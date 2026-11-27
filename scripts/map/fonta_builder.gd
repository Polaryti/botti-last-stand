class_name FontaBuilder
## The made things of Fontanova (MapFonta): what is left of a people who worshipped gods now forgotten.
## Their stone is warm limestone and old marble, their pots terracotta, their bronzes gone green; the
## last of their gods, Al'quimelea, god of change, left its mark on everything it touched as a stain
## of shifting violet and green that still glows.
## The gods of the archipelago, as the island's statues, heads and steles show them (variant):
##   0 Al'quimelea, god of change and experimentation: a flask in one hand, a third arm grown wrong.
##   1 Thaleon, the sea-father: bearded, with a fishing spear.
##   2 Ilyria, the sun-crowned: a crown of rays, arms raised.
##   3 Orvane, the twin-faced: one head, a face to the front and one behind.
##   4 Kerys, the huntress: a bow, a hound's head at her hip.

const GODS := ["Al'quimelea, god of change", "Thaleon, the sea-father", "Ilyria, the sun-crowned", "Orvane, the twin-faced", "Kerys, the huntress"]
const BRIDGE_HALF := 1.1

const LIMESTONE := Color(0.74, 0.7, 0.62)
const LIMESTONE_DARK := Color(0.55, 0.51, 0.45)
const COURSE := 1.4 # metres in one course of the cliffs' strata
const CLIFF_GREY := Color(0.58, 0.57, 0.54)
const CLIFF_OCHRE := Color(0.55, 0.48, 0.4)
const MARBLE := Color(0.82, 0.8, 0.75)
const MARBLE_SHADE := Color(0.66, 0.64, 0.6)
const OCHRE := Color(0.62, 0.5, 0.36)
const OCHRE_DARK := Color(0.47, 0.37, 0.27)
const TERRACOTTA := Color(0.66, 0.34, 0.2)
const BRONZE := Color(0.27, 0.47, 0.4)
const GOLD := Color(0.86, 0.68, 0.28)
const STAIN := Color(0.42, 0.24, 0.5) # Al'quimelea's mark on stone
const CHANGE_GLOW := Color(0.72, 0.4, 1.0) # and its light
const CHANGE_GREEN := Color(0.4, 1.0, 0.62)
const WOOD := Color(0.42, 0.3, 0.2)
const WOOD_DARK := Color(0.29, 0.21, 0.15)
const ROPE := Color(0.62, 0.53, 0.38)
const SAILCLOTH := Color(0.82, 0.77, 0.66)
const HULL_PAINT := Color(0.18, 0.32, 0.46)
const HULL_OCHRE := Color(0.7, 0.46, 0.2)
const HULL_TAR := Color(0.12, 0.1, 0.09)
const SEA_GLOW := Color(0.3, 0.9, 0.85)


# --- The gods ------------------------------------------------------------------------------------

## A god on a plinth, high metres tall, facing +Z; or toppled: the figure lying broken beside its empty
## plinth, its head rolled away.
static func god_statue(b: MapBuilder, high: float, variant: int, fallen: bool) -> void:
	var rng := b.seeded()
	var s := high / 5.2
	var l := b.cell()
	# The plinth, stepped, with the god's name once cut into it.
	for k in 3:
		var w := (2.6 - k * 0.45) * s
		l.box(Vector3(0, k * 0.4 * s + 0.2 * s, 0), Vector3(w, 0.4 * s, w), MARBLE_SHADE.darkened(0.05 * k))
	l.box(Vector3(0, 0.95 * s, 0.81 * s), Vector3(1.2 * s, 0.24 * s, 0.03 * s), LIMESTONE_DARK)
	b.solid(Vector3(0, 0.6 * s, 0), Vector3(2.6 * s, 1.2 * s, 2.6 * s))
	var into := b.mesh()
	if fallen:
		# Toppled forward and broken at the waist; the lower half still on its feet, the upper face down.
		into.base = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.2 * s, 0))
		_figure(into, s, variant, rng, 0.0, 1.6)
		into.base = b.xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(82.0)) * Basis(Vector3.UP, deg_to_rad(rng.randf_range(-25, 25))), Vector3(0.4 * s, 0.45 * s, 0.7 * s))
		_figure(into, s, variant, rng, 1.6, 9.0)
		b.solid(Vector3(0.4 * s, 0.4 * s, 3.8 * s), Vector3(1.4 * s, 0.9 * s, 3.4 * s))
	else:
		into.base = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.2 * s, 0))
		_figure(into, s, variant, rng, 0.0, 9.0)
		b.solid(Vector3(0, 3.2 * s, 0), Vector3(1.1 * s, 4.0 * s, 1.0 * s))
	b.add(into)
	_god_light(b, s, variant, fallen)


## The god's figure, about 4.6 units tall at s metres a unit, facing +Z, only the parts between from and
## to units up (so a broken statue can be drawn in pieces): a robe falling in folds, a belt, a broad
## chest under a mantle, a carved head, and arms with hands; then what marks the god.
static func _figure(l: LowPoly, s: float, variant: int, rng: RandomNumberGenerator, from: float, to: float) -> void:
	var stone := MARBLE.darkened(rng.randf_range(0.0, 0.08))
	var shade := MARBLE_SHADE
	var deep := MARBLE_SHADE.darkened(0.3)
	var in_range := func(y0: float, y1: float) -> bool: return y1 > from and y0 < to
	if in_range.call(0.0, 2.3):
		# The robe, with deep folds down to a hem that spreads on the plinth.
		l.prism(Vector3(0, 0, 0), Vector3(0, 0.18 * s, 0), 0.7 * s, 0.64 * s, 12, shade)
		l.prism(Vector3(0, 0.15 * s, 0), Vector3(0, 2.25 * s, 0), 0.62 * s, 0.42 * s, 12, stone)
		for k in 7:
			var a := TAU * k / 7.0 + 0.2
			l.prism(Vector3(cos(a) * 0.6 * s, 0.1 * s, sin(a) * 0.6 * s), Vector3(cos(a) * 0.4 * s, 2.1 * s, sin(a) * 0.4 * s), 0.08 * s, 0.035 * s, 4, shade)
		# A knee showing through, one foot forward.
		l.prism(Vector3(0.18 * s, 0.9 * s, 0.32 * s), Vector3(0.2 * s, 1.35 * s, 0.4 * s), 0.16 * s, 0.13 * s, 6, stone.lightened(0.04))
		l.box(Vector3(0.2 * s, 0.25 * s, 0.62 * s), Vector3(0.2 * s, 0.14 * s, 0.3 * s), stone)
	if in_range.call(2.1, 3.2):
		l.prism(Vector3(0, 2.18 * s, 0), Vector3(0, 2.32 * s, 0), 0.46 * s, 0.46 * s, 10, BRONZE.darkened(0.2)) # belt
		l.prism(Vector3(0, 2.3 * s, 0), Vector3(0, 3.0 * s, 0), 0.42 * s, 0.5 * s, 10, stone.lightened(0.04))
		l.prism(Vector3(0, 2.62 * s, 0.12 * s), Vector3(0, 2.98 * s, 0.14 * s), 0.34 * s, 0.38 * s, 8, stone.lightened(0.06)) # chest
		# The mantle over the left shoulder, falling across the body.
		l.box(Vector3(-0.12 * s, 2.55 * s, 0.38 * s), Vector3(0.7 * s, 0.95 * s, 0.1 * s), shade, Vector3(0, 0, -32))
		l.box(Vector3(-0.3 * s, 2.3 * s, -0.36 * s), Vector3(0.75 * s, 1.5 * s, 0.1 * s), shade, Vector3(-8, 0, -12))
		for side: float in [-1.0, 1.0]:
			FontaFlora.clump(l, Vector3(side * 0.52 * s, 2.96 * s, 0), 0.2 * s, 0.9, stone, rng, 7)
	var head_y := 3.5 * s
	if in_range.call(3.0, 4.3):
		l.prism(Vector3(0, 3.0 * s, 0), Vector3(0, 3.28 * s, 0.02 * s), 0.15 * s, 0.13 * s, 7, stone)
		_head(l, Vector3(0, head_y, 0), s, stone, shade, deep, variant)
	if not in_range.call(2.2, 4.9):
		return
	var right_hand := Vector3(0.62 * s, 2.0 * s, 0.38 * s)
	var left_hand := Vector3(-0.62 * s, 2.0 * s, 0.38 * s)
	match variant:
		0:
			# Al'quimelea, hooded: a flask raised high in the right hand, a mortar against the hip in
			# the left, and from between the shoulders a third arm, jointed too many times, reaching
			# out and down for nothing; crystals of its colour bursting through the stone where it grew.
			right_hand = Vector3(0.5 * s, 4.05 * s, 0.3 * s)
			l.prism(right_hand + Vector3(0, 0.08 * s, 0), right_hand + Vector3(0, 0.32 * s, 0), 0.15 * s, 0.13 * s, 8, Color(0.5, 0.62, 0.6))
			l.prism(right_hand + Vector3(0, 0.32 * s, 0), right_hand + Vector3(0, 0.5 * s, 0), 0.05 * s, 0.05 * s, 6, Color(0.5, 0.62, 0.6))
			left_hand = Vector3(-0.55 * s, 2.15 * s, 0.35 * s)
			l.prism(left_hand + Vector3(0.05 * s, -0.12 * s, 0.06 * s), left_hand + Vector3(0.05 * s, 0.1 * s, 0.06 * s), 0.18 * s, 0.22 * s, 8, BRONZE)
			var third: Array[Vector3] = [Vector3(0, 2.9 * s, -0.35 * s), Vector3(-0.35 * s, 3.5 * s, -0.6 * s), Vector3(-0.95 * s, 3.65 * s, -0.4 * s),
				Vector3(-1.45 * s, 3.3 * s, 0.0), Vector3(-1.7 * s, 2.7 * s, 0.35 * s), Vector3(-1.62 * s, 2.25 * s, 0.6 * s)]
			FontaFlora.limb(l, third, 0.13 * s, 0.06 * s, STAIN, 6)
			for k in range(1, third.size() - 1):
				FontaFlora.clump(l, third[k], 0.12 * s * (1.0 - k * 0.12), 0.9, STAIN.darkened(0.15), rng, 6)
			var tip: Vector3 = third[third.size() - 1]
			for k in 4:
				var a := -0.7 + k * 0.45
				var knuckle := tip + Vector3(cos(a) * 0.12, -0.08, sin(a) * 0.12) * s
				FontaFlora.limb(l, [tip, knuckle, knuckle + Vector3(cos(a) * 0.1, -0.32, sin(a) * 0.1 + 0.06) * s] as Array[Vector3], 0.03 * s, 0.008 * s, STAIN.darkened(0.1), 4)
			for k in 7:
				l.box(Vector3(rng.randf_range(-0.45, 0.2), rng.randf_range(1.0, 2.9), 0.0) * s + Vector3(0, 0, (0.45 if k % 2 else -0.45) * s), Vector3(0.22, 0.35, 0.03) * s * rng.randf_range(0.6, 1.3), STAIN, Vector3(0, 0, rng.randf() * 90))
		1:
			# Thaleon: a fishing spear upright in his right hand.
			l.prism(Vector3(0.62 * s, 0.1 * s, 0.38 * s), Vector3(0.62 * s, 4.7 * s, 0.38 * s), 0.05 * s, 0.05 * s, 5, BRONZE)
			for k in 3:
				var x := (k - 1) * 0.14 * s
				l.prism(Vector3(0.62 * s + x, 4.6 * s, 0.38 * s), Vector3(0.62 * s + x * 1.3, 5.05 * s, 0.38 * s), 0.035 * s, 0.0, 4, BRONZE)
			l.prism(Vector3(0.48 * s, 4.6 * s, 0.38 * s), Vector3(0.76 * s, 4.6 * s, 0.38 * s), 0.03 * s, 0.03 * s, 4, BRONZE)
		2:
			# Ilyria: both arms raised to the sky, palms open to the sun.
			right_hand = Vector3(0.78 * s, 4.25 * s, 0.12 * s)
			left_hand = Vector3(-0.78 * s, 4.25 * s, 0.12 * s)
		3:
			# Orvane: one hand open, held out; the other closed, held back.
			right_hand = Vector3(0.75 * s, 2.55 * s, 0.6 * s)
			left_hand = Vector3(-0.55 * s, 2.2 * s, -0.3 * s)
		4:
			# Kerys: a bow in her left hand, a quiver on her back, a hound's head at her hip.
			left_hand = Vector3(-0.72 * s, 2.35 * s, 0.4 * s)
			var bow: Array[Vector3] = [left_hand + Vector3(0, -1.0 * s, 0.12 * s), left_hand + Vector3(0, -0.5 * s, 0.26 * s), left_hand + Vector3(0, 0, 0.3 * s), left_hand + Vector3(0, 0.5 * s, 0.26 * s), left_hand + Vector3(0, 1.0 * s, 0.12 * s)]
			FontaFlora.limb(l, bow, 0.045 * s, 0.035 * s, BRONZE, 5)
			l.prism(bow[0], bow[4], 0.008 * s, 0.008 * s, 3, ROPE)
			l.prism(Vector3(0.15 * s, 2.3 * s, -0.42 * s), Vector3(-0.2 * s, 3.3 * s, -0.48 * s), 0.12 * s, 0.13 * s, 6, BRONZE.darkened(0.15))
			l.box(Vector3(0.58 * s, 1.15 * s, 0.45 * s), Vector3(0.28 * s, 0.3 * s, 0.42 * s), shade)
			l.prism(Vector3(0.58 * s, 1.25 * s, 0.66 * s), Vector3(0.58 * s, 1.18 * s, 0.86 * s), 0.11 * s, 0.06 * s, 5, stone)
			for side: float in [-1.0, 1.0]:
				l.prism(Vector3(0.58 * s + side * 0.08 * s, 1.32 * s, 0.5 * s), Vector3(0.58 * s + side * 0.1 * s, 1.5 * s, 0.45 * s), 0.05 * s, 0.0, 4, stone)
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.55 * s, 2.92 * s, 0)
		var hand := right_hand if side > 0.0 else left_hand
		var elbow := shoulder.lerp(hand, 0.5) + Vector3(side * 0.14 * s, -0.12 * s, -0.08 * s)
		FontaFlora.limb(l, [shoulder, elbow, hand] as Array[Vector3], 0.13 * s, 0.085 * s, stone, 7)
		# The hand: a palm and a thumb.
		l.box(hand + Vector3(0, -0.06 * s, 0), Vector3(0.12 * s, 0.17 * s, 0.09 * s), stone.lightened(0.03))
		l.prism(hand + Vector3(side * -0.05 * s, 0, 0.03 * s), hand + Vector3(side * -0.09 * s, 0.07 * s, 0.07 * s), 0.03 * s, 0.02 * s, 4, stone)


