extends "res://tests/input_runtime.gd"

var main: Node
const SAVE_PATH := "res://../artifacts/quest-save.json"

func finish() -> void:
	if is_instance_valid(main): main.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func total_experience(character: Dictionary) -> int:
	var total := int(character.experience)
	for level in range(1,int(character.level)): total += EterProgression.required_experience(level)
	return total

func same_journal(saved: Dictionary, expected: Dictionary) -> bool:
	if saved.is_empty() or saved.get("quests",{}).size() != expected.size(): return false
	for id in expected:
		var progress: Dictionary = saved.quests.get(id,{})
		if progress.is_empty() or int(progress.kills) != int(expected[id].kills) or progress.claimed != expected[id].claimed: return false
	return true

func open_encargos(id: String) -> bool:
	var world: Node2D = main.world
	var definition: Dictionary = EterQuests.definitions()[id]
	for npc in world.npcs:
		if npc.shop_id == definition.npc:
			world.player.position = npc.position+Vector2(0,32)
			world.player.path.clear()
			world.combat.select_target(null)
			await get_tree().physics_frame
			world.open_shop(npc)
			await get_tree().create_timer(0.1).timeout
			if not check(world.shop_ui.visible,"quest NPC shop precondition"): return false
			await click(world.shop_ui.get_node("quests").get_global_rect().get_center())
			if not check(world.quest_ui.visible and world.quest_ui.ids.has(id),"quest button opens existing listing"): return false
			world.quest_ui.listing.select(world.quest_ui.ids.find(id))
			world.quest_ui.describe()
			return true
	return false

func portal(id: String) -> bool:
	var world: Node2D = main.world
	for target in world.portals:
		if target.definition.id == id:
			var destination: String = target.definition.target
			world.player.position = target.position
			world.player.path.clear()
			world.travel(target)
			await get_tree().process_frame
			return main.world.map_id == destination
	return false

func kill(species: String) -> bool:
	var world: Node2D = main.world
	var victim: EterMonster
	for target in world.targets:
		if target is EterMonster and target.species_id == species and not target.dead:
			victim = target
			break
	if not is_instance_valid(victim): return false
	world.player.position = victim.position+Vector2(-32,0)
	world.player.path.clear()
	world.combat.select_target(victim)
	var deadline := Time.get_ticks_msec()+12000
	while not victim.dead and Time.get_ticks_msec()<deadline:
		await get_tree().physics_frame
	return victim.dead

