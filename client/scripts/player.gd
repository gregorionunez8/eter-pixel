class_name EterPlayer
extends CharacterBody2D

const SPEED := 112.0
var navigation: EterNavigation
var path := PackedVector2Array()
var destination := Vector2.ZERO
var sprite := Sprite2D.new()
var equipment_layers: Array[Sprite2D] = []
var animation_time := 0.0
var facing := 2
var frame := 0
var camera := Camera2D.new()
var dead := false
var replicated := false
var remote := false
var actor_class := ""
var actor_name := ""
var weapon_equipped := true
var server_position := Vector2.ZERO
var server_position_set := false
var name_label := Label.new()

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7
	collision.shape = shape
	add_child(collision)
	if actor_class.is_empty(): actor_class = App.class_id
	if actor_name.is_empty(): actor_name = App.player_name
	sprite.texture = load("res://assets/%s.png" % EterCharacter.definitions().classes[actor_class].sprite)
	sprite.hframes = 4
	sprite.vframes = 8
	sprite.position = Vector2(0, -18)
	add_child(sprite)
	update_equipment_visual()
	add_child(camera)
	camera.enabled = not remote
	camera.position_smoothing_enabled = false
	var label := name_label
	label.text = actor_name
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(-40, -52)
	label.size = Vector2(80, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	add_child(label)

func update_equipment_visual() -> void:
	var definition: Dictionary = EterCharacter.definitions().classes[actor_class if not actor_class.is_empty() else App.class_id]
	var equipped: bool = weapon_equipped if remote else App.character.inventory.equipment.has("weapon")
	var suffix := "" if equipped else "_unarmed"
	sprite.texture = load("res://assets/%s%s.png" % [definition.sprite,suffix])
	for layer in equipment_layers: layer.queue_free()
	equipment_layers.clear()
	if remote: return
	for uid in App.character.inventory.equipment.values():
		var item := EterInventory.find(App.character.inventory,uid)
		var visual: Dictionary=EterInventory.definitions().definitions[item.definition].get("equipped_visual",{})
		if str(visual.get("path","")).is_empty(): continue
		var layer := Sprite2D.new(); layer.texture=load(EterContent.asset_path(visual.path))
		layer.hframes=int(visual.get("hframes",1)); layer.vframes=int(visual.get("vframes",1))
		var offset: Array=visual.get("offset",[0,-18]); layer.position=Vector2(offset[0],offset[1])
		var dimensions: Array=visual.get("scale",[1,1]); layer.scale=Vector2(dimensions[0],dimensions[1])
		layer.z_index=int(visual.get("layer",1)); add_child(layer); equipment_layers.append(layer)

func move_to(point: Vector2) -> void:
	if App.online and not remote:
		destination = point
		App.send_intent("move",{"x":point.x,"y":point.y})
		return
	if not navigation:
		return
	if dead:
		return
	if not path.is_empty() and navigation.cell_at(point) == navigation.cell_at(destination):
		return
	var next_path := navigation.find_path(global_position, point)
	if not next_path.is_empty():
		if not path.is_empty() and next_path[next_path.size() - 1] == destination:
			return
		path = next_path
		destination = path[path.size() - 1]

func _physics_process(delta: float) -> void:
	if replicated:
		var old_position := position
		if server_position_set:
			var next := position.lerp(server_position,minf(1,delta*20))
			# Do not interpolate a shortcut through a solid at a path corner.
			var world := get_parent().get_parent()
			position = next if world.is_safe(next,7) else server_position
		velocity = (position-old_position)/delta
		animate(delta)
		sprite.modulate = Color(0.5,0.5,0.5,0.5) if dead else Color.WHITE
		sprite.scale.y = 0.25 if dead else 1.0
		return
	velocity = Vector2.ZERO
	if dead:
		return
	if not path.is_empty():
		var offset := path[0] - global_position
		if offset.length() < 1:
			path.remove_at(0)
		else:
			velocity = offset.normalized() * minf(float(App.character.stats.speed), offset.length() / delta)
	animate(delta)
	move_and_slide()

func animate(delta: float) -> void:
	if velocity.length_squared() > 0.1 and not dead:
		facing = posmod(roundi(velocity.angle() / (PI / 4)), 8)
		animation_time += delta
		frame = 1 + (int(animation_time * 8) % 3)
	else:
		frame = 0
		animation_time = 0
	sprite.frame = facing * 4 + frame
	for layer in equipment_layers:
		layer.frame=(facing*4+frame)%(layer.hframes*layer.vframes)
