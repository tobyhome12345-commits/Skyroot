extends "res://scripts/island.gd"
## Seed Isle: a soft, quiet 8 x 8 island. In the middle, a faintly glowing
## seed rests in a patch of soft earth, ringed by flowers.

const SEED_MAP: Array[String] = [
	"..####..",
	".######.",
	"########",
	"########",
	"########",
	"########",
	".######.",
	"..####..",
]

const NK := "res://Assets/Nature Kit/Models/GLTF format/"
const MF := "res://Assets/Mini Forest/Models/GLB format/"
const SEED := Vector2i(3, 3)


func _map() -> Array[String]:
	return SEED_MAP


## Launch point on the east edge, pointing east; its flag beside it.
func _launch_layout() -> Dictionary:
	return {"cell": Vector2i(7, 3), "dir": Vector2i(1, 0), "flag": Vector2i(7, 4)}


func _prop_layout() -> Array[Dictionary]:
	var soft := func(model: String, cell: Vector2i, rot: float) -> Dictionary:
		return {"type": "nature", "model": model, "cell": cell, "fill": 0.5, "rot": rot, "solid": false, "max_height": 0.7}
	return [
		{"type": "seed_spot", "cell": SEED},
		# A ring of flowers round the seed (the tiles east and south stay open).
		soft.call(NK + "flower_redA.glb", Vector2i(2, 2), 10.0),
		soft.call(NK + "flower_yellowB.glb", Vector2i(3, 2), 80.0),
		soft.call(NK + "flower_purpleA.glb", Vector2i(4, 2), 150.0),
		soft.call(NK + "flower_yellowC.glb", Vector2i(2, 3), 220.0),
		soft.call(NK + "flower_redC.glb", Vector2i(2, 4), 300.0),
		soft.call(MF + "patch-grass.glb", Vector2i(5, 5), 0.0),
		soft.call(NK + "grass_leafs.glb", Vector2i(1, 5), 45.0),
		{"type": "tree", "cell": Vector2i(1, 1), "kind": "round"},
		{"type": "tree", "cell": Vector2i(6, 1), "kind": "bushy"},
		{"type": "nature", "model": NK + "plant_bushDetailed.glb", "cell": Vector2i(5, 6), "fill": 0.6, "rot": 20.0, "solid": true},
		{"type": "nature", "model": NK + "stump_roundDetailed.glb", "cell": Vector2i(0, 4), "fill": 0.5, "rot": 0.0, "solid": true},
		{"type": "mushrooms", "cell": Vector2i(3, 6), "rot": 60.0},
		{"type": "rock", "cell": Vector2i(6, 6), "kind": "rock-small", "rot": 100.0},
	]


func _villager_layout() -> Array[Dictionary]:
	return []


## Press E standing just east of the seed.
func _after_build() -> void:
	_add_talk_spot(SEED + Vector2i(1, 0), SEED, "seed_isle_seed", 1.0)
