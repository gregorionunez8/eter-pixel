@tool
extends RefCounted

signal changed
const CATALOGS := ["items","monsters","combat","maps","economy","quests","classes","progression","npcs","audio","assets","balance","item_options"]
const SECTIONS := {
	"Items":["items","definitions"], "Monsters":["monsters","species"],
	"Skills":["combat","skills"], "NPCs":["npcs","definitions"],
	"Shops":["economy","shops"], "Maps":["maps","maps"],
	"Audio":["audio","definitions"], "Assets":["assets","definitions"],
	"Quests":["quests","definitions"], "Classes":["classes","classes"]
}
var root: String
var data: Dictionary = {}
var original: Dictionary = {}
var fingerprints: Dictionary = {}
var errors: Array[String] = []

func _init(repo_root: String = "") -> void:
	root = repo_root if not repo_root.is_empty() else ProjectSettings.globalize_path("res://..").simplify_path()
	reload()

func source_path(name: String) -> String:
	return root.path_join("shared/"+name+".json")

func reload() -> void:
	data.clear(); errors.clear(); fingerprints.clear()
	for name in CATALOGS:
		var content := FileAccess.get_file_as_string(source_path(name)) if FileAccess.file_exists(source_path(name)) else ""
		fingerprints[name] = content.sha256_text()
		var parser := JSON.new()
		if not content.is_empty() and (parser.parse(content) != OK or not parser.data is Dictionary):
			errors.append("%s: JSON inválido (%s)" % [name,parser.get_error_message()])
			continue
		data[name] = parser.data if not content.is_empty() else {"definitions":{}}
	original = data.duplicate(true)
	changed.emit()

func records(section: String) -> Dictionary:
	if SECTIONS.has(section):
		var location: Array = SECTIONS[section]
		return data.get(location[0],{}).get(location[1],{})
	if section in ["Balance","Progression","Reset","Drops","Options"]:
		var name: String = {"Balance":"balance","Progression":"progression","Reset":"progression","Drops":"economy","Options":"item_options"}[section]
		return {name:data.get(name,{})}
	var result: Dictionary = {}
	for map_id in data.get("maps",{}).get("maps",{}):
		var map: Dictionary = data.maps.maps[map_id]
		var key: String = {"Spots":"monsters","Zones":"zones","Portals":"portals","Player Spawns":"player_spawns","Audio Zones":"audio_zones"}.get(section,"")
		for index in range(map.get(key,[]).size()):
			var entry: Dictionary = map[key][index]
			var id: String = str(entry.get("id",map_id+"-"+key+"-"+str(index)))
			result[map_id+"/"+id] = entry
	return result

func record(section: String,id: String) -> Dictionary:
	return records(section).get(id,{})

func touch() -> void:
	changed.emit()

func dirty() -> bool:
	return data != original

func create(section: String,id: String,value: Dictionary) -> String:
	if not valid_id(id): return "ID inválido: usar letras minúsculas, números, _ o -."
	if records(section).has(id): return "El ID ya existe."
	if not SECTIONS.has(section): return "Crear esta instancia desde Maps (colocar con mouse)."
	var location: Array = SECTIONS[section]
	if not data[location[0]].has(location[1]): data[location[0]][location[1]] = {}
	data[location[0]][location[1]][id] = value.duplicate(true)
	touch()
	return ""

func delete(section: String,id: String) -> void:
	if SECTIONS.has(section):
		var location: Array = SECTIONS[section]
		data[location[0]][location[1]].erase(id)
	else:
		var map_id := id.get_slice("/",0)
		var value := record(section,id)
		var key: String = {"Spots":"monsters","Zones":"zones","Portals":"portals","Player Spawns":"player_spawns","Audio Zones":"audio_zones"}.get(section,"")
		data.maps.maps[map_id][key].erase(value)
	touch()

static func valid_id(id: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_-]{0,63}$")
	return pattern.search(id) != null

