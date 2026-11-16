extends SceneTree
## Windowed test (not headless): presses F11 twice and checks the window goes
## fullscreen and back, and that Esc does nothing to the window.
## Usage: godot_console --path . --script res://tools/test_fullscreen.gd -- [shot.png]

var _failures := 0


func _initialize() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	root.add_child(scene.instantiate())
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	var wc := root.get_node("/root/WindowControls")
	_check(wc != null, "WindowControls autoload is loaded")
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED,
			"game starts maximized (mode %d)" % DisplayServer.window_get_mode())
	var start_mode := DisplayServer.window_get_mode()
	await _press(KEY_ESCAPE)
	_check(DisplayServer.window_get_mode() == start_mode, "Esc leaves the window alone")
	await _press(KEY_F11)
	await _frames(30)
	_check(wc.is_fullscreen(), "F11 switches to fullscreen")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
		print("Fullscreen screenshot: ", args[0], " size ", root.get_texture().get_size())
	await _press(KEY_F11)
	await _frames(30)
	_check(not wc.is_fullscreen(), "F11 again leaves fullscreen")
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
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
