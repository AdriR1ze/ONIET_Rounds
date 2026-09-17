extends CanvasLayer

signal cerrado

const COLORES_RAREZA := {
	UpgradeDefinition.Rareza.COMUN: Color(0.78, 0.8, 0.86),
	UpgradeDefinition.Rareza.RARA: Color(0.4, 0.7, 1.0),
	UpgradeDefinition.Rareza.EPICA: Color(0.78, 0.45, 1.0),
	UpgradeDefinition.Rareza.LEGENDARIA: Color(1.0, 0.75, 0.2),
}

@onready var _lista: VBoxContainer = $Centro/Marco/Margin/VBox/Scroll/Lista
@onready var _contador: Label = $Centro/Marco/Margin/VBox/Header/Contador
@onready var _boton_activar_todas: Button = $Centro/Marco/Margin/VBox/Header/BotonesRapidos/ActivarTodas
@onready var _boton_desactivar_todas: Button = $Centro/Marco/Margin/VBox/Header/BotonesRapidos/DesactivarTodas
@onready var _boton_volver: Button = $Centro/Marco/Margin/VBox/Volver

var _checkboxes: Dictionary = {}


func _ready() -> void:
	visible = false
	_boton_volver.pressed.connect(_on_volver)
	_boton_activar_todas.pressed.connect(_on_activar_todas)
	_boton_desactivar_todas.pressed.connect(_on_desactivar_todas)


func abrir() -> void:
	visible = true
	_construir_lista()
	_actualizar_contador()
	_boton_volver.grab_focus()


func cerrar() -> void:
	visible = false
	cerrado.emit()


func _on_volver() -> void:
	cerrar()


func _on_activar_todas() -> void:
	UpgradeDatabase.activar_todas()
	for id in _checkboxes:
		var cb: CheckBox = _checkboxes[id]
		cb.button_pressed = true
	_actualizar_contador()


func _on_desactivar_todas() -> void:
	UpgradeDatabase.desactivar_todas()
	for id in _checkboxes:
		var cb: CheckBox = _checkboxes[id]
		cb.button_pressed = false
	_actualizar_contador()


func _actualizar_contador() -> void:
	var total := UpgradeDatabase.definiciones.size()
	var activas := UpgradeDatabase.total_activas()
	_contador.text = "%d de %d habilidades activas" % [activas, total]


func _construir_lista() -> void:
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	_checkboxes.clear()

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

	# Fila de Título y Rareza
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

	# CheckBox de Activación
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
