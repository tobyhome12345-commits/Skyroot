extends Node3D
## Builds an island from a tile map: grass/path top, a stepped rocky
## underside, and floor collision. Everything comes from tile coords.
## This script is Pebblenook; other islands extend it and override the
## layout functions (_map, _prop_layout, _villager_layout, _launch_layout).

## Pebblenook. '#' = grass, '=' = path, '.' = empty sky. 16 x 16 tiles.
const PEBBLENOOK_MAP: Array[String] = [
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

## Which island this is (see data/islands.json).
@export var island_id := "pebblenook"
## Tile the player starts on.
@export var start_cell := Vector2i(7, 8)
@export var player_path: NodePath
## Display only (the title screen's backdrop): built and drawn as normal,
## but it doesn't count as arriving, has no player, and nothing in it
## collides, triggers or reacts.
@export var display_only := false

## Height of the invisible walls around the island edge.
const EDGE_WALL_HEIGHT := 4.0
## Islands may have two levels (Leafwind): level 1 floors are one tile up.
const LEVEL_HEIGHT := Grid.TILE

var map_size := Vector2i(16, 16)
var map: Array[String] = []
## Tiles taken by props (cell -> prop name). Used to stop overlaps.
var occupied := {}
## Tiles that must stay free, e.g. the landing tile (cell -> reason).
var reserved := {}
## The launch point: its edge tile, the way it points (towards the sky) and
## the free landing tile in front of it. Empty cell = no launch point.
## Places where "Press E" shows a line (a bench, a seed...):
## [{"cell": tile the player stands on, "object": tile of the thing, "id": dialogue file}].
var talk_spots: Array[Dictionary] = []
var launch_cell := Vector2i(-1, -1)
var launch_dir := Vector2i.ZERO
var landing_cell := Vector2i(-1, -1)


## The tile map. Override for other islands.
func _map() -> Array[String]:
	return PEBBLENOOK_MAP


## The launch point: {"cell": edge tile, "dir": direction towards the sky,
## "flag": the tile beside it for its flag and signpost}.
func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(15, 8), "dir": Vector2i(1, 0), "flag": Vector2i(15, 9)}


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
		{"type": "tree", "cell": Vector2i(15, 10), "kind": "pine"},
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
	map = _map()
	map_size = Vector2i(map[0].length(), map.size())
	if not display_only:
		Game.arrive_at(island_id)
	_build_ground()
	_build_edge_walls()
	_reserve_extra()
	_place_props()
	_build_doors()
	_build_launch_trigger()
	_place_villagers()
	_after_build()
	_add_distant_views()
	if display_only:
		_make_display_only()
	else:
		_spawn_player()


## Nothing collides or reacts: floors, walls, props, villagers, doors and
## talk spots are switched off; only the look is left.
func _make_display_only() -> void:
	for n in find_children("*", "CollisionObject3D", true, false):
		var co := n as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
		if co is Area3D:
			(co as Area3D).monitoring = false
			(co as Area3D).monitorable = false
		co.process_mode = Node.PROCESS_MODE_DISABLED


## A spot where pressing E reads a line from data/dialogue/<id>.json
## ({"name", "conversations"}), cycling through them. The player stands on
## `stand`; the prompt floats over the thing on `object`.
func _add_talk_spot(stand: Vector2i, object: Vector2i, id: String, prompt_height := 2.0) -> void:
	var trigger := Area3D.new()
	trigger.set_script(preload("res://scripts/door_trigger.gd"))
	trigger.name = "talk_" + id
	trigger.set_meta("cell", stand)
	add_child(trigger)
	var over := Grid.cell_center(object, map_size) - Grid.cell_center(stand, map_size)
	over.y = cell_pos(object).y - cell_pos(stand).y
	trigger.setup(cell_pos(stand), over + Vector3(0, prompt_height, 0), _read_line.bind(id))
	talk_spots.append({"cell": stand, "object": object, "id": id})


func _read_line(id: String) -> void:
	var data := Villager.load_dialogue_lines(id)
	if data.is_empty():
		return
	var convs: Array = data["conversations"]
	var i: int = Game.next_conversation("spot_" + id, convs.size())
	DialogueBox.open(data["name"], convs[i])


## Hooks for islands that build something big before / after the props.
func _reserve_extra() -> void:
	pass


func _after_build() -> void:
	# A new game starts on Pebblenook with the opening lore scene, once.
	if island_id == "pebblenook":
		Intro.maybe_start(self)


## Tiles blocked by something that isn't a prop (e.g. the Great Tree).
func extra_blocked_cells() -> Dictionary:
	return {}


