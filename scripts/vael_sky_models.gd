class_name VaelSkyModels
extends RefCounted
## Three silhouettes from the drowned harbour. Shared cached meshes, articulated pivots,
## no per-creature lights or particles. +Z is forward; animation also runs on joined phones.
const KINDS := ["wreck_gull", "storm_ray", "bell_wraith"]
const BONE := Color(0.88, 0.86, 0.72)
const TAR := Color(0.09, 0.14, 0.18)
const SALT := Color(0.63, 0.9, 0.86)
const BRASS := Color(0.54, 0.4, 0.18)
const GLOW := Color(0.4, 1.0, 0.83)

static func _pivot(parent: Node3D, at: Vector3, label: String) -> Node3D:
	return MesenllaModels._pivot(parent, at, label)

static func _part(parent: Node3D, key: String, draw: Callable, lit := false) -> MeshInstance3D:
	var mi := MesenllaModels._part(parent, MesenllaModels._mesh("vael_sky_" + key, draw))
	if lit: mi.material_override = MesenllaModels.glow_material()
	return mi

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	var rig := _pivot(root, Vector3(0, 0.55, 0), "Rig")
	match id:
		"wreck_gull": _gull(rig)
		"storm_ray": _ray(rig)
		"bell_wraith": _wraith(rig)
	return root

static func _gull(rig: Node3D) -> void:
	_part(rig, "gull_body", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.5), Vector3(0, 0.1, 0.35), 0.13, 0.27, 8, TAR)
		l.prism(Vector3(0, 0.05, 0.18), Vector3(0, 0.22, 0.48), 0.22, 0.12, 7, BONE)
		# Salt crystals grow through its wet plumage.
		for i in 5:
			var z := -0.4 + i * 0.14
			l.prism(Vector3(0, 0.17, z), Vector3(0.04, 0.4 + sin(i) * 0.07, z - 0.05), 0.06, 0.0, 4, SALT)
		for side: float in [-1, 1]:
			l.prism(Vector3(side * 0.08, -0.1, -0.15), Vector3(side * 0.12, -0.27, -0.26), 0.028, 0.02, 5, BRASS)
			l.leaf(Vector3(side * 0.12, -0.27, -0.26), Vector3(side * 0.24, -0.27, -0.1), Vector3(side * 0.02, -0.27, -0.07), BRASS))
	var head := _pivot(rig, Vector3(0, 0.23, 0.38), "Head")
	_part(head, "gull_head", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, 0), Vector3(0, 0.11, 0.2), 0.13, 0.12, 7, BONE)
		l.prism(Vector3(0, 0.04, 0.15), Vector3(0, 0.0, 0.5), 0.09, 0.0, 5, BRASS))
	_part(head, "gull_eyes", func(l: LowPoly) -> void:
		for side: float in [-1, 1]: l.box(Vector3(side * 0.115, 0.08, 0.14), Vector3(0.035, 0.055, 0.07), GLOW), true)
	var throat := _pivot(head, Vector3(0, -0.07, 0.12), "Throat")
	_part(throat, "gull_throat", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, -0.14, 0.14), 0.08, 0.1, 6, SALT), true)
	for side: float in [-1, 1]:
		var wing := _pivot(rig, Vector3(side * 0.18, 0.1, 0), "WingL" if side < 0 else "WingR")
		_part(wing, "gull_wing_%s" % side, func(l: LowPoly) -> void:
			l.leaf(Vector3.ZERO, Vector3(side * 0.78, 0, 0.14), Vector3(side * 0.68, -0.02, -0.4), BONE)
			l.prism(Vector3.ZERO, Vector3(side * 0.76, 0, 0.07), 0.05, 0.035, 5, TAR))
		var tip := _pivot(wing, Vector3(side * 0.7, 0, 0.03), "Tip")
		_part(tip, "gull_tip_%s" % side, func(l: LowPoly) -> void:
			for f in 5:
				var at := Vector3(side * f * 0.045, 0, -f * 0.075)
				l.leaf(at, at + Vector3(side * (0.67 - f * 0.06), -0.02, -0.08), at + Vector3(0, 0, -0.14), TAR if f < 3 else SALT))
	var tail := _pivot(rig, Vector3(0, 0, -0.43), "Tail")
	_part(tail, "gull_tail", func(l: LowPoly) -> void:
		l.leaf(Vector3.ZERO, Vector3(-0.28, 0.04, -0.42), Vector3(0.28, 0.04, -0.42), BONE))

