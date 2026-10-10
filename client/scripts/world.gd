extends Node2D

signal map_changed(map_id: String,point: Vector2)
var SIZE := Vector2i(48, 32)
const TILE := 32
var map_id := "village"
var geometry: Dictionary = {}
var portals: Array[Node2D] = []
var pending_portal: Node2D
var changing_map := false
var navigation := EterNavigation.new()
var blocked: Array[Vector2i] = []
var solid_rectangles: Array[Rect2] = []
var player: EterPlayer
var terrain: Texture2D
var entities := Node2D.new()
var marker := Vector2(-100, -100)
var held := false
var mouse_tick := 0.0
var pointer_position := Vector2.ZERO
var hud: CanvasLayer
var pause_menu: PanelContainer
var combat := EterCombat.new()
var targets: Array[EterTrainingTarget] = []
var spawn_position := Vector2(24 * TILE + 16, 18 * TILE + 16)
var resource_label := Label.new()
var message_label := Label.new()
var message_left := 0.0
var skill_buttons: Array[Button] = []
var experience_label := Label.new()
var character_panel := PanelContainer.new()
var character_summary := Label.new()
var attribute_labels: Dictionary = {}
var allocation_buttons: Dictionary = {}
var inventory_ui: Control
var ground_items: Array[EterGroundItem] = []
var pending_pickup: EterGroundItem
var save_tick := 0.0
var economy_random := RandomNumberGenerator.new()
var npcs: Array[Node2D] = []
var pending_npc: Node2D
var active_npc: Node2D
var quest_ui: Panel
var shop_ui: Control
var minimap: Control
var map_panel: Control
var chat_ui: Control
var health_bar := ProgressBar.new()
var mana_bar := ProgressBar.new()
var experience_bar := ProgressBar.new()
var online_world: Node
var social_ui: Control

func _ready() -> void:
	economy_random.randomize()
	map_id = App.character.get("map_id","village")
	var maps: Dictionary = Catalog.read("maps").maps
	if not maps.has(map_id): map_id = "village"
	geometry = maps[map_id]
	SIZE = Vector2i(int(geometry.width),int(geometry.height))
	terrain = load("res://assets/%s.png" % geometry.terrain)
	entities.y_sort_enabled = true
	add_child(entities)
	assert(int(geometry.tile) == TILE,"Map tile dimensions mismatch")
	spawn_position = Vector2(geometry.spawn.x,geometry.spawn.y)
	for entry in geometry.obstacles:
		add_obstacle(Rect2i(int(entry.x),int(entry.y),int(entry.width),int(entry.height)),entry.texture)
	navigation.setup(SIZE, blocked)
	player = EterPlayer.new()
	player.navigation = navigation
	player.replicated = App.online
	player.position = spawn_position
	if App.character.get("position") is Dictionary:
		var point: Dictionary = App.character.position
		var saved_position := Vector2(float(point.get("x",spawn_position.x)),float(point.get("y",spawn_position.y)))
		if is_safe(saved_position,7): player.position = saved_position
	entities.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = SIZE.x * TILE
	player.camera.limit_bottom = SIZE.y * TILE
	for x in [22, 24, 26] if map_id == "village" else []:
		var target := EterTrainingTarget.new()
		target.position = Vector2(x * TILE + 16, 27 * TILE + 16)
		target.set_meta("server_id","training-%d" % x)
		entities.add_child(target)
		targets.append(target)
	combat.setup(self, player, targets)
	add_child(combat)
	for monster_index in range(geometry.monsters.size()):
		var entry: Dictionary = geometry.monsters[monster_index]
		var monster := EterMonster.new()
		monster.species_id = entry.species
		monster.position = Vector2(entry.x,entry.y)
		monster.navigation = navigation
		monster.player = player
		monster.combat = combat
		monster.set_meta("server_id",entry.get("id","monster-%d" % monster_index))
		entities.add_child(monster)
		if App.online:
			monster.set_physics_process(false)
		targets.append(monster)
	combat.state_changed.connect(update_resources)
	combat.target_defeated.connect(reward_monster)
	combat.feedback.connect(func(message: String): message_label.text = message; message_left = 2.5)
	combat.hit_resolved.connect(func(victim: Node2D, result: Dictionary):
		if int(result.damage) > 0:
			EterEconomy.wear(App.character,"armor" if victim == player else "weapon")
			App.character.stats = EterCharacter.derive(App.character))
	build_hud()
	for entry in geometry.npcs:
		var npc := Node2D.new()
		npc.set_script(preload("res://scripts/npc.gd"))
		npc.shop_id = entry.id
		npc.position = Vector2(entry.x,entry.y)
		entities.add_child(npc)
		npcs.append(npc)
	for entry in geometry.portals:
		var portal := preload("res://scripts/portal.gd").new()
		portal.definition = entry
		portal.position = Vector2(entry.x,entry.y)
		entities.add_child(portal)
		portals.append(portal)
	if not App.online and map_id == "village" and not App.character.get("starter_ground_claimed",false):
		spawn_ground_item(EterInventory.make_item("bronze_sword",1,"magic"),spawn_position+Vector2(-96,32))
		ground_items[0].starter_reward = true
	var ambient := CanvasModulate.new()
	ambient.color = Color(geometry.ambient)
	add_child(ambient)
	if App.online:
		App.portal_result.connect(func(success: bool): if not success: changing_map = false)
		online_world = preload("res://scripts/online_world.gd").new()
		online_world.world = self
		add_child(online_world)
	queue_redraw()

