class_name EterMonster
extends EterTrainingTarget

signal phase_changed(value: String)

var species_id := "spider"
var spawn_overrides: Dictionary = {}
var config: Dictionary
var navigation: EterNavigation
var combat: Node
var player: EterPlayer
var home := Vector2.ZERO
var phase := "idle"
var path := PackedVector2Array()
var repath_left := 0.0
var detect_left := 0.0
var death_left := 0.0
var animation_time := 0.0

static func species() -> Dictionary:
	return Catalog.read("monsters").species

func initial_state() -> Dictionary:
	config = species()[species_id].duplicate(true)
	for pair in [["respawn","respawn"],["walk_radius","leash_radius"],["aggro_radius","detect_radius"]]:
		if spawn_overrides.has(pair[0]): config[pair[1]]=spawn_overrides[pair[0]]
	return {"hp": int(config.hp), "stats": {"max_hp": int(config.hp), "attack": config.attack, "defense": config.defense, "accuracy": config.accuracy, "evasion": config.evasion}}

func _ready() -> void:
	super._ready()
	home = position
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = config.radius
	collision.shape = shape
	add_child(collision)
	var visual: Dictionary=config.get("visual",{})
	sprite.texture = load(EterContent.asset_path(str(visual.get("path",species_id))))
	sprite.hframes = int(visual.get("hframes",4))
	sprite.vframes = int(visual.get("vframes",1))
	sprite.scale=Vector2.ONE*float(visual.get("scale",1))
	var height := float(sprite.texture.get_height())/sprite.vframes
	var pivot: Array=visual.get("pivot",[0,6])
	sprite.position = Vector2(float(pivot[0]), -height / 2 + float(pivot[1]))
	bar.position.y = -height - 3
	name_label.position = Vector2(-65, -height - 17)
	name_label.size.x = 130
	name_label.text = "%s · %s" % [config.name, int(config.level)]

func change_phase(value: String) -> void:
	if phase != value:
		phase = value
		phase_changed.emit(value)
		if value=="detect": play_sound("aggro")

func visible_player() -> bool:
	if EterContent.prevents_aggro(combat.world.geometry,player.position): return false
	var query := PhysicsRayQueryParameters2D.create(position, player.position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func on_hit() -> void:
	play_sound("hit")
	if phase == "idle":
		change_phase("detect")
		detect_left = 0.15

func on_defeated() -> void:
	play_sound("death")
	path.clear()
	velocity = Vector2.ZERO
	respawn_left = config.respawn
	death_left = 0.5
	change_phase("dying")

func follow(point: Vector2, delta: float) -> void:
	repath_left -= delta
	if repath_left <= 0:
		repath_left = 0.3
		var next_path := navigation.find_path(position, point)
		if path.is_empty() or next_path.is_empty() or path[path.size()-1] != next_path[next_path.size()-1]:
			path = next_path
	if not path.is_empty():
		var offset := path[0] - position
		if offset.length() < 1:
			path.remove_at(0)
		else:
			velocity = offset.normalized() * minf(config.speed, offset.length() / delta)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not navigation:
		return
	velocity = Vector2.ZERO
	attack_left = maxf(0, attack_left - delta)
	if dead:
		respawn_left -= delta
		death_left -= delta
		if death_left <= 0:
			change_phase("respawn")
		if respawn_left <= 0:
			dead = false
			position = home
			state.hp = state.stats.max_hp
			change_phase("idle")
			refresh()
		return
	var distance := position.distance_to(player.position)
	if phase in ["detect", "chase", "attack"] and (player.dead or EterContent.prevents_aggro(combat.world.geometry,player.position) or home.distance_to(player.position) > float(config.leash_radius) or home.distance_to(position) > float(config.leash_radius)):
		change_phase("return")
		repath_left = 0
	match phase:
		"idle":
			if not player.dead and distance <= float(config.detect_radius) and visible_player():
				change_phase("detect")
				detect_left = 0.15
		"detect":
			detect_left -= delta
			if detect_left <= 0:
				change_phase("chase")
				repath_left = 0
		"chase":
			if distance <= float(config.attack_range) and visible_player():
				path.clear()
				change_phase("attack")
			else:
				follow(player.position, delta)
		"attack":
			if distance > float(config.attack_range) or not visible_player():
				change_phase("chase")
				repath_left = 0
			elif attack_left <= 0 and is_instance_valid(combat):
				attack_left = config.attack_interval
				play_sound("attack")
				var attack: Dictionary=state.stats.duplicate()
				if config.has("damage_min"): attack.attack=combat.random.randi_range(int(config.damage_min),int(config.damage_max))
				combat.receive_damage(attack)
		"return":
			if position.distance_to(home) < 2:
				position = home
				path.clear()
				state.hp = state.stats.max_hp
				refresh()
				change_phase("idle")
			else:
				follow(home, delta)
	move_and_slide()
	if velocity.length_squared() > 0.1:
		animation_time += delta
		sprite.frame = mini(sprite.hframes*sprite.vframes-1,1 + int(animation_time * 7) % 3)
		sprite.flip_h = velocity.x < 0
	else:
		sprite.frame = 0
	var frames := animation_frames()
	if not frames.is_empty():
		animation_time+=delta if velocity.length_squared()<=0.1 else 0
		sprite.frame=clampi(int(frames[int(animation_time*7)%frames.size()]),0,sprite.hframes*sprite.vframes-1)

func play_sound(event: String) -> void:
	EterAudio.get_manager(get_tree()).play(str(config.get("audio",{}).get(event+"_sound","")),"Combat")

func animation_frames() -> Array:
	var key := "death" if phase=="dying" else "attack" if phase=="attack" else "walk" if velocity.length_squared()>0.1 else "idle"
	return config.get("visual",{}).get("animation_mapping",{}).get(key,[])
