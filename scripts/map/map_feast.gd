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
const OUTLINE := [Vector3(-39, 0, -27), Vector3(39, 0, -27), Vector3(0, 0, 41)]
const GATE_NAMES := ["Orchard", "Vine", "Hearth"]
const POSTERNS := [-10.5, 10.5, -10.5]
# Bottom, top, exposed edge and inside edge of each stone course, in face space.
const COURSES := [Vector4(-1.4, 1.8, 1.10, -6.50), Vector4(1.8, 3.4, 0.10, -5.95),
	Vector4(3.4, 5.0, -0.90, -5.40), Vector4(5.0, 6.5, -1.90, -4.85),
	Vector4(6.5, 7.95, -2.75, -4.70), Vector4(7.95, 9.05, -3.30, -4.48)]

@export_enum("island", "court", "cornucopia", "orchard", "market", "kilns", "vineyard", "harbour", "ship", "shrine", "beacon", "grain", "bloom", "basin") var kind := "court"
@export var cloth := TEAL


func land(t: Terrain, _at: Transform3D) -> void:
	if kind == "island":
		t.set_isle(PackedFloat32Array([90, 92, 82, 70, 73, 77, 89, 92, 93, 88, 85, 90, 99, 97, 91, 87]), 0.073)
		t.level(Vector2(0, 2), Vector2(39, 35), 0.0, COURT, 12.0)


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
		"bloom": _bloom(b)
		"basin": _basin(b)


func _court(b: MapBuilder) -> void:
	if not b.is_preview:
		b.w.start_fort()
		var outline := PackedVector2Array()
		for corner: Vector3 in OUTLINE:
			outline.append(Vector2(corner.x, corner.z))
		b.w.fort.set_region(outline, COURT)
	var l := b.mesh()
	var light := b.mesh()
	_pave_court(b, l)
	for side in 3:
		var a: Vector3 = OUTLINE[side]
		var end: Vector3 = OUTLINE[(side + 1) % 3]
		var span := a.distance_to(end) * 0.5
		var along := (end - a).normalized()
		var out := along.cross(Vector3.UP) * -1.0
		var anchor := a.lerp(end, 0.5)
		var face := Transform3D(Basis(along, Vector3.UP, -out), anchor)
		# Face-space +Z points into the court; each higher course retreats from the base edge.
		var door: float = POSTERNS[side]
		var cuts: Array[Vector3] = [Vector3(door - 1.04, door + 1.04, 2.65), Vector3(-Fort.GATE_W * 0.5, Fort.GATE_W * 0.5, Fort.GATE_H)]
		cuts.sort_custom(func(left: Vector3, right: Vector3) -> bool: return left.x < right.x)
		var cursor := -span + 3.0
		for gap in cuts:
			_courses(b, l, face, cursor, gap.x, -1.4)
			_courses(b, l, face, gap.x, gap.y, gap.z)
			cursor = gap.y
		_courses(b, l, face, cursor, span - 3.0, -1.4)
		var postern := face * Vector3(door, 0, 0)
		if not b.is_preview:
			b.w.fort.add_door(b.xf * postern, out)
			b.w.add_enemy_block_xf(b.xf * face.translated_local(Vector3(door, 1.325, 0.22)), Vector3(2.08, 2.65, 2.2))
		_gate(b, l, GATE_NAMES[side], anchor, out, along)
		for offset: float in [-span * 0.52, span * 0.52]:
			_wall_banner(l, face * Vector3(offset, 0, 6.57), along, out, PLUM if offset < 0 else TEAL)
			_braziers_on_face(l, light, face, offset)
		# A stair ramp leads onto an inside firing gallery above each doorway.
		var ledge := face * Vector3(0, 4.75, 6.6)
		var deck_xf := Transform3D(face.basis, ledge - Vector3.UP * 0.28)
		var walk_saved := l.base
		l.base = b.xf * deck_xf
		l.box(Vector3.ZERO, Vector3(24.0, 0.56, 3.1), STONE.darkened(0.17))
		l.box(Vector3(0, 0.23, 1.52), Vector3(24.1, 0.16, 0.22), TEAL)
		l.base = walk_saved
		b.w.add_collider_xf(b.xf * deck_xf, Vector3(24.0, 0.56, 3.1))
		var stair_top := face * Vector3(-10 if door > 0 else 10, 4.75, 8.08)
		var stair_foot := stair_top - Vector3.UP * 4.75 - out * 11.0
		_walkway(b, l, stair_foot, stair_top, 2.55, CLAY)
	for vertex: Vector3 in OUTLINE:
		_pyramid_corner(b, l, light, vertex)
	b.add(l)
	b.shine(light)
	b._plant_clearings.append(Vector3(0, 0, 27))


