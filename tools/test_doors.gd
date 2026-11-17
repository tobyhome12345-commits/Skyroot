extends SceneTree
## Door round trip for every house: prompt shows at the door, E fades to the
## right interior (player frozen during the fade, placed on the entrance),
## E at the exit fades back outside, one tile in front of the same door, and
## walking away hides the prompt.
## Usage: godot_console --headless --path . --script res://tools/test_doors.gd

## Islands with houses, and how many doors each has.
const ISLANDS := {"res://scenes/pebblenook.tscn": 4, "res://scenes/leafwind.tscn": 3}

var _failures := 0
var _game: Node  # the Game autoload (looked up at runtime)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = root.get_node("/root/Game")
	for scene: String in ISLANDS:
		await _island_doors(scene, ISLANDS[scene])
	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _island_doors(scene: String, count: int) -> void:
	change_scene_to_file(scene)
	await _frames(10)
	var doors: Array = current_scene.get_node("Island/Doors").get_children()
	_check(doors.size() == count, "%d house doors on %s (%d)" % [count, scene.get_file(), doors.size()])
	var interiors := {}
	for i in doors.size():
		# Reload the island fresh each time (we come back to it anyway).
		var door: Node = current_scene.get_node("Island/Doors").get_child(i)
		var front: Vector2i = door.get_meta("cell")
		var interior_path: String = door.get_meta("interior")
		interiors[interior_path] = true
		var label := interior_path.get_file().get_basename()
		var island := current_scene.get_node("Island")
		var player := current_scene.get_node("Player") as CharacterBody3D

		# Walk up to the door: its prompt shows, the others stay hidden.
		player.spawn_at(island.to_global(island.cell_pos(front)))
		await _physics(10)
		_check(door.is_prompt_visible(), "[%s] prompt shows at the door" % label)
		var others_hidden := true
		for d in island.get_node("Doors").get_children():
			if d != door and d.is_prompt_visible():
				others_hidden = false
		_check(others_hidden, "[%s] other doors' prompts stay hidden" % label)

		# Press E: fade starts, the player can't move.
		await _press(KEY_E)
		_check(_game.input_locked, "[%s] input is locked during the fade" % label)
		var before := player.global_position
		Input.action_press("move_right")
		await _physics(8)
		Input.action_release("move_right")
		if is_instance_valid(player):
			_check(player.global_position.distance_to(before) < 0.01, "[%s] player can't move during the fade" % label)
		await _wait_unlocked()

		# Inside the right interior, on the entrance tile.
		_check(current_scene.scene_file_path == interior_path, "[%s] arrived in its own interior (%s)" % [label, current_scene.scene_file_path])
		var interior := current_scene
		var inside_player := interior.get_node("Player") as Node3D
		var cell := Grid.world_to_cell(inside_player.global_position, interior.ROOM_SIZE)
		_check(cell == interior.ENTRANCE_CELL, "[%s] player starts on the entrance tile (%s)" % [label, cell])
		var exit_trigger := interior.get_node("Exit/ExitTrigger")
		await _physics(5)
		_check(not exit_trigger.is_prompt_visible(), "[%s] exit prompt hidden away from the exit" % label)

		# Step onto the exit and press E: back outside in front of the same door.
		(inside_player as CharacterBody3D).spawn_at(interior.cell_center(interior.EXIT_CELL))
		await _physics(10)
		_check(exit_trigger.is_prompt_visible(), "[%s] exit prompt shows on the exit tile" % label)
		await _press(KEY_E)
		await _wait_unlocked()
		_check(current_scene.scene_file_path == scene, "[%s] back on the island" % label)
		var out_player := current_scene.get_node("Player") as CharacterBody3D
		var out_cell := Grid.world_to_cell(out_player.global_position, current_scene.get_node("Island").map_size)
		_check(out_cell == front, "[%s] back one tile in front of its door (%s, expected %s)" % [label, out_cell, front])
		var out_island := current_scene.get_node("Island")
		_check(absf(out_player.global_position.y - out_island.to_global(out_island.cell_pos(front)).y) < 0.05,
				"[%s] back at the door's floor height (y=%.2f)" % [label, out_player.global_position.y])

		# Walking away hides the prompt.
		var back_door: Node = current_scene.get_node("Island/Doors").get_child(i)
		await _physics(5)
		_check(back_door.is_prompt_visible(), "[%s] prompt shows again when back at the door" % label)
		out_player.spawn_at(out_island.to_global(out_island.cell_pos(front + Vector2i(0, 1))))
		await _physics(10)
		_check(not back_door.is_prompt_visible(), "[%s] prompt hides after walking away" % label)
	_check(interiors.size() == count, "each house leads to a different interior (%d unique)" % interiors.size())


func _press(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func _wait_unlocked() -> void:
	for i in 300:
		if not _game.input_locked:
			break
		await process_frame
	await _physics(5)


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
