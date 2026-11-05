class_name BotPlayer
extends Node
## A player run by the host's phone, for when there are not enough friends. To everyone else it is just
## another player: a body that moves, fights, falls and comes back. It levels up and picks a gift each
## time, goes looking for weapons, arrows, food and familiars, and is sharper on a harder difficulty.

const SPEED := 5.0
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
const BURN_DPS := 6.0
const DEBUFF_DPS := 3.0
const MAX_LEVEL := 10
const TAKE_REACH := 1.6
const TIME_XP_EVERY := 20.0 # a bot learns a little just by staying alive
const FAMILIAR_TIME := 30.0
const FAMILIAR_POWER := 1.3
## By difficulty: how often it thinks, how far it sees, how often its shots land, how slowly it attacks,
## how hurt it must be to back off, how far it will go for an item.
const SMARTS := [
	{"think": 0.45, "see": 0.8, "aim": 0.5, "pace": 1.25, "retreat": 0.0, "items": 14.0, "kite": false},
	{"think": 0.25, "see": 1.0, "aim": 0.7, "pace": 1.0, "retreat": 0.25, "items": 28.0, "kite": false},
	{"think": 0.15, "see": 1.15, "aim": 0.85, "pace": 0.88, "retreat": 0.35, "items": 45.0, "kite": true},
]
## What it can choose on levelling up, and how much each class likes it.
const GIFTS := {
	"damage": {"infantry": 3, "ranger": 3, "heavy": 2, "chivalry": 3, "magician": 3, "revenant": 3, "artificer": 2},
	"health": {"infantry": 2, "ranger": 1, "heavy": 3, "chivalry": 2, "magician": 1, "revenant": 2, "artificer": 2},
	"speed": {"infantry": 2, "ranger": 2, "heavy": 1, "chivalry": 2, "magician": 1, "revenant": 2, "artificer": 1},
	"haste": {"infantry": 3, "ranger": 2, "heavy": 1, "chivalry": 1, "magician": 2, "revenant": 3, "artificer": 2},
	"regen": {"infantry": 1, "ranger": 1, "heavy": 2, "chivalry": 1, "magician": 2, "revenant": 1, "artificer": 1},
}

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
var level := 1
var gifts := {} # gift name: how many times taken
var arrows := 0
var kills := 0
var _xp := 0
var _time_xp := TIME_XP_EVERY
var _smart: Dictionary = SMARTS[1]
var _item: Pickup
var _familiar := 0.0
var _poisoned := 0.0
var _bleeding := 0.0


func _init(owner_world: World, avatar: Avatar, info: Dictionary) -> void:
	world = owner_world
	body = avatar
	peer = avatar.peer
	_class_id = str(info.get("class", "infantry"))
	var def: Dictionary = ClassDefs.ALL[_class_id]
	_smart = SMARTS[clampi(Game.difficulty, 0, SMARTS.size() - 1)]
	arrows = int(def.get("arrows", 0))
	_set_weapon(str(def["weapon"]))
	max_hp = float(def["hp"]) * 1.2
	hp = max_hp
	at = avatar.global_position


func _set_weapon(id: String) -> void:
	_weapon = id
	var weapon: Dictionary = WeaponDefs.ALL.get(id, {})
	_ranged = not weapon.is_empty() and weapon["kind"] != WeaponDefs.Kind.MELEE


func _weapon_def() -> Dictionary:
	return WeaponDefs.ALL.get(_weapon, {})


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
	_familiar -= delta
	hp = minf(max_hp, hp + (REGEN + 0.5 * int(gifts.get("regen", 0))) * delta)
	_time_xp -= delta
	if _time_xp <= 0.0:
		_time_xp = TIME_XP_EVERY
		_gain_xp(1)
	if _burning > 0.0:
		_burning -= delta
		hurt(BURN_DPS * delta, 0)
	if _poisoned > 0.0:
		_poisoned -= delta
		hurt(DEBUFF_DPS * delta, 0)
	if _bleeding > 0.0:
		_bleeding -= delta
		hurt(DEBUFF_DPS * delta, 0)
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
		_think = float(_smart["think"])
		_decide()
	_act(delta)


