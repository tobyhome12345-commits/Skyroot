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
			return simple(T + "stall-green.glb", 0.9, 0.0, p.get("rot", 0.0))
		"launch":
			return launch_point(p["dir"])
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
	return root


## A piece that runs along one edge of its tile (fence, hedge).
## Kenney edge pieces lie on the +x edge; rotate to the wanted side.
static func edge_piece(path: String, side: String) -> Node3D:
	var root := _root()
	var rot := {"east": 0.0, "north": 90.0, "west": 180.0, "south": -90.0}[side] as float
	var piece := ModelLib.piece(path, ModelLib.TOWN_SCALE, Vector3.ZERO, rot)
	(root.get_node("Model") as Node3D).add_child(piece)
	_collider_from_model(root)
	return root


## One model fitted to a single tile. `fill` = share of the tile it may use,
## `max_height` caps its height (0 = no cap).
static func simple(path: String, fill: float, max_height: float, rot_y := 0.0) -> Node3D:
	var root := _root()
	var fitted := ModelLib.fitted(path, FOOT_1, fill, max_height, rot_y)
	(root.get_node("Model") as Node3D).add_child(fitted)
	_collider_from_model(root)
	return root


## Launch point: the Platformer Kit wooden pallet ramp, filling its edge
## tile, high end pointing out over the edge (`dir`, towards the sky).
## The model rises towards its -z; its top end is about 1.1 m high.
static func launch_point(dir: Vector2i) -> Node3D:
	var rot := {Vector2i(0, -1): 0.0, Vector2i(-1, 0): 90.0, Vector2i(0, 1): 180.0, Vector2i(1, 0): -90.0}[dir] as float
	return simple(P + "platform-ramp.glb", 0.975, 0.0, rot)


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
