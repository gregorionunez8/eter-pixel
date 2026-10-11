import { itemOptions, items, type Character, type Item } from "./rules.js";
import { derive, combatRules } from "./rpg.js";
import { Rejected } from "./store.js";
export type Inventory = Character["inventory"];
export function find(state: Inventory, uid: string) {
  const item = state.items.find((item) => item.uid === uid);
  if (!item) throw new Rejected("item_missing");
  return item;
}
export function fits(state: Inventory, item: Item, x: number, y: number) {
  const size = items.definitions[item.definition].size;
  if (
    !Number.isSafeInteger(x) ||
    !Number.isSafeInteger(y) ||
    x < 0 ||
    y < 0 ||
    x + size[0] > state.width ||
    y + size[1] > state.height
  )
    return false;
  return state.items.every((other) => {
    if (other.uid === item.uid || other.x < 0) return true;
    const otherSize = items.definitions[other.definition].size;
    return (
      x >= other.x + otherSize[0] ||
      x + size[0] <= other.x ||
      y >= other.y + otherSize[1] ||
      y + size[1] <= other.y
    );
  });
}
export function space(state: Inventory, item: Item) {
  for (let y = 0; y < state.height; y++)
    for (let x = 0; x < state.width; x++)
      if (fits(state, item, x, y)) return { x, y };
  return undefined;
}
export function validItem(item: Item) {
  if (
    !item ||
    typeof item.uid !== "string" ||
    !/^[a-f0-9]{24}$/.test(item.uid) ||
    !Object.hasOwn(items.definitions, item.definition) ||
    !Object.hasOwn(items.rarities, item.rarity)
  )
    return false;
  if (
    !["count", "upgrade", "durability", "x", "y"].every((key) =>
      Number.isSafeInteger(item[key as keyof Item]),
    )
  )
    return false;
  const definition = items.definitions[item.definition];
  if(item.options!==undefined && (!item.options || typeof item.options!=="object" || Array.isArray(item.options)))return false;
  for(const [option,value] of Object.entries(item.options??{})){
    const rule=itemOptions.definitions[option];
    if(!rule || !(itemOptions.allowed[definition.category]??[]).includes(option))return false;
    if(rule.unit==="skill_id"){if(!Object.hasOwn(combatRules.skills,String(value)))return false;}
    else if(typeof value!=="number" || !Number.isFinite(value) || value<0 || (rule.unit==="percent" && value>100))return false;
  }
  return (
    item.count >= 1 &&
    item.count <= definition.stack &&
    item.upgrade >= 0 &&
    item.upgrade <= items.upgrade.max &&
    item.durability >= 0 &&
    item.durability <= definition.durability
  );
}
export function valid(state: Inventory, classId: string) {
  if (
    !state ||
    state.width !== items.grid_width ||
    state.height !== items.grid_height ||
    !Array.isArray(state.items) ||
    !state.equipment ||
    typeof state.equipment !== "object"
  )
    return false;
  const ids = new Set<string>();
  for (const item of state.items) {
    if (!validItem(item) || ids.has(item.uid)) return false;
    ids.add(item.uid);
    if (Object.values(state.equipment).includes(item.uid)) {
      if (item.x !== -1 || item.y !== -1) return false;
    } else if (!fits(state, item, item.x, item.y)) return false;
  }
  const equipped = new Set<string>();
  for (const [slot, uid] of Object.entries(state.equipment)) {
    const item = state.items.find((item) => item.uid === uid);
    if (!item || equipped.has(uid)) return false;
    const definition = items.definitions[item.definition];
    if (
      definition.slot !== slot ||
      !(definition.classes ?? ["warrior", "mage", "elf"]).includes(classId)
    )
      return false;
    equipped.add(uid);
  }
  return true;
}
export function add(state: Inventory, incoming: Item) {
  if (
    !validItem(incoming) ||
    state.items.some((item) => item.uid === incoming.uid)
  )
    throw new Rejected("invalid_item");
  const draft = structuredClone(state),
    item = structuredClone(incoming),
    maximum = items.definitions[item.definition].stack;
  if (maximum > 1)
    for (const other of draft.items)
      if (
        other.definition === item.definition &&
        other.rarity === item.rarity &&
        other.upgrade === item.upgrade
      ) {
        const amount = Math.min(maximum - other.count, item.count);
        other.count += amount;
        item.count -= amount;
        if (!item.count) {
          state.items = draft.items;
          return;
        }
      }
  const point = space(draft, item);
  if (!point) throw new Rejected("inventory_full");
  item.x = point.x;
  item.y = point.y;
  draft.items.push(item);
  state.items = draft.items;
}
export function move(state: Inventory, uid: string, x: number, y: number) {
  const item = find(state, uid);
  if (Object.values(state.equipment).includes(uid) || !fits(state, item, x, y))
    throw new Rejected("invalid_placement");
  item.x = x;
  item.y = y;
}
export function refresh(character: Character) {
  character.stats = derive(character);
  character.hp = Math.min(character.hp, Number(character.stats.max_hp));
  character.mana = Math.min(character.mana, Number(character.stats.max_mana));
}
export function equip(character: Character, uid: string) {
  const state = character.inventory,
    item = find(state, uid),
    definition = items.definitions[item.definition];
  if (
    character.level < (definition.required_level??1) ||
    !definition.slot ||
    !(definition.classes ?? ["warrior", "mage", "elf"]).includes(
      character.class_id,
    ) ||
    Object.values(state.equipment).includes(uid)
  )
    throw new Rejected("cannot_equip");
  const draft = structuredClone(state),
    moving = find(draft, uid);
  moving.x = -1;
  moving.y = -1;
  if (draft.equipment[definition.slot]) {
    const old = find(draft, draft.equipment[definition.slot]),
      point = space(draft, old);
    if (!point) throw new Rejected("inventory_full");
    old.x = point.x;
    old.y = point.y;
  }
  draft.equipment[definition.slot] = uid;
  character.inventory = draft;
  refresh(character);
}
export function unequip(character: Character, slot: string) {
  const uid = character.inventory.equipment[slot];
  if (!uid) throw new Rejected("empty_slot");
  const item = find(character.inventory, uid),
    point = space(character.inventory, item);
  if (!point) throw new Rejected("inventory_full");
  item.x = point.x;
  item.y = point.y;
  delete character.inventory.equipment[slot];
  refresh(character);
}
export function remove(state: Inventory, uid: string) {
  const item = find(state, uid),
    result = structuredClone(item);
  state.items.splice(state.items.indexOf(item), 1);
  for (const slot in state.equipment)
    if (state.equipment[slot] === uid) delete state.equipment[slot];
  result.x = -1;
  result.y = -1;
  return result;
}
export function consume(character: Character, uid: string) {
  const item = find(character.inventory, uid),
    definition = items.definitions[item.definition];
  if(definition.category==="skill_book"){
    const id=definition.learn_skill, skill=combatRules.skills[id];
    if(!skill || character.hp<=0 || !(skill.classes??[]).includes(character.class_id) || !(definition.classes??[]).includes(character.class_id) || character.level<(skill.required_level??1) || character.level<(definition.required_level??1) || combatRules.classes[character.class_id].skills.includes(id) || (character.learned_skills??[]).includes(id)) throw new Rejected("cannot_learn");
    (character.learned_skills??=[]).push(id);
    if(--item.count===0)remove(character.inventory,uid);
    return;
  }
  if (
    definition.category !== "potion" ||
    character.hp <= 0 ||
    character.hp >= Number(character.stats.max_hp)
  )
    throw new Rejected("cannot_consume");
  character.hp = Math.min(
    Number(character.stats.max_hp),
    character.hp +
      Math.floor(Number(character.stats.max_hp) * definition.heal_fraction),
  );
  if (--item.count === 0) remove(character.inventory, uid);
}
