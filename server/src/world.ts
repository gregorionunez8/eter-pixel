import type { Character } from "./rules.js";
import { Navigation, geometry, type Point } from "./navigation.js";
import { Rejected } from "./store.js";
import { CombatSimulation } from "./combat.js";
import { WorldEconomy } from "./economy.js";
import { Social } from "./social.js";
type Actor = {
  id: string;
  account: string;
  state: Character;
  revision: number;
  path: Point[];
  destination?: Point;
};
export class AuthoritativeWorld {
  readonly navigation = new Navigation();
  readonly players = new Map<string, Actor>();
  readonly combat: CombatSimulation;
  readonly economy: WorldEconomy;
  readonly social: Social;
  tick = 0;
  constructor(
    random: () => number = Math.random,
    lootRandom: () => number = Math.random,
  ) {
    this.combat = new CombatSimulation(this, random);
    this.economy = new WorldEconomy(this, lootRandom);
    this.social = new Social(this);
  }
  join(
    account: string,
    loaded: { id: string; state: Character; revision: number },
  ) {
    if (this.players.has(loaded.id)) throw new Rejected("character_in_use");
    const state = structuredClone(loaded.state);
    if (state.map_id !== geometry.id || !this.navigation.safe(state.position)) {
      state.map_id = geometry.id;
      state.position = { ...geometry.spawn };
    }
    const actor: Actor = {
      id: loaded.id,
      account,
      state,
      revision: loaded.revision,
      path: [],
    };
    this.players.set(actor.id, actor);
    this.combat.join(actor.id);
    this.social.join(actor.id);
    return actor;
  }
  move(id: string, destination: Point, manual = true) {
    const actor = this.players.get(id);
    if (!actor) throw new Rejected("not_in_world");
    if (actor.state.hp <= 0) throw new Rejected("dead");
    if (!this.navigation.bounded(destination))
      throw new Rejected("invalid_destination");
    if (manual) this.combat.cancel(id);
    const cell = this.navigation.cellAt(destination);
    if (
      actor.path.length &&
      actor.destination &&
      JSON.stringify(cell) ===
        JSON.stringify(this.navigation.cellAt(actor.destination))
    )
      return;
    const path = this.navigation.findPath(actor.state.position, destination);
    if (!path.length) {
      if (
        this.navigation.cellAt(actor.state.position).x === cell.x &&
        this.navigation.cellAt(actor.state.position).y === cell.y
      )
        return;
      throw new Rejected("unreachable");
    }
    if (
      actor.path.length &&
      actor.destination &&
      path.at(-1)!.x === actor.destination.x &&
      path.at(-1)!.y === actor.destination.y
    )
      return;
    actor.path = path;
    actor.destination = { ...path.at(-1)! };
  }
  step(delta: number) {
    if (!Number.isFinite(delta) || delta < 0 || delta > 0.1)
      throw new Error("invalid server delta");
    this.tick++;
    for (const actor of this.players.values()) {
      if (actor.state.hp <= 0) {
        actor.path = [];
        continue;
      }
      let budget = Number(actor.state.stats.speed) * delta;
      while (actor.path.length && budget > 0) {
        const current = actor.state.position,
          target = actor.path[0],
          dx = target.x - current.x,
          dy = target.y - current.y,
          length = Math.hypot(dx, dy);
        if (length < 0.001) {
          actor.path.shift();
          continue;
        }
        const moved = Math.min(length, budget, 7);
        const point = {
          x: current.x + (dx / length) * moved,
          y: current.y + (dy / length) * moved,
        };
        if (!this.navigation.safe(point)) {
          actor.path = [];
          break;
        }
        actor.state.position = point;
        budget -= moved;
        if (moved === length) actor.path.shift();
      }
    }
    this.combat.step(delta);
    this.economy.expire();
    this.social.reconcile();
  }
  snapshot() {
    return {
      tick: this.tick,
      map_id: geometry.id,
      enemies: this.combat.snapshot(),
      events: this.combat.events,
      ground: this.economy.snapshot(),
      players: [...this.players.values()].map((actor) => ({
        id: actor.id,
        name: actor.state.name,
        class_id: actor.state.class_id,
        level: actor.state.level,
        hp: actor.state.hp,
        max_hp: actor.state.stats.max_hp,
        weapon_equipped: Boolean(actor.state.inventory.equipment.weapon),
        position: { ...actor.state.position },
      })),
    };
  }
  remove(id: string) {
    this.social.remove(id);
    const actor = this.players.get(id);
    this.players.delete(id);
    this.combat.remove(id);
    return actor;
  }
}
