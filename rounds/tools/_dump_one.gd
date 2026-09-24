extends SceneTree
var _args: PackedStringArray

func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	for a in _args:
		var scn: PackedScene = load(a)
		var node: Node = scn.instantiate()
		root.add_child(node)
		await process_frame
		var layer := node.get_node_or_null("NeonTileMap") as TileMapLayer
		if layer == null:
			for ch in node.get_children():
				if ch is TileMapLayer:
					layer = ch
					break
		var rect: Rect2i = layer.get_used_rect()
		var grid := {}
		for c in layer.get_used_cells():
			grid[Vector2i(c.x, c.y)] = true
		var s := ""
		var ys: Array = range(rect.position.y, rect.end.y)
		for gy in ys:
			var line := ""
			for gx in range(rect.position.x, rect.end.x):
				line += "#" if grid.has(Vector2i(gx, gy)) else "."
			s += "%4d %s\n" % [gy, line]
		var out := "/tmp/grid_%s.txt" % a.get_file().replace(".tscn", "")
		FileAccess.open(out, FileAccess.WRITE).store_string(s)
		print("dumped", out, " rect:", rect)
		node.queue_free()
	quit(0)
