class_name VaelModels
extends RefCounted
## The drowned of Port Vael and what the Mist Tide brings in with it: low-poly bodies built from code
## on the same parts-on-pivots rigs as the creatures of Mesenlla (MesenllaModels builds, animates and
## fells them through here). Each model is a root facing +Z.
##   brine_hound    a hound that went into the harbour and came back: sleek and eel-dark, finned,
##                  webbed, with gills in its neck and a mouth of needles. Moves as the Mist Wolf does.
##   lantern_jelly  a jelly the size of a man that drifted into the drowned harbour and grew round
##                  one of its lanterns, still lit; it trails stinging threads.
##   angler         a squat fish-thing that lies buried on the shore with only its lure showing,
##                  like a lamp someone left there, and bursts out to bite.
## The Drowned Sailors and the Barnacle Brutes are the drowned themselves, on the game's own bodies,
## dressed by sailor_gear() and brute_gear().

const KINDS := ["brine_hound", "lantern_jelly", "angler"]

const SKIN := Color(0.17, 0.27, 0.31)
const SKIN_DARK := Color(0.09, 0.15, 0.19)
const BELLY := Color(0.46, 0.53, 0.49)
const FIN := Color(0.24, 0.4, 0.42)
const BARNACLE := Color(0.8, 0.76, 0.66)
const BARNACLE_DARK := Color(0.46, 0.43, 0.38)
const KELP := Color(0.24, 0.37, 0.15)
const KELP_DARK := Color(0.15, 0.25, 0.1)
const DROWNED_GLOW := Color(0.55, 1.0, 0.82)
const LURE := Color(1.0, 0.86, 0.5)
const JELLY := Color(0.56, 0.78, 0.92)
const JELLY_RIM := Color(0.86, 0.6, 0.84)
const LANTERN_GLOW := Color(1.0, 0.78, 0.42)
const IRON := Color(0.2, 0.2, 0.22)
const RUST := Color(0.5, 0.27, 0.15)
const TEETH := Color(0.92, 0.9, 0.82)
const CORAL := Color(0.86, 0.42, 0.36)
const CLOTH := Color(0.2, 0.26, 0.36)
const CLOTH_RED := Color(0.55, 0.17, 0.14)
const TAR := Color(0.12, 0.11, 0.1)

const JELLY_FLOAT := 1.7 # how high its bell drifts
const JELLY_THREADS := 8
const ANGLER_BURIED := -0.62 # how far down its body lies, waiting


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	return MesenllaModels._mesh("vael_" + key, build)


## A cluster of barnacles round a point: little cones, open at the top, facing out along `out`.
static func barnacles(l: LowPoly, at: Vector3, out: Vector3, count: int, size: float, rng: RandomNumberGenerator) -> void:
	var n := out.normalized()
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(n).normalized()
	for i in count:
		var p := at + side * rng.randf_range(-1.0, 1.0) * size * 1.6 + up * rng.randf_range(-1.0, 1.0) * size * 1.6
		var r := size * rng.randf_range(0.55, 1.0)
		var shell := BARNACLE.darkened(rng.randf_range(0.0, 0.25))
		l.prism(p - n * r * 0.2, p + n * r * 0.9, r, r * 0.45, 5, shell)
		l.prism(p + n * r * 0.88, p + n * r * 0.95, r * 0.3, r * 0.3, 5, BARNACLE_DARK.darkened(0.4))


## Strands of kelp hanging from a point, swaying a little in their rest pose.
static func kelp(l: LowPoly, at: Vector3, length: float, strands: int, rng: RandomNumberGenerator) -> void:
	for i in strands:
		var p := at + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		var bend := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
		var mid := p + Vector3(0, -length * 0.5, 0) + bend
		var end := p + Vector3(0, -length, 0) + bend * 1.8
		var col := KELP if i % 2 == 0 else KELP_DARK
		l.prism(p, mid, 0.022, 0.018, 3, col)
		l.prism(mid, end, 0.018, 0.004, 3, col.lightened(0.06))
		l.leaf(mid, mid + Vector3(0.07, -0.06, 0), end, col.darkened(0.1))


# --- Brine Hound ------------------------------------------------------------------------------

