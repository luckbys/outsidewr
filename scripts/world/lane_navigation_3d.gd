@tool
extends NavigationRegion3D
## Initial, obstacle-free central corridor; side alleys are decorative in this stage.

@export var lane_length := 60.0
@export var lane_width := 8.0

func _ready() -> void:
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	var x := lane_length * 0.5
	var z := lane_width * 0.5
	mesh.set_vertices(PackedVector3Array([
		Vector3(-x, 0.06, -z), Vector3(-x, 0.06, z),
		Vector3(x, 0.06, z), Vector3(x, 0.06, -z)
	]))
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_mesh = mesh
