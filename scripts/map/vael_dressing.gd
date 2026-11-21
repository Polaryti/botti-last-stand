class_name VaelDressing
extends RefCounted
## What makes the drowned kingdom of Vael more than a harbour (MapVael kinds): the drowned spires of its
## old city standing far out at sea with green light in their windows; statues of its Tide Kings, crowned
## and holding tridents, standing in the town or fallen on the seabed; ruined arches of its gates; the
## bones of a whale; masts of sunk ships with corpse-lights burning at their tops; kelp beds and tide
## pools lit by things that glow; braziers, shrines, banners and bunting; cargo, nets and drying fish on
## the quay; and drifts of ghost-light hanging over the water. Each draws at the builder's spot (b.xf).

const STONE := Color(0.5, 0.5, 0.48)
const STONE_DARK := Color(0.32, 0.33, 0.33)
const WET := Color(0.22, 0.27, 0.25)
const BRONZE := Color(0.27, 0.46, 0.4)
const BRONZE_DARK := Color(0.18, 0.3, 0.27)
const BONE := Color(0.82, 0.78, 0.68)
const BONE_DARK := Color(0.62, 0.58, 0.5)
const KELP := Color(0.2, 0.32, 0.16)
const KELP_DARK := Color(0.13, 0.22, 0.12)
const DEEP_GLOW := Color(0.35, 1.0, 0.78) # the light of the deep: anemones, windows, corpse-lights
const VIOLET_GLOW := Color(0.7, 0.45, 1.0)
const FIRE := Color(1.0, 0.62, 0.25)
const FLAME := Color(1.0, 0.82, 0.4)
const CLOTH_TEAL := Color(0.12, 0.34, 0.38)
const CLOTH_BONE := Color(0.82, 0.76, 0.6)
const CLOTH_RUST := Color(0.55, 0.22, 0.14)
const GOLD := Color(0.78, 0.6, 0.26)
const WOOD := Color(0.4, 0.29, 0.19)
const WOOD_DARK := Color(0.24, 0.18, 0.12)
const ROPE := Color(0.6, 0.5, 0.34)
const FISH := Color(0.68, 0.72, 0.74)
const IRON := Color(0.2, 0.21, 0.22)


static func _local_ground(b: MapBuilder, x: float, z: float) -> float:
	return (b.xf.affine_inverse() * b.on_ground(Vector3(x, 0, z))).y


static func _tide(b: MapBuilder) -> float:
	return VaelBuilder._tide_line(b)


## Glowing parts: merged with whatever else glows nearby.
static func _glow(b: MapBuilder, build: Callable) -> void:
	var g := b.mesh()
	build.call(g)
	MesenllaBuilder._shine(b, g)


# --- The drowned city, far out at sea ----------------------------------------------------------

## A spire of the drowned city of Vael, standing up out of the open sea `high` metres: a tall
## eight-sided tower in tiers, buttressed at its foot, its top a needle (or broken off short), rows of
## narrow windows burning with the green light of the deep, and the crown of Vael on its finial. Far
## off, the fog keeps only its outline and its windows.
static func spire(b: MapBuilder, high: float) -> void:
	var rng := b.seeded()
	var l := b.mesh()
	var broken := rng.randf() < 0.35
	var r := high * 0.075
	var foot := -6.0
	var tiers := 4
	var y := foot
	var windows := l if b.look == "vael" else b.mesh()
	var window_colour := STONE_DARK.darkened(0.42) if b.look == "vael" else DEEP_GLOW
	for t in tiers:
		var h := (high * (0.78 if broken else 0.62)) / tiers
		var r0 := r * (1.0 - t * 0.16)
		var r1 := r0 * 0.9
		l.prism(Vector3(0, y, 0), Vector3(0, y + h, 0), r0, r1, 8, STONE_DARK.lightened(0.05 * (t % 2)))
		l.prism(Vector3(0, y + h - 0.6, 0), Vector3(0, y + h + 0.4, 0), r1 * 1.15, r1 * 1.1, 8, STONE_DARK.darkened(0.15))
		# Windows: tall slits on alternate faces, lit from within.
		for k in 8:
			if (k + t) % 2 == 1 or y + h * 0.5 < 0.5:
				continue
			var a := TAU * (k + 0.5) / 8.0
			var o := Vector3(sin(a), 0, cos(a))
			windows.box(o * (r0 * 0.93) + Vector3(0, y + h * 0.5, 0), Vector3(r0 * 0.16, h * 0.42, 0.25), window_colour, Vector3(0, rad_to_deg(a), 0))
		y += h
	if broken:
		# Snapped off: jagged stumps of the last tier.
		for k in 5:
			var a := TAU * k / 5.0 + rng.randf()
			l.box(Vector3(sin(a), 0, cos(a)) * r * 0.45 + Vector3(0, y + rng.randf_range(0.5, 2.5), 0), Vector3(r * 0.3, rng.randf_range(1.5, 4.0), r * 0.3), STONE_DARK, Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)))
	else:
		l.prism(Vector3(0, y, 0), Vector3(0, y + high * 0.38, 0), r * 0.5, 0.05, 8, Color(0.2, 0.24, 0.26))
		var top := Vector3(0, y + high * 0.38, 0)
		VaelModels.crown(l, top + Vector3.DOWN * r * 0.2, r * 0.32)
		windows.box(top + Vector3.UP * 0.4, Vector3.ONE * r * 0.18, window_colour)
	# Buttresses at its foot, and two lesser turrets.
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var o := Vector3(sin(a), 0, cos(a))
		l.box(o * r * 1.15 + Vector3(0, foot + high * 0.14, 0), Vector3(r * 0.45, high * 0.3, r * 1.0), STONE_DARK.darkened(0.1), Vector3(0, rad_to_deg(a), rad_to_deg(0.18)))
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * r * 2.2, 0, r * 0.6)
		l.prism(at + Vector3(0, foot, 0), at + Vector3(0, high * 0.3, 0), r * 0.38, r * 0.34, 6, STONE_DARK)
		l.prism(at + Vector3(0, high * 0.3, 0), at + Vector3(0, high * 0.42, 0), r * 0.42, 0.05, 6, Color(0.2, 0.24, 0.26))
		windows.box(at + Vector3(0, high * 0.22, r * 0.35), Vector3(r * 0.12, high * 0.06, 0.2), window_colour)
	var mi := b.add(l)
	mi.visibility_range_end = 400.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Port Vael's windows are dark, part of the silhouette against the aurora.
	if b.look != "vael":
		var glow := MesenllaBuilder._shine(b, windows, true)
		if glow:
			glow.visibility_range_end = 400.0
			glow.material_override = _far_glow()
		b.w.add_glow(b.xf * Vector3(0, y * 0.55, 0), DEEP_GLOW, high * 0.18, 0.0, true).visibility_range_end = 400.0


## Lit windows seen through the fog: unlit and unfogged, so far spires keep their lights.
static var _far_glow_mat: StandardMaterial3D
static func _far_glow() -> StandardMaterial3D:
	if _far_glow_mat == null:
		_far_glow_mat = StandardMaterial3D.new()
		_far_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_far_glow_mat.vertex_color_use_as_albedo = true
		_far_glow_mat.disable_fog = true
	return _far_glow_mat


