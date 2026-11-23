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

const KINDS := ["brine_hound", "lantern_jelly", "angler", "siren", "kraken_arm", "leviathan"]

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
const ANGLER_BURIED := -1.05 # how far down its body lies, waiting: only the top of its head and its lure show


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


## Dying: the bell crumples and empties, its threads go limp, its lantern gutters out, and what is left
## drifts down onto the sand.
static func fall_jelly(root: Node3D, k: float, delta: float) -> void:
	var float_node := root.get_node("Float") as Node3D
	var bell := float_node.get_node("Bell") as Node3D
	var go := smoothstep(0.0, 1.6, k)
	float_node.position.y = lerpf(float_node.position.y, 0.35, minf(1.0, delta * 1.5))
	bell.scale = Vector3(1.0 + go * 0.35, maxf(0.05, 1.0 - go * 0.85), 1.0 + go * 0.35)
	bell.rotation.x = lerpf(bell.rotation.x, 0.5, minf(1.0, delta * 2.0))
	(bell.get_node("Arcs") as Node3D).visible = k < 0.5 and fmod(k * 11.0, 1.0) > 0.5
	var light := bell.get_node("Light") as OmniLight3D
	light.light_energy = maxf(0.0, 1.4 * (1.0 - k / 1.2)) * (0.7 + 0.3 * sin(k * 37.0))
	(bell.get_node("Lantern") as Node3D).scale = Vector3.ONE * maxf(0.01, 1.0 - k * 0.9)
	var threads := bell.get_node("Threads") as Node3D
	for i in JELLY_THREADS:
		var at := threads.get_node("Thread%d" % i) as Node3D
		for j in 3:
			at.rotation.x = lerpf(at.rotation.x, 0.6 + j * 0.3, minf(1.0, delta * 2.0))
			at = at.get_node("Joint") as Node3D


## Dying: it rears back with its jaws wide, then flops over onto its side, its lure drooping and dimming.
static func fall_angler(root: Node3D, k: float, side: float) -> void:
	var body := root.get_node("Body") as Node3D
	var jaw := root.get_node("Body/Head/Jaw") as Node3D
	var rear := sin(clampf(k / 0.5, 0.0, 1.0) * PI)
	var over := smoothstep(0.35, 1.0, k)
	body.rotation.x = -0.5 * rear
	body.rotation.z = side * 1.4 * over
	body.position.y = 0.5 - 0.15 * over
	jaw.rotation.x = 0.9 * rear + 0.5 * over
	var stalk := root.get_node("Body/Head/Stalk") as Node3D
	stalk.rotation.x = lerpf(0.2, 1.4, over)
	var light := stalk.get_node("Stalk2/Lure/Light") as OmniLight3D
	light.light_energy = maxf(0.0, 1.1 * (1.0 - k / 1.4))
	root.set_meta("buried", false)


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
	var gait := t * (4.0 + speed * 3.0)
	var waddle := sin(gait) * speed
	head.rotation.y = lerpf(head.rotation.y, sin(gait * 0.5) * speed * 0.09, k)
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
				jaw_want = lerpf(0.15, 0.95, smoothstep(0.0, 0.45, act))
				head_want = -0.35 * smoothstep(0.0, 0.4, act)
				body.rotation.x = lerpf(body.rotation.x, -0.25, k)
				arms_want = -1.2
			else:
				var snap := smoothstep(0.03, 0.21, act)
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
	var crust := Color(0.5, 0.5, 0.47)
	return {
		"head": _mesh("brute_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2351
			# A cap of barnacles over the back of its skull, coral growing out of it; the face left bare.
			l.prism(Vector3(0, 0.75, -0.3), Vector3(0, 1.08, -0.42), 0.55, 0.32, 8, crust.darkened(0.15))
			barnacles(l, Vector3(0, 1.0, -0.4), Vector3(0, 1, -0.4), 7, 0.075, rng)
			barnacles(l, Vector3(0.45, 0.8, -0.35), Vector3(1, 0.3, -0.4), 4, 0.065, rng)
			barnacles(l, Vector3(-0.45, 0.8, -0.35), Vector3(-1, 0.3, -0.4), 4, 0.065, rng)
			for i in 3:
				var x := -0.28 + i * 0.28
				l.prism(Vector3(x, 1.0, -0.42), Vector3(x * 1.3, 1.4, -0.58), 0.05, 0.015, 4, CORAL)
				l.prism(Vector3(x * 1.2, 1.22, -0.5), Vector3(x * 1.2 + 0.12, 1.32, -0.52), 0.025, 0.01, 4, CORAL.lightened(0.1))
			kelp(l, Vector3(0.1, 0.75, -0.6), 0.55, 3, rng)),
		"chest": _mesh("brute_chest", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2352
			# The shell over its back and shoulders, white with barnacles, green with weed at the edges.
			l.prism(Vector3(0, 0.5, -0.38), Vector3(0, -0.25, -0.46), 0.7, 0.58, 9, crust.darkened(0.2))
			for side: float in [-1.0, 1.0]:
				l.prism(Vector3(side * 0.5, 0.48, -0.08), Vector3(side * 0.82, 0.34, -0.08), 0.3, 0.2, 7, crust.darkened(0.1))
				barnacles(l, Vector3(side * 0.72, 0.52, -0.08), Vector3(side, 0.8, 0), 9, 0.075, rng)
			for i in 18:
				var a := rng.randf_range(-1.1, 1.1)
				var y := rng.randf_range(-0.15, 0.5)
				barnacles(l, Vector3(sin(a) * 0.66, y, -0.4 - cos(a) * 0.3), Vector3(sin(a), 0.2, -cos(a)), 3, 0.075, rng)
			# Anchor chain over one shoulder and across its chest.
			for i in 9:
				var a := float(i) / 8.0
				var p := Vector3(lerpf(0.62, -0.5, a), lerpf(0.5, -0.22, a), 0.52 - sin(a * PI) * 0.1)
				l.box(p, Vector3(0.14, 0.09, 0.05) if i % 2 == 0 else Vector3(0.05, 0.09, 0.14), IRON.lightened(0.15))
			kelp(l, Vector3(0.62, 0.32, -0.3), 0.6, 3, rng)
			kelp(l, Vector3(-0.62, 0.22, -0.3), 0.55, 3, rng)),
	}


## The drowned's eyes: two pale sea-green lights.
static func drowned_eyes() -> Mesh:
	return _mesh("drowned_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.17, 0.17]:
			l.box(Vector3(x, 0.4, 0.62), Vector3(0.12, 0.06, 0.03), DROWNED_GLOW))


# --- The drowned court (Stage 3) ----------------------------------------------------------------

const GOLD_OLD := Color(0.78, 0.6, 0.24) # gold gone dull in the sea
const VERDIGRIS := Color(0.36, 0.62, 0.52)
const PEARL := Color(0.94, 0.92, 0.86)
const NAVY := Color(0.12, 0.16, 0.26)
const OILSKIN := Color(0.86, 0.68, 0.16)
const ROYAL := Color(0.24, 0.12, 0.3)
const ERMINE := Color(0.78, 0.78, 0.72)
const PALE := Color(0.62, 0.72, 0.7) # a Siren's skin
const SCALES := Color(0.22, 0.42, 0.46)
const SCALES_DARK := Color(0.12, 0.25, 0.3)
const KRAKEN := Color(0.42, 0.16, 0.24)
const KRAKEN_DARK := Color(0.24, 0.08, 0.14)
const SUCKER := Color(0.86, 0.66, 0.62)
const SONG_GLOW := Color(0.62, 1.0, 0.9)
const HOLLOW_GLOW := Color(1.0, 0.82, 0.4)

const SIREN_TAIL := 5
const SIREN_TAIL_LEN := 0.42
const ARM_SEGMENTS := 20
const ARM_SEGMENT := 0.33 # metres each: an arm stands 6.6 m tall
const ARM_BURIED := -6.8 # where it waits, under the sea, before it rises


