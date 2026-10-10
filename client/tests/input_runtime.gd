extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failed = true
		printerr("FAIL input: " + description)
	return condition

func finish() -> void:
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var button := InputEventMouseButton.new()
	button.position = point
	button.global_position = point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	get_viewport().push_input(button, true)
	await get_tree().process_frame
	button = button.duplicate()
	button.pressed = false
	get_viewport().push_input(button, true)
	await get_tree().process_frame

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func _ready() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	print("INPUT fixture: viewport=%s play_rect=%s" % [get_viewport().size, main.menu.get_node("Panel/Buttons/Play").get_global_rect()])
	await click(main.menu.get_node("Panel/Buttons/Play").get_global_rect().get_center())
	if not check(is_instance_valid(main.creation), "mouse activates Play"):
		await finish()
		return
	if not is_instance_valid(main.creation):
		get_tree().quit(1)
		return
	main.creation.name_input.text = "Acero"
	var enter_button: Button = main.creation.get_child(2).get_child(4).get_child(0)
	await click(enter_button.get_global_rect().get_center())
	if not check(is_instance_valid(main.world), "mouse activates create character"):
		await finish()
		return
	if not is_instance_valid(main.world):
		get_tree().quit(1)
		return
	var world: Node2D = main.world
	await get_tree().physics_frame
	var start: Vector2 = world.player.position
	var destination := start + Vector2(64,0)
	await click(world.get_canvas_transform() * destination)
	for tick in range(70):
		await get_tree().physics_frame
	if not check(world.player.position.x > start.x + 50, "mouse input moves real player"):
		await finish()
		return
	if not check(world.is_safe(world.player.position), "mouse movement keeps collision safety"):
		await finish()
		return
	# Position fixture near an effigy to test interaction and hotkey routing.
	var target: EterTrainingTarget = world.targets[1]
	world.player.position = target.position + Vector2(0,-32)
	world.player.path.clear()
	world.player.camera.force_update_scroll()
	await get_tree().process_frame
	await click(world.get_canvas_transform() * (target.position + Vector2(0,-16)))
	if not check(world.combat.selected == target, "mouse selects target"):
		await finish()
		return
	await press(KEY_1)
	if not check(float(world.combat.cooldowns.get("power_strike", 0)) > 0, "skill key executes combat command"):
		await finish()
		return
	await press(KEY_ESCAPE)
	if not check(world.pause_menu.visible, "Esc opens menu"):
		await finish()
		return
	await click(world.pause_menu.get_child(0).get_child(1).get_global_rect().get_center())
	if not check(not world.pause_menu.visible, "mouse resumes from menu"):
		await finish()
		return
	await RenderingServer.frame_post_draw
	if not check(get_viewport().get_texture().get_image().save_png("res://../artifacts/input-runtime.png") == OK, "real render capture saved"):
		await finish()
		return
	print("PASS input runtime: %s checks, viewport mouse and keyboard in real renderer" % checks if not failed else "FAIL input runtime suite")
	get_tree().quit(1 if failed else 0)
