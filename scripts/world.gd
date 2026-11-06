class_name World
extends Node3D
## Owns the map, active entities and every combat rule that touches several objects.
## Spawning and damage live here so a multiplayer host can run them alone later.

signal player_died
signal dawn_reached
signal fort_lost

static var HALF_SIZE := 110.0
const PATHS_PER_FRAME := 1
const SKY_EVERY := 0.15
const BELL_GAP := 0.5
const NIGHT_BG := Color(0.035, 0.055, 0.1)
const DAWN_BG := Color(0.78, 0.6, 0.46)
const NIGHT_AMBIENT := Color(0.34, 0.42, 0.62)
const DAWN_AMBIENT := Color(0.74, 0.66, 0.68)
const NIGHT_FOG := Color(0.05, 0.08, 0.13)
const DAWN_FOG := Color(0.92, 0.66, 0.46)

static var _shadow_mesh: QuadMesh
static var _arrow_mesh: Mesh
static var _stone_mesh: Mesh
static var _fireball_mesh: Mesh
static var _bolt_mesh: ArrayMesh
static var _axe_proj: Mesh
static var _orb_meshes := {}
static var _glow_material_cache := {}
static var _flame_mesh: BoxMesh
static var _warmed_quality := -1
static var _lands := {} # the land takes a moment to work out, and it never changes

var stone_chains: Array = [] # each line of stones in the Mists, in order, by the middle of each top
var mode: int = Game.Mode.MENU
var grid: PathGrid
var terrain: Terrain
var fort: Fort
var wood_spots: Array[Vector3] = []
var yard_wood_spots: Array[Vector3] = []
var map_roads: Array = []
var weather: Weather
var fog: ClosingFog
var play_half := 110.0
var start_spots: Array[Vector3] = []
var dummy_spots: Array[Vector3] = []
var rival_spots: Array[Vector3] = []
var stands: Array[Dictionary] = [] # the Sandbox's rows of things to try
var _enemy_blocks: StaticBody3D
var portals: MistPortals
var caches: MistCaches
var _ledge_body: StaticBody3D
var night_bg := NIGHT_BG
var night_ambient := NIGHT_AMBIENT
var night_fog_colour := NIGHT_FOG
var night_fog := 0.03
var day_fog := 0.006
var night_sky_shows := true
var night_moon_colour := Color(0.6, 0.7, 1.0)
var night_moon := 0.5
const FALL_DEATH := -12.0 # below this on the islands, you have fallen off the world
var director: Director
var player: Player
var players: Array[Target] = []
var allies: Array[Ally] = []
var _spare_allies := {} # kind -> resting bodies, ready to be used again
var bell: Node3D
var church_door := Vector3(0, 0, -36)
var zombies: Array[Zombie] = []
var pickups: Array[Pickup] = []
var loot_spots: Array[Vector3] = []
const PICKUP_APART := 6.0
var perches: Array[Vector3] = []
var crop_spots: Array[Vector3] = []
var pois: Array[Vector3] = []
var menu_camera: Camera3D

var _body: StaticBody3D
var _barriers: StaticBody3D
var _spinners: Array[Dictionary] = []
var _water_material: ShaderMaterial
var _pools := {}
var _by_id: Array[Zombie] = []
var _pickup_ids := {}
var _next_pickup_id := 1
var _warming := false
var _next_crow_dive := 0.0
var fires: Array[Dictionary] = [] # {at, radius, heals, light}
var _fire_timer := 0.0
var _mist_pool: Array[CPUParticles3D] = []
var _next_mist := 0
var _dome: MeshInstance3D
var _dome_left := 0.0
var _ally_seq := 0
var _remote_allies := {} # "peer:index" -> Ally
var map_marks: Array[Dictionary] = []
var indoors: Array[Rect2] = []
var _projectiles: Array[Projectile] = []
var _impacts: Array[Sprite3D] = []
var _impact_life: Array[float] = []
var _gore: Array[CPUParticles3D] = []
var _bolt: MeshInstance3D
var _bolt_life := 0.0
var _next_impact := 0
var _next_gore := 0
var _scan_timer := 0.0
var _orbit := 0.0
var _path_budget := 0
var _env: Environment
var _moon: DirectionalLight3D
var _sky_root: Node3D
var _night_dome: MeshInstance3D
var _star_material: StandardMaterial3D
var _burn_lights: Array[OmniLight3D] = []
var _burning: Array[Zombie] = []
var _bell_swing := 0.0
var _bell_strokes := 0
var _bell_wait := 0.0
var _blast: MeshInstance3D
var _blast_mat: StandardMaterial3D
var _blast_life := 0.0
var _puddles: Array[MeshInstance3D] = []
var _puddle_life: Array[float] = []
var _puddle_fire: Array[bool] = []
var _puddle_size: Array[float] = []
var _puddle_shown_only: Array[bool] = []
var _puddle_hurts_me: Array[bool] = []
var _sparks: Array[MeshInstance3D] = []
var _spark_life: Array[float] = []
var _next_spark := 0
var _sentries: Array[Dictionary] = []
var _sentry_look: Mesh
var _stand_items: Array[Dictionary] = []
var _fire_puddle: StandardMaterial3D
var _rings: Array[Dictionary] = []
var _aim_ring: MeshInstance3D
var _next_ring := 0
const RING_TIME := 0.55
var _next_puddle := 0
var _poison_tick := 0.0
var _traps: Array[Dictionary] = []
static var _trap_mesh: Mesh
var _lanterns: Array[OmniLight3D] = []
var _sky_material: ShaderMaterial
var _dawn_done := false
var _sky_timer := 0.0
var _sky_value := -1.0
var _last_dawn := 0.0
var _ambient_now := 0.5
var _moon_now := 0.5
var _moon_colour := Color(0.6, 0.7, 1.0)
var _fog_now := 0.03
var _fog_thick := 1.0
var now := 0.0 # game seconds: unlike the system clock, these stop during a pause


static func make_blob_shadow(size: float) -> MeshInstance3D:
	if _shadow_mesh == null:
		_shadow_mesh = QuadMesh.new()
		_shadow_mesh.size = Vector2(1.4, 1.4)
		_shadow_mesh.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = load("res://assets/sprites/blob_shadow.png")
		m.albedo_color = Color(0, 0, 0, 0.55)
		_shadow_mesh.material = m
	var s := MeshInstance3D.new()
	s.mesh = _shadow_mesh
	s.scale = Vector3(size, 1, size)
	s.position.y = 0.06
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


static func make_flames() -> CPUParticles3D:
	if _flame_mesh == null:
		_flame_mesh = BoxMesh.new()
		_flame_mesh.size = Vector3.ONE * 0.13
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mesh.material = m
	var p := CPUParticles3D.new()
	p.mesh = _flame_mesh
	p.amount = 14
	p.lifetime = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.22, 0.65, 0.22)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.25))
	ramp.set_color(1, Color(0.85, 0.15, 0.03))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


func setup(game_mode: int) -> void:
	mode = game_mode
	var file := _map_file()
	var map: MapRoot = (load(file) as PackedScene).instantiate()
	Terrain.use_half(map.land_half)
	HALF_SIZE = float(map.land_half)
	grid = PathGrid.new(int(HALF_SIZE * 2.0))
	if not _lands.has(file):
		var t := Terrain.new()
		map.plan_land(t)
		_lands[file] = t
	terrain = _lands[file]
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_barriers = StaticBody3D.new()
	_barriers.collision_layer = Terrain.BARRIER
	_barriers.collision_mask = 0
	add_child(_barriers)
	_enemy_blocks = StaticBody3D.new()
	_enemy_blocks.collision_layer = Terrain.ENEMY_ONLY
	_enemy_blocks.collision_mask = 0
	add_child(_enemy_blocks)
	var ground := StaticBody3D.new()
	ground.collision_layer = Terrain.LAYER
	ground.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = terrain.collision_shape()
	ground.add_child(ground_shape)
	add_child(ground)
	_build_environment()
	var builder := MapBuilder.new(self, terrain)
	builder.quality = Game.quality
	builder.grass_tufts = Game.grass_count()
	builder.skip_beyond = mode == Game.Mode.MENU
	builder.build(map)
	map.free()
	grid.astar.update()
	grid.build_far_grid()
	if terrain.has_islands():
		_mists_look()
	_build_fx()
	director = Director.new(self)
	add_child(director)
	if mode == Game.Mode.MENU:
		menu_camera = Camera3D.new()
		menu_camera.far = 130.0
		menu_camera.fov = 58.0
		add_child(menu_camera)
		director.set_process(false)
		_apply_sky(0.0)
		return
	weather = Weather.new(self)
	add_child(weather)
	if Net.fog_rules():
		fog = ClosingFog.new(self, Net.fog_centre)
		add_child(fog)
	_build_zombie_pools()
	prepare_allies("ghost", 1)
	player = Player.new(self)
	add_child(player)
	var start: Vector3 = start_spots[0] if not start_spots.is_empty() else Vector3.ZERO
	player.position = Vector3(start.x, ground_at(start) + 0.05, start.z)
	if fort:
		fort.fallen.connect(_on_fort_fallen)
	players.append(player)
	if Net.active():
		Net.attach(self)
		director.join_game(Net.is_client())
	elif mode == Game.Mode.SANDBOX:
		director.begin_sandbox()
	else:
		director.begin(true)
	_scan_pickups()
	_apply_sky(0.0)
	_start_weather()


## The host picked tonight's weather for everyone. The Sandbox stays dry until you ask for rain.
func _start_weather() -> void:
	var kind: int = Weather.Kind.CLEAR
	if mode != Game.Mode.SANDBOX:
		kind = Game.force_weather if Game.force_weather >= 0 else (Net.weather if Net.active() else Weather.roll())
	weather.set_kind(kind)
	if not Net.is_client() and kind != Weather.Kind.CLEAR:
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			if is_instance_valid(self) and director:
				director.show_banner(weather.opening_words(), 3.5))


## Clouds hide the stars and thicken the air. Called when the weather changes, and by the sky itself.
func weather_changed() -> void:
	_sky_value = -1.0
	_apply_sky(_last_dawn)


## Standing out in the deadly fog, you cannot see far.
func set_fog_thickness(amount: float) -> void:
	if not is_equal_approx(amount, _fog_thick):
		_fog_thick = amount
		_env.fog_density = _fog_now * _fog_thick


## Lightning lights up the whole world for a moment.
func show_lightning(amount: float) -> void:
	_sky_material.set_shader_parameter("flash", amount)
	_env.ambient_light_energy = _ambient_now + amount * 1.5
	_moon.light_energy = _moon_now + amount * 1.6
	if amount > 0.0:
		_moon.light_color = Color(0.8, 0.88, 1.0)
	else:
		_moon.light_color = _moon_colour


## Which map scene this game is on. Pressing F6 on a map in the editor overrides it.
func _map_file() -> String:
	if Game.test_map != "":
		return Game.test_map
	match mode:
		Game.Mode.FORT: return "res://maps/fort.tscn"
		Game.Mode.SANDBOX: return "res://maps/sandbox.tscn"
		Game.Mode.NIGHT:
			if Game.current_map() == "mists":
				return "res://maps/mists.tscn"
	return "res://maps/village.tscn"


# --- Map helpers used by MapBuilder ------------------------------------------

func start_fort() -> void:
	fort = Fort.new(self)
	add_child(fort)
	church_door = Vector3(0, 0, 8)


