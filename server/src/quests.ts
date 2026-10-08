import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { type Character, makeItem } from "./rules.js";
import { gainExperience } from "./rpg.js";
import { add } from "./inventory.js";
import { economyRules } from "./economy.js";
import { Rejected } from "./store.js";

export const questCatalog = JSON.parse(
  readFileSync(resolve("../shared/quests.json"), "utf8"),
);
export type QuestProgress = { kills: number; claimed: boolean };
export type QuestJournal = Record<string, QuestProgress>;
export type QuestCharacter = Character & { quests?: QuestJournal };

function definition(id: string) {
  if (!Object.hasOwn(questCatalog.definitions, id))
    throw new Rejected("quest_missing");
  return questCatalog.definitions[id];
}

// Missing journal is a valid legacy save, never a completed objective.
export function validJournal(
  journal: unknown,
): journal is QuestJournal | undefined {
  if (journal === undefined) return true;
  if (!journal || typeof journal !== "object" || Array.isArray(journal))
    return false;
  return Object.entries(journal).every(([id, progress]) => {
    if (
      !Object.hasOwn(questCatalog.definitions, id) ||
      !progress ||
      typeof progress !== "object"
    )
      return false;
    const entry = progress as QuestProgress;
    return (
      Object.keys(entry).length === 2 &&
      Number.isSafeInteger(entry.kills) &&
      entry.kills >= 0 &&
      entry.kills <= definition(id).objective.count &&
      typeof entry.claimed === "boolean" &&
      (!entry.claimed || entry.kills === definition(id).objective.count)
    );
  });
}

export function acceptQuest(state: QuestCharacter, id: string) {
  const quest = definition(id);
  if (state.quests?.[id]) throw new Rejected("quest_already_accepted");
  if (quest.requires && !state.quests?.[quest.requires]?.claimed)
    throw new Rejected("quest_locked");
  state.quests = { ...state.quests, [id]: { kills: 0, claimed: false } };
}

// Called only after a simulation awards an actual monster death to this actor.
export function recordQuestKill(
  state: QuestCharacter,
  species: string,
  mapId: string,
) {
  for (const [id, progress] of Object.entries(state.quests ?? {})) {
    const objective = definition(id).objective;
    if (
      !progress.claimed &&
      objective.species === species &&
      objective.maps.includes(mapId)
    )
      progress.kills = Math.min(objective.count, progress.kills + 1);
  }
}

// Draft first: full inventory or gold cap cannot consume the completed quest.
// Caller must validate NPC/range/life and persist this mutation before ack.
export function claimQuest(state: QuestCharacter, id: string) {
  const quest = definition(id),
    progress = state.quests?.[id];
  if (!progress || progress.claimed || progress.kills !== quest.objective.count)
    throw new Rejected("quest_not_ready");
  const draft = structuredClone(state);
  if (draft.gold + quest.reward.gold > economyRules.gold_cap)
    throw new Rejected("gold_cap");
  for (const item of quest.reward.items)
    add(draft.inventory, makeItem(item.definition, item.count, item.rarity));
  draft.gold += quest.reward.gold;
  gainExperience(draft, quest.reward.experience);
  draft.quests![id].claimed = true;
  Object.assign(state, draft);
}
