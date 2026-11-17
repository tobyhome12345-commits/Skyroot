extends Node3D
## The Great Tree, grown from smooth generated shapes so it looks organic:
##  - one trunk mesh: a curved tube that flares at the base, tapers as it
##    rises, swells into a lobe wherever a root leaves it, and carries bark
##    ridges and lighter / darker bark patches (vertex colours);
##  - roots: tubes that start inside the trunk, flow out thick and thin as
##    they spread, dive into the earth, and (some) break out again near the
##    edge and drape over it; small side roots branch off them;
##  - branches: curved tapering tubes with side twigs; two stay bare;
##  - canopy: many overlapping soft leaf blobs around the leafy branches;
##  - vines: thin tubes grown from a real point on a branch or the trunk,
##    hanging under gravity (or clinging to the trunk down to the ground);
##  - knots (rounded bumps) and hollows set into the trunk surface.
## Everything is recorded (centre lines, radii, attachment points) so the
## check (tools/check_tree.gd) can verify nothing floats, sinks or clips.
## All colours come from TreeLook: ONE health value swaps the look.
## Origin = trunk centre on the ground; +z points south (entrance, camera).
class_name GreatTree

## Tiles inside this radius (m) belong to the trunk base.
const BASE_CLAIM_RADIUS := 10.8
## The sealed entrance faces south; its root knot is this far from the
## trunk centre, the tile in front of it is where the player stands.
const ENTRANCE_DISTANCE := 9.2
## A root blocks its tile where it rises at least this high above the grass.
const ROOT_BLOCK_HEIGHT := 0.3
## Trunk shape (m): radius at the ground (front, between roots) and at the top.
const BASE_RADIUS := 8.6
const TOP_RADIUS := 4.2
const TRUNK_SIDES := 48
const TRUNK_RINGS := 44

## Where roots leave the trunk (degrees from +x towards +z), and whether
## they break out again near the edge and drape over it. South (90) stays
## clear for the path to the entrance.
const ROOTS := [
	[12.0, true], [48.0, false], [132.0, false], [168.0, true],
	[208.0, true], [250.0, false], [292.0, true], [332.0, true],
]

var island: Node3D
var player: Node3D
## Root segments for checks: {"a", "b": island-space points, "radius", "kind":
## "inner" | "outer" | "drape" | "side", "root": index}.
var roots: Array[Dictionary] = []
## Each root as a sampled centre line: {"points", "radii", "kind", "root"} (tree space).
var root_lines: Array[Dictionary] = []
## Branches: {"points", "radii", "leafy"} in tree space.
var branches: Array[Dictionary] = []
## Hanging / clinging pieces: {"points", "radius", "attach": "branch" | "trunk",
## "parent": branch index, "end": "air" | "ground" | "trunk", "kind"} in tree space.
var hangers: Array[Dictionary] = []
## Knots and hollows on the trunk: {"kind", "center", "angle", "height", "size"}.
var trunk_features: Array[Dictionary] = []
## Tiles the tree takes (cell -> "trunk" / "root").
var claimed := {}
## Things that can hide the player (see _hides).
var occluders: Array[Dictionary] = []
var canopy: Array[MeshInstance3D] = []
var falling: CPUParticles3D
var fallen_leaves: MultiMeshInstance3D
## Where each fallen leaf lies (tree space), for checks.
var fallen_leaf_spots: Array[Transform3D] = []
var entrance_glow: OmniLight3D

var _rng := RandomNumberGenerator.new()
var _trunk_parts: Array[Node] = []
var _body: StaticBody3D


## Builds the whole tree. `at` is the trunk centre in island space.
func build(owner_island: Node3D, at: Vector3, owner_player: Node3D) -> void:
	island = owner_island
	player = owner_player
	position = at
	name = "GreatTree"
	add_to_group("tree_health")
	_rng.seed = 2024
	_body = StaticBody3D.new()
	_body.name = "TreeBody"
	add_child(_body)
	for cell in _cells_within(Vector3.ZERO, BASE_CLAIM_RADIUS):
		claimed[cell] = "trunk"
	_build_trunk()
	_build_roots()
	_build_trunk_features()
	_build_entrance()
	_build_branches_and_canopy()
	_build_vines()
	_build_leaves()
	_add_occluder_cyl(_trunk_parts, 10.8, 0.0, TreeLook.TRUNK_HEIGHT + 4.0)
	apply_health()


