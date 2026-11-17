extends Node3D
## The Great Tree, assembled from scaled-up Kenney pieces (see
## Assets/CREDITS.md): Nature Kit gnarled stumps stacked into a twisting
## trunk, Nature Kit logs for roots, Survival Kit branch logs, Nature Kit
## leafy crowns for the canopy and Nature Kit hanging moss. Hollows, the
## entrance glow and falling / fallen leaves are simple shapes.
## Every colour comes from TreeLook, so ONE health value swaps the look.
## Origin = centre of the trunk on the ground. +z points south (to the
## entrance and the camera).
class_name GreatTree

const N := "res://Assets/Nature Kit/Models/GLTF format/"
const SV := "res://Assets/Survival Kit/Models/GLB format/"

## Tiles inside this radius (m) belong to the trunk base.
const BASE_CLAIM_RADIUS := 10.8
## The sealed entrance faces south; its root knot stands on the tile in front
## of the trunk, and the tile after that is where the player stands.
const ENTRANCE_DISTANCE := 9.2
## A root blocks its tile where it rises at least this high (m) above the grass.
const ROOT_BLOCK_HEIGHT := 0.3

## Where roots leave the trunk (degrees from +x towards +z) and whether they
## break out again near the edge and hang over it. South (90) is kept clear
## for the path to the entrance.
const ROOTS := [
	[12.0, true], [48.0, false], [132.0, false], [168.0, true],
	[208.0, true], [250.0, false], [292.0, true], [332.0, true],
]

var island: Node3D
var player: Node3D
## Every root piece: {"a", "b": island-space points, "radius", "kind":
## "inner" | "outer" | "drape", "node"}.
var roots: Array[Dictionary] = []
## Tiles the tree takes (cell -> "trunk" / "root" / "entrance").
var claimed := {}
## Things that can hide the player: {"shape": "cyl" | "box", ..., "meshes": [...]}
var occluders: Array[Dictionary] = []
var canopy: Array[Node3D] = []
var falling: CPUParticles3D
var entrance_glow: OmniLight3D

var _rng := RandomNumberGenerator.new()
## Everything on the trunk (bark pieces, knots, hollows, moss, the entrance
## knot): fades as one when it would hide the player.
var _trunk_parts: Array[Node] = []


## Builds the whole tree. `at` is the trunk centre in island space.
func build(owner_island: Node3D, at: Vector3, owner_player: Node3D) -> void:
	island = owner_island
	player = owner_player
	position = at
	name = "GreatTree"
	add_to_group("tree_health")
	_rng.seed = 2024
	var body := StaticBody3D.new()
	body.name = "TreeBody"
	add_child(body)
	_build_trunk(body)
	_build_roots(body)
	_build_entrance()
	_build_canopy()
	_build_moss()
	_build_leaves()
	_add_occluder_cyl(_trunk_parts, 10.6, 0.0, TreeLook.TRUNK_HEIGHT + 4.0)
	apply_health()


# ---------------------------------------------------------------- trunk

