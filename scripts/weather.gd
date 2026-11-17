class_name Weather
extends Node3D
## Most nights are clear. Some bring rain, and a few bring a storm, with lightning that strikes the map
## and hurts anyone standing there, friend or foe. The ground glows for a moment first, so a quick
## player can get out of the way. In a multiplayer game the host says where each bolt lands.
## In the Valleys of Mesenlla and on Mist Bastion some nights are windy instead: streaks of wind and
## blowing leaves, and the breeze. The Mists never see rain or storms.

enum Kind { CLEAR, RAIN, STORM, WINDY } # new kinds at the end: the number travels between phones

const STORM_CHANCE := 0.05 # of nights
const RAIN_CHANCE := 0.16 # of nights, besides the storms
const WINDY_CHANCE := 0.1 # of nights, where the wind blows
const WINDY_MAPS := ["mesenlla", "bastion", "vael"]
const DRY_MAPS := ["mists"] # no rain and no storms there
const WIND_SPEED := 13.0
const WIND_STREAKS := [40, 80, 120]
const WIND_LEAVES := [24, 48, 72]
const STRIKE_RADIUS := 4.5
const STRIKE_WARNING := 1.1
const PLAYER_DAMAGE := 40.0
const ENEMY_DAMAGE := 120.0
const STRIKE_MIN := 6.0
const STRIKE_MAX := 13.0
const STRIKE_NEAR_CHANCE := 0.45 # how often a bolt comes down close to someone, not just anywhere
const STREAKS := [300, 600, 900]
const CHECK_ROOF_EVERY := 0.3

var kind: int = Kind.CLEAR
var world: World
var flash := 0.0
var _rain: MeshInstance3D
var _rain_material: ShaderMaterial
var _next_strike := 7.0
var _next_sheet := 4.0
var _warnings: Array[Dictionary] = []
var _rings: Array[MeshInstance3D] = []
var _roof_timer := 0.0
var _indoors := false
var _clear := 0.0
var _wind: Node3D
var wind_dir := Vector3(1, 0, 0.3).normalized()


## Tonight's weather on a map.
static func roll(map_id := "village") -> int:
	var r := randf()
	if map_id in WINDY_MAPS:
		if r < WINDY_CHANCE:
			return Kind.WINDY
		r = randf()
	if map_id in DRY_MAPS:
		return Kind.CLEAR
	if r < STORM_CHANCE:
		return Kind.STORM
	return Kind.RAIN if r < STORM_CHANCE + RAIN_CHANCE else Kind.CLEAR


## The weather a map may have: a forced or sent kind it cannot have becomes a clear night.
static func allowed(kind: int, map_id: String) -> int:
	if map_id in DRY_MAPS and kind in [Kind.RAIN, Kind.STORM]:
		return Kind.CLEAR
	if kind == Kind.WINDY and map_id not in WINDY_MAPS:
		return Kind.CLEAR
	return kind


func _init(owner_world: World) -> void:
	world = owner_world


func _exit_tree() -> void:
	Sfx.rain(false, -60.0)
	Sfx.wind(false, -60.0)


func set_kind(new_kind: int) -> void:
	# Retire pending strikes when weather changes, including their pooled warning rings.
	for warning: Dictionary in _warnings:
		(warning["ring"] as MeshInstance3D).visible = false
	_warnings.clear()
	kind = new_kind
	var wet := is_wet()
	if wet and _rain == null:
		_build_rain()
	if _rain:
		_rain.visible = wet
	Sfx.rain(wet, -9.0)
	var windy := kind == Kind.WINDY
	if windy and _wind == null:
		_build_wind()
	if _wind:
		_wind.visible = windy
		for p: GPUParticles3D in _wind.get_children():
			p.emitting = windy
	Sfx.wind(windy, -11.0)
	flash = 0.0
	world.weather_changed()
	_set_flash(0.0) # reset the sky shader too if the player changes weather during a flash


func is_wet() -> bool:
	return kind == Kind.RAIN or kind == Kind.STORM


func opening_words() -> String:
	match kind:
		Kind.RAIN: return "Rain tonight"
		Kind.STORM: return "Storm tonight. Run from the glow"
		Kind.WINDY: return "The wind is up tonight"
	return ""


