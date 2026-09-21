class_name OndaChoqueEffect
extends UpgradeEffect

@export var radius: float = 90.0
@export var knockback_force: float = 420.0


func on_hit(shot: Shot, _target: Node, player: Node) -> void:
	if shot == null:
		return
	_emit_shockwave(shot.hit_position, player)


func on_body_hit(shot: Shot, _body: Node, player: Node) -> void:
	if shot == null or shot.bounces > 0:
		return
	_emit_shockwave(shot.hit_position, player)


func _emit_shockwave(pos: Vector2, player: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("reproducir"):
		audio.reproducir("golpe", 0.08)

	var wave := Line2D.new()
	wave.width = 3.5
	wave.default_color = Color(0.3, 0.85, 1.0, 0.9)
	var pts := PackedVector2Array()
	for a in 24:
		var ang := float(a) / 24.0 * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 12.0)
	pts.append(pts[0])
	wave.points = pts
	wave.global_position = pos
	tree.current_scene.add_child(wave)

	var tween := wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(radius / 12.0, radius / 12.0), 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(wave.queue_free)

	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			var p2d := p as Node2D
			var dist := p2d.global_position.distance_to(pos)
			if dist <= radius and p.has_method("apply_knockback"):
				var dir := (p2d.global_position - pos).normalized()
				if dir.is_zero_approx():
					dir = Vector2.UP
				p.apply_knockback(dir, knockback_force * (1.0 - dist / radius * 0.4))
