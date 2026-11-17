extends Node
## Cutscene player (autoload "Cutscene"). Plays a shot list from a JSON file
## (see data/cutscenes/). Reusable for any cutscene: gliding between islands
## now, and later ones like returning gifts to the Great Tree.
##
## File format:
##   {"name": ..., "parts": [{"scene": "here" | "destination", "anchor": "launch",
##                            "shots": [shot, ...]}, ...]}
##   shot: {"name", "duration" (s), "ease": "linear" | "in" | "out" | "in_out",
##          "camera": {"path": [point, ...], "look": point | [point, point, ...],
##                     "look_height": m, "fov": n | [from, to]}
##                  | {"game": true}   (ease back to the normal game camera),
##          "player": {"path": [[x,y,z], ...], "curve": bool, "ease": ...},
##          "events": [{"at": s, "do": "glider_open" | "glider_close" | "anim" |
##                      "fade" | "clouds", ...}]}
## A point is [x,y,z] in the part's anchor space, {"anchor": name, "at":
## [x,y,z]} in another anchor's space (e.g. "tree"), or "player" (the
## player's head). A "look" given as a list of points pans along them.
## Anchors come from the level's cutscene_anchor(name); for "launch": origin
## on the landing tile, +z out over the ramp to the sky, +y up, +x right.
## A part with "scene": "destination" switches to the destination scene,
## which has been loading in the background since the cutscene started.
## Esc or Space skips: fade to black, land at the destination.

signal shot_started(index: int, shot_name: String)
signal finished

const SKIP_GRACE := 0.25  # ignore skip keys right at the start (s)

var running := false
var skipped := false
## Was the destination already loaded when the first half ended?
var destination_ready_in_time := false
var shot_index := -1
var shot_name := ""
## Seconds since the cutscene started.
var elapsed := 0.0

var _data := {}
var _options := {}
var _skip := false
var _switched := false
var _cam: Camera3D
var _player: CharacterBody3D
var _level: Node
var _anchor := Transform3D.IDENTITY
var _glider: Node3D
var _glider_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if running:
		elapsed += delta


## Starts a cutscene. options: {"destination": scene path, ...}.
func play(path: String, options := {}) -> void:
	if running:
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not data.has("parts"):
		push_error("Bad cutscene file: %s" % path)
		return
	_data = data
	_options = options
	running = true
	skipped = false
	_skip = false
	_switched = false
	destination_ready_in_time = false
	shot_index = -1
	shot_name = ""
	elapsed = 0.0
	Game.input_locked = true
	var dest: String = options.get("destination", "")
	if dest != "":
		ResourceLoader.load_threaded_request(dest)
	_run()


## Same as pressing Esc / Space during the cutscene.
func skip() -> void:
	if running and elapsed >= SKIP_GRACE:
		_skip = true


# ---------------------------------------------------------------- running

func _run() -> void:
	var index := 0
	for part: Dictionary in _data["parts"]:
		if _skip:
			break
		if part.get("scene", "here") == "destination" and not _switched:
			await _switch_to_destination()
		_setup_part(part)
		for shot: Dictionary in part["shots"]:
			if _skip:
				break
			shot_index = index
			shot_name = shot.get("name", "")
			shot_started.emit(index, shot_name)
			await _run_shot(shot)
			index += 1
	if _skip:
		await _finish_skipped()
	_finish()


func _setup_part(part: Dictionary) -> void:
	var scene := get_tree().current_scene
	_level = _find_level(scene)
	_player = scene.find_child("Player", true, false) as CharacterBody3D
	_anchor = _level.cutscene_anchor(part.get("anchor", "launch")) if _level else Transform3D.IDENTITY
	if _player:
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
		if _glider and _glider.get_parent() == null:
			_attach_glider()
	if not is_instance_valid(_cam):
		_cam = Camera3D.new()
		_cam.name = "CutsceneCamera"
		scene.add_child(_cam)
		var game_cam := scene.get_viewport().get_camera_3d()
		if game_cam:
			_cam.global_transform = game_cam.global_transform
			_cam.fov = game_cam.fov
	_cam.make_current()


func _find_level(scene: Node) -> Node:
	if scene.has_method("cutscene_anchor"):
		return scene
	for c in scene.get_children():
		if c.has_method("cutscene_anchor"):
			return c
	return null


