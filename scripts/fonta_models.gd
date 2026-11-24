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
		_part(shell, "nest_crawlers", func(l: LowPoly) -> void:
			var r := RandomNumberGenerator.new()
			r.seed = 137
			for k in 9:
				var a := r.randf() * TAU
				var y := r.randf_range(0.3, 1.5)
				var w := 0.62 * sin(clampf((y - 0.15) / 1.7, 0.0, 1.0) * PI) + 0.16
				var at := Vector3(cos(a) * w, y, sin(a) * w)
				l.prism(at, at + Vector3(0, 0.03, 0.12).rotated(Vector3.UP, a), 0.035, 0.02, 4, YELLOW if k % 2 else WASP_RED))
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
	_part(rig, "ostrich_plumes", func(l: LowPoly) -> void:
		# The wings: fans of white plumes held half out from the flanks, grey at their roots.
		for side: float in [-1.0, 1.0]:
			var shoulder := Vector3(side * 0.4, 0.12, 0.22)
			for f in 7:
				var a := -0.2 + f * 0.22
				var tip := shoulder + Vector3(side * (0.32 + 0.06 * sin(f)), -0.15 - f * 0.05, -0.25 - f * 0.11).rotated(Vector3.FORWARD, side * a * 0.2)
				var mid := shoulder.lerp(tip, 0.45)
				var w := Vector3(0, 0.07, 0.06)
				l.leaf(shoulder, mid + w, mid - w, PLUME.darkened(0.35))
				l.leaf(shoulder, mid - w, mid + w, PLUME.darkened(0.35))
				l.leaf(mid + w, tip, mid - w, PLUME.darkened(0.03 * f))
				l.leaf(mid - w, tip, mid + w, PLUME.darkened(0.03 * f))
		# The tail: a fountain of white plumes, up and back.
		for f in 8:
			var a := -0.75 + f * 0.21
			var root_at := Vector3(sin(a) * 0.12, 0.18, -0.62)
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
		l.prism(Vector3(0, 0.0, 0.15), Vector3(0, -0.06, 0.42), 0.22, 0.08, 8, Color(0.5, 0.47, 0.34))
		l.prism(Vector3(0, -0.06, 0.38), Vector3(0, -0.14, 0.5), 0.08, 0.0, 5, BLACK))
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


## The ostrich running: long legs scissoring, neck pumping; the tell (m_cast) paws the ground with
## its head held low and forward; the charge (m_charge) stretches it flat out; a kick (m_bite) swings
## one leg forward hard.
static func _run_ostrich(z: Zombie, rig: Node3D, delta: float, k: float, moving: float, state: String, tell: bool, age: float, t: float) -> void:
	var charging := state == "m_charge"
	var stride := t * (moving * 1.9 if moving > 0.2 else 0.0) + float(rig.get_meta("stride", 0.0))
	var reach := 0.75 if charging else clampf(moving / 6.0, 0.15, 0.6)
	var kick := 0.0
	if z._attack_left > 0.0:
		kick = sin(clampf(1.0 - z._attack_left / 0.5, 0.0, 1.0) * PI)
	for label: String in ["LegL", "LegR"]:
		var hip := rig.get_node(label) as Node3D
		var knee := hip.get_node("Knee") as Node3D
		var phase := stride + (0.0 if label == "LegL" else PI)
		var swing := sin(phase) * reach if moving > 0.2 else 0.0
		if tell and label == "LegR":
			swing = sin(age * 9.0) * 0.35 - 0.2 # pawing
		if label == "LegR" and kick > 0.0:
			swing = -kick * 1.2
		hip.rotation.x = lerpf(hip.rotation.x, swing, minf(1.0, delta * 18.0))
		knee.rotation.x = lerpf(knee.rotation.x, maxf(0.0, -cos(phase)) * reach * 0.9 if moving > 0.2 else 0.0, minf(1.0, delta * 18.0))
	rig.position.y = 1.25 + absf(sin(stride)) * (0.12 if moving > 0.2 else 0.0)
	rig.rotation.x = lerpf(rig.rotation.x, 0.3 if charging else 0.12 if tell else 0.0, k)
	var neck := rig.get_node("Neck") as Node3D
	var upper := neck.get_node("NeckUp") as Node3D
	neck.rotation.x = lerpf(neck.rotation.x, (1.0 if charging else 0.7 if tell else 0.0) + sin(stride * 2.0) * 0.12 * minf(1.0, moving / 4.0), k)
	upper.rotation.x = lerpf(upper.rotation.x, (0.3 if charging else 0.0) - sin(stride * 2.0) * 0.08, k)
	(upper.get_node("Head") as Node3D).rotation.x = lerpf((upper.get_node("Head") as Node3D).rotation.x, -neck.rotation.x * 0.8, k)


