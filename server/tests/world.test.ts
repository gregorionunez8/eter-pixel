import test from "node:test";
import assert from "node:assert/strict";
import { createCharacter } from "../src/rules.js";
import { AuthoritativeWorld } from "../src/world.js";
import { geometry } from "../src/navigation.js";

test("authoritative movement follows server speed and shared collision geometry", () => {
  const world = new AuthoritativeWorld();
  const actor = world.join("account", {
    id: "actor",
    state: createCharacter("Acero", "warrior"),
    revision: 0,
  });
  const start = { ...actor.state.position };
  world.move(actor.id, { x: 1008, y: 560 });
  let travelled = 0;
  for (let frame = 0; frame < 200; frame++) {
    const previous = { ...actor.state.position };
    world.step(0.05);
    const moved = Math.hypot(
      actor.state.position.x - previous.x,
      actor.state.position.y - previous.y,
    );
    assert.ok(moved <= 112 * 0.05 + 0.00001, "server movement budget");
    assert.ok(
      world.navigation.safe(actor.state.position),
      "real footprint collision safety",
    );
    travelled += moved;
  }
  assert.ok(
    travelled > Math.hypot(start.x - 1008, start.y - 560),
    "route detours around tree",
  );
  assert.deepEqual(actor.state.position, { x: 1008, y: 560 });
});
test("all building destinations resolve to reachable safe ground", () => {
  const world = new AuthoritativeWorld();
  for (const obstacle of geometry.obstacles.filter(
    (entry: any) => entry.width > 1,
  )) {
    const actor = world.join("account", {
      id: String(obstacle.x) + "," + obstacle.y,
      state: createCharacter("Acero", "warrior"),
      revision: 0,
    });
    world.move(actor.id, {
      x: (obstacle.x + 1) * 32,
      y: (obstacle.y + 1) * 32,
    });
    for (let frame = 0; frame < 350; frame++) {
      world.step(0.05);
      assert.ok(world.navigation.safe(actor.state.position));
    }
    assert.equal(actor.path.length, 0, "arrives adjacent to building");
    world.remove(actor.id);
  }
});
test("diagonal routing does not cut obstacle corners and repeated destinations do not reverse", () => {
  const world = new AuthoritativeWorld();
  const actor = world.join("account", {
    id: "actor",
    state: createCharacter("Acero", "warrior"),
    revision: 0,
  });
  world.move(actor.id, { x: 1072, y: 688 });
  for (let frame = 0; frame < 200; frame++) {
    const path = actor.path;
    world.move(actor.id, { x: 1072, y: 688 });
    if (path.length)
      assert.equal(actor.path, path, "held input preserves current route");
    world.step(0.05);
    assert.ok(world.navigation.safe(actor.state.position));
  }
  assert.equal(actor.path.length, 0);
});
test("invalid coordinates, dead movement, client timestamps and duplicate joins cannot bypass authority", () => {
  const world = new AuthoritativeWorld(),
    state = createCharacter("Acero", "warrior");
  state.position = { x: 500, y: 480 };
  const actor = world.join("account", { id: "actor", state, revision: 0 });
  assert.deepEqual(
    actor.state.position,
    geometry.spawn,
    "unsafe saved position recovers spawn",
  );
  assert.throws(
    () => world.join("other", { id: "actor", state, revision: 0 }),
    /character_in_use/,
  );
  for (const destination of [
    { x: NaN, y: 1 },
    { x: Infinity, y: 1 },
    { x: -1, y: 1 },
    { x: 20000, y: 1 },
  ])
    assert.throws(
      () => world.move(actor.id, destination),
      /invalid_destination/,
    );
  actor.state.hp = 0;
  assert.throws(() => world.move(actor.id, { x: 800, y: 600 }), /dead/);
  assert.throws(() => world.step(5), /invalid server delta/);
  assert.throws(() => world.step(-1), /invalid server delta/);
  assert.throws(() => world.move("missing", { x: 10, y: 10 }), /not_in_world/);
});
test("public snapshots include peers but exclude inventory and economic state", () => {
  const world = new AuthoritativeWorld();
  for (const id of ["first", "second"])
    world.join(id, {
      id,
      state: createCharacter(
        id === "first" ? "Acero" : "Bruma",
        id === "first" ? "warrior" : "mage",
      ),
      revision: 0,
    });
  const snapshot = world.snapshot();
  assert.equal(snapshot.players.length, 2);
  for (const player of snapshot.players) {
    assert.ok(!Object.hasOwn(player, "inventory"));
    assert.ok(!Object.hasOwn(player, "gold"));
  }
  world.remove("first");
  assert.equal(world.snapshot().players.length, 1);
});
