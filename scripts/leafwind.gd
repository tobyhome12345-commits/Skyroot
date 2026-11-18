extends "res://scripts/island.gd"
## Leafwind: a breezy canopy village in the treetops, stuck in a dead calm.
## Windmills stand frozen, kites hang limp, banners and chimes droop.
## 28 x 28 tiles on two levels: the grass (level 0) and wooden / leaf decks
## one tile up (level 1), joined by two-tile wooden stairs, with rope
## bridges across the sky gaps between the island's pads.
##
## Map: '#' grass, '=' path, '.' sky (level 0 unless said)
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
const DECK_WOOD := Color(0.62, 0.45, 0.3)
const STILT_WOOD := Color(0.48, 0.34, 0.24)
const LEAF_GREEN := Color(0.5, 0.72, 0.4)
const LEAF_VEIN := Color(0.72, 0.85, 0.56)

var _body: StaticBody3D


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
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_decks(root, wood)
	_build_leaf_decks(root)
	_build_stairs(root, wood)
	_build_bridges(root, wood)
	_build_rails(root)
	var mi := MeshInstance3D.new()
	mi.name = "Woodwork"
	mi.mesh = wood.commit()
	mi.material_override = MeshUtil.vertex_color_material()
	root.add_child(mi)


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


## Wooden decks: Town Kit planks on top (top at level 1), a frame of boards
## round the edge, log stilts at the corners, and moss hanging off the edges.
## Each deck tile is solid from the grass up to its top.
func _build_decks(root: Node3D, wood: SurfaceTool) -> void:
	var planks := Node3D.new()
	planks.name = "DeckPlanks"
	root.add_child(planks)
	var top := LEVEL_HEIGHT
	for cell in ground_cells():
		if not is_deck(cell):
			continue
		var c := Grid.cell_center(cell, map_size)
		_shape(Vector3(Grid.TILE, top, Grid.TILE), c + Vector3(0.0, top / 2.0, 0.0), "deck", cell)
		if _char(cell) != "^":
			continue
		var rot := 90.0 if (cell.x + cell.y) % 2 == 0 else 0.0
		planks.add_child(ModelLib.piece(ModelLib.TOWN + "planks.glb", Grid.TILE, c + Vector3(0.0, top - PLANK_T, 0.0), rot))
		_deck_edges(root, wood, cell, top - PLANK_T, DECK_WOOD)


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
			var moss := ModelLib.fitted(NK + "hanging_moss.glb", Vector2(0.4, 0.4), 1.0, 0.9)
			var shift := (_cell_noise(cell, 20 + d.x + 2 * d.y) - 0.5) * 1.2
			moss.position = centre - e * 0.16 + along * shift + Vector3(0.0, under - 0.4 - 0.9, 0.0)
			root.add_child(moss)
	# Stilts on corners where two open edges meet (the deck's outer corners)
	# and every other tile along its edges.
	for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var open_x := not is_deck(cell + Vector2i(corner.x, 0))
		var open_z := not is_deck(cell + Vector2i(0, corner.y))
		if not ((open_x and open_z) or ((open_x or open_z) and (cell.x + cell.y) % 2 == 0)):
			continue
		var p := c + Vector3(corner.x, 0.0, corner.y) * (h - 0.2)
		MeshUtil.add_box(wood, p - Vector3(0.13, 0.0, 0.13), p + Vector3(0.13, under - 0.4, 0.13), STILT_WOOD, STILT_WOOD)


## Big leaf decks: one leaf-green slab over the whole area, with pale veins
## running out from its middle, held up by thick stems.
func _build_leaf_decks(root: Node3D) -> void:
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
	# Thick stems hold the leaf up, on every other tile.
	var stem_mat := MeshUtil.color_material(Color(0.5, 0.4, 0.26))
	for cell in cells:
		if (cell.x + cell.y) % 3 != 0:
			continue
		var stem := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.38
		cyl.height = top - LEAF_T
		cyl.radial_segments = 10
		stem.mesh = cyl
		stem.material_override = stem_mat
		stem.position = Grid.cell_center(cell, map_size) + Vector3(0.0, cyl.height / 2.0, 0.0)
		root.add_child(stem)
		_deck_moss(root, cell, top - LEAF_T)


