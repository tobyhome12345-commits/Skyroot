extends SceneTree
## Automated check for all house interiors. Fails (exit code 1) if:
##  - two objects share a tile, an object is outside the room, or stands on
##    the entrance / exit tile
##  - any model floats or sinks: every piece must stand on the floor (y = 0)
##    or exactly on top of the piece below it
##  - pieces overlap each other, spill out of their tiles, or clip into the
##    walls or the exit door
##  - a solid object has no collider, or its collider doesn't match its models
##  - the floor has a gap, or isn't flush at y = 0
##  - the exit (or any open tile) can't be reached from the entrance
## Usage: godot_console --headless --path . --script res://tools/check_interiors.gd
##   add "-- selftest" to plant known problems and prove they're caught.

const ROOMS := [
	"res://scenes/interiors/elder_home.tscn",
	"res://scenes/interiors/bedroom.tscn",
	"res://scenes/interiors/workshop.tscn",
	"res://scenes/interiors/library.tscn",
	"res://scenes/interiors/kite_workshop.tscn",
	"res://scenes/interiors/lookout.tscn",
	"res://scenes/interiors/family_home.tscn",
	"res://scenes/interiors/captain_cabin.tscn",
	"res://scenes/interiors/rope_loft.tscn",
	"res://scenes/interiors/chime_workshop.tscn",
	"res://scenes/interiors/bakehouse.tscn",
]
const TOL := 0.01

