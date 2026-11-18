class_name LeafwindProps
## Props for Leafwind, the breezy canopy village stuck in a dead calm.
## Same contract as Props: each builder returns a Node3D whose origin is the
## centre of its footprint on its floor, with "Model" (visible parts, inside
## the footprint, flush on the floor) and "Body" (collider) children.
## Kenney models where a pack has one; simple shapes in the game's colours
## for the rest (kites, chimes, bunting, the knot of wind).
## Everything droops: the wind has died.

const T := ModelLib.TOWN
const P := ModelLib.PLATFORMER
const S := ModelLib.SURVIVAL
const NK := "res://Assets/Nature Kit/Models/GLTF format/"
const FOOD := "res://Assets/food kit/Models/GLB format/"

## Leafwind's soft, slightly tired colours.
const GREEN := Color(0.56, 0.76, 0.45)
const YELLOW := Color(0.96, 0.85, 0.5)
const WHITE := Color(0.95, 0.95, 0.92)
const BLUE := Color(0.63, 0.79, 0.9)
const WOOD := Color(0.6, 0.42, 0.28)
const ROPE := Color(0.78, 0.68, 0.5)
const KITE_COLOURS := {"yellow": YELLOW, "blue": BLUE, "white": WHITE, "green": GREEN}
## Windmill sails: hub height (m), size and how far in front of the tower's
## face the hub sits (clear of the roof's eaves, so they could turn). The
## sails sit on their own "Sails" node, pivoting on the hub.
const SAIL_HUB_HEIGHT := 4.3
const SAIL_SCALE := 1.25
const SAIL_OUT := 0.62
## The windmill tower's log walls (centre line, m from the middle) and the
## reach of its thatch, kept clear of the sails.
const TOWER_HALF := 0.9
const TOWER_EAVE := 1.18


## Builds a Leafwind prop, or returns null for a type this file doesn't know.
static func build(p: Dictionary) -> Node3D:
	match p["type"]:
		"windmill":
			return windmill(p.get("rot", 0.0))
		"kite_pole":
			return kite_pole(p.get("color", "yellow"), p.get("rot", 0.0))
		"kite_rack":
			return kite_rack(p.get("rot", 0.0))
		"wind_chime":
			return wind_chime(p.get("rot", 0.0))
		"banner_pole":
			return banner_pole(p.get("red", false), p.get("rot", 0.0))
		"bunting":
			return bunting(p.get("size", Vector2i(2, 1)))
		"planter":
			return planter(p.get("flower", "flower_yellowA"), p.get("rot", 0.0))
		"hut":
			return hut(p.get("straw", false), p.get("rot", 0.0))
		"cabin":
			return cabin(p.get("seed", 1), p.get("straw", false))
		"paper_lantern":
			return paper_lantern(p.get("rot", 0.0))
		"tub_tree":
			return tub_tree(p.get("seed", 1))
		"stump_table":
			return stump_table()
		"bake_stall":
			return bake_stall(p.get("rot", 0.0))
		"oven":
			return oven()
		"rope_coils":
			return rope_coils(p.get("rot", 0.0))
		"weathervane":
			return weathervane()
		"telescope":
			return telescope(p.get("rot", 0.0))
		"wind_cliff":
			return wind_cliff(p.get("size", Vector2i(5, 3)))
	return null


# ---------------------------------------------------------------- windmill

## A 2 x 2 tile windmill in Leafwind's treehouse style: a two-storey log
## tower with round windows and an arched door, a leaf-thatch cap, and the
## pack's windmill sails (Fantasy Town Kit) on an axle out front, frozen
## still. The sails hang on their own pivot node ("Sails", meta
## "spin_axis") so they can turn later.
static func windmill(rot := 0.0) -> Node3D:
	var root := Treehouse.cabin(Vector2i(2, 2), 0.0, false, 31 + int(rot), Treehouse.LEAF_DARK, 2, TOWER_HALF, TOWER_EAVE)
	var model := root.get_node("Model") as Node3D
	for child in model.get_children():
		child.rotation_degrees.y = rot
		child.position = child.position.rotated(Vector3.UP, deg_to_rad(rot))
	var frame := _frame(root, rot)
	# Sails on the front (+z) face, on an axle out from the logs, well clear
	# of the thatch. The pack model turns about its x axis, so it is turned
	# to face +z; the pivot spins about its own z axis.
	var face := TOWER_HALF + Treehouse.LOG_R
	var hub := Vector3(0.0, SAIL_HUB_HEIGHT, face + SAIL_OUT)
	var axle := Props._rod(Vector3(0.0, SAIL_HUB_HEIGHT, face - 0.05), hub, 0.07, Treehouse.WOOD_DARK)
	axle.name = "Axle"
	frame.add_child(axle)
	var sails := Node3D.new()
	sails.name = "Sails"
	sails.position = hub
	sails.set_meta("spin_axis", Vector3(0.0, 0.0, 1.0))
	sails.add_to_group("windmill_sails")
	var blades := ModelLib.instance(T + "windmill.glb")
	blades.scale = Vector3.ONE * SAIL_SCALE
	blades.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	sails.add_child(blades)
	# Stopped upright, the way the last breeze left it.
	frame.add_child(sails)
	# The cabin's collider covers the tower; widen it to the sails too.
	for cs in root.get_node("Body").get_children():
		cs.free()
	Props._collider_from_model(root)
	return root


