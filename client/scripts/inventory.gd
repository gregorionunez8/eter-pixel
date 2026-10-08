class_name EterInventory
extends RefCounted

static func definitions() -> Dictionary:
	return Catalog.read("items")

static func make_item(definition: String, count: int = 1, rarity: String = "normal") -> Dictionary:
	var rules := definitions()
	if not rules.definitions.has(definition) or not rules.rarities.has(rarity) or count < 1 or count > int(rules.definitions[definition].stack):
		return {}
	return {"uid":Crypto.new().generate_random_bytes(12).hex_encode(),"definition":definition,"count":count,"rarity":rarity,"upgrade":0,"durability":int(rules.definitions[definition].durability),"x":-1,"y":-1}

static func initial(class_id: String) -> Dictionary:
	var rules := definitions()
	var state := {"width":int(rules.grid_width),"height":int(rules.grid_height),"items":[],"equipment":{}}
	var weapon := make_item({"warrior":"starter_sword","mage":"starter_staff","elf":"starter_bow"}[class_id])
	state.items.append(weapon)
	state.equipment["weapon"] = weapon.uid
	var potion := make_item("potion",3)
	potion.x = 0
	potion.y = 0
	state.items.append(potion)
	return state

static func find(state: Dictionary, uid: String) -> Dictionary:
	for item in state.items:
		if item.uid == uid:
			return item
	return {}

static func fits(state: Dictionary, item: Dictionary, x: int, y: int) -> bool:
	var dimensions: Array = definitions().definitions[item.definition].size
	var rect := Rect2i(x,y,int(dimensions[0]),int(dimensions[1]))
	if x < 0 or y < 0 or rect.end.x > int(state.width) or rect.end.y > int(state.height):
		return false
	for other in state.items:
		if other.uid == item.uid or int(other.x) < 0:
			continue
		var size: Array = definitions().definitions[other.definition].size
		if rect.intersects(Rect2i(int(other.x),int(other.y),int(size[0]),int(size[1]))):
			return false
	return true

static func space(state: Dictionary, item: Dictionary) -> Vector2i:
	for y in range(int(state.height)):
		for x in range(int(state.width)):
			if fits(state,item,x,y):
				return Vector2i(x,y)
	return Vector2i(-1,-1)

static func add(state: Dictionary, incoming: Dictionary) -> bool:
	if not valid_item(incoming) or not find(state,incoming.uid).is_empty():
		return false
	var draft := state.duplicate(true)
	var item := incoming.duplicate(true)
	var max_stack := int(definitions().definitions[item.definition].stack)
	if max_stack > 1:
		for other in draft.items:
			if other.definition == item.definition and other.rarity == item.rarity and other.upgrade == item.upgrade:
				var merged := mini(max_stack-int(other.count),int(item.count))
				other.count += merged
				item.count -= merged
				if item.count == 0:
					state.items = draft.items
					return true
	var position := space(draft,item)
	if position.x < 0:
		return false
	item.x = position.x
	item.y = position.y
	draft.items.append(item)
	state.items = draft.items
	return true

static func move(state: Dictionary, uid: String, x: int, y: int) -> bool:
	var item := find(state,uid)
	if item.is_empty() or state.equipment.values().has(uid) or not fits(state,item,x,y):
		return false
	item.x = x
	item.y = y
	return true

static func equip(character: Dictionary, uid: String) -> bool:
	var state: Dictionary = character.inventory
	var item := find(state,uid)
	if item.is_empty() or state.equipment.values().has(uid):
		return false
	var definition: Dictionary = definitions().definitions[item.definition]
	if not definition.has("slot") or not character.class_id in definition.get("classes",["warrior","mage","elf"]):
		return false
	var draft := state.duplicate(true)
	var moving := find(draft,uid)
	moving.x = -1
	moving.y = -1
	var slot: String = definition.slot
	if draft.equipment.has(slot):
		var old := find(draft,draft.equipment[slot])
		var position := space(draft,old)
		if position.x < 0:
			return false
		old.x = position.x
		old.y = position.y
	draft.equipment[slot] = uid
	character.inventory = draft
	return true

