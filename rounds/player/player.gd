class_name Player
extends CharacterBody2D

signal quacked(player_number: int)
signal grabbed(player_number: int)
signal parried_bullet(bullet: Node)

const BLOOD_SCENE := preload("res://effects/blood_splatter.tscn")
const CHARACTER_FRAMES := {
	"esqueleto": preload("res://player/skeleton_frames.tres"),
	"sapo": preload("res://player/sapo_frames.tres"),
	"pajaro": preload("res://player/pajaro_frames.tres"),
	"fantasma": preload("res://player/fantasma_frames.tres"),
}

# Bajar atravesando plataformas de una sola cara (one-way).
const ONE_WAY_LAYER := 7
const DROP_THROUGH_TIME := 0.22
const DROP_THROUGH_SPEED := 120.0

# Cuerdas: trepar (subir/bajar) y balanceo (colgarse y columpiarse).
const CLIMB_SPEED := 150.0
# W es a la vez "arriba" y "saltar" en el teclado: al agarrarte ignoramos el
# "salto" un instante para no soltarte en el mismo frame del agarre.
const ROPE_GRACE := 0.25

enum PlayerState {
	IDLE,
	WALKING,
	AIRBORNE,
	RAGDOLL,
	DEAD,
}

@export var player_number: int = 1
@export var weapon_offset: Vector2 = Vector2(4.0, -2.0)

@export_group("Movement")
@export var acceleration: float = 2000.0
@export var friction: float = 1200.0
@export var air_control: float = 0.70
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1100.0
@export var ragdoll_time: float = 0.175

@export_group("Parry")
@export var parry_cooldown_time: float = 4.0
@export var parry_arc_deg: float = 90.0

