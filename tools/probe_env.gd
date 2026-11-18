extends SceneTree
## Prints a scene's environment fog, light, camera and blur settings (to
## check that scene values were read as intended).
## Usage: godot_console --headless --path . --script res://tools/probe_env.gd -- res://scenes/leafwind.tscn


func _initialize() -> void:
	var scene := (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	var env: Environment = (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("fog mode=%d density=%.2f begin=%.0f end=%.0f colour=%s height_density=%.2f" % [env.fog_mode, env.fog_density,
			env.fog_depth_begin, env.fog_depth_end, env.fog_light_color, env.fog_height_density])
	print("saturation=%.2f exposure=%.2f" % [env.adjustment_saturation, env.tonemap_exposure])
	var cam := scene.get_node("Camera") as Camera3D
	print("camera pitch=%.0f distance=%.0f fov=%.0f" % [cam.get("pitch_degrees"), cam.get("distance"), cam.fov])
	var blur := (scene.get_node("TiltShift/Blur") as ColorRect).material as ShaderMaterial
	print("tilt focus_band=%s max_blur=%s" % [blur.get_shader_parameter("focus_band"), blur.get_shader_parameter("max_blur")])
	scene.free()
	quit()
