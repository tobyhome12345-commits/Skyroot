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

var map_size := Vector2i(16, 16)


func _ready() -> void:
	map_size = Vector2i(MAP[0].length(), MAP.size())
	_build_ground()


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
