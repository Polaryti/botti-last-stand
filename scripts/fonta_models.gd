class_name FontaModels
extends RefCounted
## The mutants of Fontanova, made wrong by Al'quimelea, god of change: every one of them carries the
## god's mark somewhere, a swelling or a seam that glows violet or green. Built of shared cached meshes
## on articulated pivots, +Z forward; the moves run on every phone from the state the host sends
## (Zombie._current_anim and the warning).
##   mutant_bee      a bee the size of a dog: amber fur, a striped abdomen with one swollen glowing
##                   segment, four wings blurring, a stinger that curls forward before it dives.
##   beehive         a great comb grown over a broken olive stump, dripping honey, its cells glowing
##                   where the god touched it, with bees circling it.
##   mutant_wasp     long, red and black, waisted like a blade, jaws like shears; it arches its
##                   abdomen under itself to shoot its stinger.
##   mutant_snail    a snail as big as a boar, its shell grown into a spiral of crystal seams that
##                   glow with what it leaves behind: green poison or ember fire.
##   wasp_hive_snail a snail carrying a grey paper wasps' nest for a shell, wasps crawling out of it.
##   mutant_spider   a long-legged spider with a swollen violet-marked abdomen and a crown of eyes;
##                   it clings to a tree trunk head down, then drops.
##   battle_ostrich  an ostrich in a war-harness of bronze plates and red cloth, a spiked brow plate,
##                   kicking and charging.
##   ember_moth      a moth with a wingspan wider than a man, eye-spots on its wings, shedding burning
##                   dust.
##   thornback       a tortoise as big as a cart, its shell grown into limestone thorns, moss in its
##                   seams; its beak snaps.

const KINDS := ["mutant_bee", "beehive", "mutant_wasp", "mutant_snail", "wasp_hive_snail", "mutant_spider", "battle_ostrich", "ember_moth", "thornback"]
const FLYERS := ["mutant_bee", "mutant_wasp", "ember_moth"]
const SNAILS := ["mutant_snail", "wasp_hive_snail"]

const AMBER := Color(0.85, 0.56, 0.16)
const AMBER_DARK := Color(0.48, 0.28, 0.08)
const BLACK := Color(0.07, 0.06, 0.07)
const YELLOW := Color(0.95, 0.78, 0.16)
const WING := Color(0.78, 0.84, 0.9)
const EYE := Color(0.32, 0.08, 0.12)
const GOD := Color(0.72, 0.4, 1.0) # Al'quimelea's violet
const GOD_GREEN := Color(0.4, 1.0, 0.62)
const WASP_RED := Color(0.62, 0.13, 0.08)
const COMB := Color(0.86, 0.62, 0.2)
const COMB_DARK := Color(0.55, 0.36, 0.12)
const HONEY := Color(1.0, 0.72, 0.12)
const BARK := Color(0.33, 0.29, 0.24)
const SNAIL_SKIN := Color(0.52, 0.47, 0.38)
const SNAIL_SHELL := Color(0.58, 0.44, 0.3)
const PAPER := Color(0.6, 0.58, 0.54)
const SPIDER := Color(0.16, 0.13, 0.12)
const SPIDER_HAIR := Color(0.3, 0.24, 0.2)
const OSTRICH := Color(0.12, 0.1, 0.1)
const PLUME := Color(0.92, 0.9, 0.85)
const OSTRICH_SKIN := Color(0.78, 0.52, 0.48)
const BRONZE := Color(0.5, 0.36, 0.16)
const CLOTH := Color(0.62, 0.1, 0.1)
const MOTH := Color(0.42, 0.36, 0.3)
const MOTH_DUST := Color(0.95, 0.55, 0.2)
const SHELL := Color(0.4, 0.36, 0.26)
const LIMESTONE := Color(0.74, 0.7, 0.62)
const MOSS := Color(0.3, 0.38, 0.18)


static func _pivot(parent: Node3D, at: Vector3, label: String) -> Node3D:
	return MesenllaModels._pivot(parent, at, label)


static func _part(parent: Node3D, key: String, draw: Callable, lit := false) -> MeshInstance3D:
	var mi := MesenllaModels._part(parent, MesenllaModels._mesh("fonta_" + key, draw))
	if lit:
		mi.material_override = MesenllaModels.glow_material()
	return mi


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", id)
	match id:
		"mutant_bee": _bee(root)
		"beehive": _hive(root)
		"mutant_wasp": _wasp(root)
		"mutant_snail": _snail(root, false)
		"wasp_hive_snail": _snail(root, true)
		"mutant_spider": _spider(root)
		"battle_ostrich": _ostrich(root)
		"ember_moth": _moth(root)
		"thornback": _thornback(root)
	return root


# --- Bees and wasps ------------------------------------------------------------------------------

## A pair of insect wings on a pivot, side -1 or 1, length long.
static func _wings(rig: Node3D, key: String, at: Vector3, long: float, back: bool) -> void:
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(rig, at, ("WingL" if side < 0 else "WingR") + ("2" if back else ""))
		_part(wing, "%s_wing_%s_%s" % [key, back, side], func(l: LowPoly) -> void:
			var tip := Vector3(side * long, 0.04, -long * (0.55 if back else 0.35))
			l.leaf(Vector3.ZERO, tip, Vector3(side * long * 0.45, 0.0, -long * (0.75 if back else 0.6)), WING)
			l.leaf(Vector3.ZERO, Vector3(side * long * 0.6, 0.02, long * 0.08), tip, WING.lightened(0.08))
			# Veins.
			l.prism(Vector3.ZERO, tip * 0.95, 0.008, 0.004, 3, Color(0.3, 0.28, 0.25))
			l.prism(Vector3.ZERO, Vector3(side * long * 0.45, 0.0, -long * (0.72 if back else 0.56)), 0.007, 0.003, 3, Color(0.3, 0.28, 0.25)))


## Six legs hanging under a thorax, on a pivot so they can tuck and reach.
static func _six_legs(rig: Node3D, key: String, at: Vector3, long: float, col: Color) -> void:
	var legs := _pivot(rig, at, "Legs")
	_part(legs, key + "_legs", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var hip := Vector3(side * 0.08, 0, 0.08 - k * 0.09)
				var knee := hip + Vector3(side * long * 0.45, -long * 0.2, (0.06 - k * 0.07))
				var foot := knee + Vector3(side * long * 0.1, -long * 0.55, -0.05 - k * 0.04)
				l.prism(hip, knee, 0.022, 0.016, 4, col)
				l.prism(knee, foot, 0.016, 0.008, 4, col.lightened(0.1)))


static func _bee(root: Node3D) -> void:
	var rig := _pivot(root, Vector3(0, 0.55, 0), "Rig")
	# The thorax: a ball of amber fur, tufted.
	_part(rig, "bee_thorax", func(l: LowPoly) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 71
		FontaFlora.clump(l, Vector3.ZERO, 0.24, 0.9, AMBER, r, 9)
		for k in 14:
			var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 1), r.randf_range(-1, 1)).normalized()
			l.prism(dir * 0.18, dir * 0.27, 0.035, 0.0, 3, AMBER.lightened(0.15) if k % 2 else AMBER_DARK))
	var head := _pivot(rig, Vector3(0, 0.02, 0.24), "Head")
	_part(head, "bee_head", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.04), Vector3(0, -0.02, 0.12), 0.15, 0.1, 8, BLACK)
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * 0.1, 0.02, 0.0), Vector3(side * 0.12, 0.0, 0.1), 0.08, 0.06, 7, EYE) # compound eyes
			l.prism(Vector3(side * 0.04, 0.1, 0.08), Vector3(side * 0.12, 0.28, 0.2), 0.012, 0.01, 3, BLACK) # antennae
			l.prism(Vector3(side * 0.12, 0.28, 0.2), Vector3(side * 0.14, 0.26, 0.28), 0.01, 0.006, 3, BLACK)
			l.prism(Vector3(side * 0.04, -0.08, 0.1), Vector3(side * 0.01, -0.12, 0.17), 0.025, 0.008, 4, AMBER_DARK)) # mandibles
	_part(head, "bee_eyeshine", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.16, 0.04, 0.06), Vector3(0.02, 0.05, 0.05), GOD), true)
	# The abdomen: striped segments, one swollen and glowing where the god changed it, the stinger.
	var abdomen := _pivot(rig, Vector3(0, -0.02, -0.18), "Abdomen")
	_part(abdomen, "bee_abdomen", func(l: LowPoly) -> void:
		var widths := [0.2, 0.25, 0.28, 0.26, 0.2, 0.12]
		for k in widths.size():
			var z0 := -k * 0.1
			l.prism(Vector3(0, -k * 0.025, z0), Vector3(0, -(k + 1) * 0.025, z0 - 0.1), widths[k], widths[mini(k + 1, widths.size() - 1)] if k < widths.size() - 1 else 0.06, 9, YELLOW if k % 2 == 0 else BLACK)
		l.prism(Vector3(0, -0.15, -0.6), Vector3(0, -0.2, -0.76), 0.035, 0.0, 5, BLACK))
	_part(abdomen, "bee_swelling", func(l: LowPoly) -> void:
		l.prism(Vector3(0.12, -0.06, -0.22), Vector3(0.16, -0.07, -0.34), 0.11, 0.08, 7, GOD)
		l.box(Vector3(-0.16, -0.06, -0.3), Vector3(0.02, 0.06, 0.12), GOD_GREEN), true)
	_wings(rig, "bee", Vector3(0, 0.18, 0.04), 0.55, false)
	_wings(rig, "bee", Vector3(0, 0.17, -0.06), 0.38, true)
	_six_legs(rig, "bee", Vector3(0, -0.14, 0.02), 0.36, BLACK)


static func _wasp(root: Node3D) -> void:
	var rig := _pivot(root, Vector3(0, 0.55, 0), "Rig")
	_part(rig, "wasp_thorax", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.1), Vector3(0, 0.02, 0.16), 0.14, 0.12, 8, BLACK)
		l.prism(Vector3(0, 0.06, -0.05), Vector3(0, 0.08, 0.1), 0.1, 0.08, 7, WASP_RED)
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.1, 0.06, 0.04), Vector3(0.04, 0.05, 0.12), YELLOW))
	var head := _pivot(rig, Vector3(0, 0.03, 0.2), "Head")
	_part(head, "wasp_head", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.03), Vector3(0, -0.03, 0.12), 0.12, 0.1, 8, YELLOW)
		l.box(Vector3(0, 0.04, 0.06), Vector3(0.12, 0.05, 0.08), BLACK)
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * 0.09, 0.02, 0.02), Vector3(side * 0.1, 0.0, 0.1), 0.06, 0.04, 6, BLACK)
			l.prism(Vector3(side * 0.04, 0.08, 0.06), Vector3(side * 0.16, 0.3, 0.12), 0.012, 0.008, 3, BLACK)
			# Shear jaws.
			l.prism(Vector3(side * 0.05, -0.07, 0.1), Vector3(side * 0.0, -0.1, 0.22), 0.03, 0.008, 4, WASP_RED.darkened(0.3)))
	_part(head, "wasp_eyeshine", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.125, 0.03, 0.06), Vector3(0.015, 0.04, 0.04), GOD), true)
	# The waist, a thread; the abdomen hangs from it on its own pivot, so it can arch forward.
	var abdomen := _pivot(rig, Vector3(0, -0.02, -0.14), "Abdomen")
	_part(abdomen, "wasp_abdomen", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, -0.02, -0.12), 0.03, 0.03, 5, BLACK)
		var widths := [0.12, 0.17, 0.18, 0.16, 0.12, 0.07]
		for k in widths.size():
			var z0 := -0.12 - k * 0.09
			l.prism(Vector3(0, -0.02 - k * 0.02, z0), Vector3(0, -0.04 - k * 0.02, z0 - 0.09), widths[k], widths[mini(k + 1, widths.size() - 1)] if k < widths.size() - 1 else 0.04, 8, YELLOW if k % 2 else WASP_RED.darkened(0.1 * k))
		l.prism(Vector3(0, -0.15, -0.66), Vector3(0, -0.18, -0.86), 0.03, 0.0, 5, BLACK))
	_part(abdomen, "wasp_venom", func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.12, -0.6), Vector3(0, -0.14, -0.66), 0.06, 0.03, 6, GOD_GREEN), true)
	_wings(rig, "wasp", Vector3(0, 0.12, 0.06), 0.6, false)
	_wings(rig, "wasp", Vector3(0, 0.11, -0.04), 0.42, true)
	_six_legs(rig, "wasp", Vector3(0, -0.1, 0.03), 0.42, Color(0.75, 0.55, 0.12))


