extends CanvasLayer

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0, 0, 0, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func fade_out(duracion: float = 0.25) -> void:
	if _rect == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.visible = true
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 1.0, duracion)
	await _tween.finished
	_rect.visible = true


func fade_in(duracion: float = 0.25) -> void:
	if _rect == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 0.0, duracion)
	await _tween.finished
	_rect.visible = false


func cambiar_escena(ruta: String, duracion: float = 0.25) -> void:
	await fade_out(duracion)
	get_tree().change_scene_to_file(ruta)
	await fade_in(duracion)


func recargar(duracion: float = 0.25) -> void:
	await fade_out(duracion)
	get_tree().reload_current_scene()
	await fade_in(duracion)