# ---------------------------------------------------------------- trunk shape

## Trunk centre line: gently curving as it rises.
func trunk_axis(y: float) -> Vector3:
	return Vector3(1.3 * sin(y * 0.045), y, 0.9 * sin(y * 0.033 + 1.1) - 0.9 * sin(1.1))


## Trunk surface radius at an angle (radians, from +x towards +z) and height.
func trunk_radius(angle: float, y: float) -> float:
	var t := clampf(y / TreeLook.TRUNK_HEIGHT, 0.0, 1.0)
	# Taper: wide flare at the foot, easing into a slowly narrowing column.
	var r := lerpf(BASE_RADIUS * 0.82, TOP_RADIUS, pow(t, 0.8)) + BASE_RADIUS * 0.18 * exp(-y / 4.5)
	# Lobes where roots leave the trunk.
	for root in ROOTS:
		var d := angle_difference(angle, deg_to_rad(root[0]))
		r += 1.6 * exp(-y / 3.5) * exp(-pow(d / 0.24, 2.0))
	# Bark ridges and slow bulges, never repeating exactly.
	r += 0.22 * sin(7.0 * angle + y * 0.17) + 0.14 * sin(13.0 * angle - y * 0.29) + 0.35 * sin(3.0 * angle + y * 0.06 + 1.7)
	return r


## A point on the trunk surface (tree space), `inset` metres inside it.
## How far a point is outside the trunk surface (negative = inside).
func _outside_trunk(p: Vector3) -> float:
	var axis := trunk_axis(clampf(p.y, 0.0, TreeLook.TRUNK_HEIGHT))
	var d := Vector2(p.x - axis.x, p.z - axis.z)
	return d.length() - trunk_radius(atan2(d.y, d.x), clampf(p.y, 0.0, TreeLook.TRUNK_HEIGHT))


func trunk_surface(angle: float, y: float, inset := 0.0) -> Vector3:
	var dir := Vector3(cos(angle), 0.0, sin(angle))
	return trunk_axis(y) + dir * (trunk_radius(angle, y) - inset)


func _build_trunk() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in TRUNK_RINGS + 1:
		# Dense rings near the ground (where the shape changes most).
		var y := TreeLook.TRUNK_HEIGHT * pow(float(i) / TRUNK_RINGS, 1.35) - 0.3
		var ring: Array = []
		for j in TRUNK_SIDES:
			var a := TAU * j / TRUNK_SIDES
			ring.append(trunk_surface(a, maxf(y, 0.0)) + Vector3(0, minf(y, 0.0), 0))
		rings.append(ring)
	for i in TRUNK_RINGS:
		for j in TRUNK_SIDES:
			var j2 := (j + 1) % TRUNK_SIDES
			var quad := [rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]]
			for k in [0, 1, 2, 0, 2, 3]:  # Godot draws clockwise faces: outward
				var v: Vector3 = quad[k]
				var axis := trunk_axis(maxf(v.y, 0.0))
				st.set_normal(Vector3(v.x - axis.x, 0.0, v.z - axis.z).normalized())
				st.set_color(_bark_patch(v))
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Trunk"
	mi.mesh = st.commit()
	mi.material_override = TreeLook.bark()
	add_child(mi)
	_trunk_parts.append(mi)
	# Solid trunk base.
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 9.6
	cyl.height = 30.0
	cs.shape = cyl
	cs.position = Vector3(0, 15.0, 0)
	_body.add_child(cs)


## Bark colour variation: lighter weathered patches and darker grooves.
func _bark_patch(v: Vector3) -> Color:
	var n := sin(v.x * 0.37 + v.y * 0.21) * sin(v.z * 0.41 - v.y * 0.13) + 0.5 * sin(v.y * 0.9 + v.x * 1.3)
	var k := clampf(0.9 + 0.12 * n, 0.72, 1.06)
	return Color(k, k * 0.98, k * 0.96)


# ---------------------------------------------------------------- tubes

