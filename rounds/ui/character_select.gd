extends Control

const PERSONAJES: Array[String] = ["esqueleto", "sapo", "pajaro"]
const COLUMNAS_PERSONAJES := 2
const ESCENA_JUEGO := "res://levels/test_level.tscn"
const ESCENA_MENU := "res://ui/main_menu.tscn"

const SKEL_FRAMES: SpriteFrames = preload("res://player/skeleton_frames.tres")
const SAPO_FRAMES: SpriteFrames = preload("res://player/sapo_frames.tres")
const PAJARO_FRAMES: SpriteFrames = preload("res://player/pajaro_frames.tres")
const SKEL_SHADER: Shader = preload("res://player/skeleton_palette.gdshader")
const SPRITE_FRAMES := {
	"esqueleto": SKEL_FRAMES,
	"sapo": SAPO_FRAMES,
	"pajaro": PAJARO_FRAMES,
}
const NOMBRES_PERSONAJES := {
	"esqueleto": "Esqueleto",
	"sapo": "Sapo",
	"pajaro": "Pajaro",
}
const DESCRIPCIONES_PERSONAJES := {
	"esqueleto": "Agil, huesudo e implacable.",
	"sapo": "Salton, verde y dificil de tumbar.",
	"pajaro": "Ligero, veloz y con mucho estilo.",
}

const COLOR_APAGADO := Color(0.2, 0.22, 0.28, 1.0)
const COLOR_LISTO := Color(0.3, 0.9, 0.4, 1.0)

@onready var _panel_jugadores: HBoxContainer = $Margin/VBox/PanelJugadores
@onready var _btn_iniciar: Button = $Margin/VBox/Footer/BotonIniciar
@onready var _btn_volver: Button = $Margin/VBox/Footer/BotonVolver

var _numeros: Array = []
var _choice: Dictionary = {}
var _listo: Dictionary = {}
var _cards: Dictionary = {}
var _ready_btn: Dictionary = {}
var _status_lbl: Dictionary = {}
var _disp_sel: Dictionary = {}
var _nav_cooldowns: Dictionary = {}


func _ready() -> void:
	_btn_iniciar.focus_mode = Control.FOCUS_NONE
	_btn_volver.focus_mode = Control.FOCUS_NONE
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
	panel.add_child(_crear_selector_dispositivo(numero))

	var cards := GridContainer.new()
	cards.columns = COLUMNAS_PERSONAJES
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	_cards[numero] = []
	for indice in PERSONAJES.size():
		var personaje := PERSONAJES[indice]
		var card := _crear_card_sprite(numero, color, personaje, indice)
		cards.add_child(card)
		_cards[numero].append(card)
	panel.add_child(cards)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 11)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	_status_lbl[numero] = status

	var boton := Button.new()
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(130, 32)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.pressed.connect(_toggle_ready.bind(numero))
	panel.add_child(boton)
	_ready_btn[numero] = boton

	return panel


func _crear_selector_dispositivo(numero: int) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	var etiqueta := Label.new()
	etiqueta.text = "Dispositivo:"
	etiqueta.add_theme_font_size_override("font_size", 11)
	etiqueta.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	fila.add_child(etiqueta)
	var selector := OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	# ids del menu: 0 = teclado, 1..MAX = device 0..MAX-1 (Godot auto-genera
	# ids para -1, por eso no se puede usar DISPOSITIVO_TECLADO como id).
	selector.add_item("Teclado", 0)
	var conectados := Input.get_connected_joypads()
	for m in Settings.MAX_MANDOS:
		var texto := "Mando %d" % (m + 1)
		if conectados.has(m):
			texto += " (conectado)"
		selector.add_item(texto, m + 1)
	selector.select(selector.get_item_index(Settings.dispositivo_de(numero) + 1))
	selector.item_selected.connect(_on_dispositivo_seleccionado.bind(numero))
	fila.add_child(selector)
	_disp_sel[numero] = selector
	return fila


func _on_dispositivo_seleccionado(indice: int, numero: int) -> void:
	var selector: OptionButton = _disp_sel[numero]
	Settings.set_dispositivo(numero, selector.get_item_id(indice) - 1)


