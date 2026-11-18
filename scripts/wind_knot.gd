extends Node3D
## The knot of wind on Leafwind's far cliff: soft ribbons of air tangled
## round each other. Each strand turns slowly about its own axis, so the
## knot churns in place: trapped wind, going nowhere. Built by
## LeafwindProps.wind_knot().

## Degrees per second each strand turns (set per strand as meta "spin").
func _process(delta: float) -> void:
	for strand in get_children():
		if strand.has_meta("spin_axis"):
			var axis: Vector3 = strand.get_meta("spin_axis")
			(strand as Node3D).rotate(axis, deg_to_rad(float(strand.get_meta("spin"))) * delta)
