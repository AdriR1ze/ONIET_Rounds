class_name BotBrain
extends Node

## Cerebro táctico del Bot basado en Behavior Trees (BT) y Steering Behaviors.
## - Behavior Tree: Gobierna las decisiones tácticas, secuencias temporales y estados
##   (¿QUÉ hacer?: Parry, apuntar con balística, evitar disparar a paredes, escalar muros,
##   usar cuerdas de trepar/balanceo, atravesar plataformas one-way y abrir puertas).
## - Steering Behaviors: Gobierna las fuerzas físicas motoras inmediatas (¿CÓMO desplazarse?:
##   Seek, Flee, Arrive, Strafe, Path Following y detección de peligros).

enum DifficultyTier { FACIL, MEDIO, DIFICIL }

var player: CharacterBody2D = null
var player_number: int = 1
var dificultad: int = 2

# Estados simulados de entrada expuestos a PlayerInput
var _move_axis: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _jump_just_pressed: bool = false
var _jump_just_released: bool = false
var _fire_pressed: bool = false
var _ragdoll_just_pressed: bool = false
var _crouch_pressed: bool = false
var _up_pressed: bool = false

const BotSteeringScript = preload("res://player/components/bot_steering.gd")

# Behavior Tree y Navegación
var _tree: BTNode = null
var _target: CharacterBody2D = null
var _steering = null
var _nav_graph: NavGraph = null
var _current_path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _path_update_timer: float = 0.0
var _cached_tilemap: TileMapLayer = null

# Timers y estados tácticos
var _parry_cooldown_timer: float = 0.0
var _bullet_parry_decisions: Dictionary = {}
var _shoot_delay_timer: float = 0.0
var _tactical_jump_timer: float = 0.0
var _strafe_timer: float = 0.0
var _strafe_dir: float = 1.0
var _current_spread: float = 0.0
var _spread_timer: float = 0.0
var _blocked_time: float = 0.0
var _edge_turnaround_timer: float = 0.0
var _edge_safe_dir: float = 0.0
var _wall_slide_timer: float = 0.0
var _wall_jump_cooldown: float = 0.0
var _platform_drop_cooldown: float = 0.0


func _ready() -> void:
	var p = get_parent().get_parent()
	if p is CharacterBody2D:
		player = p
		player_number = int(player.get("player_number"))
	dificultad = RunManager.dificultad_bot
	_steering = BotSteeringScript.new()
	_tactical_jump_timer = randf_range(1.0, 2.5)

	_tree = BTSelector.new([
		BTSequence.new([
			BTLeaf.new(Callable(self, "_bt_can_act")),
			BTSelector.new([
				# 1. Interrupción de Parry (Máxima prioridad reactiva)
				BTLeaf.new(Callable(self, "_bt_check_parry")),
				# 2. Evaluación Táctica, Apuntado y Movimiento
				BTSequence.new([
					BTLeaf.new(Callable(self, "_bt_find_target")),
					BTLeaf.new(Callable(self, "_bt_update_aim")),
					BTLeaf.new(Callable(self, "_bt_update_shooting")),
					BTSelector.new([
						BTLeaf.new(Callable(self, "_bt_handle_climbing_rope")),
						BTLeaf.new(Callable(self, "_bt_handle_swinging_rope")),
						BTLeaf.new(Callable(self, "_bt_handle_wall_jump")),
						BTLeaf.new(Callable(self, "_bt_handle_doors")),
						BTLeaf.new(Callable(self, "_bt_handle_hazard_avoidance")),
						BTLeaf.new(Callable(self, "_bt_handle_one_way_platform")),
						BTLeaf.new(Callable(self, "_bt_handle_navigation_and_spacing")),
					]),
				]),
			]),
		]),
		BTLeaf.new(Callable(self, "_bt_stop")),
	])


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


func is_crouch_pressed() -> bool:
	return _crouch_pressed


func is_up_pressed() -> bool:
	return _up_pressed


func _physics_process(delta: float) -> void:
	_jump_just_pressed = false
	_jump_just_released = false
	_ragdoll_just_pressed = false
	_crouch_pressed = false
	_up_pressed = false

	if _tree != null:
		_tree.tick(delta)


func _get_difficulty_tier() -> int:
	match dificultad:
		RunManager.DificultadBot.MUY_FACIL, RunManager.DificultadBot.FACIL:
			return DifficultyTier.FACIL
		RunManager.DificultadBot.MEDIO:
			return DifficultyTier.MEDIO
		_: # DIFICIL, MUY_DIFICIL, HACKER
			return DifficultyTier.DIFICIL


# ==============================================================================
# NODOS DEL BEHAVIOR TREE (BT)
# ==============================================================================

## Condición de activación: ¿El bot puede actuar en este momento?
func _bt_can_act(_delta: float) -> int:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return BTNode.Status.FAILURE
	if player.has_method("is_alive") and not player.is_alive():
		return BTNode.Status.FAILURE
	if player.get("can_control") == false:
		return BTNode.Status.FAILURE
	return BTNode.Status.SUCCESS


