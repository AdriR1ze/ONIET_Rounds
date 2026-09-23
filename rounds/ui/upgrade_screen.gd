extends CanvasLayer
class_name UpgradeScreen

signal cerrado
signal fase_completa

const CARD_SCENE := preload("res://ui/upgrade_card.tscn")
const OPCIONES_POR_JUGADOR := 4
const RAW_MENU_REPEAT_DELAY := 0.18

const COLORES_RAREZA := {
	UpgradeDefinition.Rareza.COMUN: Color(0.78, 0.82, 0.88),
	UpgradeDefinition.Rareza.RARA: Color(0.35, 0.8, 1.0),
	UpgradeDefinition.Rareza.EPICA: Color(0.82, 0.45, 1.0),
	UpgradeDefinition.Rareza.LEGENDARIA: Color(1.0, 0.78, 0.2),
}

@onready var _contenedor: HBoxContainer = $Contenedor
@onready var _titulo: Label = $Titulo

var _activo := false
var _jugadores: Array = []
var _opciones: Dictionary = {}
var _indices: Dictionary = {}
var _confirmados: Dictionary = {}
var _cartas: Dictionary = {}


var _status_labels: Dictionary = {}
var _floating_tags: Array[PanelContainer] = []

var _grupos: Array = []
var _esperando_fase := false
var _raw_menu_prev: Dictionary = {}
var _raw_menu_cooldowns: Dictionary = {}


func _ready() -> void:
	visible = false


func abrir() -> void:
	if _activo:
		return
	_activo = true
	visible = true
	PauseManager.tomar(self)
	_grupos = _construir_grupos()
	_ejecutar_fases()
	await cerrado


# Separa a los jugadores en dos tandas: los 2 primeros (1 y 2) y los otros 2
# (3 y 4). Los que no estan en partida (eliminados o inexistentes) no aparecen.
static func agrupar(activos: Array) -> Array:
	var por_numero := {}
	for jugador in activos:
		por_numero[jugador.player_number] = jugador
	var grupo_a: Array = []
	var grupo_b: Array = []
	for numero in [1, 2]:
		if por_numero.has(numero):
			grupo_a.append(por_numero[numero])
	for numero in [3, 4]:
		if por_numero.has(numero):
			grupo_b.append(por_numero[numero])
	var grupos: Array = []
	if not grupo_a.is_empty():
		grupos.append(grupo_a)
	if not grupo_b.is_empty():
		grupos.append(grupo_b)
	return grupos


func _construir_grupos() -> Array:
	return agrupar(RunManager.jugadores())


func _ejecutar_fases() -> void:
	if _grupos.is_empty():
		_cerrar.call_deferred()
		return
	for i in _grupos.size():
		if i > 0:
			await _transicion(_grupos[i])
		_mostrar_grupo(_grupos[i])
		_esperando_fase = true
		await fase_completa
	await get_tree().create_timer(0.35, true, false, true).timeout
	_cerrar()


func _mostrar_grupo(grupo: Array) -> void:
	for hijo in _contenedor.get_children():
		_contenedor.remove_child(hijo)
		hijo.queue_free()
	_cartas.clear()
	_opciones.clear()
	_indices.clear()
	_confirmados.clear()
	_status_labels.clear()
	_floating_tags.clear()
	_raw_menu_prev.clear()
	_raw_menu_cooldowns.clear()
	_jugadores = grupo
	_preparar_raw_menu_estado()

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
	_contenedor.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_contenedor, "modulate:a", 1.0, 0.3)


func _transicion(proximo_grupo: Array) -> void:
	_esperando_fase = false
	var nombres := PackedStringArray()
	for jugador in proximo_grupo:
		nombres.append(RunManager.nombre_jugador(jugador.player_number))
	_titulo.text = "TURNO DE %s" % " Y ".join(nombres).to_upper()
	var tween := create_tween()
	tween.tween_property(_contenedor, "modulate:a", 0.0, 0.25)
	await tween.finished
	await get_tree().create_timer(0.35, true, false, true).timeout