static func _ray(rig: Node3D) -> void:
	_part(rig, "ray_body", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.7), Vector3(0, 0, 0.65), 0.15, 0.32, 8, Color(0.18, 0.31, 0.38))
		l.prism(Vector3(0, -0.12, -0.3), Vector3(0, -0.12, 0.7), 0.12, 0.22, 7, SALT)
		for side: float in [-1, 1]:
			for g in 4:
				l.box(Vector3(side * 0.17, -0.21, 0.1 + g * 0.11), Vector3(0.14, 0.025, 0.035), TAR)
			l.prism(Vector3(side * 0.2, 0, 0.48), Vector3(side * 0.29, 0.04, 0.95), 0.1, 0.02, 6, TAR))
	_part(rig, "ray_lights", func(l: LowPoly) -> void:
		for side: float in [-1, 1]:
			l.box(Vector3(side * 0.22, 0.16, 0.47), Vector3(0.09, 0.05, 0.12), GLOW)
		for i in 6:
			l.box(Vector3(0, 0.17, -0.5 + i * 0.18), Vector3(0.1, 0.04, 0.08), SALT), true)
	for side: float in [-1, 1]:
		var fin := _pivot(rig, Vector3(side * 0.2, 0, 0), "WingL" if side < 0 else "WingR")
		_part(fin, "ray_fin_%s" % side, func(l: LowPoly) -> void:
			l.leaf(Vector3(0, 0, 0.6), Vector3(side * 0.95, 0.05, 0.15), Vector3(0, 0, -0.65), Color(0.21, 0.4, 0.45))
			for i in 5:
				l.prism(Vector3(0, 0.02, 0.5 - i * 0.25), Vector3(side * 0.94, 0.06, 0.13 - i * 0.065), 0.018, 0.008, 4, SALT))
		var tip := _pivot(fin, Vector3(side * 0.9, 0.04, 0.02), "Tip")
		_part(tip, "ray_tip_%s" % side, func(l: LowPoly) -> void:
			l.leaf(Vector3(0, 0, 0.2), Vector3(side * 0.86, 0.08, -0.23), Vector3(0, 0, -0.52), Color(0.12, 0.25, 0.32))
			l.prism(Vector3(0, 0.02, 0.2), Vector3(side * 0.83, 0.1, -0.23), 0.027, 0.008, 4, GLOW))
	var tail := _pivot(rig, Vector3(0, 0, -0.6), "Tail")
	_part(tail, "ray_tail", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, 0.05, -0.8), 0.1, 0.03, 6, TAR))
	var tip := _pivot(tail, Vector3(0, 0.05, -0.78), "Tip")
	_part(tip, "ray_barb", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, 0.06, -0.8), 0.03, 0.0, 5, SALT))
	var charge := _pivot(rig, Vector3.ZERO, "Charge")
	_part(charge, "ray_charge", func(l: LowPoly) -> void:
		for i in 6:
			var a := TAU * i / 6.0
			l.prism(Vector3(cos(a) * 0.45, 0.1, sin(a) * 0.6), Vector3(cos(a + 0.6) * 0.65, 0.25, sin(a + 0.6) * 0.8), 0.026, 0.008, 4, Color(0.8, 0.92, 1)), true)

