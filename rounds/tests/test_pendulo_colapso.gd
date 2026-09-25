extends Node

const MAPA := "res://levels/maps/map_03_el_pendulo.tscn"


func _ready() -> void:
	var mapa: Node2D = (load(MAPA) as PackedScene).instantiate()
	add_child(mapa)
	await get_tree().process_frame

	var layer: TileMapLayer = mapa.get_node("NeonTileMap")
	var timer: Timer = mapa.get_node("ColapsoTimer")
	timer.stop()

	var total_inicial := layer.get_used_cells().size()
	assert(total_inicial > 0, "El mapa debe tener celdas")

	# Avanzar todas las capas (el handler se detiene solo al llegar al núcleo)
	for i in range(50):
		mapa._on_timer_timeout()
	assert(mapa._radio <= mapa.radio_nucleo, "El colapso debe terminar en el núcleo")

	# Solo sobreviven celdas dentro de las columnas del núcleo
	var limite_izq: int = int(mapa.get("_centro_x")) - int(mapa.radio_nucleo)
	var limite_der: int = int(mapa.get("_centro_x")) + int(mapa.radio_nucleo)
	for c in layer.get_used_cells():
		assert(c.x >= limite_izq and c.x <= limite_der, "Celda %s quedó fuera del núcleo (límites %d..%d)" % [c, limite_izq, limite_der])

	var restantes := layer.get_used_cells().size()
	assert(restantes > 0, "Debe quedar el centro")
	assert(restantes < total_inicial, "Deben caer bloques del borde")

	# Al iniciar ronda se restaura el mapa completo
	mapa._on_ronda_iniciada(2)
	assert(layer.get_used_cells().size() == total_inicial, "El mapa debe restaurarse por ronda")

	print("✓ Colapso de El Péndulo: cae del borde al centro, queda el núcleo y se restaura por ronda")
	mapa.free()
	get_tree().quit(0)
