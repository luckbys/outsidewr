@tool
class_name TripoAssetLibrary
extends RefCounted
## Local GLB imports only. Generation and credentials belong to the offline tool.

const ROOT := "res://assets/models/tripo/"
const IDS := ["house_brick", "house_plaster", "barricade", "water_tank",
	"police_hero", "traffic_hero", "police_minion", "traffic_minion"]
static var scenes: Dictionary = {}

static func available(id: String) -> bool:
	return id in IDS and ResourceLoader.exists(ROOT + id + ".glb")

static func create(id: String, target_size: Vector3) -> Node3D:
	if not available(id):
		return null
	if not scenes.has(id):
		var resource := ResourceLoader.load(ROOT + id + ".glb")
		if not resource is PackedScene:
			push_warning("Modelo Tripo não importado: " + id)
			return null
		scenes[id] = resource
	return from_scene(scenes[id], target_size)

static func from_scene(scene: PackedScene, target_size: Vector3) -> Node3D:
	var content := scene.instantiate() as Node3D
	if content == null:
		return null
	var bounds := mesh_bounds(content)
	if bounds.size.y <= 0.0001:
		content.free()
		return null
	var factor := INF
	for axis in 3:
		if target_size[axis] > 0 and bounds.size[axis] > 0.0001:
			factor = minf(factor, target_size[axis] / bounds.size[axis])
	if not is_finite(factor) or factor <= 0:
		content.free()
		return null
	var wrapper := Node3D.new()
	wrapper.name = "GeneratedAsset"
	var offset := Node3D.new()
	offset.name = "GroundAlignment"
	wrapper.add_child(offset)
	offset.add_child(content)
	# Preserve the imported scene's root transform, hierarchy, skin and clips.
	offset.scale = Vector3.ONE * factor
	offset.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	return wrapper

static func mesh_bounds(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	var result := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh != null:
		result = transform * node.mesh.get_aabb()
		found = true
	for child in node.get_children():
		var bounds := mesh_bounds(child, transform)
		if bounds.size.length_squared() > 0:
			result = result.merge(bounds) if found else bounds
			found = true
	return result

static func mount(parent: Node3D, id: String, target_size: Vector3) -> Node3D:
	var old := parent.get_node_or_null("GeneratedAsset")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var model := create(id, target_size)
	if model != null:
		parent.add_child(model)
	return model

static func animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var player := animation_player(child)
		if player != null:
			return player
	return null

static func walk_clip(player: AnimationPlayer) -> StringName:
	if player == null:
		return &""
	var fallback := &""
	for name in player.get_animation_list():
		if String(name).to_lower().contains("walk"):
			return StringName(name)
		if String(name).to_upper() != "RESET" and fallback == &"":
			fallback = StringName(name)
	return fallback

static func pose_walk(player: AnimationPlayer, clip_name: StringName, time: float, walking: bool) -> void:
	if player == null or clip_name == &"":
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if player.current_animation != clip_name:
		player.play(clip_name)
	var clip := player.get_animation(clip_name)
	var position := fposmod(time / 8.5, maxf(0.01, clip.length)) if walking else 0.0
	player.seek(position, true)
