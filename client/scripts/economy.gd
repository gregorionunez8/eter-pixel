class_name EterEconomy
extends RefCounted

static func rules() -> Dictionary:
	return Catalog.read("economy")

static func buy(character: Dictionary, shop: String, definition: String) -> bool:
	if not rules().shops.has(shop) or not definition in rules().shops[shop].stock:
		return false
	var cost := int(rules().prices[definition])
	if int(character.gold) < cost:
		return false
	var draft: Dictionary = character.inventory.duplicate(true)
	if not EterInventory.add(draft,EterInventory.make_item(definition)):
		return false
	character.inventory = draft
	character.gold -= cost
	return true

static func sale_price(item: Dictionary) -> int:
	if item.is_empty() or not rules().prices.has(item.definition):
		return 0
	var maximum := int(EterInventory.definitions().definitions[item.definition].durability)
	var condition := float(item.durability)/maximum if maximum > 0 else 1.0
	return maxi(1,floori(float(rules().prices[item.definition])*float(rules().sell_fraction)*int(item.count)*condition))

static func sell(character: Dictionary, uid: String) -> bool:
	var item := EterInventory.find(character.inventory,uid)
	if item.is_empty() or character.inventory.equipment.values().has(uid):
		return false
	var price := sale_price(item)
	if price <= 0:
		return false
	EterInventory.remove(character.inventory,uid)
	character.gold += price
	return true

static func repair_cost(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	return (int(EterInventory.definitions().definitions[item.definition].durability)-int(item.durability))*int(rules().repair_per_point)

static func repair(character: Dictionary, uid: String) -> bool:
	var item := EterInventory.find(character.inventory,uid)
	var cost := repair_cost(item)
	if cost <= 0 or int(character.gold) < cost:
		return false
	character.gold -= cost
	item.durability = int(EterInventory.definitions().definitions[item.definition].durability)
	return true

static func wear(character: Dictionary, slot: String) -> void:
	var item := EterInventory.find(character.inventory,str(character.inventory.equipment.get(slot,"")))
	if not item.is_empty():
		item.durability = maxi(0,int(item.durability)-1)

static func loot(species: String, random: RandomNumberGenerator) -> Dictionary:
	var config: Dictionary = Catalog.read("monsters").species[species]
	var result := {"gold":0,"items":[]}
	if random.randf() < float(config.loot.chance):
		result.gold = random.randi_range(int(config.loot.gold_min),int(config.loot.gold_max))
	for drop in rules().drops.get(species,[]):
		if random.randf() < float(drop.chance):
			result.items.append(EterInventory.make_item(drop.item,1,drop.get("rarity","normal")))
	return result
