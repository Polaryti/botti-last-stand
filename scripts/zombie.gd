class_name Zombie
extends CharacterBody3D
## Pooled enemy. Each one roams until it sees or hears something, then hunts, then
## searches where the player was last seen. Animation is throttled with distance.

enum State { ROAM, INVESTIGATE, CHASE, SEARCH }
enum Effect { STUN, SLOW, IGNITE, MARK, DOT, FORGET, FREEZE }

const DIVE_WARNING := 0.6

const LAYER := 4
const HEIGHT := 1.8
const LOOPS := ["Idle", "Walking_A", "Walking_C", "Running_A"]
const ATTACK_TIME := 0.62
const BODY_TOP := {"magic": 2.2027} # the mage's hat does not count towards its height
const FAR := 34.0

static var _scenes := {}
static var _fit := {}
static var _shader: Shader
static var _materials := {}
static var _flash_material: StandardMaterial3D
static var _ice_material: StandardMaterial3D
static var _eye_mesh: Mesh
static var _claw_mesh: Mesh

var world: World
var model_id := ""
var type_id := ""
var def: Dictionary = {}
var active := false
var hp := 0.0
var max_hp := 0.0
var height := HEIGHT
var state: int = State.ROAM
var weapon_id := ""
var burn_time := 0.0
var xp_value := 10
var reveal_left := 0.0
var hero_minute := 0
var dormant := false
var flies := false
var phases := false
var hero := false
var bar_time := 0.0 # seconds left of the health bar shown after a hit
var puppet := false # on a joined phone: the host decides, and this body only shows it
var net_id := -1
var last_hitter := 0 # which player gets the kill
var next_hitter := 0
var _net_pos := Vector3.ZERO
var _net_rot := 0.0

var _visual: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _shadow: MeshInstance3D
var _parts: Array[MeshInstance3D] = []
var _hand_mesh: MeshInstance3D
var _eyes: MeshInstance3D
var _claws: Array = []
var _flames: CPUParticles3D

var _path := PackedVector3Array()
var _path_i := 0
var _needs_path := false
var _full_path := false
var _next_plan := 0.0
var _goal := Vector3.ZERO
var _has_goal := false
var _direct := false
var _last_seen := Vector3.ZERO
var _lost := 0.0
var _search_left := 0.0
var _wait := 0.0
var _sees := false
var _hold := false
var _alerted_at := -100.0
var _move_dir := Vector3.ZERO
var _knock := Vector3.ZERO
var _think := 0.0
var _attack_cd := 0.0
var _attack_left := 0.0
var _attack_hit_pending := false
var _groan_cd := 0.0
var _flash := 0.0
var _dying := 0.0
var _burn_tick := 0.0
var _stuck_timer := 0.0
var _stuck_from := Vector3.ZERO
var _anim_accum := 0.0
var _frame := 0
var _current_anim := ""
var _hurt_stun := 0.0
var _stun := 0.0
var _slow := 0.0
var _flank := Vector3.ZERO
var _predicted := false
var _custom := false
var _dot_time := 0.0
var _dot_dps := 0.0
var _dot_tick := 0.0
var _mark_time := 0.0
var _mark_mult := 1.0
var _airborne := false
var _air_vel := Vector3.ZERO
var _special_cd := 0.0
var _special_left := 0.0
var _orbit := 0.0
var _dive := 0.0
var _phase := 0.0
var _home := Vector3.ZERO
var _beam: MeshInstance3D
var _lure: MeshInstance3D
var _separation := Vector3.ZERO
var _clear := false # flyers: straight line to the target, refreshed at think rate
var _watched := false # scarecrows: refreshed at think rate
var _tick_every := 1 # far enemies move less often
var _tick_count := 0
var _tick_time := 0.0
var _since_think := 0.0
var _recover := 0.0 # flyers hang low for a moment after a dive: that is the time to hit them
var _windup := 0.0 # flyers hang still and call out before they dive
var _dive_aim := Vector3.ZERO
var net_warning := false
var _frozen := 0.0
var _mounted := false
var _horse_node: MeshInstance3D
var _ride_pass := 0.0
var _ride_turn := 0.0
var _ride_dir := Vector3.ZERO
var _ride_hit := false
var _flock_left := 0.0 # crows move on after a while
var _statue := false
var _is_dormant_type := false
var _screams := false
var _charges := false
var _caster := false
var _is_scarecrow := false
var _leaps := false
var _sight := 0.0
var _speed := 0.0
var _roam_speed := 0.0
var _damage := 0.0
var _armed_damage := 0.0
var _hero_extra := 0.0
var _scale := 1.0


func _init(owner_world: World, model: String) -> void:
	world = owner_world
	model_id = model
	puppet = Net.is_client()
	collision_layer = 0
	collision_mask = 1 | Terrain.BARRIER | Terrain.ENEMY_ONLY
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_capsule = CapsuleShape3D.new()
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	add_child(_shape)
	_build_visual()
	_set_enabled(false)


func _ready() -> void:
	# Godot turns processing back on when a node enters the tree.
	set_physics_process(active)
	set_process(active and _anim != null)


static func _setup_static() -> void:
	if _shader:
		return
	_shader = load("res://assets/shaders/rotten.gdshader")
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1, 0.9, 0.8)
	_ice_material = StandardMaterial3D.new()
	_ice_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ice_material.albedo_color = Color(0.62, 0.86, 0.96)
	var eyes := LowPoly.new()
	for x: float in [-0.2, 0.2]:
		eyes.box(Vector3(x, 0, 0), Vector3(0.1, 0.09, 0.05), Color(1, 0.18, 0.08))
	_eye_mesh = eyes.commit()
	var eye_mat := StandardMaterial3D.new()
	eye_mat.vertex_color_use_as_albedo = true
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mesh.surface_set_material(0, eye_mat)
	var claws := LowPoly.new()
	for i in 3:
		var x := -0.14 + i * 0.14
		claws.prism(Vector3(x, 0.05, 0), Vector3(x, 0.55, 0.12), 0.05, 0.0, 4, Color(0.85, 0.82, 0.7))
	_claw_mesh = claws.commit()


func _material_for(id: String, source: Material) -> ShaderMaterial:
	var key := model_id + id
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", (source as StandardMaterial3D).albedo_texture)
	m.set_shader_parameter("tint", ZombieDefs.ALL[id]["tint"])
	_materials[key] = m
	return m


