extends CanvasLayer

signal cerrado

const CARD_SCENE := preload("res://ui/upgrade_card.tscn")
const OPCIONES_POR_JUGADOR := 3

@onready var _contenedor: HBoxContainer = $Contenedor
@onready var _titulo: Label = $Titulo

var _activo := false
var _jugadores: Array = []
var _opciones: Dictionary = {}
var _indices: Dictionary = {}
var _confirmados: Dictionary = {}
var _cartas: Dictionary = {}


func _ready() -> void:
	visible = false


func abrir() -> void:
	if _activo:
		return
	_activo = true
	visible = true
	PauseManager.tomar(self)
	_construir()
	await cerrado


func _construir() -> void:
	for hijo in _contenedor.get_children():
		_contenedor.remove_child(hijo)
		hijo.queue_free()
	_cartas.clear()
	_opciones.clear()
	_indices.clear()
	_confirmados.clear()
	_jugadores = RunManager.jugadores()
	for jugador in _jugadores:
		var numero: int = jugador.player_number
		_opciones[numero] = RunManager.opciones_para(numero, OPCIONES_POR_JUGADOR)
		_indices[numero] = 0
		_confirmados[numero] = false
		_crear_panel(numero)
	_actualizar_seleccion()
	_titulo.text = "Elige una mejora   |   %s: A/D + V      %s: Izq/Der + ," % [RunManager.nombre_jugador(1), RunManager.nombre_jugador(2)]


func _crear_panel(numero: int) -> void:
	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 14)
	_contenedor.add_child(panel)

	var etiqueta := Label.new()
	var vidas_count: int = RunManager.vidas_de(numero)
	var max_nivel: int = RunManager.nivel_desbloqueado(numero)
	var corazones := ""
	for i in 5:
		corazones += "♥" if i < vidas_count else "♡"
	etiqueta.text = "%s  [%s]\nMejoras hasta Nivel %d" % [RunManager.nombre_jugador(numero), corazones, max_nivel]
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 18)
	panel.add_child(etiqueta)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	panel.add_child(fila)
	var cartas: Array = []
	for def in _opciones[numero]:
		var carta := CARD_SCENE.instantiate()
		fila.add_child(carta)
		carta.configurar(def)
		cartas.append(carta)
	_cartas[numero] = cartas


func _process(_delta: float) -> void:
	if not _activo:
		return
	for jugador in _jugadores:
		var numero: int = jugador.player_number
		if _confirmados.get(numero, false):
			continue
		var total: int = _opciones[numero].size()
		if total == 0:
			_confirmar(numero)
			continue
		if Input.is_action_just_pressed(_accion(numero, "left")):
			_indices[numero] = wrapi(_indices[numero] - 1, 0, total)
			_actualizar_seleccion()
			AudioManager.reproducir("ui_mover", 0.05)
		if Input.is_action_just_pressed(_accion(numero, "right")):
			_indices[numero] = wrapi(_indices[numero] + 1, 0, total)
			_actualizar_seleccion()
			AudioManager.reproducir("ui_mover", 0.05)
		if Input.is_action_just_pressed(_accion(numero, "fire")):
			_confirmar(numero)


func _confirmar(numero: int) -> void:
	if _confirmados.get(numero, false):
		return
	_confirmados[numero] = true
	var idx: int = _indices[numero]
	if idx < _opciones[numero].size():
		RunManager.elegir(numero, _opciones[numero][idx])
	for carta in _cartas.get(numero, []):
		carta.modulate = Color(1, 1, 1, 0.4)
	if _todos_confirmados():
		call_deferred("_cerrar_con_delay")


func _cerrar_con_delay() -> void:
	await get_tree().create_timer(0.18, true, false, true).timeout
	_cerrar()


func _cerrar() -> void:
	_activo = false
	visible = false
	Input.action_release("p1_fire")
	Input.action_release("p2_fire")
	PauseManager.soltar(self)
	cerrado.emit()


func _todos_confirmados() -> bool:
	for numero in _confirmados:
		if not _confirmados[numero]:
			return false
	return true


func _actualizar_seleccion() -> void:
	for numero in _cartas:
		var cartas: Array = _cartas[numero]
		for i in cartas.size():
			cartas[i].marcar_seleccionada(i == _indices[numero])


func _accion(numero: int, nombre: String) -> String:
	return "p%d_%s" % [numero, nombre]
