extends Node
## The creatures of Mesenlla, one by one, in a Sandbox: their entries, their bodies, and every special
## move with its tell. Run with tools/run_checks.py creatures.

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
	check(z._custom and z._visual.has_meta("body"), "the bear has a body of its own")
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
	var low := z.hp
	await seconds(1.0)
	check(z.hp > low, "mending as it runs (%.0f to %.0f)" % [low, z.hp])


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
	for mark: String in ["Great Portal", "Ring of Stones", "Hamlet", "Rift", "boss"]:
		check(names.has(mark), "the map knows its %s" % mark)
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
	boss.take_damage(100000.0, Vector3.ZERO, 0.0, boss.centre())
	await frames(2)
	check(w.director._mist_boss_defeated, "when it falls, dawn can come")
	check(w.pickups.any(func(i: Pickup) -> bool: return i.item_id == "angel"), "and it leaves an Angel")
	Game.night_map = "village"
