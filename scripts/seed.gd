extends Node3D
## The traveller's withered seed from the Great Tree: a small, dry, wrinkled
## seed with a stub of a stalk. It glows softly near an island that needs
## help (set_glow). Simple shapes in the game's colours.
class_name Seed

var _mat: StandardMaterial3D
var _light: OmniLight3D
var glow := 0.0


func _init() -> void:
	name = "Seed"
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.5, 0.36, 0.24)
	_mat.roughness = 0.8
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.55, 0.22)
	_mat.emission_energy_multiplier = 0.0
	var body := MeshInstance3D.new()
	body.name = "Body"
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.2
	s.radial_segments = 12
	s.rings = 8
	body.mesh = s
	body.material_override = _mat
	add_child(body)
	var stalk := MeshInstance3D.new()
	stalk.name = "Stalk"
	var c := CylinderMesh.new()
	c.top_radius = 0.008
	c.bottom_radius = 0.016
	c.height = 0.06
	stalk.mesh = c
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.36, 0.26, 0.18)
	stalk.material_override = sm
	stalk.position = Vector3(0, 0.12, 0)  # sits on top of the seed (top at 0.1)
	add_child(stalk)
	_light = OmniLight3D.new()
	_light.name = "GlowLight"
	_light.light_color = Color(1.0, 0.72, 0.4)
	_light.omni_range = 1.6
	_light.light_energy = 0.0
	add_child(_light)


## Glow from 0 (dark) to 1 (soft warm glow), over `time` seconds.
func set_glow(to: float, time := 0.8) -> void:
	var tween := create_tween()
	tween.tween_method(_apply_glow, glow, to, maxf(time, 0.01))


func _apply_glow(v: float) -> void:
	glow = v
	_mat.emission_energy_multiplier = 0.9 * v
	_light.light_energy = 1.2 * v
