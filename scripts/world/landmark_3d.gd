@tool
extends Marker3D
## Visible objective placeholders, independent from the 2D combat simulation.

@export var label_text := "CENTRAL":
	set(value):
		label_text = value
		refresh()
@export var accent := Color("57bde8"):
	set(value):
		accent = value
		refresh()
@export_range(0.8, 4.0, 0.1) var column_height := 1.8:
	set(value):
		column_height = value
		refresh()

func _ready() -> void:
	update_layout()

func refresh() -> void:
	if is_node_ready():
		update_layout()

func update_layout() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = accent
	material.roughness = 0.85
	$Platform.material_override = material
	$Flag.material_override = material
	$Column.scale.y = column_height
	$Column.position.y = column_height * 0.5 + 0.15
	$Pole.position.y = column_height + 0.95
	$Flag.position = Vector3(0.45, column_height + 1.15, 0)
	$Label.position.y = column_height + 2.1
	$Label.text = label_text
