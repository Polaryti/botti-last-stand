class_name BotPlayer
extends Node
## A player run by the host's phone, for when there are not enough friends. The bot is a real Player,
## with the body, weapons, skill tree, Store items and pet a person has, so everything a person can
## do to another person works on it, and everything it does works like a person's. This node only
## decides: where to go, what to hit, which ability to use, and what to take when it levels up.
## To everyone else it is another player's body, sent from here like any phone's.

const POSE_EVERY := 0.066
const REPATH_EVERY := 1.0
const SEE_ZOMBIES := 20.0
const SEE_RIVALS := 35.0
const FOLLOW_AT := 5.0
const SHOT_REACH := 22.0
const MELEE_SLACK := 0.3
## By difficulty: how often it thinks, how far it sees, how far off its aim can be (radians), how
## much slower than it could it attacks, how hurt it must be to back off, how far it goes for an
## item, whether it keeps its distance with a bow, and how often it uses an ability when it could.
const SMARTS := [
	{"think": 0.45, "see": 0.8, "aim": 0.12, "pace": 1.35, "retreat": 0.0, "items": 14.0, "kite": false, "skills": 0.45},
	{"think": 0.25, "see": 1.0, "aim": 0.06, "pace": 1.12, "retreat": 0.25, "items": 28.0, "kite": false, "skills": 0.75},
	{"think": 0.15, "see": 1.15, "aim": 0.03, "pace": 1.0, "retreat": 0.35, "items": 45.0, "kite": true, "skills": 1.0},
]

var world: World
var body: Avatar
var peer := 0
var pawn: Player

var _class_id := "infantry"
var _smart: Dictionary = SMARTS[1]
var _target: Node3D
var _explore := Vector3.INF
var _goal := Vector3.ZERO
var _has_goal := false
var _path := PackedVector3Array()
var _path_at := 0
var _repath := 0.0
var _fort_cross := Vector3.INF
var _clear_way := false # nothing between here and the goal
var _no_shortcut := 0.0 # that straight line turned out to be blocked at foot level
var _think := 0.0
var _pose := 0.0
var _respawn := -1.0
var _item: Pickup
var _aim_error := Vector2.ZERO
var _hold_fire := 0.0
var _attacks_seen := 0
var _stuck_for := 0.0
var _stuck_check := 0.0
var _last_spot := Vector3.ZERO
var _raining := -1.0 # aiming a Rain of Arrows: how long until it lets go
var _next_stance := 0.0
var _away := false # walking away from what it fights, with a spirit or a low life
var _errand := "" # why it is going where it goes: fight, item, mend, fog, follow

## For everything that used to ask the bot itself.
var at: Vector3:
	get:
		return pawn.global_position if pawn else Vector3.ZERO
var down: bool:
	get:
		return pawn == null or pawn.dead
var hp: float:
	get:
		return pawn.hp if pawn else 0.0
var max_hp: float:
	get:
		return pawn.max_hp() if pawn else 1.0
var level: int:
	get:
		return pawn.level if pawn else 1
var kills: int:
	get:
		return pawn.kills if pawn else 0


func _init(owner_world: World, avatar: Avatar, info: Dictionary) -> void:
	world = owner_world
	body = avatar
	peer = avatar.peer
	name = "Bot%d" % (peer - Net.BOT_BASE)
	_class_id = str(info.get("class", "infantry"))
	if not ClassDefs.ALL.has(_class_id) or ClassDefs.ALL[_class_id].get("no_bots", false) or ClassDefs.disabled(_class_id):
		_class_id = "infantry"
	_smart = SMARTS[clampi(Game.difficulty, 0, SMARTS.size() - 1)]
	pawn = Player.new(world, peer)
	pawn.bot = self
	pawn.bot_class = _class_id
	pawn.bot_pet = ShopDefs.PETS[randi() % ShopDefs.PETS.size()]
	pawn.name = "BotBody%d" % (peer - Net.BOT_BASE)
	pawn.position = avatar.global_position


## The body goes in after this node, so each tick this decides first and the body moves after.
func _ready() -> void:
	world.add_child.call_deferred(pawn)
	world.bots.append(self)


func _exit_tree() -> void:
	world.bots.erase(self)
	if pawn and is_instance_valid(pawn):
		pawn.queue_free()


