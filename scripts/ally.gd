class_name Ally
extends Target
## Friendly fighter: Ghost Knight familiar or summoned skeleton. Follows the player,
## attacks nearby zombies, and draws attacks away from the player.
## Bodies are pooled, because building one in the middle of a fight would stutter.

const ATTACK_RANGE := 1.8
const ATTACK_EVERY := 1.0
const HEALTH := {"ghost": 200.0, "wolf": 110.0, "decoy": 70.0, "mirror": 50.0, "skeleton": 70.0, "revenant": 110.0}
const KINDS := ["ghost", "wolf", "decoy", "mirror", "skeleton", "revenant"]

static var _scenes := {}
static var _ghost_material: StandardMaterial3D
static var _wolf_body: Mesh
static var _wolf_leg: Mesh
static var _wolf_head: Mesh
static var _wolf_tail: Mesh

var world: World
var kind := ""
var hp := 90.0
var life := 20.0
var height := 1.8
var remote_owner := 0 # someone else's summon, shown here because it is there
var net_index := 0
var net_target := Vector3.ZERO
var net_yaw := 0.0
var guarded := 0.0

var _visual: Node3D
var _anim: AnimationPlayer
var _current := ""
var _cooldown := 0.0
var _attack_left := 0.0
var _think := 0.0
var _foe: Zombie
var _rival: Avatar
var _dying := 0.0
var _legs: Array[Node3D] = []
var _run := 0.0
var _head: Node3D
var _tail: Node3D
var _idle_time := 0.0


func _init(owner_world: World, ally_kind: String) -> void:
	world = owner_world
	kind = ally_kind
	collision_mask = 1 | Terrain.BARRIER
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = height
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = height * 0.5
	add_child(shape)
	if ally_kind == "wolf":
		_build_wolf()
		return
	var model: String = {"ghost": "beast", "decoy": "magic", "mirror": "magic", "revenant": "clever"}.get(ally_kind, "skeleton")
	if not _scenes.has(model):
		_scenes[model] = load("res://assets/characters/%s.glb" % model)
	_visual = (_scenes[model] as PackedScene).instantiate()
	add_child(_visual)
	_anim = _visual.find_children("*", "AnimationPlayer", true, false)[0]
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
		if ally_kind != "skeleton":
			p.material_override = _ghost()
	_visual.scale = Vector3.ONE * height / float(Zombie.BODY_TOP.get(model, maxf(top, 0.5)))


## Takes a resting body back into the fight.
func activate(seconds: float) -> void:
	life = seconds
	remote_owner = 0
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
	_play("Idle")


func deactivate() -> void:
	visible = false
	collision_layer = 0
	process_mode = Node.PROCESS_MODE_DISABLED


func _build_wolf() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := Color(0.34, 0.32, 0.34)
	if _wolf_body == null:
		_wolf_body = LowPoly.new().box(Vector3(0, 0.62, 0), Vector3(0.42, 0.42, 1.05), fur).commit()
		var h := LowPoly.new()
		h.box(Vector3(0, 0.0, 0.1), Vector3(0.36, 0.36, 0.42), fur.darkened(0.08))
		h.box(Vector3(0, -0.08, 0.41), Vector3(0.18, 0.15, 0.3), fur.lightened(0.12))
		h.prism(Vector3(-0.1, 0.18, 0.05), Vector3(-0.12, 0.38, 0.05), 0.06, 0.0, 4, fur)
		h.prism(Vector3(0.1, 0.18, 0.05), Vector3(0.12, 0.38, 0.05), 0.06, 0.0, 4, fur)
		h.box(Vector3(0.09, 0.06, 0.31), Vector3(0.06, 0.05, 0.02), Color(1, 0.8, 0.2))
		h.box(Vector3(-0.09, 0.06, 0.31), Vector3(0.06, 0.05, 0.02), Color(1, 0.8, 0.2))
		_wolf_head = h.commit()
		_wolf_tail = LowPoly.new().prism(Vector3.ZERO, Vector3(0, -0.12, -0.52), 0.09, 0.02, 5, fur.lightened(0.05)).commit()
		_wolf_leg = LowPoly.new().box(Vector3(0, -0.22, 0), Vector3(0.12, 0.46, 0.12), fur.darkened(0.2)).commit()
	var body := MeshInstance3D.new()
	body.mesh = _wolf_body
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = _wolf_head
	head.position = Vector3(0, 0.82, 0.45)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(head)
	_head = head
	var tail := MeshInstance3D.new()
	tail.mesh = _wolf_tail
	tail.position = Vector3(0, 0.72, -0.5)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(tail)
	_tail = tail
	for s: Vector3 in [Vector3(-0.16, 0.46, 0.38), Vector3(0.16, 0.46, 0.38), Vector3(-0.16, 0.46, -0.38), Vector3(0.16, 0.46, -0.38)]:
		var mi := MeshInstance3D.new()
		mi.mesh = _wolf_leg
		mi.position = s
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)
		_legs.append(mi)


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


