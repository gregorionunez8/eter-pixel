extends Node

func _ready() -> void:
	var file := FileAccess.open("res://../artifacts/inventory-expectation.json",FileAccess.READ)
	if not file:
		push_error("Missing previous-process save expectation")
		get_tree().quit(1)
		return
	var expected: Variant = JSON.parse_string(file.get_as_text())
	if not expected is Dictionary or not expected.has_all(["uid","upgrade","gold"]):
		printerr("FAIL save reload: invalid expectation")
		get_tree().quit(1)
		return
	var character := EterSave.load_character("res://../artifacts/inventory-save.json")
	if character.is_empty():
		push_error("Cannot reload snapshot from previous process")
		get_tree().quit(1)
		return
	var item := EterInventory.find(character.inventory,expected.uid)
	if item.is_empty() or item.upgrade != expected.upgrade or item.rarity != "magic" or character.gold != expected.gold or not EterInventory.valid(character.inventory,character.class_id):
		printerr("FAIL save reload: saved item or economy differs")
		get_tree().quit(1)
		return
	print("PASS save reload: fresh Godot process preserves UID, rarity, upgrade, gold and inventory")
	get_tree().quit()
