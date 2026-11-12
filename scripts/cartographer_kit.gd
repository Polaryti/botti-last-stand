class_name CartographerKit
extends RefCounted
## The Cartographer's ability: planting linked beacons, and what each profession makes of them.
## The beacons themselves, their lines and everything they do live in SurveyNet.

const BEACONS := 3 # at a time; planting one more pulls up the oldest
const LINK := 24.0 # beacons this far apart or closer are linked by a line
const RADIUS := 4.0 # friends within this of a beacon run faster
const SPEED := 0.1 # how much faster
const LINE_HEAL := 2.0 # health a second for friends on a line
const MARK := 10.0 # enemies this close to a beacon are marked for the Cartographer's side
const STAR_BONUS := 0.2 # damage for friends inside a constellation
const STAR_DAMAGE := 15.0
const GATE_SPEED := 0.3
const GATE_REST := 3.0
const FIND_REST := 30.0
const FIND_GAP := 15.0
const LANTERN_SPEED := 1.15
const PLANT_AHEAD := 1.6 # metres in front of you
const FINDS := ["machete", "bolas", "lantern"]

const ARTS := {
	"": {"name": "Plant Beacon", "cost": 0.0, "cast": 0.25, "cd": 5.0, "icon": "beacon", "anim": "Stance"},
	"star_reader": {"name": "Set a Star Stone", "cost": 0.0, "cast": 0.25, "cd": 5.0, "icon": "star", "anim": "Stance"},
	"worlds_traveler": {"name": "Raise a Waygate", "cost": 0.0, "cast": 0.25, "cd": 5.0, "icon": "waygate", "anim": "Stance"},
	"pathfinder": {"name": "Plant Beacon", "cost": 0.0, "cast": 0.25, "cd": 5.0, "icon": "compass", "anim": "Stance"},
}


static func art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, ARTS[""])


static func kind_of(spec: String) -> String:
	return {"star_reader": "stars", "worlds_traveler": "gates", "pathfinder": "finds"}.get(spec, "")


## Everything the beacons need to know about the one who planted them, sent with each beacon so
## every phone's copy behaves alike.
static func config(p: Player) -> Dictionary:
	var bits := 0
	for i in SurveyNet.FLAGS.size():
		if p.has_flag(SurveyNet.FLAGS[i]):
			bits |= 1 << i
	return {"kind": kind_of(p.spec_id), "max": BEACONS + int(p.m("beacons")), "link": LINK + p.m("link_range"),
		"radius": RADIUS + p.m("beacon_radius"), "heal": LINE_HEAL + p.m("line_heal"), "mark": MARK + p.m("mark_range"),
		"bonus": STAR_BONUS + p.m("star_bonus"), "power": STAR_DAMAGE * (1.0 + p.m("star_power")),
		"gate_speed": GATE_SPEED + p.m("gate_speed"), "gate_rest": maxf(0.5, GATE_REST + p.m("gate_rest")), "gate_heal": p.m("gate_heal"), "bits": bits}


## After learning a skill, the beacons already standing are told, on every phone.
static func retune(p: Player) -> void:
	var cfg := config(p)
	p.world.refresh_survey(p.net_id(), cfg)
	if Net.active():
		Net.survey_settings(p.net_id(), cfg)


## Where the next beacon goes: a little in front of the Cartographer, on the ground.
static func plant_point(p: Player) -> Vector3:
	var ahead := -p.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
	return p.global_position + ahead * PLANT_AHEAD


## Whether a beacon planted now would stand alone: other beacons will still be up after it is planted
## (the oldest is pulled up when the set is full), yet none is close enough to link with it. The first
## beacon, or one that starts a new profession's set, has nothing to link with and is never "alone".
static func would_stand_alone(p: Player) -> bool:
	var found: Variant = p.world.surveys.get(p.net_id())
	if found == null or not is_instance_valid(found):
		return false
	var survey := found as SurveyNet
	if survey.kind() != kind_of(p.spec_id):
		return false
	var cfg := config(p)
	var standing := survey.beacons.duplicate()
	while not standing.is_empty() and standing.size() >= int(cfg["max"]):
		standing.pop_front()
	if standing.is_empty():
		return false
	var at := plant_point(p)
	for b: Dictionary in standing:
		if SurveyNet._flat(at, b["at"]) <= float(cfg["link"]):
			return false
	return true


static func cast(p: Player) -> void:
	var at := plant_point(p)
	at.y = p.world.ground_at(at)
	var cfg := config(p)
	p.world.plant_beacon(p.net_id(), at, cfg, p.yaw)
	if Net.active():
		Net.beacon(p.net_id(), at, cfg, p.yaw)
	# Planting a Waygate in front of you does not send you through it.
	p.gate_rest_left = maxf(p.gate_rest_left, 0.8)
	if p.spec_id == "pathfinder":
		_try_find(p, at)


## A Pathfinder's beacon on new ground unearths something only a Pathfinder can use.
static func _try_find(p: Player, at: Vector3) -> void:
	if p.find_rest_left > 0.0:
		return
	var gap := FIND_GAP + p.m("find_gap")
	if p.last_find != Vector3.INF and Vector2(at.x - p.last_find.x, at.z - p.last_find.z).length() < gap:
		p.say("Nothing new to find here")
		return
	p.find_rest_left = FIND_REST + p.m("find_rest")
	p.last_find = at
	var picks: Array[String] = []
	for i in (2 if p.has_flag("find_twice") else 1):
		picks.append(_pick(p, picks))
	var names: Array[String] = []
	for i in picks.size():
		var id := picks[i]
		var spot := at + Vector3(0.9 * (i * 2 - picks.size() + 1), 0, 0.6).rotated(Vector3.UP, p.yaw)
		if WeaponDefs.ALL.has(id):
			p.world.spawn_pickup_at(spot, Pickup.Kind.WEAPON, id)
			names.append(WeaponDefs.ALL[id]["name"])
		else:
			p.world.spawn_pickup_at(spot, Pickup.Kind.POWER, id)
			names.append(PowerDefs.ALL[id]["name"])
	if p.has_flag("find_food"):
		p.world.spawn_pickup_at(at + Vector3(0, 0, -0.9).rotated(Vector3.UP, p.yaw), Pickup.Kind.FOOD, PowerDefs.pick_weighted(PowerDefs.FOODS))
	p.say("Unearthed: %s" % " and ".join(names))
	p.world.fx_rise(at + Vector3.UP * 0.2, Color(1.0, 0.82, 0.4))
	p.world.sfx_at("unearth", at, -3.0)


## Something not already in hand, if there is one.
static func _pick(p: Player, taken: Array[String]) -> String:
	var options: Array[String] = []
	for id: String in FINDS:
		if not p.carries(id) and not taken.has(id):
			options.append(id)
	if options.is_empty():
		return "lantern"
	return options[randi() % options.size()]