@export_group("Jump Game Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var corner_correction_step: float = 1.0
@export var corner_correction_max: float = 6.0

@export_group("Wall Jump Game Feel")
@export var wall_slide_speed: float = 200.0
@export var wall_jump_velocity_mult: float = 0.9
@export var wall_jump_push: float = 340.0
@export var wall_jump_lockout: float = 0.15

@onready var _input: PlayerInput = $PlayerInput
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _health: HealthComponent = $HealthComponent
@onready var _stats: StatSheet = $StatSheet
@onready var _body_animation: AnimationPlayer = $BodyAnimation
@onready var _hit_flash: AnimationPlayer = $HitFlash
@onready var _corner_ray_left: RayCast2D = $CornerRayLeft
@onready var _corner_ray_right: RayCast2D = $CornerRayRight
@onready var _ground_ray: RayCast2D = $GroundRay
@onready var _wall_ray_left: RayCast2D = $WallRayLeft
@onready var _wall_ray_right: RayCast2D = $WallRayRight
@onready var _skeleton_sprite: AnimatedSprite2D = $Visual.get_node_or_null("SkeletonSprite")
@onready var _floating_hp: Node2D = get_node_or_null("FloatingHealthBar")
@onready var _parry_effect: AnimatedSprite2D = get_node_or_null("ParryEffect")

var facing: int = 1
var can_control: bool = true
var current_state: PlayerState = PlayerState.IDLE
var tipo_personaje: String = "esqueleto"

var _effects: Array = []
var _active_dots: Array = []
var _toxic_cloud_count: int = 0
var _poison_flash_timer: float = 0.0
var _ragdoll_timer: float = 0.0
var _parry_cooldown: float = 0.0
var _stun_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _wall_jump_lockout_timer: float = 0.0
var _last_wall_jump_side: int = 0
var _drop_through_timer: float = 0.0
var _climb_ropes: Array = []
var _swing: Node = null
var _swing_release_timer: float = 0.0
var _rope_grace_timer: float = 0.0
var _climbing_prev: bool = false
var _platform_drop_timer: float = 0.0
var _spawn_position: Vector2
var _hit_stop_remaining: float = 0.0
var _hit_stop_active: bool = false
var _death_tween: Tween = null
var _fade_tween: Tween = null

# Modificadores de físicas dinámicos (auras / campos)
var gravity_scale: float = 1.0
var jump_force_multiplier: float = 1.0

# Armadura y Mitigación
var _adaptive_armor_stacks: int = 0
var _adaptive_armor_timer: float = 0.0

# Regeneración (Segunda Piel)
var _second_skin_timer: float = 0.0
var _second_skin_tick_timer: float = 0.0

# Ralentización (Bala Anclante / Aura)
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0

# Debuff de Gravedad y Salto (Zona de Gravedad)
var _gravity_mult: float = 1.0
var _gravity_mult_timer: float = 0.0
var _jump_mult: float = 1.0
var _jump_mult_timer: float = 0.0

# Deuda de Sangre
var has_blood_debt: bool = false
var _in_blood_debt: bool = false
var _blood_debt_timer: float = 0.0
var _blood_debt_healed: int = 0
var _blood_debt_cooldown: float = 0.0

# Invulnerabilidad y protección de spawn
var invulnerable: bool = false
var _spawn_protection_timer: float = 0.0
# Propulsión (Rocket Jump)


func _ready() -> void:
	if not RunManager.es_jugador_activo(player_number):
		remove_from_group("player")
		queue_free()
		return
	_spawn_position = global_position
	add_to_group("player")
	RunManager.registrar_jugador(self)
	_configurar_personaje()
	_update_visual_facing()
	if _floating_hp != null:
		_floating_hp.setup(player_number, _health.health, _health.max_health)
		_health.health_changed.connect(_floating_hp.update_health)
	if _parry_effect != null:
		_parry_effect.visible = false
		_parry_effect.animation_finished.connect(func() -> void:
			_parry_effect.visible = false
		)


func _physics_process(delta: float) -> void:
	gravity_scale = 1.0
	jump_force_multiplier = 1.0
	_update_stun(delta)
	_update_dots(delta)
	_update_ragdoll(delta)
	_update_buffs(delta)
	_swing_release_timer = maxf(_swing_release_timer - delta, 0.0)
	_rope_grace_timer = maxf(_rope_grace_timer - delta, 0.0)
	_spawn_protection_timer = maxf(_spawn_protection_timer - delta, 0.0)
	var prev_parry_cooldown := _parry_cooldown
	_parry_cooldown = maxf(_parry_cooldown - delta, 0.0)
	if prev_parry_cooldown > 0.0 and _parry_cooldown <= 0.0 and is_alive():
		_on_parry_recharged()
	_update_state()
	# Vivo y fuera del trompezar: el visual nunca debe quedar tumbado.
	if current_state != PlayerState.DEAD and _ragdoll_timer <= 0.0:
		$Visual.rotation = 0.0
	_apply_gravity(delta)
	_update_jump_timers(delta)
	# La muerte por salir de la arena (abismo / bordes) la gestiona el DeadZone de
	# cada mapa (hazard_zone.gd). El límite hardcodeado de antes asumía un mapa fijo
	# de 1280x720 y mataba a los jugadores en mapas grandes.

	if _platform_drop_timer > 0.0:
		_platform_drop_timer = maxf(_platform_drop_timer - delta, 0.0)
		if _platform_drop_timer <= 0.0:
			set_collision_mask_value(7, true)
		else:
			velocity.y = maxf(velocity.y, 140.0)
	elif is_on_floor() and not _is_climbing() and _swing == null:
		var wants_drop := _input.is_crouch_pressed() or _input.aim().y > 0.65
		if wants_drop:
			drop_through_platform()

	if _swing != null and is_instance_valid(_swing):
		_handle_swing(delta)
		return

	var climbing := _is_climbing()
	if climbing and not _climbing_prev:
		_rope_grace_timer = ROPE_GRACE
	_climbing_prev = climbing

	if climbing:
		_handle_climb(delta)
		_handle_aim()
		_handle_actions()
	else:
		match current_state:
			PlayerState.DEAD:
				velocity.x = move_toward(velocity.x, 0.0, friction * 0.4 * delta)
			PlayerState.RAGDOLL:
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			PlayerState.IDLE, PlayerState.WALKING, PlayerState.AIRBORNE:
				_handle_horizontal(delta)
				_handle_jump()
				_handle_aim()
				_handle_actions()
		_handle_drop_through(delta)

	_apply_corner_correction()
	move_and_slide()


func _update_state() -> void:
	if current_state == PlayerState.DEAD:
		return
	if not can_control:
		current_state = PlayerState.RAGDOLL
	elif not is_on_floor():
		current_state = PlayerState.AIRBORNE
	elif not is_zero_approx(_input.move_axis()):
		current_state = PlayerState.WALKING
	else:
		current_state = PlayerState.IDLE
	_update_character_visual()


func _configurar_personaje() -> void:
	tipo_personaje = RunManager.personaje_de(player_number)
	if not RunManager.PERSONAJES_VALIDOS.has(tipo_personaje):
		tipo_personaje = "esqueleto"
	if _skeleton_sprite != null:
		_skeleton_sprite.visible = true
		var frames := RunManager.obtener_sprite_frames(tipo_personaje, player_number)
		if frames != null:
			_skeleton_sprite.sprite_frames = frames
		elif CHARACTER_FRAMES.has(tipo_personaje):
			_skeleton_sprite.sprite_frames = CHARACTER_FRAMES[tipo_personaje]
		_skeleton_sprite.modulate = Color.WHITE
		_skeleton_sprite.material = null
		_skeleton_sprite.play("idle")
	_body_animation.play("stand")


func _update_character_visual() -> void:
	if _skeleton_sprite == null:
		return
	match current_state:
		PlayerState.DEAD:
			if _skeleton_sprite.animation != "dead":
				_skeleton_sprite.play("dead")
		PlayerState.WALKING:
			if _skeleton_sprite.animation != "walk":
				_skeleton_sprite.play("walk")
		_:
			if _skeleton_sprite.animation != "idle":
				_skeleton_sprite.play("idle")


func _update_jump_timers(delta: float) -> void:
	if _wall_jump_lockout_timer > 0.0:
		_wall_jump_lockout_timer = maxf(_wall_jump_lockout_timer - delta, 0.0)
	if not can_control or current_state == PlayerState.DEAD:
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return

	_ground_ray.force_raycast_update()
	if is_on_floor():
		_last_wall_jump_side = 0
	if is_on_floor() or (_ground_ray.is_colliding() and velocity.y >= 0.0):
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if _input.is_jump_just_pressed():
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var total_gravity_scale: float = gravity_scale * (_gravity_mult if _gravity_mult_timer > 0.0 else 1.0)
		velocity.y = minf(velocity.y + (gravity * total_gravity_scale) * delta, max_fall_speed)
		_apply_wall_slide()
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _apply_wall_slide() -> void:
	if velocity.y <= 0.0 or _wall_jump_lockout_timer > 0.0:
		return
	var wall_dir := _wall_direction()
	if wall_dir == 0 or not is_equal_approx(signf(_input.move_axis()), float(wall_dir)):
		return
	velocity.y = minf(velocity.y, wall_slide_speed)


func _wall_direction() -> int:
	_wall_ray_left.force_raycast_update()
	_wall_ray_right.force_raycast_update()
	var left := _wall_ray_left.is_colliding()
	var right := _wall_ray_right.is_colliding()
	if left and right:
		var axis := _input.move_axis()
		if axis < 0.0:
			return -1
		if axis > 0.0:
			return 1
		return -facing
	if left:
		return -1
	if right:
		return 1
	return 0


func _handle_horizontal(delta: float) -> void:
	if _wall_jump_lockout_timer > 0.0:
		return
	if _input.is_lock_pressed():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return
	var direction := _input.move_axis()
	# Justo al soltarte del columpio conservás el impulso en el aire.
	if _swing_release_timer > 0.0 and not is_on_floor() and is_zero_approx(direction):
		return
	var speed := _stats.get_stat(&"move_speed") * get_speed_multiplier()
	if absf(velocity.x) > speed and (is_zero_approx(direction) or signf(velocity.x) != signf(direction)):
		var decel := friction * 0.4 if is_on_floor() else friction * 0.15
		velocity.x = move_toward(velocity.x, direction * speed, decel * delta)
	else:
		var accel := acceleration if is_on_floor() else acceleration * air_control
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	if not is_zero_approx(direction) and not _input.is_strafe_pressed():
		facing = 1 if direction > 0.0 else -1
		_update_visual_facing()


func _handle_jump() -> void:
	if _input.is_lock_pressed():
		return
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			var total_jump_mult: float = jump_force_multiplier * (_jump_mult if _jump_mult_timer > 0.0 else 1.0)
			velocity.y = _stats.get_stat(&"jump_velocity") * total_jump_mult
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			AudioManager.reproducir("salto", 0.05)
		elif _try_wall_jump():
			return
	if _input.is_jump_just_released() and velocity.y < 0.0:
		velocity.y *= 0.5


func _try_wall_jump() -> bool:
	if _wall_jump_lockout_timer > 0.0:
		return false
	var wall_dir := _wall_direction()
	if wall_dir == 0 or wall_dir == _last_wall_jump_side:
		return false
	var total_jump_mult: float = jump_force_multiplier * (_jump_mult if _jump_mult_timer > 0.0 else 1.0)
	# Dirección horizontal del salto: manda el input (permite saltar hacia
	# arriba, en diagonal, alejándose o pegado a la pared). Sin input
	# horizontal, empuja alejándose como el salto clásico.
	var aim := _input.aim()
	var push_dir := aim.x
	if aim.is_zero_approx():
		push_dir = float(-wall_dir)
	velocity.y = _stats.get_stat(&"jump_velocity") * wall_jump_velocity_mult * total_jump_mult
	velocity.x = push_dir * wall_jump_push
	facing = 1 if push_dir > 0.0 else -1
	_update_visual_facing()
	_wall_jump_lockout_timer = wall_jump_lockout
	_last_wall_jump_side = wall_dir
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	AudioManager.reproducir("salto", 0.05)
	return true


func drop_through_platform() -> void:
	_drop_through_timer = DROP_THROUGH_TIME
	set_collision_mask_value(ONE_WAY_LAYER, false)
	velocity.y = maxf(velocity.y, DROP_THROUGH_SPEED)
	position.y += 3.0


func _handle_drop_through(delta: float) -> void:
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			set_collision_mask_value(ONE_WAY_LAYER, true)
		else:
			velocity.y = maxf(velocity.y, DROP_THROUGH_SPEED)
		return
	if not can_control or current_state == PlayerState.DEAD:
		return
	if not is_on_floor() or not _input.is_crouch_pressed():
		return
	# Suelta la plataforma de una sola cara: ignora esa capa un instante para
	# caer. Sobre suelo firme no pasa nada porque eso va en la capa World.
	_drop_through_timer = DROP_THROUGH_TIME
	set_collision_mask_value(ONE_WAY_LAYER, false)
	velocity.y = DROP_THROUGH_SPEED
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func get_wall_direction() -> int:
	return _wall_direction()


func is_touching_climb_rope() -> bool:
	return not _climb_ropes.is_empty()


func is_climbing_rope() -> bool:
	return _is_climbing()


func is_on_swing() -> bool:
	return _swing != null and is_instance_valid(_swing)
func enter_climb_rope(rope: Node) -> void:
	if not _climb_ropes.has(rope):
		_climb_ropes.append(rope)


func exit_climb_rope(rope: Node) -> void:
	_climb_ropes.erase(rope)


func attach_swing(rope: Node) -> void:
	if _swing == rope:
		return
	if _swing != null and is_instance_valid(_swing) and _swing.has_method("release_player"):
		_swing.release_player()
	_swing = rope
	velocity = Vector2.ZERO
	_rope_grace_timer = ROPE_GRACE


func detach_swing() -> void:
	_swing = null


func swing_input() -> float:
	# -1 izquierda, +1 derecha; se usa para bombear el columpio.
	return _input.move_axis()


func wants_grab_rope() -> bool:
	# Para agarrarse a una cuerda hay que apretar arriba (W).
	return _input.is_up_pressed()


func _is_climbing() -> bool:
	if not can_control or current_state == PlayerState.DEAD or _swing != null:
		return false
	if _climb_ropes.is_empty():
		return false
	# Sólo se agarra si apretás arriba (o abajo para bajar); si no, cae.
	return _input.is_up_pressed() or _input.is_crouch_pressed()


func _handle_climb(delta: float) -> void:
	var up := _input.is_up_pressed()
	var down := _input.is_crouch_pressed()
	if up and not down:
		velocity.y = -CLIMB_SPEED
	elif down and not up:
		velocity.y = CLIMB_SPEED
	else:
		velocity.y = 0.0
	var hx := _input.move_axis()
	velocity.x = hx * CLIMB_SPEED * 0.7
	if not is_zero_approx(hx):
		facing = 1 if hx > 0.0 else -1
		_update_visual_facing()
	# Saltar para soltarse de la cuerda.
	if _input.is_jump_just_pressed() and _rope_grace_timer <= 0.0:
		_climb_ropes.clear()
		velocity.y = _stats.get_stat(&"jump_velocity") * 0.9
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0


func _handle_swing(_delta: float) -> void:
	if _swing == null or not is_instance_valid(_swing):
		_swing = null
		return
	current_state = PlayerState.AIRBORNE
	if _input.is_jump_just_pressed() and _rope_grace_timer <= 0.0:
		# Salir conservando la inercia del columpio.
		var v := velocity
		if _swing.has_method("get_end_velocity"):
			v = _swing.get_end_velocity()
		if _swing.has_method("release_player"):
			_swing.release_player()
		_swing = null
		velocity = v
		_swing_release_timer = 0.4
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
	elif _input.is_crouch_pressed():
		# Bajarse: soltarse y caer (más fácil que saltar).
		if _swing.has_method("release_player"):
			_swing.release_player()
		_swing = null
		velocity = Vector2(0.0, 60.0)
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0


func _apply_corner_correction() -> void:
	if not can_control or current_state == PlayerState.DEAD or velocity.y >= 0.0:
		return
	var left_hit := _corner_ray_hits(_corner_ray_left)
	var right_hit := _corner_ray_hits(_corner_ray_right)
	if left_hit == right_hit:
		return
	var direction := 1.0 if left_hit else -1.0
	var travelled := 0.0
	while travelled < corner_correction_max:
		global_position.x += direction * corner_correction_step
		travelled += corner_correction_step
		left_hit = _corner_ray_hits(_corner_ray_left)
		right_hit = _corner_ray_hits(_corner_ray_right)
		if not left_hit and not right_hit:
			return

func _corner_ray_hits(ray: RayCast2D) -> bool:
	ray.force_raycast_update()
	return ray.is_colliding()


func _handle_aim() -> void:
	var direction := _input.aim()
	if direction.is_zero_approx():
		direction = Vector2(facing, 0.0)
	elif not is_zero_approx(direction.x):
		facing = 1 if direction.x > 0.0 else -1
	_weapon.set_aim(direction)
	_update_visual_facing()


func _handle_actions() -> void:
	if _input.is_fire_pressed() and _ragdoll_timer <= 0.0:
		_weapon.try_fire()
	if _input.is_grab_just_pressed():
		grabbed.emit(player_number)
	if _input.is_ragdoll_just_pressed() and _parry_cooldown <= 0.0:
		_start_ragdoll()
	if _input.is_quack_just_pressed():
		quacked.emit(player_number)
		AudioManager.reproducir("cuac", 0.08)


func _update_visual_facing() -> void:
	var sx := absf($Visual.scale.x)
	if sx < 0.001:
		sx = 1.0
	var f := 1 if facing >= 0 else -1
	$Visual.scale.x = sx * f
	if _weapon != null:
		_weapon.position = Vector2(weapon_offset.x * f, weapon_offset.y)


func _start_ragdoll() -> void:
	_parry_cooldown = parry_cooldown_time
	_ragdoll_timer = ragdoll_time
	_play_parry_animation()


func _play_parry_animation() -> void:
	if _parry_effect == null:
		return
	var aim := get_parry_direction()
	_parry_effect.rotation = aim.angle() + deg_to_rad(45.0)
	_parry_effect.visible = true
	_parry_effect.frame = 0
	_parry_effect.play(&"parry")


func _update_ragdoll(delta: float) -> void:
	if _ragdoll_timer <= 0.0:
		return
	_ragdoll_timer = maxf(_ragdoll_timer - delta, 0.0)


func _on_parry_recharged() -> void:
	if not is_inside_tree() or not is_alive():
		return
	var tw_flash := create_tween()
	$Visual.modulate = Color(1.3, 1.8, 2.5, 1.0)
	tw_flash.tween_property($Visual, "modulate", Color.WHITE, 0.25)

	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.45, 0.9, 1.0, 0.85)
	ring.z_index = 6
	var pts := PackedVector2Array()
	for a in 24:
		var ang := float(a) / 24.0 * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 12.0)
	pts.append(pts[0])
	ring.points = pts
	ring.position = Vector2.ZERO
	add_child(ring)

	var tw_ring := ring.create_tween()
	tw_ring.set_parallel(true)
	tw_ring.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw_ring.tween_property(ring, "modulate:a", 0.0, 0.3)
	tw_ring.chain().tween_callback(ring.queue_free)


