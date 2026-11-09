extends SceneTree
## Load the actual demo and query the physics/navigation servers.

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

func run() -> void:
	var scene := load("res://scenes/demo_3d.tscn") as PackedScene
	verify(scene != null, "3D demo is a loadable independent scene")
	var demo := scene.instantiate()
	root.add_child(demo)
	var district := demo.get_node("District") as Node3D
	var rig: Node3D = demo.get_node("CameraRig")
	rig.set_process(false)
	for group in ["Terrain", "Buildings", "Decoration", "Lighting", "Navigation", "PointsOfInterest"]:
		verify(district.has_node(NodePath(group)), "District has a separate " + group + " group")
	verify(district.get_node("Buildings").get_child_count() >= 16, "Editable house instances populate the district")
	var house: Node3D = district.get_node("Buildings/House01")
	var body: MeshInstance3D = house.get_node("Body")
	var shape: CollisionShape3D = house.get_node("Collision/Shape")
	verify(is_equal_approx(body.scale.y, house.building_height), "House geometry respects dimensions in meters")
	verify(shape.shape.size.is_equal_approx(body.scale), "House collision follows its actual dimensions")
	verify(district.get_node("PointsOfInterest/PoliceCore").position.x < 0
		and district.get_node("PointsOfInterest/TrafficCore").position.x > 0,
		"The two factions have separate objective locations")
	verify(get_nodes_in_group("spawn_points").size() == 2, "Both factions have explicit spawn markers")
	verify(get_nodes_in_group("barricades").size() == 4, "Four barricade models replace the former tower markers")
	verify(get_nodes_in_group("hero_previews").size() == 2 and get_nodes_in_group("minion_previews").size() == 6,
		"The demonstration includes both heroes and three minions per team")
	var concrete: MeshInstance3D = district.get_node("PointsOfInterest/PoliceBarricade2/Concrete")
	verify(concrete.mesh is ArrayMesh and concrete.get_aabb().size.y > 1,
		"The concrete barrier has actual sloped geometry at human scale")
	var normals: PackedVector3Array = concrete.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	verify(normals[0].z < -0.9 and normals[-1].x > 0.9, "Barrier surfaces have outward-facing normals")
	var police: Node3D = district.get_node("Units/PoliceHero/Character")
	var traffic: Node3D = district.get_node("Units/TrafficHero/Character")
	verify(police.get_node("Rig/Head/Helmet").visible and not traffic.get_node("Rig/Head/Helmet").visible
		and traffic.get_node("Rig/Backpack").visible, "The factions have distinct wearable equipment")
	var minion: Node3D = district.get_node("Units/PoliceMinion1")
	var initial_minion_position := minion.position
	minion._process(1.0)
	verify(minion.position.distance_to(initial_minion_position) > 1 and minion.get_node("Character").walking,
		"The minion preview moves along its patrol with walking enabled")
	var camera: Camera3D = rig.get_node("Camera3D")
	verify(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.current,
		"Demo uses the active orthographic camera")
	var initial_position := rig.position
	rig.pan(Vector2(5, 0))
	verify(rig.position.distance_to(initial_position) > 4.9, "Camera pan moves through the environment")
	rig.pan(Vector2(10000, 10000))
	verify(absf(rig.position.x) <= 36 and absf(rig.position.z) <= 26,
		"Camera pan stays inside inspection bounds")
	rig.zoom(100)
	verify(is_equal_approx(camera.size, 12), "Camera zoom has a near limit")
	rig.zoom(-100)
	verify(is_equal_approx(camera.size, 110), "Camera zoom has a far limit")
	rig.orbit(Vector2(30, 100))
	verify(is_equal_approx(rig.elevation, 75), "Camera orbit keeps a useful overhead angle")
	rig.reset_view()
	verify(rig.position.is_equal_approx(Vector3.ZERO) and is_equal_approx(camera.size, 96),
		"Reset restores the district overview")
	demo.navigation_button.button_pressed = true
	demo.toggle_navigation()
	verify(district.get_node("Navigation/Preview").visible, "Navigation preview can be shown")
	# Allow both the navigation server and physics broadphase to synchronize.
	await physics_frame
	await physics_frame
	var world := district.get_world_3d()
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 15, 0), Vector3(0, -2, 0))
	var hit := world.direct_space_state.intersect_ray(ray)
	verify(not hit.is_empty() and hit.collider.is_in_group("world_ground"),
		"The terrain has an actual ground collision")
	var checkpoint: Node3D = district.get_node("PointsOfInterest/PoliceBarricade2")
	var checkpoint_ray := PhysicsRayQueryParameters3D.create(checkpoint.global_position + Vector3.UP * 4,
		checkpoint.global_position - Vector3.UP)
	var checkpoint_hit := world.direct_space_state.intersect_ray(checkpoint_ray)
	verify(not checkpoint_hit.is_empty() and checkpoint_hit.collider.is_in_group("barricade_collision"),
		"Barricades have an actual static collision")
	var navigation: NavigationRegion3D = district.get_node("Navigation/Lane")
	verify(navigation.navigation_mesh.get_polygon_count() > 0, "The lane has navigation polygons")
	# Navigation rebuilds asynchronously after physics registration.
	for frame in 60:
		if NavigationServer3D.map_get_iteration_id(world.navigation_map) > 0:
			break
		await physics_frame
	verify(NavigationServer3D.map_get_iteration_id(world.navigation_map) > 0,
		"The navigation map completes its initial synchronization")
	var route := PackedVector3Array()
	# The region's mesh update can arrive after the map's first empty iteration.
	for frame in 60:
		route = NavigationServer3D.map_get_path(world.navigation_map,
			Vector3(-25.5, 0.06, -1.5), Vector3(25.5, 0.06, -1.5), true)
		if route.size() >= 2:
			break
		await physics_frame
	verify(route.size() >= 2 and route[0].distance_to(route[-1]) > 50,
		"Navigation server finds a route between the two spawns")
	var nearest := NavigationServer3D.map_get_closest_point(world.navigation_map, checkpoint.global_position)
	var safe_ray := PhysicsRayQueryParameters3D.create(nearest + Vector3.UP * 4, nearest - Vector3.UP)
	var safe_hit := world.direct_space_state.intersect_ray(safe_ray)
	verify(not safe_hit.is_empty() and safe_hit.collider.is_in_group("world_ground"),
		"The navigable corridor stays outside the barricade collision")
	verify(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main.tscn",
		"The default project entry remains the existing 2D game")
	verify(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility",
		"The project keeps the web-compatible Compatibility renderer")
	print("\n%d 3D checks, %d failures" % [checks, failures])
	demo.free()
	await process_frame
	quit(1 if failures else 0)
