class_name EterSave
extends RefCounted

static func save(character: Dictionary, path: String = "") -> bool:
	if not EterQuests.valid(character.get("quests",{})): return false
	if not EterInventory.integer(character.get("gold")) or character.gold < 0 or character.gold > EterEconomy.rules().gold_cap: return false
	if not character.has_all(["name","class_id","inventory"]) or not EterCharacter.valid_name(character.name) or not character.inventory is Dictionary or not EterInventory.valid(character.inventory,character.class_id):
		return false
	var local_slot := path.is_empty()
	if local_slot:
		DirAccess.make_dir_recursive_absolute("user://characters")
		path = "user://characters/%s.json" % character.name
	var payload := JSON.stringify(character)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify({"version":1,"payload":payload,"checksum":payload.sha256_text()}))
	file.flush()
	file.close()
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		return false
	if local_slot:
		var last := FileAccess.open("user://last-character.txt",FileAccess.WRITE)
		if last:
			last.store_string(character.name)
	return true

static func load_character(path: String = "") -> Dictionary:
	if path.is_empty():
		var last := FileAccess.open("user://last-character.txt",FileAccess.READ)
		if not last:
			return {}
		var name := last.get_as_text()
		if not EterCharacter.valid_name(name):
			return {}
		path = "user://characters/%s.json" % name
	var file := FileAccess.open(path,FileAccess.READ)
	if not file:
		return {}
	var envelope: Variant = JSON.parse_string(file.get_as_text())
	if not envelope is Dictionary or not envelope.has_all(["version","payload","checksum"]) or envelope.version != 1 or not envelope.payload is String:
		return {}
	if envelope.payload.sha256_text() != envelope.checksum:
		return {}
	var character: Variant = JSON.parse_string(envelope.payload)
	if not character is Dictionary or not character.has_all(["name","class_id","level","experience","attribute_points","attributes","inventory","hp","mana","reset_count","gold","appearance"]):
		return {}
	if not character.name is String or not character.class_id is String or not character.inventory is Dictionary or not character.attributes is Dictionary:
		return {}
	if not EterCharacter.valid_name(character.name) or not EterCharacter.definitions().classes.has(character.class_id) or not EterInventory.valid(character.inventory,character.class_id):
		return {}
	for key in ["level","experience","attribute_points","hp","mana","reset_count","gold"]:
		if not EterInventory.integer(character[key]):
			return {}
	if character.level < 1 or character.level > Catalog.read("progression").max_level or character.experience < 0 or character.attribute_points < 0 or character.gold < 0 or character.gold > EterEconomy.rules().gold_cap:
		return {}
	for attribute in EterCharacter.definitions().attributes:
		if not character.attributes.has(attribute) or not EterInventory.integer(character.attributes[attribute]) or character.attributes[attribute] < 0 or character.attributes[attribute] > Catalog.read("progression").attribute_cap:
			return {}
	character.stats = EterCharacter.derive(character)
	if not EterQuests.valid(character.get("quests",{})): return {}
	if not character.has("quests"): character.quests = {}
	var maps: Dictionary = Catalog.read("maps").maps
	if not character.has("map_id"): character.map_id = "village"
	if not character.map_id is String or not maps.has(character.map_id): return {}
	if not character.has("position"): character.position = maps[character.map_id].spawn.duplicate()
	if not character.position is Dictionary or not character.position.has_all(["x","y"]): return {}
	for coordinate in [character.position.x,character.position.y]:
		if not coordinate is float and not coordinate is int: return {}
	if not Rect2(0,0,int(maps[character.map_id].width)*32,int(maps[character.map_id].height)*32).has_point(Vector2(character.position.x,character.position.y)): return {}
	character.hp = clampi(int(character.hp),1,int(character.stats.max_hp))
	character.mana = clampi(int(character.mana),0,int(character.stats.max_mana))
	return character
