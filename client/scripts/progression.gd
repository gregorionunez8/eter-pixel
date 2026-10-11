class_name EterProgression
extends RefCounted

static func required_experience(level: int) -> int:
	var settings: Dictionary=Catalog.read("progression")
	if settings.get("experience_mode","formula")=="table" and settings.get("experience_table",[]).size()>=level: return maxi(1,int(settings.experience_table[level-1]))
	var rules := Catalog.read("progression")
	return maxi(1, floori(float(rules.experience_base) * pow(maxi(1, level), float(rules.experience_exponent))))

static func gain_experience(character: Dictionary, amount: int) -> int:
	var rules := Catalog.read("progression")
	if amount <= 0 or character.level >= int(rules.max_level):
		return 0
	character.experience += floori(amount*float(Catalog.read("balance").get("player",{}).get("experience_multiplier",1)))
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

static func reset(character: Dictionary) -> bool:
	var settings: Dictionary=Catalog.read("balance").get("reset",{})
	var maximum := int(settings.get("max_resets",0))
	if not can_reset(character) or character.hp<=0 or int(character.gold)<int(settings.get("cost",0)) or (maximum>0 and int(character.get("reset_count",0))>=maximum): return false
	character.gold-=int(settings.get("cost",0)); character.reset_count=int(character.get("reset_count",0))+1
	character.level=int(settings.get("starting_level",1)); character.experience=0
	if settings.get("stats_behavior","initial")=="initial": character.attributes=EterCharacter.definitions().classes[character.class_id].attributes.duplicate(true)
	character.attribute_points=int(settings.get("points",0))*int(character.reset_count)+int(settings.get("bonus",0))
	if settings.get("skill_behavior","keep")=="initial": character.learned_skills=[]
	character.stats=EterCharacter.derive(character); character.hp=character.stats.max_hp; character.mana=character.stats.max_mana
	return true
