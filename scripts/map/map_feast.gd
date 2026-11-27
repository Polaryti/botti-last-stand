@tool
class_name MapFeast
extends MapPiece
## Authored pieces of Thalys, the island of the god of feasts.

const GOLD := Color("f5bd59")
const CREAM := Color("f1d59e")
const CLAY := Color("ae513e")
const TEAL := Color("267b73")
const PLUM := Color("873654")
const WOOD := Color("654336")
const STONE := Color("c4996a")
const MOSS := Color("73823c")
const FRUIT := [Color("ffb83b"), Color("d94c53"), Color("8b499d"), Color("9ba445"), Color("f0813e")]
const COURT := 4.0
const BOSS_FROM := Vector3(0, COURT, -12)
const WALL_X := 25.0
const WALL_Z := 21.0

@export_enum("island", "court", "cornucopia", "orchard", "market", "kilns", "vineyard", "harbour", "ship", "shrine", "beacon", "grain") var kind := "court"
@export var cloth := TEAL


func land(t: Terrain, _at: Transform3D) -> void:
	if kind == "island":
		t.set_isle(PackedFloat32Array([90, 92, 82, 70, 73, 77, 89, 92, 93, 88, 85, 90, 99, 97, 91, 87]), 0.045)
		t.level(Vector2.ZERO, Vector2(30, 26), 0.0, COURT, 16.0)


func shapes_land() -> bool:
	return kind == "island"


func build(b: MapBuilder) -> void:
	match kind:
		"court": _court(b)
		"cornucopia": _cornucopia(b)
		"orchard": _orchard(b)
		"market": _market(b)
		"kilns": _kilns(b)
		"vineyard": _vineyard(b)
		"harbour": _harbour(b)
		"ship": FontaBuilder.sailboat(b, 26.0, true)
		"shrine": _shrine(b)
		"beacon": _lamp(b, Vector3.ZERO, cloth)
		"grain": _grain(b)


func _court(b: MapBuilder) -> void:
	if not b.is_preview:
		b.w.start_fort()
		b.w.fort.set_region(PackedVector2Array([Vector2(-WALL_X, -WALL_Z), Vector2(WALL_X, -WALL_Z), Vector2(WALL_X, WALL_Z), Vector2(-WALL_X, WALL_Z)]), COURT)
	var l := b.mesh()
	var light := b.mesh()
	_pave_court(b, l)
	var gate_names := ["Orchard", "Vine", "", "Hearth"]
	for side in 4:
		var out := Fort.DIRS[side]
		var along := Vector3(out.z, 0, -out.x)
		var width := WALL_X if side % 2 == 0 else WALL_Z
		var distance := WALL_Z if side % 2 == 0 else WALL_X
		var anchor := out * distance
		var gate_name: String = gate_names[side]
		var door := -9.0
		var gaps: Array[Vector3] = [Vector3(door - 0.95, door + 0.95, 2.55)]
		if gate_name != "":
			gaps.append(Vector3(-Fort.GATE_W * 0.5, Fort.GATE_W * 0.5, Fort.GATE_H))
		var cursor := -width
		for gap in gaps:
			_wall_span(b, l, anchor, along, cursor, gap.x, -0.5)
			_wall_span(b, l, anchor, along, gap.x, gap.y, gap.z)
			cursor = gap.y
		_wall_span(b, l, anchor, along, cursor, width, -0.5)
		# Painted cloth hangs inside every wall, clear of the gates and ramps.
		for offset: float in [-width + 6.0, width - 9.0]:
			_wall_banner(l, anchor + along * offset - out * 1.18, along, out, PLUM if offset < 0 else TEAL)
		var postern := anchor + along * door
		if not b.is_preview:
			b.w.fort.add_door(b.xf * postern, out)
			var plug := Vector3(1.9, 2.55, Fort.WALL_T) if side % 2 == 0 else Vector3(Fort.WALL_T, 2.55, 1.9)
			b.w.add_enemy_block(b.xf * (postern + Vector3.UP * 1.275), plug)
		if gate_name != "":
			_gate(b, l, gate_name, anchor, out, along)
		for pillar: float in [-width + 3.5, width - 3.5]:
			var at := anchor + along * pillar - out * 0.1
			var cap := at + Vector3.UP * Fort.WALL_H
			l.prism(at, cap + Vector3.UP * 1.7, 0.65, 0.55, 8, CLAY)
			l.prism(cap + Vector3.UP * 1.7, cap + Vector3.UP * 2.0, 0.85, 0.55, 8, GOLD)
			light.ovoid(cap + Vector3.UP * 2.22, Vector3(0.35, 0.56, 0.35), GOLD, CLAY, 3, 7)
		var ramp_top := anchor - out * 1.0 + along * (width - 7.0) + Vector3.UP * Fort.WALL_H
		var ramp_foot := ramp_top - out * 11.5 - Vector3.UP * Fort.WALL_H
		_walkway(b, l, ramp_foot, ramp_top, 2.2, CLAY)
		for k in range(2, int(width - 1), 2):
			for sign_at: int in [-1, 1]:
				var at := anchor + along * (float(k) * sign_at) + out * 0.83 + Vector3.UP * (Fort.WALL_H + 0.27)
				var size := Vector3(0.84, 0.55, 0.42) if side % 2 == 0 else Vector3(0.42, 0.55, 0.84)
				l.box(at, size, CREAM)
				b.collider(at, size)
	for x in [-WALL_X, WALL_X]:
		for z in [-WALL_Z, WALL_Z]:
			var corner := Vector3(x, 0, z)
			l.prism(corner - Vector3.UP, corner + Vector3.UP * 7.5, 2.5, 2.2, 8, STONE)
			l.prism(corner + Vector3.UP * 7.3, corner + Vector3.UP * 8.0, 2.7, 2.7, 8, TEAL)
			l.prism(corner + Vector3.UP * 8.0, corner + Vector3.UP * 10.1, 2.7, 0.05, 8, CLAY)
			b.solid(corner + Vector3.UP * 3.5, Vector3(3.9, 8.3, 3.9))
	b.add(l)
	b.shine(light)
	b._plant_clearings.append(Vector3(0, 0, 34))


