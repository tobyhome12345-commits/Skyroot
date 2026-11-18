extends "res://scripts/island.gd"
## Leafwind: a breezy canopy village in the treetops, stuck in a dead calm.
## Windmills stand frozen, kites hang limp, banners and chimes droop.
## 28 x 28 tiles on two levels: the grass (level 0) and wooden / leaf decks
## one tile up (level 1), joined by two-tile wooden stairs, with rope
## bridges across the sky gaps between the island's pads.
##
## Map: '#' plank deck, '=' walkway, '.' sky (level 0 unless said); the
##      plaza is woven leaf, the lookout branch is bark, a few tiles moss
##      (see _floor_kind)
##      '^' wooden deck (level 1)    '%' big leaf deck (level 1)
##      'n' 's' 'e' 'w' stairs, rising towards north / south / east / west;
##                      always two tiles: grass at the low end, deck at the top
##      'b' rope bridge (level 0)    'B' rope bridge (level 1)

const LEAFWIND_MAP: Array[String] = [
	"..####.....#######....#####.",
	".######...#########..#######",
	"#####s##..#########..#######",
	"#####s##bb====#####..#######",
	"##^^^^^#..###======bb#######",
	"##^^^^^#..###=#####..#######",
	"##^^^^^#..###=#####..#######",
	".#^^^^^...###=#####..######.",
	"....B.....###=#####.....b...",
	"....B.....###=#####.....b...",
	".^^^^^^######=##########=##.",
	"#^^^^^^######=##########=###",
	"#^^^^^^######=###========###",
	"#^^^^^^ww=###=###=##%%%%%%##",
	"#^^^^^^##=###=###=##%%%%%%##",
	"#^^^^^^##=========##%%%%%%##",
	"###n######========ee%%%%%%##",
	"###n######=======###%%%%%%##",
	"###===========##############",
	"#############=##############",
	"#############=##############",
	"#############=##############",
	"#############========#######",
	"#############=##############",
	"#############=##############",
	".############=#############.",
	"..########################..",
	"....####################....",
]

const RISE := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
const DIRS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
## Wooden plank floor thickness on the decks (Town Kit planks at scale 2).
const PLANK_T := 0.12
## Leaf deck slab thickness.
const LEAF_T := 0.25
## Invisible guards along deck edges and stair sides: height above the
## floor and thickness (they sit inside the tile, on its edge).
const GUARD_HEIGHT := 1.6
const GUARD_T := 0.2
const BRIDGE_T := 0.3
const STAIR_T := 0.25
const NK := "res://Assets/Nature Kit/Models/GLTF format/"
const DECK_WOOD := Treehouse.WOOD_DARK
const STILT_WOOD := Treehouse.BARK
const LEAF_GREEN := Color(0.58, 0.68, 0.47)
const LEAF_VEIN := Color(0.84, 0.84, 0.66)

var _body: StaticBody3D
var _vine_st: SurfaceTool
var _rng := RandomNumberGenerator.new()


func _map() -> Array[String]:
	return LEAFWIND_MAP


## Launch point on the south edge, pointing south; flag beside it.
func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(13, 27), "dir": Vector2i(0, 1), "flag": Vector2i(14, 27)}


# ---------------------------------------------------------------- tile kinds

func _char(cell: Vector2i) -> String:
	return map[cell.y][cell.x] if is_ground(cell) else "."


func is_bridge(cell: Vector2i) -> bool:
	return _char(cell) in ["b", "B"]


func is_deck(cell: Vector2i) -> bool:
	return _char(cell) in ["^", "%"]


func is_stairs(cell: Vector2i) -> bool:
	return RISE.has(_char(cell))


## Which way a stairs tile rises (zero for other tiles).
func rise_dir(cell: Vector2i) -> Vector2i:
	return RISE.get(_char(cell), Vector2i.ZERO)


## The bottom tile of a two-tile stairs run.
func is_stairs_low(cell: Vector2i) -> bool:
	return is_stairs(cell) and _char(cell - rise_dir(cell)) != _char(cell)


func is_stairs_high(cell: Vector2i) -> bool:
	return is_stairs(cell) and _char(cell + rise_dir(cell)) != _char(cell)


## The way a bridge runs: along x or along z.
func bridge_axis(cell: Vector2i) -> Vector2i:
	if is_bridge(cell + Vector2i(1, 0)) or is_bridge(cell - Vector2i(1, 0)):
		return Vector2i(1, 0)
	return Vector2i(0, 1)


func is_land(cell: Vector2i) -> bool:
	return is_ground(cell) and not is_bridge(cell)


func cell_level(cell: Vector2i) -> int:
	return 1 if is_deck(cell) or _char(cell) == "B" else 0


func is_walkway(cell: Vector2i) -> bool:
	return is_path(cell) or is_stairs(cell) or is_bridge(cell)


