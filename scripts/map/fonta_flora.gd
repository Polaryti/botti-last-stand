class_name FontaFlora
## The plants of Fontanova: not the tropics but the Mediterranean, dry and scented. Olives grey-green
## and gnarled, holm oaks dark and dense, strawberry trees with red bark and red fruit, carobs spreading
## wide with their pods hanging, cypresses like dark flames; meadows of poppies, broom, lavender and
## chamomile; thickets of maquis. Every one of them moves in the wind (flora_sway.gdshader), harder on a
## windy night (set_wind).
## Trees are drawn once each and scattered (MapBuilder.tree with "flora:<kind>"); flowers and shrubs are
## merged per 24 m square, like the map's other small things.

const NOMINAL := {"olive": 4.5, "holm_oak": 7.0, "madrono": 5.0, "carob": 6.0, "cypress": 10.0, "stone_pine": 11.0, "almond": 4.5, "fig": 4.5, "pomegranate": 3.2, "fan_palm": 1.6}
## Each kind of tree is drawn in VARIANTS shapes, so no grove is one tree repeated.
const VARIANTS := 3
## Where a Mutant Spider can cling, at a tree's own size: the trunk's girth (its radius, bark and all)
## and how high it runs clear of leaves. A cypress is leaves to the ground: nothing clings to it.
const TRUNKS := {"olive": Vector2(0.42, 1.5), "holm_oak": Vector2(0.38, 2.4), "madrono": Vector2(0.5, 1.4), "carob": Vector2(0.45, 1.9), "stone_pine": Vector2(0.36, 6.5), "fig": Vector2(0.4, 1.3)}

const OLIVE_BARK := Color(0.33, 0.29, 0.24)
const OLIVE_LEAF := Color(0.42, 0.48, 0.36)
const OLIVE_SILVER := Color(0.58, 0.62, 0.52)
const OAK_BARK := Color(0.2, 0.17, 0.14)
const OAK_LEAF := Color(0.15, 0.24, 0.13)
const OAK_LEAF_LIGHT := Color(0.22, 0.32, 0.17)
const MADRONO_BARK := Color(0.55, 0.24, 0.14)
const MADRONO_LEAF := Color(0.2, 0.36, 0.17)
const BERRY_RED := Color(0.85, 0.12, 0.08)
const BERRY_ORANGE := Color(0.95, 0.5, 0.1)
const BLOSSOM := Color(0.95, 0.93, 0.85)
const CAROB_BARK := Color(0.27, 0.23, 0.2)
const CAROB_LEAF := Color(0.13, 0.27, 0.14)
const CAROB_LEAF_LIGHT := Color(0.2, 0.34, 0.17)
const POD := Color(0.24, 0.13, 0.08)
const CYPRESS := Color(0.1, 0.2, 0.12)
const CYPRESS_LIGHT := Color(0.16, 0.27, 0.15)
const STEM := Color(0.3, 0.4, 0.2)
const FLOWERS := [Color(0.85, 0.1, 0.08), Color(0.95, 0.8, 0.15), Color(0.55, 0.42, 0.78), Color(0.95, 0.95, 0.9), Color(0.92, 0.55, 0.65)]

static var _meshes := {}
static var _tree_material: ShaderMaterial
static var _herb_material: ShaderMaterial
static var _herbs := {} # 24 m square -> LowPoly of flowers and shrubs
static var _grass_material: ShaderMaterial
static var _tufts: Array[Mesh] = []
static var _gust := 0.0


## How the wind blows tonight: 0 still, 1 a windy night, and which way (Weather).
static func set_wind(gust: float, dir: Vector3) -> void:
	_gust = gust
	for m: ShaderMaterial in [tree_material(), herb_material(), grass_material()]:
		m.set_shader_parameter("gust", gust)
		m.set_shader_parameter("wind", Vector2(dir.x, dir.z))


static func tree_material() -> ShaderMaterial:
	if _tree_material == null:
		_tree_material = ShaderMaterial.new()
		_tree_material.shader = load("res://assets/shaders/flora_sway.gdshader")
		# A crown 6 m up moves 6 cm on a still night, about 20 on a windy one; trunks barely at all.
		_tree_material.set_shader_parameter("reach", 6.0)
		_tree_material.set_shader_parameter("sway", 0.06)
		_tree_material.set_shader_parameter("gust_sway", 0.16)
		_tree_material.set_shader_parameter("flutter", 0.012)
		_tree_material.set_shader_parameter("pace", 0.8)
	return _tree_material


static func herb_material() -> ShaderMaterial:
	if _herb_material == null:
		_herb_material = ShaderMaterial.new()
		_herb_material.shader = load("res://assets/shaders/flora_sway.gdshader")
		# A flower half a metre tall nods its head 3-4 cm, about 10 in a gust.
		_herb_material.set_shader_parameter("rooted_in_uv2", true)
		_herb_material.set_shader_parameter("reach", 0.5)
		_herb_material.set_shader_parameter("sway", 0.035)
		_herb_material.set_shader_parameter("gust_sway", 0.07)
		_herb_material.set_shader_parameter("flutter", 0.006)
		_herb_material.set_shader_parameter("pace", 1.6)
	return _herb_material


static func grass_material() -> ShaderMaterial:
	if _grass_material == null:
		_grass_material = ShaderMaterial.new()
		_grass_material.shader = load("res://assets/shaders/flora_sway.gdshader")
		# Grass is drawn as instances, one tuft each: a blade 40 cm tall nods 3 cm, 8 in a gust.
		_grass_material.set_shader_parameter("reach", 0.4)
		_grass_material.set_shader_parameter("sway", 0.03)
		_grass_material.set_shader_parameter("gust_sway", 0.08)
		_grass_material.set_shader_parameter("flutter", 0.004)
		_grass_material.set_shader_parameter("pace", 1.8)
	return _grass_material


## A tree of the kind, size metres tall, set down where the piece stands.
static func tree(b: MapBuilder, kind: String, size: float) -> void:
	var nominal: float = NOMINAL.get(kind, 5.0)
	var s := size / nominal
	# Cypresses are narrow: a blow cannot pass through one, but there is room either side.
	var planted: int = b.w.tree_spots.size()
	var variant := posmod(int(floor(b.xf.origin.x * 0.37)) * 7 + int(floor(b.xf.origin.z * 0.41)) * 13, VARIANTS)
	b.tree("flora:%s.%d" % [kind, variant], s, 1.0, kind != "fan_palm")
	if TRUNKS.has(kind) and b.w.tree_spots.size() > planted:
		var trunk: Vector2 = TRUNKS[kind]
		b.w.spider_trunks.append({"at": b.xf.origin, "girth": trunk.x * s, "high": trunk.y * s})


static func tree_mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var kind := key.get_slice(".", 0)
	var l := LowPoly.new()
	var r := RandomNumberGenerator.new()
	r.seed = hash(key) ^ 7331
	match kind:
		"olive": _olive(l, r)
		"holm_oak": _holm_oak(l, r)
		"madrono": _madrono(l, r)
		"carob": _carob(l, r)
		"cypress": _cypress(l, r)
		"stone_pine": _stone_pine(l, r)
		"almond": _almond(l, r)
		"fig": _fig(l, r)
		"pomegranate": _pomegranate(l, r)
		"fan_palm": _fan_palm(l, r)
	var m := l.commit()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, tree_material())
	_meshes[key] = m
	return m


