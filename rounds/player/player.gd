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

@export_group("Jump Game Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var corner_correction_step: float = 2.0
@export var corner_correction_max: float = 12.0

@onready var _input: PlayerInput = $PlayerInput
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _health: HealthComponent = $HealthComponent
@onready var _stats: StatSheet = $StatSheet
@onready var _body_animation: AnimationPlayer = $BodyAnimation
@onready var _hit_flash: AnimationPlayer = $HitFlash
@onready var _corner_ray_left: RayCast2D = $CornerRayLeft
@onready var _corner_ray_right: RayCast2D = $CornerRayRight
@onready var _ground_ray: RayCast2D = $GroundRay
@onready var _skeleton_sprite: AnimatedSprite2D = $Visual.get_node_or_null("SkeletonSprite")
@onready var _body_mesh: Polygon2D = $Visual.get_node_or_null("Body")
@onready var _wing_mesh: Polygon2D = $Visual.get_node_or_null("Wing")
@onready var _beak_mesh: Polygon2D = $Visual.get_node_or_null("Beak")
@onready var _eye_mesh: Polygon2D = $Visual.get_node_or_null("Eye")
@onready var _pupil_mesh: Polygon2D = $Visual.get_node_or_null("Pupil")
@onready var _feet_node: Node2D = $Visual.get_node_or_null("Feet")
@onready var _floating_hp: Node2D = get_node_or_null("FloatingHealthBar")

var facing: int = 1
var can_control: bool = true
var current_state: PlayerState = PlayerState.IDLE
var tipo_personaje: String = "pato"

var _effects: Array = []
var _active_dots: Array = []
var _toxic_cloud_count: int = 0
var _poison_flash_timer: float = 0.0
var _ragdoll_timer: float = 0.0
var _stun_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _spawn_position: Vector2
var _hit_stop_remaining: float = 0.0
var _hit_stop_active: bool = false


func _ready() -> void:
	_spawn_position = global_position
	add_to_group("player")
	RunManager.registrar_jugador(self)
	_configurar_personaje()
	_update_visual_facing()
	if _floating_hp != null:
		_floating_hp.setup(player_number, _health.health, _health.max_health)
		_health.health_changed.connect(_floating_hp.update_health)


func _physics_process(delta: float) -> void:
	_update_stun(delta)
	_update_dots(delta)
	_update_ragdoll(delta)
	_update_state()
	_apply_gravity(delta)
	_update_jump_timers(delta)

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


func _set_duck_parts_visible(v: bool) -> void:
	if _body_mesh != null: _body_mesh.visible = v
	if _wing_mesh != null: _wing_mesh.visible = v
	if _beak_mesh != null: _beak_mesh.visible = v
	if _eye_mesh != null: _eye_mesh.visible = v
	if _pupil_mesh != null: _pupil_mesh.visible = v
	if _feet_node != null: _feet_node.visible = v


func _configurar_personaje() -> void:
	tipo_personaje = RunManager.personaje_de(player_number)
	if tipo_personaje == "esqueleto":
		_set_duck_parts_visible(false)
		if _skeleton_sprite != null:
			_skeleton_sprite.visible = true
			_skeleton_sprite.modulate = Color.WHITE
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://player/skeleton_palette.gdshader")
			if player_number == 1:
				mat.set_shader_parameter("color_highlight", Color(1.0, 0.95, 0.25, 1.0))
				mat.set_shader_parameter("color_midtone", Color(1.0, 0.85, 0.15, 1.0))
				mat.set_shader_parameter("color_shadow", Color(0.65, 0.48, 0.08, 1.0))
			else:
				mat.set_shader_parameter("color_highlight", Color(0.80, 0.98, 1.0, 1.0))
				mat.set_shader_parameter("color_midtone", Color(0.35, 0.78, 1.0, 1.0))
				mat.set_shader_parameter("color_shadow", Color(0.08, 0.20, 0.38, 1.0))
			_skeleton_sprite.material = mat
			_skeleton_sprite.play("idle")
		_body_animation.play("stand")
	else:
		_set_duck_parts_visible(true)
		if _wing_mesh != null:
			if player_number == 1:
				_wing_mesh.color = Color(0.85, 0.68, 0.1, 1.0)
			else:
				_wing_mesh.color = Color(0.2, 0.58, 0.85, 1.0)
		if _skeleton_sprite != null:
			_skeleton_sprite.visible = false
		_body_animation.play("duck_idle")


func _update_character_visual() -> void:
	if tipo_personaje == "esqueleto":
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
	else:
		match current_state:
			PlayerState.DEAD:
				_body_animation.stop()
			PlayerState.WALKING:
				if _body_animation.current_animation != "duck_walk":
					_body_animation.play("duck_walk")
			_:
				if _body_animation.current_animation != "duck_idle":
					_body_animation.play("duck_idle")


func _update_jump_timers(delta: float) -> void:
	if not can_control or current_state == PlayerState.DEAD:
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return

	_ground_ray.force_raycast_update()
	if _ground_ray.is_colliding() and velocity.y >= 0.0:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if _input.is_jump_just_pressed():
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


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
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = _stats.get_stat(&"jump_velocity")
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		AudioManager.reproducir("salto", 0.05)
	if _input.is_jump_just_released() and velocity.y < 0.0:
		velocity.y *= 0.5


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
	_weapon.position = Vector2(4.0 * facing, 9.0)


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
	CombatCamera.shake_viewport(self, 4.0, 0.2)
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
	_body_animation.stop()

	if _floating_hp != null:
		_floating_hp.update_health(0, _health.max_health)

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
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_toxic_cloud_count = 0
	_poison_flash_timer = 0.0
	_active_dots.clear()
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	$Visual.rotation = 0.0
	$Visual.position = Vector2.ZERO
	if tipo_personaje == "esqueleto":
		_body_animation.play("stand")
		if _skeleton_sprite != null:
			_skeleton_sprite.play("idle")
	else:
		_body_animation.play("duck_idle")
	_update_visual_facing()
	_health.reset()
	var hurtbox_col := get_node_or_null("HurtboxComponent/CollisionShape2D") as CollisionShape2D
	if hurtbox_col != null:
		hurtbox_col.set_deferred("disabled", false)
	if _weapon != null and _weapon.has_method("reset_cooldown"):
		_weapon.reset_cooldown(0.35)
	if _weapon != null and _weapon.has_method("reset_ammo"):
		_weapon.reset_ammo()
	if _floating_hp != null:
		_floating_hp.setup(player_number, _health.health, _health.max_health)


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
	if _floating_hp != null:
		_floating_hp.setup(player_number, _health.health, _health.max_health)
	_weapon.configurar(_stats, self, _effects)


func hurt(amount: int, source: Node = null) -> void:
	_health.apply_damage(amount, source)


func heal(amount: int) -> void:
	_health.heal(amount)


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
	var dmg := maxi(int(round(damage)), 4)
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
		if _poison_flash_timer > 0.0:
			modulate = Color(0.4, 2.2, 0.4, 1.0)
		elif is_poisoned or _toxic_cloud_count > 0:
			modulate = Color(0.55, 1.25, 0.55, 1.0)
		elif modulate != Color(1.0, 1.0, 1.0, 1.0):
			modulate = Color(1.0, 1.0, 1.0, 1.0)
