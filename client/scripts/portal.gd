extends Node2D

var definition: Dictionary = {}
var sprite := Sprite2D.new()

func _ready() -> void:
	sprite.texture = load("res://assets/portal.png")
	sprite.position = Vector2(0,-16)
	add_child(sprite)
	var label := Label.new()
	label.text = str(definition.get("name","Portal → "+str(definition.get("target",""))))
	label.position = Vector2(-90,-64)
	label.size.x = 180
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",11)
	label.modulate = Color("64c8cf")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	add_child(label)

func _process(_delta: float) -> void:
	sprite.modulate = Color(0.75+sin(Time.get_ticks_msec()/500.0)*0.15,1,1)
