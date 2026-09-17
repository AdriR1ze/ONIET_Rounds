extends PanelContainer

const COLORES := {
	UpgradeDefinition.Rareza.COMUN: Color(0.78, 0.8, 0.86),
	UpgradeDefinition.Rareza.RARA: Color(0.4, 0.7, 1.0),
	UpgradeDefinition.Rareza.EPICA: Color(0.78, 0.45, 1.0),
	UpgradeDefinition.Rareza.LEGENDARIA: Color(1.0, 0.75, 0.2),
}

var definicion: UpgradeDefinition = null

@onready var _titulo: Label = $Margin/VBox/Titulo
@onready var _descripcion: Label = $Margin/VBox/Descripcion
@onready var _rareza: Label = $Margin/VBox/Rareza


func configurar(def: UpgradeDefinition) -> void:
	definicion = def
	if def == null:
		return
	_titulo.text = def.titulo
	_descripcion.text = def.descripcion
	_rareza.text = "%s  •  %s" % [def.nivel_texto(), def.rareza_texto()]
	var color: Color = COLORES.get(def.rareza, Color.WHITE)
	_titulo.modulate = color
	_rareza.modulate = color


func marcar_seleccionada(seleccionada: bool) -> void:
	modulate = Color(1, 1, 1, 1) if seleccionada else Color(0.5, 0.5, 0.55, 1)
