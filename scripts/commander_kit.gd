class_name CommanderKit
extends RefCounted
## Commander rules shared by the player, HUD and authority. Effects live in CommandField.

const COMMAND_CD := 24.0
const TRAINED_COMMAND_CD := COMMAND_CD * 0.8
const LAST_CD := 60.0
const RALLY_RADIUS := 12.0
const STORM_RADIUS := 11.0
const BARRAGE_RADIUS := 18.0
const BARRAGE_DELAY := 4.0
const BARRAGE_TIME := 5.0
const BARRAGE_INTERVAL := 0.25
const SHELL_FALL := 0.35
const FIRE_TIME := 8.0
const FIRE_RADIUS := 3.2
const FIRE_DPS := 10.0
const STAFF_BOLT := {"range": 34.0, "speed": 34.0, "knock": 2.0}

const COMMAND_ART := {"name": "Command", "cost": 0.0, "cast": 0.45, "cd": COMMAND_CD, "icon": "horn", "anim": "Stance"}
const LAST_ART := {"name": "Last Command", "cost": 0.0, "cast": 0.45, "cd": LAST_CD, "icon": "horn", "anim": "Stance"}


static func art(p: Player) -> Dictionary:
	if p.has_flag("last_command"):
		return LAST_ART
	if p.has_flag("quick_command"):
		var trained := COMMAND_ART.duplicate()
		trained["cd"] = TRAINED_COMMAND_CD
		return trained
	return COMMAND_ART


static func equip(p: Player) -> void:
	if p.spec_id in ["warlock", "gunner"]:
		p.slots = ["war_staff" if p.spec_id == "warlock" else "musket", null]
		p.current = 0
		p._equip()
		p.hp = minf(p.hp, p.max_hp())
	if p.spec_id == "vanguard":
		p._refresh_banner()


static func cast(p: Player) -> void:
	var last := p.has_flag("last_command") and p.level >= ClassDefs.MAX_LEVEL
	if last and p.spec_id == "gunner" and not p.command_target_ready:
		return
	if last and p.spec_id in ["warlock", "gunner"]:
		Net.command_field(p.spec_id, p.command_target if p.spec_id == "gunner" else p.global_position, p.world)
	elif p.spec_id == "warlock":
		p.world.spawn_ally("magician", p.global_position + Vector3(2, 0, 0), 16.0 * p.m("ally_time"))
	elif p.spec_id == "gunner":
		p.world.spawn_ally("artificer", p.global_position + Vector3(2, 0, 0), 16.0 * p.m("ally_time"))
	else:
		var radius := 16.0 if p.has_flag("banner_reach") else RALLY_RADIUS
		Net.command_rally(p.net_id(), radius, last, p.world)
		if last:
			for i in 2:
				p.world.spawn_ally("infantry", p.global_position + Vector3((i * 2 - 1) * 2, 0, 0), 20.0 * p.m("ally_time"))
	if p.has_flag("rally_recovery"):
		var radius := 16.0 if p.has_flag("banner_reach") else RALLY_RADIUS
		p.heal(20.0)
		for ally: Ally in p.world.allies:
			if not ally.dead and ally.master == p and ally.remote_owner == 0 and ally.global_position.distance_to(p.global_position) <= radius:
				ally.hp = minf(ally.hp + 20.0, float(Ally.HEALTH[ally.kind]) * p.m("ally_hp"))
		if Net.active():
			for friend: Target in p.world.friends_near(p.global_position, radius):
				Net.guard_peer(p.world.peer_of(friend), 0.0, 20.0)
	p.command_target_ready = false
	p.sfx("command", -3.0, 0.85)