static func _moth(root: Node3D) -> void:
	var rig := _pivot(root, Vector3(0, 0.6, 0), "Rig")
	_part(rig, "moth_body", func(l: LowPoly) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 91
		FontaFlora.clump(l, Vector3(0, 0, 0.05), 0.17, 1.0, MOTH.lightened(0.1), r, 8)
		l.prism(Vector3(0, -0.02, -0.05), Vector3(0, -0.06, -0.55), 0.15, 0.05, 8, MOTH)
		for k in 4:
			l.prism(Vector3(0, -0.02 - k * 0.01, -0.12 - k * 0.1), Vector3(0, -0.03 - k * 0.01, -0.17 - k * 0.1), 0.155 - k * 0.025, 0.15 - k * 0.025, 8, MOTH.darkened(0.15))
		# Feathery antennae.
		for side: float in [-1.0, 1.0]:
			var tip := Vector3(side * 0.22, 0.32, 0.38)
			l.prism(Vector3(side * 0.04, 0.08, 0.18), tip, 0.012, 0.008, 3, MOTH.lightened(0.2))
			for f in 6:
				var at := Vector3(side * 0.04, 0.08, 0.18).lerp(tip, (f + 1) / 7.0)
				l.prism(at, at + Vector3(side * 0.07, 0.02, -0.02), 0.008, 0.0, 3, MOTH.lightened(0.25)))
	_part(rig, "moth_eyes", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.09, 0.05, 0.2), Vector3(0.05, 0.05, 0.05), MOTH_DUST), true)
	for side: float in [-1.0, 1.0]:
		var fore := _pivot(rig, Vector3(side * 0.08, 0.05, 0.05), "WingL" if side < 0 else "WingR")
		_part(fore, "moth_fore_%s" % side, func(l: LowPoly) -> void:
			# A broad, rounded forewing fanned out from its root, dark bands toward its edge.
			var rim: Array[Vector3] = []
			for k in 11:
				var a := lerpf(-0.15, 1.0, k / 10.0) * PI
				var reach := 1.0 + 0.18 * sin(a * 1.3)
				rim.append(Vector3(side * (0.15 + sin(a * 0.5 + 0.35) * 1.15 * reach), 0.02 * sin(a), 0.22 - (1.0 - cos(a * 0.55)) * 0.62))
			var hub := Vector3(0, 0, 0.08)
			for k in rim.size() - 1:
				var col := MOTH.lightened(0.06) if k % 2 else MOTH
				l.leaf(hub, rim[k], rim[k + 1], col)
				l.leaf(hub, rim[k + 1], rim[k], col)
				var inner_a := hub.lerp(rim[k], 0.78) + Vector3(0, 0.006, 0)
				var inner_b := hub.lerp(rim[k + 1], 0.78) + Vector3(0, 0.006, 0)
				l.leaf(inner_a, rim[k] + Vector3(0, 0.006, 0), rim[k + 1] + Vector3(0, 0.006, 0), Color(0.3, 0.23, 0.19))
				l.leaf(inner_a, rim[k + 1] + Vector3(0, 0.006, 0), inner_b, Color(0.3, 0.23, 0.19))
				l.leaf(inner_a, rim[k + 1] + Vector3(0, -0.006, 0), rim[k] + Vector3(0, -0.006, 0), Color(0.3, 0.23, 0.19))
				l.leaf(inner_a, inner_b, rim[k + 1] + Vector3(0, -0.006, 0), Color(0.3, 0.23, 0.19)))
		_part(fore, "moth_eyespot_%s" % side, func(l: LowPoly) -> void:
			# Seen from above and below alike.
			l.prism(Vector3(side * 0.72, -0.014, -0.02), Vector3(side * 0.72, 0.022, -0.02), 0.17, 0.17, 10, GOD)
			l.prism(Vector3(side * 0.72, -0.02, -0.02), Vector3(side * 0.72, 0.03, -0.02), 0.08, 0.08, 8, MOTH_DUST), true)
		var hind := _pivot(rig, Vector3(side * 0.07, 0.03, -0.1), "WingL2" if side < 0 else "WingR2")
		_part(hind, "moth_hind_%s" % side, func(l: LowPoly) -> void:
			# The hindwing: a rounded lobe behind, ember-tinted at its edge.
			var rim: Array[Vector3] = []
			for k in 9:
				var a := k / 8.0 * PI
				rim.append(Vector3(side * sin(a) * 0.8, 0.0, -0.05 - (1.0 - cos(a)) * 0.34))
			for k in rim.size() - 1:
				var col := MOTH.darkened(0.04) if k % 2 else MOTH.darkened(0.1)
				l.leaf(Vector3.ZERO, rim[k], rim[k + 1], col)
				l.leaf(Vector3.ZERO, rim[k + 1], rim[k], col)
				var ia := rim[k] * 0.75 + Vector3(0, 0.006, 0)
				var ib := rim[k + 1] * 0.75 + Vector3(0, 0.006, 0)
				l.leaf(ia, rim[k] + Vector3(0, 0.006, 0), rim[k + 1] + Vector3(0, 0.006, 0), MOTH_DUST.darkened(0.35))
				l.leaf(ia, rim[k + 1] + Vector3(0, 0.006, 0), ib, MOTH_DUST.darkened(0.35)))


# --- The hive ------------------------------------------------------------------------------------

static func _hive(root: Node3D) -> void:
	var rig := _pivot(root, Vector3.ZERO, "Rig")
	# The broken olive stump the comb has grown over.
	_part(rig, "hive_stump", func(l: LowPoly) -> void:
		FontaFlora.limb(l, [Vector3(0, -0.3, 0), Vector3(0.15, 0.9, 0.05), Vector3(-0.1, 1.7, 0.1)] as Array[Vector3], 0.42, 0.28, BARK, 7)
		FontaFlora.limb(l, [Vector3(-0.1, 1.6, 0.1), Vector3(-0.6, 2.2, 0.2), Vector3(-0.8, 2.25, 0.4)] as Array[Vector3], 0.14, 0.06, BARK, 5)
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			l.prism(Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3), Vector3(cos(a) * 0.75, -0.25, sin(a) * 0.75), 0.13, 0.05, 5, BARK.darkened(0.15)))
	# The comb: great lobes of wax, cells pressed into them, honey running down.
	var comb := _pivot(rig, Vector3(0, 1.2, 0.05), "Comb")
	_part(comb, "hive_comb", func(l: LowPoly) -> void:
		# One great hanging comb and two lesser lobes, their wax pressed all over into hexagonal cells.
		l.ovoid(Vector3(0, 0, 0), Vector3(0.72, 0.95, 0.66), COMB.lightened(0.05), COMB_DARK, 6, 12)
		l.ovoid(Vector3(0.5, 0.35, -0.25), Vector3(0.42, 0.55, 0.4), COMB, COMB_DARK, 5, 10)
		l.ovoid(Vector3(-0.45, -0.35, -0.2), Vector3(0.38, 0.5, 0.36), COMB, COMB_DARK.darkened(0.1), 5, 10)
		for ring in 7:
			var th := 0.45 + ring * 0.33
			var count := int(round(sin(th) * 15.0))
			for k in count:
				var ph := TAU * k / count + (0.2 if ring % 2 else 0.0)
				var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var at := Vector3(dir.x * 0.72, dir.y * 0.95, dir.z * 0.66)
				var n := Vector3(dir.x / 0.72, dir.y / 0.95, dir.z / 0.66).normalized()
				l.prism(at - n * 0.02, at + n * 0.035, 0.085, 0.08, 6, COMB.lightened(0.12))
				l.prism(at + n * 0.036, at + n * 0.04, 0.06, 0.06, 6, COMB_DARK.darkened(0.35))
		# The dark mouth bees come and go by.
		l.prism(Vector3(0, -0.2, 0.6), Vector3(0, -0.2, 0.74), 0.2, 0.15, 8, BLACK))
	_part(comb, "hive_honey", func(l: LowPoly) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 117
		for k in 9:
			var a := r.randf() * TAU
			var top := Vector3(cos(a) * 0.62, r.randf_range(-0.6, -0.1), sin(a) * 0.62)
			l.prism(top, top + Vector3(0, -r.randf_range(0.3, 0.7), 0), 0.05, 0.02, 5, HONEY)
			l.prism(top + Vector3(0, -0.72, 0), top + Vector3(0, -0.8, 0), 0.04, 0.0, 5, HONEY))
	# Where the god changed it, the cells glow.
	_part(comb, "hive_glow", func(l: LowPoly) -> void:
		# Where the god changed it, cells glow in its colours.
		for k in 16:
			var th := 0.6 + (k % 5) * 0.4
			var ph := k * 2.39
			var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var at := Vector3(dir.x * 0.72, dir.y * 0.95, dir.z * 0.66)
			var n := Vector3(dir.x / 0.72, dir.y / 0.95, dir.z / 0.66).normalized()
			l.prism(at + n * 0.036, at + n * 0.045, 0.058, 0.058, 6, GOD if k % 3 else GOD_GREEN), true)
	# Bees circling it.
	var swarm := _pivot(rig, Vector3(0, 1.3, 0), "Swarm")
	for k in 5:
		var bee := _pivot(swarm, Vector3(cos(k * 1.26) * 1.4, sin(k * 2.1) * 0.4, sin(k * 1.26) * 1.4), "Bee%d" % k)
		_part(bee, "hive_bee", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0, 0.06), Vector3(0, 0, -0.09), 0.05, 0.03, 6, YELLOW)
			l.box(Vector3(0, 0, -0.02), Vector3(0.1, 0.02, 0.03), BLACK)
			l.leaf(Vector3(0, 0.03, 0.02), Vector3(0.12, 0.05, -0.04), Vector3(-0.12, 0.05, -0.04), WING))


# --- Snails --------------------------------------------------------------------------------------

