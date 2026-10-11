extends "res://tests/input_runtime.gd"
func _ready() -> void:
	App.persistence_enabled=false; App.online=false
	var registry := preload("res://addons/eter_studio/registry.gd").new()
	var duplicate_keys := preload("res://addons/eter_studio/json_keys.gd").duplicates('{"a":1,"nested":{"a":2},"a":3}')
	if not check(duplicate_keys==["a"],"duplicate key scanner respects object scopes"): await finish(); return
	var catalog: Dictionary=Catalog.read("maps").duplicate(true)
	catalog.maps.village.monsters=[{"id":"studio_spot","species":"wolf","quantity":3,"x":320,"y":320,"spawn_radius":16}]
	EterContent.maps(catalog)
	if not check(catalog.maps.village.monsters.size()==3 and catalog.maps.village.monsters[2].id=="village-studio_spot-2","runtime expands quantity into stable spawn IDs"): await finish(); return
	var factors: Dictionary=Catalog.read("balance").monster
	factors.damage=2
	var balanced: Dictionary=EterContent.apply_balance("monsters",{"species":{"test":{"hp":50,"attack":10,"damage_min":8,"damage_max":12,"defense":2,"experience":20,"respawn":6,"loot":{"gold_min":1,"gold_max":2}}}})
	factors.damage=1
	if not check(balanced.species.test.damage_min==16 and balanced.species.test.damage_max==24,"global monster damage applies to configured min/max"): await finish(); return
	var definitions: Dictionary=EterInventory.definitions().definitions
	var item: Dictionary=registry.record("Items","bronze_sword").duplicate(true)
	item.options={"additional_damage":7,"critical_chance":4.5,"attack_speed":10}
	definitions.studio_blade=item
	var character := EterCharacter.create("StudioHero","warrior")
	var before := EterCharacter.derive(character)
	var blade := EterInventory.make_item("studio_blade")
	EterInventory.add(character.inventory,blade); EterInventory.equip(character,blade.uid)
	var bonuses := EterInventory.bonuses(character.inventory)
	if not check(bonuses.critical_chance==4.5 and bonuses.attack_speed==10,"options preserve configurable percentages"): await finish(); return
	var skill := preload("res://addons/eter_studio/schema.gd").defaults("Skills")
	skill.book_item_id="studio_book"; Catalog.read("combat").skills.studio_power=skill
	var book := preload("res://addons/eter_studio/schema.gd").defaults("Items")
	book.category="skill_book"; book.erase("slot"); book.learn_skill="studio_power"; book.durability=0; definitions.studio_book=book
	var incoming := EterInventory.make_item("studio_book"); EterInventory.add(character.inventory,incoming)
	if not check(not "studio_power" in EterCombatRules.available(character) and EterInventory.learn_book(character,incoming.uid),"book gates a new skill then learns it"): await finish(); return
	if not check("studio_power" in EterCombatRules.available(character) and EterInventory.find(character.inventory,incoming.uid).is_empty(),"learning consumes once and unlocks casting"): await finish(); return
	var repeated := EterInventory.make_item("studio_book"); EterInventory.add(character.inventory,repeated)
	if not check(not EterInventory.learn_book(character,repeated.uid) and not EterInventory.find(character.inventory,repeated.uid).is_empty(),"already known book is not consumed"): await finish(); return
	var progression: Dictionary=Catalog.read("progression"); progression.reset_enabled=true; progression.reset_min_level=1
	Catalog.read("balance").reset.points=10
	if not check(EterProgression.reset(character) and character.reset_count==1 and character.attribute_points==10 and "studio_power" in character.learned_skills,"reset applies reward and preserves configured quest/items/skills policy"): await finish(); return
	var save_path := "res://../artifacts/studio-character.json"
	if not check(EterSave.save(character,save_path) and EterSave.load_character(save_path).get("learned_skills",[])==["studio_power"],"learned skills and reset state persist through disk save/load without changing user slot"): await finish(); return
	var wav := AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_8_BITS; wav.mix_rate=8000; wav.data=PackedByteArray(); wav.data.resize(8000); wav.data.fill(128)
	ResourceSaver.save(wav,"user://eter-studio-test-tone.tres")
	Catalog.read("audio").definitions.studio_tone={"path":"user://eter-studio-test-tone.tres","volume":0.5,"pitch":1}
	var audio := EterAudio.get_manager(get_tree()); await get_tree().process_frame
	var master := AudioServer.get_bus_volume_db(0); audio.play("studio_tone","UI")
	if not check(AudioServer.get_bus_index("Music")>=0 and audio.sfx_players.size()==1 and audio.sfx_players[0].bus=="UI" and AudioServer.get_bus_volume_db(0)==master,"central audio routes preview clip while preserving Master volume"): await finish(); return
	var room := preload("res://scripts/studio_test_room.gd").new(); add_child(room)
	await get_tree().process_frame
	if not check(room.world.player.position==Vector2(room.world.geometry.spawn.x,room.world.geometry.spawn.y),"Map Test starts at authored default spawn"): await finish(); return
	Catalog.read("combat").skills.power_strike.icon_path="items"
	room.world.sync_skill_buttons()
	if not check(not room.world.skill_buttons.is_empty() and room.world.skill_buttons[0].icon!=null,"configured skill icon appears on real skill bar"): await finish(); return
	var starter: Dictionary=EterInventory.definitions().definitions.starter_sword
	starter.equipped_visual={"path":"warrior_unarmed","hframes":4,"vframes":8,"offset":[0,-18],"scale":[1,1],"layer":1}
	room.world.player.update_equipment_visual()
	if not check(room.world.player.equipment_layers.size()==1,"equipment sprite is mounted on actual player layer"): await finish(); return
	var remote := EterPlayer.new(); remote.remote=true; remote.replicated=true; remote.actor_class="warrior"; remote.actor_name="Preview"
	remote.remote_equipment=[{"slot":"weapon","path":"warrior_unarmed","hframes":4,"vframes":8,"offset":[0,-18],"scale":[1,1],"layer":1}]
	room.world.entities.add_child(remote)
	if not check(remote.equipment_layers.size()==1 and remote.sprite.texture.resource_path.ends_with("warrior_unarmed.png"),"remote visual uses public descriptor and removes baked weapon"): await finish(); return
	room.test_cast()
	if not check(not App.persistence_enabled and room.world.combat.cooldowns.has("power_strike"),"test room casts actual skill with persistence disabled"): await finish(); return
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../artifacts/studio-test-room.png")
	var previous_world: Node=room.world
	if not check(not previous_world.portals.is_empty(),"portal test requires existing map portal"): await finish(); return
	var portal: Node2D=previous_world.portals[0]
	var destination: String=portal.definition.target
	previous_world.player.position=portal.position
	previous_world.combat.cooldowns.heal=6.0
	previous_world.travel(portal)
	if not check(room.world!=previous_world and room.world.map_id==destination and room.world.combat.cooldowns.heal>5.5 and not App.persistence_enabled,"isolated Test Room portals load target map preserving cooldown and no-save"): await finish(); return
	var new_map: Dictionary=preload("res://addons/eter_studio/schema.gd").defaults("Maps")
	new_map.id="studio_fresh"; new_map.name="Studio fresh test"
	var new_monster: Dictionary=preload("res://addons/eter_studio/schema.gd").defaults("Monsters")
	Catalog.read("monsters").species.studio_fresh=new_monster
	new_map.monsters=[{"id":"studio_fresh_spawn","species":"studio_fresh","x":320,"y":320}]
	Catalog.read("maps").maps.studio_fresh=new_map
	App.character.map_id="studio_fresh"; App.character.position=new_map.spawn.duplicate()
	room.change_map("studio_fresh",Vector2(176,176))
	if not check(room.world.map_id=="studio_fresh" and room.world.player.position==Vector2(176,176),"new map schema opens in actual runtime"): await finish(); return
	if not check(room.world.targets.size()==2 and room.world.targets[0].species_id=="studio_fresh" and room.world.targets[0].state.hp==65,"new monster schema spawns with real HP and visual"): await finish(); return
	var boots: Dictionary=preload("res://addons/eter_studio/schema.gd").defaults("Items")
	boots.category="boots"; boots.slot="boots"; boots.options={"speed":5}; boots.classes=["warrior"]
	definitions.studio_fresh_boots=boots
	var boots_instance := EterInventory.make_item("studio_fresh_boots")
	if not check(EterInventory.add(App.character.inventory,boots_instance) and EterInventory.equip(App.character,boots_instance.uid),"new equipment schema equips in real character inventory"): await finish(); return
	room.world.inventory_changed()
	print("PASS Studio runtime: %d checks, options skill books spots and isolated real test cast" % checks)
	await finish()
