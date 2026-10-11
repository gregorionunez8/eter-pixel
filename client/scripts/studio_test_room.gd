extends Node
var world: Node2D
var info := Label.new()
var skills := OptionButton.new()
var items := OptionButton.new()
var monsters := OptionButton.new()
var classes := OptionButton.new()
var dummy: EterTrainingTarget
var last_damage := 0
func _ready() -> void:
	App.persistence_enabled=false; App.online=false; App.active_character=false; App.class_id="warrior"; App.player_name="StudioTest"
	var request: Dictionary={}
	var request_path := "res://../artifacts/studio-test.json"
	if FileAccess.file_exists(request_path): request=JSON.parse_string(FileAccess.get_file_as_string(request_path))
	App.class_id=request.get("class_id","warrior"); App.character=EterCharacter.create("StudioTest",App.class_id)
	App.character.map_id=request.get("map_id","village"); App.character.position=Catalog.read("maps").maps[App.character.map_id].spawn.duplicate(); App.character.starter_ground_claimed=true
	world=preload("res://scripts/world.gd").new(); world.map_changed.connect(change_map); add_child(world)
	var overlay := CanvasLayer.new(); overlay.layer=30; add_child(overlay)
	var panel := PanelContainer.new(); panel.position=Vector2(8,88); panel.theme=Theme.new(); panel.theme.default_font_size=10; overlay.add_child(panel)
	var toggle := Button.new(); toggle.text="Tools"; toggle.position=Vector2(8,66); toggle.add_theme_font_size_override("font_size",10); overlay.add_child(toggle); toggle.pressed.connect(func(): panel.visible=not panel.visible)
	var box := VBoxContainer.new(); panel.add_child(box)
	var caption := Label.new(); caption.text="ÉTER Studio · sesión aislada sin guardado"; box.add_child(caption)
	for id in EterCharacter.definitions().classes: classes.add_item(id)
	classes.select(EterCharacter.definitions().classes.keys().find(App.class_id)); box.add_child(classes)
	classes.item_selected.connect(func(index):
		App.class_id=classes.get_item_text(index); App.character=EterCharacter.create("StudioTest",App.class_id)
		App.character.map_id=world.map_id; App.character.starter_ground_claimed=true
		world.player.actor_class=App.class_id; world.player.update_equipment_visual()
		world.inventory_ui.character=App.character; world.shop_ui.character=App.character; world.quest_ui.character=App.character
		world.sync_skill_buttons(); world.update_resources())
	for id in EterCombatRules.definitions().skills: skills.add_item(id)
	box.add_child(skills); action(box,"TEST CAST",test_cast)
	for id in EterInventory.definitions().definitions: items.add_item(id)
	box.add_child(items); action(box,"GIVE ITEM",func():
		if EterInventory.add(App.character.inventory,EterInventory.make_item(items.get_item_text(items.selected))): world.inventory_changed()
		else: info.text="Inventario lleno o item inválido")
	for id in EterMonster.species(): monsters.add_item(id)
	box.add_child(monsters); action(box,"TEST SPAWN",func():
		var monster := EterMonster.new(); monster.species_id=monsters.get_item_text(monsters.selected)
		monster.position=world.player.position+Vector2(64,0); monster.navigation=world.navigation; monster.player=world.player; monster.combat=world.combat
		world.entities.add_child(monster); world.targets.append(monster))
	action(box,"Restore HP / MP",func(): App.character.hp=App.character.stats.max_hp; App.character.mana=App.character.stats.max_mana; world.update_resources())
	box.add_child(info)
	box.add_theme_constant_override("separation",2)
	dummy=EterTrainingTarget.new(); dummy.position=world.player.position+Vector2(48,0); world.entities.add_child(dummy); world.targets.append(dummy)
	world.combat.hit_resolved.connect(func(target,result): if target==dummy: last_damage+=int(result.damage))
	if request.get("section","")=="Items" and EterInventory.definitions().definitions.has(request.get("id","")):
		EterInventory.add(App.character.inventory,EterInventory.make_item(request.id)); world.inventory_changed()
	if request.get("section","")=="Monsters" and EterMonster.species().has(request.get("id","")): monsters.select(EterMonster.species().keys().find(request.id))
	if request.get("section","")=="NPCs":
		var npc := preload("res://scripts/npc.gd").new(); npc.npc_id=request.get("id","shop")
		npc.shop_id=Catalog.read("npcs").definitions[npc.npc_id].get("shop_id","")
		if npc.shop_id.is_empty(): npc.shop_id=npc.npc_id
		npc.position=world.player.position+Vector2(-48,0); world.entities.add_child(npc); world.npcs.append(npc)
	if request.get("section","")=="Skills": skills.select(EterCombatRules.definitions().skills.keys().find(request.id))
func action(parent: Node,text: String,callback: Callable) -> void:
	var button := Button.new(); button.text=text; parent.add_child(button); button.pressed.connect(callback)
func test_cast() -> void:
	var id := skills.get_item_text(skills.selected)
	var skill: Dictionary=EterCombatRules.definitions().skills[id]
	App.character.level=maxi(int(App.character.level),int(skill.get("required_level",1)))
	if not App.character.has("learned_skills"): App.character.learned_skills=[]
	if not id in App.character.learned_skills: App.character.learned_skills.append(id)
	dummy.dead=false; dummy.state.hp=dummy.state.stats.max_hp; dummy.refresh()
	world.combat.select_target(dummy)
	var before := int(App.character.mana)
	last_damage=0
	var cast: bool=world.combat.cast(id)
	info.text="Damage: "+str(last_damage)+" · Cast: "+str(cast)+" · MP used: "+str(before-int(App.character.mana))+" · cooldown: "+str(world.combat.cooldowns.get(id,0))

func change_map(_map_id: String,_point: Vector2) -> void:
	var previous := world
	var cooldowns: Dictionary=previous.combat.cooldowns.duplicate()
	var started := Time.get_ticks_msec()
	remove_child(previous); previous.queue_free()
	world=preload("res://scripts/world.gd").new()
	world.map_changed.connect(change_map); add_child(world)
	for id in cooldowns: world.combat.cooldowns[id]=maxf(0,float(cooldowns[id])-(Time.get_ticks_msec()-started)/1000.0)
	dummy=EterTrainingTarget.new(); dummy.position=world.player.position+Vector2(48,0); world.entities.add_child(dummy); world.targets.append(dummy)
	world.combat.hit_resolved.connect(func(target,result): if target==dummy: last_damage+=int(result.damage))
	info.text="Mapa: "+world.map_id+" · cooldowns conservados"
