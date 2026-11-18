extends Node
## Game-wide state (autoload "Game"). One game state for the whole game: it
## lives here, outside any scene, so nothing resets when moving between
## islands or in and out of houses. Also handles fades, house doors and
## starting glider trips.

const OUTSIDE_SCENE := "res://scenes/pebblenook.tscn"
const INTERACT := "interact"
const FADE_TIME := 0.25

## True while a fade / scene change is running: the player can't move.
var input_locked := false
## Where to put the player in the next scene: {"cell": Vector2i, "facing": float}
## (facing = yaw in radians). Empty = use the scene's own start tile.
var pending_spawn := {}
## The outside tile to return to when leaving a house.
var return_cell := Vector2i.ZERO

const ISLANDS_FILE := "res://data/islands.json"
const GLIDE_CUTSCENE := "res://data/cutscenes/glide.json"

## The one game state. Everything that must survive travel goes in here.
var state := {
	"island": "pebblenook",        # island the player is on
	"visited": ["pebblenook"],     # islands been to
	"conversations": {},           # villager id -> next conversation index
	"trips": 0,                    # glider trips taken
	"intro_done": false,           # the opening lore scene has played (or was skipped)
}

## How much colour the world has: 0 = drained, 1 = full. ONE value that the
## whole look follows (every WorldEnvironment's saturation and brightness).
## For now only the opening scene changes it; later the world's joy will.
var colour_level := 1.0:
	set(v):
		colour_level = clampf(v, 0.0, 1.0)
		_apply_colour_everywhere()

## Tools / tests can turn the opening scene on (it never auto-plays while a
## tool script is running, so checks see the normal game).
var force_intro := false

var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	if not InputMap.has_action(INTERACT):
		InputMap.add_action(INTERACT)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event(INTERACT, ev)
	var layer := CanvasLayer.new()
	layer.layer = 100  # above everything, including the tilt-shift
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## Go into a house: `door_front` is the outside tile in front of its door.
func enter_house(interior_scene: String, door_front: Vector2i) -> void:
	return_cell = door_front
	_travel(interior_scene, {})


## Leave a house: back outside, one tile in front of the door, facing away.
func exit_house() -> void:
	_travel(island_scene(state["island"]), {"cell": return_cell, "facing": 0.0})


## Returns the conversation to show for this villager and moves on to the
## next one for next time (cycling round).
func next_conversation(villager_id: String, count: int) -> int:
	var convs: Dictionary = state["conversations"]
	var i: int = convs.get(villager_id, 0) % maxi(count, 1)
	convs[villager_id] = i + 1
	return i


## Called by an island scene when it loads.
func arrive_at(island_id: String) -> void:
	state["island"] = island_id
	if not (island_id in state["visited"]):
		(state["visited"] as Array).append(island_id)


## All islands from data/islands.json: [{id, name, scene, known}, ...].
func islands() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ISLANDS_FILE))
	if not (data is Dictionary) or not data.has("islands"):
		push_error("Bad islands file: %s" % ISLANDS_FILE)
		return []
	return data["islands"]


func island_scene(island_id: String) -> String:
	for i in islands():
		if i["id"] == island_id:
			return i.get("scene", OUTSIDE_SCENE)
	return OUTSIDE_SCENE


## The glide in progress (or the last one): where from and where to. The
## glide cutscene's "depart@" / "arrive@" anchors use them to head for the
## destination's place in the sky and arrive from the island left behind.
var glide_from := ""
var glide_dest := ""


## Fly to another island with the glide cutscene.
func glide_to(island_id: String) -> void:
	if input_locked:
		return
	state["trips"] += 1
	glide_from = state["island"]
	glide_dest = island_id
	var cutscene := GLIDE_CUTSCENE
	for i in islands():
		if i["id"] == island_id and i.has("cutscene"):
			cutscene = i["cutscene"]
	get_node("/root/Cutscene").play(cutscene, {
		"destination": island_scene(island_id),
		"destination_id": island_id,
	})


## Fades the world's colour to `level` over `time` seconds.
func set_colour_level(level: float, time := 0.0) -> void:
	if time <= 0.0:
		colour_level = level
		return
	var tween := create_tween()
	tween.tween_property(self, "colour_level", level, time)


## The opening scene may auto-play (not under a tool script, unless forced).
func intro_allowed() -> bool:
	return force_intro or not ("--script" in OS.get_cmdline_args())


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment:
		_apply_colour(n as WorldEnvironment)


func _apply_colour_everywhere() -> void:
	if not is_inside_tree():
		return
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_colour(we as WorldEnvironment)


## Each environment keeps its own base saturation; colour_level scales it.
func _apply_colour(we: WorldEnvironment) -> void:
	var env := we.environment
	if env == null:
		return
	if not env.has_meta("base_saturation"):
		env.set_meta("base_saturation", env.adjustment_saturation if env.adjustment_enabled else 1.0)
		env.set_meta("base_brightness", env.adjustment_brightness if env.adjustment_enabled else 1.0)
	env.adjustment_enabled = true
	env.adjustment_saturation = float(env.get_meta("base_saturation")) * lerpf(0.25, 1.0, colour_level)
	env.adjustment_brightness = float(env.get_meta("base_brightness")) * lerpf(0.9, 1.0, colour_level)


## Takes (and clears) the spawn request for the scene that just loaded.
func take_spawn() -> Dictionary:
	var s := pending_spawn
	pending_spawn = {}
	return s


func is_travelling() -> bool:
	return input_locked


func _travel(scene_path: String, spawn: Dictionary) -> void:
	if input_locked:
		return
	input_locked = true
	await _fade_to(1.0)
	pending_spawn = spawn
	get_tree().change_scene_to_file(scene_path)
	# Wait until the new scene is in the tree and has placed the player.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	input_locked = false


func _fade_to(alpha: float) -> void:
	await fade(alpha, FADE_TIME)


## Fades the whole screen to (alpha = 1) or from (alpha = 0) a colour.
func fade(alpha: float, time: float, color := Color.BLACK) -> void:
	if alpha > 0.0:
		_fade.color = color
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, maxf(time, 0.01))
	await tween.finished
