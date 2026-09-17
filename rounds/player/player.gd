class_name Player
extends CharacterBody2D

signal quacked(player_number: int)
signal grabbed(player_number: int)
signal parried_bullet(bullet: Node)

enum PlayerState {
	IDLE,
	WALKING,
	AIRBORNE,
	RAGDOLL,
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
		PlayerState.RAGDOLL:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		PlayerState.IDLE, PlayerState.WALKING, PlayerState.AIRBORNE:
			_handle_horizontal(delta)
			_handle_jump()
			_handle_aim()
			_handle_actions()

	move_and_slide()


func _update_state() -> void:
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


func is_spinning() -> bool:
	return _ragdoll_timer > 0.0 or current_state == PlayerState.RAGDOLL


func can_parry() -> bool:
	return is_spinning()


func on_parry(bullet: Node) -> void:
	parried_bullet.emit(bullet)
	print("Player %d: Parried!" % player_number)


func _on_damaged(_amount: int, source: Node) -> void:
	AudioManager.reproducir("golpe", 0.1)
	_hit_flash.play("hit")
	if source != null and source is Node2D:
		velocity += (global_position - (source as Node2D).global_position).normalized() * 220.0


func _on_died() -> void:
	AudioManager.reproducir("muerte")
	velocity = Vector2.ZERO
	can_control = false
	current_state = PlayerState.RAGDOLL
	_body_animation.play("ragdoll")


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
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_body_animation.play("stand")
	_update_visual_facing()
	_health.reset()


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


func apply_dot(dps: float, duration: float, source: Node = null) -> void:
	_active_dots.append({
		"dps": dps,
		"time_left": duration,
		"source": source
	})


func _update_dots(delta: float) -> void:
	var i := _active_dots.size() - 1
	while i >= 0:
		var dot: Dictionary = _active_dots[i]
		dot["time_left"] -= delta
		var tick_damage: float = dot["dps"] * delta
		if tick_damage > 0.0:
			hurt(int(round(tick_damage)), dot.get("source"))
		if dot["time_left"] <= 0.0:
			_active_dots.remove_at(i)
		i -= 1
