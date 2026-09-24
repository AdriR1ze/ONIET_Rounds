extends SceneTree

func _initialize() -> void:
	var dir := DirAccess.open("res://levels/maps")
	if dir == null:
		quit(1)
		return
	var paths: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tscn"):
			paths.append("res://levels/maps/" + f)
		f = dir.get_next()
	paths.sort()
	for p in paths:
		var scn: PackedScene = load(p)
		var node: Node = scn.instantiate()
		root.add_child(node)
		await process_frame
		var layer := node.get_node_or_null("NeonTileMap") as TileMapLayer
		print("=== %s ===" % p.get_file())
		if layer == null:
			print("  no NeonTileMap")
			node.queue_free()
			continue
		var rect: Rect2i = layer.get_used_rect()
		var grid: Dictionary = {}
		for c in layer.get_used_cells():
			grid[c] = true
		var miny := rect.position.y
		var maxy := rect.end.y - 1
		# filas completamente solidas (techos/pisos)
		var solid_rows: Array = []
		for gy in range(miny, maxy + 1):
			var full := true
			for gx in range(rect.position.x, rect.end.x):
				if not grid.has(Vector2i(gx, gy)):
					full = false
					break
			if full:
				solid_rows.append(gy)
		# superficie mas alta (techo) = primera fila solida desde arriba
		var techo: int = -99999
		for gy in range(miny, maxy + 1):
			var has := false
			for gx in range(rect.position.x, rect.end.x):
				if grid.has(Vector2i(gx, gy)):
					has = true
					break
			if has:
				techo = gy
				break
		var suelo := maxy
		print("  rect:", rect, " tile_size:", layer.tile_set.tile_size, " y:", miny, "..", maxy, " techo:", techo, " suelo:", suelo)
		print("  filas solidas completas:", solid_rows)
		node.queue_free()
	quit(0)
