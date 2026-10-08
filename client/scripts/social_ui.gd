extends Control

var panel := Panel.new()
var roster := ItemList.new()
var party_status: Label
var accept_party: Button
var reject_party: Button
var trade_panel := Panel.new()
var trade_title: Label
var mine := ItemList.new()
var theirs := ItemList.new()
var gold := SpinBox.new()
var other_gold: Label
var offer_button: Button
var confirm_button: Button
var state: Dictionary = {}
var roster_ids: Array[String] = []
var item_ids: Array[String] = []
var signature := ""
var previous_trade := ""
var previous_invitation := ""
var trade_signature := ""

func label(parent: Node, text: String, point: Vector2, width: float = 300) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.size.x = width
	node.add_theme_font_size_override("font_size",11)
	parent.add_child(node)
	return node

func button(parent: Node,text: String,point: Vector2,width: float,action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = point
	node.size = Vector2(width,24)
	node.add_theme_font_size_override("font_size",10)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	for window in [panel,trade_panel]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("111522")
		style.border_color = Color("796654")
		style.set_border_width_all(1)
		window.add_theme_stylebox_override("panel",style)
		add_child(window)
	panel.position = Vector2(300,63)
	panel.size = Vector2(324,246)
	label(panel,"Jugadores conectados · P: cerrar",Vector2(12,7))
	roster.position = Vector2(12,28)
	roster.size = Vector2(300,70)
	roster.add_theme_font_size_override("font_size",11)
	panel.add_child(roster)
	button(panel,"Invitar party",Vector2(12,104),96,func(): invite("party_invite"))
	button(panel,"Comerciar",Vector2(112,104),96,func(): invite("trade_invite"))
	button(panel,"Salir party",Vector2(212,104),96,func(): App.send_intent("party_leave",{}))
	party_status = label(panel,"Sin grupo",Vector2(12,139))
	party_status.size.y = 43
	party_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accept_party = button(panel,"Aceptar invitación",Vector2(12,190),146,func(): App.send_intent("party_reply",{"accept":true}))
	reject_party = button(panel,"Rechazar",Vector2(166,190),146,func(): App.send_intent("party_reply",{"accept":false}))
	button(panel,"Cerrar",Vector2(212,218),96,hide)
	trade_panel.position = Vector2(128,63)
	trade_panel.size = Vector2(496,246)
	trade_title = label(trade_panel,"Comercio",Vector2(12,7),472)
	label(trade_panel,"Tu oferta · seleccioná pilas completas",Vector2(12,30),230)
	label(trade_panel,"Oferta del otro jugador",Vector2(254,30),230)
	mine.position = Vector2(12,49)
	theirs.position = Vector2(254,49)
	for list in [mine,theirs]:
		list.size = Vector2(230,120)
		list.add_theme_font_size_override("font_size",10)
		trade_panel.add_child(list)
	mine.select_mode = ItemList.SELECT_MULTI
	label(trade_panel,"Tu oro",Vector2(12,182),80)
	gold.position = Vector2(90,175)
	gold.size = Vector2(145,28)
	gold.min_value = 0
	gold.step = 1
	gold.add_theme_font_size_override("font_size",11)
	trade_panel.add_child(gold)
	other_gold = label(trade_panel,"Oro: 0",Vector2(254,182),230)
	offer_button = button(trade_panel,"Ofrecer",Vector2(12,214),96,offer)
	confirm_button = button(trade_panel,"Confirmar",Vector2(112,214),272,confirm)
	button(trade_panel,"Cancelar",Vector2(388,214),96,func(): App.send_intent("trade_cancel",{}))
	trade_panel.hide()
	hide()

func invite(operation: String) -> void:
	if roster.get_selected_items().is_empty(): return
	App.send_intent(operation,{"target_id":roster_ids[roster.get_selected_items()[0]]})

func offer() -> void:
	var uids: Array[String] = []
	for index in mine.get_selected_items(): uids.append(item_ids[index])
	if state.get("trade") is Dictionary:
		App.send_intent("trade_offer",{"uids":uids,"gold":int(gold.value),"revision":int(state.trade.revision)})

func confirm() -> void:
	if not state.get("trade") is Dictionary: return
	if state.trade.phase == "invited": App.send_intent("trade_reply",{"accept":true})
	else: App.send_intent("trade_accept",{"revision":int(state.trade.revision)})

func toggle() -> void:
	visible = not visible
	if visible:
		trade_panel.visible = state.get("trade") is Dictionary
		panel.visible = not trade_panel.visible

func refresh(value: Dictionary) -> void:
	var next_signature := JSON.stringify([value,App.character.inventory,App.character.gold])
	if next_signature == signature: return
	signature = next_signature
	state = value
	var selected := roster_ids[roster.get_selected_items()[0]] if not roster.get_selected_items().is_empty() else ""
	roster.clear()
	roster_ids.clear()
	for actor in state.get("players",[]):
		if actor.id == App.online_character_id: continue
		roster_ids.append(actor.id)
		roster.add_item("%s · %s · Nv%s" % [actor.name,EterCharacter.definitions().classes[actor.class_id].name,int(actor.level)])
		if actor.id == selected: roster.select(roster_ids.size()-1)
	var party: Variant = state.get("party")
	party_status.text = "Sin party. Seleccioná un jugador e invitalo."
	if party is Dictionary:
		var names: Array[String] = []
		for actor in party.members: names.append("%s%s %s/%s" % [actor.name," ★" if actor.id == party.leader else "",int(actor.hp),int(actor.max_hp)])
		party_status.text = "Party: " + ", ".join(names)
	var invitation: Variant = state.get("invitation")
	accept_party.visible = invitation is Dictionary
	reject_party.visible = invitation is Dictionary
	if invitation is Dictionary:
		party_status.text = invitation.name+" te invita a su party."
		if previous_invitation != invitation.from: show(); panel.show(); trade_panel.hide()
		previous_invitation = invitation.from
	else: previous_invitation = ""
	var trade: Variant = state.get("trade")
	if not trade is Dictionary:
		if not previous_trade.is_empty(): trade_panel.hide(); panel.show(); party_status.text += "\nComercio cerrado: revisá tus objetos y oro."
		previous_trade = ""
		return
	if previous_trade != trade.id: show(); panel.hide(); trade_panel.show()
	previous_trade = trade.id
	var next_trade_signature := JSON.stringify([trade,App.character.inventory,App.character.gold])
	if next_trade_signature == trade_signature: return
	trade_signature = next_trade_signature
	mine.clear(); theirs.clear(); item_ids.clear()
	var own_offer: Dictionary = {}
	var other_offer: Dictionary = {}
	for entry in trade.offers:
		if entry.id == App.online_character_id: own_offer = entry
		else: other_offer = entry
	for item in App.character.inventory.items:
		if App.character.inventory.equipment.values().has(item.uid): continue
		item_ids.append(item.uid)
		mine.add_item("%s ×%s" % [EterItemVisual.description(item).split("\n")[0],int(item.count)],EterItemVisual.texture(item))
		mine.set_item_tooltip(mine.get_item_count()-1,EterItemVisual.description(item))
		for offered in own_offer.get("items",[]):
			if offered.uid == item.uid: mine.select(item_ids.size()-1,false)
	for item in other_offer.get("items",[]):
		theirs.add_item("%s ×%s" % [EterItemVisual.description(item).split("\n")[0],int(item.count)],EterItemVisual.texture(item))
		theirs.set_item_tooltip(theirs.get_item_count()-1,EterItemVisual.description(item))
	gold.max_value = App.character.gold
	gold.value = own_offer.get("gold",0)
	other_gold.text = "Oro ofrecido: %s" % int(other_offer.get("gold",0))
	trade_title.text = "Comercio con %s · %s" % [other_offer.get("name",""),"Invitación pendiente" if trade.phase == "invited" else "%s/2 confirmados" % trade.accepted.size()]
	offer_button.disabled = trade.phase != "open"
	gold.editable = trade.phase == "open"
	confirm_button.text = "Aceptar invitación" if trade.phase == "invited" else "Confirmado" if App.online_character_id in trade.accepted else "Confirmar oferta actual"
	confirm_button.disabled = (trade.phase == "invited" and trade.from == App.online_character_id) or App.online_character_id in trade.accepted
