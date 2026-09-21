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
	_titulo.modulate = RunManager.color_jugador(ganador)
	var partes := PackedStringArray()
	for i in RunManager.cantidad_jugadores:
		var numero := i + 1
		partes.append("%s %d" % [RunManager.nombre_jugador(numero), RunManager.marcador_de(numero)])
	_marcador.text = "    ".join(partes)
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
