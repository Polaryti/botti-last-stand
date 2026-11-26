class_name CultGear
extends RefCounted
## What the cult of Al'quimelea wears, on the shared humanoid bodies (Zombie.BODY_FILES), keyed by
## bone like VaelModels' court; pieces keyed "bone:glow" are lit from inside. They kept bees on the
## terraces and brewed the god's elixirs in the temple, and it shows:
##   cult_worshipper  a hood of undyed linen, a mask of beeswax pressed into cells with violet slits
##                    for eyes, a violet stole with a bronze bee, a robe to the ankle, a rope belt hung
##                    with little clay jars, and a bronze sickle for cutting comb.
##   cult_priest      a tall hood woven like a straw bee-skep, a violet glass eye at its brow, a veil, a
##                    mantle worked with cells, a bandolier of glowing vials, and a staff crowned with
##                    an alembic of green elixir in copper coils.
##   cult_guardian    a bronze helmet with cheek guards and a crest of black and white ostrich plumes,
##                    a bronze cuirass, a crimson cloak, leather strips at the hips, a long spear, and a
##                    round bronze shield marked with the god's cell (on the left arm).

const LINEN := Color(0.8, 0.73, 0.58)
const LINEN_DARK := Color(0.6, 0.53, 0.4)
const OCHRE := Color(0.74, 0.48, 0.18)
const STRAW := Color(0.82, 0.64, 0.3)
const VIOLET := Color(0.38, 0.18, 0.5)
const VIOLET_DARK := Color(0.22, 0.1, 0.3)
const WAX := Color(0.94, 0.83, 0.55)
const BRONZE := Color(0.66, 0.45, 0.2)
const BRONZE_DARK := Color(0.42, 0.28, 0.12)
const CRIMSON := Color(0.56, 0.12, 0.1)
const LEATHER := Color(0.4, 0.26, 0.14)
const CLAY := Color(0.62, 0.34, 0.2)
const ROPE := Color(0.66, 0.56, 0.38)
const GLOW_VIOLET := Color(0.82, 0.55, 1.0)
const GLOW_GREEN := Color(0.55, 1.0, 0.5)
const PLUME_BLACK := Color(0.1, 0.09, 0.09)
const PLUME_WHITE := Color(0.92, 0.9, 0.85)

const GEARED := ["cult_worshipper", "cult_priest", "cult_guardian"]
## How each held piece is turned in its hand (built upright, +Y along the haft).
const TURNS := {"handslot.r": Vector3(0, 0, 1.5), "handslot.l": Vector3(0, 0, 0)}

static var _meshes := {}


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var l := LowPoly.new()
		build.call(l)
		_meshes[key] = l.commit()
	return _meshes[key]


static func gear_for(model: String) -> Dictionary:
	match model:
		"cult_worshipper": return worshipper()
		"cult_priest": return priest()
		"cult_guardian": return guardian()
	return {}


## A hexagonal cell pressed into wax or worked in bronze, facing `out`.
static func _cell(l: LowPoly, at: Vector3, out: Vector3, r: float, col: Color) -> void:
	l.prism(at - out * 0.01, at + out * 0.02, r, r * 0.9, 6, col)


## An elliptical band round the body between heights y0 and y1, (rx, rz) its half-width and half-depth
## at each end, centred `back` behind the bone: robes and cuirasses fitted to a torso that is wider
## than it is deep. Open at both ends.
static func _band(l: LowPoly, y0: float, y1: float, r0: Vector2, r1: Vector2, col: Color, under: Color, back := 0.0, sides := 14) -> void:
	var centre := Vector3(0, (y0 + y1) * 0.5, -back)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p00 := Vector3(sin(a0) * r0.x, y0, cos(a0) * r0.y - back)
		var p01 := Vector3(sin(a1) * r0.x, y0, cos(a1) * r0.y - back)
		var p10 := Vector3(sin(a0) * r1.x, y1, cos(a0) * r1.y - back)
		var p11 := Vector3(sin(a1) * r1.x, y1, cos(a1) * r1.y - back)
		var top := col if y1 > y0 else under
		var low := under if y1 > y0 else col
		l._tri_shaded(p00, p01, p10, centre, low, low, top)
		l._tri_shaded(p01, p11, p10, centre, low, top, top)


