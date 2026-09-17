class_name Player
extends CharacterBody2D

signal quacked(player_number: int)
signal grabbed(player_number: int)
signal parried_bullet(bullet: Node)

const BLOOD_SCENE := preload("res://effects/blood_splatter.tscn")

enum PlayerState {
	IDLE,
	WALKING,
	AIRBORNE,
	RAGDOLL,
	DEAD,
}

@export var player_number: int = 1

@export_group("Movement")
@export var acceleration: float = 2000.0
@export var friction: float = 1200.0
@export var air_control: float = 0.70
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1100.0
@export var ragdoll_time: float = 0.6

@onready var _input: PlayerInput = $PlayerInput
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _health: HealthComponent = $HealthComponent
@onready var _stats: StatSheet = $StatSheet
@onready var _body_animation: AnimationPlayer = $BodyAnimation
@onready var _hit_flash: AnimationPlayer = $HitFlash

var facing: int = 1
var can_control: bool = true
var current_state: PlayerState = PlayerState.IDLE

var _effects: Array = []
var _active_dots: Array = []
var _ragdoll_timer: float = 0.0
var _stun_timer: float = 0.0
var _spawn_position: Vector2


func _ready() -> void:
	_spawn_position = global_position
	add_to_group("player")
	RunManager.registrar_jugador(self)
	_update_visual_facing()


func _physics_process(delta: float) -> void:
	_update_stun(delta)
	_update_dots(delta)
	_update_ragdoll(delta)
	_update_state()
	_apply_gravity(delta)

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


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_horizontal(delta: float) -> void:
	if _input.is_lock_pressed():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return
	var direction := _input.move_axis()
	var speed := _stats.get_stat(&"move_speed")
	if absf(velocity.x) > speed and (is_zero_approx(direction) or signi(velocity.x) != signi(direction)):
		var decel := friction * 0.4 if is_on_floor() else friction * 0.15
		velocity.x = move_toward(velocity.x, direction * speed, decel * delta)
	else:
		var accel := acceleration if is_on_floor() else acceleration * air_control
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	if not is_zero_approx(direction) and not _input.is_strafe_pressed():
		facing = signi(direction)
		_update_visual_facing()


func _handle_jump() -> void:
	if _input.is_lock_pressed():
		return
	if _input.is_jump_just_pressed() and is_on_floor():
		velocity.y = _stats.get_stat(&"jump_velocity")
		AudioManager.reproducir("salto", 0.05)
	if _input.is_jump_just_released() and velocity.y < 0.0:
		velocity.y *= 0.5


func _handle_aim() -> void:
	var direction := _input.aim()
	if direction.is_zero_approx():
		direction = Vector2(facing, 0.0)
	elif not is_zero_approx(direction.x):
		facing = signi(direction.x)
	_weapon.set_aim(direction)
	_update_visual_facing()


func _handle_actions() -> void:
	if _input.is_fire_pressed():
		_weapon.try_fire()
	if _input.is_grab_just_pressed():
		grabbed.emit(player_number)
	if _input.is_ragdoll_just_pressed():
		_start_ragdoll()
	if _input.is_quack_just_pressed():
		quacked.emit(player_number)
		AudioManager.reproducir("cuac", 0.08)


func _update_visual_facing() -> void:
	$Visual.scale.x = absf($Visual.scale.x) * facing
	_weapon.position.x = 4.0 * facing


func _start_ragdoll() -> void:
	current_state = PlayerState.RAGDOLL
	_ragdoll_timer = ragdoll_time
	can_control = false
	velocity.x *= 0.4
	_body_animation.play("ragdoll")


func _update_ragdoll(delta: float) -> void:
	if _ragdoll_timer <= 0.0:
		return
	_ragdoll_timer -= delta
	if _ragdoll_timer <= 0.0:
		can_control = true
		$Visual.rotation = 0.0
		_body_animation.play("stand")


