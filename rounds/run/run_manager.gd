extends Node

signal ronda_iniciada(ronda: int)
signal ronda_terminada(ronda: int)
signal mejoras_cambiadas(player_number: int)

var ronda: int = 0
var rng := RandomNumberGenerator.new()

var _jugadores: Dictionary = {}
var _mejoras: Dictionary = {}


func _ready() -> void:
	rng.randomize()


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
