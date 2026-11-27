class_name GodModels
## Al'quimelea, the fallen god of change and experimentation, who made Fontanova's mutants: built from
## LowPoly parts on a rig of pivots, and moved through MesenllaModels like the Kraken.
##
## It floats, HOVER metres up, over a column of its own elixir pouring down to the ground and turning
## as it pours. Its body is a robed torso half grown over with honeycomb wax and violet crystal, a
## crucible glowing in its chest; its face a golden mask with three eyes under a crown of rays, a halo of
## flasks turning round its head. Its left arm ends not in a hand but in a glass retort; its right is
## too long, jointed twice, its claw five fingers too long. Broken wings of wax cells hang behind it,
## crystal shards orbit it. Below half its health a second face opens on its shoulder.
##
## What it is doing is Zombie._current_anim, sent to every phone:
##   m_rise   coming down from its temple (the whole rig sinks to its hover)
##   m_cast   the retort raised and tipped: elixir rains on everyone
##   m_slam   both arms thrust down, claw spread: fields of change open under each of you
##   m_sweep  arms flung wide, back arched, the crucible blazing: the nova round it
##   m_ink    the claw pointing at the furthest of you, the shards drawn into a line: the crystal lance
##   m_roar   head thrown back, wings and halo spread wide: mutants born of it

const KINDS := ["alquimelea"]
const SIZE := 1.6 # the whole of it, against the measures it is built in
const HOVER := 4.6 # metres above the ground that its body floats (its hem a metre over the pool)
const RISE_FROM := 14.0 # metres higher than that, where it comes down from
const RISE_TIME := 3.0

const ROBE := Color(0.16, 0.08, 0.2)
const ROBE_LIGHT := Color(0.3, 0.16, 0.36)
const WAX := Color(0.94, 0.78, 0.4)
const WAX_DARK := Color(0.66, 0.46, 0.16)
const GOLD := Color(0.95, 0.74, 0.3)
const GOLD_DARK := Color(0.55, 0.36, 0.1)
const FLESH := Color(0.62, 0.52, 0.56) # where it is still anything like a body
const CRYSTAL := Color(0.62, 0.36, 0.95)
const ELIXIR := Color(0.45, 1.0, 0.5)
const EYE := Color(0.88, 0.62, 1.0)
const GLASS := Color(0.78, 0.92, 0.88)


static func _pivot(parent: Node3D, at: Vector3, label: String) -> Node3D:
	return MesenllaModels._pivot(parent, at, label)


static func _part(parent: Node3D, key: String, draw: Callable, lit := false) -> MeshInstance3D:
	var mi := MesenllaModels._part(parent, MesenllaModels._mesh("god_" + key, draw))
	if lit:
		mi.material_override = MesenllaModels.glow_material()
	return mi


static var _pour: StandardMaterial3D
## The elixir it stands on: lit from within, half clear, adding to what is behind it.
static func pour_material() -> StandardMaterial3D:
	if _pour == null:
		_pour = StandardMaterial3D.new()
		_pour.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pour.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pour.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_pour.albedo_color = Color(0.36, 0.95, 0.42, 0.32)
		_pour.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pour.disable_fog = true
	return _pour


## A honeycomb cell standing out of a surface at `at`, facing `out`.
static func _cell(l: LowPoly, at: Vector3, out: Vector3, r: float, col: Color, deep := 0.08) -> void:
	l.prism(at - out * deep, at + out * deep * 0.4, r, r * 0.92, 6, col)
	l.prism(at + out * deep * 0.4, at + out * deep * 0.1, r * 0.7, r * 0.6, 6, col.darkened(0.45))


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", id)
	var rig := _pivot(root, Vector3(0, HOVER, 0), "Rig")
	rig.scale = Vector3.ONE * SIZE
	_body(rig)
	_head(rig)
	_arms(rig)
	_wings(rig)
	_pour_column(root)
	_shards(rig)
	return root