## Every other island, far off in the sky: a low-detail landmark at its
## fixed place in the shared sky (data/sky_map.json), the same place from
## every island. Decoration only (no collision, no shadows).
func _add_distant_views() -> void:
	var sky := Node3D.new()
	sky.name = "DistantViews"
	add_child(sky)
	for id: String in SkyMap.ids():
		if id == island_id:
			continue
		var lm := DistantLandmark.create(id)
		lm.position = SkyMap.offset(id)
		sky.add_child(lm)


## Villagers outside: id (data/dialogue/<id>.json), tile, which way they face.
func _villager_layout() -> Array[Dictionary]:
	return [
		# Fennel tends the trees and plants on the west side.
		{"id": "fennel", "cell": Vector2i(2, 8), "facing": 90.0},
		# Juniper reads the notice board.
		{"id": "juniper", "cell": Vector2i(5, 6), "facing": 0.0},
	]


func _place_villagers() -> void:
	var root := Node3D.new()
	root.name = "Villagers"
	add_child(root)
	for v in _villager_layout():
		var cell: Vector2i = v["cell"]
		if not _claim_footprint(cell, Vector2i.ONE, "villager_" + v["id"]):
			continue
		var villager := Villager.create(v["id"], cell_pos(cell), v.get("facing", 0.0))
		if villager:
			villager.set_meta("cell", cell)
			root.add_child(villager)


func _spawn_player() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		return
	# Coming back out of a house: appear in front of its door.
	# Arriving by glider: appear on the landing tile.
	var spawn := Game.take_spawn()
	var cell: Vector2i = spawn.get("cell", start_cell)
	var facing: float = spawn.get("facing", 0.0)
	if spawn.get("at", "") == "launch" and landing_cell.x >= 0:
		cell = landing_cell
		facing = atan2(-float(launch_dir.x), -float(launch_dir.y))  # facing inland
	if not is_ground(cell) or occupied.has(cell):
		push_error("Player start tile %s is not free ground" % cell)
		return
	player.spawn_at(cell_pos(cell), facing)


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
		door.setup(cell_pos(front), Vector3(0.0, 2.6, -Grid.TILE / 2.0),
				Game.enter_house.bind(p["interior"], front))


## "Press E" on the landing tile in front of the launch point opens the
## destination menu.
func _build_launch_trigger() -> void:
	if landing_cell.x < 0:
		return
	var trigger := Area3D.new()
	trigger.set_script(preload("res://scripts/door_trigger.gd"))
	trigger.name = "LaunchTrigger"
	trigger.set_meta("cell", landing_cell)
	add_child(trigger)
	var to_ramp := Vector3(launch_dir.x, 0.0, launch_dir.y) * Grid.TILE
	trigger.setup(cell_pos(landing_cell), to_ramp + Vector3(0.0, 2.2, 0.0),
			TravelMenu.open.bind(island_id))


## Where cutscenes are staged. "launch": origin on the landing tile, +z
## pointing out over the ramp towards the sky, +y up.
func cutscene_anchor(anchor_name: String) -> Transform3D:
	# "start": the start tile, no turn. "distant_tree": the far-off Great Tree.
	if anchor_name == "start":
		return global_transform * Transform3D(Basis(), cell_pos(start_cell))
	if anchor_name == "distant_tree":
		var far := get_node_or_null("DistantViews/DistantTree") as Node3D
		if far:
			return Transform3D(Basis(), far.global_position)
	# "depart@6.5": the launch frame turned (about the vertical line 6.5 m
	# out over the ramp) to head for the glide's destination in the sky.
	# "arrive@11": the same, turned to come in from the island the glide
	# left. Points on that line don't move, so shots join up seamlessly.
	if anchor_name.begins_with("depart@") or anchor_name.begins_with("arrive@"):
		var out := float(anchor_name.get_slice("@", 1))
		var toward: String = Game.glide_dest if anchor_name.begins_with("depart") else Game.glide_from
		return _glide_anchor(out, toward)
	if anchor_name == "launch" and landing_cell.x >= 0:
		var fwd := Vector3(launch_dir.x, 0.0, launch_dir.y)
		var basis := Basis(fwd.cross(Vector3.UP) * -1.0, Vector3.UP, fwd)
		return global_transform * Transform3D(basis, cell_pos(landing_cell))
	return global_transform


## The launch frame turned about the vertical line `out` metres out along
## it, so its +z heads for `toward_id`'s place in the sky; never more than
## GLIDE_MAX_TURN from straight out, so a glide never doubles back over the
## island.
const GLIDE_MAX_TURN := 90.0


