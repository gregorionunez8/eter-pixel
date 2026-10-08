extends Control

signal changed
signal selected(uid: String)
signal activated(uid: String)
const CELL := 20
var character: Dictionary
var selected_uid := ""

func item_at(point: Vector2) -> Dictionary:
	for item in character.inventory.items:
		var size: Array = EterInventory.definitions().definitions[item.definition].size
		if int(item.x) >= 0 and Rect2(int(item.x)*CELL,int(item.y)*CELL,int(size[0])*CELL,int(size[1])*CELL).has_point(point):
			return item
	return {}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var item := item_at(event.position)
		if not item.is_empty():
			selected_uid = item.uid
			selected.emit(item.uid)
			if event.button_index == MOUSE_BUTTON_RIGHT or event.double_click:
				activated.emit(item.uid)
			queue_redraw()

func _get_drag_data(position: Vector2) -> Variant:
	var item := item_at(position)
	if item.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = EterItemVisual.texture(item)
	preview.custom_minimum_size = Vector2(32,32)
	set_drag_preview(preview)
	return {"uid":item.uid}

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("uid"):
		return false
	var item := EterInventory.find(character.inventory,data.uid)
	return not item.is_empty() and EterInventory.fits(character.inventory,item,floori(position.x/CELL),floori(position.y/CELL))

func _drop_data(position: Vector2, data: Variant) -> void:
	if not _can_drop_data(position,data):
		return
	var draft: Dictionary = character.inventory.duplicate(true)
	for slot in draft.equipment.keys():
		if draft.equipment[slot] == data.uid and not EterInventory.unequip(draft,slot):
			return
	if EterInventory.move(draft,data.uid,floori(position.x/CELL),floori(position.y/CELL)):
		character.inventory = draft
		changed.emit()
		queue_redraw()

func _draw() -> void:
	if character.is_empty():
		return
	for y in range(6):
		for x in range(8):
			draw_rect(Rect2(x*CELL,y*CELL,CELL-1,CELL-1),Color("27313e"))
	for item in character.inventory.items:
		if int(item.x) < 0:
			continue
		var size: Array = EterInventory.definitions().definitions[item.definition].size
		var rect := Rect2(int(item.x)*CELL,int(item.y)*CELL,int(size[0])*CELL-1,int(size[1])*CELL-1)
		var color := EterItemVisual.color(item)
		draw_rect(rect,Color(color.r*0.22,color.g*0.22,color.b*0.22))
		draw_rect(rect,Color.WHITE if item.uid == selected_uid else color,false,1)
		var icon_size := 32 if minf(rect.size.x,rect.size.y) >= 32 else 16
		draw_texture_rect(EterItemVisual.texture(item),Rect2(rect.get_center()-Vector2.ONE*icon_size/2.0,Vector2.ONE*icon_size),false)
		if int(item.count) > 1:
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(2,17),str(int(item.count)),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.WHITE)
