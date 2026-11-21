class_name TideWave
extends Node3D
## A Tidecaller's wave: a crest of seawater that rolls out over the ground from where it was called,
## in a straight line, and breaks at the end of its run. Every phone shows it. What it strikes is
## worked out on the Tidecaller's own phone (or the host, for a bot), so each blow is counted once;
## each phone looks after its own people, whom Salt Spray heals as the wave passes.

const SPEED := 14.0
const BAND := 1.4 # how deep the crest is: what stands within this behind its front is struck
## The tree's switches, sent as bits.
const FLAGS := ["riptide", "breakers", "spray", "drowning", "tsunami"]

var world: World
var owner_peer := 0
var from := Vector3.ZERO
var dir := Vector3.FORWARD
var width := 3.0
var reach := 14.0
var damage := 0.0
var bits := 0
var _run := 0.0
var _struck := {}
var _crest: MeshInstance3D
var _fading := 0.0
static var _crest_mesh: Mesh
static var _water: StandardMaterial3D


func _init(owner_world: World, peer: int, start: Vector3, toward: Vector3, wide: float, length: float, power: float, flags: int) -> void:
	world = owner_world
	owner_peer = peer
	from = start
	dir = Vector3(toward.x, 0, toward.z).normalized() if Vector2(toward.x, toward.z).length() > 0.01 else Vector3.FORWARD
	width = wide
	reach = length
	damage = power
	bits = flags & ((1 << FLAGS.size()) - 1)
	name = "TideWave%d" % peer


func has(flag: String) -> bool:
	return bits & (1 << FLAGS.find(flag)) != 0


func _ready() -> void:
	top_level = true
	_crest = MeshInstance3D.new()
	_crest.mesh = crest_mesh()
	_crest.material_override = water_material()
	_crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crest)
	_place()


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


func front() -> Vector3:
	return from + dir * _run


func _place() -> void:
	var at := front()
	at.y = world.ground_at(at)
	var grow := clampf(_run / 2.0, 0.35, 1.0) * (1.0 - _fading)
	var tall := (1.6 if has("tsunami") else 1.0) * grow
	_crest.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP).scaled(Vector3(width, tall, 1.0 + 0.4 * grow)), at)


func _physics_process(delta: float) -> void:
	if _fading > 0.0:
		_fading += delta * 3.0
		if _fading >= 1.0:
			queue_free()
			return
		_place()
		return
	_run += SPEED * delta
	if _run >= reach:
		_run = reach
		_fading = 0.01
		var at := front()
		var flank := dir.cross(Vector3.UP) * width * 0.27
		world.fx_water(at, width * 0.5, Color(0.72, 0.9, 0.92))
		world.fx_mist(at + flank + Vector3.UP * 0.5, width * 0.27)
		world.fx_mist(at - flank + Vector3.UP * 0.5, width * 0.27)
	_place()
	if has("spray"):
		for p: Player in world.local_players():
			if not p.dead and _in_band(p.global_position) and not _struck.has(p.get_instance_id()) and _friend(p):
				_struck[p.get_instance_id()] = true
				p.mended_by_friend(TidecallerKit.SPRAY_HEAL, owner_peer)
	if owner_is_here():
		_strike()


func _friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


## Inside the crest as it passes: within half the wave's width of its line, and just behind its front.
func _in_band(at: Vector3, body := 0.0) -> bool:
	var rel := Vector3(at.x - from.x, 0, at.z - from.z)
	var along := rel.dot(dir)
	var side := absf(rel.dot(dir.cross(Vector3.UP)))
	return along >= _run - BAND - body and along <= _run + 0.4 + body and side <= width * 0.5 + body