## A carved head at centre, s metres a unit: a rounded skull, jaw, brow, nose, eyes and mouth, and
## each god's own look (Al'quimelea hooded, half its face a smooth mask; Thaleon bearded; Ilyria in a
## crown of rays; Orvane with a second face behind; Kerys with braided hair).
static func _head(l: LowPoly, c: Vector3, s: float, stone: Color, shade: Color, deep: Color, variant: int) -> void:
	l.prism(c + Vector3(0, -0.24 * s, 0.03 * s), c + Vector3(0, -0.05 * s, 0.02 * s), 0.14 * s, 0.2 * s, 8, stone) # jaw
	l.prism(c + Vector3(0, -0.06 * s, 0), c + Vector3(0, 0.18 * s, 0), 0.2 * s, 0.22 * s, 9, stone.lightened(0.04))
	l.prism(c + Vector3(0, 0.18 * s, -0.01 * s), c + Vector3(0, 0.32 * s, -0.02 * s), 0.22 * s, 0.1 * s, 9, stone) # crown of the skull
	l.box(c + Vector3(0, 0.1 * s, 0.19 * s), Vector3(0.3 * s, 0.05 * s, 0.05 * s), shade) # brow
	for side: float in [-1.0, 1.0]:
		l.box(c + Vector3(side * 0.08 * s, 0.05 * s, 0.195 * s), Vector3(0.08 * s, 0.035 * s, 0.02 * s), deep) # eyes
		l.box(c + Vector3(side * 0.205 * s, 0.02 * s, 0.0), Vector3(0.03 * s, 0.11 * s, 0.07 * s), stone) # ears
	l.prism(c + Vector3(0, 0.08 * s, 0.205 * s), c + Vector3(0, -0.05 * s, 0.25 * s), 0.025 * s, 0.045 * s, 4, stone) # nose
	l.box(c + Vector3(0, -0.12 * s, 0.19 * s), Vector3(0.1 * s, 0.02 * s, 0.02 * s), deep) # mouth
	match variant:
		0:
			l.prism(c + Vector3(0, -0.28 * s, -0.04 * s), c + Vector3(0, 0.36 * s, -0.08 * s), 0.3 * s, 0.18 * s, 9, shade) # the hood
			l.prism(c + Vector3(0, 0.3 * s, -0.08 * s), c + Vector3(0, 0.52 * s, -0.16 * s), 0.18 * s, 0.0, 7, shade)
			l.box(c + Vector3(-0.09 * s, 0.03 * s, 0.215 * s), Vector3(0.19 * s, 0.34 * s, 0.03 * s), MARBLE.lightened(0.08)) # the smooth half-mask
			l.box(c + Vector3(0.03 * s, 0.03 * s, 0.23 * s), Vector3(0.01 * s, 0.36 * s, 0.03 * s), STAIN)
		1:
			l.prism(c + Vector3(0, -0.12 * s, 0.17 * s), c + Vector3(0, -0.62 * s, 0.24 * s), 0.2 * s, 0.05 * s, 7, shade) # beard
			l.prism(c + Vector3(0, 0.22 * s, -0.04 * s), c + Vector3(0, -0.2 * s, -0.2 * s), 0.22 * s, 0.14 * s, 8, shade) # hair
		2:
			for k in 11:
				var a := PI * (0.06 + 0.88 * k / 10.0)
				l.prism(c + Vector3(0, 0.18 * s, -0.04 * s), c + Vector3(cos(a) * 0.62 * s, 0.18 * s + sin(a) * 0.62 * s, -0.04 * s), 0.05 * s, 0.0, 4, GOLD.darkened(0.25))
		3:
			l.box(c + Vector3(0, 0.1 * s, -0.19 * s), Vector3(0.3 * s, 0.05 * s, 0.05 * s), shade)
			for side: float in [-1.0, 1.0]:
				l.box(c + Vector3(side * 0.08 * s, 0.05 * s, -0.195 * s), Vector3(0.08 * s, 0.035 * s, 0.02 * s), deep)
			l.prism(c + Vector3(0, 0.08 * s, -0.205 * s), c + Vector3(0, -0.05 * s, -0.25 * s), 0.025 * s, 0.045 * s, 4, stone)
			l.box(c + Vector3(0, -0.12 * s, -0.19 * s), Vector3(0.1 * s, 0.02 * s, 0.02 * s), deep)
		4:
			l.prism(c + Vector3(0, 0.1 * s, -0.18 * s), c + Vector3(0, -0.6 * s, -0.3 * s), 0.08 * s, 0.05 * s, 5, shade) # a braid


## Each god's own light, faint, where its eyes or its attribute were.
static func _god_light(b: MapBuilder, s: float, variant: int, fallen: bool) -> void:
	var glow := b.mesh()
	var colour: Color = [CHANGE_GLOW, SEA_GLOW, GOLD.lightened(0.2), Color(0.85, 0.85, 1.0), Color(0.6, 1.0, 0.5)][variant % 5]
	var head := Vector3(0, 1.2 * s + 3.45 * s, 0.25 * s) if not fallen else Vector3(0.4 * s, 0.5 * s, 4.1 * s)
	for side: float in [-1.0, 1.0]:
		glow.box(head + Vector3(side * 0.1 * s, 0.03 * s, 0), Vector3(0.08 * s, 0.03 * s, 0.03 * s), colour)
	if variant == 0 and not fallen:
		# The flask is still full of something that glows.
		glow.prism(Vector3(0.55 * s, 1.2 * s + 3.25 * s, 0.4 * s), Vector3(0.55 * s, 1.2 * s + 3.45 * s, 0.4 * s), 0.12 * s, 0.04 * s, 6, CHANGE_GREEN)
	MesenllaBuilder._shine(b, glow)
	b.w.add_glow(b.xf * head, colour, 0.6 * s + (1.0 if variant == 0 else 0.0))


## A god's head, fallen from a colossus and half sunk in the ground, size metres tall, tipped back
## and a little to one side, cracked across the face, its neck broken off.
static func god_head(b: MapBuilder, size: float, variant: int) -> void:
	var rng := b.seeded()
	var s := size / 0.62 # _head is about 0.62 units tall, beard and rays aside
	var l := b.mesh()
	l.base = b.xf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-16, 16))) * Basis(Vector3.RIGHT, deg_to_rad(-22)), Vector3(0, size * 0.28, 0))
	var stone := MARBLE.darkened(0.1)
	_head(l, Vector3.ZERO, s, stone, MARBLE_SHADE, MARBLE_SHADE.darkened(0.35), variant)
	# The broken neck, and a crack across the face.
	l.prism(Vector3(0, -0.24 * s, 0), Vector3(0, -0.42 * s, -0.02 * s), 0.15 * s, 0.17 * s, 7, MARBLE_SHADE)
	l.box(Vector3(0.05 * s, 0.0, 0.215 * s), Vector3(0.012 * s, 0.42 * s, 0.03 * s), Color(0.2, 0.18, 0.17), Vector3(0, 0, 22))
	if variant == 0:
		for k in 5:
			l.box(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.25), 0.2) * s, Vector3(0.09, 0.1, 0.02) * s * rng.randf_range(0.6, 1.2), STAIN, Vector3(0, 0, rng.randf() * 90))
	b.add(l)
	b.solid(Vector3(0, size * 0.4, 0), Vector3(size * 0.7, size * 0.8, size * 0.75))
	var weeds := b.cell()
	for k in 7:
		var a := rng.randf() * TAU
		FontaFlora.clump(weeds, Vector3(cos(a) * size * 0.45, 0.1, sin(a) * size * 0.45), rng.randf_range(0.3, 0.55), 0.6, Color(0.3, 0.34, 0.2), rng, 5)


