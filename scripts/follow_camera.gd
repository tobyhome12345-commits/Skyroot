extends Camera3D
## Fixed-angle camera that smoothly follows a target. The player cannot
## rotate or zoom it.

@export var target_path: NodePath
## How far the camera looks down, in degrees.
@export var pitch_degrees := 50.0
## Distance from the target along the view direction.
@export var distance := 24.0
## Higher = snappier follow.
@export var follow_speed := 4.0

## Only used by the screenshot tool for check views; the game keeps yaw 0
## and no focus override.
var yaw_degrees := 0.0
var focus_override: Variant = null  # Vector3 or null

var _target: Node3D


func _ready() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	snap_to_target()


## Jump straight to the follow position (used at start, no swoop).
func snap_to_target() -> void:
	rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0.0)
	global_position = _desired_position()


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_desired_position(), weight)


func _desired_position() -> Vector3:
	var focus: Vector3 = Vector3.ZERO
	if focus_override != null:
		focus = focus_override
	elif _target:
		focus = _target.global_position
	var pitch := deg_to_rad(pitch_degrees)
	var back := Vector3(0.0, sin(pitch), cos(pitch)).rotated(Vector3.UP, deg_to_rad(yaw_degrees))
	return focus + back * distance
