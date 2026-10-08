extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL inventory: " + description)

func _ready() -> void:
	var character := EterCharacter.create("Acero","warrior")
	var state: Dictionary = character.inventory
	check(EterInventory.valid(state,"warrior"), "starter inventory valid")
	var weapon := EterInventory.make_item("bronze_sword",1,"magic")
	check(EterInventory.add(state,weapon), "insert 1x2 weapon")
	check(not EterInventory.add(state,weapon), "duplicate UID rejected")
	var uid: String = weapon.uid
	check(not EterInventory.move(state,uid,7,5), "bounds reject tall item")
	check(not EterInventory.move(state,uid,0,0), "occupied cell rejected")
	check(EterInventory.move(state,uid,4,2), "move succeeds to free cells")
	check(EterInventory.equip(character,uid), "equip swaps atomically")
	state = character.inventory
	check(state.equipment.weapon == uid and EterInventory.find(state,uid).x == -1, "equipped item has one location")
	check(EterCharacter.derive(character).attack == 36, "rarity modifies equipped stats")
	character.gold = 1000
	check(EterInventory.upgrade(character,uid,0).success, "upgrade success consumes configured gold")
	check(character.gold == 980 and EterCharacter.derive(character).attack == 38, "upgrade bonus and cost")
	check(not EterInventory.upgrade(character,uid,1).success and EterInventory.find(state,uid).upgrade == 0, "configured failure downgrades")
	check(EterInventory.upgrade(character,uid,1).success, "100 percent upgrade chance is guaranteed")
	check(EterInventory.valid(state,"warrior"), "equipment remains valid")
	check(EterInventory.add(state,EterInventory.make_item("potion",7)), "potion stack merges")
	var potions := 0
	for item in state.items:
		if item.definition == "potion":
			potions += int(item.count)
	check(potions == 10, "stack count conserved")
	for id in ["robe","helmet","gloves","boots","shield","ring","pendant","ore"]:
		check(EterInventory.add(state,EterInventory.make_item(id)), "all category dimensions fit: " + id)
	check(EterInventory.valid(state,"warrior"), "mixed dimensions do not overlap")
	var wrong := EterInventory.make_item("starter_staff")
	check(EterInventory.add(state,wrong), "item for other class may be carried")
	check(not EterInventory.equip(character,wrong.uid), "wrong class cannot equip")
	var corrupt := state.duplicate(true)
	corrupt.items.append(corrupt.items[0].duplicate(true))
	check(not EterInventory.valid(corrupt,"warrior"), "save rejects duplicate UID")
	var invalid := weapon.duplicate(true)
	invalid.count = 1.5
	check(not EterInventory.add(state,invalid), "fractional stack rejected")
	invalid.definition = "nonexistent"
	check(not EterInventory.add(state,invalid), "unknown definition rejected")
	var full := EterInventory.initial("warrior")
	for index in range(47):
		check(EterInventory.add(full,EterInventory.make_item("ring")), "fill unique 1x1 cell")
	var snapshot := JSON.stringify(full)
	check(not EterInventory.unequip(full,"weapon") and JSON.stringify(full) == snapshot, "full inventory unequip leaves state intact")
	check(not EterInventory.add(full,EterInventory.make_item("robe")) and JSON.stringify(full) == snapshot, "no-space add leaves state intact")
	check(EterInventory.add(full,EterInventory.make_item("potion",7)), "full grid still accepts complete stack merge")
	snapshot = JSON.stringify(full)
	check(not EterInventory.add(full,EterInventory.make_item("potion",1)) and JSON.stringify(full) == snapshot, "overflow merge cannot lose items")
	var removed := EterInventory.remove(full,full.items[1].uid)
	check(not removed.is_empty() and EterInventory.add(full,removed), "drop and pickup preserves same UID")
	check(EterInventory.valid(full,"warrior"), "full inventory remains valid")
	print("PASS inventory: %s checks, grid, stacking, equipment, upgrade and conservation" % checks if not failed else "FAIL inventory suite")
	get_tree().quit(1 if failed else 0)