# --- Statues of the Tide Kings -------------------------------------------------------------------

## A Tide King of Vael in green bronze: robed, crowned, a trident upright in his right hand and his left
## held out over the water; on a stepped plinth of pale stone. His eyes still hold a little of the
## deep's light. `high` is the figure's height. Fallen (on the seabed), he lies on his side half sunk
## in the sand, his crown rolled away, weed and barnacles over him.
static func statue(b: MapBuilder, high: float, fallen: bool) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var s := high / 4.0
	var base := Vector3.ZERO
	if not fallen:
		for k in 3:
			var w := (2.8 - k * 0.5) * s
			l.box(Vector3(0, k * 0.45 * s + 0.22 * s, 0), Vector3(w, 0.45 * s, w), STONE.darkened(0.06 * k))
		base = Vector3(0, 1.35 * s, 0)
		b.solid(Vector3(0, 0.8 * s, 0), Vector3(2.8 * s, 1.6 * s, 2.8 * s))
	var turn := Basis.IDENTITY
	if fallen:
		turn = Basis(Vector3.FORWARD, deg_to_rad(84.0)) * Basis(Vector3.UP, deg_to_rad(20.0))
		base = Vector3(0, 0.25 * s - 0.15 * s, 0)
		b.solid(Vector3(0, 0.5 * s, 0), Vector3(3.6 * s, 1.2 * s, 1.4 * s))
	var into := b.mesh()
	into.base = b.xf * Transform3D(turn, base)
	_king(into, s, rng)
	var tide := _tide(b)
	if fallen or base.y < tide:
		for k in 8:
			var at := Vector3(rng.randf_range(-1.6, 1.6) * s, rng.randf_range(0.1, 0.9) * s, rng.randf_range(-0.4, 0.4) * s)
			VaelModels.barnacles(l, at, Vector3(0, 1, 0), 3, 0.06 * s, rng)
			VaelModels.kelp(l, at + Vector3.UP * 0.2, rng.randf_range(0.4, 0.9), 2, rng)
	b.add(into)
	# The eyes.
	var eyes := b.mesh()
	eyes.base = b.xf * Transform3D(turn, base)
	for side: float in [-1.0, 1.0]:
		eyes.box(Vector3(side * 0.11 * s, 3.42 * s, 0.27 * s), Vector3(0.09 * s, 0.05 * s, 0.04 * s), DEEP_GLOW)
	MesenllaBuilder._shine(b, eyes)
	if fallen:
		# His crown, rolled off into the sand beside him.
		var c := b.mesh()
		VaelModels.crown(c, Vector3(1.6 * s, -0.1 * s, 1.4 * s), 0.36 * s)
		b.add(c)
	if not fallen:
		b.w.add_glow(b.xf * (base + Vector3(0, 3.42 * s, 0.3 * s)), DEEP_GLOW, 0.7 * s)


## The king's figure, standing, `s` metres a unit (4 units tall), facing +Z.
static func _king(l: LowPoly, s: float, rng: RandomNumberGenerator) -> void:
	var robe := BRONZE.darkened(rng.randf_range(0.0, 0.08))
	l.prism(Vector3(0, 0, 0), Vector3(0, 2.2 * s, 0), 0.62 * s, 0.38 * s, 8, robe)
	l.prism(Vector3(0, 0, 0), Vector3(0, 0.25 * s, 0), 0.7 * s, 0.66 * s, 8, BRONZE_DARK)
	l.prism(Vector3(0, 2.1 * s, 0), Vector3(0, 2.9 * s, 0), 0.42 * s, 0.46 * s, 8, robe.lightened(0.05))
	# A cloak over the shoulders, hanging behind.
	l.box(Vector3(0, 1.8 * s, -0.36 * s), Vector3(1.05 * s, 2.2 * s, 0.14 * s), BRONZE_DARK, Vector3(-6, 0, 0))
	l.prism(Vector3(-0.5 * s, 2.85 * s, 0), Vector3(0.5 * s, 2.85 * s, 0), 0.2 * s, 0.2 * s, 6, robe)
	l.prism(Vector3(0, 2.9 * s, 0), Vector3(0, 3.1 * s, 0), 0.14 * s, 0.14 * s, 6, robe.darkened(0.1))
	# Head and beard.
	l.box(Vector3(0, 3.38 * s, 0.02 * s), Vector3(0.42 * s, 0.5 * s, 0.44 * s), BRONZE.lightened(0.04))
	l.prism(Vector3(0, 3.18 * s, 0.18 * s), Vector3(0, 2.86 * s, 0.24 * s), 0.18 * s, 0.04 * s, 5, BRONZE_DARK)
	VaelModels.crown(l, Vector3(0, 3.62 * s, 0.02 * s), 0.25 * s)
	# The trident, upright in the right hand.
	var hand := Vector3(0.62 * s, 2.0 * s, 0.25 * s)
	l.prism(Vector3(0.48 * s, 2.75 * s, 0), hand, 0.1 * s, 0.09 * s, 5, robe)
	l.prism(Vector3(0.62 * s, 0.05 * s, 0.25 * s), Vector3(0.62 * s, 4.4 * s, 0.25 * s), 0.045 * s, 0.045 * s, 5, BRONZE_DARK)
	for k in 3:
		var x := (k - 1) * 0.16 * s
		l.prism(Vector3(0.62 * s + x, 4.25 * s, 0.25 * s), Vector3(0.62 * s + x, (4.85 if k == 1 else 4.7) * s, 0.25 * s), 0.035 * s, 0.005 * s, 4, BRONZE)
	l.prism(Vector3(0.44 * s, 4.28 * s, 0.25 * s), Vector3(0.8 * s, 4.28 * s, 0.25 * s), 0.035 * s, 0.035 * s, 4, BRONZE)
	# The left arm held out, palm down over the sea.
	l.prism(Vector3(-0.48 * s, 2.75 * s, 0), Vector3(-0.85 * s, 2.45 * s, 0.6 * s), 0.1 * s, 0.08 * s, 5, robe)
	l.box(Vector3(-0.92 * s, 2.42 * s, 0.72 * s), Vector3(0.16 * s, 0.06 * s, 0.22 * s), BRONZE.lightened(0.05))


# --- Ruins on the seabed --------------------------------------------------------------------------