## Long and low, built for the water: a slick dark hide paling to a grey belly, a ridge of fin along
## its spine, slits of gills behind the jaw, a flat eel's head with a wide mouth full of needles and
## eyes that glow sea-green, webbed paws, a finned tail. Barnacles crust its shoulders and haunches,
## and weed hangs from its belly. Parts as _quadruped wants them (the same as the Mist Wolf's).
static func hound_look() -> Dictionary:
	var skin := SKIN
	return {
		"hip": Vector3(0, 0.6, -0.46), "shoulder": Vector3(0, 0.64, 0.38), "neck": Vector3(0, 0.8, 0.62), "width": 0.15, "upper_len": 0.3, "lower_len": 0.26,
		"jaw_at": Vector3(0, -0.06, 0.1), "tail_at": Vector3(0, 0.66, -0.74),
		"torso": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2301
			l.prism(Vector3(0, 0.66, -0.76), Vector3(0, 0.68, 0.1), 0.16, 0.22, 9, skin) # loins to ribs
			l.prism(Vector3(0, 0.68, 0.1), Vector3(0, 0.72, 0.52), 0.24, 0.18, 9, skin.lightened(0.04)) # the chest
			l.prism(Vector3(0, 0.74, 0.46), Vector3(0, 0.84, 0.66), 0.17, 0.13, 8, skin) # the neck
			# The grey belly along its underside.
			l.prism(Vector3(0, 0.56, -0.6), Vector3(0, 0.55, 0.42), 0.1, 0.15, 7, BELLY)
			# Gill slits behind the jaw, three each side.
			for x: float in [-1.0, 1.0]:
				for g in 3:
					l.box(Vector3(x * 0.15, 0.8 - g * 0.035, 0.6 - g * 0.025), Vector3(0.02, 0.012, 0.09), SKIN_DARK.darkened(0.5), Vector3(0, x * 18.0, 0))
			# The ridge of fin down its spine: spines with a skin stretched between them.
			var spines: Array[Vector3] = []
			for i in 9:
				var z := 0.5 - i * 0.14
				var tall := 0.16 + sin(float(i) / 8.0 * PI) * 0.1
				var base := Vector3(0, 0.88 - absf(z - 0.0) * 0.08, z)
				spines.append(base)
				l.prism(base, base + Vector3(0, tall, -0.06), 0.012, 0.0, 3, SKIN_DARK)
				spines.append(base + Vector3(0, tall, -0.06))
			for i in range(0, spines.size() - 2, 2):
				l.leaf(spines[i], spines[i + 1], spines[i + 2], FIN.darkened(0.1))
				l.leaf(spines[i + 1], spines[i + 3], spines[i + 2], FIN)
			barnacles(l, Vector3(0.18, 0.78, 0.32), Vector3(1, 0.6, 0.2), 5, 0.03, rng)
			barnacles(l, Vector3(-0.17, 0.74, 0.24), Vector3(-1, 0.5, 0.1), 4, 0.028, rng)
			barnacles(l, Vector3(0.16, 0.72, -0.52), Vector3(1, 0.4, -0.3), 4, 0.026, rng)
			kelp(l, Vector3(0.05, 0.47, 0.1), 0.24, 3, rng)
			kelp(l, Vector3(-0.06, 0.48, -0.3), 0.2, 2, rng),
		"head": func(l: LowPoly) -> void:
			# A flat, wide skull running into a long blunt snout.
			l.prism(Vector3(0, 0.03, -0.1), Vector3(0, 0.03, 0.14), 0.14, 0.13, 8, skin)
			l.prism(Vector3(0, 0.02, 0.14), Vector3(0, 0.0, 0.38), 0.12, 0.07, 8, skin.lightened(0.05))
			l.box(Vector3(0, 0.07, 0.12), Vector3(0.2, 0.04, 0.3), SKIN_DARK)
			# Bulging eyes set wide, and nostril pits.
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.1, 0.07, 0.08), Vector3(x * 0.13, 0.09, 0.1), 0.05, 0.04, 6, SKIN_DARK)
				l.box(Vector3(x * 0.03, 0.04, 0.37), Vector3(0.02, 0.015, 0.02), SKIN_DARK.darkened(0.6))
				# A small finned frill where its ears were.
				l.leaf(Vector3(x * 0.11, 0.08, -0.06), Vector3(x * 0.2, 0.18, -0.18), Vector3(x * 0.12, 0.02, -0.16), FIN)
			# The upper teeth, a row of needles.
			for i in 7:
				var a := -0.5 + float(i) / 6.0
				var tip := Vector3(a * 0.13, -0.08, 0.14 + (1.0 - absf(a) * 2.0) * 0.22)
				l.prism(tip + Vector3(0, 0.05, 0), tip, 0.01, 0.0, 3, TEETH),
		"jaw": func(l: LowPoly) -> void:
			l.prism(Vector3(0, -0.01, -0.04), Vector3(0, -0.02, 0.26), 0.1, 0.055, 7, BELLY.darkened(0.15))
			for i in 6:
				var a := -0.5 + float(i) / 5.0
				var gum := Vector3(a * 0.12, 0.01, 0.06 + (1.0 - absf(a) * 2.0) * 0.18)
				l.prism(gum, gum + Vector3(0, 0.06, 0.01), 0.01, 0.0, 3, TEETH),
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.125, 0.085, 0.09), Vector3(x * 0.15, 0.095, 0.1), 0.032, 0.026, 6, DROWNED_GLOW),
		"glow": func(l: LowPoly) -> void:
			# A line of pale lights down each flank, like a deep fish's.
			for x: float in [-1.0, 1.0]:
				for i in 6:
					l.box(Vector3(x * 0.2, 0.64, 0.36 - i * 0.18), Vector3(0.02, 0.025, 0.025), DROWNED_GLOW.darkened(0.15)),
		"tail": func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.06, -0.3), 0.07, 0.04, 6, skin)
			l.prism(Vector3(0, -0.06, -0.3), Vector3(0, -0.1, -0.52), 0.04, 0.012, 5, skin.darkened(0.1))
			# A tall fin above and below, like an eel's.
			l.leaf(Vector3(0, 0.04, -0.08), Vector3(0, 0.14, -0.36), Vector3(0, -0.06, -0.56), FIN)
			l.leaf(Vector3(0, -0.06, -0.12), Vector3(0, -0.2, -0.34), Vector3(0, -0.1, -0.54), FIN.darkened(0.15)),
		"upper_front": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.06, 0), Vector3(0, -0.3, 0.02), 0.07, 0.045, 6, skin),
		"upper_hind": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.08, -0.04), Vector3(0, -0.3, 0.04), 0.1, 0.045, 6, skin),
		"lower": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.02, 0), Vector3(0, -0.26, -0.02), 0.04, 0.03, 6, SKIN_DARK.lightened(0.1)),
		"paw": func(l: LowPoly) -> void:
			# Long webbed toes.
			for c in 3:
				var x := -0.04 + c * 0.04
				l.prism(Vector3(x * 0.5, -0.02, 0.0), Vector3(x, -0.04, 0.12), 0.014, 0.008, 4, SKIN_DARK)
			l.leaf(Vector3(-0.04, -0.04, 0.12), Vector3(0, -0.02, 0.0), Vector3(0.04, -0.04, 0.12), FIN.darkened(0.2))
			l.box(Vector3(0, -0.02, 0.02), Vector3(0.07, 0.04, 0.07), SKIN_DARK),
	}


