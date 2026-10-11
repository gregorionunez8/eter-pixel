class_name EterEconomy
extends RefCounted

static func rules() -> Dictionary:
	return Catalog.read("economy")

static func credit(character: Dictionary, amount: int) -> bool:
	if not EterInventory.integer(character.get("gold")) or amount < 0:
		return false
	var balance := int(character.gold)
	var cap := int(rules().gold_cap)
	if balance < 0 or balance > cap or amount > cap-balance:
		return false
	character.gold = balance+amount
	return true

static func buy(character: Dictionary, shop: String, definition: String) -> bool:
	if not rules().shops.has(shop) or not definition in rules().shops[shop].stock:
		return false
	if not rules().shops[shop].get("buy_enabled",true): return false
	var cost := buy_price(definition,shop)
	if int(character.gold) < cost:
		return false
	var draft: Dictionary = character.inventory.duplicate(true)
	if not EterInventory.add(draft,EterInventory.make_item(definition)):
		return false
	character.inventory = draft
	character.gold -= cost
	return true

static func sale_price(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var definition: Dictionary=EterInventory.definitions().definitions[item.definition]
	if definition.has("sell_price"): return maxi(0,floori(float(definition.sell_price)*int(item.count)*float(Catalog.read("balance").get("economy",{}).get("sell_multiplier",1))))
	var maximum := int(definition.durability)
	var condition := float(item.durability)/maximum if maximum > 0 else 1.0
	return maxi(1,floori(float(buy_price(item.definition))*float(rules().sell_fraction)*int(item.count)*condition))

static func sell(character: Dictionary, uid: String) -> bool:
	var item := EterInventory.find(character.inventory,uid)
	if item.is_empty() or character.inventory.equipment.values().has(uid):
		return false
	var price := sale_price(item)
	if price <= 0 or not credit(character,price):
		return false
	EterInventory.remove(character.inventory,uid)
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
		if random.randf() < minf(1,float(drop.chance)*float(Catalog.read("balance").get("monster",{}).get("drop_rate",1))):
			var quantity := random.randi_range(int(drop.get("min_quantity",1)),int(drop.get("max_quantity",1)))
			var item := EterInventory.make_item(drop.item,quantity,drop.get("rarity","normal"))
			item.upgrade=random.randi_range(int(drop.get("min_upgrade",0)),int(drop.get("max_upgrade",0)))
			for option in drop.get("possible_options",[]):
				if option is Dictionary and random.randf()<float(drop.get("option_chance",0)):
					if not item.has("options"): item.options={}
					item.options[option.option]=option.value
			result.items.append(item)
	return result

static func buy_price(id: String,shop: String="") -> int:
	var definition: Dictionary=EterInventory.definitions().definitions[id]
	var price: Variant=rules().shops.get(shop,{}).get("prices",{}).get(id,definition.get("buy_price",rules().prices.get(id,0)))
	return maxi(0,floori(float(price)*float(Catalog.read("balance").get("economy",{}).get("buy_multiplier",1)))) if definition.has("buy_price") or rules().shops.get(shop,{}).get("prices",{}).has(id) else int(price)
static func enabled(shop: String,action: String) -> bool:
	return bool(rules().shops.get(shop,{}).get(action+"_enabled",shop=="smith" if action in ["repair","upgrade"] else true))
