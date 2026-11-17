class_name VaelBuilder
extends RefCounted
## How the landmarks of Port Vael look (MapVael): the drowned harbour of the old kingdom of Vael.
## Each draws at the builder's current spot (b.xf) the way MapBuilder's own pieces do, and adds the
## colliders, glows and lights it needs. Below the high-water line (MistTide.HIGH_Y) everything is
## stained dark and green and crusted with barnacles; above it, salt-bleached.

const QUAY_STONE := Color(0.46, 0.45, 0.43)
const QUAY_DARK := Color(0.33, 0.33, 0.33)
const SLIME := Color(0.2, 0.28, 0.17)
const WET_STONE := Color(0.27, 0.29, 0.28)
const WOOD_WET := Color(0.29, 0.21, 0.14)
const WOOD_DARK := Color(0.19, 0.14, 0.1)
const WOOD_BLEACHED := Color(0.56, 0.5, 0.42)
const HULL_PAINT := Color(0.18, 0.24, 0.3)
const HULL_RED := Color(0.45, 0.16, 0.12)
const SAIL := Color(0.62, 0.58, 0.48)
const ROPE := Color(0.55, 0.46, 0.31)
const NET := Color(0.3, 0.34, 0.3)
const IRON := Color(0.2, 0.21, 0.22)
const RUST := Color(0.48, 0.26, 0.15)
const BRONZE := Color(0.45, 0.4, 0.22)
const BRONZE_GREEN := Color(0.32, 0.5, 0.42)
const LAMP := Color(1.0, 0.8, 0.45)
const SEA_GLOW := Color(0.55, 1.0, 0.82)
const ROCK := Color(0.36, 0.36, 0.37)
const ROCK_DARK := Color(0.24, 0.25, 0.27)
const SAND := Color(0.58, 0.53, 0.42)


## The high-water mark in this piece's frame: below it, stone and wood are wet and weeded.
static func _tide_line(b: MapBuilder) -> float:
	return MistTide.HIGH_Y - b.xf.origin.y


## A block of stone: weeded and dark below the tide line, pale above.
static func _stone_col(y_mid: float, tide: float, base: Color, rng: RandomNumberGenerator) -> Color:
	var c := base.darkened(rng.randf_range(0.0, 0.12))
	if y_mid < tide - 0.4:
		return SLIME.lerp(WET_STONE, rng.randf_range(0.2, 0.6))
	if y_mid < tide + 0.2:
		return WET_STONE.lerp(c, 0.35)
	return c


