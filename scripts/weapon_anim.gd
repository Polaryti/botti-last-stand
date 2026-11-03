class_name WeaponAnim
## First-person attack animations as keyframes. Each key is a moment of the attack, a position
## offset of the hand, and which way the blade points. Every swing has the same three beats:
## a quick wind-up, a fast strike that lands at Player.SWING_HIT, and a slower recovery.

const SMEAR_TIME := 0.11
const HIT_MOMENT_START := 0.18 # a hit from another move joins the swing just before the blow

## Blade pointing direction for the weapons held upright, in the camera's frame.
const REST_DIRS := {
	"stab": Vector3(0.08, 0.5, -0.86),
	"slash": Vector3(-0.22, 0.75, -0.62),
	"reap": Vector3(-0.05, 0.88, -0.45),
	"smash": Vector3(-0.28, 0.8, -0.3),
	"claw": Vector3(-0.06, 0.82, -0.56),
	"overhead": Vector3(-0.1, 0.94, -0.3),
}

## name -> list of [time, hand offset, blade direction, roll around the blade]
const KEYS := {
	"overhead_a": [
		[0.0, Vector3.ZERO, Vector3(-0.1, 0.94, -0.3), 1.25],
		[0.24, Vector3(-0.04, 0.12, 0.1), Vector3(-0.03, 0.8, 0.6), 0.6],
		[0.3, Vector3(-0.16, 0.1, -0.08), Vector3(-0.04, 0.72, -0.68), 0.1],
		[0.42, Vector3(-0.22, -0.12, -0.14), Vector3(-0.03, 0.02, -1.0), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.1, 0.94, -0.3), 1.25]],
	"overhead_b": [
		[0.0, Vector3.ZERO, Vector3(-0.1, 0.94, -0.3), 1.25],
		[0.24, Vector3(-0.04, 0.12, 0.1), Vector3(-0.03, 0.8, 0.6), 0.6],
		[0.3, Vector3(-0.16, 0.1, -0.08), Vector3(-0.04, 0.72, -0.68), 0.1],
		[0.42, Vector3(-0.22, -0.12, -0.14), Vector3(-0.03, 0.02, -1.0), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.1, 0.94, -0.3), 1.25]],
	"claw_a": [
		[0.0, Vector3.ZERO, Vector3(-0.06, 0.82, -0.56), 0.0],
		[0.16, Vector3(0.1, 0.16, 0.06), Vector3(0.42, 0.86, 0.12), 0.25],
		[0.3, Vector3(-0.06, 0.05, -0.2), Vector3(-0.3, 0.46, -0.84), 0.8],
		[0.44, Vector3(-0.36, -0.14, -0.12), Vector3(-0.8, -0.12, -0.5), 1.0],
		[1.0, Vector3.ZERO, Vector3(-0.06, 0.82, -0.56), 0.0]],
	"claw_b": [
		[0.0, Vector3.ZERO, Vector3(-0.06, 0.82, -0.56), 0.0],
		[0.16, Vector3(0.1, 0.16, 0.06), Vector3(0.42, 0.86, 0.12), 0.25],
		[0.3, Vector3(-0.06, 0.05, -0.2), Vector3(-0.3, 0.46, -0.84), 0.8],
		[0.44, Vector3(-0.36, -0.14, -0.12), Vector3(-0.8, -0.12, -0.5), 1.0],
		[1.0, Vector3.ZERO, Vector3(-0.06, 0.82, -0.56), 0.0]],
	"slash_a": [
		[0.0, Vector3.ZERO, Vector3(-0.22, 0.75, -0.62), 0.0],
		[0.17, Vector3(0.1, 0.1, 0.03), Vector3(0.55, 0.78, 0.12), 0.3],
		[0.3, Vector3(-0.04, 0.04, -0.12), Vector3(-0.32, 0.42, -0.85), 0.9],
		[0.45, Vector3(-0.42, -0.1, -0.06), Vector3(-0.96, -0.08, -0.28), 1.2],
		[1.0, Vector3.ZERO, Vector3(-0.22, 0.75, -0.62), 0.0]],
	"slash_b": [
		[0.0, Vector3.ZERO, Vector3(-0.22, 0.75, -0.62), 0.0],
		[0.17, Vector3(-0.34, -0.08, -0.04), Vector3(-0.92, 0.16, -0.36), -0.9],
		[0.3, Vector3(-0.1, 0.0, -0.12), Vector3(0.24, 0.36, -0.9), -0.9],
		[0.45, Vector3(0.12, 0.1, -0.06), Vector3(0.9, 0.42, -0.18), -0.8],
		[1.0, Vector3.ZERO, Vector3(-0.22, 0.75, -0.62), 0.0]],
	"reap_a": [
		[0.0, Vector3.ZERO, Vector3(-0.05, 0.88, -0.45), 0.0],
		[0.2, Vector3(0.16, 0.06, 0.1), Vector3(0.72, 0.62, -0.1), 0.0],
		[0.3, Vector3(0.02, -0.04, -0.12), Vector3(0.12, 0.42, -0.9), 0.0],
		[0.48, Vector3(-0.44, -0.1, -0.06), Vector3(-0.9, 0.3, -0.28), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.05, 0.88, -0.45), 0.0]],
	"reap_b": [
		[0.0, Vector3.ZERO, Vector3(-0.05, 0.88, -0.45), 0.0],
		[0.2, Vector3(-0.42, -0.04, 0.02), Vector3(-0.85, 0.45, -0.1), 0.0],
		[0.3, Vector3(-0.1, -0.05, -0.14), Vector3(-0.1, 0.42, -0.9), 0.0],
		[0.48, Vector3(0.2, 0.0, -0.06), Vector3(0.88, 0.4, -0.2), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.05, 0.88, -0.45), 0.0]],
	"smash_a": [
		[0.0, Vector3.ZERO, Vector3(-0.28, 0.8, -0.3), 0.0],
		[0.2, Vector3(0.04, 0.16, 0.02), Vector3(0.1, 0.86, 0.5), 0.0],
		[0.3, Vector3(-0.1, -0.02, -0.14), Vector3(-0.14, 0.34, -0.93), 0.0],
		[0.42, Vector3(-0.13, -0.17, -0.16), Vector3(-0.14, -0.24, -0.96), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.28, 0.8, -0.3), 0.0]],
	"smash_b": [
		[0.0, Vector3.ZERO, Vector3(-0.28, 0.8, -0.3), 0.0],
		[0.2, Vector3(0.12, 0.13, 0.0), Vector3(0.58, 0.72, 0.38), 0.0],
		[0.3, Vector3(-0.06, 0.0, -0.14), Vector3(0.1, 0.32, -0.94), 0.0],
		[0.42, Vector3(-0.28, -0.16, -0.12), Vector3(-0.6, -0.22, -0.76), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.28, 0.8, -0.3), 0.0]],
	"stab_a": [
		[0.0, Vector3.ZERO, Vector3(0.08, 0.5, -0.86), 0.0],
		[0.16, Vector3(0.04, -0.03, 0.08), Vector3(0.14, 0.62, -0.77), 0.0],
		[0.3, Vector3(-0.1, 0.05, -0.16), Vector3(-0.14, 0.36, -0.92), 0.0],
		[0.46, Vector3(-0.09, 0.04, -0.13), Vector3(-0.1, 0.4, -0.91), 0.0],
		[1.0, Vector3.ZERO, Vector3(0.08, 0.5, -0.86), 0.0]],
	"stab_b": [
		[0.0, Vector3.ZERO, Vector3(0.08, 0.5, -0.86), 0.0],
		[0.16, Vector3(0.08, 0.06, 0.06), Vector3(0.34, 0.6, -0.72), 1.2],
		[0.3, Vector3(-0.15, 0.0, -0.15), Vector3(-0.34, 0.24, -0.9), 1.6],
		[0.46, Vector3(-0.17, -0.02, -0.11), Vector3(-0.4, 0.28, -0.87), 1.4],
		[1.0, Vector3.ZERO, Vector3(0.08, 0.5, -0.86), 0.0]],
	# Polearms lie along the camera's view: only the hands move, and the point drives straight in.
	"thrust_a": [
		[0.0, Vector3.ZERO, Vector3.ZERO, 0.0],
		[0.2, Vector3(0.03, -0.03, 0.26), Vector3(0.06, 0.02, 0.0), 0.0],
		[0.3, Vector3(-0.1, 0.05, -0.72), Vector3(-0.01, 0.06, 0.0), 0.0],
		[0.44, Vector3(-0.09, 0.04, -0.64), Vector3(0.0, 0.05, 0.0), 0.3],
		[1.0, Vector3.ZERO, Vector3.ZERO, 0.0]],
	"thrust_b": [
		[0.0, Vector3.ZERO, Vector3.ZERO, 0.0],
		[0.2, Vector3(0.06, 0.05, 0.24), Vector3(-0.05, -0.05, 0.0), 0.0],
		[0.3, Vector3(-0.14, -0.02, -0.7), Vector3(0.05, 0.08, 0.0), 0.0],
		[0.44, Vector3(-0.12, -0.03, -0.6), Vector3(0.04, 0.06, 0.0), -0.3],
		[1.0, Vector3.ZERO, Vector3.ZERO, 0.0]],
	"cast": [
		[0.0, Vector3.ZERO, Vector3(-0.1, 0.96, -0.2), 0.0],
		[0.16, Vector3(0.02, -0.03, 0.1), Vector3(-0.02, 0.92, 0.3), 0.0],
		[0.3, Vector3(-0.1, 0.1, -0.24), Vector3(-0.12, 0.7, -0.72), 0.0],
		[0.5, Vector3(-0.08, 0.08, -0.18), Vector3(-0.12, 0.76, -0.62), 0.0],
		[1.0, Vector3.ZERO, Vector3(-0.1, 0.96, -0.2), 0.0]],
	"throw": [
		[0.0, Vector3.ZERO, Vector3(-0.1, 0.9, -0.3), 0.0],
		[0.14, Vector3(0.06, 0.22, 0.14), Vector3(0.2, 0.62, 0.72), 0.0],
		[0.3, Vector3(-0.08, 0.0, -0.34), Vector3(-0.08, 0.1, -1.0), 0.0],
		[1.0, Vector3(0.0, -0.3, 0.0), Vector3(-0.1, 0.9, -0.3), 0.0]],
}

