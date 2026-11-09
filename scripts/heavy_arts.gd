class_name HeavyArts
extends RefCounted
## Profession effects use the acting player for ownership, teams and kill credit.

static func mend_summons(w: World, owner: int, at: Vector3, radius: float, healing: float) -> void:
	for ally: Ally in w.allies:
		if ally.dead or ally.remote_owner != 0 or ally.global_position.distance_to(at) > radius: continue
		if Net.active() and ally.master and Net.bots_foes(owner, ally.master.net_id()): continue
		var cap := float(Ally.HEALTH[ally.kind]) * (ally.master.m("ally_hp") if ally.master else 1.0)
		ally.hp = minf(cap, ally.hp + healing)

static func heal_party(p: Player, at: Vector3, radius: float, healing: float) -> void:
	var w := p.world
	var was := w.begin_act(p)
	if not p.dead and p.global_position.distance_to(at) <= radius: p.heal(healing)
	mend_summons(w, p.net_id(), at, radius, healing)
	if Net.active():
		for friend: Target in w.friends_near(at, radius):
			Net.guard_peer(w.peer_of(friend), 0.0, healing)
		Net.heavy_mend(at, radius, healing, p.net_id())
	HeavyWave.emit(w, 0, at, Vector3.FORWARD, radius)
	w.end_act(was)

static func last_rites(p: Player, at: Vector3) -> void:
	var w := p.world
	var was := w.begin_act(p)
	heal_party(p, at, 6.0, 10.0)
	w.burn_around(at, 4.0)
	HeavyWave.emit(w, 1, at, Vector3.FORWARD, 4.0)
	w.sfx_at("chime", at, -6.0)
	w.end_act(was)

static func faultline(p: Player) -> void:
	var w := p.world
	var was := w.begin_act(p)
	var forward := -p.camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var reach := 0.0
	var previous := p.global_position + Vector3.UP * 0.7
	for step in range(1, 25):
		var at := p.global_position + forward * (step * 0.5)
		if w.terrain.ground_height(at.x, at.z) < World.FALL_DEATH: break
		at.y = w.ground_at(at) + 0.7
		if not w.has_line_of_sight(previous, at): break
		previous = at
		reach = step * 0.5
	if reach < 0.5:
		w.end_act(was)
		return
	for enemy: Zombie in w.zombies_near(p.position, reach + 2.0, 32):
		if enemy.flies or not _in_line(p.position, forward, enemy.position, reach, enemy.body_radius()): continue
		if not w.has_line_of_sight(p.position + Vector3.UP, enemy.centre()): continue
		enemy.take_damage(40.0 * p.damage_multiplier(), forward, 3.0, enemy.centre())
		if enemy.is_alive(): enemy.slow(2.0)
	for rival: Target in w.rivals_near(p.position, reach + 1.0):
		if _in_line(p.position, forward, rival.global_position, reach, 0.4) and w.has_line_of_sight(p.position + Vector3.UP, rival.global_position + Vector3.UP):
			w.hit_rival(rival, 40.0 * p.damage_multiplier(), p.position)
			w.status_rival(rival, Net.Status.SLOW, 2.0)
	HeavyWave.emit(w, 2, p.position, forward, reach)
	w.sfx_at("hammer", p.position, -1.0)
	w.end_act(was)

static func _in_line(origin: Vector3, forward: Vector3, at: Vector3, reach: float, body: float) -> bool:
	var offset := at - origin
	if absf(offset.y) > 4.0: return false
	offset.y = 0.0
	var along := offset.dot(forward)
	return along >= 0.0 and along <= reach + body and (offset - forward * along).length() <= 1.2 + body
