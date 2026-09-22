class_name WeaponComponent
extends Node2D

signal fired
signal ammo_changed(current: int, maximum: int)
signal reload_started
signal reload_completed

@export var bullet_scene: PackedScene

@onready var muzzle: Marker2D = $Muzzle
@onready var _muzzle_flash: Polygon2D = $Muzzle/MuzzleFlash
@onready var _muzzle_flash_timer: Timer = $Muzzle/MuzzleFlashTimer

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
	_muzzle_flash_timer.timeout.connect(_on_muzzle_flash_timeout)


func _on_muzzle_flash_timeout() -> void:
	_muzzle_flash.visible = false


func _flash_muzzle() -> void:
	_muzzle_flash.visible = true
	_muzzle_flash_timer.start()


func configurar(stats: StatSheet, player: Node, effects: Array) -> void:
	_stats = stats
	_player = player
	_effects = effects
	max_ammo = maxi(_stat_entero(&"max_ammo", 3), 1)
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
	if _player != null and _player.has_method("get_damage_multiplier"):
		dano = int(round(float(dano) * _player.get_damage_multiplier()))
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

	if _has_melee_strike():
		_fire_melee_strike(is_roulette)
	elif _has_laser_sight():
		var rebotes := _stat_entero(&"bounces", 0)
		var penetracion_pared := _stat_entero(&"wall_pierce", 0)
		var s := Shot.new()
		s.direction = aim_direction
		s.damage = dano
		s.speed = velocidad
		s.lifetime = duracion
		s.knockback = empuje
		s.pierce = penetracion
		s.wall_pierce = penetracion_pared
		s.bounces = rebotes
		s.gravity = gravedad
		s.drag = rozamiento
		for efecto in _effects:
			efecto.on_fire(s, _player)
		_fire_laser(s, is_roulette)
	else:
		var rebotes := _stat_entero(&"bounces", 0)
		var penetracion_pared := _stat_entero(&"wall_pierce", 0)
		var escala_bala := _stat(&"bullet_scale", 1.0)
		# Plantilla única por disparo: los efectos on_fire se aplican una sola vez
		# y cada proyectil recibe una copia (evita repetir retrocesos como Propulsión).
		var plantilla := Shot.new()
		plantilla.direction = aim_direction
		plantilla.damage = dano
		plantilla.speed = velocidad
		plantilla.lifetime = duracion
		plantilla.knockback = empuje
		plantilla.pierce = penetracion
		plantilla.wall_pierce = penetracion_pared
		plantilla.bounces = rebotes
		plantilla.gravity = gravedad
		plantilla.drag = rozamiento
		for efecto in _effects:
			efecto.on_fire(plantilla, _player)

		for i in cantidad:
			var angulo := base_angle + deg_to_rad(dispersion * (i - centro))
			var s := plantilla.copy()
			s.direction = Vector2.RIGHT.rotated(angulo)

			var bala := bullet_scene.instantiate()
			bala.direction = s.direction
			bala.shooter = _player
			bala.player = _player
			bala.damage = s.damage
			bala.speed = s.speed
			bala.lifetime = s.lifetime
			bala.pierce = s.pierce
			bala.knockback = s.knockback
			bala.bullet_gravity = s.gravity
			bala.drag = s.drag
			bala.bounces = s.bounces
			bala.wall_pierce = s.wall_pierce
			bala.can_split = s.can_split
			bala.is_glitch = s.is_glitch
			bala.magnetic_aura = s.magnetic_aura
			bala.stun_duration = s.stun_duration
			bala.ricochet_bonus = s.ricochet_bonus
			if is_quick:
				bala.modulate = Color(1.3, 1.2, 0.4, 1.0)
			if is_roulette:
				escala_bala *= 1.3
				bala.modulate = Color(1.8, 0.2, 0.2, 1.0)
			if escala_bala != 1.0:
				bala.scale = Vector2(escala_bala, escala_bala)
			bala.effects = _effects.duplicate(true)
			bala.shot = s
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
	_flash_muzzle()
	CombatCamera.shake_viewport(self, 1.2, 0.12)
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


func _fire_laser(shot: Shot, is_roulette: bool = false) -> void:
	var color := Color(1.0, 0.2, 0.2, 0.98) if is_roulette else Color(0.25, 0.9, 1.0, 0.95)
	var width := 6.0 if is_roulette else 4.0
	_fire_single_laser(shot, aim_direction, color, width)

	if shot.is_glitch:
		var clone_dmg := maxi(int(round(shot.damage * 0.50)), 1)
		var clone_kb := shot.knockback * 0.5
		var glitch_left := shot.copy()
		glitch_left.damage = clone_dmg
		glitch_left.knockback = clone_kb
		_fire_single_laser(glitch_left, aim_direction.rotated(deg_to_rad(-16.0)), Color(0.2, 1.8, 1.8, 0.95), 3.0)
		var glitch_right := shot.copy()
		glitch_right.damage = clone_dmg
		glitch_right.knockback = clone_kb
		_fire_single_laser(glitch_right, aim_direction.rotated(deg_to_rad(16.0)), Color(1.8, 0.2, 1.6, 0.95), 3.0)

	if shot.can_split:
		var split_dmg := maxi(int(round(shot.damage * 0.30)), 1)
		var split_kb := shot.knockback * 0.5
		var split_left := shot.copy()
		split_left.damage = split_dmg
		split_left.knockback = split_kb
		_fire_single_laser(split_left, aim_direction.rotated(deg_to_rad(-18.0)), color, width)
		var split_right := shot.copy()
		split_right.damage = split_dmg
		split_right.knockback = split_kb
		_fire_single_laser(split_right, aim_direction.rotated(deg_to_rad(18.0)), color, width)


