extends "res://tests/test_online_world.gd"

func total_experience(character: Dictionary) -> int:
	var total := int(character.experience)
	for level in range(1,int(character.level)): total += EterProgression.required_experience(level)
	return total

func open_npc(npc_id: String) -> bool:
	var world: Node2D = main.world
	world.combat.select_target(null)
	for npc in world.npcs:
		if npc.shop_id != npc_id: continue
		world.handle_primary(npc.position+Vector2(0,-16))
		return await wait_until(func(): return world.shop_ui.visible and world.shop_ui.shop_id == npc_id,"online NPC opens: "+npc_id,20000)
	return false

func encargos(id: String) -> bool:
	if not await open_npc(EterQuests.definitions()[id].npc): return false
	var world: Node2D = main.world
	await get_tree().process_frame
	await click(world.shop_ui.get_node("quests").get_global_rect().get_center())
	if not check(world.quest_ui.visible and not world.shop_ui.visible and world.quest_ui.ids.has(id),"online Encargos replaces shop"): return false
	world.quest_ui.listing.select(world.quest_ui.ids.find(id))
	world.quest_ui.describe()
	return true

func travel_to(id: String) -> bool:
	var world: Node2D = main.world
	world.combat.select_target(null)
	for portal in world.portals:
		if portal.definition.id != id: continue
		var destination: String = portal.definition.target
		world.handle_primary(portal.position)
		return await wait_until(func(): return main.world.map_id == destination,"online portal: "+id,35000)
	return false

func defeat(species: String, id: String, count: int) -> bool:
	var world: Node2D = main.world
	for target in world.targets:
		if not target is EterMonster or target.species_id != species or target.dead: continue
		print("QUEST online combat: expected=%d player=%s target=%s kills=%s" % [count,world.player.position,target.position,App.character.quests[id].kills])
		world.combat.select_target(target)
		var passed := await wait_until(func(): return int(App.character.quests[id].kills) == count,"real server kill updates quest: "+id,30000)
		if not passed: print("QUEST combat failure: player=%s target=%s dead=%s selected=%s progress=%s message=%s" % [world.player.position,target.position,target.dead,world.combat.selected,App.character.quests[id],world.message_label.text])
		return passed
	return false

