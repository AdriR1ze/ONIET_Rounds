extends Control

const PERSONAJES: Array[String] = ["pato", "esqueleto"]
const ESCENA_JUEGO := "res://levels/test_level.tscn"
const ESCENA_MENU := "res://ui/main_menu.tscn"

# Colores de equipo
const COLOR_P1 := Color(1.0, 0.85, 0.2, 1.0) # Oro / Amarillo
const COLOR_P2 := Color(0.35, 0.75, 1.0, 1.0) # Cian
const COLOR_APAGADO := Color(0.2, 0.22, 0.28, 1.0)
const COLOR_LISTO := Color(0.3, 0.9, 0.4, 1.0)

var p1_choice: int = 0
var p2_choice: int = 0
var p1_ready: bool = false
var p2_ready: bool = false

# Nodos UI
@onready var _p1_titulo: Label = $Margin/VBox/PanelJugadores/P1Container/HeaderP1/NombreP1
@onready var _p2_titulo: Label = $Margin/VBox/PanelJugadores/P2Container/HeaderP2/NombreP2

@onready var _p1_card_pato: PanelContainer = $Margin/VBox/PanelJugadores/P1Container/Cards/CardPato
@onready var _p1_card_esqueleto: PanelContainer = $Margin/VBox/PanelJugadores/P1Container/Cards/CardEsqueleto
@onready var _p1_ready_btn: Button = $Margin/VBox/PanelJugadores/P1Container/BotonListoP1
@onready var _p1_status_lbl: Label = $Margin/VBox/PanelJugadores/P1Container/EstadoP1

@onready var _p2_card_pato: PanelContainer = $Margin/VBox/PanelJugadores/P2Container/Cards/CardPato
@onready var _p2_card_esqueleto: PanelContainer = $Margin/VBox/PanelJugadores/P2Container/Cards/CardEsqueleto
@onready var _p2_ready_btn: Button = $Margin/VBox/PanelJugadores/P2Container/BotonListoP2
@onready var _p2_status_lbl: Label = $Margin/VBox/PanelJugadores/P2Container/EstadoP2

@onready var _p1_skel_sprite: AnimatedSprite2D = $Margin/VBox/PanelJugadores/P1Container/Cards/CardEsqueleto/VBox/PreviewBox/SkelSpriteP1
@onready var _p2_skel_sprite: AnimatedSprite2D = $Margin/VBox/PanelJugadores/P2Container/Cards/CardEsqueleto/VBox/PreviewBox/SkelSpriteP2

@onready var _btn_iniciar: Button = $Margin/VBox/Footer/BotonIniciar
@onready var _btn_volver: Button = $Margin/VBox/Footer/BotonVolver


func _ready() -> void:
	AudioManager.reproducir_musica("menu")
	_p1_titulo.text = RunManager.nombre_jugador(1)
	_p2_titulo.text = RunManager.nombre_jugador(2)

	# Iniciar animaciones de spritesheet y modular colores
	if _p1_skel_sprite != null:
		_p1_skel_sprite.modulate = Color(1.25, 1.05, 0.25, 1.0)
		_p1_skel_sprite.play("walk")
	if _p2_skel_sprite != null:
		_p2_skel_sprite.modulate = Color(0.35, 0.85, 1.3, 1.0)
		_p2_skel_sprite.play("walk")

	# Conectar botones de ratón
	_p1_card_pato.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not p1_ready:
				p1_choice = 0
				_actualizar_ui()
	)
	_p1_card_esqueleto.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not p1_ready:
				p1_choice = 1
				_actualizar_ui()
	)
	_p2_card_pato.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not p2_ready:
				p2_choice = 0
				_actualizar_ui()
	)
	_p2_card_esqueleto.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not p2_ready:
				p2_choice = 1
				_actualizar_ui()
	)

	_p1_ready_btn.pressed.connect(_toggle_p1_ready)
	_p2_ready_btn.pressed.connect(_toggle_p2_ready)
	_btn_iniciar.pressed.connect(_iniciar_partida)
	_btn_volver.pressed.connect(_volver_al_menu)

	_actualizar_ui()


