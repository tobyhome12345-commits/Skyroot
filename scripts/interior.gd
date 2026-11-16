extends Node3D
## A house interior: an 8 x 8 tile room on the same grid as the island.
## Cutaway view: back and side walls only, no front wall or ceiling.
## Furniture comes from the Kenney packs (see Assets/CREDITS.md); every
## object snaps to whole tiles, one object per tile, flush on the floor.
## The exit door is on the front edge; the player enters on the tile behind it.

const ROOM_SIZE := Vector2i(8, 8)
const EXIT_CELL := Vector2i(3, 7)
const ENTRANCE_CELL := Vector2i(3, 6)
## Interior walls are Town modules stretched up to this height (m).
const WALL_HEIGHT := 2.8
## Furniture is drawn 1.25x its pack scale indoors so each piece fills its
## tile (a bed spans 1 x 2 tiles, a desk 1 tile) and the room feels lived-in.
const INTERIOR_SCALE := 1.25
## Furniture against a wall keeps this far (m) from the tile edge, which
## clears the wall and its window shutters.
const WALL_CLEARANCE := 0.4
const FLOOR_THICKNESS := 0.1
## Gap kept between items standing next to each other inside one object.
const PART_GAP := 0.05

@export_enum("elder", "bedroom", "workshop", "library") var room := "elder"
@export var player_path: NodePath

## Tiles taken by objects (cell -> object name).
var occupied := {}
var map_size := ROOM_SIZE


func _ready() -> void:
	var data: Dictionary = _rooms()[room]
	_build_environment(data)
	_build_floor()
	_build_walls(data)
	_build_exit()
	_build_objects(data)
	_spawn_player()


# ---------------------------------------------------------------- rooms

