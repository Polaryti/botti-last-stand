class_name FogBank
extends Node3D
## A Fogbinder's fog: a low bank of sea-fog where it was bound, a drifting grey dome with wisps rolling
## off it. Every phone shows it. Binding is worked out on the Fogbinder's own phone (or the host, for a
## bot): everything in it when it is called is blinded and slowed, and with Mistbound Sea the bank
## stays and binds whatever walks into it.

const TICK := 0.25
const FLAGS := ["fog_root", "fog_mark", "fog_field"]

var world: World
var owner_peer := 0
var radius := 4.5
var blind := 4.0
var left := 1.2 # how long it shows; a Mistbound Sea stays
var bits := 0
var _bound := {}
var _tick := 0.0
var _puff := 0.0
var _dome: MeshInstance3D
var _age := 0.0
static var _dome_mesh: Mesh
static var _fog_mat: StandardMaterial3D


func _init(owner_world: World, peer: int, at: Vector3, r: float, blind_secs: float, flags: int) -> void:
	world = owner_world
	owner_peer = peer
	radius = r
	blind = blind_secs
	bits = flags & ((1 << FLAGS.size()) - 1)
	left = TidecallerKit.FIELD_TIME if has("fog_field") else 1.4
	position = at
	name = "FogBank%d" % peer


func has(flag: String) -> bool:
	return bits & (1 << FLAGS.find(flag)) != 0


func _ready() -> void:
	top_level = true
	_dome = MeshInstance3D.new()
	_dome.mesh = dome_mesh()
	_dome.material_override = fog_material()
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dome)
	_dome.scale = Vector3(radius, radius * 0.45, radius) * 0.2
	for i in 6:
		var a := TAU * i / 6.0
		world.fx_mist(global_position + Vector3(cos(a), 0.0, sin(a)) * radius * 0.72, radius * 0.52)
	if owner_is_here():
		_bind_all()


func owner_is_here() -> bool:
	if not Net.active():
		return true
	return owner_peer == Net.my_id() or (Net.is_host() and Net.is_bot(owner_peer))


func owner_player() -> Player:
	if world.player and world.player.net_id() == owner_peer:
		return world.player
	for bot: Player in Net.bot_pawns():
		if bot.net_id() == owner_peer:
			return bot
	return null


func _physics_process(delta: float) -> void:
	_age += delta
	left -= delta
	# It rolls out quickly, holds, and thins away at the end.
	var grow := clampf(_age / 0.35, 0.0, 1.0)
	var fade := clampf(left / 0.6, 0.0, 1.0)
	_dome.scale = Vector3(radius, radius * 0.45, radius) * maxf(0.05, grow) * (0.85 + 0.15 * fade)
	_dome.transparency = 1.0 - fade * 0.95
	_puff -= delta
	if _puff <= 0.0 and left > 0.4:
		_puff = 0.35
		var a := randf() * TAU
		world.fx_mist(global_position + Vector3(cos(a), 0.3, sin(a)) * radius * randf_range(0.3, 0.9), radius * 0.3)
	if left <= 0.0:
		queue_free()
		return
	if has("fog_field") and owner_is_here():
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_bind_all()


## Everything inside, bound: blinded so it loses whoever it hunts, and slowed. Each creature once per
## bank, unless it walks out and back in a Mistbound Sea.
func _bind_all() -> void:
	var by := owner_player()
	if by == null:
		return
	var was := world.begin_act(by)
	for z: Zombie in world.zombies_near(global_position, radius, 40):
		if not z.is_alive() or float(_bound.get(z.get_instance_id(), -1.0)) > world.now:
			continue
		_bound[z.get_instance_id()] = world.now + blind
		z.blind_for(blind)
		z.slow(TidecallerKit.FOG_SLOW)
		if has("fog_root"):
			z.root(TidecallerKit.FOG_ROOT, true)
		if has("fog_mark"):
			z.mark(1.0 + TidecallerKit.FOG_MARK, blind)
	for r: Target in world.rivals_near(global_position, radius):
		if float(_bound.get(r.get_instance_id(), -1.0)) > world.now:
			continue
		_bound[r.get_instance_id()] = world.now + blind
		world.status_rival(r, Net.Status.SLOW, TidecallerKit.FOG_SLOW)
		world.status_rival(r, Net.Status.BLIND, blind)
	world.end_act(was)


## A low dome one unit across, its rim on the ground.
static func dome_mesh() -> Mesh:
	if _dome_mesh == null:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 16
		s.rings = 8
		s.is_hemisphere = true
		_dome_mesh = s
	return _dome_mesh


static func fog_material() -> StandardMaterial3D:
	if _fog_mat == null:
		_fog_mat = StandardMaterial3D.new()
		_fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fog_mat.albedo_color = Color(0.44, 0.72, 0.76, 0.20)
		_fog_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_fog_mat.disable_receive_shadows = true
	return _fog_mat