## A lump of leaves: a squashed, jittered ball, lit from above (lighter on top, darker beneath).
static func clump(l: LowPoly, at: Vector3, radius: float, squash: float, col: Color, r: RandomNumberGenerator, sides := 7) -> void:
	var top := at + Vector3.UP * radius * squash
	var bottom := at + Vector3.DOWN * radius * squash * 0.7
	var ring_hi: Array[Vector3] = []
	var ring_lo: Array[Vector3] = []
	var turn := r.randf() * TAU
	for k in sides:
		var a := turn + TAU * k / sides
		var j := r.randf_range(0.85, 1.12)
		ring_hi.append(at + Vector3(cos(a) * radius * 0.82 * j, radius * squash * 0.42, sin(a) * radius * 0.82 * j))
		var a2 := a + PI / sides
		ring_lo.append(at + Vector3(cos(a2) * radius * j, -radius * squash * 0.18, sin(a2) * radius * j))
	var light := col.lightened(0.14)
	var shade := col.darkened(0.25)
	for k in sides:
		var n := (k + 1) % sides
		l._tri(top, ring_hi[k], ring_hi[n], at, light)
		l._tri(ring_hi[k], ring_lo[k], ring_hi[n], at, col)
		l._tri(ring_hi[n], ring_lo[k], ring_lo[n], at, col.darkened(0.08))
		l._tri(ring_lo[k], bottom, ring_lo[n], at, shade)


## A limb bending along points, thinning as it goes.
static func limb(l: LowPoly, points: Array[Vector3], r0: float, r1: float, col: Color, sides := 6) -> void:
	for i in points.size() - 1:
		var t0 := float(i) / (points.size() - 1)
		var t1 := float(i + 1) / (points.size() - 1)
		l.prism(points[i], points[i + 1], lerpf(r0, r1, t0), lerpf(r0, r1, t1), sides, col.darkened(0.04 * i))


## The olive: a short trunk twisted with age, splitting into leaning limbs, and a loose crown of grey-green
## clumps, silver where the leaves turn in the wind.
static func _olive(l: LowPoly, r: RandomNumberGenerator) -> void:
	var trunk: Array[Vector3] = [Vector3(0, -0.9, 0), Vector3(0.12, 0.6, 0.05), Vector3(-0.08, 1.2, 0.1), Vector3(0.1, 1.7, -0.05)]
	limb(l, trunk, 0.34, 0.2, OLIVE_BARK, 7)
	# Old olives are hollowed and ridged: a second, twisting strand of trunk.
	limb(l, [Vector3(0.18, -0.9, -0.12), Vector3(0.28, 0.7, -0.2), Vector3(0.1, 1.5, -0.1)] as Array[Vector3], 0.2, 0.12, OLIVE_BARK.darkened(0.1), 5)
	var crowns: Array[Vector3] = []
	for k in 3:
		var a := TAU * k / 3.0 + r.randf_range(-0.3, 0.3)
		var end := Vector3(cos(a) * 1.3, 2.7 + r.randf_range(-0.2, 0.3), sin(a) * 1.3)
		limb(l, [Vector3(0.05, 1.6, 0), Vector3(cos(a) * 0.6, 2.1, sin(a) * 0.6), end] as Array[Vector3], 0.13, 0.05, OLIVE_BARK.lightened(0.05), 5)
		crowns.append(end)
	for k in 9:
		var base: Vector3 = crowns[k % 3]
		var at := base + Vector3(r.randf_range(-0.8, 0.8), r.randf_range(-0.1, 0.9), r.randf_range(-0.8, 0.8))
		clump(l, at, r.randf_range(0.75, 1.05), 0.55, OLIVE_SILVER if k % 3 == 0 else OLIVE_LEAF, r)
	clump(l, Vector3(0, 3.4, 0), 1.1, 0.5, OLIVE_LEAF.lightened(0.05), r)


## The holm oak: a stout dark trunk and a great dense dome of small dark leaves, almost black at night.
static func _holm_oak(l: LowPoly, r: RandomNumberGenerator) -> void:
	limb(l, [Vector3(0, -0.9, 0), Vector3(0.05, 1.4, 0), Vector3(-0.05, 2.6, 0.05)] as Array[Vector3], 0.42, 0.28, OAK_BARK, 7)
	for k in 4:
		var a := TAU * k / 4.0 + r.randf() * 0.5
		limb(l, [Vector3(0, 2.4, 0), Vector3(cos(a) * 1.1, 3.4, sin(a) * 1.1), Vector3(cos(a) * 1.9, 4.4, sin(a) * 1.9)] as Array[Vector3], 0.17, 0.07, OAK_BARK, 5)
	for k in 12:
		var a := TAU * k / 12.0 + r.randf() * 0.4
		var ring := 0.0 if k == 0 else (1.4 if k < 7 else 2.4)
		var at := Vector3(cos(a) * ring, 4.8 + r.randf_range(-0.4, 0.6) + (0.9 if ring < 1.0 else 0.0) - ring * 0.25, sin(a) * ring)
		clump(l, at, r.randf_range(1.2, 1.6), 0.62, OAK_LEAF_LIGHT if k % 4 == 0 else OAK_LEAF, r, 8)


## The strawberry tree: a few red-barked stems, a rounded glossy crown, hung with red and orange fruit
## and clusters of white bells.
static func _madrono(l: LowPoly, r: RandomNumberGenerator) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		limb(l, [Vector3(cos(a) * 0.15, -0.9, sin(a) * 0.15), Vector3(cos(a) * 0.45, 1.3, sin(a) * 0.45), Vector3(cos(a) * 0.8, 2.6, sin(a) * 0.8)] as Array[Vector3], 0.13, 0.07, MADRONO_BARK, 6)
	var tops: Array[Vector3] = []
	for k in 8:
		var a := TAU * k / 8.0 + r.randf() * 0.5
		var ring := 0.0 if k == 0 else r.randf_range(0.9, 1.5)
		var at := Vector3(cos(a) * ring, 3.3 + r.randf_range(-0.3, 0.5) - ring * 0.2 + (0.5 if k == 0 else 0.0), sin(a) * ring)
		clump(l, at, r.randf_range(0.85, 1.1), 0.7, MADRONO_LEAF.lightened(0.06) if k % 3 == 0 else MADRONO_LEAF, r)
		tops.append(at)
	# Fruit and flowers on the outside of the crown, both at once, as the strawberry tree carries them.
	for k in 26:
		var c: Vector3 = tops[r.randi_range(1, tops.size() - 1)]
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.5), r.randf_range(-1, 1)).normalized()
		var at := c + dir * 0.95
		if k % 4 == 3:
			l.box(at, Vector3(0.16, 0.12, 0.16), BLOSSOM)
		else:
			l.box(at, Vector3(0.13, 0.13, 0.13), BERRY_RED if k % 3 else BERRY_ORANGE, Vector3(r.randf() * 40, r.randf() * 90, 0))