## Acción de parada: Reinicia los inputs si el bot no puede actuar.
func _bt_stop(_delta: float) -> int:
	_move_axis = 0.0
	_fire_pressed = false
	_crouch_pressed = false
	_up_pressed = false
	return BTNode.Status.SUCCESS


## Interrupción reactiva de Parry: Comprueba proyectiles hostiles en trayectoria de colisión.
func _bt_check_parry(delta: float) -> int:
	_parry_cooldown_timer = maxf(_parry_cooldown_timer - delta, 0.0)
	if _bullet_parry_decisions.size() > 40:
		_limpiar_registro_balas()

	if player.has_method("is_spinning") and player.is_spinning():
		return BTNode.Status.FAILURE
	if player.get("can_control") == false or _parry_cooldown_timer > 0.0:
		return BTNode.Status.FAILURE

	var bullets := get_tree().get_nodes_in_group("bullet")
	if bullets.is_empty():
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	var tier := _get_difficulty_tier()

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
		if dist > 260.0:
			continue

		var b_speed := b_vel.length()
		var heading_dot := b_vel.normalized().dot(to_player.normalized())
		if heading_dot < 0.48:
			continue

		var time_to_hit := dist / b_speed
		var b_id: int = b.get_instance_id()

		if not _bullet_parry_decisions.has(b_id):
			var parry_chance := 0.0
			match tier:
				DifficultyTier.DIFICIL:
					parry_chance = 0.55 if dificultad == RunManager.DificultadBot.HACKER else 0.35
				DifficultyTier.MEDIO:
					parry_chance = 0.20
				DifficultyTier.FACIL:
					parry_chance = 0.06
			_bullet_parry_decisions[b_id] = (randf() < parry_chance)

		if _bullet_parry_decisions[b_id]:
			var trigger_window := 0.16 if tier == DifficultyTier.DIFICIL else (0.13 if tier == DifficultyTier.MEDIO else 0.11)
			if time_to_hit <= trigger_window:
				_ragdoll_just_pressed = true
				_aim_dir = (b.global_position - my_pos).normalized()
				_bullet_parry_decisions[b_id] = false

				match tier:
					DifficultyTier.DIFICIL:
						_parry_cooldown_timer = 1.4
					DifficultyTier.MEDIO:
						_parry_cooldown_timer = 2.6
					DifficultyTier.FACIL:
						_parry_cooldown_timer = 4.2

				# Interrumpe y consume este tick como acción de emergencia
				return BTNode.Status.SUCCESS
		elif time_to_hit <= 0.22 and player.is_on_floor():
			# Esquiva reactiva humana por salto y desplazamiento lateral
			_jump_just_pressed = true
			_move_axis = -signf(b_vel.x)

	return BTNode.Status.FAILURE


## Localiza el oponente activo más cercano.
func _bt_find_target(_delta: float) -> int:
	_target = _find_target()
	return BTNode.Status.SUCCESS if _target != null else BTNode.Status.FAILURE


## Calcula la puntería balística y dispersión según dificultad.
func _bt_update_aim(delta: float) -> int:
	if _target == null:
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	var target_pos := _target.global_position
	var target_vel := _target.velocity
	var dist := my_pos.distance_to(target_pos)

	var bullet_speed := 1050.0
	if player.get("_stats") != null:
		var s: float = float(player._stats.get_stat(&"bullet_speed"))
		if s > 100.0:
			bullet_speed = s

	var tier := _get_difficulty_tier()
	var desired_aim := Vector2.RIGHT

	# 1. Ángulo balístico
	var solved_angle := Ballistics.solve_launch_angle(my_pos, target_pos, bullet_speed, 1000.0)

	if tier == DifficultyTier.DIFICIL:
		var t := dist / bullet_speed
		var predicted_pos := target_pos + target_vel * (t * 0.85)
		var lead_angle := Ballistics.solve_launch_angle(my_pos, predicted_pos, bullet_speed, 1000.0)
		if not is_nan(lead_angle):
			desired_aim = Vector2(cos(lead_angle), sin(lead_angle))
		elif not is_nan(solved_angle):
			desired_aim = Vector2(cos(solved_angle), sin(solved_angle))
		else:
			desired_aim = (target_pos - my_pos).normalized()
	elif tier == DifficultyTier.MEDIO:
		if not is_nan(solved_angle):
			desired_aim = Vector2(cos(solved_angle), sin(solved_angle))
		else:
			desired_aim = (target_pos - my_pos).normalized()
	else:
		desired_aim = (target_pos - my_pos).normalized()

	# 2. Dispersión y suavizado de seguimiento
	_spread_timer -= delta
	if _spread_timer <= 0.0:
		_spread_timer = randf_range(0.2, 0.5)
		var max_spread := 0.0
		match tier:
			DifficultyTier.DIFICIL:
				max_spread = deg_to_rad(2.0)
			DifficultyTier.MEDIO:
				max_spread = deg_to_rad(8.0)
			DifficultyTier.FACIL:
				max_spread = deg_to_rad(20.0)
		_current_spread = randf_range(-max_spread, max_spread)

	desired_aim = desired_aim.rotated(_current_spread)

	var tracking_speed := 25.0 if tier == DifficultyTier.DIFICIL else (12.0 if tier == DifficultyTier.MEDIO else 5.0)
	_aim_dir = _aim_dir.slerp(desired_aim, clampf(tracking_speed * delta, 0.0, 1.0)).normalized()

	return BTNode.Status.SUCCESS