func _build_rain() -> void:
	var count: int = STREAKS[Game.quality]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var seed := Vector3(rng.randf(), rng.randf(), rng.randf())
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			st.set_uv(corner)
			st.add_vertex(seed)
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3.ONE * -2000.0, Vector3.ONE * 4000.0)
	_rain_material = ShaderMaterial.new()
	_rain_material.shader = load("res://assets/shaders/rain.gdshader")
	_rain = MeshInstance3D.new()
	_rain.mesh = mesh
	_rain.material_override = _rain_material
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


## The wind: pale streaks blowing past and leaves tumbling in it, around wherever you are.
func _build_wind() -> void:
	_wind = Node3D.new()
	_wind.name = "Wind"
	add_child(_wind)
	var a := randf() * TAU
	wind_dir = Vector3(cos(a), 0, sin(a))
	# Streaks: thin, pale and quick.
	var streaks := GPUParticles3D.new()
	streaks.amount = WIND_STREAKS[Game.quality]
	streaks.lifetime = 1.4
	streaks.local_coords = false
	streaks.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 30, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 4, 22)
	pm.direction = wind_dir
	pm.spread = 4.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = WIND_SPEED * 0.85
	pm.initial_velocity_max = WIND_SPEED * 1.25
	pm.particle_flag_align_y = true
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	streaks.process_material = pm
	var streak := BoxMesh.new()
	streak.size = Vector3(0.035, 2.0, 0.035)
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pale.vertex_color_use_as_albedo = true
	pale.albedo_color = Color(0.88, 0.94, 1.0, 0.38)
	pale.disable_fog = true
	streak.material = pale
	streaks.draw_pass_1 = streak
	streaks.position = Vector3.UP * 2.5
	_wind.add_child(streaks)
	# Leaves: tumbling, in the colours of the season.
	var leaves := GPUParticles3D.new()
	leaves.amount = WIND_LEAVES[Game.quality]
	leaves.lifetime = 3.2
	leaves.local_coords = false
	leaves.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 30, 80))
	var lm := ParticleProcessMaterial.new()
	lm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	lm.emission_box_extents = Vector3(18, 3, 18)
	lm.direction = wind_dir + Vector3.UP * 0.15
	lm.spread = 20.0
	lm.gravity = Vector3(0, -0.6, 0)
	lm.initial_velocity_min = WIND_SPEED * 0.4
	lm.initial_velocity_max = WIND_SPEED * 0.65
	lm.angular_velocity_min = -360.0
	lm.angular_velocity_max = 360.0
	lm.turbulence_enabled = true
	lm.turbulence_noise_strength = 2.0
	lm.turbulence_noise_scale = 3.0
	var hues := Gradient.new()
	hues.set_color(0, Color(0.55, 0.62, 0.22))
	hues.set_color(1, Color(0.78, 0.42, 0.14))
	hues.add_point(0.5, Color(0.86, 0.68, 0.22))
	var hue_ramp := GradientTexture1D.new()
	hue_ramp.gradient = hues
	lm.color_initial_ramp = hue_ramp
	leaves.process_material = lm
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.14, 0.09)
	var leaf_look := StandardMaterial3D.new()
	leaf_look.vertex_color_use_as_albedo = true
	leaf_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf_look.roughness = 0.9
	leaf.material = leaf_look
	leaves.draw_pass_1 = leaf
	leaves.position = Vector3.UP * 1.5
	_wind.add_child(leaves)


func _process(delta: float) -> void:
	if kind == Kind.WINDY and _wind:
		# The wind is all around you, wherever you go.
		var at := world._player_camera_position()
		_wind.global_position = Vector3(at.x, world.ground_at(at), at.z)
		return
	if kind == Kind.CLEAR:
		return
	_check_roof(delta)
	if kind == Kind.STORM:
		_tick_storm(delta)


## Under a roof the rain stays outside, and sounds further away.
func _check_roof(delta: float) -> void:
	_roof_timer -= delta
	if _roof_timer <= 0.0:
		_roof_timer = CHECK_ROOF_EVERY
		var from := world._player_camera_position()
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 14.0, 1)
		_indoors = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		Sfx.rain(true, -17.0 if _indoors else -9.0)
	_clear = move_toward(_clear, 7.0 if _indoors else 0.0, delta * 30.0)
	if _rain_material:
		_rain_material.set_shader_parameter("clear_radius", _clear)


