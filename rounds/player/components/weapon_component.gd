class_name WeaponComponent
extends Node2D

signal fired
signal ammo_changed(current: int, maximum: int)
signal reload_started
signal reload_completed

@export var bullet_scene: PackedScene

@onready var muzzle: Marker2D = $Muzzle

var aim_direction: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0
var _stats: StatSheet = null
var _player: Node = null
var _effects: Array = []

var max_ammo: int = 3
var current_ammo: int = 3
var is_reloading: bool = false
var reload_time: float = 1.2
var _reload_timer: float = 0.0
var _quickdraw_ready: bool = false
var _roulette_bullet: int = -1


func _ready() -> void:
	current_ammo = max_ammo


func configurar(stats: StatSheet, player: Node, effects: Array) -> void:
	_stats = stats
	_player = player
	_effects = effects
	max_ammo = _stat_entero(&"max_ammo", 3)
	reload_time = _stat(&"reload_time", 1.2)
	current_ammo = max_ammo
	is_reloading = false
	_on_reload_finished()
	ammo_changed.emit(current_ammo, max_ammo)
	_cooldown = 0.35


func reset_cooldown(time: float = 0.35) -> void:
	_cooldown = time


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			is_reloading = false
			current_ammo = max_ammo
			_on_reload_finished()
			ammo_changed.emit(current_ammo, max_ammo)
			reload_completed.emit()


func start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
	is_reloading = true
	_reload_timer = reload_time
	reload_started.emit()


func get_reload_progress() -> float:
	if not is_reloading or reload_time <= 0.0:
		return 1.0
	return clampf(1.0 - (_reload_timer / reload_time), 0.0, 1.0)


func reset_ammo() -> void:
	is_reloading = false
	_reload_timer = 0.0
	current_ammo = max_ammo
	ammo_changed.emit(current_ammo, max_ammo)
	reload_completed.emit()