func is_alive() -> bool:
	return _health != null and _health.is_alive() and current_state != PlayerState.DEAD


func is_spinning() -> bool:
	return is_alive() and _ragdoll_timer > 0.0


func can_parry(bullet: Node = null) -> bool:
	if not is_spinning():
		return false
	if bullet == null:
		return true
	return _bullet_in_parry_arc(bullet)


# Dirección a la que se desvía la bala parada: el aim actual del arma.
func get_parry_direction() -> Vector2:
	if _weapon != null and not _weapon.aim_direction.is_zero_approx():
		return _weapon.aim_direction.normalized()
	return Vector2(facing, 0.0)


# Solo se parrea una bala que viene dentro del cono del aim (apuntar donde parrear).
func _bullet_in_parry_arc(bullet: Node) -> bool:
	var aim := get_parry_direction()
	var b_vel: Vector2 = bullet.get("velocity") if bullet != null and "velocity" in bullet else Vector2.ZERO
	if b_vel.length_squared() < 1.0:
		return false
	var from := -b_vel.normalized()
	return from.dot(aim) >= cos(deg_to_rad(parry_arc_deg * 0.5))


func on_parry(bullet: Node) -> void:
	parried_bullet.emit(bullet)
	for ef in _effects:
		if ef.has_method("on_parry"):
			ef.on_parry(bullet, self)
	print("Player %d: Parried!" % player_number)


