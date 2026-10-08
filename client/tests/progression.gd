extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL progression: " + description)

func _ready() -> void:
	check(EterProgression.required_experience(1) == 80, "initial XP threshold")
	for level in range(2,101):
		check(EterProgression.required_experience(level) > EterProgression.required_experience(level-1), "progressive XP curve")
	for class_id in ["warrior", "mage", "elf"]:
		var character := EterCharacter.create("Viajero", class_id)
		check(EterProgression.gain_experience(character,-1) == 0 and character.experience == 0, "negative XP rejected")
		check(EterProgression.gain_experience(character,79) == 0 and character.level == 1, "below threshold")
		var before_hp: int = character.stats.max_hp
		check(EterProgression.gain_experience(character,1) == 1 and character.level == 2 and character.experience == 0, "exact threshold levels up")
		check(character.attribute_points == 5 and character.stats.max_hp == before_hp + 8 and character.hp == character.stats.max_hp, "level grants points and derived growth")
		check(not EterProgression.allocate(character,"unknown") and not EterProgression.allocate(character,"strength",6) and not EterProgression.allocate(character,"strength",-1), "allocation validation")
		var strength: int = character.attributes.strength
		check(EterProgression.allocate(character,"strength",2) and character.attributes.strength == strength+2 and character.attribute_points == 3, "points allocated exactly")
		check(EterProgression.allocate(character,"vitality",3) and character.attribute_points == 0 and character.stats.max_hp == before_hp+23, "vitality modifies actual stats")
		check(not EterProgression.allocate(character,"energy"), "cannot overspend")
		character.experience = 99
		check(EterProgression.death_penalty(character) == 4 and character.experience == 95 and character.level == 2, "death penalty is configurable progress loss without delevel")
		var levels := EterProgression.gain_experience(character,1000000000)
		check(levels == 98 and character.level == 100 and character.experience == 0, "large rewards are bounded by level cap")
		check(not EterProgression.can_reset(character) and character.reset_count == 0, "reset expansion remains explicitly disabled")
	# Integration: actual battle commands award XP once, efigies award none.
	App.class_id = "warrior"
	App.character = EterCharacter.create("Acero", "warrior")
	var world := preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	world.combat.random.seed = 1909
	for target in world.targets:
		if target is EterMonster:
			target.set_physics_process(false)
	var spider: EterMonster = world.targets[3]
	world.player.position = spider.home + Vector2(-32,0)
	world.combat.select_target(spider)
	await get_tree().physics_frame
	world.combat.cast("power_strike")
	for tick in range(240):
		await get_tree().physics_frame
	check(spider.dead and App.character.experience == 24, "real combat death grants species XP")
	world.combat.damage_target(spider,1000,"physical","slash")
	check(App.character.experience == 24, "duplicate death grants no XP")
	for attempt in range(8):
		world.combat.damage_target(world.targets[0],1000,"physical","slash")
	check(App.character.experience == 24, "efigies cannot farm XP")
	EterProgression.gain_experience(App.character,56)
	world.update_resources()
	world.allocation_buttons.strength.pressed.emit()
	check(App.character.attribute_points == 4 and App.character.attributes.strength == 27, "character panel allocates points")
	check(world.experience_label.text.contains("Puntos 4"), "HUD reflects progression")
	print("PASS progression: %s checks, curve, levels, allocation, death penalty and real battle rewards" % checks if not failed else "FAIL progression suite")
	get_tree().quit(1 if failed else 0)