func _wall_span(b: MapBuilder, l: LowPoly, anchor: Vector3, along: Vector3, start: float, end: float, low: float) -> void:
	var span := end - start
	var high := Fort.WALL_H
	var at := anchor + along * ((start + end) * 0.5) + Vector3.UP * ((low + high) * 0.5)
	var size := Vector3(span, high - low, Fort.WALL_T) if absf(along.x) > 0.5 else Vector3(Fort.WALL_T, high - low, span)
	l.box(at, size, STONE)
	if low < 0:
		# Raised blocks catch the light; broad gaps reveal the darker mortar behind.
		for course in 4:
			var y := 0.62 + course * 1.01
			var shift := 0.8 if course % 2 == 0 else 0.1
			var blocks := floori((span - shift) / 1.65)
			for i in blocks:
				var p := anchor + along * (start + shift + (i + 0.5) * 1.65) + Vector3.UP * y
				var block := Vector3(1.57, 0.91, Fort.WALL_T + 0.07) if absf(along.x) > 0.5 else Vector3(Fort.WALL_T + 0.07, 0.91, 1.57)
				l.box(p, block, STONE.darkened(0.06 + 0.05 * ((i * 3 + course) % 4)))
		b.solid(at, size)
	else:
		b.collider(at, size)
	for y in [4.75, 5.85, 6.35]:
		var band := Vector3(size.x + (0.12 if absf(along.z) > 0.5 else 0.0), 0.22, size.z + (0.12 if absf(along.x) > 0.5 else 0.0))
		l.box(Vector3(at.x, y, at.z), band, TEAL if y == 5.85 else CREAM)


