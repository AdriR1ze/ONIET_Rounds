class_name UpgradeDefinition
extends Resource

enum Rareza {
	COMUN,
	RARA,
	EPICA,
	LEGENDARIA,
}

@export var id: StringName
@export var titulo: String
@export_multiline var descripcion: String
@export var icono: Texture2D
@export var rareza: Rareza = Rareza.COMUN
@export var tags: Array[StringName] = []
@export var max_stacks: int = 1
@export var peso: float = 1.0
@export var requiere: Array[StringName] = []
@export var stats: Array[StatModifier] = []
@export var efectos: Array[UpgradeEffect] = []


func rareza_texto() -> String:
	return String(Rareza.keys()[rareza]).capitalize()