func _run_shot(shot: Dictionary) -> void:
	var duration: float = shot.get("duration", 1.0)
	var cam: Dictionary = shot.get("camera", {})
	var pl: Dictionary = shot.get("player", {})
	var events: Array = shot.get("events", []).duplicate()
	var cam_start := _cam.global_transform
	var fov_start := _cam.fov
	var t := 0.0
	while true:
		# Events whose time has come.
		for e: Dictionary in events.duplicate():
			if t >= float(e.get("at", 0.0)):
				_event(e)
				events.erase(e)
		var k := clampf(t / duration, 0.0, 1.0)
		_apply_player(pl, _ease(k, pl.get("ease", shot.get("ease", "in_out"))))
		_apply_camera(cam, _ease(k, cam.get("ease", shot.get("ease", "in_out"))), cam_start, fov_start)
		if t >= duration or _skip:
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	for e: Dictionary in events:
		_event(e)


func _apply_player(pl: Dictionary, k: float) -> void:
	if not pl.has("path") or _player == null:
		return
	var curve: bool = pl.get("curve", false)
	_player.global_position = _path(pl["path"], k, curve)
	# Face the way they're moving.
	var ahead := _path(pl["path"], minf(k + 0.02, 1.0), curve)
	var behind := _path(pl["path"], maxf(k - 0.02, 0.0), curve)
	var d := ahead - behind
	if Vector2(d.x, d.z).length() > 0.001:
		(_player.get_node("Visual") as Node3D).rotation.y = atan2(d.x, d.z)


func _apply_camera(cam: Dictionary, k: float, cam_start: Transform3D, fov_start: float) -> void:
	if cam.is_empty():
		return
	if cam.get("game", false):
		var game_cam := _game_camera()
		if game_cam == null:
			return
		if game_cam.has_method("snap_to_target"):
			game_cam.snap_to_target()
		var to := game_cam.global_transform
		var q := cam_start.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), k)
		_cam.global_transform = Transform3D(Basis(q), cam_start.origin.lerp(to.origin, k))
		_cam.fov = lerpf(fov_start, game_cam.fov, k)
		return
	var pos := _path(cam["path"], k, true)
	var look = cam.get("look", "player")
	_look_height = cam.get("look_height", 1.0)
	var target: Vector3
	if look is Array and not look.is_empty() and (look[0] is Array or look[0] is Dictionary or look[0] is String):
		target = _path(look, k, true)
	else:
		target = _point(look)
	if not pos.is_equal_approx(target):
		_cam.look_at_from_position(pos, target, Vector3.UP)
	var fov = cam.get("fov", null)
	if fov is Array:
		_cam.fov = lerpf(float(fov[0]), float(fov[1]), k)
	elif fov != null:
		_cam.fov = float(fov)


func _event(e: Dictionary) -> void:
	match e.get("do", ""):
		"glider_open":
			_open_glider()
		"glider_close":
			_close_glider(false)
		"anim":
			if _player and _player.has_method("play_anim"):
				_player.play_anim(e.get("name", "idle"))
		"fade":
			var color := Color.BLACK
			if e.get("color", "black") == "cloud":
				color = Color(0.97, 0.96, 1.0)
			Game.fade(float(e.get("to", 1.0)), float(e.get("time", 0.4)), color)
		"clouds":
			var clouds := get_tree().current_scene.find_child("Clouds", true, false)
			if clouds and clouds.has_method("add_cloud"):
				for p in e.get("points", []):
					clouds.add_cloud(_point(p))
		_:
			push_error("Unknown cutscene event: %s" % e)


# ---------------------------------------------------------------- scene switch

func _switch_to_destination() -> void:
	var dest: String = _options.get("destination", "")
	if dest == "":
		return
	destination_ready_in_time = ResourceLoader.load_threaded_get_status(dest) == ResourceLoader.THREAD_LOAD_LOADED
	var packed := ResourceLoader.load_threaded_get(dest) as PackedScene
	# Keep the glider across the switch: it travels with the player.
	if _glider and _glider.get_parent():
		_glider.get_parent().remove_child(_glider)
	Game.pending_spawn = {"at": "launch"}
	_cam = null
	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await get_tree().process_frame
	_switched = true


# ---------------------------------------------------------------- glider

func _open_glider() -> void:
	if _glider == null:
		_glider = Glider.build()
	_attach_glider()
	_glider.scale = Vector3(0.05, 0.3, 0.05)
	_tween_glider(Vector3.ONE, 0.35)


