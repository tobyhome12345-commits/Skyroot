extends SceneTree
## Villager check, run on the island and all 4 interiors. Fails if:
##  - a villager shares a tile with another object or villager, or stands on
##    a path, a door tile, the entrance or the exit, or off the floor
##  - a villager floats / sinks, spills out of its tile, or overlaps furniture
##  - a villager has no solid collider, or its collider leaves its tile
##  - a villager's talk zone reaches a door / exit tile (prompts would clash)
##  - with villagers counted as obstacles, a door, the exit or any open tile
##    can't be reached
##  - a dialogue file is malformed or doesn't have 3-4 conversations
## Usage: godot_console --headless --path . --script res://tools/check_villagers.gd
##   add "-- selftest" to move villagers into bad spots and prove it's caught.

const SCENES := {
	"island": "res://scenes/pebblenook.tscn",
	"traders_rock": "res://scenes/traders_rock.tscn",
	"leafwind": "res://scenes/leafwind.tscn",
	"elder_home": "res://scenes/interiors/elder_home.tscn",
	"bedroom": "res://scenes/interiors/bedroom.tscn",
	"workshop": "res://scenes/interiors/workshop.tscn",
	"library": "res://scenes/interiors/library.tscn",
	"kite_workshop": "res://scenes/interiors/kite_workshop.tscn",
}
const EXPECTED := {"island": 2, "traders_rock": 1, "leafwind": 7, "elder_home": 1, "bedroom": 1, "workshop": 1, "library": 1, "kite_workshop": 1}
const TOL := 0.02

