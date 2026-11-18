class_name Treehouse
## Leafwind's own look: a soft, slightly muted palette (sage and moss
## greens, pale straw yellow, cream, warm wood, pale sky blue) and builders
## for treehouse buildings made from simple shapes, so Leafwind doesn't
## share Pebblenook's Town Kit houses or its red and teal roofs:
##  - log walls (round logs, interlocking at the corners)
##  - leaf-thatch roofs in overlapping, scalloped tiers
##  - round windows with a warm glow behind them, arched plank doors
##  - a tree trunk growing up through the roof, with branches and leaves
## Bark, logs and branches use shaders/bark.gdshader; floors use
## shaders/leafwind_floor.gdshader.

const WOOD := Color(0.8, 0.6, 0.4)          # honey oak
const WOOD_LIGHT := Color(0.9, 0.73, 0.5)
const WOOD_DARK := Color(0.56, 0.4, 0.28)
const CREAM := Color(0.96, 0.91, 0.78)
const BARK := Color(0.55, 0.42, 0.31)
const BARK_DARK := Color(0.42, 0.32, 0.25)
const LEAF := Color(0.55, 0.72, 0.4)
const LEAF_DARK := Color(0.42, 0.6, 0.34)
const LEAF_LIGHT := Color(0.7, 0.8, 0.5)
const STRAW := Color(0.93, 0.82, 0.55)
const MOSS := Color(0.52, 0.66, 0.38)
## Floor tints: decks, the lighter main walkways, the round plaza.
const DECK := Color(0.86, 0.64, 0.41)
const WALKWAY := Color(0.94, 0.77, 0.53)
const PLAZA_WOOD := Color(0.9, 0.7, 0.46)
const SKY := Color(0.74, 0.84, 0.9)
const ROPE := Color(0.8, 0.72, 0.55)
const GLOW := Color(1.0, 0.86, 0.6)
## Log radius for walls (m).
const LOG_R := 0.13

static var _materials := {}


# ---------------------------------------------------------------- materials

## Floor material: "deck" / "walk" (planks; board direction comes from each
## quad's UV.x), "moss", "plaza" (round boards; give it a centre).
static func floor_material(kind: String) -> ShaderMaterial:
	var key := "floor_" + kind
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/leafwind_floor.gdshader")
		m.set_shader_parameter("kind", {"deck": 0, "walk": 0, "moss": 2, "plaza": 4}[kind] as int)
		m.set_shader_parameter("board_width", 0.48 if kind == "walk" else 0.42)
		_materials[key] = m
	return _materials[key]


static func bark_material() -> ShaderMaterial:
	if not _materials.has("bark"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/bark.gdshader")
		_materials["bark"] = m
	return _materials["bark"]


## Plain vertex-coloured material (leaves, thatch, doors).
static func flat_material() -> StandardMaterial3D:
	if not _materials.has("flat"):
		var m := MeshUtil.vertex_color_material()
		m.roughness = 0.9
		_materials["flat"] = m
	return _materials["flat"]


## A softly glowing window pane: warm lamplight (outside) or pale sky (inside).
static func glow_material(colour := GLOW) -> StandardMaterial3D:
	var key := "glow_" + colour.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour.darkened(0.3)
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 0.7
		_materials[key] = m
	return _materials[key]


static func mesh(st: SurfaceTool, mat: Material, mesh_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


# ---------------------------------------------------------------- shapes

## A round tube through `pts` with a radius per point (bark / log pieces).
## UV.x = metres along, UV.y = 0..1 around (for the bark shader).
static func add_tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, colour: Color, sides := 8, caps := true) -> void:
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var along := PackedFloat32Array()
	var dist := 0.0
	var ref := Vector3.UP
	for i in pts.size():
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(tangent.dot(ref)) > 0.9:
			ref = Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
		var u := tangent.cross(ref).normalized()
		var v := tangent.cross(u).normalized()
		var ring := PackedVector3Array()
		var ns := PackedVector3Array()
		for k in sides + 1:
			var a := TAU * k / sides
			var n := u * cos(a) + v * sin(a)
			ring.append(pts[i] + n * radii[i])
			ns.append(n)
		rings.append(ring)
		norms.append(ns)
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		along.append(dist)
	for i in pts.size() - 1:
		for k in sides:
			for idx in [[i, k], [i, k + 1], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i + 1, k]]:
				st.set_color(colour)
				st.set_uv(Vector2(along[idx[0]], float(idx[1]) / sides))
				st.set_normal(norms[idx[0]][idx[1]])
				st.add_vertex(rings[idx[0]][idx[1]])
	if caps:
		for end in [0, pts.size() - 1]:
			var n := (pts[end] - pts[1 if end == 0 else end - 1]).normalized()
			for k in sides:
				for v in [pts[end], rings[end][k], rings[end][k + 1]]:
					st.set_color(colour.darkened(0.15))
					st.set_uv(Vector2(along[end], 0.0))
					st.set_normal(n)
					st.add_vertex(v)


