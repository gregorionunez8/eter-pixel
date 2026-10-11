@tool
extends RefCounted
const ITEM_TYPES := ["weapon","helmet","armor","gloves","pants","boots","ring","pendant","wings","pet","shield","potion","consumable","skill_book","quest_item","material","misc"]
const SLOTS := {"weapon":"weapon","helmet":"helmet","armor":"armor","gloves":"gloves","pants":"pants","boots":"boots","ring":"ring","pendant":"pendant","wings":"wings","pet":"pet","shield":"shield"}
const LABELS := {"category":"Type","armor":"Chest","pendant":"Necklace","hp":"Max HP","mana":"Mana Cost","multiplier":"Damage Multiplier","detect_radius":"Aggro Range","leash_radius":"Return / Walk Range","respawn":"Respawn Time (s)","radius":"Collision Radius (px)","attack_interval":"Attack Interval (s)","tile":"Tile Size (px)","terrain":"Base Tile / Background","ambient":"Ambient Tint","stack":"Max Stack","size":"Inventory Size (cells)","icon":"Legacy Atlas Icon","icon_path":"Inventory Icon","ground_sprite":"Ground / Drop Sprite","equipped_visual":"Equipped Visual","learn_skill":"Skill Book Learns","book_item_id":"Book Item ID","chances":"Success Chance (%)"}
const ENUMS := {
	"experience_mode":["formula","table"],"category":ITEM_TYPES,"slot":["weapon","helmet","armor","gloves","pants","boots","ring","pendant","wings","pet","shield"],"type":["shop","quest","reset","dialogue","other"],
	"mode":["single","area","heal","multiple","buff","debuff","directional"],
	"behavior":["direct_damage","projectile","area_damage","heal","buff","debuff","multi_projectile","aoe_around_player","directional"],
	"damage_type":["physical","magic"],"rarity":["normal","magic","excellent","legendary"],
	"surface":["grass","dirt","stone","wood","water","dungeon"],"shape":["rectangle","tiles"],
	"pvp_mode":["disabled","enabled","free"],"stats_behavior":["initial","keep"],
	"skill_behavior":["keep","initial"],"inventory_behavior":["keep"],"equipment_behavior":["keep"],"quest_behavior":["keep"]
}

static func defaults(section: String) -> Dictionary:
	match section:
		"Items": return {"name":"Nuevo item","description":"","category":"weapon","slot":"weapon","subtype":"","rarity":"normal","required_level":1,"classes":["warrior","mage","elf"],"buy_price":1,"sell_price":0,"tradeable":true,"droppable":true,"storable":true,"stack":1,"durability":100,"size":[1,1],"bonuses":{"attack":0,"defense":0},"icon":0,"icon_path":"","ground_sprite":"","equipped_visual":{"path":"","offset":[0,-18],"scale":[1,1],"layer":1,"hframes":4,"vframes":8,"animation_mapping":{}},"options":{},"audio":{}}
		"Monsters": return {"name":"Nuevo monstruo","description":"","level":1,"hp":65,"max_mana":1,"attack":12,"damage_min":12,"damage_max":12,"defense":2,"magic_defense":0,"experience":24,"speed":78,"detect_radius":144,"leash_radius":260,"walk_radius":260,"attack_range":28,"attack_interval":1.2,"respawn":6,"radius":7,"accuracy":75,"evasion":4,"loot":{"gold_min":3,"gold_max":8,"chance":0.8},"visual":{"path":"spider","frame_width":32,"frame_height":32,"hframes":4,"vframes":1,"scale":1,"pivot":[0,6],"animation_mapping":{"idle":[0],"walk":[1,2,3],"attack":[0],"hit":[0],"death":[0]}},"audio":{}}
		"Skills": return {"name":"Nuevo poder","description":"","classes":["warrior"],"required_level":1,"icon_path":"","mana":8,"cooldown":3,"cast_time":0,"range":52,"base_damage":0,"multiplier":1.8,"scaling_stat":"attack","hits":1,"max_targets":3,"heal_fraction":0.3,"mode":"single","behavior":"direct_damage","area_radius":52,"projectile_speed":240,"effect_duration":0.2,"effect":"slash","damage_type":"physical","book_item_id":"","buff":{},"audio":{"cast_sound":"","travel_sound":"","impact_sound":"","loop_sound":"","volume":1,"pitch_variance":0},"vfx":{"cast_effect":"","projectile_effect":"","impact_effect":"","area_effect":""}}
		"NPCs": return {"name":"Nuevo NPC","type":"dialogue","shop_id":"","visual":"warrior_unarmed","facing":2,"interaction_radius":64,"dialogue":"Hola, viajero.","audio":{}}
		"Shops": return {"name":"Nueva tienda","stock":[],"prices":{},"quantity_rules":{"buy_quantity":1},"buy_enabled":true,"sell_enabled":true,"repair_enabled":false,"upgrade_enabled":false}
		"Maps": return {"id":"","name":"Nuevo mapa","width":48,"height":32,"tile":32,"spawn":{"x":176,"y":176},"terrain":"terrain","ambient":"ffffff","monsters":[],"npcs":[],"portals":[],"obstacles":[],"layers":{},"zones":[],"player_spawns":[],"audio_zones":[],"pvp_mode":"disabled","recommended_level":1,"music":"","ambient_sound":"","volume":1,"fade_duration":1}
		"Progression", "Reset": return {"max_level":100,"experience_base":80,"experience_exponent":1.7,"experience_mode":"formula","experience_table":[],"points_per_level":5,"death_experience_fraction":0.05,"attribute_cap":10000,"reset_enabled":false,"reset_min_level":100}
		"Audio": return {"name":"Nuevo sonido","path":"","category":"SFX","volume":1,"pitch":1,"loop":false}
		"Assets": return {"name":"Nuevo asset","path":"","category":"Custom","surface":"stone"}
	return {}

static func display(key: String) -> String:
	return LABELS.get(key,key.capitalize().replace("_"," "))

static func array_entry(key: String) -> Variant:
	match key:
		"drops": return {"item":"potion","chance":0.7,"min_quantity":1,"max_quantity":1,"min_upgrade":0,"max_upgrade":0,"possible_options":[],"option_chance":0}
		"possible_options": return {"option":"critical_chance","value":4}
		"experience_table": return 80
		"stock": return "potion"
		"entries": return {"species":"spider","quantity":1}
		"player_spawns": return {"id":"spawn_new","x":176,"y":176,"target":"village"}
		"portals": return {"id":"portal_new","x":176,"y":176,"target":"village","arrival":{"x":176,"y":176},"audio":{}}
		"npcs": return {"id":"npc_new","npc_id":"shop","x":176,"y":176,"facing":2}
		"monsters": return {"id":"spot_new","species":"spider","x":176,"y":176,"quantity":1,"walk_radius":144,"spawn_radius":0,"respawn":6,"enabled":true}
		"zones": return {"id":"zone_new","x":176,"y":176,"width":64,"height":64,"shape":"rectangle","pvp_mode":"disabled","monster_aggro_disabled":false,"town":true,"respawn_allowed":true,"skill_restrictions":[],"audio":{}}
		"audio_zones": return {"id":"audio_zone_new","x":176,"y":176,"width":64,"height":64,"shape":"rectangle","music":"","ambient_sound":"","enter_sound":"","exit_sound":"","fade_time":1,"priority":1}
		"obstacles": return {"x":5,"y":5,"width":1,"height":1,"texture":"tree"}
	return ""