func _physics_process(delta: float) -> void:
	if not Net.in_game or Net._over or not is_instance_valid(body) or pawn == null or not pawn.is_inside_tree():
		return
	var was := world.begin_act(pawn)
	if pawn.dead:
		_stop()
		if _respawn >= 0.0:
			_respawn -= delta
			if _respawn < 0.0:
				_come_back()
	else:
		_live(delta)
	world.end_act(was)
	if not pawn.dead:
		body.teleport(pawn.global_position)
	_pose -= delta
	if _pose <= 0.0:
		_pose = POSE_EVERY
		Net.bot_pose(self)


# --- Being hit ----------------------------------------------------------------

## From the network: a zombie on the host, or a blow from someone. Friends cannot hurt it.
func hurt_by(amount: float, from: Vector3, zombie_id: int, by_peer: int) -> void:
	if pawn == null or pawn.dead:
		return
	if by_peer > 0:
		if not Net.bots_foes(by_peer, peer):
			return
		pawn.last_foe = by_peer
		pawn.hit_by = str(Net.roster.get(by_peer, {}).get("name", "another player"))
	else:
		pawn.last_foe = 0
	var z: Zombie = world.zombie_by_id(zombie_id) if zombie_id >= 0 else null
	pawn.hurt(amount, from, z)


func ignite(seconds: float) -> void:
	if pawn and not pawn.dead:
		pawn.ignite(seconds)


func apply_status(kind: int, seconds: float) -> void:
	if pawn and not pawn.dead:
		pawn.apply_status(kind, seconds)


## Its body fell. The score is kept on the host, and it comes back like a person does.
func on_fell() -> void:
	_stop()
	_target = null
	_item = null
	Net.note_bot_fell(peer, pawn.last_foe)
	if Net.fog_rules() and Net.lives_of(peer) <= 0:
		_respawn = -1.0
	else:
		_respawn = Net.FOG_RESPAWN if Net.fog_rules() else Net.RESPAWN_TIME


func _come_back() -> void:
	var spot := world.far_from_rivals_of(peer) if Net.pvp() else world.near_friend()
	pawn.respawn(spot)
	body.teleport(pawn.global_position)
	body.set_fallen(false)
	_item = null
	_path = PackedVector3Array()
	_raining = -1.0


func _stop() -> void:
	pawn.input_move = Vector2.ZERO
	pawn.input_fire = false
	pawn.input_jump = false


# --- Every tick ---------------------------------------------------------------

func _live(delta: float) -> void:
	var fog := world.fog
	if fog and not fog.contains(pawn.global_position):
		pawn.fog_hurt(ClosingFog.damage_at(world.director.elapsed) * delta)
		if pawn.dead:
			return
	_spend_points()
	_hold_fire -= delta
	if pawn.attack_count != _attacks_seen:
		_attacks_seen = pawn.attack_count
		var d := pawn.weapon_def()
		if not d.is_empty():
			_hold_fire = pawn.attack_interval(d) * (float(_smart["pace"]) - 1.0)
	_think -= delta
	if _think <= 0.0:
		_think = float(_smart["think"])
		_decide()
		_use_skills()
	_act(delta)


## Each level brings a choice, as for a person: one of the options on its path, its branch included.
func _spend_points() -> void:
	var tries := 0
	while pawn.points > 0 and tries < 12:
		tries += 1
		var step := pawn.next_step()
		var all := pawn.steps()
		if step >= all.size():
			return
		var options: Array = all[step]
		if options.is_empty() or not pawn.choose_ability(step, randi() % options.size()):
			return


## The closest enemy in sight, or a rival if there is one about. Then, where to go.
func _decide() -> void:
	var eye := pawn.eye_position()
	var zombie: Zombie = world.nearest_zombie(eye, SEE_ZOMBIES * float(_smart["see"]), true)
	var rival := _nearest_rival(SEE_RIVALS * float(_smart["see"]), true)
	_target = zombie
	if rival:
		var zombie_far := zombie.position.distance_to(pawn.global_position) if zombie else INF
		# People are worth more trouble than the undead.
		if rival.global_position.distance_to(pawn.global_position) * 0.7 < zombie_far:
			_target = rival
	var a := float(_smart["aim"])
	_aim_error = Vector2(randf_range(-a, a), randf_range(-a, a) * 0.5)
	_has_goal = true
	_item = _wanted_item()
	_decide_goal()
	_clear_way = _has_goal and pawn.global_position.distance_to(_goal) < 12.0 and world.has_line_of_sight(eye, _goal + Vector3.UP * 1.5)
	_manage_weapons()