## Cloth hung from a thigh bone (+Y runs down the leg, -Z is the front): panels in front, behind and on
## the outside, down to just above the ankle, so a robe parts and swings with every stride.
static func _leg_panels(l: LowPoly, outer: float, col: Color, hem: Color, long := 0.4, wide := 0.27) -> void:
	for spot: Array in [[Vector3(0, 0, -0.17), Vector3(wide, long, 0.03)], [Vector3(0, 0, 0.16), Vector3(wide, long, 0.03)], [Vector3(outer * 0.16, 0, 0), Vector3(0.03, long, wide * 0.9)]]:
		var at: Vector3 = spot[0]
		var size: Vector3 = spot[1]
		l.box(at + Vector3(0, long * 0.5 - 0.02, 0), size, col)
		l.box(at + Vector3(0, long - 0.03, 0), size * Vector3(1.04, 0.0, 1.04) + Vector3(0, 0.06, 0), hem)


## A sleeve on an arm bone (+Y runs along the arm): a tube from the shoulder or the elbow, flaring.
static func _sleeve(l: LowPoly, long: float, r0: float, r1: float, col: Color, cuff := Color(0, 0, 0, 0)) -> void:
	l.prism(Vector3(0, -0.02, 0), Vector3(0, long, 0), r0, r1, 9, col)
	if cuff.a > 0.0:
		l.prism(Vector3(0, long - 0.05, 0), Vector3(0, long, 0), r1 + 0.01, r1 + 0.015, 9, cuff)


# The body, in its bones' own measure (Zombie.BODY_FILES "normal_a"/"normal_b"): the head bone sits at
# the neck, the head above it 0.93 tall and 0.96 wide, its face at z 0.46, the eyes at y 0.36; the
# chest bone 0.27 below the neck, the torso 0.75 wide and 0.6 deep down to the hips 0.5 below it;
# arms 0.24 to the elbow and 0.26 on to the wrist; thighs 0.23, shins 0.14.