func _on_damaged(amount: int, source: Node) -> void:
	AudioManager.reproducir("golpe", 0.1)
	_hit_flash.play("hit")
	CombatCamera.shake_viewport(self, 4.0, 0.2)
	for ef in _effects:
		if ef.has_method("on_damaged"):
			ef.on_damaged(amount, source, self)
	if is_alive():
		_hit_stop(0.04)


func _hit_stop(duracion: float) -> void:
	if not is_inside_tree():
		return
	_hit_stop_remaining = maxf(_hit_stop_remaining, duracion)
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.0
	while _hit_stop_remaining > 0.0 and is_inside_tree():
		var paso := _hit_stop_remaining
		await get_tree().create_timer(paso, true, false, true).timeout
		_hit_stop_remaining = maxf(_hit_stop_remaining - paso, 0.0)
	_restaurar_hit_stop()


func _restaurar_hit_stop() -> void:
	_hit_stop_remaining = 0.0
	_hit_stop_active = false
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	if _hit_stop_active:
		_restaurar_hit_stop()


func _secuencia_muerte() -> void:
	if not is_inside_tree():
		return
	_hit_stop_active = true
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.10, true, false, true).timeout
	if is_inside_tree():
		Engine.time_scale = 0.25
		await get_tree().create_timer(0.45, true, false, true).timeout
	_restaurar_hit_stop()


