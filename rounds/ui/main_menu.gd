extends Control

const NIVEL := "res://levels/test_level.tscn"
const ESCENA_PERSONAJES := "res://ui/character_select.tscn"
const OPCIONES_RONDAS := [1, 2, 3, 5, 7]
const OPCIONES_VIDAS := [1, 2, 3, 4, 5]

@onready var _menu: VBoxContainer = $Centro/Menu
@onready var _controles: ColorRect = $Controles
@onready var _opciones: CanvasLayer = $OptionsScreen
@onready var _indice: CanvasLayer = $UpgradeIndexScreen
@onready var _modal_nombres: ColorRect = $ModalNombres
@onready var _input_p1: LineEdit = $ModalNombres/Centro/Marco/Margin/VBox/Campos/CampoP1/InputP1
@onready var _input_p2: LineEdit = $ModalNombres/Centro/Marco/Margin/VBox/Campos/CampoP2/InputP2
@onready var _boton_iniciar: Button = $ModalNombres/Centro/Marco/Margin/VBox/Botones/Comenzar
@onready var _boton_volver_nombres: Button = $ModalNombres/Centro/Marco/Margin/VBox/Botones/Volver
@onready var _rondas: OptionButton = $Centro/Menu/Config/Rondas/Valor
@onready var _vidas: OptionButton = $Centro/Menu/Config/Vidas/Valor
@onready var _boton_jugar: Button = $Centro/Menu/Jugar
@onready var _boton_indice: Button = $Centro/Menu/Indice
@onready var _boton_controles: Button = $Centro/Menu/Controles
@onready var _boton_opciones: Button = $Centro/Menu/Opciones
@onready var _boton_salir: Button = $Centro/Menu/Salir
@onready var _boton_volver: Button = $Controles/Centro/Marco/Margin/VBox/Volver


func _ready() -> void:
	get_tree().paused = false
	AudioManager.reproducir_musica("menu")
	_controles.visible = false
	_modal_nombres.visible = false
	_poblar(_rondas, OPCIONES_RONDAS, RunManager.rondas_para_ganar)
	_poblar(_vidas, OPCIONES_VIDAS, RunManager.vidas_por_ronda)

	_boton_jugar.pressed.connect(_mostrar_modal_nombres)
	_boton_iniciar.pressed.connect(_iniciar_partida)
	_boton_volver_nombres.pressed.connect(_ocultar_modal_nombres)
	_input_p1.text_submitted.connect(func(_t: String) -> void: _input_p2.grab_focus())
	_input_p2.text_submitted.connect(func(_t: String) -> void: _iniciar_partida())

	_boton_indice.pressed.connect(_mostrar_indice)
	_indice.cerrado.connect(_ocultar_indice)

	_boton_controles.pressed.connect(_mostrar_controles)
	_boton_opciones.pressed.connect(_mostrar_opciones)
	_boton_salir.pressed.connect(_salir)
	_boton_volver.pressed.connect(_ocultar_controles)
	_opciones.cerrado.connect(_ocultar_opciones)

	_menu.visible = true
	_boton_jugar.grab_focus()


func _mostrar_modal_nombres() -> void:
	_input_p1.text = RunManager.nombre_jugador(1)
	_input_p2.text = RunManager.nombre_jugador(2)
	_menu.visible = false
	_modal_nombres.visible = true
	_input_p1.grab_focus()
	_input_p1.select_all()


func _ocultar_modal_nombres() -> void:
	_modal_nombres.visible = false
	_menu.visible = true
	_boton_jugar.grab_focus()


func _iniciar_partida() -> void:
	RunManager.set_nombres(_input_p1.text, _input_p2.text)
	RunManager.configurar_partida(_valor(_rondas, OPCIONES_RONDAS), _valor(_vidas, OPCIONES_VIDAS))
	RunManager.reiniciar()
	Transition.cambiar_escena(ESCENA_PERSONAJES)


func _mostrar_indice() -> void:
	_menu.visible = false
	_indice.abrir()


func _ocultar_indice() -> void:
	_menu.visible = true
	_boton_indice.grab_focus()


func _mostrar_controles() -> void:
	_menu.visible = false
	_controles.visible = true
	_boton_volver.grab_focus()


func _ocultar_controles() -> void:
	_controles.visible = false
	_menu.visible = true
	_boton_controles.grab_focus()


func _mostrar_opciones() -> void:
	_menu.visible = false
	_opciones.abrir()


func _ocultar_opciones() -> void:
	_menu.visible = true
	_boton_opciones.grab_focus()


func _salir() -> void:
	get_tree().quit()


func _poblar(boton: OptionButton, valores: Array, actual: int) -> void:
	boton.clear()
	for valor in valores:
		boton.add_item(str(valor))
	var indice: int = valores.find(actual)
	boton.selected = indice if indice >= 0 else 0


func _valor(boton: OptionButton, valores: Array) -> int:
	return int(valores[boton.selected])
