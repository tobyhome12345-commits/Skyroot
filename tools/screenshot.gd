extends SceneTree
## Renders the main scene (if any) for a few frames, saves a PNG, then quits.
## Usage: godot_console --path . --script res://tools/screenshot.gd -- <output.png> [options]
## Options (for checking, not gameplay):
##   pitch=<deg>      override camera pitch (e.g. pitch=15 to see the underside)
##   distance=<m>     override camera distance
##   yaw=<deg>        orbit the camera around its focus (check views only)
##   focus=<x>,<z>    look at that tile instead of the player (close-ups)
##   debug            turn on the debug view (grid lines + collision shapes)
##   notilt           hide the tilt-shift blur (to compare)
##   frames=<n>       frames to wait after setup before capturing (default 10)
##   walk=<action>:<s> hold a move action (e.g. walk=move_down:1.5) first
##   scene=<res path> capture that scene instead of the main scene (e.g. an interior)
##   player=<x>,<z>   put the player on that tile first (e.g. at a door, to show its prompt)

var wait_frames := 10


func _initialize() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			main_path = arg.substr(6)
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
			"yaw":
				if camera and "yaw_degrees" in camera:
					camera.yaw_degrees = float(parts[1])
			"focus":
				# focus=<tile x>,<tile z>: look at that tile instead of the player.
				var xz := parts[1].split(",")
				var island := root.find_child("Island", true, false)
				if island == null:
					island = root.find_child("Interior", true, false)
				if camera and island:
					var cell := Vector2i(int(xz[0]), int(xz[1]))
					camera.focus_override = Grid.cell_center(cell, island.map_size)
			"distance":
				if camera and "distance" in camera:
					camera.distance = float(parts[1])
			"debug":
				call_group("debug_toggle", "set_debug_visible", true)
			"frames":
				wait_frames = int(parts[1])
			"player":
				# player=<x>,<z>: put the player on that tile first (e.g. at a door).
				var pxz := parts[1].split(",")
				var level := root.find_child("Island", true, false)
				if level == null:
					level = root.find_child("Interior", true, false)
				var p := root.find_child("Player", true, false)
				if p and level:
					p.spawn_at(Grid.cell_center(Vector2i(int(pxz[0]), int(pxz[1])), level.map_size))
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