static func _wraith(rig: Node3D) -> void:
	# A cracked ship's bell suspended in the clothes and rigging of its dead bell-ringer.
	var bell := _pivot(rig, Vector3(0, 0.4, 0), "Bell")
	_part(bell, "wraith_bell", func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.25, 0), Vector3(0, 0.3, 0), 0.42, 0.19, 10, BRASS)
		l.prism(Vector3(0, -0.32, 0), Vector3(0, -0.23, 0), 0.48, 0.42, 10, BRASS.lightened(0.15))
		l.prism(Vector3(0, 0.3, 0), Vector3(0, 0.47, 0), 0.12, 0.08, 8, TAR)
		for i in 8:
			var a := TAU * i / 8.0
			l.box(Vector3(cos(a) * 0.35, -0.05, sin(a) * 0.35), Vector3(0.055, 0.05, 0.055), BONE))
	_part(bell, "wraith_cracks", func(l: LowPoly) -> void:
		l.prism(Vector3(-0.02, 0.2, 0.25), Vector3(0.07, 0, 0.34), 0.018, 0.025, 4, GLOW)
		l.prism(Vector3(0.07, 0, 0.34), Vector3(0.02, -0.25, 0.43), 0.025, 0.012, 4, GLOW), true)
	var clapper := _pivot(bell, Vector3(0, 0.1, 0), "Clapper")
	_part(clapper, "wraith_clapper", func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, -0.65, 0), 0.025, 0.025, 5, TAR)
		l.prism(Vector3(0, -0.65, 0), Vector3(0, -0.48, 0), 0.12, 0.09, 7, GLOW), true)
	for i in 6:
		var a := TAU * i / 6.0
		var strip := _pivot(rig, Vector3(cos(a) * 0.35, 0.2, sin(a) * 0.35), "Strip%d" % i)
		_part(strip, "wraith_strip_%d" % i, func(l: LowPoly) -> void:
			var end := Vector3(cos(a) * 0.25, -0.8 - (i % 2) * 0.25, sin(a) * 0.25)
			l.leaf(Vector3.ZERO, Vector3(-sin(a) * 0.17, -0.4, cos(a) * 0.17), end, Color(0.2, 0.38, 0.34))
			l.prism(Vector3.ZERO, end, 0.018, 0.005, 4, SALT))
	for side: float in [-1, 1]:
		var sail := _pivot(rig, Vector3(side * 0.3, 0.5, 0), "WingL" if side < 0 else "WingR")
		_part(sail, "wraith_sail_%s" % side, func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(side * 0.85, 0.45, -0.1), 0.03, 0.01, 5, BRASS)
			for f in 4:
				var at := Vector3(side * f * 0.2, f * 0.1, -0.05)
				l.leaf(at, at + Vector3(side * 0.21, 0.12, 0), at + Vector3(side * 0.18, -0.48 + f * 0.05, -0.2), Color(0.35, 0.49, 0.43)))

