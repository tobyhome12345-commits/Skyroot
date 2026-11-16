extends SceneTree
## Prints the bounding box of 3D models, so they can be scaled to the grid.
## Usage: godot_console --headless --path . --script res://tools/measure_models.gd -- <res://a.glb> [more...]
## A directory path measures every .glb inside it.


func _initialize() -> void:
	var paths: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.ends_with(".glb") or arg.ends_with(".gltf"):
			paths.append(arg)
		else:
			for f in DirAccess.get_files_at(arg):
				if f.ends_with(".glb"):
					paths.append(arg.path_join(f))
	for p in paths:
		var scene := load(p) as PackedScene
		if scene == null:
			print("LOAD FAILED  ", p)
			continue
		var node := scene.instantiate() as Node3D
		var box := ModelUtil.local_aabb(node)
		print("%-30s size=(%.3f, %.3f, %.3f)  min=(%.3f, %.3f, %.3f)" % [
			p.get_file().get_basename(), box.size.x, box.size.y, box.size.z,
			box.position.x, box.position.y, box.position.z])
		node.free()
	quit()
