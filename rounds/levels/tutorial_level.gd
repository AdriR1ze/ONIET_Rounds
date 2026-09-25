extends Node2D

# Sala de práctica interactiva: una instrucción a la vez y solo avanza cuando la
# acción REAL ocurre (llegar a la marca, saltar de verdad, romper el blanco con
# una bala, parrear la bala del drill, elegir una mejora). Nada se completa "por
# apretar la tecla".

const MENU_PRINCIPAL := "res://ui/main_menu.tscn"
const BALA_SCENE := preload("res://weapons/bullet.tscn")

enum Paso { MOVER, SALTAR, DISPARAR, PARRY_LATERAL, PARRY_ARRIBA, MEJORAS, FIN }

const ALCANCE_META := 60.0
const TOTAL_PASOS := 6

# Drill de parry (pasos 4 y 5). Las dos balas salen RELATIVAS a la posición del
# jugador: el drill ocurre donde el jugador está parado (sin teletransporte).
# En map_02_tres_pisos el jugador arranca y dispara parado sobre la plataforma
# del SpawnP1 (fila de tiles gy15, techo y=480); a esa altura la fila gy14 está
# despejada de pared a pared, así que el carril lateral no toca geometría.
# La bala que cae recorre un tramo SIN techo: la plataforma gy11 termina en
# y=384 y la bala aparece en y ≈ jugador.y - 55 (≈404), por debajo de ella.
const DRILL_LATERAL_DIST := 170.0      # la bala lateral nace a la izquierda
const DRILL_LATERAL_VELOCIDAD := 130.0
const DRILL_ALTO_CAIDA := 55.0         # la bala que cae nace por encima
const DRILL_CAIDA_VELOCIDAD := 50.0
const DRILL_DANIO := 25
const DRILL_ESPERA_MAXIMA := 4.0

@onready var _player: Player = $Player1
@onready var _health: HealthComponent = $Player1/HealthComponent
@onready var _meta: Marker2D = $Meta
@onready var _blanco: TrainingTarget = $Placement/Blanco
@onready var _paso_label: Label = $TutorialHUD/Arriba/Info/Paso
@onready var _progreso_label: Label = $TutorialHUD/Arriba/Info/Progreso
@onready var _aviso_label: Label = $TutorialHUD/Arriba/Info/Aviso
@onready var _boton_saltear: Button = $TutorialHUD/Abajo/Botones/Saltear
@onready var _boton_volver: Button = $TutorialHUD/Abajo/Botones/Volver
@onready var _drill_timer: Timer = $DrillTimer
@onready var _upgrade_screen: UpgradeScreen = $UpgradeScreen

var _paso: int = Paso.MOVER
var _piso_previo: bool = true
var _bala_drill: Node = null
var _drill_resuelto: bool = false


func _ready() -> void:
	_health.died.connect(_on_player_died)
	_blanco.destroyed.connect(_on_blanco_destruido)
	_player.parried_bullet.connect(_on_player_parried)
	_drill_timer.timeout.connect(_on_drill_timeout)
	_boton_saltear.pressed.connect(_saltar_paso)
	_boton_volver.pressed.connect(_volver_al_menu)
	_piso_previo = _player.is_on_floor()
	_actualizar_hud()


func _physics_process(_delta: float) -> void:
	match _paso:
		Paso.MOVER:
			if _player.global_position.distance_to(_meta.global_position) <= ALCANCE_META:
				_avanzar()
		Paso.SALTAR:
			var en_suelo: bool = _player.is_on_floor()
			if _piso_previo and not en_suelo and _player.velocity.y < 0.0:
				_avanzar()
	_piso_previo = _player.is_on_floor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_player.respawn()
		get_viewport().set_input_as_handled()


func _avanzar() -> void:
	if _paso >= Paso.FIN:
		return
	_ir_al_paso(_paso + 1)
	_aviso_label.text = "¡Bien!"


func _saltar_paso() -> void:
	if _paso >= Paso.FIN:
		return
	_ir_al_paso(_paso + 1)
	_aviso_label.text = "Paso salteado."


func _ir_al_paso(nuevo: int) -> void:
	if nuevo < Paso.MOVER or nuevo > Paso.FIN:
		return
	_limpiar_paso(_paso)
	_paso = nuevo
	match _paso:
		Paso.DISPARAR:
			# Por si el jugador rompió el blanco antes de tiempo o hay que reintentar.
			_blanco.revive()
		Paso.PARRY_LATERAL, Paso.PARRY_ARRIBA:
			_iniciar_drill()
		Paso.MEJORAS:
			_iniciar_mejoras()
	_actualizar_hud()


func _limpiar_paso(paso: int) -> void:
	if paso != Paso.PARRY_LATERAL and paso != Paso.PARRY_ARRIBA:
		return
	_drill_resuelto = true
	_drill_timer.stop()
	if is_instance_valid(_bala_drill):
		_bala_drill.queue_free()
	_bala_drill = null


func _actualizar_hud() -> void:
	_paso_label.text = _texto_paso(_paso)
	_progreso_label.text = "%d / %d" % [mini(_paso + 1, TOTAL_PASOS), TOTAL_PASOS]
	_boton_saltear.visible = _paso < Paso.FIN