func _build_visual() -> void:
	_setup_static()
	_custom = model_id in ["crow", "gargoyle", "mimic", "scarecrow"]
	if _custom:
		_visual = EnemyModels.build(model_id)
		add_child(_visual)
		for mi in _visual.find_children("*", "MeshInstance3D", false, false):
			_parts.append(mi as MeshInstance3D)
		_fit[model_id] = 1.0
		if model_id == "mimic":
			_build_lure()
	else:
		var path := "res://assets/characters/%s.glb" % model_id
		if not _scenes.has(model_id):
			_scenes[model_id] = load(path)
		_visual = (_scenes[model_id] as PackedScene).instantiate()
		add_child(_visual)
		_anim = _visual.find_children("*", "AnimationPlayer", true, false)[0]
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for n: String in LOOPS:
			if _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_skeleton = _visual.find_children("*", "Skeleton3D", true, false)[0]
		for mi in _visual.find_children("*", "MeshInstance3D", true, false):
			var part := mi as MeshInstance3D
			_parts.append(part)
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.extra_cull_margin = 1.0
		if not _fit.has(model_id):
			_measure()
		_eyes = _attach("head", _eye_mesh, Vector3(0, 0.42, 0.49))
		# Bone attachments cost time on every pose update, so only add those that get used.
		if model_id == "beast":
			_claws = [_attach("handslot.r", _claw_mesh, Vector3.ZERO), _attach("handslot.l", _claw_mesh, Vector3.ZERO)]
			_horse_node = MeshInstance3D.new()
			_horse_node.mesh = HorseModel.mesh()
			_horse_node.rotation.y = PI
			_horse_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_horse_node.visible = false
			add_child(_horse_node)
	_shadow = World.make_blob_shadow(1.0)
	add_child(_shadow)


## A mimic pretends to be a pickup: same spinning item and beacon as real loot.
func _build_lure() -> void:
	_lure = MeshInstance3D.new()
	_lure.position.y = 0.8
	_lure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lure)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.28
	cyl.height = 2.8
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.72, 0.2, 0.15)
	_beam.material_override = m
	_beam.position.y = 1.4
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)


func _attach(bone: String, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	_skeleton.add_child(a)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mi)
	return mi


func _measure() -> void:
	var high := 0.0
	for part in _parts:
		high = maxf(high, part.get_aabb().end.y)
	_fit[model_id] = HEIGHT / float(BODY_TOP.get(model_id, maxf(high, 0.5)))


func _set_enabled(on: bool) -> void:
	active = on
	visible = on
	set_physics_process(on)
	set_process(on and _anim != null)
	collision_layer = LAYER if on else 0
	_shape.set_deferred("disabled", not on)


func spawn(id: String, at: Vector3, minute := 0) -> void:
	type_id = id
	def = ZombieDefs.ALL[id]
	var s: float = def["scale"]
	_scale = s
	_sight = def["sight"]
	_roam_speed = def["roam_speed"]
	flies = def.get("flies", false)
	phases = def.get("phases", false)
	hero = def.get("hero", false)
	_statue = def.get("statue", false)
	_is_dormant_type = def.get("dormant", false)
	_screams = def.get("screams", false)
	_charges = def.get("charges", false)
	_caster = def.get("caster", false)
	_is_scarecrow = def.get("scarecrow", false)
	_leaps = def.get("leaps", false) or (id == "hero_infantry" and minute >= 4)
	hero_minute = minute
	weapon_id = ""
	hp = float(def["hp"])
	xp_value = int(def["xp"])
	_speed = def["speed"]
	_damage = def["damage"]
	_armed_damage = ZombieDefs.ARMED_DAMAGE
	if hero:
		# Fallen Heroes grow with the night, each in its own way.
		hp += ZombieDefs.HERO_HP_PER_MINUTE * minute
		xp_value += ZombieDefs.HERO_XP_PER_MINUTE * minute
	else:
		# So does everything else, a little.
		hp *= 1.0 + ZombieDefs.NIGHT_HP * minute
		var harder := 1.0 + ZombieDefs.NIGHT_DAMAGE * minute
		_damage *= harder
		_armed_damage *= harder
		_speed *= 1.0 + ZombieDefs.NIGHT_SPEED * minute
	hp *= Game.enemy_health()
	_damage *= Game.enemy_damage()
	_armed_damage *= Game.enemy_damage()
	_hero_extra = (hero_minute * 0.8) * Game.enemy_damage()
	_speed *= Game.enemy_speed()
	max_hp = hp
	reveal_left = 0.0
	bar_time = 0.0
	_clear = false
	_watched = false
	_recover = 0.0
	_windup = 0.0
	net_warning = false
	_frozen = 0.0
	_flock_left = ZombieDefs.CROW_STAY
	_separation = Vector3.ZERO
	_direct = false
	_tick_every = 1
	_tick_time = 0.0
	_dot_time = 0.0
	_mark_time = 0.0
	_airborne = false
	_special_cd = randf_range(1.5, 4.0)
	_special_left = 0.0
	_orbit = randf() * TAU
	_dive = 0.0
	_phase = randf() * TAU
	_home = at
	dormant = _statue or _is_dormant_type
	_stun = 0.0
	_slow = 0.0
	_predicted = false
	# Each zombie approaches from its own side, so a group ends up surrounding you.
	var a := randf() * TAU
	_flank = Vector3.ZERO if id == "beast" else Vector3(cos(a), 0, sin(a))
	height = HEIGHT * s
	position = at
	last_hitter = 0
	next_hitter = 0
	var ground := world.ground_at(at)
	if not _statue:
		position.y = ground
	if flies and not dormant:
		position.y = ground + float(def["fly_height"])
	_capsule.radius = (0.7 if flies else 0.36) * s
	_capsule.height = height
	_shape.position = Vector3(0, height * 0.5, 0)
	_visual.scale = Vector3.ONE * float(_fit[model_id]) * s
	_shadow.scale = Vector3(s, 1, s)
	_shadow.visible = position.y - ground < 0.5
	state = State.ROAM
	weapon_id = ""
	if _hand_mesh:
		_hand_mesh.mesh = null
	if def.has("weapon"):
		weapon_id = def["weapon"]
		_show_weapon(weapon_id)
	for c: MeshInstance3D in _claws:
		c.visible = def.get("claws", false)
	_visual.position = Vector3.ZERO
	_show_mount(def.get("rider", false))
	_ride_pass = 0.0
	_ride_turn = 1.0
	if _lure:
		_lure.visible = true
		_beam.visible = true
		_lure.mesh = WeaponDefs.mesh(WeaponDefs.pick_random())
		_lure.scale = Vector3.ONE * 0.5
		_visual.visible = false
	else:
		_visual.visible = true
	collision_mask = 0 if flies or phases else (1 | Terrain.BARRIER | Terrain.ENEMY_ONLY)
	burn_time = 0.0
	_stop_flames()
	_knock = Vector3.ZERO
	_think = randf() * 0.2
	_attack_cd = 0.5
	_attack_left = 0.0
	_attack_hit_pending = false
	_groan_cd = randf_range(2.0, 10.0)
	_dying = 0.0
	_flash = 0.0
	_hold = false
	_sees = false
	_lost = 0.0
	_wait = randf_range(0.0, 2.0)
	_has_goal = false
	_needs_path = false
	_full_path = false
	_next_plan = 0.0
	_path = PackedVector3Array()
	_path_i = 0
	_hurt_stun = 0.0
	_stuck_timer = 0.0
	_stuck_from = position
	rotation.y = randf() * TAU
	_net_pos = position
	_net_rot = rotation.y
	_restore_materials()
	_current_anim = ""
	_play("Idle")
	_set_enabled(true)
	if _anim == null:
		_visual.rotation = Vector3.ZERO


