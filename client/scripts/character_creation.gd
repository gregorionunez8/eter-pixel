extends Control

signal character_created(player_name: String, class_id: String)
signal canceled
signal saved_selected(character: Dictionary)

var name_input := LineEdit.new()
var class_select := OptionButton.new()
var detail := Label.new()
var error := Label.new()
var preview := Sprite2D.new()
var class_ids: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("111522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "ÉTER · Crear personaje"
	title.position = Vector2(175, 22)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("64c8cf")
	add_child(title)
	var box := VBoxContainer.new()
	box.position = Vector2(242, 75)
	box.size = Vector2(350, 260)
	box.add_theme_constant_override("separation", 9)
	add_child(box)
	name_input.placeholder_text = "Nombre (3 a 16 letras o números)"
	name_input.max_length = 16
	box.add_child(name_input)
	class_ids = EterCharacter.definitions().classes.keys()
	for class_id in class_ids:
		class_select.add_item(EterCharacter.definitions().classes[class_id].name)
	box.add_child(class_select)
	class_select.item_selected.connect(update_selection)
	detail.add_theme_font_size_override("font_size", 12)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(350, 115)
	box.add_child(detail)
	error.add_theme_font_size_override("font_size", 11)
	error.modulate = Color("df8667")
	box.add_child(error)
	var row := HBoxContainer.new()
	box.add_child(row)
	var create_button := Button.new()
	create_button.text = "Entrar a la aldea"
	create_button.pressed.connect(submit)
	row.add_child(create_button)
	var back := Button.new()
	back.text = "Volver"
	back.pressed.connect(func(): canceled.emit())
	row.add_child(back)
	var load_button := Button.new()
	load_button.text = "Cargar nombre"
	load_button.pressed.connect(func():
		var saved := EterSave.load_character("user://characters/%s.json" % name_input.text.strip_edges()) if EterCharacter.valid_name(name_input.text.strip_edges()) else {}
		if saved.is_empty():
			error.text = "No hay guardado válido con ese nombre."
		else:
			saved_selected.emit(saved))
	row.add_child(load_button)
	preview.position = Vector2(130, 180)
	preview.scale = Vector2(3, 3)
	preview.hframes = 4
	preview.vframes = 8
	preview.frame = 8
	add_child(preview)
	update_selection(0)
	name_input.grab_focus()

func update_selection(index: int) -> void:
	var class_id: String = class_ids[index]
	var definition: Dictionary = EterCharacter.definitions().classes[class_id]
	var character := EterCharacter.create("Viajero", class_id)
	detail.text = "%s\nFuerza %s · Agilidad %s · Vitalidad %s · Energía %s\nVida %s · Maná %s · Ataque %s · Defensa %s\nVelocidad %s · Precisión %s · Evasión %s" % [definition.description, character.attributes.strength, character.attributes.agility, character.attributes.vitality, character.attributes.energy, character.stats.max_hp, character.stats.max_mana, character.stats.attack, character.stats.defense, character.stats.speed, character.stats.accuracy, character.stats.evasion]
	preview.texture = load("res://assets/%s.png" % definition.sprite)

func submit() -> void:
	var value := name_input.text.strip_edges()
	if not EterCharacter.valid_name(value):
		error.text = "Usá 3–16 letras, números o guión bajo."
		return
	if App.persistence_enabled and FileAccess.file_exists("user://characters/%s.json" % value):
		error.text = "Nombre guardado. Usá Cargar nombre."
		return
	character_created.emit(value, class_ids[class_select.selected])
