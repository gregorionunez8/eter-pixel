import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { once } from "node:events";
import { WebSocket } from "ws";
import { openDatabase } from "../src/database.js";
import { Store } from "../src/store.js";
import { startService } from "../src/service.js";
let seq = 0;
function request(ws: WebSocket, op: string, data: unknown = {}) {
  const id = "quest" + ++seq;
  return new Promise<any>((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off("message", receive);
      reject(new Error("quest request timeout"));
    }, 5000);
    const receive = (buffer: Buffer) => {
      const msg = JSON.parse(buffer.toString());
      if (msg.id === id) {
        clearTimeout(timer);
        ws.off("message", receive);
        resolve(msg);
      }
    };
    ws.on("message", receive);
    ws.send(JSON.stringify({ v: 1, id, op, data }));
  });
}
test(
  "quest intents use actual simulation kills, SQL rollback and unique rewards after database restart",
  { timeout: 30000 },
  async () => {
    let db = await openDatabase("../artifacts/postgres-quests-test", 55446),
      store = new Store(db.pool);
    await store.migrate();
    const suffix = randomUUID().replaceAll("-", "").slice(0, 8),
      username = "quest" + suffix,
      key = "quest_" + suffix;
    const account = await store.register(username, "fixture-password"),
      saved = await store.create(account, "Encargo" + suffix, "warrior");
    const sockets: WebSocket[] = [];
    let service: Awaited<ReturnType<typeof startService>> | undefined;
    try {
      service = await startService(store, 0, {
        persistenceKey: key,
        checkpointMs: 60000,
        random: () => 0,
        lootRandom: () => 0.99,
      });
      const connect = async () => {
        const ws = new WebSocket(`ws://127.0.0.1:${service!.port}`);
        sockets.push(ws);
        await once(ws, "open");
        assert.equal(
          (
            await request(ws, "login", {
              username,
              password: "fixture-password",
            })
          ).ok,
          true,
        );
        return ws;
      };
      let ws = await connect();
      assert.equal(
        (await request(ws, "quest_accept", { quest_id: "silk_on_the_road" }))
          .error,
        "not_in_world",
      );
      assert.equal(
        (await request(ws, "enter_world", { character_id: saved.id })).ok,
        true,
      );
      assert.equal(
        (
          await request(ws, "quest_accept", {
            quest_id: "silk_on_the_road",
            kills: 3,
          })
        ).error,
        "bad_request",
      );
      assert.equal(
        (await request(ws, "quest_accept", { quest_id: "silk_on_the_road" }))
          .error,
        "npc_out_of_range",
      );
      const actor = service.world.players.get(saved.id)!;
      // Trusted fixture position next to Iria; clients cannot send this state.
      actor.state.position = { x: 1008, y: 560 };
      actor.state.hp = 0;
      assert.equal(
        (await request(ws, "quest_accept", { quest_id: "silk_on_the_road" }))
          .error,
        "dead",
      );
      actor.state.hp = 160;
      assert.equal(
        (await request(ws, "quest_accept", { quest_id: "fangs_in_the_mist" }))
          .error,
        "npc_out_of_range",
      );
      assert.equal(
        (await request(ws, "quest_accept", { quest_id: "silk_on_the_road" }))
          .ok,
        true,
      );
      assert.equal(
        (await store.load(account, saved.id)).state.quests!.silk_on_the_road
          .kills,
        0,
      );
      assert.equal(
        (await request(ws, "quest_claim", { quest_id: "silk_on_the_road" }))
          .error,
        "quest_not_ready",
      );
      const enemy = service.world.combat.enemies.get("monster-0")!;
      // High attack/short respawn accelerate real AI/autoattack; no injected kills.
      enemy.config = { ...enemy.config, respawn: 0.05 };
      actor.state.stats.attack = 10000;
      for (let kill = 0; kill < 3; kill++) {
      actor.state.position = { x: enemy.home.x - 32, y: enemy.home.y };
        enemy.hp = 1;
        service.world.combat.select(saved.id, enemy.id);
        for (
          let frame = 0;
          frame < 100 && actor.state.quests!.silk_on_the_road.kills <= kill;
          frame++
        )
          service.world.step(0.05);
        assert.equal(actor.state.quests!.silk_on_the_road.kills, kill + 1);
        service.world.combat.cancel(saved.id);
        service.world.step(0.05);
      }
      actor.state.position = { x: 1008, y: 560 };
      await db.pool.query(
        `CREATE FUNCTION controlled_quests_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='${key}' THEN RAISE EXCEPTION 'controlled_quest_failure'; END IF; RETURN NEW; END $$; CREATE TRIGGER controlled_quests_failure BEFORE UPDATE ON world_states FOR EACH ROW EXECUTE FUNCTION controlled_quests_failure()`,
      );
      const before = structuredClone(actor.state);
      assert.equal(
        (await request(ws, "quest_claim", { quest_id: "silk_on_the_road" }))
          .error,
        "persistence_failed",
      );
      assert.deepEqual(actor.state.quests, before.quests);
      assert.equal(actor.state.gold, before.gold);
      assert.deepEqual(actor.state.inventory, before.inventory);
      assert.equal(
        (await store.load(account, saved.id)).state.quests!.silk_on_the_road
          .claimed,
        false,
      );
      await db.pool.query(
        "DROP TRIGGER controlled_quests_failure ON world_states; DROP FUNCTION controlled_quests_failure()",
      );
      assert.equal(
        (await request(ws, "quest_claim", { quest_id: "silk_on_the_road" })).ok,
        true,
      );
      const persisted = (await store.load(account, saved.id)).state;
      assert.equal(persisted.gold, before.gold + 40);
      assert.equal(persisted.quests!.silk_on_the_road.claimed, true);
      assert.equal(
        persisted.inventory.items.find((i) => i.definition === "potion")!.count,
        6,
      );
      await service.close();
      service = undefined;
      await db.close();
      db = await openDatabase("../artifacts/postgres-quests-test", 55446);
      store = new Store(db.pool);
      service = await startService(store, 0, { persistenceKey: key });
      ws = await connect();
      const entered = await request(ws, "enter_world", {
        character_id: saved.id,
      });
      assert.equal(entered.data.state.quests.silk_on_the_road.claimed, true);
      assert.equal(
        (await request(ws, "quest_claim", { quest_id: "silk_on_the_road" }))
          .error,
        "quest_not_ready",
      );
      assert.equal(
        (await store.load(account, saved.id)).state.gold,
        persisted.gold,
      );
    } finally {
      for (const ws of sockets) ws.terminate();
      await service?.close();
      await db.close();
    }
  },
);
