class_name EterCombat
extends Node

signal state_changed
signal feedback(message: String)
signal hit_resolved(target: Node2D, result: Dictionary)
signal target_defeated(target: EterTrainingTarget)

var player: EterPlayer
var world: Node2D
var targets: Array[EterTrainingTarget] = []
var selected: EterTrainingTarget
var cooldowns: Dictionary = {}
var auto_left := 0.0
var chase_left := 0.0
var respawn_left := 0.0
var regen_left := 0.0
var since_damage := 0.0
var random := RandomNumberGenerator.new()

func setup(owner_world: Node2D, actor: EterPlayer, training_targets: Array[EterTrainingTarget]) -> void:
	world = owner_world
	player = actor
	targets = training_targets
	random.randomize()

func select_target(target: EterTrainingTarget) -> void:
	if selected == target:
		return
	if is_instance_valid(selected):
		selected.selected = false
		selected.queue_redraw()
	selected = target
	if is_instance_valid(selected):
		selected.selected = true
		selected.queue_redraw()

func line_of_sight(target_position: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target_position, 1)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func spawn_effect(kind: String, origin: Vector2, end: Vector2, radius: float = 40) -> void:
	var effect := Node2D.new()
	effect.set_script(preload("res://scripts/combat_effect.gd"))
	effect.kind = kind
	effect.position = origin
	effect.endpoint = end - origin
	effect.radius = radius
	effect.color = Color("dd7044") if kind == "fire" else Color("64c8cf") if kind == "nova" else Color("82bf85") if kind == "heal" else Color("d5aa64")
	world.add_child(effect)

func damage_label(point: Vector2, hit_result: Dictionary) -> void:
	var label := Label.new()
	label.text = "Fallo" if hit_result.miss else "%s%s" % [hit_result.damage, "!" if hit_result.critical else ""]
	label.position = point + Vector2(-10,-45)
	label.add_theme_font_size_override("font_size", 14 if hit_result.critical else 11)
	label.modulate = Color("d5aa64") if hit_result.critical else Color("eeeecc")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)

func damage_target(target: EterTrainingTarget, multiplier: float, damage_type: String, effect: String) -> void:
	if target.dead:
		return
	var hit_result := EterCombatRules.hit(App.character.stats, target.state.stats, damage_type, multiplier, random.randf(), random.randf())
	target.state.hp = maxi(0, target.state.hp - int(hit_result.damage))
	damage_label(target.position, hit_result)
	spawn_effect(effect, player.position if effect in ["fire", "arrow"] else target.position, target.position)
	if target.state.hp == 0:
		target.dead = true
		target.respawn_left = EterCombatRules.definitions().target_respawn_seconds
		if selected == target:
			select_target(null)
		if target.has_method("on_defeated"):
			target.on_defeated()
		target_defeated.emit(target)
	elif hit_result.damage > 0 and target.has_method("on_hit"):
		target.on_hit()
	target.refresh()
	hit_resolved.emit(target, hit_result)
	state_changed.emit()

func receive_damage(attack_stats: Dictionary) -> void:
	if player.dead:
		return
	var hit_result := EterCombatRules.hit(attack_stats, App.character.stats, "physical", 1, random.randf(), random.randf())
	App.character.hp = maxi(0, App.character.hp - int(hit_result.damage))
	if not hit_result.miss:
		since_damage = 0
	damage_label(player.position, hit_result)
	if App.character.hp == 0:
		EterProgression.death_penalty(App.character)
		player.dead = true
		player.path.clear()
		player.sprite.scale.y = 0.25
		player.sprite.modulate = Color(0.5,0.5,0.5,0.6)
		respawn_left = EterCombatRules.definitions().player_respawn_seconds
		select_target(null)
		feedback.emit("Has caído. La piedra de Éter te llama…")
	state_changed.emit()

