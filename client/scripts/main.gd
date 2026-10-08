extends Node

var menu: Control
var world: Node
var status: Label

func _ready() -> void:
	show_menu()
	if "--capture-menu" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png("res://../artifacts/menu.png")
		assert(result == OK)
		print("PASS rendered menu capture")
		get_tree().quit()
	if "--capture-world" in OS.get_cmdline_user_args():
		start_game()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png("res://../artifacts/world.png")
		assert(result == OK)
		print("PASS rendered world capture")
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		assert(menu.has_node("Panel/Buttons/Play"))
		start_game()
		await get_tree().process_frame
		assert(is_instance_valid(world))
		print("PASS foundation: menu, transition, world scene")
		get_tree().quit()

func make_label(value: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func show_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var background := ColorRect.new()
	background.color = Color("111522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(190, 50)
	panel.size = Vector2(260, 260)
	menu.add_child(panel)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 12)
	panel.add_child(buttons)
	var logo := make_label("É T E R", 44)
	logo.modulate = Color("64c8cf")
	buttons.add_child(logo)
	buttons.add_child(make_label("El último refugio de la niebla", 12))
	for entry in [["Play", "Jugar", start_game], ["Settings", "Configuración", show_settings], ["Exit", "Salir", exit_game]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.custom_minimum_size.y = 32
		button.pressed.connect(entry[2])
		buttons.add_child(button)
	status = make_label("Desarrollo local · vertical slice en construcción", 11)
	status.position = Vector2(0, 330)
	status.size.x = 640
	menu.add_child(status)

func show_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Configuración"
	dialog.min_size = Vector2i(280, 150)
	menu.add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = App.settings.get_value("video", "fullscreen", false)
	box.add_child(fullscreen)
	box.add_child(make_label("Volumen"))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = App.settings.get_value("audio", "volume", 0.7)
	box.add_child(volume)
	dialog.confirmed.connect(func(): App.save_settings(fullscreen.button_pressed, volume.value); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func start_game() -> void:
	if is_instance_valid(world):
		return
	menu.queue_free()
	world = preload("res://scenes/world.tscn").instantiate()
	add_child(world)

func exit_game() -> void:
	get_tree().quit()
