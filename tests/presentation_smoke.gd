extends SceneTree
## Verify that the real 3D presentation stays aligned with the playable match.

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

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func run() -> void:
	create_timer(20).timeout.connect(func() -> void:
		push_error("3D presentation checks timed out")
		quit(1))
	root.size = Vector2i(1440, 900)
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.start_match(0)
	await process_frame
	var view: Control = arena.presentation
	verify(view.enabled and view.viewport.own_world_3d and not arena.actor_root.visible,
		"The playable scene starts with its independent 3D presentation")
	view.sync_units()
	verify(view.views.size() == arena.units.size(), "Every initial combat unit has a live 3D model")
	var panorama: Control = view.get_child(0)
	var normals: PackedVector3Array = panorama.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	verify(normals[0].y > 0.3, "Backdrop hills have upward-facing surfaces instead of being culled from above")
	for dimensions in [Vector2i(1440, 900), Vector2i(1024, 512), Vector2i(800, 600), Vector2i(480, 800)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var aligned := true
		for point in [Vector2(-540, 0), Vector2(140, 50), Vector2(300, -80), Vector2.ZERO]:
			var expected: Vector2 = arena.world.get_global_transform_with_canvas() * Iso.project(point)
			aligned = aligned and view.project(point).distance_to(expected) < 0.05
		verify(aligned, "3D projection, world picking and range rings align at %s" % dimensions)
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	var defense: UnitActor
	for unit in arena.units:
		if unit.team == 1 and unit.role == UnitActor.Role.BARRICADE:
			defense = unit
			break
	click(view.project(defense.world_position, 0.6))
	verify(arena.player.attack_target == defense, "Clicking the actual rendered barricade center selects that defense")
	arena.command_move(Vector2(-200, -50))
	arena.simulate(0.1)
	view.sync_units()
	var model: Node3D = view.views[arena.player.get_instance_id()].root
	verify(model.position.distance_to(view.world_point(arena.player.world_position, 0.1)) < 0.0001 and model.walking,
		"The hero mesh follows actual movement and walking state in meters")
	arena.spawn_wave()
	view.sync_units()
	verify(view.views.size() == arena.units.size(), "New waves create models for the actual combat minions")
	defense.take_damage(10000, arena.player)
	arena.simulate(0.05)
	view.sync_units()
	verify(view.ruins.get_child_count() == 1 and view.views.size() == arena.units.size(),
		"A destroyed defense leaves rubble and removes its active model")
	var surviving: UnitActor
	for unit in arena.units:
		if unit.team == 1 and unit.role == UnitActor.Role.BARRICADE:
			surviving = unit
			break
	surviving.take_damage(surviving.max_hp * 0.5, arena.player)
	view.sync_units()
	var smoke: CPUParticles3D = view.views[surviving.get_instance_id()].smoke
	verify(smoke.emitting, "Smoke is emitted from an actually damaged structure")
	arena.paused = true
	var pose: Vector3 = model.get_node("Rig/LeftLeg").rotation
	arena.simulate(3)
	view.sync_units()
	verify(smoke.speed_scale == 0 and model.get_node("Rig/LeftLeg").rotation == pose,
		"Pause freezes particles and the combat-driven character pose")
	var hp: float = arena.player.hp
	var elapsed: float = arena.elapsed
	key(KEY_F2)
	verify(not view.enabled and arena.actor_root.visible and arena.world.get_node("District").visible
		and view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"F2 restores the classic 2D rendering and suspends 3D rendering")
	key(KEY_F2)
	verify(view.enabled and arena.player.hp == hp and arena.elapsed == elapsed and arena.paused,
		"Restoring 3D preserves health, time and the same paused match")
	arena.start_match(1)
	verify(view.ruins.get_child_count() == 0 and view.views.size() == 8,
		"Restart clears rubble and models from the previous match")
	var player_id: int = arena.player.get_instance_id()
	arena.player.take_damage(10000, surviving if is_instance_valid(surviving) else null)
	view.sync_units()
	verify(not view.views[player_id].root.visible, "The defeated player model is hidden during respawn")
	for i in 82:
		arena.simulate(0.1)
	view.sync_units()
	verify(arena.player.alive and arena.player.team == 1 and not view.views.has(player_id)
		and view.views[arena.player.get_instance_id()].root.visible,
		"Respawn replaces the old mesh with the correct faction's living hero")
	print("\n%d presentation checks, %d failures" % [checks, failures])
	arena.free()
	await process_frame
	quit(1 if failures else 0)
