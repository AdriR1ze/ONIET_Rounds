class_name NavGraph
extends RefCounted

## AStar2D graph of standable cells extracted from a TileMapLayer by physics
## probes. Jump/fall edges are considered within the model limits below.
##
## The static `_cache` shares one graph per map key across every bot. It is a
## cache, not a manager: bots build it lazily and never own it.

const JUMP_UP_CELLS: int = 5
const JUMP_REACH_CELLS: int = 6
const MAX_FALL_CELLS: int = 7
const CLEARANCE_SAMPLES: int = 6

var tile_size: int = 32
var _astar: AStar2D
var _ids: Dictionary = {}  # Vector2i cell -> int id
var _probe_shape: RectangleShape2D

static var _cache: Dictionary = {}


static func get_or_build(tilemap: TileMapLayer, key: String) -> NavGraph:
	if _cache.has(key):
		return _cache[key]
	var graph := NavGraph.new()
	graph.build(tilemap)
	_cache[key] = graph
	return graph


func build(tilemap: TileMapLayer) -> void:
	tile_size = tilemap.tile_set.tile_size.x
	_astar = AStar2D.new()
	_ids.clear()
	_probe_shape = RectangleShape2D.new()
	_probe_shape.size = Vector2(tile_size - 6, tile_size - 6)

	var space := tilemap.get_world_2d().direct_space_state
	var rect := tilemap.get_used_rect()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var center := tilemap.to_global(tilemap.map_to_local(cell))
			if _is_standable(space, center):
				var id := _astar.get_point_count()
				_astar.add_point(id, center)
				_ids[cell] = id

	_connect_edges(space)


func _connect_edges(space: PhysicsDirectSpaceState2D) -> void:
	for key in _ids.keys():
		var cell: Vector2i = key
		var id: int = _ids[cell]
		var center: Vector2 = _astar.get_point_position(id)

		# Walk: right and down neighbors.
		for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbor: Vector2i = cell + offset
			if _ids.has(neighbor):
				_astar.connect_points(id, _ids[neighbor])

		# Fall: drop to a lower standable cell within MAX_FALL_CELLS.
		for dy in range(1, MAX_FALL_CELLS + 1):
			for dx in [-1, 0, 1]:
				var fall_target: Vector2i = cell + Vector2i(dx, dy)
				if _ids.has(fall_target) and _clearance_ok(space, center, _astar.get_point_position(_ids[fall_target])):
					_astar.connect_points(id, _ids[fall_target])

		# Jump: reach a higher (or equal) standable cell.
		for up in range(0, JUMP_UP_CELLS + 1):
			for dx in range(-JUMP_REACH_CELLS, JUMP_REACH_CELLS + 1):
				if dx == 0 and up == 0:
					continue
				var jump_target: Vector2i = cell + Vector2i(dx, -up)
				if _ids.has(jump_target) and _clearance_ok(space, center, _astar.get_point_position(_ids[jump_target])):
					_astar.connect_points(id, _ids[jump_target])


func _is_standable(space: PhysicsDirectSpaceState2D, center: Vector2) -> bool:
	return _is_free(space, center) and _has_ground_below(space, center)


func _is_free(space: PhysicsDirectSpaceState2D, center: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _probe_shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()


func _has_ground_below(space: PhysicsDirectSpaceState2D, center: Vector2) -> bool:
	var from := center + Vector2(0.0, tile_size * 0.3)
	var to := center + Vector2(0.0, tile_size * 1.4)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()


func _clearance_ok(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for i in range(1, CLEARANCE_SAMPLES + 1):
		var t := float(i) / float(CLEARANCE_SAMPLES + 1)
		query.position = a.lerp(b, t)
		if not space.intersect_point(query, 1).is_empty():
			return false
	return true


func nearest_cell(world: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	for key in _ids.keys():
		var cell: Vector2i = key
		var center: Vector2 = _astar.get_point_position(_ids[cell])
		var dist := center.distance_squared_to(world)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best


func has_cell(cell: Vector2i) -> bool:
	return _ids.has(cell)


func point_count() -> int:
	return _astar.get_point_count() if _astar != null else 0


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _nearest_id(from)
	var b := _nearest_id(to)
	if a == -1 or b == -1:
		return PackedVector2Array()
	if a == b:
		return PackedVector2Array([_astar.get_point_position(a)])
	return _astar.get_point_path(a, b)


func _nearest_id(world: Vector2) -> int:
	var cell := nearest_cell(world)
	return _ids[cell] if _ids.has(cell) else -1
