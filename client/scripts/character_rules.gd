class_name EterCharacter
extends RefCounted

static func definitions() -> Dictionary:
	return Catalog.read("classes")

static func valid_name(value: String) -> bool:
	var rules := definitions()
	if value.length() < int(rules.name_min) or value.length() > int(rules.name_max):
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9_]+$")
	return regex.search(value) != null

static func create(value: String, class_id: String) -> Dictionary:
	var rules := definitions()
	if not valid_name(value) or not rules.classes.has(class_id):
		return {}
	var definition: Dictionary = rules.classes[class_id]
	var result := {"name": value, "class_id": class_id, "level": 1, "experience": 0, "attribute_points": 0, "attributes": definition.attributes.duplicate(true), "appearance": {"weapon": definition.weapon_visual, "armor": definition.armor_visual}}
	result["stats"] = derive(result)
	result["hp"] = result.stats.max_hp
	result["mana"] = result.stats.max_mana
	result["reset_count"] = 0
	return result

static func formula(coefficients: Dictionary, attributes: Dictionary, level: int) -> int:
	var value := float(coefficients.get("base", 0))
	for attribute in definitions().attributes:
		value += float(attributes.get(attribute, 0)) * float(coefficients.get(attribute, 0))
	value += (level - 1) * float(coefficients.get("level", 0))
	return maxi(0, floori(value))

static func derive(character: Dictionary) -> Dictionary:
	var rules := definitions()
	var stats := {}
	for key in rules.derived:
		stats[key] = formula(rules.derived[key], character.attributes, int(character.level))
	var definition: Dictionary = rules.classes[character.class_id]
	stats["attack"] = formula(definition.attack, character.attributes, int(character.level))
	stats["damage_type"] = definition.damage_type
	stats["speed"] = definition.speed
	return stats
