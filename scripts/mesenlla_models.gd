class_name MesenllaModels
extends RefCounted
## The creatures of the Valleys of Mesenlla and Mist Bastion: low-poly bodies built from code, and the
## light animation that moves them. Four-legged bodies move their legs in beast_gait.gdshader; the
## rest are parts on pivots. Each model is a root facing +Z; what the animation needs is kept as meta.
## The state a creature is in (rearing, charging, slamming...) is Zombie._current_anim, which is
## also what other phones are sent, so they show the same thing.

const KINDS := ["bear", "mist_bear", "eagle", "mist_eagle", "shapeshifter", "earth_elemental", "mist_elemental",
	"storm_elemental", "wyvern", "great_revenant_elemental", "war_wyvern"]
const FLYERS := ["eagle", "mist_eagle", "wyvern", "war_wyvern"]
const BOSS_NAMES := {"great_revenant_elemental": "GREAT REVENANT ELEMENTAL", "war_wyvern": "WAR WYVERN"}

const FUR := Color(0.36, 0.24, 0.15)
const FUR_DARK := Color(0.22, 0.14, 0.09)
const MUZZLE := Color(0.55, 0.42, 0.3)
const CLAW := Color(0.86, 0.82, 0.7)
const BLACK := Color(0.05, 0.05, 0.06)
const MIST_FUR := Color(0.52, 0.6, 0.64)
const MIST_GLOW := Color(0.45, 0.95, 0.92)
const STONE := Color(0.46, 0.44, 0.41)
const STONE_DARK := Color(0.3, 0.29, 0.28)
const MOSS := Color(0.3, 0.46, 0.22)
const AMBER := Color(1.0, 0.66, 0.2)
const BONE := Color(0.9, 0.88, 0.8)
const SCALE_GREEN := Color(0.3, 0.38, 0.26)
const SCALE_BELLY := Color(0.62, 0.58, 0.42)
const WING := Color(0.36, 0.27, 0.22)
const STEEL := Color(0.58, 0.6, 0.66)
const BANNER_RED := Color(0.62, 0.12, 0.1)
const GOLD := Color(0.95, 0.72, 0.22)
const LEAF := Color(0.3, 0.5, 0.22)
const LEAF_DARK := Color(0.2, 0.34, 0.15)
const BARK := Color(0.4, 0.3, 0.2)

static var _meshes := {}
static var _gait_shader: Shader
static var _glow: StandardMaterial3D
static var _ghost: StandardMaterial3D


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var l := LowPoly.new()
		build.call(l)
		_meshes[key] = l.commit()
	return _meshes[key]