func _build_trunk(body: StaticBody3D) -> void:
	# Wide gnarled base (the flare), then four tall stumps stacked and turned
	# so the bark, knots and broken edges never line up.
	var flare := _model(N + "stump_old.glb", Vector3.ONE * 56.0, Vector3(0, 25, 0))
	_place_bottom(flare, Vector3.ZERO)
	TreeLook.apply_to(flare)
	_trunk_parts.append(flare)
	var pieces := [
		# [scale, base height, turn]
		[44.0, 0.0, 40.0], [36.0, 22.0, 160.0], [30.0, 40.0, 285.0], [25.0, 56.0, 50.0],
	]
	var trunk_nodes: Array[Node3D] = []
	for i in pieces.size():
		var p: Array = pieces[i]
		var piece := _model(N + "stump_oldTall.glb", Vector3.ONE * float(p[0]), Vector3(0, p[2], 0))
		_place_bottom(piece, Vector3(0, p[1], 0))
		TreeLook.apply_to(piece, false, i % 2 == 1)
		trunk_nodes.append(piece)
		_trunk_parts.append(piece)
	# Knots (small stumps sticking out) and dark hollows on the lower trunk,
	# where the player can see them.
	for k in [[200.0, 9.0, 7.0], [300.0, 16.0, 6.0], [20.0, 21.0, 6.5], [120.0, 12.0, 6.0]]:
		var dir := _dir(k[0])
		var knot := _model(N + "stump_roundDetailed.glb", Vector3.ONE * float(k[2]), Vector3(-90, -k[0] + 90.0, 0))
		knot.position = dir * (_trunk_radius(k[1]) - 0.6) + Vector3(0, k[1], 0)
		TreeLook.apply_to(knot, false, true)
		_trunk_parts.append(knot)
	var hollow_mat := StandardMaterial3D.new()
	hollow_mat.albedo_color = Color(0.2, 0.16, 0.14)
	hollow_mat.roughness = 1.0
	for h in [[235.0, 7.5, 1.3], [340.0, 13.0, 1.0], [70.0, 18.0, 1.1]]:
		var dir := _dir(h[0])
		var mi := MeshInstance3D.new()
		mi.name = "Hollow"
		var s := SphereMesh.new()
		s.radius = h[2]
		s.height = h[2] * 3.0
		mi.mesh = s
		mi.material_override = hollow_mat
		mi.position = dir * (_trunk_radius(h[1]) - 0.45) + Vector3(0, h[1], 0)
		mi.scale = Vector3(1.0, 1.0, 0.35)
		mi.look_at_from_position(mi.position, mi.position + dir, Vector3.UP)
		add_child(mi)
		_trunk_parts.append(mi)
	# Solid trunk base.
	_cyl_collider(body, 9.6, 0.0, 30.0)


## Rough trunk radius at a height (for placing things on its surface).
func _trunk_radius(y: float) -> float:
	return lerpf(8.4, 4.4, clampf(y / TreeLook.TRUNK_HEIGHT, 0.0, 1.0))


# ---------------------------------------------------------------- roots

func _build_roots(body: StaticBody3D) -> void:
	# Claim the trunk base tiles first.
	for cell in _cells_within(Vector3.ZERO, BASE_CLAIM_RADIUS):
		claimed[cell] = "trunk"
	for r in ROOTS:
		var angle: float = r[0] + _rng.randf_range(-4.0, 4.0)
		var dir := _dir(angle)
		var side := dir.cross(Vector3.UP)
		var rad := _rng.randf_range(1.15, 1.45)
		var twist := side * _rng.randf_range(-1.6, 1.6)
		# Inner root: from high on the flare, bending, diving into the earth.
		var a := dir * 7.0 + Vector3(0, 3.2, 0)
		var m := dir * 11.5 + twist + Vector3(0, rad * 0.9, 0)
		var b := dir * 16.0 + twist * 1.4 + Vector3(0, -rad * 0.9, 0)
		_root_piece(a, m, rad * 1.15, "inner", body)
		_root_piece(m, b, rad, "inner", body)
		if not r[1]:
			continue
		# Outer root: breaks out of the ground again and runs over the edge.
		var edge := _edge_along(dir, rad)
		if edge < 21.0:
			continue
		# Breaks out again well past the walking ring, leaving a walkable gap
		# between the inner root (dives in by 16 m) and this one.
		var c := dir * maxf(22.0, edge - 5.5) + twist + Vector3(0, -rad * 0.7, 0)
		var d := dir * (edge + 0.4) + twist + Vector3(0, rad * 0.75, 0)
		_root_piece(c, d, rad * 0.85, "outer", body)
		# Drape: hanging down outside the island's cliff.
		var e := dir * (edge + 1.0 + rad) + twist + Vector3(0, -7.5, 0)
		_root_piece(d + dir * 0.2, e, rad * 0.7, "drape", null)


