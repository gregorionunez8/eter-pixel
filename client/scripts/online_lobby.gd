extends Control

signal entered(data: Dictionary)
signal canceled
var address := LineEdit.new()
var username := LineEdit.new()
var password := LineEdit.new()
var status := Label.new()
var login_box := VBoxContainer.new()
var characters_box := VBoxContainer.new()
var character_list := ItemList.new()
var name_input := LineEdit.new()
var class_select := OptionButton.new()
var characters: Array = []
var class_ids: Array = []
var busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("111522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "ÉTER · Conexión local"
	title.position = Vector2(170,15)
	title.add_theme_font_size_override("font_size",24)
	title.modulate = Color("64c8cf")
	add_child(title)
	for box in [login_box,characters_box]:
		box.position = Vector2(140,60)
		box.size.x = 360
		box.add_theme_constant_override("separation",8)
		add_child(box)
	address.text = App.environment.get("server_url","ws://127.0.0.1:8080")
	address.placeholder_text = "Dirección del servidor"
	login_box.add_child(address)
	username.placeholder_text = "Cuenta (3–32 caracteres)"
	username.max_length = 32
	login_box.add_child(username)
	password.placeholder_text = "Contraseña (mínimo 8 caracteres)"
	password.secret = true
	password.max_length = 128
	login_box.add_child(password)
	var row := HBoxContainer.new()
	login_box.add_child(row)
	add_button(row,"Iniciar sesión",func(): authenticate(false))
	add_button(row,"Registrar cuenta",func(): authenticate(true))
	character_list.custom_minimum_size = Vector2(360,90)
	characters_box.add_child(character_list)
	name_input.placeholder_text = "Nombre de personaje nuevo (3–16)"
	name_input.max_length = 16
	characters_box.add_child(name_input)
	class_ids = EterCharacter.definitions().classes.keys()
	for id in class_ids: class_select.add_item(EterCharacter.definitions().classes[id].name)
	characters_box.add_child(class_select)
	row = HBoxContainer.new()
	characters_box.add_child(row)
	add_button(row,"Crear",create_character)
	add_button(row,"Entrar",select_character)
	characters_box.hide()
	status.position = Vector2(70,295)
	status.size = Vector2(500,35)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",12)
	add_child(status)
	var back := Button.new()
	back.text = "Volver"
	back.position = Vector2(280,330)
	back.pressed.connect(func(): if not busy: App.end_online(); canceled.emit())
	add_child(back)
	username.grab_focus()

func add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func authenticate(register: bool) -> void:
	if busy: return
	busy = true
	status.text = "Conectando…"
	if not is_instance_valid(App.network) or not App.network.was_open:
		if App.begin_connection(address.text.strip_edges()) != OK:
			status.text = "No se pudo abrir la conexión"
			busy = false
			return
		var deadline := Time.get_ticks_msec()+10000
		while not App.network.was_open and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
	var credentials := {"username":username.text.strip_edges(),"password":password.text}
	var reply: Dictionary
	if register:
		reply = await App.network.request("register",credentials)
		if not reply.get("ok",false):
			status.text = App.error_message(reply.get("error","disconnected"))
			busy = false
			return
	reply = await App.network.request("login",credentials)
	if reply.get("ok",false):
		App.credentials = credentials
		password.text = ""
		await refresh_characters()
		login_box.hide()
		characters_box.show()
	else: status.text = App.error_message(reply.get("error","disconnected"))
	busy = false

func refresh_characters() -> void:
	var reply: Dictionary = await App.network.request("characters")
	if not reply.get("ok",false):
		status.text = App.error_message(reply.get("error","disconnected"))
		return
	characters = reply.data
	character_list.clear()
	for state in characters: character_list.add_item("%s · %s · Nv%s" % [state.name,EterCharacter.definitions().classes[state.class_id].name,int(state.level)])
	if not characters.is_empty(): character_list.select(0)
	status.text = "Seleccioná un personaje o creá uno (máximo tres)."

func create_character() -> void:
	if busy: return
	busy = true
	var reply: Dictionary = await App.network.request("create_character",{"name":name_input.text.strip_edges(),"class_id":class_ids[class_select.selected]})
	if reply.get("ok",false): await refresh_characters()
	else: status.text = App.error_message(reply.get("error","disconnected"))
	busy = false

func select_character() -> void:
	if busy or character_list.get_selected_items().is_empty(): return
	busy = true
	var state: Dictionary = characters[character_list.get_selected_items()[0]]
	var reply: Dictionary = await App.network.request("enter_world",{"character_id":state.id})
	if reply.get("ok",false):
		App.online = true
		App.online_character_id = state.id
		App.network.latest_world = reply.data.world
		entered.emit(reply.data)
	else: status.text = App.error_message(reply.get("error","disconnected"))
	busy = false
