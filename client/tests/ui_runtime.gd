extends "res://tests/input_runtime.gd"

func _ready() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.enter_world("Ventana","mage")
	await get_tree().create_timer(0.2).timeout
	var world: Node2D = main.world
	if not check(world.health_bar.value == App.character.hp and world.mana_bar.value == App.character.mana,"resource bars initial values"):
		await finish()
		return
	App.character.hp = 50
	App.character.mana = 60
	EterProgression.gain_experience(App.character,20)
	world.update_resources()
	if not check(world.health_bar.value == 50 and world.mana_bar.value == 60 and world.experience_bar.value == 20,"resource bars track changes"):
		await finish()
		return
	await press(KEY_M)
	if not check(world.map_panel.visible and not world.inventory_ui.visible,"M opens map"):
		await finish()
		return
	await RenderingServer.frame_post_draw
	if not check(get_viewport().get_texture().get_image().save_png("res://../artifacts/map-runtime.png") == OK,"map capture saved"):
		await finish()
		return
	await press(KEY_ESCAPE)
	if not check(not world.map_panel.visible and not world.pause_menu.visible,"Esc closes map first"):
		await finish()
		return
	await click(world.minimap.get_global_rect().get_center())
	if not check(world.map_panel.visible,"minimap click opens map"):
		await finish()
		return
	await press(KEY_I)
	if not check(world.inventory_ui.visible and not world.map_panel.visible,"I replaces map with inventory"):
		await finish()
		return
	await press(KEY_C)
	if not check(world.character_panel.visible and not world.inventory_ui.visible,"C replaces inventory"):
		await finish()
		return
	await press(KEY_C)
	await press(KEY_ENTER)
	if not check(world.chat_ui.visible and world.chat_ui.input.has_focus(),"Enter focuses chat"):
		await finish()
		return
	world.chat_ui.input.text = "Mensaje de prueba"
	await press(KEY_ENTER)
	if not check("No enviado: sin conexión" in world.chat_ui.history.get_parsed_text(),"offline chat refuses pretending delivery"):
		await finish()
		return
	world.chat_ui.append_message("Prueba","[color=red]literal[/color]")
	if not check("[color=red]literal[/color]" in world.chat_ui.history.get_parsed_text(),"chat treats markup as plain text"):
		await finish()
		return
	await RenderingServer.frame_post_draw
	if not check(get_viewport().get_texture().get_image().save_png("res://../artifacts/ui-runtime.png") == OK,"HUD and chat capture saved"):
		await finish()
		return
	await press(KEY_ESCAPE)
	if not check(not world.chat_ui.visible and not world.pause_menu.visible,"Esc closes chat first"):
		await finish()
		return
	await press(KEY_ESCAPE)
	await click(world.pause_menu.get_child(0).get_node("Settings").get_global_rect().get_center())
	var dialog: AcceptDialog
	for child in world.hud.get_children():
		if child is AcceptDialog: dialog = child
	if not check(is_instance_valid(dialog) and dialog.visible,"menu button opens actual settings dialog"):
		await finish()
		return
	if is_instance_valid(dialog):
		dialog.hide()
		dialog.canceled.emit()
	world.pause_menu.hide()
	var original_size := get_window().size
	for dimensions in [Vector2i(960,540),Vector2i(1280,720)]:
		get_window().size = dimensions
		await get_tree().create_timer(0.1).timeout
		if not check(world.minimap.get_global_rect().end.x <= 640 and world.inventory_ui.get_global_rect().end.y <= 360,"UI stays in design viewport at "+str(dimensions)):
			await finish()
			return
		await RenderingServer.frame_post_draw
		if not check(get_viewport().get_texture().get_image().get_size() == Vector2i(640,360),"integer design rendering at "+str(dimensions)):
			await finish()
			return
	get_window().size = original_size
	main.queue_free()
	await get_tree().process_frame
	print("PASS UI runtime: %s checks" % checks if not failed else "FAIL UI runtime")
	get_tree().quit(1 if failed else 0)