func apply_knockback(dir: Vector2, force: float) -> void:
	if force <= 0.0:
		return
	var push := dir.normalized()
	# Apply strong horizontal knockback
	velocity.x += push.x * force
	# Moderate vertical impulse, never launch out of the map
	if push.y < -0.15:
		velocity.y = maxf(velocity.y + push.y * force * 0.35, -420.0)
	elif push.y > 0.0:
		velocity.y += push.y * force * 0.35


func _on_died() -> void:
	AudioManager.reproducir("muerte")
	CombatCamera.shake_viewport(self, 9.0, 0.35)
	_secuencia_muerte()
	can_control = false
	current_state = PlayerState.DEAD
	_ragdoll_timer = 0.0
	_body_animation.call_deferred("stop")
	if _parry_effect != null:
		_parry_effect.visible = false
		_parry_effect.stop()

	if _floating_hp != null:
		_floating_hp.update_health(0, _health.max_health)

	# Impulso de caída al suelo
	velocity.x *= 0.3
	velocity.y = maxf(velocity.y, 140.0)

	# Rotar el personaje tumbado en el suelo
	var rot_target := deg_to_rad(90.0 if facing >= 0 else -90.0)
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property($Visual, "rotation", rot_target, 0.22).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property($Visual, "position:y", 8.0, 0.22)
	_death_tween.tween_property(self, "modulate", Color(0.72, 0.72, 0.78, 1.0), 0.3)

	# Desvanecer y ocultar el cadáver tras una breve pausa
	# Se guarda para poder cancelarlo en respawn(): si el jugador revive antes de
	# que termine, un tween huérfano dejaría vivo pero invisible al personaje.
	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.8)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_fade_tween.tween_callback(func():
		if current_state == PlayerState.DEAD:
			visible = false
	)

	# Desactivar colisión con proyectiles para no deflectar ni recibir más impactos
	var hurtbox := get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		hurtbox.set_active(false)

	_spawn_blood()


