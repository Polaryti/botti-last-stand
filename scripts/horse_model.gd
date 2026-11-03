class_name HorseModel
## One horse, shared by every rider. Its legs move in the shader, so it costs a single draw call.
## Each rider has its own copy of the material, because each horse moves at its own pace.

const RIDDEN_SIZE := 0.82 # beside the game's big-headed people, a horse at full size swallows its rider
const SADDLE := 0.7 # how high a rider sits on a horse of that size, for someone of height 1.8

static var _mesh: Mesh
static var _material: ShaderMaterial


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
	l.box(Vector3(-0.1, 2.27, -1.03), Vector3(0.07, 0.16, 0.05), coat)
	l.box(Vector3(0.1, 2.27, -1.03), Vector3(0.07, 0.16, 0.05), coat)
	l.box(Vector3(0, 1.0, 1.32), Vector3(0.12, 0.85, 0.14), mane, Vector3(16, 0, 0))
	for s: Vector2 in [Vector2(-0.27, -0.65), Vector2(0.27, -0.65), Vector2(-0.27, 0.95), Vector2(0.27, 0.95)]:
		l.box(Vector3(s.x, 0.48, s.y), Vector3(0.17, 0.85, 0.17), coat)
		l.box(Vector3(s.x, 0.06, s.y), Vector3(0.2, 0.1, 0.2), mane)
	_mesh = l.commit()
	_mesh.surface_set_material(0, material())
	return _mesh


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://assets/shaders/horse.gdshader")
	return _material


## A horse of its own, standing still until told otherwise.
static func make() -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh()
	n.material_override = material().duplicate()
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_gait(n, 0.0)
	return n


static func set_gait(horse: MeshInstance3D, gait: float) -> void:
	var m := horse.material_override as ShaderMaterial
	var was: Variant = m.get_shader_parameter("gait")
	if was == null or absf(float(was) - gait) > 0.08:
		m.set_shader_parameter("gait", gait)
