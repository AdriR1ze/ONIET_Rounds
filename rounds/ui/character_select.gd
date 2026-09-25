extends Control

const NumberPickerButton = preload("res://ui/number_picker_button.gd")
const FONT_PIXEL: FontFile = preload("res://Fuente_de_texto_pixel.ttf")

const PERSONAJES: Array[String] = ["esqueleto", "sapo", "pajaro", "fantasma"]
const ESCENA_JUEGO := "res://levels/test_level.tscn"
const ESCENA_MENU := "res://ui/main_menu.tscn"

const NOMBRES_PERSONAJES := {
	"esqueleto": "Esqueleto",
	"sapo": "Sapo",
	"pajaro": "Pájaro",
	"fantasma": "Fantasma",
}

const COLOR_APAGADO := Color(0.2, 0.22, 0.28, 1.0)
const COLOR_LISTO := Color(0.3, 0.9, 0.4, 1.0)

@onready var _btn_volver: Button = $Margin/VBox/TopBar/BotonVolver
@onready var _config_partida: HBoxContainer = $Margin/VBox/TopBar/ConfigPartida
@onready var _bottom_slots: HBoxContainer = $Margin/VBox/BottomSlots

var _numeros: Array = [1, 2, 3, 4]
var _choice: Dictionary = {}
var _listo: Dictionary = {}
var _slot_activo: Dictionary = {}
var _name_inputs: Dictionary = {}
var _disp_sel: Dictionary = {}
var _dif_sel: Dictionary = {}
var _dif_row: Dictionary = {}
var _ready_btn: Dictionary = {}
var _status_lbl: Dictionary = {}
var _pj_sprites: Dictionary = {}
var _pj_names: Dictionary = {}
var _slot_active_views: Dictionary = {}
var _slot_inactive_views: Dictionary = {}
var _nav_cooldowns: Dictionary = {}

var _rondas_picker: Button
var _vidas_picker: Button
var _jugador_enfocado: int = 1
var _editando_nombre_jugador: int = 0
var _iniciando: bool = false


func _ready() -> void:
	randomize()
	_btn_volver.focus_mode = Control.FOCUS_NONE
	_btn_volver.pressed.connect(_volver_al_menu)
	_btn_volver.mouse_entered.connect(func(): AudioManager.reproducir("ui_mover", 0.04))

	_inicializar_estados()
	_construir_top_config()
	_construir_bottom_slots()
	_actualizar_ui()


func _inicializar_estados() -> void:
	for n in _numeros:
		var activo_inicial: bool = RunManager.es_jugador_activo(n) if RunManager.slots_activos.size() > 0 else (n <= 2)
		_slot_activo[n] = activo_inicial

		if Settings.es_bot(n):
			_choice[n] = randi() % PERSONAJES.size()
			_listo[n] = true
		else:
			_choice[n] = 0
			_listo[n] = false


func _construir_top_config() -> void:
	for hijo in _config_partida.get_children():
		_config_partida.remove_child(hijo)
		hijo.queue_free()

	# Configuración de Rondas
	var rondas_box := HBoxContainer.new()
	rondas_box.add_theme_constant_override("separation", 8)
	rondas_box.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl_rondas := Label.new()
	lbl_rondas.text = "RONDAS:"
	lbl_rondas.add_theme_font_override("font", FONT_PIXEL)
	lbl_rondas.add_theme_font_size_override("font_size", 18)
	lbl_rondas.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	rondas_box.add_child(lbl_rondas)

	_rondas_picker = NumberPickerButton.new()
	_rondas_picker.min_value = 1
	_rondas_picker.max_value = 20
	_rondas_picker.value = RunManager.rondas_para_ganar
	_rondas_picker.add_theme_font_override("font", FONT_PIXEL)
	_rondas_picker.add_theme_font_size_override("font_size", 20)
	_rondas_picker.custom_minimum_size = Vector2(90, 44)
	_rondas_picker.valor_cambiado.connect(func(v: int) -> void:
		RunManager.rondas_para_ganar = v
	)
	rondas_box.add_child(_rondas_picker)
	_config_partida.add_child(rondas_box)

	# Separador visual
	var sep := VSeparator.new()
	sep.modulate.a = 0.4
	_config_partida.add_child(sep)

	# Configuración de Vidas
	var vidas_box := HBoxContainer.new()
	vidas_box.add_theme_constant_override("separation", 8)
	vidas_box.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl_vidas := Label.new()
	lbl_vidas.text = "VIDAS:"
	lbl_vidas.add_theme_font_override("font", FONT_PIXEL)
	lbl_vidas.add_theme_font_size_override("font_size", 18)
	lbl_vidas.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	vidas_box.add_child(lbl_vidas)

	_vidas_picker = NumberPickerButton.new()
	_vidas_picker.min_value = 1
	_vidas_picker.max_value = 20
	_vidas_picker.value = RunManager.vidas_por_ronda
	_vidas_picker.add_theme_font_override("font", FONT_PIXEL)
	_vidas_picker.add_theme_font_size_override("font_size", 20)
	_vidas_picker.custom_minimum_size = Vector2(90, 44)
	_vidas_picker.valor_cambiado.connect(func(v: int) -> void:
		RunManager.vidas_por_ronda = v
	)
	vidas_box.add_child(_vidas_picker)
	_config_partida.add_child(vidas_box)


