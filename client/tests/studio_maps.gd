extends "res://tests/input_runtime.gd"
func _ready() -> void:
	var registry := preload("res://addons/eter_studio/registry.gd").new()
	var editor := preload("res://addons/eter_studio/map_editor.gd").new()
	var map: Dictionary=registry.record("Maps","village").duplicate(true)
	editor.open(registry,map); add_child(editor)
	await get_tree().process_frame
	var canvas=editor.canvas
	canvas.tool="Paint"; canvas.asset="grass"; canvas.paint(Vector2(64,96))
	if not check(map.layers.Ground.size()==1 and map.layers.Ground[0].x==2,"paint uses mouse coordinates and tile scale"): await finish(); return
	canvas.tool="Erase Paint"; canvas.paint(Vector2(64,96))
	if not check(map.layers.Ground.is_empty(),"erase painted tile"): await finish(); return
	canvas.tool="Spot"; canvas.content_id="wolf"; var before: int=map.monsters.size(); canvas.place(Vector2(320,320))
	if not check(map.monsters.size()==before+1 and map.monsters.back().species=="wolf" and canvas.hit(Vector2(320,320)).key=="monsters","spot placement and hit selection"): await finish(); return
	canvas.tool="NPC"; canvas.content_id="shop"; canvas.place(Vector2(352,320))
	if not check(map.npcs.back().npc_id=="shop","NPC definition is referenced, not copied"): await finish(); return
	canvas.tool="Safe Zone"; canvas.place(Vector2(400,400))
	if not check(map.zones.back().type=="safe" and map.zones.back().monster_aggro_disabled,"visual safe zone placement"): await finish(); return
	canvas.tool="Portal"; canvas.content_id="forest"; canvas.place(Vector2(500,500))
	if not check(map.portals.back().target=="forest" and map.portals.back().arrival==registry.record("Maps","forest").spawn,"portal destination selector uses map spawn"): await finish(); return
	for id in ["village","forest","crypt"]:
		canvas.configure(registry,registry.record("Maps",id))
		if not check(canvas.custom_minimum_size==Vector2(768,512),"existing map "+id+" opens at original tile scale"): await finish(); return
	print("PASS Studio maps: %d checks, visual painting and placements without source changes" % checks)
	await finish()
