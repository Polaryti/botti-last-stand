class_name HarvestModels
extends RefCounted
## A splitting pomegranate, a loaf carrying a kiln in its crust, and a flying chili pod.

const CREAM := Color("f7d883")
const CRUST := Color("ac582a")
const COAL := Color("392129")
const FIRE := Color("ff9230")
const PIP := Color("db3f64")
const RIND := Color("933843")
const LEAF := Color("6d963e")
const CHILI := Color("c72d38")
const DEATH_TIMES := {"pipburst": 2.15, "ovenback": 2.65, "pepperwing": 2.85}
const PIP_FRAGMENTS := 11


static func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	node.set_meta("rest", node.transform)
	parent.add_child(node)
	return node


static func _mesh(parent: Node3D, geometry: LowPoly, glowing := false) -> void:
	var node := MeshInstance3D.new()
	node.mesh = geometry.commit()
	if glowing:
		node.material_override = MesenllaModels.glow_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	var rig := _pivot(root, "Rig", Vector3.ZERO)
	match id:
		"pipburst": _pomegranate(rig)
		"ovenback": _oven(rig)
		"pepperwing": _moth(rig)
	return root


static func _legs(rig: Node3D, count: int, across: float, foot: float, col: Color) -> void:
	for i in count:
		var side := -1.0 if i % 2 else 1.0
		var depth := (floorf(i * 0.5) - (count / 4.0 - 0.5)) * foot * 1.4
		var leg := _pivot(rig, "Leg%d" % i, Vector3(across * side, foot * 0.83, depth))
		var l := LowPoly.new()
		var knee := Vector3(foot * 0.39 * side, -foot * 0.27, foot * 0.25)
		var tip := Vector3(foot * 0.55 * side, -foot * 0.80, foot * 0.64)
		l.prism(Vector3.ZERO, knee, foot * 0.23, foot * 0.17, 6, col)
		l.prism(knee, tip, foot * 0.19, foot * 0.15, 6, col.darkened(0.14))
		l.ovoid(tip + Vector3.BACK * foot * 0.08, Vector3(0.16, 0.10, 0.27) * foot, col, COAL, 3, 6)
		_mesh(leg, l)


static func _pomegranate(rig: Node3D) -> void:
	_legs(rig, 6, 0.38, 0.58, LEAF.darkened(0.22))
	var shell := _pivot(rig, "Fruit", Vector3(0, 0.86, 0))
	var l := LowPoly.new()
	l.ovoid(Vector3.ZERO, Vector3(0.77, 0.72, 0.73), RIND.lightened(0.18), RIND.darkened(0.35), 6, 12)
	for k in 5:
		var a := TAU * k / 5.0
		var out := Vector3(cos(a), 0, sin(a))
		l.prism(Vector3.UP * 0.65 + out * 0.1, Vector3.UP * 0.94 + out * 0.21, 0.083, 0.014, 5, RIND.darkened(0.33))
	l.ovoid(Vector3(0, 0.09, 0.61), Vector3(0.54, 0.44, 0.19), COAL, COAL.darkened(0.15), 4, 10)
	_mesh(shell, l)
	var core := _pivot(shell, "Pips", Vector3(0, 0.05, 0.78))
	l = LowPoly.new()
	for i in 13:
		var a := i * 2.398
		var dist := sqrt(float(i) / 13.0) * 0.43
		var seed := Vector3(cos(a) * dist, sin(a) * dist * 0.84, -dist * 0.19)
		l.ovoid(seed, Vector3(0.13, 0.119, 0.12), PIP.lightened(i % 4 * 0.11), RIND, 3, 7)
	_mesh(core, l, true)
	for side: float in [-1.0, 1.0]:
		var cheek := _pivot(shell, "HuskL" if side < 0.0 else "HuskR", Vector3(side * 0.52, 0.04, 0.44))
		l = LowPoly.new()
		l.ovoid(Vector3(-side * 0.09, 0.01, 0.12), Vector3(0.24, 0.48, 0.18), RIND, COAL, 4, 8)
		l.prism(Vector3(-side * 0.31, 0.24, 0.23), Vector3(-side * 0.075, 0.31, 0.25), 0.052, 0.07, 6, CREAM)
		_mesh(cheek, l)
	# Baked into every pooled rig. Kept small and hidden under the living fruit until the split.
	var spill := _pivot(rig, "Spill", Vector3.ZERO)
	spill.scale = Vector3.ONE * 0.001
	spill.set_meta("rest", spill.transform)
	for i in PIP_FRAGMENTS:
		var fragment := _pivot(spill, "Piece%d" % i, Vector3.ZERO)
		l = LowPoly.new()
		if i < 3:
			l.ovoid(Vector3.ZERO, Vector3(0.25, 0.13, 0.19), RIND, CREAM.darkened(0.35), 3, 7)
		else:
			l.ovoid(Vector3.ZERO, Vector3(0.09, 0.08, 0.12), PIP.lightened(0.1 * (i % 3)), RIND, 3, 6)
		_mesh(fragment, l)


