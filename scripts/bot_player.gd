class_name BotPlayer
extends Node
## A player run by the host's phone, for when there are not enough friends. To everyone else it is just
## another player: a body that moves, fights, falls and comes back. It has no skill tree. Its blows simply
## get stronger as the night goes on, the way a real player's do.

const SPEED := 5.0
const THINK_EVERY := 0.25
const POSE_EVERY := 0.066
const REPATH_EVERY := 1.0
const MELEE_REACH := 2.0
const SHOT_REACH := 18.0
const SHOT_SPEED := 40.0
const SEE_ZOMBIES := 20.0
const SEE_RIVALS := 35.0
const REGEN := 1.0 # health a second
const KILL_HEAL := 8.0
const FOLLOW_AT := 5.0
const SHOT_HITS := 0.7 # how often a shot at another player finds them
const BURN_DPS := 6.0

var world: World
var body: Avatar
var peer := 0
var at := Vector3.ZERO
var hp := 100.0
var max_hp := 100.0
var down := false

var _class_id := "infantry"
var _weapon := ""
var _ranged := false
var _yaw := 0.0
var _velocity := Vector3.ZERO
var _attacks := 0
var _target: Node3D
var _goal := Vector3.ZERO
var _has_goal := false
var _path := PackedVector3Array()
var _path_at := 0
var _repath := 0.0
var _clear_way := false # nothing between here and the goal
var _no_shortcut := 0.0 # that straight line turned out to be blocked at foot level
var _think := 0.0
var _pose := 0.0
var _cooldown := 0.0
var _respawn := -1.0
var _guard := 0.0
var _frozen := 0.0
var _slowed := 0.0
var _burning := 0.0
var _last_by := 0


func _init(owner_world: World, avatar: Avatar, info: Dictionary) -> void:
	world = owner_world
	body = avatar
	peer = avatar.peer
	_class_id = str(info.get("class", "infantry"))
	var def: Dictionary = ClassDefs.ALL[_class_id]
	_weapon = str(def["weapon"])
	var weapon: Dictionary = WeaponDefs.ALL.get(_weapon, {})
	_ranged = not weapon.is_empty() and weapon["kind"] != WeaponDefs.Kind.MELEE
	max_hp = float(def["hp"]) * 1.2
	hp = max_hp
	at = avatar.global_position


func _physics_process(delta: float) -> void:
	if not Net.in_game or Net._over or not is_instance_valid(body):
		return
	_pose -= delta
	if not down:
		_live(delta)
	elif _respawn >= 0.0:
		_respawn -= delta
		if _respawn < 0.0:
			_come_back()
	if _pose <= 0.0:
		_pose = POSE_EVERY
		Net.bot_pose(self, at, _yaw, _velocity, _attacks, _weapon, hp / maxf(max_hp, 1.0))


func _live(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)
	_slowed = maxf(0.0, _slowed - delta)
	_cooldown -= delta
	hp = minf(max_hp, hp + REGEN * delta)
	if _burning > 0.0:
		_burning -= delta
		hurt(BURN_DPS * delta, 0)
	var fog := world.fog
	if fog and not fog.contains(at):
		hurt(ClosingFog.damage_at(world.director.elapsed) * delta, 0)
	if down:
		return
	_velocity = Vector3.ZERO
	if _frozen > 0.0:
		_frozen -= delta
		return
	_think -= delta
	if _think <= 0.0:
		_think = THINK_EVERY
		_decide()
	_act(delta)


## The closest enemy in sight, or a rival if there is one about. Then, where to go.
func _decide() -> void:
	var eye := at + Vector3.UP * 1.5
	var zombie: Zombie = world.nearest_zombie(eye, SEE_ZOMBIES, true)
	var rival := _nearest_rival(SEE_RIVALS, true)
	_target = zombie
	if rival:
		var zombie_far := zombie.position.distance_to(at) if zombie else INF
		# People are worth more trouble than the undead.
		if rival.global_position.distance_to(at) * 0.7 < zombie_far:
			_target = rival
	_has_goal = true
	_decide_goal()
	_clear_way = _has_goal and at.distance_to(_goal) < 12.0 and world.has_line_of_sight(eye, _goal + Vector3.UP * 1.5)


func _decide_goal() -> void:
	var fog := world.fog
	if fog and not fog.contains(at, -3.0):
		_goal = fog.centre3()
	elif _target:
		_goal = _target.global_position
	elif Net.pvp():
		var anyone := _nearest_rival(INF, false)
		if anyone:
			_goal = anyone.global_position
		elif fog:
			_goal = fog.centre3()
		else:
			_has_goal = false
	else:
		var friend := _nearest_friend()
		_has_goal = friend != null and friend.global_position.distance_to(at) > FOLLOW_AT
		if friend:
			_goal = friend.global_position


func _nearest_rival(reach: float, need_sight: bool) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for t: Target in world.players:
		if t == body or t.dead or t.is_unseen() or not Net.bots_foes(peer, _peer_of(t)):
			continue
		var d := t.global_position.distance_to(at)
		if d < best_d and (not need_sight or world.has_line_of_sight(at + Vector3.UP * 1.5, t.eye_position())):
			best_d = d
			best = t
	return best