static func _part(parent: Node3D, mesh: Mesh, at := Vector3.ZERO, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func _pivot(parent: Node3D, at: Vector3, name: String) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.name = name
	parent.add_child(n)
	return n


## Unshaded and coloured by the mesh: eyes, cores, lightning.
static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.vertex_color_use_as_albedo = true
		_glow.disable_fog = true
	return _glow


## Half there: mist creatures, coloured by the mesh and lit from inside.
static func ghost_material() -> StandardMaterial3D:
	if _ghost == null:
		_ghost = StandardMaterial3D.new()
		_ghost.vertex_color_use_as_albedo = true
		_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.albedo_color = Color(1, 1, 1, 0.78)
		_ghost.emission_enabled = true
		_ghost.emission = Color(0.18, 0.42, 0.46)
		_ghost.rim_enabled = true
		_ghost.rim = 0.8
	return _ghost


## A four-legged body with its own copy of the gait material, so each one walks at its own pace.
static func _gaited(parent: Node3D, mesh: Mesh, belly: float, neck_z: float, mist := 0.0) -> MeshInstance3D:
	if _gait_shader == null:
		_gait_shader = load("res://assets/shaders/beast_gait.gdshader")
	var mi := _part(parent, mesh)
	var m := ShaderMaterial.new()
	m.shader = _gait_shader
	m.set_shader_parameter("belly", belly)
	m.set_shader_parameter("neck_z", neck_z)
	m.set_shader_parameter("mist", mist)
	m.set_shader_parameter("gait", 0.0)
	mi.material_override = m
	mi.extra_cull_margin = 0.6
	mi.rotation.y = PI # built head towards -Z, like the horse
	return mi


static func set_gait(body: MeshInstance3D, gait: float) -> void:
	var m := body.material_override as ShaderMaterial
	if m and absf(float(m.get_shader_parameter("gait")) - gait) > 0.06:
		m.set_shader_parameter("gait", gait)


# --- Bodies ----------------------------------------------------------------------

## A bear, head towards -Z: heavy shoulders, a hump, a short muzzle and pale claws.
static func _bear_mesh(l: LowPoly, fur: Color, dark: Color, muzzle: Color, eye: Color, saddle := false) -> void:
	l.box(Vector3(0, 0.88, 0.1), Vector3(0.92, 0.72, 1.5), fur)
	l.box(Vector3(0, 1.1, -0.42), Vector3(0.98, 0.5, 0.62), fur.lightened(0.05))
	l.box(Vector3(0, 0.98, 0.72), Vector3(0.8, 0.56, 0.5), fur.darkened(0.06))
	l.box(Vector3(0, 0.98, -0.95), Vector3(0.56, 0.5, 0.5), fur)
	l.box(Vector3(0, 0.88, -1.27), Vector3(0.32, 0.26, 0.3), muzzle)
	l.box(Vector3(0, 0.95, -1.44), Vector3(0.12, 0.09, 0.05), BLACK)
	for x: float in [-0.2, 0.2]:
		l.box(Vector3(x, 1.27, -0.92), Vector3(0.13, 0.13, 0.1), dark)
		l.box(Vector3(x * 0.75, 1.06, -1.21), Vector3(0.06, 0.05, 0.03), eye)
	for leg: Vector2 in [Vector2(-0.3, -0.5), Vector2(0.3, -0.5), Vector2(-0.3, 0.62), Vector2(0.3, 0.62)]:
		l.prism(Vector3(leg.x, 0.62, leg.y), Vector3(leg.x, 0.08, leg.y), 0.17, 0.15, 6, dark)
		l.box(Vector3(leg.x, 0.05, leg.y - 0.06), Vector3(0.26, 0.1, 0.3), dark.darkened(0.1))
		for c in 3:
			l.prism(Vector3(leg.x - 0.08 + c * 0.08, 0.05, leg.y - 0.2), Vector3(leg.x - 0.08 + c * 0.08, 0.02, leg.y - 0.3), 0.025, 0.0, 4, CLAW)
	l.box(Vector3(0, 0.98, 0.98), Vector3(0.16, 0.14, 0.12), dark)
	if saddle:
		# Woven of leaves and bark by the Children of the Woods, with a seat and reins.
		l.box(Vector3(0, 1.3, -0.1), Vector3(1.0, 0.1, 0.8), LEAF_DARK)
		l.box(Vector3(0, 1.36, -0.1), Vector3(0.5, 0.12, 0.6), BARK)
		for x: float in [-0.52, 0.52]:
			l.box(Vector3(x, 1.0, -0.1), Vector3(0.04, 0.5, 0.6), LEAF)
		l.box(Vector3(0, 1.18, -0.75), Vector3(0.62, 0.04, 0.04), BARK)


static func bear_mount() -> MeshInstance3D:
	var body := _mesh("bear_mount", func(l: LowPoly) -> void: _bear_mesh(l, FUR, FUR_DARK, MUZZLE, BLACK, true))
	var mi := MeshInstance3D.new()
	mi.mesh = body
	if _gait_shader == null:
		_gait_shader = load("res://assets/shaders/beast_gait.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _gait_shader
	m.set_shader_parameter("belly", 0.62)
	m.set_shader_parameter("neck_z", -0.75)
	m.set_shader_parameter("stride", 0.5)
	m.set_shader_parameter("gait", 0.0)
	mi.material_override = m
	mi.extra_cull_margin = 0.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A stag of pure white with a crown of antlers, head towards -Z.
static func _stag_mesh(l: LowPoly) -> void:
	var white := Color(0.9, 0.9, 0.86)
	var shade := Color(0.72, 0.72, 0.7)
	l.box(Vector3(0, 1.05, 0.05), Vector3(0.5, 0.5, 1.25), white)
	l.box(Vector3(0, 1.25, -0.62), Vector3(0.26, 0.6, 0.3), white, Vector3(-28, 0, 0))
	l.box(Vector3(0, 1.62, -0.88), Vector3(0.24, 0.24, 0.42), white)
	l.box(Vector3(0, 1.56, -1.12), Vector3(0.14, 0.14, 0.14), shade)
	for x: float in [-1.0, 1.0]:
		l.box(Vector3(x * 0.1, 1.68, -0.97), Vector3(0.05, 0.05, 0.03), Color(0.5, 0.9, 1.0))
		l.prism(Vector3(x * 0.1, 1.74, -0.82), Vector3(x * 0.3, 2.2, -0.7), 0.03, 0.02, 4, BONE)
		l.prism(Vector3(x * 0.3, 2.2, -0.7), Vector3(x * 0.42, 2.55, -0.85), 0.02, 0.0, 4, BONE)
		l.prism(Vector3(x * 0.22, 2.0, -0.74), Vector3(x * 0.42, 2.1, -1.0), 0.018, 0.0, 4, BONE)
		l.prism(Vector3(x * 0.3, 2.2, -0.7), Vector3(x * 0.5, 2.36, -0.5), 0.018, 0.0, 4, BONE)
		l.box(Vector3(x * 0.18, 1.74, -0.76), Vector3(0.12, 0.06, 0.04), shade)
	for leg: Vector2 in [Vector2(-0.17, -0.45), Vector2(0.17, -0.45), Vector2(-0.17, 0.55), Vector2(0.17, 0.55)]:
		l.prism(Vector3(leg.x, 0.85, leg.y), Vector3(leg.x, 0.05, leg.y), 0.07, 0.04, 5, white)
		l.box(Vector3(leg.x, 0.04, leg.y), Vector3(0.08, 0.08, 0.1), Color(0.25, 0.22, 0.2))
	l.box(Vector3(0, 1.2, 0.72), Vector3(0.14, 0.2, 0.08), white)


## Standing up: the Shapeshifter's hulking second shape, half bear and half something older.
static func _were_parts(root: Node3D) -> void:
	var beast := _pivot(root, Vector3.ZERO, "Beast")
	var fur := Color(0.28, 0.2, 0.16)
	_part(beast, _mesh("were_torso", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.95, 0), Vector3(0, 1.85, 0.05), 0.42, 0.55, 7, fur)
		l.box(Vector3(0, 1.75, 0.12), Vector3(0.95, 0.45, 0.6), fur.lightened(0.05))
		l.box(Vector3(0, 1.35, 0.32), Vector3(0.5, 0.5, 0.12), MUZZLE.darkened(0.2))))
	var head := _pivot(beast, Vector3(0, 2.05, 0.22), "Head")
	_part(head, _mesh("were_head", func(l: LowPoly) -> void:
		l.box(Vector3(0, 0.1, 0.05), Vector3(0.5, 0.42, 0.5), fur)
		l.box(Vector3(0, 0.0, 0.38), Vector3(0.28, 0.22, 0.3), MUZZLE)
		l.box(Vector3(0, 0.06, 0.54), Vector3(0.1, 0.08, 0.04), BLACK)
		for x: float in [-1.0, 1.0]:
			l.box(Vector3(x * 0.2, 0.36, -0.02), Vector3(0.12, 0.12, 0.08), fur.darkened(0.2))
			l.prism(Vector3(x * 0.15, 0.3, -0.05), Vector3(x * 0.45, 0.75, -0.2), 0.03, 0.015, 4, BONE)
			l.prism(Vector3(x * 0.33, 0.55, -0.12), Vector3(x * 0.55, 0.62, 0.1), 0.015, 0.0, 4, BONE)))
	_part(head, _mesh("were_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.12, 0.12]:
			l.box(Vector3(x, 0.17, 0.31), Vector3(0.08, 0.04, 0.02), Color(0.6, 1.0, 0.85)))).material_override = glow_material()
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(beast, Vector3(side * 0.6, 1.8, 0.1), "ArmL" if side < 0 else "ArmR")
		_part(arm, _mesh("were_arm", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.7, 0.05), 0.17, 0.14, 6, fur)
			l.prism(Vector3(0, -0.7, 0.05), Vector3(0, -1.15, 0.2), 0.14, 0.12, 6, fur.darkened(0.1))
			for c in 3:
				l.prism(Vector3(-0.08 + c * 0.08, -1.18, 0.24), Vector3(-0.1 + c * 0.1, -1.42, 0.4), 0.03, 0.0, 4, CLAW)))
		var leg := _pivot(beast, Vector3(side * 0.26, 1.0, 0), "LegL" if side < 0 else "LegR")
		_part(leg, _mesh("were_leg", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.55, -0.08), 0.17, 0.14, 6, fur)
			l.prism(Vector3(0, -0.55, -0.08), Vector3(0, -0.95, 0.04), 0.13, 0.1, 6, fur.darkened(0.12))
			l.box(Vector3(0, -0.97, 0.12), Vector3(0.22, 0.08, 0.3), FUR_DARK)))


