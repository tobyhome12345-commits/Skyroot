extends Area3D
## A door the player can use: standing on its tile shows a small "Press E"
## prompt; pressing E calls `activate` (set by whoever creates the door).

## Called when the player presses E here.
var activate: Callable
var _player_here := false
var _prompt: Label3D


## Builds the trigger on one tile. `prompt_pos` is where the prompt floats
## (relative to the tile centre), usually above the door itself.
func setup(tile_centre: Vector3, prompt_pos: Vector3, action: Callable) -> void:
	activate = action
	position = tile_centre
	var shape := BoxShape3D.new()
	shape.size = Vector3(Grid.TILE * 0.9, 2.0, Grid.TILE * 0.9)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 1.0, 0.0)
	add_child(cs)
	_prompt = Label3D.new()
	_prompt.name = "Prompt"
	_prompt.text = "Press E"
	_prompt.font_size = 64
	_prompt.outline_size = 16
	_prompt.pixel_size = 0.006
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.modulate = Color(1.0, 0.97, 0.88)
	_prompt.outline_modulate = Color(0.2, 0.12, 0.08)
	_prompt.position = prompt_pos
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_prompt_visible() -> bool:
	return _prompt.visible


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_here = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_here = false


## The prompt shows while the player is here and free to act (hidden during
## fades, menus, dialogue and cutscenes; back as soon as they close).
func _process(_delta: float) -> void:
	if _prompt:
		_prompt.visible = _player_here and not Game.input_locked


func _unhandled_input(event: InputEvent) -> void:
	if not _player_here or Game.input_locked:
		return
	if event.is_action_pressed(Game.INTERACT) and not event.is_echo():
		get_viewport().set_input_as_handled()
		_prompt.visible = false
		activate.call()
