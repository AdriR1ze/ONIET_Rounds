class_name WeaponComponent
extends Node2D

signal fired

@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.2

@onready var muzzle: Marker2D = $Muzzle

var aim_direction: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0


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
	var bullet := bullet_scene.instantiate()
	bullet.direction = aim_direction
	bullet.shooter = get_parent()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	_cooldown = fire_cooldown
	fired.emit()
	return true
