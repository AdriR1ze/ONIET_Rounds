extends Node2D

const MENU_PRINCIPAL := "res://ui/main_menu.tscn"

# Sufijos de Settings.SUFIJOS que se muestran en el panel, en orden.
const SUFIJOS_MOSTRADOS := ["left", "right", "jump", "down", "fire", "ragdoll", "grab"]

@onready var _player: Player = $Player1
@onready var _health: HealthComponent = $Player1/HealthComponent
@onready var _panel: VBoxContainer = $TutorialHUD/Fondo/Panel
@onready var _controles: Label = $TutorialHUD/Fondo/Panel/Controles
@onready var _boton_volver: Button = $TutorialHUD/Fondo/Panel/Volver

var _accion_fire: String = ""


func _ready() -> void:
	_accion_fire = "p%d_fire" % _player.player_number
	_health.died.connect(_on_player_died)
	_boton_volver.pressed.connect(_volver_al_menu)
	_controles.text = _construir_texto_controles()


func _unhandled_input(event: InputEvent) -> void:
	# El panel se cierra con la acción de disparo REAL del jugador. No depende
	# del foco de un Button (eso ya causó un bug con teclas de gameplay).
	if _panel.visible and event.is_action_pressed(_accion_fire):
		_panel.visible = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart"):
		_player.respawn()
		get_viewport().set_input_as_handled()


func _construir_texto_controles() -> String:
	var lineas: PackedStringArray = []
	for sufijo in SUFIJOS_MOSTRADOS:
		var accion := "p%d_%s" % [_player.player_number, sufijo]
		var etiqueta: String = Settings.ETIQUETAS.get(sufijo, sufijo)
		var tecla := Settings.nombre_binding(Settings.binding_de(accion))
		lineas.append("%s: %s" % [etiqueta, tecla])
	var cerrar := Settings.nombre_binding(Settings.binding_de(_accion_fire))
	lineas.append("")
	lineas.append("Presioná %s para empezar a practicar." % cerrar)
	return "\n".join(lineas)


func _on_player_died() -> void:
	# respawn() ya reinicia salud, posición, estado, timers y buffs por sí solo.
	_player.respawn()


func _volver_al_menu() -> void:
	Transition.cambiar_escena(MENU_PRINCIPAL)
