class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node)
signal died

@export var max_health: int = 100

var health: int = 0


func _ready() -> void:
	reset()


func apply_damage(amount: int, source: Node = null) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	damaged.emit(amount, source)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func apply_silent_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	if health <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func reset() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func is_alive() -> bool:
	return health > 0