## A snail's body and its shell, the shell either grown into glowing crystal seams or (wasps) a paper
## wasps' nest. The shell sits on its own pivot, so it can rock as the foot heaves.
static func _snail(root: Node3D, nest: bool) -> void:
	var rig := _pivot(root, Vector3.ZERO, "Rig")
	var key := "nest" if nest else "snail"
	var foot := _pivot(rig, Vector3.ZERO, "Foot")
	_part(foot, key + "_foot", func(l: LowPoly) -> void:
		# The soft foot: low, broad and wet, swelling under the shell and running out to a point behind.
		for k in 7:
			var z := 0.75 - k * 0.32
			var w := 0.44 * (1.0 - pow(maxf(0.0, (0.2 - z) / 1.9), 1.4)) + 0.04
			l.ovoid(Vector3(0, 0.14, z), Vector3(w, 0.15, 0.3), SNAIL_SKIN.lightened(0.04), SNAIL_SKIN.darkened(0.25), 4, 10)
		# The rippled fringe along its edge.
		for side: float in [-1.0, 1.0]:
			for k in 9:
				var z := 0.7 - k * 0.24
				var w := 0.44 * (1.0 - pow(maxf(0.0, (0.2 - z) / 1.9), 1.4)) + 0.06
				l.ovoid(Vector3(side * w, 0.05, z), Vector3(0.06, 0.04, 0.13), SNAIL_SKIN.darkened(0.15), SNAIL_SKIN.darkened(0.35), 3, 6))
	var neck := _pivot(foot, Vector3(0, 0.2, 0.85), "Neck")
	_part(neck, key + "_head", func(l: LowPoly) -> void:
		# The head reared a little off the ground, a wet mouth under it, two feelers low in front.
		l.ovoid(Vector3(0, 0.12, 0.05), Vector3(0.3, 0.26, 0.38), SNAIL_SKIN.lightened(0.08), SNAIL_SKIN.darkened(0.2), 4, 10, Basis(Vector3.RIGHT, -0.5))
		l.ovoid(Vector3(0, 0.02, 0.36), Vector3(0.12, 0.04, 0.05), Color(0.28, 0.2, 0.18), Color(0.2, 0.14, 0.12), 3, 8)
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * 0.14, 0.08, 0.34), Vector3(side * 0.26, -0.02, 0.56), 0.055, 0.02, 5, SNAIL_SKIN.darkened(0.05)))
	for side: float in [-1.0, 1.0]:
		var stalk := _pivot(neck, Vector3(side * 0.12, 0.32, 0.2), "StalkL" if side < 0 else "StalkR")
		_part(stalk, key + "_stalk_%s" % side, func(l: LowPoly) -> void:
			FontaFlora.limb(l, [Vector3.ZERO, Vector3(side * 0.06, 0.32, 0.12), Vector3(side * 0.13, 0.6, 0.2)] as Array[Vector3], 0.055, 0.03, SNAIL_SKIN, 6))
		_part(stalk, key + "_eye_%s" % side, func(l: LowPoly) -> void:
			l.ovoid(Vector3(side * 0.13, 0.65, 0.21), Vector3(0.055, 0.06, 0.055), GOD_GREEN if not nest else GOD, (GOD_GREEN if not nest else GOD).darkened(0.3), 3, 6), true)
	var shell := _pivot(foot, Vector3(0, 0.25, -0.35), "Shell")
	if nest:
		_part(shell, "nest_shell", func(l: LowPoly) -> void:
			# A paper nest: layered grey bands, its mouth at the back, holes all over.
			var r := RandomNumberGenerator.new()
			r.seed = 131
			for k in 7:
				var y := 0.15 + k * 0.22
				var w := 0.62 * sin((k + 1) / 8.0 * PI) + 0.12
				l.prism(Vector3(0, y, 0), Vector3(0, y + 0.24, 0), w, w * 0.92, 10, PAPER.darkened(0.08 * (k % 2)))
			for k in 12:
				var a := r.randf() * TAU
				var y := r.randf_range(0.4, 1.4)
				var w := 0.62 * sin(clampf((y - 0.15) / 1.7, 0.0, 1.0) * PI) + 0.12
				l.prism(Vector3(cos(a) * w * 0.98, y, sin(a) * w * 0.98), Vector3(cos(a) * (w + 0.03), y, sin(a) * (w + 0.03)), 0.07, 0.07, 6, BLACK)
			l.prism(Vector3(0, 1.72, 0), Vector3(0, 2.0, 0), 0.12, 0.03, 6, PAPER.darkened(0.2)))
		var crawlers := _part(shell, "nest_crawlers", func(l: LowPoly) -> void:
			var r := RandomNumberGenerator.new()
			r.seed = 137
			for k in 9:
				var a := r.randf() * TAU
				var y := r.randf_range(0.3, 1.5)
				var w := 0.62 * sin(clampf((y - 0.15) / 1.7, 0.0, 1.0) * PI) + 0.16
				var at := Vector3(cos(a) * w, y, sin(a) * w)
				l.prism(at, at + Vector3(0, 0.03, 0.12).rotated(Vector3.UP, a), 0.035, 0.02, 4, YELLOW if k % 2 else WASP_RED))
		crawlers.name = "Crawlers"
	else:
		# A true coiled shell: a tube winding inward round a sideways axis, each whorl narrower,
		# growth bands across it, limestone knobs on the outer whorl.
		_part(shell, "snail_shell", func(l: LowPoly) -> void:
			var steps := 46
			for i in steps:
				var t0 := float(i) / steps
				var t1 := float(i + 1) / steps
				var col := SNAIL_SHELL.lightened(0.1) if i % 3 == 0 else SNAIL_SHELL.darkened(0.06 * (i % 2))
				l.prism(_whorl(t0), _whorl(t1), _whorl_r(t0), _whorl_r(t1), 10, col.darkened(t0 * 0.25))
			# The mouth: a lip round the opening, low at the front.
			l.prism(_whorl(0.0) + Vector3(0, 0, 0.04), _whorl(0.0) - Vector3(0, 0, 0.02), _whorl_r(0.0) * 1.08, _whorl_r(0.0) * 0.9, 10, SNAIL_SHELL.lightened(0.25))
			for k in 7:
				var t := 0.05 + k * 0.06
				var at := _whorl(t)
				var out := _whorl_out(t)
				l.prism(at + out * _whorl_r(t) * 0.85, at + out * (_whorl_r(t) + 0.2) + Vector3(0, 0.04, 0), 0.07, 0.0, 5, LIMESTONE.darkened(0.15)))
		# The crystal seams along both sides of every whorl, coloured by what it leaves behind (set per
		# creature, by FontaMind.trail_colour).
		var draw_seams := func(l: LowPoly) -> void:
			var steps := 52
			for side: float in [-1.0, 1.0]:
				for i in steps:
					var t0 := float(i) / steps
					var t1 := float(i + 1) / steps
					var a := _whorl(t0) + (_whorl_out(t0) * 0.55 + Vector3(side * 0.8, 0, 0)) * _whorl_r(t0)
					var b := _whorl(t1) + (_whorl_out(t1) * 0.55 + Vector3(side * 0.8, 0, 0)) * _whorl_r(t1)
					l.prism(a, b, 0.032 * (1.0 - t0 * 0.6), 0.032 * (1.0 - t1 * 0.6), 4, Color.WHITE)
		var seams := _part(shell, "snail_seams", draw_seams, true)
		seams.name = "Seams"


## The snail's shell coils round a sideways axis through SHELL_HUB, starting at its mouth on the foot
## (t = 0) and winding 2.4 turns inward to its tip (t = 1), drifting a little to one side as it goes.
const SHELL_HUB := Vector3(0, 0.62, -0.05)
static func _whorl(t: float) -> Vector3:
	var a := -PI * 0.5 + t * TAU * 2.4
	var r := 0.7 * exp(-2.1 * t)
	return SHELL_HUB + Vector3(0.18 * t, sin(a) * r, cos(a) * r) + Vector3(0, 0.12, 0) * (1.0 - t)


static func _whorl_r(t: float) -> float:
	return 0.5 * exp(-2.1 * t) + 0.03


static func _whorl_out(t: float) -> Vector3:
	var a := -PI * 0.5 + t * TAU * 2.4
	return Vector3(0, sin(a), cos(a))


# --- The spider ----------------------------------------------------------------------------------

static func _spider(root: Node3D) -> void:
	var rig := _pivot(root, Vector3(0, 0.55, 0), "Rig")
	_part(rig, "spider_body", func(l: LowPoly) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 151
		# The front body, and the great abdomen behind it, hairy.
		l.prism(Vector3(0, 0, -0.05), Vector3(0, 0.03, 0.32), 0.24, 0.18, 9, SPIDER)
		FontaFlora.clump(l, Vector3(0, 0.15, -0.55), 0.48, 0.85, SPIDER, r, 9)
		for k in 26:
			var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.2, 1), r.randf_range(-1, 1)).normalized()
			l.prism(Vector3(0, 0.15, -0.55) + dir * 0.4, Vector3(0, 0.15, -0.55) + dir * 0.52, 0.03, 0.0, 3, SPIDER_HAIR)
		# Fangs.
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * 0.07, -0.02, 0.32), Vector3(side * 0.05, -0.16, 0.42), 0.05, 0.01, 5, BLACK))
	_part(rig, "spider_marks", func(l: LowPoly) -> void:
		# The god's mark on its back, and its crown of eyes.
		# A chevron of the god's violet pointing to its head, like the mark on the Beehive's cells.
		for side: float in [-1.0, 1.0]:
			l.turned_box(Vector3(side * 0.08, 0.55, -0.6), Vector3(0.07, 0.02, 0.3), GOD, Basis(Vector3.RIGHT, -0.25) * Basis(Vector3.UP, side * 0.55))
			l.turned_box(Vector3(side * 0.07, 0.5, -0.78), Vector3(0.05, 0.02, 0.18), GOD.darkened(0.15), Basis(Vector3.RIGHT, -0.4) * Basis(Vector3.UP, side * 0.55))
		l.turned_box(Vector3(0, 0.45, -0.85), Vector3(0.22, 0.02, 0.06), GOD_GREEN, Basis(Vector3.RIGHT, -0.6))
		for k in 8:
			var a := -0.7 + (k % 4) * 0.47
			var y := 0.12 if k < 4 else 0.06
			l.box(Vector3(sin(a) * 0.12, y, 0.3 + cos(a) * 0.02), Vector3(0.04, 0.04, 0.03) * (1.4 if k in [1, 2] else 1.0), Color(1.0, 0.3, 0.25) if k < 4 else GOD), true)
	# Eight legs, each on a hip pivot with a knee pivot, so they can step, grip and spread.
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var hip := _pivot(rig, Vector3(side * 0.16, 0.02, 0.22 - k * 0.12), "Leg%s%d" % ["L" if side < 0 else "R", k])
			hip.rotation.y = side * (0.9 - k * 0.55)
			_part(hip, "spider_thigh_%s" % side, func(l: LowPoly) -> void:
				l.prism(Vector3.ZERO, Vector3(side * 0.55, 0.42, 0), 0.05, 0.04, 5, SPIDER_HAIR))
			var knee := _pivot(hip, Vector3(side * 0.55, 0.42, 0), "Knee")
			_part(knee, "spider_shin_%s" % side, func(l: LowPoly) -> void:
				l.prism(Vector3.ZERO, Vector3(side * 0.5, -0.95, 0), 0.04, 0.012, 5, SPIDER)
				l.box(Vector3(side * 0.24, -0.45, 0), Vector3(0.09, 0.03, 0.09), GOD.darkened(0.3)))


# --- The battle ostrich --------------------------------------------------------------------------