func _crear_panel(numero: int) -> void:
	var color_acento: Color = RunManager.color_jugador(numero)
	var color_fondo: Color = Color(color_acento.r * 0.12, color_acento.g * 0.12, color_acento.b * 0.12, 0.9)

	var panel_marco := PanelContainer.new()
	panel_marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_marco.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = color_fondo
	sb.border_color = Color(color_acento.r, color_acento.g, color_acento.b, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_top = 12
	sb.content_margin_right = 12
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
	var total_vidas: int = clampi(RunManager.vidas_por_ronda, 1, 20)
	var max_nivel: int = RunManager.nivel_desbloqueado(numero)
	var corazones := ""
	for i in total_vidas:
		if i > 0 and i % 5 == 0:
			corazones += " "
		corazones += "♥" if i < vidas_count else "♡"
	var controles_hint: String = "Moverse para elegir · Disparar / Enter para confirmar" if Settings.es_teclado(numero) else "Moverse para elegir · X / Disparar para confirmar"

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
	fila.add_theme_constant_override("separation", 8)
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

	# Sección de Habilidades Actuales (Estilo Brotato)
	_crear_seccion_habilidades_actuales(v_box, numero, color_acento)


func _crear_seccion_habilidades_actuales(v_box: VBoxContainer, numero: int, color_acento: Color) -> void:
	var mejoras := RunManager.mejoras_de(numero)

	# Agrupar por id para mostrar cantidades apiladas (ej: x2, x3) estilo Brotato
	var agrupadas: Array[Dictionary] = []
	var mapa_pos: Dictionary = {}
	for def in mejoras:
		if def == null:
			continue
		if mapa_pos.has(def.id):
			var idx: int = mapa_pos[def.id]
			agrupadas[idx]["count"] += 1
		else:
			mapa_pos[def.id] = agrupadas.size()
			agrupadas.append({"def": def, "count": 1})

	var sep := HSeparator.new()
	sep.modulate = Color(color_acento.r, color_acento.g, color_acento.b, 0.30)
	v_box.add_child(sep)

	var contenedor_seccion := VBoxContainer.new()
	contenedor_seccion.add_theme_constant_override("separation", 6)
	v_box.add_child(contenedor_seccion)

	# Encabezado de la sección
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	contenedor_seccion.add_child(header)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "HABILIDADES ACTUALES (%d)" % mejoras.size()
	lbl_titulo.add_theme_font_size_override("font_size", 13)
	lbl_titulo.modulate = color_acento
	header.add_child(lbl_titulo)

	var lbl_detalle := Label.new()
	lbl_detalle.text = "  •  Pasa el cursor sobre un objeto para ver sus efectos" if not agrupadas.is_empty() else ""
	lbl_detalle.add_theme_font_size_override("font_size", 11)
	lbl_detalle.modulate = Color(0.75, 0.78, 0.85, 0.65)
	lbl_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_detalle)

	# Contenedor horizontal con scroll si excede
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 52)
	contenedor_seccion.add_child(scroll)

	var tray := HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_BEGIN
	tray.add_theme_constant_override("separation", 8)
	scroll.add_child(tray)

	if agrupadas.is_empty():
		var lbl_vacio := Label.new()
		lbl_vacio.text = "Sin habilidades previas (se acumularán aquí entre rondas)"
		lbl_vacio.add_theme_font_size_override("font_size", 11)
		lbl_vacio.modulate = Color(0.55, 0.58, 0.65, 0.55)
		tray.add_child(lbl_vacio)
		return

	# Etiqueta flotante con el nombre arriba del ícono
	var floating_tag := PanelContainer.new()
	floating_tag.visible = false
	floating_tag.top_level = true
	floating_tag.z_index = 100
	floating_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_sb := StyleBoxFlat.new()
	tag_sb.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	tag_sb.border_color = Color(1.0, 1.0, 1.0, 0.85)
	tag_sb.set_border_width_all(2)
	tag_sb.set_corner_radius_all(5)
	tag_sb.content_margin_left = 8
	tag_sb.content_margin_right = 8
	tag_sb.content_margin_top = 3
	tag_sb.content_margin_bottom = 3
	floating_tag.add_theme_stylebox_override("panel", tag_sb)

	var tag_lbl := Label.new()
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_lbl.add_theme_font_size_override("font_size", 12)
	floating_tag.add_child(tag_lbl)
	v_box.add_child(floating_tag)
	_floating_tags.append(floating_tag)

	var theme_script: Script = load("res://ui/card_theme_window.gd")

	for item in agrupadas:
		var def: UpgradeDefinition = item["def"]
		var count: int = item["count"]
		var col_rareza: Color = COLORES_RAREZA.get(def.rareza, Color(0.78, 0.82, 0.88))

		# Marco de la casilla estilo Brotato
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(46, 46)
		badge.mouse_filter = Control.MOUSE_FILTER_STOP

		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.04, 0.06, 0.09, 0.95)
		b_sb.border_color = Color(col_rareza.r, col_rareza.g, col_rareza.b, 0.85)
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(6)
		badge.add_theme_stylebox_override("panel", b_sb)

		# Margen interior (ignora ratón para no interceptar hover del badge)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 3)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_right", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		badge.add_child(margin)

		# Ventana temática animada en miniatura (ignora ratón para que el badge reciba hover)
		var theme_win: Control = theme_script.new()
		theme_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
		theme_win.custom_minimum_size = Vector2(38, 38)
		theme_win.set_tema(def.tema, col_rareza)
		margin.add_child(theme_win)

		# Etiqueta de cantidad (x2, x3) si está apilada
		if count > 1:
			var count_lbl := Label.new()
			count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count_lbl.text = "x%d" % count
			count_lbl.add_theme_font_size_override("font_size", 10)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count_lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
			badge.add_child(count_lbl)

		# Tooltip detallado
		var tooltip_lines: Array[String] = [
			"%s  [%s • %s]" % [def.titulo.to_upper(), def.nivel_texto().to_upper(), def.rareza_texto().to_upper()],
			def.subtitulo if not def.subtitulo.is_empty() else def.descripcion,
			""
		]
		for m in def.mecanicas:
			tooltip_lines.append("★  " + m)
		for v in def.ventajas:
			tooltip_lines.append("+  " + (v if v.begins_with("+") else "+ " + v))
		for d in def.desventajas:
			tooltip_lines.append("-  " + (d if d.begins_with("-") else "- " + d))
		badge.tooltip_text = "\n".join(tooltip_lines)

		# Eventos de hover para mostrar el nombre arriba del ícono y actualizar texto de detalle
		badge.mouse_entered.connect(func():
			lbl_detalle.text = "  •  %s: %s" % [def.titulo, def.subtitulo if not def.subtitulo.is_empty() else def.descripcion]
			lbl_detalle.modulate = col_rareza

			tag_lbl.text = "%s  (%s)" % [def.titulo.to_upper(), def.rareza_texto().to_upper()]
			tag_lbl.modulate = col_rareza
			tag_sb.border_color = col_rareza
			floating_tag.visible = true
			floating_tag.reset_size()
			var tag_x: float = badge.global_position.x + (badge.size.x * 0.5) - (floating_tag.size.x * 0.5)
			var tag_y: float = badge.global_position.y - floating_tag.size.y - 6.0

			# Evitar que la etiqueta flote fuera de la pantalla (especialmente para el jugador 1 a la izquierda)
			var vp_size := floating_tag.get_viewport_rect().size
			var margin_lat := 12.0
			var max_x := maxf(vp_size.x - floating_tag.size.x - margin_lat, margin_lat)
			tag_x = clampf(tag_x, margin_lat, max_x)
			if tag_y < 8.0:
				tag_y = badge.global_position.y + badge.size.y + 6.0

			floating_tag.global_position = Vector2(tag_x, tag_y)

			b_sb.border_color = Color(col_rareza.r, col_rareza.g, col_rareza.b, 1.0)
			b_sb.set_border_width_all(3)
		)
		badge.mouse_exited.connect(func():
			lbl_detalle.text = "  •  Pasa el cursor sobre un objeto para ver sus efectos"
			lbl_detalle.modulate = Color(0.75, 0.78, 0.85, 0.65)
			floating_tag.visible = false
			b_sb.border_color = Color(col_rareza.r, col_rareza.g, col_rareza.b, 0.85)
			b_sb.set_border_width_all(2)
		)

		tray.add_child(badge)


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