## Tiles you can step to from `cell` by walking (ignoring props): same-level
## neighbours, along a bridge only lengthways, and onto stairs only at their
## bottom (from the grass) or top (from the deck).
func walk_links(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_ground(cell):
		return out
	if is_stairs(cell):
		out.append(cell - rise_dir(cell))
		out.append(cell + rise_dir(cell))
		return out
	for d in DIRS:
		var n := cell + d
		if not is_ground(n):
			continue
		if is_bridge(cell) and _along(d, bridge_axis(cell)) == 0:
			continue
		if is_stairs(n):
			var r := rise_dir(n)
			if (d == r and is_stairs_low(n) and cell_level(cell) == 0) or (d == -r and is_stairs_high(n) and cell_level(cell) == 1):
				out.append(n)
			continue
		if is_bridge(n) and _along(d, bridge_axis(n)) == 0:
			continue
		if cell_level(n) == cell_level(cell):
			out.append(n)
	return out


func _along(d: Vector2i, axis: Vector2i) -> int:
	return d.x * axis.x + d.y * axis.y


# ---------------------------------------------------------------- structures

## Decks, stairs, bridges and the rails along drops are built before the
## props, so props stand on them.
func _reserve_extra() -> void:
	var root := Node3D.new()
	root.name = "Structures"
	add_child(root)
	_body = StaticBody3D.new()
	_body.name = "StructureBody"
	root.add_child(_body)
	# Shared meshes, so hundreds of planks, posts and ropes stay cheap:
	# bark-shaded woodwork (frames, stilts, posts, ropes) and deck vines.
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	_vine_st = SurfaceTool.new()
	_vine_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rng.seed = 5150
	_build_decks(root, wood)
	_build_leaf_decks(root, wood)
	_build_stairs(root, wood)
	_build_bridges(root, wood)
	_build_rails(root, wood)
	var floors := Node3D.new()
	floors.name = "DeckFloors"
	root.add_child(floors)
	_commit_floors(floors)
	root.add_child(Treehouse.mesh(wood, Treehouse.bark_material(), "Woodwork"))
	root.add_child(Treehouse.mesh(_vine_st, Treehouse.flat_material(), "DeckVines"))


## A collision box in the structure body, tagged with what it is and where.
func _shape(size: Vector3, pos: Vector3, kind: String, cell: Vector2i, basis := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(basis, pos)
	cs.name = "%s_%d_%d_%d" % [kind, cell.x, cell.y, _body.get_child_count()]
	cs.set_meta("kind", kind)
	cs.set_meta("cell", cell)
	_body.add_child(cs)


## Wooden decks: plank floor on top (top at level 1), a frame of boards
## round the edge, bark log stilts at the corners, and vines hanging off.
## Each deck tile is solid from the grass up to its top.
func _build_decks(root: Node3D, wood: SurfaceTool) -> void:
	var top := LEVEL_HEIGHT
	for cell in ground_cells():
		if not is_deck(cell):
			continue
		var c := Grid.cell_center(cell, map_size)
		_shape(Vector3(Grid.TILE, top, Grid.TILE), c + Vector3(0.0, top / 2.0, 0.0), "deck", cell)
		if _char(cell) != "^":
			continue
		_floor_quad("deck", cell, top)
		_deck_edges(root, wood, cell, top - 0.004, DECK_WOOD)


## Boards along a deck tile's open edges, stilts on its outer corners, and
## a little hanging moss.
func _deck_edges(root: Node3D, wood: SurfaceTool, cell: Vector2i, under: float, colour: Color) -> void:
	var c := Grid.cell_center(cell, map_size)
	var h := Grid.TILE / 2.0
	for d in DIRS:
		if is_deck(cell + d):
			continue
		var e := Vector3(d.x, 0.0, d.y)
		var along := Vector3(absf(e.z), 0.0, absf(e.x))
		var centre := c + e * (h - 0.06)
		var half := along * h + e.abs() * 0.06
		MeshUtil.add_box(wood, centre - half + Vector3(0.0, under - 0.4, 0.0), centre + half + Vector3(0.0, under, 0.0), colour, colour.darkened(0.15))
		if _cell_noise(cell, d.x * 3 + d.y + 10) < 0.45:
			var shift := (_cell_noise(cell, 20 + d.x + 2 * d.y) - 0.5) * 1.2
			_add_vine(_vine_st, centre - e * 0.1 + along * shift + Vector3(0.0, under - 0.4, 0.0), _rng.randf_range(0.6, 1.2), e, _rng)
	# Stilts on corners where two open edges meet (the deck's outer corners)
	# and every other tile along its edges.
	for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var open_x := not is_deck(cell + Vector2i(corner.x, 0))
		var open_z := not is_deck(cell + Vector2i(0, corner.y))
		if not ((open_x and open_z) or ((open_x or open_z) and (cell.x + cell.y) % 2 == 0)):
			continue
		var p := c + Vector3(corner.x, 0.0, corner.y) * (h - 0.2)
		Treehouse.add_log(wood, p + Vector3(0.0, 0.02, 0.0), p + Vector3(0.0, under - 0.4, 0.0), 0.15, STILT_WOOD)


## Big leaf decks: one leaf-green slab over the whole area, with pale veins
## running out from its middle, held up by thick stems.
func _build_leaf_decks(root: Node3D, wood: SurfaceTool) -> void:
	var cells: Array[Vector2i] = []
	for cell in ground_cells():
		if _char(cell) == "%":
			cells.append(cell)
	if cells.is_empty():
		return
	var centre := Vector3.ZERO
	for cell in cells:
		centre += Grid.cell_center(cell, map_size)
	centre /= cells.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := LEVEL_HEIGHT
	var h := Grid.TILE / 2.0
	var steps := 4
	for cell in cells:
		var c := Grid.cell_center(cell, map_size)
		for i in steps:
			for j in steps:
				var x0 := c.x - h + Grid.TILE * i / steps
				var x1 := c.x - h + Grid.TILE * (i + 1) / steps
				var z0 := c.z - h + Grid.TILE * j / steps
				var z1 := c.z - h + Grid.TILE * (j + 1) / steps
				var quad := [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)]
				for k in [0, 1, 2, 0, 2, 3]:
					var v: Vector3 = quad[k]
					st.set_color(_leaf_colour(v - centre))
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
		for d in DIRS:
			if _char(cell + d) == "%":
				continue
			var e := Vector3(d.x, 0.0, d.y)
			var along := Vector3(absf(e.z), 0.0, absf(e.x)) * h
			var a := c + e * h - along
			var b := c + e * h + along
			var rim := LEAF_GREEN.darkened(0.25)
			var face := [a + Vector3(0, top, 0), b + Vector3(0, top, 0), b + Vector3(0, top - LEAF_T, 0), a + Vector3(0, top - LEAF_T, 0)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(rim)
				st.set_normal(e)
				st.add_vertex(face[k])
		# Underside.
		var under := [Vector3(c.x - h, top - LEAF_T, c.z - h), Vector3(c.x + h, top - LEAF_T, c.z - h),
				Vector3(c.x + h, top - LEAF_T, c.z + h), Vector3(c.x - h, top - LEAF_T, c.z + h)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_color(LEAF_GREEN.darkened(0.4))
			st.set_normal(Vector3.DOWN)
			st.add_vertex(under[k])
	var leaf := MeshInstance3D.new()
	leaf.name = "LeafDeck"
	leaf.mesh = st.commit()
	leaf.material_override = MeshUtil.vertex_color_material()
	root.add_child(leaf)
	# Thick bark stems hold the leaf up, on every third tile, and vines
	# hang off its rim.
	for cell in cells:
		var c := Grid.cell_center(cell, map_size)
		if (cell.x + cell.y) % 3 == 0:
			Treehouse.add_branch(wood, c + Vector3(0.0, 0.02, 0.0), c + Vector3(0.0, top - LEAF_T - 0.02, 0.0), 0.36, 0.22, Vector3(0.12, 0.0, 0.0), STILT_WOOD)
		for d in DIRS:
			if _char(cell + d) == "%" or _cell_noise(cell, 33 + d.x + 2 * d.y) > 0.5:
				continue
			_add_vine(_vine_st, c + Vector3(d.x, 0.0, d.y) * 0.85 + Vector3(0.0, top - LEAF_T, 0.0), _rng.randf_range(0.5, 1.2), Vector3(d.x, 0.0, d.y), _rng)


## Leaf colour at an offset from the leaf's middle: a pale midrib along x,
## pale side veins fanning out, a little darker towards the rim.
func _leaf_colour(o: Vector3) -> Color:
	var angle := atan2(o.z, o.x)
	var vein := absf(fposmod(angle * 9.0 / PI, 1.0) - 0.5)  # 0.5 on a vein
	var on_vein := clampf((vein - 0.42) / 0.08, 0.0, 1.0)
	if absf(o.z) < 0.18:
		on_vein = 1.0
	var col := LEAF_GREEN.lerp(LEAF_VEIN, on_vein * 0.8)
	return col.darkened(clampf(o.length() / 30.0, 0.0, 0.18))


## Two-tile wooden stairs (Town Kit wide wooden stairs, stretched to rise
## half a level per tile), a wooden block under the top flight, handrails,
## one sloped collider and guards along both sides.
func _build_stairs(root: Node3D, wood: SurfaceTool) -> void:
	var steps := Node3D.new()
	steps.name = "Stairs"
	root.add_child(steps)
	var turn := {Vector2i(1, 0): 0.0, Vector2i(0, -1): 90.0, Vector2i(-1, 0): 180.0, Vector2i(0, 1): -90.0}
	for cell in ground_cells():
		if not is_stairs_low(cell):
			continue
		var r := rise_dir(cell)
		var high := cell + r
		var run := Vector3(r.x, 0.0, r.y)
		var side := Vector3(absf(run.z), 0.0, absf(run.x))
		var c_low := Grid.cell_center(cell, map_size)
		var c_high := Grid.cell_center(high, map_size)
		var half_level := LEVEL_HEIGHT / 2.0
		for part in [[c_low, 0.0], [c_high, half_level]]:
			var s := ModelLib.instance(ModelLib.TOWN + "stairs-wide-wood.glb")
			s.scale = Vector3(Grid.TILE, half_level, Grid.TILE)
			s.rotation_degrees.y = turn[r]
			s.position = (part[0] as Vector3) + Vector3(0.0, part[1], 0.0)
			steps.add_child(s)
		var h := Grid.TILE / 2.0
		MeshUtil.add_box(wood, c_high - Vector3(h, 0.0, h), c_high + Vector3(h, half_level, h), Treehouse.WOOD, Treehouse.WOOD_DARK)
		# One sloped collider from the grass at the bottom edge to the deck
		# at the top edge.
		var length := Vector2(2.0 * Grid.TILE, LEVEL_HEIGHT).length()
		var a := atan2(LEVEL_HEIGHT, 2.0 * Grid.TILE)
		var bx := (run * cos(a) + Vector3.UP * sin(a)).normalized()
		var by := (-run * sin(a) + Vector3.UP * cos(a)).normalized()
		var basis := Basis(bx, by, bx.cross(by))
		var mid := c_low + run * h + Vector3(0.0, half_level, 0.0)
		_shape(Vector3(length, STAIR_T, Grid.TILE), mid - by * STAIR_T / 2.0, "stairs", cell, basis)
		# Guards and handrails along both sides.
		for sgn: float in [-1.0, 1.0]:
			var edge := side * sgn * (h - GUARD_T / 2.0)
			_shape(Vector3(Grid.TILE * 2.0 * absf(run.x) + GUARD_T * absf(run.z), LEVEL_HEIGHT + GUARD_HEIGHT, Grid.TILE * 2.0 * absf(run.z) + GUARD_T * absf(run.x)),
					mid + edge - Vector3(0.0, half_level, 0.0) + Vector3(0.0, (LEVEL_HEIGHT + GUARD_HEIGHT) / 2.0, 0.0), "stairs_guard", cell)
			var bottom := c_low - run * (h - 0.1) + side * sgn * (h - 0.12)
			var topp := c_high + run * (h - 0.1) + side * sgn * (h - 0.12) + Vector3(0.0, LEVEL_HEIGHT, 0.0)
			for p in [bottom, topp]:
				Treehouse.add_log(wood, p + Vector3(0.0, 0.02, 0.0), p + Vector3(0.0, 0.95, 0.0), 0.07, STILT_WOOD)
			Treehouse.add_log(wood, bottom + Vector3(0.0, 0.9, 0.0), topp + Vector3(0.0, 0.9, 0.0), 0.035, Treehouse.ROPE, 6)


## Rope bridges: plank walkway on two beams, posts at both ends, and rope
## handrails that sag in the middle (no wind to pull them taut).
func _build_bridges(root: Node3D, wood: SurfaceTool) -> void:
	var bridges := Node3D.new()
	bridges.name = "Bridges"
	root.add_child(bridges)
	for cell in ground_cells():
		if not is_bridge(cell) or is_bridge(cell - bridge_axis(cell)):
			continue
		var axis := bridge_axis(cell)
		var cells: Array[Vector2i] = []
		var c := cell
		while is_bridge(c):
			cells.append(c)
			c += axis
		var y := float(cell_level(cell)) * LEVEL_HEIGHT
		var run := Vector3(axis.x, 0.0, axis.y)
		var across := Vector3(absf(run.z), 0.0, absf(run.x))
		var h := Grid.TILE / 2.0
		for b in cells:
			var bc := Grid.cell_center(b, map_size)
			_shape(Vector3(Grid.TILE, BRIDGE_T, Grid.TILE), bc + Vector3(0.0, y - BRIDGE_T / 2.0, 0.0), "bridge", b)
			_floor_quad("walk_x" if axis.x != 0 else "walk_z", b, y, 1.7, axis.x != 0)
		var start := Grid.cell_center(cells[0], map_size) - run * h + Vector3(0.0, y, 0.0)
		var end := Grid.cell_center(cells[-1], map_size) + run * h + Vector3(0.0, y, 0.0)
		for sgn: float in [-1.0, 1.0]:
			var off := across * sgn * 0.72
			MeshUtil.add_box(wood, start + off - across * 0.07 + Vector3(0.0, -PLANK_T - 0.16, 0.0),
					end + off + across * 0.07 + Vector3(0.0, -PLANK_T, 0.0), STILT_WOOD, STILT_WOOD)
			var a := start + run * 0.15 + across * sgn * 0.85
			var b := end - run * 0.15 + across * sgn * 0.85
			for p in [a, b]:
				Treehouse.add_log(wood, p + Vector3(0.0, 0.02, 0.0), p + Vector3(0.0, 1.25, 0.0), 0.08, STILT_WOOD)
			for rope in [[1.15, 0.38], [0.6, 0.22]]:
				var pts := PackedVector3Array()
				var radii := PackedFloat32Array()
				for i in 13:
					var t := i / 12.0
					pts.append(a.lerp(b, t) + Vector3(0.0, rope[0] - rope[1] * 4.0 * t * (1.0 - t), 0.0))
					radii.append(0.03)
				Treehouse.add_tube(wood, pts, radii, Treehouse.ROPE, 6)
				if rope[0] > 1.0:
					for i in range(1, 12):
						var p := pts[i]
						Treehouse.add_log(wood, p, Vector3(p.x, y + 0.02, p.z), 0.012, Treehouse.ROPE, 4)


## Rope railings along every deck edge you can't walk off: bark posts and
## a rope sagging between them. Where the drop is onto the island (not the
## sky) an invisible guard stops the player too (the sky side already has
## the island's edge walls).
func _build_rails(_root: Node3D, wood: SurfaceTool) -> void:
	var h := Grid.TILE / 2.0
	for cell in ground_cells():
		if not is_deck(cell):
			continue
		var links := walk_links(cell)
		var c := cell_pos(cell)
		for d in DIRS:
			var n := cell + d
			if n in links:
				continue
			if is_deck(n):
				continue
			var e := Vector3(d.x, 0.0, d.y)
			if is_ground(n):
				var along := Vector3(absf(e.z), 0.0, absf(e.x))
				_shape(along * Grid.TILE + e.abs() * GUARD_T + Vector3(0.0, GUARD_HEIGHT, 0.0),
						c + e * (h - GUARD_T / 2.0) + Vector3(0.0, GUARD_HEIGHT / 2.0, 0.0), "deck_guard", cell)
			var along := Vector3(absf(e.z), 0.0, absf(e.x))
			var a := c + e * (h - 0.12) - along * (h - 0.12)
			var b := c + e * (h - 0.12) + along * (h - 0.12)
			for p in [a, b]:
				Treehouse.add_log(wood, p + Vector3(0.0, 0.02, 0.0), p + Vector3(0.0, 0.9, 0.0), 0.06, STILT_WOOD, 6)
			for rope_y in [0.82, 0.45]:
				var pts := PackedVector3Array()
				var radii := PackedFloat32Array()
				for i in 9:
					var t := i / 8.0
					pts.append(a.lerp(b, t) + Vector3(0.0, rope_y - 0.16 * 4.0 * t * (1.0 - t), 0.0))
					radii.append(0.025)
				Treehouse.add_tube(wood, pts, radii, Treehouse.ROPE, 5)


# ---------------------------------------------------------------- props

func _prop_layout() -> Array[Dictionary]:
	var N := NK
	return [
		# ---- The far cliff on the north edge, with its knot of wind.
		{"type": "wind_cliff", "cell": Vector2i(12, 0), "size": Vector2i(5, 3)},
		{"type": "crate", "cell": Vector2i(11, 0), "rot": 41.0},
		{"type": "crate", "cell": Vector2i(17, 0), "rot": 42.0},
		{"type": "tub_tree", "cell": Vector2i(18, 2), "seed": 121},
		# A weathered sign says what the cliff is (Press E to read it).
		{"type": "nature", "model": ModelLib.SURVIVAL + "signpost.glb", "cell": Vector2i(15, 3), "fill": 0.6, "rot": 200.0, "solid": true},
		# ---- Windward Lookout: a quiet corner facing the cliff.
		{"type": "bench", "cell": Vector2i(15, 6), "rot": 90.0},
		{"type": "bench", "cell": Vector2i(11, 6), "rot": 90.0},
		{"type": "paper_lantern", "cell": Vector2i(12, 5)},
		{"type": "banner_pole", "cell": Vector2i(14, 8), "rot": 0.0},
		{"type": "planter", "cell": Vector2i(18, 7), "flower": "flower_purpleA"},
		{"type": "tub_tree", "cell": Vector2i(10, 8), "seed": 128},
		{"type": "tub_tree", "cell": Vector2i(18, 9), "seed": 135},
		{"type": "flowers", "cell": Vector2i(16, 8), "rot": 50.0},
		{"type": "nature", "model": N + "flower_yellowB.glb", "cell": Vector2i(11, 4), "fill": 0.45, "rot": 10.0, "solid": false, "max_height": 0.7},
		{"type": "mushrooms", "cell": Vector2i(17, 5), "rot": 120.0},
		{"type": "barrel", "cell": Vector2i(10, 6), "rot": 46.0},
		# ---- North-west pad: the kite hill, with its high deck.
		{"type": "tub_tree", "cell": Vector2i(1, 1), "seed": 149},
		{"type": "tub_tree", "cell": Vector2i(6, 1), "seed": 156},
		{"type": "barrel", "cell": Vector2i(0, 5), "rot": 49.0},
		{"type": "grass", "cell": Vector2i(3, 2), "rot": 30.0},
		{"type": "flowers_tall", "cell": Vector2i(7, 6)},
		{"type": "tub_tree", "cell": Vector2i(1, 7), "seed": 170},
		{"type": "kite_pole", "cell": Vector2i(2, 4), "color": "yellow", "rot": 0.0},
		{"type": "kite_pole", "cell": Vector2i(6, 6), "color": "blue", "rot": 180.0},
		{"type": "kite_pole", "cell": Vector2i(2, 6), "color": "white", "rot": 30.0},
		{"type": "planter", "cell": Vector2i(6, 4), "flower": "flower_redA"},
		{"type": "wind_chime", "cell": Vector2i(6, 7), "rot": 90.0},
		{"type": "paper_lantern", "cell": Vector2i(2, 7)},
		# ---- West terrace: the kite-maker's workshop.
		{"type": "cabin", "cell": Vector2i(2, 11), "size": Vector2i(2, 2), "seed": 177,
			"interior": "res://scenes/interiors/kite_workshop.tscn"},
		{"type": "kite_rack", "cell": Vector2i(5, 11), "rot": 0.0},
		{"type": "planter", "cell": Vector2i(1, 11), "flower": "flower_yellowC"},
		{"type": "planter", "cell": Vector2i(6, 10), "flower": "flower_purpleB"},
		{"type": "paper_lantern", "cell": Vector2i(1, 12)},
		{"type": "crate", "cell": Vector2i(1, 14), "rot": 20.0},
		{"type": "barrel", "cell": Vector2i(1, 15)},
		{"type": "bunting", "cell": Vector2i(4, 15), "size": Vector2i(2, 1)},
		{"type": "banner_pole", "cell": Vector2i(6, 15), "red": true, "rot": 180.0},
		{"type": "wind_chime", "cell": Vector2i(5, 13), "rot": 0.0},
		# Under the terrace: a little nook by the island's edge.
		{"type": "tub_tree", "cell": Vector2i(0, 11), "seed": 184},
		{"type": "planter", "cell": Vector2i(0, 12), "flower": "flower_redC"},
		{"type": "nature", "model": N + "log_stack.glb", "cell": Vector2i(0, 13), "fill": 0.6, "rot": 90.0, "solid": true},
		# ---- North-east pad: the rope-weaver's corner and the old mill.
		{"type": "windmill", "cell": Vector2i(24, 1), "size": Vector2i(2, 2), "rot": 0.0},
		{"type": "rope_coils", "cell": Vector2i(22, 2), "rot": 15.0},
		{"type": "rope_coils", "cell": Vector2i(22, 6), "rot": -30.0},
		{"type": "hut", "cell": Vector2i(26, 4), "size": Vector2i(1, 1), "straw": true, "interior": "res://scenes/interiors/rope_loft.tscn"},
		{"type": "tub_tree", "cell": Vector2i(26, 1), "seed": 191},
		{"type": "tub_tree", "cell": Vector2i(22, 0), "seed": 198},
		{"type": "paper_lantern", "cell": Vector2i(25, 6)},
		{"type": "flowers", "cell": Vector2i(26, 6), "rot": 200.0},
		{"type": "crate", "cell": Vector2i(21, 6), "rot": -15.0},
		{"type": "grass", "cell": Vector2i(27, 1), "rot": 80.0},
		# ---- North band (between the pads and the plaza).
		{"type": "tub_tree", "cell": Vector2i(8, 10), "seed": 205},
		{"type": "hut", "cell": Vector2i(10, 11), "size": Vector2i(1, 1), "interior": "res://scenes/interiors/captain_cabin.tscn"},
		{"type": "tub_tree", "cell": Vector2i(15, 10), "seed": 212},
		{"type": "tub_tree", "cell": Vector2i(19, 10), "seed": 219},
		{"type": "tub_tree", "cell": Vector2i(26, 11), "seed": 226},
		{"type": "planter", "cell": Vector2i(22, 11), "flower": "flower_yellowA"},
		{"type": "flowers_tall", "cell": Vector2i(11, 10)},
		{"type": "grass", "cell": Vector2i(20, 11), "rot": 10.0},
		# ---- Around the plaza: limp kites, banners, lanterns.
		{"type": "kite_pole", "cell": Vector2i(11, 13), "color": "yellow", "rot": 0.0},
		{"type": "kite_pole", "cell": Vector2i(15, 13), "color": "green", "rot": 200.0},
		{"type": "banner_pole", "cell": Vector2i(9, 17), "rot": 0.0},
		{"type": "banner_pole", "cell": Vector2i(17, 17), "red": true, "rot": 180.0},
		{"type": "paper_lantern", "cell": Vector2i(14, 14)},
		{"type": "paper_lantern", "cell": Vector2i(12, 19)},
		{"type": "planter", "cell": Vector2i(16, 18), "flower": "flower_redB"},
		{"type": "planter", "cell": Vector2i(10, 19), "flower": "flower_purpleC"},
		# ---- East leaf rise: the weather-watcher's lookout and the third mill.
		{"type": "cabin", "cell": Vector2i(21, 13), "size": Vector2i(2, 2), "seed": 233, "straw": true,
			"interior": "res://scenes/interiors/lookout.tscn"},
		{"type": "windmill", "cell": Vector2i(24, 13), "size": Vector2i(2, 2), "rot": 0.0},
		{"type": "weathervane", "cell": Vector2i(25, 16)},
		{"type": "planter", "cell": Vector2i(20, 13), "flower": "flower_yellowB"},
		{"type": "wind_chime", "cell": Vector2i(25, 17), "rot": 180.0},
		{"type": "paper_lantern", "cell": Vector2i(20, 17)},
		{"type": "tub_tree", "cell": Vector2i(19, 14), "seed": 240},
		{"type": "tub_tree", "cell": Vector2i(27, 13), "seed": 247},
		{"type": "flowers", "cell": Vector2i(18, 13), "rot": 10.0},
		{"type": "paper_lantern", "cell": Vector2i(18, 17)},
		{"type": "tub_tree", "cell": Vector2i(27, 16), "seed": 254},
		# ---- South field: the first mill, the bakery, the family home,
		# the chime-maker's corner, huts and gardens.
		{"type": "windmill", "cell": Vector2i(2, 20), "size": Vector2i(2, 2), "rot": 0.0},
		{"type": "kite_pole", "cell": Vector2i(6, 20), "color": "white", "rot": 90.0},
		{"type": "hut", "cell": Vector2i(6, 23), "size": Vector2i(1, 1), "interior": "res://scenes/interiors/bakehouse.tscn"},
		{"type": "bunting", "cell": Vector2i(8, 23), "size": Vector2i(2, 1)},
		{"type": "oven", "cell": Vector2i(10, 21)},
		{"type": "bake_stall", "cell": Vector2i(11, 21), "rot": 0.0},
		{"type": "barrel", "cell": Vector2i(10, 22), "rot": 30.0},
		{"type": "crate", "cell": Vector2i(11, 22), "rot": -10.0},
		{"type": "cabin", "cell": Vector2i(17, 20), "size": Vector2i(2, 2), "seed": 261, "straw": true,
			"interior": "res://scenes/interiors/family_home.tscn"},
		{"type": "planter", "cell": Vector2i(19, 21), "flower": "flower_redA"},
		{"type": "flowers", "cell": Vector2i(16, 20), "rot": 20.0},
		{"type": "wind_chime", "cell": Vector2i(20, 24), "rot": 0.0},
		{"type": "wind_chime", "cell": Vector2i(22, 24), "rot": 120.0},
		{"type": "wind_chime", "cell": Vector2i(21, 26), "rot": 240.0},
		{"type": "hut", "cell": Vector2i(23, 23), "size": Vector2i(1, 1), "straw": true, "interior": "res://scenes/interiors/chime_workshop.tscn"},
		{"type": "tub_tree", "cell": Vector2i(25, 20), "seed": 268},
		{"type": "tub_tree", "cell": Vector2i(1, 24), "seed": 275},
		{"type": "tub_tree", "cell": Vector2i(4, 26), "seed": 282},
		{"type": "tub_tree", "cell": Vector2i(8, 26), "seed": 289},
		{"type": "tub_tree", "cell": Vector2i(25, 25), "seed": 296},
		{"type": "tub_tree", "cell": Vector2i(27, 18), "seed": 303},
		{"type": "paper_lantern", "cell": Vector2i(12, 24)},
		{"type": "paper_lantern", "cell": Vector2i(14, 24)},
		{"type": "planter", "cell": Vector2i(11, 26), "flower": "flower_yellowC"},
		{"type": "planter", "cell": Vector2i(15, 26), "flower": "flower_purpleA"},
		{"type": "flowers", "cell": Vector2i(4, 23), "rot": 90.0},
		{"type": "flowers_tall", "cell": Vector2i(18, 25)},
		{"type": "grass", "cell": Vector2i(9, 20), "rot": 45.0},
		{"type": "grass", "cell": Vector2i(22, 19), "rot": 150.0},
		{"type": "mushrooms", "cell": Vector2i(1, 25), "rot": 30.0},
		{"type": "barrel", "cell": Vector2i(0, 18), "rot": 70.0},
		{"type": "barrel", "cell": Vector2i(26, 23), "rot": 71.0},
		{"type": "planter", "cell": Vector2i(7, 19), "flower": "flower_purpleC"},
		{"type": "nature", "model": N + "flower_redB.glb", "cell": Vector2i(19, 23), "fill": 0.45, "rot": 0.0, "solid": false, "max_height": 0.7},
		{"type": "nature", "model": N + "grass_leafsLarge.glb", "cell": Vector2i(5, 21), "fill": 0.6, "rot": 0.0, "solid": false, "max_height": 0.7},
	]


## The sign by the far cliff: stand beside it and press E to read it.
func _after_build() -> void:
	_add_talk_spot(Vector2i(14, 3), Vector2i(15, 3), "gust_point", 1.6)
	_add_atmosphere()
	_build_canopy_frame()


## Villagers: id (data/dialogue/<id>.json), tile, facing (degrees, 0 =
## towards the camera / south, 180 = north). The kite-maker is indoors.
func _villager_layout() -> Array[Dictionary]:
	return [
		# The old sailor sits looking out at the far cliff.
		{"id": "captain_brisk", "cell": Vector2i(16, 6), "facing": 180.0},
		# The weather-watcher, out on the leaf rise, squinting at a still sky.
		{"id": "nimbus", "cell": Vector2i(23, 16), "facing": 160.0},
		# Two children under their limp kites by the plaza.
		{"id": "wisp", "cell": Vector2i(11, 14), "facing": 200.0},
		{"id": "tuck", "cell": Vector2i(15, 14), "facing": 160.0},
		# The rope-weaver among her coils.
		{"id": "maude", "cell": Vector2i(23, 5), "facing": -60.0},
		# The baker behind the stall.
		{"id": "barnaby", "cell": Vector2i(12, 21), "facing": 90.0},
		# The chime-maker among the silent chimes.
		{"id": "bellamy", "cell": Vector2i(21, 24), "facing": 0.0},
	]

# ---------------------------------------------------------------- canopy ground

## The ground is not Pebblenook's grass and rock: Leafwind's pads are wooden
## decks laid over giant branches. The fit check reads this to know which
## ground rules apply.
const GROUND_STYLE := "canopy"
## How deep the bark rim round each pad goes (m).
const RIM_DEPTH := 0.6
## The woven-leaf plaza in the middle of the village.
const PLAZA := Rect2i(10, 15, 7, 3)
## The windward lookout is the top of a great branch: bark underfoot.
const BARK_TOP := Rect2i(10, 0, 9, 10)
## A few soft patches of moss (flowers and mushrooms grow on them).
const MOSS_CELLS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(16, 8), Vector2i(17, 5), Vector2i(11, 4), Vector2i(4, 23),
	Vector2i(5, 21), Vector2i(9, 20), Vector2i(1, 25), Vector2i(18, 25), Vector2i(19, 23), Vector2i(22, 19),
	Vector2i(26, 6), Vector2i(27, 1), Vector2i(16, 20), Vector2i(7, 6), Vector2i(11, 10), Vector2i(20, 11), Vector2i(18, 13)]

var _floors := {}  # kind -> SurfaceTool


## What a tile's floor is made of.
func _floor_kind(cell: Vector2i) -> String:
	if cell in MOSS_CELLS:
		return "moss"
	if is_path(cell):
		if PLAZA.has_point(cell):
			return "weave"
		var along_z := is_path(cell + Vector2i(0, 1)) or is_path(cell - Vector2i(0, 1))
		var along_x := is_path(cell + Vector2i(1, 0)) or is_path(cell - Vector2i(1, 0))
		return "walk_z" if along_z and not along_x else "walk_x"
	if BARK_TOP.has_point(cell):
		return "bark"
	return "deck"


const FLOOR_COLOURS := {"deck": Treehouse.WOOD, "walk_x": Treehouse.WOOD_LIGHT, "walk_z": Treehouse.WOOD_LIGHT,
	"weave": Treehouse.LEAF_LIGHT, "moss": Treehouse.MOSS, "bark": Treehouse.BARK}


## One flat floor quad over a tile at height y. Rope bridges are narrower:
## `width` across, running along x (`run_x`) or z.
func _floor_quad(kind: String, cell: Vector2i, y: float, width := Grid.TILE, run_x := true) -> void:
	if not _floors.has(kind):
		var new_st := SurfaceTool.new()
		new_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_floors[kind] = new_st
	var st: SurfaceTool = _floors[kind]
	var c := Grid.cell_center(cell, map_size)
	var hx := (Grid.TILE if run_x else width) / 2.0
	var hz := (width if run_x else Grid.TILE) / 2.0
	var q := [Vector3(c.x - hx, y, c.z - hz), Vector3(c.x + hx, y, c.z - hz), Vector3(c.x + hx, y, c.z + hz), Vector3(c.x - hx, y, c.z + hz)]
	var colour: Color = FLOOR_COLOURS[kind]
	colour = colour.darkened(_cell_noise(cell, 61) * 0.06)
	for k in [0, 2, 1, 0, 3, 2]:
		st.set_color(colour)
		st.set_normal(Vector3.UP)
		st.add_vertex(q[k])


func _commit_floors(parent: Node3D) -> void:
	for kind: String in _floors:
		parent.add_child(Treehouse.mesh(_floors[kind], Treehouse.floor_material(kind), "floor_" + kind))
	_floors.clear()


## Leafwind's ground: plank decks, walkways, a woven-leaf plaza, bark and
## moss on top; a bark rim round every pad's edge; under each pad, great
## bark-covered branches holding it up, with roots and vines hanging into
## the sky. Floor collision is one box per tile, as on every island.
func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := Grid.TILE / 2.0
	var rim_edges := 0
	for cell in land_cells():
		_floor_quad(_floor_kind(cell), cell, 0.0)
		var c := Grid.cell_center(cell, map_size)
		for d in DIRS:
			if is_land(cell + d):
				continue
			rim_edges += 1
			var e := Vector3(d.x, 0.0, d.y)
			var along := Vector3(absf(e.z), 0.0, absf(e.x))
			var a := c + e * h - along * h
			var b := c + e * h + along * h
			var face := [a, b, b - Vector3(0.0, RIM_DEPTH, 0.0), a - Vector3(0.0, RIM_DEPTH, 0.0)]
			var tone := Treehouse.BARK.darkened(_cell_noise(cell, 70 + d.x + 3 * d.y) * 0.12)
			for k in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = face[k]
				rim.set_color(tone)
				rim.set_uv(Vector2((v - a).dot(along) * 0.6, -v.y * 2.0))
				rim.set_normal(e)
				rim.add_vertex(v)
		var under := [Vector3(c.x - h, -RIM_DEPTH, c.z - h), Vector3(c.x + h, -RIM_DEPTH, c.z - h),
				Vector3(c.x + h, -RIM_DEPTH, c.z + h), Vector3(c.x - h, -RIM_DEPTH, c.z + h)]
		for k in [0, 1, 2, 0, 2, 3]:
			rim.set_color(Treehouse.BARK_DARK)
			rim.set_uv(Vector2((under[k] as Vector3).x * 0.3, (under[k] as Vector3).z * 0.3))
			rim.set_normal(Vector3.DOWN)
			rim.add_vertex(under[k])
	_commit_floors(ground)
	var rim_mesh := Treehouse.mesh(rim, Treehouse.bark_material(), "Rims")
	rim_mesh.set_meta("rim_edges", rim_edges)
	ground.add_child(rim_mesh)
	_build_underside()
	# Floor collision: one box per land tile, top at y = 0.
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorBody"
	add_child(floor_body)
	for cell in land_cells():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(Grid.TILE, GRASS_THICKNESS, Grid.TILE)
		shape.shape = box
		shape.position = Grid.cell_center(cell, map_size) + Vector3(0.0, -GRASS_THICKNESS / 2.0, 0.0)
		floor_body.add_child(shape)


## The pads (land tiles joined edge to edge).
func _pads() -> Array:
	var seen := {}
	var pads := []
	for start in land_cells():
		if seen.has(start):
			continue
		var cells: Array[Vector2i] = [start]
		seen[start] = true
		var i := 0
		while i < cells.size():
			for d in DIRS:
				var n := cells[i] + d
				if is_land(n) and not seen.has(n):
					seen[n] = true
					cells.append(n)
			i += 1
		pads.append(cells)
	return pads


## Under each pad: a great branch rising out of the clouds to hold it,
## limbs spreading under its far corners, roots trailing down, and vines
## hanging off the rims into the gaps. Everything stays under its pad.
func _build_underside() -> void:
	var under := Node3D.new()
	under.name = "Underside"
	add_child(under)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vines := SurfaceTool.new()
	vines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var top := -RIM_DEPTH
	for cells: Array in _pads():
		var centre := Vector3.ZERO
		for c: Vector2i in cells:
			centre += Grid.cell_center(c, map_size)
		centre /= cells.size()
		var r_top := clampf(sqrt(float(cells.size())) * 0.17, 0.9, 2.2)
		var crown := Vector3(centre.x, top - r_top - 0.05, centre.z)
		var base := crown + Vector3(rng.randf_range(-1.0, 1.0), -30.0, rng.randf_range(-1.0, 1.0))
		Treehouse.add_branch(bark, base, crown, r_top * 1.6, r_top, Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.0, 1.0)), Treehouse.BARK, 10)
		# Limbs out to the pad's inner tiles, furthest from the middle.
		var inner: Array[Vector2i] = []
		for c: Vector2i in cells:
			if is_land(c + Vector2i(1, 0)) and is_land(c - Vector2i(1, 0)) and is_land(c + Vector2i(0, 1)) and is_land(c - Vector2i(0, 1)):
				inner.append(c)
		for k in 5:
			var a := TAU * k / 5.0 + 0.3
			var dir := Vector2(cos(a), sin(a))
			var best := Vector2i(-1, -1)
			var best_d := -INF
			for c: Vector2i in inner:
				var p := Grid.cell_center(c, map_size)
				var dd := Vector2(p.x - centre.x, p.z - centre.z).dot(dir)
				if dd > best_d:
					best_d = dd
					best = c
			if best.x < 0 or best_d < 3.0:
				continue
			var r1 := 0.3
			var tip := Grid.cell_center(best, map_size) + Vector3(0.0, top - r1 - 0.03, 0.0)
			var from := crown - Vector3(0.0, 2.5, 0.0)
			Treehouse.add_branch(bark, from, tip, r_top * 0.55, r1, Vector3(0.0, -1.2, 0.0), Treehouse.BARK.darkened(0.05), 8)
		# Roots trailing down from the great branch.
		for k in 3:
			var a := TAU * k / 3.0 + rng.randf()
			var from := crown - Vector3(0.0, 4.0 + 2.0 * k, 0.0)
			var to := from + Vector3(cos(a) * 1.2, -rng.randf_range(4.0, 7.0), sin(a) * 1.2)
			Treehouse.add_branch(bark, from, to, 0.22, 0.04, Vector3(cos(a), 0.0, sin(a)) * 0.6, Treehouse.BARK_DARK, 6)
	# Vines off the rims.
	for cell in land_cells():
		for d in DIRS:
			if is_land(cell + d) or _cell_noise(cell, 80 + d.x * 2 + d.y) > 0.32:
				continue
			var e := Vector3(d.x, 0.0, d.y)
			var along := Vector3(absf(e.z), 0.0, absf(e.x))
			var p := Grid.cell_center(cell, map_size) + e * (Grid.TILE / 2.0 - 0.06) + along * (_cell_noise(cell, 90) - 0.5) * 1.4
			_add_vine(vines, Vector3(p.x, -0.1, p.z), rng.randf_range(1.6, 5.5), e, rng)
	under.add_child(Treehouse.mesh(bark, Treehouse.bark_material(), "Branches"))
	under.add_child(Treehouse.mesh(vines, Treehouse.flat_material(), "Vines"))


