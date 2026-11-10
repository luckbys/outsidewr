@tool
extends Node3D
## Deterministic dressing, shared by the playable presentation and inspection scene.

func _ready() -> void:
	var house_scene := preload("res://scenes/world/modules/house_block_3d.tscn")
	var colors := [Color("ac6850"), Color("c5ad7f"), Color("8c9b8e"), Color("6c8b85"), Color("b38b65")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110
	if not $Buildings.has_node("Infill"):
		var infill := Node3D.new()
		infill.name = "Infill"
		$Buildings.add_child(infill)
		for z in [-18, -10, 10, 18]:
			for x in [-21, -11, -1, 9, 19, 29]:
				if z == -18 and x > 5:
					continue
				var house := house_scene.instantiate()
				house.position = Vector3(x, 0, z + rng.randf_range(-0.45, 0.45))
				house.footprint = Vector2(rng.randf_range(3.4, 4.0), rng.randf_range(3.8, 4.6))
				house.building_height = [2.9, 4.6, 5.8, 7.4][rng.randi_range(0, 3)]
				var facade := StandardMaterial3D.new()
				facade.albedo_color = colors[rng.randi_range(0, colors.size() - 1)]
				house.facade_material = facade
				infill.add_child(house)
	$Terrain/Ground/Surface.material_override = MorroMaterials.surface("concrete", Color("837766"))
	$Terrain/Ground/Surface.scale.y = 1.4
	$Terrain/Ground/Surface.position.y = -0.45
	$Terrain/TerraceWest.material_override = MorroMaterials.surface("brick", Color("675a49"))
	$Terrain/TerraceWest.position.y = -1.5
	$Terrain/TerraceWest.scale.y = 0.25
	for index in 4:
		get_node("Terrain/EdgeTerrace%d" % index).material_override = MorroMaterials.surface("concrete", Color("958b73"))
	$Terrain/Sidewalk.material_override = MorroMaterials.surface("concrete", Color("a79b83"))
	$Terrain/Road.material_override = MorroMaterials.surface("asphalt", Color("514d46"))
	$Decoration/Court.material_override = MorroMaterials.surface("concrete", Color("456d5e"))
	var sun := $Lighting/Sun as DirectionalLight3D
	sun.rotation_degrees = Vector3(-38, -43, 0)
	sun.light_color = Color("ffe1b1")
	sun.light_energy = 1.0
	sun.directional_shadow_max_distance = 180
	var environment := ($Lighting/Environment as WorldEnvironment).environment
	environment.ambient_light_color = Color("b5b6ad")
	environment.ambient_light_energy = 0.48
	if not has_node("StreetDetails"):
		build_street_details()

func build_street_details() -> void:
	var details := Node3D.new()
	details.name = "StreetDetails"
	add_child(details)
	var batch := MorroMeshBatch.new()
	var wood := MorroMaterials.surface("metal", Color("625b4c"))
	var wire := MorroMaterials.solid(Color("292e2c"))
	var concrete := MorroMaterials.surface("concrete", Color("b5a890"))
	# Utility poles and sagging wires, with supports clear of the playable corridor.
	for x in [-27, -12, 3, 18, 30]:
		for z in [-6.5, 6.5]:
			batch.box(Vector3(x, 3.4, z), Vector3(0.16, 6.8, 0.16), wood)
			batch.box(Vector3(x, 6.1, z), Vector3(0.16, 0.16, 1.7), wood)
			if x == 30:
				continue
			for cable in [-0.6, 0, 0.6]:
				for segment in 8:
					var t := segment / 8.0
					var next := (segment + 1) / 8.0
					batch.beam(Vector3(x + t * 15, 6.3 - sin(t * PI) * 1.1, z + cable),
						Vector3(x + next * 15, 6.3 - sin(next * PI) * 1.1, z + cable), 0.026, wire)
	# Curb cuts, drains and little patches at the road edges.
	for x in range(-31, 32, 4):
		batch.box(Vector3(x, 0.1, 4.4), Vector3(1.0, 0.035, 0.42), wire)
		batch.box(Vector3(x, 0.13, 4.9), Vector3(2.7, 0.12, 0.12), concrete)
		batch.box(Vector3(x, 0.13, -4.9), Vector3(2.7, 0.12, 0.12), concrete)
	batch.finish(details)
