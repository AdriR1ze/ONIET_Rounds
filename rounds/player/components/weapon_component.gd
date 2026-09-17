class_name WeaponComponent
extends Node2D

signal fired

@export var bullet_scene: PackedScene

@onready var muzzle: Marker2D = $Muzzle

var aim_direction: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0
var _stats: StatSheet = null
var _player: Node = null
var _effects: Array = []


func configurar(stats: StatSheet, player: Node, effects: Array) -> void:
	_stats = stats
	_player = player
	_effects = effects


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func set_aim(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	aim_direction = direction.normalized()
	rotation = aim_direction.angle()


func can_fire() -> bool:
	return _cooldown <= 0.0 and bullet_scene != null


func try_fire() -> bool:
	if not can_fire():
		return false

	var cantidad := _stat_entero(&"projectiles", 1)
	var dispersion: float = _stat(&"spread", 0.0)
	var dano := _stat_entero(&"damage", 1)
	var velocidad: float = _stat(&"bullet_speed", 900.0)
	var duracion: float = _stat(&"bullet_lifetime", 2.0)
	var penetracion := _stat_entero(&"pierce", 0)
	var empuje: float = _stat(&"knockback", 0.0)

	var base_angle := aim_direction.angle()
	var centro := (cantidad - 1) / 2.0
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
		bala.effects = _effects
		for efecto in _effects:
			efecto.on_fire(bala, _player)
		get_tree().current_scene.add_child(bala)
		bala.global_position = muzzle.global_position

	_cooldown = 1.0 / maxf(_stat(&"fire_rate", 5.0), 0.1)
	fired.emit()
	return true


func _stat(stat: StringName, por_defecto: float) -> float:
	if _stats == null:
		return por_defecto
	return _stats.get_stat(stat)


func _stat_entero(stat: StringName, por_defecto: int) -> int:
	return int(round(_stat(stat, float(por_defecto))))
