@tool
extends Node3D
## Editable blockout module. One Godot unit equals one meter.

@export var footprint := Vector2(4.4, 4.0):
	set(value):
		footprint = Vector2(maxf(value.x, 2.8), maxf(value.y, 2.8))
		refresh()
@export_range(2.6, 8.0, 0.1) var building_height := 5.4:
	set(value):
		building_height = value
		refresh()
@export var facade_material: StandardMaterial3D:
	set(value):
		facade_material = value
		refresh()
@export var water_tank := true:
	set(value):
		water_tank = value
		refresh()

func _ready() -> void:
	update_layout()

func refresh() -> void:
	if is_node_ready():
		update_layout()

func update_layout() -> void:
	var body := get_node("Body") as MeshInstance3D
	body.scale = Vector3(footprint.x, building_height, footprint.y)
	body.position.y = building_height * 0.5
	if facade_material != null:
		var variant := posmod(roundi(position.x * 3 + position.z * 5), 6)
		var brick := variant in [0, 2, 5]
		var tint := facade_material.albedo_color.lerp(Color("a56850"), 0.7) if brick else facade_material.albedo_color
		body.material_override = MorroMaterials.surface("brick" if brick else "plaster", tint)
	$Roof.material_override = MorroMaterials.surface("concrete", Color("a59a83"))
	$WaterTank/Container.material_override = MorroMaterials.surface("metal", Color("37596c"))
	$WaterTank/Lid.material_override = MorroMaterials.solid(Color("4b6b80"))
	$Roof.scale = Vector3(footprint.x + 0.18, 0.18, footprint.y + 0.18)
	$Roof.position.y = building_height + 0.09
	$Door.position = Vector3(-footprint.x * 0.17, 0.9, footprint.y * 0.5 + 0.035)
	for side in [-1, 1]:
		var suffix := "Left" if side == -1 else "Right"
		var lower := get_node("Windows/Lower" + suffix) as MeshInstance3D
		var upper := get_node("Windows/Upper" + suffix) as MeshInstance3D
		lower.position = Vector3(side * footprint.x * 0.28, 1.65, footprint.y * 0.5 + 0.04)
		upper.position = Vector3(lower.position.x, building_height - 1.1, lower.position.z)
		upper.visible = building_height >= 4.5
		var side_window := get_node("Windows/Side" + suffix) as MeshInstance3D
		side_window.position = Vector3(footprint.x * 0.5 + 0.04, 1.65, side * footprint.y * 0.25)
	$WaterTank.visible = water_tank
	$WaterTank.position = Vector3(footprint.x * 0.2, building_height + 0.18, -footprint.y * 0.15)
	$Antenna.position = Vector3(-footprint.x * 0.25, building_height + 0.18, -footprint.y * 0.2)
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x, building_height, footprint.y)
	$Collision/Shape.shape = shape
	$Collision/Shape.position.y = building_height * 0.5
	build_details()

