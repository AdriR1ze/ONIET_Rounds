class_name PlayerInput
extends Node

@export var player_number: int = 1


func _ready() -> void:
	var value: Variant = get_parent().get("player_number")
	if value != null:
		player_number = int(value)


func move_axis() -> float:
	return Input.get_axis(_action("left"), _action("right"))


func aim() -> Vector2:
	# Stick derecho: apuntado analogico libre (si el dispositivo lo tiene).
	if InputMap.has_action(_action("aim_left")):
		var stick := Input.get_vector(
			_action("aim_left"), _action("aim_right"),
			_action("aim_up"), _action("aim_down")
		)
		if stick.length_squared() > 0.0:
			return stick

	# Fallback digital (teclado / D-pad): 8 direcciones.
	var left := Input.is_action_pressed(_action("left"))
	var right := Input.is_action_pressed(_action("right"))
	var up := Input.is_action_pressed(_action("up"))
	var down := Input.is_action_pressed(_action("down"))

	var direction := Vector2.ZERO
	if left and not right:
		direction.x = -1.0
	elif right and not left:
		direction.x = 1.0
	if up and not down:
		direction.y = -1.0
	elif down and not up:
		direction.y = 1.0
	return direction


func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed(_action("jump"))


func is_jump_just_released() -> bool:
	return Input.is_action_just_released(_action("jump"))


func is_crouch_pressed() -> bool:
	return Input.is_action_pressed(_action("down"))


func is_strafe_pressed() -> bool:
	return Input.is_action_pressed(_action("strafe"))


func is_fire_pressed() -> bool:
	return Input.is_action_pressed(_action("fire"))


func is_grab_just_pressed() -> bool:
	return Input.is_action_just_pressed(_action("grab"))


func is_ragdoll_just_pressed() -> bool:
	return Input.is_action_just_pressed(_action("ragdoll"))


func is_quack_just_pressed() -> bool:
	var act := _action("quack")
	return InputMap.has_action(act) and Input.is_action_just_pressed(act)


func is_lock_pressed() -> bool:
	return Input.is_action_pressed(_action("lock"))


func _action(name: String) -> String:
	return "p%d_%s" % [player_number, name]