## Each frame, on every phone. Flight is read from how the body really moves (its turning, climbing and
## speed, kept between frames in the root's meta), so it banks into turns, noses up as it climbs and
## flaps harder when it works; the state (m_cast with its warning, then m_throw) gives the tell and the
## release.
##   Wreck Gull: bursts of strong flapping, the hand of the wing folding in on the upstroke and opening
##     on the downstroke, then a glide on raised wings; the head holds level while the body bobs; the
##     tail fans and twists in turns. Tell: it hangs in the air beating fast, head drawn back, throat
##     swelling. Release: the head snaps forward and one hard downstroke throws it back.
##   Storm Ray: it rows through the air like a ray through water, a wave running out along each fin,
##     the body rocking with it, the tail whipping after. Tell: both fins curl up into a cup, crackling,
##     the body trembling. Release: the fins slam down and the tail lashes.
##   Bell Wraith: the cracked bell hangs from it like a pendulum, swinging with every change of pace;
##     the strips of the dead ringer's clothes trail and ripple behind; the torn sails beat slowly.
##     Tell: the bell swings harder and harder, the clapper striking. Release: it tolls: the bell
##     jumps and rings, the whole body jolting up.
static func animate(z: Zombie, root: Node3D, delta: float, moving: float) -> void:
	var state := z._current_anim
	var tell := z.is_warning()
	if state != str(root.get_meta("act_state", "")) or tell != bool(root.get_meta("act_warning", false)):
		root.set_meta("act_state", state)
		root.set_meta("act_warning", tell)
		root.set_meta("act_t", 0.0)
	var age := float(root.get_meta("act_t", 0.0)) + delta
	root.set_meta("act_t", age)
	var cast := state == "m_throw"
	var rig := root.get_node("Rig") as Node3D
	var t := z.world.now + z.net_id * 0.41
	# How it is really moving.
	var yaw := z.rotation.y
	var last_yaw := float(root.get_meta("yaw", yaw))
	var turn := wrapf(yaw - last_yaw, -PI, PI) / maxf(delta, 0.001)
	root.set_meta("yaw", yaw)
	var last_y := float(root.get_meta("high", z.position.y))
	var climb := (z.position.y - last_y) / maxf(delta, 0.001)
	root.set_meta("high", z.position.y)
	var speed := Vector2(z.velocity.x, z.velocity.z).length()
	if speed < 0.01:
		speed = moving
	var k := minf(1.0, delta * 6.0)
	var bank := clampf(-turn * 0.28, -0.6, 0.6)
	var pitch := clampf(-climb * 0.12, -0.35, 0.35)
	# The beat: its phase moves at its own pace, faster when it works.
	var pace := 0.0
	match z.model_id:
		"wreck_gull": pace = 3.4 if tell else 2.2 + minf(speed, 6.0) * 0.12
		"storm_ray": pace = 0.9 if tell else 0.75 + minf(speed, 6.0) * 0.06
		"bell_wraith": pace = 0.6
	var beat := float(root.get_meta("beat", randf() * TAU)) + delta * pace * TAU
	root.set_meta("beat", beat)
	match z.model_id:
		"wreck_gull": _fly_gull(z, root, rig, delta, k, beat, bank, pitch, speed, tell, cast, age, t)
		"storm_ray": _fly_ray(z, rig, delta, k, beat, bank, pitch, tell, cast, age, t)
		"bell_wraith": _fly_wraith(z, root, rig, delta, k, beat, bank, speed, tell, cast, age, t)


## One wingbeat of a gull, 0..TAU: a quick, strong downstroke (40% of it) and a slower upstroke.
static func _stroke(beat: float) -> float:
	var f := fposmod(beat, TAU) / TAU
	return lerpf(1.0, -1.0, smoothstep(0.0, 0.4, f)) if f < 0.4 else lerpf(-1.0, 1.0, smoothstep(0.4, 1.0, f))