## The carob: a thick, leaning trunk and a wide, low, spreading crown like an umbrella, with long dark
## pods hanging under it.
static func _carob(l: LowPoly, r: RandomNumberGenerator) -> void:
	limb(l, [Vector3(0, -0.9, 0), Vector3(0.2, 1.1, 0.1), Vector3(0.1, 2.0, 0)] as Array[Vector3], 0.5, 0.36, CAROB_BARK, 7)
	for k in 5:
		var a := TAU * k / 5.0 + r.randf() * 0.4
		limb(l, [Vector3(0.1, 1.9, 0), Vector3(cos(a) * 1.4, 2.9, sin(a) * 1.4), Vector3(cos(a) * 2.6, 3.4, sin(a) * 2.6)] as Array[Vector3], 0.2, 0.08, CAROB_BARK.lightened(0.05), 5)
	for k in 13:
		var a := TAU * k / 13.0 + r.randf() * 0.3
		var ring := 0.0 if k == 0 else (1.7 if k < 6 else 3.0)
		var at := Vector3(cos(a) * ring, 4.1 + r.randf_range(-0.25, 0.35) - ring * 0.12, sin(a) * ring)
		clump(l, at, r.randf_range(1.15, 1.45), 0.48, CAROB_LEAF_LIGHT if k % 4 == 1 else CAROB_LEAF, r, 8)
	for k in 18:
		var a := r.randf() * TAU
		var d := r.randf_range(1.0, 3.2)
		var top := Vector3(cos(a) * d, 3.4 - d * 0.1, sin(a) * d)
		l.box(top + Vector3.DOWN * 0.2, Vector3(0.05, 0.4, 0.08), POD, Vector3(r.randf_range(-10, 10), r.randf() * 180, 0))


## The cypress: one tall dark flame of a tree.
static func _cypress(l: LowPoly, r: RandomNumberGenerator) -> void:
	l.prism(Vector3(0, -0.9, 0), Vector3(0, 1.0, 0), 0.22, 0.16, 6, OAK_BARK)
	# One tall, dense flame of foliage: widest a quarter of the way up, closing to a point, its
	# surface ridged where the sprays of needles stand out, and leaning a touch off true.
	var tall := r.randf_range(8.6, 10.4)
	var girth := r.randf_range(1.0, 1.25)
	var lean := Vector3(r.randf_range(-0.25, 0.25), 0, r.randf_range(-0.25, 0.25))
	const ROWS := 10
	const SIDES := 9
	var rows: Array[Array] = []
	for i in ROWS + 1:
		var t := float(i) / ROWS
		var radius := girth * (lerpf(0.5, 1.0, t / 0.25) if t < 0.25 else pow(1.0 - (t - 0.25) / 0.75, 0.85))
		var row: Array[Vector3] = []
		for j in SIDES:
			var a := TAU * j / SIDES + (PI / SIDES if i % 2 == 1 else 0.0)
			var tuft := 1.0 + (0.14 if (i + j) % 2 == 0 else -0.08) + r.randf_range(-0.08, 0.08)
			row.append(Vector3(cos(a) * radius * tuft, 0.6 + t * tall, sin(a) * radius * tuft) + lean * t * t)
		rows.append(row)
	var centre := Vector3(0, 0.6 + tall * 0.35, 0)
	for i in ROWS:
		var c0 := CYPRESS.lerp(CYPRESS_LIGHT, float(i) / ROWS * 0.8)
		var c1 := CYPRESS.lerp(CYPRESS_LIGHT, float(i + 1) / ROWS * 0.8)
		for j in SIDES:
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i][(j + 1) % SIDES]
			var c: Vector3 = rows[i + 1][j]
			var d: Vector3 = rows[i + 1][(j + 1) % SIDES]
			l._tri_shaded(a, c, b, centre, c0.darkened(0.15), c1, c0)
			l._tri_shaded(b, c, d, centre, c0, c1, c1.darkened(0.1))
	# The underside, closed.
	var base := Vector3(0, 0.45, 0)
	for j in SIDES:
		l._tri_shaded(rows[0][(j + 1) % SIDES], base, rows[0][j], centre, CYPRESS.darkened(0.3), CYPRESS.darkened(0.4), CYPRESS.darkened(0.3))


const PINE_BARK := Color(0.32, 0.22, 0.17)
const PINE_NEEDLES := Color(0.16, 0.27, 0.14)
const ALMOND_BARK := Color(0.24, 0.18, 0.16)
const ALMOND_BLOSSOM := Color(0.98, 0.88, 0.9)
const ALMOND_PINK := Color(0.96, 0.7, 0.78)
const FIG_BARK := Color(0.55, 0.53, 0.48)
const FIG_LEAF := Color(0.3, 0.45, 0.2)
const POMEGRANATE_LEAF := Color(0.2, 0.36, 0.15)
const POMEGRANATE_RED := Color(0.8, 0.1, 0.08)
const PALM_GREEN := Color(0.32, 0.45, 0.28)
const PALM_FIBRE := Color(0.36, 0.26, 0.18)


## The stone pine: a tall bare trunk leaning a little, red-brown and plated, and high up a broad flat
## umbrella of dark needles, the silhouette of every Mediterranean shore.
static func _stone_pine(l: LowPoly, r: RandomNumberGenerator) -> void:
	var lean := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
	var trunk: Array[Vector3] = [Vector3(0, -0.9, 0), Vector3(0, 2.5, 0) + lean * 0.3, Vector3(0, 5.5, 0) + lean * 0.7, Vector3(0, 7.6, 0) + lean]
	limb(l, trunk, 0.36, 0.2, PINE_BARK, 7)
	var crown := Vector3(0, 8.6, 0) + lean
	for k in 5:
		var a := TAU * k / 5.0 + r.randf() * 0.5
		limb(l, [trunk[3], trunk[3] + Vector3(cos(a) * 1.4, 0.8, sin(a) * 1.4), crown + Vector3(cos(a) * 2.6, 0.1, sin(a) * 2.6)] as Array[Vector3], 0.14, 0.06, PINE_BARK, 5)
	# The umbrella: a ring of flat clumps and one over the middle, dark beneath, lighter on top.
	for k in 9:
		var a := TAU * k / 9.0 + r.randf() * 0.3
		var ring := 0.0 if k == 0 else r.randf_range(2.0, 3.2)
		clump(l, crown + Vector3(cos(a) * ring, r.randf_range(-0.15, 0.3) + (0.35 if k == 0 else 0.0), sin(a) * ring), r.randf_range(1.5, 2.0), 0.32, PINE_NEEDLES.lightened(0.06) if k % 3 == 0 else PINE_NEEDLES, r, 8)


## The almond in blossom: a small dark tree, its crooked limbs clouded with white and pale pink flowers
## (its petals blow about it on the wind, Ambience).
static func _almond(l: LowPoly, r: RandomNumberGenerator) -> void:
	limb(l, [Vector3(0, -0.9, 0), Vector3(0.1, 0.8, 0.05), Vector3(-0.05, 1.4, 0)] as Array[Vector3], 0.2, 0.13, ALMOND_BARK, 6)
	var tips: Array[Vector3] = []
	for k in 4:
		var a := TAU * k / 4.0 + r.randf_range(-0.4, 0.4)
		var tip := Vector3(cos(a) * 1.5, 2.9 + r.randf_range(-0.3, 0.4), sin(a) * 1.5)
		limb(l, [Vector3(0, 1.3, 0), Vector3(cos(a) * 0.7, 2.0, sin(a) * 0.7), tip] as Array[Vector3], 0.1, 0.04, ALMOND_BARK, 5)
		tips.append(tip)
	for k in 11:
		var base: Vector3 = tips[k % 4] if k < 9 else Vector3(0, 3.2, 0)
		var at := base + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(-0.2, 0.5), r.randf_range(-0.6, 0.6))
		clump(l, at, r.randf_range(0.6, 0.85), 0.6, ALMOND_PINK if k % 3 == 0 else ALMOND_BLOSSOM, r, 6)
	# A few early leaves among the flowers.
	for k in 10:
		var at: Vector3 = tips[k % 4] + Vector3(r.randf_range(-0.8, 0.8), r.randf_range(-0.4, 0.4), r.randf_range(-0.8, 0.8))
		l.box(at, Vector3(0.18, 0.04, 0.1), Color(0.4, 0.55, 0.28), Vector3(0, r.randf() * 180, r.randf_range(-20, 20)))


