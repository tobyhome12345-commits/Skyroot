extends SceneTree
## Sky check: the distant islands seen from every island. Fails if:
##  - an island's distant view isn't at its place in data/sky_map.json, or
##    appears in a different place from different islands
##  - a distant view sits inside (or near) the island you're on, closer than
##    its playable area, or inside the cloud lanes round it
##  - two distant views overlap on screen, seen from the island's camera on
##    its landing tile
##  - a distant view can't be seen: it must show from the landing tile, or,
##    where the island you're on hides it there, from somewhere else on it
##    (Leafwind's canopy framing counts as hiding)
##  - a distant view has collision or shadows, is not low-poly, doesn't
##    share its material, or keeps working while off screen
##  - a glide doesn't head for its destination's place in the sky (or come
##    in from the island it left), turns back over the island, or its path
##    runs low over land
## Usage: godot_console --headless --path . --script res://tools/check_sky.gd
##   add "-- selftest" to plant problems and prove they're caught.

const ISLANDS := {
	"pebblenook": "res://scenes/pebblenook.tscn",
	"great_tree": "res://scenes/great_tree_island.tscn",
	"leafwind": "res://scenes/leafwind.tscn",
	"lookout_isle": "res://scenes/lookout_isle.tscn",
	"traders_rock": "res://scenes/traders_rock.tscn",
	"seed_isle": "res://scenes/seed_isle.tscn",
}
const ASPECT := 16.0 / 9.0
## How deep under an island its rock / branches hide things (m).
const UNDERSIDE := 14.0
const MAX_TRIANGLES := 4000