static var _quats := {}
static var _smear: Mesh
static var _arrow: Mesh
static var _orb: Mesh
static var _mist: Material


static func keys_for(swing: String, side: bool) -> String:
	if swing == "":
		return ""
	return swing + ("_a" if side else "_b")


## The blade's +Y axis points along dir, and roll turns the edge to face the swing.
static func _blade(dir: Vector3, roll: float) -> Quaternion:
	var y := dir.normalized()
	var hint := Vector3.BACK if absf(y.z) < 0.9 else Vector3.UP
	var x := hint.cross(y).normalized()
	var z := x.cross(y)
	return Quaternion(Basis(x, y, z)) * Quaternion(Vector3.UP, roll)


static func _key_rotation(keys: String, key: Array) -> Quaternion:
	var dir: Vector3 = key[2]
	if keys.begins_with("thrust"):
		return Quaternion.from_euler(Vector3(dir.y, -dir.x, float(key[3])))
	return _blade(dir, float(key[3]))


## What the weapon looks like when nothing is happening.
static func rest_rotation(swing: String, tilt: float) -> Quaternion:
	var key := "rest" + swing + str(tilt)
	if not _quats.has(key):
		if REST_DIRS.has(swing):
			_quats[key] = _blade(REST_DIRS[swing], 1.25 if swing == "overhead" else 0.0)
		elif swing == "thrust":
			_quats[key] = Quaternion.from_euler(Vector3.ZERO)
		else:
			_quats[key] = Quaternion(Vector3(0, 0, 1), tilt)
	return _quats[key]


