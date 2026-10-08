extends Panel

signal submitted(channel: String, message: String)
var connected := false
var channel := OptionButton.new()
var input := LineEdit.new()
var history := RichTextLabel.new()

func _ready() -> void:
	position = Vector2(14,186)
	size = Vector2(280,118)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111522",0.94)
	style.border_color = Color("796654")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel",style)
	history.position = Vector2(6,5)
	history.size = Vector2(268,72)
	history.add_theme_font_size_override("normal_font_size",10)
	history.scroll_following = true
	add_child(history)
	channel.position = Vector2(6,80)
	channel.size = Vector2(75,28)
	channel.add_theme_font_size_override("font_size",10)
	channel.add_item("Global")
	channel.add_item("Local")
	add_child(channel)
	input.position = Vector2(86,80)
	input.size = Vector2(186,28)
	input.add_theme_font_size_override("font_size",10)
	input.max_length = 160
	input.placeholder_text = "Enter: enviar · Esc: cerrar"
	input.text_submitted.connect(send)
	add_child(input)
	append_message("Sistema","Sin conexión. Chat requiere servidor.")
	hide()

func append_message(sender: String, message: String) -> void:
	# Plain text prevents rich-text tags supplied by other users from changing UI.
	history.add_text("%s: %s\n" % [sender,message])
	if history.get_line_count() > 80:
		history.clear()
		history.add_text("Sistema: historial anterior descartado.\n")

func send(message: String) -> void:
	message = message.strip_edges()
	if message.is_empty(): return
	if not connected:
		append_message("Sistema","No enviado: sin conexión al servidor.")
		return
	submitted.emit("global" if channel.selected == 0 else "local",message)
	input.clear()

func open() -> void:
	show()
	input.grab_focus()