## The Sunken Crown: a band of sea-dulled gold with points of two heights, each tipped with a pearl,
## coral grown up through it, barnacles on the band, green verdigris in the hollows, and a great green
## stone at the front. `at` is the bottom of the band, `r` its radius.
static func crown(l: LowPoly, at: Vector3, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2401
	var band := r * 0.38
	l.prism(at, at + Vector3.UP * band, r, r * 1.04, 12, GOLD_OLD)
	l.prism(at + Vector3.UP * band * 0.35, at + Vector3.UP * band * 0.62, r * 1.06, r * 1.06, 12, VERDIGRIS.darkened(0.15))
	for i in 8:
		var a := TAU * i / 8.0
		var o := Vector3(sin(a), 0, cos(a))
		var tall := r * (1.0 if i % 2 == 0 else 0.62)
		var base := at + o * r * 1.02 + Vector3.UP * band
		var tip := base + o * r * 0.1 + Vector3.UP * tall
		l.prism(base, tip, r * 0.2, r * 0.02, 4, GOLD_OLD.lightened(0.05 * (i % 2)))
		l.box(tip + Vector3.UP * r * 0.06, Vector3.ONE * r * (0.16 if i % 2 == 0 else 0.11), PEARL)
	# The green stone at the front, in a gold setting.
	l.prism(at + Vector3(0, band * 0.5, r * 1.02), at + Vector3(0, band * 0.5, r * 1.14), r * 0.2, r * 0.14, 6, GOLD_OLD.darkened(0.1))
	l.prism(at + Vector3(0, band * 0.5, r * 1.12), at + Vector3(0, band * 0.5, r * 1.2), r * 0.14, r * 0.06, 6, Color(0.3, 0.95, 0.6))
	# Coral grown up through the band at one side, barnacles on the other.
	for i in 3:
		var a := -2.1 + i * 0.3
		var o := Vector3(sin(a), 0, cos(a))
		var foot := at + o * r * 1.04 + Vector3.UP * band * 0.4
		var top := foot + o * r * 0.2 + Vector3.UP * r * (0.7 + i * 0.15)
		l.prism(foot, top, r * 0.07, r * 0.025, 4, CORAL)
		l.prism(foot.lerp(top, 0.6), foot.lerp(top, 0.6) + o.rotated(Vector3.UP, 0.8) * r * 0.25 + Vector3.UP * r * 0.15, r * 0.04, r * 0.015, 4, CORAL.lightened(0.1))
	barnacles(l, at + Vector3(sin(1.9), 0, cos(1.9)) * r * 1.05 + Vector3.UP * band * 0.5, Vector3(sin(1.9), 0.2, cos(1.9)), 5, r * 0.08, rng)


## Gear for each of the court that walks on the game's own bodies: bone name -> mesh, as ClassGear's.
## A key "bone:glow" is lit from inside (eyes, a lamp's lens). In the bone's own space: its head is
## about a metre across.
static func gear_for(model: String) -> Dictionary:
	match model:
		"press_gang": return press_gear()
		"tide_witch": return witch_gear()
		"harbourmaster": return harbourmaster_gear()
		"lighthouse_keeper": return keeper_gear()
		"hollow_sovereign": return sovereign_gear()
	return {}


const GEARED := ["press_gang", "tide_witch", "harbourmaster", "lighthouse_keeper", "hollow_sovereign"]
## What a hand holds ("handslot.r" gear) is built upright, +Y up, and turned by this to stand upright in
## the hand with the arm at rest (a staff, a trident); what hangs from the fist is built down -Y.
const HELD_TURN := Vector3(0, 0, 1.5)


## A Press Gang man: a tarred round hat with weed hanging from it, a short blue jacket with brass
## buttons over a striped shirt, a cross-belt, and a weighted net bundled on his back, floats and all.
static func press_gear() -> Dictionary:
	return {
		"head": _mesh("press_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2411
			l.prism(Vector3(0, 0.66, -0.04), Vector3(0, 0.72, -0.04), 0.86, 0.86, 12, TAR) # the brim
			l.prism(Vector3(0, 0.72, -0.04), Vector3(0, 1.08, -0.06), 0.58, 0.54, 12, TAR.lightened(0.06))
			l.prism(Vector3(0, 0.78, -0.04), Vector3(0, 0.86, -0.04), 0.6, 0.6, 12, CLOTH_RED.darkened(0.3)) # a ribbon
			kelp(l, Vector3(0.6, 0.66, -0.3), 0.5, 2, rng)
			kelp(l, Vector3(-0.55, 0.66, 0.2), 0.4, 2, rng)
			barnacles(l, Vector3(0.4, 0.95, 0.2), Vector3(0.6, 1, 0.3), 3, 0.05, rng)),
		"chest": _mesh("press_chest", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2412
			# The jacket: open at the front, a collar up at the back.
			for side: float in [-1.0, 1.0]:
				l.box(Vector3(side * 0.34, 0.0, 0.12), Vector3(0.36, 0.86, 0.9), NAVY, Vector3(0, 0, side * -4.0))
				for b in 3:
					l.box(Vector3(side * 0.2, 0.2 - b * 0.22, 0.58), Vector3(0.06, 0.06, 0.04), GOLD_OLD)
			l.box(Vector3(0, 0.36, -0.42), Vector3(0.9, 0.2, 0.12), NAVY.darkened(0.2), Vector3(-15, 0, 0))
			# The shirt between, in stripes.
			for i in 4:
				l.box(Vector3(0, 0.25 - i * 0.18, 0.5), Vector3(0.22, 0.08, 0.04), Color(0.85, 0.83, 0.76) if i % 2 == 0 else Color(0.2, 0.25, 0.42))
			# A cross-belt.
			l.box(Vector3(0, 0.0, 0.6), Vector3(0.12, 1.1, 0.05), Color(0.32, 0.22, 0.14), Vector3(0, 0, 36))
			# The net, bundled on his back: a ball of rope with cork floats and lead weights.
			l.prism(Vector3(0, 0.3, -0.62), Vector3(0, -0.3, -0.7), 0.36, 0.42, 8, Color(0.6, 0.5, 0.34))
			for i in 7:
				var a := TAU * i / 7.0
				l.box(Vector3(cos(a) * 0.4, sin(a) * 0.25, -0.72 + sin(a * 2.0) * 0.08), Vector3(0.09, 0.07, 0.09), Color(0.72, 0.55, 0.3) if i % 2 == 0 else Color(0.3, 0.31, 0.33))
			l.box(Vector3(0.28, 0.42, -0.4), Vector3(0.06, 0.5, 0.06), Color(0.55, 0.45, 0.3), Vector3(0, 0, -30))
			barnacles(l, Vector3(0.5, 0.3, 0.0), Vector3(1, 0.7, 0), 4, 0.05, rng)
			kelp(l, Vector3(-0.5, 0.2, -0.2), 0.45, 2, rng)),
		"hips": _mesh("press_hips", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.12, 0), Vector3(0, 0.0, 0), 0.6, 0.62, 10, Color(0.3, 0.21, 0.13))
			l.box(Vector3(0, 0.06, 0.6), Vector3(0.16, 0.14, 0.05), GOLD_OLD)
			# A cosh at his belt.
			l.prism(Vector3(-0.58, 0.05, 0.1), Vector3(-0.6, -0.5, 0.2), 0.05, 0.1, 6, Color(0.36, 0.25, 0.15))),
	}


## A Tide Witch: long hair of kelp to her waist, a crown of shells and fish bones, a shawl of fishing net
## hung with cork floats and shells over her shoulders, skirts of weed in strips to the ground, and a
## staff of driftwood with a glass fishing float at its head, lit sea-green from inside.
static func witch_gear() -> Dictionary:
	return {
		"head": _mesh("witch_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2421
			# Hair of kelp: over the crown and down her back and sides.
			l.prism(Vector3(0, 0.55, -0.1), Vector3(0, 1.0, -0.12), 0.66, 0.4, 9, KELP_DARK)
			for i in 11:
				var a := lerpf(-2.4, 2.4, float(i) / 10.0)
				var at := Vector3(sin(a) * 0.62, 0.75, cos(a) * 0.5 - 0.15)
				var length := 1.1 + absf(sin(i * 1.7)) * 0.6
				l.prism(at, at + Vector3(sin(a) * 0.15, -length * 0.55, -0.12), 0.07, 0.05, 4, KELP if i % 2 == 0 else KELP_DARK)
				l.prism(at + Vector3(sin(a) * 0.15, -length * 0.55, -0.12), at + Vector3(sin(a) * 0.12, -length, -0.2), 0.05, 0.01, 4, KELP.lightened(0.05))
			# Her crown: shells and the bones of fish, standing up round her head.
			for i in 7:
				var a := lerpf(-1.3, 1.3, float(i) / 6.0)
				var base := Vector3(sin(a) * 0.55, 0.95, cos(a) * 0.45)
				if i % 2 == 0:
					l.prism(base, base + Vector3(sin(a) * 0.1, 0.36 + (0.1 if i == 3 else 0.0), cos(a) * 0.06), 0.1, 0.0, 5, Color(0.9, 0.84, 0.74))
				else:
					l.prism(base, base + Vector3(0, 0.3, 0), 0.02, 0.02, 3, BARNACLE)
					for r in 3:
						l.prism(base + Vector3(0, 0.08 + r * 0.08, 0), base + Vector3(0.12, 0.12 + r * 0.08, 0.02), 0.012, 0.0, 3, BARNACLE)
						l.prism(base + Vector3(0, 0.08 + r * 0.08, 0), base + Vector3(-0.12, 0.12 + r * 0.08, 0.02), 0.012, 0.0, 3, BARNACLE)
			barnacles(l, Vector3(-0.3, 1.0, -0.3), Vector3(-0.4, 1, -0.3), 3, 0.04, rng)),
		"chest": _mesh("witch_chest", func(l: LowPoly) -> void:
			# The shawl of net: a cape of rope mesh over the shoulders, its floats and shells hanging.
			var rope := Color(0.56, 0.48, 0.34)
			l.prism(Vector3(0, 0.38, 0), Vector3(0, -0.25, -0.05), 0.5, 0.82, 10, Color(0.26, 0.3, 0.28))
			for i in 12:
				var a := TAU * i / 12.0
				var top := Vector3(sin(a) * 0.52, 0.36, cos(a) * 0.5)
				var low := Vector3(sin(a) * 0.86, -0.28, cos(a) * 0.82 - 0.05)
				l.prism(top, low, 0.02, 0.02, 3, rope)
				var b := TAU * (i + 1) / 12.0
				l.prism(Vector3(sin(a) * 0.7, 0.05, cos(a) * 0.67), Vector3(sin(b) * 0.7, 0.05, cos(b) * 0.67), 0.016, 0.016, 3, rope)
				l.box(low + Vector3(0, -0.05, 0), Vector3(0.1, 0.08, 0.1), Color(0.72, 0.55, 0.3) if i % 3 == 0 else Color(0.9, 0.84, 0.74))
			# A string of shells across her breast.
			for i in 7:
				var a := lerpf(-1.0, 1.0, float(i) / 6.0)
				l.prism(Vector3(a * 0.4, 0.2 - (1.0 - a * a) * 0.2, 0.62), Vector3(a * 0.4, 0.1 - (1.0 - a * a) * 0.2, 0.66), 0.06, 0.0, 5, Color(0.92, 0.82, 0.74))),
		"hips": _mesh("witch_hips", func(l: LowPoly) -> void:
			# Skirts of weed, in strips to the ground.
			l.prism(Vector3(0, 0.2, 0), Vector3(0, -0.1, 0), 0.6, 0.66, 10, KELP_DARK)
			for i in 14:
				var a := TAU * i / 14.0
				var o := Vector3(sin(a), 0, cos(a))
				var length := 1.15 + absf(sin(i * 2.3)) * 0.25
				l.prism(o * 0.62 + Vector3.UP * 0.05, o * 0.8 + Vector3.UP * (-length * 0.5), 0.12, 0.1, 4, KELP if i % 2 == 0 else KELP_DARK)
				l.prism(o * 0.8 + Vector3.UP * (-length * 0.5), o * 0.86 + Vector3.UP * -length, 0.1, 0.02, 4, KELP.darkened(0.1))),
		"handslot.r": _mesh("witch_staff", func(l: LowPoly) -> void:
			var drift := Color(0.6, 0.55, 0.46)
			l.prism(Vector3(0, -1.6, 0), Vector3(0.04, 0.3, 0), 0.06, 0.07, 5, drift)
			l.prism(Vector3(0.04, 0.3, 0), Vector3(-0.08, 1.1, 0.02), 0.07, 0.05, 5, drift.darkened(0.1))
			# The cage of rope round the float, and shells hung from it.
			for i in 4:
				var a := TAU * i / 4.0
				l.prism(Vector3(-0.08, 1.05, 0.02), Vector3(-0.08 + cos(a) * 0.24, 1.32, 0.02 + sin(a) * 0.24), 0.015, 0.015, 3, Color(0.55, 0.45, 0.3))
				l.prism(Vector3(-0.08 + cos(a) * 0.24, 1.0, 0.02 + sin(a) * 0.24), Vector3(-0.08 + cos(a) * 0.28, 0.82, 0.02 + sin(a) * 0.28), 0.01, 0.01, 3, Color(0.55, 0.45, 0.3))
				l.prism(Vector3(-0.08 + cos(a) * 0.28, 0.82, 0.02 + sin(a) * 0.28), Vector3(-0.08 + cos(a) * 0.28, 0.72, 0.02 + sin(a) * 0.28), 0.05, 0.0, 4, Color(0.9, 0.82, 0.74))),
		"handslot.r:glow": _mesh("witch_float", func(l: LowPoly) -> void:
			l.prism(Vector3(-0.08, 1.12, 0.02), Vector3(-0.08, 1.32, 0.02), 0.2, 0.2, 9, SONG_GLOW.darkened(0.1))
			l.prism(Vector3(-0.08, 1.32, 0.02), Vector3(-0.08, 1.52, 0.02), 0.2, 0.0, 9, SONG_GLOW)
			l.prism(Vector3(-0.08, 1.12, 0.02), Vector3(-0.08, 0.98, 0.02), 0.2, 0.0, 9, SONG_GLOW.darkened(0.2))),
	}