static func _fly_gull(z: Zombie, root: Node3D, rig: Node3D, delta: float, k: float, beat: float, bank: float, pitch: float, speed: float, tell: bool, cast: bool, age: float, t: float) -> void:
	# Bursts of flapping and glides between: a slow swell decides which, flapping always when it works.
	var flapping := 1.0 if tell or cast or speed > 4.5 or absf(bank) > 0.25 else smoothstep(-0.2, 0.3, sin(t * 0.9 + z.net_id))
	var glide_mix := float(root.get_meta("flap", 1.0))
	glide_mix = move_toward(glide_mix, flapping, delta * 2.0)
	root.set_meta("flap", glide_mix)
	var s := _stroke(beat)
	var down := 1.0 - smoothstep(-1.0, 1.0, s) # 1 at the bottom of the stroke
	var want_pitch := pitch + sin(t * 1.7) * 0.03
	if tell:
		want_pitch = -0.55 * smoothstep(0.0, 0.4, age) # hanging nose-up, beating to hold its place
	elif cast:
		want_pitch = 0.4 * exp(-age * 5.0) # thrown forward by the spit
	rig.rotation.x = lerpf(rig.rotation.x, want_pitch, k)
	rig.rotation.z = lerpf(rig.rotation.z, bank, k)
	# The body rises a little on each downstroke.
	rig.position.y = 0.55 + sin(t * 1.3) * 0.08 + (down - 0.5) * 0.07 * glide_mix
	for side: float in [-1.0, 1.0]:
		var wing := rig.get_node("WingL" if side < 0 else "WingR") as Node3D
		var tip := wing.get_node("Tip") as Node3D
		# Flapping: from high (+0.8) to low (-0.6); the hand folds in on the way up, opens on the way down.
		var shoulder := lerpf(0.8, -0.6, down)
		var hand := lerpf(-0.5, 0.05, down) if s > -0.9 else 0.05
		var sweep := lerpf(0.35, -0.05, down) # swept back as it comes up
		# Gliding: wings held a little raised, the hands set, a little sway in the air.
		var g_shoulder := 0.16 + sin(t * 2.1 + side) * 0.03
		shoulder = lerpf(g_shoulder, shoulder, glide_mix)
		hand = lerpf(0.04, hand, glide_mix)
		sweep = lerpf(0.05, sweep, glide_mix)
		if tell:
			shoulder *= 1.2
		elif cast and age < 0.25:
			shoulder = lerpf(0.9, -0.8, age / 0.25) # one hard stroke to throw itself back
			hand = 0.1
			sweep = -0.2
		var kw := minf(1.0, delta * 18.0)
		wing.rotation.z = lerpf(wing.rotation.z, side * shoulder, kw)
		wing.rotation.y = lerpf(wing.rotation.y, side * -sweep, kw)
		tip.rotation.z = lerpf(tip.rotation.z, side * hand, kw)
	# The head holds level as the body bobs and pitches; drawn back for the tell, snapping forward to spit.
	var head := rig.get_node("Head") as Node3D
	var head_want := -rig.rotation.x * 0.8 + sin(t * 2.6) * 0.04
	if tell:
		head_want = -0.55 - rig.rotation.x * 0.5
	elif cast:
		head_want = 0.75 * exp(-age * 6.0)
	head.rotation.x = lerpf(head.rotation.x, head_want, minf(1.0, delta * 12.0))
	head.rotation.z = lerpf(head.rotation.z, -rig.rotation.z * 0.7, k)
	(head.get_node("Throat") as Node3D).scale = Vector3.ONE * (1.0 + (0.55 + sin(t * 16.0) * 0.12) * smoothstep(0.0, 0.5, age) if tell else 1.0)
	# The tail fans out to brake and twists in turns.
	var tail := rig.get_node("Tail") as Node3D
	var fan := 1.35 if tell or absf(bank) > 0.25 else 1.0
	tail.scale.x = lerpf(tail.scale.x, fan, k)
	tail.rotation.z = lerpf(tail.rotation.z, bank * 0.8, k)
	tail.rotation.x = lerpf(tail.rotation.x, -rig.rotation.x * 0.5 + (0.2 if tell else 0.0), k)