func _decide_goal() -> void:
	var here := pawn.global_position
	var fog := world.fog
	_away = false
	_errand = "fight"
	if world.mist_storm and world.mist_storm.contains(here):
		_goal = world.mist_storm.escape(here)
		_errand = "evacuate"
	elif fog and not fog.contains(here, -3.0):
		_goal = fog.centre3()
		_errand = "fog"
	elif _item:
		_goal = _item.global_position
		_errand = "item"
	elif pawn.spirit_left > 0.0 and _target_alive():
		# Out of its body: away from the fight, to come back later where it is safe.
		_goal = here + (here - _target.global_position).normalized() * 10.0
		_away = true
	elif _backing_off():
		var friend := _nearest_friend()
		var away := (here - _target.global_position).normalized() * 12.0
		_goal = friend.global_position if friend else here + away
		_away = friend == null
	elif world.fort and pawn.wood > 0 and _gate_to_mend() != Vector3.INF and not (_target_alive() and _target.global_position.distance_to(here) < 6.0):
		_goal = _gate_to_mend()
		_errand = "mend"
	elif _target_alive():
		_goal = _target.global_position
	elif Net.pvp():
		var anyone := _nearest_rival(INF, false)
		if anyone:
			_goal = anyone.global_position
		elif fog:
			_goal = fog.centre3()
		else:
			_has_goal = false
	elif world.portals:
		if _explore == Vector3.INF or here.distance_to(_explore) < 8.0:
			var land := MapIslands.ISLANDS[randi_range(1, 8)]
			_explore = Vector3(land.x + 8, land.w, land.y)
		_goal = _explore
		_errand = "explore"
	else:
		var friend := _nearest_friend()
		_errand = "follow"
		_has_goal = friend != null and friend.global_position.distance_to(here) > FOLLOW_AT
		if friend:
			_goal = friend.global_position


## Too hurt to carry on with this fight.
func _backing_off() -> bool:
	return _target_alive() and float(_smart["retreat"]) > 0.0 and pawn.hp < pawn.max_hp() * float(_smart["retreat"])


func _gate_to_mend() -> Vector3:
	var best := Vector3.INF
	var worst := Fort.GATE_HP
	for g: Dictionary in world.fort.gates:
		if float(g["hp"]) < worst:
			worst = float(g["hp"])
			best = (g["at"] as Vector3) - (g["dir"] as Vector3) * 2.5
	return best


## What is worth walking to right now. With an enemy on top of it, only food is worth the risk.
func _wanted_item() -> Pickup:
	var hurt_badly := pawn.hp < pawn.max_hp() * 0.35
	var busy := _target_alive() and _target.global_position.distance_to(pawn.global_position) < 5.0
	var best: Pickup = null
	var best_score := 0.0
	for p: Pickup in world.pickups:
		var d := p.global_position.distance_to(pawn.global_position)
		var woodland_errand := p.kind == Pickup.Kind.WOOD and world.fort != null and pawn.wood < 6 and _gate_to_mend() != Vector3.INF
		if d > float(_smart["items"]) and not woodland_errand:
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
	match p.kind:
		Pickup.Kind.FOOD:
			return 4.0 if pawn.hp < pawn.max_hp() * 0.35 else (2.0 if pawn.hp < pawn.max_hp() * 0.7 else 0.0)
		Pickup.Kind.ARROWS:
			var shoots := WeaponDefs.uses_arrows(pawn.weapon_def()) or bool(pawn.class_def().get("ranged", false))
			return 2.0 if shoots and pawn.arrows < pawn.max_arrows() * 0.4 and not pawn.class_def().get("no_weapons", false) else 0.0
		Pickup.Kind.POWER:
			return 3.0 if PowerDefs.ALL[p.item_id]["familiar"] else 1.0
		Pickup.Kind.WOOD:
			return 2.0 if world.fort and pawn.wood < Fort.WOOD_MAX else 0.0
		Pickup.Kind.WEAPON:
			if not pawn.can_use(p.weapon_id) or pawn.carries(p.weapon_id) or (p.weapon_id == pawn.shun_weapon):
				return 0.0
			if pawn.has_empty_slot():
				return 1.5
			return 1.5 if weapon_value(WeaponDefs.ALL[p.weapon_id]) > weapon_value(pawn.weapon_def()) * 1.15 else 0.0
	return 0.0


