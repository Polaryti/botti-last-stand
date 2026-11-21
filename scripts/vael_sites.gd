class_name VaelSites
extends RefCounted
## Port Vael's landings, lanes and supply spots. They use the same walkability as the AI and keep
## spawn decisions on the host. Height comes from the ground, including the authored ramps.

enum Shore { ANY, DRY, WATERLINE, EXPOSED, FLOODED }
const PLAYER_CLEARANCE := 3.5
const MOB_CLEARANCE := 1.4

var world: World


func _init(on: World) -> void:
	world = on


func accessible(at: Vector3) -> bool:
	return world._inside_play(at, 2.0) and world.grid.is_free(world.grid.to_cell(at)) and world.in_reach(at)


func _shore_allows(at: Vector3, shore: Shore) -> bool:
	match shore:
		Shore.DRY: return not world.tide.flooded(at)
		Shore.WATERLINE: return at.y < MistTide.HIGH_Y + 0.4
		Shore.EXPOSED: return at.y < MistTide.HIGH_Y + 0.4 and not world.tide.flooded(at)
		Shore.FLOODED: return world.tide.flooded(at)
	return true


func _live_players() -> Array[Target]:
	var live: Array[Target] = []
	for p: Target in world.players:
		if is_instance_valid(p) and not p.dead:
			live.append(p)
	return live


## Each candidate is checked against every living player. A separated group can get enemies on both
## sides of the map, while a doorway occupied by a teammate cannot become a spawn point.
func enemy_site(lo := 25.0, hi := 66.0, shore := Shore.ANY) -> Vector3:
	var live := _live_players()
	if live.is_empty():
		return Vector3.INF
	var focus: Target = live.pick_random()
	var pool := world.vael_approaches.duplicate()
	# A player off the marked routes still gets pressure, including in the back streets.
	for i in 12:
		var angle := randf() * TAU
		pool.append(focus.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(lo, hi))
	var best := Vector3.INF
	var score := -INF
	var min_sq := lo * lo
	var max_sq := hi * hi
	for candidate: Vector3 in pool:
		var from_focus := _flat_delta(candidate, focus.global_position)
		var dist_sq := from_focus.length_squared()
		if dist_sq < min_sq or dist_sq > max_sq:
			continue
		var too_close := false
		for p: Target in live:
			if _flat_delta(candidate, p.global_position).length_squared() < min_sq:
				too_close = true
				break
		if too_close or not accessible(candidate):
			continue
		candidate.y = world.ground_at(candidate)
		if not _shore_allows(candidate, shore) or not _room_for_enemy(candidate):
			continue
		if world.fog and not world.fog.contains(candidate, -4.0):
			continue
		var behind := from_focus.normalized().dot(focus.look_direction()) < 0.25
		var value := randf_range(0.0, 13.0) - sqrt(dist_sq) * 0.23 + (8.0 if behind else 0.0)
		if value > score:
			best = candidate
			score = value
	return best


func spawn_pack(id: String, count: int, shore: Shore) -> int:
	var centre := enemy_site(26.0, 45.0, shore)
	if centre == Vector3.INF:
		centre = enemy_site(26.0, 62.0)
	if centre == Vector3.INF:
		return 0
	var came := 1 if world.spawn_zombie(id, centre) else 0
	if came == 0:
		return 0
	var live := _live_players()
	var turn := randf() * TAU
	for i in 12:
		if came >= count:
			break
		var angle := turn + i * TAU / 12.0
		var at := centre + Vector3(cos(angle), 0, sin(angle)) * 2.5
		if not accessible(at) or not world.grid.line_is_open(centre, at) or not _room_for_enemy(at):
			continue
		if live.any(func(p: Target) -> bool: return _flat_delta(at, p.global_position).length_squared() < 22.0 * 22.0):
			continue
		if world.fog and not world.fog.contains(at, -4.0):
			continue
		at.y = world.ground_at(at)
		if absf(at.y - centre.y) <= 0.9 and world.spawn_zombie(id, at):
			came += 1
	return came


func _room_for_enemy(at: Vector3) -> bool:
	for z: Zombie in world.zombies:
		if z.is_alive() and _flat_delta(z.global_position, at).length_squared() < MOB_CLEARANCE * MOB_CLEARANCE:
			return false
	return true


func pickup_site(kind: int) -> Vector3:
	var live := _live_players()
	if live.is_empty():
		return Vector3.INF
	var focus: Target = live.pick_random()
	var supplies := kind in [Pickup.Kind.FOOD, Pickup.Kind.ARROWS]
	var best := Vector3.INF
	var score := -INF
	for at: Vector3 in world.loot_spots:
		var dist := _flat_delta(at, focus.global_position).length()
		if dist > (76.0 if supplies else 102.0):
			continue
		if not can_stock(at, supplies) or live.any(func(p: Target) -> bool: return _flat_delta(at, p.global_position).length_squared() < PLAYER_CLEARANCE * PLAYER_CLEARANCE):
			continue
		# Food and arrows favour nearby routes. Weapons and potions have room to land farther out.
		var value := randf_range(0.0, 18.0) - absf(dist - (24.0 if supplies else 45.0)) * 0.38
		if value > score:
			best = at
			score = value
	if best != Vector3.INF:
		return best
	# When the versus fog closes over the marked sites, keep supplying the remaining ground.
	if world.fog:
		for i in 18:
			var angle := randf() * TAU
			var at := focus.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(6.0, 18.0)
			if can_stock(at, supplies, 4.0) and not live.any(func(p: Target) -> bool: return _flat_delta(at, p.global_position).length_squared() < PLAYER_CLEARANCE * PLAYER_CLEARANCE):
				return at
	return Vector3.INF


func holds_supplies(at: Vector3) -> bool:
	if world.fog:
		return false
	return world.cache_spots.any(func(cache: Vector3) -> bool: return _flat_delta(at, cache).length_squared() < 0.01)


func can_stock(at: Vector3, supplies: bool, separate := World.PICKUP_APART) -> bool:
	if not accessible(at) or (world.fog and not world.fog.contains(at, -3.0)):
		return false
	var y := world.ground_at(at)
	if y < (MistTide.HIGH_Y if supplies else world.tide.level) + 0.06:
		return false
	var gap_sq := separate * separate
	for p: Pickup in world.pickups:
		if _flat_delta(p.global_position, at).length_squared() < gap_sq:
			return false
	return true


func patrol(from: Vector3) -> Vector3:
	var points := world.pois
	if points.is_empty():
		return from
	for i in 8:
		var at: Vector3 = points.pick_random()
		var dist := _flat_delta(at, from).length_squared()
		if dist >= 8.0 * 8.0 and dist <= 40.0 * 40.0 and accessible(at):
			return at
	return from


static func _flat_delta(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(a.x - b.x, 0.0, a.z - b.z)
