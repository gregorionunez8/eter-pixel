@tool
extends VBoxContainer
signal edited
signal asset_requested(current: String,setter: Callable)
const Schema = preload("schema.gd")
var registry: RefCounted
var section := ""
var target: Dictionary
var rebuilding := false

func open(source: RefCounted,kind: String,record: Dictionary) -> void:
	registry = source; section = kind; target = record
	rebuild()

func rebuild() -> void:
	for child in get_children(): child.queue_free()
	var template := Schema.defaults(section)
	if section == "Items":
		if not Schema.SLOTS.has(target.get("category","weapon")): template.erase("slot")
		template.buy_price = registry.data.economy.prices.get(_item_id(),1)
	if section == "Monsters": template.visual.path = _monster_id()
	if section == "Shops":
		template.repair_enabled = _shop_id() == "smith"
		template.upgrade_enabled = _shop_id() == "smith"
	if section == "Skills" and not target.has("classes"):
		template.classes = []
		for class_id in registry.data.combat.classes:
			if _skill_id() in registry.data.combat.classes[class_id].skills: template.classes.append(class_id)
	var keys: Array = target.keys()
	for key in template:
		if not key in keys: keys.append(key)
	for key in keys:
		if key == "id": continue
		field(self,target,key,target.get(key,template.get(key)),str(key))

func _record_id(kind: String) -> String:
	for id in registry.records(kind):
		if is_same(registry.records(kind)[id],target): return id
	return ""
func _item_id() -> String: return _record_id("Items")
func _monster_id() -> String: return _record_id("Monsters")
func _shop_id() -> String: return _record_id("Shops")
func _skill_id() -> String: return _record_id("Skills")

func commit(container: Variant,key: Variant,value: Variant,full_path: String) -> void:
	if full_path == "requires" and value == "": value=null
	container[key] = value
	var parts := full_path.split("/")
	var cursor: Variant = target
	for index in range(parts.size()-1):
		var part: Variant = int(parts[index]) if cursor is Array else parts[index]
		if cursor is Dictionary and not cursor.has(part): cursor[part] = [] if parts[index+1].is_valid_int() else {}
		cursor = cursor[part]
	var final_key: Variant = int(parts[-1]) if cursor is Array else parts[-1]
	if cursor is Array:
		while cursor.size() <= int(final_key): cursor.append(null)
	cursor[final_key] = value
	if container is Dictionary and container == target and key == "category" and section == "Items":
		if Schema.SLOTS.has(value): target.slot = Schema.SLOTS[value]
		else: target.erase("slot")
		var allowed: Array = registry.data.item_options.allowed.get(value,[])
		for option in target.get("options",{}).keys():
			if not option in allowed: target.options.erase(option)
		call_deferred("rebuild")
	if container is Dictionary and container == target and key=="behavior" and section=="Skills":
		target.mode={"direct_damage":"single","projectile":"single","area_damage":"area","heal":"heal","multi_projectile":"multiple","aoe_around_player":"area","buff":"buff","debuff":"debuff","directional":"directional"}.get(value,"single")
		if value=="projectile": target.effect="fire"
		elif value=="multi_projectile": target.effect="arrow"
		call_deferred("rebuild")
	registry.touch(); edited.emit()

func choices(key: String,full_path: String) -> Array:
	if key == "category" and section == "Assets": return ["Ground","Walls","Nature","Buildings","Interior","Decoration","Special","Custom"]
	if key == "category" and section == "Audio": return ["UI","Player","Movement","Combat","Skills","Monster","NPC","Town","PvP","Ambient","Music","Items","Portals"]
	if key == "category" and section != "Items": return []
	if key=="option": return registry.data.item_options.definitions.keys()
	var references := {"item":"Items","definition":"Items","book_item_id":"Items","learn_skill":"Skills","skill":"Skills","species":"Monsters","npc":"NPCs","requires":"Quests","npc_id":"NPCs","shop_id":"Shops","target":"Maps","map_id":"Maps","scaling_stat":"Stats"}
	if full_path.begins_with("footsteps/"): return [""]+registry.records("Audio").keys()
	if key.ends_with("_sound") or key in ["music","ambient_sound","ambient_loop"]: return [""]+registry.records("Audio").keys()
	if key in references:
		if references[key] == "Stats": return ["attack","strength","agility","energy","vitality"]
		return [""]+registry.records(references[key]).keys()
	if key in ["icon_path","ground_sprite"] or key == "path" and section != "Audio" or key == "visual" and section == "NPCs": return [""]+registry.records("Assets").keys()
	if key == "terrain": return registry.records("Assets").keys()
	if full_path.begins_with("objective/maps/"): return registry.records("Maps").keys()
	if full_path.begins_with("stock/"): return registry.records("Items").keys()
	if full_path.begins_with("skills/"): return registry.records("Skills").keys()
	if full_path.begins_with("skill_restrictions/"): return registry.records("Skills").keys()
	return Schema.ENUMS.get(key,[])

