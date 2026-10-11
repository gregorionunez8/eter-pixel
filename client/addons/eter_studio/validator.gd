@tool
extends RefCounted
var issues: Array[Dictionary] = []
var registry: RefCounted

func add(severity: String,section: String,id: String,message: String) -> void:
	issues.append({"severity":severity,"section":section,"id":id,"message":message})

func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func path_exists(asset: String,visited: Dictionary={}) -> bool:
	if visited.has(asset): return false
	visited=visited.duplicate(); visited[asset]=true
	if asset.is_empty(): return true
	if asset.begins_with("res://assets/"): return FileAccess.file_exists(registry.root.path_join("client/"+asset.trim_prefix("res://")))
	if registry.records("Assets").has(asset): return not str(registry.records("Assets")[asset].get("path","")).is_empty() and path_exists(registry.records("Assets")[asset].path,visited)
	if registry.records("Audio").has(asset): return not str(registry.records("Audio")[asset].get("path","")).is_empty() and path_exists(registry.records("Audio")[asset].path,visited)
	return false

func media_path(asset: String,visited: Dictionary={}) -> String:
	if asset.is_empty() or visited.has(asset): return ""
	visited=visited.duplicate(); visited[asset]=true
	if asset.begins_with("res://assets/"): return registry.root.path_join("client/"+asset.trim_prefix("res://"))
	for kind in ["Assets","Audio"]:
		if registry.records(kind).has(asset): return media_path(str(registry.record(kind,asset).get("path","")),visited)
	return ""

func visual_valid(visual: Dictionary,section: String,id: String) -> void:
	if str(visual.get("path","")).is_empty(): return
	var image := Image.new()
	var file_path := media_path(str(visual.path))
	if file_path.is_empty() or not FileAccess.file_exists(file_path) or file_path.get_extension().to_lower()!="png": return
	if image.load(file_path)!=OK: add("ERROR",section,id,"PNG inválido."); return
	var columns := int(visual.get("hframes",1)); var rows := int(visual.get("vframes",1))
	if columns<1 or rows<1 or image.get_width()%maxi(1,columns)!=0 or image.get_height()%maxi(1,rows)!=0: add("ERROR",section,id,"Hoja incompatible con Hframes/Vframes.")
	for frames in visual.get("animation_mapping",{}).values():
		if not frames is Array: add("ERROR",section,id,"Mapping de animación debe ser lista de frames."); continue
		for frame in frames:
			if not number(frame) or int(frame)<0 or int(frame)>=columns*rows: add("ERROR",section,id,"Frame de animación fuera de la hoja.")

func scan(value: Variant,section: String,id: String,key: String = "",percent_options: bool = false) -> void:
	if value is Dictionary:
		for name in value: scan(value[name],section,id,str(name),percent_options or key == "options")
	elif value is Array:
		for child in value: scan(child,section,id,key,percent_options)
	elif number(value):
		if key in ["chance","option_chance","critical_chance"] and (value < 0 or value > (100 if percent_options else 1)): add("ERROR",section,id,key+": el porcentaje debe estar entre 0 y 100.")
		if key=="facing" and (value<0 or value>7 or value!=floor(value)): add("ERROR",section,id,"Facing requiere dirección entera0–7.")
		if key in ["hframes","vframes","stack","quantity","hits"] and (value<1 or value!=floor(value)): add("ERROR",section,id,key+": requiere entero positivo.")
		if key in ["hp","max_hp","max_mana","level","stack","width","height","quantity","radius","attack_interval","respawn"] and value <= 0: add("ERROR",section,id,key+": debe ser mayor que cero.")
		if key in ["mana","cooldown","attack","defense","experience","speed","gold_min","gold_max","required_level"] and value < 0: add("ERROR",section,id,key+": no puede ser negativo.")
	elif value is String:
		if (key.ends_with("_path") or key in ["path","visual","icon_path","ground_sprite","equipped_sprite","texture"]) and not path_exists(value): add("ERROR",section,id,"Asset inexistente o fuera de res://assets/: "+value)
		if not value.is_empty() and key in ["path","visual","icon_path","ground_sprite","equipped_sprite","texture"]:
			var file_path := media_path(value)
			if not file_path.is_empty() and file_path.get_extension().to_lower() not in (["wav","ogg"] if section=="Audio" else ["png"]): add("ERROR",section,id,"Formato de media incompatible: "+value)
		if key.ends_with("_sound") or key in ["music","ambient_sound","ambient_loop"]:
			if not value.is_empty() and not registry.records("Audio").has(value): add("ERROR",section,id,"Audio inexistente: "+value)