## The Harbourmaster: a peaked cap with a braided band and an anchor badge, grey whiskers, a long navy
## greatcoat, double-breasted with brass buttons and fringed epaulettes, crusted with barnacles at the
## hem; a handbell at his belt; and in his hand the great hook on its chain that he throws.
static func harbourmaster_gear() -> Dictionary:
	return {
		"head": _mesh("harbour_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2431
			l.prism(Vector3(0, 0.7, -0.04), Vector3(0, 1.05, -0.06), 0.6, 0.66, 12, NAVY)
			l.prism(Vector3(0, 1.05, -0.06), Vector3(0, 1.1, -0.06), 0.66, 0.5, 12, NAVY.lightened(0.05))
			l.prism(Vector3(0, 0.7, -0.04), Vector3(0, 0.8, -0.04), 0.62, 0.62, 12, GOLD_OLD) # the braid
			l.box(Vector3(0, 0.66, 0.6), Vector3(0.9, 0.05, 0.4), TAR, Vector3(-12, 0, 0)) # the peak
			# The badge: an anchor in brass.
			l.box(Vector3(0, 0.92, 0.66), Vector3(0.05, 0.2, 0.04), GOLD_OLD)
			l.box(Vector3(0, 0.84, 0.66), Vector3(0.18, 0.04, 0.04), GOLD_OLD)
			l.box(Vector3(0, 1.0, 0.66), Vector3(0.1, 0.04, 0.04), GOLD_OLD)
			# Grey whiskers down his cheeks and a moustache.
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.52, 0.45, 0.32), Vector3(x * 0.5, 0.05, 0.4), 0.14, 0.06, 5, Color(0.7, 0.72, 0.7))
				l.prism(Vector3(x * 0.05, 0.28, 0.66), Vector3(x * 0.32, 0.18, 0.62), 0.07, 0.03, 4, Color(0.72, 0.74, 0.72))
			kelp(l, Vector3(-0.5, 0.75, -0.4), 0.55, 3, rng)
			barnacles(l, Vector3(0.5, 0.95, -0.3), Vector3(1, 0.6, -0.4), 4, 0.05, rng)),
		"chest": _mesh("harbour_chest", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2432
			l.prism(Vector3(0, 0.42, 0), Vector3(0, -0.5, 0), 0.62, 0.68, 10, NAVY)
			l.box(Vector3(0, 0.36, 0.0), Vector3(1.05, 0.2, 0.7), NAVY.lightened(0.04)) # the collar
			for side: float in [-1.0, 1.0]:
				# Epaulettes, gold fringe hanging.
				l.box(Vector3(side * 0.6, 0.42, 0), Vector3(0.36, 0.08, 0.4), GOLD_OLD)
				for f in 5:
					l.prism(Vector3(side * (0.78 + 0.0), 0.4, -0.16 + f * 0.08), Vector3(side * 0.82, 0.22, -0.16 + f * 0.08), 0.016, 0.01, 3, GOLD_OLD.darkened(0.15))
				# Two rows of brass buttons.
				for b in 4:
					l.box(Vector3(side * 0.24, 0.24 - b * 0.22, 0.66), Vector3(0.07, 0.07, 0.04), GOLD_OLD)
			barnacles(l, Vector3(-0.55, -0.3, 0.3), Vector3(-1, 0, 0.4), 6, 0.06, rng)
			kelp(l, Vector3(0.6, 0.1, -0.3), 0.6, 3, rng)),
		"hips": _mesh("harbour_hips", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2433
			# The coat's skirts, to the knee, split at the back.
			l.prism(Vector3(0, 0.15, 0), Vector3(0, -0.85, -0.04), 0.66, 0.8, 10, NAVY)
			l.box(Vector3(0, 0.12, 0.64), Vector3(0.2, 0.14, 0.05), GOLD_OLD)
			l.prism(Vector3(0, 0.15, 0), Vector3(0, 0.05, 0), 0.68, 0.68, 10, Color(0.18, 0.12, 0.08)) # belt
			# The handbell at his belt.
			l.prism(Vector3(0.66, 0.05, 0.1), Vector3(0.7, -0.12, 0.1), 0.03, 0.03, 4, Color(0.32, 0.22, 0.14))
			l.prism(Vector3(0.7, -0.12, 0.1), Vector3(0.72, -0.4, 0.1), 0.06, 0.18, 8, GOLD_OLD.darkened(0.1))
			barnacles(l, Vector3(0.3, -0.8, 0.5), Vector3(0.4, -0.2, 1), 6, 0.06, rng)
			barnacles(l, Vector3(-0.5, -0.75, -0.3), Vector3(-1, -0.2, -0.4), 5, 0.06, rng)),
		"handslot.r": _mesh("harbour_hook", func(l: LowPoly) -> void:
			var iron := Color(0.3, 0.29, 0.28)
			# A few links of chain hanging from his fist, and the hook below them.
			for i in 4:
				var y := -0.12 - i * 0.16
				l.box(Vector3(0, y, 0), Vector3(0.14, 0.16, 0.04) if i % 2 == 0 else Vector3(0.04, 0.16, 0.14), iron)
			l.prism(Vector3(0, -0.72, 0), Vector3(0, -1.3, 0), 0.07, 0.07, 6, iron)
			l.prism(Vector3(0, -1.3, 0), Vector3(0.24, -1.52, 0), 0.07, 0.06, 6, iron)
			l.prism(Vector3(0.24, -1.52, 0), Vector3(0.46, -1.34, 0), 0.06, 0.05, 6, iron)
			l.prism(Vector3(0.46, -1.34, 0), Vector3(0.48, -1.06, 0), 0.05, 0.0, 6, Color(0.55, 0.52, 0.48))),
	}


