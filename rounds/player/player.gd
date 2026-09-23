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
}

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
@export var ragdoll_time: float = 0.35

@export_group("Jump Game Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var corner_correction_step: float = 1.0
@export var corner_correction_max: float = 6.0

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
@onready var _floating_hp: Node2D = get_node_or_null("FloatingHealthBar")

var facing: int = 1
var can_control: bool = true
var current_state: PlayerState = PlayerState.IDLE
var tipo_personaje: String = "esqueleto"

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
var _death_tween: Tween = null
var _fade_tween: Tween = null

# Modificadores de físicas dinámicos (auras / campos)
var gravity_scale: float = 1.0
var jump_force_multiplier: float = 1.0

# Armadura y Mitigación
var _adaptive_armor_stacks: int = 0
var _adaptive_armor_timer: float = 0.0
var _harvest_armor_stacks: int = 0
var _harvest_armor_timer: float = 0.0
var _charge_armor: float = 0.0
var _running_time: float = 0.0
var _charge_hit_cooldown: float = 0.0

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

# Corazón de Titanio
var has_titanium_heart: bool = false
var _titanium_heart_ready: bool = true
var _titanium_heart_cooldown: float = 0.0

# Deuda de Sangre
var has_blood_debt: bool = false
var _in_blood_debt: bool = false
var _blood_debt_timer: float = 0.0
var _blood_debt_healed: int = 0
var _blood_debt_cooldown: float = 0.0

# Sepultador (empuje contra pared)
var _sepultador_timer: float = 0.0
var _sepultador_damage: int = 0
var _last_sepultador_source: Node = null

# Barrera (Muro Vivo)
var active_barrier: Node2D = null
var _still_timer: float = 0.0

# Propulsión (Rocket Jump)


func _ready() -> void:
	if player_number > RunManager.cantidad_jugadores:
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


func _physics_process(delta: float) -> void:
	gravity_scale = 1.0
	jump_force_multiplier = 1.0
	_update_stun(delta)
	_update_dots(delta)
	_update_ragdoll(delta)
	_update_buffs(delta)
	_update_state()
	# Vivo y fuera del trompezar: el visual nunca debe quedar tumbado.
	if current_state != PlayerState.DEAD and _ragdoll_timer <= 0.0:
		$Visual.rotation = 0.0
	_apply_gravity(delta)
	_update_jump_timers(delta)
	# Comprobación de límites del mapa (caída al abismo o salir fuera de pantalla)
	if is_alive() and (global_position.y > 850.0 or global_position.y < -400.0 or absf(global_position.x - 640.0) > 950.0):
		_health.apply_damage(_health.health, null)

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
	_check_sepultador_collision()


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
	if not CHARACTER_FRAMES.has(tipo_personaje):
		tipo_personaje = "esqueleto"
	if _skeleton_sprite != null:
		_skeleton_sprite.visible = true
		_skeleton_sprite.sprite_frames = CHARACTER_FRAMES[tipo_personaje]
		_skeleton_sprite.modulate = Color.WHITE
		if tipo_personaje == "esqueleto":
			var paleta := RunManager.paleta_esqueleto(player_number)
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://player/skeleton_palette.gdshader")
			mat.set_shader_parameter("color_highlight", paleta[0])
			mat.set_shader_parameter("color_midtone", paleta[1])
			mat.set_shader_parameter("color_shadow", paleta[2])
			_skeleton_sprite.material = mat
		else:
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
	if not can_control or current_state == PlayerState.DEAD:
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return

	_ground_ray.force_raycast_update()
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
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_horizontal(delta: float) -> void:
	if _input.is_lock_pressed():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return
	var direction := _input.move_axis()
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
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		var total_jump_mult: float = jump_force_multiplier * (_jump_mult if _jump_mult_timer > 0.0 else 1.0)
		velocity.y = _stats.get_stat(&"jump_velocity") * total_jump_mult
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
		facing = 1 if direction.x > 0.0 else -1
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
	var sx := absf($Visual.scale.x)
	if sx < 0.001:
		sx = 1.0
	var f := 1 if facing >= 0 else -1
	$Visual.scale.x = sx * f
	if _weapon != null:
		_weapon.position = Vector2(weapon_offset.x * f, weapon_offset.y)


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
	_body_animation.stop()

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
	current_state = PlayerState.IDLE
	_ragdoll_timer = 0.0
	_stun_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_toxic_cloud_count = 0
	_poison_flash_timer = 0.0
	_active_dots.clear()
	gravity_scale = 1.0
	jump_force_multiplier = 1.0
	_adaptive_armor_stacks = 0
	_adaptive_armor_timer = 0.0
	_harvest_armor_stacks = 0
	_harvest_armor_timer = 0.0
	_charge_armor = 0.0
	_running_time = 0.0
	_charge_hit_cooldown = 0.0
	_second_skin_timer = 0.0
	_second_skin_tick_timer = 0.0
	_slow_factor = 1.0
	_slow_timer = 0.0
	_gravity_mult = 1.0
	_gravity_mult_timer = 0.0
	_jump_mult = 1.0
	_jump_mult_timer = 0.0
	_titanium_heart_ready = true
	_titanium_heart_cooldown = 0.0
	_in_blood_debt = false
	_blood_debt_timer = 0.0
	_blood_debt_healed = 0
	_blood_debt_cooldown = 0.0
	_sepultador_timer = 0.0
	_sepultador_damage = 0
	_last_sepultador_source = null
	if is_instance_valid(active_barrier):
		active_barrier.queue_free()
		active_barrier = null
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
	has_titanium_heart = false
	has_blood_debt = false
	if is_instance_valid(active_barrier):
		active_barrier.queue_free()
		active_barrier = null

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
	if not is_alive():
		return

	# Daño letal extremo de zonas de muerte / abismo
	if amount >= 999:
		_health.apply_damage(_health.health, source)
		return

	# Intercepción por Barrera de Muro Vivo
	if is_instance_valid(active_barrier) and active_barrier.has_method("absorb_hit"):
		if active_barrier.absorb_hit():
			return

	# Mitigación por armadura (Piel Adaptativa, Cosecha, Carga Blindada)
	var armor_red := get_armor_reduction()
	var final_amount: int = maxi(int(round(float(amount) * (1.0 - armor_red))), 1)

	# Corazón de Titanio: no puede bajarte de 25% max HP si está listo
	if has_titanium_heart and _titanium_heart_ready:
		var floor_hp := int(ceil(float(_health.max_health) * 0.25))
		if _health.health > floor_hp and (_health.health - final_amount) < floor_hp:
			final_amount = _health.health - floor_hp
			_titanium_heart_ready = false
			_titanium_heart_cooldown = 12.0
			CombatCamera.shake_viewport(self, 3.0, 0.15)
			AudioManager.reproducir("golpe", 0.15)

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
	if _harvest_armor_stacks > 0:
		total += float(_harvest_armor_stacks) * 0.05
	total += _charge_armor
	return clampf(total, 0.0, 0.75)


func get_speed_multiplier() -> float:
	var mult: float = 1.0
	if _slow_timer > 0.0:
		mult *= _slow_factor
	if has_effect_id("ira_sangre") and _health.health <= int(float(_health.max_health) * 0.5):
		mult *= 1.15
	return mult


func get_damage_multiplier() -> float:
	var mult: float = 1.0
	if has_effect_id("ira_sangre") and _health.health <= int(float(_health.max_health) * 0.5):
		mult *= 1.25
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


func mark_sepultador(source: Node, bullet_dmg: int, duration: float = 0.6) -> void:
	_last_sepultador_source = source
	_sepultador_damage = bullet_dmg
	_sepultador_timer = duration


func _check_sepultador_collision() -> void:
	if _sepultador_timer <= 0.0 or current_state == PlayerState.DEAD:
		return
	if is_on_wall() and absf(velocity.x) > 30.0:
		var bonus_dmg := maxi(int(round(float(_sepultador_damage) * 0.50)), 1)
		hurt(bonus_dmg, _last_sepultador_source)
		stun(0.40)
		CombatCamera.shake_viewport(self, 5.0, 0.2)
		AudioManager.reproducir("golpe", 0.15)
		_sepultador_timer = 0.0
		_last_sepultador_source = null


func _update_buffs(delta: float) -> void:
	# Armadura Adaptativa
	if _adaptive_armor_timer > 0.0:
		_adaptive_armor_timer -= delta
		if _adaptive_armor_timer <= 0.0:
			_adaptive_armor_stacks = 0

	# Cosecha de Balas
	if _harvest_armor_timer > 0.0:
		_harvest_armor_timer -= delta
		if _harvest_armor_timer <= 0.0:
			_harvest_armor_stacks = 0

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

	# Corazón de Titanio
	if _titanium_heart_cooldown > 0.0:
		_titanium_heart_cooldown -= delta
		if _titanium_heart_cooldown <= 0.0:
			_titanium_heart_ready = true

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

	# Sepultador
	if _sepultador_timer > 0.0:
		_sepultador_timer -= delta
		if _sepultador_timer <= 0.0:
			_last_sepultador_source = null

	# Cooldown de Carga Blindada
	if _charge_hit_cooldown > 0.0:
		_charge_hit_cooldown -= delta

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
		elif has_effect_id("ira_sangre") and _health.health <= int(float(_health.max_health) * 0.5):
			modulate = Color(1.35, 0.8, 0.8, 1.0)
		elif modulate != Color(1.0, 1.0, 1.0, 1.0):
			modulate = Color(1.0, 1.0, 1.0, 1.0)