static func add_log(st: SurfaceTool, a: Vector3, b: Vector3, r: float, colour: Color, sides := 8) -> void:
	add_tube(st, PackedVector3Array([a, b]), PackedFloat32Array([r, r]), colour, sides)


## A tapering, gently bending branch from `a` to `b` (bark).
static func add_branch(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, bend: Vector3, colour: Color, segs := 6) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in segs + 1:
		var t := float(i) / segs
		pts.append(a.lerp(b, t) + bend * sin(PI * t))
		radii.append(lerpf(r0, r1, t))
	add_tube(st, pts, radii, colour, 8)


## A low-poly clump of leaves: a squashed, jittered sphere, flat shaded.
static func add_leaf_blob(st: SurfaceTool, centre: Vector3, size: Vector3, colour: Color, rng: RandomNumberGenerator) -> void:
	var rings := 4
	var segs := 7
	var pts: Array[PackedVector3Array] = []
	for i in rings + 1:
		var lat := PI * float(i) / rings - PI / 2.0
		var ring := PackedVector3Array()
		for k in segs:
			var lon := TAU * float(k) / segs + (0.3 if i % 2 == 1 else 0.0)
			var j := 1.0 if (i == 0 or i == rings) else rng.randf_range(0.82, 1.08)
			ring.append(centre + Vector3(cos(lat) * cos(lon) * size.x, sin(lat) * size.y, cos(lat) * sin(lon) * size.z) * j)
		pts.append(ring)
	for i in rings:
		for k in segs:
			var k2 := (k + 1) % segs
			var c := colour.darkened(rng.randf_range(-0.06, 0.12))
			_tri(st, pts[i][k], pts[i + 1][k], pts[i + 1][k2], c, centre)
			_tri(st, pts[i][k], pts[i + 1][k2], pts[i][k2], c, centre)


## Flat-shaded triangle facing away from `inside`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-8:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_color(col)
		st.set_uv(Vector2.ZERO)  # every vertex has a UV, so tubes can share the mesh
		st.set_normal(n)
		st.add_vertex(v)


## A box with its own colour (for panels, sills, frames).
static func add_box(st: SurfaceTool, lo: Vector3, hi: Vector3, colour: Color) -> void:
	MeshUtil.add_box(st, lo, hi, colour, colour.darkened(0.12))


# ---------------------------------------------------------------- buildings

