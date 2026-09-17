extends Node

const RUTA := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]
const JUGADORES := [1, 2]
const SUFIJOS := ["left", "right", "up", "down", "jump", "strafe", "ragdoll", "grab", "fire", "quack"]
const ETIQUETAS := {
	"left": "Izquierda",
	"right": "Derecha",
	"up": "Arriba",
	"down": "Abajo",
	"jump": "Saltar",
	"strafe": "Strafe",
	"ragdoll": "Trompezar",
	"grab": "Agarrar",
	"fire": "Disparar",
	"quack": "Graznar",
}
const DEFAULT_JOY := {
	"left": {"t": "joy_axis", "axis": 0, "value": -1.0},
	"right": {"t": "joy_axis", "axis": 0, "value": 1.0},
	"up": {"t": "joy_axis", "axis": 1, "value": -1.0},
	"down": {"t": "joy_axis", "axis": 1, "value": 1.0},
	"jump": {"t": "joy_button", "button": 0},
	"fire": {"t": "joy_button", "button": 2},
	"grab": {"t": "joy_button", "button": 3},
	"strafe": {"t": "joy_button", "button": 10},
	"ragdoll": {"t": "joy_button", "button": 4},
	"quack": {"t": "joy_button", "button": 5},
}
const ACCIONES_PROTEGIDAS := ["pause", "ui_cancel"]

enum ModoPantalla {
	PANTALLA_COMPLETA,
	VENTANA_SIN_BORDES,
	EN_VENTANA,
}

signal video_cambiado

var volumenes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
var pantalla_completa := false
var modo_pantalla: int = ModoPantalla.EN_VENTANA
var resolucion_actual: Vector2i = Vector2i(1280, 720)

var _defaults: Dictionary = {}
var _remaps: Dictionary = {}


func _ready() -> void:
	_crear_buses()
	_asegurar_acciones_globales()
	_capturar_defaults()
	cargar()
	aplicar_todo()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11 or event.keycode == KEY_F11:
			toggle_pantalla_completa()
			get_viewport().set_input_as_handled()


func _asegurar_acciones_globales() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", escape)
	var start := InputEventJoypadButton.new()
	start.device = -1
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", start)


func _crear_buses() -> void:
	for nombre in BUSES:
		if AudioServer.get_bus_index(nombre) != -1:
			continue
		var indice := AudioServer.bus_count
		AudioServer.add_bus(indice)
		AudioServer.set_bus_name(indice, nombre)
		if nombre != "Master":
			AudioServer.set_bus_send(indice, "Master")


func _capturar_defaults() -> void:
	for accion in InputMap.get_actions():
		var eventos: Array = []
		for evento in InputMap.action_get_events(accion):
			var d := _evento_a_dict(evento)
			if not d.is_empty():
				eventos.append(d)
		if not eventos.is_empty():
			_defaults[accion] = eventos


func resoluciones_disponibles() -> Array[Vector2i]:
	var lista: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]
	var scr := DisplayServer.screen_get_size()
	if scr.x >= 640 and scr.y >= 360 and not lista.has(scr):
		lista.append(scr)
		lista.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a.x * a.y) < (b.x * b.y)
		)
	return lista


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	for nombre in BUSES:
		volumenes[nombre] = float(cfg.get_value("audio", nombre, 1.0))
	pantalla_completa = bool(cfg.get_value("video", "fullscreen", false))
	modo_pantalla = int(cfg.get_value("video", "window_mode", ModoPantalla.PANTALLA_COMPLETA if pantalla_completa else ModoPantalla.EN_VENTANA))
	var rw: int = int(cfg.get_value("video", "resolution_w", 1280))
	var rh: int = int(cfg.get_value("video", "resolution_h", 720))
	resolucion_actual = Vector2i(rw, rh)
	_remaps = cfg.get_value("input", "remaps", {})


func guardar() -> void:
	var cfg := ConfigFile.new()
	for nombre in BUSES:
		cfg.set_value("audio", nombre, volumenes[nombre])
	cfg.set_value("video", "fullscreen", pantalla_completa)
	cfg.set_value("video", "window_mode", modo_pantalla)
	cfg.set_value("video", "resolution_w", resolucion_actual.x)
	cfg.set_value("video", "resolution_h", resolucion_actual.y)
	cfg.set_value("input", "remaps", _remaps)
	cfg.save(RUTA)


func aplicar_todo() -> void:
	for nombre in BUSES:
		set_volumen(nombre, volumenes[nombre])
	aplicar_pantalla()
	aplicar_controles()


