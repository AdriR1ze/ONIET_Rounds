class_name StatSheet
extends Node

signal stat_changed(stat: StringName, value: float)

const BASE_STATS := {
	&"move_speed": 230.0,
	&"jump_velocity": -830.0,
	&"max_health": 3.0,
	&"fire_rate": 5.0,
	&"damage": 1.0,
	&"bullet_speed": 900.0,
	&"bullet_lifetime": 2.0,
	&"projectiles": 1.0,
	&"spread": 0.0,
	&"pierce": 0.0,
	&"knockback": 0.0,
}

var _base: Dictionary = BASE_STATS.duplicate()
var _flat: Dictionary = {}
var _mult: Dictionary = {}


func get_stat(stat: StringName) -> float:
	var base: float = _base.get(stat, 0.0)
	return (base + _flat.get(stat, 0.0)) * _mult.get(stat, 1.0)


func get_entero(stat: StringName) -> int:
	return int(round(get_stat(stat)))


func limpiar() -> void:
	_flat.clear()
	_mult.clear()


func agregar_modificador(mod: StatModifier) -> void:
	if mod == null:
		return
	if mod.op == StatModifier.Op.MULT:
		_mult[mod.stat] = _mult.get(mod.stat, 1.0) * mod.value
	else:
		_flat[mod.stat] = _flat.get(mod.stat, 0.0) + mod.value
	stat_changed.emit(mod.stat, get_stat(mod.stat))