func _process(delta: float) -> void:
	if not _activo or not _esperando_fase:
		return
	for jugador in _jugadores:
		var numero: int = jugador.player_number
		if _confirmados.get(numero, false):
			continue
		var total: int = _opciones[numero].size()
		if total == 0:
			_confirmar(numero)
			continue
		if _procesar_raw_menu(numero, total, delta):
			continue
		var move_axis := Input.get_axis(_accion(numero, "left"), _accion(numero, "right"))
		var key_cd := "%d_stick" % numero
		var cd: float = maxf(float(_raw_menu_cooldowns.get(key_cd, 0.0)) - delta, 0.0)
		if absf(move_axis) < 0.35:
			_raw_menu_cooldowns[key_cd] = 0.0
		elif cd <= 0.0:
			_indices[numero] = wrapi(_indices[numero] + (1 if move_axis > 0.0 else -1), 0, total)
			_actualizar_seleccion()
			AudioManager.reproducir("ui_mover", 0.05)
			_raw_menu_cooldowns[key_cd] = RAW_MENU_REPEAT_DELAY
		elif _accion_just_pressed(numero, "left") and absf(move_axis) < 0.35:
			_indices[numero] = wrapi(_indices[numero] - 1, 0, total)
			_actualizar_seleccion()
			AudioManager.reproducir("ui_mover", 0.05)
		elif _accion_just_pressed(numero, "right") and absf(move_axis) < 0.35:
			_indices[numero] = wrapi(_indices[numero] + 1, 0, total)
			_actualizar_seleccion()
		var fire_pressed: bool = _accion_just_pressed(numero, "fire")
		var jump_pressed: bool = not Settings.es_teclado(numero) and _accion_just_pressed(numero, "jump")
		if fire_pressed or jump_pressed:
			_confirmar(numero)