## Disparo táctico: ¡NUNCA dispara a través de paredes ni puertas cerradas!
func _bt_update_shooting(delta: float) -> int:
	if _target == null:
		_fire_pressed = false
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	var target_pos := _target.global_position

	_shoot_delay_timer = maxf(_shoot_delay_timer - delta, 0.0)

	# 1. VERIFICACIÓN DE LÍNEA DE VISIÓN: Raycast contra muros (máscara 1) y puertas
	if not _has_line_of_sight(my_pos, target_pos):
		_fire_pressed = false
		return BTNode.Status.SUCCESS

	# 2. VERIFICACIÓN DE TRAYECTORIA BALÍSTICA
	var space := player.get_world_2d().direct_space_state
	if space != null:
		var bullet_speed := 1050.0
		if player.get("_stats") != null:
			var s: float = float(player._stats.get_stat(&"bullet_speed"))
			if s > 100.0:
				bullet_speed = s
		var arc_res := Ballistics.can_hit(space, my_pos, target_pos, bullet_speed, 1000.0, 1.8, 1, [player.get_rid()])
		if not arc_res.feasible and arc_res.reason == "blocked":
			_fire_pressed = false
			return BTNode.Status.SUCCESS

	# 3. Alineación angular y cadencia de disparo
	var to_target := (target_pos - my_pos).normalized()
	var angle_diff := absf(_aim_dir.angle_to(to_target))
	var tier := _get_difficulty_tier()

	var max_angle_threshold := deg_to_rad(18.0) if tier == DifficultyTier.DIFICIL else (deg_to_rad(24.0) if tier == DifficultyTier.MEDIO else deg_to_rad(34.0))

	if angle_diff < max_angle_threshold:
		if _shoot_delay_timer <= 0.0:
			_fire_pressed = true
			if tier == DifficultyTier.FACIL:
				_shoot_delay_timer = randf_range(0.4, 0.9)
			elif tier == DifficultyTier.MEDIO and randf() < 0.3:
				_shoot_delay_timer = randf_range(0.15, 0.35)
		else:
			_fire_pressed = false
	else:
		_fire_pressed = false

	return BTNode.Status.SUCCESS


## Evasión de abismo y pinchos: Frena rotundamente ante precipicios o pinchos.
func _bt_handle_hazard_avoidance(delta: float) -> int:
	# Si ya está en maniobra de retroceso por borde:
	if _edge_turnaround_timer > 0.0:
		_edge_turnaround_timer -= delta
		_move_axis = _edge_safe_dir
		return BTNode.Status.SUCCESS

	if player.is_on_floor():
		var move_dir := signf(_move_axis)
		if not is_zero_approx(move_dir):
			var space := player.get_world_2d().direct_space_state
			var lookahead: float = clampf(absf(player.velocity.x) * 0.28 + 36.0, 36.0, 80.0)
			var hazard_info: Dictionary = _steering.check_hazard_ahead(space, player, move_dir, lookahead, _get_tilemap())

			if hazard_info.hazard_ahead:
				# Si el bot tiene una ruta activa para cruzar a la siguiente plataforma:
				# Saltar hacia adelante con el impulso completo hacia el waypoint
				if not _current_path.is_empty() and _path_index < _current_path.size():
					var next_wp: Vector2 = _current_path[_path_index]
					if signf(next_wp.x - player.global_position.x) == move_dir:
						_jump_just_pressed = true
						_move_axis = move_dir
						return BTNode.Status.SUCCESS

				if hazard_info.safe_jump_available:
					# Salto seguro hacia adelante para cruzar a la repisa
					_jump_just_pressed = true
					_move_axis = move_dir
					return BTNode.Status.SUCCESS
				else:
					# Freno absoluto y giro en U solo si el abismo no es franqueable
					_edge_safe_dir = -move_dir
					_move_axis = _edge_safe_dir
					_edge_turnaround_timer = 0.35
					if absf(player.velocity.x) > 20.0 and signf(player.velocity.x) == move_dir:
						player.velocity.x *= 0.2
					return BTNode.Status.SUCCESS

	elif not player.is_on_floor():
		# Si está en una cuerda o escalando, no intervenir
		if player.has_method("is_touching_climb_rope") and (player.is_touching_climb_rope() or player.is_climbing_rope()):
			return BTNode.Status.FAILURE
		if player.has_method("is_on_swing") and player.is_on_swing():
			return BTNode.Status.FAILURE

		# Si ya lleva impulso horizontal en el aire (ej. salto activo cruzando hueco), no revertir
		if absf(player.velocity.x) > 40.0:
			return BTNode.Status.FAILURE

		var my_pos := player.global_position
		var suelo_debajo := _hay_suelo(my_pos, 220.0)
		if not suelo_debajo:
			var hay_izq := _hay_suelo(Vector2(my_pos.x - 70.0, my_pos.y), 220.0)
			var hay_der := _hay_suelo(Vector2(my_pos.x + 70.0, my_pos.y), 220.0)
			if hay_izq and not hay_der:
				_move_axis = -1.0
				return BTNode.Status.SUCCESS
			elif hay_der and not hay_izq:
				_move_axis = 1.0
				return BTNode.Status.SUCCESS

	return BTNode.Status.FAILURE