static func unequip(state: Dictionary, slot: String) -> bool:
	if not state.equipment.has(slot):
		return false
	var item := find(state,state.equipment[slot])
	var position := space(state,item)
	if position.x < 0:
		return false
	item.x = position.x
	item.y = position.y
	state.equipment.erase(slot)
	return true

static func remove(state: Dictionary, uid: String) -> Dictionary:
	var item := find(state,uid)
	if item.is_empty():
		return {}
	var result := item.duplicate(true)
	state.items.erase(item)
	for slot in state.equipment.keys():
		if state.equipment[slot] == uid:
			state.equipment.erase(slot)
	result.x = -1
	result.y = -1
	return result

static func bonuses(state: Dictionary) -> Dictionary:
	var result := {}
	for uid in state.equipment.values():
		var item := find(state,uid)
		if item.is_empty() or int(item.durability) <= 0:
			continue
		var definition: Dictionary = definitions().definitions[item.definition]
		for stat in definition.bonuses:
			var amount := floori(float(definition.bonuses[stat]) * float(definitions().rarities[item.rarity].multiplier)) + int(item.upgrade) * int(definitions().upgrade.stat_per_level)
			result[stat] = int(result.get(stat,0)) + amount
	return result

static func upgrade(character: Dictionary, uid: String, roll: float) -> Dictionary:
	var item := find(character.inventory,uid)
	var rules: Dictionary = definitions().upgrade
	if item.is_empty() or int(item.upgrade) >= int(rules.max) or int(definitions().definitions[item.definition].stack) > 1:
		return {"accepted":false}
	var cost := int(rules.gold_base) + int(item.upgrade) * int(rules.gold_per_level)
	if int(character.get("gold",0)) < cost or roll < 0 or roll > 1:
		return {"accepted":false}
	character.gold -= cost
	var chance := float(rules.chances[int(item.upgrade)])
	var success := chance >= 1 or roll < chance
	item.upgrade = int(item.upgrade) + 1 if success else maxi(0,int(item.upgrade)-int(rules.failure_downgrade))
	return {"accepted":true,"success":success,"cost":cost}

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value))

static func valid_item(item: Dictionary) -> bool:
	if not item.has_all(["uid","definition","count","rarity","upgrade","durability","x","y"]) or not item.uid is String or item.uid.length() != 24:
		return false
	if not definitions().definitions.has(item.definition) or not definitions().rarities.has(item.rarity):
		return false
	for key in ["count","upgrade","durability","x","y"]:
		if not integer(item[key]):
			return false
	var definition: Dictionary = definitions().definitions[item.definition]
	return int(item.count) >= 1 and int(item.count) <= int(definition.stack) and int(item.upgrade) >= 0 and int(item.upgrade) <= int(definitions().upgrade.max) and int(item.durability) >= 0 and int(item.durability) <= int(definition.durability)

static func valid(state: Dictionary, class_id: String) -> bool:
	if not state.has_all(["width","height","items","equipment"]) or int(state.width) != int(definitions().grid_width) or int(state.height) != int(definitions().grid_height):
		return false
	if not state.items is Array or not state.equipment is Dictionary:
		return false
	if not integer(state.width) or not integer(state.height):
		return false
	var ids := {}
	for item in state.items:
		if not item is Dictionary or not valid_item(item):
			return false
		if ids.has(item.uid) or not definitions().definitions.has(item.definition) or not definitions().rarities.has(item.rarity):
			return false
		ids[item.uid] = true
		var definition: Dictionary = definitions().definitions[item.definition]
		if int(item.count) < 1 or int(item.count) > int(definition.stack) or int(item.upgrade) < 0 or int(item.upgrade) > 15 or int(item.durability) < 0 or int(item.durability) > int(definition.durability):
			return false
		if state.equipment.values().has(item.uid):
			if int(item.x) != -1 or int(item.y) != -1:
				return false
		elif not fits(state,item,int(item.x),int(item.y)):
			return false
	var equipped_ids := {}
	for slot in state.equipment:
		if not state.equipment[slot] is String:
			return false
		var item := find(state,state.equipment[slot])
		if item.is_empty() or equipped_ids.has(item.uid):
			return false
		var definition: Dictionary = definitions().definitions[item.definition]
		if definition.get("slot","") != slot or not class_id in definition.get("classes",["warrior","mage","elf"]):
			return false
		equipped_ids[item.uid] = true
	return true