func _pave_court(b: MapBuilder, l: LowPoly) -> void:
	# Two arcades and a tiled ring, with dirt recesses for supplies and unobstructed approaches.
	for x in range(-23, 24):
		for z in range(-19, 20):
			var r := Vector2(x, z).length()
			var radial := r > 6.3 and r < 8.3
			var avenue := absi(x) <= 2 or absi(z) <= 2
			if not radial and not avenue and r > 6.3:
				continue
			var at := Vector3(x, 0.042, z)
			var col := CLAY if (x + z) % 2 == 0 else CREAM.darkened(0.17)
			if radial:
				col = TEAL if (x - z) % 2 == 0 else GOLD.darkened(0.23)
			l.box(at, Vector3(0.965, 0.06, 0.965), col)
	for side: int in [-1, 1]:
		var table := Vector3(side * 13.0, 0, 8.0)
		l.box(table + Vector3.UP * 0.9, Vector3(5.3, 0.16, 1.87), WOOD)
		l.box(table + Vector3.UP * 1.0, Vector3(3.9, 0.05, 2.0), PLUM if side < 0 else TEAL)
		for j: float in [-2.25, 2.25]:
			l.box(table + Vector3(j, 0.45, 0.0), Vector3(0.25, 0.9, 1.6), WOOD)
		for i in 12:
			var at := table + Vector3(-2.2 + (i % 6) * 0.82, 1.19, -0.46 + floorf(i / 6.0) * 0.92)
			_fruit(l, at, 0.19 + (i % 3) * 0.052, i)
		b.solid(table + Vector3.UP * 0.47, Vector3(5.2, 0.95, 1.75))


func _wall_banner(l: LowPoly, at: Vector3, along: Vector3, out: Vector3, col: Color) -> void:
	var a := at + Vector3.UP * 5.37
	l.prism(a - along * 1.6, a + along * 1.6, 0.065, 0.065, 7, GOLD)
	var top := a - Vector3.UP * 0.08
	var base := at + Vector3.UP * 2.82 - out * 0.09
	for i in 10:
		var x := (i / 10.0 - 0.5) * 2.82
		var next := ((i + 1) / 10.0 - 0.5) * 2.82
		var p := top + along * x
		var q := top + along * next
		var r := base + along * x - Vector3.UP * (0.32 - absf(x) * 0.15)
		var t := base + along * next - Vector3.UP * (0.32 - absf(next) * 0.15)
		var dye := GOLD if i in [0, 9] else col.lightened(0.045 * (i % 3))
		l._tri(p, q, t, at + out, dye)
		l._tri(p, t, r, at + out, dye)
	var emblem := at + Vector3.UP * 4.07 - out * 0.068
	for i in 8:
		var angle := TAU * i / 8.0
		var next := TAU * (i + 1) / 8.0
		var left := emblem + (along * cos(angle) + Vector3.UP * sin(angle)) * 0.50
		var right := emblem + (along * cos(next) + Vector3.UP * sin(next)) * 0.50
		l.prism(left, right, 0.038, 0.038, 5, GOLD)
	l.prism(emblem - along * 0.34 - Vector3.UP * 0.12, emblem + along * 0.34 - Vector3.UP * 0.12, 0.058, 0.058, 5, CREAM)
	l.prism(emblem - Vector3.UP * 0.20, emblem + Vector3.UP * 0.30, 0.092, 0.013, 6, GOLD)


func _gate(b: MapBuilder, l: LowPoly, gate_name: String, at: Vector3, out: Vector3, along: Vector3) -> void:
	for end: float in [-1.0, 1.0]:
		var post := at + along * end * (Fort.GATE_W * 0.5 + 0.42) + out * 1.17
		l.prism(post, post + Vector3.UP * 5.1, 0.43, 0.38, 6, CLAY)
		l.prism(post + Vector3.UP * 4.2, post + Vector3.UP * 4.48, 0.58, 0.58, 6, GOLD)
	var gate := Node3D.new()
	gate.position = b.xf * at
	gate.rotation.y = 0.0 if absf(out.z) > 0.5 else PI * 0.5
	b.w.add_child(gate)
	var rows: Array[Node3D] = []
	for row in 5:
		var boards := LowPoly.new()
		var y := (row + 0.5) * Fort.GATE_H / 5.0
		for i in 8:
			var x := (i - 3.5) * Fort.GATE_W / 8.0
			boards.box(Vector3(x, y, 0), Vector3(0.67, Fort.GATE_H / 5.0, 0.48), WOOD.lightened(0.05 * (i % 3)))
			boards.box(Vector3(x, y, 0), Vector3(0.10, 0.12, 0.55), GOLD)
		for z in [-0.27, 0.27]:
			boards.box(Vector3(0, y - 0.22, z), Vector3(Fort.GATE_W, 0.12, 0.07), TEAL)
		var mesh := MeshInstance3D.new()
		mesh.mesh = boards.commit()
		gate.add_child(mesh)
		rows.append(mesh)
	if not b.is_preview:
		b.w.fort.add_gate_at(gate_name, b.xf * at, out, gate, rows)