## A colossal stone hand rising out of the ground, size metres tall, as if the god beneath reached up.
static func god_hand(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var s := size
	var l := b.mesh()
	l.base = b.xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-10)), Vector3(0, -0.2 * s, 0))
	var stone := MARBLE.darkened(0.12)
	l.prism(Vector3(0, -0.2 * s, 0), Vector3(0, 0.45 * s, 0.05 * s), 0.26 * s, 0.22 * s, 7, stone)
	l.box(Vector3(0, 0.6 * s, 0.06 * s), Vector3(0.5 * s, 0.36 * s, 0.2 * s), stone)
	for k in 4:
		var x := (k - 1.5) * 0.12 * s
		var bent := 0.15 * k * s * 0.3
		var finger: Array[Vector3] = [Vector3(x, 0.76 * s, 0.06 * s), Vector3(x, 1.0 * s, 0.1 * s + bent), Vector3(x, 1.15 * s - bent, 0.25 * s + bent)]
		FontaFlora.limb(l, finger, 0.05 * s, 0.04 * s, stone.lightened(0.03 * k), 5)
	FontaFlora.limb(l, [Vector3(0.25 * s, 0.55 * s, 0.1 * s), Vector3(0.38 * s, 0.72 * s, 0.2 * s), Vector3(0.36 * s, 0.86 * s, 0.32 * s)] as Array[Vector3], 0.06 * s, 0.045 * s, stone, 5)
	b.add(l)
	b.solid(Vector3(0, 0.5 * s, 0.05 * s), Vector3(0.6 * s, 1.0 * s, 0.4 * s))
	var weeds := b.cell()
	for k in 6:
		var a := rng.randf() * TAU
		FontaFlora.clump(weeds, Vector3(cos(a) * 0.4 * s, 0.1, sin(a) * 0.4 * s), rng.randf_range(0.25, 0.45), 0.6, Color(0.28, 0.34, 0.22), rng, 5)


# --- Ruins ---------------------------------------------------------------------------------------

## A column size metres tall, fluted, with its capital; broken off, it ends in a jagged stump and a
## fallen drum lies beside it.
static func column(b: MapBuilder, size: float, broken: bool) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var r := clampf(size * 0.08, 0.3, 0.6)
	var high := size * (rng.randf_range(0.3, 0.65) if broken else 1.0)
	l.box(Vector3(0, 0.15, 0), Vector3(r * 2.8, 0.3, r * 2.8), MARBLE_SHADE)
	l.prism(Vector3(0, 0.3, 0), Vector3(0, high, 0), r, r * 0.86, 12, MARBLE.darkened(rng.randf_range(0.0, 0.08)))
	for k in 6:
		var a := TAU * k / 6.0
		l.prism(Vector3(cos(a) * r * 0.98, 0.35, sin(a) * r * 0.98), Vector3(cos(a) * r * 0.85, high - 0.05, sin(a) * r * 0.85), 0.05, 0.04, 3, MARBLE_SHADE)
	if broken:
		for k in 4:
			var a := TAU * k / 4.0 + rng.randf()
			l.prism(Vector3(cos(a) * r * 0.4, high, sin(a) * r * 0.4), Vector3(cos(a) * r * 0.5, high + rng.randf_range(0.2, 0.5), sin(a) * r * 0.5), r * 0.4, 0.0, 4, MARBLE)
		var drum := Vector3(r * 3.0, r, rng.randf_range(-1.0, 1.0))
		l.prism(drum + Vector3(0, 0, -size * 0.12), drum + Vector3(0, 0, size * 0.12), r * 0.95, r * 0.95, 10, MARBLE.darkened(0.08))
		b.solid(drum, Vector3(r * 2.0, r * 2.0, size * 0.24))
	else:
		l.prism(Vector3(0, high, 0), Vector3(0, high + 0.25, 0), r * 0.9, r * 1.3, 10, MARBLE)
		l.box(Vector3(0, high + 0.4, 0), Vector3(r * 3.0, 0.3, r * 3.0), MARBLE_SHADE)
	b.solid(Vector3(0, high * 0.5, 0), Vector3(r * 2.0, high, r * 2.0))


## A ruined wall size metres long and up to wide metres high, of ochre blocks, its top broken and its
## fallen stones at its foot.
static func ruin_wall(b: MapBuilder, size: float, wide: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var high := wide if wide > 0.0 else 2.4
	var x := -size * 0.5
	while x < size * 0.5:
		var w := rng.randf_range(0.7, 1.3)
		var top := high * (0.35 + 0.65 * absf(sin((x + size) * 0.45 + rng.randf()))) if absf(x) < size * 0.42 else high * 0.3
		var y := 0.0
		var row := 0
		while y < top:
			var bh := rng.randf_range(0.4, 0.55)
			l.box(Vector3(x + w * 0.5 + (0.2 if row % 2 else 0.0), y + bh * 0.5, 0), Vector3(w - 0.04, bh - 0.03, 0.62), OCHRE.darkened(rng.randf_range(0.0, 0.15)))
			y += bh
			row += 1
		x += w
	for k in int(size * 0.5):
		l.box(Vector3(rng.randf_range(-size * 0.5, size * 0.5), 0.2, rng.randf_range(0.6, 1.6) * (1 if k % 2 else -1)), Vector3(0.8, 0.4, 0.55), OCHRE_DARK, Vector3(rng.randf() * 10, rng.randf() * 90, 0))
	b.solid(Vector3(0, high * 0.4, 0), Vector3(size, high * 0.8, 0.62))


## The Temple of Al'quimelea, size metres wide and wide deep, facing +Z: three steps up, a ring of
## columns (some fallen), the cella's walls with a door, its roof fallen in, and inside, the god's
## sigil in the floor, glowing.
static func temple(b: MapBuilder, size: float, wide: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var w := size
	var d := wide
	for k in 3:
		l.box(Vector3(0, k * 0.35 + 0.17, 0), Vector3(w - k * 1.0, 0.35, d - k * 1.0), MARBLE_SHADE.darkened(0.04 * (2 - k)))
	var floor_y := 1.05
	b.solid(Vector3(0, 0.5, 0), Vector3(w - 2.0, 1.0, d - 2.0))
	# The steps are walked as slopes across the whole front and both sides, so no step is a wall.
	b.w.add_ledge(b.xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16)), Vector3(0, 0.45, d * 0.5 - 0.4)), Vector3(w - 0.4, 0.4, 3.6))
	for side: float in [-1.0, 1.0]:
		var turn := Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-16))
		b.w.add_ledge(b.xf * Transform3D(turn, Vector3(side * (w * 0.5 - 0.4), 0.45, 0)), Vector3(d - 0.4, 0.4, 3.6))
	# The peristyle: columns all round, some gone, some broken.
	var col_h := 7.5
	var cols := 0
	for side in 4:
		var count := 7 if side % 2 == 0 else 5
		for k in count:
			var t := float(k) / (count - 1)
			var at := Vector3.ZERO
			match side:
				0: at = Vector3(lerpf(-w * 0.5 + 2.0, w * 0.5 - 2.0, t), floor_y, d * 0.5 - 2.0)
				1: at = Vector3(w * 0.5 - 2.0, floor_y, lerpf(d * 0.5 - 2.0, -d * 0.5 + 2.0, t))
				2: at = Vector3(lerpf(w * 0.5 - 2.0, -w * 0.5 + 2.0, t), floor_y, -d * 0.5 + 2.0)
				3: at = Vector3(-w * 0.5 + 2.0, floor_y, lerpf(-d * 0.5 + 2.0, d * 0.5 - 2.0, t))
			if (side == 0 and k == 3) or (side % 2 == 1 and (k == 0 or k == count - 1)):
				continue # the doorway, and the corners counted once
			cols += 1
			var standing := rng.randf() > 0.3
			var h := col_h if standing else col_h * rng.randf_range(0.25, 0.55)
			var r := 0.5
			l.box(at + Vector3(0, 0.12, 0), Vector3(1.4, 0.24, 1.4), MARBLE_SHADE)
			l.prism(at + Vector3(0, 0.24, 0), at + Vector3(0, h, 0), r, r * 0.88, 12, MARBLE.darkened(rng.randf_range(0.0, 0.1)))
			if standing:
				l.prism(at + Vector3(0, h, 0), at + Vector3(0, h + 0.3, 0), r * 0.9, r * 1.35, 10, MARBLE)
				l.box(at + Vector3(0, h + 0.45, 0), Vector3(1.5, 0.3, 1.5), MARBLE_SHADE)
			else:
				l.prism(at + Vector3(1.4, 0.45, rng.randf_range(-1, 1)), at + Vector3(1.4 + rng.randf_range(2.0, 3.2), 0.45, rng.randf_range(-1, 1)), 0.45, 0.45, 10, MARBLE.darkened(0.1))
			var world_at := at
			b.solid(world_at + Vector3(0, h * 0.5, 0), Vector3(1.0, h, 1.0))
	# What is left of the entablature, over the front.
	l.box(Vector3(-w * 0.18, floor_y + col_h + 0.95, d * 0.5 - 2.0), Vector3(w * 0.52, 0.8, 1.5), MARBLE_SHADE)
	l.box(Vector3(-w * 0.18, floor_y + col_h + 1.4, d * 0.5 - 2.05), Vector3(w * 0.5, 0.12, 1.4), STAIN.lightened(0.1))
	# A corner of the pediment still up, its gable cut with the god's sigil.
	l.gable(Vector3(-w * 0.44, floor_y + col_h + 1.35, d * 0.5 - 1.6), Vector3(-w * 0.02, floor_y + col_h + 1.35, d * 0.5 - 1.6), Vector3(-w * 0.23, floor_y + col_h + 3.3, d * 0.5 - 1.6), MARBLE)
	# The cella: thick walls, the front with a tall doorway, the roof long fallen in.
	var cw := w * 0.5
	var cd := d * 0.55
	var wall_h := 6.0
	for side: float in [-1.0, 1.0]:
		l.box(Vector3(side * cw * 0.5, floor_y + wall_h * 0.5, 0), Vector3(0.9, wall_h, cd), LIMESTONE)
		b.solid(Vector3(side * cw * 0.5, floor_y + wall_h * 0.5, 0), Vector3(0.9, wall_h, cd))
		l.box(Vector3(side * (cw * 0.25 + 1.3), floor_y + wall_h * 0.5, cd * 0.5), Vector3(cw * 0.5 - 2.6, wall_h, 0.9), LIMESTONE)
		b.solid(Vector3(side * (cw * 0.25 + 1.3), floor_y + wall_h * 0.5, cd * 0.5), Vector3(cw * 0.5 - 2.6, wall_h, 0.9))
	l.box(Vector3(0, floor_y + wall_h * 0.4, -cd * 0.5), Vector3(cw, wall_h * 0.8, 0.9), LIMESTONE.darkened(0.05))
	b.solid(Vector3(0, floor_y + wall_h * 0.4, -cd * 0.5), Vector3(cw, wall_h * 0.8, 0.9))
	l.box(Vector3(0, floor_y + wall_h + 0.3, cd * 0.5), Vector3(3.2, 0.6, 1.0), MARBLE_SHADE) # lintel
	# The stain of the god spreading over the inner walls.
	for k in 14:
		var side := -1.0 if k % 2 else 1.0
		l.box(Vector3(side * (cw * 0.5 - 0.47), floor_y + rng.randf_range(0.5, wall_h - 0.5), rng.randf_range(-cd * 0.45, cd * 0.45)), Vector3(0.03, rng.randf_range(0.6, 1.8), rng.randf_range(0.6, 2.2)), STAIN.darkened(rng.randf() * 0.2))
	# Fallen roof blocks inside.
	for k in 6:
		l.box(Vector3(rng.randf_range(-cw * 0.35, cw * 0.35), floor_y + 0.35, rng.randf_range(-cd * 0.4, -cd * 0.1)), Vector3(rng.randf_range(1.0, 2.0), 0.7, rng.randf_range(0.8, 1.4)), LIMESTONE_DARK, Vector3(rng.randf() * 12, rng.randf() * 90, 0))
	b.add(l)
	# The sigil of change on the floor: two rings, and the spokes of transformation, glowing.
	var sigil := b.mesh()
	var c := Vector3(0, floor_y + 0.04, -cd * 0.1)
	for ring: float in [2.6, 1.7]:
		for k in 24:
			var a := TAU * k / 24.0
			sigil.box(c + Vector3(cos(a) * ring, 0, sin(a) * ring), Vector3(0.12, 0.02, ring * 0.27), CHANGE_GLOW, Vector3(0, -rad_to_deg(a), 0))
	for k in 6:
		var a := TAU * k / 6.0
		sigil.box(c + Vector3(cos(a) * 0.85, 0, sin(a) * 0.85), Vector3(0.1, 0.02, 1.7), CHANGE_GREEN if k % 2 else CHANGE_GLOW, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	MesenllaBuilder._shine(b, sigil)
	b.w.add_glow(b.xf * (c + Vector3.UP * 1.5), CHANGE_GLOW, 6.0)


## An altar of the cult: a block carved with rings, its bowl still holding something that glows.
static func altar(b: MapBuilder) -> void:
	var l := b.cell()
	l.box(Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.0), MARBLE_SHADE)
	l.box(Vector3(0, 1.05, 0), Vector3(1.8, 0.12, 1.2), MARBLE)
	l.box(Vector3(0, 0.55, 0.51), Vector3(1.2, 0.5, 0.03), STAIN)
	l.prism(Vector3(0, 1.1, 0), Vector3(0, 1.3, 0), 0.32, 0.4, 8, BRONZE)
	b.solid(Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.2))
	var glow := b.mesh()
	glow.prism(Vector3(0, 1.27, 0), Vector3(0, 1.31, 0), 0.34, 0.34, 8, CHANGE_GREEN)
	MesenllaBuilder._shine(b, glow)
	b.w.add_glow(b.xf * Vector3(0, 1.6, 0), CHANGE_GREEN, 2.5)


