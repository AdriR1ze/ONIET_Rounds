extends CanvasLayer

const MENU_PRINCIPAL := "res://ui/main_menu.tscn"

@onready var _boton_reanudar: Button = $Centro/Menu/Reanudar
@onready var _boton_reiniciar: Button = $Centro/Menu/Reiniciar
@onready var _boton_menu: Button = $Centro/Menu/MenuPrincipal
@onready var _boton_salir: Button = $Centro/Menu/Salir

var _activo := false


func _ready() -> void:
	visible = false
	_boton_reanudar.pressed.connect(reanudar)
	_boton_reiniciar.pressed.connect(_reiniciar)
	_boton_menu.pressed.connect(_ir_al_menu)
	_boton_salir.pressed.connect(_salir)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _activo:
			reanudar()
		else:
			pausar()
		get_viewport().set_input_as_handled()


func pausar() -> void:
	if _activo:
		return
	_activo = true
	visible = true
	get_tree().paused = true
	_boton_reanudar.grab_focus()


func reanudar() -> void:
	if not _activo:
		return
	_activo = false
	visible = false
	get_tree().paused = false


func _reiniciar() -> void:
	get_tree().paused = false
	RunManager.reiniciar()
	get_tree().reload_current_scene()


func _ir_al_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_PRINCIPAL)


func _salir() -> void:
	get_tree().quit()
