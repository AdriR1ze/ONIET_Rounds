extends CanvasLayer

signal cerrado

const COLOR_OK := Color(0.16, 0.5, 0.26)
const COLOR_ERROR := Color(0.85, 0.2, 0.2)

@onready var _master: HSlider = $Centro/Marco/Margin/VBox/AudioGrid/Master
@onready var _music: HSlider = $Centro/Marco/Margin/VBox/AudioGrid/Music
@onready var _sfx: HSlider = $Centro/Marco/Margin/VBox/AudioGrid/Sfx
@onready var _pantalla: CheckButton = $Centro/Marco/Margin/VBox/PantallaCompleta
@onready var _aviso: Label = $Centro/Marco/Margin/VBox/Aviso
@onready var _controles: VBoxContainer = $Centro/Marco/Margin/VBox/Scroll/Controles
@onready var _boton_guardar: Button = $Centro/Marco/Margin/VBox/Botones/Guardar
@onready var _boton_restablecer: Button = $Centro/Marco/Margin/VBox/Botones/Restablecer
@onready var _boton_volver: Button = $Centro/Marco/Margin/VBox/Botones/Volver

var _escuchando: String = ""
var _pendientes: Dictionary = {}
var _botones: Dictionary = {}


func _ready() -> void:
	visible = false
	_master.value_changed.connect(func(valor: float) -> void: Settings.set_volumen("Master", valor))
	_music.value_changed.connect(func(valor: float) -> void: Settings.set_volumen("Music", valor))
	_sfx.value_changed.connect(func(valor: float) -> void: Settings.set_volumen("SFX", valor))
	_pantalla.toggled.connect(Settings.set_pantalla_completa)
	_boton_guardar.pressed.connect(_guardar)
	_boton_restablecer.pressed.connect(_restablecer)
	_boton_volver.pressed.connect(cerrar)
	_construir_controles()


func abrir() -> void:
	visible = true
	_escuchando = ""
	_pendientes.clear()
	_aviso.text = ""
	_master.set_value_no_signal(Settings.volumenes["Master"])
	_music.set_value_no_signal(Settings.volumenes["Music"])
	_sfx.set_value_no_signal(Settings.volumenes["SFX"])
	_pantalla.set_pressed_no_signal(Settings.pantalla_completa)
	_actualizar_botones()
	_boton_volver.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	_escuchando = ""
	_pendientes.clear()
	visible = false
	cerrado.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if _escuchando.is_empty():
			cerrar()
		else:
			_pendientes.erase(_escuchando)
			_escuchando = ""
			_aviso.text = ""
			_actualizar_botones()
		get_viewport().set_input_as_handled()
		return
	if _escuchando.is_empty() or not _es_valido(event):
		return
	var d := Settings._evento_a_dict(event)
	if d.is_empty():
		return
	var accion := _escuchando
	_pendientes[accion] = d
	var choque := _conflicto(accion, d)
	if choque.is_empty():
		_aviso.text = "Cambio pendiente — usá Guardar para aplicarlo"
	else:
		_aviso.text = "Choca con %s — no se puede guardar" % Settings.etiqueta_accion(choque)
	_escuchando = ""
	_actualizar_botones()
	get_viewport().set_input_as_handled()


func _es_valido(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= 0.5
	if event is InputEventMouseButton:
		return event.pressed
	return false


func _construir_controles() -> void:
	for hijo in _controles.get_children():
		_controles.remove_child(hijo)
		hijo.queue_free()
	_botones.clear()
	for jugador in Settings.JUGADORES:
		var cabecera := Label.new()
		cabecera.text = "Jugador %d" % jugador
		cabecera.add_theme_font_size_override("font_size", 18)
		_controles.add_child(cabecera)
		for sufijo in Settings.SUFIJOS:
			var accion := "p%d_%s" % [jugador, sufijo]
			var fila := HBoxContainer.new()
			var etiqueta := Label.new()
			etiqueta.text = Settings.ETIQUETAS.get(sufijo, sufijo)
			etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(etiqueta)
			var boton := Button.new()
			boton.custom_minimum_size = Vector2(190, 0)
			boton.pressed.connect(_empezar_escucha.bind(accion))
			fila.add_child(boton)
			_controles.add_child(fila)
			_botones[accion] = boton
	_actualizar_botones()


func _empezar_escucha(accion: String) -> void:
	call_deferred("_activar_escucha", accion)


func _activar_escucha(accion: String) -> void:
	if not visible:
		return
	_escuchando = accion
	_aviso.text = ""
	_actualizar_botones()


func _actualizar_botones() -> void:
	var errores := _acciones_en_error()
	for accion in _botones:
		var boton: Button = _botones[accion]
		if _pendientes.has(accion):
			boton.text = Settings.nombre_binding(_pendientes[accion])
		elif accion == _escuchando:
			boton.text = "Presioná una tecla…"
		else:
			boton.text = Settings.nombre_binding(Settings.binding_de(accion))
		_pintar_boton(boton, COLOR_ERROR if errores.has(accion) else COLOR_OK)


func _pintar_boton(boton: Button, color: Color) -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(color.r, color.g, color.b, 0.16)
	caja.border_color = color
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(4)
	caja.content_margin_left = 10.0
	caja.content_margin_right = 10.0
	caja.content_margin_top = 5.0
	caja.content_margin_bottom = 5.0
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		boton.add_theme_stylebox_override(estado, caja)


func _guardar() -> void:
	if not _acciones_en_error().is_empty():
		_aviso.text = "No se puede guardar: hay controles en conflicto"
		return
	if _pendientes.is_empty():
		_aviso.text = "No hay cambios para guardar"
		return
	for accion in _pendientes:
		Settings.set_binding(accion, Settings.evento_de_dict(_pendientes[accion]))
	_pendientes.clear()
	_escuchando = ""
	_aviso.text = "Controles guardados"
	_actualizar_botones()


func _restablecer() -> void:
	Settings.reset_controles()
	_escuchando = ""
	_pendientes.clear()
	_aviso.text = "Controles restablecidos"
	_actualizar_botones()


func _eventos_efectivos(accion: String) -> Array:
	if _pendientes.has(accion):
		return [_pendientes[accion]]
	var lista: Array = []
	for evento in InputMap.action_get_events(accion):
		lista.append(Settings._evento_a_dict(evento))
	return lista


func _conflicto(accion: String, candidato: Dictionary) -> String:
	for otra in Settings._acciones_vigiladas():
		if otra == accion:
			continue
		for d in _eventos_efectivos(otra):
			if Settings._dicts_chocan(candidato, d):
				return otra
	return ""


func _acciones_en_error() -> Dictionary:
	var errores: Dictionary = {}
	for accion in _pendientes:
		for otra in Settings._acciones_vigiladas():
			if otra == accion:
				continue
			for d in _eventos_efectivos(otra):
				if Settings._dicts_chocan(_pendientes[accion], d):
					errores[accion] = true
					errores[otra] = true
	return errores
