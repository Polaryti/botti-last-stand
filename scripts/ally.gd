class_name Ally
extends Target
## Friendly fighter: Ghost Knight familiar or summoned skeleton. Follows the player,
## attacks nearby zombies, and draws attacks away from the player.
## Mist Soldiers (the mist_ kinds) belong to nobody: Mist Bastion's garrison holds a post on its
## lane, fights what comes within reach of it and goes back to it. Nobody is credited with their kills.
## Bodies are pooled, because building one in the middle of a fight would stutter.

const ATTACK_RANGE := 1.8
const ATTACK_EVERY := 1.0
const HEALTH := {"magician": 75.0, "artificer": 100.0, "infantry": 140.0, "rat": 40.0, "raven": 70.0, "snake": 90.0, "fox": 100.0, "ghost": 200.0, "wolf": 110.0, "decoy": 70.0, "body": 160.0, "mirror": 50.0, "skeleton": 70.0, "revenant": 110.0, "ranger": 90.0,
	"mist_infantry": 117.0, "mist_ranger": 72.0, "mist_heavy": 221.0}
const KINDS := ["ghost", "wolf", "decoy", "mirror", "skeleton", "revenant", "raven", "snake", "fox", "rat", "body", "magician", "artificer", "infantry", "ranger",
	"mist_infantry", "mist_ranger", "mist_heavy"] # new kinds go at the end: their index travels between phones
## Mist Bastion's garrison: who they are, what they hit for (a weapon blow is 1) and how far from
## their post they will go after an enemy.
const GARRISON := ["mist_infantry", "mist_ranger", "mist_heavy"]
const GARRISON_BLOW := {"mist_infantry": 0.65, "mist_heavy": 1.04}
const GARRISON_SPEED := {"mist_infantry": 5.2, "mist_ranger": 5.2, "mist_heavy": 4.2}
const GARRISON_SIGHT := 18.0
const GARRISON_LEASH := 16.0
const GARRISON_GATE_OUT := 4.0 # metres before its gate that a Mist Soldier stands
const GARRISON_PORTAL_OUT := 5.0 # and from the portal, once its gate has fallen
const GARRISON_ABREAST := 1.7 # between soldiers side by side
const GARRISON_RANGER_ROOM := 6.0 # how far from its place a Mist Ranger backs away from what comes at it
const HEAVY_GUARD := 0.3 # the Mist Heavy's tower shield takes this much off every blow
const RANGER_SHOT := 0.585 # of a weapon blow, every 1.1 seconds
const BEASTS := ["wolf", "raven", "snake", "fox", "rat"]
const BEAST_BITE := {"wolf": 1.0, "raven": 0.8, "snake": 0.7, "fox": 0.75, "rat": 0.4}
const BEAST_SPEED := {"wolf": 7.0, "raven": 8.0, "snake": 7.4, "fox": 7.5, "rat": 7.5}
const RAVEN_HEIGHT := 2.1
const SNAKE_POISON := 0.35
const FOX_FOOD := 0.07 # a bite that turns something up, and of those, how many are food
const FOX_FINDS_FOOD := 0.56 # the rest are arrows, a little less often
const FOX_FIND_GAP := 14.0 # seconds before the fox can find anything again

static var _scenes := {}
static var _ghost_material: StandardMaterial3D
static var _beast_parts := {}

var world: World
var kind := ""
var hp := 90.0
var life := 20.0
var height := 1.8
var remote_owner := 0 # someone else's summon, shown here because it is there
var master: Player # whose summon it is, on this phone: its player, or one of the host's bots
var net_index := 0
var net_target := Vector3.ZERO
var net_yaw := 0.0
var net_biting := false
var _snake: SnakeBody
var guarded := 0.0
## For a Mist Soldier: the lane it holds (its gate's number) and where on it.
var lane := -1
var post := Vector3.INF
var fell_back := false # a Mist Soldier whose gate has fallen: it holds the portal from then on

