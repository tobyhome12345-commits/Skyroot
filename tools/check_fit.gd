extends SceneTree
## Automated fit check for the island. Fails (exit code 1) if:
##  - two objects share a tile, or an object is off the island / on a path
##  - any model floats above or sinks below the ground (lowest point != y 0)
##  - a model spills out of its own tiles, or two models overlap
##  - a solid object has no collider, or its collider doesn't match the model
##  - a door is blocked, or a solid collider reaches into a path tile
##  - the ground, edge walls or rocky underside have gaps
##  - the player doesn't stand flush on the ground
## Usage: godot_console --headless --path . --script res://tools/check_fit.gd
##   add "-- selftest" to deliberately break a few things and prove they're caught.

## How far (m) a model may stick out of its tiles: roof eaves overhang 0.13 m.
const OVERHANG_TOLERANCE := 0.15
## How far (m) the lowest point may be from the ground and still count as flush.
const GROUND_TOLERANCE := 0.01

var _failures := 0
var _checks := 0
var _island: Node3D


func _initialize() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var level := scene.instantiate()
	root.add_child(level)
	_island = level.get_node("Island")
	_run.call_deferred(level)


func _run(level: Node) -> void:
	for i in 30:
		await physics_frame
	if "selftest" in OS.get_cmdline_user_args():
		_break_things()
	var props: Array[Node3D] = []
	for child in _island.get_node("Props").get_children():
		props.append(child as Node3D)
	print("Checking %d objects on %d ground tiles" % [props.size(), _island.ground_cells().size()])

	_check_tiles(props)
	var boxes := {}
	for prop in props:
		boxes[prop] = _check_model(prop)
		_check_collider(prop, boxes[prop])
	_check_overlaps(props, boxes)
	_check_paths_and_doors(props)
	_check_ground()
	_check_player(level.get_node("Player"))

	print("RESULT: %s (%d checks)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks])
	quit(1 if _failures > 0 else 0)


## Self-test: plant known problems; the check must report every one.
func _break_things() -> void:
	var props := _island.get_node("Props")
	print("SELFTEST: tree_6 floats 0.3 m, barrel sinks 0.2 m, flowers moved onto a house tile, crate overlaps a house")
	(props.get_node("tree_6") as Node3D).position.y += 0.3
	for p in props.get_children():
		if String(p.name).begins_with("barrel"):
			(p.get_node("Model") as Node3D).position.y -= 0.2
			break
	for p in props.get_children():
		if String(p.name).begins_with("flowers_"):
			p.set_meta("cell", Vector2i(3, 3))
			break
	for p in props.get_children():
		if String(p.name).begins_with("crate"):
			(p as Node3D).position.x += 1.2  # pushes it into house_1 next door
			break


# ---------------------------------------------------------------- tiles

func _check_tiles(props: Array[Node3D]) -> void:
	var owner_of := {}
	for prop in props:
		if not prop.has_meta("cell"):
			_fail("%s has no tile position" % prop.name)
			continue
		for c in _footprint(prop):
			_expect(_island.is_ground(c), "%s: tile %s is on the island" % [prop.name, c])
			_expect(not _island.is_path(c), "%s: tile %s is not a path tile" % [prop.name, c])
			if owner_of.has(c):
				_fail("%s and %s share tile %s" % [prop.name, owner_of[c], c])
			else:
				owner_of[c] = prop.name
		_checks += 1


func _footprint(prop: Node3D) -> Array[Vector2i]:
	var cell: Vector2i = prop.get_meta("cell")
	var size: Vector2i = prop.get_meta("size")
	var cells: Array[Vector2i] = []
	for dz in size.y:
		for dx in size.x:
			cells.append(cell + Vector2i(dx, dz))
	return cells


## Footprint rectangle in island space (x/z, metres).
func _footprint_rect(prop: Node3D) -> Rect2:
	var cell: Vector2i = prop.get_meta("cell")
	var size: Vector2i = prop.get_meta("size")
	var centre := Grid.footprint_center(cell, size, _island.map_size)
	var half := Vector2(size) * Grid.TILE / 2.0
	return Rect2(Vector2(centre.x, centre.z) - half, half * 2.0)


# ---------------------------------------------------------------- models

func _check_model(prop: Node3D) -> AABB:
	var box := ModelUtil.aabb_in(prop.get_node("Model"), _island)
	_expect(box.size.length() > 0.01, "%s has a visible model" % prop.name)
	var bottom := box.position.y
	_expect(absf(bottom) <= GROUND_TOLERANCE,
			"%s sits flush on the ground (lowest point y=%.3f)" % [prop.name, bottom])
	var rect := _footprint_rect(prop).grow(OVERHANG_TOLERANCE)
	var model_rect := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	_expect(rect.encloses(model_rect),
			"%s stays inside its tiles (model %s, tiles %s)" % [prop.name, model_rect, _footprint_rect(prop)])
	return box


func _check_collider(prop: Node3D, model_box: AABB) -> void:
	var shapes := prop.get_node("Body").find_children("*", "CollisionShape3D", true, false)
	if not prop.get_meta("solid", true):
		_expect(shapes.is_empty() and model_box.size.y < 0.15,
				"%s is a flat ground detail with no collider" % prop.name)
		return
	_expect(not shapes.is_empty(), "%s (solid) has a collider" % prop.name)
	for s in shapes:
		var cs := s as CollisionShape3D
		var col := _shape_aabb(cs)
		# Collider must not stick out of the model, and must cover most of it.
		_expect(model_box.grow(0.05).encloses(col),
				"%s collider fits inside its model (collider %s, model %s)" % [prop.name, col, model_box])
		var area_ratio := (col.size.x * col.size.z) / maxf(0.001, model_box.size.x * model_box.size.z)
		_expect(area_ratio >= 0.5, "%s collider covers its model (%.0f%% of footprint)" % [prop.name, area_ratio * 100.0])
		_expect(col.position.y <= GROUND_TOLERANCE and col.end.y >= minf(model_box.end.y, 1.0) - 0.05,
				"%s collider reaches from the ground to at least player height" % prop.name)


func _shape_aabb(cs: CollisionShape3D) -> AABB:
	var local: AABB
	if cs.shape is BoxShape3D:
		var size := (cs.shape as BoxShape3D).size
		local = AABB(-size / 2.0, size)
	elif cs.shape is CylinderShape3D:
		var cyl := cs.shape as CylinderShape3D
		local = AABB(Vector3(-cyl.radius, -cyl.height / 2.0, -cyl.radius), Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0))
	else:
		local = AABB()
	return ModelUtil._relative_transform(_island, cs) * local