func references(section: String,id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shop_id in records("Shops"):
		if section == "Items" and id in records("Shops")[shop_id].get("stock",[]): result.append({"section":"Shops","id":shop_id,"path":"stock"})
	for species in data.get("economy",{}).get("drops",{}):
		for drop in data.economy.drops[species]:
			if section == "Items" and drop.get("item") == id: result.append({"section":"Monsters","id":species,"path":"drops"})
	for quest_id in records("Quests"):
		var quest: Dictionary = records("Quests")[quest_id]
		for reward in quest.get("reward",{}).get("items",[]):
			if section == "Items" and reward.definition == id: result.append({"section":"Quests","id":quest_id,"path":"reward"})
		if section == "Monsters" and quest.get("objective",{}).get("species") == id: result.append({"section":"Quests","id":quest_id,"path":"objective"})
		if section == "Maps" and (quest.get("map_id") == id or id in quest.get("objective",{}).get("maps",[])): result.append({"section":"Quests","id":quest_id,"path":"map"})
	for map_id in records("Maps"):
		var map: Dictionary = records("Maps")[map_id]
		for spawn in map.get("monsters",[]):
			if section == "Monsters" and (spawn.get("species") == id or spawn.get("entries",[]).any(func(e): return e.get("species") == id)): result.append({"section":"Maps","id":map_id,"path":"monsters"})
		for npc in map.get("npcs",[]):
			if section == "NPCs" and npc.get("npc_id",npc.id) == id: result.append({"section":"Maps","id":map_id,"path":"npcs"})
		for portal in map.get("portals",[]):
			if section == "Maps" and portal.target == id: result.append({"section":"Maps","id":map_id,"path":"portals"})
	for class_id in data.get("combat",{}).get("classes",{}):
		if section == "Skills" and id in data.combat.classes[class_id].skills: result.append({"section":"Classes","id":class_id,"path":"skills"})
	for skill_id in records("Skills"):
		if section == "Items" and records("Skills")[skill_id].get("book_item_id","") == id: result.append({"section":"Skills","id":skill_id,"path":"book_item_id"})
	for item_id in records("Items"):
		if section == "Skills" and records("Items")[item_id].get("learn_skill","") == id: result.append({"section":"Items","id":item_id,"path":"learn_skill"})
	for npc_id in records("NPCs"):
		if section == "Shops" and records("NPCs")[npc_id].get("shop_id","") == id: result.append({"section":"NPCs","id":npc_id,"path":"shop_id"})
	return result

func search(query: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section in SECTIONS.keys()+["Spots","Zones","Portals","Player Spawns","Audio Zones"]:
		for id in records(section):
			if query.is_empty() or query.to_lower() in (id+" "+JSON.stringify(records(section)[id])).to_lower(): result.append({"section":section,"id":id})
	return result

func validate() -> Array[Dictionary]:
	return preload("validator.gd").new().run(self)

func save_all() -> String:
	var issues := validate()
	for issue in issues:
		if issue.severity == "ERROR": return "Guardado bloqueado: "+issue.message
	# Detect external edits before touching any file.
	for name in CATALOGS:
		var disk := FileAccess.get_file_as_string(source_path(name)) if FileAccess.file_exists(source_path(name)) else ""
		if disk.sha256_text() != fingerprints.get(name,""): return "Conflicto externo en "+name+". Recargar antes de guardar."
	var written: Array[String] = []
	var backups: Dictionary = {}
	for name in CATALOGS:
		if data[name] == original.get(name): continue
		var source := source_path(name)
		backups[name] = FileAccess.get_file_as_string(source) if FileAccess.file_exists(source) else ""
		var backup_root := root.path_join("artifacts/studio-backup")
		if DirAccess.make_dir_recursive_absolute(backup_root) != OK: return "No se pudo crear backup."
		if not backups[name].is_empty():
			var backup_error := atomic_write(backup_root.path_join(name+".json"),backups[name])
			if not backup_error.is_empty(): return backup_error
		var error := atomic_write(source,JSON.stringify(data[name],"  ")+"
")
		if not error.is_empty():
			for previous in written:
				if backups[previous].is_empty(): DirAccess.remove_absolute(source_path(previous))
				else: atomic_write(source_path(previous),backups[previous])
			return error
		written.append(name)
	if not written.is_empty():
		var backup_root := root.path_join("artifacts/studio-backup")
		DirAccess.make_dir_recursive_absolute(backup_root)
		# One bounded snapshot per catalog, ignored by runtime/Git.
		for name in written:
			if not backups[name].is_empty(): atomic_write(backup_root.path_join(name+".json"),backups[name])
	reload()
	return ""

func build() -> String:
	var failure := save_all()
	if not failure.is_empty(): return failure
	var destination := root.path_join("client/data")
	DirAccess.make_dir_recursive_absolute(destination)
	for name in CATALOGS:
		if not FileAccess.file_exists(source_path(name)): continue
		failure = atomic_write(destination.path_join(name+".json"),FileAccess.get_file_as_string(source_path(name)))
		if not failure.is_empty(): return failure
	# Backward-compatible village geometry for legacy server callers.
	failure = atomic_write(root.path_join("shared/world.json"),JSON.stringify(data.maps.maps.village,"  ")+"
")
	if not failure.is_empty(): return failure
	return atomic_write(destination.path_join("world.json"),FileAccess.get_file_as_string(root.path_join("shared/world.json")))

static func atomic_write(file_path: String,content: String) -> String:
	var file := FileAccess.open(file_path+".tmp",FileAccess.WRITE)
	if file == null: return "No se pudo escribir "+file_path
	file.store_string(content); file.flush(); file.close()
	if DirAccess.rename_absolute(file_path+".tmp",file_path) != OK: return "No se pudo reemplazar "+file_path
	return ""