## A treehouse cabin or hut on a footprint of `size` tiles (1 x 1 or 2 x 2),
## origin at the footprint's centre on its floor. Log walls, an arched door
## on the front (+z) at `door_x`, round glowing windows, a leaf-thatch roof
## and (if `tree`) a trunk growing up through the roof with leafy branches.
## `storeys` stacks the log walls (windmill towers use 2).
## Returns a node with "Model" / "Body" like every prop.
static func cabin(size: Vector2i, door_x: float, tree: bool, seed_value: int, roof_colour := LEAF, storeys := 1, wall_half := -1.0, eave_half := -1.0) -> Node3D:
	var root := Props._root()
	var model := root.get_node("Model") as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := float(size.x) * Grid.TILE / 2.0
	var w := wall_half if wall_half > 0.0 else half - 0.27  # wall centre line
	var h := (2.4 if size.x > 1 else 2.0) * storeys        # wall height
	var logs := SurfaceTool.new()
	logs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := LOG_R
	var overhang := minf(0.14, half - w - r - 0.02)
	# Front / back logs at even heights, side logs at odd ones, so they
	# interlock at the corners.
	var rows := int(h / (2.0 * r))
	for i in rows:
		var y := r + 2.0 * r * i
		var tone := WOOD.darkened(rng.randf_range(-0.05, 0.1))
		if i % 2 == 0:
			for z in [-w, w]:
				add_log(logs, Vector3(-w - overhang, y, z), Vector3(w + overhang, y, z), r, tone)
		else:
			for x in [-w, w]:
				add_log(logs, Vector3(x, y, -w - overhang), Vector3(x, y, w + overhang), r, tone)
	# Side walls start one log up: a sill beam fills under them.
	for x in [-w, w]:
		add_box(logs, Vector3(x - r * 0.9, 0.0, -w + r), Vector3(x + r * 0.9, r, w - r), WOOD_DARK)
	model.add_child(mesh(logs, bark_material(), "LogWalls"))
	# Inside: a closed, dark box, so nothing shows through any gap.
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := WOOD_DARK.darkened(0.4)
	MeshUtil.add_box(inner, Vector3(-w + r * 0.5, 0.012, -w + r * 0.5), Vector3(w - r * 0.5, h - 0.05, w - r * 0.5), dark, dark, true, false)
	model.add_child(mesh(inner, flat_material(), "Inside"))
	# Door and windows on the face of the logs.
	var face := w + r + 0.015
	var trim := SurfaceTool.new()
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var door_w := 0.8 if size.x > 1 else 0.66
	var door_h := 1.55 if size.x > 1 else 1.4
	_arched_panel(trim, Vector3(door_x, 0.0, face), door_w + 0.14, door_h + 0.07, 0.03, WOOD_DARK)
	_arched_panel(trim, Vector3(door_x, 0.0, face + 0.03), door_w, door_h, 0.035, WOOD_LIGHT)
	add_box(trim, Vector3(door_x + door_w * 0.28, door_h * 0.45, face + 0.065), Vector3(door_x + door_w * 0.36, door_h * 0.52, face + 0.09), WOOD_DARK)
	model.add_child(mesh(trim, flat_material(), "Door"))
	var win_y := (1.35 if size.x > 1 else 1.2)
	var windows: Array = []
	if size.x > 1 and absf(door_x) > 0.5:
		windows.append([Vector3(-door_x, win_y, face), Vector3.BACK])
	windows.append([Vector3(face, win_y, 0.0), Vector3.RIGHT])
	windows.append([Vector3(-face, win_y, 0.0), Vector3.LEFT])
	windows.append([Vector3(0.0, win_y, -face), Vector3.FORWARD])
	if storeys > 1:
		windows.append([Vector3(0.0, win_y + 2.0, face), Vector3.BACK])
		windows.append([Vector3(face, win_y + 2.0, 0.0), Vector3.RIGHT])
	for wdw in windows:
		model.add_child(round_window(wdw[0], wdw[1], 0.26 if size.x > 1 else 0.2))
	# Leaf-thatch roof.
	var eave := eave_half if eave_half > 0.0 else half - 0.08
	var roof_h := 1.7 if size.x > 1 else 1.3
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	thatch(roof, Vector3(0.0, h - 0.02, 0.0), eave, roof_h, 4 if size.x > 1 or storeys > 1 else 10, roof_colour, rng)
	model.add_child(mesh(roof, flat_material(), "Thatch"))
	# A trunk growing up through the roof, with leafy branches.
	var top_y := h + roof_h
	if tree:
		var bark := SurfaceTool.new()
		bark.begin(Mesh.PRIMITIVE_TRIANGLES)
		var leaves := SurfaceTool.new()
		leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
		var crown := Vector3(0.0, top_y + 1.6, 0.0)
		add_branch(bark, Vector3(0.0, h * 0.5, 0.0), crown, 0.34, 0.2, Vector3(0.1, 0.0, -0.05), BARK)
		var reach := half - 0.75
		for i in 3:
			var a := TAU * i / 3.0 + 0.4
			var tip := Vector3(cos(a) * reach, top_y + 0.9 + 0.3 * i, sin(a) * reach)
			add_branch(bark, crown - Vector3(0.0, 0.5, 0.0), tip, 0.13, 0.06, Vector3(0.0, 0.25, 0.0), BARK)
			add_leaf_blob(leaves, tip + Vector3(0.0, 0.25, 0.0), Vector3(0.62, 0.42, 0.62), [LEAF, LEAF_DARK, LEAF_LIGHT][i], rng)
		add_leaf_blob(leaves, crown + Vector3(0.0, 0.35, 0.0), Vector3(0.85, 0.6, 0.85), LEAF, rng)
		model.add_child(mesh(bark, bark_material(), "Trunk"))
		model.add_child(mesh(leaves, flat_material(), "Leaves"))
	else:
		# A curl of stalk on the tip of the roof.
		var stalk := SurfaceTool.new()
		stalk.begin(Mesh.PRIMITIVE_TRIANGLES)
		add_branch(stalk, Vector3(0.0, top_y - 0.15, 0.0), Vector3(0.18, top_y + 0.35, 0.05), 0.07, 0.025, Vector3(-0.08, 0.05, 0.0), BARK)
		model.add_child(mesh(stalk, bark_material(), "Stalk"))
	var foot := 2.0 * (w + r)
	Props._box_collider(root, Vector3(foot, h, foot), Vector3(0.0, h / 2.0, 0.0))
	return root