static func weapon_value(d: Dictionary) -> float:
	if d.is_empty():
		return 0.0
	return float(d.get("power", 1.0)) * minf(float(d.get("max_hits", 1)), 3.0) / float(d["rate"]) * (1.3 if d["kind"] != WeaponDefs.Kind.MELEE else 1.0)


func _nearest_rival(reach: float, need_sight: bool) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	var eye := pawn.eye_position()
	for t: Target in world.rivals_near(pawn.global_position, reach):
		if t.is_unseen():
			continue
		var d := t.global_position.distance_to(pawn.global_position)
		if d < best_d and (not need_sight or world.has_line_of_sight(eye, t.eye_position())):
			best_d = d
			best = t
	return best


## People first: a bot keeps close to the humans on its side, and to another bot if there are none.
func _nearest_friend() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for t: Target in world.friends_near(pawn.global_position, INF):
		var d := t.global_position.distance_to(pawn.global_position) * (3.0 if Net.is_bot(world.peer_of(t)) else 1.0)
		if d < best_d:
			best_d = d
			best = t
	return best


func _target_alive() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	return (_target as Zombie).is_alive() if _target is Zombie else not (_target as Target).dead


func _target_point() -> Vector3:
	return (_target as Zombie).centre() if _target is Zombie else _target.global_position + Vector3.UP * 1.1


# --- Weapons -------------------------------------------------------------------

## Bows from afar and blades up close, when it carries both. A better weapon on the ground is taken.
func _manage_weapons() -> void:
	var p := pawn
	var d := p.weapon_def()
	var other: Variant = p.slots[1 - p.current]
	var other_def: Dictionary = WeaponDefs.ALL.get(other, {}) if other else {}
	if not d.is_empty() and WeaponDefs.uses_arrows(d) and p.arrows <= 0 and not other_def.is_empty():
		p.switch_weapon()
		return
	if p.nearby_weapon and is_instance_valid(p.nearby_weapon) and _worth(p.nearby_weapon) > 0.0:
		p.take_nearby_weapon()
		return
	if other_def.is_empty() or not _target_alive():
		return
	var dist := _target.global_position.distance_to(p.global_position)
	var ranged_now: bool = not d.is_empty() and d["kind"] != WeaponDefs.Kind.MELEE
	var ranged_other: bool = other_def["kind"] != WeaponDefs.Kind.MELEE and (not WeaponDefs.uses_arrows(other_def) or p.arrows > 0)
	if ranged_now and dist < 3.5 and not ranged_other:
		p.switch_weapon()
	elif not ranged_now and ranged_other and dist > 7.0:
		p.switch_weapon()


func _reach() -> float:
	var d := pawn.weapon_def()
	if d.is_empty():
		return 0.0
	if d["kind"] == WeaponDefs.Kind.MELEE:
		return pawn.melee_stats(d)["range"] - MELEE_SLACK
	return minf(float(d.get("range", SHOT_REACH)) * pawn.m("ranged_power"), SHOT_REACH)


# --- Acting --------------------------------------------------------------------

func _act(delta: float) -> void:
	pawn.input_fire = false
	var here := pawn.global_position
	var move := Vector3.ZERO
	var has_target := _target_alive()
	var want_move := _has_goal
	if _raining >= 0.0:
		_raining -= delta
		if _raining < 0.0:
			pawn.art_release()
	if has_target and not _away and _raining < 0.0:
		var aim := _target_point()
		_face(aim, true)
		var d := pawn.weapon_def()
		var dist := Vector2(_target.global_position.x - here.x, _target.global_position.z - here.z).length()
		var edge: float = (_target as Zombie).body_radius() if _target is Zombie else 0.4
		var reach := _reach()
		var ranged: bool = not d.is_empty() and d["kind"] != WeaponDefs.Kind.MELEE
		if dist <= reach + edge and _hold_fire <= 0.0 and pawn.spirit_left <= 0.0 and (not ranged or world.has_line_of_sight(pawn.eye_position(), aim)):
			pawn.input_fire = true
		var stop_at := reach * 0.6 if ranged else 1.1
		# An Iron Mountain lets them come, to grow its stone skin.
		if pawn.has_flag("iron_mountain") and not ranged and dist < 7.0:
			stop_at = 7.0
		if _errand == "fight":
			if dist <= stop_at:
				want_move = false
			if ranged and bool(_smart["kite"]) and dist < 4.0:
				_goal = here + (here - _target.global_position).normalized() * 6.0
				want_move = true
	if want_move:
		move = _walk_dir(delta)
		if not has_target or _away:
			if move != Vector3.ZERO:
				_face(here + move * 4.0 + Vector3.UP * 1.5, false)
	_set_move(move)
	_check_stuck(delta, move != Vector3.ZERO)


