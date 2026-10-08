import test from "node:test";
import assert from "node:assert/strict";
import { AuthoritativeWorld } from "../src/world.js";
import { createCharacter, makeItem } from "../src/rules.js";
import { Social } from "../src/social.js";
import { add, find } from "../src/inventory.js";
function fixture(count = 3) {
  const world = new AuthoritativeWorld(),
    players = [];
  for (let i = 0; i < count; i++)
    players.push(
      world.join("account" + i, {
        id: "player" + i,
        state: createCharacter("Jugador" + i, "warrior"),
        revision: 0,
      }),
    );
  return { world, players };
}
test("global/local chat routing uses authoritative distance, names and bounded plain text", () => {
  const { world, players } = fixture();
  players[2].state.position = { x: 784, y: 928 };
  const social = new Social(world, () => 1000);
  players.forEach((p) => social.join(p.id));
  assert.deepEqual(
    social.chat(players[0].id, "global", "[b]hola[/b]").recipients,
    players.map((p) => p.id),
  );
  assert.throws(() => social.chat(players[0].id, "local", "spam"), /chat_rate/);
  const local = social.chat(players[1].id, "local", " hola ");
  assert.deepEqual(local.recipients, [players[0].id, players[1].id]);
  assert.equal(local.message.sender, players[1].state.name);
  for (const text of ["", "a".repeat(161), "salto\nlinea", 123])
    assert.throws(
      () => social.chat(players[2].id, "global", text),
      /invalid_chat/,
    );
  assert.throws(
    () => social.chat(players[2].id, "private", "hola"),
    /invalid_chat/,
  );
});
test("party invitation is consent-based, leader-only, capped and cleared on disconnect", () => {
  const { world, players } = fixture(6),
    social = world.social;
  social.inviteParty(players[0].id, players[1].id);
  assert.equal(social.partyFor(players[1].id), undefined);
  social.replyParty(players[1].id, true);
  assert.deepEqual(social.partyFor(players[0].id)!.members, [
    players[0].id,
    players[1].id,
  ]);
  assert.throws(
    () => social.inviteParty(players[1].id, players[2].id),
    /party_unavailable/,
  );
  for (let i = 2; i < 5; i++) {
    social.inviteParty(players[0].id, players[i].id);
    social.replyParty(players[i].id, true);
  }
  assert.throws(
    () => social.inviteParty(players[0].id, players[5].id),
    /party_unavailable/,
  );
  social.remove(players[0].id);
  assert.equal(social.partyFor(players[1].id)!.leader, players[1].id);
  assert.equal(social.snapshot(players[1].id).players.length, 5);
  social.leaveParty(players[1].id);
  assert.equal(social.partyFor(players[1].id), undefined);
});
test("social invitations expire and rejected invitations do not create membership", () => {
  const { world, players } = fixture();
  let now = 0;
  const social = new Social(world, () => now);
  players.forEach((p) => social.join(p.id));
  social.inviteParty("player0", "player1");
  social.replyParty("player1", false);
  assert.equal(social.partyFor("player0"), undefined);
  social.inviteParty("player0", "player1");
  now = 30001;
  social.reconcile();
  assert.throws(() => social.replyParty("player1", true), /invitation_missing/);
  social.inviteTrade("player0", "player1");
  now += 30001;
  social.reconcile();
  assert.equal(social.tradeFor("player0"), undefined);
});
test("trade requires matching revision, both confirmations and atomic inventory/gold exchange", () => {
  const { world, players } = fixture(),
    social = world.social;
  players[0].state.gold = 100;
  players[1].state.gold = 50;
  const robe = makeItem("robe");
  add(players[0].state.inventory, robe);
  social.inviteTrade("player0", "player1");
  social.replyTrade("player1", true);
  let trade = social.tradeFor("player0")!;
  assert.throws(
    () => social.offer("player0", [robe.uid, robe.uid], 0, trade.revision),
    /invalid_offer/,
  );
  assert.throws(
    () =>
      social.offer(
        "player0",
        [players[0].state.inventory.equipment.weapon],
        0,
        trade.revision,
      ),
    /equipped_offer/,
  );
  social.offer("player0", [robe.uid], 10, trade.revision);
  assert.throws(() => social.accept("player1", 1), /trade_revision/);
  assert.equal(social.accept("player0", trade.revision).ready, false);
  social.offer("player1", [], 5, trade.revision);
  assert.deepEqual(trade.accepted, []);
  social.accept("player0", trade.revision);
  assert.equal(social.accept("player1", trade.revision).ready, true);
  social.exchange(trade.id);
  social.complete(trade.id);
  assert.equal(players[0].state.gold, 95);
  assert.equal(players[1].state.gold, 55);
  assert.throws(
    () => find(players[0].state.inventory, robe.uid),
    /item_missing/,
  );
  assert.equal(find(players[1].state.inventory, robe.uid).definition, "robe");
  assert.equal(social.snapshot("player2").trade, null);
});
test("full recipient grid and gold cap leave both inventories and balances untouched", () => {
  const { world, players } = fixture(),
    social = world.social;
  const potion = makeItem("potion", 10),
    robe = makeItem("robe");
  players[1].state.inventory.items = players[1].state.inventory.items.filter(
    (i) => i.x === -1,
  );
  for (let i = 0; i < 48; i++)
    add(players[1].state.inventory, makeItem("ring"));
  add(players[0].state.inventory, robe);
  social.inviteTrade("player0", "player1");
  social.replyTrade("player1", true);
  const trade = social.tradeFor("player0")!;
  social.offer("player0", [robe.uid], 0, trade.revision);
  social.accept("player0", trade.revision);
  social.accept("player1", trade.revision);
  const before = players.map((p) => structuredClone(p.state));
  assert.throws(() => social.exchange(trade.id), /inventory_full/);
  assert.deepEqual(
    players.map((p) => p.state),
    before,
  );
  social.cancel("player0");
  players[0].state.gold = 1000000000;
  players[1].state.gold = 1;
  social.inviteTrade("player0", "player1");
  social.replyTrade("player1", true);
  const capped = social.tradeFor("player0")!;
  social.offer("player1", [], 1, capped.revision);
  social.accept("player0", capped.revision);
  social.accept("player1", capped.revision);
  assert.throws(() => social.exchange(capped.id), /gold_cap/);
  assert.equal(players[1].state.gold, 1);
});
test("offered item mutation, death, range and disconnect cancel trade before any exchange", () => {
  for (const reason of ["item", "dead", "range", "disconnect"]) {
    const { world, players } = fixture(),
      social = world.social;
    const robe = makeItem("robe");
    add(players[0].state.inventory, robe);
    social.inviteTrade("player0", "player1");
    social.replyTrade("player1", true);
    const trade = social.tradeFor("player0")!;
    social.offer("player0", [robe.uid], 0, trade.revision);
    social.accept("player0", trade.revision);
    if (reason === "item") find(players[0].state.inventory, robe.uid).upgrade++;
    if (reason === "dead") players[1].state.hp = 0;
    if (reason === "range") players[1].state.position.x += 96;
    if (reason === "disconnect") social.remove("player1");
    social.reconcile();
    assert.equal(social.tradeFor("player0"), undefined, reason);
    assert.equal(find(players[0].state.inventory, robe.uid).definition, "robe");
  }
});
