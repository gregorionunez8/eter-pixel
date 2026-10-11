class_name EterContent
extends RefCounted
static func asset_path(value: String) -> String:
	if value.begins_with("res://"): return value
	var definitions: Dictionary=Catalog.read("assets").get("definitions",{})
	return str(definitions.get(value,{}).get("path","res://assets/"+value+".png"))
static func maps(catalog: Dictionary) -> Dictionary:
	for id in catalog.maps:
		var map: Dictionary=catalog.maps[id]
		map.id=id
		for key in ["regions","labels","obstacles","npcs","portals"]:
			if not map.has(key): map[key]=[]
		var expanded: Array=[]
		for index in range(map.monsters.size()):
			var spot: Dictionary=map.monsters[index]
			if not spot.get("enabled",true): continue
			var entries: Array=spot.get("entries",[{"species":spot.get("species","spider"),"quantity":spot.get("quantity",1)}])
			var sequence := 0
			var total := 0
			for entry in entries: total+=int(entry.get("quantity",1))
			for entry in entries:
				for count in range(int(entry.get("quantity",1))):
					var spawn: Dictionary=spot.duplicate(true)
					spawn.species=entry.species
					var base := str(spot.get("id","monster-"+str(index)))
					if spot.has("quantity") or spot.has("entries") or spot.has("enabled"): base=str(id)+"-"+base
					if total>1:
						spawn.id=base+"-"+str(sequence)
						var angle := float(sequence)*TAU/float(total)
						spawn.x=float(spot.x)+cos(angle)*float(spot.get("spawn_radius",16))
						spawn.y=float(spot.y)+sin(angle)*float(spot.get("spawn_radius",16))
					else: spawn.id=base
					spawn.erase("entries"); spawn.erase("quantity")
					expanded.append(spawn); sequence+=1
		map.monsters=expanded
	return catalog

static func apply_balance(name: String,value: Dictionary) -> Dictionary:
	if name=="items":
		for slot in ["pants","wings","pet"]:
			if not slot in value.slots: value.slots.append(slot)
	var balance: Dictionary=Catalog.read("balance")
	if name=="monsters":
		var factors: Dictionary=balance.get("monster",{})
		for config in value.species.values():
			for pair in [["hp","hp"],["attack","damage"],["defense","defense"],["experience","experience"],["respawn","respawn"]]:
				config[pair[0]]=float(config[pair[0]])*float(factors.get(pair[1],1))
			config.loot.gold_min=floori(float(config.loot.gold_min)*float(factors.get("gold",1)))
			config.loot.gold_max=floori(float(config.loot.gold_max)*float(factors.get("gold",1)))
	if name=="combat":
		var factors: Dictionary=balance.get("skill",{})
		for skill in value.skills.values():
			if skill.has("multiplier"): skill.multiplier=float(skill.multiplier)*float(factors.get("damage",1))*float(factors.get("pve",1))
			skill.mana=floori(float(skill.mana)*float(factors.get("mana",1)))
			skill.cooldown=float(skill.cooldown)*float(factors.get("cooldown",1))
	if name=="economy":
		var factors: Dictionary=balance.get("economy",{})
		value.sell_fraction=float(value.sell_fraction)*float(factors.get("sell_multiplier",1))
		for id in value.prices: value.prices[id]=floori(float(value.prices[id])*float(factors.get("buy_multiplier",1)))
	return value

static func prevents_aggro(map: Dictionary,point: Vector2) -> bool:
	for zone in map.get("zones",[]):
		if zone.get("monster_aggro_disabled",false) and Rect2(zone.x,zone.y,zone.get("width",96),zone.get("height",96)).has_point(point): return true
	return false
