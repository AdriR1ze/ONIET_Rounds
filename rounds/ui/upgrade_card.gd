extends PanelContainer

const COLORES_RAREZA := {
	UpgradeDefinition.Rareza.COMUN: Color(0.78, 0.82, 0.88),
	UpgradeDefinition.Rareza.RARA: Color(0.35, 0.8, 1.0),
	UpgradeDefinition.Rareza.EPICA: Color(0.82, 0.45, 1.0),
	UpgradeDefinition.Rareza.LEGENDARIA: Color(1.0, 0.78, 0.2),
}

const COLOR_MECANICA := Color(0.82, 0.48, 1.0)
const COLOR_VENTAJA := Color(0.3, 1.0, 0.45)
const COLOR_DESVENTAJA := Color(1.0, 0.35, 0.35)

var definicion: UpgradeDefinition = null

@onready var _titulo: Label = $Margin/VBox/Titulo
@onready var _ventana_tema: Control = $Margin/VBox/ThemeWindow
@onready var _subtitulo: Label = $Margin/VBox/Subtitulo
@onready var _lista_atributos: VBoxContainer = $Margin/VBox/Atributos
@onready var _rareza_tag: Label = $Margin/VBox/Footer/RarezaTag


func _ready() -> void:
	_ensure_nodes()
	pivot_offset = custom_minimum_size / 2.0


func _ensure_nodes() -> void:
	if _titulo == null:
		_titulo = get_node_or_null("Margin/VBox/Titulo")
	if _ventana_tema == null:
		_ventana_tema = get_node_or_null("Margin/VBox/ThemeWindow")
	if _subtitulo == null:
		_subtitulo = get_node_or_null("Margin/VBox/Subtitulo")
	if _lista_atributos == null:
		_lista_atributos = get_node_or_null("Margin/VBox/Atributos")
	if _rareza_tag == null:
		_rareza_tag = get_node_or_null("Margin/VBox/Footer/RarezaTag")


func configurar(def: UpgradeDefinition) -> void:
	definicion = def
	_ensure_nodes()
	if def == null:
		return

	var col_rareza: Color = COLORES_RAREZA.get(def.rareza, Color.WHITE)

	if _titulo != null:
		_titulo.text = def.titulo.to_upper()
		_titulo.modulate = col_rareza

	if _subtitulo != null:
		_subtitulo.text = def.subtitulo if not def.subtitulo.is_empty() else def.descripcion

	if _ventana_tema != null and _ventana_tema.has_method("set_tema"):
		_ventana_tema.set_tema(def.tema, col_rareza)

	if _rareza_tag != null:
		_rareza_tag.text = "%s • %s" % [def.nivel_texto().to_upper(), def.rareza_texto().to_upper()]
		_rareza_tag.modulate = col_rareza * 0.85

	# Limpiar lista anterior
	if _lista_atributos != null:
		for h in _lista_atributos.get_children():
			_lista_atributos.remove_child(h)
			h.queue_free()

	# 1. Mecánicas especiales (Violeta)
	for m in def.mecanicas:
		_agregar_linea("★  " + m, COLOR_MECANICA)

	# 2. Ventajas / Buffs (Verde)
	for v in def.ventajas:
		var texto := v if v.begins_with("+") else "+ " + v
		_agregar_linea(texto, COLOR_VENTAJA)

	# 3. Desventajas / Debuffs (Rojo)
	for d in def.desventajas:
		var texto := d if d.begins_with("-") else "- " + d
		_agregar_linea(texto, COLOR_DESVENTAJA)

	queue_redraw()


func _agregar_linea(texto: String, color: Color) -> void:
	if _lista_atributos == null:
		return
	var l := Label.new()
	l.text = texto
	l.modulate = color
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	_lista_atributos.add_child(l)


func marcar_seleccionada(seleccionada: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0) if seleccionada else Color(0.55, 0.58, 0.65, 0.85)
	scale = Vector2(1.04, 1.04) if seleccionada else Vector2(1.0, 1.0)


func _draw() -> void:
	var col_bracket := Color(0.25, 0.8, 1.0, 0.9)
	if definicion != null:
		col_bracket = COLORES_RAREZA.get(definicion.rareza, col_bracket)

	var arm := 14.0
	var thick := 2.5
	# Superior Izquierda
	draw_line(Vector2(2, 2), Vector2(2 + arm, 2), col_bracket, thick)
	draw_line(Vector2(2, 2), Vector2(2, 2 + arm), col_bracket, thick)
	# Superior Derecha
	draw_line(Vector2(size.x - 2, 2), Vector2(size.x - 2 - arm, 2), col_bracket, thick)
	draw_line(Vector2(size.x - 2, 2), Vector2(size.x - 2, 2 + arm), col_bracket, thick)
	# Inferior Izquierda
	draw_line(Vector2(2, size.y - 2), Vector2(2 + arm, size.y - 2), col_bracket, thick)
	draw_line(Vector2(2, size.y - 2), Vector2(2, size.y - 2 - arm), col_bracket, thick)
	# Inferior Derecha
	draw_line(Vector2(size.x - 2, size.y - 2), Vector2(size.x - 2 - arm, size.y - 2), col_bracket, thick)
	draw_line(Vector2(size.x - 2, size.y - 2), Vector2(size.x - 2, size.y - 2 - arm), col_bracket, thick)
