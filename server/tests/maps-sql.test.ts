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
  const id = "maps" + ++seq;
  return new Promise<any>((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off("message", receive);
      reject(new Error("map request timeout"));
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
  "real WS portal transitions persist map/position and isolate snapshots through SQL failure and restart",
  { timeout: 30000 },
  async () => {
    let db = await openDatabase("../artifacts/postgres-maps-test", 55445),
      store = new Store(db.pool);
    await store.migrate();
    const suffix = randomUUID().replaceAll("-", "").slice(0, 8),
      key = "maps_" + suffix;
    const accounts: string[] = [],
      ids: string[] = [],
      sockets: WebSocket[] = [];
    let service: Awaited<ReturnType<typeof startService>> | undefined;
    try {
      for (let i = 0; i < 2; i++) {
        const account = await store.register(
          "maps" + i + suffix,
          "fixture-password",
        );
        accounts.push(account);
        const saved = await store.create(account, "Viaje" + i + suffix, "mage");
        ids.push(saved.id);
        saved.state.position = { x: 784, y: 976 };
        await store.save(account, saved.id, saved.state, saved.revision);
      }
      service = await startService(store, 0, {
        persistenceKey: key,
        checkpointMs: 60000,
      });
      const connect = async (i: number) => {
        const ws: WebSocket = new WebSocket(`ws://127.0.0.1:${service!.port}`);
        sockets.push(ws);
        await once(ws, "open");
        assert.equal(
          (
            await request(ws, "login", {
              username: "maps" + i + suffix,
              password: "fixture-password",
            })
          ).ok,
          true,
        );
        return ws;
      };
      const a = await connect(0),
        b = await connect(1);
      for (const [ws, id] of [
        [a, ids[0]],
        [b, ids[1]],
      ] as [WebSocket, string][])
        assert.equal(
          (await request(ws, "enter_world", { character_id: id })).ok,
          true,
        );
      assert.equal(
        (
          await request(a, "portal", {
            portal_id: "village_forest",
            target: "crypt",
          })
        ).error,
        "bad_request",
      );
      const first = await request(a, "portal", { portal_id: "village_forest" });
      assert.equal(first.ok, true);
      assert.equal(first.data.world.map_id, "forest");
      assert.equal(first.data.world.players.length, 1);
      assert.equal(
        (await store.load(accounts[0], ids[0])).state.map_id,
        "forest",
      );
      const observed = await new Promise<any>((resolve) => {
        const listener = (buffer: Buffer) => {
          const msg = JSON.parse(buffer.toString());
          if (msg.event === "snapshot") {
            b.off("message", listener);
            resolve(msg.data);
          }
        };
        b.on("message", listener);
      });
      assert.equal(observed.map_id, "village");
      assert.deepEqual(
        observed.players.map((p: any) => p.id),
        [ids[1]],
      );
      assert.equal(
        (await request(b, "portal", { portal_id: "village_forest" })).ok,
        true,
      );
      assert.equal(service.world.snapshot("forest").players.length, 2);
      const actor = service.world.players.get(ids[0])!;
      actor.state.position = { x: 1360, y: 800 };
      service.world.combat.battles.get(ids[0])!.cooldowns.fireball = 2;
      service.world.step(0);
      await db.pool.query(
        `CREATE FUNCTION controlled_maps_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='${key}' THEN RAISE EXCEPTION 'controlled_portal_failure'; END IF; RETURN NEW; END $$; CREATE TRIGGER controlled_maps_failure BEFORE UPDATE ON world_states FOR EACH ROW EXECUTE FUNCTION controlled_maps_failure()`,
      );
      assert.equal(
        (await request(a, "portal", { portal_id: "forest_crypt" })).error,
        "persistence_failed",
      );
      assert.equal(actor.state.map_id, "forest");
      assert.equal(
        (await store.load(accounts[0], ids[0])).state.map_id,
        "forest",
      );
      await db.pool.query(
        "DROP TRIGGER controlled_maps_failure ON world_states; DROP FUNCTION controlled_maps_failure()",
      );
      const crypt = await request(a, "portal", { portal_id: "forest_crypt" });
      assert.equal(crypt.ok, true);
      assert.equal(crypt.data.world.map_id, "crypt");
      assert.equal(crypt.data.world.enemies.length, 6);
      const persisted = await store.load(accounts[0], ids[0]);
      assert.equal(persisted.state.map_id, "crypt");
      assert.deepEqual(persisted.state.position, { x: 176, y: 176 });
      assert.ok(
        persisted.state.combat_state.cooldown_deadlines.fireball > Date.now(),
      );
      await service.close();
      service = undefined;
      await db.close();
      db = await openDatabase("../artifacts/postgres-maps-test", 55445);
      store = new Store(db.pool);
      service = await startService(store, 0, { persistenceKey: key });
      const resumed = await connect(0),
        loaded = await request(resumed, "enter_world", {
          character_id: ids[0],
        });
      assert.equal(loaded.data.state.map_id, "crypt");
      assert.equal(loaded.data.world.map_id, "crypt");
      assert.deepEqual(loaded.data.state.position, { x: 176, y: 176 });
      assert.equal(
        (await request(resumed, "portal", { portal_id: "crypt_forest" })).ok,
        true,
      );
      assert.equal(
        (await store.load(accounts[0], ids[0])).state.map_id,
        "forest",
      );
    } finally {
      for (const ws of sockets) ws.terminate();
      await service?.close();
      await db.close();
    }
  },
);