static func _earth_parts(root: Node3D, big: bool) -> void:
	var s := 2.0 if big else 1.0
	var body := _pivot(root, Vector3.ZERO, "Body")
	_part(body, _mesh("earth_torso", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.95, 0), Vector3(0, 1.75, 0.05), 0.5, 0.62, 6, STONE)
		l.box(Vector3(0.1, 1.85, 0.05), Vector3(1.05, 0.5, 0.75), STONE.lightened(0.06), Vector3(0, 12, 6))
		l.box(Vector3(-0.3, 1.25, 0.32), Vector3(0.4, 0.36, 0.2), STONE_DARK, Vector3(10, 20, 0))
		l.box(Vector3(0.25, 2.08, 0.1), Vector3(0.6, 0.12, 0.5), MOSS)
		l.box(Vector3(-0.35, 1.55, -0.3), Vector3(0.4, 0.22, 0.2), MOSS)
		for x: float in [-0.25, 0.25]:
			l.prism(Vector3(x, 0.95, 0), Vector3(x * 1.1, 0.05, 0.05), 0.24, 0.3, 5, STONE_DARK)), Vector3.ZERO).scale = Vector3.ONE * s
	var core := _part(body, _mesh("earth_core", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 1.3, 0.36), Vector3(0, 1.62, 0.38), 0.14, 0.08, 5, AMBER)
		l.box(Vector3(0, 2.32, 0.34), Vector3(0.36, 0.06, 0.04), AMBER)), Vector3.ZERO, "Core")
	core.material_override = glow_material()
	core.scale = Vector3.ONE * s
	_part(body, _mesh("earth_head", func(l: LowPoly) -> void:
		l.box(Vector3(0, 2.32, 0.08), Vector3(0.62, 0.48, 0.55), STONE, Vector3(0, 8, 0))
		l.box(Vector3(0, 2.6, 0.0), Vector3(0.5, 0.12, 0.4), MOSS)), Vector3.ZERO).scale = Vector3.ONE * s
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(body, Vector3(side * 0.82, 1.95, 0.05) * s, "ArmL" if side < 0 else "ArmR")
		var part := _part(arm, _mesh("earth_arm", func(l: LowPoly) -> void:
			l.box(Vector3(0, -0.25, 0), Vector3(0.42, 0.42, 0.42), STONE, Vector3(10, 30, 5))
			l.box(Vector3(0, -0.75, 0.05), Vector3(0.38, 0.4, 0.38), STONE_DARK, Vector3(-8, 12, 0))
			l.box(Vector3(0, -1.25, 0.1), Vector3(0.55, 0.5, 0.55), STONE, Vector3(5, 40, 10))
			l.box(Vector3(0.05, -1.0, 0.25), Vector3(0.2, 0.14, 0.1), MOSS)))
		part.scale = Vector3.ONE * s