func _fire_single_laser(shot: Shot, dir: Vector2, color: Color, width: float) -> void:
	var s := shot.copy()
	var from_pos := muzzle.global_position
	var cur_dir := dir
	var points := PackedVector2Array()
	points.append(from_pos)

	var space := get_world_2d().direct_space_state
	var max_segments := s.bounces + 1
	for _i in max_segments:
		var to_pos := from_pos + cur_dir * 1400.0
		var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
		query.collision_mask = 5  # Hurtbox (4) and solid world (1)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		if _player != null:
			query.exclude = [_player]

		var result := space.intersect_ray(query)
		if result.is_empty():
			points.append(to_pos)
			break

		var hit_pos: Vector2 = result["position"]
		var hit_norm: Vector2 = result["normal"]
		var collider: Node = result.get("collider") as Node
		if collider != null:
			s.hit_position = hit_pos
			s.hit_normal = hit_norm
			s.direction = cur_dir
			if collider.has_method("take_hit"):
				collider.take_hit(s.damage, _player)
			var target_player: Node = collider.get_parent()
			if target_player != null and target_player.has_method("apply_knockback") and s.knockback > 0.0:
				target_player.apply_knockback(cur_dir, s.knockback)
			for ef in _effects:
				if collider is Area2D and ef.has_method("on_hit"):
					ef.on_hit(s, collider, _player)
				elif ef.has_method("on_body_hit"):
					ef.on_body_hit(s, collider, _player)

		points.append(hit_pos)

		if collider is Area2D:
			break
		if s.bounces > 0:
			s.bounces -= 1
			cur_dir = cur_dir.bounce(hit_norm)
			from_pos = hit_pos + hit_norm * 0.5
		else:
			break

	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.points = points
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


func _has_melee_strike() -> bool:
	for ef in _effects:
		if ef.get("is_melee") == true:
			return true
	return false


func _fire_melee_strike(is_roulette: bool = false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return

	var max_hp: float = 100.0
	if _player != null and "_health" in _player and _player._health != null:
		max_hp = float(_player._health.max_health)

	var pct: float = 0.35
	for ef in _effects:
		if ef.get("is_melee") == true and "damage_pct_of_max_health" in ef:
			pct = float(ef.damage_pct_of_max_health)

	var dano: int = maxi(int(round(max_hp * pct)), 12)
	if _player != null and _player.has_method("get_damage_multiplier"):
		dano = int(round(float(dano) * _player.get_damage_multiplier()))
	if is_roulette:
		dano *= 4

	var empuje: float = 520.0 + _stat(&"knockback", 0.0)
	var from_pos: Vector2 = muzzle.global_position
	var range_dist: float = 65.0

	var s := Shot.new()
	s.direction = aim_direction
	s.damage = dano
	s.knockback = empuje
	s.hit_position = from_pos + aim_direction * (range_dist * 0.5)

	for efecto in _effects:
		efecto.on_fire(s, _player)

	# Efecto visual: Arco de impacto melee frontal
	var slash := Line2D.new()
	slash.width = 8.0 if is_roulette else 5.5
	slash.default_color = Color(1.8, 0.4, 0.2, 1.0) if is_roulette else Color(1.0, 0.85, 0.25, 0.95)
	var pts := PackedVector2Array()
	var base_ang := aim_direction.angle()
	for a in 11:
		var offset_ang := deg_to_rad(-55.0 + float(a) * 11.0)
		pts.append(from_pos + Vector2.RIGHT.rotated(base_ang + offset_ang) * range_dist)
	slash.points = pts
	tree.current_scene.add_child(slash)
	var tw := slash.create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.16)
	tw.tween_callback(slash.queue_free)

	# Detección de impacto contra rivales
	var hit_any: bool = false
	for p in tree.get_nodes_in_group("player"):
		if p != null and is_instance_valid(p) and p != _player and p is Node2D:
			var p2d := p as Node2D
			var diff := p2d.global_position - from_pos
			var dist := diff.length()
			if dist <= range_dist + 16.0:
				var angle_diff := absf(aim_direction.angle_to(diff))
				if angle_diff < deg_to_rad(65.0) or dist < 28.0:
					hit_any = true
					if p.has_method("hurt"):
						p.hurt(dano, _player)
					if p.has_method("apply_knockback"):
						p.apply_knockback(aim_direction, empuje)
					for efecto in _effects:
						if efecto.has_method("on_hit"):
							efecto.on_hit(s, p, _player)

	if hit_any:
		CombatCamera.shake_viewport(self, 4.5, 0.18)
		AudioManager.reproducir("golpe", 0.16)
	else:
		AudioManager.reproducir("disparo", 0.08)
