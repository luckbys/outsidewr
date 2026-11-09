class_name FieldGeometry3D
extends RefCounted
## Shared, low-poly meshes with meter-scale dimensions and flat surface normals.

static func extruded_profile(profile: PackedVector2Array, length: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var half := length * 0.5
	for i in profile.size():
		var next := (i + 1) % profile.size()
		var a := Vector3(-half, profile[i].y, profile[i].x)
		var b := Vector3(half, profile[i].y, profile[i].x)
		var c := Vector3(half, profile[next].y, profile[next].x)
		var d := Vector3(-half, profile[next].y, profile[next].x)
		quad(tool, a, b, c, d)
	for end in [-1, 1]:
		for i in range(1, profile.size() - 1):
			var a := Vector3(end * half, profile[0].y, profile[0].x)
			var b := Vector3(end * half, profile[i].y, profile[i].x)
			var c := Vector3(end * half, profile[i + 1].y, profile[i + 1].x)
			if end == -1:
				triangle(tool, a, b, c)
			else:
				triangle(tool, a, c, b)
	tool.generate_normals()
	return tool.commit()

static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	triangle(tool, a, b, c)
	triangle(tool, a, c, d)

static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		tool.set_uv(Vector2(point.x + point.z, point.y))
		tool.add_vertex(point)