## The four rooms. Object fields:
##   id      model ("F:" Furniture Kit, "S:" Survival, "T:" Town, "P:" Platformer)
##   cell    top-left tile, size: footprint in tiles (default 1 x 1)
##   rot     yaw in degrees (Furniture Kit models face +z, towards the camera)
##   against "north" / "west" / "east": pushed back against that wall
##   top     small items standing on the object's top: [id, Vector2 offset m, rot]
##   parts   extra items on the floor next to it: [id, Vector2 offset m, rot]
##   flat    rugs: walkable, no collider
##   light   adds a warm lamp light at the top of the object
func _rooms() -> Dictionary:
	return {
		# 1. The elder's home: cozy living room and kitchen.
		"elder": {
			"wall": "wall", "windows": [Vector2i(5, 0), Vector2i(0, 2), Vector2i(7, 1)],
			"objects": [
				{"id": "F:kitchenFridge", "cell": Vector2i(0, 0), "against": "north"},
				{"id": "F:kitchenCabinet", "cell": Vector2i(1, 0), "against": "north",
					"top": [["F:kitchenCoffeeMachine", Vector2(0.15, 0.0), 0.0]]},
				{"id": "F:kitchenStove", "cell": Vector2i(2, 0), "against": "north"},
				{"id": "F:kitchenSink", "cell": Vector2i(3, 0), "against": "north"},
				{"id": "F:kitchenCabinet", "cell": Vector2i(4, 0), "against": "north",
					"top": [["F:toaster", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:bookcaseOpen", "cell": Vector2i(6, 0), "against": "north",
					"top": [["F:books", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:sideTableDrawers", "cell": Vector2i(5, 0), "against": "north",
					"top": [["F:radio", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:pottedPlant", "cell": Vector2i(7, 0), "against": "north"},
				{"id": "F:pottedPlant", "cell": Vector2i(0, 1), "against": "west"},
				{"id": "F:rugRound", "cell": Vector2i(1, 4), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:lampRoundFloor", "cell": Vector2i(7, 2), "against": "east", "light": true},
				{"id": "F:table", "cell": Vector2i(1, 2), "size": Vector2i(2, 1),
					"top": [["F:plantSmall1", Vector2(0.0, 0.0), 0.0]],
					"parts": [["F:chair", Vector2(-1.4, 0.0), 90.0], ["F:chair", Vector2(1.4, 0.0), -90.0]]},
				{"id": "F:rugRectangle", "cell": Vector2i(3, 3), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:loungeChair", "cell": Vector2i(5, 3), "rot": 90.0},
				{"id": "F:tableCoffee", "cell": Vector2i(6, 3), "size": Vector2i(1, 2), "rot": 90.0,
					"top": [["F:books", Vector2(0.0, -0.3), 30.0]]},
				{"id": "F:loungeSofa", "cell": Vector2i(7, 3), "size": Vector2i(1, 2), "rot": -90.0, "against": "east"},
				{"id": "F:sideTable", "cell": Vector2i(0, 4), "rot": 90.0, "against": "west",
					"top": [["F:lampRoundTable", Vector2(0.0, 0.0), 0.0]], "light": true},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 6)},
			],
		},
		# 2. A young villager's bedroom.
		"bedroom": {
			"wall": "wall-wood", "windows": [Vector2i(4, 0), Vector2i(7, 4)],
			"objects": [
				{"id": "F:bedSingle", "cell": Vector2i(0, 0), "size": Vector2i(1, 2), "against": "north"},
				{"id": "F:cabinetBed", "cell": Vector2i(1, 0), "against": "north",
					"top": [["F:lampSquareTable", Vector2(0.0, 0.0), 0.0]], "light": true},
				{"id": "F:desk", "cell": Vector2i(3, 0), "against": "north",
					"top": [["F:laptop", Vector2(-0.25, 0.0), 0.0], ["F:books", Vector2(0.45, 0.05), -15.0]]},
				{"id": "F:chairDesk", "cell": Vector2i(3, 1), "rot": 180.0},
				{"id": "F:bookcaseOpen", "cell": Vector2i(5, 0), "against": "north",
					"top": [["F:books", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:bookcaseClosedDoors", "cell": Vector2i(6, 0), "against": "north"},
				{"id": "F:bookcaseClosedDoors", "cell": Vector2i(7, 0), "against": "north"},
				{"id": "F:sideTable", "cell": Vector2i(0, 4), "rot": 90.0, "against": "west",
					"top": [["F:plantSmall1", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:lampRoundFloor", "cell": Vector2i(7, 5), "against": "east", "light": true},
				{"id": "F:bear", "cell": Vector2i(0, 2), "rot": 90.0, "against": "west"},
				{"id": "F:rugRound", "cell": Vector2i(3, 3), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:bookcaseOpenLow", "cell": Vector2i(7, 2), "rot": -90.0, "against": "east",
					"top": [["F:radio", Vector2(0.0, 0.0), -90.0]]},
				{"id": "F:plantSmall2", "cell": Vector2i(7, 3), "against": "east"},
				{"id": "F:cardboardBoxClosed", "cell": Vector2i(7, 6)},
			],
		},
		# 3. The tinkerer's workshop.
		"workshop": {
			"wall": "wall-wood", "windows": [Vector2i(3, 0), Vector2i(0, 3)],
			"objects": [
				{"id": "F:lampSquareFloor", "cell": Vector2i(0, 0), "against": "north", "light": true},
				{"id": "S:workbench", "cell": Vector2i(1, 0), "against": "north",
					"top": [["S:tool-hammer", Vector2(0.0, 0.0), 30.0]]},
				{"id": "S:workbench-anvil", "cell": Vector2i(2, 0), "against": "north"},
				{"id": "S:workbench-grind", "cell": Vector2i(4, 0), "against": "north"},
				{"id": "S:workbench", "cell": Vector2i(5, 0), "against": "north",
					"top": [["S:tool-shovel", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:bookcaseOpenLow", "cell": Vector2i(0, 3), "rot": 90.0, "against": "west",
					"top": [["S:bottle", Vector2(0.0, 0.0), 0.0]]},
				{"id": "S:barrel", "cell": Vector2i(1, 6)},
				{"id": "F:lampSquareFloor", "cell": Vector2i(7, 3), "against": "east", "light": true},
				{"id": "F:bookcaseOpen", "cell": Vector2i(6, 0), "against": "north",
					"top": [["S:box", Vector2(0.0, 0.0), 10.0]]},
				{"id": "F:bookcaseOpen", "cell": Vector2i(7, 0), "against": "north",
					"top": [["S:bucket", Vector2(0.0, 0.0), 0.0]]},
				{"id": "S:chest", "cell": Vector2i(0, 2), "rot": 90.0, "against": "west"},
				{"id": "F:table", "cell": Vector2i(3, 3), "size": Vector2i(2, 1),
					"top": [["S:tool-axe", Vector2(-0.45, 0.0), 0.0], ["S:tool-pickaxe", Vector2(0.4, 0.0), 0.0]]},
				{"id": "S:barrel", "cell": Vector2i(0, 5)},
				{"id": "S:barrel-open", "cell": Vector2i(0, 6)},
				{"id": "S:box-large", "cell": Vector2i(7, 5)},
				{"id": "S:box", "cell": Vector2i(7, 6), "rot": 20.0},
				{"id": "F:pottedPlant", "cell": Vector2i(7, 2), "against": "east"},
				{"id": "S:box", "cell": Vector2i(6, 6), "rot": -15.0},
			],
		},
		# 4. A study / library with a fireplace.
		"library": {
			"wall": "wall", "windows": [Vector2i(0, 3), Vector2i(7, 1)],
			"objects": [
				{"id": "F:bookcaseClosed", "cell": Vector2i(0, 0), "against": "north"},
				{"id": "F:bookcaseOpen", "cell": Vector2i(1, 0), "against": "north",
					"top": [["F:books", Vector2(0.0, 0.0), 0.0]]},
				{"type": "fireplace", "cell": Vector2i(3, 0), "size": Vector2i(2, 1)},
				{"id": "F:bookcaseOpen", "cell": Vector2i(6, 0), "against": "north",
					"top": [["F:books", Vector2(0.0, 0.0), 20.0]]},
				{"id": "F:bookcaseClosed", "cell": Vector2i(7, 0), "against": "north"},
				{"id": "F:bookcaseOpen", "cell": Vector2i(0, 1), "rot": 90.0, "against": "west",
					"top": [["F:books", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:bookcaseOpenLow", "cell": Vector2i(0, 2), "rot": 90.0, "against": "west",
					"top": [["F:plantSmall3", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:sideTable", "cell": Vector2i(1, 4), "rot": 90.0,
					"top": [["F:books", Vector2(0.0, 0.0), 45.0]]},
				{"id": "F:pottedPlant", "cell": Vector2i(2, 0), "against": "north"},
				{"id": "F:bookcaseOpen", "cell": Vector2i(7, 2), "rot": -90.0, "against": "east",
					"top": [["F:books", Vector2(0.0, 0.0), 0.0]]},
				{"id": "F:loungeChair", "cell": Vector2i(0, 4), "rot": 90.0, "against": "west"},
				{"id": "F:lampRoundFloor", "cell": Vector2i(0, 5), "light": true},
				{"id": "F:rugRectangle", "cell": Vector2i(2, 3), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:desk", "cell": Vector2i(7, 3), "rot": -90.0, "against": "east",
					"top": [["F:lampSquareTable", Vector2(0.0, -0.4), 0.0], ["F:books", Vector2(0.0, 0.35), 90.0]], "light": true},
				{"id": "F:chairDesk", "cell": Vector2i(6, 3), "rot": 90.0},
				{"id": "F:pottedPlant", "cell": Vector2i(7, 6)},
			],
		},
	}


# ---------------------------------------------------------------- grid

func cell_center(cell: Vector2i) -> Vector3:
	return Grid.cell_center(cell, ROOM_SIZE)


func in_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < ROOM_SIZE.x and cell.y < ROOM_SIZE.y


func room_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in ROOM_SIZE.y:
		for x in ROOM_SIZE.x:
			cells.append(Vector2i(x, z))
	return cells


# ---------------------------------------------------------------- building

func _build_environment(_data: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.065, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.82, 0.62)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Warm main light above the middle of the room, plus a soft fill.
	var main := OmniLight3D.new()
	main.name = "RoomLight"
	main.light_color = Color(1.0, 0.8, 0.58)
	main.light_energy = 2.2
	main.omni_range = 18.0
	main.omni_attenuation = 0.8
	main.shadow_enabled = true
	main.position = cell_center(Vector2i(4, 3)) + Vector3(-1.0, 6.0, 1.0)
	add_child(main)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(1.0, 0.86, 0.7)
	fill.light_energy = 0.35
	fill.shadow_enabled = true
	fill.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	add_child(fill)


## Board floor, one tile at a time, top flush at y = 0: Fantasy Town Kit
## plank boards laid over a Furniture Kit floor tile (darkened), so the gaps
## between the boards read as seams. Boards alternate direction per row.
func _build_floor() -> void:
	var floor_root := Node3D.new()
	floor_root.name = "Floor"
	add_child(floor_root)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.36, 0.22, 0.14)
	dark.roughness = 0.9
	for cell in room_cells():
		var centre := cell_center(cell)
		var boards := ModelLib.piece(ModelLib.TOWN + "planks.glb", ModelLib.TOWN_SCALE, centre, 0.0)
		var board_h := ModelUtil.local_aabb(boards).size.y * ModelLib.TOWN_SCALE
		boards.position.y = -board_h
		boards.name = "boards_%d_%d" % [cell.x, cell.y]
		floor_root.add_child(boards)
		var base: Array = ModelLib.placed("F:floorFull")
		var base_node: Node3D = base[0]
		base_node.position = centre + Vector3(0.0, -board_h - (base[1] as Vector3).y, 0.0)
		for mi in base_node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = dark
		base_node.name = "floor_%d_%d" % [cell.x, cell.y]
		base_node.set_meta("cell", cell)
		floor_root.add_child(base_node)
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(ROOM_SIZE.x * Grid.TILE, 0.5, ROOM_SIZE.y * Grid.TILE)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, -0.25, 0.0)
	body.add_child(cs)


## Back (north) and side walls from Fantasy Town Kit modules, one per tile
## edge; the front edge is open (cutaway) but blocked by an invisible wall.
func _build_walls(data: Dictionary) -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var wall: String = data["wall"]
	var windows: Array = data.get("windows", [])
	var sides := {"north": [Vector2i(0, -1), 90.0], "west": [Vector2i(-1, 0), 180.0], "east": [Vector2i(1, 0), 0.0]}
	for cell in room_cells():
		for side: String in sides:
			var d: Vector2i = sides[side][0]
			if in_room(cell + d):
				continue
			var kind := wall + ("-window-shutters" if cell in windows else "")
			var piece := ModelLib.piece(ModelLib.TOWN + kind + ".glb", ModelLib.TOWN_SCALE, cell_center(cell), sides[side][1])
			piece.scale.y = WALL_HEIGHT  # Town modules are 1 unit tall
			piece.name = "wall_%s_%d_%d" % [side, cell.x, cell.y]
			walls.add_child(piece)
	# Collision: a slab along each wall (covers the window shutters), and an
	# invisible one along the open front edge.
	var body := StaticBody3D.new()
	body.name = "WallBody"
	add_child(body)
	var w := ROOM_SIZE.x * Grid.TILE
	var d := ROOM_SIZE.y * Grid.TILE
	var t := WALL_CLEARANCE
	var h := WALL_HEIGHT
	_wall_box(body, Vector3(w, h, t), Vector3(0.0, h / 2.0, -d / 2.0 + t / 2.0))
	_wall_box(body, Vector3(t, h, d), Vector3(-w / 2.0 + t / 2.0, h / 2.0, 0.0))
	_wall_box(body, Vector3(t, h, d), Vector3(w / 2.0 - t / 2.0, h / 2.0, 0.0))
	_wall_box(body, Vector3(w, h, t), Vector3(0.0, h / 2.0, d / 2.0 + t / 2.0))


func _wall_box(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


## Exit door frame on the front edge of the exit tile, a doormat, and the
## trigger that takes the player back outside.
func _build_exit() -> void:
	var exit_root := Node3D.new()
	exit_root.name = "Exit"
	add_child(exit_root)
	var centre := cell_center(EXIT_CELL)
	var door: Array = ModelLib.placed("F:doorway", 0.0, INTERIOR_SCALE)
	var door_node: Node3D = door[0]
	var door_size: Vector3 = door[1]
	door_node.name = "ExitDoor"
	door_node.position = centre + Vector3(0.0, 0.0, Grid.TILE / 2.0 - door_size.z / 2.0)
	exit_root.add_child(door_node)
	var mat: Array = ModelLib.placed("F:rugDoormat", 0.0, INTERIOR_SCALE)
	var mat_node: Node3D = mat[0]
	mat_node.name = "Doormat"
	mat_node.position = centre + Vector3(0.0, 0.0, Grid.TILE / 2.0 - door_size.z - (mat[1] as Vector3).z / 2.0 - PART_GAP)
	exit_root.add_child(mat_node)
	var trigger := Area3D.new()
	trigger.set_script(preload("res://scripts/door_trigger.gd"))
	trigger.name = "ExitTrigger"
	exit_root.add_child(trigger)
	trigger.setup(centre, Vector3(0.0, 2.6, Grid.TILE / 2.0), Game.exit_house)


func _build_objects(data: Dictionary) -> void:
	var objects := Node3D.new()
	objects.name = "Objects"
	add_child(objects)
	var index := 0
	for o: Dictionary in data["objects"]:
		var cell: Vector2i = o["cell"]
		var size: Vector2i = o.get("size", Vector2i.ONE)
		var label: String = o.get("type", (o.get("id", "?") as String).get_slice(":", 1))
		var obj_name := "%s_%d" % [label, index]
		index += 1
		if not _claim(cell, size, obj_name):
			continue
		var node := _build_fireplace(size) if o.get("type", "") == "fireplace" else _build_object(o, size)
		node.name = obj_name
		node.position = Grid.footprint_center(cell, size, ROOM_SIZE)
		node.set_meta("cell", cell)
		node.set_meta("size", size)
		objects.add_child(node)


## One footprint can't hold two objects, and the entrance/exit stay clear.
func _claim(cell: Vector2i, size: Vector2i, obj_name: String) -> bool:
	for dz in size.y:
		for dx in size.x:
			var c := cell + Vector2i(dx, dz)
			if not in_room(c):
				push_error("%s at %s is outside the room (tile %s)" % [obj_name, cell, c])
				return false
			if c == ENTRANCE_CELL or c == EXIT_CELL:
				push_error("%s at %s blocks the entrance/exit (tile %s)" % [obj_name, cell, c])
				return false
			if occupied.has(c):
				push_error("%s at %s overlaps %s (tile %s)" % [obj_name, cell, occupied[c], c])
				return false
	for dz in size.y:
		for dx in size.x:
			occupied[cell + Vector2i(dx, dz)] = obj_name
	return true


func _build_object(o: Dictionary, size: Vector2i) -> Node3D:
	var root := _object_root()
	var model := root.get_node("Model") as Node3D
	var main: Array = ModelLib.placed(o["id"], o.get("rot", 0.0), INTERIOR_SCALE)
	var main_node: Node3D = main[0]
	var main_size: Vector3 = main[1]
	main_node.position = _against_offset(o.get("against", ""), size, main_size)
	model.add_child(main_node)
	_warn_if_too_big(o["id"], size, main_size)
	# Small items stand exactly on the object's top surface.
	for t: Array in o.get("top", []):
		var item: Array = ModelLib.placed(t[0], t[2], INTERIOR_SCALE)
		var item_node: Node3D = item[0]
		var off: Vector2 = t[1]
		item_node.position = main_node.position + Vector3(off.x, main_size.y, off.y)
		model.add_child(item_node)
	# Extra items on the floor beside it (e.g. chairs around a table).
	for p: Array in o.get("parts", []):
		var part: Array = ModelLib.placed(p[0], p[2], INTERIOR_SCALE)
		var part_node: Node3D = part[0]
		var off: Vector2 = p[1]
		part_node.position = main_node.position + Vector3(off.x, 0.0, off.y)
		model.add_child(part_node)
	if o.get("light", false):
		_add_lamp_light(root, ModelUtil.aabb_in(model, root))
	if o.get("flat", false):
		root.set_meta("solid", false)
	else:
		_collider_from_model(root)
	return root


## Fireplace (no pack has one): a stone chimney stack from the Fantasy Town
## Kit against the back wall, with a Survival Kit fire pit on its hearth.
func _build_fireplace(size: Vector2i) -> Node3D:
	var root := _object_root()
	var model := root.get_node("Model") as Node3D
	var chimney: Array = ModelLib.placed("T:chimney-base", 90.0, INTERIOR_SCALE)
	var chimney_node: Node3D = chimney[0]
	var chimney_size: Vector3 = chimney[1]
	chimney_node.position = _against_offset("north", size, chimney_size)
	model.add_child(chimney_node)
	var fire: Array = ModelLib.placed("S:campfire-pit", 0.0, INTERIOR_SCALE)
	var fire_node: Node3D = fire[0]
	var fire_size: Vector3 = fire[1]
	fire_node.position = chimney_node.position + Vector3(0.0, 0.0, chimney_size.z / 2.0 + fire_size.z / 2.0 + PART_GAP)
	model.add_child(fire_node)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.light_energy = 2.0
	glow.omni_range = 6.0
	glow.position = fire_node.position + Vector3(0.0, 0.6, 0.3)
	root.add_child(glow)
	_collider_from_model(root)
	return root


## Where a model sits inside its footprint: centred, or pushed back against
## a wall (keeping WALL_CLEARANCE from the tile edge).
func _against_offset(side: String, size: Vector2i, model_size: Vector3) -> Vector3:
	var half := Vector2(size) * Grid.TILE / 2.0
	match side:
		"north":
			return Vector3(0.0, 0.0, -half.y + WALL_CLEARANCE + model_size.z / 2.0)
		"west":
			return Vector3(-half.x + WALL_CLEARANCE + model_size.x / 2.0, 0.0, 0.0)
		"east":
			return Vector3(half.x - WALL_CLEARANCE - model_size.x / 2.0, 0.0, 0.0)
	return Vector3.ZERO


func _warn_if_too_big(id: String, size: Vector2i, model_size: Vector3) -> void:
	var room_for := Vector2(size) * Grid.TILE
	if model_size.x > room_for.x or model_size.z > room_for.y:
		push_error("%s (%s) doesn't fit its %s tile footprint" % [id, model_size, size])


func _add_lamp_light(root: Node3D, box: AABB) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "LampLight"
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 2.2
	lamp.omni_range = 6.0
	lamp.position = Vector3(box.get_center().x, box.end.y + 0.15, box.get_center().z)
	root.add_child(lamp)


func _object_root() -> Node3D:
	var root := Node3D.new()
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	return root


## Box collider matching the object's models.
func _collider_from_model(root: Node3D) -> void:
	var box := ModelUtil.aabb_in(root.get_node("Model"), root)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = box.get_center()
	root.get_node("Body").add_child(cs)
	root.set_meta("solid", true)


func _spawn_player() -> void:
	Game.take_spawn()  # interiors always start at the entrance
	var player := get_node_or_null(player_path)
	if player:
		player.spawn_at(cell_center(ENTRANCE_CELL), PI)  # facing into the room
