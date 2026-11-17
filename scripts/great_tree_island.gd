extends "res://scripts/island.gd"
## The Great Tree's island: the biggest island, 32 x 32 tiles, with the
## withered Great Tree in the middle. Same grid, ground, cliffs and props as
## the other islands; the outline, decoration and tree are generated from a
## fixed seed, so it's the same every time but no two areas look alike.

const SIZE := 32
const TREE_CELL := Vector2i(16, 15)
## Path from the landing tile north to the sealed entrance (this column).
const PATH_X := 16
const PATH_FROM_ROW := 21
## A walking ring around the trunk (distance from its centre, m) stays clear
## of decoration so the player can always walk all the way round.
const RING_MIN := 15.0
const RING_MAX := 22.0

const NK := "res://Assets/Nature Kit/Models/GLTF format/"
const SK := "res://Assets/Survival Kit/Models/GLB format/"
const PK := "res://Assets/Platformer Kit/Models/GLB format/"
const MF := "res://Assets/Mini Forest/Models/GLB format/"

const ENTRANCE_DIALOGUE := "res://data/dialogue/great_tree_entrance.json"

var tree: GreatTree
var _map_rows: Array[String] = []


# ---------------------------------------------------------------- layout

func _map() -> Array[String]:
	if _map_rows.is_empty():
		for z in SIZE:
			var row := ""
			for x in SIZE:
				row += _tile_char(Vector2i(x, z))
			_map_rows.append(row)
	return _map_rows


## Round, wobbly outline (never a square), a tongue of land to the south for
## the launch point, and a path up to the trunk.
func _tile_char(c: Vector2i) -> String:
	var d := Vector2(c.x + 0.5 - (TREE_CELL.x + 0.5), c.y + 0.5 - (TREE_CELL.y + 0.5))
	var a := d.angle()
	var edge := 14.2 + 1.1 * sin(3.0 * a + 0.8) + 0.7 * sin(5.0 * a + 2.1) + 0.45 * cos(9.0 * a)
	var tongue := c.x >= PATH_X - 1 and c.x <= PATH_X + 1 and c.y >= 26
	if d.length() >= edge and not tongue:
		return "."
	if c.x == PATH_X and c.y >= PATH_FROM_ROW and c.y <= SIZE - 2:
		return "="
	return "#"


func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(PATH_X, SIZE - 1), "dir": Vector2i(0, 1), "flag": Vector2i(PATH_X - 1, SIZE - 1)}


func _villager_layout() -> Array[Dictionary]:
	return []


## The tree goes in before any props, and takes its tiles.
func _reserve_extra() -> void:
	tree = GreatTree.new()
	add_child(tree)
	tree.build(self, Grid.cell_center(TREE_CELL, map_size), get_node_or_null(player_path))
	for cell in tree.claimed:
		occupied[cell] = "great_tree"


## Tiles nothing may stand on apart from the player: path, ring round the
## trunk, the entrance, the launch point, its flag and landing tile.
func _keep_clear(cell: Vector2i) -> bool:
	if is_path(cell) or occupied.has(cell):
		return true
	var launch := _launch_layout()
	var lc: Vector2i = launch["cell"]
	if cell == lc or cell == launch["flag"] or cell == lc - launch["dir"]:
		return true
	if (cell - lc).length_squared() <= 2:
		return true
	if cell in tree.entrance_cells():
		return true
	var r := (Grid.cell_center(cell, map_size) - tree.position).length()
	if r >= RING_MIN and r <= RING_MAX:
		return true
	# One tile either side of the path stays open too.
	if absi(cell.x - PATH_X) <= 1 and cell.y >= PATH_FROM_ROW - 1:
		return true
	return false