## An arch of one of Vael's sea gates, `span` metres across, along X: two piers of big stone blocks
## and the arch over them, its keystone carved with the crowned wave of Vael. Weed hangs from it and
## barnacles crust it to the high-water mark. Broken, one pier stands alone and the arch's stones lie
## tumbled at its foot.
static func arch(b: MapBuilder, span: float, broken: bool) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var tide := _tide(b)
	var half := span * 0.5
	var high := span * 0.7
	for side: float in [-1.0, 1.0]:
		if broken and side > 0.0:
			# The fallen pier: its blocks lying where they fell.
			for k in 6:
				var at := Vector3(half + rng.randf_range(-1.0, 2.5), _local_ground(b, half, 0) + 0.3, rng.randf_range(-1.5, 1.5))
				l.box(at, Vector3(1.0, 0.7, 0.9), VaelBuilder._stone_col(at.y, tide, STONE, rng), Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 90), rng.randf_range(-25, 25)))
			continue
		var g := _local_ground(b, side * half, 0) - 0.4
		var y := g
		while y < high:
			var h := minf(0.75, high - y)
			l.box(Vector3(side * half, y + h * 0.5, 0), Vector3(1.3, h - 0.04, 1.4), VaelBuilder._stone_col(y + h * 0.5, tide, STONE, rng))
			y += 0.75
		b.solid(Vector3(side * half, high * 0.5, 0), Vector3(1.3, high, 1.4))
		if y - 0.75 < tide:
			VaelModels.barnacles(l, Vector3(side * (half - 0.66), minf(tide, high) - 0.6, 0), Vector3(-side, 0, 0), 5, 0.06, rng)
	# The arch: voussoirs round a half circle.
	var parts := 11
	for k in parts:
		var a0 := PI * k / parts
		var a1 := PI * (k + 1) / parts
		if broken and (a0 + a1) * 0.5 < PI * 0.62:
			continue
		var am := (a0 + a1) * 0.5
		var at := Vector3(cos(am) * half, high + sin(am) * half * 0.55, 0)
		var col := VaelBuilder._stone_col(at.y, tide, STONE.lightened(0.04), rng)
		l.box(at, Vector3(half * PI / parts * 1.02, 0.7, 1.4), col, Vector3(0, 0, rad_to_deg(am) - 90.0))
		if rng.randf() < 0.6:
			VaelModels.kelp(l, at + Vector3(0, -0.35, rng.randf_range(-0.5, 0.5)), rng.randf_range(0.6, 1.6), 2, rng)
	if not broken:
		# The keystone, carved: a crown over a wave.
		var key := Vector3(0, high + half * 0.55, 0.72)
		l.box(key, Vector3(0.9, 1.0, 0.12), STONE.lightened(0.1))
		VaelModels.crown(l, key + Vector3(0, 0.05, 0.02), 0.18)
		for k in 3:
			l.box(key + Vector3((k - 1) * 0.24, -0.32, 0.04), Vector3(0.22, 0.08, 0.06), BRONZE, Vector3(0, 0, 25))


## The bones of a great whale, washed up long ago: a spine of vertebrae along Z, a curve of ribs either
## side rising out of the sand like a hull's frames, and the long skull at the front.
static func whale_bones(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var verts := int(length / 0.9)
	for k in verts:
		var z := -length * 0.5 + (k + 0.5) * length / verts
		var g := _local_ground(b, 0, z)
		var lift := sin(float(k) / verts * PI) * 0.6
		l.box(Vector3(0, g + 0.3 + lift, z), Vector3(0.55, 0.4, 0.6), BONE.darkened(rng.randf_range(0.0, 0.15)))
		l.box(Vector3(0, g + 0.62 + lift, z), Vector3(0.1, 0.35, 0.3), BONE_DARK)
		if k % 2 == 0 and k > 1 and k < verts - 3:
			for side: float in [-1.0, 1.0]:
				# A rib: an arc up and over, its tip in the sand.
				var span := length * 0.16 * sin(float(k) / verts * PI) + 0.8
				var prev := Vector3(side * 0.3, g + 0.4 + lift, z)
				for j in 6:
					var u := float(j + 1) / 6.0
					var p := Vector3(side * (0.3 + sin(u * PI * 0.9) * span), g + 0.4 + lift + sin(u * PI * 0.55) * span * 1.1 - u * u * 0.8, z + u * 0.4)
					l.prism(prev, p, 0.11 - u * 0.05, 0.1 - u * 0.05, 5, BONE.darkened(0.04 * j))
					prev = p
				b.solid(Vector3(side * span * 0.8, g + 0.8, z), Vector3(0.4, 1.6, 0.4))
	# The skull: long and low, the jaws open.
	var front := length * 0.5
	var gs := _local_ground(b, 0, front + 1.5)
	l.prism(Vector3(0, gs + 0.5, front), Vector3(0, gs + 0.35, front + 3.2), 0.85, 0.3, 6, BONE)
	l.prism(Vector3(0, gs + 0.1, front + 0.2), Vector3(0, gs + 0.15, front + 3.4), 0.5, 0.18, 6, BONE_DARK)
	b.solid(Vector3(0, gs + 0.5, front + 1.6), Vector3(1.6, 1.0, 3.2))


## A mast of a ship sunk on the flats, standing up out of the sand at a lean: its yard still across it
## with rags of sail hanging, stays running down to the seabed, a crow's nest, and at its top a
## corpse-light: a lantern burning cold and green that no one lit.
static func mast(b: MapBuilder, high: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var tide := _tide(b)
	var lean := Basis(Vector3(1, 0, 0.3).normalized(), deg_to_rad(rng.randf_range(8.0, 16.0)))
	var g := _local_ground(b, 0, 0) - 0.5
	var top := lean * Vector3(0, high, 0) + Vector3(0, g, 0)
	var col_low := VaelBuilder.WOOD_WET
	l.prism(Vector3(0, g, 0), Vector3(0, g, 0).lerp(top, 0.45), 0.22, 0.19, 7, col_low)
	l.prism(Vector3(0, g, 0).lerp(top, 0.45), top, 0.19, 0.12, 7, VaelBuilder.WOOD_DARK)
	b.solid(Vector3(0, g + 1.2, 0), Vector3(0.5, 2.4, 0.5))
	VaelModels.barnacles(l, Vector3(0, minf(tide, g + 2.0) - 0.4, 0.2), Vector3(0, 0, 1), 6, 0.06, rng)
	VaelModels.kelp(l, Vector3(0.15, minf(tide, g + 2.0), 0.1), 1.2, 3, rng)
	# The yard, the sail in rags.
	var yard := Vector3(0, g, 0).lerp(top, 0.72)
	var across := lean * Vector3(1, 0, 0)
	l.prism(yard - across * high * 0.28, yard + across * high * 0.28, 0.08, 0.08, 5, VaelBuilder.WOOD_DARK)
	for k in 5:
		var u := (k - 2) * 0.11 * high
		var drop := rng.randf_range(0.8, 2.2)
		if rng.randf() < 0.2:
			continue
		l.box(yard + across * u + Vector3(0, -drop * 0.5, 0.1), Vector3(high * 0.1, drop, 0.03), VaelBuilder.SAIL.darkened(rng.randf_range(0.1, 0.35)), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-6, 6)))
	# The crow's nest.
	var nest := Vector3(0, g, 0).lerp(top, 0.88)
	l.prism(nest, nest + Vector3(0, 0.5, 0), 0.5, 0.55, 8, VaelBuilder.WOOD_DARK.lightened(0.05))
	# Stays down to the seabed.
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var foot := Vector3(cos(a) * high * 0.45, 0, sin(a) * high * 0.45)
		foot.y = _local_ground(b, foot.x, foot.z) + 0.05
		l.prism(nest, foot, 0.025, 0.025, 3, VaelBuilder.ROPE.darkened(0.3))
	# The corpse-light, hanging from the masthead.
	var lamp := top + Vector3(0.0, -0.45, 0.0)
	l.prism(top, lamp + Vector3(0, 0.25, 0), 0.02, 0.02, 3, IRON)
	l.box(lamp + Vector3(0, 0.22, 0), Vector3(0.32, 0.06, 0.32), IRON)
	_glow(b, func(g2: LowPoly) -> void: g2.box(lamp, Vector3(0.24, 0.36, 0.24), DEEP_GLOW))
	b.w.add_glow(b.xf * lamp, DEEP_GLOW, 2.2)
	MesenllaBuilder._light(b, lamp, DEEP_GLOW, 1.4, 9.0)


