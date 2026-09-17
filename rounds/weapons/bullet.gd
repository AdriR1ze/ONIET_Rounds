extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 2.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var _time_alive: float = 0.0


func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func parry(new_shooter: Node) -> void:
	shooter = new_shooter
	direction = -direction
	rotation = direction.angle()
	position += direction * 8.0
	_time_alive = 0.0
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate = Color(1.5, 1.5, 1.5, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if shooter != null and shooter.is_ancestor_of(area):
		return
	if area.has_method("try_parry") and area.try_parry(self):
		return
	var parent := area.get_parent()
	if parent != null and parent.has_method("can_parry") and parent.can_parry():
		parry(parent)
		if parent.has_method("on_parry"):
			parent.on_parry(self)
		return
	if area.has_method("take_hit"):
		area.take_hit(damage, shooter)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if shooter != null and (body == shooter or shooter.is_ancestor_of(body)):
		return
	queue_free()
