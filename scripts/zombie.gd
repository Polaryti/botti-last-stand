class_name Zombie
extends CharacterBody3D
## Pooled enemy. Each one roams until it sees or hears something, then hunts, then
## searches where the player was last seen. Animation is throttled with distance.

enum State { ROAM, INVESTIGATE, CHASE, SEARCH }
enum Effect { STUN, SLOW, IGNITE, MARK, DOT, FORGET, FREEZE, TAUNT, PULL, BLEED, DISARM, FLINCH, ROOT, PIN, REVEAL, HAUL, DRIFT, BLIND } # new ones go at the end: the number travels

const DIVE_WARNING := 0.6

const LAYER := 4
const HEIGHT := 1.8
const LOOPS := ["Idle", "Walking_A", "Walking_C", "Running_A"]
const ATTACK_TIME := 0.62
const MARCH_UNTIL := 6.0 # how near its gate a zombie running up a lane slows to a walk
const LANE_AHEAD := 6.0 # up a lane, how far along its road a zombie aims: near enough never to leave it
const LANE_REACH := 7.0 # how far to the side of that road someone may stand and still be gone after
const LANE_ENGAGE := 12.0 # and how near they must be: until then the way to them is the road itself
const BODY_TOP := {"magic": 2.2027} # the mage's hat does not count towards its height
## Bodies that share another's animated model, dressed differently.
const BODY_FILES := {"woods_child": "normal_b", "fallen_revenant": "clever", # a Fallen Revenant is a Revenant's own body
	"drowned": "normal_a", "barnacle_brute": "normal_a", # the drowned of Vael, dressed by VaelModels
	"press_gang": "normal_b", "tide_witch": "magic", "harbourmaster": "normal_a", "lighthouse_keeper": "clever", "hollow_sovereign": "normal_a"}
const FAR := 34.0
const DUMMY_WINDOW := 5.0

static var _scenes := {}
static var _fit := {}
static var _shader: Shader
static var _materials := {}
static var _flash_material: StandardMaterial3D
static var _ice_material: StandardMaterial3D
static var _eye_mesh: Mesh
static var _claw_mesh: Mesh

const HOP_REACH := 9.5
const HOP_UP := 6.0
const HOP_GRAVITY := 18.0
const HOP_THINK := 0.4
const HOP_LOOK := 30.0

var mist_mind: MistMind
var mesenlla_mind: MesenllaMind # (a VaelMind for the drowned court of Port Vael)
var _court_light: OmniLight3D # the Lighthouse Keeper's great lamp
const KEEPER_LAMP := 1.4 # its light, until he lifts it and it blazes
var mesenlla_warning := false # a creature of Mesenlla is showing the tell of a special move
var world: World
var model_id := ""
var type_id := ""
var def: Dictionary = {}
var active := false
var spawn_generation := 0
var hp := 0.0
var max_hp := 0.0
var height := HEIGHT
var state: int = State.ROAM
var _pull_at := Vector3.ZERO
var _pull_left := 0.0
var weapon_id := ""
var blind_left := 0.0 # inside an enemy Nightfall: sees only BLIND_SIGHT metres
var soaked_left := 0.0 # soaked by a Stormcaller's Trident, on that Stormcaller's phone (TidecallerKit)
var _drips: CPUParticles3D
var _puddle: MeshInstance3D
static var _puddle_mesh: Mesh
var burn_time := 0.0
var xp_value := 10
var reveal_left := 0.0
var hero_minute := 0
var dormant := false
var flies := false
var phases := false
var hero := false
var fort_gate := -1 # Defend the Fort: the gate this one was sent against
var fort_shortcut := false # and whether it would rather take a breach somewhere else
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
var _shadow_at := Vector2(INF, INF)
var _shadow_floor := 0.0
var _shadow_walkable := false
var _shadow_terrain: Terrain
var _shadow_revision := -1
var _parts: Array[MeshInstance3D] = []
var _hand_mesh: WeaponVisual
var _eyes: MeshInstance3D
var _claws: Array = []
var _flames: CPUParticles3D

var _path := PackedVector3Array()
var _path_i := 0
var _needs_path := false
var _full_path := false
var _marching := false # in a fort with long lanes, running up its lane to the gate
## About a fort's business (its gate, its lane, the portal) rather than fighting someone: it looks
## where it is going, or at what it strikes, not at whoever it can see off to the side.
var _on_duty := false
var _duty_face := Vector3.INF # the gate or the portal it is striking
var _attack_aim := Vector3.INF # what its blow under way is aimed at: INF for its target
var _next_plan := 0.0
var _goal := Vector3.ZERO
var _has_goal := false
var _direct := false
var _walk_around_until := 0.0
var _blocked_timer := 0.0
var _blocked_from := Vector3.ZERO
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
var _death_total := 0.0 # how long this death takes, for creatures that fall in their own way
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
var _dot_pending := 0.0
var _dot_wait := 0.25
var _poison_dps := 0.0
var dot_kind := "" # set just before a damage-over-time tick's take_damage: "poison", "bleed", "fire"
var _bleed_dps := 0.0
var poison_left := 0.0
var bleed_left := 0.0
var _debuff_fx: CPUParticles3D
var _gate_wait := 0.0
var _stun_fx: CPUParticles3D
var shown_debuffs := 0 # on another phone: which of them the host last told us about
var _mark_time := 0.0
var toll_until := 0.0 # pinned by a Highwayman's Toll: its plunder is sure while this lasts
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
## A wyvern's element ("fire", "ice" or "storm"; ZombieDefs "elements"), chosen as it rises.
var element := ""
## Hastened by a Mist Wolf's howl: this many seconds left of moving HASTE times as fast.
var haste_left := 0.0
const HASTE := 1.35
## Held by an Antler Charm's vines: it can strike what is in reach, but cannot move. A boss is held
## half as long; nothing can be caught again until ANTLER_AGAIN after it was caught; fliers are not.
var root_left := 0.0
var _root_again := -100.0
var _vines: MeshInstance3D
static var _vine_mesh: Mesh
## A War Wyvern's rider (wyvern_rider): the wyvern it rides, and which of its seats.
var carrier: Zombie
var seat := -1
var _loose_was := 0.0
var _is_dummy := false
var _dummy_log: Array = []
var _dummy_last := 0.0
var _dummy_show := 0.0
var _dummy_label: Label3D
var _horse_node: Node3D # a Dread Rider's horse (a MeshInstance3D), or a Woodland Cavalry's bear (MesenllaModels.cavalry_bear)
var _mount_fall := 0.0 # seconds left of the cavalry's bear going down, once it is brought down
var _seat_y := 0.0 # where the rider's body stands, from its feet, sitting on the bear
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
# In the Mists: jumping over gaps and along the stones after whoever it is chasing.
var _can_hop := false
var _hop_reach := HOP_REACH
var _hop_up := HOP_UP
var _hop_cd := 0.0
var _hop_to := Vector3.INF
var _hop_left := 0.0
var _hop_line := -1
var _hop_i := -1
var _hop_walk := Vector3.INF
var _vault_from := Vector3.INF
var _perch_line := -1
var _perch_i := -1
var _perch_lost := 0.0
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
	return _skin(model_id, id, source)


static func _skin(model: String, id: String, source: Material) -> ShaderMaterial:
	var key := model + id
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", (source as StandardMaterial3D).albedo_texture)
	m.set_shader_parameter("tint", ZombieDefs.def_of(id)["tint"])
	_materials[key] = m
	return m


## A zombie's body for a stage away from the night (the Store's demonstrations): the same file, rotten
## skin and red eyes as in a night, 1.8 m tall and facing -Z, its animations ready to play. Returns
## {"node", "anim", "parts"}.
static func show_body(model: String, id := "normal") -> Dictionary:
	_setup_static()
	if not _scenes.has(model):
		_scenes[model] = load("res://assets/characters/%s.glb" % BODY_FILES.get(model, model))
	var visual: Node3D = (_scenes[model] as PackedScene).instantiate()
	visual.rotation.y = PI
	var anim: AnimationPlayer = visual.find_children("*", "AnimationPlayer", true, false)[0]
	for n: String in LOOPS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var skeleton: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	BodyAnim.install(anim, skeleton)
	var parts: Array[MeshInstance3D] = []
	var high := 0.0
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.material_override = _skin(model, id, part.mesh.surface_get_material(0))
		high = maxf(high, part.get_aabb().end.y)
		parts.append(part)
	visual.scale = Vector3.ONE * HEIGHT / float(BODY_TOP.get(model, maxf(high, 0.5)))
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skeleton.add_child(head)
	var eyes := MeshInstance3D.new()
	eyes.mesh = _eye_mesh
	eyes.position = Vector3(0, 0.42, 0.49)
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(eyes)
	return {"node": visual, "anim": anim, "parts": parts}


## What a frozen creature is coloured.
static func ice_material() -> StandardMaterial3D:
	_setup_static()
	return _ice_material