var _visual: Node3D
var _anim: AnimationPlayer
var _current := ""
var _cooldown := 0.0
var _attack_left := 0.0
var _think := 0.0
var _foe: Zombie
var _rival: Target
var _found_at := -100.0
var _dying := 0.0
var _legs: Array[Node3D] = []
var _run := 0.0
var _head: Node3D
var _tail: Node3D
var _idle_time := 0.0


func _init(owner_world: World, ally_kind: String) -> void:
	world = owner_world
	kind = ally_kind
	collision_mask = 1 | Terrain.BARRIER | (Terrain.ENEMY_ONLY if world.terrain.has_islands() else 0)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = height
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = height * 0.5
	add_child(shape)
	if BEASTS.has(ally_kind):
		_build_beast(_visual_root())
		return
	var model: String = {"ghost": "beast", "decoy": "magic", "mirror": "magic", "revenant": "clever", "body": "clever", "magician": "magic", "artificer": "clever", "infantry": "clever", "ranger": "clever",
		"mist_infantry": "clever", "mist_ranger": "clever", "mist_heavy": "beast"}.get(ally_kind, "skeleton")
	if not _scenes.has(model):
		_scenes[model] = load("res://assets/characters/%s.glb" % model)
	_visual = (_scenes[model] as PackedScene).instantiate()
	add_child(_visual)
	_anim = _visual.find_children("*", "AnimationPlayer", true, false)[0]
	BodyAnim.install(_anim, _visual.find_children("*", "Skeleton3D", true, false)[0])
	for n: String in ["Idle", "Running_A"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var top := 0.0
	var parts := _visual.find_children("*", "MeshInstance3D", true, false)
	for mi in parts:
		var p := mi as MeshInstance3D
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.extra_cull_margin = 1.0
		top = maxf(top, p.get_aabb().end.y)
		if ally_kind not in ["skeleton", "body", "magician", "artificer", "infantry", "ranger"] and ally_kind not in GARRISON:
			p.material_override = _ghost()
	_visual.scale = Vector3.ONE * height / float(Zombie.BODY_TOP.get(model, maxf(top, 0.5)))
	if ally_kind == "body":
		ClassDefs.dress(_visual, "monk")
	elif ally_kind in ["magician", "artificer", "infantry", "ranger"] or ally_kind in GARRISON:
		ClassDefs.dress(_visual, ally_kind)
		_equip_retinue()


## Takes a resting body back into the fight.
func activate(seconds: float) -> void:
	guarded = 0.0
	net_biting = false
	if _snake: _snake.reset_pose()
	life = seconds
	remote_owner = 0
	master = null
	lane = -1
	post = Vector3.INF
	fell_back = false
	_found_at = -100.0
	dead = false
	hp = HEALTH[kind]
	_dying = 0.0
	_cooldown = 0.0
	_attack_left = 0.0
	_think = 0.0
	_foe = null
	velocity = Vector3.ZERO
	collision_layer = LAYER
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_current = ""
	_play("Meditate" if kind == "body" else "Idle")


func deactivate() -> void:
	visible = false
	collision_layer = 0
	process_mode = Node.PROCESS_MODE_DISABLED


func _visual_root() -> Node3D:
	_visual = Node3D.new()
	add_child(_visual)
	return _visual


## The body of a pet, also used to show it in the Store and the Armory. Returns the parts that move.
func _build_beast(root: Node3D) -> void:
	var made := build_beast_model(kind, root)
	_head = made["head"]
	_tail = made["tail"]
	_legs.assign(made["legs"])
	_snake = made.get("snake")


static func _part(root: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func build_beast_model(beast: String, root: Node3D) -> Dictionary:
	match beast:
		"raven": return _raven_model(root)
		"snake": return _snake_model(root)
	return _four_legs_model(beast, root)


static func _four_legs_model(beast: String, root: Node3D) -> Dictionary:
	var fur: Color = {"wolf": Color(0.34, 0.32, 0.34), "fox": Color(0.72, 0.36, 0.12), "rat": Color(0.3, 0.27, 0.24)}[beast]
	if not _beast_parts.has(beast):
		var h := LowPoly.new()
		h.box(Vector3(0, 0.0, 0.1), Vector3(0.36, 0.36, 0.42), fur.darkened(0.08))
		h.box(Vector3(0, -0.08, 0.41), Vector3(0.18, 0.15, 0.3), fur.lightened(0.12))
		h.prism(Vector3(-0.1, 0.18, 0.05), Vector3(-0.12, 0.38, 0.05), 0.06, 0.0, 4, fur)
		h.prism(Vector3(0.1, 0.18, 0.05), Vector3(0.12, 0.38, 0.05), 0.06, 0.0, 4, fur)
		h.box(Vector3(0.09, 0.06, 0.31), Vector3(0.06, 0.05, 0.02), Color(1, 0.8, 0.2))
		h.box(Vector3(-0.09, 0.06, 0.31), Vector3(0.06, 0.05, 0.02), Color(1, 0.8, 0.2))
		var tail := LowPoly.new().prism(Vector3.ZERO, Vector3(0, -0.12, -0.52), 0.09, 0.02, 5, fur.lightened(0.1))
		if beast == "fox":
			tail.prism(Vector3(0, -0.1, -0.42), Vector3(0, -0.12, -0.56), 0.05, 0.01, 5, Color(0.92, 0.9, 0.84))
		_beast_parts[beast] = {
			"body": LowPoly.new().box(Vector3(0, 0.62, 0), Vector3(0.42, 0.42, 1.05), fur).commit(),
			"head": h.commit(), "tail": tail.commit(),
			"leg": LowPoly.new().box(Vector3(0, -0.22, 0), Vector3(0.12, 0.46, 0.12), fur.darkened(0.2)).commit()}
	var parts: Dictionary = _beast_parts[beast]
	root.scale = Vector3.ONE * {"wolf": 1.0, "fox": 0.8, "rat": 0.42}[beast]
	_part(root, parts["body"], Vector3.ZERO)
	var legs: Array[Node3D] = []
	for s: Vector3 in [Vector3(-0.16, 0.46, 0.38), Vector3(0.16, 0.46, 0.38), Vector3(-0.16, 0.46, -0.38), Vector3(0.16, 0.46, -0.38)]:
		legs.append(_part(root, parts["leg"], s))
	return {"head": _part(root, parts["head"], Vector3(0, 0.82, 0.45)), "tail": _part(root, parts["tail"], Vector3(0, 0.72, -0.5)), "legs": legs}


static func _raven_model(root: Node3D) -> Dictionary:
	var ink := Color(0.1, 0.1, 0.14)
	if not _beast_parts.has("raven"):
		_beast_parts["raven"] = {
			"body": LowPoly.new().box(Vector3(0, 0, 0), Vector3(0.2, 0.2, 0.5), ink).commit(),
			"head": LowPoly.new().box(Vector3(0, 0, 0), Vector3(0.16, 0.16, 0.16), ink.lightened(0.08)).prism(Vector3(0, 0, 0.08), Vector3(0, -0.03, 0.26), 0.04, 0.0, 4, Color(0.75, 0.62, 0.2)).commit(),
			"tail": LowPoly.new().box(Vector3(0, 0, -0.15), Vector3(0.18, 0.03, 0.3), ink).commit(),
			"wing": LowPoly.new().box(Vector3(0.28, 0, 0), Vector3(0.56, 0.03, 0.3), ink.lightened(0.05)).commit()}
	var parts: Dictionary = _beast_parts["raven"]
	_part(root, parts["body"], Vector3.ZERO)
	_part(root, parts["wing"], Vector3(0.08, 0.05, 0))
	var left := _part(root, parts["wing"], Vector3(-0.08, 0.05, 0))
	left.rotation.y = PI
	return {"head": _part(root, parts["head"], Vector3(0, 0.08, 0.3)), "tail": _part(root, parts["tail"], Vector3(0, 0, -0.25)), "legs": [] as Array[Node3D]}


static func _snake_model(root: Node3D) -> Dictionary:
	var body := SnakeBody.new()
	root.add_child(body)
	return {"head": body, "tail": body, "legs": [] as Array[Node3D], "snake": body}


static func _ghost() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.albedo_color = Color(0.55, 0.9, 1.0, 0.55)
	return _ghost_material


func _play(n: String, speed := 1.0) -> void:
	if _anim == null:
		return
	if _current == n or not _anim.has_animation(n):
		_anim.speed_scale = speed
		return
	_current = n
	_anim.speed_scale = speed
	_anim.play(n, 0.15)


func _master() -> Player:
	if kind in GARRISON:
		return null
	return master if master != null and is_instance_valid(master) else world.player


func is_garrison() -> bool:
	return kind in GARRISON


func hurt(amount: float, _from: Vector3, _attacker: Zombie = null) -> void:
	var me := _master()
	if kind == "body" and me and me.has_flag("empty_body"):
		amount *= 0.5
	if dead:
		return
	if remote_owner != 0:
		Net.ally_hurt(remote_owner, net_index, amount)
		return
	if guarded > 0.0:
		amount *= 1.0 - WorldLight.DOME_REDUCTION
	if kind == "mist_heavy":
		amount *= 1.0 - HEAVY_GUARD
	# A Guardian shields its own summons too.
	if me and me.m("cover") > 0.0 and global_position.distance_to(me.global_position) <= me.m("cover_radius"):
		amount *= 1.0 - me.m("cover")
	hp -= amount
	if kind == "body" and me:
		me.body_hit(amount)
	if hp <= 0.0:
		_die()


func set_dying(seconds: float) -> void:
	_dying = seconds


func _die() -> void:
	var me := _master()
	var was := world.begin_act(me)
	if kind == "revenant" and me and me.has_flag("host_burst"):
		me.mist_burst_at(position + Vector3.UP, 0.4)
	dead = true
	collision_layer = 0
	_dying = 1.2 if _anim else 0.3
	_current = ""
	_play("Death_A", 1.3)
	if me:
		if kind == "skeleton" and me.has_flag("corpse_blast"):
			world.blast(position + Vector3.UP, 3.0, 25.0)
		elif kind == "decoy":
			me.decoy_burst(position + Vector3.UP)
		elif kind == "body":
			me.body_lost()
	world.end_act(was)


func _physics_process(delta: float) -> void:
	if remote_owner != 0:
		var was := global_position
		global_position = global_position.lerp(net_target, minf(1.0, delta * 9.0))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, delta * 9.0))
		var moving := was.distance_squared_to(global_position) > 0.000004
		_attack_left = 0.25 if net_biting else 0.0
		if kind != "body":
			_play("Running_A" if moving else "Idle")
		_move_wolf(delta, moving)
		return
	var was := world.begin_act(_master())
	_tick_own(delta)
	world.end_act(was)


