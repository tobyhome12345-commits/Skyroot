extends SceneTree
## Title screen test: it is the main scene; "Skyroot" and the subtitle are
## up top, the three buttons below, nothing cut off or overlapping at
## 1920 x 1080; W / S, the arrow keys, E and Enter work, the selected button
## grows and glows smoothly; Settings opens a panel with a Fullscreen toggle
## and Back (Esc closes it too); the backdrop is the real Great Tree island,
## display only (no player, nothing collides, the game state untouched);
## the camera loop is seamless and never comes near the tree or the island;
## the particles are light; the skip switch works; Play fades to black and
## starts the game on Pebblenook.
## Usage: godot_console --headless --path . --script res://tools/test_title.gd

const TITLE := "res://scenes/title.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("/root/Game")
	_check(ProjectSettings.get_setting("application/run/main_scene") == TITLE, "the title screen is the main scene")
	_check(not bool(ProjectSettings.get_setting("application/run/skip_title", true)), "skip_title is off by default")
	var state_before: Dictionary = game.state.duplicate(true)
	change_scene_to_file(TITLE)
	for i in 30:
		await process_frame
	var t := current_scene
	_check(t.has_method("play"), "the title scene runs")
	# ---- Text and layout.
	var word := ""
	for l: Label in t.title_letters:
		word += l.text
	_check(word == "Skyroot", "the title says Skyroot (%s)" % word)
	_check(t.subtitle != null and t.subtitle.text != "", "there is a subtitle (%s)" % (t.subtitle.text if t.subtitle else ""))
	var names: Array = t.buttons.map(func(b: Button) -> String: return b.text)
	_check(names == ["Play", "Settings", "Quit"], "three buttons: Play, Settings, Quit (%s)" % [names])
	var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var title_rect := Rect2()
	for l: Label in t.title_letters:
		title_rect = l.get_global_rect() if title_rect.size == Vector2.ZERO else title_rect.merge(l.get_global_rect())
	title_rect = title_rect.merge(t.subtitle.get_global_rect())
	var menu_rect := Rect2()
	for b: Button in t.buttons:
		menu_rect = b.get_global_rect() if menu_rect.size == Vector2.ZERO else menu_rect.merge(b.get_global_rect())
	_check(screen.encloses(title_rect) and screen.encloses(menu_rect.grow(menu_rect.size.x * 0.05)),
			"title and menu fit on a 1920 x 1080 screen (title %s, menu %s)" % [title_rect, menu_rect])
	_check(not title_rect.intersects(menu_rect.grow(menu_rect.size.x * 0.05)), "the title and the menu don't overlap")
	_check(title_rect.get_center().y < 540.0 and absf(title_rect.get_center().x - 960.0) < 40.0, "the title is centred in the upper part")
	for b: Button in t.buttons:
		_check(b.get_theme_font_size("font_size") >= 36, "%s is big enough to read" % b.text)
	# ---- Selection: keys, highlight.
	var focus := func() -> Control: return t.get_viewport().gui_get_focus_owner()
	_check(focus.call() == t.buttons[0], "Play is selected at the start")
	await _press(KEY_S)
	_check(focus.call() == t.buttons[1], "S selects the next button")
	await _press(KEY_DOWN)
	_check(focus.call() == t.buttons[2], "the down arrow selects the next button")
	await _press(KEY_S)
	_check(focus.call() == t.buttons[0], "down from Quit wraps to Play")
	await _press(KEY_W)
	_check(focus.call() == t.buttons[2], "W from Play wraps to Quit")
	await _press(KEY_UP)
	_check(focus.call() == t.buttons[1], "the up arrow selects the button above")
	var b1: Button = t.buttons[1]
	await _frames(3)
	var mid := b1.scale.x
	for i in 30:
		await process_frame
	_check(b1.scale.x > 1.05 and b1.get_node("Glow").modulate.a > 0.9, "the selected button grows and glows (%.2f)" % b1.scale.x)
	_check(mid < b1.scale.x, "the highlight eases in, no snapping (%.2f then %.2f)" % [mid, b1.scale.x])
	_check(is_equal_approx(t.buttons[0].scale.x, 1.0) and t.buttons[0].get_node("Glow").modulate.a < 0.1, "the other buttons are not highlighted")
	# ---- Settings.
	await _press(KEY_E)
	_check(t.settings.visible and not t.menu.visible, "E on Settings opens the settings panel")
	_check(focus.call() == t.fullscreen_toggle, "the Fullscreen toggle is selected")
	_check(t.fullscreen_toggle is CheckButton and t.fullscreen_toggle.text.begins_with("Fullscreen"), "the panel has a Fullscreen toggle")
	var panel_rect: Rect2 = t.settings.get_global_rect()
	_check(screen.encloses(panel_rect), "the settings panel fits on screen (%s)" % panel_rect)
	await _press(KEY_S)
	_check((focus.call() as Button).text == "Back", "S moves to Back")
	await _press(KEY_ENTER)
	_check(not t.settings.visible and t.menu.visible and focus.call() == t.buttons[1], "Back closes the panel and returns to Settings")
	await _press(KEY_E)
	await _press(KEY_ESCAPE)
	_check(not t.settings.visible and t.menu.visible, "Esc closes the settings panel")
	# ---- The backdrop.
	var island: Node3D = t.island
	_check(island.get("island_id") == "great_tree" and island.get("display_only"), "the backdrop is the real Great Tree island, display only")
	_check(t.find_child("Player", true, false) == null, "no player in the backdrop")
	var live := 0
	for co in island.find_children("*", "CollisionObject3D", true, false):
		if (co as CollisionObject3D).collision_layer != 0 or (co as CollisionObject3D).collision_mask != 0:
			live += 1
	_check(live == 0, "nothing in the backdrop collides (%d)" % live)
	_check(game.state == state_before, "showing the backdrop leaves the game state untouched")
	_check(island.get_node("DistantViews").get_child_count() >= 5, "the distant islands are in the sky")
	_check(t.find_child("Clouds", false, false) != null, "clouds drift round it")
	var tree := island.get("tree") as Node3D
	var loop: float = t.LOOP_TIME
	var a: Transform3D = t.camera_transform(0.0)
	var b: Transform3D = t.camera_transform(loop)
	_check(a.origin.is_equal_approx(b.origin) and a.basis.is_equal_approx(b.basis), "the camera loop is seamless")
	var worst_step := 0.0
	var nearest := INF
	var lowest := INF
	var prev: Vector3 = a.origin
	for i in range(1, 1601):
		var p: Vector3 = t.camera_transform(loop * i / 1600.0).origin
		worst_step = maxf(worst_step, p.distance_to(prev))
		prev = p
		var flat := Vector2(p.x - tree.global_position.x, p.z - tree.global_position.z).length()
		nearest = minf(nearest, flat)
		lowest = minf(lowest, p.y)
	_check(worst_step < 0.5, "the camera drifts slowly and smoothly (%.2f m per step)" % worst_step)
	var island_reach := Vector2(island.map_size).length() * Grid.TILE / 2.0
	_check(nearest > maxf(TreeLook.CANOPY_RADIUS, island_reach) + 15.0, "the camera keeps well clear of the tree and the island (%.0f m)" % nearest)
	_check(lowest > 10.0, "the camera stays above the island (%.0f m)" % lowest)
	# ---- Particles.
	var parts: Array = t.camera.find_children("*", "CPUParticles3D", false, false)
	var count := 0
	for p: CPUParticles3D in parts:
		count += p.amount
		_check(p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s cast no shadows" % p.name)
	_check(parts.size() == 2 and count <= 60, "leaves and light dust float past, few of them (%d)" % count)
	# ---- Skip switch.
	_check(t.skip_requested(PackedStringArray(["--skip-title"])) and not t.skip_requested(PackedStringArray()), "the --skip-title launch argument skips the title")
	# ---- Play.
	await _press(KEY_W)
	_check(focus.call() == t.buttons[0], "back to Play")
	await _press(KEY_ENTER)
	await _frames(20)
	var fade_rect := game.get("_fade") as ColorRect
	_check(fade_rect.modulate.a > 0.1, "Play fades to black (%.2f)" % fade_rect.modulate.a)
	for i in 240:
		await process_frame
		if current_scene and current_scene.scene_file_path.ends_with("pebblenook.tscn") and fade_rect.modulate.a < 0.01:
			break
	_check(current_scene.scene_file_path == "res://scenes/pebblenook.tscn", "then the game starts on Pebblenook (%s)" % current_scene.scene_file_path)
	_check(fade_rect.modulate.a < 0.01, "and fades back in")
	_check(game.state["island"] == "pebblenook" and current_scene.find_child("Player", true, false) != null, "with the player on Pebblenook, as always")
	print("RESULT: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


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


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