func _build_visual() -> void:
	_setup_static()
	_custom = model_id in ["crow", "gargoyle", "mimic", "scarecrow", "dummy", "harrier", "lantern_wisp", "mist_weaver", "veil_regent"] or model_id in MesenllaModels.KINDS
	if _custom:
		_visual = MistModels.build(model_id) if model_id in MistModels.KINDS else MesenllaModels.build(model_id) if model_id in MesenllaModels.KINDS else EnemyModels.build(model_id)
		add_child(_visual)
		# A creature of Mesenlla is built of parts on pivots: all of them flash when struck.
		var deep := model_id in MesenllaModels.KINDS or model_id == "crow" # (a Carrion Crow is a posed bird)
		for mi in _visual.find_children("*", "MeshInstance3D", deep, false):
			_parts.append(mi as MeshInstance3D)
			(mi as MeshInstance3D).set_meta("mist_rest", (mi as MeshInstance3D).transform)
			# Its own look (glowing eyes, mist, a walking shader) comes back after a flash.
			(mi as MeshInstance3D).set_meta("own_material", (mi as MeshInstance3D).material_override)
		if deep:
			MesenllaModels.remember_pose(_visual)
		_fit[model_id] = 1.0
		if model_id == "mimic":
			_build_lure()
	else:
		var path := "res://assets/characters/%s.glb" % BODY_FILES.get(model_id, model_id)
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
		BodyAnim.install(_anim, _skeleton)
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
			_horse_node = HorseModel.make()
			_horse_node.rotation.y = PI
			_horse_node.visible = false
			add_child(_horse_node)
		elif model_id == "fallen_revenant":
			# A Revenant, as a Revenant player is seen: the class's own gear and its ghostly look. Its
			# flash on a hit returns to that look, not a zombie's skin.
			_eyes.visible = false
			ClassGear.wear(_visual, "revenant")
			_parts.clear()
			for mi in _visual.find_children("*", "MeshInstance3D", true, false):
				var piece := mi as MeshInstance3D
				piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				piece.set_meta("own_material", piece.material_override)
				_parts.append(piece)
		elif model_id == "woods_child":
			# A Child of the Woods: leaves, bark and twigs over a small body, green eyes, and a bear to ride.
			_eyes.visible = false
			var gear := MesenllaModels.child_gear()
			var worn: Array[MeshInstance3D] = []
			for bone: String in gear:
				worn.append(_attach(bone, gear[bone], Vector3.ZERO))
			var eyes := _attach("head", MesenllaModels.child_eyes(), Vector3.ZERO)
			eyes.material_override = MesenllaModels.glow_material()
			_eyes = eyes
			worn.append(eyes)
			# Its leaves, bark and eyes are of it too: they freeze, and flash when struck, with its
			# body, and come back to their own look after. (So does its bear, made when it first rides.)
			for piece in worn:
				piece.set_meta("own_material", piece.material_override)
				_parts.append(piece)
		elif model_id in ["drowned", "barnacle_brute"]:
			# One of the drowned of Vael: a sailor's cap, weed and rope, or a Brute's crust of barnacles
			# and coral, and the pale sea-green eyes of all of them. Their gear flashes and freezes with them.
			_eyes.visible = false
			var gear := VaelModels.sailor_gear() if model_id == "drowned" else VaelModels.brute_gear()
			var worn: Array[MeshInstance3D] = []
			for bone: String in gear:
				worn.append(_attach(bone, gear[bone], Vector3.ZERO))
			var eyes := _attach("head", VaelModels.drowned_eyes(), Vector3.ZERO)
			eyes.material_override = MesenllaModels.glow_material()
			_eyes = eyes
			worn.append(eyes)
			for piece in worn:
				piece.set_meta("own_material", piece.material_override)
				_parts.append(piece)
		elif model_id in VaelModels.GEARED:
			# The drowned court of Vael: each in its own clothes, with what it carries (VaelModels.gear_for).
			# Pieces keyed "bone:glow" are lit from inside: eyes, a lamp's lens, a witch's float.
			_eyes.visible = false
			var gear := VaelModels.gear_for(model_id)
			var worn: Array[MeshInstance3D] = []
			for key: String in gear:
				if model_id == "hollow_sovereign" and key.begins_with("handslot"): continue
				var piece := _attach(key.get_slice(":", 0), gear[key], Vector3.ZERO)
				if key.begins_with("handslot"):
					piece.rotation = Vector3(0, 0, -1.5) if model_id == "hollow_sovereign" else VaelModels.HELD_TURN
				if key.ends_with(":glow"):
					piece.material_override = MesenllaModels.glow_material()
				worn.append(piece)
				if model_id == "lighthouse_keeper" and key == "chest:glow":
					# The great lamp on his back lights the ground around him, and blazes as he lifts it.
					_court_light = OmniLight3D.new()
					_court_light.light_color = Color(1.0, 0.86, 0.5)
					_court_light.light_energy = KEEPER_LAMP
					_court_light.omni_range = 9.0
					_court_light.shadow_enabled = false
					_court_light.visible = Game.quality > 0
					_court_light.position = Vector3(0, 0.25, -0.95)
					piece.get_parent().add_child(_court_light)
			var eyes_mesh := VaelModels.court_eyes(model_id)
			if eyes_mesh:
				var eyes := _attach("head", eyes_mesh, Vector3.ZERO)
				eyes.material_override = MesenllaModels.glow_material()
				_eyes = eyes
				worn.append(eyes)
			for piece in worn:
				piece.set_meta("own_material", piece.material_override)
				_parts.append(piece)
	if model_id == "hollow_sovereign": SovereignRegalia.install(self)
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
	spawn_generation += 1
	type_id = id
	element = ""
	haste_left = 0.0
	root_left = 0.0
	revealed_left = 0.0
	_root_again = -100.0
	if _vines:
		_vines.visible = false
	carrier = null
	seat = -1
	if model_id in MistModels.KINDS:
		for part in _parts:
			part.transform = part.get_meta("mist_rest", Transform3D.IDENTITY)
	if model_id in MesenllaModels.KINDS or model_id == "crow":
		# Back on its feet after the last time this body fell.
		MesenllaModels.reset_pose(_visual)
		if model_id == "angler":
			_visual.set_meta("risen", 0.0)
			VaelModels.bury(_visual) # it lies in wait in the sand
	mist_mind = MistMind.new() if id in MistModels.BORN else null
	mesenlla_mind = VaelSkyMind.new(id) if id in VaelSkyMind.KINDS else VaelMind.new(id) if VaelMind.handles(id) else MesenllaMind.new(id) if MesenllaMind.wants(id) else null
	mesenlla_warning = false
	def = ZombieDefs.def_of(id)
	_is_dummy = def.get("dummy", false)
	_dummy_log.clear()
	if _dummy_label:
		_dummy_label.visible = false
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
	_can_hop = world.terrain.has_islands() and not flies and not phases and not _is_dormant_type and not _is_scarecrow and not def.get("rider", false)
	_hop_reach = float(def.get("hop_reach", HOP_REACH))
	_hop_up = float(def.get("hop_up", HOP_UP))
	_hop_cd = randf() * HOP_THINK
	_hop_left = 0.0
	_vault_from = Vector3.INF
	_hop_line = -1
	_hop_i = -1
	_hop_walk = Vector3.INF
	_perch_line = -1
	_perch_i = -1
	_perch_lost = 0.0
	hero_minute = minute
	weapon_id = ""
	_on_duty = false
	_duty_face = Vector3.INF
	_attack_aim = Vector3.INF
	blind_left = 0.0
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
	if is_boss() or def.get("miniboss", false):
		hp *= 1.0 + 0.55 * maxi(0, (Net.roster.size() if Net.active() else world.players.size()) - 1)
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
	_dot_pending = 0.0
	_dot_wait = 0.25
	_poison_dps = 0.0
	_bleed_dps = 0.0
	poison_left = 0.0
	bleed_left = 0.0
	show_debuffs(false, false)
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
	_show_stun(false)
	_slow = 0.0
	_predicted = false
	# Each zombie approaches from its own side, so a group ends up surrounding you.
	var a := randf() * TAU
	_flank = Vector3.ZERO if id == "beast" else Vector3(cos(a), 0, sin(a))
	height = (2.2 if model_id == "lantern_wisp" else 2.35 if model_id in MistModels.KINDS else float(def.get("tall", HEIGHT))) * s
	position = at
	last_hitter = 0
	next_hitter = 0
	var ground := world.ground_at(at)
	if not _statue:
		position.y = ground
	if flies and not dormant:
		position.y = ground + float(def["fly_height"])
	_capsule.radius = (0.7 if flies else float(def.get("radius", 0.36))) * s
	_capsule.height = height
	_shape.position = Vector3(0, height * 0.5, 0)
	_visual.scale = Vector3.ONE * float(_fit[model_id]) * s
	_shadow.scale = Vector3(s, 1, s)
	_shadow.visible = position.y - ground < 0.5
	state = State.ROAM
	weapon_id = ""
	if _hand_mesh:
		_hand_mesh.equip("")
	if def.has("weapon"):
		weapon_id = def["weapon"]
		_show_weapon(weapon_id)
	elif def.has("weapons"):
		# Whatever it found: a blade, a spear or a bow, each as often as its odds say.
		var found: Array = def["weapons"]
		var odds: Array = def.get("weapon_odds", [])
		weapon_id = str(found[randi() % found.size()] if odds.size() != found.size() else found[pick_weighted(odds)])
		_show_weapon(weapon_id)
	for c: MeshInstance3D in _claws:
		c.visible = def.get("claws", false)
	_visual.position = Vector3.ZERO
	if model_id == "veil_regent":
		(_visual.get_node("RegentHealth") as Label3D).visible = true
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
	if mesenlla_mind:
		mesenlla_mind.start(self)


func _show_mount(on: bool, falls := false) -> void:
	var was := _mounted
	_mounted = on
	if on and _horse_node == null and model_id == "woods_child":
		_make_bear_mount()
	var bear := _horse_node != null and not (_horse_node is MeshInstance3D)
	if _horse_node:
		_mount_fall = 0.0
		_horse_node.top_level = false
		if bear:
			MesenllaModels.reset_pose(_horse_node)
		_horse_node.visible = on
		_horse_node.rotation = Vector3(0, 0 if bear else PI, 0)
		_horse_node.position = Vector3.ZERO
		_visual.position.x = 0.0
		_horse_node.scale = Vector3.ONE * _scale * (MesenllaModels.CAVALRY_SIZE if bear else HorseModel.RIDDEN_SIZE)
		if bear:
			if not on and was and falls:
				# Brought down: the bear stays where it fell and rolls over, and its rider jumps clear.
				_horse_node.visible = true
				_horse_node.top_level = true
				_horse_node.global_transform = global_transform.scaled_local(Vector3.ONE * _scale * MesenllaModels.CAVALRY_SIZE)
				_mount_fall = MOUNT_FALL_TIME
	_visual.rotation = Vector3.ZERO
	_visual.position.z = 0.0
	if bear and on:
		_seat_rider()
	else:
		_visual.position.y = HorseModel.SADDLE * _scale if on else 0.0
	if def.get("rider", false):
		# On horseback there is a lot more of it to hit.
		_capsule.radius = (0.85 if on else 0.36) * _scale
		_capsule.height = height + (1.1 * _scale if on else 0.0)
		_shape.position = Vector3(0, _capsule.height * 0.5, 0)


## Which of these weights wins a draw, each in proportion to its weight.
static func pick_weighted(weights: Array) -> int:
	var total := 0.0
	for w: Variant in weights:
		total += float(w)
	var roll := randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return weights.size() - 1


## A training dummy cannot die or do anything back. It only says how hard it has been hit.
func _tick_dummy(delta: float) -> void:
	_tick_burn(delta)
	_tick_dot(delta)
	_tick_flash(delta)
	bar_time = 0.0
	if _stun > 0.0:
		_stun -= delta
		if _stun <= 0.0:
			_show_stun(false)
	_knock = Vector3.ZERO
	_hurt_stun = 0.0
	var dealt := max_hp - hp
	hp = max_hp
	if dealt > 0.0:
		_dummy_last = dealt
		_dummy_log.append([world.now, dealt])
	while not _dummy_log.is_empty() and world.now - float(_dummy_log[0][0]) > DUMMY_WINDOW:
		_dummy_log.pop_front()
	_dummy_show -= delta
	if _dummy_show <= 0.0:
		_dummy_show = 0.2
		var total := 0.0
		for entry: Array in _dummy_log:
			total += float(entry[1])
		if _dummy_label == null:
			_dummy_label = Label3D.new()
			_dummy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_dummy_label.font = UiTheme.bold_font()
			_dummy_label.font_size = 48
			_dummy_label.pixel_size = 0.009
			_dummy_label.outline_size = 10
			_dummy_label.position.y = 2.75
			add_child(_dummy_label)
		_dummy_label.visible = not _dummy_log.is_empty()
		_dummy_label.text = "Last hit %d\n%d a second" % [int(_dummy_last), int(total / DUMMY_WINDOW)]


## The rider comes through at a gallop, turns wide, and comes through again. On a bear (the Woodland
## Cavalry) it sits astride: the spear couched as the bear gallops in, driven home as they pass while
## the bear rakes with a paw, then brandished overhead as the bear half rears and roars, wheeling.
func _tick_rider(target: Target, to: Vector3, dist: float, delta: float) -> void:
	var on_bear: bool = def.get("mount", "") == "bear"
	if _attack_left > 0.0:
		_attack_left -= delta
	if _ride_pass > 0.0:
		_ride_pass -= delta
		velocity = _ride_dir * _speed * (0.5 if _slow > 0.0 else 1.0)
		rotation.y = lerp_angle(rotation.y, atan2(_ride_dir.x, _ride_dir.z), min(1.0, delta * 10.0))
		move_and_slide()
		position.y = world.ground_at(position)
		if on_bear and _attack_left <= 0.0:
			_play("RideCharge", 1.0, 0.15)
		if not _ride_hit and dist < 2.7 and absf(target.global_position.y - position.y) < 2.6:
			_ride_hit = true
			_attack_left = ATTACK_TIME * 0.6
			_current_anim = ""
			if on_bear:
				_play("RideThrust", 1.0, 0.04)
			else:
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
		if on_bear and _attack_left <= 0.0:
			_play("RideBrandish", 1.0, 0.15)
		return
	if _sees and dist > 1.0:
		_ride_dir = to / dist
		_ride_pass = dist / _speed + 0.7
		_ride_hit = false
		world.sfx_at("gallop", position, 0.0)
		return
	_move(target, to, dist, delta)
	_play("Ride" if on_bear else "Idle")


