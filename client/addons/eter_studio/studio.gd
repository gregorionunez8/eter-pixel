@tool
extends VBoxContainer
const Registry = preload("registry.gd")
const Schema = preload("schema.gd")
const Form = preload("form.gd")
const AssetEditor = preload("asset_editor.gd")
var asset_window: Window
var asset_editor: VBoxContainer
var asset_setter: Callable
var registry: RefCounted
var editor_plugin: EditorPlugin
var navigation := Tree.new()
var listing := ItemList.new()
var search := LineEdit.new()
var filter := OptionButton.new()
var sort := OptionButton.new()
var title := Label.new()
var status := Label.new()
var body := VBoxContainer.new()
var ids: Array[String] = []
var section := "Items"
var selected_id := ""
var form: VBoxContainer
var pending: Callable

func _ready() -> void:
	registry = Registry.new()
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	var logo := Label.new(); logo.text = "ÉTER STUDIO"; toolbar.add_child(logo)
	for entry in [["Save / Save All",save_all],["Build Content",build_content],["Validate",show_validation],["Search / References",show_references],["Reload",reload_content]]:
		var button := Button.new(); button.text = entry[0]; toolbar.add_child(button); button.pressed.connect(entry[1])
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	navigation.custom_minimum_size.x = 180; navigation.hide_root = true; split.add_child(navigation)
	var root_item := navigation.create_item()
	for group in {"CONTENT":["Items","Monsters","Skills","NPCs","Shops","Quests"],"WORLD":["Maps","Spots","Zones","Portals","Player Spawns","Audio Zones"],"GAME":["Balance","Progression","Reset","Classes","Drops","Options"],"MEDIA":["Asset Editor","Assets","Audio"],"TOOLS":["Validate","Search","References","Test Content"]}:
		var parent := navigation.create_item(root_item); parent.set_text(0,group); parent.set_selectable(0,false)
		for category in {"CONTENT":["Items","Monsters","Skills","NPCs","Shops","Quests"],"WORLD":["Maps","Spots","Zones","Portals","Player Spawns","Audio Zones"],"GAME":["Balance","Progression","Reset","Classes","Drops","Options"],"MEDIA":["Asset Editor","Assets","Audio"],"TOOLS":["Validate","Search","References","Test Content"]}[group]:
			var item := navigation.create_item(parent); item.set_text(0,category); item.set_metadata(0,category)
	navigation.item_selected.connect(func(): navigate(str(navigation.get_selected().get_metadata(0))))
	var content := HSplitContainer.new(); split.add_child(content); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var browser := VBoxContainer.new(); browser.custom_minimum_size.x = 240; content.add_child(browser)
	search.placeholder_text = "Buscar ID / nombre"; browser.add_child(search); search.text_changed.connect(func(_text): refresh_list())
	var controls := HBoxContainer.new(); browser.add_child(controls)
	filter.add_item("Todos"); controls.add_child(filter); filter.item_selected.connect(func(_index): refresh_list())
	sort.add_item("ID A → Z"); sort.add_item("Nombre A → Z"); sort.add_item("Nombre Z → A"); controls.add_child(sort); sort.item_selected.connect(func(_index): refresh_list())
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL; browser.add_child(listing)
	listing.item_selected.connect(func(index: int): select_record(ids[index]))
	var actions := HBoxContainer.new(); browser.add_child(actions)
	for entry in [["Create",false],["Duplicate",true]]:
		var button := Button.new(); button.text = entry[0]; actions.add_child(button); button.pressed.connect(func(): create_dialog(entry[1]))
	var remove := Button.new(); remove.text = "Delete"; actions.add_child(remove); remove.pressed.connect(delete_dialog)
	var scroll := ScrollContainer.new(); content.add_child(scroll); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
	title.text = "Seleccionar contenido"; body.add_child(title)
	registry.changed.connect(update_dirty)
	navigate("Items")

