@tool
extends Control
signal changed
signal selected(key: String,index: int)
var registry: RefCounted
var map: Dictionary = {}
var zoom := 0.5
var tool := "Select / Move"
var asset := "grass"
var content_id := ""
var layer := "Ground"
var cache: Dictionary = {}
var drag_key := ""
var drag_index := -1
var rectangle_start := Vector2(-1,-1)
const ARRAY_TOOLS := {"Spot":"monsters","NPC":"npcs","Portal":"portals","Player Spawn":"player_spawns","Safe Zone":"zones","PvP Zone":"zones","Audio Zone":"audio_zones"}
func configure(store: RefCounted,value: Dictionary) -> void:
	registry=store; map=value; refresh()
func refresh() -> void:
	custom_minimum_size=Vector2(float(map.get("width",48))*32,float(map.get("height",32))*32)*zoom; queue_redraw()
func asset_path(id: String) -> String:
	if id.begins_with("res://"): return id
	return str(registry.record("Assets",id).get("path","res://assets/"+id+".png"))
func texture(id: String) -> Texture2D:
	var file_path := asset_path(id)
	if not cache.has(file_path):
		var image := Image.new()
		cache[file_path]=ImageTexture.create_from_image(image) if image.load(ProjectSettings.globalize_path(file_path))==OK else null
	return cache[file_path]
func hit(point: Vector2) -> Dictionary:
	for key in ["monsters","npcs","portals","player_spawns","zones","audio_zones"]:
		for index in range(map.get(key,[]).size()-1,-1,-1):
			var entry: Dictionary=map[key][index]
			if key in ["zones","audio_zones"]:
				if Rect2(entry.x,entry.y,entry.get("width",96),entry.get("height",96)).has_point(point): return {"key":key,"index":index}
			elif point.distance_to(Vector2(entry.x,entry.y))<24: return {"key":key,"index":index}
	return {}
func unique_id(key: String) -> String:
	var index := 1
	while map.get(key,[]).any(func(entry): return entry.get("id","")==key+"_"+str(index)): index+=1
	return key+"_"+str(index)
func paint(point: Vector2) -> void:
	var cell := Vector2i((point/32).floor())
	if cell.x<0 or cell.y<0 or cell.x>=map.width or cell.y>=map.height: return
	if tool in ["Paint","Erase Paint"]:
		if not map.has("layers"): map.layers={}
		if not map.layers.has(layer): map.layers[layer]=[]
		var tiles: Array=map.layers[layer]
		for index in range(tiles.size()-1,-1,-1):
			if int(tiles[index].x)==cell.x and int(tiles[index].y)==cell.y: tiles.remove_at(index)
		if tool=="Paint": tiles.append({"x":cell.x,"y":cell.y,"texture":asset})
	elif tool in ["Collision","Erase Collision"]:
		var obstacles: Array=map.obstacles
		if tool=="Collision":
			if not obstacles.any(func(entry): return Rect2i(entry.x,entry.y,entry.width,entry.height).has_point(cell)): obstacles.append({"x":cell.x,"y":cell.y,"width":1,"height":1,"texture":""})
		else:
			for index in range(obstacles.size()-1,-1,-1):
				var entry: Dictionary=obstacles[index]
				if int(entry.width)==1 and int(entry.height)==1 and int(entry.x)==cell.x and int(entry.y)==cell.y: obstacles.remove_at(index)
	changed.emit(); registry.touch(); queue_redraw()
