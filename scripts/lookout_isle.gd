extends "res://scripts/island.gd"
## Lookout Isle: a quiet 8 x 8 island with a bench and a low fence along the
## north edge, looking out at the Great Tree (which lies due north).

const LOOKOUT_MAP: Array[String] = [
	"..####..",
	".######.",
	"########",
	"########",
	"###=####",
	".##=###.",
	"..#=##..",
	"...##...",
]

const NK := "res://Assets/Nature Kit/Models/GLTF format/"
const BENCH := Vector2i(3, 2)


func _map() -> Array[String]:
	return LOOKOUT_MAP


## Launch point on the south edge, pointing south; its flag beside it.
func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(3, 7), "dir": Vector2i(0, 1), "flag": Vector2i(4, 7)}


func _prop_layout() -> Array[Dictionary]:
	return [
		# The bench faces north, towards the fence and the tree beyond it.
		{"type": "bench", "cell": BENCH, "rot": 90.0},
		{"type": "fence", "cell": Vector2i(2, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(3, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(4, 0), "side": "north"},
		{"type": "fence", "cell": Vector2i(5, 0), "side": "north"},
		{"type": "lantern", "cell": Vector2i(4, 3)},
		{"type": "tree", "cell": Vector2i(0, 3), "kind": "crooked"},
		{"type": "tree", "cell": Vector2i(7, 3), "kind": "round"},
		{"type": "rock", "cell": Vector2i(6, 5), "kind": "rock-wide", "rot": 25.0},
		{"type": "rock", "cell": Vector2i(1, 1), "kind": "rock-small", "rot": 200.0},
		{"type": "flowers", "cell": Vector2i(2, 3), "rot": 30.0},
		{"type": "flowers_tall", "cell": Vector2i(5, 2)},
		{"type": "nature", "model": NK + "flower_purpleB.glb", "cell": Vector2i(1, 4), "fill": 0.45, "rot": 70.0, "solid": false, "max_height": 0.7},
		{"type": "nature", "model": NK + "grass_leafsLarge.glb", "cell": Vector2i(5, 4), "fill": 0.6, "rot": 10.0, "solid": false, "max_height": 0.7},
		{"type": "grass", "cell": Vector2i(6, 1), "rot": 140.0},
		{"type": "mushrooms", "cell": Vector2i(2, 6)},
	]


func _villager_layout() -> Array[Dictionary]:
	return []


## Press E standing behind the bench (south of it).
func _after_build() -> void:
	_add_talk_spot(BENCH + Vector2i(0, 1), BENCH, "lookout_bench", 1.6)