func _spawn_blood() -> void:
	var scene_root := get_tree().current_scene if is_inside_tree() else get_parent()
	if scene_root == null:
		return
	var blood := BLOOD_SCENE.instantiate() as Node2D
	blood.global_position = global_position + Vector2(0, -6)
	scene_root.add_child(blood)


func stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	can_control = false
	modulate = Color(0.7, 0.7, 1.3, 1.0)


func _update_stun(delta: float) -> void:
	if _stun_timer <= 0.0:
		return
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		if _ragdoll_timer <= 0.0:
			can_control = true
		modulate = Color(1.0, 1.0, 1.0, 1.0)


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	can_control = true
	invulnerable = false
	_spawn_protection_timer = 0.5
	current_state = PlayerState.IDLE
	_ragdoll_timer = 0.0
	_parry_cooldown = 0.0
	if _parry_effect != null:
		_parry_effect.visible = false
		_parry_effect.stop()
	_stun_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_lockout_timer = 0.0
	_last_wall_jump_side = 0
	_toxic_cloud_count = 0
	_poison_flash_timer = 0.0
	_active_dots.clear()
	gravity_scale = 1.0
	jump_force_multiplier = 1.0
	_adaptive_armor_stacks = 0
	_adaptive_armor_timer = 0.0
	_second_skin_timer = 0.0
	_second_skin_tick_timer = 0.0
	_slow_factor = 1.0
	_slow_timer = 0.0
	_gravity_mult = 1.0
	_gravity_mult_timer = 0.0
	_jump_mult = 1.0
	_jump_mult_timer = 0.0
	_in_blood_debt = false
	_blood_debt_timer = 0.0
	_blood_debt_healed = 0
	_blood_debt_cooldown = 0.0
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _skeleton_sprite != null:
		_skeleton_sprite.modulate = Color.WHITE
		_skeleton_sprite.visible = true
	facing = 1
	var sx := absf($Visual.scale.x)
	$Visual.scale.x = sx if sx > 0.001 else 1.0
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	$Visual.rotation = 0.0
	$Visual.position = Vector2.ZERO
	_body_animation.play("stand")
	if _skeleton_sprite != null:
		_skeleton_sprite.play("idle")
	_update_visual_facing()
	_health.reset()
	# Reactivar el hurtbox. set_active() reconcilia el shape en el próximo frame
	# físico, así no compite con el disable encolado por _on_died.
	var hurtbox := get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox != null:
		hurtbox.set_active(true)
	if _weapon != null and _weapon.has_method("reset_cooldown"):
		_weapon.reset_cooldown(0.35)
	if _weapon != null and _weapon.has_method("reset_ammo"):
		_weapon.reset_ammo()
	if _floating_hp != null:
		_floating_hp.setup(player_number, _health.health, _health.max_health)