static func _body(rig: Node3D) -> void:
	var body := _pivot(rig, Vector3.ZERO, "Body")
	_part(body, "body", func(l: LowPoly) -> void:
		# The robe: long, narrowing to where the elixir pours out of it, ragged at the hem.
		l.ovoid(Vector3(0, 1.2, 0), Vector3(1.25, 1.55, 0.95), ROBE, ROBE.darkened(0.3), 7, 16)
		l.prism(Vector3(0, 0.2, 0), Vector3(0, -1.4, 0), 1.05, 0.35, 14, ROBE.darkened(0.1))
		for k in 12:
			var a := TAU * k / 12.0
			var long := 0.5 + 0.35 * absf(sin(k * 2.3))
			var at := Vector3(sin(a) * 0.55, -1.2, cos(a) * 0.5)
			l.prism(at, at + Vector3(sin(a) * 0.15, -long, cos(a) * 0.15), 0.2, 0.02, 4, ROBE_LIGHT.darkened(0.2 * (k % 2)))
		# A collar of gold and bronze cells, the god's own.
		l.prism(Vector3(0, 2.45, 0), Vector3(0, 2.6, 0), 0.95, 0.75, 14, GOLD_DARK)
		for k in 14:
			var a := TAU * k / 14.0
			_cell(l, Vector3(sin(a) * 0.9, 2.5, cos(a) * 0.8), Vector3(sin(a), 0.3, cos(a)).normalized(), 0.11, GOLD)
		# Half of it grown over with wax: the cells crowd up the right side and over the shoulder.
		for row in 9:
			for col in 8:
				var a := 0.55 + col * 0.3 + (0.15 if row % 2 else 0.0) # from the right of its chest round its back
				var y := 0.1 + row * 0.27
				var wide := 1.25 * sqrt(maxf(0.05, 1.0 - pow((y - 1.2) / 1.6, 2)))
				if (row + col * 0.7 < 2.0) or (row > 6 and col < 3):
					continue # a ragged edge where the wax stops
				var out := Vector3(sin(a), 0.1, cos(a)).normalized()
				_cell(l, Vector3(sin(a) * wide, y, cos(a) * wide * 0.76), out, 0.13, WAX.darkened(0.06 * ((row + col) % 3)))
		# And on the other side, where it is still something like a body: grey flesh showing through
		# the torn robe, ribs under it.
		for k in 4:
			l.prism(Vector3(-0.6, 1.4 - k * 0.22, 0.62), Vector3(-1.02, 1.32 - k * 0.22, 0.2), 0.06, 0.04, 5, FLESH.darkened(0.1 * k)))
	# The crucible in its chest, and the crystal growths round it.
	var crucible := _pivot(body, Vector3(0.0, 1.45, 0.78), "Crucible")
	_part(crucible, "crucible_rim", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.12), Vector3(0, 0, 0.14), 0.52, 0.46, 12, GOLD_DARK)
		for k in 8:
			var a := TAU * k / 8.0
			l.prism(Vector3(cos(a) * 0.48, sin(a) * 0.48, 0.1), Vector3(cos(a) * 0.62, sin(a) * 0.62, 0.02), 0.06, 0.0, 4, GOLD))
	_part(crucible, "crucible_glow", func(l: LowPoly) -> void:
		l.ovoid(Vector3(0, 0, 0.12), Vector3(0.4, 0.4, 0.16), ELIXIR, ELIXIR.darkened(0.3), 4, 12), true)
	_part(body, "crystals", func(l: LowPoly) -> void:
		for spot: Array in [[Vector3(-0.95, 2.3, 0.1), Vector3(-0.6, 1.0, 0.2), 0.22], [Vector3(-0.9, 2.1, -0.4), Vector3(-0.5, 0.8, -0.6), 0.16],
				[Vector3(-1.05, 1.7, 0.35), Vector3(-0.9, 0.3, 0.6), 0.14], [Vector3(0.4, 0.5, 0.85), Vector3(0.5, -0.3, 0.9), 0.12], [Vector3(-0.3, 2.55, -0.55), Vector3(-0.2, 1.0, -0.9), 0.18]]:
			var base: Vector3 = spot[0]
			var tip: Vector3 = base + (spot[1] as Vector3)
			l.prism(base, tip, float(spot[2]), 0.0, 6, CRYSTAL)
			l.prism(base, base + (spot[1] as Vector3) * 0.45, float(spot[2]) * 0.6, 0.0, 6, CRYSTAL.lightened(0.3)), true)
	# The second face: shut until it is half gone, then it opens on the left shoulder.
	var second := _pivot(body, Vector3(-0.95, 2.35, 0.45), "Second")
	second.rotation = Vector3(0, -0.6, 0.35)
	_part(second, "second_face", func(l: LowPoly) -> void:
		l.ovoid(Vector3.ZERO, Vector3(0.36, 0.42, 0.14), GOLD.darkened(0.1), GOLD_DARK, 4, 10)
		l.box(Vector3(0, -0.2, 0.12), Vector3(0.18, 0.05, 0.04), Color(0.08, 0.02, 0.06)))
	_part(second, "second_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.13, 0.13]:
			l.box(Vector3(x, 0.06, 0.14), Vector3(0.1, 0.05, 0.03), EYE), true)
	second.scale = Vector3.ONE * 0.01
	second.visible = false