func _glide_anchor(out: float, toward_id: String) -> Transform3D:
	var launch := cutscene_anchor("launch")
	return launch * Transform3D(Basis(Vector3.UP, glide_turn(toward_id)), Vector3(0.0, 0.0, out)) 			* Transform3D(Basis(), Vector3(0.0, 0.0, -out))


## How far (radians, about +y) a glide turns from straight out over the
## launch ramp to head for `toward_id` (clamped to GLIDE_MAX_TURN).
func glide_turn(toward_id: String) -> float:
	var want := SkyMap.heading(toward_id)
	if want == Vector3.ZERO or launch_dir == Vector2i.ZERO:
		return 0.0
	var out := Vector3(launch_dir.x, 0.0, launch_dir.y)
	var angle := out.signed_angle_to(want, Vector3.UP)
	var limit := deg_to_rad(GLIDE_MAX_TURN)
	return clampf(angle, -limit, limit)


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
	return map[cell.y][cell.x] != "."


func is_path(cell: Vector2i) -> bool:
	return is_ground(cell) and map[cell.y][cell.x] == "="


## Solid island (grass, rock and cliffs under it). Bridges are walkable
## ground but not land. Override on islands with bridges.
func is_land(cell: Vector2i) -> bool:
	return is_ground(cell)


func land_cells() -> Array[Vector2i]:
	return ground_cells().filter(func(c: Vector2i) -> bool: return is_land(c))


## Which level a tile's floor is on (0 = the grass, 1 = one tile up).
## Override on islands with raised platforms.
func cell_level(_cell: Vector2i) -> int:
	return 0


## World position (island space) of the middle of a tile's floor.
func cell_pos(cell: Vector2i) -> Vector3:
	return Grid.cell_center(cell, map_size) + Vector3(0.0, float(cell_level(cell)) * LEVEL_HEIGHT, 0.0)


## Tiles nothing may be placed on: paths, and on some islands stairs and
## bridges. Override to add more.
func is_walkway(cell: Vector2i) -> bool:
	return is_path(cell)


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
	var layout := _prop_layout()
	# The launch point goes first, and its landing tile is reserved, so no
	# prop or villager can ever stand on it.
	var launch := _launch_layout()
	if not launch.is_empty():
		launch_cell = launch["cell"]
		launch_dir = launch["dir"]
		landing_cell = launch_cell - launch_dir
		reserved[landing_cell] = "landing tile"
		layout.push_front({"type": "launch", "cell": launch_cell, "dir": launch_dir})
		if launch.has("flag"):
			layout.insert(1, {"type": "launch_flag", "cell": launch["flag"], "dir": launch_dir})
	var index := 0
	for p in layout:
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
		node.position = Grid.footprint_center(cell, size, map_size) + Vector3(0.0, cell_pos(cell).y, 0.0)
		node.set_meta("cell", cell)
		node.set_meta("size", size)
		if p["type"] == "launch":
			# The launch lip hangs out over the edge, towards the sky only.
			node.set_meta("overhang_dir", p["dir"])
			node.set_meta("overhang", Props.LAUNCH_OVERHANG)
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
			if is_walkway(c):
				push_error("%s at %s blocks the path (tile %s)" % [prop_name, cell, c])
				return false
			if cell_level(c) != cell_level(cell):
				push_error("%s at %s spans two levels (tile %s)" % [prop_name, cell, c])
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
	for cell in land_cells():
		for dir: Vector2i in sides:
			if is_land(cell + dir):
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
	if not is_land(cell + along_cell):
		hi -= CORNER_TRIM
	if not is_land(cell - along_cell):
		lo += CORNER_TRIM
	wall.scale.x = (hi - lo) / Grid.TILE
	wall.position += along * ((lo + hi) / 2.0)


## Dirt-and-stone floor tiles from the Modular Cave pack on every path tile,
## turned in 90 degree steps so the pattern doesn't repeat.
func _build_path_tiles() -> void:
	var tiles := Node3D.new()
	tiles.name = "PathTiles"
	add_child(tiles)
	for cell in land_cells():
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
	for cell in land_cells():
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
		if not is_land(cell + Vector2i(-1, 0)):
			lo.x += ROCK_INSET
		if not is_land(cell + Vector2i(1, 0)):
			hi.x -= ROCK_INSET
		if not is_land(cell + Vector2i(0, -1)):
			lo.z += ROCK_INSET
		if not is_land(cell + Vector2i(0, 1)):
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
	for cell in land_cells():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(Grid.TILE, GRASS_THICKNESS, Grid.TILE)
		shape.shape = box
		shape.position = Grid.cell_center(cell, map_size) + Vector3(0.0, -GRASS_THICKNESS / 2.0, 0.0)
		floor_body.add_child(shape)
