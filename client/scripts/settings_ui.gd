extends AcceptDialog

func _ready() -> void:
	title = "Configuración"
	min_size = Vector2i(280,150)
	var box := VBoxContainer.new()
	add_child(box)
	var fullscreen := CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = App.settings.get_value("video","fullscreen",false)
	box.add_child(fullscreen)
	var label := Label.new()
	label.text = "Volumen"
	box.add_child(label)
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = App.settings.get_value("audio","volume",0.7)
	box.add_child(volume)
	confirmed.connect(func(): App.save_settings(fullscreen.button_pressed,volume.value); queue_free())
	canceled.connect(queue_free)