# ---------------------------------------------------------------- kites

## A tall pole with a kite hanging limp from its line, tail drooping.
static func kite_pole(colour: String, rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var pole := ModelLib.instance(T + "pillar-wood.glb")
	pole.scale = Vector3(1.0, 3.0, 1.0)
	pole.position = Vector3(-0.45, 0.0, 0.0)
	model.add_child(pole)
	# The line drops from the pole top to the kite's nose.
	model.add_child(Props._rod(Vector3(-0.45, 2.95, 0.0), Vector3(0.15, 2.45, 0.0), 0.012, ROPE))
	model.add_child(_kite(KITE_COLOURS.get(colour, YELLOW), Vector3(0.2, 2.45, 0.05), -160.0, 0.9))
	return _finish(root)


## A drying rack in the kite-maker's yard: two posts and a bar with three
## half-finished kites hanging from it.
static func kite_rack(rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	for x in [-0.8, 0.8]:
		var post := ModelLib.instance(T + "pillar-wood.glb")
		post.scale = Vector3(1.0, 1.9, 1.0)
		post.position = Vector3(x, 0.0, 0.0)
		model.add_child(post)
	model.add_child(Props._rod(Vector3(-0.8, 1.82, 0.0), Vector3(0.8, 1.82, 0.0), 0.035, WOOD))
	var colours := [YELLOW, BLUE, WHITE]
	for i in 3:
		var x := -0.5 + 0.5 * i
		model.add_child(_kite(colours[i], Vector3(x, 1.8, 0.06), 180.0, 0.55))
	return _finish(root)


## A diamond kite (two cloth triangles and its cross sticks) with a tail of
## little bows. `nose` is where the top of the kite is; `tilt` turns it
## (180 = hanging upside down); `size` is its height in metres.
static func _kite(colour: Color, nose: Vector3, tilt: float, size: float) -> Node3D:
	var kite := Node3D.new()
	kite.name = "Kite"
	kite.position = nose
	kite.rotation_degrees.z = tilt + 180.0
	var h := size
	var w := size * 0.62
	var top := Vector3(0.0, 0.0, 0.0)
	var left := Vector3(-w / 2.0, -h * 0.32, 0.0)
	var right := Vector3(w / 2.0, -h * 0.32, 0.0)
	var bottom := Vector3(0.0, -h, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[top, right, bottom, colour], [top, bottom, left, colour.darkened(0.12)]]:
		for v in [tri[0], tri[1], tri[2]]:
			st.set_color(tri[3])
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	cloth.mesh = st.commit()
	cloth.material_override = MeshUtil.vertex_color_material()
	kite.add_child(cloth)
	kite.add_child(Props._rod(top + Vector3(0, 0, 0.01), bottom + Vector3(0, 0, 0.01), 0.01, WOOD))
	kite.add_child(Props._rod(left + Vector3(0, 0, 0.01), right + Vector3(0, 0, 0.01), 0.01, WOOD))
	# Tail: hangs straight down (no wind), with a few bows.
	var tail_top := bottom
	var tail_end := bottom + Vector3(0.02, -h * 0.55, 0.0)
	kite.add_child(Props._rod(tail_top, tail_end, 0.006, ROPE))
	for i in 3:
		var bow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.09, 0.05, 0.01)
		bow.mesh = prism
		bow.material_override = MeshUtil.color_material([BLUE, YELLOW, WHITE][i])
		bow.position = tail_top.lerp(tail_end, 0.3 + 0.3 * i)
		bow.rotation_degrees.z = 90.0
		kite.add_child(bow)
	return kite


# ---------------------------------------------------------------- chimes, banners, bunting

## A post with a crossbar and five hanging tubes, quite still.
static func wind_chime(rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var post := ModelLib.instance(T + "pillar-wood.glb")
	post.scale = Vector3(1.0, 2.5, 1.0)
	model.add_child(post)
	model.add_child(Props._rod(Vector3(0.0, 2.38, 0.0), Vector3(0.6, 2.38, 0.0), 0.03, WOOD))
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.03
	ring.mesh = disc
	ring.material_override = MeshUtil.color_material(WOOD)
	ring.position = Vector3(0.5, 2.2, 0.0)
	model.add_child(ring)
	model.add_child(Props._rod(Vector3(0.5, 2.37, 0.0), Vector3(0.5, 2.21, 0.0), 0.006, ROPE))
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.82, 0.88)
	metal.metallic = 0.6
	metal.roughness = 0.35
	for i in 5:
		var a := TAU * i / 5.0
		var top := Vector3(0.5 + cos(a) * 0.15, 2.19, sin(a) * 0.15)
		var length := 0.35 + 0.08 * i
		var tube := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.022
		cyl.height = length
		cyl.radial_segments = 8
		tube.mesh = cyl
		tube.material_override = metal
		tube.position = top - Vector3(0.0, 0.06 + length / 2.0, 0.0)
		model.add_child(tube)
		model.add_child(Props._rod(top, top - Vector3(0.0, 0.06, 0.0), 0.004, ROPE))
	return _finish(root)


## A cloth banner hanging limp from a pole and crossbar: a soft strip of
## cloth with a gentle fold or two (no wind to lift it) and a leaf sewn on.
static func banner_pole(red: bool, rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Treehouse.add_log(st, Vector3(-0.5, 0.0, 0.0), Vector3(-0.5, 2.8, 0.0), 0.07, Treehouse.WOOD)
	Treehouse.add_log(st, Vector3(-0.55, 2.66, 0.0), Vector3(0.45, 2.66, 0.0), 0.035, Treehouse.WOOD)
	model.add_child(Treehouse.mesh(st, Treehouse.bark_material(), "Pole"))
	var cloth_colour := Treehouse.STRAW if red else Treehouse.SKY
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 2.62
	var length := 1.5
	var cols := 6
	var rows := 8
	for j in rows:
		for i in cols:
			var quad := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var x := -0.45 + 0.9 * float(c[0]) / cols
				var y := top - length * float(c[1]) / rows
				var fold := sin(float(c[0]) / cols * TAU * 1.5) * 0.04 * float(c[1]) / rows
				quad.append(Vector3(x, y, fold))
			for k in [0, 1, 2, 0, 2, 3]:
				cloth.set_color(cloth_colour.darkened(0.06 * float(j) / rows))
				cloth.set_normal(Vector3.BACK)
				cloth.add_vertex(quad[k])
	# A swallow-tail notch at the bottom and a leaf emblem.
	var leaf_c := Vector3(0.0, top - length * 0.45, 0.035)
	for v in [leaf_c + Vector3(0, 0.22, 0), leaf_c + Vector3(0.13, 0, 0), leaf_c + Vector3(0, -0.22, 0),
			leaf_c + Vector3(0, 0.22, 0), leaf_c + Vector3(0, -0.22, 0), leaf_c + Vector3(-0.13, 0, 0)]:
		cloth.set_color(Treehouse.LEAF_DARK)
		cloth.set_normal(Vector3.BACK)
		cloth.add_vertex(v)
	var cloth_mi := Treehouse.mesh(cloth, Treehouse.flat_material(), "Cloth")
	cloth_mi.position.x = 0.0
	model.add_child(cloth_mi)
	return _finish(root)


## A paper lantern on a crook-topped post: a soft, pale-yellow glowing
## globe hanging quite still.
static func paper_lantern(rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Treehouse.add_log(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 2.2, 0.0), 0.06, Treehouse.WOOD)
	Treehouse.add_branch(st, Vector3(0.0, 2.15, 0.0), Vector3(0.5, 2.35, 0.0), 0.045, 0.03, Vector3(0.0, 0.12, 0.0), Treehouse.WOOD)
	model.add_child(Treehouse.mesh(st, Treehouse.bark_material(), "Post"))
	model.add_child(Props._rod(Vector3(0.5, 2.3, 0.0), Vector3(0.5, 1.95, 0.0), 0.008, ROPE))
	var globe := MeshInstance3D.new()
	globe.name = "Lantern"
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.34
	globe.mesh = sphere
	globe.material_override = Treehouse.glow_material(Color(1.0, 0.92, 0.7))
	globe.position = Vector3(0.5, 1.95 - 0.17, 0.0)
	model.add_child(globe)
	return _finish(root)


## The round plaza's table: a broad old tree stump with a pale, ringed top
## and flared roots, two little stump stools beside it, and a pie and a
## croissant waiting for company.
static func stump_table() -> Node3D:
	var root := Props._root()
	var model := _frame(root, 0.0)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 0.78
	Treehouse.add_tube(bark, PackedVector3Array([Vector3.ZERO, Vector3(0.0, top, 0.0)]), PackedFloat32Array([0.6, 0.54]), Treehouse.BARK, 12)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var out := Vector3(cos(a), 0.0, sin(a))
		Treehouse.add_branch(bark, out * 0.4 + Vector3(0.0, 0.3, 0.0), out * 0.82 + Vector3(0.0, 0.055, 0.0), 0.15, 0.05, Vector3(0.0, 0.05, 0.0), Treehouse.BARK, 4)
	for x in [-0.76, 0.76]:
		Treehouse.add_tube(bark, PackedVector3Array([Vector3(x, 0.0, 0.0), Vector3(x, 0.42, 0.0)]), PackedFloat32Array([0.19, 0.17]), Treehouse.BARK, 10)
	model.add_child(Treehouse.mesh(bark, Treehouse.bark_material(), "Stump"))
	# Pale cut tops with growth rings.
	var wood := MeshUtil.color_material(Color(0.93, 0.8, 0.6))
	var ring_mat := MeshUtil.color_material(Color(0.78, 0.6, 0.4))
	for t in [[Vector3(0.0, top, 0.0), 0.53, [0.18, 0.32, 0.44]], [Vector3(-0.76, 0.42, 0.0), 0.16, [0.08]], [Vector3(0.76, 0.42, 0.0), 0.16, [0.08]]]:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = t[1]
		cyl.bottom_radius = t[1]
		cyl.height = 0.02
		cyl.radial_segments = 20
		disc.mesh = cyl
		disc.material_override = wood
		disc.position = (t[0] as Vector3) + Vector3(0.0, 0.016, 0.0)  # 6 mm clear of the stump's cap
		model.add_child(disc)
		for r: float in t[2]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = r - 0.008
			torus.outer_radius = r + 0.008
			torus.rings = 24
			ring.mesh = torus
			ring.material_override = ring_mat
			ring.scale = Vector3(1.0, 0.3, 1.0)
			ring.position = (t[0] as Vector3) + Vector3(0.0, 0.027, 0.0)
			model.add_child(ring)
	var pie := ModelLib.fitted(FOOD + "pie.glb", Vector2(0.42, 0.42), 1.0, 0.0)
	pie.position = Vector3(-0.12, top + 0.027, 0.08)
	model.add_child(pie)
	var croissant := ModelLib.fitted(FOOD + "croissant.glb", Vector2(0.22, 0.22), 1.0, 0.0, 40.0)
	croissant.position = Vector3(0.24, top + 0.027, -0.16)
	model.add_child(croissant)
	return _finish(root)


## A small tree growing in a wooden tub: bark trunk, a few branches, soft
## clumps of muted leaves. Kept inside its tile.
static func tub_tree(seed_value: int) -> Node3D:
	var root := Props._root()
	var model := root.get_node("Model") as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_add_tub(model, 0.48, 0.5)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := rng.randf_range(3.0, 3.8)
	var crown := Vector3(rng.randf_range(-0.1, 0.1), height - 0.9, rng.randf_range(-0.1, 0.1))
	Treehouse.add_branch(bark, Vector3(0.0, 0.4, 0.0), crown, 0.13, 0.08, Vector3(0.08, 0.0, 0.05), Treehouse.BARK)
	var tones := [Treehouse.LEAF, Treehouse.LEAF_DARK, Treehouse.LEAF_LIGHT]
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf_range(0.0, 1.0)
		var tip := crown + Vector3(cos(a) * 0.45, rng.randf_range(0.0, 0.4), sin(a) * 0.45)
		Treehouse.add_branch(bark, crown - Vector3(0.0, 0.4, 0.0), tip, 0.06, 0.03, Vector3(0.0, 0.1, 0.0), Treehouse.BARK)
		Treehouse.add_leaf_blob(leaves, tip + Vector3(0.0, 0.15, 0.0), Vector3(0.42, 0.32, 0.42), tones[i], rng)
	Treehouse.add_leaf_blob(leaves, crown + Vector3(0.0, 0.45, 0.0), Vector3(0.55, 0.45, 0.55), Treehouse.LEAF, rng)
	model.add_child(Treehouse.mesh(bark, Treehouse.bark_material(), "Trunk"))
	model.add_child(Treehouse.mesh(leaves, Treehouse.flat_material(), "Leaves"))
	return _finish(root)


## A round wooden tub of staves with two rope bands and dark soil on top,
## standing on the floor. Returns the soil height.
static func _add_tub(model: Node3D, radius: float, height: float) -> float:
	var tub := MeshInstance3D.new()
	tub.name = "Tub"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.85
	cyl.height = height
	cyl.radial_segments = 12
	tub.mesh = cyl
	tub.material_override = MeshUtil.color_material(Treehouse.WOOD)
	tub.position.y = height / 2.0
	model.add_child(tub)
	for y in [0.25, 0.75]:
		var band := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var r := lerpf(radius * 0.85, radius, y)
		torus.inner_radius = r - 0.01
		torus.outer_radius = r + 0.03
		band.mesh = torus
		band.material_override = MeshUtil.color_material(Treehouse.ROPE)
		band.position.y = height * y
		model.add_child(band)
	var soil := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.92
	disc.bottom_radius = radius * 0.92
	disc.height = 0.04
	soil.mesh = disc
	soil.material_override = MeshUtil.color_material(Treehouse.BARK_DARK)
	soil.position.y = height - 0.06
	model.add_child(soil)
	return height - 0.04


## Two posts and a sagging string of little cloth flags between them,
## along the footprint's long side.
static func bunting(size: Vector2i) -> Node3D:
	var root := Props._root()
	var model := root.get_node("Model") as Node3D
	var along_x := size.x >= size.y
	var half := (float(maxi(size.x, size.y)) * Grid.TILE) / 2.0 - 0.15
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var a := -axis * half
	var b := axis * half
	for end in [a, b]:
		var post := ModelLib.instance(T + "pillar-wood.glb")
		post.scale = Vector3(1.0, 2.4, 1.0)
		post.position = end
		model.add_child(post)
	var top := Vector3(0.0, 2.32, 0.0)
	var sag := 0.55
	var pts := PackedVector3Array()
	for i in 17:
		var t := i / 16.0
		pts.append(a.lerp(b, t) + top - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0))
	model.add_child(_tube(pts, 0.012, ROPE))
	var colours := [YELLOW, BLUE, WHITE, GREEN]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := axis.cross(Vector3.UP)
	for i in range(1, 16):
		var p := pts[i]
		var c: Color = colours[i % 4]
		var w := 0.13
		for v in [p - axis * w, p + axis * w, p - Vector3(0.0, 0.3, 0.0) + side * 0.01]:
			st.set_color(c)
			st.set_normal(side)
			st.add_vertex(v)
	var flags := MeshInstance3D.new()
	flags.name = "Flags"
	flags.mesh = st.commit()
	flags.material_override = MeshUtil.vertex_color_material()
	model.add_child(flags)
	return _finish(root)


# ---------------------------------------------------------------- village bits

## A wooden tub of flowers (tub built from simple shapes, Nature Kit
## flowers in it).
static func planter(flower: String, rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var soil := _add_tub(model, 0.5, 0.55)
	var bloom := ModelLib.fitted(NK + flower + ".glb", Vector2(0.9, 0.9), 1.0, 0.75)
	bloom.position.y = soil - 0.02
	model.add_child(bloom)
	var moss := SurfaceTool.new()
	moss.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(flower)
	Treehouse.add_leaf_blob(moss, Vector3(0.22, soil + 0.04, -0.15), Vector3(0.2, 0.08, 0.16), Treehouse.MOSS, rng)
	model.add_child(Treehouse.mesh(moss, Treehouse.flat_material(), "Moss"))
	return _finish(root)


## A little treehouse hut (log walls, round thatch roof, arched door on the
## front). You can go in: see the "interior" on its layout entry.
static func hut(straw_roof: bool, rot := 0.0) -> Node3D:
	return Treehouse.cabin(Vector2i(1, 1), 0.0, false, 17 + int(rot), Treehouse.STRAW if straw_roof else Treehouse.LEAF)


## A treehouse cabin on 2 x 2 tiles, built round a tree trunk that grows up
## through its leaf-thatch roof. Its door is on the front-left tile.
static func cabin(seed_value: int, straw_roof: bool) -> Node3D:
	return Treehouse.cabin(Vector2i(2, 2), -1.0, true, seed_value, Treehouse.STRAW if straw_roof else Treehouse.LEAF)


## The baker's stall, its counter laid with loaves, a pie and croissants.
static func bake_stall(rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, 0.0)
	var stall := ModelLib.fitted(T + "stall-green.glb", Props.FOOT_1, 0.9, 0.0, rot)
	model.add_child(stall)
	var top := _counter_height(stall, model)
	var goods := [["loaf.glb", Vector3(-0.35, 0.0, 0.25), 0.55, 20.0], ["pie.glb", Vector3(0.05, 0.0, 0.3), 0.45, 0.0],
			["croissant.glb", Vector3(0.4, 0.0, 0.22), 0.3, 60.0], ["loaf-round.glb", Vector3(0.2, 0.0, 0.0), 0.4, 0.0]]
	for g in goods:
		var item := ModelLib.fitted(FOOD + g[0], Vector2(g[2], g[2]), 1.0, 0.0, g[3])
		item.position = (Basis(Vector3.UP, deg_to_rad(rot)) * g[1]) + Vector3(0.0, top, 0.0)
		model.add_child(item)
	return _finish(root)


## Height of a stall's counter top: the highest flat part under the awning,
## estimated as 40% of the stall's height (Kenney stalls are built that way).
static func _counter_height(stall: Node3D, space: Node3D) -> float:
	return ModelUtil.aabb_in(stall, space).size.y * 0.4


## The baker's clay oven: a brick base and a warm dome, with a stubby
## chimney. Built from simple shapes.
static func oven() -> Node3D:
	var root := Props._root()
	var model := _frame(root, 0.0)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.6, 1.4)
	base.mesh = box
	base.material_override = MeshUtil.color_material(Color(0.66, 0.42, 0.33))
	base.position.y = 0.3
	model.add_child(base)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 0.62
	sphere.is_hemisphere = true
	dome.mesh = sphere
	dome.material_override = MeshUtil.color_material(Color(0.86, 0.66, 0.48))
	dome.position.y = 0.6
	model.add_child(dome)
	var mouth := MeshInstance3D.new()
	var hole := BoxMesh.new()
	hole.size = Vector3(0.4, 0.28, 0.05)
	mouth.mesh = hole
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.35, 0.16, 0.08)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.55, 0.25)
	glow.emission_energy_multiplier = 0.8
	mouth.material_override = glow
	mouth.position = Vector3(0.0, 0.76, 0.59)
	model.add_child(mouth)
	var chimney := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.12
	cyl.height = 0.5
	chimney.mesh = cyl
	chimney.material_override = MeshUtil.color_material(Color(0.66, 0.42, 0.33))
	chimney.position = Vector3(-0.2, 1.3, -0.2)
	model.add_child(chimney)
	return _finish(root)


