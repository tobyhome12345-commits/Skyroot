extends Node3D
## A far-off island seen from another island: a cheap, simplified version
## (one merged low-poly mesh, one shared material, no shadows, no
## collision) placed at the island's spot in the shared sky (SkyMap). It
## sits among a few clouds and bobs very gently, as if floating; the bobbing
## only runs while it is on screen. Distance haze comes from each island's
## environment (depth fog), so it shares the sky's light and colour.
## Kinds: "great_tree" (the existing DistantTree), "leafwind",
## "pebblenook", "lookout_isle", "traders_rock", "seed_isle".
class_name DistantLandmark

## Bobbing: metres up and down, and seconds per bob.
const BOB_HEIGHT := 0.8
const BOB_PERIOD := 14.0
const GRASS := Color(0.49, 0.72, 0.36)
const ROCK := Color(0.6, 0.6, 0.76)
const CLOUD := Color(1.0, 0.98, 0.95)

static var _shared: Material
static var _glow: Material

var island_id := ""
var _base := Vector3.ZERO
var _phase := 0.0
var _time := 0.0


## Builds the distant view of `id` (an island in the sky map).
static func create(id: String) -> DistantLandmark:
	var lm := DistantLandmark.new()
	lm.island_id = id
	lm.name = "DistantTree" if id == "great_tree" else "Distant_" + id
	lm.add_to_group("distant_landmark")
	lm.set_meta("island", id)
	lm._build(String(SkyMap.slot(id).get("landmark", id)))
	return lm


func _ready() -> void:
	_base = position
	_phase = float(hash(island_id) % 1000) / 1000.0 * TAU
	# Only bob while on screen: no cost when out of view.
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.name = "OnScreen"
	notifier.aabb = ModelUtil.aabb_in(self, self)
	notifier.screen_entered.connect(set_process.bind(true))
	notifier.screen_exited.connect(set_process.bind(false))
	add_child(notifier)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	position = _base + Vector3(0.0, sin(_time * TAU / BOB_PERIOD + _phase) * BOB_HEIGHT, 0.0)


static func shared_material() -> Material:
	if _shared == null:
		var m := MeshUtil.vertex_color_material()
		m.roughness = 1.0
		_shared = m
	return _shared


static func glow_material() -> Material:
	if _glow == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.95, 0.7)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.9, 0.55)
		m.emission_energy_multiplier = 2.0
		_glow = m
	return _glow


# ---------------------------------------------------------------- building

func _build(kind: String) -> void:
	if kind == "great_tree":
		var tree := DistantTree.new()
		tree.name = "Tree"
		add_child(tree)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow: SurfaceTool = null
	match kind:
		"leafwind":
			_leafwind(st, rng)
		"pebblenook":
			_floating_island(st, Vector3.ZERO, 18.0, 16.0, GRASS, ROCK, rng)
			for h in [Vector3(-7, 0, -6), Vector3(7, 0, -6), Vector3(-7, 0, 7), Vector3(7, 0, 7)]:
				_house(st, h, Color(0.86, 0.36, 0.3) if int(h.x + h.z) % 2 == 0 else Color(0.36, 0.66, 0.64))
			for t in [Vector3(-14, 0, 2), Vector3(13, 0, -1), Vector3(0, 0, -13), Vector3(2, 0, 13)]:
				_tree(st, t, 5.0, rng)
		"lookout_isle":
			_floating_island(st, Vector3.ZERO, 9.0, 9.0, GRASS, ROCK, rng)
			Treehouse.add_box(st, Vector3(-1.2, 0, -1.0), Vector3(1.2, 0.9, 0.0), Color(0.6, 0.42, 0.28))
			for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
				Treehouse.add_box(st, Vector3(x - 0.15, 0, -6.2), Vector3(x + 0.15, 1.1, -5.9), Color(0.62, 0.45, 0.3))
			_tree(st, Vector3(-5, 0, 2), 4.0, rng)
			_tree(st, Vector3(5, 0, 1), 3.5, rng)
		"traders_rock":
			_floating_island(st, Vector3.ZERO, 9.0, 10.0, GRASS.darkened(0.1), ROCK, rng)
			Treehouse.add_box(st, Vector3(-1.8, 0, -1.4), Vector3(1.8, 1.3, 1.4), Color(0.6, 0.42, 0.28))
			_cone(st, Vector3(0, 2.4, 0), 2.6, 1.6, 4, Color(0.86, 0.32, 0.28))
			for p in [Vector3(-1.6, 1.3, -1.2), Vector3(1.6, 1.3, -1.2), Vector3(-1.6, 1.3, 1.2), Vector3(1.6, 1.3, 1.2)]:
				Treehouse.add_box(st, p - Vector3(0.12, 0, 0.12), p + Vector3(0.12, 1.1, 0.12), Color(0.6, 0.42, 0.28))
			_tree(st, Vector3(5, 0, -4), 4.0, rng)
		"seed_isle":
			_floating_island(st, Vector3.ZERO, 9.0, 9.0, GRASS, ROCK, rng)
			for k in 7:
				var a := TAU * k / 7.0
				Treehouse.add_leaf_blob(st, Vector3(cos(a) * 2.2, 0.4, sin(a) * 2.2), Vector3(0.6, 0.4, 0.6), [Color(0.9, 0.45, 0.45), Color(0.95, 0.85, 0.4), Color(0.7, 0.55, 0.9)][k % 3], rng)
			_tree(st, Vector3(-5, 0, -4), 4.0, rng)
			_tree(st, Vector3(5, 0, -3), 3.5, rng)
			glow = SurfaceTool.new()
			glow.begin(Mesh.PRIMITIVE_TRIANGLES)
			Treehouse.add_leaf_blob(glow, Vector3(0, 0.6, 0), Vector3(0.7, 0.7, 0.7), Color.WHITE, rng)
	_clouds(st, rng, 14.0 if kind == "leafwind" else 8.0 if kind == "pebblenook" else 5.0)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = shared_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if glow:
		var g := MeshInstance3D.new()
		g.name = "Glow"
		g.mesh = glow.commit()
		g.material_override = glow_material()
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)