## The fig: a short pale grey trunk splitting low into smooth limbs, under a broad crown of big
## light-green leaves (drawn large and flat).
static func _fig(l: LowPoly, r: RandomNumberGenerator) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		limb(l, [Vector3(cos(a) * 0.12, -0.9, sin(a) * 0.12), Vector3(cos(a) * 0.4, 0.9, sin(a) * 0.4), Vector3(cos(a) * 1.3, 2.2, sin(a) * 1.3)] as Array[Vector3], 0.17, 0.08, FIG_BARK, 6)
	for k in 9:
		var a := TAU * k / 9.0 + r.randf() * 0.4
		var ring := 0.0 if k == 0 else r.randf_range(1.1, 2.0)
		clump(l, Vector3(cos(a) * ring, 3.0 + r.randf_range(-0.3, 0.3) - ring * 0.15, sin(a) * ring), r.randf_range(1.0, 1.3), 0.55, FIG_LEAF.lightened(0.08) if k % 3 == 0 else FIG_LEAF, r, 7)
	for k in 18:
		var a := r.randf() * TAU
		var at := Vector3(cos(a) * r.randf_range(1.6, 2.7), r.randf_range(2.4, 3.6), sin(a) * r.randf_range(1.6, 2.7))
		l.box(at, Vector3(0.42, 0.03, 0.36), FIG_LEAF.lightened(0.14), Vector3(r.randf_range(-30, 30), r.randf() * 180, r.randf_range(-30, 30)))


## The pomegranate: a bushy little tree of many thin stems, glossy leaves, scarlet flowers and fruit.
static func _pomegranate(l: LowPoly, r: RandomNumberGenerator) -> void:
	for k in 5:
		var a := TAU * k / 5.0 + r.randf() * 0.4
		limb(l, [Vector3(cos(a) * 0.08, -0.9, sin(a) * 0.08), Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.4), Vector3(cos(a) * 0.9, 1.9, sin(a) * 0.9)] as Array[Vector3], 0.07, 0.04, OAK_BARK.lightened(0.1), 5)
	for k in 8:
		var a := TAU * k / 8.0 + r.randf() * 0.4
		var ring := 0.0 if k == 0 else r.randf_range(0.7, 1.2)
		clump(l, Vector3(cos(a) * ring, 2.2 + r.randf_range(-0.3, 0.4), sin(a) * ring), r.randf_range(0.65, 0.85), 0.75, POMEGRANATE_LEAF.lightened(0.06) if k % 2 else POMEGRANATE_LEAF, r, 6)
	for k in 14:
		var a := r.randf() * TAU
		var at := Vector3(cos(a) * r.randf_range(0.9, 1.5), r.randf_range(1.6, 2.9), sin(a) * r.randf_range(0.9, 1.5))
		if k % 3 == 0:
			l.prism(at, at + Vector3(0, 0.14, 0), 0.06, 0.1, 6, POMEGRANATE_RED.lightened(0.15)) # a flower's trumpet
		else:
			l.ovoid(at, Vector3(0.12, 0.11, 0.12), POMEGRANATE_RED, POMEGRANATE_RED.darkened(0.35), 3, 6)
			l.prism(at + Vector3(0, 0.1, 0), at + Vector3(0, 0.16, 0), 0.04, 0.05, 5, POMEGRANATE_RED.darkened(0.2))


## The dwarf fan palm, the one palm native to these shores: a clump of short shaggy stems and stiff fans.
static func _fan_palm(l: LowPoly, r: RandomNumberGenerator) -> void:
	for s in 3:
		var a := TAU * s / 3.0 + r.randf() * 0.6
		var base := Vector3(cos(a) * 0.25, -0.5, sin(a) * 0.25)
		var top := base + Vector3(cos(a) * 0.25, 0.9 + r.randf() * 0.4, sin(a) * 0.25)
		l.prism(base, top, 0.14, 0.11, 6, PALM_FIBRE)
		for f in 7:
			var fa := TAU * f / 7.0 + r.randf() * 0.4
			var out := Vector3(cos(fa), 0.0, sin(fa))
			var stalk := top + out * 0.5 + Vector3(0, 0.35, 0)
			l.prism(top, stalk, 0.02, 0.015, 3, PALM_GREEN.darkened(0.2))
			# The fan: ribs spread from the stalk's end.
			for k in 5:
				var ra := fa + (k - 2) * 0.22
				var tip := stalk + Vector3(cos(ra), 0.25 + r.randf() * 0.15, sin(ra)) * 0.55
				var side := Vector3(-sin(ra), 0, cos(ra)) * 0.06
				l.leaf(stalk, tip + side, tip - side, PALM_GREEN.lightened(0.05 * (k % 2)))


## A meadow of wildflowers size metres across: poppies, broom, lavender, chamomile and rock-rose, in
## drifts of one colour shading into the next.
static func wildflowers(b: MapBuilder, size: float) -> void:
	if not b._plant_allowed(b.xf.origin, 0.5):
		return
	var r := b.seeded()
	var l := _herb_cell(b)
	var count := int(size * size * [0.25, 0.45, 0.7][b.quality])
	var drift := r.randi_range(0, FLOWERS.size() - 1)
	for k in count:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * size * 0.5
		var local := Vector3(cos(a) * d, 0, sin(a) * d)
		var at := b.on_ground(local)
		if b.terrain.isle_depth(at.x, at.z) > 0.0 or b.terrain.slope(at.x, at.z) > 0.7:
			continue
		# Drifts: the colour shifts across the meadow rather than speckling.
		var c: Color = FLOWERS[(drift + int(floor((local.x + local.z * 0.6) / (size * 0.3) + r.randf() * 0.7))) % FLOWERS.size()]
		var tall := r.randf_range(0.25, 0.55)
		var top := at + Vector3(r.randf_range(-0.05, 0.05), tall, r.randf_range(-0.05, 0.05))
		l.base = Transform3D.IDENTITY
		l.root_y = at.y
		l.prism(at, top, 0.012, 0.008, 3, STEM)
		var petal := r.randf_range(0.07, 0.11)
		l.box(top, Vector3(petal, 0.03, petal), c, Vector3(0, r.randf() * 90, 0))
		if c == FLOWERS[2]:
			# Lavender: a spike, not a cup.
			l.box(top + Vector3.UP * 0.06, Vector3(0.035, 0.14, 0.035), c.darkened(0.1))


