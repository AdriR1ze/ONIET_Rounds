class_name BalaAnclanteEffect
extends UpgradeEffect

@export var radius: float = 85.0
@export var slow_factor: float = 0.50
@export var slow_duration: float = 1.5


func on_hit(shot: Shot, _target: Node, player: Node) -> void:
	if shot == null:
		return
	_apply_area_slow(shot.hit_position, player)


func on_body_hit(shot: Shot, _body: Node, player: Node) -> void:
	if shot == null or shot.bounces > 0:
		return
	_apply_area_slow(shot.hit_position, player)


func _apply_area_slow(pos: Vector2, player: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.2, 0.6, 1.0, 0.85)
	var pts := PackedVector2Array()
	for a in 20:
		var ang := float(a) / 20.0 * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	pts.append(pts[0])
	ring.points = pts
	ring.global_position = pos
	tree.current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			var p2d := p as Node2D
			if p2d.global_position.distance_to(pos) <= radius and p.has_method("apply_slow"):
				p.apply_slow(slow_factor, slow_duration)
