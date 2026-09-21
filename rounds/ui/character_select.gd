extends Control

const PERSONAJES: Array[String] = ["pato", "esqueleto"]
const ESCENA_JUEGO := "res://levels/test_level.tscn"
const ESCENA_MENU := "res://ui/main_menu.tscn"

const SKEL_FRAMES: SpriteFrames = preload("res://player/skeleton_frames.tres")
const SKEL_SHADER: Shader = preload("res://player/skeleton_palette.gdshader")

const COLOR_APAGADO := Color(0.2, 0.22, 0.28, 1.0)
const COLOR_LISTO := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_BEAK := Color(0.96, 0.52, 0.12, 1.0)
const COLOR_EYE := Color(0.12, 0.13, 0.18, 1.0)
const COLOR_FOOT := Color(0.92, 0.45, 0.08, 1.0)

const POLY_BODY := [-9, -15, 6, -15, 11, -12, 12, -4, 10, 2, 12, 10, 8, 15, -7, 15, -12, 11, -14, 4, -16, 1, -12, -4, -10, -11]
const POLY_WING := [-8, -1, 1, -1, 3, 4, -2, 9, -9, 6]
const POLY_BEAK := [11, -4, 19, -3, 21, 0, 19, 3, 11, 3]
const POLY_EYE := [4, -12, 8, -12, 8, -7, 4, -7]
const POLY_PUPIL := [5, -11, 7, -11, 7, -9, 5, -9]
const POLY_FOOT_L := [-5, 14, 0, 14, 3, 17, -4, 17]
const POLY_FOOT_R := [1, 14, 6, 14, 9, 17, 2, 17]

@onready var _panel_jugadores: HBoxContainer = $Margin/VBox/PanelJugadores
@onready var _btn_iniciar: Button = $Margin/VBox/Footer/BotonIniciar
@onready var _btn_volver: Button = $Margin/VBox/Footer/BotonVolver

var _numeros: Array = []
var _choice: Dictionary = {}
var _listo: Dictionary = {}
var _card_pato: Dictionary = {}
var _card_esqueleto: Dictionary = {}
var _ready_btn: Dictionary = {}
var _status_lbl: Dictionary = {}


func _ready() -> void:
	AudioManager.reproducir_musica("menu")
	_btn_iniciar.pressed.connect(_iniciar_partida)
	_btn_volver.pressed.connect(_volver_al_menu)
	_construir_paneles()
	_actualizar_ui()


func _construir_paneles() -> void:
	for hijo in _panel_jugadores.get_children():
		_panel_jugadores.remove_child(hijo)
		hijo.queue_free()
	_numeros.clear()
	for i in RunManager.cantidad_jugadores:
		_numeros.append(i + 1)
	for indice in _numeros.size():
		var numero: int = _numeros[indice]
		_choice[numero] = 0
		_listo[numero] = false
		_panel_jugadores.add_child(_crear_panel(numero))
		if indice < _numeros.size() - 1:
			_panel_jugadores.add_child(_crear_separador())


func _crear_separador() -> CenterContainer:
	var centro := CenterContainer.new()
	var etiqueta := Label.new()
	etiqueta.text = "VS"
	etiqueta.add_theme_color_override("font_color", Color(0.35, 0.38, 0.48, 1))
	etiqueta.add_theme_font_size_override("font_size", 22)
	centro.add_child(etiqueta)
	return centro


func _crear_panel(numero: int) -> VBoxContainer:
	var color := RunManager.color_jugador(numero)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	var tag := Label.new()
	tag.text = "JUGADOR %d" % numero
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", color)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nombre := Label.new()
	nombre.text = RunManager.nombre_jugador(numero)
	nombre.add_theme_font_size_override("font_size", 18)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(tag)
	header.add_child(nombre)
	panel.add_child(header)

	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 8)
	var card_pato := _crear_card_pato(numero, color)
	var card_esqueleto := _crear_card_esqueleto(numero, color)
	cards.add_child(card_pato)
	cards.add_child(card_esqueleto)
	panel.add_child(cards)
	_card_pato[numero] = card_pato
	_card_esqueleto[numero] = card_esqueleto

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 11)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	_status_lbl[numero] = status

	var boton := Button.new()
	boton.custom_minimum_size = Vector2(130, 32)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.pressed.connect(_toggle_ready.bind(numero))
	panel.add_child(boton)
	_ready_btn[numero] = boton

	return panel


func _crear_card_pato(numero: int, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(_on_card_input.bind(numero, 0))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 100)
	var visual := Node2D.new()
	visual.position = Vector2(60, 52)
	visual.scale = Vector2(1.6, 1.6)
	visual.add_child(_poly(POLY_BODY, color))
	visual.add_child(_poly(POLY_WING, color.darkened(0.2)))
	visual.add_child(_poly(POLY_BEAK, COLOR_BEAK))
	visual.add_child(_poly(POLY_EYE, COLOR_EYE))
	visual.add_child(_poly(POLY_PUPIL, Color.WHITE))
	visual.add_child(_poly(POLY_FOOT_L, COLOR_FOOT))
	visual.add_child(_poly(POLY_FOOT_R, COLOR_FOOT))
	preview.add_child(visual)
	vbox.add_child(preview)
	vbox.add_child(_texto("Pato Clásico", 15, Color.WHITE))
	vbox.add_child(_texto("El duelista emplumado original.", 11, Color(0.7, 0.72, 0.8)))
	card.add_child(vbox)
	_ignorar_raton(vbox)
	return card


