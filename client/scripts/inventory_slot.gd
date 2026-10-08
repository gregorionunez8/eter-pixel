extends Button

signal changed
signal selected(uid: String)
var character: Dictionary
var slot := "weapon"

func _get_drag_data(_position: Vector2) -> Variant:
	if not character.inventory.equipment.has(slot):
		return null
	var uid: String = character.inventory.equipment[slot]
	var preview := TextureRect.new()
	preview.texture = EterItemVisual.texture(EterInventory.find(character.inventory,uid))
	preview.custom_minimum_size = Vector2(32,32)
	set_drag_preview(preview)
	return {"uid":uid}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("uid"):
		return false
	var item := EterInventory.find(character.inventory,data.uid)
	if item.is_empty():
		return false
	var definition: Dictionary = EterInventory.definitions().definitions[item.definition]
	return definition.get("slot","") == slot and character.class_id in definition.get("classes",["warrior","mage","elf"])

func _drop_data(position: Vector2, data: Variant) -> void:
	if App.online:
		if _can_drop_data(position,data): App.send_intent("equip",{"uid":data.uid})
		return
	if _can_drop_data(position,data) and EterInventory.equip(character,data.uid):
		changed.emit()

func refresh() -> void:
	icon = null
	if character.inventory.equipment.has(slot):
		var item := EterInventory.find(character.inventory,character.inventory.equipment[slot])
		icon = EterItemVisual.texture(item)
		tooltip_text = EterItemVisual.description(item)