## The Woodland Cavalry's bear, the first time this body rides one.
func _make_bear_mount() -> void:
	_horse_node = MesenllaModels.cavalry_bear()
	_horse_node.visible = false
	add_child(_horse_node)
	MesenllaModels.remember_pose(_horse_node)
	for mi in _horse_node.find_children("*", "MeshInstance3D", true, false):
		var piece := mi as MeshInstance3D
		piece.set_meta("own_material", piece.material_override)
		_parts.append(piece)
	if _frozen > 0.0 or _flash > 0.0:
		_restore_materials()


const MOUNT_FALL_TIME := 1.8 # seconds the cavalry's bear takes to roll over and sink away, brought down


## The rider sits in the bear's saddle and moves with its back: up and down with its gallop, tipped
## back as it half rears.
func _seat_rider() -> void:
	var seat := _horse_node.get_node_or_null("Rig/Hind/Torso/Saddle") as Node3D
	if seat == null or not seat.is_inside_tree():
		return
	var to := global_transform.affine_inverse() * seat.global_transform
	var turn := Basis(to.basis.get_rotation_quaternion())
	var size := _visual.scale
	_visual.transform = Transform3D(turn.scaled(size), to.origin - turn.y * _rider_hip() * size.y)
	_seat_y = _visual.position.y


## How high the rider's hips are above its feet, in its body's own measure, sitting astride.
func _rider_hip() -> float:
	if not _fit.has("woods_child_hip"):
		var hip := 0.42
		if _skeleton:
			var i := _skeleton.find_bone("hips")
			if i >= 0:
				var rest := _skeleton.get_bone_global_rest(i)
				hip = ((_visual.global_transform.affine_inverse() * _skeleton.global_transform) * rest.origin).y
		_fit["woods_child_hip"] = hip
	return float(_fit["woods_child_hip"])


## A mount under its rider: the horse's legs swinging with its pace, or the bear moving with what
## its rider is doing, the rider sitting in its saddle. pace: metres a second.
func _tick_mount(delta: float, pace: float) -> void:
	if _horse_node is MeshInstance3D:
		HorseModel.set_gait(_horse_node as MeshInstance3D, clampf(pace / 7.0, 0.0, 1.0))
		return
	MesenllaModels.ride_bear(self, _horse_node, delta, pace, _current_anim)
	_seat_rider()


## The cavalry's bear, brought down: it rolls over where it fell, then sinks away.
func _tick_mount_fall(delta: float) -> void:
	if _mount_fall <= 0.0 or _horse_node == null:
		return
	_mount_fall -= delta
	var t := MOUNT_FALL_TIME - _mount_fall
	var over := smoothstep(0.0, 0.7, t)
	var rig := _horse_node.get_node("Rig") as Node3D
	rig.rotation.z = 1.5 * over
	rig.position.y = 0.42 * over
	var head := rig.get_node("Hind/Torso/Head") as Node3D
	head.rotation.x = lerpf(head.rotation.x, 0.5 * over, minf(1.0, delta * 6.0))
	rig.position.y -= 1.2 * smoothstep(1.1, MOUNT_FALL_TIME, t)
	if _mount_fall <= 0.0:
		_horse_node.visible = false
		_horse_node.top_level = false
		rig.rotation.z = 0.0
		rig.position = Vector3.ZERO


## Below 40% health the horse goes down, and whoever rode it fights on foot.
func _check_dismount() -> void:
	if _mounted and hp < max_hp * 0.4:
		_show_mount(false, true)
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
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "handslot.r"
		_skeleton.add_child(attachment)
		_hand_mesh = WeaponVisual.new()
		attachment.add_child(_hand_mesh)
	var d: Dictionary = WeaponDefs.ALL[id]
	_hand_mesh.equip(id)
	var hold := 0.55 if WeaponDefs.is_ranged(id) or id in ["lance", "spear", "pitchfork", "javelins"] else 1.0
	_hand_mesh.scale = Vector3.ONE * float(d["scale"]) * hold * 2.2 / float(_fit[model_id])
	_hand_mesh.rotation = WeaponDefs.hand_rotation(id)
	if id in WeaponDefs.ALIGNED_HELD:
		_hand_mesh.hold(self, true, WeaponDefs.held_size(id) * _scale)


func _restore_materials() -> void:
	if _frozen > 0.0:
		for p in _parts:
			p.material_override = _ice_material
		return
	if _custom or model_id == "fallen_revenant":
		for p in _parts:
			p.material_override = p.get_meta("own_material", null)
		return
	var ghost: Variant = def.get("ghost")
	for p in _parts:
		if p.has_meta("own_material"):
			p.material_override = p.get_meta("own_material")
		elif ghost != null:
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
	if _hand_mesh and anim_name in ["Thrust", "Overhead", "Sweep", "BoSpin", "Throw", "1H_Melee_Attack_Chop", "2H_Ranged_Shoot"]:
		_hand_mesh.attack()
	_current_anim = anim_name
	_anim.speed_scale = speed
	_anim.play(anim_name, blend)


## A boss of the Mists or of Mesenlla: shrugs off long stuns, and grows with the number of players.
func is_boss() -> bool:
	return def.get("mist_boss", false) or def.get("mesenlla_boss", false) or def.get("vael_boss", false)


## The Harbourmaster, the Mad Lighthouse Keeper and the Kraken's Arms: not bosses (the night does not
## wait for them), but each comes once, grows with the number of players and shrugs off half a stun.
func is_miniboss() -> bool:
	return def.get("miniboss", false)


func is_alive() -> bool:
	return active and _dying <= 0.0


func display_name() -> String:
	return def["name"]


func is_hunting() -> bool:
	return is_alive() and state == State.CHASE


## The Fallen (the Fallen Heroes, and the Fallen Revenant of the Mists): a long bar with a name over
## them while they hunt.
func named_bar() -> bool:
	return hero or bool(def.get("fallen", false)) or is_miniboss() or def.get("vael_boss", false)


func headshot_at(y: float) -> bool:
	return y > position.y + height * 0.76


func centre() -> Vector3:
	return position + Vector3.UP * height * 0.55


## How wide the body really is. Models are wider than the capsule they collide with, and a hit
## that lands on what you can see should count.
func body_radius() -> float:
	return _capsule.radius * 1.4


func is_unaware() -> bool:
	return is_alive() and state != State.CHASE


func is_behind(from: Vector3) -> bool:
	var look := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var to := from - position
	to.y = 0.0
	return to.length() > 0.01 and look.dot(to.normalized()) < -0.25


## Shown by a flare's light: nothing hidden stays hidden in it (Anglers lying in wait, for one).
var revealed_left := 0.0
func reveal(seconds: float) -> void:
	if puppet:
		Net.effect_zombie(self, Effect.REVEAL, seconds)
		return
	revealed_left = maxf(revealed_left, seconds)


## Small enough for a Boarding Hook to drag: not a boss, nor anything much bigger than a person.
func control_immune() -> bool:
	return is_boss() or is_miniboss()


func draggable() -> bool:
	return not is_boss() and not def.get("miniboss", false) and _scale < 1.5 and not flies and carrier == null


## Pinned by a Toll knife, on this phone (only the Highwayman's phone counts it).
func tolled() -> bool:
	return world != null and world.now < toll_until


func mark(mult: float, seconds: float) -> void:
	if puppet:
		Net.effect_zombie(self, Effect.MARK, mult, seconds)
		return
	_mark_mult = maxf(_mark_mult if _mark_time > 0.0 else 1.0, mult)
	_mark_time = seconds


## A tick of poison, bleeding or fire shows, in its colour, to whoever put it on: here when that is
## this phone's player (or no one in particular, alone), else on that person's phone.
func _show_dot(amount: float, kind: String) -> void:
	var by := last_hitter
	if not Net.active() or by == 0 or by == Net.my_id():
		world.damage_numbers.show_dot(get_instance_id(), centre() + Vector3.UP * 0.5, amount, kind)
	elif Net.is_host() and not Net.is_bot(by) and net_id >= 0:
		Net.dot_number(by, net_id, amount, kind)


## Poison also makes it take 5% more from everything. Bleeding also slows it by 10%.
func add_dot(dps: float, seconds: float, bleeding := false) -> void:
	if puppet:
		Net.effect_zombie(self, Effect.BLEED if bleeding else Effect.DOT, dps, seconds)
		return
	if not is_finite(dps) or not is_finite(seconds) or dps < 0.0 or seconds <= 0.0:
		return
	if bleeding:
		_bleed_dps = maxf(_bleed_dps if bleed_left > 0.0 else 0.0, dps)
		bleed_left = maxf(bleed_left, seconds)
	else:
		_poison_dps = maxf(_poison_dps if poison_left > 0.0 else 0.0, dps)
		poison_left = maxf(poison_left, seconds)
	show_debuffs(poison_left > 0.0, bleed_left > 0.0)


## Stars circling the head.
func _show_stun(on: bool) -> void:
	if _stun_fx == null:
		if not on:
			return
		_stun_fx = CPUParticles3D.new()
		_stun_fx.amount = 5
		_stun_fx.lifetime = 0.7
		_stun_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_stun_fx.emission_sphere_radius = 0.3
		_stun_fx.gravity = Vector3.ZERO
		_stun_fx.local_coords = true
		_stun_fx.orbit_velocity_min = 1.0
		_stun_fx.orbit_velocity_max = 1.4
		_stun_fx.position = Vector3.UP * 2.0
		var star := BoxMesh.new()
		star.size = Vector3(0.09, 0.09, 0.09)
		var look := StandardMaterial3D.new()
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.albedo_color = Color(1.0, 0.85, 0.3)
		star.material = look
		_stun_fx.mesh = star
		add_child(_stun_fx)
	if _stun_fx.emitting != on:
		_stun_fx.emitting = on


## Green bubbles for poison, red drops for bleeding. Made the first time they are needed.
func show_debuffs(poisoned: bool, bleeding: bool) -> void:
	if not poisoned and not bleeding:
		if _debuff_fx:
			_debuff_fx.emitting = false
		return
	if _debuff_fx == null:
		_debuff_fx = CPUParticles3D.new()
		_debuff_fx.amount = 10
		_debuff_fx.lifetime = 0.8
		_debuff_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_debuff_fx.emission_sphere_radius = 0.35
		_debuff_fx.position = Vector3.UP * 1.0
		_debuff_fx.gravity = Vector3.ZERO
		var dot := QuadMesh.new()
		dot.size = Vector2(0.11, 0.11)
		var look := StandardMaterial3D.new()
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		look.vertex_color_use_as_albedo = true
		dot.material = look
		_debuff_fx.mesh = dot
		add_child(_debuff_fx)
	_debuff_fx.color = Color(0.35, 0.95, 0.25) if poisoned else Color(0.85, 0.08, 0.06)
	_debuff_fx.gravity = Vector3.UP * (1.0 if poisoned else -3.0)
	_debuff_fx.emitting = true


# --- Damage ------------------------------------------------------------------