## A thicket of maquis size metres across: rosemary, lentisk, myrtle, and broom in yellow flower.
static func maquis(b: MapBuilder, size: float) -> void:
	if not b._plant_allowed(b.xf.origin, 0.8):
		return
	var r := b.seeded()
	var l := _herb_cell(b)
	var count := int(size * [1.0, 1.6, 2.2][b.quality])
	for k in count:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * size * 0.5
		var at := b.on_ground(Vector3(cos(a) * d, 0, sin(a) * d))
		if at.y < Terrain.ISLE_SEA_Y + 0.5 and not b.terrain.isle.is_empty():
			continue
		l.base = Transform3D.IDENTITY
		l.root_y = at.y
		var bush := r.randf_range(0.35, 0.75)
		var col := [Color(0.24, 0.33, 0.2), Color(0.3, 0.36, 0.24), Color(0.2, 0.28, 0.18)][k % 3] as Color
		clump(l, at + Vector3.UP * bush * 0.6, bush, 0.75, col, r, 6)
		if k % 4 == 0:
			# Broom in flower.
			for q in 5:
				l.box(at + Vector3(r.randf_range(-bush, bush) * 0.6, bush * 1.1 + r.randf() * 0.2, r.randf_range(-bush, bush) * 0.6), Vector3(0.09, 0.09, 0.09), FLOWERS[1])


static func _herb_cell(b: MapBuilder) -> LowPoly:
	var key := Vector2i(int(floor(b.xf.origin.x / 24.0)), int(floor(b.xf.origin.z / 24.0)))
	if not _herbs.has(key):
		var l := LowPoly.new()
		l.rooted = true
		_herbs[key] = l
	return _herbs[key]


## The flowers and shrubs, one mesh per square, all moving in the wind.
static func flush(b: MapBuilder) -> void:
	for key: Vector2i in _herbs:
		var m := (_herbs[key] as LowPoly).commit()
		if m.get_surface_count() == 0:
			continue
		m.surface_set_material(0, herb_material())
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = [70.0, 95.0, 130.0][b.quality]
		b.w.add_child(mi)
	_herbs.clear()


# --- The field: the whole island planted ---------------------------------------------------------
# One piece (MapFonta "flora") plants Fontanova from its land: what grows where depends on how high it
# is, how steep, how near the sea, and which part of the island (FIELD_ZONES). Plants keep off the
# roads, the paths and anything built; trees keep further off. Flowers grow in drifts of one kind,
# not speckled; trees in groves with glades between.

const POPPY := Color(0.86, 0.1, 0.07)
const DAISY := Color(0.96, 0.95, 0.9)
const CHAMOMILE := Color(0.97, 0.95, 0.82)
const GOLD := Color(0.95, 0.78, 0.14)
const LAVENDER := Color(0.55, 0.42, 0.8)
const THYME := Color(0.72, 0.5, 0.75)
const BORAGE := Color(0.35, 0.5, 0.95)
const GLADIOLUS := Color(0.85, 0.2, 0.55)
const ASPHODEL := Color(0.95, 0.93, 0.88)
const LEAF_GREEN := Color(0.3, 0.42, 0.2)
const DRY_GRASS := Color(0.78, 0.68, 0.38)
const GREEN_GRASS := Color(0.45, 0.55, 0.26)
const ROSEMARY := Color(0.26, 0.36, 0.28)
const LENTISK := Color(0.2, 0.3, 0.17)
const MYRTLE := Color(0.18, 0.32, 0.16)
const ROCKROSE := Color(0.95, 0.75, 0.85)
const OLEANDER := Color(0.95, 0.5, 0.65)

## The island's parts and what grows in each: their trees (and how thickly), shrubs, and flowers.
##   "c" centre, "r" radius (an ellipse with "s" stretch along X), "trees" weights by kind, "grove" the
##   chance a tree stands in a 6 m square inside a grove, "herbs" weights by kind, "lush" how thick.
const FIELD_ZONES := [
	{"name": "landing", "c": Vector2(0, 92), "r": 40.0, "s": 1.6, "trees": {"fan_palm": 4, "pomegranate": 1, "fig": 1}, "grove": 0.12, "herbs": {"golden_grass": 4, "asphodel": 2, "sea_lavender": 3, "rockrose": 1, "fan_palm_small": 1}, "lush": 0.7},
	{"name": "terraces", "c": Vector2(0, 26), "r": 58.0, "s": 1.2, "trees": {"olive": 12, "almond": 4, "carob": 2, "fig": 1, "pomegranate": 1}, "grove": 0.62, "herbs": {"poppy": 4, "daisy": 3, "chamomile": 2, "green_grass": 4, "borage": 1, "gladiolus": 1, "lavender": 1}, "lush": 1.0},
	{"name": "upper", "c": Vector2(10, -24), "r": 34.0, "s": 1.3, "trees": {"olive": 8, "almond": 3, "carob": 3, "cypress": 1}, "grove": 0.5, "herbs": {"poppy": 3, "gladiolus": 2, "chamomile": 2, "golden_grass": 3, "acanthus": 1, "thyme": 2}, "lush": 0.95},
	{"name": "rim", "c": Vector2(-44, -12), "r": 22.0, "s": 0.6, "trees": {"stone_pine": 3, "cypress": 2, "olive": 2, "fig": 1}, "grove": 0.3, "herbs": {"thyme": 3, "golden_grass": 4, "rockrose": 2, "lavender": 2, "rosemary": 2}, "lush": 0.85},
	{"name": "ridge", "c": Vector2(-98, 2), "r": 30.0, "s": 0.45, "trees": {"stone_pine": 5, "cypress": 1, "holm_oak": 1}, "grove": 0.35, "herbs": {"golden_grass": 5, "thyme": 3, "rosemary": 3, "lentisk": 2, "rockrose": 2, "asphodel": 1}, "lush": 0.8},
	{"name": "wood", "c": Vector2(84, -20), "r": 30.0, "s": 0.8, "trees": {"holm_oak": 7, "madrono": 4, "stone_pine": 1}, "grove": 0.85, "herbs": {"green_grass": 3, "acanthus": 2, "myrtle": 3, "lentisk": 2, "borage": 1, "asphodel": 1}, "lush": 1.0},
	{"name": "acropolis", "c": Vector2(0, -88), "r": 36.0, "s": 1.2, "trees": {"cypress": 3, "olive": 1}, "grove": 0.1, "herbs": {"acanthus": 3, "golden_grass": 3, "poppy": 1, "thyme": 2, "asphodel": 2}, "lush": 0.6},
	{"name": "east", "c": Vector2(50, 40), "r": 40.0, "s": 1.0, "trees": {"olive": 5, "carob": 3, "almond": 2, "stone_pine": 2, "pomegranate": 1}, "grove": 0.45, "herbs": {"poppy": 3, "golden_grass": 3, "daisy": 2, "lavender": 2, "oleander": 1}, "lush": 0.9},
	{"name": "crags", "c": Vector2(0, -100), "r": 90.0, "s": 1.0, "trees": {"stone_pine": 4, "cypress": 1}, "grove": 0.2, "herbs": {"golden_grass": 4, "thyme": 2, "rosemary": 2, "lentisk": 2}, "lush": 0.6},
]
const HERB_CELL := 2.5
const TREE_CELL := 6.0


