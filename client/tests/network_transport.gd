extends SceneTree

var network = preload("res://scripts/network.gd").new()
var failed := false
var checks := 0
var role := 0
var suffix := ""
var url := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		printerr("FAIL network: " + message)

func wait_open() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not network.was_open and Time.get_ticks_msec() < deadline:
		await process_frame
	check(network.was_open,"connection opens")

func call_server(op: String, data: Dictionary = {}) -> Dictionary:
	var reply: Dictionary = await network.request(op,data)
	check(reply.get("ok",false),op + ": " + str(reply.get("error","")))
	return reply.get("data",{})

func run() -> void:
	var args := OS.get_cmdline_user_args()
	url = args[0]
	role = int(args[1])
	suffix = args[2]
	root.add_child(network)
	check(network.connect_server(url) == OK,"connect starts")
	await wait_open()
	var credentials := {"username":"godot_%d_%s" % [role,suffix],"password":"fixture-password"}
	await call_server("register",credentials)
	await call_server("login",credentials)
	var created := await call_server("create_character",{"name":"Red%d%s" % [role,suffix],"class_id":"warrior" if role == 0 else "mage"})
	var id: String = created.get("id","")
	var entered := await call_server("enter_world",{"character_id":id})
	check(entered.has("state") and entered.has("world"),"private state and public world")
	var destination := Vector2(848,592) if role == 0 else Vector2(784,656)
	await call_server("move",{"x":destination.x,"y":destination.y})
	var deadline := Time.get_ticks_msec() + 12000
	var both_arrived := false
	while Time.get_ticks_msec() < deadline:
		var arrived := 0
		for actor in network.latest_world.get("players",[]):
			var expected := destination if actor.id == id else (Vector2(784,656) if role == 0 else Vector2(848,592))
			if Vector2(actor.position.x,actor.position.y).distance_to(expected) < 2:
				arrived += 1
		both_arrived = arrived == 2
		if both_arrived:
			break
		await process_frame
	check(both_arrived,"two actual Godot clients observe both authoritative movements")
	check(network.latest_self.has("state"),"private self snapshot")
	var forbidden: Dictionary = await network.request("move",{"x":850,"y":592,"speed":999})
	check(not forbidden.get("ok",true),"server rejects extra speed")
	await create_timer(0.5).timeout
	network.close()
	while network.was_open:
		await process_frame
	await create_timer(0.5).timeout
	check(network.connect_server(url) == OK,"reconnect starts")
	await wait_open()
	await call_server("login",credentials)
	entered = await call_server("enter_world",{"character_id":id})
	if entered.has("state"):
		var pos: Dictionary = entered.state.position
		check(Vector2(pos.x,pos.y).distance_to(destination) < 2,"SQL saved position recovered")
	check(network.pending.is_empty(),"no unresolved requests")
	network.close()
	await create_timer(0.2).timeout
	network.queue_free()
	await process_frame
	if not failed:
		print("PASS Godot network transport: role%d %d checks" % [role,checks])
	quit(1 if failed else 0)
