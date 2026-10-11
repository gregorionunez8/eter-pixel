import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { npcShop, applyBalance, balance } from "./content.js";
import { randomBytes } from "node:crypto";
import type { AuthoritativeWorld } from "./world.js";
import { geometry, type Point } from "./navigation.js";
import { items, makeItem, type Item } from "./rules.js";
import {
  add,
  find,
  equip,
  unequip,
  remove,
  move,
  consume,
  refresh,
  validItem,
} from "./inventory.js";
import { Rejected } from "./store.js";
import { recordQuestKill } from "./quests.js";
export const economyRules = applyBalance("economy",JSON.parse(
  readFileSync(resolve("../shared/economy.json"), "utf8"),
));
export type Ground = {
  id: string;
  map_id?: string;
  item?: Item;
  gold: number;
  position: Point;
  owner?: string;
  protectedUntil: number;
  expiresAt: number;
};
export class WorldEconomy {
  readonly ground = new Map<string, Ground>();
  constructor(
    private world: AuthoritativeWorld,
    private random: () => number = Math.random,
  ) {
    world.combat.onDefeated = (killer, enemy) => {
      const actor = world.players.get(killer);
      if (actor) recordQuestKill(actor.state, enemy.species, enemy.map_id);
      const loot = enemy.config.loot;
      if (this.random() < loot.chance) {
        const gold =
          loot.gold_min +
          Math.floor(this.random() * (loot.gold_max - loot.gold_min + 1));
        this.spawn({
          gold,
          position: { x: enemy.position.x - 16, y: enemy.position.y },
          owner: killer,
        });
      }
      let offset = 16;
      for (const drop of economyRules.drops[enemy.species] ?? [])
        if (this.random() < Math.min(1,drop.chance*(balance.monster?.drop_rate??1))) {
          const quantity=(drop.min_quantity??1)+Math.floor(this.random()*((drop.max_quantity??1)-(drop.min_quantity??1)+1));
          const item=makeItem(drop.item,quantity,drop.rarity??"normal");
          item.upgrade=(drop.min_upgrade??0)+Math.floor(this.random()*((drop.max_upgrade??0)-(drop.min_upgrade??0)+1));
          for(const option of drop.possible_options??[])if(typeof option==="object" && this.random()<(drop.option_chance??0))(item.options??={})[option.option]=option.value;
          this.spawn({
            item,
            position: { x: enemy.position.x + offset, y: enemy.position.y },
            owner: killer,
          });
          offset += 24;
        }
    };
  }
  private actor(id: string) {
    const actor = this.world.players.get(id);
    if (!actor) throw new Rejected("not_in_world");
    if (actor.state.hp <= 0) throw new Rejected("dead");
    return actor;
  }
  private npc(id: string, shop: string) {
    const actor = this.actor(id),
      npc = this.world
        .geometryFor(actor.state.map_id)
        .npcs.find((npc: any) => npcShop(npc) === shop);
    if (
      !npc ||
      !Object.hasOwn(economyRules.shops, shop) ||
      Math.hypot(
        actor.state.position.x - npc.x,
        actor.state.position.y - npc.y,
      ) > economyRules.npc_range ||
      !this.world.combat.visible(actor.state.position, npc, actor.state.map_id)
    )
      throw new Rejected("npc_out_of_range");
    return actor;
  }
  private credit(id: string, amount: number) {
    const state = this.actor(id).state;
    if (
      !Number.isSafeInteger(amount) ||
      amount < 0 ||
      !Number.isSafeInteger(state.gold + amount) ||
      state.gold + amount > economyRules.gold_cap
    )
      throw new Rejected("gold_limit");
    state.gold += amount;
  }
  spawn(input: {
    item?: Item;
    gold?: number;
    position: Point;
    owner?: string;
    map_id?: string;
  }) {
    if (
      !input.item &&
      (!Number.isSafeInteger(input.gold) || Number(input.gold) <= 0)
    )
      throw new Error("invalid_ground");
    if (input.item && !validItem(input.item))
      throw new Error("invalid_ground_item");
    let position = { ...input.position };
    const mapId =
        input.map_id ??
        (input.owner
          ? this.world.players.get(input.owner)?.state.map_id
          : undefined) ??
        "village",
      navigation = this.world.navigationFor(mapId);
    if (!navigation.safe(position)) {
      const cell = navigation.cellAt(position);
      let best: Point | undefined,
        bestDistance = Infinity;
      for (let radius = 0; radius <= 8 && !best; radius++)
        for (let y = cell.y - radius; y <= cell.y + radius; y++)
          for (let x = cell.x - radius; x <= cell.x + radius; x++) {
            const candidate = navigation.center({ x, y }),
              distance = Math.hypot(
                candidate.x - position.x,
                candidate.y - position.y,
              );
            if (distance < bestDistance && navigation.safe(candidate)) {
              best = candidate;
              bestDistance = distance;
            }
          }
      if (!best) throw new Error("unreachable_ground_spawn");
      position = best;
    }
    const id = input.item?.uid ?? randomBytes(12).toString("hex");
    if (this.ground.has(id)) throw new Error("duplicate_ground");
    const now = Date.now(),
      ground: Ground = {
        id,
        map_id: mapId,
        gold: input.gold ?? 0,
        item: input.item ? structuredClone(input.item) : undefined,
        position,
        owner: input.owner,
        protectedUntil: input.owner
          ? now + economyRules.loot_owner_seconds * 1000
          : 0,
        expiresAt: now + economyRules.ground_lifetime_seconds * 1000,
      };
    this.ground.set(id, ground);
    return ground;
  }
  pickup(id: string, groundId: string) {
    const actor = this.actor(id),
      ground = this.ground.get(groundId);
    if (!ground) throw new Rejected("ground_missing");
    if (
      ground.expiresAt <= Date.now() ||
      (ground.owner &&
        ground.owner !== id &&
        ground.protectedUntil > Date.now())
    )
      throw new Rejected("loot_protected");
    if (
      actor.state.map_id !== (ground.map_id ?? "village") ||
      Math.hypot(
        actor.state.position.x - ground.position.x,
        actor.state.position.y - ground.position.y,
      ) > economyRules.pickup_range ||
      !this.world.combat.visible(
        actor.state.position,
        ground.position,
        actor.state.map_id,
      )
    )
      throw new Rejected("pickup_out_of_range");
    if (ground.item) add(actor.state.inventory, ground.item);
    else this.credit(id, ground.gold);
    this.ground.delete(groundId);
    refresh(actor.state);
  }
  drop(id: string, uid: string) {
    const actor = this.actor(id),
      duplicate = this.ground.has(uid);
    if (duplicate) throw new Rejected("invalid_item");
    const item = remove(actor.state.inventory, uid);
    this.spawn({ item, position: actor.state.position, owner: id });
    refresh(actor.state);
  }
  buy(id: string, shop: string, definition: string) {
    const actor = this.npc(id, shop);
    if (!economyRules.shops[shop].stock.includes(definition))
      throw new Rejected("not_in_stock");
    if(economyRules.shops[shop].buy_enabled===false)throw new Rejected("buy_disabled");
    const price = this.buyPrice(definition,shop);
    if (actor.state.gold < price) throw new Rejected("insufficient_gold");
    add(actor.state.inventory, makeItem(definition));
    actor.state.gold -= price;
  }
  buyPrice(id: string,shop: string=""){
    const definition=items.definitions[id];
    const override=economyRules.shops[shop]?.prices?.[id]??definition.buy_price;
    return override!==undefined?Math.max(0,Math.floor(override*(balance.economy?.buy_multiplier??1))):economyRules.prices[id]??0;
  }
  salePrice(item: Item) {
    const definition=items.definitions[item.definition];
    if(definition.sell_price!==undefined)return Math.max(0,Math.floor(definition.sell_price*item.count));
    const maximum = items.definitions[item.definition].durability,
      condition = maximum ? item.durability / maximum : 1;
    return Math.max(
      1,
      Math.floor(
        this.buyPrice(item.definition) *
          economyRules.sell_fraction *
          item.count *
          condition,
      ),
    );
  }
  sell(id: string, shop: string, uid: string) {
    const actor = this.npc(id, shop),
      item = find(actor.state.inventory, uid);
    if (Object.values(actor.state.inventory.equipment).includes(uid))
      throw new Rejected("equipped_item");
    if(economyRules.shops[shop].sell_enabled===false || this.salePrice(item)<=0)throw new Rejected("sell_disabled");
    this.credit(id, this.salePrice(item));
    remove(actor.state.inventory, uid);
  }
  serviceShop(id: string,action: string){
    const actor=this.actor(id);
    const npc=this.world.geometryFor(actor.state.map_id).npcs.find((n:any)=>{
      const shop=npcShop(n);
      return (economyRules.shops[shop]?.[action+"_enabled"]??(shop==="smith")) && Math.hypot(actor.state.position.x-n.x,actor.state.position.y-n.y)<=economyRules.npc_range && this.world.combat.visible(actor.state.position,n,actor.state.map_id);
    });
    if(!npc)throw new Rejected("npc_out_of_range");
    return this.npc(id,npcShop(npc));
  }
  repair(id: string, uid: string) {
    const actor = this.serviceShop(id, "repair"),
      item = find(actor.state.inventory, uid),
      maximum = items.definitions[item.definition].durability,
      cost = (maximum - item.durability) * economyRules.repair_per_point;
    if (cost <= 0) throw new Rejected("nothing_to_repair");
    if (actor.state.gold < cost) throw new Rejected("insufficient_gold");
    actor.state.gold -= cost;
    item.durability = maximum;
    refresh(actor.state);
  }
  upgrade(id: string, uid: string) {
    const actor = this.serviceShop(id, "upgrade"),
      item = find(actor.state.inventory, uid);
    if (
      !items.definitions[item.definition].slot ||
      item.durability <= 0 ||
      item.upgrade >= items.upgrade.max
    )
      throw new Rejected("cannot_upgrade");
    const cost =
      items.upgrade.gold_base + item.upgrade * items.upgrade.gold_per_level;
    if (actor.state.gold < cost) throw new Rejected("insufficient_gold");
    const chance = items.upgrade.chances[item.upgrade],
      success = chance >= 1 || this.random() < chance;
    actor.state.gold -= cost;
    item.upgrade = success
      ? item.upgrade + 1
      : Math.max(0, item.upgrade - items.upgrade.failure_downgrade);
    refresh(actor.state);
    return { success, cost };
  }
  equip(id: string, uid: string) {
    equip(this.actor(id).state, uid);
  }
  unequip(id: string, slot: string) {
    unequip(this.actor(id).state, slot);
  }
  move(id: string, uid: string, x: number, y: number) {
    const actor = this.actor(id),
      draft = structuredClone(actor.state.inventory);
    for (const [slot, equipped] of Object.entries(draft.equipment))
      if (equipped === uid) delete draft.equipment[slot];
    move(draft, uid, x, y);
    actor.state.inventory = draft;
    refresh(actor.state);
  }
  consume(id: string, uid: string) {
    consume(this.actor(id).state, uid);
  }
  expire() {
    for (const [id, ground] of this.ground)
      if (ground.expiresAt <= Date.now()) this.ground.delete(id);
  }
  restore(records: Ground[]) {
    this.ground.clear();
    for (const ground of records) {
      if (
        !ground ||
        typeof ground.id !== "string" ||
        this.ground.has(ground.id) ||
        !this.world
          .navigationFor(ground.map_id ?? "village")
          .bounded(ground.position) ||
        (ground.item && !validItem(ground.item)) ||
        !Number.isSafeInteger(ground.gold) ||
        ground.gold < 0
      )
        throw new Error("corrupt_ground_state");
      this.ground.set(ground.id, {
        ...structuredClone(ground),
        map_id: ground.map_id ?? "village",
      });
    }
    this.expire();
  }
  snapshot(mapId: string = "village") {
    return [...this.ground.values()]
      .filter((ground) => (ground.map_id ?? "village") === mapId)
      .map((ground) => ({
        id: ground.id,
        item: ground.item,
        gold: ground.gold,
        position: { ...ground.position },
        owner: ground.owner,
        protectedUntil: ground.protectedUntil,
      }));
  }
}