static func worshipper() -> Dictionary:
	return {
		"head": _mesh("worshipper_head", func(l: LowPoly) -> void:
			# The hood: over the whole head and round it, its point falling back, its fall on the shoulders.
			l.ovoid(Vector3(0, 0.47, -0.05), Vector3(0.55, 0.54, 0.52), LINEN, LINEN_DARK, 6, 14)
			l.prism(Vector3(0, 0.88, -0.25), Vector3(0, 1.0, -0.62), 0.2, 0.02, 7, LINEN.darkened(0.05))
			l.prism(Vector3(0, 0.12, -0.06), Vector3(0, -0.1, -0.06), 0.5, 0.6, 12, LINEN_DARK)
			# The wax mask over the face, cells pressed into it in rows, a bronze band at the brow.
			l.ovoid(Vector3(0, 0.36, 0.45), Vector3(0.36, 0.36, 0.1), WAX, WAX.darkened(0.18), 4, 12)
			for row in 4:
				for col in 4:
					var x := -0.24 + col * 0.15 + (0.075 if row % 2 else 0.0)
					var y := 0.6 - row * 0.12
					if row == 2 or Vector2(x / 0.32, (y - 0.36) / 0.32).length() > 0.95:
						continue # the eye line stays smooth for the slits
					var z := 0.45 + 0.1 * sqrt(maxf(0.0, 1.0 - pow(x / 0.36, 2) - pow((y - 0.36) / 0.36, 2)))
					_cell(l, Vector3(x, y, z - 0.005), Vector3(0, 0, 1), 0.055, WAX.darkened(0.14))
			l.box(Vector3(0, 0.62, 0.48), Vector3(0.7, 0.05, 0.08), BRONZE)
			# A chin of wax drawn to a point, like a bee's.
			l.prism(Vector3(0, 0.06, 0.48), Vector3(0, -0.08, 0.55), 0.13, 0.01, 6, WAX.darkened(0.06))),
		"head:glow": _mesh("worshipper_eyes", func(l: LowPoly) -> void:
			for x: float in [-0.14, 0.14]:
				l.box(Vector3(x, 0.37, 0.545), Vector3(0.15, 0.035, 0.02), GLOW_VIOLET)),
		"chest": _mesh("worshipper_chest", func(l: LowPoly) -> void:
			# The robe over the torso, and the violet stole over it, a bronze bee pinned at the breast.
			_band(l, 0.27, -0.52, Vector2(0.34, 0.29), Vector2(0.42, 0.35), LINEN, LINEN_DARK)
			for side: float in [-1.0, 1.0]:
				l.turned_box(Vector3(side * 0.13, -0.12, 0.34), Vector3(0.11, 0.72, 0.03), VIOLET, Basis(Vector3.FORWARD, side * 0.12) * Basis(Vector3.RIGHT, -0.12))
				l.box(Vector3(side * 0.17, -0.5, 0.38), Vector3(0.13, 0.05, 0.03), OCHRE)
			l.prism(Vector3(0, 0.12, 0.34), Vector3(0, 0.04, 0.39), 0.045, 0.035, 6, BRONZE)
			for side: float in [-1.0, 1.0]:
				l.box(Vector3(side * 0.06, 0.1, 0.38), Vector3(0.08, 0.04, 0.015), BRONZE.lightened(0.25), Vector3(0, 0, side * 25.0))),
		"upperarm.l": _mesh("worshipper_sleeve_up", func(l: LowPoly) -> void: _sleeve(l, 0.25, 0.12, 0.13, LINEN)),
		"upperarm.r": _mesh("worshipper_sleeve_up", func(l: LowPoly) -> void: _sleeve(l, 0.25, 0.12, 0.13, LINEN)),
		"lowerarm.l": _mesh("worshipper_sleeve_low", func(l: LowPoly) -> void: _sleeve(l, 0.22, 0.13, 0.18, LINEN, LINEN_DARK)),
		"lowerarm.r": _mesh("worshipper_sleeve_low", func(l: LowPoly) -> void: _sleeve(l, 0.22, 0.13, 0.18, LINEN, LINEN_DARK)),
		"hips": _mesh("worshipper_hips", func(l: LowPoly) -> void:
			# A rope belt, the top of the skirt under it, and little clay jars hung from the belt.
			_band(l, 0.08, -0.12, Vector2(0.43, 0.37), Vector2(0.46, 0.4), LINEN, LINEN_DARK)
			_band(l, 0.08, 0.02, Vector2(0.445, 0.385), Vector2(0.445, 0.385), ROPE, ROPE.darkened(0.2))
			for k in 3:
				var a := 1.0 + k * 0.55
				var at := Vector3(sin(a) * 0.46, 0.0, cos(a) * 0.4)
				l.prism(at + Vector3(0, 0.05, 0), at, 0.012, 0.012, 3, ROPE)
				l.prism(at, at + Vector3(0, -0.13, 0), 0.05, 0.065, 6, CLAY.darkened(0.08 * k))
				l.prism(at + Vector3(0, -0.13, 0), at + Vector3(0, -0.17, 0), 0.065, 0.03, 6, CLAY.darkened(0.08 * k))),
		"upperleg.l": _mesh("worshipper_robe_l", func(l: LowPoly) -> void: _leg_panels(l, 1.0, LINEN, LINEN_DARK)),
		"upperleg.r": _mesh("worshipper_robe_r", func(l: LowPoly) -> void: _leg_panels(l, -1.0, LINEN, LINEN_DARK)),
		"handslot.r": _mesh("worshipper_sickle", func(l: LowPoly) -> void:
			# A comb-cutter's sickle: a wooden grip, a bronze crescent.
			l.prism(Vector3(0, -0.08, 0), Vector3(0, 0.28, 0), 0.04, 0.035, 6, LEATHER)
			l.prism(Vector3(0, 0.27, 0), Vector3(0, 0.32, 0), 0.045, 0.045, 6, BRONZE_DARK)
			var last := Vector3(0, 0.32, 0)
			for k in 8:
				var a := (k + 1) / 8.0 * PI * 0.95
				var at := Vector3(0, 0.32 + sin(a) * 0.26, (1.0 - cos(a)) * 0.23)
				l.prism(last, at, 0.03 - k * 0.0025, 0.028 - k * 0.0025, 4, BRONZE.lightened(0.1))
				l.box((last + at) * 0.5, Vector3(0.01, 0.05, 0.05), BRONZE.lightened(0.3))
				last = at),
	}


