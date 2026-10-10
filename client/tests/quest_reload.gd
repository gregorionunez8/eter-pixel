extends "res://tests/input_runtime.gd"

func _ready() -> void:
	var saved := EterSave.load_character("res://../artifacts/quest-save.json")
	if not check(not saved.is_empty(),"fresh process reads quest snapshot"):
		await finish()
		return
	for id in EterQuests.definitions():
		var progress: Dictionary = saved.quests.get(id,{})
		if not check(not progress.is_empty() and progress.claimed and int(progress.kills) == int(EterQuests.definitions()[id].objective.count),"fresh process preserves delivered quest: "+id):
			await finish()
			return
	var main := preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.load_selected(saved)
	if not check(main.world.quest_ui.character == App.character and App.character.quests.size() == 3,"loaded character reconnects quest widget"):
		await finish()
		return
	print("PASS quest reload: %d checks, three delivered quests survive fresh Godot process" % checks)
	await finish()