## One root piece: a Nature Kit log stretched between two points.
func _root_piece(a: Vector3, b: Vector3, rad: float, kind: String, body: StaticBody3D) -> void:
	var node := _segment(N + "log.glb", a, b, rad, 0.234, 0.173)
	node.name = "Root_%s_%d" % [kind, roots.size()]
	TreeLook.apply_to(node, false, kind == "drape")
	roots.append({"a": position + a, "b": position + b, "radius": rad, "kind": kind, "node": node})
	if kind == "drape":
		return
	# Solid, and its tiles belong to the tree.
	var len := a.distance_to(b)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rad * 2.0, rad * 1.6, len)
	cs.shape = box
	cs.transform = node.transform
	body.add_child(cs)
	var steps := int(ceil(len / 0.4))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		# Only where the root shows above the grass does it block the tile.
		if p.y + rad * 0.8 > ROOT_BLOCK_HEIGHT:
			for cell in _cells_within(p, rad):
				if not claimed.has(cell):
					claimed[cell] = "root"
	_add_occluder_box([node], node.transform, Vector3(rad, rad * 0.8, len / 2.0))


## Distance from the trunk centre to the island's edge along `dir`, taking
## the widest point across a root of radius `rad`.
func _edge_along(dir: Vector3, rad: float) -> float:
	var side := dir.cross(Vector3.UP)
	var best := 0.0
	for off: float in [-rad, 0.0, rad]:
		var r := 8.0
		while r < 80.0:
			var p := position + dir * r + side * off
			if not island.is_ground(Grid.world_to_cell(p, island.map_size)):
				break
			r += 0.2
		best = maxf(best, r)
	return best


# ---------------------------------------------------------------- entrance

func _build_entrance() -> void:
	var front := Vector3(0, 0, 1)
	var c := front * ENTRANCE_DISTANCE
	# A knot of roots crossing in front of the trunk.
	var knot := Node3D.new()
	knot.name = "SealedEntrance"
	add_child(knot)
	_trunk_parts.append(knot)
	for seg in [
		[Vector3(-2.4, 0.0, -0.4), Vector3(0.9, 4.0, -1.4), 0.7],
		[Vector3(2.4, 0.0, -0.4), Vector3(-0.9, 3.8, -1.4), 0.7],
		[Vector3(-1.9, 1.7, 0.1), Vector3(1.9, 2.3, -0.2), 0.45],
		[Vector3(-0.6, 0.0, 0.3), Vector3(0.2, 3.0, -0.9), 0.4],
	]:
		var p := _segment(N + "log.glb", c + seg[0], c + seg[1], seg[2], 0.234, 0.173)
		TreeLook.apply_to(p, false, true)
		p.reparent(knot)
	# Faint warm glow behind the roots.
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var s := SphereMesh.new()
	s.radius = 1.3
	s.height = 2.4
	glow.mesh = s
	glow.material_override = TreeLook.glow()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = c + Vector3(0, 1.6, -1.2)
	glow.scale = Vector3(1.0, 1.1, 0.45)
	knot.add_child(glow)
	entrance_glow = OmniLight3D.new()
	entrance_glow.name = "GlowLight"
	entrance_glow.light_color = Color(1.0, 0.68, 0.36)
	entrance_glow.light_energy = 1.4
	entrance_glow.omni_range = 6.0
	entrance_glow.position = c + Vector3(0, 1.6, 0.6)
	knot.add_child(entrance_glow)


## The tile the root knot stands on, and the tile in front of it.
func entrance_cells() -> Array[Vector2i]:
	var knot := Grid.world_to_cell(position + Vector3(0, 0, ENTRANCE_DISTANCE), island.map_size)
	return [knot, knot + Vector2i(0, 1)]


# ---------------------------------------------------------------- canopy