## Adds a smooth tube along `points` (radius `radii` at each point) to `st`.
## The ends are left open: they're always buried in the trunk or the ground,
## or taper to a tiny tip.
func _tube(st: SurfaceTool, points: Array, radii: Array, sides: int, color_fn := Callable()) -> void:
	var n := points.size()
	var prev_normal := Vector3.ZERO
	var rings: Array = []
	for i in n:
		var p: Vector3 = points[i]
		# Direction averaged over a few points, so tight bends don't fold the tube.
		var tangent: Vector3 = ((points[mini(i + 2, n - 1)] as Vector3) - (points[maxi(i - 2, 0)] as Vector3)).normalized()
		var normal := prev_normal
		if normal == Vector3.ZERO:
			normal = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
		normal = (normal - tangent * normal.dot(tangent)).normalized()  # parallel transport
		prev_normal = normal
		var binormal := tangent.cross(normal)
		var ring: Array = []
		for j in sides:
			var a := TAU * j / sides
			var out := normal * cos(a) + binormal * sin(a)
			ring.append([p + out * float(radii[i]), out])
		rings.append(ring)
	for i in n - 1:
		for j in sides:
			var j2 := (j + 1) % sides
			var quad := [rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]]
			for k in [0, 2, 1, 0, 3, 2]:  # Godot draws clockwise faces: outward
				var v: Array = quad[k]
				st.set_normal(v[1])
				st.set_color(color_fn.call(v[0]) if color_fn.is_valid() else Color.WHITE)
				st.add_vertex(v[0])


## Smooth points along control points (Catmull-Rom), `per` per segment.
func _smooth(ctrl: Array, per: int) -> Array:
	var out := []
	for i in ctrl.size() - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in per:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / per))
	out.append(ctrl[ctrl.size() - 1])
	return out


func _taper(n: int, r0: float, r1: float, power := 1.0) -> Array:
	var out := []
	for i in n:
		out.append(lerpf(r0, r1, pow(float(i) / maxf(n - 1, 1), power)))
	return out


# ---------------------------------------------------------------- roots

func _build_roots() -> void:
	for ri in ROOTS.size():
		var r: Array = ROOTS[ri]
		var angle := deg_to_rad(r[0] + _rng.randf_range(-3.0, 3.0))
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var side := dir.cross(Vector3.UP)
		var rad := _rng.randf_range(1.5, 1.8)
		var bend := _rng.randf_range(-1.8, 1.8)
		# Main root: starts deep inside the trunk lobe, flows out and down.
		var ctrl := [
			trunk_axis(5.5) + dir * 4.0,
			trunk_axis(3.0) + dir * (trunk_radius(angle, 3.0) - 0.4),
			dir * 11.5 + side * bend * 0.4 + Vector3(0, rad * 0.55, 0),
			dir * 14.0 + side * bend + Vector3(0, rad * 0.15, 0),
			dir * 16.5 + side * bend * 1.3 + Vector3(0, -rad * 0.9, 0),
		]
		var pts := _smooth(ctrl, 6)
		var radii := _taper(pts.size(), rad * 1.5, rad * 0.45, 0.8)
		_add_root(pts, radii, "inner", ri)
		# A thinner side root splitting off and diving into the ground.
		var k := int(pts.size() * 0.55)
		var sp: Vector3 = pts[k]
		var sdir := (dir + side * (0.9 if bend < 0 else -0.9)).normalized()
		var side_pts := _smooth([sp, sp + sdir * 2.5 + Vector3(0, -0.1, 0), sp + sdir * 5.0 + Vector3(0, -0.9 - sp.y, 0)], 5)
		_add_root(side_pts, _taper(side_pts.size(), float(radii[k]) * 0.55, 0.22), "side", ri)
		if not r[1]:
			continue
		# Outer root: surfaces again near the edge and drapes over it.
		var edge := _edge_along(dir, side, bend * 1.3, rad)
		if edge < 23.0:
			continue
		var start := maxf(22.0, edge - 5.0)
		var rad2 := rad * 0.8
		var o_ctrl := [
			dir * start + side * bend * 1.3 + Vector3(0, -rad2 * 1.1, 0),
			dir * (start + (edge - start) * 0.55) + side * bend * 1.3 + Vector3(0, rad2 * 0.2, 0),
			dir * (edge + rad2 + 0.35) + side * bend * 1.3 + Vector3(0, rad2 * 0.3, 0),
			dir * (edge + rad2 + 0.55) + side * bend * 1.3 + Vector3(0, -2.5, 0),
			dir * (edge + rad2 + 0.75) + side * bend * 1.6 + Vector3(0, -7.0, 0),
		]
		var o_pts := _smooth(o_ctrl, 6)
		_add_root(o_pts, _taper(o_pts.size(), rad2, 0.18, 1.2), "outer", ri)


