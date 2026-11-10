extends Control
## Static low-resolution city panorama, rendered once and softly blurred.
## Separate from gameplay so depth-of-field never blurs units or their targets.

var terrain: MeshInstance3D

func hill(x: float, z: float) -> float:
	var left := 65 * exp(-pow((x + 150) / 120, 2) - pow((z + 260) / 220, 2))
	var right := 95 * exp(-pow((x - 150) / 110, 2) - pow((z + 230) / 180, 2))
	return 4 + left + right + sin(x * 0.021 + 0.8) * 6 + cos(z * 0.027 - x * 0.01) * 5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.gui_disable_input = true
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var background := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b7b3a3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8c7bd")
	environment.ambient_light_energy = 0.6
	background.environment = environment
	world.add_child(background)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_color = Color("ffe1b4")
	light.light_energy = 0.85
	world.add_child(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = 98761
	var batch := MorroMeshBatch.new()
	var palette := [Color("9f8473"), Color("9c8c76"), Color("b0a28c"), Color("808f86"), Color("91705e"), Color("9a9b8b")]
	var roof := MorroMaterials.solid(Color("8d897b"))
	for z in range(-450, 45, 12):
		for x in range(-300, 301, 12):
			if rng.randf() < 0.13:
				continue
			var px := x + rng.randf_range(-1.8, 1.8)
			var pz := z + rng.randf_range(-1.8, 1.8)
			var height := rng.randf_range(3.0, 9.0)
			var size := Vector3(rng.randf_range(5.5, 9.0), height, rng.randf_range(5.5, 9.0))
			var center := Vector3(px, hill(px, pz) + height * 0.5, pz)
			batch.box(center, size, MorroMaterials.solid(palette[rng.randi_range(0, palette.size() - 1)]))
			batch.box(center + Vector3(0, height * 0.5, 0), Vector3(size.x + 0.2, 0.2, size.z + 0.2), roof)
	batch.finish(world)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-520, 65, 10):
		for x in range(-360, 365, 10):
			for offset in [Vector2(0, 0), Vector2(10, 10), Vector2(0, 10), Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]:
				tool.add_vertex(Vector3(x + offset.x, hill(x + offset.x, z + offset.y), z + offset.y))
	tool.generate_normals()
	terrain = MeshInstance3D.new()
	terrain.mesh = tool.commit()
	terrain.material_override = MorroMaterials.solid(Color("737967"))
	world.add_child(terrain)
	var camera := Camera3D.new()
	camera.position = Vector3(70, 52, 105)
	camera.far = 1000
	camera.fov = 65
	world.add_child(camera)
	camera.look_at(Vector3(0, -15, -45))
	camera.current = true
	var image := TextureRect.new()
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur := ShaderMaterial.new()
	blur.shader = preload("res://assets/shaders/backdrop_blur.gdshader")
	image.material = blur
	add_child(image)
