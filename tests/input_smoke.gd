extends SceneTree
## Exercise the GUI and input dispatch rather than calling match commands directly.

var failures := 0
var checks := 0

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
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = InputEventKey.new()
	event.physical_keycode = code
	root.push_input(event, true)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func run() -> void:
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	await process_frame
	var button: Button = arena.hud.coral_button
	click(button.get_global_rect().get_center())
	await process_frame
	verify(arena.state == arena.State.PLAYING and arena.player_team == 1,
		"Clicking the Coral button starts the selected faction")
	verify(not arena.hud.overlay.visible, "Starting a match dismisses the selection overlay")
	key(KEY_Q)
	verify(arena.pulse_timer > 0, "Keyboard Q dispatches to the ability")
	key(KEY_ESCAPE)
	verify(arena.paused and arena.hud.overlay.visible, "Escape opens the pause screen")
	var cooldown: float = arena.dash_timer
	key(KEY_E)
	verify(arena.dash_timer == cooldown, "Gameplay input is blocked while paused")
	click(arena.hud.secondary_button.get_global_rect().get_center())
	verify(not arena.paused and not arena.hud.overlay.visible, "Continue button resumes the match")
	# A keyboard-activated skill button must not also consume Space as a game command.
	arena.command_move(Vector2.ZERO)
	key(KEY_SPACE)
	verify(arena.player.destination == arena.player.world_position,
		"Space stops movement after using the menu")
	print("\n%d input checks, %d failures" % [checks, failures])
	arena.free()
	await process_frame
	quit(1 if failures else 0)