# --- Lantern Jelly ----------------------------------------------------------------------------

## A bell of pale, half-clear flesh with a frilled rim, and inside it, held in its folds, a ship's
## lantern still burning; under it the frilled mouth-arms and eight long stinging threads, each in
## three joints so they can trail and coil. Nodes:
##   Float > Bell (pulses) > Lantern, Arcs (shown as it stings), Threads > Thread0..7 > Joint > Joint
static func jelly_parts(root: Node3D) -> void:
	var float_node := MesenllaModels._pivot(root, Vector3(0, JELLY_FLOAT, 0), "Float")
	var bell := MesenllaModels._pivot(float_node, Vector3.ZERO, "Bell")
	var flesh := MesenllaModels._part(bell, _mesh("jelly_bell", func(l: LowPoly) -> void:
		# The dome: rings narrowing to its crown, and a frilled, scalloped rim.
		var profile := [Vector2(0.62, 0.0), Vector2(0.64, 0.12), Vector2(0.6, 0.3), Vector2(0.5, 0.46), Vector2(0.34, 0.58), Vector2(0.14, 0.65), Vector2(0.0, 0.67)]
		for i in profile.size() - 1:
			var a: Vector2 = profile[i]
			var b: Vector2 = profile[i + 1]
			l.prism(Vector3(0, a.y, 0), Vector3(0, b.y, 0), a.x, b.x, 12, JELLY.lightened(0.04 * i))
		for i in 12:
			var ang := TAU * (i + 0.5) / 12.0
			var o := Vector3(cos(ang), 0, sin(ang))
			l.leaf(o * 0.6 + Vector3(0, 0.02, 0), o * 0.7 + Vector3(0, -0.12, 0), o.rotated(Vector3.UP, 0.26) * 0.62, JELLY_RIM)
		# Ribs of darker flesh down the dome.
		for i in 8:
			var ang := TAU * i / 8.0
			var o := Vector3(cos(ang), 0, sin(ang))
			l.prism(o * 0.62 + Vector3(0, 0.08, 0), o * 0.2 + Vector3(0, 0.62, 0), 0.025, 0.012, 3, JELLY.darkened(0.2))))
	flesh.material_override = MesenllaModels.ghost_material()
	# The lantern it grew round: an iron frame and cap, glass panes, and the flame.
	MesenllaModels._part(bell, _mesh("jelly_lantern", func(l: LowPoly) -> void:
		for i in 4:
			var ang := TAU * i / 4.0 + PI * 0.25
			var o := Vector3(cos(ang), 0, sin(ang)) * 0.13
			l.prism(o + Vector3(0, 0.06, 0), o + Vector3(0, 0.38, 0), 0.012, 0.012, 4, IRON)
		l.prism(Vector3(0, 0.04, 0), Vector3(0, 0.08, 0), 0.17, 0.17, 4, RUST)
		l.prism(Vector3(0, 0.37, 0), Vector3(0, 0.45, 0), 0.17, 0.08, 4, RUST)
		l.prism(Vector3(0, 0.45, 0), Vector3(0, 0.52, 0), 0.04, 0.04, 6, IRON)
		barnacles(l, Vector3(0.1, 0.42, 0.08), Vector3(0.6, 1, 0.4), 3, 0.018, RandomNumberGenerator.new())), Vector3(0, 0.0, 0))
	var flame := MesenllaModels._part(bell, _mesh("jelly_flame", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.09, 0), Vector3(0, 0.2, 0), 0.05, 0.07, 6, LANTERN_GLOW)
		l.prism(Vector3(0, 0.2, 0), Vector3(0, 0.33, 0), 0.07, 0.0, 6, Color(1.0, 0.95, 0.75))), Vector3.ZERO, "Lantern")
	flame.material_override = MesenllaModels.glow_material()
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = LANTERN_GLOW
	light.light_energy = 0.9
	light.omni_range = 5.0
	light.position = Vector3(0, 0.2, 0)
	light.shadow_enabled = false
	light.visible = Game.quality > 0
	bell.add_child(light)
	# The sting, seen: crackling threads of light round the bell, shown as it stings.
	var arcs := MesenllaModels._part(bell, _mesh("jelly_arcs", func(l: LowPoly) -> void:
		for i in 6:
			var ang := TAU * i / 6.0
			var pts := [Vector3(cos(ang) * 0.5, 0.0, sin(ang) * 0.5), Vector3(cos(ang + 0.2) * 0.75, -0.3, sin(ang + 0.2) * 0.75),
				Vector3(cos(ang - 0.1) * 0.95, -0.6, sin(ang - 0.1) * 0.95), Vector3(cos(ang + 0.15) * 1.1, -0.95, sin(ang + 0.15) * 1.1)]
			for p in 3:
				l.prism(pts[p], pts[p + 1], 0.02, 0.02, 3, Color(0.75, 0.95, 1.0))), Vector3.ZERO, "Arcs")
	arcs.material_override = MesenllaModels.glow_material()
	arcs.visible = false
	# The frilled mouth-arms under the bell.
	var arms := MesenllaModels._part(bell, _mesh("jelly_arms", func(l: LowPoly) -> void:
		for i in 4:
			var ang := TAU * i / 4.0
			var o := Vector3(cos(ang), 0, sin(ang))
			var top := o * 0.08
			var mid := o * 0.16 + Vector3(0, -0.45, 0)
			var low := o * 0.1 + Vector3(0, -0.85, 0)
			l.prism(top, mid, 0.06, 0.05, 5, JELLY_RIM)
			l.prism(mid, low, 0.05, 0.01, 5, JELLY_RIM.lightened(0.1))
			for f in 4:
				var y := -0.15 - f * 0.18
				l.leaf(o * 0.1 + Vector3(0, y, 0), o * 0.24 + Vector3(0, y - 0.08, 0), o.rotated(Vector3.UP, 0.5) * 0.12 + Vector3(0, y - 0.14, 0), JELLY_RIM.darkened(0.1))), Vector3.ZERO, "MouthArms")
	arms.material_override = MesenllaModels.ghost_material()
	# The stinging threads.
	var threads := MesenllaModels._pivot(bell, Vector3.ZERO, "Threads")
	var segment := _mesh("jelly_thread", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, -0.42, 0), 0.016, 0.011, 4, JELLY.lightened(0.2))
		l.box(Vector3(0, -0.2, 0), Vector3(0.03, 0.03, 0.03), DROWNED_GLOW))
	for i in JELLY_THREADS:
		var ang := TAU * i / float(JELLY_THREADS)
		var hang := MesenllaModels._pivot(threads, Vector3(cos(ang) * 0.52, 0.0, sin(ang) * 0.52), "Thread%d" % i)
		hang.rotation.y = -ang
		var at := hang
		for j in 3:
			var piece := MesenllaModels._part(at, segment)
			piece.material_override = MesenllaModels.ghost_material()
			var joint := MesenllaModels._pivot(at, Vector3(0, -0.42, 0), "Joint")
			at = joint


## Drifting: the bell pulsing as it swims, the threads trailing behind and coiling; stinging, the threads
## flare out and the bell crackles with light. Its lantern gutters as it is hurt.
static func animate_jelly(z: Zombie, root: Node3D, delta: float, speed: float, state: String, t: float, act: float) -> void:
	var float_node := root.get_node("Float") as Node3D
	var bell := float_node.get_node("Bell") as Node3D
	var stinging := state == "m_sting"
	var warn := stinging and z.is_warning()
	var beat := t * (2.6 if stinging else 1.6 + speed * 1.2)
	var pulse := sin(beat * TAU * 0.5)
	float_node.position.y = JELLY_FLOAT + sin(t * 0.9) * 0.12 - pulse * 0.05
	# The bell squeezes to push itself along, then opens again.
	var squeeze := maxf(0.0, pulse)
	bell.scale = Vector3(1.0 - squeeze * 0.14, 1.0 + squeeze * 0.12, 1.0 - squeeze * 0.14)
	bell.rotation.x = lerpf(bell.rotation.x, 0.25 * speed, minf(1.0, delta * 3.0))
	bell.rotation.z = sin(t * 0.7) * 0.06
	var arcs := bell.get_node("Arcs") as Node3D
	arcs.visible = (stinging and not warn) or (warn and fmod(act * 9.0, 1.0) > 0.6)
	arcs.rotation.y = floor(t * 14.0) * 1.1
	var light := bell.get_node("Light") as OmniLight3D
	var hurt := clampf(z.hp / maxf(z.max_hp, 1.0), 0.0, 1.0)
	var gutter := 0.75 + 0.25 * sin(t * 13.0) * sin(t * 5.3)
	light.light_energy = (2.4 if stinging and not warn else 0.9) * lerpf(0.5, 1.0, hurt) * gutter
	light.light_color = Color(0.75, 0.95, 1.0) if stinging and not warn else LANTERN_GLOW
	(bell.get_node("Lantern") as Node3D).scale = Vector3.ONE * (0.85 + 0.2 * gutter)
	var threads := bell.get_node("Threads") as Node3D
	threads.rotation.y = sin(t * 0.4) * 0.3
	for i in JELLY_THREADS:
		var at := threads.get_node("Thread%d" % i) as Node3D
		var lag := float(i) * 0.7
		var flare := 0.0
		if stinging:
			flare = 0.4 if warn else 0.95
		var sway := 0.22 + speed * 0.25
		for j in 3:
			# Each joint follows the one above it a beat later, so a wave runs down the thread.
			var bend := sin(beat * TAU * 0.5 - lag - j * 0.9) * sway * (0.6 + j * 0.3)
			var want := -flare * (0.8 if j == 0 else 0.3) + bend - speed * 0.35 * (1.0 if j == 0 else 0.2)
			at.rotation.x = lerpf(at.rotation.x, want, minf(1.0, delta * 6.0))
			at = at.get_node("Joint") as Node3D


# --- Angler -----------------------------------------------------------------------------------

## A squat fish-thing on short webbed legs: a head as big as its body, all mouth, a lower jaw jutting
## past the upper with fangs in both, small mean eyes, spines down its back, long arms with webbed
## claws, barnacles and weed over its hide; from its brow a long stalk ends in a lure that glows like a
## lantern. Nodes: Body > Head > (Jaw, Stalk > Stalk2 > Lure), ArmL, ArmR; LegL, LegR at the hips.
static func angler_parts(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2331
	var body := MesenllaModels._pivot(root, Vector3(0, 0.5, 0), "Body")
	MesenllaModels._part(body, _mesh("angler_body", func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.1, -0.12), Vector3(0, 0.32, 0.02), 0.42, 0.48, 9, SKIN.darkened(0.1))
		l.prism(Vector3(0, -0.12, 0.08), Vector3(0, 0.26, 0.2), 0.3, 0.34, 8, BELLY.darkened(0.1)) # the pale belly
		l.prism(Vector3(0, -0.12, -0.12), Vector3(0, -0.25, -0.1), 0.42, 0.3, 9, SKIN_DARK)
		# Spines and a torn fin down its back.
		var tips: Array[Vector3] = []
		for i in 5:
			var base := Vector3(0, 0.38 - i * 0.1, -0.2 - i * 0.07)
			var tip := base + Vector3(0, 0.26 - i * 0.03, -0.12)
			l.prism(base, tip, 0.02, 0.0, 3, SKIN_DARK)
			tips.append(base)
			tips.append(tip)
		for i in range(0, tips.size() - 2, 2):
			l.leaf(tips[i], tips[i + 1], tips[i + 2], FIN.darkened(0.2))
		# Its stubby tail.
		l.prism(Vector3(0, -0.15, -0.38), Vector3(0, -0.2, -0.62), 0.14, 0.04, 6, SKIN)
		l.leaf(Vector3(0, -0.2, -0.56), Vector3(0, 0.0, -0.78), Vector3(0, -0.38, -0.76), FIN)
		barnacles(l, Vector3(0.3, 0.2, -0.15), Vector3(1, 0.5, -0.4), 6, 0.035, rng)
		barnacles(l, Vector3(-0.26, 0.05, -0.25), Vector3(-1, 0.3, -0.5), 5, 0.03, rng)
		kelp(l, Vector3(-0.2, 0.3, -0.25), 0.35, 3, rng)
		kelp(l, Vector3(0.22, -0.1, 0.0), 0.25, 2, rng)))
	var head := MesenllaModels._pivot(body, Vector3(0, 0.3, 0.16), "Head")
	MesenllaModels._part(head, _mesh("angler_head", func(l: LowPoly) -> void:
		# A great domed head, wider than it is long, its upper jaw lined with fangs.
		l.prism(Vector3(0, -0.05, -0.2), Vector3(0, 0.05, 0.3), 0.42, 0.34, 9, SKIN)
		l.prism(Vector3(0, 0.05, 0.3), Vector3(0, 0.0, 0.44), 0.34, 0.22, 9, SKIN.lightened(0.05))
		l.box(Vector3(0, 0.3, -0.02), Vector3(0.4, 0.12, 0.42), SKIN_DARK)
		for x: float in [-1.0, 1.0]:
			# Small eyes high on the head, sunk in ridges.
			l.prism(Vector3(x * 0.24, 0.26, 0.2), Vector3(x * 0.28, 0.3, 0.26), 0.06, 0.04, 6, SKIN_DARK)
			# Fins where cheeks would be.
			l.leaf(Vector3(x * 0.38, 0.0, -0.05), Vector3(x * 0.62, 0.18, -0.25), Vector3(x * 0.48, -0.2, -0.3), FIN)
		for i in 9:
			var a := -0.5 + float(i) / 8.0
			var gum := Vector3(a * 0.62, -0.18, 0.2 + (1.0 - absf(a) * 2.0) * 0.2)
			var long := 0.12 if i % 2 == 0 else 0.07
			l.prism(gum + Vector3(0, 0.04, 0), gum + Vector3(0, -long, 0.02), 0.022, 0.0, 3, TEETH)
		barnacles(l, Vector3(-0.22, 0.3, -0.12), Vector3(-0.5, 1, -0.3), 5, 0.03, rng)))
	var eyes := MesenllaModels._part(head, _mesh("angler_eyes", func(l: LowPoly) -> void:
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.27, 0.29, 0.25), Vector3(x * 0.29, 0.3, 0.27), 0.03, 0.02, 5, DROWNED_GLOW)))
	eyes.material_override = MesenllaModels.glow_material()
	var jaw := MesenllaModels._pivot(head, Vector3(0, -0.14, -0.12), "Jaw")
	MesenllaModels._part(jaw, _mesh("angler_jaw", func(l: LowPoly) -> void:
		# The underbite: the lower jaw juts out past the upper, fangs pointing up.
		l.prism(Vector3(0, -0.06, 0.0), Vector3(0, -0.1, 0.62), 0.36, 0.26, 8, BELLY.darkened(0.25))
		l.box(Vector3(0, -0.02, 0.36), Vector3(0.5, 0.04, 0.42), Color(0.45, 0.12, 0.14)) # its gullet
		for i in 9:
			var a := -0.5 + float(i) / 8.0
			var gum := Vector3(a * 0.6, -0.02, 0.34 + (1.0 - absf(a) * 2.0) * 0.24)
			var long := 0.15 if i % 2 == 1 else 0.09
			l.prism(gum, gum + Vector3(0, long, 0.03), 0.026, 0.0, 3, TEETH)))
	# The lure: a stalk from its brow in two joints, ending in a glowing bulb with a little light.
	var stalk := MesenllaModels._pivot(head, Vector3(0, 0.34, 0.12), "Stalk")
	MesenllaModels._part(stalk, _mesh("angler_stalk", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, 0.42, 0.1), 0.03, 0.022, 5, SKIN_DARK)))
	var stalk2 := MesenllaModels._pivot(stalk, Vector3(0, 0.42, 0.1), "Stalk2")
	MesenllaModels._part(stalk2, _mesh("angler_stalk2", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, 0.12, 0.34), 0.022, 0.014, 5, SKIN_DARK)))
	var lure := MesenllaModels._pivot(stalk2, Vector3(0, 0.12, 0.34), "Lure")
	var bulb := MesenllaModels._part(lure, _mesh("angler_lure", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.0, 0), Vector3(0, -0.09, 0), 0.03, 0.08, 7, LURE)
		l.prism(Vector3(0, -0.09, 0), Vector3(0, -0.2, 0), 0.08, 0.0, 7, LURE.lightened(0.2))))
	bulb.material_override = MesenllaModels.glow_material()
	var glow := OmniLight3D.new()
	glow.name = "Light"
	glow.light_color = LURE
	glow.light_energy = 1.1
	glow.omni_range = 4.5
	glow.position = Vector3(0, -0.1, 0)
	glow.shadow_enabled = false
	glow.visible = Game.quality > 0
	lure.add_child(glow)
	for side: float in [-1.0, 1.0]:
		var arm := MesenllaModels._pivot(body, Vector3(side * 0.44, 0.12, 0.08), "ArmL" if side < 0 else "ArmR")
		MesenllaModels._part(arm, _mesh("angler_arm", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0.06, -0.3, 0.1), 0.08, 0.06, 6, SKIN)
			l.prism(Vector3(0.06, -0.3, 0.1), Vector3(0.05, -0.58, 0.22), 0.06, 0.045, 6, SKIN.lightened(0.05))
			for c in 3:
				var off := -0.05 + c * 0.05
				l.prism(Vector3(0.05 + off, -0.58, 0.22), Vector3(0.05 + off * 1.6, -0.72, 0.32), 0.016, 0.0, 3, TEETH.darkened(0.2))
			l.leaf(Vector3(0.0, -0.6, 0.22), Vector3(0.12, -0.6, 0.22), Vector3(0.06, -0.7, 0.3), FIN.darkened(0.2))))
		var leg := MesenllaModels._pivot(root, Vector3(side * 0.22, 0.32, -0.05), "LegL" if side < 0 else "LegR")
		MesenllaModels._part(leg, _mesh("angler_leg", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.28, 0.04), 0.1, 0.07, 6, SKIN_DARK)
			l.box(Vector3(0, -0.3, 0.1), Vector3(0.16, 0.04, 0.2), SKIN_DARK)
			l.leaf(Vector3(-0.08, -0.31, 0.2), Vector3(0.08, -0.31, 0.2), Vector3(0, -0.31, 0.02), FIN.darkened(0.2))))


## Lying in wait: its body down in the sand or the mud, only the lure standing up out of it.
static func bury(root: Node3D) -> void:
	var body := root.get_node("Body") as Node3D
	body.position.y = 0.5 + ANGLER_BURIED
	body.rotation.x = 0.0
	for leg: String in ["LegL", "LegR"]:
		(root.get_node(leg) as Node3D).position.y = 0.32 + ANGLER_BURIED - 0.2
	(root.get_node("Body/Head/Jaw") as Node3D).rotation.x = 0.0
	root.set_meta("buried", true)


## Its lure, while it waits: swaying and turning as if hung on a hook, glowing a little brighter now
## and then, the way a lamp does in the wind.
static func lure_idle(root: Node3D, t: float) -> void:
	var stalk := root.get_node("Body/Head/Stalk") as Node3D
	stalk.rotation.x = 0.15 + sin(t * 0.8) * 0.12
	stalk.rotation.z = sin(t * 0.55) * 0.18
	var lure := stalk.get_node("Stalk2/Lure") as Node3D
	lure.rotation.z = sin(t * 1.7) * 0.25
	var light := lure.get_node("Light") as OmniLight3D
	light.light_energy = 1.1 + maxf(0.0, sin(t * 0.9)) * 0.6


## Bursting out of the ground on waking, then a rolling, waddling walk with its arms swinging and the
## lure bobbing ahead; it gapes and lunges to bite.
static func animate_angler(z: Zombie, root: Node3D, delta: float, speed: float, state: String, t: float, act: float) -> void:
	var body := root.get_node("Body") as Node3D
	var head := body.get_node("Head") as Node3D
	var jaw := head.get_node("Jaw") as Node3D
	var arm_l := body.get_node("ArmL") as Node3D
	var arm_r := body.get_node("ArmR") as Node3D
	var leg_l := root.get_node("LegL") as Node3D
	var leg_r := root.get_node("LegR") as Node3D
	var k := minf(1.0, delta * 10.0)
	if root.get_meta("buried", false):
		# Out of the sand in a spray of it.
		var risen := float(root.get_meta("risen", 0.0)) + delta * 2.2
		root.set_meta("risen", risen)
		var up := smoothstep(0.0, 1.0, risen)
		body.position.y = 0.5 + ANGLER_BURIED * (1.0 - up) + sin(up * PI) * 0.35
		body.rotation.x = -sin(up * PI) * 0.4
		jaw.rotation.x = sin(up * PI) * 0.8
		for leg: Node3D in [leg_l, leg_r]:
			leg.position.y = lerpf(0.32 + ANGLER_BURIED - 0.2, 0.32, up)
		if risen >= 1.0:
			root.set_meta("buried", false)
			root.set_meta("risen", 0.0)
		lure_idle(root, t)
		return
	var gait := t * (5.0 + speed * 4.0)
	var waddle := sin(gait) * speed
	body.position.y = lerpf(body.position.y, 0.5 + absf(sin(gait)) * 0.06 * speed, k)
	body.rotation.z = lerpf(body.rotation.z, waddle * 0.16, k)
	body.rotation.x = lerpf(body.rotation.x, 0.1 * speed, k)
	leg_l.rotation.x = sin(gait) * 0.7 * speed
	leg_r.rotation.x = -sin(gait) * 0.7 * speed
	var jaw_want := 0.08 + sin(t * 1.3) * 0.05
	var head_want := 0.0
	var arms_want := -sin(gait) * 0.5 * speed
	match state:
		"m_bite":
			if z.is_warning():
				# Gaping wide, rearing back, arms spread.
				jaw_want = 0.95
				head_want = -0.35
				body.rotation.x = lerpf(body.rotation.x, -0.25, k)
				arms_want = -1.2
			else:
				var snap := clampf(act / 0.25, 0.0, 1.0)
				jaw_want = 0.9 * (1.0 - snap)
				head_want = 0.3 * sin(snap * PI)
				body.rotation.x = lerpf(body.rotation.x, 0.35 * sin(snap * PI), minf(1.0, delta * 20.0))
				arms_want = -0.6
				k = minf(1.0, delta * 20.0)
		"m_swipe":
			arms_want = -1.4 + clampf(act / 0.3, 0.0, 1.0) * 1.8
	jaw.rotation.x = lerpf(jaw.rotation.x, jaw_want, k)
	head.rotation.x = lerpf(head.rotation.x, head_want, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, arms_want, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, -arms_want if state == "" else arms_want, k)
	var stalk := head.get_node("Stalk") as Node3D
	stalk.rotation.x = lerpf(stalk.rotation.x, 0.25 + speed * 0.3 + sin(gait * 0.5) * 0.1, k)
	stalk.rotation.z = sin(t * 0.8) * 0.15
	(stalk.get_node("Stalk2/Lure") as Node3D).rotation.z = sin(gait) * 0.4 * speed + sin(t * 1.7) * 0.2


