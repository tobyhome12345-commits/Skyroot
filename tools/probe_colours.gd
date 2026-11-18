extends SceneTree
## Prints each surface material's colour / texture for models, to see how a
## pack is coloured.
## Usage: godot_console --headless --path . --script res://tools/probe_colours.gd -- <res://a.glb> [more...]


func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var node := (load(p) as PackedScene).instantiate()
		var seen := {}
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			for i in m.get_surface_count():
				var mat := m.surface_get_material(i)
				if mat is BaseMaterial3D:
					var b := mat as BaseMaterial3D
					var key := "%s %s tex=%s vcol=%s" % [b.resource_name, b.albedo_color.to_html(false), b.albedo_texture != null, b.vertex_color_use_as_albedo]
					seen[key] = true
		print(p.get_file(), ": ", ", ".join(seen.keys()))
		node.free()
	quit()