var _failures := 0
var _checks := 0
var _room := ""
var _interior: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selftest := "selftest" in OS.get_cmdline_user_args()
	for path: String in ROOMS:
		_room = path.get_file().get_basename()
		var scene := (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		_interior = scene as Node3D
		for i in 20:
			await physics_frame
		if selftest:
			_break_things()
		var before := _failures
		_check_room(scene)
		if not selftest:
			await _walk_into_everything(scene)
		print("%-11s %s" % [_room, "ok" if _failures == before else "%d problem(s)" % (_failures - before)])
		scene.queue_free()
		await process_frame
	print("RESULT: %s (%d checks, %d rooms)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks, ROOMS.size()])
	quit(1 if _failures > 0 else 0)


func _check_room(scene: Node) -> void:
	var objects: Array[Node3D] = []
	for o in _interior.get_node("Objects").get_children():
		objects.append(o as Node3D)
	_check_tiles(objects)
	var boxes := {}
	for o in objects:
		boxes[o] = _check_object(o)
	_check_overlaps(objects, boxes)
	_check_walls(objects, boxes)
	_check_floor()
	_check_reachable(objects)
	_check_player(scene.get_node("Player"))


# ---------------------------------------------------------------- tiles

func _check_tiles(objects: Array[Node3D]) -> void:
	var owner_of := {}
	for o in objects:
		for c in _footprint(o):
			_expect(_interior.in_room(c), "%s: tile %s is inside the room" % [o.name, c])
			_expect(c != _interior.ENTRANCE_CELL and c != _interior.EXIT_CELL,
					"%s keeps the entrance and exit clear (tile %s)" % [o.name, c])
			if owner_of.has(c):
				_fail("%s and %s share tile %s" % [o.name, owner_of[c], c])
			else:
				owner_of[c] = o.name
			_checks += 1


func _footprint(o: Node3D) -> Array[Vector2i]:
	var cell: Vector2i = o.get_meta("cell")
	var size: Vector2i = o.get_meta("size")
	var cells: Array[Vector2i] = []
	for dz in size.y:
		for dx in size.x:
			cells.append(cell + Vector2i(dx, dz))
	return cells


func _footprint_rect(o: Node3D) -> Rect2:
	var cell: Vector2i = o.get_meta("cell")
	var size: Vector2i = o.get_meta("size")
	var centre := Grid.footprint_center(cell, size, _interior.ROOM_SIZE)
	var half := Vector2(size) * Grid.TILE / 2.0
	return Rect2(Vector2(centre.x, centre.z) - half, half * 2.0)


# ---------------------------------------------------------------- objects

## Checks one object's pieces and collider; returns its overall model box.
func _check_object(o: Node3D) -> AABB:
	var model := o.get_node("Model") as Node3D
	var pieces: Array[AABB] = []
	for p in model.get_children():
		pieces.append(ModelUtil.aabb_in(p as Node3D, _interior))
	# Every piece stands on the floor or exactly on top of another piece.
	for i in pieces.size():
		var p := pieces[i]
		var supported := absf(p.position.y) <= TOL
		if not supported:
			var centre := Vector2(p.get_center().x, p.get_center().z)
			for j in pieces.size():
				var q := pieces[j]
				var q_rect := Rect2(Vector2(q.position.x, q.position.z), Vector2(q.size.x, q.size.z))
				if j != i and absf(q.end.y - p.position.y) <= TOL and q_rect.has_point(centre):
					supported = true
					break
		_expect(supported, "%s: piece %s sits on the floor or on the piece below (bottom y=%.3f)" % [
				o.name, model.get_child(i).name, p.position.y])
	# Pieces of one object don't overlap each other.
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			_expect(not _overlaps(pieces[i], pieces[j]),
					"%s: pieces %s and %s don't overlap" % [o.name, model.get_child(i).name, model.get_child(j).name])
	var box := ModelUtil.aabb_in(model, _interior)
	var rect := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	_expect(_footprint_rect(o).grow(0.02).encloses(rect), "%s stays inside its tiles (%s vs %s)" % [o.name, rect, _footprint_rect(o)])
	# Collider.
	var shapes := o.get_node("Body").find_children("*", "CollisionShape3D", true, false)
	if not o.get_meta("solid", true):
		_expect(shapes.is_empty() and box.size.y < 0.1, "%s is a flat rug with no collider" % o.name)
	else:
		_expect(shapes.size() == 1, "%s (solid) has a collider" % o.name)
		for s in shapes:
			var cs := s as CollisionShape3D
			var size := (cs.shape as BoxShape3D).size
			var col := ModelUtil._relative_transform(_interior, cs) * AABB(-size / 2.0, size)
			_expect(col.position.is_equal_approx(box.position) and col.size.is_equal_approx(box.size),
					"%s collider matches its models (%s vs %s)" % [o.name, col, box])
	return box


func _check_overlaps(objects: Array[Node3D], boxes: Dictionary) -> void:
	for i in objects.size():
		for j in range(i + 1, objects.size()):
			var a: AABB = boxes[objects[i]]
			var b: AABB = boxes[objects[j]]
			# Rugs lie flat on the floor; anything else may not overlap them either.
			_expect(not _overlaps(a, b),
					"%s and %s don't overlap" % [objects[i].name, objects[j].name])


## No model clips into a wall piece, and nothing overlaps the exit door.
func _check_walls(objects: Array[Node3D], boxes: Dictionary) -> void:
	var walls: Array[AABB] = []
	for w in _interior.get_node("Walls").get_children():
		walls.append(ModelUtil.aabb_in(w as Node3D, _interior))
	var door := ModelUtil.aabb_in(_interior.get_node("Exit/ExitDoor") as Node3D, _interior)
	var mat := ModelUtil.aabb_in(_interior.get_node("Exit/Doormat") as Node3D, _interior)
	_expect(absf(door.position.y) <= TOL and absf(mat.position.y) <= TOL, "exit door and doormat sit on the floor")
	_expect(not _overlaps(door, mat), "doormat doesn't clip into the door")
	for o in objects:
		var box: AABB = boxes[o]
		for wb in walls:
			if _overlaps(box, wb):
				_fail("%s clips into a wall" % o.name)
				break
		_checks += 1
		_expect(not _overlaps(box, door), "%s keeps clear of the exit door" % o.name)


# ---------------------------------------------------------------- floor & paths

func _check_floor() -> void:
	var cells := {}
	for f in _interior.get_node("Floor").get_children():
		var box := ModelUtil.aabb_in(f as Node3D, _interior)
		if String(f.name).begins_with("boards"):
			_expect(absf(box.end.y) <= TOL, "floor boards %s are flush at y = 0 (top %.3f)" % [f.name, box.end.y])
		else:
			cells[f.get_meta("cell")] = true
			_expect(box.end.y <= TOL, "floor base %s stays under the boards" % f.name)
	for c in _interior.room_cells():
		_expect(cells.has(c), "floor covers tile %s" % c)


## Walk the tile grid from the entrance: the exit and every open tile must be
## reachable (solid objects block their whole footprint).
func _check_reachable(objects: Array[Node3D]) -> void:
	var blocked := {}
	for o in objects:
		if o.get_meta("solid", true):
			for c in _footprint(o):
				blocked[c] = true
	var start: Vector2i = _interior.ENTRANCE_CELL
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if _interior.in_room(n) and not blocked.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	_expect(seen.has(_interior.EXIT_CELL), "the exit can be reached from the entrance")
	for c in _interior.room_cells():
		if not blocked.has(c):
			_expect(seen.has(c), "open tile %s can be reached from the entrance" % c)


func _check_player(player: Node3D) -> void:
	var cell := Grid.world_to_cell(player.global_position, _interior.ROOM_SIZE)
	_expect(cell == _interior.ENTRANCE_CELL, "player starts on the entrance tile (%s)" % cell)
	_expect(absf(player.global_position.y) <= 0.02, "player stands on the floor (y=%.3f)" % player.global_position.y)


## Physics walk: from the entrance, hold each direction (and diagonals) for
## a few seconds. The player must stay in the room, on the floor, and never
## end up inside any solid object's collider.
func _walk_into_everything(scene: Node) -> void:
	var player := scene.get_node("Player") as CharacterBody3D
	var start := player.global_position
	var solids: Array[AABB] = []
	for o in _interior.get_node("Objects").get_children():
		for s in (o as Node).get_node("Body").find_children("*", "CollisionShape3D", true, false):
			var cs := s as CollisionShape3D
			var size := (cs.shape as BoxShape3D).size
			solids.append(ModelUtil._relative_transform(_interior, cs) * AABB(-size / 2.0, size))
	var half := Vector2(_interior.ROOM_SIZE) * Grid.TILE / 2.0
	var routes := [["move_up"], ["move_left"], ["move_right"], ["move_down"],
			["move_up", "move_left"], ["move_up", "move_right"], ["move_down", "move_left"], ["move_down", "move_right"]]
	for route: Array in routes:
		player.spawn_at(start)
		for a: String in route:
			Input.action_press(a)
		for i in 240:
			await physics_frame
			var p := player.global_position
			var inside := false
			for b in solids:
				if p.x > b.position.x + TOL and p.x < b.end.x - TOL and p.z > b.position.z + TOL and p.z < b.end.z - TOL:
					inside = true
			if inside or absf(p.x) > half.x or absf(p.z) > half.y or p.y < -0.05:
				_fail("player walking %s ended up inside something or outside the room at %s" % ["+".join(route), p])
				break
		for a: String in route:
			Input.action_release(a)
		_checks += 1


# ---------------------------------------------------------------- self-test

func _break_things() -> void:
	var objects := _interior.get_node("Objects")
	print("SELFTEST (%s): lift a piece 0.3 m, sink one 0.2 m, put an object on the exit, push one into a wall" % _room)
	var first := objects.get_child(0) as Node3D
	((first.get_node("Model") as Node3D).get_child(0) as Node3D).position.y += 0.3
	var second := objects.get_child(1) as Node3D
	((second.get_node("Model") as Node3D).get_child(0) as Node3D).position.y -= 0.2
	var third := objects.get_child(2) as Node3D
	third.set_meta("cell", _interior.EXIT_CELL)
	var last := objects.get_child(objects.get_child_count() - 1) as Node3D
	last.position.x += 1.5


# ---------------------------------------------------------------- helpers

## True if two boxes overlap by more than TOL on every axis (touching, or a
## paper-thin rug lying on the floor, doesn't count).
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
	print("FAIL  [%s] %s" % [_room, what])
