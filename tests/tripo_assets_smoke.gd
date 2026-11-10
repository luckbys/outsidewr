extends SceneTree
## Local scene fixtures verify integration; no placeholder is installed as a Tripo model.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func fixture() -> PackedScene:
	var node := Node3D.new()
	node.name = "Fixture"
	node.position = Vector3(4, 2, -3)
	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	var box := BoxMesh.new()
	box.size = Vector3(2, 3, 4)
	mesh.mesh = box
	mesh.position = Vector3(1, 0.5, 2)
	mesh.rotation.y = 0.4
	node.add_child(mesh)
	mesh.owner = node
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	return scene

func run() -> void:
	verify(not TripoAssetLibrary.available("not_in_catalog"), "Unknown model IDs never load an arbitrary path")
	verify(TripoAssetLibrary.create("not_in_catalog", Vector3.ONE) == null, "An unavailable generated model leaves the procedural fallback available")
	var empty := Node3D.new()
	var empty_scene := PackedScene.new()
	empty_scene.pack(empty)
	empty.free()
	verify(TripoAssetLibrary.from_scene(empty_scene, Vector3.ONE) == null, "A scene without a mesh is rejected")
	var scene := fixture()
	var source := scene.instantiate()
	var source_bounds := TripoAssetLibrary.mesh_bounds(source)
	source.free()
	var model := TripoAssetLibrary.from_scene(scene, Vector3(0, 1.85, 0))
	var bounds := TripoAssetLibrary.mesh_bounds(model)
	verify(is_equal_approx(bounds.size.y, 1.85), "An imported character is scaled to meters")
	verify(absf(bounds.position.y) < 0.0001 and absf(bounds.get_center().x) < 0.0001 and absf(bounds.get_center().z) < 0.0001,
		"Nested imported transforms are centered on the ground plane")
	verify(is_equal_approx(bounds.size.x / bounds.size.y, source_bounds.size.x / source_bounds.size.y),
		"Uniform scaling preserves model proportions")
	model.free()
	model = TripoAssetLibrary.from_scene(scene, Vector3(4, 5, 2))
	bounds = TripoAssetLibrary.mesh_bounds(model)
	verify(bounds.size.x <= 4.001 and bounds.size.y <= 5.001 and bounds.size.z <= 2.001,
		"Generated scenery fits the existing collision footprint")
	model.free()
	var actor := Node3D.new()
	actor.name = "AnimationFixture"
	var body := Node3D.new()
	body.name = "Body"
	actor.add_child(body)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var clip := Animation.new()
	clip.length = 1
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath("Body:position"))
	clip.track_insert_key(track, 0, Vector3.ZERO)
	clip.track_insert_key(track, 1, Vector3(1, 0, 0))
	var library := AnimationLibrary.new()
	library.add_animation("walk", clip)
	library.add_animation("RESET", Animation.new())
	player.add_animation_library("", library)
	root.add_child(actor)
	verify(TripoAssetLibrary.animation_player(actor) == player and TripoAssetLibrary.walk_clip(player) == &"walk",
		"The imported hierarchy exposes its walk animation")
	TripoAssetLibrary.pose_walk(player, &"walk", 4.25, true)
	verify(is_equal_approx(body.position.x, 0.5), "Walk animation is driven by the supplied match time")
	var pose := body.position
	await process_frame
	await process_frame
	verify(body.position == pose, "Manual animation does not keep advancing while the match clock is frozen")
	TripoAssetLibrary.pose_walk(player, &"walk", 20, false)
	verify(body.position == Vector3.ZERO, "A stopped imported character returns to the first animation pose")
	actor.free()
	var defense: Node3D = load("res://scenes/world/modules/barricade_3d.tscn").instantiate()
	root.add_child(defense)
	verify(defense.get_node("Collision/Shape").shape != null, "The defense keeps its actual collision regardless of visual asset availability")
	defense.free()
	print("\n%d Tripo integration checks, %d failures" % [checks, failures])
	await process_frame
	quit(1 if failures else 0)
