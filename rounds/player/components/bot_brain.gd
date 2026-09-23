class_name BotBrain
extends Node

var player: CharacterBody2D = null
var player_number: int = 1
var dificultad: int = 2

# Estados simulados de entrada
var _move_axis: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _jump_just_pressed: bool = false
var _jump_just_released: bool = false
var _fire_pressed: bool = false
var _ragdoll_just_pressed: bool = false

# Timers y estados internos de IA
var _parry_cooldown_timer: float = 0.0
var _bullet_parry_decisions: Dictionary = {}
var _shoot_delay_timer: float = 0.0
var _tactical_jump_timer: float = 0.0
var _strafe_timer: float = 0.0
var _strafe_dir: float = 1.0
var _current_spread: float = 0.0
var _spread_timer: float = 0.0
var _blocked_time: float = 0.0


func _ready() -> void:
	var p = get_parent().get_parent()
	if p is CharacterBody2D:
		player = p
		player_number = int(player.get("player_number"))
	dificultad = RunManager.dificultad_bot
	_tactical_jump_timer = randf_range(1.0, 2.5)


func get_move_axis() -> float:
	return _move_axis


func get_aim() -> Vector2:
	return _aim_dir


func is_jump_just_pressed() -> bool:
	return _jump_just_pressed


func is_jump_just_released() -> bool:
	return _jump_just_released


func is_fire_pressed() -> bool:
	return _fire_pressed


func is_ragdoll_just_pressed() -> bool:
	return _ragdoll_just_pressed


func _physics_process(delta: float) -> void:
	_jump_just_pressed = false
	_jump_just_released = false
	_ragdoll_just_pressed = false

	if player == null or not is_instance_valid(player):
		_move_axis = 0.0
		_fire_pressed = false
		return

	if player.has_method("is_alive") and not player.is_alive():
		_move_axis = 0.0
		_fire_pressed = false
		return

	if player.get("can_control") == false:
		_move_axis = 0.0
		_fire_pressed = false
		return

	dificultad = RunManager.dificultad_bot
	_parry_cooldown_timer = maxf(_parry_cooldown_timer - delta, 0.0)

	# Limpiar registro de balas periódicamente
	if _bullet_parry_decisions.size() > 40:
		_limpiar_registro_balas()

	# 1. Chequeo de Parry reactivo calibrado (evaluación única por bala + cooldown)
	_check_parry(delta)

	# 2. Búsqueda de objetivo enemigo vivo
	var target: CharacterBody2D = _find_target()
	if target == null:
		_move_axis = 0.0
		_fire_pressed = false
		return

	# 3. Navegación, movimiento y prevención de caídas al vacío
	_update_movement(target, delta)

	# 4. Apuntado predictivo según dificultad
	_update_aim(target, delta)

	# 5. Lógica de disparo
	_update_shooting(target, delta)


func _limpiar_registro_balas() -> void:
	var keys_to_remove: Array = []
	for b_id in _bullet_parry_decisions:
		var instance = instance_from_id(b_id)
		if instance == null or not is_instance_valid(instance):
			keys_to_remove.append(b_id)
	for k in keys_to_remove:
		_bullet_parry_decisions.erase(k)


func _find_target() -> CharacterBody2D:
	var closest: CharacterBody2D = null
	var min_dist := INF
	var my_pos := player.global_position

	for p in RunManager.jugadores_activos():
		if not is_instance_valid(p) or p == player or not (p is CharacterBody2D):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		var d := my_pos.distance_squared_to(p.global_position)
		if d < min_dist:
			min_dist = d
			closest = p

	return closest