## Natural decoration, placed from a fixed seed. Each kind of spot gets its
## own mix, so the island never looks copy-pasted:
##  near the trunk: mushrooms, moss, old stumps, roots' rubble;
##  open meadow: grass, flowers, bushes, fallen logs, rocks;
##  near the edge: tall stones and big rocks.
func _prop_layout() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out: Array[Dictionary] = []
	var taken := {}
	var cells := ground_cells()
	for cell in cells:
		if taken.has(cell) or _keep_clear(cell):
			continue
		var r := (Grid.cell_center(cell, map_size) - tree.position).length()
		var near_edge := _edge_distance(cell) <= 1
		var roll := rng.randf()
		var rot := rng.randf_range(0.0, 360.0)
		var item := {}
		if r < RING_MIN:
			# Shady ground under the trunk.
			if roll < 0.22:
				item = _nature(NK + ["mushroom_redGroup.glb", "mushroom_tanGroup.glb", "mushroom_redTall.glb", "mushroom_tanTall.glb"][rng.randi() % 4], 0.55, rot, true)
			elif roll < 0.4:
				item = _nature(SK + "patch-grass-large.glb", 0.9, rot, false)
			elif roll < 0.5:
				item = _nature(NK + ["stump_old.glb", "stump_roundDetailed.glb"][rng.randi() % 2], 0.6, rot, true)
		elif near_edge:
			if roll < 0.18:
				item = _nature(NK + ["stone_tallA.glb", "stone_tallC.glb", "rock_tallB.glb", "rock_tallE.glb"][rng.randi() % 4], 0.6, rot, true)
			elif roll < 0.32:
				item = _nature(NK + ["rock_largeA.glb", "rock_largeC.glb", "stone_largeB.glb", "rock_largeE.glb"][rng.randi() % 4], 0.75, rot, true)
			elif roll < 0.45:
				item = _nature(NK + ["grass_large.glb", "grass_leafsLarge.glb"][rng.randi() % 2], 0.6, rot, false)
		else:
			# Open meadow.
			if roll < 0.07:
				# Fallen log across two tiles, if the next tile is free too.
				var along := Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
				var other := cell + along
				if is_ground(other) and not taken.has(other) and not _keep_clear(other):
					item = _nature(NK + ["log_large.glb", "log_stackLarge.glb"][rng.randi() % 2], 0.85, 0.0 if along.x != 0 else 90.0, true)
					item["size"] = Vector2i(2, 1) if along.x != 0 else Vector2i(1, 2)
					taken[other] = true
			elif roll < 0.15:
				item = _nature(NK + ["plant_bushLarge.glb", "plant_bushDetailed.glb", "plant_bush.glb", "plant_bushTriangle.glb"][rng.randi() % 4], 0.7, rot, true)
			elif roll < 0.22:
				item = _nature(NK + ["rock_smallA.glb", "rock_smallC.glb", "stone_smallB.glb", "rock_smallFlatA.glb", "stone_smallTopA.glb"][rng.randi() % 5], 0.45, rot, true)
			elif roll < 0.36:
				item = _nature(NK + ["grass.glb", "grass_large.glb", "grass_leafs.glb", "grass_leafsLarge.glb"][rng.randi() % 4], 0.6, rot, false)
			elif roll < 0.44:
				item = _nature(NK + ["flower_redA.glb", "flower_yellowB.glb", "flower_purpleC.glb", "flower_yellowA.glb", "flower_redC.glb"][rng.randi() % 5], 0.45, rot, false)
			elif roll < 0.5:
				item = _nature(MF + ["patch-grass.glb", "patch-dirt.glb"][rng.randi() % 2], 0.9, rot, false)
		if item.is_empty():
			continue
		item["cell"] = cell
		taken[cell] = true
		out.append(item)
	return out


func _nature(path: String, fill: float, rot: float, solid: bool) -> Dictionary:
	return {"type": "nature", "model": path, "fill": fill, "rot": rot, "solid": solid}


# ---------------------------------------------------------------- entrance & anchors

func _after_build() -> void:
	var cells := tree.entrance_cells()
	var stand := cells[1]
	var trigger := Area3D.new()
	trigger.set_script(preload("res://scripts/door_trigger.gd"))
	trigger.name = "EntranceTrigger"
	trigger.set_meta("cell", stand)
	add_child(trigger)
	trigger.setup(Grid.cell_center(stand, map_size), Vector3(0.0, 4.6, -2.6), _speak_to_tree)


func _speak_to_tree() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ENTRANCE_DIALOGUE))
	if data is Dictionary:
		DialogueBox.open(data["name"], data["conversations"][0])


## "tree": origin at the trunk centre, oriented like the launch anchor.
func cutscene_anchor(anchor_name: String) -> Transform3D:
	if anchor_name == "tree":
		var launch := super.cutscene_anchor("launch")
		return Transform3D(launch.basis, tree.global_position)
	return super.cutscene_anchor(anchor_name)


## Tiles the tree blocks, for the checks.
func extra_blocked_cells() -> Dictionary:
	return tree.claimed if tree else {}
