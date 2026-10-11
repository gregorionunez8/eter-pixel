extends "res://tests/input_runtime.gd"
func _ready() -> void:
	var editor := preload("res://addons/eter_studio/asset_editor.gd").new()
	add_child(editor)
	await get_tree().process_frame
	var canvas = editor.canvas
	canvas.color=Color.RED; canvas.snapshot(); canvas.paint(Vector2i(2,3))
	if not check(canvas.bitmap.get_pixel(2,3)==Color.RED,"pencil draws an exact pixel"): await finish(); return
	canvas.undo()
	if not check(canvas.bitmap.get_pixel(2,3).a==0,"undo restores transparency"): await finish(); return
	canvas.redo(); canvas.mirror(true)
	if not check(canvas.bitmap.get_pixel(13,3)==Color.RED,"redo and horizontal mirror"): await finish(); return
	canvas.color=Color.BLUE; canvas.tool="Fill"; canvas.snapshot(); canvas.paint(Vector2i(0,0))
	if not check(canvas.bitmap.get_pixel(15,15)==Color.BLUE and canvas.bitmap.get_pixel(13,3)==Color.RED,"flood fill preserves boundaries"): await finish(); return
	canvas.resize_canvas(32,48)
	if not check(canvas.bitmap.get_size()==Vector2i(32,48) and canvas.bitmap.get_pixel(13,3)==Color.RED,"resize preserves pixels at native equipment dimensions"): await finish(); return
	canvas.tool="Eraser"; canvas.last=Vector2i(-1,-1); canvas.paint(Vector2i(13,3))
	if not check(canvas.bitmap.get_pixel(13,3).a==0,"eraser clears alpha"): await finish(); return
	var file_path := "res://../artifacts/studio-pixels.png"
	if not check(canvas.bitmap.save_png(file_path)==OK and editor.open_png(file_path),"PNG round trip without modifying source art"): await finish(); return
	var controlled := "res://assets/studio-acceptance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".png"
	var wrote: bool=editor.save_png(controlled)
	var exists := FileAccess.file_exists(controlled)
	if exists: DirAccess.remove_absolute(ProjectSettings.globalize_path(controlled))
	if not check(wrote and exists,"asset editor saves an actual controlled PNG and cleans only its unique test file"): await finish(); return
	if not check(not editor.save_png("user://outside.png"),"save rejects paths outside controlled assets"): await finish(); return
	print("PASS Studio assets: %d checks, pixel operations and PNG round trip" % checks)
	await finish()
