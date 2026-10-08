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
export function makeItem(definition: string, count = 1) {
  return {
    uid: randomBytes(12).toString("hex"),
    definition,
    count,
    rarity: "normal",
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
  const formula = (coefficients: Record<string, number>) =>
    Math.max(
      0,
      Math.floor(
        (coefficients.base ?? 0) +
          classes.attributes.reduce(
            (total: number, attribute: string) =>
              total +
              (attributes[attribute] ?? 0) * (coefficients[attribute] ?? 0),
            0,
          ),
      ),
    );
  const stats: Record<string, number | string> = {};
  for (const [key, coefficients] of Object.entries(classes.derived))
    stats[key] = formula(coefficients as Record<string, number>);
  stats.attack = formula(definition.attack);
  stats.damage_type = definition.damage_type;
  stats.speed = definition.speed;
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
    inventory: {
      width: items.grid_width as number,
      height: items.grid_height as number,
      items: [weapon, potion],
      equipment: { weapon: weapon.uid },
    },
    hp: stats.max_hp as number,
    mana: stats.max_mana as number,
    gold: 0,
    starter_ground_claimed: false,
    reset_count: 0,
    map_id: "village",
    position: { x: 784, y: 592 },
  };
}
