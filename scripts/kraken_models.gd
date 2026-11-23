class_name KrakenModels
extends RefCounted
## The Kraken of Vael and its arms, one design for both: the four arms that rise out of the flooded
## flats in the middle of the night are the very arms the whole creature wears when it rises at the
## end of it.
##
## An arm: twenty joints, thick and dark red-purple at the root, tapering to a curling tip; pale
## underneath with paired suckers along the side it strikes with (+Z), a dorsal ridge, scars, and
## spots that glow sea-green in the dark down its back.
##
## The Kraken: a great mantle reared out of the sea, ridged and barnacled, leaning back; the broken
## gold-and-coral spires of drowned Vael grown into it like a crown, their windows still lit; two
## huge gold eyes with a bar of black across each; a hooked beak under them; and eight of those arms
## round it, spread over the water and writhing, rearing high and whipping down where it strikes.
## +Z is the way it faces. Node names: Body > Mantle, Crown, Eyes, Beak, Arm0..Arm7 > Arm > Seg0..;
## Foam; Glow.

const SEGMENTS := 20
const SEGMENT := 0.33 # metres: an arm of the miniboss stands 6.6 m tall
const BURIED := -6.8 # where a lone arm waits under the sea before it rises
const ARMS := 8
const ARM_SCALE := 1.55 # the whole Kraken's arms: half as big again
const ARM_RING := 1.9 # metres from the middle of the mantle to the root of each arm
const BODY_SUNK := -13.0 # where the Kraken waits under the sea before it rises
const BODY_SCALE := 1.35 # the whole of it, mantle and arms
const KRAKEN := Color(0.42, 0.16, 0.24)
const KRAKEN_DARK := Color(0.24, 0.08, 0.14)
const SUCKER := Color(0.86, 0.66, 0.62)
const SPOT := Color(0.35, 1.0, 0.8)
const GOLD := Color(0.68, 0.54, 0.24)
const CORAL := Color(0.86, 0.42, 0.36)
const EYE := Color(1.0, 0.78, 0.22)


# --- One arm ----------------------------------------------------------------------------------------

## The segment meshes, shared by every arm (the Kraken's are the same, scaled).
static func _segment(i: int) -> Mesh:
	var r0 := lerpf(0.82, 0.06, pow(float(i) / SEGMENTS, 0.72))
	var r1 := lerpf(0.82, 0.06, pow(float(i + 1) / SEGMENTS, 0.72))
	return MesenllaModels._mesh("kraken_seg%d" % i, func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, SEGMENT, 0), r0, r1, 9, KRAKEN if i % 2 == 0 else KRAKEN.darkened(0.06))
		# The pale underside, and its suckers, toward +Z.
		l.prism(Vector3(0, 0, r0 * 0.45), Vector3(0, SEGMENT, r1 * 0.45), r0 * 0.62, r1 * 0.62, 7, SUCKER.darkened(0.15))
		for s in 2:
			var y := SEGMENT * (0.25 + s * 0.5)
			var r := lerpf(r0, r1, 0.25 + s * 0.5)
			for x: float in [-0.35, 0.35]:
				var p := Vector3(x * r, y, r * 0.98)
				l.prism(p, p + Vector3(0, 0, r * 0.14), r * 0.2, r * 0.17, 7, SUCKER)
				l.prism(p + Vector3(0, 0, r * 0.13), p + Vector3(0, 0, r * 0.15), r * 0.1, r * 0.1, 6, KRAKEN_DARK)
		# The dorsal ridge, scars, and a translucent cutting fin along the tip.
		l.prism(Vector3(0, 0, -r0), Vector3(0, SEGMENT, -r1), r0 * 0.1, r1 * 0.08, 5, KRAKEN_DARK)
		if i > 13:
			l.leaf(Vector3(0, 0, -r0), Vector3(0, SEGMENT * 0.45, -r0 * 2.5), Vector3(0, SEGMENT, -r1), CORAL.darkened(0.2))
		for scar in 2:
			l.prism(Vector3(r0 * 0.8, SEGMENT * (0.2 + scar * 0.4), -r0 * 0.4), Vector3(r0 * 0.6, SEGMENT * (0.4 + scar * 0.4), -r0 * 0.7), 0.014, 0.006, 3, SUCKER.darkened(0.35))
		if i % 3 == 1:
			l.box(Vector3(r0 * 0.3, SEGMENT * 0.5, -r0 * 0.85), Vector3(r0 * 0.6, SEGMENT * 0.4, 0.04), KRAKEN_DARK)
		if i < 3:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2461 + i
			VaelModels.barnacles(l, Vector3(-r0 * 0.7, SEGMENT * 0.5, -r0 * 0.6), Vector3(-1, 0, -0.8), 4, 0.06, rng))