func aplicar_mejoras(upgrades: Array) -> void:
	_effects.clear()
	_stats.limpiar()
	has_blood_debt = false

	for def in upgrades:
		for mod in def.stats:
			_stats.agregar_modificador(mod)
	for def in upgrades:
		for efecto in def.efectos:
			var ef_inst: UpgradeEffect = efecto.duplicate(true)
			_effects.append(ef_inst)
			ef_inst.on_apply(self, 1)
	_health.max_health = maxi(_stats.get_entero(&"max_health"), 1)
	_health.reset()
	if _floating_hp != null:
		_floating_hp.setup(player_number, _health.health, _health.max_health)
	_weapon.configurar(_stats, self, _effects)
	if not _weapon.reload_started.is_connected(_on_weapon_reload_started):
		_weapon.reload_started.connect(_on_weapon_reload_started)


func _on_weapon_reload_started() -> void:
	for ef in _effects:
		if ef.has_method("on_reload_started"):
			ef.on_reload_started(self)


func hurt(amount: int, source: Node = null) -> void:
	if not is_alive() or invulnerable or _spawn_protection_timer > 0.0:
		return

	# Daño letal extremo de zonas de muerte / abismo
	if amount >= 999:
		_health.apply_damage(_health.health, source)
		return

	# Mitigación por armadura (Piel Adaptativa)
	var armor_red := get_armor_reduction()
	var final_amount: int = maxi(int(round(float(amount) * (1.0 - armor_red))), 1)

	# Deuda de Sangre: sobrevive en deuda por 5 segundos si el daño es letal
	if has_blood_debt:
		if _health.health - final_amount <= 0:
			if not _in_blood_debt and _blood_debt_cooldown <= 0.0:
				_in_blood_debt = true
				_blood_debt_timer = 5.0
				_blood_debt_healed = 0
				final_amount = maxi(_health.health - 1, 0)
			elif _in_blood_debt:
				final_amount = maxi(_health.health - 1, 0)

	_health.apply_damage(final_amount, source)


func heal(amount: int) -> void:
	if not is_alive():
		return
	var prev_hp := _health.health
	_health.heal(amount)
	var healed := _health.health - prev_hp
	if healed > 0:
		if _in_blood_debt:
			_blood_debt_healed += healed
		for ef in _effects:
			if ef.has_method("on_healed"):
				ef.on_healed(healed, self)


func get_armor_reduction() -> float:
	var total: float = 0.0
	if _adaptive_armor_stacks > 0:
		total += float(_adaptive_armor_stacks) * 0.08
	return clampf(total, 0.0, 0.75)


func get_speed_multiplier() -> float:
	var mult: float = 1.0
	if _slow_timer > 0.0:
		mult *= _slow_factor
	return mult


func get_damage_multiplier() -> float:
	var mult: float = 1.0
	return mult


func has_effect_id(effect_id: String) -> bool:
	for ef in _effects:
		if ef.get("effect_id") == effect_id:
			return true
	return false


func apply_recoil(impulse: Vector2) -> void:
	if current_state == PlayerState.DEAD:
		return
	# Si el retroceso impulsa hacia arriba, cancelamos la inercia de caída previa
	if impulse.y < -50.0 and velocity.y > 0.0:
		velocity.y = 0.0
	velocity += impulse
	# Tope de acumulación: al spamear disparos el retroceso se suma, pero sin
	# salir disparado fuera de la arena.
	velocity.x = clampf(velocity.x, -700.0, 700.0)
	velocity.y = clampf(velocity.y, -640.0, 900.0)