func _tick_own(delta: float) -> void:
	guarded = maxf(0.0, guarded - delta)
	if dead:
		_dying -= delta
		if _dying <= 0.0:
			world.remove_ally(self)
		return
	life -= delta
	if life <= 0.0:
		_die()
		return
	_cooldown -= delta
	_attack_left -= delta
	_think -= delta
	if kind in GARRISON:
		_tick_garrison(delta)
		return
	if _think <= 0.0:
		_think = 0.25
		_foe = world.nearest_zombie(global_position + Vector3.UP, 16.0, true)
		_rival = world.nearest_rival(global_position + Vector3.UP, 16.0)
		if kind == "decoy" or kind == "body":
			_foe = null
			_rival = null
		elif _rival and _foe and _foe.position.distance_squared_to(position) < _rival.global_position.distance_squared_to(position):
			_rival = null
	var dir := Vector3.ZERO
	var speed: float = BEAST_SPEED.get(kind, 5.0)
	if kind == "decoy" or kind == "body":
		velocity = Vector3.ZERO
		return
	if kind == "mirror" or (kind in ["magician", "ranger"] and (_foe != null or _rival != null)):
		if _rival and not _rival.dead and _cooldown <= 0.0:
			_cooldown = 1.2
			_retinue_shot(position + Vector3.UP * 1.4, _rival.global_position + Vector3.UP)
			_current = ""
			_play(_shoot_anim(), 1.5)
			return
		if _foe and _foe.is_alive() and _cooldown <= 0.0:
			_cooldown = 1.2
			var from := position + Vector3.UP * 1.4
			_retinue_shot(from, _foe.centre())
			_current = ""
			_play(_shoot_anim(), 1.5)
		if _foe and _foe.is_alive():
			var look := _foe.position - position
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), min(1.0, delta * 9.0))
		return
	var player := _master()
	var dmg_mult: float = player.m("ally_damage") if player else 1.0
	if _rival and not _rival.dead:
		var to := _rival.global_position - position
		to.y = 0.0
		if to.length() > ATTACK_RANGE * 0.8:
			dir = to.normalized()
		if to.length() < ATTACK_RANGE and _cooldown <= 0.0:
			_cooldown = ATTACK_EVERY
			_attack_left = 0.5 if _anim else 0.25
			_current = ""
			_play("1H_Melee_Attack_Chop", 1.5)
			world.hit_rival(_rival, WeaponDefs.DAMAGE * dmg_mult * 0.7, position)
			world.sfx_at("wolf" if kind in ["wolf", "fox"] else "thunk" if BEASTS.has(kind) else "clang", position, -10.0)
		if to.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 9.0))
	elif _foe and _foe.is_alive():
		var to := _foe.position - position
		to.y = 0.0
		if to.length() > ATTACK_RANGE * 0.8:
			dir = to.normalized()
		if to.length() < ATTACK_RANGE and _cooldown <= 0.0:
			_cooldown = ATTACK_EVERY
			_attack_left = 0.5 if _anim else 0.25
			_current = ""
			_play("1H_Melee_Attack_Chop", 1.5)
			_foe.take_damage(WeaponDefs.DAMAGE * dmg_mult * float(BEAST_BITE.get(kind, 0.7 if kind == "revenant" else 0.8 if kind == "skeleton" else 1.0)), to, 2.0, _foe.centre())
			if _foe.is_alive() and kind == "artificer":
				_foe.ignite(ZombieDefs.BURN_SECONDS)
			if not _foe.is_alive() and player:
				player.on_ally_kill()
			elif BEASTS.has(kind) and player and player.has_flag("wolf_stun"):
				_foe.stun(AbilityNumbers.SAVAGE_BITE_STUN)
			if _foe.is_alive() and kind == "snake" and randf() < SNAKE_POISON:
				_foe.add_dot(10.0, 4.0)
				if player == world.player:
					Game.note_poison(40.0)
			if _foe.is_alive() and kind == "rat" and player and player.has_flag("rat_poison") and randf() < 0.5:
				_foe.add_dot(10.0, 4.0)
				if player == world.player:
					Game.note_poison(40.0)
			if kind == "fox":
				_forage()
			world.sfx_at("wolf" if kind in ["wolf", "fox"] else "thunk" if BEASTS.has(kind) else "clang", position, -10.0)
		if to.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 9.0))
	elif player:
		var to := player.global_position - position
		to.y = 0.0
		if world.portals and to.length() > 26.0:
			# You went through a gate. It finds its own way.
			position = player.global_position + Vector3(1.5, 0.0, 1.5)
		if to.length() > 4.0:
			dir = to.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 7.0))
			speed = 6.0
	if _attack_left > 0.0:
		dir = Vector3.ZERO
	velocity = dir * speed
	move_and_slide()
	position.y = world.ground_at(position) + (RAVEN_HEIGHT if kind == "raven" else 0.0)
	if _attack_left <= 0.0:
		_play("Running_A" if dir != Vector3.ZERO else "Idle")
	_move_wolf(delta, dir != Vector3.ZERO)