## One of the alchemist god's cauldrons, size metres across: bronze on three legs, an alembic over it,
## and in it something that glows and is never the same colour twice.
static func cauldron(b: MapBuilder, size: float) -> void:
	var s := size
	var l := b.cell()
	for k in 3:
		var a := TAU * k / 3.0
		l.prism(Vector3(cos(a) * 0.45 * s, 0, sin(a) * 0.45 * s), Vector3(cos(a) * 0.3 * s, 0.45 * s, sin(a) * 0.3 * s), 0.05 * s, 0.05 * s, 4, BRONZE.darkened(0.2))
	l.prism(Vector3(0, 0.3 * s, 0), Vector3(0, 0.75 * s, 0), 0.28 * s, 0.5 * s, 10, BRONZE)
	l.prism(Vector3(0, 0.75 * s, 0), Vector3(0, 0.82 * s, 0), 0.52 * s, 0.52 * s, 10, BRONZE.lightened(0.1))
	# The alembic: a glass bulb on a stand and its long beak.
	l.prism(Vector3(0.75 * s, 0, 0), Vector3(0.75 * s, 0.9 * s, 0), 0.03 * s, 0.03 * s, 4, BRONZE.darkened(0.2))
	l.prism(Vector3(0.75 * s, 0.9 * s, 0), Vector3(0.75 * s, 1.15 * s, 0), 0.16 * s, 0.05 * s, 7, Color(0.5, 0.62, 0.6))
	l.prism(Vector3(0.75 * s, 1.12 * s, 0), Vector3(0.25 * s, 1.05 * s, 0), 0.025 * s, 0.015 * s, 4, Color(0.5, 0.62, 0.6))
	b.solid(Vector3(0, 0.45 * s, 0), Vector3(1.0 * s, 0.9 * s, 1.0 * s))
	var glow := b.mesh()
	glow.prism(Vector3(0, 0.78 * s, 0), Vector3(0, 0.8 * s, 0), 0.48 * s, 0.48 * s, 10, CHANGE_GREEN)
	for k in 5:
		glow.box(Vector3(cos(k * 1.3) * 0.25 * s, 0.84 * s + k * 0.03 * s, sin(k * 1.3) * 0.25 * s), Vector3(0.08, 0.08, 0.08) * s, CHANGE_GLOW if k % 2 else CHANGE_GREEN)
	MesenllaBuilder._shine(b, glow)
	b.w.add_glow(b.xf * Vector3(0, 1.3 * s, 0), CHANGE_GREEN, 2.6 * s)


## A carved stone slab, size metres tall, cut with one god's sigil and words no one can read now.
static func stele(b: MapBuilder, size: float, variant: int) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var tilt := Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-8, 8))
	l.box(Vector3(0, size * 0.5 - 0.2, 0), Vector3(size * 0.45, size, size * 0.12), LIMESTONE.darkened(rng.randf() * 0.1), tilt)
	l.box(Vector3(0, size + -0.18, 0), Vector3(size * 0.5, size * 0.08, size * 0.15), LIMESTONE, tilt)
	for k in 5:
		l.box(Vector3(0, size * (0.15 + 0.08 * k), size * 0.062), Vector3(size * 0.32, size * 0.018, 0.01), LIMESTONE_DARK, tilt)
	b.solid(Vector3(0, size * 0.45, 0), Vector3(size * 0.45, size * 0.9, size * 0.15))
	var glow := b.mesh()
	var colour: Color = [CHANGE_GLOW, SEA_GLOW, GOLD.lightened(0.2), Color(0.85, 0.85, 1.0), Color(0.6, 1.0, 0.5)][variant % 5]
	glow.box(Vector3(0, size * 0.72, size * 0.063), Vector3(size * 0.18, size * 0.18, 0.01), colour, tilt + Vector3(0, 0, 45))
	MesenllaBuilder._shine(b, glow)


## Terracotta amphorae, some standing, some fallen and broken.
static func amphorae(b: MapBuilder) -> void:
	var rng := b.seeded()
	var l := b.cell()
	for k in rng.randi_range(3, 6):
		var at := Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
		var col := TERRACOTTA.darkened(rng.randf() * 0.2)
		if k % 3 == 2:
			l.base = b.xf * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(88)) * Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, 0.25, 0))
			_amphora(l, col, true)
		else:
			l.base = b.xf * Transform3D(Basis.IDENTITY, at)
			_amphora(l, col, false)
	l.base = b.xf


static func _amphora(l: LowPoly, col: Color, broken: bool) -> void:
	l.prism(Vector3(0, 0, 0), Vector3(0, 0.15, 0), 0.04, 0.16, 7, col.darkened(0.1))
	l.prism(Vector3(0, 0.15, 0), Vector3(0, 0.55, 0), 0.16, 0.24, 7, col)
	if broken:
		l.prism(Vector3(0, 0.55, 0), Vector3(0.03, 0.66, 0), 0.24, 0.18, 7, col.darkened(0.05))
		return
	l.prism(Vector3(0, 0.55, 0), Vector3(0, 0.78, 0), 0.24, 0.08, 7, col)
	l.prism(Vector3(0, 0.78, 0), Vector3(0, 0.92, 0), 0.06, 0.07, 6, col.lightened(0.05))
	for side: float in [-1.0, 1.0]:
		l.prism(Vector3(side * 0.06, 0.88, 0), Vector3(side * 0.18, 0.7, 0), 0.02, 0.02, 4, col)


