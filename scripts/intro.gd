class_name Intro
## The opening lore scene. Plays once, the first time a new game starts on
## Pebblenook; Game.state["intro_done"] remembers it (skipping counts too).
## Elder Moss stands on the tile next to the traveller for the scene, the
## traveller holds the seed, and the world's colour starts muted.

const SCENE := "res://data/cutscenes/intro.json"
## The elder stands one tile west of the start tile, facing the traveller.
const ELDER_OFFSET := Vector2i(-1, 0)
const MUTED := 0.3


static func _game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/Game")


## Called when Pebblenook is built: starts the scene if it hasn't played.
static func maybe_start(island: Node3D) -> void:
	var game := _game()
	if game.state.get("intro_done", false) or not game.intro_allowed():
		return
	start.call_deferred(island)  # once the player has been placed


static func start(island: Node3D) -> void:
	var game := _game()
	var player := island.get_node(island.player_path) as CharacterBody3D
	var start_cell: Vector2i = island.start_cell
	var cell := start_cell + ELDER_OFFSET
	if not island.is_free(cell):
		push_error("Intro: the elder's tile %s isn't free" % cell)
		game.state["intro_done"] = true
		return
	# The elder, on his own tile, facing the traveller (east).
	var elder := Villager.create("elder", Grid.cell_center(cell, island.map_size), 90.0)
	elder.name = "villager_elder"
	elder.set_meta("cell", cell)
	elder.set_meta("intro", true)
	island.get_node("Villagers").add_child(elder)
	island.occupied[cell] = "intro_elder"
	# The traveller faces the elder (west), holding the seed in front of them.
	player.spawn_at(Grid.cell_center(start_cell, island.map_size), -PI / 2.0)
	var seed := Seed.new()
	player.get_node("Visual").add_child(seed)
	seed.position = Vector3(0.0, 0.8, 0.42)
	player.play_anim("holding-both")
	game.set_colour_level(MUTED)
	game.get_node("/root/Cutscene").play(SCENE, {"on_end": finish.bind(island, elder, seed, cell)})


## Runs when the scene ends, watched or skipped: the elder goes home, the
## seed goes back in the traveller's pocket, colour returns, never again.
static func finish(skipped: bool, island: Node3D, elder: Node, seed: Node, cell: Vector2i) -> void:
	var game := _game()
	if is_instance_valid(elder):
		elder.queue_free()
	if is_instance_valid(seed):
		seed.queue_free()
	if is_instance_valid(island):
		island.occupied.erase(cell)
	game.set_colour_level(1.0)
	game.state["intro_done"] = true
	game.state["intro_skipped"] = skipped
