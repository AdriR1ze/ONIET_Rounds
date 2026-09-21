class_name NexoVidaEffect
extends UpgradeEffect

var _cooldown_timer: float = 0.0


func on_process(delta: float, _player: Node) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func on_reload_started(player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = 4.5

	var p2d := player as Node2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	# Crear el tótem de vida visual en el suelo
	var totem := Node2D.new()
	totem.global_position = p2d.global_position

	# Gráfico del tótem (poste de madera / cristal esmeralda)
	var base := Polygon2D.new()
	base.color = Color(0.15, 0.75, 0.3, 0.85)
	base.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(3, -20), Vector2(-3, -20)
	])
	totem.add_child(base)

	var crystal := Polygon2D.new()
	crystal.color = Color(0.4, 1.0, 0.5, 0.95)
	crystal.polygon = PackedVector2Array([
		Vector2(0, -28), Vector2(6, -22), Vector2(0, -16), Vector2(-6, -22)
	])
	totem.add_child(crystal)

	tree.current_scene.add_child(totem)

	# El tótem cura al jugador durante 3 segundos
	_run_totem(totem, player)


func _run_totem(totem: Node2D, player: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var ticks := 6
	for i in ticks:
		if not is_instance_valid(totem) or not is_instance_valid(player):
			break
		await tree.create_timer(0.5, false).timeout
		if not is_instance_valid(totem) or not is_instance_valid(player):
			break
		if player.has_method("heal"):
			player.heal(4)

		# Pulso de curación esmeralda
		var ring := Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(0.3, 1.0, 0.45, 0.8)
		var pts := PackedVector2Array()
		for a in 16:
			var ang := float(a) / 16.0 * TAU
			pts.append(Vector2(cos(ang), sin(ang)) * 24.0)
		pts.append(pts[0])
		ring.points = pts
		totem.add_child(ring)
		var tw := ring.create_tween()
		tw.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.25)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(ring.queue_free)

	if is_instance_valid(totem):
		var tw := totem.create_tween()
		tw.tween_property(totem, "modulate:a", 0.0, 0.3)
		tw.tween_callback(totem.queue_free)
