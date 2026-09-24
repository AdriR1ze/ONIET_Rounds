extends SceneTree

func _initialize() -> void:
	var paths := [
		"res://levels/maps/map_13_arena_abierta.tscn",
		"res://levels/maps/map_03_el_pendulo.tscn",
		"res://levels/test_level.tscn",
	]
	for p in paths:
		if not FileAccess.file_exists(p):
			continue
		var scn: PackedScene = load(p)
		var node: Node = scn.instantiate()
		root.add_child(node)
		await process_frame
		var layer := node.get_node_or_null("NeonTileMap")
		if layer == null:
			# buscar cualquier TileMapLayer
			for child in node.get_children():
				if child is TileMapLayer:
					layer = child
					break
		print("=== " + p + " ===")
		if layer == null:
			print("  no TileMapLayer")
		else:
			var rect: Rect2i = layer.get_used_rect()
			print("  used_rect:", rect, " tile_size:", layer.tile_set.tile_size)
			# grilla de ocupacion
			var grid := {}
			for c in layer.get_used_cells():
				grid[Vector2i(c.x, c.y)] = true
			var miny := 99999
			var maxy := -99999
			for k in grid:
				miny = mini(miny, k.y)
				maxy = maxi(maxy, k.y)
			print("  y occupied range: ", miny, "..", maxy)
			# columnas libres de arriba a abajo (detectar techo)
			var s := ""
			for gy in range(miny, maxy + 1):
				var line := ""
				for gx in range(rect.position.x, rect.end.x):
					line += "#" if grid.has(Vector2i(gx, gy)) else "."
				s += "%4d %s\n" % [gy, line]
			FileAccess.open(("/tmp/map_%s.txt" % p.get_file()).replace(".tscn", ""), FileAccess.WRITE).store_string(s)
			print("  dumped to /tmp/map_", p.get_file().replace(".tscn", ""), ".txt")
		node.queue_free()
	quit(0)
