class_name EterNetwork
extends Node

signal connected
signal disconnected
signal snapshot_received(state: Dictionary)
signal self_received(state: Dictionary)

var peer := WebSocketPeer.new()
var latest_world: Dictionary = {}
var latest_self: Dictionary = {}
var pending: Dictionary = {}
var sequence := 0
var was_open := false
var connecting := false
var connect_deadline := 0

func connect_server(url: String) -> Error:
	if connecting or peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return ERR_ALREADY_IN_USE
	latest_world.clear()
	latest_self.clear()
	peer = WebSocketPeer.new()
	var result := peer.connect_to_url(url)
	connecting = result == OK
	connect_deadline = Time.get_ticks_msec() + 10000
	return result

func _process(_delta: float) -> void:
	peer.poll()
	var state := peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not was_open:
			was_open = true
			connecting = false
			connected.emit()
		while peer.get_available_packet_count() > 0:
			var packet := peer.get_packet()
			if packet.size() > 65536 or not peer.was_string_packet():
				close()
				break
			receive(JSON.parse_string(packet.get_string_from_utf8()))
	elif state == WebSocketPeer.STATE_CLOSED:
		if was_open or connecting:
			was_open = false
			connecting = false
			for id in pending:
				pending[id] = {"ok":false,"error":"disconnected"}
			disconnected.emit()
	elif connecting and Time.get_ticks_msec() > connect_deadline:
		close()

func receive(value: Variant) -> void:
	if not value is Dictionary or value.get("v") != 1:
		return
	if value.has("id"):
		if pending.has(value.id) and value.get("ok") is bool:
			pending[value.id] = value
	elif value.get("data") is Dictionary:
		if value.get("event") == "snapshot":
			latest_world = value.data
			snapshot_received.emit(latest_world)
		elif value.get("event") == "self":
			latest_self = value.data
			self_received.emit(latest_self)

# Never resend a timed-out mutation: its SQL commit may already have succeeded.
func request(operation: String, data: Dictionary = {}, timeout_ms: int = 10000) -> Dictionary:
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return {"ok":false,"error":"disconnected"}
	sequence += 1
	var id := "godot_%d" % sequence
	pending[id] = null
	var result := peer.send_text(JSON.stringify({"v":1,"id":id,"op":operation,"data":data}))
	if result != OK:
		pending.erase(id)
		return {"ok":false,"error":"send_failed"}
	var deadline := Time.get_ticks_msec() + timeout_ms
	while pending[id] == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var response: Dictionary = pending[id] if pending[id] != null else {"ok":false,"error":"timeout"}
	pending.erase(id)
	return response

func close() -> void:
	peer.close(1000,"client exit")

func _exit_tree() -> void:
	peer.close()
