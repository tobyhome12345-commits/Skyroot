extends Node
## Game-wide state (autoload "Game"): moving between the island and house
## interiors with a fade to black, and where the player should appear.

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

var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_travel(OUTSIDE_SCENE, {"cell": return_cell, "facing": 0.0})


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
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished
