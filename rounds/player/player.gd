class_name Player
extends CharacterBody2D

signal quacked(player_number: int)
signal grabbed(player_number: int)

enum PlayerState {
	IDLE,
	WALKING,
	CROUCHING,
	AIRBORNE,
	RAGDOLL,
}

@export var player_number: int = 1

@export_group("Movement")
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0
@export var air_control: float = 0.55
@export var gravity: float = 1500.0
@export var max_fall_speed: float = 950.0
@export var crouch_speed_multiplier: float = 0.4
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
var _crouching: bool = false
var _ragdoll_timer: float = 0.0
var _spawn_position: Vector2


func _ready() -> void:
	_spawn_position = global_position
	RunManager.registrar_jugador(self)


func _physics_process(delta: float) -> void:
	_update_ragdoll(delta)
	_update_state()
	_apply_gravity(delta)

	match current_state:
		PlayerState.RAGDOLL:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		PlayerState.IDLE, PlayerState.WALKING, PlayerState.CROUCHING, PlayerState.AIRBORNE:
			_handle_horizontal(delta)
			_handle_jump()
			_handle_aim()
			_handle_actions()

	move_and_slide()
	_update_crouch()


func _update_state() -> void:
	if not can_control:
		current_state = PlayerState.RAGDOLL
	elif not is_on_floor():
		current_state = PlayerState.AIRBORNE
	elif _crouching:
		current_state = PlayerState.CROUCHING
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
	var direction := _input.move_axis()
	var speed := _stats.get_stat(&"move_speed")
	if _crouching:
		speed *= crouch_speed_multiplier
	var accel := acceleration if is_on_floor() else acceleration * air_control
	velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	if not is_zero_approx(direction) and not _input.is_strafe_pressed():
		facing = signi(direction)


func _handle_jump() -> void:
	if _input.is_jump_just_pressed() and is_on_floor():
		velocity.y = _stats.get_stat(&"jump_velocity")
	if _input.is_jump_just_released() and velocity.y < 0.0:
		velocity.y *= 0.5


func _handle_aim() -> void:
	var direction := _input.aim()
	if direction.is_zero_approx():
		direction = Vector2(facing, 0.0)
	_weapon.set_aim(direction)


func _handle_actions() -> void:
	if _input.is_fire_pressed():
		_weapon.try_fire()
	if _input.is_grab_just_pressed():
		grabbed.emit(player_number)
	if _input.is_ragdoll_just_pressed():
		_start_ragdoll()
	if _input.is_quack_just_pressed():
		quacked.emit(player_number)
		print("Player %d: Quack!" % player_number)


func _update_crouch() -> void:
	if not can_control:
		return
	var wants_crouch := _input.is_crouch_pressed() and is_on_floor()
	if wants_crouch == _crouching:
		return
	_crouching = wants_crouch
	_body_animation.play("crouch" if _crouching else "stand")


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


func _on_damaged(_amount: int, source: Node) -> void:
	_hit_flash.play("hit")
	if source != null and source is Node2D:
		velocity += (global_position - (source as Node2D).global_position).normalized() * 220.0


func _on_died() -> void:
	velocity = Vector2.ZERO
	can_control = false
	current_state = PlayerState.RAGDOLL
	_body_animation.play("ragdoll")


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	can_control = true
	current_state = PlayerState.IDLE
	_ragdoll_timer = 0.0
	_crouching = false
	_body_animation.play("stand")
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
