class_name ZonaGravedadEffect
extends UpgradeEffect

@export var radius: float = 140.0
@export var gravity_scale: float = 1.90
@export var jump_multiplier: float = 0.45
@export var slow_factor: float = 0.65

var _aura_node: Node2D = null


class GravityZoneAura extends Node2D:
	var owner_player: Node = null
	var zone_radius: float = 140.0
	var _time: float = 0.0

	func _process(delta: float) -> void:
		if owner_player == null or not is_instance_valid(owner_player):
			queue_free()
			return
		if owner_player.has_method("is_alive") and not owner_player.is_alive():
			visible = false
			return
		visible = true
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := sin(_time * 4.0)
		# Campo violeta traslúcido
		var bg_col := Color(0.55, 0.18, 0.95, 0.07 + 0.03 * pulse)
		draw_circle(Vector2.ZERO, zone_radius, bg_col)
		# Borde exterior de la zona
		var border_col := Color(0.65, 0.28, 1.0, 0.38 + 0.15 * pulse)
		draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 48, border_col, 2.0)

		# Ondas gravitatorias descendentes (flechas y líneas indicando fuerte gravedad hacia abajo)
		for i in range(5):
			var x_offset: float = (float(i) - 2.0) * (zone_radius * 0.32)
			var y_phase: float = fmod(_time * 65.0 + float(i) * 28.0, zone_radius * 1.5) - zone_radius * 0.75
			var line_len: float = 18.0
			var arrow_alpha: float = clampf(1.0 - absf(y_phase) / (zone_radius * 0.8), 0.0, 0.65)
			var line_col := Color(0.75, 0.35, 1.0, arrow_alpha)
			draw_line(Vector2(x_offset, y_phase), Vector2(x_offset, y_phase + line_len), line_col, 2.0)
			draw_line(Vector2(x_offset - 3.5, y_phase + line_len - 3.5), Vector2(x_offset, y_phase + line_len), line_col, 1.5)
			draw_line(Vector2(x_offset + 3.5, y_phase + line_len - 3.5), Vector2(x_offset, y_phase + line_len), line_col, 1.5)


func on_apply(player: Node, _stacks: int) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	if not is_instance_valid(_aura_node):
		var aura := GravityZoneAura.new()
		aura.owner_player = player
		aura.zone_radius = radius
		_aura_node = aura
		player.add_child(aura)


func on_process(_delta: float, player: Node) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var p2d := player as Node2D
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	# Asegurar aura visual si aún no existe
	if not is_instance_valid(_aura_node):
		var aura := GravityZoneAura.new()
		aura.owner_player = player
		aura.zone_radius = radius
		_aura_node = aura
		player.add_child(aura)

	var my_pos := p2d.global_position
	for p in tree.get_nodes_in_group("player"):
		if not is_instance_valid(p) or p == player or not (p is CharacterBody2D):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		var target_p := p as CharacterBody2D
		var dist := my_pos.distance_to(target_p.global_position)
		if dist <= radius:
			# 1. Mayor gravedad y menor salto al rival
			if target_p.has_method("apply_gravity_debuff"):
				target_p.apply_gravity_debuff(gravity_scale, jump_multiplier, 0.20)
			# 2. Mayor lentitud de movimiento al rival
			if target_p.has_method("apply_slow"):
				target_p.apply_slow(slow_factor, 0.20)