## A bed of kelp on the seabed, `radius` across: tall strands standing up in clumps, with rocks among
## them and anemones glowing green and violet in the dark.
static func kelp_bed(b: MapBuilder, radius: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var glows := b.mesh()
	var clumps := int(radius * 1.6) + 3
	for k in clumps:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var at := Vector3(cos(a) * d, 0, sin(a) * d)
		at.y = _local_ground(b, at.x, at.z)
		for s in rng.randi_range(3, 6):
			var foot := at + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			var tall := rng.randf_range(1.0, 2.6)
			var sway := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
			var mid := foot + Vector3(0, tall * 0.5, 0) + sway * 0.4
			var tip := foot + Vector3(0, tall, 0) + sway
			var col := KELP if s % 2 == 0 else KELP_DARK
			l.prism(foot, mid, 0.04, 0.035, 3, col)
			l.prism(mid, tip, 0.035, 0.01, 3, col.lightened(0.05))
			l.leaf(mid, mid + Vector3(0.18, 0.15, 0.05), tip, col.lightened(0.1))
			l.leaf(foot.lerp(mid, 0.5), foot.lerp(mid, 0.5) + Vector3(-0.15, 0.2, 0.0), mid, col)
		if rng.randf() < 0.5:
			l.box(at + Vector3(0.4, 0.15, 0.2), Vector3(0.6, 0.4, 0.5), VaelBuilder.ROCK_DARK, Vector3(rng.randf_range(-20, 20), rng.randf() * 90, 0))
		# Anemones: soft glowing tufts.
		for n in rng.randi_range(1, 3):
			var p := at + Vector3(rng.randf_range(-0.6, 0.6), 0.05, rng.randf_range(-0.6, 0.6))
			var c := DEEP_GLOW if rng.randf() < 0.65 else VIOLET_GLOW
			glows.prism(p, p + Vector3(0, 0.12, 0), 0.07, 0.11, 6, c.darkened(0.25))
			for t in 5:
				var ta := TAU * t / 5.0
				glows.prism(p + Vector3(0, 0.1, 0), p + Vector3(cos(ta) * 0.1, 0.22, sin(ta) * 0.1), 0.02, 0.008, 3, c)
	MesenllaBuilder._shine(b, glows)
	b.w.add_glow(b.xf * Vector3(0, 0.4, 0), DEEP_GLOW, radius * 0.6)


## A tide pool in a ring of rocks: still dark water, anemones glowing round its edge, starfish and
## shells on the stones.
static func tide_pool(b: MapBuilder, radius: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var coastal := b.look == "vael"
	var details := l if coastal else b.mesh()
	var g := _local_ground(b, 0, 0)
	l.prism(Vector3(0, g - 0.02, 0), Vector3(0, g + 0.04, 0), radius, radius, 12, Color(0.06, 0.12, 0.13))
	var stones := int(radius * 5.0)
	for k in stones:
		var a := TAU * k / stones + rng.randf_range(-0.1, 0.1)
		var at := Vector3(cos(a) * radius, 0, sin(a) * radius)
		at.y = _local_ground(b, at.x, at.z) + 0.12
		var s := rng.randf_range(0.35, 0.7)
		l.box(at, Vector3(s, s * 0.6, s * 0.8), VaelBuilder.ROCK.darkened(rng.randf_range(0.0, 0.3)), Vector3(rng.randf_range(-20, 20), rad_to_deg(a), rng.randf_range(-15, 15)))
		if rng.randf() < 0.45:
			var c := DEEP_GLOW if rng.randf() < 0.6 else VIOLET_GLOW
			if coastal:
				c = c.darkened(0.65)
			var p := at * 0.85 + Vector3(0, -0.05, 0)
			for t in 4:
				var ta := TAU * t / 4.0
				details.prism(p, p + Vector3(cos(ta) * 0.09, 0.14, sin(ta) * 0.09), 0.025, 0.008, 3, c)
		if rng.randf() < 0.2:
			# A starfish on the stone.
			var p := at + Vector3(0, s * 0.31, 0)
			for t in 5:
				var ta := TAU * t / 5.0
				l.prism(p, p + Vector3(cos(ta) * 0.16, 0.01, sin(ta) * 0.16), 0.04, 0.012, 3, Color(0.8, 0.35, 0.18))
	if not coastal:
		MesenllaBuilder._shine(b, details)
		b.w.add_glow(b.xf * Vector3(0, g + 0.3, 0), DEEP_GLOW, radius * 0.8)


## A head of a drowned statue standing up out of the sea, crowned, its eyes still faintly lit.
static func statue_head(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var g := _local_ground(b, 0, 0)
	var tilt := Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-15, 15))
	var head := Transform3D(Basis.from_euler(tilt * PI / 180.0), Vector3(0, g + size * 0.4, 0))
	var h := b.mesh()
	h.base = b.xf * head
	h.box(Vector3.ZERO, Vector3(size * 0.85, size, size * 0.9), BRONZE)
	h.prism(Vector3(0, -size * 0.35, size * 0.42), Vector3(0, -size * 0.75, size * 0.5), size * 0.35, size * 0.1, 5, BRONZE_DARK)
	h.box(Vector3(0, size * 0.05, size * 0.47), Vector3(size * 0.14, size * 0.3, size * 0.12), BRONZE.lightened(0.05))
	VaelModels.crown(h, Vector3(0, size * 0.5, 0), size * 0.5)
	VaelModels.barnacles(h, Vector3(-size * 0.4, -size * 0.2, 0), Vector3(-1, 0, 0), 6, size * 0.05, rng)
	b.add(h)
	var eyes := b.mesh()
	eyes.base = b.xf * head
	for side: float in [-1.0, 1.0]:
		eyes.box(Vector3(side * size * 0.2, size * 0.12, size * 0.46), Vector3(size * 0.14, size * 0.07, 0.04), DEEP_GLOW)
	MesenllaBuilder._shine(b, eyes)
	b.w.add_glow(b.xf * (head * Vector3(0, size * 0.12, size * 0.5)), DEEP_GLOW, size * 0.9)
	b.solid(Vector3(0, g + size * 0.4, 0), Vector3(size * 0.9, size * 1.4, size * 0.9))


# --- The harbour and the town --------------------------------------------------------------------

## A brazier of the old harbour: an iron bowl on a stone pedestal with a fire burning in it.
static func brazier(b: MapBuilder) -> void:
	var l := b.cell()
	l.prism(Vector3(0, 0, 0), Vector3(0, 0.25, 0), 0.42, 0.38, 8, STONE_DARK)
	l.prism(Vector3(0, 0.25, 0), Vector3(0, 0.95, 0), 0.18, 0.15, 8, STONE)
	l.prism(Vector3(0, 0.95, 0), Vector3(0, 1.25, 0), 0.25, 0.55, 8, IRON)
	l.prism(Vector3(0, 1.22, 0), Vector3(0, 1.3, 0), 0.57, 0.57, 8, IRON.lightened(0.1))
	for k in 4:
		var a := TAU * k / 4.0
		l.prism(Vector3(cos(a) * 0.12, 1.2, sin(a) * 0.12), Vector3(cos(a + 0.6) * 0.2, 1.38, sin(a + 0.6) * 0.2), 0.05, 0.04, 4, Color(0.15, 0.1, 0.08))
	var rng := b.seeded()
	_glow(b, func(g: LowPoly) -> void: flames(g, Vector3(0, 1.24, 0), 0.5, rng))
	b.solid(Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.7))
	b.w.add_glow(b.xf * Vector3(0, 1.6, 0), FIRE, 2.2)
	b.w.add_fire(b.xf.origin, WorldLight.LANTERN_REACH)
	MesenllaBuilder._light(b, Vector3(0, 1.9, 0), FIRE, 1.8, 10.0)
	sparks(b, Vector3(0, 1.7, 0), 0.25)


