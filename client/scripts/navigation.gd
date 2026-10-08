class_name EterNavigation
extends RefCounted

const TILE := 32
var grid := AStarGrid2D.new()
var bounds := Rect2i()

func setup(size: Vector2i, blocked: Array[Vector2i]) -> void:
	bounds = Rect2i(Vector2i.ZERO, size)
	grid.region = bounds
	grid.cell_size = Vector2(TILE, TILE)
	grid.offset = Vector2(TILE / 2.0, TILE / 2.0)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cell in blocked:
		grid.set_point_solid(cell)

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))

func walkable(cell: Vector2i) -> bool:
	return bounds.has_point(cell) and not grid.is_point_solid(cell)

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := cell_at(from)
	if not walkable(start):
		return PackedVector2Array()
	var finish := cell_at(to)
	finish.x = clampi(finish.x, 0, bounds.size.x - 1)
	finish.y = clampi(finish.y, 0, bounds.size.y - 1)
	if not walkable(finish):
		var best := Vector2i(-1, -1)
		var distance := INF
		for radius in range(1, 9):
			for y in range(finish.y - radius, finish.y + radius + 1):
				for x in range(finish.x - radius, finish.x + radius + 1):
					var candidate := Vector2i(x, y)
					if walkable(candidate) and candidate.distance_squared_to(finish) < distance and not grid.get_id_path(start, candidate).is_empty():
						best = candidate
						distance = candidate.distance_squared_to(finish)
			if best != Vector2i(-1, -1):
				finish = best
				break
		if best == Vector2i(-1, -1):
			return PackedVector2Array()
	var route := grid.get_point_path(start, finish)
	if route.is_empty():
		return route
	# Return to own cell center before turning to prevent corner clipping on reroute.
	if route[0].distance_to(from) < 1:
		route.remove_at(0)
	return route
