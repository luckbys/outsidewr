@tool
class_name MorroMeshBatch
extends RefCounted
## Bake small static details into one draw surface per material.

var buckets: Dictionary = {}
static var cube: BoxMesh

func append_instance(instance: MeshInstance3D) -> void:
	for surface_index in instance.mesh.get_surface_count():
		var material := instance.get_active_material(surface_index)
		if material == null:
			continue
		if not buckets.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[material] = tool
		buckets[material].append_from(instance.mesh, surface_index, instance.global_transform)

func box(center: Vector3, dimensions: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	if cube == null:
		cube = BoxMesh.new()
		cube.size = Vector3.ONE
	if not buckets.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		buckets[material] = tool
	var transform := Transform3D(Basis.from_euler(rotation).scaled(dimensions), center)
	buckets[material].append_from(cube, 0, transform)

func beam(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var direction := to - from
	if direction.length() < 0.001:
		return
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	var rotation := Basis.looking_at(direction, up).get_euler()
	box((from + to) * 0.5, Vector3(width, width, direction.length()), material, rotation)

func finish(parent: Node3D) -> void:
	for material in buckets:
		var instance := MeshInstance3D.new()
		instance.mesh = buckets[material].commit()
		instance.material_override = material
		parent.add_child(instance)
