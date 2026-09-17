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


var _status_labels: Dictionary = {}


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
	_status_labels.clear()
	_jugadores = RunManager.jugadores()

	for i in _jugadores.size():
		var jugador = _jugadores[i]
		var numero: int = jugador.player_number
		_opciones[numero] = RunManager.opciones_para(numero, OPCIONES_POR_JUGADOR)
		_indices[numero] = 0
		_confirmados[numero] = false

		_crear_panel(numero)

		# Insertar divisor central entre jugadores
		if i == 0 and _jugadores.size() > 1:
			_crear_divisor_central()

	_actualizar_seleccion()
	_titulo.text = "ELIGE UNA MEJORA"


func _crear_panel(numero: int) -> void:
	var color_acento: Color = Color(0.25, 0.85, 1.0) if numero == 1 else Color(1.0, 0.55, 0.25)
	var color_fondo: Color = Color(0.03, 0.06, 0.10, 0.88) if numero == 1 else Color(0.10, 0.05, 0.03, 0.88)

	var panel_marco := PanelContainer.new()
	panel_marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_marco.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = color_fondo
	sb.border_color = Color(color_acento.r, color_acento.g, color_acento.b, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_top = 12
	sb.content_margin_right = 16
	sb.content_margin_bottom = 12
	panel_marco.add_theme_stylebox_override("panel", sb)
	_contenedor.add_child(panel_marco)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	v_box.add_theme_constant_override("separation", 10)
	panel_marco.add_child(v_box)

	# Encabezado del jugador
	var header_box := VBoxContainer.new()
	header_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_box.add_theme_constant_override("separation", 2)
	v_box.add_child(header_box)

	var titulo_jugador := Label.new()
	titulo_jugador.text = "%s" % RunManager.nombre_jugador(numero).to_upper()
	titulo_jugador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_jugador.add_theme_font_size_override("font_size", 18)
	titulo_jugador.modulate = color_acento
	header_box.add_child(titulo_jugador)

	var vidas_count: int = RunManager.vidas_de(numero)
	var max_nivel: int = RunManager.nivel_desbloqueado(numero)
	var corazones := ""
	for i in 5:
		corazones += "♥" if i < vidas_count else "♡"
	var controles_hint: String = "[ A / D ]  Elegir: [ V ]" if numero == 1 else "[ ← / → ]  Elegir: [ , ]"

	var info_sub := Label.new()
	info_sub.text = "%s  •  Nivel máx %d  •  %s" % [corazones, max_nivel, controles_hint]
	info_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_sub.add_theme_font_size_override("font_size", 12)
	info_sub.modulate = Color(0.85, 0.88, 0.95, 0.8)
	header_box.add_child(info_sub)

	var sep := HSeparator.new()
	sep.modulate = Color(color_acento.r, color_acento.g, color_acento.b, 0.4)
	v_box.add_child(sep)

	# Fila de cartas
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 14)
	v_box.add_child(fila)

	var cartas: Array = []
	for def in _opciones[numero]:
		var carta := CARD_SCENE.instantiate()
		fila.add_child(carta)
		carta.configurar(def)
		cartas.append(carta)
	_cartas[numero] = cartas

	# Estado / Confirmación
	var status_lbl := Label.new()
	status_lbl.text = "Seleccionando carta..."
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.modulate = Color(0.7, 0.75, 0.85, 0.75)
	v_box.add_child(status_lbl)
	_status_labels[numero] = status_lbl


func _crear_divisor_central() -> void:
	var div_container := VBoxContainer.new()
	div_container.alignment = BoxContainer.ALIGNMENT_CENTER
	div_container.custom_minimum_size = Vector2(48, 0)
	div_container.add_theme_constant_override("separation", 12)
	_contenedor.add_child(div_container)

	# Línea superior
	var linea_sup := ColorRect.new()
	linea_sup.custom_minimum_size = Vector2(2, 160)
	linea_sup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	linea_sup.color = Color(0.4, 0.5, 0.7, 0.35)
	div_container.add_child(linea_sup)

	# Emblema "VS"
	var vs_panel := PanelContainer.new()
	vs_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vs_sb := StyleBoxFlat.new()
	vs_sb.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	vs_sb.border_color = Color(1.0, 0.82, 0.25, 0.85)
	vs_sb.set_border_width_all(2)
	vs_sb.set_corner_radius_all(16)
	vs_sb.content_margin_left = 12
	vs_sb.content_margin_top = 8
	vs_sb.content_margin_right = 12
	vs_sb.content_margin_bottom = 8
	vs_panel.add_theme_stylebox_override("panel", vs_sb)
	div_container.add_child(vs_panel)

	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.add_theme_font_size_override("font_size", 18)
	vs_label.modulate = Color(1.0, 0.85, 0.3, 1.0)
	vs_panel.add_child(vs_label)

	# Línea inferior
	var linea_inf := ColorRect.new()
	linea_inf.custom_minimum_size = Vector2(2, 160)
	linea_inf.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	linea_inf.color = Color(0.4, 0.5, 0.7, 0.35)
	div_container.add_child(linea_inf)


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

	var lbl: Label = _status_labels.get(numero, null)
	if lbl != null:
		lbl.text = "✓  ¡MEJORA SELECCIONADA!"
		lbl.modulate = Color(0.35, 1.0, 0.5, 1.0)

	if _todos_confirmados():
		call_deferred("_cerrar_con_delay")


func _cerrar_con_delay() -> void:
	await get_tree().create_timer(0.22, true, false, true).timeout
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