## Turns its head toward a point, a little off by its difficulty when shooting.
func _face(point: Vector3, aiming: bool) -> void:
	var eye := pawn.eye_position()
	var to := point - eye
	var flat := Vector2(to.x, to.z).length()
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, maxf(flat, 0.01))
	if aiming:
		yaw += _aim_error.x
		pitch += _aim_error.y
		var d := pawn.weapon_def()
		if not d.is_empty() and WeaponDefs.uses_arrows(d):
			# Arrows drop on the way, so aim a little high.
			var speed := float(d.get("speed", 40.0)) * pawn.m("ranged_power")
			var flight := flat / maxf(speed, 1.0)
			pitch += atan2(maxf(0.5 * float(d.get("gravity", 0.0)) * flight * flight - 0.5 * flight, 0.0), maxf(flat, 0.01))
	else:
		pitch = 0.0
	pawn.yaw = yaw
	pawn.rotation.y = yaw
	pawn.pitch = clampf(pitch, deg_to_rad(-82), deg_to_rad(82))
	pawn.head.rotation.x = pawn.pitch


## The way it means to go becomes a stick pushed that way, as a person's thumb would.
func _set_move(world_dir: Vector3) -> void:
	if world_dir == Vector3.ZERO:
		pawn.input_move = Vector2.ZERO
		return
	var local := pawn.global_basis.inverse() * world_dir
	pawn.input_move = Vector2(local.x, local.z).limit_length(1.0)


func _walk_dir(delta: float) -> Vector3:
	var here := pawn.global_position
	_repath -= delta
	_no_shortcut -= delta
	var aim := _goal
	if world.portals:
		aim = world.portals.waypoint(here, _goal)
	var crossing := false
	if world.fort:
		if _fort_cross != Vector3.INF and Vector2(_fort_cross.x - here.x, _fort_cross.z - here.z).length() > 0.8:
			aim = _fort_cross
			crossing = true
		else:
			_fort_cross = Vector3.INF
			if world.fort.inside(here) != world.fort.inside(_goal):
				var best := INF
				var door := Vector3.ZERO
				var outward := Vector3.ZERO
				for side in 4:
					var dir: Vector3 = Fort.DIRS[side]
					var point: Vector3 = dir * Fort.HALF + Vector3(dir.z, 0, -dir.x) * Fort.DOORS[side]
					var cost := here.distance_to(point) + _goal.distance_to(point)
					if cost < best:
						best = cost
						door = point
						outward = dir
				var from_side := -1.0 if world.fort.inside(here) else 1.0
				var approach := door + outward * from_side * 4.0
				aim = approach
				if Vector2(approach.x - here.x, approach.z - here.z).length() < 1.3:
					_fort_cross = door - outward * from_side * 4.0
					aim = _fort_cross
					crossing = true
	var direct := crossing or (_clear_way and _no_shortcut <= 0.0 and aim == _goal)
	if not direct and _repath <= 0.0:
		_repath = REPATH_EVERY
		_path = world.grid.route(here, aim)
		_path_at = 0
	var next := aim
	if not direct and _path_at < _path.size():
		next = _path[_path_at]
		if Vector2(next.x - here.x, next.z - here.z).length() < 0.7:
			_path_at += 1
			if _path_at < _path.size():
				next = _path[_path_at]
	var way := Vector3(next.x - here.x, 0.0, next.z - here.z)
	if way.length() < 0.3:
		return Vector3.ZERO
	return way.normalized()


