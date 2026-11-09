class_name MistModels
extends RefCounted
## Three distinct silhouettes, cached low-poly meshes and lightweight procedural animation.
const KINDS := ["lantern_wisp", "mist_weaver", "veil_regent", "fallen_revenant"]
const INK := Color(0.075, 0.09, 0.16)
const VEIL := Color(0.19, 0.22, 0.36)
const BONE := Color(0.68, 0.78, 0.82)
const LIGHT := Color(0.25, 0.95, 0.9)
static var _meshes := {}
static var _material: ShaderMaterial

static func _part(root: Node3D, key: String, build: Callable) -> MeshInstance3D:
	if not _meshes.has(key):
		var l := LowPoly.new()
		build.call(l)
		_meshes[key] = l.commit()
	var part := MeshInstance3D.new()
	part.name = key
	part.mesh = _meshes[key]
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://assets/shaders/mist_body.gdshader")
	(part.mesh as ArrayMesh).surface_set_material(0, _material)
	root.add_child(part)
	return part

static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	var boss := kind == "veil_regent"
	if kind == "lantern_wisp":
		_part(root, "Lantern", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.8, 0), Vector3(0, 1.5, 0), 0.32, 0.22, 6, INK)
			l.prism(Vector3(0, 1.5, 0), Vector3(0, 1.8, 0), 0.28, 0.0, 6, BONE)
			for i in 4:
				var a := i * PI * 0.5
				var side := Vector3(cos(a), 0, sin(a)) * 0.28
				l.prism(side + Vector3.UP * 0.8, side + Vector3.UP * 1.48, 0.025, 0.025, 4, BONE)
			l.prism(Vector3(0, 0.95, 0.3), Vector3(0, 1.35, 0.3), 0.16, 0.04, 5, LIGHT)
			for side: float in [-1, 1]:
				l.prism(Vector3(side * 0.2, 0.75, 0), Vector3(side * 0.6, 0.1, -0.3), 0.1, 0.0, 4, VEIL))
	else:
		_part(root, "Mantle", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.35, 0), Vector3(0, 1.5, 0), 0.55, 0.25, 7, VEIL)
			for i in 7:
				var a := i * TAU / 7.0
				var v := Vector3(cos(a), 0, sin(a))
				l.prism(v * 0.5 + Vector3.UP * 0.45, v * 0.67 + Vector3.UP * (0.1 if i % 2 else 0.3), 0.16, 0.0, 4, INK)
			l.prism(Vector3(0, 1.5, 0), Vector3(0, 1.95, 0.04), 0.23, 0.17, 6, BONE)
			for side: float in [-1, 1]:
				l.box(Vector3(side * 0.1, 1.78, 0.2), Vector3(0.08, 0.045, 0.04), LIGHT)
				l.prism(Vector3(side * 0.23, 1.9, 0), Vector3(side * 0.6, 2.35, -0.1), 0.06, 0.0, 4, BONE)
				l.prism(Vector3(side * 0.38, 2.1, -0.05), Vector3(side * 0.7, 2.12, -0.12), 0.04, 0.0, 4, BONE)
				l.prism(Vector3(side * 0.23, 1.45, 0), Vector3(side * 0.85, 1.1, 0.14), 0.12, 0.05, 5, INK))
		if not boss and kind != "fallen_revenant":
			for side: float in [-1, 1]:
				var wing := _part(root, "WingLeft" if side < 0 else "WingRight", func(l: LowPoly) -> void:
					l.prism(Vector3.ZERO, Vector3(side * 1.1, 0.25, -0.15), 0.12, 0.4, 4, VEIL)
					l.prism(Vector3(side * 1.1, 0.25, -0.15), Vector3(side * 1.6, -0.4, -0.35), 0.4, 0.0, 4, BONE))
				wing.position.y = 1.25
	if kind == "fallen_revenant":
		_part(root, "SpectralClaws", func(l: LowPoly) -> void:
			for side: float in [-1.0, 1.0]:
				for finger in 3:
					var at := Vector3(side * (0.72 + finger * 0.06), 1.12, 0.14)
					l.prism(at, at + Vector3(side * 0.12, -0.25, 0.48), 0.035, 0.0, 4, LIGHT))
	if boss:
		for i in 3:
			var orbit := _part(root, "Orbit%d" % i, func(l: LowPoly) -> void:
				for segment in 24:
					var a := TAU * segment / 24.0
					var b := TAU * (segment + 1) / 24.0
					l.prism(Vector3(cos(a), 0, sin(a)) * 1.05, Vector3(cos(b), 0, sin(b)) * 1.05, 0.015, 0.015, 4, LIGHT))
			orbit.position.y = 1.55 + i * 0.3
		var crown := _part(root, "Crown", func(l: LowPoly) -> void:
			for i in 9:
				var a := i * TAU / 9.0
				var v := Vector3(cos(a), 0, sin(a))
				l.prism(v * 0.7, v * 0.78 + Vector3.UP * (0.48 if i % 2 else 0.65), 0.065, 0.0, 4, LIGHT)
				var next := Vector3(cos(a + TAU / 9), 0, sin(a + TAU / 9))
				l.prism(v * 0.7, next * 0.7, 0.04, 0.04, 4, BONE))
		crown.position.y = 2.2
		var nameplate := Label3D.new()
		nameplate.name = "RegentHealth"
		nameplate.position.y = 3.2
		nameplate.font_size = 32
		nameplate.pixel_size = 0.004
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.modulate = Color(0.65, 0.9, 1.0)
		root.add_child(nameplate)
	return root

static func animate(root: Node3D, time: float, fraction: float) -> void:
	root.position.y = 0.25 + sin(time * 2.0) * 0.12
	root.rotation.z = sin(time * 1.4) * 0.035
	var crown := root.get_node_or_null("Crown") as Node3D
	if crown:
		for i in 3:
			(root.get_node("Orbit%d" % i) as Node3D).rotation = Vector3(sin(time + i) * 0.6, time * (i + 1) * 0.3, cos(time + i) * 0.6)
		crown.rotation.y = time * (1.2 if fraction <= 0.5 else 0.35)
		var label := root.get_node("RegentHealth") as Label3D
		label.text = "VEIL REGENT • %d%%" % ceili(fraction * 100.0)
		label.modulate = Color(1.0, 0.45, 0.8) if fraction <= 0.5 else Color(0.65, 0.9, 1.0)
	for side: String in ["WingLeft", "WingRight"]:
		var wing := root.get_node_or_null(side) as Node3D
		if wing:
			wing.rotation.z = sin(time * 2.5) * (0.16 if side == "WingLeft" else -0.16)