## The thornback plodding: legs in slow diagonal pairs, the shell swaying; snapping, it shoots its
## head out.
static func _plod_thornback(rig: Node3D, delta: float, k: float, moving: float, state: String, age: float, t: float) -> void:
	var step := t * (2.2 if moving > 0.2 else 0.0)
	for n in 4:
		var leg := rig.get_node("Leg%d" % n) as Node3D
		var phase := step + (0.0 if n in [0, 3] else PI)
		leg.rotation.x = sin(phase) * 0.35 if moving > 0.2 else 0.0
	(rig.get_node("Shell") as Node3D).rotation.z = sin(step) * 0.04
	var head := rig.get_node("Head") as Node3D
	var snap := exp(-age * 7.0) if state == "m_bite" else 0.0
	head.position.z = lerpf(head.position.z, 1.05 + snap * 0.45, minf(1.0, delta * 20.0))
	head.rotation.y = sin(t * 0.6) * 0.25


## Dying: flyers tumble down, wings limp; the hive sags and its swarm scatters; snails sink into their
## shells and collapse; the spider curls its legs in; the ostrich and the thornback fall over.
static func fall(root: Node3D, age: float, delta: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var id := str(root.get_meta("kind", ""))
	var k := minf(1.0, delta * 5.0)
	match id:
		"mutant_bee", "mutant_wasp", "ember_moth":
			rig.rotation.z += delta * 6.0 * exp(-age * 0.8)
			rig.rotation.x = lerpf(rig.rotation.x, 1.1, k)
			rig.position.y = maxf(0.1, rig.position.y - delta * 2.5)
			for label: String in ["WingL", "WingR", "WingL2", "WingR2"]:
				if rig.has_node(label):
					var side := -1.0 if label.begins_with("WingL") else 1.0
					(rig.get_node(label) as Node3D).rotation.z = lerpf((rig.get_node(label) as Node3D).rotation.z, side * -0.6, k)
		"beehive":
			(rig.get_node("Comb") as Node3D).position.y = lerpf((rig.get_node("Comb") as Node3D).position.y, 0.6, k * 0.5)
			(rig.get_node("Comb") as Node3D).rotation.z = lerpf((rig.get_node("Comb") as Node3D).rotation.z, 0.5, k * 0.5)
			var swarm := rig.get_node("Swarm") as Node3D
			swarm.scale = Vector3.ONE * (1.0 + age * 2.0)
			swarm.position.y += delta * 2.0
		"mutant_snail", "wasp_hive_snail":
			var foot := rig.get_node("Foot") as Node3D
			foot.scale.y = lerpf(foot.scale.y, 0.4, k)
			(foot.get_node("Neck") as Node3D).position.z = lerpf((foot.get_node("Neck") as Node3D).position.z, 0.4, k)
			rig.rotation.z = lerpf(rig.rotation.z, 0.35, k * 0.5)
		"mutant_spider":
			rig.rotation.z = lerpf(rig.rotation.z, PI, k * 0.7)
			rig.position.y = lerpf(rig.position.y, 0.5, k)
			for side: String in ["L", "R"]:
				for n in 4:
					var hip := rig.get_node("Leg%s%d" % [side, n]) as Node3D
					hip.rotation.z = lerpf(hip.rotation.z, (-1.0 if side == "L" else 1.0) * 0.9, k)
					(hip.get_node("Knee") as Node3D).rotation.z = lerpf((hip.get_node("Knee") as Node3D).rotation.z, (-1.0 if side == "L" else 1.0) * -1.2, k)
		"battle_ostrich":
			rig.rotation.z = lerpf(rig.rotation.z, 1.4, k * 0.6)
			rig.position.y = lerpf(rig.position.y, 0.55, k * 0.6)
			(rig.get_node("Neck") as Node3D).rotation.x = lerpf((rig.get_node("Neck") as Node3D).rotation.x, 1.4, k)
		"thornback":
			(rig.get_node("Head") as Node3D).position.z = lerpf((rig.get_node("Head") as Node3D).position.z, 0.6, k)
			for n in 4:
				(rig.get_node("Leg%d" % n) as Node3D).scale = Vector3.ONE * maxf(0.2, 1.0 - age)
			rig.rotation.z = lerpf(rig.rotation.z, 0.25, k * 0.4)
	if age > 2.0:
		root.position.y -= delta * 0.6


static func death_time(id: String) -> float:
	match id:
		"beehive": return 2.8
		"mutant_bee", "mutant_wasp": return 2.0
	return 2.6