func place(point: Vector2) -> void:
	if not ARRAY_TOOLS.has(tool): return
	var key: String=ARRAY_TOOLS[tool]
	if not map.has(key): map[key]=[]
	var entry: Dictionary=preload("schema.gd").array_entry(key)
	entry.id=unique_id(key); entry.x=snappedf(point.x,16); entry.y=snappedf(point.y,16)
	if tool=="Spot": entry.species=content_id; entry.quantity=1; entry.spawn_radius=32; entry.walk_radius=96; entry.respawn=8; entry.enabled=true
	elif tool=="NPC": entry.npc_id=content_id
	elif tool=="Portal":
		entry.target=content_id
		if registry.records("Maps").has(content_id): entry.arrival=registry.record("Maps",content_id).spawn.duplicate()
	elif tool in ["Safe Zone","PvP Zone"]:
		entry.type="safe" if tool=="Safe Zone" else "pvp"; entry.width=96; entry.height=96
		entry.pvp_disabled=tool=="Safe Zone"; entry.monster_aggro_disabled=tool=="Safe Zone"; entry.town_status=tool=="Safe Zone"; entry.respawn_allowed=true
	map[key].append(entry); registry.touch(); changed.emit(); selected.emit(key,map[key].size()-1); queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var point: Vector2=event.position/zoom
		if event.pressed:
			if tool in ["Paint","Erase Paint","Collision","Erase Collision"]: paint(point); drag_key="paint"
			elif ARRAY_TOOLS.has(tool): place(point)
			else:
				var found := hit(point)
				if not found.is_empty(): drag_key=found.key; drag_index=found.index; selected.emit(drag_key,drag_index)
		else: drag_key=""; drag_index=-1
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		var point: Vector2=event.position/zoom
		if drag_key=="paint": paint(point)
		elif not drag_key.is_empty() and drag_index>=0:
			map[drag_key][drag_index].x=clampf(snappedf(point.x,16),0,float(map.width)*32-16)
			map[drag_key][drag_index].y=clampf(snappedf(point.y,16),0,float(map.height)*32-16)
			registry.touch(); changed.emit(); queue_redraw()
func _draw() -> void:
	if map.is_empty(): return
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	draw_rect(Rect2(Vector2.ZERO,custom_minimum_size),Color("273547"))
	var base := texture(str(map.get("terrain","terrain")))
	if base!=null:
		for y in range(int(map.height)):
			for x in range(int(map.width)): draw_texture_rect_region(base,Rect2(Vector2(x,y)*32*zoom,Vector2.ONE*32*zoom),Rect2(0,0,32,32))
	for layer_name in map.get("layers",{}):
		for cell in map.layers[layer_name]:
			var image := texture(str(cell.texture))
			if image!=null: draw_texture_rect(image,Rect2(Vector2(cell.x,cell.y)*32*zoom,Vector2.ONE*32*zoom),false)
	for obstacle in map.get("obstacles",[]):
		var area := Rect2(Vector2(obstacle.x,obstacle.y)*32*zoom,Vector2(obstacle.width,obstacle.height)*32*zoom)
		var image := texture(str(obstacle.texture))
		if image!=null: draw_texture_rect(image,area,false)
		draw_rect(area,Color(1,0.2,0.2,0.32))
	for key in ["zones","audio_zones"]:
		for entry in map.get(key,[]):
			var color := Color(0.15,0.8,0.35,0.25) if entry.get("type","safe")=="safe" else Color(0.95,0.3,0.2,0.25)
			if key=="audio_zones": color=Color(0.4,0.2,1,0.3)
			draw_rect(Rect2(Vector2(entry.x,entry.y)*zoom,Vector2(entry.get("width",96),entry.get("height",96))*zoom),color)
	for key in ["monsters","npcs","portals","player_spawns"]:
		for entry in map.get(key,[]):
			var point := Vector2(entry.x,entry.y)*zoom
			var color := Color.ORANGE if key=="monsters" else Color.CYAN if key=="portals" else Color.WHITE
			if key=="monsters":
				draw_arc(point,float(entry.get("walk_radius",96))*zoom,0,TAU,48,Color(1,0.6,0.2,0.5))
				draw_arc(point,float(entry.get("spawn_radius",16))*zoom,0,TAU,32,Color(1,0.2,0.2,0.7))
			draw_circle(point,6,color)
			draw_string(ThemeDB.fallback_font,point+Vector2(8,0),str(entry.get("species",entry.get("npc_id",entry.get("id","")))),HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
	draw_circle(Vector2(map.spawn.x,map.spawn.y)*zoom,5,Color.GREEN)
