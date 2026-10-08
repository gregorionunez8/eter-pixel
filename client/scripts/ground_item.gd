class_name EterGroundItem
extends Node2D

var item: Dictionary
var starter_reward := false

func _ready() -> void:
	var label := Label.new()
	label.text = EterInventory.definitions().definitions[item.definition].name
	label.position = Vector2(-60,-30)
	label.size.x = 120
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",9)
	label.modulate = EterItemVisual.color(item)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _draw() -> void:
	draw_arc(Vector2.ZERO,10,0,TAU,12,EterItemVisual.color(item),1)
	draw_texture(EterItemVisual.texture(item),Vector2(-8,-16))
