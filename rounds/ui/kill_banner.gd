extends CanvasLayer

signal terminado

@onready var _centro: CenterContainer = $Centro
@onready var _panel: PanelContainer = $Centro/Marco
@onready var _texto_titulo: Label = $Centro/Marco/Margin/VBox/TextoTitulo
@onready var _texto_detalle: Label = $Centro/Marco/Margin/VBox/TextoDetalle


func _asegurar_nodos() -> void:
	if _centro == null:
		_centro = $Centro
		_panel = $Centro/Marco
		_texto_titulo = $Centro/Marco/Margin/VBox/TextoTitulo
		_texto_detalle = $Centro/Marco/Margin/VBox/TextoDetalle


func _ready() -> void:
	_asegurar_nodos()
	visible = false


func mostrar_baja(victima_num: int, vidas_restantes: int) -> void:
	_asegurar_nodos()
	var nombre_victima: String = RunManager.nombre_jugador(victima_num)
	var color_victima: Color = RunManager.color_jugador(victima_num)

	_texto_titulo.text = "¡BAJA!"
	_texto_titulo.modulate = color_victima

	var texto_vidas := "%d vida restante" % vidas_restantes if vidas_restantes == 1 else "%d vidas restantes" % vidas_restantes
	_texto_detalle.text = "%s • %s" % [nombre_victima, texto_vidas]

	visible = true
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.7, 0.7)
	_centro.modulate.a = 0.0

	AudioManager.reproducir("golpe", 0.08)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_centro, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2(1.08, 1.08), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished
	var tween_settle := create_tween()
	tween_settle.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.10)
	await tween_settle.finished

	await get_tree().create_timer(0.45).timeout

	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(_centro, "modulate:a", 0.0, 0.18)
	tween_out.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.18)
	await tween_out.finished

	visible = false
	terminado.emit()