func _check_overlaps(props: Array[Node3D], boxes: Dictionary) -> void:
	for i in props.size():
		for j in range(i + 1, props.size()):
			var a: AABB = boxes[props[i]]
			var b: AABB = boxes[props[j]]
			_expect(not a.grow(-0.01).intersects(b.grow(-0.01)),
					"%s and %s don't overlap" % [props[i].name, props[j].name])


# ---------------------------------------------------------------- paths & doors

func _check_paths_and_doors(props: Array[Node3D]) -> void:
	var path_boxes: Array[AABB] = []
	for c in _island.ground_cells():
		if _island.is_path(c):
			var centre := Grid.cell_center(c, _island.map_size)
			path_boxes.append(AABB(centre - Vector3(Grid.TILE / 2.0, 0.0, Grid.TILE / 2.0), Vector3(Grid.TILE, 2.0, Grid.TILE)))
	for prop in props:
		for s in prop.get_node("Body").find_children("*", "CollisionShape3D", true, false):
			var col := _shape_aabb(s as CollisionShape3D).grow(-0.01)
			for pb in path_boxes:
				_expect(not col.intersects(pb), "%s collider stays out of the path" % prop.name)
		if String(prop.name).begins_with("house"):
			# The door is in the front-left module: the tile in front must be walkable.
			var cell: Vector2i = prop.get_meta("cell")
			var size: Vector2i = prop.get_meta("size")
			var door_front := cell + Vector2i(0, size.y)
			_expect(_island.is_path(door_front) or (_island.is_ground(door_front) and not _island.occupied.has(door_front)),
					"%s door opens onto a walkable tile %s" % [prop.name, door_front])


