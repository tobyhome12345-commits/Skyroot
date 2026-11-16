extends CharacterBody3D
## Placeholder human. Walks with WASD or the arrow keys.
## Island edges and props are solid, so the player stays on the island.

@export var speed := 5.0
@export var acceleration := 30.0
@export var turn_speed := 12.0

@onready var _visual: Node3D = $Visual

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position := Vector3.ZERO


func _ready() -> void:
	_setup_input()
	_spawn_position = global_position


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0.0, input.y)
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()

	if direction.length() > 0.01:
		var target_yaw := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	# Safety net: should never happen, but never lose the player.
	if global_position.y < -30.0:
		global_position = _spawn_position
		velocity = Vector3.ZERO


## Places the player on a tile (called by the island at start).
func spawn_at(pos: Vector3) -> void:
	global_position = pos
	_spawn_position = pos
	velocity = Vector3.ZERO


static func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