static func _head(rig: Node3D) -> void:
	var head := _pivot(rig, Vector3(0, 2.75, 0.1), "Head")
	_part(head, "mask", func(l: LowPoly) -> void:
		# A long golden mask, calm, cracked from crown to chin; dark behind it.
		# A hood of its robe behind the mask, close round it.
		l.ovoid(Vector3(0, 0.72, -0.12), Vector3(0.62, 0.86, 0.5), ROBE.darkened(0.2), ROBE.darkened(0.4), 6, 14)
		l.prism(Vector3(0, 0.0, -0.1), Vector3(0, 0.5, -0.15), 0.72, 0.6, 12, ROBE)
		l.ovoid(Vector3(0, 0.75, 0.3), Vector3(0.66, 0.95, 0.3), GOLD, GOLD_DARK, 5, 14)
		l.box(Vector3(0, 0.62, 0.6), Vector3(0.09, 0.32, 0.06), GOLD.lightened(0.15))
		l.box(Vector3(0, 0.25, 0.56), Vector3(0.3, 0.05, 0.04), GOLD_DARK)
		for k in 6:
			l.box(Vector3(0.05 + sin(k * 1.7) * 0.05, 1.45 - k * 0.22, 0.56 - absf(k - 2.5) * 0.02), Vector3(0.03, 0.24, 0.03), Color(0.08, 0.02, 0.08), Vector3(0, 0, 10.0 * sin(k * 2.1)))
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.24, 0.82, 0.58), Vector3(0.24, 0.08, 0.04), Color(0.05, 0.02, 0.05))
		l.prism(Vector3(0, 1.22, 0.5), Vector3(0, 1.22, 0.62), 0.12, 0.12, 8, GOLD_DARK)
		# The crown: rays of gold and crystal round the back of its head.
		for k in 13:
			var a := -1.45 + k * (2.9 / 12.0)
			var root_at := Vector3(sin(a) * 0.62, 1.1 + cos(a) * 0.55, -0.35)
			var tip := root_at + Vector3(sin(a), cos(a), -0.1).normalized() * (0.7 + 0.35 * float(k % 2 == 0))
			l.prism(root_at, tip, 0.08, 0.0, 4, GOLD if k % 2 == 0 else GOLD_DARK))
	var eyes := _part(head, "eyes", func(l: LowPoly) -> void:
		for side: float in [-1.0, 1.0]:
			l.box(Vector3(side * 0.24, 0.82, 0.6), Vector3(0.18, 0.05, 0.03), EYE)
		l.prism(Vector3(0, 1.22, 0.6), Vector3(0, 1.22, 0.66), 0.09, 0.07, 8, EYE), true)
	eyes.name = "Eyes"
	# The halo: its flasks turning round its head.
	var halo := _pivot(head, Vector3(0, 1.0, -0.45), "Halo")
	halo.rotation.x = -0.35
	for k in 9:
		var a := TAU * k / 9.0
		var flask := _pivot(halo, Vector3(cos(a) * 1.55, 0, sin(a) * 1.55), "Flask%d" % k)
		_part(flask, "flask_glass", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.18, 0), Vector3(0, 0.34, 0), 0.05, 0.04, 6, GLASS)
			l.prism(Vector3(0, 0.34, 0), Vector3(0, 0.38, 0), 0.06, 0.05, 6, Color(0.6, 0.2, 0.15)))
		_part(flask, "flask_%d" % (k % 3), func(l: LowPoly) -> void:
			l.ovoid(Vector3(0, 0.05, 0), Vector3(0.16, 0.17, 0.16), [ELIXIR, CRYSTAL, Color(1.0, 0.6, 0.3)][k % 3], ELIXIR.darkened(0.3), 3, 8), true)


