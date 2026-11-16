class_name ModelUtil
## Helpers for imported 3D models: bounding boxes and grid fitting.


## Combined bounding box of every visible mesh under `node`, expressed in
## `node`'s own local space. Works even when the node is not in the tree.
static func local_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := _relative_transform(node, mi) * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


## Bounding box of `node`'s meshes in `space`'s local space
## (e.g. the island root), using transforms only — no scene tree needed.
static func aabb_in(node: Node3D, space: Node3D) -> AABB:
	return _relative_transform(space, node) * local_aabb(node)


## Transform that takes `child`'s local space into `ancestor`'s local space.
static func _relative_transform(ancestor: Node, child: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = child
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