func set_volumen(bus: String, valor: float) -> void:
	volumenes[bus] = clampf(valor, 0.0, 1.0)
	var indice := AudioServer.get_bus_index(bus)
	if indice == -1:
		return
	AudioServer.set_bus_mute(indice, volumenes[bus] <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(volumenes[bus], 0.001)))


func set_pantalla_completa(activo: bool) -> void:
	set_modo_pantalla(ModoPantalla.PANTALLA_COMPLETA if activo else ModoPantalla.EN_VENTANA)


func set_modo_pantalla(modo: int) -> void:
	modo_pantalla = clampi(modo, 0, 2)
	pantalla_completa = (modo_pantalla == ModoPantalla.PANTALLA_COMPLETA)
	aplicar_pantalla()
	guardar()
	video_cambiado.emit()


func set_resolucion(res: Vector2i) -> void:
	if res.x < 640 or res.y < 360:
		return
	resolucion_actual = res
	aplicar_pantalla()
	guardar()
	video_cambiado.emit()


func es_ventana_incrustada() -> bool:
	var win := get_window()
	return win != null and win.has_method("is_embedded") and win.is_embedded()


func toggle_pantalla_completa() -> void:
	if es_ventana_incrustada():
		print("AVISO: El juego está incrustado en el editor de Godot (Game Embed Mode). Para pantalla completa, desactiva 'Embed Game' en la barra del editor.")
		return
	if modo_pantalla == ModoPantalla.PANTALLA_COMPLETA:
		set_modo_pantalla(ModoPantalla.EN_VENTANA)
	else:
		set_modo_pantalla(ModoPantalla.PANTALLA_COMPLETA)


func aplicar_pantalla() -> void:
	if es_ventana_incrustada():
		# Dentro del editor en modo incrustado, la ventana es un control secundario del editor
		return
	match modo_pantalla:
		ModoPantalla.PANTALLA_COMPLETA:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		ModoPantalla.VENTANA_SIN_BORDES:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(resolucion_actual)
			_centrar_ventana()
		ModoPantalla.EN_VENTANA:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolucion_actual)
			_centrar_ventana()


func _centrar_ventana() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen)
	var win_size := DisplayServer.window_get_size()
	if screen_rect.size.x > 0 and screen_rect.size.y > 0 and win_size.x > 0 and win_size.y > 0:
		var pos := screen_rect.position + (screen_rect.size - win_size) / 2
		DisplayServer.window_set_position(pos)


func aplicar_controles() -> void:
	for jugador in JUGADORES:
		for sufijo in SUFIJOS:
			var accion := "p%d_%s" % [jugador, sufijo]
			if not InputMap.has_action(accion):
				InputMap.add_action(accion)
			InputMap.action_erase_events(accion)
			if _remaps.has(accion):
				_agregar_evento(accion, _remaps[accion])
				continue
			for d in _defaults.get(accion, []):
				_agregar_evento(accion, d)
			var jd: Dictionary = DEFAULT_JOY.get(sufijo, {})
			if not jd.is_empty():
				var con_device := jd.duplicate()
				con_device["device"] = jugador - 1
				_agregar_evento(accion, con_device)


func binding_de(accion: String) -> Dictionary:
	if _remaps.has(accion):
		return _remaps[accion]
	var eventos := InputMap.action_get_events(accion)
	if not eventos.is_empty():
		return _evento_a_dict(eventos[0])
	return {}


func evento_de_dict(d: Dictionary) -> InputEvent:
	return _dict_a_evento(d)


func set_binding(accion: String, evento: InputEvent) -> bool:
	var d := _evento_a_dict(evento)
	if d.is_empty():
		return false
	if not conflicto(accion, evento).is_empty():
		return false
	_remaps[accion] = d
	_aplicar_accion(accion, d)
	guardar()
	return true


func conflicto(accion: String, evento: InputEvent) -> String:
	var candidato := _evento_a_dict(evento)
	if candidato.is_empty():
		return ""
	for otra in _acciones_vigiladas():
		if otra == accion:
			continue
		for existente in InputMap.action_get_events(otra):
			if _dicts_chocan(candidato, _evento_a_dict(existente)):
				return otra
	return ""


func etiqueta_accion(accion: String) -> String:
	if accion == "pause":
		return "Pausa"
	if accion == "ui_cancel":
		return "Cancelar / Atrás"
	if accion.begins_with("p") and accion.contains("_"):
		var partes := accion.split("_", false, 1)
		if partes.size() == 2:
			return "Jugador %s · %s" % [partes[0].substr(1), ETIQUETAS.get(partes[1], partes[1])]
	return accion