## True when a transform is turned by some number of quarter turns, so a plain box will do.
func _square_on(t: Transform3D) -> int:
	var yaw := t.basis.get_euler().y
	var quarter := yaw / (PI * 0.5)
	if absf(quarter - round(quarter)) < 0.01:
		return posmod(int(round(quarter)), 2)
	return -1


func add_solid_xf(t: Transform3D, size: Vector3) -> void:
	var turns := _square_on(t)
	if turns >= 0:
		add_solid(t.origin, size if turns == 0 else Vector3(size.z, size.y, size.x))
		return
	add_rotated_collider(t, size)
	if t.origin.y - size.y * 0.5 - ground_at(t.origin) < 1.8:
		grid.block_turned(t, size)


func add_collider_xf(t: Transform3D, size: Vector3) -> void:
	var turns := _square_on(t)
	if turns >= 0:
		add_collider(t.origin, size if turns == 0 else Vector3(size.z, size.y, size.x))
	else:
		add_rotated_collider(t, size)


func add_barrier_xf(t: Transform3D, size: Vector3) -> void:
	var turns := _square_on(t)
	if turns >= 0:
		add_barrier(t.origin, size if turns == 0 else Vector3(size.z, size.y, size.x))
		return
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = t
	_barriers.add_child(cs)
	grid.block_turned(t, size)


