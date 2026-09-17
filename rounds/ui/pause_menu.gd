extends CanvasLayer

const MENU_PRINCIPAL := "res://ui/main_menu.tscn"

@onready var _boton_reanudar: Button = $Centro/Menu/Reanudar
@onready var _boton_reiniciar: Button = $Centro/Menu/Reiniciar
@onready var _boton_opciones: Button = $Centro/Menu/Opciones
@onready var _boton_menu: Button = $Centro/Menu/MenuPrincipal
@onready var _boton_salir: Button = $Centro/Menu/Salir
@onready var _opciones: CanvasLayer = $OptionsScreen

var _activo := false


func _ready() -> void:
	visible = false
	_boton_reanudar.pressed.connect(reanudar)
	_boton_reiniciar.pressed.connect(_reiniciar)
	_boton_opciones.pressed.connect(_mostrar_opciones)
	_boton_menu.pressed.connect(_ir_al_menu)
	_boton_salir.pressed.connect(_salir)
	_opciones.cerrado.connect(_ocultar_opciones)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _opciones.visible:
		return
	if _activo:
		reanudar()
	else:
		pausar()


func pausar() -> void:
	if _activo or PauseManager.bloqueado(self):
		return
	_activo = true
	visible = true
	PauseManager.tomar(self)
	_boton_reanudar.grab_focus()


func reanudar() -> void:
	if not _activo:
		return
	_activo = false
	visible = false
	PauseManager.soltar(self)


func _reiniciar() -> void:
	_activo = false
	visible = false
	PauseManager.soltar(self)
	RunManager.reiniciar()
	get_tree().reload_current_scene()


func _ir_al_menu() -> void:
	_activo = false
	visible = false
	PauseManager.soltar(self)
	get_tree().change_scene_to_file(MENU_PRINCIPAL)


func _salir() -> void:
	PauseManager.soltar(self)
	get_tree().quit()


func _mostrar_opciones() -> void:
	_opciones.abrir()


func _ocultar_opciones() -> void:
	_boton_opciones.grab_focus()