static func _arms(rig: Node3D) -> void:
	# Its left: a thin grey arm ending in a glass retort it pours from.
	var left := _pivot(rig, Vector3(-1.2, 2.2, 0.1), "ArmL")
	_part(left, "arm_upper", func(l: LowPoly) -> void:
		l.ovoid(Vector3.ZERO, Vector3(0.45, 0.42, 0.45), ROBE, ROBE.darkened(0.3), 4, 10)
		l.prism(Vector3(0, 0.1, 0), Vector3(-0.2, -1.2, 0.1), 0.36, 0.5, 10, ROBE_LIGHT)
		for k in 6:
			var a := TAU * k / 6.0
			l.prism(Vector3(-0.2 + cos(a) * 0.45, -1.15, 0.1 + sin(a) * 0.45), Vector3(-0.2 + cos(a) * 0.5, -1.55, 0.1 + sin(a) * 0.5), 0.14, 0.02, 4, ROBE_LIGHT.darkened(0.25)))
	var fore_l := _pivot(left, Vector3(-0.2, -1.2, 0.1), "Fore")
	_part(fore_l, "retort_arm", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, -1.1, 0.25), 0.24, 0.15, 8, FLESH)
		for k in 3:
			l.prism(Vector3(0.12 * (k - 1), -0.15, 0.18), Vector3(0.08 * (k - 1), -0.95, 0.34), 0.05, 0.035, 5, FLESH.lightened(0.08)) # sinews
		l.prism(Vector3(0, -1.0, 0.22), Vector3(0, -1.18, 0.27), 0.16, 0.16, 8, GOLD_DARK)
		l.prism(Vector3(0, -1.18, 0.27), Vector3(0.2, -1.5, 0.75), 0.06, 0.035, 6, GLASS))
	var retort := _pivot(fore_l, Vector3(0, -1.5, 0.2), "Retort")
	_part(retort, "retort_glow", func(l: LowPoly) -> void:
		l.ovoid(Vector3.ZERO, Vector3(0.36, 0.34, 0.36), ELIXIR, ELIXIR.darkened(0.25), 5, 12), true)
	# Its right: too long, jointed twice, and the claw at the end of it.
	var right := _pivot(rig, Vector3(1.2, 2.2, 0.1), "ArmR")
	_part(right, "claw_upper", func(l: LowPoly) -> void:
		l.ovoid(Vector3.ZERO, Vector3(0.48, 0.44, 0.48), WAX_DARK, WAX_DARK.darkened(0.3), 4, 10)
		l.prism(Vector3(0, 0.1, 0), Vector3(0.25, -1.15, 0.05), 0.38, 0.32, 10, ROBE)
		for k in 7:
			var a := TAU * k / 7.0
			_cell(l, Vector3(0.12 + cos(a) * 0.38, -0.5 + sin(k * 1.7) * 0.25, sin(a) * 0.36), Vector3(cos(a), 0, sin(a)), 0.1, WAX.darkened(0.08 * (k % 3))))
	var mid := _pivot(right, Vector3(0.25, -1.15, 0.05), "Mid")
	_part(mid, "claw_mid", func(l: LowPoly) -> void:
		l.ovoid(Vector3.ZERO, Vector3(0.16, 0.16, 0.16), FLESH.darkened(0.2), FLESH.darkened(0.4), 3, 8)
		l.prism(Vector3.ZERO, Vector3(0.1, -1.0, 0.15), 0.22, 0.18, 8, FLESH)
		l.prism(Vector3(0.18, -0.3, 0.05), Vector3(0.55, -0.15, 0.1), 0.08, 0.0, 5, CRYSTAL)
		l.prism(Vector3(0.12, -0.6, -0.1), Vector3(0.4, -0.65, -0.45), 0.07, 0.0, 5, CRYSTAL.lightened(0.2)))
	var fore_r := _pivot(mid, Vector3(0.1, -1.0, 0.15), "Fore")
	_part(fore_r, "claw_fore", func(l: LowPoly) -> void:
		l.ovoid(Vector3.ZERO, Vector3(0.14, 0.14, 0.14), CRYSTAL.darkened(0.3), CRYSTAL.darkened(0.5), 3, 8)
		l.prism(Vector3.ZERO, Vector3(0, -0.8, 0.2), 0.19, 0.24, 8, FLESH.darkened(0.05))
		l.ovoid(Vector3(0, -0.85, 0.22), Vector3(0.34, 0.22, 0.28), FLESH.darkened(0.1), FLESH.darkened(0.3), 3, 8))
	var claw := _pivot(fore_r, Vector3(0, -0.9, 0.22), "Claw")
	for k in 5:
		var a := -0.9 + k * 0.45
		var finger := _pivot(claw, Vector3(sin(a) * 0.18, 0, cos(a) * 0.14), "Finger%d" % k)
		finger.rotation = Vector3(0.2, a * 0.5, 0)
		_part(finger, "finger", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.6, 0.12), 0.09, 0.07, 5, FLESH.darkened(0.15))
			l.ovoid(Vector3(0, -0.6, 0.12), Vector3(0.08, 0.08, 0.08), FLESH.darkened(0.25), FLESH.darkened(0.4), 2, 6)
			l.prism(Vector3(0, -0.6, 0.12), Vector3(0, -1.15, 0.42), 0.07, 0.0, 5, Color(0.1, 0.06, 0.1)))