func build_details() -> void:
	var previous := get_node_or_null("Details")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	var details := Node3D.new()
	details.name = "Details"
	add_child(details)
	# Recessed openings, frames and grilles are baked into material batches.
	$Windows.visible = false
	$Door.visible = false
	var batch := MorroMeshBatch.new()
	var concrete := MorroMaterials.surface("concrete", Color("9e998a"))
	var metal := MorroMaterials.solid(Color("424540"))
	var dark := MorroMaterials.solid(Color("202c2a"))
	var frame := MorroMaterials.solid(Color("c2b69c"))
	var wood := MorroMaterials.surface("metal", Color("645c4c"))
	var tank := MorroMaterials.solid(Color("315a69"))
	var x := footprint.x * 0.5
	var z := footprint.y * 0.5
	if posmod(roundi(position.x + position.z), 4) == 0:
		var sheet := MorroMaterials.surface("metal", Color("74766d"))
		batch.box(Vector3(0, building_height + 0.3, 0), Vector3(footprint.x, 0.08, footprint.y), sheet)
		for rib in range(1, int(footprint.x / 0.3)):
			batch.box(Vector3(-x + rib * 0.3, building_height + 0.36, 0), Vector3(0.035, 0.035, footprint.y), sheet)
	# Concrete pillars, floor slabs, a roof parapet and weather-darkened skirting.
	for side in [-1, 1]:
		batch.box(Vector3(side * (x - 0.08), building_height * 0.5, z + 0.025), Vector3(0.17, building_height, 0.09), concrete)
		batch.box(Vector3(side * x, building_height + 0.34, 0), Vector3(0.14, 0.45, footprint.y), concrete)
		batch.box(Vector3(0, building_height + 0.34, side * z), Vector3(footprint.x, 0.45, 0.14), concrete)
	batch.box(Vector3(0, 0.16, z + 0.04), Vector3(footprint.x, 0.25, 0.09), concrete)
	for floor_y in range(3, int(building_height), 3):
		batch.box(Vector3(0, floor_y, z + 0.04), Vector3(footprint.x, 0.16, 0.14), concrete)
		batch.box(Vector3(x + 0.04, floor_y, 0), Vector3(0.14, 0.16, footprint.y), concrete)
	for floor_y in [1.7, building_height - 1.1]:
		if floor_y > 2 and building_height < 4.5:
			continue
		for side in [-1, 1]:
			var p := Vector3(side * footprint.x * 0.28, floor_y, z + 0.055)
			batch.box(p, Vector3(0.88, 1.05, 0.08), frame)
			batch.box(p + Vector3(0, 0, 0.055), Vector3(0.7, 0.84, 0.05), dark)
			batch.box(p + Vector3(0, -0.53, 0.08), Vector3(1.02, 0.08, 0.24), concrete)
			for bar in [-0.23, 0.0, 0.23]:
				batch.box(p + Vector3(bar, 0, 0.1), Vector3(0.024, 0.85, 0.025), metal)
			batch.box(p + Vector3(0, 0, 0.12), Vector3(0.73, 0.026, 0.025), metal)
			var side_p := Vector3(x + 0.055, floor_y, side * footprint.y * 0.25)
			batch.box(side_p, Vector3(0.08, 1.0, 0.88), frame)
			batch.box(side_p + Vector3(0.055, 0, 0), Vector3(0.05, 0.8, 0.7), dark)
			batch.box(side_p + Vector3(0.1, 0, 0), Vector3(0.025, 0.8, 0.035), metal)
	var door := Vector3(-footprint.x * 0.17, 1.0, z + 0.09)
	batch.box(door, Vector3(1.1, 2.05, 0.1), concrete)
	batch.box(door + Vector3(0, -0.03, 0.06), Vector3(0.88, 1.85, 0.08), wood)
	for i in 9:
		batch.box(door + Vector3(0, -0.8 + i * 0.2, 0.11), Vector3(0.86, 0.025, 0.025), metal)
	batch.box(Vector3(x - 0.3, building_height * 0.5, z + 0.12), Vector3(0.055, building_height, 0.06), metal)
	# Tank ribs, antenna crossbars and roof clutter give scale without extra nodes.
	if water_tank:
		for height in [0.3, 0.58, 0.86]:
			for i in 12:
				var a := Vector3(sin(i * TAU / 12.0), 0, cos(i * TAU / 12.0)) * 0.54
				var b := Vector3(sin((i + 1) * TAU / 12.0), 0, cos((i + 1) * TAU / 12.0)) * 0.54
				batch.beam($WaterTank.position + Vector3(0, height, 0) + a, $WaterTank.position + Vector3(0, height, 0) + b, 0.04, tank)
	var aerial: Vector3 = $Antenna.position
	batch.beam(aerial + Vector3(-0.6, 1.1, 0), aerial + Vector3(0.6, 1.1, 0), 0.035, metal)
	for offset in [-0.4, 0, 0.4]:
		batch.beam(aerial + Vector3(offset, 1.1, -0.35), aerial + Vector3(offset, 1.1, 0.35), 0.025, metal)
	# A few exposed external stairs follow the facade, outside the combat lane.
	if posmod(roundi(position.x), 3) == 0 and building_height >= 4.5:
		for i in 11:
			batch.box(Vector3(x + 0.52, 0.15 + i * 0.25, -z + i * 0.33), Vector3(0.95, 0.14, 0.4), concrete)
		batch.beam(Vector3(x + 1.0, 1.0, -z), Vector3(x + 1.0, 3.6, -z + 3.5), 0.045, metal)
	batch.finish(details)