func _attach_glider() -> void:
	if _player == null or _glider == null:
		return
	if _glider.get_parent():
		_glider.get_parent().remove_child(_glider)
	var visual := _player.get_node("Visual") as Node3D
	visual.add_child(_glider)
	_glider.position = GLIDER_HANDS


## Folds the glider away and removes it (instantly when skipping).
func _close_glider(instant: bool) -> void:
	if _glider == null:
		return
	var g := _glider
	_glider = null
	if instant or not g.is_inside_tree():
		g.queue_free()
		return
	if _glider_tween:
		_glider_tween.kill()
	_glider_tween = g.create_tween()
	_glider_tween.tween_property(g, "scale", Vector3(0.05, 0.3, 0.05), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_glider_tween.tween_callback(g.queue_free)


func _tween_glider(to: Vector3, time: float) -> void:
	if _glider_tween:
		_glider_tween.kill()
	_glider_tween = _glider.create_tween()
	_glider_tween.tween_property(_glider, "scale", to, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Where the glider's bar sits on the player: at the hands, which the
## "holding-both" animation holds out in front at chest height.
const GLIDER_HANDS := Vector3(0.0, 0.78, 0.32)


# ---------------------------------------------------------------- ending

func _finish_skipped() -> void:
	skipped = true
	await Game.fade(1.0, 0.3)
	if not _switched and _options.get("destination", "") != "":
		await _switch_to_destination()
		var scene := get_tree().current_scene
		_level = _find_level(scene)
		_player = scene.find_child("Player", true, false) as CharacterBody3D
	_close_glider(true)
	# Put the player on the landing tile, ready to go.
	if _level and _player and "landing_cell" in _level:
		var cell: Vector2i = _level.landing_cell
		var dir: Vector2i = _level.launch_dir
		_player.spawn_at(Grid.cell_center(cell, _level.map_size), atan2(-float(dir.x), -float(dir.y)))
	_restore_camera()
	await Game.fade(0.0, 0.35)


func _finish() -> void:
	_close_glider(true)
	if _player:
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(true)
		if _player.has_method("play_anim"):
			_player.play_anim("idle")
	_restore_camera()
	running = false
	Game.input_locked = false
	finished.emit()


func _restore_camera() -> void:
	var game_cam := _game_camera()
	if game_cam:
		if game_cam.has_method("snap_to_target"):
			game_cam.snap_to_target()
		game_cam.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null


func _game_camera() -> Camera3D:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Camera") as Camera3D if scene else null


## Nothing else gets input during a cutscene; Esc / Space skip it.
func _input(event: InputEvent) -> void:
	if not running:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in [KEY_ESCAPE, KEY_SPACE]:
		skip()


# ---------------------------------------------------------------- maths

func _ease(k: float, kind: String) -> float:
	match kind:
		"linear":
			return k
		"in":
			return k * k
		"out":
			return 1.0 - (1.0 - k) * (1.0 - k)
	return k * k * (3.0 - 2.0 * k)


static func _vec(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


var _look_height := 1.0


## A point in world space: [x,y,z] (part anchor), {"anchor", "at"} or "player".
func _point(p) -> Vector3:
	if p is String:
		if p == "player" and _player:
			return _player.global_position + Vector3(0.0, _look_height, 0.0)
		return _anchor.origin
	if p is Dictionary:
		var t := _anchor
		if _level and p.has("anchor"):
			t = _level.cutscene_anchor(p["anchor"])
		return t * _vec(p.get("at", [0, 0, 0]))
	return _anchor * _vec(p)


## World point at k (0..1) along a path of points: smooth (Catmull-Rom) or
## straight segments; both spread evenly by length.
func _path(points: Array, k: float, curve: bool) -> Vector3:
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(_point(p))
	if pts.size() == 1:
		return pts[0]
	var lengths: Array[float] = []
	var total := 0.0
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		lengths.append(l)
		total += l
	var want := k * total
	for i in lengths.size():
		if want <= lengths[i] or i == lengths.size() - 1:
			var s := clampf(want / maxf(lengths[i], 0.0001), 0.0, 1.0)
			if not curve:
				return pts[i].lerp(pts[i + 1], s)
			var p0 := pts[maxi(i - 1, 0)]
			var p3 := pts[mini(i + 2, pts.size() - 1)]
			return pts[i].cubic_interpolate(pts[i + 1], p0, p3, s)
		want -= lengths[i]
	return pts[pts.size() - 1]
