extends Node2D

const SIZE := Vector2i(48, 32)
const TILE := 32
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

func _ready() -> void:
	terrain = load("res://assets/terrain.png")
	entities.y_sort_enabled = true
	add_child(entities)
	for x in range(SIZE.x):
		add_obstacle(Rect2i(x, 0, 1, 1), "wall")
		if x < 21 or x > 26:
			add_obstacle(Rect2i(x, SIZE.y - 1, 1, 1), "wall")
	for y in range(1, SIZE.y - 1):
		add_obstacle(Rect2i(0, y, 1, 1), "wall")
		add_obstacle(Rect2i(SIZE.x - 1, y, 1, 1), "wall")
	for entry in [[15, 14, "house"], [17, 7, "house"], [29, 14, "shop"], [34, 18, "smith"], [17, 23, "house"], [29, 23, "house"]]:
		add_obstacle(Rect2i(entry[0], entry[1], 4, 3), entry[2])
	add_obstacle(Rect2i(23, 14, 2, 2), "shrine")
	for cell in [Vector2i(5,5),Vector2i(13,5),Vector2i(32,4),Vector2i(41,5),Vector2i(5,16),Vector2i(16,18),Vector2i(30,18),Vector2i(42,17),Vector2i(6,27),Vector2i(16,26),Vector2i(31,27),Vector2i(41,27)]:
		add_obstacle(Rect2i(cell, Vector2i.ONE), "tree")
	navigation.setup(SIZE, blocked)
	player = EterPlayer.new()
	player.navigation = navigation
	player.position = spawn_position
	entities.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = SIZE.x * TILE
	player.camera.limit_bottom = SIZE.y * TILE
	for x in [22, 24, 26]:
		var target := EterTrainingTarget.new()
		target.position = Vector2(x * TILE + 16, 27 * TILE + 16)
		entities.add_child(target)
		targets.append(target)
	combat.setup(self, player, targets)
	add_child(combat)
	combat.state_changed.connect(update_resources)
	combat.feedback.connect(func(message: String): message_label.text = message; message_left = 2.5)
	build_hud()
	var ambient := CanvasModulate.new()
	ambient.color = Color(0.83, 0.89, 0.96)
	add_child(ambient)
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
	location.text = "ALDEA DE ÉTER"
	location.position = Vector2(16, 10)
	location.add_theme_font_size_override("font_size", 14)
	location.modulate = Color("d5aa64")
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(location)
	resource_label.position = Vector2(16, 29)
	resource_label.add_theme_font_size_override("font_size", 11)
	resource_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(resource_label)
	update_resources()
	var help := Label.new()
	help.text = "Clic: caminar/atacar · 1/2: habilidades · Esc: menú"
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
	pause_menu.size = Vector2(200, 120)
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
	var leave := Button.new()
	leave.text = "Volver al inicio"
	leave.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(leave)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_position = event.position
	# Release still applies if a UI control consumes the mouse event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		held = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pause_menu.visible = not pause_menu.visible
		held = false
		return
	if pause_menu.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1, KEY_2]:
		var index := 0 if event.keycode == KEY_1 else 1
		combat.cast(EterCombatRules.definitions().classes[App.class_id].skills[index])
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_position = event.position
		held = event.pressed
		if held:
			handle_primary(get_global_transform_with_canvas().affine_inverse() * pointer_position)

func handle_primary(point: Vector2) -> void:
	if player.dead:
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

func _process(delta: float) -> void:
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

func is_safe(point: Vector2, radius: float = 6.5) -> bool:
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
			if (x >= 21 and x <= 26) or (y >= 16 and y <= 19):
				tile = 1
			if x >= 20 and x <= 27 and y >= 12 and y <= 20:
				tile = 2
			draw_texture_rect_region(terrain, Rect2(x * TILE, y * TILE, TILE, TILE), Rect2(tile * TILE, 0, TILE, TILE))
	draw_string(ThemeDB.fallback_font, Vector2(666, 951), "BOSQUE DE LAS SOMBRAS  ↓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d5aa64"))
	if marker.x >= 0:
		draw_arc(marker, 8, 0, TAU, 12, Color("64c8cf"), 1)
		draw_line(marker + Vector2(-12, 0), marker + Vector2(12, 0), Color("64c8cf"))
