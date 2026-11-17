class_name Props
## Island props built from Kenney models (see Assets/CREDITS.md).
## Every builder returns a Node3D whose origin is the centre of its tile
## footprint on the ground (y = 0). Children:
##   Model - the visible models, fitted inside the footprint, flush on the ground
##   Body  - a StaticBody3D whose collision shape is made from the model's bounds
## Solid props block the player; flat ground details (solid = false) don't.

const T := ModelLib.TOWN
const P := ModelLib.PLATFORMER
const F := ModelLib.FOREST
const S := ModelLib.SURVIVAL
const FOOT_1 := Vector2(2.0, 2.0)  # one tile in metres
## Lit room shell inside each house (see _add_lit_interior).
const INTERIOR_HALF := 1.6
const INTERIOR_HEIGHT := 1.95


## Builds a prop from a layout entry (see island.gd).
static func build(p: Dictionary) -> Node3D:
	match p["type"]:
		"house":
			return house(p.get("red_roof", false), p.get("wood", false))
		"tree":
			return tree(p.get("kind", "pine"))
		"well":
			return well()
		"notice_board":
			return notice_board()
		"fence":
			return edge_piece(T + "fence.glb", p.get("side", "north"))
		"hedge":
			return edge_piece(T + "hedge-large.glb", p.get("side", "north"))
		"lantern":
			return simple(T + "lantern.glb", 0.4, 2.4)
		"rock":
			return simple(T + p.get("kind", "rock-small") + ".glb", 0.7, 1.1, p.get("rot", 0.0))
		"flowers":
			return simple(P + "flowers.glb", 0.7, 0.0, p.get("rot", 0.0))
		"flowers_tall":
			return simple(P + "flowers-tall.glb", 0.65, 0.0, p.get("rot", 0.0))
		"plant":
			return simple(F + "plant.glb", 0.6, 0.0, p.get("rot", 0.0))
		"grass":
			return simple(P + "grass.glb", 0.6, 0.0, p.get("rot", 0.0))
		"mushrooms":
			return simple(P + "mushrooms.glb", 0.5, 0.0, p.get("rot", 0.0))
		"barrel":
			return simple(S + "barrel.glb", 0.5, 0.9, p.get("rot", 0.0))
		"crate":
			return simple(S + "box.glb", 0.4, 0.0, p.get("rot", 0.0))
		"cart":
			return simple(T + "cart.glb", 0.85, 0.0, p.get("rot", 0.0))
		"stall":
			return simple(T + ("stall-red.glb" if p.get("red", false) else "stall-green.glb"), 0.9, 0.0, p.get("rot", 0.0))
		"bench":
			return simple(T + "stall-bench.glb", 0.85, 0.0, p.get("rot", 90.0))
		"seed_spot":
			return seed_spot()
		"launch":
			return launch_point(p["dir"])
		"launch_flag":
			return launch_flag(p["dir"])
		"nature":
			return nature(p)
	push_error("Unknown prop type: %s" % p["type"])
	return null


# ---------------------------------------------------------------- builders

## 2 x 2 tile house from Fantasy Town Kit modules (one module per tile).
## Door and a window face +z (towards the camera and the path).
static func house(red_roof: bool, wood: bool) -> Node3D:
	var root := _root()
	var model := root.get_node("Model") as Node3D
	var k := ModelLib.TOWN_SCALE
	var wall := "wall-wood" if wood else "wall"
	for mx in 2:
		for mz in 2:
			var c := Vector3((mx - 0.5) * k, 0.0, (mz - 0.5) * k)
			if mx == 1:
				model.add_child(ModelLib.piece(T + (wall + "-window-shutters" if mz == 0 else wall) + ".glb", k, c, 0.0))
			if mx == 0:
				model.add_child(ModelLib.piece(T + (wall + "-window-shutters" if mz == 1 else wall) + ".glb", k, c, 180.0))
			if mz == 0:
				model.add_child(ModelLib.piece(T + wall + ".glb", k, c, 90.0))
			if mz == 1:
				var front := wall + ("-door" if mx == 0 else "-window-shutters")
				model.add_child(ModelLib.piece(T + front + ".glb", k, c, -90.0))
		# Two roof slopes meet in the middle: a gable roof over 2 x 2 tiles.
	for mz in 2:
		var z := (mz - 0.5) * k
		var roof_l := ModelLib.piece(T + "roof.glb", k, Vector3(-0.5 * k, k, z), 0.0)
		var roof_r := ModelLib.piece(T + "roof.glb", k, Vector3(0.5 * k, k, z), 180.0)
		model.add_child(roof_l)
		model.add_child(roof_r)
		if red_roof:
			ModelLib.set_atlas(roof_l, ModelLib.red_roof_atlas())
			ModelLib.set_atlas(roof_r, ModelLib.red_roof_atlas())
	_add_lit_interior(model)
	# Walls stand exactly on the footprint edges: 4 x 4 m, 2 m tall.
	_box_collider(root, Vector3(2.0 * k, k, 2.0 * k), Vector3(0.0, k / 2.0, 0.0))
	return root