## A round window on a wall at `pos`, facing `out`: a glowing pane in a
## ring of wood.
static func round_window(pos: Vector3, out: Vector3, radius: float, pane_colour := GLOW) -> Node3D:
	var node := Node3D.new()
	node.name = "RoundWindow"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u := out.cross(Vector3.UP).normalized()
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 17:
		var a := TAU * k / 16.0
		ring.append(pos + out * 0.07 + (u * cos(a) + Vector3.UP * sin(a)) * radius)
		radii.append(0.05)
	add_tube(st, ring, radii, WOOD_DARK, 6, false)
	# Cross bars.
	add_log(st, pos + out * 0.04 - u * radius, pos + out * 0.04 + u * radius, 0.025, WOOD_DARK, 5)
	add_log(st, pos + out * 0.04 - Vector3.UP * radius, pos + out * 0.04 + Vector3.UP * radius, 0.025, WOOD_DARK, 5)
	node.add_child(mesh(st, flat_material(), "Frame"))
	var pane := SurfaceTool.new()
	pane.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 16:
		var a0 := TAU * k / 16.0
		var a1 := TAU * (k + 1) / 16.0
		# The pane sits just off the logs, behind the frame and its bars.
		for v in [pos + out * 0.006, pos + out * 0.006 + (u * cos(a0) + Vector3.UP * sin(a0)) * radius,
				pos + out * 0.006 + (u * cos(a1) + Vector3.UP * sin(a1)) * radius]:
			pane.set_color(Color.WHITE)
			pane.set_normal(out)
			pane.add_vertex(v)
	node.add_child(mesh(pane, glow_material(pane_colour), "Pane"))
	return node


