extends CanvasLayer

signal cerrado

enum Tab { HABILIDADES, MAPAS }

const COLORES_RAREZA := {
	UpgradeDefinition.Rareza.COMUN: Color(0.78, 0.8, 0.86),
	UpgradeDefinition.Rareza.RARA: Color(0.4, 0.7, 1.0),
	UpgradeDefinition.Rareza.EPICA: Color(0.78, 0.45, 1.0),
	UpgradeDefinition.Rareza.LEGENDARIA: Color(1.0, 0.75, 0.2),
}

@onready var _tab_habilidades: Button = $Centro/Marco/Margin/VBox/Pestanas/TabHabilidades
@onready var _tab_mapas: Button = $Centro/Marco/Margin/VBox/Pestanas/TabMapas
@onready var _titulo: Label = $Centro/Marco/Margin/VBox/Header/Titulo
@onready var _lista: VBoxContainer = $Centro/Marco/Margin/VBox/Scroll/Lista
@onready var _contador: Label = $Centro/Marco/Margin/VBox/Header/Contador
@onready var _boton_activar_todas: Button = $Centro/Marco/Margin/VBox/Header/BotonesRapidos/ActivarTodas
@onready var _boton_desactivar_todas: Button = $Centro/Marco/Margin/VBox/Header/BotonesRapidos/DesactivarTodas
@onready var _boton_volver: Button = $Centro/Marco/Margin/VBox/Volver

var _tab_actual: Tab = Tab.HABILIDADES
var _checkboxes: Dictionary = {}


func _ready() -> void:
	visible = false
	_boton_volver.pressed.connect(_on_volver)
	_boton_activar_todas.pressed.connect(_on_activar_todas)
	_boton_desactivar_todas.pressed.connect(_on_desactivar_todas)
	_tab_habilidades.pressed.connect(func(): _cambiar_tab(Tab.HABILIDADES))
	_tab_mapas.pressed.connect(func(): _cambiar_tab(Tab.MAPAS))


func abrir() -> void:
	visible = true
	_cambiar_tab(Tab.HABILIDADES)
	_boton_volver.grab_focus()


func cerrar() -> void:
	visible = false
	cerrado.emit()


func _cambiar_tab(nuevo_tab: Tab) -> void:
	_tab_actual = nuevo_tab
	_actualizar_estilo_tabs()
	_construir_lista()
	_actualizar_contador()


func _actualizar_estilo_tabs() -> void:
	if _tab_actual == Tab.HABILIDADES:
		_titulo.text = "Índice de Habilidades"
		_tab_habilidades.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_tab_mapas.modulate = Color(0.65, 0.7, 0.8, 0.7)
		_boton_activar_todas.text = "Activar Todas"
		_boton_desactivar_todas.text = "Desactivar Todas"
	else:
		_titulo.text = "Índice de Mapas"
		_tab_habilidades.modulate = Color(0.65, 0.7, 0.8, 0.7)
		_tab_mapas.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_boton_activar_todas.text = "Activar Todos"
		_boton_desactivar_todas.text = "Desactivar Todos"


func _on_volver() -> void:
	cerrar()


func _on_activar_todas() -> void:
	if _tab_actual == Tab.HABILIDADES:
		UpgradeDatabase.activar_todas()
		for id in _checkboxes:
			var cb: CheckBox = _checkboxes[id]
			cb.button_pressed = true
	else:
		MapManager.activar_todos()
		for id in _checkboxes:
			var cb: CheckBox = _checkboxes[id]
			cb.button_pressed = true
	_actualizar_contador()


func _on_desactivar_todas() -> void:
	if _tab_actual == Tab.HABILIDADES:
		UpgradeDatabase.desactivar_todas()
		for id in _checkboxes:
			var cb: CheckBox = _checkboxes[id]
			cb.button_pressed = false
	else:
		MapManager.desactivar_todos()
		for id in _checkboxes:
			var cb: CheckBox = _checkboxes[id]
			cb.button_pressed = MapManager.is_activo(id)
	_actualizar_contador()


func _actualizar_contador() -> void:
	if _tab_actual == Tab.HABILIDADES:
		var total := UpgradeDatabase.definiciones.size()
		var activas := UpgradeDatabase.total_activas()
		_contador.text = "%d de %d habilidades activas" % [activas, total]
	else:
		var total := MapManager.obtener_mapas().size()
		var activos := MapManager.total_activos()
		_contador.text = "%d de %d mapas activos (minimo 1)" % [activos, total]


func _construir_lista() -> void:
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	_checkboxes.clear()

	if _tab_actual == Tab.HABILIDADES:
		_construir_lista_habilidades()
	else:
		_construir_lista_mapas()


func _construir_lista_habilidades() -> void:
	var lista_ordenada: Array[UpgradeDefinition] = []
	for d in UpgradeDatabase.definiciones:
		lista_ordenada.append(d)

	lista_ordenada.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool:
		if a.nivel != b.nivel:
			return a.nivel < b.nivel
		return a.titulo < b.titulo
	)

	for def in lista_ordenada:
		var item := _crear_item_mejora(def)
		_lista.add_child(item)