func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.enter_world("Encargos","warrior")
	# Trusted combat fixture accelerates actual autoattacks, never quest progress.
	for attribute in App.character.attributes: App.character.attributes[attribute] = 1000
	App.character.stats = EterCharacter.derive(App.character)
	App.character.hp = App.character.stats.max_hp
	App.character.mana = App.character.stats.max_mana
	main.world.combat.random.seed = 1909
	await get_tree().create_timer(0.2).timeout
	if not check(main.world.quest_ui.character == App.character and main.world.quest_ui.get_parent() == main.world.hud,"quest widget owns current character and HUD lifecycle"):
		await finish()
		return
	for id in EterQuests.definitions():
		var definition: Dictionary = EterQuests.definitions()[id]
		if not await open_encargos(id):
			await finish()
			return
		if not check(main.world.quest_ui.visible and not main.world.shop_ui.visible,"Encargos replaces shop: "+id):
			await finish()
			return
		if not check(not main.world.quest_ui.action.disabled,"existing quest available in chain: "+id):
			await finish()
			return
		await click(main.world.quest_ui.action.get_global_rect().get_center())
		if not check(App.character.quests.has(id) and App.character.quests[id].kills == 0,"UI accepts existing quest: "+id):
			await finish()
			return
		if not check(EterSave.save(App.character,SAVE_PATH) and same_journal(EterSave.load_character(SAVE_PATH),App.character.quests),"accepted progress persists: "+id):
			await finish()
			return
		await press(KEY_ESCAPE)
		if not check(not main.world.quest_ui.visible and not main.world.pause_menu.visible,"Escape closes quest before menu"):
			await finish()
			return
		if id != "silk_on_the_road":
			if not check(await portal("village_forest"),"travel to forest for quest"):
				await finish()
				return
		if id == "oath_beneath_the_stone":
			if not check(await portal("forest_crypt"),"travel to crypt for guardian quest"):
				await finish()
				return
		for count in range(int(definition.objective.count)):
			if not check(await kill(definition.objective.species),"actual autoattack defeats "+definition.objective.species):
				await finish()
				return
			if not check(App.character.quests[id].kills == count+1,"actual kill updates progress: "+id):
				await finish()
				return
			if not check(EterSave.save(App.character,SAVE_PATH) and same_journal(EterSave.load_character(SAVE_PATH),App.character.quests),"kill progress persists: "+id):
				await finish()
				return
			if count+1 < int(definition.objective.count): await get_tree().create_timer(6.2).timeout
		if main.world.map_id == "crypt":
			if not check(await portal("crypt_forest"),"guardian return to forest"):
				await finish()
				return
		if main.world.map_id == "forest":
			if not check(await portal("forest_village"),"return to quest NPC"):
				await finish()
				return
		if not await open_encargos(id):
			await finish()
			return
		if not check(main.world.quest_ui.detail.text.contains("%s/%s" % [int(definition.objective.count),int(definition.objective.count)]),"UI displays completed objective: "+id):
			await finish()
			return
		var gold: int = App.character.gold
		var experience := total_experience(App.character)
		var quantities: Dictionary = {}
		for reward in definition.reward.items:
			var quantity := 0
			for item in App.character.inventory.items:
				if item.definition == reward.definition and item.rarity == reward.rarity: quantity += int(item.count)
			quantities[reward.definition] = quantity
		await click(main.world.quest_ui.action.get_global_rect().get_center())
		if not check(App.character.quests[id].claimed and App.character.gold == gold+int(definition.reward.gold),"UI claims reward once: "+id):
			await finish()
			return
		if not check(total_experience(App.character) == experience+int(definition.reward.experience),"quest XP reward applied: "+id):
			await finish()
			return
		for reward in definition.reward.items:
			var quantity := 0
			for item in App.character.inventory.items:
				if item.definition == reward.definition and item.rarity == reward.rarity: quantity += int(item.count)
			if not check(quantity == quantities[reward.definition]+int(reward.count),"exact item reward and rarity: "+id):
				await finish()
				return
		var rewarded := App.character.duplicate(true)
		if not check(not await main.world.request_quest("quest_claim",id) and App.character == rewarded,"second claim rejected unchanged: "+id):
			await finish()
			return
		if not check(main.world.quest_ui.action.disabled,"claimed quest action disabled: "+id):
			await finish()
			return
		if not check(EterSave.save(App.character,SAVE_PATH),"quest reward saved: "+id):
			await finish()
			return
		var restored := EterSave.load_character(SAVE_PATH)
		if not check(same_journal(restored,App.character.quests) and int(restored.get("gold",-1)) == App.character.gold,"delivered quest persists: "+id):
			await finish()
			return
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if not check(get_viewport().get_texture().get_image().save_png("res://../artifacts/quest-%s.png" % id) == OK,"quest rendered capture"):
				await finish()
				return
		main.world.open_shop(main.world.active_npc)
		if not check(main.world.shop_ui.visible and not main.world.quest_ui.visible,"shop closes quest without null reference"):
			await finish()
			return
		main.world.shop_ui.hide()
	# Pickup at cap must leave the ground reward intact.
	App.character.gold = int(EterEconomy.rules().gold_cap)
	main.world.spawn_gold(1,main.world.player.position)
	var ground: EterGroundItem = main.world.ground_items.back()
	if not check(not main.world.pickup_item(ground) and main.world.ground_items.has(ground) and App.character.gold == int(EterEconomy.rules().gold_cap),"gold pickup cap preserves ground and balance"):
		await finish()
		return
	# Rejected quest reward preserves its objective and inventory.
	var capped := EterCharacter.create("Limite","warrior")
	EterQuests.accept(capped,"silk_on_the_road")
	for count in range(3): EterQuests.record_kill(capped,"spider","village")
	capped.gold = int(EterEconomy.rules().gold_cap)
	var before := capped.duplicate(true)
	if not check(EterQuests.claim(capped,"silk_on_the_road") == "gold_cap" and capped == before,"quest cap rejects complete reward atomically"):
		await finish()
		return
	# Map transition retains cooldown and elapsed time instead of resetting it.
	main.queue_free()
	await get_tree().process_frame
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.enter_world("Tiempo","elf")
	if not check(main.world.combat.cast("heal"),"cast real heal before portal"):
		await finish()
		return
	var left: float = main.world.combat.cooldowns.heal
	if not check(await portal("village_forest"),"cooldown portal transition"):
		await finish()
		return
	if not check(main.world.combat.cooldowns.heal > left-0.5 and main.world.combat.cooldowns.heal <= left,"portal preserves remaining heal cooldown"):
		await finish()
		return
	if not check(not main.world.combat.cast("heal"),"portal cannot reset active cooldown"):
		await finish()
		return
	await get_tree().create_timer(0.3).timeout
	if not check(main.world.combat.cooldowns.heal < left-0.2,"cooldown continues ticking in new map"):
		await finish()
		return
	if not check(await portal("forest_village") and main.world.combat.cooldowns.heal > 0,"return portal also preserves cooldown"):
		await finish()
		return
	print("PASS quest stability: %s checks, three real quest flows, persistence, windows, cooldown and gold cap" % checks)
	await finish()
