extends SceneTree
## Leafwind check: the two-level island and its three interiors. Fails if:
##  - two solid objects (props, villagers) share a tile, or anything stands
##    on a path, stairs or bridge tile, or on the landing tile
##  - anything floats or sinks (props and villagers flush on their floor,
##    the grass or a deck one level up)
##  - a floor has a gap or a step: rays down across every tile, and across
##    every edge you can walk over (bridge ends, stair ends, deck edges),
##    must find the floor at exactly the right height
##  - a stairs run isn't two tiles from the grass up to a deck, or a bridge
##    doesn't join two floors at its own level
##  - a drop isn't guarded (you could walk off a deck, a stair side or a
##    bridge), checked with rays and by walking the player into it
##  - the stairs and bridges can't actually be walked (physics walk)
##  - the launch point isn't on an edge tile facing the sky, or the landing
##    tile is blocked
##  - any open tile on the island can't be reached from the landing tile
##  - the 3 windmills don't have separate sails, or the far cliff / knot of
##    wind is missing or reachable
##  - an interior: shared tiles, floating / sinking objects, or an open tile
##    or the exit that can't be reached from the entrance
## Usage: godot_console --headless --path . --script res://tools/check_leafwind.gd
##   add "-- selftest" to plant problems and prove they're caught.

const SCENE := "res://scenes/leafwind.tscn"
const INTERIORS := ["res://scenes/interiors/kite_workshop.tscn", "res://scenes/interiors/lookout.tscn", "res://scenes/interiors/family_home.tscn"]
const TOL := 0.03
const DIRS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const KEYS := {Vector2i(1, 0): "move_right", Vector2i(-1, 0): "move_left", Vector2i(0, -1): "move_up", Vector2i(0, 1): "move_down"}