## The closest enemy in sight, or a rival if there is one about. Then, where to go.
func _decide() -> void:
	var eye := at + Vector3.UP * 1.5
	var zombie: Zombie = world.nearest_zombie(eye, SEE_ZOMBIES * float(_smart["see"]), true)
	var rival := _nearest_rival(SEE_RIVALS * float(_smart["see"]), true)
	_target = zombie
	if rival:
		var zombie_far := zombie.position.distance_to(at) if zombie else INF
		# People are worth more trouble than the undead.
		if rival.global_position.distance_to(at) * 0.7 < zombie_far:
			_target = rival
	_has_goal = true
	_item = _wanted_item()
	_decide_goal()
	_clear_way = _has_goal and at.distance_to(_goal) < 12.0 and world.has_line_of_sight(eye, _goal + Vector3.UP * 1.5)


func _decide_goal() -> void:
	var fog := world.fog
	if fog and not fog.contains(at, -3.0):
		_goal = fog.centre3()
	elif _item:
		_goal = _item.global_position
	elif _backing_off():
		var friend := _nearest_friend()
		var away := (at - _target.global_position).normalized() * 12.0
		_goal = friend.global_position if friend else at + away
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


## Too hurt to carry on with this fight.
func _backing_off() -> bool:
	return _target != null and is_instance_valid(_target) and float(_smart["retreat"]) > 0.0 and hp < max_hp * float(_smart["retreat"])


## What is worth walking to right now. With an enemy on top of it, only food is worth the risk.
func _wanted_item() -> Pickup:
	var hurt_badly := hp < max_hp * 0.35
	var busy := _target != null and is_instance_valid(_target) and _target.global_position.distance_to(at) < 5.0
	var best: Pickup = null
	var best_score := 0.0
	for p: Pickup in world.pickups:
		var d := p.global_position.distance_to(at)
		if d > float(_smart["items"]):
			continue
		var worth := _worth(p)
		if worth <= 0.0 or (busy and not (hurt_badly and p.kind == Pickup.Kind.FOOD)):
			continue
		var score := worth / (d + 4.0)
		if score > best_score:
			best_score = score
			best = p
	return best


func _worth(p: Pickup) -> float:
	var def: Dictionary = ClassDefs.ALL[_class_id]
	match p.kind:
		Pickup.Kind.FOOD:
			return 4.0 if hp < max_hp * 0.35 else (2.0 if hp < max_hp * 0.7 else 0.0)
		Pickup.Kind.ARROWS:
			return 2.0 if WeaponDefs.uses_arrows(_weapon_def()) and arrows < 15 else 0.0
		Pickup.Kind.POWER:
			return 3.0 if PowerDefs.ALL[p.item_id]["familiar"] else 1.0
		Pickup.Kind.WEAPON:
			if def.get("no_weapons", false) or def.get("mana", false):
				return 0.0
			var d: Dictionary = WeaponDefs.ALL[p.weapon_id]
			if d["kind"] == WeaponDefs.Kind.RANGED and not def.get("ranged", false):
				return 0.0
			return 1.5 if _weapon_value(d) > _weapon_value(_weapon_def()) * 1.15 else 0.0
	return 0.0


static func _weapon_value(d: Dictionary) -> float:
	if d.is_empty():
		return 0.0
	return float(d.get("power", 1.0)) * minf(float(d.get("max_hits", 1)), 3.0) / float(d["rate"]) * (1.3 if d["kind"] != WeaponDefs.Kind.MELEE else 1.0)


func _take(p: Pickup) -> void:
	match p.kind:
		Pickup.Kind.FOOD:
			hp = minf(max_hp, hp + float(PowerDefs.FOODS[p.item_id]["heal"]))
		Pickup.Kind.ARROWS:
			arrows += 12
		Pickup.Kind.POWER:
			_familiar = FAMILIAR_TIME
		Pickup.Kind.WEAPON:
			_set_weapon(p.weapon_id)
			arrows += p.bonus_arrows
	world.sfx_at("pickup", at, -8.0)
	world.remove_pickup(p)
	_item = null


