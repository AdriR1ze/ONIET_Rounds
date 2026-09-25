extends Control

const NIVEL := "res://levels/test_level.tscn"
const ESCENA_PERSONAJES := "res://ui/character_select.tscn"
const ESCENA_TUTORIAL := "res://levels/tutorial_level.tscn"
const OPCIONES_JUGADORES := [2, 3, 4]

@onready var _menu: VBoxContainer = $Centro/Menu
@onready var _opciones: CanvasLayer = $OptionsScreen
@onready var _indice: CanvasLayer = $UpgradeIndexScreen
@onready var _modal_partida: ColorRect = $ModalPartida
@onready var _campos: VBoxContainer = $ModalPartida/Centro/Marco/Margin/VBox/Campos
@onready var _boton_iniciar: Button = $ModalPartida/Centro/Marco/Margin/VBox/Botones/Comenzar
@onready var _boton_volver_partida: Button = $ModalPartida/Centro/Marco/Margin/VBox/Botones/Volver
@onready var _jugadores: OptionButton = $ModalPartida/Centro/Marco/Margin/VBox/Config/Jugadores/Valor
@onready var _rondas: Button = $ModalPartida/Centro/Marco/Margin/VBox/Config/Rondas/Valor
@onready var _vidas: Button = $ModalPartida/Centro/Marco/Margin/VBox/Config/Vidas/Valor
@onready var _dificultad_bot: OptionButton = $ModalPartida/Centro/Marco/Margin/VBox/Config/DificultadBot/Valor
@onready var _boton_jugar: Button = $Centro/Menu/Jugar
@onready var _boton_tutorial: Button = $Centro/Menu/Tutorial
@onready var _boton_indice: Button = $Centro/Menu/Indice
@onready var _boton_opciones: Button = $Centro/Menu/Opciones
@onready var _boton_salir: Button = $Centro/Menu/Salir

var _inputs: Array[LineEdit] = []
var _tweens_botones: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	_modal_partida.visible = false
	_poblar(_jugadores, OPCIONES_JUGADORES, RunManager.cantidad_jugadores)
	_rondas.value = RunManager.rondas_para_ganar
	_vidas.value = RunManager.vidas_por_ronda
	_poblar_dificultad_bot()

	_jugadores.item_selected.connect(_on_jugadores_changed)
	_boton_jugar.pressed.connect(_abrir_seleccion_personajes)
	_boton_tutorial.pressed.connect(_abrir_tutorial)
	_boton_iniciar.pressed.connect(_iniciar_partida)
	_boton_volver_partida.pressed.connect(_ocultar_modal_partida)

	_boton_indice.pressed.connect(_mostrar_indice)
	_indice.cerrado.connect(_ocultar_indice)

	_boton_opciones.pressed.connect(_mostrar_opciones)
	_boton_salir.pressed.connect(_salir)
	_opciones.cerrado.connect(_ocultar_opciones)

	_configurar_efectos_botones()

	_menu.visible = true
	_boton_jugar.grab_focus()


func _poblar_dificultad_bot() -> void:
	_dificultad_bot.clear()
	for i in RunManager.DIFICULTADES_BOT.size():
		_dificultad_bot.add_item(RunManager.DIFICULTADES_BOT[i], i)
	_dificultad_bot.selected = RunManager.dificultad_bot


func _abrir_seleccion_personajes() -> void:
	Transition.cambiar_escena(ESCENA_PERSONAJES)


func _mostrar_modal_partida() -> void:
	var cantidad: int = _valor(_jugadores, OPCIONES_JUGADORES)
	RunManager.set_cantidad_jugadores(cantidad)
	_construir_campos(cantidad)
	_menu.visible = false
	_modal_partida.visible = true
	_jugadores.grab_focus()


func _on_jugadores_changed(_indice: int) -> void:
	var cantidad: int = _valor(_jugadores, OPCIONES_JUGADORES)
	RunManager.set_cantidad_jugadores(cantidad)
	_construir_campos(cantidad)


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


func _ocultar_modal_partida() -> void:
	_modal_partida.visible = false
	_menu.visible = true
	_boton_jugar.grab_focus()


func _iniciar_partida() -> void:
	var nombres: Array = []
	for entrada in _inputs:
		nombres.append(entrada.text)
	RunManager.set_nombres(nombres)
	RunManager.configurar_partida(int(_rondas.value), int(_vidas.value), _dificultad_bot.selected)
	RunManager.reiniciar()
	Transition.cambiar_escena(ESCENA_PERSONAJES)


func _mostrar_indice() -> void:
	_menu.visible = false
	_indice.abrir()


func _ocultar_indice() -> void:
	_menu.visible = true
	_boton_indice.grab_focus()


func _mostrar_opciones() -> void:
	_menu.visible = false
	_opciones.abrir()


func _ocultar_opciones() -> void:
	_menu.visible = true
	_boton_opciones.grab_focus()


func _abrir_tutorial() -> void:
	Transition.cambiar_escena(ESCENA_TUTORIAL)


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


func _configurar_efectos_botones() -> void:
	var botones: Array[Button] = [
		_boton_jugar,
		_boton_tutorial,
		_boton_indice,
		_boton_opciones,
		_boton_salir
	]
	for btn in botones:
		btn.pivot_offset = btn.custom_minimum_size * 0.5
		btn.focus_entered.connect(_on_boton_focus.bind(btn, true))
		btn.focus_exited.connect(_on_boton_focus.bind(btn, false))
		btn.mouse_entered.connect(_on_boton_mouse.bind(btn))
		btn.mouse_exited.connect(_on_boton_mouse_exit.bind(btn))


func _on_boton_focus(btn: Button, enfocado: bool) -> void:
	_animar_boton(btn, enfocado)
	if enfocado and is_inside_tree():
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").reproducir("ui_mover", 0.05)


func _on_boton_mouse(btn: Button) -> void:
	btn.grab_focus()


func _on_boton_mouse_exit(btn: Button) -> void:
	if not btn.has_focus():
		_animar_boton(btn, false)


func _animar_boton(btn: Button, activo: bool) -> void:
	btn.z_index = 2 if activo else 0
	if _tweens_botones.has(btn) and is_instance_valid(_tweens_botones[btn]):
		_tweens_botones[btn].kill()
	var tween := create_tween()
	_tweens_botones[btn] = tween
	var escala_meta := Vector2(1.1, 1.1) if activo else Vector2.ONE
	tween.tween_property(btn, "scale", escala_meta, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