func take_damage(amount: float, from_dir: Vector3, knock: float, hit_pos: Vector3) -> void:
	var dot := dot_kind
	dot_kind = ""
	if not is_alive():
		return
	if poison_left > 0.0:
		amount *= 1.05
	if puppet:
		# Show the hit straight away. The host has the last word on whether it killed.
		world.damage_numbers.show_hit(get_instance_id(), hit_pos, amount, max_hp)
		hp = maxf(hp - amount, 1.0)
		bar_time = 2.5
		_flash_on()
		world.fx_gore(hit_pos, def.get("tint", Color(0.3, 0.3, 0.3)))
		world.sfx_at(_hurt_sound(), position, -8.0)
		Net.hit_zombie(self, amount, from_dir, knock, hit_pos)
		return
	# Your side's blows (yours, your pet's, your summons') show what they took.
	var ours := next_hitter == 0 and world.acting() == world.player
	if next_hitter != 0:
		last_hitter = next_hitter
	elif Net.active():
		# Whoever is acting right now: this phone's player, or a bot on the host.
		last_hitter = world.acting().net_id() if world.acting() else Net.my_id()
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
	if dot != "":
		_show_dot(amount, dot)
	elif ours:
		world.damage_numbers.show_hit(get_instance_id(), hit_pos, amount, max_hp)
	hp -= amount
	if _is_dummy:
		hp = maxf(hp, 1.0)
	bar_time = 2.5
	_flash_on()
	if not control_immune() and flies and (_dive > 0.0 or _windup > 0.0):
		# A blow knocks it out of its dive, and it hangs there for a moment.
		_dive = 0.0
		_windup = 0.0
		_recover = maxf(_recover, 0.8)
	if not control_immune() and not def.get("rooted", false): # (a Kraken's Arm stands in the sea floor)
		_knock += Vector3(from_dir.x, 0, from_dir.z).normalized() * knock / _scale
	world.fx_gore(hit_pos, def.get("tint", Color(0.3, 0.3, 0.3)))
	if Net.is_host():
		Net.gore(hit_pos, def.get("tint", Color(0.3, 0.3, 0.3)))
	if hp <= 0.0:
		_die()
		return
	if _is_dummy:
		world.sfx_at("thunk", position, -8.0)
		return
	_check_dismount()
	world.sfx_at(_hurt_sound(), position, -8.0)
	if type_id != "beast" and not control_immune():
		_hurt_stun = 0.1
	var p := world.nearest_player(position)
	if p:
		_start_chase(p.global_position)


## The voices of Mesenlla: for an alert, an idle sound, and a death.
const MESENLLA_VOICES := {"wyvern_rider": "woods_chatter", "bear": "bear_roar", "mist_bear": "bear_roar", "eagle": "eagle_cry", "mist_eagle": "eagle_cry",
	"shapeshifter": "shapeshift", "child_of_woods": "woods_chatter", "woodland_cavalry": "woods_chatter", "earth_elemental": "stone_grind",
	"mist_elemental": "mist_blink", "storm_elemental": "storm_call", "wyvern": "wyvern_roar", "great_revenant_elemental": "stone_grind",
	"war_wyvern": "wyvern_roar",
	"wreck_gull": "wreck_gull_call", "storm_ray": "storm_ray_call", "bell_wraith": "bell_wraith_call",
	"drowned_sailor": "drowned_moan", "barnacle_brute": "drowned_moan", "brine_hound": "hound_snarl", "lantern_jelly": "jelly_hum",
	"siren": "siren_hum", "press_gang": "press_shout", "tide_witch": "witch_call", "harbourmaster": "harbour_growl", "lighthouse_keeper": "keeper_laugh",
	"kraken_arm": "kraken_rise", "hollow_sovereign": "sovereign_voice", "leviathan": "leviathan_roar", "kraken": "kraken_roar"}


## How each of them sounds when struck, and when it dies.
const MESENLLA_HURT := {"wyvern_rider": "woods_hurt", "bear": "bear_hurt", "mist_bear": "bear_hurt", "eagle": "eagle_hurt", "mist_eagle": "eagle_hurt",
	"child_of_woods": "woods_hurt", "woodland_cavalry": "woods_hurt", "earth_elemental": "stone_hit", "great_revenant_elemental": "stone_hit",
	"mist_elemental": "mist_hurt", "storm_elemental": "storm_hurt", "wyvern": "wyvern_hurt", "war_wyvern": "wyvern_hurt",
	"wreck_gull": "wreck_gull_hurt", "storm_ray": "storm_ray_hurt", "bell_wraith": "bell_wraith_hurt",
	"drowned_sailor": "drowned_hurt", "barnacle_brute": "brute_hurt", "brine_hound": "hound_snarl", "lantern_jelly": "jelly_hum", "angler": "angler_bite",
	"siren": "siren_shriek", "press_gang": "drowned_hurt", "tide_witch": "drowned_hurt", "harbourmaster": "harbour_growl", "lighthouse_keeper": "keeper_hurt",
	"kraken_arm": "kraken_hurt", "hollow_sovereign": "sovereign_hurt", "leviathan": "leviathan_hurt", "kraken": "kraken_hurt"}
const MESENLLA_DEATHS := {"wyvern_rider": "woods_death", "bear": "bear_death", "mist_bear": "bear_death", "eagle": "eagle_death", "mist_eagle": "eagle_death",
	"shapeshifter": "shapeshifter_death", "child_of_woods": "woods_death", "woodland_cavalry": "woods_death", "earth_elemental": "stone_crumble",
	"great_revenant_elemental": "revenant_death", "mist_elemental": "mist_dissipate", "storm_elemental": "storm_burst", "wyvern": "wyvern_death",
	"war_wyvern": "wyvern_death",
	"wreck_gull": "wreck_gull_death", "storm_ray": "storm_ray_death", "bell_wraith": "bell_wraith_death",
	"drowned_sailor": "drowned_death", "barnacle_brute": "brute_death", "brine_hound": "hound_death", "lantern_jelly": "jelly_burst", "angler": "angler_death",
	"siren": "siren_death", "press_gang": "drowned_death", "tide_witch": "witch_death", "harbourmaster": "brute_death", "lighthouse_keeper": "keeper_hurt",
	"kraken_arm": "kraken_death", "hollow_sovereign": "sovereign_death", "leviathan": "leviathan_death", "kraken": "kraken_end"}


## The Shapeshifter speaks with whichever body it has: the stag's call, or the beast's growl.
func _in_beast_form() -> bool:
	return _current_anim in ["m_beast", "m_swipe"] or (mesenlla_mind != null and mesenlla_mind.form == "beast")


func _voice() -> String:
	if type_id == "shapeshifter":
		return "beast_growl" if _in_beast_form() else "stag_call"
	return MESENLLA_VOICES.get(type_id, "")


func _hurt_sound() -> String:
	if type_id in MistModels.BORN:
		return "wraith"
	if type_id == "shapeshifter":
		return "bear_hurt" if _in_beast_form() else "stag_hurt"
	return MESENLLA_HURT.get(type_id, "zombie_hurt")


## A plain blow: a bear's or the beast's claws rake the air; everything else snarls.
func _attack_sound() -> String:
	if type_id in ["bear", "mist_bear"] or (type_id == "shapeshifter" and _in_beast_form()):
		return "claw_swipe"
	return "attack"


func _death_sound() -> String:
	if type_id in MistModels.BORN:
		return "mist_burst"
	if MESENLLA_DEATHS.has(type_id):
		return MESENLLA_DEATHS[type_id]
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
	if model_id == "angler":
		# Out of the sand in a spray of it (VaelModels.animate_angler plays the rise).
		world.sfx_at("angler_rise", position, 0.0)
		world.fx_gore(position + Vector3.UP * 0.3, Color(0.55, 0.5, 0.4))
	if _lure:
		_lure.visible = false
		_beam.visible = false
		_visual.visible = true
		world.sfx_at("mimic", position, 0.0)
	if _statue:
		world.sfx_at("gargoyle", position, -2.0)


## Caught off guard: whatever blow it was winding up comes to nothing, and it cannot start another for
## a moment. It still moves and sees. (A Thief appearing in front of it with a blade, for one.)
func flinch(seconds: float) -> void:
	if control_immune(): return
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.FLINCH, seconds)
		return
	if mesenlla_mind:
		mesenlla_mind.interrupt(self)
	_attack_left = 0.0
	_attack_hit_pending = false
	_attack_cd = maxf(_attack_cd, seconds)


func stun(seconds: float) -> void:
	if control_immune(): return
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.STUN, seconds)
		return
	if is_boss():
		seconds = minf(seconds * 0.35, 0.6)
	elif is_miniboss():
		seconds *= 0.5
	if dormant:
		_wake()
	if mesenlla_mind:
		mesenlla_mind.interrupt(self)
	_stun = maxf(_stun, seconds)
	_show_stun(true)
	_attack_left = 0.0
	_attack_hit_pending = false
	_special_left = 0.0 # a stun cuts a Banshee's scream or a Fallen Knight's charge short
	_hold = false
	_tick_every = 1
	_current_anim = ""
	_play("Hit_A", 0.8, 0.05)


## Mist Burst: frozen solid, and a hit does not thaw it.
func freeze(seconds: float) -> void:
	if control_immune(): return
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.FREEZE, seconds)
		return
	stun(seconds)
	_show_frozen(_stun if is_boss() else seconds)


func _show_frozen(seconds: float) -> void:
	var was := _frozen > 0.0
	_frozen = seconds
	if (seconds > 0.0) != was:
		_restore_materials()


func slow(seconds: float) -> void:
	if control_immune(): return
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


## Whether a creature of this kind lets go of its weapon as it falls ("weapon_drop"; most always do).
static func lets_go(of: Dictionary) -> bool:
	return randf() < float(of.get("weapon_drop", 1.0))


## What a creature leaves as it falls: "weapon", "arrows", "food", or "" for nothing. A kind with a
## "loot" table (the Children of the Woods) leaves something only "loot_chance" of the time, then any
## entry of the table as likely as the others.
static func loot(of: Dictionary) -> String:
	if of.has("loot"):
		if randf() >= float(of.get("loot_chance", 1.0)):
			return ""
		return str((of["loot"] as Array).pick_random())
	return "weapon" if lets_go(of) else ""


func _die() -> void:
	if mesenlla_mind:
		mesenlla_mind.on_death(self)
	_show_death()
	if weapon_id != "":
		match loot(def):
			"weapon": world.drop_weapon(position + Vector3(0, 0, 0.5), weapon_id)
			"arrows": world.spawn_pickup_at(position + Vector3(0, 0, 0.5), Pickup.Kind.ARROWS, "arrows")
			"food": world.spawn_pickup_at(position + Vector3(0, 0, 0.5), Pickup.Kind.FOOD, PowerDefs.pick_weighted(PowerDefs.FOODS))
		weapon_id = ""
		if _hand_mesh:
			_hand_mesh.equip("")
	# Its riders go down with it, and whoever brought it down brought them down too.
	for rider: Zombie in world.zombies.duplicate():
		if rider.carrier == self and rider.is_alive():
			rider.carrier = null
			rider.next_hitter = last_hitter if last_hitter != 0 else -1
			rider.take_damage(rider.hp + 1.0, Vector3.ZERO, 0.0, rider.centre())
	# A boss leaves nothing behind but its last words.
	var last_words: String = ZombieDefs.ALL[type_id].get("last_words", "")
	if last_words != "":
		world.director.show_banner("%s: \u201c%s\u201d" % [ZombieDefs.ALL[type_id]["name"], last_words], 6.0)
	world.on_zombie_killed(self)


func blind(seconds: float) -> void:
	if control_immune(): return
	blind_left = maxf(blind_left, seconds)


## Robbed by a Thief: the weapon falls (or, with drop false, is taken). Returns what it held, or "".
## Class weapons and weapons that never lie about stay put.
## Knocks the weapon out of its hand: onto the ground, or (drop false) nowhere, for a Thief's Fence.
## On a phone that is not the host this one is only a copy, so the host is told to do it for real:
## the host drops the weapon and tells every phone the creature is unarmed.
func disarm(drop := true) -> String:
	if control_immune(): return ""
	if weapon_id == "" or not WeaponDefs.lies_around(weapon_id):
		return ""
	var held := weapon_id
	if puppet:
		Net.effect_zombie(self, Effect.DISARM, 1.0 if drop else 0.0)
	elif drop:
		world.drop_weapon(position + Vector3(0, 0, 0.6), held)
	weapon_id = ""
	if _hand_mesh:
		_hand_mesh.equip("")
	if Net.is_host():
		Net.zombie_weapon(self)
	return held


## The host says this body is dead.
func net_die() -> void:
	_show_death()
	weapon_id = ""
	if _hand_mesh:
		_hand_mesh.equip("")


