extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var pierce: int = 0
@export var knockback: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var player: Node = null
var effects: Array = []

var _hit_targets: Array = []


func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return
	if not area.has_method("take_hit"):
		return
	if shooter != null and (area == shooter or shooter.is_ancestor_of(area)):
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