## A body can catch on a corner or a fence. Jump first, then find another way, and only as a last
## resort step onto the next point of its path.
func _check_stuck(delta: float, moving: bool) -> void:
	_stuck_check -= delta
	if _stuck_check > 0.0:
		return
	_stuck_check = 0.5
	var here := pawn.global_position
	var moved := Vector2(here.x - _last_spot.x, here.z - _last_spot.z).length()
	_last_spot = here
	if not moving or moved > 0.6 or pawn._is_moved_by_mist():
		_stuck_for = 0.0
		return
	_stuck_for += 0.5
	if _stuck_for >= 1.0:
		pawn.input_jump = true
	if _stuck_for >= 2.0:
		_no_shortcut = 3.0
		_repath = 0.0
	if _stuck_for >= 5.0 and _path_at < _path.size():
		var spot := _path[_path_at]
		pawn.global_position = Vector3(spot.x, world.ground_at(spot) + 0.1, spot.z)
		pawn.velocity = Vector3.ZERO
		_stuck_for = 0.0


# --- Abilities -----------------------------------------------------------------

func _enemies_within(radius: float) -> int:
	var n := world.zombies_near(pawn.global_position, radius, 12).size()
	return n + world.rivals_near(pawn.global_position, radius).size()


## The same buttons a person has, pressed when they would help.
func _use_skills() -> void:
	var p := pawn
	if p.dead or p.frozen_left > 0.0 or randf() > float(_smart["skills"]):
		return
	var has_target := _target_alive()
	var dist := _target.global_position.distance_to(p.global_position) if has_target else INF
	if p.horse_ready() and not p.is_riding() and has_target and dist < 30.0:
		p.mount()
		return
	if p.has_burst() and p.burst_cd_left <= 0.0 and p.mana >= p.burst_cost() and _enemies_within(p.m("burst_radius")) >= (1 if p.hp < p.max_hp() * 0.5 else 2):
		p.use_burst()
		return
	if not p.has_art() or p.art_cd_left > 0.0 or p._cast_kind != "" or p.aiming_art:
		return
	if p.spirit_left > 0.0:
		# Back to its body once it is safe, or the spirit's time is nearly up.
		if p.spirit_left < 0.8 or not has_target or dist > 12.0:
			p.use_art()
		return
	if p.mana < p.art_cost():
		return
	var low := p.hp < p.max_hp() * 0.4
	var near := _enemies_within(4.5)
	var kind := "stance" if p.class_id == "adept" else ("ki_blast" if p.class_id == "monk" and p.spec_id == "" else p.spec_id)
	if p.class_id == "bandit" and p.spec_id == "":
		kind = "into_shadows"
	if p.class_id == "cartographer":
		kind = "beacon"
	match kind:
		"beacon":
			# A new marker where the fight is, or (for a Pathfinder) on new ground when a find is due.
			var survey: SurveyNet = world.surveys.get(p.net_id()) if world.surveys.has(p.net_id()) else null
			var fresh_ground := survey == null or not is_instance_valid(survey) or not survey.near_beacon(p.global_position, 9.0)
			var find_due := p.spec_id == "pathfinder" and p.find_rest_left <= 0.0 and (p.last_find == Vector3.INF or p.last_find.distance_to(p.global_position) > CartographerKit.FIND_GAP + p.m("find_gap"))
			if fresh_ground and ((has_target and dist < 20.0) or find_due):
				p.use_art()
		"into_shadows":
			if p.invis_left <= 0.0 and p.can_vanish() and ((low and near > 0) or (has_target and dist < 8.0)):
				p.use_art()
		"thief":
			if has_target and dist < BanditKit.STEAL_RANGE + p.m("steal_range") and BanditKit.steal_target(p) != null:
				p.use_art()
		"mercenary":
			if near >= 2 or (low and near > 0):
				p.use_art()
		"highwayman":
			if has_target and dist < 15.0:
				_face(_target_point(), false)
				p.use_art()
		"ki_blast":
			if near >= 2 or (near >= 1 and p.hp < p.max_hp() * 0.7):
				p.use_art()
		"stance":
			_next_stance -= float(_smart["think"])
			if (p._void_is_ready() and has_target) or (has_target and dist < 6.0 and _next_stance <= 0.0):
				_next_stance = randf_range(4.0, 8.0)
				p.use_art()
		"leaper":
			if low and near > 0 and has_target:
				_face(p.global_position * 2.0 - _target.global_position + Vector3.UP * 1.5, false)
				p.use_art()
			elif has_target and dist > 7.0 and dist < 16.0:
				_face(_target_point(), false)
				p.use_art()
		"bo_master":
			if has_target and dist > 4.0 and dist < 9.5:
				_face(_target_point(), false)
				p.use_art()
		"rift":
			if has_target and dist < WorldLight.RIFT_REACH and not p._rift_candidates().is_empty():
				p.use_art()
		"summoner", "inventor":
			if has_target and dist < 16.0:
				if kind == "inventor":
					_face_throw(17.0)
				p.use_art()
		"guardian":
			if (low and near > 0) or near >= 3:
				p.use_art()
		"pyromaniac":
			if has_target and dist > 4.5 and dist < 22.0:
				_face_throw(17.0 * p.m("bomb_throw"))
				p.use_art()
		"illusionist", "spirit_walker":
			if low and near > 0:
				if has_target:
					_face(p.global_position * 2.0 - _target.global_position + Vector3.UP * 1.5, false)
				p.use_art()
		"iron_mountain":
			var top := Player.SKIN_UNMOVED if p.has_flag("unmoved") else Player.SKIN_MAX
			var radius := 4.0 + 5.0 * clampf(p.stone_skin / top, 0.0, 1.0)
			if p.stone_skin >= Player.SKIN_STRONG and _enemies_within(radius) >= 1:
				p.use_art()
		"apothecary":
			if p.hp < p.max_hp() * 0.55 or p.poison_left > 0.0 or p.bleed_left > 0.0 or _friend_needs_help():
				p.use_art()
		"sharpshooter":
			_aim_rain()
		"trapper":
			if has_target and dist < 12.0:
				p.use_art()
		"duelist":
			if has_target and dist < 3.0:
				p.use_art()
		"shadow":
			if (low or (has_target and dist < 6.0)) and p.shadow_kills >= Player.SHROUD_KILLS:
				p.use_art()
		_:
			if has_target and dist < 12.0:
				p.use_art()