## Cuerda de balanceo (Péndulo): Agarre, bombeo de impulso y suelta con salto.
func _bt_handle_swinging_rope(_delta: float) -> int:
	if player.has_method("is_on_swing") and player.is_on_swing():
		if _target != null:
			# Bombear en dirección al objetivo
			_move_axis = _steering.seek(player.global_position.x, _target.global_position.x)
			# Soltar cuando la velocidad vaya hacia el objetivo
			var moving_toward := player.velocity.x * (_target.global_position.x - player.global_position.x) > 0.0
			if moving_toward and absf(player.velocity.x) > 280.0:
				_jump_just_pressed = true
		return BTNode.Status.SUCCESS

	# Detección de columpio cercano para cruzar huecos
	var swings := get_tree().get_nodes_in_group("cuerda_balanceo")
	if swings.is_empty():
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	for s in swings:
		if is_instance_valid(s) and s.has_method("get_end_position"):
			var bob_pos: Vector2 = s.get_end_position()
			if my_pos.distance_to(bob_pos) < 45.0:
				_move_axis = _steering.arrive(my_pos.x, bob_pos.x, 24.0)
				_up_pressed = true # Agarrarse
				return BTNode.Status.SUCCESS

	return BTNode.Status.FAILURE


## Cuerda vertical (Trepar): Sube con W, baja con S, y salta al llegar a la altura deseada.
func _bt_handle_climbing_rope(_delta: float) -> int:
	var touching: bool = bool(player.has_method("is_touching_climb_rope") and player.is_touching_climb_rope())
	var climbing: bool = bool(player.has_method("is_climbing_rope") and player.is_climbing_rope())

	if touching or climbing:
		if _target != null:
			var target_y := _target.global_position.y
			var my_y := player.global_position.y

			if target_y < my_y - 25.0:
				# Subir por la cuerda
				_up_pressed = true
				if my_y <= target_y + 16.0:
					# Salto para desembarcar en la plataforma
					_jump_just_pressed = true
				return BTNode.Status.SUCCESS
			elif target_y > my_y + 40.0:
				# Bajar por la cuerda
				_crouch_pressed = true
				return BTNode.Status.SUCCESS

	return BTNode.Status.FAILURE


## Escalar paredes y Wall-Jump: Secuencia de empuje contra pared, deslizamiento y salto.
func _bt_handle_wall_jump(delta: float) -> int:
	_wall_jump_cooldown = maxf(_wall_jump_cooldown - delta, 0.0)
	if _target == null:
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	var target_pos := _target.global_position
	var has_los := _has_line_of_sight(my_pos, target_pos)

	var wall_dir := 0
	if player.has_method("get_wall_direction"):
		wall_dir = player.get_wall_direction()

	# 1. En el aire en contacto lateral con la pared: Wall-Jump reactivo hacia el lado opuesto
	if not player.is_on_floor() and wall_dir != 0:
		if _wall_jump_cooldown <= 0.0:
			_wall_slide_timer += delta
			if _wall_slide_timer >= 0.04:
				_jump_just_pressed = true
				_aim_dir = Vector2(-wall_dir, -0.65).normalized()
				_move_axis = -float(wall_dir)
				_wall_slide_timer = 0.0
				_wall_jump_cooldown = 0.10
				return BTNode.Status.SUCCESS
			else:
				# Deslizar empujando hacia la pared antes del salto
				_move_axis = float(wall_dir)
				return BTNode.Status.SUCCESS
	else:
		_wall_slide_timer = 0.0

	# 2. En el suelo frente a una pared hacia el objetivo elevado:
	# Iniciar el primer salto hacia la pared para comenzar la escalada solo si el objetivo
	# está arriba, en dirección a la pared y hay espacio vertical para escalar sin chocar techo.
	if player.is_on_floor() and (player.is_on_wall() or wall_dir != 0):
		var target_dx := target_pos.x - my_pos.x
		var effective_wall_dir := wall_dir if wall_dir != 0 else int(signf(player.get_wall_normal().x * -1.0))
		if target_pos.y < my_pos.y - 25.0 and effective_wall_dir != 0 and signf(target_dx) == float(effective_wall_dir):
			var space := player.get_world_2d().direct_space_state
			if space != null:
				var head_ray := PhysicsRayQueryParameters2D.create(my_pos, my_pos + Vector2(0.0, -45.0), 1)
				head_ray.exclude = [player.get_rid()]
				if space.intersect_ray(head_ray).is_empty():
					_move_axis = float(effective_wall_dir)
					_jump_just_pressed = true
					return BTNode.Status.SUCCESS

	return BTNode.Status.FAILURE