func _construir_bottom_slots() -> void:
	for hijo in _bottom_slots.get_children():
		_bottom_slots.remove_child(hijo)
		hijo.queue_free()

	for n in _numeros:
		var slot_card := PanelContainer.new()
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_card.name = "SlotCard%d" % n

		var root_vbox := VBoxContainer.new()
		root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_card.add_child(root_vbox)

		# 1. Vista Inactiva
		var inactive_view := VBoxContainer.new()
		inactive_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inactive_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inactive_view.alignment = BoxContainer.ALIGNMENT_CENTER
		inactive_view.add_theme_constant_override("separation", 18)

		var lbl_inact := Label.new()
		lbl_inact.text = "JUGADOR %d\n[CERRADO]" % n
		lbl_inact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_inact.add_theme_font_override("font", FONT_PIXEL)
		lbl_inact.add_theme_font_size_override("font_size", 22)
		lbl_inact.add_theme_color_override("font_color", Color(0.52, 0.55, 0.65))
		inactive_view.add_child(lbl_inact)

		var btn_activar := Button.new()
		btn_activar.text = "+ ACTIVAR"
		btn_activar.add_theme_font_override("font", FONT_PIXEL)
		btn_activar.add_theme_font_size_override("font_size", 18)
		btn_activar.custom_minimum_size = Vector2(160, 48)
		btn_activar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_activar.focus_mode = Control.FOCUS_NONE
		btn_activar.pressed.connect(_toggle_slot_activo.bind(n))
		btn_activar.mouse_entered.connect(func(): AudioManager.reproducir("ui_mover", 0.04))
		inactive_view.add_child(btn_activar)

		root_vbox.add_child(inactive_view)
		_slot_inactive_views[n] = inactive_view

		# 2. Vista Activa
		var active_view := VBoxContainer.new()
		active_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		active_view.add_theme_constant_override("separation", 10)

		# Header del slot
		var header_hbox := HBoxContainer.new()
		header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var lbl_tag := Label.new()
		lbl_tag.text = "P%d" % n
		lbl_tag.add_theme_font_override("font", FONT_PIXEL)
		lbl_tag.add_theme_font_size_override("font_size", 24)
		lbl_tag.add_theme_color_override("font_color", RunManager.color_jugador(n))
		header_hbox.add_child(lbl_tag)

		var sp_hdr := Control.new()
		sp_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(sp_hdr)

		var btn_desactivar := Button.new()
		btn_desactivar.text = "✔ ACTIVO"
		btn_desactivar.add_theme_font_override("font", FONT_PIXEL)
		btn_desactivar.add_theme_font_size_override("font_size", 14)
		btn_desactivar.custom_minimum_size = Vector2(95, 32)
		btn_desactivar.focus_mode = Control.FOCUS_NONE
		btn_desactivar.pressed.connect(_toggle_slot_activo.bind(n))
		btn_desactivar.mouse_entered.connect(func(): AudioManager.reproducir("ui_mover", 0.04))
		header_hbox.add_child(btn_desactivar)
		active_view.add_child(header_hbox)

		# Selector de Dispositivo
		var disp_box := HBoxContainer.new()
		disp_box.alignment = BoxContainer.ALIGNMENT_CENTER
		disp_box.add_theme_constant_override("separation", 6)
		var lbl_disp := Label.new()
		lbl_disp.text = "Tipo:"
		lbl_disp.add_theme_font_override("font", FONT_PIXEL)
		lbl_disp.add_theme_font_size_override("font_size", 16)
		lbl_disp.add_theme_color_override("font_color", Color(0.72, 0.75, 0.85))
		disp_box.add_child(lbl_disp)

		var sel_disp := OptionButton.new()
		sel_disp.focus_mode = Control.FOCUS_NONE
		sel_disp.add_theme_font_override("font", FONT_PIXEL)
		sel_disp.add_theme_font_size_override("font_size", 16)
		sel_disp.custom_minimum_size = Vector2(0, 38)
		sel_disp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_disp.add_item("Teclado", 0)
		var conectados := Input.get_connected_joypads()
		for m in Settings.MAX_MANDOS:
			var txt := "Mando %d" % (m + 1)
			if conectados.has(m):
				txt += " (*)"
			sel_disp.add_item(txt, m + 1)
		sel_disp.add_item("Bot", 99)

		if Settings.es_bot(n):
			sel_disp.select(sel_disp.get_item_index(99))
		else:
			sel_disp.select(sel_disp.get_item_index(Settings.dispositivo_de(n) + 1))
		sel_disp.item_selected.connect(_on_dispositivo_seleccionado.bind(n))
		disp_box.add_child(sel_disp)
		active_view.add_child(disp_box)
		_disp_sel[n] = sel_disp

		# Dificultad del Bot (solo visible si es bot)
		var dif_box := HBoxContainer.new()
		dif_box.alignment = BoxContainer.ALIGNMENT_CENTER
		dif_box.add_theme_constant_override("separation", 6)
		var lbl_dif := Label.new()
		lbl_dif.text = "Dificultad:"
		lbl_dif.add_theme_font_override("font", FONT_PIXEL)
		lbl_dif.add_theme_font_size_override("font_size", 16)
		lbl_dif.add_theme_color_override("font_color", Color(0.72, 0.75, 0.85))
		dif_box.add_child(lbl_dif)

		var sel_dif := OptionButton.new()
		sel_dif.focus_mode = Control.FOCUS_NONE
		sel_dif.add_theme_font_override("font", FONT_PIXEL)
		sel_dif.add_theme_font_size_override("font_size", 16)
		sel_dif.custom_minimum_size = Vector2(0, 38)
		sel_dif.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for d_idx in RunManager.DIFICULTADES_BOT.size():
			sel_dif.add_item(RunManager.DIFICULTADES_BOT[d_idx], d_idx)
		sel_dif.selected = RunManager.dificultad_bot_de(n)
		sel_dif.item_selected.connect(_on_dificultad_seleccionada.bind(n))
		dif_box.add_child(sel_dif)
		active_view.add_child(dif_box)
		_dif_sel[n] = sel_dif
		_dif_row[n] = dif_box

		# Espaciador superior del carrusel
		var sp_mid_top := Control.new()
		sp_mid_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
		active_view.add_child(sp_mid_top)

		# Mini Carousel de Selección de Personaje
		var pj_box := HBoxContainer.new()
		pj_box.alignment = BoxContainer.ALIGNMENT_CENTER
		pj_box.add_theme_constant_override("separation", 12)

		var btn_prev := Button.new()
		btn_prev.text = "◀"
		btn_prev.add_theme_font_override("font", FONT_PIXEL)
		btn_prev.add_theme_font_size_override("font_size", 24)
		btn_prev.custom_minimum_size = Vector2(40, 48)
		btn_prev.focus_mode = Control.FOCUS_NONE
		btn_prev.pressed.connect(_mover_eleccion.bind(n, -1))
		btn_prev.mouse_entered.connect(func(): AudioManager.reproducir("ui_mover", 0.04))
		pj_box.add_child(btn_prev)

		var preview_ctrl := Control.new()
		preview_ctrl.custom_minimum_size = Vector2(100, 96)
		var spr := AnimatedSprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(3.8, 3.8)
		spr.position = Vector2(50, 48)
		preview_ctrl.add_child(spr)
		pj_box.add_child(preview_ctrl)
		_pj_sprites[n] = spr

		var btn_next := Button.new()
		btn_next.text = "▶"
		btn_next.add_theme_font_override("font", FONT_PIXEL)
		btn_next.add_theme_font_size_override("font_size", 24)
		btn_next.custom_minimum_size = Vector2(40, 48)
		btn_next.focus_mode = Control.FOCUS_NONE
		btn_next.pressed.connect(_mover_eleccion.bind(n, 1))
		btn_next.mouse_entered.connect(func(): AudioManager.reproducir("ui_mover", 0.04))
		pj_box.add_child(btn_next)
		active_view.add_child(pj_box)

		# Nombre del Personaje
		var lbl_pj_name := Label.new()
		lbl_pj_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_pj_name.add_theme_font_override("font", FONT_PIXEL)
		lbl_pj_name.add_theme_font_size_override("font_size", 22)
		lbl_pj_name.add_theme_color_override("font_color", RunManager.color_jugador(n))
		active_view.add_child(lbl_pj_name)
		_pj_names[n] = lbl_pj_name

		# Espaciador inferior del carrusel
		var sp_mid_bot := Control.new()
		sp_mid_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		active_view.add_child(sp_mid_bot)

		# Botón ¡LISTO!
		var btn_listo := Button.new()
		btn_listo.custom_minimum_size = Vector2(160, 46)
		btn_listo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_listo.focus_mode = Control.FOCUS_NONE
		btn_listo.add_theme_font_override("font", FONT_PIXEL)
		btn_listo.add_theme_font_size_override("font_size", 20)
		btn_listo.pressed.connect(_toggle_ready.bind(n))
		btn_listo.mouse_entered.connect(func(): AudioManager.reproducir("ui_mover", 0.04))
		active_view.add_child(btn_listo)
		_ready_btn[n] = btn_listo

		# Status
		var lbl_status := Label.new()
		lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_status.add_theme_font_override("font", FONT_PIXEL)
		lbl_status.add_theme_font_size_override("font_size", 14)
		lbl_status.custom_minimum_size = Vector2(140, 26)
		active_view.add_child(lbl_status)
		_status_lbl[n] = lbl_status

		# Campo de Texto para el Nombre
		var name_box := HBoxContainer.new()
		name_box.alignment = BoxContainer.ALIGNMENT_CENTER
		name_box.add_theme_constant_override("separation", 6)
		var lbl_nom := Label.new()
		lbl_nom.text = "Nombre:"
		lbl_nom.add_theme_font_override("font", FONT_PIXEL)
		lbl_nom.add_theme_font_size_override("font_size", 16)
		lbl_nom.add_theme_color_override("font_color", Color(0.72, 0.75, 0.85))
		name_box.add_child(lbl_nom)

		var input_nom := LineEdit.new()
		input_nom.text = RunManager.nombre_jugador(n)
		input_nom.placeholder_text = "Jugador %d" % n
		input_nom.max_length = 15
		input_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input_nom.custom_minimum_size = Vector2(0, 38)
		input_nom.add_theme_font_override("font", FONT_PIXEL)
		input_nom.add_theme_font_size_override("font_size", 16)
		input_nom.text_changed.connect(func(txt: String):
			RunManager.set_nombre(n, txt)
		)
		input_nom.focus_entered.connect(func():
			_jugador_enfocado = n
			_editando_nombre_jugador = n
			_actualizar_ui()
		)
		input_nom.focus_exited.connect(func():
			if _editando_nombre_jugador == n:
				_editando_nombre_jugador = 0
				_actualizar_ui()
		)
		input_nom.text_submitted.connect(func(txt: String):
			RunManager.set_nombre(n, txt)
			_editando_nombre_jugador = 0
			input_nom.release_focus()
			AudioManager.reproducir("salto", 0.05)
			_actualizar_ui()
			_comprobar_inicio_automatico()
		)
		name_box.add_child(input_nom)
		active_view.add_child(name_box)
		_name_inputs[n] = input_nom

		root_vbox.add_child(active_view)
		_slot_active_views[n] = active_view

		_bottom_slots.add_child(slot_card)


