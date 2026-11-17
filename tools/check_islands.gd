extends SceneTree
## Launch-point check for every island. Fails (exit code 1) if:
##  - two objects (props, launch point, villagers) share a tile
##  - an island has no launch point, or it isn't on an edge tile, or it
##    doesn't point out at open sky
##  - the launch ramp isn't flush on the ground, spills out of its tile other
##    than its lip over the sky, or its lip doesn't really overhang the edge
##  - the flag / signpost isn't beside the launch point
##  - the landing tile isn't free ground (something stands on it, it's a door
##    tile, or it's off the island), isn't right in front of the ramp, or
##    can't be reached from the island's start / from every open tile
##  - the launch trigger isn't on the landing tile
##  - (Great Tree) the sealed entrance's tile is taken or can't be reached
## Usage: godot_console --headless --path . --script res://tools/check_islands.gd
##   add "-- selftest" to put a crate on a landing tile and move a launch
##   point inland, to prove both are caught.

const ISLANDS := ["res://scenes/pebblenook.tscn", "res://scenes/test_island.tscn", "res://scenes/great_tree_island.tscn"]
const TOL := 0.02

var _failures := 0
var _checks := 0
var _where := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selftest := "selftest" in OS.get_cmdline_user_args()
	for path: String in ISLANDS:
		var scene := (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		for i in 20:
			await physics_frame
		var island: Node3D = scene.get_node("Island")
		_where = island.island_id
		if selftest:
			_break_things(island)
		var before := _failures
		_check_island(island)
		print("%-12s %s" % [_where, "ok" if _failures == before else "%d problem(s)" % (_failures - before)])
		scene.queue_free()
		await process_frame
	print("RESULT: %s (%d checks, %d islands)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks, ISLANDS.size()])
	quit(1 if _failures > 0 else 0)


func _check_island(island: Node3D) -> void:
	var map_size: Vector2i = island.map_size
	# Everything that owns a tile.
	var owner_of := {}
	var blocked := {}
	var launch: Node3D = null
	for p in island.get_node("Props").get_children():
		var cell: Vector2i = p.get_meta("cell")
		var size: Vector2i = p.get_meta("size")
		if String(p.name).begins_with("launch_") and not String(p.name).begins_with("launch_flag"):
			launch = p
		for dz in size.y:
			for dx in size.x:
				_claim(owner_of, cell + Vector2i(dx, dz), String(p.name))
				if p.get_meta("solid", true):
					blocked[cell + Vector2i(dx, dz)] = true
	# Tiles taken by something that isn't a prop (the Great Tree's trunk and roots).
	var extra: Dictionary = island.extra_blocked_cells()
	for cell in extra:
		_claim(owner_of, cell, "great_tree")
		blocked[cell] = true
	for v in island.get_node("Villagers").get_children():
		var cell: Vector2i = v.get_meta("cell")
		_claim(owner_of, cell, String(v.name))
		blocked[cell] = true

	# Launch point: on an edge tile, pointing at open sky.
	_expect(launch != null, "the island has a launch point")
	if launch == null:
		return
	var cell: Vector2i = launch.get_meta("cell")
	var dir: Vector2i = island.launch_dir
	_expect(cell == island.launch_cell, "launch prop sits on the launch tile %s" % cell)
	_expect(island.is_ground(cell) and not island.is_path(cell), "launch point stands on grass (%s)" % cell)
	_expect(not island.is_ground(cell + dir), "launch point is on an edge tile, pointing at open sky (%s -> %s)" % [cell, cell + dir])
	var sky_ahead := true
	for i in range(1, 6):
		if island.is_ground(cell + dir * i):
			sky_ahead = false
	_expect(sky_ahead, "nothing but sky for 5 tiles beyond the ramp")
	var box := ModelUtil.aabb_in(launch.get_node("Model") as Node3D, island)
	_expect(absf(box.position.y) <= TOL, "launch ramp sits flush on the ground (%.3f)" % box.position.y)
	var c := Grid.cell_center(cell, map_size)
	var tile := Rect2(Vector2(c.x, c.z) - Vector2.ONE * Grid.TILE / 2.0, Vector2.ONE * Grid.TILE)
	# Only the lip may stick out, and only towards the sky by its set amount.
	var amount: float = launch.get_meta("overhang", 0.0)
	var allowed := tile.grow(TOL).grow_individual(maxf(0.0, -dir.x) * amount, maxf(0.0, -dir.y) * amount,
			maxf(0.0, dir.x) * amount, maxf(0.0, dir.y) * amount)
	var model_rect := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	_expect(allowed.encloses(model_rect), "launch point stays in its tile apart from the lip over the sky")
	var reach := (model_rect.end.x - tile.end.x) if dir.x > 0 else (tile.position.x - model_rect.position.x) if dir.x < 0 			else (model_rect.end.y - tile.end.y) if dir.y > 0 else (tile.position.y - model_rect.position.y)
	_expect(reach > amount * 0.8, "the launch lip really overhangs the edge (%.2f m)" % reach)
	# Flag and signpost on a tile beside the launch point, along the edge.
	var flag: Node3D = null
	for p in island.get_node("Props").get_children():
		if String(p.name).begins_with("launch_flag"):
			flag = p
	_expect(flag != null, "the launch point has its flag and signpost")
	if flag:
		var fc: Vector2i = flag.get_meta("cell")
		_expect((fc - cell).length_squared() == 1 and fc - cell != dir and fc - cell != -dir,
				"the flag stands beside the launch point, along the edge (%s)" % fc)

	# Landing tile: right in front of the ramp, free, reachable.
	var landing: Vector2i = island.landing_cell
	_expect(landing == cell - dir, "landing tile %s is right in front of the ramp" % landing)
	_expect(island.is_ground(landing), "landing tile %s is on the island" % landing)
	_expect(not owner_of.has(landing), "landing tile %s is free (%s)" % [landing, owner_of.get(landing, "nothing on it")])
	var doors := island.get_node("Doors").get_children()
	for d in doors:
		_expect(d.get_meta("cell") != landing, "landing tile isn't a house door tile")
	var trigger := island.get_node_or_null("LaunchTrigger")
	_expect(trigger != null and Grid.world_to_cell(trigger.position, map_size) == landing,
			"the launch \"Press E\" trigger is on the landing tile")
	var seen := _reach(island, island.start_cell, blocked)
	_expect(seen.has(landing), "landing tile can be reached from the start tile %s" % island.start_cell)
	var from_landing := _reach(island, landing, blocked)
	for g in island.ground_cells():
		if not blocked.has(g):
			_expect(from_landing.has(g), "open tile %s can be reached from the landing tile" % g)
	for d in doors:
		_expect(from_landing.has(d.get_meta("cell")), "door tile %s can be reached from the landing tile" % d.get_meta("cell"))
	var tree = island.get("tree")
	if tree:
		var stand: Vector2i = tree.entrance_cells()[1]
		_expect(not owner_of.has(stand), "the sealed entrance's tile %s is free (%s)" % [stand, owner_of.get(stand, "nothing on it")])
		_expect(from_landing.has(stand), "the sealed entrance can be reached from the landing tile")
		var trig := island.get_node_or_null("EntranceTrigger")
		_expect(trig != null and Grid.world_to_cell(trig.position, map_size) == stand, "the entrance prompt is on its tile")


func _claim(owner_of: Dictionary, cell: Vector2i, who: String) -> void:
	if owner_of.has(cell):
		_fail("%s and %s share tile %s" % [who, owner_of[cell], cell])
	else:
		owner_of[cell] = who
	_checks += 1


func _reach(island: Node3D, start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if island.is_ground(n) and not blocked.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


func _break_things(island: Node3D) -> void:
	var props := island.get_node("Props")
	if island.island_id == "pebblenook":
		print("SELFTEST (pebblenook): move a crate onto the landing tile")
		for p in props.get_children():
			if String(p.name).begins_with("crate"):
				p.set_meta("cell", island.landing_cell)
				break
	elif island.island_id == "great_tree":
		print("SELFTEST (great_tree): put a rock on the entrance tile")
		var last := props.get_child(props.get_child_count() - 1)
		last.set_meta("cell", island.tree.entrance_cells()[1])
		last.set_meta("solid", true)
	else:
		print("SELFTEST (%s): move the launch point inland" % island.island_id)
		for p in props.get_children():
			if String(p.name).begins_with("launch_") and not String(p.name).begins_with("launch_flag"):
				p.set_meta("cell", Vector2i(4, 3))
				island.launch_cell = Vector2i(4, 3)
				break


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	_failures += 1
	print("FAIL  [%s] %s" % [_where, what])
