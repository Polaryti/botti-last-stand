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
	# Paving.
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


## A ship wrecked on the seabed, lying over on her side along the piece's X axis, bow at +X: the hull
## of tarred planks on its ribs, stove in amidships so the ribs show, the deck tipped towards you (+Z)
## with its hatch and rail, the mast snapped and fallen across the flats with its yard and a rag of
## sail, rigging trailing, and all of it crusted with barnacles and hung with weed. length is from bow
## to stern. Solid where it is solid: you can climb in through the hole in its side.
static func wreck(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var half := length * 0.5
	var beam := length * 0.28
	var depth := length * 0.2
	var heel := 0.62 # how far she lies over
	var lean := Basis(Vector3(1, 0, 0), heel)
	var hole := Vector2(-length * 0.08, length * 0.16) # where her side is stove in, along X
	# Ribs and planks, built as if upright, then tipped over.
	var stations := int(length / 0.9)
	for k in stations + 1:
		var s := float(k) / stations
		var x := lerpf(-half, half, s)
		# The hull's section narrows to the bow and stern.
		var fat := sin(clampf(s, 0.04, 0.96) * PI) ** 0.6
		var wide := beam * 0.5 * fat
		var keel := -depth * (0.4 + 0.6 * fat)
		var stove := x > hole.x and x < hole.y
		for side: float in [-1.0, 1.0]:
			# The rib, in three segments from keel to gunwale.
			var pts := [Vector3(x, keel, 0), Vector3(x, keel * 0.55, side * wide * 0.8), Vector3(x, keel * 0.1, side * wide), Vector3(x, depth * 0.15, side * wide * 0.92)]
			for p in 3:
				var a: Vector3 = lean * pts[p]
				var e: Vector3 = lean * pts[p + 1]
				l.prism(a, e, 0.08, 0.08, 4, WOOD_DARK)
			# Planking between this station and the next, except where she is stove in on her low side.
			if k < stations and not (stove and side < 0):
				var s2 := float(k + 1) / stations
				var x2 := lerpf(-half, half, s2)
				var fat2 := sin(clampf(s2, 0.04, 0.96) * PI) ** 0.6
				var wide2 := beam * 0.5 * fat2
				var keel2 := -depth * (0.4 + 0.6 * fat2)
				var pts2 := [Vector3(x2, keel2, 0), Vector3(x2, keel2 * 0.55, side * wide2 * 0.8), Vector3(x2, keel2 * 0.1, side * wide2), Vector3(x2, depth * 0.15, side * wide2 * 0.92)]
				for p in 3:
					var a0: Vector3 = lean * pts[p]
					var a1: Vector3 = lean * pts[p + 1]
					var c0: Vector3 = lean * pts2[p]
					var c1: Vector3 = lean * pts2[p + 1]
					var col := HULL_PAINT if p == 2 else WOOD_WET
					if p == 2 and k % 7 == 3:
						col = HULL_RED
					col = col.darkened(rng.randf_range(0.0, 0.15))
					l.gable(a0, c0, c1, col)
					l.gable(a0, c1, a1, col)
	# The deck, tipped, with hatch, rail and a broken bit of bulwark.
	var deck_y := depth * 0.12
	l.turned_box(lean * Vector3(0, deck_y, 0), Vector3(length * 0.86, 0.12, beam * 0.86), WOOD_BLEACHED.darkened(0.2), lean)
	l.turned_box(lean * Vector3(length * 0.1, deck_y + 0.3, 0), Vector3(1.6, 0.5, 1.4), WOOD_DARK, lean)
	l.turned_box(lean * Vector3(-length * 0.32, deck_y + 0.9, 0), Vector3(length * 0.16, 1.6, beam * 0.7), WOOD_WET, lean) # the stern cabin
	# The stump of the mast, and the mast itself fallen across the flats with its yard and sail.
	var foot := lean * Vector3(length * 0.05, deck_y, 0)
	l.prism(foot, lean * Vector3(length * 0.05, deck_y + 2.2, 0), 0.24, 0.2, 7, WOOD_WET)
	var fall_dir := Vector3(0.35, 0, 1.0).normalized()
	var mast_from := b.xf.affine_inverse() * b.on_ground(Vector3(length * 0.05, 0, beam * 0.6))
	mast_from.y += 0.25
	var mast_to := b.xf.affine_inverse() * b.on_ground(Vector3(length * 0.05, 0, beam * 0.6) + fall_dir * length * 0.65)
	mast_to.y += 0.2
	l.prism(mast_from, mast_to, 0.22, 0.14, 7, WOOD_WET.darkened(0.1))
	var yard_mid := mast_from.lerp(mast_to, 0.6)
	var yard_dir := fall_dir.cross(Vector3.UP).normalized()
	l.prism(yard_mid - yard_dir * length * 0.22, yard_mid + yard_dir * length * 0.22, 0.1, 0.1, 6, WOOD_DARK)
	# The rag of sail, draped over the yard onto the ground.
	var drape := yard_mid + fall_dir * 1.6 + Vector3(0, -0.15, 0)
	l.gable(yard_mid - yard_dir * length * 0.2, yard_mid + yard_dir * length * 0.15, drape + yard_dir * 0.6, SAIL.darkened(0.2))
	# Rigging trailing.
	for k in 5:
		var from := lean * Vector3(rng.randf_range(-half * 0.6, half * 0.6), deck_y + 0.3, rng.randf_range(-beam * 0.3, beam * 0.3))
		var to := b.xf.affine_inverse() * b.on_ground(Vector3(from.x + rng.randf_range(-2, 2), 0, beam * 0.6 + rng.randf_range(1.0, 4.0)))
		var mid := from.lerp(to, 0.5) + Vector3(0, -0.3, 0)
		l.prism(from, mid, 0.025, 0.025, 3, ROPE)
		l.prism(mid, to, 0.025, 0.025, 3, ROPE.darkened(0.2))
	# Barnacles and weed all over what lies under the tide.
	for k in int(length * 3.0):
		var x := rng.randf_range(-half * 0.9, half * 0.9)
		var up := rng.randf_range(-0.7, 0.4)
		var at := lean * Vector3(x, up * depth, -beam * 0.48)
		VaelModels.barnacles(l, at, lean * Vector3(0, -0.4, -1), 3, 0.05, rng)
	for k in int(length * 1.2):
		var x := rng.randf_range(-half * 0.9, half * 0.9)
		var at := lean * Vector3(x, depth * 0.1, -beam * 0.46)
		VaelModels.kelp(l, at, rng.randf_range(0.4, 1.0), 2, rng)
	b.add(l)
	# Solid: the hull's high side and its keel, the stern cabin; open where she is stove in.
	var high_side := lean * Vector3(0, -depth * 0.2, beam * 0.45)
	b.solid(high_side + Vector3(0, depth * 0.3, 0), Vector3(length * 0.9, depth * 1.2, 0.8))
	var low_side := lean * Vector3(0, -depth * 0.4, -beam * 0.4)
	for seg: Vector2 in [Vector2(-half * 0.9, hole.x), Vector2(hole.y, half * 0.9)]:
		if seg.y - seg.x > 0.5:
			b.solid(Vector3((seg.x + seg.y) * 0.5, low_side.y + depth * 0.45, low_side.z), Vector3(seg.y - seg.x, depth, 0.8))
	b.solid(lean * Vector3(-length * 0.32, deck_y + 0.9, 0), Vector3(length * 0.16, 1.8, beam * 0.6))
	b.solid(mast_from.lerp(mast_to, 0.5), Vector3(0.5, 0.5, 0.5) + (mast_to - mast_from).abs())
	b.w.perches.append(b.xf * (lean * Vector3(0, deck_y + 1.0, beam * 0.3)))
	MesenllaBuilder._feature(b, "wreck", length)


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


## A ruined bell tower of the drowned town, standing out on the flats: square, of dark stone, its top
## broken off, leaning; the bell still hangs in the open frame, green with age. Tolls at the tide's
## turning (see MistTide).
static func bell_tower(b: MapBuilder, high: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var tide := _tide_line(b)
	var lean := Basis(Vector3(0, 0, 1), 0.08) * Basis(Vector3(1, 0, 0), -0.05)
	var course := 0.7
	var y := -0.5
	while y < high:
		var mid := y + course * 0.5
		for side in 4:
			var a := side * PI * 0.5
			var off := Vector3(cos(a), 0, sin(a)) * 1.6
			var size := Vector3(0.4, course - 0.04, 3.6) if side % 2 == 0 else Vector3(3.6, course - 0.04, 0.4)
			# The top is broken: some blocks missing near it.
			if y > high - 2.2 and rng.randf() < 0.35:
				continue
			l.turned_box(lean * (off + Vector3(0, mid, 0)), size, _stone_col(mid, tide, QUAY_DARK.lightened(0.05), rng), lean)
		y += course
	# Arches for the bell.
	var arch_y := high - 2.6
	l.turned_box(lean * Vector3(0, arch_y + 2.1, 0), Vector3(3.6, 0.35, 3.6), QUAY_DARK, lean)
	var bell_at := lean * Vector3(0, arch_y + 1.0, 0)
	l.prism(bell_at + lean * Vector3(0, 0.9, 0), bell_at + lean * Vector3(0, 0.5, 0), 0.25, 0.45, 10, BRONZE_GREEN)
	l.prism(bell_at + lean * Vector3(0, 0.5, 0), bell_at + lean * Vector3(0, -0.3, 0), 0.45, 0.75, 10, BRONZE_GREEN.darkened(0.1))
	l.prism(bell_at + lean * Vector3(0, -0.3, 0), bell_at + lean * Vector3(0, -0.4, 0), 0.78, 0.78, 10, BRONZE)
	l.turned_box(lean * Vector3(0, arch_y + 1.95, 0), Vector3(3.2, 0.18, 0.2), WOOD_DARK, lean)
	for k in int(high * 2.0):
		var at := lean * Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.4, minf(tide, high)), 1.82)
		VaelModels.barnacles(l, at, lean * Vector3(0, 0, 1), 3, 0.05, rng)
	b.add(l)
	b.solid(Vector3(0, high * 0.5, 0), Vector3(3.6, high, 3.6))
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