func _deck_moss(root: Node3D, cell: Vector2i, under: float) -> void:
	for d in DIRS:
		if _char(cell + d) == "%":
			continue
		var moss := ModelLib.fitted(NK + "hanging_moss.glb", Vector2(0.4, 0.4), 1.0, 0.8)
		moss.position = Grid.cell_center(cell, map_size) + Vector3(d.x, 0.0, d.y) * 0.8 + Vector3(0.0, under - 0.8, 0.0)
		root.add_child(moss)


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
		MeshUtil.add_box(wood, c_high - Vector3(h, 0.0, h), c_high + Vector3(h, half_level, h), DECK_WOOD, DECK_WOOD.darkened(0.2))
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
				MeshUtil.add_box(wood, p - Vector3(0.06, 0.0, 0.06), p + Vector3(0.06, 0.95, 0.06), STILT_WOOD, STILT_WOOD)
			steps.add_child(Props._rod(bottom + Vector3(0.0, 0.9, 0.0), topp + Vector3(0.0, 0.9, 0.0), 0.04, DECK_WOOD))


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
			var plank := ModelLib.instance(ModelLib.TOWN + "planks.glb")
			plank.scale = Vector3(Grid.TILE, Grid.TILE, 1.6)
			plank.rotation_degrees.y = 0.0 if axis.x != 0 else 90.0
			plank.position = bc + Vector3(0.0, y - PLANK_T, 0.0)
			bridges.add_child(plank)
		var start := Grid.cell_center(cells[0], map_size) - run * h + Vector3(0.0, y, 0.0)
		var end := Grid.cell_center(cells[-1], map_size) + run * h + Vector3(0.0, y, 0.0)
		for sgn: float in [-1.0, 1.0]:
			var off := across * sgn * 0.72
			MeshUtil.add_box(wood, start + off - across * 0.07 + Vector3(0.0, -PLANK_T - 0.16, 0.0),
					end + off + across * 0.07 + Vector3(0.0, -PLANK_T, 0.0), STILT_WOOD, STILT_WOOD)
			var a := start + run * 0.15 + across * sgn * 0.85
			var b := end - run * 0.15 + across * sgn * 0.85
			for p in [a, b]:
				MeshUtil.add_box(wood, p - Vector3(0.07, 0.0, 0.07), p + Vector3(0.07, 1.25, 0.07), STILT_WOOD, STILT_WOOD)
			for rope in [[1.15, 0.38], [0.6, 0.22]]:
				var pts := PackedVector3Array()
				for i in 13:
					var t := i / 12.0
					pts.append(a.lerp(b, t) + Vector3(0.0, rope[0] - rope[1] * 4.0 * t * (1.0 - t), 0.0))
				bridges.add_child(LeafwindProps._tube(pts, 0.03, LeafwindProps.ROPE))
				if rope[0] > 1.0:
					for i in range(1, 12):
						var p := pts[i]
						bridges.add_child(Props._rod(p, Vector3(p.x, y + 0.02, p.z), 0.012, LeafwindProps.ROPE))


## Rails along every deck edge you can't walk off: a wooden balustrade on
## the wooden decks, posts and a sagging rope on the leaf deck. Where the
## drop is onto the island (not the sky) an invisible guard stops the
## player too (the sky side already has the island's edge walls).
func _build_rails(root: Node3D) -> void:
	var rails := Node3D.new()
	rails.name = "Rails"
	root.add_child(rails)
	var turn := {Vector2i(1, 0): 0.0, Vector2i(0, -1): 90.0, Vector2i(-1, 0): 180.0, Vector2i(0, 1): -90.0}
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
			if _char(cell) == "^":
				var fence := ModelLib.instance(ModelLib.TOWN + "balcony-wall-fence.glb")
				fence.scale = Vector3(Grid.TILE, 1.0, Grid.TILE)
				fence.rotation_degrees.y = turn[d]
				fence.position = c
				rails.add_child(fence)
			else:
				var along := Vector3(absf(e.z), 0.0, absf(e.x))
				var a := c + e * (h - 0.12) - along * (h - 0.12)
				var b := c + e * (h - 0.12) + along * (h - 0.12)
				for p in [a, b]:
					rails.add_child(Props._rod(p, p + Vector3(0.0, 0.85, 0.0), 0.05, DECK_WOOD))
				var pts := PackedVector3Array()
				for i in 9:
					var t := i / 8.0
					pts.append(a.lerp(b, t) + Vector3(0.0, 0.8 - 0.18 * 4.0 * t * (1.0 - t), 0.0))
				rails.add_child(LeafwindProps._tube(pts, 0.025, LeafwindProps.ROPE))


