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
		body.material_override = facade_material
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
