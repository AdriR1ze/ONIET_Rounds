class_name ContragolpeSismicoEffect
extends UpgradeEffect

@export var radius: float = 75.0
@export var damage_pct: float = 0.15


func on_parry(_bullet: Node, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("reproducir"):
		audio.reproducir("golpe", 0.12)

	var max_hp: float = 100.0
	var health_comp = player.get_node_or_null("HealthComponent")
	if health_comp != null and "max_health" in health_comp:
		max_hp = float(health_comp.max_health)
	var dmg: int = maxi(int(round(max_hp * damage_pct)), 5)

	var boom := Polygon2D.new()
	var pts := PackedVector2Array()
	for a in 16:
		var ang := float(a) / 16.0 * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	boom.polygon = pts
	boom.color = Color(1.0, 0.45, 0.1, 0.75)
	boom.global_position = p2d.global_position
	tree.current_scene.add_child(boom)
	var tween := boom.create_tween()
	tween.tween_property(boom, "modulate:a", 0.0, 0.22)
	tween.tween_callback(boom.queue_free)

	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			var target_p2d := p as Node2D
			if target_p2d.global_position.distance_to(p2d.global_position) <= radius:
				if p.has_method("hurt"):
					p.hurt(dmg, player)
				if p.has_method("apply_knockback"):
					var dir := (target_p2d.global_position - p2d.global_position).normalized()
					if dir.is_zero_approx():
						dir = Vector2.UP
					p.apply_knockback(dir, 320.0)