## A vine hanging from `top`: a thin stem bowing out a little, with small
## leaves along it.
func _add_vine(st: SurfaceTool, top: Vector3, length: float, out: Vector3, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var steps := 8
	var sway := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(top + Vector3(0.0, -length * t, 0.0) + out * 0.25 * sin(PI * t * 0.8) + sway * t * t)
		radii.append(lerpf(0.035, 0.015, t))
	Treehouse.add_tube(st, pts, radii, Treehouse.LEAF_DARK.darkened(0.2), 5, false)
	var leaves := int(length / 0.3)
	for j in leaves:
		var t := (float(j) + 0.5) / leaves
		var i := mini(int(t * steps), steps - 1)
		var p := pts[i].lerp(pts[i + 1], t * steps - i)
		var a := rng.randf_range(0.0, TAU)
		var side := Vector3(cos(a), 0.0, sin(a))
		var tip := p + side * 0.2 + Vector3(0.0, -0.06, 0.0)
		var wing := side.cross(Vector3.UP) * 0.07
		var col := [Treehouse.LEAF, Treehouse.LEAF_DARK, Treehouse.LEAF_LIGHT][j % 3] as Color
		for v in [p, tip + wing * 0.3 - side * 0.1 + wing, tip, p, tip, tip - side * 0.1 - wing]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)