var _failures := 0
var _checks := 0
var _where := ""
var _total_villagers := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selftest := "selftest" in OS.get_cmdline_user_args()
	for key: String in SCENES:
		_where = key
		var scene := (load(SCENES[key]) as PackedScene).instantiate()
		root.add_child(scene)
		for i in 20:
			await physics_frame
		var on_island := scene.has_node("Island")
		var level: Node3D = scene.get_node("Island") if on_island else scene as Node3D
		if selftest:
			_break_things(level, key)
		var before := _failures
		_check_level(level, on_island)
		print("%-11s %s" % [key, "ok" if _failures == before else "%d problem(s)" % (_failures - before)])
		scene.queue_free()
		await process_frame
	_expect(_total_villagers == 15, "15 villagers in total (%d)" % _total_villagers)
	print("RESULT: %s (%d checks)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _check_level(level: Node3D, is_island: bool) -> void:
	var villagers := level.get_node("Villagers").get_children()
	_total_villagers += villagers.size()
	_expect(villagers.size() == EXPECTED[_where], "%d villager(s) here (%d)" % [EXPECTED[_where], villagers.size()])
	var map_size: Vector2i = level.map_size
	# Everything that owns tiles, with its model box.
	var objects := level.get_node("Props" if is_island else "Objects").get_children()
	var owner_of := {}
	var boxes: Array[AABB] = []
	for o in objects:
		var cell: Vector2i = o.get_meta("cell")
		var size: Vector2i = o.get_meta("size")
		for dz in size.y:
			for dx in size.x:
				owner_of[cell + Vector2i(dx, dz)] = String(o.name)
		boxes.append(ModelUtil.aabb_in(o.get_node("Model") as Node3D, level))
	# Door / exit tiles.
	var door_cells: Array[Vector2i] = []
	if is_island:
		for d in level.get_node("Doors").get_children():
			door_cells.append(d.get_meta("cell"))
	else:
		door_cells.append(level.EXIT_CELL)
		door_cells.append(level.ENTRANCE_CELL)

	var blocked := {}
	for o in objects:
		if o.get_meta("solid", true):
			var cell: Vector2i = o.get_meta("cell")
			var size: Vector2i = o.get_meta("size")
			for dz in size.y:
				for dx in size.x:
					blocked[cell + Vector2i(dx, dz)] = true
	for v in villagers:
		var vil := v as Villager
		var cell: Vector2i = vil.get_meta("cell")
		var label := vil.villager_id
		# Tile rules.
		if owner_of.has(cell):
			_fail("%s shares tile %s with %s" % [label, cell, owner_of[cell]])
		else:
			owner_of[cell] = label
		_checks += 1
		_expect(not door_cells.has(cell), "%s doesn't stand on a door / entrance / exit tile (%s)" % [label, cell])
		if is_island:
			_expect(level.is_ground(cell) and not level.is_walkway(cell), "%s stands on grass or a deck, not a path, stairs, bridge or the sky (%s)" % [label, cell])
		else:
			_expect(level.in_room(cell), "%s stands inside the room (%s)" % [label, cell])
		blocked[cell] = true
		var floor_y: float = level.cell_pos(cell).y if is_island else 0.0
		_expect(Grid.world_to_cell(vil.global_position, map_size) == cell and is_equal_approx(vil.position.y, floor_y),
				"%s is placed exactly on its tile at floor level" % label)
		# Model: flush, inside its tile, not overlapping anything.
		var box := ModelUtil.aabb_in(vil.get_node("Visual") as Node3D, level)
		_expect(absf(box.position.y - floor_y) <= TOL, "%s stands flush on the floor (feet y=%.3f, floor y=%.1f)" % [label, box.position.y, floor_y])
		var centre := Grid.cell_center(cell, map_size)
		var tile := Rect2(Vector2(centre.x, centre.z) - Vector2.ONE * Grid.TILE / 2.0, Vector2.ONE * Grid.TILE)
		var r := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		_expect(tile.grow(TOL).encloses(r), "%s stays inside its tile (%s)" % [label, r])
		for b in boxes:
			if _overlaps(box, b):
				_fail("%s overlaps a neighbouring object" % label)
				break
		_checks += 1
		# Collider.
		var cs := vil.get_node_or_null("CollisionShape") as CollisionShape3D
		_expect(cs != null and cs.shape is CylinderShape3D, "%s has a solid collider" % label)
		if cs:
			var cyl := cs.shape as CylinderShape3D
			_expect(cyl.radius * 2.0 <= Grid.TILE and cs.position.y - cyl.height / 2.0 <= TOL and cyl.height >= 1.2,
					"%s collider fits its tile and covers the body" % label)
		# Talk zone must not reach a door / exit tile.
		for dc in door_cells:
			var dist := Vector2(centre.x, centre.z).distance_to(
					Vector2(Grid.cell_center(dc, map_size).x, Grid.cell_center(dc, map_size).z))
			_expect(dist > Villager.TALK_RADIUS, "%s's talk zone stays clear of door tile %s (%.1f m)" % [label, dc, dist])
		# Dialogue data.
		var data := Villager.load_dialogue(label)
		var convs: Array = data.get("conversations", [])
		_expect(not data.is_empty() and convs.size() >= 3 and convs.size() <= 4,
				"%s has 3-4 conversations (%d)" % [label, convs.size()])
		for c in convs:
			_expect(c is Array and not (c as Array).is_empty(), "%s: every conversation has at least one line" % label)
	_check_reachable(level, is_island, blocked, door_cells, map_size)


## With villagers as obstacles, every door / exit and every open tile can
## still be reached.
func _check_reachable(level: Node3D, is_island: bool, blocked: Dictionary, door_cells: Array[Vector2i], map_size: Vector2i) -> void:
	var cells: Array = level.ground_cells() if is_island else level.room_cells()
	var start: Vector2i = level.start_cell if is_island else level.ENTRANCE_CELL
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n in cells and not blocked.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for dc in door_cells:
		_expect(seen.has(dc), "door / exit tile %s can be reached" % dc)
	for c in cells:
		if not blocked.has(c):
			_expect(seen.has(c), "open tile %s can be reached" % c)


func _break_things(level: Node3D, key: String) -> void:
	var villagers := level.get_node("Villagers").get_children()
	if villagers.is_empty():
		return
	var v := villagers[0] as Node3D
	if key == "traders_rock":
		print("SELFTEST (traders_rock): move %s onto the landing tile" % v.name)
		v.set_meta("cell", level.landing_cell)
		v.position = Grid.cell_center(level.landing_cell, level.map_size)
	elif key == "island":
		print("SELFTEST (island): move %s onto the elder's door tile" % v.name)
		var door := level.get_node("Doors").get_child(0)
		v.set_meta("cell", door.get_meta("cell"))
		v.position = Grid.cell_center(door.get_meta("cell"), level.map_size)
	else:
		print("SELFTEST (%s): move %s onto the exit tile" % [key, v.name])
		v.set_meta("cell", level.EXIT_CELL)
		v.position = level.cell_center(level.EXIT_CELL)


func _overlaps(a: AABB, b: AABB) -> bool:
	for axis in 3:
		if minf(a.end[axis], b.end[axis]) - maxf(a.position[axis], b.position[axis]) <= TOL:
			return false
	return true


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	_failures += 1
	print("FAIL  [%s] %s" % [_where, what])
