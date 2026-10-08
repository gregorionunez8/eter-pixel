import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { randomBytes } from "node:crypto";

// npm scripts run in server/. Catalogs are the same source used by Godot.
export const classes = JSON.parse(
  readFileSync(resolve("../shared/classes.json"), "utf8"),
);
export const items = JSON.parse(
  readFileSync(resolve("../shared/items.json"), "utf8"),
);
export type Character = ReturnType<typeof createCharacter>;
export function validName(name: unknown): name is string {
  return (
    typeof name === "string" &&
    name.length >= classes.name_min &&
    name.length <= classes.name_max &&
    /^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9_]+$/.test(name)
  );
}
export type Item = ReturnType<typeof makeItem>;
export function makeItem(definition: string, count = 1, rarity = "normal") {
  if (
    !Object.hasOwn(items.definitions, definition) ||
    !Object.hasOwn(items.rarities, rarity) ||
    !Number.isSafeInteger(count) ||
    count < 1 ||
    count > items.definitions[definition].stack
  )
    throw new Error("invalid_item");
  return {
    uid: randomBytes(12).toString("hex"),
    definition,
    count,
    rarity,
    upgrade: 0,
    durability: items.definitions[definition].durability as number,
    x: -1,
    y: -1,
  };
}
export function createCharacter(name: string, classId: string) {
  if (!validName(name) || !Object.hasOwn(classes.classes, classId))
    throw new Error("invalid_character");
  const definition = classes.classes[classId];
  const attributes: Record<string, number> = { ...definition.attributes };
  const weapon = makeItem(
    (
      {
        warrior: "starter_sword",
        mage: "starter_staff",
        elf: "starter_bow",
      } as Record<string, string>
    )[classId],
  );
  const potion = makeItem("potion", 3);
  potion.x = 0;
  potion.y = 0;
  const inventory = {
    width: items.grid_width as number,
    height: items.grid_height as number,
    items: [weapon, potion],
    equipment: { weapon: weapon.uid } as Record<string, string>,
  };
  const stats = deriveStats({
    class_id: classId,
    level: 1,
    attributes,
    inventory,
  });
  return {
    name,
    class_id: classId,
    level: 1,
    experience: 0,
    attribute_points: 0,
    attributes,
    appearance: {
      weapon: definition.weapon_visual,
      armor: definition.armor_visual,
    },
    stats,
    inventory,
    hp: stats.max_hp as number,
    mana: stats.max_mana as number,
    gold: 0,
    starter_ground_claimed: false,
    reset_count: 0,
    combat_state: {
      cooldown_deadlines: {} as Record<string, number>,
      respawn_deadline: 0,
      regeneration_deadline: 0,
    },
    map_id: "village",
    position: { x: 784, y: 592 },
  };
}
export function deriveStats(state: {
  class_id: string;
  level: number;
  attributes: Record<string, number>;
  inventory: { items: Item[]; equipment: Record<string, string> };
}) {
  const definition = classes.classes[state.class_id];
  const formula = (coefficients: Record<string, number>) =>
    Math.max(
      0,
      Math.floor(
        (coefficients.base ?? 0) +
          (state.level - 1) * (coefficients.level ?? 0) +
          classes.attributes.reduce(
            (sum: number, key: string) =>
              sum + state.attributes[key] * (coefficients[key] ?? 0),
            0,
          ),
      ),
    );
  const stats: Record<string, number | string> = {
    attack: formula(definition.attack),
    damage_type: definition.damage_type,
    speed: definition.speed,
  };
  for (const [key, value] of Object.entries(classes.derived))
    stats[key] = formula(value as Record<string, number>);
  for (const uid of Object.values(state.inventory.equipment)) {
    const item = state.inventory.items.find((item) => item.uid === uid);
    if (!item || item.durability <= 0) continue;
    for (const [stat, bonus] of Object.entries(
      items.definitions[item.definition].bonuses,
    ))
      stats[stat] =
        Number(stats[stat] ?? 0) +
        Math.floor(Number(bonus) * items.rarities[item.rarity].multiplier) +
        item.upgrade * items.upgrade.stat_per_level;
  }
  return stats;
}
