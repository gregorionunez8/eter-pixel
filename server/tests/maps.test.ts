import test from "node:test";
import assert from "node:assert/strict";
import { Navigation, mapsCatalog } from "../src/navigation.js";
import { AuthoritativeWorld } from "../src/world.js";
import { createCharacter } from "../src/rules.js";
test("three map geometries have safe spawns, reciprocal portals and reachable combat zones", () => {
  const maps = mapsCatalog.maps;
  assert.deepEqual(Object.keys(maps), ["village", "forest", "crypt"]);
  for (const data of Object.values(maps) as any[]) {
    const nav = new Navigation(data);
    assert.ok(nav.safe(data.spawn), data.id + " spawn");
    for (const portal of data.portals) {
      for (const point of [portal, portal.arrival]) {
        assert.equal(point.x % data.tile, data.tile / 2);
        assert.equal(point.y % data.tile, data.tile / 2);
      }
      assert.ok(nav.safe(portal), portal.id + " walkable portal");
      assert.ok(
        nav.findPath(data.spawn, portal).length,
        portal.id + " reachable",
      );
      const target = maps[portal.target],
        destination = new Navigation(target);
      assert.ok(
        destination.safe(portal.arrival),
        portal.id + " safe destination",
      );
      assert.ok(
        target.portals.some((p: any) => p.target === data.id),
        portal.id + " return portal",
      );
    }
    for (const monster of data.monsters) {
      assert.ok(
        nav.safe(monster),
        data.id + " safe monster " + monster.species,
      );
      assert.ok(
        nav.findPath(data.spawn, monster).length,
        data.id + " reachable monster " + monster.species,
      );
    }
    for (const rect of data.obstacles)
      assert.equal(
        nav.walkable({ x: rect.x, y: rect.y }),
        false,
        data.id + " solid obstacle",
      );
  }
});
test("portal validation rejects distant/dead/foreign IDs and preserves cooldown while changing map", () => {
  const world = new AuthoritativeWorld(),
    actor = world.join("a", {
      id: "a",
      state: createCharacter("Camino", "mage"),
      revision: 0,
    });
  const original = structuredClone(actor.state);
  assert.throws(
    () => world.portal("a", "village_forest"),
    /portal_out_of_range/,
  );
  assert.deepEqual(actor.state, original);
  actor.state.position = { x: 784, y: 976 };
  actor.state.hp = 0;
  assert.throws(() => world.portal("a", "village_forest"), /dead/);
  actor.state.hp = 100;
  assert.throws(() => world.portal("a", "forest_crypt"), /portal_out_of_range/);
  world.combat.battles.get("a")!.cooldowns.fireball = 2;
  world.move("a", { x: 784, y: 944 });
  world.portal("a", "village_forest");
  assert.equal(actor.state.map_id, "forest");
  assert.deepEqual(actor.state.position, { x: 176, y: 176 });
  assert.equal(actor.path.length, 0);
  assert.equal(world.combat.battles.get("a")!.cooldowns.fireball, 2);
  actor.state.position = { x: 1360, y: 800 };
  world.portal("a", "forest_crypt");
  assert.equal(actor.state.map_id, "crypt");
  world.portal("a", "crypt_forest");
  assert.equal(actor.state.map_id, "forest");
  actor.state.position = { x: 176, y: 176 };
  world.portal("a", "forest_village");
  assert.equal(actor.state.map_id, "village");
});
test("movement in each geometry obeys physics budget and safely reaches all portals", () => {
  for (const map of Object.values(mapsCatalog.maps) as any[]) {
    const world = new AuthoritativeWorld(),
      state = createCharacter("Andante", "warrior");
    state.map_id = map.id;
    state.position = { ...map.spawn };
    const actor = world.join("a", { id: "a", state, revision: 0 });
    world.combat.enemies.clear();
    for (const portal of map.portals) {
      world.move("a", portal);
      for (let tick = 0; tick < 4000 && actor.path.length; tick++) {
        const previous = { ...actor.state.position };
        world.step(0.05);
        assert.ok(
          world.navigationFor(map.id).safe(actor.state.position),
          map.id + " collision",
        );
        assert.ok(
          Math.hypot(
            actor.state.position.x - previous.x,
            actor.state.position.y - previous.y,
          ) <=
            Number(actor.state.stats.speed) * 0.05 + 0.001,
          map.id + " speed",
        );
      }
      assert.ok(
        Math.hypot(
          actor.state.position.x - portal.x,
          actor.state.position.y - portal.y,
        ) < 1,
        map.id + " arrival",
      );
    }
  }
});
test("map snapshots, combat target selection, AI, NPC and loot never cross maps", () => {
  const world = new AuthoritativeWorld(() => 0.2),
    first = world.join("a", {
      id: "a",
      state: createCharacter("Aldea", "mage"),
      revision: 0,
    }),
    state = createCharacter("Bosque", "warrior");
  state.map_id = "forest";
  state.position = { x: 400, y: 432 };
  const second = world.join("b", { id: "b", state, revision: 0 });
  assert.equal(world.snapshot().players.length, 1);
  assert.equal(world.snapshot("forest").players.length, 1);
  assert.equal(world.snapshot("forest").enemies.length, 6);
  assert.throws(
    () => world.combat.select("a", "forest-monster-0"),
    /invalid_target/,
  );
  const enemy = world.combat.enemies.get("forest-monster-0")!;
  first.state.position = { ...second.state.position };
  for (const other of [...world.combat.enemies.values()])
    if (other !== enemy) world.combat.enemies.delete(other.id);
  const hp = first.state.hp;
  for (let i = 0; i < 100; i++) world.step(0.05);
  assert.equal(first.state.hp, hp);
  assert.ok(second.state.hp < Number(second.state.stats.max_hp));
  second.state.position = { x: 784, y: 592 };
  first.state.position = { ...second.state.position };
  const gold = world.economy.spawn({
    gold: 5,
    position: second.state.position,
    map_id: "forest",
  });
  assert.equal(world.snapshot().ground.length, 0);
  assert.equal(world.snapshot("forest").ground.length, 1);
  assert.throws(
    () => world.economy.pickup("a", gold.id),
    /pickup_out_of_range/,
  );
  world.economy.pickup("b", gold.id);
  assert.equal(second.state.gold, 5);
  second.state.position = { x: 1008, y: 560 };
  assert.throws(
    () => world.economy.buy("b", "shop", "potion"),
    /npc_out_of_range/,
  );
});