static func _oven(rig: Node3D) -> void:
	_legs(rig, 4, 0.82, 0.83, CRUST.darkened(0.22))
	var loaf := _pivot(rig, "Loaf", Vector3(0, 1.26, 0))
	var l := LowPoly.new()
	l.ovoid(Vector3(0, 0.28, -0.17), Vector3(1.15, 0.95, 1.58), CRUST.lightened(0.13), COAL.lightened(0.09), 6, 12)
	for k in 4:
		var z := -1.25 + k * 0.69
		var top := 1.19 - 0.25 * absf(z + 0.3)
		l.prism(Vector3(-0.69, top - 0.11, z + 0.12), Vector3(0.61, top, z - 0.18), 0.10, 0.075, 5, CREAM)
		l.prism(Vector3(-0.79, top - 0.17, z + 0.13), Vector3(0.67, top - 0.03, z - 0.18), 0.038, 0.032, 5, CRUST.darkened(0.25))
	l.ovoid(Vector3(0, -0.04, 1.12), Vector3(0.81, 0.69, 0.36), COAL, COAL, 5, 10)
	for side: float in [-1.0, 1.0]:
		l.ovoid(Vector3(side * 0.67, 0.55, 1.01), Vector3(0.20, 0.13, 0.21), COAL, COAL, 3, 7)
		l.ovoid(Vector3(side * 0.65, 0.56, 1.17), Vector3(0.10, 0.07, 0.075), CREAM, FIRE, 3, 6)
	_mesh(loaf, l)
	var coals := _pivot(loaf, "Coals", Vector3(0, -0.12, 1.39))
	l = LowPoly.new()
	for k in 7:
		var a := k / 6.0 * PI
		l.ovoid(Vector3(cos(a) * 0.61, sin(a) * 0.34, 0), Vector3(0.13, 0.21, 0.07), FIRE, CRUST, 4, 6)
	_mesh(coals, l, true)
	var jaw := _pivot(loaf, "Jaw", Vector3(0, -0.43, 1.01))
	l = LowPoly.new()
	l.ovoid(Vector3(0, 0.0, 0.32), Vector3(0.81, 0.23, 0.53), CRUST, COAL, 4, 10)
	for k in 6:
		l.prism(Vector3(-0.52 + k * 0.22, 0.12, 0.65), Vector3(-0.52 + k * 0.22, 0.27, 0.61), 0.085, 0.027, 5, CREAM)
	_mesh(jaw, l)