static func _ring(l: LowPoly, radius: float, y: float, thick: float, col: Color, segments := 20) -> void:
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		l.prism(Vector3(cos(a) * radius, y, sin(a) * radius), Vector3(cos(b) * radius, y, sin(b) * radius), thick, thick, 4, col)


## Two bat wings that pivot at the shoulder, and a spiked tail.
static func _wyvern_parts(root: Node3D, armoured: bool) -> void:
	var s := 1.8 if armoured else 1.0
	var hide := SCALE_GREEN.darkened(0.15) if armoured else SCALE_GREEN
	var body := _pivot(root, Vector3.ZERO, "Body")
	body.scale = Vector3.ONE * s
	_part(body, _mesh("wyvern_body_%s" % armoured, func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.7), Vector3(0, 0.05, 0.55), 0.24, 0.34, 7, hide)
		l.box(Vector3(0, -0.2, 0.0), Vector3(0.4, 0.14, 0.9), SCALE_BELLY)
		l.prism(Vector3(0, 0.05, 0.55), Vector3(0, 0.38, 1.05), 0.2, 0.12, 6, hide)
		l.box(Vector3(0, 0.45, 1.25), Vector3(0.26, 0.24, 0.42), hide)
		l.box(Vector3(0, 0.38, 1.5), Vector3(0.2, 0.14, 0.24), hide.darkened(0.1))
		for x: float in [-1.0, 1.0]:
			l.box(Vector3(x * 0.1, 0.52, 1.38), Vector3(0.06, 0.04, 0.03), Color(1.0, 0.6, 0.1))
			l.prism(Vector3(x * 0.1, 0.58, 1.15), Vector3(x * 0.2, 0.8, 0.85), 0.04, 0.0, 4, BONE)
			l.prism(Vector3(x * 0.16, -0.18, 0.2), Vector3(x * 0.2, -0.6, 0.35), 0.07, 0.04, 5, hide)
			l.prism(Vector3(x * 0.2, -0.6, 0.35), Vector3(x * 0.2, -0.66, 0.52), 0.03, 0.0, 4, CLAW)
		for i in 4:
			l.prism(Vector3(0, 0.2, -0.4 + i * 0.3), Vector3(0, 0.38, -0.46 + i * 0.3), 0.06, 0.0, 4, BONE)
		if armoured:
			l.box(Vector3(0, 0.26, 0.05), Vector3(0.56, 0.12, 0.8), STEEL)
			l.box(Vector3(0, 0.55, 1.22), Vector3(0.3, 0.1, 0.34), STEEL)
			l.box(Vector3(0, 0.36, -0.1), Vector3(0.5, 0.08, 0.5), BANNER_RED)
			l.prism(Vector3(0, 0.3, -0.2), Vector3(0, 1.6, -0.35), 0.025, 0.025, 4, Color(0.35, 0.24, 0.14))
			l.box(Vector3(0.0, 1.3, -0.62), Vector3(0.02, 0.5, 0.55), BANNER_RED)
			l.box(Vector3(0.0, 1.3, -0.62), Vector3(0.03, 0.14, 0.2), GOLD)))
	var tail := _pivot(body, Vector3(0, 0.0, -0.7), "Tail")
	_part(tail, _mesh("wyvern_tail_%s" % armoured, func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, -0.05, -0.8), 0.16, 0.08, 5, hide)
		l.prism(Vector3(0, -0.05, -0.8), Vector3(0, -0.1, -1.5), 0.08, 0.03, 4, hide)
		l.prism(Vector3(0, -0.1, -1.45), Vector3(0, 0.02, -1.75), 0.1, 0.0, 4, BONE)))
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(body, Vector3(side * 0.22, 0.18, 0.25), "WingL" if side < 0 else "WingR")
		_part(wing, _mesh("wyvern_wing_%s_%s" % [armoured, side], func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(side * 0.9, 0.12, 0.1), 0.05, 0.04, 4, hide)
			l.prism(Vector3(side * 0.9, 0.12, 0.1), Vector3(side * 1.9, 0.0, -0.1), 0.04, 0.02, 4, hide)
			l.box(Vector3(side * 0.95, 0.02, -0.35), Vector3(1.9, 0.03, 0.8), WING)
			l.box(Vector3(side * 1.55, 0.0, -0.4), Vector3(0.75, 0.025, 0.6), WING.darkened(0.15))))
		root.set_meta("wing_l" if side < 0 else "wing_r", wing)