## The glowing spots down its back, every other joint: drawn unlit, so they glow in the dark.
static func _spots(i: int) -> Mesh:
	var r := lerpf(0.82, 0.06, pow((i + 0.5) / SEGMENTS, 0.72))
	return MesenllaModels._mesh("kraken_spots%d" % i, func(l: LowPoly) -> void:
		for x: float in [-0.42, 0.42]:
			var p := Vector3(x * r, SEGMENT * 0.5, -r * 0.9)
			l.prism(p, p + Vector3(0, 0, -r * 0.08), r * 0.13, r * 0.1, 6, SPOT))


## An arm, its root at the parent's origin, standing up (+Y), suckers toward +Z. Returns the pivot
## that lifts the whole of it ("Arm"); its joints are Seg0 > Seg1 > ... below it.
static func arm(parent: Node3D) -> Node3D:
	var root := MesenllaModels._pivot(parent, Vector3.ZERO, "Arm")
	var at := root
	var where := Vector3.ZERO
	var glow := MesenllaModels.glow_material()
	for i in SEGMENTS:
		var seg := MesenllaModels._pivot(at, where, "Seg%d" % i)
		MesenllaModels._part(seg, _segment(i))
		if i % 2 == 0 and i < SEGMENTS - 3:
			MesenllaModels._part(seg, _spots(i)).material_override = glow
		at = seg
		where = Vector3(0, SEGMENT, 0)
	return root


