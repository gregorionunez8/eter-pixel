class_name EterCombatRules
extends RefCounted

static func definitions() -> Dictionary:
	return Catalog.read("combat")

static func hit(attack: Dictionary, defense: Dictionary, damage_type: String, multiplier: float, accuracy_roll: float, critical_roll: float) -> Dictionary:
	var rules := definitions()
	var chance := clampf((float(attack.accuracy) - float(defense.evasion)) / 100.0, rules.min_hit_chance, rules.max_hit_chance)
	if accuracy_roll > chance:
		return {"damage": 0, "critical": false, "miss": true}
	var factor: float = rules.magic_defense_factor if damage_type == "magic" else rules.physical_defense_factor
	var damage := maxi(1, floori(float(attack.attack) * multiplier - float(defense.defense) * factor))
	var critical := critical_roll < float(rules.critical_chance)
	if critical:
		damage = maxi(1, floori(damage * float(rules.critical_multiplier)))
	return {"damage": damage, "critical": critical, "miss": false}