func _esta_escribiendo_nombre() -> bool:
	if _editando_nombre_jugador > 0:
		return true
	for n in _name_inputs:
		var input: LineEdit = _name_inputs[n]
		if is_instance_valid(input) and input.has_focus():
			return true
	return false


func _toggle_slot_activo(numero: int) -> void:
	if _esta_escribiendo_nombre():
		return
	var actual: bool = _slot_activo.get(numero, false)
	_slot_activo[numero] = not actual
	if _slot_activo[numero]:
		AudioManager.reproducir("salto", 0.05)
		if Settings.es_bot(numero):
			_listo[numero] = true
		else:
			_listo[numero] = false
		_jugador_enfocado = numero
	else:
		AudioManager.reproducir("ui_mover", 0.05)
		_listo[numero] = false
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _on_dispositivo_seleccionado(indice: int, numero: int) -> void:
	if _esta_escribiendo_nombre():
		return
	var selector: OptionButton = _disp_sel[numero]
	var id := selector.get_item_id(indice)
	if id == 99:
		Settings.set_dispositivo(numero, Settings.DISPOSITIVO_BOT)
		_choice[numero] = randi() % PERSONAJES.size()
		_listo[numero] = true
	else:
		var prev_bot: bool = Settings.es_bot(numero)
		Settings.set_dispositivo(numero, id - 1)
		if prev_bot:
			_listo[numero] = false
	_jugador_enfocado = numero
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _on_dificultad_seleccionada(indice: int, numero: int) -> void:
	if _esta_escribiendo_nombre():
		return
	var selector: OptionButton = _dif_sel[numero]
	var dif := selector.get_item_id(indice)
	RunManager.set_dificultad_bot_de(numero, dif)
	_actualizar_ui()