## A solid with any shape, given by the corners of its hull.
func add_wedge(t: Transform3D, points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = t
	_body.add_child(cs)


func grid_block_turned(t: Transform3D, size: Vector3) -> void:
	grid.block_turned(t, size)


func grid_mark_crops(t: Transform3D, size: Vector2) -> void:
	grid.mark_crops_turned(t, size)



func ground_at(at: Vector3) -> float:
	var h := terrain.height(at.x, at.z)
	if h < FALL_DEATH and terrain.has_islands():
		return terrain.island_floor(at.x, at.z) # over the void, what flies stays level with the islands
	return h


func add_barrier(at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	_barriers.add_child(cs)
	grid.block_box(at, size)


## A flock takes turns, so there is always time to deal with the crow that is coming.
func take_dive_turn() -> bool:
	if now < _next_crow_dive:
		return false
	_next_crow_dive = now + 1.5
	return true


## Firelight: you can see in it, and you can be seen in it.
func add_fire(at: Vector3, radius: float, light: OmniLight3D = null, heals := false) -> void:
	fires.append({"at": at, "radius": radius, "light": light, "heals": heals, "phase": randf() * 6.0})


func in_firelight(p: Vector3) -> bool:
	for f: Dictionary in fires:
		if p.distance_squared_to(f["at"]) < float(f["radius"]) * float(f["radius"]):
			return true
	return false


func beside_bonfire(p: Vector3) -> bool:
	for f: Dictionary in fires:
		if f["heals"] and p.distance_squared_to(f["at"]) < 18.0:
			return true
	return false


## Only fires near the player cast light, because a phone can only afford a few.
func _tick_fires(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = 0.1
	var cam := _player_camera_position()
	var t := Time.get_ticks_msec() * 0.001
	var bright := smoothstep(0.25, 1.0, _sky_value) if _sky_value > 0.0 else 0.0
	for f: Dictionary in fires:
		var l: OmniLight3D = f["light"]
		if l == null:
			continue
		var near := cam.distance_squared_to(f["at"]) < 3600.0
		l.visible = near
		if near:
			var ph: float = f["phase"]
			l.light_energy = lerpf(2.5, 0.3, bright) * (0.86 + 0.14 * sin(t * 9.0 + ph) * sin(t * 5.3 + ph * 2.0))


## Something only enemies bump into, like the small doors of the fort.
func add_enemy_block(at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	_enemy_blocks.add_child(cs)
	grid.block_box(at, size)


func add_rotated_collider(xf: Transform3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	_body.add_child(cs)


func _on_fort_fallen() -> void:
	if Net.is_host():
		Net.finish("The heart has fallen", "The fort lasted until %s.\n%s" % [Game.clock(director.night_left()), Net.score_lines()])
	elif not Net.active():
		fort_lost.emit()


func add_spinner(node: Node3D, axis: Vector3, speed: float) -> void:
	_spinners.append({"node": node, "axis": axis, "speed": speed})


func set_water(m: ShaderMaterial) -> void:
	_water_material = m


## Solid for players and nothing else, for what hangs in the air: mobs walk by the map's grid.
func add_ledge(xf: Transform3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	_ledges().add_child(cs)


## A round stone to land on. at is the middle of its top.
## The line of stones nearest someone standing on one, and which stone: x is -1 if they are on none.
func stone_near(p: Vector3) -> Vector2i:
	for line in stone_chains.size():
		var chain: Array = stone_chains[line]
		for i in chain.size():
			var top: Vector3 = chain[i]
			if absf(top.y - p.y) < 3.0 and Vector2(top.x - p.x, top.z - p.z).length() < 2.8:
				return Vector2i(line, i)
	return Vector2i(-1, -1)


func add_stone(at: Vector3, radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at + Vector3.DOWN * 0.25
	_ledges().add_child(cs)


func _ledges() -> StaticBody3D:
	if _ledge_body == null:
		_ledge_body = StaticBody3D.new()
		_ledge_body.collision_layer = Terrain.LAYER
		_ledge_body.collision_mask = 0
		add_child(_ledge_body)
	return _ledge_body


func add_collider(at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	_body.add_child(cs)


func add_solid(at: Vector3, size: Vector3) -> void:
	add_collider(at, size)
	if at.y - size.y * 0.5 - ground_at(at) < 1.8:
		grid.block_box(at, size)


func add_lantern_light(l: OmniLight3D) -> void:
	_lanterns.append(l)


func add_glow(at: Vector3, col: Color, size: float, fade_at := 0.0) -> void:
	if not _glow_material_cache.has(col):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = load("res://assets/sprites/glow.png")
		m.albedo_color = Color(col, 0.75)
		m.disable_fog = true
		_glow_material_cache[col] = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _glow_material_cache[col]
	var g := MeshInstance3D.new()
	g.mesh = q
	g.position = at
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_range_end = fade_at
	add_child(g)


# --- Night, fog and sky ------------------------------------------------------

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.0
	_env.fog_density = 0.03
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(-48, -32, 0)
	_moon.shadow_enabled = Game.quality == 2
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_moon.directional_shadow_max_distance = 45.0
	add_child(_moon)
	_build_sky()


## A violet night with nothing under it.
func _mists_look() -> void:
	night_bg = Color(0.3, 0.52, 0.58)
	night_fog_colour = Color(0.4, 0.66, 0.7)
	night_fog = 0.0062 if Game.quality > 0 else 0.011
	day_fog = 0.0035 if Game.quality > 0 else 0.008
	night_ambient = Color(0.74, 0.8, 0.76)
	night_sky_shows = false
	# The sky has to be further off than the furthest island, or it paints over them.
	_sky_root.scale = Vector3.ONE * 4.6
	night_moon_colour = Color(1.0, 0.94, 0.82)
	night_moon = 0.62
	_sky_material.set_shader_parameter("tint", Vector3(7.4, 8.0, 5.0))
	_sky_value = -1.0
	_apply_sky(_last_dawn)


func _build_sky() -> void:
	_sky_root = Node3D.new()
	add_child(_sky_root)
	var dome := SphereMesh.new()
	dome.radius = 96.0
	dome.height = 192.0
	dome.radial_segments = 24
	dome.rings = 12
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load("res://assets/shaders/sky.gdshader")
	# The sky goes first, or it paints over see-through things like names and glows.
	_sky_material.render_priority = -100
	dome.material = _sky_material
	var dome_node := MeshInstance3D.new()
	dome_node.mesh = dome
	dome_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome_node.extra_cull_margin = 400.0
	_sky_root.add_child(dome_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var l := LowPoly.new()
	# Stars, and a moon placed where the light comes from.
	for i in 150:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.08, 1), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.14, 0.36)
		l.box(d * 90.0, Vector3(s, s, s), Color(0.8, 0.85, 1.0) * rng.randf_range(0.55, 1.0))
	var moon_dir := Vector3(0.4, 0.68, 0.61).normalized()
	l.prism(moon_dir * 88.0, moon_dir * 89.0, 4.2, 4.2, 12, Color(0.92, 0.94, 1.0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = -99
	_star_material = mat
	var stars := l.commit()
	stars.surface_set_material(0, mat)
	_night_dome = MeshInstance3D.new()
	_night_dome.mesh = stars
	_night_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_night_dome.extra_cull_margin = 200.0
	_sky_root.add_child(_night_dome)


## 0 is deep night and 1 is sunrise. Colours, light angle, shadows and fog all move together.
func _apply_sky(dawn: float) -> void:
	if is_equal_approx(dawn, _sky_value):
		return
	_sky_value = dawn
	_last_dawn = dawn
	var wet := weather != null and weather.is_wet()
	_sky_material.set_shader_parameter("cloud", 1.0 if wet else 0.0)
	var warm := smoothstep(0.0, 0.7, dawn)
	var bright := smoothstep(0.25, 1.0, dawn)
	_sky_material.set_shader_parameter("dawn", dawn)
	if _water_material:
		_water_material.set_shader_parameter("dawn", bright)
	_sky_material.set_shader_parameter("sun_dir", _sun_direction(dawn))
	_star_material.albedo_color = Color(1, 1, 1, clampf(1.0 - dawn * 1.8, 0.0, 1.0))
	_night_dome.visible = dawn < 0.56 and not wet and night_sky_shows
	_env.background_color = night_bg.lerp(DAWN_BG, bright)
	_env.ambient_light_color = night_ambient.lerp(DAWN_AMBIENT, warm)
	_ambient_now = lerpf(0.5, 0.8, bright) * (0.9 if wet else 1.0)
	_env.ambient_light_energy = _ambient_now
	_env.fog_light_color = night_fog_colour.lerp(DAWN_FOG, warm)
	_fog_now = lerpf(night_fog, day_fog, bright) * (1.35 if wet else 1.0)
	_env.fog_density = _fog_now * _fog_thick
	_moon.rotation_degrees = Vector3(lerpf(-48.0, -13.0, bright), lerpf(-32.0, -150.0, bright), 0.0)
	_moon_colour = night_moon_colour.lerp(Color(1.0, 0.68, 0.42), warm)
	_moon.light_color = _moon_colour
	_moon_now = lerpf(night_moon, 1.35, bright) * (0.55 if wet else 1.0)
	_moon.light_energy = _moon_now
	for l in _lanterns:
		l.light_energy = lerpf(2.0, 0.25, bright)
	if player:
		player.set_dawn_light(bright)


func _sun_direction(dawn: float) -> Vector3:
	var elevation := deg_to_rad(lerpf(-14.0, 13.0, smoothstep(0.1, 1.0, dawn)))
	var azimuth := deg_to_rad(-150.0)
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)).normalized()


func _player_camera_position() -> Vector3:
	if Net.spectate_cam and is_instance_valid(Net.spectate_cam) and Net.spectate_cam.current:
		return Net.spectate_cam.global_position
	if player:
		return player.camera.global_position
	return menu_camera.global_position if menu_camera else Vector3.ZERO


# --- Frame update ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_path_budget = PATHS_PER_FRAME
	now += delta


func take_path_budget() -> bool:
	if _path_budget <= 0:
		return false
	_path_budget -= 1
	return true


func _process(delta: float) -> void:
	_tick_fx(delta)
	for s: Dictionary in _spinners:
		(s["node"] as Node3D).rotate_object_local(s["axis"], float(s["speed"]) * delta)
	_tick_fires(delta)
	_sky_root.position = _player_camera_position()
	if mode == Game.Mode.MENU:
		_orbit += delta * 0.05
		menu_camera.position = Vector3(cos(_orbit) * 30.0, 11.0, sin(_orbit) * 30.0)
		menu_camera.look_at(Vector3(0, 1.5, 0))
		return
	if player and not player.dead:
		player.poll_keyboard()
	_tick_bell(delta)
	_tick_poison(delta)
	_tick_rings(delta)
	_tick_traps(delta)
	_tick_sentries(delta)
	# The light changes slowly, so a few updates a second look the same and cost less.
	_sky_timer -= delta
	if _sky_timer <= 0.0:
		_sky_timer = SKY_EVERY
		if director.running or _dawn_done:
			var d := 1.0 if _dawn_done else director.dawn_amount()
			_apply_sky(d)
			# The drums keep going through the last stand. The warm music waits for the very end.
			Sfx.set_mood(1.0 if count_hunting() > 0 else 0.0, smoothstep(0.5, 1.0, d))
		else:
			Sfx.set_mood(0.0, 0.0)
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.12
		_scan_pickups()
	_tick_burn_lights()


func _tick_fx(delta: float) -> void:
	for i in _impacts.size():
		if _impact_life[i] > 0.0:
			_impact_life[i] -= delta
			if _impact_life[i] <= 0.0:
				_impacts[i].visible = false
	if _bolt_life > 0.0:
		_bolt_life -= delta
		_bolt.visible = _bolt_life > 0.0 and fmod(_bolt_life, 0.08) > 0.03
	if _dome_left > 0.0:
		_dome_left -= delta
		if _dome_left <= 0.0:
			_dome.visible = false
	if _blast_life > 0.0:
		_blast_life -= delta
		_blast.scale *= 1.0 + delta * 2.0
		if _blast_life <= 0.0:
			_blast.visible = false
	for i in _sparks.size():
		if _spark_life[i] > 0.0:
			_spark_life[i] -= delta
			if _spark_life[i] <= 0.0:
				_sparks[i].visible = false


# --- Queries -----------------------------------------------------------------

func nearest_player(from: Vector3) -> Target:
	var best: Target = null
	var best_d := INF
	for p in players:
		if p.dead:
			continue
		var d := from.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Zombies go for whoever is closest, so summons draw attacks away from the player.
func nearest_target(from: Vector3) -> Target:
	var best: Target = nearest_player(from)
	var best_d := INF
	if best:
		best_d = from.distance_squared_to(best.global_position)
	for a in allies:
		if a.dead:
			continue
		var d := from.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func nearest_zombie(from: Vector3, radius: float, need_sight: bool) -> Zombie:
	var best: Zombie = null
	var best_d := radius * radius
	for z in zombies:
		if not z.is_alive() or z.dormant:
			continue
		var d := z.centre().distance_squared_to(from)
		if d < best_d and (not need_sight or has_line_of_sight(from, z.centre())):
			best_d = d
			best = z
	return best


func nearest_zombie_excluding(from: Vector3, radius: float, excluded: Array[RID]) -> Zombie:
	var best: Zombie = null
	var best_d := radius * radius
	for z in zombies:
		if not z.is_alive() or z.dormant or excluded.has(z.get_rid()):
			continue
		var d := z.centre().distance_squared_to(from)
		if d < best_d and has_line_of_sight(from, z.centre()):
			best_d = d
			best = z
	return best


func nearest_weapon_pickup(from: Vector3, radius: float) -> Pickup:
	var best: Pickup = null
	var best_d := radius * radius
	for p in pickups:
		if p.kind != Pickup.Kind.WEAPON:
			continue
		var d := p.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = p
	return best


func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | Terrain.LAYER)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func count_living() -> int:
	var n := 0
	for z in zombies:
		if z.is_alive():
			n += 1
	return n


func count_type(id: String) -> int:
	var n := 0
	for z in zombies:
		if z.is_alive() and z.type_id == id:
			n += 1
	return n


func count_hunting() -> int:
	var n := 0
	for z in zombies:
		if z.is_hunting():
			n += 1
	return n


## One zombie that spots you alerts the others around it, and they know where you are.
func call_horde(caller: Zombie, at: Vector3, radius: float) -> void:
	var r2 := radius * radius
	for z in zombies:
		if z != caller and z.is_alive() and z.position.distance_squared_to(caller.position) < r2:
			z._start_chase(at)


## Every zombie learns where its nearest player is.
func call_all_to_players() -> void:
	for z in zombies:
		if z.is_alive():
			var p := nearest_player(z.position)
			if p:
				z._start_chase(p.global_position)


func call_all(at: Vector3) -> void:
	for z in zombies:
		if z.is_alive():
			z._start_chase(at)


## What area abilities do to other players in a fight. Returns how many there were.
func status_rivals(at: Vector3, radius: float, kind: int, seconds: float) -> int:
	var near := rivals_near(at, radius)
	for r: Avatar in near:
		Net.status_peer(r.peer, kind, seconds)
	return near.size()


func nearest_rival(from: Vector3, radius: float) -> Avatar:
	var best: Avatar = null
	var best_d := radius * radius
	for r: Avatar in rivals_near(from, radius):
		var d := r.global_position.distance_squared_to(from)
		if d < best_d and has_line_of_sight(from, r.eye_position()):
			best_d = d
			best = r
	return best


func slow_around(at: Vector3, radius: float, seconds: float) -> int:
	fx_ring(at, radius, Color(0.55, 0.85, 1.0))
	var n := status_rivals(at, radius, Net.Status.SLOW, seconds)
	for z in zombies:
		if z.is_alive() and z.position.distance_to(at) <= radius:
			z.slow(seconds)
			n += 1
	return n


func burn_around(at: Vector3, radius: float) -> int:
	fx_ring(at, radius, Color(1.0, 0.55, 0.15))
	var n := status_rivals(at, radius, Net.Status.BURN, ZombieDefs.BURN_SECONDS)
	for z in zombies:
		if z.is_alive() and z.position.distance_to(at) <= radius:
			z.ignite(ZombieDefs.BURN_SECONDS)
			n += 1
	return n


func forget_around(at: Vector3, radius: float) -> int:
	var n := 0
	for z in zombies:
		if z.is_alive() and z.position.distance_to(at) <= radius:
			z.forget()
			n += 1
	return n


func zombies_near(at: Vector3, radius: float, limit: int) -> Array[Zombie]:
	var out: Array[Zombie] = []
	for z in zombies:
		if z.is_alive() and not z.dormant and z.position.distance_to(at) <= radius:
			out.append(z)
			if out.size() >= limit:
				break
	return out


func ally_near(at: Vector3, radius: float) -> bool:
	for a in allies:
		if not a.dead and a.position.distance_to(at) <= radius:
			return true
	return false


func count_allies(kind: String) -> int:
	var n := 0
	for a in allies:
		if a.kind == kind and not a.dead:
			n += 1
	return n


func stun_around(at: Vector3, radius: float, seconds: float) -> int:
	fx_ring(at, radius, Color(1.0, 0.85, 0.35))
	var n := status_rivals(at, radius, Net.Status.STUN, seconds)
	for z in zombies:
		if z.is_alive() and z.position.distance_to(at) <= radius:
			z.stun(seconds)
			n += 1
	return n


func make_noise(at: Vector3, radius: float) -> void:
	if Net.is_client():
		Net.noise(at, radius)
		return
	var r2 := radius * radius
	for z in zombies:
		if z.position.distance_squared_to(at) < r2:
			z.hear(at)


## Gentle touch-screen aim help: bends a shot that barely misses onto the target.
func assist_aim(origin: Vector3, dir: Vector3, max_range: float) -> Vector3:
	const CONE := 0.9984 # about 3.2 degrees
	var best: Zombie = null
	var best_dot := CONE
	var aim := dir
	for z in zombies:
		if not z.is_alive() or z.dormant:
			continue
		var to := z.centre() - origin
		var d := to.length()
		if d > max_range or d < 0.01:
			continue
		var dot := (to / d).dot(dir)
		if dot > best_dot:
			best_dot = dot
			best = z
			aim = to / d
	if best and has_line_of_sight(origin, best.centre()):
		return aim
	return dir


# --- Combat ------------------------------------------------------------------

func melee_hit(attacker: Player, d: Dictionary, stats: Dictionary) -> int:
	var origin := attacker.eye_position()
	var forward := -attacker.camera.global_basis.z
	var range_m: float = stats["range"]
	var flat_forward := Vector3(forward.x, 0, forward.z).normalized()
	var half_cone := deg_to_rad(minf(float(stats["cone"]), 359.0) * 0.5)
	var cos_limit := cos(half_cone)
	var left: int = stats["hits"]
	var hits := 0
	for z: Zombie in zombies.duplicate():
		if left <= 0:
			break
		if not z.is_alive():
			continue
		var centre := z.centre()
		var to := centre - origin
		var flat := Vector3(to.x, 0, to.z)
		var dist := flat.length()
		# What counts is the edge of the body, not its middle.
		var body := z.body_radius()
		if dist > range_m + body or absf(to.y) > 3.0:
			continue
		if dist > 0.7 and (flat / dist).dot(flat_forward) < cos(minf(half_cone + atan2(body, dist), PI)):
			continue
		if not has_line_of_sight(origin, centre):
			continue
		damage_zombie(z, attacker.modify_damage(z, float(stats["damage"])), forward, float(stats["knock"]), centre, false)
		attacker.on_melee_connect(z, d)
		hits += 1
		left -= 1
	if Net.pvp():
		hits += _melee_rivals(attacker, origin, flat_forward, range_m, cos_limit, float(stats["damage"]))
	return hits


func _melee_rivals(attacker: Player, origin: Vector3, flat_forward: Vector3, range_m: float, cos_limit: float, damage: float) -> int:
	var hits := 0
	for t in players:
		if not t is Avatar or t.dead or not Net.is_foe((t as Avatar).peer):
			continue
		var centre: Vector3 = t.global_position + Vector3.UP * 1.0
		var to := centre - origin
		var flat := Vector3(to.x, 0, to.z)
		var dist := flat.length()
		if dist > range_m + 0.35 or absf(to.y) > 3.0:
			continue
		if dist > 0.7 and (flat / dist).dot(flat_forward) < cos_limit:
			continue
		if has_line_of_sight(origin, centre):
			Net.hit_player((t as Avatar).peer, damage, attacker.global_position)
			fx_gore(centre, Color(0.6, 0.1, 0.08))
			attacker.on_hit(false)
			attacker.on_melee_rival((t as Avatar).peer, attacker.weapon_def())
			hits += 1
	return hits


func damage_zombie(z: Zombie, amount: float, dir: Vector3, knock: float, at: Vector3, head_shot: bool) -> void:
	z.take_damage(amount, dir, knock, at)
	if player:
		player.on_hit(head_shot)


## from_hand is false for familiars and hawks, whose arrows do not count as the player's own shots.
func _shot_mesh(id: String) -> Mesh:
	match id:
		"javelin":
			return WeaponDefs.mesh("javelins")
		"stone":
			if _stone_mesh == null:
				var l := LowPoly.new()
				l.box(Vector3.ZERO, Vector3(0.09, 0.09, 0.09), Color(0.5, 0.5, 0.48))
				_stone_mesh = l.commit()
			return _stone_mesh
	return _arrow_mesh


func spawn_player_arrow(p: Player, at: Vector3, vel: Vector3, grav: float, max_range: float, knock: float, dmg: float, from_hand := true) -> void:
	var bounce := int(p.m("bounces")) + (PowerDefs.BOUNCES if p.has_power("bounce_arrows") else 0)
	var burning := p.has_power("fire_arrows") or (p.is_riding() and (p.has_flag("riding_fire") or p.has_flag("war_machine")))
	var d := p.weapon_def() if from_hand else {}
	var shot := _launch(Projectile.Kind.ARROW, _shot_mesh(str(d.get("shot", ""))), at, vel, grav, max_range, dmg, knock, burning, bounce)
	if shot:
		shot.pierce = int(p.m("pierce")) + int(d.get("pierce", 0))
		shot.poison = d.get("poison", Vector2.ZERO)
		shot.stagger = float(d.get("stagger", 0.0))
		shot.sharp = p.has_flag("sharpshooter")
		shot.from_player = from_hand
		if Net.active():
			Net.shot(0, at, vel, grav, max_range, burning, Color.WHITE)


func familiar_arrow(p: Player, target: Node3D) -> void:
	var from := p.eye_position() + p.camera.global_basis.x * -0.4 + Vector3.UP * 0.25
	var aim: Vector3 = (target as Zombie).centre() if target is Zombie else target.global_position + Vector3.UP
	var dir := (aim - from).normalized()
	spawn_player_arrow(p, from, dir * 40.0, 0.0, PowerDefs.ARCHER_RANGE + 5.0, 1.0, WeaponDefs.DAMAGE * p.damage_multiplier(), false)
	Sfx.play("bow", -9.0, 1.2)


func spawn_axe(p: Player, at: Vector3, vel: Vector3, max_range: float, knock: float, dmg: float) -> void:
	var shot := _launch(Projectile.Kind.AXE, _axe_proj, at, vel, 0.0, max_range, dmg, knock)
	if shot == null:
		p.axe_returned()
	else:
		shot.from_player = true
		if Net.active():
			Net.shot(1, at, vel, 0.0, max_range, false, Color.WHITE)


func spawn_bolt(p: Player, at: Vector3, vel: Vector3, max_range: float, knock: float, dmg: float, meteor: bool, element := "") -> void:
	var col := Color(0.55, 0.75, 1.0)
	match element:
		"fire": col = Color(1.0, 0.5, 0.12)
		"frost": col = Color(0.65, 0.95, 1.0)
		"storm": col = Color(0.95, 0.9, 0.4)
	var bounce := int(p.m("bounces")) + (2 if element == "storm" else 0)
	var shot := _launch(Projectile.Kind.BOLT, _orb_mesh(col), at, vel, 0.0, max_range, dmg, knock, element == "fire", bounce)
	if Net.active():
		Net.shot(2, at, vel, 0.0, max_range, element == "fire", col)
	if shot:
		shot.from_player = true
		shot.frost = element == "frost"
		if meteor:
			shot.blast_radius = 5.0
			shot.scale = Vector3.ONE * 2.0
		else:
			shot.scale = Vector3.ONE


func mirror_bolt(from: Vector3, target: Vector3) -> void:
	_launch(Projectile.Kind.BOLT, _orb_mesh(Color(0.75, 0.55, 1.0)), from, (target - from).normalized() * 26.0, 0.0, 26.0, WeaponDefs.DAMAGE, 1.0)
	sfx_at("spell", from, -8.0)


func _orb_mesh(col: Color) -> Mesh:
	if _orb_meshes.has(col):
		return _orb_meshes[col]
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	sphere.radial_segments = 8
	sphere.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	sphere.material = m
	_orb_meshes[col] = sphere
	return sphere


## Area damage from a meteor or an explosive arrow.
func blast(at: Vector3, radius: float, damage: float) -> void:
	fx_blast(at, radius, Color(1.0, 0.55, 0.15, 0.55))
	Sfx.play("blast", -2.0, 1.0, 0.1)
	make_noise(at, 16.0)
	for z: Zombie in zombies.duplicate():
		if z.is_alive() and z.centre().distance_to(at) <= radius:
			z.take_damage(damage, z.position - at, 5.0, z.centre())
			if player:
				player.on_hit(false)
	for r: Avatar in rivals_near(at, radius):
		Net.hit_player(r.peer, damage, at)


func flash_bolt(at: Vector3) -> void:
	_bolt.global_position = Vector3(at.x, ground_at(at), at.z)
	_bolt.rotation.y = randf() * TAU
	_bolt.visible = true
	_bolt_life = 0.22


func thunder_strike(p: Player, at: Vector3) -> void:
	flash_bolt(at)
	Sfx.play("thunder", -3.0, 1.0, 0.2)
	for z: Zombie in zombies.duplicate():
		if z.is_alive() and z.position.distance_to(at) <= PowerDefs.THUNDER_RADIUS:
			z.take_damage(PowerDefs.THUNDER_DAMAGE * p.damage_multiplier(), z.position - at, 4.0, z.centre())
			p.on_hit(false)
	for r: Avatar in rivals_near(at, PowerDefs.THUNDER_RADIUS):
		Net.hit_player(r.peer, PowerDefs.THUNDER_DAMAGE * p.damage_multiplier(), at)
	fx_gore(at + Vector3.UP * 0.5, Color(0.7, 0.85, 1.0))


func spawn_fireball(at: Vector3, target: Vector3, damage: float, source := "") -> void:
	if Net.is_host():
		Net.enemy_shot(true, at, target, damage, 32.0, true, source)
	var shot := _launch(Projectile.Kind.FIREBALL, _fireball_mesh, at, (target - at).normalized() * 15.0, 0.0, 32.0, damage)
	if shot:
		shot.source = source
	sfx_at("fireball", at, -6.0)


func spawn_enemy_arrow(at: Vector3, target: Vector3, damage: float, max_range: float, burning := false, source := "") -> void:
	if Net.is_host():
		Net.enemy_shot(false, at, target, damage, max_range, burning, source)
	var shot := _launch(Projectile.Kind.ENEMY_ARROW, _arrow_mesh, at, (target - at).normalized() * 26.0, 0.0, max_range + 4.0, damage, 0.0, burning)
	if shot:
		shot.source = source
	sfx_at("bow", at, -6.0)


# --- The Sandbox ----------------------------------------------------------------

## Lays out one of everything along the rows the map marks, each taken thing coming back soon after.
func set_up_stands() -> void:
	_stand_items.clear()
	for row: Dictionary in stands:
		var along := Basis(Vector3.UP, float(row["yaw"])) * Vector3.RIGHT
		var entries: Array = []
		match str(row["kind"]):
			"weapon":
				for id: String in WeaponDefs.ALL:
					var d: Dictionary = WeaponDefs.ALL[id]
					if not d.get("hidden", false) and id != "staff":
						entries.append([Pickup.Kind.WEAPON, id])
			"item":
				for id: String in PowerDefs.ALL:
					if not PowerDefs.ALL[id]["familiar"]:
						entries.append([Pickup.Kind.POWER, id])
				for id: String in PowerDefs.FOODS:
					entries.append([Pickup.Kind.FOOD, id])
				entries.append([Pickup.Kind.ARROWS, "arrows"])
			"familiar":
				for id: String in PowerDefs.ALL:
					if PowerDefs.ALL[id]["familiar"]:
						entries.append([Pickup.Kind.POWER, id])
		for i in entries.size():
			var at: Vector3 = row["at"] + along * (i * 3.6)
			_stand_items.append({"kind": entries[i][0], "id": entries[i][1], "at": at, "item": null, "wait": 0.0})
		var sign_post := Label3D.new()
		sign_post.text = {"weapon": "Weapons", "item": "Potions and food", "familiar": "Familiars"}[str(row["kind"])]
		sign_post.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_post.font = UiTheme.title_font()
		sign_post.font_size = 64
		sign_post.pixel_size = 0.012
		sign_post.modulate = UiTheme.BONE
		sign_post.outline_size = 12
		sign_post.position = (row["at"] as Vector3) + along * (entries.size() - 1) * 1.8 + Vector3.UP * 3.2
		add_child(sign_post)


func tick_stands(delta: float) -> void:
	for s: Dictionary in _stand_items:
		if is_instance_valid(s["item"]):
			(s["item"] as Pickup).life = 999.0
			continue
		s["wait"] = float(s["wait"]) - delta
		if float(s["wait"]) <= 0.0:
			s["wait"] = 2.0
			s["item"] = spawn_pickup_at(s["at"], s["kind"], s["id"])


## An enemy of your choice, a little way in front of you.
func sandbox_spawn(id: String) -> bool:
	var ahead := -player.global_basis.z
	var at := player.global_position + ahead * 9.0
	var cell := grid.to_cell(at)
	if not grid.is_free(cell):
		at = grid.to_world(grid.nearest_free(cell))
	at.y = 0.0
	return spawn_zombie(id, at)


func sandbox_clear() -> void:
	for z: Zombie in zombies.duplicate():
		if z.type_id != "dummy":
			z.release()


## Something thrown by hand, that does its work where it lands.
func spawn_thrown(at: Vector3, vel: Vector3, col: Color, burst: Callable, burning := false, size := 1.0) -> Projectile:
	var shot := _launch(Projectile.Kind.BOLT, _orb_mesh(col), at, vel, 14.0, 70.0, 0.0, 0.0, burning)
	if shot == null:
		burst.call(at + vel * 0.5)
		return null
	shot.from_player = true
	shot.blast_radius = 0.01
	shot.on_burst = burst
	shot.scale = Vector3.ONE * size
	if Net.active():
		Net.shot(2, at, vel, 14.0, 70.0, burning, col)
	return shot


## A dart that carries a spark. It jumps to whatever is near when it hits.
func spawn_dart(at: Vector3, vel: Vector3, dmg: float, jumps: int) -> void:
	var col := Color(0.6, 0.92, 1.0)
	var shot := _launch(Projectile.Kind.BOLT, _orb_mesh(col), at, vel, 0.0, 40.0, dmg, 1.0)
	if shot:
		shot.from_player = true
		shot.sparks = jumps
		shot.scale = Vector3.ONE * 0.5
		if Net.active():
			Net.shot(2, at, vel, 0.0, 40.0, false, col)


## A line of light between two points, for a moment.
func fx_spark(a: Vector3, b: Vector3) -> void:
	var m := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	var length := a.distance_to(b)
	if length < 0.05:
		return
	m.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT)
	m.scale = Vector3(1, 1, length)
	m.visible = true
	_spark_life[_sparks.find(m)] = 0.14


func place_sentry(p: Player, at: Vector3, seconds: float) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _sentry_mesh()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = Vector3(at.x, ground_at(at), at.z)
	_sentries.append({"node": node, "left": seconds, "timer": 0.4, "owner": p})
	if p and Net.active():
		Net.world_fx(Net.Fx.SENTRY, at, Vector3(seconds, 0, 0))


func _sentry_mesh() -> Mesh:
	if _sentry_look == null:
		var iron := Color(0.27, 0.29, 0.32)
		var brass := Color(0.72, 0.56, 0.22)
		var l := LowPoly.new()
		for a: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
			l.prism(Vector3(0, 0.95, 0), Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55), 0.05, 0.04, 5, Color(0.36, 0.24, 0.14))
		l.box(Vector3(0, 1.08, 0), Vector3(0.36, 0.3, 0.56), iron)
		l.prism(Vector3(0, 1.12, -0.2), Vector3(0, 1.12, -1.0), 0.06, 0.05, 6, brass)
		l.box(Vector3(0, 1.12, -0.32), Vector3(1.0, 0.06, 0.06), Color(0.36, 0.24, 0.14))
		_sentry_look = l.commit()
	return _sentry_look


func _tick_sentries(delta: float) -> void:
	for i in range(_sentries.size() - 1, -1, -1):
		var s: Dictionary = _sentries[i]
		s["left"] = float(s["left"]) - delta
		var node: MeshInstance3D = s["node"]
		if float(s["left"]) <= 0.0:
			fx_blast(node.global_position + Vector3.UP * 0.8, 0.8, Color(1.0, 0.8, 0.4, 0.4))
			node.queue_free()
			_sentries.remove_at(i)
			continue
		var owner_player: Player = s["owner"]
		if owner_player == null:
			continue
		s["timer"] = float(s["timer"]) - delta
		if float(s["timer"]) > 0.0:
			continue
		var from := node.global_position + Vector3.UP * 1.12
		var aim_at := aim_point(from, WorldLight.SENTRY_REACH)
		if aim_at == Vector3.INF:
			s["timer"] = 0.3
			continue
		s["timer"] = 0.55
		node.rotation.y = atan2(-(aim_at.x - from.x), -(aim_at.z - from.z))
		var dir := (aim_at - from).normalized()
		spawn_player_arrow(owner_player, from + dir * 0.9, dir * 45.0, 0.0, WorldLight.SENTRY_REACH + 6.0, 1.0, WeaponDefs.DAMAGE * owner_player.m("inv_damage") * owner_player.damage_multiplier(), false)
		sfx_at("crossbow", from, -6.0)


## What a turret should shoot at: the closest enemy, or the closest rival player.
func aim_point(from: Vector3, reach: float) -> Vector3:
	var z := nearest_zombie(from, reach, true)
	var r := nearest_rival(from, reach)
	if r and (z == null or r.global_position.distance_squared_to(from) < z.centre().distance_squared_to(from)):
		return r.global_position + Vector3.UP
	return z.centre() if z else Vector3.INF


func _launch(kind: int, m: Mesh, at: Vector3, vel: Vector3, grav: float, max_range: float, dmg: float, knock := 0.0, fire := false, bounces := 0) -> Projectile:
	for p in _projectiles:
		if not p.active:
			p.scale = Vector3.ONE
			p.launch(kind, m, at, vel, grav, max_range, dmg, knock, fire, bounces)
			return p
	return null


func burn_tick(z: Zombie) -> void:
	var mult := player.m("burn_damage") if player else 1.0
	if z.phases:
		mult *= 2.0
	z.next_hitter = z.last_hitter
	z.take_damage(6.0 * mult, Vector3.ZERO, 0.0, z.centre())
	if player:
		player.hit_marker = maxf(player.hit_marker, 0.35)


func register_burning(z: Zombie) -> void:
	if not _burning.has(z):
		_burning.append(z)


## Burning zombies light the night. Only the closest few get a real light.
func _tick_burn_lights() -> void:
	for i in range(_burning.size() - 1, -1, -1):
		if _burning[i].burn_time <= 0.0 or not _burning[i].is_alive():
			_burning.remove_at(i)
	for i in _burn_lights.size():
		var l := _burn_lights[i]
		if i < _burning.size():
			l.visible = true
			l.global_position = _burning[i].centre() + Vector3.UP * 0.3
			l.light_energy = 2.2 + sin(Time.get_ticks_msec() * 0.02 + i) * 0.5
		else:
			l.visible = false


# --- Spawning ----------------------------------------------------------------

func _build_zombie_pools() -> void:
	var plan := Game.zombie_pool_plan()
	for model: String in plan:
		_pools[model] = []
		for i in int(plan[model]):
			var z := Zombie.new(self, model)
			z.net_id = _by_id.size()
			_by_id.append(z)
			add_child(z)
			(_pools[model] as Array).append(z)


func spawn_zombie(id: String, at := Vector3.INF) -> bool:
	var models: Array = ZombieDefs.def_of(id)["models"].duplicate()
	models.shuffle()
	var pool: Array = []
	for m: String in models:
		if not (_pools[m] as Array).is_empty():
			pool = _pools[m]
			break
	if pool.is_empty():
		return false
	if at == Vector3.INF:
		at = _pick_spawn_point()
	if at == Vector3.INF:
		return false
	var z: Zombie = pool.pop_back()
	zombies.append(z)
	var minute := director.minute() if director else 0
	z.spawn(id, at, minute)
	if Net.is_host() and not _warming:
		Net.zombie_spawned(z, id, z.position, minute)
	return true


func zombie_by_id(id: int) -> Zombie:
	return _by_id[id] if id >= 0 and id < _by_id.size() else null


## The host raised this one. Each body has the same number on every phone.
func net_spawn_zombie(net_id: int, id: String, at: Vector3, minute: int) -> void:
	var z := zombie_by_id(net_id)
	if z == null:
		return
	if z.active:
		z.release()
	(_pools[z.model_id] as Array).erase(z)
	zombies.append(z)
	z.spawn(id, at, minute)
	z.position = at
	z._net_pos = at


func net_zombie_released(z: Zombie) -> void:
	if not _warming:
		Net.zombie_gone(z)


func net_spawn_pickup(net_id: int, kind: int, item: String, bonus: int, at: Vector3) -> void:
	var p := Pickup.new()
	p.setup(kind, item, bonus)
	add_child(p)
	p.global_position = at
	p.net_id = net_id
	_pickup_ids[net_id] = p
	pickups.append(p)


func net_remove_pickup(net_id: int) -> void:
	var p: Pickup = _pickup_ids.get(net_id)
	if p and is_instance_valid(p):
		_remove_pickup_here(p)


func net_visual_shot(mesh: int, at: Vector3, vel: Vector3, grav: float, reach: float, fire: bool, col: Color) -> void:
	var m: Mesh = _arrow_mesh
	if mesh == 1:
		m = _axe_proj
	elif mesh == 2:
		m = _orb_mesh(col)
	var shot := _launch(Projectile.Kind.ARROW, m, at, vel, grav, reach, 0.0, 0.0, fire)
	if shot:
		shot.visual = true


## Where each player starts. In a fight they start apart.
func player_start(peer: int) -> Vector3:
	var order: Array = Net.roster.keys()
	order.sort()
	var i := maxi(order.find(peer), 0)
	var spots := start_spots
	if Net.pvp() and not rival_spots.is_empty():
		spots = rival_spots
	var s: Vector3 = spots[i % spots.size()] if not spots.is_empty() else Vector3.ZERO
	return Vector3(s.x, ground_at(s) + 0.05, s.z)


## Wood turns up just inside a gate, where it is needed: the most damaged gate first.
func stock_wood() -> void:
	if fort == null or fort.gates.is_empty():
		return
	var g: Dictionary = fort.gates[randi() % fort.gates.size()]
	for other: Dictionary in fort.gates:
		if float(other["hp"]) < float(g["hp"]):
			g = other
	var dir: Vector3 = g["dir"]
	var along := Vector3(dir.z, 0, -dir.x)
	for attempt in 8:
		var at: Vector3 = (g["at"] as Vector3) - dir * randf_range(3.0, 5.0) + along * randf_range(-Fort.GATE_W, Fort.GATE_W)
		if not grid.is_free(grid.to_cell(at)):
			at = grid.to_world(grid.nearest_free(grid.to_cell(at)))
		var clash := false
		for other in pickups:
			if other.global_position.distance_to(at) < 1.0:
				clash = true
				break
		if not clash:
			spawn_pickup_at(at, Pickup.Kind.WOOD, "wood")
			return


## Somewhere to come back: as far as can be managed from everyone else. A bot asks from its own side.
func far_from_rivals_of(peer: int) -> Vector3:
	var best := Vector3(fog.centre.x, 0, fog.centre.y) if fog else Vector3(0, 0, 4.5)
	var best_d := -1.0
	for i in 12:
		var spot := loot_spots[randi() % loot_spots.size()]
		if fog and not fog.contains(spot, -5.0):
			continue
		var near := INF
		for t: Target in players:
			var other: int = (t as Avatar).peer if t is Avatar else Net.my_id()
			if not t.dead and Net.bots_foes(peer, other):
				near = minf(near, t.global_position.distance_to(spot))
		if near > best_d:
			best_d = near
			best = spot
	return best


func far_from_rivals() -> Vector3:
	var best := Vector3(fog.centre.x, 0, fog.centre.y) if fog else Vector3(0, 0, 4.5)
	var best_d := -1.0
	for i in 12:
		var spot := loot_spots[randi() % loot_spots.size()]
		if fog and not fog.contains(spot, -5.0):
			continue
		var near := INF
		for t in players:
			if t != player and not t.dead:
				near = minf(near, spot.distance_to(t.global_position))
		if near > best_d and near < 90.0:
			best_d = near
			best = spot
	return best


func spawn_gargoyle() -> bool:
	if perches.is_empty() or count_type("gargoyle") >= 2:
		return false
	var best := Vector3.INF
	for i in 8:
		var p: Vector3 = _nearby_perch()
		if player == null or Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > 16.0:
			best = p
			break
	return best != Vector3.INF and spawn_zombie("gargoyle", best)


func _nearby_perch() -> Vector3:
	var p: Vector3 = perches[randi() % perches.size()]
	for i in 6:
		if p.distance_to(random_player_position()) < 70.0:
			break
		p = perches[randi() % perches.size()]
	return p


func random_player_position() -> Vector3:
	if players.is_empty():
		return Vector3.ZERO
	return players[randi() % players.size()].global_position


func spawn_mimic() -> bool:
	for i in 8:
		var at: Vector3 = _loot_near_players()
		if grid.is_free(grid.to_cell(at)) and (player == null or at.distance_to(player.global_position) > 10.0):
			return spawn_zombie("mimic", at)
	return false


func spawn_scarecrow() -> bool:
	if crop_spots.is_empty():
		return false
	for i in 6:
		var at: Vector3 = crop_spots[randi() % crop_spots.size()]
		if at.distance_to(random_player_position()) > 90.0:
			continue
		if player == null or at.distance_to(player.global_position) > 14.0:
			return spawn_zombie("scarecrow", at)
	return false


## Fallen Mage's late trick: two zombies claw up beside it.
func raise_for(z: Zombie) -> void:
	for i in 2:
		spawn_zombie("normal", z.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	fx_blast(z.position + Vector3.UP * 0.3, 2.5, Color(0.5, 0.25, 0.6, 0.4))
	sfx_at("wraith", z.position, -2.0)


func banner(text: String, seconds: float) -> void:
	if director:
		director.show_banner(text, seconds)


## Out of sight and far from every player, at the edge of what they can hear. The map is big,
## so the search stays around the players: a zombie across the river would never find them.
func _pick_spawn_point() -> Vector3:
	var best := Vector3.INF
	var best_score := -INF
	for i in 16:
		var p: Vector3
		if players.is_empty():
			p = Vector3(randf_range(-HALF_SIZE + 2, HALF_SIZE - 2), 0, randf_range(-HALF_SIZE + 2, HALF_SIZE - 2))
		else:
			var a := randf() * TAU
			p = random_player_position() + Vector3(cos(a), 0, sin(a)) * randf_range(28.0, 62.0)
			if fort:
				p = Vector3(cos(a), 0, sin(a)) * randf_range(44.0, 72.0)
			if absf(p.x) > HALF_SIZE - 2.0 or absf(p.z) > HALF_SIZE - 2.0:
				continue
		p.y = 0.0
		if fog and not fog.contains(p, -4.0):
			continue
		var c := grid.to_cell(p)
		if not grid.is_free(c):
			continue
		var near := INF
		var seen := false
		for pl in players:
			if pl.dead:
				continue
			var to := p - pl.global_position
			to.y = 0.0
			near = minf(near, to.length())
			if to.normalized().dot(pl.look_direction()) > 0.4:
				seen = true
		if near < 26.0:
			continue
		var score := -near * 0.2 + (0.0 if seen else 20.0)
		if score > best_score:
			best_score = score
			best = grid.to_world(c)
	return best


func recycle_zombie(z: Zombie) -> void:
	zombies.erase(z)
	(_pools[z.model_id] as Array).append(z)


func on_zombie_killed(z: Zombie) -> void:
	make_noise(z.position, 6.0)
	if Net.is_host():
		Net.zombie_died(z, z.last_hitter)
	elif player:
		player.on_kill(z)


func on_player_died(p: Player) -> void:
	if Net.active():
		Net.local_died(p.last_foe)
	else:
		player_died.emit()


## Sunrise burns away everything still standing.
func on_dawn() -> void:
	_dawn_done = true
	_apply_sky(1.0)
	if player:
		player.guard_left = 999.0
		player.burn_time = 0.0
	for z: Zombie in zombies:
		if z.is_alive():
			z.ignite(ZombieDefs.BURN_SECONDS)
	get_tree().create_timer(1.2).timeout.connect(_burn_all)
	dawn_reached.emit()


func _burn_all() -> void:
	if Net.is_client():
		return
	for z: Zombie in zombies.duplicate():
		if z.is_alive():
			z.next_hitter = -1
			z.take_damage(99999.0, Vector3.UP, 0.0, z.centre())


func spawn_pickup_near_player(kind: int, id: String, near: float, far: float, around: Target = null) -> Pickup:
	var centre_at := Vector3.ZERO
	if around:
		centre_at = around.global_position
	elif player:
		centre_at = player.global_position
	for i in 14:
		var a := randf() * TAU
		var at := centre_at + Vector3(cos(a), 0, sin(a)) * randf_range(near, far)
		if absf(at.x) < HALF_SIZE - 2.0 and absf(at.z) < HALF_SIZE - 2.0 and grid.is_free(grid.to_cell(at)) and not terrain.in_water(at.x, at.z):
			return spawn_pickup_at(at, kind, id)
	return spawn_pickup_random(kind, id)


func spawn_pickup_at(at: Vector3, kind: int, id: String, bonus := 0) -> Pickup:
	if Net.is_client():
		Net.request_drop(at, kind, id, bonus)
		return null
	var p := Pickup.new()
	p.setup(kind, id, bonus)
	add_child(p)
	p.global_position = Vector3(at.x, ground_at(at), at.z)
	pickups.append(p)
	if Net.is_host():
		p.net_id = _next_pickup_id
		_next_pickup_id += 1
		_pickup_ids[p.net_id] = p
		Net.pickup_spawned(p, p.global_position)
	return p


## Half of all supplies land in buildings and yards, so exploring pays off.
func spawn_pickup_random(kind: int, id: String) -> Pickup:
	for i in 14:
		var at: Vector3
		if i < 6 and not loot_spots.is_empty():
			at = _loot_near_players()
		else:
			at = _open_ground_near_players()
		var c := grid.to_cell(at)
		if not grid.is_free(c) or terrain.in_water(at.x, at.z):
			continue
		if player and at.distance_to(player.global_position) < 4.0:
			continue
		if fog and not fog.contains(at, -3.0):
			continue
		# Things to find lie apart, not in heaps.
		at += Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		if not grid.is_free(grid.to_cell(at)) or terrain.in_pool(at.x, at.z):
			continue
		var clash := false
		for other in pickups:
			if Vector2(other.global_position.x - at.x, other.global_position.z - at.z).length() < PICKUP_APART:
				clash = true
				break
		if not clash:
			var bonus := 8 if kind == Pickup.Kind.WEAPON and WeaponDefs.is_ranged(id) else 0
			return spawn_pickup_at(at, kind, id, bonus)
	return null


## Supplies vanish after a while, so they land where someone can reach them in time.
func _loot_near_players() -> Vector3:
	var spot := loot_spots[randi() % loot_spots.size()]
	if players.is_empty():
		return spot
	var near := players[randi() % players.size()].global_position
	for i in 6:
		if spot.distance_to(near) < 70.0:
			break
		spot = loot_spots[randi() % loot_spots.size()]
	return spot


func _open_ground_near_players() -> Vector3:
	if players.is_empty():
		return Vector3(randf_range(-HALF_SIZE + 3, HALF_SIZE - 3), 0, randf_range(-HALF_SIZE + 3, HALF_SIZE - 3))
	var a := randf() * TAU
	var at := players[randi() % players.size()].global_position + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 55.0)
	return Vector3(clampf(at.x, -HALF_SIZE + 3, HALF_SIZE - 3), 0, clampf(at.z, -HALF_SIZE + 3, HALF_SIZE - 3))


func drop_weapon(at: Vector3, id: String) -> void:
	var c := grid.nearest_free(grid.to_cell(at))
	var target := at if grid.is_free(grid.to_cell(at)) else grid.to_world(c)
	spawn_pickup_at(target, Pickup.Kind.WEAPON, id)


func remove_pickup(p: Pickup) -> void:
	if Net.active() and p.net_id > 0:
		Net.pickup_gone(p.net_id)
	_remove_pickup_here(p)


func _remove_pickup_here(p: Pickup) -> void:
	pickups.erase(p)
	_pickup_ids.erase(p.net_id)
	p.queue_free()


func count_pickups(kind: int) -> int:
	var n := 0
	for p in pickups:
		if p.kind == kind:
			n += 1
	return n


func collect_weapon(p: Pickup) -> void:
	player.give_weapon(p.weapon_id)
	player.add_arrows(p.bonus_arrows)
	Sfx.play("weapon_change")
	remove_pickup(p)


func _scan_pickups() -> void:
	if player == null or player.dead:
		return
	var near: Pickup = null
	var near_d := 2.0
	var here := player.global_position
	var named: Pickup = null
	var named_d := 3.5
	for p: Pickup in pickups.duplicate():
		var d := p.global_position.distance_to(here)
		if d < named_d:
			named = p
			named_d = d
		if d > 2.0:
			continue
		match p.kind:
			Pickup.Kind.WEAPON:
				if not player.can_use(p.weapon_id):
					pass
				elif player.carries(p.weapon_id):
					# Spare copy: bows give their arrows, the rest stay on the ground.
					if p.bonus_arrows > 0:
						player.add_arrows(p.bonus_arrows)
						Sfx.play("pickup", -5.0)
						remove_pickup(p)
				elif player.has_empty_slot():
					collect_weapon(p)
				elif d < near_d:
					near = p
					near_d = d
			Pickup.Kind.FOOD:
				if d < 1.6 and player.hp < player.max_hp():
					player.heal(float(PowerDefs.FOODS[p.item_id]["heal"]))
					player.say("+%d %s" % [int(PowerDefs.FOODS[p.item_id]["heal"]), p.display_name()])
					Sfx.play("eat", -2.0)
					remove_pickup(p)
			Pickup.Kind.ARROWS:
				if d < 1.6 and player.arrows < player.max_arrows() and not player.class_def().get("no_weapons", false):
					player.add_arrows(12)
					player.say("+12 Arrows")
					Sfx.play("pickup", -5.0)
					remove_pickup(p)
			Pickup.Kind.POWER:
				if d < 1.6:
					player.activate_power(p.item_id)
					remove_pickup(p)
			Pickup.Kind.WOOD:
				if d < 1.8 and player.wood < Fort.WOOD_MAX:
					player.wood = mini(Fort.WOOD_MAX, player.wood + Fort.WOOD_PER_PICKUP)
					player.say("Wood: %d" % player.wood)
					Sfx.play("pickup", -5.0, 0.7)
					remove_pickup(p)
	player.nearby_weapon = near
	player.named_item = named


# --- Allies, familiars and the church ----------------------------------------

func spawn_ally(kind: String, at: Vector3, seconds: float) -> void:
	var cap := int(player.m("ally_cap")) if player else 4
	if Ally.BEASTS.has(kind):
		cap += 4
	var mine := 0
	for other in allies:
		if other.remote_owner == 0:
			mine += 1
	if mine >= cap and kind != "body":
		return
	var spare: Array = _spare_allies.get(kind, [])
	var a: Ally
	if spare.is_empty():
		a = Ally.new(self, kind)
		add_child(a)
	else:
		a = spare.pop_back()
	a.activate(seconds)
	_ally_seq = (_ally_seq + 1) % 250
	a.net_index = _ally_seq
	if player:
		a.hp *= player.m("ally_hp")
	a.global_position = grid.to_world(grid.nearest_free(grid.to_cell(at)))
	allies.append(a)


## Someone else's summons, as they are right now.
func net_remote_allies(peer: int, b: PackedByteArray) -> void:
	var seen := {}
	var at := 0
	while at + 9 <= b.size():
		var key := "%d:%d" % [peer, b.decode_u8(at)]
		seen[key] = true
		var a: Ally = _remote_allies.get(key)
		var pos := Vector3(b.decode_s16(at + 2), b.decode_s16(at + 4), b.decode_s16(at + 6)) * 0.01
		if a == null:
			var kind: String = Ally.KINDS[clampi(b.decode_u8(at + 1), 0, Ally.KINDS.size() - 1)]
			var spare: Array = _spare_allies.get(kind, [])
			if spare.is_empty():
				a = Ally.new(self, kind)
				add_child(a)
			else:
				a = spare.pop_back()
			a.activate(INF)
			a.remote_owner = peer
			a.net_index = b.decode_u8(at)
			a.global_position = pos
			allies.append(a)
			_remote_allies[key] = a
		a.net_target = pos
		a.net_yaw = b.decode_u8(at + 8) / 255.0 * TAU
		at += 9
	for key: String in _remote_allies.keys():
		if key.begins_with("%d:" % peer) and not seen.has(key):
			var gone: Ally = _remote_allies[key]
			_remote_allies.erase(key)
			remove_ally(gone)


func forget_peer_allies(peer: int) -> void:
	net_remote_allies(peer, PackedByteArray())


func remove_ally(a: Ally) -> void:
	allies.erase(a)
	a.deactivate()
	if not _spare_allies.has(a.kind):
		_spare_allies[a.kind] = []
	_spare_allies[a.kind].append(a)


## Bodies are built when an ability is chosen, so summoning them later does not stutter.
## Gone at once, with no falling down.
func dismiss_ally(kind: String) -> void:
	for a in allies:
		if a.kind == kind and a.remote_owner == 0 and not a.dead:
			a.dead = true
			a.collision_layer = 0
			a.set_dying(0.01)


func prepare_allies(kind: String, count: int) -> void:
	if not _spare_allies.has(kind):
		_spare_allies[kind] = []
	var spare: Array = _spare_allies[kind]
	while spare.size() + count_allies(kind) < count:
		var a := Ally.new(self, kind)
		add_child(a)
		a.deactivate()
		spare.append(a)


## The imp fetches the nearest item on the map, though never a weapon.
func imp_steal(p: Player) -> void:
	var best: Pickup = null
	var best_d := PowerDefs.IMP_RANGE * PowerDefs.IMP_RANGE
	for it in pickups:
		if it.kind == Pickup.Kind.WEAPON:
			continue
		if it.kind == Pickup.Kind.FOOD and p.hp >= p.max_hp():
			continue
		var d := it.global_position.distance_squared_to(p.global_position)
		if d < best_d and d > 4.0:
			best_d = d
			best = it
	if best:
		var t := best.create_tween() # dies with the item, if the item expires on the way
		var target := Vector3(p.global_position.x, ground_at(p.global_position), p.global_position.z)
		t.tween_property(best, "global_position", target, 0.6)
		Sfx.play("pickup", -9.0, 0.8, 0.5)


## Real flames for fire, and rising bubbles for poison, on top of the glow on the ground.
func _dress_puddle(pd: MeshInstance3D, seed_from: int) -> void:
	var flames := Node3D.new()
	flames.visible = false
	pd.add_child(flames)
	for i in 5:
		var a := TAU * (float(i) / 5.0 + seed_from * 0.13)
		var flame := MeshInstance3D.new()
		flame.mesh = WorldLight.flame_mesh()
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3(cos(a), 0.0, sin(a)) * (0.0 if i == 0 else 0.75)
		flame.scale = Vector3.ONE * (0.8 if i == 0 else 0.5 + 0.1 * i)
		flames.add_child(flame)
	var bubbles := CPUParticles3D.new()
	bubbles.visible = false
	bubbles.emitting = false
	bubbles.amount = 16
	bubbles.lifetime = 1.1
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(1.0, 0.05, 1.0)
	bubbles.direction = Vector3.UP
	bubbles.spread = 12.0
	bubbles.gravity = Vector3.UP * 0.6
	bubbles.initial_velocity_min = 0.3
	bubbles.initial_velocity_max = 0.8
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.3
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 6
	ball.rings = 3
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.5, 1.0, 0.25, 0.8)
	ball.material = look
	bubbles.mesh = ball
	pd.add_child(bubbles)


## shown_only: another player's patch. It looks the same here, and their phone does the burning.
func drop_poison(at: Vector3, burning := false, seconds := 0.0, size := 1.6, shown_only := false, hurts_me := false) -> void:
	var m := _puddles[_next_puddle]
	_puddle_life[_next_puddle] = seconds if seconds > 0.0 else PowerDefs.POISON_TIME
	_puddle_fire[_next_puddle] = burning
	_puddle_size[_next_puddle] = size
	_puddle_shown_only[_next_puddle] = shown_only
	_puddle_hurts_me[_next_puddle] = hurts_me
	m.scale = Vector3(size / 1.6, 1.0, size / 1.6)
	m.material_override = _fire_puddle if burning else null
	(m.get_child(0) as Node3D).visible = burning
	var bubbles := m.get_child(1) as CPUParticles3D
	bubbles.visible = not burning
	bubbles.emitting = not burning
	_next_puddle = (_next_puddle + 1) % _puddles.size()
	m.global_position = Vector3(at.x, ground_at(at) + 0.07, at.z)
	m.visible = true


func _tick_poison(delta: float) -> void:
	_poison_tick -= delta
	var tick := _poison_tick <= 0.0
	if tick:
		_poison_tick = 0.5
	for i in _puddles.size():
		if _puddle_life[i] <= 0.0:
			continue
		_puddle_life[i] -= delta
		if _puddle_life[i] <= 0.0:
			_puddles[i].visible = false
		elif tick and _puddle_hurts_me[i]:
			if player and Vector2(player.global_position.x - _puddles[i].global_position.x, player.global_position.z - _puddles[i].global_position.z).length() < _puddle_size[i]:
				player.ignite(2.0)
		elif tick and not _puddle_shown_only[i]:
			var at := _puddles[i].global_position
			for z: Zombie in zombies.duplicate():
				if z.is_alive() and Vector2(z.position.x - at.x, z.position.z - at.z).length() < _puddle_size[i]:
					if _puddle_fire[i]:
						z.ignite(ZombieDefs.BURN_SECONDS)
					else:
						z.take_damage(PowerDefs.POISON_DPS * 0.5, Vector3.ZERO, 0.0, z.centre())
						Game.note_poison(PowerDefs.POISON_DPS * 0.5)


## The bell can be heard across the village. Roaming zombies walk over to see why.
## One stroke for each minute gone, half a second apart, and the whole map can hear them.
func ring_bell(minutes: int) -> void:
	_bell_strokes = maxi(_bell_strokes, minutes)
	_bell_wait = 0.0
	for z in zombies:
		if z.position.distance_to(church_door) < 50.0:
			z.hear_bell(church_door)


func bell_strokes_left() -> int:
	return _bell_strokes


func _tick_bell(delta: float) -> void:
	if _bell_strokes > 0:
		_bell_wait -= delta
		if _bell_wait <= 0.0:
			_bell_wait = BELL_GAP
			_bell_strokes -= 1
			_bell_swing = 1.0
			Sfx.play("bell", -2.0, 1.0, 0.2)
	if bell == null or _bell_swing <= 0.0:
		return
	_bell_swing = maxf(0.0, _bell_swing - delta * 0.28)
	bell.rotation.x = sin(Time.get_ticks_msec() * 0.006) * 0.55 * _bell_swing


# --- Traps --------------------------------------------------------------------

static func trap_mesh() -> Mesh:
	if _trap_mesh == null:
		var l := LowPoly.new()
		l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.06, 0), 0.5, 0.5, 8, Color(0.3, 0.3, 0.33))
		l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.1, 0), 0.14, 0.14, 6, Color(0.5, 0.2, 0.15))
		for i in 8:
			var a := TAU * i / 8.0
			l.prism(Vector3(cos(a) * 0.4, 0.05, sin(a) * 0.4), Vector3(cos(a) * 0.32, 0.26, sin(a) * 0.32), 0.05, 0.0, 3, Color(0.78, 0.8, 0.84))
		_trap_mesh = l.commit()
	return _trap_mesh