func _strike() -> void:
	var by := owner_player()
	if by == null:
		return
	var was := world.begin_act(by)
	var mid := front()
	for z: Zombie in world.zombies_near(mid, width * 0.5 + BAND + 2.0, 30):
		if not z.is_alive() or _struck.has(z.get_instance_id()) or not _in_band(z.position, z.body_radius()):
			continue
		_struck[z.get_instance_id()] = true
		var push := -dir if has("riptide") else dir
		world.damage_zombie(z, by.modify_damage(z, damage), push, 0.0 if has("riptide") else TidecallerKit.WAVE_KNOCK, z.centre(), false)
		z.slow(TidecallerKit.WAVE_SLOW)
		if has("riptide"):
			z.pull_to(by.global_position + dir * 1.5)
		if has("breakers"):
			z.stun(TidecallerKit.BREAKERS_STUN)
		if has("drowning"):
			z.add_dot(TidecallerKit.DROWNING.x, TidecallerKit.DROWNING.y)
		world.fx_water(z.centre(), 0.8, Color(0.72, 0.9, 0.92))
	for r: Target in world.rivals_near(mid, width * 0.5 + BAND + 2.0):
		if _struck.has(r.get_instance_id()) or not _in_band(r.global_position, 0.4):
			continue
		_struck[r.get_instance_id()] = true
		world.hit_rival(r, damage, from)
		world.status_rival(r, Net.Status.SLOW, TidecallerKit.WAVE_SLOW)
		if has("breakers"):
			world.status_rival(r, Net.Status.STUN, TidecallerKit.BREAKERS_STUN)
	world.end_act(was)


## The crest: a curling sheet of water one metre wide (scaled to the wave), its back a long slope, its
## face rising into a lip that curls over the front, lower toward both ends. Foam lightens the top.
## Faces -Z, the way it rolls.
static func crest_mesh() -> Mesh:
	if _crest_mesh == null:
		# The cross-section from the back (z +1.3, on the ground) over the crest to the lip, curling down.
		var profile: Array[Vector2] = [Vector2(1.3, 0.0), Vector2(0.8, 0.28), Vector2(0.4, 0.62), Vector2(0.12, 0.92), Vector2(-0.08, 1.08),
			Vector2(-0.28, 1.1), Vector2(-0.44, 1.0), Vector2(-0.5, 0.84), Vector2(-0.44, 0.7)]
		var deep := Color(0.14, 0.46, 0.54)
		var sea := Color(0.34, 0.74, 0.76)
		var foam := Color(0.94, 0.99, 0.98)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 12
		for c in cols:
			var x0 := -0.5 + float(c) / cols
			var x1 := -0.5 + float(c + 1) / cols
			for k in profile.size() - 1:
				var quad: Array[Vector3] = []
				var tint: Array[Color] = []
				for x: float in [x0, x1]:
					var h := 1.0 - pow(absf(x) * 2.0, 4.0) * 0.75
					h *= 0.95 + 0.05 * cos(x * TAU * 3.0)
					for q: Vector2 in [profile[k], profile[k + 1]]:
						quad.append(Vector3(x, q.y * h, q.x * (0.7 + 0.3 * h)))
						var up := clampf(q.y / 1.1, 0.0, 1.0)
						var white := clampf((up - 0.68) * 2.8 + sin(x * 41.0 + q.x * 5.0) * 0.22, 0.0, 1.0)
						tint.append(deep.lerp(sea, up).lerp(foam, white if k >= 4 else 0.0))
				# quad: [x0 lower, x0 upper, x1 lower, x1 upper]
				for i: int in [0, 1, 2, 2, 1, 3]:
					st.set_color(tint[i])
					st.add_vertex(quad[i])
		st.generate_normals()
		_crest_mesh = st.commit()
	return _crest_mesh


static func water_material() -> StandardMaterial3D:
	if _water == null:
		_water = StandardMaterial3D.new()
		_water.vertex_color_use_as_albedo = true
		_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water.albedo_color = Color(1, 1, 1, 0.82)
		_water.roughness = 0.2
		_water.cull_mode = BaseMaterial3D.CULL_DISABLED
		_water.metallic_specular = 0.8
		_water.emission_enabled = true
		_water.emission = Color(0.1, 0.25, 0.26)
	return _water
