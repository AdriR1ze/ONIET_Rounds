extends Node

const RUTA_DEFINICIONES := "res://upgrades/definitions"
const PROB_CATEGORIA := {
	UpgradeDefinition.Categoria.ATAQUE: 0.40,
	UpgradeDefinition.Categoria.DEFENSA: 0.40,
	UpgradeDefinition.Categoria.CONTROL: 0.20,
}

var definiciones: Array[UpgradeDefinition] = []
var desactivadas: Dictionary = {}


func _ready() -> void:
	cargar()


func cargar() -> void:
	definiciones.clear()
	var dir := DirAccess.open(RUTA_DEFINICIONES)
	if dir == null:
		return
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if not dir.current_is_dir() and (archivo.ends_with(".tres") or archivo.ends_with(".tres.remap")):
			var recurso := load(RUTA_DEFINICIONES + "/" + archivo.trim_suffix(".remap"))
			if recurso is UpgradeDefinition:
				definiciones.append(recurso)
		archivo = dir.get_next()
	dir.list_dir_end()


func is_activa(id: StringName) -> bool:
	return not desactivadas.get(id, false)


func set_activa(id: StringName, activa: bool) -> void:
	if activa:
		desactivadas.erase(id)
	else:
		desactivadas[id] = true


func activar_todas() -> void:
	desactivadas.clear()


func desactivar_todas() -> void:
	for def in definiciones:
		desactivadas[def.id] = true


func total_activas() -> int:
	var count := 0
	for def in definiciones:
		if is_activa(def.id):
			count += 1
	return count


func opciones(cantidad: int, rng: RandomNumberGenerator, filtro: Callable) -> Array[UpgradeDefinition]:
	var por_categoria: Dictionary = {}
	for def in definiciones:
		if not is_activa(def.id):
			continue
		if not filtro.call(def):
			continue
		if not por_categoria.has(def.categoria):
			por_categoria[def.categoria] = []
		por_categoria[def.categoria].append(def)

	var elegidas: Array[UpgradeDefinition] = []
	for _i in cantidad:
		var categorias: Array = []
		var total := 0.0
		for categoria in por_categoria:
			if not por_categoria[categoria].is_empty():
				categorias.append(categoria)
				total += float(PROB_CATEGORIA.get(categoria, 0.0))
		if categorias.is_empty():
			break

		var tirada := rng.randf() * total
		var elegida: int = categorias[categorias.size() - 1]
		for categoria in categorias:
			tirada -= float(PROB_CATEGORIA.get(categoria, 0.0))
			if tirada <= 0.0:
				elegida = categoria
				break

		var bucket: Array = por_categoria[elegida]
		var indice := rng.randi_range(0, bucket.size() - 1)
		elegidas.append(bucket[indice])
		bucket.remove_at(indice)

	return elegidas