## Flagstones over the land: big worn slabs of grey stone in rows along X, on a bed of mortar, with
## weeds in a few of the joints. The quay and the market square are paved with them.
static func paving(b: MapBuilder, length: float, deep: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	l.box(Vector3(0, -0.02, 0), Vector3(length, 0.1, deep), QUAY_DARK.darkened(0.3))
	var z := -deep * 0.5
	var row := 0
	while z < deep * 0.5 - 0.05:
		var d := minf(rng.randf_range(1.0, 1.5), deep * 0.5 - z)
		var x := -length * 0.5 - (rng.randf_range(0.0, 0.8) if row % 2 else 0.0)
		while x < length * 0.5:
			var w := rng.randf_range(1.0, 2.0)
			var x0 := maxf(x, -length * 0.5)
			var x1 := minf(x + w, length * 0.5)
			if x1 - x0 > 0.15:
				var at := Vector3((x0 + x1) * 0.5, 0.06, z + d * 0.5)
				var y := (b.xf.affine_inverse() * b.on_ground(Vector3(at.x, 0, at.z))).y
				l.box(Vector3(at.x, maxf(y, 0.0) + 0.06, at.z), Vector3(x1 - x0 - 0.06, 0.1, d - 0.06), QUAY_STONE.lerp(SAND, rng.randf_range(0.0, 0.2)).darkened(rng.randf_range(0.0, 0.14)))
			x += w
		z += d
		row += 1
	b.add(l)


## The face of a harbour wall along the piece's X axis, from its top (the piece's height) down to the
## seabed in front of it (+Z), in courses of dressed stone; a band of weed and barnacles below the
## high-water mark; iron mooring rings and stone bollards along the top, and a coping of long slabs.
## The walkable top is the land itself (a MapLevel under the quay).
static func quay_wall(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var tide := _tide_line(b)
	var front := 0.0
	# How deep the wall goes: down to the lowest ground in front of it.
	var bottom := 0.0
	for k in 9:
		var x := lerpf(-length * 0.5, length * 0.5, k / 8.0)
		bottom = minf(bottom, (b.xf.affine_inverse() * b.on_ground(Vector3(x, 0, 1.5))).y)
	bottom -= 0.6
	var course := 0.55
	var y := bottom
	var row := 0
	while y < -0.05:
		var x := -length * 0.5 - (0.6 if row % 2 else 0.0)
		while x < length * 0.5:
			var w := rng.randf_range(1.1, 1.8)
			var x0 := maxf(x, -length * 0.5)
			var x1 := minf(x + w, length * 0.5)
			if x1 - x0 > 0.2:
				var mid := y + course * 0.5
				l.box(Vector3((x0 + x1) * 0.5, mid, front + rng.randf_range(-0.04, 0.04)), Vector3(x1 - x0 - 0.05, course - 0.05, 0.6), _stone_col(mid, tide, QUAY_STONE, rng))
			x += w
		y += course
		row += 1
	# Coping slabs along the top, overhanging the face a little.
	var x := -length * 0.5
	while x < length * 0.5:
		var w := minf(rng.randf_range(1.6, 2.4), length * 0.5 - x)
		l.box(Vector3(x + w * 0.5, 0.06, front - 0.15), Vector3(w - 0.04, 0.22, 1.1), QUAY_DARK.lightened(rng.randf_range(0.0, 0.15)))
		x += w
	# Barnacles crusting the stone below the tide line.
	var crust := minf(tide, -0.2)
	for k in int(length * 1.2):
		var at := Vector3(rng.randf_range(-length * 0.5, length * 0.5), rng.randf_range(bottom + 0.3, crust), front + 0.32)
		VaelModels.barnacles(l, at, Vector3(0, 0, 1), 3, 0.05, rng)
	# Weed hanging from the tide line.
	for k in int(length * 0.8):
		VaelModels.kelp(l, Vector3(rng.randf_range(-length * 0.5, length * 0.5), crust + 0.1, front + 0.33), rng.randf_range(0.5, 1.2), 2, rng)
	# Bollards and rings.
	var every := 7.0
	var bx := -length * 0.5 + every * 0.5
	while bx < length * 0.5:
		l.prism(Vector3(bx, 0.15, front - 0.9), Vector3(bx, 0.65, front - 0.9), 0.24, 0.2, 8, IRON)
		l.prism(Vector3(bx, 0.65, front - 0.9), Vector3(bx, 0.78, front - 0.9), 0.3, 0.26, 8, IRON.lightened(0.08))
		b.solid(Vector3(bx, 0.45, front - 0.9), Vector3(0.5, 0.7, 0.5))
		for s in 6:
			var a0 := TAU * s / 6.0
			var a1 := TAU * (s + 1) / 6.0
			l.prism(Vector3(bx + 1.6 + cos(a0) * 0.2, -0.6 + sin(a0) * 0.2, front + 0.34), Vector3(bx + 1.6 + cos(a1) * 0.2, -0.6 + sin(a1) * 0.2, front + 0.34), 0.03, 0.03, 4, RUST)
		bx += every
	b.add(l)
	b.collider(Vector3(0, (bottom - 0.2) * 0.5, front - 0.1), Vector3(length, -bottom + 0.4, 0.8))
	MesenllaBuilder._feature(b, "quay", length)


## A breakwater (a mole) along the piece's Z axis: a causeway of big stone blocks with sloping sides
## of tumbled rock, its top paved and walled on the sea side. The top is the land (see MapVael.land).
static func mole(b: MapBuilder, length: float, wide: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var tide := _tide_line(b)
	var half := wide * 0.5
	# Paving, on a bed of rubble and mortar.
	l.box(Vector3(0, -0.06, 0), Vector3(wide, 0.14, length), QUAY_DARK.darkened(0.25))
	var z := -length * 0.5
	while z < length * 0.5:
		var d := minf(1.4, length * 0.5 - z)
		for k in int(wide / 1.4):
			var x := -half + 0.7 + k * 1.4
			l.box(Vector3(x, 0.03, z + d * 0.5), Vector3(1.34, 0.08, d - 0.06), QUAY_STONE.darkened(rng.randf_range(0.0, 0.15)))
		z += d
	# Faces, down to the seabed, and tumbled rock along their feet.
	for side: float in [-1.0, 1.0]:
		z = -length * 0.5
		while z < length * 0.5:
			var d := minf(rng.randf_range(1.6, 2.6), length * 0.5 - z)
			var foot := (b.xf.affine_inverse() * b.on_ground(Vector3(side * (half + 2.0), 0, z + d * 0.5))).y
			var y := foot - 0.4
			while y < -0.05:
				var h := minf(0.7, -y)
				l.box(Vector3(side * (half + 0.1), y + h * 0.5, z + d * 0.5), Vector3(0.7, h - 0.05, d - 0.05), _stone_col(y + h * 0.5, tide, QUAY_STONE, rng))
				y += 0.7
			for k in 2:
				var at := Vector3(side * (half + rng.randf_range(0.8, 2.2)), foot + rng.randf_range(0.0, 0.4), z + rng.randf_range(0.0, d))
				var s := rng.randf_range(0.5, 1.0)
				l.box(at, Vector3(s, s * 0.7, s * 0.9), _stone_col(at.y, tide, ROCK, rng), Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 90), rng.randf_range(-20, 20)))
				if at.y < tide:
					VaelModels.barnacles(l, at + Vector3(0, s * 0.35, 0), Vector3(0, 1, 0), 3, 0.05, rng)
			z += d
	# A parapet on the seaward (+X) side.
	z = -length * 0.5
	while z < length * 0.5:
		var d := minf(3.0, length * 0.5 - z)
		l.box(Vector3(half - 0.3, 0.55, z + d * 0.5), Vector3(0.6, 1.1, d - 0.08), QUAY_DARK.lightened(rng.randf_range(0.0, 0.1)))
		z += d
	b.collider(Vector3(half - 0.3, 0.55, 0), Vector3(0.6, 1.1, length))
	b.add(l)
	MesenllaBuilder._feature(b, "mole", length)


## A lighthouse: a tall round tower of pale stone on a stepped plinth, a door at its foot, small windows
## up its side, a gallery with a railing round the lantern room, and the lantern itself: dark glass
## cracked by the sea's weather, and inside it the great lamp, unlit. (In Last Light it is the goal.)
## high is its height to the gallery.
static func lighthouse(b: MapBuilder, high: float, lit: bool) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var white := Color(0.78, 0.76, 0.7)
	var band := Color(0.55, 0.16, 0.13)
	l.prism(Vector3(0, 0, 0), Vector3(0, 1.0, 0), 4.2, 3.9, 10, QUAY_DARK)
	l.prism(Vector3(0, 1.0, 0), Vector3(0, 1.5, 0), 3.7, 3.5, 10, QUAY_STONE)
	# The tower, narrowing, in rings of stone with red bands.
	var rings := 8
	for k in rings:
		var y0 := 1.5 + (high - 1.5) * k / rings
		var y1 := 1.5 + (high - 1.5) * (k + 1) / rings
		var r0 := lerpf(3.0, 2.0, float(k) / rings)
		var r1 := lerpf(3.0, 2.0, float(k + 1) / rings)
		l.prism(Vector3(0, y0, 0), Vector3(0, y1, 0), r0, r1, 12, band if k % 3 == 2 else white.darkened(rng.randf_range(0.0, 0.08)))
	# Door and windows.
	l.box(Vector3(0, 2.6, 2.98), Vector3(1.3, 2.2, 0.2), WOOD_DARK)
	l.box(Vector3(0, 3.8, 2.96), Vector3(1.6, 0.25, 0.28), QUAY_DARK)
	for k in 4:
		var y := 5.0 + k * (high - 6.0) / 4.0
		var a := k * 1.7
		var r := lerpf(3.0, 2.0, (y - 1.5) / (high - 1.5)) + 0.02
		l.box(Vector3(sin(a) * r, y, cos(a) * r), Vector3(0.5, 0.9, 0.12), Color(0.05, 0.06, 0.08), Vector3(0, rad_to_deg(a), 0))
	# Gallery and railing.
	l.prism(Vector3(0, high, 0), Vector3(0, high + 0.35, 0), 2.9, 2.9, 12, QUAY_DARK)
	for k in 16:
		var a := TAU * k / 16.0
		l.prism(Vector3(cos(a) * 2.75, high + 0.35, sin(a) * 2.75), Vector3(cos(a) * 2.75, high + 1.4, sin(a) * 2.75), 0.04, 0.04, 4, IRON)
	l.prism(Vector3(0, high + 1.35, 0), Vector3(0, high + 1.45, 0), 2.8, 2.8, 16, IRON)
	# The lantern room: a frame of iron round panes of glass, a domed cap and a weathervane.
	l.prism(Vector3(0, high + 0.35, 0), Vector3(0, high + 0.9, 0), 1.6, 1.6, 8, white)
	for k in 8:
		var a := TAU * k / 8.0
		l.prism(Vector3(cos(a) * 1.55, high + 0.9, sin(a) * 1.55), Vector3(cos(a) * 1.5, high + 3.2, sin(a) * 1.5), 0.06, 0.06, 4, IRON)
	l.prism(Vector3(0, high + 3.2, 0), Vector3(0, high + 3.5, 0), 1.75, 1.6, 8, BRONZE_GREEN)
	l.prism(Vector3(0, high + 3.5, 0), Vector3(0, high + 4.6, 0), 1.6, 0.15, 8, BRONZE_GREEN.darkened(0.1))
	l.prism(Vector3(0, high + 4.6, 0), Vector3(0, high + 5.4, 0), 0.05, 0.05, 4, IRON)
	l.box(Vector3(0.25, high + 5.2, 0), Vector3(0.6, 0.18, 0.02), IRON)
	var glass := b.mesh()
	glass.prism(Vector3(0, high + 0.9, 0), Vector3(0, high + 3.2, 0), 1.5, 1.45, 8, Color(0.12, 0.16, 0.18) if not lit else Color(1.0, 0.92, 0.7))
	b.add(l)
	if lit:
		MesenllaBuilder._shine(b, glass, true)
		b.w.add_glow(b.xf * Vector3(0, high + 2.0, 0), LAMP, 6.0, 260.0, true)
		MesenllaBuilder._light(b, Vector3(0, high + 2.0, 0), LAMP, 3.0, 26.0)
	else:
		b.add(glass)
		# The great lamp inside, cold.
		var lamp := b.mesh()
		lamp.prism(Vector3(0, high + 1.0, 0), Vector3(0, high + 2.6, 0), 0.6, 0.6, 8, BRONZE)
		lamp.prism(Vector3(0, high + 1.2, 0), Vector3(0, high + 2.4, 0), 0.7, 0.7, 8, Color(0.5, 0.6, 0.62))
		b.add(lamp)
	b.solid(Vector3(0, high * 0.5, 0), Vector3(5.2, high, 5.2))
	b.w.perches.append(b.xf * Vector3(0, high + 0.6, 2.6))
	MesenllaBuilder._feature(b, "lighthouse", 6.0)


## A ship wrecked on the seabed along the piece's X axis, bow at +X: sunk in the sand to her
## waterline and listing towards +Z, her hull of tarred planks on ribs with a red band at the wale,
## the stem rising at the bow and a stern cabin aft. Her deck is planked, broken through amidships
## where the hold gapes, and her side is stove in towards you (+Z) so you can climb in. The mast has
## snapped: its stump stands, and the rest lies across the flats with its yard and a rag of sail, the
## rigging trailing. Barnacles crust her and weed hangs from her, all below the high-water mark.
static func wreck(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var half := length * 0.5
	var beam := length * 0.3
	var depth := length * 0.2
	# She lies half sunk: her keel and bilge under the sand, her deck a little above it.
	var at_rest := b.xf
	b.xf = b.xf.translated_local(Vector3(0, depth * 0.35, 0))
	var tide := _tide_line(b)
	var heel := 0.2
	var lean := Basis(Vector3(1, 0, 0), heel)
	var hole := Vector2(-length * 0.12, length * 0.12) # where her side is stove in and her deck broken, along X
	var stations := int(length / 0.9)
	# The section of the hull at s (0 stern to 1 bow): half its width and the height of its gunwale.
	var section := func(s: float) -> Vector2:
		var fat := sin(clampf(s * 0.92 + 0.04, 0.0, 1.0) * PI) ** 0.55
		if s > 0.8:
			fat *= lerpf(1.0, 0.25, (s - 0.8) / 0.2) # the bow draws to a point
		var sheer := depth * 0.18 + depth * 0.35 * pow(absf(s - 0.45) * 2.0, 2.0)
		return Vector2(beam * 0.5 * fat, sheer)
	var rib := func(s: float, side: float) -> Array[Vector3]:
		var x := lerpf(-half, half, s)
		var sec: Vector2 = section.call(s)
		var keel := -depth
		return [Vector3(x, keel, 0), Vector3(x, keel * 0.6, side * sec.x * 0.75), Vector3(x, keel * 0.15, side * sec.x), Vector3(x, sec.y, side * sec.x * 0.94)]
	for k in stations:
		var s0 := float(k) / stations
		var s1 := float(k + 1) / stations
		var x0 := lerpf(-half, half, s0)
		var stove := x0 > hole.x and x0 < hole.y
		for side: float in [-1.0, 1.0]:
			var r0: Array[Vector3] = rib.call(s0, side)
			var r1: Array[Vector3] = rib.call(s1, side)
			for p in 3:
				if k % 2 == 0:
					l.prism(lean * r0[p], lean * r0[p + 1], 0.07, 0.07, 4, WOOD_DARK)
				# Planks, except where she is stove in on the side that faces you (and up near the wale).
				if stove and side > 0 and p >= 1:
					continue
				var col := WOOD_WET.darkened(rng.randf_range(0.0, 0.2))
				if p == 1:
					col = HULL_PAINT.darkened(rng.randf_range(0.0, 0.2))
				l.gable(lean * r0[p], lean * r1[p], lean * r1[p + 1], col)
				l.gable(lean * r0[p], lean * r1[p + 1], lean * r0[p + 1], col)
			# The wale: a red-painted strake along her side under the gunwale.
			if not (stove and side > 0):
				var drop := Vector3(0, -0.35, 0)
				l.prism(lean * (r0[3] + drop), lean * (r1[3] + drop), 0.09, 0.09, 4, HULL_RED.darkened(rng.randf_range(0.0, 0.2)))
		# The deck, planked, broken through over the hold.
		var sec: Vector2 = section.call((s0 + s1) * 0.5)
		var planks := 6
		for j in planks:
			var z := lerpf(-sec.x * 0.9, sec.x * 0.9, (j + 0.5) / planks)
			if stove and (j >= 2 or rng.randf() < 0.5):
				continue
			l.turned_box(lean * Vector3((x0 + lerpf(-half, half, s1)) * 0.5, depth * 0.12, z), Vector3(length / stations + 0.02, 0.08, sec.x * 1.8 / planks - 0.05), WOOD_BLEACHED.darkened(rng.randf_range(0.15, 0.35)), lean)
	# The stem at the bow and the transom and cabin at the stern.
	var bow := lean * Vector3(half, (section.call(1.0) as Vector2).y, 0)
	l.prism(lean * Vector3(half * 0.92, -depth, 0), bow + Vector3(0.6, 0.9, 0), 0.14, 0.1, 5, WOOD_DARK)
	var stern_sec: Vector2 = section.call(0.0)
	l.turned_box(lean * Vector3(-half + 0.05, stern_sec.y * 0.5 - depth * 0.3, 0), Vector3(0.16, stern_sec.y + depth * 0.5, beam * 0.7), WOOD_WET, lean)
	l.turned_box(lean * Vector3(-half * 0.7, depth * 0.12 + 0.85, 0), Vector3(length * 0.18, 1.6, beam * 0.62), WOOD_WET.lightened(0.05), lean)
	l.turned_box(lean * Vector3(-half * 0.7, depth * 0.12 + 1.72, 0), Vector3(length * 0.2, 0.12, beam * 0.68), WOOD_DARK, lean)
	l.turned_box(lean * Vector3(-half * 0.7 + length * 0.09, depth * 0.12 + 0.75, 0), Vector3(0.06, 1.2, 0.8), Color(0.05, 0.05, 0.06), lean)
	# The stump of the mast, and the mast fallen across the flats with its yard and sail.
	var deck_y := depth * 0.12
	var foot := lean * Vector3(length * 0.05, deck_y, 0)
	l.prism(foot, lean * Vector3(length * 0.05, deck_y + 2.4, 0), 0.24, 0.2, 7, WOOD_WET)
	var fall_dir := Vector3(0.35, 0, 1.0).normalized()
	var mast_from := b.xf.affine_inverse() * b.on_ground(Vector3(length * 0.05, 0, beam * 0.75))
	mast_from.y += 0.25
	var mast_to := b.xf.affine_inverse() * b.on_ground(Vector3(length * 0.05, 0, beam * 0.75) + fall_dir * length * 0.6)
	mast_to.y += 0.2
	l.prism(mast_from, mast_to, 0.22, 0.14, 7, WOOD_WET.darkened(0.1))
	var yard_mid := mast_from.lerp(mast_to, 0.6)
	var yard_dir := fall_dir.cross(Vector3.UP).normalized()
	l.prism(yard_mid - yard_dir * length * 0.2, yard_mid + yard_dir * length * 0.2, 0.1, 0.1, 6, WOOD_DARK)
	var drape := yard_mid + fall_dir * 1.8 + Vector3(0, -0.1, 0)
	l.gable(yard_mid - yard_dir * length * 0.18, yard_mid + yard_dir * length * 0.14, drape + yard_dir * 0.6, SAIL.darkened(0.2))
	# Rigging trailing from the stump to the ground.
	for k in 4:
		var from := lean * Vector3(length * 0.05, deck_y + 2.2, 0)
		var to := b.xf.affine_inverse() * b.on_ground(Vector3(length * 0.05 + rng.randf_range(-4, 4), 0, beam * 0.6 + rng.randf_range(0.5, 3.0)))
		var mid := from.lerp(to, 0.5) + Vector3(0, -0.4, 0)
		l.prism(from, mid, 0.025, 0.025, 3, ROPE)
		l.prism(mid, to, 0.025, 0.025, 3, ROPE.darkened(0.2))
	# Barnacles on her hull below the high-water mark, weed hanging along it.
	for k in int(length * 3.0):
		var s := rng.randf_range(0.08, 0.92)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var r: Array[Vector3] = rib.call(s, side)
		var at := lean * r[1].lerp(r[2], rng.randf())
		if at.y < tide:
			VaelModels.barnacles(l, at, lean * Vector3(0, -0.3, side), 3, 0.05, rng)
	for k in int(length * 1.2):
		var s := rng.randf_range(0.1, 0.9)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var r: Array[Vector3] = rib.call(s, side)
		var at := lean * r[3]
		VaelModels.kelp(l, at + Vector3(0, -0.05, side * 0.05), rng.randf_range(0.4, 1.0), 2, rng)
	b.add(l)
	# Solid: her sides (open where she is stove in), her stern and cabin.
	for side: float in [-1.0, 1.0]:
		var wall_z := side * beam * 0.45
		if side > 0:
			for seg: Vector2 in [Vector2(-half * 0.85, hole.x), Vector2(hole.y, half * 0.85)]:
				b.solid(lean * Vector3((seg.x + seg.y) * 0.5, 0.0, wall_z), Vector3(seg.y - seg.x, depth * 0.7, 0.7))
		else:
			b.solid(lean * Vector3(0, 0.0, wall_z), Vector3(length * 0.85, depth * 0.7, 0.7))
	b.solid(lean * Vector3(-half * 0.7, deck_y + 0.85, 0), Vector3(length * 0.18, 1.7, beam * 0.62))
	b.w.perches.append(b.xf * (lean * Vector3(-half * 0.7, deck_y + 1.8, 0)))
	MesenllaBuilder._feature(b, "wreck", length)
	b.xf = at_rest


## A small boat drawn up on the shore, keel up, or lying on its side: planks, oars and a coil of rope.
static func boat(b: MapBuilder, length: float, upturned: bool) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var half := length * 0.5
	var beam := length * 0.34
	var flip := Basis(Vector3(1, 0, 0), PI) if upturned else Basis(Vector3(1, 0, 0), 0.9)
	var lift := Vector3(0, 0.55 if upturned else 0.35, 0)
	for k in 7:
		var s := float(k) / 6.0
		var x := lerpf(-half, half, s)
		var fat := sin(clampf(s, 0.05, 0.95) * PI) ** 0.5
		var x2 := lerpf(-half, half, minf(1.0, s + 1.0 / 6.0))
		var fat2 := sin(clampf(minf(1.0, s + 1.0 / 6.0), 0.05, 0.95) * PI) ** 0.5
		if k == 6:
			break
		for side: float in [-1.0, 1.0]:
			var a0 := flip * Vector3(x, -0.4 * fat, 0) + lift
			var a1 := flip * Vector3(x, 0.15, side * beam * 0.5 * fat) + lift
			var c0 := flip * Vector3(x2, -0.4 * fat2, 0) + lift
			var c1 := flip * Vector3(x2, 0.15, side * beam * 0.5 * fat2) + lift
			var col := (HULL_RED if side < 0 else HULL_PAINT).lerp(WOOD_BLEACHED, 0.35).darkened(rng.randf_range(0.0, 0.1))
			l.gable(a0, c0, c1, col)
			l.gable(a0, c1, a1, col)
	for k in 2:
		var off := -0.5 + k * 1.0
		l.box(Vector3(off, 0.08, beam * 0.9), Vector3(length * 0.75, 0.06, 0.12), WOOD_BLEACHED, Vector3(0, rng.randf_range(-12, 12), 0))
	b.solid(lift, Vector3(length * 0.9, 0.9, beam * 0.9))


## A wooden crane on the quay: a post on a braced foot, a jib reaching out over the water, a block
## and tackle, and a net of cargo hanging from its hook.
static func crane(b: MapBuilder, high: float) -> void:
	var l := b.mesh()
	l.box(Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 2.4), WOOD_DARK)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		l.prism(Vector3(c.x * 1.1, 0.5, c.y * 1.1), Vector3(c.x * 0.2, high * 0.45, c.y * 0.2), 0.1, 0.1, 5, WOOD_WET)
	l.prism(Vector3(0, 0.5, 0), Vector3(0, high, 0), 0.26, 0.22, 7, WOOD_WET)
	var tip := Vector3(0, high + 1.2, high * 0.7)
	l.prism(Vector3(0, high * 0.75, 0), tip, 0.18, 0.12, 6, WOOD_WET.lightened(0.05))
	l.prism(Vector3(0, high, 0), tip, 0.06, 0.06, 4, ROPE)
	l.box(tip + Vector3(0, -0.25, 0), Vector3(0.3, 0.45, 0.25), WOOD_DARK)
	var hook := tip + Vector3(0, -high * 0.6, 0)
	l.prism(tip + Vector3(0, -0.4, 0), hook, 0.03, 0.03, 3, ROPE)
	l.prism(hook, hook + Vector3(0, -0.3, 0.15), 0.04, 0.02, 4, IRON)
	# The cargo net: crates and a barrel bundled in rope.
	var net := hook + Vector3(0, -1.1, 0)
	l.box(net + Vector3(-0.3, 0, 0), Vector3(0.7, 0.6, 0.7), WOOD_BLEACHED, Vector3(0, 15, 0))
	l.box(net + Vector3(0.35, 0.05, 0.1), Vector3(0.55, 0.55, 0.55), WOOD_WET, Vector3(0, -20, 0))
	l.prism(net + Vector3(0, 0.5, 0), net + Vector3(-0.6, -0.3, 0), 0.02, 0.02, 3, NET)
	l.prism(net + Vector3(0, 0.5, 0), net + Vector3(0.6, -0.3, 0.1), 0.02, 0.02, 3, NET)
	l.prism(net + Vector3(-0.6, -0.32, 0), net + Vector3(0.6, -0.32, 0.1), 0.02, 0.02, 3, NET)
	b.add(l)
	b.solid(Vector3(0, high * 0.5, 0), Vector3(1.2, high, 1.2))


## Fishing nets hung to dry on a rack of poles along the piece's X axis, with floats and a basket.
static func net_rack(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var posts := int(length / 2.5) + 1
	for k in posts:
		var x := lerpf(-length * 0.5, length * 0.5, float(k) / maxf(1.0, posts - 1))
		l.prism(Vector3(x, 0, 0), Vector3(x, 2.2, 0), 0.07, 0.06, 5, WOOD_BLEACHED.darkened(0.2))
		b.solid(Vector3(x, 1.0, 0), Vector3(0.2, 2.0, 0.2))
	l.prism(Vector3(-length * 0.5, 2.1, 0), Vector3(length * 0.5, 2.1, 0), 0.04, 0.04, 4, WOOD_BLEACHED)
	for k in posts - 1:
		var x0 := lerpf(-length * 0.5, length * 0.5, float(k) / maxf(1.0, posts - 1))
		var x1 := lerpf(-length * 0.5, length * 0.5, float(k + 1) / maxf(1.0, posts - 1))
		var sag := rng.randf_range(0.6, 1.1)
		# The net: a sheet of mesh, both faces, dark with wet.
		l.gable(Vector3(x0, 2.05, 0), Vector3(x1, 2.05, 0), Vector3((x0 + x1) * 0.5, 2.05 - sag * 1.4, 0.04), NET)
		for f in 3:
			var x := lerpf(x0, x1, (f + 0.5) / 3.0)
			l.box(Vector3(x, 2.0 - sag * 0.6, 0.06), Vector3(0.12, 0.12, 0.12), Color(0.7, 0.55, 0.3))
	l.prism(Vector3(length * 0.5 + 0.8, 0, 0.6), Vector3(length * 0.5 + 0.8, 0.5, 0.6), 0.35, 0.42, 8, ROPE.darkened(0.3))


## Lobster pots and crab creels stacked, a coil of rope and a few floats.
static func pots(b: MapBuilder) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var count := 3 + rng.randi() % 3
	for k in count:
		var at := Vector3(rng.randf_range(-1.0, 1.0), 0.3 + (0.55 if k >= 3 else 0.0), rng.randf_range(-0.6, 0.6))
		var turn := rng.randf_range(0, 180)
		l.box(at, Vector3(0.8, 0.5, 0.55), WOOD_BLEACHED.darkened(0.25), Vector3(0, turn, 0))
		for h in 3:
			l.prism(at + Vector3(-0.35 + h * 0.35, -0.25, 0).rotated(Vector3.UP, deg_to_rad(turn)), at + Vector3(-0.35 + h * 0.35, 0.3, 0).rotated(Vector3.UP, deg_to_rad(turn)), 0.02, 0.02, 3, ROPE)
	for k in 6:
		var a := TAU * k / 6.0
		l.prism(Vector3(1.5 + cos(a) * 0.35, 0.05, sin(a) * 0.35), Vector3(1.5 + cos(a + 1.05) * 0.35, 0.05, sin(a + 1.05) * 0.35), 0.05, 0.05, 4, ROPE)
	b.solid(Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 1.2))


## A harbour lamp on an iron post, its lantern lit: a warm light on the quay at night.
static func lamp_post(b: MapBuilder) -> void:
	var l := b.cell()
	l.prism(Vector3(0, 0, 0), Vector3(0, 0.4, 0), 0.2, 0.15, 6, IRON)
	l.prism(Vector3(0, 0.4, 0), Vector3(0, 3.2, 0), 0.07, 0.06, 6, IRON)
	l.prism(Vector3(0, 3.2, 0), Vector3(0.45, 3.4, 0), 0.04, 0.04, 4, IRON)
	l.prism(Vector3(0.5, 3.35, 0), Vector3(0.5, 2.95, 0), 0.15, 0.16, 4, IRON)
	l.prism(Vector3(0.5, 3.35, 0), Vector3(0.5, 3.5, 0), 0.17, 0.02, 4, BRONZE_GREEN)
	b.solid(Vector3(0, 1.6, 0), Vector3(0.25, 3.2, 0.25))
	var lamp := b.mesh()
	lamp.box(Vector3(0.5, 3.12, 0), Vector3(0.22, 0.3, 0.22), LAMP)
	MesenllaBuilder._shine(b, lamp)
	var flame_at := b.xf * Vector3(0.5, 3.12, 0)
	b.w.add_glow(flame_at, LAMP, 2.4)
	b.w.add_fire(b.xf.origin, WorldLight.LANTERN_REACH)
	if b.quality > 0 and not b.is_preview:
		var light := OmniLight3D.new()
		light.position = flame_at
		light.light_color = LAMP
		light.light_energy = 2.0
		light.omni_range = 7.0
		light.omni_attenuation = 1.4
		b.w.add_child(light)
		b.w.add_lantern_light(light)


## The rotten stumps of a pier that has gone: two rows of black piles out along the piece's Z axis, a
## few planks of deck still across them, and weed and barnacles thick on every pile.
static func pilings(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var tide := _tide_line(b)
	var z := 0.0
	while z < length:
		for side: float in [-1.4, 1.4]:
			if rng.randf() < 0.18:
				continue
			var foot := b.xf.affine_inverse() * b.on_ground(Vector3(side, 0, z))
			var top := foot.y + rng.randf_range(1.2, 3.4)
			var lean := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
			l.prism(foot + Vector3(0, -0.3, 0), Vector3(side, top, z) + lean, 0.2, 0.17, 6, WOOD_DARK)
			VaelModels.barnacles(l, Vector3(side, minf(top, tide) - 0.4, z) + lean * 0.5, Vector3(side, 0, 0), 4, 0.05, rng)
			VaelModels.kelp(l, Vector3(side, minf(top, tide) - 0.1, z) + lean * 0.5, 0.6, 2, rng)
			b.solid(Vector3(side, foot.y + 1.0, z), Vector3(0.4, 2.0, 0.4))
		if rng.randf() < 0.35:
			var y := (b.xf.affine_inverse() * b.on_ground(Vector3(0, 0, z))).y + rng.randf_range(1.0, 2.4)
			l.box(Vector3(0, y, z), Vector3(3.4, 0.1, 0.32), WOOD_BLEACHED.darkened(0.3), Vector3(rng.randf_range(-8, 8), rng.randf_range(-6, 6), rng.randf_range(-10, 10)))
		z += 2.4
	b.add(l)


## A ruined bell tower of the drowned town, standing out on the flats: square, of pale stone gone dark
## and weeded up to the high-water mark, with quoins at its corners, a door, slit windows, and at the
## top an open belfry of four pillars under a broken roof, the bell still hanging in it, green with
## age. The whole tower leans a little, as the seabed has given under it.
static func bell_tower(b: MapBuilder, high: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var tide := _tide_line(b)
	var lean := Basis(Vector3(0, 0, 1), 0.07) * Basis(Vector3(1, 0, 0), -0.04)
	var half := 1.8
	var belfry := high - 3.2 # where the open belfry begins
	var stone := QUAY_STONE.lightened(0.08)
	# The plinth, sunk in the sand.
	l.turned_box(lean * Vector3(0, -0.2, 0), Vector3(half * 2.0 + 0.6, 0.8, half * 2.0 + 0.6), _stone_col(-0.2, tide, QUAY_DARK, rng), lean)
	# The shaft, in courses, with quoins at the corners.
	var course := 0.6
	var y := 0.2
	var row := 0
	while y < belfry:
		var mid := y + course * 0.5
		var col := _stone_col(mid, tide, stone, rng)
		l.turned_box(lean * Vector3(0, mid, 0), Vector3(half * 2.0, course - 0.03, half * 2.0), col, lean)
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				var long := 0.7 if (row + int(cx) + int(cz)) % 2 == 0 else 0.45
				l.turned_box(lean * Vector3(cx * (half - long * 0.5 + 0.05), mid, cz * (half + 0.03)), Vector3(long, course - 0.06, 0.12), col.lightened(0.12), lean)
				l.turned_box(lean * Vector3(cx * (half + 0.03), mid, cz * (half - (1.15 - long) * 0.5 + 0.05)), Vector3(0.12, course - 0.06, 1.15 - long), col.lightened(0.12), lean)
		y += course
		row += 1
	# The door, and slit windows up the faces.
	l.turned_box(lean * Vector3(0, 1.3, half + 0.02), Vector3(1.2, 2.2, 0.08), Color(0.05, 0.06, 0.07), lean)
	l.turned_box(lean * Vector3(0, 2.5, half + 0.06), Vector3(1.5, 0.3, 0.16), stone.lightened(0.1), lean)
	for side in 4:
		var a := side * PI * 0.5
		var out := Vector3(sin(a), 0, cos(a))
		for k in 2:
			var wy := belfry * (0.45 + k * 0.25)
			l.turned_box(lean * (out * (half + 0.02) + Vector3(0, wy, 0)), Vector3(0.18 if side % 2 == 0 else 0.08, 0.9, 0.08 if side % 2 == 0 else 0.18), Color(0.05, 0.06, 0.07), lean)
	# A string course, then the belfry: four pillars, the open arches between them.
	l.turned_box(lean * Vector3(0, belfry + 0.1, 0), Vector3(half * 2.0 + 0.3, 0.25, half * 2.0 + 0.3), stone.darkened(0.1), lean)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			l.turned_box(lean * Vector3(cx * (half - 0.3), belfry + 1.45, cz * (half - 0.3)), Vector3(0.6, 2.5, 0.6), stone, lean)
	l.turned_box(lean * Vector3(0, belfry + 2.85, 0), Vector3(half * 2.0 + 0.2, 0.3, half * 2.0 + 0.2), stone.darkened(0.08), lean)
	# The roof, mostly fallen in: two slopes and the bare rafters of the others.
	var top := belfry + 3.0
	var peak := lean * Vector3(0, top + 1.8, 0)
	var c0 := lean * Vector3(-half, top, half)
	var c1 := lean * Vector3(half, top, half)
	var c2 := lean * Vector3(half, top, -half)
	var c3 := lean * Vector3(-half, top, -half)
	l.gable(c0, c1, peak, QUAY_DARK.darkened(0.2))
	l.gable(c1, c2, peak, QUAY_DARK.darkened(0.3))
	for c: Vector3 in [c2, c3]:
		l.prism(c, peak, 0.07, 0.06, 4, WOOD_DARK)
	l.prism(c3, c3.lerp(peak, 0.5) + Vector3(0.3, -0.2, 0), 0.07, 0.06, 4, WOOD_DARK)
	# The bell, its yoke on a beam across the belfry.
	var bell_at := lean * Vector3(0, belfry + 1.5, 0)
	l.turned_box(lean * Vector3(0, belfry + 2.55, 0), Vector3(half * 2.0 - 0.6, 0.18, 0.2), WOOD_DARK, lean)
	l.prism(bell_at + lean * Vector3(0, 0.95, 0), bell_at + lean * Vector3(0, 0.55, 0), 0.25, 0.45, 10, BRONZE_GREEN)
	l.prism(bell_at + lean * Vector3(0, 0.55, 0), bell_at + lean * Vector3(0, -0.25, 0), 0.45, 0.72, 10, BRONZE_GREEN.darkened(0.1))
	l.prism(bell_at + lean * Vector3(0, -0.25, 0), bell_at + lean * Vector3(0, -0.35, 0), 0.75, 0.75, 10, BRONZE)
	l.prism(bell_at + lean * Vector3(0, -0.2, 0), bell_at + lean * Vector3(0, -0.6, 0), 0.06, 0.1, 6, BRONZE.darkened(0.2))
	# Barnacles and weed up to the high-water mark.
	for k in int(high * 3.0):
		var side := rng.randi() % 4
		var a := side * PI * 0.5
		var out := Vector3(sin(a), 0, cos(a))
		var across := out.cross(Vector3.UP)
		var at := lean * (out * (half + 0.04) + across * rng.randf_range(-half, half) + Vector3(0, rng.randf_range(0.1, minf(tide, belfry)), 0))
		VaelModels.barnacles(l, at, lean * out, 3, 0.05, rng)
	for k in 10:
		var side := rng.randi() % 4
		var a := side * PI * 0.5
		var out := Vector3(sin(a), 0, cos(a))
		var across := out.cross(Vector3.UP)
		VaelModels.kelp(l, lean * (out * (half + 0.05) + across * rng.randf_range(-half, half) + Vector3(0, minf(tide, belfry) - 0.05, 0)), rng.randf_range(0.4, 0.9), 2, rng)
	b.add(l)
	b.solid(Vector3(0, belfry * 0.5, 0), Vector3(half * 2.0, belfry, half * 2.0))
	MesenllaBuilder._feature(b, "bell_tower", 3.6)


## A great anchor half buried in the seabed, rusted, its chain running off into the sand.
static func sunk_anchor(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var tilt := Basis(Vector3(0, 0, 1), 0.5)
	l.turned_box(tilt * Vector3(0, size * 0.4, 0), Vector3(size * 0.12, size * 1.1, size * 0.12), RUST, tilt)
	l.turned_box(tilt * Vector3(0, size * 0.9, 0), Vector3(size * 0.7, size * 0.1, size * 0.1), RUST.darkened(0.2), tilt)
	for side: float in [-1.0, 1.0]:
		var arm0 := tilt * Vector3(0, -0.05, 0)
		var arm1 := tilt * Vector3(side * size * 0.5, size * 0.2, 0)
		l.prism(arm0, arm1, size * 0.06, size * 0.05, 5, RUST)
		l.prism(arm1, arm1 + tilt * Vector3(side * size * 0.08, size * 0.25, 0), size * 0.12, 0.0, 4, RUST.darkened(0.1))
	for k in 6:
		l.box(Vector3(-size * 0.4 - k * 0.32, 0.05, k * 0.1), Vector3(0.3, 0.1, 0.18) if k % 2 == 0 else Vector3(0.18, 0.1, 0.3), IRON)
	VaelModels.barnacles(l, tilt * Vector3(0, size * 0.3, size * 0.07), Vector3(0, 0, 1), 6, 0.05, rng)
	b.solid(tilt * Vector3(0, size * 0.4, 0), Vector3(size * 0.4, size * 1.0, size * 0.4))


## Rocks on the flats, dark and weeded, crusted with barnacles below the tide line.
static func sea_rocks(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var tide := _tide_line(b)
	for k in 3 + rng.randi() % 3:
		var at := Vector3(rng.randf_range(-size, size), 0.0, rng.randf_range(-size, size)) * 0.5
		var s := size * rng.randf_range(0.3, 0.6)
		var lie := b.xf.affine_inverse() * b.on_ground(at)
		var centre := lie + Vector3(0, s * 0.3, 0)
		l.box(centre, Vector3(s, s * 0.75, s * 0.9), _stone_col(centre.y, tide, ROCK, rng), Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 90), rng.randf_range(-15, 15)))
		if centre.y < tide:
			VaelModels.barnacles(l, centre + Vector3(0, s * 0.38, 0), Vector3(0, 1, 0), 4, 0.06, rng)
			VaelModels.kelp(l, centre + Vector3(s * 0.4, s * 0.3, 0), 0.5, 2, rng)
		b.solid(centre, Vector3(s, s * 0.75, s * 0.9))


## A channel buoy: an iron cage on a float, tipped on its side on the seabed at low tide.
static func buoy(b: MapBuilder) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var tip := Basis(Vector3(1, 0, 0), 1.1)
	l.turned_box(tip * Vector3(0, 0.3, 0), Vector3(1.1, 0.6, 1.1), HULL_RED.darkened(0.2), tip)
	for k in 4:
		var a := TAU * k / 4.0
		l.prism(tip * Vector3(cos(a) * 0.45, 0.6, sin(a) * 0.45), tip * Vector3(0, 1.9, 0), 0.04, 0.04, 4, IRON)
	l.prism(tip * Vector3(0, 1.7, 0), tip * Vector3(0, 2.1, 0), 0.18, 0.14, 6, IRON)
	VaelModels.barnacles(l, tip * Vector3(0, 0.1, 0.5), tip * Vector3(0, 0, 1), 5, 0.05, rng)
	VaelModels.kelp(l, tip * Vector3(0.4, 0.3, 0.5), 0.6, 3, rng)
	b.solid(Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4))


## Stairs cut into a harbour wall, going down towards +Z from the top (the piece's height) to the
## seabed: worn stone steps, weeded below the tide line. The steps are the land (MapVael.land).
static func sea_stairs(b: MapBuilder, length: float, drop: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var tide := _tide_line(b)
	var steps := int(length / 0.45)
	for k in steps:
		var z := (k + 0.5) * length / steps
		var y := -drop * (k + 1) / steps
		l.box(Vector3(0, y - 0.15, z), Vector3(2.6, 0.32, length / steps + 0.02), _stone_col(y, tide, QUAY_STONE, rng))
	for side: float in [-1.0, 1.0]:
		l.box(Vector3(side * 1.5, -drop * 0.5 + 0.2, length * 0.5), Vector3(0.4, drop + 0.4, length), QUAY_DARK)
		b.solid(Vector3(side * 1.5, -drop * 0.5 + 0.2, length * 0.5), Vector3(0.4, drop + 0.4, length))
	b.add(l)
