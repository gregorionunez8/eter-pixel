import test from "node:test";
import assert from "node:assert/strict";
import { AuthoritativeWorld } from "../src/world.js";
import { createCharacter } from "../src/rules.js";
import {
  combatRules,
  hit,
  derive,
  gainExperience,
  requiredExperience,
  allocate,
  deathPenalty,
} from "../src/rpg.js";

function fixture(classId = "warrior") {
  const world = new AuthoritativeWorld(() => 0.2),
    actor = world.join("account", {
      id: "actor",
      state: createCharacter("Acero", classId),
      revision: 0,
    });
  const target = world.combat.enemies.get("training-24")!;
  actor.state.position = { x: target.position.x, y: target.position.y - 32 };
  return { world, actor, target };
}
function runUntil(
  world: AuthoritativeWorld,
  predicate: () => boolean,
  max = 1000,
) {
  for (let tick = 0; tick < max && !predicate(); tick++) world.step(0.05);
  assert.ok(predicate(), "server tick condition reached");
}
test("central damage formulas physical/magic/miss/critical/clamps", () => {
  const attack = { attack: 30, accuracy: 90 },
    defense = { defense: 10, evasion: 5 };
  assert.equal(hit(attack, defense, "physical", 1, 0.2, 0.2).damage, 20);
  assert.equal(hit(attack, defense, "magic", 1, 0.2, 0.2).damage, 24);
  assert.equal(hit(attack, defense, "physical", 1, 0.2, 0.01).damage, 36);
  assert.equal(hit(attack, defense, "physical", 1, 0.99, 0.2).damage, 0);
  assert.equal(
    hit(
      { ...attack, attack: 1 },
      { ...defense, defense: 1000 },
      "physical",
      1,
      0.2,
      0.2,
    ).damage,
    1,
  );
});
for (const classId of ["warrior", "mage", "elf"])
  for (const skillId of combatRules.classes[classId].skills as string[]) {
    test("real server skill " + skillId, () => {
      const { world, actor, target } = fixture(classId),
        skill = combatRules.skills[skillId];
      actor.state.hp = 50;
      world.combat.select(actor.id, target.id);
      const mana = actor.state.mana;
      world.combat.cast(actor.id, skillId);
      assert.equal(actor.state.mana, mana - skill.mana);
      assert.equal(
        world.combat.battles.get(actor.id)!.cooldowns[skillId],
        skill.cooldown,
      );
      if (skill.mode === "heal")
        assert.equal(
          actor.state.hp,
          50 +
            Math.floor(Number(actor.state.stats.max_hp) * skill.heal_fraction),
        );
      else assert.ok(target.hp < target.config.hp);
      const before = structuredClone(actor.state);
      assert.throws(() => world.combat.cast(actor.id, skillId), /cooldown/);
      assert.deepEqual(actor.state, before, "cooldown no charge");
      assert.ok(
        world.combat.events.some(
          (event) => event.kind === "skill" && event.skill === skillId,
        ),
      );
    });
  }
