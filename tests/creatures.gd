extends Node
## The creatures of Mesenlla, one by one, in a Sandbox: their entries, their bodies, and every special
## move with its tell; then their two maps, the Valleys of Mesenlla and Mist Bastion with its garrison.
## Run with tools/run_checks.py creatures.

var checks := 0
var failures := 0
var w: World
var p: Player

const KINDS := ["bear", "mist_bear", "eagle", "mist_eagle", "shapeshifter", "child_of_woods", "woodland_cavalry", "earth_elemental",
	"mist_elemental", "storm_elemental", "wyvern", "great_revenant_elemental", "war_wyvern"]


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", description)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(t: float) -> void:
	await frames(int(t * Engine.physics_ticks_per_second / maxf(Engine.time_scale, 0.01)) + 1)


func _ready() -> void:
	seed(40422)
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	Game.player_name = "Test Player"
	Game.quality = 0
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "heavy"
	Game.mode = Game.Mode.SANDBOX
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.SANDBOX)
	for z: Zombie in w.zombies.duplicate():
		z.release()
	p = w.player
	_entries()
	await _bear()
	await _mist_bear()
	await _shapeshifter()
	await _children()
	await _earth()
	await _mist_elemental()
	await _storm()
	await _flyers()
	await _revenant()
	await _mesenlla_map()
	await _bastion_map()
	await _deaths()
	Net.leave()
	w.queue_free()
	await frames(2)
	Sfx.stop_all()
	OS.delay_msec(120)
	await get_tree().create_timer(0.15).timeout
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## Somewhere open, with the player standing still and able to be hurt: a spot with a clear view 20 m
## to the north and solid ground all the way.
func arena(_offset := Vector3.ZERO) -> Vector3:
	clear()
	if _open == Vector3.INF:
		for r in range(0, 90, 6):
			for a in 16:
				var c := Vector3(cos(TAU * a / 16.0) * r, 0, sin(TAU * a / 16.0) * r)
				if _is_open(c):
					_open = c
					break
			if _open != Vector3.INF:
				break
	check(_open != Vector3.INF, "an open place to meet them")
	var centre := _open
	p.global_position = Vector3(centre.x, w.ground_at(centre) + 0.05, centre.z)
	p.velocity = Vector3.ZERO
	p.hp = p.max_hp()
	p.guard_left = 0.0
	p.frozen_left = 0.0
	p.burn_time = 0.0
	p.dead = false
	p.yaw = 0.0
	p.rotation.y = 0.0
	return p.global_position


var _open := Vector3.INF


func _is_open(c: Vector3) -> bool:
	var eye := Vector3(c.x, w.ground_at(c) + 1.4, c.z)
	for z in range(-20, 3, 2):
		for x in [-8, 0, 8]:
			var at := c + Vector3(x, 0, z)
			if not w.grid.is_free(w.grid.to_cell(at)) or not w.terrain.is_walkable(at.x, at.z):
				return false
		var far := c + Vector3(0, 0, z)
		if not w.has_line_of_sight(eye, Vector3(far.x, w.ground_at(far) + 1.4, far.z)):
			return false
	return absf(w.ground_at(c) - w.ground_at(c + Vector3(0, 0, -20))) < 2.5


func clear() -> void:
	for z: Zombie in w.zombies.duplicate():
		z.release()
	for seal in w.mist_seals.duplicate():
		seal.queue_free()
	for it: Pickup in w.pickups.duplicate():
		w.remove_pickup(it)


func raise(id: String, at: Vector3) -> Zombie:
	var spot := w.grid.to_world(w.grid.nearest_free(w.grid.to_cell(at)))
	check(w.spawn_zombie(id, Vector3(spot.x, 0, spot.z)), "%s can be raised" % id)
	var z: Zombie = w.zombies.back()
	var look := p.global_position - z.position
	z.rotation.y = atan2(look.x, look.z)
	z._start_chase(p.global_position)
	return z


func seals(style: int) -> Array:
	return w.mist_seals.filter(func(s: MistSeal) -> bool: return is_instance_valid(s) and s.style == style)


## Waits until the creature shows a state, or the time runs out.
func until_state(z: Zombie, state: String, limit: float) -> bool:
	var t := 0.0
	while t < limit and z._current_anim != state:
		await seconds(0.05)
		t += 0.05
	return z._current_anim == state


