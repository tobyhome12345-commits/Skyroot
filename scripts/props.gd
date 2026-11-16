class_name Props
## Simple placeholder props. Each builder returns a Node3D whose origin is the
## centre of its tile footprint at ground level (y = 0). All parts stay inside
## the footprint, sit on the ground, and come with a solid collider.


static func house(walls: Color, roof: Color) -> Node3D:
	# 2 x 2 tiles = 4 x 4 m footprint.
	var root := Node3D.new()
	var wall_size := Vector3(3.4, 2.6, 3.4)
	_box(root, wall_size, Vector3(0.0, wall_size.y / 2.0, 0.0), walls)
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(3.9, 1.5, 3.8)
	_mesh(root, roof_mesh, Vector3(0.0, wall_size.y + 0.75, 0.0), roof)
	var front := wall_size.z / 2.0
	_box(root, Vector3(0.9, 1.6, 0.1), Vector3(0.0, 0.8, front + 0.05), Color(0.42, 0.27, 0.18))
	var window := Color(1.0, 0.88, 0.55)
	_box(root, Vector3(0.6, 0.6, 0.08), Vector3(-1.05, 1.6, front + 0.04), window)
	_box(root, Vector3(0.6, 0.6, 0.08), Vector3(1.05, 1.6, front + 0.04), window)
	_box(root, Vector3(0.45, 1.0, 0.45), Vector3(1.0, wall_size.y + 1.0, -0.8), Color(0.6, 0.45, 0.4))
	_box_collider(root, wall_size, Vector3(0.0, wall_size.y / 2.0, 0.0))
	return root


static func tree(leaf: Color) -> Node3D:
	# 1 tile = 2 x 2 m footprint.
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 1.4
	_mesh(root, trunk, Vector3(0.0, 0.7, 0.0), Color(0.5, 0.34, 0.22))
	_mesh(root, _sphere(0.85), Vector3(0.0, 1.95, 0.0), leaf)
	_mesh(root, _sphere(0.6), Vector3(0.1, 2.65, 0.05), leaf.lightened(0.08))
	_cylinder_collider(root, 0.35, 2.0)
	return root


static func well() -> Node3D:
	var root := Node3D.new()
	var stone := Color(0.66, 0.63, 0.6)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.75
	ring.bottom_radius = 0.8
	ring.height = 0.8
	_mesh(root, ring, Vector3(0.0, 0.4, 0.0), stone)
	var water := CylinderMesh.new()
	water.top_radius = 0.58
	water.bottom_radius = 0.58
	water.height = 0.04
	_mesh(root, water, Vector3(0.0, 0.81, 0.0), Color(0.25, 0.45, 0.6))
	var wood := Color(0.5, 0.34, 0.22)
	_box(root, Vector3(0.12, 1.7, 0.12), Vector3(-0.68, 0.85, 0.0), wood)
	_box(root, Vector3(0.12, 1.7, 0.12), Vector3(0.68, 0.85, 0.0), wood)
	var roof := PrismMesh.new()
	roof.size = Vector3(1.8, 0.55, 1.3)
	_mesh(root, roof, Vector3(0.0, 1.97, 0.0), Color(0.72, 0.36, 0.3))
	_cylinder_collider(root, 0.85, 1.7)
	return root


static func notice_board() -> Node3D:
	var root := Node3D.new()
	var wood := Color(0.5, 0.34, 0.22)
	_box(root, Vector3(0.12, 1.7, 0.12), Vector3(-0.65, 0.85, 0.0), wood)
	_box(root, Vector3(0.12, 1.7, 0.12), Vector3(0.65, 0.85, 0.0), wood)
	_box(root, Vector3(1.6, 0.9, 0.1), Vector3(0.0, 1.2, 0.0), Color(0.62, 0.45, 0.3))
	_box(root, Vector3(0.4, 0.5, 0.02), Vector3(-0.35, 1.22, 0.06), Color(0.96, 0.93, 0.84))
	_box(root, Vector3(0.45, 0.35, 0.02), Vector3(0.3, 1.3, 0.06), Color(0.95, 0.85, 0.7))
	_box_collider(root, Vector3(1.6, 1.7, 0.4), Vector3(0.0, 0.85, 0.0))
	return root


# ---------------------------------------------------------------- helpers

static func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = MeshUtil.color_material(color)
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, color)


static func _body(parent: Node3D) -> StaticBody3D:
	var body := parent.get_node_or_null("Body") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "Body"
		parent.add_child(body)
	return body


static func _box_collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	_body(parent).add_child(cs)


static func _cylinder_collider(parent: Node3D, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, height / 2.0, 0.0)
	_body(parent).add_child(cs)