func _show_mount(on: bool) -> void:
	_mounted = on
	if _horse_node:
		_horse_node.visible = on
	_visual.position.y = 0.85 if on else 0.0


## The rider comes through at a gallop, turns wide, and comes through again.
func _tick_rider(target: Target, to: Vector3, dist: float, delta: float) -> void:
	if _attack_left > 0.0:
		_attack_left -= delta
	if _ride_pass > 0.0:
		_ride_pass -= delta
		velocity = _ride_dir * _speed * (0.5 if _slow > 0.0 else 1.0)
		rotation.y = lerp_angle(rotation.y, atan2(_ride_dir.x, _ride_dir.z), min(1.0, delta * 10.0))
		move_and_slide()
		position.y = world.ground_at(position)
		if not _ride_hit and dist < 2.7 and absf(target.global_position.y - position.y) < 2.6:
			_ride_hit = true
			_attack_left = ATTACK_TIME * 0.6
			_current_anim = ""
			_play("1H_Melee_Attack_Chop", 1.8, 0.05)
			target.hurt(_melee_damage(), position, self)
			world.sfx_at("clang", position, -2.0)
		if get_slide_collision_count() > 0:
			_ride_pass = 0.0
		if _ride_pass <= 0.0:
			_ride_turn = randf_range(0.9, 1.4)
		return
	if _ride_turn > 0.0:
		# Wheeling round. This is the moment to hit it.
		_ride_turn -= delta
		velocity = Vector3(sin(rotation.y), 0, cos(rotation.y)) * _speed * 0.45
		rotation.y += delta * 2.6
		move_and_slide()
		position.y = world.ground_at(position)
		return
	if _sees and dist > 1.0:
		_ride_dir = to / dist
		_ride_pass = dist / _speed + 0.7
		_ride_hit = false
		world.sfx_at("gallop", position, 0.0)
		return
	_move(target, to, dist, delta)
	_play("Idle")


## Below 40% health the horse goes down, and whoever rode it fights on foot.
func _check_dismount() -> void:
	if _mounted and hp < max_hp * 0.4:
		_show_mount(false)
		_speed = 3.6 * Game.enemy_speed()
		_stun = maxf(_stun, 0.9)
		_current_anim = ""
		_play("Hit_A", 0.8, 0.05)
		world.sfx_at("gallop", position, 2.0)
		world.fx_gore(position + Vector3.UP, Color(0.3, 0.19, 0.12))


func _show_weapon(id: String) -> void:
	if _skeleton == null:
		return
	if _hand_mesh == null:
		_hand_mesh = _attach("handslot.r", null, Vector3.ZERO)
	var d: Dictionary = WeaponDefs.ALL[id]
	_hand_mesh.mesh = WeaponDefs.mesh(id)
	var hold := 0.55 if WeaponDefs.is_ranged(id) or id in ["lance", "spear", "pitchfork"] else 1.0
	_hand_mesh.scale = Vector3.ONE * float(d["scale"]) * hold * 2.2 / float(_fit[model_id])


func _restore_materials() -> void:
	if _frozen > 0.0:
		for p in _parts:
			p.material_override = _ice_material
		return
	if _custom:
		for p in _parts:
			p.material_override = null
		return
	var ghost: Variant = def.get("ghost")
	for p in _parts:
		if ghost != null:
			p.material_override = _ghost_material(ghost)
		else:
			p.material_override = _material_for(type_id, p.mesh.surface_get_material(0))


static func _ghost_material(col: Color) -> StandardMaterial3D:
	if _materials.has(col):
		return _materials[col]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	_materials[col] = m
	return m


func _flash_on() -> void:
	_flash = 0.08
	for p in _parts:
		p.material_override = _flash_material


func _play(anim_name: String, speed := 1.0, blend := 0.2) -> void:
	if _anim == null:
		return
	if _current_anim == anim_name:
		_anim.speed_scale = speed
		return
	_current_anim = anim_name
	_anim.speed_scale = speed
	_anim.play(anim_name, blend)


func is_alive() -> bool:
	return active and _dying <= 0.0


func display_name() -> String:
	return def["name"]


func is_hunting() -> bool:
	return is_alive() and state == State.CHASE


func headshot_at(y: float) -> bool:
	return y > position.y + height * 0.76


func centre() -> Vector3:
	return position + Vector3.UP * height * 0.55


func is_unaware() -> bool:
	return is_alive() and state != State.CHASE


func is_behind(from: Vector3) -> bool:
	var look := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var to := from - position
	to.y = 0.0
	return to.length() > 0.01 and look.dot(to.normalized()) < -0.25


func mark(mult: float, seconds: float) -> void:
	if puppet:
		Net.effect_zombie(self, Effect.MARK, mult, seconds)
		return
	_mark_mult = maxf(_mark_mult if _mark_time > 0.0 else 1.0, mult)
	_mark_time = seconds


func add_dot(dps: float, seconds: float) -> void:
	if puppet:
		Net.effect_zombie(self, Effect.DOT, dps, seconds)
		return
	_dot_dps = dps
	_dot_time = maxf(_dot_time, seconds)


# --- Damage ------------------------------------------------------------------

func take_damage(amount: float, from_dir: Vector3, knock: float, hit_pos: Vector3) -> void:
	if not is_alive():
		return
	if puppet:
		# Show the hit straight away. The host has the last word on whether it killed.
		hp = maxf(hp - amount, 1.0)
		bar_time = 2.5
		_flash_on()
		world.fx_gore(hit_pos, def.get("tint", Color(0.3, 0.3, 0.3)))
		world.sfx_at("zombie_hurt", position, -8.0)
		Net.hit_zombie(self, amount, from_dir, knock, hit_pos)
		return
	if next_hitter != 0:
		last_hitter = next_hitter
	elif Net.active():
		last_hitter = Net.my_id()
	next_hitter = 0
	if dormant:
		_wake()
	if _mark_time > 0.0:
		amount *= _mark_mult
	if def.get("shielded", false) and amount < 5000.0:
		var away := -from_dir
		away.y = 0.0
		var look := Vector3(sin(rotation.y), 0, cos(rotation.y))
		if away.length_squared() > 0.001 and look.dot(away.normalized()) > 0.3:
			amount *= 0.5
			world.sfx_at("block", position, -6.0)
	hp -= amount
	bar_time = 2.5
	_flash_on()
	if flies and (_dive > 0.0 or _windup > 0.0):
		# A blow knocks it out of its dive, and it hangs there for a moment.
		_dive = 0.0
		_windup = 0.0
		_recover = maxf(_recover, 0.8)
	_knock += Vector3(from_dir.x, 0, from_dir.z).normalized() * knock / _scale
	world.fx_gore(hit_pos, def.get("tint", Color(0.3, 0.3, 0.3)))
	if Net.is_host():
		Net.gore(hit_pos, def.get("tint", Color(0.3, 0.3, 0.3)))
	if hp <= 0.0:
		_die()
		return
	_check_dismount()
	world.sfx_at("zombie_hurt", position, -8.0)
	if type_id != "beast":
		_hurt_stun = 0.1
	var p := world.nearest_player(position)
	if p:
		_start_chase(p.global_position)


