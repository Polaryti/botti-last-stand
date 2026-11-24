class_name HarpoonerKit
extends RefCounted
## The Harpooner: Haul on the ability button whatever the path, and the path's own ability on a second
## button beside it (Blood in the Water, Rig a Line or Great Harpoon). The Rigger's lines themselves
## live in RigLine, and the rope everyone sees in HaulRope.

# The class
const RETURN := 4.0 # the Whaler's Harpoon comes back to a Harpooner's hand by itself after this long
# Haul
const HAUL_RANGE := 18.0
const HAUL_CONE := 22.0 # degrees either side of where you look
const HAUL_DAMAGE := 20.0
const HAUL_STUN := 0.6
const HAUL_FRONT := 1.8 # where it lands: this far in front of you
const HAUL_SPEED := 16.0 # metres a second, the way a rope hauls
const HAUL_STOP := 1.6 # pulled to something too big to move, you stop this far from it
const HAUL_STAGGER := 0.4 # ...and it is off balance this long
# Reaver
const BLOOD_TIME := 6.0
const BLOOD_HEAL := 3.0
const BLOOD_SPEED := 0.15
const HAUL_MARK := 1.3
const HAUL_MARK_TIME := 4.0
const BLOOD_GUARD := 0.15
const SLAM_DAMAGE := 40.0
const SLAM_RADIUS := 3.0
const REFUND := 4.0
const RED_TIDE_REACH := 12.0
# Rigger
const RIG_REACH := 14.0
const RIG_TIME := 12.0
const RIG_LINES := 2
const TRIP_STUN := 1.0
const TRIP_SLOW := 2.0
const BARB_DAMAGE := 25.0
const BARB_BLEED := Vector2(8.0, 3.0) # damage a second, and seconds
const SNARE := 1.5
const LIFELINE_SPEED := 0.25
const LIFELINE_TIME := 3.0
const CROWS_NEST := 0.25
const CROWS_REACH := 4.0
# Leviathan Hunter
const GREAT_DAMAGE := 90.0
const GREAT_PIN := 1.5
const GREAT_RANGE := 34.0
const GREAT_SPEED := 36.0
const MARK := 1.2
const MARK_TIME := 8.0
const BIG_GAME := 0.3
const BANE := 1.4
const FLENSE_HEAL := 10.0
const MARK_BLEED := Vector2(8.0, 4.0)

const ARTS := {
	"": {"name": "Haul", "cost": 0.0, "cast": 0.12, "cd": 8.0, "icon": "chain"},
	"reaver": {"name": "Blood in the Water", "cost": 0.0, "cast": 0.2, "cd": 20.0, "icon": "drop", "anim": "Stance"},
	"rigger": {"name": "Rig a Line", "cost": 0.0, "cast": 0.2, "cd": 12.0, "icon": "rope"},
	"leviathan_hunter": {"name": "Great Harpoon", "cost": 0.0, "cast": 0.35, "cd": 14.0, "icon": "harpoon"},
}
const BLOOD := Color(0.78, 0.12, 0.12)


## Haul, on the ability button.
static func art(_p: Player) -> Dictionary:
	return ARTS[""]


## The path's own ability, on a second button beside Haul.
static func path_art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, {}) if p.spec_id != "" else {}


static func cast(p: Player) -> void:
	haul(p)


static func cast_path(p: Player) -> void:
	match p.spec_id:
		"reaver": blood_in_the_water(p)
		"rigger": rig_a_line(p)
		"leviathan_hunter": great_harpoon(p)


## How long the Whaler's Harpoon takes to come back to this hand by itself.
static func harpoon_return(p: Player, tethered: float) -> float:
	if p.class_id != "harpooner":
		return tethered
	return maxf(1.0, RETURN + p.m("harpoon_back"))


# --- Haul ----------------------------------------------------------------------

