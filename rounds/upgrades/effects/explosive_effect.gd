class_name ExplosiveEffect
extends UpgradeEffect

@export var radius: float = 60.0
@export var damage: int = 15


func on_hit(shot: Shot, _target: Node, player: Node) -> void:
	if shot == null:
		return
	_explode(shot.hit_position, player, shot.damage)


func on_body_hit(shot: Shot, _body: Node, player: Node) -> void:
	if shot == null:
		return
	if shot.bounces > 0:
		return
	print(shot.damage)
	_explode(shot.hit_position, player, shot.damage)


func _explode(pos: Vector2, player: Node, shot_damage) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("reproducir"):
		audio.reproducir("golpe", 0.08)

	var boom := Polygon2D.new()
	var pts: PackedVector2Array = []
	for a in 16:
		var ang := float(a) / 16.0 * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	boom.polygon = pts
	boom.color = Color(1.0, 0.5, 0.1, 0.75)
	boom.global_position = pos
	tree.current_scene.add_child(boom)
	var tween := boom.create_tween()
	tween.tween_property(boom, "modulate:a", 0.0, 0.22)
	tween.tween_callback(boom.queue_free)

	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			if (p as Node2D).global_position.distance_to(pos) <= radius:
				if p.has_method("hurt"):
					p.hurt((shot_damage / 25) * 15, player)
				if p.has_method("apply_knockback"):
					var dir := ((p as Node2D).global_position - pos).normalized()
					if dir.is_zero_approx():
						dir = Vector2.UP
					p.apply_knockback(dir, 220.0)