## Returns [hand offset, rotation or null]. Past the end of the keys it returns the rest pose.
static func sample(keys: String, t: float, arc: float) -> Array:
	if keys == "" or t >= 1.0 or not KEYS.has(keys):
		return [Vector3.ZERO, null]
	var list: Array = KEYS[keys]
	if not _quats.has(keys):
		var rots: Array[Quaternion] = []
		for key: Array in list:
			rots.append(_key_rotation(keys, key))
		_quats[keys] = rots
	var rots: Array[Quaternion] = _quats[keys]
	var i := 0
	while i < list.size() - 2 and t >= float(list[i + 1][0]):
		i += 1
	var a: Array = list[i]
	var b: Array = list[i + 1]
	var f := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	# The blow itself accelerates. Everything else eases in and out.
	var striking := float(a[0]) < Player.SWING_HIT and float(b[0]) >= Player.SWING_HIT and i > 0
	f = f * f if striking else smoothstep(0.0, 1.0, f)
	var pos: Vector3 = (a[1] as Vector3).lerp(b[1], f) * arc
	return [pos, rots[i].slerp(rots[i + 1], f)]


## The plane of the swing's trail, or NAN for a blow that leaves none.
static func smear_roll(keys: String) -> float:
	match keys:
		"overhead_a", "overhead_b": return 1.57
		"claw_a": return 0.5
		"claw_b": return -0.5
		"slash_a": return 0.28
		"slash_b": return -0.28
		"reap_a": return 0.1
		"reap_b": return -0.1
		"smash_a": return 1.35
		"smash_b": return 0.95
	return NAN