test("cast validation rejects wrong class, mana, range, walls, dead target and dead caster atomically", () => {
  const { world, actor, target } = fixture();
  const unchanged = (action: () => void, code: RegExp) => {
    const before = structuredClone(actor.state);
    assert.throws(action, code);
    assert.deepEqual(actor.state, before);
  };
  unchanged(() => world.combat.cast(actor.id, "fireball"), /invalid_skill/);
  unchanged(() => world.combat.cast(actor.id, "power_strike"), /out_of_range/);
  world.combat.select(actor.id, target.id);
  actor.state.mana = 0;
  unchanged(
    () => world.combat.cast(actor.id, "power_strike"),
    /insufficient_mana/,
  );
  actor.state.mana = 44;
  actor.state.position = { x: 784, y: 592 };
  unchanged(() => world.combat.cast(actor.id, "power_strike"), /out_of_range/);
  actor.state.position = { x: 1008, y: 560 };
  target.position = { x: 1008, y: 496 };
  assert.equal(
    world.combat.visible(actor.state.position, target.position),
    false,
  );
  const mage = fixture("mage");
  mage.actor.state.position = { x: 1008, y: 560 };
  mage.target.position = { x: 1008, y: 496 };
  mage.world.combat.select(mage.actor.id, mage.target.id);
  assert.throws(
    () => mage.world.combat.cast(mage.actor.id, "fireball"),
    /out_of_range/,
  );
  target.hp = 0;
  unchanged(() => world.combat.select(actor.id, target.id), /invalid_target/);
  actor.state.hp = 0;
  unchanged(() => world.combat.cast(actor.id, "power_strike"), /dead/);
});
test("multishot affects at most three and area affects all in range", () => {
  const { world, actor, target } = fixture("elf");
  let index = 0;
  for (const enemy of world.combat.enemies.values()) {
    enemy.position = {
      x: target.position.x + (index++ % 3) * 16,
      y: target.position.y,
    };
  }
  world.combat.cast(actor.id, "multishot");
  assert.equal(
    [...world.combat.enemies.values()].filter(
      (enemy) => enemy.hp < enemy.config.hp,
    ).length,
    3,
  );
  const second = fixture("mage");
  for (const enemy of second.world.combat.enemies.values())
    enemy.position = { ...second.target.position };
  second.world.combat.cast(second.actor.id, "nova");
  assert.equal(
    [...second.world.combat.enemies.values()].filter(
      (enemy) => enemy.hp < enemy.config.hp,
    ).length,
    9,
  );
});
test("pursuit autoattack kills a real spider once, gains XP and respawns", () => {
  const world = new AuthoritativeWorld(() => 0.2),
    actor = world.join("account", {
      id: "actor",
      state: createCharacter("Acero", "warrior"),
      revision: 0,
    }),
    spider = world.combat.enemies.get("monster-0")!;
  for (const enemy of [...world.combat.enemies.values()])
    if (enemy !== spider) world.combat.enemies.delete(enemy.id);
  actor.state.position = { x: spider.home.x - 96, y: spider.home.y };
  world.combat.select(actor.id, spider.id);
  runUntil(world, () => spider.hp === 0);
  assert.equal(actor.state.experience, 24);
  assert.ok(actor.state.hp > 0);
  const awarded = actor.state.experience;
  for (let tick = 0; tick < 50; tick++) world.step(0.05);
  assert.equal(actor.state.experience, awarded);
  assert.equal(
    world.combat.events.filter((event) => event.kind === "defeated").length,
    1,
  );
  runUntil(world, () => spider.hp > 0);
  assert.deepEqual(spider.position, spider.home);
  assert.equal(spider.hp, 65);
  assert.ok(
    actor.state.inventory.items[0].durability < 100,
    "combat weapon wears",
  );
});
test("training never rewards XP; death penalty and player respawn run on server clock", () => {
  const { world, actor, target } = fixture();
  actor.state.hp = 1;
  actor.state.experience = 59;
  world.combat.select(actor.id, target.id);
  runUntil(world, () => actor.state.hp === 0);
  assert.equal(actor.state.experience, 57);
  assert.equal(actor.path.length, 0);
  assert.throws(() => world.move(actor.id, { x: 800, y: 600 }), /dead/);
  runUntil(world, () => actor.state.hp > 0);
  assert.equal(actor.state.hp, Number(actor.state.stats.max_hp));
  assert.deepEqual(actor.state.position, { x: 784, y: 592 });
  const training = fixture();
  training.actor.state.stats.attack = 10000;
  training.world.combat.select(training.actor.id, training.target.id);
  training.world.step(0.05);
  assert.equal(training.target.hp, 0);
  assert.equal(training.actor.state.experience, 0);
});
for (const name of ["spider", "goblin", "wolf", "skeleton", "orc", "guardian"])
  test(
    "server AI " + name + " detects attacks returns and avoids solids",
    () => {
      const world = new AuthoritativeWorld(() => 0.2),
        actor = world.join("account", {
          id: "actor",
          state: createCharacter("Acero", "warrior"),
          revision: 0,
        });
      const enemy = [...world.combat.enemies.values()].find(
        (enemy) => enemy.species === name,
      )!;
      for (const other of [...world.combat.enemies.values()])
        if (other !== enemy) world.combat.enemies.delete(other.id);
      actor.state.position = { x: enemy.home.x, y: enemy.home.y + 64 };
      assert.ok(world.navigation.safe(actor.state.position));
      assert.ok(world.combat.visible(enemy.position, actor.state.position));
      actor.state.hp = 10000;
      runUntil(world, () => enemy.phase === "attack");
      runUntil(world, () => actor.state.hp < 10000);
      actor.state.position = { x: 784, y: 592 };
      for (let tick = 0; tick < 300; tick++) {
        world.step(0.05);
        assert.ok(world.navigation.safe(enemy.position, enemy.config.radius));
      }
      assert.equal(enemy.phase, "idle");
      assert.deepEqual(enemy.position, enemy.home);
      assert.equal(enemy.hp, enemy.config.hp);
    },
  );
test("progression levels multiple times, allocations and death penalty use shared rules", () => {
  for (const classId of ["warrior", "mage", "elf"]) {
    const state = createCharacter("Acero", classId);
    assert.equal(gainExperience(state, 80), 1);
    assert.equal(state.level, 2);
    assert.equal(state.attribute_points, 5);
    const hp = state.hp;
    allocate(state, "vitality", 2);
    assert.equal(state.hp, hp + 10);
    assert.equal(state.attribute_points, 3);
    const before = structuredClone(state);
    for (const [attribute, amount] of [
      ["gold", 1],
      ["strength", 0],
      ["strength", 4],
      ["strength", 0.5],
    ] as [string, number][]) {
      assert.throws(
        () => allocate(state, attribute, amount),
        /invalid_allocation/,
      );
      assert.deepEqual(state, before);
    }
    assert.deepEqual(state.stats, derive(state));
    state.experience = 79;
    assert.equal(deathPenalty(state), 3);
    assert.ok(requiredExperience(20) > requiredExperience(10));
    gainExperience(state, 10_000_000);
    assert.equal(state.level, 100);
    assert.equal(state.experience, 0);
  }
});
test("regeneration restores resources only after server delay", () => {
  const world = new AuthoritativeWorld(() => 0.2),
    actor = world.join("account", {
      id: "actor",
      state: createCharacter("Acero", "warrior"),
      revision: 0,
    });
  actor.state.hp = 50;
  actor.state.mana = 5;
  for (let tick = 0; tick < 60; tick++) world.step(0.05);
  assert.equal(actor.state.hp, 50);
  assert.equal(actor.state.mana, 5);
  for (let tick = 0; tick < 60; tick++) world.step(0.05);
  assert.ok(actor.state.hp > 50);
  assert.ok(actor.state.mana > 5);
});
