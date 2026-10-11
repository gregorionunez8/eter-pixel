extends "res://tests/input_runtime.gd"
func _ready() -> void:
	var studio := preload("res://addons/eter_studio/studio.gd").new()
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(studio)
	await get_tree().create_timer(0.2).timeout
	if not check(studio.ids.size() == 13,"Studio browser displays all existing items"):
		await finish(); return
	studio.open_record("bronze_sword")
	await get_tree().process_frame
	if not check(not studio.registry.dirty() and studio.form.get_child_count()>15,"item form exposes structured fields without dirty-on-open"):
		await finish(); return
	studio.form.commit(studio.form.target,"name","Test visual sword","name")
	if not check(studio.registry.dirty() and studio.registry.records("Items").bronze_sword.name == "Test visual sword","form edit changes draft and dirty state"):
		await finish(); return
	studio.registry.reload()
	studio.section = "Monsters"; studio.open_record("goblin")
	await get_tree().process_frame
	if not check(not studio.registry.dirty(),"monster and drop form opening does not mutate content"):
		await finish(); return
	studio.show_validation()
	await get_tree().process_frame
	if not check(not studio.registry.validate().any(func(issue): return issue.severity == "ERROR"),"validation panel accepts legacy content"):
		await finish(); return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../artifacts/studio-infrastructure.png")
	print("PASS Studio UI: %d checks, browser forms and validation without source changes" % checks)
	await finish()