## What Haul would catch: the enemy nearest the middle of your view, in reach and not behind a wall.
## A rival player first if one is as near the middle as a creature.
static func haul_target(p: Player) -> Node3D:
	var reach := HAUL_RANGE + p.m("haul_range")
	var eye := p.eye_position()
	var look := -p.camera.global_basis.z if p.camera else -p.global_basis.z
	var best: Node3D = null
	var best_score := INF
	var limit := cos(deg_to_rad(HAUL_CONE))
	for z: Zombie in p.world.zombies_near(p.global_position, reach, 40):
		if not z.is_alive():
			continue
		var to := z.centre() - eye
		var dist := to.length()
		if dist < 0.5 or dist > reach + z.body_radius():
			continue
		var along := (to / dist).dot(look)
		if along < limit or not p.world.has_line_of_sight(eye, z.centre()):
			continue
		var score := (1.0 - along) * 40.0 + dist * 0.15
		if score < best_score:
			best_score = score
			best = z
	var was := p.world.begin_act(p)
	for r: Target in p.world.rivals_near(p.global_position, reach):
		var to := r.global_position + Vector3.UP - eye
		var dist := to.length()
		if dist < 0.5:
			continue
		var along := (to / dist).dot(look)
		if along < limit or not p.world.has_line_of_sight(eye, r.global_position + Vector3.UP):
			continue
		var score := (1.0 - along) * 40.0 + dist * 0.15 - 0.5
		if score < best_score:
			best_score = score
			best = r
	p.world.end_act(was)
	return best


## Whether something can be hauled in, or is so big that the Harpooner is hauled to it instead.
static func too_big(t: Node3D) -> bool:
	return t is Zombie and not (t as Zombie).draggable()