## A dry-stone wall holding up an olive terrace, size metres long and wide metres high.
static func terrace_wall(b: MapBuilder, size: float, wide: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var high := wide if wide > 0.0 else 1.1
	# Gaps every few metres to walk through, as the terraces' steps.
	var gap_every := 11.0
	var x := -size * 0.5
	var run_from := x
	while x < size * 0.5:
		if fmod(x + size * 0.5, gap_every) > gap_every - 2.4:
			if x - run_from > 0.5:
				b.solid(Vector3((run_from + x) * 0.5, high * 0.5, 0), Vector3(x - run_from, high, 0.5))
			x += 0.5
			run_from = x
			continue
		var w := rng.randf_range(0.35, 0.6)
		var y := 0.0
		while y < high:
			var h := rng.randf_range(0.2, 0.3)
			var at := b.on_ground(Vector3(x + w * 0.5, 0, 0))
			l.base = Transform3D.IDENTITY
			l.box(at + Vector3(0, y + h * 0.5 - 0.1, 0), Vector3(w * 0.96, h * 0.92, 0.5) , LIMESTONE.darkened(rng.randf_range(0.0, 0.22)), Vector3(rng.randf_range(-4, 4), rad_to_deg(b.xf.basis.get_euler().y), rng.randf_range(-4, 4)))
			y += h
		x += w
	if x - run_from > 0.5:
		b.solid(Vector3((run_from + x) * 0.5, high * 0.5, 0), Vector3(x - run_from, high, 0.5))
	l.base = b.xf


# --- The Landing ---------------------------------------------------------------------------------

## The ship that brought you: a merchantman of the old Mediterranean, size metres long, run up on the
## sand and heeled over on her side. A round-bellied hull of painted planks, sharp at both ends, her
## stern post sweeping up and curling forward over the deck, her stem rising to a carved head, an eye
## painted either side of the bow to see her way. Two steering oars at her quarters, one snapped. A
## single mast with its yard and square sail, torn, the cloth hanging and moving in the wind. On deck: a
## little deckhouse aft, a rack of amphorae, coiled ropes, a stone anchor, the hatch open. A hole stove
## in her low side, ribs showing. Everything is drawn on every side, stern and keel included.
static func sailboat(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var len := size
	var beam := size * 0.3
	var depth := size * 0.15
	var heel := Basis(Vector3.FORWARD, deg_to_rad(-22.0)) * Basis(Vector3.RIGHT, deg_to_rad(-3.0))
	var base := b.xf * Transform3D(heel, Vector3(0, -depth * 0.35, 0))
	var hull := LowPoly.new()
	hull.base = base
	const STATIONS := 18
	const ROUND := 6
	var rings: Array = []
	for k in STATIONS + 1:
		var t := float(k) / STATIONS # 0 at the stern, 1 at the bow
		var z := lerpf(-len * 0.5, len * 0.5, t)
		# Sharp at both ends, fullest just aft of the middle.
		var half := beam * 0.5 * pow(sin(clampf(t, 0.0, 1.0) * PI), 0.62) * (1.0 - 0.08 * t)
		half = maxf(half, 0.06)
		var sheer := depth * (1.0 + 0.45 * pow(absf(t - 0.45) * 2.0, 2.2))
		var keel := sheer * (0.18 + 0.82 * pow(sin(clampf(t, 0.0, 1.0) * PI), 0.55))
		var ring: Array[Vector3] = []
		for q in ROUND * 2 + 1:
			var a := PI * float(q) / (ROUND * 2) # 0 port gunwale, PI starboard gunwale
			var x := -cos(a) * half * (1.0 - 0.12 * pow(sin(a), 4.0))
			var y := sheer - pow(sin(a), 0.75) * keel
			ring.append(Vector3(x, y, z))
		rings.append(ring)
	# The planking: painted strakes above, a band of ochre at the wale, tarred below the waterline.
	for k in STATIONS:
		var r0: Array[Vector3] = rings[k]
		var r1: Array[Vector3] = rings[k + 1]
		for q in ROUND * 2:
			var from_top := mini(q, ROUND * 2 - 1 - q)
			var col := HULL_PAINT if from_top < 2 else (HULL_OCHRE if from_top == 2 else (WOOD_DARK if from_top < 4 else HULL_TAR))
			col = col.darkened(0.07 * (q % 2) + rng.randf() * 0.04)
			var c := Vector3(0, depth * 0.9, (r0[q].z + r1[q].z) * 0.5)
			hull._tri(r0[q], r1[q], r1[q + 1], c, col)
			hull._tri(r0[q], r1[q + 1], r0[q + 1], c, col)
	# Plank seams and the two wales, running the length of her.
	for q in [2, 3, 4, ROUND * 2 - 2, ROUND * 2 - 3, ROUND * 2 - 4]:
		for k in STATIONS:
			var a: Vector3 = rings[k][q]
			var e: Vector3 = rings[k + 1][q]
			var out := Vector3(a.x, 0, 0).normalized() * 0.04
			hull.prism(a + out, e + out, 0.05 if q in [3, ROUND * 2 - 3] else 0.025, 0.05 if q in [3, ROUND * 2 - 3] else 0.025, 4, WOOD_DARK.darkened(0.3) if q in [3, ROUND * 2 - 3] else WOOD_DARK)
	# The keel, under all of her.
	for k in STATIONS:
		hull.prism(rings[k][ROUND], rings[k + 1][ROUND], 0.18, 0.18, 5, WOOD_DARK.darkened(0.2))
	# The deck: planks across her, gunwale capping along both sides.
	for k in STATIONS:
		var r0: Array[Vector3] = rings[k]
		var r1: Array[Vector3] = rings[k + 1]
		var a0 := r0[0]
		var b0 := r0[ROUND * 2]
		var a1 := r1[0]
		var b1 := r1[ROUND * 2]
		var c := (a0 + b1) * 0.5 + Vector3.DOWN
		hull._tri(a0, b0, b1, c, WOOD.lightened(0.06 * (k % 2)))
		hull._tri(a0, b1, a1, c, WOOD.lightened(0.06 * (k % 2)))
		for edge: Array in [[a0, a1], [b0, b1]]:
			hull.prism((edge[0] as Vector3) + Vector3.UP * 0.08, (edge[1] as Vector3) + Vector3.UP * 0.08, 0.11, 0.11, 4, WOOD_DARK)
	# The stern post sweeping up and curling forward over the deck; the stem rising to a carved head.
	var stern: Vector3 = rings[0][ROUND]
	var last := stern
	for k in 9:
		var a := k / 8.0 * PI * 0.95
		var p := Vector3(0, stern.y + depth * 0.6 + sin(a) * depth * 1.2 + (1.0 - cos(a)) * depth * 0.5, -len * 0.5 - sin(a * 0.9) * depth * 0.5 + (1.0 - cos(a)) * depth * 0.55)
		hull.prism(last, p, 0.28 - k * 0.022, 0.26 - k * 0.022, 6, WOOD_DARK.lightened(0.05 * (k % 2)))
		last = p
	var stem: Vector3 = rings[STATIONS][ROUND]
	last = stem
	for k in 7:
		var p := Vector3(0, stem.y + k * depth * 0.2, len * 0.5 + sin(k / 6.0 * PI * 0.5) * depth * 0.4)
		hull.prism(last, p, 0.26, 0.24, 6, WOOD_DARK)
		last = p
	hull.ovoid(last + Vector3(0, 0.25, 0.1), Vector3(0.32, 0.4, 0.45), HULL_OCHRE, HULL_OCHRE.darkened(0.3), 3, 6)
	# The eyes on her bow, to see her way.
	for side: float in [-1.0, 1.0]:
		var ring: Array[Vector3] = rings[STATIONS - 2]
		var at: Vector3 = ring[1 if side < 0 else ROUND * 2 - 1]
		var out := Vector3(side, 0, 0) * 0.08
		var eye_turn := Vector3(0, -side * 18.0, 0)
		hull.box(at + out + Vector3(0, -0.45, 0), Vector3(0.12, 0.55, 1.2), Color(0.95, 0.93, 0.86), eye_turn)
		hull.box(at + out * 2.0 + Vector3(0, -0.45, 0.05), Vector3(0.1, 0.42, 0.42), Color(0.08, 0.08, 0.1), eye_turn)
		hull.box(at + out * 2.0 + Vector3(0, -0.15, 0), Vector3(0.1, 0.08, 1.3), HULL_OCHRE.darkened(0.2), eye_turn)
	# A hole stove in her low side, ribs showing through.
	var holed: Array[Vector3] = rings[7]
	var hole_at: Vector3 = holed[ROUND * 2 - 3]
	hull.box(hole_at + Vector3(0.2, 0, 0.6), Vector3(0.16, 1.3, 2.4), Color(0.05, 0.04, 0.04))
	for k in 4:
		hull.prism(hole_at + Vector3(0.3, -0.7, -0.3 + k * 0.65), hole_at + Vector3(0.3, 0.7, -0.3 + k * 0.65), 0.07, 0.07, 4, WOOD)
	for k in 5:
		hull.box(hole_at + Vector3(0.35, rng.randf_range(-0.8, 0.8), rng.randf_range(-0.6, 1.6)), Vector3(0.05, 0.12, rng.randf_range(0.5, 1.1)), WOOD_DARK, Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-40, 40)))
	# Steering oars at her quarters: the port one still shipped, the starboard snapped.
	for side: float in [-1.0, 1.0]:
		var at: Vector3 = rings[2][0 if side < 0 else ROUND * 2]
		var blade_end := at + Vector3(side * 1.0, -depth * 1.4, -1.6)
		if side > 0:
			blade_end = at.lerp(blade_end, 0.45)
		hull.prism(at + Vector3(0, 0.9, 0.4), blade_end, 0.12, 0.1, 6, WOOD)
		if side < 0:
			hull.box(blade_end + Vector3(0, 0.6, -0.1), Vector3(0.12, 1.6, 0.7), WOOD.darkened(0.1), Vector3(-20, 0, side * 10))
	# The deckhouse aft, its roof tiled.
	var deck_y := depth * 1.02
	hull.box(Vector3(0, deck_y + 0.75, -len * 0.3), Vector3(beam * 0.5, 1.5, len * 0.14), WOOD)
	for k in 5:
		hull.box(Vector3(0, deck_y + 1.55 + k * 0.0, -len * 0.3 - len * 0.06 + k * len * 0.03), Vector3(beam * 0.56, 0.1, len * 0.034), Color(0.62, 0.3, 0.2).darkened(0.08 * (k % 2)))
	hull.box(Vector3(beam * 0.25 + 0.02, deck_y + 0.7, -len * 0.3), Vector3(0.04, 1.0, 0.6), Color(0.08, 0.06, 0.05))
	# A rack of amphorae amidships, a coil of rope, a stone anchor, the hatch open.
	for row in 2:
		for k in 4:
			var at := Vector3(-beam * 0.18 + row * beam * 0.36 - beam * 0.18 * 0.0, deck_y, -len * 0.08 + k * 0.8)
			hull.prism(at, at + Vector3(0, 0.7, 0), 0.22, 0.26, 7, Color(0.66, 0.38, 0.22).darkened(0.08 * ((row + k) % 2)))
			hull.prism(at + Vector3(0, 0.7, 0), at + Vector3(0, 0.95, 0), 0.26, 0.09, 7, Color(0.62, 0.35, 0.2))
	hull.box(Vector3(0, deck_y + 0.04, len * 0.16), Vector3(beam * 0.36, 0.1, 1.6), Color(0.06, 0.05, 0.04))
	hull.prism(Vector3(beam * 0.25, deck_y, len * 0.28), Vector3(beam * 0.25, deck_y + 0.25, len * 0.28), 0.6, 0.6, 12, ROPE)
	hull.prism(Vector3(beam * 0.25, deck_y + 0.25, len * 0.28), Vector3(beam * 0.25, deck_y + 0.27, len * 0.28), 0.25, 0.25, 10, ROPE.darkened(0.4))
	hull.prism(Vector3(-beam * 0.2, deck_y, len * 0.33), Vector3(-beam * 0.2, deck_y + 0.35, len * 0.33), 0.45, 0.4, 7, CLIFF_GREY)
	hull.prism(Vector3(-beam * 0.2, deck_y + 0.15, len * 0.33), Vector3(-beam * 0.2, deck_y + 0.2, len * 0.33), 0.12, 0.12, 6, Color(0.1, 0.1, 0.1))
	# The mast and its yard, braced round, and the rigging.
	var mast_foot := Vector3(0, depth * 0.5, len * 0.02)
	var mast_top := Vector3(0, deck_y + size * 0.62, len * 0.02)
	hull.prism(mast_foot, mast_top, 0.26, 0.16, 8, WOOD_DARK)
	hull.prism(mast_top, mast_top + Vector3(0, 0.5, 0), 0.2, 0.2, 6, WOOD_DARK.darkened(0.2))
	var yard_y := deck_y + size * 0.56
	var yard := Basis(Vector3.UP, deg_to_rad(25.0))
	hull.prism(Vector3(0, yard_y, len * 0.02) + yard * Vector3(-beam * 1.0, 0.4, 0), Vector3(0, yard_y, len * 0.02) + yard * Vector3(beam * 1.0, -0.2, 0), 0.12, 0.12, 6, WOOD_DARK)
	for p: Vector3 in [rings[STATIONS - 1][ROUND], rings[1][ROUND], rings[9][0], rings[9][ROUND * 2]]:
		var tie := Vector3(p.x, maxf(p.y, deck_y), p.z)
		hull.prism(tie, mast_top - Vector3(0, 0.3, 0), 0.035, 0.035, 3, ROPE)
	# Barnacles and weed along her waterline.
	for k in 50:
		var ring: Array[Vector3] = rings[rng.randi_range(1, STATIONS - 1)]
		var p: Vector3 = ring[rng.randi_range(4, ROUND * 2 - 4)]
		hull.box(p, Vector3(0.14, 0.1, 0.14), Color(0.58, 0.57, 0.52) if k % 2 else Color(0.2, 0.32, 0.17))
	b.add(hull)
	# The sail: square, hung from the yard, torn and half fallen, moving in the wind like the trees.
	var sail := LowPoly.new()
	sail.base = base
	var cols := 6
	var rows := 7
	var sail_top := yard_y - 0.1
	var sail_drop := size * 0.42
	for i in cols:
		for j in rows:
			if (i >= 4 and j > 3) or (i == 3 and j > 5) or (i == 0 and j == 6):
				continue # torn away
			var u0 := float(i) / cols
			var u1 := float(i + 1) / cols
			var v0 := float(j) / rows
			var v1 := float(j + 1) / rows
			var corner := func(u: float, v: float) -> Vector3:
				var along := yard * Vector3(lerpf(-beam * 0.95, beam * 0.95, u), 0, 0)
				var belly := sin(u * PI) * sin(v * PI) * 0.9 + v * v * 0.6
				return Vector3(0, sail_top - v * sail_drop, len * 0.02 + 0.3) + along + yard * Vector3(0, 0, belly)
			var p := [corner.call(u0, v0), corner.call(u1, v0), corner.call(u1, v1), corner.call(u0, v1)]
			var col := SAILCLOTH.darkened(0.05 * (i % 2) + 0.06 * v0)
			if j == 1 or (i == 2 and j == 4):
				col = Color(0.62, 0.22, 0.16).lerp(SAILCLOTH, 0.25) # her red band, and a patch
			for side: float in [1.0, -1.0]:
				var c: Vector3 = (p[0] + p[2]) * 0.5 + yard * Vector3(0, 0, -side * 3.0)
				sail._tri(p[0], p[1], p[2], c, col)
				sail._tri(p[0], p[2], p[3], c, col)
	var sm := sail.commit()
	if sm.get_surface_count() > 0:
		sm.surface_set_material(0, FontaFlora.tree_material())
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		b.w.add_child(mi)
	# Bodies stop at the hull; it can be climbed by its low side.
	for k in 5:
		var t := (k + 0.5) / 5.0
		var wide := beam * 0.9 * pow(sin(t * PI), 0.6)
		b.solid(Vector3(0, depth * 0.55, lerpf(-len * 0.46, len * 0.46, t)), Vector3(wide, depth * 1.3, len * 0.19))
	b.solid(Vector3(0, deck_y + size * 0.3, len * 0.02), Vector3(0.4, size * 0.6, 0.4))
	# A lantern hung at the deckhouse door, still burning: the one warm light on the beach.
	var lamp := b.mesh()
	lamp.base = base
	lamp.box(Vector3(beam * 0.3, deck_y + 1.3, -len * 0.25), Vector3(0.2, 0.3, 0.2), Color(1.0, 0.75, 0.35))
	MesenllaBuilder._shine(b, lamp)
	b.w.add_glow(base * Vector3(beam * 0.3, deck_y + 1.4, -len * 0.25), Color(1.0, 0.7, 0.35), 5.0)


