extends Node

var settings := ConfigFile.new()
var environment: Dictionary = {}
var player_name := "Viajero"
var class_id := "warrior"
var character: Dictionary = {}
var persistence_enabled := true
var active_character := false
var online := false
var network: EterNetwork
var online_character_id := ""
var credentials: Dictionary = {}
var network_url := ""
signal intent_failed(message: String)
signal portal_result(success: bool)

func travel_portal(portal_id: String) -> void:
	var reply: Dictionary = await send_intent("portal",{"portal_id":portal_id})
	if reply.get("ok",false):
		network.latest_world = reply.data.world
		network.latest_self = {"state":reply.data.state,"cooldowns":reply.data.get("cooldowns",{}),"social":reply.data.get("social",{})}
		network.self_received.emit(network.latest_self)
	portal_result.emit(reply.get("ok",false))

func begin_connection(url: String) -> Error:
	if is_instance_valid(network):
		network.queue_free()
	network = EterNetwork.new()
	add_child(network)
	network_url = url
	return network.connect_server(url)

func send_intent(operation: String, data: Dictionary) -> Dictionary:
	var reply: Dictionary = await network.request(operation,data) if is_instance_valid(network) else {"ok":false,"error":"disconnected"}
	if not reply.get("ok",false):
		intent_failed.emit(error_message(reply.get("error","disconnected")))
	return reply

func error_message(code: String) -> String:
	var social_errors := {"party_unavailable":"No se puede invitar a ese jugador ahora.","trade_unavailable":"Acercate a un jugador vivo que no esté comerciando.","trade_revision":"La oferta cambió. Revisala antes de confirmar.","trade_missing":"El comercio se cerró o canceló.","equipped_offer":"Desequipá el objeto antes de ofrecerlo.","invalid_offer":"Revisá los objetos y el oro ofrecidos.","chat_rate":"Esperá un momento antes de enviar otro mensaje.","invalid_chat":"El mensaje está vacío, es demasiado largo o contiene saltos de línea."}
	if social_errors.has(code): return social_errors[code]
	var quest_errors := {"quest_not_ready":"El encargo aún no está listo o ya fue entregado.","quest_locked":"Completá primero el encargo anterior.","quest_already_accepted":"Este encargo ya fue aceptado.","npc_out_of_range":"Acercate al NPC correspondiente.","gold_cap":"Límite de oro alcanzado.","gold_limit":"Límite de oro alcanzado."}
	if quest_errors.has(code): return quest_errors[code]
	return {"disconnected":"Conexión perdida. Usá Reconectar en el menú.","timeout":"Sin respuesta. Revisá el estado antes de repetir.","insufficient_gold":"Oro insuficiente", "inventory_full":"Inventario lleno", "out_of_range":"Acercate al objetivo", "cooldown":"Habilidad en enfriamiento", "insufficient_mana":"Maná insuficiente", "character_in_use":"Personaje conectado; esperá el guardado", "invalid_credentials":"Cuenta o contraseña incorrecta", "persistence_failed":"No se pudo guardar. Operación rechazada."}.get(code,"Operación rechazada (%s)" % code)

func end_online() -> void:
	if is_instance_valid(network):
		network.close()
	online = false
	online_character_id = ""
	credentials.clear()
	active_character = false

func reconnect() -> Dictionary:
	if not online or not is_instance_valid(network):
		return {"ok":false,"error":"disconnected"}
	if network.was_open:
		return {"ok":false,"error":"already_connected"}
	if network.connect_server(network_url) != OK:
		return {"ok":false,"error":"connect_failed"}
	var deadline := Time.get_ticks_msec()+10000
	while not network.was_open and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var reply: Dictionary = await send_intent("login",credentials)
	if reply.get("ok",false):
		reply = await send_intent("enter_world",{"character_id":online_character_id})
	return reply

func _ready() -> void:
	settings.load("user://settings.cfg")
	var file := FileAccess.open("res://config/development.json", FileAccess.READ)
	if file:
		environment = JSON.parse_string(file.get_as_text())
	else:
		log_error("No se pudo cargar la configuración de entorno")
	apply_settings()
	character = EterCharacter.create(player_name, class_id)
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if "test_" in argument or "--capture" in argument or "--smoke" in argument:
			persistence_enabled = false

func save_character() -> void:
	if persistence_enabled and active_character and not online and not EterSave.save(character):
		log_error("No se pudo guardar el personaje local")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_character()

func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get_value("video", "fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(float(settings.get_value("audio", "volume", 0.7))))

func save_settings(fullscreen: bool, volume: float) -> void:
	settings.set_value("video", "fullscreen", fullscreen)
	settings.set_value("audio", "volume", volume)
	var result := settings.save("user://settings.cfg") if persistence_enabled else OK
	if result != OK:
		log_error("Error guardando configuración: %s" % result)
	apply_settings()

func log_error(message: String) -> void:
	push_error(message)
	var file := FileAccess.open("user://eter-errors.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://eter-errors.log") else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line("%s %s" % [Time.get_datetime_string_from_system(), message])
