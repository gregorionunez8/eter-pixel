extends Control

signal activated
var world: Node2D
var expanded := false

func _ready() -> void:
	tooltip_text = "M: mapa · dorado: servicios · rojo: enemigos"
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		accept_event()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("111522"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("796654"),false)
	var inset := Vector2(8,24) if expanded else Vector2(4,4)
	var area := size-inset-Vector2(8,28) if expanded else size-inset*2
	var scale_factor := area / Vector2(world.SIZE*world.TILE)
	for y in range(world.SIZE.y):
		for x in range(world.SIZE.x):
			var color := Color("34413c")
			if (x >= 21 and x <= 26) or (y >= 16 and y <= 19): color = Color("796654")
			draw_rect(Rect2(inset+Vector2(x,y)*world.TILE*scale_factor,Vector2.ONE*world.TILE*scale_factor),color)
	for rect in world.solid_rectangles:
		draw_rect(Rect2(inset+rect.position*scale_factor,rect.size*scale_factor),Color("1c2229"))
	for npc in world.npcs:
		draw_circle(inset+npc.position*scale_factor,3 if expanded else 2,Color("d5aa64"))
	for target in world.targets:
		if target is EterMonster and not target.dead:
			draw_circle(inset+target.position*scale_factor,2 if expanded else 1,Color("b94c4c"))
	draw_circle(inset+world.player.position*scale_factor,3 if expanded else 2,Color("64c8cf"))
	if expanded:
		draw_string(ThemeDB.fallback_font,Vector2(10,16),"ALDEA DE ÉTER · M: cerrar",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d5aa64"))
		draw_string(ThemeDB.fallback_font,Vector2(10,size.y-10),"Vos · Servicios · Enemigos · Salida sur",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b4aca0"))
