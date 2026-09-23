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


const MAX_CORAS_POR_FILA := 5


func _crear_esquina(numero: int) -> MarginContainer:
	var color := RunManager.color_jugador(numero)
	var izquierda := numero % 2 == 1
	var arriba := numero <= 2

	var esquina := MarginContainer.new()
	if arriba:
		esquina.set_anchors_preset(Control.PRESET_TOP_LEFT if izquierda else Control.PRESET_TOP_RIGHT)
		esquina.offset_top = 18.0
		esquina.offset_bottom = 125.0
	else:
		esquina.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if izquierda else Control.PRESET_BOTTOM_RIGHT)
		esquina.offset_top = -125.0
		esquina.offset_bottom = -18.0

	if izquierda:
		esquina.offset_left = 28.0
		esquina.offset_right = 260.0
	else:
		esquina.offset_left = -260.0
		esquina.offset_right = -28.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var nombre := Label.new()
	nombre.add_theme_font_size_override("font_size", 18)
	nombre.add_theme_color_override("font_color", color)
	nombre.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	nombre.add_theme_constant_override("shadow_offset_x", 1)
	nombre.add_theme_constant_override("shadow_offset_y", 1)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if izquierda else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(nombre)
	_nombres[numero] = nombre

	var vidas := VBoxContainer.new()
	vidas.add_theme_constant_override("separation", 3)
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
		var izquierda := numero % 2 == 1
		if _nombres.has(numero):
			_nombres[numero].text = RunManager.nombre_jugador(numero)
		if _vidas.has(numero):
			_actualizar_vidas_container(_vidas[numero], RunManager.vidas_de(numero), total_vidas, numero, izquierda)
		puntajes.append(str(RunManager.marcador_de(numero)))
	if _marcador != null:
		_marcador.text = "  -  ".join(puntajes)


func _actualizar_vidas_container(contenedor: VBoxContainer, vidas_actuales: int, total: int, player_num: int, izquierda: bool) -> void:
	if contenedor == null:
		return

	total = clampi(total, 1, RunManager.MAX_VIDAS)
	var filas_count := ceili(float(total) / float(MAX_CORAS_POR_FILA))

	# Si hay muchas filas de corazones, se hacen más chicos para no molestar la vista
	var escala := 1.0
	var sep_h := 6
	var sep_v := 4
	if filas_count == 2:
		escala = 0.85
		sep_h = 5
		sep_v = 3
	elif filas_count == 3:
		escala = 0.72
		sep_h = 4
		sep_v = 3
	elif filas_count >= 4:
		escala = 0.60
		sep_h = 4
		sep_v = 2

	contenedor.add_theme_constant_override("separation", sep_v)

	while contenedor.get_child_count() < filas_count:
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_BEGIN if izquierda else BoxContainer.ALIGNMENT_END
		contenedor.add_child(fila)

	while contenedor.get_child_count() > filas_count:
		var extra := contenedor.get_child(contenedor.get_child_count() - 1)
		contenedor.remove_child(extra)
		extra.queue_free()

	var pip_idx := 0
	for r in filas_count:
		var fila := contenedor.get_child(r) as HBoxContainer
		fila.alignment = BoxContainer.ALIGNMENT_BEGIN if izquierda else BoxContainer.ALIGNMENT_END
		fila.add_theme_constant_override("separation", sep_h)

		var coras_en_esta_fila := mini(MAX_CORAS_POR_FILA, total - (r * MAX_CORAS_POR_FILA))

		while fila.get_child_count() < coras_en_esta_fila:
			var pip := Control.new()
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.draw.connect(_dibujar_pip.bind(pip))
			fila.add_child(pip)

		while fila.get_child_count() > coras_en_esta_fila:
			var extra := fila.get_child(fila.get_child_count() - 1)
			fila.remove_child(extra)
			extra.queue_free()

		for c in coras_en_esta_fila:
			var pip := fila.get_child(c) as Control
			pip.custom_minimum_size = Vector2(18.0 * escala, 20.0 * escala)
			var activa := (pip_idx < vidas_actuales)
			var necesita_update := false

			if not pip.has_meta("activa") or pip.get_meta("activa") != activa:
				pip.set_meta("activa", activa)
				necesita_update = true
			if not pip.has_meta("player") or pip.get_meta("player") != player_num:
				pip.set_meta("player", player_num)
				necesita_update = true
			if not pip.has_meta("escala") or not is_equal_approx(float(pip.get_meta("escala")), escala):
				pip.set_meta("escala", escala)
				necesita_update = true

			if necesita_update:
				pip.queue_redraw()

			pip_idx += 1


func _dibujar_pip(pip: Control) -> void:
	var activa: bool = pip.get_meta("activa") if pip.has_meta("activa") else true
	var player_num: int = pip.get_meta("player") if pip.has_meta("player") else 1
	var escala: float = pip.get_meta("escala") if pip.has_meta("escala") else 1.0

	var pts := PackedVector2Array()
	for pt in HEART_POINTS:
		pts.append(pt * escala)

	if activa:
		var col_base := RunManager.color_jugador(player_num)
		var col_glow := Color(col_base.r, col_base.g, col_base.b, 0.4)

		pip.draw_colored_polygon(pts, col_glow)
		pip.draw_colored_polygon(pts, col_base)
		pip.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.75), maxf(1.2 * escala, 0.8), true)
		pip.draw_circle(Vector2(5.5, 4.5) * escala, maxf(1.2 * escala, 0.7), Color(1.0, 1.0, 1.0, 0.85))
	else:
		pip.draw_colored_polygon(pts, COLOR_EMPTY)
		pip.draw_polyline(pts, COLOR_EMPTY_BORDER, maxf(1.0 * escala, 0.8), true)
