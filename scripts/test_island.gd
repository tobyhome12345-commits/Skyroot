extends "res://scripts/island.gd"
## Test Island: a small 10 x 10 island to try gliding between islands.
## Same grid, ground, cliffs and props as Pebblenook; only the layout differs.

const TEST_MAP: Array[String] = [
	"...####...",
	".########.",
	".########.",
	"##########",
	"####==####",
	"#=====####",
	"##########",
	".########.",
	".########.",
	"...####...",
]


func _map() -> Array[String]:
	return TEST_MAP


## Launch point on the west edge, pointing west; the path leads inland.
func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(0, 5), "dir": Vector2i(-1, 0), "flag": Vector2i(0, 4)}


func _prop_layout() -> Array[Dictionary]:
	return [
		{"type": "tree", "cell": Vector2i(3, 1), "kind": "pine"},
		{"type": "tree", "cell": Vector2i(6, 1), "kind": "round"},
		{"type": "tree", "cell": Vector2i(8, 3), "kind": "bushy"},
		{"type": "tree", "cell": Vector2i(8, 7), "kind": "pine"},
		{"type": "tree", "cell": Vector2i(2, 8), "kind": "crooked"},
		{"type": "lantern", "cell": Vector2i(2, 4)},
		{"type": "lantern", "cell": Vector2i(2, 6)},
		{"type": "rock", "cell": Vector2i(1, 2), "kind": "rock-small", "rot": 40.0},
		{"type": "rock", "cell": Vector2i(5, 8), "kind": "rock-wide", "rot": -30.0},
		{"type": "flowers", "cell": Vector2i(6, 4), "rot": 20.0},
		{"type": "flowers_tall", "cell": Vector2i(6, 6)},
		{"type": "plant", "cell": Vector2i(3, 6), "rot": 90.0},
		{"type": "barrel", "cell": Vector2i(7, 5)},
		{"type": "crate", "cell": Vector2i(7, 4), "rot": 25.0},
		{"type": "mushrooms", "cell": Vector2i(4, 7)},
		{"type": "grass", "cell": Vector2i(4, 2)},
		{"type": "grass", "cell": Vector2i(4, 8), "rot": 60.0},
	]


func _villager_layout() -> Array[Dictionary]:
	return []