func _mover_eleccion(numero: int, direccion: int) -> void:
	if _esta_escribiendo_nombre():
		return
	_choice[numero] = posmod(int(_choice[numero]) + direccion, PERSONAJES.size())
	_jugador_enfocado = numero
	AudioManager.reproducir("ui_mover", 0.05)
	_actualizar_ui()


func _toggle_ready(numero: int) -> void:
	if not _slot_activo.get(numero, false):
		return
	if _editando_nombre_jugador == numero:
		if _name_inputs.has(numero) and is_instance_valid(_name_inputs[numero]):
			_name_inputs[numero].release_focus()
		_editando_nombre_jugador = 0
		AudioManager.reproducir("salto", 0.05)
		_actualizar_ui()
		_comprobar_inicio_automatico()
		return
	if _esta_escribiendo_nombre():
		return
	if Settings.es_bot(numero):
		_mover_eleccion(numero, 1)
		return
	_listo[numero] = not _listo.get(numero, false)
	_jugador_enfocado = numero
	AudioManager.reproducir("salto", 0.05)
	_actualizar_ui()
	_comprobar_inicio_automatico()


func _actualizar_ui() -> void:
	# Actualizar Bottom Slots
	for n in _numeros:
		var activo: bool = _slot_activo.get(n, false)
		var card: PanelContainer = _bottom_slots.get_node_or_null("SlotCard%d" % n)
		if card != null:
			card.add_theme_stylebox_override("panel", _estilo_slot(RunManager.color_jugador(n), activo))

		if _slot_active_views.has(n):
			_slot_active_views[n].visible = activo
		if _slot_inactive_views.has(n):
			_slot_inactive_views[n].visible = not activo

		if activo:
			var pj: String = PERSONAJES[_choice.get(n, 0)]
			var spr: AnimatedSprite2D = _pj_sprites[n]
			var frames := RunManager.obtener_sprite_frames(pj, n)
			spr.sprite_frames = frames
			spr.animation = &"walk"
			spr.play()

			var lbl_pj: Label = _pj_names[n]
			lbl_pj.text = NOMBRES_PERSONAJES[pj].to_upper()

			var es_bot := Settings.es_bot(n)
			if _dif_row.has(n):
				_dif_row[n].visible = es_bot

			var btn: Button = _ready_btn[n]
			var status: Label = _status_lbl[n]

			if _editando_nombre_jugador == n:
				btn.text = "CONFIRMAR"
				status.text = "Presioná ENTER para confirmar"
				status.modulate = Color(1.0, 0.85, 0.25, 1.0)
			elif es_bot:
				btn.text = "CAMBIAR BOT"
				status.text = "BOT (%s) • ¡LISTO!" % RunManager.dificultad_bot_nombre_de(n).to_upper()
				status.modulate = Color(0.35, 0.8, 1.0, 1.0)
			elif _listo.get(n, false):
				btn.text = "CANCELAR"
				status.text = "¡LISTO PARA COMBATIR!"
				status.modulate = COLOR_LISTO
			else:
				btn.text = "¡LISTO!"
				if Settings.es_teclado(n):
					status.text = "WASD • Dispará/Enter"
				else:
					status.text = "Mando • Dispará/A"
				status.modulate = Color(0.7, 0.7, 0.7, 1.0)