func _nearest_friend() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for t: Target in world.players:
		if t == body or t.dead or Net.is_bot(_peer_of(t)):
			continue
		var d := t.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = t
	return best


func _peer_of(t: Target) -> int:
	return (t as Avatar).peer if t is Avatar else Net.my_id()


func _target_alive() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	return (_target as Zombie).is_alive() if _target is Zombie else not (_target as Target).dead


func _act(delta: float) -> void:
	var has_target := _target_alive()
	var reach := SHOT_REACH if _ranged else MELEE_REACH
	var stop_at := 0.0
	if has_target:
		var distance := _target.global_position.distance_to(at)
		var edge: float = (_target as Zombie).body_radius() if _target is Zombie else 0.4
		var to := _target.global_position - at
		_yaw = atan2(-to.x, -to.z)
		if distance <= reach + edge and _cooldown <= 0.0:
			_attack(distance)
		stop_at = reach * 0.6 if _ranged else 1.4
		if distance <= stop_at and not (world.fog and not world.fog.contains(at, -3.0)):
			return
	if _has_goal:
		_walk(delta)


func _walk(delta: float) -> void:
	_repath -= delta
	_no_shortcut -= delta
	var direct := _clear_way and _no_shortcut <= 0.0
	if not direct and _repath <= 0.0:
		_repath = REPATH_EVERY
		_path = world.grid.route(at, _goal)
		_path_at = 0
	var next := _goal
	if not direct and _path_at < _path.size():
		next = _path[_path_at]
		if Vector2(next.x - at.x, next.z - at.z).length() < 0.7:
			_path_at += 1
			if _path_at < _path.size():
				next = _path[_path_at]
	var way := Vector3(next.x - at.x, 0.0, next.z - at.z)
	if way.length() < 0.1:
		return
	way = way.normalized()
	var speed := SPEED * (0.6 if _slowed > 0.0 else 1.0)
	var moved := at + way * speed * delta
	if not world.grid.is_free(world.grid.to_cell(moved)):
		if direct or _path_at >= _path.size():
			_no_shortcut = 2.0
			_repath = 0.0
			return
		# Its plan only brushes a corner: the plan is still right, so keep to it.
	at = moved
	at.y = world.ground_at(at) + 0.05
	_velocity = way * speed
	if not _target_alive():
		_yaw = atan2(-way.x, -way.z)


func _power() -> float:
	return 1.0 + world.director.elapsed / 300.0


func _attack(distance: float) -> void:
	_cooldown = 1.1 if _ranged else 0.8
	_attacks += 1
	var damage := WeaponDefs.DAMAGE * _power()
	var aim: Vector3 = (_target as Zombie).centre() if _target is Zombie else _target.global_position + Vector3.UP
	if _ranged:
		var from := at + Vector3.UP * 1.5
		var vel := (aim - from).normalized() * SHOT_SPEED
		var wand := _weapon == "staff"
		world.net_visual_shot(2 if wand else 0, from, vel, 0.0, distance, false, Color(0.5, 0.7, 1.0))
		Net.shot(2 if wand else 0, from, vel, 0.0, distance, false, Color(0.5, 0.7, 1.0))
	if _target is Zombie:
		var z := _target as Zombie
		z.next_hitter = peer
		z.take_damage(damage, z.position - at, 1.5, z.centre())
		if not z.is_alive():
			hp = minf(max_hp, hp + KILL_HEAL)
	elif not _ranged or randf() < SHOT_HITS:
		Net.bot_hit(peer, _peer_of(_target as Target), damage, at)


func hurt(amount: float, by: int) -> void:
	if down or _guard > 0.0:
		return
	if by > 0:
		_last_by = by
	hp -= amount
	if hp <= 0.0:
		_fall()


func ignite(seconds: float) -> void:
	if not down:
		_burning = maxf(_burning, seconds)


func apply_status(kind: int, seconds: float) -> void:
	if down or _guard > 0.0:
		return
	var secs := seconds * Player.PVP_STATUS
	match kind:
		Net.Status.FREEZE, Net.Status.STUN:
			_frozen = maxf(_frozen, secs)
		Net.Status.SLOW:
			_slowed = maxf(_slowed, secs)
		Net.Status.BURN:
			ignite(secs)


func _fall() -> void:
	down = true
	hp = 0.0
	_velocity = Vector3.ZERO
	_target = null
	body.set_fallen(true)
	Net.note_bot_fell(peer, _last_by)
	_last_by = 0
	if Net.fog_rules() and Net.lives_of(peer) <= 0:
		_respawn = -1.0
	else:
		_respawn = Net.FOG_RESPAWN if Net.fog_rules() else Net.RESPAWN_TIME


func _come_back() -> void:
	at = world.far_from_rivals_of(peer) if Net.pvp() else world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(_friend_or_here())))
	at.y = world.ground_at(at) + 0.05
	hp = max_hp
	down = false
	_guard = 2.5
	_frozen = 0.0
	_slowed = 0.0
	_burning = 0.0
	body.teleport(at)
	body.set_fallen(false)


func _friend_or_here() -> Vector3:
	var friend := _nearest_friend()
	if friend:
		return friend.global_position + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	return at
