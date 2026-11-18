extends SceneTree
## Part check: builds every building-like prop on its own and looks for
## parts that fight each other:
##  - two different parts with faces in the same plane, facing the same way
##    and overlapping (they flicker / z-fight)
##  - parts listed as "must stay apart" (windmill sails vs tower and roof)
##    whose shapes come within a few cm of each other
## Usage: godot_console --headless --path . --script res://tools/check_parts.gd
##   add "-- verbose" to list every clash.

## Prop layouts to build and inspect.
const PROPS := [
	{"type": "house", "cell": Vector2i.ZERO, "size": Vector2i(2, 2), "wood": true},
	{"type": "house", "cell": Vector2i.ZERO, "size": Vector2i(2, 2), "red_roof": true},
	{"type": "windmill", "cell": Vector2i.ZERO, "size": Vector2i(2, 2)},
	{"type": "hut", "cell": Vector2i.ZERO},
	{"type": "hut", "cell": Vector2i.ZERO, "straw": true},
	{"type": "cabin", "cell": Vector2i.ZERO, "size": Vector2i(2, 2), "seed": 3},
	{"type": "cabin", "cell": Vector2i.ZERO, "size": Vector2i(2, 2), "seed": 8, "straw": true},
	{"type": "tub_tree", "cell": Vector2i.ZERO, "seed": 5},
	{"type": "paper_lantern", "cell": Vector2i.ZERO},
	{"type": "planter", "cell": Vector2i.ZERO},
	{"type": "well", "cell": Vector2i.ZERO},
	{"type": "notice_board", "cell": Vector2i.ZERO},
	{"type": "kite_pole", "cell": Vector2i.ZERO},
	{"type": "wind_chime", "cell": Vector2i.ZERO},
	{"type": "banner_pole", "cell": Vector2i.ZERO},
	{"type": "oven", "cell": Vector2i.ZERO},
	{"type": "bake_stall", "cell": Vector2i.ZERO},
	{"type": "wind_cliff", "cell": Vector2i.ZERO, "size": Vector2i(5, 3)},
]
## Plane match tolerance (m) and the smallest overlap that counts (m²).
const PLANE_TOL := 0.002
const MIN_AREA := 0.0004
## Gap (m) that sails must keep from the rest of the windmill.
const SAIL_GAP := 0.05