## What was carried ashore from the boat: crates, barrels, a coil of rope, sacks and an oar.
static func shore_crates(b: MapBuilder) -> void:
	var rng := b.seeded()
	var l := b.cell()
	for k in 3:
		var at := Vector3(rng.randf_range(-1.5, 1.5), 0.4, rng.randf_range(-1.0, 1.0))
		l.box(at, Vector3(0.8, 0.8, 0.8), WOOD.darkened(rng.randf() * 0.15), Vector3(0, rng.randf() * 40, 0))
		l.box(at + Vector3(0, 0.0, 0.41), Vector3(0.82, 0.08, 0.02), WOOD_DARK, Vector3(0, rng.randf() * 40, 0))
	for k in 2:
		var at := Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(1.0, 1.8))
		l.prism(at, at + Vector3(0, 0.9, 0), 0.32, 0.32, 8, WOOD)
		l.prism(at + Vector3(0, 0.2, 0), at + Vector3(0, 0.26, 0), 0.34, 0.34, 8, Color(0.3, 0.3, 0.3))
		l.prism(at + Vector3(0, 0.64, 0), at + Vector3(0, 0.7, 0), 0.34, 0.34, 8, Color(0.3, 0.3, 0.3))
	l.prism(Vector3(2.0, 0.0, -0.8), Vector3(2.0, 0.18, -0.8), 0.4, 0.4, 10, ROPE)
	l.prism(Vector3(2.0, 0.18, -0.8), Vector3(2.0, 0.2, -0.8), 0.18, 0.18, 8, ROPE.darkened(0.3))
	l.box(Vector3(-2.2, 0.08, -0.4), Vector3(0.15, 0.08, 2.6), WOOD, Vector3(0, 30, 0))
	b.solid(Vector3(0, 0.45, 0.3), Vector3(3.6, 0.9, 2.6))


# --- Crossings -----------------------------------------------------------------------------------

## A rope bridge over a ravine: planks on two ropes, hand-ropes sagging between posts at each end.
## Players walk on its planks (ledges); mobs on the deck the land keeps for them.
static func rope_bridge(b: MapBuilder, _piece: Node3D) -> void:
	var t := b.terrain
	var data := {}
	var near := INF
	for d: Dictionary in t.bridges():
		var mid: Vector2 = (Vector2(d["a"]) + Vector2(d["b"])) * 0.5
		var dist := mid.distance_to(Vector2(b.xf.origin.x, b.xf.origin.z))
		if dist < near:
			near = dist
			data = d
	if data.is_empty():
		return
	var from: Vector2 = data["a"]
	var to: Vector2 = data["b"]
	var along := (to - from).normalized()
	var yaw := atan2(along.x, along.y)
	var length := from.distance_to(to)
	var half := BRIDGE_HALF
	var side := Vector3(along.y, 0, -along.x)
	var l := LowPoly.new()
	var rng := b.seeded()
	const STEP := 0.55
	var parts := maxi(2, int(length / STEP))
	var last := Vector3.ZERO
	for n in parts + 1:
		var s := float(n) / parts
		var p := from.lerp(to, s)
		var at := Vector3(p.x, t.deck_y(data, s), p.y)
		if n > 0:
			var mid := (last + at) * 0.5
			var run := at - last
			var basis := Basis.looking_at(run.normalized(), Vector3.UP)
			b.w.add_ledge(Transform3D(basis, mid + Vector3.DOWN * 0.2), Vector3(half * 2.0, 0.4, run.length() + 0.05))
			if rng.randf() > 0.06 or n < 3 or n > parts - 2:
				l.turned_box(mid + Vector3.DOWN * 0.05, Vector3(half * 2.0 + rng.randf_range(-0.1, 0.15), 0.08, run.length() * 0.78), WOOD.lightened(rng.randf_range(-0.08, 0.1)), basis)
			for g: float in [-1.0, 1.0]:
				l.prism(last + side * g * (half - 0.15) + Vector3.DOWN * 0.12, at + side * g * (half - 0.15) + Vector3.DOWN * 0.12, 0.04, 0.04, 4, ROPE)
		last = at
	# The hand-ropes, sagging from post to post, with drop-lines down to the planks.
	var ends: Array[Vector3] = []
	for s: float in [0.0, 1.0]:
		var p := from.lerp(to, s)
		ends.append(Vector3(p.x, t.deck_y(data, s), p.y))
	for g: float in [-1.0, 1.0]:
		var prev := ends[0] + side * g * (half + 0.1) + Vector3.UP * 1.2
		for n in range(1, 17):
			var s := float(n) / 16
			var p := from.lerp(to, s)
			var deck := Vector3(p.x, t.deck_y(data, s), p.y)
			var hand := deck + side * g * (half + 0.1) + Vector3.UP * (1.2 - sin(s * PI) * 0.25)
			l.prism(prev, hand, 0.035, 0.035, 4, ROPE)
			if n % 2 == 0 and n < 16:
				l.prism(hand, deck + side * g * (half - 0.15), 0.02, 0.02, 3, ROPE.darkened(0.1))
			prev = hand
	for e: Vector3 in ends:
		for g: float in [-1.0, 1.0]:
			l.prism(e + side * g * (half + 0.1) + Vector3.DOWN * 0.8, e + side * g * (half + 0.1) + Vector3.UP * 1.5, 0.13, 0.1, 5, WOOD_DARK)
	# Flat steps at each end, onto the land.
	for s: float in [0.0, 1.0]:
		var p := from.lerp(to, s)
		var out := along * (-1.0 if s == 0.0 else 1.0)
		var flat := Vector3(p.x + out.x * 1.0, t.deck_y(data, s) - 0.2, p.y + out.y * 1.0)
		b.w.add_ledge(Transform3D(Basis(Vector3.UP, yaw), flat), Vector3(half * 2.0, 0.4, 2.4))
	b.add(l)