static func _moth(rig: Node3D) -> void:
	var pod := _pivot(rig, "Pod", Vector3(0, 0.38, 0))
	var l := LowPoly.new()
	var last := Vector3(0, 0.08, 0.72)
	for i in 7:
		var t := i / 6.0
		var a := Vector3(-0.32 * t * t, 0.12 * sin(t * PI) - 0.18 * t, 0.46 - t * 1.8)
		l.prism(last, a, lerpf(0.45, 0.11, t), lerpf(0.46, 0.015, t), 9, CHILI.lightened(0.06 * (i % 3)))
		last = a
	l.ovoid(Vector3(0, 0.08, 0.63), Vector3(0.44, 0.36, 0.47), LEAF, COAL, 5, 9)
	for side: float in [-1.0, 1.0]:
		l.prism(Vector3(side * 0.16, 0.22, 0.87), Vector3(side * 0.45, 0.61, 1.13), 0.044, 0.019, 5, LEAF)
		l.ovoid(Vector3(side * 0.24, 0.14, 0.935), Vector3(0.14, 0.16, 0.12), CREAM, FIRE, 3, 7)
	_mesh(pod, l)
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(pod, "WingL" if side < 0.0 else "WingR", Vector3(side * 0.27, 0.23, 0.10))
		l = LowPoly.new()
		var veins := LowPoly.new()
		for patch in 2:
			var rear := float(patch) * 0.66
			var corners := [Vector3.ZERO, Vector3(side * 1.25, 0.10, 0.85 - rear), Vector3(side * (2.06 - patch * 0.31), 0.02, 0.27 - rear), Vector3(side * 1.28, -0.07, -0.76 - rear)]
			var hub := Vector3(side * 0.92, 0.11, -rear * 0.63)
			for i in corners.size():
				var start: Vector3 = corners[i]
				var next: Vector3 = corners[(i + 1) % corners.size()]
				var dye := Color("dd8e36").lerp(CHILI, (i + patch) * 0.18)
				l._tri(start, next, hub, hub + Vector3.DOWN, dye)
				l._tri(start, next, hub, hub + Vector3.UP, dye.darkened(0.23))
				veins.prism(Vector3.ZERO, start * 0.92 + Vector3.UP * 0.035, 0.035, 0.014, 4, CREAM)
		_mesh(wing, l)
		_mesh(wing, veins, true)
	var spark := _pivot(pod, "Spark", Vector3(0, -0.18, 0.86))
	l = LowPoly.new()
	l.ovoid(Vector3.ZERO, Vector3(0.19, 0.16, 0.16), FIRE, CHILI, 4, 8)
	_mesh(spark, l, true)


