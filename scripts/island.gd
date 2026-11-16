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
const GRASS_COLOR := Color(0.49, 0.72, 0.36)
const PATH_COLOR := Color(0.83, 0.71, 0.5)
const DIRT_COLOR := Color(0.55, 0.4, 0.28)
const ROCK_COLOR := Color(0.52, 0.47, 0.45)

## Tile the player starts on.
@export var start_cell := Vector2i(7, 8)
@export var player_path: NodePath

## Height of the invisible walls around the island edge.
const EDGE_WALL_HEIGHT := 4.0

var map_size := Vector2i(16, 16)
## Tiles taken by props (cell -> prop name). Used to stop overlaps.
var occupied := {}


## Every prop on the island: type, top-left tile, footprint in tiles.
func _prop_layout() -> Array[Dictionary]:
	return [
		{"type": "house", "cell": Vector2i(3, 3), "size": Vector2i(2, 2),
			"walls": Color(0.96, 0.89, 0.76), "roof": Color(0.78, 0.38, 0.3)},
		{"type": "house", "cell": Vector2i(11, 3), "size": Vector2i(2, 2),
			"walls": Color(0.93, 0.84, 0.7), "roof": Color(0.4, 0.55, 0.7)},
		{"type": "house", "cell": Vector2i(3, 10), "size": Vector2i(2, 2),
			"walls": Color(0.98, 0.92, 0.82), "roof": Color(0.55, 0.65, 0.4)},
		{"type": "house", "cell": Vector2i(11, 10), "size": Vector2i(2, 2),
			"walls": Color(0.9, 0.82, 0.72), "roof": Color(0.85, 0.6, 0.35)},
		{"type": "well", "cell": Vector2i(9, 8), "size": Vector2i(1, 1)},
		{"type": "notice_board", "cell": Vector2i(6, 6), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(1, 4), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(14, 4), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(1, 9), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(14, 9), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(5, 14), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(10, 14), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(6, 1), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(9, 1), "size": Vector2i(1, 1)},
		{"type": "tree", "cell": Vector2i(13, 7), "size": Vector2i(1, 1)},
	]


func _ready() -> void:
	map_size = Vector2i(MAP[0].length(), MAP.size())
	_build_ground()
	_build_edge_walls()
	_place_props()
	_spawn_player()


func _spawn_player() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		return
	if not is_free(start_cell):
		push_error("Player start tile %s is not free ground" % start_cell)
		return
	player.spawn_at(Grid.cell_center(start_cell, map_size))


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
	var tree_leaves := [Color(0.36, 0.62, 0.33), Color(0.42, 0.68, 0.36), Color(0.5, 0.7, 0.38)]
	var index := 0
	for p in _prop_layout():
		var cell: Vector2i = p["cell"]
		var size: Vector2i = p["size"]
		var prop_name := "%s_%d" % [p["type"], index]
		if not _claim_footprint(cell, size, prop_name):
			continue
		var node: Node3D
		match p["type"]:
			"house":
				node = Props.house(p["walls"], p["roof"])
			"tree":
				node = Props.tree(tree_leaves[index % tree_leaves.size()])
			"well":
				node = Props.well()
			"notice_board":
				node = Props.notice_board()
			_:
				push_error("Unknown prop type: %s" % p["type"])
				continue
		node.name = prop_name
		node.position = Grid.footprint_center(cell, size, map_size)
		props_root.add_child(node)
		index += 1


## Checks the footprint is fully on ground and not shared, then reserves it.
## Stops anything from floating over the edge or clipping into another prop.
func _claim_footprint(cell: Vector2i, size: Vector2i, prop_name: String) -> bool:
	for dz in size.y:
		for dx in size.x:
			var c := cell + Vector2i(dx, dz)
			if not is_ground(c):
				push_error("%s at %s hangs off the island (tile %s)" % [prop_name, cell, c])
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

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Grid.TILE / 2.0
	for cell in ground_cells():
		var c := Grid.cell_center(cell, map_size)
		# Grass / path slab, top surface at y = 0.
		var top_color := PATH_COLOR if is_path(cell) else GRASS_COLOR
		top_color = top_color.darkened(_cell_noise(cell, 1) * 0.06)
		var side_color := DIRT_COLOR
		MeshUtil.add_box(st, Vector3(c.x - half, -GRASS_THICKNESS, c.z - half),
				Vector3(c.x + half, 0.0, c.z + half), top_color, side_color)
		# Rock column hanging below. Deeper towards the middle, in whole tiles.
		var depth_tiles := _edge_distance(cell) + int(_cell_noise(cell, 2) * 2.0)
		var bottom := -GRASS_THICKNESS - float(depth_tiles) * Grid.TILE
		var rock := ROCK_COLOR.darkened(_cell_noise(cell, 3) * 0.15)
		MeshUtil.add_box(st, Vector3(c.x - half, bottom, c.z - half),
				Vector3(c.x + half, -GRASS_THICKNESS, c.z + half), rock, rock)
	st.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Ground"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = MeshUtil.vertex_color_material()
	add_child(mesh_instance)

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
