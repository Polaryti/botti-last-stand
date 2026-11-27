extends Node
## The creatures of Mesenlla, one by one, in a Sandbox: their entries, their bodies, and every special
## move with its tell; then their two maps, the Valleys of Mesenlla and Mist Bastion with its garrison.
## Run with tools/run_checks.py creatures.

var checks := 0
var failures := 0
var w: World
var p: Player

const KINDS := ["bear", "mist_bear", "eagle", "mist_eagle", "shapeshifter", "child_of_woods", "woodland_cavalry", "earth_elemental",
	"mist_elemental", "storm_elemental", "wyvern", "great_revenant_elemental", "war_wyvern", "wyvern_rider"]


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
	var z: Zombie = w.zombies.filter(func(o: Zombie) -> bool: return o.type_id == id).back() # (a War Wyvern's riders rise after it)
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
	for state: String in ["m_swipe", "m_rear", "m_charge", "m_slam", "m_cast", "m_breath", "m_throw", "m_blink", "m_stag", "m_beast", "m_shift", "m_paw"]:
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
		check(ZombieDefs.ALL[id].get("mesenlla_boss", false) and CodexPanel.enemy_group(id) == 8, "%s is listed with the bosses" % id)
	check(CodexPanel.enemy_group("bear") == 4, "the others are Creatures of Mesenlla")
	# The Codex: when an enemy first comes is only shown once you have killed one; bosses and
	# minibosses, called up by the night, never show a clock (they used to read 166:39).
	var kills: Dictionary = Game.killed_kinds.duplicate()
	var timed: Array = ZombieDefs.ALL.keys().filter(func(k: String) -> bool: return float(ZombieDefs.ALL[k].get("from", -1.0)) > 0.0 and float(ZombieDefs.ALL[k]["from"]) < CodexPanel.UNTIMED and not ZombieDefs.ALL[k].get("miniboss", false) and not ZombieDefs.ALL[k].get("carried", false) and not str(ZombieDefs.ALL[k].get("icon", "")).ends_with("+crown"))
	var some: String = timed[0]
	Game.killed_kinds.erase(some)
	check(not CodexPanel.enemy_note(some).contains("Appears from"), "before the first kill the Codex keeps when %s comes to itself" % some)
	Game.killed_kinds[some] = true
	check(CodexPanel.enemy_note(some).contains("Appears from"), "after it, it tells")
	var notes := PackedStringArray()
	for id: String in ZombieDefs.ALL:
		Game.killed_kinds[id] = true
		if CodexPanel.enemy_note(id).contains("166:"): notes.append(id)
	check(notes.is_empty(), "no enemy appears from 166:39 (%s)" % ", ".join(notes))
	for id: String in ["leviathan", "kraken", "hollow_sovereign"]:
		check(str(ZombieDefs.ALL[id]["icon"]).ends_with("+crown") and CodexPanel.enemy_note(id).ends_with("Boss encounter"), "%s wears the boss crown and is a boss encounter" % id)
	check(CodexPanel.enemy_note("harbourmaster").ends_with("Miniboss encounter"), "the Harbourmaster is a miniboss encounter")
	Game.killed_kinds = kills


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
	var sole := z._visual.get_node("Rig/Hind/Torso/LegFL/Knee/Paw") as Node3D
	var turned := 0.0
	for i in 30:
		MesenllaModels.animate(z, z._visual, 0.03, z._speed)
		turned = maxf(turned, sole.rotation.x)
	check(turned > 0.4, "each paw turns its sole back as it lifts (%.2f)" % turned)
	check(z._parts.filter(func(mi: MeshInstance3D) -> bool: return mi.get_meta("own_material", null) == MesenllaModels.fur_material(false)).size() >= 10, "in a coat of fur")
	check(z._visual.get_node_or_null("Rig/Hind/Torso/Head/Jaw") != null, "with a jaw that opens")
	# A hit flashes every part of it, and each part gets its own look back after.
	var eyes: Array = z._parts.filter(func(mi: MeshInstance3D) -> bool: return mi.get_meta("own_material", null) == MesenllaModels.glow_material())
	check(z._parts.size() > 8 and eyes.size() >= 1, "all its parts flash when struck (%d)" % z._parts.size())
	z._flash_on()
	z._restore_materials()
	check(eyes.all(func(mi: MeshInstance3D) -> bool: return mi.material_override == MesenllaModels.glow_material()), "and its glowing eyes glow again after the flash")
	var hp0 := p.hp
	check(await until_state(z, "m_rear", 6.0), "a bear close by rears up first")
	check(z.is_warning(), "and that is its tell")
	await seconds(MesenllaMind.MAUL_TELL * 0.6)
	check((z._visual.get_node("Rig/Hind") as Node3D).rotation.x < -0.8 and (z._visual.get_node("Rig/Hind/Torso/Head/Jaw") as Node3D).rotation.x > 0.4, "up on its hind legs, roaring")
	await seconds(MesenllaMind.MAUL_TELL * 0.4 + 0.3)
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
	check(await until_state(z, "m_paw", 6.0), "a Mist Bear paws the ground before a charge")
	var paw := z._visual.get_node("Rig/Hind/Torso/LegFR") as Node3D
	var rakes := []
	for i in 12:
		await seconds(0.05)
		rakes.append(paw.rotation.x)
	check(rakes.max() - rakes.min() > 0.5 and (z._visual.get_node("Rig/Hind/Torso/Head") as Node3D).rotation.x > 0.25, "head down, raking the ground with a forepaw (%.2f)" % (rakes.max() - rakes.min()))
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
	var mind := z.mesenlla_mind
	check(z._current_anim == "m_stag" and z._damage == 0.0, "the Shapeshifter starts as a harmless stag")
	check((z._visual.get_node("Stag") as Node3D).visible and not (z._visual.get_node("Beast") as Node3D).visible, "and looks like one")
	z.position = Vector3(at.x, w.ground_at(at), at.z - 5.0)
	check(await until_state(z, "m_shift", 4.0), "close by, it changes shape")
	await seconds(MesenllaMind.SHIFT_TIME + 0.2)
	var first := mind.form
	check(first in MesenllaMind.FIGHTING_FORMS and z._damage > 0.0, "into one that can hurt you (%s)" % first)
	await seconds(0.2)
	var node_of := {"beast": "Beast", "wolf": "Wolf", "owl": "Owl", "boar": "Boar"}
	check((z._visual.get_node(node_of[first]) as Node3D).visible and not (z._visual.get_node("Stag") as Node3D).visible, "and looks like it")
	# Every FORM_TIME seconds it takes another shape: each looks its own, moves at its own pace.
	var seen := {first: true}
	for i in 12:
		mind._form_left = 0.0
		await seconds(MesenllaMind.SHIFT_TIME + 0.35)
		var now: String = mind.form
		check(now != "stag" and is_equal_approx(z._speed, float(MesenllaMind.FORM_SPEED[now]) * Game.enemy_speed()) and (z._visual.get_node(node_of[now]) as Node3D).visible, "as the %s it moves at its own pace and looks like one" % MesenllaMind.FORM_NAMES[now])
		seen[now] = true
		if seen.size() == 4:
			break
	check(seen.size() == 4, "beast, wolf, owl and boar in turn (%s)" % str(seen.keys()))
	# The Mist Wolf howls and the creatures round it are hastened; then it lunges.
	z.hp = z.max_hp
	mind._begin_shift(z, "wolf")
	await seconds(MesenllaMind.SHIFT_TIME + 0.1)
	var friend := raise("bear", z.position + Vector3(3, 0, 0))
	friend.set_physics_process(false)
	mind.cooldown_b = 0.0
	mind._form_left = 60.0
	z.position = Vector3(at.x, w.ground_at(at), at.z - 6.0)
	check(await until_state(z, "m_howl", 3.0), "the Mist Wolf howls")
	await seconds(MesenllaMind.HOWL_TIME + 0.1)
	check(friend.haste_left > 0.0 and friend._desired_speed() > 0.0, "and the creatures near it are hastened")
	var calm := friend._speed
	friend.state = Zombie.State.CHASE
	check(friend._desired_speed() > calm * 1.2, "faster than they were (%.1f, was %.1f)" % [friend._desired_speed(), calm])
	friend.release()
	mind.cooldown = 0.0
	z.position = Vector3(at.x, w.ground_at(at), at.z - 6.0)
	var hp0 := p.hp
	check(await until_state(z, "m_lunge", 3.0) and z.is_warning(), "it crouches before it lunges")
	await seconds(MesenllaMind.LUNGE_TELL + MesenllaMind.LUNGE_TIME + 0.1)
	check(p.hp < hp0, "and the lunge lands (%.0f)" % (hp0 - p.hp))
	# The Great Owl takes to the air and dives.
	p.hp = p.max_hp()
	mind._begin_shift(z, "owl")
	await seconds(MesenllaMind.SHIFT_TIME + 0.1)
	mind._form_left = 60.0
	mind.cooldown = 99.0
	await seconds(1.5)
	check(z.position.y - w.ground_at(z.position) > MesenllaMind.OWL_HEIGHT * 0.6, "the Great Owl circles high, out of reach (%.1f m)" % (z.position.y - w.ground_at(z.position)))
	mind.cooldown = 0.0
	hp0 = p.hp
	check(await until_state(z, "m_owl", 0.1) and await until_state(z, "m_dive", 4.0), "then screeches and dives")
	await seconds(1.4)
	check(p.hp < hp0, "talons first (%.0f)" % (hp0 - p.hp))
	# The Tusked Boar paws the ground, charges and knocks you down.
	p.hp = p.max_hp()
	p.frozen_left = 0.0
	p._status_immune = 0.0
	mind._begin_shift(z, "boar")
	await seconds(MesenllaMind.SHIFT_TIME + 0.1)
	mind._form_left = 60.0
	mind.cooldown_b = 0.0
	z.position = Vector3(at.x, w.ground_at(at), at.z - 10.0)
	check(await until_state(z, "m_paw", 3.0), "the Tusked Boar paws the ground")
	check(await until_state(z, "m_charge", 2.0), "and charges")
	hp0 = p.hp
	var knocked := false
	for i in 20:
		await seconds(0.05)
		knocked = knocked or p.frozen_left > 0.0
	check(p.hp < hp0 and knocked, "knocking you down (%.0f)" % (hp0 - p.hp))
	p.frozen_left = 0.0
	# Badly hurt, back to the stag, and away.
	z.hp = z.max_hp * 0.2
	await seconds(MesenllaMind.SHIFT_TIME + 0.6)
	check(mind.form == "stag" and mind.phase == "flee", "badly hurt, it turns back into the stag and flees")
	check(absf(z._speed - float(ZombieDefs.ALL["shapeshifter"]["speed"]) * 1.15 * Game.enemy_speed()) < 0.01, "running as fast as the stag can")
	var low := z.hp
	await seconds(MesenllaMind.STAG_FLEE * 0.5)
	check(is_equal_approx(z.hp, low) and mind.phase == "flee", "it does not mend while it runs (%.0f to %.0f)" % [low, z.hp])
	await seconds(MesenllaMind.STAG_FLEE * 0.5 + 0.2)
	check(is_equal_approx(z.hp, z.max_hp), "not caught within %d seconds, it comes back whole (%.0f of %.0f)" % [int(MesenllaMind.STAG_FLEE), z.hp, z.max_hp])
	await seconds(MesenllaMind.SHIFT_TIME + 0.2)
	check(mind.form in MesenllaMind.FIGHTING_FORMS, "and fights again (%s)" % mind.form)
	check(str(ZombieDefs.ALL["shapeshifter"]["desc"]).contains("every %d seconds" % int(MesenllaMind.FORM_TIME)), "the Codex says how often it changes shape")
	for state: String in ["m_wolf", "m_bite", "m_lunge", "m_howl", "m_owl", "m_dive", "m_boar", "m_gore"]:
		check(Net.ANIMS.has(state), "%s reaches other phones" % state)
	z.release()


