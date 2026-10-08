extends Node2D

var shop_id := "shop"

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/%s_unarmed.png" % ("mage" if shop_id == "shop" else "warrior"))
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0,0,32,48)
	sprite.position.y = -20
	sprite.modulate = Color("d5aa64") if shop_id == "smith" else Color("82bf85")
	add_child(sprite)
	var label := Label.new()
	label.text = EterEconomy.rules().shops[shop_id].name.split(" · ")[0]
	label.position = Vector2(-30,-54)
	label.size.x = 60
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",10)
	label.modulate = Color("d5aa64")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