func _entries() -> void:
	for id: String in KINDS:
		var d: Dictionary = ZombieDefs.ALL[id]
		check(SpawnRules.is_mesenlla(d), "%s lives only beyond the Mists" % id)
		var badge := ClassPresentation.map_tag(d)
		check((badge.get_child(0) as Label).text == "Map Exclusive · Mesenlla", "%s is tagged Map Exclusive · Mesenlla" % id)
		badge.free()
		for part: String in str(d["icon"]).split("+"):
			check(Icons.exists(part), "%s icon part %s" % [id, part])
		check(Sfx.NAMES.has(Zombie.MESENLLA_VOICES.get(id, "")), "%s has a voice" % id)
	for state: String in ["m_swipe", "m_rear", "m_charge", "m_slam", "m_cast", "m_breath", "m_throw", "m_blink", "m_stag", "m_beast", "m_shift"]:
		check(Net.ANIMS.has(state), "%s reaches other phones" % state)
	check(Net.ANIMS.size() <= 64, "the state still fits its six bits")
	for sound: String in ["quake_warning", "earth_slam", "storm_call", "fire_warning", "fire_breath", "boulder_throw", "boulder_impact", "revenant_roar", "bear_maul"]:
		check(Sfx.NAMES.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	# Nothing from the old maps roams beyond the Mists, and nothing from beyond roams the old maps.
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "mesenlla"
	var plan := Game.zombie_pool_plan()
	check(plan.has("woods_child") and not plan.has("normal_a") and not plan.has("beast") and not plan.has("crow"), "beyond the Mists only its own creatures have bodies (%s)" % str(plan.keys()))
	Game.night_map = "village"
	check(not Game.zombie_pool_plan().has("bear"), "and the Village has none of them")
	Game.mode = Game.Mode.SANDBOX
	var strays := 0
	for i in 300:
		if SpawnRules.is_mesenlla(ZombieDefs.ALL[ZombieDefs.pick_roamer(600.0, "village")]):
			strays += 1
	check(strays == 0, "the Village never picks a creature of Mesenlla to roam (%d)" % strays)
	var bosses := ["great_revenant_elemental", "war_wyvern"]
	for id: String in bosses:
		check(ZombieDefs.ALL[id].get("mesenlla_boss", false) and CodexPanel.enemy_group(id) == 5, "%s is listed with the bosses" % id)
	check(CodexPanel.enemy_group("bear") == 4, "the others are Creatures of Mesenlla")


func _bear() -> void:
	var at := arena()
	var z := raise("bear", at + Vector3(0, 0, -2.4))
	check(z._custom and z._visual.get_node_or_null("Rig/Hind/Torso/Head") != null and z._visual.get_node_or_null("Rig/LegBL/Knee") != null, "the bear has a body of its own, on joints")
	# It walks on its legs: they swing from the hip and fold at the knee.
	var leg := z._visual.get_node("Rig/Hind/Torso/LegFL") as Node3D
	var swings := []
	z._current_anim = ""
	for i in 12:
		MesenllaModels.animate(z, z._visual, 0.05, z._speed)
		swings.append(leg.rotation.x)
	check(swings.max() - swings.min() > 0.3, "walking, its legs swing (%.2f)" % (swings.max() - swings.min()))
	# A hit flashes every part of it, and each part gets its own look back after.
	var eyes: Array = z._parts.filter(func(mi: MeshInstance3D) -> bool: return mi.get_meta("own_material", null) == MesenllaModels.glow_material())
	check(z._parts.size() > 8 and eyes.size() >= 1, "all its parts flash when struck (%d)" % z._parts.size())
	z._flash_on()
	z._restore_materials()
	check(eyes.all(func(mi: MeshInstance3D) -> bool: return mi.material_override == MesenllaModels.glow_material()), "and its glowing eyes glow again after the flash")
	var hp0 := p.hp
	check(await until_state(z, "m_rear", 6.0), "a bear close by rears up first")
	check(z.is_warning(), "and that is its tell")
	await seconds(MesenllaMind.MAUL_TELL + 0.3)
	check(p.hp < hp0 - z._damage * 1.5, "then the maul lands hard (%.0f)" % (hp0 - p.hp))
	# A stun stops a rearing bear.
	z.mesenlla_mind.cooldown = 0.0
	p.hp = p.max_hp()
	check(await until_state(z, "m_rear", 4.0), "it rears again")
	z.stun(1.0)
	check(z.mesenlla_mind.phase == "" and not z.is_warning(), "a stun cuts the maul short")


func _mist_bear() -> void:
	var at := arena()
	var z := raise("mist_bear", at + Vector3(0, 0, -11))
	z.mesenlla_mind.cooldown_b = 0.0
	var hp0 := p.hp
	check(await until_state(z, "m_rear", 6.0), "a Mist Bear paws the ground before a charge")
	var charged := await until_state(z, "m_charge", 3.0)
	if not charged:
		print("DEBUG mist bear: state=%s phase=%s left=%.2f dist=%.1f" % [z._current_anim, z.mesenlla_mind.phase, z.mesenlla_mind.left, z.position.distance_to(p.global_position)])
	check(charged, "then charges")
	await seconds(1.6)
	check(p.hp < hp0, "and the charge strikes (%.0f)" % (hp0 - p.hp))
	check(z.def.get("shoves", false), "throwing you back")


func _shapeshifter() -> void:
	var at := arena()
	var z := raise("shapeshifter", at + Vector3(0, 0, -16))
	check(z._current_anim == "m_stag" and z._damage == 0.0, "the Shapeshifter starts as a harmless stag")
	check((z._visual.get_node("Stag") as Node3D).visible and not (z._visual.get_node("Beast") as Node3D).visible, "and looks like one")
	z.position = Vector3(at.x, w.ground_at(at), at.z - 5.0)
	check(await until_state(z, "m_shift", 4.0), "close by, it changes shape")
	await seconds(MesenllaMind.SHIFT_TIME + 0.2)
	check(z.mesenlla_mind.form == "beast" and z._damage > 0.0, "into a beast that can hurt you")
	await seconds(0.2)
	check((z._visual.get_node("Beast") as Node3D).visible, "and looks like one")
	z.hp = z.max_hp * 0.2
	await seconds(MesenllaMind.SHIFT_TIME + 0.6)
	check(z.mesenlla_mind.form == "stag" and z.mesenlla_mind.phase == "flee", "badly hurt, it turns back into the stag and flees")
	check(absf(z._speed - float(ZombieDefs.ALL["shapeshifter"]["speed"]) * 1.15 * Game.enemy_speed()) < 0.01, "running as fast as the stag can")
	var low := z.hp
	await seconds(MesenllaMind.STAG_FLEE * 0.5)
	check(is_equal_approx(z.hp, low) and z.mesenlla_mind.phase == "flee", "it does not mend while it runs (%.0f to %.0f)" % [low, z.hp])
	await seconds(MesenllaMind.STAG_FLEE * 0.5 + 0.2)
	check(is_equal_approx(z.hp, z.max_hp), "not caught within %d seconds, it comes back whole (%.0f of %.0f)" % [int(MesenllaMind.STAG_FLEE), z.hp, z.max_hp])
	await seconds(MesenllaMind.SHIFT_TIME + 0.2)
	check(z.mesenlla_mind.form == "beast" and is_equal_approx(z._speed, MesenllaMind.BEAST_SPEED * Game.enemy_speed()), "as the beast again, faster than before (%.1f m/s)" % z._speed)


## The south of the Valleys, the edge of the land, and the tents of the camp.
func _mesenlla_south() -> void:
	var names := w.map_marks.map(func(m: Dictionary) -> String: return m["name"])
	for mark: String in ["Fallen Hall", "Hunters' Lodge", "Old Mine", "Mossy Spring"]:
		check(names.has(mark), "the south has its %s" % mark)
	check(w.cache_spots.size() == 3 and w.cache_spots.all(func(at: Vector3) -> bool: return at.z > 60.0), "three caches of rarer finds, all in the south")
	w.director.elapsed = 1.0
	w.director._cache_look = 0.0
	w.director._tick_caches()
	var found: Array = []
	for at: Vector3 in w.cache_spots:
		for it: Pickup in w.pickups:
			if Vector2(it.global_position.x - at.x, it.global_position.z - at.z).length() < 2.0:
				found.append(it)
	check(found.size() == 3 and found.all(func(it: Pickup) -> bool: return it.kind == Pickup.Kind.POWER or float(WeaponDefs.ALL[it.item_id]["weight"]) <= WeaponDefs.RARE_WEIGHT), "each holds a rare weapon or a potion: %s" % str(found.map(func(it: Pickup) -> String: return it.item_id)))
	for it: Pickup in found:
		w.pickups.erase(it)
		it.queue_free()
	await frames(1)
	w.director._cache_look = 0.0
	w.director._tick_caches()
	check(not w.pickups.any(func(it: Pickup) -> bool: return Vector2(it.global_position.x - w.cache_spots[0].x, it.global_position.z - w.cache_spots[0].z).length() < 2.0), "taken, a cache is not filled again at once")
	w.director.elapsed += Director.CACHE_REFILL + 1.0
	w.director._cache_look = 0.0
	w.director._tick_caches()
	check(w.pickups.any(func(it: Pickup) -> bool: return Vector2(it.global_position.x - w.cache_spots[0].x, it.global_position.z - w.cache_spots[0].z).length() < 2.0), "but %d seconds later it is" % int(Director.CACHE_REFILL))
	# The shrines.
	check(w.shrines.size() == 3 and w.shrines.map(func(sh: Dictionary) -> String: return sh["blessing"]).has("stag") and w.shrines.map(func(sh: Dictionary) -> String: return sh["blessing"]).has("bear") and w.shrines.map(func(sh: Dictionary) -> String: return sh["blessing"]).has("spring"), "three shrines: the Stag, the Bear and the Spring")
	var stag: Dictionary = w.shrines.filter(func(sh: Dictionary) -> bool: return sh["blessing"] == "stag")[0]
	var was_speed := p.m("speed")
	var was_at := p.global_position
	p.global_position = stag["at"] + Vector3(0, 0.1, 1.4)
	w._tick_shrines()
	check(p.m("speed") > was_speed + 0.2 and w.director.banner.contains("Stag"), "touching the Stag's shrine makes you swifter (%.2f to %.2f)" % [was_speed, p.m("speed")])
	check(float(stag["ready_at"]) > w.now and not (stag["glow"][0] as Node3D).visible, "and it goes dark to rest")
	var bear: Dictionary = w.shrines.filter(func(sh: Dictionary) -> bool: return sh["blessing"] == "bear")[0]
	var was_melee := p.m("melee_damage")
	p.global_position = bear["at"] + Vector3(0, 0.1, 1.4)
	w._tick_shrines()
	check(p.m("melee_damage") > was_melee + 0.2 and p.m("ranged_damage") > 1.0, "the Bear's makes every kind of blow harder")
	var spring: Dictionary = w.shrines.filter(func(sh: Dictionary) -> bool: return sh["blessing"] == "spring")[0]
	p.hp = p.max_hp() * 0.5
	var low := p.hp
	p.global_position = spring["at"] + Vector3(0, 0.1, 1.4)
	w._tick_shrines()
	check(p.hp >= low + 19.0 and p.m("regen") >= 4.0, "and the Spring's heals you, and goes on healing")
	p._buffs.clear()
	p.global_position = was_at
	# The tents stop you, all of them.
	var space := w.get_world_3d().direct_space_state
	var blocked := 0
	var tents := 0
	for at: Vector3 in [Vector3(-14, 6, -34), Vector3(-14, 6, -26), Vector3(14, 6, -34), Vector3(15, 6, -24), Vector3(-7, 6, -19)]:
		tents += 1
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.6, 0) + Vector3(3.5, 0, 0), at + Vector3(0, 0.6, 0) - Vector3(3.5, 0, 0), 1)
		var front := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.6, 0) + Vector3(0, 0, 3.5), at + Vector3(0, 0.6, 0) - Vector3(0, 0, 3.5), 1)
		if not space.intersect_ray(ray).is_empty() and not space.intersect_ray(front).is_empty():
			blocked += 1
	check(blocked == tents, "nobody walks through a tent, from the side or the door (%d of %d)" % [blocked, tents])
	# The edge of the land is lined with tall trees.
	var edge := w.tree_spots.filter(func(t: Vector3) -> bool: return maxf(absf(t.x), absf(t.z)) > w.play_half - 4.0)
	check(edge.size() >= 120, "the edge of the land is lined with tall trees (%d)" % edge.size())


