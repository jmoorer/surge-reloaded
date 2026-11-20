# Renders a scene and saves a PNG. Not headless (needs a GPU).
# Run: godot --path . --script res://tools/screenshot.gd -- <scene.tscn> <out.png> [seconds] [setup]
# setup: "dose" takes a pill, "crash" skips to the crash, "end" stands near extraction,
# "pause" opens the pause menu.
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
	if player:
		player.set_process_unhandled_input(false)  # Real mouse must not move the camera.
	if player and setup == "wall":
		player.global_position = Vector3(-4.5, 0, 34)
		player.get_node("CameraYaw").rotation.y = deg_to_rad(90)
		player.get_node("CameraYaw/CameraPitch").rotation.x = deg_to_rad(12)
	elif player and setup == "facade":
		player.global_position = Vector3(3, 0, 20)
		player.get_node("CameraYaw").rotation.y = deg_to_rad(70)
		player.dose.add_pills(1)
		player.dose.take()
	elif player and setup == "end":
		player.global_position = Vector3(2, 0, -44)
	elif player and setup == "pause":
		(level.get_node("Run") as RunDirector).pause()
	elif player and setup != "":
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
