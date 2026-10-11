import { resetCharacter } from "./rpg.js";
import { npcDefinitions } from "./content.js";
import { items } from "./rules.js";
import type { Character } from "./rules.js";
import { Navigation, geometry, mapsCatalog, type Point } from "./navigation.js";
import { Rejected } from "./store.js";
import { CombatSimulation } from "./combat.js";
import { WorldEconomy } from "./economy.js";
import { Social } from "./social.js";
import { npcShop } from "./content.js";
import { acceptQuest, claimQuest, questCatalog } from "./quests.js";
import { economyRules } from "./economy.js";
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
  readonly navigations = new Map<string, Navigation>(
    Object.entries(mapsCatalog.maps).map(([id, data]) => [
      id,
      new Navigation(data),
    ]),
  );
  readonly players = new Map<string, Actor>();
  readonly combat: CombatSimulation;
  readonly economy: WorldEconomy;
  readonly social: Social;
  tick = 0;
  quest(id: string, questId: string, claim: boolean) {
    const actor = this.players.get(id);
    if (!actor) throw new Rejected("not_in_world");
    if (actor.state.hp <= 0) throw new Rejected("dead");
    if (
      typeof questId !== "string" ||
      !Object.hasOwn(questCatalog.definitions, questId)
    )
      throw new Rejected("quest_missing");
    const quest = questCatalog.definitions[questId];
    const npc = this.geometryFor(actor.state.map_id).npcs.find(
      (n: any) => (n.npc_id ?? n.id) === quest.npc,
    );
    if (
      actor.state.map_id !== quest.map_id ||
      !npc ||
      Math.hypot(
        actor.state.position.x - npc.x,
        actor.state.position.y - npc.y,
      ) > economyRules.npc_range ||
      !this.combat.visible(actor.state.position, npc, actor.state.map_id)
    )
      throw new Rejected("npc_out_of_range");
    if (claim) claimQuest(actor.state, questId);
    else acceptQuest(actor.state, questId);
    return { quests: actor.state.quests };
  }
  geometryFor(mapId: string) {
    if (!Object.hasOwn(mapsCatalog.maps, mapId))
      throw new Rejected("invalid_map");
    return mapsCatalog.maps[mapId];
  }
  navigationFor(mapId: string) {
    const nav = this.navigations.get(mapId);
    if (!nav) throw new Rejected("invalid_map");
    return nav;
  }
  portal(id: string, portalId: string) {
    const actor = this.players.get(id);
    if (!actor) throw new Rejected("not_in_world");
    if (actor.state.hp <= 0) throw new Rejected("dead");
    const source = this.geometryFor(actor.state.map_id),
      portal = source.portals.find((p: any) => p.id === portalId);
    if (
      !portal ||
      Math.hypot(
        actor.state.position.x - portal.x,
        actor.state.position.y - portal.y,
      ) > mapsCatalog.portal_range ||
      !this.combat.visible(actor.state.position, portal, actor.state.map_id)
    )
      throw new Rejected("portal_out_of_range");
    if (!this.navigationFor(portal.target).safe(portal.arrival))
      throw new Rejected("invalid_portal");
    actor.state.map_id = portal.target;
    actor.state.position = { ...portal.arrival };
    actor.path = [];
    actor.destination = undefined;
    this.combat.cancel(id);
    return actor;
  }
  reset(id: string,npcId: string){
    const actor=this.players.get(id);
    if(!actor)throw new Rejected("not_in_world");
    const npc=this.geometryFor(actor.state.map_id).npcs.find((n:any)=>(n.npc_id??n.id)===npcId);
    if(!npc || npcDefinitions[npcId]?.type!=="reset" || Math.hypot(actor.state.position.x-npc.x,actor.state.position.y-npc.y)>economyRules.npc_range || !this.combat.visible(actor.state.position,npc,actor.state.map_id))throw new Rejected("npc_out_of_range");
    resetCharacter(actor.state);return {accepted:true};
  }
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
    if (!Object.hasOwn(mapsCatalog.maps, state.map_id)) {
      state.map_id = geometry.id;
    }
    if (!this.navigationFor(state.map_id).safe(state.position))
      state.position = { ...this.geometryFor(state.map_id).spawn };
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
    const navigation = this.navigationFor(actor.state.map_id);
    if (!navigation.bounded(destination))
      throw new Rejected("invalid_destination");
    if (manual) this.combat.cancel(id);
    const cell = navigation.cellAt(destination);
    if (
      actor.path.length &&
      actor.destination &&
      JSON.stringify(cell) ===
        JSON.stringify(navigation.cellAt(actor.destination))
    )
      return;
    const path = navigation.findPath(actor.state.position, destination);
    if (!path.length) {
      if (
        navigation.cellAt(actor.state.position).x === cell.x &&
        navigation.cellAt(actor.state.position).y === cell.y
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
      const navigation = this.navigationFor(actor.state.map_id);
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
        if (!navigation.safe(point)) {
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
  snapshot(mapId: string = "village") {
    return {
      tick: this.tick,
      map_id: mapId,
      enemies: this.combat.snapshot(mapId),
      events: this.combat.events.filter((event) => event.map_id === mapId),
      ground: this.economy.snapshot(mapId),
      players: [...this.players.values()]
        .filter((actor) => actor.state.map_id === mapId)
        .map((actor) => ({
          id: actor.id,
          name: actor.state.name,
          class_id: actor.state.class_id,
          level: actor.state.level,
          hp: actor.state.hp,
          max_hp: actor.state.stats.max_hp,
          weapon_equipped: Boolean(actor.state.inventory.equipment.weapon),
          equipped_visuals: Object.entries(actor.state.inventory.equipment).flatMap(([slot,uid])=>{
            const item=actor.state.inventory.items.find(i=>i.uid===uid);
            const visual=item?items.definitions[item.definition].equipped_visual:undefined;
            return visual?.path?[{...visual,slot}]:[];
          }),
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
