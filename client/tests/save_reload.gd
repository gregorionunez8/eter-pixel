extends Node

func _ready() -> void:
	var file := FileAccess.open("res://../artifacts/inventory-expectation.json",FileAccess.READ)
	if not file:
		push_error("Missing previous-process save expectation")
		get_tree().quit(1)
		return
	var expected: Dictionary = JSON.parse_string(file.get_as_text())
	var character := EterSave.load_character("res://../artifacts/inventory-save.json")
	if character.is_empty():
		push_error("Cannot reload snapshot from previous process")
		get_tree().quit(1)
		return
	var item := EterInventory.find(character.inventory,expected.uid)
	assert(not item.is_empty())
	assert(item.upgrade == expected.upgrade and item.rarity == "magic")
	assert(character.gold == expected.gold)
	assert(EterInventory.valid(character.inventory,character.class_id))
	print("PASS save reload: fresh Godot process preserves UID, rarity, upgrade, gold and inventory")
	get_tree().quit()