## The Oracle's Grotto, size metres deep along the piece's +Z and wide across at its mouth (the -Z end,
## at the foot of a cliff): a passage of dark rock widening into the oracle's chamber, where her spring
## glows in a basin of stones among offerings and niches, then narrowing to the sealed door of her
## sanctum, a round room where the veiled oracle sits carved in marble over her altar. Three braziers
## stand cold along the way (FontaRites lights them and opens the door). Walls, roof and stalactites
## are rock blocks, never flat panels; nothing leads out but the way in.
const CAVE_ROCK := Color(0.4, 0.37, 0.36)
const CAVE_DARK := Color(0.26, 0.24, 0.25)
const CAVE_FLOOR := Color(0.46, 0.42, 0.37)
static func grotto(b: MapBuilder, size: float, wide: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var floor_y := 0.0
	var half_len := size * 0.5
	var door_z := size * 0.32
	# How wide and high the cave is along its length: the mouth, the chamber, the neck before the door,
	# the round sanctum.
	var width := func(z: float) -> float:
		var chamber := exp(-pow((z + 1.0) / (size * 0.17), 2.0)) * wide * 0.9
		var sanctum := exp(-pow((z - size * 0.42) / (size * 0.09), 2.0)) * wide * 0.5
		var neck := -exp(-pow((z - door_z) / 1.6, 2.0)) * wide * 0.15
		return wide + chamber + sanctum + neck
	var height := func(z: float) -> float:
		return 4.4 + exp(-pow((z + 1.0) / (size * 0.2), 2.0)) * 2.2 + exp(-pow((z - size * 0.42) / (size * 0.1), 2.0)) * 1.2
	var step := 1.1
	var z := -half_len
	while z <= half_len + 0.6:
		var w: float = width.call(z)
		var h: float = height.call(z)
		for g: float in [-1.0, 1.0]:
			# The wall: courses of rough dark rock, leaning in as they rise.
			var y := floor_y - 0.3
			var course := 0
			while y < h:
				var bh := rng.randf_range(0.8, 1.7)
				var lean := course * 0.22
				var x := g * (w * 0.5 + 0.7 - lean)
				var col := CAVE_ROCK.lerp(CAVE_DARK, rng.randf()).darkened(rng.randf_range(0.0, 0.15))
				# Boulders, not slabs: rounded and uneven, each turned its own way.
				var turn := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-15, 15)), deg_to_rad(rng.randf_range(0, 180)), deg_to_rad(rng.randf_range(-15, 15))))
				l.ovoid(Vector3(x, y + bh * 0.5, z), Vector3(rng.randf_range(0.8, 1.2), bh * 0.62, (step + rng.randf_range(0.4, 1.0)) * 0.62), col.lightened(0.06), col.darkened(0.2), 3, 6, turn)
				y += bh * 0.85
				course += 1
			b.solid(Vector3(g * (w * 0.5 + 0.9), floor_y + h * 0.5, z), Vector3(1.4, h + 1.0, step + 0.15))
		# The roof: heavy slabs, overlapping so no sky shows, and stalactites hanging from it.
		l.box(Vector3(0, floor_y + h + 0.5, z), Vector3(w + 3.0, 1.6, step + 0.9), CAVE_DARK.darkened(rng.randf_range(0.0, 0.25)), Vector3(rng.randf_range(-5, 5), rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		b.solid(Vector3(0, floor_y + h + 0.9, z), Vector3(w + 2.0, 1.4, step + 0.15))
		for q in 3:
			var x := rng.randf_range(-w * 0.42, w * 0.42)
			var drop := rng.randf_range(0.3, 1.4)
			l.prism(Vector3(x, floor_y + h - 0.1, z + rng.randf_range(-0.4, 0.4)), Vector3(x + rng.randf_range(-0.05, 0.05), floor_y + h - 0.1 - drop, z), rng.randf_range(0.12, 0.26), 0.0, 5, CAVE_ROCK.lightened(0.1))
		# The floor: bare stone under everything, worn flags down the middle, loose stones to either side.
		l.box(Vector3(0, floor_y + 0.01, z), Vector3(w + 1.6, 0.04, step + 0.12), CAVE_FLOOR.darkened(0.3 + rng.randf() * 0.1))
		if absf(z) < half_len:
			for k in 2:
				var fx := rng.randf_range(-w * 0.25, w * 0.25)
				l.box(Vector3(fx, floor_y + 0.03, z + rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(0.8, 1.4), 0.08, rng.randf_range(0.6, 1.0)), CAVE_FLOOR.darkened(rng.randf_range(0.0, 0.2)), Vector3(0, rng.randf() * 40, 0))
			for k in 3:
				var fx := rng.randf_range(-w * 0.48, w * 0.48)
				l.ovoid(Vector3(fx, floor_y + 0.06, z + rng.randf_range(-0.5, 0.5)), Vector3(rng.randf_range(0.1, 0.3), 0.1, rng.randf_range(0.1, 0.3)), CAVE_ROCK, CAVE_DARK, 2, 5)
		# Spires on top, so that no one stands on the roof.
		var spire := Vector3(rng.randf_range(-w * 0.4, w * 0.4), floor_y + h + 1.3, z)
		l.prism(spire, spire + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(1.6, 3.0), 0), 0.9, 0.05, 5, LIMESTONE.darkened(0.2))
		b.solid(spire + Vector3.UP * 1.0, Vector3(1.0, 2.0, 1.0))
		z += step
	# The mouth: an arch of great stones, ivy hanging over it, the god's sign cut above.
	var mouth := -half_len - 0.6
	l.box(Vector3(0, floor_y + 5.2, mouth), Vector3(wide + 4.5, 2.4, 1.8), LIMESTONE.darkened(0.15), Vector3(0, 0, rng.randf_range(-4, 4)))
	for g: float in [-1.0, 1.0]:
		l.box(Vector3(g * (wide * 0.5 + 1.4), floor_y + 2.4, mouth), Vector3(2.2, 5.2, 2.0), LIMESTONE.darkened(0.1), Vector3(0, 0, g * 5))
	for k in 8:
		var x := rng.randf_range(-wide * 0.5, wide * 0.5)
		l.box(Vector3(x, floor_y + 4.1 - rng.randf() * 0.8, mouth + 0.95), Vector3(0.25, rng.randf_range(0.8, 1.8), 0.08), Color(0.18, 0.3, 0.14))
	# The back of the sanctum: the living rock.
	for k in 5:
		var x := -wide * 0.9 + k * wide * 0.45
		l.box(Vector3(x, floor_y + 2.6, half_len + 1.4), Vector3(wide * 0.6, 5.8, 2.4), CAVE_DARK.darkened(rng.randf_range(0.0, 0.2)), Vector3(rng.randf_range(-5, 5), rng.randf_range(-10, 10), rng.randf_range(-5, 5)))
	b.solid(Vector3(0, floor_y + 2.8, half_len + 1.6), Vector3(wide * 3.0, 6.5, 1.6))
	# The chamber: the oracle's spring in a ring of stones, niches cut in the walls with lamps and little
	# votive figures, offerings left by the spring.
	var pool := Vector3(-wide * 0.55, floor_y, -1.0)
	for k in 12:
		var a := TAU * k / 12.0
		l.ovoid(pool + Vector3(cos(a) * 1.9, 0.18, sin(a) * 1.9), Vector3(0.42, 0.25, 0.32), CAVE_FLOOR.lightened(0.05), CAVE_DARK, 2, 6)
	for k in 4:
		var g := -1.0 if k % 2 == 0 else 1.0
		var nz := -5.0 + k * 2.6
		var nw: float = width.call(nz)
		var niche := Vector3(g * (nw * 0.5 - 0.15), floor_y + 1.6, nz)
		l.box(niche, Vector3(0.2, 1.1, 0.9), Color(0.08, 0.07, 0.08))
		l.prism(niche + Vector3(-g * 0.15, -0.45, 0), niche + Vector3(-g * 0.15, 0.15, 0), 0.12, 0.08, 6, MARBLE.darkened(0.2))
		l.ovoid(niche + Vector3(-g * 0.15, 0.25, 0), Vector3(0.08, 0.1, 0.08), MARBLE.darkened(0.15), MARBLE.darkened(0.3), 2, 5)
	for k in 6:
		var at := pool + Vector3(rng.randf_range(-2.8, 2.8), 0, rng.randf_range(2.2, 3.4)) * Vector3(1, 0, 1 if k % 2 else -1)
		l.prism(at, at + Vector3(0, 0.45, 0), 0.14, 0.18, 7, Color(0.62, 0.36, 0.22).darkened(0.1 * (k % 3)))
	# The sanctum: the veiled oracle carved sitting on her throne against the back wall, her altar
	# before her (where the relic lies, FontaRites).
	var seat := Vector3(0, floor_y, half_len - 0.6)
	l.box(seat + Vector3(0, 0.6, 0.3), Vector3(2.2, 1.2, 1.4), MARBLE_SHADE)
	l.box(seat + Vector3(0, 2.2, 0.85), Vector3(2.2, 2.6, 0.3), MARBLE_SHADE.darkened(0.05))
	l.prism(seat + Vector3(0, 1.2, 0.1), seat + Vector3(0, 2.7, 0.2), 0.62, 0.42, 8, MARBLE)
	l.prism(seat + Vector3(0, 2.7, 0.2), seat + Vector3(0, 3.5, 0.25), 0.42, 0.05, 8, MARBLE.darkened(0.05)) # the veil over her head
	for g: float in [-1.0, 1.0]:
		l.prism(seat + Vector3(g * 0.5, 1.25, -0.35), seat + Vector3(g * 0.45, 0.1, -0.5), 0.2, 0.17, 6, MARBLE.darkened(0.08)) # her knees, her robe falling
		l.prism(seat + Vector3(g * 0.55, 2.4, 0.1), seat + Vector3(g * 0.35, 1.5, -0.45), 0.12, 0.1, 6, MARBLE) # her arms
	var altar := Vector3(0, floor_y, size * 0.44 - 0.4)
	l.box(altar + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 1.0), MARBLE_SHADE.darkened(0.1))
	l.box(altar + Vector3(0, 1.05, 0), Vector3(2.6, 0.1, 1.2), MARBLE)
	b.add(l)
	if not b.is_preview:
		# Three braziers along the way in (the mouth's hall, the chamber, before the door), the sealed
		# door, and the sanctum's altar behind it with its relic.
		b.w.grotto_rites = {
			"braziers": [b.xf * Vector3(wide * 0.3, floor_y, -size * 0.34), b.xf * Vector3(wide * 0.6, floor_y, -0.5), b.xf * Vector3(-wide * 0.3, floor_y, door_z - 2.2)],
			"door": b.xf * Transform3D(Basis.IDENTITY, Vector3(0, floor_y, door_z)),
			"relic": b.xf * Vector3(0, floor_y + 1.1, size * 0.44 - 0.4),
			"wide": wide,
		}
	# What glows: the spring, crystals of the god's colours on the walls, the sigil on the sanctum floor.
	var glow := b.mesh()
	glow.prism(pool + Vector3(0, 0.05, 0), pool + Vector3(0, 0.12, 0), 1.7, 1.7, 12, SEA_GLOW)
	for k in 14:
		var cz := rng.randf_range(-half_len + 2.0, door_z - 1.0)
		var cw: float = width.call(cz)
		var g := -1.0 if k % 2 else 1.0
		var at := Vector3(g * (cw * 0.5 - 0.1), floor_y + rng.randf_range(0.2, 3.0), cz)
		for c in 3:
			glow.prism(at, at + Vector3(-g * rng.randf_range(0.1, 0.4), rng.randf_range(0.25, 0.7), rng.randf_range(-0.2, 0.2)), 0.1, 0.0, 5, CHANGE_GLOW if (k + c) % 2 else CHANGE_GREEN)
	glow.prism(Vector3(0, floor_y + 0.02, size * 0.4), Vector3(0, floor_y + 0.05, size * 0.4), 1.6, 1.6, 6, CHANGE_GLOW.darkened(0.2))
	MesenllaBuilder._shine(b, glow)
	b.w.add_glow(b.xf * (pool + Vector3(0, 1.0, 0)), SEA_GLOW, 6.0)
	b.w.add_glow(b.xf * Vector3(wide * 0.4, floor_y + 2.0, -size * 0.2), CHANGE_GLOW, 4.0)
	b.w.add_glow(b.xf * Vector3(-wide * 0.4, floor_y + 2.0, size * 0.1), CHANGE_GREEN, 4.0)
	b.w.add_glow(b.xf * Vector3(0, floor_y + 2.5, size * 0.42), CHANGE_GLOW, 5.0)


