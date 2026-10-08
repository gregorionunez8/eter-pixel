import test from "node:test";
import assert from "node:assert/strict";
import { createCharacter, makeItem } from "../src/rules.js";
import {
  add,
  find,
  move,
  equip,
  unequip,
  remove,
  consume,
  valid,
  refresh,
} from "../src/inventory.js";
import { AuthoritativeWorld } from "../src/world.js";

function fixture(classId = "warrior", roll = 0.2) {
  const world = new AuthoritativeWorld(
      () => 0.2,
      () => roll,
    ),
    actor = world.join("account", {
      id: "actor",
      state: createCharacter("Mercado", classId),
      revision: 0,
    });
  return { world, actor };
}
test("drag equipped item into grid atomically unequips and validates destination", () => {
  const { world, actor } = fixture();
  const sword = makeItem("bronze_sword", 1, "magic");
  add(actor.state.inventory, sword);
  equip(actor.state, sword.uid);
  const before = structuredClone(actor.state);
  assert.throws(
    () => world.economy.move(actor.id, sword.uid, 0, 0),
    /invalid_placement/,
  );
  assert.deepEqual(actor.state, before);
  world.economy.move(actor.id, sword.uid, 3, 3);
  assert.equal(actor.state.inventory.equipment.weapon, undefined);
  assert.equal(find(actor.state.inventory, sword.uid).x, 3);
  assert.equal(find(actor.state.inventory, sword.uid).y, 3);
  assert.ok(valid(actor.state.inventory, "warrior"));
  assert.ok(Number(actor.state.stats.attack) < Number(before.stats.attack));
});
test("server grid covers all sizes bounds collision duplicate UID and stack conservation", () => {
  const state = createCharacter("Acero", "warrior").inventory;
  for (const definition of ["ring", "boots", "helmet", "robe"]) {
    const item = makeItem(definition);
    add(state, item);
    assert.ok(valid(state, "warrior"));
    assert.throws(() => add(state, item), /invalid_item/);
  }
  const boots = state.items.find((item) => item.definition === "boots")!;
  for (const [x, y] of [
    [7, 5],
    [0, 0],
    [-1, 0],
    [0.5, 3],
  ]) {
    const before = structuredClone(state);
    assert.throws(() => move(state, boots.uid, x, y), /invalid_placement/);
    assert.deepEqual(state, before);
  }
  add(state, makeItem("potion", 7));
  assert.equal(
    state.items.find((item) => item.definition === "potion")!.count,
    10,
  );
  add(state, makeItem("potion", 5));
  assert.equal(
    state.items
      .filter((item) => item.definition === "potion")
      .reduce((sum, item) => sum + item.count, 0),
    15,
  );
});
test("equipment swaps one UID location, class restrictions and derived rarity/upgrade stats", () => {
  const character = createCharacter("Acero", "warrior"),
    sword = makeItem("bronze_sword", 1, "magic");
  add(character.inventory, sword);
  equip(character, sword.uid);
  assert.equal(character.inventory.equipment.weapon, sword.uid);
  assert.equal(find(character.inventory, sword.uid).x, -1);
  assert.equal(character.stats.attack, 36);
  find(character.inventory, sword.uid).upgrade = 2;
  refresh(character);
  assert.equal(character.stats.attack, 40);
  find(character.inventory, sword.uid).durability = 0;
  refresh(character);
  assert.equal(character.stats.attack, 27);
  unequip(character, "weapon");
  assert.ok(valid(character.inventory, "warrior"));
  const staff = makeItem("starter_staff");
  add(character.inventory, staff);
  const before = structuredClone(character);
  assert.throws(() => equip(character, staff.uid), /cannot_equip/);
  assert.deepEqual(character, before);
});
test("full grid and partial stack merges reject atomically without losing quantity", () => {
  const character = createCharacter("Acero", "warrior");
  while (true) {
    try {
      add(character.inventory, makeItem("ore", 20));
    } catch {
      break;
    }
  }
  const before = structuredClone(character);
  assert.throws(
    () => add(character.inventory, makeItem("potion", 10)),
    /inventory_full/,
  );
  assert.deepEqual(character, before, "partial potion merge rolled back");
  assert.throws(() => unequip(character, "weapon"), /inventory_full/);
  assert.deepEqual(character, before);
});
test("potions heal and decrement exactly once; non-consumables and full health rejected", () => {
  const character = createCharacter("Acero", "warrior"),
    potion = character.inventory.items[1];
  character.hp = 50;
  consume(character, potion.uid);
  assert.equal(character.hp, 106);
  assert.equal(potion.count, 2);
  const before = structuredClone(character);
  assert.throws(
    () => consume(character, character.inventory.equipment.weapon),
    /cannot_consume/,
  );
  assert.deepEqual(character, before);
  character.hp = 160;
  assert.throws(() => consume(character, potion.uid), /cannot_consume/);
});
test("buy sell repair upgrade use server price stock range and gold, repeated sale is rejected", () => {
  const { world, actor } = fixture();
  actor.state.position = { x: 1008, y: 560 };
  actor.state.gold = 1000;
  world.economy.buy(actor.id, "shop", "potion");
  assert.equal(actor.state.gold, 992);
  const potion = actor.state.inventory.items[1];
  assert.equal(potion.count, 4);
  world.economy.sell(actor.id, "shop", potion.uid);
  assert.equal(actor.state.gold, 1004);
  const before = structuredClone(actor.state);
  assert.throws(
    () => world.economy.sell(actor.id, "shop", potion.uid),
    /item_missing/,
  );
  assert.deepEqual(actor.state, before);
  assert.throws(
    () => world.economy.buy(actor.id, "shop", "bronze_sword"),
    /not_in_stock/,
  );
  assert.deepEqual(actor.state, before);
  assert.throws(
    () =>
      world.economy.sell(
        actor.id,
        "shop",
        actor.state.inventory.equipment.weapon,
      ),
    /equipped_item/,
  );
  actor.state.position = { x: 1104, y: 688 };
  const weapon = find(
    actor.state.inventory,
    actor.state.inventory.equipment.weapon,
  );
  weapon.durability = 90;
  world.economy.repair(actor.id, weapon.uid);
  assert.equal(weapon.durability, 100);
  assert.equal(actor.state.gold, 994);
  assert.deepEqual(world.economy.upgrade(actor.id, weapon.uid), {
    success: true,
    cost: 20,
  });
  assert.equal(weapon.upgrade, 1);
  assert.equal(actor.state.stats.attack, 29);
  actor.state.position = { x: 784, y: 592 };
  const distant = structuredClone(actor.state);
  assert.throws(
    () => world.economy.buy(actor.id, "shop", "potion"),
    /npc_out_of_range/,
  );
  assert.deepEqual(actor.state, distant);
});
test("economy rejects insufficient funds, full inventory, dead actor and invalid ownership unchanged", () => {
  const { world, actor } = fixture();
  actor.state.position = { x: 1008, y: 560 };
  const before = structuredClone(actor.state);
  assert.throws(
    () => world.economy.buy(actor.id, "shop", "potion"),
    /insufficient_gold/,
  );
  assert.deepEqual(actor.state, before);
  assert.throws(
    () => world.economy.equip(actor.id, "ffffffffffffffffffffffff"),
    /item_missing/,
  );
  assert.deepEqual(actor.state, before);
  actor.state.gold = 1000;
  while (true) {
    try {
      add(actor.state.inventory, makeItem("ore", 20));
    } catch {
      break;
    }
  }
  const full = structuredClone(actor.state);
  assert.throws(
    () => world.economy.buy(actor.id, "shop", "robe"),
    /inventory_full/,
  );
  assert.deepEqual(actor.state, full);
  actor.state.hp = 0;
  assert.throws(
    () => world.economy.drop(actor.id, actor.state.inventory.items[1].uid),
    /dead/,
  );
});
test("upgrade failure downgrade and +15 cap consume only configured costs", () => {
  const { world, actor } = fixture("warrior", 0.99);
  actor.state.position = { x: 1104, y: 688 };
  actor.state.gold = 1000;
  const item = find(
    actor.state.inventory,
    actor.state.inventory.equipment.weapon,
  );
  assert.ok(world.economy.upgrade(actor.id, item.uid).success);
  assert.equal(item.upgrade, 1);
  assert.equal(world.economy.upgrade(actor.id, item.uid).success, false);
  assert.equal(item.upgrade, 0);
  assert.equal(actor.state.gold, 945);
  item.upgrade = 15;
  const before = structuredClone(actor.state);
  assert.throws(
    () => world.economy.upgrade(actor.id, item.uid),
    /cannot_upgrade/,
  );
  assert.deepEqual(actor.state, before);
});
test("drop pickup keeps UID, guards range and protected owner, no second pickup", () => {
  const { world, actor } = fixture(),
    uid = actor.state.inventory.equipment.weapon;
  world.economy.drop(actor.id, uid);
  assert.equal(world.economy.ground.get(uid)!.item!.uid, uid);
  assert.equal(actor.state.inventory.equipment.weapon, undefined);
  const other = world.join("other", {
    id: "other",
    state: createCharacter("Bruma", "mage"),
    revision: 0,
  });
  assert.throws(() => world.economy.pickup(other.id, uid), /loot_protected/);
  actor.state.position = { x: 1008, y: 560 };
  assert.throws(
    () => world.economy.pickup(actor.id, uid),
    /pickup_out_of_range/,
  );
  actor.state.position = { x: 784, y: 592 };
  world.economy.pickup(actor.id, uid);
  assert.equal(find(actor.state.inventory, uid).uid, uid);
  assert.equal(world.economy.ground.size, 0);
  assert.throws(() => world.economy.pickup(actor.id, uid), /ground_missing/);
});
test("gold cap and full-grid pickup preserve ground on rejection; expiry removes it", () => {
  const { world, actor } = fixture();
  actor.state.gold = 1_000_000_000;
  const gold = world.economy.spawn({ gold: 1, position: actor.state.position });
  assert.throws(() => world.economy.pickup(actor.id, gold.id), /gold_limit/);
  assert.ok(world.economy.ground.has(gold.id));
  while (true) {
    try {
      add(actor.state.inventory, makeItem("ore", 20));
    } catch {
      break;
    }
  }
  const ground = world.economy.spawn({
    item: makeItem("robe"),
    position: actor.state.position,
  });
  assert.throws(
    () => world.economy.pickup(actor.id, ground.id),
    /inventory_full/,
  );
  assert.ok(world.economy.ground.has(ground.id));
  ground.expiresAt = Date.now() - 1;
  world.economy.expire();
  assert.equal(world.economy.ground.has(ground.id), false);
});
test("real monster kill mints loot once and training never mints rewards", () => {
  const { world, actor } = fixture("warrior", 0.2),
    monster = world.combat.enemies.get("monster-0")!;
  actor.state.position = { x: monster.position.x, y: monster.position.y - 32 };
  actor.state.stats.attack = 10000;
  world.combat.select(actor.id, monster.id);
  world.step(0.05);
  assert.equal(monster.hp, 0);
  assert.equal(world.economy.ground.size, 2);
  const count = world.economy.ground.size;
  for (let tick = 0; tick < 20; tick++) world.step(0.05);
  assert.equal(world.economy.ground.size, count);
  const initialGold = actor.state.gold;
  for (const ground of [...world.economy.ground.values()]) {
    actor.state.position = { ...ground.position };
    world.economy.pickup(actor.id, ground.id);
  }
  assert.ok(actor.state.gold > initialGold);
  assert.ok(
    actor.state.inventory.items.some((item) => item.definition === "ore"),
  );
  const training = world.combat.enemies.get("training-24")!;
  actor.state.position = {
    x: training.position.x,
    y: training.position.y - 32,
  };
  actor.state.stats.attack = 10000;
  world.combat.select(actor.id, training.id);
  world.step(0.05);
  assert.equal(training.hp, 0);
  assert.equal(world.economy.ground.size, 0);
});
test("loot offsets inside a building are corrected to walkable ground", () => {
  const { world } = fixture();
  const ground = world.economy.spawn({
    gold: 5,
    position: { x: 1008, y: 480 },
  });
  assert.ok(world.navigation.safe(ground.position));
  assert.notDeepEqual(ground.position, { x: 1008, y: 480 });
});
test("cooldown and death timers survive removing and rejoining actor state", () => {
  const { world, actor } = fixture("mage"),
    target = world.combat.enemies.get("training-24")!;
  actor.state.position = { x: target.position.x, y: target.position.y - 64 };
  world.combat.select(actor.id, target.id);
  world.combat.cast(actor.id, "fireball");
  const state = structuredClone(actor.state);
  world.remove(actor.id);
  world.join("account", { id: actor.id, state, revision: 0 });
  assert.throws(() => world.combat.cast(actor.id, "fireball"), /cooldown/);
  state.hp = 0;
  state.combat_state.respawn_deadline = Date.now() + 2000;
  world.remove(actor.id);
  const dead = world.join("account", { id: actor.id, state, revision: 0 });
  assert.ok(world.combat.battles.get(actor.id)!.respawn > 1);
  assert.throws(
    () => world.economy.consume(actor.id, state.inventory.items[1].uid),
    /dead/,
  );
  assert.equal(dead.state.hp, 0);
});
