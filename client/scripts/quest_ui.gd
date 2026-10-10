extends Panel

signal requested(operation: String, id: String)
var character: Dictionary
var npc_id := ""
var ids: Array[String] = []
var listing := ItemList.new()
var detail := Label.new()
var title := Label.new()
var action := Button.new()
var signature := ""
var busy := false

func _ready() -> void:
	position = Vector2(80,83)
	size = Vector2(480,220)
	z_index = 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522")
	style.border_color = Color("b48b53")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel",style)
	title.position = Vector2(12,7)
	title.add_theme_font_size_override("font_size",12)
	add_child(title)
	listing.position = Vector2(12,32)
	listing.size = Vector2(158,142)
	listing.add_theme_font_size_override("font_size",10)
	add_child(listing)
	listing.item_selected.connect(func(_index): describe())
	detail.position = Vector2(182,32)
	detail.size = Vector2(284,146)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",11)
	add_child(detail)
	action.position = Vector2(182,185)
	action.size = Vector2(176,26)
	action.add_theme_font_size_override("font_size",11)
	action.pressed.connect(func():
		var selection := listing.get_selected_items()
		if busy or selection.is_empty(): return
		var id := ids[selection[0]]
		requested.emit("quest_claim" if character.get("quests",{}).has(id) else "quest_accept",id))
	add_child(action)
	var close := Button.new()
	close.text = "Cerrar"
	close.position = Vector2(370,185)
	close.size = Vector2(96,26)
	close.add_theme_font_size_override("font_size",11)
	close.pressed.connect(hide)
	add_child(close)
	hide()

func open(npc: String = "") -> void:
	npc_id = npc
	signature = ""
	show()
	refresh()

func refresh() -> void:
	var next := JSON.stringify([npc_id,character.get("quests",{}),busy])
	if next == signature: return
	signature = next
	var previous := ""
	var selected := listing.get_selected_items()
	if not selected.is_empty() and selected[0] < ids.size(): previous = ids[selected[0]]
	listing.clear();ids.clear()
	title.text = "Diario · Encargos de Éter" if npc_id.is_empty() else EterEconomy.rules().shops[npc_id].name+" · Encargos"
	for id in EterQuests.definitions():
		var quest: Dictionary = EterQuests.definitions()[id]
		if not npc_id.is_empty() and quest.npc != npc_id: continue
		ids.append(id)
		var progress: Dictionary = character.get("quests",{}).get(id,{})
		var status := "Entregado" if progress.get("claimed",false) else "Activo %s/%s" % [int(progress.kills),int(quest.objective.count)] if not progress.is_empty() else "Disponible"
		listing.add_item(quest.name+" · "+status)
		listing.set_item_tooltip(ids.size()-1,quest.name+" · "+status)
	if not ids.is_empty(): listing.select(maxi(0,ids.find(previous)))
	describe()

func describe() -> void:
	var selected := listing.get_selected_items()
	if selected.is_empty(): detail.text = "No hay encargos.";action.disabled=true;return
	var id := ids[selected[0]]
	var quest: Dictionary = EterQuests.definitions()[id]
	var progress: Dictionary = character.get("quests",{}).get(id,{})
	var claimed: bool = progress.get("claimed",false)
	var locked: bool = quest.requires != null and not character.get("quests",{}).get(quest.requires,{}).get("claimed",false)
	var status := "Entregado" if claimed else "Requiere el encargo anterior" if locked else "Muertes: %s/%s" % [int(progress.get("kills",0)),int(quest.objective.count)] if not progress.is_empty() else "Disponible"
	var rewards := "%s XP · %s oro" % [int(quest.reward.experience),int(quest.reward.gold)]
	for item in quest.reward.items: rewards += " · %s ×%s" % [EterInventory.definitions().definitions[item.definition].name,int(item.count)]
	detail.text = "%s\n\n%s\n%s" % [quest.completed_dialogue if claimed else quest.dialogue,status,rewards]
	action.text = "Entregado" if claimed else "Entregar" if not progress.is_empty() else "Aceptar"
	action.disabled = busy or npc_id.is_empty() or locked or claimed or (not progress.is_empty() and int(progress.kills)<int(quest.objective.count))