## The Mad Lighthouse Keeper: a yellow oilskin coat and sou'wester, a wild white beard, round spectacles
## lit by his own lamp, a belt hung with little oil lamps, and on his back, in a brass cage, the great
## lamp of the lighthouse, its lens burning (the lens and the spectacles are "glow").
static func keeper_gear() -> Dictionary:
	return {
		"head": _mesh("keeper_head", func(l: LowPoly) -> void:
			# The sou'wester: a deep crown and a broad brim, longest at the back.
			l.prism(Vector3(0, 0.62, -0.06), Vector3(0, 1.05, -0.1), 0.62, 0.52, 10, OILSKIN)
			l.prism(Vector3(0, 0.6, -0.12), Vector3(0, 0.66, -0.12), 0.95, 0.9, 12, OILSKIN.darkened(0.1))
			l.box(Vector3(0, 0.52, -0.62), Vector3(1.1, 0.06, 0.5), OILSKIN.darkened(0.15), Vector3(25, 0, 0))
			# Wild white hair under it and a long beard.
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.55, 0.62, 0.0), Vector3(x * 0.78, 0.3, -0.1), 0.14, 0.04, 4, Color(0.9, 0.9, 0.86))
			l.prism(Vector3(0, 0.2, 0.5), Vector3(0, -0.7, 0.72), 0.42, 0.06, 7, Color(0.9, 0.9, 0.86))
			l.prism(Vector3(0.2, 0.0, 0.55), Vector3(0.32, -0.5, 0.62), 0.14, 0.02, 5, Color(0.84, 0.84, 0.8))
			l.prism(Vector3(-0.2, 0.0, 0.55), Vector3(-0.34, -0.45, 0.6), 0.14, 0.02, 5, Color(0.84, 0.84, 0.8))
			# The spectacles' wire frames.
			l.box(Vector3(0, 0.42, 0.66), Vector3(0.7, 0.03, 0.03), GOLD_OLD)),
		"head:glow": _mesh("keeper_lenses", func(l: LowPoly) -> void:
			for x: float in [-0.2, 0.2]:
				l.prism(Vector3(x, 0.42, 0.64), Vector3(x, 0.42, 0.68), 0.13, 0.13, 8, Color(1.0, 0.92, 0.6))),
		"chest": _mesh("keeper_chest", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.42, 0), Vector3(0, -0.5, 0), 0.62, 0.7, 10, OILSKIN)
			for b in 4:
				l.box(Vector3(0.12, 0.25 - b * 0.22, 0.66), Vector3(0.08, 0.08, 0.04), Color(0.2, 0.18, 0.15))
			# Straps over the shoulders to the lamp on his back.
			for side: float in [-1.0, 1.0]:
				l.box(Vector3(side * 0.32, 0.1, 0.0), Vector3(0.1, 0.9, 1.36), Color(0.36, 0.24, 0.14))
			# The lamp's brass cage: a base, corner posts and a domed cap with a vent.
			l.prism(Vector3(0, -0.35, -0.95), Vector3(0, -0.22, -0.95), 0.5, 0.5, 8, GOLD_OLD.darkened(0.15))
			for i in 8:
				var a := TAU * i / 8.0
				l.prism(Vector3(cos(a) * 0.46, -0.22, -0.95 + sin(a) * 0.46), Vector3(cos(a) * 0.46, 0.75, -0.95 + sin(a) * 0.46), 0.03, 0.03, 4, GOLD_OLD)
			l.prism(Vector3(0, 0.75, -0.95), Vector3(0, 1.0, -0.95), 0.52, 0.2, 8, GOLD_OLD.darkened(0.1))
			l.prism(Vector3(0, 1.0, -0.95), Vector3(0, 1.18, -0.95), 0.12, 0.08, 6, Color(0.2, 0.18, 0.15))),
		"chest:glow": _mesh("keeper_lens", func(l: LowPoly) -> void:
			# The great lens: rings of glass round the flame, burning yellow-white.
			l.prism(Vector3(0, -0.2, -0.95), Vector3(0, 0.25, -0.95), 0.38, 0.42, 10, Color(1.0, 0.86, 0.45))
			l.prism(Vector3(0, 0.25, -0.95), Vector3(0, 0.72, -0.95), 0.42, 0.36, 10, Color(1.0, 0.92, 0.6))
			l.prism(Vector3(0, 0.05, -0.95), Vector3(0, 0.5, -0.95), 0.1, 0.0, 6, Color(1.0, 1.0, 0.9))),
		"hips": _mesh("keeper_hips", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.15, 0), Vector3(0, -0.95, -0.04), 0.66, 0.84, 10, OILSKIN)
			# Little oil lamps hung from his belt.
			for i in 3:
				var a := -0.9 + i * 0.9
				var at := Vector3(sin(a) * 0.72, -0.1, cos(a) * 0.7)
				l.prism(at, at + Vector3(0, -0.16, 0), 0.02, 0.02, 3, Color(0.3, 0.3, 0.3))
				l.prism(at + Vector3(0, -0.16, 0), at + Vector3(0, -0.4, 0), 0.1, 0.1, 6, Color(1.0, 0.75, 0.35))
				l.prism(at + Vector3(0, -0.4, 0), at + Vector3(0, -0.45, 0), 0.12, 0.12, 6, GOLD_OLD)
			l.prism(Vector3(0, 0.15, 0), Vector3(0, 0.04, 0), 0.68, 0.68, 10, Color(0.32, 0.22, 0.12))),
		"handslot.r": _mesh("keeper_lamp", func(l: LowPoly) -> void:
			# An oil lamp in his fist, ready to throw.
			var brass := GOLD_OLD
			l.prism(Vector3(0, -0.05, 0), Vector3(0, -0.2, 0), 0.03, 0.03, 4, brass)
			l.prism(Vector3(0, -0.2, 0), Vector3(0, -0.28, 0), 0.16, 0.16, 8, brass)
			l.prism(Vector3(0, -0.28, 0), Vector3(0, -0.56, 0), 0.13, 0.13, 8, Color(1.0, 0.8, 0.4))
			l.prism(Vector3(0, -0.56, 0), Vector3(0, -0.64, 0), 0.17, 0.12, 8, brass)),
	}


## The Hollow Sovereign: no face, only the dark of a deep hood and two points of gold light; over it,
## the Sunken Crown. A royal mantle gone purple-black, its ermine yellowed and torn, a chain of office,
## coral grown into great shoulder-pieces, a robe falling to the ground in tatters, and a trident.
static func sovereign_gear() -> Dictionary:
	return {
		"head": _mesh("sovereign_head", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2441
			# The hood, deep, its opening a black hollow where a face should be.
			l.prism(Vector3(0, 0.2, -0.1), Vector3(0, 1.0, -0.2), 0.78, 0.52, 10, ROYAL)
			l.prism(Vector3(0, 1.0, -0.2), Vector3(0, 0.9, -0.7), 0.4, 0.06, 7, ROYAL.darkened(0.15))
			l.box(Vector3(0, 0.45, 0.58), Vector3(0.8, 0.86, 0.12), Color(0.02, 0.02, 0.03))
			for x: float in [-1.0, 1.0]:
				l.box(Vector3(x * 0.46, 0.45, 0.6), Vector3(0.14, 0.95, 0.22), ROYAL.lightened(0.05))
			l.box(Vector3(0, 0.92, 0.6), Vector3(0.92, 0.12, 0.22), ROYAL.lightened(0.05))
			# The Sunken Crown upon it.
			crown(l, Vector3(0, 1.02, 0.0), 0.5)
			kelp(l, Vector3(0.6, 0.6, -0.4), 0.8, 3, rng)
			barnacles(l, Vector3(-0.6, 0.8, -0.3), Vector3(-1, 0.4, -0.3), 5, 0.06, rng)),
		"head:glow": _mesh("sovereign_eyes", func(l: LowPoly) -> void:
			for x: float in [-0.18, 0.18]:
				l.box(Vector3(x, 0.5, 0.66), Vector3(0.08, 0.08, 0.03), HOLLOW_GLOW)),
		"chest": _mesh("sovereign_chest", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2442
			# The mantle, falling from the shoulders to the hips, its trim of old ermine.
			l.prism(Vector3(0, 0.45, -0.02), Vector3(0, -0.6, -0.12), 0.66, 0.92, 10, ROYAL)
			l.prism(Vector3(0, 0.42, 0), Vector3(0, 0.26, 0), 0.72, 0.84, 10, ERMINE)
			for i in 10:
				var a := TAU * i / 10.0
				l.box(Vector3(sin(a) * 0.82, 0.33, cos(a) * 0.8), Vector3(0.05, 0.08, 0.05), Color(0.08, 0.08, 0.08))
			# The chain of office, and its medallion.
			for i in 9:
				var a := lerpf(-1.1, 1.1, float(i) / 8.0)
				l.box(Vector3(sin(a) * 0.55, 0.22 - (1.0 - a * a / 1.21) * 0.32, 0.6 + cos(a) * 0.04), Vector3(0.1, 0.07, 0.04), GOLD_OLD)
			l.prism(Vector3(0, -0.14, 0.62), Vector3(0, -0.14, 0.7), 0.15, 0.15, 8, GOLD_OLD)
			l.prism(Vector3(0, -0.14, 0.7), Vector3(0, -0.14, 0.73), 0.08, 0.08, 6, Color(0.3, 0.95, 0.6))
			# Coral grown into shoulder-pieces.
			for side: float in [-1.0, 1.0]:
				l.prism(Vector3(side * 0.6, 0.4, 0), Vector3(side * 0.95, 0.5, 0), 0.32, 0.2, 7, CORAL.darkened(0.25))
				for c in 4:
					var o := Vector3(side * (0.7 + c * 0.08), 0.55, -0.2 + c * 0.14)
					l.prism(o, o + Vector3(side * 0.12, 0.35 + (c % 2) * 0.15, 0.0), 0.06, 0.015, 4, CORAL)
				barnacles(l, Vector3(side * 0.85, 0.42, 0.1), Vector3(side, 0.5, 0.2), 5, 0.06, rng)
			kelp(l, Vector3(0.0, -0.4, -0.7), 0.7, 4, rng)),
		"hips": _mesh("sovereign_hips", func(l: LowPoly) -> void:
			# The robe, to the ground, rotted into strips at its hem.
			l.prism(Vector3(0, 0.2, 0), Vector3(0, -0.7, -0.04), 0.7, 0.92, 12, ROYAL.darkened(0.1))
			for i in 16:
				var a := TAU * i / 16.0
				var o := Vector3(sin(a), 0, cos(a))
				var length := 0.5 + absf(sin(i * 1.9)) * 0.35
				l.prism(o * 0.88 + Vector3.UP * -0.65, o * 0.98 + Vector3.UP * (-0.65 - length), 0.17, 0.03, 4, ROYAL.darkened(0.2) if i % 2 == 0 else ROYAL)
			for i in 6: # a girdle of gold plates
				var a := TAU * i / 6.0
				l.box(Vector3(sin(a) * 0.72, 0.12, cos(a) * 0.72), Vector3(0.12, 0.08, 0.12), GOLD_OLD)
			l.prism(Vector3(0, 0.16, 0), Vector3(0, 0.08, 0), 0.72, 0.72, 12, GOLD_OLD.darkened(0.3))),
		"handslot.r": _mesh("sovereign_trident", func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2443
			l.prism(Vector3(0, -1.4, 0), Vector3(0, 1.6, 0), 0.05, 0.05, 6, GOLD_OLD.darkened(0.2))
			l.prism(Vector3(0, 1.6, 0), Vector3(0, 1.72, 0), 0.1, 0.12, 6, GOLD_OLD)
			l.prism(Vector3(-0.32, 1.72, 0), Vector3(0.32, 1.72, 0), 0.05, 0.05, 6, GOLD_OLD)
			for x: float in [-0.32, 0.0, 0.32]:
				l.prism(Vector3(x, 1.72, 0), Vector3(x, 2.3 + (0.15 if x == 0.0 else 0.0), 0), 0.045, 0.03, 5, GOLD_OLD)
				l.prism(Vector3(x, 2.3 + (0.15 if x == 0.0 else 0.0), 0), Vector3(x, 2.52 + (0.15 if x == 0.0 else 0.0), 0), 0.06, 0.0, 5, GOLD_OLD.lightened(0.1))
			barnacles(l, Vector3(0, 0.5, 0.05), Vector3(0, 0, 1), 5, 0.04, rng)
			l.prism(Vector3(0.05, 1.3, 0), Vector3(0.25, 1.62, 0), 0.03, 0.01, 4, CORAL)),
	}


