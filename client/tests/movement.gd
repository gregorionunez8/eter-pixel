extends Node

var checks := 0
var failed := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("FAIL movement: " + description)

func _ready() -> void:
	var world := preload("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	check(world.navigation.walkable(Vector2i(24, 19)), "spawn walkable")
	check(not world.navigation.walkable(Vector2i(23, 14)), "shrine solid")
	var around: PackedVector2Array = world.navigation.find_path(Vector2(22 * 32 + 16, 14 * 32 + 16), Vector2(26 * 32 + 16, 14 * 32 + 16))
	check(around.size() > 4, "path detours around shrine")
	for point in around:
		check(world.is_safe(point), "path avoids collision footprint")
	var into: PackedVector2Array = world.navigation.find_path(world.player.position, Vector2(24 * 32, 14 * 32))
	check(not into.is_empty() and world.navigation.walkable(world.navigation.cell_at(into[into.size()-1])), "solid click resolves to reachable ground")
	world.set_destination(Vector2(22 * 32 + 16, 13 * 32 + 16))
	var expected: Vector2 = world.player.destination
	for tick in range(270):
		await get_tree().physics_frame
		check(world.is_safe(world.player.global_position), "real physics does not cross walls")
	check(world.player.position.distance_to(expected) < 2, "real actor reaches destination around obstacle")
	check(world.player.path.is_empty(), "arrival stops movement")
	# Continuous click must not replan back to the cell center on each update.
	world.set_destination(Vector2(26 * 32 + 16, 13 * 32 + 16))
	expected = world.player.destination
	for tick in range(180):
		if tick % 7 == 0:
			world.set_destination(expected)
		await get_tree().physics_frame
		check(world.is_safe(world.player.position), "continuous destination avoids obstacles")
	check(world.player.position.distance_to(expected) < 2, "held destination reaches target without oscillation")
	# Bypass navigation to test physics as independent protection.
	world.player.position = Vector2(24 * 32 + 16, 16 * 32 + 16)
	world.player.path = PackedVector2Array([Vector2(24 * 32 + 16, 14 * 32 + 16)])
	for tick in range(80):
		await get_tree().physics_frame
		check(world.is_safe(world.player.position), "physics blocks invalid direct route")
	check(world.player.position.y >= 16 * 32 + 6.5, "collision stops before shrine")
	var nav := EterNavigation.new()
	var solid: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	nav.setup(Vector2i(3, 3), solid)
	check(nav.find_path(Vector2(16,16), Vector2(48,48)).is_empty(), "no corner cut")
	print("PASS movement: %s checks, pathfinding + actual CharacterBody2D physics" % checks if not failed else "FAIL movement suite")
	get_tree().quit(1 if failed else 0)
