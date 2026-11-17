extends SceneTree
## Opening lore scene test. Fails (exit code 1) if:
##  - it doesn't start on a new game, or the colour isn't muted at the start
##  - a beat is missing or out of order, the seed never glows, the elder
##    isn't standing on his own free tile, or the player can move
##  - the camera ever passes through a building, prop or villager, or dips
##    under the ground
##  - at the end: control, the normal camera or full colour aren't back, or
##    the elder / seed are left behind
##  - it plays again after it has finished
##  - Esc (early) or Space (during a dialogue line) don't skip it, or a skip
##    doesn't end exactly like a watched scene
##  - afterwards Elder Moss doesn't give (cycling) recap lines
## Usage: godot_console --headless --path . --script res://tools/test_intro.gd

const BEATS := ["greeting", "seed", "tree", "promise", "forgetting", "fading", "why_seed", "what_to_do", "launch"]

var _failures := 0
var _game: Node
var _cs: Node
var _box: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = root.get_node("/root/Game")
	_cs = root.get_node("/root/Cutscene")
	_box = root.get_node("/root/DialogueBox")
	var lines = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/elder_intro.json"))
	_game.force_intro = true

	# ---- 1. Watch the whole scene.
	change_scene_to_file("res://scenes/pebblenook.tscn")
	await _wait_for_start()
	_check(_cs.running, "the scene starts on a new game")
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	var elder := island.get_node_or_null("Villagers/villager_elder") as Node3D
	_check(elder != null, "Elder Moss is there for the scene")
	if elder:
		var cell: Vector2i = elder.get_meta("cell")
		_check(cell == island.start_cell + Intro.ELDER_OFFSET and island.is_ground(cell) and not island.is_path(cell),
				"the elder stands on his own grass tile next to the traveller (%s)" % cell)
		_check(absf(elder.position.y) < 0.01 and elder.position == Grid.cell_center(cell, island.map_size),
				"the elder stands flush on the ground, on the tile centre")
	_check(_game.colour_level <= 0.35, "the world starts muted (colour level %.2f)" % _game.colour_level)
	var solids := _solid_boxes(island)
	var seen_firsts: Array[String] = []
	var seed_max := 0.0
	var cam_bad := ""
	var start_pos := player.global_position
	var moved := false
	var start_ms := Time.get_ticks_msec()
	var press_wait := 0
	while _cs.running:
		await process_frame
		var cam := root.get_viewport().get_camera_3d()
		if cam and cam_bad == "":
			cam_bad = _camera_clips(cam.global_position, solids, island)
		var seed := player.find_child("Seed", true, false)
		if seed:
			seed_max = maxf(seed_max, seed.glow)
		if _box.is_open():
			var txt: String = _box.current_text()
			if not (txt in seen_firsts):
				seen_firsts.append(txt)
			press_wait += 1
			if press_wait >= 4:
				press_wait = 0
				await _press(KEY_E)
		Input.action_press("move_left")
		if player.global_position.distance_to(start_pos) > 0.01:
			moved = true
		Input.action_release("move_left")
	var seconds := (Time.get_ticks_msec() - start_ms) / 1000.0
	var order_ok := true
	var last_index := -1
	for beat: String in BEATS:
		var first: String = lines["beats"][beat][0]
		var i := seen_firsts.find(first)
		if i < 0 or i < last_index:
			order_ok = false
		last_index = i
	_check(order_ok, "every beat is told, in order (%s)" % ", ".join(BEATS))
	_check(seed_max > 0.9, "the seed glows (%.2f)" % seed_max)
	_check(not moved, "the player can't move during the scene")
	_check(cam_bad == "", "the camera never clips through anything (%s)" % cam_bad)
	_check(not _cs.skipped, "it wasn't skipped")
	print("      (scene took %.0f s with E pressed straight away; reading takes about 1.5 minutes)" % seconds)
	await _check_ended("watched")

	# ---- 2. It never plays again.
	change_scene_to_file("res://scenes/pebblenook.tscn")
	await _frames(40)
	_check(not _cs.running and _game.state["intro_done"], "it doesn't play again once finished")

	# ---- 3. Skip early with Esc.
	_game.state["intro_done"] = false
	change_scene_to_file("res://scenes/pebblenook.tscn")
	await _wait_for_start()
	await _frames(40)
	var skip_ms := Time.get_ticks_msec()
	await _press(KEY_ESCAPE)
	await _wait_end()
	_check(_cs.skipped, "Esc skips the scene")
	_check((Time.get_ticks_msec() - skip_ms) / 1000.0 < 2.0, "skipping is quick (a fade)")
	await _check_ended("skipped with Esc")

	# ---- 4. Skip with Space in the middle of a dialogue line.
	_game.state["intro_done"] = false
	change_scene_to_file("res://scenes/pebblenook.tscn")
	await _wait_for_start()
	for i in 4000:
		if _box.is_open():
			break
		await process_frame
	_check(_box.is_open(), "a dialogue line is showing")
	await _press(KEY_SPACE)
	await _wait_end()
	_check(_cs.skipped, "Space skips the scene, even mid-dialogue")
	_check(not _box.is_open(), "the dialogue box is closed after skipping")
	await _check_ended("skipped with Space")

	# ---- 5. Elder Moss gives recaps afterwards.
	change_scene_to_file("res://scenes/interiors/elder_home.tscn")
	await _frames(10)
	var room := current_scene
	var v: Node3D = room.get_node("Villagers/villager_elder")
	var p := room.get_node("Player") as CharacterBody3D
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/elder.json"))
	var recaps: Array = data["recap_conversations"]
	var firsts := recaps.map(func(c: Array) -> String: return c[0])
	var got: Array[String] = []
	for n in 3:
		p.spawn_at(Grid.cell_center((v.get_meta("cell") as Vector2i) + Vector2i(0, 1), room.ROOM_SIZE))
		await _physics(8)
		await _press(KEY_E)
		got.append(_box.current_text())
		while _box.is_open():
			_box.advance()
			await process_frame
		await _frames(3)
	_check(got.all(func(t: String) -> bool: return t in firsts), "Elder Moss gives story recaps after the scene")
	_check(got[0] != got[1] and got[1] != got[2], "the recaps cycle through different reminders")

	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## What must be true when the scene has ended, however it ended.
