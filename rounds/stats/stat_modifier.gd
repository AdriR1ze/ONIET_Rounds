class_name StatModifier
extends Resource

enum Op {
	ADD,
	MULT,
}

@export var stat: StringName
@export var op: Op = Op.ADD
@export var value: float = 1.0