## The Town Kit walls have open windows and door frames, and the house is a
## hollow shell, so without this you'd see the grass inside. A warm, softly
## glowing room shell just inside the walls makes the windows look lit.
## It stays inside the window shutters (which reach 1.65 m from the centre)
## and under the roof, so it never pokes through or clips.
static func _add_lit_interior(model: Node3D) -> void:
	var shell := MeshInstance3D.new()
	shell.name = "LitInterior"
	var box := BoxMesh.new()
	box.size = Vector3(INTERIOR_HALF * 2.0, INTERIOR_HEIGHT, INTERIOR_HALF * 2.0)
	shell.mesh = box
	shell.position = Vector3(0.0, INTERIOR_HEIGHT / 2.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.22, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.4)
	mat.emission_energy_multiplier = 0.55
	mat.roughness = 1.0
	shell.material_override = mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(shell)


static func tree(kind: String) -> Node3D:
	var path: String
	match kind:
		"round":
			path = T + "tree-high-round.glb"
		"crooked":
			path = T + "tree-crooked.glb"
		"bushy":
			path = P + "tree.glb"
		_:
			path = T + "tree.glb"
	return simple(path, 0.85, 4.2)


## No pack has a well, so it is built from Fantasy Town Kit parts:
## a round stone basin (raised), two wooden posts, a little pointed roof,
## and a Survival Kit bucket beside it.
static func well() -> Node3D:
	var root := _root()
	var model := root.get_node("Model") as Node3D
	var ring := ModelLib.instance(T + "fountain-round.glb")  # 2 x 0.28 x 2
	ring.scale = Vector3(0.75, 2.8, 0.75)  # 1.5 m wide, 0.78 m tall
	model.add_child(ring)
	for x in [-0.6, 0.6]:
		var post := ModelLib.instance(T + "pillar-wood.glb")  # 0.16 x 1 x 0.16
		post.scale = Vector3(1.2, 1.9, 1.2)
		post.position = Vector3(x, 0.0, 0.0)
		model.add_child(post)
	var roof := ModelLib.instance(T + "roof-point.glb")  # 1.1 x 0.5 x 1.1
	roof.scale = Vector3.ONE * 1.4
	roof.position = Vector3(0.0, 1.9, 0.0)
	model.add_child(roof)
	var bucket := ModelLib.instance(S + "bucket.glb")  # 0.144 x 0.192
	bucket.scale = Vector3.ONE * 2.2
	bucket.position = Vector3(0.72, 0.0, 0.72)
	model.add_child(bucket)
	_collider_from_model(root)
	return root


## No pack has a notice board either: two wooden posts holding a plank board.
static func notice_board() -> Node3D:
	var root := _root()
	var model := root.get_node("Model") as Node3D
	for x in [-0.65, 0.65]:
		var post := ModelLib.instance(T + "pillar-wood.glb")
		post.scale = Vector3(1.2, 1.75, 1.2)
		post.position = Vector3(x, 0.0, 0.0)
		model.add_child(post)
	var board := ModelLib.instance(T + "planks.glb")  # 1 x 0.06 x 1, lying flat
	board.scale = Vector3(1.3, 1.5, 0.9)
	board.rotation_degrees.x = 90.0  # stand it up: 1.3 wide, 0.9 tall, 0.09 thick
	board.position = Vector3(0.0, 1.25, 0.0)
	model.add_child(board)
	var top := ModelLib.instance(T + "roof-flat.glb")
	top.scale = Vector3(1.5, 0.6, 0.35)
	top.position = Vector3(0.0, 1.75, 0.0)
	model.add_child(top)
	_collider_from_model(root)
	root.add_child(_promise_carving())
	return root


