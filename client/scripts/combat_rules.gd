class_name EterCombatRules
extends RefCounted

static func definitions() -> Dictionary:
	return Catalog.read("combat")

static func hit(attack: Dictionary, defense: Dictionary, damage_type: String, multiplier: float, accuracy_roll: float, critical_roll: float,base_damage: float=0) -> Dictionary:
	var rules := definitions()
	var chance := clampf((float(attack.accuracy) - float(defense.evasion)) / 100.0, rules.min_hit_chance, rules.max_hit_chance)
	if accuracy_roll > chance:
		return {"damage": 0, "critical": false, "miss": true}
	var factor: float = rules.magic_defense_factor if damage_type == "magic" else rules.physical_defense_factor
	var damage := maxi(1, floori(float(attack.attack) * multiplier + base_damage - float(defense.defense) * factor))
	damage=maxi(1,floori(damage*(1.0-clampf(float(defense.get("damage_reduction",0))/100.0,0,0.95))))
	var critical := critical_roll < clampf(float(rules.critical_chance)+float(attack.get("critical_chance",0))/100.0,0,1)
	if critical:
		damage = maxi(1, floori(damage * float(rules.critical_multiplier)))
	return {"damage": damage, "critical": critical, "miss": false}

static func available(character: Dictionary) -> Array:
	var rules := definitions()
	var result: Array=[]
	for id in rules.skills:
		var skill: Dictionary=rules.skills[id]
		var base: bool=id in rules.classes[character.class_id].skills
		var classes: Array=skill.get("classes",[character.class_id] if base else [])
		if not character.class_id in classes or int(character.level)<int(skill.get("required_level",1)): continue
		var learned: bool=id in character.get("learned_skills",[])
		var weapon_skill := false
		for uid in character.inventory.equipment.values():
			var item := EterInventory.find(character.inventory,uid)
			if EterInventory.definitions().definitions[item.definition].get("options",{}).get("skill","")==id: weapon_skill=true
		if base or skill.get("book_item_id","").is_empty() or learned or weapon_skill: result.append(id)
	return result