## A Mist Soldier: hold the post, fight whatever comes near it, and go back to it. The Ranger shoots
## from where it stands and steps back from anything that gets close; the Infantry and the Heavy close in.
func _tick_garrison(delta: float) -> void:
	if _foe and not _foe.is_alive():
		_foe = null
	var home := _garrison_home()
	var fort := world.fort
	# On its way in through a fallen gate it fights only what is on top of it.
	var falling_back := fell_back and fort != null and not fort.inside(position)
	if _think <= 0.0:
		_think = 0.25
		_foe = world.nearest_zombie(global_position + Vector3.UP, 3.0 if falling_back else GARRISON_SIGHT, true)
		if _foe and home != Vector3.INF and _foe.position.distance_to(home) > GARRISON_LEASH + 4.0:
			_foe = null
		# Before its gate it fights what comes up the lane; at the portal, what has got inside.
		if _foe and fort and not falling_back and fort.inside(_foe.position) != fell_back and not _foe.flies:
			_foe = null
	var heavy := kind == "mist_heavy"
	var dir := Vector3.ZERO
	var speed: float = GARRISON_SPEED[kind]
	if _foe:
		var to := _foe.position - position
		to.y = 0.0
		if kind == "mist_ranger":
			if _cooldown <= 0.0:
				_cooldown = 1.1
				world.garrison_arrow(position + Vector3.UP * 1.4, _foe.centre(), WeaponDefs.DAMAGE * RANGER_SHOT)
				_attack_left = 0.35
				_current = ""
				_play("2H_Ranged_Shoot", 1.5)
			var stand := home if home != Vector3.INF else position
			if to.length() < 5.0 and position.distance_to(stand) < GARRISON_RANGER_ROOM and (fort == null or fort.inside(position - to.normalized()) == fort.inside(position)):
				dir = -to.normalized()
		else:
			var reach := ATTACK_RANGE + (0.5 if heavy else 0.0)
			if to.length() > reach * 0.8:
				dir = to.normalized()
			if to.length() < reach and _cooldown <= 0.0:
				_cooldown = ATTACK_EVERY * (1.35 if heavy else 1.0)
				_attack_left = 0.5
				_current = ""
				var swing := "2H_Melee_Attack_Chop" if heavy and _anim and _anim.has_animation("2H_Melee_Attack_Chop") else "1H_Melee_Attack_Chop"
				_play(swing, 1.5)
				_foe.next_hitter = -1 # nobody's kill
				_foe.take_damage(WeaponDefs.DAMAGE * float(GARRISON_BLOW[kind]), to.normalized(), 4.0 if heavy else 2.0, _foe.centre())
				world.sfx_at("clang", position, -9.0)
		if to.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 9.0))
	elif home != Vector3.INF:
		var to := _garrison_step(home) - position
		to.y = 0.0
		if to.length() > 1.5:
			dir = to.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 7.0))
	if _attack_left > 0.0:
		dir = Vector3.ZERO
	velocity = dir * speed
	move_and_slide()
	position.y = world.ground_at(position)
	if _attack_left <= 0.0:
		_play("Running_A" if dir != Vector3.ZERO else "Idle")


