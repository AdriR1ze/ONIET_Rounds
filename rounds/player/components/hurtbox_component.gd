class_name HurtboxComponent
extends Area2D

signal hurt(amount: int, source: Node)
signal parried(bullet: Node)

# Estado deseado del hurtbox. El dueno (Player) lo cambia en muerte/respawn y el
# componente reconcilia su CollisionShape2D cada frame fisico. Asi no importa el
# orden en que se apliquen los set_deferred: gana siempre el ultimo estado pedido.
var _active: bool = true


func _ready() -> void:
	_reconciliar()


func set_active(activo: bool) -> void:
	_active = activo
	_reconciliar()


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	_reconciliar()


func _reconciliar() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	if col.disabled == _active:
		col.set_deferred("disabled", not _active)


func take_hit(amount: int, source: Node = null) -> void:
	var parent: Node = get_parent()
	if parent != null and parent.has_method("is_alive") and not parent.is_alive():
		return
	hurt.emit(amount, source)


func try_parry(bullet: Node) -> bool:
	var parent: Node = get_parent()
	if parent != null and parent.has_method("can_parry") and parent.can_parry(bullet):
		if bullet.has_method("parry"):
			bullet.parry(parent)
		parried.emit(bullet)
		if parent.has_method("on_parry"):
			parent.on_parry(bullet)
		return true
	return false