# ---------------------------------------------------------------- ground

func _check_ground() -> void:
	var floor_cells := {}
	for s in _island.get_node("FloorBody").get_children():
		var cs := s as CollisionShape3D
		floor_cells[Grid.world_to_cell(cs.position, _island.map_size)] = true
	var wall_cells := {}
	for s in _island.get_node("EdgeWalls").get_children():
		var cs := s as CollisionShape3D
		wall_cells[Grid.world_to_cell(cs.position, _island.map_size)] = true
	var ground: Array = _island.ground_cells()
	for c in ground:
		_expect(floor_cells.has(c), "ground tile %s has floor under it" % c)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not _island.is_ground(n):
				_expect(wall_cells.has(n), "edge next to %s is walled (at %s)" % [c, n])
	_expect(floor_cells.size() == ground.size(), "one floor tile per ground tile (%d / %d)" % [floor_cells.size(), ground.size()])
	# The ground mesh (grass + rocky underside) must cover every tile without gaps.
	var mesh: Mesh = (_island.get_node("Ground") as MeshInstance3D).mesh
	var faces := mesh.get_faces()
	var top_cells := {}
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var y := a.y
		if is_equal_approx(a.y, b.y) and is_equal_approx(a.y, c.y) and (is_zero_approx(y) or is_equal_approx(y, -_island.PATH_DEPTH)):
			top_cells[Grid.world_to_cell((a + b + c) / 3.0, _island.map_size)] = true
	for c in ground:
		_expect(top_cells.has(c), "ground surface covers tile %s" % c)
	# Every path tile has a paving tile whose top is flush with the grass.
	var paving := {}
	for t in _island.get_node("PathTiles").get_children():
		var box := ModelUtil.aabb_in(t as Node3D, _island)
		var cell: Vector2i = t.get_meta("cell")
		paving[cell] = true
		_expect(absf(box.position.y) <= GROUND_TOLERANCE, "path tile %s sits flush on the ground (y=%.3f)" % [cell, box.position.y])
		_expect(box.end.y <= 0.06, "path tile %s stones stay low enough to walk over (%.3f)" % [cell, box.end.y])
		var r := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		var centre := Grid.cell_center(cell, _island.map_size)
		var tile_rect := Rect2(Vector2(centre.x, centre.z) - Vector2.ONE * Grid.TILE / 2.0, Vector2.ONE * Grid.TILE)
		_expect(tile_rect.grow(0.01).encloses(r) and r.size.x > Grid.TILE - 0.02 and r.size.y > Grid.TILE - 0.02,
				"path tile %s exactly fills its tile (%s)" % [cell, r])
	for c in ground:
		if _island.is_path(c):
			_expect(paving.has(c), "path tile %s is paved" % c)
	# Cliff walls: under the grass layer, faces on the island edge, never sticking out.
	var island_rect := Rect2(-Vector2(_island.map_size) * Grid.TILE / 2.0, Vector2(_island.map_size) * Grid.TILE)
	var cliff_count := 0
	for w in _island.get_node("Cliffs").get_children():
		var box := ModelUtil.aabb_in(w as Node3D, _island)
		cliff_count += 1
		_expect(box.end.y <= -_island.GRASS_THICKNESS + GROUND_TOLERANCE, "%s stays under the grass layer" % w.name)
		_expect(island_rect.grow(0.02).encloses(Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))),
				"%s doesn't stick out past the island edge" % w.name)
	var edge_faces := 0
	for c in ground:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _island.is_ground(c + d):
				edge_faces += 1
	_expect(cliff_count == edge_faces, "every outer edge has a cliff wall (%d / %d)" % [cliff_count, edge_faces])
	_check_coplanar(mesh)
	var mesh_box := mesh.get_aabb()
	_expect(mesh_box.position.y < -Grid.TILE, "rocky underside hangs below the island (bottom y=%.1f)" % mesh_box.position.y)