## Where a Mist Soldier's duty is right now. While its lane's gate stands: on the ground before the
## gate, where whatever comes up the lane to break it has to get past. Once that gate has fallen: by
## the portal, on the side the fallen gate is, and there it stays even if the gate is mended.
func _garrison_home() -> Vector3:
	var fort := world.fort
	if fort == null or lane < 0 or lane >= fort.gates.size():
		return post
	var g: Dictionary = fort.gates[lane]
	var out: Vector3 = g["dir"]
	var side := out.cross(Vector3.UP) * (float(net_index % 3) - 1.0) * GARRISON_ABREAST
	if not g["closed"]:
		fell_back = true
	if fell_back:
		var towards := (g["at"] as Vector3) - fort.heart_at
		towards.y = 0.0
		return fort.heart_at + towards.normalized() * GARRISON_PORTAL_OUT + side
	return (g["at"] as Vector3) + out * (GARRISON_GATE_OUT + (1.6 if kind == "mist_ranger" else 0.0)) + side


## The next spot to walk to on the way home. Falling back from before a fallen gate, that is first
## the mouth of the gateway and then the far side of it: a straight line would meet the wall.
func _garrison_step(home: Vector3) -> Vector3:
	var fort := world.fort
	if not fell_back or fort == null or fort.inside(position):
		return home
	var g: Dictionary = fort.gates[lane]
	var out: Vector3 = g["dir"]
	var from: Vector3 = position - (g["at"] as Vector3)
	from.y = 0.0
	var along := from.dot(out)
	var aside := (from - out * along).length()
	if aside > 1.0 and along > -1.0:
		return (g["at"] as Vector3) + out * maxf(2.0, minf(along, 4.0))
	return (g["at"] as Vector3) - out * (Fort.WALL_T * 0.5 + 2.5)


