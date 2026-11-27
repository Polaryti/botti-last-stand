class_name FeastModels
extends RefCounted
## Pelagros is a living feast oven in a bronze mask, with a split waist of draped cloth,
## a sacrificial ladle and a turning wheel of harvest emblems.

const BRONZE := Color("bd693c")
const DARK := Color("39212d")
const GOLD := Color("efb752")
const IVORY := Color("f6dc9b")
const TURQUOISE := Color("318d84")
const WINE := Color("85314d")
const FIRE := Color("ff9c45")
const ORBIT := "SolarWheel"


static func _part(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = at
	pivot.set_meta("rest", pivot.transform)
	parent.add_child(pivot)
	return pivot


static func _mesh(parent: Node3D, l: LowPoly, luminous := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	if luminous:
		mi.material_override = MesenllaModels.glow_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func build() -> Node3D:
	var root := Node3D.new()
	var body := _part(root, "Body", Vector3.ZERO)
	var l := LowPoly.new()
	l.prism(Vector3(0, 0.72, 0), Vector3(0, 3.8, 0), 2.3, 1.08, 12, WINE)
	l.prism(Vector3(0, 3.43, 0), Vector3(0, 5.35, 0), 1.04, 2.05, 10, TURQUOISE)
	l.ovoid(Vector3(0, 5.42, 0), Vector3(2.16, 1.35, 1.08), BRONZE, DARK, 6, 12)
	for i in 10:
		var a := i * TAU / 10.0
		var r := Vector3(cos(a), 0, sin(a))
		var collar := r * 2.02 + Vector3.UP * 5.52
		l.prism(collar, r * 1.24 + Vector3.UP * 6.22, 0.12, 0.09, 6, GOLD)
	l.prism(Vector3(0, 3.68, 0), Vector3(0, 3.93, 0), 1.24, 1.24, 12, GOLD)
	l.ovoid(Vector3(0, 5.09, 0.87), Vector3(0.94, 1.03, 0.29), DARK, DARK.darkened(0.3), 5, 12)
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * 0.95, 5.04 + sin(a) * 0.94, 1.13)
		var q := Vector3(cos(a + TAU / 8.0) * 0.95, 5.04 + sin(a + TAU / 8.0) * 0.94, 1.13)
		l.prism(p, q, 0.11, 0.11, 5, GOLD)
	for y in [4.67, 4.91, 5.15, 5.39]:
		l.prism(Vector3(-0.74, y, 1.17), Vector3(0.74, y, 1.17), 0.055, 0.055, 5, BRONZE.darkened(0.3))
	_mesh(body, l)
	var embers := _part(body, "Embers", Vector3(0, 5.05, 1.0))
	var coals := LowPoly.new()
	for i in 11:
		var x := sin(i * 6.13) * 0.57
		var y := (i % 5 - 2) * 0.26
		coals.ovoid(Vector3(x, y, 0.14 - absf(y) * 0.08), Vector3(0.12, 0.18, 0.04), FIRE.lightened(i % 3 * 0.13), BRONZE, 3, 7)
	_mesh(embers, coals, true)
	var mask := _part(body, "Mask", Vector3(0, 6.15, 0))
	l = LowPoly.new()
	l.prism(Vector3(0, 0, 0.14), Vector3(0, 0.44, 0.12), 0.46, 0.78, 8, GOLD)
	l.ovoid(Vector3(0, 0.83, 0.02), Vector3(0.88, 0.92, 0.64), IVORY, BRONZE, 5, 10)
	l.prism(Vector3(0, 0.59, 0.62), Vector3(0, 0.99, 0.60), 0.14, 0.19, 5, GOLD)
	l.prism(Vector3(-0.33, 0.41, 0.54), Vector3(0.32, 0.41, 0.54), 0.063, 0.063, 5, DARK)
	for side in [-1.0, 1.0]:
		var inner := Vector3(side * 0.15, 0.99, 0.56)
		var outer := Vector3(side * 0.67, 1.1, 0.47)
		l.prism(inner, outer, 0.11, 0.12, 5, DARK)
		l.prism(Vector3(side * 0.54, 1.37, 0), Vector3(side * 0.86, 2.06, -0.02), 0.24, 0.11, 6, BRONZE)
		l.prism(Vector3(side * 0.86, 2.06, -0.02), Vector3(side * 0.69, 2.34, 0.16), 0.12, 0.02, 6, GOLD)
		for i in 4:
			var at := Vector3(side * (0.32 + i * 0.12), 1.26 + i * 0.13, 0.53 - i * 0.13)
			l.ovoid(at, Vector3(0.13, 0.28, 0.07), GOLD, BRONZE, 3, 6, Basis(Vector3.BACK, -side * 0.67))
	_mesh(mask, l)
	var eyes := LowPoly.new()
	for side in [-1.0, 1.0]:
		eyes.prism(Vector3(side * 0.21, 1.00, 0.65), Vector3(side * 0.57, 1.07, 0.57), 0.041, 0.068, 5, FIRE.lightened(0.22))
	_mesh(mask, eyes, true)
	for side in [-1.0, 1.0]:
		var arm := _part(body, "LadleArm" if side > 0 else "ServingArm", Vector3(side * 1.77, 5.67, 0))
		l = LowPoly.new()
		l.ovoid(Vector3(side * 0.16, -0.06, 0), Vector3(0.78, 0.71, 0.67), GOLD, BRONZE, 5, 9)
		var elbow := Vector3(side * 0.54, -1.55, 0)
		l.prism(Vector3(side * 0.32, -0.25, 0), elbow, 0.5, 0.35, 8, BRONZE)
		var wrist := Vector3(side * 0.41, -2.54, 0.78)
		l.prism(elbow, wrist, 0.4, 0.26, 8, TURQUOISE)
		l.ovoid(wrist, Vector3(0.4, 0.37, 0.33), GOLD, BRONZE, 4, 8)
		if side > 0.0:
			var handle := wrist + Vector3(0.54, -0.51, 2.18)
			l.prism(wrist - Vector3(0.2, -0.14, 0.74), handle, 0.16, 0.19, 7, BRONZE)
			l.ovoid(handle + Vector3(0, -0.06, 0.7), Vector3(0.84, 0.44, 1.07), GOLD, BRONZE, 5, 11)
			l.ovoid(handle + Vector3(0, 0.34, 0.7), Vector3(0.70, 0.11, 0.87), DARK, WINE, 4, 10)
		else:
			for i in 4:
				var at := wrist + Vector3((i - 1.5) * 0.17, 0.02, 0.15)
				l.prism(at, at + Vector3(0, 0.14, 0.49), 0.11, 0.07, 5, IVORY)
		_mesh(arm, l)
	for i in 9:
		var a := TAU * i / 9.0
		var skirt := _part(body, "Sash%d" % i, Vector3(cos(a) * 1.01, 3.68, sin(a) * 1.01))
		skirt.rotation.y = PI * 0.5 - a
		skirt.set_meta("rest", skirt.transform)
		l = LowPoly.new()
		l.box(Vector3(0, -1.27, 0.27), Vector3(0.66, 2.64, 0.12), WINE if i % 2 == 0 else TURQUOISE, Vector3(-12, 0, 0))
		l.box(Vector3(0, -2.51, 0.55), Vector3(0.65, 0.19, 0.16), GOLD)
		_mesh(skirt, l)
	var orbit := _part(body, ORBIT, Vector3(0, 7.11, -0.73))
	l = LowPoly.new()
	for i in 28:
		var a := TAU * i / 28.0
		var b := TAU * (i + 1) / 28.0
		var at := Vector3(cos(a), sin(a), 0) * 2.49
		var next := Vector3(cos(b), sin(b), 0) * 2.49
		l.prism(at, next, 0.095, 0.095, 6, GOLD)
		if i % 4 == 0:
			l.ovoid(at * 1.08, Vector3(0.24, 0.24, 0.18), FIRE, GOLD, 5, 8)
	_mesh(orbit, l, true)
	return root


static func animate(z: Zombie, root: Node3D, delta: float, state: String, clock: float, elapsed: float) -> void:
	var body := root.get_node("Body") as Node3D
	var ladle := body.get_node("LadleArm") as Node3D
	var serve := body.get_node("ServingArm") as Node3D
	var wheel := body.get_node(ORBIT) as Node3D
	var mask := body.get_node("Mask") as Node3D
	var embers := body.get_node("Embers") as Node3D
	var warning := z.is_warning()
	var lift := 0.0
	var open := 0.0
	var twist := 0.0
	var bounce := 0.14 * sin(clock * 2.5)
	match state:
		"m_rise":
			bounce += -3.2 * (1.0 - smoothstep(0.0, 1.8, elapsed))
			lift = -0.55 * sin(clampf(elapsed / 1.8, 0.0, 1.0) * PI)
		"m_cast":
			lift = -2.53 if warning else 0.63
			open = -1.71 if warning else -0.35
			bounce += 0.37 if warning else -0.28 * exp(-elapsed * 5.0)
		"m_sweep":
			lift = -0.88 if warning else -1.16
			twist = 0.8 if warning else -0.9 * exp(-elapsed * 3.2)
		"m_slam":
			lift = -2.08 if warning else 0.82
			open = lift * 0.8
			bounce += 0.7 if warning else -0.40 * exp(-elapsed * 5.0)
		"m_roar":
			open = -2.1
			lift = -2.05
	var blend := minf(1.0, delta * (5.0 if warning else 13.0))
	body.position.y = lerpf(body.position.y, bounce, blend)
	body.rotation.y = lerp_angle(body.rotation.y, twist, blend)
	ladle.rotation.x = lerpf(ladle.rotation.x, lift + sin(clock * 2.15) * 0.12, blend)
	ladle.rotation.z = lerpf(ladle.rotation.z, 0.25 + twist * 0.5, blend)
	serve.rotation.x = lerpf(serve.rotation.x, open + sin(clock * 2.15 + PI) * 0.11, blend)
	serve.rotation.z = lerpf(serve.rotation.z, -0.28 - absf(open) * 0.27, blend)
	wheel.rotation.z += delta * (0.65 if warning else 0.21)
	wheel.rotation.y = sin(clock * 1.4) * 0.13
	mask.rotation.x = lerpf(mask.rotation.x, -0.19 if warning else 0.12, blend)
	embers.scale = Vector3.ONE * (0.96 + sin(clock * (13.0 if warning else 3.0)) * (0.16 if warning else 0.06))
	for i in 9:
		var sash := body.get_node("Sash%d" % i) as Node3D
		sash.rotation.x = sin(clock * 2.9 + i * 0.7) * (0.18 if warning else 0.08) - 0.14


static func fall(root: Node3D, progress: float) -> void:
	var body := root.get_node("Body") as Node3D
	body.rotation.z = smoothstep(0.0, 0.62, progress) * -0.92
	body.rotation.x = smoothstep(0.0, 0.8, progress) * 0.66
	body.position.y = -4.7 * smoothstep(0.23, 1.0, progress)
	(body.get_node(ORBIT) as Node3D).scale = Vector3.ONE * maxf(0.01, 1.0 - progress)
	(body.get_node("Embers") as Node3D).scale = Vector3.ONE * (1.0 - smoothstep(0.0, 0.24, progress))