## The part of the island a point is in: the nearest zone, measured in its own radii.
static func zone_at(x: float, z: float) -> Dictionary:
	var best: Dictionary = FIELD_ZONES[FIELD_ZONES.size() - 1]
	var best_d := INF
	for zone: Dictionary in FIELD_ZONES:
		var c: Vector2 = zone["c"]
		var d := Vector2((x - c.x) / float(zone["s"]), z - c.y).length() / float(zone["r"])
		if d < best_d:
			best_d = d
			best = zone
	return best


static func _pick(weights: Dictionary, roll: float) -> String:
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var at := roll * total
	for k: String in weights:
		at -= float(weights[k])
		if at <= 0.0:
			return k
	return weights.keys()[0]


## Whether a point is on (or within margin of) a road or path.
static func _on_road(b: MapBuilder, p: Vector2, margin: float) -> bool:
	for line: Array[Vector2] in b.w.map_roads:
		for i in line.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])) < 2.2 + margin:
				return true
	return false


static func field(b: MapBuilder, radius: float) -> void:
	var t := b.terrain
	var grove_noise := FastNoiseLite.new()
	grove_noise.seed = 1717
	grove_noise.frequency = 0.035
	var drift_noise := FastNoiseLite.new()
	drift_noise.seed = 2929
	drift_noise.frequency = 0.06
	var lush_noise := FastNoiseLite.new()
	lush_noise.seed = 4141
	lush_noise.frequency = 0.08
	var r := RandomNumberGenerator.new()
	r.seed = 515151
	var density: float = [0.35, 0.65, 1.0][b.quality]
	var keep := b.xf
	# Trees, in groves.
	var steps := int(radius * 2.0 / TREE_CELL)
	for j in steps:
		for i in steps:
			var x := -radius + (i + r.randf_range(0.15, 0.85)) * TREE_CELL
			var z := -radius + (j + r.randf_range(0.15, 0.85)) * TREE_CELL
			var roll := r.randf()
			var kind_roll := r.randf()
			var size_roll := r.randf()
			if not _plantable(t, x, z, 0.55):
				continue
			var zone := zone_at(x, z)
			var grove := 0.5 + 0.5 * grove_noise.get_noise_2d(x, z)
			if roll > float(zone["grove"]) * (0.35 + grove * 1.15):
				continue
			if _on_road(b, Vector2(x, z), 2.5):
				continue
			var kind := _pick(zone["trees"], kind_roll)
			var nominal: float = NOMINAL[kind]
			b.stand_at(Transform3D(Basis(Vector3.UP, size_roll * TAU), Vector3(x, t.height(x, z), z)))
			if not b._plant_allowed(b.xf.origin, 1.5) or b.tree_clearings.any(func(c: Vector3) -> bool: return Vector2(x - c.x, z - c.y).length() < c.z):
				continue
			tree(b, kind, nominal * lerpf(0.75, 1.25, size_roll))
	# Flowers, grasses and shrubs, in drifts.
	steps = int(radius * 2.0 / HERB_CELL)
	for j in steps:
		for i in steps:
			var cx := -radius + (i + 0.5) * HERB_CELL
			var cz := -radius + (j + 0.5) * HERB_CELL
			if not _plantable(t, cx, cz, 0.8):
				continue
			var zone := zone_at(cx, cz)
			var lush := float(zone["lush"]) * (0.55 + 0.45 * lush_noise.get_noise_2d(cx, cz)) * density
			var count := int(lush * 7.0 + r.randf())
			# One kind holds each drift; a second kind mixes in at its edges.
			var drift := 0.5 + 0.5 * drift_noise.get_noise_2d(cx, cz)
			var main := _pick(zone["herbs"], drift)
			var other := _pick(zone["herbs"], fposmod(drift + 0.37, 1.0))
			b.stand_at(Transform3D(Basis.IDENTITY, Vector3(cx, t.height(cx, cz), cz)))
			var l := _herb_cell(b)
			for k in count:
				var x := cx + r.randf_range(-HERB_CELL * 0.5, HERB_CELL * 0.5)
				var z := cz + r.randf_range(-HERB_CELL * 0.5, HERB_CELL * 0.5)
				if not _plantable(t, x, z, 0.8) or _on_road(b, Vector2(x, z), 0.2) or not b._plant_allowed(Vector3(x, 0, z), 0.3):
					continue
				var at := Vector3(x, t.height(x, z) - 0.04, z)
				herb(l, main if r.randf() < 0.75 else other, at, r)
	_terrace_faces(b)
	carpet(b, radius)
	b.stand_at(keep)


## The grass under everything: tufts close together over every patch of open ground, drawn as
## instances of a few tufts in squares that only show near the eye, so a lush island costs little.
## Each tuft takes its colour from where it grows: greener where the ground holds water and in the
## wood, sun-dried gold on the ridges and the crags, a little of each everywhere.
const CARPET_CELL := 12.0
const CARPET_DENSITY := [1.0, 2.0, 3.2] # tufts per square metre, by quality
const CARPET_SIGHT := [26.0, 34.0, 44.0]


