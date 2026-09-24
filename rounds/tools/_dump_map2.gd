extends SceneTree

func _initialize() -> void:
	var scn: PackedScene = load("res://levels/maps/map_13_arena_abierta.tscn")
	var node: Node = scn.instantiate()
	root.add_child(node)
	await process_frame
	var layer := node.get_node_or_null("NeonTileMap") as TileMapLayer
	var by_cell: Dictionary = {}
	var counts: Dictionary = {}
	for c in layer.get_used_cells():
		var src: int = layer.get_cell_source_id(c)
		var atl: Vector2i = layer.get_cell_atlas_coords(c)
		var key: String = "%d@(%d,%d)" % [src, atl.x, atl.y]
		by_cell[c] = key
		counts[key] = int(counts.get(key, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	for k in keys:
		print("  %s -> %d" % [k, counts[k]])
	var rect: Rect2i = layer.get_used_rect()
	var s := ""
	for gy in range(rect.position.y, rect.end.y):
		var line := ""
		for gx in range(rect.position.x, rect.end.x):
			var k: String = String(by_cell.get(Vector2i(gx, gy), "."))
			line += (k[0] if k != "." else ".")
		s += "%4d %s\n" % [gy, line]
	FileAccess.open("/tmp/map13_src.txt", FileAccess.WRITE).store_string(s)
	print("dumped /tmp/map13_src.txt")
	node.queue_free()
	quit(0)