func is_alive() -> bool:
	return _health != null and _health.is_alive() and current_state != PlayerState.DEAD


func is_spinning() -> bool:
	return is_alive() and _ragdoll_timer > 0.0


func can_parry() -> bool:
	return is_spinning()


func on_parry(bullet: Node) -> void:
	parried_bullet.emit(bullet)
	print("Player %d: Parried!" % player_number)


func _on_damaged(_amount: int, _source: Node) -> void:
	AudioManager.reproducir("golpe", 0.1)
	_hit_flash.play("hit")


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
	can_control = false
	current_state = PlayerState.DEAD
	_ragdoll_timer = 0.0
	_body_animation.stop()

	# Impulso de caída al suelo
	velocity.x *= 0.3
	velocity.y = maxf(velocity.y, 140.0)

	# Rotar el personaje tumbado en el suelo
	var rot_target := deg_to_rad(90.0 if facing >= 0 else -90.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property($Visual, "rotation", rot_target, 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property($Visual, "position:y", 8.0, 0.22)
	tween.tween_property(self, "modulate", Color(0.72, 0.72, 0.78, 1.0), 0.3)

	# Desactivar colisión con proyectiles para no deflectar ni recibir más impactos
	var hurtbox_col := get_node_or_null("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	if hurtbox_col != null:
		hurtbox_col.set_deferred("disabled", true)

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
	current_state = PlayerState.IDLE
	_ragdoll_timer = 0.0
	_stun_timer = 0.0
	_active_dots.clear()
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	$Visual.rotation = 0.0
	$Visual.position = Vector2.ZERO
	_body_animation.play("stand")
	_update_visual_facing()
	_health.reset()
	var hurtbox_col := get_node_or_null("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	if hurtbox_col != null:
		hurtbox_col.set_deferred("disabled", false)
	if _weapon != null and _weapon.has_method("reset_cooldown"):
		_weapon.reset_cooldown(0.35)


func aplicar_mejoras(upgrades: Array) -> void:
	_effects.clear()
	_stats.limpiar()
	for def in upgrades:
		for mod in def.stats:
			_stats.agregar_modificador(mod)
	for def in upgrades:
		for efecto in def.efectos:
			_effects.append(efecto)
			efecto.on_apply(self, 1)
	_health.max_health = maxi(_stats.get_entero(&"max_health"), 1)
	_health.reset()
	_weapon.configurar(_stats, self, _effects)


func hurt(amount: int, source: Node = null) -> void:
	_health.apply_damage(amount, source)


func heal(amount: int) -> void:
	_health.heal(amount)


func apply_dot(dps: float, _duration: float, source: Node = null) -> void:
	for dot in _active_dots:
		if dot.get("source") == source:
			dot["ticks_remaining"] = 3
			dot["tick_timer"] = 0.7
			return
	_active_dots.append({
		"damage_per_tick": maxi(int(round(dps)), 5),
		"ticks_remaining": 3,
		"tick_timer": 0.7,
		"source": source
	})


func _update_dots(delta: float) -> void:
	var i := _active_dots.size() - 1
	var is_poisoned := false
	while i >= 0:
		var dot: Dictionary = _active_dots[i]
		dot["tick_timer"] -= delta
		if dot["tick_timer"] <= 0.0:
			dot["tick_timer"] = 0.7
			dot["ticks_remaining"] -= 1
			_health.apply_silent_damage(dot["damage_per_tick"])
		if dot["ticks_remaining"] > 0:
			is_poisoned = true
		else:
			_active_dots.remove_at(i)
		i -= 1

	if is_poisoned and _stun_timer <= 0.0:
		modulate = Color(0.55, 1.15, 0.55, 1.0)
	elif _stun_timer <= 0.0 and modulate != Color(1.0, 1.0, 1.0, 1.0):
		modulate = Color(1.0, 1.0, 1.0, 1.0)
