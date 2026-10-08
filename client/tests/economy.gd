extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL economy: "+description)

func _ready() -> void:
	var character := EterCharacter.create("Mercado","warrior")
	var before := character.duplicate(true)
	check(not EterEconomy.buy(character,"shop","potion") and character == before,"insufficient gold atomic")
	character.gold = 1000
	before = character.duplicate(true)
	check(not EterEconomy.buy(character,"missing","potion") and character == before,"invalid shop atomic")
	check(not EterEconomy.buy(character,"shop","bronze_sword") and character == before,"stock validation")
	check(EterEconomy.buy(character,"shop","potion") and character.gold == 992,"buy one potion")
	check(character.inventory.items[1].count == 4,"purchase stacks")
	var potion: Dictionary = character.inventory.items[1]
	check(EterEconomy.sell(character,potion.uid) and character.gold == 1004,"sell full stack correct price")
	before = character.duplicate(true)
	check(not EterEconomy.sell(character,potion.uid) and character == before,"repeat sale cannot duplicate gold")
	var weapon: Dictionary = EterInventory.find(character.inventory,character.inventory.equipment.weapon)
	check(not EterEconomy.sell(character,weapon.uid) and character == before,"equipped sale rejected")
	check(not EterEconomy.repair(character,weapon.uid) and character == before,"full durability no charge")
	EterEconomy.wear(character,"weapon")
	check(weapon.durability == 99 and EterEconomy.repair_cost(weapon) == 1,"wear priced")
	check(EterEconomy.repair(character,weapon.uid) and character.gold == 1003 and weapon.durability == 100,"repair restores item")
	weapon.durability = 0
	check(not EterInventory.upgrade(character,weapon.uid,0).accepted,"broken upgrade rejected")
	check(EterEconomy.repair(character,weapon.uid),"broken repair permitted")
	check(EterInventory.upgrade(character,weapon.uid,0).success and EterCharacter.derive(character).attack == 29,"starter upgrade has attack bonus")
	before = character.duplicate(true)
	check(not EterInventory.upgrade(character,weapon.uid,NAN).accepted and character == before,"NaN upgrade rejected")
	character.gold = 0
	weapon.durability = 90
	before = character.duplicate(true)
	check(not EterEconomy.repair(character,weapon.uid) and character == before,"unaffordable repair atomic")
	character.gold = 1000
	while EterInventory.add(character.inventory,EterInventory.make_item("ore",20)):
		pass
	before = character.duplicate(true)
	check(not EterEconomy.buy(character,"shop","robe") and character == before,"full inventory purchase atomic")
	var random := RandomNumberGenerator.new()
	random.seed = 1909
	for species in Catalog.read("monsters").species:
		var config: Dictionary = Catalog.read("monsters").species[species]
		var rewards := 0
		for index in range(40):
			var loot := EterEconomy.loot(species,random)
			check(int(loot.gold) == 0 or int(loot.gold) >= int(config.loot.gold_min) and int(loot.gold) <= int(config.loot.gold_max),"gold bounds "+species)
			for item in loot.items:
				check(EterInventory.valid_item(item),"valid generated drop "+species)
				rewards += 1
		check(rewards > 0,"configured item drops observed "+species)
	print("PASS economy: %s checks" % checks if not failed else "FAIL economy")
	get_tree().quit(1 if failed else 0)