## The camp is shelled from 2:00, warned at 5:00, and lost to the mist after the barrage.
func _mesenlla_camp() -> void:
	var d := w.director
	d.camp = null
	check(CampSiege.wanted(w), "the camp can be shelled here")
	d.camp = CampSiege.new(w)
	var siege := d.camp
	check(siege.centre != Vector3.INF and Vector2(siege.centre.x, siege.centre.z + 32.0).length() < 4.0, "around Mesenlla Watch")
	var seals := w.mist_seals.size()
	siege.tick(CampSiege.STRIKES_FROM - 1.0)
	check(w.mist_seals.size() == seals, "nothing falls before %d s" % int(CampSiege.STRIKES_FROM))
	siege.tick(CampSiege.STRIKES_FROM)
	check(w.mist_seals.size() == seals + CampSiege.VOLLEY, "then storm and mist fall on the camp (%d circles)" % (w.mist_seals.size() - seals))
	check(w.mist_seals.slice(seals).all(func(m: MistSeal) -> bool: return Vector2(m.position.x - siege.centre.x, m.position.z - siege.centre.z).length() <= CampSiege.RADIUS), "and only on the camp")
	siege.tick(CampSiege.WARN_AT)
	check(d.banner.contains("Get out"), "at 5:00 everyone is told to get out: %s" % d.banner)
	check(not w.camp_fallen, "the camp still stands")
	var before := w.mist_seals.size()
	siege.tick(CampSiege.BARRAGE_AT + 2.0)
	check(w.mist_seals.size() - before >= int(2.0 / CampSiege.BARRAGE_EVERY), "then the barrage comes down (%d circles in 2 s)" % (w.mist_seals.size() - before))
	siege.tick(CampSiege.BARRAGE_AT + CampSiege.BARRAGE_TIME + 0.1)
	check(w.camp_fallen and siege.done, "and the camp falls")
	var in_camp := w.watchtowers.filter(func(t: Dictionary) -> bool: return Vector2(t["at"].x - siege.centre.x, t["at"].z - siege.centre.z).length() <= CampSiege.RADIUS + 4.0)
	check(in_camp.size() == 2 and in_camp.all(func(t: Dictionary) -> bool: return t.get("ruined", false) and not (t["parts"][0] as Node3D).visible), "its archer posts are brought down")
	check(w.watchtowers.any(func(t: Dictionary) -> bool: return not t.get("ruined", false)), "and the towers elsewhere still stand")
	var storm := w.storm_at(siege.centre)
	check(storm != null and storm.duration == INF and w.storm_at(siege.centre + Vector3(0, 0, 40)) == null, "a Mist Storm settles over the camp for good")
	var inside := 0
	for i in 200:
		var at := w._pick_spawn_point()
		if at != Vector3.INF and w.storm_at(at) != null:
			inside += 1
	check(inside == 0, "nothing rises inside it")
	var loot_inside := 0
	for i in 60:
		var it := w.spawn_pickup_random(Pickup.Kind.FOOD, "bread")
		if it and w.storm_at(it.global_position) != null:
			loot_inside += 1
	check(loot_inside == 0, "and nothing is left lying there")
	p.respawn(siege.centre)
	check(w.storm_at(p.global_position) == null, "a player back on their feet stands outside it (%.0f, %.0f)" % [p.global_position.x, p.global_position.z])
	p.hp = p.max_hp()
	p.guard_left = 0.0
	p.global_position = siege.centre + Vector3(0, 0.2, 0)
	storm.elapsed = storm.warning
	var hp := p.hp
	storm._physics_process(1.0)
	check(p.hp < hp - MistStorm.DPS * 0.9, "and inside it the mist burns, as in the Mists (%.1f)" % (hp - p.hp))
	storm.end_now()
	w.camp_fallen = false
	p.respawn(p.global_position)
	d.camp = null


