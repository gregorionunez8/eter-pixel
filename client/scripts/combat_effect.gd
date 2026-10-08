extends Node2D

var kind := "slash"
var color := Color("d5aa64")
var elapsed := 0.0
var duration := 0.45
var endpoint := Vector2.ZERO
var radius := 40.0

func _process(delta: float) -> void:
	elapsed += delta
	modulate.a = 1.0 - elapsed / duration
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0, 1)
	if kind in ["fire", "arrow"]:
		var point := endpoint * minf(1, progress * 2)
		draw_line(point - endpoint.normalized() * 12, point, color, 2)
		if kind == "fire":
			draw_circle(point, 4, color)
			draw_circle(point - Vector2(1,1), 2, Color("f4dc91"))
	elif kind in ["spin", "nova", "heal"]:
		draw_arc(Vector2.ZERO, maxf(2, radius * progress), 0, TAU, 24, color, 2)
		for index in range(8):
			var point := Vector2.from_angle(index * TAU / 8 + progress) * radius * progress
			draw_rect(Rect2(point, Vector2(2,2)), color)
	else:
		draw_arc(Vector2.ZERO, 18, -PI / 3 + progress, PI / 2 + progress, 9, color, 2)