func _crear_card_esqueleto(numero: int, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(_on_card_input.bind(numero, 1))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 100)
	var sprite := AnimatedSprite2D.new()
	var paleta := RunManager.paleta_esqueleto(numero)
	var mat := ShaderMaterial.new()
	mat.shader = SKEL_SHADER
	mat.set_shader_parameter("color_highlight", paleta[0])
	mat.set_shader_parameter("color_midtone", paleta[1])
	mat.set_shader_parameter("color_shadow", paleta[2])
	sprite.material = mat
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(60, 55)
	sprite.scale = Vector2(3.4, 3.4)
	sprite.sprite_frames = SKEL_FRAMES
	sprite.animation = &"walk"
	sprite.frame_progress = 0.5
	preview.add_child(sprite)
	vbox.add_child(preview)
	vbox.add_child(_texto("Esqueleto", 15, Color.WHITE))
	vbox.add_child(_texto("Ágil, huesudo e implacable.", 11, Color(0.7, 0.72, 0.8)))
	card.add_child(vbox)
	_ignorar_raton(vbox)
	return card


func _ignorar_raton(nodo: Node) -> void:
	if nodo is Control:
		(nodo as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hijo in nodo.get_children():
		_ignorar_raton(hijo)


func _poly(puntos: Array, color: Color) -> Polygon2D:
	var poli := Polygon2D.new()
	poli.polygon = PackedVector2Array(puntos)
	poli.color = color
	return poli


func _texto(contenido: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = contenido
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return etiqueta


func _estilo_card(color: Color, seleccionada: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18, 0.95) if seleccionada else Color(0.06, 0.07, 0.1, 0.8)
	sb.set_border_width_all(3 if seleccionada else 1)
	sb.border_color = color if seleccionada else COLOR_APAGADO
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


func _on_card_input(event: InputEvent, numero: int, eleccion: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _listo[numero]:
			_choice[numero] = eleccion
			_actualizar_ui()


func _unhandled_input(event: InputEvent) -> void:
	for numero in _numeros:
		if _usa_raw_keyboard(numero):
			continue
		if not _listo[numero]:
			if event.is_action_pressed("p%d_left" % numero):
				_choice[numero] = 0
				_actualizar_ui()
			elif event.is_action_pressed("p%d_right" % numero):
				_choice[numero] = 1
				_actualizar_ui()
		if event.is_action_pressed("p%d_jump" % numero) or event.is_action_pressed("p%d_fire" % numero):
			_toggle_ready(numero)
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()


func _process(_delta: float) -> void:
	for numero in _numeros:
		if not _usa_raw_keyboard(numero):
			continue
		if not _listo[numero]:
			if KeyboardSetup.raw_action_just_pressed(numero, "left"):
				_choice[numero] = 0
				_actualizar_ui()
			elif KeyboardSetup.raw_action_just_pressed(numero, "right"):
				_choice[numero] = 1
				_actualizar_ui()
		if (
			KeyboardSetup.raw_action_just_pressed(numero, "jump")
			or KeyboardSetup.raw_action_just_pressed(numero, "fire")
		):
			_toggle_ready(numero)


func _usa_raw_keyboard(numero: int) -> bool:
	return numero <= 2 and KeyboardSetup.raw_input_activo()


func _toggle_ready(numero: int) -> void:
	_listo[numero] = not _listo[numero]
	AudioManager.reproducir("salto", 0.05)
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _comprobar_inicio_automatico() -> void:
	if not _todos_listos():
		return
	await get_tree().create_timer(0.4).timeout
	if _todos_listos() and is_inside_tree():
		_iniciar_partida()


func _todos_listos() -> bool:
	for numero in _numeros:
		if not _listo[numero]:
			return false
	return not _numeros.is_empty()


func _actualizar_ui() -> void:
	for numero in _numeros:
		var color := RunManager.color_jugador(numero)
		var elegido: int = _choice[numero]
		_card_pato[numero].add_theme_stylebox_override("panel", _estilo_card(color, elegido == 0))
		_card_esqueleto[numero].add_theme_stylebox_override("panel", _estilo_card(color, elegido == 1))
		var boton: Button = _ready_btn[numero]
		boton.text = "CANCELAR" if _listo[numero] else "¡LISTO!"
		var status: Label = _status_lbl[numero]
		if _listo[numero]:
			status.text = "¡LISTO PARA COMBATIR!"
			status.modulate = COLOR_LISTO
		else:
			status.text = "Mové para elegir • Saltá para confirmar"
			status.modulate = Color(0.7, 0.7, 0.7, 1.0)
	_btn_iniciar.text = "¡A LUCHAR! (COMENZANDO...)" if _todos_listos() else "COMENZAR PARTIDA"


func _iniciar_partida() -> void:
	for numero in _numeros:
		RunManager.set_personaje(numero, PERSONAJES[_choice[numero]])
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _volver_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)