func cast(skill_id: String) -> bool:
	var rules := EterCombatRules.definitions()
	if player.dead or not skill_id in rules.classes[App.class_id].skills:
		return false
	var skill: Dictionary = rules.skills[skill_id]
	if float(cooldowns.get(skill_id, 0)) > 0:
		feedback.emit("Habilidad en enfriamiento")
		return false
	if App.character.mana < skill.mana:
		feedback.emit("Maná insuficiente")
		return false
	var victims: Array[EterTrainingTarget] = []
	if skill.mode == "single":
		if not is_instance_valid(selected) or selected.dead or player.position.distance_to(selected.position) > float(skill.range) or not line_of_sight(selected.position):
			feedback.emit("Seleccioná un objetivo dentro de rango")
			return false
		victims.append(selected)
	elif skill.mode in ["area", "multiple"]:
		for target in targets:
			if not target.dead and player.position.distance_to(target.position) <= float(skill.range) and line_of_sight(target.position):
				victims.append(target)
		if victims.is_empty():
			feedback.emit("No hay objetivos en rango")
			return false
		if skill.mode == "multiple":
			victims.resize(mini(victims.size(), int(skill.max_targets)))
	App.character.mana -= int(skill.mana)
	cooldowns[skill_id] = float(skill.cooldown)
	if skill.mode == "heal":
		App.character.hp = mini(App.character.stats.max_hp, App.character.hp + floori(App.character.stats.max_hp * float(skill.heal_fraction)))
		spawn_effect("heal", player.position, player.position, 34)
	elif skill.mode == "area":
		spawn_effect(skill.effect, player.position, player.position, skill.range)
	for victim in victims:
		damage_target(victim, skill.multiplier, skill.damage_type, skill.effect)
	state_changed.emit()
	return true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var rules := EterCombatRules.definitions()
	auto_left = maxf(0, auto_left - delta)
	chase_left = maxf(0, chase_left - delta)
	for key in cooldowns:
		cooldowns[key] = maxf(0, float(cooldowns[key]) - delta)
	for target in targets:
		if target is EterMonster:
			continue
		if target.dead:
			target.respawn_left -= delta
			if target.respawn_left <= 0:
				target.dead = false
				target.state.hp = target.state.stats.max_hp
				target.refresh()
		else:
			target.attack_left = maxf(0, target.attack_left - delta)
			if selected == target and not player.dead and target.attack_left <= 0 and player.position.distance_to(target.position) <= float(target.state.retaliation_range) and line_of_sight(target.position):
				target.attack_left = target.state.retaliation_interval
				receive_damage(target.state.stats)
	if player.dead:
		respawn_left -= delta
		if respawn_left <= 0:
			player.dead = false
			player.position = world.spawn_position
			player.sprite.scale.y = 1
			player.sprite.modulate = Color.WHITE
			App.character.hp = App.character.stats.max_hp
			App.character.mana = App.character.stats.max_mana
			state_changed.emit()
		return
	since_damage += delta
	regen_left += delta
	if regen_left >= float(rules.regeneration_interval):
		regen_left = 0
		if since_damage >= float(rules.regeneration_delay):
			App.character.hp = mini(App.character.stats.max_hp, App.character.hp + maxi(1, floori(App.character.stats.max_hp * float(rules.hp_regeneration_fraction))))
			App.character.mana = mini(App.character.stats.max_mana, App.character.mana + maxi(1, floori(App.character.stats.max_mana * float(rules.mana_regeneration_fraction))))
			state_changed.emit()
	if not is_instance_valid(selected) or selected.dead:
		return
	var definition: Dictionary = rules.classes[App.class_id]
	if player.position.distance_to(selected.position) <= float(definition.auto_range) and line_of_sight(selected.position):
		player.path.clear()
		if auto_left <= 0:
			auto_left = definition.auto_interval
			damage_target(selected, 1, App.character.stats.damage_type, "fire" if App.class_id == "mage" else "arrow" if App.class_id == "elf" else "slash")
	elif chase_left <= 0:
		chase_left = 0.3
		player.move_to(selected.position)
