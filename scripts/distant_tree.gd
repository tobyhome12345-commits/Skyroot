extends Node3D
## The Great Tree as seen from other islands: same size and proportions as
## the real one (TreeLook constants), but only a handful of simple meshes
## (trunk, branches, leaf blobs, and the island under it), no shadows. Uses
## the shared TreeLook materials, so health changes it too.
## Origin = trunk centre at the island's ground level.
class_name DistantTree

const ISLAND_RADIUS := 32.0

var _blobs: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("tree_health")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# The island under it: a grassy disc and a rocky underside.
	var top := _cyl(ISLAND_RADIUS, ISLAND_RADIUS * 0.96, 2.0, Vector3(0, -1.0, 0), _flat(Color(0.49, 0.72, 0.36)))
	top.name = "IslandTop"
	_cyl(ISLAND_RADIUS * 0.96, 5.0, 26.0, Vector3(0, -15.0, 0), _flat(Color(0.6, 0.6, 0.76)))
	# Trunk and flare.
	var h := TreeLook.TRUNK_HEIGHT
	_cyl(TreeLook.TRUNK_RADIUS * 0.55, TreeLook.TRUNK_RADIUS, h, Vector3(0, h / 2.0, 0), TreeLook.bark())
	_cyl(TreeLook.TRUNK_RADIUS, TreeLook.TRUNK_RADIUS * 1.35, 9.0, Vector3(0, 4.5, 0), TreeLook.bark())
	# Branches.
	for i in 7:
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var from := Vector3(0, rng.randf_range(52.0, 70.0), 0)
		var to := from + dir * rng.randf_range(20.0, 28.0) + Vector3(0, rng.randf_range(8.0, 18.0), 0)
		var mi := _cyl(1.0, 2.0, from.distance_to(to), (from + to) / 2.0, TreeLook.bark_dark())
		var z := (to - from).normalized()
		var x := z.cross(Vector3.FORWARD if absf(z.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		mi.basis = Basis(x, z, x.cross(z))
	# Canopy blobs.
	for i in 14:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(4.0, TreeLook.CANOPY_RADIUS * 0.8)
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		var size := rng.randf_range(10.0, 15.0)
		s.radius = size
		s.height = size * 1.5
		s.radial_segments = 8
		s.rings = 5
		mi.mesh = s
		mi.material_override = TreeLook.leaf()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * r, TreeLook.CANOPY_BASE + rng.randf_range(4.0, 24.0), sin(a) * r)
		mi.set_meta("base", mi.position)
		mi.set_meta("order", rng.randf())
		add_child(mi)
		_blobs.append(mi)
	_blobs.sort_custom(func(p: Node3D, q: Node3D) -> bool: return p.get_meta("order") < q.get_meta("order"))
	apply_health()


func apply_health() -> void:
	var show := int(round(_blobs.size() * TreeLook.leaf_density()))
	for i in _blobs.size():
		_blobs[i].visible = i < show
		_blobs[i].position = (_blobs[i].get_meta("base") as Vector3) - Vector3(0, 5.0 * TreeLook.droop(), 0)
		_blobs[i].scale = Vector3(1.0, 1.0 - 0.28 * TreeLook.droop(), 1.0)


func _cyl(top: float, bottom: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m
