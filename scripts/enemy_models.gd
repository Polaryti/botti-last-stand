class_name EnemyModels
## Built from code, for enemies with no matching free animated model.

static var _cache := {}


static func _mesh(key: String, build: Callable) -> Mesh:
	if not _cache.has(key):
		var l := LowPoly.new()
		build.call(l)
		_cache[key] = l.commit()
	return _cache[key]


static func _part(root: Node3D, mesh: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## Returns the model. Named parts are stored as metadata for the animation code.
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"crow":
			var black := Color(0.08, 0.07, 0.11)
			_part(root, _mesh("crow_body", func(l: LowPoly) -> void:
				l.prism(Vector3(0, 0, -0.34), Vector3(0, 0, 0.26), 0.09, 0.17, 6, black)
				l.prism(Vector3(0, 0.05, 0.26), Vector3(0, 0.09, 0.46), 0.13, 0.1, 6, black)
				l.prism(Vector3(0, 0.08, 0.46), Vector3(0, 0.05, 0.68), 0.05, 0.0, 4, Color(0.55, 0.45, 0.2))
				l.box(Vector3(0.08, 0.15, 0.48), Vector3(0.03, 0.03, 0.02), Color(1, 0.2, 0.1))
				l.box(Vector3(-0.08, 0.15, 0.48), Vector3(0.03, 0.03, 0.02), Color(1, 0.2, 0.1))
				l.box(Vector3(0, -0.02, -0.5), Vector3(0.18, 0.03, 0.34), black)))
			var wing := _mesh("crow_wing", func(l: LowPoly) -> void:
				l.box(Vector3(0.36, 0, 0), Vector3(0.72, 0.03, 0.34), black.lightened(0.08)))
			root.set_meta("wing_l", _part(root, wing, Vector3(0.06, 0.05, 0)))
			var wr := _part(root, wing, Vector3(-0.06, 0.05, 0))
			wr.scale = Vector3(-1, 1, 1)
			root.set_meta("wing_r", wr)
		"harrier":
			# A pale ray of the mist: all wing, with a long whip of a tail and a burning eye each side.
			var pale := Color(0.74, 0.94, 0.9)
			var under := Color(0.16, 0.42, 0.46)
			_part(root, _mesh("harrier_body", func(l: LowPoly) -> void:
				l.prism(Vector3(0, 0, -0.5), Vector3(0, 0, 0.42), 0.14, 0.3, 6, pale)
				l.prism(Vector3(0, 0.02, 0.42), Vector3(0, 0, 0.82), 0.26, 0.05, 5, pale.lightened(0.15))
				for x: float in [-0.14, 0.14]:
					l.box(Vector3(x, 0.14, 0.56), Vector3(0.09, 0.07, 0.09), Color(1.0, 0.36, 0.2))
					l.prism(Vector3(x, 0.0, 0.76), Vector3(x * 1.2, -0.12, 1.08), 0.05, 0.0, 4, under)
				l.prism(Vector3(0, 0, -0.5), Vector3(0, 0.05, -1.1), 0.08, 0.05, 4, under)
				l.prism(Vector3(0, 0.05, -1.1), Vector3(0, -0.04, -1.9), 0.05, 0.015, 4, under)
				l.prism(Vector3(0, 0.1, -0.1), Vector3(0, 0.42, -0.42), 0.12, 0.0, 4, under)))
			var ray_wing := _mesh("harrier_wing", func(l: LowPoly) -> void:
				l.box(Vector3(0.42, 0, 0), Vector3(0.84, 0.05, 0.78), pale)
				l.box(Vector3(1.08, -0.02, -0.08), Vector3(0.52, 0.04, 0.48), pale.darkened(0.12))
				l.box(Vector3(1.52, -0.04, -0.18), Vector3(0.42, 0.03, 0.2), under))
			root.set_meta("wing_l", _part(root, ray_wing, Vector3(0.14, 0.03, 0)))
			var other_wing := _part(root, ray_wing, Vector3(-0.14, 0.03, 0))
			other_wing.scale = Vector3(-1, 1, 1)
			root.set_meta("wing_r", other_wing)
		"gargoyle":
			var stone := Color(0.4, 0.4, 0.44)
			_part(root, _mesh("garg_body", func(l: LowPoly) -> void:
				l.box(Vector3(0, 1.0, 0), Vector3(0.75, 0.9, 0.55), stone)
				l.box(Vector3(0, 1.62, 0.18), Vector3(0.5, 0.48, 0.5), stone.lightened(0.05))
				l.prism(Vector3(-0.18, 1.82, 0.14), Vector3(-0.3, 2.24, 0.02), 0.08, 0.0, 4, stone.darkened(0.3))
				l.prism(Vector3(0.18, 1.82, 0.14), Vector3(0.3, 2.24, 0.02), 0.08, 0.0, 4, stone.darkened(0.3))
				l.box(Vector3(0.12, 1.68, 0.44), Vector3(0.1, 0.07, 0.02), Color(1, 0.4, 0.1))
				l.box(Vector3(-0.12, 1.68, 0.44), Vector3(0.1, 0.07, 0.02), Color(1, 0.4, 0.1))
				l.box(Vector3(0, 1.48, 0.44), Vector3(0.3, 0.08, 0.02), Color(0.08, 0.06, 0.06))
				for x: float in [-0.25, 0.25]:
					l.box(Vector3(x, 0.32, 0.12), Vector3(0.26, 0.64, 0.42), stone.darkened(0.12))
					l.box(Vector3(x * 1.7, 0.95, 0.22), Vector3(0.2, 0.7, 0.2), stone.darkened(0.08))
					l.prism(Vector3(x * 1.7, 0.6, 0.3), Vector3(x * 1.7, 0.4, 0.44), 0.07, 0.0, 4, Color(0.15, 0.13, 0.13))
				l.prism(Vector3(0, 0.75, -0.25), Vector3(0, 0.2, -0.8), 0.09, 0.0, 4, stone.darkened(0.2))))
			var wing := _mesh("garg_wing", func(l: LowPoly) -> void:
				l.box(Vector3(0.65, 0.2, 0), Vector3(1.3, 0.05, 0.72), stone.darkened(0.25))
				l.box(Vector3(1.2, 0.05, 0.1), Vector3(0.5, 0.05, 0.5), stone.darkened(0.3)))
			root.set_meta("wing_l", _part(root, wing, Vector3(0.3, 1.3, -0.25)))
			var wr := _part(root, wing, Vector3(-0.3, 1.3, -0.25))
			wr.scale = Vector3(-1, 1, 1)
			root.set_meta("wing_r", wr)
		"mimic":
			var wood := Color(0.42, 0.26, 0.14)
			var iron := Color(0.3, 0.3, 0.32)
			root.set_meta("base", _part(root, _mesh("mimic_base", func(l: LowPoly) -> void:
				l.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.7), wood)
				l.box(Vector3(0, 0.3, 0.36), Vector3(1.02, 0.1, 0.02), iron)
				l.box(Vector3(-0.42, 0.3, 0), Vector3(0.08, 0.62, 0.72), iron)
				l.box(Vector3(0.42, 0.3, 0), Vector3(0.08, 0.62, 0.72), iron)
				l.box(Vector3(0, 0.56, 0.05), Vector3(0.9, 0.04, 0.55), Color(0.3, 0.05, 0.06))
				for i in 6:
					l.prism(Vector3(-0.38 + i * 0.15, 0.58, 0.32), Vector3(-0.38 + i * 0.15, 0.78, 0.33), 0.04, 0.0, 4, Color(0.92, 0.9, 0.75)))))
			var lid := _part(root, _mesh("mimic_lid", func(l: LowPoly) -> void:
				l.box(Vector3(0, 0.14, 0.33), Vector3(1.0, 0.28, 0.7), wood.darkened(0.08))
				l.box(Vector3(-0.42, 0.14, 0.33), Vector3(0.08, 0.3, 0.72), iron)
				l.box(Vector3(0.42, 0.14, 0.33), Vector3(0.08, 0.3, 0.72), iron)
				for i in 6:
					l.prism(Vector3(-0.38 + i * 0.15, 0.0, 0.64), Vector3(-0.38 + i * 0.15, -0.2, 0.65), 0.04, 0.0, 4, Color(0.92, 0.9, 0.75))
				l.box(Vector3(0.18, 0.25, 0.68), Vector3(0.1, 0.08, 0.02), Color(1, 0.2, 0.1))
				l.box(Vector3(-0.18, 0.25, 0.68), Vector3(0.1, 0.08, 0.02), Color(1, 0.2, 0.1))), Vector3(0, 0.6, -0.35))
			root.set_meta("lid", lid)
		"dummy":
			var straw := Color(0.72, 0.6, 0.3)
			var post := Color(0.3, 0.2, 0.12)
			var rope := Color(0.42, 0.32, 0.2)
			_part(root, _mesh("dummy_body", func(l: LowPoly) -> void:
				l.box(Vector3(0, 0.6, 0), Vector3(0.16, 1.2, 0.16), post)
				l.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.16), post)
				l.box(Vector3(0, 0.05, 0), Vector3(0.16, 0.1, 0.9), post)
				l.box(Vector3(0, 1.2, 0), Vector3(0.62, 0.8, 0.34), straw)
				l.box(Vector3(0, 1.0, 0), Vector3(0.66, 0.06, 0.38), rope)
				l.box(Vector3(0, 1.42, 0), Vector3(0.66, 0.06, 0.38), rope)
				l.box(Vector3(0, 1.55, 0), Vector3(1.5, 0.12, 0.12), post)
				l.box(Vector3(0.78, 1.55, 0), Vector3(0.16, 0.3, 0.18), straw)
				l.box(Vector3(-0.78, 1.55, 0), Vector3(0.16, 0.3, 0.18), straw)
				l.box(Vector3(0, 1.82, 0), Vector3(0.36, 0.38, 0.36), straw.lightened(0.08))
				l.prism(Vector3(0, 1.22, 0.17), Vector3(0, 1.22, 0.2), 0.24, 0.24, 12, Color(0.86, 0.82, 0.72))
				l.prism(Vector3(0, 1.22, 0.2), Vector3(0, 1.22, 0.215), 0.15, 0.15, 12, Color(0.7, 0.16, 0.12))
				l.prism(Vector3(0, 1.22, 0.215), Vector3(0, 1.22, 0.23), 0.06, 0.06, 10, Color(0.86, 0.82, 0.72))))
		"scarecrow":
			var hay := Color(0.72, 0.6, 0.26)
			var post := Color(0.2, 0.13, 0.08)
			root.set_meta("body", _part(root, _mesh("sc_body", func(l: LowPoly) -> void:
				l.box(Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), post)
				l.box(Vector3(0, 1.28, 0), Vector3(0.62, 0.7, 0.32), Color(0.32, 0.22, 0.25))
				l.box(Vector3(0, 0.92, 0), Vector3(0.7, 0.12, 0.36), hay)
				l.box(Vector3(0, 1.82, 0), Vector3(0.36, 0.36, 0.36), hay)
				l.box(Vector3(0.09, 1.86, 0.19), Vector3(0.08, 0.08, 0.02), Color(0.9, 0.3, 0.05))
				l.box(Vector3(-0.09, 1.86, 0.19), Vector3(0.08, 0.08, 0.02), Color(0.9, 0.3, 0.05))
				l.box(Vector3(0, 1.72, 0.19), Vector3(0.2, 0.05, 0.02), Color(0.05, 0.03, 0.03))
				l.prism(Vector3(0, 2.0, 0), Vector3(0, 2.38, 0), 0.38, 0.0, 6, Color(0.14, 0.1, 0.08)))))
			var arm := _mesh("sc_arm", func(l: LowPoly) -> void:
				l.box(Vector3(0.45, 0, 0), Vector3(0.9, 0.1, 0.1), post)
				l.box(Vector3(0.92, 0, 0), Vector3(0.16, 0.2, 0.16), hay))
			root.set_meta("arm_l", _part(root, arm, Vector3(0.3, 1.5, 0)))
			var ar := _part(root, arm, Vector3(-0.3, 1.5, 0))
			ar.scale = Vector3(-1, 1, 1)
			root.set_meta("arm_r", ar)
	return root