## Plataformas atravesables (One-Way):
## - Para bajar: Fuerza agacharse / drop_through_platform().
## - Para subir: Salto desde abajo para atravesarla y posarse encima.
func _bt_handle_one_way_platform(delta: float) -> int:
	_platform_drop_cooldown = maxf(_platform_drop_cooldown - delta, 0.0)
	if _platform_drop_cooldown > 0.0 or _target == null:
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	var target_pos := _target.global_position

	# 1. Bajar: el enemigo está claramente abajo y estamos sobre una plataforma one-way
	if target_pos.y > my_pos.y + 30.0:
		if _is_standing_on_one_way():
			_crouch_pressed = true
			if player.has_method("drop_through_platform"):
				player.drop_through_platform()
			_platform_drop_cooldown = 0.35
			_move_axis = _steering.seek(my_pos.x, target_pos.x)
			return BTNode.Status.SUCCESS

	# 2. Subir: el objetivo está arriba y hay una plataforma one-way encima
	if target_pos.y < my_pos.y - 35.0 and player.is_on_floor():
		if _has_one_way_above():
			_move_axis = _steering.seek(my_pos.x, target_pos.x)
			_jump_just_pressed = true
			return BTNode.Status.SUCCESS

	return BTNode.Status.FAILURE


## Puertas: Se aproxima a la zona detectora de la puerta para que se abra automáticamente.
func _bt_handle_doors(_delta: float) -> int:
	if _target == null:
		return BTNode.Status.FAILURE

	var doors := get_tree().get_nodes_in_group("puerta")
	if doors.is_empty():
		return BTNode.Status.FAILURE

	var my_pos := player.global_position
	var target_pos := _target.global_position
	var has_los := _has_line_of_sight(my_pos, target_pos)

	for d in doors:
		if not is_instance_valid(d) or not d.is_inside_tree():
			continue
		if d.has_method("is_open") and d.is_open():
			continue

		var door_pos: Vector2 = d.global_position
		var dist_to_door := my_pos.distance_to(door_pos)

		# Si hay una puerta a menos de 220px:
		# Si no tenemos visión directa al rival (ej. estamos en habitación cerrada)
		# o la puerta está en dirección al objetivo, ir a la puerta para abrirla
		if dist_to_door < 220.0:
			var door_dir := signf(door_pos.x - my_pos.x)
			var target_dir := signf(target_pos.x - my_pos.x)
			if not has_los or door_dir == target_dir:
				_move_axis = _steering.seek(my_pos.x, door_pos.x)
				return BTNode.Status.SUCCESS

	return BTNode.Status.FAILURE