func bounded(map: Dictionary,point: Dictionary) -> bool:
	return point.has_all(["x","y"]) and number(point.x) and number(point.y) and point.x >= 0 and point.y >= 0 and point.x < map.width*map.tile and point.y < map.height*map.tile

func run(source: RefCounted) -> Array[Dictionary]:
	registry = source; issues.clear()
	for error in source.errors: add("ERROR","Validate","",error)
	if not source.errors.is_empty(): return issues
	for section in source.SECTIONS:
		for id in source.records(section):
			if not source.valid_id(id): add("ERROR",section,id,"ID interno inválido.")
			var entry: Variant = source.records(section)[id]
			if not entry is Dictionary: add("ERROR",section,id,"Registro inválido."); continue
			for visual_key in ["visual","equipped_visual"]:
				if entry.get(visual_key) is Dictionary: visual_valid(entry[visual_key],section,id)
			scan(entry,section,id)
			for class_id in entry.get("classes",[]):
				if not source.records("Classes").has(class_id): add("ERROR",section,id,"Clase inexistente: "+str(class_id))
	var items: Dictionary = source.records("Items")
	for id in items:
		var item: Dictionary = items[id]
		if not item.has_all(["name","category","size","bonuses","icon","stack","durability"]): add("ERROR","Items",id,"Faltan campos del formato de inventario."); continue
		if item.size.size() != 2 or int(item.size[0]) < 1 or int(item.size[1]) < 1 or int(item.size[0]) > int(source.data.items.grid_width) or int(item.size[1]) > int(source.data.items.grid_height): add("ERROR","Items",id,"Tamaño incompatible con inventario.")
		if item.has("slot") and not item.slot in preload("schema.gd").SLOTS.values(): add("ERROR","Items",id,"Slot no registrado: "+str(item.slot))
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
			if items.has(drop.get("item","")):
				var definition: Dictionary=items[drop.item]
				if int(drop.get("max_quantity",1))>int(definition.stack): add("ERROR","Monsters",species,"Drop supera el máximo de pila del item.")
				for option in drop.get("possible_options",[]):
					if not option is Dictionary or not option.has_all(["option","value"]): add("ERROR","Monsters",species,"Opción de drop requiere opción y valor."); continue
					if not option.option in source.data.item_options.allowed.get(definition.category,[]): add("ERROR","Monsters",species,"Opción de drop no permitida para ese item.")
			if int(drop.get("min_quantity",1)) > int(drop.get("max_quantity",1)): add("ERROR","Monsters",species,"Cantidad mínima mayor que máxima.")
			if int(drop.get("min_upgrade",0)) > int(drop.get("max_upgrade",0)) or int(drop.get("max_upgrade",0)) > int(upgrade.get("max",15)): add("ERROR","Monsters",species,"Rango de upgrade de drop inválido.")
	var maps: Dictionary = source.records("Maps")
	if not maps.has("village"): add("ERROR","Maps","village","Aldea es el mapa inicial requerido por el juego actual.")
	for map_id in maps:
		var map: Dictionary = maps[map_id]
		if not map.has_all(["name","ambient","ground_color","path_color","width","height","tile","spawn","terrain","monsters","npcs","portals","obstacles"]): add("ERROR","Maps",map_id,"Faltan datos obligatorios del mapa."); continue
		if int(map.tile) != 32: add("ERROR","Maps",map_id,"La escala actual requiere tiles de32px.")
		if not bounded(map,map.spawn): add("ERROR","Maps",map_id,"Player Spawn fuera del mapa.")
		if not path_exists(str(map.terrain)) and not path_exists("res://assets/"+map.terrain+".png"): add("ERROR","Maps",map_id,"Base tile inexistente.")
		for group in ["monsters","npcs","portals","zones","player_spawns","audio_zones"]:
			var ids: Dictionary = {}
			for index in range(map.get(group,[]).size()):
				var entry: Dictionary = map[group][index]
				var id := str(entry.get("id",map_id+"-"+group+"-"+str(index)))
				if ids.has(id): add("ERROR","Maps",map_id,"ID de instancia duplicado: "+id)
				ids[id] = true
				if group=="monsters" and (not preload("res://scripts/inventory.gd").integer(entry.get("quantity",1)) or int(entry.get("quantity",1))>64): add("ERROR","Maps",map_id,"Spot requiere cantidad entera entre 1 y64.")
				if not bounded(map,entry): add("ERROR","Maps",map_id,group+" fuera del mapa: "+id)
				if group == "monsters":
					var entries: Array=entry.get("entries",[])
					if entries.is_empty(): entries=[{"species":entry.get("species",""),"quantity":entry.get("quantity",1)}]
					var total := 0
					for spawn in entries:
						if not spawn is Dictionary: add("ERROR","Maps",map_id,"Entry de spot inválida."); continue
						var quantity: Variant=spawn.get("quantity",1)
						if not preload("res://scripts/inventory.gd").integer(quantity) or int(quantity)<1: add("ERROR","Maps",map_id,"Cantidad de entry debe ser entera y positiva.")
						total+=int(quantity)
						if not source.records("Monsters").has(spawn.get("species","")): add("ERROR","Maps",map_id,"Spot referencia un monstruo inexistente.")
					if total>64: add("ERROR","Maps",map_id,"Spot excede64 monstruos.")
				if group == "npcs" and not source.records("NPCs").has(entry.get("npc_id",entry.id)): add("ERROR","Maps",map_id,"NPC inexistente: "+id)
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
	for id in source.records("Audio"):
		if str(source.record("Audio",id).get("path","")).is_empty(): add("ERROR","Audio",id,"Importar WAV/OGG antes de construir.")
	for id in source.records("Skills"):
		var skill: Dictionary = source.records("Skills")[id]
		if not skill.get("book_item_id","").is_empty() and (not items.has(skill.book_item_id) or items[skill.book_item_id].get("learn_skill","") != id): add("ERROR","Skills",id,"Libro de aprendizaje incompatible.")
		if float(skill.get("cast_time",0))>0 or not skill.get("vfx",{}).values().all(func(value): return str(value).is_empty()): add("WARNING","Skills",id,"Cast Time y VFX externos están preparados; este runtime utiliza efectos existentes.")
		if skill.get("mode","single") in ["buff","debuff","directional"]: add("ERROR","Skills",id,"Comportamiento aún no disponible en runtime: usar single, area, multiple o heal.")
	for class_id in ["warrior","mage","elf"]:
		if not source.records("Classes").has(class_id): add("ERROR","Classes",class_id,"Clase inicial requerida: no borrar.")
	for id in source.records("Quests"):
		var quest: Dictionary = source.records("Quests")[id]
		if not quest.has_all(["name","npc","map_id","requires","dialogue","completed_dialogue","objective","reward"]) or not quest.get("objective",{}) is Dictionary or not quest.get("reward",{}) is Dictionary or not quest.get("objective",{}).has_all(["species","count","maps"]) or not quest.get("reward",{}).has_all(["experience","gold","items"]): add("ERROR","Quests",id,"Encargo incompleto: faltan objetivo, NPC o recompensa."); continue
		if not source.records("NPCs").has(quest.npc): add("ERROR","Quests",id,"NPC de entrega inexistente.")
		if quest.requires != null and not source.records("Quests").has(quest.requires): add("ERROR","Quests",id,"Prerequisito inexistente.")
		if not source.records("Monsters").has(quest.objective.species): add("ERROR","Quests",id,"Objetivo referencia monstruo inexistente.")
		if not maps.has(quest.map_id): add("ERROR","Quests",id,"Mapa de quest inexistente.")
		for reward in quest.reward.items:
			if not items.has(reward.definition): add("ERROR","Quests",id,"Recompensa referencia item inexistente.")
	for key in source.data.balance:
		scan(source.data.balance[key],"Balance","balance")
	if issues.is_empty(): add("INFO","Validate","","Contenido válido: referencias y formatos compatibles.")
	return issues
