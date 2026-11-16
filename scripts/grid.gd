class_name Grid
## Shared grid rules. Every wall, floor and object is placed by whole tile
## coordinates (Vector2i). World positions are always computed from these,
## never typed in by hand.

## Size of one tile in world units (metres).
const TILE := 2.0


## World position of the centre of a footprint that starts at `cell` and is
## `size` tiles big. The island is centred on the world origin.
static func footprint_center(cell: Vector2i, size: Vector2i, map_size: Vector2i) -> Vector3:
	var x := (float(cell.x) + float(size.x) / 2.0 - float(map_size.x) / 2.0) * TILE
	var z := (float(cell.y) + float(size.y) / 2.0 - float(map_size.y) / 2.0) * TILE
	return Vector3(x, 0.0, z)


## World position of the centre of a single tile.
static func cell_center(cell: Vector2i, map_size: Vector2i) -> Vector3:
	return footprint_center(cell, Vector2i.ONE, map_size)


## Which tile a world position falls in.
static func world_to_cell(pos: Vector3, map_size: Vector2i) -> Vector2i:
	return Vector2i(
		floori(pos.x / TILE + float(map_size.x) / 2.0),
		floori(pos.z / TILE + float(map_size.y) / 2.0))