## A fire: tongues of flame of different heights leaning a little this way and that, deep orange
## outside, then yellow, then a white-hot core, and glowing coals round their feet. `size` is its width.
static func flames(g: LowPoly, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var layers := [[Color(0.95, 0.35, 0.1), 1.0, 7], [Color(1.0, 0.62, 0.18), 0.72, 5], [Color(1.0, 0.9, 0.55), 0.42, 3]]
	for layer: Array in layers:
		var col: Color = layer[0]
		var k: float = layer[1]
		for t in int(layer[2]):
			var a := TAU * t / float(layer[2]) + rng.randf() * 0.6
			var foot := at + Vector3(cos(a), 0, sin(a)) * size * 0.32 * k
			var tall := size * k * rng.randf_range(1.1, 2.0)
			var tip := foot + Vector3(cos(a) * size * 0.12 + rng.randf_range(-0.05, 0.05), tall, sin(a) * size * 0.12 + rng.randf_range(-0.05, 0.05))
			g.prism(foot, tip, size * 0.22 * k, 0.0, 4, col)
	for t in 6:
		var a := TAU * t / 6.0
		g.box(at + Vector3(cos(a), 0, sin(a)) * size * 0.4 + Vector3(0, 0.02, 0), Vector3.ONE * size * 0.16, Color(1.0, 0.4, 0.12), Vector3(rng.randf() * 40, rng.randf() * 90, 0))


## Sparks going up off a fire: small, bright and quick, few.
static var _spark_mesh: QuadMesh
static func sparks(b: MapBuilder, local: Vector3, spread: float) -> void:
	if b.is_preview or b.quality == 0:
		return
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.07, 0.07)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = load("res://assets/sprites/glow.png")
		m.albedo_color = Color(1.0, 0.7, 0.3)
		m.disable_fog = true
		_spark_mesh.material = m
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.amount = 10
	p.lifetime = 1.4
	p.preprocess = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.2, 0.6, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 0.4, 0.1, 0))
	p.color_ramp = ramp
	p.position = b.xf * local
	p.visibility_range_end = 60.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(p)
	b.w.add_scenery(p, 50.0)


## A roadside shrine of the Tide: a little stone niche on a post, a small figure of a Tide King in it,
## candles burning before it and shells left as offerings.
static func shrine(b: MapBuilder) -> void:
	var rng := b.seeded()
	var l := b.cell()
	l.box(Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 0.5), STONE)
	l.box(Vector3(0, 1.45, 0), Vector3(0.95, 0.75, 0.7), STONE.lightened(0.04))
	l.box(Vector3(0, 1.45, 0.12), Vector3(0.62, 0.55, 0.5), STONE_DARK.darkened(0.3))
	l.gable(Vector3(-0.6, 1.83, 0.4), Vector3(0.6, 1.83, 0.4), Vector3(0, 2.2, 0.4), VaelBuilder.QUAY_DARK)
	l.box(Vector3(0, 2.0, 0), Vector3(1.25, 0.08, 0.95), VaelBuilder.QUAY_DARK, Vector3(0, 0, 0))
	l.prism(Vector3(0, 1.2, 0.05), Vector3(0, 1.55, 0.05), 0.11, 0.06, 6, BRONZE)
	l.box(Vector3(0, 1.62, 0.05), Vector3(0.09, 0.1, 0.09), BRONZE.lightened(0.05))
	VaelModels.crown(l, Vector3(0, 1.67, 0.05), 0.06)
	for k in 5:
		l.box(Vector3(rng.randf_range(-0.35, 0.35), 0.05, rng.randf_range(0.35, 0.6)), Vector3(0.1, 0.05, 0.08), Color(0.9, 0.84, 0.74).darkened(rng.randf() * 0.2), Vector3(0, rng.randf() * 90, 0))
	_glow(b, func(g: LowPoly) -> void:
		for k in 3:
			var at := Vector3((k - 1) * 0.16, 1.17, 0.3)
			g.prism(at, at + Vector3(0, 0.12, 0), 0.03, 0.03, 5, Color(0.95, 0.9, 0.8))
			g.prism(at + Vector3(0, 0.12, 0), at + Vector3(0, 0.2, 0), 0.025, 0.0, 4, FLAME))
	b.w.add_glow(b.xf * Vector3(0, 1.35, 0.3), FIRE, 0.9)
	b.solid(Vector3(0, 0.8, 0), Vector3(0.9, 1.6, 0.7))


## A tall pole with a banner of Vael: deep sea-green cloth with a pale crown over a wave, its foot
## frayed by the wind.
static func banner(b: MapBuilder, high: float) -> void:
	var l := b.cell()
	l.prism(Vector3(0, 0, 0), Vector3(0, high, 0), 0.07, 0.05, 6, WOOD_DARK)
	l.prism(Vector3(0, high, 0), Vector3(0, high + 0.25, 0), 0.08, 0.0, 6, GOLD)
	l.prism(Vector3(-0.7, high - 0.3, 0), Vector3(0.7, high - 0.3, 0), 0.035, 0.035, 4, WOOD_DARK)
	var drop := high * 0.5
	l.box(Vector3(0, high - 0.3 - drop * 0.5, 0.04), Vector3(1.3, drop, 0.03), CLOTH_TEAL)
	for k in 5:
		var x := -0.52 + k * 0.26
		l.box(Vector3(x, high - 0.3 - drop - 0.12, 0.04), Vector3(0.18, 0.28, 0.03), CLOTH_TEAL.darkened(0.1), Vector3(0, 0, (k - 2) * 6))
	var mid := Vector3(0, high - 0.3 - drop * 0.42, 0.065)
	VaelModels.crown(l, mid + Vector3(0, 0.08, 0), 0.16)
	for k in 4:
		l.box(mid + Vector3(-0.36 + k * 0.24, -0.22, 0.0), Vector3(0.26, 0.07, 0.02), CLOTH_BONE, Vector3(0, 0, 25 if k % 2 == 0 else -25))
	b.solid(Vector3(0, 1.0, 0), Vector3(0.2, 2.0, 0.2))


