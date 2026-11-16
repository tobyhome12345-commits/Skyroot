class_name MeshUtil
## Helpers for building simple coloured boxes into one mesh.


## Adds an axis-aligned box from `lo` to `hi`. The top face gets `top_color`,
## the other five faces get `side_color`. `with_top` / `with_bottom = false`
## leave that face out (for faces that are always covered by something else).
static func add_box(st: SurfaceTool, lo: Vector3, hi: Vector3, top_color: Color, side_color: Color, with_top := true, with_bottom := true) -> void:
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
		Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	# Each face: 4 corner indices (counter-clockwise seen from outside), normal.
	if with_top:
		_quad(st, p[4], p[5], p[6], p[7], Vector3.UP, top_color)
	if with_bottom:
		_quad(st, p[3], p[2], p[1], p[0], Vector3.DOWN, side_color)
	_quad(st, p[7], p[6], p[2], p[3], Vector3.BACK, side_color)
	_quad(st, p[5], p[4], p[0], p[1], Vector3.FORWARD, side_color)
	_quad(st, p[6], p[5], p[1], p[2], Vector3.RIGHT, side_color)
	_quad(st, p[4], p[7], p[3], p[0], Vector3.LEFT, side_color)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(color)
		st.set_normal(n)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(v)


static func vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func color_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