static func _fly_ray(z: Zombie, rig: Node3D, delta: float, k: float, beat: float, bank: float, pitch: float, tell: bool, cast: bool, age: float, t: float) -> void:
	var want_pitch := pitch + sin(beat + PI * 0.5) * 0.07 # it rocks nose up and down with each stroke
	if cast:
		want_pitch = -0.25 * exp(-age * 4.0)
	rig.rotation.x = lerpf(rig.rotation.x, want_pitch, k)
	rig.rotation.z = lerpf(rig.rotation.z, bank * 0.8, k)
	var tremble := sin(t * 47.0) * 0.012 * smoothstep(0.0, 0.6, age) if tell else 0.0
	rig.position.y = 0.55 + sin(beat - 0.6) * 0.09 + tremble
	var curl := smoothstep(0.0, float(VaelSkyMind.TELLS["storm_ray"]) * 0.7, age) if tell else 0.0
	var slam := exp(-age * 4.5) if cast else 0.0
	for side: float in [-1.0, 1.0]:
		var fin := rig.get_node("WingL" if side < 0 else "WingR") as Node3D
		var tip := fin.get_node("Tip") as Node3D
		# A wave running out along the fin: the outer part a little after the inner.
		var inner := sin(beat) * 0.24 + bank * side * 0.1
		var outer := sin(beat - 1.1) * 0.36
		inner = lerpf(inner, 0.85, curl) - 0.7 * slam
		outer = lerpf(outer, 0.7, curl) - 0.5 * slam
		var kf := minf(1.0, delta * (20.0 if cast else 10.0))
		fin.rotation.z = lerpf(fin.rotation.z, side * inner, kf)
		tip.rotation.z = lerpf(tip.rotation.z, side * outer, kf)
		# The front edge leads the stroke.
		fin.rotation.x = lerpf(fin.rotation.x, cos(beat) * 0.08, kf)
	var tail := rig.get_node("Tail") as Node3D
	var tail_tip := tail.get_node("Tip") as Node3D
	var lash := sin(age * 14.0) * exp(-age * 3.0) * 0.8 if cast else 0.0
	tail.rotation.y = lerpf(tail.rotation.y, sin(beat - 1.6) * 0.22 - bank * 0.4 + lash, k)
	tail.rotation.x = lerpf(tail.rotation.x, sin(beat - 1.2) * 0.12 + (0.35 * curl), k)
	tail_tip.rotation.y = lerpf(tail_tip.rotation.y, sin(beat - 2.4) * 0.4 + lash * 0.6, minf(1.0, delta * 9.0))
	var charge := rig.get_node("Charge") as Node3D
	charge.visible = tell or (cast and age < 0.3)
	charge.rotation.y = t * 5.0
	charge.scale = Vector3.ONE * (0.7 + 0.5 * curl + 0.06 * sin(t * 31.0))


static func _fly_wraith(z: Zombie, root: Node3D, rig: Node3D, delta: float, k: float, beat: float, bank: float, speed: float, tell: bool, cast: bool, age: float, t: float) -> void:
	# The bell, a pendulum: pushed by every change in how fast the wraith moves, pulled back to hang.
	var bell := rig.get_node("Bell") as Node3D
	var last_speed := float(root.get_meta("speed", speed))
	var push := (speed - last_speed) / maxf(delta, 0.001)
	root.set_meta("speed", speed)
	var swing := float(root.get_meta("swing", 0.0))
	var spin := float(root.get_meta("swing_v", 0.0))
	var drive := 0.0
	if tell:
		# Rung harder and harder as the tell goes on.
		drive = sin(t * 7.5) * lerpf(6.0, 26.0, smoothstep(0.0, float(VaelSkyMind.TELLS["bell_wraith"]), age))
	elif cast and age < 0.12:
		spin += 9.0 # it tolls
	spin += (-swing * 30.0 - spin * 2.2 - push * 0.35 + drive) * delta
	swing = clampf(swing + spin * delta, -1.1, 1.1)
	root.set_meta("swing", swing)
	root.set_meta("swing_v", spin)
	bell.rotation.x = swing
	bell.rotation.z = lerpf(bell.rotation.z, bank * 0.5, k)
	(bell.get_node("Clapper") as Node3D).rotation.x = -swing * 1.6 + sin(t * 3.0) * 0.05
	var ring := exp(-age * 5.0) if cast else 0.0
	bell.scale = Vector3.ONE * (1.0 + ring * 0.12 * absf(sin(age * 40.0)))
	rig.position.y = 0.55 + sin(t * 1.1) * 0.14 + ring * 0.35
	rig.rotation.x = lerpf(rig.rotation.x, -clampf(speed * 0.04, 0.0, 0.25), k) # it leans into its drift
	rig.rotation.z = lerpf(rig.rotation.z, bank * 0.6, k)
	# The strips of cloth trail behind as it drifts, a ripple running down each.
	for i in 6:
		var strip := rig.get_node("Strip%d" % i) as Node3D
		var trail := -clampf(speed * 0.09, 0.0, 0.6)
		var flutter := sin(t * 2.6 - i * 0.9) * (0.16 + clampf(speed * 0.03, 0.0, 0.2))
		strip.rotation.x = lerpf(strip.rotation.x, trail + flutter - swing * 0.2 - ring * 0.5, minf(1.0, delta * 5.0))
		strip.rotation.z = lerpf(strip.rotation.z, sin(t * 1.7 - i) * 0.12, minf(1.0, delta * 5.0))
	# The torn sails beat slowly, and spread wide as it rings.
	for side: float in [-1.0, 1.0]:
		var sail := rig.get_node("WingL" if side < 0 else "WingR") as Node3D
		var beat_s := sin(beat + side * 0.25) * 0.38
		if tell:
			beat_s = lerpf(beat_s, 0.6, smoothstep(0.0, 0.8, age))
		beat_s += ring * 0.7
		sail.rotation.z = lerpf(sail.rotation.z, side * beat_s, minf(1.0, delta * 6.0))
		sail.rotation.y = lerpf(sail.rotation.y, side * sin(beat - 0.8) * 0.15, minf(1.0, delta * 6.0))


