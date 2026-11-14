class_name MesenllaModels
extends RefCounted
## The creatures of the Valleys of Mesenlla and Mist Bastion: low-poly bodies built from code, and the
## light animation that moves them. All of them are parts on pivots; the bear a Child of the Woods
## rides is the one body that still walks in beast_gait.gdshader, like a horse. Each model is a root
## facing +Z; what the animation needs is kept as meta.
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


# --- Four legs on joints ------------------------------------------------------------

## A four-legged creature put together from parts on pivots, facing +Z, so it can walk, rear, maul,
## charge and fall over. The nodes:
##   Rig            the whole animal; it rolls over when it dies
##     Hind         at the hind hips: rearing tips everything above them up
##       Torso      the body, the neck and the head ("Head"), and the forelegs
##     LegBL, LegBR the hind legs, which stay on the ground when it rears
## Each leg is a pivot at the hip or shoulder with its "Knee" below.
static func _quadruped(root: Node3D, key: String, look: Dictionary) -> void:
	var rig := _pivot(root, Vector3.ZERO, "Rig")
	var hip: Vector3 = look["hip"]
	var hind := _pivot(rig, hip, "Hind")
	var torso := _pivot(hind, Vector3.ZERO, "Torso")
	var body := _part(torso, _mesh(key + "_torso", look["torso"]), -hip)
	var head := _pivot(torso, Vector3(look["neck"]) - hip, "Head")
	var head_mesh := _part(head, _mesh(key + "_head", look["head"]))
	var material: Material = look.get("material", null)
	for part in [body, head_mesh]:
		part.material_override = material
	if look.has("eyes"):
		_part(head, _mesh(key + "_eyes", look["eyes"])).material_override = glow_material()
	if look.has("glow"):
		_part(torso, _mesh(key + "_glow", look["glow"]), -hip).material_override = glow_material()
	var shoulder: Vector3 = look["shoulder"]
	for side: float in [-1.0, 1.0]:
		var w: float = look["width"] * side
		for front: bool in [true, false]:
			var at := Vector3(w, shoulder.y, shoulder.z) if front else Vector3(w, hip.y, hip.z)
			var parent: Node3D = torso if front else rig
			var leg := _pivot(parent, at - hip if front else at, "Leg%s%s" % ["F" if front else "B", "L" if side < 0 else "R"])
			var upper := _part(leg, _mesh("%s_upper_%s" % [key, front], look["upper_front" if front else "upper_hind"]))
			var knee := _pivot(leg, Vector3(0, -float(look["upper_len"]), 0), "Knee")
			var lower := _part(knee, _mesh("%s_lower_%s" % [key, front], look["lower"]))
			upper.material_override = material
			lower.material_override = material
	root.set_meta("legs", ["LegFL", "LegFR", "LegBL", "LegBR"])


## A bear's parts, facing +Z: a deep barrel of a body with a hump over the shoulders, a heavy head
## with a short muzzle and round ears, thick legs and pale claws.
static func _bear_look(fur: Color, dark: Color, muzzle: Color, eye: Color, misty: bool) -> Dictionary:
	var look := {
		"hip": Vector3(0, 0.76, -0.55), "shoulder": Vector3(0, 0.78, 0.48), "neck": Vector3(0, 0.98, 0.74), "width": 0.27, "upper_len": 0.36,
		"torso": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.86, -0.82), Vector3(0, 0.92, 0.3), 0.42, 0.5, 8, fur)
			l.prism(Vector3(0, 0.92, 0.3), Vector3(0, 0.9, 0.7), 0.5, 0.4, 8, fur.lightened(0.04))
			l.prism(Vector3(0, 1.08, 0.08), Vector3(0, 1.12, 0.55), 0.3, 0.26, 7, fur.darkened(0.04))
			l.box(Vector3(0, 0.62, 0.0), Vector3(0.62, 0.2, 1.0), dark)
			l.prism(Vector3(0, 0.98, -0.82), Vector3(0, 0.92, -0.98), 0.1, 0.04, 5, dark),
		"head": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, -0.12), Vector3(0, 0.04, 0.24), 0.26, 0.24, 8, fur)
			l.prism(Vector3(0, -0.04, 0.24), Vector3(0, -0.08, 0.5), 0.15, 0.1, 7, muzzle)
			l.box(Vector3(0, -0.02, 0.52), Vector3(0.12, 0.08, 0.05), BLACK)
			l.box(Vector3(0, -0.15, 0.36), Vector3(0.16, 0.05, 0.14), dark)
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.15, 0.2, 0.02), Vector3(x * 0.18, 0.31, 0.0), 0.07, 0.05, 6, dark),
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-0.11, 0.11]:
				l.box(Vector3(x, 0.08, 0.27), Vector3(0.05, 0.05, 0.03), eye),
		"upper_front": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.1, 0), Vector3(0, -0.38, 0.02), 0.17, 0.13, 7, fur.darkened(0.08)),
		"upper_hind": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.12, -0.04), Vector3(0, -0.38, 0.04), 0.2, 0.13, 7, fur.darkened(0.06)),
		"lower": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.02, 0), Vector3(0, -0.3, 0.02), 0.13, 0.11, 7, dark)
			l.box(Vector3(0, -0.35, 0.06), Vector3(0.24, 0.09, 0.3), dark.darkened(0.12))
			for c in 3:
				l.prism(Vector3(-0.08 + c * 0.08, -0.36, 0.2), Vector3(-0.08 + c * 0.08, -0.39, 0.29), 0.025, 0.0, 4, CLAW),
	}
	if misty:
		look["glow"] = func(l: LowPoly) -> void:
			# Mist streaming off its back in pale stripes.
			for i in 4:
				l.box(Vector3(0, 1.34 - i * 0.03, 0.45 - i * 0.3), Vector3(0.46 - i * 0.06, 0.05, 0.12), MIST_GLOW.darkened(0.25))
		look["material"] = mist_body_material()
	return look