static func carpet(b: MapBuilder, radius: float) -> void:
	var t := b.terrain
	var r := RandomNumberGenerator.new()
	r.seed = 828282
	var wet := FastNoiseLite.new()
	wet.seed = 6161
	wet.frequency = 0.045
	var thick := FastNoiseLite.new()
	thick.seed = 7272
	thick.frequency = 0.09
	var per_cell := int(CARPET_CELL * CARPET_CELL * float(CARPET_DENSITY[b.quality]))
	var steps := int(radius * 2.0 / CARPET_CELL)
	var tufts := tuft_meshes()
	for j in steps:
		for i in steps:
			var x0 := -radius + i * CARPET_CELL
			var z0 := -radius + j * CARPET_CELL
			var centre := Vector3(x0 + CARPET_CELL * 0.5, 0, z0 + CARPET_CELL * 0.5)
			centre.y = t.height(centre.x, centre.z)
			if not _plantable(t, centre.x, centre.z, 2.0) and not _plantable(t, x0, z0, 2.0) and not _plantable(t, x0 + CARPET_CELL, z0 + CARPET_CELL, 2.0):
				continue # all sea
			# Only the stretches of road that pass near this square need checking.
			var near_roads: Array[PackedVector2Array] = []
			var box := Rect2(x0 - 3.0, z0 - 3.0, CARPET_CELL + 6.0, CARPET_CELL + 6.0)
			for line: Array[Vector2] in b.w.map_roads:
				for n in line.size() - 1:
					if box.intersects(Rect2(line[n], Vector2.ZERO).expand(line[n + 1]).grow(0.01)):
						near_roads.append(PackedVector2Array([line[n], line[n + 1]]))
			var near_clearings: Array[Vector3] = []
			for c: Vector3 in b._plant_clearings:
				if Vector2(c.x, c.y).distance_to(Vector2(centre.x, centre.z)) < c.z + CARPET_CELL:
					near_clearings.append(c)
			var near_rooms: Array[Dictionary] = []
			for room: Dictionary in b._plant_rooms:
				var origin := (room["inverse"] as Transform3D).affine_inverse().origin
				if Vector2(origin.x, origin.z).distance_to(Vector2(centre.x, centre.z)) < (room["half"] as Vector2).length() + CARPET_CELL:
					near_rooms.append(room)
			var spots: Array[Array] = [[], [], []]
			for k in per_cell:
				var x := x0 + r.randf() * CARPET_CELL
				var z := z0 + r.randf() * CARPET_CELL
				var roll := r.randf()
				var shape := r.randi() % tufts.size()
				var turn := r.randf() * TAU
				var tall := r.randf_range(0.7, 1.3)
				# Thicker in some places than others, never bald.
				if roll > 0.45 + 0.55 * (0.5 + 0.5 * thick.get_noise_2d(x, z)):
					continue
				if not _plantable(t, x, z, 0.75):
					continue
				var on_road := false # or anything else that keeps it bare
				for c in near_clearings:
					if Vector2(x - c.x, z - c.y).length() < c.z + 0.2:
						on_road = true
						break
				for room in near_rooms:
					var local: Vector3 = (room["inverse"] as Transform3D) * Vector3(x, 0, z)
					var half: Vector2 = room["half"]
					if absf(local.x) < half.x + 0.2 and absf(local.z) < half.y + 0.2:
						on_road = true
				for seg in near_roads:
					if Vector2(x, z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x, z), seg[0], seg[1])) < 2.2:
						on_road = true
						break
				if on_road:
					continue
				var zone := zone_at(x, z)
				var dry: float = {"ridge": 0.75, "crags": 0.8, "rim": 0.6, "acropolis": 0.6, "landing": 0.7, "wood": 0.05, "terraces": 0.25, "upper": 0.4, "east": 0.35}.get(zone["name"], 0.4)
				dry = clampf(dry + wet.get_noise_2d(x, z) * 0.45, 0.0, 1.0)
				var col := GREEN_GRASS.lerp(DRY_GRASS, dry).darkened(r.randf_range(0.0, 0.22))
				var basis := Basis(Vector3.UP, turn).scaled(Vector3(tall, tall * r.randf_range(0.8, 1.2), tall))
				spots[shape].append([Transform3D(basis, Vector3(x, t.height(x, z) - 0.03, z) - centre), col])
			for shape in tufts.size():
				var list: Array = spots[shape]
				if list.is_empty():
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.mesh = tufts[shape]
				mm.instance_count = list.size()
				for n in list.size():
					mm.set_instance_transform(n, list[n][0])
					mm.set_instance_color(n, list[n][1])
				var node := MultiMeshInstance3D.new()
				node.multimesh = mm
				node.material_override = grass_material()
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.visibility_range_end = float(CARPET_SIGHT[b.quality])
				node.visibility_range_end_margin = 6.0
				node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				b.w.add_child(node)
				node.position = centre


## Three tufts of grass blades, white so each instance can be tinted: a low dense one, a taller
## loose one, and one with a few seed heads standing out of it.
static func tuft_meshes() -> Array[Mesh]:
	if not _tufts.is_empty():
		return _tufts
	var r := RandomNumberGenerator.new()
	r.seed = 3131
	for shape in 3:
		var l := LowPoly.new()
		var blades: int = [14, 11, 9][shape]
		var high: float = [0.26, 0.4, 0.34][shape]
		for k in blades:
			var a := TAU * k / blades + r.randf_range(-0.3, 0.3)
			var foot := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.03, 0.14)
			var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.06, 0.18)
			var h := high * r.randf_range(0.65, 1.15)
			var side := Vector3(-sin(a), 0, cos(a)) * r.randf_range(0.04, 0.065)
			var shade := Color.WHITE.darkened(r.randf_range(0.0, 0.25))
			l.leaf(foot - side, foot + side, foot + lean + Vector3.UP * h, shade)
		if shape == 2:
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				var top := Vector3(cos(a) * 0.08, 0.55 + k * 0.05, sin(a) * 0.08)
				l.prism(Vector3.ZERO, top, 0.008, 0.006, 3, Color(0.9, 0.85, 0.7))
				l.ovoid(top + Vector3.UP * 0.04, Vector3(0.02, 0.06, 0.02), Color(1.0, 0.95, 0.8), Color(0.85, 0.8, 0.6), 2, 4)
		_tufts.append(l.commit())
	return _tufts


## Somewhere a plant can grow: dry land, not a cliff, not the Ravine.
static func _plantable(t: Terrain, x: float, z: float, steep: float) -> bool:
	if t.isle_depth(x, z) > 0.0 or t.height(x, z) < Terrain.ISLE_SEA_Y + 0.4:
		return false
	if not t.chasms.is_empty() and t.in_chasm(x, z):
		return false
	return t.slope(x, z) < steep


## One plant of the kind, its root at `at` (the wind bends it from there).
static func herb(l: LowPoly, kind: String, at: Vector3, r: RandomNumberGenerator) -> void:
	l.root_y = at.y
	l.base = Transform3D.IDENTITY
	match kind:
		"poppy": _flower(l, at, r, POPPY, r.randf_range(0.3, 0.55), 0.09, Color(0.1, 0.06, 0.06), 5)
		"daisy": _flower(l, at, r, DAISY, r.randf_range(0.15, 0.3), 0.07, GOLD, 8)
		"chamomile": _flower(l, at, r, CHAMOMILE, r.randf_range(0.2, 0.35), 0.05, GOLD, 7, 3)
		"borage": _flower(l, at, r, BORAGE, r.randf_range(0.25, 0.4), 0.06, Color(0.1, 0.1, 0.15), 5)
		"lavender", "sea_lavender": _lavender(l, at, r, LAVENDER if kind == "lavender" else Color(0.6, 0.5, 0.85))
		"thyme": _thyme(l, at, r)
		"gladiolus": _spike(l, at, r, GLADIOLUS, r.randf_range(0.5, 0.8))
		"asphodel": _spike(l, at, r, ASPHODEL, r.randf_range(0.7, 1.05))
		"golden_grass": _grass(l, at, r, DRY_GRASS, r.randf_range(0.35, 0.7))
		"green_grass": _grass(l, at, r, GREEN_GRASS, r.randf_range(0.25, 0.5))
		"acanthus": _acanthus(l, at, r)
		"rosemary": _shrub(l, at, r, ROSEMARY, Color(0.6, 0.65, 0.95), r.randf_range(0.35, 0.6))
		"lentisk": _shrub(l, at, r, LENTISK, Color(0.75, 0.2, 0.15), r.randf_range(0.5, 0.85))
		"myrtle": _shrub(l, at, r, MYRTLE, DAISY, r.randf_range(0.45, 0.75))
		"rockrose": _shrub(l, at, r, LEAF_GREEN, ROCKROSE, r.randf_range(0.3, 0.5))
		"oleander": _shrub(l, at, r, LEAF_GREEN.darkened(0.1), OLEANDER, r.randf_range(0.8, 1.2))
		"broom": _shrub(l, at, r, LEAF_GREEN, GOLD, r.randf_range(0.6, 0.9))
		"fan_palm_small": _grass(l, at, r, PALM_GREEN, r.randf_range(0.4, 0.6), 9)