## Falling out of the sky: a gull tumbles over and over, wings flung up; a ray flutters down rocking
## like a leaf; the wraith's sails fold, its strips stream up and its bell drops, swinging wildly.
static func fall(root: Node3D, age: float, delta: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var k := minf(1.0, delta * 6.0)
	if rig.has_node("Bell"):
		var bell := rig.get_node("Bell") as Node3D
		bell.rotation.x = sin(age * 9.0) * 0.9 * exp(-age * 0.8)
		for i in 6:
			(rig.get_node("Strip%d" % i) as Node3D).rotation.x = lerpf((rig.get_node("Strip%d" % i) as Node3D).rotation.x, -1.4, k)
		for label: String in ["WingL", "WingR"]:
			(rig.get_node(label) as Node3D).rotation.z = lerpf((rig.get_node(label) as Node3D).rotation.z, 1.1 if label == "WingL" else -1.1, k)
		rig.rotation.z = lerpf(rig.rotation.z, 0.5, minf(1.0, delta * 2.0))
	elif rig.has_node("Charge"):
		(rig.get_node("Charge") as Node3D).visible = false
		rig.rotation.z = sin(age * 5.5) * 0.7 * exp(-age * 0.6)
		rig.rotation.x = lerpf(rig.rotation.x, 0.3, k)
		for label: String in ["WingL", "WingR"]:
			var side := -1.0 if label == "WingL" else 1.0
			(rig.get_node(label) as Node3D).rotation.z = lerpf((rig.get_node(label) as Node3D).rotation.z, side * 0.5 * sin(age * 5.5), k)
	else:
		rig.rotation.z += delta * 7.0 * exp(-age * 0.7)
		rig.rotation.x = lerpf(rig.rotation.x, 0.9, k)
		for label: String in ["WingL", "WingR"]:
			var side := -1.0 if label == "WingL" else 1.0
			(rig.get_node(label) as Node3D).rotation.z = lerpf((rig.get_node(label) as Node3D).rotation.z, side * 1.2, k)
			((rig.get_node(label) as Node3D).get_node("Tip") as Node3D).rotation.z = lerpf(((rig.get_node(label) as Node3D).get_node("Tip") as Node3D).rotation.z, side * 0.6, k)
	if age > 1.8:
		root.scale *= maxf(0.01, 1.0 - delta * 4.0)