static func _eagle_parts(root: Node3D, misty: bool) -> void:
	var body_col := Color(0.62, 0.86, 0.9) if misty else Color(0.35, 0.24, 0.14)
	var head_col := Color(0.88, 0.98, 1.0) if misty else Color(0.94, 0.93, 0.88)
	var body := _part(root, _mesh("eagle_body_%s" % misty, func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, -0.32), Vector3(0, 0.02, 0.28), 0.1, 0.17, 6, body_col)
		l.prism(Vector3(0, 0.06, 0.28), Vector3(0, 0.1, 0.48), 0.13, 0.11, 6, head_col)
		l.prism(Vector3(0, 0.08, 0.48), Vector3(0, 0.0, 0.64), 0.06, 0.0, 4, Color(1.0, 0.78, 0.2))
		for x: float in [-0.08, 0.08]:
			l.box(Vector3(x, 0.15, 0.48), Vector3(0.03, 0.03, 0.02), Color(0.45, 0.95, 1.0) if misty else BLACK)
		l.box(Vector3(0, -0.02, -0.52), Vector3(0.3, 0.03, 0.32), head_col if not misty else body_col)
		for x: float in [-0.06, 0.06]:
			l.prism(Vector3(x, -0.12, 0.05), Vector3(x, -0.24, 0.12), 0.025, 0.02, 4, Color(1.0, 0.78, 0.2))))
	if misty:
		body.material_override = ghost_material()
	for side: float in [-1.0, 1.0]:
		var wing := _part(root, _mesh("eagle_wing_%s_%s" % [misty, side], func(l: LowPoly) -> void:
			l.box(Vector3(side * 0.42, 0, 0), Vector3(0.84, 0.03, 0.36), body_col)
			l.box(Vector3(side * 0.98, -0.02, -0.04), Vector3(0.42, 0.025, 0.3), body_col.darkened(0.2))
			for f in 4:
				l.box(Vector3(side * (1.22 + f * 0.02), -0.02, -0.14 + f * 0.08), Vector3(0.24, 0.02, 0.05), body_col.darkened(0.3))), Vector3(side * 0.08, 0.04, 0))
		if misty:
			wing.material_override = ghost_material()
		root.set_meta("wing_l" if side < 0 else "wing_r", wing)


