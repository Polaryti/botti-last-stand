class_name MistSeal
extends Node3D
## A ground-following, one-hit warning. Each phone hurts only its locally owned targets.
## The style says what lands when it closes: mist that slows (the Mists), a quake that stuns, a bolt
## of lightning, a gout of fire, or a boulder thrown from whoever cast it (Mesenlla).
const LIMIT := 16
enum Style { MIST, QUAKE, STORM, FIRE, BOULDER }
const LOOKS := {
	Style.MIST: [Color(0.2, 0.8, 1.0), Color(0.85, 0.4, 1.0)],
	Style.QUAKE: [Color(0.95, 0.86, 0.32), Color(1.0, 0.6, 0.12)],
	Style.STORM: [Color(0.75, 0.85, 1.0), Color(1.0, 1.0, 0.75)],
	Style.FIRE: [Color(1.0, 0.42, 0.1), Color(0.9, 0.08, 0.04)],
	Style.BOULDER: [Color(0.78, 0.76, 0.72), Color(0.66, 0.36, 0.22)],
}
var style := 0
var _boulder: MeshInstance3D
var _from := Vector3.ZERO
static var _boulder_mesh: Mesh
var world: World
var radius := 3.0
var inner := 0.0
var warning := 1.5
var damage := 12.0
var source_id := -1
var elapsed := 0.0
var struck := false
var _material: ShaderMaterial

static func cast(z: Zombie, at: Vector3, reach: float, delay: float, amount: float, eye := 0.0, kind := 0) -> void:
	if z.world.mist_seals.size() >= LIMIT or not z.world.terrain.is_walkable(at.x, at.z):
		return
	# Aim at the surface below a jumping target, never at an invisible plane in mid-air.
	var ground := z.world.ground_at(at)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.35, Vector3(at.x, ground - 0.5, at.z), 1)
	var hit := z.world.get_world_3d().direct_space_state.intersect_ray(query)
	at.y = (hit["position"] as Vector3).y if not hit.is_empty() else ground
	if Net.active():
		if Net.is_host():
			Net.mist_seal(at, reach, eye, delay, amount, z.net_id, kind)
	else:
		create(z.world, at, reach, eye, delay, amount, z.net_id, kind)

static func create(w: World, at: Vector3, reach: float, eye: float, delay: float, amount: float, source: int, kind := 0) -> MistSeal:
	var seal := MistSeal.new()
	w.add_child(seal)
	seal.world = w
	seal.position = at
	seal.radius = reach
	seal.inner = eye
	seal.warning = delay
	seal.damage = amount
	seal.source_id = source
	seal.style = kind if LOOKS.has(kind) else 0
	w.mist_seals.append(seal)
	seal.tree_exiting.connect(func() -> void: w.mist_seals.erase(seal))
	seal._build()
	w.sfx_at(["mist_warning", "quake_warning", "storm_call", "fire_warning", "boulder_throw"][seal.style], at, 0.0)
	if seal.style == Style.BOULDER:
		seal._throw()
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
	_material.set_shader_parameter("col_a", LOOKS[style][0])
	_material.set_shader_parameter("col_b", LOOKS[style][1])
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	mesh_node.material_override = _material
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)

## A boulder flies from its thrower to where the seal will close, landing just as it does.
func _throw() -> void:
	var source := world.zombie_by_id(source_id)
	_from = source.centre() + Vector3.UP * 1.2 if source and source.active else position + Vector3(0, 14.0, 0)
	if _boulder_mesh == null:
		var l := LowPoly.new()
		l.prism(Vector3(0, -0.55, 0), Vector3(0, 0.55, 0), 0.6, 0.48, 6, Color(0.46, 0.43, 0.4))
		l.prism(Vector3(0.2, 0.2, 0.3), Vector3(0.1, 0.5, 0.5), 0.2, 0.0, 4, Color(0.3, 0.55, 0.3))
		l.box(Vector3(-0.3, 0.1, 0.42), Vector3(0.2, 0.08, 0.1), Color(0.55, 0.95, 0.92))
		_boulder_mesh = l.commit()
	_boulder = MeshInstance3D.new()
	_boulder.mesh = _boulder_mesh
	_boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boulder.top_level = true
	add_child(_boulder)
	_boulder.global_position = _from


func _physics_process(delta: float) -> void:
	elapsed += delta
	_material.set_shader_parameter("progress", minf(elapsed / warning, 1.0))
	if _boulder and not struck:
		var t := minf(elapsed / warning, 1.0)
		var at := _from.lerp(position + Vector3.UP * 0.6, t)
		at.y += sin(t * PI) * maxf(4.0, _from.distance_to(position) * 0.35)
		_boulder.global_position = at
		_boulder.rotation = Vector3(t * 7.0, t * 4.0, 0)
	if not struck and elapsed >= warning:
		struck = true
		strike()
	if elapsed >= warning + 0.45:
		queue_free()

func strike() -> void:
	var col: Color = LOOKS[style][1]
	world.show_ring(position, radius, col)
	world.fx_blast(position + Vector3.UP * 0.5, radius, Color(col, 0.65))
	match style:
		Style.MIST:
			world.fx_mist(position + Vector3.UP, radius * 0.5)
		Style.STORM:
			world.flash_bolt(position)
		Style.QUAKE, Style.BOULDER:
			world.fx_gore(position + Vector3.UP * 0.4, Color(0.42, 0.36, 0.3))
			if _boulder:
				_boulder.visible = false
	if world.player:
		Sfx.play_at(["mist_burst", "earth_slam", "thunder", "fire_breath", "boulder_impact"][style], position, world.player.global_position, 0.0)
	var source := world.zombie_by_id(source_id)
	var targets: Array = world.players.duplicate()
	if not Net.active() or Net.is_host():
		targets.append_array(world.allies)
	for target: Target in targets:
		if target.dead or target is Avatar or not contains(target.global_position):
			continue
		target.hurt(damage, position, source)
		if target is Player:
			var p := target as Player
			match style:
				Style.MIST: p.apply_status(Net.Status.SLOW, 2.0)
				Style.QUAKE, Style.BOULDER:
					p.apply_status(Net.Status.STUN, 0.8)
					p.velocity += Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z).normalized() * 6.0 + Vector3.UP * 4.0
				Style.STORM: p.apply_status(Net.Status.STUN, 0.5)
				Style.FIRE: p.ignite(3.0)
		elif style == Style.FIRE:
			target.ignite(3.0)

func contains(at: Vector3) -> bool:
	var distance := Vector2(at.x - position.x, at.z - position.z).length()
	return distance <= radius and distance >= inner and absf(at.y - position.y) <= 3.5 and world.terrain.is_walkable(at.x, at.z)
