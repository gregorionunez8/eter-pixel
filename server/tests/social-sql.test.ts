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
function request(ws: WebSocket, op: string, data: unknown = {}) {
  const id = "social" + ++sequence;
  return new Promise<any>((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off("message", receive);
      reject(new Error("request timeout " + op));
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
  "three real WS peers route chat and atomically commit consensual trade with SQL rollback",
  { timeout: 30000 },
  async (t) => {
    const db = await openDatabase("../artifacts/postgres-social-test", 55444),
      store = new Store(db.pool);
    await store.migrate();
    const suffix = randomUUID().replaceAll("-", "").slice(0, 8),
      key = "social_" + suffix;
    let service: Awaited<ReturnType<typeof startService>> | undefined;
    const sockets: WebSocket[] = [],
      accounts: string[] = [],
      ids: string[] = [],
      messages: any[][] = [[], [], []];
    const robe = makeItem("robe", 1, "excellent");
    try {
      for (let i = 0; i < 3; i++) {
        const account = await store.register(
          "social" + i + suffix,
          "fixture-password",
        );
        accounts.push(account);
        const saved = await store.create(
          account,
          "Soc" + i + suffix,
          "warrior",
        );
        ids.push(saved.id);
        saved.state.gold = 100;
        if (i === 0) add(saved.state.inventory, robe);
        saved.state.position = {
          x: i === 1 ? 816 : 784,
          y: i === 2 ? 928 : 592,
        };
        await store.save(account, saved.id, saved.state, saved.revision);
      }
      service = await startService(store, 0, {
        persistenceKey: key,
        checkpointMs: 60000,
      });
      for (let i = 0; i < 3; i++) {
      const ws: WebSocket = new WebSocket(`ws://127.0.0.1:${service.port}`);
        sockets.push(ws);
        await once(ws, "open");
        ws.on("message", (buffer) => {
          const msg = JSON.parse(buffer.toString());
          if (msg.event === "chat") messages[i].push(msg.data);
        });
        assert.equal(
          (
            await request(ws, "login", {
              username: "social" + i + suffix,
              password: "fixture-password",
            })
          ).ok,
          true,
        );
        assert.equal(
          (await request(ws, "enter_world", { character_id: ids[i] })).ok,
          true,
        );
      }
      const social = service.world.social;
      await t.test(
        "chat cannot impersonate sender or leak local text to distant peer",
        async () => {
          assert.equal(
            (
              await request(sockets[0], "chat", {
                channel: "global",
                message: "[b]literal[/b]",
              })
            ).ok,
            true,
          );
          await new Promise((r) => setTimeout(r, 20));
          assert.deepEqual(
            messages.map((m) => m.length),
            [1, 1, 1],
          );
          assert.equal(messages[1][0].sender, "Soc0" + suffix);
          assert.equal(
            (
              await request(sockets[0], "chat", {
                channel: "global",
                message: "spam",
              })
            ).error,
            "chat_rate",
          );
          assert.equal(
            (
              await request(sockets[1], "chat", {
                channel: "local",
                message: "cerca",
                sender: "falso",
              })
            ).error,
            "bad_request",
          );
          assert.equal(
            (
              await request(sockets[1], "chat", {
                channel: "local",
                message: "cerca",
              })
            ).ok,
            true,
          );
          await new Promise((r) => setTimeout(r, 20));
          assert.deepEqual(
            messages.map((m) => m.length),
            [2, 2, 1],
          );
        },
      );
      await t.test(
        "party requires recipient consent and does not expose offered items to outsiders",
        async () => {
          assert.equal(
            (await request(sockets[0], "party_invite", { target_id: ids[1] }))
              .ok,
            true,
          );
          assert.equal(social.partyFor(ids[1]), undefined);
          assert.equal(
            (await request(sockets[1], "party_reply", { accept: true })).ok,
            true,
          );
          assert.equal(social.partyFor(ids[1])!.members.length, 2);
          assert.equal(
            (await request(sockets[0], "trade_invite", { target_id: ids[1] }))
              .ok,
            true,
          );
          assert.equal(
            (await request(sockets[1], "trade_reply", { accept: true })).ok,
            true,
          );
          assert.equal(social.snapshot(ids[2]).trade, null);
        },
      );
      await t.test(
        "offers invalidate confirmations and stale revisions cannot finalize",
        async () => {
          let rev = social.tradeFor(ids[0])!.revision;
          assert.equal(
            (
              await request(sockets[0], "trade_offer", {
                uids: [robe.uid],
                gold: 10,
                revision: rev,
              })
            ).ok,
            true,
          );
          assert.equal(
            (await request(sockets[0], "trade_accept", { revision: rev }))
              .error,
            "trade_revision",
          );
          rev = social.tradeFor(ids[0])!.revision;
          assert.equal(
            (await request(sockets[0], "trade_accept", { revision: rev })).ok,
            true,
          );
          assert.equal(
            (
              await request(sockets[1], "trade_offer", {
                uids: [],
                gold: 5,
                revision: rev,
              })
            ).ok,
            true,
          );
          assert.deepEqual(social.tradeFor(ids[0])!.accepted, []);
          rev = social.tradeFor(ids[0])!.revision;
          assert.equal(
            (await request(sockets[0], "trade_accept", { revision: rev })).ok,
            true,
          );
        },
      );
      await t.test(
        "actual SQL exception rolls back both inventories and gold; explicit retry commits once",
        async () => {
          await db.pool.query(
            "INSERT INTO world_states(id) VALUES($1) ON CONFLICT DO NOTHING",
            [key],
          );
          await db.pool.query(
            `CREATE FUNCTION controlled_social_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id='${key}' THEN RAISE EXCEPTION 'controlled_trade_storage_failure'; END IF; RETURN NEW; END $$; CREATE TRIGGER controlled_social_failure BEFORE UPDATE ON world_states FOR EACH ROW EXECUTE FUNCTION controlled_social_failure()`,
          );
          const rev = social.tradeFor(ids[0])!.revision;
          assert.equal(
            (await request(sockets[1], "trade_accept", { revision: rev }))
              .error,
            "persistence_failed",
          );
          assert.equal(
            find(service!.world.players.get(ids[0])!.state.inventory, robe.uid)
              .rarity,
            "excellent",
          );
          assert.equal((await store.load(accounts[0], ids[0])).state.gold, 100);
          assert.throws(
            () =>
              find(
                service!.world.players.get(ids[1])!.state.inventory,
                robe.uid,
              ),
            /item_missing/,
          );
          assert.deepEqual(social.tradeFor(ids[0])!.accepted, [ids[0]]);
          await db.pool.query(
            "DROP TRIGGER controlled_social_failure ON world_states; DROP FUNCTION controlled_social_failure()",
          );
          assert.equal(
            (await request(sockets[1], "trade_accept", { revision: rev })).data
              .completed,
            true,
          );
          const a = await store.load(accounts[0], ids[0]),
            b = await store.load(accounts[1], ids[1]);
          assert.equal(a.state.gold, 95);
          assert.equal(b.state.gold, 105);
          assert.throws(
            () => find(a.state.inventory, robe.uid),
            /item_missing/,
          );
          assert.equal(find(b.state.inventory, robe.uid).rarity, "excellent");
          assert.equal(
            (await request(sockets[1], "trade_accept", { revision: rev }))
              .error,
            "trade_missing",
          );
        },
      );
      await t.test(
        "disconnect cancels invitations/trades and removes member from active roster",
        async () => {
          assert.equal(
            (await request(sockets[0], "trade_invite", { target_id: ids[1] }))
              .ok,
            true,
          );
          sockets[1].close();
          await once(sockets[1], "close");
          const until = Date.now() + 5000;
          while (social.active.has(ids[1]) && Date.now() < until)
            await new Promise((r) => setTimeout(r, 10));
          assert.equal(social.active.has(ids[1]), false);
          assert.equal(social.tradeFor(ids[0]), undefined);
          assert.deepEqual(social.partyFor(ids[0])!.members, [ids[0]]);
        },
      );
    } finally {
      for (const ws of sockets) ws.terminate();
      await service?.close();
      await db.close();
    }
  },
);
