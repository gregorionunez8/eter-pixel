extends Node2D

func _ready() -> void:
	var label := Label.new()
	label.text = "Aldea de Éter · fundaciones verificables"
	label.position = Vector2(180, 160)
	add_child(label)
