extends Node

## Tests for NavGraph: builds the AStar2D graph from map_13 and finds a path.

func _ready() -> void:
	print("--- TEST DE NAVEGACIÓN DEL BOT (NAVGRAPH) ---")
	var scn: PackedScene = load("res://levels/maps/map_13_arena_abierta.tscn")
	assert(scn != null, "No se pudo cargar map_13_arena_abierta.tscn")
	var map := scn.instantiate() as Node2D
	add_child(map)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var tilemap := map.get_node("NeonTileMap") as TileMapLayer
	assert(tilemap != null, "NeonTileMap debe existir y ser TileMapLayer")

	var graph := NavGraph.get_or_build(tilemap, "res://levels/maps/map_13_arena_abierta.tscn")
	print("Puntos en el grafo: %d" % graph.point_count())
	assert(graph.point_count() > 0, "El grafo debe tener al menos un nodo")

	var path := graph.find_path(Vector2(480, 1400), Vector2(2720, 1400))
	print("Tamaño del camino SpawnP1 -> SpawnP2: %d" % path.size())
	assert(path.size() >= 2, "Debe existir un camino entre los dos spawns, tamaño: %d" % path.size())

	map.free()
	print("--- TODOS LOS TESTS DE NAVGRAPH PASARON EXITOSAMENTE ---")
	get_tree().quit(0)