func _walkway(b: MapBuilder, l: LowPoly, foot: Vector3, top: Vector3, wide: float, colour: Color) -> void:
	var along := (top - foot).normalized()
	var across := Vector3.UP.cross(along).normalized()
	var normal := along.cross(across)
	var xf := Transform3D(Basis(across, normal, along), foot.lerp(top, 0.5) - normal * 0.13)
	var size := Vector3(wide, 0.26, foot.distance_to(top) + 0.08)
	var saved := l.base
	l.base = saved * xf
	l.box(Vector3.ZERO, size, colour)
	for i in ceili(size.z / 0.65):
		var z := -size.z * 0.5 + i * 0.65
		l.box(Vector3(0, 0.138, z), Vector3(wide, 0.018, 0.065), colour.lightened(0.22))
	l.base = saved
	b.w.add_collider_xf(b.xf * xf, size)


## A hollow woven horn eight metres high, with a bronze lip and a spill of oversized harvest.
func _cornucopia(b: MapBuilder) -> void:
	var l := b.mesh()
	var light := b.mesh()
	l.prism(Vector3.ZERO, Vector3.UP * 0.7, 3.05, 2.8, 12, CLAY)
	l.prism(Vector3.UP * 0.7, Vector3.UP * 0.9, 2.83, 2.83, 12, CREAM)
	l.prism(Vector3.UP * 0.9, Vector3.UP * 0.98, 2.7, 2.7, 12, TEAL)
	b.solid(Vector3.UP * 0.5, Vector3(2.75, 1.0, 2.75))
	var rings: Array[PackedVector3Array] = []
	var centres := PackedVector3Array()
	const TEETH := 24
	const SECTIONS := 34
	for i in SECTIONS + 1:
		var t := float(i) / SECTIONS
		var p := Vector3(0, 3.38 + t * t * 7.5 - t * 2.7, 1.1 - sin(t * PI * 0.75) * 6.4)
		var tangent := Vector3(0, 15.0 * t - 2.7, -6.4 * PI * 0.75 * cos(t * PI * 0.75)).normalized()
		var top := Vector3.RIGHT.cross(tangent)
		var r := 2.65 * pow(1.0 - t, 1.45) + 0.12
		var ring := PackedVector3Array()
		for q in TEETH:
			var a := TAU * q / TEETH
			ring.append(p + (Vector3.RIGHT * cos(a) + top * sin(a)) * r)
		rings.append(ring)
		centres.append(p)
	for i in SECTIONS:
		for q in TEETH:
			var j := (q + 1) % TEETH
			var a := rings[i][q]
			var c := rings[i][j]
			var d := rings[i + 1][q]
			var e := rings[i + 1][j]
			var middle := (a + c + d + e) * 0.25
			var inner := centres[i].lerp(centres[i + 1], 0.5)
			var wicker := (GOLD if i % 4 == 2 else WOOD.lerp(GOLD, 0.54)).lightened(0.1 * ((i + q) % 2))
			l._tri(a, c, e, inner, wicker)
			l._tri(a, e, d, inner, wicker)
			l._tri(a, e, c, middle + (middle - inner), wicker.darkened(0.32))
			l._tri(a, d, e, middle + (middle - inner), wicker.darkened(0.32))
			if i in [0, 2, 8, 16, 25, 33]:
				l.prism(a, c, 0.09, 0.09, 5, GOLD if i in [0, 2] else CLAY)
			if q % 3 == 0:
				l.prism(a, d, 0.05, 0.05, 4, CREAM)
	var rng := b.seeded()
	for i in 37:
		var z := rng.randf_range(0.45, 5.1)
		var x := rng.randf_range(-2.2, 2.2) * lerpf(0.65, 1.0, z / 5.1)
		var size := rng.randf_range(0.22, 0.56)
		var mound := maxf(0.0, 2.9 - z * 0.73 - absf(x) * 0.28)
		_fruit(l, Vector3(x, size + mound * rng.randf_range(0.60, 1.05), z), size, i)
	for i in 9:
		var at := Vector3(-1.6 + i * 0.4, 2.3 + sin(i) * 0.20, 1.30)
		_wheat(l, at, 1.3, 3)
	for i in 22:
		var a := TAU * i / 22.0
		var p := Vector3(cos(a), 0.95, sin(a)) * Vector3(2.60, 1, 2.60)
		light.ovoid(p, Vector3(0.11, 0.06, 0.11), GOLD, CLAY, 2, 5)
	var horn := b.add(l)
	var shine := b.add(light)
	shine.material_override = MesenllaBuilder.glow_material()
	shine.reparent(horn)
	b.w.add_glow(b.xf * Vector3(0, 3.9, 1.6), GOLD, 8.7)
	b.w.add_glow(b.xf * Vector3(0, 5.0, -2.5), Color("fa9352"), 6.6)
	if not b.is_preview:
		b.w.fort.set_heart(b.xf.origin, horn, "Cornucopia")