var _failures := 0
var _checks := 0
var _where := ""
var _offsets := {}  # id -> offset seen from the first island
var _selftest := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_selftest = "selftest" in OS.get_cmdline_user_args()
	var game := root.get_node("/root/Game")
	for id: String in ISLANDS:
		_where = id
		var before := _failures
		change_scene_to_file(ISLANDS[id])
		for i in 10:
			await process_frame
		var island := current_scene.get_node("Island")
		if _selftest:
			_break_things(island, id)
		_check_places(island)
		_check_cost(island)
		_check_clouds(island)
		await _check_views(island)
		_check_glides(island, game)
		print("%-13s %s" % [id, "ok" if _failures == before else "%d problem(s)" % (_failures - before)])
	_where = "sky map"
	for id: String in SkyMap.ids():
		_expect(ISLANDS.has(id), "%s in the sky map is a real island" % id)
	for id in ["rootholm", "barkton", "seedhaven"]:
		_expect(not SkyMap.has_place(id), "%s has an empty slot for later" % id)
	print("RESULT: %s (%d checks)" % ["ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _landmarks(island: Node) -> Array:
	return island.get_node("DistantViews").get_children().filter(func(n: Node) -> bool: return n is DistantLandmark)


# ---------------------------------------------------------------- places

func _check_places(island: Node3D) -> void:
	var shown := {}
	for lm: DistantLandmark in _landmarks(island):
		var id := lm.island_id
		shown[id] = true
		var off := lm.global_position - island.global_position
		_expect(off.is_equal_approx(SkyMap.offset(id)), "%s is at its place in the sky map (%s)" % [id, off])
		if _offsets.has(id):
			_expect((_offsets[id] as Vector3).is_equal_approx(off), "%s appears in the same place as from the other islands" % id)
		else:
			_offsets[id] = off
		# Well away from this island and its playable area.
		var half := Vector2(island.map_size) * Grid.TILE / 2.0
		var here := AABB(Vector3(-half.x, -40.0, -half.y), Vector3(half.x * 2.0, 160.0, half.y * 2.0)).grow(30.0)
		var box := _box(lm, island)
		_expect(not box.intersects(here), "%s stays well clear of this island" % id)
		_expect(off.length() > half.length() * 4.0, "%s is far beyond the playable area (%.0f m)" % [id, off.length()])
	for id: String in SkyMap.ids():
		if id != island.island_id:
			_expect(shown.has(id), "%s is shown in the sky" % id)
	_expect(not shown.has(island.island_id), "the island doesn't show itself")


func _box(lm: Node3D, space: Node3D) -> AABB:
	return ModelUtil.aabb_in(lm, space)


# ---------------------------------------------------------------- cost

func _check_cost(island: Node3D) -> void:
	var mats := {}
	for lm: DistantLandmark in _landmarks(island):
		var id := lm.island_id
		_expect(lm.find_children("*", "CollisionObject3D", true, false).is_empty() and lm.find_children("*", "CollisionShape3D", true, false).is_empty(),
				"%s has no collision" % id)
		var tris := 0
		for g in lm.find_children("*", "GeometryInstance3D", true, false):
			_expect((g as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadows (%s)" % [id, g.name])
			if g is MeshInstance3D and (g as MeshInstance3D).mesh:
				tris += (g as MeshInstance3D).mesh.get_faces().size() / 3
				if id != "great_tree":
					mats[(g as MeshInstance3D).material_override] = true
		if id != "great_tree":
			_expect(tris <= MAX_TRIANGLES, "%s is low-poly (%d triangles)" % [id, tris])
		_expect(lm.find_child("OnScreen", false, false) is VisibleOnScreenNotifier3D, "%s only works while on screen" % id)
	_expect(mats.size() <= 2, "the distant islands share their materials (%d)" % mats.size())


func _check_clouds(island: Node3D) -> void:
	var clouds := current_scene.get_node_or_null("Clouds") as Node3D
	if clouds == null:
		return
	var lanes := ModelUtil.aabb_in(clouds, island)
	var wrap := float(clouds.get("wrap_tiles")) * Grid.TILE + 6.0
	lanes = lanes.merge(AABB(Vector3(-wrap, lanes.position.y, lanes.position.z), Vector3(wrap * 2.0, lanes.size.y, lanes.size.z)))
	for lm: DistantLandmark in _landmarks(island):
		_expect(not _box(lm, island).intersects(lanes.grow(4.0)), "%s keeps out of the cloud lanes round the island" % lm.island_id)


# ---------------------------------------------------------------- views

## The game camera for the player standing on `cell`.
func _camera_at(island: Node3D, cell: Vector2i) -> Transform3D:
	var cam := current_scene.get_node("Camera") as Camera3D
	var pitch := deg_to_rad(float(cam.get("pitch_degrees")))
	var focus: Vector3 = island.to_global(island.cell_pos(cell))
	var pos := focus + Vector3(0.0, sin(pitch), cos(pitch)) * float(cam.get("distance"))
	return Transform3D(Basis.from_euler(Vector3(-pitch, 0.0, 0.0)), pos)


## Screen position (-1..1 both ways, +y up) of a world point, or null.
func _screen(xf: Transform3D, fov: float, p: Vector3) -> Variant:
	var local := xf.affine_inverse() * p
	if local.z > -0.1:
		return null
	var t := tan(deg_to_rad(fov / 2.0))
	return Vector2(local.x / (-local.z * t * ASPECT), local.y / (-local.z * t))


## Screen rectangle of a landmark (its box's corners).
func _screen_rect(xf: Transform3D, fov: float, box: AABB) -> Rect2:
	var r := Rect2()
	var first := true
	for i in 8:
		var s = _screen(xf, fov, box.get_endpoint(i))
		if s == null:
			continue
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


## Can the camera see this point: on screen, not under Leafwind's canopy
## framing, and not hidden behind / under the island it stands on?
func _sees(island: Node3D, xf: Transform3D, fov: float, p: Vector3) -> bool:
	var s = _screen(xf, fov, p)
	if s == null or absf(s.x) > 0.97 or absf(s.y) > 0.97:
		return false
	if island.get("FRAME_TOP") != null and (s.y > island.FRAME_TOP or absf(s.x) > island.FRAME_SIDE):
		return false
	var from := island.to_local(xf.origin)
	var to := island.to_local(p)
	var tree = island.get("tree")
	for i in range(1, 600):
		var q := from.lerp(to, float(i) / 600.0)
		var cell := Grid.world_to_cell(q, island.map_size)
		if island.is_ground(cell) and q.y <= 0.3 + float(island.cell_level(cell)) * island.LEVEL_HEIGHT and q.y >= -UNDERSIDE:
			return false
		if tree != null:
			var r := Vector2(q.x - tree.position.x, q.z - tree.position.z).length()
			if (q.y >= -1.0 and q.y <= 80.0 and r < 10.0) or (q.y >= 60.0 and q.y <= 112.0 and r < 37.0):
				return false
	return true


## Points that stand for a landmark: its middle, and for the tall Great Tree
## its trunk and crown too.
func _marks(lm: DistantLandmark, island: Node3D) -> Array[Vector3]:
	var box := _box(lm, island)
	var pts: Array[Vector3] = [island.to_global(box.get_center())]
	if lm.island_id == "great_tree":
		pts.append(lm.global_position + Vector3(0.0, 40.0, 0.0))
		pts.append(lm.global_position + Vector3(0.0, 88.0, 0.0))
	return pts


func _check_views(island: Node3D) -> void:
	var cam := current_scene.get_node("Camera") as Camera3D
	var fov := cam.fov
	var landing: Vector2i = island.landing_cell
	var xf := _camera_at(island, landing)
	var lms := _landmarks(island)
	# No two landmarks overlap on screen from the landing camera.
	var rects := {}
	for lm: DistantLandmark in lms:
		rects[lm.island_id] = _screen_rect(xf, fov, _box(lm, island))
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			_expect(not (rects[ids[i]] as Rect2).intersects(rects[ids[j]]),
					"%s and %s don't overlap on screen (%s / %s)" % [ids[i], ids[j], rects[ids[i]], rects[ids[j]]])
	# Each one shows from the landing tile, or from somewhere else on the
	# island where the island hides it at the landing tile.
	for lm: DistantLandmark in lms:
		var seen_at := Vector2i(-1, -1)
		if _sees_any(island, xf, fov, _marks(lm, island)):
			seen_at = landing
		else:
			for c: Vector2i in island.ground_cells():
				if island.occupied.has(c) or island.is_walkway(c) and not island.is_path(c):
					continue
				if _sees_any(island, _camera_at(island, c), fov, _marks(lm, island)):
					seen_at = c
					break
		_expect(seen_at.x >= 0, "%s can be seen from this island" % lm.island_id)
		if seen_at != landing and seen_at.x >= 0:
			print("      %s is hidden by the island at the landing tile; seen from %s" % [lm.island_id, seen_at])
	await process_frame


func _sees_any(island: Node3D, xf: Transform3D, fov: float, pts: Array[Vector3]) -> bool:
	for p in pts:
		if _sees(island, xf, fov, p):
			return true
	return false


# ---------------------------------------------------------------- glides

## Every glide from here heads for its destination's place in the sky (as
## far as it can turn without doubling back), and every glide arriving
## here comes in from the island it left. Neither runs low over land.
func _check_glides(island: Node3D, game: Node) -> void:
	var out := Vector3(island.launch_dir.x, 0.0, island.launch_dir.y)
	var here: String = island.island_id
	for other: String in SkyMap.ids():
		if other == here or not ISLANDS.has(other):
			continue
		# Leaving for `other`.
		game.glide_dest = other
		var dep: Transform3D = island.cutscene_anchor("depart@6.5")
		var heading := dep.basis.z.normalized()
		heading.y = 0.0
		var want := SkyMap.heading(other)
		var turn := absf(rad_to_deg(out.signed_angle_to(want, Vector3.UP)))
		var got := rad_to_deg(heading.angle_to(want))
		_expect(got <= maxf(0.5, turn - island.GLIDE_MAX_TURN + 0.5), "a glide to %s heads for its place in the sky (%.0f° off, %.0f° turn needed)" % [other, got, turn])
		_expect(rad_to_deg(heading.angle_to(out)) <= island.GLIDE_MAX_TURN + 0.5, "a glide to %s never turns back over the island" % other)
		_check_path(island, _cutscene_for(game, other), 0, 2, "leaving for " + other)
		# Arriving from `other`.
		game.glide_from = other
		var arrive_file := _cutscene_for(game, here)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arrive_file))
		var anchor := _arrive_anchor_name(data)
		var arr: Transform3D = island.cutscene_anchor(anchor)
		var from_dir := arr.basis.z.normalized()
		from_dir.y = 0.0
		var want_from := SkyMap.heading(other)
		var turn_in := absf(rad_to_deg(out.signed_angle_to(want_from, Vector3.UP)))
		_expect(rad_to_deg(from_dir.angle_to(want_from)) <= maxf(0.5, turn_in - island.GLIDE_MAX_TURN + 0.5), "a glide from %s arrives from its place in the sky" % other)
		_check_path(island, arrive_file, 1, 0, "arriving from " + other)
	game.glide_from = ""
	game.glide_dest = ""


func _cutscene_for(game: Node, dest: String) -> String:
	for i: Dictionary in game.islands():
		if i["id"] == dest and i.has("cutscene"):
			return i["cutscene"]
	return game.GLIDE_CUTSCENE


func _arrive_anchor_name(data: Dictionary) -> String:
	for p in data["parts"][1]["shots"][0]["player"]["path"]:
		if p is Dictionary and String(p.get("anchor", "")).begins_with("arrive@"):
			return p["anchor"]
	return "launch"


## The player's path in one shot, resolved on this island: no point may be
## over the island's land lower than 6 m above its floor.
func _check_path(island: Node3D, file: String, part: int, shot: int, what: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	var pts: Array = data["parts"][part]["shots"][shot]["player"]["path"]
	var resolved: Array[Vector3] = []
	for p in pts:
		if p is Dictionary:
			resolved.append(island.cutscene_anchor(p["anchor"]) * Vector3(p["at"][0], p["at"][1], p["at"][2]))
		else:
			resolved.append(island.cutscene_anchor("launch") * Vector3(p[0], p[1], p[2]))
	var low := false
	for i in resolved.size() - 1:
		for k in 11:
			var q := island.to_local(resolved[i].lerp(resolved[i + 1], k / 10.0))
			var cell := Grid.world_to_cell(q, island.map_size)
			var floor_y: float = float(island.cell_level(cell)) * float(island.LEVEL_HEIGHT)
			if island.is_ground(cell) and cell != island.landing_cell and cell != island.launch_cell and q.y < floor_y + 6.0 and q.y > -UNDERSIDE:
				low = true
	_expect(not low, "the glide path %s stays clear of the island" % what)


# ---------------------------------------------------------------- self-test

func _break_things(island: Node3D, id: String) -> void:
	var lms := _landmarks(island)
	if id == "lookout_isle" and lms.size() >= 2:
		print("SELFTEST (lookout_isle): put %s on top of %s, and %s inside the island" % [lms[0].name, lms[1].name, lms[2].name])
		(lms[0] as Node3D).position = (lms[1] as Node3D).position + Vector3(2.0, 0.0, 0.0)
		(lms[2] as Node3D).position = Vector3(0.0, -10.0, 0.0)
	elif id == "seed_isle" and not lms.is_empty():
		print("SELFTEST (seed_isle): move %s to a different place" % lms[0].name)
		(lms[0] as Node3D).position += Vector3(30.0, 0.0, 0.0)


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL  [%s] %s" % [_where, what])
