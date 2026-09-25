extends Node

const MAPA := "res://levels/maps/map_03_el_pendulo.tscn"
const SOURCE_VERDE := 0
const ATLAS_VERDE := Vector2i(0, 0)


func _ready() -> void:
	var mapa: Node2D = (load(MAPA) as PackedScene).instantiate()
	add_child(mapa)
	await get_tree().process_frame

	var layer: TileMapLayer = mapa.get_node("NeonTileMap")
	var timer: Timer = mapa.get_node("ColapsoTimer")
	timer.stop()

	var total_inicial := layer.get_used_cells().size()
	assert(total_inicial > 0, "El mapa debe tener celdas")
	var verdes_iniciales := _contar_verdes(layer)
	assert(verdes_iniciales > 0, "El mapa debe tener andamiaje verde")

	# Avanzar todas las fases (el handler se detiene solo al terminar)
	for i in range(80):
		mapa._on_timer_timeout()
	assert(mapa._radio <= mapa.radio_nucleo, "El colapso debe terminar en el núcleo")
	assert(mapa._fase == mapa.Fase.TERMINADA, "El colapso debe terminar tras la fase verde")

	# Solo sobreviven celdas dentro de las columnas del núcleo
	var limite_izq: int = int(mapa.get("_centro_x")) - int(mapa.radio_nucleo)
	var limite_der: int = int(mapa.get("_centro_x")) + int(mapa.radio_nucleo)
	for c in layer.get_used_cells():
		assert(c.x >= limite_izq and c.x <= limite_der, "Celda %s quedó fuera del núcleo (límites %d..%d)" % [c, limite_izq, limite_der])

	var restantes := layer.get_used_cells().size()
	assert(restantes > 0, "Debe quedar el núcleo")
	assert(restantes < total_inicial, "Deben caer bloques del borde")

	# La última fase tira todo el verde: no debe quedar ninguno en pie
	assert(_contar_verdes(layer) == 0, "No debe quedar andamiaje verde tras el colapso")

	# Al iniciar ronda se restaura el mapa completo, verde incluido
	mapa._on_ronda_iniciada(2)
	assert(layer.get_used_cells().size() == total_inicial, "El mapa debe restaurarse por ronda")
	assert(_contar_verdes(layer) == verdes_iniciales, "El andamiaje verde debe restaurarse por ronda")

	# Perder una vida a mitad de ronda también reinicia toda la destrucción
	for i in range(10):
		mapa._on_timer_timeout()
	var parcial := layer.get_used_cells().size()
	assert(parcial < total_inicial, "El colapso debe haber empezado")
	mapa._on_vida_perdida(1, 1)
	assert(layer.get_used_cells().size() == total_inicial, "Perder una vida debe restaurar el mapa")
	assert(mapa._fase == mapa.Fase.GRACIA, "Perder una vida debe reiniciar la fase del colapso")
	assert(_contar_verdes(layer) == verdes_iniciales, "Perder una vida debe restaurar el andamiaje verde")

	print("✓ Colapso de El Péndulo: cae del borde al centro, el verde cae al final y todo se rehace al reiniciar")
	mapa.free()
	get_tree().quit(0)


func _contar_verdes(layer: TileMapLayer) -> int:
	var total := 0
	for c in layer.get_used_cells():
		if layer.get_cell_source_id(c) == SOURCE_VERDE and layer.get_cell_atlas_coords(c) == ATLAS_VERDE:
			total += 1
	return total
