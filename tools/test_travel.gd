extends SceneTree
## Travel test, end to end:
##  - "Press E" at the launch point, E opens the destination menu with the
##    right entries (other known islands selectable, the 4 unknown ones greyed
##    out as "Unknown", the current island not listed); Esc closes it
##  - picking Test Island plays the whole glide cutscene: all shots in order,
##    about 8 s, the destination loaded in the background before the first
##    half ends, no input works meanwhile (moving, E, menus)
##  - landing: on Test Island's landing tile, glider gone, normal camera back,
##    full control again
##  - back to Pebblenook, skipping with Esc: fades and lands quickly
##  - a third trip skipped with Space during the second half
##  - game state carries across every trip (a villager's conversation
##    progress, visited islands, trip count)
## Usage: godot_console --headless --path . --script res://tools/test_travel.gd

var _failures := 0
var _game: Node
var _menu: Node
var _cs: Node
var _box: Node
var _shots: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = root.get_node("/root/Game")
	_menu = root.get_node("/root/TravelMenu")
	_cs = root.get_node("/root/Cutscene")
	_box = root.get_node("/root/DialogueBox")
	_cs.shot_started.connect(func(_i: int, n: String) -> void: _shots.append(n))
	change_scene_to_file("res://scenes/pebblenook.tscn")
	await _frames(10)

	# Talk to Juniper once, so there's progress to carry across islands.
	await _talk("juniper", Vector2i(0, 1))
	_check(_game.state["conversations"].get("juniper", 0) == 1, "talked to Juniper once (progress 1)")

	# ---- Launch point and menu on Pebblenook.
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	player.spawn_at(Grid.cell_center(island.landing_cell, island.map_size))
	await _physics(10)
	var trigger := island.get_node("LaunchTrigger")
	_check(trigger.is_prompt_visible(), "\"Press E\" shows on the landing tile")
	await _press(KEY_E)
	_check(_menu.is_open(), "E opens the destination menu")
	_check(_game.input_locked, "player is locked while the menu is open")
	var entries: Array = _menu.entries()
	var ids := entries.map(func(e: Dictionary) -> String: return e["id"])
	var here := _entry(entries, "pebblenook")
	_check(not here.is_empty() and not here["enabled"] and here["tag"] == "You are here",
			"the island you're on is listed, greyed out, with a \"You are here\" tag")
	_check(not _menu.choose("pebblenook"), "the island you're on can't be picked")
	_check(_entry(entries, "test_island").get("enabled", false), "Test Island is selectable")
	for unknown in ["rootholm", "barkton", "leafwind", "seedhaven"]:
		var e := _entry(entries, unknown)
		_check(not e.is_empty() and not e["enabled"], "%s is listed, greyed out and not selectable" % unknown.capitalize())
	_check(not _menu.choose("rootholm"), "an unknown island can't be picked")
	_check(_unknown_labels() == 4, "the 4 unknown islands say \"Unknown\"")
	_check(entries.size() == 7, "all 7 islands are listed (%d)" % entries.size())
	_check(_entry(entries, "great_tree").get("enabled", false), "The Great Tree is selectable")
	await _press(KEY_ESCAPE)
	_check(not _menu.is_open() and not _game.input_locked, "Esc closes the menu and gives control back")

	# ---- Trip 1: Pebblenook -> Test Island, watched in full.
	await _press(KEY_E)
	_check(_menu.is_open(), "E opens the menu again")
	_shots.clear()
	var start_ms := Time.get_ticks_msec()
	await _press(KEY_E)  # focus starts on Test Island
	_check(_cs.running, "picking Test Island starts the glide cutscene")
	_check(not _menu.is_open(), "the menu closes when the cutscene starts")
	# Nothing works during the cutscene.
	await _frames(20)
	var p_before := player.global_position
	Input.action_press("move_left")
	await _press(KEY_E)
	await _press(KEY_F11)
	await _physics(10)
	Input.action_release("move_left")
	_check(_game.input_locked, "input is locked during the cutscene")
	_check(not _menu.is_open() and not _box.is_open(), "E does nothing during the cutscene")
	_check(not root.get_node("/root/WindowControls").is_fullscreen(), "other keys (F11) do nothing during the cutscene")
	_check(is_instance_valid(player) and player.global_position.distance_to(p_before) > 0.01,
			"the cutscene moves the player (not the movement keys)")
	await _wait_cutscene()
	var seconds := (Time.get_ticks_msec() - start_ms) / 1000.0
	_check(_shots.size() == 6 and _shots[0].begins_with("1.") and _shots[4].begins_with("5."),
			"all shots played in order (%s)" % ", ".join(_shots))
	_check(seconds > 7.0 and seconds < 10.0, "the cutscene takes about 8 seconds (%.1f s)" % seconds)
	_check(_cs.destination_ready_in_time, "the destination loaded in the background before the first half ended")
	_check(not _cs.skipped, "it wasn't skipped")
	await _check_landed("test_island", "trip 1")
	_check(_game.state["trips"] == 1, "one trip taken")

	# ---- Trip 2: Test Island -> Pebblenook, skipped with Esc.
	island = current_scene.get_node("Island")
	player = current_scene.get_node("Player") as CharacterBody3D
	player.spawn_at(Grid.cell_center(island.landing_cell, island.map_size))
	await _physics(10)
	await _press(KEY_E)
	entries = _menu.entries()
	ids = entries.map(func(e: Dictionary) -> String: return e["id"])
	_check(_entry(entries, "pebblenook").get("enabled", false) and _entry(entries, "test_island").get("tag", "") == "You are here"
			and not _entry(entries, "test_island").get("enabled", true),
			"on Test Island the menu offers Pebblenook, and Test Island says \"You are here\"")
	_check(_menu.choose("pebblenook"), "Pebblenook can be picked")
	await _frames(40)
	var skip_ms := Time.get_ticks_msec()
	await _press(KEY_ESCAPE)
	await _wait_cutscene()
	var skip_s := (Time.get_ticks_msec() - skip_ms) / 1000.0
	_check(_cs.skipped, "Esc skips the cutscene")
	_check(skip_s < 2.5, "skipping lands quickly (%.1f s)" % skip_s)
	await _check_landed("pebblenook", "trip 2 (skipped)")

	# Progress carried across both trips: Juniper picks up where she left off.
	await _talk("juniper", Vector2i(0, 1))
	_check(_box_text_was == current_scene.get_node("Island/Villagers/villager_juniper").conversations[1][0],
			"Juniper continues with her 2nd conversation after two trips (nothing reset)")
	_check("test_island" in _game.state["visited"] and "pebblenook" in _game.state["visited"],
			"both islands are in the visited list")

	# ---- Trip 3: skipped with Space during the second half.
	island = current_scene.get_node("Island")
	player = current_scene.get_node("Player") as CharacterBody3D
	player.spawn_at(Grid.cell_center(island.landing_cell, island.map_size))
	await _physics(10)
	await _press(KEY_E)
	_menu.choose("test_island")
	while _cs.running and _cs.shot_index < 3:
		await process_frame
	await _frames(10)
	_check(current_scene.scene_file_path.ends_with("test_island.tscn"), "the second half plays on the destination island")
	await _press(KEY_SPACE)
	await _wait_cutscene()
	_check(_cs.skipped, "Space skips the cutscene")
	await _check_landed("test_island", "trip 3 (skipped in the second half)")
	_check(_game.state["trips"] == 3 and _game.state["conversations"].get("juniper", 0) == 2,
			"game state kept counting across 3 trips (trips 3, Juniper 2)")

	# ---- Trip 4: Test Island -> the Great Tree, watched in full (tilt-up arrival).
	island = current_scene.get_node("Island")
	player = current_scene.get_node("Player") as CharacterBody3D
	player.spawn_at(Grid.cell_center(island.landing_cell, island.map_size))
	await _physics(10)
	await _press(KEY_E)
	_shots.clear()
	_check(_menu.choose("great_tree"), "Test Island's menu offers the Great Tree")
	await _wait_cutscene()
	_check(_shots.any(func(n: String) -> bool: return n.begins_with("6. Tilt up")),
			"arriving at the Great Tree plays the tilt-up reveal (%s)" % ", ".join(_shots))
	await _check_landed("great_tree", "trip 4 (to the Great Tree)")
	# ---- Glide back from the tree to both islands (skipped with Esc).
	await _glide_skipped("pebblenook")
	await _glide_skipped("great_tree")
	await _glide_skipped("test_island")

	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _glide_skipped(dest: String) -> void:
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	var from: String = island.island_id
	player.spawn_at(Grid.cell_center(island.landing_cell, island.map_size))
	await _physics(10)
	await _press(KEY_E)
	_check(_menu.choose(dest), "from %s the menu offers %s" % [from, dest])
	await _frames(30)
	await _press(KEY_ESCAPE)
	await _wait_cutscene()
	await _check_landed(dest, "%s to %s (skipped)" % [from, dest])