func _children() -> void:
	var at := arena()
	var kid := raise("child_of_woods", at + Vector3(0, 0, -12))
	check(kid.weapon_id in ZombieDefs.ALL["child_of_woods"]["weapons"], "a Child of the Woods carries a weapon it found (%s)" % kid.weapon_id)
	check(kid.model_id == "woods_child" and not kid._custom, "on an animated body of its own")
	var held := kid.weapon_id
	kid.take_damage(10000.0, Vector3.ZERO, 0.0, kid.centre())
	await seconds(0.2)
	check(not WeaponDefs.lies_around(held) or w.pickups.any(func(i: Pickup) -> bool: return i.kind == Pickup.Kind.WEAPON and i.item_id == held), "and drops it when it falls")
	var rider := raise("woodland_cavalry", at + Vector3(0, 0, -14))
	check(rider._mounted and rider._horse_node.visible and (rider._horse_node.material_override as ShaderMaterial).get_shader_parameter("belly") != null, "Woodland Cavalry ride bears")
	check(rider.weapon_id == "spear", "with spears")
	rider.take_damage(rider.max_hp * 0.65, Vector3.ZERO, 0.0, rider.centre())
	check(not rider._mounted, "bring the bear down and the rider fights on foot")


func _earth() -> void:
	var at := arena()
	var z := raise("earth_elemental", at + Vector3(0, 0, -3))
	var hp0 := p.hp
	check(await until_state(z, "m_slam", 6.0), "an Earth Elemental close by raises its fists")
	check(seals(MistSeal.Style.QUAKE).size() == 1, "and an amber circle marks where it will pound")
	await seconds(MesenllaMind.SLAM_TELL + 0.2)
	check(p.hp < hp0 and p.frozen_left > 0.0, "staying inside hurts and stuns (%.0f)" % (hp0 - p.hp))
	at = arena()
	z = raise("earth_elemental", at + Vector3(0, 0, -14))
	z.mesenlla_mind.cooldown_b = 0.0
	check(await until_state(z, "m_throw", 6.0), "from further away it throws a stone")
	check(seals(MistSeal.Style.BOULDER).size() == 1, "landing where the ring shows")
	var ring: MistSeal = seals(MistSeal.Style.BOULDER)[0]
	check(ring._boulder != null and ring._boulder.visible, "and the stone can be seen in the air")
	p.global_position += Vector3(8, 0, 0)
	hp0 = p.hp
	await seconds(MesenllaMind.STONE_TELL + 0.2)
	check(p.hp == hp0, "stepping out of the ring avoids it")


func _mist_elemental() -> void:
	var at := arena()
	var z := raise("mist_elemental", at + Vector3(0, 0, -16))
	z.mesenlla_mind.cooldown = 0.0
	var faded := await until_state(z, "m_blink", 6.0)
	if not faded:
		print("DEBUG mist elemental: state=%s phase=%s cd=%.2f sees=%s dist=%.1f unseen=%s" % [z._current_anim, z.mesenlla_mind.phase, z.mesenlla_mind.cooldown, z._sees, z.position.distance_to(p.global_position), p.is_unseen()])
	check(faded, "a Mist Elemental fades away")
	await seconds(MesenllaMind.BLINK_TELL + 0.2)
	check(Vector2(z.position.x - at.x, z.position.z - at.z).length() < 3.2, "and comes back right beside you (%.1f m)" % Vector2(z.position.x - at.x, z.position.z - at.z).length())
	z.take_damage(10000.0, Vector3.ZERO, 0.0, z.centre())
	check(seals(MistSeal.Style.MIST).size() == 1, "when it falls its mist bursts")


func _storm() -> void:
	var at := arena()
	var z := raise("storm_elemental", at + Vector3(0, 0, -7))
	var start := Vector2(z.position.x - at.x, z.position.z - at.z).length()
	check(await until_state(z, "m_cast", 6.0), "a Storm Elemental calls lightning")
	var strike: Array = seals(MistSeal.Style.STORM)
	check(strike.size() == 1 and Vector2(strike[0].position.x - at.x, strike[0].position.z - at.z).length() < 2.0, "where you stand")
	await seconds(2.0)
	check(Vector2(z.position.x - at.x, z.position.z - at.z).length() > start + 0.5, "and backs away to keep its distance")


