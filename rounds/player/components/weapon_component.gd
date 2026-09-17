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
	ammo_changed.emit(current_ammo, max_ammo)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			is_reloading = false
			current_ammo = max_ammo
			ammo_changed.emit(current_ammo, max_ammo)
			reload_completed.emit()


func start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
	is_reloading = true
	_reload_timer = reload_time
	reload_started.emit()


func set_aim(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	aim_direction = direction.normalized()
	rotation = aim_direction.angle()


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
	var velocidad: float = _stat(&"bullet_speed", 780.0)
	var duracion: float = _stat(&"bullet_lifetime", 2.5)
	var penetracion := _stat_entero(&"pierce", 0)
	var empuje: float = _stat(&"knockback", 0.0)
	var gravedad: float = _stat(&"bullet_gravity", 720.0)
	var rozamiento: float = _stat(&"bullet_drag", 0.2)

	var base_angle := aim_direction.angle()
	var centro := (cantidad - 1) / 2.0

	if _has_laser_sight():
		_fire_laser(dano, empuje)
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
			if escala_bala != 1.0:
				bala.scale = Vector2(escala_bala, escala_bala)
			bala.effects = _effects
			for efecto in _effects:
				efecto.on_fire(bala, _player)
			get_tree().current_scene.add_child(bala)
			var spawn_pos: Vector2 = muzzle.global_position
			if _player != null and _player.has_method("is_on_floor") and _player.is_on_floor():
				if spawn_pos.y > _player.global_position.y + 13.0:
					spawn_pos.y = _player.global_position.y + 13.0
			bala.global_position = spawn_pos

	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	if current_ammo <= 0:
		start_reload()

	_cooldown = 1.0 / maxf(_stat(&"fire_rate", 5.0), 0.1)
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


func _fire_laser(dano: int, empuje: float) -> void:
	var from_pos := muzzle.global_position
	var to_pos := from_pos + aim_direction * 1400.0

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
				target_player.apply_knockback(aim_direction, empuje)

	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.25, 0.9, 1.0, 0.95)
	line.add_point(from_pos)
	line.add_point(hit_pos)
	get_tree().current_scene.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)