## Navegación táctica y combate a distancia (Steering general y Waypoints).
func _bt_handle_navigation_and_spacing(delta: float) -> int:
	if _target == null:
		_move_axis = 0.0
		return BTNode.Status.SUCCESS

	var my_pos := player.global_position
	var target_pos := _target.global_position
	var dist := my_pos.distance_to(target_pos)
	var tier := _get_difficulty_tier()
	var space := player.get_world_2d().direct_space_state

	# Comprobar si el objetivo está en otra plataforma o a distinta elevación
	var different_platform := absf(target_pos.y - my_pos.y) > 36.0
	var has_los := _has_line_of_sight(my_pos, target_pos)

	# 1. ESPACIADO DE COMBATE HUMANO: Nunca pegarse al rival cuerpo a cuerpo
	if dist < 140.0 and not different_platform:
		# Situación de cuerpo a cuerpo pegado: salto de desenganche y retroceso inmediato
		_move_axis = _steering.flee(my_pos.x, target_pos.x)
		if player.is_on_floor():
			_jump_just_pressed = true
			if player.is_on_wall():
				_move_axis = _steering.seek(my_pos.x, target_pos.x)
	elif dist < 220.0 and has_los and not different_platform:
		# Retroceder manteniendo la mira para ganar ángulo de tiro
		_move_axis = _steering.flee(my_pos.x, target_pos.x)
	elif has_los and not different_platform:
		var opt_min := 220.0
		var opt_max := 400.0

		if dist > opt_max:
			_move_axis = _steering.seek(my_pos.x, target_pos.x)
		elif dist < opt_min:
			_move_axis = _steering.flee(my_pos.x, target_pos.x)
		else:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(0.3, 0.9)
				_strafe_dir = -_strafe_dir if randf() < 0.6 else _strafe_dir
			_move_axis = _steering.strafe(_strafe_dir, 0.85 if tier == DifficultyTier.DIFICIL else 0.55)

	# 2. Navegación entre plataformas o sin línea de visión (Pathfinding por NavGraph)
	else:
		_path_update_timer -= delta
		var tilemap := _get_tilemap()
		if tilemap != null and _path_update_timer <= 0.0:
			_path_update_timer = 0.4
			var key := str(tilemap.get_instance_id())
			_nav_graph = NavGraph.get_or_build(tilemap, key)
			_current_path = _nav_graph.find_path(my_pos, target_pos)
			_path_index = 0

		if not _current_path.is_empty():
			var follow_res: Dictionary = _steering.follow_path(my_pos, _current_path, _path_index, 36.0)
			_path_index = follow_res["index"]
			_move_axis = follow_res["move_axis"]
			var wp: Vector2 = follow_res["target"]

			# Si llegó al final o ya tiene línea de visión directa a distancia de tiro en el mismo piso
			if follow_res["finished"] or (has_los and not different_platform and dist < 320.0):
				_current_path = PackedVector2Array()
				_path_index = 0
			else:
				# Salto entre waypoints más altos o sobre huecos hacia la plataforma contigua
				if player.is_on_floor():
					var need_jump_up := wp.y < my_pos.y - 18.0
					var need_drop_down := wp.y > my_pos.y + 18.0 and absf(wp.x - my_pos.x) < 48.0
					if need_drop_down and _is_standing_on_one_way():
						_crouch_pressed = true
						if player.has_method("drop_through_platform"):
							player.drop_through_platform()
					else:
						var gap_ahead := not _hay_suelo(my_pos + Vector2(signf(_move_axis) * 26.0, 0.0), 40.0)
						var wp_horizontal_jump := absf(wp.x - my_pos.x) > 36.0 and not _hay_suelo(my_pos + Vector2(signf(_move_axis) * 24.0, 0.0), 30.0)
						if need_jump_up or gap_ahead or wp_horizontal_jump:
							_jump_just_pressed = true
		else:
			# Si NavGraph no encuentra camino o el objetivo está tras una pared, buscar salida/puerta/cuerda
			if not has_los:
				_move_axis = _buscar_salida_o_apertura(my_pos, target_pos)
			elif different_platform:
				# Objetivo en distinta plataforma: buscar plataforma intermedia para subir o bajar
				var intermediate := _buscar_plataforma_elevada(my_pos, target_pos)
				if intermediate != Vector2.ZERO:
					_move_axis = _steering.seek(my_pos.x, intermediate.x)
					if player.is_on_floor() and (absf(intermediate.x - my_pos.x) < 36.0 or player.is_on_wall()):
						if intermediate.y < my_pos.y - 18.0:
							_jump_just_pressed = true
						elif intermediate.y > my_pos.y + 18.0 and _is_standing_on_one_way():
							_crouch_pressed = true
							if player.has_method("drop_through_platform"):
								player.drop_through_platform()
				else:
					_move_axis = _buscar_salida_o_apertura(my_pos, target_pos)
			else:
				if dist > 260.0:
					_move_axis = _steering.seek(my_pos.x, target_pos.x)
				elif dist < 180.0:
					_move_axis = _steering.flee(my_pos.x, target_pos.x)

	# Salto táctico frecuente para esquivar y ganar ángulos de disparo
	_tactical_jump_timer -= delta
	if _tactical_jump_timer <= 0.0 and player.is_on_floor():
		_tactical_jump_timer = randf_range(0.9, 2.0)
		_jump_just_pressed = true

	# 3. Verificación de si el personaje CABE en el hueco frente a él (no meterse en rendijas)
	if space != null and absf(_move_axis) > 0.1:
		var ahead_pos := my_pos + Vector2(signf(_move_axis) * 22.0, 0.0)
		if not _steering.can_character_fit(space, ahead_pos):
			_blocked_time += delta
			if _blocked_time > 0.12:
				# Si cabe saltando por encima, saltar; de lo contrario dar media vuelta
				var above_pos := my_pos + Vector2(0.0, -42.0)
				if _steering.can_character_fit(space, above_pos) and player.is_on_floor():
					_jump_just_pressed = true
				else:
					_move_axis = -signf(_move_axis)
					_edge_turnaround_timer = 0.4
					_edge_safe_dir = _move_axis
				_blocked_time = 0.0
		elif player.is_on_floor() and absf(player.velocity.x) < 20.0:
			_blocked_time += delta
			if _blocked_time > 0.15:
				_jump_just_pressed = true
				_blocked_time = 0.0
		else:
			_blocked_time = 0.0
	else:
		_blocked_time = 0.0

	return BTNode.Status.SUCCESS


# ==============================================================================
# MÉTODOS DE APOYO Y COMPATIBILIDAD
# ==============================================================================

