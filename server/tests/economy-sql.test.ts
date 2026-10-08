import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { once } from "node:events";
import { WebSocket } from "ws";
import { openDatabase } from "../src/database.js";
import { Store } from "../src/store.js";
import { startService } from "../src/service.js";
import { makeItem } from "../src/rules.js";
import { add, find } from "../src/inventory.js";

let sequence = 0;
function request(socket: WebSocket, op: string, data: unknown): Promise<any> {
  const id = "econ" + ++sequence;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off("message", receive);
      reject(new Error("response timeout " + op));
    }, 3000);
    function receive(buffer: Buffer) {
      const value = JSON.parse(buffer.toString());
      if (value.id === id) {
        clearTimeout(timer);
        socket.off("message", receive);
        resolve(value);
      }
    }
    socket.on("message", receive);
    socket.send(JSON.stringify({ v: 1, id, op, data }));
  });
}

test(
  "economic transactions use real SQL atomicity, peer ownership and restart recovery",
  { timeout: 30000 },
  async (t) => {
    let database = await openDatabase(
      "../artifacts/postgres-economy-test",
      55442,
    );
    let service: Awaited<ReturnType<typeof startService>> | undefined;
    const sockets: WebSocket[] = [];
    const suffix = randomUUID().replaceAll("-", "").slice(0, 8),
      worldKey = "economy_" + suffix;
    let firstAccount = "",
      secondAccount = "",
      firstId = "",
      secondId = "",
      transferredUid = "";
    try {
      const store = new Store(database.pool);
      await store.migrate();
      firstAccount = await store.register(
        "econ_a_" + suffix,
        "fixture-password",
      );
      secondAccount = await store.register(
        "econ_b_" + suffix,
        "fixture-password",
      );
      const first = await store.create(firstAccount, "Uno" + suffix, "warrior"),
        second = await store.create(secondAccount, "Dos" + suffix, "mage");
      firstId = first.id;
      secondId = second.id;
      first.state.gold = 1000;
      first.state.position = { x: 1008, y: 560 };
      first.revision = await store.save(
        firstAccount,
        first.id,
        first.state,
        first.revision,
      );
      second.state.position = { x: 1008, y: 560 };
      second.revision = await store.save(
        secondAccount,
        second.id,
        second.state,
        second.revision,
      );
      service = await startService(store, 0, {
        persistenceKey: worldKey,
        random: () => 0.2,
        lootRandom: () => 0.2,
        checkpointMs: 60000,
      });
      for (const [username, id] of [
        ["econ_a_" + suffix, first.id],
        ["econ_b_" + suffix, second.id],
      ]) {
        const socket: WebSocket = new WebSocket(
          "ws://127.0.0.1:" + service.port,
        );
        sockets.push(socket);
        await once(socket, "open");
        assert.equal(
          (
            await request(socket, "login", {
              username,
              password: "fixture-password",
            })
          ).ok,
          true,
        );
        assert.equal(
          (await request(socket, "enter_world", { character_id: id })).ok,
          true,
        );
      }
      const [a, b] = sockets;
      await t.test(
        "buy price injection rejected; item and gold persisted before reply",
        async () => {
          assert.equal(
            (
              await request(a, "buy", {
                shop_id: "shop",
                definition: "robe",
                price: 0,
              })
            ).error,
            "bad_request",
          );
          assert.equal(
            (await request(a, "buy", { shop_id: "shop", definition: "robe" }))
              .ok,
            true,
          );
          const saved = await store.load(firstAccount, firstId);
          assert.equal(saved.state.gold, 940);
          const robe = saved.state.inventory.items.find(
            (item) => item.definition === "robe",
          )!;
          transferredUid = robe.uid;
          assert.equal(
            (await request(b, "sell", { shop_id: "shop", uid: robe.uid }))
              .error,
            "item_missing",
          );
        },
      );
      await t.test(
        "drop removes SQL ownership and protected ground; two peers cannot collect it twice",
        async () => {
          assert.equal(
            (await request(a, "drop", { uid: transferredUid })).ok,
            true,
          );
          assert.equal(
            (
              await store.load(firstAccount, firstId)
            ).state.inventory.items.some((item) => item.uid === transferredUid),
            false,
          );
          assert.equal(
            (await store.loadWorld(worldKey))!.ground[0].item!.uid,
            transferredUid,
          );
          assert.equal(
            (await request(b, "pickup", { ground_id: transferredUid })).error,
            "loot_protected",
          );
          service!.world.economy.ground.get(transferredUid)!.protectedUntil =
            Date.now() - 1;
          const results = await Promise.all([
            request(a, "pickup", { ground_id: transferredUid }),
            request(b, "pickup", { ground_id: transferredUid }),
          ]);
          assert.equal(results.filter((result) => result.ok).length, 1);
          assert.equal(
            results.filter((result) => result.error === "ground_missing")
              .length,
            1,
          );
          const savedA = await store.load(firstAccount, firstId),
            savedB = await store.load(secondAccount, secondId);
          assert.equal(
            [
              ...savedA.state.inventory.items,
              ...savedB.state.inventory.items,
            ].filter((item) => item.uid === transferredUid).length,
            1,
          );
          assert.equal((await store.loadWorld(worldKey))!.ground.length, 0);
        },
      );
      await t.test(
        "SQL-backed reconnect preserves active skill cooldown instead of resetting it",
        async () => {
          const actor = service!.world.players.get(secondId)!,
            target = service!.world.combat.enemies.get("training-24")!;
          actor.state.position = {
            x: target.position.x,
            y: target.position.y - 64,
          };
          actor.path = [];
          await request(b, "select_target", { target_id: target.id });
          assert.equal(
            (await request(b, "cast", { skill_id: "fireball" })).ok,
            true,
          );
          b.terminate();
          for (
            let attempt = 0;
            attempt < 100 && service!.world.players.has(secondId);
            attempt++
          )
            await new Promise((resolve) => setTimeout(resolve, 5));
          assert.equal(service!.world.players.has(secondId), false);
          assert.ok(
            (await store.load(secondAccount, secondId)).state.combat_state
              .cooldown_deadlines.fireball > Date.now(),
          );
          const resumed = new WebSocket("ws://127.0.0.1:" + service!.port);
          sockets.push(resumed);
          await once(resumed, "open");
          await request(resumed, "login", {
            username: "econ_b_" + suffix,
            password: "fixture-password",
          });
          await request(resumed, "enter_world", { character_id: secondId });
          assert.equal(
            (await request(resumed, "cast", { skill_id: "fireball" })).error,
            "cooldown",
          );
        },
      );
      await t.test(
        "SQL failure rolls back economic in-memory mutation and database state",
        async () => {
          const actor = service!.world.players.get(firstId)!,
            before = structuredClone(actor.state);
          await database.pool
            .query(`CREATE OR REPLACE FUNCTION reject_economy_fixture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='${worldKey}' THEN RAISE EXCEPTION 'controlled fixture storage failure'; END IF; RETURN NEW; END $$;
        CREATE TRIGGER reject_economy_fixture BEFORE UPDATE ON world_states FOR EACH ROW EXECUTE FUNCTION reject_economy_fixture();`);
          try {
            assert.equal(
              (
                await request(a, "buy", {
                  shop_id: "shop",
                  definition: "potion",
                })
              ).error,
              "persistence_failed",
            );
            assert.equal(actor.state.gold, before.gold);
            assert.deepEqual(actor.state.inventory, before.inventory);
            assert.equal(
              (await store.load(firstAccount, firstId)).state.gold,
              before.gold,
            );
          } finally {
            await database.pool.query(
              "DROP TRIGGER reject_economy_fixture ON world_states; DROP FUNCTION reject_economy_fixture()",
            );
          }
          assert.equal(
            (await request(a, "buy", { shop_id: "shop", definition: "potion" }))
              .ok,
            true,
          );
        },
      );
      await t.test(
        "checkpoint revision failure rolls back earlier actor updates and ground atomically",
        async () => {
          const loadedA = await store.load(firstAccount, firstId),
            loadedB = await store.load(secondAccount, secondId),
            savedWorld = (await store.loadWorld(worldKey))!;
          const aState = structuredClone(loadedA.state);
          aState.gold += 50;
          await assert.rejects(
            store.checkpoint(
              worldKey,
              savedWorld.revision,
              [
                {
                  id: firstId,
                  account: firstAccount,
                  state: aState,
                  revision: loadedA.revision,
                },
                {
                  id: secondId,
                  account: secondAccount,
                  state: loadedB.state,
                  revision: -1,
                },
              ],
              [],
            ),
            /stale_state/,
          );
          assert.equal(
            (await store.load(firstAccount, firstId)).state.gold,
            loadedA.state.gold,
          );
          assert.equal(
            (await store.loadWorld(worldKey))!.revision,
            savedWorld.revision,
          );
        },
      );
      await t.test(
        "failed disconnect retains state and exclusivity until checkpoint retry succeeds",
        async () => {
          const key = "recovery_" + suffix,
            account = await store.register(
              "recovery_" + suffix,
              "fixture-password",
            ),
            character = await store.create(
              account,
              "Recov" + suffix,
              "warrior",
            );
          await database.pool
            .query(`CREATE OR REPLACE FUNCTION reject_disconnect_fixture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='${key}' THEN RAISE EXCEPTION 'controlled disconnect storage failure'; END IF; RETURN NEW; END $$;
        CREATE TRIGGER reject_disconnect_fixture BEFORE UPDATE ON world_states FOR EACH ROW EXECUTE FUNCTION reject_disconnect_fixture();`);
          const recovery = await startService(store, 0, {
            persistenceKey: key,
            checkpointMs: 25,
          });
          const clients: WebSocket[] = [];
          const connect = async () => {
            const socket: WebSocket = new WebSocket(
              "ws://127.0.0.1:" + recovery.port,
            );
            clients.push(socket);
            await once(socket, "open");
            await request(socket, "login", {
              username: "recovery_" + suffix,
              password: "fixture-password",
            });
            return socket;
          };
          try {
            const original = await connect();
            await request(original, "enter_world", {
              character_id: character.id,
            });
            recovery.world.players.get(character.id)!.state.gold = 77;
            original.terminate();
            await new Promise((resolve) => setTimeout(resolve, 60));
            assert.ok(
              recovery.world.players.has(character.id),
              "failed save retains locked actor",
            );
            assert.equal(
              (await store.load(account, character.id)).state.gold,
              0,
            );
            const resumed = await connect();
            assert.equal(
              (
                await request(resumed, "enter_world", {
                  character_id: character.id,
                })
              ).error,
              "character_in_use",
            );
            await database.pool.query(
              "DROP TRIGGER reject_disconnect_fixture ON world_states; DROP FUNCTION reject_disconnect_fixture()",
            );
            for (
              let attempt = 0;
              attempt < 100 && recovery.world.players.has(character.id);
              attempt++
            )
              await new Promise((resolve) => setTimeout(resolve, 10));
            assert.equal(recovery.world.players.has(character.id), false);
            assert.equal(
              (await store.load(account, character.id)).state.gold,
              77,
            );
            assert.equal(
              (
                await request(resumed, "enter_world", {
                  character_id: character.id,
                })
              ).ok,
              true,
            );
            assert.equal(
              recovery.world.players.get(character.id)!.state.gold,
              77,
            );
          } finally {
            await database.pool.query(
              "DROP TRIGGER IF EXISTS reject_disconnect_fixture ON world_states; DROP FUNCTION IF EXISTS reject_disconnect_fixture()",
            );
            for (const socket of clients) socket.terminate();
            await recovery.close();
          }
        },
      );
      await t.test(
        "ground and owner state survive graceful server and SQL restart without duplication",
        async () => {
          const actor = service!.world.players.get(firstId)!;
          const item = makeItem("helmet", 1, "excellent");
          add(actor.state.inventory, item);
          await new Promise((resolve) => setTimeout(resolve, 1000));
          assert.equal((await request(a, "drop", { uid: item.uid })).ok, true);
          for (const socket of sockets) socket.terminate();
          await service!.close();
          service = undefined;
          await database.close();
          database = await openDatabase(
            "../artifacts/postgres-economy-test",
            55442,
          );
          const reopened = new Store(database.pool);
          const grounds = (await reopened.loadWorld(worldKey))!.ground;
          assert.equal(
            grounds.find((ground) => ground.id === item.uid)!.item!.rarity,
            "excellent",
          );
          assert.equal(
            (
              await reopened.load(firstAccount, firstId)
            ).state.inventory.items.some((owned) => owned.uid === item.uid),
            false,
          );
          service = await startService(reopened, 0, {
            persistenceKey: worldKey,
            checkpointMs: 60000,
          });
          assert.ok(service.world.economy.ground.has(item.uid));
          const resumed = new WebSocket("ws://127.0.0.1:" + service.port);
          sockets.push(resumed);
          await once(resumed, "open");
          await request(resumed, "login", {
            username: "econ_a_" + suffix,
            password: "fixture-password",
          });
          await request(resumed, "enter_world", { character_id: firstId });
          assert.equal(
            (await request(resumed, "pickup", { ground_id: item.uid })).ok,
            true,
          );
          assert.equal(
            (await request(resumed, "pickup", { ground_id: item.uid })).error,
            "ground_missing",
          );
          assert.equal(
            find(
              (await reopened.load(firstAccount, firstId)).state.inventory,
              item.uid,
            ).rarity,
            "excellent",
          );
          assert.equal((await reopened.loadWorld(worldKey))!.ground.length, 0);
        },
      );
    } finally {
      for (const socket of sockets) socket.terminate();
      if (service) await service.close();
      await database.close();
    }
  },
);