func _check_parry(_delta: float) -> void:
	if player.has_method("is_spinning") and player.is_spinning():
		return
	if player.get("can_control") == false:
		return
	if _parry_cooldown_timer > 0.0:
		return

	var bullets := get_tree().get_nodes_in_group("bullet")
	if bullets.is_empty():
		return

	var my_pos := player.global_position

	for b in bullets:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		if b.get("shooter") == player:
			continue
		var b_vel: Vector2 = b.get("velocity") if "velocity" in b else Vector2.ZERO
		if b_vel.length_squared() < 100.0:
			continue

		var to_player: Vector2 = my_pos - b.global_position
		var dist := to_player.length()

		# Solo evaluar balas en un radio de peligro razonable
		if dist > 260.0:
			continue

		var b_speed := b_vel.length()
		var heading_dot := b_vel.normalized().dot(to_player.normalized())

		# La bala debe estar desplazándose hacia el jugador
		if heading_dot < 0.48:
			continue

		var time_to_hit := dist / b_speed
		var b_id: int = b.get_instance_id()

		# DECISIÓN ÚNICA POR BALA (evita evaluar randf() 60 veces por segundo para el mismo proyectil)
		if not _bullet_parry_decisions.has(b_id):
			var parry_chance := 0.0
			match dificultad:
				RunManager.DificultadBot.HACKER:
					parry_chance = 0.65
				RunManager.DificultadBot.MUY_DIFICIL:
					parry_chance = 0.45
				RunManager.DificultadBot.DIFICIL:
					parry_chance = 0.30
				RunManager.DificultadBot.MEDIO:
					parry_chance = 0.18
				RunManager.DificultadBot.FACIL:
					parry_chance = 0.08
				RunManager.DificultadBot.MUY_FACIL:
					parry_chance = 0.0

			_bullet_parry_decisions[b_id] = (randf() < parry_chance)

		# Si esta bala fue asignada para ser parada por el bot:
		if _bullet_parry_decisions[b_id]:
			var trigger_window := 0.16
			match dificultad:
				RunManager.DificultadBot.HACKER:
					trigger_window = 0.18
				RunManager.DificultadBot.MUY_DIFICIL:
					trigger_window = 0.17
				RunManager.DificultadBot.DIFICIL:
					trigger_window = 0.15
				RunManager.DificultadBot.MEDIO:
					trigger_window = 0.13
				_:
					trigger_window = 0.11

			if time_to_hit <= trigger_window:
				_ragdoll_just_pressed = true
				_bullet_parry_decisions[b_id] = false # Ya ejecutó el parry para esta bala

				# Cooldown para no parrear ráfagas continuas de forma injusta
				match dificultad:
					RunManager.DificultadBot.HACKER:
						_parry_cooldown_timer = 1.2
					RunManager.DificultadBot.MUY_DIFICIL:
						_parry_cooldown_timer = 1.8
					RunManager.DificultadBot.DIFICIL:
						_parry_cooldown_timer = 2.4
					RunManager.DificultadBot.MEDIO:
						_parry_cooldown_timer = 3.2
					_:
						_parry_cooldown_timer = 4.5
				return


func _update_aim(target: CharacterBody2D, delta: float) -> void:
	var my_pos := player.global_position
	var target_pos := target.global_position
	var target_vel := target.velocity
	var dist := my_pos.distance_to(target_pos)

	var bullet_speed := 1050.0
	if player.get("_stats") != null:
		var s: float = float(player._stats.get_stat(&"bullet_speed"))
		if s > 100.0:
			bullet_speed = s

	var predicted_pos := target_pos

	match dificultad:
		RunManager.DificultadBot.HACKER:
			# Puntería predictiva de 2 pasos exacta (alta precisión)
			var t1 := dist / bullet_speed
			var p1 := target_pos + target_vel * t1
			var t2 := my_pos.distance_to(p1) / bullet_speed
			predicted_pos = target_pos + target_vel * t2
			predicted_pos.y -= 0.5 * 1200.0 * (t2 * t2) * 0.35
			_aim_dir = (predicted_pos - my_pos).normalized()
			return

		RunManager.DificultadBot.MUY_DIFICIL:
			var t := (dist / bullet_speed) * 0.95
			predicted_pos = target_pos + target_vel * t
			predicted_pos.y -= 0.5 * 1200.0 * (t * t) * 0.25

		RunManager.DificultadBot.DIFICIL:
			var t := (dist / bullet_speed) * 0.75
			predicted_pos = target_pos + target_vel * t

		RunManager.DificultadBot.MEDIO:
			var t := (dist / bullet_speed) * 0.40
			predicted_pos = target_pos + target_vel * t

		RunManager.DificultadBot.FACIL, RunManager.DificultadBot.MUY_FACIL:
			predicted_pos = target_pos

	# Dispersión y retraso de seguimiento según dificultad
	_spread_timer -= delta
	if _spread_timer <= 0.0:
		_spread_timer = randf_range(0.15, 0.45)
		var max_spread := 0.0
		match dificultad:
			RunManager.DificultadBot.MUY_DIFICIL:
				max_spread = deg_to_rad(2.0)
			RunManager.DificultadBot.DIFICIL:
				max_spread = deg_to_rad(5.0)
			RunManager.DificultadBot.MEDIO:
				max_spread = deg_to_rad(12.0)
			RunManager.DificultadBot.FACIL:
				max_spread = deg_to_rad(22.0)
			RunManager.DificultadBot.MUY_FACIL:
				max_spread = deg_to_rad(35.0)
		_current_spread = randf_range(-max_spread, max_spread)

	var desired_aim := (predicted_pos - my_pos).normalized().rotated(_current_spread)
	var tracking_speed := 15.0
	match dificultad:
		RunManager.DificultadBot.MUY_DIFICIL:
			tracking_speed = 30.0
		RunManager.DificultadBot.DIFICIL:
			tracking_speed = 18.0
		RunManager.DificultadBot.MEDIO:
			tracking_speed = 9.0
		RunManager.DificultadBot.FACIL:
			tracking_speed = 4.5
		RunManager.DificultadBot.MUY_FACIL:
			tracking_speed = 2.5

	_aim_dir = _aim_dir.slerp(desired_aim, clampf(tracking_speed * delta, 0.0, 1.0)).normalized()


