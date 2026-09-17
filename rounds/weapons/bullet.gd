extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var pierce: int = 0
@export var knockback: float = 0.0
@export var bullet_gravity: float = 800.0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var _time_alive: float = 0.0
var player: Node = null
var effects: Array = []
var _hit_targets: Array = []


func _ready() -> void:
	if velocity == Vector2.ZERO:
		velocity = direction * speed
	rotation = velocity.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	velocity.y += bullet_gravity * delta
	position += velocity * delta
	direction = velocity.normalized()
	rotation = velocity.angle()
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func parry(new_shooter: Node) -> void:
	shooter = new_shooter
	player = new_shooter
	velocity = -velocity
	direction = velocity.normalized()
	rotation = velocity.angle()
	position += direction * 8.0
	_time_alive = 0.0
	_hit_targets.clear()
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate = Color(1.5, 1.5, 1.5, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return
	if shooter != null and (area == shooter or shooter.is_ancestor_of(area)):
		return

	if area.has_method("try_parry") and area.try_parry(self):
		return
	var parent := area.get_parent()
	if parent != null and parent.has_method("can_parry") and parent.can_parry():
		parry(parent)
		if parent.has_method("on_parry"):
			parent.on_parry(self)
		return

	if not area.has_method("take_hit"):
		return

	var dueno := area.get_parent()
	_hit_targets.append(area)
	for efecto in effects:
		efecto.on_hit(self, area, player)
	area.take_hit(damage, player)
	if knockback > 0.0 and dueno != null and dueno.has_method("apply_knockback"):
		dueno.apply_knockback(direction, knockback)

	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if shooter != null and (body == shooter or shooter.is_ancestor_of(body)):
		return
	queue_free()
