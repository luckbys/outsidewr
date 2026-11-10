extends SceneTree
## Exercise actual GUI input, match state and container layout at different sizes.

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

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func click(point: Vector2) -> void:
	motion(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func inside(control: Control, viewport: Rect2) -> bool:
	return viewport.grow(1).encloses(control.get_global_rect())

func resize_to(dimensions: Vector2i) -> void:
	root.size = dimensions
	await process_frame
	await process_frame

func run() -> void:
	create_timer(15).timeout.connect(func() -> void:
		push_error("HUD integration checks timed out")
		quit(1))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await resize_to(Vector2i(1440, 900))
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.start_match(0)
	await process_frame
	var hud: Control = arena.hud
	for dimensions in [Vector2i(1440, 900), Vector2i(800, 600), Vector2i(480, 800)]:
		await resize_to(dimensions)
		hud.layout_controls()
		await process_frame
		var viewport := root.get_visible_rect()
		var valid := true
		for control in [hud.pulse_button, hud.dash_button, hud.retreat_button, hud.pause_button, hud.minimap]:
			valid = valid and inside(control, viewport)
		verify(valid, "Match HUD actions fit the %s viewport" % dimensions)
		verify(not hud.hero_rect.intersects(hud.skills_rect) and not hud.skills_rect.intersects(hud.minimap.get_global_rect()),
			"Hero, skills and minimap do not overlap at %s" % dimensions)
	# Decorative HUD panels consume clicks rather than ordering movement underneath.
	await resize_to(Vector2i(1440, 900))
	arena.command_move(Vector2(100, 0))
	var destination: Vector2 = arena.player.destination
	var blocked := true
	for panel_rect: Rect2 in [hud.header_rect, hud.hero_rect, hud.objective_rect, hud.target_rect, hud.hints_rect]:
		click(panel_rect.get_center())
		blocked = blocked and arena.player.destination == destination
	verify(blocked, "Clicking HUD information panels does not issue world commands")
	var goal := Vector2(180, -30)
	click(hud.minimap.get_global_transform_with_canvas() * hud.minimap.project(goal))
	verify(arena.player.destination.distance_to(goal) < 0.01,
		"Clicking the minimap converts the marker position into a single move command")
	click(hud.pause_button.get_global_rect().get_center())
	verify(arena.paused and hud.overlay.visible, "The header pause button opens the pause overlay")
	destination = arena.player.destination
	click(hud.minimap.get_global_transform_with_canvas() * hud.minimap.project(Vector2(-180, 0)))
	verify(arena.player.destination == destination, "The minimap cannot move the hero while paused")
	click(hud.secondary_button.get_global_rect().get_center())
	await process_frame
	verify(not arena.paused and not hud.overlay.visible, "The pause overlay resumes the same match")
	# The pointer over a HUD button must not replace the last world aim direction.
	arena.player.world_position = Vector2.ZERO
	arena.player.position = Vector2.ZERO
	arena.player.destination = Vector2.ZERO
	var aim := Vector2(180, 0)
	motion(arena.world.get_global_transform_with_canvas() * Iso.project(aim))
	click(hud.dash_button.get_global_rect().get_center())
	verify(arena.player.world_position.distance_to(Vector2(MatchRules.DASH_DISTANCE, 0)) < 0.01,
		"The Avanço button uses the last world aim instead of its HUD position")
	await process_frame
	verify(hud.dash_button.disabled and hud.dash_button.remaining > 0,
		"The skill card shows its actual cooldown and blocks repeated use")
	var position_before: Vector2 = arena.player.world_position
	click(hud.retreat_button.get_global_rect().get_center())
	verify(arena.player.destination == MatchRules.FACTIONS[0].spawn_point and arena.player.world_position == position_before,
		"Recuar orders movement to the central without teleporting")
	arena.command_move(Vector2(180, -50))
	key(KEY_B)
	verify(arena.player.destination == MatchRules.FACTIONS[0].spawn_point, "B activates the same retreat command")
	arena.player.hp = 60
	verify(hud.player_state() == "VIDA BAIXA / RECUE", "Low health is described from actual hero state")
	for unit in arena.units:
		if unit.team == 1 and unit.role == UnitActor.Role.BARRICADE:
			unit.take_damage(10000, arena.player)
	verify(hud.defense_count(1) == 0 and not arena.has_barricades(1),
		"Objective indicators update when the enemy central becomes vulnerable")
	arena.free()
	await process_frame
	var demo: Node = load("res://scenes/demo_3d.tscn").instantiate()
	root.add_child(demo)
	for dimensions in [Vector2i(1440, 900), Vector2i(800, 600), Vector2i(480, 800)]:
		await resize_to(dimensions)
		demo.layout_hud()
		await process_frame
		var valid := true
		for control in demo.action_flow.get_children():
			valid = valid and inside(control, root.get_visible_rect())
		verify(valid, "3D inspection buttons wrap inside the %s viewport" % dimensions)
	key(KEY_H)
	verify(demo.help_panel.visible, "H opens the 3D camera controls")
	key(KEY_H)
	key(KEY_4)
	verify(demo.view_buttons[3].button_pressed and demo.view_name == "Personagens",
		"The view shortcut updates the selected camera preset")
	key(KEY_N)
	verify(demo.district.get_node("Navigation/Preview").visible, "N toggles the real navigation preview")
	demo.free()
	await process_frame
	print("\n%d HUD checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