func _acciones_vigiladas() -> Array:
	var lista: Array = []
	for jugador in JUGADORES:
		for sufijo in SUFIJOS:
			lista.append("p%d_%s" % [jugador, sufijo])
	for global in ACCIONES_PROTEGIDAS:
		if InputMap.has_action(global):
			lista.append(global)
	return lista


func _dicts_chocan(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var ta := String(a.get("t", ""))
	if ta != String(b.get("t", "")):
		return false
	match ta:
		"key":
			return (
				int(a.get("code", 0)) == int(b.get("code", 0))
				and bool(a.get("ctrl", false)) == bool(b.get("ctrl", false))
				and bool(a.get("alt", false)) == bool(b.get("alt", false))
				and bool(a.get("shift", false)) == bool(b.get("shift", false))
			)
		"joy_button":
			return _mismo_device(a, b) and int(a.get("button", 0)) == int(b.get("button", 0))
		"joy_axis":
			return (
				_mismo_device(a, b)
				and int(a.get("axis", 0)) == int(b.get("axis", 0))
				and signf(float(a.get("value", 1.0))) == signf(float(b.get("value", 1.0)))
			)
		"mouse_button":
			return int(a.get("button", 0)) == int(b.get("button", 0))
	return false


func _mismo_device(a: Dictionary, b: Dictionary) -> bool:
	var da := int(a.get("device", -1))
	var db := int(b.get("device", -1))
	return da == db or da == -1 or db == -1


func reset_controles() -> void:
	_remaps.clear()
	guardar()
	aplicar_controles()


func nombre_binding(d: Dictionary) -> String:
	match String(d.get("t", "")):
		"key":
			var code := int(d.get("code", 0))
			var texto := OS.get_keycode_string(code)
			if bool(d.get("ctrl", false)):
				texto = "Ctrl+" + texto
			if bool(d.get("alt", false)):
				texto = "Alt+" + texto
			if bool(d.get("shift", false)):
				texto = "Shift+" + texto
			return texto
		"joy_button":
			return "Pad %d · Botón %d" % [int(d.get("device", 0)) + 1, int(d.get("button", 0))]
		"joy_axis":
			var signo := "+" if float(d.get("value", 1.0)) >= 0.0 else "-"
			return "Pad %d · Eje %d %s" % [int(d.get("device", 0)) + 1, int(d.get("axis", 0)), signo]
		"mouse_button":
			return "Mouse %d" % int(d.get("button", 1))
	return "—"


func _aplicar_accion(accion: String, d: Dictionary) -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion)
	InputMap.action_erase_events(accion)
	_agregar_evento(accion, d)


func _agregar_evento(accion: String, d: Dictionary) -> void:
	var evento := _dict_a_evento(d)
	if evento != null:
		InputMap.action_add_event(accion, evento)


func _evento_a_dict(evento: InputEvent) -> Dictionary:
	if evento is InputEventKey:
		var code: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
		return {
			"t": "key",
			"code": code,
			"ctrl": evento.ctrl_pressed,
			"alt": evento.alt_pressed,
			"shift": evento.shift_pressed,
		}
	if evento is InputEventJoypadButton:
		return {"t": "joy_button", "device": evento.device, "button": evento.button_index}
	if evento is InputEventJoypadMotion:
		return {
			"t": "joy_axis",
			"device": evento.device,
			"axis": evento.axis,
			"value": 1.0 if evento.axis_value >= 0.0 else -1.0,
		}
	if evento is InputEventMouseButton:
		return {"t": "mouse_button", "button": evento.button_index}
	return {}


func _dict_a_evento(d: Dictionary) -> InputEvent:
	match String(d.get("t", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(d.get("code", 0))
			key.ctrl_pressed = bool(d.get("ctrl", false))
			key.alt_pressed = bool(d.get("alt", false))
			key.shift_pressed = bool(d.get("shift", false))
			return key
		"joy_button":
			var boton := InputEventJoypadButton.new()
			boton.device = int(d.get("device", 0))
			boton.button_index = int(d.get("button", 0))
			return boton
		"joy_axis":
			var eje := InputEventJoypadMotion.new()
			eje.device = int(d.get("device", 0))
			eje.axis = int(d.get("axis", 0))
			eje.axis_value = float(d.get("value", 1.0))
			return eje
		"mouse_button":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(d.get("button", 1))
			return mouse
	return null