static func _ostrich(root: Node3D) -> void:
	var rig := _pivot(root, Vector3(0, 1.25, 0), "Rig")
	# Where a point lies on the body's surface, a bearing round it (0 on top, PI/2 on the right) and
	# a length along it (+ forward), a little proud of it by `out`.
	var body_c := Vector3(0, 0.05, -0.05)
	var body_r := Vector3(0.44, 0.38, 0.64)
	var on_body := func(bearing: float, along: float, out: float) -> Vector3:
		var ring := sqrt(maxf(0.0, 1.0 - along * along))
		return body_c + Vector3(sin(bearing) * body_r.x * ring, cos(bearing) * body_r.y * ring, along * body_r.z) * (1.0 + out)
	_part(rig, "ostrich_body", func(l: LowPoly) -> void:
		l.ovoid(body_c, body_r, OSTRICH.lightened(0.08), OSTRICH.darkened(0.3), 6, 12, Basis(Vector3.RIGHT, -0.12))
		# A cloak of loose black plumes over the back and flanks, their tips catching the light.
		for row in 5:
			var along := 0.55 - row * 0.26
			for k in 9:
				var bearing := -1.9 + k * 0.475 + (0.2 if row % 2 else 0.0)
				var base: Vector3 = on_body.call(bearing, along, 0.02)
				var down := Vector3(sin(bearing) * 0.5, -0.8, -0.45).normalized()
				var tip := base + down * 0.28
				var w := Vector3(cos(bearing), 0, 0) * 0.07 + Vector3(0, 0, 0.05)
				l.leaf(base - w, tip, base + w, OSTRICH.lightened(0.05 + 0.04 * (k % 2)))
				l.leaf(base + w, tip, base - w, OSTRICH.lightened(0.05 + 0.04 * (k % 2)))
				l.leaf(tip - w * 0.4, tip + down * 0.08, tip + w * 0.4, OSTRICH.lightened(0.3)))
	# The wings: fans of white plumes held half out from the flanks, grey at their roots, each on its
	# own pivot at the shoulder so they can beat, spread and flare.
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.4, 0.12, 0.22)
		var wing := _pivot(rig, shoulder, "WingL" if side < 0 else "WingR")
		_part(wing, "ostrich_wing_%s" % side, func(l: LowPoly) -> void:
			for f in 7:
				var a := -0.2 + f * 0.22
				var tip := Vector3(side * (0.32 + 0.06 * sin(f)), -0.15 - f * 0.05, -0.25 - f * 0.11).rotated(Vector3.FORWARD, side * a * 0.2)
				var mid := tip * 0.45
				var w := Vector3(0, 0.07, 0.06)
				l.leaf(Vector3.ZERO, mid + w, mid - w, PLUME.darkened(0.35))
				l.leaf(Vector3.ZERO, mid - w, mid + w, PLUME.darkened(0.35))
				l.leaf(mid + w, tip, mid - w, PLUME.darkened(0.03 * f))
				l.leaf(mid - w, tip, mid + w, PLUME.darkened(0.03 * f)))
	# The tail: a fountain of white plumes, up and back, that bounces as it runs.
	var tail := _pivot(rig, Vector3(0, 0.18, -0.62), "Tail")
	_part(tail, "ostrich_tail", func(l: LowPoly) -> void:
		for f in 8:
			var a := -0.75 + f * 0.21
			var root_at := Vector3(sin(a) * 0.12, 0.0, 0.0)
			var tip := root_at + Vector3(sin(a) * 0.32, 0.38 - absf(a) * 0.2, -0.3)
			var w := Vector3(0.06, 0, 0.04)
			l.leaf(root_at - w, tip, root_at + w, PLUME)
			l.leaf(root_at + w, tip, root_at - w, PLUME)
			l.leaf(tip - w * 0.8, tip + Vector3(sin(a) * 0.08, -0.12, -0.06), tip + w * 0.8, PLUME.darkened(0.06)))
	# The war-harness: a curved breastplate of bronze lames, a girth strap, a red saddle cloth with a
	# fringe, and a bronze boss on each flank.
	_part(rig, "ostrich_harness", func(l: LowPoly) -> void:
		for row in 3:
			for k in 7:
				var bearing := -1.25 + k * 0.42
				var along := 0.82 - row * 0.12
				var at: Vector3 = on_body.call(bearing, along, 0.06 + row * 0.01)
				var face := (at - body_c).normalized()
				var turn := Basis.looking_at(-face, Vector3.UP)
				l.turned_box(at + Vector3(0, -0.1 - row * 0.02, 0), Vector3(0.15, 0.13, 0.025), BRONZE.lightened(0.06 * ((k + row) % 2)), turn)
				l.prism(at + Vector3(0, -0.04 - row * 0.02, 0), at + face * 0.035 + Vector3(0, -0.04 - row * 0.02, 0), 0.016, 0.0, 4, BRONZE.lightened(0.35))
		for k in 17:
			var bearing := -PI + k * TAU / 16.0
			var a: Vector3 = on_body.call(bearing, 0.28, 0.035)
			var b: Vector3 = on_body.call(bearing + TAU / 16.0, 0.28, 0.035)
			l.prism(a, b, 0.03, 0.03, 4, Color(0.28, 0.18, 0.1))
		for row in 3:
			for k in 6:
				var a0 := -1.15 + k * 0.383
				var a1 := a0 + 0.383
				var z0 := 0.12 - row * 0.2
				var z1 := z0 - 0.2
				var p00: Vector3 = on_body.call(a0, z0, 0.05)
				var p01: Vector3 = on_body.call(a1, z0, 0.05)
				var p10: Vector3 = on_body.call(a0, z1, 0.05)
				var p11: Vector3 = on_body.call(a1, z1, 0.05)
				var col := CLOTH.darkened(0.06 * ((k + row) % 2))
				l.leaf(p00, p01, p10, col)
				l.leaf(p01, p11, p10, col)
				l.leaf(p00, p10, p01, col)
				l.leaf(p01, p10, p11, col)
		for side: float in [-1.0, 1.0]:
			for f in 9:
				var at: Vector3 = on_body.call(side * 1.15, 0.12 - f * 0.075, 0.06)
				l.prism(at, at + Vector3(side * 0.02, -0.14, 0), 0.016, 0.006, 3, Color(0.95, 0.75, 0.25))
			var boss: Vector3 = on_body.call(side * 1.45, 0.05, 0.07)
			l.prism(boss, boss + Vector3(side * 0.05, 0, 0), 0.09, 0.06, 8, BRONZE.lightened(0.2))
			l.prism(boss + Vector3(side * 0.05, 0, 0), boss + Vector3(side * 0.1, 0, 0), 0.03, 0.0, 5, BRONZE.lightened(0.4)))
	# The neck, in two pivots, a ruff of black plumes at its root, and the head.
	var neck := _pivot(rig, Vector3(0, 0.28, 0.5), "Neck")
	_part(neck, "ostrich_neck_low", func(l: LowPoly) -> void:
		FontaFlora.limb(l, [Vector3.ZERO, Vector3(0, 0.3, 0.08), Vector3(0, 0.58, 0.12)] as Array[Vector3], 0.14, 0.075, OSTRICH_SKIN, 8)
		for k in 10:
			var a := TAU * k / 10.0
			var base := Vector3(sin(a) * 0.15, 0.04, cos(a) * 0.12)
			var tip := base + Vector3(sin(a) * 0.12, -0.2, cos(a) * 0.08)
			var w := Vector3(cos(a), 0, -sin(a)) * 0.06
			l.leaf(base - w, tip, base + w, OSTRICH.lightened(0.1))
			l.leaf(base + w, tip, base - w, OSTRICH.lightened(0.1)))
	var upper := _pivot(neck, Vector3(0, 0.58, 0.12), "NeckUp")
	_part(upper, "ostrich_neck_up", func(l: LowPoly) -> void:
		FontaFlora.limb(l, [Vector3.ZERO, Vector3(0, 0.3, 0.02), Vector3(0, 0.58, 0.06)] as Array[Vector3], 0.075, 0.06, OSTRICH_SKIN.lightened(0.05), 7)
		# A bronze collar with a red tassel.
		l.prism(Vector3(0, 0.08, 0.0), Vector3(0, 0.16, 0.01), 0.09, 0.085, 8, BRONZE.lightened(0.1))
		l.prism(Vector3(0, 0.12, 0.09), Vector3(0, -0.05, 0.14), 0.03, 0.012, 5, CLOTH))
	var head := _pivot(upper, Vector3(0, 0.6, 0.06), "Head")
	_part(head, "ostrich_head", func(l: LowPoly) -> void:
		l.ovoid(Vector3(0, 0.01, 0.02), Vector3(0.1, 0.09, 0.12), OSTRICH_SKIN.lightened(0.1), OSTRICH_SKIN.darkened(0.1), 4, 8)
		# A broad flat beak, its gape running back under the eye.
		l.ovoid(Vector3(0, -0.02, 0.19), Vector3(0.065, 0.03, 0.12), Color(0.82, 0.64, 0.42), Color(0.6, 0.44, 0.28), 3, 8)
		l.box(Vector3(0, -0.03, 0.17), Vector3(0.11, 0.008, 0.2), Color(0.3, 0.2, 0.15))
		# The spiked brow plate, cheek straps.
		l.turned_box(Vector3(0, 0.08, 0.04), Vector3(0.17, 0.04, 0.17), BRONZE, Basis(Vector3.RIGHT, -0.15))
		for k in 3:
			l.prism(Vector3((k - 1) * 0.05, 0.1, 0.06 - absf(k - 1) * 0.03), Vector3((k - 1) * 0.07, 0.25 - absf(k - 1) * 0.05, -0.02), 0.026, 0.0, 4, BRONZE.lightened(0.25))
		for side: float in [-1.0, 1.0]:
			l.turned_box(Vector3(side * 0.095, -0.01, 0.06), Vector3(0.012, 0.14, 0.03), Color(0.28, 0.18, 0.1), Basis(Vector3.RIGHT, 0.3))
			# Lashes over the eye.
			l.prism(Vector3(side * 0.09, 0.055, 0.06), Vector3(side * 0.11, 0.075, 0.1), 0.01, 0.0, 3, BLACK))
	_part(head, "ostrich_eyes", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			l.ovoid(Vector3(side * 0.088, 0.03, 0.06), Vector3(0.018, 0.03, 0.035), Color(1.0, 0.5, 0.15), Color(0.9, 0.3, 0.1), 3, 6), true)
	# Two long legs: a feathered thigh, the bare shank, a foot with its two great toes.
	for side: float in [-1.0, 1.0]:
		var hip := _pivot(rig, Vector3(side * 0.22, -0.22, 0.0), "LegL" if side < 0 else "LegR")
		_part(hip, "ostrich_thigh_%s" % side, func(l: LowPoly) -> void:
			l.ovoid(Vector3(0, -0.02, 0), Vector3(0.17, 0.2, 0.2), OSTRICH, OSTRICH.darkened(0.2), 4, 8)
			FontaFlora.limb(l, [Vector3(0, -0.12, 0.02), Vector3(0, -0.3, 0.06), Vector3(0, -0.45, 0.1)] as Array[Vector3], 0.12, 0.07, OSTRICH_SKIN.darkened(0.05), 7))
		var knee := _pivot(hip, Vector3(0, -0.45, 0.1), "Knee")
		_part(knee, "ostrich_shank_%s" % side, func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.02, 0), Vector3(0, -0.55, -0.12), 0.065, 0.05, 6, OSTRICH_SKIN.darkened(0.1))
			# Scaled front of the shank.
			for k in 5:
				var y := -0.08 - k * 0.1
				l.box(Vector3(0, y, 0.04 - k * 0.02), Vector3(0.07, 0.05, 0.03), OSTRICH_SKIN.darkened(0.25))
			l.prism(Vector3(0, -0.55, -0.12), Vector3(side * 0.04, -0.6, 0.14), 0.055, 0.035, 5, OSTRICH_SKIN.darkened(0.2))
			l.prism(Vector3(0, -0.55, -0.12), Vector3(-side * 0.07, -0.6, 0.05), 0.04, 0.025, 4, OSTRICH_SKIN.darkened(0.2))
			l.prism(Vector3(side * 0.04, -0.6, 0.14), Vector3(side * 0.04, -0.62, 0.22), 0.03, 0.0, 4, BLACK))