static func _fruit(l: LowPoly, at: Vector3, size: float, kind_id: int) -> void:
	var col: Color = FRUIT[kind_id % FRUIT.size()]
	if kind_id % 5 == 2:
		for i in 5:
			var a := TAU * i / 5.0
			l.ovoid(at + Vector3(cos(a), sin(a), cos(a * 2.0)) * size * 0.46, Vector3.ONE * size * 0.56, col, col.darkened(0.48), 3, 6)
	else:
		var aspect := Vector3(1, 0.72 if kind_id % 3 == 0 else 1.03, 0.94)
		l.ovoid(at, aspect * size, col, col.darkened(0.38), 4, 8)
	l.prism(at + Vector3.UP * size * 0.68, at + Vector3(size * 0.4, size * 1.23, 0), size * 0.07, size * 0.025, 4, MOSS.darkened(0.24))
	l.ovoid(at + Vector3(size * 0.36, size, 0.02), Vector3(0.46, 0.14, 0.28) * size, MOSS.lightened(0.12), TEAL, 2, 5)


static func _wheat(l: LowPoly, at: Vector3, tall: float, stalks: int) -> void:
	for i in stalks:
		var a := TAU * i / stalks
		var head := at + Vector3(cos(a) * tall * 0.31, tall * (0.84 + 0.09 * (i % 3)), sin(a) * tall * 0.31)
		l.prism(at, head, tall * 0.027, tall * 0.017, 4, MOSS)
		for k in 3:
			var side := -1.0 if k % 2 else 1.0
			var seed := head + Vector3(side * 0.065, k * 0.09, 0) * tall
			l.ovoid(seed, Vector3(0.062, 0.115, 0.048) * tall, GOLD, CLAY, 3, 5, Basis(Vector3.BACK, -side * 0.44))


func _orchard(b: MapBuilder) -> void:
	FontaFlora.tree(b, "pomegranate", b.seeded().randf_range(3.3, 4.8))
	var l := b.cell()
	for i in 11:
		var a := i * 2.39
		var at := b.on_ground(Vector3(cos(a) * (1.35 + i * 0.15), 0, sin(a) * (1.35 + i * 0.15)))
		_fruit(l, b.xf.affine_inverse() * at + Vector3.UP * 0.19, 0.21, i)
	FontaFlora.wildflowers(b, 6.8)


func _grain(b: MapBuilder) -> void:
	var l := b.cell()
	var rng := b.seeded()
	for i in (84 if b.quality > 0 else 40):
		var x := rng.randf_range(-6.1, 6.1)
		var row := i % 7 - 3
		var z := row * 0.77 + rng.randf_range(-0.2, 0.2)
		var at := b.xf.affine_inverse() * b.on_ground(Vector3(x, 0, z))
		_wheat(l, at, rng.randf_range(0.63, 1.2), 2)