func update_dirty() -> void:
	status.text = "● Cambios sin guardar" if registry.dirty() else "Contenido compartido cargado · sin cambios"

func clear_body() -> void:
	for child in body.get_children(): child.queue_free()

func guard(action: Callable) -> void:
	if not registry.dirty(): action.call(); return
	var dialog := ConfirmationDialog.new(); dialog.title = "Cambios sin guardar"
	dialog.dialog_text = "Hay cambios en memoria. Guardar todo antes de continuar, continuar conservándolos sin guardar, o cancelar."
	dialog.ok_button_text = "Guardar todo"; dialog.add_button("Continuar sin guardar",false,"keep")
	add_child(dialog)
	dialog.confirmed.connect(func(): if save_all(): action.call(); dialog.queue_free())
	dialog.custom_action.connect(func(_name): action.call(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(540,160))

func navigate(kind: String) -> void:
	guard(func():
		section = kind; selected_id = ""; clear_body()
		filter.clear(); filter.add_item("Todos")
		if kind == "Items":
			for type in Schema.ITEM_TYPES: filter.add_item(type)
		refresh_list()
		if kind == "Validate": show_validation()
		elif kind in ["Search","References"]: show_references()
		elif kind == "Asset Editor": open_asset("",Callable())
		elif kind == "Test Content": show_test_tools())

func refresh_list() -> void:
	listing.clear(); ids.clear()
	var records: Dictionary = registry.records(section)
	var ordered: Array = records.keys()
	ordered.sort_custom(func(a,b):
		var first := str(records[a].get("name",a)) if sort.selected > 0 else str(a)
		var second := str(records[b].get("name",b)) if sort.selected > 0 else str(b)
		return first.naturalnocasecmp_to(second)<0 if sort.selected<2 else first.naturalnocasecmp_to(second)>0)
	for id in ordered:
		var record: Dictionary = records[id]
		if not search.text.is_empty() and not search.text.to_lower() in (str(id)+" "+str(record.get("name",""))).to_lower(): continue
		if section == "Items" and filter.selected>0 and record.get("category","") != filter.get_item_text(filter.selected): continue
		ids.append(str(id)); listing.add_item(str(record.get("name",id))+" · "+str(id))
		if id == selected_id: listing.select(ids.size()-1)

func select_record(id: String) -> void:
	guard(func(): open_record(id))

func open_record(id: String) -> void:
	selected_id = id; clear_body()
	var heading := Label.new(); heading.text = section+" · "+id+" (ID estable)"; body.add_child(heading)
	var notes: Dictionary={"Skills":"Runtime: single/area/multiple/heal. Cast Time y VFX externos preparados; BUFF/DEBUFF/DIRECTIONAL bloquean Build.","Monsters":"Runtime: HP/daño/AI, hoja y mapping. Max MP/Magic Defense y hit visual preparados.","Zones":"Rectángulos y aggro disabled activos. PvP/skill restrictions/respawn policies preparados."}
	if notes.has(section):
		var note := Label.new(); note.text=notes[section]; note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(note)
	if section in ["Items","Monsters","Skills","NPCs"]: add_previews(id)
	if section in ["Items","Monsters","Skills","NPCs","Maps","Spots"]:
		var test := Button.new(); test.text="TEST · "+section; body.add_child(test); test.disabled=editor_plugin==null; test.pressed.connect(func(): test_content(section,id))
	form = Form.new(); body.add_child(form); form.open(registry,section,registry.record(section,id))
	form.asset_requested.connect(import_audio if section=="Audio" else open_asset)
	form.edited.connect(refresh_list)
	if section == "Skills":
		var book := Button.new(); book.text="CREATE SKILL BOOK"; body.add_child(book); book.pressed.connect(func(): create_skill_book(id))
	if section == "Monsters":
		var label := Label.new(); label.text = "Drops del monstruo · probabilidades en %"; body.add_child(label)
		var drops_form := Form.new(); body.add_child(drops_form)
		if not registry.data.economy.drops.has(id): registry.data.economy.drops[id] = []
		drops_form.open(registry,"Drops",{"drops":registry.data.economy.drops[id]})
		drops_form.edited.connect(func(): registry.data.economy.drops[id] = drops_form.target.drops)
		var multiplier := float(registry.data.balance.get("monster",{}).get("drop_rate",1))
		for drop in registry.data.economy.drops[id]:
			var summary := Label.new(); summary.text="%s · base %.4f%% · efectiva %.4f%% (%sx)" % [str(registry.record("Items",str(drop.get("item",""))).get("name",drop.get("item",""))),float(drop.get("chance",0))*100,minf(1,float(drop.get("chance",0))*multiplier)*100,str(multiplier)]; body.add_child(summary)
		var sort_drops := Button.new(); sort_drops.text="Ordenar drops por chance"; body.add_child(sort_drops)
		sort_drops.pressed.connect(func(): registry.data.economy.drops[id].sort_custom(func(a,b): return a.chance>b.chance); registry.touch(); open_record(id))
	if section == "Items": add_upgrade_preview(id)
	if section == "Classes" and registry.data.combat.classes.has(id):
		var attack_label := Label.new(); attack_label.text="Attack Range / Interval / Skills"; body.add_child(attack_label)
		var class_form := Form.new(); body.add_child(class_form); class_form.open(registry,"Classes",registry.data.combat.classes[id])
	if section == "Balance": add_balance_panels()
	if section == "Progression": add_experience_table()
	if section == "Audio":
		var settings_form := Form.new(); body.add_child(settings_form)
		settings_form.open(registry,"Audio",{"footsteps":registry.data.audio.footsteps})
		settings_form.edited.connect(func(): registry.data.audio.footsteps=settings_form.target.footsteps)
		var audio_controls := HBoxContainer.new(); body.add_child(audio_controls)
		var preview := AudioStreamPlayer.new(); body.add_child(preview)
		var play := Button.new(); play.text="Play"; audio_controls.add_child(play)
		play.pressed.connect(func():
			var audio: Dictionary=registry.record("Audio",id)
			if str(audio.get("path","")).is_empty(): message("Importar audio primero."); return
			preview.stream=load(audio.path).duplicate()
			if preview.stream is AudioStreamWAV: preview.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if audio.get("loop",false) else AudioStreamWAV.LOOP_DISABLED
			elif preview.stream is AudioStreamOggVorbis: preview.stream.loop=audio.get("loop",false)
			preview.stream_paused=false; preview.volume_db=linear_to_db(maxf(0.0001,float(audio.get("volume",1)))); preview.pitch_scale=float(audio.get("pitch",1)); preview.play())
		var pause := Button.new(); pause.text="Pause / Resume"; audio_controls.add_child(pause); pause.pressed.connect(func(): preview.stream_paused=not preview.stream_paused)
		var stop := Button.new(); stop.text="Stop"; audio_controls.add_child(stop); stop.pressed.connect(preview.stop)
	if section == "Maps":
		var map_editor := preload("map_editor.gd").new(); map_editor.open(registry,registry.record("Maps",id)); body.add_child(map_editor)
		map_editor.asset_requested.connect(open_asset)
	refresh_list()

func create_dialog(duplicate: bool) -> void:
	if not registry.SECTIONS.has(section): message("Instancias de mundo se crean desde Maps, mediante colocación con mouse."); return
	if duplicate and selected_id.is_empty(): message("Seleccionar contenido para duplicar."); return
	var dialog := ConfirmationDialog.new(); dialog.title = "Duplicar" if duplicate else "Crear"
	var input := LineEdit.new(); input.placeholder_text = "ID interno único: blade_001"; dialog.add_child(input); add_child(dialog)
	dialog.confirmed.connect(func():
		var value: Dictionary = registry.record(section,selected_id).duplicate(true) if duplicate else Schema.defaults(section)
		if section == "Maps": value.id = input.text
		var error: String = registry.duplicate_record(section,selected_id,input.text) if duplicate else registry.create(section,input.text,value)
		if not error.is_empty(): message(error)
		else: open_record(input.text)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(420,140))

func delete_dialog() -> void:
	if selected_id.is_empty(): return
	var refs: Array[Dictionary] = registry.references(section,selected_id)
	var text := "¿Eliminar "+selected_id+"?"
	if not refs.is_empty():
		text += "\nReferenciado por:"
		for reference in refs: text += "\n"+reference.section+" / "+reference.id+" · "+reference.path
		text += "\nBuild será bloqueado mientras existan referencias rotas."
	var dialog := ConfirmationDialog.new(); dialog.title = "Confirmar eliminación"; dialog.dialog_text = text.replace("\n","
"); add_child(dialog)
	var removing := selected_id; var kind := section
	dialog.confirmed.connect(func(): registry.delete(kind,removing); selected_id=""; clear_body(); refresh_list(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(560,260))

func save_all() -> bool:
	var error: String = registry.save_all()
	message("Guardado completo." if error.is_empty() else error)
	return error.is_empty()

func build_content() -> void:
	var error: String = registry.build()
	if error.is_empty() and editor_plugin != null: editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	message("Build completo: shared → client/data. Reiniciar juego y servidor para cargar los cambios." if error.is_empty() else error)

func reload_content() -> void:
	var action := func(): registry.reload(); refresh_list(); clear_body()
	if registry.dirty():
		var dialog := ConfirmationDialog.new(); dialog.dialog_text="Recargar descarta los cambios sin guardar. ¿Continuar?"; add_child(dialog)
		dialog.confirmed.connect(func(): action.call(); dialog.queue_free()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()
	else: action.call()

func show_validation() -> void:
	clear_body()
	for issue in registry.validate():
		var button := Button.new(); button.text = issue.severity+" · "+issue.section+" / "+issue.id+" · "+issue.message; button.alignment = HORIZONTAL_ALIGNMENT_LEFT; body.add_child(button)
		button.pressed.connect(func():
			if registry.record(issue.section,issue.id).is_empty(): return
			section = issue.section; refresh_list(); open_record(issue.id))

func show_references() -> void:
	clear_body()
	var query := LineEdit.new(); query.placeholder_text="Buscar globalmente: goblin / blade_001"; body.add_child(query)
	var results := VBoxContainer.new(); body.add_child(results)
	var refresh := func(text: String):
		for child in results.get_children(): child.queue_free()
		var matches: Array = registry.references(section,selected_id) if text.is_empty() and not selected_id.is_empty() else registry.search(text)
		for match in matches:
			var button := Button.new(); button.text=match.section+" · "+match.id; results.add_child(button)
			button.pressed.connect(func(): section=match.section; refresh_list(); open_record(match.id))
	query.text_changed.connect(refresh); refresh.call("")

func message(text: String) -> void:
	status.text = text+(" · ● Sin guardar" if registry.dirty() else "")

func resolve_asset(value: String) -> String:
	if registry.records("Assets").has(value): return str(registry.record("Assets",value).get("path",""))
	return value

func open_asset(current: String,setter: Callable) -> void:
	if asset_window == null:
		asset_window = Window.new(); asset_window.title="ÉTER Studio · Asset Editor"; asset_window.size=Vector2i(1100,760); add_child(asset_window)
		asset_editor = AssetEditor.new(); asset_window.add_child(asset_editor); asset_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		asset_window.close_requested.connect(func(): asset_editor.confirm_destructive(func(): asset_window.hide()))
		asset_editor.saved.connect(func(file_path: String):
			var id := file_path.get_file().get_basename().to_snake_case()
			if not registry.valid_id(id): id="asset_"+str(file_path.hash()).replace("-","")
			var suffix := 1; var base := id
			while registry.records("Assets").has(id) and registry.record("Assets",id).get("path","")!=file_path:
				id=base+"_"+str(suffix); suffix+=1
			if not registry.records("Assets").has(id): registry.create("Assets",id,{"name":id,"path":file_path,"category":"Custom"})
			if asset_setter.is_valid(): asset_setter.call(file_path)
			if editor_plugin != null: editor_plugin.get_editor_interface().get_resource_filesystem().scan()
			message("PNG guardado. Save All y Build Content para publicar sus referencias."))
	var action := func():
		asset_setter=setter
		var file_path := resolve_asset(current)
		if not file_path.is_empty() and FileAccess.file_exists(file_path): asset_editor.open_png(file_path)
		asset_window.popup_centered()
	asset_editor.confirm_destructive(action)

func show_test_tools() -> void:
	clear_body()
	var label := Label.new(); label.text="Test Content usa el runtime actual. Guardar y construir antes de ejecutar."; body.add_child(label)
	var run := Button.new(); run.text="Play · juego existente"; body.add_child(run)
	run.disabled=editor_plugin==null
	run.text="Open isolated Test Room"
	run.pressed.connect(func(): test_content("Maps","village"))

func import_audio(_current: String,setter: Callable) -> void:
	var dialog := FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters=PackedStringArray(["*.wav, *.ogg ; Audio WAV / OGG"]); add_child(dialog)
	dialog.file_selected.connect(func(file_path: String):
		var destination := "res://assets/audio/"+file_path.get_file()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
		if FileAccess.file_exists(destination):
			message("Ya existe ese nombre. Renombrar el archivo antes de importar para no sobrescribir audio."); dialog.queue_free(); return
		var error := DirAccess.copy_absolute(file_path,ProjectSettings.globalize_path(destination))
		if error!=OK: message("No se pudo importar audio.")
		else:
			setter.call(destination)
			if editor_plugin!=null: editor_plugin.get_editor_interface().get_resource_filesystem().scan()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(820,560))

func create_skill_book(skill_id: String) -> void:
	var skill: Dictionary=registry.record("Skills",skill_id)
	if not str(skill.get("book_item_id","")).is_empty(): message("Este poder ya tiene un libro."); return
	var id := skill_id+"_book"; var suffix := 1
	while registry.records("Items").has(id): id=skill_id+"_book_"+str(suffix); suffix+=1
	var item := Schema.defaults("Items"); item.category="skill_book"; item.erase("slot"); item.name="Libro · "+str(skill.name)
	item.description="Aprende "+str(skill.name); item.learn_skill=skill_id; item.classes=skill.get("classes",[]).duplicate()
	if item.classes.is_empty():
		for class_id in registry.data.combat.classes:
			if skill_id in registry.data.combat.classes[class_id].skills: item.classes.append(class_id)
	item.required_level=skill.get("required_level",1); item.durability=0
	var error: String=registry.create("Items",id,item)
	if error.is_empty(): skill.book_item_id=id; registry.touch(); section="Items"; refresh_list(); open_record(id)
	else: message(error)

func add_previews(id: String) -> void:
	var strip := HBoxContainer.new(); body.add_child(strip)
	var record: Dictionary=registry.record(section,id)
	var visuals: Array=[]
	if section=="Items":
		visuals=[["Inventory Icon",record.get("icon_path",""),1,1],["Ground Item",record.get("ground_sprite",""),1,1],["Equipped Visual",record.get("equipped_visual",{}).get("path",""),record.get("equipped_visual",{}).get("hframes",1),record.get("equipped_visual",{}).get("vframes",1)]]
	elif section=="Monsters": visuals=[["Animation",record.get("visual",{}).get("path",id),record.get("visual",{}).get("hframes",4),record.get("visual",{}).get("vframes",1)]]
	elif section=="Skills": visuals=[["Skill Icon",record.get("icon_path",""),1,1]]
	else: visuals=[["NPC",record.get("visual","warrior_unarmed"),4,8]]
	for entry in visuals:
		var preview := preload("preview.gd").new(); preview.label=entry[0]; preview.columns=maxi(1,int(entry[2])); preview.rows=maxi(1,int(entry[3])); preview.animated=section=="Monsters"
		var file_path := resolve_asset(str(entry[1]))
		if not file_path.is_empty() and FileAccess.file_exists(file_path):
			var image := Image.new()
			if image.load(ProjectSettings.globalize_path(file_path))==OK: preview.texture=ImageTexture.create_from_image(image)
		elif section=="Items" and entry[0] in ["Inventory Icon","Ground Item"]:
			var image := Image.new()
			if image.load(ProjectSettings.globalize_path("res://assets/items.png"))==OK:
				var atlas := AtlasTexture.new(); atlas.atlas=ImageTexture.create_from_image(image); atlas.region=Rect2(int(record.get("icon",0))*16,0,16,16); preview.texture=atlas
		strip.add_child(preview)

func test_content(kind: String,id: String) -> void:
	var failure: String=registry.build()
	if not failure.is_empty(): message(failure); return
	var map_id := id if kind=="Maps" else id.get_slice("/",0) if kind=="Spots" else "village"
	var request := {"section":kind,"id":id,"map_id":map_id,"class_id":"warrior"}
	var error: String=registry.atomic_write(registry.root.path_join("artifacts/studio-test.json"),JSON.stringify(request))
	if not error.is_empty(): message(error); return
	if editor_plugin!=null: editor_plugin.get_editor_interface().play_custom_scene("res://scenes/studio_test_room.tscn")

func add_balance_panels() -> void:
	for entry in [["Player Stat Formulas (shared)",registry.data.classes.derived],["Item Upgrade",registry.data.items.upgrade],["Economy",registry.data.economy],["Progression / Reset",registry.data.progression]]:
		var label := Label.new(); label.text=entry[0]; body.add_child(label)
		var balance_form := Form.new(); body.add_child(balance_form)
		var target: Dictionary=entry[1]
		balance_form.open(registry,"Balance",target)
	add_experience_table()
func add_experience_table() -> void:
	var settings: Dictionary=registry.data.progression
	var label := Label.new(); label.text="Curva XP · primeras "+str(mini(200,int(settings.max_level)))+" filas (tabla o fórmula)"; body.add_child(label)
	var table := Tree.new(); table.columns=3; table.hide_root=true; table.column_titles_visible=true; table.custom_minimum_size.y=230
	for index in range(3): table.set_column_title(index,["Level","Required XP","Total XP"][index])
	body.add_child(table); var root := table.create_item(); var total := 0
	for level in range(1,mini(200,int(settings.max_level))+1):
		var xp := maxi(1,floori(float(settings.experience_base)*pow(level,float(settings.experience_exponent))))
		if settings.get("experience_mode","formula")=="table" and settings.get("experience_table",[]).size()>=level: xp=int(settings.experience_table[level-1])
		var row := table.create_item(root); row.set_text(0,str(level)); row.set_text(1,str(xp)); row.set_text(2,str(total)); total+=xp

func add_upgrade_preview(id: String) -> void:
	var record: Dictionary=registry.record("Items",id)
	if not record.has("slot"): return
	var label := Label.new(); label.text="Upgrade Preview · rarity normal"; body.add_child(label)
	var table := Tree.new(); table.columns=3; table.column_titles_visible=true; table.hide_root=true; table.custom_minimum_size.y=180
	for index in range(3): table.set_column_title(index,["+","Attack","Defense"][index])
	body.add_child(table); var root := table.create_item()
	for level in range(int(registry.data.items.upgrade.max)+1):
		var row := table.create_item(root); row.set_text(0,str(level))
		for index in range(1,3):
			var stat: String=["","attack","defense"][index]
			row.set_text(index,str(float(record.get("bonuses",{}).get(stat,0))+level*float(registry.data.items.upgrade.stat_per_level)) if record.get("bonuses",{}).has(stat) else "—")
