extends SceneTree
## Dialogue test: prompt near a villager, E opens the box (name + typed-out
## text), the player can't move, E finishes typing / advances / closes, the
## villager turns to face the player, the next talk shows a different
## conversation, and walking away hides the prompt. Runs outside (Juniper,
## Fennel) and inside a house (Elder Moss).
## Usage: godot_console --headless --path . --script res://tools/test_dialogue.gd

var _failures := 0
var _game: Node
var _box: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = root.get_node("/root/Game")
	_box = root.get_node("/root/DialogueBox")
	change_scene_to_file("res://scenes/pebblenook.tscn")
	await _frames(10)
	var island := current_scene.get_node("Island")
	await _talk_test(current_scene, island, "juniper", Vector2i(0, 1))
	await _talk_test(current_scene, island, "fennel", Vector2i(1, 0))
	change_scene_to_file("res://scenes/interiors/elder_home.tscn")
	await _frames(10)
	await _talk_test(current_scene, current_scene, "elder", Vector2i(0, -1))
	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Stand on the tile next to the villager (offset), then run a full talk.
func _talk_test(scene: Node, level: Node, id: String, offset: Vector2i) -> void:
	var villager: Node3D = level.get_node("Villagers/villager_" + id)
	var player := scene.get_node("Player") as CharacterBody3D
	var cell: Vector2i = villager.get_meta("cell")
	var stand := Grid.cell_center(cell + offset, level.map_size)
	player.spawn_at(stand)
	await _physics(10)
	_check(villager.is_prompt_visible(), "[%s] prompt shows when the player walks up" % id)

	await _press(KEY_E)
	_check(_box.is_open(), "[%s] E opens the dialogue box" % id)
	_check(_box.current_name() == villager.display_name, "[%s] box shows the speaker's name (%s)" % [id, _box.current_name()])
	_check(_box.current_text() == villager.conversations[0][0], "[%s] first talk shows the first conversation" % id)
	_check(_box.is_typing(), "[%s] text is typed out letter by letter" % id)
	_check(_game.input_locked, "[%s] player is locked while the box is open" % id)
	_check(not villager.is_prompt_visible(), "[%s] prompt hides while talking" % id)

	# Try to walk away mid-conversation: nothing happens.
	var before := player.global_position
	Input.action_press("move_down")
	await _physics(20)
	Input.action_release("move_down")
	_check(player.global_position.distance_to(before) < 0.01, "[%s] player can't move during dialogue" % id)

	# Villager turned to face the player.
	await _physics(30)
	var d: Vector3 = player.global_position - villager.global_position
	var want := atan2(d.x, d.z)
	var have: float = villager.get_node("Visual").rotation.y
	_check(absf(angle_difference(have, want)) < 0.15, "[%s] villager turns to face the player" % id)

	# E finishes typing, then advances, then closes.
	var pages: Array = villager.conversations[0]
	await _press(KEY_E)
	_check(not _box.is_typing(), "[%s] E finishes the typing" % id)
	for i in range(1, pages.size()):
		await _press(KEY_E)
		_check(_box.current_text() == pages[i], "[%s] E goes to page %d" % [id, i + 1])
		await _press(KEY_E)  # finish typing
	await _press(KEY_E)
	_check(not _box.is_open(), "[%s] E on the last page closes the box" % id)
	_check(not _game.input_locked, "[%s] player can move again" % id)
	await _frames(3)
	_check(villager.is_prompt_visible(), "[%s] prompt comes back after talking" % id)

	# Talking again shows a different conversation.
	await _press(KEY_E)
	_check(_box.is_open() and _box.current_text() == villager.conversations[1][0],
			"[%s] next talk shows a different conversation" % id)
	while _box.is_open():
		await _press(KEY_E)

	# Walk away: prompt hides.
	player.spawn_at(Grid.cell_center(cell + offset * 3, level.map_size))
	await _physics(10)
	_check(not villager.is_prompt_visible(), "[%s] prompt hides after walking away" % id)


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