func _death_sound() -> String:
	match type_id:
		"crow": return "crow"
		"gargoyle": return "blast"
		"banshee": return "wraith"
		"wraith": return "wraith"
		"mimic": return "mimic"
		"scarecrow": return "creak"
	return "zombie_death"


func _wake() -> void:
	if puppet:
		return
	_show_awake()
	if Net.is_host():
		Net.zombie_woke(self)
	var p := world.nearest_player(position)
	if p:
		_start_chase(p.global_position)


func net_wake() -> void:
	_show_awake()


func _show_awake() -> void:
	dormant = false
	_special_left = 0.0
	if _lure:
		_lure.visible = false
		_beam.visible = false
		_visual.visible = true
		world.sfx_at("mimic", position, 0.0)
	if _statue:
		world.sfx_at("gargoyle", position, -2.0)


func stun(seconds: float) -> void:
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.STUN, seconds)
		return
	if dormant:
		_wake()
	_stun = maxf(_stun, seconds)
	_attack_left = 0.0
	_attack_hit_pending = false
	_special_left = 0.0 # a stun cuts a Banshee's scream or a Fallen Knight's charge short
	_hold = false
	_tick_every = 1
	_current_anim = ""
	_play("Hit_A", 0.8, 0.05)


## Mist Burst: frozen solid, and a hit does not thaw it.
func freeze(seconds: float) -> void:
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.FREEZE, seconds)
		return
	stun(seconds)
	_show_frozen(seconds)


func _show_frozen(seconds: float) -> void:
	var was := _frozen > 0.0
	_frozen = seconds
	if (seconds > 0.0) != was:
		_restore_materials()


func slow(seconds: float) -> void:
	if puppet:
		Net.effect_zombie(self, Effect.SLOW, seconds)
		return
	_slow = maxf(_slow, seconds)


func ignite(seconds: float) -> void:
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.IGNITE, seconds)
		return
	_show_burning(seconds)


func _show_burning(seconds: float) -> void:
	burn_time = maxf(burn_time, seconds)
	_burn_tick = 0.0
	if _flames == null:
		_flames = World.make_flames()
		add_child(_flames)
	_flames.position = Vector3.UP * height * 0.5
	_flames.emitting = true
	world.register_burning(self)


func _stop_flames() -> void:
	if _flames:
		_flames.emitting = false


func _die() -> void:
	_show_death()
	if weapon_id != "":
		world.drop_weapon(position + Vector3(0, 0, 0.5), weapon_id)
		weapon_id = ""
		if _hand_mesh:
			_hand_mesh.mesh = null
	world.on_zombie_killed(self)


## The host says this body is dead.
func net_die() -> void:
	_show_death()
	weapon_id = ""
	if _hand_mesh:
		_hand_mesh.mesh = null


func _show_death() -> void:
	_dying = 2.2
	burn_time = 0.0
	bar_time = 0.0
	_airborne = false
	_tick_every = 1
	_stop_flames()
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	_shadow.visible = false
	_knock = Vector3.ZERO
	_current_anim = ""
	_play("Death_A" if randf() < 0.5 else "Death_B", 1.2, 0.1)
	if _anim == null:
		_visual.rotation.x = -PI * 0.5
		_visual.position.y = 0.2
		_dying = 0.9
	if puppet:
		Sfx.play_at(_death_sound(), position, world.player.global_position if world.player else position, -6.0)
	else:
		world.sfx_at(_death_sound(), position, -6.0)


func release() -> void:
	if not active:
		return
	_set_enabled(false)
	world.recycle_zombie(self)
	if Net.is_host():
		world.net_zombie_released(self)


# --- On a joined phone -------------------------------------------------------

## True while this flyer is about to come down on someone.
func is_warning() -> bool:
	return net_warning if puppet else (_windup > 0.0 or _dive > 0.0)


func anim_speed() -> float:
	return _anim.speed_scale if _anim else 1.0


func net_apply(at: Vector3, rot: float, flags: int, hp_fraction: float, anim_name: String, speed: float) -> void:
	if _dying > 0.0:
		return
	_net_pos = at
	_net_rot = rot
	state = flags & 3
	hp = maxf(1.0, hp_fraction * max_hp)
	net_warning = flags & 64 != 0
	if def.get("rider", false) and (flags & 128 != 0) != _mounted:
		_show_mount(flags & 128 != 0)
	_show_frozen(0.25 if flags & 32 != 0 else 0.0)
	var burning := flags & 8 != 0
	if burning and burn_time <= 0.0:
		_show_burning(60.0)
	elif not burning and burn_time > 0.0:
		burn_time = 0.0
		_stop_flames()
	if anim_name != "":
		_play(anim_name, speed, 0.12)
	if position.distance_squared_to(at) > 49.0:
		position = at


func net_weapon(id: String) -> void:
	weapon_id = id
	_show_weapon(id)


func _puppet_tick(delta: float) -> void:
	var was := position
	position = position.lerp(_net_pos, minf(1.0, delta * 10.0))
	rotation.y = lerp_angle(rotation.y, _net_rot, minf(1.0, delta * 10.0))
	reveal_left -= delta
	bar_time -= delta
	_tick_flash(delta)
	if _custom and not dormant:
		_animate_custom(delta, was.distance_squared_to(position))
	elif _lure and dormant:
		_lure.rotation.y += delta * 1.6
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		var p := world.player
		var d := position.distance_to(p.global_position) if p else 0.0
		if _eyes:
			_eyes.visible = d < FAR
		_shadow.visible = d < FAR and position.y - world.ground_at(position) < 0.5


# --- Senses ------------------------------------------------------------------

func forget() -> void:
	if type_id == "beast" or not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.FORGET)
		return
	state = State.ROAM
	_clear_goal()
	_attack_left = 0.0
	_sees = false


## A Guardian's challenge: everything comes for them, even what had lost interest.
func taunted_by(at: Vector3) -> void:
	if not puppet and not dormant:
		_start_chase(at)


func hear(at: Vector3) -> void:
	if puppet or not is_alive() or state == State.CHASE or dormant:
		return
	state = State.INVESTIGATE
	_set_goal(at)


## The church bell only distracts zombies that are not already busy.
func hear_bell(at: Vector3) -> void:
	if not puppet and is_alive() and state == State.ROAM and not dormant and not flies:
		state = State.INVESTIGATE
		_set_goal(at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))


func _start_chase(at: Vector3) -> void:
	if puppet or dormant:
		return # something asleep stays asleep, however much the horde shouts
	state = State.CHASE
	_last_seen = at
	_lost = 0.0
	_predicted = false
	# Re-plan only when the target has really moved: paths are the costly part.
	# The further away it is, the less a small move changes the way there.
	var spot := at + _flank * 2.5
	var slack := maxf(2.0, position.distance_to(at) * 0.2)
	if not _has_goal or _goal.distance_squared_to(spot) > slack * slack:
		_set_goal(spot)


