extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL character: " + description)

func _ready() -> void:
	check(EterCharacter.valid_name("Éter_01"), "accented name accepted")
	for value in ["ab", "Name with space", "<script>", "12345678901234567", ""]:
		check(not EterCharacter.valid_name(value), "invalid name rejected")
	check(EterCharacter.create("Viajero", "unknown").is_empty(), "unknown class rejected")
	var warrior := EterCharacter.create("Acero", "warrior")
	var mage := EterCharacter.create("Bruma", "mage")
	var elf := EterCharacter.create("Liria", "elf")
	check(warrior.stats.max_hp == 160 and warrior.stats.attack == 27, "warrior baseline")
	check(mage.stats.max_mana == 132 and mage.stats.attack == 30, "mage baseline")
	check(elf.stats.defense == 14 and elf.stats.accuracy == 88, "elf baseline")
	warrior.attributes.strength = 100
	check(EterCharacter.create("Acero", "warrior").attributes.strength == 26, "data is not mutated by character")
	var screen := Control.new()
	screen.set_script(preload("res://scripts/character_creation.gd"))
	add_child(screen)
	var submissions: Array = []
	screen.character_created.connect(func(value, class_id): submissions.append([value, class_id]))
	screen.name_input.text = "ab"
	screen.submit()
	check(submissions.is_empty(), "UI refuses invalid creation")
	for index in range(3):
		var class_id: String = screen.class_ids[index]
		screen.class_select.select(index)
		screen.update_selection(index)
		screen.name_input.text = "Viajero%s" % index
		screen.submit()
		check(submissions[index][1] == class_id, "UI emits selected class")
		check(screen.preview.texture.get_size() == Vector2(128,384), "class sprite exists with eight directions")
		App.class_id = class_id
		App.player_name = submissions[index][0]
		App.character = EterCharacter.create(App.player_name, class_id)
		check(App.character.level == 1 and App.character.experience == 0 and App.character.attribute_points == 0, "initial progression fields")
		var world := preload("res://scenes/world.tscn").instantiate()
		add_child(world)
		await get_tree().physics_frame
		var start: Vector2 = world.player.position
		world.player.move_to(start + Vector2(64,0))
		for tick in range(10):
			await get_tree().physics_frame
		check(world.player.position.x > start.x + 10, "class actually moves")
		check(world.player.sprite.frame > 0, "walk animation runs")
		check(world.player.sprite.texture.resource_path.ends_with(class_id + ".png"), "class appearance applied")
		check(App.character.appearance.weapon in ["sword", "staff", "bow"], "starter weapon visual")
		world.queue_free()
		await get_tree().process_frame
	print("PASS characters: %s checks, all three classes created and moving" % checks if not failed else "FAIL characters suite")
	get_tree().quit(1 if failed else 0)