## Now and then a bite turns something up: food, or a few arrows. Never twice in quick succession.
func _forage() -> void:
	if world.now - _found_at < FOX_FIND_GAP or randf() >= FOX_FOOD:
		return
	_found_at = world.now
	var spot := position + Vector3(0.6, 0, 0.6)
	if randf() < FOX_FINDS_FOOD:
		world.spawn_pickup_at(spot, Pickup.Kind.FOOD, PowerDefs.FOODS.keys().pick_random())
	else:
		world.spawn_pickup_at(spot, Pickup.Kind.ARROWS, "arrows")


## Legs, a bounce in its stride, a tail that never quite stops, and a lunge when it bites.
func _move_wolf(delta: float, moving: bool) -> void:
	if _snake:
		_snake.moving = moving
		_snake.biting = _attack_left > 0.0
		return
	if _legs.is_empty():
		return
	_idle_time += delta
	if moving:
		_run += delta * 16.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_run + (0.0 if i % 3 == 0 else PI)) * (0.7 if moving else lerpf(absf(_legs[i].rotation.x), 0.0, 0.5))
	_visual.position.y = absf(sin(_run)) * 0.07 if moving else sin(_idle_time * 1.6) * 0.012
	_visual.rotation.x = sin(_run) * 0.05 if moving else 0.0
	_tail.rotation.y = sin(_idle_time * (11.0 if moving else 3.5)) * (0.3 if moving else 0.5)
	if _attack_left > 0.0:
		_head.rotation.x = 0.45 * sin(_attack_left * 12.0)
		_head.position.z = 0.45 + 0.14 * absf(sin(_attack_left * 12.0))
	else:
		_head.rotation.x = sin(_idle_time * 1.3) * 0.06
		_head.position.z = 0.45
		_head.rotation.y = sin(_idle_time * 0.7) * (0.0 if moving else 0.28)


