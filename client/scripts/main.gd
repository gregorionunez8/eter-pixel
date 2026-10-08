extends Node

var menu: Control
var world: Node
var status: Label
var creation: Control

func _ready() -> void:
	show_menu()
	if "--capture-progression" in OS.get_cmdline_user_args():
		enter_world("Acero", "warrior")
		EterProgression.gain_experience(App.character, 100)
		world.update_resources()
		world.character_panel.show()
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var result: int = get_viewport().get_texture().get_image().save_png("res://../artifacts/progression.png")
		assert(result == OK)
		print("PASS rendered progression capture")
		get_tree().quit()
	if "--capture-monsters" in OS.get_cmdline_user_args():
		enter_world("Acero", "warrior")
		world.player.position = Vector2(38 * 32 + 16, 24 * 32 + 16)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var result: int = get_viewport().get_texture().get_image().save_png("res://../artifacts/monsters.png")
		assert(result == OK)
		print("PASS rendered monsters capture")
		get_tree().quit()
	if "--capture-combat" in OS.get_cmdline_user_args():
		enter_world("Bruma", "mage")
		world.combat.random.seed = 1909
		world.player.position = world.targets[1].position + Vector2(0,-64)
		await get_tree().physics_frame
		world.combat.select_target(world.targets[1])
		world.combat.cast("nova")
		world.combat.cast("fireball")
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var result: int = get_viewport().get_texture().get_image().save_png("res://../artifacts/combat.png")
		assert(result == OK)
		print("PASS rendered combat capture")
		get_tree().quit()
	if "--capture-classes" in OS.get_cmdline_user_args():
		start_game()
		for index in range(3):
			creation.class_select.select(index)
			creation.update_selection(index)
			await get_tree().create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			var result: int = get_viewport().get_texture().get_image().save_png("res://../artifacts/class-%s.png" % creation.class_ids[index])
			assert(result == OK)
		print("PASS rendered class captures")
		get_tree().quit()
	if "--capture-menu" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png("res://../artifacts/menu.png")
		assert(result == OK)
		print("PASS rendered menu capture")
		get_tree().quit()
	if "--capture-world" in OS.get_cmdline_user_args():
		enter_world("Viajero", "warrior")
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
		assert(is_instance_valid(creation))
		creation.name_input.text = "Viajero"
		creation.submit()
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
	for entry in [["Play", "Jugar", start_game], ["Continue", "Continuar último", continue_game], ["Settings", "Configuración", show_settings], ["Exit", "Salir", exit_game]]:
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
	creation = Control.new()
	creation.set_script(preload("res://scripts/character_creation.gd"))
	creation.character_created.connect(enter_world)
	creation.saved_selected.connect(load_selected)
	creation.canceled.connect(func(): creation.queue_free(); show_menu())
	add_child(creation)

func enter_world(player_name: String, class_id: String) -> void:
	App.character = EterCharacter.create(player_name, class_id)
	if App.character.is_empty():
		App.log_error("Creación inválida")
		return
	App.player_name = player_name
	App.class_id = class_id
	open_world()

func continue_game() -> void:
	var saved := EterSave.load_character()
	if saved.is_empty():
		status.text = "No hay guardado local válido"
		return
	load_selected(saved)

func load_selected(saved: Dictionary) -> void:
	App.character = saved
	App.player_name = saved.name
	App.class_id = saved.class_id
	open_world()

func open_world() -> void:
	App.active_character = true
	if is_instance_valid(menu):
		menu.queue_free()
	if is_instance_valid(creation):
		creation.queue_free()
	world = preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	App.save_character()

func exit_game() -> void:
	get_tree().quit()