# --- The sea and the rock ------------------------------------------------------------------------

## Another island of the archipelago, far out at sea, size metres across: a mountain with a temple on
## it and its god's light burning, drawn past the fog so it is always there on the horizon.
static func horizon_isle(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var dark := Color(0.3, 0.32, 0.4)
	for k in 6:
		var at := Vector3(rng.randf_range(-size * 0.3, size * 0.3), Terrain.ISLE_FLOOR + 2.0, rng.randf_range(-size * 0.15, size * 0.15))
		var h := size * rng.randf_range(0.18, 0.42) * (1.4 if k == 0 else 1.0)
		l.prism(at, at + Vector3(rng.randf_range(-size * 0.05, size * 0.05), h, 0), size * rng.randf_range(0.18, 0.3), size * 0.03, 7, dark.lightened(rng.randf() * 0.06))
	var peak := Vector3(0, Terrain.ISLE_FLOOR + 2.0 + size * 0.42 * 1.4, 0)
	l.box(peak + Vector3(0, 1.0, 0), Vector3(size * 0.08, size * 0.03, size * 0.05), dark.lightened(0.1))
	var mi := b.add(l)
	mi.material_override = b.no_fog()
	mi.material_override.albedo_color = Color(0.55, 0.58, 0.66)
	var glow := b.mesh()
	var colours := [SEA_GLOW, GOLD.lightened(0.2), Color(0.85, 0.85, 1.0), Color(0.6, 1.0, 0.5)]
	glow.box(peak + Vector3(0, size * 0.04, 0), Vector3(size * 0.02, size * 0.02, size * 0.02), colours[rng.randi_range(0, colours.size() - 1)])
	var g := b.add(glow)
	var shine := StandardMaterial3D.new()
	shine.vertex_color_use_as_albedo = true
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.disable_fog = true
	g.material_override = shine


## A pillar of limestone standing in the sea, size metres high, white-streaked by the birds.
static func sea_stack(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var base_y := Terrain.ISLE_FLOOR + 1.0 - b.xf.origin.y
	for k in 3:
		var at := Vector3(rng.randf_range(-0.6, 0.6), base_y, rng.randf_range(-0.6, 0.6))
		var h := size * rng.randf_range(0.6, 1.0) - base_y * 0.0 + absf(base_y)
		l.prism(at, at + Vector3(rng.randf_range(-0.5, 0.5), h, rng.randf_range(-0.5, 0.5)), size * rng.randf_range(0.18, 0.26), size * 0.08, 6, LIMESTONE.darkened(rng.randf_range(0.0, 0.2)))
	b.solid(Vector3(0, size * 0.5, 0), Vector3(size * 0.35, size, size * 0.35))


## An outcrop of limestone, size metres across: grey-white blocks, cracked and leaning.
## The Sacred Way's stair: marble treads up the slope the land has here, size metres long towards the
## piece's -Z and wide across, some cracked, some missing their edge. They follow the ground (walked as
## the ramp it is), each tread's top at the ground's height at its upper edge.
static func sacred_stair(b: MapBuilder, size: float, wide: float) -> void:
	var t := b.terrain
	var rng := b.seeded()
	var l := b.mesh()
	l.base = Transform3D.IDENTITY
	var run := 0.55
	var count := int(size / run)
	var back := -b.xf.basis.z.normalized()
	var side := b.xf.basis.x.normalized()
	for i in count:
		var p0 := b.xf.origin + back * (i * run)
		var p1 := b.xf.origin + back * ((i + 1) * run)
		var h0 := t.height(p0.x, p0.z)
		var h1 := t.height(p1.x, p1.z)
		if h1 - h0 < 0.05:
			# The landing: one long worn slab.
			l.box((p0 + p1) * 0.5 + Vector3(0, h1 - 0.12, 0), Vector3(wide, 0.26, run), MARBLE_SHADE.darkened(0.05), Vector3(0, rad_to_deg(atan2(back.x, back.z)), 0))
			continue
		var centre := (p0 + p1) * 0.5
		var tall := h1 - h0 + 0.35
		var col := MARBLE.darkened(rng.randf_range(0.04, 0.2))
		var yaw := rad_to_deg(atan2(back.x, back.z))
		# A tread in two or three slabs across, not one bar.
		var pieces := rng.randi_range(2, 3)
		for k in pieces:
			var w := wide / pieces
			var off := side * (-wide * 0.5 + w * (k + 0.5))
			if rng.randf() < 0.05:
				continue # a slab gone
			l.box(centre + off + Vector3(0, h1 - tall * 0.5, 0), Vector3(w - 0.05, tall, run + 0.02), col.darkened(0.06 * (k % 2)), Vector3(rng.randf_range(-1.5, 1.5), yaw, rng.randf_range(-1.5, 1.5)))
	b.add(l)


## Every cliff on the island dressed in rock: where the land drops sheer, limestone blocks are stacked
## up its face from foot to rim in strata, set into it and turned to face out, so a cliff reads as
## broken rock and not a stretched sheet. Merged per 40 m square.
static func cliff_faces(b: MapBuilder, radius: float) -> void:
	var t := b.terrain
	var keep := b.xf
	b.stand_at(Transform3D.IDENTITY)
	var chunks := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var step := 1.7
	var x := -radius
	while x < radius:
		var z := -radius
		while z < radius:
			z += step
			var gx := (t.ground_height(x + 1.0, z) - t.ground_height(x - 1.0, z)) * 0.5
			var gz := (t.ground_height(x, z + 1.0) - t.ground_height(x, z - 1.0)) * 0.5
			if Vector2(gx, gz).length() < 1.05 or not b._plant_allowed(Vector3(x, 0, z), -0.5):
				continue # not steep, or inside the grotto or another cleared place (the walls beside them keep their rock)
			var out := Vector3(-gx, 0, -gz).normalized()
			var hi := maxf(t.ground_height(x - out.x * 2.5, z - out.z * 2.5), t.ground_height(x, z))
			var lo := maxf(t.ground_height(x + out.x * 2.5, z + out.z * 2.5), Terrain.ISLE_SEA_Y - 1.2)
			if hi - lo < 1.6:
				continue
			var key := Vector2i(int(floor(x / 40.0)), int(floor(z / 40.0)))
			if not chunks.has(key):
				chunks[key] = b.mesh()
			var l: LowPoly = chunks[key]
			var yaw := rad_to_deg(atan2(out.x, out.z))
			# Level courses of limestone, each at its own height everywhere on the island, so the
			# strata run unbroken along a face. A course is laid in this cell only where it meets the
			# face here, so neighbouring cells never stack the same course twice.
			for k in range(ceili((lo - 0.4) / COURSE), floori((hi - 0.3) / COURSE) + 1):
				var yc := (k + 0.5) * COURSE
				if yc > hi - 0.3:
					break
				var s_rim := -2.5
				var s_foot := 2.5
				for _i in 10:
					var mid_s := (s_rim + s_foot) * 0.5
					if t.ground_height(x + out.x * mid_s, z + out.z * mid_s) > yc:
						s_rim = mid_s
					else:
						s_foot = mid_s
				var face := Vector3(x, 0, z) + out * ((s_rim + s_foot) * 0.5)
				if absf(face.x - x) > step * 0.5 or absf(face.z - z) > step * 0.5:
					continue
				var deep := 2.0
				var proud := (0.18 if k % 2 == 0 else 0.0) + rng.randf_range(0.0, 0.14)
				var at := face - out * (deep * 0.5 - proud)
				at.y = yc - 0.02
				var col := _course_colour(k).darkened(rng.randf_range(0.0, 0.07))
				l.box(at, Vector3(rng.randf_range(2.3, 2.9), COURSE * rng.randf_range(0.9, 0.98), deep), col, Vector3(0, yaw, 0))
				# Now and then a cushion of something green clinging on a ledge.
				if rng.randf() < 0.025:
					l.ovoid(at + out * (deep * 0.5 + 0.1) + Vector3.UP * COURSE * 0.5, Vector3(0.6, 0.22, 0.5), Color(0.36, 0.42, 0.22), Color(0.24, 0.3, 0.16), 3, 6)
		x += step
	for key: Vector2i in chunks:
		FontaFlora.keep_mesh("cliffs", b.add(chunks[key]))
	b.stand_at(keep)


## The colour of a course of the island's limestone: pale and grey in turns, and now and then a
## band of ochre where iron ran through the rock.
static func _course_colour(k: int) -> Color:
	var h := absi(k * 7919 + 13) % 11
	if h == 3 or h == 8:
		return CLIFF_OCHRE
	return CLIFF_GREY.lightened(0.08) if k % 2 == 0 else CLIFF_GREY.darkened(0.05)


static func limestone(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	for k in rng.randi_range(3, 5):
		var at := Vector3(rng.randf_range(-size * 0.35, size * 0.35), 0, rng.randf_range(-size * 0.35, size * 0.35))
		var h := size * rng.randf_range(0.25, 0.6)
		l.box(at + Vector3(0, h * 0.4, 0), Vector3(size * rng.randf_range(0.25, 0.45), h, size * rng.randf_range(0.25, 0.45)), LIMESTONE.darkened(rng.randf_range(0.0, 0.25)), Vector3(rng.randf_range(-12, 12), rng.randf() * 90, rng.randf_range(-12, 12)))
	b.solid(Vector3(0, size * 0.25, 0), Vector3(size * 0.6, size * 0.5, size * 0.6))
