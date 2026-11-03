@tool
class_name Crops
## The plants of the fields and the orchard, drawn as instanced meshes that sway in the wind.

static var _meshes := {}
static var _sway: ShaderMaterial
static var _sway_soft: ShaderMaterial


static func material(soft := false) -> ShaderMaterial:
	if _sway == null:
		_sway = ShaderMaterial.new()
		_sway.shader = load("res://assets/shaders/sway.gdshader")
		_sway_soft = ShaderMaterial.new()
		_sway_soft.shader = _sway.shader
		_sway_soft.set_shader_parameter("strength", 0.018)
	return _sway_soft if soft else _sway


## Flat blade from a base point to a tip, one triangle.
static func _blade(l: LowPoly, base: Vector3, tip: Vector3, wide: float, col: Color) -> void:
	var dir := tip - base
	var side := Vector3(dir.z, 0, -dir.x)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized() * wide * 0.5
	l.gable(base - side, base + side, tip, col)


static func wheat() -> Mesh:
	if _meshes.has("wheat"):
		return _meshes["wheat"]
	var l := LowPoly.new()
	var straw := Color(0.5, 0.42, 0.2)
	var ear := Color(0.6, 0.5, 0.24)
	for i in 4:
		var a := TAU * i / 4.0 + 0.5
		var lean := Vector3(cos(a), 0, sin(a))
		var top := lean * 0.2 + Vector3.UP * (1.35 + 0.13 * (i % 2))
		_blade(l, lean * 0.06, top, 0.07, straw)
		# The heavy ear, nodding at the top of the stalk.
		var over := top + lean * 0.09 + Vector3.UP * 0.2
		_blade(l, top + Vector3.DOWN * 0.06, over, 0.075, ear)
		_blade(l, over, top + lean * 0.14 + Vector3.DOWN * 0.03, 0.05, ear.darkened(0.12))
	for i in 3:
		var a := TAU * i / 3.0
		var lean := Vector3(cos(a), 0, sin(a))
		_blade(l, lean * 0.04, lean * 0.42 + Vector3.UP * 0.72, 0.1, Color(0.32, 0.36, 0.16))
	_meshes["wheat"] = l.commit()
	return _meshes["wheat"]


static func corn() -> Mesh:
	if _meshes.has("corn"):
		return _meshes["corn"]
	var l := LowPoly.new()
	var stem := Color(0.3, 0.44, 0.17)
	var leaf := Color(0.24, 0.46, 0.17)
	l.prism(Vector3.ZERO, Vector3(0, 2.3, 0), 0.035, 0.015, 3, stem)
	for i in 6:
		var a := i * 2.4
		var y := 0.45 + i * 0.3
		var out := Vector3(cos(a), 0, sin(a))
		var mid := out * 0.34 + Vector3.UP * (y + 0.28)
		_blade(l, Vector3.UP * y, mid, 0.13, leaf.lightened(0.05 * (i % 3)))
		_blade(l, mid, out * 0.72 + Vector3.UP * (y + 0.05), 0.1, leaf.darkened(0.08))
	# Cobs and the tassel.
	l.prism(Vector3(0.05, 1.05, 0.03), Vector3(0.15, 1.42, 0.07), 0.046, 0.026, 4, Color(0.66, 0.54, 0.22))
	l.prism(Vector3(-0.05, 1.3, -0.03), Vector3(-0.14, 1.62, -0.07), 0.04, 0.022, 4, Color(0.6, 0.5, 0.24))
	for i in 3:
		var a := i * 2.1
		_blade(l, Vector3.UP * 2.25, Vector3(cos(a) * 0.14, 2.62, sin(a) * 0.14), 0.05, Color(0.72, 0.6, 0.3))
	_meshes["corn"] = l.commit()
	return _meshes["corn"]


static func cabbage() -> Mesh:
	if _meshes.has("cabbage"):
		return _meshes["cabbage"]
	var l := LowPoly.new()
	l.prism(Vector3(0, 0.02, 0), Vector3(0, 0.34, 0), 0.25, 0.13, 7, Color(0.48, 0.66, 0.34))
	for i in 5:
		var a := TAU * i / 5.0
		var out := Vector3(cos(a), 0, sin(a))
		_blade(l, out * 0.08 + Vector3.UP * 0.04, out * 0.48 + Vector3.UP * 0.2, 0.32, Color(0.26, 0.5, 0.26))
	_meshes["cabbage"] = l.commit()
	return _meshes["cabbage"]


static func turnip() -> Mesh:
	if _meshes.has("turnip"):
		return _meshes["turnip"]
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.02, 0), Vector3(0, 0.12, 0), 0.08, 0.1, 5, Color(0.8, 0.6, 0.72))
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		_blade(l, Vector3.UP * 0.1, Vector3(cos(a) * 0.17, 0.48, sin(a) * 0.17), 0.1, Color(0.27, 0.48, 0.2))
	_meshes["turnip"] = l.commit()
	return _meshes["turnip"]