## Leafwind from afar: four wooden platforms at slightly different heights
## joined by bridges, bark undersides with vines hanging off, a log
## windmill with its sails, two thatched cabins and a leafy canopy.
func _leafwind(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var pads := [[Vector3(0, 0, 6), 14.0], [Vector3(-14, 2, -12), 9.0], [Vector3(14, 0, -13), 8.0], [Vector3(-2, 1, -16), 7.0]]
	for p in pads:
		_floating_island(st, p[0], p[1], p[1] * 0.9, Treehouse.DECK, Treehouse.BARK, rng)
		for k in 5:
			var a := TAU * k / 5.0 + rng.randf()
			var top: Vector3 = (p[0] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * (p[1] as float) * 0.95 - Vector3(0, 0.6, 0)
			Treehouse.add_tube(st, PackedVector3Array([top, top - Vector3(0, rng.randf_range(5.0, 10.0), 0)]), PackedFloat32Array([0.25, 0.12]), Treehouse.LEAF_DARK, 4, false)
	for b in [[0, 1], [0, 2], [1, 3]]:
		var a: Vector3 = pads[b[0]][0]
		var c: Vector3 = pads[b[1]][0]
		Treehouse.add_tube(st, PackedVector3Array([a + Vector3(0, 0.1, 0), c + Vector3(0, 0.1, 0)]), PackedFloat32Array([0.6, 0.6]), Treehouse.WOOD_LIGHT, 4, false)
	# The windmill on the north-east pad.
	var mill := Vector3(14, 0, -13)
	Treehouse.add_box(st, mill + Vector3(-1.4, 0, -1.4), mill + Vector3(1.4, 8.0, 1.4), Treehouse.WOOD)
	_cone(st, mill + Vector3(0, 8.0, 0), 2.4, 3.0, 4, Treehouse.LEAF_DARK)
	var hub := mill + Vector3(0, 7.0, 1.8)
	for a in [PI / 4.0, 3.0 * PI / 4.0]:
		var d := Vector3(cos(a), sin(a), 0.0) * 5.0
		Treehouse.add_box(st, hub - Vector3(0.3, 0.3, 0.1) + Vector3.ZERO, hub + Vector3(0.3, 0.3, 0.1), Treehouse.CREAM)
		Treehouse.add_tube(st, PackedVector3Array([hub - d, hub + d]), PackedFloat32Array([0.35, 0.35]), Treehouse.CREAM, 4, false)
	# Cabins with trunks and leafy crowns.
	for c in [Vector3(-5, 0, 4), Vector3(6, 0, 9), Vector3(-14, 2, -12)]:
		Treehouse.add_box(st, c + Vector3(-2, 0, -2), c + Vector3(2, 2.5, 2), Treehouse.WOOD)
		_cone(st, c + Vector3(0, 2.5, 0), 2.6, 2.0, 4, Treehouse.STRAW)
		Treehouse.add_tube(st, PackedVector3Array([c + Vector3(0, 3.5, 0), c + Vector3(0, 7.5, 0)]), PackedFloat32Array([0.5, 0.35]), Treehouse.BARK, 5, false)
		Treehouse.add_leaf_blob(st, c + Vector3(0, 8.5, 0), Vector3(3.2, 2.2, 3.2), Treehouse.LEAF, rng)
	for k in 6:
		var a := TAU * k / 6.0
		Treehouse.add_leaf_blob(st, Vector3(cos(a) * 16.0, 6.0 + rng.randf_range(0, 3), sin(a) * 13.0), Vector3(4.0, 2.5, 4.0), [Treehouse.LEAF, Treehouse.LEAF_DARK, Treehouse.LEAF_LIGHT][k % 3], rng)


## A floating island: a flat top (`top` colour) and a faceted underside
## tapering down to a point (`under` colour).
func _floating_island(st: SurfaceTool, centre: Vector3, radius: float, depth: float, top: Color, under: Color, rng: RandomNumberGenerator) -> void:
	var sides := 10
	var ring := PackedVector3Array()
	for k in sides:
		var a := TAU * k / sides
		ring.append(centre + Vector3(cos(a), 0.0, sin(a)) * radius * rng.randf_range(0.9, 1.05))
	var mid := PackedVector3Array()
	for k in sides:
		mid.append(centre + (ring[k] - centre) * 0.6 + Vector3(0.0, -depth * 0.45, 0.0))
	var tip := centre + Vector3(rng.randf_range(-1, 1), -depth, rng.randf_range(-1, 1))
	for k in sides:
		var k2 := (k + 1) % sides
		Treehouse._tri(st, centre, ring[k2], ring[k], top.darkened(rng.randf_range(0.0, 0.08)), centre - Vector3(0, 1, 0))
		Treehouse._tri(st, ring[k], ring[k2], mid[k2], under.darkened(rng.randf_range(0.0, 0.12)), centre - Vector3(0, depth * 0.3, 0))
		Treehouse._tri(st, ring[k], mid[k2], mid[k], under.darkened(rng.randf_range(0.0, 0.12)), centre - Vector3(0, depth * 0.3, 0))
		Treehouse._tri(st, mid[k], mid[k2], tip, under.darkened(rng.randf_range(0.1, 0.25)), centre - Vector3(0, depth * 0.5, 0))


## A Pebblenook-style house: white walls and a pointed roof.
func _house(st: SurfaceTool, at: Vector3, roof: Color) -> void:
	Treehouse.add_box(st, at + Vector3(-2, 0, -2), at + Vector3(2, 2.6, 2), Color(0.92, 0.88, 0.8))
	_cone(st, at + Vector3(0, 2.6, 0), 3.0, 2.2, 4, roof)


func _tree(st: SurfaceTool, at: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	Treehouse.add_box(st, at + Vector3(-0.3, 0, -0.3), at + Vector3(0.3, height * 0.45, 0.3), Color(0.5, 0.36, 0.26))
	Treehouse.add_leaf_blob(st, at + Vector3(0, height * 0.7, 0), Vector3(1.8, 1.6, 1.8) * height / 4.0, Color(0.4, 0.66, 0.5), rng)


## A pointed roof / cone with `sides` sides (4 = pyramid).
func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, colour: Color) -> void:
	var apex := base + Vector3(0, height, 0)
	for k in sides:
		var a0 := TAU * k / sides + PI / sides
		var a1 := TAU * (k + 1) / sides + PI / sides
		Treehouse._tri(st, base + Vector3(cos(a0), 0, sin(a0)) * radius, base + Vector3(cos(a1), 0, sin(a1)) * radius, apex, colour, base)


## A few soft clouds drifting round and under the island.
func _clouds(st: SurfaceTool, rng: RandomNumberGenerator, size: float) -> void:
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf()
		var at := Vector3(cos(a) * size * 2.2, -size * rng.randf_range(0.6, 1.4), sin(a) * size * 1.6)
		Treehouse.add_leaf_blob(st, at, Vector3(size * 0.9, size * 0.35, size * 0.6), CLOUD, rng)