func _update_shooting(target: CharacterBody2D, delta: float) -> void:
	var my_pos := player.global_position
	var to_target := (target.global_position - my_pos).normalized()
	var angle_diff := absf(_aim_dir.angle_to(to_target))

	_shoot_delay_timer = maxf(_shoot_delay_timer - delta, 0.0)

	match dificultad:
		RunManager.DificultadBot.HACKER:
			_fire_pressed = (angle_diff < deg_to_rad(18.0))

		RunManager.DificultadBot.MUY_DIFICIL:
			if angle_diff < deg_to_rad(16.0):
				if _shoot_delay_timer <= 0.0:
					_fire_pressed = true
					if randf() < 0.1:
						_shoot_delay_timer = randf_range(0.05, 0.15)
				else:
					_fire_pressed = false
			else:
				_fire_pressed = false

		RunManager.DificultadBot.DIFICIL:
			if angle_diff < deg_to_rad(20.0):
				if _shoot_delay_timer <= 0.0:
					_fire_pressed = true
					if randf() < 0.2:
						_shoot_delay_timer = randf_range(0.1, 0.25)
				else:
					_fire_pressed = false
			else:
				_fire_pressed = false

		RunManager.DificultadBot.MEDIO:
			if angle_diff < deg_to_rad(25.0):
				if _shoot_delay_timer <= 0.0:
					_fire_pressed = true
					if randf() < 0.35:
						_shoot_delay_timer = randf_range(0.2, 0.5)
				else:
					_fire_pressed = false
			else:
				_fire_pressed = false

		RunManager.DificultadBot.FACIL:
			if angle_diff < deg_to_rad(32.0):
				if _shoot_delay_timer <= 0.0:
					_fire_pressed = true
					if randf() < 0.5:
						_shoot_delay_timer = randf_range(0.4, 0.9)
				else:
					_fire_pressed = false
			else:
				_fire_pressed = false

		RunManager.DificultadBot.MUY_FACIL:
			if angle_diff < deg_to_rad(40.0):
				if _shoot_delay_timer <= 0.0:
					_fire_pressed = true
					_shoot_delay_timer = randf_range(0.7, 1.5)
				else:
					_fire_pressed = false
			else:
				_fire_pressed = false


func _update_movement(target: CharacterBody2D, delta: float) -> void:
	var my_pos := player.global_position
	var target_pos := target.global_position
	var dist := my_pos.distance_to(target_pos)
	var dir_to_target_x := signf(target_pos.x - my_pos.x)

	var opt_dist_min := 160.0
	var opt_dist_max := 280.0

	if dificultad == RunManager.DificultadBot.HACKER:
		opt_dist_min = 180.0
		opt_dist_max = 260.0

	# 1. Distancia y posicionamiento deseado
	if dist > opt_dist_max:
		_move_axis = dir_to_target_x
	elif dist < opt_dist_min:
		_move_axis = -dir_to_target_x
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(0.4, 1.2)
			_strafe_dir = -_strafe_dir if randf() < 0.6 else _strafe_dir
		_move_axis = _strafe_dir * (0.8 if dificultad >= RunManager.DificultadBot.DIFICIL else 0.5)

	# 2. Detección y evasión de precipicios / vacío en el mapa
	_evitar_abismo(delta)

	# 3. Detección de atasco contra pared o escalón
	if player.is_on_floor() and absf(_move_axis) > 0.2:
		if absf(player.velocity.x) < 25.0:
			_blocked_time += delta
			if _blocked_time > 0.15:
				_jump_just_pressed = true
				_blocked_time = 0.0
		else:
			_blocked_time = 0.0
	else:
		_blocked_time = 0.0

	# 4. Salto vertical si el objetivo está en plataformas más altas
	if target_pos.y < my_pos.y - 70.0 and absf(target_pos.x - my_pos.x) < 380.0:
		if player.is_on_floor() and _hay_suelo(my_pos, 80.0) and randf() < (0.85 if dificultad >= RunManager.DificultadBot.DIFICIL else 0.4):
			_jump_just_pressed = true

	# 5. Salto táctico periódico en dificultades altas (solo si está seguro en el centro de la plataforma)
	if dificultad >= RunManager.DificultadBot.DIFICIL:
		_tactical_jump_timer -= delta
		if _tactical_jump_timer <= 0.0:
			_tactical_jump_timer = randf_range(1.4, 3.0)
			if player.is_on_floor() and _hay_suelo(my_pos + Vector2(-45.0, 12.0), 90.0) and _hay_suelo(my_pos + Vector2(45.0, 12.0), 90.0) and randf() < 0.70:
				_jump_just_pressed = true


