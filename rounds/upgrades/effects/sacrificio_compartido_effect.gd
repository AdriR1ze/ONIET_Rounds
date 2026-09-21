class_name SacrificioCompartidoEffect
extends UpgradeEffect

@export var radius: float = 140.0
@export var damage_share_pct: float = 0.50


func on_healed(amount: int, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	var dmg: int = maxi(int(round(float(amount) * damage_share_pct)), 1)
	var pos := p2d.global_position

	# Pulso visual rojo oscuro al repartir daño
	var pulse := Line2D.new()
	pulse.width = 2.5
	pulse.default_color = Color(0.9, 0.1, 0.25, 0.8)
	var pts := PackedVector2Array()
	for a in 20:
		var ang := float(a) / 20.0 * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	pts.append(pts[0])
	pulse.points = pts
	pulse.global_position = pos
	tree.current_scene.add_child(pulse)
	var tween := pulse.create_tween()
	tween.tween_property(pulse, "modulate:a", 0.0, 0.35)
	tween.tween_callback(pulse.queue_free)

	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != player and p is Node2D:
			var target_p2d := p as Node2D
			if target_p2d.global_position.distance_to(pos) <= radius and p.has_method("hurt"):
				p.hurt(dmg, player)
