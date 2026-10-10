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

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failed = true
		printerr("FAIL online world: " + message)
	return condition

func finish() -> void:
	App.end_online()
	if is_instance_valid(main): main.queue_free()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(1 if failed else 0)

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
	if "--fail-role0" in args and role == 0:
		check(false,"controlled important precondition")
		await finish()
		return
	# Let the root stretch/layout settle before deriving mouse coordinates.
	await get_tree().create_timer(0.2).timeout
	await click(main.menu.get_node("Online").get_global_rect().get_center())
	if not check(is_instance_valid(main.creation),"mouse opens online lobby"):
		await finish()
		return
	var lobby: Control = main.creation
	lobby.address.text = args[0]
	lobby.username.text = "godotw_%d_%s" % [role,suffix]
	lobby.password.text = "fixture-password"
	await lobby.authenticate(false)
	if not check(lobby.characters.size() == 1,"login lists only account character"):
		await finish()
		return
	if not check(lobby.password.text.is_empty(),"password removed from widget"):
		await finish()
		return
	lobby.name_input.text = "Ze%d%s" % [role,suffix]
	lobby.class_select.select(2)
	await lobby.create_character()
	if not check(lobby.characters.size() == 2,"online class creation persisted"):
		await finish()
		return
	lobby.character_list.select(0)
	await lobby.select_character()
	await get_tree().process_frame
	if not check(is_instance_valid(main.world) and App.online,"enter renders authoritative world"):
		await finish()
		return
	var world: Node2D = main.world
	if not check(world.player.replicated and world.ground_items.is_empty(),"online movement passive, no local starter drop"):
		await finish()
		return
	for target in world.targets:
		if target is EterMonster:
			if not check(not target.is_physics_processing(),"online monster AI disabled"):
				await finish()
				return
	if not await wait_until(func(): return world.online_world.remotes.size() == 1,"remote avatar appears"):
		await finish()
		return
	var destination := Vector2(1008,592) if role == 0 else Vector2(912,592)
	world.player.camera.force_update_scroll()
	await click(world.get_global_transform_with_canvas()*destination)
	if not await wait_until(func(): return arrived(world,Vector2(1008,592),Vector2(912,592)),"mouse moves both visible players"):
		await finish()
		return
	if not check(world.is_safe(world.player.position,7),"online interpolation remains outside solids"):
		await finish()
		return
	if not check(not world.online_world.remotes.values()[0].camera.enabled,"remote camera does not replace own"):
		await finish()
		return
	for target in world.targets:
		if not check(target.bar.size.y <= 5,"enemy HP bar retains pixel height"):
			await finish()
			return
	if graphics:
		await RenderingServer.frame_post_draw
		if not check(get_tree().root.get_texture().get_image().save_png("res://../artifacts/online-world-%d.png" % role)==OK,"two avatar viewport captured"):
			await finish()
			return
	if role == 0:
		world.open_shop(world.npcs[0])
		if not check(world.shop_ui.visible,"NPC window opens in range"):
			await finish()
			return
		var original_gold: int = App.character.gold
		if not check(world.transact("buy","robe"),"buy sends intent"):
			await finish()
			return
		if not check(App.character.gold == original_gold,"client does not deduct optimistic gold"):
			await finish()
			return
		if not await wait_until(func(): return App.character.gold == original_gold-60,"SQL purchase updates self/UI"):
			await finish()
			return
		var robe_uid := ""
		for item in App.character.inventory.items:
			if item.definition == "robe": robe_uid = item.uid
		if not check(not robe_uid.is_empty(),"server item UID appears"):
			await finish()
			return
		world.shop_ui.hide()
		world.inventory_ui.show()
		world.inventory_ui.select_item(robe_uid)
		await click(world.inventory_ui.action.get_global_rect().get_center())
		if not await wait_until(func(): return App.character.inventory.equipment.get("armor","")==robe_uid,"inventory button equips on server"):
			await finish()
			return
		var old_inventory: Dictionary = App.character.inventory.duplicate(true)
		world.inventory_ui.grid._drop_data(Vector2(65,65),{"uid":robe_uid})
		if not check(App.character.inventory == old_inventory,"drag sends intent without local mutation"):
			await finish()
			return
		if not await wait_until(func(): return not App.character.inventory.equipment.has("armor"),"drag unequips atomically"):
			await finish()
			return
		if not check(int(EterInventory.find(App.character.inventory,robe_uid).x)==3,"drag position is server confirmed"):
			await finish()
			return
		world.drop_item(robe_uid)
		if not await wait_until(func(): return not world.ground_items.is_empty(),"drop reconciled from snapshot"):
			await finish()
			return
		if not check(EterInventory.find(App.character.inventory,robe_uid).is_empty(),"drop removed from private inventory"):
			await finish()
			return
		var ground: EterGroundItem = world.ground_items[0]
		world.pickup_item(ground)
		if not await wait_until(func(): return world.ground_items.is_empty() and not EterInventory.find(App.character.inventory,robe_uid).is_empty(),"pickup confirmed once with same UID"):
			await finish()
			return
		world.inventory_ui.hide()
	else:
		await get_tree().create_timer(4).timeout
	world.set_destination(Vector2(784,848) if role == 0 else Vector2(752,848))
	if not await wait_until(func(): return arrived(world,Vector2(784,848),Vector2(752,848)),"both clients reach combat area",16000):
		await finish()
		return
	var target: EterTrainingTarget = world.targets[1]
	var initial_hp: int = target.state.hp
	world.player.camera.force_update_scroll()
	await click(world.get_global_transform_with_canvas()*(target.position+Vector2(0,-16)))
	await click(world.skill_buttons[0].get_global_rect().get_center())
	var skill_id: String = EterCombatRules.definitions().classes[App.class_id].skills[0]
	if not await wait_until(func(): return world.combat.cooldowns.get(skill_id,0)>0,"server cooldown reaches skill UI"):
		await finish()
		return
	if not await wait_until(func(): return target.state.hp < initial_hp,"shared real combat changes target HP"):
		await finish()
		return
	if not check(App.character.experience == 0,"effigy has no XP reward"):
		await finish()
		return
	var sequence: int = world.online_world.event_sequence
	world.online_world.apply_snapshot(App.network.latest_world)
	if not check(world.online_world.event_sequence == sequence,"combat events deduplicated"):
		await finish()
		return
	App.network.close()
	if not await wait_until(func(): return not App.network.was_open,"disconnect detected"):
		await finish()
		return
	await get_tree().create_timer(0.5).timeout
	var reply: Dictionary = await App.reconnect()
	if not check(reply.get("ok",false),"world reconnect authenticated"):
		await finish()
		return
	if reply.get("ok",false): world.online_world.entered(reply.data)
	if not await wait_until(func(): return world.combat.cooldowns.get(skill_id,0)>0,"cooldown survives visual reconnect"):
		await finish()
		return
	if not check(world.player.position.distance_to(Vector2(784,848) if role==0 else Vector2(752,848))<2,"position retained after reconnect"):
		await finish()
		return
	if not await wait_until(func(): return world.social_ui.roster_ids.size()==1,"connected roster includes second player"):
		await finish()
		return
	world.chat_ui.open()
	world.chat_ui.send("[b]literal_%d[/b]" % role)
	if not await wait_until(func(): return "literal_%d" % (1-role) in world.chat_ui.history.get_parsed_text(),"real global chat delivered to other Godot"):
		await finish()
		return
	if not check("[b]literal_" in world.chat_ui.history.get_parsed_text(),"chat markup remains literal"):
		await finish()
		return
	await get_tree().create_timer(0.55).timeout
	world.chat_ui.channel.select(1)
	world.chat_ui.send("cerca_%d" % role)
	if not await wait_until(func(): return "cerca_%d" % (1-role) in world.chat_ui.history.get_parsed_text(),"local chat delivered to nearby Godot"):
		await finish()
		return
	if not check("Local ·" in world.chat_ui.history.get_parsed_text(),"local channel displayed"):
		await finish()
		return
	world.chat_ui.hide(); world.chat_ui.input.release_focus()
	world.toggle_social()
	world.social_ui.roster.select(0)
	if role==0:
		world.social_ui.invite("party_invite")
	else:
		if not await wait_until(func(): return world.social_ui.state.get("invitation") is Dictionary,"party invitation appears"):
			await finish()
			return
		await click(world.social_ui.accept_party.get_global_rect().get_center())
	if not await wait_until(func(): return world.social_ui.state.get("party") is Dictionary and world.social_ui.state.party.members.size()==2,"both consent to party"):
		await finish()
		return
	if role==0:
		world.social_ui.roster.select(0)
		world.social_ui.invite("trade_invite")
	else:
		if not await wait_until(func(): return world.social_ui.state.get("trade") is Dictionary,"trade invitation appears"):
			await finish()
			return
		await click(world.social_ui.confirm_button.get_global_rect().get_center())
	if not await wait_until(func(): return world.social_ui.state.get("trade") is Dictionary and world.social_ui.state.trade.phase=="open","both see open trade"):
		await finish()
		return
	var social: Control = world.social_ui
	if role==0:
		for index in range(social.item_ids.size()):
			if EterInventory.find(App.character.inventory,social.item_ids[index]).definition=="robe": social.mine.select(index)
		social.gold.value=10
		await click(social.offer_button.get_global_rect().get_center())
	else:
		if not await wait_until(func():
			if not social.state.get("trade") is Dictionary: return false
			for entry in social.state.trade.offers:
				if entry.id!=App.online_character_id and entry.items.size()==1: return true
			return false,"other offer is visible before submitting"):
			await finish()
			return
		for index in range(social.item_ids.size()):
			if EterInventory.find(App.character.inventory,social.item_ids[index]).definition=="potion": social.mine.select(index)
		social.gold.value=5
		await click(social.offer_button.get_global_rect().get_center())
	if not await wait_until(func():
		if not social.state.get("trade") is Dictionary: return false
		for entry in social.state.trade.offers:
			if entry.items.size()!=1: return false
		return true,"both offers reviewed before confirmation"):
		await finish()
		return
	if not check(social.theirs.get_item_text(0).contains("×3" if role==0 else "×1"),"full stack quantity visible before confirming"):
		await finish()
		return
	if graphics:
		await RenderingServer.frame_post_draw
		if not check(get_tree().root.get_texture().get_image().save_png("res://../artifacts/online-trade-%d.png" % role)==OK,"trade UI captured"):
			await finish()
			return
	if role==0:
		await click(social.confirm_button.get_global_rect().get_center())
	else:
		if not await wait_until(func(): return social.state.get("trade") is Dictionary and social.state.trade.accepted.size()==1,"first confirmation visible"):
			await finish()
			return
		await click(social.confirm_button.get_global_rect().get_center())
	if not await wait_until(func(): return not social.state.get("trade") is Dictionary,"SQL exchange completes for both clients"):
		await finish()
		return
	if role==0:
		var potion_count:=0
		for item in App.character.inventory.items:
			if item.definition=="potion": potion_count+=int(item.count)
		if not check(potion_count==6 and App.character.gold==935,"trade conserves stacked potions and gold"):
			await finish()
			return
	else:
		var received_robe:=false
		for item in App.character.inventory.items:
			if item.definition=="robe": received_robe=true
		if not check(received_robe and App.character.gold==1005,"trade receives server UID and gold"):
			await finish()
			return
	social.hide()
	var spider: EterTrainingTarget = world.targets[3]
	if role == 0:
		world.handle_primary(spider.position+Vector2(0,-16))
	if not await wait_until(func(): return spider.dead,"real spider death replicated to both clients",20000):
		await finish()
		return
	if role == 0:
		if not await wait_until(func(): return App.character.experience == 24,"actual monster kill awards server XP once"):
			await finish()
			return
		var previous_gold: int = App.character.gold
		var gold: EterGroundItem
		for ground in world.ground_items:
			if ground.gold > 0: gold = ground; break
		if not check(is_instance_valid(gold),"monster minted shared gold drop"):
			await finish()
			return
		if is_instance_valid(gold):
			world.handle_primary(gold.position)
			if not await wait_until(func(): return App.character.gold > previous_gold,"click picks real monster gold authoritatively"):
				await finish()
				return
		var material: EterGroundItem
		for ground in world.ground_items:
			if not ground.item.is_empty() and ground.item.definition == "ore": material = ground; break
		if not check(is_instance_valid(material),"real monster item loot appears"):
			await finish()
			return
		if is_instance_valid(material):
			world.handle_primary(material.position)
			if not await wait_until(func():
				for item in App.character.inventory.items:
					if item.definition == "ore": return true
				return false,"click picks real monster item into inventory"):
				await finish()
				return
	else:
		if not check(not world.ground_items.is_empty(),"second player observes monster loot"):
			await finish()
			return
	if not check(not unsafe_frame,"all online player frames remain outside obstacles"):
		await finish()
		return
	world = main.world
	world.handle_primary(world.portals[0].position)
	if not await wait_until(func(): return main.world.map_id=="forest","mouse travels to forest authoritatively",15000):
		await finish()
		return
	if not await wait_until(func(): return main.world.online_world.remotes.size()==1,"both players meet in forest",15000):
		await finish()
		return
	world = main.world
	if not check(world.targets[0].get_meta("server_id")=="forest-monster-0","forest replaces old targets"):
		await finish()
		return
	if not check(world.targets.size() == 6,"forest excludes village training targets"):
		await finish()
		return
	if graphics:
		await RenderingServer.frame_post_draw
		if not check(get_tree().root.get_texture().get_image().save_png("res://../artifacts/online-forest-%d.png" % role)==OK,"forest rendered capture"):
			await finish()
			return
	world.handle_primary(world.portals[1].position)
	if not await wait_until(func(): return main.world.map_id=="crypt","mouse travels to crypt authoritatively",30000):
		await finish()
		return
	if not await wait_until(func(): return main.world.online_world.remotes.size()==1,"both players meet in crypt",15000):
		await finish()
		return
	world = main.world
	if not check(world.targets[0].get_meta("server_id")=="crypt-monster-0","crypt replaces old targets"):
		await finish()
		return
	if graphics:
		await RenderingServer.frame_post_draw
		if not check(get_tree().root.get_texture().get_image().save_png("res://../artifacts/online-crypt-%d.png" % role)==OK,"crypt rendered capture"):
			await finish()
			return
	App.network.close()
	if not await wait_until(func(): return not App.network.was_open,"crypt disconnect detected"):
		await finish()
		return
	await get_tree().create_timer(0.5).timeout
	reply = await App.reconnect()
	if not check(reply.get("ok",false) and reply.data.state.map_id=="crypt","SQL reconnect retains crypt"):
		await finish()
		return
	if reply.get("ok",false): world.online_world.entered(reply.data)
	if not check(main.world.map_id=="crypt" and world.is_safe(world.player.position,7),"reconnected crypt position safe"):
		await finish()
		return
	if not failed: print("PASS online world: role%d %d checks%s" % [role,checks," with renderer" if graphics else " headless"])
	await finish()