## The eyes each of the court shows: the drowned's sea-green, or for the Sovereign none at all (his
## light is in his hood's own "head:glow").
static func court_eyes(model: String) -> Mesh:
	if model == "hollow_sovereign":
		return null
	return drowned_eyes()


# --- Siren ------------------------------------------------------------------------------------

## A Siren: from the waist up a woman drowned long ago, grey-green and thin, ribs and collarbones showing,
## with long fingers webbed to the first joint and black claws; hair of kelp to her waist; a face all
## eyes, which glow pale; at the waist her skin turns to scales and a great eel's tail, finned along its
## top and ending in a fan, carries her over the ground. Weed and shells hang about her.
## Nodes: Body (at the waist) > Torso > Head > (Jaw, Hair), ArmL/ArmR > Fore; Tail0 > Tail1 > ... > Fan;
## Song (rings of light round her while she sings).
static func siren_parts(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2451
	var body := MesenllaModels._pivot(root, Vector3(0, 0.62, 0.1), "Body")
	MesenllaModels._part(body, _mesh("siren_waist", func(l: LowPoly) -> void:
		# The scaled hips, curving back and down into the tail, fins at either side.
		l.prism(Vector3(0, 0.25, 0.0), Vector3(0, -0.15, -0.12), 0.24, 0.3, 9, SCALES)
		l.prism(Vector3(0, -0.15, -0.12), Vector3(0, -0.45, -0.38), 0.3, 0.27, 9, SCALES_DARK)
		for x: float in [-1.0, 1.0]:
			l.leaf(Vector3(x * 0.26, 0.05, -0.05), Vector3(x * 0.6, -0.15, -0.2), Vector3(x * 0.3, -0.3, -0.3), FIN)
		# A belt of shells and weed where skin meets scale.
		for i in 9:
			var a := TAU * i / 9.0
			l.prism(Vector3(sin(a) * 0.25, 0.22, cos(a) * 0.25), Vector3(sin(a) * 0.29, 0.12, cos(a) * 0.29), 0.05, 0.0, 4, Color(0.9, 0.84, 0.76) if i % 2 == 0 else BARNACLE)
		kelp(l, Vector3(0.2, 0.2, 0.15), 0.35, 2, rng)
		kelp(l, Vector3(-0.18, 0.2, -0.1), 0.3, 2, rng)))
	var torso := MesenllaModels._pivot(body, Vector3(0, 0.22, 0), "Torso")
	MesenllaModels._part(torso, _mesh("siren_torso", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.3, 0.02), 0.2, 0.18, 8, PALE)
		l.prism(Vector3(0, 0.3, 0.02), Vector3(0, 0.62, 0.0), 0.18, 0.24, 8, PALE.lightened(0.04))
		l.prism(Vector3(0, 0.62, 0.0), Vector3(0, 0.7, 0.0), 0.24, 0.1, 8, PALE)
		l.prism(Vector3(0, 0.68, 0.0), Vector3(0, 0.82, 0.02), 0.06, 0.055, 6, PALE) # the neck
		# Ribs and collarbones showing through.
		for i in 4:
			var y := 0.32 + i * 0.07
			for x: float in [-1.0, 1.0]:
				l.box(Vector3(x * 0.1, y, 0.17), Vector3(0.12, 0.018, 0.03), PALE.darkened(0.2), Vector3(0, 0, x * -12.0))
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.03, 0.66, 0.1), Vector3(x * 0.2, 0.68, 0.06), 0.018, 0.015, 4, PALE.lightened(0.1))
		# A rag of sail across her, and a string of shells.
		l.prism(Vector3(0, 0.42, 0.02), Vector3(0, 0.56, 0.02), 0.21, 0.23, 8, Color(0.58, 0.6, 0.55))
		for i in 6:
			var a := lerpf(-0.9, 0.9, float(i) / 5.0)
			l.prism(Vector3(a * 0.15, 0.62 - (1.0 - a * a) * 0.08, 0.17), Vector3(a * 0.15, 0.56 - (1.0 - a * a) * 0.08, 0.2), 0.03, 0.0, 4, Color(0.92, 0.84, 0.76))))
	var head := MesenllaModels._pivot(torso, Vector3(0, 0.82, 0.02), "Head")
	MesenllaModels._part(head, _mesh("siren_head", func(l: LowPoly) -> void:
		# A narrow face, hollow cheeks, a long chin.
		l.prism(Vector3(0, -0.02, 0.0), Vector3(0, 0.18, 0.0), 0.1, 0.14, 8, PALE)
		l.prism(Vector3(0, 0.18, 0.0), Vector3(0, 0.3, -0.02), 0.14, 0.08, 8, PALE.lightened(0.05))
		l.box(Vector3(0, 0.12, 0.11), Vector3(0.12, 0.06, 0.04), PALE.darkened(0.1)) # brow
		l.prism(Vector3(0, 0.1, 0.12), Vector3(0, 0.03, 0.15), 0.025, 0.012, 4, PALE.darkened(0.05)) # nose
		for x: float in [-1.0, 1.0]:
			l.box(Vector3(x * 0.055, 0.12, 0.115), Vector3(0.06, 0.035, 0.02), Color(0.04, 0.06, 0.08)) # deep sockets
			# Fins where her ears were.
			l.leaf(Vector3(x * 0.12, 0.14, -0.02), Vector3(x * 0.26, 0.26, -0.12), Vector3(x * 0.14, 0.04, -0.1), FIN.lightened(0.1))))
	var eyes := MesenllaModels._part(head, _mesh("siren_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.055, 0.055]:
			l.box(Vector3(x, 0.12, 0.125), Vector3(0.035, 0.022, 0.012), SONG_GLOW)))
	eyes.material_override = MesenllaModels.glow_material()
	var jaw := MesenllaModels._pivot(head, Vector3(0, 0.03, 0.04), "Jaw")
	MesenllaModels._part(jaw, _mesh("siren_jaw", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.0, 0.0), Vector3(0, -0.06, 0.08), 0.07, 0.035, 6, PALE)
		l.box(Vector3(0, 0.0, 0.08), Vector3(0.06, 0.012, 0.02), Color(0.2, 0.05, 0.08))))
	# Hair of kelp, strands from her crown down her back to her waist, on its own pivot to sway.
	var hair := MesenllaModels._pivot(head, Vector3(0, 0.26, -0.04), "Hair")
	MesenllaModels._part(hair, _mesh("siren_hair", func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.04, 0.02), Vector3(0, 0.04, -0.04), 0.15, 0.12, 8, KELP_DARK)
		for i in 13:
			var a := lerpf(-2.2, 2.2, float(i) / 12.0)
			var at := Vector3(sin(a) * 0.13, 0.0, cos(a) * 0.08 - 0.08)
			var length := 0.7 + absf(sin(i * 2.1)) * 0.35
			var mid := at + Vector3(sin(a) * 0.08, -length * 0.5, -0.1)
			l.prism(at, mid, 0.035, 0.03, 4, KELP if i % 2 == 0 else KELP_DARK)
			l.prism(mid, mid + Vector3(sin(a) * 0.04, -length * 0.5, -0.04), 0.03, 0.006, 4, KELP.lightened(0.06))))
	for side: float in [-1.0, 1.0]:
		var arm := MesenllaModels._pivot(torso, Vector3(side * 0.22, 0.62, 0.0), "ArmL" if side > 0 else "ArmR")
		MesenllaModels._part(arm, _mesh("siren_upper", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.34, 0.02), 0.06, 0.045, 6, PALE)))
		var fore := MesenllaModels._pivot(arm, Vector3(0, -0.34, 0.02), "Fore")
		MesenllaModels._part(fore, _mesh("siren_fore", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.32, 0.04), 0.045, 0.035, 6, PALE)
			# The hand: long fingers, webbed, black claws.
			for f in 4:
				var x := -0.045 + f * 0.03
				l.prism(Vector3(x * 0.5, -0.32, 0.04), Vector3(x, -0.5, 0.08), 0.012, 0.008, 3, PALE.darkened(0.08))
				l.prism(Vector3(x, -0.5, 0.08), Vector3(x * 1.1, -0.58, 0.12), 0.008, 0.0, 3, Color(0.08, 0.08, 0.1))
			l.leaf(Vector3(-0.045, -0.46, 0.08), Vector3(0.045, -0.46, 0.08), Vector3(0, -0.33, 0.05), FIN.lightened(0.15))))
	# The tail: from behind her hips, along the ground, each joint a little thinner, to its fan.
	var at := root
	var where := Vector3(0, 0.22, -0.36)
	for i in SIREN_TAIL:
		var seg := MesenllaModels._pivot(at, where, "Tail%d" % i)
		var r0 := 0.27 - i * 0.045
		var r1 := 0.27 - (i + 1) * 0.045
		MesenllaModels._part(seg, _mesh("siren_tail%d" % i, func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, 0, -SIREN_TAIL_LEN), r0, r1, 8, SCALES if i % 2 == 0 else SCALES.darkened(0.08))
			l.prism(Vector3(0, -r0 * 0.4, 0), Vector3(0, -r1 * 0.4, -SIREN_TAIL_LEN), r0 * 0.7, r1 * 0.7, 6, BELLY)
			# A fin along its top.
			l.leaf(Vector3(0, r0 * 0.9, 0.0), Vector3(0, r0 * 0.9 + 0.12, -SIREN_TAIL_LEN * 0.5), Vector3(0, r1 * 0.9, -SIREN_TAIL_LEN), FIN)))
		at = seg
		where = Vector3(0, 0, -SIREN_TAIL_LEN)
	var fan := MesenllaModels._pivot(at, where, "Fan")
	MesenllaModels._part(fan, _mesh("siren_fan", func(l: LowPoly) -> void:
		l.leaf(Vector3.ZERO, Vector3(-0.42, 0.1, -0.45), Vector3(0, 0.0, -0.28), FIN.lightened(0.05))
		l.leaf(Vector3.ZERO, Vector3(0, 0.0, -0.28), Vector3(0.42, 0.1, -0.45), FIN)
		for x: float in [-0.25, 0.0, 0.25]:
			l.prism(Vector3.ZERO, Vector3(x * 1.4, 0.05, -0.42), 0.012, 0.004, 3, SCALES_DARK)))
	# Her song, seen: rings of pale light that swell out from her while she sings.
	var song := MesenllaModels._pivot(root, Vector3(0, 1.55, 0.1), "Song")
	for i in 3:
		var ring := MesenllaModels._part(song, _mesh("siren_ring", func(l: LowPoly) -> void:
			for s in 18:
				var a := TAU * s / 18.0
				var b := TAU * (s + 1) / 18.0
				if s % 3 == 2:
					continue
				l.prism(Vector3(cos(a), 0, sin(a)) * 0.5, Vector3(cos(b), 0, sin(b)) * 0.5, 0.02, 0.02, 3, SONG_GLOW)), Vector3.ZERO, "Ring%d" % i)
		ring.material_override = MesenllaModels.glow_material()
		ring.rotation.x = PI * 0.5 - 0.25 + i * 0.25
	song.visible = false
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = SONG_GLOW
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	light.visible = Game.quality > 0
	song.add_child(light)