## Two visible surfaces in the same plane flicker (z-fighting). Every
## outside-facing triangle of the cliffs is compared against the ground mesh
## and against the other cliffs; any pair that lies in the same plane (within
## 2 mm), faces the same way and overlaps is reported.
func _check_coplanar(ground_mesh: Mesh) -> void:
	var buckets := {}  # Vector3i(axis, facing, plane_mm) -> Array of [source, Rect2]
	_add_faces(buckets, "ground", ground_mesh, Transform3D.IDENTITY)
	for w in _island.get_node("Cliffs").get_children():
		for mi in (w as Node).find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			_add_faces(buckets, String(w.name), m.mesh, ModelUtil._relative_transform(_island, m))
	var clashes := 0
	var examples: Array[String] = []
	for key: Vector3i in buckets:
		var here: Array = buckets[key]
		var next: Array = buckets.get(key + Vector3i(0, 0, 1), [])
		for i in here.size():
			var others: Array = here.slice(i + 1) + next
			for b: Array in others:
				var a: Array = here[i]
				if a[0] == b[0] or (a[0] == "ground" and b[0] == "ground"):
					continue
				if (a[1] as Rect2).intersection(b[1] as Rect2).get_area() > 0.0004:
					clashes += 1
					if examples.size() < 3:
						examples.append("%s vs %s (axis %d, plane %.3f m)" % [a[0], b[0], key.x, key.z / 500.0])
	_expect(clashes == 0, "no flickering overlaps between cliffs and rock (%d found%s)" % [clashes, (": " + ", ".join(examples)) if clashes > 0 else ""])


## True if `p` lies (within 5 cm) on a tile edge between a ground tile and sky.
func _on_outer_edge(p: Vector3, axis: int) -> bool:
	var step := Vector3.ZERO
	step[axis] = 0.05
	var inside: bool = _island.is_ground(Grid.world_to_cell(p - step, _island.map_size))
	var outside: bool = _island.is_ground(Grid.world_to_cell(p + step, _island.map_size))
	return inside != outside


## Adds every axis-aligned triangle to a bucket keyed by its axis, which way
## it faces, and its plane position in 2 mm steps.
func _add_faces(buckets: Dictionary, source: String, mesh: Mesh, xf: Transform3D) -> void:
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var a := xf * faces[i]
		var b := xf * faces[i + 1]
		var c := xf * faces[i + 2]
		var n := (b - a).cross(c - a)
		if n.length() < 1e-6:
			continue
		n = n.normalized()
		var axis := n.abs().max_axis_index()
		if absf(n[axis]) < 0.999:
			continue
		# Only the island's outside walls can be seen: a vertical face counts
		# when it lies on a tile edge with ground on one side and sky on the other.
		if axis == 1 or not _on_outer_edge((a + b + c) / 3.0, axis):
			continue
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var rect := Rect2(Vector2(a[u], a[v]), Vector2.ZERO).expand(Vector2(b[u], b[v])).expand(Vector2(c[u], c[v]))
		var key := Vector3i(axis, 1 if n[axis] > 0.0 else -1, roundi(a[axis] * 500.0))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append([source, rect])


# ---------------------------------------------------------------- player

func _check_player(player: Node3D) -> void:
	_expect(absf(player.global_position.y) <= 0.02, "player stands on the ground (y=%.3f)" % player.global_position.y)
	var box := ModelUtil.aabb_in(player.get_node("Visual"), player)
	_expect(absf(box.position.y) <= GROUND_TOLERANCE, "player model's feet are flush with the ground (%.3f)" % box.position.y)
	_expect(box.size.x <= Grid.TILE and box.size.z <= Grid.TILE, "player model fits in one tile (%s)" % box.size)


# ---------------------------------------------------------------- helpers

func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	_failures += 1
	print("FAIL  " + what)
