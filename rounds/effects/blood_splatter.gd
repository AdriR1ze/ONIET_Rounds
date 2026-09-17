extends Node2D

@onready var _burst: CPUParticles2D = $Burst
@onready var _drips: CPUParticles2D = $Drips


func _ready() -> void:
	_configurar_textura()
	_burst.emitting = true
	_drips.emitting = true

	await get_tree().create_timer(1.8).timeout
	queue_free()


func _configurar_textura() -> void:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_burst.texture = tex
	_drips.texture = tex

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.9, 0.08, 0.12, 1.0),
		Color(0.7, 0.02, 0.05, 0.95),
		Color(0.45, 0.01, 0.03, 0.7),
		Color(0.3, 0.0, 0.01, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	_burst.color_ramp = grad
	_drips.color_ramp = grad