func _shoot_anim() -> String:
	return "2H_Ranged_Shoot" if kind == "ranger" else "Spellcast_Shoot"


func _retinue_shot(from: Vector3, at: Vector3) -> void:
	var owner_player := _master()
	if owner_player and kind == "ranger":
		world.spawn_player_arrow(owner_player, from, (at - from).normalized() * 40.0, 0.0, 30.0, 1.0, WeaponDefs.DAMAGE * owner_player.m("ally_damage"), false)
		world.sfx_at("bow", from, -9.0)
	elif owner_player and kind == "magician":
		world.spawn_bolt(owner_player, from, (at - from).normalized() * 30.0, 26.0, 1.0, 25.0 * owner_player.m("ally_damage"), false)
	else:
		world.mirror_bolt(from, at)


func _equip_retinue() -> void:
	var skeleton: Skeleton3D = _visual.find_children("*", "Skeleton3D", true, false)[0]
	var bone := "handslot.r"
	if skeleton.find_bone(bone) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var hand := MeshInstance3D.new()
	var weapon := "staff" if kind == "magician" else "torch" if kind == "artificer" else "bow" if kind in ["ranger", "mist_ranger"] else "battleaxe" if kind == "mist_heavy" else "sword"
	hand.mesh = WeaponDefs.mesh(weapon)
	hand.rotation = WeaponDefs.hand_rotation(weapon)
	hand.scale = Vector3.ONE * 0.8 / _visual.scale.x
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment.add_child(hand)
	if weapon == "torch":
		var flame := MeshInstance3D.new()
		flame.mesh = WorldLight.flame_mesh()
		flame.position.y = WeaponDefs.TORCH_FIRE
		flame.scale = Vector3.ONE * 0.14
		hand.add_child(flame)