func _obtener_slots_activos() -> Array:
	var lista: Array = []
	for n in _numeros:
		if _slot_activo.get(n, false):
			lista.append(n)
	return lista


func _todos_listos() -> bool:
	if _esta_escribiendo_nombre():
		return false
	var activos := _obtener_slots_activos()
	if activos.size() < 2:
		return false
	for n in activos:
		if not _listo.get(n, false):
			return false
	return true


func _comprobar_inicio_automatico() -> void:
	if not _todos_listos():
		return
	await get_tree().create_timer(0.5).timeout
	if _todos_listos() and is_inside_tree() and not _iniciando:
		_iniciar_partida()


func _iniciar_partida() -> void:
	if _esta_escribiendo_nombre():
		return
	var activos := _obtener_slots_activos()
	if activos.size() < 2:
		return
	_iniciando = true
	AudioManager.reproducir("salto", 0.05)

	# 1. Configurar partidas y slots
	RunManager.configurar_partida(int(_rondas_picker.value), int(_vidas_picker.value))
	RunManager.set_slots_activos(activos)

	# 2. Asignar personajes y nombres
	for n in activos:
		var eleccion: int = _choice.get(n, 0)
		RunManager.set_personaje(n, PERSONAJES[eleccion])
		if _name_inputs.has(n) and is_instance_valid(_name_inputs[n]):
			RunManager.set_nombre(n, _name_inputs[n].text)

	RunManager.reiniciar()

	if is_instance_valid(Transition) and Transition.has_method("cambiar_escena"):
		Transition.cambiar_escena(ESCENA_JUEGO)
	else:
		get_tree().change_scene_to_file(ESCENA_JUEGO)