# --- The drowned (on the game's own bodies) ----------------------------------------------------

## A Drowned Sailor's clothes and growths, bone name -> mesh, in the body's bone space (its head is
## about a metre across): a knitted cap gone green, weed hanging from it and from the shoulders, a
## knotted neckerchief, barnacles on the shoulders, and a coil of rope across the chest.
static func sailor_gear() -> Dictionary:
	return {
		"head": _mesh("sailor_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2341
			l.prism(Vector3(0, 0.62, -0.05), Vector3(0, 1.02, -0.08), 0.6, 0.48, 9, CLOTH.darkened(0.15))
			l.prism(Vector3(0, 0.6, -0.05), Vector3(0, 0.72, -0.05), 0.63, 0.63, 9, CLOTH.lightened(0.05))
			l.prism(Vector3(0, 1.02, -0.08), Vector3(0.1, 1.2, -0.2), 0.2, 0.1, 6, CLOTH.darkened(0.2))
			kelp(l, Vector3(-0.45, 0.75, -0.2), 0.55, 3, rng)
			kelp(l, Vector3(0.4, 0.8, -0.35), 0.45, 2, rng)
			barnacles(l, Vector3(0.38, 0.5, 0.25), Vector3(1, 0.2, 0.6), 4, 0.05, rng)),
		"chest": _mesh("sailor_chest", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2342
			# The neckerchief, knotted at the front.
			l.prism(Vector3(0, 0.36, 0), Vector3(0, 0.26, 0), 0.5, 0.55, 8, CLOTH_RED)
			l.prism(Vector3(0, 0.26, 0.5), Vector3(0.06, 0.0, 0.58), 0.08, 0.02, 4, CLOTH_RED.darkened(0.15))
			# A coil of rope over one shoulder and across.
			for i in 7:
				var a := float(i) / 6.0
				var p0 := Vector3(lerpf(0.5, -0.45, a), lerpf(0.35, -0.3, a), 0.56 - absf(a - 0.5) * 0.25)
				var p1 := Vector3(lerpf(0.5, -0.45, a + 0.16), lerpf(0.35, -0.3, a + 0.16), 0.56 - absf(a + 0.16 - 0.5) * 0.25)
				l.prism(p0, p1, 0.05, 0.05, 5, Color(0.55, 0.45, 0.3).darkened(0.1 * (i % 2)))
			barnacles(l, Vector3(0.5, 0.3, -0.1), Vector3(1, 0.7, 0), 5, 0.05, rng)
			barnacles(l, Vector3(-0.48, 0.25, 0.05), Vector3(-1, 0.6, 0.2), 4, 0.045, rng)
			kelp(l, Vector3(0.45, 0.2, -0.3), 0.5, 3, rng)
			kelp(l, Vector3(-0.4, 0.0, 0.4), 0.4, 2, rng)),
	}