## The rope-weaver's coils of rope, stacked on a low crate.
static func rope_coils(rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var crate := ModelLib.fitted(S + "box-large.glb", Vector2(1.2, 1.2), 1.0, 0.55)
	model.add_child(crate)
	var top := ModelUtil.aabb_in(crate, model).end.y
	var mat := MeshUtil.color_material(ROPE)
	# [centre on the crate, outer radius, how many coils it sits on]
	for c in [[Vector2(-0.22, -0.1), 0.26, 0], [Vector2(0.26, 0.15), 0.22, 0], [Vector2(-0.22, -0.1), 0.2, 1]]:
		var r: float = c[1]
		var height := r * 0.55 * 2.2  # tube thickness, stretched up into a coil
		var coil := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r * 0.45
		torus.outer_radius = r
		coil.mesh = torus
		coil.material_override = mat
		coil.scale = Vector3(1.0, 2.2, 1.0)
		var base := top + (0.26 * 0.55 * 2.2 if c[2] == 1 else 0.0)
		coil.position = Vector3(c[0].x, base + height / 2.0, c[0].y)
		model.add_child(coil)
	return _finish(root)


## The weather-watcher's vane: a pole with an arrow that hasn't moved in
## weeks, and a windsock hanging straight down.
static func weathervane() -> Node3D:
	var root := Props._root()
	var model := root.get_node("Model") as Node3D
	var pole := ModelLib.instance(T + "pillar-wood.glb")
	pole.scale = Vector3(1.0, 3.0, 1.0)
	model.add_child(pole)
	var arrow := Props._scaled(P + "arrow.glb", Vector3.ONE * 0.9, 0.0)
	arrow.position.y = 3.0
	model.add_child(arrow)
	model.add_child(Props._rod(Vector3(0.0, 2.4, 0.0), Vector3(0.55, 2.4, 0.0), 0.02, WOOD))
	var sock := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.05
	cone.height = 0.7
	sock.mesh = cone
	sock.material_override = MeshUtil.color_material(Color(0.95, 0.6, 0.45))
	sock.position = Vector3(0.55, 2.4 - 0.35, 0.0)
	model.add_child(sock)
	return _finish(root)


## The weather-watcher's brass telescope on a wooden tripod, tilted up at
## the sky through the window.
static func telescope(rot := 0.0) -> Node3D:
	var root := Props._root()
	var model := _frame(root, rot)
	var head := Vector3(0.0, 1.05, 0.0)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		# Feet start a little up so the rods' round ends rest on the floor.
		model.add_child(Props._rod(Vector3(cos(a) * 0.38, 0.03, sin(a) * 0.38), head, 0.025, WOOD))
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.8, 0.64, 0.32)
	brass.metallic = 0.7
	brass.roughness = 0.35
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.08
	cyl.height = 0.95
	tube.mesh = cyl
	tube.material_override = brass
	tube.position = head + Vector3(0.0, 0.18, -0.12)
	tube.rotation_degrees.x = -60.0  # pointing up and out of the window (-z)
	model.add_child(tube)
	# Stand it exactly on the floor (the tilted rods' ends dip a little).
	model.position.y -= ModelUtil.aabb_in(model, root).position.y
	return _finish(root)


