# Renders a scene and saves a PNG. Not headless (needs a GPU).
# Run: godot --path . --script res://tools/screenshot.gd -- <scene.tscn> <out.png> [seconds] [setup]
# setup: optional "dose" to take a pill first, "crash" to skip to the crash.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/levels/district.tscn"
	var out: String = args[1] if args.size() > 1 else "user://shot.png"
	var seconds: float = float(args[2]) if args.size() > 2 else 1.0
	var setup: String = args[3] if args.size() > 3 else ""
	root.size = Vector2i(1280, 720)
	var level: Node = load(scene_path).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var player := level.get_node_or_null("Player")
	if player and setup != "":
		var dose: Dose = player.dose
		dose.add_pills(1)
		dose.take()
		if setup == "crash":
			dose.time_left = 0.01
	var t := 0.0
	while t < seconds:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