## Which way the trail travels while it fades.
static func smear_turn(keys: String) -> float:
	match keys:
		"slash_a", "reap_a", "claw_a": return 0.9
		"slash_b", "reap_b", "claw_b": return -0.9
		"smash_a", "smash_b": return 0.6
	return 0.0


## A pale band along the path of the blade. It shows for a tenth of a second, and it is what
## makes a blow look fast on a small screen.
static func smear_mesh() -> Mesh:
	if _smear:
		return _smear
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 12
	for i in SEGMENTS:
		var a0 := lerpf(-1.25, 1.25, float(i) / SEGMENTS)
		var a1 := lerpf(-1.25, 1.25, float(i + 1) / SEGMENTS)
		var fade0 := sin(float(i) / SEGMENTS * PI)
		var fade1 := sin(float(i + 1) / SEGMENTS * PI)
		var inner := 0.42
		var outer := 0.78
		var p0 := Vector3(sin(a0) * inner, 0, -cos(a0) * inner)
		var p1 := Vector3(sin(a0) * outer, 0, -cos(a0) * outer)
		var p2 := Vector3(sin(a1) * outer, 0, -cos(a1) * outer)
		var p3 := Vector3(sin(a1) * inner, 0, -cos(a1) * inner)
		for v: Array in [[p0, 0.0], [p1, fade0], [p2, fade1], [p0, 0.0], [p2, fade1], [p3, 0.0]]:
			st.set_color(Color(0.95, 0.97, 1.0, float(v[1]) * 0.55))
			st.add_vertex(v[0])
	_smear = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	_smear.surface_set_material(0, m)
	return _smear


static func mist_smear() -> Material:
	if _mist == null:
		var m := (smear_mesh().surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = Color(0.5, 0.95, 0.95)
		_mist = m
	return _mist


static func nocked_arrow() -> Mesh:
	if _arrow == null:
		_arrow = LowPoly.new() \
			.prism(Vector3(0, 0, 0.32), Vector3(0, 0, -0.34), 0.011, 0.011, 4, WeaponDefs.LIGHT_WOOD) \
			.prism(Vector3(0, 0, -0.34), Vector3(0, 0, -0.44), 0.024, 0.0, 4, WeaponDefs.STEEL) \
			.box(Vector3(0, 0, 0.28), Vector3(0.008, 0.06, 0.1), Color(0.9, 0.9, 0.85)) \
			.box(Vector3(0, 0, 0.28), Vector3(0.06, 0.008, 0.1), Color(0.9, 0.9, 0.85)) \
			.commit()
	return _arrow


## The light at the head of the staff.
static func orb_mesh() -> Mesh:
	if _orb == null:
		var s := SphereMesh.new()
		s.radius = 0.055
		s.height = 0.11
		s.radial_segments = 8
		s.rings = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.62, 0.8, 1.0)
		s.material = m
		_orb = s
	return _orb