## A battle ostrich under a Temple Guardian (ZombieDefs "mount": "ostrich"): the same bird, with a
## saddle for the rider to sit in (Zombie._seat_rider).
const MOUNT_SIZE := 0.95 # (times its rider's own scale: a Guardian's head rides level with the bird's)
static func mount_ostrich() -> Node3D:
	var root := Node3D.new()
	root.name = "OstrichMount"
	_ostrich(root)
	_pivot(root.get_node("Rig") as Node3D, Vector3(0, 0.34, -0.3), "Saddle")
	return root


## The mount runs as the ostrich does on its own: legs scissoring with its rider's pace, stretched out
## in the charge, a kick as its rider strikes.
static func ride_ostrich(z: Zombie, mount: Node3D, delta: float, pace: float, rider_anim: String) -> void:
	var rig := mount.get_node("Rig") as Node3D
	var state := "m_charge" if rider_anim == "RideCharge" else ""
	_run_ostrich(z, rig, delta, minf(1.0, delta * 8.0), pace, state, false, 0.0, z.world.now, true)


## A Guardian's ostrich brought down under it: it dies as a battle ostrich does, `age` seconds in,
## and sinks away at the end of MOUNT_FALL_TIME.
const MOUNT_FALL_TIME := 3.0
static func fall_mount(z: Zombie, mount: Node3D, age: float, delta: float) -> void:
	if not mount.has_meta("side"):
		mount.set_meta("side", -1.0 if randf() < 0.5 else 1.0)
	var rig := mount.get_node("Rig") as Node3D
	_die_ostrich(z, mount, rig, age, delta, float(mount.get_meta("side")), mount.global_position)
	rig.position.y -= 1.4 * smoothstep(MOUNT_FALL_TIME - 0.6, MOUNT_FALL_TIME, age)


# --- The thornback -------------------------------------------------------------------------------

static func _thornback(root: Node3D) -> void:
	var rig := _pivot(root, Vector3.ZERO, "Rig")
	var shell := _pivot(rig, Vector3(0, 0.5, 0), "Shell")
	_part(shell, "thornback_shell", func(l: LowPoly) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 191
		l.prism(Vector3(0, -0.12, 0), Vector3(0, 0.0, 0), 1.05, 1.08, 12, SHELL.darkened(0.2))
		l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.55, 0), 1.08, 0.7, 12, SHELL)
		l.prism(Vector3(0, 0.55, 0), Vector3(0, 0.78, 0), 0.7, 0.2, 12, SHELL.lightened(0.05))
		# Plates, and the limestone thorns grown out of them.
		for k in 9:
			var a := TAU * k / 9.0
			l.turned_box(Vector3(cos(a) * 0.75, 0.38, sin(a) * 0.75), Vector3(0.42, 0.03, 0.36), SHELL.darkened(0.25), Basis.looking_at(Vector3(cos(a), 0.9, sin(a)).normalized(), Vector3.UP))
		for k in 13:
			var a := r.randf() * TAU
			var d := r.randf_range(0.1, 0.75)
			var at := Vector3(cos(a) * d, 0.8 - d * 0.55, sin(a) * d)
			l.prism(at, at + Vector3(cos(a) * d * 0.3, r.randf_range(0.35, 0.8), sin(a) * d * 0.3), r.randf_range(0.09, 0.16), 0.0, 5, LIMESTONE.darkened(r.randf() * 0.2))
		for k in 10:
			var a := r.randf() * TAU
			FontaFlora.clump(l, Vector3(cos(a) * 0.85, 0.3, sin(a) * 0.85), 0.14, 0.5, MOSS, r, 5))
	_part(shell, "thornback_seam", func(l: LowPoly) -> void:
		for k in 9:
			var a := TAU * k / 9.0 + 0.35
			l.box(Vector3(cos(a) * 0.9, 0.2, sin(a) * 0.9), Vector3(0.05, 0.08, 0.05), GOD), true)
	var head := _pivot(rig, Vector3(0, 0.5, 1.05), "Head")
	_part(head, "thornback_head", func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.05, -0.3), Vector3(0, 0.0, 0.15), 0.2, 0.22, 8, Color(0.45, 0.42, 0.3))
		l.prism(Vector3(0, 0.0, 0.15), Vector3(0, -0.03, 0.42), 0.22, 0.08, 8, Color(0.5, 0.47, 0.34))
		l.prism(Vector3(0, -0.03, 0.38), Vector3(0, -0.12, 0.52), 0.08, 0.0, 5, BLACK)) # the hooked upper beak
	var jaw := _pivot(head, Vector3(0, -0.12, 0.14), "Jaw")
	_part(jaw, "thornback_jaw", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.1), Vector3(0, -0.02, 0.24), 0.17, 0.06, 7, Color(0.42, 0.39, 0.28))
		l.prism(Vector3(0, -0.02, 0.22), Vector3(0, 0.02, 0.33), 0.06, 0.0, 5, BLACK))
	_part(head, "thornback_eyes", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.16, 0.06, 0.22), Vector3(0.03, 0.04, 0.05), GOD_GREEN), true)
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var front := 1.0 if k < 2 else -1.0
		var leg := _pivot(rig, Vector3(side * 0.72, 0.35, front * 0.55), "Leg%d" % k)
		_part(leg, "thornback_leg", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.35, 0.04), 0.2, 0.18, 7, Color(0.45, 0.42, 0.3))
			for c in 3:
				l.prism(Vector3((c - 1) * 0.08, -0.32, 0.12), Vector3((c - 1) * 0.09, -0.36, 0.22), 0.03, 0.0, 4, BLACK))


# --- Moving them ---------------------------------------------------------------------------------

## Each frame, on every phone.
static func animate(z: Zombie, root: Node3D, delta: float, moving: float) -> void:
	var state := z._current_anim
	var tell := z.is_warning()
	if state != str(root.get_meta("act_state", "")) or tell != bool(root.get_meta("act_warning", false)):
		root.set_meta("act_state", state)
		root.set_meta("act_warning", tell)
		root.set_meta("act_t", 0.0)
	var age := float(root.get_meta("act_t", 0.0)) + delta
	root.set_meta("act_t", age)
	var t := z.world.now + z.net_id * 0.37
	var rig := root.get_node("Rig") as Node3D
	var k := minf(1.0, delta * 8.0)
	match z.model_id:
		"mutant_bee", "mutant_wasp": _fly_insect(z, root, rig, delta, k, state, tell, age, t)
		"ember_moth": _fly_moth(rig, delta, k, state, tell, age, t)
		"beehive": _sway_hive(z, rig, delta, t)
		"mutant_snail", "wasp_hive_snail": _crawl_snail(z, root, rig, delta, k, moving, state, age, t)
		"mutant_spider": _scuttle_spider(z, rig, delta, k, moving, state, tell, age, t)
		"battle_ostrich": _run_ostrich(z, rig, delta, k, moving, state, tell, age, t)
		"thornback": _plod_thornback(rig, delta, k, moving, state, age, t)


## Bees and wasps: wings a blur, body bobbing; the tell curls the abdomen forward under the body; a
## dive pitches it nose down, legs swept back; a wasp's shot snaps the abdomen straight.
static func _fly_insect(z: Zombie, root: Node3D, rig: Node3D, delta: float, k: float, state: String, tell: bool, age: float, t: float) -> void:
	var blur := sin(t * 70.0)
	for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
		if not rig.has_node(label):
			continue
		var side := -1.0 if label.begins_with("WingL") else 1.0
		var wing := rig.get_node(label) as Node3D
		wing.rotation.z = side * (0.25 + blur * 0.55 * (0.8 if label.ends_with("2") else 1.0))
		wing.rotation.y = side * (0.15 + cos(t * 70.0) * 0.12)
	var diving := state == "m_dive"
	var pitch := 0.55 if diving else -0.15 if tell else 0.08 * sin(t * 2.3)
	rig.rotation.x = lerpf(rig.rotation.x, pitch, k)
	rig.position.y = 0.55 + sin(t * 3.1) * 0.05
	var abdomen := rig.get_node("Abdomen") as Node3D
	var curl := 0.0
	if tell:
		curl = 1.0 * smoothstep(0.0, 0.35, age) # the stinger brought round to the front
	elif state == "m_throw":
		curl = 1.0 - smoothstep(0.0, 0.12, age) # snapped straight as the stinger flies
	# A negative turn about X brings the abdomen (which runs back along -Z) down and forward under the body.
	abdomen.rotation.x = lerpf(abdomen.rotation.x, -curl + sin(t * 9.0) * 0.06, minf(1.0, delta * 14.0))
	var legs := rig.get_node("Legs") as Node3D
	legs.rotation.x = lerpf(legs.rotation.x, -0.7 if diving else 0.15 * sin(t * 4.0), k)
	(rig.get_node("Head") as Node3D).rotation.y = sin(t * 1.7) * 0.15


static func _fly_moth(rig: Node3D, delta: float, k: float, state: String, tell: bool, age: float, t: float) -> void:
	# Slow, heavy beats; the tell spreads the wings wide and holds them, eye-spots blazing; the release
	# claps them together and throws the dust.
	var beat := sin(t * 5.5)
	var spread := 0.0
	if tell:
		spread = smoothstep(0.0, 0.5, age)
	var clap := exp(-age * 6.0) if state == "m_throw" else 0.0
	for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
		var side := -1.0 if label.begins_with("WingL") else 1.0
		var wing := rig.get_node(label) as Node3D
		var want := lerpf(beat * 0.7 + 0.1, -0.15, spread) + clap * 1.3
		wing.rotation.z = lerpf(wing.rotation.z, side * want * (0.85 if label.ends_with("2") else 1.0), minf(1.0, delta * 12.0))
	rig.position.y = 0.6 + beat * 0.12
	rig.rotation.x = lerpf(rig.rotation.x, -0.5 * spread + sin(t * 1.3) * 0.08, k)


## The hive breathes a little, its bees circle; struck, it shakes and its bees swarm out wider.
static func _sway_hive(z: Zombie, rig: Node3D, delta: float, t: float) -> void:
	var comb := rig.get_node("Comb") as Node3D
	var shaken := clampf(z.bar_time - 2.0, 0.0, 0.5) * 2.0
	comb.scale = Vector3.ONE * (1.0 + sin(t * 1.6) * 0.02)
	comb.rotation.z = sin(t * 40.0) * 0.06 * shaken
	var swarm := rig.get_node("Swarm") as Node3D
	swarm.rotation.y += delta * (1.4 + shaken * 3.0)
	for k in swarm.get_child_count():
		var bee := swarm.get_child(k) as Node3D
		var r := 1.3 + shaken * 0.8 + sin(t * 1.1 + k) * 0.2
		var a := k * 1.26 + sin(t * 0.7 + k) * 0.4
		bee.position = Vector3(cos(a) * r, sin(t * 2.2 + k * 2.0) * 0.45, sin(a) * r)
		bee.rotation.y = -a


