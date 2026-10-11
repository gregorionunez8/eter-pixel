extends "res://tests/input_runtime.gd"
const Registry = preload("res://addons/eter_studio/registry.gd")
const Schema = preload("res://addons/eter_studio/schema.gd")
const FIXTURE := "res://../artifacts/studio-registry-fixture"

func _ready() -> void:
	var real := Registry.new()
	if not check(not real.dirty() and real.validate().all(func(issue): return issue.severity != "ERROR"),"existing catalogs import and validate without mutations"):
		await finish(); return
	if not check(real.records("Items").size() == 13 and real.records("Monsters").size() == 6 and real.records("Skills").size() == 6 and real.records("Maps").size() == 3 and real.records("NPCs").size() == 2,"all existing content appears in registry"):
		await finish(); return
	if not check(real.search("goblin").size()>1 and not real.references("Items","potion").is_empty(),"global search and references cover shops drops quests"):
		await finish(); return
	var folder := ProjectSettings.globalize_path(FIXTURE)
	DirAccess.make_dir_recursive_absolute(folder.path_join("shared"))
	DirAccess.make_dir_recursive_absolute(folder.path_join("client/assets"))
	for name in Registry.CATALOGS:
		if FileAccess.file_exists(real.source_path(name)): DirAccess.copy_absolute(real.source_path(name),folder.path_join("shared/"+name+".json"))
	for asset in real.records("Assets").values(): DirAccess.copy_absolute(ProjectSettings.globalize_path(asset.path),folder.path_join("client/"+asset.path.trim_prefix("res://")))
	var registry := Registry.new(folder)
	if not check(registry.create("Items","blade_test",Schema.defaults("Items")).is_empty(),"create visual-compatible item definition"):
		await finish(); return
	if not check(not registry.create("Items","blade_test",{}).is_empty() and not registry.create("Items","BAD ID",{}).is_empty(),"duplicate and malformed IDs rejected"):
		await finish(); return
	registry.data.items.definitions.blade_test.options = {"skill":"power_strike","critical_chance":4}
	registry.data.economy.shops.shop.stock.append("blade_test")
	if not check(registry.references("Items","blade_test").size() == 1 and registry.dirty(),"reference discovery and dirty state"):
		await finish(); return
	var bound: Dictionary=registry.record("Items","blade_test")
	var save_error := registry.save_all()
	if not check(save_error.is_empty(),"validated atomic save to shared format: "+save_error):
		await finish(); return
	if not check(not registry.dirty() and registry.records("Items").has("blade_test"),"save reload preserves record and resets dirty"):
		await finish(); return
	bound.name="Edited after save"
	if not check(registry.dirty() and registry.record("Items","blade_test").name=="Edited after save" and registry.save_all().is_empty(),"bound editor keeps editing after Save All"): await finish(); return
	var external := FileAccess.open(folder.path_join("shared/items.json"),FileAccess.READ_WRITE)
	external.seek_end(); external.store_string(" "); external.close()
	registry.data.items.definitions.blade_test.name = "Edited"
	if not check(registry.save_all().contains("Conflicto"),"external edit blocks overwrite"):
		await finish(); return
	registry.reload()
	registry.delete("Items","blade_test")
	if not check(registry.validate().any(func(issue): return issue.severity == "ERROR" and issue.section == "Shops") and not registry.build().is_empty(),"deleting referenced content blocks build"):
		await finish(); return
	registry.data.economy.shops.shop.stock.erase("blade_test")
	if not check(registry.build().is_empty() and FileAccess.file_exists(folder.path_join("client/data/items.json")),"build syncs shared catalogs after resolving references"):
		await finish(); return
	registry.data.economy.drops.spider[0].chance = 1.01
	if not check(registry.validate().any(func(issue): return issue.severity == "ERROR" and issue.message.contains("porcentaje")),"drop chance greater than100 blocked"):
		await finish(); return
	print("PASS Studio registry: %d checks, legacy adapters CRUD validation references conflicts and build" % checks)
	await finish()