## After landing: right island, on its landing tile, glider gone, normal
## camera, and the player can move again.
func _check_landed(island_id: String, label: String) -> void:
	await _frames(5)
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	_check(island.island_id == island_id and _game.state["island"] == island_id, "[%s] arrived on %s" % [label, island_id])
	var cell := Grid.world_to_cell(player.global_position, island.map_size)
	_check(cell == island.landing_cell, "[%s] player is on the landing tile %s (%s)" % [label, island.landing_cell, cell])
	_check(absf(player.global_position.y) < 0.05, "[%s] player stands on the ground (y=%.2f)" % [label, player.global_position.y])
	_check(player.find_child("Glider", true, false) == null, "[%s] the glider is gone" % label)
	_check(root.get_viewport().get_camera_3d() == current_scene.get_node("Camera"), "[%s] the normal game camera is back" % label)
	_check(not _game.input_locked and not _cs.running, "[%s] full control is back" % label)
	var before := player.global_position
	var away: String = "move_left" if island.launch_dir.x > 0 else "move_right"
	Input.action_press(away)
	await _physics(20)
	Input.action_release(away)
	_check(player.global_position.distance_to(before) > 0.3, "[%s] the player can walk again" % label)
	await _physics(10)


var _box_text_was := ""


## Stand next to a villager, press E, remember the first line, close it.
func _talk(id: String, offset: Vector2i) -> void:
	var island := current_scene.get_node("Island")
	var v: Node3D = island.get_node("Villagers/villager_" + id)
	var player := current_scene.get_node("Player") as CharacterBody3D
	player.spawn_at(Grid.cell_center((v.get_meta("cell") as Vector2i) + offset, island.map_size))
	await _physics(10)
	await _press(KEY_E)
	_box_text_was = _box.current_text()
	while _box.is_open():
		_box.advance()
		await process_frame
	await _frames(3)


func _entry(entries: Array, id: String) -> Dictionary:
	for e: Dictionary in entries:
		if e["id"] == id:
			return e
	return {}


func _unknown_labels() -> int:
	var n := 0
	for l in _menu.find_children("*", "Label", true, false):
		if (l as Label).text == "Unknown" and l.is_visible_in_tree():
			n += 1
	return n


func _wait_cutscene() -> void:
	for i in 2000:
		if not _cs.running:
			break
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
