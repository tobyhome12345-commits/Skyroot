extends Node3D
## Builds the Pebblenook island from a tile map: grass/path top, a stepped
## rocky underside, and floor collision. Everything comes from tile coords.

## '#' = grass, '=' = path, '.' = empty sky. 16 x 16 tiles.
const MAP: Array[String] = [
	"...##########...",
	"..############..",
	".##############.",
	"################",
	"################",
	"###==========###",
	"#######==#######",
	"#######==#######",
	"#######==#######",
	"#######==#######",
	"#######==#######",
	"#######==#######",
	"###==========###",
	".##############.",
	"..############..",
	"...##########...",
]

const GRASS_THICKNESS := 0.5
## Path tiles (Modular Cave dirt floor) sit flush on the ground at y = 0, like
## every model. The ground mesh under them is recessed this much so the two
## surfaces never overlap (no flicker).
const PATH_DEPTH := 0.05
const PATH_TILE_SCALE := 0.5  # cave floor tiles are 4 m; half size = 1 tile
## Height of the Modular Cave "template-wall-half" cliff pieces.
const CLIFF_HEIGHT := 4.05
## How far the rock under the island sits behind the cliff faces on the rim.
const ROCK_INSET := 0.03
## How much cliff pieces are shortened at outer corners. Must differ from
## ROCK_INSET, or the cliff's end would share a plane with the rock.
const CORNER_TRIM := 0.05
const GRASS_COLOR := Color(0.49, 0.72, 0.36)
const PATH_COLOR := Color(0.83, 0.71, 0.5)
const DIRT_COLOR := Color(0.72, 0.46, 0.32)
const ROCK_COLOR := Color(0.6, 0.6, 0.76)

## Tile the player starts on.
@export var start_cell := Vector2i(7, 8)
@export var player_path: NodePath

## Height of the invisible walls around the island edge.
const EDGE_WALL_HEIGHT := 4.0

var map_size := Vector2i(16, 16)
## Tiles taken by props (cell -> prop name). Used to stop overlaps.
var occupied := {}


