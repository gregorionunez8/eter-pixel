extends Node

var settings := ConfigFile.new()
var environment: Dictionary = {}
var player_name := "Viajero"
var class_id := "warrior"
var character: Dictionary = {}
var persistence_enabled := true
var active_character := false

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
	if persistence_enabled and active_character and not EterSave.save(character):
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