static func _wings(rig: Node3D) -> void:
	# Two fans of wax cells hung from its back, broken: whole cells, half cells, gaps.
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(rig, Vector3(side * 0.5, 2.3, -0.75), "WingL" if side < 0 else "WingR")
		_part(wing, "wing_%s" % side, func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 77 if side < 0 else 91
			for row in 6:
				for col in 5 - row / 2:
					if rng.randf() < 0.22:
						continue # a gap where a cell broke away
					var x := side * (0.35 + col * 0.36 + row * 0.12)
					var y := 0.6 - row * 0.32 + col * 0.18
					var r := 0.19 * (1.0 - row * 0.06)
					var col_c := WAX.darkened(0.05 * row + rng.randf() * 0.15)
					l.prism(Vector3(x, y, -0.06), Vector3(x, y, 0.06), r, r, 6, col_c)
					if rng.randf() < 0.35:
						l.prism(Vector3(x, y, 0.06), Vector3(x, y, 0.09), r * 0.65, r * 0.6, 6, WAX_DARK.darkened(0.3))
			l.prism(Vector3.ZERO, Vector3(side * 1.9, 1.2, -0.1), 0.06, 0.02, 5, WAX_DARK))


## The column of elixir it floats on: rings of light, turning and pouring down to a pool.
static func _pour_column(root: Node3D) -> void:
	var pour := _pivot(root, Vector3.ZERO, "Pour")
	for k in 6:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		var r := (0.9 - k * 0.11) * SIZE
		t.inner_radius = r * 0.55
		t.outer_radius = r
		t.rings = 12
		t.ring_segments = 6
		ring.mesh = t
		ring.material_override = pour_material()
		ring.name = "Ring%d" % k
		ring.position = Vector3(0, 0.15 + k * 0.42, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pour.add_child(ring)
	var stream := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.6 * SIZE
	c.bottom_radius = 0.25 * SIZE
	c.height = HOVER
	c.radial_segments = 10
	stream.mesh = c
	stream.position = Vector3(0, HOVER * 0.5, 0)
	stream.material_override = pour_material()
	stream.name = "Stream"
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pour.add_child(stream)
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2 * SIZE
	disc.bottom_radius = 2.4 * SIZE
	disc.height = 0.05
	disc.radial_segments = 20
	pool.mesh = disc
	pool.position = Vector3(0, 0.06, 0)
	pool.material_override = pour_material()
	pool.name = "Pool"
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pour.add_child(pool)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 1.0, 0.55)
	light.light_energy = 2.4
	light.omni_range = 14.0
	light.position = Vector3(0, 1.5, 0)
	light.name = "Light"
	pour.add_child(light)