## Every prop on the island: type, top-left tile, footprint in tiles (size
## defaults to 1 x 1), plus options for the builder in props.gd.
func _prop_layout() -> Array[Dictionary]:
	return [
		# Houses: 2 x 2 tiles, doors face the path in front of them.
		# Each house leads to its own interior scene.
		{"type": "house", "cell": Vector2i(3, 3), "size": Vector2i(2, 2), "red_roof": true,
			"interior": "res://scenes/interiors/elder_home.tscn"},
		{"type": "house", "cell": Vector2i(11, 3), "size": Vector2i(2, 2), "wood": true,
			"interior": "res://scenes/interiors/bedroom.tscn"},
		{"type": "house", "cell": Vector2i(3, 10), "size": Vector2i(2, 2), "wood": true,
			"interior": "res://scenes/interiors/workshop.tscn"},
		{"type": "house", "cell": Vector2i(11, 10), "size": Vector2i(2, 2), "red_roof": true,
			"interior": "res://scenes/interiors/library.tscn"},
		{"type": "well", "cell": Vector2i(9, 8)},
		{"type": "notice_board", "cell": Vector2i(6, 6)},
		{"type": "tree", "cell": Vector2i(1, 4), "kind": "pine"},
		{"type": "tree", "cell": Vector2i(14, 4), "kind": "round"},
		{"type": "tree", "cell": Vector2i(1, 9), "kind": "bushy"},
		{"type": "tree", "cell": Vector2i(14, 9), "kind": "pine"},
		{"type": "tree", "cell": Vector2i(5, 14), "kind": "round"},
		{"type": "tree", "cell": Vector2i(10, 14), "kind": "bushy"},
		{"type": "tree", "cell": Vector2i(6, 1), "kind": "crooked"},
		{"type": "tree", "cell": Vector2i(9, 1), "kind": "pine"},
		{"type": "tree", "cell": Vector2i(13, 7), "kind": "bushy"},
		# Fence along the back (north) edge.
		{"type": "fence", "cell": Vector2i(3, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(4, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(5, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(6, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(7, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(8, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(9, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(10, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(11, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(12, 0), "side": "north"},
		# Lanterns beside the paths.
		{"type": "lantern", "cell": Vector2i(6, 4)},
		{"type": "lantern", "cell": Vector2i(9, 4)},
		{"type": "lantern", "cell": Vector2i(6, 11)},
		{"type": "lantern", "cell": Vector2i(9, 11)},
		# Little gardens beside each house.
		{"type": "flowers_tall", "cell": Vector2i(2, 3)},
		{"type": "plant", "cell": Vector2i(2, 4)},
		{"type": "barrel", "cell": Vector2i(5, 3)},
		{"type": "flowers", "cell": Vector2i(5, 4)},
		{"type": "crate", "cell": Vector2i(10, 3), "rot": 15.0},
		{"type": "flowers", "cell": Vector2i(10, 4), "rot": 90.0},
		{"type": "flowers_tall", "cell": Vector2i(13, 3), "rot": 45.0},
		{"type": "plant", "cell": Vector2i(13, 4), "rot": 90.0},
		{"type": "plant", "cell": Vector2i(2, 10), "rot": 180.0},
		{"type": "flowers_tall", "cell": Vector2i(2, 11), "rot": 120.0},
		{"type": "barrel", "cell": Vector2i(5, 10)},
		{"type": "flowers", "cell": Vector2i(5, 11), "rot": 45.0},
		{"type": "plant", "cell": Vector2i(10, 10), "rot": 45.0},
		{"type": "flowers_tall", "cell": Vector2i(10, 11), "rot": 200.0},
		{"type": "crate", "cell": Vector2i(13, 10), "rot": -20.0},
		{"type": "flowers", "cell": Vector2i(13, 11), "rot": 135.0},
		# Bits of nature around the edges.
		{"type": "rock", "cell": Vector2i(2, 7), "kind": "rock-small", "rot": 30.0},
		{"type": "rock", "cell": Vector2i(14, 12), "kind": "rock-wide", "rot": -40.0},
		{"type": "rock", "cell": Vector2i(12, 1), "kind": "rock-small", "rot": 160.0},
		{"type": "grass", "cell": Vector2i(4, 7)},
		{"type": "grass", "cell": Vector2i(11, 8), "rot": 70.0},
		{"type": "grass", "cell": Vector2i(8, 14), "rot": 140.0},
		{"type": "grass", "cell": Vector2i(4, 1), "rot": 20.0},
		{"type": "mushrooms", "cell": Vector2i(12, 14)},
		{"type": "mushrooms", "cell": Vector2i(3, 13), "rot": 90.0},
		{"type": "cart", "cell": Vector2i(14, 6), "rot": 90.0},
	]


func _ready() -> void:
	map_size = Vector2i(MAP[0].length(), MAP.size())
	_build_ground()
	_build_edge_walls()
	_place_props()
	_build_doors()
	_spawn_player()


func _spawn_player() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		return
	# Coming back out of a house: appear in front of its door.
	var spawn := Game.take_spawn()
	var cell: Vector2i = spawn.get("cell", start_cell)
	if not is_ground(cell) or occupied.has(cell):
		push_error("Player start tile %s is not free ground" % cell)
		return
	player.spawn_at(Grid.cell_center(cell, map_size), spawn.get("facing", 0.0))


## The tile in front of a house's door (the door is in its front-left module).
func door_front_cell(house_cell: Vector2i, house_size: Vector2i) -> Vector2i:
	return house_cell + Vector2i(0, house_size.y)


## A door trigger on the tile in front of every house door.
func _build_doors() -> void:
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)
	for p in _prop_layout():
		if not p.has("interior"):
			continue
		var front := door_front_cell(p["cell"], p["size"])
		var door := Area3D.new()
		door.set_script(preload("res://scripts/door_trigger.gd"))
		door.name = "door_%d_%d" % [front.x, front.y]
		door.set_meta("cell", front)
		door.set_meta("interior", p["interior"])
		doors.add_child(door)
		# Prompt floats above the door, which is on the tile edge behind.
		door.setup(Grid.cell_center(front, map_size), Vector3(0.0, 2.6, -Grid.TILE / 2.0),
				Game.enter_house.bind(p["interior"], front))


## Invisible walls on every empty tile that touches the island, so the
## player can never walk off the edge.
func _build_edge_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "EdgeWalls"
	add_child(body)
	for z in range(-1, map_size.y + 1):
		for x in range(-1, map_size.x + 1):
			var cell := Vector2i(x, z)
			if is_ground(cell) or not _touches_ground(cell):
				continue
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(Grid.TILE, EDGE_WALL_HEIGHT, Grid.TILE)
			shape.shape = box
			shape.position = Grid.cell_center(cell, map_size) + Vector3(0.0, EDGE_WALL_HEIGHT / 2.0, 0.0)
			body.add_child(shape)


func _touches_ground(cell: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if is_ground(cell + Vector2i(dx, dz)):
				return true
	return false


# ---------------------------------------------------------------- map helpers

func is_ground(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return false
	return MAP[cell.y][cell.x] != "."


func is_path(cell: Vector2i) -> bool:
	return is_ground(cell) and MAP[cell.y][cell.x] == "="


func ground_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in map_size.y:
		for x in map_size.x:
			if is_ground(Vector2i(x, z)):
				cells.append(Vector2i(x, z))
	return cells


## Distance (in tiles) from a ground cell to the nearest empty cell.
func _edge_distance(cell: Vector2i) -> int:
	for d in range(1, 9):
		for dz in range(-d, d + 1):
			for dx in range(-d, d + 1):
				if not is_ground(cell + Vector2i(dx, dz)):
					return d
	return 9


## Small stable per-cell random number in 0..1 (same every run).
func _cell_noise(cell: Vector2i, salt: int) -> float:
	var h := hash(Vector3i(cell.x, cell.y, salt))
	return float(h % 1000) / 1000.0


# ---------------------------------------------------------------- props

func _place_props() -> void:
	var props_root := Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	var index := 0
	for p in _prop_layout():
		var cell: Vector2i = p["cell"]
		var size: Vector2i = p.get("size", Vector2i.ONE)
		var prop_name := "%s_%d" % [p["type"], index]
		index += 1
		if not _claim_footprint(cell, size, prop_name):
			continue
		var node := Props.build(p)
		if node == null:
			continue
		node.name = prop_name
		node.position = Grid.footprint_center(cell, size, map_size)
		node.set_meta("cell", cell)
		node.set_meta("size", size)
		props_root.add_child(node)


## Checks the footprint is fully on ground and not shared, then reserves it.
## Stops anything from floating over the edge or clipping into another prop.
func _claim_footprint(cell: Vector2i, size: Vector2i, prop_name: String) -> bool:
	for dz in size.y:
		for dx in size.x:
			var c := cell + Vector2i(dx, dz)
			if not is_ground(c):
				push_error("%s at %s hangs off the island (tile %s)" % [prop_name, cell, c])
				return false
			if is_path(c):
				push_error("%s at %s blocks the path (tile %s)" % [prop_name, cell, c])
				return false
			if occupied.has(c):
				push_error("%s at %s overlaps %s (tile %s)" % [prop_name, cell, occupied[c], c])
				return false
	for dz in size.y:
		for dx in size.x:
			occupied[cell + Vector2i(dx, dz)] = prop_name
	return true


func is_free(cell: Vector2i) -> bool:
	return is_ground(cell) and not occupied.has(cell)


# ---------------------------------------------------------------- ground

## Carved rock cliff walls (Modular Cave pack) along every outer edge of the
## island, just under the grass and dirt layer. Each piece is exactly one
## tile wide; its face sits on the tile edge and its body reaches inwards,
## hidden inside the island's rock.
func _build_cliffs() -> void:
	var cliffs := Node3D.new()
	cliffs.name = "Cliffs"
	add_child(cliffs)
	var stone_atlas := load(ModelLib.CAVE_ATLAS) as Texture2D
	var sides := {
		Vector2i(0, 1): 0.0,     # south: face +z
		Vector2i(1, 0): 90.0,    # east:  face +x
		Vector2i(0, -1): 180.0,  # north: face -z
		Vector2i(-1, 0): -90.0,  # west:  face -x
	}
	for cell in ground_cells():
		for dir: Vector2i in sides:
			if is_ground(cell + dir):
				continue
			var edge := Vector3(dir.x, 0.0, dir.y) * (Grid.TILE / 2.0)
			var pos := Grid.cell_center(cell, map_size) + edge + Vector3(0.0, -GRASS_THICKNESS - CLIFF_HEIGHT, 0.0)
			var wall := ModelLib.piece(ModelLib.CAVE + "template-wall-half.glb", 1.0, pos, sides[dir])
			wall.name = "cliff_%d_%d_%d_%d" % [cell.x, cell.y, dir.x, dir.y]
			_trim_corner_ends(wall, cell, dir)
			ModelLib.set_atlas(wall, stone_atlas)
			cliffs.add_child(wall)


## On an outer corner two cliffs meet at a right angle, and the end of one
## would lie in the same plane as the face of the other (flicker). Trim the
## piece by CORNER_TRIM at any end that sits on an outer corner.
func _trim_corner_ends(wall: Node3D, cell: Vector2i, dir: Vector2i) -> void:
	# The piece runs along its local x axis from -1 to +1 (one tile).
	var along := wall.basis.x.normalized()
	var along_cell := Vector2i(roundi(along.x), roundi(along.z))
	var lo := -Grid.TILE / 2.0
	var hi := Grid.TILE / 2.0
	if not is_ground(cell + along_cell):
		hi -= CORNER_TRIM
	if not is_ground(cell - along_cell):
		lo += CORNER_TRIM
	wall.scale.x = (hi - lo) / Grid.TILE
	wall.position += along * ((lo + hi) / 2.0)


## Dirt-and-stone floor tiles from the Modular Cave pack on every path tile,
## turned in 90 degree steps so the pattern doesn't repeat.
func _build_path_tiles() -> void:
	var tiles := Node3D.new()
	tiles.name = "PathTiles"
	add_child(tiles)
	for cell in ground_cells():
		if not is_path(cell):
			continue
		var rot := 90.0 * float(int(_cell_noise(cell, 4) * 4.0))
		var pos := Grid.cell_center(cell, map_size)
		var tile := ModelLib.piece(ModelLib.CAVE + "template-floor-detail.glb", PATH_TILE_SCALE, pos, rot)
		tile.name = "path_%d_%d" % [cell.x, cell.y]
		tile.set_meta("cell", cell)
		tiles.add_child(tile)


func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Grid.TILE / 2.0
	for cell in ground_cells():
		var c := Grid.cell_center(cell, map_size)
		# Grass slab, top surface at y = 0 (path tiles: recessed, tile on top).
		var top_color := PATH_COLOR if is_path(cell) else GRASS_COLOR
		top_color = top_color.darkened(_cell_noise(cell, 1) * 0.06)
		var side_color := DIRT_COLOR
		var top := -PATH_DEPTH if is_path(cell) else 0.0
		# No bottom face: the rock column always sits right under it.
		MeshUtil.add_box(st, Vector3(c.x - half, -GRASS_THICKNESS, c.z - half),
				Vector3(c.x + half, top, c.z + half), top_color, side_color, true, false)
		# Rock column hanging below. Deeper towards the middle, in whole tiles.
		# At least 2 tiles deep so the 4 m cliff walls on the rim have rock behind them.
		var depth_tiles := maxi(2, _edge_distance(cell) + int(_cell_noise(cell, 2) * 2.0))
		var bottom := -GRASS_THICKNESS - float(depth_tiles) * Grid.TILE
		var rock := ROCK_COLOR.darkened(_cell_noise(cell, 3) * 0.15)
		# On outer edges the rock sits ROCK_INSET behind the cliff walls, so the
		# two surfaces never share a plane (that would flicker / z-fight).
		var lo := Vector3(c.x - half, bottom, c.z - half)
		var hi := Vector3(c.x + half, -GRASS_THICKNESS, c.z + half)
		if not is_ground(cell + Vector2i(-1, 0)):
			lo.x += ROCK_INSET
		if not is_ground(cell + Vector2i(1, 0)):
			hi.x -= ROCK_INSET
		if not is_ground(cell + Vector2i(0, -1)):
			lo.z += ROCK_INSET
		if not is_ground(cell + Vector2i(0, 1)):
			hi.z -= ROCK_INSET
		# No top face: the grass slab sits exactly on it, so it can't be seen
		# and would only double up with the cliff tops at the same height.
		MeshUtil.add_box(st, lo, hi, rock, rock, false)
	st.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Ground"
	mesh_instance.mesh = st.commit()
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = preload("res://shaders/island_ground.gdshader")
	ground_mat.set_shader_parameter("detail_tex", ModelLib.stone_texture())
	mesh_instance.material_override = ground_mat
	add_child(mesh_instance)
	_build_path_tiles()
	_build_cliffs()

	# Floor collision: one box per ground tile.
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorBody"
	add_child(floor_body)
	for cell in ground_cells():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(Grid.TILE, GRASS_THICKNESS, Grid.TILE)
		shape.shape = box
		shape.position = Grid.cell_center(cell, map_size) + Vector3(0.0, -GRASS_THICKNESS / 2.0, 0.0)
		floor_body.add_child(shape)
