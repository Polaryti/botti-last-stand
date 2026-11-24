class_name FontaFlora
## The plants of Fontanova: not the tropics but the Mediterranean, dry and scented. Olives grey-green
## and gnarled, holm oaks dark and dense, strawberry trees with red bark and red fruit, carobs spreading
## wide with their pods hanging, cypresses like dark flames; meadows of poppies, broom, lavender and
## chamomile; thickets of maquis. Every one of them moves in the wind (flora_sway.gdshader), harder on a
## windy night (set_wind).
## Trees are drawn once each and scattered (MapBuilder.tree with "flora:<kind>"); flowers and shrubs are
## merged per 24 m square, like the map's other small things.

const NOMINAL := {"olive": 4.5, "holm_oak": 7.0, "madrono": 5.0, "carob": 6.0, "cypress": 10.0}
## Where a Mutant Spider can cling, at a tree's own size: the trunk's girth (its radius, bark and all)
## and how high it runs clear of leaves. A cypress is leaves to the ground: nothing clings to it.
const TRUNKS := {"olive": Vector2(0.42, 1.5), "holm_oak": Vector2(0.38, 2.4), "madrono": Vector2(0.5, 1.4), "carob": Vector2(0.45, 1.9)}

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
static var _gust := 0.0


## How the wind blows tonight: 0 still, 1 a windy night, and which way (Weather).
static func set_wind(gust: float, dir: Vector3) -> void:
	_gust = gust
	for m: ShaderMaterial in [tree_material(), herb_material()]:
		m.set_shader_parameter("gust", gust)
		m.set_shader_parameter("wind", Vector2(dir.x, dir.z))


static func tree_material() -> ShaderMaterial:
	if _tree_material == null:
		_tree_material = ShaderMaterial.new()
		_tree_material.shader = load("res://assets/shaders/flora_sway.gdshader")
		_tree_material.set_shader_parameter("bend", 0.0045)
	return _tree_material


static func herb_material() -> ShaderMaterial:
	if _herb_material == null:
		_herb_material = ShaderMaterial.new()
		_herb_material.shader = load("res://assets/shaders/flora_sway.gdshader")
		_herb_material.set_shader_parameter("bend", 0.5)
	return _herb_material


## A tree of the kind, size metres tall, set down where the piece stands.
static func tree(b: MapBuilder, kind: String, size: float) -> void:
	var nominal: float = NOMINAL.get(kind, 5.0)
	var s := size / nominal
	# Cypresses are narrow: a blow cannot pass through one, but there is room either side.
	var planted: int = b.w.tree_spots.size()
	b.tree("flora:" + kind, s, 1.0, true)
	if TRUNKS.has(kind) and b.w.tree_spots.size() > planted:
		var trunk: Vector2 = TRUNKS[kind]
		b.w.spider_trunks.append({"at": b.xf.origin, "girth": trunk.x * s, "high": trunk.y * s})


static func tree_mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var l := LowPoly.new()
	var r := RandomNumberGenerator.new()
	r.seed = hash(kind) ^ 7331
	match kind:
		"olive": _olive(l, r)
		"holm_oak": _holm_oak(l, r)
		"madrono": _madrono(l, r)
		"carob": _carob(l, r)
		"cypress": _cypress(l, r)
	var m := l.commit()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, tree_material())
	_meshes[kind] = m
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
	var trunk: Array[Vector3] = [Vector3(0, -0.2, 0), Vector3(0.12, 0.6, 0.05), Vector3(-0.08, 1.2, 0.1), Vector3(0.1, 1.7, -0.05)]
	limb(l, trunk, 0.34, 0.2, OLIVE_BARK, 7)
	# Old olives are hollowed and ridged: a second, twisting strand of trunk.
	limb(l, [Vector3(0.18, -0.2, -0.12), Vector3(0.28, 0.7, -0.2), Vector3(0.1, 1.5, -0.1)] as Array[Vector3], 0.2, 0.12, OLIVE_BARK.darkened(0.1), 5)
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
	limb(l, [Vector3(0, -0.2, 0), Vector3(0.05, 1.4, 0), Vector3(-0.05, 2.6, 0.05)] as Array[Vector3], 0.42, 0.28, OAK_BARK, 7)
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
		limb(l, [Vector3(cos(a) * 0.15, -0.2, sin(a) * 0.15), Vector3(cos(a) * 0.45, 1.3, sin(a) * 0.45), Vector3(cos(a) * 0.8, 2.6, sin(a) * 0.8)] as Array[Vector3], 0.13, 0.07, MADRONO_BARK, 6)
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
	limb(l, [Vector3(0, -0.2, 0), Vector3(0.2, 1.1, 0.1), Vector3(0.1, 2.0, 0)] as Array[Vector3], 0.5, 0.36, CAROB_BARK, 7)
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
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 1.2, 0), 0.22, 0.16, 6, OAK_BARK)
	var tiers := 9
	for k in tiers:
		var t := float(k) / tiers
		var y := 0.8 + t * 8.4
		var w := sin(clampf(t * 1.15 + 0.12, 0.0, 1.0) * PI) * 1.15 + 0.12
		clump(l, Vector3(r.randf_range(-0.05, 0.05), y + 0.5, r.randf_range(-0.05, 0.05)), w, 1.1, CYPRESS_LIGHT if k % 2 else CYPRESS, r, 7)
	l.prism(Vector3(0, 9.3, 0), Vector3(0, 10.2, 0), 0.25, 0.0, 6, CYPRESS)


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
		_herbs[key] = LowPoly.new()
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
