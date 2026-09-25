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
		"id": &"a",
		"nombre": "a",
		"tipo": "Boceto 1 / Geometría",
		"descripcion": "Viga central inclinada a 45 grados rodeada por un arco de elipses flotantes y base de combate.",
		"escena": "res://levels/maps/map_04_repisas_orbes.tscn",
		"color": Color(0.2, 0.9, 1.0),
		"atlas_id": 1,
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


func _hay_al_menos_un_bot() -> bool:
	for i in range(1, RunManager.cantidad_jugadores + 1):
		if Settings.es_bot(i):
			return true
	for jug in RunManager.jugadores():
		if is_instance_valid(jug) and Settings.es_bot(jug.player_number):
			return true
	return false


func _es_mapa_piramide(m: Dictionary) -> bool:
	var id_str := str(m.get("id", "")).to_lower()
	var nombre_str := str(m.get("nombre", "")).to_lower()
	var escena_str := str(m.get("escena", "")).to_lower()
	return id_str == "el_pendulo" or id_str == "la_piramide" or "piramide" in id_str or "pendulo" in id_str or "piramide" in nombre_str or "piramide" in escena_str


func obtener_mapa_aleatorio() -> Dictionary:
	var activos := obtener_mapas_activos()
	if activos.is_empty():
		return DEFINICIONES_MAPAS[0]

	# Si hay al menos un bot seleccionado, el mapa de la pirámide queda excluido
	# silenciosamente a menos que sea el único mapa activo que quedó habilitado.
	if _hay_al_menos_un_bot():
		var sin_piramide: Array[Dictionary] = []
		for m in activos:
			if not _es_mapa_piramide(m):
				sin_piramide.append(m)
		if not sin_piramide.is_empty():
			activos = sin_piramide

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


func aplicar_estilo_mapa(_mapa_node: Node2D, _info: Dictionary) -> void:
	# Los materiales y estilos de neón están configurados directamente en la escena .tscn
	pass
