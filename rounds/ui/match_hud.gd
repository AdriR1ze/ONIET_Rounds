extends CanvasLayer

const COLOR_EMPTY := Color(0.1, 0.12, 0.16, 0.55)
const COLOR_EMPTY_BORDER := Color(0.28, 0.32, 0.4, 0.4)

@onready var _ronda: Label = $CenterBadge/HBox/Ronda
@onready var _marcador: Label = $CenterBadge/HBox/Marcador

# Puntos del corazon estilizado (18x20)
const HEART_POINTS := [
	Vector2(9.0, 4.5),
	Vector2(6.5, 1.5),
	Vector2(2.5, 2.0),
	Vector2(0.5, 5.5),
	Vector2(1.5, 9.5),
	Vector2(9.0, 18.0),
	Vector2(16.5, 9.5),
	Vector2(17.5, 5.5),
	Vector2(15.5, 2.0),
	Vector2(11.5, 1.5),
	Vector2(9.0, 4.5)
]

var _nombres: Dictionary = {}
var _vidas: Dictionary = {}


func _ready() -> void:
	_construir_esquinas()
	_actualizar_hud()
	if RunManager.has_signal("vidas_cambiadas"):
		RunManager.vidas_cambiadas.connect(_actualizar_hud)
	if RunManager.has_signal("marcador_cambiado"):
		RunManager.marcador_cambiado.connect(_actualizar_hud)
	if RunManager.has_signal("ronda_iniciada"):
		RunManager.ronda_iniciada.connect(func(_r): _actualizar_hud())


func _process(_delta: float) -> void:
	_actualizar_hud()


func _construir_esquinas() -> void:
	for hijo in get_children():
		if hijo is MarginContainer:
			remove_child(hijo)
			hijo.queue_free()
	_nombres.clear()
	_vidas.clear()
	for i in RunManager.cantidad_jugadores:
		var numero := i + 1
		var esquina := _crear_esquina(numero)
		add_child(esquina)


func _crear_esquina(numero: int) -> MarginContainer:
	var color := RunManager.color_jugador(numero)
	var izquierda := numero % 2 == 1
	var arriba := numero <= 2

	var esquina := MarginContainer.new()
	if arriba:
		esquina.set_anchors_preset(Control.PRESET_TOP_LEFT if izquierda else Control.PRESET_TOP_RIGHT)
	else:
		esquina.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if izquierda else Control.PRESET_BOTTOM_RIGHT)
	if izquierda:
		esquina.offset_left = 32.0
		esquina.offset_right = 260.0
	else:
		esquina.offset_left = -292.0
		esquina.offset_right = -32.0
	if arriba:
		esquina.offset_top = 22.0
		esquina.offset_bottom = 80.0
	else:
		esquina.offset_top = -80.0
		esquina.offset_bottom = -22.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var nombre := Label.new()
	nombre.add_theme_font_size_override("font_size", 18)
	nombre.add_theme_color_override("font_color", color)
	nombre.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	nombre.add_theme_constant_override("shadow_offset_x", 1)
	nombre.add_theme_constant_override("shadow_offset_y", 1)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if izquierda else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(nombre)
	_nombres[numero] = nombre

	var vidas := HBoxContainer.new()
	vidas.add_theme_constant_override("separation", 8)
	vidas.alignment = BoxContainer.ALIGNMENT_BEGIN if izquierda else BoxContainer.ALIGNMENT_END
	vbox.add_child(vidas)
	_vidas[numero] = vidas

	esquina.add_child(vbox)
	return esquina


func _actualizar_hud() -> void:
	if _ronda != null:
		_ronda.text = "RONDA %d" % maxi(RunManager.ronda, 1)

	var total_vidas: int = RunManager.vidas_por_ronda
	if total_vidas <= 0:
		total_vidas = 5

	var puntajes: Array = []
	for i in RunManager.cantidad_jugadores:
		var numero := i + 1
		if _nombres.has(numero):
			_nombres[numero].text = RunManager.nombre_jugador(numero)
		if _vidas.has(numero):
			_actualizar_vidas_container(_vidas[numero], RunManager.vidas_de(numero), total_vidas, numero)
		puntajes.append(str(RunManager.marcador_de(numero)))
	if _marcador != null:
		_marcador.text = "  -  ".join(puntajes)


func _actualizar_vidas_container(contenedor: HBoxContainer, vidas_actuales: int, total: int, player_num: int) -> void:
	if contenedor == null:
		return

	while contenedor.get_child_count() < total:
		var pip := Control.new()
		pip.custom_minimum_size = Vector2(18, 20)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.draw.connect(_dibujar_pip.bind(pip))
		contenedor.add_child(pip)

	while contenedor.get_child_count() > total:
		var extra := contenedor.get_child(contenedor.get_child_count() - 1)
		contenedor.remove_child(extra)
		extra.queue_free()

	for i in total:
		var pip := contenedor.get_child(i) as Control
		var activa := (i < vidas_actuales)
		var necesita_update := false
		if not pip.has_meta("activa") or pip.get_meta("activa") != activa:
			pip.set_meta("activa", activa)
			necesita_update = true
		if not pip.has_meta("player") or pip.get_meta("player") != player_num:
			pip.set_meta("player", player_num)
			necesita_update = true
		if necesita_update:
			pip.queue_redraw()


func _dibujar_pip(pip: Control) -> void:
	var activa: bool = pip.get_meta("activa") if pip.has_meta("activa") else true
	var player_num: int = pip.get_meta("player") if pip.has_meta("player") else 1

	var pts := PackedVector2Array(HEART_POINTS)

	if activa:
		var col_base := RunManager.color_jugador(player_num)
		var col_glow := Color(col_base.r, col_base.g, col_base.b, 0.4)

		pip.draw_colored_polygon(pts, col_glow)
		pip.draw_colored_polygon(pts, col_base)
		pip.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.75), 1.2, true)
		pip.draw_circle(Vector2(5.5, 4.5), 1.2, Color(1.0, 1.0, 1.0, 0.85))
	else:
		pip.draw_colored_polygon(pts, COLOR_EMPTY)
		pip.draw_polyline(pts, COLOR_EMPTY_BORDER, 1.0, true)