const Y_LIMITE_MUERTE := 635.0


func _evitar_abismo(_delta: float) -> void:
	var my_pos := player.global_position
	var move_dir := signf(_move_axis)

	# Límites extremos del mapa (bordes de pantalla)
	if my_pos.x < 190.0 and move_dir < 0.0:
		_move_axis = 1.0
		if player.is_on_floor() and player.velocity.x < -30.0:
			player.velocity.x = 0.0
		return
	elif my_pos.x > 1090.0 and move_dir > 0.0:
		_move_axis = -1.0
		if player.is_on_floor() and player.velocity.x > 30.0:
			player.velocity.x = 0.0
		return

	# Si está en el suelo y moviéndose: sondear si hay suelo delante
	if player.is_on_floor() and not is_zero_approx(move_dir):
		# Lookahead dinámico según velocidad
		var lookahead: float = clampf(absf(player.velocity.x) * 0.28 + 36.0, 36.0, 80.0)
		var probe_cerca := Vector2(my_pos.x + move_dir * 22.0, my_pos.y + 12.0)
		var probe_lejos := Vector2(my_pos.x + move_dir * lookahead, my_pos.y + 12.0)

		var hay_suelo_cerca := _hay_suelo(probe_cerca, 130.0)
		var hay_suelo_lejos := _hay_suelo(probe_lejos, 130.0)

		if not hay_suelo_cerca or not hay_suelo_lejos:
			# Detectó precipicio o final de plataforma
			# Comprobar si hay una plataforma accesible para un salto seguro
			var salto_seguro := false
			for d_salto in [110.0, 150.0]:
				var test_landing := Vector2(my_pos.x + move_dir * d_salto, my_pos.y - 20.0)
				if _hay_suelo(test_landing, 100.0):
					salto_seguro = true
					break

			if salto_seguro and absf(player.velocity.x) > 100.0:
				# Solo saltar si tiene inercia hacia adelante y la plataforma está confirmada
				_jump_just_pressed = true
			else:
				# Si no hay salto seguro garantizado: FRENAR DE FORMA ROTUNDA
				_move_axis = -move_dir
				if absf(player.velocity.x) > 20.0 and signf(player.velocity.x) == move_dir:
					player.velocity.x *= 0.25 # Frenar inercia para no resbalar

	# Si está en el aire (saltando o empujado):
	elif not player.is_on_floor():
		var suelo_debajo := _hay_suelo(my_pos, 220.0)
		if not suelo_debajo:
			# Está sobre el vacío: buscar la plataforma más cercana a los lados
			var hay_izq := _hay_suelo(Vector2(my_pos.x - 70.0, my_pos.y), 220.0)
			var hay_der := _hay_suelo(Vector2(my_pos.x + 70.0, my_pos.y), 220.0)
			if hay_izq and not hay_der:
				_move_axis = -1.0
			elif hay_der and not hay_izq:
				_move_axis = 1.0
			elif not hay_izq and not hay_der:
				var hay_izq_lejos := _hay_suelo(Vector2(my_pos.x - 140.0, my_pos.y), 240.0)
				var hay_der_lejos := _hay_suelo(Vector2(my_pos.x + 140.0, my_pos.y), 240.0)
				if hay_izq_lejos and not hay_der_lejos:
					_move_axis = -1.0
				elif hay_der_lejos and not hay_izq_lejos:
					_move_axis = 1.0


func _hay_suelo(origen: Vector2, distancia_abajo: float) -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(origen, origen + Vector2(0.0, distancia_abajo), 1)
	query.exclude = [player.get_rid()]
	var res := space.intersect_ray(query)
	if res.is_empty():
		return false
	var hit_pos: Vector2 = res.get("position", Vector2.ZERO)
	if hit_pos.y >= Y_LIMITE_MUERTE:
		return false
	return true
