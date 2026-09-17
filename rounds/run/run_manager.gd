extends Node

signal ronda_iniciada(ronda: int)
signal ronda_terminada(ronda: int, ganador: int)
signal mejoras_cambiadas(player_number: int)
signal marcador_cambiado
signal vidas_cambiadas
signal partida_terminada(ganador: int)

var ronda: int = 0
var rondas_para_ganar: int = 3
var vidas_por_ronda: int = 3
var rng := RandomNumberGenerator.new()

var _jugadores: Dictionary = {}
var _mejoras: Dictionary = {}
var _marcador: Dictionary = {}
var _vidas: Dictionary = {}


func _ready() -> void:
	rng.randomize()


func configurar_partida(rondas: int, vidas: int) -> void:
	rondas_para_ganar = maxi(rondas, 1)
	vidas_por_ronda = maxi(vidas, 1)


func registrar_jugador(player: Node) -> void:
	var numero: int = player.player_number
	_jugadores[numero] = player
	if not _mejoras.has(numero):
		_mejoras[numero] = []
	_recalcular(numero)


func jugadores() -> Array:
	return _jugadores.values()


func mejoras_de(player_number: int) -> Array:
	return _mejoras.get(player_number, [])


func stacks_de(player_number: int, id: StringName) -> int:
	var total := 0
	for def in _mejoras.get(player_number, []):
		if def.id == id:
			total += 1
	return total


func opciones_para(player_number: int, cantidad: int = 3) -> Array[UpgradeDefinition]:
	return UpgradeDatabase.opciones(cantidad, rng, func(def):
		return stacks_de(player_number, def.id) < def.max_stacks and _cumple_requisitos(player_number, def)
	)


func elegir(player_number: int, def: UpgradeDefinition) -> void:
	if def == null:
		return
	_mejoras[player_number].append(def)
	_recalcular(player_number)
	mejoras_cambiadas.emit(player_number)


func vidas_de(player_number: int) -> int:
	return _vidas.get(player_number, vidas_por_ronda)


func marcador_de(player_number: int) -> int:
	return _marcador.get(player_number, 0)


func marcador() -> Dictionary:
	return _marcador.duplicate()


func iniciar_partida() -> void:
	_marcador.clear()
	for numero in _jugadores:
		_marcador[numero] = 0
	marcador_cambiado.emit()


func iniciar_ronda(numero: int) -> void:
	ronda = numero
	_vidas.clear()
	for numero_jugador in _jugadores:
		_vidas[numero_jugador] = vidas_por_ronda
	ronda_iniciada.emit(ronda)
	vidas_cambiadas.emit()


func registrar_muerte(player_number: int) -> bool:
	var vidas: int = vidas_de(player_number) - 1
	_vidas[player_number] = maxi(vidas, 0)
	vidas_cambiadas.emit()
	return vidas > 0


func ganador_de_ronda(perdedor: int) -> int:
	for numero in _jugadores:
		if numero != perdedor:
			return numero
	return 0


func terminar_ronda(ganador: int) -> void:
	_marcador[ganador] = marcador_de(ganador) + 1
	marcador_cambiado.emit()
	ronda_terminada.emit(ronda, ganador)
	if partida_ganada():
		partida_terminada.emit(ganador)


func partida_ganada() -> bool:
	return ganador_partida() != 0


func ganador_partida() -> int:
	for numero in _marcador:
		if _marcador[numero] >= rondas_para_ganar:
			return numero
	return 0


func reiniciar() -> void:
	_jugadores.clear()
	_mejoras.clear()
	_marcador.clear()
	_vidas.clear()
	ronda = 0


func _cumple_requisitos(player_number: int, def: UpgradeDefinition) -> bool:
	for requerido in def.requiere:
		if stacks_de(player_number, requerido) <= 0:
			return false
	return true


func _recalcular(player_number: int) -> void:
	var player: Node = _jugadores.get(player_number)
	if player != null and player.has_method("aplicar_mejoras"):
		player.aplicar_mejoras(_mejoras[player_number])
