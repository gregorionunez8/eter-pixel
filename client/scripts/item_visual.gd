class_name EterItemVisual
extends RefCounted

const ATLAS := preload("res://assets/items.png")

static func texture(item: Dictionary,ground: bool=false) -> Texture2D:
	var definition: Dictionary=EterInventory.definitions().definitions[item.definition]
	var custom := str(definition.get("ground_sprite","")) if ground else str(definition.get("icon_path",""))
	if not custom.is_empty(): return load(EterContent.asset_path(custom))
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	result.region = Rect2(int(EterInventory.definitions().definitions[item.definition].icon)*16,0,16,16)
	return result

static func color(item: Dictionary) -> Color:
	return Color(EterInventory.definitions().rarities[item.rarity].color)

static func description(item: Dictionary) -> String:
	var definition: Dictionary = EterInventory.definitions().definitions[item.definition]
	var value := "%s +%s · %s\n" % [definition.name,int(item.upgrade),EterInventory.definitions().rarities[item.rarity].name]
	var names := {"attack":"Ataque","defense":"Defensa","max_hp":"Vida","max_mana":"Maná"}
	for key in definition.bonuses:
		var amount := floori(float(definition.bonuses[key])*float(EterInventory.definitions().rarities[item.rarity].multiplier)) + int(item.upgrade)*int(EterInventory.definitions().upgrade.stat_per_level)
		value += "%s +%s " % [names.get(key,key),amount]
	return value + "\nCantidad %s · Estado %s" % [int(item.count),int(item.durability)]
