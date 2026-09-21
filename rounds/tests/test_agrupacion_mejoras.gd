extends RefCounted

const PantallaMejoras := preload("res://ui/upgrade_screen.gd")


class JugadorFalso:
	var player_number: int

	func _init(numero: int) -> void:
		player_number = numero


func _falsos(numeros: Array) -> Array:
	var lista: Array = []
	for n in numeros:
		lista.append(JugadorFalso.new(n))
	return lista


func _numeros(grupos: Array, indice: int) -> Array:
	var lista: Array = []
	for jugador in grupos[indice]:
		lista.append(jugador.player_number)
	return lista


func test_cuatro_jugadores_dos_tandas() -> void:
	var grupos := PantallaMejoras.agrupar(_falsos([1, 2, 3, 4]))
	assert(grupos.size() == 2, "4 jugadores deben ser 2 tandas")
	assert(_numeros(grupos, 0) == [1, 2], "tanda 1 = jugadores 1 y 2")
	assert(_numeros(grupos, 1) == [3, 4], "tanda 2 = jugadores 3 y 4")


func test_tres_jugadores() -> void:
	var grupos := PantallaMejoras.agrupar(_falsos([1, 2, 3]))
	assert(grupos.size() == 2, "3 jugadores deben ser 2 tandas")
	assert(_numeros(grupos, 0) == [1, 2], "tanda 1 = jugadores 1 y 2")
	assert(_numeros(grupos, 1) == [3], "tanda 2 = solo jugador 3")


func test_dos_jugadores_una_tanda() -> void:
	var grupos := PantallaMejoras.agrupar(_falsos([1, 2]))
	assert(grupos.size() == 1, "2 jugadores deben ser una sola tanda")
	assert(_numeros(grupos, 0) == [1, 2], "tanda unica = jugadores 1 y 2")


func test_jugador_muerto_no_aparece() -> void:
	# Jugador 2 eliminado: su bloque no debe aparecer.
	var grupos := PantallaMejoras.agrupar(_falsos([1, 3, 4]))
	assert(grupos.size() == 2, "deben ser 2 tandas")
	assert(_numeros(grupos, 0) == [1], "tanda 1 = solo jugador 1")
	assert(_numeros(grupos, 1) == [3, 4], "tanda 2 = jugadores 3 y 4")


func test_primeros_dos_eliminados() -> void:
	var grupos := PantallaMejoras.agrupar(_falsos([3, 4]))
	assert(grupos.size() == 1, "solo queda la tanda de 3 y 4")
	assert(_numeros(grupos, 0) == [3, 4], "tanda unica = jugadores 3 y 4")


func test_sin_jugadores() -> void:
	assert(PantallaMejoras.agrupar([]).is_empty(), "sin jugadores no hay tandas")
