@tool
extends RefCounted
var issues: Array[Dictionary] = []
var registry: RefCounted

func add(severity: String,section: String,id: String,message: String) -> void:
	issues.append({"severity":severity,"section":section,"id":id,"message":message})

func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func path_exists(asset: String) -> bool:
	if asset.is_empty(): return true
	if asset.begins_with("res://assets/"): return FileAccess.file_exists(registry.root.path_join("client/"+asset.trim_prefix("res://")))
	if registry.records("Assets").has(asset): return path_exists(registry.records("Assets")[asset].get("path",""))
	if registry.records("Audio").has(asset): return path_exists(registry.records("Audio")[asset].get("path",""))
	return false

func scan(value: Variant,section: String,id: String,key: String = "",percent_options: bool = false) -> void:
	if value is Dictionary:
		for name in value: scan(value[name],section,id,str(name),percent_options or key == "options")
	elif value is Array:
		for child in value: scan(child,section,id,key,percent_options)
	elif number(value):
		if key in ["chance","option_chance","critical_chance"] and (value < 0 or value > (100 if percent_options else 1)): add("ERROR",section,id,key+": el porcentaje debe estar entre 0 y 100.")
		if key in ["hp","max_hp","max_mana","level","stack","width","height","quantity","radius","attack_interval","respawn"] and value <= 0: add("ERROR",section,id,key+": debe ser mayor que cero.")
		if key in ["mana","cooldown","attack","defense","experience","speed","gold_min","gold_max","required_level"] and value < 0: add("ERROR",section,id,key+": no puede ser negativo.")
	elif value is String:
		if (key.ends_with("_path") or key in ["path","visual","icon_path","ground_sprite","equipped_sprite"]) and not path_exists(value): add("ERROR",section,id,"Asset inexistente o fuera de res://assets/: "+value)
		if key.ends_with("_sound") or key in ["music","ambient_sound","ambient_loop"]:
			if not value.is_empty() and not registry.records("Audio").has(value): add("ERROR",section,id,"Audio inexistente: "+value)

func bounded(map: Dictionary,point: Dictionary) -> bool:
	return point.has_all(["x","y"]) and number(point.x) and number(point.y) and point.x >= 0 and point.y >= 0 and point.x < map.width*map.tile and point.y < map.height*map.tile

