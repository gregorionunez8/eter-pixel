class_name EterProgression
extends RefCounted

static func required_experience(level: int) -> int:
	var rules := Catalog.read("progression")
	return maxi(1, floori(float(rules.experience_base) * pow(maxi(1, level), float(rules.experience_exponent))))

static func gain_experience(character: Dictionary, amount: int) -> int:
	var rules := Catalog.read("progression")
	if amount <= 0 or character.level >= int(rules.max_level):
		return 0
	character.experience += amount
	var levels := 0
	while character.level < int(rules.max_level) and character.experience >= required_experience(character.level):
		character.experience -= required_experience(character.level)
		character.level += 1
		character.attribute_points += int(rules.points_per_level)
		levels += 1
	if character.level >= int(rules.max_level):
		character.experience = 0
	if levels > 0:
		character.stats = EterCharacter.derive(character)
		character.hp = character.stats.max_hp
		character.mana = character.stats.max_mana
	return levels

static func allocate(character: Dictionary, attribute: String, amount: int = 1) -> bool:
	var rules := Catalog.read("progression")
	if not attribute in EterCharacter.definitions().attributes or amount <= 0 or amount > int(character.attribute_points):
		return false
	if int(character.attributes[attribute]) + amount > int(rules.attribute_cap):
		return false
	var old_stats: Dictionary = character.stats
	character.attributes[attribute] += amount
	character.attribute_points -= amount
	character.stats = EterCharacter.derive(character)
	character.hp = mini(character.stats.max_hp, character.hp + character.stats.max_hp - old_stats.max_hp)
	character.mana = mini(character.stats.max_mana, character.mana + character.stats.max_mana - old_stats.max_mana)
	return true

static func death_penalty(character: Dictionary) -> int:
	var lost := floori(int(character.experience) * float(Catalog.read("progression").death_experience_fraction))
	character.experience = maxi(0, int(character.experience) - lost)
	return lost

static func can_reset(character: Dictionary) -> bool:
	var rules := Catalog.read("progression")
	return bool(rules.reset_enabled) and int(character.level) >= int(rules.reset_min_level)
