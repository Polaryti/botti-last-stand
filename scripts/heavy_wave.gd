class_name HeavyWave
extends MeshInstance3D
## One temporary mesh, grounded along its complete outline; at most eight per world.
var elapsed := 0.0
var look: ShaderMaterial

static func emit(w: World, kind: int, at: Vector3, direction: Vector3, radius: float) -> void:
	spawn_visual(w, kind, at, direction, radius)
	if Net.active(): Net.heavy_visual(kind, at, direction, radius)

static func spawn_visual(w: World, kind: int, at: Vector3, direction: Vector3, radius: float) -> HeavyWave:
	var active := w.find_children("HeavyWave*", "MeshInstance3D", false, false)
	if active.size() >= 8:
		active[0].name = "RetiringWave"
		active[0].queue_free()
	var node := HeavyWave.new()
	node.name = "HeavyWave"
	var mesh_builder := LowPoly.new()
	var tint := Color(0.95, 0.72, 0.27) if kind != 2 else Color(0.95, 0.35, 0.12)
	if kind == 2:
		var forward := Vector3(direction.x, 0, direction.z).normalized()
		var side := forward.cross(Vector3.UP)
		var last := at
		for i in 16:
			var point := at + forward * radius * float(i + 1) / 16.0 + side * sin(i * 2.2) * 0.3
			last.y = w.ground_at(last) + 0.055
			point.y = w.ground_at(point) + 0.055
			mesh_builder.prism(last, point, 0.07, 0.045, 4, tint)
			if i % 3 == 0:
				var fork := point + side * (0.7 if i % 2 else -0.7) - forward * 0.35
				fork.y = w.ground_at(fork) + 0.055
				mesh_builder.prism(point, fork, 0.035, 0.015, 4, tint)
			last = point
	else:
		for n in 48:
			var a := at + Vector3(cos(TAU * n / 48.0), 0, sin(TAU * n / 48.0)) * radius
			var b := at + Vector3(cos(TAU * (n + 1) / 48.0), 0, sin(TAU * (n + 1) / 48.0)) * radius
			a.y = w.ground_at(a) + 0.05
			b.y = w.ground_at(b) + 0.05
			mesh_builder.prism(a, b, 0.025, 0.025, 4, tint)
		for n in (6 if kind == 0 else 8):
			var dir := Vector3(cos(TAU * n / (6.0 if kind == 0 else 8.0)), 0, sin(TAU * n / (6.0 if kind == 0 else 8.0)))
			var a := at + dir * radius * 0.35
			var b := at + dir * radius * 0.7
			a.y = w.ground_at(a) + 0.06
			b.y = w.ground_at(b) + 0.06
			mesh_builder.prism(a, b, 0.035, 0.01, 4, tint)
	node.mesh = mesh_builder.commit()
	node.look = ShaderMaterial.new()
	node.look.shader = preload("res://assets/shaders/heavy_wave.gdshader")
	node.material_override = node.look
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(node)
	return node

func _process(delta: float) -> void:
	elapsed += delta
	look.set_shader_parameter("fade", maxf(0.0, 1.0 - elapsed / 1.2))
	if elapsed >= 1.2: queue_free()