func _flyers() -> void:
	var at := arena()
	var eagle := raise("eagle", at + Vector3(0, 0, -12))
	check(eagle.flies and eagle.position.y - w.ground_at(eagle.position) > 4.0, "eagles fly high")
	check(eagle._visual.has_meta("wing_l"), "on wings that beat")
	var mist := raise("mist_eagle", at + Vector3(4, 0, -12))
	mist.mesenlla_mind.on_dive(mist)
	check(seals(MistSeal.Style.MIST).size() == 1, "a Mist Eagle's stoop leaves a ring of mist")
	clear()
	var wyvern := raise("wyvern", at + Vector3(0, 0, -14))
	wyvern.mesenlla_mind.cooldown = 0.0
	check(await until_state(wyvern, "m_breath", 5.0), "a wyvern hovers and breathes")
	check(seals(MistSeal.Style.FIRE).size() == 1, "and fire is coming down in an orange ring")
	var hp0 := p.hp
	await seconds(MesenllaMind.BREATH_TELL + 0.3)
	check(p.hp < hp0 and p.burn_time > 0.0, "staying in it burns")
	clear()
	var war := raise("war_wyvern", at + Vector3(0, 0, -18))
	war.mesenlla_mind.cooldown = 0.0
	check(await until_state(war, "m_breath", 5.0), "the War Wyvern breathes too")
	check(seals(MistSeal.Style.FIRE).size() == 4, "along a line of four rings")
	# Two Children of the Woods ride it with bows and shoot in turn.
	var riders: Array = war._visual.get_meta("riders", [])
	check(riders.size() == 2, "two Children of the Woods ride the War Wyvern")
	var shots := func() -> int: return w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.kind == Projectile.Kind.ENEMY_ARROW).size()
	var shot_most := 0
	for i in 40:
		await seconds(0.1)
		shot_most = maxi(shot_most, shots.call())
	check(shot_most >= 1, "and their arrows fly at whoever is in range (%d in the air at most)" % shot_most)
	war.hp = war.max_hp * 0.45
	await seconds(0.3)
	check(w.count_type("eagle") >= 2, "and below half health it calls eagles")


func _revenant() -> void:
	var at := arena()
	var z := raise("great_revenant_elemental", at + Vector3(0, 0, -4))
	check(z.is_boss() and z.height > 4.0, "the Great Revenant Elemental is a boss, and huge")
	check(z._visual.get_node("BossHealth") != null, "with its name and health over it")
	check(await until_state(z, "m_slam", 6.0), "close by it pounds the ground")
	check(seals(MistSeal.Style.QUAKE).size() == 1 and is_equal_approx(seals(MistSeal.Style.QUAKE)[0].radius, MesenllaMind.QUAKE_RADIUS), "in a wide amber circle")
	at = arena()
	z = raise("great_revenant_elemental", at + Vector3(0, 0, -16))
	z.mesenlla_mind.cooldown_b = 0.0
	check(await until_state(z, "m_throw", 6.0), "further away it throws boulders")
	check(seals(MistSeal.Style.BOULDER).size() == 1, "one at a time")
	await seconds(1.5)
	z.hp = z.max_hp * 0.45
	z.mesenlla_mind.cooldown_b = 0.0
	await seconds(0.3)
	check(z.mesenlla_mind.enraged, "below half health its boulders break loose")
	await until_state(z, "m_throw", 4.0)
	check(seals(MistSeal.Style.BOULDER).size() >= 2, "and it throws two at a time")
	z.stun(3.0)
	check(z._stun <= 0.61, "a boss shrugs off a long stun")