static func _shards(rig: Node3D) -> void:
	var orbit := _pivot(rig, Vector3(0, 1.4, 0), "Shards")
	for k in 7:
		var a := TAU * k / 7.0
		var shard := _pivot(orbit, Vector3(cos(a) * 2.6, sin(k * 1.9) * 0.6, sin(a) * 2.6), "Shard%d" % k)
		_part(shard, "shard_%d" % (k % 2), func(l: LowPoly) -> void:
			var long := 0.7 if k % 2 == 0 else 0.5
			l.prism(Vector3(0, -long * 0.5, 0), Vector3.ZERO, 0.0, 0.14, 6, CRYSTAL)
			l.prism(Vector3.ZERO, Vector3(0, long, 0), 0.14, 0.0, 6, CRYSTAL.lightened(0.25)), true)


# --- Moving ----------------------------------------------------------------------------------------

static func animate(z: Zombie, root: Node3D, delta: float, state: String, t: float, act: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var body := rig.get_node("Body") as Node3D
	var head := rig.get_node("Head") as Node3D
	var halo := head.get_node("Halo") as Node3D
	var arm_l := rig.get_node("ArmL") as Node3D
	var arm_r := rig.get_node("ArmR") as Node3D
	var fore_l := arm_l.get_node("Fore") as Node3D
	var mid_r := arm_r.get_node("Mid") as Node3D
	var claw := mid_r.get_node("Fore/Claw") as Node3D
	var crucible := body.get_node("Crucible") as Node3D
	var shards := rig.get_node("Shards") as Node3D
	var pour := root.get_node("Pour") as Node3D
	var k := minf(1.0, delta * 5.0)
	var tell := z.is_warning()
	var hurt := 1.0 - z.hp / maxf(z.max_hp, 1.0)
	# Floating: a slow heave, a lean into where it goes; higher and more restless as it is hurt.
	var hover := HOVER + 0.6 * hurt
	var rise := 0.0
	if state == "m_rise":
		rise = RISE_FROM * (1.0 - smoothstep(0.0, RISE_TIME, act))
	rig.position.y = lerpf(rig.position.y, hover + rise + sin(t * 0.8) * 0.3, minf(1.0, delta * (20.0 if state == "m_rise" else 3.0)))
	rig.rotation.z = sin(t * 0.55) * 0.06 * (1.0 + hurt)
	# The pour beneath it: the stream reaches from the pool to its hem, its rings turning down it.
	var stream := pour.get_node("Stream") as MeshInstance3D
	var reach := maxf(0.5, rig.position.y - 2.2 * SIZE)
	stream.scale = Vector3(1, reach / HOVER, 1)
	stream.position.y = reach * 0.5
	for i in 6:
		var ring := pour.get_node("Ring%d" % i) as Node3D
		var along := fmod(t * 0.6 + i / 6.0, 1.0)
		ring.position.y = reach * (1.0 - along)
		ring.scale = Vector3.ONE * lerpf(0.5, 1.5, along)
		ring.rotation.y = t * (1.5 + i * 0.3)
	(pour.get_node("Light") as OmniLight3D).light_energy = 2.0 + sin(t * 2.3) * 0.5 + (2.5 if state == "m_sweep" else 0.0)
	# The crucible's pulse: faster as it is hurt, blazing as it gathers a nova.
	var nova := smoothstep(0.0, 1.2, act) if state == "m_sweep" else 0.0
	crucible.scale = Vector3.ONE * (1.0 + sin(t * (3.0 + hurt * 4.0)) * 0.08 + nova * 0.8)
	# The halo and the shards turn; the shards gather into a line for the lance, scatter for the nova.
	halo.rotation.y += delta * (0.8 + hurt)
	var spread := 1.0 + nova * 0.6 + (0.3 if state == "m_roar" else 0.0)
	halo.scale = Vector3.ONE * lerpf(halo.scale.x, spread, k)
	shards.rotation.y += delta * (0.6 + hurt * 0.8)
	for i in 7:
		var s := shards.get_node("Shard%d" % i) as Node3D
		var a := TAU * i / 7.0
		var want := Vector3(cos(a) * 2.6 * spread, sin(t * 1.3 + i) * 0.5, sin(a) * 2.6 * spread)
		if state == "m_ink":
			# A line out in front of it, toward whoever it points at.
			want = Basis(Vector3.UP, -shards.rotation.y) * Vector3(0.0, -0.6, 2.4 + i * 0.75)
		s.position = s.position.lerp(want, k)
		s.rotation.y += delta * 2.0
	# The head: tilted, watching; thrown back to roar; bowed over the slam.
	var head_x := 0.12 + sin(t * 0.4) * 0.05
	match state:
		"m_roar": head_x = -0.55
		"m_slam": head_x = 0.35
		"m_cast": head_x = -0.15
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
	head.rotation.z = lerpf(head.rotation.z, 0.12 * sin(t * 0.3) + 0.15 * hurt, k)
	# The arms.
	var l_arm := Vector3(0.1 + sin(t * 0.7) * 0.06, 0.2, -0.25)
	var l_fore := Vector3(-0.35, 0, 0)
	var r_arm := Vector3(0.15 + sin(t * 0.6 + 1.0) * 0.06, -0.2, 0.3)
	var r_mid := Vector3(-0.5, 0, 0.1)
	var spread_claw := 0.1
	match state:
		"m_cast":
			# The retort raised high and tipped over them.
			var up := smoothstep(0.0, 0.7, act)
			l_arm = Vector3(-2.2 * up, 0.2, -0.6 * up)
			l_fore = Vector3(-0.6 * up, 0, 0.4 * up)
		"m_slam":
			# Both arms flung up, then driven down, the claw spread wide.
			var up := smoothstep(0.0, 0.5, act) * (1.0 - smoothstep(0.7, 0.95, act))
			l_arm = Vector3(-2.4 * up + 0.6, 0.2, -0.3)
			r_arm = Vector3(-2.4 * up + 0.6, -0.2, 0.3)
			r_mid = Vector3(-0.2, 0, 0)
			spread_claw = 0.9
		"m_sweep":
			l_arm = Vector3(-0.5, 0.2, -1.4 * nova)
			r_arm = Vector3(-0.5, -0.2, 1.4 * nova)
			spread_claw = 0.8
		"m_ink":
			r_arm = Vector3(-1.5, -0.5, 0.2)
			r_mid = Vector3(0.1, 0, 0)
			spread_claw = 0.0
		"m_roar":
			l_arm = Vector3(-1.0, 0.2, -1.1)
			r_arm = Vector3(-1.0, -0.2, 1.1)
			spread_claw = 1.0
	arm_l.rotation = arm_l.rotation.lerp(l_arm, k)
	fore_l.rotation = fore_l.rotation.lerp(l_fore, k)
	arm_r.rotation = arm_r.rotation.lerp(r_arm, k)
	mid_r.rotation = mid_r.rotation.lerp(r_mid, k)
	for i in 5:
		var f := claw.get_node("Finger%d" % i) as Node3D
		f.rotation.x = lerpf(f.rotation.x, 0.6 - spread_claw * 0.9 + sin(t * 2.0 + i) * 0.06, k)
	body.rotation.x = lerpf(body.rotation.x, (-0.3 * nova) + (0.15 if state == "m_slam" else 0.0) + (-0.2 if state == "m_roar" else 0.0), k)
	# Wings: hanging, stirring; spread wide when it roars or gathers a nova.
	for side: float in [-1.0, 1.0]:
		var wing := rig.get_node("WingL" if side < 0 else "WingR") as Node3D
		var open := 0.25 + sin(t * 0.9 + side) * 0.06 + (0.7 if state == "m_roar" else 0.0) + nova * 0.5
		wing.rotation.y = lerpf(wing.rotation.y, side * open, k)
		wing.rotation.z = lerpf(wing.rotation.z, -side * 0.2 * open, k)
	# A tell is lit: its eyes flare.
	crucible.visible = true
	var eyes := head.get_node("Eyes") as MeshInstance3D
	eyes.scale = Vector3.ONE * (1.25 if tell else 1.0)
	# Half gone: the second face opens on its shoulder.
	var second := body.get_node("Second") as Node3D
	if hurt >= 0.5:
		second.visible = true
		second.scale = second.scale.lerp(Vector3.ONE, minf(1.0, delta * 1.5))
	else:
		second.visible = false
		second.scale = Vector3.ONE * 0.01


# --- Dying ------------------------------------------------------------------------------------------

const DEATH_TIME := 6.0

## Six seconds of it: it convulses, its halo breaks and the flasks fall, the shards drop out of the
## air, the crucible flares white and cracks; it sags down its own column into the pool, and the pool
## burns away to nothing.
static func fall(z: Zombie, root: Node3D, age: float, delta: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var body := rig.get_node("Body") as Node3D
	var head := rig.get_node("Head") as Node3D
	var halo := head.get_node("Halo") as Node3D
	var shards := rig.get_node("Shards") as Node3D
	var pour := root.get_node("Pour") as Node3D
	var crucible := body.get_node("Crucible") as Node3D
	# Convulsing (0-1.6), a shake that dies away.
	var shake := (1.0 - smoothstep(1.2, 2.2, age)) * 0.12
	rig.rotation = Vector3(sin(age * 31.0) * shake, sin(age * 23.0) * shake * 0.5, sin(age * 27.0) * shake + 0.25 * smoothstep(2.0, 4.0, age))
	head.rotation.x = lerpf(head.rotation.x, -0.7 if age < 2.0 else 0.6, minf(1.0, delta * 3.0))
	if FontaModels._once(root, "break", age, 0.6):
		z.world.fx_ring(z.position + Vector3.UP * 0.2, 10.0, Color(0.75, 0.45, 1.0))
		z.world.sfx_at("alq_shatter", z.position, 6.0)
	# The flasks and shards fall out of the air.
	for flask in halo.get_children():
		var f := flask as Node3D
		f.position.y -= delta * maxf(0.0, age - 0.6) * 9.8
		f.rotation.x += delta * 5.0
	for shard in shards.get_children():
		var s := shard as Node3D
		s.position.y = maxf(-HOVER - 1.4, s.position.y - delta * maxf(0.0, age - 0.8) * 9.8)
		s.rotation.z += delta * 4.0
	# The crucible flares and cracks.
	var flare := smoothstep(1.0, 2.0, age) * (1.0 - smoothstep(2.4, 2.8, age))
	crucible.scale = Vector3.ONE * (1.0 + flare * 1.6)
	if FontaModels._once(root, "crack", age, 2.5):
		z.world.fx_gore(z.position + Vector3.UP * (rig.position.y + 1.4), Color(0.5, 1.0, 0.45))
		z.world.fx_mist(z.position + Vector3.UP * 2.0, 4.0)
		z.world.show_ring(z.position + Vector3.UP * 0.1, 6.0, Color(0.5, 1.0, 0.5))
		crucible.visible = false
	# It sags down its column into the pool, folding over.
	var sag := smoothstep(2.4, 4.6, age)
	rig.position.y = lerpf(HOVER, -1.6, sag)
	body.rotation.x = lerpf(0.0, 0.7, sag)
	for side in ["ArmL", "ArmR"]:
		var arm := rig.get_node(side) as Node3D
		arm.rotation.x = lerpf(arm.rotation.x, 0.6, minf(1.0, delta * 2.0))
	# The pool burns away, and all of it with it.
	var gone := smoothstep(4.4, DEATH_TIME, age)
	pour.scale = Vector3(1.0 + gone, maxf(0.01, 1.0 - gone), 1.0 + gone)
	(pour.get_node("Light") as OmniLight3D).light_energy = 3.0 * (1.0 - gone) + flare * 6.0
	rig.scale = Vector3.ONE * SIZE * maxf(0.01, 1.0 - gone)
	if FontaModels._once(root, "end", age, 4.6):
		z.world.fx_ring(z.position + Vector3.UP * 0.1, 14.0, Color(1.0, 0.95, 0.7))
		z.world.fx_mist(z.position + Vector3.UP * 0.6, 6.0)