func _show_death() -> void:
	if world and not is_boss():
		world.note_fall(position)
	carrier = null # a rider shot from the saddle falls
	if model_id == "veil_regent":
		(_visual.get_node("RegentHealth") as Label3D).visible = false
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
	if model_id in MistModels.KINDS:
		_dying = 1.6
		world.fx_mist(centre(), 2.0)
	elif type_id == "fallen_revenant":
		_dying = 1.6
		world.fx_mist(centre(), 2.0)
	elif model_id in MesenllaModels.KINDS or model_id == "crow":
		# (A Carrion Crow falls out of the air like any other bird.)
		_dying = MesenllaModels.death_time(model_id)
		_death_total = _dying
		MesenllaModels.begin_death(self, _visual)
	elif _anim == null:
		_visual.rotation.x = -PI * 0.5
		_visual.position.y = 0.2
		_dying = 0.9
	if puppet:
		Sfx.play_at(_death_sound(), position, world.player.global_position if world.player else position, -6.0)
	else:
		world.sfx_at(_death_sound(), position, -6.0)


## Caught by an Antler Charm's vines (PowerDefs.ANTLER_ROOT), or pinned by a harpoon (pinned: no
## wait between one and the next).
func root(seconds: float, pinned := false) -> void:
	if control_immune(): return
	if not is_alive() or flies or carrier:
		return
	if puppet:
		Net.effect_zombie(self, Effect.PIN if pinned else Effect.ROOT, seconds)
		return
	if world.now < _root_again and not pinned:
		return
	if is_boss():
		seconds *= 0.5
	root_left = maxf(root_left, seconds)
	if not pinned:
		_root_again = world.now + PowerDefs.ANTLER_AGAIN
	velocity = Vector3.ZERO
	# A charge or a lunge ends where the vines catch it.
	if mesenlla_mind and mesenlla_mind.phase in ["charge", "leap"]:
		mesenlla_mind.interrupt(self)
	if pinned:
		return # held by the harpoon in it: no vines
	show_roots(seconds)
	if Net.is_host():
		Net.zombie_rooted(self, seconds)


## Vines wound round its legs, growing out of the ground, while it is held.
func show_roots(seconds: float) -> void:
	if seconds <= 0.0:
		if _vines:
			_vines.visible = false
		return
	if _vine_mesh == null:
		var l := LowPoly.new()
		var vine := Color(0.28, 0.45, 0.18)
		for i in 7:
			var a := TAU * i / 7.0
			var r := 0.42
			var pts: Array[Vector3] = []
			for k in 5:
				var b := a + k * 0.7
				pts.append(Vector3(cos(b) * r * (1.0 - k * 0.12), k * 0.22, sin(b) * r * (1.0 - k * 0.12)))
			for k in 4:
				l.prism(pts[k], pts[k + 1], 0.045 - k * 0.008, 0.04 - k * 0.008, 4, vine.lightened(0.05 * (i % 2)))
			l.box(pts[2] + Vector3(0.03, 0.02, 0), Vector3(0.12, 0.02, 0.07), Color(0.36, 0.62, 0.24), Vector3(0, a * 57.0, 25))
		_vine_mesh = l.commit()
	if _vines == null:
		_vines = MeshInstance3D.new()
		_vines.mesh = _vine_mesh
		_vines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_vines)
	var girth := maxf(1.0, _capsule.radius / 0.36)
	_vines.scale = Vector3(girth, maxf(0.8, height / 1.8), girth)
	_vines.visible = true
	root_left = maxf(root_left, seconds) if puppet else root_left


## A Mist Wolf's howl: it moves faster for a while.
func hasten(seconds: float) -> void:
	haste_left = maxf(haste_left, seconds)


## Fire, Ice or Storm (a wyvern): how it looks, and what it breathes.
func set_element(e: String) -> void:
	element = e
	if _visual.has_meta("rig"):
		(_visual.get_meta("rig") as WyvernRig).set_element(e)


## Sat in a War Wyvern's saddle, at this seat. It goes where the wyvern goes.
func mount_on(wyvern: Zombie, which: int) -> void:
	carrier = wyvern
	seat = which
	dormant = false
	collision_mask = 0
	_shadow.visible = false
	_loose_was = MesenllaModels.rider_cycle(seat, world.now)
	_current_anim = ""
	_play("RideShoot", 1.0, 0.0)
	_sit()


## The wyvern's seat, in the world.
func _sit() -> void:
	var rig := carrier._visual.get_meta("rig", null) as WyvernRig
	var spot := rig.body.get_node_or_null("Seat%d" % seat) as Node3D if rig else null
	global_position = spot.global_position if spot else carrier.global_position + Vector3.UP
	_net_pos = global_position


## A rider in the saddle: carried, turning towards whoever is nearest, drawing and loosing in time with
## the world's clock (MesenllaModels.rider_cycle), so every phone shows the same. Its arrows are the
## host's. It can be struck, burnt, poisoned, stunned and frozen like any other; while stunned or
## frozen it does not shoot.
const RIDER_RANGE := 34.0
const RIDER_DAMAGE := 0.35 # of its wyvern's blow


func _tick_carried(delta: float) -> void:
	if not is_instance_valid(carrier) or not carrier.active or not carrier.is_alive():
		carrier = null
		return
	_sit()
	reveal_left -= delta
	bar_time -= delta
	_tick_flash(delta)
	var aim := Vector3.INF
	var p := world.nearest_player(position)
	if p:
		aim = p.global_position
	var yaw := carrier.rotation.y
	if aim != Vector3.INF:
		var look := aim - position
		yaw += clampf(wrapf(atan2(look.x, look.z) - carrier.rotation.y, -PI, PI), -1.3, 1.3)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 8.0))
	var cycle := MesenllaModels.rider_cycle(seat, world.now)
	if _anim and _frozen <= 0.0:
		if _anim.current_animation != "RideShoot":
			_anim.play("RideShoot")
		_anim.seek(cycle, true)
		_anim_accum = 0.0
	var loosed := _loose_was < BodyAnim.RIDE_LOOSE and cycle >= BodyAnim.RIDE_LOOSE
	_loose_was = cycle
	if puppet:
		return
	if _frozen > 0.0:
		_frozen -= delta
		if _frozen <= 0.0:
			_show_frozen(0.0)
	if _stun > 0.0:
		_stun -= delta
		if _stun <= 0.0:
			_show_stun(false)
	_tick_burn(delta)
	_tick_dot(delta)
	if not is_alive() or not loosed or _stun > 0.0 or _frozen > 0.0 or p == null or p.dead:
		return
	var from := position + Vector3.UP * height * 0.75
	var at := p.eye_position() - Vector3.UP * 0.3
	if from.distance_to(at) > RIDER_RANGE or not world.has_line_of_sight(from, at):
		return
	world.spawn_enemy_arrow(from, at + p.velocity * from.distance_to(at) / 26.0, carrier._damage * RIDER_DAMAGE, RIDER_RANGE, false, def["name"])


func release() -> void:
	if not active:
		return
	soaked_left = 0.0
	if _drips:
		_drips.emitting = false
		_puddle.visible = false
	_set_enabled(false)
	world.recycle_zombie(self)
	if Net.is_host():
		world.net_zombie_released(self)


# --- On a joined phone -------------------------------------------------------

## Soaked by a Stormcaller's Trident: seawater runs off it, and its Stormspear's lightning leaps to it.
func soak(seconds: float) -> void:
	if not is_alive():
		return
	soaked_left = maxf(soaked_left, seconds)
	if _drips == null:
		_drips = CPUParticles3D.new()
		_drips.amount = 22
		_drips.lifetime = 0.6
		_drips.local_coords = false
		_drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_drips.emission_box_extents = Vector3(body_radius() * 0.8, HEIGHT * _scale * 0.35, body_radius() * 0.8)
		_drips.direction = Vector3.DOWN
		_drips.spread = 12.0
		_drips.gravity = Vector3(0, -9.0, 0)
		_drips.initial_velocity_min = 0.4
		_drips.initial_velocity_max = 1.2
		_drips.scale_amount_min = 0.6
		_drips.scale_amount_max = 1.0
		var drop := SphereMesh.new()
		drop.radius = 0.045
		drop.height = 0.13
		drop.radial_segments = 4
		drop.rings = 2
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.6, 0.92, 1.0)
		drop.material = m
		_drips.mesh = drop
		_drips.position = Vector3.UP * HEIGHT * _scale * 0.55
		_drips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_drips)
		# The seawater running off it pools round its feet, glinting.
		if _puddle_mesh == null:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.7
			ring.outer_radius = 1.0
			ring.rings = 18
			ring.ring_segments = 4
			var glint := StandardMaterial3D.new()
			glint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glint.albedo_color = Color(0.5, 0.85, 1.0, 0.45)
			ring.material = glint
			_puddle_mesh = ring
		_puddle = MeshInstance3D.new()
		_puddle.mesh = _puddle_mesh
		_puddle.position.y = 0.06
		_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_puddle)
	_drips.emitting = true
	_puddle.visible = true


## True while this flyer is about to come down on someone.
func is_warning() -> bool:
	return net_warning if puppet else (_windup > 0.0 or _dive > 0.0 or mesenlla_warning)


func anim_speed() -> float:
	return _anim.speed_scale if _anim else 1.0


func net_apply(at: Vector3, rot: float, flags: int, hp_fraction: float, anim_name: String, speed: float) -> void:
	if _dying > 0.0:
		return
	if carrier:
		# In the saddle: where it is and what it does are the wyvern's and its bow's.
		hp = maxf(1.0, hp_fraction * max_hp)
		_show_stun(flags & 16 != 0)
		_show_frozen(0.25 if flags & 32 != 0 else 0.0)
		return
	if position.distance_to(at) > 12.0:
		position = at
	_net_pos = at
	_net_rot = rot
	state = flags & 3
	hp = maxf(1.0, hp_fraction * max_hp)
	_show_stun(flags & 16 != 0)
	net_warning = flags & 64 != 0
	if def.get("rider", false) and (flags & 128 != 0) != _mounted:
		_show_mount(flags & 128 != 0, true)
	_show_frozen(0.25 if flags & 32 != 0 else 0.0)
	var burning := flags & 8 != 0
	if burning and burn_time <= 0.0:
		_show_burning(60.0)
	elif not burning and burn_time > 0.0:
		burn_time = 0.0
		_stop_flames()
	if model_id in MesenllaModels.KINDS:
		_current_anim = anim_name
	elif anim_name != "":
		_play(anim_name, speed, 0.12)
	if position.distance_squared_to(at) > 49.0:
		position = at


func net_weapon(id: String) -> void:
	weapon_id = id
	if id == "" or not WeaponDefs.ALL.has(id):
		# Disarmed on the host: empty the hand here too.
		if _hand_mesh:
			_hand_mesh.equip("")
		return
	_show_weapon(id)


func _puppet_tick(delta: float) -> void:
	_update_ground_shadow()
	var was := position
	position = position.lerp(_net_pos, minf(1.0, delta * 10.0))
	rotation.y = lerp_angle(rotation.y, _net_rot, minf(1.0, delta * 10.0))
	reveal_left -= delta
	bar_time -= delta
	_tick_flash(delta)
	if root_left > 0.0:
		root_left -= delta
		if root_left <= 0.0:
			show_roots(0.0)
	if _mounted:
		_tick_mount(delta, was.distance_to(position) / maxf(delta, 0.001))
	_tick_mount_fall(delta)
	if _custom and not dormant:
		# The host's creatures move here by snapshots: their pace is how far they came this frame.
		var pace := was.distance_to(position) / maxf(delta, 0.001) if model_id in MesenllaModels.KINDS else was.distance_squared_to(position)
		_animate_custom(delta, pace)
	elif _lure and dormant:
		_lure.rotation.y += delta * 1.6
	elif dormant and model_id == "angler":
		VaelModels.lure_idle(_visual, world.now + float(net_id) * 0.37) # its lure, swaying over the sand
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		var p := world.player
		var d := position.distance_to(p.global_position) if p else 0.0
		if _eyes:
			_eyes.visible = d < FAR
		_shadow.visible = _shadow.visible and d < FAR