func _tick_storm(delta: float) -> void:
	if not Net.is_client() and world.director and (world.director.running or world.director.sandbox):
		_next_strike -= delta
		if _next_strike <= 0.0:
			_next_strike = randf_range(STRIKE_MIN, STRIKE_MAX)
			var at := _pick_spot()
			if Net.is_host():
				Net.lightning(at)
			announce(at)
	_next_sheet -= delta
	if _next_sheet <= 0.0:
		_next_sheet = randf_range(7.0, 18.0)
		_set_flash(randf_range(0.35, 0.7))
		Sfx.play("thunder_far", randf_range(-14.0, -8.0), randf_range(0.85, 1.1), 1.0)
	for i in range(_warnings.size() - 1, -1, -1):
		var w: Dictionary = _warnings[i]
		w["left"] = float(w["left"]) - delta
		var ring: MeshInstance3D = w["ring"]
		(ring.material_override as ShaderMaterial).set_shader_parameter("progress", 1.0 - clampf(float(w["left"]) / STRIKE_WARNING, 0.0, 1.0))
		if float(w["left"]) <= 0.0:
			ring.visible = false
			_strike(w["at"])
			_warnings.remove_at(i)
	if flash > 0.0:
		_set_flash(maxf(0.0, flash - delta * 3.2))


func _pick_spot() -> Vector3:
	var half := world.play_half - 4.0
	if randf() < STRIKE_NEAR_CHANCE and not world.players.is_empty():
		var who: Target = world.players[randi() % world.players.size()]
		var a := randf() * TAU
		var r := randf_range(2.0, 16.0)
		var near := who.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		return Vector3(clampf(near.x, -half, half), 0.0, clampf(near.z, -half, half))
	return Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))


## The ground glows where the next bolt will land.
func announce(at: Vector3) -> void:
	var ground := Vector3(at.x, world.ground_at(at), at.z)
	var ring := _free_ring()
	(ring.material_override as ShaderMaterial).set_shader_parameter("progress", 0.0)
	ring.global_position = ground + Vector3.UP * 0.12
	ring.visible = true
	_warnings.append({"at": ground, "left": STRIKE_WARNING, "ring": ring})
	if world.player:
		Sfx.play_at("spell", ground, world.player.global_position, -8.0, 0.3)


func _free_ring() -> MeshInstance3D:
	for r in _rings:
		if not r.visible:
			return r
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * STRIKE_RADIUS * 2.0
	var ring_look := ShaderMaterial.new()
	ring_look.shader = load("res://assets/shaders/strike_ring.gdshader")
	var r := MeshInstance3D.new()
	r.mesh = disc
	r.material_override = ring_look
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(r)
	_rings.append(r)
	return r


func _strike(at: Vector3) -> void:
	world.flash_bolt(at)
	_set_flash(1.0)
	world.fx_gore(at + Vector3.UP * 0.5, Color(0.7, 0.85, 1.0))
	world.make_noise(at, 26.0)
	var p := world.player
	var from := world._player_camera_position()
	var d := from.distance_to(at)
	Sfx.play("thunder", clampf(2.0 - d * 0.16, -14.0, 2.0), 1.0, 0.1)
	if d < 20.0 and p and not p.dead:
		p.shake(clampf(1.0 - d / 20.0, 0.0, 1.0))
	# Only your own phone decides what happens to you.
	if p and not p.dead and p.global_position.distance_to(at) <= STRIKE_RADIUS + 1.0 and world.has_line_of_sight(at + Vector3.UP * 8.0, p.eye_position()):
		p.last_foe = 0
		p.hit_by = "lightning"
		p.hurt(PLAYER_DAMAGE, at)
	for a in world.allies:
		if a.remote_owner == 0 and not a.dead and a.global_position.distance_to(at) <= STRIKE_RADIUS:
			a.hurt(PLAYER_DAMAGE * 1.5, at)
	for bot: BotPlayer in Net.bot_players():
		if bot.pawn and not bot.pawn.dead and bot.at.distance_to(at) <= STRIKE_RADIUS:
			bot.pawn.last_foe = 0
			bot.pawn.hit_by = "lightning"
			bot.pawn.hurt(PLAYER_DAMAGE, at)
	if Net.is_client():
		return
	for z: Zombie in world.zombies.duplicate():
		if z.is_alive() and Vector2(z.position.x - at.x, z.position.z - at.z).length() <= STRIKE_RADIUS:
			z.next_hitter = -1
			z.take_damage(ENEMY_DAMAGE, z.position - at, 6.0, z.centre())
			if z.is_alive():
				z.stun(1.2)


func _set_flash(amount: float) -> void:
	flash = amount
	world.show_lightning(flash)