## Bunting on a rope `length` metres along X, sagging between two poles: pennants of sea-green, bone
## and rust, for a feast the town never had.
static func bunting(b: MapBuilder, length: float, poles: bool) -> void:
	var l := b.cell()
	var high := 3.6
	if poles:
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * length * 0.5, 0, 0), Vector3(side * length * 0.5, high + 0.2, 0), 0.06, 0.05, 5, WOOD_DARK)
			b.solid(Vector3(side * length * 0.5, 1.0, 0), Vector3(0.2, 2.0, 0.2))
	var cols := [CLOTH_TEAL, CLOTH_BONE, CLOTH_RUST]
	var pieces := int(length / 0.6)
	var prev := Vector3(-length * 0.5, high, 0)
	for k in pieces + 1:
		var u := float(k) / pieces
		var p := Vector3(lerpf(-length * 0.5, length * 0.5, u), high - sin(u * PI) * length * 0.06, 0)
		if k > 0:
			l.prism(prev, p, 0.012, 0.012, 3, ROPE)
			if k < pieces:
				var c: Color = cols[k % 3]
				l.leaf(prev.lerp(p, 0.15), prev.lerp(p, 0.85), prev.lerp(p, 0.5) + Vector3(0, -0.38, 0), c)
				l.leaf(prev.lerp(p, 0.85), prev.lerp(p, 0.15), prev.lerp(p, 0.5) + Vector3(0, -0.38, 0.001), c.darkened(0.15))
		prev = p


## Cargo waiting on the quay for ships that never came: crates stacked high under a lashed tarpaulin,
## barrels, a coil of rope and a heap of sacks.
static func cargo(b: MapBuilder) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var crate := Color(0.5, 0.38, 0.24)
	for k in 4:
		var at := Vector3((k % 2) * 1.05 - 0.5, 0.48 + (k / 2) * 0.95, rng.randf_range(-0.08, 0.08))
		l.box(at, Vector3(1.0, 0.92, 1.0), crate.darkened(rng.randf_range(0.0, 0.2)), Vector3(0, rng.randf_range(-6, 6), 0))
		l.box(at + Vector3(0, 0, 0.51), Vector3(0.9, 0.1, 0.02), crate.darkened(0.35))
	# The tarpaulin over the top, hanging down one side, lashed.
	l.box(Vector3(0, 1.95, 0), Vector3(2.3, 0.06, 1.2), Color(0.32, 0.36, 0.3))
	l.box(Vector3(0, 1.45, -0.58), Vector3(2.3, 1.0, 0.05), Color(0.3, 0.34, 0.28), Vector3(8, 0, 0))
	for x: float in [-0.6, 0.6]:
		l.box(Vector3(x, 1.0, 0.52), Vector3(0.04, 1.95, 0.02), ROPE)
	# Barrels and rope beside it.
	for k in 3:
		var at := Vector3(1.6 + (k % 2) * 0.6, 0.0, -0.3 + k * 0.45)
		l.prism(at, at + Vector3(0, 0.9, 0), 0.3, 0.3, 8, WOOD)
		l.prism(at + Vector3(0, 0.2, 0), at + Vector3(0, 0.26, 0), 0.31, 0.31, 8, IRON)
		l.prism(at + Vector3(0, 0.66, 0), at + Vector3(0, 0.72, 0), 0.31, 0.31, 8, IRON)
	for k in 10:
		var a0 := TAU * k / 10.0
		var a1 := TAU * (k + 1) / 10.0
		for ring in 3:
			var r := 0.22 + ring * 0.07
			l.prism(Vector3(-1.7 + cos(a0) * r, 0.06, 0.6 + sin(a0) * r), Vector3(-1.7 + cos(a1) * r, 0.06, 0.6 + sin(a1) * r), 0.04, 0.04, 3, ROPE.darkened(0.08 * ring))
	for k in 3:
		l.box(Vector3(-1.6 + k * 0.2, 0.22 + (k % 2) * 0.2, -0.3), Vector3(0.55, 0.38, 0.4), Color(0.62, 0.55, 0.4), Vector3(0, k * 25, (k - 1) * 8))
	b.solid(Vector3(0, 1.0, 0), Vector3(2.2, 2.0, 1.2))
	b.solid(Vector3(1.9, 0.45, 0.15), Vector3(1.2, 0.9, 1.6))