static func haul(p: Player) -> void:
	var t := haul_target(p)
	if t == null:
		p.say("Nothing to haul")
		p.art_cd_left = 0.5
		return
	var here := p.global_position
	var ahead := -p.global_basis.z
	ahead = Vector3(ahead.x, 0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.1 else Vector3.FORWARD
	var there: Vector3 = t.global_position
	var dist := Vector2(there.x - here.x, there.z - here.z).length()
	var rope_life := dist / HAUL_SPEED + 0.15
	show_rope(p.world, p, t)
	if Net.active():
		Net.haul_rope(p.net_id(), t)
	p.world.sfx_at("haul_throw", here, -3.0)
	p._swing_time = 0.3
	p._swing = 0.0
	p._swing_keys = "throw"
	p._noise(4.0)
	var was := p.world.begin_act(p)
	if t is Zombie:
		var z := t as Zombie
		var dmg := p.modify_damage(z, HAUL_DAMAGE * p.damage_multiplier())
		if too_big(z):
			# Too big to move: the rope hauls the Harpooner to it, and it is caught off balance.
			p.haul_self_to(z.position, HAUL_STOP + z.body_radius())
			z.stun(HAUL_STAGGER)
			if p.has_flag("haul_slam"):
				p.slam_on_arrival = true
		else:
			var spot := here + ahead * HAUL_FRONT
			spot.y = p.world.ground_at(spot)
			z.haul_to(spot)
			z.stun(HAUL_STUN + p.m("haul_stun") + rope_life)
		p.world.damage_zombie(z, dmg, Vector3.ZERO, 0.0, z.centre(), false)
		_after_haul(p, z)
	elif t is Target:
		var spot := here + ahead * HAUL_FRONT
		Net.hauled(p.world.peer_of(t as Target), spot, p.net_id())
		p.world.hit_rival(t as Target, HAUL_DAMAGE * p.damage_multiplier(), here)
		p.status_on(p.world.peer_of(t as Target), Net.Status.STUN, HAUL_STUN + p.m("haul_stun"))
	p.world.end_act(was)
	p.world.sfx_at("hook_catch", there, -2.0)


## What a Haul leaves behind on what it caught: bleeding, a mark, and a note for No Quarter.
static func _after_haul(p: Player, z: Zombie) -> void:
	if p.has_flag("barbed"):
		z.add_dot(MARK_BLEED.x, MARK_BLEED.y, true)
	if p.spec_id == "reaver":
		z.mark(HAUL_MARK, HAUL_MARK_TIME)
	p.hauled[z.get_instance_id()] = p.world.now + HAUL_MARK_TIME


## Everyone's rope, on this phone: from the Harpooner's hand to what it caught.
static func show_rope(world: World, from: Node3D, to: Node3D) -> void:
	if from == null or to == null:
		return
	var there: Vector3 = (to as Zombie).centre() if to is Zombie else to.global_position + Vector3.UP
	var dist := Vector2(there.x - from.global_position.x, there.z - from.global_position.z).length()
	HaulRope.create(world, from, from.global_position + Vector3.UP * 1.2, to, there, dist / HAUL_SPEED + 0.15)


## Grapple Slam: pulled all the way to something big, the Harpooner lands in a slam.
static func land_slam(p: Player) -> void:
	var at := p.global_position
	var was := p.world.begin_act(p)
	for z: Zombie in p.world.zombies_near(at, SLAM_RADIUS, 12):
		if z.is_alive():
			p.world.damage_zombie(z, p.modify_damage(z, SLAM_DAMAGE * p.damage_multiplier()), z.position - at, 3.0, z.centre(), false)
	for r: Target in p.world.rivals_near(at, SLAM_RADIUS):
		p.world.hit_rival(r, SLAM_DAMAGE * p.damage_multiplier(), at)
	p.world.end_act(was)
	p.world.fx_blast(at + Vector3.UP * 0.2, SLAM_RADIUS * 0.7, Color(0.85, 0.75, 0.55, 0.45))
	p.world.sfx_at("anchor_slam", at, -2.0)
	p.shake(0.5)


# --- Reaver: Blood in the Water --------------------------------------------------

static func blood_time(p: Player) -> float:
	return BLOOD_TIME + p.m("blood_time")


static func blood_in_the_water(p: Player) -> void:
	var secs := blood_time(p)
	p._act({"do": "buff", "key": "blood_water", "stat": "speed", "val": BLOOD_SPEED, "secs": secs}, {})
	if p.has_flag("blood_guard"):
		p._act({"do": "buff", "key": "blood_guard", "stat": "damage_taken", "val": -BLOOD_GUARD, "secs": secs}, {})
	p.say("Blood in the Water!")
	p.world.fx_ring(p.global_position, 3.0, BLOOD)
	p.world.sfx_at("blood_water", p.global_position, -3.0)


static func in_blood(p: Player) -> bool:
	return p._buffs.has("blood_water")


## A blow that lands, by melee or by a shot.
static func on_blow(p: Player) -> void:
	if in_blood(p) and p.hp < p.max_hp():
		p.heal(BLOOD_HEAL)


# --- Rigger: Rig a Line ----------------------------------------------------------

static func line_bits(p: Player) -> int:
	var bits := 0
	for i in RigLine.FLAGS.size():
		if p.has_flag(RigLine.FLAGS[i]):
			bits |= 1 << i
	return bits


## Where the far end of a line goes: up to the reach ahead, along the ground, short of any wall.
static func line_end(p: Player) -> Vector3:
	var ahead := -p.global_basis.z
	ahead = Vector3(ahead.x, 0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.1 else Vector3.FORWARD
	var end := p.leap_landing(p.global_position, ahead, RIG_REACH + p.m("line_reach"))
	end.y = p.world.ground_at(end)
	return end


static func rig_a_line(p: Player) -> void:
	var from := p.global_position
	from.y = p.world.ground_at(from)
	var to := line_end(p)
	if Vector2(to.x - from.x, to.z - from.z).length() < 2.0:
		p.say("No room for a line")
		p.path_art_cd_left = 0.5
		return
	var secs := RIG_TIME + p.m("line_time")
	var bits := line_bits(p)
	var keep := RIG_LINES + int(p.m("lines"))
	var cradle := p.has_flag("cats_cradle")
	p.world.rig_line(p.net_id(), from, to, secs, bits, keep, cradle)
	if Net.active():
		Net.rig_line(p.net_id(), from, to, secs, bits, keep, cradle)
	p.world.sfx_at("rig_line", from, -3.0)
	p._swing_time = 0.3
	p._swing = 0.0
	p._swing_keys = "throw"


## Crow's Nest: shots strike harder from beside one of your own lines.
static func by_own_line(p: Player) -> bool:
	if not p.has_flag("crows_nest"):
		return false
	for line: RigLine in p.world.rig_lines:
		if is_instance_valid(line) and line.owner_peer == p.net_id() and not line.cradle and line.distance_to(p.global_position) <= CROWS_REACH:
			return true
	return false


# --- Leviathan Hunter ----------------------------------------------------------------

static func great_harpoon(p: Player) -> void:
	var dir := p.world.assist_aim(p.camera.global_position, -p.camera.global_basis.z, GREAT_RANGE)
	var start := p.camera.global_position + dir * 0.6 + p.camera.global_basis.x * 0.12 + Vector3.DOWN * 0.08
	var dmg := GREAT_DAMAGE * (1.0 + p.m("great_damage")) * p._ranged_mult()
	p.world.spawn_great_harpoon(p, start, dir * GREAT_SPEED + Vector3.UP * 0.4, GREAT_RANGE, dmg)
	p.world.sfx_at("great_harpoon", start, -1.0)
	p._kick = 1.0
	p._swing_time = 0.35
	p._swing = 0.0
	p._swing_keys = "throw"
	p._noise(6.0)


static func mark_time(p: Player) -> float:
	return MARK_TIME + p.m("mark_time")


## What a Leviathan Hunter's harpoons strike: marked for everyone, and with the tree, bleeding and
## shown through walls to the Hunter.
static func mark(p: Player, z: Zombie) -> void:
	if p.spec_id != "leviathan_hunter" or not z.is_alive():
		return
	var big := z.is_boss() or z.is_miniboss()
	z.mark(BANE if big and p.has_flag("bane") else MARK, mark_time(p))
	if p.has_flag("mark_bleed"):
		z.add_dot(MARK_BLEED.x, mark_time(p), true)
	if p.has_flag("mark_reveal"):
		z.reveal_left = maxf(z.reveal_left, mark_time(p))
	p.hunted[z.get_instance_id()] = p.world.now + mark_time(p)


## A Whaler's Harpoon thrown by a Harpooner, or a Great Harpoon, strikes a creature.
static func on_harpoon_hit(p: Player, z: Zombie) -> void:
	if p.has_flag("barbed"):
		z.add_dot(MARK_BLEED.x, MARK_BLEED.y, true)
	mark(p, z)


## Whale Oil: the Hunter's own blows on bosses and minibosses.
static func damage_scale(p: Player, z: Zombie) -> float:
	var scale := 1.0
	if p.has_flag("big_game") and (z.is_boss() or z.is_miniboss()):
		scale *= 1.0 + BIG_GAME
	return scale


# --- Kills -----------------------------------------------------------------------

static func on_kill(p: Player, z: Zombie) -> void:
	var id := z.get_instance_id()
	var now := p.world.now
	if p.has_flag("haul_refund") and float(p.hauled.get(id, -1.0)) >= now:
		p.art_cd_left = maxf(0.0, p.art_cd_left - REFUND)
	if p.has_flag("flensing") and float(p.hunted.get(id, -1.0)) >= now and p.hp < p.max_hp():
		p.heal(FLENSE_HEAL)
	p.hauled.erase(id)
	p.hunted.erase(id)
	if p.has_flag("red_tide") and in_blood(p):
		_red_tide(p, z.position)


## Red Tide: in Blood in the Water, every kill hauls the next one in.
static func _red_tide(p: Player, from: Vector3) -> void:
	var best: Zombie = null
	for z: Zombie in p.world.zombies_near(p.global_position, RED_TIDE_REACH, 20):
		if z.is_alive() and z.draggable() and z.position.distance_to(from) > 0.3 and (best == null or z.position.distance_to(p.global_position) < best.position.distance_to(p.global_position)):
			best = z
	if best == null:
		return
	var ahead := best.position - p.global_position
	ahead = Vector3(ahead.x, 0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.1 else Vector3.FORWARD
	var spot := p.global_position + ahead * HAUL_FRONT
	spot.y = p.world.ground_at(spot)
	show_rope(p.world, p, best)
	if Net.active():
		Net.haul_rope(p.net_id(), best)
	best.haul_to(spot)
	best.stun(HAUL_STUN + p.m("haul_stun"))
	_after_haul(p, best)
	p.world.sfx_at("hook_catch", best.position, -3.0)