func add_obstacle(cells: Rect2i, texture_id: String) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			blocked.append(Vector2i(x, y))
	var footprint := Rect2(Vector2(cells.position) * TILE, Vector2(cells.size) * TILE)
	solid_rectangles.append(footprint)
	var body := StaticBody2D.new()
	body.position = Vector2(footprint.get_center().x, footprint.end.y)
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	collision.shape = shape
	collision.position = Vector2(0, -footprint.size.y / 2)
	body.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/%s.png" % texture_id)
	sprite.position = Vector2(0, -sprite.texture.get_height() / 2.0 + 4)
	body.add_child(sprite)
	entities.add_child(body)
	if texture_id == "smith" or texture_id == "shop":
		var label := Label.new()
		label.text = "Herrero" if texture_id == "smith" else "Tienda"
		label.position = Vector2(-40, 1)
		label.size.x = 80
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(label)

func build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var location := Label.new()
	location.text = str(geometry.name).to_upper()
	location.position = Vector2(16, 10)
	location.add_theme_font_size_override("font_size", 14)
	location.modulate = Color("d5aa64")
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(location)
	resource_label.position = Vector2(16, 29)
	resource_label.add_theme_font_size_override("font_size", 11)
	resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(resource_label)
	experience_label.position = Vector2(16, 44)
	experience_label.add_theme_font_size_override("font_size", 10)
	experience_label.modulate = Color("d5aa64")
	experience_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(experience_label)
	update_resources()
	var help := Label.new()
	help.text = "Clic: mover/atacar · I/C/M: ventanas · Enter: chat · Esc: menú"
	help.position = Vector2(14, 310)
	help.add_theme_font_size_override("font_size", 11)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(help)
	message_label.position = Vector2(306, 337)
	message_label.add_theme_font_size_override("font_size", 10)
	message_label.modulate = Color("d5aa64")
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(message_label)
	var skills: Array = EterCombatRules.definitions().classes[App.class_id].skills
	for index in range(skills.size()):
		var button := Button.new()
		button.position = Vector2(14 + index * 144, 332)
		button.size = Vector2(140, 24)
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_disabled_color", Color("b4aca0"))
		var skill_id: String = skills[index]
		button.pressed.connect(func(): held = false; combat.cast(skill_id))
		hud.add_child(button)
		skill_buttons.append(button)
	pause_menu = PanelContainer.new()
	pause_menu.position = Vector2(220, 112)
	pause_menu.size = Vector2(200, 150)
	pause_menu.visible = false
	hud.add_child(pause_menu)
	var box := VBoxContainer.new()
	pause_menu.add_child(box)
	var title := Label.new()
	title.text = "ÉTER · Menú"
	box.add_child(title)
	var resume := Button.new()
	resume.text = "Continuar"
	resume.pressed.connect(func(): pause_menu.hide())
	box.add_child(resume)
	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "Configuración"
	settings.pressed.connect(func():
		var dialog := AcceptDialog.new()
		dialog.set_script(preload("res://scripts/settings_ui.gd"))
		hud.add_child(dialog)
		dialog.popup_centered())
	box.add_child(settings)
	var leave := Button.new()
	leave.text = "Volver al inicio"
	leave.pressed.connect(func(): App.save_character(); App.end_online(); get_tree().reload_current_scene())
	box.add_child(leave)
	if App.online:
		var reconnect_button := Button.new()
		reconnect_button.text = "Reconectar"
		reconnect_button.pressed.connect(func():
			reconnect_button.disabled = true
			var reply: Dictionary = await App.reconnect()
			if reply.get("ok",false): online_world.entered(reply.data)
			else: message_label.text = App.error_message(reply.get("error","disconnected")); message_left = 5
			reconnect_button.disabled = false)
		box.add_child(reconnect_button)
	build_character_panel()
	inventory_ui = Control.new()
	inventory_ui.set_script(preload("res://scripts/inventory_ui.gd"))
	inventory_ui.character = App.character
	inventory_ui.changed.connect(inventory_changed)
	inventory_ui.drop_requested.connect(drop_item)
	hud.add_child(inventory_ui)
	inventory_ui.hide()
	shop_ui = Panel.new()
	shop_ui.set_script(preload("res://scripts/shop_ui.gd"))
	shop_ui.character = App.character
	shop_ui.requested.connect(transact)
	hud.add_child(shop_ui)
	quest_ui = preload("res://scripts/quest_ui.gd").new()
	quest_ui.character = App.character
	quest_ui.requested.connect(request_quest)
	hud.add_child(quest_ui)
	minimap = Control.new()
	minimap.set_script(preload("res://scripts/map_ui.gd"))
	minimap.world = self
	minimap.position = Vector2(528,10)
	minimap.size = Vector2(96,64)
	minimap.activated.connect(toggle_map)
	hud.add_child(minimap)
	map_panel = Control.new()
	map_panel.set_script(preload("res://scripts/map_ui.gd"))
	map_panel.world = self
	map_panel.expanded = true
	map_panel.position = Vector2(284,63)
	map_panel.size = Vector2(340,246)
	map_panel.activated.connect(toggle_map)
	hud.add_child(map_panel)
	map_panel.hide()
	chat_ui = Panel.new()
	chat_ui.set_script(preload("res://scripts/chat_ui.gd"))
	hud.add_child(chat_ui)
	if App.online:
		social_ui = preload("res://scripts/social_ui.gd").new()
		hud.add_child(social_ui)
		var social_button := Button.new()
		social_button.text = "P: jugadores"
		social_button.position = Vector2(528,80)
		social_button.size = Vector2(96,24)
		social_button.add_theme_font_size_override("font_size",10)
		social_button.pressed.connect(toggle_social)
		hud.add_child(social_button)
	var colors := [Color("b94c4c"),Color("487dbc"),Color("d5aa64")]
	var bars := [health_bar,mana_bar,experience_bar]
	for index in range(bars.size()):
		var bar: ProgressBar = bars[index]
		var background := StyleBoxFlat.new()
		background.bg_color = Color("111522")
		background.border_color = Color("796654")
		background.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = colors[index]
		bar.add_theme_stylebox_override("background",background)
		bar.add_theme_stylebox_override("fill",fill)
		bar.show_percentage = false
		bar.position = Vector2(16,62+index*8)
		bar.size = Vector2(180,5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(bar)
	# Control input follows tree order: windows must also be above HUD buttons.
	hud.move_child(shop_ui,hud.get_child_count()-1)
	hud.move_child(quest_ui,hud.get_child_count()-1)
	update_resources()

func toggle_map() -> void:
	if is_instance_valid(social_ui): social_ui.hide()
	map_panel.visible = not map_panel.visible
	inventory_ui.hide()
	character_panel.hide()
	shop_ui.hide()
	quest_ui.hide()
	held = false

func toggle_social() -> void:
	if not App.online: return
	chat_ui.hide(); chat_ui.input.release_focus()
	inventory_ui.hide(); character_panel.hide(); shop_ui.hide(); quest_ui.hide(); map_panel.hide()
	social_ui.toggle()
	held = false

func open_shop(npc: Node2D) -> void:
	if player.dead or player.position.distance_to(npc.position) > float(EterEconomy.rules().npc_range) or not combat.line_of_sight(npc.position): return
	active_npc = npc
	quest_ui.hide()
	if is_instance_valid(social_ui): social_ui.hide()
	shop_ui.shop_id = npc.shop_id
	shop_ui.refresh()
	shop_ui.show()
	inventory_ui.hide()
	character_panel.hide()
	map_panel.hide()
	held = false
	player.path.clear()

func request_quest(operation: String, id: String) -> bool:
	if operation not in ["quest_accept","quest_claim"] or quest_ui.busy or not quest_ui.visible or not is_instance_valid(active_npc) or player.dead:
		return false
	if player.position.distance_to(active_npc.position) > float(EterEconomy.rules().npc_range) or not combat.line_of_sight(active_npc.position):
		return false
	var definition: Dictionary = EterQuests.definitions().get(id,{})
	if definition.is_empty() or definition.npc != active_npc.shop_id or definition.map_id != map_id:
		return false
	quest_ui.busy = true
	quest_ui.refresh()
	var accepted := false
	if App.online:
		var reply: Dictionary = await App.send_intent(operation,{"quest_id":id})
		accepted = reply.get("ok",false)
	else:
		var error := EterQuests.claim(App.character,id) if operation == "quest_claim" else EterQuests.accept(App.character,id)
		accepted = error.is_empty()
		if accepted:
			inventory_changed()
			inventory_ui.refresh()
		else:
			message_label.text = App.error_message(error)
			message_left = 3
	quest_ui.busy = false
	quest_ui.refresh()
	return accepted

func transact(operation: String, value: String) -> bool:
	if not shop_ui.visible or not is_instance_valid(active_npc) or player.dead or player.position.distance_to(active_npc.position) > float(EterEconomy.rules().npc_range) or not combat.line_of_sight(active_npc.position):
		return false
	if operation == "quests":
		shop_ui.hide()
		quest_ui.open(active_npc.shop_id)
		return true
	if App.online:
		var data := {"definition":value,"shop_id":active_npc.shop_id} if operation == "buy" else {"uid":value,"shop_id":active_npc.shop_id} if operation == "sell" else {"uid":value}
		App.send_intent(operation,data)
		return true
	var accepted := false
	match operation:
		"buy": accepted = EterEconomy.buy(App.character,active_npc.shop_id,value)
		"sell": accepted = EterEconomy.sell(App.character,value)
		"repair": accepted = active_npc.shop_id == "smith" and EterEconomy.repair(App.character,value)
		"upgrade":
			if active_npc.shop_id == "smith":
				var result := EterInventory.upgrade(App.character,value,economy_random.randf())
				accepted = result.accepted
				if accepted:
					message_label.text = "Mejora exitosa" if result.success else "Mejora fallida: perdió un nivel"
	if accepted:
		inventory_changed()
		inventory_ui.refresh()
		shop_ui.refresh()
	else:
		message_label.text = "Operación rechazada: revisá oro, espacio o equipo"
	message_left = 3
	return accepted

func inventory_changed() -> void:
	if App.online:
		return
	App.character.stats = EterCharacter.derive(App.character)
	App.character.hp = mini(App.character.hp,App.character.stats.max_hp)
	App.character.mana = mini(App.character.mana,App.character.stats.max_mana)
	update_resources()
	player.update_equipment_visual()
	App.save_character()

func spawn_ground_item(item: Dictionary, point: Vector2) -> void:
	var ground := EterGroundItem.new()
	ground.item = item
	ground.position = point
	entities.add_child(ground)
	ground_items.append(ground)

func spawn_gold(amount: int, point: Vector2) -> void:
	if amount <= 0: return
	var ground := EterGroundItem.new()
	ground.gold = amount
	ground.position = point
	entities.add_child(ground)
	ground_items.append(ground)

func drop_item(uid: String) -> void:
	if App.online:
		App.send_intent("drop",{"uid":uid})
		return
	if player.dead:
		return
	var item := EterInventory.remove(App.character.inventory,uid)
	if not item.is_empty():
		spawn_ground_item(item,player.position)
		inventory_changed()
		inventory_ui.refresh()

func pickup_item(ground: EterGroundItem) -> bool:
	if not is_instance_valid(ground) or not ground_items.has(ground) or player.dead or player.position.distance_to(ground.position) > 48:
		return false
	if App.online:
		App.send_intent("pickup",{"ground_id":str(ground.get_meta("server_id",""))})
		return true
	if ground.gold > 0:
		if not EterEconomy.credit(App.character,ground.gold):
			message_label.text = "Límite de oro alcanzado"
			message_left = 3
			return false
	elif not EterInventory.add(App.character.inventory,ground.item):
		message_label.text = "Inventario lleno"
		message_left = 2
		return false
	ground_items.erase(ground)
	if ground.starter_reward:
		App.character.starter_ground_claimed = true
	ground.queue_free()
	inventory_changed()
	inventory_ui.refresh()
	return true

func build_character_panel() -> void:
	character_panel.position = Vector2(360, 63)
	character_panel.size = Vector2(264, 246)
	character_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("111522")
	panel_style.border_color = Color("796654")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(8)
	character_panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(character_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	character_panel.add_child(box)
	character_summary.add_theme_font_size_override("font_size", 11)
	character_summary.custom_minimum_size = Vector2(250, 94)
	character_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(character_summary)
	var names := {"strength":"Fuerza", "agility":"Agilidad", "vitality":"Vitalidad", "energy":"Energía"}
	for attribute in EterCharacter.definitions().attributes:
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = 208
		label.add_theme_font_size_override("font_size", 12)
		label.set_meta("display_name", names[attribute])
		row.add_child(label)
		attribute_labels[attribute] = label
		var button := Button.new()
		button.text = "+"
		button.add_theme_font_size_override("font_size", 12)
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("303b49")
		button_style.set_content_margin_all(2)
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("hover", button_style)
		button.add_theme_stylebox_override("pressed", button_style)
		button.add_theme_stylebox_override("disabled", button_style)
		button.custom_minimum_size = Vector2(34, 24)
		button.pressed.connect(func():
			if App.online:
				App.send_intent("allocate",{"attribute":attribute,"amount":1})
				return
			if EterProgression.allocate(App.character, attribute):
				update_resources())
		row.add_child(button)
		allocation_buttons[attribute] = button
	update_character_panel()

func update_character_panel() -> void:
	var character: Dictionary = App.character
	character_summary.text = "%s · Nivel %s\nPuntos disponibles: %s\nAtaque %s · Defensa %s\nPrecisión %s · Evasión %s\nVelocidad %s · Resets %s\nC: cerrar" % [character.name, character.level, character.attribute_points, character.stats.attack, character.stats.defense, character.stats.accuracy, character.stats.evasion, character.stats.speed, character.reset_count]
	for attribute in attribute_labels:
		attribute_labels[attribute].text = "%s: %s" % [attribute_labels[attribute].get_meta("display_name"), int(character.attributes[attribute])]
		allocation_buttons[attribute].disabled = character.attribute_points <= 0

func reward_monster(target: EterTrainingTarget) -> void:
	if App.online:
		return
	if not target is EterMonster:
		return
	var levels := EterProgression.gain_experience(App.character, int(target.config.experience))
	EterQuests.record_kill(App.character,target.species_id,map_id)
	if quest_ui.visible: quest_ui.refresh()
	var loot := EterEconomy.loot(target.species_id,economy_random)
	spawn_gold(loot.gold,target.position+Vector2(-16,0))
	for index in range(loot.items.size()):
		spawn_ground_item(loot.items[index],target.position+Vector2(16+index*24,0))
	App.save_character()
	message_label.text = "+%s XP%s" % [target.config.experience, " · ¡Nivel %s!" % App.character.level if levels > 0 else ""]
	message_left = 3
	update_resources()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and chat_ui.visible:
		chat_ui.hide()
		chat_ui.input.release_focus()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		pointer_position = event.position
	# Release still applies if a UI control consumes the mouse event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		held = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(social_ui) and social_ui.visible:
			social_ui.hide()
			return
		if quest_ui.visible:
			quest_ui.hide()
			return
		if map_panel.visible:
			map_panel.hide()
			return
		if shop_ui.visible:
			shop_ui.hide()
			return
		pause_menu.visible = not pause_menu.visible
		held = false
		return
	if pause_menu.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		toggle_social()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_map()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		if is_instance_valid(social_ui): social_ui.hide()
		quest_ui.hide()
		chat_ui.open()
		held = false
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if is_instance_valid(social_ui): social_ui.hide()
		shop_ui.hide()
		quest_ui.hide()
		map_panel.hide()
		character_panel.visible = not character_panel.visible
		inventory_ui.hide()
		held = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if is_instance_valid(social_ui): social_ui.hide()
		shop_ui.hide()
		quest_ui.hide()
		map_panel.hide()
		inventory_ui.visible = not inventory_ui.visible
		character_panel.hide()
		held = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1, KEY_2]:
		var index := 0 if event.keycode == KEY_1 else 1
		combat.cast(EterCombatRules.definitions().classes[App.class_id].skills[index])
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_position = event.position
		held = event.pressed
		if held:
			handle_primary(get_global_transform_with_canvas().affine_inverse() * pointer_position)

func handle_primary(point: Vector2) -> void:
	if player.dead or changing_map:
		return
	pending_pickup = null
	pending_npc = null
	pending_portal = null
	for portal in portals:
		if point.distance_to(portal.position) < 28:
			combat.select_target(null)
			if player.position.distance_to(portal.position)<=float(Catalog.read("maps").portal_range) and combat.line_of_sight(portal.position):
				travel(portal)
			else:
				pending_portal = portal
				player.move_to(portal.position)
			return
	for npc in npcs:
		if point.distance_to(npc.position+Vector2(0,-16)) < 24:
			combat.select_target(null)
			if player.position.distance_to(npc.position) <= float(EterEconomy.rules().npc_range) and combat.line_of_sight(npc.position):
				open_shop(npc)
			else:
				pending_npc = npc
				player.move_to(npc.position)
			return
	for ground in ground_items:
		if point.distance_to(ground.position) < 20:
			combat.select_target(null)
			if not pickup_item(ground):
				pending_pickup = ground
				player.move_to(ground.position)
			return
	for target in targets:
		if not target.dead and point.distance_to(target.position + Vector2(0,-16)) < 24:
			combat.select_target(target)
			return
	combat.select_target(null)
	set_destination(point)

func set_destination(point: Vector2) -> void:
	player.move_to(point)
	marker = player.destination
	queue_redraw()

func travel(portal: Node2D) -> void:
	if changing_map or player.dead or player.position.distance_to(portal.position)>float(Catalog.read("maps").portal_range) or not combat.line_of_sight(portal.position): return
	held = false
	pending_portal = null
	changing_map = true
	if App.online:
		# App outlives the scene that a successful transition replaces.
		App.travel_portal(portal.definition.id)
	else:
		App.character.map_id = portal.definition.target
		App.character.position = portal.definition.arrival.duplicate()
		map_changed.emit(App.character.map_id,Vector2(App.character.position.x,App.character.position.y))

func _process(delta: float) -> void:
	if changing_map: return
	if not App.online:
		App.character.map_id = map_id
		App.character.position = {"x":player.position.x,"y":player.position.y}
	if is_instance_valid(pending_portal) and player.position.distance_to(pending_portal.position)<=float(Catalog.read("maps").portal_range) and combat.line_of_sight(pending_portal.position):
		travel(pending_portal)
		return
	if is_instance_valid(pending_npc) and player.position.distance_to(pending_npc.position) <= float(EterEconomy.rules().npc_range) and combat.line_of_sight(pending_npc.position):
		open_shop(pending_npc)
		pending_npc = null
	if (shop_ui.visible or quest_ui.visible) and (player.dead or not is_instance_valid(active_npc) or player.position.distance_to(active_npc.position) > float(EterEconomy.rules().npc_range) or not combat.line_of_sight(active_npc.position)):
		shop_ui.hide()
		quest_ui.hide()
	save_tick += delta
	if save_tick >= 30:
		save_tick = 0
		App.save_character()
	if is_instance_valid(pending_pickup) and player.position.distance_to(pending_pickup.position) <= 48:
		pickup_item(pending_pickup)
		pending_pickup = null
	message_left -= delta
	if message_left <= 0:
		message_label.text = ""
	var skills: Array = EterCombatRules.definitions().classes[App.class_id].skills
	for index in range(skill_buttons.size()):
		var skill: Dictionary = EterCombatRules.definitions().skills[skills[index]]
		var cooldown := float(combat.cooldowns.get(skills[index], 0))
		skill_buttons[index].text = "%s %s%s" % [index + 1, skill.name, " · %ss" % ceili(cooldown) if cooldown > 0 else ""]
		skill_buttons[index].disabled = player.dead or cooldown > 0 or App.character.mana < skill.mana
	mouse_tick += delta
	if held and not pause_menu.visible and mouse_tick > 0.12:
		mouse_tick = 0
		handle_primary(get_global_transform_with_canvas().affine_inverse() * pointer_position)

func update_resources() -> void:
	resource_label.text = "%s · Nv %s · Vida %s/%s · Maná %s/%s" % [EterCharacter.definitions().classes[App.class_id].name, App.character.level, App.character.hp, App.character.stats.max_hp, App.character.mana, App.character.stats.max_mana]
	experience_label.text = "XP %s/%s · Puntos %s · Oro %s · C: personaje" % [App.character.experience, EterProgression.required_experience(App.character.level), App.character.attribute_points,App.character.gold]
	if not attribute_labels.is_empty():
		update_character_panel()
	health_bar.max_value = App.character.stats.max_hp
	health_bar.value = App.character.hp
	mana_bar.max_value = App.character.stats.max_mana
	mana_bar.value = App.character.mana
	experience_bar.max_value = EterProgression.required_experience(App.character.level)
	experience_bar.value = App.character.experience

func is_safe(point: Vector2, radius: float = 6.5) -> bool:
	if not Rect2(Vector2.ZERO,Vector2(SIZE)*TILE).has_point(point): return false
	for rect in solid_rectangles:
		var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		if point.distance_to(closest) < radius:
			return false
	return true

func _draw() -> void:
	if not terrain:
		return
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var tile := 0
			for region in geometry.regions:
				if Rect2i(int(region.x),int(region.y),int(region.width),int(region.height)).has_point(Vector2i(x,y)): tile = int(region.tile)
			draw_texture_rect_region(terrain, Rect2(x * TILE, y * TILE, TILE, TILE), Rect2(tile * TILE, 0, TILE, TILE))
	for entry in geometry.labels:
		draw_string(ThemeDB.fallback_font,Vector2(entry.x,entry.y),entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d5aa64"))
	if marker.x >= 0:
		draw_arc(marker, 8, 0, TAU, 12, Color("64c8cf"), 1)
		draw_line(marker + Vector2(-12, 0), marker + Vector2(12, 0), Color("64c8cf"))
