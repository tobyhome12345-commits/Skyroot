extends SceneTree
## Leafwind talk test: every villager on Leafwind (and Tamsin in her kite
## workshop) shows "Press E" when you stand beside them, E opens their own
## lines, they turn to face you, the player can't move while reading, and
## each talk shows their next conversation, cycling round. Every villager
## has a different look.
## Usage: godot_console --headless --path . --script res://tools/test_leafwind_talk.gd

const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]

var _failures := 0
var _box: Node
var _models := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_box = root.get_node("/root/DialogueBox")
	change_scene_to_file("res://scenes/leafwind.tscn")
	await _frames(10)
	var island := current_scene.get_node("Island")
	var villagers := island.get_node("Villagers").get_children()
	_check(villagers.size() == 7, "7 villagers outside on Leafwind (%d)" % villagers.size())
	for v: Villager in villagers:
		var stand := _free_neighbour(island, v.get_meta("cell"))
		await _talk_to(v, island.to_global(island.cell_pos(stand)))
	change_scene_to_file("res://scenes/interiors/kite_workshop.tscn")
	await _frames(10)
	var room := current_scene
	var tamsin := room.get_node("Villagers").get_child(0) as Villager
	var cell: Vector2i = tamsin.get_meta("cell")
	await _talk_to(tamsin, room.to_global(room.cell_center(cell + Vector2i(-1, 0))))
	_check(_models.size() == 8, "8 villagers, each with a different look (%d looks)" % _models.size())
	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## A walkable tile next to the villager, on the same floor.
func _free_neighbour(island: Node, cell: Vector2i) -> Vector2i:
	for d in DIRS:
		var n := cell + d
		if n in island.walk_links(cell) and not island.occupied.has(n) and not island.is_stairs(n):
			return n
	return cell + DIRS[0]


func _talk_to(v: Villager, stand: Vector3) -> void:
	var player := current_scene.get_node("Player") as CharacterBody3D
	player.spawn_at(stand)
	await _physics(10)
	var label := v.villager_id
	_check(v.is_prompt_visible(), "[%s] \"Press E\" shows beside them" % label)
	var data := Villager.load_dialogue(label)
	_models[data["model"]] = true
	var convs: Array = data["conversations"]
	_check(convs.size() >= 3 and convs.size() <= 4, "[%s] has 3-4 conversations (%d)" % [label, convs.size()])
	var seen: Array = []
	for n in convs.size():
		await _press(KEY_E)
		_check(_box.is_open() and _box.current_name() == v.display_name, "[%s] E opens their dialogue (%s)" % [label, _box.current_name()])
		seen.append(_box.current_text())
		var before := player.global_position
		Input.action_press("move_left")
		await _physics(30)
		Input.action_release("move_left")
		_check(player.global_position.distance_to(before) < 0.01, "[%s] the player can't move while reading" % label)
		var to_player := player.global_position - v.global_position
		var want := atan2(to_player.x, to_player.z)
		var visual := v.get_node("Visual") as Node3D
		_check(absf(angle_difference(visual.rotation.y, want)) < 0.2, "[%s] turns to face the player" % label)
		while _box.is_open():
			_box.advance()
			await process_frame
		await _frames(3)
	var firsts: Array = convs.map(func(c: Array) -> String: return c[0])
	_check(seen == firsts, "[%s] each talk is the next conversation, cycling" % label)
	await _press(KEY_E)
	_check(_box.current_text() == firsts[0], "[%s] after the last one it starts again" % label)
	while _box.is_open():
		_box.advance()
		await process_frame
	await _frames(3)


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