var _failures := 0
var _checks := 0
var _where := "leafwind"
var _island: Node3D
var _space: PhysicsDirectSpaceState3D
var _blocked := {}  # cell -> what stands there (solid props and villagers)
var _selftest := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_selftest = "selftest" in OS.get_cmdline_user_args()
	change_scene_to_file(SCENE)
	for i in 30:
		await physics_frame
	_island = current_scene.get_node("Island")
	_space = _island.get_world_3d().direct_space_state
	if _selftest:
		_break_things()
		for i in 3:
			await physics_frame
	_check_objects()
	_check_launch()
	_check_shapes()
	_check_floors()
	_check_guards()
	_check_reachable()
	_check_windmills_and_cliff()
	await _walk_tests()
	print("leafwind    %s" % ("ok" if _failures == 0 else "%d problem(s)" % _failures))
	for path: String in INTERIORS:
		await _check_interior(path)
	print("RESULT: %s (%d checks)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- objects

func _check_objects() -> void:
	var owner_of := {}
	var things: Array[Node3D] = []
	for p in _island.get_node("Props").get_children():
		things.append(p)
	for v in _island.get_node("Villagers").get_children():
		things.append(v)
	for t in things:
		var cell: Vector2i = t.get_meta("cell")
		var size: Vector2i = t.get_meta("size", Vector2i.ONE)
		var solid: bool = t is Villager or t.get_meta("solid", true)
		var floor_y: float = _island.cell_pos(cell).y
		for dz in size.y:
			for dx in size.x:
				var c := cell + Vector2i(dx, dz)
				_expect(_island.is_ground(c), "%s: tile %s is on the island" % [t.name, c])
				_expect(not _island.is_walkway(c) or String(t.name).begins_with("launch_"), "%s: tile %s isn't a path, stairs or bridge" % [t.name, c])
				_expect(c != _island.landing_cell, "%s keeps off the landing tile" % t.name)
				_expect(is_equal_approx(_island.cell_pos(c).y, floor_y), "%s: all its tiles are on one level" % t.name)
				if owner_of.has(c):
					_fail("%s and %s share tile %s" % [t.name, owner_of[c], c])
				else:
					owner_of[c] = t.name
				if solid:
					_blocked[c] = t.name
		# Flush on its own floor.
		var vis := t.get_node_or_null("Model") as Node3D
		if vis == null:
			vis = t.get_node("Visual") as Node3D
		var box := ModelUtil.aabb_in(vis, _island)
		_expect(absf(box.position.y - floor_y) <= TOL, "%s stands flush on its floor (bottom %.3f, floor %.1f)" % [t.name, box.position.y, floor_y])
		_expect(is_equal_approx(t.position.y, floor_y), "%s sits at its floor's height" % t.name)


func _check_launch() -> void:
	var cell: Vector2i = _island.launch_cell
	var dir: Vector2i = _island.launch_dir
	_expect(_island.is_ground(cell) and not _island.is_ground(cell + dir), "launch point %s is on an edge tile, facing the sky" % cell)
	_expect(_island.cell_level(cell) == 0, "launch point is on the grass")
	var landing: Vector2i = _island.landing_cell
	_expect(landing == cell - dir and _island.is_ground(landing) and not _blocked.has(landing), "landing tile %s is free" % landing)
	_expect(not _island.is_stairs(landing) and not _island.is_bridge(landing), "landing tile is plain ground")


# ---------------------------------------------------------------- stairs & bridges

## Every stairs run is two tiles: grass below its foot, a deck above its
## top. Every bridge joins two floors at its own level, end to end.
func _check_shapes() -> void:
	for c: Vector2i in _island.ground_cells():
		if _island.is_stairs_low(c):
			var r: Vector2i = _island.rise_dir(c)
			var high := c + r
			_expect(_island.is_stairs_high(high) and not _island.is_stairs_low(high), "stairs at %s are exactly two tiles long" % c)
			var foot := c - r
			var head := high + r
			_expect(_island.is_ground(foot) and not _island.is_stairs(foot) and not _island.is_bridge(foot) and _island.cell_level(foot) == 0,
					"stairs at %s start on the grass (%s)" % [c, foot])
			_expect(_island.is_deck(head) and _island.cell_level(head) == 1, "stairs at %s reach a deck (%s)" % [c, head])
			_expect(c in _island.walk_links(foot) and high in _island.walk_links(head), "stairs at %s join both floors" % c)
		if _island.is_bridge(c):
			var axis: Vector2i = _island.bridge_axis(c)
			var side := Vector2i(axis.y, axis.x)
			_expect(not _island.is_ground(c + side) and not _island.is_ground(c - side), "bridge %s has sky on both sides" % c)
			for d in [axis, -axis]:
				var n: Vector2i = c + d
				if not _island.is_bridge(n):
					_expect(_island.is_ground(n) and not _island.is_stairs(n) and _island.cell_level(n) == _island.cell_level(c),
							"bridge %s lands on a floor at its own level (%s)" % [c, n])
	# Links go both ways.
	for c: Vector2i in _island.ground_cells():
		for n: Vector2i in _island.walk_links(c):
			_expect(c in _island.walk_links(n), "you can walk back from %s to %s" % [n, c])


## The floor's height at an island-space point on a tile (stairs slope).
func _expected_floor(cell: Vector2i, p: Vector3) -> float:
	if _island.is_stairs(cell):
		var r: Vector2i = _island.rise_dir(cell)
		var low: Vector2i = cell if _island.is_stairs_low(cell) else cell - r
		var start := Grid.cell_center(low, _island.map_size) - Vector3(r.x, 0.0, r.y) * Grid.TILE / 2.0
		var t := (p - start).dot(Vector3(r.x, 0.0, r.y)) / (2.0 * Grid.TILE)
		return clampf(t, 0.0, 1.0) * _island.LEVEL_HEIGHT
	return _island.cell_pos(cell).y


func _floor_at(p: Vector3) -> Variant:
	var from := _island.to_global(Vector3(p.x, 12.0, p.z))
	var to := _island.to_global(Vector3(p.x, -3.0, p.z))
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [(current_scene.get_node("Player") as CollisionObject3D).get_rid()]
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		return null
	return _island.to_local(hit["position"]).y


## Rays down over every open tile (centre and four points round it) and
## across every walkable edge (just either side of it).
func _check_floors() -> void:
	for c: Vector2i in _island.ground_cells():
		if _blocked.has(c):
			continue
		var centre := Grid.cell_center(c, _island.map_size)
		for o in [Vector3.ZERO, Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
			var p: Vector3 = centre + o
			var y = _floor_at(p)
			var want := _expected_floor(c, p)
			_expect(y != null and absf(float(y) - want) <= TOL, "floor on tile %s at %s is at %.2f m (found %s)" % [c, o, want, y])
		for n: Vector2i in _island.walk_links(c):
			if _blocked.has(n):
				continue
			var d := n - c
			var edge := centre + Vector3(d.x, 0.0, d.y) * Grid.TILE / 2.0
			for side: float in [-0.03, 0.03]:
				var p: Vector3 = edge + Vector3(d.x, 0.0, d.y) * side
				var y = _floor_at(p)
				var want := _expected_floor(c if side < 0.0 else n, p)
				_expect(y != null and absf(float(y) - want) <= TOL, "no gap or step between %s and %s (want %.2f, found %s)" % [c, n, want, y])


## Every way off a tile that isn't a walkable link is blocked: a ray
## sideways at knee-to-chest height hits something before the next tile.
func _check_guards() -> void:
	for c: Vector2i in _island.ground_cells():
		if _blocked.has(c):
			continue
		var links: Array = _island.walk_links(c)
		var centre := Grid.cell_center(c, _island.map_size)
		for d in DIRS:
			if c + d in links:
				continue
			var e := Vector3(d.x, 0.0, d.y)
			var y0 := _expected_floor(c, centre)
			for h: float in [0.5, 1.2]:
				var from := centre + Vector3(0.0, y0 + h, 0.0)
				var q := PhysicsRayQueryParameters3D.create(_island.to_global(from), _island.to_global(from + e * (Grid.TILE / 2.0 + 0.05)))
				_expect(not _space.intersect_ray(q).is_empty(), "the drop from %s towards %s is guarded (at %.1f m)" % [c, c + d, h])


## Every open tile can be reached from the landing tile, walking over
## stairs and bridges (props and villagers in the way).
func _check_reachable() -> void:
	var start: Vector2i = _island.landing_cell
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n: Vector2i in _island.walk_links(c):
			if not _blocked.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for c: Vector2i in _island.ground_cells():
		if not _blocked.has(c):
			_expect(seen.has(c), "open tile %s can be reached from the landing tile" % c)
	for door in _island.get_node("Doors").get_children():
		_expect(seen.has(door.get_meta("cell")), "door tile %s can be reached" % door.get_meta("cell"))
	var levels := {}
	for c in seen:
		levels[_island.cell_level(c)] = true
	_expect(levels.size() == 2, "both levels can be reached")


func _check_windmills_and_cliff() -> void:
	var mills := 0
	var cliff: Node3D = null
	for p in _island.get_node("Props").get_children():
		if String(p.name).begins_with("windmill"):
			mills += 1
			var sails := p.find_child("Sails", true, false) as Node3D
			_expect(sails != null and sails.has_meta("spin_axis") and sails.get_child_count() > 0, "%s has separate sails on a pivot" % p.name)
			_expect(sails != null and ModelUtil.aabb_in(sails, _island).position.y > _island.cell_pos(p.get_meta("cell")).y + 1.9,
					"%s sails clear the player's head" % p.name)
		if String(p.name).begins_with("wind_cliff"):
			cliff = p
	_expect(mills == 3, "3 windmills (%d)" % mills)
	_expect(cliff != null and cliff.find_child("WindKnot", true, false) != null, "the far cliff has its knot of wind")
	if cliff:
		var cell: Vector2i = cliff.get_meta("cell")
		var size: Vector2i = cliff.get_meta("size")
		_expect(cell.y == 0 and not _island.is_ground(cell + Vector2i(size.x / 2, -1)), "the far cliff is on the island's north edge")
		_expect(cliff.get_meta("solid", false), "the far cliff can't be walked onto")


# ---------------------------------------------------------------- physics walks

## Walk the player up and down every stairs run and across every bridge,
## and into a guarded deck edge.
func _walk_tests() -> void:
	var player := current_scene.get_node("Player") as CharacterBody3D
	for c: Vector2i in _island.ground_cells():
		if _island.is_stairs_low(c):
			var r: Vector2i = _island.rise_dir(c)
			var foot := c - r
			var head := c + r * 2
			await _walk(player, foot, r, head, "up the stairs at %s" % c)
			await _walk(player, head, -r, foot, "down the stairs at %s" % c)
		if _island.is_bridge(c) and not _island.is_bridge(c - _island.bridge_axis(c)):
			var axis: Vector2i = _island.bridge_axis(c)
			var end := c
			while _island.is_bridge(end + axis):
				end += axis
			await _walk(player, c - axis, axis, end + axis, "across the bridge at %s" % c)
	# Into a guarded deck edge: stays up on the deck.
	var tested := 0
	for c: Vector2i in _island.ground_cells():
		if tested >= 3 or not _island.is_deck(c) or _blocked.has(c):
			continue
		for d in DIRS:
			var n := c + d
			if _island.is_ground(n) and _island.cell_level(n) == 0 and not n in _island.walk_links(c):
				player.spawn_at(_island.to_global(_island.cell_pos(c)))
				await _hold(KEYS[d], 50)
				_expect(absf(_island.to_local(player.global_position).y - _island.LEVEL_HEIGHT) < 0.1,
						"walking into the guarded edge of %s keeps the player on the deck" % c)
				tested += 1
				break


func _walk(player: CharacterBody3D, from: Vector2i, dir: Vector2i, to: Vector2i, what: String) -> void:
	player.spawn_at(_island.to_global(_island.cell_pos(from)))
	for i in 3:
		await physics_frame
	Input.action_press(KEYS[dir])
	var reached := false
	for i in 180:
		await physics_frame
		var here := _island.to_local(player.global_position)
		if Grid.world_to_cell(here, _island.map_size) == to:
			reached = true
		if reached and Grid.cell_center(to, _island.map_size).distance_to(Vector3(here.x, 0, here.z)) < 0.6:
			break
	Input.action_release(KEYS[dir])
	for i in 10:
		await physics_frame
	var y := _island.to_local(player.global_position).y
	_expect(reached and absf(y - _island.cell_pos(to).y) < 0.08, "the player can walk %s (y=%.2f)" % [what, y])


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame
	Input.action_release(action)
	for i in 10:
		await physics_frame


# ---------------------------------------------------------------- interiors

func _check_interior(path: String) -> void:
	_where = path.get_file().get_basename()
	var before := _failures
	if not ResourceLoader.exists(path):
		_fail("interior scene is missing")
		return
	change_scene_to_file(path)
	for i in 20:
		await physics_frame
	var room := current_scene
	var objects := room.get_node("Objects").get_children()
	var owner_of := {}
	var blocked := {}
	for o in objects:
		var cell: Vector2i = o.get_meta("cell")
		var size: Vector2i = o.get_meta("size")
		for dz in size.y:
			for dx in size.x:
				var c := cell + Vector2i(dx, dz)
				_expect(room.in_room(c), "%s stays inside the room" % o.name)
				if owner_of.has(c):
					_fail("%s and %s share tile %s" % [o.name, owner_of[c], c])
				owner_of[c] = o.name
				if o.get_meta("solid", true):
					blocked[c] = true
		var box := ModelUtil.aabb_in(o.get_node("Model") as Node3D, room)
		_expect(absf(box.position.y) <= TOL, "%s stands flush on the floor (%.3f)" % [o.name, box.position.y])
	for v in room.get_node("Villagers").get_children() if room.has_node("Villagers") else []:
		var cell: Vector2i = v.get_meta("cell")
		_expect(not owner_of.has(cell), "%s has a tile of their own" % v.name)
		blocked[cell] = true
	_expect(objects.size() >= 8, "the room is well furnished (%d objects)" % objects.size())
	var start: Vector2i = room.ENTRANCE_CELL
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if room.in_room(n) and not blocked.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	_expect(seen.has(room.EXIT_CELL), "the exit can be reached from the entrance")
	for c: Vector2i in room.room_cells():
		if not blocked.has(c):
			_expect(seen.has(c), "open tile %s can be reached" % c)
	print("%-11s %s" % [_where, "ok" if _failures == before else "%d problem(s)" % (_failures - before)])


# ---------------------------------------------------------------- self-test

func _break_things() -> void:
	print("SELFTEST: lift a bridge plank 0.3 m, drop a stairs collider, remove a deck guard, put a crate on the stairs, a villager on the landing tile")
	var body := _island.get_node("Structures/StructureBody")
	var done := {}
	for cs in body.get_children():
		var kind: String = cs.get_meta("kind")
		if done.has(kind):
			continue
		if kind == "bridge":
			cs.position.y += 0.3
			done[kind] = true
		elif kind == "stairs":
			cs.position.y -= 0.5
			done[kind] = true
		elif kind == "deck_guard" and not _island.occupied.has(cs.get_meta("cell")):
			cs.disabled = true
			print("SELFTEST: guard removed on tile %s" % cs.get_meta("cell"))
			done[kind] = true
	for p in _island.get_node("Props").get_children():
		if String(p.name).begins_with("crate"):
			for c: Vector2i in _island.ground_cells():
				if _island.is_stairs(c):
					p.set_meta("cell", c)
					break
			break
	var v := _island.get_node("Villagers").get_child(0) as Node3D
	v.set_meta("cell", _island.landing_cell)


# ---------------------------------------------------------------- helpers

func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	_failures += 1
	print("FAIL  [%s] %s" % [_where, what])
