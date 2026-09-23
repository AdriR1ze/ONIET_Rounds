extends Node

signal ronda_iniciada(ronda: int)
signal ronda_terminada(ronda: int, ganador: int)
signal mejoras_cambiadas(player_number: int)
signal marcador_cambiado
signal vidas_cambiadas
signal partida_terminada(ganador: int)

var ronda: int = 0
var rondas_para_ganar: int = 5
var vidas_por_ronda: int = 2
var cantidad_jugadores: int = 2
var rng := RandomNumberGenerator.new()

enum DificultadBot {
	MUY_FACIL,
	FACIL,
	MEDIO,
	DIFICIL,
	MUY_DIFICIL,
	HACKER,
}

const DIFICULTADES_BOT := [
	"Muy Fácil",
	"Fácil",
	"Medio",
	"Difícil",
	"Muy Difícil",
	"Hacker",
]

var dificultad_bot: int = DificultadBot.MEDIO

const COLORES_JUGADOR := {
	1: Color(1.0, 0.85, 0.2, 1.0),
	2: Color(0.35, 0.75, 1.0, 1.0),
	3: Color(0.45, 0.95, 0.45, 1.0),
	4: Color(1.0, 0.45, 0.8, 1.0),
}
const PALETAS_ESQUELETO := {
	1: [Color(1.0, 0.95, 0.25, 1.0), Color(1.0, 0.85, 0.15, 1.0), Color(0.65, 0.48, 0.08, 1.0)],
	2: [Color(0.80, 0.98, 1.0, 1.0), Color(0.35, 0.78, 1.0, 1.0), Color(0.08, 0.20, 0.38, 1.0)],
	3: [Color(0.85, 1.0, 0.80, 1.0), Color(0.45, 0.95, 0.45, 1.0), Color(0.10, 0.40, 0.12, 1.0)],
	4: [Color(1.0, 0.85, 0.95, 1.0), Color(1.0, 0.45, 0.80, 1.0), Color(0.45, 0.10, 0.30, 1.0)],
}

var vidas: Dictionary = { 1: 2, 2: 2 }
var nombres: Dictionary = { 1: "Jugador 1", 2: "Jugador 2" }
var personajes: Dictionary = { 1: "esqueleto", 2: "esqueleto" }
var partida_finalizada: bool = false
var _jugadores: Dictionary = {}
var _mejoras: Dictionary = {}
var _marcador: Dictionary = {}


func _ready() -> void:
	rng.randomize()


func color_jugador(numero: int) -> Color:
	return COLORES_JUGADOR.get(numero, COLORES_JUGADOR[1])


func paleta_esqueleto(numero: int) -> Array:
	return PALETAS_ESQUELETO.get(numero, PALETAS_ESQUELETO[1])


func set_cantidad_jugadores(cantidad: int) -> void:
	cantidad_jugadores = clampi(cantidad, 2, 4)
	_inicializar_jugadores()


func nombre_jugador(numero: int) -> String:
	return nombres.get(numero, "Jugador %d" % numero)


func set_nombres(lista: Array) -> void:
	for i in cantidad_jugadores:
		var numero := i + 1
		var n := String(lista[i]).strip_edges() if i < lista.size() else ""
		nombres[numero] = n if not n.is_empty() else "Jugador %d" % numero


func set_personaje(player_number: int, id: String) -> void:
	personajes[player_number] = id


func personaje_de(player_number: int) -> String:
	return personajes.get(player_number, "esqueleto")


const MAX_VIDAS := 20


func configurar_partida(rondas: int, vidas: int, dif_bot: int = -1) -> void:
	rondas_para_ganar = maxi(rondas, 1)
	vidas_por_ronda = clampi(vidas, 1, MAX_VIDAS)
	if dif_bot >= 0:
		set_dificultad_bot(dif_bot)


func set_dificultad_bot(dificultad: int) -> void:
	dificultad_bot = clampi(dificultad, 0, DIFICULTADES_BOT.size() - 1)