func _check_ended(how: String) -> void:
	await _frames(5)
	var island := current_scene.get_node("Island")
	var player := current_scene.get_node("Player") as CharacterBody3D
	_check(_game.state["intro_done"], "[%s] the game remembers the scene has played" % how)
	_check(not _game.input_locked and not _cs.running and not _box.is_open(), "[%s] control is back" % how)
	_check(root.get_viewport().get_camera_3d() == current_scene.get_node("Camera"), "[%s] the normal camera is back" % how)
	_check(absf(_game.colour_level - 1.0) < 0.001, "[%s] full colour is back (%.2f)" % [how, _game.colour_level])
	_check(island.get_node_or_null("Villagers/villager_elder") == null or island.get_node("Villagers/villager_elder").is_queued_for_deletion(),
			"[%s] the elder has gone home" % how)
	_check(not island.occupied.has(island.start_cell + Intro.ELDER_OFFSET), "[%s] the elder's tile is free again" % how)
	_check(player.find_child("Seed", true, false) == null or player.find_child("Seed", true, false).is_queued_for_deletion(),
			"[%s] the seed is put away" % how)
	var before := player.global_position
	Input.action_press("move_down")
	await _physics(20)
	Input.action_release("move_down")
	_check(player.global_position.distance_to(before) > 0.3, "[%s] the player can walk again" % how)


## Model boxes (world space) of everything solid on the island.
func _solid_boxes(island: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	for prop in island.get_node("Props").get_children():
		out.append(ModelUtil.aabb_in(prop.get_node("Model") as Node3D, island))
	for v in island.get_node("Villagers").get_children():
		out.append(ModelUtil.aabb_in(v.get_node("Visual") as Node3D, island))
	var player := current_scene.get_node("Player")
	out.append(ModelUtil.aabb_in(player.get_node("Visual") as Node3D, island).grow(-0.05))
	return out


func _camera_clips(p: Vector3, boxes: Array[AABB], island: Node3D) -> String:
	for b in boxes:
		if b.grow(0.15).has_point(p):
			return "inside something at %s" % p
	if island.is_ground(Grid.world_to_cell(p, island.map_size)) and p.y < 0.3:
		return "under the ground at %s" % p
	return ""


func _wait_for_start() -> void:
	for i in 120:
		if _cs.running:
			return
		await process_frame


func _wait_end() -> void:
	for i in 3000:
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