# ---------------------------------------------------------------- the far cliff

## The far cliff on Leafwind's north edge, where the wind used to come
## from: a craggy, faceted spire in the island's own blue-grey stone (same
## stone texture as the island's underside), with grassy ledges and two
## smaller crags beside it. On top, the tangled knot of wind. Decoration only.
static func wind_cliff(size: Vector2i) -> Node3D:
	var root := Props._root()
	var model := root.get_node("Model") as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# [centre, base radii (x, z), profile: [height, radius share, grass ledge on top?]]
	var main_top := 9.4
	var spires := [
		[Vector3(-0.7, 0.0, -0.1), Vector2(2.75, 2.3), [[0.0, 1.0, false], [1.4, 0.97, false], [2.9, 0.88, true], [2.9, 0.72, false],
				[4.6, 0.64, false], [6.1, 0.56, true], [6.1, 0.45, false], [7.9, 0.37, false], [main_top, 0.3, false]]],
		[Vector3(3.15, 0.0, 0.55), Vector2(1.35, 1.25), [[0.0, 1.0, false], [1.8, 0.9, false], [3.2, 0.78, true], [3.2, 0.6, false], [4.7, 0.48, false]]],
		[Vector3(-3.95, 0.0, 1.35), Vector2(0.8, 0.8), [[0.0, 1.0, false], [1.4, 0.82, false], [2.6, 0.62, false]]],
	]
	var main_cap := Vector3.ZERO
	var ledges: Array[Vector3] = []
	for s in spires:
		var cap := _add_spire(st, rng, s[0], s[1], s[2], ledges)
		if main_cap == Vector3.ZERO:
			main_cap = cap
	var mi := MeshInstance3D.new()
	mi.name = "Crag"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/island_ground.gdshader")
	mat.set_shader_parameter("detail_tex", ModelLib.stone_texture())
	mi.material_override = mat
	model.add_child(mi)
	# Grass tufts and a flower or two on the ledges.
	var tufts := [P + "grass.glb", NK + "flower_yellowA.glb", P + "grass.glb", NK + "flower_purpleA.glb", P + "grass.glb"]
	for i in ledges.size():
		var tuft := ModelLib.fitted(tufts[i % tufts.size()], Vector2(0.5, 0.5), 1.0, 0.45, 40.0 * i)
		tuft.position = ledges[i]
		model.add_child(tuft)
	var knot := wind_knot()
	knot.position = main_cap + Vector3(0.0, 1.9, 0.0)
	model.add_child(knot)
	Props._collider_from_model(root)
	return root