## Returns the model. Named nodes and meta are what animate() moves.
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"bear":
			root.set_meta("body", _gaited(root, _mesh("bear", func(l: LowPoly) -> void: _bear_mesh(l, FUR, FUR_DARK, MUZZLE, BLACK)), 0.62, -0.75))
		"mist_bear":
			var body := _gaited(root, _mesh("mist_bear", func(l: LowPoly) -> void:
				_bear_mesh(l, MIST_FUR, MIST_FUR.darkened(0.3), MIST_FUR.lightened(0.2), MIST_GLOW)
				# Mist streaming off its back in pale stripes.
				for i in 4:
					l.box(Vector3(0, 1.38 - i * 0.03, -0.4 + i * 0.3), Vector3(0.5 - i * 0.06, 0.08, 0.16), MIST_GLOW.darkened(0.2))), 0.62, -0.75, 0.8)
			body.scale = Vector3.ONE * 1.0
			root.set_meta("body", body)
		"eagle", "mist_eagle":
			_eagle_parts(root, id == "mist_eagle")
		"shapeshifter":
			var stag_holder := _pivot(root, Vector3.ZERO, "Stag")
			root.set_meta("body", _gaited(stag_holder, _mesh("stag", func(l: LowPoly) -> void: _stag_mesh(l)), 0.85, -0.7))
			_were_parts(root)
			(root.get_node("Beast") as Node3D).visible = false
		"earth_elemental":
			_earth_parts(root, false)
		"great_revenant_elemental":
			_earth_parts(root, true)
			# Mist binds the boulders: pale bands around it, and loose stones that orbit once it is angry.
			var bands := _part(root, _mesh("revenant_bands", func(l: LowPoly) -> void:
				_ring(l, 1.3, 2.4, 0.05, MIST_GLOW)
				_ring(l, 1.15, 3.3, 0.05, MIST_GLOW)
				_ring(l, 0.8, 1.6, 0.04, MIST_GLOW)), Vector3.ZERO, "Bands")
			bands.material_override = glow_material()
			var orbit := _pivot(root, Vector3(0, 3.0, 0), "Orbit")
			for i in 5:
				var a := TAU * i / 5.0
				_part(orbit, _mesh("orbit_stone", func(l: LowPoly) -> void:
					l.box(Vector3.ZERO, Vector3(0.5, 0.42, 0.46), STONE, Vector3(20, 35, 10))
					l.box(Vector3(0, 0.22, 0), Vector3(0.3, 0.06, 0.3), MOSS)), Vector3(cos(a) * 2.2, sin(a * 2.0) * 0.4, sin(a) * 2.2))
			orbit.visible = false
			_label(root, 5.6)
		"mist_elemental":
			var core := _part(root, _mesh("mist_core", func(l: LowPoly) -> void:
				for i in 5:
					var a := TAU * i / 5.0
					l.prism(Vector3(0, 1.4, 0), Vector3(cos(a) * 0.32, 1.4 + sin(a * 3.0) * 0.3, sin(a) * 0.32), 0.09, 0.0, 4, BONE)
				l.prism(Vector3(0, 1.1, 0), Vector3(0, 1.75, 0), 0.0, 0.16, 5, BONE)
				l.prism(Vector3(0, 1.75, 0), Vector3(0, 2.05, 0), 0.16, 0.0, 5, Color(0.6, 1.0, 0.95))), Vector3.ZERO, "Core")
			core.material_override = glow_material()
			var swirl := _pivot(root, Vector3.ZERO, "Swirl")
			var shell := _part(swirl, _mesh("mist_shell", func(l: LowPoly) -> void:
				l.prism(Vector3(0, 0.25, 0), Vector3(0, 1.2, 0), 0.04, 0.55, 7, Color(0.55, 0.78, 0.82))
				l.prism(Vector3(0, 1.2, 0), Vector3(0, 2.1, 0), 0.55, 0.3, 7, Color(0.6, 0.85, 0.88))
				l.prism(Vector3(0, 2.1, 0), Vector3(0, 2.35, 0), 0.3, 0.0, 7, Color(0.7, 0.9, 0.92))))
			shell.material_override = ghost_material()
			var ribbons := _part(swirl, _mesh("mist_ribbons", func(l: LowPoly) -> void:
				for i in 3:
					var y := 0.8 + i * 0.5
					for seg in 14:
						var a := TAU * seg / 14.0 + i
						var b := TAU * (seg + 1) / 14.0 + i
						if seg % 4 == 3:
							continue
						var r := 0.7 + i * 0.05
						l.prism(Vector3(cos(a) * r, y + sin(a * 2.0) * 0.12, sin(a) * r), Vector3(cos(b) * r, y + sin(b * 2.0) * 0.12, sin(b) * r), 0.035, 0.035, 4, MIST_GLOW)), Vector3.ZERO, "Ribbons")
			ribbons.material_override = glow_material()
		"storm_elemental":
			var cloud := _pivot(root, Vector3.ZERO, "Cloud")
			_part(cloud, _mesh("storm_cloud", func(l: LowPoly) -> void:
				var grey := Color(0.32, 0.34, 0.4)
				l.prism(Vector3(0, 1.75, 0), Vector3(0, 2.3, 0), 0.6, 0.45, 7, grey)
				l.prism(Vector3(0.45, 1.85, 0.1), Vector3(0.45, 2.25, 0.1), 0.4, 0.3, 6, grey.lightened(0.08))
				l.prism(Vector3(-0.42, 1.8, -0.1), Vector3(-0.42, 2.2, -0.1), 0.42, 0.28, 6, grey.darkened(0.1))
				l.prism(Vector3(0.05, 2.25, -0.3), Vector3(0.05, 2.55, -0.3), 0.34, 0.18, 6, grey.lightened(0.15))
				l.prism(Vector3(0, 1.4, 0), Vector3(0, 1.75, 0), 0.2, 0.6, 7, grey.darkened(0.25))))
			var eyes := _part(cloud, _mesh("storm_eyes", func(l: LowPoly) -> void:
				for x: float in [-0.18, 0.18]:
					l.box(Vector3(x, 2.0, 0.56), Vector3(0.12, 0.05, 0.04), Color(0.85, 0.95, 1.0))), Vector3.ZERO)
			eyes.material_override = glow_material()
			var bolts := _part(cloud, _mesh("storm_bolts", func(l: LowPoly) -> void:
				var white := Color(0.9, 0.95, 1.0)
				for i in 3:
					var a := TAU * i / 3.0 + 0.4
					var pts := [Vector3(cos(a) * 0.4, 1.5, sin(a) * 0.4), Vector3(cos(a) * 0.55, 1.15, sin(a) * 0.5), Vector3(cos(a) * 0.4, 0.85, sin(a) * 0.62), Vector3(cos(a) * 0.62, 0.5, sin(a) * 0.55)]
					for p in 3:
						l.prism(pts[p], pts[p + 1], 0.03, 0.03, 4, white)), Vector3.ZERO, "Bolts")
			bolts.material_override = glow_material()
			var stones := _pivot(root, Vector3(0, 0.75, 0), "Stones")
			for i in 5:
				var a := TAU * i / 5.0
				_part(stones, _mesh("storm_stone", func(l: LowPoly) -> void:
					l.box(Vector3.ZERO, Vector3(0.26, 0.22, 0.24), STONE_DARK, Vector3(15, 25, 0))
					l.box(Vector3(0, 0.12, 0), Vector3(0.12, 0.04, 0.12), Color(0.6, 0.8, 1.0))), Vector3(cos(a) * 0.85, 0, sin(a) * 0.85))
		"wyvern":
			_wyvern_parts(root, false)
		"war_wyvern":
			_wyvern_parts(root, true)
			_label(root, 3.6)
	return root


