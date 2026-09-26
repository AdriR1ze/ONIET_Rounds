extends Control

const ESCENA_MENU := "res://ui/main_menu.tscn"

@onready var _texto_inicio: Label = $CentroTexto/TextoInicio
var _transicionando: bool = false


func _ready() -> void:
	_iniciar_parpadeo()


func _iniciar_parpadeo() -> void:
	if _texto_inicio == null:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_texto_inicio, "modulate:a", 0.15, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_texto_inicio, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_avanzar()


func _input(event: InputEvent) -> void:
	if _transicionando or not is_inside_tree():
		return
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			_avanzar()


func _unhandled_input(event: InputEvent) -> void:
	if _transicionando or not is_inside_tree():
		return
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			_avanzar()


func _avanzar() -> void:
	if _transicionando or not is_inside_tree():
		return
	_transicionando = true
	if has_node("/root/AudioManager"):
		var audio = get_node("/root/AudioManager")
		if audio.has_method("reproducir"):
			audio.reproducir("ui_click")
	if has_node("/root/Transition"):
		var trans = get_node("/root/Transition")
		if trans.has_method("cambiar_escena"):
			trans.cambiar_escena(ESCENA_MENU)
	elif get_tree() != null:
		get_tree().change_scene_to_file(ESCENA_MENU)

