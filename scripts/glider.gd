class_name Glider
## A small hang-glider built from simple shapes in the game's colours: a
## curved, striped cloth wing, a wooden control bar the player holds, and two
## struts joining them. Origin = where the player's hands hold the bar.

const SPAN := 2.8        # wing tip to wing tip (m)
const CHORD := 1.0       # wing depth, front to back (m)
const DROOP := 0.35      # how far the wing tips curve down (m)
const BAR_DROP := 0.75   # wing sits this far above the bar (m)
const STRIPES := 7
const SEGMENTS := 28

const CREAM := Color(0.99, 0.95, 0.86)
const ORANGE := Color(0.85, 0.5, 0.3)
const WOOD := Color(0.55, 0.36, 0.22)


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Glider"
	root.add_child(_wing())
	# Control bar (held by the player) across x.
	root.add_child(_rod(Vector3(-0.45, 0.0, 0.0), Vector3(0.45, 0.0, 0.0), 0.035, WOOD))
	# Two struts from the bar ends up to the wing, plus a keel down the middle.
	var wing_y := BAR_DROP - _droop_at(0.5)
	root.add_child(_rod(Vector3(-0.45, 0.0, 0.0), Vector3(-0.5, wing_y, 0.05), 0.025, WOOD))
	root.add_child(_rod(Vector3(0.45, 0.0, 0.0), Vector3(0.5, wing_y, 0.05), 0.025, WOOD))
	root.add_child(_rod(Vector3(0.0, BAR_DROP + 0.02, -CHORD * 0.5), Vector3(0.0, BAR_DROP + 0.02, CHORD * 0.55), 0.03, WOOD))
	return root


## Height drop of the wing at sideways position x (curved like a sail).
static func _droop_at(x: float) -> float:
	var t := x / (SPAN / 2.0)
	return DROOP * t * t


## Curved cloth wing: a strip bent down towards the tips and slightly arched
## front to back, with alternating cream / orange stripes.
static func _wing() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var x0 := -SPAN / 2.0 + SPAN * float(i) / SEGMENTS
		var x1 := -SPAN / 2.0 + SPAN * float(i + 1) / SEGMENTS
		var stripe := int(floor(float(i) / SEGMENTS * STRIPES))
		var color := ORANGE if stripe % 2 == 0 else CREAM
		var rows := 4
		for r in rows:
			var z0 := -CHORD / 2.0 + CHORD * float(r) / rows
			var z1 := -CHORD / 2.0 + CHORD * float(r + 1) / rows
			var a := _wing_point(x0, z0)
			var b := _wing_point(x1, z0)
			var c := _wing_point(x1, z1)
			var d := _wing_point(x0, z1)
			var n := (b - a).cross(d - a).normalized()
			if n.y < 0.0:
				n = -n
			for v in [a, b, c, a, c, d]:
				st.set_color(color)
				st.set_normal(n)
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Wing"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mi.material_override = mat
	return mi


static func _wing_point(x: float, z: float) -> Vector3:
	var arch := 0.12 * (1.0 - pow(z / (CHORD / 2.0), 2.0))  # cloth bulges up a little
	# The leading edge (front, +z) sits a touch higher: the glider noses up.
	return Vector3(x, BAR_DROP - _droop_at(x) + arch + z * 0.12, z)


## A thin wooden rod between two points.
static func _rod(from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = from.distance_to(to)
	cyl.radial_segments = 8
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	var up := (to - from).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (from + to) / 2.0)
	return mi
