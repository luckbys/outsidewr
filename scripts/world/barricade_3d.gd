@tool
extends Marker3D
## A concrete checkpoint prop. Its collision is part of the static world.

@export var label_text := "BARRICADA":
	set(value):
		label_text = value
		refresh()
@export var accent := Color("57bde8"):
	set(value):
		accent = value
		refresh()

static var jersey_mesh: ArrayMesh

func _ready() -> void:
	update_visuals()

func refresh() -> void:
	if is_node_ready():
		update_visuals()

func update_visuals() -> void:
	if jersey_mesh == null:
		jersey_mesh = FieldGeometry3D.extruded_profile(PackedVector2Array([
			Vector2(-0.55, 0), Vector2(-0.55, 0.18), Vector2(-0.3, 0.55),
			Vector2(-0.2, 1.08), Vector2(0.2, 1.08), Vector2(0.3, 0.55),
			Vector2(0.55, 0.18), Vector2(0.55, 0)
		]), 3.4)
	$Concrete.mesh = jersey_mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = accent.darkened(0.12)
	paint.roughness = 0.8
	$TeamPlate.material_override = paint
	$Label.text = label_text
