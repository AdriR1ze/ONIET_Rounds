extends CanvasLayer

const COLOR_EMPTY := Color(0.1, 0.12, 0.16, 0.55)
const COLOR_EMPTY_BORDER := Color(0.28, 0.32, 0.4, 0.4)

@onready var _ronda: Label = $CenterBadge/HBox/Ronda
@onready var _marcador: Label = $CenterBadge/HBox/Marcador

const TEXTURAS_CORAZONES: Dictionary = {
	"esqueleto": {
		"lleno": preload("res://sprite_sheets/personajes/esqueleto/Corazones_esqueleto_lleno.png"),
		"vacio": preload("res://sprite_sheets/personajes/esqueleto/Corazones_esqueleto_vacio.png"),
	},
	"sapo": {
		"lleno": preload("res://sprite_sheets/personajes/sapo/Corazones_sapo_lleno.png"),
		"vacio": preload("res://sprite_sheets/personajes/sapo/Corazones__sapo_vacio.png"),
	},
	"pajaro": {
		"lleno": preload("res://sprite_sheets/personajes/pajaro/Corazones_pajaro_lleno.png"),
		"vacio": preload("res://sprite_sheets/personajes/pajaro/Corazones_pajaro_vacio.png"),
	},
	"fantasma": {
		"lleno": preload("res://sprite_sheets/personajes/fantasma/corazon_fantasma_lleno.png"),
		"vacio": preload("res://sprite_sheets/personajes/fantasma/corazon_fantasma_vacio.png"),
	},
}

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

	var total_base: int = RunManager.vidas_por_ronda
	if total_base <= 0:
		total_base = 5

	var puntajes: Array = []
	for i in RunManager.cantidad_jugadores:
		var numero := i + 1
		var izquierda := numero % 2 == 1
		if _nombres.has(numero):
			_nombres[numero].text = RunManager.nombre_jugador(numero)
		if _vidas.has(numero):
			# Cada jugador muestra sus propias vidas: si una vida extra supera el
			# tope inicial, se agrega un corazón lleno (no uno vacío de otro jugador).
			var vidas_actuales := RunManager.vidas_de(numero)
			_actualizar_vidas_container(_vidas[numero], vidas_actuales, maxi(total_base, vidas_actuales), numero, izquierda)
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
			var pip := TextureRect.new()
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			fila.add_child(pip)

		while fila.get_child_count() > coras_en_esta_fila:
			var extra := fila.get_child(fila.get_child_count() - 1)
			fila.remove_child(extra)
			extra.queue_free()

		var personaje: String = RunManager.personaje_de(player_num)
		var texturas: Dictionary = RunManager.obtener_texturas_corazon(personaje, player_num)
		if texturas.is_empty():
			texturas = TEXTURAS_CORAZONES.get(personaje, TEXTURAS_CORAZONES["esqueleto"])
		var tam_pip := Vector2(22.0 * escala, 22.0 * escala)

		for c in coras_en_esta_fila:
			var pip := fila.get_child(c) as TextureRect
			if pip.custom_minimum_size != tam_pip:
				pip.custom_minimum_size = tam_pip

			var activa := (pip_idx < vidas_actuales)
			var tex: Texture2D = texturas["lleno"] if activa else texturas["vacio"]
			if pip.texture != tex:
				pip.texture = tex

			pip_idx += 1