## A friend close by who is badly hurt, for an Apothecary's tonic.
func _friend_needs_help() -> bool:
	for t: Target in world.friends_near(pawn.global_position, 8.0):
		if t is Avatar and (t as Avatar).hp_fraction < 0.5:
			return true
		if t is Player and (t as Player).hp < (t as Player).max_hp() * 0.5:
			return true
	return false


## A Rain of Arrows goes where the most enemies are, aimed and let go as a person would.
func _aim_rain() -> void:
	if not pawn.has_item("rain_of_arrows") or pawn.arrows < Player.RAIN_ARROWS:
		return
	var best := Vector3.INF
	var best_n := 2
	for z: Zombie in world.zombies_near(pawn.global_position, Player.RAIN_REACH - 2.0, 24):
		var n := world.zombies_near(z.position, Player.RAIN_RADIUS, 24).size() + world.rivals_near(z.position, Player.RAIN_RADIUS).size()
		if n > best_n and z.position.distance_to(pawn.global_position) > 6.0:
			best_n = n
			best = z.position
	for r: Target in world.rivals_near(pawn.global_position, Player.RAIN_REACH - 2.0):
		if best == Vector3.INF and r.global_position.distance_to(pawn.global_position) > 6.0:
			best = r.global_position
	if best == Vector3.INF:
		return
	_face(best, false)
	var eye := pawn.eye_position()
	var to := best - eye
	pawn.pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), deg_to_rad(-82), deg_to_rad(82))
	pawn.head.rotation.x = pawn.pitch
	pawn.art_aim()
	_raining = 0.3


## Faces the target with the arc a thrown thing needs to land on it. Things leave the hand a little
## upward, so that is taken off.
func _face_throw(speed: float) -> void:
	if not _target_alive():
		return
	var here := pawn.global_position
	var flat := Vector2(_target.global_position.x - here.x, _target.global_position.z - here.z).length()
	_face(_target.global_position, false)
	var reach := clampf(14.0 * flat / (speed * speed), -1.0, 1.0)
	var arc := 0.5 * asin(reach)
	pawn.pitch = clampf(arc - atan(0.2), deg_to_rad(-30), deg_to_rad(60))
	pawn.head.rotation.x = pawn.pitch
