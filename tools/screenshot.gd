extends SceneTree
## Renders the main scene (if any) for a few frames, saves a PNG, then quits.
## Usage: godot_console --path . --script res://tools/screenshot.gd -- <output.png> [options]
## Options (for checking, not gameplay):
##   pitch=<deg>      override camera pitch (e.g. pitch=15 to see the underside)
##   distance=<m>     override camera distance
##   debug            turn on the debug view (grid lines + collision shapes)
##   notilt           hide the tilt-shift blur (to compare)
##   frames=<n>       frames to wait after setup before capturing (default 10)
##   walk=<action>:<s> hold a move action (e.g. walk=move_down:1.5) first

var wait_frames := 10


func _initialize() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_path != "":
		var scene: PackedScene = load(main_path)
		if scene:
			root.add_child(scene.instantiate())
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://screenshot.png"
	var camera := root.get_camera_3d()
	for arg in args.slice(1):
		var parts := arg.split("=")
		match parts[0]:
			"pitch":
				if camera and "pitch_degrees" in camera:
					camera.pitch_degrees = float(parts[1])
					camera.rotation_degrees.x = -float(parts[1])
			"distance":
				if camera and "distance" in camera:
					camera.distance = float(parts[1])
			"debug":
				call_group("debug_toggle", "set_debug_visible", true)
			"frames":
				wait_frames = int(parts[1])
			"notilt":
				for layer in root.find_children("TiltShift", "CanvasLayer", true, false):
					layer.visible = false
	if camera and camera.has_method("snap_to_target"):
		camera.snap_to_target()
	# walk=<action>:<seconds> holds a movement key before capturing.
	for arg in args.slice(1):
		if arg.begins_with("walk="):
			var walk := arg.substr(5).split(":")
			Input.action_press(walk[0])
			await create_timer(float(walk[1])).timeout
			Input.action_release(walk[0])
	for i in wait_frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(out_path)
	print("Screenshot saved: ", out_path, " (error code ", err, ")")
	quit()