func hurt(amount: float, _from: Vector3, _attacker: Zombie = null) -> void:
	if dead:
		return
	if remote_owner != 0:
		Net.ally_hurt(remote_owner, net_index, amount)
		return
	if guarded > 0.0:
		return
	# A Guardian shields its own summons too.
	var me := world.player
	if me and me.m("cover") > 0.0 and global_position.distance_to(me.global_position) <= me.m("cover_radius"):
		amount *= 1.0 - me.m("cover")
	hp -= amount
	if hp <= 0.0:
		_die()


func _die() -> void:
	if kind == "revenant" and world.player and world.player.has_flag("host_burst"):
		world.player.mist_burst_at(position + Vector3.UP, 0.4)
	dead = true
	collision_layer = 0
	_dying = 1.2 if _anim else 0.3
	_current = ""
	_play("Death_A", 1.3)
	if not world.player:
		return
	if kind == "skeleton" and world.player.has_flag("corpse_blast"):
		world.blast(position + Vector3.UP, 3.0, 25.0)
	elif kind == "decoy":
		world.player.decoy_burst(position + Vector3.UP)


func _physics_process(delta: float) -> void:
	if remote_owner != 0:
		var was := global_position
		global_position = global_position.lerp(net_target, minf(1.0, delta * 9.0))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, delta * 9.0))
		_play("Running_A" if was.distance_squared_to(net_target) > 0.05 else "Idle")
		_move_wolf(delta, was.distance_squared_to(net_target) > 0.05)
		return
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
	if _think <= 0.0:
		_think = 0.25
		_foe = world.nearest_zombie(global_position + Vector3.UP, 16.0, true)
		_rival = world.nearest_rival(global_position + Vector3.UP, 16.0)
		if kind == "decoy":
			_foe = null
			_rival = null
		elif _rival and _foe and _foe.position.distance_squared_to(position) < _rival.global_position.distance_squared_to(position):
			_rival = null
	var dir := Vector3.ZERO
	var speed := 7.0 if kind == "wolf" else 5.0
	if kind == "decoy":
		velocity = Vector3.ZERO
		return
	if kind == "mirror":
		if _rival and not _rival.dead and _cooldown <= 0.0:
			_cooldown = 1.2
			world.mirror_bolt(position + Vector3.UP * 1.4, _rival.global_position + Vector3.UP)
			_current = ""
			_play("Spellcast_Shoot", 1.5)
			return
		if _foe and _foe.is_alive() and _cooldown <= 0.0:
			_cooldown = 1.2
			var from := position + Vector3.UP * 1.4
			world.mirror_bolt(from, _foe.centre())
			_current = ""
			_play("Spellcast_Shoot", 1.5)
		if _foe and _foe.is_alive():
			var look := _foe.position - position
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), min(1.0, delta * 9.0))
		return
	var player := world.player
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
			Net.hit_player(_rival.peer, WeaponDefs.DAMAGE * dmg_mult * 0.7, position)
			world.sfx_at("wolf" if kind == "wolf" else "clang", position, -10.0)
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
			_foe.take_damage(WeaponDefs.DAMAGE * dmg_mult * (0.7 if kind == "revenant" else 0.8 if kind == "skeleton" else 1.0), to, 2.0, _foe.centre())
			if not _foe.is_alive() and player:
				player.on_ally_kill()
			elif kind == "wolf" and player and player.has_flag("wolf_stun"):
				_foe.stun(0.7)
			world.sfx_at("wolf" if kind == "wolf" else "clang", position, -10.0)
		if to.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 9.0))
	elif world.player:
		var to := world.player.global_position - position
		to.y = 0.0
		if to.length() > 4.0:
			dir = to.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), min(1.0, delta * 7.0))
			speed = 6.0
	if _attack_left > 0.0:
		dir = Vector3.ZERO
	velocity = dir * speed
	move_and_slide()
	position.y = world.ground_at(position)
	if _attack_left <= 0.0:
		_play("Running_A" if dir != Vector3.ZERO else "Idle")
	_move_wolf(delta, dir != Vector3.ZERO)


## Legs, a bounce in its stride, a tail that never quite stops, and a lunge when it bites.
func _move_wolf(delta: float, moving: bool) -> void:
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