func _gain_xp(amount: int) -> void:
	_xp += amount
	while level < MAX_LEVEL and _xp >= 3 + level * 2:
		_xp -= 3 + level * 2
		level += 1
		_choose_gift()


func _choose_gift() -> void:
	var total := 0
	for gift: String in GIFTS:
		total += int(GIFTS[gift].get(_class_id, 1))
	var roll := randi() % maxi(total, 1)
	for gift: String in GIFTS:
		roll -= int(GIFTS[gift].get(_class_id, 1))
		if roll < 0:
			gifts[gift] = int(gifts.get(gift, 0)) + 1
			if gift == "health":
				max_hp += 15.0
				hp += 15.0
			return


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
	if _item and is_instance_valid(_item) and _item.global_position.distance_to(at) < TAKE_REACH:
		_take(_item)
	# Out of arrows: back to what it started with, or its fists.
	if WeaponDefs.uses_arrows(_weapon_def()) and arrows <= 0:
		var own := str(ClassDefs.ALL[_class_id]["weapon"])
		_set_weapon(own if not WeaponDefs.uses_arrows(WeaponDefs.ALL[own]) else "dagger")
	var has_target := _target_alive()
	var d := _weapon_def()
	var reach: float = minf(float(d.get("range", SHOT_REACH)), SHOT_REACH) if _ranged else maxf(MELEE_REACH, float(d.get("range", MELEE_REACH)) * 0.8)
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
	var speed := SPEED * (0.6 if _slowed > 0.0 else 1.0) * (1.0 + 0.06 * int(gifts.get("speed", 0)))
	if _bleeding > 0.0:
		speed *= Player.BLEED_SPEED
	if world.terrain.in_water(body.global_position.x, body.global_position.z):
		speed *= Player.WADE_SPEED
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
	var power := (1.0 + 0.12 * int(gifts.get("damage", 0))) * (1.0 + world.director.elapsed / 900.0)
	return power * (FAMILIAR_POWER if _familiar > 0.0 else 1.0)


func _attack(distance: float) -> void:
	var d := _weapon_def()
	_cooldown = float(d.get("rate", 0.6)) * 1.4 * float(_smart["pace"]) / (1.0 + 0.08 * int(gifts.get("haste", 0)))
	_attacks += 1
	if WeaponDefs.uses_arrows(d):
		arrows -= 1
	var damage := WeaponDefs.DAMAGE * float(d.get("power", 1.0)) * _power()
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
		if d.get("burns", false):
			z.ignite(ZombieDefs.BURN_SECONDS)
		if d.get("bleed", false):
			z.add_dot(8.0, 3.0, true)
		if d.has("poison"):
			z.add_dot((d["poison"] as Vector2).x, (d["poison"] as Vector2).y)
		if d.has("stun"):
			z.stun(float(d["stun"]))
		if not z.is_alive():
			hp = minf(max_hp, hp + KILL_HEAL)
			kills += 1
			_gain_xp(1)
	elif not _ranged or randf() < float(_smart["aim"]):
		Net.bot_hit(peer, _peer_of(_target as Target), damage, at)


func hurt(amount: float, by: int) -> void:
	if down or _guard > 0.0:
		return
	if by > 0:
		_last_by = by
	hp -= amount * (Player.POISON_HURT if _poisoned > 0.0 else 1.0)
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
		Net.Status.POISON:
			_poisoned = maxf(_poisoned, secs)
		Net.Status.BLEED:
			_bleeding = maxf(_bleeding, secs)


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
	_poisoned = 0.0
	_bleeding = 0.0
	_familiar = 0.0
	_item = null
	body.teleport(at)
	body.set_fallen(false)


func _friend_or_here() -> Vector3:
	var friend := _nearest_friend()
	if friend:
		return friend.global_position + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	return at
