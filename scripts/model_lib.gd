class_name ModelLib
## Kenney models used on the island (all CC0 — see Assets/CREDITS.md), and
## helpers that fit them to the tile grid: scaled to a footprint, centred on
## it, and sitting flush on the ground (lowest point at y = 0).

const TOWN := "res://Assets/Houses/Models/GLB format/"
const PLATFORMER := "res://Assets/Platformer Kit/Models/GLB format/"
const FOREST := "res://Assets/Mini Forest/Models/GLB format/"
const SURVIVAL := "res://Assets/Survival Kit/Models/GLB format/"
const CHARACTERS := "res://Assets/Mini Characters/Models/GLB format/"
const FURNITURE := "res://Assets/Furniture Kit/Models/GLTF format/"

## Fixed scales that keep every pack at the same world size as the island
## (Furniture Kit: 1 unit = one tile, like the Town houses; Survival Kit items
## are modelled smaller, so they need 3x to stand next to furniture).
const PACK_SCALE := {"F": 2.0, "T": 2.0, "S": 3.0, "P": 2.0, "C": 1.0}
const PACK_PATH := {
	"F": FURNITURE, "T": TOWN, "S": SURVIVAL, "P": PLATFORMER,
	"C": "res://Assets/Modular Cave/Models/GLB format/",
}

## Fantasy Town Kit pieces are 1 unit modules; 2x makes one module = one tile.
const TOWN_SCALE := 2.0

const TOWN_ATLAS := "res://Assets/Houses/Models/GLB format/Textures/colormap.png"
## In the Town atlas the roof colour is the swatch at ROOF_SWATCH; RED_SWATCH
## is the pack's own red. Copying one onto the other gives red roofs.
const ROOF_SWATCH := Vector2i(64, 384)
const RED_SWATCH := Rect2i(0, 384, 64, 128)

const CAVE := "res://Assets/Modular Cave/Models/GLB format/"
## The Modular Cave atlas starts with a 128 x 128 px stone texture.
const CAVE_ATLAS := "res://Assets/Modular Cave/Models/Textures/variation-a.png"
const STONE_REGION := Rect2i(0, 0, 128, 128)

static var _cache := {}
static var _red_roof_atlas: Texture2D
static var _stone_texture: Texture2D


## The stone texture cut out of the Modular Cave atlas, for the island ground.
static func stone_texture() -> Texture2D:
	if _stone_texture == null:
		var img := (load(CAVE_ATLAS) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var stone := img.get_region(STONE_REGION)
		stone.generate_mipmaps()
		_stone_texture = ImageTexture.create_from_image(stone)
	return _stone_texture


## The Town atlas with the roof swatch recoloured to the pack's red.
static func red_roof_atlas() -> Texture2D:
	if _red_roof_atlas == null:
		var img := (load(TOWN_ATLAS) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.blit_rect(img, RED_SWATCH, ROOF_SWATCH)
		img.generate_mipmaps()
		_red_roof_atlas = ImageTexture.create_from_image(img)
	return _red_roof_atlas


## A fresh copy of a model.
static func instance(path: String) -> Node3D:
	if not _cache.has(path):
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Model not found: %s" % path)
			return Node3D.new()
		_cache[path] = scene
	var node := (_cache[path] as PackedScene).instantiate() as Node3D
	_crisp_atlas(node)
	return node


static var _crisp_materials := {}


## Kenney models colour faces by sampling flat swatches in a small atlas.
## Smooth (mipmapped) filtering blends neighbouring swatches on thin faces,
## which shows up as rainbow stripes, so sample the atlas pixel-exact.
static func _crisp_atlas(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat == null:
				continue
			if not _crisp_materials.has(mat):
				var copy := mat.duplicate() as BaseMaterial3D
				copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				_crisp_materials[mat] = copy
			mi.set_surface_override_material(i, _crisp_materials[mat])


## A model placed exactly as authored, uniformly scaled. Used for modular
## pieces that are already designed on a 1-unit grid.
static func piece(path: String, scale: float, pos: Vector3, rot_y_degrees: float) -> Node3D:
	var n := instance(path)
	n.scale = Vector3.ONE * scale
	n.position = pos
	n.rotation_degrees.y = rot_y_degrees
	return n


## Wraps a model so it fits a footprint: uniformly scaled so its width and
## depth fill at most `fill` of the footprint (and its height is at most
## `max_height` if given), centred on the footprint, bottom flush with y = 0.
## Returns a holder node whose origin is the footprint centre on the ground.
static func fitted(path: String, footprint: Vector2, fill := 0.85, max_height := 0.0, rot_y_degrees := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	var model := instance(path)
	model.rotation_degrees.y = rot_y_degrees
	holder.add_child(model)
	var box := ModelUtil.aabb_in(model, holder)
	var s := minf(footprint.x * fill / box.size.x, footprint.y * fill / box.size.z)
	if max_height > 0.0:
		s = minf(s, max_height / box.size.y)
	model.scale = Vector3.ONE * s
	box = ModelUtil.aabb_in(model, holder)
	var centre := box.get_center()
	model.position = Vector3(-centre.x, -box.position.y, -centre.z)
	return holder


## Path and scale for a short model id like "F:bedSingle" (pack letter: F
## Furniture Kit, T Town, S Survival, P Platformer, C Modular Cave).
static func resolve(id: String) -> Array:
	var parts := id.split(":")
	return [PACK_PATH[parts[0]] + parts[1] + ".glb", PACK_SCALE[parts[0]]]


## A model at its pack's fixed scale, turned by `rot_y_degrees`, wrapped in
## a holder so that its bounding box is centred on the holder's origin in
## x/z and its lowest point is at y = 0. Returns [holder, size].
static func placed(id: String, rot_y_degrees := 0.0, scale_mult := 1.0) -> Array:
	var r := resolve(id)
	var holder := Node3D.new()
	holder.name = (r[0] as String).get_file().get_basename()
	var model := instance(r[0])
	model.scale = Vector3.ONE * float(r[1]) * scale_mult
	model.rotation_degrees.y = rot_y_degrees
	holder.add_child(model)
	var box := ModelUtil.aabb_in(model, holder)
	var centre := box.get_center()
	model.position = Vector3(-centre.x, -box.position.y, -centre.z)
	return [holder, box.size]


## Swaps the colour atlas on every mesh (Kenney models share one atlas, so
## a different atlas recolours them, e.g. red roofs instead of teal).
static func set_atlas(node: Node, tex: Texture2D) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.albedo_texture = tex
				mi.set_surface_override_material(i, copy)
