extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL combat: " + description)

func _ready() -> void:
	var attack := {"attack": 30, "accuracy": 90}
	var defense := {"defense": 10, "evasion": 5}
	check(EterCombatRules.hit(attack, defense, "physical", 1, 0, 1).damage == 20, "physical defense")
	check(EterCombatRules.hit(attack, defense, "magic", 1, 0, 1).damage == 24, "magic defense")
	check(EterCombatRules.hit(attack, defense, "physical", 1, 0, 0).damage == 36, "critical multiplier")
	check(EterCombatRules.hit(attack, defense, "physical", 1, 1, 0).damage == 0, "miss deals zero damage")
	check(EterCombatRules.hit({"attack":1,"accuracy":90}, defense, "physical", 1, 0, 1).damage == 1, "minimum damage")
	for class_id in ["warrior", "mage", "elf"]:
		App.class_id = class_id
		App.character = EterCharacter.create("Viajero", class_id)
		var world := preload("res://scenes/world.tscn").instantiate()
		add_child(world)
		await get_tree().physics_frame
		var combat: EterCombat = world.combat
		combat.random.seed = 1909
		combat.set_physics_process(false)
		var resolved_hits: Array = []
		combat.hit_resolved.connect(func(victim, result): resolved_hits.append({"target": victim, "result": result}))
		var target: EterTrainingTarget = world.targets[1]
		combat.select_target(target)
		var skills: Array = EterCombatRules.definitions().classes[class_id].skills
		var mana_before: int = App.character.mana
		check(not combat.cast("invalid_skill"), "invalid skill rejected")
		check(not combat.cast(skills[0]), "out of range rejected")
		check(App.character.mana == mana_before and combat.cooldowns.is_empty(), "rejection consumes no mana or cooldown")
		world.player.position = target.position + Vector2(0,-32)
		await get_tree().physics_frame
		check(combat.cast(skills[0]), "first skill works for " + class_id)
		check(target.state.hp < target.state.stats.max_hp, "skill causes real target damage")
		check(App.character.mana == mana_before - int(EterCombatRules.definitions().skills[skills[0]].mana), "exact mana cost")
		check(not combat.cast(skills[0]), "cooldown blocks repeat cast")
		App.character.hp = App.character.stats.max_hp - 40
		resolved_hits.clear()
		check(combat.cast(skills[1]), "second skill works for " + class_id)
		if class_id == "elf":
			check(App.character.hp > App.character.stats.max_hp - 40 and App.character.hp <= App.character.stats.max_hp, "healing is capped")
		else:
			check(resolved_hits.size() == 3, "area attempts all three targets")
			for index in range(3):
				check(resolved_hits[index].target == world.targets[index], "area resolves each target exactly once")
				var expected_hp: int = world.targets[index].state.stats.max_hp - int(resolved_hits[index].result.damage)
				if index != 1:
					check(world.targets[index].state.hp == expected_hp, "area applies hit or miss consistently")
		App.character.mana = 0
		combat.cooldowns.clear()
		check(not combat.cast(skills[0]), "mana validation")
		combat.select_target(null)
		combat.since_damage = 10
		combat._physics_process(1.1)
		check(App.character.mana > 0, "mana regeneration")
		# A wall in front of a close target must prevent the spell.
		target.position = Vector2(24 * 32 + 16, 14 * 32 + 16)
		world.player.position = Vector2(24 * 32 + 16, 16 * 32 + 16)
		App.character.mana = App.character.stats.max_mana
		combat.select_target(target)
		await get_tree().physics_frame
		check(not combat.cast(skills[0]), "spell cannot pass through shrine")
		world.queue_free()
		await get_tree().process_frame
	# Real ticks: pursue, autoattack, death and both respawns.
	App.class_id = "warrior"
	App.character = EterCharacter.create("Acero", "warrior")
	var world := preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	world.combat.random.seed = 1909
	var target: EterTrainingTarget = world.targets[1]
	world.player.position = target.position + Vector2(0,-192)
	world.combat.select_target(target)
	for tick in range(150):
		await get_tree().physics_frame
		check(world.is_safe(world.player.position), "pursuit respects walls")
	check(world.player.position.distance_to(target.position) <= 44, "pursuit reaches attack range")
	check(target.state.hp < target.state.stats.max_hp, "autoattack changes health")
	world.combat.select_target(null)
	# Lethal damage still can miss. Retry attacks, and assert a real resolved hit kills.
	for attempt in range(8):
		if target.dead:
			break
		world.combat.damage_target(target, 1000, "physical", "slash")
	check(target.dead and target.state.hp == 0, "target dies")
	world.combat.receive_damage({"attack":100000,"accuracy":1000})
	check(world.player.dead and App.character.hp == 0, "player dies")
	var position_at_death: Vector2 = world.player.position
	world.player.move_to(position_at_death + Vector2(100,0))
	await get_tree().physics_frame
	check(world.player.position == position_at_death, "dead player cannot move")
	for tick in range(330):
		await get_tree().physics_frame
	check(not world.player.dead and App.character.hp == App.character.stats.max_hp, "real player respawn restores health")
	check(world.player.position == world.spawn_position, "respawn returns to village")
	check(not target.dead and target.state.hp == target.state.stats.max_hp, "real target respawn")
	print("PASS combat: %s checks, skills, pursuit, autoattack, death and real respawns" % checks if not failed else "FAIL combat suite")
	get_tree().quit(1 if failed else 0)
