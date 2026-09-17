extends Node

signal ronda_iniciada(ronda: int)
signal ronda_terminada(ronda: int)
signal mejoras_cambiadas(player_number: int)
signal vidas_cambiadas(player_number: int, vidas: int)
signal partida_terminada(ganador_player_number: int)

var ronda: int = 0
var rng := RandomNumberGenerator.new()

var vidas: Dictionary = { 1: 5, 2: 5 }
var partida_finalizada: bool = false
var _jugadores: Dictionary = {}
var _mejoras: Dictionary = {}


func _ready() -> void:
	rng.randomize()


func registrar_jugador(player: Node) -> void:
	var numero: int = player.player_number
	_jugadores[numero] = player
	if not _mejoras.has(numero):
		_mejoras[numero] = []
	if not vidas.has(numero):
		vidas[numero] = 5
	_recalcular(numero)


func jugadores() -> Array:
	return _jugadores.values()


func vidas_de(player_number: int) -> int:
	return vidas.get(player_number, 5)


func nivel_desbloqueado(player_number: int) -> int:
	var vidas_actuales: int = vidas_de(player_number)
	var vidas_perdidas: int = 5 - vidas_actuales
	return clampi(1 + vidas_perdidas, 1, 5)


func perder_vida(player_number: int) -> void:
	if partida_finalizada:
		return
	var actual: int = vidas_de(player_number)
	actual = maxi(actual - 1, 0)
	vidas[player_number] = actual
	vidas_cambiadas.emit(player_number, actual)
	if actual == 0:
		partida_finalizada = true
		var ganador: int = 2 if player_number == 1 else 1
		partida_terminada.emit(ganador)
		print("FIN DE PARTIDA! Ganador: Jugador %d" % ganador)


func mejoras_de(player_number: int) -> Array:
	return _mejoras.get(player_number, [])


func stacks_de(player_number: int, id: StringName) -> int:
	var total := 0
	for def in _mejoras.get(player_number, []):
		if def.id == id:
			total += 1
	return total


func opciones_para(player_number: int, cantidad: int = 3) -> Array[UpgradeDefinition]:
	var max_nivel := nivel_desbloqueado(player_number)
	return UpgradeDatabase.opciones(cantidad, rng, func(def: UpgradeDefinition) -> bool:
		if def.nivel > max_nivel:
			return false
		if stacks_de(player_number, def.id) > 0:
			return false
		return _cumple_requisitos(player_number, def)
	)


func elegir(player_number: int, def: UpgradeDefinition) -> void:
	if def == null:
		return
	_mejoras[player_number].append(def)
	_recalcular(player_number)
	mejoras_cambiadas.emit(player_number)


func iniciar_ronda(numero: int) -> void:
	ronda = numero
	ronda_iniciada.emit(ronda)


func terminar_ronda() -> void:
	ronda_terminada.emit(ronda)


func _cumple_requisitos(player_number: int, def: UpgradeDefinition) -> bool:
	for requerido in def.requiere:
		if stacks_de(player_number, requerido) <= 0:
			return false
	return true


func _recalcular(player_number: int) -> void:
	var player: Node = _jugadores.get(player_number)
	if player != null and player.has_method("aplicar_mejoras"):
		player.aplicar_mejoras(_mejoras[player_number])
