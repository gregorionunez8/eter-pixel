class_name EterGroundItem
extends Node2D

var item: Dictionary
var gold := 0
var starter_reward := false

func _ready() -> void:
	var label := Label.new()
	label.text = "%s oro" % gold if gold > 0 else EterInventory.definitions().definitions[item.definition].name
	label.position = Vector2(-60,-30)
	label.size.x = 120
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",9)
	label.modulate = Color("d5aa64") if gold > 0 else EterItemVisual.color(item)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _draw() -> void:
	if gold > 0:
		draw_circle(Vector2(0,-5),5,Color("796654"))
		draw_circle(Vector2(-2,-8),4,Color("d5aa64"))
		draw_line(Vector2(-2,-11),Vector2(-2,-5),Color("f1d59d"),1)
	else:
		draw_arc(Vector2.ZERO,10,0,TAU,12,EterItemVisual.color(item),1)
		draw_texture(EterItemVisual.texture(item,true),Vector2(-8,-16))
