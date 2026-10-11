class_name EterAudio
extends Node
static var instance: EterAudio
var music_player := AudioStreamPlayer.new()
var ambient_player := AudioStreamPlayer.new()
var current_music := ""
var current_ambient := ""
var step_left := 0.0
var zone_id := ""
static func get_manager(tree: SceneTree) -> EterAudio:
	if not is_instance_valid(instance):
		instance=EterAudio.new(); tree.root.add_child.call_deferred(instance)
	return instance
func _ready() -> void:
	for name in ["Master","Music","Ambient","SFX","UI","Combat","Voice"]:
		if AudioServer.get_bus_index(name)<0:
			AudioServer.add_bus(); var index := AudioServer.bus_count-1; AudioServer.set_bus_name(index,name); AudioServer.set_bus_send(index,"Master")
	add_child(music_player); music_player.bus="Music"
	add_child(ambient_player); ambient_player.bus="Ambient"
func definition(id: String) -> Dictionary:
	return Catalog.read("audio").get("definitions",{}).get(id,{})
func stream(id: String) -> AudioStream:
	var entry := definition(id)
	if entry.is_empty() or str(entry.get("path","")).is_empty(): return null
	var resource: AudioStream=load(entry.path)
	return resource
func play(id: String,bus: String="SFX") -> void:
	if id.is_empty(): return
	var audio := stream(id)
	if audio==null: return
	var entry := definition(id)
	var player := AudioStreamPlayer.new(); player.stream=audio; player.bus=bus
	player.volume_db=linear_to_db(maxf(0.0001,float(entry.get("volume",1))))
	player.pitch_scale=maxf(0.05,float(entry.get("pitch",1)))
	add_child(player); player.finished.connect(player.queue_free); player.play()
func loop_track(player: AudioStreamPlayer,id: String,volume: float,fade: float) -> void:
	player.stop(); player.stream=stream(id)
	if player.stream==null: return
	if player.stream is AudioStreamWAV: player.stream=player.stream.duplicate(); player.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	elif player.stream is AudioStreamOggVorbis: player.stream=player.stream.duplicate(); player.stream.loop=true
	var target := linear_to_db(maxf(0.0001,volume*float(definition(id).get("volume",1))))
	player.volume_db=-60 if fade>0 else target; player.play()
	if fade>0: create_tween().tween_property(player,"volume_db",target,fade)
func update_world(map: Dictionary,point: Vector2,delta: float,moving: bool) -> void:
	var music := str(map.get("music","")); var ambient := str(map.get("ambient_sound",""))
	var selected: Dictionary={}; var next_zone := ""
	for zone in map.get("zones",[])+map.get("audio_zones",[]):
		if Rect2(zone.x,zone.y,zone.get("width",96),zone.get("height",96)).has_point(point) and int(zone.get("priority",0))>=int(selected.get("priority",-1)):
			selected=zone; next_zone=str(zone.get("id",""))
	if not selected.is_empty():
		music=str(selected.get("music",music)); ambient=str(selected.get("ambient_sound",ambient))
	if zone_id!=next_zone: play(str(selected.get("enter_sound","")),"Ambient"); zone_id=next_zone
	var volume := float(map.get("volume",1)); var fade := float(selected.get("fade_time",map.get("fade_duration",1)))
	if music!=current_music: current_music=music; loop_track(music_player,music,volume,fade)
	if ambient!=current_ambient: current_ambient=ambient; loop_track(ambient_player,ambient,volume,fade)
	step_left-=delta
	if moving and step_left<=0:
		step_left=0.35; var surface := "grass"
		var cell := Vector2i((point/32).floor())
		for layer in map.get("layers",{}).values():
			for tile in layer:
				if int(tile.x)==cell.x and int(tile.y)==cell.y: surface=str(Catalog.read("assets").definitions.get(tile.texture,{}).get("surface","grass"))
		play(str(Catalog.read("audio").get("footsteps",{}).get(surface,"")),"SFX")
