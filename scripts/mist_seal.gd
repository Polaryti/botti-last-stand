class_name MistSeal
extends Node3D
## A ground-following, one-hit warning. Each phone hurts only its locally owned targets.
const LIMIT := 12
var world: World
var radius := 3.0
var inner := 0.0
var warning := 1.5
var damage := 12.0
var source_id := -1
var elapsed := 0.0
var struck := false
var _material: ShaderMaterial

static func cast(z: Zombie, at: Vector3, reach: float, delay: float, amount: float, eye := 0.0) -> void:
	if z.world.mist_seals.size() >= LIMIT or not z.world.terrain.is_walkable(at.x, at.z):
		return
	# Aim at the surface below a jumping target, never at an invisible plane in mid-air.
	var ground := z.world.ground_at(at)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.35, Vector3(at.x, ground - 0.5, at.z), 1)
	var hit := z.world.get_world_3d().direct_space_state.intersect_ray(query)
	at.y = (hit["position"] as Vector3).y if not hit.is_empty() else ground
	if Net.active():
		if Net.is_host():
			Net.mist_seal(at, reach, eye, delay, amount, z.net_id)
	else:
		create(z.world, at, reach, eye, delay, amount, z.net_id)

static func create(w: World, at: Vector3, reach: float, eye: float, delay: float, amount: float, source: int) -> MistSeal:
	var seal := MistSeal.new()
	w.add_child(seal)
	seal.world = w
	seal.position = at
	seal.radius = reach
	seal.inner = eye
	seal.warning = delay
	seal.damage = amount
	seal.source_id = source
	w.mist_seals.append(seal)
	seal.tree_exiting.connect(func() -> void: w.mist_seals.erase(seal))
	seal._build()
	w.sfx_at("mist_warning", at, 0.0)
	return seal

func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 8
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	var space := world.get_world_3d().direct_space_state
	for row in STEPS + 1:
		for col in STEPS + 1:
			var p := Vector3((float(col) / STEPS * 2.0 - 1.0) * radius, 0, (float(row) / STEPS * 2.0 - 1.0) * radius)
			var at := position + p
			var ground := world.ground_at(at)
			query.from = Vector3(at.x, maxf(position.y, ground) + 0.35, at.z)
			query.to = Vector3(at.x, ground - 0.5, at.z)
			var hit := space.intersect_ray(query)
			p.y = float((hit["position"] as Vector3).y) - position.y + 0.12 if not hit.is_empty() else ground - position.y + 0.12
			vertices.append(p)
			colours.append(Color(1, 1, 1, 1 if world.terrain.is_walkable(at.x, at.z) else 0))
	for row in STEPS:
		for col in STEPS:
			var a := row * (STEPS + 1) + col
			for i: int in [a, a + STEPS + 1, a + 1, a + 1, a + STEPS + 1, a + STEPS + 2]:
				st.set_color(colours[i])
				st.set_uv(Vector2(vertices[i].x, vertices[i].z) / (radius * 2.0) + Vector2.ONE * 0.5)
				st.set_normal(Vector3.UP)
				st.add_vertex(vertices[i])
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/mist_seal.gdshader")
	_material.set_shader_parameter("eye", inner / radius)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	mesh_node.material_override = _material
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)

func _physics_process(delta: float) -> void:
	elapsed += delta
	_material.set_shader_parameter("progress", minf(elapsed / warning, 1.0))
	if not struck and elapsed >= warning:
		struck = true
		strike()
	if elapsed >= warning + 0.45:
		queue_free()

func strike() -> void:
	world.fx_ring(position, radius, Color(0.45, 0.85, 1.0))
	world.fx_blast(position + Vector3.UP * 0.5, radius, Color(0.5, 0.7, 1.0, 0.65))
	world.fx_mist(position + Vector3.UP, radius * 0.5)
	world.sfx_at("mist_burst", position, 0.0)
	var source := world.zombie_by_id(source_id)
	var targets: Array = world.players.duplicate()
	if not Net.active() or Net.is_host():
		targets.append_array(world.allies)
	for target: Target in targets:
		if target.dead or target is Avatar or not contains(target.global_position):
			continue
		target.hurt(damage, position, source)
		if target is Player:
			(target as Player).apply_status(Net.Status.SLOW, 2.0)

func contains(at: Vector3) -> bool:
	var distance := Vector2(at.x - position.x, at.z - position.z).length()
	return distance <= radius and distance >= inner and absf(at.y - position.y) <= 3.5 and world.terrain.is_walkable(at.x, at.z)