func place_trap(p: Player, at: Vector3, arming := 0.0) -> void:
	var limit := int(p.m("trap_cap"))
	while _traps.size() >= limit:
		var old: Dictionary = _traps.pop_front()
		(old["node"] as Node).queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = trap_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(at.x, ground_at(at) + 0.03, at.z)
	if arming > 0.0:
		mi.scale = Vector3.ONE * 0.6
	_traps.append({"node": mi, "at": mi.global_position, "armed_at": now + arming})
	Sfx.play("trap", -8.0, 1.3, 0.2)
	if p.has_flag("trap_lure"):
		for z in zombies:
			if z.position.distance_to(at) < 22.0:
				z.hear_bell(at)


func _tick_traps(_delta: float) -> void:
	if player == null:
		return
	for i in range(_traps.size() - 1, -1, -1):
		var at: Vector3 = _traps[i]["at"]
		if now < float(_traps[i]["armed_at"]):
			continue
		var trap_node := _traps[i]["node"] as Node3D
		if trap_node.scale.x < 1.0:
			trap_node.scale = Vector3.ONE
			Sfx.play_at("trap", at, player.global_position, -6.0)
		var caught := rivals_near(at, 1.1)
		if not caught.is_empty():
			(_traps[i]["node"] as Node).queue_free()
			_traps.remove_at(i)
			Sfx.play_at("trap", at, player.global_position, 0.0)
			Net.hit_player(caught[0].peer, player.m("trap_damage"), at)
			Net.status_peer(caught[0].peer, Net.Status.STUN, 2.0 + player.m("trap_stun"))
			continue
		for z: Zombie in zombies:
			if not z.is_alive() or z.flies or z.dormant:
				continue
			if Vector2(z.position.x - at.x, z.position.z - at.z).length() < 1.05:
				_spring_trap(i, z, at)
				break