## A rack of fish drying on the quay: two A-frames, poles across, rows of split fish hanging.
static func fish_rack(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	for side: float in [-1.0, 1.0]:
		var x := side * length * 0.5
		l.prism(Vector3(x, 0, -0.6), Vector3(x, 2.0, 0), 0.05, 0.04, 4, WOOD_DARK)
		l.prism(Vector3(x, 0, 0.6), Vector3(x, 2.0, 0), 0.05, 0.04, 4, WOOD_DARK)
		b.solid(Vector3(x, 1.0, 0), Vector3(0.2, 2.0, 1.2))
	for y: float in [1.9, 1.35]:
		l.prism(Vector3(-length * 0.5, y, 0), Vector3(length * 0.5, y, 0), 0.03, 0.03, 4, WOOD)
		var x := -length * 0.5 + 0.25
		while x < length * 0.5 - 0.2:
			var hang := rng.randf_range(0.35, 0.5)
			var c := FISH.darkened(rng.randf_range(0.0, 0.3))
			l.prism(Vector3(x, y - 0.04, 0), Vector3(x, y - hang, 0), 0.07, 0.02, 4, c)
			l.leaf(Vector3(x - 0.07, y - hang, 0), Vector3(x + 0.07, y - hang, 0), Vector3(x, y - hang - 0.1, 0), c.darkened(0.2))
			x += rng.randf_range(0.22, 0.32)


## A drift of ghost-lights hanging over the water or the ruins: green sparks wandering slowly, coming
## and going, `size` metres across.
static func ghost_lights(b: MapBuilder, size: float) -> void:
	MesenllaBuilder._mist(b, Vector3(0, 1.4, 0), Vector3(size * 0.5, 1.0, size * 0.5), DEEP_GLOW, int(size * 1.2), 0.15)
	b.w.add_glow(b.xf * Vector3(0, 1.0, 0), DEEP_GLOW, size * 0.35)


# --- The upper town ------------------------------------------------------------------------------

const MOSS := Color(0.3, 0.4, 0.22)
const LAMP_WARM := Color(1.0, 0.72, 0.36)
const PAPER := Color(0.95, 0.7, 0.38)
const LINEN := Color(0.84, 0.82, 0.74)

## A drystone wall `length` metres along X, knee to hip high: rough stones laid without mortar in two
## courses, capped with stones on edge, moss along the top and in the joints.
static func drystone(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var high := 0.95
	var x := -length * 0.5
	while x < length * 0.5 - 0.1:
		var w := minf(rng.randf_range(0.6, 1.1), length * 0.5 - x)
		var y0 := _local_ground(b, x + w * 0.5, 0.0)
		for course in 2:
			var h := high * 0.42
			var c := STONE.darkened(rng.randf_range(0.05, 0.3)).lerp(MOSS, 0.12 if course == 0 else 0.0)
			var off := 0.0 if course == 0 else rng.randf_range(-0.15, 0.15)
			l.box(Vector3(x + w * 0.5 + off, y0 + h * (course + 0.5), rng.randf_range(-0.04, 0.04)), Vector3(w - 0.04, h - 0.03, 0.62 - course * 0.08),
				c, Vector3(rng.randf_range(-3, 3), rng.randf_range(-6, 6), rng.randf_range(-4, 4)))
		# Coping stones set on edge, leaning a little, and moss along them.
		var y_top := y0 + high * 0.84
		var t := x + 0.08
		while t < x + w - 0.05:
			l.box(Vector3(t, y_top + 0.11, 0), Vector3(0.19, 0.26, 0.42), STONE_DARK.lightened(rng.randf_range(0.0, 0.18)), Vector3(0, 0, rng.randf_range(-14, 14)))
			t += 0.24
		if rng.randf() < 0.55:
			l.box(Vector3(x + w * 0.5, y_top + 0.24, rng.randf_range(-0.1, 0.1)), Vector3(w * rng.randf_range(0.4, 0.9), 0.05, 0.3), MOSS.darkened(rng.randf() * 0.25))
		x += w
	b.solid(Vector3(0, high * 0.5 + _local_ground(b, 0, 0), 0), Vector3(length, high, 0.6))


## A cottage garden `wide` by `deep` metres behind a drystone wall left open at the front (+Z): rows
## of kale and leeks, bean poles with their vines, a heap of seaweed dug in for the soil, a barrow.
static func garden(b: MapBuilder, wide: float, deep: float) -> void:
	var rng := b.seeded()
	var keep := b.xf
	for side: Array in [[Vector3(0, 0, -deep * 0.5), 0.0, wide], [Vector3(-wide * 0.5, 0, 0), 90.0, deep], [Vector3(wide * 0.5, 0, 0), 90.0, deep],
			[Vector3(-wide * 0.3, 0, deep * 0.5), 0.0, wide * 0.4], [Vector3(wide * 0.3, 0, deep * 0.5), 0.0, wide * 0.4]]:
		b.xf = keep * Transform3D(Basis(Vector3.UP, deg_to_rad(side[1])), side[0])
		drystone(b, side[2])
	b.xf = keep
	var l := b.cell()
	var soil := Color(0.24, 0.17, 0.11)
	var rows := int((wide - 1.6) / 0.9)
	for r in rows:
		var x := -wide * 0.5 + 1.0 + r * 0.9
		l.box(Vector3(x, _local_ground(b, x, 0) + 0.05, -0.4), Vector3(0.6, 0.12, deep - 2.4), soil.darkened(rng.randf() * 0.2))
		var z := -deep * 0.5 + 1.0
		while z < deep * 0.5 - 1.6:
			var y := _local_ground(b, x, z) + 0.1
			if r % 3 == 2:
				# Bean poles, tied in a wigwam, the vines up them.
				for k in 3:
					var a := TAU * k / 3.0
					l.prism(Vector3(x + cos(a) * 0.25, y, z + sin(a) * 0.25), Vector3(x, y + 1.7, z), 0.025, 0.02, 3, WOOD)
				l.prism(Vector3(x, y, z), Vector3(x, y + 1.4, z), 0.13, 0.04, 5, KELP.lightened(0.15))
				z += 1.1
			else:
				var c := Color(0.22, 0.42, 0.24) if r % 3 == 0 else Color(0.38, 0.5, 0.3)
				for k in 5:
					var a := TAU * k / 5.0 + rng.randf()
					l.leaf(Vector3(x, y, z), Vector3(x + cos(a) * 0.12, y + 0.05, z + sin(a) * 0.12), Vector3(x + cos(a) * 0.3, y + 0.38, z + sin(a) * 0.3), c.darkened(rng.randf() * 0.2))
				z += 0.55
	# The seaweed heap, glistening, and the barrow beside it.
	var hx := wide * 0.5 - 1.0
	var hz := deep * 0.5 - 1.1
	var hy := _local_ground(b, hx, hz)
	for k in 7:
		l.box(Vector3(hx + rng.randf_range(-0.35, 0.35), hy + 0.12 + k * 0.03, hz + rng.randf_range(-0.3, 0.3)), Vector3(0.5, 0.18, 0.4), KELP_DARK.lerp(KELP, rng.randf()), Vector3(rng.randf() * 20, rng.randf() * 90, rng.randf() * 20))
	l.box(Vector3(hx - 1.1, hy + 0.42, hz), Vector3(0.6, 0.28, 0.9), WOOD, Vector3(0, 0, 0))
	l.prism(Vector3(hx - 1.1, hy + 0.17, hz + 0.5), Vector3(hx - 1.1, hy + 0.17, hz + 0.25), 0.16, 0.16, 8, WOOD_DARK)
	for s: float in [-0.25, 0.25]:
		l.prism(Vector3(hx - 1.1 + s, hy + 0.4, hz - 0.4), Vector3(hx - 1.1 + s, hy + 0.5, hz - 1.0), 0.025, 0.025, 4, WOOD_DARK)


## A string of paper lanterns `length` metres along X between two posts, sagging, each lantern a warm
## glow: the town hung them for the Tide feast. Every fourth burns green, for the drowned.
static func lantern_string(b: MapBuilder, length: float, poles: bool) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var high := 4.2
	if poles:
		for side: float in [-1.0, 1.0]:
			var x := side * length * 0.5
			l.prism(Vector3(x, _local_ground(b, x, 0), 0), Vector3(x, high + 0.25, 0), 0.07, 0.055, 5, WOOD_DARK)
			b.solid(Vector3(x, 1.0, 0), Vector3(0.22, 2.0, 0.22))
	var pieces := maxi(4, int(length / 1.6))
	var prev := Vector3(-length * 0.5, high, 0)
	var lamps: Array[Vector3] = []
	for k in pieces + 1:
		var u := float(k) / pieces
		var p := Vector3(lerpf(-length * 0.5, length * 0.5, u), high - sin(u * PI) * length * 0.07, 0)
		if k > 0:
			l.prism(prev, p, 0.012, 0.012, 3, Color(0.15, 0.13, 0.1))
		if k > 0 and k < pieces:
			lamps.append(p)
		prev = p
	_glow(b, func(g: LowPoly) -> void:
		for i in lamps.size():
			var at: Vector3 = lamps[i] + Vector3(0, -0.36, 0)
			var c := DEEP_GLOW if i % 4 == 3 else PAPER.lerp(LAMP_WARM, rng.randf())
			g.prism(at + Vector3(0, -0.18, 0), at + Vector3(0, 0.0, 0), 0.12, 0.17, 8, c)
			g.prism(at, at + Vector3(0, 0.18, 0), 0.17, 0.12, 8, c))
	for i in lamps.size():
		l.prism(lamps[i] + Vector3(0, -0.16, 0), lamps[i], 0.008, 0.008, 3, Color(0.15, 0.13, 0.1))
		if i % 2 == 0:
			b.w.add_glow(b.xf * (lamps[i] + Vector3(0, -0.36, 0)), DEEP_GLOW if i % 4 == 3 else LAMP_WARM, 1.1)
	MesenllaBuilder._light(b, Vector3(0, high - length * 0.07, 0), LAMP_WARM, 0.9, length * 0.6)


## A washing line between two posts `length` metres apart: sheets, shirts and a fisherman's smock,
## grey with salt, hanging still.
static func laundry(b: MapBuilder, length: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var high := 2.3
	for side: float in [-1.0, 1.0]:
		var x := side * length * 0.5
		l.prism(Vector3(x, _local_ground(b, x, 0), 0), Vector3(x, high + 0.15, 0), 0.05, 0.045, 5, WOOD)
		l.prism(Vector3(x, high, -0.25), Vector3(x, high, 0.25), 0.03, 0.03, 4, WOOD)
		b.solid(Vector3(x, 1.0, 0), Vector3(0.18, 2.0, 0.18))
	l.prism(Vector3(-length * 0.5, high, 0), Vector3(length * 0.5, high, 0), 0.01, 0.01, 3, ROPE)
	var x := -length * 0.5 + 0.4
	var cloth := [LINEN, CLOTH_BONE, Color(0.5, 0.55, 0.62), CLOTH_TEAL.lightened(0.2), Color(0.6, 0.42, 0.3)]
	while x < length * 0.5 - 0.6:
		var w := rng.randf_range(0.5, 1.1)
		var drop := rng.randf_range(0.5, 1.0)
		var sag := sin((x + length * 0.5) / length * PI) * length * 0.03
		var c: Color = cloth[rng.randi() % cloth.size()]
		l.box(Vector3(x + w * 0.5, high - sag - drop * 0.5, 0), Vector3(w, drop, 0.02), c.darkened(rng.randf() * 0.15), Vector3(0, 0, rng.randf_range(-3, 3)))
		x += w + rng.randf_range(0.15, 0.4)


## A bench against a wall, with a net on it half mended, and a pair of sea-boots under it.
static func bench(b: MapBuilder) -> void:
	var l := b.cell()
	l.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.07, 0.4), WOOD)
	for x: float in [-0.65, 0.65]:
		l.box(Vector3(x, 0.22, 0), Vector3(0.08, 0.44, 0.34), WOOD_DARK)
	l.box(Vector3(0.3, 0.52, 0.02), Vector3(0.7, 0.08, 0.36), Color(0.36, 0.4, 0.34), Vector3(0, 8, 4))
	l.box(Vector3(0.75, 0.25, 0.25), Vector3(0.4, 0.5, 0.06), Color(0.36, 0.4, 0.34), Vector3(-20, 0, 0))
	for x: float in [-0.35, -0.15]:
		l.prism(Vector3(x, 0, 0.05), Vector3(x, 0.36, 0.05), 0.07, 0.065, 6, Color(0.15, 0.16, 0.15))
	b.solid(Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 0.45))