func run(source: RefCounted) -> Array[Dictionary]:
	registry = source; issues.clear()
	for error in source.errors: add("ERROR","Validate","",error)
	for section in source.SECTIONS:
		for id in source.records(section):
			if not source.valid_id(id): add("ERROR",section,id,"ID interno inválido.")
			var entry: Variant = source.records(section)[id]
			if not entry is Dictionary: add("ERROR",section,id,"Registro inválido."); continue
			scan(entry,section,id)
			for class_id in entry.get("classes",[]):
				if not source.records("Classes").has(class_id): add("ERROR",section,id,"Clase inexistente: "+str(class_id))
	var items: Dictionary = source.records("Items")
	for id in items:
		var item: Dictionary = items[id]
		if not item.has_all(["name","category","size","bonuses","icon","stack","durability"]): add("ERROR","Items",id,"Faltan campos del formato de inventario."); continue
		if item.size.size() != 2 or int(item.size[0]) < 1 or int(item.size[1]) < 1 or int(item.size[0]) > int(source.data.items.grid_width) or int(item.size[1]) > int(source.data.items.grid_height): add("ERROR","Items",id,"Tamaño incompatible con inventario.")
		if item.has("slot") and not item.slot in source.data.items.slots: add("ERROR","Items",id,"Slot no registrado: "+str(item.slot))
		if not item.get("learn_skill","").is_empty() and not source.records("Skills").has(item.learn_skill): add("ERROR","Items",id,"Skill Book referencia un poder inexistente.")
		if item.get("category","") == "skill_book" and item.has("slot"): add("ERROR","Items",id,"Un Skill Book no puede equiparse.")
		var allowed: Array = source.data.get("item_options",{}).get("allowed",{}).get(item.category,[])
		for option in item.get("options",{}):
			if not option in allowed: add("ERROR","Items",id,"Opción no permitida para este tipo: "+str(option))
			if option == "skill" and not source.records("Skills").has(str(item.options[option])): add("ERROR","Items",id,"La opción Skill referencia un poder inexistente.")
	for id in ["starter_sword","starter_staff","starter_bow","potion"]:
		if not items.has(id): add("ERROR","Items",id,"El equipamiento inicial actual requiere este ID. No borrar.")
	var upgrade: Dictionary = source.data.get("items",{}).get("upgrade",{})
	if int(upgrade.get("max",0)) < 1 or upgrade.get("chances",[]).size() < int(upgrade.get("max",0)): add("ERROR","Balance","balance","Upgrade máximo excede la tabla de probabilidades.")
	for chance in upgrade.get("chances",[]):
		if not number(chance) or chance < 0 or chance > 1: add("ERROR","Balance","balance","Probabilidad de mejora inválida.")
	for shop_id in source.records("Shops"):
		for item_id in source.records("Shops")[shop_id].get("stock",[]):
			if not items.has(item_id): add("ERROR","Shops",shop_id,"Item inexistente: "+str(item_id))
			elif not source.data.economy.prices.has(item_id) and not items[item_id].has("buy_price"): add("ERROR","Shops",shop_id,"Item sin precio de compra: "+str(item_id))
	for species in source.data.get("economy",{}).get("drops",{}):
		if not source.records("Monsters").has(species): add("ERROR","Monsters",species,"Tabla de drops de monstruo inexistente.")
		for drop in source.data.economy.drops[species]:
			if not items.has(drop.get("item","")): add("ERROR","Monsters",species,"Drop referencia un item inexistente.")
			scan(drop,"Monsters",species)
			if int(drop.get("min_quantity",1)) > int(drop.get("max_quantity",1)): add("ERROR","Monsters",species,"Cantidad mínima mayor que máxima.")
			if int(drop.get("min_upgrade",0)) > int(drop.get("max_upgrade",0)) or int(drop.get("max_upgrade",0)) > int(upgrade.get("max",15)): add("ERROR","Monsters",species,"Rango de upgrade de drop inválido.")
	var maps: Dictionary = source.records("Maps")
	if not maps.has("village"): add("ERROR","Maps","village","Aldea es el mapa inicial requerido por el juego actual.")
	for map_id in maps:
		var map: Dictionary = maps[map_id]
		if not map.has_all(["width","height","tile","spawn","terrain","monsters","npcs","portals","obstacles"]): add("ERROR","Maps",map_id,"Faltan datos obligatorios del mapa."); continue
		if int(map.tile) != 32: add("ERROR","Maps",map_id,"La escala actual requiere tiles de32px.")
		if not bounded(map,map.spawn): add("ERROR","Maps",map_id,"Player Spawn fuera del mapa.")
		if not path_exists("res://assets/"+map.terrain+".png"): add("ERROR","Maps",map_id,"Base tile inexistente.")
		for group in ["monsters","npcs","portals","zones","player_spawns","audio_zones"]:
			var ids: Dictionary = {}
			for index in range(map.get(group,[]).size()):
				var entry: Dictionary = map[group][index]
				var id := str(entry.get("id",map_id+"-"+group+"-"+str(index)))
				if ids.has(id): add("ERROR","Maps",map_id,"ID de instancia duplicado: "+id)
				ids[id] = true
				if not bounded(map,entry): add("ERROR","Maps",map_id,group+" fuera del mapa: "+id)
				if group == "monsters":
					for spawn in entry.get("entries",[{"species":entry.get("species","")}]):
						if not source.records("Monsters").has(spawn.get("species","")): add("ERROR","Maps",map_id,"Spot referencia un monstruo inexistente.")
				if group == "npcs" and not source.records("NPCs").is_empty() and not source.records("NPCs").has(entry.get("npc_id",entry.id)): add("ERROR","Maps",map_id,"NPC inexistente: "+id)
				if group == "portals":
					if not maps.has(entry.get("target","")): add("ERROR","Maps",map_id,"Portal sin destino válido: "+id)
					elif not bounded(maps[entry.target],entry.get("arrival",{})): add("ERROR","Maps",map_id,"Llegada de portal fuera del destino.")
				if group == "player_spawns" and not maps.has(entry.get("target",map_id)): add("ERROR","Maps",map_id,"Spawn destination missing.")
				scan(entry,"Maps",map_id)
	for npc_id in source.records("NPCs"):
		var npc: Dictionary = source.records("NPCs")[npc_id]
		if npc.get("type","shop") == "shop" and not source.records("Shops").has(npc.get("shop_id",npc_id)): add("ERROR","NPCs",npc_id,"Tienda inexistente.")
	for class_id in source.data.get("combat",{}).get("classes",{}):
		for id in source.data.combat.classes[class_id].get("skills",[]):
			if not source.records("Skills").has(id): add("ERROR","Classes",class_id,"Poder inexistente: "+str(id))
	for id in source.records("Skills"):
		var skill: Dictionary = source.records("Skills")[id]
		if not skill.get("book_item_id","").is_empty() and (not items.has(skill.book_item_id) or items[skill.book_item_id].get("learn_skill","") != id): add("ERROR","Skills",id,"Libro de aprendizaje incompatible.")
		if skill.get("mode","single") in ["buff","debuff","directional"]: add("WARNING","Skills",id,"Este comportamiento debe probarse en Test Skill; no equivale a PvP avanzado.")
	for id in source.records("Quests"):
		var quest: Dictionary = source.records("Quests")[id]
		if not source.records("Monsters").has(quest.objective.species): add("ERROR","Quests",id,"Objetivo referencia monstruo inexistente.")
		if not maps.has(quest.map_id): add("ERROR","Quests",id,"Mapa de quest inexistente.")
		for reward in quest.reward.items:
			if not items.has(reward.definition): add("ERROR","Quests",id,"Recompensa referencia item inexistente.")
	if issues.is_empty(): add("INFO","Validate","","Contenido válido: referencias y formatos compatibles.")
	return issues