func _build_canopy() -> void:
	var crown := Node3D.new()
	crown.name = "Canopy"
	add_child(crown)
	# Branches from the upper trunk; two are left bare.
	var branches := [
		[20.0, 58.0, 26.0, 28.0, true], [95.0, 54.0, 24.0, 22.0, false], [160.0, 62.0, 28.0, 34.0, true],
		[215.0, 56.0, 25.0, 26.0, true], [270.0, 64.0, 30.0, 30.0, true], [325.0, 52.0, 22.0, 20.0, false],
		[60.0, 70.0, 22.0, 40.0, true], [240.0, 72.0, 20.0, 38.0, true],
	]
	var tips: Array[Vector3] = []
	for br in branches:
		var dir := _dir(br[0])
		var a := dir * (_trunk_radius(br[1]) - 1.0) + Vector3(0, br[1], 0)
		var b := a + dir * float(br[2]) * cos(deg_to_rad(br[3])) + Vector3(0, float(br[2]) * sin(deg_to_rad(br[3])), 0)
		var piece := _segment(SV + "tree-log.glb", a, b, 1.8, 0.249, 0.277)
		piece.reparent(crown)
		TreeLook.apply_to(piece, false, not br[4])
		if br[4]:
			tips.append(b)
	tips.append(Vector3(0, TreeLook.TRUNK_HEIGHT + 4.0, 0))
	# Leaf clusters around each leafy branch tip and over the top.
	var cluster_spots: Array[Vector3] = []
	for t in tips:
		cluster_spots.append(t)
		for j in 3:
			cluster_spots.append(t + Vector3(_rng.randf_range(-11, 11), _rng.randf_range(-6, 5), _rng.randf_range(-11, 11)))
	# A ring of clusters filling the middle of the crown.
	for j in 8:
		var a := TAU * j / 8.0
		cluster_spots.append(Vector3(cos(a) * 16.0, TreeLook.CANOPY_BASE + _rng.randf_range(4.0, 14.0), sin(a) * 16.0))
	for i in cluster_spots.size():
		var leaf := _model(N + "tree_fat.glb",
				Vector3.ONE * _rng.randf_range(26.0, 36.0), Vector3(0, _rng.randf_range(0, 360), 0))
		var size: Vector3 = leaf.get_meta("size")
		_place_bottom(leaf, cluster_spots[i] - Vector3(0, size.y * 0.55, 0))
		leaf.reparent(crown)
		TreeLook.apply_to(leaf, false, false, true)
		# The cluster's little trunk is hidden; a flat leafy cap closes the
		# opening it leaves underneath, so the crown looks solid from below.
		var cap := MeshInstance3D.new()
		cap.name = "LeafCap"
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = size.x * 0.34
		cap_mesh.height = size.x * 0.68
		cap_mesh.radial_segments = 8
		cap_mesh.rings = 4
		cap.mesh = cap_mesh
		cap.material_override = TreeLook.leaf()
		cap.position = Vector3(0.0, size.y * 0.24, 0.0)
		cap.scale = Vector3(1.0, 0.35, 1.0)
		leaf.add_child(cap)
		leaf.set_meta("base", leaf.transform)
		leaf.set_meta("order", _rng.randf())
		canopy.append(leaf)
	canopy.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.get_meta("order") < y.get_meta("order"))


# ---------------------------------------------------------------- moss & leaves

func _build_moss() -> void:
	# Long strands hanging from the trunk, knots and branches.
	var spots := [
		[200.0, 11.0], [230.0, 18.0], [300.0, 20.0], [20.0, 24.0], [60.0, 15.0], [120.0, 22.0],
		[160.0, 9.0], [340.0, 13.0], [100.0, 27.0],
	]
	for s in spots:
		var dir := _dir(s[0])
		var moss := _model(N + "hanging_moss.glb", Vector3(9.0, 9.0, 9.0), Vector3(0, -s[0] + 90.0, 0))
		var size: Vector3 = moss.get_meta("size")
		_place_bottom(moss, dir * (_trunk_radius(s[1]) + 0.1) + Vector3(0, s[1] - size.y, 0))
		TreeLook.apply_to(moss, true)
		_trunk_parts.append(moss)


