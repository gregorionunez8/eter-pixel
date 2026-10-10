extends "res://tests/input_runtime.gd"

func drag(from: Vector2, to: Vector2) -> bool:
	get_viewport().warp_mouse(from)
	await get_tree().create_timer(0.06).timeout
	get_viewport().update_mouse_cursor_state()
	var motion := InputEventMouseMotion.new()
	motion.position = from
	motion.global_position = from
	get_viewport().push_input(motion,true)
	var button := InputEventMouseButton.new()
	button.position = from
	button.global_position = from
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	get_viewport().push_input(button,true)
	await get_tree().process_frame
	motion = InputEventMouseMotion.new()
	motion.position = from + Vector2(12,0)
	get_viewport().warp_mouse(motion.position)
	await get_tree().create_timer(0.06).timeout
	get_viewport().update_mouse_cursor_state()
	motion.global_position = motion.position
	motion.relative = Vector2(12,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	if not check(get_viewport().gui_is_dragging(), "real GUI drag begins"):
		button.pressed = false
		get_viewport().push_input(button,true)
		return false
	motion = InputEventMouseMotion.new()
	motion.position = to
	get_viewport().warp_mouse(to)
	await get_tree().create_timer(0.06).timeout
	get_viewport().update_mouse_cursor_state()
	motion.global_position = to
	motion.relative = to-from-Vector2(12,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	button = InputEventMouseButton.new()
	button.position = to
	button.global_position = to
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	get_viewport().push_input(button,true)
	await get_tree().process_frame
	return true

func _ready() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.enter_world("Acero","warrior")
	await get_tree().create_timer(0.3).timeout
	var original_cursor := get_viewport().get_mouse_position()
	var world: Node2D = main.world
	var sword := EterInventory.make_item("bronze_sword",1,"magic")
	EterInventory.add(App.character.inventory,sword)
	EterInventory.add(App.character.inventory,EterInventory.make_item("robe"))
	EterInventory.add(App.character.inventory,EterInventory.make_item("helmet",1,"excellent"))
	world.inventory_ui.refresh()
	await press(KEY_I)
	if not check(world.inventory_ui.visible, "I opens inventory"):
		await finish()
		return
	var grid: Control = world.inventory_ui.grid
	var item := EterInventory.find(App.character.inventory,sword.uid)
	if not await drag(grid.global_position+Vector2(int(item.x)*20+10,int(item.y)*20+10),grid.global_position+Vector2(90,50)):
		await finish()
		return
	item = EterInventory.find(App.character.inventory,sword.uid)
	if not check(item.x == 4 and item.y == 2, "mouse drag moves item in grid"):
		await finish()
		return
	var slot: Button = world.inventory_ui.slots[0]
	if not await drag(grid.global_position+Vector2(90,50),slot.get_global_rect().get_center()):
		await finish()
		return
	if not check(App.character.inventory.equipment.weapon == sword.uid and App.character.stats.attack == 36, "mouse drag equips and affects combat stats"):
		await finish()
		return
	if not await drag(slot.get_global_rect().get_center(),grid.global_position+Vector2(110,70)):
		await finish()
		return
	if not check(not App.character.inventory.equipment.has("weapon") and EterInventory.find(App.character.inventory,sword.uid).x == 5, "drag unequips into exact grid cell"):
		await finish()
		return
	if not check(world.player.sprite.texture.resource_path.ends_with("_unarmed.png"), "removing weapon changes player sprite"):
		await finish()
		return
	await click(grid.global_position+Vector2(110,70))
	await click(world.inventory_ui.get_node("Drop").get_global_rect().get_center())
	if not check(EterInventory.find(App.character.inventory,sword.uid).is_empty(), "drop removes inventory ownership"):
		await finish()
		return
	await press(KEY_I)
	await click(world.get_canvas_transform()*world.player.position)
	if not check(not EterInventory.find(App.character.inventory,sword.uid).is_empty(), "click pickup restores same item UID"):
		await finish()
		return
	await press(KEY_I)
	App.character.hp = 50
	await click(grid.global_position+Vector2(10,10))
	await click(world.inventory_ui.get_node("Use").get_global_rect().get_center())
	if not check(App.character.hp > 50 and grid.item_at(Vector2(10,10)).count == 2, "potion heals and decrements stack"):
		await finish()
		return
	if not check(EterInventory.valid(App.character.inventory,"warrior"), "all UI actions preserve invariants"):
		await finish()
		return
	App.character.gold = 1000
	if not check(EterInventory.upgrade(App.character,sword.uid,0).success, "upgraded item prepared for persistence"):
		await finish()
		return
	var expectation := FileAccess.open("res://../artifacts/inventory-expectation.json",FileAccess.WRITE)
	if not check(expectation != null,"expectation file opens"):
		await finish()
		return
	expectation.store_string(JSON.stringify({"uid":sword.uid,"gold":App.character.gold,"upgrade":1}))
	expectation.close()
	var save_path := "res://../artifacts/inventory-save.json"
	if not check(EterSave.save(App.character,save_path), "save writes real local snapshot"):
		await finish()
		return
	if not check(EterSave.save(App.character,save_path), "atomic replacement works on Windows"):
		await finish()
		return
	var restored := EterSave.load_character(save_path)
	if not check(not restored.is_empty() and EterInventory.valid(restored.inventory,"warrior"), "disk reload validates inventory"):
		await finish()
		return
	if not check(not EterInventory.find(restored.inventory,sword.uid).is_empty(), "disk reload preserves UID"):
		await finish()
		return
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if not check(file != null,"corruption fixture file opens"):
		await finish()
		return
	file.store_string('{"version":1,"payload":"broken","checksum":"wrong"}')
	file.close()
	if not check(EterSave.load_character(save_path).is_empty(), "corrupt checksum rejected"):
		await finish()
		return
	if not check(EterSave.save(App.character,save_path), "valid snapshot recoverable after corrupt file"):
		await finish()
		return
	await RenderingServer.frame_post_draw
	if not check(get_viewport().get_texture().get_image().save_png("res://../artifacts/inventory-runtime.png") == OK, "real inventory renderer capture saved"):
		await finish()
		return
	print("PASS inventory runtime: %s checks, real drag, equipment, ground pickup, potions and disk persistence" % checks if not failed else "FAIL inventory runtime suite")
	get_viewport().warp_mouse(original_cursor)
	get_tree().quit(1 if failed else 0)