## One faceted rock column (low-poly, like the rest of the art): rings of
## jittered points shrinking upwards, with flat grassy ledges where it steps
## in and a grassy cap on top. Adds its triangles to `st`, adds a point on
## each ledge to `ledges`, and returns the middle of its cap.
static func _add_spire(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, radii: Vector2, profile: Array, ledges: Array[Vector3]) -> Vector3:
	var sides := 9
	var rock := Color(0.6, 0.6, 0.76)
	var grass := Color(0.49, 0.72, 0.36)
	var rings: Array[PackedVector3Array] = []
	var lean := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.04, 0.04))
	for i in profile.size():
		var y: float = profile[i][0]
		var share: float = profile[i][1]
		var ring := PackedVector3Array()
		var twist := rng.randf_range(-0.12, 0.12)
		for k in sides:
			var a := TAU * k / sides + twist
			var jitter := 1.0 + rng.randf_range(-0.12, 0.1)
			if i == 0:
				jitter = minf(jitter, 1.0)  # the base never pokes out past its radius
			var p := Vector3(cos(a) * radii.x, 0.0, sin(a) * radii.y) * share * jitter
			ring.append(centre + lean * y + p + Vector3(0.0, y, 0.0))
		rings.append(ring)
	for i in profile.size() - 1:
		var flat: bool = is_equal_approx(profile[i][0], profile[i + 1][0])
		var mid_ring := centre + lean * float(profile[i][0]) + Vector3(0.0, profile[i][0], 0.0)
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k2]
			var d: Vector3 = rings[i + 1][k]
			var shade := rng.randf_range(0.0, 0.16) + (0.1 if i == 0 else 0.0)
			var col := grass.darkened(rng.randf_range(0.0, 0.08)) if flat else rock.darkened(shade)
			_flat_tri(st, a, b, c, col, mid_ring)
			_flat_tri(st, a, c, d, col, mid_ring)
		if flat and profile[i][2]:
			var k := rng.randi_range(0, sides - 1)
			ledges.append((rings[i][k] + rings[i + 1][k]) / 2.0)
	# Grassy cap: a low dome over the top ring.
	var top := rings[rings.size() - 1]
	var cap := Vector3.ZERO
	for p in top:
		cap += p
	cap /= top.size()
	var peak := cap + Vector3(0.0, 0.25, 0.0)
	for k in sides:
		_flat_tri(st, top[k], top[(k + 1) % sides], peak, grass.darkened(rng.randf_range(0.0, 0.1)), cap - Vector3(0.0, 1.0, 0.0))
	return peak


