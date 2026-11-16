extends Node3D
## Debug view, toggled with F3: grid lines on every ground tile and
## see-through shapes for every collider (edge walls, props, player).

const TOGGLE_KEY := KEY_F3

@export var island_path: NodePath
@export var player_path: NodePath

var _debug_nodes: Array[Node3D] = []
var _label: Label
var _visible := false


func _ready() -> void:
	add_to_group("debug_toggle")
	# Wait one frame so the island has built its tiles and colliders.
	await get_tree().process_frame
	var island := get_node(island_path)
	_build_grid_lines(island)
	_build_collider_shapes(island.get_node("EdgeWalls"), Color(1.0, 0.25, 0.2, 0.25))
	_build_collider_shapes(island.get_node("Props"), Color(1.0, 0.6, 0.1, 0.45), true)
	var player := get_node_or_null(player_path)
	if player:
		_build_collider_shapes(player, Color(0.2, 0.5, 1.0, 0.5), true)
	_build_label()
	set_debug_visible(_visible)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		set_debug_visible(not _visible)


func set_debug_visible(on: bool) -> void:
	_visible = on
	for n in _debug_nodes:
		n.visible = on
	if _label:
		_label.visible = on


func _build_grid_lines(island: Node) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := Grid.TILE / 2.0
	var y := 0.03
	for cell in island.ground_cells():
		var c := Grid.cell_center(cell, island.map_size)
		var a := Vector3(c.x - half, y, c.z - half)
		var b := Vector3(c.x + half, y, c.z - half)
		var d := Vector3(c.x - half, y, c.z + half)
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(d)
		# Close the far edges where there is no neighbour to draw them.
		if not island.is_ground(cell + Vector2i(1, 0)):
			mesh.surface_add_vertex(b)
			mesh.surface_add_vertex(Vector3(c.x + half, y, c.z + half))
		if not island.is_ground(cell + Vector2i(0, 1)):
			mesh.surface_add_vertex(d)
			mesh.surface_add_vertex(Vector3(c.x + half, y, c.z + half))
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "GridLines"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _flat_material(Color(0.1, 0.15, 0.1, 0.6))
	add_child(mi)
	_debug_nodes.append(mi)


## Adds a see-through mesh inside every CollisionShape3D under `root`, so it
## moves with its collider (e.g. the player). `on_top` draws it through the
## object's own mesh so colliders hidden inside walls are still visible.
func _build_collider_shapes(root: Node, color: Color, on_top := false) -> void:
	var material := _flat_material(color)
	material.no_depth_test = on_top
	if on_top:
		material.render_priority = 1
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		var mesh: Mesh
		if cs.shape is BoxShape3D:
			var b := BoxMesh.new()
			b.size = (cs.shape as BoxShape3D).size
			mesh = b
		elif cs.shape is CylinderShape3D:
			var cyl := CylinderMesh.new()
			cyl.top_radius = (cs.shape as CylinderShape3D).radius
			cyl.bottom_radius = cyl.top_radius
			cyl.height = (cs.shape as CylinderShape3D).height
			mesh = cyl
		elif cs.shape is CapsuleShape3D:
			var cap := CapsuleMesh.new()
			cap.radius = (cs.shape as CapsuleShape3D).radius
			cap.height = (cs.shape as CapsuleShape3D).height
			mesh = cap
		else:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "DebugShape"
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = material
		cs.add_child(mi)
		_debug_nodes.append(mi)


func _build_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2  # above the tilt-shift blur
	add_child(layer)
	_label = Label.new()
	_label.text = "DEBUG (F3)  grid lines | collision: red = edge walls, orange = props, blue = player"
	_label.position = Vector2(12, 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