static func animate(z: Zombie, root: Node3D, delta: float, pace: float, clock: float, act: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var state := z._current_anim
	var warning := z.is_warning()
	var moving := clampf(pace / maxf(1.0, z._speed), 0.0, 1.0)
	var melee := sin(clampf(act / Zombie.ATTACK_TIME, 0.0, 1.0) * PI) if state == "m_swipe" else 0.0
	var stride := clock * 7.8
	match z.model_id:
		"pipburst":
			var fruit := rig.get_node("Fruit") as Node3D
			var open := smoothstep(0.0, HarvestMind.PIP_TELL, act) if warning else 0.0
			rig.position.y = absf(sin(stride)) * 0.23 * moving if not warning else 0.035 * sin(clock * 32.0)
			fruit.scale = Vector3.ONE * (1.0 + open * 0.27)
			fruit.rotation.x = -0.18 * moving + open * 0.2 + melee * 0.54
			for side: float in [-1.0, 1.0]:
				var shell := fruit.get_node("HuskL" if side < 0 else "HuskR") as Node3D
				shell.rotation.y = side * open * 1.35
		"ovenback":
			var loaf := rig.get_node("Loaf") as Node3D
			var jaw := loaf.get_node("Jaw") as Node3D
			var breath := state == "m_breath"
			var open := smoothstep(0.0, 0.86, act) if warning and breath else (1.0 - smoothstep(0.0, 0.55, act) if breath else melee)
			jaw.rotation.x = open * 0.55
			loaf.rotation.x = -open * 0.13 + melee * 0.33 + sin(stride) * moving * 0.09
			loaf.rotation.z = sin(stride * 0.5) * moving * 0.08
			(loaf.get_node("Coals") as Node3D).scale = Vector3.ONE * (0.74 + open * 0.37 + sin(clock * 15.0) * 0.08)
		"pepperwing":
			var pod := rig.get_node("Pod") as Node3D
			var wind := state == "m_cast" and warning
			var flutter := sin(clock * (32.0 if wind else 22.0))
			(pod.get_node("WingL") as Node3D).rotation.z = -flutter * (0.95 if wind else 0.72)
			(pod.get_node("WingR") as Node3D).rotation.z = flutter * (0.95 if wind else 0.72)
			pod.rotation.x = lerpf(pod.rotation.x, -0.42 if wind else (0.53 if state == "m_cast" else -0.08), minf(1.0, delta * 8.0))
			pod.rotation.z = sin(clock * 2.7) * 0.16
			(pod.get_node("Spark") as Node3D).scale = Vector3.ONE * (0.22 if not wind else 0.6 + act * 1.3)
			return
	for i in (6 if z.model_id == "pipburst" else 4):
		(rig.get_node("Leg%d" % i) as Node3D).rotation.x = sin(stride + i * PI * 0.71) * moving * 0.55 - melee * 0.19


static func begin_death(z: Zombie, root: Node3D) -> void:
	var rig := root.get_node("Rig") as Node3D
	var poses := {}
	for node: Node in rig.find_children("*", "Node3D", true, false):
		if node.has_meta("rest"):
			poses[node.name] = (node as Node3D).rotation
	root.set_meta("fall_pose", poses)
	if z.model_id != "pepperwing":
		return
	# Use the actual surface below the moth, including roofs and decks. The flight retains its
	# altitude long enough for its failing wingbeats to read before it falls.
	var from := z.position
	var floor_y := minf(from.y, z.world.floor_contact(from).y)
	root.set_meta("fall_origin", from)
	root.set_meta("fall_floor", floor_y)


static func fall(z: Zombie, root: Node3D, elapsed: float) -> void:
	var rig := root.get_node("Rig") as Node3D
	var side := float(root.get_meta("side", 1.0))
	var pose: Dictionary = root.get_meta("fall_pose", {})
	match z.model_id:
		"pipburst":
			_split(z, root, rig, elapsed, side, pose)
		"ovenback":
			_crumple(z, root, rig, elapsed, side, pose)
		"pepperwing":
			_crash(z, root, rig, elapsed, side, pose)


static func _split(z: Zombie, root: Node3D, rig: Node3D, t: float, side: float, pose: Dictionary) -> void:
	var fruit := rig.get_node("Fruit") as Node3D
	var husk := smoothstep(0.10, 0.36, t)
	var drop := smoothstep(0.29, 0.73, t)
	var settle := smoothstep(1.82, DEATH_TIMES["pipburst"], t)
	var twitch := sin(t * 41.0) * exp(-t * 8.0)
	fruit.rotation = (pose.get("Fruit", Vector3.ZERO) as Vector3).lerp(Vector3(0.27, 0, side * 0.63), drop)
	fruit.scale = Vector3(1.0 + twitch * 0.065 + husk * 0.07, 1.0 - drop * 0.33, 1.0 + husk * 0.12)
	fruit.position.y = 0.86 - drop * 0.51 - settle * 0.52
	for i in 6:
		var leg := rig.get_node("Leg%d" % i) as Node3D
		var curl := smoothstep(0.21 + 0.032 * i, 0.79, t)
		leg.rotation.x = lerpf((pose.get(leg.name, Vector3.ZERO) as Vector3).x, -1.0 + 0.16 * (i % 3), curl) + twitch * 0.16
		leg.rotation.z = (-1.0 if i % 2 == 0 else 1.0) * curl * 0.53
		leg.position.y = 0.48 - curl * 0.28 - settle * 0.30
	(fruit.get_node("HuskL") as Node3D).rotation.y = lerpf((pose.get("HuskL", Vector3.ZERO) as Vector3).y, -1.79, husk)
	(fruit.get_node("HuskR") as Node3D).rotation.y = lerpf((pose.get("HuskR", Vector3.ZERO) as Vector3).y, 1.83, husk)
	(fruit.get_node("Pips") as Node3D).scale = Vector3.ONE * maxf(0.001, 1.0 - husk)
	if t < 0.24:
		return
	var spill := rig.get_node("Spill") as Node3D
	spill.scale = Vector3.ONE
	var age := t - 0.24
	for i in PIP_FRAGMENTS:
		var fragment := spill.get_node("Piece%d" % i) as Node3D
		var a := i * 2.399 + side * 0.44
		var launch := Vector3(cos(a), 0, sin(a)) * (1.0 + 0.36 * (i % 5))
		var roll := minf(age, 0.66 + 0.03 * (i % 3))
		var y := maxf(0.072, 0.75 + (1.55 + 0.27 * (i % 4)) * roll - 5.3 * roll * roll)
		fragment.position = Vector3(0, y - settle * 0.17, 0.51) + launch * roll
		fragment.rotation = Vector3(roll * (5.0 + i), roll * 3.8 * side, roll * (5.9 - i))
	if not root.has_meta("did_split"):
		root.set_meta("did_split", true)
		z.world.fx_water(z.position + Vector3.BACK * 0.54, 0.68, PIP)


static func _crumple(z: Zombie, root: Node3D, rig: Node3D, t: float, side: float, pose: Dictionary) -> void:
	var loaf := rig.get_node("Loaf") as Node3D
	var buckle := smoothstep(0.07, 0.66, t)
	var slam := smoothstep(0.48, 0.98, t)
	var recoil := sin(maxf(0, t - 0.98) * 21.0) * exp(-maxf(0, t - 0.98) * 7.0) * 0.07
	var settle := smoothstep(2.12, DEATH_TIMES["ovenback"], t)
	loaf.rotation = (pose.get("Loaf", Vector3.ZERO) as Vector3).lerp(Vector3(0.21, side * 0.14, side * 1.05), slam) + Vector3(-0.19 * buckle * (1.0 - slam), 0, recoil)
	loaf.position.y = 1.26 - buckle * 0.38 + slam * 0.11 - settle * 1.74
	loaf.position.x = -side * 0.40 * slam
	var jaw := loaf.get_node("Jaw") as Node3D
	jaw.rotation.x = lerpf((pose.get("Jaw", Vector3.ZERO) as Vector3).x, 0.79, buckle) - 0.49 * slam + recoil
	var coals := loaf.get_node("Coals") as Node3D
	var out := smoothstep(0.83, 1.83, t)
	coals.scale = Vector3.ONE * maxf(0.001, (1.0 - out) * (0.86 + sin(t * 27.0) * 0.16))
	for i in 4:
		var leg := rig.get_node("Leg%d" % i) as Node3D
		var give := smoothstep(i * 0.095, 0.75 + i * 0.05, t)
		leg.rotation = (pose.get(leg.name, Vector3.ZERO) as Vector3).lerp(Vector3(-1.21 + 0.33 * i, 0, side * (0.48 + 0.17 * i)), give)
		leg.position.y = 0.69 - 0.48 * give - settle * 0.46
	if t >= 0.85 and not root.has_meta("did_oven_impact"):
		root.set_meta("did_oven_impact", true)
		z.world.fx_gore(z.position + Vector3(-side * 0.54, 0.18, 0.65), CRUST.lightened(0.29))
		z.world.fx_mist(z.position + Vector3(-side * 0.30, 0.58, 0.93), 0.64)


static func _crash(z: Zombie, root: Node3D, rig: Node3D, t: float, side: float, pose: Dictionary) -> void:
	var pod := rig.get_node("Pod") as Node3D
	var from: Vector3 = root.get_meta("fall_origin", z.position)
	var floor_y := float(root.get_meta("fall_floor", from.y))
	var air := minf(maxf(0.0, from.y - floor_y), 28.0)
	var flight := clampf(sqrt(air / 9.7), 0.21, 1.55)
	var plunge := clampf((t - 0.15) / flight, 0.0, 1.0)
	z.position.y = from.y - (from.y - floor_y) * plunge * plunge
	var land := smoothstep(0.77, 1.0, plunge)
	var stop := smoothstep(0.18, 0.95, plunge)
	var thrash := sin(28.0 * t - 5.4 * t * t)
	pod.rotation = (pose.get("Pod", Vector3.ZERO) as Vector3).lerp(Vector3(0.94 * (1.0 - land) + 0.18, side * 0.36 * plunge, -side * (0.92 + 0.48 * land)), smoothstep(0.0, 0.44, t))
	for flank: float in [-1.0, 1.0]:
		var label := "WingL" if flank < 0.0 else "WingR"
		var wing := pod.get_node(label) as Node3D
		var fold := 0.94 if flank == side else -0.13
		var flap := flank * thrash * (0.63 if flank == side else 0.30) * (1.0 - stop)
		wing.rotation.z = lerpf((pose.get(label, Vector3.ZERO) as Vector3).z, flap + flank * fold * stop, smoothstep(0.0, 0.22, t))
		wing.rotation.y = flank * stop * 0.54
	(pod.get_node("Spark") as Node3D).scale = Vector3.ONE * maxf(0.001, 1.0 - smoothstep(0.0, 0.28, t))
	var sink := smoothstep(2.25, DEATH_TIMES["pepperwing"], t)
	rig.position.y = -0.07 * land - 0.79 * sink
	if plunge >= 1.0 and not root.has_meta("did_pepper_impact"):
		root.set_meta("did_pepper_impact", true)
		z.world.fx_gore(z.position + Vector3.UP * 0.17, CHILI.lightened(0.22))
		z.world.fx_mist(z.position + Vector3.UP * 0.18, 0.48)
