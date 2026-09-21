@tool
class_name GeometricPlatform
extends StaticBody2D

@export var border_color: Color = Color(0.2, 0.85, 1.0, 1.0):
	set(val):
		border_color = val
		queue_redraw()

@export var fill_color: Color = Color(0.04, 0.08, 0.14, 0.95):
	set(val):
		fill_color = val
		queue_redraw()

@export var border_width: float = 3.0:
	set(val):
		border_width = val
		queue_redraw()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
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
				_draw_transformed_rect(trans, rect)
			elif shape is CircleShape2D:
				var circle_shape := shape as CircleShape2D
				var rad: float = circle_shape.radius
				_draw_transformed_circle(trans, rad)
			elif shape is CapsuleShape2D:
				var cap_shape := shape as CapsuleShape2D
				var rad: float = cap_shape.radius
				var height: float = cap_shape.height
				_draw_transformed_capsule(trans, rad, height)
		elif child is CollisionPolygon2D:
			var col_poly := child as CollisionPolygon2D
			var poly: PackedVector2Array = col_poly.polygon
			if poly.size() >= 3:
				var trans: Transform2D = col_poly.transform
				var transformed_poly := PackedVector2Array()
				for pt in poly:
					transformed_poly.append(trans * pt)
				draw_polygon(transformed_poly, PackedColorArray([fill_color]))
				var outline := Array(transformed_poly)
				outline.append(transformed_poly[0])
				draw_polyline(PackedVector2Array(outline), border_color, border_width)


func _draw_transformed_rect(trans: Transform2D, rect: Rect2) -> void:
	var corners := PackedVector2Array([
		trans * rect.position,
		trans * Vector2(rect.position.x + rect.size.x, rect.position.y),
		trans * (rect.position + rect.size),
		trans * Vector2(rect.position.x, rect.position.y + rect.size.y),
	])
	draw_polygon(corners, PackedColorArray([fill_color]))
	var outline := Array(corners)
	outline.append(corners[0])
	draw_polyline(PackedVector2Array(outline), border_color, border_width)


func _draw_transformed_circle(trans: Transform2D, radius: float) -> void:
	var segments := 32
	var pts := PackedVector2Array()
	for i in range(segments):
		var angle := (float(i) / float(segments)) * TAU
		var local_pt := Vector2(cos(angle) * radius, sin(angle) * radius)
		pts.append(trans * local_pt)
	draw_polygon(pts, PackedColorArray([fill_color]))
	var outline := Array(pts)
	outline.append(pts[0])
	draw_polyline(PackedVector2Array(outline), border_color, border_width)


func _draw_transformed_capsule(trans: Transform2D, radius: float, height: float) -> void:
	var half_len: float = maxf(0.0, (height * 0.5) - radius)
	var segments := 24
	var pts := PackedVector2Array()

	# Semicírculo superior
	for i in range(segments / 2 + 1):
		var angle := PI + (float(i) / float(segments / 2)) * PI
		var pt := Vector2(cos(angle) * radius, -half_len + sin(angle) * radius)
		pts.append(trans * pt)

	# Semicírculo inferior
	for i in range(segments / 2 + 1):
		var angle := (float(i) / float(segments / 2)) * PI
		var pt := Vector2(cos(angle) * radius, half_len + sin(angle) * radius)
		pts.append(trans * pt)

	draw_polygon(pts, PackedColorArray([fill_color]))
	var outline := Array(pts)
	outline.append(pts[0])
	draw_polyline(PackedVector2Array(outline), border_color, border_width)