static func _label(root: Node3D, high: float) -> void:
	var label := Label3D.new()
	label.name = "BossHealth"
	label.position.y = high
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.82, 0.5)
	label.outline_size = 8
	root.add_child(label)


# --- Movement ----------------------------------------------------------------------

## Called every frame with the creature's state (Zombie._current_anim) and how fast it moves.
static func animate(z: Zombie, root: Node3D, delta: float, moving: float) -> void:
	var t := z.world.now + float(z.net_id) * 0.37
	var state := z._current_anim
	var speed := clampf(moving / maxf(z._speed, 0.1), 0.0, 1.0) if moving > 0.0 else 0.0
	match z.model_id:
		"bear", "mist_bear":
			var body := root.get_meta("body") as MeshInstance3D
			set_gait(body, 1.0 if state == "m_charge" else speed)
			# Rearing tips it up on its hind legs; the maul brings it down hard.
			var pitch := 0.0
			if state == "m_rear":
				pitch = -0.75
			elif state == "m_swipe":
				pitch = 0.18
			body.rotation.x = lerpf(body.rotation.x, pitch, minf(1.0, delta * 9.0))
			body.position.y = lerpf(body.position.y, 0.35 if state == "m_rear" else 0.0, minf(1.0, delta * 9.0))
			body.position.z = lerpf(body.position.z, -0.4 if state == "m_rear" else 0.0, minf(1.0, delta * 9.0))
		"eagle", "mist_eagle", "wyvern", "war_wyvern":
			var rate := 3.0 if z.model_id.ends_with("eagle") else 1.6
			var beat := sin(t * rate * 2.0) * (0.85 if state != "m_breath" else 0.35)
			if z.is_warning() and z.model_id.ends_with("eagle"):
				beat = -1.1 # wings folded for the stoop
			(root.get_meta("wing_l") as Node3D).rotation.z = beat
			(root.get_meta("wing_r") as Node3D).rotation.z = -beat
			var body := root.get_node_or_null("Body") as Node3D
			if body:
				var tail := body.get_node("Tail") as Node3D
				tail.rotation.y = sin(t * 1.7) * 0.3
				body.rotation.x = lerpf(body.rotation.x, 0.35 if state == "m_breath" else 0.0, minf(1.0, delta * 5.0))
		"shapeshifter":
			var stag := root.get_node("Stag") as Node3D
			var beast := root.get_node("Beast") as Node3D
			var as_beast := state in ["m_beast", "m_swipe"]
			stag.visible = not as_beast and state != "m_shift"
			beast.visible = as_beast or (state == "m_shift" and fmod(t * 8.0, 1.0) > 0.5)
			if stag.visible:
				set_gait(root.get_meta("body") as MeshInstance3D, speed)
			if beast.visible:
				_walk_upright(beast, t, speed, state == "m_swipe")
		"earth_elemental", "great_revenant_elemental":
			var body := root.get_node("Body") as Node3D
			body.position.y = sin(t * 1.5) * 0.04
			var arm_l := body.get_node("ArmL") as Node3D
			var arm_r := body.get_node("ArmR") as Node3D
			var lift := 0.0
			if state == "m_slam":
				lift = -2.6 if z.is_warning() else 0.4
			elif state == "m_throw":
				lift = -2.2
			var swing := sin(t * 4.0) * 0.35 * speed
			arm_l.rotation.x = lerpf(arm_l.rotation.x, lift + swing, minf(1.0, delta * 8.0))
			arm_r.rotation.x = lerpf(arm_r.rotation.x, lift - swing if state != "m_throw" else 0.2, minf(1.0, delta * 8.0))
			body.rotation.z = sin(t * 2.0) * 0.04 * speed
			var orbit := root.get_node_or_null("Orbit") as Node3D
			if orbit:
				orbit.visible = state in ["m_beast", "m_throw", "m_slam"] and z.hp < z.max_hp * 0.5
				orbit.rotation.y = t * 0.9
			_boss_label(z, root)
		"mist_elemental":
			root.position.y = 0.25 + sin(t * 2.2) * 0.12
			(root.get_node("Swirl") as Node3D).rotation.y = t * 1.6
			(root.get_node("Swirl/Ribbons") as Node3D).rotation.y = -t * 2.4
			var fade := 0.2 if state == "m_blink" else 1.0
			root.scale = root.scale.lerp(Vector3.ONE * fade, minf(1.0, delta * 10.0))
		"storm_elemental":
			root.position.y = 0.2 + sin(t * 1.8) * 0.1
			(root.get_node("Stones") as Node3D).rotation.y = t * (2.5 if state == "m_cast" else 0.9)
			var bolts := root.get_node("Cloud/Bolts") as Node3D
			bolts.visible = state == "m_cast" or fmod(t * 3.7, 1.0) > 0.82
			bolts.rotation.y = floor(t * 9.0) * 1.3
			(root.get_node("Cloud") as Node3D).position.y = 0.3 if state == "m_cast" else 0.0
	if z.model_id == "war_wyvern":
		_boss_label(z, root)