## Adds one root: its mesh, the record for checks, colliders on the parts
## above the grass, and the tiles it blocks.
func _add_root(pts: Array, radii: Array, kind: String, index: int) -> void:
	# Outside the trunk, on the island, a root lies on (half in) the ground:
	# it never bows up into the air.
	for pass_i in 3:
		for i in pts.size():
			var p: Vector3 = pts[i]
			var on_island: bool = island.is_ground(Grid.world_to_cell(position + p, island.map_size))
			if on_island and _outside_trunk(p) > -0.5:
				pts[i] = Vector3(p.x, minf(p.y, float(radii[i]) * 0.55), p.z)
		# Ease out the kinks the flattening leaves (the ends stay put).
		var eased := pts.duplicate()
		for i in range(1, pts.size() - 1):
			eased[i] = ((pts[i - 1] as Vector3) + (pts[i] as Vector3) * 2.0 + (pts[i + 1] as Vector3)) / 4.0
		pts.assign(eased)
	for i in pts.size():
		var p: Vector3 = pts[i]
		if island.is_ground(Grid.world_to_cell(position + p, island.map_size)) and _outside_trunk(p) > -0.5:
			pts[i] = Vector3(p.x, minf(p.y, float(radii[i]) * 0.55), p.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, pts, radii, 14, _bark_patch)
	var mi := MeshInstance3D.new()
	mi.name = "Root_%s_%d" % [kind, index]
	mi.mesh = st.commit()
	mi.material_override = TreeLook.bark_dark() if kind == "side" else TreeLook.bark()
	add_child(mi)
	root_lines.append({"points": pts, "radii": radii, "kind": kind, "root": index})
	var caps := []
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r := (float(radii[i]) + float(radii[i + 1])) / 2.0
		var mid := (a + b) / 2.0
		# Over the edge the root hangs outside the island: "drape".
		var over_edge: bool = not island.is_ground(Grid.world_to_cell(position + mid, island.map_size))
		roots.append({"a": position + a, "b": position + b, "radius": r,
				"kind": "drape" if over_edge else kind, "root": index})
		caps.append([a, b, r])
		if over_edge:
			continue
		# Above the grass: solid, and its tiles belong to the tree.
		if mid.y + r * 0.8 > ROOT_BLOCK_HEIGHT and Vector2(mid.x, mid.z).length() > 8.0:
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = r * 0.9
			cap.height = a.distance_to(b) + r * 1.8
			cs.shape = cap
			var up := (b - a).normalized()
			var x := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
			cs.transform = Transform3D(Basis(x, up, x.cross(up)), mid)
			_body.add_child(cs)
		for p: Vector3 in [a, mid]:
			if p.y + r * 0.8 > ROOT_BLOCK_HEIGHT:
				for cell in _cells_within(p, r):
					if not claimed.has(cell):
						claimed[cell] = "root"
	occluders.append({"shape": "caps", "caps": caps, "meshes": [mi]})


## Distance from the trunk centre to the island's edge along `dir` (shifted
## sideways by `off`), so a root of radius `rad` stays on the island.
func _edge_along(dir: Vector3, side: Vector3, off: float, rad: float) -> float:
	var best := 200.0
	for o: float in [off - rad, off, off + rad]:
		var r := 8.0
		while r < 80.0:
			var p := position + dir * r + side * o
			if not bool(island.is_ground(Grid.world_to_cell(p, island.map_size))):
				break
			r += 0.1
		best = minf(best, r)
	return best


# ---------------------------------------------------------------- knots, hollows, entrance

