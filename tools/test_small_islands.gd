extends SceneTree
## Small islands test: the bench on Lookout Isle and the seed on Seed Isle
## show "Press E" and read their lines from the dialogue files, cycling; the
## trader on Trader's Rock talks through 4 cycling conversations; the player
## can't move while reading; the seed glows and can't be picked up.
## Usage: godot_console --headless --path . --script res://tools/test_small_islands.gd

var _failures := 0
var _box: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_box = root.get_node("/root/DialogueBox")
	await _spot_test("res://scenes/lookout_isle.tscn", "lookout_bench")
	await _spot_test("res://scenes/seed_isle.tscn", "seed_isle_seed")
	var seed := current_scene.find_child("Seed", true, false)
	_check(seed != null and seed.glow > 0.3, "the seed on Seed Isle glows faintly")
	_check(seed != null and seed.get_parent().get_parent().name.begins_with("seed_spot"), "the seed stays in its soft earth (it can't be collected)")
	await _trader_test()
	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _spot_test(scene: String, id: String) -> void:
	change_scene_to_file(scene)
	await _frames(10)
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))
	var spot: Dictionary = island.talk_spots.filter(func(t: Dictionary) -> bool: return t["id"] == id)[0]
	player.spawn_at(Grid.cell_center(spot["cell"], island.map_size))
	await _physics(10)
	var trig := island.get_node("talk_" + id)
	_check(trig.is_prompt_visible(), "[%s] \"Press E\" shows" % id)
	var seen: Array[String] = []
	for n in data["conversations"].size():
		await _press(KEY_E)
		_check(_box.is_open() and _box.current_name() == data["name"], "[%s] E opens the dialogue box (%s)" % [id, _box.current_name()])
		seen.append(_box.current_text())
		var before := player.global_position
		Input.action_press("move_up")
		await _physics(10)
		Input.action_release("move_up")
		_check(player.global_position.distance_to(before) < 0.01, "[%s] the player can't move while reading" % id)
		while _box.is_open():
			_box.advance()
			await process_frame
		await _frames(3)
	var firsts: Array = data["conversations"].map(func(c: Array) -> String: return c[0])
	_check(seen == firsts, "[%s] each press reads the next line, cycling (%d lines)" % [id, seen.size()])
	player.spawn_at(Grid.cell_center(island.landing_cell, island.map_size))
	await _physics(10)
	_check(not trig.is_prompt_visible(), "[%s] the prompt hides when walking away" % id)


func _trader_test() -> void:
	change_scene_to_file("res://scenes/traders_rock.tscn")
	await _frames(10)
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	var trader: Node3D = island.get_node("Villagers/villager_trader")
	var cell: Vector2i = trader.get_meta("cell")
	player.spawn_at(Grid.cell_center(cell + Vector2i(0, 1), island.map_size))
	await _physics(10)
	_check(trader.is_prompt_visible(), "[trader] \"Press E\" shows next to the trader")
	_check(trader.conversations.size() >= 3 and trader.conversations.size() <= 4, "[trader] has 3-4 conversations")
	var seen: Array[String] = []
	for n in trader.conversations.size():
		await _press(KEY_E)
		_check(_box.current_name() == trader.display_name, "[trader] the box shows %s" % trader.display_name)
		seen.append(_box.current_text())
		while _box.is_open():
			_box.advance()
			await process_frame
		await _frames(3)
	var unique := {}
	for t in seen:
		unique[t] = true
	_check(unique.size() == trader.conversations.size(), "[trader] every talk is a different conversation, cycling")
	var model_path: String = Villager.load_dialogue("trader")["model"]
	_check(model_path.get_file() != "character-male-a.glb", "[trader] looks different from the player (%s)" % model_path.get_file())


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
