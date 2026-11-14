class_name Consecration
extends Node3D
## A Paladin's Consecration: a holy standard planted in the ground, with a ring of gold light round it.
## Friends of the Paladin inside heal; enemies inside burn and are slowed. Every phone makes its own copy
## and looks after its own people; creatures are the host's, so only the host burns them.

var world: World
var owner_peer := 0
var radius := 6.0
var _left := 8.0
var _life := 8.0
var _tick := 0.0
var _rim: MeshInstance3D
var _glow: MeshInstance3D
var _rays: GPUParticles3D


func _init(owner_world: World, peer: int, at: Vector3, area: float, seconds: float) -> void:
	world = owner_world
	owner_peer = peer
	radius = area
	_left = seconds
	_life = seconds
	position = at
	name = "Consecration"


func _ready() -> void:
	add_child(standard())
	_rim = MeshInstance3D.new()
	_rim.material_override = light_material()
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rim.mesh = rim_mesh(radius, func(flat: Vector3) -> float:
		return (world.ground_at(position + flat) if world else position.y) - position.y)
	add_child(_rim)
	_glow = wash(radius)
	add_child(_glow)
	# Motes of light rising from it.
	_rays = GPUParticles3D.new()
	_rays.amount = 36 if Game.quality > 0 else 14
	_rays.lifetime = 1.8
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius * 0.9
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 0.1
	pm.gravity = Vector3(0, 0.9, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	_rays.process_material = pm
	var mote := QuadMesh.new()
	mote.size = Vector2(0.1, 0.1)
	mote.material = mote_material()
	_rays.draw_pass_1 = mote
	_rays.position.y = 0.2
	add_child(_rays)


## The holy standard: a gold pole and a pale banner, 2.6 m tall. The Store's demonstration plants the
## same one.
static func standard() -> Node3D:
	var root := Node3D.new()
	root.name = "Standard"
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.86, 0.7, 0.32)
	gold.metallic = 0.6
	gold.roughness = 0.4
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.06
	cyl.height = 2.6
	pole.mesh = cyl
	pole.material_override = gold
	pole.position.y = 1.3
	root.add_child(pole)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.96, 0.92, 0.78)
	cloth.emission_enabled = true
	cloth.emission = Color(1.0, 0.85, 0.45)
	cloth.emission_energy_multiplier = 0.6
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var banner := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 1.1)
	banner.mesh = quad
	banner.material_override = cloth
	banner.position = Vector3(0.42, 2.0, 0)
	root.add_child(banner)
	for mi: MeshInstance3D in [pole, banner]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func light_material() -> StandardMaterial3D:
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color(1.0, 0.82, 0.4)
	light.disable_fog = true
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	return light


static func mote_material() -> StandardMaterial3D:
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.albedo_color = Color(1.0, 0.88, 0.55)
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.disable_fog = true
	return mote_mat


## The ring of gold light on the ground; `ground` gives the ground's height (relative to the centre)
## under each point of it.
static func rim_mesh(area: float, ground: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const PARTS := 56
	var points: Array[Vector3] = []
	for i in PARTS + 1:
		var a := TAU * i / PARTS
		var flat := Vector3(cos(a), 0, sin(a))
		var y := float(ground.call(flat * area)) + 0.08
		points.append(Vector3(flat.x * (area - 0.1), y, flat.z * (area - 0.1)))
		points.append(Vector3(flat.x * (area + 0.1), y, flat.z * (area + 0.1)))
	for i in PARTS:
		for v: Vector3 in [points[i * 2], points[i * 2 + 1], points[i * 2 + 2], points[i * 2 + 1], points[i * 2 + 3], points[i * 2 + 2]]:
			st.add_vertex(v)
	return st.commit()


## The soft glow over what the ring holds.
static func wash(area: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.45, 0.12)
	mat.disable_fog = true
	var disc := CylinderMesh.new()
	disc.top_radius = area
	disc.bottom_radius = area
	disc.height = 0.02
	disc.radial_segments = 40
	var glow := MeshInstance3D.new()
	glow.mesh = disc
	glow.material_override = mat
	glow.position.y = 0.12
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return glow


func contains(at: Vector3) -> bool:
	return Vector2(at.x - position.x, at.z - position.z).length() <= radius and absf(at.y - position.y) < 4.0


func is_friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var fade := clampf(_left / 0.6, 0.0, 1.0) * clampf((_life - _left) / 0.3, 0.0, 1.0)
	(_glow.material_override as StandardMaterial3D).albedo_color.a = 0.12 * fade
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_tend(world.player, 0.25)
	if Net.is_host() or not Net.active():
		for bot: Player in Net.bot_pawns():
			_tend(bot, 0.25)
		for z: Zombie in world.zombies_near(position, radius, 40):
			if contains(z.position):
				z.ignite(UpgradeKit.CONSECRATE_BURN)
				z.slow(0.5)


## One person on this phone (or one of the host's bots): mended if a friend, burned and slowed if not.
func _tend(p: Player, step: float) -> void:
	if p == null or p.dead or not contains(p.global_position):
		return
	if is_friend(p):
		if p.hp < p.max_hp():
			p.mended_by_friend(UpgradeKit.CONSECRATE_HEAL * step)
	else:
		p.apply_status(Net.Status.BURN, 1.0)
		p.apply_status(Net.Status.SLOW, 0.5)