func _build_trunk_features() -> void:
	var hollow_mat := StandardMaterial3D.new()
	hollow_mat.albedo_color = Color(0.2, 0.16, 0.14)
	hollow_mat.roughness = 1.0
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	# Knots: rounded bumps half sunk into the bark.
	for k in [[200.0, 9.0, 1.3], [300.0, 16.0, 1.1], [24.0, 21.0, 1.2], [118.0, 12.0, 1.0], [250.0, 27.0, 0.9], [60.0, 33.0, 1.0]]:
		var a := deg_to_rad(k[0])
		var c := trunk_surface(a, k[1], k[2] * 0.45)
		var mi := MeshInstance3D.new()
		mi.name = "Knot"
		mi.mesh = sphere
		mi.material_override = TreeLook.bark()
		mi.transform = _surface_frame(a, c, Vector3(k[2] * 1.3, k[2] * 0.9, k[2]))
		add_child(mi)
		_trunk_parts.append(mi)
		trunk_features.append({"kind": "knot", "center": c, "angle": a, "height": k[1], "size": k[2]})
	# Hollows: dark ovals set into the bark, flush with the surface.
	for h in [[235.0, 7.5, 1.4], [340.0, 13.0, 1.1], [70.0, 18.0, 1.2]]:
		var a := deg_to_rad(h[0])
		var c := trunk_surface(a, h[1], h[2] * 0.3)
		var mi := MeshInstance3D.new()
		mi.name = "Hollow"
		mi.mesh = sphere
		mi.material_override = hollow_mat
		mi.transform = _surface_frame(a, c, Vector3(h[2], h[2] * 1.5, h[2] * 0.4))
		add_child(mi)
		_trunk_parts.append(mi)
		trunk_features.append({"kind": "hollow", "center": c, "angle": a, "height": h[1], "size": h[2]})


## Transform at a point on the trunk, its local z pointing straight out.
func _surface_frame(angle: float, at: Vector3, scale: Vector3) -> Transform3D:
	var out := Vector3(cos(angle), 0.0, sin(angle))
	var b := Basis(out.cross(Vector3.UP) * -1.0, Vector3.UP, out)
	return Transform3D(b.scaled(scale), at)