## A snail heaving along: the foot rippling, the shell rocking, eye-stalks searching; it rears its
## head back for the tell and lunges; a wasp-snail's nest shudders as wasps come out of it.
static func _crawl_snail(z: Zombie, root: Node3D, rig: Node3D, delta: float, k: float, moving: float, state: String, age: float, t: float) -> void:
	if z.model_id == "mutant_snail" and not root.has_meta("tinted"):
		root.set_meta("tinted", true)
		var seams := root.find_child("Seams", true, false) as MeshInstance3D
		if seams:
			var look := MesenllaModels.glow_material().duplicate() as StandardMaterial3D
			look.albedo_color = FontaMind.trail_colour(z)
			seams.material_override = look
	if z.model_id == "mutant_snail":
		FontaTrails.of(z.world).track(z)
	var foot := rig.get_node("Foot") as Node3D
	var crawl := t * (3.0 if moving > 0.2 else 0.8)
	foot.scale.z = 1.0 + sin(crawl) * 0.06
	foot.scale.y = 1.0 - sin(crawl) * 0.04
	var shell := foot.get_node("Shell") as Node3D
	shell.rotation.z = sin(crawl * 0.5) * 0.05
	shell.rotation.x = sin(crawl) * 0.03
	if state == "m_cast":
		shell.position.y = 0.25 + absf(sin(age * 30.0)) * 0.05 # the nest shudders as it opens
	else:
		shell.position.y = 0.25
	var neck := foot.get_node("Neck") as Node3D
	var reach := 0.0
	if z._attack_left > 0.0:
		reach = sin(clampf(1.0 - z._attack_left / 0.6, 0.0, 1.0) * PI)
	neck.rotation.x = lerpf(neck.rotation.x, -0.25 * reach + sin(t * 0.9) * 0.05, k)
	neck.position.z = 0.95 + reach * 0.25
	for label: String in ["StalkL", "StalkR"]:
		var stalk := neck.get_node(label) as Node3D
		stalk.rotation.x = sin(t * 1.3 + (0.0 if label == "StalkL" else 1.7)) * 0.25
		stalk.rotation.z = sin(t * 0.9 + (0.0 if label == "StalkL" else 2.1)) * 0.2


## A spider: legs stepping in alternate fours, quick; perched (m_sink), head down and legs gripping;
## the tell (m_cast) crouches it; the pounce (m_lunge) throws every leg out wide; biting (m_bite).
static func _scuttle_spider(z: Zombie, rig: Node3D, delta: float, k: float, moving: float, state: String, tell: bool, age: float, t: float) -> void:
	var perched := state == "m_sink"
	var leaping := state == "m_lunge"
	var gait := t * (14.0 if moving > 0.3 else 0.0)
	# Perched, it faces out from the trunk and tips head down, so its belly and legs grip the bark.
	rig.rotation.x = lerpf(rig.rotation.x, 1.45 if perched else 0.0, k)
	rig.position.y = lerpf(rig.position.y, 0.35 if tell else 0.55, k)
	for side: String in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		for n in 4:
			var hip := rig.get_node("Leg%s%d" % [side, n]) as Node3D
			var knee := hip.get_node("Knee") as Node3D
			var phase := gait + (0.0 if (n + (0 if side == "L" else 1)) % 2 == 0 else PI)
			var lift := 0.0
			var swing := 0.0
			if leaping:
				lift = -0.15
				swing = (-0.35 if n < 2 else 0.4) # front legs reach ahead, back legs trail
			elif perched:
				lift = -0.2
			elif moving > 0.3:
				lift = maxf(0.0, sin(phase)) * 0.35
				swing = cos(phase) * 0.35
			if tell:
				lift = -0.3
			hip.rotation.z = lerpf(hip.rotation.z, s * lift, minf(1.0, delta * 16.0))
			hip.rotation.x = lerpf(hip.rotation.x, swing, minf(1.0, delta * 16.0))
			knee.rotation.z = lerpf(knee.rotation.z, s * (0.9 if leaping else 0.25 if tell else 0.0), minf(1.0, delta * 14.0))


## The ostrich. Running: a real stride, each leg folding up as it swings through and reaching
## straight to plant, the body bobbing twice a stride and rolling a little, the neck pumping, the
## wings held out and beating for balance, the tail bouncing. Standing: it looks about in quick bird
## jerks. The tell (m_cast) is a threat display: wings up and spread, head low and forward, one foot
## scraping the ground back. The charge (m_charge) is flat out, neck level, wings wide. The kick
## (m_bite): a wind-up, knee drawn high and the body leaning back, wings flaring, then the leg slashes
## forward and down, and is set back.
static func _run_ostrich(z: Zombie, rig: Node3D, delta: float, k: float, moving: float, state: String, tell: bool, age: float, t: float, ridden := false) -> void:
	var charging := state == "m_charge"
	var running := moving > 0.2 or charging
	var pace := (2.6 if charging else clampf(moving * 0.55, 0.9, 2.4))
	var stride := float(rig.get_meta("stride", 0.0)) + delta * pace * TAU * (1.0 if running else 0.0)
	rig.set_meta("stride", fmod(stride, TAU * 8.0))
	var reach := 0.8 if charging else clampf(moving / 7.0, 0.3, 0.6)
	# The kick, from the state's own clock (a charge's kick and a melee kick alike).
	var kicking := state == "m_bite"
	var wind := _ease(0.0, 0.22, age) if kicking else 0.0
	var slash := _ease(0.22, 0.34, age) if kicking else 0.0
	var back := _ease(0.45, 0.7, age) if kicking else 0.0
	var kick_leg := 1.0 - back
	for label: String in ["LegL", "LegR"]:
		var hip := rig.get_node(label) as Node3D
		var knee := hip.get_node("Knee") as Node3D
		var phase := stride + (0.0 if label == "LegL" else PI)
		var swing_x := 0.0
		var fold := 0.0
		if running:
			# Forward through the air (sin > 0) folded, back along the ground straight.
			swing_x = -sin(phase) * reach
			fold = maxf(0.0, sin(phase + 0.6)) * (0.9 + reach)
		if tell and label == "LegR":
			# Scraping: forward lightly, then dragged back hard along the ground.
			var scrape := fmod(age * 1.6, 1.0)
			swing_x = lerpf(-0.45, 0.4, _ease(0.35, 0.8, scrape))
			fold = 0.5 * (1.0 - _ease(0.2, 0.4, scrape))
		if kicking and label == "LegR":
			swing_x = lerpf(lerpf(0.0, -1.5, wind), -0.55, slash) * kick_leg
			fold = lerpf(lerpf(0.0, 1.7, wind), -0.15, slash) * kick_leg
		hip.rotation.x = lerpf(hip.rotation.x, swing_x, minf(1.0, delta * 20.0))
		knee.rotation.x = lerpf(knee.rotation.x, fold, minf(1.0, delta * 20.0))
	# The body: two bobs a stride, a little roll, leaning into the run; back on its heels to kick.
	var bob := absf(cos(stride)) * (0.1 if running else 0.0)
	var breathe := sin(t * 1.8) * 0.015
	rig.position.y = 1.25 - bob + breathe - 0.12 * float(tell) + 0.06 * wind * (1.0 - slash)
	rig.rotation.z = lerpf(rig.rotation.z, sin(stride) * 0.06 * float(running), k)
	var lean := 0.32 if charging else 0.18 if tell else 0.08 * float(running)
	lean += -0.3 * wind * (1.0 - slash) + 0.15 * slash * kick_leg
	rig.rotation.x = lerpf(rig.rotation.x, lean, minf(1.0, delta * 10.0))
	# The neck: pumping with the stride, low and forward for the display, level in the charge,
	# drawn back for the kick; the head kept level, and when it stands, glancing about in jerks.
	var neck := rig.get_node("Neck") as Node3D
	var upper := neck.get_node("NeckUp") as Node3D
	var head := upper.get_node("Head") as Node3D
	var pump := sin(stride * 2.0) * 0.14 * float(running)
	var bend := (1.15 if charging else 0.85 if tell else 0.2 * float(running)) - 0.45 * wind * (1.0 - slash)
	if ridden:
		bend = maxf(bend, 0.75) # under a rider the neck is carried well forward, clear of the rider
	neck.rotation.x = lerpf(neck.rotation.x, bend + pump, k)
	upper.rotation.x = lerpf(upper.rotation.x, (0.35 if charging else -0.2 if tell else 0.0) - pump * 0.6, k)
	head.rotation.x = lerpf(head.rotation.x, -(neck.rotation.x + upper.rotation.x) * 0.85, k)
	var glance := 0.0
	if not running and not tell and not kicking:
		glance = (floorf(fmod(t * 0.9, 4.0)) - 1.5) * 0.35 # a new look every second or so, snapped to
	head.rotation.y = lerpf(head.rotation.y, glance, minf(1.0, delta * 18.0))
	if tell:
		head.rotation.z = sin(age * 7.0) * 0.12 # a hissing sway
	else:
		head.rotation.z = lerpf(head.rotation.z, 0.0, k)
	# Wings: folded at rest, held out and beating as it runs, spread high for the display, wide in
	# the charge, flared for the kick.
	for label: String in ["WingL", "WingR"]:
		var wing := rig.get_node(label) as Node3D
		var s := -1.0 if label == "WingL" else 1.0
		var open := 0.0
		var lift := 0.0
		if running:
			open = (0.9 if charging else 0.45) + sin(stride * 2.0 + 0.5) * 0.25
		if tell:
			open = 1.1 + sin(age * 9.0) * 0.12
			lift = 0.7
		if kicking:
			open = maxf(open, 1.2 * (wind + slash * 0.5) * kick_leg)
		wing.rotation.z = lerpf(wing.rotation.z, s * open, minf(1.0, delta * 12.0))
		wing.rotation.x = lerpf(wing.rotation.x, -lift, minf(1.0, delta * 10.0))
	var tail := rig.get_node("Tail") as Node3D
	tail.rotation.x = lerpf(tail.rotation.x, (0.25 if charging else -0.35 if tell else 0.0) + cos(stride * 2.0) * 0.12 * float(running), minf(1.0, delta * 12.0))


