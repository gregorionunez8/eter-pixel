extends Panel

signal requested(operation: String, value: String)
var character: Dictionary
var shop_id := "shop"
var stock := ItemList.new()
var owned := ItemList.new()
var title := Label.new()
var detail := Label.new()
var owned_ids: Array[String] = []
var stock_ids: Array[String] = []

func _ready() -> void:
	position = Vector2(128,63)
	size = Vector2(496,246)
	z_index = 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522")
	style.border_color = Color("796654")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel",style)
	title.position = Vector2(10,5)
	title.add_theme_font_size_override("font_size",12)
	add_child(title)
	var quests := Button.new()
	quests.name = "quests"
	quests.text = "Encargos"
	quests.position = Vector2(394,3)
	quests.size = Vector2(92,22)
	quests.add_theme_font_size_override("font_size",10)
	quests.pressed.connect(func(): requested.emit("quests",""))
	add_child(quests)
	stock.position = Vector2(10,28)
	stock.size = Vector2(220,150)
	owned.position = Vector2(240,28)
	owned.size = Vector2(246,150)
	for list in [stock,owned]:
		list.add_theme_font_size_override("font_size",10)
		add_child(list)
	stock.item_selected.connect(func(_index): describe())
	owned.item_selected.connect(func(_index): describe())
	detail.position = Vector2(10,183)
	detail.size = Vector2(476,26)
	detail.add_theme_font_size_override("font_size",9)
	add_child(detail)
	var operations := [["buy","Comprar",10],["sell","Vender",105],["repair","Reparar",200],["upgrade","Mejorar",295],["close","Cerrar",390]]
	for entry in operations:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.position = Vector2(entry[2],214)
		button.size = Vector2(86,24)
		button.add_theme_font_size_override("font_size",10)
		var operation: String = entry[0]
		button.pressed.connect(func():
			if operation == "close": hide(); return
			var selected := stock.get_selected_items() if operation == "buy" else owned.get_selected_items()
			if not selected.is_empty():
				requested.emit(operation,stock_ids[selected[0]] if operation == "buy" else owned_ids[selected[0]]))
		add_child(button)
	hide()

func refresh() -> void:
	title.text = "%s · %s oro" % [EterEconomy.rules().shops[shop_id].name,character.gold]
	stock.clear()
	owned.clear()
	stock_ids.clear()
	owned_ids.clear()
	for id in EterEconomy.rules().shops[shop_id].stock:
		stock_ids.append(id)
		stock.add_item("%s · %s oro" % [EterInventory.definitions().definitions[id].name,EterEconomy.buy_price(id,shop_id)])
	for item in character.inventory.items:
		owned_ids.append(item.uid)
		owned.add_item("%s +%s%s" % [EterInventory.definitions().definitions[item.definition].name,item.upgrade," [E]" if character.inventory.equipment.values().has(item.uid) else ""])
	get_node("repair").disabled = not EterEconomy.enabled(shop_id,"repair")
	get_node("upgrade").disabled = not EterEconomy.enabled(shop_id,"upgrade")
	detail.text = "Comprar agrega una unidad. Vender consume la pila; desequipá antes."

func describe() -> void:
	var selected := owned.get_selected_items()
	if selected.is_empty(): return
	var item := EterInventory.find(character.inventory,owned_ids[selected[0]])
	var cost := int(EterInventory.definitions().upgrade.gold_base)+int(item.upgrade)*int(EterInventory.definitions().upgrade.gold_per_level)
	var chance := float(EterInventory.definitions().upgrade.chances[mini(14,int(item.upgrade))])*100
	detail.text = "Venta %s · Reparar %s · Mejora %s oro (%s%%; fallo: -1)\nDurabilidad %s · Nivel máximo +15" % [EterEconomy.sale_price(item),EterEconomy.repair_cost(item),cost,chance,item.durability]