func _build_entrance() -> void:
	var knot := Node3D.new()
	knot.name = "SealedEntrance"
	add_child(knot)
	_trunk_parts.append(knot)
	var front := deg_to_rad(90.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Roots crossing in front of the opening, each anchored in the bark at
	# one end and in the ground (or the bark) at the other.
	for seg in [[-25.0, 4.2, 22.0, 0.0, 0.5], [25.0, 4.0, -22.0, 0.0, 0.5], [-14.0, 2.0, 15.0, 2.6, 0.34]]:
		var a := trunk_surface(front + deg_to_rad(seg[0]) / 4.0, seg[1], 0.35)
		var b := trunk_surface(front + deg_to_rad(seg[2]) / 4.0, seg[3], 0.35)
		if seg[3] == 0.0:
			b += Vector3(0, -0.3, 0.6)  # its foot goes into the ground
		# Leaves the bark outwards, arches over, and goes back in gently.
		var out := Vector3(0, 0, 1)
		var pts := _smooth([a, a + out * 0.9 + (b - a) * 0.15, b + out * 0.9 - (b - a) * 0.15, b], 10)
		_tube(st, pts, _taper(pts.size(), seg[4], seg[4] * 0.8), 12, _bark_patch)
		hangers.append({"points": pts, "radius": seg[4], "attach": "trunk", "parent": -1,
				"end": "trunk" if seg[3] > 0.0 else "ground", "kind": "entrance_root"})
	var mi := MeshInstance3D.new()
	mi.name = "KnotRoots"
	mi.mesh = st.commit()
	mi.material_override = TreeLook.bark_dark()
	knot.add_child(mi)
	# Faint warm glow behind the roots, set into the bark.
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	glow.mesh = s
	glow.material_override = TreeLook.glow()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.transform = _surface_frame(front, trunk_surface(front, 1.6, 0.45), Vector3(1.0, 1.5, 0.55))
	knot.add_child(glow)
	entrance_glow = OmniLight3D.new()
	entrance_glow.name = "GlowLight"
	entrance_glow.light_color = Color(1.0, 0.68, 0.36)
	entrance_glow.light_energy = 1.4
	entrance_glow.omni_range = 6.0
	entrance_glow.position = trunk_surface(front, 1.8) + Vector3(0, 0, 1.5)
	knot.add_child(entrance_glow)


## The tile the root knot stands on, and the tile in front of it.
func entrance_cells() -> Array[Vector2i]:
	var knot := Grid.world_to_cell(position + Vector3(0, 0, ENTRANCE_DISTANCE), island.map_size)
	return [knot, knot + Vector2i(0, 1)]


# ---------------------------------------------------------------- branches & canopy

func _build_branches_and_canopy() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# [angle, height, length, rise (deg), leafy]
	var specs := [
		[20.0, 56.0, 28.0, 26.0, true], [95.0, 52.0, 24.0, 18.0, false], [160.0, 60.0, 30.0, 30.0, true],
		[215.0, 54.0, 27.0, 24.0, true], [270.0, 63.0, 30.0, 28.0, true], [325.0, 50.0, 22.0, 16.0, false],
		[60.0, 68.0, 24.0, 38.0, true], [240.0, 71.0, 22.0, 36.0, true], [130.0, 66.0, 22.0, 34.0, true],
	]
	for b in specs:
		var a := deg_to_rad(b[0])
		var dir := Vector3(cos(a), 0, sin(a))
		var rise := deg_to_rad(b[3])
		var start := trunk_axis(b[1]) + dir * (trunk_radius(a, b[1]) * 0.45)
		var len: float = b[2]
		var side := dir.cross(Vector3.UP) * _rng.randf_range(-3.0, 3.0)
		var ctrl := [
			start,
			trunk_surface(a, b[1] + 1.5) + dir * 1.0,
			start + dir * len * 0.45 * cos(rise) + side * 0.5 + Vector3(0, len * 0.45 * sin(rise), 0),
			start + dir * len * 0.8 * cos(rise) + side + Vector3(0, len * 0.65 * sin(rise), 0),
			start + dir * len * cos(rise) + side * 1.2 + Vector3(0, len * 0.6 * sin(rise) - (2.5 if b[4] else 0.5), 0),
		]
		var pts := _smooth(ctrl, 5)
		var radii := _taper(pts.size(), 2.6, 0.35, 0.7)
		_tube(st, pts, radii, 12, _bark_patch)
		branches.append({"points": pts, "radii": radii, "leafy": b[4]})
		# A side twig from the outer half.
		var k := int(pts.size() * 0.6)
		var tp: Vector3 = pts[k]
		var tdir := (dir.rotated(Vector3.UP, 0.7 if _rng.randf() < 0.5 else -0.7) + Vector3(0, 0.5, 0)).normalized()
		var twig := _smooth([tp, tp + tdir * 4.0, tp + tdir * 8.0 + Vector3(0, -1.0, 0)], 4)
		var twig_r := _taper(twig.size(), float(radii[k]) * 0.6, 0.18)
		_tube(st, twig, twig_r, 8, _bark_patch)
		branches.append({"points": twig, "radii": twig_r, "leafy": b[4]})
	var mi := MeshInstance3D.new()
	mi.name = "Branches"
	mi.mesh = st.commit()
	mi.material_override = TreeLook.bark()
	add_child(mi)
	_build_canopy()


## Soft, overlapping leaf blobs along the outer part of every leafy branch
## and over the crown, so the canopy reads as one full mass.
func _build_canopy() -> void:
	var crown := Node3D.new()
	crown.name = "Canopy"
	add_child(crown)
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 18
	blob.rings = 10
	var spots: Array[Array] = []  # [centre, size, branch index]
	for bi in branches.size():
		var br: Dictionary = branches[bi]
		if not br["leafy"]:
			continue
		var pts: Array = br["points"]
		var count := 3 if pts.size() < 12 else 5
		for c in count:
			var t := lerpf(0.45, 1.0, float(c) / maxf(count - 1, 1))
			var p: Vector3 = pts[int(t * (pts.size() - 1))]
			var off := Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(0.5, 3.0), _rng.randf_range(-2.5, 2.5))
			spots.append([p + off, _rng.randf_range(6.5, 9.5), bi])
	# Crown top, around the top of the trunk.
	var top := trunk_axis(TreeLook.TRUNK_HEIGHT)
	for j in 6:
		var a := TAU * j / 6.0
		spots.append([top + Vector3(cos(a) * 7.0, _rng.randf_range(2.0, 6.0), sin(a) * 7.0), _rng.randf_range(8.0, 10.0), -1])
	for s in spots:
		var mi := MeshInstance3D.new()
		mi.name = "Leaves"
		mi.mesh = blob
		mi.material_override = TreeLook.leaf()
		var size: float = s[1]
		var base := Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3(size * 1.15, size * 0.72, size)), s[0])
		mi.transform = base
		mi.set_meta("base", base)
		mi.set_meta("size", size)
		mi.set_meta("branch", s[2])
		mi.set_meta("order", _rng.randf())
		crown.add_child(mi)
		canopy.append(mi)
	canopy.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.get_meta("order") < y.get_meta("order"))


