import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { classes, deriveStats as derive, type Character } from "./rules.js";
export { deriveStats as derive } from "./rules.js";
import { Rejected } from "./store.js";
export const combatRules = JSON.parse(
  readFileSync(resolve("../shared/combat.json"), "utf8"),
);
export const progressionRules = JSON.parse(
  readFileSync(resolve("../shared/progression.json"), "utf8"),
);
export const species = JSON.parse(
  readFileSync(resolve("../shared/monsters.json"), "utf8"),
).species;
export function requiredExperience(level: number) {
  return Math.max(
    1,
    Math.floor(
      progressionRules.experience_base *
        Math.max(1, level) ** progressionRules.experience_exponent,
    ),
  );
}
export function gainExperience(state: Character, amount: number) {
  if (
    !Number.isSafeInteger(amount) ||
    amount <= 0 ||
    state.level >= progressionRules.max_level
  )
    return 0;
  state.experience += amount;
  let levels = 0;
  while (
    state.level < progressionRules.max_level &&
    state.experience >= requiredExperience(state.level)
  ) {
    state.experience -= requiredExperience(state.level);
    state.level++;
    state.attribute_points += progressionRules.points_per_level;
    levels++;
  }
  if (state.level >= progressionRules.max_level) state.experience = 0;
  if (levels) {
    state.stats = derive(state);
    state.hp = Number(state.stats.max_hp);
    state.mana = Number(state.stats.max_mana);
  }
  return levels;
}
export function allocate(state: Character, attribute: string, amount: number) {
  if (
    !classes.attributes.includes(attribute) ||
    !Number.isSafeInteger(amount) ||
    amount <= 0 ||
    amount > state.attribute_points ||
    state.attributes[attribute] + amount > progressionRules.attribute_cap
  )
    throw new Rejected("invalid_allocation");
  const old = state.stats;
  state.attributes[attribute] += amount;
  state.attribute_points -= amount;
  state.stats = derive(state);
  state.hp = Math.min(
    Number(state.stats.max_hp),
    state.hp + Number(state.stats.max_hp) - Number(old.max_hp),
  );
  state.mana = Math.min(
    Number(state.stats.max_mana),
    state.mana + Number(state.stats.max_mana) - Number(old.max_mana),
  );
}
export function deathPenalty(state: Character) {
  const lost = Math.floor(
    state.experience * progressionRules.death_experience_fraction,
  );
  state.experience -= lost;
  return lost;
}
export function hit(
  attack: Record<string, number | string>,
  defense: Record<string, number | string>,
  kind: string,
  multiplier: number,
  accuracyRoll: number,
  criticalRoll: number,
) {
  const chance = Math.max(
    combatRules.min_hit_chance,
    Math.min(
      combatRules.max_hit_chance,
      (Number(attack.accuracy) - Number(defense.evasion)) / 100,
    ),
  );
  if (accuracyRoll > chance) return { damage: 0, miss: true, critical: false };
  let damage = Math.max(
    1,
    Math.floor(
      Number(attack.attack) * multiplier -
        Number(defense.defense) *
          (kind === "magic"
            ? combatRules.magic_defense_factor
            : combatRules.physical_defense_factor),
    ),
  );
  const critical = criticalRoll < combatRules.critical_chance;
  if (critical)
    damage = Math.max(1, Math.floor(damage * combatRules.critical_multiplier));
  return { damage, miss: false, critical };
}