func _spring_trap(i: int, z: Zombie, at: Vector3) -> void:
	var p := player
	(_traps[i]["node"] as Node).queue_free()
	_traps.remove_at(i)
	Sfx.play_at("trap", at, p.global_position, 0.0)
	z.stun(2.0 + p.m("trap_stun"))
	z.take_damage(p.m("trap_damage"), Vector3.UP, 0.0, z.centre())
	if p.has_flag("trap_bleed"):
		z.add_dot(16.0, 4.0, true)
	if p.has_flag("trap_fire"):
		z.ignite(ZombieDefs.BURN_SECONDS)
	if p.has_flag("trap_blast"):
		blast(at + Vector3.UP * 0.4, 3.8, 60.0)
	if p.has_flag("field_snares") and not z.is_alive():
		place_trap(p, at)


# --- Warm-up -----------------------------------------------------------------

## Phones compile a shader the first time something uses it, which shows up as a stutter in
## the middle of a fight. So every enemy and effect is drawn once now, behind the loading screen.
func warm_up() -> void:
	if player == null:
		await get_tree().process_frame
		return
	_load_ahead()
	if _warmed_quality == Game.quality:
		await get_tree().process_frame
		return
	_warmed_quality = Game.quality
	_warming = true
	var cam := Camera3D.new()
	cam.far = 400.0
	cam.fov = 100.0
	add_child(cam)
	cam.global_position = Vector3(0, 3.0, 12.0)
	cam.current = true
	var spot := Vector3(0, 0, 6.0)
	var added: Array[Zombie] = []
	var running_effects: Array[Node] = [_gore[_next_gore]]
	var kinds := ["normal", "clever", "magic", "rider", "wraith", "banshee", "crow", "gargoyle", "mimic", "scarecrow", "hero_infantry", "hero_ranger"]
	for i in kinds.size():
		var before := zombies.size()
		if spawn_zombie(kinds[i], spot + Vector3(-5.5 + i, 0, 0)):
			var z := zombies[before]
			added.append(z)
			z.position.y = 0.1
			z.dormant = false
			if z._lure:
				z._visual.visible = true
			if i % 3 == 0:
				z._show_burning(1.0)
				running_effects.append(z._flames)
			elif i % 3 == 1:
				z._flash_on()
	var allies_from := allies.size()
	for kind: String in ["skeleton", "wolf", "raven", "snake", "fox", "ghost"]:
		spawn_ally(kind, spot + Vector3(allies.size() * 1.5 - 2.0, 0, -2.0), 1.0)
	fx_gore(spot + Vector3(-1, 1, 1), Color(0.5, 0.2, 0.2))
	fx_blast(spot + Vector3(1, 1, 1), 1.5, Color(1.0, 0.55, 0.15, 0.55))
	flash_bolt(spot + Vector3(2, 0, 2))
	fx_impact(spot + Vector3(0, 1.5, 1))
	fx_mist(spot + Vector3(0, 1, 2), 1.0)
	running_effects.append(_mist_pool[0])
	drop_poison(spot + Vector3(-2, 0, 1), true)
	drop_poison(spot + Vector3(2, 0, 1), false)
	var shots: Array[Projectile] = []
	for s: Projectile in [_launch(Projectile.Kind.ARROW, _arrow_mesh, spot + Vector3(-1, 1.6, 2), Vector3.FORWARD, 0.0, 9.0, 0.0),
			_launch(Projectile.Kind.FIREBALL, _fireball_mesh, spot + Vector3(0, 1.6, 2), Vector3.FORWARD, 0.0, 9.0, 0.0),
			_launch(Projectile.Kind.BOLT, _orb_mesh(Color(0.55, 0.75, 1.0)), spot + Vector3(1, 1.6, 2), Vector3.FORWARD, 0.0, 9.0, 0.0)]:
		if s:
			shots.append(s)
	# The world is frozen during this, but particles only appear when they run.
	for n in running_effects:
		n.process_mode = Node.PROCESS_MODE_ALWAYS
	# Enemies and effects, then the village from above and from the fields, then the player's own view.
	await _warm_frame()
	cam.global_position = Vector3(0, 95.0, 0.5)
	cam.look_at(Vector3.ZERO)
	await _warm_frame()
	cam.global_position = Vector3(-35.0, 16.0, 30.0)
	cam.look_at(Vector3(-35.0, 0.0, 36.0))
	await _warm_frame()
	for n in running_effects:
		n.process_mode = Node.PROCESS_MODE_INHERIT
	_mist_pool[0].visible = false
	for z in added:
		z.burn_time = 0.0
		z._stop_flames()
		z.release()
	_burning.clear()
	for s in shots:
		s.stop()
	while allies.size() > allies_from:
		remove_ally(allies[-1])
	_bolt.visible = false
	_bolt_life = 0.0
	_blast.visible = false
	_blast_life = 0.0
	for i in _impacts.size():
		_impacts[i].visible = false
		_impact_life[i] = 0.0
	for i in _puddles.size():
		_puddles[i].visible = false
		_puddle_life[i] = 0.0
	cam.queue_free()
	player.camera.current = true
	await _warm_frame()
	_warming = false


