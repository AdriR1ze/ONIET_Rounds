class_name BotSteering
extends RefCounted

## Steering Behaviors para cálculo de fuerzas físicas inmediatas de movimiento.
## Se encarga del "CÓMO": calcular los ejes de desplazamiento horizontal (Seek,
## Flee, Arrive, Strafe, Path Following) y la detección de peligros en el suelo
## (abismo, ácido/HazardZone y pinchos).

const STOP_THRESHOLD := 6.0
const WORLD_MASK := 1 | 64 # Sólido (1) + Plataforma One-Way (64)


## Seek: Empuja con fuerza máxima hacia el objetivo horizontal.
func seek(current_x: float, target_x: float) -> float:
	var dx := target_x - current_x
	if absf(dx) < STOP_THRESHOLD:
		return 0.0
	return 1.0 if dx > 0.0 else -1.0


## Arrive: Se aproxima al objetivo y frena suavemente al entrar en el radio de frenado.
func arrive(current_x: float, target_x: float, slowing_radius: float = 48.0) -> float:
	var dx := target_x - current_x
	var dist := absf(dx)
	if dist < STOP_THRESHOLD:
		return 0.0
	var speed_factor := clampf(dist / maxf(slowing_radius, 1.0), 0.25, 1.0)
	return (1.0 if dx > 0.0 else -1.0) * speed_factor


## Flee: Huye en dirección contraria a una amenaza.
func flee(current_x: float, threat_x: float) -> float:
	var dx := current_x - threat_x
	if absf(dx) < STOP_THRESHOLD:
		return -1.0 if int(current_x) % 2 == 0 else 1.0
	return 1.0 if dx > 0.0 else -1.0


## Strafe: Movimiento lateral oscilante para combate a distancia.
func strafe(current_dir: float, speed_mult: float = 0.8) -> float:
	return signf(current_dir) * clampf(speed_mult, 0.2, 1.0)


## Path Following: Avanza a través de una lista de waypoints generada por NavGraph.
func follow_path(current_pos: Vector2, path: PackedVector2Array, current_idx: int, arrival_radius: float = 36.0) -> Dictionary:
	if path.is_empty():
		return {"target": current_pos, "index": 0, "finished": true, "move_axis": 0.0}
	
	var idx := clampi(current_idx, 0, path.size() - 1)
	var wp := path[idx]
	var dist := current_pos.distance_to(wp)

	# Avanzar al siguiente waypoint si:
	# 1. Ya estamos dentro del radio de llegada.
	# 2. O estamos más cerca del siguiente punto que del actual.
	# 3. O ya alcanzamos el punto horizontalmente en una maniobra de descenso vertical.
	while idx < path.size() - 1:
		var next_wp := path[idx + 1]
		var next_dist := current_pos.distance_to(next_wp)
		var reached_horizontally := absf(wp.x - current_pos.x) < 16.0
		var is_descending := wp.y > current_pos.y + 18.0
		if dist < arrival_radius or next_dist < dist or (reached_horizontally and is_descending and current_pos.y >= wp.y - 16.0):
			idx += 1
			wp = path[idx]
			dist = current_pos.distance_to(wp)
		else:
			break

	var finished := (idx >= path.size() - 1) and (dist < arrival_radius or absf(wp.x - current_pos.x) < STOP_THRESHOLD)
	var move_axis := 0.0
	if not finished:
		# Entre plataformas y waypoints intermedios se requiere velocidad completa
		move_axis = seek(current_pos.x, wp.x)
		# Si ya estamos alineados horizontalmente con este punto intermedio pero hay más camino, orientar al siguiente
		if is_zero_approx(move_axis) and idx < path.size() - 1:
			move_axis = seek(current_pos.x, path[idx + 1].x)

	return {
		"target": wp,
		"index": idx,
		"finished": finished,
		"move_axis": move_axis
	}