## The Shapeshifter's first shape: a stag of pure white on long legs, with a crown of antlers.
static func _stag_look() -> Dictionary:
	var white := Color(0.9, 0.9, 0.86)
	var shade := Color(0.74, 0.74, 0.72)
	var hoof := Color(0.25, 0.22, 0.2)
	return {
		"hip": Vector3(0, 1.0, -0.5), "shoulder": Vector3(0, 1.0, 0.45), "neck": Vector3(0, 1.55, 0.78), "width": 0.16, "upper_len": 0.46,
		"torso": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 1.06, -0.66), Vector3(0, 1.1, 0.58), 0.25, 0.28, 7, white)
			l.prism(Vector3(0, 1.12, 0.5), Vector3(0, 1.55, 0.78), 0.17, 0.12, 6, white)
			l.box(Vector3(0, 0.92, 0.0), Vector3(0.3, 0.12, 0.9), shade)
			l.prism(Vector3(0, 1.2, -0.66), Vector3(0, 1.05, -0.82), 0.08, 0.02, 5, white),
		"head": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.04, -0.1), Vector3(0, 0.0, 0.2), 0.13, 0.11, 7, white)
			l.prism(Vector3(0, 0.0, 0.2), Vector3(0, -0.06, 0.42), 0.1, 0.06, 6, shade)
			l.box(Vector3(0, -0.04, 0.43), Vector3(0.06, 0.05, 0.03), BLACK)
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.1, 0.12, -0.04), Vector3(x * 0.26, 0.2, -0.1), 0.05, 0.02, 4, shade)
				l.prism(Vector3(x * 0.07, 0.14, 0.0), Vector3(x * 0.25, 0.58, -0.1), 0.03, 0.022, 4, BONE)
				l.prism(Vector3(x * 0.25, 0.58, -0.1), Vector3(x * 0.38, 0.92, -0.28), 0.022, 0.0, 4, BONE)
				l.prism(Vector3(x * 0.17, 0.38, -0.05), Vector3(x * 0.38, 0.48, 0.16), 0.018, 0.0, 4, BONE)
				l.prism(Vector3(x * 0.25, 0.58, -0.1), Vector3(x * 0.46, 0.72, 0.08), 0.018, 0.0, 4, BONE)
				l.prism(Vector3(x * 0.31, 0.75, -0.18), Vector3(x * 0.5, 0.86, -0.06), 0.015, 0.0, 4, BONE),
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-0.1, 0.1]:
				l.box(Vector3(x, 0.08, 0.14), Vector3(0.04, 0.04, 0.03), Color(0.5, 0.9, 1.0)),
		"upper_front": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.08, 0), Vector3(0, -0.48, 0.02), 0.08, 0.05, 6, white),
		"upper_hind": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.1, -0.06), Vector3(0, -0.48, -0.02), 0.12, 0.05, 6, white),
		"lower": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, 0), Vector3(0, -0.46, 0.0), 0.045, 0.035, 5, white)
			l.box(Vector3(0, -0.5, 0.02), Vector3(0.08, 0.08, 0.1), hoof),
	}


