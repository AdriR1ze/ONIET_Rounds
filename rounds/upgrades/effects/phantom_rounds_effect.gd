class_name PhantomRoundsEffect
extends UpgradeEffect


func on_fire(bullet: Node, _player: Node) -> void:
	# Give phantom bullets visual translucent purple glow from start
	var visual := bullet.get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate = Color(0.85, 0.5, 1.0, 0.85)
