extends Node

signal mapas_cambiados

const DEFINICIONES_MAPAS: Array[Dictionary] = [
	{
		"id": &"foso_acido",
		"nombre": "Foso de Ácido",
		"tipo": "Suelo Mortal / Peligro",
		"descripcion": "El suelo te mata. El piso inferior está cubierto de plasma letal: lucha sobre plataformas flotantes sin caerte.",
		"escena": "res://levels/maps/map_01_foso_acido.tscn",
		"color": Color(1.0, 0.35, 0.35),
		"atlas_id": 3,
	},
	{
		"id": &"tres_pisos",
		"nombre": "Tres Pisos",
		"tipo": "Niveles Accesibles",
		"descripcion": "Tres plantas horizontales completas interconectadas por peldaños de altura moderada y huecos de caída.",
		"escena": "res://levels/maps/map_02_tres_pisos.tscn",
		"color": Color(0.35, 0.55, 1.0),
		"atlas_id": 2,
	},
	{
		"id": &"el_pendulo",
		"nombre": "El Péndulo",
		"tipo": "Boceto 1 / Geometría",
		"descripcion": "Viga central inclinada a 45 grados rodeada por un arco de elipses flotantes y base de combate.",
		"escena": "res://levels/maps/map_03_el_pendulo.tscn",
		"color": Color(0.2, 0.9, 1.0),
		"atlas_id": 1,
	},
	{
		"id": &"repisas_orbes",
		"nombre": "Repisas y Orbes",
		"tipo": "Boceto 2 / Asimétrico",
		"descripcion": "Estantes y repisas escalonadas en el centro con columnas verticales de orbes circulares a los lados.",
		"escena": "res://levels/maps/map_04_repisas_orbes.tscn",
		"color": Color(1.0, 0.65, 0.15),
		"atlas_id": 0,
	},
	{
		"id": &"el_abismo",
		"nombre": "El Abismo",
		"tipo": "Boceto 3 / Bastiones",
		"descripcion": "Dos bastiones colosales donde aparecen los duelistas, techo superior y escalones sobre el abismo.",
		"escena": "res://levels/maps/map_05_el_abismo.tscn",
		"color": Color(0.2, 0.95, 0.4),
		"atlas_id": 0,
	},
	{
		"id": &"castillo_carmesi",
		"nombre": "Castillo Carmesí",
		"tipo": "Rounds / Núcleo Letal",
		"descripcion": "Almenas escalonadas de castillo con coberturas tácticas y un peligroso núcleo mortal en el foso central.",
		"escena": "res://levels/maps/map_06_castillo_carmesi.tscn",
		"color": Color(1.0, 0.25, 0.35),
		"atlas_id": 3,
	},
	{
		"id": &"la_piramide",
		"nombre": "La Pirámide",
		"tipo": "Rounds / Castillo Piramidal",
		"descripcion": "Fortaleza piramidal con peldaños ascendentes hacia la corona central y dos torres centinela aisladas.",
		"escena": "res://levels/maps/map_07_la_piramide.tscn",
		"color": Color(1.0, 0.82, 0.2),
		"atlas_id": 1,
	},
	{
		"id": &"coliseo_plasma",
		"nombre": "El Coliseo de Plasma",
		"tipo": "Arena / Foso y Anillo",
		"descripcion": "Gradas laterales escalonadas, foso mortal de plasma y un anillo circular suspendido en lo alto.",
		"escena": "res://levels/maps/map_08_coliseo_plasma.tscn",
		"color": Color(0.85, 0.35, 1.0),
		"atlas_id": 2,
	},
	{
		"id": &"camaras_gemelas",
		"nombre": "Cámaras Gemelas",
		"tipo": "Cerrado / Táctico",
		"descripcion": "Dos búnkers fortificados con ventanas de tiro y techo bajo conectados por un puente elevado.",
		"escena": "res://levels/maps/map_09_camaras_gemelas.tscn",
		"color": Color(0.15, 0.9, 0.85),
		"atlas_id": 1,
	},
	{
		"id": &"catapulta_diagonal",
		"nombre": "La Catapulta Diagonal",
		"tipo": "Rampas / Rebote",
		"descripcion": "Dos rampas diagonales cruzadas en el centro con orbes elevados para tiros con ángulo y rebotes.",
		"escena": "res://levels/maps/map_10_catapulta_diagonal.tscn",
		"color": Color(0.8, 1.0, 0.2),
		"atlas_id": 0,
	},
	{
		"id": &"nucleo_flotante",
		"nombre": "El Núcleo Flotante",
		"tipo": "Islas / Zona Mortal",
		"descripcion": "Islas circulares flotantes rodeando una zona letal suspendida en el aire con puente superior.",
		"escena": "res://levels/maps/map_11_nucleo_flotante.tscn",
		"color": Color(1.0, 0.2, 0.7),
		"atlas_id": 3,
	},
	{
		"id": &"el_trono",
		"nombre": "El Trono Alto",
		"tipo": "Castillo / Rey Colina",
		"descripcion": "Plataforma central de trono elevado con parapetos de cobertura y bajadas hacia trincheras inferiores.",
		"escena": "res://levels/maps/map_12_el_trono.tscn",
		"color": Color(0.4, 0.65, 1.0),
		"atlas_id": 2,
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
