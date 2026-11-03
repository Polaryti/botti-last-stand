class_name HorseModel
## One horse, shared by every rider. Its legs move in the shader, so it costs a single draw call.

static var _mesh: Mesh


static func mesh() -> Mesh:
	if _mesh:
		return _mesh
	var coat := Color(0.3, 0.19, 0.12)
	var mane := Color(0.1, 0.07, 0.06)
	var cloth := Color(0.55, 0.13, 0.12)
	var l := LowPoly.new()
	l.box(Vector3(0, 1.15, 0.15), Vector3(0.75, 0.75, 2.0), coat)
	l.box(Vector3(0, 1.37, 0.15), Vector3(0.82, 0.32, 1.2), cloth)
	l.box(Vector3(0, 1.62, -0.92), Vector3(0.36, 1.0, 0.45), coat, Vector3(-30, 0, 0))
	l.box(Vector3(0, 2.05, -1.32), Vector3(0.3, 0.32, 0.78), coat)
	l.box(Vector3(0, 1.96, -1.74), Vector3(0.24, 0.2, 0.2), Color(0.16, 0.1, 0.07))
	l.box(Vector3(0, 1.9, -0.72), Vector3(0.08, 1.05, 0.14), mane, Vector3(-30, 0, 0))
	for s: Vector2 in [Vector2(-0.27, -0.65), Vector2(0.27, -0.65), Vector2(-0.27, 0.95), Vector2(0.27, 0.95)]:
		l.box(Vector3(s.x, 0.48, s.y), Vector3(0.17, 0.85, 0.17), coat)
		l.box(Vector3(s.x, 0.06, s.y), Vector3(0.2, 0.1, 0.2), mane)
	_mesh = l.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/horse.gdshader")
	_mesh.surface_set_material(0, m)
	return _mesh