var _failures := 0
var _checks := 0
var _verbose := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_verbose = "verbose" in OS.get_cmdline_user_args()
	for p: Dictionary in PROPS:
		var node := Props.build(p)
		root.add_child(node)
		var label := "%s%s" % [p["type"], " (red)" if p.get("red_roof", false) else (" (wood)" if p.get("wood", false) else (" (straw)" if p.get("straw", false) else ""))]
		var before := _failures
		_check_coplanar(node, label)
		if p["type"] == "windmill":
			_check_sails(node)
		print("%-22s %s" % [label, "ok" if _failures == before else "%d clash(es)" % (_failures - before)])
		node.free()
	print("RESULT: %s (%d checks)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks])
	quit(1 if _failures > 0 else 0)


## Every triangle of every mesh, in the prop's space, tagged with its part
## (the mesh instance it belongs to).
func _triangles(node: Node3D) -> Array:
	var out := []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var xf := node.global_transform.affine_inverse() * m.global_transform
		var faces := m.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var a := xf * faces[i]
			var b := xf * faces[i + 1]
			var c := xf * faces[i + 2]
			var n := (b - a).cross(c - a)
			if n.length() < 1e-7:
				continue
			# Faces lying on the ground facing down are never seen.
			if n.normalized().y < -0.99 and maxf(a.y, maxf(b.y, c.y)) < 0.01:
				continue
			out.append([m.get_instance_id(), a, b, c, n.normalized(), m.name])
	return out


## Coplanar, same-facing, overlapping faces from two different parts.
func _check_coplanar(node: Node3D, label: String) -> void:
	var tris := _triangles(node)
	var buckets := {}
	for t in tris:
		var n: Vector3 = t[4]
		var d := n.dot(t[1])
		var key := Vector4i(roundi(n.x * 50), roundi(n.y * 50), roundi(n.z * 50), roundi(d / PLANE_TOL))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(t)
	var reported := {}
	for key in buckets:
		var list: Array = buckets[key]
		# Also compare with the neighbouring plane bucket (rounding edge).
		var near: Array = list.duplicate()
		var k2 := Vector4i(key.x, key.y, key.z, key.w + 1)
		if buckets.has(k2):
			near.append_array(buckets[k2])
		for i in list.size():
			for j in range(i + 1, near.size()):
				var a: Array = list[i]
				var b: Array = near[j]
				if a[0] == b[0]:
					continue
				var pair := "%s|%s" % [a[5], b[5]] if String(a[5]) < String(b[5]) else "%s|%s" % [b[5], a[5]]
				if reported.has(pair):
					continue
				_checks += 1
				if absf((a[4] as Vector3).dot(b[1] - a[1])) > PLANE_TOL:
					continue
				if _overlap_area(a, b) > MIN_AREA:
					reported[pair] = true
					_failures += 1
					print("FAIL  [%s] parts %s and %s share a surface (they flicker) near %s, facing %s" % [label, a[5], b[5], ((a[1] + a[2] + a[3]) / 3.0).snapped(Vector3.ONE * 0.01), (a[4] as Vector3).snapped(Vector3.ONE * 0.01)])


## Rough overlap area of two coplanar triangles: sample points of one
## inside the other.
func _overlap_area(a: Array, b: Array) -> float:
	var n: Vector3 = a[4]
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := n.cross(u)
	var pa := PackedVector2Array([Vector2(u.dot(a[1]), v.dot(a[1])), Vector2(u.dot(a[2]), v.dot(a[2])), Vector2(u.dot(a[3]), v.dot(a[3]))])
	var pb := PackedVector2Array([Vector2(u.dot(b[1]), v.dot(b[1])), Vector2(u.dot(b[2]), v.dot(b[2])), Vector2(u.dot(b[3]), v.dot(b[3]))])
	var inter := Geometry2D.intersect_polygons(_ccw(pa), _ccw(pb))
	var area := 0.0
	for poly in inter:
		area += absf(_area(poly))
	return area


func _ccw(p: PackedVector2Array) -> PackedVector2Array:
	if _area(p) < 0.0:
		p.reverse()
	return p


func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return s / 2.0


## The sails keep a clear gap from the tower and roof (so they could turn).
func _check_sails(node: Node3D) -> void:
	var sails := node.find_child("Sails", true, false) as Node3D
	_checks += 1
	if sails == null:
		_failures += 1
		print("FAIL  [windmill] has no Sails node")
		return
	var sail_ids := {}
	for mi in sails.find_children("*", "MeshInstance3D", true, false):
		sail_ids[mi.get_instance_id()] = true
	var sail_tris := []
	var rest_tris := []
	for t in _triangles(node):
		(sail_tris if sail_ids.has(t[0]) else rest_tris).append(t)
	# The sails sweep a disc as they turn: every tower / roof point inside
	# that disc's slab (between the sails' back and front) is a clash.
	var hub := node.global_transform.affine_inverse() * sails.global_position
	var axis: Vector3 = (sails.global_basis * (sails.get_meta("spin_axis") as Vector3)).normalized()
	var radius := 0.0
	var back := INF
	for t in sail_tris:
		for k in [1, 2, 3]:
			var p: Vector3 = t[k]
			var along := axis.dot(p - hub)
			back = minf(back, along)
			radius = maxf(radius, ((p - hub) - axis * along).length())
	var clash := false
	for t in rest_tris:
		for k in [1, 2, 3]:
			var p: Vector3 = t[k]
			var along := axis.dot(p - hub)
			var r := ((p - hub) - axis * along).length()
			if along > back - SAIL_GAP and r < radius and String(t[5]) != "Axle":
				clash = true
	_checks += 1
	if clash:
		_failures += 1
		print("FAIL  [windmill] the tower or roof reaches into the sails' sweep (they'd clip when turning)")
