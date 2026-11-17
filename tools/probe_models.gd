extends SceneTree
## Prints where a model's mesh is highest along z and x (which way stairs rise),
## and the centre of its bounds.
## Usage: godot_console --headless --path . --script res://tools/probe_models.gd -- <res://a.glb> [more...]


func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var node := (load(p) as PackedScene).instantiate() as Node3D
		var hi_z := 0.0
		var hi_x := 0.0
		var top := -INF
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			for v in (mi as MeshInstance3D).mesh.get_faces():
				if v.y > top + 0.001:
					top = v.y
					hi_z = v.z
					hi_x = v.x
		var sx := 0.0
		var sz := 0.0
		var n := 0
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			for v in (mi as MeshInstance3D).mesh.get_faces():
				if v.y > top - 0.05:
					sx += v.x
					sz += v.z
					n += 1
		hi_x = sx / maxf(1.0, n)
		hi_z = sz / maxf(1.0, n)
		var box := ModelUtil.local_aabb(node)
		print("%-28s top y=%.2f, mean of top vertices x=%.2f z=%.2f  centre=%s" % [p.get_file(), top, hi_x, hi_z, box.get_center()])
		node.free()
	quit()
