extends SceneTree
## Great Tree attachment check. Fails (exit code 1) if:
##  - a vine / hanging piece doesn't start on a real surface (a branch, the
##    trunk), has a gap between its points, cuts through the trunk, or ends
##    floating (an "air" end too close to the ground, a "ground" end above or
##    below it, a "trunk" end off the bark)
##  - a knot or hollow isn't set into the trunk surface
##  - a branch doesn't grow out of the trunk, or a twig out of its branch
##  - a leaf blob isn't touching its branch (or the crown top)
##  - a root doesn't start inside the trunk, floats above the grass, hangs
##    over the edge through the island's rock, or two roots overlap badly
##  - a fallen leaf isn't lying flat on open grass
##  - any generated mesh (trunk, roots, branches, vines, entrance knot) has
##    triangles facing inward where they can be seen (holes / inside-out),
##    beyond tiny slivers where two pieces cross
## Usage: godot_console --headless --path . --script res://tools/check_tree.gd
##   add "-- selftest" to plant known problems and prove they're caught.

const TOL := 0.06

var _failures := 0
var _checks := 0
var _tree: GreatTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://scenes/great_tree_island.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	_tree = scene.get_node("Island").tree
	if "selftest" in OS.get_cmdline_user_args():
		_break_things()
	_check_hangers()
	_check_features()
	_check_branches()
	_check_canopy()
	_check_roots()
	_check_fallen_leaves()
	_check_faces()
	print("RESULT: %s (%d checks: %d hanging pieces, %d roots, %d branches, %d leaf blobs)" % [
		"ALL PASSED" if _failures == 0 else "%d FAILED" % _failures, _checks,
		_tree.hangers.size(), _tree.root_lines.size(), _tree.branches.size(), _tree.canopy.size()])
	quit(1 if _failures > 0 else 0)


## How far a point is outside the trunk surface (negative = inside).
func _outside_trunk(p: Vector3) -> float:
	if p.y < 0.0 or p.y > TreeLook.TRUNK_HEIGHT:
		return 99.0
	var axis := _tree.trunk_axis(p.y)
	var d := Vector2(p.x - axis.x, p.z - axis.z)
	return d.length() - _tree.trunk_radius(atan2(d.y, d.x), p.y)


## Distance from a point to a tube (centre line + radii): negative = inside.
func _outside_tube(p: Vector3, pts: Array, radii: Array) -> float:
	var best := 1.0e9
	for i in pts.size() - 1:
		var d := GreatTree._dist_to_segment(p, pts[i], pts[i + 1])
		best = minf(best, d - (float(radii[i]) + float(radii[i + 1])) / 2.0)
	return best


func _check_hangers() -> void:
	for hi in _tree.hangers.size():
		var h: Dictionary = _tree.hangers[hi]
		var pts: Array = h["points"]
		var r: float = h["radius"]
		var label := "%s %d" % [h["kind"], hi]
		var first: Vector3 = pts[0]
		var last: Vector3 = pts[pts.size() - 1]
		# Attachment: the first point sits on (just inside) its parent's surface.
		if h["attach"] == "branch":
			var br: Dictionary = _tree.branches[h["parent"]]
			var o := _outside_tube(first, br["points"], br["radii"])
			_expect(o <= TOL and o > -1.0, "%s hangs from a real point on branch %d (%.2f m off its bark)" % [label, h["parent"], o])
		else:
			var o := _outside_trunk(first)
			_expect(absf(o) <= 0.5, "%s starts on the trunk (%.2f m off the bark)" % [label, o])
		# No gaps between points.
		for i in pts.size() - 1:
			if (pts[i] as Vector3).distance_to(pts[i + 1]) > 1.6:
				_fail("%s has a gap between points %d and %d" % [label, i, i + 1])
				break
		_checks += 1
		# Never cuts through the trunk (after leaving its attachment point).
		# (Its anchored ends may sit in the bark; everything between must not.)
		var cut := false
		for i in range(1, pts.size()):
			var p: Vector3 = pts[i]
			if p.distance_to(first) < 1.0 or (h["end"] == "trunk" and p.distance_to(last) < 1.0):
				continue
			if _outside_trunk(p) < -0.05:
				cut = true
		_expect(not cut, "%s doesn't cut through the trunk" % label)
		# Hanging pieces hang under gravity: each point no higher than the last.
		if h["kind"] == "hanging_moss":
			var rising := false
			for i in pts.size() - 1:
				if (pts[i + 1] as Vector3).y > (pts[i] as Vector3).y + 0.01:
					rising = true
			_expect(not rising, "%s hangs downwards" % label)
		# The end.
		match h["end"]:
			"air":
				_expect(last.y - r > 1.0, "%s ends in the air, well clear of the ground (y=%.1f)" % [label, last.y])
			"ground":
				_expect(last.y <= r and last.y >= -r - 0.6, "%s ends on / in the ground (y=%.2f)" % [label, last.y])
			"trunk":
				_expect(absf(_outside_trunk(last)) <= 0.5, "%s ends on the trunk" % label)


func _check_features() -> void:
	for f: Dictionary in _tree.trunk_features:
		var c: Vector3 = f["center"]
		var o := _outside_trunk(c)
		var size: float = f["size"]
		# The centre sits just under the bark: half sunk, never floating or buried.
		_expect(o < 0.0 and o > -size, "%s at %.0f m is set into the bark (centre %.2f m from the surface)" % [f["kind"], f["height"], o])


