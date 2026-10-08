import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { once } from "node:events";
import { WebSocket } from "ws";
import { openDatabase } from "../src/database.js";
import { Store } from "../src/store.js";
import { createCharacter } from "../src/rules.js";
import { startService } from "../src/service.js";

let sequence = 0;
test("Windows PostgreSQL lifecycle starts a fresh cluster, rejects double start and closes idempotently", async () => {
  const directory = "../artifacts/postgres-launcher-clean-test";
  const database = await openDatabase(directory, 55441);
  try {
    assert.match(database.version, /PostgreSQL 18/);
    await assert.rejects(
      openDatabase(directory, 55441),
      /cluster_already_running/,
    );
    assert.equal(
      (await database.pool.query("SELECT 1 AS value")).rows[0].value,
      1,
    );
  } finally {
    await database.close();
    await database.close();
  }
  assert.equal(
    existsSync(resolve(directory, "postmaster.pid")),
    false,
    "clean shutdown removes server PID",
  );
});
async function snapshot(
  socket: WebSocket,
  predicate: (data: any) => boolean,
): Promise<any> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off("message", receive);
      reject(new Error("snapshot timeout"));
    }, 3000);
    function receive(buffer: Buffer) {
      const value = JSON.parse(buffer.toString());
      if (value.event === "snapshot" && predicate(value.data)) {
        clearTimeout(timer);
        socket.off("message", receive);
        resolve(value.data);
      }
    }
    socket.on("message", receive);
  });
}
async function request(
  socket: WebSocket,
  op: string,
  data: unknown,
  id = String(++sequence),
): Promise<any> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off("message", receive);
      reject(new Error("response timeout " + op));
    }, 3000);
    function receive(buffer: Buffer) {
      const result = JSON.parse(buffer.toString());
      if (result.id !== id) return;
      clearTimeout(timer);
      socket.off("message", receive);
      resolve(result);
    }
    socket.on("message", receive);
    socket.send(JSON.stringify({ v: 1, id, op, data }));
  });
}

