extends SceneTree
## Requires a real display (or X11 dummy display); headless has no rendered pixels.
## godot --path . --script tools/capture_preview.gd -- /tmp/morro-preview

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if args.size() > 0 else "user://preview"
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1440, 900)
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("factions.png"))
	arena.start_match(0)
	arena.command_move(Vector2(-60, -45))
	for i in 190:
		arena.simulate(0.1)
	arena.notice_timer = 0
	arena.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("match.png"))
	print("Previews saved to ", directory)
	arena.free()
	quit()