## Mist made flesh, opaque but glowing at the edges like the mist creatures: the Mist Bear.
static var _mist_body: StandardMaterial3D


static func mist_body_material() -> StandardMaterial3D:
	if _mist_body == null:
		_mist_body = StandardMaterial3D.new()
		_mist_body.vertex_color_use_as_albedo = true
		_mist_body.emission_enabled = true
		_mist_body.emission = Color(0.1, 0.26, 0.3)
		_mist_body.rim_enabled = true
		_mist_body.rim = 1.0
		_mist_body.rim_tint = 0.2
	return _mist_body


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
	if armoured:
		_riders(root, body)


## Two Children of the Woods ride the War Wyvern, one behind the other, each with a short bow.
## Their bows are drawn in turn; the arrows are shot in MesenllaMind.
static var _rider_scene: PackedScene
const RIDER_SEATS := [Vector3(0, 0.12, 0.52), Vector3(0, 0.12, 0.12)]
const RIDER_SIZE := 0.62 # of a Child of the Woods standing on the ground, before the wyvern's own size


static func _riders(root: Node3D, body: Node3D) -> void:
	if _rider_scene == null:
		_rider_scene = load("res://assets/characters/normal_b.glb")
	var riders: Array[Node3D] = []
	for i in RIDER_SEATS.size():
		var rider := _rider_scene.instantiate() as Node3D
		rider.name = "Rider%d" % i
		rider.position = RIDER_SEATS[i]
		rider.scale = Vector3.ONE * RIDER_SIZE / body.scale.x
		body.add_child(rider)
		var skeleton: Skeleton3D = rider.find_children("*", "Skeleton3D", true, false)[0]
		var gear := child_gear()
		gear["head2"] = child_eyes()
		for key: String in gear:
			var at := BoneAttachment3D.new()
			at.bone_name = "head" if key == "head2" else key
			skeleton.add_child(at)
			var mi := MeshInstance3D.new()
			mi.mesh = gear[key]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if key == "head2":
				mi.material_override = glow_material()
			at.add_child(mi)
		var hand := BoneAttachment3D.new()
		hand.bone_name = "handslot.r"
		skeleton.add_child(hand)
		var bow := MeshInstance3D.new()
		bow.mesh = _mesh("rider_bow", func(l: LowPoly) -> void:
			# A short bow of bent wood, held upright, with its string.
			var pts := [Vector3(0, -0.8, -0.14), Vector3(0, -0.45, 0.02), Vector3(0, 0.0, 0.08), Vector3(0, 0.45, 0.02), Vector3(0, 0.8, -0.14)]
			for k in pts.size() - 1:
				l.prism(pts[k], pts[k + 1], 0.06, 0.06, 5, BARK)
			l.prism(pts[0], pts[pts.size() - 1], 0.008, 0.008, 3, BONE)
			l.box(Vector3(0, 0, 0.07), Vector3(0.07, 0.16, 0.07), LEAF_DARK))
		bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bow.rotation = Vector3(PI * 0.5, 0, 0) # upright in the outstretched hand
		hand.add_child(bow)
		for mi in rider.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var anim: AnimationPlayer = rider.find_children("*", "AnimationPlayer", true, false)[0]
		BodyAnim.install(anim, skeleton)
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		anim.play("RideShoot")
		rider.set_meta("anim", anim)
		riders.append(rider)
	root.set_meta("riders", riders)


## Where a rider's arrow starts, and when (seconds into the shared clock) each rider looses: the
## second rider shoots half a cycle after the first.
static func rider_cycle(i: int, now: float) -> float:
	return fmod(now + i * BodyAnim.RIDE_SHOT * 0.5, BodyAnim.RIDE_SHOT)


## The riders draw and loose in time with the world's clock, so every phone shows the same, and turn
## in the saddle towards the nearest player.
static func _animate_riders(z: Zombie, root: Node3D) -> void:
	var riders: Array = root.get_meta("riders", [])
	var aim: Vector3 = Vector3.INF
	var p := z.world.nearest_player(z.position) if z.world else null
	if p:
		aim = p.global_position
	for i in riders.size():
		var rider := riders[i] as Node3D
		var anim := rider.get_meta("anim") as AnimationPlayer
		if anim.current_animation != "RideShoot":
			anim.play("RideShoot") # (playing before the body was in the scene does not take)
		anim.seek(rider_cycle(i, z.world.now), true)
		if aim != Vector3.INF:
			var local := (rider.get_parent() as Node3D).to_local(aim)
			var yaw := clampf(atan2(local.x, local.z), -1.3, 1.3)
			rider.rotation.y = lerp_angle(rider.rotation.y, yaw, 0.15)


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