## The thornback. Walking: diagonal pairs of legs, each lifted and set down heavily, the shell
## rising and settling and rolling a little with each step, the head pushed out ahead, nodding with
## the steps. Standing: slow breathing, the head turning to look. Biting (m_bite): it draws its head
## back and rears its front a little, then lunges, the whole body lurching forward, the head shooting
## out with the beak open, snapping shut; then it settles back.
static func _plod_thornback(rig: Node3D, delta: float, k: float, moving: float, state: String, age: float, t: float) -> void:
	var walking := moving > 0.2
	var step := float(rig.get_meta("step", 0.0)) + delta * 1.3 * TAU * float(walking)
	rig.set_meta("step", fmod(step, TAU * 8.0))
	var biting := state == "m_bite"
	var wind := _ease(0.0, 0.25, age) if biting else 0.0
	var lunge := _ease(0.25, 0.36, age) if biting else 0.0
	var settle := _ease(0.45, 0.85, age) if biting else 0.0
	var strike := lunge * (1.0 - settle)
	var draw := wind * (1.0 - lunge)
	for n in 4:
		var leg := rig.get_node("Leg%d" % n) as Node3D
		var sx := -1.0 if n % 2 == 0 else 1.0
		var front := 1.0 if n < 2 else -1.0
		var phase := step + (0.0 if n in [0, 3] else PI)
		var rest := Vector3(sx * 0.72, 0.35, front * 0.55)
		var lift := maxf(0.0, sin(phase)) * 0.16 * float(walking)
		var swing := -cos(phase) * 0.4 * float(walking)
		if biting and front > 0.0:
			swing = -0.35 * strike + 0.25 * draw # front legs braced for the lunge
		leg.position = rest + Vector3(0, lift, 0)
		leg.rotation.x = lerpf(leg.rotation.x, swing, minf(1.0, delta * 10.0))
	var shell := rig.get_node("Shell") as Node3D
	var thump := (1.0 - absf(sin(step))) * float(walking)
	shell.position.y = 0.5 + 0.06 * (1.0 - thump) + sin(t * 1.2) * 0.012 * float(not walking)
	shell.rotation.z = sin(step) * 0.05 * float(walking)
	shell.rotation.x = lerpf(shell.rotation.x, -0.12 * draw + 0.1 * strike, minf(1.0, delta * 14.0))
	rig.position.z = lerpf(rig.position.z, -0.15 * draw + 0.3 * strike, minf(1.0, delta * 16.0))
	var head := rig.get_node("Head") as Node3D
	var jaw := head.get_node("Jaw") as Node3D
	var out := (0.12 if walking else 0.0) - 0.4 * draw + 0.55 * strike
	head.position.z = lerpf(head.position.z, 1.05 + out, minf(1.0, delta * 22.0))
	head.position.y = 0.5 + 0.04 * sin(step * 2.0) * float(walking) + 0.08 * draw
	head.rotation.x = lerpf(head.rotation.x, 0.08 * sin(step * 2.0) * float(walking) - 0.25 * draw + 0.1 * strike, minf(1.0, delta * 14.0))
	var look := sin(t * 0.45) * 0.45 if not walking and not biting else sin(step * 0.5) * 0.12
	head.rotation.y = lerpf(head.rotation.y, look, minf(1.0, delta * 3.0))
	# The beak: open as it lunges, snapping shut at full reach.
	var gape := 0.55 * _ease(0.15, 0.28, age) * (1.0 - _ease(0.33, 0.38, age)) if biting else 0.0
	jaw.rotation.x = lerpf(jaw.rotation.x, gape, minf(1.0, delta * 30.0))