# ---------------------------------------------------------------- vines

## Vines and hanging moss, each grown from a real attachment point.
func _build_vines() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Hanging from branch undersides, swaying a little, ending in the air.
	for bi in branches.size():
		var br: Dictionary = branches[bi]
		var pts: Array = br["points"]
		if pts.size() < 12:
			continue
		for n in 2:
			var k := int(pts.size() * _rng.randf_range(0.3, 0.75))
			var r: float = br["radii"][k]
			var attach: Vector3 = pts[k] - Vector3(0, r * 0.8, 0)  # just inside the underside
			var length := _rng.randf_range(4.0, 11.0)
			var sway := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
			var vpts := []
			var steps := 10
			for i in steps + 1:
				var t := float(i) / steps
				vpts.append(attach + Vector3(0, -length * t, 0) + sway * t * t)
			_tube(st, vpts, _taper(vpts.size(), 0.16, 0.05), 6)
			hangers.append({"points": vpts, "radius": 0.16, "attach": "branch", "parent": bi, "end": "air", "kind": "hanging_moss"})
	# Clinging to the trunk from a knot or ridge all the way to the ground,
	# following the bark (never cutting through it).
	for v in [[205.0, 9.0], [300.0, 15.0], [118.0, 11.0], [345.0, 19.0], [70.0, 16.0]]:
		var a := deg_to_rad(v[0])
		var vpts := []
		var h: float = v[1]
		var steps := int(ceil(h / 0.5))
		for i in steps + 1:
			var y := h * (1.0 - float(i) / steps)
			var wa := a + 0.08 * sin(y * 1.3 + v[0])
			# Lies on the bark (its own radius out from the surface), never in it.
			vpts.append(trunk_surface(wa, y) + Vector3(cos(wa), 0, sin(wa)) * 0.17)
		_tube(st, vpts, _taper(vpts.size(), 0.14, 0.12), 6)
		hangers.append({"points": vpts, "radius": 0.14, "attach": "trunk", "parent": -1, "end": "ground", "kind": "clinging_vine"})
	var mi := MeshInstance3D.new()
	mi.name = "Vines"
	mi.mesh = st.commit()
	mi.material_override = TreeLook.moss()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_trunk_parts.append(mi)


# ---------------------------------------------------------------- leaves on the ground / falling