## Where it comes up out of the sea: a ring of churned white water round a dark swirl, turning.
static var _foam_ring: TorusMesh
static var _foam_mat: StandardMaterial3D
static func _foam(parent: Node3D, size: float, label: String, swirl_under := true) -> Node3D:
	if _foam_ring == null:
		_foam_ring = TorusMesh.new()
		_foam_ring.inner_radius = 1.0
		_foam_ring.outer_radius = 1.75
		_foam_ring.rings = 28
		_foam_ring.ring_segments = 5
		_foam_mat = StandardMaterial3D.new()
		_foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_foam_mat.albedo_color = Color(0.86, 0.98, 0.96, 0.55)
	var foam := MesenllaModels._pivot(parent, Vector3(0, 0.05, 0), label)
	if swirl_under:
		_swirl_disc(foam)
	var ring := MeshInstance3D.new()
	ring.mesh = _foam_ring
	ring.material_override = _foam_mat
	ring.scale = Vector3(1.0, 0.18, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.add_child(ring)
	foam.scale = Vector3(size, 1.0, size)
	return foam


static func _swirl_disc(foam: Node3D) -> void:
	var swirl := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.9
	disc.bottom_radius = 1.9
	disc.height = 0.02
	disc.radial_segments = 28
	swirl.mesh = disc
	var water := ShaderMaterial.new()
	water.shader = SeaSerpentBody._water_shader()
	swirl.material_override = water
	swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.add_child(swirl)


## The Kraken's Arm, the miniboss: one arm out of the sea in a ring of foam.
static func arm_parts(root: Node3D) -> void:
	_foam(root, 1.0, "Foam")
	var lone := arm(root)
	lone.position.y = BURIED


## The foam lies on the water where it comes up out of it, whatever the ground under the sea.
static func _float(z: Zombie, foam: Node3D) -> void:
	var sea := z.world.tide.level if z.world.tide else z.position.y
	foam.global_position.y = maxf(sea, z.world.ground_at(z.position)) + 0.06


## Each joint's bend toward its suckers (x) and to the side (z), eased toward what is wanted.
static func _bend(root: Node3D, want: Callable, k: float) -> void:
	var at := root.get_node("Seg0") as Node3D
	for i in SEGMENTS:
		var w: Vector2 = want.call(i, float(i) / SEGMENTS)
		at.rotation.x = lerpf(at.rotation.x, w.x, k)
		at.rotation.z = lerpf(at.rotation.z, w.y, k)
		if i < SEGMENTS - 1:
			at = at.get_node("Seg%d" % (i + 1)) as Node3D


## The lone arm, each frame: rising out of the sea or sinking back, swaying and curling where it
## stands; rearing back high before a slam (the tell) and whipping down in front; sweeping round low.
static func animate_arm(z: Zombie, root: Node3D, delta: float, state: String, t: float, act: float) -> void:
	var lone := root.get_node("Arm") as Node3D
	var foam := root.get_node("Foam") as Node3D
	foam.rotation.y = t * 0.6
	_float(z, foam)
	foam.scale = Vector3(1.0 + sin(t * 2.3) * 0.06, 1.0, 1.0 + sin(t * 2.3) * 0.06)
	var k := minf(1.0, delta * 9.0)
	var up := 1.0
	match state:
		"m_rise": up = smoothstep(0.0, VaelMind.RISE_TIME, act)
		"m_sink": up = 1.0 - smoothstep(0.0, VaelMind.SINK_TIME, act)
	lone.position.y = lerpf(BURIED, -0.3, up)
	var warning := z.is_warning()
	if state == "m_slam" and not warning:
		k = minf(1.0, delta * 26.0)
	elif state == "m_swipe":
		k = minf(1.0, delta * 18.0)
	_bend(lone, func(i: int, f: float) -> Vector2:
		# Standing: a slow wave runs up it and the tip curls over toward you.
		var x := sin(t * 1.5 - i * 0.36) * (0.025 + f * 0.035) + f * f * 0.17
		var y := sin(t * 1.1 - i * 0.28) * (0.02 + f * 0.04)
		match state:
			"m_slam":
				if warning:
					var coil := clampf(act / maxf(VaelMind.KRAKEN_TELL - 0.25, 0.1), 0.0, 1.0)
					x = lerpf(x, -0.22 + f * 0.35 if i > 2 else -0.1, coil)
					y = sin(t * 7.0 - i) * 0.03 * coil
				else:
					var whip := clampf(act / 0.18, 0.0, 1.0)
					x = lerpf(-0.2, (0.21 if i < 6 else 0.015) - (0.0 if f < 0.8 else 0.08), whip)
					y = 0.0
			"m_swipe":
				var sweep := clampf(act / 0.45, 0.0, 1.0)
				x = 0.16 if i < 6 else 0.06
				y = (0.22 if i < 5 else 0.05) * lerpf(-1.0, 1.0, sweep)
			"m_rise", "m_sink":
				x = sin(t * 4.0 - i * 0.6) * 0.15
		return Vector2(x, y), k)


## A lone arm dying: it shudders, goes limp, falls over sideways into the water and sinks.
static func fall_arm(root: Node3D, k: float, side: float) -> void:
	var lone := root.get_node("Arm") as Node3D
	var limp := smoothstep(0.15, 1.2, k)
	lone.rotation.z = side * 1.35 * limp
	lone.position.y = -0.3 - smoothstep(1.4, 2.6, k) * 3.5
	_bend(lone, func(i: int, _f: float) -> Vector2:
		return Vector2(sin(k * 30.0 - i) * 0.08 * (1.0 - limp) + 0.04 * limp, side * 0.06 * limp), 1.0)
	(root.get_node("Foam") as Node3D).scale = Vector3(1.0 + k * 0.4, 1.0, 1.0 + k * 0.4)


# --- The Kraken ---------------------------------------------------------------------------------------

static func kraken_parts(root: Node3D) -> void:
	_foam(root, 3.4, "Foam", false)
	var body := MesenllaModels._pivot(root, Vector3(0, BODY_SUNK, 0), "Body")
	body.scale = Vector3.ONE * BODY_SCALE
	var glow := MesenllaModels.glow_material()
	var mantle := MesenllaModels._pivot(body, Vector3.ZERO, "Mantle")
	MesenllaModels._part(mantle, MesenllaModels._mesh("kraken_mantle", func(l: LowPoly) -> void:
		# The mantle: rings of hide, widest low down, leaning back to a blunt crest; ribs down it.
		var rings: Array[Vector3] = [Vector3(0, -0.6, 2.25), Vector3(0, 0.6, 2.5), Vector3(-0.2, 2.0, 2.65), Vector3(-0.6, 3.4, 2.4),
			Vector3(-1.1, 4.7, 1.9), Vector3(-1.7, 5.8, 1.25), Vector3(-2.3, 6.6, 0.55), Vector3(-2.6, 7.0, 0.05)]
		for i in rings.size() - 1:
			var a := rings[i]
			var b := rings[i + 1]
			l.prism(Vector3(0, a.y, a.x), Vector3(0, b.y, b.x), a.z, b.z, 12, KRAKEN if i % 2 == 0 else KRAKEN.darkened(0.07))
		for r in 10:
			var ang := TAU * r / 10.0
			for i in rings.size() - 2:
				var a := rings[i]
				var b := rings[i + 1]
				var pa := Vector3(sin(ang) * a.z * 1.01, a.y, a.x + cos(ang) * a.z * 1.01)
				var pb := Vector3(sin(ang) * b.z * 1.01, b.y, b.x + cos(ang) * b.z * 1.01)
				l.prism(pa, pb, 0.12, 0.09, 4, KRAKEN_DARK)
		# The pale throat and the folds of the siphon under the eyes.
		l.prism(Vector3(0, -0.4, 1.6), Vector3(0, 1.4, 2.0), 1.3, 1.0, 9, SUCKER.darkened(0.25))
		l.prism(Vector3(1.6, 0.0, 1.2), Vector3(2.1, 0.5, 1.9), 0.45, 0.25, 7, KRAKEN_DARK)
		# Brows over each eye, heavy and scarred.
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * 1.4, 3.15, 1.6), Vector3(side * 2.3, 2.95, 0.6), 0.42, 0.22, 6, KRAKEN_DARK)
			for scar in 3:
				l.prism(Vector3(side * (1.9 + scar * 0.15), 1.4 + scar * 0.5, 1.9 - scar * 0.2), Vector3(side * (2.1 + scar * 0.15), 1.9 + scar * 0.5, 1.6 - scar * 0.2), 0.04, 0.02, 3, SUCKER.darkened(0.3))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7711
		for i in 9:
			var ang := rng.randf_range(-PI, PI)
			var y := rng.randf_range(0.2, 5.0)
			var r := lerpf(2.5, 1.4, y / 5.0)
			VaelModels.barnacles(l, Vector3(sin(ang) * r, y, -0.4 * y / 5.0 + cos(ang) * r), Vector3(sin(ang), 0.2, cos(ang)), 5, 0.12, rng)))
	MesenllaModels._part(mantle, MesenllaModels._mesh("kraken_mantle_spots", func(l: LowPoly) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 991
		for i in 26:
			var ang := rng.randf_range(-PI * 0.95, PI * 0.95)
			var y := rng.randf_range(0.4, 5.6)
			var r := lerpf(2.55, 1.35, y / 5.6) + 0.04
			var p := Vector3(sin(ang) * r, y, -0.45 * y / 5.6 + cos(ang) * r)
			l.prism(p, p + Vector3(sin(ang), 0, cos(ang)) * 0.05, rng.randf_range(0.07, 0.15), 0.06, 6, SPOT))).material_override = glow
	# The crown: the broken towers of drowned Vael, grown into its head, gold under coral and weed.
	var crown := MesenllaModels._pivot(body, Vector3(-0.0, 5.0, -1.3), "Crown")
	crown.scale = Vector3.ONE * 1.35
	MesenllaModels._part(crown, MesenllaModels._mesh("kraken_crown", func(l: LowPoly) -> void:
		for i in 7:
			var ang := lerpf(-1.25, 1.25, i / 6.0)
			var high := 1.2 + (1.3 if i == 3 else 0.7 if i in [2, 4] else 0.2) + 0.25 * sin(i * 2.3)
			var base := Vector3(sin(ang) * 1.25, 0.0, cos(ang) * 1.25 - 0.3)
			var lean := Vector3(sin(ang) * 0.3, 0, -0.35)
			l.prism(base, base + lean * 0.5 + Vector3.UP * high, 0.32, 0.22, 6, GOLD.darkened(0.1 * (i % 2)))
			l.prism(base + lean * 0.5 + Vector3.UP * high, base + lean + Vector3.UP * (high + 0.75), 0.24, 0.0, 6, GOLD.darkened(0.25))
			l.prism(base + Vector3.UP * 0.1, base + Vector3(0.18, 0.7, 0.1), 0.22, 0.05, 5, CORAL)
			l.prism(base + Vector3.UP * 0.3, base + Vector3(-0.2, 0.9, 0.12), 0.12, 0.0, 4, CORAL.darkened(0.2))
		l.prism(Vector3(0, -0.15, -0.3), Vector3(0, 0.2, -0.3), 1.55, 1.5, 12, GOLD.darkened(0.3))))
	MesenllaModels._part(crown, MesenllaModels._mesh("kraken_crown_windows", func(l: LowPoly) -> void:
		for i in 7:
			var ang := lerpf(-1.25, 1.25, i / 6.0)
			var high := 1.2 + (1.3 if i == 3 else 0.7 if i in [2, 4] else 0.2) + 0.25 * sin(i * 2.3)
			var base := Vector3(sin(ang) * 1.25, 0.0, cos(ang) * 1.25 - 0.3)
			for w in 2:
				var at := base + Vector3(sin(ang) * 0.3, high * (0.35 + 0.3 * w), cos(ang) * 0.3)
				l.box(at, Vector3(0.08, 0.16, 0.08), SPOT))).material_override = glow
	# The eyes: great gold discs with a bar of black across each, under the brows.
	var eyes := MesenllaModels._pivot(body, Vector3(0, 2.55, 0), "Eyes")
	for side: float in [-1.0, 1.0]:
		var eye := MesenllaModels._pivot(eyes, Vector3(side * 1.75, 0.15, 1.75), "Eye" + ("L" if side < 0 else "R"))
		eye.rotation.y = side * 0.6
		eye.scale = Vector3.ONE * 1.3
		MesenllaModels._part(eye, MesenllaModels._mesh("kraken_eye", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0, -0.1), Vector3(0, 0, 0.12), 0.62, 0.58, 12, EYE))).material_override = glow
		MesenllaModels._part(eye, MesenllaModels._mesh("kraken_pupil", func(l: LowPoly) -> void:
			l.box(Vector3(0, 0, 0.14), Vector3(0.86, 0.15, 0.04), Color(0.02, 0.01, 0.02))
			# The lid's rim round it, dark and heavy.
			for k in 12:
				var a0 := TAU * k / 12.0
				var a1 := TAU * (k + 1) / 12.0
				l.prism(Vector3(cos(a0), sin(a0), 0) * 0.66 + Vector3(0, 0, 0.06), Vector3(cos(a1), sin(a1), 0) * 0.66 + Vector3(0, 0, 0.06), 0.09, 0.09, 4, KRAKEN_DARK)))
	# The beak, hooked, under the eyes; it opens as it roars.
	var beak := MesenllaModels._pivot(body, Vector3(0, 0.85, 2.15), "Beak")
	MesenllaModels._part(beak, MesenllaModels._mesh("kraken_beak_top", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.15, -0.2), Vector3(0, -0.35, 0.75), 0.55, 0.0, 7, Color(0.12, 0.1, 0.12))
		l.prism(Vector3(0, 0.0, -0.2), Vector3(0, 0.12, 0.4), 0.4, 0.2, 7, Color(0.2, 0.16, 0.16))))
	var jaw := MesenllaModels._pivot(beak, Vector3(0, -0.2, 0), "Jaw")
	MesenllaModels._part(jaw, MesenllaModels._mesh("kraken_beak_low", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.2), Vector3(0, -0.15, 0.55), 0.42, 0.0, 7, Color(0.16, 0.12, 0.14))))
	# Eight arms round the base of the mantle, roots under the water.
	for i in ARMS:
		var ang := TAU * (i + 0.5) / ARMS
		var socket := MesenllaModels._pivot(body, Vector3(sin(ang) * ARM_RING, -0.2, cos(ang) * ARM_RING), "Arm%d" % i)
		socket.rotation.y = ang
		socket.scale = Vector3.ONE * ARM_SCALE
		arm(socket)
	# Its whirlpool: the sea turning round it, out to where it draws you in from.
	var whirl := MeshInstance3D.new()
	whirl.name = "Whirl"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 40
	whirl.mesh = disc
	var turning := ShaderMaterial.new()
	turning.shader = _whirl_shader()
	whirl.material_override = turning
	whirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	whirl.scale = Vector3(VaelMind.KRAKEN_PULL_REACH, 1.0, VaelMind.KRAKEN_PULL_REACH)
	whirl.visible = false
	root.add_child(whirl)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = SPOT
	light.light_energy = 0.0
	light.omni_range = 16.0
	light.position = Vector3(0, 2.0, 2.5)
	root.add_child(light)


