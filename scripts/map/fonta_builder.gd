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
	# Steps up at the front, as a slope you can walk.
	b.w.add_ledge(b.xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-16)), Vector3(0, 0.45, d * 0.5 - 0.4)), Vector3(6.0, 0.4, 3.6))
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

## The sailboat that brought you, size metres long, run up on the beach and heeled over on its side:
## bow up the sand along +Z, its mast leaning, its sail torn and flapping in the wind.
static func sailboat(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var len := size
	var beam := size * 0.28
	var depth := size * 0.16
	var heel := Basis(Vector3.FORWARD, deg_to_rad(-24.0)) * Basis(Vector3.RIGHT, deg_to_rad(-4.0))
	var base := b.xf * Transform3D(heel, Vector3(0, -depth * 0.15, 0))
	var hull := LowPoly.new()
	hull.base = base
	const STATIONS := 12
	const ROUND := 5
	var rings: Array = []
	for k in STATIONS + 1:
		var t := float(k) / STATIONS # 0 at the stern, 1 at the bow
		var z := lerpf(-len * 0.5, len * 0.5, t)
		var half := beam * 0.5 * (pow(sin(clampf(t * 0.92 + 0.08, 0.0, 1.0) * PI), 0.55) if t > 0.45 else lerpf(0.72, 1.0, t / 0.45))
		var sheer := depth * (1.0 + 0.35 * pow(t, 2.0) + 0.12 * pow(1.0 - t, 2.0))
		# The keel rises towards bow and stern, so the hull is a boat's shape from the side, not a box.
		var keel := sheer * (0.25 + 0.75 * pow(sin(clampf(t * 0.95 + 0.04, 0.0, 1.0) * PI), 0.7))
		var ring: Array[Vector3] = []
		for q in ROUND * 2 + 1:
			var a := PI * float(q) / (ROUND * 2) # 0 port gunwale, PI starboard gunwale
			var x := -cos(a) * half * (1.0 - 0.15 * pow(sin(a), 4.0))
			var y := sheer - pow(sin(a), 0.8) * keel
			ring.append(Vector3(x, y, z))
		rings.append(ring)
	for k in STATIONS:
		var r0: Array[Vector3] = rings[k]
		var r1: Array[Vector3] = rings[k + 1]
		for q in ROUND * 2:
			# Painted strakes above the waterline, tarred below; each plank runs the length of the hull.
			var col := HULL_PAINT if q < 3 or q > ROUND * 2 - 4 else WOOD_DARK
			col = col.lightened(0.06 * (q % 2))
			var c := Vector3(0, depth * 1.2, (r0[q].z + r1[q].z) * 0.5)
			hull._tri(r0[q], r1[q], r1[q + 1], c, col)
			hull._tri(r0[q], r1[q + 1], r0[q + 1], c, col)
	# The deck, and a white stripe under the gunwale.
	for k in STATIONS:
		var r0: Array[Vector3] = rings[k]
		var r1: Array[Vector3] = rings[k + 1]
		var a0 := r0[0]
		var b0 := r0[ROUND * 2]
		var a1 := r1[0]
		var b1 := r1[ROUND * 2]
		var c := (a0 + b1) * 0.5 + Vector3.DOWN
		hull._tri(a0, b0, b1, c, WOOD.lightened(0.08 * (k % 2)))
		hull._tri(a0, b1, a1, c, WOOD.lightened(0.08 * (k % 2)))
		for edge: Array in [[a0, a1], [b0, b1]]:
			hull.prism((edge[0] as Vector3) + Vector3.DOWN * 0.18, (edge[1] as Vector3) + Vector3.DOWN * 0.18, 0.08, 0.08, 4, SAILCLOTH)
	# A cabin aft, its hatch open.
	hull.box(Vector3(0, depth * 1.2 + 0.5, -len * 0.22), Vector3(beam * 0.55, 1.0, len * 0.22), WOOD)
	hull.box(Vector3(0, depth * 1.2 + 1.03, -len * 0.22), Vector3(beam * 0.6, 0.08, len * 0.24), WOOD_DARK)
	# The bowsprit, the mast, the boom.
	hull.prism(Vector3(0, depth * 1.5, len * 0.45), Vector3(0, depth * 1.9, len * 0.68), 0.12, 0.07, 6, WOOD_DARK)
	var mast_top := Vector3(0, depth * 1.2 + size * 0.75, len * 0.08)
	hull.prism(Vector3(0, depth * 0.6, len * 0.08), mast_top, 0.2, 0.12, 7, WOOD_DARK)
	hull.prism(Vector3(0, depth * 1.2 + 1.6, len * 0.08), Vector3(0, depth * 1.2 + 1.4, -len * 0.35), 0.1, 0.08, 6, WOOD_DARK)
	# Shrouds and stays.
	for p: Vector3 in [Vector3(beam * 0.48, depth * 1.2, len * 0.05), Vector3(-beam * 0.48, depth * 1.2, len * 0.05), Vector3(0, depth * 1.9, len * 0.68)]:
		hull.prism(p, mast_top - Vector3(0, 0.3, 0), 0.025, 0.025, 3, ROPE)
	# Barnacles and weed along the waterline.
	for k in 30:
		var t := rng.randf()
		var ring: Array[Vector3] = rings[int(t * STATIONS)]
		var p: Vector3 = ring[rng.randi_range(3, ROUND * 2 - 3)]
		hull.box(p, Vector3(0.12, 0.08, 0.12), Color(0.55, 0.55, 0.5) if k % 2 else Color(0.2, 0.3, 0.16))
	b.add(hull)
	# The sail, torn, half lowered, flapping: its own mesh, moving in the wind like the trees.
	var sail := LowPoly.new()
	sail.base = base
	var foot_y := depth * 1.2 + 1.7
	var head_y := depth * 1.2 + size * 0.62
	var cols := 5
	var rows := 6
	for i in cols:
		for j in rows:
			if (i == 3 and j > 2) or (i == 4 and j > 3):
				continue # torn away
			var z0 := lerpf(len * 0.06, -len * 0.33, float(i) / cols)
			var z1 := lerpf(len * 0.06, -len * 0.33, float(i + 1) / cols)
			var y0 := lerpf(foot_y, head_y, float(j) / rows)
			var y1 := lerpf(foot_y, head_y, float(j + 1) / rows)
			var belly := func(z: float, y: float) -> float: return sin(clampf((z - len * 0.06) / (-len * 0.39), 0, 1) * PI) * sin(clampf((y - foot_y) / (head_y - foot_y), 0, 1) * PI) * 0.9
			var p := [Vector3(belly.call(z0, y0), y0, z0), Vector3(belly.call(z1, y0), y0, z1), Vector3(belly.call(z1, y1), y1, z1), Vector3(belly.call(z0, y1), y1, z0)]
			# Cloths sewn in vertical panels, weathered unevenly.
			var col := SAILCLOTH.darkened(0.05 * (i % 2) + 0.03 * j / rows)
			for side: float in [1.0, -1.0]:
				var c := Vector3(-side * 3.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
				sail._tri(p[0], p[1], p[2], c, col)
				sail._tri(p[0], p[2], p[3], c, col)
	var sm := sail.commit()
	if sm.get_surface_count() > 0:
		sm.surface_set_material(0, FontaFlora.tree_material())
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		b.w.add_child(mi)
	# Bodies stop at the hull; it can be climbed by its low side.
	for k in 4:
		var t := (k + 0.5) / 4.0
		b.solid(Vector3(0, depth * 0.7, lerpf(-len * 0.45, len * 0.45, t)), Vector3(beam * (0.85 if k in [1, 2] else 0.6), depth * 1.5, len * 0.24))
	b.solid(Vector3(0, depth * 1.2 + size * 0.38, len * 0.08), Vector3(0.4, size * 0.75, 0.4))
	# A lantern hung on the cabin, still burning: the one warm light on the beach.
	var lamp := b.mesh()
	lamp.base = base
	lamp.box(Vector3(beam * 0.32, depth * 1.2 + 1.2, -len * 0.1), Vector3(0.18, 0.26, 0.18), Color(1.0, 0.75, 0.35))
	MesenllaBuilder._shine(b, lamp)
	b.w.add_glow(base * Vector3(beam * 0.32, depth * 1.2 + 1.3, -len * 0.1), Color(1.0, 0.7, 0.35), 4.0)


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


## A cave passage through the rock, size metres long along +Z and wide across: rough walls and a roof
## of rock with stalactites, its floor the land cut level (MapFonta.land), lit inside by a glowing
## pool and the god's crystals. In the middle it opens into a chamber where the cult kept an oracle.
static func grotto(b: MapBuilder, size: float, wide: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var floor_y := 0.0
	var high := 4.2
	var step := 2.0
	var count := int(size / step)
	for k in count + 1:
		var z := -size * 0.5 + k * step
		var chamber := 1.0 + 0.9 * exp(-pow(z / (size * 0.18), 2.0))
		var half := wide * 0.5 * chamber
		var top := high * (1.0 + (chamber - 1.0) * 0.6)
		# Walls, of piled rough blocks leaning inward.
		for g: float in [-1.0, 1.0]:
			for q in 3:
				var y := floor_y + q * top / 3.0
				l.box(Vector3(g * (half + 0.6 - q * 0.35), y + top / 6.0, z), Vector3(1.6 + rng.randf() * 0.8, top / 3.0 + 0.4, step + 0.5), LIMESTONE_DARK.darkened(rng.randf_range(0.05, 0.3)), Vector3(rng.randf_range(-6, 6), rng.randf_range(-8, 8), g * (8 + q * 6)))
			b.solid(Vector3(g * (half + 0.9), floor_y + top * 0.5, z), Vector3(1.4, top + 1.0, step + 0.2))
		# The roof: slabs over the passage, stalactites hanging from it.
		l.box(Vector3(0, floor_y + top + 0.6, z), Vector3(half * 2.0 + 2.4, 1.4 + rng.randf() * 0.6, step + 0.6), LIMESTONE_DARK.darkened(rng.randf_range(0.1, 0.35)), Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-5, 5)))
		b.solid(Vector3(0, floor_y + top + 0.9, z), Vector3(half * 2.0 + 2.0, 1.4, step + 0.2))
		for q in 2:
			var x := rng.randf_range(-half * 0.8, half * 0.8)
			l.prism(Vector3(x, floor_y + top, z + rng.randf_range(-0.8, 0.8)), Vector3(x, floor_y + top - rng.randf_range(0.4, 1.3), z), 0.2, 0.0, 5, LIMESTONE.darkened(0.25))
		# Limestone spires on top, so that no one stands on the roof over the passage.
		var spire := Vector3(rng.randf_range(-half, half), floor_y + top + 1.3, z)
		l.prism(spire, spire + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(1.6, 3.0), 0), 0.9, 0.05, 5, LIMESTONE)
		b.solid(spire + Vector3.UP * 1.0, Vector3(1.0, 2.0, 1.0))
	# The entrances: an arch of bigger stones at each end.
	for g: float in [-1.0, 1.0]:
		var z := g * (size * 0.5 + 0.6)
		l.box(Vector3(0, floor_y + high + 1.2, z), Vector3(wide + 3.5, 2.2, 1.6), LIMESTONE.darkened(0.1), Vector3(0, 0, rng.randf_range(-6, 6)))
		for s: float in [-1.0, 1.0]:
			l.box(Vector3(s * (wide * 0.5 + 1.2), floor_y + high * 0.5 + 0.4, z), Vector3(2.0, high + 1.6, 1.8), LIMESTONE, Vector3(0, 0, s * 6))
	b.add(l)
	# Inside: the oracle's pool in the chamber, glowing sea-green, and crystals of the god's colour.
	var glow := b.mesh()
	glow.prism(Vector3(wide * 0.45, floor_y + 0.03, 0), Vector3(wide * 0.45, floor_y + 0.06, 0), 1.6, 1.6, 10, SEA_GLOW)
	for k in 7:
		var at := Vector3(rng.randf_range(-wide * 0.6, wide * 0.6), floor_y, rng.randf_range(-size * 0.4, size * 0.4))
		at.x = signf(at.x) * maxf(absf(at.x), wide * 0.4)
		glow.prism(at, at + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.5, 1.2), rng.randf_range(-0.2, 0.2)), 0.18, 0.0, 5, CHANGE_GLOW if k % 2 else CHANGE_GREEN)
	MesenllaBuilder._shine(b, glow)
	b.w.add_glow(b.xf * Vector3(wide * 0.45, floor_y + 1.0, 0), SEA_GLOW, 5.0)
	b.w.add_glow(b.xf * Vector3(-wide * 0.3, floor_y + 1.4, -size * 0.3), CHANGE_GLOW, 3.5)
	b.w.add_glow(b.xf * Vector3(wide * 0.3, floor_y + 1.4, size * 0.3), CHANGE_GREEN, 3.5)


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
static func limestone(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	for k in rng.randi_range(3, 5):
		var at := Vector3(rng.randf_range(-size * 0.35, size * 0.35), 0, rng.randf_range(-size * 0.35, size * 0.35))
		var h := size * rng.randf_range(0.25, 0.6)
		l.box(at + Vector3(0, h * 0.4, 0), Vector3(size * rng.randf_range(0.25, 0.45), h, size * rng.randf_range(0.25, 0.45)), LIMESTONE.darkened(rng.randf_range(0.0, 0.25)), Vector3(rng.randf_range(-12, 12), rng.randf() * 90, rng.randf_range(-12, 12)))
	b.solid(Vector3(0, size * 0.25, 0), Vector3(size * 0.6, size * 0.5, size * 0.6))