## The Valleys of Mesenlla as a night: its own light, music, creatures, weapons, specials and boss.
func _mesenlla_map() -> void:
	clear()
	w.queue_free()
	await frames(2)
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "mesenlla"
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	p = w.player
	check(w.map_id == "mesenlla" and w.spawn_map() == "mesenlla", "the Valleys of Mesenlla load as their own map")
	check(Game.MAPS.has("mesenlla") and Game.VERSUS_MAPS.has("mesenlla") and Board.MAPS.has("mesenlla"), "playable alone, together and in versus, and counted on the leaderboard")
	check(Sfx.MUSIC_SETS.has("mesenlla") and ResourceLoader.exists("res://assets/music/mesenlla_night.ogg") and ResourceLoader.exists("res://assets/music/mesenlla_hunted.ogg") and ResourceLoader.exists("res://assets/music/mesenlla_dawn.ogg"), "with music of its own")
	check(is_equal_approx(float(w._sky_material.get_shader_parameter("dusk")), 1.0), "under a twilight sky")
	check(p.camera.far >= 200.0, "and a view far enough for the islands in the sky")
	check(p.global_position.y > 4.0 and absf(p.global_position.x) < 20.0, "players start in the outpost on the mountain shoulder (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	var names := w.map_marks.map(func(m: Dictionary) -> String: return m["name"])
	for mark: String in ["Mesenlla Watch", "Ring of Stones", "Woodcutters' Camp", "Rift", "Falls", "boss"]:
		check(names.has(mark), "the map knows its %s" % mark)
	check(not names.has("Great Portal") and not names.has("Hamlet"), "and no longer has a portal or a hamlet")
	var kinds := w.map_features.map(func(f: Dictionary) -> String: return f["kind"])
	check(kinds.count("falls") == 2 and kinds.count("arch") == 3 and kinds.count("rift") == 4 and not kinds.has("portal"), "two waterfalls, three arches of rock and four rifts are drawn on the Map: %s" % str(kinds))
	# The rifts stand above the ground now, not sunk into it.
	var tall_trees := 0
	for mm in w.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh := (mm as MultiMeshInstance3D).multimesh.mesh
		if mesh == MesenllaBuilder.tree_mesh("giant_fir"):
			tall_trees += (mm as MultiMeshInstance3D).multimesh.instance_count
	check(tall_trees >= 40, "the forest has its giant firs (%d)" % tall_trees)
	check(w.get_node_or_null("Ambience") != null, "and its own air: wisps of mist, motes and falling leaves")
	await _mesenlla_south()
	await _mesenlla_camp()
	for z: Zombie in w.zombies:
		check(SpawnRules.is_mesenlla(z.def), "only creatures of Mesenlla are out (%s)" % z.type_id)
	var foreign := 0
	for i in 400:
		var id := ZombieDefs.pick_roamer(600.0, "mesenlla")
		if not ZombieDefs.ALL[id].get("maps", []).has("mesenlla"):
			foreign += 1
	check(foreign == 0, "and only they are chosen to roam")
	var seen := {}
	for i in 600:
		seen[WeaponDefs.pick_random("mesenlla")] = true
	check(seen.has("battleaxe") and seen.has("chakram"), "the Battleaxe and the Rift Chakram lie about")
	check(not seen.has("pitchfork") and not seen.has("scythe") and not seen.has("torch"), "and the Village's farm tools do not")
	check(w.director.requires_regent(), "dawn waits for the boss here too")
	w.director.elapsed = 400.0
	w.director._tick_mesenlla()
	check(w.count_type("eagle") >= 2 and w.count_type("woodland_cavalry") == 1 and w.count_type("wyvern") == 1, "eagles circle in, the Woodland Cavalry ride and a wyvern comes down")
	w.director.elapsed = 520.0
	w.director._tick_mist_boss()
	check(w.count_type("great_revenant_elemental") == 1, "the Great Revenant Elemental rises")
	var boss: Zombie = null
	for z: Zombie in w.zombies:
		if z.type_id == "great_revenant_elemental":
			boss = z
	check(boss != null and Vector2(boss.position.x + 54.0, boss.position.z + 64.0).length() < 8.0, "at the Ring of Stones")
	check(w.director.banner.contains("Great Revenant Elemental"), "and everyone is told")
	var fell_at := boss.position
	boss.take_damage(100000.0, Vector3.ZERO, 0.0, boss.centre())
	await frames(2)
	check(w.director._mist_boss_defeated, "when it falls, dawn can come")
	check(not w.pickups.any(func(i: Pickup) -> bool: return i.item_id == "angel" and Vector2(i.global_position.x - fell_at.x, i.global_position.z - fell_at.z).length() < 8.0), "it leaves no Angel")
	check(w.director.banner.contains("Stone forgets nothing"), "and says its last words: %s" % w.director.banner)
	Game.night_map = "village"


## Mist Bastion: the Great Portal behind three gates, three lanes up to them, the garrison that holds
## them, and the War Wyvern.
func _bastion_map() -> void:
	clear()
	w.queue_free()
	await frames(2)
	Game.mode = Game.Mode.FORT
	Game.fort_map = "bastion"
	check(Game.current_map() == "bastion", "Defend the Fort can be played at Mist Bastion")
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.FORT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate():
		z.release()
	p = w.player
	var fort := w.fort
	check(w.map_id == "bastion" and fort != null, "Mist Bastion loads as a stronghold of its own")
	check(Sfx.music_set == "bastion" and ResourceLoader.exists("res://assets/music/bastion_night.ogg") and ResourceLoader.exists("res://assets/music/bastion_hunted.ogg") and ResourceLoader.exists("res://assets/music/bastion_dawn.ogg"), "with music of its own")
	check(Board.MAPS.has("bastion") and Game.FORT_MAPS.has("bastion"), "chosen like the Fort, and counted on the leaderboard")
	check(fort.gates.map(func(g: Dictionary) -> String: return g["name"]) == ["west", "middle", "east"], "three gates, one for each lane: %s" % str(fort.gates.map(func(g: Dictionary) -> String: return g["name"])))
	check(fort.gates.map(func(g: Dictionary) -> String: return g["short"]) == ["W", "M", "E"], "shown as W, M and E")
	check(fort.doors.size() == 3, "a postern beside each gate")
	check(fort.gates.all(func(g: Dictionary) -> bool: return (g["lane"] as Array).size() == 1), "and each gate the foot of its lane")
	check(is_equal_approx(fort.floor_y, 16.0) and fort.inside(fort.heart_at) and fort.inside(p.global_position), "players start inside the walls, round the Great Portal on the summit")
	check(not fort.on_wall(p.global_position) and fort.on_wall(p.global_position + Vector3.UP * 4.0), "the wall walk counts from the summit, not the valley")
	check(fort.outside_by(fort.heart_at) < 0.0 and fort.outside_by(Vector3(0, 0, 40)) > 60.0, "the walls know how far out a place is")
	check(w.near_wood_spots.size() > 10 and w.field_wood_spots.size() > 10, "wood lies outside the walls to mend the gates (%d near, %d further)" % [w.near_wood_spots.size(), w.field_wood_spots.size()])
	var names := w.map_marks.map(func(m: Dictionary) -> String: return m["name"])
	for mark: String in ["Great Portal", "West Lane", "Middle Lane", "East Lane", "boss"]:
		check(names.has(mark), "the map knows the %s" % mark)
	# Each lane leads to its own gate.
	for g: Dictionary in fort.gates:
		var foot: Vector3 = (g["lane"] as Array)[0]
		var reach := w.grid.flood(foot)
		check(reach.has(w.grid.nearest_free(w.grid.to_cell(fort.gate_front(g, foot)))), "the %s lane climbs to its gate" % g["name"])
	# Nobody gets round the outside of the outer lanes, and the inside of the middle gate is clear.
	var west_reach := w.grid.flood((fort.gates[0]["lane"] as Array)[0])
	var beyond := 0
	for c: Vector2i in west_reach:
		if absf(w.grid.to_world(c).x) > 75.5:
			beyond += 1
	check(beyond == 0, "nothing paths round the outside of the outer spines (%d cells)" % beyond)
	var space := w.get_world_3d().direct_space_state
	for side: float in [-1.0, 1.0]:
		for z: float in [-90.0, -40.0, 30.0, 100.0]:
			var from := Vector3(side * 70.0, w.ground_at(Vector3(side * 70.0, 0, z)) + 1.0, z)
			var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3(side * 10.0, 0, 0), Terrain.BARRIER)
			check(not space.intersect_ray(ray).is_empty(), "an unseen wall stops anyone going beyond x = %.0f at z = %.0f" % [side * 75.0, z])
	var blocked := 0
	for x in range(-3, 4):
		for z in range(-52, -48):
			if not w.grid.is_free(w.grid.to_cell(Vector3(x, 0, z))):
				blocked += 1
	check(blocked == 0, "no stairs stand in front of the middle gate on the inside (%d cells blocked)" % blocked)
	# Only Mesenlla's creatures, and they come up the lanes.
	var plan := Game.zombie_pool_plan()
	check(plan.has("war_wyvern") and not plan.has("great_revenant_elemental") and plan.keys().all(func(m: String) -> bool: return ZombieDefs.ALL.values().any(func(d: Dictionary) -> bool: return d["models"].has(m) and SpawnRules.is_mesenlla(d))), "only creatures of Mesenlla are brought up: %s" % str(plan.keys()))
	w.player.global_position = fort.heart_at + Vector3(0, 0.1, 6)
	var counts := [0, 0, 0]
	var near_foot := 0
	for i in 9:
		if w.spawn_zombie("child_of_woods"):
			var z: Zombie = w.zombies.back()
			counts[z.fort_gate] += 1
			var foot: Vector3 = (fort.gates[z.fort_gate]["lane"] as Array)[0]
			if Vector2(z.position.x - foot.x, z.position.z - foot.z).length() < 12.0:
				near_foot += 1
	check(counts == [3, 3, 3], "each gate gets its share of them: %s" % str(counts))
	check(near_foot == 9, "and they rise at the foot of that gate's lane (%d of 9)" % near_foot)
	check(fort.has_lanes(), "the Bastion's enemies come up long lanes")
	# How far they come over a few seconds, not how fast one is going at one moment: a step can
	# always pause on a bump or a neighbour.
	await seconds(2.0)
	var climbers := w.zombies.filter(func(z: Zombie) -> bool: return z.is_alive() and z.type_id == "child_of_woods")
	var from := climbers.map(func(z: Zombie) -> Vector3: return z.position)
	await seconds(6.0)
	var paces: Array[float] = []
	var marching := 0
	for i in climbers.size():
		var z: Zombie = climbers[i]
		paces.append(Vector2(z.position.x - from[i].x, z.position.z - from[i].z).length() / 6.0)
		if z._marching:
			marching += 1
	paces.sort()
	var middle := paces[paces.size() / 2] if not paces.is_empty() else 0.0
	var walk: float = ZombieDefs.ALL["child_of_woods"]["roam_speed"] * 1.5
	# Three rise together at each foot and jostle at first, so the middle of them is checked against
	# the walk, and the fastest against a run.
	var fastest: float = paces.back() if not paces.is_empty() else 0.0
	# Gates first: someone a little way off is passed by; only someone right in the way is fought.
	var climber: Zombie = climbers[0]
	var keep_at := p.global_position
	p.global_position = climber.position + Vector3(8.0, 0.2, 0)
	check(climber._fort_plan(p, 8.0) and climber._lane_bound(8.0), "lane enemies pass by a player a few steps off and keep on for the gate")
	p.global_position = climber.position + Vector3(1.6, 0.2, 0)
	check(not climber._fort_plan(p, 1.6) and not climber._lane_bound(1.6), "but strike whoever stands right in their way")
	p.global_position = keep_at
	var feet_rifts := 0
	for gate: Dictionary in fort.gates:
		var foot: Vector3 = (gate["lane"] as Array)[0]
		if w.map_features.any(func(f: Dictionary) -> bool: return f["kind"] == "rift" and (f["at"] as Vector2).distance_to(Vector2(foot.x, foot.z)) < 12.0):
			feet_rifts += 1
	check(feet_rifts == 3, "a rift stands at the foot of each lane, where its enemies come out (%d)" % feet_rifts)
	check(marching == climbers.size() and middle > walk and fastest > walk * 1.3, "and come up them at a run, not stopping at the foot (%d of %d running; %.1f m/s for the middle one and %.1f m/s for the fastest, against a %.1f m/s walk)" % [marching, climbers.size(), middle, fastest, walk])
	clear()
	# The garrison.
	var g := w.garrison
	check(g != null, "Mist Bastion has its garrison")
	g.tick(10.0)
	check(w.allies.filter(func(a: Ally) -> bool: return a.is_garrison()).is_empty(), "nobody comes out of the waystones at once")
	g.tick(Garrison.FIRST)
	var soldiers := w.allies.filter(func(a: Ally) -> bool: return a.is_garrison())
	check(soldiers.size() == 3 and soldiers.all(func(a: Ally) -> bool: return a.kind == "mist_infantry") and soldiers.map(func(a: Ally) -> int: return a.lane) == [0, 1, 2], "then a Mist Infantry for each lane")
	check(soldiers.all(func(a: Ally) -> bool: return a.global_position.distance_to(g.mark(a.lane, "muster")) < 2.5 and a.post == g.mark(a.lane, "post")), "stepping out of its lane's waystone, to hold its post")
	check(w.director.banner.contains("Mist Soldiers"), "and everyone is told")
	g.tick(Garrison.FIRST + Garrison.EVERY)
	var second := w.allies.filter(func(a: Ally) -> bool: return a.is_garrison() and a.kind == "mist_ranger")
	check(second.size() == 3, "next comes a Mist Ranger on each lane")
	g.tick(Garrison.FIRST + Garrison.EVERY * 2.0)
	check(w.allies.filter(func(a: Ally) -> bool: return a.is_garrison()).size() == 3 * Garrison.PER_LANE, "and no more than %d hold a lane" % Garrison.PER_LANE)
	check(g.next_kind(0, 100.0) == "mist_infantry" and g.next_kind(0, Garrison.HEAVY_FROM) == "mist_heavy", "the Heavy's turn waits for 3:00")
	check(Ally.HEALTH["mist_infantry"] < 120.0 and Ally.HEALTH["mist_ranger"] < 75.0 and Ally.HEALTH["mist_heavy"] < 225.0 and Ally.GARRISON_BLOW["mist_infantry"] < 0.7, "the Mist Soldiers are about a third weaker than they were")
	var post_reach := [32.0, 17.0, 32.0]
	for i in 3:
		var gate_at: Vector3 = fort.gates[i]["at"]
		check(Vector2(g.mark(i, "post").x - gate_at.x, g.mark(i, "post").z - gate_at.z).length() < post_reach[i], "the %s post is held close below its gate (%.0f m)" % [fort.gates[i]["name"], Vector2(g.mark(i, "post").x - gate_at.x, g.mark(i, "post").z - gate_at.z).length()])
	var walker: Ally = soldiers[1]
	await seconds(9.0)
	check(walker.global_position.distance_to(walker.post) < 3.0, "a soldier walks down to its post (%.1f m off)" % walker.global_position.distance_to(walker.post))
	# They fight what comes near, and nobody is credited with what they kill.
	var kid := raise("child_of_woods", walker.post + Vector3(2.5, 0, 2.5))
	kid.set_physics_process(false)
	var xp_before := p.xp
	await seconds(10.0)
	check(not kid.is_alive() and kid.last_hitter == -1, "the garrison fights what comes near its post (hp %.0f, credited to %d)" % [kid.hp, kid.last_hitter])
	check(p.xp == xp_before, "and its kills are nobody's")
	var heavy := w.spawn_garrison("mist_heavy", 1, walker.post, walker.post)
	var hp_full := heavy.hp
	heavy.hurt(100.0, heavy.global_position)
	check(is_equal_approx(hp_full - heavy.hp, 100.0 * (1.0 - Ally.HEAVY_GUARD)), "the Mist Heavy's shield takes %d%% off every blow" % int(Ally.HEAVY_GUARD * 100.0))
	check(Ally.KINDS.slice(-3) == Garrison.ORDER, "the soldiers travel to other phones by their place among the summons")
	# The Great Portal: what lands on it hurts it.
	var portal_hp := fort.heart_hp
	var seal := MistSeal.create(w, fort.heart_at, 3.0, 0.0, 0.1, 20.0, -1, MistSeal.Style.FIRE)
	await seconds(0.4)
	check(seal != null and fort.heart_hp < portal_hp, "fire landing on the Great Portal hurts it (%.0f)" % (portal_hp - fort.heart_hp))
	# The War Wyvern.
	check(w.director.requires_regent(), "dawn waits for the War Wyvern")
	w.director.elapsed = 520.0
	w.director._tick_mist_boss()
	var boss: Zombie = null
	for z: Zombie in w.zombies:
		if z.type_id == "war_wyvern":
			boss = z
	check(boss != null and w.director.banner.contains("War Wyvern"), "the War Wyvern comes for the Great Portal")
	p.global_position = Vector3(-60, w.ground_at(Vector3(-60, 0, 60)), 60)
	portal_hp = fort.heart_hp
	boss.mesenlla_mind._pass_left = 0.0
	var pass_seals := 0
	for i in 60:
		await seconds(0.25)
		pass_seals = maxi(pass_seals, w.mist_seals.filter(func(s: MistSeal) -> bool: return s.style == MistSeal.Style.FIRE and Vector2(s.position.x - fort.heart_at.x, s.position.z - fort.heart_at.z).length() < 12.0).size())
		if fort.heart_hp < portal_hp:
			break
	check(pass_seals >= 3 and fort.heart_hp < portal_hp, "it makes a burning pass along a lane to the portal (%d circles, %.0f damage)" % [pass_seals, portal_hp - fort.heart_hp])
	var fell_at := boss.position
	boss.take_damage(100000.0, Vector3.ZERO, 0.0, boss.centre())
	await frames(2)
	check(w.director._mist_boss_defeated, "when it falls, dawn can come")
	check(not w.pickups.any(func(i: Pickup) -> bool: return i.item_id == "angel" and Vector2(i.global_position.x - fell_at.x, i.global_position.z - fell_at.z).length() < 8.0), "it leaves no Angel")
	check(w.director.banner.contains("the sky was never yours"), "and says its last words: %s" % w.director.banner)
	Game.fort_map = "fort"
	Game.mode = Game.Mode.SANDBOX