func _stall(b: MapBuilder, l: LowPoly, p: Vector3, colours: Array) -> void:
	for dx in [-2.4, 2.4]:
		for dz in [-1.65, 1.65]:
			l.prism(p + Vector3(dx, 0, dz), p + Vector3(dx, 3.35 - dz * 0.18, dz), 0.13, 0.105, 5, WOOD)
	for i in 10:
		var x := (i - 4.5) * 0.50
		l.box(p + Vector3(x, 3.24, 0), Vector3(0.515, 0.10, 3.65), colours[i % colours.size()], Vector3(10, 0, 0))
		l.box(p + Vector3(x, 2.80 - 0.06 * (i % 2), 1.79), Vector3(0.51, 0.36, 0.08), colours[i % colours.size()])
	l.box(p + Vector3(0, 0.86, 0.42), Vector3(4.35, 0.18, 1.6), WOOD)
	b.solid(p + Vector3(0, 0.49, 0.42), Vector3(4.1, 0.98, 1.45))
	for i in 14:
		_fruit(l, p + Vector3((i % 7 - 3) * 0.56, 1.18, float(floori(i / 7.0)) * 0.56), 0.21 + (i % 3) * 0.04, i)


func _market(b: MapBuilder) -> void:
	var l := b.mesh()
	_stall(b, l, Vector3.ZERO, [cloth, CREAM, cloth])
	for i in 4:
		var at := Vector3(-2.8 + i * 1.9, 0.02, 2.4)
		l.box(at, Vector3(1.2, 0.05, 0.9), cloth.darkened(0.25))
		l.box(at + Vector3.UP * 0.04, Vector3(0.8, 0.035, 0.54), GOLD.darkened(0.25))
	b.add(l)
	_lamp(b, Vector3(3, 0, 1.6), GOLD)


func _kilns(b: MapBuilder) -> void:
	var l := b.mesh()
	for i in 3:
		var x := (i - 1) * 4.4
		var at := Vector3(x, 0, 0)
		l.prism(at, at + Vector3.UP * 1.3, 1.65, 1.65, 12, STONE)
		l.ovoid(at + Vector3.UP * 1.25, Vector3(1.63, 1.49, 1.52), CLAY, WOOD, 5, 12)
		l.prism(at + Vector3(0.7, 1.6, -0.6), at + Vector3(0.7, 3.3, -0.6), 0.42, 0.34, 8, CREAM)
		l.box(at + Vector3(0, 1.06, 1.44), Vector3(1.0, 0.67, 0.12), WOOD.darkened(0.6))
		var heat := b.mesh()
		heat.box(at + Vector3(0, 0.91, 1.52), Vector3(0.8, 0.21, 0.06), GOLD)
		b.shine(heat)
		b.w.add_glow(b.xf * (at + Vector3(0, 1.05, 1.75)), Color("ff9a4c"), 4.5)
		b.solid(at + Vector3.UP * 0.9, Vector3(2.45, 1.8, 2.45))
	b.add(l)


func _vineyard(b: MapBuilder) -> void:
	var l := b.mesh()
	for row in 3:
		var z := row * 3.7
		for knot in 7:
			var at := b.xf.affine_inverse() * b.on_ground(Vector3((knot - 3) * 2.8, 0, z))
			l.prism(at, at + Vector3.UP * 1.8, 0.08, 0.065, 5, WOOD)
			if knot < 6:
				var next := b.xf.affine_inverse() * b.on_ground(Vector3((knot - 2) * 2.8, 0, z))
				l.prism(at + Vector3.UP * 1.58, next + Vector3.UP * 1.58, 0.04, 0.04, 4, WOOD)
				for i in 3:
					var bunch := at.lerp(next, (i + 0.5) / 3.0) + Vector3.UP * 1.32
					l.ovoid(bunch + Vector3.UP * 0.29, Vector3(0.55, 0.32, 0.36), MOSS, TEAL.darkened(0.27), 3, 6)
					_fruit(l, bunch, 0.23, 2)
	b.add(l)


