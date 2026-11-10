@tool
class_name MorroMaterials
extends RefCounted
## Shared, meter-scale surface textures. No external downloads or render plugins.

static var materials: Dictionary = {}
static var textures: Dictionary = {}

static func surface(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + tint.to_html()
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.roughness = 0.93
	result.uv1_triplanar = true
	result.uv1_world_triplanar = true
	result.uv1_scale = Vector3.ONE * (0.5 if kind == "asphalt" else 1.0)
	if not textures.has(kind):
		textures[kind] = make_textures(kind)
	result.albedo_texture = textures[kind][0]
	result.normal_enabled = true
	result.normal_texture = textures[kind][1]
	result.normal_scale = 0.4 if kind == "brick" else 0.25
	materials[key] = result
	return result

static func make_textures(kind: String) -> Array[ImageTexture]:
	const N := 128
	var image := Image.create(N, N, false, Image.FORMAT_RGB8)
	var normal := Image.create(N, N, false, Image.FORMAT_RGB8)
	var heights := PackedFloat32Array()
	heights.resize(N * N)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for y in N:
		for x in N:
			var grain := rng.randf_range(-0.09, 0.09)
			var broad := sin(x * 0.085) * sin(y * 0.14) * 0.055
			var value := 0.88 + grain + broad
			var depth := grain * 0.14
			if kind == "brick":
				var row := y / 11
				var seam := (x + (16 if row % 2 == 0 else 0)) % 32
				var joint := y % 11 <= 1 or seam <= 1
				value = (0.48 if joint else 0.87 + sin(row * 37.0 + x / 32 * 23.0) * 0.1) + grain
				depth = 0.0 if joint else 0.38 + grain * 0.2
			elif kind == "plaster":
				var worn := sin(x * 0.13 + sin(y * 0.05) * 3) * cos(y * 0.095)
				value -= maxf(0, worn - 0.2) * 0.26
			elif kind == "asphalt":
				value += grain * 0.7
			elif kind == "metal":
				value -= 0.23 if y % 14 < 3 else 0.0
				depth += sin(y * TAU / 14.0) * 0.17
			image.set_pixel(x, y, Color(value, value * 0.99, value * 0.96))
			heights[y * N + x] = depth
	for y in N:
		for x in N:
			var dx := heights[y * N + (x + 1) % N] - heights[y * N + (x + N - 1) % N]
			var dy := heights[((y + 1) % N) * N + x] - heights[((y + N - 1) % N) * N + x]
			var vector := Vector3(-dx, -dy, 0.6).normalized()
			normal.set_pixel(x, y, Color(vector.x * 0.5 + 0.5, vector.y * 0.5 + 0.5, vector.z * 0.5 + 0.5))
	image.generate_mipmaps()
	normal.generate_mipmaps()
	return [ImageTexture.create_from_image(image), ImageTexture.create_from_image(normal)]

static func solid(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not materials.has(key):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.88
		materials[key] = result
	return materials[key]
