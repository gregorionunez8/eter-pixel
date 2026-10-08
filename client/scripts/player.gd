class_name EterPlayer
extends CharacterBody2D

const SPEED := 112.0
var navigation: EterNavigation
var path := PackedVector2Array()
var destination := Vector2.ZERO
var sprite := Sprite2D.new()
var animation_time := 0.0
var facing := 2
var frame := 0
var camera := Camera2D.new()

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7
	collision.shape = shape
	add_child(collision)
	sprite.texture = load("res://assets/traveler.png")
	sprite.hframes = 4
	sprite.vframes = 8
	sprite.position = Vector2(0, -18)
	add_child(sprite)
	add_child(camera)
	camera.position_smoothing_enabled = false
	var label := Label.new()
	label.text = App.player_name
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(-40, -52)
	label.size = Vector2(80, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func move_to(point: Vector2) -> void:
	if not navigation:
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
	velocity = Vector2.ZERO
	if not path.is_empty():
		var offset := path[0] - global_position
		if offset.length() < 1:
			path.remove_at(0)
		else:
			velocity = offset.normalized() * minf(SPEED, offset.length() / delta)
	if velocity.length_squared() > 0.1:
		facing = posmod(roundi(velocity.angle() / (PI / 4)), 8)
		animation_time += delta
		frame = 1 + (int(animation_time * 8) % 3)
	else:
		frame = 0
		animation_time = 0
	move_and_slide()
	sprite.frame = facing * 4 + frame