# --- Senses ------------------------------------------------------------------

func forget() -> void:
	if control_immune(): return
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
	if control_immune(): return
	if puppet:
		Net.effect_zombie(self, Effect.TAUNT, at.x, at.z)
	elif not dormant:
		_start_chase(at)


## Dragged to a point, as if on a rope.
func pull_to(at: Vector3) -> void:
	if control_immune(): return
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.PULL, at.x, at.z)
		return
	_pull_at = at
	_pull_left = 0.7


## Drawn by an Adept's Event Horizon: carried slowly toward a point for a moment, while it still walks and
## fights as it would (unlike a pull, which takes it off its feet).
func drift_to(at: Vector3, speed: float) -> void:
	if not is_alive() or not draggable():
		return
	if puppet:
		Net.effect_zombie(self, Effect.DRIFT, at.x, at.z)
		return
	var to := Vector3(at.x - position.x, 0, at.z - position.z)
	_drift = to.normalized() * speed if to.length() > 0.1 else Vector3.ZERO
	_drift_left = 0.35
var _drift := Vector3.ZERO
var _drift_left := 0.0


## Blinded: it sees only a few metres for a while (on every phone, by way of the host).
func blind_for(seconds: float) -> void:
	if control_immune(): return
	if not is_alive():
		return
	if puppet:
		Net.effect_zombie(self, Effect.BLIND, seconds, 0.0)
		return
	blind(seconds)


## Hauled in on a Harpooner's rope: dragged all the way to a point, however far (pull_to stops after
## a few metres), at the pace a rope hauls.
func haul_to(at: Vector3) -> void:
	if not is_alive() or not draggable():
		return
	if puppet:
		Net.effect_zombie(self, Effect.HAUL, at.x, at.z)
		return
	_pull_at = at
	_pull_left = clampf(Vector2(at.x - position.x, at.z - position.z).length() / HarpoonerKit.HAUL_SPEED + 0.1, 0.2, 2.2)


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
	# Coming at someone from the side must not mean stopping on the wrong side of their fence.
	if not world.grid.line_is_open(at, spot) or (world.vael_sites and not world.vael_sites.accessible(spot)):
		spot = at
	var slack := maxf(2.0, position.distance_to(at) * 0.2)
	if not _has_goal or _goal.distance_squared_to(spot) > slack * slack:
		_set_goal(spot)


func _can_see(target: Target, to: Vector3, dist: float) -> bool:
	var sight := _sight
	if blind_left > 0.0:
		sight = minf(sight, NightfallDome.BLIND_SIGHT)
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
		if world.vael_sites:
			if world.vael_sites.accessible(p):
				return p
		elif absf(p.x) < world.half_size - 1.0 and absf(p.z) < world.half_size - 1.0 and world.grid.is_free(world.grid.to_cell(p)):
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
	_shadow.visible = _shadow.visible and dist < FAR
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
	_marching = false
	_on_duty = world.fort != null and not flies and _fort_plan(target, dist)
	if _on_duty:
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
			if type_id == "clever" and weapon_id == "":
				_roam(dt)
			elif _arrived():
				state = State.SEARCH
				_search_left = 8.0
				_clear_goal()
		State.SEARCH:
			if type_id == "clever" and weapon_id == "": _roam(dt)
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
	# Straight at you, unless a fence or a cart is in the way: seeing you is not the same as reaching you.
	_direct = _sees and dist < 8.0 and state == State.CHASE and not _hold and world.now >= _walk_around_until \
			and (phases or world.grid.line_is_open(position, target.global_position))
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


## In the fort: a zombie goes for the players only if it can actually get to them. Otherwise it
## goes for its own gate (handed out evenly when it rose), and once that gate is open, through it to
## the heart. A breach elsewhere draws only a few, so every gate keeps being pressed.
func _fort_plan(target: Target, dist: float) -> bool:
	var fort := world.fort
	var me_inside := fort.inside(position)
	var they_inside := fort.inside(target.global_position)
	var they_reachable := not fort.on_wall(target.global_position) and (me_inside == they_inside or fort.any_open())
	if fort.has_lanes():
		return _lane_plan(target, dist, me_inside, they_inside)
	if _sees and they_reachable and dist < _sight:
		return false
	if state == State.CHASE and they_reachable and (target.global_position - position).length() < 14.0:
		return false
	state = State.INVESTIGATE
	_direct = false
	_hold = false
	var g := fort.gate_for(self)
	if me_inside or phases or not g["closed"]:
		var heart := fort.heart_at + (position - fort.heart_at).normalized() * 2.2
		_fort_goal(heart)
		if Vector2(position.x - fort.heart_at.x, position.z - fort.heart_at.z).length() < 3.8:
			_hold = true
			_fort_strike(-1, fort.heart_at)
		return true
	var front := fort.gate_front(g, position)
	_fort_goal(front)
	if Vector2(position.x - front.x, position.z - front.z).length() < 1.6:
		_hold = true
		_fort_strike(g["i"], g["at"])
	return true


## Up a stronghold's lane (Mist Bastion). A zombie keeps to the road of the lane it rose on, all the
## way to that lane's gate and no other: it fights whoever it finds on its lane like anywhere else,
## breaks its gate, and once the gate is down goes through it for the portal, fighting whoever stands
## inside. A gate fallen on another lane changes nothing for it.
func _lane_plan(target: Target, dist: float, me_inside: bool, they_inside: bool) -> bool:
	var fort := world.fort
	var g := fort.gate_for(self)
	var gate: int = g["i"]
	var afoot := not fort.on_wall(target.global_position)
	# Who it can get at without leaving its lane: inside, anyone inside; outside, anyone on its lane.
	var mine := afoot and they_inside if me_inside else afoot and not they_inside and fort.off_lane(gate, target.global_position) < LANE_REACH
	if mine and dist < LANE_ENGAGE and (_sees or state == State.CHASE):
		return false # the ordinary fight
	state = State.INVESTIGATE
	_direct = false
	_hold = false
	if me_inside or phases:
		var heart := fort.heart_at + (position - fort.heart_at).normalized() * 2.2
		_fort_goal(heart)
		_marching = Vector2(position.x - heart.x, position.z - heart.z).length() > MARCH_UNTIL
		if Vector2(position.x - fort.heart_at.x, position.z - fort.heart_at.z).length() < 3.8:
			_hold = true
			_fort_strike(-1, fort.heart_at)
		return true
	var front := fort.gate_front(g, position)
	var to_front := Vector2(position.x - front.x, position.z - front.z).length()
	if to_front > LANE_AHEAD:
		# Still on the way: the next stretch of the road, never straight for the gate over the slopes.
		_fort_goal(fort.lane_ahead(gate, position, LANE_AHEAD))
		_marching = true
		return true
	if not g["closed"]:
		# Its gate is down: straight through the gateway. Once inside, the portal.
		_fort_goal((g["at"] as Vector3) - (g["dir"] as Vector3) * (Fort.WALL_T * 0.5 + 1.6))
		_marching = false
		return true
	_fort_goal(front)
	_marching = to_front > MARCH_UNTIL
	if to_front < 1.6:
		_hold = true
		_fort_strike(gate, g["at"])
	return true


func _fort_goal(at: Vector3) -> void:
	if not _has_goal or _goal.distance_squared_to(at) > 4.0:
		_set_goal(at)


func _fort_strike(gate: int, at: Vector3) -> void:
	var to := at - position
	_duty_face = at
	if to.length_squared() > 0.01:
		rotation.y = atan2(to.x, to.z)
	if _attack_cd > 0.0 or _attack_left > 0.0:
		return
	_attack_aim = at
	_attack_cd = _attack_interval()
	_attack_left = ATTACK_TIME
	_current_anim = ""
	_play(BodyAnim.mob_attack(weapon_id, def.get("claws", false)), 1.2, 0.1)
	var dmg := maxf(_melee_damage(), 8.0)
	if gate >= 0:
		world.fort.hit_gate(world.fort.gates[gate], dmg * Fort.WOOD_TOUGHNESS, position)
	else:
		world.fort.hit_heart(dmg * Fort.HEART_TOUGHNESS)


func _roam(dt: float) -> void:
	if type_id == "clever" and weapon_id == "":
		var p := world.nearest_weapon_pickup(position, world.half_size * 2.0)
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
				var next := world.vael_sites.patrol(position) if world.vael_sites else position
				_set_goal(next if next != position else _random_spot(18.0))


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
	if type_id in MistModels.BORN:
		return "wraith"
	if _voice() != "":
		return _voice()
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
		if model_id in MistModels.KINDS:
			var t := clampf(1.0 - _dying / 1.6, 0.0, 1.0)
			for i in _parts.size():
				var rest: Transform3D = _parts[i].get_meta("mist_rest", Transform3D.IDENTITY)
				_parts[i].transform = rest
				_parts[i].position += Vector3(sin(i * 2.4), 1.0, cos(i * 2.4)) * t
				_parts[i].scale *= maxf(0.01, 1.0 - t)
		var floor_y := world.ground_at(position)
		if position.y > floor_y:
			position.y = maxf(floor_y, position.y - 14.0 * delta) # flyers and leapers fall out of the air
		if model_id in MesenllaModels.KINDS or model_id == "crow":
			MesenllaModels.animate_death(self, _visual, _death_total - _dying, delta)
		elif _mounted and _horse_node:
			# A rider and its mount go down together: the horse or bear rolls onto its side, the
			# rider falls from the saddle to the ground beside it.
			var k := clampf((2.2 - _dying) / 0.6, 0.0, 1.0)
			var over := k * k * (3.0 - 2.0 * k)
			_horse_node.rotation.z = 1.45 * over
			_horse_node.position.y = 0.45 * over * _scale
			var bear := not (_horse_node is MeshInstance3D)
			_visual.rotation = Vector3.ZERO
			_visual.position.y = (_seat_y if bear else HorseModel.SADDLE * _scale) * (1.0 - over)
			_visual.position.x = -0.7 * over * _scale
			if not bear:
				HorseModel.set_gait(_horse_node as MeshInstance3D, 0.0)
		if _dying <= 0.0:
			release()
		return
	if carrier:
		_tick_carried(delta)
		return
	if puppet:
		_puppet_tick(delta)
		return
	_tick_mount_fall(delta)
	if _frozen > 0.0:
		_frozen -= delta
		if _frozen <= 0.0:
			_show_frozen(0.0)
	if _pull_left > 0.0:
		_pull_left -= delta
		_tick_flash(delta) # a blow's flash fades as usual while it is dragged
		_drift_left = 0.0
		var to_pull := Vector3(_pull_at.x - position.x, 0.0, _pull_at.z - position.z)
		if to_pull.length() > 1.0:
			position += to_pull.normalized() * minf(16.0 * delta, to_pull.length())
			if not flies:
				position.y = world.ground_at(position)
		return
	if _is_dummy:
		_tick_dummy(delta)
		return
	_update_ground_shadow()
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
	haste_left = maxf(0.0, haste_left - delta)
	if root_left > 0.0:
		root_left -= delta
		if root_left <= 0.0:
			show_roots(0.0)
	revealed_left = maxf(0.0, revealed_left - delta)
	blind_left = maxf(0.0, blind_left - delta)
	_tick_flash(delta)
	if _drift_left > 0.0:
		_drift_left -= delta
		position += _drift * delta
		if not flies:
			position.y = world.ground_at(position)
	if _airborne:
		# A leap always finishes, even if something stuns it in mid-air.
		if _vault_from != Vector3.INF:
			_tick_vael_vault(delta)
		else:
			_tick_leap(target, delta)
		return
	if _stun > 0.0:
		_stun -= delta
		if _stun <= 0.0:
			_show_stun(false)
		velocity = _knock
		_knock = _knock.lerp(Vector3.ZERO, min(1.0, delta * 8.0))
		if _perch_i >= 0:
			pass # there is nowhere to stagger to on a stone
		elif not flies and not phases:
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

	var storm := world.storm_at(position)
	if storm and not def.get("mist_boss", false) and not mist_mind:
		var exit := storm.escape(position)
		if exit != Vector3.INF:
			if not _has_goal or _goal.distance_squared_to(exit) > 1.0: _set_goal(exit)
			state = State.INVESTIGATE
			_move(target, exit - position, position.distance_to(exit), delta)
			return
	if mist_mind:
		mist_mind.tick(self, target, delta)
		return
	if mesenlla_mind and mesenlla_mind.tick(self, target, to, dist, delta):
		if _custom:
			_animate_custom(delta, velocity.length())
		return
	if flies:
		_fly(target, to, dist, delta)
		if mesenlla_mind:
			mesenlla_mind.after(self)
		return
	if _is_scarecrow and _watched:
		_animate_custom(delta, 0.0)
		return
	if _screams and _special_left > 0.0:
		_tick_scream(target, delta)
		return
	if _mounted:
		_tick_rider(target, to, dist, delta)
		_tick_mount(delta, velocity.length())
		return
	if _can_hop:
		_hop_cd -= delta
		if _perch_i >= 0:
			_tick_perch(target, to, dist, delta)
			return
		if _hop_cd <= 0.0:
			_hop_cd = HOP_THINK
			_think_hop(target, dist)
			if _airborne:
				return
	elif world.vael_sites and state == State.CHASE and dist < 18.0:
		_hop_cd -= delta
		if _hop_cd <= 0.0:
			_hop_cd = 0.55
			if _try_vael_vault(to, dist):
				return
	_tick_hero(target, dist, delta)
	_try_leap(target, dist)
	if not _airborne:
		_move(target, to, dist, delta)
		_combat(target, dist, delta)
		_stuck_check(delta)
		if mesenlla_mind:
			mesenlla_mind.after(self)
		if _custom:
			_animate_custom(delta, velocity.length())