static var _whirl: Shader
static func _whirl_shader() -> Shader:
	if _whirl == null:
		_whirl = Shader.new()
		_whirl.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 1.0;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float arms = sin(a * 5.0 + log(r + 0.02) * 9.0 + TIME * 5.0) * 0.5 + 0.5;
	float foam = smoothstep(0.75, 1.0, arms) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = mix(vec3(0.05, 0.25, 0.28), vec3(0.85, 1.0, 0.97), foam);
	ALPHA = strength * (0.18 + foam * 0.6) * (1.0 - smoothstep(0.9, 1.0, r)) * smoothstep(0.08, 0.25, r);
}
"""
	return _whirl


## Where each of its arms points, as an angle round the body (0 = straight ahead).
static func arm_angle(i: int) -> float:
	return TAU * (i + 0.5) / ARMS


## Each frame. What its arms do follows the rings on the ground it has cast: for each ring, the arm
## that points nearest it rears up high over the water for the tell and whips down onto it; for its
## hook, the nearest arm reaches out flat; its sweep throws every arm round low. Otherwise they lie
## spread on the water, writhing, two of them always raised and waving.
static func animate_kraken(z: Zombie, root: Node3D, delta: float, state: String, t: float, act: float) -> void:
	var body := root.get_node("Body") as Node3D
	var foam := root.get_node("Foam") as Node3D
	var light := root.get_node("Glow") as OmniLight3D
	foam.rotation.y = t * 0.35
	_float(z, foam)
	var rise := 1.0
	match state:
		"m_rise": rise = smoothstep(0.0, VaelMind.KRAKEN_RISE, act)
	body.position.y = lerpf(BODY_SUNK, 0.0, 1.0 - pow(1.0 - rise, 2.0))
	var spread := 3.4 + sin(t * 1.7) * 0.2 + (1.0 - rise) * 2.0
	foam.scale = Vector3(spread, 1.0, spread)
	light.light_energy = lerpf(light.light_energy, 2.2 * rise + (2.0 if state in ["m_roar", "m_pull"] else 0.0), minf(1.0, delta * 4.0))
	# The whirlpool shows while it turns, swelling in and dying away.
	var whirl := root.get_node("Whirl") as MeshInstance3D
	var turning := state == "m_pull"
	var w_strength := float(whirl.get_meta("strength", 0.0))
	w_strength = move_toward(w_strength, 1.0 if turning else 0.0, delta * (1.5 if turning else 0.8))
	whirl.set_meta("strength", w_strength)
	whirl.visible = w_strength > 0.01
	(whirl.material_override as ShaderMaterial).set_shader_parameter("strength", w_strength)
	_float(z, whirl)
	whirl.global_position.y += 0.03
	var k := minf(1.0, delta * 6.0)
	# The mantle breathes, leans back as it roars, sways a little toward what it watches.
	var mantle := body.get_node("Mantle") as Node3D
	var breath := sin(t * 1.2)
	mantle.scale = Vector3(1.0 + breath * 0.03, 1.0 + breath * 0.045, 1.0 + breath * 0.03)
	var lean := -0.28 if state in ["m_roar", "m_pull"] else -0.12 if state == "m_ink" else 0.0
	body.rotation.x = lerpf(body.rotation.x, lean + sin(t * 0.6) * 0.03, k)
	body.rotation.z = lerpf(body.rotation.z, sin(t * 0.45) * 0.04, k)
	var jaw := body.get_node("Beak/Jaw") as Node3D
	var open := 0.75 if state in ["m_roar", "m_ink", "m_pull"] else 0.35 if z.is_warning() else 0.06 + 0.05 * sin(t * 1.9)
	jaw.rotation.x = lerpf(jaw.rotation.x, open, minf(1.0, delta * 8.0))
	# It blinks now and then; its eyes narrow as it rears to strike.
	var eyes := body.get_node("Eyes") as Node3D
	var blink := 1.0 - (1.0 if fposmod(t + z.net_id, 7.3) < 0.14 else 0.0)
	eyes.scale.y = lerpf(eyes.scale.y, blink * (0.7 if z.is_warning() else 1.0), minf(1.0, delta * 20.0))
	# Which rings each arm answers.
	var seals: Array[MistSeal] = []
	for seal: MistSeal in z.world.mist_seals:
		if seal.source_id == z.net_id and is_instance_valid(seal):
			seals.append(seal)
	var taken := {}
	var plan := {}
	for seal: MistSeal in seals:
		if seal.style == MistSeal.Style.WAVE:
			continue # its waves and sweep belong to the whole body, not to one arm
		var rel := (seal.global_position - root.global_position)
		var local := root.global_basis.inverse() * rel
		var ang := atan2(local.x, local.z)
		var best := -1
		var near := INF
		for i in ARMS:
			if taken.has(i):
				continue
			var d := absf(wrapf(arm_angle(i) - ang, -PI, PI))
			if d < near:
				near = d
				best = i
		if best >= 0:
			taken[best] = true
			plan[best] = {"seal": seal, "turn": wrapf(ang - arm_angle(best), -PI, PI), "reach": Vector2(local.x, local.z).length()}
	var sweeping := state == "m_sweep"
	for i in ARMS:
		var socket := body.get_node("Arm%d" % i) as Node3D
		var limb := socket.get_node("Arm") as Node3D
		var phase := i * 1.37
		var base := 1.22 + sin(t * 0.7 + phase) * 0.06 # spread out over the water
		var turn := sin(t * 0.5 + phase) * 0.12
		var raised := (i == 1 or i == 6) and not sweeping
		var ks := k
		var want := func(j: int, f: float) -> Vector2:
			# Lying out over the water, drooping to it, the last third lifting and curling, a wave running down it.
			return Vector2((0.03 if f < 0.45 else -0.07 * f) + sin(t * 1.6 - j * 0.4 + phase) * 0.035, sin(t * 1.1 - j * 0.3 + phase) * 0.04)
		if raised:
			base = 0.15 + sin(t * 0.8 + phase) * 0.12
			want = func(j: int, f: float) -> Vector2:
				return Vector2(sin(t * 1.4 - j * 0.35 + phase) * (0.04 + f * 0.05) + f * f * 0.16, sin(t * 1.0 - j * 0.3) * 0.04)
		if plan.has(i):
			var p: Dictionary = plan[i]
			var seal: MistSeal = p["seal"]
			turn = p["turn"]
			var left := seal.warning - seal.elapsed
			if seal.style == MistSeal.Style.HOOK:
				# Reaching out flat along the ground for whoever it means to drag in.
				base = lerpf(base, 1.42, clampf(seal.elapsed / maxf(seal.warning, 0.1), 0.0, 1.0))
				want = func(_j: int, f: float) -> Vector2: return Vector2(0.01 + (0.18 * f if left < 0.0 else 0.0), 0.0)
				ks = minf(1.0, delta * (14.0 if left < 0.2 else 5.0))
			elif left > 0.2:
				# Reared high and back over the water, coiled: the tell.
				var coil := clampf(seal.elapsed / maxf(seal.warning - 0.2, 0.1), 0.0, 1.0)
				base = lerpf(base, -0.25, coil)
				want = func(j: int, f: float) -> Vector2: return Vector2(lerpf(0.0, -0.08 + f * 0.25, coil), sin(t * 8.0 - j) * 0.025 * coil)
				ks = minf(1.0, delta * 7.0)
			else:
				# Whipped down flat onto the ring, the tip curling over it.
				base = 1.5
				var reach := float(p["reach"]) / (SEGMENTS * SEGMENT * ARM_SCALE * BODY_SCALE)
				want = func(_j: int, f: float) -> Vector2: return Vector2(0.015 + (0.25 if f > minf(0.95, reach) else 0.0), 0.0)
				ks = minf(1.0, delta * 28.0)
		elif sweeping:
			var swing := clampf(act / 0.55, 0.0, 1.0)
			base = lerpf(0.9, 1.4, swing)
			turn = lerpf(-0.55, 0.55, swing) * (1.0 if i % 2 == 0 else -1.0)
			want = func(_j: int, f: float) -> Vector2: return Vector2(0.03 - f * 0.05, 0.08 * sin(f * PI) * (1.0 if i % 2 == 0 else -1.0))
			ks = minf(1.0, delta * 16.0)
		elif state in ["m_roar", "m_pull"]:
			base = -0.15 + sin(t * 3.0 + phase) * 0.15
			want = func(j: int, f: float) -> Vector2: return Vector2(sin(t * 4.0 - j * 0.5 + phase) * 0.08 + f * 0.1, sin(t * 3.0 - j) * 0.05)
			ks = minf(1.0, delta * 5.0)
		elif state == "m_rise":
			base = 0.3 + (1.0 - rise) * 0.4
			want = func(j: int, _f: float) -> Vector2: return Vector2(sin(t * 4.0 - j * 0.6 + phase) * 0.12, 0.0)
		limb.rotation.x = lerpf(limb.rotation.x, base, ks)
		limb.rotation.y = lerp_angle(limb.rotation.y, turn, ks)
		_bend(limb, want, ks)


## The Kraken dying: its arms go limp and slide off into the sea, its eyes dim, and the mantle sinks
## back under, the crown last.
static func fall_kraken(root: Node3D, k: float, _side: float) -> void:
	var body := root.get_node("Body") as Node3D
	var limp := smoothstep(0.1, 1.6, k)
	body.rotation.x = lerpf(0.0, 0.35, limp)
	body.position.y = -smoothstep(1.6, 4.6, k) * 9.0
	for i in ARMS:
		var limb := (body.get_node("Arm%d" % i) as Node3D).get_node("Arm") as Node3D
		limb.rotation.x = lerpf(limb.rotation.x, 1.55, limp * 0.2)
		_bend(limb, func(j: int, _f: float) -> Vector2: return Vector2(sin(k * 24.0 - j + i) * 0.06 * (1.0 - limp), 0.0), 0.2)
	(body.get_node("Eyes") as Node3D).scale = Vector3.ONE * maxf(0.05, 1.0 - limp * 0.6)
	var light := root.get_node("Glow") as OmniLight3D
	light.light_energy = 2.2 * (1.0 - limp)
	(root.get_node("Foam") as Node3D).scale = Vector3(3.4 + k * 1.2, 1.0, 3.4 + k * 1.2)
