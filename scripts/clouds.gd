extends Node3D
## Soft clouds drifting slowly around (and below) the island. They travel in
## lanes that never cross the island itself, so nothing clips through it.
## Clouds start on whole tile coordinates; only the drift is smooth.

@export var cloud_count := 18
@export var wrap_tiles := 30  # clouds wrap between -wrap and +wrap tiles on x
@export var seed_value := 7

var _clouds: Array[Node3D] = []
var _speeds: Array[float] = []
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.98, 0.95)
	_material.roughness = 1.0
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.92, 0.85)
	_material.emission_energy_multiplier = 0.35
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in cloud_count:
		var tile: Vector3i
		if i % 3 == 0:
			# Deep layer, well below the rocky underside.
			tile = Vector3i(rng.randi_range(-wrap_tiles, wrap_tiles), rng.randi_range(-16, -13), rng.randi_range(-14, 14))
		else:
			# Side lanes in front of and behind the island.
			var side := 1 if i % 2 == 0 else -1
			tile = Vector3i(rng.randi_range(-wrap_tiles, wrap_tiles), rng.randi_range(-6, 1), side * rng.randi_range(12, 16))
		var cloud := _make_cloud(rng)
		cloud.position = Vector3(tile) * Grid.TILE
		add_child(cloud)
		_clouds.append(cloud)
		_speeds.append(rng.randf_range(0.4, 1.0))


func _process(delta: float) -> void:
	var limit := float(wrap_tiles) * Grid.TILE
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += _speeds[i] * delta
		if c.position.x > limit:
			c.position.x -= limit * 2.0


func _make_cloud(rng: RandomNumberGenerator) -> Node3D:
	var cloud := Node3D.new()
	var puffs := rng.randi_range(4, 7)
	for p in puffs:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r := rng.randf_range(1.2, 2.4)
		s.radius = r
		s.height = r * 1.6  # slightly flattened
		s.radial_segments = 16
		s.rings = 8
		mi.mesh = s
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(-0.3, 0.6), rng.randf_range(-1.5, 1.5))
		cloud.add_child(mi)
	return cloud
