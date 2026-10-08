class_name EterTrainingTarget
extends Node2D

var state: Dictionary = {}
var dead := false
var respawn_left := 0.0
var attack_left := 0.0
var sprite := Sprite2D.new()
var bar := ProgressBar.new()
var selected := false

func _ready() -> void:
	state = EterCombatRules.definitions().training_target.duplicate(true)
	sprite.texture = load("res://assets/training.png")
	sprite.position = Vector2(0, -18)
	add_child(sprite)
	bar.position = Vector2(-18, -49)
	bar.size = Vector2(36, 5)
	bar.show_percentage = false
	bar.max_value = state.stats.max_hp
	bar.value = state.hp
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var label := Label.new()
	label.text = "Efigie"
	label.position = Vector2(-28, -64)
	label.size.x = 56
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func refresh() -> void:
	bar.value = state.hp
	bar.visible = not dead
	if dead:
		sprite.scale.y = 0.25
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		sprite.scale.y = 1
		sprite.modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	if selected and not dead:
		draw_arc(Vector2.ZERO, 17, 0, TAU, 16, Color("df8667"), 1)
