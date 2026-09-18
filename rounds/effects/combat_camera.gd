class_name CombatCamera
extends Camera2D

var _rng := RandomNumberGenerator.new()
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if _shake_duration <= 0.0:
		return
	_shake_time += delta
	if _shake_time >= _shake_duration:
		_reset_shake()
		return
	var falloff := 1.0 - (_shake_time / _shake_duration)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf() * _shake_intensity * falloff
	offset = Vector2.RIGHT.rotated(angle) * radius


func shake(intensidad: float, duracion: float = 0.25) -> void:
	_shake_intensity = intensidad
	_shake_duration = maxf(duracion, 0.0)
	_shake_time = 0.0


func _reset_shake() -> void:
	_shake_time = 0.0
	_shake_duration = 0.0
	_shake_intensity = 0.0
	offset = Vector2.ZERO


static func shake_viewport(from: Node, intensidad: float, duracion: float = 0.25) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var camera := from.get_viewport().get_camera_2d()
	if camera is CombatCamera:
		camera.shake(intensidad, duracion)