# ---------------------------------------------------------------- atmosphere

## Pale haze drifting in the gaps between the pads and under the rims, and
## soft rays of light slanting down through the canopy.
func _add_atmosphere() -> void:
	var air := Node3D.new()
	air.name = "Atmosphere"
	add_child(air)
	var mist_shader := preload("res://shaders/mist.gdshader")
	var n := 0
	for z in range(-2, map_size.y + 2):
		for x in range(-2, map_size.x + 2):
			var cell := Vector2i(x, z)
			if is_ground(cell) or not _near_land(cell, 2) or _cell_noise(cell, 51) > 0.14:
				continue
			var mist := MeshInstance3D.new()
			mist.name = "Mist%d" % n
			var quad := QuadMesh.new()
			quad.size = Vector2(6.0 + _cell_noise(cell, 52) * 4.0, 3.0 + _cell_noise(cell, 53) * 1.5)
			mist.mesh = quad
			var mat := ShaderMaterial.new()
			mat.shader = mist_shader
			mat.set_shader_parameter("seed", float(n) * 3.7)
			mat.set_shader_parameter("opacity", 0.22 + _cell_noise(cell, 54) * 0.18)
			mist.material_override = mat
			mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mist.position = Grid.cell_center(cell, map_size) + Vector3(0.0, -2.2 + _cell_noise(cell, 55) * 2.8, 0.0)
			air.add_child(mist)
			n += 1
	# Light shafts, slanting the same way as the sun.
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	var to_sun := (sun.global_basis.z if sun else Vector3(0.4, 0.8, 0.3)).normalized()
	var shaft_shader := preload("res://shaders/light_shaft.gdshader")
	var spots := [[Vector2i(13, 16), 0.0], [Vector2i(14, 6), 0.0], [Vector2i(4, 13), 2.0], [Vector2i(22, 16), 2.0],
			[Vector2i(12, 23), 0.0], [Vector2i(24, 4), 0.0], [Vector2i(8, 9), -1.0]]
	for i in spots.size():
		var cell: Vector2i = spots[i][0]
		var foot := Grid.cell_center(cell, map_size) + Vector3(0.0, spots[i][1], 0.0)
		var length := 20.0
		var y := to_sun
		var x := y.cross(Vector3(0.0, 0.5, 1.0).normalized()).normalized()
		var zz := x.cross(y)
		var shaft := MeshInstance3D.new()
		shaft.name = "LightShaft%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(2.4 + 0.6 * (i % 3), length)
		shaft.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = shaft_shader
		mat.set_shader_parameter("strength", 0.09 + 0.03 * (i % 2))
		shaft.material_override = mat
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.transform = Transform3D(Basis(x, y, zz), foot + y * (length / 2.0))
		air.add_child(shaft)


