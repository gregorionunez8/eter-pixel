extends Node

var checks := 0
var failed := false
var main: Node
var role := 0
var suffix := ""
var graphics := false
var unsafe_frame := false

func _physics_process(_delta: float) -> void:
	if is_instance_valid(main) and is_instance_valid(main.world) and App.online:
		if not main.world.is_safe(main.world.player.position,7): unsafe_frame = true

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		printerr("FAIL online world: " + message)

func wait_until(predicate: Callable, label: String, timeout_ms: int = 12000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var passed: bool = predicate.call()
	check(passed,label)
	return passed

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_tree().root.push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	get_tree().root.push_input(event,true)
	await get_tree().process_frame

func arrived(world: Node2D, first: Vector2, second: Vector2) -> bool:
	if world.online_world.remotes.size() != 1: return false
	var own := first if role == 0 else second
	var other := second if role == 0 else first
	return world.player.position.distance_to(own)<2 and world.online_world.remotes.values()[0].position.distance_to(other)<2

func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = int(args[1])
	suffix = args[2]
	graphics = args.size()>3 and args[3] == "graphics"
	main = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await click(main.menu.get_node("Online").get_global_rect().get_center())
	check(is_instance_valid(main.creation),"mouse opens online lobby")
	var lobby: Control = main.creation
	lobby.address.text = args[0]
	lobby.username.text = "godotw_%d_%s" % [role,suffix]
	lobby.password.text = "fixture-password"
	await lobby.authenticate(false)
	check(lobby.characters.size() == 1,"login lists only account character")
	check(lobby.password.text.is_empty(),"password removed from widget")
	lobby.name_input.text = "Ze%d%s" % [role,suffix]
	lobby.class_select.select(2)
	await lobby.create_character()
	check(lobby.characters.size() == 2,"online class creation persisted")
	lobby.character_list.select(0)
	await lobby.select_character()
	await get_tree().process_frame
	check(is_instance_valid(main.world) and App.online,"enter renders authoritative world")
	var world: Node2D = main.world
	check(world.player.replicated and world.ground_items.is_empty(),"online movement passive, no local starter drop")
	for target in world.targets:
		if target is EterMonster: check(not target.is_physics_processing(),"online monster AI disabled")
	await wait_until(func(): return world.online_world.remotes.size() == 1,"remote avatar appears")
	var destination := Vector2(1008,592) if role == 0 else Vector2(912,592)
	world.player.camera.force_update_scroll()
	await click(world.get_global_transform_with_canvas()*destination)
	await wait_until(func(): return arrived(world,Vector2(1008,592),Vector2(912,592)),"mouse moves both visible players")
	check(world.is_safe(world.player.position,7),"online interpolation remains outside solids")
	check(not world.online_world.remotes.values()[0].camera.enabled,"remote camera does not replace own")
	for target in world.targets:
		check(target.bar.size.y <= 5,"enemy HP bar retains pixel height")
	if graphics:
		await RenderingServer.frame_post_draw
		check(get_tree().root.get_texture().get_image().save_png("res://../artifacts/online-world-%d.png" % role)==OK,"two avatar viewport captured")
	if role == 0:
		world.open_shop(world.npcs[0])
		check(world.shop_ui.visible,"NPC window opens in range")
		var original_gold: int = App.character.gold
		check(world.transact("buy","robe"),"buy sends intent")
		check(App.character.gold == original_gold,"client does not deduct optimistic gold")
		await wait_until(func(): return App.character.gold == original_gold-60,"SQL purchase updates self/UI")
		var robe_uid := ""
		for item in App.character.inventory.items:
			if item.definition == "robe": robe_uid = item.uid
		check(not robe_uid.is_empty(),"server item UID appears")
		world.shop_ui.hide()
		world.inventory_ui.show()
		world.inventory_ui.select_item(robe_uid)
		await click(world.inventory_ui.action.get_global_rect().get_center())
		await wait_until(func(): return App.character.inventory.equipment.get("armor","")==robe_uid,"inventory button equips on server")
		var old_inventory: Dictionary = App.character.inventory.duplicate(true)
		world.inventory_ui.grid._drop_data(Vector2(65,65),{"uid":robe_uid})
		check(App.character.inventory == old_inventory,"drag sends intent without local mutation")
		await wait_until(func(): return not App.character.inventory.equipment.has("armor"),"drag unequips atomically")
		check(int(EterInventory.find(App.character.inventory,robe_uid).x)==3,"drag position is server confirmed")
		world.drop_item(robe_uid)
		await wait_until(func(): return not world.ground_items.is_empty(),"drop reconciled from snapshot")
		check(EterInventory.find(App.character.inventory,robe_uid).is_empty(),"drop removed from private inventory")
		var ground: EterGroundItem = world.ground_items[0]
		world.pickup_item(ground)
		await wait_until(func(): return world.ground_items.is_empty() and not EterInventory.find(App.character.inventory,robe_uid).is_empty(),"pickup confirmed once with same UID")
		world.inventory_ui.hide()
	else:
		await get_tree().create_timer(4).timeout
	world.set_destination(Vector2(784,848) if role == 0 else Vector2(752,848))
	await wait_until(func(): return arrived(world,Vector2(784,848),Vector2(752,848)),"both clients reach combat area",16000)
	var target: EterTrainingTarget = world.targets[1]
	var initial_hp: int = target.state.hp
	world.player.camera.force_update_scroll()
	await click(world.get_global_transform_with_canvas()*(target.position+Vector2(0,-16)))
	await click(world.skill_buttons[0].get_global_rect().get_center())
	var skill_id: String = EterCombatRules.definitions().classes[App.class_id].skills[0]
	await wait_until(func(): return world.combat.cooldowns.get(skill_id,0)>0,"server cooldown reaches skill UI")
	await wait_until(func(): return target.state.hp < initial_hp,"shared real combat changes target HP")
	check(App.character.experience == 0,"effigy has no XP reward")
	var sequence: int = world.online_world.event_sequence
	world.online_world.apply_snapshot(App.network.latest_world)
	check(world.online_world.event_sequence == sequence,"combat events deduplicated")
	App.network.close()
	await wait_until(func(): return not App.network.was_open,"disconnect detected")
	await get_tree().create_timer(0.5).timeout
	var reply: Dictionary = await App.reconnect()
	check(reply.get("ok",false),"world reconnect authenticated")
	if reply.get("ok",false): world.online_world.entered(reply.data)
	await wait_until(func(): return world.combat.cooldowns.get(skill_id,0)>0,"cooldown survives visual reconnect")
	check(world.player.position.distance_to(Vector2(784,848) if role==0 else Vector2(752,848))<2,"position retained after reconnect")
	var spider: EterTrainingTarget = world.targets[3]
	if role == 0:
		world.handle_primary(spider.position+Vector2(0,-16))
	await wait_until(func(): return spider.dead,"real spider death replicated to both clients",20000)
	if role == 0:
		await wait_until(func(): return App.character.experience == 24,"actual monster kill awards server XP once")
		var previous_gold: int = App.character.gold
		var gold: EterGroundItem
		for ground in world.ground_items:
			if ground.gold > 0: gold = ground; break
		check(is_instance_valid(gold),"monster minted shared gold drop")
		if is_instance_valid(gold):
			world.handle_primary(gold.position)
			await wait_until(func(): return App.character.gold > previous_gold,"click picks real monster gold authoritatively")
		var material: EterGroundItem
		for ground in world.ground_items:
			if not ground.item.is_empty() and ground.item.definition == "ore": material = ground; break
		check(is_instance_valid(material),"real monster item loot appears")
		if is_instance_valid(material):
			world.handle_primary(material.position)
			await wait_until(func():
				for item in App.character.inventory.items:
					if item.definition == "ore": return true
				return false,"click picks real monster item into inventory")
	else:
		check(not world.ground_items.is_empty(),"second player observes monster loot")
	check(not unsafe_frame,"all online player frames remain outside obstacles")
	App.end_online()
	main.queue_free()
	await get_tree().create_timer(0.3).timeout
	if not failed: print("PASS online world: role%d %d checks%s" % [role,checks," with renderer" if graphics else " headless"])
	get_tree().quit(1 if failed else 0)
