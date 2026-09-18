class_name HazardZone
extends Area2D

@export var damage: int = 999

var _pulse_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Jugadores
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_timer += delta * 6.0
	var alpha: float = 0.8 + 0.2 * sin(_pulse_timer)
	modulate.a = alpha


func _draw() -> void:
	var has_polygon := false
	for child in get_children():
		if child is Polygon2D:
			has_polygon = true
			break
	if has_polygon:
		return

	var fill_color := Color(1.0, 0.15, 0.1, 0.88)
	var border_color := Color(1.0, 0.45, 0.1, 1.0)

	for child in get_children():
		if child is CollisionShape2D:
			var col := child as CollisionShape2D
			var shape: Shape2D = col.shape
			if shape == null:
				continue
			var trans: Transform2D = col.transform
			if shape is RectangleShape2D:
				var rect_shape := shape as RectangleShape2D
				var ext: Vector2 = rect_shape.size
				var rect := Rect2(-ext * 0.5, ext)
				var corners := PackedVector2Array([
					trans * rect.position,
					trans * Vector2(rect.position.x + rect.size.x, rect.position.y),
					trans * (rect.position + rect.size),
					trans * Vector2(rect.position.x, rect.position.y + rect.size.y),
				])
				draw_polygon(corners, PackedColorArray([fill_color]))
				var outline := Array(corners)
				outline.append(corners[0])
				draw_polyline(PackedVector2Array(outline), border_color, 2.5)
			elif shape is CircleShape2D:
				var circle_shape := shape as CircleShape2D
				var rad: float = circle_shape.radius
				var segments := 32
				var pts := PackedVector2Array()
				for i in range(segments):
					var angle := (float(i) / float(segments)) * TAU
					pts.append(trans * Vector2(cos(angle) * rad, sin(angle) * rad))
				draw_polygon(pts, PackedColorArray([fill_color]))
				var outline := Array(pts)
				outline.append(pts[0])
				draw_polyline(PackedVector2Array(outline), border_color, 2.5)


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if body.has_method("hurt"):
		body.hurt(damage, self)
	elif body.has_method("_on_died"):
		body._on_died()