## A stone chimney on a roof, `high` metres above the piece's spot to its top, smoke rising from it
## slow and grey into the still night air.
static var _smoke_mesh: QuadMesh
static func chimney(b: MapBuilder, high: float) -> void:
	var l := b.cell()
	l.box(Vector3(0, high - 1.4, 0), Vector3(0.75, 2.8, 0.75), STONE.darkened(0.12))
	l.box(Vector3(0, high + 0.04, 0), Vector3(0.9, 0.12, 0.9), STONE_DARK)
	for x: float in [-0.16, 0.16]:
		l.prism(Vector3(x, high + 0.1, 0), Vector3(x, high + 0.42, 0), 0.11, 0.1, 6, Color(0.5, 0.32, 0.24))
	if b.is_preview or b.quality == 0:
		return
	if _smoke_mesh == null:
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(0.9, 0.9)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = load("res://assets/sprites/glow.png")
		m.albedo_color = Color(0.55, 0.6, 0.62, 0.22)
		m.vertex_color_use_as_albedo = true
		_smoke_mesh.material = m
	var p := CPUParticles3D.new()
	p.mesh = _smoke_mesh
	p.amount = 8
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0.12, 0.05, 0.05)
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.55
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 3.2))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	p.position = b.xf * Vector3(0, high + 0.4, 0)
	p.visibility_range_end = 90.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(p)
	b.w.add_scenery(p, 80.0)


## Where the drowned have walked up out of the sea: a wet trail of sea-water still faintly glowing,
## strands of weed and a few shells, `size` metres long, along X.
static func sea_trail(b: MapBuilder, size: float) -> void:
	var rng := b.seeded()
	var l := b.cell()
	var steps := int(size / 0.8)
	var marks: Array[Vector3] = []
	for k in steps:
		var x := -size * 0.5 + k * 0.8 + rng.randf_range(-0.1, 0.1)
		var z := (0.18 if k % 2 == 0 else -0.18) + sin(k * 0.7) * 0.4
		var y := _local_ground(b, x, z) + 0.03
		marks.append(Vector3(x, y, z))
		if rng.randf() < 0.4:
			l.leaf(Vector3(x - 0.2, y + 0.01, z), Vector3(x + 0.25, y + 0.01, z + 0.1), Vector3(x + 0.05, y + 0.02, z + 0.35), KELP.darkened(rng.randf() * 0.3))
		if rng.randf() < 0.25:
			l.box(Vector3(x + 0.3, y + 0.02, z - 0.2), Vector3(0.08, 0.04, 0.06), Color(0.9, 0.84, 0.74), Vector3(0, rng.randf() * 90, 0))
	_glow(b, func(g: LowPoly) -> void:
		for m: Vector3 in marks:
			g.box(m, Vector3(0.22, 0.01, 0.34), DEEP_GLOW.darkened(0.45), Vector3(0, rng.randf_range(-15, 15), 0)))
	b.w.add_glow(b.xf * Vector3(0, 0.3, 0), DEEP_GLOW, size * 0.25)


## A lamp on an iron bracket by a door, left burning for someone still out at sea.
static func porch_lamp(b: MapBuilder) -> void:
	var l := b.cell()
	l.prism(Vector3(0, 2.3, 0), Vector3(0, 2.3, 0.45), 0.025, 0.025, 4, IRON)
	l.prism(Vector3(0, 2.3, 0.45), Vector3(0, 2.1, 0.45), 0.01, 0.01, 3, IRON)
	l.prism(Vector3(0, 1.82, 0.45), Vector3(0, 1.86, 0.45), 0.11, 0.11, 6, IRON)
	l.prism(Vector3(0, 2.05, 0.45), Vector3(0, 2.12, 0.45), 0.11, 0.0, 6, IRON)
	_glow(b, func(g: LowPoly) -> void: g.prism(Vector3(0, 1.86, 0.45), Vector3(0, 2.05, 0.45), 0.08, 0.08, 6, LAMP_WARM))
	b.w.add_glow(b.xf * Vector3(0, 1.95, 0.45), LAMP_WARM, 1.3)