## Each creature of Mesenlla dies in its own way, with its own last sound, and stands up whole when
## the same body is used again.
func _deaths() -> void:
	for id: String in ["bear", "mist_bear", "shapeshifter", "earth_elemental", "mist_elemental", "storm_elemental", "eagle", "wyvern"]:
		var hurt := "zombie_hurt"
		check(Sfx.NAMES.has(Zombie.MESENLLA_DEATHS[id]) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % Zombie.MESENLLA_DEATHS[id]), "%s has a death sound of its own: %s" % [id, Zombie.MESENLLA_DEATHS[id]])
		if Zombie.MESENLLA_HURT.has(id):
			hurt = Zombie.MESENLLA_HURT[id]
			check(Sfx.NAMES.has(hurt) and Net.SOUNDS.has(hurt), "and a hurt sound: %s" % hurt)
	for id: String in ["bear", "earth_elemental", "mist_elemental", "storm_elemental", "wyvern"]:
		clear()
		var z := raise(id, arena() + Vector3(0, 0, -8))
		var body := z._visual
		var rest := {}
		for n in body.find_children("*", "Node3D", true, false):
			if (n as Node3D).has_meta("rest"):
				rest[n] = (n as Node3D).get_meta("rest")
		z.take_damage(z.hp + 10.0, Vector3.ZERO, 0.0, z.centre())
		check(not z.is_alive() and z._death_total == MesenllaModels.death_time(z.model_id), "%s falls over %.1f s" % [id, z._death_total])
		await seconds(z._death_total * 0.55)
		var moved := rest.keys().filter(func(n: Node3D) -> bool: return is_instance_valid(n) and not n.transform.is_equal_approx(rest[n])).size()
		check(moved >= 3 or not body.transform.is_equal_approx(body.get_meta("rest")), "and its body comes down or apart as it dies (%d parts moved)" % moved)
		await seconds(z._death_total * 0.6)
		check(not z.active, "then it is gone")
		# The same body, used again, is whole.
		(w._pools[z.model_id] as Array).erase(z)
		z.spawn(id, arena() + Vector3(0, 0, -8))
		var wrong := rest.keys().filter(func(n: Node3D) -> bool: return not n.transform.is_equal_approx(rest[n])).size()
		check(wrong == 0, "%s stands up whole when it comes back (%d parts out of place)" % [id, wrong])
		z.release()
	# The Woodland Cavalry go down with their bears.
	clear()
	var rider := raise("woodland_cavalry", arena() + Vector3(0, 0, -8))
	check(rider._mounted, "a Woodland Cavalry rides its bear")
	rider.take_damage(rider.hp + 10.0, Vector3.ZERO, 0.0, rider.centre())
	await seconds(0.8)
	check(rider._horse_node.rotation.z > 1.2 and rider._visual.position.y < HorseModel.SADDLE * 0.3, "killed in the saddle, the bear rolls over and the rider falls to the ground")
	await seconds(2.0)
	clear()
	var again := raise("woodland_cavalry", arena() + Vector3(0, 0, -8))
	check(is_zero_approx(again._horse_node.rotation.z) and again._mounted, "the next one rides upright")