func _can_see(target: Target, to: Vector3, dist: float) -> bool:
	var sight := _sight
	if world.grid.in_crops(target.global_position):
		sight *= 0.5
	if target.is_unseen():
		return false
	sight *= target.sight_factor()
	if dist > sight:
		return false
	# A statue on its perch watches every way at once.
	if dist > 5.0 and not dormant:
		var look := Vector3(sin(rotation.y), 0, cos(rotation.y))
		if look.dot(Vector3(to.x, 0, to.z).normalized()) < 0.05:
			return false
	if phases:
		return true
	return world.has_line_of_sight(position + Vector3.UP * height * 0.85, target.eye_position())


func _set_goal(at: Vector3) -> void:
	_goal = at
	_has_goal = true
	_needs_path = true
	_stuck_timer = 0.0


func _clear_goal() -> void:
	_has_goal = false
	_needs_path = false
	_path = PackedVector3Array()
	_path_i = 0


func _arrived() -> bool:
	return not _has_goal or Vector2(position.x - _goal.x, position.z - _goal.z).length() < 1.3


func _random_spot(radius: float) -> Vector3:
	for i in 6:
		var p := position + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
		if absf(p.x) < World.HALF_SIZE - 1.0 and absf(p.z) < World.HALF_SIZE - 1.0 and world.grid.is_free(world.grid.to_cell(p)):
			return p
	return position


# --- Brain -------------------------------------------------------------------

func _decide(target: Target, to: Vector3, dist: float, dt: float) -> void:
	# Far from the action, move less often. Nobody can see the difference out there.
	_tick_every = 1
	if not flies and not _airborne and _stun <= 0.0:
		if dist > 32.0:
			_tick_every = 4
		elif dist > 18.0:
			_tick_every = 2
	# Lost in the fog anyway, and each of these is one more draw call.
	if _eyes:
		_eyes.visible = dist < FAR
	_shadow.visible = dist < FAR and position.y - world.ground_at(position) < 0.5 and not _airborne
	if dormant and _is_dormant_type:
		# A mimic only reacts to something right next to it, so it needs no sight check.
		if dist < 3.0:
			_wake()
		return
	_sees = _can_see(target, to, dist)
	if dormant:
		if _sees:
			_wake()
		return
	if _special_think(dist):
		return
	if world.fort and not flies and _fort_plan(target, dist):
		return
	if _sees:
		_start_chase(target.global_position)
		if world.now - _alerted_at > 4.0:
			_alerted_at = world.now
			world.call_horde(self, target.global_position, 15.0)
			world.sfx_at(_alert_sound(), position, -6.0)
	match type_id:
		"beast":
			# A beast tracks by scent: hiding only delays it.
			if state != State.CHASE or fmod(world.now, 2.5) < dt:
				_start_chase(target.global_position)
	match state:
		State.CHASE:
			if not _sees:
				_lost += dt
				# Lost from view: head for where you were going, not where you were.
				if not _predicted and _lost > 0.5:
					_predicted = true
					_set_goal(target.global_position + target.velocity * 1.3)
				if _lost > 9.0 or _arrived():
					state = State.SEARCH
					_search_left = 12.0
					_clear_goal()
		State.INVESTIGATE:
			if _arrived():
				state = State.SEARCH
				_search_left = 8.0
				_clear_goal()
		State.SEARCH:
			_search_left -= dt
			if _search_left <= 0.0:
				state = State.ROAM
				_clear_goal()
			elif _arrived():
				_set_goal(_random_spot(9.0))
		State.ROAM:
			_roam(dt)
	_hold = false
	if _sees and _attack_style() == "ranged":
		_hold = dist > 4.0 and dist < _ranged_reach()
	elif _sees and _screams and dist < 12.0:
		_hold = true # a Banshee never comes close: she stares, and calls the others
	_direct = _sees and dist < 8.0 and state == State.CHASE and not _hold
	if flies:
		_clear = (state == State.CHASE or _sees) and world.has_line_of_sight(position, target.eye_position())
		return
	if _is_scarecrow:
		_watched = _is_watched(target, dist)
	_separation = Vector3.ZERO
	if dist < 30.0:
		for other in world.zombies:
			if other == self or not other.is_alive():
				continue
			var away := position - other.position
			var d2 := away.length_squared()
			if d2 < 1.3 and d2 > 0.0001:
				_separation += away / d2
		_separation *= 0.25


## In the fort: a zombie goes for the players only if it can actually get to them. Otherwise
## it goes through the nearest open gate to the heart, or if every gate is shut, it breaks one.
func _fort_plan(target: Target, dist: float) -> bool:
	var fort := world.fort
	var me_inside := fort.inside(position)
	var they_inside := fort.inside(target.global_position)
	var they_reachable := not fort.on_wall(target.global_position) and (me_inside == they_inside or fort.any_open())
	if _sees and they_reachable and dist < _sight:
		return false
	if state == State.CHASE and they_reachable and (target.global_position - position).length() < 14.0:
		return false
	state = State.INVESTIGATE
	_direct = false
	_hold = false
	if me_inside or fort.any_open() or phases:
		_fort_goal(fort.heart_at + (position - fort.heart_at).normalized() * 2.2)
		if Vector2(position.x - fort.heart_at.x, position.z - fort.heart_at.z).length() < 3.8:
			_hold = true
			_fort_strike(-1, fort.heart_at)
		return true
	var g := fort.gate_nearest(position)
	var front := fort.gate_front(g, position)
	_fort_goal(front)
	if Vector2(position.x - front.x, position.z - front.z).length() < 1.6:
		_hold = true
		_fort_strike(g["i"], g["at"])
	return true


func _fort_goal(at: Vector3) -> void:
	if not _has_goal or _goal.distance_squared_to(at) > 4.0:
		_set_goal(at)


func _fort_strike(gate: int, at: Vector3) -> void:
	var to := at - position
	if to.length_squared() > 0.01:
		rotation.y = atan2(to.x, to.z)
	if _attack_cd > 0.0 or _attack_left > 0.0:
		return
	_attack_cd = _attack_interval()
	_attack_left = ATTACK_TIME
	_current_anim = ""
	_play("1H_Melee_Attack_Chop" if weapon_id != "" or def.get("claws", false) else "Unarmed_Melee_Attack_Punch_A", 1.2, 0.1)
	var dmg := maxf(_melee_damage(), 8.0)
	if gate >= 0:
		world.fort.hit_gate(world.fort.gates[gate], dmg * Fort.WOOD_TOUGHNESS, position)
	else:
		world.fort.hit_heart(dmg * Fort.HEART_TOUGHNESS)


