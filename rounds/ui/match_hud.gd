extends CanvasLayer

const COLOR_HP := Color(0.4, 0.85, 0.45, 1)
const COLOR_HP_VACIO := Color(0.14, 0.11, 0.08, 0.65)
const COLOR_VIDA := Color(1, 0.72, 0.2, 1)
const COLOR_VIDA_VACIO := Color(0.14, 0.11, 0.08, 0.65)
const TAMANO_PIP := 12.0

@onready var _ronda: Label = $Fondo/Margin/HBox/Centro/Ronda
@onready var _marcador: Label = $Fondo/Margin/HBox/Centro/Marcador
@onready var _p1_nombre: Label = $Fondo/Margin/HBox/Izquierda/Nombre
@onready var _p1_hp: HBoxContainer = $Fondo/Margin/HBox/Izquierda/HP
@onready var _p1_vidas: HBoxContainer = $Fondo/Margin/HBox/Izquierda/Vidas
@onready var _p2_nombre: Label = $Fondo/Margin/HBox/Derecha/Nombre
@onready var _p2_hp: HBoxContainer = $Fondo/Margin/HBox/Derecha/HP
@onready var _p2_vidas: HBoxContainer = $Fondo/Margin/HBox/Derecha/Vidas


func _process(_delta: float) -> void:
	_ronda.text = "Ronda %d" % maxi(RunManager.ronda, 1)
	var n1 := RunManager.nombre_jugador(1)
	var n2 := RunManager.nombre_jugador(2)
	_marcador.text = "%s  %d  -  %d  %s" % [n1, RunManager.marcador_de(1), RunManager.marcador_de(2), n2]
	_p1_nombre.text = "%s  (%d/%d HP)" % [n1, _salud(1), _salud_max(1)]
	_p2_nombre.text = "(%d/%d HP)  %s" % [_salud(2), _salud_max(2), n2]
	_pintar_pips(_p1_hp, _salud(1), _salud_max(1), COLOR_HP, COLOR_HP_VACIO)
	_pintar_pips(_p1_vidas, RunManager.vidas_de(1), RunManager.vidas_por_ronda, COLOR_VIDA, COLOR_VIDA_VACIO)
	_pintar_pips(_p2_hp, _salud(2), _salud_max(2), COLOR_HP, COLOR_HP_VACIO)
	_pintar_pips(_p2_vidas, RunManager.vidas_de(2), RunManager.vidas_por_ronda, COLOR_VIDA, COLOR_VIDA_VACIO)


func _pintar_pips(contenedor: HBoxContainer, valor: int, maximo: int, color: Color, color_vacio: Color) -> void:
	var num_pips: int = maximo
	var pips_llenos: int = valor
	if maximo > 10:
		num_pips = maxi(int(ceil(float(maximo) / 25.0)), 1)
		pips_llenos = clampi(int(ceil(float(valor) / 25.0)), 0, num_pips)
	var total := maxi(num_pips, 1)
	while contenedor.get_child_count() < total:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(TAMANO_PIP, TAMANO_PIP)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor.add_child(pip)
	while contenedor.get_child_count() > total:
		var sobrante := contenedor.get_child(contenedor.get_child_count() - 1)
		contenedor.remove_child(sobrante)
		sobrante.queue_free()
	for i in total:
		var pip := contenedor.get_child(i) as ColorRect
		pip.color = color if i < pips_llenos else color_vacio


func _salud(numero: int) -> int:
	var salud := _componente_salud(numero)
	return salud.health if salud != null else 0


func _salud_max(numero: int) -> int:
	var salud := _componente_salud(numero)
	return salud.max_health if salud != null else 1


func _componente_salud(numero: int) -> Node:
	for jugador in RunManager.jugadores():
		if not is_instance_valid(jugador):
			continue
		if jugador.player_number == numero:
			return jugador.get_node_or_null("HealthComponent")
	return null