## A flat panel with an arched top, standing at `base` (bottom middle),
## facing +z, `depth` thick.
static func _arched_panel(st: SurfaceTool, base: Vector3, width: float, height: float, depth: float, colour: Color) -> void:
	var rad := width / 2.0
	var straight := height - rad
	add_box(st, base + Vector3(-rad, 0.0, 0.0), base + Vector3(rad, straight, depth), colour)
	var segs := 10
	for k in segs:
		var a0 := PI * k / segs
		var a1 := PI * (k + 1) / segs
		var c := base + Vector3(0.0, straight, 0.0)
		var p0 := c + Vector3(cos(a0) * rad, sin(a0) * rad, 0.0)
		var p1 := c + Vector3(cos(a1) * rad, sin(a1) * rad, 0.0)
		for zz in [depth, 0.0]:
			var n := Vector3.BACK if zz > 0.0 else Vector3.FORWARD
			for v in [c, p0, p1]:
				st.set_color(colour)
				st.set_normal(n)
				st.add_vertex(v + Vector3(0.0, 0.0, zz))
		for v in [p0, p1, p1 + Vector3(0, 0, depth), p0, p1 + Vector3(0, 0, depth), p0 + Vector3(0, 0, depth)]:
			st.set_color(colour.darkened(0.12))
			st.set_normal(((p0 + p1) / 2.0 - c).normalized())
			st.add_vertex(v)


## A leaf-thatch roof: three overlapping tiers, each with a scalloped lower
## edge, rising from `base` (eave height) to a point `height` above it.
## `sides` = 4 for a square roof, more for a round one.
static func thatch(st: SurfaceTool, base: Vector3, eave: float, height: float, sides: int, colour: Color, rng: RandomNumberGenerator) -> void:
	var tiers := 3
	var scallops := 4
	var tones := [colour, colour.darkened(0.1), colour.lightened(0.08)]
	for t in tiers:
		var s0 := 1.0 - float(t) / tiers
		var s1 := maxf(0.0, 1.0 - float(t + 1) / tiers - 0.04)
		var y0 := base.y + height * float(t) / tiers - (0.1 if t > 0 else 0.0)
		var y1 := base.y + height * minf(1.0, float(t + 1) / tiers + 0.06)
		var tone: Color = tones[t]
		for k in sides:
			var c0 := _roof_corner(k, sides, eave)
			var c1 := _roof_corner(k + 1, sides, eave)
			for j in scallops:
				var f0 := float(j) / scallops
				var f1 := float(j + 1) / scallops
				var fm := (f0 + f1) / 2.0
				var lo0 := c0.lerp(c1, f0) * s0
				var lo1 := c0.lerp(c1, f1) * s0
				var lom := c0.lerp(c1, fm) * s0 * 1.02
				var hi0 := c0.lerp(c1, f0) * s1
				var hi1 := c0.lerp(c1, f1) * s1
				var drop := 0.1 + rng.randf_range(0.0, 0.05)
				var a := Vector3(lo0.x, y0, lo0.y) + Vector3(base.x, 0, base.z)
				var b := Vector3(lo1.x, y0, lo1.y) + Vector3(base.x, 0, base.z)
				var m := Vector3(lom.x, y0 - drop, lom.y) + Vector3(base.x, 0, base.z)
				var c := Vector3(hi1.x, y1, hi1.y) + Vector3(base.x, 0, base.z)
				var d := Vector3(hi0.x, y1, hi0.y) + Vector3(base.x, 0, base.z)
				var col := tone.darkened(rng.randf_range(-0.04, 0.08))
				var inside := Vector3(base.x, y0 - 1.0, base.z)
				_tri(st, a, m, d, col, inside)
				_tri(st, m, c, d, col, inside)
				_tri(st, m, b, c, col, inside)
	# Underside of the eaves (seen from low angles).
	for k in sides:
		var c0 := _roof_corner(k, sides, eave)
		var c1 := _roof_corner(k + 1, sides, eave)
		_tri(st, base, Vector3(c0.x, base.y, c0.y) + Vector3(base.x, 0, base.z), Vector3(c1.x, base.y, c1.y) + Vector3(base.x, 0, base.z),
				colour.darkened(0.45), base + Vector3(0.0, 1.0, 0.0))


static func _roof_corner(k: int, sides: int, eave: float) -> Vector2:
	if sides == 4:
		return [Vector2(-eave, -eave), Vector2(eave, -eave), Vector2(eave, eave), Vector2(-eave, eave)][k % 4]
	var a := TAU * k / sides
	return Vector2(cos(a), sin(a)) * eave