func _idle_sound() -> String:
	if type_id in MistModels.BORN:
		return "wraith"
	if _voice() != "":
		return _voice()
	match type_id:
		"crow": return "crow"
		"wraith": return "wraith"
	return "groan"


func _tick_dot(delta: float) -> void:
	var had_poison := poison_left > 0.0
	var had_bleed := bleed_left > 0.0
	if not had_poison and not had_bleed:
		return
	# Integrate each channel over its remaining life; no extra half-second tick at expiry.
	var amount := _poison_dps * minf(delta, maxf(poison_left, 0.0)) + _bleed_dps * minf(delta, maxf(bleed_left, 0.0))
	_dot_pending += amount
	_dot_wait -= delta
	if _dot_pending > 0.0 and (_dot_wait <= 0.0 or maxf(poison_left, bleed_left) <= delta):
		next_hitter = last_hitter
		var previous_flinch := _hurt_stun
		dot_kind = "poison" if _poison_dps * float(poison_left > 0.0) >= _bleed_dps * float(bleed_left > 0.0) else "bleed"
		take_damage(_dot_pending, Vector3.ZERO, 0.0, centre())
		_hurt_stun = previous_flinch
		_dot_pending = 0.0
		_dot_wait = 0.25
	poison_left = maxf(0.0, poison_left - delta)
	bleed_left = maxf(0.0, bleed_left - delta)
	if had_poison != (poison_left > 0.0) or had_bleed != (bleed_left > 0.0):
		show_debuffs(poison_left > 0.0, bleed_left > 0.0)


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
	var aim := target.global_position + target.velocity * 0.35
	# Over the void this is not a leap but a long way down. Crossing a gap is _think_hop's job.
	if world.terrain.has_islands() and not world.terrain.is_walkable(aim.x, aim.z):
		return
	_special_cd = randf_range(3.0, 4.5)
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
	if _hop_left > 0.0:
		_tick_hop(target, delta)
		return
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


## Drowned walkers vault low obstacles in pursuit. A blocked arc leaves their route alone so they
## can take a nearby door or the path around a wall.
func _try_vael_vault(to: Vector3, dist: float) -> bool:
	if phases or is_boss() or dormant or _hold or _attack_left > 0.0 or root_left > 0.0 or dist < 1.6:
		return false
	# Once out of sight, follow the known target position rather than reacting through buildings.
	var heading := to if _sees else _last_seen - position
	var there := VaelVault.landing(self, world, heading)
	if there == Vector3.INF:
		return false
	_vault_from = global_position
	_hop_to = there
	_hop_left = VaelVault.TIME
	_airborne = true
	_tick_every = 1
	_shadow.visible = false
	var facing := there - global_position
	rotation.y = atan2(facing.x, facing.z)
	_current_anim = ""
	_play("Running_A", 1.55, 0.05)
	world.sfx_at("jump_a", position, -7.0)
	return true


func _tick_vael_vault(delta: float) -> void:
	_hop_left = maxf(0.0, _hop_left - delta)
	var progress := 1.0 - _hop_left / VaelVault.TIME
	var there := VaelVault.point(_vault_from, _hop_to, progress)
	var blocked := move_and_collide(there - global_position) != null
	blocked = blocked or global_position.distance_squared_to(there) > 0.04
	if not blocked and _hop_left > 0.0:
		return
	if blocked:
		# A collider changed during the jump: recover on the known safe takeoff side.
		global_position = _vault_from
		_walk_around_until = world.now + 2.0
		_direct = false
	else:
		world.sfx_at("land", position, -13.0)
	_vault_from = Vector3.INF
	_hop_left = 0.0
	_airborne = false
	_hop_cd = 1.1
	_shadow.visible = true
	_clear_path_only()


# --- Jumping about the Mists --------------------------------------------------

## Is whoever it is chasing on the stones, or across a gap? Then it comes the way they went.
func _think_hop(target: Target, dist: float) -> void:
	_hop_walk = Vector3.INF
	if state != State.CHASE or _attack_left > 0.0 or _hold or dist > HOP_LOOK or _stun > 0.0:
		return
	var at := target.global_position
	if at.y - world.ground_at(at) > 0.8:
		var on := world.stone_near(at)
		if on.x >= 0:
			var best := _best_stone(on.x, on.y)
			if best >= 0:
				_hop_onto(on.x, best)
			else:
				_head_for(_closest_stone(on.x))
			return
	var flat := Vector3(at.x - position.x, 0.0, at.z - position.z)
	if dist < 2.0:
		return
	var dir := flat / dist
	var gap_at := -1.0
	var d := 2.0
	var terrain := world.terrain
	while d < dist:
		var p := position + dir * d
		var walkable := terrain.is_walkable(p.x, p.z)
		if gap_at < 0.0:
			if not walkable:
				gap_at = d
		elif walkable:
			var across := d + 1.5
			if across - gap_at + 1.5 > _hop_reach:
				return
			var land := position + dir * across
			if not terrain.is_walkable(land.x, land.z) or not world.grid.is_free(world.grid.to_cell(land)):
				return
			land.y = world.ground_at(land)
			if land.y - position.y > _hop_up:
				return
			if gap_at - 1.5 > 2.0:
				_head_for(position + dir * (gap_at - 1.5))
			else:
				_start_hop(land)
			return
		d += 2.0


## Straight there on foot, when the grid has no way to get to a place that is about to be jumped from.
func _head_for(at: Vector3) -> void:
	if world.grid.line_is_open(position, at):
		_hop_walk = at


func _closest_stone(line: int) -> Vector3:
	var best := Vector3.INF
	var near := INF
	for top: Vector3 in world.stone_chains[line]:
		var d := Vector2(top.x - position.x, top.z - position.z).length()
		if d < near:
			near = d
			best = top
	return best


## The stone in reach that is closest along the line to the one wanted, if nobody is on it.
func _best_stone(line: int, want: int) -> int:
	var chain: Array = world.stone_chains[line]
	var best := -1
	var best_gap := 1 << 20
	for i in chain.size():
		var top: Vector3 = chain[i]
		if Vector2(top.x - position.x, top.z - position.z).length() > _hop_reach or top.y - position.y > _hop_up:
			continue
		var gap := absi(i - want)
		if gap < best_gap and not _stone_taken(line, i):
			best_gap = gap
			best = i
	return best


func _stone_taken(line: int, i: int) -> bool:
	for other in world.zombies:
		if other != self and ((other._perch_line == line and other._perch_i == i) or (other._hop_line == line and other._hop_i == i)):
			return true
	return false


func _hop_onto(line: int, i: int) -> void:
	_start_hop(world.stone_chains[line][i])
	_hop_line = line
	_hop_i = i


func _start_hop(land: Vector3) -> void:
	var flat := land - position
	flat.y = 0.0
	var flight := clampf(flat.length() / 8.0, 0.45, 1.4)
	_air_vel = flat / flight
	_air_vel.y = (land.y - position.y + 0.5 * HOP_GRAVITY * flight * flight) / flight
	_hop_to = land
	_hop_left = flight
	_hop_line = -1
	_hop_i = -1
	_perch_line = -1
	_perch_i = -1
	_perch_lost = 0.0
	_hop_walk = Vector3.INF
	_airborne = true
	_shadow.visible = false
	_tick_every = 1
	_clear_path_only()
	world.sfx_at("leaper", position, -6.0)
	_current_anim = ""
	_play("Running_A", 1.6, 0.05)


func _tick_hop(target: Target, delta: float) -> void:
	_hop_left -= delta
	_air_vel.y -= HOP_GRAVITY * delta
	position += _air_vel * delta
	if Vector2(_air_vel.x, _air_vel.z).length_squared() > 0.1:
		rotation.y = atan2(_air_vel.x, _air_vel.z)
	if _hop_left > 0.0:
		return
	position = _hop_to
	_airborne = false
	_perch_line = _hop_line
	_perch_i = _hop_i
	_hop_line = -1
	_hop_i = -1
	_hop_cd = 0.5
	_attack_cd = 0.3
	_shadow.visible = _perch_i < 0
	var d := position.distance_to(target.global_position)
	if d < 2.2 and absf(target.global_position.y - position.y) < 2.4:
		target.hurt(_melee_damage(), position, self)
		world.sfx_at("attack", position, -3.0)


## On a stone: fight whoever is in reach, follow them along the line, or come down after them.
func _tick_perch(target: Target, to: Vector3, dist: float, delta: float) -> void:
	velocity = Vector3.ZERO
	if dist > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 9.0))
	if _anim != null and _attack_left <= 0.0:
		_play("Idle")
	_combat(target, dist, delta)
	if _custom:
		_animate_custom(delta, 0.0)
	if _hop_cd > 0.0 or _attack_left > 0.0:
		return
	_hop_cd = HOP_THINK
	var at := target.global_position
	var on := world.stone_near(at) if at.y - world.ground_at(at) > 0.8 else Vector2i(-1, -1)
	if on.x == _perch_line and on.x >= 0:
		if dist > _melee_reach():
			var best := _best_stone(on.x, on.y)
			if best >= 0 and absi(best - on.y) < absi(_perch_i - on.y):
				_hop_onto(on.x, best)
		return
	var land := _land_towards(at)
	if land != Vector3.INF:
		_start_hop(land)
		return
	# Too far from anywhere to land: back down the line, the way it came.
	var chain: Array = world.stone_chains[_perch_line]
	for i in chain.size():
		var top: Vector3 = chain[i]
		if i < _perch_i and Vector2(top.x - position.x, top.z - position.z).length() <= _hop_reach and not _stone_taken(_perch_line, i):
			_hop_onto(_perch_line, i)
			return
	_perch_lost += HOP_THINK
	if _perch_lost > 8.0:
		release()