## Sliding over the ground on her tail, which swings from side to side in a wave down its length; her
## body sways above it and her hair streams. Singing: she draws breath first, head back and arms
## lifting (the tell), then sings with her arms spread and her head up, jaw open, rings of light
## swelling out from her. A blow is a rake of her claws, left and right in turn.
static func animate_siren(z: Zombie, root: Node3D, delta: float, speed: float, state: String, t: float, act: float) -> void:
	var body := root.get_node("Body") as Node3D
	var torso := body.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var jaw := head.get_node("Jaw") as Node3D
	var hair := head.get_node("Hair") as Node3D
	var arm_l := torso.get_node("ArmL") as Node3D
	var arm_r := torso.get_node("ArmR") as Node3D
	var song := root.get_node("Song") as Node3D
	var k := minf(1.0, delta * 8.0)
	var wave := t * (2.2 + speed * 4.0)
	# The tail's wave, stronger when she moves.
	var at := root.get_node("Tail0") as Node3D
	for i in SIREN_TAIL:
		at.rotation.y = lerpf(at.rotation.y, sin(wave - i * 0.72) * (0.08 + speed * 0.18) * (0.65 + i * 0.13), k)
		at.rotation.x = lerpf(at.rotation.x, 0.05 if i == 0 else 0.0, k)
		if i < SIREN_TAIL - 1:
			at = at.get_node("Tail%d" % (i + 1)) as Node3D
	(at.get_node("Fan") as Node3D).rotation.y = sin(wave - SIREN_TAIL * 0.9) * 0.4
	body.rotation.z = lerpf(body.rotation.z, sin(wave - 0.8) * 0.06 * (0.3 + speed), k)
	body.position.y = 0.62 + sin(t * 1.4) * 0.025
	hair.rotation.x = lerpf(hair.rotation.x, 0.15 + speed * 0.35 + sin(t * 1.1) * 0.06, k)
	hair.rotation.z = sin(t * 0.8) * 0.08
	var torso_x := 0.08 * speed
	var head_x := 0.0
	var jaw_x := 0.05
	var al := Vector3(0.2 + sin(wave) * 0.2 * speed, 0, -0.15)
	var ar := Vector3(0.2 - sin(wave) * 0.2 * speed, 0, 0.15)
	var fore := -0.4
	var singing := 0.0
	match state:
		"m_song":
			if z.is_warning():
				# Drawing breath: head back, arms rising.
				var up := clampf(act / VaelMind.SONG_TELL, 0.0, 1.0)
				torso_x = -0.25 * up
				head_x = -0.45 * up
				al = Vector3(-1.2 * up, 0, -0.5 * up)
				ar = Vector3(-1.2 * up, 0, 0.5 * up)
				fore = -0.2
				singing = 0.2 * up
			else:
				torso_x = -0.18 + sin(t * 3.0) * 0.04
				head_x = -0.3 + sin(t * 2.2) * 0.08
				jaw_x = 0.55 + sin(t * 9.0) * 0.12
				al = Vector3(-1.4, 0, -1.1)
				ar = Vector3(-1.4, 0, 1.1)
				fore = -0.15
				singing = 1.0
		"m_swipe":
			var swipes := int(root.get_meta("swipes", 0))
			var rake := smoothstep(0.09, 0.34, act)
			var arm := Vector3(lerpf(-2.4, 0.4, rake), 0, 0.0)
			if swipes % 2 == 0:
				ar = arm + Vector3(0, 0, lerpf(0.6, -0.5, rake))
			else:
				al = arm + Vector3(0, 0, lerpf(-0.6, 0.5, rake))
			torso_x = 0.25 * sin(rake * PI)
			jaw_x = 0.4
			fore = -0.6
	torso.rotation.x = lerpf(torso.rotation.x, torso_x, k)
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
	jaw.rotation.x = lerpf(jaw.rotation.x, jaw_x, minf(1.0, delta * 14.0))
	arm_l.rotation = arm_l.rotation.lerp(al, k)
	arm_r.rotation = arm_r.rotation.lerp(ar, k)
	(arm_l.get_node("Fore") as Node3D).rotation.x = lerpf((arm_l.get_node("Fore") as Node3D).rotation.x, fore, k)
	(arm_r.get_node("Fore") as Node3D).rotation.x = lerpf((arm_r.get_node("Fore") as Node3D).rotation.x, fore, k)
	song.visible = singing > 0.05
	(song.get_node("Light") as OmniLight3D).light_energy = singing * (1.6 + sin(t * 6.0) * 0.4)
	for i in 3:
		var ring := song.get_node("Ring%d" % i) as Node3D
		var grow := fmod(t * 0.9 + i / 3.0, 1.0)
		ring.scale = Vector3.ONE * (0.6 + grow * 3.2) * maxf(singing, 0.3)
		ring.visible = singing > 0.5 or i == 0
		ring.rotation.y = t * (0.6 + i * 0.3)


## Dying: she shrieks with her arms flung up, then falls back across her own tail and lies still, her
## eyes going dark; the tail curls once and lies flat.
static func fall_siren(root: Node3D, k: float, side: float) -> void:
	var body := root.get_node("Body") as Node3D
	var torso := body.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var rear := sin(clampf(k / 0.5, 0.0, 1.0) * PI)
	var over := smoothstep(0.3, 1.1, k)
	torso.rotation.x = -0.4 * rear - 1.2 * over
	torso.rotation.z = side * 0.3 * over
	body.position.y = 0.62 - 0.35 * over
	head.rotation.x = -0.6 * rear + 0.3 * over
	(head.get_node("Jaw") as Node3D).rotation.x = 0.7 * rear + 0.3 * over
	(torso.get_node("ArmL") as Node3D).rotation = Vector3(-2.2 * rear, 0, -1.4 * over)
	(torso.get_node("ArmR") as Node3D).rotation = Vector3(-2.2 * rear, 0, 1.4 * over)
	(root.get_node("Song") as Node3D).visible = false
	var at := root.get_node("Tail0") as Node3D
	for i in SIREN_TAIL:
		at.rotation.y = side * sin(clampf(k / 0.9, 0.0, 1.0) * PI) * 0.35 * (1.0 - over * 0.5)
		if i < SIREN_TAIL - 1:
			at = at.get_node("Tail%d" % (i + 1)) as Node3D


# --- Kraken's Arm ----------------------------------------------------------------------------

## One great arm of the kraken, standing out of the sea: twelve joints, thick and dark red-purple at its
## root and tapering to a curling tip, pale underneath with rows of suckers along its inner side (the
## side toward you). Where it comes out of the water, a ring of churned foam. Nodes: Arm (lifted out
## of the sea as it rises) > Seg0 > Seg1 > ... > Seg11; Foam.
static func kraken_parts(root: Node3D) -> void:
	var foam_mesh := _mesh("kraken_foam", func(l: LowPoly) -> void:
		for i in 16:
			var a := TAU * i / 16.0
			var b := TAU * (i + 1) / 16.0
			l.prism(Vector3(cos(a), 0, sin(a)) * 1.35, Vector3(cos(b), 0, sin(b)) * 1.35, 0.18, 0.18, 4, Color(0.86, 0.94, 0.92))
			l.prism(Vector3(cos(a), 0, sin(a)) * 1.8, Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * 2.1, 0.12, 0.0, 3, Color(0.78, 0.88, 0.86)))
	var foam := MesenllaModels._part(root, foam_mesh, Vector3(0, 0.05, 0), "Foam")
	foam.material_override = MesenllaModels.ghost_material()
	var arm := MesenllaModels._pivot(root, Vector3.ZERO, "Arm")
	var at := arm
	var where := Vector3(0, -0.3, 0)
	for i in ARM_SEGMENTS:
		var seg := MesenllaModels._pivot(at, where, "Seg%d" % i)
		var r0 := lerpf(0.82, 0.06, pow(float(i) / ARM_SEGMENTS, 0.72))
		var r1 := lerpf(0.82, 0.06, pow(float(i + 1) / ARM_SEGMENTS, 0.72))
		MesenllaModels._part(seg, _mesh("kraken_seg%d" % i, func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, ARM_SEGMENT, 0), r0, r1, 9, KRAKEN if i % 2 == 0 else KRAKEN.darkened(0.06))
			# The pale underside, and its suckers, toward +Z.
			l.prism(Vector3(0, 0, r0 * 0.45), Vector3(0, ARM_SEGMENT, r1 * 0.45), r0 * 0.62, r1 * 0.62, 7, SUCKER.darkened(0.15))
			for s in 2:
				var y := ARM_SEGMENT * (0.25 + s * 0.5)
				var r := lerpf(r0, r1, 0.25 + s * 0.5)
				for x: float in [-0.35, 0.35]:
					var p := Vector3(x * r, y, r * 0.98)
					l.prism(p, p + Vector3(0, 0, r * 0.14), r * 0.2, r * 0.17, 7, SUCKER)
					l.prism(p + Vector3(0, 0, r * 0.13), p + Vector3(0, 0, r * 0.15), r * 0.1, r * 0.1, 6, KRAKEN_DARK)
			# Raised dorsal ridges, scarred hide and a translucent cutting fin along the tip.
			l.prism(Vector3(0,0,-r0), Vector3(0,ARM_SEGMENT,-r1),r0*0.1,r1*0.08,5,KRAKEN_DARK)
			if i > 13:
				l.leaf(Vector3(0,0,-r0),Vector3(0,ARM_SEGMENT*0.45,-r0*2.5),Vector3(0,ARM_SEGMENT,-r1),CORAL.darkened(0.2))
			for scar in 2:
				l.prism(Vector3(r0*0.8,ARM_SEGMENT*(0.2+scar*0.4),-r0*0.4),Vector3(r0*0.6,ARM_SEGMENT*(0.4+scar*0.4),-r0*0.7),0.014,0.006,3,SUCKER.darkened(0.35))
			# Darker blotches on its back.
			if i % 3 == 1:
				l.box(Vector3(r0 * 0.3, ARM_SEGMENT * 0.5, -r0 * 0.85), Vector3(r0 * 0.6, ARM_SEGMENT * 0.4, 0.04), KRAKEN_DARK)
			if i < 3:
				var rng := RandomNumberGenerator.new()
				rng.seed = 2461 + i
				barnacles(l, Vector3(-r0 * 0.7, ARM_SEGMENT * 0.5, -r0 * 0.6), Vector3(-1, 0, -0.8), 4, 0.06, rng)))
		at = seg
		where = Vector3(0, ARM_SEGMENT, 0)
	arm.position.y = ARM_BURIED


