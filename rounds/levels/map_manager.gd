extends Node

signal mapas_cambiados

const DEFINICIONES_MAPAS: Array[Dictionary] = [
	{
		"id": &"pilar_central",
		"nombre": "Pilar Central",
		"tipo": "Abierto / Cobertura",
		"descripcion": "Gran monolito central con escalones accesibles a ambos lados. Subidas comodas para alcanzar todas las alturas.",
		"escena": "res://levels/maps/map_01_pilar_central.tscn",
		"color": Color(0.2, 0.85, 1.0),
		"atlas_id": 1,
	},
	{
		"id": &"plataformas_flotantes",
		"nombre": "La Rueda",
		"tipo": "Circular / Arena",
		"descripcion": "Una gigantesca rueda circular en el centro con aberturas. Se puede combatir dentro, encima o a traves de ella.",
		"escena": "res://levels/maps/map_02_plataformas_flotantes.tscn",
		"color": Color(0.35, 0.55, 1.0),
		"atlas_id": 2,
	},
	{
		"id": &"bunker_clausura",
		"nombre": "Foso de Acido",
		"tipo": "Suelo Mortal / Peligro",
		"descripcion": "El suelo te mata. El piso inferior esta cubierto de plasma letal: lucha sobre plataformas flotantes sin caerte.",
		"escena": "res://levels/maps/map_03_bunker_clausura.tscn",
		"color": Color(1.0, 0.35, 0.35),
		"atlas_id": 3,
	},
	{
		"id": &"dos_torres",
		"nombre": "Las Dos Torres",
		"tipo": "Torres / Asedio",
		"descripcion": "Dos fortalezas con almenas accesibles por escaleras y un puente central a media altura que cruza el valle.",
		"escena": "res://levels/maps/map_04_dos_torres.tscn",
		"color": Color(0.4, 0.95, 0.4),
		"atlas_id": 0,
	},
	{
		"id": &"la_jaula",
		"nombre": "Orbes Flotantes",
		"tipo": "Islas Circulares",
		"descripcion": "Planetas y esferas circulares flotantes de neon en el aire con escalones bajos para subir sin esfuerzo.",
		"escena": "res://levels/maps/map_05_la_jaula.tscn",
		"color": Color(0.2, 0.85, 1.0),
		"atlas_id": 1,
	},
	{
		"id": &"escalones_cruzados",
		"nombre": "Bunker Laberinto",
		"tipo": "Cerrado / Tactico",
		"descripcion": "Pasadizos cerrados, techos bajos y salas conectadas con escalones cortos para combates a corta distancia.",
		"escena": "res://levels/maps/map_06_escalones_cruzados.tscn",
		"color": Color(1.0, 0.45, 0.2),
		"atlas_id": 3,
	},
	{
		"id": &"tres_pisos",
		"nombre": "Tres Pisos",
		"tipo": "Niveles Accesibles",
		"descripcion": "Tres plantas horizontales completas interconectadas por peldanos de altura moderada y huecos de caida.",
		"escena": "res://levels/maps/map_07_tres_pisos.tscn",
		"color": Color(0.35, 0.55, 1.0),
		"atlas_id": 2,
	},
	{
		"id": &"el_embudo",
		"nombre": "El Coliseo",
		"tipo": "Foso Mortal / Gradas",
		"descripcion": "Gradas laterales escalonadas y seguras con un foso central letal de plasma justo debajo del puente de duelo.",
		"escena": "res://levels/maps/map_08_el_embudo.tscn",
		"color": Color(0.4, 0.95, 0.4),
		"atlas_id": 0,
	},
]

var desactivados: Dictionary = {}
var ultimo_mapa_id: StringName = &""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func obtener_mapas() -> Array[Dictionary]:
	return DEFINICIONES_MAPAS


func obtener_mapa_por_id(id: StringName) -> Dictionary:
	for mapa in DEFINICIONES_MAPAS:
		if mapa["id"] == id:
			return mapa
	return DEFINICIONES_MAPAS[0]


func is_activo(id: StringName) -> bool:
	return not desactivados.get(id, false)


func set_activo(id: StringName, activo: bool) -> void:
	if activo:
		desactivados.erase(id)
	else:
		# Garantizar que siempre haya al menos 1 mapa activo
		if total_activos() <= 1 and is_activo(id):
			return
		desactivados[id] = true
	mapas_cambiados.emit()


func activar_todos() -> void:
	desactivados.clear()
	mapas_cambiados.emit()


func desactivar_todos() -> void:
	# Mantiene unicamente el primer mapa activo para no dejar la lista vacia
	desactivados.clear()
	for i in range(1, DEFINICIONES_MAPAS.size()):
		desactivados[DEFINICIONES_MAPAS[i]["id"]] = true
	mapas_cambiados.emit()


func total_activos() -> int:
	var count := 0
	for mapa in DEFINICIONES_MAPAS:
		if is_activo(mapa["id"]):
			count += 1
	return count


func obtener_mapas_activos() -> Array[Dictionary]:
	var activos: Array[Dictionary] = []
	for mapa in DEFINICIONES_MAPAS:
		if is_activo(mapa["id"]):
			activos.append(mapa)
	if activos.is_empty():
		activos.append(DEFINICIONES_MAPAS[0])
	return activos


func obtener_mapa_aleatorio() -> Dictionary:
	var activos := obtener_mapas_activos()
	if activos.is_empty():
		return DEFINICIONES_MAPAS[0]

	if activos.size() == 1:
		ultimo_mapa_id = activos[0]["id"]
		return activos[0]

	# Evitar repetir el mismo mapa de forma consecutiva
	var candidatos: Array[Dictionary] = []
	for m in activos:
		if m["id"] != ultimo_mapa_id:
			candidatos.append(m)

	if candidatos.is_empty():
		candidatos = activos

	var seleccionado: Dictionary = candidatos[_rng.randi_range(0, candidatos.size() - 1)]
	ultimo_mapa_id = seleccionado["id"]
	return seleccionado