func _build_leaves() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.38)
	quad.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	var spots: Array[Transform3D] = []
	for i in 300:
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(10.0, 30.0)
		var p := position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var cell := Grid.world_to_cell(p, island.map_size)
		# Only on open grass: not on roots, the trunk, or paths.
		if not island.is_ground(cell) or claimed.has(cell) or island.is_path(cell):
			continue
		spots.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)), p - position + Vector3(0, 0.012, 0)))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	fallen_leaf_spots = spots
	fallen_leaves = MultiMeshInstance3D.new()
	fallen_leaves.name = "FallenLeaves"
	fallen_leaves.multimesh = mm
	var mat := TreeLook.leaf().duplicate() as StandardMaterial3D
	mat.albedo_color = TreeLook.LEAF_WITHERED.lerp(Color(0.62, 0.46, 0.3), 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fallen_leaves.material_override = mat
	fallen_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fallen_leaves)
	falling = CPUParticles3D.new()
	falling.name = "FallingLeaves"
	var leaf_quad := QuadMesh.new()
	leaf_quad.size = Vector2(0.5, 0.35)
	falling.mesh = leaf_quad
	var fmat := TreeLook.leaf().duplicate() as StandardMaterial3D
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	falling.material_override = fmat
	falling.position = Vector3(0, 30.0, 0)
	falling.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	falling.emission_box_extents = Vector3(26, 4, 26)
	falling.lifetime = 18.0
	falling.preprocess = 18.0
	falling.direction = Vector3(0, -1, 0)
	falling.spread = 30.0
	falling.gravity = Vector3(0.25, -0.05, 0.1)
	falling.initial_velocity_min = 1.3
	falling.initial_velocity_max = 1.8
	falling.angular_velocity_min = -90.0
	falling.angular_velocity_max = 90.0
	falling.particle_flag_rotate_y = true
	add_child(falling)


## Re-applies density, droop and falling leaves from TreeLook.health.
## (Colours update by themselves: they're shared materials.)
func apply_health() -> void:
	var show := int(round(canopy.size() * TreeLook.leaf_density()))
	var droop := TreeLook.droop()
	for i in canopy.size():
		var leaf := canopy[i]
		leaf.visible = i < show
		var base: Transform3D = leaf.get_meta("base")
		var t := base
		t.origin.y -= 1.2 * droop
		t.basis = t.basis.scaled(Vector3(1.0 + 0.08 * droop, 1.0 - 0.2 * droop, 1.0 + 0.08 * droop))
		leaf.transform = t
	if falling:
		falling.amount = maxi(1, TreeLook.falling_leaves() * int(falling.lifetime) / 2)


# ---------------------------------------------------------------- fading

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or player == null or not is_instance_valid(player):
		return
	var from := cam.global_position
	var to := player.global_position + Vector3(0, 1.0, 0)
	for o in occluders:
		var want := 0.78 if _hides(o, from, to) else 0.0
		var cur: float = o.get("fade", 0.0)
		cur = move_toward(cur, want, delta * 3.0)
		if cur != o.get("fade", 0.0):
			o["fade"] = cur
			for mi: GeometryInstance3D in o["meshes"]:
				mi.transparency = cur


## True if the line from the camera to the player passes through it.
func _hides(o: Dictionary, from: Vector3, to: Vector3) -> bool:
	for i in range(1, 24):
		var p := to_local(from.lerp(to, float(i) / 24.0))
		if o["shape"] == "cyl":
			if p.y >= o["y0"] and p.y <= o["y1"] and Vector2(p.x, p.z).length() < o["r"]:
				return true
		else:
			for c: Array in o["caps"]:
				if _dist_to_segment(p, c[0], c[1]) < float(c[2]) + 0.2:
					return true
	return false


## True if the occluder at index `i` is faded right now (for tests).
func is_faded(i: int) -> bool:
	return occluders[i].get("fade", 0.0) > 0.4


func _add_occluder_cyl(nodes: Array, r: float, y0: float, y1: float) -> void:
	var meshes := []
	for n: Node in nodes:
		if n is MeshInstance3D:
			meshes.append(n)
		meshes.append_array(n.find_children("*", "MeshInstance3D", true, false))
	occluders.append({"shape": "cyl", "r": r, "y0": y0, "y1": y1, "meshes": meshes})


# ---------------------------------------------------------------- helpers

static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _cells_within(p: Vector3, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var world := position + p
	var c := Grid.world_to_cell(world, island.map_size)
	var span := int(ceil(r / Grid.TILE)) + 1
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := c + Vector2i(dx, dz)
			var cc := Grid.cell_center(cell, island.map_size)
			var nx := clampf(world.x, cc.x - Grid.TILE / 2.0, cc.x + Grid.TILE / 2.0)
			var nz := clampf(world.z, cc.z - Grid.TILE / 2.0, cc.z + Grid.TILE / 2.0)
			if Vector2(nx - world.x, nz - world.z).length() < r - 0.05 and island.is_ground(cell):
				out.append(cell)
	return out