func _texto_paso(paso: int) -> String:
	match paso:
		Paso.MOVER:
			return "Movete hasta la marca  (%s / %s)" % [_tecla("left"), _tecla("right")]
		Paso.SALTAR:
			return "Saltá  (%s)" % _tecla("jump")
		Paso.DISPARAR:
			return "Rompé el blanco  (%s)" % _tecla("fire")
		Paso.PARRY_LATERAL:
			return "Viene una bala de costado: parreala apuntando hacia ella  (%s)" % _tecla("ragdoll")
		Paso.PARRY_ARRIBA:
			# Ojo: "arriba" y "saltar" comparten tecla, así que apuntar arriba
			# también hace saltar. Por eso el aviso.
			return "Cae una bala desde arriba: apuntá arriba con %s (también salta) y parreala con %s" % [_tecla("up"), _tecla("ragdoll")]
		Paso.MEJORAS:
			return "Elegí tu mejora"
		_:
			return "¡Listo! Completaste el tutorial."


# Las teclas SIEMPRE salen de los bindings vivos (remapeables), igual que en
# options_screen.gd:204. Nunca se hardcodea A/D/W/V/Q.
func _tecla(sufijo: String) -> String:
	var accion := "p%d_%s" % [_player.player_number, sufijo]
	return Settings.nombre_binding(Settings.binding_de(accion))


func _on_blanco_destruido() -> void:
	if _paso == Paso.DISPARAR:
		_avanzar()


# ── Drill de parry ───────────────────────────────────────────────────────────
# El paso se completa por RESULTADO: el jugador parrea ESA bala (player.on_parry
# emite parried_bullet). No se mira la tecla.

func _es_paso_parry() -> bool:
	return _paso == Paso.PARRY_LATERAL or _paso == Paso.PARRY_ARRIBA


func _iniciar_drill() -> void:
	_bala_drill = null
	_drill_resuelto = false
	# Concesión del tutorial: NO usamos player.respawn() para reiniciar el cooldown
	# del parry porque teleporta al spawn. El drill arranca donde el jugador está
	# parado, así que tocamos el cooldown directo (player.gd tiene trabajo en curso
	# y no expone un reset público).
	_player.set("_parry_cooldown", 0.0)
	_crear_bala_drill()
	_drill_timer.start(DRILL_ESPERA_MAXIMA)


func _crear_bala_drill() -> void:
	var desde_arriba: bool = _paso == Paso.PARRY_ARRIBA
	var bala := BALA_SCENE.instantiate()
	if desde_arriba:
		bala.direction = Vector2.DOWN
		bala.speed = DRILL_CAIDA_VELOCIDAD
		bala.velocity = Vector2.DOWN * DRILL_CAIDA_VELOCIDAD
	else:
		bala.direction = Vector2.RIGHT
		bala.speed = DRILL_LATERAL_VELOCIDAD
		bala.velocity = Vector2.RIGHT * DRILL_LATERAL_VELOCIDAD
	bala.damage = DRILL_DANIO
	# Sin gravedad: vuela perfectamente recto y predecible. SIN wall_pierce: el
	# carril elegido está realmente despejado (nada de balas fantasma).
	bala.bullet_gravity = 0.0
	bala.lifetime = DRILL_ESPERA_MAXIMA + 1.0
	bala.shooter = null
	bala.player = null
	# IMPORTANTE: posicionar ANTES de add_child. Si se agrega primero, el Area2D
	# nace en (0,0), solapa el tile de la esquina del mapa y muere en el primer
	# frame. (En la v1 lo tapaba el wall_pierce.)
	var origen: Vector2 = _player.global_position
	if desde_arriba:
		bala.position = origen + Vector2(0.0, -DRILL_ALTO_CAIDA)
	else:
		bala.position = origen + Vector2(-DRILL_LATERAL_DIST, 0.0)
	get_tree().current_scene.add_child(bala)
	bala.tree_exiting.connect(_on_drill_bullet_gone.bind(bala))
	_bala_drill = bala


func _on_drill_bullet_gone(bala: Node) -> void:
	if bala != _bala_drill:
		return
	_bala_drill = null
	if not _es_paso_parry() or _drill_resuelto:
		return
	# La bala se fue (impactó al jugador o al mundo) sin ser parreada. No se puede
	# add_child() dentro de tree_exiting, así que el reintento se difiere un frame.
	_drill_timer.stop()
	_reintentar_drill.call_deferred()


func _on_drill_timeout() -> void:
	if not _es_paso_parry() or _drill_resuelto:
		return
	# Se pasó de largo sin tocar a nadie: reintento inmediato.
	if is_instance_valid(_bala_drill):
		_bala_drill.queue_free()
	_bala_drill = null
	_reintentar_drill()


func _reintentar_drill() -> void:
	if not _es_paso_parry() or _drill_resuelto:
		return
	_aviso_label.text = "Uy, probá de nuevo"
	_iniciar_drill()


func _on_player_parried(bullet: Node) -> void:
	if not _es_paso_parry() or bullet != _bala_drill:
		return
	_drill_resuelto = true
	_drill_timer.stop()
	if is_instance_valid(_bala_drill):
		_bala_drill.queue_free()
	_bala_drill = null
	_avanzar()


# ── Paso de mejoras ──────────────────────────────────────────────────────────

func _iniciar_mejoras() -> void:
	# La pantalla REAL se encarga de pausar, mostrar las cartas, aplicar la mejora
	# y cerrarse. Acá le pedimos UNA sola carta y esperamos a que cierre.
	await _upgrade_screen.abrir(1)
	if _paso == Paso.MEJORAS:
		_avanzar()


# ── Flujo de nivel ───────────────────────────────────────────────────────────

func _on_player_died() -> void:
	# respawn() ya reinicia salud, posición, estado, timers y buffs por sí solo.
	# Caer al vacío SÍ es una muerte: teletransportar al spawn acá es correcto.
	_player.respawn()


func _volver_al_menu() -> void:
	Transition.cambiar_escena(MENU_PRINCIPAL)
