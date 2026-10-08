extends Node

var checks := 0
var failed := false
var main: Node

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failed = true; push_error("FAIL maps: "+message)

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate();event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame

func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.enter_world("Viajera","elf")
	await get_tree().process_frame
	var maps: Dictionary = Catalog.read("maps").maps
	for id in maps:
		var data: Dictionary = maps[id]
		var nav := EterNavigation.new()
		var blocked: Array[Vector2i] = []
		for rect in data.obstacles:
			for y in range(int(rect.y),int(rect.y+rect.height)):
				for x in range(int(rect.x),int(rect.x+rect.width)): blocked.append(Vector2i(x,y))
		nav.setup(Vector2i(data.width,data.height),blocked)
		check(nav.walkable(nav.cell_at(Vector2(data.spawn.x,data.spawn.y))),id+" safe spawn")
		for portal in data.portals: check(not nav.find_path(Vector2(data.spawn.x,data.spawn.y),Vector2(portal.x,portal.y)).is_empty(),id+" reachable portal")
		for monster in data.monsters: check(not nav.find_path(Vector2(data.spawn.x,data.spawn.y),Vector2(monster.x,monster.y)).is_empty(),id+" reachable enemy")
		check(ResourceLoader.exists("res://assets/%s.png" % data.terrain),id+" local atlas")
	var inventory: Dictionary = App.character.inventory.duplicate(true)
	for portal_id in ["village_forest","forest_crypt","crypt_forest","forest_village"]:
		var world: Node2D = main.world
		var target: Node2D
		for portal in world.portals:
			if portal.definition.id==portal_id: target=portal
		check(is_instance_valid(target),portal_id+" node exists")
		if not is_instance_valid(target): break
		world.player.position=target.position+Vector2(0,32)
		world.player.path.clear()
		await get_tree().physics_frame
		world.player.camera.force_update_scroll()
		var destination: String=target.definition.target
		await click(world.get_global_transform_with_canvas()*target.position)
		check(main.world.map_id==destination,portal_id+" mouse transition")
		check(App.character.map_id==destination and main.world.is_safe(main.world.player.position,7),portal_id+" state and safe arrival")
		check(App.character.inventory==inventory,portal_id+" inventory conserved")
		await get_tree().process_frame
		for enemy in main.world.targets:
			check(enemy.bar.size.y <= 5, destination+" compact monster health bar")
		if "--capture-maps" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png("res://../artifacts/map-%s.png" % destination)==OK,destination+" rendered capture")
	check(EterSave.save(App.character,"res://../artifacts/map-character.json"),"local save of map/position")
	var saved := EterSave.load_character("res://../artifacts/map-character.json")
	check(saved.map_id==App.character.map_id and saved.position==App.character.position,"map/position reload")
	main.queue_free()
	await get_tree().process_frame
	if not failed: print("PASS maps: %s checks, local portals and geometry" % checks)
	get_tree().quit(1 if failed else 0)
