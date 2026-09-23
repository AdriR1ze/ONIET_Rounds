extends CanvasLayer

signal terminado

@onready var _centro: CenterContainer = $Centro
@onready var _panel: PanelContainer = $Centro/Marco
@onready var _texto_ronda: Label = $Centro/Marco/Margin/VBox/TextoRonda
@onready var _texto_mapa: Label = $Centro/Marco/Margin/VBox/TextoMapa
@onready var _subtexto: Label = $Centro/Marco/Margin/VBox/Subtexto


func _asegurar_nodos() -> void:
	if _centro == null:
		_centro = $Centro
		_panel = $Centro/Marco
		_texto_ronda = $Centro/Marco/Margin/VBox/TextoRonda
		_texto_mapa = $Centro/Marco/Margin/VBox/TextoMapa
		_subtexto = $Centro/Marco/Margin/VBox/Subtexto


func _ready() -> void:
	_asegurar_nodos()
	visible = false


func mostrar_intro(ronda: int, mapa_info: Dictionary) -> void:
	_asegurar_nodos()
	var nombre_mapa: String = mapa_info.get("nombre", "ARENA")
	var tipo_mapa: String = mapa_info.get("tipo", "COMBATE")
	var color_mapa: Color = mapa_info.get("color", Color(0.2, 0.85, 1.0))

	_texto_ronda.text = "— RONDA %d —" % ronda
	_texto_mapa.text = nombre_mapa.to_upper()
	_texto_mapa.modulate = color_mapa
	_subtexto.text = tipo_mapa.to_upper()

	visible = true
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.75, 0.75)
	_centro.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_centro, "modulate:a", 1.0, 0.22)
	tween.tween_property(_panel, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished
	var tween_settle := create_tween()
	tween_settle.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.12)
	await tween_settle.finished

	await get_tree().create_timer(0.75).timeout

	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(_centro, "modulate:a", 0.0, 0.22)
	tween_out.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.22)
	await tween_out.finished

	visible = false
	terminado.emit()