## A Barnacle Brute's crust: thick plates of barnacles and coral grown over its back, shoulders and
## head like armour, weed trailing from them, and a length of anchor chain wound over a shoulder.
## It turns its shell to blows (see ZombieDefs "shell").
static func brute_gear() -> Dictionary:
	return {
		"head": _mesh("brute_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2351
			l.prism(Vector3(0, 0.5, -0.15), Vector3(0, 1.0, -0.25), 0.62, 0.42, 8, BARNACLE_DARK)
			barnacles(l, Vector3(0, 0.95, -0.2), Vector3(0, 1, -0.3), 7, 0.08, rng)
			barnacles(l, Vector3(0.5, 0.7, -0.2), Vector3(1, 0.4, -0.2), 5, 0.07, rng)
			barnacles(l, Vector3(-0.5, 0.7, -0.25), Vector3(-1, 0.4, -0.2), 5, 0.07, rng)
			for i in 3:
				var x := -0.3 + i * 0.3
				l.prism(Vector3(x, 1.0, -0.3), Vector3(x * 1.3, 1.35, -0.45), 0.05, 0.015, 4, CORAL)
				l.prism(Vector3(x * 1.2, 1.2, -0.38), Vector3(x * 1.2 + 0.12, 1.3, -0.4), 0.025, 0.01, 4, CORAL.lightened(0.1))
			kelp(l, Vector3(0, 0.6, -0.55), 0.6, 4, rng)),
		"chest": _mesh("brute_chest", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2352
			# The shell over its back and shoulders.
			l.prism(Vector3(0, 0.55, -0.35), Vector3(0, -0.3, -0.45), 0.75, 0.62, 9, BARNACLE_DARK.darkened(0.1))
			for side: float in [-1.0, 1.0]:
				l.prism(Vector3(side * 0.55, 0.5, -0.05), Vector3(side * 0.85, 0.35, -0.05), 0.32, 0.22, 7, BARNACLE_DARK)
				barnacles(l, Vector3(side * 0.75, 0.55, -0.05), Vector3(side, 0.8, 0), 8, 0.07, rng)
			for i in 14:
				var a := rng.randf_range(-1.2, 1.2)
				var y := rng.randf_range(-0.2, 0.55)
				barnacles(l, Vector3(sin(a) * 0.72, y, -0.35 - cos(a) * 0.32), Vector3(sin(a), 0.2, -cos(a)), 3, 0.07, rng)
			# Anchor chain round one shoulder.
			for i in 9:
				var a := float(i) / 8.0
				var p := Vector3(lerpf(0.65, -0.5, a), lerpf(0.5, -0.25, a), 0.52 - sin(a * PI) * 0.1)
				l.box(p, Vector3(0.14, 0.09, 0.05) if i % 2 == 0 else Vector3(0.05, 0.09, 0.14), IRON.lightened(0.1) if i % 3 else RUST)
			kelp(l, Vector3(0.6, 0.3, -0.3), 0.6, 3, rng)
			kelp(l, Vector3(-0.6, 0.2, -0.3), 0.55, 3, rng)),
	}


## The drowned's eyes: two pale sea-green lights.
static func drowned_eyes() -> Mesh:
	return _mesh("drowned_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.17, 0.17]:
			l.box(Vector3(x, 0.47, 0.62), Vector3(0.12, 0.06, 0.03), DROWNED_GLOW))
