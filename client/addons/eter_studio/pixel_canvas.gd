@tool
extends Control
signal edited
signal picked(color: Color)
var bitmap := Image.create(16,16,false,Image.FORMAT_RGBA8)
var texture: ImageTexture
var zoom := 12
var grid := true
var tool := "Pencil"
var color := Color.WHITE
var drawing := false
var last := Vector2i(-1,-1)
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()

func refresh() -> void:
	texture = ImageTexture.create_from_image(bitmap)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(bitmap.get_size())*zoom
	queue_redraw()

func snapshot() -> void:
	undo_stack.append(bitmap.duplicate())
	while undo_stack.size()>64 or undo_stack.size()*bitmap.get_width()*bitmap.get_height()*4 > 32*1024*1024: undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(bitmap.duplicate()); bitmap = undo_stack.pop_back(); refresh(); edited.emit()
func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(bitmap.duplicate()); bitmap = redo_stack.pop_back(); refresh(); edited.emit()

func reset(width: int,height: int) -> void:
	snapshot(); bitmap = Image.create(width,height,false,Image.FORMAT_RGBA8); refresh(); edited.emit()

func resize_canvas(width: int,height: int) -> void:
	snapshot()
	var replacement := Image.create(width,height,false,Image.FORMAT_RGBA8)
	replacement.blit_rect(bitmap,Rect2i(Vector2i.ZERO,Vector2i(mini(width,bitmap.get_width()),mini(height,bitmap.get_height()))),Vector2i.ZERO)
	bitmap = replacement; refresh(); edited.emit()

func mirror(horizontal: bool) -> void:
	snapshot()
	if horizontal: bitmap.flip_x()
	else: bitmap.flip_y()
	refresh(); edited.emit()

func inside(point: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO,bitmap.get_size()).has_point(point)

func fill_at(point: Vector2i) -> void:
	if not inside(point): return
	var previous := bitmap.get_pixelv(point)
	if previous == color: return
	var stack: Array[Vector2i] = [point]
	while not stack.is_empty():
		var pixel: Vector2i = stack.pop_back()
		if not inside(pixel) or bitmap.get_pixelv(pixel) != previous: continue
		bitmap.set_pixelv(pixel,color)
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]: stack.append(pixel+direction)

func paint(point: Vector2i) -> void:
	if not inside(point): return
	if tool == "Color Picker": picked.emit(bitmap.get_pixelv(point)); return
	if tool == "Fill": fill_at(point)
	else:
		var distance := maxi(absi(point.x-last.x),absi(point.y-last.y)) if inside(last) else 0
		for step in range(distance+1):
			var pixel := Vector2i(Vector2(last).lerp(Vector2(point),float(step)/maxi(1,distance)).round()) if distance>0 else point
			if inside(pixel): bitmap.set_pixelv(pixel,Color.TRANSPARENT if tool == "Eraser" else color)
	last = point; refresh(); edited.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			last = Vector2i(-1,-1); drawing = true
			if tool != "Color Picker": snapshot()
			paint(Vector2i((event.position/zoom).floor()))
		else: drawing = false
		accept_event()
	elif event is InputEventMouseMotion and drawing and tool in ["Pencil","Eraser"]:
		paint(Vector2i((event.position/zoom).floor())); accept_event()

func _draw() -> void:
	var block := 1 if bitmap.get_width()*bitmap.get_height()<4096 else 8
	for y in range(0,bitmap.get_height(),block):
		for x in range(0,bitmap.get_width(),block):
			draw_rect(Rect2(Vector2(x,y)*zoom,Vector2(mini(block,bitmap.get_width()-x),mini(block,bitmap.get_height()-y))*zoom),Color("353b48") if (x/block+y/block)%2==0 else Color("242936"))
	if texture != null: draw_texture_rect(texture,Rect2(Vector2.ZERO,Vector2(bitmap.get_size())*zoom),false)
	if grid and zoom>=4:
		for x in range(bitmap.get_width()+1): draw_line(Vector2(x*zoom,0),Vector2(x*zoom,bitmap.get_height()*zoom),Color(0,0,0,0.25))
		for y in range(bitmap.get_height()+1): draw_line(Vector2(0,y*zoom),Vector2(bitmap.get_width()*zoom,y*zoom),Color(0,0,0,0.25))