func _roam(dt: float) -> void:
	if type_id == "clever" and weapon_id == "":
		var p := world.nearest_weapon_pickup(position, 34.0)
		if p:
			if p.global_position.distance_to(position) < 1.6:
				_take_weapon(p)
				return
			if not _has_goal or _goal.distance_to(p.global_position) > 0.5:
				_set_goal(p.global_position)
			return
	if _arrived():
		_clear_goal()
		_wait -= dt
		if _wait <= 0.0:
			_wait = randf_range(1.5, 6.0)
			if type_id == "magic" and not world.pois.is_empty():
				_set_goal(world.pois[randi() % world.pois.size()])
			else:
				_set_goal(_random_spot(18.0))


func _nearby_poi() -> Vector3:
	var best: Vector3 = world.pois[randi() % world.pois.size()]
	for i in 5:
		if best.distance_to(position) < 60.0:
			break
		best = world.pois[randi() % world.pois.size()]
	return best


func _take_weapon(p: Pickup) -> void:
	weapon_id = p.weapon_id
	_show_weapon(weapon_id)
	world.remove_pickup(p)
	if Net.is_host():
		Net.zombie_weapon(self)
	_clear_goal()
	_attack_left = 0.7
	_current_anim = ""
	_play("PickUp", 1.4, 0.1)


func _alert_sound() -> String:
	match type_id:
		"leaper": return "leaper"
		"wraith": return "wraith"
	return "groan"


## Enemy-specific senses. Returns true when the normal plan should be skipped.
func _special_think(dist: float) -> bool:
	if _screams:
		if _sees and _special_cd <= 0.0 and dist < 22.0:
			_special_left = 2.4
			_special_cd = 14.0
			_hold = true
			_current_anim = ""
			_play("Spellcast_Shoot", 0.5, 0.1)
			world.sfx_at("banshee", position, 3.0)
		if _special_left > 0.0:
			_hold = true
			return true
	return false


func _attack_style() -> String:
	if _caster:
		return "ranged"
	if weapon_id != "" and WeaponDefs.is_ranged(weapon_id):
		return "ranged"
	return "melee"


func _ranged_reach() -> float:
	if _caster:
		return 20.0
	return minf(float(WeaponDefs.ALL[weapon_id]["range"]) * 0.8, 30.0)


func _melee_reach() -> float:
	var r := 1.5 * _scale
	if weapon_id != "" and not WeaponDefs.is_ranged(weapon_id):
		r = maxf(r, float(WeaponDefs.ALL[weapon_id]["range"]) * 0.75)
	return r


func _attack_interval() -> float:
	if def.has("attack_rate"):
		return def["attack_rate"]
	if weapon_id != "":
		return maxf(0.9, float(WeaponDefs.ALL[weapon_id]["rate"]) * 2.2)
	return 1.1


func _melee_damage() -> float:
	if hero:
		return _damage + _hero_extra
	return _armed_damage if weapon_id != "" else _damage


func _physics_process(delta: float) -> void:
	if _dying > 0.0:
		_dying -= delta
		_tick_flash(delta)
		var floor_y := world.ground_at(position)
		if position.y > floor_y:
			position.y = maxf(floor_y, position.y - 14.0 * delta) # flyers and leapers fall out of the air
		if _dying <= 0.0:
			release()
		return
	if puppet:
		_puppet_tick(delta)
		return
	if _frozen > 0.0:
		_frozen -= delta
		if _frozen <= 0.0:
			_show_frozen(0.0)
	_tick_time += delta
	_tick_count += 1
	if _tick_every > 1 and _tick_count % _tick_every != 0:
		return
	delta = _tick_time
	_tick_time = 0.0
	var target := world.nearest_target(position)
	if target == null:
		return
	var to := target.global_position - position
	to.y = 0.0
	var dist := to.length()

	_tick_burn(delta)
	_tick_dot(delta)
	if not is_alive():
		return
	if _mark_time > 0.0:
		_mark_time -= delta
	reveal_left -= delta
	bar_time -= delta
	_special_cd -= delta
	_think -= delta
	_since_think += delta
	if _think <= 0.0:
		_think = randf_range(0.18, 0.28)
		_decide(target, to, dist, _since_think)
		_since_think = 0.0
	_attack_cd -= delta
	_hurt_stun -= delta
	_slow -= delta
	_tick_flash(delta)
	if _airborne:
		# A leap always finishes, even if something stuns it in mid-air.
		_tick_leap(target, delta)
		return
	if _stun > 0.0:
		_stun -= delta
		velocity = _knock
		_knock = _knock.lerp(Vector3.ZERO, min(1.0, delta * 8.0))
		if not flies and not phases:
			move_and_slide()
			position.y = world.ground_at(position)
		else:
			position += velocity * delta
		return
	if dormant:
		if _lure:
			_lure.rotation.y += delta * 1.6
		return
	_groan_cd -= delta
	if _groan_cd <= 0.0:
		_groan_cd = randf_range(5.0, 12.0)
		world.sfx_at(_idle_sound(), position, -14.0)

	if flies:
		_fly(target, to, dist, delta)
		return
	if _is_scarecrow and _watched:
		_animate_custom(delta, 0.0)
		return
	if _screams and _special_left > 0.0:
		_tick_scream(target, delta)
		return
	if _mounted:
		_tick_rider(target, to, dist, delta)
		return
	_tick_hero(target, dist, delta)
	_try_leap(target, dist)
	if not _airborne:
		_move(target, to, dist, delta)
		_combat(target, dist, delta)
		_stuck_check(delta)
		if _custom:
			_animate_custom(delta, velocity.length())


func _idle_sound() -> String:
	match type_id:
		"crow": return "crow"
		"wraith": return "wraith"
	return "groan"


func _tick_dot(delta: float) -> void:
	if _dot_time <= 0.0:
		return
	_dot_time -= delta
	_dot_tick -= delta
	if _dot_tick <= 0.0:
		_dot_tick = 0.5
		next_hitter = last_hitter
		take_damage(_dot_dps * 0.5, Vector3.ZERO, 0.0, centre())


## A scarecrow only moves while you are not looking at it.
func _is_watched(target: Target, dist: float) -> bool:
	if target is Ally or dist > 30.0:
		return false
	var eye := target.eye_position()
	var to_me := (centre() - eye).normalized()
	return to_me.dot(target.look_direction()) > 0.55 and world.has_line_of_sight(eye, centre())


func _try_leap(target: Target, dist: float) -> void:
	if not _leaps:
		return
	if _special_cd > 0.0 or not _sees or dist < 3.5 or dist > 9.5 or _attack_left > 0.0:
		return
	_special_cd = randf_range(3.0, 4.5)
	var aim := target.global_position + target.velocity * 0.35
	var flight := clampf(dist / 9.0, 0.45, 0.8)
	var flat := aim - position
	flat.y = 0.0
	_air_vel = flat / flight
	_air_vel.y = 0.5 * 18.0 * flight
	_airborne = true
	_shadow.visible = false
	_tick_every = 1
	world.sfx_at("leaper", position, -2.0)
	_current_anim = ""
	_play("Running_A", 1.6, 0.05)


