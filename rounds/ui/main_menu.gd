extends Control

const NIVEL := "res://levels/test_level.tscn"
const ESCENA_PERSONAJES := "res://ui/character_select.tscn"
const OPCIONES_JUGADORES := [2, 3, 4]
const OPCIONES_RONDAS := [1, 2, 3, 5, 7]
const OPCIONES_VIDAS := [1, 2, 3, 4, 5]

@onready var _menu: VBoxContainer = $Centro/Menu
@onready var _controles: ColorRect = $Controles
@onready var _opciones: CanvasLayer = $OptionsScreen
@onready var _indice: CanvasLayer = $UpgradeIndexScreen
@onready var _modal_nombres: ColorRect = $ModalNombres
@onready var _campos: VBoxContainer = $ModalNombres/Centro/Marco/Margin/VBox/Campos
@onready var _boton_iniciar: Button = $ModalNombres/Centro/Marco/Margin/VBox/Botones/Comenzar
@onready var _boton_volver_nombres: Button = $ModalNombres/Centro/Marco/Margin/VBox/Botones/Volver
@onready var _jugadores: OptionButton = $Centro/Menu/Config/Jugadores/Valor
@onready var _rondas: OptionButton = $Centro/Menu/Config/Rondas/Valor
@onready var _vidas: OptionButton = $Centro/Menu/Config/Vidas/Valor
@onready var _boton_jugar: Button = $Centro/Menu/Jugar
@onready var _boton_indice: Button = $Centro/Menu/Indice
@onready var _boton_controles: Button = $Centro/Menu/Controles
@onready var _boton_opciones: Button = $Centro/Menu/Opciones
@onready var _boton_salir: Button = $Centro/Menu/Salir
@onready var _boton_volver: Button = $Controles/Centro/Marco/Margin/VBox/Volver

var _inputs: Array[LineEdit] = []


func _ready() -> void:
	get_tree().paused = false
	AudioManager.reproducir_musica("menu")
	_controles.visible = false
	_modal_nombres.visible = false
	_poblar(_jugadores, OPCIONES_JUGADORES, RunManager.cantidad_jugadores)
	_poblar(_rondas, OPCIONES_RONDAS, RunManager.rondas_para_ganar)
	_poblar(_vidas, OPCIONES_VIDAS, RunManager.vidas_por_ronda)

	_boton_jugar.pressed.connect(_mostrar_modal_nombres)
	_boton_iniciar.pressed.connect(_iniciar_partida)
	_boton_volver_nombres.pressed.connect(_ocultar_modal_nombres)

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
	var cantidad: int = _valor(_jugadores, OPCIONES_JUGADORES)
	RunManager.set_cantidad_jugadores(cantidad)
	_construir_campos(cantidad)
	_menu.visible = false
	_modal_nombres.visible = true
	if not _inputs.is_empty():
		_inputs[0].grab_focus()
		_inputs[0].select_all()


func _construir_campos(cantidad: int) -> void:
	for hijo in _campos.get_children():
		_campos.remove_child(hijo)
		hijo.queue_free()
	_inputs.clear()
	for i in cantidad:
		var numero := i + 1
		var campo := VBoxContainer.new()
		campo.add_theme_constant_override("separation", 4)
		var etiqueta := Label.new()
		etiqueta.text = "Jugador %d:" % numero
		etiqueta.add_theme_font_size_override("font_size", 14)
		etiqueta.add_theme_color_override("font_color", RunManager.color_jugador(numero))
		var entrada := LineEdit.new()
		entrada.placeholder_text = "Jugador %d" % numero
		entrada.text = RunManager.nombre_jugador(numero)
		entrada.max_length = 20
		entrada.text_submitted.connect(_on_nombre_submitted.bind(i))
		campo.add_child(etiqueta)
		campo.add_child(entrada)
		_campos.add_child(campo)
		_inputs.append(entrada)


func _on_nombre_submitted(_texto: String, indice: int) -> void:
	if indice + 1 < _inputs.size():
		_inputs[indice + 1].grab_focus()
	else:
		_iniciar_partida()


func _ocultar_modal_nombres() -> void:
	_modal_nombres.visible = false
	_menu.visible = true
	_boton_jugar.grab_focus()


func _iniciar_partida() -> void:
	var nombres: Array = []
	for entrada in _inputs:
		nombres.append(entrada.text)
	RunManager.set_nombres(nombres)
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