## Somewhere to come down: near the target if it can, otherwise any ground in reach.
func _land_towards(at: Vector3) -> Vector3:
	var flat := Vector3(at.x - position.x, 0.0, at.z - position.z)
	var turn := atan2(flat.x, flat.z)
	for a: float in [0.0, 0.8, -0.8, 1.6, -1.6, 2.4, -2.4, PI]:
		var dir := Vector3(sin(turn + a), 0.0, cos(turn + a))
		var r := minf(_hop_reach, flat.length()) if a == 0.0 else _hop_reach
		while r >= 2.0:
			var p := position + dir * r
			if world.terrain.is_walkable(p.x, p.z) and world.grid.is_free(world.grid.to_cell(p)):
				p.y = world.ground_at(p)
				if p.y - position.y <= _hop_up:
					return p
			r -= 2.0
	return Vector3.INF


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
		if target.global_position.distance_to(position) < 5.0:
			target.hurt(_melee_damage(), position, self)
	elif type_id == "hero_magician" and hero_minute >= 7 and _special_cd <= 0.0 and _sees:
		_special_cd = 22.0
		world.raise_for(self)


## Flyers circle high and dive at you when they have a clear line. Roofs protect you.
## After a dive they hang low for a moment, so even a sword gets its chance.
func _fly(target: Target, _to: Vector3, dist: float, delta: float) -> void:
	var high: float = def["fly_height"]
	_orbit += delta * 1.1
	var speed := _speed * (0.5 if _slow > 0.0 else 1.0) * (HASTE if haste_left > 0.0 else 1.0)
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
			if mesenlla_mind:
				mesenlla_mind.on_dive(self)
		if not _clear:
			_dive = 0.0
	else:
		var ground := target.global_position if (state == State.CHASE or dist < _sight) else _home
		if world.map_id == "bastion" and world.fort and (type_id == "eagle" or type_id == "mist_eagle") and not _sees:
			ground = world.fort.heart_at
		aim = ground + Vector3(cos(_orbit) * 6.0, high, sin(_orbit) * 6.0)
		if _clear and _special_cd <= 0.0 and dist < _sight and (_statue or world.take_dive_turn()):
			_windup = DIVE_WARNING
			world.sfx_at("crow" if type_id == "crow" else "eagle_cry" if type_id.ends_with("eagle") else "wyvern_roar" if type_id.ends_with("wyvern") else "gargoyle", position, 0.0)
	var dir := aim - position
	velocity = dir.normalized() * speed if dir.length() > 0.2 else Vector3.ZERO
	position += (velocity + _knock) * delta
	_knock = _knock.lerp(Vector3.ZERO, min(1.0, delta * 6.0))
	position.y = maxf(position.y, world.ground_at(position) + 0.6)
	position.x = clampf(position.x, -world.half_size + 1.0, world.half_size - 1.0)
	position.z = clampf(position.z, -world.half_size + 1.0, world.half_size - 1.0)
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), min(1.0, delta * 6.0))
	_animate_custom(delta, 1.0)


func _animate_custom(delta: float, moving: float) -> void:
	if model_id in MistModels.KINDS:
		MistModels.animate(_visual, world.now, hp / maxf(max_hp, 1.0))
		return
	if model_id == "fallen_revenant":
		# A body with bones, moved by MistMind: its claws while it strikes, else running or standing.
		if _attack_left > 0.0:
			_attack_left -= delta
			return
		_play("Running_A" if moving > 0.5 else "Idle", maxf(0.7, moving / 3.5) if moving > 0.5 else 1.0)
		return
	if model_id in MesenllaModels.KINDS:
		MesenllaModels.animate(self, _visual, delta, moving)
		return
	_phase += delta * (9.0 if moving > 0.0 else 0.0)
	match model_id:
		"crow":
			(_visual.get_meta("bird") as BirdRig).drive(self, delta)
		"gargoyle", "harrier":
			var rate := 0.6 if model_id == "harrier" else 1.0
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
	if _hold or _attack_left > 0.0 or _hurt_stun > 0.0 or root_left > 0.0:
		return 0.0
	var mult := 0.5 if _slow > 0.0 else 1.0
	if not flies and world.terrain.in_water(position.x, position.z):
		mult *= Player.WADE_SPEED
	if bleed_left > 0.0:
		mult *= Player.BLEED_SPEED
	if _charges and _special_left > 0.0:
		mult *= 2.6
	if haste_left > 0.0:
		mult *= HASTE
	if world.tide:
		mult *= world.tide.quickens(self) # the Drowned, at high tide
	if _marching:
		return _speed * mult
	match state:
		State.CHASE: return _speed * mult
		State.SEARCH, State.INVESTIGATE: return _roam_speed * 1.5 * mult
	return _roam_speed * mult


func _move(_target: Target, to: Vector3, dist: float, delta: float) -> void:
	if world.portals and not flies:
		_gate_wait -= delta
		if _gate_wait <= 0.0:
			var out := world.portals.exit_from(position)
			if out != Vector3.INF:
				position = out
				if not world.mist_storms.is_empty() and world.storm_at(out) == null:
					_clear_goal()
					state = State.ROAM
				_gate_wait = 2.0
				_needs_path = true
				_path = PackedVector3Array()
	var dir := Vector3.ZERO
	var speed := _desired_speed()
	if speed > 0.0 and _hop_walk != Vector3.INF:
		dir = _hop_walk - position
		dir.y = 0.0
		if dir.length() < 0.4:
			dir = Vector3.ZERO
		else:
			dir = dir.normalized()
			var ahead := position + dir * 0.8
			if not world.terrain.is_walkable(ahead.x, ahead.z):
				dir = Vector3.ZERO
		_clear_path_only()
	elif speed > 0.0:
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
				# Spreading out to surround you is for open ground. On a bridge there is only the one way.
				var spread := 0.0 if world.terrain.has_islands() and world.terrain.near_deck(position.x, position.z) else 1.0
				var approach := to + _flank * clampf(dist - 2.5, 0.0, 4.0) * spread
				if world.vael_sites and not world.grid.line_is_open(position, position + approach):
					approach = to # take the doorway or the ramp straight on
				dir = approach.normalized()
				_check_blocked(delta)
			_clear_path_only()
		elif _has_goal:
			if _needs_path and world.take_path_budget():
				var aim := world.portals.waypoint(position, _goal) if world.portals else _goal
				_path = world.grid.path(position, aim) if _full_path else world.grid.route(position, aim)
				_full_path = false
				_path_i = 0
				_needs_path = false
			while _path_i < _path.size() and Vector2(_path[_path_i].x - position.x, _path[_path_i].z - position.z).length() < 0.65:
				_path_i += 1
			# A long journey is planned one stretch at a time, the next one asked for a few steps before
			# this one runs out, so the walker never stands waiting for it.
			var leg_ending := _path.size() > 0 and _path_i < _path.size() \
					and Vector2(_path[-1].x - position.x, _path[-1].z - position.z).length() < 3.0 \
					and Vector2(_path[-1].x - _goal.x, _path[-1].z - _goal.z).length() > 1.3
			if (_path_i >= _path.size() or leg_ending) and not _arrived() and not _needs_path and world.now >= _next_plan:
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
	var floor_y := world.ground_at(position)
	position.y = floor_y + (0.25 if phases else 0.0)
	_face(to, dist, dir, delta)
	if _anim != null and _attack_left <= 0.0:
		if velocity.length_squared() < 0.04:
			_play("Idle")
		elif state == State.CHASE or _marching:
			_play("Running_A", maxf(0.55, _speed / 5.0))
		else:
			_play("Walking_C" if type_id == "normal" else "Walking_A", maxf(0.5, velocity.length() / 1.8))


func _clear_path_only() -> void:
	_needs_path = true
	_path = PackedVector3Array()
	_path_i = 0


## Which way it looks. A blow under way: at what it is aimed at. In a fort, about the gate or the
## portal: where it walks, or at the gate or portal it is striking, never at someone who is only in
## sight off its lane. Otherwise: at whoever it sees or hunts close by, or where it walks.
func _face(to: Vector3, dist: float, dir: Vector3, delta: float) -> void:
	var look := Vector3.ZERO
	var rate := 9.0
	if _attack_left > 0.0:
		look = _attack_aim - position if _attack_aim != Vector3.INF and _on_duty else to
	elif _on_duty:
		if _hold and _duty_face != Vector3.INF:
			look = _duty_face - position
		else:
			look = dir
			rate = 7.0
	elif _sees or _hold or state == State.CHASE and dist < 4.0:
		look = to if dist > 0.01 else Vector3.ZERO
	else:
		look = dir
		rate = 7.0
	look.y = 0.0
	if look.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, delta * rate))


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
		# Up a stronghold's lane they do not stop to shoot at anyone further off than the next few steps.
		if dist < _ranged_reach():
			_attack_aim = Vector3.INF
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
		_attack_aim = Vector3.INF
		_attack_cd = _attack_interval()
		_attack_left = ATTACK_TIME
		_attack_hit_pending = true
		_current_anim = ""
		_play(BodyAnim.mob_attack(weapon_id, def.get("claws", false)), 1.4, 0.1)
		world.sfx_at(_attack_sound(), position, -8.0)


## Walking straight at someone and getting nowhere: something the grid does not know about is in the way.
func _check_blocked(delta: float) -> void:
	_blocked_timer += delta
	if _blocked_timer < 0.9:
		return
	if position.distance_to(_blocked_from) < 0.3 and not phases:
		_walk_around_until = world.now + 3.0
		_direct = false
	_blocked_timer = 0.0
	_blocked_from = position


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
	if soaked_left > 0.0:
		soaked_left -= delta
		if _drips:
			_drips.emitting = soaked_left > 0.0 and is_alive()
			_puddle.visible = _drips.emitting
			_puddle.scale = Vector3.ONE * body_radius() * (1.6 + 0.12 * sin(_anim_accum * 5.0))
	if _court_light:
		# The Keeper's lamp swells as he lifts it, and blazes as it is held up (here and on every phone).
		var lifting := _current_anim == "Raise" and is_alive()
		var want := KEEPER_LAMP * (6.0 if lifting and is_warning() else 9.0 if lifting else 1.0)
		_court_light.light_energy = move_toward(_court_light.light_energy, want, delta * 14.0)
		_court_light.omni_range = 9.0 + (_court_light.light_energy - KEEPER_LAMP) * 0.8
	var p := world.player
	var every := 1
	if p:
		var to := position - p.global_position
		var distance_squared := to.length_squared()
		if distance_squared > 45.0 * 45.0:
			every = 12
		elif distance_squared > 22.0 * 22.0:
			every = 4
		elif distance_squared > 10.0 * 10.0:
			every = 2
		if distance_squared > 4.0 * 4.0 and to.dot(-p.camera.global_basis.z) < 0.0:
			every = maxi(every, 6)
	if _frozen > 0.0:
		_anim_accum = 0.0
		return
	if _anim != null and (_frame + get_instance_id()) % every == 0:
		_anim.advance(_anim_accum)
		_anim_accum = 0.0


func _update_ground_shadow() -> void:
	var at := Vector2(position.x, position.z)
	if at != _shadow_at or _shadow_terrain != world.terrain or _shadow_revision != world.terrain.bake_revision:
		_shadow_at = at
		_shadow_terrain = world.terrain
		_shadow_revision = world.terrain.bake_revision
		_shadow_floor = world.ground_at(position)
		_shadow_walkable = world.terrain.is_walkable(position.x, position.z)
	var gap := maxf(0.0, position.y - _shadow_floor)
	var transform := Transform3D(Basis.IDENTITY.scaled(Vector3(_scale, 1, _scale) / (1.0 + gap * 0.08)), Vector3(position.x, _shadow_floor + 0.035, position.z))
	if _shadow.global_transform != transform: _shadow.global_transform = transform
	var show := is_alive() and _shadow_walkable and gap < 12.0
	if _shadow.visible != show: _shadow.visible = show
	var alpha := clampf(gap / 12.0, 0.0, 1.0)
	if _shadow.transparency != alpha: _shadow.transparency = alpha
