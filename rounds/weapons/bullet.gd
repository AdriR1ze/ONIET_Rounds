extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 2.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null


func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if shooter != null and shooter.is_ancestor_of(area):
		return
	if area.has_method("take_hit"):
		area.take_hit(damage, shooter)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if shooter != null and (body == shooter or shooter.is_ancestor_of(body)):
		return
	queue_free()
