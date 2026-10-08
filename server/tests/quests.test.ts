import test from "node:test";
import assert from "node:assert/strict";
import { createCharacter, makeItem, items } from "../src/rules.js";
import { economyRules } from "../src/economy.js";
import {
  acceptQuest,
  recordQuestKill,
  claimQuest,
  validJournal,
  type QuestCharacter,
} from "../src/quests.js";

function ready(): QuestCharacter {
  const state: QuestCharacter = createCharacter("Mision", "warrior");
  acceptQuest(state, "silk_on_the_road");
  for (let i = 0; i < 3; i++) recordQuestKill(state, "spider", "village");
  return state;
}
test("quest journal accepts legacy saves and rejects malformed or forged progress", () => {
  assert.equal(validJournal(undefined), true);
  for (const value of [
    null,
    [],
    { unknown: { kills: 0, claimed: false } },
    { silk_on_the_road: { kills: 4, claimed: false } },
    { silk_on_the_road: { kills: 0, claimed: true } },
    { silk_on_the_road: { kills: 3, claimed: false, extra: true } },
  ])
    assert.equal(validJournal(value), false);
  assert.equal(validJournal(ready().quests), true);
});
test("quest acceptance requires predecessor and kill progress filters species/map and caps objective", () => {
  const state: QuestCharacter = createCharacter("Mision", "mage");
  recordQuestKill(state, "spider", "village");
  assert.equal(state.quests, undefined);
  assert.throws(() => acceptQuest(state, "fangs_in_the_mist"), /quest_locked/);
  acceptQuest(state, "silk_on_the_road");
  assert.throws(
    () => acceptQuest(state, "silk_on_the_road"),
    /already_accepted/,
  );
  assert.throws(() => claimQuest(state, "silk_on_the_road"), /not_ready/);
  recordQuestKill(state, "wolf", "village");
  recordQuestKill(state, "spider", "crypt");
  assert.equal(state.quests!.silk_on_the_road.kills, 0);
  for (let i = 0; i < 5; i++) recordQuestKill(state, "spider", "forest");
  assert.equal(state.quests!.silk_on_the_road.kills, 3);
});
test("quest rewards merge stacks and are claimable exactly once across serialization", () => {
  const state = ready();
  claimQuest(state, "silk_on_the_road");
  assert.equal(state.gold, 40);
  assert.equal(state.experience, 60);
  assert.equal(
    state.inventory.items.find((i) => i.definition === "potion")!.count,
    6,
  );
  const restored: QuestCharacter = JSON.parse(JSON.stringify(state)),
    before = structuredClone(restored);
  assert.throws(() => claimQuest(restored, "silk_on_the_road"), /not_ready/);
  assert.deepEqual(restored, before);
  acceptQuest(restored, "fangs_in_the_mist");
  recordQuestKill(restored, "wolf", "village");
  assert.equal(restored.quests!.fangs_in_the_mist.kills, 0);
  for (let i = 0; i < 2; i++) recordQuestKill(restored, "wolf", "forest");
  claimQuest(restored, "fangs_in_the_mist");
  assert.equal(restored.gold, 110);
  assert.equal(restored.level, 2);
  assert.ok(
    restored.inventory.items.some(
      (i) => i.definition === "boots" && i.rarity === "magic",
    ),
  );
  acceptQuest(restored, "oath_beneath_the_stone");
  recordQuestKill(restored, "guardian", "crypt");
  claimQuest(restored, "oath_beneath_the_stone");
  assert.equal(restored.gold, 230);
  assert.ok(
    restored.inventory.items.some(
      (i) => i.definition === "ring" && i.rarity === "excellent",
    ),
  );
});
test("failed quest reward preserves every field for full inventory and gold cap", () => {
  for (const mode of ["grid", "gold"]) {
    const state = ready();
    if (mode === "gold") state.gold = economyRules.gold_cap;
    else {
      state.inventory.items = state.inventory.items.filter((i) => i.x === -1);
      for (let y = 0; y < 6; y++)
        for (let x = 0; x < 8; x++) {
          const item = makeItem("potion", items.definitions.potion.stack);
          item.x = x;
          item.y = y;
          state.inventory.items.push(item);
        }
    }
    const before = structuredClone(state);
    assert.throws(
      () => claimQuest(state, "silk_on_the_road"),
      mode === "grid" ? /inventory_full/ : /gold_cap/,
    );
    assert.deepEqual(state, before);
  }
});
