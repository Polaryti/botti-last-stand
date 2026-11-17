class_name Boons
extends RefCounted
## Last Light's boons: at each waystation of the Lantern Road everyone chooses one of three, kept for
## the rest of the voyage. Each adds to the player's own numbers (Player.mods) or sets a flag the game
## reads. Offers never repeat a boon you already have, and are the same for a player at a waystation
## however often they are asked (seeded by the waystation and the player).

const ALL := {
	"salt_ward": {"name": "Salt Ward", "icon": "shield+up", "desc": "You take 20% less damage.", "add": {"damage_taken": -0.2}},
	"lamplighter": {"name": "Lamplighter's Fury", "icon": "flame+up", "desc": "Your blows and your shots hit 20% harder.", "add": {"melee_damage": 0.2, "ranged_damage": 0.2}},
	"sea_legs": {"name": "Sea Legs", "icon": "tide+up", "desc": "You move 10% faster, and wading no longer slows you.", "add": {"speed": 0.1}, "flag": "sea_legs"},
	"ships_biscuit": {"name": "Ship's Biscuit", "icon": "heart+up", "desc": "25 more health, and you are healed in full.", "add": {"max_hp": 25.0}, "heal": true},
	"mended_net": {"name": "Mended Net", "icon": "lotus+clock", "desc": "You heal 1 health a second.", "add": {"regen": 1.0}},
	"deep_lungs": {"name": "Deep Lungs", "icon": "tide+shield", "desc": "Outside the light the tide takes half as much from you, and only after 6 s.", "flag": "deep_lungs"},
	"lantern_bearer": {"name": "Lantern Bearer", "icon": "lantern+up", "desc": "The barge's light reaches 4 m further for you.", "flag": "lantern_bearer"},
}
const DEEP_GRACE := 6.0
const DEEP_SHARE := 0.5
const BEARER_REACH := 4.0
const OFFERED := 3


## The three a player is offered at a waystation.
static func offer_for(p: Player, way: int) -> Array[String]:
	var open: Array[String] = []
	for id: String in ALL:
		if not p.boons.has(id):
			open.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([way, p.net_id(), p.class_id])
	var out: Array[String] = []
	while out.size() < OFFERED and not open.is_empty():
		out.append(open.pop_at(rng.randi() % open.size()))
	return out


static func grant(p: Player, id: String) -> void:
	if not ALL.has(id) or p.boons.has(id):
		return
	var d: Dictionary = ALL[id]
	p.boons.append(id)
	var add: Dictionary = d.get("add", {})
	for k: String in add:
		p.mods[k] = float(p.mods[k]) + float(add[k])
	if d.has("flag"):
		p.flags[d["flag"]] = true
	if d.get("heal", false):
		p.hp = p.max_hp()
	p.say(str(d["name"]))
	p.sfx("ui_choose", -3.0)


## How long a player may be outside the light before the tide starts to drown them.
static func grace(p: Player) -> float:
	return DEEP_GRACE if p.has_flag("deep_lungs") else LastLight.OUT_GRACE


static func drown_share(p: Player) -> float:
	return DEEP_SHARE if p.has_flag("deep_lungs") else 1.0


static func light_bonus(p: Player) -> float:
	return BEARER_REACH if p.has_flag("lantern_bearer") else 0.0
