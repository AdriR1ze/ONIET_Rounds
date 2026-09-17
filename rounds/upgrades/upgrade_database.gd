extends Node

const RUTA_DEFINICIONES := "res://upgrades/definitions"
const PESO_RAREZA := {
	UpgradeDefinition.Rareza.COMUN: 1.0,
	UpgradeDefinition.Rareza.RARA: 0.55,
	UpgradeDefinition.Rareza.EPICA: 0.25,
	UpgradeDefinition.Rareza.LEGENDARIA: 0.08,
}

var definiciones: Array[UpgradeDefinition] = []


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
		if not dir.current_is_dir() and archivo.ends_with(".tres"):
			var recurso := load(RUTA_DEFINICIONES + "/" + archivo)
			if recurso is UpgradeDefinition:
				definiciones.append(recurso)
		archivo = dir.get_next()
	dir.list_dir_end()


func opciones(cantidad: int, rng: RandomNumberGenerator, filtro: Callable) -> Array[UpgradeDefinition]:
	var pool: Array[UpgradeDefinition] = []
	for def in definiciones:
		if filtro.call(def):
			pool.append(def)

	var elegidas: Array[UpgradeDefinition] = []
	while elegidas.size() < cantidad and not pool.is_empty():
		var total := 0.0
		for def in pool:
			total += _peso(def)
		var tirada := rng.randf() * total
		var acumulado := 0.0
		var indice := pool.size() - 1
		for i in pool.size():
			acumulado += _peso(pool[i])
			if tirada <= acumulado:
				indice = i
				break
		elegidas.append(pool[indice])
		pool.remove_at(indice)
	return elegidas


func _peso(def: UpgradeDefinition) -> float:
	return maxf(def.peso, 0.0) * float(PESO_RAREZA.get(def.rareza, 1.0))