static func beans() -> Mesh:
	if _meshes.has("beans"):
		return _meshes["beans"]
	var l := LowPoly.new()
	l.prism(Vector3(-0.04, 0, 0), Vector3(0.02, 2.0, 0), 0.022, 0.015, 3, Color(0.42, 0.3, 0.17))
	l.prism(Vector3(0.05, 0, 0.04), Vector3(0.02, 2.0, 0), 0.022, 0.015, 3, Color(0.42, 0.3, 0.17))
	for i in 7:
		var a := i * 2.4
		var y := 0.25 + i * 0.25
		_blade(l, Vector3(0, y, 0), Vector3(cos(a) * 0.32, y + 0.2, sin(a) * 0.32), 0.26, Color(0.22, 0.42, 0.18))
	_meshes["beans"] = l.commit()
	return _meshes["beans"]


static func pumpkin() -> Mesh:
	if _meshes.has("pumpkin"):
		return _meshes["pumpkin"]
	var l := LowPoly.new()
	var skin := Color(0.88, 0.45, 0.1)
	l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.24, 0), 0.26, 0.38, 8, skin)
	l.prism(Vector3(0, 0.24, 0), Vector3(0, 0.44, 0), 0.38, 0.16, 8, skin.darkened(0.08))
	l.prism(Vector3(0, 0.44, 0), Vector3(0.03, 0.56, 0), 0.05, 0.03, 4, Color(0.32, 0.36, 0.14))
	for i in 3:
		var a := i * 2.1 + 0.4
		_blade(l, Vector3(cos(a) * 0.25, 0.02, sin(a) * 0.25), Vector3(cos(a) * 0.75, 0.16, sin(a) * 0.75), 0.38, Color(0.2, 0.4, 0.17))
	_meshes["pumpkin"] = l.commit()
	return _meshes["pumpkin"]


## Plain plants that the wind barely moves: a low vine on its frame.
static func vine() -> Mesh:
	if _meshes.has("vine"):
		return _meshes["vine"]
	var l := LowPoly.new()
	var wood := Color(0.3, 0.2, 0.12)
	l.prism(Vector3(0, 0, 0), Vector3(0, 1.45, 0), 0.03, 0.03, 4, wood)
	l.box(Vector3(0, 1.2, 0), Vector3(1.9, 0.03, 0.03), wood)
	for i in 8:
		var x := -0.8 + i * 0.23
		_blade(l, Vector3(x, 1.2, 0), Vector3(x + 0.14, 1.52, 0.16 * (1 if i % 2 == 0 else -1)), 0.3, Color(0.22, 0.4, 0.16))
		_blade(l, Vector3(x, 1.2, 0), Vector3(x - 0.1, 0.78, -0.16 * (1 if i % 2 == 0 else -1)), 0.28, Color(0.25, 0.44, 0.17))
		if i % 2 == 0:
			l.prism(Vector3(x, 1.12, 0.02), Vector3(x, 0.92, 0.02), 0.075, 0.02, 4, Color(0.34, 0.16, 0.42))
	_meshes["vine"] = l.commit()
	return _meshes["vine"]


## An apple tree, smaller than the forest trees, with fruit you can see from a distance.
static func apple_tree() -> Mesh:
	if _meshes.has("apple_tree"):
		return _meshes["apple_tree"]
	var l := LowPoly.new()
	var bark := Color(0.28, 0.2, 0.14)
	var leaf := Color(0.2, 0.38, 0.17)
	l.prism(Vector3.ZERO, Vector3(0, 1.5, 0), 0.17, 0.11, 6, bark)
	l.prism(Vector3(0, 1.3, 0), Vector3(0.68, 2.2, 0.2), 0.08, 0.05, 4, bark)
	l.prism(Vector3(0, 1.4, 0), Vector3(-0.55, 2.28, -0.3), 0.08, 0.05, 4, bark)
	for c: Array in [[Vector3(0, 2.75, 0), 1.45, 0.0], [Vector3(0.82, 2.35, 0.3), 1.0, 0.04], [Vector3(-0.72, 2.45, -0.42), 1.1, -0.03], [Vector3(0.1, 2.3, -0.82), 0.95, 0.03]]:
		var at: Vector3 = c[0]
		var r: float = c[1]
		var tone := leaf.lightened(float(c[2]) + 0.04)
		l.prism(at + Vector3.DOWN * r * 0.65, at, r * 0.55, r, 7, tone.darkened(0.08))
		l.prism(at, at + Vector3.UP * r * 0.72, r, 0.1, 7, tone)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.95, 1.65)
		var y := rng.randf_range(1.95, 3.2)
		var shrink := clampf(1.0 - absf(y - 2.6) * 0.42, 0.4, 1.0)
		l.box(Vector3(cos(a) * r * shrink, y, sin(a) * r * shrink), Vector3.ONE * 0.13, Color(0.82, 0.14, 0.1) if i % 5 != 0 else Color(0.86, 0.62, 0.14))
	_meshes["apple_tree"] = l.commit()
	return _meshes["apple_tree"]


## Instances with their own tint, so a field is not one flat colour.
static func plant(mesh: Mesh, xforms: Array[Transform3D], tints: PackedColorArray, soft := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, tints[i] if i < tints.size() else Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material(soft)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