func _crear_card_sprite(numero: int, color: Color, personaje: String, indice: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(_on_card_input.bind(numero, indice))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 100)
	var sprite := AnimatedSprite2D.new()
	if personaje == "esqueleto":
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
	sprite.sprite_frames = SPRITE_FRAMES[personaje]
	sprite.animation = &"walk"
	sprite.frame_progress = 0.5
	preview.add_child(sprite)
	vbox.add_child(preview)
	vbox.add_child(_texto(NOMBRES_PERSONAJES[personaje], 15, Color.WHITE))
	vbox.add_child(_texto(DESCRIPCIONES_PERSONAJES[personaje], 11, Color(0.7, 0.72, 0.8)))
	card.add_child(vbox)
	_ignorar_raton(vbox)
	return card


func _ignorar_raton(nodo: Node) -> void:
	if nodo is Control:
		(nodo as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hijo in nodo.get_children():
		_ignorar_raton(hijo)


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
	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE) and Settings.es_teclado(1):
			_toggle_ready(1)


func _process(delta: float) -> void:
	for numero in _numeros:
		if _usa_raw_keyboard(numero):
			if not _listo[numero]:
				if KeyboardSetup.raw_action_just_pressed(numero, "left"):
					_mover_eleccion(numero, -1)
					AudioManager.reproducir("ui_mover", 0.05)
				elif KeyboardSetup.raw_action_just_pressed(numero, "right"):
					_mover_eleccion(numero, 1)
					AudioManager.reproducir("ui_mover", 0.05)
				elif KeyboardSetup.raw_action_just_pressed(numero, "up"):
					_mover_eleccion(numero, -COLUMNAS_PERSONAJES)
					AudioManager.reproducir("ui_mover", 0.05)
				elif KeyboardSetup.raw_action_just_pressed(numero, "down"):
					_mover_eleccion(numero, COLUMNAS_PERSONAJES)
					AudioManager.reproducir("ui_mover", 0.05)
			if KeyboardSetup.raw_action_just_pressed(numero, "fire") or KeyboardSetup.raw_action_just_pressed(numero, "jump"):
				_toggle_ready(numero)
			continue

		# Jugadores de mando o teclado estándar
		if not _listo[numero]:
			var mx := Input.get_axis("p%d_left" % numero, "p%d_right" % numero)
			var my := Input.get_axis("p%d_up" % numero, "p%d_down" % numero)
			var cd: float = maxf(float(_nav_cooldowns.get(numero, 0.0)) - delta, 0.0)
			if absf(mx) < 0.35 and absf(my) < 0.35:
				_nav_cooldowns[numero] = 0.0
			elif cd <= 0.0:
				if absf(mx) >= absf(my):
					_mover_eleccion(numero, 1 if mx > 0.0 else -1)
				else:
					_mover_eleccion(numero, COLUMNAS_PERSONAJES if my > 0.0 else -COLUMNAS_PERSONAJES)
				_nav_cooldowns[numero] = 0.22
				AudioManager.reproducir("ui_mover", 0.05)

		var fire_pressed: bool = Input.is_action_just_pressed("p%d_fire" % numero)
		var jump_pressed: bool = Input.is_action_just_pressed("p%d_jump" % numero)
		if fire_pressed or jump_pressed:
			_toggle_ready(numero)


func _usa_raw_keyboard(numero: int) -> bool:
	return Settings.es_teclado(numero) and numero <= 2 and KeyboardSetup.raw_input_activo()


func _toggle_ready(numero: int) -> void:
	_listo[numero] = not _listo[numero]
	AudioManager.reproducir("salto", 0.05)
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _mover_eleccion(numero: int, direccion: int) -> void:
	_choice[numero] = posmod(int(_choice[numero]) + direccion, PERSONAJES.size())
	_actualizar_ui()


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
		var cards: Array = _cards[numero]
		for indice in cards.size():
			cards[indice].add_theme_stylebox_override("panel", _estilo_card(color, elegido == indice))
		var boton: Button = _ready_btn[numero]
		boton.text = "CANCELAR" if _listo[numero] else "¡LISTO!"
		var status: Label = _status_lbl[numero]
		if _listo[numero]:
			status.text = "¡LISTO PARA COMBATIR!"
			status.modulate = COLOR_LISTO
		else:
			status.text = "Mové para elegir • X / Dispará para confirmar"
			status.modulate = Color(0.7, 0.7, 0.7, 1.0)
	_btn_iniciar.text = "¡A LUCHAR! (COMENZANDO...)" if _todos_listos() else "COMENZAR PARTIDA"


func _iniciar_partida() -> void:
	for numero in _numeros:
		RunManager.set_personaje(numero, PERSONAJES[_choice[numero]])
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _volver_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)