static func priest() -> Dictionary:
	return {
		"head": _mesh("priest_head", func(l: LowPoly) -> void:
			# A hood woven like a bee-skep over the whole head: rings of straw narrowing to a rounded top.
			for k in 6:
				var y := 0.0 + k * 0.17
				var r0 := 0.6 - k * k * 0.009 - k * 0.02
				var r1 := 0.6 - (k + 1) * (k + 1) * 0.009 - (k + 1) * 0.02
				l.prism(Vector3(0, y, -0.03), Vector3(0, y + 0.17, -0.03), r0, r1, 14, STRAW.darkened(0.1 * (k % 2)))
				l.prism(Vector3(0, y + 0.15, -0.03), Vector3(0, y + 0.19, -0.03), r1 + 0.02, r1 + 0.02, 14, STRAW.darkened(0.2))
			l.prism(Vector3(0, 1.02, -0.03), Vector3(0, 1.12, -0.03), 0.24, 0.05, 10, STRAW.darkened(0.12))
			# The veil: dark gauze over the face below the eye, slit at its hem.
			for k in 7:
				var x := -0.27 + k * 0.09
				var long := 0.34 + 0.06 * sin(k * 1.9)
				var z := 0.56 - absf(x) * 0.25
				l.box(Vector3(x, 0.48 - long * 0.5, z), Vector3(0.085, long, 0.02), VIOLET.lightened(0.05 * (k % 2)))
				l.prism(Vector3(x, 0.48 - long, z), Vector3(x, 0.44 - long, z), 0.012, 0.0, 4, BRONZE.lightened(0.2)) # little bronze weights
			l.box(Vector3(0, 0.49, 0.56), Vector3(0.62, 0.04, 0.035), BRONZE)
			# A bronze setting round the eye at the brow.
			l.prism(Vector3(0, 0.6, 0.55), Vector3(0, 0.6, 0.63), 0.13, 0.13, 8, BRONZE)),
		"head:glow": _mesh("priest_eye", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.6, 0.6), Vector3(0, 0.6, 0.67), 0.09, 0.065, 8, GLOW_VIOLET)),
		"chest": _mesh("priest_chest", func(l: LowPoly) -> void:
			_band(l, 0.27, -0.52, Vector2(0.36, 0.3), Vector2(0.44, 0.37), VIOLET, VIOLET_DARK)
			# The mantle over the shoulders, worked with cells in ochre thread.
			_band(l, 0.29, 0.0, Vector2(0.4, 0.34), Vector2(0.52, 0.45), OCHRE.darkened(0.1), OCHRE.darkened(0.3))
			for k in 9:
				var a := -1.3 + k * 0.325
				_cell(l, Vector3(sin(a) * 0.5, 0.06, cos(a) * 0.43), Vector3(sin(a), 0, cos(a)), 0.045, OCHRE.lightened(0.25))
			# The bandolier: a strap across the chest, its vials in loops.
			l.turned_box(Vector3(0, -0.2, 0.37), Vector3(0.1, 0.85, 0.03), LEATHER, Basis(Vector3.FORWARD, 0.6))
			for k in 4:
				var at := Vector3(-0.2 + k * 0.13, -0.02 - k * 0.12, 0.4)
				l.prism(at + Vector3(0, 0.08, 0), at + Vector3(0, 0.11, 0), 0.02, 0.02, 5, Color(0.6, 0.2, 0.15))),
		"chest:glow": _mesh("priest_vials", func(l: LowPoly) -> void:
			for k in 4:
				var at := Vector3(-0.2 + k * 0.13, -0.02 - k * 0.12, 0.4)
				l.prism(at + Vector3(0, -0.06, 0), at + Vector3(0, 0.08, 0), 0.04, 0.03, 6, GLOW_GREEN if k % 2 == 0 else GLOW_VIOLET)),
		"upperarm.l": _mesh("priest_sleeve_up", func(l: LowPoly) -> void: _sleeve(l, 0.25, 0.12, 0.14, VIOLET)),
		"upperarm.r": _mesh("priest_sleeve_up", func(l: LowPoly) -> void: _sleeve(l, 0.25, 0.12, 0.14, VIOLET)),
		"lowerarm.l": _mesh("priest_sleeve_low", func(l: LowPoly) -> void: _sleeve(l, 0.24, 0.14, 0.23, VIOLET, OCHRE)),
		"lowerarm.r": _mesh("priest_sleeve_low", func(l: LowPoly) -> void: _sleeve(l, 0.24, 0.14, 0.23, VIOLET, OCHRE)),
		"hips": _mesh("priest_hips", func(l: LowPoly) -> void:
			_band(l, 0.08, -0.14, Vector2(0.44, 0.38), Vector2(0.5, 0.43), VIOLET, VIOLET_DARK)
			_band(l, 0.08, 0.0, Vector2(0.455, 0.395), Vector2(0.455, 0.395), BRONZE_DARK, BRONZE_DARK.darkened(0.2))
			for k in 3:
				_cell(l, Vector3(-0.15 + k * 0.15, 0.04, 0.4), Vector3(0, 0, 1), 0.035, BRONZE.lightened(0.2))),
		"upperleg.l": _mesh("priest_robe_l", func(l: LowPoly) -> void: _leg_panels(l, 1.0, VIOLET, OCHRE, 0.42, 0.3)),
		"upperleg.r": _mesh("priest_robe_r", func(l: LowPoly) -> void: _leg_panels(l, -1.0, VIOLET, OCHRE, 0.42, 0.3)),
		"handslot.r": _mesh("priest_staff", func(l: LowPoly) -> void:
			# A staff of dark wood, bronze-shod, a copper cage at its head holding the alembic.
			l.prism(Vector3(0, -0.85, 0), Vector3(0, 1.25, 0), 0.035, 0.03, 6, Color(0.3, 0.2, 0.12))
			l.prism(Vector3(0, -0.85, 0), Vector3(0, -0.95, 0), 0.035, 0.0, 5, BRONZE)
			var copper := Color(0.72, 0.38, 0.2)
			for k in 4:
				var a := TAU * k / 4.0
				l.prism(Vector3(0, 1.22, 0), Vector3(cos(a) * 0.14, 1.4, sin(a) * 0.14), 0.015, 0.015, 4, copper)
				l.prism(Vector3(cos(a) * 0.14, 1.4, sin(a) * 0.14), Vector3(0, 1.62, 0), 0.015, 0.015, 4, copper)
			var last := Vector3(0, 1.66, 0)
			for k in 10:
				var a := k * 0.9
				var at := Vector3(cos(a) * 0.08, 1.64 - k * 0.05, sin(a) * 0.08)
				l.prism(last, at, 0.012, 0.012, 4, copper)
				last = at),
		"handslot.r:glow": _mesh("priest_alembic", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 1.28, 0), Vector3(0, 1.42, 0), 0.1, 0.11, 8, GLOW_GREEN)
			l.prism(Vector3(0, 1.42, 0), Vector3(0, 1.52, 0), 0.11, 0.035, 8, GLOW_GREEN.darkened(0.1))
			l.prism(Vector3(0, 1.52, 0), Vector3(0, 1.66, 0), 0.028, 0.024, 6, Color(0.85, 0.95, 0.88))),
	}