## Dying. Every one of them dies in stages, the way the beasts of Mesenlla do: a last spasm, the fall,
## the moment it hits the ground, a few twitches, stillness, and then it sinks away. Each frame, `age`
## seconds after it began; side (-1 or 1) is which way it goes over.
##   bees and wasps  a jolt, wings flared and the abdomen curled hard under; they tumble out of the
##                   air, land on their backs with a splash of ichor, legs curl up and twitch.
##   ember moth      one last clap of the wings and a burst of burning dust; it spirals down slowly,
##                   wings limp, and lies spread on the ground, one wing lifting twice, its eyes going out.
##   spider          rears up, front legs raised; slumps onto its belly, legs splayed; rolls onto its
##                   back and its legs fold in over it, twitching.
##   battle ostrich  staggers, legs buckling, neck flung up; drops onto its keel and over onto its
##                   side, neck flopping to the ground, a leg kicking out twice.
##   thornback       a last snap of the beak; head and legs pull into the shell, which drops with a
##                   thud and rocks, then rolls over onto its back, legs paddling at the air; the god's
##                   seams flicker out.
##   snails          the eye-stalks pull in, the head rears and shudders; head and foot shrink into
##                   the shell, which tips over; the mutant snail's seams spill a last pool, the
##                   wasp-snail's nest bursts and its wasps boil out of it.
##   beehive         the comb cracks and sags off its stump, honey bursting, the swarm scattering.
static func fall(z: Zombie, root: Node3D, age: float, delta: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var id := str(root.get_meta("kind", ""))
	var side := float(root.get_meta("side", 1.0))
	var total := death_time(id)
	var sink := clampf((age - (total - 0.6)) / 0.6, 0.0, 1.0)
	match id:
		"mutant_bee", "mutant_wasp": _die_insect(z, root, rig, age, delta, side)
		"ember_moth": _die_moth(z, root, rig, age, delta, side)
		"mutant_spider": _die_spider(z, root, rig, age, delta, side)
		"battle_ostrich": _die_ostrich(z, root, rig, age, delta, side)
		"thornback": _die_thornback(z, root, rig, age, delta, side)
		"mutant_snail", "wasp_hive_snail": _die_snail(z, root, rig, age, delta, side)
		"beehive": _die_hive(z, root, rig, age, delta)
	root.position.y = -sink * (0.9 if id in ["thornback", "beehive", "wasp_hive_snail"] else 0.6)


static func death_time(id: String) -> float:
	match id:
		"mutant_bee", "mutant_wasp": return 2.6
		"ember_moth", "mutant_spider", "beehive": return 3.0
		"battle_ostrich", "mutant_snail", "wasp_hive_snail": return 3.2
		"thornback": return 3.4
	return 3.0


## Once only, the first frame `age` passes `at`.
static func _once(root: Node3D, label: String, age: float, at: float) -> bool:
	if age < at or root.has_meta("did_" + label):
		return false
	root.set_meta("did_" + label, true)
	return true


## Whether the body has come down to the ground yet, and how long ago (-1 still falling).
static func _landed(z: Zombie, root: Node3D, age: float) -> float:
	if z.position.y - z.world.ground_at(z.position) > 0.05:
		return -1.0
	if not root.has_meta("landed_at"):
		root.set_meta("landed_at", age)
	return age - float(root.get_meta("landed_at"))


static func _ease(a: float, b: float, t: float) -> float:
	var k := clampf((t - a) / maxf(b - a, 0.001), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _die_insect(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float, side: float) -> void:
	var abdomen := rig.get_node("Abdomen") as Node3D
	var legs := rig.get_node("Legs") as Node3D
	var head := rig.get_node("Head") as Node3D
	var down := _landed(z, root, age)
	var jolt := _ease(0.0, 0.08, age) * (1.0 - _ease(0.12, 0.3, age))
	if down < 0.0:
		# The jolt, then the tumble: spinning over, wings flared and stuttering, legs clutching.
		var flutter := sin(age * 38.0) * 0.5 * exp(-age * 1.5)
		for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
			var wing := rig.get_node(label) as Node3D
			var s := -1.0 if label.begins_with("WingL") else 1.0
			wing.rotation.z = s * (0.9 + flutter)
			wing.rotation.y = s * 0.4
		rig.rotation.z += delta * side * (3.0 + age * 6.0)
		rig.rotation.x = lerpf(rig.rotation.x, 0.6, minf(1.0, delta * 4.0))
		rig.position.y = 0.55 + jolt * 0.15
		abdomen.rotation.x = lerpf(abdomen.rotation.x, -1.1, minf(1.0, delta * 16.0))
		legs.rotation.x = lerpf(legs.rotation.x, 0.9, minf(1.0, delta * 10.0))
		return
	if _once(root, "splash", age, 0.0):
		z.world.fx_gore(z.position + Vector3.UP * 0.2, GOD_GREEN.lerp(AMBER, 0.5) if z.model_id == "mutant_bee" else GOD_GREEN)
		z.world.show_ring(z.position + Vector3.UP * 0.05, 0.6, GOD.darkened(0.3))
	# On its back: the body rolls over and settles, wings flat out, legs curled up and twitching.
	var settle := _ease(0.0, 0.35, down)
	rig.rotation.z = lerpf(rig.rotation.z, side * PI * 0.92, minf(1.0, delta * 10.0))
	rig.rotation.x = lerpf(rig.rotation.x, 0.0, minf(1.0, delta * 8.0))
	rig.position.y = lerpf(0.55, 0.3, settle) + absf(sin(down * 9.0)) * 0.12 * exp(-down * 6.0) # a bounce
	for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
		var wing := rig.get_node(label) as Node3D
		var s := -1.0 if label.begins_with("WingL") else 1.0
		wing.rotation.z = lerpf(wing.rotation.z, s * -0.15, minf(1.0, delta * 8.0))
		wing.rotation.y = lerpf(wing.rotation.y, s * 0.6, minf(1.0, delta * 6.0))
	var twitch := sin(down * 24.0) * 0.35 * _ease(0.2, 0.3, down) * (1.0 - _ease(0.9, 1.6, down))
	legs.rotation.x = 1.35 + twitch
	legs.scale = Vector3(1.0, lerpf(1.0, 0.65, settle), 1.0)
	abdomen.rotation.x = -0.5 * (1.0 - settle) + sin(down * 17.0) * 0.12 * (1.0 - _ease(0.6, 1.3, down))
	head.rotation.x = lerpf(head.rotation.x, 0.4, settle)
	_fade_glow(rig, 1.0 - _ease(0.8, 1.8, down))


static func _die_moth(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float, side: float) -> void:
	var down := _landed(z, root, age)
	if _once(root, "dust", age, 0.12):
		z.world.fx_rise(z.position + Vector3.UP * 0.6, MOTH_DUST)
	if down < 0.0:
		# One last clap, then the wings go limp and it spirals down, slowly.
		var clap := sin(_ease(0.0, 0.3, age) * PI)
		for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
			var wing := rig.get_node(label) as Node3D
			var s := -1.0 if label.begins_with("WingL") else 1.0
			var limp := 0.25 + sin(age * 4.0) * 0.1
			wing.rotation.z = lerpf(wing.rotation.z, s * (clap * 1.3 + limp * (1.0 - clap)), minf(1.0, delta * 14.0))
		root.rotation.y += delta * side * 2.2
		rig.rotation.z = lerpf(rig.rotation.z, side * 0.5, minf(1.0, delta * 2.0))
		rig.rotation.x = lerpf(rig.rotation.x, 0.35, minf(1.0, delta * 2.0))
		return
	if _once(root, "thud", age, 0.0):
		z.world.fx_gore(z.position + Vector3.UP * 0.1, MOTH_DUST.darkened(0.2))
	# Spread on the ground, wings flat; one wing lifts twice, feebly; the eye-spots go out.
	var settle := _ease(0.0, 0.4, down)
	rig.rotation.z = lerpf(rig.rotation.z, side * 0.12, settle)
	rig.rotation.x = lerpf(rig.rotation.x, 0.08, settle)
	rig.position.y = lerpf(rig.position.y, 0.12, minf(1.0, delta * 6.0))
	var lift := absf(sin(_ease(0.5, 1.5, down) * TAU)) * 0.45 * (1.0 - _ease(1.2, 1.6, down))
	for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
		var wing := rig.get_node(label) as Node3D
		var s := -1.0 if label.begins_with("WingL") else 1.0
		var raise := lift if (s > 0.0) == (side > 0.0) and not label.ends_with("2") else 0.0
		wing.rotation.z = lerpf(wing.rotation.z, s * (-0.06 + raise), minf(1.0, delta * 10.0))
	_fade_glow(rig, 1.0 - _ease(0.6, 1.6, down))


static func _die_spider(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float, side: float) -> void:
	# Rearing (0-0.45), slumped (0.45-0.9), over onto its back (0.9-1.5), legs folding in, twitching.
	var rear := sin(_ease(0.0, 0.45, age) * PI) * (1.0 - _ease(0.4, 0.6, age))
	var slump := _ease(0.4, 0.75, age)
	var over := _ease(0.9, 1.45, age)
	if _once(root, "slump", age, 0.62):
		z.world.fx_gore(z.position + Vector3.UP * 0.3, GOD.darkened(0.35))
	if _once(root, "over", age, 1.4):
		z.world.show_ring(z.position + Vector3.UP * 0.05, 1.0, GOD.darkened(0.4))
	rig.rotation.x = -0.55 * rear
	rig.rotation.z = side * PI * over
	rig.position.y = lerpf(0.55 + rear * 0.15, 0.22, slump) + over * 0.5 + sin(over * PI) * 0.25
	var twitch_on := _ease(1.4, 1.5, age) * (1.0 - _ease(2.0, 2.5, age))
	for leg_side: String in ["L", "R"]:
		var s := -1.0 if leg_side == "L" else 1.0
		for n in 4:
			var hip := rig.get_node("Leg%s%d" % [leg_side, n]) as Node3D
			var knee := hip.get_node("Knee") as Node3D
			var raised := rear * (0.9 if n < 2 else 0.0)
			var splay := slump * (1.0 - over) * 0.35
			var curl := over
			var twitch := sin(age * 21.0 + n * 1.7 + s) * 0.3 * twitch_on
			hip.rotation.z = s * (-raised * 0.8 + splay - curl * 0.75 + twitch)
			hip.rotation.x = (-0.5 if n < 2 else 0.0) * raised
			knee.rotation.z = s * (-0.2 * raised + curl * 2.3 + twitch * 0.6)
	_fade_glow(rig, 1.0 - _ease(1.6, 2.4, age))


static func _die_ostrich(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float, side: float, at := Vector3.INF) -> void:
	var where := z.position if at == Vector3.INF else at # (a fallen mount lies where it fell, not under its rider)
	var neck := rig.get_node("Neck") as Node3D
	var upper := neck.get_node("NeckUp") as Node3D
	var head := upper.get_node("Head") as Node3D
	# Struck (0-0.15), a stagger, the legs buckling (to 0.4); dropping onto its keel (0.3-0.75) and
	# over onto its side (0.6-1.05); a leg kicks.
	var struck := sin(_ease(0.0, 0.3, age) * PI)
	var stagger := _ease(0.05, 0.4, age)
	var drop := _ease(0.3, 0.75, age)
	var over := _ease(0.6, 1.05, age)
	if _once(root, "thud", age, 0.95):
		z.world.fx_gore(where + Vector3.UP * 0.4, Color(0.45, 0.4, 0.34))
		z.world.show_ring(where + Vector3.UP * 0.05, 1.4, Color(0.55, 0.5, 0.42))
	var lurch := sin(stagger * PI) * (1.0 - drop)
	rig.position.y = lerpf(1.25, 0.5, drop) - lurch * 0.15 + absf(sin(_ease(0.95, 1.3, age) * PI)) * 0.08
	rig.position.x = side * lurch * 0.3
	rig.rotation.x = -0.35 * struck + 0.25 * lurch + 0.15 * drop * (1.0 - over)
	rig.rotation.z = side * (0.25 * lurch + 1.35 * over)
	# The neck flung back as it is struck, whipping forward as it goes down, and once down the long
	# neck lies curved along the ground, the head turned over at its end.
	# (Rolled onto its side, the ground lies off the rig's -X for side 1: the neck is swung round
	# towards it about its yaw, and the upper neck curls the same way.)
	neck.rotation.x = -0.8 * struck + lerpf(0.0, 1.35, drop)
	neck.rotation.y = -side * 0.75 * over
	upper.rotation.x = -0.5 * struck + 0.6 * drop - 0.5 * over
	upper.rotation.z = side * 0.7 * over
	head.rotation.x = 0.4 * struck - 0.2 * drop + 0.3 * over
	head.rotation.z = side * 0.9 * over
	var kicks := sin(_ease(1.3, 2.1, age) * TAU * 2.0) * 0.5 * (1.0 - _ease(1.9, 2.3, age))
	for label: String in ["LegL", "LegR"]:
		var hip := rig.get_node(label) as Node3D
		var knee := hip.get_node("Knee") as Node3D
		var near := (label == "LegR") == (side > 0.0)
		# Buckling: thighs forward, shanks folding back; once down, the legs stiffen out and one kicks.
		var buckle := (0.7 if near else 1.0) * stagger * (1.0 - over)
		hip.rotation.x = -buckle - 0.5 * over + (kicks if not near else 0.0)
		knee.rotation.x = 1.3 * buckle * (1.0 - over) + 0.25 * over + (absf(kicks) * 0.6 if not near else 0.0)
	_fade_glow(rig, 1.0 - _ease(1.6, 2.4, age))


static func _die_thornback(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float, side: float) -> void:
	var head := rig.get_node("Head") as Node3D
	# The last snap (0-0.3); head and legs drawn in (0.3-0.8); down with a thud (0.75-0.9); then its
	# own weight rolls it over the edge of a stone onto its back (1.1-1.7), where the legs come out
	# again and paddle at the air, slower and slower, and stop.
	var snap := sin(_ease(0.0, 0.3, age) * PI)
	var withdraw := _ease(0.3, 0.8, age) * (1.0 - _ease(1.5, 1.8, age))
	var drop := _ease(0.75, 0.9, age)
	var over := _ease(1.1, 1.7, age)
	if _once(root, "thud", age, 0.88):
		z.world.fx_gore(z.position + Vector3.UP * 0.2, LIMESTONE.darkened(0.3))
		z.world.show_ring(z.position + Vector3.UP * 0.05, 1.8, LIMESTONE.darkened(0.2))
	if _once(root, "roll", age, 1.65):
		z.world.fx_gore(z.position + Vector3(side * 0.6, 0.3, 0), LIMESTONE.darkened(0.2))
	head.position.z = 1.05 + snap * 0.45 - withdraw * 0.55
	head.scale = Vector3.ONE * lerpf(1.0, 0.6, withdraw)
	head.rotation.x = -0.4 * snap + 0.25 * withdraw + 0.5 * over
	var paddle := sin(maxf(0.0, age - 1.6) * 7.0) * 0.6 * _ease(1.6, 1.75, age) * (1.0 - _ease(2.2, 2.7, age))
	for n in 4:
		var leg := rig.get_node("Leg%d" % n) as Node3D
		var sx := -1.0 if n % 2 == 0 else 1.0
		var front := 1.0 if n < 2 else -1.0
		leg.position = Vector3(sx * 0.72, 0.35, front * 0.55).lerp(Vector3(sx * 0.5, 0.45, front * 0.4), withdraw)
		leg.scale = Vector3.ONE * lerpf(1.0, 0.25, withdraw)
		leg.rotation.x = paddle * (1.0 if n in [0, 3] else -1.0)
	# Down, a rocking that dies away, then over: lifted onto the edge of its shell and onto its dome.
	var rock := sin(maxf(0.0, age - 0.9) * 11.0) * 0.07 * exp(-maxf(0.0, age - 0.9) * 3.0) * drop * (1.0 - over)
	rig.rotation.z = side * (rock + PI * 0.94 * over)
	rig.rotation.x = rock * 0.6
	rig.position.y = -0.25 * drop * (1.0 - over) + sin(over * PI) * 0.9 + over * 1.05
	rig.position.x = side * 0.7 * sin(over * PI * 0.5)
	# The god's seams flicker and go out.
	var left := 1.0 - _ease(1.8, 2.6, age)
	_fade_glow(rig, left * (0.4 + 0.6 * float(fmod(age * 13.0, 1.0) > 0.3)) if age > 1.8 else 1.0)


static func _die_snail(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float, side: float) -> void:
	var foot := rig.get_node("Foot") as Node3D
	var neck := foot.get_node("Neck") as Node3D
	var shell := foot.get_node("Shell") as Node3D
	var nest := z.model_id == "wasp_hive_snail"
	# Stalks pull in and the head rears, shuddering (0-0.6); everything shrinks into the shell
	# (0.5-1.3); the shell tips over (1.1-1.6).
	var rear := sin(_ease(0.0, 0.6, age) * PI)
	var shrink := _ease(0.5, 1.3, age)
	var tip := _ease(1.1, 1.6, age)
	for label: String in ["StalkL", "StalkR"]:
		var stalk := neck.get_node(label) as Node3D
		stalk.scale = Vector3.ONE * lerpf(1.0, 0.15, _ease(0.0, 0.4, age))
		stalk.rotation.x = 0.6 * _ease(0.0, 0.4, age)
	neck.rotation.x = -0.5 * rear + sin(age * 30.0) * 0.06 * rear
	neck.position.z = lerpf(0.95, 0.15, shrink)
	neck.scale = Vector3.ONE * lerpf(1.0, 0.3, shrink)
	foot.scale = Vector3(lerpf(1.0, 0.75, shrink), lerpf(1.0, 0.35, shrink), lerpf(1.0, 0.6, shrink))
	shell.position.y = lerpf(0.25, 0.12, shrink) / foot.scale.y # the shell settles a little as the foot shrinks under it
	shell.scale = Vector3(1.0 / foot.scale.x, 1.0 / foot.scale.y, 1.0 / foot.scale.z) # (and keeps its size)
	rig.rotation.z = side * 0.9 * tip
	rig.position.y = sin(tip * PI) * 0.15
	if _once(root, "spill", age, 0.55):
		if nest:
			z.world.fx_gore(z.position + Vector3.UP * 1.2, PAPER)
		else:
			z.world.fx_gore(z.position + Vector3.UP * 0.4, FontaMind.trail_colour(z))
			z.world.show_ring(z.position + Vector3.UP * 0.05, 1.5, FontaMind.trail_colour(z))
	if _once(root, "thud", age, 1.55):
		z.world.fx_gore(z.position + Vector3.UP * 0.3, SNAIL_SKIN)
	if nest:
		# The nest bursts: its wasps boil out and scatter.
		var crawlers := shell.get_node_or_null("Crawlers") as Node3D
		if crawlers:
			var burst := _ease(0.35, 0.8, age)
			crawlers.scale = Vector3.ONE * (1.0 + burst * 0.35)
			crawlers.position.y = burst * 0.5
			crawlers.rotation.y += delta * 5.0 * burst
			crawlers.visible = burst < 0.95
		if _once(root, "swarm", age, 0.7):
			z.world.fx_rise(z.position + Vector3.UP * 1.4, YELLOW)
	_fade_glow(rig, 1.0 - _ease(1.0, 2.0, age))


static func _die_hive(z: Zombie, root: Node3D, rig: Node3D, age: float, delta: float) -> void:
	var comb := rig.get_node("Comb") as Node3D
	var swarm := rig.get_node("Swarm") as Node3D
	# It shudders (0-0.4), cracks and sags off the stump (0.35-1.2), the swarm flies apart.
	var shake := (1.0 - _ease(0.3, 0.45, age)) * sin(age * 50.0) * 0.08
	var sag := _ease(0.35, 1.2, age)
	if _once(root, "crack", age, 0.4):
		z.world.fx_gore(z.position + Vector3.UP * 1.4, HONEY)
	if _once(root, "land", age, 1.15):
		z.world.fx_gore(z.position + Vector3.UP * 0.4, HONEY.darkened(0.2))
		z.world.show_ring(z.position + Vector3.UP * 0.05, 1.6, HONEY.darkened(0.3))
	comb.rotation.z = shake + 0.55 * sag
	comb.position.y = -0.7 * sag
	comb.position.x = 0.35 * sag
	swarm.scale = Vector3.ONE * (1.0 + _ease(0.2, 1.6, age) * 3.5)
	swarm.position.y += delta * 1.5
	swarm.rotation.y += delta * 5.0
	swarm.visible = age < 1.8
	_fade_glow(rig, 1.0 - _ease(0.8, 1.8, age))


## The god's glow going out of a dead thing: every lit part shrinks away as `left` falls to 0.
static func _fade_glow(rig: Node3D, left: float) -> void:
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		if part.material_override == MesenllaModels.glow_material() or part.name == "Seams" or part.has_meta("glow"):
			part.set_meta("glow", true)
			part.visible = left > 0.02