test(
  "real PostgreSQL + two WebSocket peers, accounts and persistent characters",
  { timeout: 45000 },
  async (t) => {
    let database = await openDatabase(
      "../artifacts/postgres-backend-test",
      55439,
    );
    let service: Awaited<ReturnType<typeof startService>> | undefined;
    const peers: WebSocket[] = [];
    const suffix = randomUUID().replaceAll("-", "").slice(0, 8);
    const password = "fixture-password-only";
    let account = "",
      characterId = "",
      weaponUid = "",
      peerCharacterId = "";
    try {
      assert.match(database.version, /PostgreSQL 18/);
      console.log("REAL DATABASE:", database.version);
      const store = new Store(database.pool);
      await store.migrate();
      await t.test("class formulas match known Godot baselines", () => {
        assert.equal(createCharacter("Acero", "warrior").hp, 160);
        assert.equal(createCharacter("Bruma", "mage").mana, 132);
        assert.equal(createCharacter("Fresno", "elf").stats.defense, 14);
        assert.throws(() => createCharacter("bad name", "warrior"));
        assert.throws(() => createCharacter("Acero", "unknown"));
      });
      await t.test(
        "account registration hashes password and rejects duplicates",
        async () => {
          account = await store.register("test_" + suffix, password);
          await assert.rejects(
            store.register("TEST_" + suffix, password),
            /account_exists/,
          );
          const row = (
            await database.pool.query("SELECT * FROM accounts WHERE id=$1", [
              account,
            ])
          ).rows[0];
          assert.notEqual(row.password_hash, password);
          assert.equal(row.password_hash.length, 128);
          assert.equal(await store.login("TEST_" + suffix, password), account);
          await assert.rejects(
            store.login("test_" + suffix, "wrong-password"),
            /login_failed/,
          );
          await assert.rejects(
            store.login("missing_" + suffix, password),
            /login_failed/,
          );
        },
      );
      await t.test(
        "character creation server generates inventory, gold and stats",
        async () => {
          const created = await store.create(
            account,
            "Acero" + suffix,
            "warrior",
          );
          characterId = created.id;
          weaponUid = created.state.inventory.equipment.weapon;
          assert.equal(created.state.gold, 0);
          assert.equal(created.state.stats.attack, 27);
          assert.equal(created.state.inventory.items[0].uid, weaponUid);
          assert.equal(created.state.inventory.items[1].count, 3);
          await assert.rejects(
            store.create(account, "ACERO" + suffix, "mage"),
            /name_exists/,
          );
        },
      );
      await t.test(
        "optimistic revision protects trusted save from stale overwrite",
        async () => {
          const loaded = await store.load(account, characterId);
          loaded.state.gold = 17;
          assert.equal(
            await store.save(
              account,
              characterId,
              loaded.state,
              loaded.revision,
            ),
            1,
          );
          loaded.state.gold = 999;
          await assert.rejects(
            store.save(account, characterId, loaded.state, 0),
            /stale_state/,
          );
          assert.equal((await store.load(account, characterId)).state.gold, 17);
        },
      );
      await t.test(
        "transaction enforces three-character limit under concurrent requests",
        async () => {
          const results = await Promise.allSettled([
            store.create(account, "Bruma" + suffix, "mage"),
            store.create(account, "Fresno" + suffix, "elf"),
            store.create(account, "Cuarto" + suffix, "warrior"),
          ]);
          assert.equal(
            results.filter((value) => value.status === "fulfilled").length,
            2,
          );
          assert.equal((await store.list(account)).length, 3);
        },
      );
      service = await startService(store, 0, { random: () => 0.2 });
      for (let index = 0; index < 2; index++) {
        const peer = new WebSocket("ws://127.0.0.1:" + service.port);
        peers.push(peer);
        await once(peer, "open");
      }
      const [first, second] = peers;
      await t.test(
        "two peers authenticate independently and block anonymous access",
        async () => {
          assert.equal(
            (await request(first, "characters", {})).error,
            "unauthenticated",
          );
          assert.equal(
            (
              await request(first, "login", {
                username: "test_" + suffix,
                password,
              })
            ).ok,
            true,
          );
          assert.equal(
            (
              await request(second, "register", {
                username: "peer_" + suffix,
                password,
              })
            ).ok,
            true,
          );
          assert.equal(
            (
              await request(second, "login", {
                username: "peer_" + suffix,
                password,
              })
            ).ok,
            true,
          );
          assert.equal((await request(first, "characters", {})).data.length, 3);
        },
      );
      await t.test(
        "ownership enforced and payload cannot inject economy or stats",
        async () => {
          assert.equal(
            (
              await request(second, "load_character", {
                character_id: characterId,
              })
            ).error,
            "character_missing",
          );
          assert.equal(
            (
              await request(second, "create_character", {
                name: "Peer" + suffix,
                class_id: "mage",
                gold: 9000,
              })
            ).error,
            "bad_request",
          );
          const result = await request(second, "create_character", {
            name: "Peer" + suffix,
            class_id: "mage",
          });
          assert.equal(result.ok, true);
          assert.equal(result.data.state.gold, 0);
          peerCharacterId = result.data.id;
          assert.equal(
            (await request(first, "save_state", { gold: 9000 })).error,
            "unknown_operation",
          );
          assert.equal(
            (
              await request(first, "load_character", {
                character_id: characterId,
              })
            ).data.state.gold,
            17,
          );
        },
      );
      await t.test(
        "request ids reject duplicate mutating messages",
        async () => {
          assert.equal(
            (await request(first, "characters", {}, "repeat")).ok,
            true,
          );
          assert.equal(
            (await request(first, "characters", {}, "repeat")).error,
            "duplicate_request",
          );
        },
      );
      await t.test(
        "malformed JSON and invalid UUID fail without terminating server",
        async () => {
          const response = once(second, "message");
          second.send("{broken");
          assert.equal(
            JSON.parse(String((await response)[0])).error,
            "bad_request",
          );
          assert.equal(
            (
              await request(second, "load_character", {
                character_id: "------------------------------------",
              })
            ).error,
            "character_missing",
          );
          assert.equal((await request(second, "characters", {})).ok, true);
        },
      );
      await t.test(
        "two WebSocket peers receive each other and server-driven movement",
        async () => {
          assert.equal(
            (await request(first, "enter_world", { character_id: characterId }))
              .ok,
            true,
          );
          assert.equal(
            (
              await request(second, "enter_world", {
                character_id: peerCharacterId,
              })
            ).ok,
            true,
          );
          const seeing = snapshot(second, (data) => data.players.length === 2);
          assert.equal((await seeing).players.length, 2);
          assert.equal(
            (await request(first, "move", { x: 848, y: 592, speed: 9999 }))
              .error,
            "bad_request",
          );
          const arrival = snapshot(second, (data) =>
            data.players.some(
              (player: any) =>
                player.id === characterId && player.position.x === 848,
            ),
          );
          assert.equal(
            (await request(first, "move", { x: 848, y: 592 })).ok,
            true,
          );
          const arrived = await arrival;
          assert.deepEqual(
            arrived.players.find((player: any) => player.id === characterId)
              .position,
            { x: 848, y: 592 },
          );
          const competing = new WebSocket("ws://127.0.0.1:" + service!.port);
          peers.push(competing);
          await once(competing, "open");
          assert.equal(
            (
              await request(competing, "login", {
                username: "test_" + suffix,
                password,
              })
            ).ok,
            true,
          );
          assert.equal(
            (
              await request(competing, "enter_world", {
                character_id: characterId,
              })
            ).error,
            "character_in_use",
          );
          competing.terminate();
        },
      );
      await t.test(
        "combat intentions are validated and broadcast to the other peer",
        async () => {
          const actor = service!.world.players.get(peerCharacterId)!;
          const target = service!.world.combat.enemies.get("training-24")!;
          actor.state.position = {
            x: target.position.x,
            y: target.position.y - 64,
          };
          actor.path = [];
          assert.equal(
            (await request(second, "select_target", { target_id: target.id }))
              .ok,
            true,
          );
          assert.equal(
            (
              await request(second, "cast", {
                skill_id: "fireball",
                damage: 10000,
              })
            ).error,
            "bad_request",
          );
          const observed = snapshot(first, (data) =>
            data.events.some(
              (event: any) =>
                event.kind === "skill" &&
                event.actor === peerCharacterId &&
                event.skill === "fireball",
            ),
          );
          assert.equal(
            (await request(second, "cast", { skill_id: "fireball" })).ok,
            true,
          );
          const result = await observed;
          assert.ok(
            result.enemies.find((enemy: any) => enemy.id === target.id).hp <
              110,
          );
          const mana = actor.state.mana;
          assert.equal(
            (await request(second, "cast", { skill_id: "fireball" })).error,
            "cooldown",
          );
          assert.equal(actor.state.mana, mana);
          assert.equal(
            (
              await request(second, "allocate", {
                attribute: "energy",
                amount: 1,
              })
            ).error,
            "invalid_allocation",
          );
          assert.equal(
            (await request(second, "award_experience", { amount: 10000 }))
              .error,
            "unknown_operation",
          );
        },
      );
      await t.test(
        "heartbeat closes a socket that stops responding to ping",
        async () => {
          const heartbeatService = await startService(store, 0, {
            heartbeatMs: 50,
          });
          const silent = new WebSocket(
            "ws://127.0.0.1:" + heartbeatService.port,
            { autoPong: false },
          );
          await once(silent, "open");
          try {
            await once(silent, "close");
            assert.equal(silent.readyState, WebSocket.CLOSED);
          } finally {
            silent.terminate();
            await heartbeatService.close();
          }
        },
      );
      for (const peer of peers) peer.terminate();
      await service.close();
      service = undefined;
      await database.close();
      database = await openDatabase(
        "../artifacts/postgres-backend-test",
        55439,
      );
      await t.test(
        "real database shutdown/restart retains account UID inventory and gold",
        async () => {
          const reopened = new Store(database.pool);
          assert.equal(
            await reopened.login("test_" + suffix, password),
            account,
          );
          const saved = await reopened.load(account, characterId);
          assert.equal(saved.state.gold, 17);
          assert.equal(saved.revision, 2);
          assert.deepEqual(saved.state.position, { x: 848, y: 592 });
          assert.equal(saved.state.inventory.equipment.weapon, weaponUid);
          assert.equal(saved.state.inventory.items[0].uid, weaponUid);
        },
      );
    } finally {
      for (const peer of peers) peer.terminate();
      if (service) await service.close();
      await database.close();
    }
  },
);