# ---------------------------------------------------------------- props

func _prop_layout() -> Array[Dictionary]:
	var N := NK
	return [
		# ---- The far cliff on the north edge, with its knot of wind.
		{"type": "wind_cliff", "cell": Vector2i(12, 0), "size": Vector2i(5, 3)},
		{"type": "nature", "model": N + "rock_tallA.glb", "cell": Vector2i(11, 0), "fill": 0.7, "rot": 20.0, "solid": true},
		{"type": "nature", "model": N + "rock_largeB.glb", "cell": Vector2i(17, 0), "fill": 0.8, "rot": -30.0, "solid": true},
		{"type": "nature", "model": N + "grass_large.glb", "cell": Vector2i(10, 2), "fill": 0.6, "rot": 0.0, "solid": false, "max_height": 0.7},
		{"type": "nature", "model": N + "plant_bushSmall.glb", "cell": Vector2i(18, 2), "fill": 0.6, "rot": 40.0, "solid": true},
		# A weathered sign says what the cliff is (Press E to read it).
		{"type": "nature", "model": ModelLib.SURVIVAL + "signpost.glb", "cell": Vector2i(15, 3), "fill": 0.6, "rot": 200.0, "solid": true},
		# ---- Windward Lookout: a quiet corner facing the cliff.
		{"type": "bench", "cell": Vector2i(15, 6), "rot": 90.0},
		{"type": "bench", "cell": Vector2i(11, 6), "rot": 90.0},
		{"type": "lantern", "cell": Vector2i(12, 5)},
		{"type": "banner_pole", "cell": Vector2i(14, 8), "rot": 0.0},
		{"type": "planter", "cell": Vector2i(18, 7), "flower": "flower_purpleA"},
		{"type": "tree", "cell": Vector2i(10, 8), "kind": "round"},
		{"type": "nature", "model": N + "tree_oak.glb", "cell": Vector2i(18, 9), "fill": 0.9, "rot": 30.0, "solid": true, "max_height": 4.6},
		{"type": "flowers", "cell": Vector2i(16, 8), "rot": 50.0},
		{"type": "nature", "model": N + "flower_yellowB.glb", "cell": Vector2i(11, 4), "fill": 0.45, "rot": 10.0, "solid": false, "max_height": 0.7},
		{"type": "mushrooms", "cell": Vector2i(17, 5), "rot": 120.0},
		{"type": "nature", "model": N + "stump_oldTall.glb", "cell": Vector2i(10, 6), "fill": 0.55, "rot": 0.0, "solid": true},
		# ---- North-west pad: the kite hill, with its high deck.
		{"type": "tree", "cell": Vector2i(1, 1), "kind": "round"},
		{"type": "nature", "model": N + "tree_fat.glb", "cell": Vector2i(6, 1), "fill": 0.9, "rot": 0.0, "solid": true, "max_height": 4.4},
		{"type": "rock", "cell": Vector2i(0, 5), "kind": "rock-small", "rot": 70.0},
		{"type": "grass", "cell": Vector2i(3, 2), "rot": 30.0},
		{"type": "flowers_tall", "cell": Vector2i(7, 6)},
		{"type": "nature", "model": N + "plant_bush.glb", "cell": Vector2i(1, 7), "fill": 0.6, "rot": 10.0, "solid": true},
		{"type": "kite_pole", "cell": Vector2i(2, 4), "color": "yellow", "rot": 0.0},
		{"type": "kite_pole", "cell": Vector2i(6, 6), "color": "blue", "rot": 180.0},
		{"type": "kite_pole", "cell": Vector2i(2, 6), "color": "white", "rot": 30.0},
		{"type": "planter", "cell": Vector2i(6, 4), "flower": "flower_redA"},
		{"type": "wind_chime", "cell": Vector2i(6, 7), "rot": 90.0},
		{"type": "lantern", "cell": Vector2i(2, 7)},
		# ---- West terrace: the kite-maker's workshop.
		{"type": "house", "cell": Vector2i(2, 11), "size": Vector2i(2, 2), "wood": true,
			"interior": "res://scenes/interiors/kite_workshop.tscn"},
		{"type": "kite_rack", "cell": Vector2i(5, 11), "rot": 0.0},
		{"type": "planter", "cell": Vector2i(1, 11), "flower": "flower_yellowC"},
		{"type": "planter", "cell": Vector2i(6, 10), "flower": "flower_purpleB"},
		{"type": "lantern", "cell": Vector2i(1, 12)},
		{"type": "crate", "cell": Vector2i(1, 14), "rot": 20.0},
		{"type": "barrel", "cell": Vector2i(1, 15)},
		{"type": "bunting", "cell": Vector2i(4, 15), "size": Vector2i(2, 1)},
		{"type": "banner_pole", "cell": Vector2i(6, 15), "red": true, "rot": 180.0},
		{"type": "wind_chime", "cell": Vector2i(5, 13), "rot": 0.0},
		# Under the terrace: a little nook by the island's edge.
		{"type": "nature", "model": N + "tree_detailed.glb", "cell": Vector2i(0, 11), "fill": 0.9, "rot": 0.0, "solid": true, "max_height": 4.4},
		{"type": "planter", "cell": Vector2i(0, 12), "flower": "flower_redC"},
		{"type": "nature", "model": N + "log_stack.glb", "cell": Vector2i(0, 13), "fill": 0.6, "rot": 90.0, "solid": true},
		# ---- North-east pad: the rope-weaver's corner and the old mill.
		{"type": "windmill", "cell": Vector2i(24, 1), "size": Vector2i(2, 2), "rot": 0.0},
		{"type": "rope_coils", "cell": Vector2i(22, 2), "rot": 15.0},
		{"type": "rope_coils", "cell": Vector2i(22, 6), "rot": -30.0},
		{"type": "hut", "cell": Vector2i(26, 4), "size": Vector2i(1, 1), "red_roof": true, "interior": "res://scenes/interiors/rope_loft.tscn"},
		{"type": "tree", "cell": Vector2i(26, 1), "kind": "pine"},
		{"type": "nature", "model": N + "tree_oak.glb", "cell": Vector2i(22, 0), "fill": 0.9, "rot": 120.0, "solid": true, "max_height": 4.2},
		{"type": "lantern", "cell": Vector2i(25, 6)},
		{"type": "flowers", "cell": Vector2i(26, 6), "rot": 200.0},
		{"type": "crate", "cell": Vector2i(21, 6), "rot": -15.0},
		{"type": "grass", "cell": Vector2i(27, 1), "rot": 80.0},
		# ---- North band (between the pads and the plaza).
		{"type": "nature", "model": N + "tree_fat.glb", "cell": Vector2i(8, 10), "fill": 0.9, "rot": 60.0, "solid": true, "max_height": 4.4},
		{"type": "hut", "cell": Vector2i(10, 11), "size": Vector2i(1, 1), "interior": "res://scenes/interiors/captain_cabin.tscn"},
		{"type": "tree", "cell": Vector2i(15, 10), "kind": "bushy"},
		{"type": "tree", "cell": Vector2i(19, 10), "kind": "round"},
		{"type": "nature", "model": N + "tree_detailed.glb", "cell": Vector2i(26, 11), "fill": 0.9, "rot": 200.0, "solid": true, "max_height": 4.6},
		{"type": "planter", "cell": Vector2i(22, 11), "flower": "flower_yellowA"},
		{"type": "flowers_tall", "cell": Vector2i(11, 10)},
		{"type": "grass", "cell": Vector2i(20, 11), "rot": 10.0},
		# ---- Around the plaza: limp kites, banners, lanterns.
		{"type": "kite_pole", "cell": Vector2i(11, 13), "color": "yellow", "rot": 0.0},
		{"type": "kite_pole", "cell": Vector2i(15, 13), "color": "green", "rot": 200.0},
		{"type": "banner_pole", "cell": Vector2i(9, 17), "rot": 0.0},
		{"type": "banner_pole", "cell": Vector2i(17, 17), "red": true, "rot": 180.0},
		{"type": "lantern", "cell": Vector2i(14, 14)},
		{"type": "lantern", "cell": Vector2i(12, 19)},
		{"type": "planter", "cell": Vector2i(16, 18), "flower": "flower_redB"},
		{"type": "planter", "cell": Vector2i(10, 19), "flower": "flower_purpleC"},
		# ---- East leaf rise: the weather-watcher's lookout and the third mill.
		{"type": "house", "cell": Vector2i(21, 13), "size": Vector2i(2, 2), "red_roof": true,
			"interior": "res://scenes/interiors/lookout.tscn"},
		{"type": "windmill", "cell": Vector2i(24, 13), "size": Vector2i(2, 2), "rot": 0.0},
		{"type": "weathervane", "cell": Vector2i(25, 16)},
		{"type": "planter", "cell": Vector2i(20, 13), "flower": "flower_yellowB"},
		{"type": "wind_chime", "cell": Vector2i(25, 17), "rot": 180.0},
		{"type": "lantern", "cell": Vector2i(20, 17)},
		{"type": "tree", "cell": Vector2i(19, 14), "kind": "bushy"},
		{"type": "tree", "cell": Vector2i(27, 13), "kind": "pine"},
		{"type": "flowers", "cell": Vector2i(18, 13), "rot": 10.0},
		{"type": "lantern", "cell": Vector2i(18, 17)},
		{"type": "nature", "model": N + "plant_bushLarge.glb", "cell": Vector2i(27, 16), "fill": 0.7, "rot": 30.0, "solid": true},
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
		{"type": "house", "cell": Vector2i(17, 20), "size": Vector2i(2, 2), "red_roof": true,
			"interior": "res://scenes/interiors/family_home.tscn"},
		{"type": "planter", "cell": Vector2i(19, 21), "flower": "flower_redA"},
		{"type": "flowers", "cell": Vector2i(16, 20), "rot": 20.0},
		{"type": "wind_chime", "cell": Vector2i(20, 24), "rot": 0.0},
		{"type": "wind_chime", "cell": Vector2i(22, 24), "rot": 120.0},
		{"type": "wind_chime", "cell": Vector2i(21, 26), "rot": 240.0},
		{"type": "hut", "cell": Vector2i(23, 23), "size": Vector2i(1, 1), "red_roof": true, "interior": "res://scenes/interiors/chime_workshop.tscn"},
		{"type": "tree", "cell": Vector2i(25, 20), "kind": "pine"},
		{"type": "tree", "cell": Vector2i(1, 24), "kind": "round"},
		{"type": "nature", "model": N + "tree_oak.glb", "cell": Vector2i(4, 26), "fill": 0.9, "rot": 0.0, "solid": true, "max_height": 4.2},
		{"type": "tree", "cell": Vector2i(8, 26), "kind": "bushy"},
		{"type": "nature", "model": N + "tree_fat.glb", "cell": Vector2i(25, 25), "fill": 0.9, "rot": 90.0, "solid": true, "max_height": 4.4},
		{"type": "tree", "cell": Vector2i(27, 18), "kind": "crooked"},
		{"type": "lantern", "cell": Vector2i(12, 24)},
		{"type": "lantern", "cell": Vector2i(14, 24)},
		{"type": "planter", "cell": Vector2i(11, 26), "flower": "flower_yellowC"},
		{"type": "planter", "cell": Vector2i(15, 26), "flower": "flower_purpleA"},
		{"type": "flowers", "cell": Vector2i(4, 23), "rot": 90.0},
		{"type": "flowers_tall", "cell": Vector2i(18, 25)},
		{"type": "grass", "cell": Vector2i(9, 20), "rot": 45.0},
		{"type": "grass", "cell": Vector2i(22, 19), "rot": 150.0},
		{"type": "mushrooms", "cell": Vector2i(1, 25), "rot": 30.0},
		{"type": "rock", "cell": Vector2i(0, 18), "kind": "rock-wide", "rot": 20.0},
		{"type": "rock", "cell": Vector2i(26, 23), "kind": "rock-small", "rot": 210.0},
		{"type": "nature", "model": N + "plant_bushDetailed.glb", "cell": Vector2i(7, 19), "fill": 0.6, "rot": 0.0, "solid": true},
		{"type": "nature", "model": N + "flower_redB.glb", "cell": Vector2i(19, 23), "fill": 0.45, "rot": 0.0, "solid": false, "max_height": 0.7},
		{"type": "nature", "model": N + "grass_leafsLarge.glb", "cell": Vector2i(5, 21), "fill": 0.6, "rot": 0.0, "solid": false, "max_height": 0.7},
	]


## The sign by the far cliff: stand beside it and press E to read it.
func _after_build() -> void:
	_add_talk_spot(Vector2i(14, 3), Vector2i(15, 3), "gust_point", 1.6)


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
