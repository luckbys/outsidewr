@tool
extends Node3D
## Appearance and joint animation only; combat is owned by the match simulation.

@export_enum("Polícia", "Tráfico") var team := 0:
	set(value):
		team = value
		refresh()
@export var hero := true:
	set(value):
		hero = value
		refresh()
@export_range(0, 3, 1) var variation := 0:
	set(value):
		variation = value
		refresh()
@export var walking := false

const SKIN := [Color("b58161"), Color("825a44"), Color("d0a080"), Color("684a3b")]
const STREET := [Color("4e5650"), Color("555153"), Color("68614f"), Color("414b54")]
var phase := 0.0
static var palette: Dictionary = {}

func _ready() -> void:
	phase = variation * 1.7 + team * 0.4
	update_appearance()

func refresh() -> void:
	if is_node_ready():
		update_appearance()

func material(color: Color) -> StandardMaterial3D:
	if not palette.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.9
		palette[color] = result
	return palette[color]

func update_appearance() -> void:
	var root := $Rig
	root.scale = Vector3.ONE * (1.04 if hero else 0.98)
	var shirt := material(Color("263b4b") if team == 0 else STREET[variation % STREET.size()])
	var pants := material(Color("283744") if team == 0 else Color("38434c"))
	var skin := material(SKIN[variation % SKIN.size()])
	var vest := material(Color("1c282d") if team == 0 else Color("3d4137"))
	var accent := material(MatchRules.FACTIONS[team].color.darkened(0.15))
	for path in ["Rig/Torso", "Rig/LeftArm/Upper", "Rig/RightArm/Upper"]:
		get_node(path).material_override = shirt
	for path in ["Rig/Pelvis", "Rig/LeftLeg/Thigh", "Rig/RightLeg/Thigh",
		"Rig/LeftLeg/Knee/Shin", "Rig/RightLeg/Knee/Shin"]:
		get_node(path).material_override = pants
	for path in ["Rig/Head/Face", "Rig/Head/EarLeft", "Rig/Head/EarRight", "Rig/Head/Nose",
		"Rig/Neck", "Rig/LeftArm/Elbow/Forearm", "Rig/RightArm/Elbow/Forearm",
		"Rig/LeftArm/Elbow/Hand", "Rig/RightArm/Elbow/Hand"]:
		get_node(path).material_override = skin
	$Rig/Vest.material_override = vest
	$Rig/LeftArm/TeamBand.material_override = accent
	$Rig/Badge.material_override = accent
	$Rig/Head/Helmet.visible = team == 0 and hero
	$Rig/Head/Cap.visible = not $Rig/Head/Helmet.visible
	$Rig/Head/Cap.material_override = shirt
	$Rig/Head/CapBrim.visible = not $Rig/Head/Helmet.visible
	$Rig/Head/CapBrim.material_override = shirt
	$Rig/Backpack.visible = team == 1 and hero
	$Rig/Radio.visible = team == 0 and hero
	$Rig/Vest.visible = team == 0 or hero
	$Rig/PouchLeft.visible = team == 0 or hero
	$Rig/PouchRight.visible = hero
	$Nameplate.visible = hero
	$Nameplate.text = "AGENTE" if team == 0 else "OLHEIRO"
	$Selection.material_override = accent
	apply_pose(0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	phase += delta * (7.5 if walking else 1.8)
	apply_pose(phase)

func apply_pose(time: float) -> void:
	var stride := sin(time) * 0.36 if walking else 0.0
	$Rig/LeftLeg.rotation.x = stride
	$Rig/RightLeg.rotation.x = -stride
	$Rig/LeftLeg/Knee.rotation.x = -maxf(0, stride) * 0.8
	$Rig/RightLeg/Knee.rotation.x = -maxf(0, -stride) * 0.8
	$Rig/LeftArm.rotation = Vector3(0.35 - stride * 0.06, 0, 0.1)
	$Rig/RightArm.rotation = Vector3(0.42 + stride * 0.06, 0, -0.1)
	$Rig/LeftArm/Elbow.rotation = Vector3(1.05, -0.7, 0)
	$Rig/RightArm/Elbow.rotation = Vector3(0.95, 0.5, 0)
	$Rig.position.y = absf(sin(time)) * 0.022 if walking else sin(time) * 0.007
