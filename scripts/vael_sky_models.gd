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

static func animate(z: Zombie, root: Node3D, delta: float, moving: float) -> void:
	var state := z._current_anim
	if state != str(root.get_meta("act_state", "")):
		root.set_meta("act_state", state)
		root.set_meta("act_t", 0.0)
	var age := float(root.get_meta("act_t", 0.0)) + delta
	root.set_meta("act_t", age)
	var t := z.world.now + z.net_id * 0.41
	var tell := z.is_warning()
	var cast := state == "m_throw"
	var rig := root.get_node("Rig") as Node3D
	var pitch := -0.18 if tell else (0.3 * exp(-age * 4.0) if cast else sin(t * 2.0) * 0.04)
	rig.rotation.x = lerpf(rig.rotation.x, pitch, minf(1, delta * 9))
	rig.rotation.z = lerpf(rig.rotation.z, sin(t * 1.3) * minf(moving * 0.025, 0.14), minf(1, delta * 6))
	rig.position.y = 0.55 + sin(t * 2.2) * 0.07
	for side: float in [-1, 1]:
		var wing := rig.get_node("WingL" if side < 0 else "WingR") as Node3D
		var beat := sin(t * (5.5 if z.model_id == "wreck_gull" else 2.8))
		var fold := 0.6 if tell else (0.85 * exp(-age * 5) if cast else beat * 0.32)
		wing.rotation.z = lerpf(wing.rotation.z, side * fold, minf(1, delta * 10))
		var tip := wing.get_node_or_null("Tip") as Node3D
		if tip: tip.rotation.z = side * sin(t * 4 - 0.7) * (0.12 if tell else 0.3)
	match z.model_id:
		"wreck_gull":
			(rig.get_node("Head") as Node3D).rotation.x = -0.5 if tell else (0.7 * exp(-age * 6) if cast else sin(t * 2) * 0.05)
			(rig.get_node("Head/Throat") as Node3D).scale = Vector3.ONE * (1.0 + (0.6 + sin(t * 16) * 0.1 if tell else 0.0))
			(rig.get_node("Tail") as Node3D).rotation.y = sin(t * 2.3) * 0.2
		"storm_ray":
			(rig.get_node("Tail") as Node3D).rotation.y = sin(t * 3.1) * 0.28
			(rig.get_node("Tail/Tip") as Node3D).rotation.y = sin(t * 3.1 - 0.8) * 0.4
			var charge := rig.get_node("Charge") as Node3D
			charge.visible = tell or (cast and age < 0.3)
			charge.rotation.y = t * 5
		"bell_wraith":
			var bell := rig.get_node("Bell") as Node3D
			bell.rotation.x = sin(t * (12 if tell else 2)) * (0.32 if tell else 0.07)
			(bell.get_node("Clapper") as Node3D).rotation.x = sin(t * (12 if tell else 2) - 0.9) * (0.65 if tell else 0.16)
			for i in 6:
				(rig.get_node("Strip%d" % i) as Node3D).rotation.x = sin(t * 2.5 - i * 0.7) * 0.18

static func fall(root: Node3D, age: float, delta: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	rig.rotation.z = lerpf(rig.rotation.z, 1.4, minf(1, delta * 5))
	rig.rotation.x += delta * 1.2
	for label: String in ["WingL", "WingR"]:
		var wing := rig.get_node(label) as Node3D
		wing.rotation.z = lerpf(wing.rotation.z, -1.2 if label == "WingL" else 1.2, minf(1, delta * 6))
	var charge := rig.get_node_or_null("Charge") as Node3D
	if charge: charge.visible = false
	root.scale *= maxf(0.01, 1.0 - delta * 4) if age > 1.8 else 1.0
