extends Node

var cache: Dictionary = {}

func read(catalog_name: String) -> Dictionary:
	if not cache.has(catalog_name):
		var file := FileAccess.open("res://data/%s.json" % catalog_name, FileAccess.READ)
		if not file:
			push_error("Catálogo ausente: " + catalog_name)
			return {}
		cache[catalog_name] = JSON.parse_string(file.get_as_text())
	return cache[catalog_name]