func _tick_leap(target: Target, delta: float) -> void:
	_air_vel.y -= 18.0 * delta
	position += _air_vel * delta
	rotation.y = atan2(_air_vel.x, _air_vel.z)
	var floor_y := world.ground_at(position)
	if position.y <= floor_y and _air_vel.y < 0.0:
		position.y = floor_y
		_airborne = false
		_shadow.visible = true
		_attack_cd = 0.3
		_set_goal(target.global_position)
		var dist := position.distance_to(target.global_position)
		if dist < 2.2 and absf(target.global_position.y - position.y) < 2.4:
			target.hurt(_melee_damage(), position, self)
			world.sfx_at("attack", position, -3.0)
		# Never land inside something solid.
		var c := world.grid.to_cell(position)
		if not world.grid.is_free(c):
			var free := world.grid.to_world(world.grid.nearest_free(c))
			position.x = free.x
			position.z = free.z


## Banshee: hold still and scream, then every zombie around learns where you are.
func _tick_scream(target: Target, delta: float) -> void:
	_special_left -= delta
	var to := target.global_position - position
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 6.0))
	velocity = Vector3.ZERO
	if _special_left <= 0.0:
		_hold = false
		if _sees or position.distance_to(target.global_position) < 26.0:
			world.call_horde(self, target.global_position, 42.0)
			world.banner("A scream gives you away!", 2.0)
		_set_goal(_random_spot(18.0))
		state = State.SEARCH
		_search_left = 8.0


## Fallen Heroes learn a new trick as the night goes on.
func _tick_hero(target: Target, dist: float, delta: float) -> void:
	if not hero:
		return
	if _charges:
		if _special_left > 0.0:
			_special_left -= delta
			if dist < 2.4:
				_special_left = 0.0
				target.hurt(_melee_damage() * 1.5, position, self)
				if hero_minute >= 7:
					target.velocity += (target.global_position - position).normalized() * 8.0
		elif _special_cd <= 0.0 and _sees and dist > 6.0:
			_special_cd = 8.0 if hero_minute >= 6 else 12.0
			_special_left = 1.8
			world.sfx_at("gallop", position, 0.0)
	elif type_id == "hero_heavy" and hero_minute >= 7 and _special_cd <= 0.0 and dist < 5.0:
		_special_cd = 10.0
		world.fx_blast(position + Vector3.UP * 0.2, 3.5, Color(0.7, 0.55, 0.35, 0.4))
		world.sfx_at("hammer", position, 0.0)
		if target is Player:
			target.hurt(_melee_damage(), position, self)
	elif type_id == "hero_magician" and hero_minute >= 7 and _special_cd <= 0.0 and _sees:
		_special_cd = 22.0
		world.raise_for(self)


## Flyers circle high and dive at you when they have a clear line. Roofs protect you.
## After a dive they hang low for a moment, so even a sword gets its chance.
func _fly(target: Target, _to: Vector3, dist: float, delta: float) -> void:
	var high: float = def["fly_height"]
	_orbit += delta * 1.1
	var speed := _speed * (0.5 if _slow > 0.0 else 1.0)
	if type_id == "crow":
		_flock_left -= delta
		if _flock_left <= 0.0 and _dive <= 0.0:
			# The flock has had enough and moves on: straight up, out of sight, and gone.
			position += Vector3(sin(_orbit), 1.0, cos(_orbit)).normalized() * speed * delta
			_animate_custom(delta, 1.0)
			if position.y - world.ground_at(position) > 22.0:
				release()
			return
	var aim: Vector3
	if _recover > 0.0:
		_recover -= delta
		var side := Vector3(cos(_orbit * 2.0), 0.0, sin(_orbit * 2.0)) * 1.8
		aim = target.global_position + side + Vector3.UP * 0.8
		speed *= 0.45
	elif _windup > 0.0:
		# It stops, turns and calls out. Whoever hears it has time to look up.
		_windup -= delta
		aim = position
		var look := target.global_position - position
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), min(1.0, delta * 10.0))
		if _windup <= 0.0:
			_dive = 2.5
			# It dives at where you are about to be, so a step aside makes it miss.
			_dive_aim = target.eye_position() + target.velocity * 0.25 + Vector3.DOWN * 0.3
		if not _clear:
			_windup = 0.0
			_dive = 0.0
	elif _dive > 0.0:
		_dive -= delta
		aim = _dive_aim
		speed *= 1.25
		if position.distance_to(aim) < 1.0:
			_dive = 0.0
			# Hit or miss, it needs a moment before it can climb again.
			_recover = ZombieDefs.FLYER_RECOVER * (1.6 if _statue else 1.0)
			_special_cd = randf_range(5.0, 7.5) if _statue else randf_range(3.0, 5.0)
			if position.distance_to(target.eye_position()) < 1.6 and world.has_line_of_sight(position, target.eye_position()):
				target.hurt(_melee_damage(), position, self)
				world.sfx_at("crow" if type_id == "crow" else "attack", position, -3.0)
		if not _clear:
			_dive = 0.0
	else:
		var ground := target.global_position if (state == State.CHASE or dist < _sight) else _home
		aim = ground + Vector3(cos(_orbit) * 6.0, high, sin(_orbit) * 6.0)
		if _clear and _special_cd <= 0.0 and dist < _sight and (_statue or world.take_dive_turn()):
			_windup = DIVE_WARNING
			world.sfx_at("crow" if type_id == "crow" else "gargoyle", position, 0.0)
	var dir := aim - position
	velocity = dir.normalized() * speed if dir.length() > 0.2 else Vector3.ZERO
	position += (velocity + _knock) * delta
	_knock = _knock.lerp(Vector3.ZERO, min(1.0, delta * 6.0))
	position.y = maxf(position.y, world.ground_at(position) + 0.6)
	position.x = clampf(position.x, -World.HALF_SIZE + 1.0, World.HALF_SIZE - 1.0)
	position.z = clampf(position.z, -World.HALF_SIZE + 1.0, World.HALF_SIZE - 1.0)
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), min(1.0, delta * 6.0))
	_animate_custom(delta, 1.0)


func _animate_custom(delta: float, moving: float) -> void:
	_phase += delta * (9.0 if moving > 0.0 else 0.0)
	match model_id:
		"crow", "gargoyle":
			var rate := 3.2 if model_id == "crow" else 1.0
			var f := sin(_phase * rate) * 0.7
			(_visual.get_meta("wing_l") as Node3D).rotation.z = f
			(_visual.get_meta("wing_r") as Node3D).rotation.z = -f
		"mimic":
			(_visual.get_meta("lid") as Node3D).rotation.x = -absf(sin(_phase)) * 0.75
			_visual.position.y = absf(sin(_phase * 0.5)) * 0.25
		"scarecrow":
			if moving > 0.0:
				_visual.rotation.z = sin(_phase * 0.7) * 0.16
				(_visual.get_meta("arm_l") as Node3D).rotation.z = -0.25 + sin(_phase) * 0.25
				(_visual.get_meta("arm_r") as Node3D).rotation.z = 0.25 - sin(_phase) * 0.25