func _courses(b: MapBuilder, l: LowPoly, face: Transform3D, start: float, end: float, opening: float) -> void:
	var saved := l.base
	l.base *= face
	var span := end - start
	var midpoint := (start + end) * 0.5
	for i in COURSES.size():
		var course: Vector4 = COURSES[i]
		var low := maxf(course.x, opening)
		if course.y <= low:
			continue
		var height := course.y - low
		var thickness := course.z - course.w
		var at := Vector3(midpoint, low + height * 0.5, -(course.z + course.w) * 0.5)
		var size := Vector3(span + 0.03, height, thickness)
		var shade := STONE.lerp(CREAM, 0.13 * i).darkened(0.05 * (i % 2))
		l.box(at, size, shade)
		l.box(Vector3(midpoint, course.y - 0.09, -course.z - 0.035), Vector3(span + 0.04, 0.16, 0.10), TEAL if i in [1, 4] else CREAM)
		if opening < 0.0 and i == 0:
			b.w.add_solid_xf(b.xf * face.translated_local(at), size)
		else:
			b.w.add_collider_xf(b.xf * face.translated_local(at), size)
		var stagger := 0.46 * (i % 2)
		for j in floori((span - stagger) / 1.65):
			var x := start + stagger + (j + 0.5) * 1.65
			l.box(Vector3(x, course.y - height * 0.42, -course.z - 0.019), Vector3(1.61, height * 0.69, 0.07), shade.darkened(0.045 * ((j * 7 + i) % 5)))
	l.base = saved


func _braziers_on_face(l: LowPoly, light: LowPoly, face: Transform3D, offset: float) -> void:
	var at := face * Vector3(offset, 9.05, 3.92)
	l.prism(at, at + Vector3.UP * 1.1, 0.44, 0.27, 8, CLAY)
	l.prism(at + Vector3.UP * 1.1, at + Vector3.UP * 1.38, 0.33, 0.58, 8, GOLD)
	light.ovoid(at + Vector3.UP * 1.56, Vector3(0.34, 0.50, 0.34), GOLD, CLAY, 3, 7)


func _pyramid_corner(b: MapBuilder, l: LowPoly, light: LowPoly, vertex: Vector3) -> void:
	# Solid corner piers stitch the diagonal faces together. Terraces taper above each corner.
	var centre := vertex.move_toward(Vector3.ZERO, 1.65)
	for i in 7:
		var h := 1.68
		var radius := 6.5 - i * 0.77
		var at := centre.move_toward(Vector3.ZERO, i * 0.33) + Vector3.UP * (i * h - 0.55)
		l.prism(at, at + Vector3.UP * h, radius, radius - 0.19, 6, STONE.lerp(CREAM, i * 0.095))
		l.prism(at + Vector3.UP * (h - 0.17), at + Vector3.UP * h, radius, radius, 6, TEAL if i in [2, 5] else GOLD.darkened(0.18))
		if i == 0:
			b.solid(at + Vector3.UP * 1.5, Vector3(8.8, 3.0, 8.8))
		else:
			b.collider(at + Vector3.UP * h * 0.5, Vector3.ONE * (radius * 1.14) * Vector3(1.0, h / (radius * 1.14), 1.0))
	var flame := centre.move_toward(Vector3.ZERO, 2.05) + Vector3.UP * 11.8
	l.prism(flame - Vector3.UP * 0.65, flame + Vector3.UP * 0.12, 0.82, 1.45, 6, GOLD)
	light.ovoid(flame + Vector3.UP * 0.52, Vector3(0.71, 1.25, 0.71), GOLD, CLAY, 4, 9)
	b.w.add_glow(b.xf * (flame + Vector3.UP), GOLD, 10.0)