static func _walk_upright(beast: Node3D, t: float, speed: float, swiping: bool) -> void:
	var step := sin(t * 8.0) * 0.6 * speed
	(beast.get_node("LegL") as Node3D).rotation.x = step
	(beast.get_node("LegR") as Node3D).rotation.x = -step
	var arm_l := beast.get_node("ArmL") as Node3D
	var arm_r := beast.get_node("ArmR") as Node3D
	if swiping:
		arm_r.rotation.x = -1.9
		arm_l.rotation.x = -1.2
	else:
		arm_l.rotation.x = -step * 0.6 - 0.2
		arm_r.rotation.x = step * 0.6 - 0.2
	beast.rotation.x = 0.12 * speed


static func _boss_label(z: Zombie, root: Node3D) -> void:
	var label := root.get_node_or_null("BossHealth") as Label3D
	if label == null:
		return
	var fraction := z.hp / maxf(z.max_hp, 1.0)
	label.text = "%s • %d%%" % [BOSS_NAMES.get(z.model_id, ""), ceili(fraction * 100.0)]
	label.modulate = Color(1.0, 0.45, 0.3) if fraction <= 0.5 else Color(1.0, 0.82, 0.5)


# --- Children of the Woods --------------------------------------------------------------

## What a Child of the Woods wears over a small body: a hood of leaves with twig antlers, a bark mask
## with green eyes, and a mantle of leaves. Keys are bone names.
static func child_gear() -> Dictionary:
	return {
		"head": _mesh("child_head", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.45, -0.05), Vector3(0, 1.05, -0.12), 0.68, 0.36, 8, LEAF)
			l.prism(Vector3(0, 1.05, -0.12), Vector3(0, 1.1, -0.5), 0.3, 0.04, 6, LEAF_DARK)
			for i in 6:
				var a := TAU * i / 6.0
				l.leaf(Vector3(cos(a) * 0.62, 0.7, sin(a) * 0.62 - 0.05), Vector3(cos(a) * 0.82, 0.48, sin(a) * 0.82 - 0.05), Vector3(cos(a + 0.4) * 0.66, 0.5, sin(a + 0.4) * 0.66), LEAF_DARK)
			l.box(Vector3(0, 0.42, 0.56), Vector3(0.82, 0.48, 0.1), BARK)
			l.box(Vector3(0, 0.2, 0.6), Vector3(0.3, 0.12, 0.06), BARK.darkened(0.2))
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.2, 1.0, -0.05), Vector3(x * 0.45, 1.45, -0.15), 0.035, 0.02, 4, BARK)
				l.prism(Vector3(x * 0.38, 1.3, -0.12), Vector3(x * 0.6, 1.4, 0.02), 0.02, 0.0, 4, BARK)
				l.prism(Vector3(x * 0.3, 1.2, -0.1), Vector3(x * 0.3, 1.52, -0.2), 0.018, 0.0, 4, BARK)),
		"chest": _mesh("child_chest", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.4, 0), Vector3(0, -0.1, 0), 0.45, 0.66, 8, LEAF_DARK)
			for i in 8:
				var a := TAU * i / 8.0
				l.leaf(Vector3(cos(a) * 0.58, -0.05, sin(a) * 0.58), Vector3(cos(a) * 0.7, -0.4, sin(a) * 0.7), Vector3(cos(a + 0.35) * 0.6, -0.3, sin(a + 0.35) * 0.6), LEAF)),
	}


static func child_eyes() -> Mesh:
	return _mesh("child_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.17, 0.17]:
			l.box(Vector3(x, 0.47, 0.62), Vector3(0.11, 0.06, 0.03), Color(0.62, 1.0, 0.45)))
