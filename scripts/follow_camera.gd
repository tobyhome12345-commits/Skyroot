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

var _target: Node3D


func _ready() -> void:
	rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	snap_to_target()


## Jump straight to the follow position (used at start, no swoop).
func snap_to_target() -> void:
	global_position = _desired_position()


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_desired_position(), weight)


func _desired_position() -> Vector3:
	var focus := _target.global_position if _target else Vector3.ZERO
	var pitch := deg_to_rad(pitch_degrees)
	return focus + Vector3(0.0, sin(pitch), cos(pitch)) * distance
