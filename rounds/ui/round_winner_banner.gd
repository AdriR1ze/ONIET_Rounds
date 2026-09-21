extends CanvasLayer

signal terminado

@onready var _panel: CenterContainer = $Centro
@onready var _texto_ganador: Label = $Centro/Marco/Margin/VBox/TextoGanador
@onready var _subtexto: Label = $Centro/Marco/Margin/VBox/Subtexto
@onready var _confeti_top: CPUParticles2D = $ConfetiTop
@onready var _confeti_burst: CPUParticles2D = $ConfetiBurst


func _ready() -> void:
	visible = false
	_configurar_particulas()


func _configurar_particulas() -> void:
	var img := Image.create(10, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_confeti_top.texture = tex
	_confeti_burst.texture = tex

	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.85, 0.2),
		Color(0.2, 0.9, 1.0),
		Color(1.0, 0.25, 0.7),
		Color(0.3, 1.0, 0.4),
		Color(1.0, 0.5, 0.1),
		Color(0.7, 0.4, 1.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	_confeti_top.color_ramp = grad
	_confeti_burst.color_ramp = grad


func mostrar_ganador(ganador: int) -> void:
	var nombre: String = RunManager.nombre_jugador(ganador)
	var color_ganador: Color = RunManager.color_jugador(ganador)

	_texto_ganador.text = "¡%s GANÓ LA RONDA!" % nombre.to_upper()
	_texto_ganador.modulate = color_ganador
	_subtexto.text = "Ronda %d completada" % RunManager.ronda

	visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.7, 0.7)
	_panel.pivot_offset = _panel.size / 2.0

	_confeti_top.restart()
	_confeti_top.emitting = true
	_confeti_burst.restart()
	_confeti_burst.emitting = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(_panel, "scale", Vector2(1.05, 1.05), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.3).timeout
	var tween_pulse := create_tween()
	tween_pulse.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.15)

	# Mantener visible por 1.4 segundos más de celebración con confetis
	await get_tree().create_timer(1.4).timeout

	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tween_out.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.3)
	await tween_out.finished

	_confeti_top.emitting = false
	_confeti_burst.emitting = false
	visible = false
	terminado.emit()