func _volver_al_menu() -> void:
	if is_instance_valid(Transition) and Transition.has_method("cambiar_escena"):
		Transition.cambiar_escena(ESCENA_MENU)
	else:
		get_tree().change_scene_to_file(ESCENA_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if _esta_escribiendo_nombre():
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			if _name_inputs.has(_editando_nombre_jugador) and is_instance_valid(_name_inputs[_editando_nombre_jugador]):
				_name_inputs[_editando_nombre_jugador].release_focus()
			_editando_nombre_jugador = 0
			get_viewport().set_input_as_handled()
			_actualizar_ui()
		return

	if event.is_action_pressed("ui_cancel"):
		_volver_al_menu()
	elif event is InputEventKey and event.pressed and not event.echo:
		var p_teclado := Settings.primer_jugador_teclado()
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE) and p_teclado > 0:
			if _slot_activo.get(p_teclado, false):
				_toggle_ready(p_teclado)


func _process(delta: float) -> void:
	if _esta_escribiendo_nombre():
		return
	for numero in _numeros:
		if not _slot_activo.get(numero, false):
			continue
		if Settings.es_bot(numero):
			continue

		if _usa_raw_keyboard(numero):
			var slot := Settings.slot_teclado_de(numero)
			if not _listo.get(numero, false):
				if KeyboardSetup.raw_action_just_pressed(slot, "left"):
					_mover_eleccion(numero, -1)
				elif KeyboardSetup.raw_action_just_pressed(slot, "right"):
					_mover_eleccion(numero, 1)
			if KeyboardSetup.raw_action_just_pressed(slot, "fire"):
				_toggle_ready(numero)
			continue

		# Jugadores de mando o teclado estándar
		if not _listo.get(numero, false):
			var mx := Input.get_axis("p%d_left" % numero, "p%d_right" % numero)
			var cd: float = maxf(float(_nav_cooldowns.get(numero, 0.0)) - delta, 0.0)
			if absf(mx) < 0.35:
				_nav_cooldowns[numero] = 0.0
			elif cd <= 0.0:
				_mover_eleccion(numero, 1 if mx > 0.0 else -1)
				_nav_cooldowns[numero] = 0.22

		var fire_pressed: bool = Input.is_action_just_pressed("p%d_fire" % numero)
		var jump_pressed: bool = not Settings.es_teclado(numero) and Input.is_action_just_pressed("p%d_jump" % numero)
		if fire_pressed or jump_pressed:
			_toggle_ready(numero)


func _usa_raw_keyboard(numero: int) -> bool:
	var slot := Settings.slot_teclado_de(numero)
	return slot >= 1 and slot <= 2 and KeyboardSetup.raw_input_activo()


func _estilo_slot(color: Color, activo: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.95) if activo else Color(0.04, 0.05, 0.07, 0.75)
	sb.set_border_width_all(2 if activo else 1)
	sb.border_color = color if activo else Color(0.25, 0.28, 0.35, 0.5)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb
