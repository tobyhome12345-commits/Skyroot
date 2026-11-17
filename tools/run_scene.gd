extends SceneTree
## Loads a scene for a few frames and quits, so its errors show up.
## Usage: godot_console --headless --path . --script res://tools/run_scene.gd -- res://scenes/leafwind.tscn


func _initialize() -> void:
	change_scene_to_file.call_deferred(OS.get_cmdline_user_args()[0])
	for i in 40:
		await process_frame
	print("RAN ", OS.get_cmdline_user_args()[0])
	quit()