func set_aim(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	aim_direction = direction.normalized()
	rotation = aim_direction.angle()
	if absf(rotation) > PI * 0.5:
		scale.y = -1.0
	else:
		scale.y = 1.0


func can_fire() -> bool:
	return _cooldown <= 0.0 and bullet_scene != null and not is_reloading and current_ammo > 0


func try_fire() -> bool:
	if is_reloading:
		return false
	if current_ammo <= 0:
		start_reload()
		return false
	if not can_fire():
		return false

	var cantidad := _stat_entero(&"projectiles", 1)
	var dispersion: float = _stat(&"spread", 0.0)
	var dano := _stat_entero(&"damage", 25)
	var velocidad: float = _stat(&"bullet_speed", 1050.0)
	var duracion: float = _stat(&"bullet_lifetime", 1.5)
	var penetracion := _stat_entero(&"pierce", 0)
	var empuje: float = _stat(&"knockback", 0.0)
	var gravedad: float = _stat(&"bullet_gravity", 1200.0)
	var rozamiento: float = _stat(&"bullet_drag", 0.0)

	var is_quick := false
	if _quickdraw_ready:
		is_quick = true
		_quickdraw_ready = false
		dispersion = 0.0
		velocidad *= 1.70

	var is_roulette := false
	if current_ammo == _roulette_bullet:
		is_roulette = true
		_roulette_bullet = -1
		dano = int(round(dano * 4.0))

	var base_angle := aim_direction.angle()
	var centro := (cantidad - 1) / 2.0

	if _has_laser_sight():
		_fire_laser(dano, empuje, is_roulette)
	else:
		var rebotes := _stat_entero(&"bounces", 0)
		var penetracion_pared := _stat_entero(&"wall_pierce", 0)
		var escala_bala := _stat(&"bullet_scale", 1.0)
		for i in cantidad:
			var angulo := base_angle + deg_to_rad(dispersion * (i - centro))
			var bala := bullet_scene.instantiate()
			bala.direction = Vector2.RIGHT.rotated(angulo)
			bala.shooter = _player
			bala.player = _player
			bala.damage = dano
			bala.speed = velocidad
			bala.lifetime = duracion
			bala.pierce = penetracion
			bala.knockback = empuje
			bala.bullet_gravity = gravedad
			bala.drag = rozamiento
			bala.bounces = rebotes
			bala.wall_pierce = penetracion_pared
			if is_quick:
				bala.modulate = Color(1.3, 1.2, 0.4, 1.0)
			if is_roulette:
				escala_bala *= 1.3
				bala.modulate = Color(1.8, 0.2, 0.2, 1.0)
			if escala_bala != 1.0:
				bala.scale = Vector2(escala_bala, escala_bala)
			bala.effects = _effects.duplicate(true)
			for efecto in bala.effects:
				efecto.on_fire(bala, _player)
			get_tree().current_scene.add_child(bala)
			var spawn_pos: Vector2 = muzzle.global_position
			if _player != null and _player.has_method("is_on_floor") and _player.is_on_floor():
				var effective_rad: float = 4.0 * escala_bala
				var max_allowed_y: float = _player.global_position.y + 20.0 - effective_rad - 2.0
				if spawn_pos.y > max_allowed_y:
					spawn_pos.y = max_allowed_y
			bala.global_position = spawn_pos

	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	if current_ammo <= 0:
		start_reload()

	_cooldown = 1.0 / maxf(_stat(&"fire_rate", 5.0), 0.1)
	if is_roulette:
		AudioManager.reproducir("golpe", 0.08)
	AudioManager.reproducir("disparo", 0.06)
	fired.emit()
	return true


func _stat(stat: StringName, por_defecto: float) -> float:
	if _stats == null:
		return por_defecto
	return _stats.get_stat(stat)


func _stat_entero(stat: StringName, por_defecto: int) -> int:
	return int(round(_stat(stat, float(por_defecto))))


func _has_laser_sight() -> bool:
	for ef in _effects:
		if ef.get("is_laser_sight") == true:
			return true
	return false


func _has_glitch() -> bool:
	for ef in _effects:
		if ef.get("is_glitch") == true:
			return true
	return false


func _fire_laser(dano: int, empuje: float, is_roulette: bool = false) -> void:
	if _player != null:
		_player.set_meta("last_laser_damage", dano)
	var color := Color(1.0, 0.2, 0.2, 0.98) if is_roulette else Color(0.25, 0.9, 1.0, 0.95)
	var width := 6.0 if is_roulette else 4.0
	_fire_single_laser(aim_direction, dano, empuje, color, width)

	if _has_glitch() and randf() < 0.50:
		var clone_dmg := maxi(int(round(dano * 0.50)), 1)
		_fire_single_laser(aim_direction.rotated(deg_to_rad(-16.0)), clone_dmg, empuje * 0.5, Color(0.2, 1.8, 1.8, 0.95), 3.0)
		_fire_single_laser(aim_direction.rotated(deg_to_rad(16.0)), clone_dmg, empuje * 0.5, Color(1.8, 0.2, 1.6, 0.95), 3.0)


func _fire_single_laser(dir: Vector2, dano: int, empuje: float, color: Color, width: float) -> void:
	var from_pos := muzzle.global_position
	var to_pos := from_pos + dir * 1400.0

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = 5  # Hurtbox (4) and solid world (1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _player != null:
		query.exclude = [_player]

	var result := space.intersect_ray(query)
	var hit_pos := to_pos
	if not result.is_empty():
		hit_pos = result["position"]
		var collider: Node = result.get("collider") as Node
		if collider != null:
			if collider.has_method("take_hit"):
				collider.take_hit(dano, _player)
			var target_player: Node = collider.get_parent()
			if target_player != null and target_player.has_method("apply_knockback") and empuje > 0.0:
				target_player.apply_knockback(dir, empuje)
			for ef in _effects:
				if collider is Area2D and ef.has_method("on_hit"):
					ef.on_hit(null, collider, _player)
				elif ef.has_method("on_body_hit"):
					ef.on_body_hit(null, collider, _player)

	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.add_point(from_pos)
	line.add_point(hit_pos)
	get_tree().current_scene.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.tween_callback(line.queue_free)


func _on_reload_finished() -> void:
	if _has_quickdraw():
		_quickdraw_ready = true
	if _has_russian_roulette():
		if randf() < 0.50 and max_ammo > 0:
			_roulette_bullet = randi_range(1, max_ammo)
		else:
			_roulette_bullet = -1


func _has_quickdraw() -> bool:
	for ef in _effects:
		if ef.get("is_quickdraw") == true:
			return true
	return false


func _has_russian_roulette() -> bool:
	for ef in _effects:
		if ef.get("is_russian_roulette") == true:
			return true
	return false