func _harbour(b: MapBuilder) -> void:
	var l := b.mesh()
	var start := Vector3(0, b.terrain.height(b.xf.origin.x, b.xf.origin.z) - b.xf.origin.y, 0)
	_walkway(b, l, start, Vector3(0, 0, 5), 4.6, WOOD)
	_walkway(b, l, Vector3(0, 0, 5), Vector3(0, 0, 27), 4.6, WOOD)
	_walkway(b, l, Vector3(-11, 0, 26), Vector3(11, 0, 26), 2.5, WOOD)
	for i in 5:
		for x in [-2.2, 2.2]:
			var at := Vector3(x, 0, 5.5 + i * 4.8)
			l.prism(at - Vector3.UP * 5.0, at + Vector3.UP * 1.05, 0.24, 0.24, 7, WOOD)
			l.prism(at + Vector3.UP * 0.86, at + Vector3.UP * 0.98, 0.28, 0.28, 7, CREAM)
	for x in [-8.5, 8.5]:
		var bollard := Vector3(x, 0, 26.6)
		l.prism(bollard - Vector3.UP * 4.9, bollard + Vector3.UP * 1.2, 0.34, 0.3, 8, WOOD)
		l.prism(bollard + Vector3.UP * 0.62, Vector3(x * 0.83, 0.95, 29.1), 0.055, 0.055, 5, CREAM)
	# The landing extends to a real boarding plank amidships.
	_walkway(b, l, Vector3(0, 0, 26.8), Vector3(0, 0.66, 31.4), 1.95, WOOD)
	b.add(l)
	for z in [6, 15, 24]:
		_lamp(b, Vector3(-2, 0, z), GOLD)


func _shrine(b: MapBuilder) -> void:
	var l := b.mesh()
	l.prism(Vector3.ZERO, Vector3.UP * 0.5, 4.9, 4.55, 12, STONE)
	l.prism(Vector3.UP * 0.5, Vector3.UP * 0.75, 4.56, 4.48, 12, CREAM)
	for i in 7:
		var a := (0.24 + i * 0.087) * TAU
		var at := Vector3(cos(a) * 4.05, 0.75, -sin(a) * 4.05)
		l.prism(at - Vector3.UP * 0.08, at + Vector3.UP * 0.2, 0.55, 0.55, 8, CLAY)
		l.prism(at, at + Vector3.UP * 4.1, 0.36, 0.31, 8, CREAM)
		l.prism(at + Vector3.UP * 4.1, at + Vector3.UP * 4.4, 0.56, 0.59, 8, GOLD)
		if i % 2 == 0:
			_lamp(b, at + Vector3.UP * 4.4, GOLD, false)
		b.solid(at + Vector3.UP * 2.0, Vector3(0.82, 4.0, 0.82))
	for i in 4:
		var x := (i - 1.5) * 0.82
		_wheat(l, Vector3(x, 0.77, -1.85), 1.6, 4)
		_fruit(l, Vector3(x, 1.18, -0.82), 0.37, i)
	b.collider(Vector3.UP * 0.34, Vector3(6, 0.70, 6))
	b.add(l)


func _lamp(b: MapBuilder, at: Vector3, colour: Color, tall := true) -> void:
	var l := b.cell()
	var base := at + Vector3.UP * (2.65 if tall else 0.24)
	if tall:
		l.prism(at, base, 0.095, 0.068, 6, WOOD)
	l.prism(base, base + Vector3.UP * 0.15, 0.15, 0.35, 8, CLAY)
	l.prism(base + Vector3.UP * 0.15, base + Vector3.UP * 0.38, 0.35, 0.36, 8, WOOD)
	var light := b.mesh()
	light.ovoid(base + Vector3.UP * 0.4, Vector3(0.29, 0.32, 0.29), colour, colour.darkened(0.47), 3, 7)
	b.shine(light)
	b.w.add_glow(b.xf * (base + Vector3.UP * 0.42), colour, 5.2)