static func guardian() -> Dictionary:
	return {
		"head": _mesh("guardian_head", func(l: LowPoly) -> void:
			# A closed bronze helmet over the whole head: cheek guards, a nose guard, a T of dark between,
			# a brow ridge, a neck guard flaring behind.
			l.ovoid(Vector3(0, 0.46, -0.02), Vector3(0.55, 0.55, 0.54), BRONZE, BRONZE_DARK, 6, 16)
			l.box(Vector3(0, 0.03, 0.42), Vector3(0.36, 0.1, 0.12), BRONZE.darkened(0.05)) # the chin, closed under the beard
			_band(l, 0.62, 0.56, Vector2(0.56, 0.55), Vector2(0.56, 0.55), BRONZE_DARK, BRONZE_DARK.darkened(0.2), 0.02)
			l.box(Vector3(0, 0.3, 0.535), Vector3(0.07, 0.36, 0.04), BRONZE.lightened(0.1))
			for side: float in [-1.0, 1.0]:
				l.turned_box(Vector3(side * 0.25, 0.14, 0.45), Vector3(0.24, 0.48, 0.06), BRONZE.lightened(0.05), Basis(Vector3.UP, side * 0.45))
				l.turned_box(Vector3(side * 0.44, 0.16, 0.18), Vector3(0.08, 0.5, 0.42), BRONZE.darkened(0.05), Basis.IDENTITY) # the sides, down past the jaw
				l.box(Vector3(side * 0.17, 0.38, 0.52), Vector3(0.2, 0.06, 0.02), Color(0.05, 0.04, 0.04))
			l.prism(Vector3(0, 0.08, -0.32), Vector3(0, -0.06, -0.42), 0.32, 0.38, 10, BRONZE_DARK)
			# The crest: a bronze holder, and a ridge of plumes front to back, black with white tips.
			l.box(Vector3(0, 1.0, -0.06), Vector3(0.07, 0.07, 0.72), BRONZE_DARK)
			for k in 11:
				var z := 0.3 - k * 0.075
				var tip := Vector3(0, 1.36 - absf(k - 4.0) * 0.03, z - 0.12)
				l.leaf(Vector3(-0.035, 1.02, z), tip, Vector3(0.035, 1.02, z), PLUME_BLACK)
				l.leaf(Vector3(0.035, 1.02, z), tip, Vector3(-0.035, 1.02, z), PLUME_BLACK)
				l.prism(tip + Vector3(0, -0.05, 0.02), tip, 0.03, 0.0, 4, PLUME_WHITE)
			l.prism(Vector3(0, 1.02, -0.44), Vector3(0, 0.5, -0.72), 0.08, 0.03, 6, PLUME_BLACK)),
		"head:glow": _mesh("guardian_eyes", func(l: LowPoly) -> void:
			for x: float in [-0.16, 0.16]:
				l.box(Vector3(x, 0.38, 0.535), Vector3(0.12, 0.035, 0.02), GLOW_VIOLET)),
		"chest": _mesh("guardian_chest", func(l: LowPoly) -> void:
			# The cuirass, its chest worked in muscle, the god's cell at the breastbone; a crimson cloak.
			_band(l, 0.27, -0.5, Vector2(0.37, 0.31), Vector2(0.4, 0.34), BRONZE, BRONZE_DARK)
			_band(l, -0.08, -0.5, Vector2(0.43, 0.37), Vector2(0.41, 0.35), BRONZE, BRONZE_DARK)
			for side: float in [-1.0, 1.0]:
				l.turned_box(Vector3(side * 0.14, 0.08, 0.32), Vector3(0.24, 0.18, 0.05), BRONZE.lightened(0.1), Basis(Vector3.UP, side * 0.35))
				for k in 3:
					l.box(Vector3(side * 0.09, -0.16 - k * 0.1, 0.37), Vector3(0.14, 0.07, 0.04), BRONZE.lightened(0.04))
			_cell(l, Vector3(0, 0.15, 0.33), Vector3(0, 0, 1), 0.05, VIOLET)
			l.turned_box(Vector3(0, -0.3, -0.36), Vector3(0.66, 0.92, 0.035), CRIMSON, Basis(Vector3.RIGHT, -0.12))
			_band(l, 0.3, 0.2, Vector2(0.38, 0.33), Vector2(0.4, 0.35), CRIMSON.darkened(0.15), CRIMSON.darkened(0.3))),
		"upperarm.l": _mesh("guardian_pauldron", func(l: LowPoly) -> void:
			l.ovoid(Vector3(0, 0.05, 0), Vector3(0.15, 0.13, 0.15), BRONZE_DARK, BRONZE_DARK.darkened(0.2), 4, 10)
			_sleeve(l, 0.2, 0.1, 0.105, CRIMSON)),
		"upperarm.r": _mesh("guardian_pauldron", func(l: LowPoly) -> void:
			l.ovoid(Vector3(0, 0.05, 0), Vector3(0.15, 0.13, 0.15), BRONZE_DARK, BRONZE_DARK.darkened(0.2), 4, 10)
			_sleeve(l, 0.2, 0.1, 0.105, CRIMSON)),
		"lowerarm.l": _mesh("guardian_bracer", func(l: LowPoly) -> void: l.prism(Vector3(0, 0.06, 0), Vector3(0, 0.22, 0), 0.11, 0.12, 8, BRONZE)),
		"lowerarm.r": _mesh("guardian_bracer", func(l: LowPoly) -> void: l.prism(Vector3(0, 0.06, 0), Vector3(0, 0.22, 0), 0.11, 0.12, 8, BRONZE)),
		"hips": _mesh("guardian_hips", func(l: LowPoly) -> void:
			# A crimson tunic's hem under a belt, leather strips over it, bronze-studded.
			_band(l, 0.08, -0.16, Vector2(0.42, 0.36), Vector2(0.47, 0.41), CRIMSON, CRIMSON.darkened(0.3))
			_band(l, 0.08, 0.0, Vector2(0.43, 0.37), Vector2(0.43, 0.37), LEATHER, LEATHER.darkened(0.2))
			for k in 14:
				var a := TAU * k / 14.0
				var at := Vector3(sin(a) * 0.46, -0.08, cos(a) * 0.4)
				l.turned_box(at, Vector3(0.11, 0.2, 0.025), LEATHER.lightened(0.07 * (k % 2)), Basis(Vector3.UP, a))
				l.box(at + Vector3(sin(a) * 0.015, -0.07, cos(a) * 0.015), Vector3(0.03, 0.03, 0.03), BRONZE)),
		"lowerleg.l": _mesh("guardian_greave", func(l: LowPoly) -> void:
			l.prism(Vector3(0, -0.04, 0), Vector3(0, 0.13, 0), 0.11, 0.095, 8, BRONZE)
			l.ovoid(Vector3(0, -0.03, -0.08), Vector3(0.08, 0.06, 0.04), BRONZE.lightened(0.1), BRONZE_DARK, 3, 8)),
		"lowerleg.r": _mesh("guardian_greave", func(l: LowPoly) -> void:
			l.prism(Vector3(0, -0.04, 0), Vector3(0, 0.13, 0), 0.11, 0.095, 8, BRONZE)
			l.ovoid(Vector3(0, -0.03, -0.08), Vector3(0.08, 0.06, 0.04), BRONZE.lightened(0.1), BRONZE_DARK, 3, 8)),
		"handslot.r": _mesh("guardian_spear", func(l: LowPoly) -> void:
			l.prism(Vector3(0, -0.8, 0), Vector3(0, 1.35, 0), 0.035, 0.03, 6, Color(0.42, 0.3, 0.18))
			l.prism(Vector3(0, -0.8, 0), Vector3(0, -0.95, 0), 0.04, 0.0, 5, BRONZE_DARK)
			# A broad bronze leaf of a blade, a crimson tassel under it.
			l.prism(Vector3(0, 1.33, 0), Vector3(0, 1.42, 0), 0.045, 0.04, 6, BRONZE_DARK)
			l.turned_box(Vector3(0, 1.58, 0), Vector3(0.12, 0.3, 0.025), BRONZE.lightened(0.15), Basis.IDENTITY)
			l.prism(Vector3(0, 1.73, 0), Vector3(0, 1.86, 0), 0.045, 0.0, 4, BRONZE.lightened(0.25))
			l.prism(Vector3(0, 1.42, 0), Vector3(0, 1.3, 0.04), 0.05, 0.02, 6, CRIMSON)),
		"handslot.l": _mesh("guardian_shield", func(l: LowPoly) -> void:
			# A round bronze shield, rimmed, the god's cell worked large at its middle.
			l.prism(Vector3(0, 0, -0.04), Vector3(0, 0, 0.04), 0.52, 0.52, 18, BRONZE)
			l.prism(Vector3(0, 0, 0.04), Vector3(0, 0, 0.07), 0.52, 0.45, 18, BRONZE.lightened(0.12))
			l.prism(Vector3(0, 0, 0.07), Vector3(0, 0, 0.11), 0.22, 0.18, 6, VIOLET)
			l.prism(Vector3(0, 0, 0.11), Vector3(0, 0, 0.14), 0.12, 0.09, 6, VIOLET.lightened(0.25))
			for k in 6:
				var a := TAU * k / 6.0 + PI / 6.0
				l.prism(Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.06), Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.1), 0.035, 0.02, 5, BRONZE_DARK)),
	}


static func eyes(_model: String) -> Mesh:
	return null # their eyes are in their masks and helmets ("head:glow")