## Each frame: rising out of the sea or sinking back into it, swaying and curling where it stands;
## rearing back high before a slam (the tell) and whipping down to the ground in front of it; sweeping
## round low across the water close by.
static func animate_kraken(z: Zombie, root: Node3D, delta: float, state: String, t: float, act: float) -> void:
	var arm := root.get_node("Arm") as Node3D
	var foam := root.get_node("Foam") as Node3D
	foam.rotation.y = t * 0.6
	foam.scale = Vector3.ONE * (1.0 + sin(t * 2.3) * 0.06)
	var k := minf(1.0, delta * 9.0)
	var up := 1.0
	match state:
		"m_rise": up = smoothstep(0.0, VaelMind.RISE_TIME, act)
		"m_sink": up = 1.0 - smoothstep(0.0, VaelMind.SINK_TIME, act)
	arm.position.y = lerpf(ARM_BURIED, -0.3, up)
	var at := arm.get_node("Seg0") as Node3D
	for i in ARM_SEGMENTS:
		var f := float(i) / ARM_SEGMENTS
		# Standing: a slow wave runs up it and the tip curls over toward you.
		var want_x := sin(t * 1.5 - i * 0.36) * (0.025 + f * 0.035) + f * f * 0.17
		var want_z := sin(t * 1.1 - i * 0.28) * (0.02 + f * 0.04)
		match state:
			"m_slam":
				if z.is_warning():
					# Reared back and up, coiled to strike.
					var coil := clampf(act / maxf(VaelMind.KRAKEN_TELL - 0.25, 0.1), 0.0, 1.0)
					want_x = lerpf(want_x, -0.22 + f * 0.35 if i > 2 else -0.1, coil)
					want_z = sin(t * 7.0 - i) * 0.03 * coil
				else:
					# Down it comes, flat along the ground in front.
					var whip := clampf(act / 0.18, 0.0, 1.0)
					want_x = lerpf(-0.2, (0.21 if i < 6 else 0.015) - (0.0 if f < 0.8 else 0.08), whip)
					want_z = 0.0
					k = minf(1.0, delta * 26.0)
			"m_swipe":
				var sweep := clampf(act / 0.45, 0.0, 1.0)
				want_x = 0.16 if i < 6 else 0.06
				want_z = (0.22 if i < 5 else 0.05) * lerpf(-1.0, 1.0, sweep)
				k = minf(1.0, delta * 18.0)
			"m_rise", "m_sink":
				want_x = sin(t * 4.0 - i * 0.6) * 0.15
		at.rotation.x = lerpf(at.rotation.x, want_x, k)
		at.rotation.z = lerpf(at.rotation.z, want_z, k)
		if i < ARM_SEGMENTS - 1:
			at = at.get_node("Seg%d" % (i + 1)) as Node3D


## Dying: it shudders, goes limp, and falls over sideways into the water, then sinks.
static func fall_kraken(root: Node3D, k: float, side: float) -> void:
	var arm := root.get_node("Arm") as Node3D
	var limp := smoothstep(0.15, 1.2, k)
	arm.rotation.z = side * 1.35 * limp
	arm.position.y = -0.3 - smoothstep(1.4, 2.6, k) * 3.5
	var at := arm.get_node("Seg0") as Node3D
	for i in ARM_SEGMENTS:
		at.rotation.x = sin(k * 30.0 - i) * 0.08 * (1.0 - limp) + 0.04 * limp
		at.rotation.z = side * 0.06 * limp
		if i < ARM_SEGMENTS - 1:
			at = at.get_node("Seg%d" % (i + 1)) as Node3D
	(root.get_node("Foam") as Node3D).scale = Vector3.ONE * (1.0 + k * 0.4)


# --- The Leviathan of the Mists ----------------------------------------------------------------

const LEVI_SEGMENTS := 9
const LEVI_SEGMENT := 1.1
const LEVI_BURIED := -13.0
const LEVI_SCALES := Color(0.13, 0.27, 0.3)
const LEVI_DARK := Color(0.07, 0.15, 0.18)
const LEVI_BELLY := Color(0.62, 0.7, 0.6)
const LEVI_FIN := Color(0.22, 0.48, 0.5)
const LEVI_EYE := Color(0.6, 1.0, 0.85)