## Things that would otherwise be loaded or built at the moment they are first needed.
func _load_ahead() -> void:
	for id: String in WeaponDefs.ALL:
		WeaponDefs.mesh(id)
	for id: String in PowerDefs.ALL:
		PowerDefs.mesh(id)
	for id: String in PowerDefs.FOODS:
		PowerDefs.mesh(id)
	PowerDefs.mesh("arrows")
	var t := player.tree_data()
	var groups: Array = (t["core"] as Array).duplicate()
	for spec: Dictionary in t["specs"]:
		groups.append([spec["entry"], spec["final"]])
		groups.append_array(spec["path"])
	for options: Array in groups:
		for a: Dictionary in options:
			for part: String in String(a["icon"]).split("+"):
				Icons.glyph(part)


func _warm_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# --- Effects -----------------------------------------------------------------

func _build_sparks() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.95, 1.0)
	m.disable_fog = true
	box.material = m
	for i in 8:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_sparks.append(mi)
		_spark_life.append(0.0)


func _build_fx() -> void:
	_build_sparks()
	if _arrow_mesh == null:
		_arrow_mesh = LowPoly.new() \
			.prism(Vector3(0, 0, 0.32), Vector3(0, 0, -0.32), 0.012, 0.012, 4, WeaponDefs.LIGHT_WOOD) \
			.prism(Vector3(0, 0, -0.32), Vector3(0, 0, -0.42), 0.026, 0.0, 4, WeaponDefs.STEEL) \
			.box(Vector3(0, 0, 0.3), Vector3(0.008, 0.07, 0.1), Color(0.9, 0.9, 0.85)) \
			.commit()
		_fireball_mesh = SphereMesh.new()
		_fireball_mesh.radius = 0.22
		_fireball_mesh.height = 0.44
		_fireball_mesh.radial_segments = 8
		_fireball_mesh.rings = 4
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1.0, 0.5, 0.12)
		_fireball_mesh.material = fm
		_bolt_mesh = _make_bolt()
	if _axe_proj == null:
		_axe_proj = WeaponDefs.axe_mesh()
	for i in 24:
		var p := Projectile.new(self)
		add_child(p)
		_projectiles.append(p)
	var hit_tex: Texture2D = load("res://assets/sprites/hit.png")
	for i in 8:
		var s := Sprite3D.new()
		s.texture = hit_tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.pixel_size = 0.005
		s.visible = false
		add_child(s)
		_impacts.append(s)
		_impact_life.append(0.0)
	var gore_mesh := BoxMesh.new()
	gore_mesh.size = Vector3.ONE * 0.08
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gore_mesh.material = gm
	for i in 6:
		var g := CPUParticles3D.new()
		g.mesh = gore_mesh
		g.amount = 8
		g.one_shot = true
		g.emitting = false
		g.explosiveness = 1.0
		g.lifetime = 0.5
		g.direction = Vector3.UP
		g.spread = 75.0
		g.initial_velocity_min = 2.0
		g.initial_velocity_max = 5.0
		g.gravity = Vector3(0, -14, 0)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		_gore.append(g)
	_bolt = MeshInstance3D.new()
	_bolt.mesh = _bolt_mesh
	_bolt.visible = false
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bolt)
	_blast = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 1.0
	bs.height = 2.0
	bs.radial_segments = 10
	bs.rings = 5
	_blast_mat = StandardMaterial3D.new()
	_blast_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blast_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bs.material = _blast_mat
	_blast.mesh = bs
	_blast.visible = false
	_blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blast)
	_fire_puddle = StandardMaterial3D.new()
	_fire_puddle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire_puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_puddle.albedo_texture = load("res://assets/sprites/glow.png")
	_fire_puddle.albedo_color = Color(1.0, 0.45, 0.1, 0.85)
	var puddle := PlaneMesh.new()
	puddle.size = Vector2(3.0, 3.0)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_texture = load("res://assets/sprites/glow.png")
	pm.albedo_color = Color(0.45, 0.95, 0.2, 0.7)
	puddle.material = pm
	for i in 6:
		var pd := MeshInstance3D.new()
		pd.mesh = puddle
		pd.visible = false
		pd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pd)
		_dress_puddle(pd, i)
		_puddles.append(pd)
		_puddle_life.append(0.0)
		_puddle_fire.append(false)
		_puddle_size.append(1.6)
		_puddle_shown_only.append(false)
		_puddle_hurts_me.append(false)
	for i in 3:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.omni_range = 7.0
		l.visible = false
		add_child(l)
		_burn_lights.append(l)


