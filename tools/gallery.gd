extends SceneTree
## Lays models out in a row with name labels and saves a screenshot, to look
## at asset pieces before using them.
## Usage: godot_console --path . --script res://tools/gallery.gd -- <out.png> <res://a.glb> [more...]

const SPACING := 1.6


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var paths := args.slice(1)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.35, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var cols := 6
	for i in paths.size():
		var scene := load(paths[i]) as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		node.position = Vector3((i % cols) * SPACING, 0, (i / cols) * SPACING * 1.4)
		world.add_child(node)
		var label := Label3D.new()
		label.text = paths[i].get_file().get_basename()
		label.font_size = 28
		label.pixel_size = 0.004
		label.position = node.position + Vector3(0, -0.05, 0.75)
		label.rotation_degrees.x = -50
		world.add_child(label)
	var rows := int(ceil(paths.size() / float(cols)))
	var cam := Camera3D.new()
	world.add_child(cam)
	var center := Vector3((cols - 1) * SPACING / 2.0, 0.3, (rows - 1) * SPACING * 0.7)
	var cam_pos := center + Vector3(0, 6.5, 6.0)
	cam.transform = Transform3D(Basis.looking_at(center - cam_pos), cam_pos)
	cam.fov = 50
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("Gallery saved: ", out)
	quit()
