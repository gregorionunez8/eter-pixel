extends "res://tests/input_runtime.gd"

var main: Node

func finish() -> void:
	if is_instance_valid(main): main.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.enter_world("Mercado","warrior")
	await get_tree().create_timer(0.3).timeout
	var world: Node2D = main.world
	App.character.gold = 1000
	var npc: Node2D = world.npcs[0]
	await click(world.get_global_transform_with_canvas()*(npc.position+Vector2(0,-16)))
	for tick in range(180):
		await get_tree().physics_frame
	if not check(world.shop_ui.visible,"NPC click opens shop"):
		await finish()
		return
	if not check(world.player.position.distance_to(npc.position) <= float(EterEconomy.rules().npc_range) and world.is_safe(world.player.position),"click walks to NPC around obstacles"):
		await finish()
		return
	var ui: Control = world.shop_ui
	await click(ui.global_position+Vector2(45,40))
	await click(ui.get_node("buy").global_position+Vector2(30,12))
	if not check(App.character.gold == 992 and App.character.inventory.items[1].count == 4,"real buy button stacks potion"):
		await finish()
		return
	await click(ui.global_position+Vector2(270,60))
	await click(ui.get_node("sell").global_position+Vector2(30,12))
	if not check(App.character.gold == 1004 and App.character.inventory.items.size() == 1,"real sell button removes stack"):
		await finish()
		return
	var before := App.character.duplicate(true)
	if not check(not world.transact("repair",App.character.inventory.equipment.weapon) and App.character == before,"repair unavailable at provision NPC"):
		await finish()
		return
	world.player.position = world.npcs[1].position+Vector2(-32,32)
	world.player.path.clear()
	await get_tree().create_timer(0.1).timeout
	await click(world.get_global_transform_with_canvas()*(world.npcs[1].position+Vector2(0,-16)))
	if not check(ui.visible and ui.shop_id == "smith","smith opens by click"):
		await finish()
		return
	var weapon := EterInventory.find(App.character.inventory,App.character.inventory.equipment.weapon)
	weapon.durability = 90
	ui.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await click(ui.global_position+Vector2(270,40))
	await click(ui.get_node("repair").get_global_rect().get_center())
	if not check(weapon.durability == 100 and App.character.gold == 994,"repair button restores durability"):
		await finish()
		return
	await click(ui.global_position+Vector2(270,40))
	await click(ui.get_node("upgrade").global_position+Vector2(30,12))
	if not check(weapon.upgrade == 1 and App.character.gold == 974 and App.character.stats.attack == 29,"upgrade button charges and recomputes stats"):
		await finish()
		return
	await click(ui.global_position+Vector2(270,40))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../artifacts/economy-runtime.png")
	world.player.position = world.spawn_position
	world.player.path.clear()
	before = App.character.duplicate(true)
	if not check(not world.transact("buy","potion") and App.character == before,"distant shop transaction rejected"):
		await finish()
		return
	await get_tree().create_timer(0.1).timeout
	if not check(not ui.visible,"distance closes shop"):
		await finish()
		return
	world.spawn_gold(20,world.player.position)
	var gold: EterGroundItem = world.ground_items.back()
	if not check(world.pickup_item(gold),"gold pickup succeeds"):
		await finish()
		return
	if not check(not world.pickup_item(gold),"second pickup before free rejected"):
		await finish()
		return
	world.spawn_gold(20,world.player.position+Vector2(32,0))
	gold = world.ground_items.back()
	await click(world.get_global_transform_with_canvas()*gold.position)
	if not check(App.character.gold == 1014,"gold picked by mouse"):
		await finish()
		return
	if not check(not is_instance_valid(gold) and App.character.gold == 1014,"gold entity consumed once"):
		await finish()
		return
	var monster: EterMonster = world.targets[3]
	var ground_count: int = world.ground_items.size()
	world.combat.damage_target(monster,1000,"physical","slash")
	if not monster.dead: world.combat.damage_target(monster,1000,"physical","slash")
	if not check(monster.dead,"real monster kill"):
		await finish()
		return
	var rewarded: int = world.ground_items.size()
	if not check(rewarded >= ground_count,"loot integration retains ground objects"):
		await finish()
		return
	world.combat.damage_target(monster,1000,"physical","slash")
	if not check(world.ground_items.size() == rewarded,"dead monster cannot issue loot twice"):
		await finish()
		return
	main.queue_free()
	await get_tree().process_frame
	print("PASS economy runtime: %s checks" % checks if not failed else "FAIL economy runtime")
	get_tree().quit(1 if failed else 0)