func reconnect_journal() -> bool:
	var journal: Dictionary = App.character.quests.duplicate(true)
	App.network.close()
	if not await wait_until(func(): return not App.network.was_open,"quest disconnect acknowledged"): return false
	await get_tree().create_timer(0.5).timeout
	var reply: Dictionary = await App.reconnect()
	if not check(reply.get("ok",false),"quest reconnect authenticated"): return false
	main.world.online_world.entered(reply.data)
	return check(App.character.quests == journal,"accepted/killed/claimed progress survives SQL reconnect")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = int(args[1]); suffix = args[2]; graphics = args[3] == "quests-graphics"
	main = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().create_timer(0.2).timeout
	main.start_online()
	var lobby: Control = main.creation
	lobby.address.text = args[0]
	lobby.username.text = "godotw_%d_%s" % [role,suffix]
	lobby.password.text = "fixture-password"
	await lobby.authenticate(false)
	if not check(lobby.characters.size() == 1,"quest login lists fixture character"):
		await finish()
		return
	lobby.character_list.select(0)
	await lobby.select_character()
	await get_tree().process_frame
	if not check(is_instance_valid(main.world) and App.online,"quest enters actual online world"):
		await finish()
		return
	var world: Node2D = main.world
	if not check(world.quest_ui.character == App.character,"online quest owns current shared character"):
		await finish()
		return
	# Exercise the existing shop intents through the UI consumer; no client rewards.
	if not check(await open_npc("shop"),"Iria opens online"):
		await finish()
		return
	var gold: int = App.character.gold
	if not check(world.transact("buy","potion"),"online purchase submitted"):
		await finish()
		return
	if not await wait_until(func(): return App.character.gold == gold-8,"online purchase persisted"):
		await finish()
		return
	var potion := ""
	for item in App.character.inventory.items:
		if item.definition == "potion": potion = item.uid
	if not check(not potion.is_empty(),"online potion exists before selling"):
		await finish()
		return
	if not check(world.transact("sell",potion),"online sale submitted"):
		await finish()
		return
	if not await wait_until(func(): return App.character.gold == gold+4,"online sale persisted"):
		await finish()
		return
	if not check(await open_npc("smith"),"Daro opens online"):
		await finish()
		return
	var weapon: Dictionary = EterInventory.find(App.character.inventory,App.character.inventory.equipment.weapon)
	if not check(not weapon.is_empty(),"online starter weapon exists before upgrade"):
		await finish()
		return
	var uid: String = weapon.uid
	gold = App.character.gold
	if not check(world.transact("upgrade",uid),"online upgrade submitted"):
		await finish()
		return
	if not await wait_until(func(): return EterInventory.find(App.character.inventory,uid).get("upgrade",-1) == 1 and App.character.gold == gold-20,"online upgrade persisted"):
		await finish()
		return
	world.shop_ui.hide()
	for id in EterQuests.definitions():
		var definition: Dictionary = EterQuests.definitions()[id]
		if not check(await encargos(id),"existing online quest window: "+id):
			await finish()
			return
		if not check(not main.world.quest_ui.action.disabled,"existing online quest available: "+id):
			await finish()
			return
		await click(main.world.quest_ui.action.get_global_rect().get_center())
		if not await wait_until(func(): return App.character.quests.has(id) and not main.world.quest_ui.busy,"UI accept confirmed by server: "+id):
			await finish()
			return
		if not check(await reconnect_journal(),"accepted quest persisted online"):
			await finish()
			return
		if id != "silk_on_the_road":
			if not check(await travel_to("village_forest"),"online travel to forest"):
				await finish()
				return
		if id == "oath_beneath_the_stone":
			if not check(await travel_to("forest_crypt"),"online travel to crypt"):
				await finish()
				return
		for count in range(int(definition.objective.count)):
			if not check(await defeat(definition.objective.species,id,count+1),"actual online quest objective"):
				await finish()
				return
			if count == 0:
				if not check(await reconnect_journal(),"intermediate quest kill persisted online"):
					await finish()
					return
			if count+1 < int(definition.objective.count): await get_tree().create_timer(6.2).timeout
		if main.world.map_id == "crypt":
			if not check(await travel_to("crypt_forest"),"online guardian return"):
				await finish()
				return
		if main.world.map_id == "forest":
			if not check(await travel_to("forest_village"),"online return to NPC"):
				await finish()
				return
		if not check(await encargos(id),"online return to Encargos"):
			await finish()
			return
		if not check(main.world.quest_ui.detail.text.contains("%s/%s" % [int(definition.objective.count),int(definition.objective.count)]),"online UI displays complete progress"):
			await finish()
			return
		gold = App.character.gold
		var experience := total_experience(App.character)
		await click(main.world.quest_ui.action.get_global_rect().get_center())
		if not await wait_until(func(): return App.character.quests[id].claimed and not main.world.quest_ui.busy,"UI reward confirmed: "+id):
			await finish()
			return
		if not check(App.character.gold == gold+int(definition.reward.gold) and total_experience(App.character) == experience+int(definition.reward.experience),"online gold/XP reward applies once"):
			await finish()
			return
		for reward in definition.reward.items:
			var amount := 0
			for item in App.character.inventory.items:
				if item.definition == reward.definition and item.rarity == reward.rarity: amount += int(item.count)
			if not check(amount >= int(reward.count),"online item reward and rarity: "+reward.definition):
				await finish()
				return
		var before: Dictionary = App.character.duplicate(true)
		if not check(not await main.world.request_quest("quest_claim",id),"duplicate online claim rejected"):
			await finish()
			return
		if not check(App.character.gold == before.gold and App.character.experience == before.experience and App.character.inventory == before.inventory,"rejected online claim cannot duplicate reward"):
			await finish()
			return
		if not check(await reconnect_journal(),"claimed quest persisted online"):
			await finish()
			return
		if graphics:
			if not check(await encargos(id),"render delivered online quest"):
				await finish()
				return
			await RenderingServer.frame_post_draw
			if not check(get_tree().root.get_texture().get_image().save_png("res://../artifacts/online-quest-%s.png" % id)==OK,"online quest capture"):
				await finish()
				return
		main.world.quest_ui.hide()
	# Actual combat caused weapon wear; repair at the existing smith.
	if not check(await open_npc("smith"),"return to online smith for repair"):
		await finish()
		return
	weapon = EterInventory.find(App.character.inventory,uid)
	if not check(not weapon.is_empty() and int(weapon.durability) < 100,"real server combat caused durability wear"):
		await finish()
		return
	gold = App.character.gold
	var cost := 100-int(weapon.durability)
	if not check(main.world.transact("repair",uid),"online repair submitted"):
		await finish()
		return
	if not await wait_until(func(): return EterInventory.find(App.character.inventory,uid).get("durability",-1) == 100 and App.character.gold == gold-cost,"online repair persisted"):
		await finish()
		return
	print("PASS online world quests: %d checks, existing shops, three real quests and SQL reconnect" % checks)
	await finish()