func field(parent: VBoxContainer,container: Variant,key: Variant,value: Variant,full_path: String) -> void:
	var name := str(key)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption := Label.new()
	caption.text = Schema.display(name)
	caption.custom_minimum_size.x = 200
	caption.tooltip_text = full_path
	row.add_child(caption)
	if name == "classes":
		var all := Button.new(); all.text = "ALL"; row.add_child(all)
		all.pressed.connect(func(): commit(container,key,registry.records("Classes").keys(),full_path); rebuild())
		for class_id in registry.records("Classes"):
			var button := CheckBox.new(); button.text = registry.records("Classes")[class_id].name
			button.button_pressed = class_id in value
			row.add_child(button)
			button.toggled.connect(func(enabled: bool):
				var classes: Array = container.get(key,value).duplicate()
				if enabled and not class_id in classes: classes.append(class_id)
				if not enabled: classes.erase(class_id)
				commit(container,key,classes,full_path))
	elif value is Dictionary or value is Array:
		var body := VBoxContainer.new()
		parent.add_child(body)
		body.add_theme_constant_override("separation",4)
		var toggle := Button.new(); toggle.text = "Expandir / Contraer"; row.add_child(toggle)
		toggle.pressed.connect(func(): body.visible = not body.visible)
		body.visible = name in ["options","bonuses","equipped_visual","visual","audio"]
		var nested: Variant = container.get(key,value) if container is Dictionary else container[key]
		if nested is Dictionary:
			var template: Dictionary = {}
			if name == "audio":
				if section in ["Maps","Zones","Audio Zones"]: template.music=""; template.ambient_sound=""
				for event in ["interaction","greeting","shop_open","quest","reset","pickup","drop","equip","unequip","use","upgrade","repair","idle","aggro","attack","hit","death","cast","travel","impact","loop","enter","arrival","exit"]: template[event+"_sound"] = ""
			var keys: Array = nested.keys()
			for child in template:
				if not child in keys: keys.append(child)
			for child in keys:
				# Persist a default nested group only when a field is actually edited.
				var proxy: Dictionary = nested
				var row_index := body.get_child_count()
				field(body,proxy,child,nested.get(child,template.get(child)),full_path+"/"+str(child))
				if nested.has(child) and name in ["options","bonuses","prices","footsteps","buff"]:
					var remove := Button.new(); remove.text="Quitar"; body.get_child(row_index).add_child(remove)
					remove.pressed.connect(func(): nested.erase(child); commit(container,key,nested.duplicate(true),full_path); rebuild())
			var add := Button.new(); add.text = "+ Agregar campo"; row.add_child(add)
			add.pressed.connect(func(): add_key(container,key,nested,name,full_path))
		else:
			for index in range(nested.size()):
				var group := VBoxContainer.new(); body.add_child(group)
				field(group,nested,index,nested[index],full_path+"/"+str(index))
				var remove := Button.new(); remove.text = "Quitar fila "+str(index+1); group.add_child(remove)
				remove.pressed.connect(func():
					nested.remove_at(index); commit(container,key,nested,full_path); rebuild())
			var add := Button.new(); add.text = "+ Agregar fila"; row.add_child(add)
			add.pressed.connect(func():
				nested.append(Schema.array_entry(name)); commit(container,key,nested,full_path); rebuild())
	elif value is bool:
		var control := CheckBox.new(); control.button_pressed = value; row.add_child(control)
		control.toggled.connect(func(next: bool): commit(container,key,next,full_path))
	elif typeof(value) in [TYPE_INT,TYPE_FLOAT]:
		var control := SpinBox.new(); control.min_value = -1000000000; control.max_value = 1000000000
		var percent := (name in ["chance","option_chance","critical_chance"] and not full_path.begins_with("options/")) or full_path.begins_with("chances/")
		control.step = 0.0001 if percent else 0.01
		control.value = float(value)*100 if percent else float(value)
		if percent: control.min_value = 0; control.max_value = 100; control.suffix = "%"
		control.custom_minimum_size.x = 160; row.add_child(control)
		control.value_changed.connect(func(next: float): commit(container,key,next/100 if percent else next,full_path))
	else:
		var options := choices(name,full_path).duplicate()
		if not options.is_empty():
			var control := OptionButton.new(); row.add_child(control)
			if not str(value) in options: options.append(str(value))
			for option in options: control.add_item("(ninguno)" if str(option).is_empty() else str(option)); control.set_item_metadata(control.item_count-1,option)
			control.select(options.find(str(value)))
			control.item_selected.connect(func(index: int): commit(container,key,control.get_item_metadata(index),full_path))
		else:
			var control := LineEdit.new(); control.text = str(value) if value != null else ""; control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(control)
			control.text_changed.connect(func(next: String): commit(container,key,next,full_path))
		if name in ["icon_path","ground_sprite","visual","path"]:
			var asset := Button.new(); asset.text = "Dibujar / Importar" if section != "Audio" else "Importar audio"
			row.add_child(asset)
			asset.pressed.connect(func(): asset_requested.emit(str(container.get(key,value)),func(next: String): commit(container,key,next,full_path); rebuild()))

func add_key(container: Variant,key: Variant,nested: Dictionary,name: String,full_path: String) -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = "Agregar "+Schema.display(name)
	var choices := OptionButton.new()
	var options: Array = []
	if name == "options": options = registry.data.item_options.allowed.get(target.get("category","weapon"),[])
	elif name == "bonuses" or name == "buff": options = ["attack","defense","max_hp","max_mana","speed","accuracy","evasion"]
	elif name == "prices": options = registry.records("Items").keys()
	elif name == "footsteps": options = Schema.ENUMS.surface
	else: options = ["custom"]
	for option in options:
		if not nested.has(option): choices.add_item(str(option))
	if choices.item_count == 0: dialog.queue_free(); return
	dialog.add_child(choices); add_child(dialog)
	dialog.confirmed.connect(func():
		var option := choices.get_item_text(choices.selected)
		nested[option] = registry.records("Skills").keys()[0] if option == "skill" else "" if name == "footsteps" else 0
		commit(container,key,nested,full_path); rebuild(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(360,120))