func _check_branches() -> void:
	for bi in _tree.branches.size():
		var br: Dictionary = _tree.branches[bi]
		var first: Vector3 = (br["points"] as Array)[0]
		var grows_from_trunk := _outside_trunk(first) < 0.0
		var grows_from_branch := false
		for bj in _tree.branches.size():
			if bj != bi and _outside_tube(first, _tree.branches[bj]["points"], _tree.branches[bj]["radii"]) < 0.0:
				grows_from_branch = true
		_expect(grows_from_trunk or grows_from_branch, "branch %d grows out of the trunk or a branch" % bi)


func _check_canopy() -> void:
	for leaf in _tree.canopy:
		var base: Transform3D = leaf.get_meta("base")
		var size: float = leaf.get_meta("size")
		var bi: int = leaf.get_meta("branch")
		var touching: bool
		if bi >= 0:
			var br: Dictionary = _tree.branches[bi]
			touching = _outside_tube(base.origin, br["points"], br["radii"]) < size * 0.7
		else:
			touching = base.origin.distance_to(_tree.trunk_axis(TreeLook.TRUNK_HEIGHT)) < size + GreatTree.TOP_RADIUS
		_expect(touching, "a leaf blob is attached to its branch (branch %d)" % bi)


func _check_roots() -> void:
	var lines := _tree.root_lines
	for li in lines.size():
		var line: Dictionary = lines[li]
		var pts: Array = line["points"]
		var radii: Array = line["radii"]
		var label := "%s root %d" % [line["kind"], line["root"]]
		var first: Vector3 = pts[0]
		match line["kind"]:
			"inner":
				_expect(_outside_trunk(first) < 0.0, "%s starts inside the trunk" % label)
			"side":
				var parent := _main_root(line["root"])
				_expect(_outside_tube(first, parent["points"], parent["radii"]) < 0.0, "%s grows out of its main root" % label)
			"outer":
				_expect(first.y + float(radii[0]) < 0.0, "%s starts under the ground" % label)
		var floating := false
		var through_rock := false
		for i in pts.size():
			var p: Vector3 = pts[i]
			var rr: float = radii[i]
			var world := _tree.position + p
			var on_island: bool = _tree.island.is_ground(Grid.world_to_cell(world, _tree.island.map_size))
			if on_island:
				# On the island a root rests on or in the ground (or comes out of the trunk).
				if p.y - rr > TOL and _outside_trunk(p) > 0.0:
					floating = true
			elif p.y < 0.0:
				# Over the edge: hanging outside the rock, never through it.
				for d in [Vector3(rr, 0, 0), Vector3(-rr, 0, 0), Vector3(0, 0, rr), Vector3(0, 0, -rr)]:
					if _tree.island.is_ground(Grid.world_to_cell(world + d * 0.9, _tree.island.map_size)):
						through_rock = true
		_expect(not floating, "%s rests on the ground (nowhere floats above it)" % label)
		_expect(not through_rock, "%s hangs outside the island's rock" % label)
		_expect(float(radii[0]) >= float(radii[radii.size() - 1]), "%s is thick at the trunk and thins as it spreads" % label)
	# Different roots don't run through each other above the ground.
	for a in lines.size():
		for b in range(a + 1, lines.size()):
			if lines[a]["root"] == lines[b]["root"]:
				continue
			var bad := false
			for i in (lines[a]["points"] as Array).size():
				var p: Vector3 = lines[a]["points"][i]
				if p.y < 0.0 or Vector2(p.x, p.z).length() < 11.0:
					continue
				if _outside_tube(p, lines[b]["points"], lines[b]["radii"]) < -float(lines[a]["radii"][i]) * 0.5:
					bad = true
			_expect(not bad, "roots %d and %d don't run through each other" % [lines[a]["root"], lines[b]["root"]])


func _main_root(index: int) -> Dictionary:
	for line: Dictionary in _tree.root_lines:
		if line["root"] == index and line["kind"] == "inner":
			return line
	return {}


func _check_fallen_leaves() -> void:
	var spots := _tree.fallen_leaf_spots
	var bad := 0
	for t in spots:
		var cell := Grid.world_to_cell(_tree.position + t.origin, _tree.island.map_size)
		if absf(t.origin.y - 0.012) > 0.001 or not _tree.island.is_ground(cell) or _tree.claimed.has(cell) or _tree.island.is_path(cell):
			bad += 1
	_expect(bad == 0 and spots.size() > 50, "all %d fallen leaves lie flat on open grass (%d don't)" % [spots.size(), bad])


## Godot draws a triangle only from its front (clockwise) side. Every face
## of the generated tree meshes must point outwards, or the game shows holes
## and the inside of the shape.
func _check_faces() -> void:
	for mi in _tree.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh as ArrayMesh
		if mesh == null:
			continue
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bad_area := 0.0
		for i in range(0, v.size() - 2, 3):
			var face := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])
			if face.dot(n[i] + n[i + 1] + n[i + 2]) < 0.0:
				var c: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
				if _outside_trunk(c) > 0.0 and c.y > -0.05:
					bad_area += face.length() / 2.0
		_expect(bad_area < 0.05, "%s has no visible inside-out faces (%.3f m2)" % [mi.name, bad_area])


func _break_things() -> void:
	print("SELFTEST: detach a vine, lift a knot out of the bark, float a root, push a vine through the trunk")
	for h in _tree.hangers:
		if h["kind"] == "hanging_moss":
			for i in (h["points"] as Array).size():
				h["points"][i] += Vector3(0, -3.0, 0)  # gap under its branch
			break
	_tree.trunk_features[0]["center"] += Vector3(3.0, 0, 0)
	var line: Dictionary = _tree.root_lines[0]
	line["points"][line["points"].size() / 2] += Vector3(0, 2.0, 0)
	for h in _tree.hangers:
		if h["kind"] == "clinging_vine":
			h["points"][5] = _tree.trunk_axis((h["points"][5] as Vector3).y)
			break


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	_failures += 1
	print("FAIL  " + what)