## The Old Promise carved into the board's front: the four islands, each
## with its gift. Shallow shapes and burnt-in words, flush on the planks.
static func _promise_carving() -> Node3D:
	var carving := Node3D.new()
	carving.name = "Carving"
	# The board's front face: the plank model stands up from z = 0 to its
	# thickness (0.06 x 1.5), so the carving sits just in front of that.
	var front := 0.06 * 1.5 + 0.004
	var ink := Color(0.32, 0.2, 0.12)
	var mat := MeshUtil.color_material(Color(0.42, 0.27, 0.16))
	var gifts := [["Rootholm", "water"], ["Barkton", "strength"], ["Leafwind", "breath"], ["Seedhaven", "new life"]]
	for i in 4:
		var x := -0.45 + 0.3 * i
		# The island: a small raised disc.
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.09
		cyl.height = 0.012
		disc.mesh = cyl
		disc.material_override = mat
		disc.rotation_degrees.x = 90.0
		disc.position = Vector3(x, 1.36, front + 0.006)
		carving.add_child(disc)
		for t in [[gifts[i][0], 1.22, 0.00075], [gifts[i][1], 1.16, 0.00065]]:
			var label := Label3D.new()
			label.text = t[0]
			label.font_size = 64
			label.pixel_size = t[2]
			label.modulate = ink
			label.outline_size = 0
			label.double_sided = false
			label.position = Vector3(x, t[1], front + 0.003)
			carving.add_child(label)
	var title := Label3D.new()
	title.text = "The Old Promise"
	title.font_size = 64
	title.pixel_size = 0.0013
	title.modulate = ink
	title.outline_size = 0
	title.position = Vector3(0.0, 1.55, front + 0.003)
	carving.add_child(title)
	return carving


## A faintly glowing seed resting in a little mound of soft, dark earth.
## The mound is a low dome standing on the grass; the seed nestles into its
## top. The seed can't be picked up (yet).
static func seed_spot() -> Node3D:
	var root := _root()
	var model := root.get_node("Model") as Node3D
	var mound := MeshInstance3D.new()
	mound.name = "SoftEarth"
	var dome := SphereMesh.new()
	dome.radius = SEED_MOUND_RADIUS
	dome.height = SEED_MOUND_HEIGHT
	dome.is_hemisphere = true
	dome.radial_segments = 20
	dome.rings = 6
	mound.mesh = dome
	mound.material_override = MeshUtil.color_material(Color(0.36, 0.25, 0.18), 1.0)
	model.add_child(mound)
	# Stand the dome on the grass, wherever its mesh starts.
	var box := dome.get_aabb()
	mound.position.y = -box.position.y
	var top := box.end.y - box.position.y
	var seed := Seed.new()
	# Seed body: 0.2 tall, centred on its origin; it sinks 3 cm into the earth.
	seed.position = Vector3(0.0, top + 0.1 - 0.03, 0.0)
	model.add_child(seed)
	seed.glow_now(0.55)
	_collider_from_model(root)
	return root


const SEED_MOUND_RADIUS := 0.62
const SEED_MOUND_HEIGHT := 0.22


## A piece that runs along one edge of its tile (fence, hedge).
## Kenney edge pieces lie on the +x edge; rotate to the wanted side.
static func edge_piece(path: String, side: String) -> Node3D:
	var root := _root()
	var rot := {"east": 0.0, "north": 90.0, "west": 180.0, "south": -90.0}[side] as float
	var piece := ModelLib.piece(path, ModelLib.TOWN_SCALE, Vector3.ZERO, rot)
	(root.get_node("Model") as Node3D).add_child(piece)
	_collider_from_model(root)
	return root


## A natural piece (rock, log, bush, grass...) fitted to its footprint.
## Solid ones get a collider; walk-through ones (grass, flowers, ground
## patches) get none and are marked "walkable".
static func nature(p: Dictionary) -> Node3D:
	var root := _root()
	var size: Vector2i = p.get("size", Vector2i.ONE)
	var foot := Vector2(size) * Grid.TILE
	var fitted := ModelLib.fitted(p["model"], foot, p.get("fill", 0.7), p.get("max_height", 0.0), p.get("rot", 0.0))
	(root.get_node("Model") as Node3D).add_child(fitted)
	if p.get("tree_wood", false):
		TreeLook.apply_to(fitted)  # fallen wood matches the Great Tree's bark
	if p.get("solid", true):
		_collider_from_model(root)
	else:
		root.set_meta("solid", false)
		root.set_meta("walkable", true)
	return root


## One model fitted to a single tile. `fill` = share of the tile it may use,
## `max_height` caps its height (0 = no cap).
static func simple(path: String, fill: float, max_height: float, rot_y := 0.0) -> Node3D:
	var root := _root()
	var fitted := ModelLib.fitted(path, FOOT_1, fill, max_height, rot_y)
	(root.get_node("Model") as Node3D).add_child(fitted)
	_collider_from_model(root)
	return root