## A flat-shaded triangle whose normal points away from `inside`.
static func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


## The knot of wind: soft ribbons of air looped round and through each
## other into a tangled ball, with wisps spiralling in from outside and a
## few leaves caught inside. Every strand churns slowly about its own axis
## (scripts/wind_knot.gd), and bands of air flow along the ribbons
## (shaders/wind_ribbon.gdshader): wind, tied up and going nowhere.
const KNOT_RADIUS := 1.45


static func wind_knot() -> Node3D:
	var knot := Node3D.new()
	knot.name = "WindKnot"
	knot.set_script(preload("res://scripts/wind_knot.gd"))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/wind_ribbon.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var r := KNOT_RADIUS
	# Closed loops: torus knots and wobbly rings, each tilted differently.
	var loops := [[2, 3, 0.95], [3, 2, 0.8], [2, 5, 0.72], [1, 0, 1.0], [1, 0, 0.88], [3, 4, 0.6]]
	for i in loops.size():
		var p: int = loops[i][0]
		var q: int = loops[i][1]
		var size: float = loops[i][2]
		var pts := PackedVector3Array()
		for j in 121:
			var t := TAU * j / 120.0
			var v: Vector3
			if q == 0:
				v = Vector3(cos(t), 0.18 * sin(3.0 * t + i), sin(t))  # a wobbly ring
			else:
				var rr := 2.0 + cos(q * t)
				v = Vector3(rr * cos(p * t), sin(q * t), rr * sin(p * t)) / 3.0
			pts.append(v * r * size)
		var strand := _ribbon(pts, 0.32 - 0.03 * i, false, mat)
		strand.name = "Strand%d" % i
		strand.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		strand.set_meta("spin_axis", Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)).normalized())
		strand.set_meta("spin", rng.randf_range(5.0, 11.0) * (1.0 if i % 2 == 0 else -1.0))
		knot.add_child(strand)
	# Wisps spiralling in from outside, caught by the knot.
	for i in 4:
		var pts := PackedVector3Array()
		var start := rng.randf_range(0.0, TAU)
		var tilt := rng.randf_range(-0.5, 0.5)
		for j in 41:
			var t := j / 40.0
			var a := start + t * 5.0
			var rad := r * lerpf(1.0, 0.35, t)
			pts.append(Vector3(cos(a) * rad, tilt * rad + (t - 0.5) * 0.4, sin(a) * rad))
		var wisp := _ribbon(pts, 0.2, true, mat)
		wisp.name = "Wisp%d" % i
		wisp.set_meta("spin_axis", Vector3.UP)
		wisp.set_meta("spin", rng.randf_range(8.0, 14.0))
		knot.add_child(wisp)
	# Leaves caught in the tangle.
	var leaves := Node3D.new()
	leaves.name = "CaughtLeaves"
	leaves.set_meta("spin_axis", Vector3(0.3, 1.0, -0.2).normalized())
	leaves.set_meta("spin", -6.0)
	var leaf_mat := MeshUtil.color_material(GREEN)
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 7:
		var leaf := MeshInstance3D.new()
		var quad := PrismMesh.new()
		quad.size = Vector3(0.16, 0.24, 0.01)
		leaf.mesh = quad
		leaf.material_override = leaf_mat
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)).normalized()
		leaf.position = dir * r * rng.randf_range(0.4, 0.85)
		leaf.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		leaves.add_child(leaf)
	knot.add_child(leaves)
	# A faint cool glow in the middle.
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(0.75, 0.88, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = 4.0
	knot.add_child(glow)
	return knot


## A flat ribbon along a line of points, turned to face outwards from the
## knot's middle. UV.x = distance along (m), UV.y = across (0..1); vertex
## alpha fades the ends of open ribbons.
static func _ribbon(pts: PackedVector3Array, width: float, open: bool, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lefts := PackedVector3Array()
	var rights := PackedVector3Array()
	var dist := PackedFloat32Array()
	var along := 0.0
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var tangent := (next - prev).normalized()
		var out := pts[i].normalized() if pts[i].length() > 0.01 else Vector3.UP
		var side := tangent.cross(out).normalized()
		var t := float(i) / float(pts.size() - 1)
		var w := width * (sin(PI * t) if open else 1.0)
		lefts.append(pts[i] - side * w / 2.0)
		rights.append(pts[i] + side * w / 2.0)
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		dist.append(along)
	for i in pts.size() - 1:
		var t0 := float(i) / float(pts.size() - 1)
		var t1 := float(i + 1) / float(pts.size() - 1)
		var a0 := sin(PI * t0) if open else 1.0
		var a1 := sin(PI * t1) if open else 1.0
		var quad := [[lefts[i], dist[i], 0.0, a0], [rights[i], dist[i], 1.0, a0], [rights[i + 1], dist[i + 1], 1.0, a1],
				[lefts[i], dist[i], 0.0, a0], [rights[i + 1], dist[i + 1], 1.0, a1], [lefts[i + 1], dist[i + 1], 0.0, a1]]
		for v in quad:
			st.set_color(Color(1, 1, 1, v[3]))
			st.set_uv(Vector2(v[1], v[2]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- helpers

## A wall of a one-module building: every corner is an outer corner.
static func _one_module_wall(path: String, k: float, centre: Vector3, rot: float) -> Node3D:
	return Props.wall_piece(path, k, centre, rot, Vector2i.ZERO, func(m: Vector2i) -> bool: return m == Vector2i.ZERO)


## A child of root's Model, turned by `rot` degrees.
static func _frame(root: Node3D, rot: float) -> Node3D:
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.rotation_degrees.y = rot
	(root.get_node("Model") as Node3D).add_child(frame)
	return frame


## Collider from the model's bounds, as for every other prop.
static func _finish(root: Node3D) -> Node3D:
	Props._collider_from_model(root)
	return root


## A round tube along a line of points (ropes, strands of wind).
static func _tube(pts: PackedVector3Array, radius: float, colour: Color, mat: Material = null, sides := 6) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var ref := Vector3.UP
	for i in pts.size():
		var tangent := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(tangent.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var u := tangent.cross(ref).normalized()
		var v := tangent.cross(u).normalized()
		var ring := PackedVector3Array()
		var ns := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			var n := u * cos(a) + v * sin(a)
			ring.append(pts[i] + n * radius)
			ns.append(n)
		rings.append(ring)
		normals.append(ns)
	for i in pts.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			for idx in [[i, k], [i + 1, k], [i + 1, k2], [i, k], [i + 1, k2], [i, k2]]:
				st.set_color(colour)
				st.set_normal(normals[idx[0]][idx[1]])
				st.add_vertex(rings[idx[0]][idx[1]])
	var mi := MeshInstance3D.new()
	mi.name = "Tube"
	mi.mesh = st.commit()
	if mat:
		mi.material_override = mat
	else:
		var m := MeshUtil.vertex_color_material()
		mi.material_override = m
	return mi