func apply_slow(factor: float, duration: float) -> void:
	if current_state == PlayerState.DEAD:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)


func apply_gravity_debuff(grav_scale: float, jump_scale: float, duration: float = 0.20) -> void:
	if current_state == PlayerState.DEAD:
		return
	_gravity_mult = maxf(_gravity_mult, grav_scale)
	_gravity_mult_timer = maxf(_gravity_mult_timer, duration)
	_jump_mult = minf(_jump_mult, jump_scale)
	_jump_mult_timer = maxf(_jump_mult_timer, duration)


func _update_buffs(delta: float) -> void:
	# Armadura Adaptativa
	if _adaptive_armor_timer > 0.0:
		_adaptive_armor_timer -= delta
		if _adaptive_armor_timer <= 0.0:
			_adaptive_armor_stacks = 0

	# Regeneración (Segunda Piel)
	if _second_skin_timer > 0.0:
		_second_skin_timer -= delta
		_second_skin_tick_timer -= delta
		if _second_skin_tick_timer <= 0.0:
			_second_skin_tick_timer = 0.5
			heal(2)

	# Ralentización
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	# Debuff de Gravedad y Salto (Zona de Gravedad)
	if _gravity_mult_timer > 0.0:
		_gravity_mult_timer -= delta
		if _gravity_mult_timer <= 0.0:
			_gravity_mult = 1.0

	if _jump_mult_timer > 0.0:
		_jump_mult_timer -= delta
		if _jump_mult_timer <= 0.0:
			_jump_mult = 1.0

	# Deuda de Sangre
	if _blood_debt_cooldown > 0.0:
		_blood_debt_cooldown -= delta
	if _in_blood_debt:
		_blood_debt_timer -= delta
		if _blood_debt_timer <= 0.0:
			_in_blood_debt = false
			if _blood_debt_healed < 1:
				_health.apply_damage(_health.health, null)
			else:
				_blood_debt_cooldown = 10.0

	# Notificar a los efectos activos
	for ef in _effects:
		if ef.has_method("on_process"):
			ef.on_process(delta, self)


func apply_dot(damage_per_tick: float, ticks_count: int = 3, source: Node = null) -> void:
	if current_state == PlayerState.DEAD:
		return
	var dmg := maxi(int(round(damage_per_tick)), 4)
	var ticks := maxi(ticks_count, 1)
	for dot in _active_dots:
		if dot.get("source") == source:
			dot["damage_per_tick"] = dmg
			dot["ticks_remaining"] = ticks
			dot["tick_timer"] = 0.65
			return
	_active_dots.append({
		"damage_per_tick": dmg,
		"ticks_remaining": ticks,
		"tick_timer": 0.65,
		"source": source
	})


func apply_poison_tick(damage: float, _source: Node = null) -> void:
	if current_state == PlayerState.DEAD:
		return
	var dmg := maxi(int(round(damage)), 1)
	_health.apply_silent_damage(dmg)
	_trigger_poison_feedback()


func set_in_toxic_cloud(in_cloud: bool) -> void:
	if in_cloud:
		_toxic_cloud_count += 1
	else:
		_toxic_cloud_count = maxi(_toxic_cloud_count - 1, 0)


func _trigger_poison_feedback() -> void:
	_poison_flash_timer = 0.14
	AudioManager.reproducir("golpe", 0.04)


func _update_dots(delta: float) -> void:
	if _poison_flash_timer > 0.0:
		_poison_flash_timer -= delta

	var i := _active_dots.size() - 1
	var is_poisoned := false
	while i >= 0:
		var dot: Dictionary = _active_dots[i]
		dot["tick_timer"] -= delta
		if dot["tick_timer"] <= 0.0:
			dot["tick_timer"] = 0.65
			dot["ticks_remaining"] -= 1
			_health.apply_silent_damage(dot["damage_per_tick"])
			_trigger_poison_feedback()
		if dot["ticks_remaining"] > 0:
			is_poisoned = true
		else:
			_active_dots.remove_at(i)
		i -= 1

	if _stun_timer <= 0.0 and current_state != PlayerState.DEAD:
		if _in_blood_debt:
			var pulse := 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.012)
			modulate = Color(1.8 * pulse, 0.2, 0.2, 1.0)
		elif _poison_flash_timer > 0.0:
			modulate = Color(0.4, 2.2, 0.4, 1.0)
		elif is_poisoned or _toxic_cloud_count > 0:
			modulate = Color(0.55, 1.25, 0.55, 1.0)
		elif modulate != Color(1.0, 1.0, 1.0, 1.0):
			modulate = Color(1.0, 1.0, 1.0, 1.0)
