extends SceneTree
## Great Tree test:
##  - the trunk and roots are solid: walking straight at the tree from 8
##    directions stops the player outside the trunk
##  - the player can walk all the way round (24 points on a ring, each
##    walked to from the last)
##  - walking behind the trunk fades it out; in front, it's solid again
##  - the sealed entrance: prompt, E opens "The tree is silent." from the
##    dialogue file, the player can't move, E closes it, nothing opens
##  - one shared health value: changing it recolours bark and leaves, shows
##    more leaves and fewer falling ones, on the full tree and the distant one
##  - the distant tree is on every other island, low-detail, far away
## Usage: godot_console --headless --path . --script res://tools/test_great_tree.gd

var _failures := 0
var _box: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_box = root.get_node("/root/DialogueBox")
	change_scene_to_file("res://scenes/great_tree_island.tscn")
	await _frames(10)
	var island := current_scene.get_node("Island")
	var tree: GreatTree = island.tree
	var player := current_scene.get_node("Player") as CharacterBody3D
	var c := tree.global_position

	# Solid trunk: walk at it from 8 directions.
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		var start := _free_tile_near(island, c + dir * 18.0)
		player.spawn_at(Grid.cell_center(start, island.map_size))
		await _physics(3)
		await _hold_towards(player, c, 4.0)
		var d := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
		_check(d > 9.0 and player.global_position.y > -0.2,
				"walking at the tree from %d deg stops outside the trunk (%.1f m)" % [i * 45, d])

	# Walk all the way round.
	var ring_r := 18.5
	player.spawn_at(Grid.cell_center(_free_tile_near(island, c + Vector3(0, 0, ring_r)), island.map_size))
	await _physics(3)
	var reached := 0
	for i in range(1, 25):
		var a := PI / 2.0 + TAU * i / 24.0
		var target := c + Vector3(cos(a), 0, sin(a)) * ring_r
		await _hold_towards(player, target, 2.5)
		if Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length() < 2.6:
			reached += 1
	_check(reached >= 23, "walked all the way round the tree (%d / 24 points)" % reached)

	# Fade: behind the trunk (north of it) the trunk fades; in front it doesn't.
	var trunk := tree.occluders.size() - 1
	var behind_cell := _free_tile_near(island, c + Vector3(0, 0, -19))
	player.spawn_at(Grid.cell_center(behind_cell, island.map_size))
	await create_timer(1.5).timeout  # the fade runs in real time
	_check(tree.is_faded(trunk), "walking behind the trunk fades it out")
	player.spawn_at(Grid.cell_center(_free_tile_near(island, c + Vector3(0, 0, 19)), island.map_size))
	await create_timer(1.5).timeout
	_check(not tree.is_faded(trunk), "in front of the trunk it's solid again")

	# Sealed entrance.
	var stand: Vector2i = tree.entrance_cells()[1]
	player.spawn_at(Grid.cell_center(stand, island.map_size))
	await _physics(10)
	var trig := island.get_node("EntranceTrigger")
	_check(trig.is_prompt_visible(), "the prompt shows at the sealed entrance")
	await _press(KEY_E)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/great_tree_entrance.json"))
	_check(_box.is_open() and _box.current_text() == "The tree is silent." and data["conversations"][0][0] == "The tree is silent.",
			"E opens the dialogue box: %s (from the dialogue file)" % _box.current_text())
	var before := player.global_position
	Input.action_press("move_down")
	await _physics(15)
	Input.action_release("move_down")
	_check(player.global_position.distance_to(before) < 0.01, "the player can't move while it's open")
	while _box.is_open():
		await _press(KEY_E)
	_check(not _box.is_open(), "E closes it")
	_check(current_scene.scene_file_path.ends_with("great_tree_island.tscn"), "nothing opens (still outside)")

	# One health value.
	var bark0 := TreeLook.bark().albedo_color
	var leaf0 := TreeLook.leaf().albedo_color
	var shown0 := _shown(tree)
	var fall0 := tree.falling.amount
	var far := DistantTree.new()
	current_scene.add_child(far)
	await _frames(2)
	TreeLook.set_health(1.0, self)
	await _frames(2)
	var shown1 := _shown(tree)
	_check(TreeLook.bark().albedo_color != bark0 and TreeLook.leaf().albedo_color != leaf0, "health changes bark and leaf colours")
	_check(TreeLook.leaf().albedo_color.g > TreeLook.leaf().albedo_color.r, "healthy leaves are green")
	_check(shown1 > shown0, "health shows more leaves (%d -> %d)" % [shown0, shown1])
	_check(tree.falling.amount < fall0, "health means fewer falling leaves (%d -> %d)" % [fall0, tree.falling.amount])
	var far_leaf := far.find_children("*", "MeshInstance3D", true, false).filter(
			func(m: MeshInstance3D) -> bool: return m.material_override == TreeLook.leaf())
	_check(not far_leaf.is_empty(), "the distant tree shares the same leaf material")
	TreeLook.set_health(0.0, self)
	await _frames(2)
	_check(TreeLook.bark().albedo_color == bark0 and _shown(tree) == shown0, "setting health back to 0 restores the withered look")

	# Distant tree on the other islands, cheap.
	for path: String in ["res://scenes/pebblenook.tscn", "res://scenes/lookout_isle.tscn", "res://scenes/traders_rock.tscn", "res://scenes/seed_isle.tscn", "res://scenes/leafwind.tscn"]:
		change_scene_to_file(path)
		await _frames(10)
		var dt := current_scene.find_child("DistantTree", true, false) as Node3D
		_check(dt != null, "%s shows the distant tree" % path.get_file())
		if dt:
			var meshes := dt.find_children("*", "MeshInstance3D", true, false)
			_check(meshes.size() <= 30, "the distant tree is low-detail (%d meshes)" % meshes.size())
			_check(dt.global_position.length() > 300.0, "it's far away (%.0f m)" % dt.global_position.length())

	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _shown(tree: GreatTree) -> int:
	var n := 0
	for leaf in tree.canopy:
		if leaf.visible:
			n += 1
	return n


func _free_tile_near(island: Node, p: Vector3) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1.0e9
	for cell: Vector2i in island.ground_cells():
		if island.occupied.has(cell):
			continue
		var d := Grid.cell_center(cell, island.map_size).distance_to(Vector3(p.x, 0, p.z))
		if d < best_d:
			best_d = d
			best = cell
	return best


## Steers the player towards a point by holding the movement keys.
func _hold_towards(player: CharacterBody3D, target: Vector3, seconds: float) -> void:
	for i in int(seconds * 60):
		var d := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		if d.length() < 0.4:
			break
		if d.x < -0.2:
			Input.action_press("move_left")
		if d.x > 0.2:
			Input.action_press("move_right")
		if d.y < -0.2:
			Input.action_press("move_up")
		if d.y > 0.2:
			Input.action_press("move_down")
		await physics_frame
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	await _physics(3)


func _press(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