func _unhandled_input(event: InputEvent) -> void:
	# Controles Jugador 1
	if not p1_ready:
		if event.is_action_pressed("p1_left") or event.is_action_pressed("ui_left"):
			p1_choice = 0
			_actualizar_ui()
		elif event.is_action_pressed("p1_right") or event.is_action_pressed("ui_right"):
			p1_choice = 1
			_actualizar_ui()
	if event.is_action_pressed("p1_jump") or event.is_action_pressed("p1_fire"):
		_toggle_p1_ready()
		get_viewport().set_input_as_handled()

	# Controles Jugador 2
	if not p2_ready:
		if event.is_action_pressed("p2_left"):
			p2_choice = 0
			_actualizar_ui()
		elif event.is_action_pressed("p2_right"):
			p2_choice = 1
			_actualizar_ui()
	if event.is_action_pressed("p2_jump") or event.is_action_pressed("p2_fire"):
		_toggle_p2_ready()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()


func _toggle_p1_ready() -> void:
	p1_ready = not p1_ready
	AudioManager.reproducir("salto", 0.05)
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _toggle_p2_ready() -> void:
	p2_ready = not p2_ready
	AudioManager.reproducir("salto", 0.05)
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _comprobar_inicio_automatico() -> void:
	if p1_ready and p2_ready:
		# Iniciar partida tras un pequeño destello
		await get_tree().create_timer(0.4).timeout
		if p1_ready and p2_ready and is_inside_tree():
			_iniciar_partida()


func _actualizar_ui() -> void:
	# Actualizar tarjetas P1
	_estilar_tarjeta(_p1_card_pato, p1_choice == 0, COLOR_P1)
	_estilar_tarjeta(_p1_card_esqueleto, p1_choice == 1, COLOR_P1)
	_p1_ready_btn.text = "CANCELAR LISTO" if p1_ready else "¡LISTO!"
	_p1_status_lbl.text = "✓ ¡LISTO PARA COMBATIR!" if p1_ready else "[ A / D cambiar  •  W / Espacio confirmar ]"
	_p1_status_lbl.modulate = COLOR_LISTO if p1_ready else Color(0.7, 0.7, 0.7, 1.0)

	# Actualizar tarjetas P2
	_estilar_tarjeta(_p2_card_pato, p2_choice == 0, COLOR_P2)
	_estilar_tarjeta(_p2_card_esqueleto, p2_choice == 1, COLOR_P2)
	_p2_ready_btn.text = "CANCELAR LISTO" if p2_ready else "¡LISTO!"
	_p2_status_lbl.text = "✓ ¡LISTO PARA COMBATIR!" if p2_ready else "[ ← / → cambiar  •  ↑ / Enter confirmar ]"
	_p2_status_lbl.modulate = COLOR_LISTO if p2_ready else Color(0.7, 0.7, 0.7, 1.0)

	# Botón de inicio
	if p1_ready and p2_ready:
		_btn_iniciar.disabled = false
		_btn_iniciar.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_btn_iniciar.text = "¡A LUCHAR! (COMENZANDO...)"
	else:
		_btn_iniciar.disabled = false
		_btn_iniciar.modulate = Color(0.9, 0.9, 0.9, 1.0)
		_btn_iniciar.text = "COMENZAR PARTIDA"


func _estilar_tarjeta(card: PanelContainer, seleccionada: bool, color_borde: Color) -> void:
	var sb: StyleBoxFlat
	if card.has_theme_stylebox_override("panel"):
		sb = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	else:
		sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18, 0.95) if seleccionada else Color(0.06, 0.07, 0.1, 0.8)
	sb.border_width_left = 3 if seleccionada else 1
	sb.border_width_top = 3 if seleccionada else 1
	sb.border_width_right = 3 if seleccionada else 1
	sb.border_width_bottom = 3 if seleccionada else 1
	sb.border_color = color_borde if seleccionada else COLOR_APAGADO
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", sb)


func _iniciar_partida() -> void:
	RunManager.set_personaje(1, PERSONAJES[p1_choice])
	RunManager.set_personaje(2, PERSONAJES[p2_choice])
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _volver_al_menu() -> void:
	get_tree().change_scene_to_file(ESCENA_MENU)
