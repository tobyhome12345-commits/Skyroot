extends SceneTree
## Renders the main scene (if any) for a few frames, saves a PNG, then quits.
## Usage: godot_console --path . --script res://tools/screenshot.gd -- <output.png>

const WAIT_FRAMES := 10


func _initialize() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_path != "":
		var scene: PackedScene = load(main_path)
		if scene:
			root.add_child(scene.instantiate())
	_capture.call_deferred()


func _capture() -> void:
	for i in WAIT_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://screenshot.png"
	var err := root.get_texture().get_image().save_png(out_path)
	print("Screenshot saved: ", out_path, " (error code ", err, ")")
	quit()