func _desired_speed() -> float:
	if _hold or _attack_left > 0.0 or _hurt_stun > 0.0:
		return 0.0
	var mult := 0.5 if _slow > 0.0 else 1.0
	if _charges and _special_left > 0.0:
		mult *= 2.6
	match state:
		State.CHASE: return _speed * mult
		State.SEARCH, State.INVESTIGATE: return _roam_speed * 1.5 * mult
	return _roam_speed * mult


func _move(_target: Target, to: Vector3, dist: float, delta: float) -> void:
	var dir := Vector3.ZERO
	var speed := _desired_speed()
	if speed > 0.0:
		if phases:
			if state == State.CHASE and _sees:
				if dist > _melee_reach() * 0.7:
					dir = to / maxf(dist, 0.01)
			elif _has_goal:
				dir = _goal - position
				dir.y = 0.0
				dir = dir.normalized()
		elif _direct:
			if dist > _melee_reach() * 0.7:
				var approach := to + _flank * clampf(dist - 2.5, 0.0, 4.0)
				dir = approach.normalized()
			_clear_path_only()
		elif _has_goal:
			if _needs_path and world.take_path_budget():
				_path = world.grid.path(position, _goal) if _full_path else world.grid.route(position, _goal)
				_full_path = false
				_path_i = 0
				_needs_path = false
			while _path_i < _path.size() and Vector2(_path[_path_i].x - position.x, _path[_path_i].z - position.z).length() < 0.65:
				_path_i += 1
			# A long journey is planned one stretch at a time.
			if _path_i >= _path.size() and not _arrived() and not _needs_path and world.now >= _next_plan:
				_next_plan = world.now + 0.4
				_needs_path = true
				_full_path = _path.is_empty() # the stretches led nowhere, so plan the whole way once
			if _path_i < _path.size():
				dir = _path[_path_i] - position
				dir.y = 0.0
				dir = dir.normalized()
	_move_dir = (dir + _separation).limit_length(1.0) if dir != Vector3.ZERO else _separation.limit_length(0.4)
	velocity = _move_dir * speed + _knock
	_knock = _knock.lerp(Vector3.ZERO, min(1.0, delta * 8.0))
	if phases:
		position += velocity * delta
	elif _tick_every > 1:
		# move_and_slide always uses one physics step, so a skipped tick needs a longer stride.
		var plain := velocity
		velocity *= float(_tick_every)
		move_and_slide()
		velocity = plain
	else:
		move_and_slide()
	position.y = world.ground_at(position) + (0.25 if phases else 0.0)
	if _sees or _hold or state == State.CHASE and dist < 4.0:
		if dist > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 9.0))
	elif dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), min(1.0, delta * 7.0))
	if _anim != null and _attack_left <= 0.0:
		if velocity.length_squared() < 0.04:
			_play("Idle")
		elif state == State.CHASE:
			_play("Running_A", maxf(0.55, _speed / 5.0))
		else:
			_play("Walking_C" if type_id == "normal" else "Walking_A", maxf(0.5, velocity.length() / 1.8))


func _clear_path_only() -> void:
	_needs_path = true
	_path = PackedVector3Array()
	_path_i = 0


func _combat(target: Target, dist: float, delta: float) -> void:
	if _attack_left > 0.0:
		_attack_left -= delta
		if _attack_hit_pending and _attack_left <= ATTACK_TIME * 0.5:
			_attack_hit_pending = false
			var again := target.global_position - position
			again.y = 0.0
			if again.length() < _melee_reach() + 0.5 and absf(target.position.y - position.y) < 2.4:
				if _damage > 0.0:
					target.hurt(_melee_damage(), position, self)
					if type_id == "hero_heavy" and hero_minute >= 4 and target is Player:
						(target as Player).velocity += (target.global_position - position).normalized() * 5.0
		return
	if _attack_cd > 0.0 or not _sees or _damage <= 0.0:
		return
	if _attack_style() == "ranged" and dist > 4.0:
		if dist < _ranged_reach():
			_attack_cd = 2.4 if _caster else maxf(1.5, _attack_interval())
			if hero and hero_minute >= 4:
				_attack_cd *= 0.7
			_attack_left = ATTACK_TIME
			_current_anim = ""
			var aim := target.eye_position() + Vector3.DOWN * 0.35
			var from := position + Vector3.UP * height * 0.75
			if _caster:
				_play("Spellcast_Shoot", 1.3, 0.1)
				world.spawn_fireball(from, aim, _damage, display_name())
				if type_id == "hero_magician" and hero_minute >= 4:
					world.spawn_fireball(from + Vector3.UP * 0.4, aim, _damage, display_name())
			else:
				_play("2H_Ranged_Shoot", 1.3, 0.1)
				var fire_tip := type_id == "hero_ranger" and hero_minute >= 4
				var reach := float(WeaponDefs.ALL[weapon_id]["range"])
				world.spawn_enemy_arrow(from, aim, _armed_damage, reach, fire_tip, display_name())
				if type_id == "hero_ranger" and hero_minute >= 7:
					world.spawn_enemy_arrow(from, aim + Vector3(1.2, 0, 0), _armed_damage, reach, fire_tip, display_name())
		return
	if dist < _melee_reach() and absf(target.position.y - position.y) < 2.4:
		_attack_cd = _attack_interval()
		_attack_left = ATTACK_TIME
		_attack_hit_pending = true
		_current_anim = ""
		if weapon_id != "" or def.get("claws", false):
			_play("1H_Melee_Attack_Chop", 1.6, 0.1)
		else:
			_play("Unarmed_Melee_Attack_Punch_A", 1.2, 0.1)
		world.sfx_at("attack", position, -8.0)


func _stuck_check(delta: float) -> void:
	if not _has_goal or _desired_speed() <= 0.0 or _direct:
		_stuck_timer = 0.0
		_stuck_from = position
		return
	_stuck_timer += delta
	if _stuck_timer > 1.6:
		if position.distance_to(_stuck_from) < 0.35:
			_needs_path = true
			_full_path = true
			if state == State.ROAM:
				_clear_goal()
		_stuck_timer = 0.0
		_stuck_from = position


func _tick_burn(delta: float) -> void:
	if burn_time <= 0.0:
		return
	burn_time -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		world.burn_tick(self)
	if burn_time <= 0.0:
		_stop_flames()


func _tick_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_restore_materials()


## Animation runs manually: every frame close up, rarely when far or behind the camera.
func _process(delta: float) -> void:
	_anim_accum += delta
	_frame += 1
	var p := world.player
	var every := 1
	if p:
		var to := position - p.global_position
		var d := to.length()
		if d > 45.0:
			every = 12
		elif d > 22.0:
			every = 4
		elif d > 10.0:
			every = 2
		if d > 4.0 and to.dot(-p.camera.global_basis.z) < 0.0:
			every = maxi(every, 6)
	if _frozen > 0.0:
		_anim_accum = 0.0
		return
	if _anim != null and (_frame + get_instance_id()) % every == 0:
		_anim.advance(_anim_accum)
		_anim_accum = 0.0