## A flower on its stem: leaves at the foot, the head turned up, petals round a heart.
static func _flower(l: LowPoly, at: Vector3, r: RandomNumberGenerator, petal: Color, tall: float, wide: float, heart: Color, petals: int, heads := 1) -> void:
	for h in heads:
		var top := at + Vector3(r.randf_range(-0.08, 0.08), tall * r.randf_range(0.85, 1.0), r.randf_range(-0.08, 0.08))
		var stem_side := Vector3(0.012, 0, 0)
		l.leaf(at - stem_side, top, at + stem_side, STEM)
		l.leaf(at + Vector3(0, 0, 0.012), top, at - Vector3(0, 0, 0.012), STEM)
		var turn := r.randf() * TAU
		for k in petals:
			var a := turn + TAU * k / petals
			var out := Vector3(cos(a), 0.25, sin(a)) * wide
			var side := Vector3(-sin(a), 0, cos(a)) * wide * 0.35
			l.leaf(top, top + out + side, top + out - side, petal.darkened(0.06 * (k % 2)))
		l.box(top + Vector3.UP * 0.012, Vector3(wide * 0.45, 0.025, wide * 0.45), heart)
	# A rosette of leaves at the foot.
	for k in 3:
		var a := r.randf() * TAU
		var tip := at + Vector3(cos(a) * 0.14, 0.05, sin(a) * 0.14)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.03
		l.leaf(at + Vector3.UP * 0.01, tip + side, tip - side, LEAF_GREEN)


static func _lavender(l: LowPoly, at: Vector3, r: RandomNumberGenerator, col: Color) -> void:
	for k in 7:
		var a := r.randf() * TAU
		var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.04, 0.14)
		var top := at + lean + Vector3.UP * r.randf_range(0.3, 0.48)
		l.leaf(at - Vector3(0.01, 0, 0), top, at + Vector3(0.01, 0, 0), Color(0.42, 0.5, 0.38))
		l.box(top + Vector3.UP * 0.04, Vector3(0.035, 0.11, 0.035), col.darkened(r.randf() * 0.15))


static func _thyme(l: LowPoly, at: Vector3, r: RandomNumberGenerator) -> void:
	l.ovoid(at + Vector3.UP * 0.05, Vector3(0.22, 0.08, 0.2), Color(0.38, 0.45, 0.3), Color(0.25, 0.32, 0.2), 2, 6)
	for k in 6:
		var a := r.randf() * TAU
		var d := r.randf() * 0.18
		l.box(at + Vector3(cos(a) * d, 0.11, sin(a) * d), Vector3(0.05, 0.03, 0.05), THYME.darkened(r.randf() * 0.15))


## A tall flowering spike (asphodel, gladiolus): a stem with flowers set up its upper half.
static func _spike(l: LowPoly, at: Vector3, r: RandomNumberGenerator, col: Color, tall: float) -> void:
	var top := at + Vector3(r.randf_range(-0.05, 0.05), tall, r.randf_range(-0.05, 0.05))
	l.leaf(at - Vector3(0.014, 0, 0), top, at + Vector3(0.014, 0, 0), STEM)
	l.leaf(at - Vector3(0, 0, 0.014), top, at + Vector3(0, 0, 0.014), STEM)
	for k in 6:
		var p := at.lerp(top, 0.5 + k * 0.09)
		var a := k * 2.1
		l.box(p + Vector3(cos(a), 0, sin(a)) * 0.03, Vector3(0.06, 0.05, 0.06), col.darkened(0.05 * (k % 2)), Vector3(0, a * 57.0, 20))
	# Long strap leaves at the foot.
	for k in 4:
		var a := r.randf() * TAU
		var tip := at + Vector3(cos(a) * 0.22, 0.28, sin(a) * 0.22)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		l.leaf(at, tip + side, tip - side, LEAF_GREEN)


## A tuft of grass: thin blades fanned from one root, leaning out a little.
static func _grass(l: LowPoly, at: Vector3, r: RandomNumberGenerator, col: Color, tall: float, blades := 6) -> void:
	for k in blades:
		var a := r.randf() * TAU
		var lean := Vector3(cos(a), 0, sin(a)) * tall * r.randf_range(0.15, 0.4)
		var tip := at + lean + Vector3.UP * tall * r.randf_range(0.7, 1.0)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.022
		l.leaf(at - side, tip, at + side, col.lerp(col.lightened(0.25), r.randf()))


## Acanthus: the leaf on every column's capital, a rosette of great deep-cut leaves.
static func _acanthus(l: LowPoly, at: Vector3, r: RandomNumberGenerator) -> void:
	for k in 7:
		var a := TAU * k / 7.0 + r.randf() * 0.3
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var mid := at + out * 0.25 + Vector3.UP * 0.22
		var tip := at + out * 0.5 + Vector3.UP * 0.1
		l.leaf(at, mid + side * 0.12, mid - side * 0.12, Color(0.2, 0.36, 0.16))
		l.leaf(mid + side * 0.12, tip, mid - side * 0.12, Color(0.24, 0.4, 0.18))
	if r.randf() < 0.5:
		_spike(l, at, r, Color(0.85, 0.75, 0.85), 0.7)


## A shrub: a few rounded clumps of small leaves, flowers or berries dotted over them.
static func _shrub(l: LowPoly, at: Vector3, r: RandomNumberGenerator, leaf: Color, bloom: Color, size: float) -> void:
	for k in 3:
		var off := Vector3(r.randf_range(-0.3, 0.3), 0, r.randf_range(-0.3, 0.3)) * size
		clump(l, at + off + Vector3.UP * size * 0.55, size * r.randf_range(0.55, 0.8), 0.8, leaf.lightened(0.05 * k), r, 6)
	for k in 7:
		var a := r.randf() * TAU
		var d := size * r.randf_range(0.3, 0.6)
		l.box(at + Vector3(cos(a) * d, size * r.randf_range(0.6, 1.0), sin(a) * d), Vector3(0.07, 0.07, 0.07), bloom)


## The olive terraces' risers faced with dry stone: a wall of rough, weathered blocks laid along the
## middle of each riser, half set into it (it is walked over like the riser itself).
static func _terrace_faces(b: MapBuilder) -> void:
	var t := b.terrain
	var keep := b.xf
	b.stand_at(Transform3D.IDENTITY)
	var l := b.mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2323
	const GAP := 0.6
	for zone: Dictionary in t._terraced:
		var c: Vector2 = zone["c"]
		var rad: float = zone["r"]
		var step: float = zone["step"]
		var x := c.x - rad
		while x < c.x + rad:
			var z := c.y - rad
			while z < c.y + rad:
				z += GAP
				if Vector2(x, z).distance_to(c) > rad - float(zone["f"]):
					continue
				var h := t.height(x, z)
				var q := h / step
				var frac := q - floorf(q)
				if frac < 0.7 or frac > 0.86 or t.slope(x, z) < 0.25 or _on_road(b, Vector2(x, z), 0.3):
					continue
				var gx := t.height(x + 0.5, z) - t.height(x - 0.5, z)
				var gz := t.height(x, z + 0.5) - t.height(x, z - 0.5)
				var yaw := rad_to_deg(atan2(gx, gz))
				var stone := Color(0.6, 0.54, 0.45).darkened(rng.randf_range(0.0, 0.25))
				l.box(Vector3(x, h - 0.1, z), Vector3(rng.randf_range(0.55, 0.8), rng.randf_range(0.35, 0.55), rng.randf_range(0.4, 0.55)), stone, Vector3(rng.randf_range(-8, 8), yaw + rng.randf_range(-10, 10), rng.randf_range(-6, 6)))
			x += GAP
	b.add(l)
	b.stand_at(keep)