## Evitar abismo para compatibilidad con la suite de pruebas.
func _evitar_abismo(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	var move_dir := signf(_move_axis)
	if is_zero_approx(move_dir):
		return
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return
	if _steering == null:
		_steering = BotSteeringScript.new()

	var lookahead: float = clampf(absf(player.velocity.x) * 0.28 + 36.0, 36.0, 80.0)
	var hazard_info: Dictionary = _steering.check_hazard_ahead(space, player, move_dir, lookahead, _get_tilemap())

	if hazard_info.hazard_ahead:
		if hazard_info.safe_jump_available and absf(player.velocity.x) > 100.0:
			_jump_just_pressed = true
		else:
			_move_axis = -move_dir
			_edge_turnaround_timer = 0.35
			_edge_safe_dir = -move_dir
			if absf(player.velocity.x) > 20.0 and signf(player.velocity.x) == move_dir:
				player.velocity.x *= 0.25
	elif not player.is_on_floor():
		var my_pos := player.global_position
		var suelo_debajo := _hay_suelo(my_pos, 220.0)
		if not suelo_debajo:
			var hay_izq := _hay_suelo(Vector2(my_pos.x - 70.0, my_pos.y), 220.0)
			var hay_der := _hay_suelo(Vector2(my_pos.x + 70.0, my_pos.y), 220.0)
			if hay_izq and not hay_der:
				_move_axis = -1.0
			elif hay_der and not hay_izq:
				_move_axis = 1.0


func _find_target() -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_score := -INF
	var my_pos := player.global_position

	var candidates: Array = RunManager.jugadores_activos()
	if candidates.is_empty() and player != null and player.is_inside_tree():
		candidates = player.get_tree().get_nodes_in_group("player")

	for p in candidates:
		if not is_instance_valid(p) or p.is_queued_for_deletion() or not p.is_inside_tree() or p == player or not (p is CharacterBody2D):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue

		var p_pos: Vector2 = p.global_position
		var dist := my_pos.distance_to(p_pos)
		var has_los := _has_line_of_sight(my_pos, p_pos)

		# Puntuación base por proximidad
		var score := 1200.0 - dist
		if has_los:
			score += 1500.0 # Prioridad enorme a quien podemos ver y disparar

		# Penalizar fuertemente quedarse trabado mirando al rival directamente a través de un techo o piso
		if not has_los and absf(p_pos.x - my_pos.x) < 80.0 and absf(p_pos.y - my_pos.y) > 40.0:
			score -= 1200.0

		# Inercia de objetivo para evitar saltos caóticos de mira
		if p == _target:
			score += 250.0

		if score > best_score:
			best_score = score
			best = p

	if best == null and _target != null and is_instance_valid(_target) and (_target is CharacterBody2D):
		if not (_target.has_method("is_alive") and not _target.is_alive()):
			return _target

	return best


## Busca una plataforma intermedia a diferente altura para escalar hacia el objetivo.
func _buscar_plataforma_elevada(my_pos: Vector2, target_pos: Vector2) -> Vector2:
	if _nav_graph == null or _nav_graph.point_count() == 0:
		return Vector2.ZERO
	var target_is_above := target_pos.y < my_pos.y - 36.0
	var best_pos := Vector2.ZERO
	var best_score := -INF

	for cell in _nav_graph._ids.keys():
		var pt_pos: Vector2 = _nav_graph._astar.get_point_position(_nav_graph._ids[cell])
		if target_is_above:
			# Buscar una plataforma por encima de nosotros en dirección al objetivo
			if pt_pos.y < my_pos.y - 20.0 and pt_pos.y >= target_pos.y - 50.0:
				var dist_x_to_me := absf(pt_pos.x - my_pos.x)
				var dist_x_to_target := absf(pt_pos.x - target_pos.x)
				var score := 1200.0 - dist_x_to_me - dist_x_to_target * 0.4
				if score > best_score:
					best_score = score
					best_pos = pt_pos
		else:
			# Buscar una plataforma por debajo
			if pt_pos.y > my_pos.y + 20.0 and pt_pos.y <= target_pos.y + 50.0:
				var dist_x_to_me := absf(pt_pos.x - my_pos.x)
				var dist_x_to_target := absf(pt_pos.x - target_pos.x)
				var score := 1200.0 - dist_x_to_me - dist_x_to_target * 0.4
				if score > best_score:
					best_score = score
					best_pos = pt_pos

	return best_pos


## Busca una salida (puerta, cuerda o extremo de repisa) cuando el enemigo está tras una pared.
func _buscar_salida_o_apertura(my_pos: Vector2, target_pos: Vector2) -> float:
	# 1. Si hay puertas en la habitación o cerca, dirigirse primero a la puerta
	var doors := get_tree().get_nodes_in_group("puerta")
	var best_door_x := INF
	var min_door_dist := INF
	for d in doors:
		if is_instance_valid(d) and d.is_inside_tree():
			var d_pos: Vector2 = d.global_position
			var dist := my_pos.distance_to(d_pos)
			if dist < min_door_dist and dist < 450.0:
				min_door_dist = dist
				best_door_x = d_pos.x
	if not is_inf(best_door_x):
		return _steering.seek(my_pos.x, best_door_x)

	# 2. Si hay cuerdas de trepar en el mapa, dirigirse a la cuerda
	var ropes := get_tree().get_nodes_in_group("cuerda_trepar")
	var best_rope_x := INF
	var min_rope_dist := INF
	for r in ropes:
		if is_instance_valid(r):
			var d := my_pos.distance_squared_to(r.global_position)
			if d < min_rope_dist:
				min_rope_dist = d
				best_rope_x = r.global_position.x
	if not is_inf(best_rope_x) and min_rope_dist < 400000.0:
		return _steering.seek(my_pos.x, best_rope_x)

	# 3. Buscar pozos verticales o plataformas escalables en NavGraph hacia el nivel del rival
	if _nav_graph != null and _nav_graph.point_count() > 0:
		var best_plat_x := INF
		var min_plat_dist := INF
		var target_is_above := target_pos.y < my_pos.y - 30.0
		for cell in _nav_graph._ids.keys():
			var pt_pos: Vector2 = _nav_graph._astar.get_point_position(_nav_graph._ids[cell])
			var is_useful := (target_is_above and pt_pos.y < my_pos.y - 20.0) or (not target_is_above and pt_pos.y > my_pos.y + 20.0)
			if is_useful:
				var d := my_pos.distance_squared_to(pt_pos)
				if d < min_plat_dist:
					min_plat_dist = d
					best_plat_x = pt_pos.x
		if not is_inf(best_plat_x):
			return _steering.seek(my_pos.x, best_plat_x)

	# 4. Moverse hacia el extremo de la plataforma actual (para buscar bajada o desvío)
	var move_dir := signf(target_pos.x - my_pos.x)
	if is_zero_approx(move_dir):
		move_dir = 1.0 if (int(my_pos.x) % 2 == 0) else -1.0
	return move_dir


func _has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return false

	# Mask 1: Sólidos y puertas cerradas
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	if _target != null and is_instance_valid(_target) and hit.get("collider") == _target:
		return true
	return false


func _hay_suelo(origen: Vector2, distancia_abajo: float) -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(origen, origen + Vector2(0.0, distancia_abajo), 1 | 64)
	query.exclude = [player.get_rid()]
	return not space.intersect_ray(query).is_empty()


func _is_standing_on_one_way() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return false
	for dx in [-10.0, 0.0, 10.0]:
		var origin := player.global_position + Vector2(dx, 10.0)
		var dest := player.global_position + Vector2(dx, 28.0)
		var query_ow := PhysicsRayQueryParameters2D.create(origin, dest, 64)
		query_ow.exclude = [player.get_rid()]
		var hit_ow := space.intersect_ray(query_ow)
		if not hit_ow.is_empty():
			var query_solid := PhysicsRayQueryParameters2D.create(origin, dest, 1)
			query_solid.exclude = [player.get_rid()]
			var hit_solid := space.intersect_ray(query_solid)
			if hit_solid.is_empty() or hit_ow.position.y <= hit_solid.position.y + 2.0:
				return true
	return false


func _has_one_way_above() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return false
	for dx in [-18.0, 0.0, 18.0]:
		var origin := player.global_position + Vector2(dx, -10.0)
		var dest := player.global_position + Vector2(dx, -120.0)
		var query_ow := PhysicsRayQueryParameters2D.create(origin, dest, 64)
		query_ow.exclude = [player.get_rid()]
		var hit_ow := space.intersect_ray(query_ow)
		if not hit_ow.is_empty():
			var query_solid := PhysicsRayQueryParameters2D.create(origin, dest, 1)
			query_solid.exclude = [player.get_rid()]
			var hit_solid := space.intersect_ray(query_solid)
			if hit_solid.is_empty() or hit_ow.position.y >= hit_solid.position.y - 2.0:
				return true
	return false


func _get_tilemap() -> TileMapLayer:
	if _cached_tilemap != null and is_instance_valid(_cached_tilemap) and _cached_tilemap.is_inside_tree():
		return _cached_tilemap
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return null
	var parent := player.get_parent()
	if parent != null:
		var tm := parent.find_child("NeonTileMap", true, false) as TileMapLayer
		if tm != null:
			_cached_tilemap = tm
			return _cached_tilemap
	var tms := get_tree().get_nodes_in_group("tilemap")
	if not tms.is_empty() and tms[0] is TileMapLayer:
		_cached_tilemap = tms[0]
		return _cached_tilemap
	return null


func _limpiar_registro_balas() -> void:
	var keys_to_remove: Array = []
	for b_id in _bullet_parry_decisions:
		var instance = instance_from_id(b_id)
		if instance == null or not is_instance_valid(instance):
			keys_to_remove.append(b_id)
	for k in keys_to_remove:
		_bullet_parry_decisions.erase(k)