## Sonda el entorno frente al bot para detectar si hay vacío (abismo), pinchos o HazardZone.
func check_hazard_ahead(space: PhysicsDirectSpaceState2D, player: CharacterBody2D, move_dir: float, lookahead: float, tilemap: TileMapLayer = null) -> Dictionary:
	var result := {
		"hazard_ahead": false,
		"abyss_ahead": false,
		"spikes_ahead": false,
		"safe_jump_available": false,
		"safe_landing_pos": Vector2.ZERO
	}

	if space == null or player == null or is_zero_approx(move_dir):
		return result

	var my_pos := player.global_position
	var probe_cerca := Vector2(my_pos.x + move_dir * 24.0, my_pos.y + 12.0)
	var probe_lejos := Vector2(my_pos.x + move_dir * lookahead, my_pos.y + 12.0)

	var ground_cerca := _probe_ground(space, player, probe_cerca, 130.0)
	var ground_lejos := _probe_ground(space, player, probe_lejos, 130.0)

	# 1. Comprobar abismo (no hay suelo delante)
	if not ground_cerca["hit"] or not ground_lejos["hit"]:
		result["abyss_ahead"] = true
		result["hazard_ahead"] = true

	# 2. Comprobar si el suelo detectado está en una zona de peligro (HazardZone o Pinchos)
	if ground_cerca["hit"] and is_point_hazardous(space, ground_cerca["position"], tilemap):
		result["spikes_ahead"] = true
		result["hazard_ahead"] = true
	elif ground_lejos["hit"] and is_point_hazardous(space, ground_lejos["position"], tilemap):
		result["spikes_ahead"] = true
		result["hazard_ahead"] = true

	# 3. Si hay peligro adelante, comprobar si hay un salto seguro hacia adelante
	if result["hazard_ahead"]:
		for d_salto in [80.0, 130.0, 180.0, 230.0, 280.0, 320.0]:
			for dy in [-70.0, 0.0, 50.0, 110.0]:
				var test_pos := Vector2(my_pos.x + move_dir * d_salto, my_pos.y + dy)
				var land := _probe_ground(space, player, test_pos, 70.0)
				if land["hit"] and not is_point_hazardous(space, land["position"], tilemap):
					if can_character_fit(space, land["position"]):
						result["safe_jump_available"] = true
						result["safe_landing_pos"] = land["position"]
						break
			if result["safe_jump_available"]:
				break

	return result


## Comprueba si un punto en el mundo coincide con una zona letal o pinchos.
func is_point_hazardous(space: PhysicsDirectSpaceState2D, point: Vector2, tilemap: TileMapLayer = null) -> bool:
	if space == null:
		return false

	# 1. Chequeo por Area2D (HazardZone / Pincho)
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := space.intersect_point(query, 6)
	for h in hits:
		var col = h.get("collider")
		if col != null:
			if col is HazardZone:
				return true
			var s: Script = col.get_script()
			if s != null and (s.resource_path.ends_with("hazard_zone.gd") or s.resource_path.ends_with("pincho.gd")):
				return true
			if col.is_in_group("hazard") or col.is_in_group("deadzone") or col.is_in_group("spikes") or col.is_in_group("pincho"):
				return true

	# 2. Chequeo por celda del TileMapLayer (source_id 6 = pincho)
	if tilemap != null and is_instance_valid(tilemap):
		var cell := tilemap.local_to_map(tilemap.to_local(point))
		if tilemap.get_cell_source_id(cell) == 6 or tilemap.get_cell_source_id(cell + Vector2i(0, -1)) == 6:
			return true

	return false


func _probe_ground(space: PhysicsDirectSpaceState2D, player: CharacterBody2D, from: Vector2, depth: float) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, depth), WORLD_MASK)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {"hit": false, "position": Vector2.ZERO}
	return {"hit": true, "position": hit.position}


## Comprueba si el personaje cabe físicamente en una posición (ancho 20, alto 36) sin chocar con paredes.
func can_character_fit(space: PhysicsDirectSpaceState2D, pos: Vector2) -> bool:
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 36.0)
	query.shape = shape
	query.transform = Transform2D(0.0, pos - Vector2(0.0, 18.0))
	query.collision_mask = 1 # Solo paredes sólidas
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()