## Launch point, on an edge tile. Built in a frame where -z points out to
## the sky (`dir`), then turned to face it:
##  - a gentle wooden ramp (Platformer Kit pallet ramp) rising to the edge
##  - a plank lip (Fantasy Town Kit planks) that overhangs the edge by
##    LAUNCH_OVERHANG metres, held up by two wooden braces (simple shapes)
##  - rope rails along both sides (Platformer Kit rope fence)
static func launch_point(dir: Vector2i) -> Node3D:
	var root := _root()
	var frame := _launch_frame(root, dir)
	# Ramp: high end flush with the tile's sky edge.
	var ramp := _scaled(P + "platform-ramp.glb", Vector3.ONE * LAUNCH_RAMP_SCALE, 0.0)
	var ramp_size: Vector3 = ramp.get_meta("size")
	ramp.position = Vector3(0.0, 0.0, -1.0 + ramp_size.z / 2.0)
	frame.add_child(ramp)
	# Lip: planks continuing the ramp's top out over the edge.
	var lip := _scaled(T + "planks.glb", Vector3(ramp_size.x / 1.0, 1.5, LAUNCH_OVERHANG), 0.0)
	var lip_size: Vector3 = lip.get_meta("size")
	lip.position = Vector3(0.0, ramp_size.y - lip_size.y, -1.0 - LAUNCH_OVERHANG / 2.0)
	frame.add_child(lip)
	# Two braces from the grass at the edge up under the end of the lip.
	for x in [-0.4, 0.4]:
		frame.add_child(_rod(Vector3(x, 0.06, -0.97), Vector3(x, ramp_size.y - lip_size.y - 0.03, -1.0 - LAUNCH_OVERHANG + 0.12), 0.05, LAUNCH_WOOD))
	# Rope rails along both sides of the ramp.
	for side in [-1.0, 1.0]:
		var rail := _scaled(P + "fence-rope.glb", Vector3(ramp_size.z / 0.95, 3.0, 1.6), 90.0)
		var rail_size: Vector3 = rail.get_meta("size")
		rail.position = Vector3(side * (ramp_size.x / 2.0 + 0.03 + rail_size.x / 2.0), 0.0, ramp.position.z)
		frame.add_child(rail)
	_collider_from_model(root)
	return root


## Flag and signpost on the tile beside the launch point: Platformer Kit
## flag at the back, Survival Kit signpost pointing out to the sky.
static func launch_flag(dir: Vector2i) -> Node3D:
	var root := _root()
	var frame := _launch_frame(root, dir)
	var flag := _scaled(P + "flag.glb", Vector3.ONE * 2.6, 90.0)  # cloth flies out to the sky
	flag.position = Vector3(0.25, 0.0, -0.45)
	frame.add_child(flag)
	var sign := _scaled(S + "signpost-single.glb", Vector3.ONE * 3.0, -90.0)
	sign.position = Vector3(-0.45, 0.0, 0.45)
	frame.add_child(sign)
	_collider_from_model(root)
	return root


const LAUNCH_RAMP_SCALE := 1.2
## How far (m) the launch lip sticks out past the island's edge.
const LAUNCH_OVERHANG := 0.9
const LAUNCH_WOOD := Color(0.62, 0.38, 0.24)


## A child of root's Model, turned so its -z points along `dir`.
static func _launch_frame(root: Node3D, dir: Vector2i) -> Node3D:
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.rotation_degrees.y = {Vector2i(0, -1): 0.0, Vector2i(-1, 0): 90.0, Vector2i(0, 1): 180.0, Vector2i(1, 0): -90.0}[dir] as float
	(root.get_node("Model") as Node3D).add_child(frame)
	return frame


## A model at a (possibly non-uniform) scale, turned, centred on its holder
## in x/z with its lowest point at y = 0. The holder's meta "size" is its size.
static func _scaled(path: String, scale: Vector3, rot_y: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	var model := ModelLib.instance(path)
	model.scale = scale
	holder.add_child(model)
	holder.rotation_degrees.y = rot_y
	var box := ModelUtil.aabb_in(model, holder)
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	var turned := Basis(Vector3.UP, deg_to_rad(rot_y)) * box.size
	holder.set_meta("size", turned.abs())
	return holder


## A thin wooden rod between two points (simple shape).
static func _rod(from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Brace"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = from.distance_to(to)
	cyl.radial_segments = 8
	mi.mesh = cyl
	mi.material_override = MeshUtil.color_material(color)
	var up := (to - from).normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (from + to) / 2.0)
	return mi


# ---------------------------------------------------------------- helpers

static func _root() -> Node3D:
	var root := Node3D.new()
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	return root


## Box collider that matches the model's bounding box. Very flat details
## (under 15 cm) get no collider: you walk over them like grass.
static func _collider_from_model(root: Node3D) -> void:
	var box := ModelUtil.aabb_in(root.get_node("Model"), root)
	if box.size.y < 0.15:
		root.set_meta("solid", false)
		return
	_box_collider(root, box.size, box.get_center())


static func _box_collider(root: Node3D, size: Vector3, centre: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = centre
	root.get_node("Body").add_child(cs)
	root.set_meta("solid", true)
