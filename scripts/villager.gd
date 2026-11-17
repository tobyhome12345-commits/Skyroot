extends StaticBody3D
## A villager standing on one tile. Walk up to see "Press E"; E opens their
## dialogue (from data/dialogue/<id>.json) and they turn to face you. Each
## talk shows their next conversation, cycling round.
## Create with `Villager.create(id, tile_centre, facing_degrees)`.
class_name Villager

const DIALOGUE_DIR := "res://data/dialogue/"
## Same scale as the player, so everyone is the same size.
const MODEL_SCALE := 2.0
## Collision: a cylinder around the body (arms swing a little outside it).
const BODY_RADIUS := 0.55
const BODY_HEIGHT := 1.5
## Talk zone radius (m): reaches the four neighbouring tiles.
const TALK_RADIUS := 2.3
const TURN_SPEED := 8.0

var villager_id := ""
## Key for "which conversation is next" (differs for recap lines).
var counter_key := ""
var display_name := ""
var conversations: Array = []

var _visual: Node3D
var _prompt: Label3D
var _player: Node3D = null
var _target_yaw := 0.0


## The Game / DialogueBox autoloads, looked up at runtime (so this script
## also compiles inside tools that run before autoloads exist).
func _game() -> Node:
	return get_node("/root/Game")


func _dialogue_box() -> Node:
	return get_node("/root/DialogueBox")


## Builds a villager from its dialogue file. Returns null if the file is bad.
static func create(id: String, tile_centre: Vector3, facing_degrees := 0.0) -> Villager:
	var data := load_dialogue(id)
	if data.is_empty():
		return null
	var v := Villager.new()
	v.name = "villager_" + id
	v.villager_id = id
	v.display_name = data["name"]
	v.conversations = data["conversations"]
	# After the opening scene, some villagers (Elder Moss) give story recaps.
	var game := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Game")
	if data.has("recap_conversations") and game and game.state.get("intro_done", false):
		v.conversations = data["recap_conversations"]
		v.counter_key = id + "_recap"
	v.position = tile_centre
	v._target_yaw = deg_to_rad(facing_degrees)
	v._build(data["model"])
	return v


## Reads data/dialogue/<id>.json: {"name", "model", "conversations": [[page, ...], ...]}.
static func load_dialogue(id: String) -> Dictionary:
	var path := DIALOGUE_DIR + id + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Dialogue file missing or empty: %s" % path)
		return {}
	var data = JSON.parse_string(text)
	if not (data is Dictionary) or not data.has("name") or not data.has("model") or not data.has("conversations"):
		push_error("Dialogue file %s needs name, model and conversations" % path)
		return {}
	return data


func _build(model_path: String) -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.rotation.y = _target_yaw
	add_child(_visual)
	var model := ModelLib.instance(model_path)
	model.scale = Vector3.ONE * MODEL_SCALE
	_visual.add_child(model)
	var anim := model.find_children("*", "AnimationPlayer", true, false)
	if not anim.is_empty():
		var ap := anim[0] as AnimationPlayer
		if ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")
	# Solid body.
	var body_shape := CylinderShape3D.new()
	body_shape.radius = BODY_RADIUS
	body_shape.height = BODY_HEIGHT
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape"
	cs.shape = body_shape
	cs.position = Vector3(0.0, BODY_HEIGHT / 2.0, 0.0)
	add_child(cs)
	# Talk zone.
	var zone := Area3D.new()
	zone.name = "TalkZone"
	var zone_shape := CylinderShape3D.new()
	zone_shape.radius = TALK_RADIUS
	zone_shape.height = 2.0
	var zcs := CollisionShape3D.new()
	zcs.shape = zone_shape
	zcs.position = Vector3(0.0, 1.0, 0.0)
	zone.add_child(zcs)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)
	# Prompt above the head.
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
	_prompt.position = Vector3(0.0, 2.2, 0.0)
	_prompt.visible = false
	add_child(_prompt)


func is_prompt_visible() -> bool:
	return _prompt.visible


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body
		_prompt.visible = not _game().input_locked


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
		_prompt.visible = false


func _process(delta: float) -> void:
	if _visual:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, _target_yaw, 1.0 - exp(-TURN_SPEED * delta))
	# Show the prompt again once a conversation (or fade) is over.
	if _player and not _game().input_locked and not _prompt.visible:
		_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _game().input_locked:
		return
	if event.is_action_pressed(_game().INTERACT) and not event.is_echo():
		get_viewport().set_input_as_handled()
		talk()


## Turn to the player and open the next conversation.
func talk() -> void:
	if _player:
		var d := _player.global_position - global_position
		_target_yaw = atan2(d.x, d.z)
	_prompt.visible = false
	var index: int = _game().next_conversation(counter_key if counter_key != "" else villager_id, conversations.size())
	_dialogue_box().open(display_name, conversations[index])
