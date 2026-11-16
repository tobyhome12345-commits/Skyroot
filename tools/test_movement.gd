extends SceneTree
## Headless gameplay test: holds keys and checks the player stays on the
## island, cannot walk through props, and that F3 toggles the debug view.
## Usage: godot_console --headless --path . --script res://tools/test_movement.gd

var _failures := 0
var _player: CharacterBody3D
var _island: Node3D


func _initialize() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var level := scene.instantiate()
	root.add_child(level)
	_island = level.get_node("Island")
	_player = level.get_node("Player")
	_run.call_deferred()


func _run() -> void:
	await _settle()
	var start := _player.global_position
	_check(_island.is_ground(_cell()), "player starts on ground")

	# Walk into each island edge for a long time.
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		_player.spawn_at(start)
		await _hold(action, 8.0)
		_check(_island.is_ground(_cell()) and _player.global_position.y > -0.5,
				"stays on island after holding %s (at %s)" % [action, _player.global_position])

	# Diagonals into the corners too.
	for pair in [["move_left", "move_up"], ["move_right", "move_down"]]:
		_player.spawn_at(start)
		Input.action_press(pair[0])
		await _hold(pair[1], 8.0)
		Input.action_release(pair[0])
		_check(_island.is_ground(_cell()) and _player.global_position.y > -0.5,
				"stays on island holding %s+%s" % pair)

	# Walk right from start (7,8) into the well at (9,8): must stop in front.
	_player.spawn_at(start)
	await _hold("move_right", 3.0)
	var well_x := Grid.cell_center(Vector2i(9, 8), _island.map_size).x
	_check(_player.global_position.x < well_x - 0.85,
			"blocked by well (x=%.2f, well=%.2f)" % [_player.global_position.x, well_x])

	# Walk up from (4,6) into house at (3..4, 3..4).
	_player.spawn_at(Grid.cell_center(Vector2i(4, 6), _island.map_size))
	await _hold("move_up", 3.0)
	_check(_player.global_position.z > Grid.footprint_center(Vector2i(3, 3), Vector2i(2, 2), _island.map_size).z + 1.7,
			"blocked by house (z=%.2f)" % _player.global_position.z)

	# Walk left from (3,9) into tree at (1,9).
	_player.spawn_at(Grid.cell_center(Vector2i(3, 9), _island.map_size))
	await _hold("move_left", 3.0)
	var tree_x := Grid.cell_center(Vector2i(1, 9), _island.map_size).x
	_check(_player.global_position.x > tree_x + 0.35,
			"blocked by tree (x=%.2f, tree=%.2f)" % [_player.global_position.x, tree_x])

	# F3 toggles the debug view on and off.
	var debug_view := root.find_child("DebugView", true, false)
	var grid_lines := debug_view.get_node("GridLines") as Node3D
	_check(not grid_lines.visible, "debug view starts hidden")
	await _press_key(KEY_F3)
	_check(grid_lines.visible, "F3 shows debug view")
	await _press_key(KEY_F3)
	_check(not grid_lines.visible, "F3 again hides debug view")

	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _cell() -> Vector2i:
	return Grid.world_to_cell(_player.global_position, _island.map_size)


func _settle() -> void:
	for i in 10:
		await physics_frame


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame
	Input.action_release(action)
	await _settle()


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
