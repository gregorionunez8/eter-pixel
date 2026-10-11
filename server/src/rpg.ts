import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { classes, items, deriveStats as derive, type Character } from "./rules.js";
export { deriveStats as derive } from "./rules.js";
import { applyBalance, balance } from "./content.js";
import { Rejected } from "./store.js";
export const combatRules = applyBalance("combat",JSON.parse(
  readFileSync(resolve("../shared/combat.json"), "utf8"),
));
export const progressionRules = JSON.parse(
  readFileSync(resolve("../shared/progression.json"), "utf8"),
);
export const species = applyBalance("monsters",JSON.parse(
  readFileSync(resolve("../shared/monsters.json"), "utf8"),
)).species;
export function requiredExperience(level: number) {
  if(progressionRules.experience_mode==="table" && progressionRules.experience_table?.[level-1]!==undefined)return Math.max(1,Math.floor(progressionRules.experience_table[level-1]));
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
  state.experience += Math.floor(amount*(balance.player?.experience_multiplier??1));
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
  baseDamage: number=0,
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
      Number(attack.attack) * multiplier + baseDamage -
        Number(defense.defense) *
          (kind === "magic"
            ? combatRules.magic_defense_factor
            : combatRules.physical_defense_factor),
    ),
  );
  damage=Math.max(1,Math.floor(damage*(1-Math.max(0,Math.min(0.95,Number(defense.damage_reduction??0)/100)))));
  const critical = criticalRoll < Math.min(1,combatRules.critical_chance+Number(attack.critical_chance??0)/100);
  if (critical)
    damage = Math.max(1, Math.floor(damage * combatRules.critical_multiplier));
  return { damage, miss: false, critical };
}

export function availableSkills(state: Character): string[] {
  return Object.entries(combatRules.skills).filter(([id,raw])=>{
    const skill=raw as any;
    const base=combatRules.classes[state.class_id].skills.includes(id);
    const weapon=Object.values(state.inventory.equipment).some(uid=>{
      const item=state.inventory.items.find(i=>i.uid===uid);
      return item && items.definitions[item.definition].options?.skill===id;
    });
    return (skill.classes??(base?[state.class_id]:[])).includes(state.class_id)
      && state.level>=(skill.required_level??1)
      && (base || !skill.book_item_id || (state.learned_skills??[]).includes(id) || weapon);
  }).map(([id])=>id);
}

export function resetCharacter(state: Character){
 const settings=balance.reset??{}, maximum=settings.max_resets??0;
 if(!progressionRules.reset_enabled || state.hp<=0 || state.level<progressionRules.reset_min_level || state.gold<(settings.cost??0) || (maximum>0 && state.reset_count>=maximum))throw new Rejected("cannot_reset");
 state.gold-=settings.cost??0;state.reset_count++;state.level=settings.starting_level??1;state.experience=0;
 if((settings.stats_behavior??"initial")==="initial")state.attributes={...classes.classes[state.class_id].attributes};
 state.attribute_points=(settings.points??0)*state.reset_count+(settings.bonus??0);
 if(settings.skill_behavior==="initial")state.learned_skills=[];
 state.stats=derive(state);state.hp=Number(state.stats.max_hp);state.mana=Number(state.stats.max_mana);
}
