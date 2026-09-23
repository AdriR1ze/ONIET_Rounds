class_name NumberPickerButton
extends Button

signal valor_cambiado(nuevo_valor: int)

@export var min_value: int = 1
@export var max_value: int = 99
@export var value: int = 1:
	set(v):
		var clamped_v := clampi(v, min_value, max_value)
		if value != clamped_v or text.is_empty():
			value = clamped_v
			_actualizar_texto()
			valor_cambiado.emit(value)

var editando: bool = false:
	set(e):
		if editando != e:
			editando = e
			_actualizar_texto()


func _ready() -> void:
	custom_minimum_size = Vector2(90, 0)
	focus_mode = Control.FOCUS_ALL
	_actualizar_texto()
	focus_exited.connect(_on_focus_exited)


func _on_focus_exited() -> void:
	if editando:
		editando = false


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		editando = not editando
		if editando:
			AudioManager.reproducir("ui_mover", 0.05)
		else:
			AudioManager.reproducir("salto", 0.05)
		accept_event()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			editando = not editando
			if editando:
				AudioManager.reproducir("ui_mover", 0.05)
			else:
				AudioManager.reproducir("salto", 0.05)
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var previo := value
			value += 1
			if value != previo:
				AudioManager.reproducir("ui_mover", 0.05)
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var previo := value
			value -= 1
			if value != previo:
				AudioManager.reproducir("ui_mover", 0.05)
			accept_event()
			return

	if not editando:
		return

	if event.is_action_pressed("ui_cancel"):
		editando = false
		AudioManager.reproducir("salto", 0.05)
		accept_event()
		return

	var delta := 0
	var es_arriba: bool = event.is_action_pressed("ui_up", true)
	var es_abajo: bool = event.is_action_pressed("ui_down", true)
	var es_derecha: bool = event.is_action_pressed("ui_right", true)
	var es_izquierda: bool = event.is_action_pressed("ui_left", true)
	if event is InputEventKey and event.pressed:
		var k: Key = (event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != 0 else (event as InputEventKey).keycode
		if k == KEY_W:
			es_arriba = true
		elif k == KEY_S:
			es_abajo = true
		elif k == KEY_D:
			es_derecha = true
		elif k == KEY_A:
			es_izquierda = true

	if es_arriba or es_derecha:
		delta = 1
	elif es_abajo or es_izquierda:
		delta = -1

	if delta != 0:
		var previo := value
		value += delta
		if value != previo:
			AudioManager.reproducir("ui_mover", 0.05)
		accept_event()


func _actualizar_texto() -> void:
	if editando:
		text = "▲  %d  ▼" % value
		add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
		add_theme_color_override("font_focus_color", Color(0.25, 0.95, 1.0))
		add_theme_color_override("font_hover_color", Color(0.25, 0.95, 1.0))
		add_theme_color_override("font_pressed_color", Color(0.25, 0.95, 1.0))
	else:
		text = "%d" % value
		remove_theme_color_override("font_color")
		remove_theme_color_override("font_focus_color")
		remove_theme_color_override("font_hover_color")
		remove_theme_color_override("font_pressed_color")