static func _make_bolt() -> ArrayMesh:
	var l := LowPoly.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var col := Color(0.8, 0.9, 1.0)
	var p := Vector3.ZERO
	var y := 0.0
	while y < 34.0:
		var step := rng.randf_range(2.0, 4.0)
		var q := Vector3(rng.randf_range(-1.1, 1.1), y + step, rng.randf_range(-1.1, 1.1))
		l.prism(p, q, 0.14, 0.09, 4, col)
		p = q
		y += step
	var m := l.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	m.surface_set_material(0, mat)
	return m


func sfx_at(sound: String, at: Vector3, volume := 0.0) -> void:
	if player:
		Sfx.play_at(sound, at, _player_camera_position(), volume)
	if Net.is_host():
		Net.sound_at(sound, at, volume)


## Other players in a circle, if this is a game where you can hurt them.
func rivals_near(at: Vector3, radius: float) -> Array[Avatar]:
	var out: Array[Avatar] = []
	if not Net.pvp():
		return out
	for t in players:
		if t is Avatar and not t.dead and Net.is_foe((t as Avatar).peer) and t.global_position.distance_to(at) <= radius:
			out.append(t as Avatar)
	return out


## Puffs of fog that roll out and fade. Mist Leap leaves these behind it.
func fx_mist(at: Vector3, size: float) -> void:
	if _mist_pool.is_empty():
		_build_mist()
	var p := _mist_pool[_next_mist]
	_next_mist = (_next_mist + 1) % _mist_pool.size()
	p.global_position = at
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.initial_velocity_min = size * 0.5
	p.initial_velocity_max = size * 1.5
	p.visible = true
	p.restart()