func _unhandled_input(event: InputEvent) -> void:
	var p_teclado := Settings.primer_jugador_teclado()
	if not _activo or p_teclado <= 0 or _confirmados.get(p_teclado, false):
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_confirmar(p_teclado)


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
		_esperando_fase = false
		fase_completa.emit()


func _cerrar() -> void:
	_activo = false
	_esperando_fase = false
	visible = false
	for tag in _floating_tags:
		if is_instance_valid(tag):
			tag.visible = false
	for i in RunManager.cantidad_jugadores:
		Input.action_release("p%d_fire" % (i + 1))
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


func _accion_just_pressed(numero: int, nombre: String) -> bool:
	var slot := Settings.slot_teclado_de(numero)
	if slot >= 1 and slot <= 2 and KeyboardSetup.raw_input_activo():
		return KeyboardSetup.raw_action_just_pressed(slot, nombre)
	return Input.is_action_just_pressed(_accion(numero, nombre))


func _procesar_raw_menu(numero: int, total: int, delta: float) -> bool:
	var slot := Settings.slot_teclado_de(numero)
	if slot < 1 or slot > 2 or not KeyboardSetup.raw_input_activo():
		return false
	if _raw_menu_action(slot, "left", true, delta):
		_indices[numero] = wrapi(_indices[numero] - 1, 0, total)
		_actualizar_seleccion()
		AudioManager.reproducir("ui_mover", 0.05)
	if _raw_menu_action(slot, "right", true, delta):
		_indices[numero] = wrapi(_indices[numero] + 1, 0, total)
		_actualizar_seleccion()
		AudioManager.reproducir("ui_mover", 0.05)
	if _raw_menu_action(slot, "fire", false, delta):
		_confirmar(numero)
	return true


func _raw_menu_action(numero: int, nombre: String, repetir: bool, delta: float) -> bool:
	var key := "%d_%s" % [numero, nombre]
	var pressed := KeyboardSetup.raw_action_pressed(numero, nombre)
	var was_pressed := bool(_raw_menu_prev.get(key, false))
	_raw_menu_prev[key] = pressed
	if not pressed:
		_raw_menu_cooldowns[key] = 0.0
		return false
	if not repetir:
		return not was_pressed
	var cooldown := maxf(float(_raw_menu_cooldowns.get(key, 0.0)) - delta, 0.0)
	if not was_pressed or cooldown <= 0.0:
		_raw_menu_cooldowns[key] = RAW_MENU_REPEAT_DELAY
		return true
	_raw_menu_cooldowns[key] = cooldown
	return false


func _preparar_raw_menu_estado() -> void:
	if not KeyboardSetup.raw_input_activo():
		return
	for jugador in _jugadores:
		var numero: int = jugador.player_number
		var slot := Settings.slot_teclado_de(numero)
		if slot < 1 or slot > 2:
			continue
		for nombre in ["left", "right", "fire", "jump"]:
			var key := "%d_%s" % [slot, nombre]
			var pressed := KeyboardSetup.raw_action_pressed(slot, nombre)
			_raw_menu_prev[key] = pressed
			_raw_menu_cooldowns[key] = RAW_MENU_REPEAT_DELAY if pressed else 0.0