func _pave_court(b: MapBuilder, l: LowPoly) -> void:
	# A tiled ring and mosaic paths, with dirt recesses for supplies and unobstructed approaches.
	var courtyard := PackedVector2Array([Vector2(-32, -24), Vector2(32, -24), Vector2(0, 31)])
	for x in range(-23, 24):
		for z in range(-19, 20):
			var r := Vector2(x, z).length()
			var radial := r > 6.3 and r < 8.3
			var avenue := absi(x) <= 2 or absi(z) <= 2
			if not Geometry2D.is_point_in_polygon(Vector2(x, z), courtyard) or (not radial and not avenue and r > 6.3):
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
	gate.basis = Basis(along, Vector3.UP, -out)
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
	b.solid(Vector3.UP * 0.48, Vector3(5.0, 0.96, 5.0))
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
	if not b.is_preview:
		var sections := [0, 3, 7, 12, 18, 24, 29, SECTIONS]
		for k in sections.size() - 1:
			var hull := PackedVector3Array()
			for index: int in sections.slice(k, k + 2):
				for q in range(0, TEETH, 2):
					hull.append(rings[index][q])
			b.w.add_wedge(b.xf, hull)
		# Support the spill without making a square invisible obstacle around the horn.
		b.w.add_wedge(b.xf, PackedVector3Array([
			Vector3(-1.75, 0, 0.9), Vector3(1.75, 0, 0.9), Vector3(-1.7, 0, 4.85), Vector3(1.7, 0, 4.85),
			Vector3(-1.55, 2.35, 0.9), Vector3(1.55, 2.35, 0.9), Vector3(-1.1, 0.55, 4.85), Vector3(1.1, 0.55, 4.85)]))
		b.no_walk(Vector3(0, 0, 1.5), Vector3(3.8, 1.0, 6.4))
		b.no_walk(Vector3(0, 0, -2.35), Vector3(3.2, 1.0, 2.6))
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
		b.w.fort.set_heart(b.xf.origin, horn, "Cornucopia", 5.9)


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


## Beds of tall flowers are laid out in drifts, with a different palette at each village.
func _bloom(b: MapBuilder) -> void:
	var l := b.cell()
	var rng := b.seeded()
	var colours := [cloth, cloth.lightened(0.27), CREAM, Color("a84d78"), Color("f2a545")]
	var to_local := b.xf.affine_inverse()
	for i in (46 if b.quality > 0 else 26):
		var row := i % 4
		var x := rng.randf_range(-5.55, 5.55)
		var z := (row - 1.5) * 0.85 + 0.45 * sin(x * 0.56) + rng.randf_range(-0.28, 0.28)
		var base := to_local * b.on_ground(Vector3(x, 0, z))
		var tall := rng.randf_range(0.36, 1.23)
		var head := base + Vector3(rng.randf_range(-0.08, 0.08), tall, rng.randf_range(-0.09, 0.09))
		var dye: Color = colours[(row + rng.randi_range(0, 2)) % colours.size()]
		l.prism(base, head, 0.021, 0.011, 4, MOSS)
		for side: float in [-1.0, 1.0]:
			var leaf := base.lerp(head, 0.28 if side > 0.0 else 0.54)
			l.ovoid(leaf + Vector3(side * 0.13, 0.06, 0), Vector3(0.17, 0.045, 0.075), MOSS.lightened(0.13), TEAL, 2, 5, Basis(Vector3.BACK, side * 0.36))
		for j in 5:
			var a := TAU * j / 5.0 + x
			var petal := Vector3(cos(a), 0.03, sin(a))
			l.ovoid(head + petal * 0.106, Vector3(0.116, 0.049, 0.067), dye, dye.darkened(0.24), 2, 5, Basis(Vector3.UP, -a))
		l.ovoid(head + Vector3.UP * 0.04, Vector3(0.065, 0.055, 0.065), GOLD, CLAY, 2, 6)


func _basin(b: MapBuilder) -> void:
	var l := b.mesh()
	l.prism(Vector3.ZERO, Vector3.UP * 0.41, 2.42, 2.42, 12, STONE)
	l.prism(Vector3.UP * 0.41, Vector3.UP * 0.49, 2.18, 2.18, 12, TEAL.darkened(0.16))
	for i in 12:
		var a := TAU * i / 12.0
		var n := TAU * (i + 1) / 12.0
		var rim := Vector3(cos(a) * 2.27, 0.55, sin(a) * 2.27)
		l.prism(rim, Vector3(cos(n) * 2.27, 0.55, sin(n) * 2.27), 0.19, 0.19, 5, CREAM)
		if i % 3 == 0:
			l.ovoid(rim * Vector3(0.72, 1.04, 0.72), Vector3(0.22, 0.025, 0.14), MOSS, TEAL, 2, 5)
	l.prism(Vector3.UP * 0.48, Vector3.UP * 1.17, 0.48, 0.31, 8, CLAY)
	l.prism(Vector3.UP * 1.17, Vector3.UP * 1.32, 0.3, 0.68, 8, GOLD)
	b.add(l)
	b.solid(Vector3.UP * 0.27, Vector3(3.55, 0.55, 3.55))
	var water := b.mesh()
	for i in 5:
		var a := TAU * i / 5.0
		var p := Vector3(cos(a), 0.0, sin(a))
		water.prism(Vector3.UP * 1.31, p * 0.63 + Vector3.UP * 0.58, 0.033, 0.026, 4, Color("83dbce"))
	b.shine(water)
