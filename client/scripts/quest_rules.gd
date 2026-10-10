class_name EterQuests
extends RefCounted

static func definitions() -> Dictionary:
	return Catalog.read("quests").definitions

static func valid(journal: Variant) -> bool:
	if not journal is Dictionary: return false
	for id in journal:
		if not definitions().has(id): return false
		var progress: Variant = journal[id]
		if not progress is Dictionary or progress.size() != 2 or not progress.has_all(["kills","claimed"]): return false
		if not EterInventory.integer(progress.kills) or not progress.claimed is bool: return false
		var count: int = int(definitions()[id].objective.count)
		if progress.kills < 0 or progress.kills > count or (progress.claimed and progress.kills != count): return false
	return true

static func accept(character: Dictionary, id: String) -> String:
	if not definitions().has(id): return "quest_missing"
	var quest: Dictionary = definitions()[id]
	var journal: Dictionary = character.get("quests",{})
	if journal.has(id): return "quest_already_accepted"
	if quest.requires != null and not journal.get(quest.requires,{}).get("claimed",false): return "quest_locked"
	character.quests = journal
	journal[id] = {"kills":0,"claimed":false}
	return ""

static func record_kill(character: Dictionary, species: String, map_id: String) -> void:
	for id in character.get("quests",{}):
		var progress: Dictionary = character.quests[id]
		var objective: Dictionary = definitions()[id].objective
		if not progress.claimed and objective.species == species and map_id in objective.maps:
			progress.kills = mini(int(objective.count),int(progress.kills)+1)

static func claim(character: Dictionary, id: String) -> String:
	if not definitions().has(id): return "quest_missing"
	var quest: Dictionary = definitions()[id]
	var progress: Dictionary = character.get("quests",{}).get(id,{})
	if progress.is_empty() or progress.claimed or int(progress.kills) != int(quest.objective.count): return "quest_not_ready"
	var draft := character.duplicate(true)
	if not EterEconomy.credit(draft,int(quest.reward.gold)): return "gold_cap"
	for item in quest.reward.items:
		if not EterInventory.add(draft.inventory,EterInventory.make_item(item.definition,int(item.count),item.rarity)): return "inventory_full"
	EterProgression.gain_experience(draft,int(quest.reward.experience))
	draft.quests[id].claimed = true
	character.clear()
	character.merge(draft,true)
	return ""