## The south of the Valleys, the edge of the land, and the tents of the camp.
func _mesenlla_south() -> void:
	var names := w.map_marks.map(func(m: Dictionary) -> String: return m["name"])
	for mark: String in ["Fallen Hall", "Hunters' Lodge", "Old Mine", "Mossy Spring"]:
		check(names.has(mark), "the south has its %s" % mark)
	check(w.cache_spots.size() == 3 and w.cache_spots.all(func(at: Vector3) -> bool: return at.z > 60.0), "three caches of rarer finds, all in the south")
	# The lodge stands on dry ground and can be walked into; the mine is cut into its slope; the
	# bridge runs with the road, straight across a river that runs east to west under it.
	var lodge := Vector3(-40, 0, 90)
	check(w.terrain.height(lodge.x, lodge.z) > 0.3 and not w.terrain.in_water(lodge.x, lodge.z), "the Hunters' Lodge stands on dry ground (%.1f)" % w.terrain.height(lodge.x, lodge.z))
	var lodge_ways := 0
	for from: Vector3 in [Vector3(-40, 0, 97), Vector3(-30, 0, 90), Vector3(-50, 0, 90), Vector3(-40, 0, 80)]:
		if w.in_reach(from) and w.terrain.is_walkable(from.x, from.z):
			lodge_ways += 1
	check(lodge_ways == 4 and w.in_reach(lodge + Vector3(0, 0, 1.0)), "it can be walked up to from every side, and into (%d of 4 sides)" % lodge_ways)
	var wet := PhysicsRayQueryParameters3D.create(Vector3(-40, 3.0, 104), Vector3(-40, 3.0, 94), Terrain.BARRIER)
	check(w.get_world_3d().direct_space_state.intersect_ray(wet).is_empty(), "nothing unseen stands between the south and its door")
	var yard := Vector3(68, 0, 86)
	check(absf(w.ground_at(yard) - 6.0) < 0.2 and absf(w.ground_at(Vector3(74, 0, 86)) - 6.0) < 0.3 and w.ground_at(Vector3(82, 0, 86)) > 10.0, "the Old Mine opens off a level yard, with the hill rising behind it (%.1f, %.1f, %.1f)" % [w.ground_at(yard), w.ground_at(Vector3(74, 0, 86)), w.ground_at(Vector3(82, 0, 86))])
	check(w.in_reach(yard), "and its yard can be walked to")
	check(w.terrain.on_deck(-8.0, 54.0) and w.terrain.on_deck(-8.0, 59.0) and w.terrain.on_deck(-8.0, 64.0) and not w.terrain.on_deck(-14.0, 59.0), "the bridge runs north to south with the road")
	check(w.terrain.in_water(-14.0, 59.4) and w.terrain.in_water(-1.0, 57.6) and not w.terrain.in_water(-8.0, 51.0) and not w.terrain.in_water(-8.0, 67.0), "over a river that runs east to west under it")
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
	# And nobody stands on one: wherever you land on a tent, it is too steep to stand on.
	var flat_tops := 0
	var looked := 0
	for at: Vector3 in [Vector3(-14, 6, -34), Vector3(-14, 6, -26), Vector3(14, 6, -34), Vector3(15, 6, -24), Vector3(-7, 6, -19)]:
		for dx: float in [-1.0, -0.4, 0.0, 0.4, 1.0]:
			var down := PhysicsRayQueryParameters3D.create(Vector3(at.x + dx, w.ground_at(at) + 8.0, at.z), Vector3(at.x + dx, w.ground_at(at) + 0.3, at.z), 1)
			var hit := space.intersect_ray(down)
			if hit.is_empty():
				continue
			looked += 1
			if (hit["normal"] as Vector3).y > cos(p.floor_max_angle) + 0.01:
				flat_tops += 1
	check(looked >= 15 and flat_tops == 0, "and no tent has anywhere flat enough to stand on top (%d flat of %d)" % [flat_tops, looked])
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
	check(w.ground_shunned(siege.centre) and w.grid.astar.get_point_weight_scale(w.grid.to_cell(siege.centre)) > 5.0, "from then on ways are planned round it, and bots keep off it")
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
	kid.take_damage(10000.0, Vector3.ZERO, 0.0, kid.centre())
	var left := {"weapon": 0, "arrows": 0, "food": 0, "": 0}
	for n in 6000:
		left[Zombie.loot(ZombieDefs.ALL["child_of_woods"])] += 1
	var dropped: int = left["weapon"] + left["arrows"] + left["food"]
	check(dropped > 1080 and dropped < 1320, "falling, it leaves something one time in five (%d of 6000)" % dropped)
	check([left["weapon"], left["arrows"], left["food"]].all(func(n: int) -> bool: return absf(float(n) / float(dropped) - 1.0 / 3.0) < 0.06), "and that is its weapon, arrows or food, a third each (%d, %d, %d)" % [left["weapon"], left["arrows"], left["food"]])
	check(Zombie.loot(ZombieDefs.ALL["clever"]) == "weapon" and ZombieDefs.ALL["woodland_cavalry"]["loot"] == ZombieDefs.ALL["child_of_woods"]["loot"] and is_equal_approx(ZombieDefs.ALL["woodland_cavalry"]["loot_chance"], 0.2), "others still always drop their weapon; the riders are Children too")
	var count_of := func(kind: Pickup.Kind) -> int: return w.pickups.filter(func(q: Pickup) -> bool: return q.kind == kind).size()
	var before := [count_of.call(Pickup.Kind.WEAPON), count_of.call(Pickup.Kind.ARROWS), count_of.call(Pickup.Kind.FOOD)]
	seed(20261115) # the same falls every run
	for n in 30:
		var child := raise("child_of_woods", at + Vector3((n % 10) * 1.5 - 7.0, 0, -18 - (n / 10) * 1.5))
		child.take_damage(10000.0, Vector3.ZERO, 0.0, child.centre())
		child.release() # its body back to the pool for the next one; what it left stays
	randomize()
	var after := [count_of.call(Pickup.Kind.WEAPON) - before[0], count_of.call(Pickup.Kind.ARROWS) - before[1], count_of.call(Pickup.Kind.FOOD) - before[2]]
	check(after[0] + after[1] + after[2] > 0 and after[0] + after[1] + after[2] < 15, "thirty Children fallen leave a few things on the ground: %s weapons, arrows, food" % str(after))
	var rider := raise("woodland_cavalry", at + Vector3(0, 0, -14))
	check(rider._mounted and rider._horse_node.visible and rider._horse_node.get_node_or_null("Rig/Hind/Torso/Saddle") != null, "Woodland Cavalry ride bears, in a saddle")
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
	check(wyvern.element in ["fire", "ice", "storm"] and (wyvern._visual.get_meta("rig") as WyvernRig).element == wyvern.element, "a wyvern rises as Fire, Ice or Storm, and looks it (%s)" % wyvern.element)
	var kinds := {}
	for i in 60:
		var e: String = ZombieDefs.ALL["wyvern"]["elements"].pick_random()
		kinds[e] = true
	check(kinds.size() == 3, "each of the three as likely")
	wyvern.set_element("fire")
	wyvern.mesenlla_mind.cooldown = 0.0
	check(await until_state(wyvern, "m_breath", 5.0), "a wyvern hovers and breathes")
	check(seals(MistSeal.Style.FIRE).size() == 1, "a Fire wyvern's fire is coming down in an orange ring")
	var hp0 := p.hp
	await seconds(MesenllaMind.BREATH_TELL + 0.3)
	check(p.hp < hp0 and p.burn_time > 0.0, "staying in it burns")
	await seconds(0.5)
	p.burn_time = 0.0
	clear()
	wyvern = raise("wyvern", at + Vector3(0, 0, -14))
	wyvern.set_element("ice")
	wyvern.mesenlla_mind.cooldown = 0.0
	check(await until_state(wyvern, "m_breath", 5.0) and seals(MistSeal.Style.FROST).size() == 1, "an Ice wyvern breathes frost")
	p.frozen_left = 0.0
	p._status_immune = 0.0
	await seconds(MesenllaMind.BREATH_TELL + 0.3)
	check(p.is_iced and p.slowed_left > 0.0, "which freezes you, and slows you after")
	p.frozen_left = 0.0
	p.slowed_left = 0.0
	wyvern.mesenlla_mind.on_dive(wyvern)
	check(seals(MistSeal.Style.FROST).any(func(m: MistSeal) -> bool: return is_equal_approx(m.radius, MesenllaMind.DIVE_BURST_RADIUS)), "and where it dives, its frost bursts")
	clear()
	wyvern = raise("wyvern", at + Vector3(0, 0, -14))
	wyvern.set_element("storm")
	wyvern.mesenlla_mind.cooldown = 0.0
	check(await until_state(wyvern, "m_breath", 5.0) and seals(MistSeal.Style.STORM).size() == 1, "a Storm wyvern calls lightning down")
	await seconds(1.6)
	p.frozen_left = 0.0
	clear()
	var war := raise("war_wyvern", at + Vector3(0, 0, -18))
	war.set_element("fire")
	war.mesenlla_mind.cooldown = 0.0
	check(await until_state(war, "m_breath", 5.0), "the War Wyvern breathes too")
	check(seals(MistSeal.Style.FIRE).size() == 4, "along a line of four rings")
	# Two Children of the Woods ride it with bows and shoot in turn, each a creature of its own.
	var riders: Array = w.zombies.filter(func(r: Zombie) -> bool: return r.carrier == war)
	check(riders.size() == 2 and riders.all(func(r: Zombie) -> bool: return r.type_id == "wyvern_rider" and r.weapon_id == "bow"), "two Children of the Woods ride the War Wyvern")
	await frames(2)
	var seat := (war._visual.get_meta("rig") as WyvernRig).body.get_node("Seat0") as Node3D
	check((riders[0] as Zombie).global_position.distance_to(seat.global_position) < 0.05, "in its saddle")
	var shots := func() -> int: return w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.kind == Projectile.Kind.ENEMY_ARROW).size()
	var shot_most := 0
	for i in 40:
		await seconds(0.1)
		shot_most = maxi(shot_most, shots.call())
	check(shot_most >= 1, "and their arrows fly at whoever is in range (%d in the air at most)" % shot_most)
	var first := riders[0] as Zombie
	var second := riders[1] as Zombie
	var war_hp := war.hp
	first.take_damage(first.hp + 1.0, Vector3.ZERO, 0.0, first.centre())
	check(not first.is_alive() and second.is_alive() and is_equal_approx(war.hp, war_hp), "one can be shot out of the saddle on its own")
	var fell_from := first.position.y
	await seconds(0.4)
	check(first.position.y < fell_from - 1.0, "and falls")
	war.take_damage(war.hp - war.max_hp * 0.45, Vector3.ZERO, 0.0, war.centre())
	await frames(1)
	check(w.count_type("eagle") >= 2, "and the blow that takes it below half health calls eagles, at once")
	war.take_damage(war.hp + 1.0, Vector3.ZERO, 0.0, war.centre())
	check(not second.is_alive(), "when the War Wyvern falls, its rider falls with it")


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
	check(w.director.boss_card == "great_revenant_elemental" and w.director.boss_card_time > 0.0 and w.director.banner_time == 0.0, "and everyone is told by its entrance card, not an ordinary banner")
	for kind: String in Director.BOSS_CARDS:
		var card: Dictionary = Director.BOSS_CARDS[kind]
		check(ZombieDefs.ALL[kind]["name"] == card["name"] and Sfx.NAMES.has(card["bells"]) and Net.SOUNDS.has(card["bells"]) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % card["bells"]), "%s: its card has its name and its bells" % kind)
		check(Director.BOSS_CARDS.values().filter(func(c: Dictionary) -> bool: return c["color"] == card["color"]).size() == 1, "%s: a colour of its own" % kind)
	# Every boss, the Veil Regent of the Mists too, and any boss to come: an entrance card with what it
	# says as it comes, and what it says as it falls.
	for id: String in ZombieDefs.ALL:
		var d: Dictionary = ZombieDefs.ALL[id]
		if d.get("mist_boss", false) or d.get("mesenlla_boss", false):
			check(Director.BOSS_CARDS.has(id), "%s enters with a card" % id)
			check(str(d.get("first_words", "")).length() > 12 and str(d.get("last_words", "")).length() > 12, "%s speaks as it comes and as it falls" % id)
	var fell_at := boss.position
	boss.take_damage(100000.0, Vector3.ZERO, 0.0, boss.centre())
	await frames(2)
	check(w.director._mist_boss_defeated, "when it falls, dawn can come")
	check(w.director.banner.contains(str(ZombieDefs.ALL["great_revenant_elemental"]["last_words"])) and w.director.banner.begins_with("Great Revenant Elemental: \u201c"), "and it says its last words: %s" % w.director.banner)
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
			# Behind the foot, between it and the rift: never further up the lane than the foot itself.
			if Vector2(z.position.x - foot.x, z.position.z - foot.z).length() < 10.0 and z.position.z > foot.z - 0.5:
				near_foot += 1
	check(counts == [3, 3, 3], "each gate gets its share of them: %s" % str(counts))
	check(near_foot == 9, "and they rise at the very end of that gate's lane (%d of 9)" % near_foot)
	# Even with someone standing at a lane's foot: there is nowhere else on a lane to come from.
	w.player.global_position = (fort.gates[2]["lane"] as Array)[0] + Vector3(0, 0.3, -6)
	var east_before := w.zombies.size()
	var rose_east := 0
	for i in 3:
		if w.spawn_zombie("child_of_woods"):
			var z: Zombie = w.zombies.back()
			if z.fort_gate == fort.lane_at(z.position):
				rose_east += 1
	check(rose_east == 3 and w.zombies.size() == east_before + 3, "nobody rises on one lane to walk to another, wherever the players stand (%d of 3)" % rose_east)
	w.player.global_position = fort.heart_at + Vector3(0, 0.1, 6)
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
	# On its lane a zombie fights like anywhere else, but never leaves the lane for anyone.
	var climber: Zombie = climbers.filter(func(z: Zombie) -> bool: return z.fort_gate == 1)[0]
	var keep_at := p.global_position
	climber._sees = true
	p.global_position = climber.position + Vector3(3.0, 0.2, -5.0)
	check(not climber._fort_plan(p, 5.8), "a lane enemy goes for a player it sees on its lane")
	p.global_position = Vector3(-46.0, w.ground_at(Vector3(-46, 0, climber.position.z)) + 0.2, climber.position.z)
	check(climber._fort_plan(p, 46.0) and fort.lane_at(p.global_position) == 0, "but not for one on another lane: it keeps on for its gate")
	# Someone in sight at the side of its lane, out of its reach: it looks up its road while it goes
	# on, not at them over its shoulder.
	var road := fort.lane_ahead(climber.fort_gate, climber.position, Zombie.LANE_AHEAD) - climber.position
	road.y = 0.0
	road = road.normalized()
	var aside := road.cross(Vector3.UP).normalized()
	p.global_position = climber.position + aside * (Zombie.LANE_REACH + 3.0) + Vector3.UP * 0.2
	p.global_position.y = w.ground_at(p.global_position) + 0.2
	var to_side := p.global_position - climber.position
	climber._sees = true
	climber._attack_left = 0.0
	climber._on_duty = climber._fort_plan(p, to_side.length())
	climber.rotation.y = atan2(to_side.x, to_side.z)
	for i in 40:
		climber._face(to_side, to_side.length(), road, 0.05)
	var facing := Vector3(sin(climber.rotation.y), 0, cos(climber.rotation.y))
	check(climber._on_duty and facing.dot(road) > 0.95, "a lane enemy that only sees someone beside its lane looks ahead as it goes (%.2f along its road)" % facing.dot(road))
	climber._attack_left = 0.4
	climber._attack_aim = Vector3.INF
	for i in 40:
		climber._face(to_side, to_side.length(), road, 0.05)
	facing = Vector3(sin(climber.rotation.y), 0, cos(climber.rotation.y))
	check(facing.dot(to_side.normalized()) > 0.95, "and turns to them only for a blow or a shot it aims at them")
	climber._attack_left = 0.0
	climber._on_duty = false
	climber._hold = false
	climber._sees = true
	climber.state = Zombie.State.CHASE
	for i in 40:
		climber._face(to_side, to_side.length(), road, 0.05)
	facing = Vector3(sin(climber.rotation.y), 0, cos(climber.rotation.y))
	check(facing.dot(to_side.normalized()) > 0.95, "while one it is fighting, it faces")
	p.global_position = fort.heart_at + Vector3(0, 0.1, 6)
	check(climber._fort_plan(p, 99.0), "nor for one inside the walls")
	# The road, not the slopes: the spot it aims for is always on its lane's road, a little ahead.
	var off_road := 0.0
	var behind := 0
	for z: Zombie in climbers:
		var aim := fort.lane_ahead(z.fort_gate, z.position, Zombie.LANE_AHEAD)
		off_road = maxf(off_road, fort.off_lane(z.fort_gate, aim))
		off_road = maxf(off_road, fort.off_lane(z.fort_gate, z.position) - 3.5)
		if aim.z > z.position.z + 0.5:
			behind += 1
	check(off_road < 0.1 and behind == 0, "they keep to the road of their lane on the way up (%.1f m off it, %d aiming back)" % [off_road, behind])
	for gate: Dictionary in fort.gates:
		var way: Array[Vector3] = gate["way"]
		check(way.size() >= 8 and way[0] == (gate["lane"] as Array)[0] and way.back().distance_to(gate["at"]) < 3.0, "the %s lane's road runs from its foot to its gate (%d points)" % [gate["name"], way.size()])
	# A gate that falls on another lane changes nothing for it; its own gate fallen is its way in.
	fort.hit_gate(fort.gates[0], 99999.0, fort.gates[0]["at"])
	check(fort.gate_for(climber)["i"] == 1 and climber.fort_gate == 1, "a gate fallen on another lane draws nobody off theirs")
	var west_one: Zombie = climbers.filter(func(z: Zombie) -> bool: return z.fort_gate == 0)[0]
	var west_front := fort.gate_front(fort.gates[0], west_one.position)
	west_one.position = west_front + Vector3(-1.0, 0, 0)
	west_one._fort_plan(p, 99.0)
	check(west_one._has_goal and fort.inside(west_one._goal), "through its own fallen gate, into the walls")
	west_one.position = (fort.gates[0]["at"] as Vector3) + Vector3(4.0, 0, 0)
	p.global_position = Vector3(46, w.ground_at(Vector3(46, 0, 0)) + 0.2, 0)
	west_one._fort_plan(p, 99.0)
	check(west_one._goal.distance_to(fort.heart_at) < 3.0, "and from there on to the portal")
	fort.repair(0, 99999.0)
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
	check(soldiers.all(func(a: Ally) -> bool: return a.global_position.distance_to(g.mark(a.lane, "muster")) < 2.5), "stepping out of its lane's waystone")
	check(w.director.banner.contains("Mist Soldiers"), "and everyone is told")
	g.tick(Garrison.FIRST + Garrison.EVERY)
	var second := w.allies.filter(func(a: Ally) -> bool: return a.is_garrison() and a.kind == "mist_ranger")
	check(second.size() == 3, "next comes a Mist Ranger on each lane")
	g.tick(Garrison.FIRST + Garrison.EVERY * 2.0)
	check(w.allies.filter(func(a: Ally) -> bool: return a.is_garrison()).size() == 3 * Garrison.PER_LANE, "and no more than %d hold a lane" % Garrison.PER_LANE)
	check(g.next_kind(0, 100.0) == "mist_infantry" and g.next_kind(0, Garrison.HEAVY_FROM) == "mist_heavy", "the Heavy's turn waits for 3:00")
	check(Ally.HEALTH["mist_infantry"] < 120.0 and Ally.HEALTH["mist_ranger"] < 75.0 and Ally.HEALTH["mist_heavy"] < 225.0 and Ally.GARRISON_BLOW["mist_infantry"] < 0.7, "the Mist Soldiers are about a third weaker than they were")
	# They stand before their gate, and fight what comes to break it.
	var walker: Ally = soldiers[1]
	var mid_gate: Dictionary = fort.gates[1]
	var mid_front := fort.gate_front(mid_gate, (mid_gate["at"] as Vector3) + (mid_gate["dir"] as Vector3) * 5.0)
	await seconds(9.0)
	for a: Ally in soldiers:
		var their_gate: Dictionary = fort.gates[a.lane]
		var off := Vector2(a.global_position.x - (their_gate["at"] as Vector3).x, a.global_position.z - (their_gate["at"] as Vector3).z).length()
		check(off < 8.0 and not fort.inside(a.global_position), "the %s lane's soldier stands before its gate (%.1f m from it)" % [their_gate["name"], off])
	var kid := raise("child_of_woods", mid_front + Vector3(0.6, 0, 0))
	kid.set_physics_process(false)
	var xp_before := p.xp
	await seconds(10.0)
	check(not kid.is_alive() and kid.last_hitter == -1, "the garrison fights what comes to break its gate (hp %.0f, credited to %d)" % [kid.hp, kid.last_hitter])
	check(p.xp == xp_before, "and its kills are nobody's")
	# Its gate fallen, it falls back through the gateway to the portal, and holds that.
	fort.hit_gate(mid_gate, 99999.0, mid_gate["at"])
	await seconds(9.0)
	var mid_guard := w.allies.filter(func(a: Ally) -> bool: return a.is_garrison() and a.lane == 1 and not a.dead)
	var at_portal := mid_guard.filter(func(a: Ally) -> bool: return a.fell_back and fort.inside(a.global_position) and a.global_position.distance_to(fort.heart_at) < 9.0).size()
	check(not mid_guard.is_empty() and at_portal == mid_guard.size(), "with their gate fallen, its soldiers fall back to the portal (%d of %d there)" % [at_portal, mid_guard.size()])
	var others := w.allies.filter(func(a: Ally) -> bool: return a.is_garrison() and a.lane != 1 and not a.dead)
	check(others.all(func(a: Ally) -> bool: return not a.fell_back and not fort.inside(a.global_position)), "while the other lanes' soldiers stay before their own gates")
	var raider := raise("child_of_woods", fort.heart_at + Vector3(0, 0, 3.0))
	raider.set_physics_process(false)
	await seconds(10.0)
	check(not raider.is_alive(), "and there they fight what has got inside (hp %.0f)" % raider.hp)
	fort.repair(1, 99999.0)
	var heavy := w.spawn_garrison("mist_heavy", 1, walker.post, walker.post)
	var hp_full := heavy.hp
	heavy.hurt(100.0, heavy.global_position)
	check(is_equal_approx(hp_full - heavy.hp, 100.0 * (1.0 - Ally.HEAVY_GUARD)), "the Mist Heavy's shield takes %d%% off every blow" % int(Ally.HEAVY_GUARD * 100.0))
	check(Ally.KINDS.find(Garrison.ORDER[0]) == 15 and Ally.KINDS.slice(15, 18) == Garrison.ORDER, "the soldiers travel to other phones by their place among the summons, which never changes")
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
	check(boss != null and w.director.boss_card == "war_wyvern" and w.director.boss_card_time > 0.0, "the War Wyvern comes for the Great Portal, with its own entrance card")
	p.global_position = Vector3(-60, w.ground_at(Vector3(-60, 0, 60)), 60)
	portal_hp = fort.heart_hp
	check(w.zombies.filter(func(r: Zombie) -> bool: return r.carrier == boss).size() == 2, "its two riders with it, though the Children of the Woods were many tonight")
	boss.set_element("fire")
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
