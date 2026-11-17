extends "res://scripts/island.gd"
## Trader's Rock: a rocky 8 x 8 outcrop where a travelling trader has set up
## a little stall, with barrels and crates of goods. No shop yet.

const TRADER_MAP: Array[String] = [
	".######.",
	"########",
	"########",
	"#====###",
	"########",
	".######.",
	".######.",
	"..####..",
]

const NK := "res://Assets/Nature Kit/Models/GLTF format/"


func _map() -> Array[String]:
	return TRADER_MAP


## Launch point on the west edge, pointing west; its flag beside it.
func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(0, 3), "dir": Vector2i(-1, 0), "flag": Vector2i(0, 4)}


func _prop_layout() -> Array[Dictionary]:
	return [
		{"type": "stall", "cell": Vector2i(4, 2), "red": true, "rot": 180.0},
		{"type": "barrel", "cell": Vector2i(7, 2)},
		{"type": "crate", "cell": Vector2i(7, 3), "rot": 15.0},
		{"type": "crate", "cell": Vector2i(3, 2), "rot": -10.0},
		{"type": "cart", "cell": Vector2i(6, 6), "rot": 90.0},
		{"type": "lantern", "cell": Vector2i(2, 2)},
		{"type": "rock", "cell": Vector2i(1, 5), "kind": "rock-large", "rot": 40.0},
		{"type": "rock", "cell": Vector2i(5, 6), "kind": "rock-wide", "rot": -60.0},
		{"type": "rock", "cell": Vector2i(1, 0), "kind": "rock-small", "rot": 120.0},
		{"type": "nature", "model": NK + "stone_tallB.glb", "cell": Vector2i(6, 0), "fill": 0.55, "rot": 15.0, "solid": true},
		{"type": "nature", "model": NK + "rock_smallFlatA.glb", "cell": Vector2i(3, 5), "fill": 0.5, "rot": 80.0, "solid": true},
		{"type": "tree", "cell": Vector2i(7, 1), "kind": "pine"},
		{"type": "nature", "model": NK + "grass_large.glb", "cell": Vector2i(2, 4), "fill": 0.6, "rot": 0.0, "solid": false, "max_height": 0.7},
		{"type": "nature", "model": NK + "flower_yellowA.glb", "cell": Vector2i(4, 6), "fill": 0.45, "rot": 30.0, "solid": false, "max_height": 0.7},
	]


## The trader stands beside the stall, facing the path.
func _villager_layout() -> Array[Dictionary]:
	return [{"id": "trader", "cell": Vector2i(5, 2), "facing": 0.0}]
