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
	var room := preload("res://scripts/studio_test_room.gd").new(); add_child(room)
	await get_tree().process_frame
	room.test_cast()
	if not check(not App.persistence_enabled and room.world.combat.cooldowns.has("power_strike"),"test room casts actual skill with persistence disabled"): await finish(); return
	print("PASS Studio runtime: %d checks, options skill books spots and isolated real test cast" % checks)
	await finish()
