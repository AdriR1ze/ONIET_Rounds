extends CanvasLayer

@onready var _ronda: Label = $Barra/HBox/Centro/Ronda
@onready var _marcador: Label = $Barra/HBox/Centro/Marcador
@onready var _p1_hp: ProgressBar = $Barra/HBox/Izquierda/FilaHP/HP
@onready var _p1_vidas: ProgressBar = $Barra/HBox/Izquierda/FilaVidas/Vidas
@onready var _p2_hp: ProgressBar = $Barra/HBox/Derecha/FilaHP/HP
@onready var _p2_vidas: ProgressBar = $Barra/HBox/Derecha/FilaVidas/Vidas


func _process(_delta: float) -> void:
	_ronda.text = "Ronda %d" % maxi(RunManager.ronda, 1)
	_marcador.text = "P1  %d  -  %d  P2" % [RunManager.marcador_de(1), RunManager.marcador_de(2)]
	_actualizar_jugador(1, _p1_hp, _p1_vidas)
	_actualizar_jugador(2, _p2_hp, _p2_vidas)


func _actualizar_jugador(numero: int, hp: ProgressBar, vidas: ProgressBar) -> void:
	hp.max_value = maxi(_salud_max(numero), 1)
	hp.value = _salud(numero)
	vidas.max_value = maxi(RunManager.vidas_por_ronda, 1)
	vidas.value = RunManager.vidas_de(numero)


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
