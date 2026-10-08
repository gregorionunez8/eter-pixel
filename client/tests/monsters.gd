extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL monster: " + description)

func _ready() -> void:
	var world := preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	world.combat.random.seed = 1909
	var monsters: Array[EterMonster] = []
	for target in world.targets:
		if target is EterMonster:
			monsters.append(target)
			target.set_physics_process(false)
	check(monsters.size() == 6, "all six species exist in actual world")
	for monster in monsters:
		check(monster.config.experience > 0 and monster.config.loot.gold_max >= monster.config.loot.gold_min, "progression and loot data")
		check(world.is_safe(monster.home, monster.config.radius - 0.5), "safe spawn footprint")
		check(monster.sprite.hframes == 4 and monster.sprite.texture != null, "original animation sheet exists")
		monster.position = Vector2(22 * 32 + 16, 19 * 32 + 16)
		monster.home = monster.position
		world.player.position = monster.position + Vector2(64,0)
		world.player.path.clear()
		App.character.hp = App.character.stats.max_hp
		var phases: Array = []
		var record := func(value): phases.append(value)
		monster.phase_changed.connect(record)
		monster.set_physics_process(true)
		for tick in range(180):
			await get_tree().physics_frame
			check(world.is_safe(monster.position, float(monster.config.radius) - 0.5), "moving enemy remains outside solids")
		check("detect" in phases and "chase" in phases and "attack" in phases, "detect -> chase -> attack for " + monster.species_id)
		check(App.character.hp < App.character.stats.max_hp, "enemy actually damages player")
		world.player.position = monster.home + Vector2(0, -float(monster.config.leash_radius) - 64)
		for tick in range(120):
			await get_tree().physics_frame
		check("return" in phases and monster.phase == "idle", "leash returns to idle: %s (%s)" % [monster.species_id, monster.phase])
		check(monster.position.distance_to(monster.home) < 2, "return reaches home: %s %s" % [monster.species_id, monster.position.distance_to(monster.home)])
		# Kill through combat; duplicate commands must not emit duplicate death rewards.
		var kills: Array = []
		var count_kill := func(victim): kills.append(victim)
		world.combat.target_defeated.connect(count_kill)
		for attempt in range(10):
			world.combat.damage_target(monster, 1000, "magic", "fire")
			if monster.dead:
				break
		world.combat.damage_target(monster, 1000, "magic", "fire")
		check(monster.dead and monster.phase == "dying" and kills.size() == 1, "death only occurs once")
		# Spider uses production six-second timer; other species use a short timer fixture.
		if monster.species_id != "spider":
			monster.respawn_left = 0.7
		var ticks := 380 if monster.species_id == "spider" else 50
		for tick in range(ticks):
			await get_tree().physics_frame
		check("respawn" in phases and not monster.dead and monster.state.hp == monster.state.stats.max_hp, "respawn restores enemy")
		monster.set_physics_process(false)
		monster.phase_changed.disconnect(record)
		world.combat.target_defeated.disconnect(count_kill)
	# Exercise obstacle detour with a player behind the plaza shrine.
	var spider := monsters[0]
	spider.position = Vector2(22 * 32 + 16, 14 * 32 + 16)
	spider.home = spider.position
	world.player.position = Vector2(26 * 32 + 16, 14 * 32 + 16)
	spider.on_hit()
	spider.set_physics_process(true)
	for tick in range(240):
		await get_tree().physics_frame
		check(world.is_safe(spider.position, 6.5), "pursuit detours around shrine without crossing")
	check(spider.position.distance_to(world.player.position) < 32, "enemy reaches player around wall")
	print("PASS monsters: %s checks, six species AI, physical navigation, death and respawn" % checks if not failed else "FAIL monsters suite")
	get_tree().quit(1 if failed else 0)
