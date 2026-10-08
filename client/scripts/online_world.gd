extends Node

var world: Node2D
var remotes: Dictionary = {}
var enemies: Dictionary = {}
var grounds: Dictionary = {}
var event_sequence := 0
var inventory_signature := ""
var chat_sequence := 0

func _ready() -> void:
	for target in world.targets:
		enemies[target.get_meta("server_id")] = target
	App.network.snapshot_received.connect(apply_snapshot)
	App.network.self_received.connect(apply_self)
	App.network.disconnected.connect(connection_lost)
	App.intent_failed.connect(show_error)
	App.network.chat_received.connect(receive_chat)
	world.chat_ui.connected = App.network.was_open
	world.chat_ui.submitted.connect(func(channel: String,message: String): App.send_intent("chat",{"channel":channel,"message":message}))
	entered({"state":App.character.duplicate(true),"world":App.network.latest_world})

func show_error(message: String) -> void:
	world.message_label.text = message
	world.message_left = 5

func connection_lost() -> void:
	world.chat_ui.connected = false
	chat_sequence = 0
	world.social_ui.hide()
	world.held = false
	world.pending_pickup = null
	world.pending_npc = null
	show_error(App.error_message("disconnected"))

func receive_chat(message: Dictionary) -> void:
	if int(message.sequence) <= chat_sequence: return
	chat_sequence = int(message.sequence)
	world.chat_ui.append_message("%s · %s" % ["Global" if message.channel == "global" else "Local",message.sender],message.message)

func entered(data: Dictionary) -> void:
	world.message_label.text = ""
	world.message_left = 0
	event_sequence = 0
	for event in data.get("world",{}).get("events",[]):
		event_sequence = maxi(event_sequence,int(event.sequence))
	apply_self({"state":data.state,"cooldowns":{}})
	var point: Dictionary = data.state.position
	world.player.position = Vector2(point.x,point.y)
	world.player.server_position = world.player.position
	world.player.server_position_set = true
	apply_snapshot(data.get("world",{}))

func apply_self(data: Dictionary) -> void:
	if not data.has("state"): return
	var state: Dictionary = normalize_numbers(data.state)
	# Preserve Dictionary identity shared with inventory/shop widgets.
	App.character.clear()
	App.character.merge(state,true)
	world.player.dead = App.character.hp <= 0
	world.combat.cooldowns = data.get("cooldowns",{}).duplicate()
	world.update_resources()
	world.chat_ui.connected = App.network.was_open
	world.social_ui.refresh(data.get("social",{}))
	var signature := JSON.stringify([App.character.inventory,App.character.gold])
	if signature != inventory_signature:
		inventory_signature = signature
		world.inventory_ui.refresh()
		if world.shop_ui.visible: world.shop_ui.refresh()
		world.player.update_equipment_visual()

func normalize_numbers(value: Variant) -> Variant:
	# Godot JSON numbers arrive as floats; keep whole RPG values readable.
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = normalize_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value: result.append(normalize_numbers(entry))
		return result
	if value is float and value == floor(value): return int(value)
	return value

func apply_snapshot(data: Dictionary) -> void:
	var present: Dictionary = {}
	for state in data.get("players",[]):
		var actor: EterPlayer
		if state.id == App.online_character_id:
			actor = world.player
		else:
			present[state.id] = true
			if not remotes.has(state.id):
				actor = EterPlayer.new()
				actor.remote = true
				actor.replicated = true
				actor.actor_class = state.class_id
				actor.actor_name = state.name
				actor.position = Vector2(state.position.x,state.position.y)
				world.entities.add_child(actor)
				remotes[state.id] = actor
			actor = remotes[state.id]
		actor.server_position = Vector2(state.position.x,state.position.y)
		actor.server_position_set = true
		actor.dead = state.hp <= 0
		if actor.remote:
			actor.weapon_equipped = state.get("weapon_equipped",true)
			actor.update_equipment_visual()
			actor.name_label.text = "%s · Nv%s\n%s/%s" % [state.name,int(state.level),int(state.hp),int(state.get("max_hp",state.hp))]
			actor.name_label.position.y = -65
			actor.name_label.position.x = -60
			actor.name_label.size = Vector2(120,30)
	for id in remotes.keys():
		if not present.has(id):
			remotes[id].queue_free()
			remotes.erase(id)
	for state in data.get("enemies",[]):
		if not enemies.has(state.id): continue
		var target: EterTrainingTarget = enemies[state.id]
		var previous := target.position
		target.position = Vector2(state.position.x,state.position.y)
		target.state.hp = int(state.hp)
		target.state.stats.max_hp = int(state.max_hp)
		target.bar.max_value = state.max_hp
		target.dead = state.hp <= 0
		if target is EterMonster:
			target.phase = state.phase
			target.sprite.frame = 1 + (int(Time.get_ticks_msec()/125) % 3) if previous.distance_to(target.position)>0.1 else 0
		target.refresh()
		if target.dead and world.combat.selected == target:
			world.combat.selected = null
			target.selected = false
	var ground_present: Dictionary = {}
	for state in data.get("ground",[]):
		ground_present[state.id] = true
		if grounds.has(state.id): continue
		var ground := EterGroundItem.new()
		ground.item = state.get("item",{})
		ground.gold = int(state.get("gold",0))
		ground.position = Vector2(state.position.x,state.position.y)
		ground.set_meta("server_id",state.id)
		world.entities.add_child(ground)
		world.ground_items.append(ground)
		grounds[state.id] = ground
	for id in grounds.keys():
		if not ground_present.has(id):
			var ground: EterGroundItem = grounds[id]
			world.ground_items.erase(ground)
			if world.pending_pickup == ground: world.pending_pickup = null
			ground.queue_free()
			grounds.erase(id)
	for event in data.get("events",[]):
		if int(event.sequence) <= event_sequence: continue
		event_sequence = int(event.sequence)
		if event.kind == "hit":
			var point := Vector2(event.position.x,event.position.y)
			world.combat.damage_label(point,event)
			var origin := point
			if event.actor == App.online_character_id: origin = world.player.position
			elif remotes.has(event.actor): origin = remotes[event.actor].position
			elif enemies.has(event.actor): origin = enemies[event.actor].position
			world.combat.spawn_effect(event.effect,origin,point)
		elif event.kind == "skill":
			var skill: Dictionary = EterCombatRules.definitions().skills[event.skill]
			if skill.mode in ["area","heal"]:
				var point := Vector2(event.position.x,event.position.y)
				world.combat.spawn_effect(skill.effect,point,point,float(skill.get("range",34)))
		elif event.kind == "defeated" and event.killer == App.online_character_id:
			show_error("+%s XP" % int(event.experience))
