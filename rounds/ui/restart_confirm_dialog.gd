extends CanvasLayer

signal confirmado
signal cancelado

@onready var _boton_reiniciar: Button = $Centro/Marco/Margin/VBox/Botones/Reiniciar
@onready var _boton_cancelar: Button = $Centro/Marco/Margin/VBox/Botones/Cancelar

var _activo := false


func _ready() -> void:
	visible = false
	_boton_reiniciar.pressed.connect(_al_confirmar)
	_boton_cancelar.pressed.connect(cerrar)


func _unhandled_input(event: InputEvent) -> void:
	if not _activo:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		cerrar()
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()


func abrir() -> void:
	if _activo or PauseManager.bloqueado(self):
		return
	_activo = true
	visible = true
	PauseManager.tomar(self)
	_boton_cancelar.grab_focus()


func cerrar() -> void:
	if not _activo:
		return
	_activo = false
	visible = false
	PauseManager.soltar(self)
	cancelado.emit()


func _al_confirmar() -> void:
	if not _activo:
		return
	_activo = false
	visible = false
	PauseManager.soltar(self)
	confirmado.emit()
	RunManager.reiniciar()
	Transition.recargar()