func _build_mist() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/sprites/glow.png")
	m.disable_fog = true
	quad.material = m
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.97, 0.98, 0.62))
	ramp.set_color(1, Color(0.55, 0.85, 0.9, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	for i in 10:
		var p := CPUParticles3D.new()
		p.mesh = quad
		p.amount = 14
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.92
		p.lifetime = 1.15
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.5
		p.direction = Vector3(0, 0.25, 0)
		p.spread = 180.0
		p.gravity = Vector3(0, 0.45, 0)
		p.damping_min = 1.2
		p.damping_max = 2.4
		p.color_ramp = ramp
		p.scale_amount_curve = grow
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_mist_pool.append(p)


## A Guardian's dome: everyone inside it is safe while it lasts.
func fx_dome(at: Vector3, radius: float, seconds: float) -> void:
	if _dome == null:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 16
		s.rings = 8
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(1.0, 0.82, 0.36, 0.2)
		m.disable_fog = true
		s.material = m
		_dome = MeshInstance3D.new()
		_dome.mesh = s
		_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_dome)
	_dome.global_position = at
	_dome.scale = Vector3.ONE * radius
	_dome.visible = true
	_dome_left = seconds


func best_cover(at: Vector3) -> Avatar:
	var best: Avatar = null
	for t in players:
		if t is Avatar and not t.dead:
			var a := t as Avatar
			if a.cover_pct > 0.0 and not Net.is_foe(a.peer) and at.distance_to(a.global_position) <= a.cover_radius:
				if best == null or a.cover_pct > best.cover_pct:
					best = a
	return best


func near_friend() -> Vector3:
	for t in players:
		if t is Avatar and not t.dead and not Net.is_foe((t as Avatar).peer):
			var c := grid.nearest_free(grid.to_cell(t.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))))
			return grid.to_world(c)
	return far_from_rivals()


## Where an aimed ability will land. A radius of zero takes it away.
func show_aim(at: Vector3, radius: float) -> void:
	if _aim_ring == null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		_aim_ring = MeshInstance3D.new()
		_aim_ring.mesh = plane
		_aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var look := ShaderMaterial.new()
		look.shader = load("res://assets/shaders/strike_ring.gdshader")
		_aim_ring.material_override = look
		add_child(_aim_ring)
	_aim_ring.visible = radius > 0.0
	if radius > 0.0:
		_aim_ring.global_position = at + Vector3.UP * 0.15
		_aim_ring.scale = Vector3(radius, 1.0, radius)


## A wave along the ground, shown on every phone.
func fx_ring(at: Vector3, radius: float, col: Color) -> void:
	show_ring(at, radius, col)
	Net.ring_fx(at, radius, col)


func show_ring(at: Vector3, radius: float, col: Color) -> void:
	if _rings.is_empty():
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		for i in 4:
			var mi := MeshInstance3D.new()
			mi.mesh = plane
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var look := ShaderMaterial.new()
			look.shader = load("res://assets/shaders/shock_ring.gdshader")
			mi.material_override = look
			mi.visible = false
			add_child(mi)
			_rings.append({"node": mi, "left": 0.0})
	var ring: Dictionary = _rings[_next_ring]
	_next_ring = (_next_ring + 1) % _rings.size()
	var node := ring["node"] as MeshInstance3D
	node.global_position = Vector3(at.x, ground_at(at) + 0.12, at.z)
	node.scale = Vector3(radius, 1.0, radius)
	(node.material_override as ShaderMaterial).set_shader_parameter("tint", Vector3(col.r, col.g, col.b))
	node.visible = true
	ring["left"] = RING_TIME


func _tick_rings(delta: float) -> void:
	for ring: Dictionary in _rings:
		if float(ring["left"]) <= 0.0:
			continue
		ring["left"] = float(ring["left"]) - delta
		var node := ring["node"] as MeshInstance3D
		if float(ring["left"]) <= 0.0:
			node.visible = false
		else:
			(node.material_override as ShaderMaterial).set_shader_parameter("progress", 1.0 - float(ring["left"]) / RING_TIME)


func fx_blast(at: Vector3, radius: float, col: Color) -> void:
	_blast_mat.albedo_color = col
	_blast.global_position = at
	_blast.scale = Vector3.ONE * radius * 0.7
	_blast.visible = true
	_blast_life = 0.18


func fx_impact(at: Vector3) -> void:
	var s := _impacts[_next_impact]
	_impact_life[_next_impact] = 0.09
	_next_impact = (_next_impact + 1) % _impacts.size()
	s.global_position = at
	s.visible = true


func fx_gore(at: Vector3, col: Color) -> void:
	var g := _gore[_next_gore]
	_next_gore = (_next_gore + 1) % _gore.size()
	g.global_position = at
	g.color = col.darkened(0.25)
	g.restart()