## The Shapeshifter's white stag as a Cavalry rider's steed (the White Stag cosmetic): facing -Z like
## the horse, sized so its back is where the horse's saddle is. scale_to: the horse's own size.
static func stag_steed(scale_to := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "StagSteed"
	var holder := _pivot(root, Vector3.ZERO, "Stag")
	_quadruped(holder, "stag", _stag_look())
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * 1.12 * scale_to
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("legs", ["LegFL", "LegFR", "LegBL", "LegBR"].map(func(n: String) -> Node3D: return root.find_child(n, true, false) as Node3D))
	return root


## The stag steed's legs swinging, faster and wider the faster it goes (gait 0..1).
static func steed_gait(root: Node3D, gait: float) -> void:
	var t := Time.get_ticks_msec() * 0.016
	var legs: Array = root.get_meta("legs", [])
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(t + (0.0 if i % 3 == 0 else PI)) * 0.7 * clampf(gait, 0.05, 1.0)


## Returns the model. Named nodes and meta are what animate() moves.
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"bear":
			_quadruped(root, "bear", _bear_look(FUR, FUR_DARK, MUZZLE, BLACK, false))
		"mist_bear":
			_quadruped(root, "mist_bear", _bear_look(MIST_FUR, MIST_FUR.darkened(0.3), MIST_FUR.lightened(0.2), MIST_GLOW, true))
		"eagle", "mist_eagle":
			_eagle_parts(root, id == "mist_eagle")
		"shapeshifter":
			var stag_holder := _pivot(root, Vector3.ZERO, "Stag")
			_quadruped(stag_holder, "stag", _stag_look())
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
	# How long it has been in this state, for moves that play out over time (a maul, a slash).
	if state != str(root.get_meta("act_state", "")):
		root.set_meta("act_state", state)
		root.set_meta("act_t", 0.0)
	else:
		root.set_meta("act_t", float(root.get_meta("act_t", 0.0)) + delta)
	var speed := clampf(moving / maxf(z._speed, 0.1), 0.0, 1.0) if moving > 0.0 else 0.0
	match z.model_id:
		"bear", "mist_bear":
			_animate_quadruped(z, root, delta, speed, state, false)
		"eagle", "mist_eagle", "wyvern", "war_wyvern":
			var rate := 3.0 if z.model_id.ends_with("eagle") else 1.6
			var beat := sin(t * rate * 2.0) * (0.85 if state != "m_breath" else 0.35)
			if z.is_warning() and z.model_id.ends_with("eagle"):
				beat = -1.1 # wings folded for the stoop
			(root.get_meta("wing_l") as Node3D).rotation.z = beat
			(root.get_meta("wing_r") as Node3D).rotation.z = -beat
			# A wyvern's wings are heard on each downstroke, on this phone only.
			if z.model_id.ends_with("wyvern") and z.world.player:
				var was := float(root.get_meta("beat", 0.0))
				root.set_meta("beat", beat)
				if was > 0.0 and beat <= 0.0:
					Sfx.play_at("wing_flap", z.position, z.world.player.global_position, -9.0 if z.model_id == "war_wyvern" else -13.0)
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
				_animate_quadruped(z, stag, delta, speed, state, true)
			if beast.visible:
				_walk_upright(beast, t, speed, state == "m_swipe", float(root.get_meta("act_t", 0.0)), delta)
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
		_animate_riders(z, root)


## Walking, trotting or galloping on four legs, rearing up, mauling and charging. Each leg swings
## from the hip and folds at the knee while it comes forward, so the paws lift off the ground.
static func _animate_quadruped(z: Zombie, root: Node3D, delta: float, speed: float, state: String, light: bool) -> void:
	var rig := root.get_node("Rig") as Node3D
	var hind := rig.get_node("Hind") as Node3D
	var torso := hind.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var k := minf(1.0, delta * 10.0)
	var charging := state == "m_charge"
	var gait := 1.0 if charging else speed
	# The legs' clock runs faster the faster it goes, and keeps its place between frames.
	var pace := lerpf(5.5, 9.0, gait) if not light else lerpf(6.5, 10.5, gait)
	var phase := float(root.get_meta("phase", randf() * TAU)) + delta * pace * (0.25 + gait)
	root.set_meta("phase", fmod(phase, TAU * 8.0))
	var amp := lerpf(0.0, 0.55, gait) if not charging else 0.8
	var offsets := {"LegFL": 0.0, "LegBR": PI * 0.5 if not charging else PI, "LegFR": PI if not charging else 0.25, "LegBL": PI * 1.5 if not charging else PI + 0.25}
	var rear := 0.0
	var head_pitch := sin(phase * 2.0) * 0.06 * gait
	var bob := absf(sin(phase)) * 0.05 * gait
	if state == "m_rear":
		rear = -0.95
		head_pitch = -0.45
		bob = 0.0
	elif state == "m_swipe":
		# The maul: forepaws flung up, then brought down hard with the head lunging after them.
		var act := float(root.get_meta("act_t", 0.0))
		rear = -0.4 if act < 0.12 else 0.16
		head_pitch = -0.2 if act < 0.12 else 0.4
		bob = 0.0
	elif charging:
		head_pitch = 0.22
	else:
		# Breathing while it stands.
		torso.scale = Vector3.ONE * (1.0 + sin(z.world.now * 2.2 + float(z.net_id)) * 0.012 * (1.0 - gait))
	hind.rotation.x = lerpf(hind.rotation.x, rear, minf(1.0, delta * (16.0 if state == "m_swipe" else 7.0)))
	# Lower at the ends of each stride, when the legs reach out furthest.
	rig.position.y = lerpf(rig.position.y, -bob if state != "m_rear" else 0.0, k)
	rig.rotation.x = lerpf(rig.rotation.x, sin(phase * 2.0) * 0.05 if charging else 0.0, k)
	head.rotation.x = lerpf(head.rotation.x, head_pitch, k)
	head.rotation.y = lerpf(head.rotation.y, sin(z.world.now * 0.7 + float(z.net_id)) * 0.25 * (1.0 - gait), minf(1.0, delta * 3.0))
	for leg_name: String in offsets:
		var leg := (torso if leg_name.begins_with("LegF") else rig).get_node(leg_name) as Node3D
		var knee := leg.get_node("Knee") as Node3D
		var front := leg_name.begins_with("LegF")
		var swing := 0.0
		var fold := 0.0
		if state == "m_rear" and front:
			# Up on its hind legs, the forepaws claw at the air.
			swing = -0.7 + sin(z.world.now * 9.0 + (0.0 if leg_name == "LegFL" else 1.6)) * 0.35
			fold = 0.9
		elif state == "m_swipe" and front:
			var act := float(root.get_meta("act_t", 0.0))
			swing = -1.35 if act < 0.12 else -0.35 + (0.12 if leg_name == "LegFL" else -0.05)
			fold = 1.0 if act < 0.12 else 0.0
		else:
			var a: float = phase + float(offsets[leg_name])
			swing = -sin(a) * amp
			# Folded while the leg comes forward, straight while it carries the weight.
			fold = maxf(0.0, cos(a)) * amp * (1.5 if front else 1.1)
			if not front:
				fold *= 0.8
		leg.rotation.x = lerpf(leg.rotation.x, swing, minf(1.0, delta * 18.0))
		knee.rotation.x = lerpf(knee.rotation.x, fold, minf(1.0, delta * 18.0))


## The beast on two legs: a heavy stride with the arms swinging, and a slash that winds up over the
## shoulder, twists through the body and rakes down and across.
static func _walk_upright(beast: Node3D, t: float, speed: float, swiping: bool, act: float, delta: float) -> void:
	var step := sin(t * 7.0) * 0.6 * speed
	var leg_l := beast.get_node("LegL") as Node3D
	var leg_r := beast.get_node("LegR") as Node3D
	var arm_l := beast.get_node("ArmL") as Node3D
	var arm_r := beast.get_node("ArmR") as Node3D
	var head := beast.get_node("Head") as Node3D
	var k := minf(1.0, delta * 20.0)
	var target := {"arm_l": Vector3(-step * 0.6 - 0.2, 0, 0.15), "arm_r": Vector3(step * 0.6 - 0.2, 0, -0.15), "lean": 0.12 * speed, "twist": 0.0, "head": 0.0}
	if swiping:
		if act < 0.16:
			# Wind up: the right arm high and back, the body turning away.
			target = {"arm_l": Vector3(-0.9, 0, 0.4), "arm_r": Vector3(-2.7, 0, -0.5), "lean": -0.15, "twist": -0.45, "head": -0.2}
		elif act < 0.34:
			# The rake: down and across, the body coming round behind it.
			target = {"arm_l": Vector3(-0.4, 0, 0.3), "arm_r": Vector3(0.35, 0, 0.6), "lean": 0.35, "twist": 0.4, "head": 0.25}
		else:
			target = {"arm_l": Vector3(-0.5, 0, 0.25), "arm_r": Vector3(0.1, 0, 0.3), "lean": 0.25, "twist": 0.2, "head": 0.15}
		step = 0.0
	leg_l.rotation.x = lerpf(leg_l.rotation.x, step if not swiping else 0.35, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -step if not swiping else -0.3, k)
	var al: Vector3 = target["arm_l"]
	var ar: Vector3 = target["arm_r"]
	arm_l.rotation = arm_l.rotation.lerp(al, k)
	arm_r.rotation = arm_r.rotation.lerp(ar, k)
	beast.rotation.x = lerpf(beast.rotation.x, float(target["lean"]), k)
	beast.rotation.y = lerpf(beast.rotation.y, float(target["twist"]), k)
	head.rotation.x = lerpf(head.rotation.x, float(target["head"]), k)
	# A heavy body bobs with each step.
	beast.position.y = -absf(sin(t * 7.0)) * 0.06 * speed


# --- Falling ----------------------------------------------------------------------------

## Every pivot and part where the body was built, so a body that fell can stand up again when the
## same creature is used again.
static func remember_pose(root: Node3D) -> void:
	root.set_meta("rest", root.transform)
	for n in root.find_children("*", "Node3D", true, false):
		(n as Node3D).set_meta("rest", (n as Node3D).transform)


static func reset_pose(root: Node3D) -> void:
	root.transform = root.get_meta("rest", root.transform)
	for n in root.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		if node.has_meta("rest"):
			node.transform = node.get_meta("rest")
		node.remove_meta("fall")
		if node is MeshInstance3D or node is Label3D:
			node.visible = true
	root.remove_meta("side")
	# The Shapeshifter stands as a stag again, the Revenant's stones are still.
	var beast := root.get_node_or_null("Beast") as Node3D
	if beast:
		beast.visible = false
	var orbit := root.get_node_or_null("Orbit") as Node3D
	if orbit:
		orbit.visible = false


## How long each kind takes to die before the body is gone.
static func death_time(id: String) -> float:
	match id:
		"great_revenant_elemental", "war_wyvern":
			return 3.2
		"mist_elemental", "storm_elemental":
			return 1.8
	return 2.6


## The moment it dies: which way it falls, and the boss's name taken down.
static func begin_death(z: Zombie, root: Node3D) -> void:
	root.set_meta("side", -1.0 if randf() < 0.5 else 1.0)
	var label := root.get_node_or_null("BossHealth") as Label3D
	if label:
		label.visible = false
	var as_beast := false
	var beast := root.get_node_or_null("Beast") as Node3D
	if beast and beast.visible:
		as_beast = true
	root.set_meta("as_beast", as_beast)
	var stag := root.get_node_or_null("Stag") as Node3D
	if stag:
		stag.visible = not as_beast
	# Pieces that come apart: their own way out and their own spin.
	var loose: Array[Node3D] = []
	match z.model_id:
		"earth_elemental", "great_revenant_elemental":
			var body := root.get_node("Body") as Node3D
			for n in body.get_children():
				loose.append(n as Node3D)
			var orbit := root.get_node_or_null("Orbit") as Node3D
			if orbit:
				for n in orbit.get_children():
					loose.append(n as Node3D)
		"storm_elemental":
			for n in root.get_node("Stones").get_children():
				loose.append(n as Node3D)
	var size := 2.0 if z.model_id == "great_revenant_elemental" else 1.0
	for piece in loose:
		var out := Vector3(piece.position.x, 0.0, piece.position.z)
		out = out.normalized() if out.length() > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		piece.set_meta("fall", {"v": out * randf_range(0.6, 1.6) * size + Vector3.UP * randf_range(0.5, 1.8) * size,
			"spin": Vector3(randf_range(-4, 4), randf_range(-3, 3), randf_range(-4, 4)), "rest": false, "delay": randf_range(0.0, 0.35)})


## Each frame of a death, k seconds after it began.
static func animate_death(z: Zombie, root: Node3D, k: float, delta: float) -> void:
	var side := float(root.get_meta("side", 1.0))
	var total := death_time(z.model_id)
	# The last moments: the body sinks into the ground and is gone.
	var sink := clampf((k - (total - 0.7)) / 0.7, 0.0, 1.0)
	match z.model_id:
		"bear", "mist_bear":
			_fall_quadruped(root, k, side, 0.5)
			root.position.y = -sink * 1.0
		"shapeshifter":
			if root.get_meta("as_beast", false):
				_fall_upright(root.get_node("Beast") as Node3D, k, side)
			else:
				_fall_quadruped(root.get_node("Stag") as Node3D, k, side, 0.32)
			root.position.y = -sink * 1.2
		"eagle", "mist_eagle", "wyvern", "war_wyvern":
			_fall_flyer(z, root, k, delta, side)
			root.position.y -= sink * delta * 1.6
		"earth_elemental", "great_revenant_elemental":
			_crumble(z, root, k, delta)
			var bands := root.get_node_or_null("Bands") as Node3D
			if bands:
				bands.scale = Vector3.ONE * maxf(0.01, 1.0 - k * 1.2)
				bands.rotation.y += delta * 3.0
			root.position.y = -sink * 0.8
		"mist_elemental":
			# Spun apart: the swirl whirls faster and wider, rises and thins to nothing.
			var swirl := root.get_node("Swirl") as Node3D
			swirl.rotation.y += delta * (3.0 + k * 14.0)
			swirl.scale = Vector3.ONE * (1.0 + k * 0.9)
			(root.get_node("Swirl/Ribbons") as Node3D).rotation.y -= delta * 8.0
			(root.get_node("Core") as Node3D).scale = Vector3.ONE * maxf(0.01, 1.0 - k * 1.4)
			root.position.y += delta * 0.9
			root.scale = Vector3.ONE * maxf(0.01, 1.0 - clampf((k - 0.5) / 1.2, 0.0, 1.0))
		"storm_elemental":
			# It bursts: the cloud swells and tears, lightning flickers, the stones fall.
			var cloud := root.get_node("Cloud") as Node3D
			var swell := 1.0 + minf(k, 0.35) * 1.6
			cloud.scale = Vector3.ONE * swell * maxf(0.01, 1.0 - clampf((k - 0.5) / 1.0, 0.0, 1.0))
			cloud.rotation.y += delta * 5.0
			var bolts := cloud.get_node("Bolts") as Node3D
			bolts.visible = k < 1.1 and fmod(k * 13.0, 1.0) > 0.4
			bolts.rotation.y = floor(k * 17.0) * 1.7
			for stone in root.get_node("Stones").get_children():
				_tumble(z, stone as Node3D, k, delta, 0.13)


## Four legs give way: a stagger, then over onto its side, legs stiff, and still.
static func _fall_quadruped(holder: Node3D, k: float, side: float, girth: float) -> void:
	var rig := holder.get_node("Rig") as Node3D
	var hind := rig.get_node("Hind") as Node3D
	var torso := hind.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var over := smoothstep(0.18, 0.75, k)
	# A last lurch up on the forelegs before it goes over.
	hind.rotation.x = -0.25 * sin(clampf(k / 0.4, 0.0, 1.0) * PI) * (1.0 - over)
	rig.rotation.z = side * 1.45 * over + side * 0.1 * sin(clampf((k - 0.75) / 0.3, 0.0, 1.0) * PI)
	rig.position.y = girth * over
	head.rotation.x = lerpf(0.0, 0.35, over)
	head.rotation.z = -side * 0.4 * over
	var twitch := sin(k * 22.0) * 0.12 * clampf((k - 0.8) / 0.2, 0.0, 1.0) * clampf((1.5 - k) / 0.4, 0.0, 1.0)
	for leg_name: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		var front := leg_name.begins_with("LegF")
		var leg := (torso if front else rig).get_node(leg_name) as Node3D
		var knee := leg.get_node("Knee") as Node3D
		leg.rotation.x = lerpf(leg.rotation.x, (-0.45 if front else 0.4) + twitch, minf(1.0, over * 0.3 + 0.05))
		knee.rotation.x = lerpf(knee.rotation.x, 0.15, minf(1.0, over * 0.3 + 0.05))


## Standing up when it dies: the knees go, it falls back and lies with its arms flung out.
static func _fall_upright(body: Node3D, k: float, side: float) -> void:
	var over := smoothstep(0.1, 0.8, k)
	body.rotation.x = -1.5 * over
	body.rotation.z = side * 0.25 * over
	body.position.y = 0.25 * over
	for leg_name: String in ["LegL", "LegR"]:
		(body.get_node(leg_name) as Node3D).rotation.x = lerpf(0.0, 0.9, smoothstep(0.0, 0.35, k)) * (1.0 - over * 0.6)
	(body.get_node("ArmL") as Node3D).rotation.z = -1.2 * over
	(body.get_node("ArmR") as Node3D).rotation.z = 1.2 * over
	(body.get_node("Head") as Node3D).rotation.x = -0.4 * over


## A flyer shot down: wings flail and the body tips nose-first as it drops; on the ground it rolls
## onto its side with a wing crumpled under it.
static func _fall_flyer(z: Zombie, root: Node3D, k: float, delta: float, side: float) -> void:
	var landed := z.position.y - z.world.ground_at(z.position) < 0.05
	if not landed:
		root.set_meta("landed_at", -1.0)
	elif float(root.get_meta("landed_at", -1.0)) < 0.0:
		root.set_meta("landed_at", k)
	var since := k - float(root.get_meta("landed_at", -1.0)) if landed else 0.0
	var flail := sin(k * 15.0) * 1.0 * maxf(0.0, 1.0 - k * 0.6) if not landed else 0.0
	var wing_l := root.get_meta("wing_l") as Node3D
	var wing_r := root.get_meta("wing_r") as Node3D
	var body := root.get_node_or_null("Body") as Node3D
	var big := z.model_id.ends_with("wyvern")
	if not landed:
		wing_l.rotation.z = flail
		wing_r.rotation.z = -flail
		if body:
			body.rotation.x = lerpf(body.rotation.x, 0.8, minf(1.0, delta * 3.0))
			(body.get_node("Tail") as Node3D).rotation.y = sin(k * 9.0) * 0.6
		else:
			root.rotation.z += delta * 9.0 * side
	else:
		var lie := smoothstep(0.0, 0.45, since)
		# Down: the body comes level, rolls over, and the wings lie flat, one of them folded.
		root.rotation.z = lerpf(root.rotation.z if body == null else 0.0, side * (1.2 if body else 1.5), lie)
		if body:
			body.rotation.x = lerpf(0.8, 0.0, lie)
			root.position.y = lerpf(0.0, 0.35 * body.scale.y, lie)
		wing_l.rotation.z = lerpf(wing_l.rotation.z, 0.2 if side > 0 else -1.3, lie)
		wing_r.rotation.z = lerpf(wing_r.rotation.z, 1.3 if side > 0 else -0.2, lie)
		if big and since < delta * 1.5:
			z.world.fx_gore(z.position + Vector3.UP * 0.2, Color(0.45, 0.4, 0.34))


## Stone coming apart: the arms and the body break into their pieces, which fall and roll away while
## the glowing core goes out.
static func _crumble(z: Zombie, root: Node3D, k: float, delta: float) -> void:
	var body := root.get_node("Body") as Node3D
	var core := body.get_node_or_null("Core") as Node3D
	if k < 0.3:
		# A shudder first.
		body.position.x = sin(k * 70.0) * 0.05
		body.rotation.x = k * 0.5
		return
	for piece in body.get_children():
		_tumble(z, piece as Node3D, k - 0.3, delta, 0.25 if z.model_id == "earth_elemental" else 0.5)
	if core:
		core.scale = Vector3.ONE * maxf(0.01, 1.0 - (k - 0.3) * 1.5) * (1.0 + sin(k * 40.0) * 0.15) * (2.0 if z.model_id == "great_revenant_elemental" else 1.0)
	var orbit := root.get_node_or_null("Orbit") as Node3D
	if orbit and orbit.visible:
		for stone in orbit.get_children():
			_tumble(z, stone as Node3D, k, delta, 0.2)


## One loose piece: thrown out, falling, spinning, and coming to rest on the ground.
static func _tumble(z: Zombie, piece: Node3D, k: float, delta: float, rest_height: float) -> void:
	var fall: Variant = piece.get_meta("fall", null)
	if fall == null or k < float(fall["delay"]) or bool(fall["rest"]):
		return
	var v: Vector3 = fall["v"]
	piece.global_position += v * delta
	v.y -= 9.8 * delta
	var spin: Vector3 = fall["spin"]
	piece.rotation += spin * delta
	var ground := z.world.ground_at(piece.global_position) + rest_height
	if piece.global_position.y <= ground and v.y < 0.0:
		piece.global_position.y = ground
		if absf(v.y) > 2.0:
			v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
			spin *= 0.5
		else:
			fall["rest"] = true
	fall["v"] = v
	fall["spin"] = spin


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