func _near_land(cell: Vector2i, reach: int) -> bool:
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if is_land(cell + Vector2i(dx, dz)):
				return true
	return false


# ---------------------------------------------------------------- framing

## Great overhead branches with leaf clusters across the top corners of the
## view, and vines hanging down at the sides, so the village sits inside a
## giant canopy. Attached to the game camera and sized by the view (screen
## fraction), so it frames the same way at any resolution.
func _build_canopy_frame() -> void:
	var cam := get_parent().get_node_or_null("Camera") as Camera3D
	if cam == null:
		return
	var frame := Node3D.new()
	frame.name = "CanopyFrame"
	cam.add_child(frame)
	var d := 6.0
	var hh := d * tan(deg_to_rad(cam.fov / 2.0))
	var hw := hh * 16.0 / 9.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones := [Treehouse.LEAF.darkened(0.12), Treehouse.LEAF_DARK.darkened(0.1), Treehouse.LEAF, Treehouse.LEAF_LIGHT.darkened(0.08)]
	# [start, end, start radius] in view units (hw, hh), at depth d.
	var limbs := [[Vector2(-1.35, 0.92), Vector2(-0.2, 1.22), 0.5], [Vector2(1.35, 0.88), Vector2(0.28, 1.25), 0.45],
			[Vector2(-1.25, 1.25), Vector2(-0.55, 0.98), 0.25]]
	for limb in limbs:
		var a := Vector3((limb[0] as Vector2).x * hw, (limb[0] as Vector2).y * hh, -d - 0.8)
		var b := Vector3((limb[1] as Vector2).x * hw, (limb[1] as Vector2).y * hh, -d + 0.4)
		Treehouse.add_branch(bark, a, b, limb[2], 0.1, Vector3(0.0, -hh * 0.12, 0.0), Treehouse.BARK_DARK, 8)
		for k in 6:
			var t := 0.2 + 0.13 * k
			var p := a.lerp(b, t) + Vector3(0.0, -hh * 0.12 * sin(PI * t), 0.0)
			var twig := p + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.9, -0.3), rng.randf_range(-0.3, 0.6))
			Treehouse.add_branch(bark, p, twig, 0.09, 0.03, Vector3(0.0, 0.1, 0.0), Treehouse.BARK_DARK, 4)
			var s := rng.randf_range(0.7, 1.15)
			Treehouse.add_leaf_blob(leaves, twig, Vector3(1.0, 0.65, 0.8) * s, tones[k % tones.size()], rng)
			Treehouse.add_leaf_blob(leaves, p + Vector3(0.0, 0.3, -0.2), Vector3(0.9, 0.6, 0.7) * s, tones[(k + 1) % tones.size()], rng)
	# Clusters peeking down along the top edge.
	for k in 5:
		var x := lerpf(-0.6, 0.65, float(k) / 4.0) * hw + rng.randf_range(-0.4, 0.4)
		Treehouse.add_leaf_blob(leaves, Vector3(x, hh * 1.12, -d - rng.randf_range(0.0, 1.0)), Vector3(1.1, 0.6, 0.8) * rng.randf_range(0.8, 1.2), tones[k % tones.size()], rng)
	# Vines down the sides.
	var vines := SurfaceTool.new()
	vines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [[-0.95, 0.75], [-0.86, 0.45], [-0.78, 0.25], [0.93, 0.6], [0.84, 0.3]]:
		var top := Vector3(v[0] * hw, hh * 1.1, -d + 0.2)
		_add_vine(vines, top, hh * (1.1 - v[1]) + 0.5, Vector3.ZERO, rng)
	for part in [Treehouse.mesh(bark, Treehouse.bark_material(), "Branches"), Treehouse.mesh(leaves, Treehouse.flat_material(), "Leaves"),
			Treehouse.mesh(vines, Treehouse.flat_material(), "Vines")]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(part)