func dificultad_bot_nombre() -> String:
	if dificultad_bot >= 0 and dificultad_bot < DIFICULTADES_BOT.size():
		return DIFICULTADES_BOT[dificultad_bot]
	return "Medio"


func registrar_jugador(player: Node) -> void:
	var numero: int = player.player_number
	_jugadores[numero] = player
	if not _mejoras.has(numero):
		_mejoras[numero] = []
	if not vidas.has(numero):
		vidas[numero] = vidas_por_ronda
	_recalcular(numero)


func jugadores() -> Array:
	return _jugadores.values()


func jugadores_activos() -> Array:
	# OJO: con la nueva semántica, tras terminar una ronda el perdedor queda con 0
	# vidas hasta que run_controller llame a iniciar_ronda(); el orden de llamadas
	# es responsabilidad de run_controller.
	var lista: Array = []
	for numero in _jugadores:
		if vidas_de(numero) > 0:
			lista.append(_jugadores[numero])
	return lista


func jugadores_con_vidas() -> Array:
	var lista: Array = []
	for numero in _jugadores:
		if vidas_de(numero) > 0:
			lista.append(_jugadores[numero])
	return lista


func vidas_de(player_number: int) -> int:
	return vidas.get(player_number, vidas_por_ronda)


func nivel_desbloqueado(player_number: int) -> int:
	# Las mejoras de nivel 2-5 escalan con el progreso de la partida (ronda alcanzada).
	return clampi(ronda, 1, 5)


func perder_vida(player_number: int) -> void:
	if partida_finalizada:
		return
	var actual: int = vidas_de(player_number)
	actual = maxi(actual - 1, 0)
	vidas[player_number] = actual
	vidas_cambiadas.emit()


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


func marcador_de(player_number: int) -> int:
	return _marcador.get(player_number, 0)


func marcador() -> Dictionary:
	return _marcador.duplicate()


func iniciar_partida() -> void:
	partida_finalizada = false
	_marcador.clear()
	_inicializar_jugadores()
	for numero in _jugadores:
		_marcador[numero] = 0
	marcador_cambiado.emit()
	vidas_cambiadas.emit()


func iniciar_ronda(numero: int) -> void:
	ronda = numero
	for jugador_numero in _jugadores:
		vidas[jugador_numero] = vidas_por_ronda
	ronda_iniciada.emit(ronda)
	vidas_cambiadas.emit()


func terminar_ronda(ganador: int) -> void:
	if ganador > 0:
		_marcador[ganador] = marcador_de(ganador) + 1
		marcador_cambiado.emit()
	ronda_terminada.emit(ronda, ganador)
	if ganador > 0 and marcador_de(ganador) >= rondas_para_ganar:
		partida_finalizada = true
		partida_terminada.emit(ganador)


func partida_ganada() -> bool:
	return ganador_partida() != 0


func ganador_partida() -> int:
	for numero in _jugadores:
		if marcador_de(numero) >= rondas_para_ganar:
			return numero
	return 0


func reiniciar() -> void:
	_jugadores.clear()
	_mejoras.clear()
	_marcador.clear()
	partida_finalizada = false
	ronda = 0
	_inicializar_jugadores()


func _inicializar_jugadores() -> void:
	for numero in range(1, cantidad_jugadores + 1):
		vidas[numero] = vidas_por_ronda
		if not nombres.has(numero):
			nombres[numero] = "Jugador %d" % numero
		if not personajes.has(numero):
			personajes[numero] = "esqueleto"


func _cumple_requisitos(player_number: int, def: UpgradeDefinition) -> bool:
	for requerido in def.requiere:
		if stacks_de(player_number, requerido) <= 0:
			return false
	return true


func _recalcular(player_number: int) -> void:
	var player: Node = _jugadores.get(player_number)
	if player != null and player.has_method("aplicar_mejoras"):
		player.aplicar_mejoras(_mejoras[player_number])
