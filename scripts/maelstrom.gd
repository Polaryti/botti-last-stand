class_name Maelstrom
extends Node3D
## A Stormcaller's Maelstrom: a storm cell where its third Stormspear ended. A dark cloud turns low
## overhead, rain drives down out of it and the wind circles over the ground; every so often a bolt
## falls on an enemy under it, a soaked one first. The bolts are struck on the Stormcaller's phone (or
## the host, for a bot) and every phone is told where they fell.

const CLOUD_HIGH := 6.2

var world: World
var owner_peer := 0
var left := TidecallerKit.MAELSTROM_TIME
var _next := 0.35
var _age := 0.0
var _cloud: Node3D
var _puffs: Array[MeshInstance3D] = []
var _wind: MeshInstance3D
var _rain: CPUParticles3D
var _light: OmniLight3D
static var _wind_mat: StandardMaterial3D


func _init(owner_world: World, peer: int, at: Vector3) -> void:
	world = owner_world
	owner_peer = peer
	position = at
	name = "Maelstrom%d" % peer


func _ready() -> void:
	top_level = true
	if _wind_mat == null:
		_wind_mat = StandardMaterial3D.new()
		_wind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wind_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_wind_mat.albedo_color = Color(0.7, 0.88, 1.0, 0.22)
	_cloud = Node3D.new()
	_cloud.position = Vector3.UP * CLOUD_HIGH
	add_child(_cloud)
	_build_cloud()
	_wind = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = TidecallerKit.MAELSTROM_REACH * 0.88
	ring.outer_radius = TidecallerKit.MAELSTROM_REACH
	ring.rings = 32
	ring.ring_segments = 4
	_wind.mesh = ring
	_wind.material_override = _wind_mat
	_wind.position = Vector3.UP * 0.15
	_wind.scale = Vector3(1, 0.15, 1)
	add_child(_wind)
	_rain = CPUParticles3D.new()
	_rain.amount = 90 if Game.quality > 0 else 36
	_rain.lifetime = 0.7
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_rain.emission_sphere_radius = TidecallerKit.MAELSTROM_REACH * 0.8
	_rain.position = Vector3.UP * (CLOUD_HIGH - 0.6)
	_rain.direction = Vector3.DOWN
	_rain.spread = 6.0
	_rain.gravity = Vector3(0, -20, 0)
	_rain.initial_velocity_min = 8.0
	_rain.initial_velocity_max = 11.0
	var streak := BoxMesh.new()
	streak.size = Vector3(0.025, 0.55, 0.025)
	var wet := StandardMaterial3D.new()
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color = Color(0.75, 0.9, 1.0, 0.45)
	streak.material = wet
	_rain.mesh = streak
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)
	_light = OmniLight3D.new()
	_light.light_color = TidecallerKit.STORM
	_light.omni_range = 12.0
	_light.light_energy = 0.0
	_light.position = Vector3.UP * (CLOUD_HIGH - 1.5)
	add_child(_light)
	world.sfx_here("maelstrom", global_position, -2.0)
	scale = Vector3.ONE * 0.3


## A low cloud of soft, dark puffs in a ring round a darker heart, each one a billboard so it reads
## as vapour from any side; a few paler tops where the lightning inside lights it.
func _build_cloud() -> void:
	var r := TidecallerKit.MAELSTROM_REACH
	var soft := load("res://assets/sprites/glow.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 22:
		var ring := i < 14
		var a := TAU * i / 14.0 if ring else rng.randf() * TAU
		var d := r * (0.55 + rng.randf_range(-0.1, 0.12)) if ring else r * rng.randf_range(0.0, 0.35)
		var puff := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var size := r * (0.8 if ring else 1.0) * rng.randf_range(0.85, 1.2)
		quad.size = Vector2(size, size * 0.7)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = soft
		var shade := rng.randf_range(0.0, 1.0)
		mat.albedo_color = Color(0.2, 0.24, 0.3).lerp(Color(0.5, 0.56, 0.66), shade * (0.7 if ring else 0.3))
		mat.albedo_color.a = 0.92
		mat.render_priority = i
		quad.material = mat
		puff.mesh = quad
		puff.position = Vector3(cos(a) * d, rng.randf_range(-0.4, 0.6), sin(a) * d)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cloud.add_child(puff)
		_puffs.append(puff)


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


func _process(delta: float) -> void:
	_age += delta
	left -= delta
	var grow := clampf(_age / 0.5, 0.0, 1.0)
	var fade := clampf(left / 0.8, 0.0, 1.0)
	scale = Vector3.ONE * maxf(0.05, grow * (0.6 + 0.4 * fade))
	_cloud.rotation.y += delta * 0.6
	for i in _puffs.size():
		_puffs[i].position.y += sin(_age * 0.9 + i) * delta * 0.15
	_wind.rotation.y -= delta * 2.2
	_wind_mat.albedo_color.a = 0.22 * fade
	_rain.emitting = left > 0.3
	_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 12.0)
	if left <= -0.8:
		queue_free()
		return
	if left <= 0.0 or not owner_is_here():
		return
	_next -= delta
	if _next <= 0.0:
		_next = TidecallerKit.MAELSTROM_GAP
		_strike()


## A bolt on an enemy under the cloud: a soaked one if there is one, the nearest the middle if not.
func _strike() -> void:
	var by := owner_player()
	if by == null:
		return
	var pick: Zombie = null
	var best := INF
	for z: Zombie in world.zombies_near(global_position, TidecallerKit.MAELSTROM_REACH, 32):
		if not z.is_alive() or z.dormant:
			continue
		var score := z.position.distance_to(global_position) - (100.0 if z.soaked_left > 0.0 else 0.0)
		if score < best:
			best = score
			pick = z
	if pick == null:
		return
	var was := world.begin_act(by)
	world.damage_zombie(pick, TidecallerKit.MAELSTROM_DAMAGE * by.damage_multiplier() * by.m("spell_damage"), Vector3.UP, 0.5, pick.centre(), false)
	pick.soak(TidecallerKit.SOAK_TIME)
	world.end_act(was)
	show_bolt(pick.centre())
	if Net.active():
		Net.maelstrom_bolt(owner_peer, pick.centre())


func show_bolt(at: Vector3) -> void:
	var top := global_position + Vector3.UP * (CLOUD_HIGH - 0.8) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	world.add_child(StormArc.new(PackedVector3Array([top, at]), true))
	_light.light_energy = 4.0
	world.sfx_here("thunder", at, -8.0)