func _build_leaves() -> void:
	# Fallen leaves on the ground around the trunk (flat, one draw call).
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
		if not island.is_ground(cell) or claimed.has(cell):
			continue
		var basis := Basis(Vector3.UP, _rng.randf_range(0, TAU))
		spots.append(Transform3D(basis, p - position + Vector3(0, 0.012, 0)))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	var fallen := MultiMeshInstance3D.new()
	fallen.name = "FallenLeaves"
	fallen.multimesh = mm
	var mat := TreeLook.leaf().duplicate() as StandardMaterial3D
	mat.albedo_color = TreeLook.LEAF_WITHERED.lerp(Color(0.62, 0.46, 0.3), 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fallen.material_override = mat
	fallen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fallen)
	# A few leaves always slowly falling past the camera.
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
		t.origin.y -= 5.0 * droop
		t.basis = t.basis.scaled(Vector3(1.0 + 0.1 * droop, 1.0 - 0.28 * droop, 1.0 + 0.1 * droop))
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
		var hides := _hides(o, from, to)
		var want := 0.78 if hides else 0.0
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
			var q: Vector3 = (o["xform"] as Transform3D).affine_inverse() * p
			var h: Vector3 = o["half"]
			if absf(q.x) < h.x and absf(q.y) < h.y and absf(q.z) < h.z:
				return true
	return false


## True if the occluder at index `i` is faded right now (for tests).
func is_faded(i: int) -> bool:
	return occluders[i].get("fade", 0.0) > 0.4


func _add_occluder_cyl(nodes: Array, r: float, y0: float, y1: float) -> void:
	occluders.append({"shape": "cyl", "r": r, "y0": y0, "y1": y1, "meshes": _meshes(nodes)})


func _add_occluder_box(nodes: Array, xform: Transform3D, half: Vector3) -> void:
	occluders.append({"shape": "box", "xform": xform, "half": half, "meshes": _meshes(nodes)})


func _meshes(nodes: Array) -> Array:
	var out := []
	for n: Node in nodes:
		if n is MeshInstance3D:
			out.append(n)
		out.append_array(n.find_children("*", "MeshInstance3D", true, false))
	return out


# ---------------------------------------------------------------- helpers

func _dir(angle_deg: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(cos(a), 0.0, sin(a))


## A model scaled (per axis) and rotated (degrees), centred on its holder in
## x/z with its lowest point at the holder's origin. meta "size" = its size.
func _model(path: String, scale: Vector3, rot_deg: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	var model := ModelLib.instance(path)
	model.scale = scale
	model.rotation_degrees = rot_deg
	holder.add_child(model)
	var box := ModelUtil.aabb_in(model, holder)
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	holder.set_meta("size", box.size)
	add_child(holder)
	return holder


func _place_bottom(holder: Node3D, at: Vector3) -> void:
	holder.position = at


## A log-like model stretched between two points: its length runs along the
## model's z axis, `w` and `h` are the model's own width and height.
func _segment(path: String, a: Vector3, b: Vector3, rad: float, w: float, h: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	var model := ModelLib.instance(path)
	var len := a.distance_to(b)
	var raw_len := ModelUtil.local_aabb(model).size.z
	model.scale = Vector3(rad * 2.0 / w, rad * 1.6 / h, (len + rad * 0.6) / raw_len)
	holder.add_child(model)
	var box := ModelUtil.aabb_in(model, holder)
	model.position = -box.get_center()
	var z := (b - a).normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	holder.transform = Transform3D(Basis(x, y, z), (a + b) / 2.0)
	add_child(holder)
	return holder


func _cells_within(p: Vector3, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var world := position + p
	var c := Grid.world_to_cell(world, island.map_size)
	var span := int(ceil(r / Grid.TILE)) + 1
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := c + Vector2i(dx, dz)
			var cc := Grid.cell_center(cell, island.map_size)
			# Nearest point of the tile to the circle centre.
			var nx := clampf(world.x, cc.x - Grid.TILE / 2.0, cc.x + Grid.TILE / 2.0)
			var nz := clampf(world.z, cc.z - Grid.TILE / 2.0, cc.z + Grid.TILE / 2.0)
			if Vector2(nx - world.x, nz - world.z).length() < r - 0.05 and island.is_ground(cell):
				out.append(cell)
	return out


func _cyl_collider(body: StaticBody3D, r: float, y0: float, y1: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = y1 - y0
	cs.shape = cyl
	cs.position = Vector3(0, (y0 + y1) / 2.0, 0)
	body.add_child(cs)
