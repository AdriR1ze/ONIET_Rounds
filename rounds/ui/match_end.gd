extends CanvasLayer

const MENU_PRINCIPAL := "res://ui/main_menu.tscn"

@onready var _titulo: Label = $Centro/Menu/Titulo
@onready var _marcador: Label = $Centro/Menu/Marcador
@onready var _boton_revancha: Button = $Centro/Menu/Revancha
@onready var _boton_menu: Button = $Centro/Menu/MenuPrincipal


func _ready() -> void:
	visible = false
	_boton_revancha.pressed.connect(_revancha)
	_boton_menu.pressed.connect(_ir_al_menu)


func mostrar(ganador: int) -> void:
	_titulo.text = "¡Ganó %s!" % RunManager.nombre_jugador(ganador)
	var n1 := RunManager.nombre_jugador(1)
	var n2 := RunManager.nombre_jugador(2)
	_marcador.text = "%s  %d  -  %d  %s" % [n1, RunManager.marcador_de(1), RunManager.marcador_de(2), n2]
	visible = true
	PauseManager.tomar(self)
	_boton_revancha.grab_focus()


func _revancha() -> void:
	PauseManager.soltar(self)
	RunManager.reiniciar()
	Transition.recargar()


func _ir_al_menu() -> void:
	PauseManager.soltar(self)
	Transition.cambiar_escena(MENU_PRINCIPAL)
