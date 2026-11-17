class_name TreeLook
## How the Great Tree looks, driven by ONE shared value: `health`
## (0 = withered, 1 = healthy). Every part of the tree (the real one on its
## island and the low-detail one seen from other islands) uses these shared
## materials, so changing health changes them all at once:
##   bark tone, leaf colour, moss colour, leaf density, leaf droop, and how
##   many leaves are falling.
## Only the withered look is used for now (health = 0).

## Real-world size of the tree, shared by the full and the distant version.
const TRUNK_RADIUS := 8.0        # 8 tiles wide at the base
const TRUNK_HEIGHT := 78.0
const CANOPY_BASE := 66.0        # canopy starts this high
const CANOPY_RADIUS := 34.0

const BARK_WITHERED := Color(0.44, 0.39, 0.35)    # dull grey-brown
const BARK_HEALTHY := Color(0.56, 0.37, 0.23)
const BARK_DARK_WITHERED := Color(0.33, 0.29, 0.27)
const BARK_DARK_HEALTHY := Color(0.38, 0.24, 0.15)
const WOOD_WITHERED := Color(0.66, 0.6, 0.53)   # cut / broken wood
const WOOD_HEALTHY := Color(0.86, 0.7, 0.5)
const LEAF_WITHERED := Color(0.8, 0.76, 0.52)    # pale, dry
const LEAF_HEALTHY := Color(0.36, 0.64, 0.38)
const MOSS_WITHERED := Color(0.47, 0.5, 0.36)
const MOSS_HEALTHY := Color(0.3, 0.56, 0.32)

static var health := 0.0

static var _bark: StandardMaterial3D
static var _bark_dark: StandardMaterial3D
static var _wood: StandardMaterial3D
static var _leaf: StandardMaterial3D
static var _moss: StandardMaterial3D
static var _glow: StandardMaterial3D


## Changes the tree's health everywhere: shared materials update at once,
## and every tree in the scene re-applies density, droop and falling leaves.
static func set_health(h: float, tree: SceneTree = null) -> void:
	health = clampf(h, 0.0, 1.0)
	_update_materials()
	if tree:
		tree.call_group("tree_health", "apply_health")


## 0..1 share of canopy leaf clusters shown.
static func leaf_density() -> float:
	return lerpf(0.5, 1.0, health)


## 0..1 how much the leaves droop (1 = withered).
static func droop() -> float:
	return 1.0 - health


## Falling leaves per second.
static func falling_leaves() -> int:
	return int(lerpf(14.0, 3.0, health))


static func bark() -> StandardMaterial3D:
	_ensure()
	return _bark


static func bark_dark() -> StandardMaterial3D:
	_ensure()
	return _bark_dark


static func wood() -> StandardMaterial3D:
	_ensure()
	return _wood


static func leaf() -> StandardMaterial3D:
	_ensure()
	return _leaf


static func moss() -> StandardMaterial3D:
	_ensure()
	return _moss


## The warm glow behind the sealed entrance.
static func glow() -> StandardMaterial3D:
	_ensure()
	return _glow


## Re-colours a model with the tree materials, surface by surface, using
## the pack's material names: leaves / grass become leaves (or moss), inner
## wood stays light, bark becomes bark. `leaves_only` hides everything but
## the leaves (for canopy clusters made from whole little trees).
static func apply_to(node: Node, green_is_moss := false, dark := false, leaves_only := false) -> void:
	_ensure()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var n := src.resource_name.to_lower() if src else ""
			var mat: Material
			if "leaf" in n or "leafs" in n or "grass" in n or "green" in n:
				mat = _moss if green_is_moss else _leaf
			elif leaves_only:
				mat = _hidden
			elif "inner" in n:
				mat = _wood
			else:
				mat = _bark_dark if dark else _bark
			mi.set_surface_override_material(i, mat)


static var _hidden: StandardMaterial3D


static func _ensure() -> void:
	if _bark == null:
		_bark = _make(0.95)
		_bark_dark = _make(0.95)
		_wood = _make(0.9)
		_leaf = _make(0.85)
		_moss = _make(1.0)
		_glow = _make(0.6)
		_hidden = StandardMaterial3D.new()
		_hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hidden.albedo_color = Color(0, 0, 0, 0)
		_hidden.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.emission_enabled = true
		_update_materials()


static func _make(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = roughness
	return m


static func _update_materials() -> void:
	if _bark == null:
		return
	_bark.albedo_color = BARK_WITHERED.lerp(BARK_HEALTHY, health)
	_bark_dark.albedo_color = BARK_DARK_WITHERED.lerp(BARK_DARK_HEALTHY, health)
	_wood.albedo_color = WOOD_WITHERED.lerp(WOOD_HEALTHY, health)
	_leaf.albedo_color = LEAF_WITHERED.lerp(LEAF_HEALTHY, health)
	_moss.albedo_color = MOSS_WITHERED.lerp(MOSS_HEALTHY, health)
	_glow.albedo_color = Color(1.0, 0.72, 0.38)
	_glow.emission = Color(1.0, 0.62, 0.28)
	_glow.emission_energy_multiplier = lerpf(0.7, 2.0, health)