func _construir_lista_mapas() -> void:
	for mapa in MapManager.obtener_mapas():
		var item := _crear_item_mapa(mapa)
		_lista.add_child(item)


func _crear_item_mapa(mapa: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var col_neon: Color = mapa.get("color", Color.WHITE)

	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	var icon_rect := ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.color = Color(0.08, 0.09, 0.14, 0.9)
	var outline := ReferenceRect.new()
	outline.custom_minimum_size = Vector2(44, 44)
	outline.border_color = col_neon
	outline.border_width = 2.0
	outline.editor_only = false
	icon_box.add_child(icon_rect)
	icon_box.add_child(outline)
	var icon_lbl := Label.new()
	icon_lbl.text = "MAP"
	icon_lbl.add_theme_font_size_override("font_size", 12)
	icon_lbl.modulate = col_neon
	icon_box.add_child(icon_lbl)
	hbox.add_child(icon_box)

	var vbox_texto := VBoxContainer.new()
	vbox_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_texto.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox_texto)

	var header_item := HBoxContainer.new()
	header_item.add_theme_constant_override("separation", 10)
	vbox_texto.add_child(header_item)

	var titulo := Label.new()
	titulo.text = mapa.get("nombre", "Mapa")
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.modulate = col_neon
	header_item.add_child(titulo)

	var badge := Label.new()
	badge.text = "[ %s ]" % str(mapa.get("tipo", "NORMAL")).to_upper()
	badge.add_theme_font_size_override("font_size", 13)
	badge.modulate = col_neon.lerp(Color.WHITE, 0.3)
	header_item.add_child(badge)

	var desc := Label.new()
	desc.text = mapa.get("descripcion", "")
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(0.85, 0.88, 0.94, 0.85)
	vbox_texto.add_child(desc)

	var cb := CheckBox.new()
	cb.text = "Activo"
	var id: StringName = mapa["id"]
	cb.button_pressed = MapManager.is_activo(id)
	cb.toggled.connect(func(activa: bool) -> void:
		MapManager.set_activo(id, activa)
		cb.button_pressed = MapManager.is_activo(id)
		_actualizar_contador()
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0) if cb.button_pressed else Color(0.55, 0.55, 0.6, 0.6)
	)
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0) if cb.button_pressed else Color(0.55, 0.55, 0.6, 0.6)
	hbox.add_child(cb)

	_checkboxes[id] = cb
	return panel


func _crear_item_mejora(def: UpgradeDefinition) -> PanelContainer:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var vbox_texto := VBoxContainer.new()
	vbox_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_texto.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox_texto)

	var color_rareza: Color = COLORES_RAREZA.get(def.rareza, Color.WHITE)

	# Fila de Titulo y Rareza
	var header_item := HBoxContainer.new()
	header_item.add_theme_constant_override("separation", 10)
	vbox_texto.add_child(header_item)

	var titulo := Label.new()
	titulo.text = def.titulo
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.modulate = color_rareza
	header_item.add_child(titulo)

	var badge := Label.new()
	badge.text = "[%s • %s]" % [def.nivel_texto(), def.rareza_texto().to_upper()]
	badge.add_theme_font_size_override("font_size", 13)
	badge.modulate = color_rareza.lerp(Color.WHITE, 0.3)
	header_item.add_child(badge)

	if not def.subtitulo.is_empty():
		var sub := Label.new()
		sub.text = def.subtitulo
		sub.add_theme_font_size_override("font_size", 14)
		sub.modulate = Color(0.9, 0.92, 0.98, 0.85)
		vbox_texto.add_child(sub)

	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	vbox_texto.add_child(stats_box)

	for m in def.mecanicas:
		var lm := Label.new()
		lm.text = "★  " + m
		lm.modulate = Color(0.82, 0.48, 1.0)
		lm.add_theme_font_size_override("font_size", 12)
		stats_box.add_child(lm)

	for v in def.ventajas:
		var lv := Label.new()
		lv.text = (v if v.begins_with("+") else "+ " + v)
		lv.modulate = Color(0.3, 1.0, 0.45)
		lv.add_theme_font_size_override("font_size", 12)
		stats_box.add_child(lv)

	for d in def.desventajas:
		var ld := Label.new()
		ld.text = (d if d.begins_with("-") else "- " + d)
		ld.modulate = Color(1.0, 0.35, 0.35)
		ld.add_theme_font_size_override("font_size", 12)
		stats_box.add_child(ld)

	# CheckBox de Activacion
	var cb := CheckBox.new()
	cb.text = "Activa"
	cb.button_pressed = UpgradeDatabase.is_activa(def.id)
	cb.toggled.connect(func(activa: bool) -> void:
		UpgradeDatabase.set_activa(def.id, activa)
		_actualizar_contador()
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0) if activa else Color(0.55, 0.55, 0.6, 0.6)
	)
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0) if cb.button_pressed else Color(0.55, 0.55, 0.6, 0.6)
	hbox.add_child(cb)

	_checkboxes[def.id] = cb
	return panel