## The Leviathan of the Mists: a sea serpent vast enough to wrap the Isle of Lamps. Out of the water
## stands its neck, thick as a tower at the sea and narrowing to its head, dark sea-green scales on its
## back with a crest of torn fins, pale and ridged beneath (+Z, toward you); its head long as a boat,
## a jaw lined with teeth, frills behind, and eyes lit like drowned lanterns. Behind it two coils of
## its body break the water. Nodes: Body (lifted out of the sea as it rises) > Neck0 > ... > Neck8 >
## Head > Jaw; Coils; Foam.
static func leviathan_parts(root: Node3D) -> void:
	var foam_mesh := _mesh("levi_foam", func(l: LowPoly) -> void:
		for i in 20:
			var a := TAU * i / 20.0
			var b := TAU * (i + 1) / 20.0
			l.prism(Vector3(cos(a), 0, sin(a)) * 2.2, Vector3(cos(b), 0, sin(b)) * 2.2, 0.25, 0.25, 4, Color(0.86, 0.94, 0.92))
			l.prism(Vector3(cos(a), 0, sin(a)) * 3.0, Vector3(cos(a + 0.15), 0, sin(a + 0.15)) * 3.6, 0.16, 0.0, 3, Color(0.78, 0.88, 0.86)))
	var foam := MesenllaModels._part(root, foam_mesh, Vector3(0, 0.05, 0), "Foam")
	foam.material_override = MesenllaModels.ghost_material()
	var coils := MesenllaModels._pivot(root, Vector3.ZERO, "Coils")
	MesenllaModels._part(coils, _mesh("levi_coils", func(l: LowPoly) -> void:
		# Two arches of its body out of the water behind it, finned along the top.
		for c: Vector3 in [Vector3(-2.0, 0, -6.5), Vector3(2.5, 0, -12.0)]:
			var r := 2.6 if c.z > -8.0 else 2.1
			var thick := 0.95 if c.z > -8.0 else 0.8
			for k in 8:
				var a0 := PI * k / 8.0
				var a1 := PI * (k + 1) / 8.0
				var p0 := c + Vector3(cos(a0) * r, sin(a0) * r - 0.6, 0)
				var p1 := c + Vector3(cos(a1) * r, sin(a1) * r - 0.6, 0)
				l.prism(p0, p1, thick, thick, 8, LEVI_SCALES if k % 2 == 0 else LEVI_SCALES.darkened(0.08))
				if k > 0 and k < 7:
					var top := c + Vector3(cos((a0 + a1) * 0.5) * (r + thick * 0.9), sin((a0 + a1) * 0.5) * (r + thick * 0.9) - 0.6, 0)
					l.leaf(top, top + Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0) * 0.8, top + Vector3(0, 0, 0.5), LEVI_FIN)))
	# A continuous articulated tail replaces the disconnected rear silhouette.
	var tail_parent := coils
	for i in 16:
		var tail := MesenllaModels._pivot(tail_parent, Vector3(0, 0, -0.85) if i > 0 else Vector3(0, 0.1, -3.5), "SeaTail%d" % i)
		var r := lerpf(0.85, 0.035, float(i)/16)
		MesenllaModels._part(tail, _mesh("sea_tail%d" % i, func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0,0,-0.9),r,r*0.85,10,LEVI_SCALES)
			l.leaf(Vector3(0,r,0),Vector3(0,r+0.55,-0.45),Vector3(0,r*0.8,-0.9),LEVI_FIN)
			if i == 15:
				for side: float in [-1,1]: l.leaf(Vector3.ZERO,Vector3(side*1.3,0.3,-1.2),Vector3(side*0.3,0,-0.6),LEVI_FIN)))
		tail_parent = tail
	var body := MesenllaModels._pivot(root, Vector3(0, LEVI_BURIED, 0), "Body")
	var at := body
	var where := Vector3(0, -0.6, 0)
	for i in LEVI_SEGMENTS:
		var seg := MesenllaModels._pivot(at, where, "Neck%d" % i)
		var r0 := lerpf(1.3, 0.72, float(i) / LEVI_SEGMENTS)
		var r1 := lerpf(1.3, 0.72, float(i + 1) / LEVI_SEGMENTS)
		MesenllaModels._part(seg, _mesh("levi_neck%d" % i, func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, LEVI_SEGMENT, 0), r0, r1, 10, LEVI_SCALES if i % 2 == 0 else LEVI_SCALES.darkened(0.06))
			# Its pale ridged throat toward +Z.
			l.prism(Vector3(0, 0.0, r0 * 0.5), Vector3(0, LEVI_SEGMENT, r1 * 0.5), r0 * 0.6, r1 * 0.6, 8, LEVI_BELLY.darkened(0.05 * (i % 2)))
			l.box(Vector3(0, LEVI_SEGMENT * 0.5, r0 * 0.98), Vector3(r0 * 0.9, 0.08, 0.06), LEVI_BELLY.darkened(0.2))
			# Scales: darker plates down its sides.
			for x: float in [-1.0, 1.0]:
				l.box(Vector3(x * r0 * 0.8, LEVI_SEGMENT * 0.5, -r0 * 0.3), Vector3(0.08, LEVI_SEGMENT * 0.7, r0 * 0.8), LEVI_DARK, Vector3(0, x * 20.0, 0))
			# The crest of fins down its back (-Z).
			l.leaf(Vector3(0, 0.0, -r0 * 0.95), Vector3(0, LEVI_SEGMENT * 0.6, -r0 - 0.9 + i * 0.05), Vector3(0, LEVI_SEGMENT, -r1 * 0.95), LEVI_FIN)
			if i < 3:
				var rng := RandomNumberGenerator.new()
				rng.seed = 2601 + i
				barnacles(l, Vector3(r0 * 0.7, LEVI_SEGMENT * 0.5, -r0 * 0.5), Vector3(1, 0, -0.6), 6, 0.08, rng)
				kelp(l, Vector3(-r0 * 0.8, LEVI_SEGMENT, 0), 0.9, 3, rng)))
		at = seg
		where = Vector3(0, LEVI_SEGMENT, 0)
	var head := MesenllaModels._pivot(at, where, "Head")
	MesenllaModels._part(head, _mesh("levi_head", func(l: LowPoly) -> void:
		# The skull, its long snout forward (+Z), brow ridges, nostrils.
		l.prism(Vector3(0, 0.1, -0.6), Vector3(0, 0.2, 0.6), 0.85, 0.8, 9, LEVI_SCALES)
		l.prism(Vector3(0, 0.2, 0.6), Vector3(0, 0.05, 2.8), 0.8, 0.32, 9, LEVI_SCALES.lightened(0.04))
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.5, 0.75, -0.2), Vector3(x * 0.45, 0.6, 1.2), 0.2, 0.08, 5, LEVI_DARK) # brow
			l.box(Vector3(x * 0.2, 0.32, 2.65), Vector3(0.1, 0.06, 0.12), Color(0.02, 0.04, 0.05)) # nostril
			# Frills behind the jaw, and swept-back horns.
			l.leaf(Vector3(x * 0.7, 0.2, -0.4), Vector3(x * 1.9, 0.9, -1.4), Vector3(x * 1.2, -0.5, -1.0), LEVI_FIN.lightened(0.08))
			l.prism(Vector3(x * 0.5, 0.75, -0.5), Vector3(x * 0.9, 1.6, -2.0), 0.14, 0.02, 5, BARNACLE)
			# The upper teeth.
			for k in 7:
				var z := 0.6 + k * 0.32
				var w := lerpf(0.72, 0.34, float(k) / 7.0)
				l.prism(Vector3(x * w, -0.2, z), Vector3(x * w * 0.95, -0.55, z + 0.05), 0.07, 0.0, 4, Color(0.9, 0.88, 0.8))
		l.prism(Vector3(0, -0.25, 0.4), Vector3(0, -0.2, 2.6), 0.6, 0.22, 8, Color(0.3, 0.06, 0.08)))) # the mouth's dark
	var eyes := MesenllaModels._part(head, _mesh("levi_eyes", func(l: LowPoly) -> void:
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.68, 0.48, 0.5), Vector3(x * 0.76, 0.48, 0.5), 0.2, 0.2, 8, LEVI_EYE)))
	eyes.material_override = MesenllaModels.glow_material()
	var jaw := MesenllaModels._pivot(head, Vector3(0, -0.15, -0.3), "Jaw")
	MesenllaModels._part(jaw, _mesh("levi_jaw", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.0, 0.0), Vector3(0, -0.2, 2.6), 0.68, 0.24, 8, LEVI_BELLY.darkened(0.15))
		for x: float in [-1.0, 1.0]:
			for k in 6:
				var z := 0.8 + k * 0.3
				var w := lerpf(0.6, 0.28, float(k) / 6.0)
				l.prism(Vector3(x * w, 0.05, z), Vector3(x * w * 0.95, 0.4, z + 0.05), 0.06, 0.0, 4, Color(0.9, 0.88, 0.8))))
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = LEVI_EYE
	light.light_energy = 1.4
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.visible = Game.quality > 0
	light.position = Vector3(0, 0.6, 1.0)
	head.add_child(light)


## Each frame: rising out of the sea or sinking, swaying where it stands and watching you; rearing
## back before it strikes (the tell) and striking down to the ground in front of it, jaws snapping;
## lifting its head and spitting the sea (m_breath).
static func animate_leviathan(z: Zombie, root: Node3D, delta: float, state: String, t: float, act: float) -> void:
	var body := root.get_node("Body") as Node3D
	var foam := root.get_node("Foam") as Node3D
	foam.rotation.y = t * 0.4
	foam.scale = Vector3.ONE * (1.0 + sin(t * 1.8) * 0.05)
	var up := 1.0
	match state:
		"m_rise": up = smoothstep(0.0, VaelMind.RISE_TIME, act)
		"m_sink": up = 1.0 - smoothstep(0.0, VaelMind.SINK_TIME, act)
	body.position.y = lerpf(LEVI_BURIED, 0.0, up)
	(root.get_node("Coils") as Node3D).position.y = lerpf(-4.0, 0.0, up)
	var tail := root.get_node("Coils/SeaTail0") as Node3D
	for i in 16:
		tail.rotation.y = sin(t*1.7-i*0.4)*(0.08+float(i)*0.007)
		tail.rotation.x = sin(t*1.2-i*0.35)*0.045
		if i < 15: tail = tail.get_node("SeaTail%d" % (i+1)) as Node3D
	var k := minf(1.0, delta * 6.0)
	var head_x := 0.25
	var jaw_x := 0.1 + sin(t * 1.3) * 0.05
	var at := body.get_node("Neck0") as Node3D
	for i in LEVI_SEGMENTS:
		var f := float(i) / LEVI_SEGMENTS
		var want_x := sin(t * 0.9 - i * 0.4) * 0.05 + (0.06 if i > 5 else 0.0)
		var want_z := sin(t * 0.7 - i * 0.3) * 0.05
		match state:
			"m_slam":
				if z.is_warning():
					var coil := clampf(act / maxf(VaelMind.BITE_TELL_L - 0.3, 0.1), 0.0, 1.0)
					want_x = lerpf(want_x, -0.12 if i < 6 else 0.2, coil)
					head_x = lerpf(0.25, 0.9, coil)
					jaw_x = lerpf(0.1, 0.9, coil)
				else:
					var strike := clampf(act / 0.2, 0.0, 1.0)
					want_x = lerpf(-0.12, 0.2 if i < 7 else 0.05, strike)
					head_x = lerpf(0.9, 0.2, strike)
					jaw_x = lerpf(0.9, 0.0, clampf((act - 0.15) / 0.1, 0.0, 1.0))
					k = minf(1.0, delta * 22.0)
			"m_bite":
				var strike := clampf(act / 0.2, 0.0, 1.0)
				want_x = lerpf(-0.12, 0.2 if i < 7 else 0.05, strike)
				head_x = lerpf(0.9, 0.2, strike)
				jaw_x = lerpf(0.9, 0.0, clampf((act - 0.15) / 0.1, 0.0, 1.0))
				k = minf(1.0, delta * 22.0)
			"m_breath":
				var rear := sin(clampf(act / 1.0, 0.0, 1.0) * PI)
				want_x = -0.06 * rear + 0.03
				head_x = -0.5 * rear + 0.2
				jaw_x = 1.0 * rear
			"m_rise", "m_sink":
				want_x = sin(t * 3.0 - i * 0.6) * 0.08
				jaw_x = 0.6
		at.rotation.x = lerpf(at.rotation.x, want_x, k)
		at.rotation.z = lerpf(at.rotation.z, want_z, k)
		at = at.get_node("Neck%d" % (i + 1)) as Node3D if i < LEVI_SEGMENTS - 1 else at
	var head := at.get_node("Head") as Node3D
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
	var jaw := head.get_node("Jaw") as Node3D
	jaw.rotation.x = lerpf(jaw.rotation.x, jaw_x, minf(1.0, delta * 14.0))


## Dying: it screams with its jaws wide, sways, and falls slowly sideways across the water, then sinks.
static func fall_leviathan(root: Node3D, k: float, side: float) -> void:
	var body := root.get_node("Body") as Node3D
	var fall := smoothstep(0.4, 2.2, k)
	body.rotation.z = side * 1.3 * fall
	body.position.y = -smoothstep(2.4, 4.0, k) * 9.0
	var at := body.get_node("Neck0") as Node3D
	for i in LEVI_SEGMENTS:
		at.rotation.x = sin(k * 9.0 - i) * 0.05 * (1.0 - fall)
		at = at.get_node("Neck%d" % (i + 1)) as Node3D if i < LEVI_SEGMENTS - 1 else at
	var jaw := at.get_node("Head/Jaw") as Node3D
	jaw.rotation.x = 1.0 * (1.0 - smoothstep(1.2, 2.4, k))
	(root.get_node("Coils") as Node3D).position.y = -smoothstep(1.0, 3.0, k) * 4.0
	(root.get_node("Foam") as Node3D).scale = Vector3.ONE * (1.0 + k * 0.5)
