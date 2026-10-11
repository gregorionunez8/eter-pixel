@tool
extends Control
var texture: Texture2D
var columns := 1
var rows := 1
var elapsed := 0.0
var animated := false
var label := ""
func _ready() -> void:
	custom_minimum_size=Vector2(170,160); texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	if animated: elapsed+=delta; queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("202735"))
	draw_string(ThemeDB.fallback_font,Vector2(8,18),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
	if texture==null: draw_string(ThemeDB.fallback_font,Vector2(8,45),"Sin asset personalizado",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.GRAY); return
	var dimensions := Vector2(texture.get_size())/Vector2(columns,rows)
	var frame := int(elapsed*8)%columns if animated else 0
	var scale := minf(3,minf((size.x-16)/dimensions.x,(size.y-32)/dimensions.y))
	draw_texture_rect_region(texture,Rect2(Vector2((size.x-dimensions.x*scale)/2,28),dimensions*scale),Rect2(Vector2(frame*dimensions.x,0),dimensions))
