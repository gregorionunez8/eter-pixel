extends Control

signal changed
signal drop_requested(uid: String)
var character: Dictionary
var grid: Control
var detail := Label.new()
var action := Button.new()
var selected_uid := ""
var slots: Array[Button] = []

func _ready() -> void:
	position = Vector2(300,63)
	size = Vector2(324,246)
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522")
	style.border_color = Color("796654")
	style.set_border_width_all(1)
	background.add_theme_stylebox_override("panel",style)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := Label.new()
	title.text = "Inventario · I: cerrar"
	title.position = Vector2(12,7)
	title.add_theme_font_size_override("font_size",13)
	add_child(title)
	grid = Control.new()
	grid.set_script(preload("res://scripts/inventory_grid.gd"))
	grid.character = character
	grid.position = Vector2(12,34)
	grid.size = Vector2(160,120)
	grid.changed.connect(notify_changed)
	grid.selected.connect(select_item)
	grid.activated.connect(func(uid): selected_uid = uid; activate())
	add_child(grid)
	detail.position = Vector2(12,159)
	detail.size = Vector2(165,53)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",9)
	add_child(detail)
	action.text = "Equipar/usar"
	action.name = "Use"
	action.position = Vector2(12,215)
	action.size = Vector2(97,24)
	action.add_theme_font_size_override("font_size",10)
	action.pressed.connect(activate)
	add_child(action)
	var drop := Button.new()
	drop.text = "Soltar"
	drop.name = "Drop"
	drop.position = Vector2(112,215)
	drop.size = Vector2(60,24)
	drop.add_theme_font_size_override("font_size",10)
	drop.pressed.connect(func(): if not selected_uid.is_empty(): drop_requested.emit(selected_uid))
	add_child(drop)
	var names := ["Arma","Armadura","Yelmo","Guantes","Botas","Escudo","Anillo","Colgante","Pantalón","Alas","Mascota"]
	for index in range(EterInventory.definitions().slots.size()):
		var button := Button.new()
		button.set_script(preload("res://scripts/inventory_slot.gd"))
		button.character = character
		button.slot = EterInventory.definitions().slots[index]
		button.text = names[index]
		button.position = Vector2(182+(index%2)*68,34+(index/2)*34)
		button.size = Vector2(64,30)
		button.add_theme_font_size_override("font_size",9)
		button.changed.connect(notify_changed)
		button.pressed.connect(func(): if character.inventory.equipment.has(button.slot): select_item(character.inventory.equipment[button.slot]))
		add_child(button)
		slots.append(button)
	refresh()

func select_item(uid: String) -> void:
	selected_uid = uid
	refresh()

func activate() -> void:
	var item := EterInventory.find(character.inventory,selected_uid)
	if item.is_empty():
		return
	var definition: Dictionary = EterInventory.definitions().definitions[item.definition]
	if App.online:
		if definition.category in ["potion","skill_book"]: App.send_intent("consume",{"uid":item.uid})
		elif character.inventory.equipment.values().has(item.uid):
			for slot in character.inventory.equipment:
				if character.inventory.equipment[slot] == item.uid: App.send_intent("unequip",{"slot":slot})
		else: App.send_intent("equip",{"uid":item.uid})
		return
	var success := false
	if definition.category == "skill_book": success=EterInventory.learn_book(character,item.uid)
	elif definition.category == "potion":
		if character.hp < character.stats.max_hp:
			character.hp = mini(character.stats.max_hp,character.hp+floori(character.stats.max_hp*float(definition.heal_fraction)))
			item.count -= 1
			if item.count == 0:
				EterInventory.remove(character.inventory,item.uid)
			success = true
	elif character.inventory.equipment.values().has(item.uid):
		for slot in character.inventory.equipment.keys():
			if character.inventory.equipment[slot] == item.uid:
				success = EterInventory.unequip(character.inventory,slot)
	else:
		success = EterInventory.equip(character,item.uid)
	if success:
		notify_changed()
	else:
		detail.text = "No se pudo: clase, espacio o vida completa."

func notify_changed() -> void:
	changed.emit()
	refresh()

func refresh() -> void:
	if not grid:
		return
	grid.queue_redraw()
	for button in slots:
		button.refresh()
	var item := EterInventory.find(character.inventory,selected_uid)
	detail.text = "Arrastrá para mover/equipar.\nDoble clic o clic derecho: usar.\nEquipo: seleccionar y desequipar." if item.is_empty() else EterItemVisual.description(item)
	action.text = "Desequipar" if character.inventory.equipment.values().has(selected_uid) else "Equipar/usar"
