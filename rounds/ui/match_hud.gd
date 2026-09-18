extends CanvasLayer

const COLOR_P1 := Color(1.0, 0.85, 0.2, 1.0) # Amarillo Jugador 1
const COLOR_P1_GLOW := Color(1.0, 0.9, 0.3, 0.4)
const COLOR_P2 := Color(0.35, 0.78, 1.0, 1.0) # Azul/Cyan Jugador 2
const COLOR_P2_GLOW := Color(0.4, 0.85, 1.0, 0.4)

const COLOR_EMPTY := Color(0.1, 0.12, 0.16, 0.55)
const COLOR_EMPTY_BORDER := Color(0.28, 0.32, 0.4, 0.4)

@onready var _ronda: Label = $CenterBadge/HBox/Ronda
@onready var _marcador: Label = $CenterBadge/HBox/Marcador
@onready var _p1_nombre: Label = $P1Corner/VBox/P1Name
@onready var _p1_vidas: HBoxContainer = $P1Corner/VBox/P1Lives
@onready var _p2_nombre: Label = $P2Corner/VBox/P2Name
@onready var _p2_vidas: HBoxContainer = $P2Corner/VBox/P2Lives

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


func _ready() -> void:
	_actualizar_hud()
	if RunManager.has_signal("vidas_cambiadas"):
		RunManager.vidas_cambiadas.connect(_actualizar_hud)
	if RunManager.has_signal("marcador_cambiado"):
		RunManager.marcador_cambiado.connect(_actualizar_hud)
	if RunManager.has_signal("ronda_iniciada"):
		RunManager.ronda_iniciada.connect(func(_r): _actualizar_hud())


func _process(_delta: float) -> void:
	_actualizar_hud()


func _actualizar_hud() -> void:
	if _ronda != null:
		_ronda.text = "RONDA %d" % maxi(RunManager.ronda, 1)

	var p1_score: int = RunManager.marcador_de(1)
	var p2_score: int = RunManager.marcador_de(2)
	if _marcador != null:
		_marcador.text = "%d  -  %d" % [p1_score, p2_score]

	var n1 := RunManager.nombre_jugador(1)
	var n2 := RunManager.nombre_jugador(2)
	if _p1_nombre != null:
		_p1_nombre.text = n1
	if _p2_nombre != null:
		_p2_nombre.text = n2

	var v1: int = RunManager.vidas_de(1)
	var v2: int = RunManager.vidas_de(2)
	var total_vidas: int = RunManager.vidas_por_ronda
	if total_vidas <= 0:
		total_vidas = 5

	_actualizar_vidas_container(_p1_vidas, v1, total_vidas, 1)
	_actualizar_vidas_container(_p2_vidas, v2, total_vidas, 2)


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
		var col_base := COLOR_P1 if player_num == 1 else COLOR_P2
		var col_glow := COLOR_P1_GLOW if player_num == 1 else COLOR_P2_GLOW

		# Resplandor sutil
		pip.draw_colored_polygon(pts, col_glow)
		# Relleno principal
		pip.draw_colored_polygon(pts, col_base)
		# Borde luminoso
		pip.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.75), 1.2, true)
		# Brillo interior
		pip.draw_circle(Vector2(5.5, 4.5), 1.2, Color(1.0, 1.0, 1.0, 0.85))
	else:
		# Vida perdida: ranura oscura translucida
		pip.draw_colored_polygon(pts, COLOR_EMPTY)
		pip.draw_polyline(pts, COLOR_EMPTY_BORDER, 1.0, true)
