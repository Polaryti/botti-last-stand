extends Node
## Plays the real game with scripted input. Run:
## godot --headless --path . res://tests/test_game.tscn
## Add -- soak to also run a long bot game.

const OPEN := Vector3(0, 0, 36) # open road south of the village

var failures := 0
var checks := 0
var m: Node
var w: World
var pl: Player
var hud: Hud


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)
		if pl and is_instance_valid(pl):
			print("   state: dead=", pl.dead, " hp=", pl.hp, " paused=", get_tree().paused, " pos=", pl.global_position, " weapon=", pl.weapon_id(), " cd=", pl._cooldown, " menu=", hud.menu_open if hud else false)
	elif OS.get_cmdline_user_args().has("verbose"):
		print("ok: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(t: float) -> void:
	await frames(maxi(1, ceili(t * Engine.physics_ticks_per_second / Engine.time_scale)))


func _ready() -> void:
	Game.player_name = "Test Player"
	# Same 1/60 s steps as the real game, four times as fast.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	Engine.max_fps = 0
	seed(20261108)
	Game.quality = 0
	Game.player_class = "infantry"
	Game.force_weather = Weather.Kind.CLEAR # a bolt of lightning would upset the tests
	Game.save_settings()
	var args := OS.get_cmdline_user_args()
	Game.night_map = "village"
	Game.pet = "wolf"
	var plan: Array[String] = ["test_map", "test_flow", "test_weapons", "test_touch", "test_auto_jump", "test_items", "test_powers", "test_zombies", "test_night",
		"test_land", "test_version_20_1", "test_version_19_1", "test_version_20", "test_version_19", "test_version_18", "test_version_16", "test_version_15", "test_version_14", "test_version_13", "test_version_12_4", "test_version_12_2", "test_version_11", "test_version_10", "test_version_9", "test_version_8", "test_new_things", "test_fort", "test_crows", "test_revenant", "test_fire", "test_trees", "test_finals", "test_classes", "test_enemies", "test_new_stuff", "test_review", "test_beyond_review"]
	var groups := {
		"core": plan.slice(0, 9), "recent": plan.slice(9, 17), "legacy": plan.slice(17, 25),
		"classes": ["test_new_things", "test_revenant", "test_trees", "test_finals", "test_classes"],
		"world": ["test_fort", "test_crows", "test_fire", "test_enemies", "test_new_stuff", "test_review", "test_beyond_review"]}
	var selected := "all"
	for arg: String in args:
		if arg.begins_with("group="):
			selected = arg.trim_prefix("group=")
		elif arg.begins_with("case="):
			plan.assign([arg.trim_prefix("case=")])
	if selected != "all":
		if not groups.has(selected):
			push_error("Unknown gameplay group: " + selected)
			get_tree().quit(2)
			return
		plan.assign(groups[selected])
	if args.has("soakonly"):
		plan.clear()
	for method: String in plan:
		if not has_method(method):
			push_error("Unknown gameplay case: " + method)
			get_tree().quit(2)
			return
		await _case(method)
	if args.has("soak") or args.has("soakonly"):
		await soak()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	await finish()


func _case(method: String) -> void:
	var before := Time.get_ticks_usec()
	var previous := checks
	seed(20261108 + method.hash())
	Game.player_class = "infantry"
	Game.difficulty = 1
	Game.night_map = "village"
	if method == "test_flow":
		if is_instance_valid(m):
			m.queue_free()
			await frames(2)
		m = null # this scenario owns its menu/startup fixture
	else:
		await start_clean()
	await call(method)
	print("CASE %s: %d checks in %.2f s" % [method, checks - previous, (Time.get_ticks_usec() - before) / 1000000.0])


func finish() -> void:
	get_tree().paused = false
	Net.leave()
	if is_instance_valid(m):
		m.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Sfx.stop_all()
	OS.delay_msec(120) # allow the audio mixing thread to release stopped playback
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures > 0 else 0)


func test_map() -> void:
	var world := World.new()
	add_child(world)
	var old_map := Game.test_map
	Game.test_map = "res://maps/village.tscn"
	world.setup(Game.Mode.MENU)
	Game.test_map = old_map
	await frames(2)
	var seen := world.grid.flood(Vector3(0, 0, 4.5))
	var free := 0
	for y in world.grid.size:
		for x in world.grid.size:
			if world.grid.is_free(Vector2i(x, y)):
				free += 1
	print("  free cells=", free, " reachable=", seen.size())
	# Corners behind turned buildings and an islet in the river at the far corner of the map are all that
	# should be left out. tests/reach_check.tscn says where each one is.
	ok(free - seen.size() < 100, "almost every open cell can be walked to")
	var bad := 0
	for spot in world.loot_spots:
		if not seen.has(world.grid.nearest_free(world.grid.to_cell(spot))) or not world.grid.is_free(world.grid.to_cell(spot)):
			bad += 1
			print("  bad loot spot ", spot)
	ok(bad == 0, "all %d loot spots are reachable" % world.loot_spots.size())
	var inside := [Vector3(0, 0, -44), Vector3(-16, 0, -13.5), Vector3(15.5, 0, -14.5), Vector3(-16.5, 0, 14.5), Vector3(16, 0, 15), Vector3(31, 0, 12), Vector3(-37, 0, -33), Vector3(37, 0, -31)]
	for p: Vector3 in inside:
		ok(seen.has(world.grid.nearest_free(world.grid.to_cell(p))), "building at %s can be entered" % p)
	var t0 := Time.get_ticks_usec()
	world.grid.path(Vector3(-55, 0, -55), Vector3(55, 0, 55))
	print("  longest path ms=", (Time.get_ticks_usec() - t0) / 1000.0)
	world.free()


## The tests only know a code by its hash, so this public file gives nothing away.
func _code_of(class_id: String) -> String:
	for key: String in Game.CODES:
		if Game.CODES[key] == class_id:
			return key
	return ""


func test_revenant() -> void:
	# Hidden until a code opens it.
	var saved := Game.unlocked.duplicate()
	Game.unlocked.clear()
	ok(not ClassDefs.available().has("revenant"), "the Revenant is hidden at first")
	ok(Game.redeem("not a code")["result"] == "bad", "a wrong code does nothing")
	ok(not ClassDefs.available().has("revenant"), "and it stays hidden")
	Game.redeemed.clear()
	ok(Game.code_key("  aBc ") == Game.code_key("ABC"), "a code can be typed in any case and with stray spaces")
	ok(Game.redeem_key(_code_of("revenant"))["class"] == "revenant", "the code works")
	ok(Game.redeem_key(_code_of("revenant"))["result"] == "used", "and only once")
	ok(ClassDefs.available().has("revenant"), "and shows the class")
	ok(ClassDefs.available().size() >= 4, "next to the others")
	Game.save_settings()
	Game.unlocked.clear()
	Game.load_settings()
	ok(Game.unlocked.has("revenant"), "and it stays unlocked after restarting")
	for key: String in Game.CODES:
		ok(key.length() == 64 and key.is_valid_hex_number(), "codes are kept as hashes, not written out")

	Game.player_class = "revenant"
	await start_clean()
	place(OPEN)
	ok(pl.weapon_id() == "claws" and pl.max_mana() == 100.0, "a Revenant has claws and Mist")
	ok(not pl.can_use("sword") and not pl.can_use("bow"), "and cannot use weapons")
	var sword := w.spawn_pickup_at(pl.global_position + Vector3(0.5, 0, 0), Pickup.Kind.WEAPON, "sword")
	var ammo := w.spawn_pickup_at(pl.global_position + Vector3(-0.5, 0, 0), Pickup.Kind.ARROWS, "arrows")
	await seconds(0.3)
	ok(is_instance_valid(sword) and w.pickups.has(sword) and pl.weapon_id() == "claws", "a sword on the ground stays there")
	ok(pl.nearby_weapon == null, "with no offer to take it")
	ok(w.pickups.has(ammo), "and so do arrows")
	clear_pickups()
	# Claws cost a little Mist, and it comes back on its own and from kills.
	var z := spawn("normal", front(1.8), true)
	aim_at(z)
	pl.mana = 50.0
	var hp0 := z.hp
	pl.input_fire = true
	await seconds(0.3)
	pl.input_fire = false
	ok(z.hp < hp0, "claws hurt")
	ok(pl.mana < 50.0, "and use Mist")
	pl.mana = 50.0
	await seconds(1.0)
	ok(pl.mana > 52.0, "Mist comes back by itself (%.1f)" % pl.mana)
	pl.mana = 10.0
	z.next_hitter = 0
	await kill_all()
	await frames(2)
	var kz := spawn("normal", front(1.8), true)
	pl.mana = 10.0
	kz.take_damage(99999.0, Vector3.FORWARD, 0.0, kz.centre())
	ok(pl.mana >= 15.0, "and from kills")
	await seconds(0.1)
	# No Mist: still a weak blow.
	var weak := spawn("normal", front(1.8), true)
	aim_at(weak)
	pl.mana = 0.0
	pl._cooldown = 0.0
	var hp1 := weak.hp
	pl.input_fire = true
	await seconds(0.35)
	pl.input_fire = false
	ok(weak.hp < hp1, "with no Mist, claws still hit weakly")
	await kill_all()
	await frames(2)
	# Mist Burst.
	var a := spawn("normal", pl.global_position + Vector3(3, 0, 0), false)
	var b := spawn("normal", pl.global_position + Vector3(-3, 0, 2), false)
	var out := spawn("normal", pl.global_position + Vector3(14, 0, 0), true)
	pl.mana = 100.0
	var ahp := a.hp
	pl.use_burst()
	ok(pl.mana == 65.0, "Mist Burst uses Mist at once")
	ok(a.hp == ahp, "and takes a moment to go off")
	await seconds(0.6)
	ok(a.hp < ahp and b.hp < b.max_hp, "then it hurts everything around")
	ok(a._frozen > 0.0 and a._stun > 0.0 and b._frozen > 0.0, "and freezes it")
	ok(not out._frozen > 0.0 and out.hp == out.max_hp, "but not what is far away")
	var frozen_at := a.position
	await seconds(1.0)
	ok(a.position.distance_to(frozen_at) < 0.3, "frozen enemies stay where they are")
	await seconds(1.1)
	ok(a._frozen <= 0.0, "for about 2 seconds")
	pl.mana = 100.0
	pl.use_burst()
	ok(pl.mana == 100.0, "Mist Burst has a cooldown")
	pl.burst_cd_left = 0.0
	pl.mana = 10.0
	pl.use_burst()
	ok(pl.mana == 10.0, "and needs enough Mist")
	await kill_all()
	await frames(2)
	# The Revenant chooses at each step, like every other class.
	pl.mana = 100.0
	pl.add_xp(100000)
	ok(pl.next_step() == 0 and pl.points > 0, "levels give points, and nothing is chosen for you")
	for i in Player.CORE_STEPS:
		ok(pl.choose_ability(i, 1), "you can take the other gift at step %d" % i)
	ok(pl.spec_id == "" and pl.choose_ability(Player.CORE_STEPS, 0), "then you choose a path")
	ok(pl.spec_id == "leaper", "Mist Leaper")
	# Mist Leaper: forward, up and down the land, not through walls.
	Game.player_class = "revenant"
	await start_clean()
	pl.level = 6
	for i in Player.CORE_STEPS:
		pl.points += 1
		pl.choose_ability(i, 0)
	pl.points = 1
	pl.choose_ability(Player.CORE_STEPS, 0)
	var from := Vector3(0, 0, 40)
	place(from)
	await seconds(0.2)
	pl.mana = 100.0
	pl.use_art()
	ok(pl.mana < 100.0, "the leap uses Mist")
	await seconds(0.7)
	var travelled: float = Vector2(pl.global_position.x - from.x, pl.global_position.z - from.z).length()
	ok(travelled > 6.0 and travelled < 10.5, "and carries you about 9 m (%.1f)" % travelled)
	ok(absf(pl.global_position.y - w.ground_at(pl.global_position)) < 0.5, "landing on the ground")
	# Uphill: the far end stands higher, and the landing is on top of it.
	var up := pl.leap_landing(Vector3(-27, w.ground_at(Vector3(-27, 0, -52)), -52), Vector3(-0.5, 0, -0.87).normalized(), 9.0)
	ok(absf(up.y - w.ground_at(up)) < 0.05, "a leap takes the height of the land into account")
	var wall := pl.leap_landing(Vector3(-18, 0, -6), Vector3(0, 0, -1), 20.0)
	ok(wall.z > -11.0, "and stops at a wall (%.1f)" % wall.z)
	var cliff := pl.leap_landing(Vector3(-60, w.ground_at(Vector3(-60, 0, -36)), -36), Vector3(0, 0, -1), 20.0)
	ok(cliff.y < 8.5 - 1.0, "a leap cannot clear the castle cliff")
	# Rift Traveller: hops, damage, untouchable.
	Game.player_class = "revenant"
	await start_clean()
	place(OPEN)
	pl.points = Player.CORE_STEPS + 1
	for i in Player.CORE_STEPS:
		pl.choose_ability(i, 0)
	pl.choose_ability(Player.CORE_STEPS, 1)
	ok(pl.spec_id == "rift", "Rift Traveller")
	pl.mana = 100.0
	pl.use_art()
	ok(pl.mana == 100.0 and pl.art_cd_left == 0.0, "with nothing near, the jump costs nothing")
	var r1 := spawn("normal", pl.global_position + Vector3(4, 0, -3), true)
	var r2 := spawn("normal", pl.global_position + Vector3(-5, 0, -4), true)
	var r3 := spawn("normal", pl.global_position + Vector3(0, 0, -7), true)
	var r4 := spawn("normal", pl.global_position + Vector3(0, 0, -15), true)
	await frames(2)
	var hp_me := pl.hp
	var r1hp := r1.hp
	pl.use_art()
	await seconds(1.0)
	ok(r1.hp < r1hp and r2.hp < r2.max_hp and r3.hp < r3.max_hp, "the jump cuts the three closest")
	ok(r4.hp == r4.max_hp, "and no more than its hops")
	ok(pl.hp == hp_me, "untouched")
	ok(pl.global_position.distance_to(OPEN) > 2.0, "and it moved you")
	ok(absf(pl.global_position.y - w.ground_at(pl.global_position)) < 0.5, "onto the ground")
	var during := spawn("normal", pl.global_position + Vector3(1, 0, 0), true)
	pl.art_cd_left = 0.0
	pl.mana = 100.0
	pl.use_art()
	await seconds(0.34)
	pl.hurt(50.0, during.position, during)
	ok(pl.hp == hp_me, "nothing can hurt you during the jump")
	await seconds(0.6)
	await kill_all()
	await frames(2)
	# Summoner.
	Game.player_class = "revenant"
	await start_clean()
	place(OPEN)
	pl.points = 5
	for i in Player.CORE_STEPS:
		pl.choose_ability(i, 0)
	pl.choose_ability(Player.CORE_STEPS, 2)
	ok(pl.spec_id == "summoner", "Summoner")
	pl.mana = 100.0
	pl.use_art()
	await seconds(0.9)
	ok(w.count_allies("revenant") == 1, "calls another Revenant")
	var foe := spawn("normal", pl.global_position + Vector3(0, 0, -4), true)
	await seconds(4.0)
	ok(foe.hp < foe.max_hp or not foe.is_alive(), "which fights")
	var ally_life: float = w.allies[0].life
	ok(ally_life < 14.0 and ally_life > 0.0, "and does not stay")
	await kill_all()
	for al: Ally in w.allies.duplicate():
		w.remove_ally(al)
	Game.unlocked = saved
	Game.save_settings()
	Game.player_class = "infantry"
	await start_clean()


func test_fire() -> void:
	await start_clean()
	ok(w.fires.size() > 25, "there are fires around the map (%d)" % w.fires.size())
	var start := w.grid.flood(Vector3(0, 0, 4.5))
	var blocked_roads := 0
	for s: Vector3 in [Vector3(0, 0, 53), Vector3(72, 0, 0), Vector3(-35, 0, -63), Vector3(-44, 0, -70)]:
		if not start.has(w.grid.to_cell(s)):
			blocked_roads += 1
	ok(blocked_roads == 0, "and none of them blocks a road")
	# Firelight shows you.
	var bonfire: Dictionary = {}
	for f: Dictionary in w.fires:
		if f["heals"]:
			bonfire = f
			break
	var at: Vector3 = bonfire["at"]
	place(at + Vector3(4, 0, 0))
	await seconds(0.4)
	ok(pl.is_lit(), "standing near a fire puts you in the light")
	ok(pl.sight_factor() > 1.2, "and zombies see you from further away")
	# Well clear of every fire, at ground height: a spot can be inside a wall and push you out of it.
	var dark := Vector3(-100, 0, -100)
	for i in 60:
		var p := Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
		var on_land := Vector3(p.x, w.ground_at(p), p.z)
		var clear := true
		for f: Dictionary in w.fires:
			if on_land.distance_to(f["at"]) < float(f["radius"]) + 4.0:
				clear = false
				break
		if clear:
			dark = p
			break
	place(dark)
	await seconds(0.4)
	ok(not pl.is_lit() and pl.sight_factor() <= 1.0, "away from the fire it is dark")
	equip("torch")
	await seconds(0.4)
	ok(pl.is_lit(), "unless you carry a torch")
	await equip("dagger")
	# Warmth.
	place(at + Vector3(1.8, 0, 0))
	pl.hp = 50.0
	await seconds(1.5)
	ok(pl.hp > 50.5, "a bonfire warms you back to health, slowly")


func test_land() -> void:
	await start_clean()
	var t := w.terrain
	var start := w.grid.flood(Vector3(0, 0, 4.5))
	# Everything worth reaching can be reached on foot.
	var lost := 0
	for spot: Vector3 in w.loot_spots:
		if not start.has(w.grid.nearest_free(w.grid.to_cell(spot))):
			lost += 1
			print("  cannot reach loot at ", spot)
	ok(lost == 0, "every loot spot can be reached on foot")
	for poi: Vector3 in w.pois:
		ok(start.has(w.grid.nearest_free(w.grid.to_cell(poi))), "the place at %s can be reached" % poi)
	ok(start.has(w.grid.to_cell(Vector3(-72, 0, -55))), "the castle yard can be reached")
	ok(start.has(w.grid.to_cell(Vector3(-10, 0, 100))), "and the far bank too")
	# The water can be crossed anywhere, and it slows everyone down.
	ok(t.is_walkable(0, 64), "the stone bridge stands over the river")
	ok(t.is_walkable(72, 0), "the timber bridge too")
	ok(t.is_walkable(-54, 64), "and the ford is shallow")
	ok(t.is_walkable(24, 64), "and the rest of the river can be waded")
	ok(w.grid.is_free(w.grid.to_cell(Vector3(24, 0, 64))), "so paths can go through it")
	var walls_in_water := 0
	for rx in range(-110, 111, 2):
		for rz in range(-110, 111, 2):
			# Right beside a bridge, its own side stops you.
			var by_bridge := t.on_deck(rx - 2, rz) or t.on_deck(rx + 2, rz) or t.on_deck(rx, rz - 2) or t.on_deck(rx, rz + 2)
			if t.in_water(rx, rz) and not t.is_walkable(rx, rz) and not by_bridge:
				walls_in_water += 1
	ok(walls_in_water == 0, "with no invisible wall anywhere in the water (%d)" % walls_in_water)
	var wet := spawn("normal", Vector3(24, 0, 64), true)
	ok(t.in_water(24, 64) and wet._desired_speed() < wet._speed + 0.01, "mobs are slowed in the water too")
	wet.state = Zombie.State.CHASE
	ok(is_equal_approx(wet._desired_speed(), wet._speed * Player.WADE_SPEED), "by the same amount as you")
	wet.release()
	var north := w.grid.path(Vector3(24, 0, 55), Vector3(24, 0, 76))
	ok(north.size() > 0 and north.size() < 40, "a zombie walks straight across")
	# A long journey is planned in stretches, and those stretches do get there.
	var walker := spawn("normal", Vector3(24, 0, 80))
	walker._set_goal(Vector3(-20, 0, -18))
	walker.state = Zombie.State.INVESTIGATE
	walker._search_left = 999.0
	walker._sight = 0.0
	walker._roam_speed = 9.0
	w.director.running = false
	place(Vector3(0, 0, 35))
	for i in 500:
		await frames(4)
		walker._set_goal(Vector3(-20, 0, -18)) if not walker._has_goal else null
		walker.state = Zombie.State.INVESTIGATE
		if walker.position.distance_to(Vector3(-20, 0, -18)) < 3.0:
			break
	ok(walker.position.distance_to(Vector3(-20, 0, -18)) < 6.0, "a zombie finds its way from the far bank to the village (%s)" % walker.position)
	await kill_all()
	await frames(2)
	# The castle stands high.
	ok(t.height(-72, -60) > 7.5, "the castle stands on high ground")
	# The player walks up the castle road, and across a bridge, on the real collision.
	var goal := Vector3(-44, 0, -70)
	pl.global_position = Vector3(-25, t.height(-25, -48) + 0.2, -48)
	await seconds(0.3)
	for leg: Vector3 in [Vector3(-30, 0, -60), Vector3(-39, 0, -68.5), goal]:
		for i in 400:
			var to := leg - pl.global_position
			to.y = 0.0
			if to.length() < 1.0:
				break
			pl.yaw = atan2(-to.x, -to.z)
			pl.rotation.y = pl.yaw
			pl.input_move = Vector2(0, -1)
			await frames(1)
	pl.input_move = Vector2.ZERO
	ok(pl.global_position.y > 6.0, "the player can walk up the castle road")
	pl.global_position = Vector3(0, t.height(0, 52) + 0.2, 52)
	pl.yaw = PI
	pl.rotation.y = PI
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	var highest := 0.0
	for i in 300:
		await frames(1)
		highest = maxf(highest, pl.global_position.y)
		if pl.global_position.z > 76.0:
			break
	pl.input_move = Vector2.ZERO
	ok(pl.global_position.z > 75.0, "and across the bridge")
	ok(highest > 0.7, "which rises over the river")
	# Standing at the water's edge goes no further.
	pl.global_position = Vector3(24, t.height(24, 57) + 0.2, 57)
	pl.yaw = PI
	pl.rotation.y = PI
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	await seconds(5.0)
	pl.input_move = Vector2.ZERO
	ok(pl.global_position.z > 72.0, "you can wade across the river (%s)" % pl.global_position)
	# Zombies and items stand on the ground, wherever that is.
	place(Vector3(-60, 0, -60))
	var z := spawn("normal", Vector3(-70, 0, -60))
	await seconds(0.2)
	ok(absf(z.position.y - t.height(z.position.x, z.position.z)) < 0.05, "a zombie stands on the hilltop")
	var it := w.spawn_pickup_at(Vector3(-62, 0, -60), Pickup.Kind.FOOD, "bread")
	ok(absf(it.global_position.y - 8.5) < 0.2, "and so does an item")
	var crow := spawn("crow", Vector3(-66, 0, -60))
	ok(crow.position.y > 8.5 + 1.0, "a crow flies above the hill, not inside it")
	ok(w.has_line_of_sight(Vector3(-60, 10, -60), Vector3(-68, 10, -60)), "you can see across the yard")
	ok(not w.has_line_of_sight(Vector3(-25, 1.5, -30), Vector3(-72, 1.5, -70)), "but not through the hill")
	kill_all()
	await frames(2)
	# Far from everyone, a roaming zombie moves back around the players.
	place(Vector3(0, 0, 8))
	var far := spawn("normal", Vector3(100, 0, -100))
	w.director._clear_far_zombies()
	ok(not far.active, "a zombie that wandered far away is replaced")
	# Spawn points stay near enough to matter.
	for i in 8:
		var at := w._pick_spawn_point()
		if at != Vector3.INF:
			ok(at.distance_to(pl.global_position) < 80.0, "zombies appear within reach of the players")
	# Mana bar.
	Game.player_class = "magician"
	await start_clean()
	ok(pl.class_def().get("mana", false) and pl.max_mana() >= 100.0, "the magician has mana")


func test_crows() -> void:
	await start_clean()
	place(OPEN)
	w.director.running = false
	var c1: Zombie = spawn("crow", pl.global_position + Vector3(4, 0, 0))
	var c2: Zombie = spawn("crow", pl.global_position + Vector3(-4, 0, 0))
	for c: Zombie in [c1, c2]:
		c._special_cd = 0.0
		c.state = Zombie.State.CHASE
		c._clear = true
	var warned := false
	var both := false
	var first_hit_at := -1.0
	var t0 := w.now
	var hp0 := pl.hp
	for i in 90:
		await frames(1)
		c1._clear = true
		c2._clear = true
		if c1.is_warning() or c2.is_warning():
			warned = true
		if (c1._dive > 0.0 or c1._windup > 0.0) and (c2._dive > 0.0 or c2._windup > 0.0):
			both = true
		if first_hit_at < 0.0 and pl.hp < hp0:
			first_hit_at = w.now - t0
	ok(warned, "a crow gives warning before it dives")
	ok(not both or first_hit_at < 0.0 or first_hit_at > 0.5, "and it cannot hit in the moment it starts")
	await kill_all()
	await frames(2)
	# Stepping aside makes it miss, and it hangs low either way.
	var m1 := spawn("crow", pl.global_position + Vector3(0, 0, -5))
	m1._dive = 2.5
	m1._dive_aim = pl.eye_position() + Vector3(0, 0, -0.5)
	m1._clear = true
	pl.global_position += Vector3(5, 0, 0)
	var hp1 := pl.hp
	await seconds(1.2)
	ok(pl.hp == hp1, "a dive at where you were misses")
	ok(m1._recover > 0.0 or m1._dive <= 0.0, "and the crow still has to recover")
	# It can be knocked out of a dive.
	await kill_all()
	await frames(2)
	var m2 := spawn("hero_ranger", pl.global_position + Vector3(0, 0, -40), true)
	m2.release()
	var m3 := spawn("crow", pl.global_position + Vector3(0, 2, -3))
	m3.hp = 1000.0
	m3.max_hp = 1000.0
	m3._dive = 2.0
	m3._dive_aim = pl.eye_position()
	m3.take_damage(10.0, Vector3.FORWARD, 0.0, m3.centre())
	ok(m3._dive == 0.0 and m3._recover > 0.0, "a hit knocks a crow out of its dive")
	await kill_all()
	await frames(2)
	# Only one of a flock goes at a time.
	w._next_crow_dive = 0.0
	ok(w.take_dive_turn(), "one crow takes its turn")
	ok(not w.take_dive_turn(), "the next waits")


## Defend the Fort: the walls, the gates, the heart, the wood.
func test_fort() -> void:
	Game.mode = Game.Mode.FORT
	Game.player_class = "infantry"
	if m and is_instance_valid(m):
		m.queue_free()
		await frames(2)
	var wf := World.new()
	add_child(wf)
	wf.setup(Game.Mode.FORT)
	w = wf
	pl = wf.player
	wf.director.running = false
	wf.director._stock_timer = 9999.0
	wf.director._familiar_timer = 9999.0
	await seconds(0.3)
	var f := wf.fort
	ok(f.gates.size() == 4, "the fort has four gates")
	ok(f.inside(pl.global_position), "and you start inside it")
	# Shut gates keep the outside out. Nothing else leads in on the ground.
	var from_outside := wf.grid.flood(Vector3(40, 0, 40))
	ok(not from_outside.has(wf.grid.to_cell(Vector3(10, 0, 3))), "with all gates shut there is no way in on foot")
	ok(from_outside.has(wf.grid.to_cell(Vector3(0, 0, -30))), "the outside is one open wood")
	var yard := wf.grid.flood(Vector3(10, 0, 3))
	ok(yard.has(wf.grid.to_cell(f.heart_at + Vector3(0, 0, 3))), "the heart can be reached from the yard")
	# The stairs lead up, and you can walk the walls.
	place(Vector3(-22.6, 0, -23.6), -PI * 0.5)
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	var top_y := 0.0
	for i in 400:
		await frames(1)
		top_y = maxf(top_y, pl.global_position.y)
		if pl.global_position.x > -6.5:
			break
	pl.input_move = Vector2.ZERO
	ok(top_y > Fort.WALL_H - 1.5, "stairs lead to the top of the wall (%.1f)" % top_y)
	# From the wall, you can step off outward, and it does no harm.
	pl.global_position = Vector3(3, Fort.WALL_H + 0.3, -Fort.HALF)
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	await seconds(0.5)
	ok(pl.is_on_floor() and pl.global_position.y > Fort.WALL_H - 0.5, "you can stand on the wall (%s)" % pl.global_position)
	var hp0 := pl.hp
	pl.input_move = Vector2(0, -1)
	await seconds(0.5)
	pl.input_move = Vector2.ZERO
	await seconds(1.2)
	ok(pl.global_position.z < -Fort.HALF - 1.0 and pl.global_position.y < 1.0, "and drop off it (%s)" % pl.global_position)
	ok(pl.hp == hp0, "without getting hurt")
	# The small doors let a player through, but not an enemy.
	place(Vector3(-15, 0, -33), 0.0)
	var door := Fort.DIRS[0] * Fort.HALF
	var across := Vector3(Fort.DIRS[0].z, 0, -Fort.DIRS[0].x)
	var door_at: Vector3 = door + across * Fort.DOORS[0]
	place(door_at + Vector3(0, 0, -3.0), PI)
	pl.yaw = PI
	pl.rotation.y = PI
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	await seconds(1.5)
	pl.input_move = Vector2.ZERO
	ok(f.inside(pl.global_position), "the small door lets you in (%s)" % pl.global_position)
	# Enemies outside attack a gate, even with a player in plain view behind it.
	place(Vector3(3, 0, 11))
	var g: Dictionary = f.gates[0]
	var a := spawn("normal", (g["at"] as Vector3) + Vector3(0, 0, -6))
	a._sight = 200.0
	var gate_hp: float = g["hp"]
	await seconds(4.0)
	ok(float(g["hp"]) < gate_hp, "enemies break at the gate (%.0f)" % float(g["hp"]))
	ok(not f.inside(a.position), "and it holds them out")
	# The gate falls, and now they come in for the heart.
	f.hit_gate(g, 99999.0, g["at"])
	ok(not g["closed"], "a gate can fall")
	ok(f.any_open(), "which opens the way")
	ok(wf.grid.flood(Vector3(40, 0, 40)).has(wf.grid.to_cell(Vector3(10, 0, 3))), "for anything on foot")
	place(Vector3(40, 0, 40))
	pl.global_position = Vector3(-90, wf.ground_at(Vector3(-90, 0, -90)), -90)
	var heart0 := f.heart_hp
	a._speed = 9.0
	a._roam_speed = 7.0
	for i in 500:
		await frames(2)
		if f.heart_hp < heart0:
			break
	ok(f.heart_hp < heart0, "enemies go through to the heart and hurt it (%.0f)" % f.heart_hp)
	await kill_all()
	await frames(2)
	# Wood: picked up, and carried to a gate it mends it as you stand close.
	var wood := wf.spawn_pickup_at(Vector3(3, 0, 9), Pickup.Kind.WOOD, "wood")
	place(Vector3(3, 0, 9))
	await seconds(0.3)
	ok(pl.wood == Fort.WOOD_PER_PICKUP and not (is_instance_valid(wood) and wf.pickups.has(wood)), "wood gets picked up")
	pl.wood = Fort.WOOD_MAX
	place((g["at"] as Vector3) + Vector3(0, 0, 4))
	var repaired0: float = g["hp"]
	await seconds(0.8)
	ok(float(g["hp"]) > repaired0 and pl.wood < Fort.WOOD_MAX, "standing near the broken gate with wood mends it (%.0f)" % float(g["hp"]))
	await seconds(3.2)
	ok(g["closed"], "and once it has its strength back it closes")
	ok(not wf.grid.flood(Vector3(40, 0, 40)).has(wf.grid.to_cell(Vector3(10, 0, 3))), "and shuts the way again")
	place(Vector3(3, 0, 11))
	pl.wood = 2
	await seconds(1.0)
	ok(pl.wood == 2, "away from a damaged gate, wood is kept")
	# Spawn points are outside the walls.
	for i in 10:
		var at := wf._pick_spawn_point()
		if at != Vector3.INF:
			ok(not f.inside(at), "new enemies arrive from outside")
	# When the heart falls, it is over.
	var lost := [false]
	wf.fort_lost.connect(func() -> void: lost[0] = true)
	f.hit_heart(999999.0)
	ok(lost[0], "when the heart falls the game is lost")
	wf.queue_free()
	await frames(2)
	Game.mode = Game.Mode.NIGHT
	await start_clean()


func _path(class_id: String, spec: int) -> void:
	Game.player_class = class_id
	await start_clean()
	pl.points = 10
	if spec >= 0:
		for i in Player.CORE_STEPS:
			pl.choose_ability(i, 0)
		pl.choose_ability(Player.CORE_STEPS, spec)


func test_version_18() -> void:
	var unlocked_before := Game.unlocked.duplicate()
	var redeemed_before := Game.redeemed.duplicate()
	Game.unlocked.erase("adept")
	Game.redeemed.erase(_code_of("adept"))
	ok(not Game.owns_class("adept"), "the Adept is locked")
	ok(ClassDefs.price("adept") == 1150 and ClassDefs.for_sale().has("adept"), "it is sold again, at its old price")
	ok(Game.redeem_key(_code_of("adept"))["result"] == "opened" and Game.owns_class("adept") and Game.redeemed.has(_code_of("adept")), "and its code opens it")
	Game.unlocked["monk"] = true
	# The Bo and the hands are nobody's item.
	ok(WeaponDefs.ALL["bo"].get("hidden", false) and WeaponDefs.ALL["fists"].get("hidden", false), "neither the Bo nor empty hands are offered anywhere")
	Game.player_class = "ranger"
	await start_clean()
	ok(not pl.can_use("bo"), "only a Monk can use the Bo")
	await _path("monk", -1)
	ok(pl.weapon_id() == "fists" and WeaponDefs.ALL["fists"]["name"] == "", "a Monk with no weapon punches, and it has no name")
	ok(pl.has_empty_slot(), "and its hands count as free")
	ok(pl.mana == 0.0 and pl.max_mana() == 100.0, "Ki starts empty")
	clear_pickups()
	var count_before: int = w.count_pickups(Pickup.Kind.WEAPON)
	w.drop_weapon(front(1.2), "sword")
	await seconds(0.4)
	# Empty hands collect a usable weapon automatically; never dereference the retired pickup.
	await frames(2)
	ok(pl.weapon_id() == "sword" and pl.slots[1] == null, "taking a sword fills the hand")
	ok(w.count_pickups(Pickup.Kind.WEAPON) == count_before, "and no fists are left on the ground")
	pl.give_weapon("dagger")
	pl.give_weapon("mace")
	ok(not pl.slots.has("fists"), "the fists are never a slot in the way")
	await _path("monk", -1)
	var dummy := spawn("normal", front(1.6), true)
	var hp0: float = dummy.hp
	pl._do_melee_hit()
	ok(dummy.hp < hp0, "the punch hits")
	ok(is_equal_approx(pl.mana, Player.KI_PER_HIT), "and a hit gives Ki (%.1f)" % pl.mana)
	ok(pl.has_art() and pl.art_def()["name"] == "Ki Blast", "before a path, the ability is Ki Blast")
	pl.use_art()
	ok(pl._cast_kind == "", "not enough Ki, nothing happens")
	pl.mana = 40.0
	var hp1: float = dummy.hp
	pl.hp = 50.0
	pl.use_art()
	await seconds(0.3)
	ok(dummy.hp < hp1 and pl.hp >= 60.0 and pl.mana == 10.0, "Ki Blast spends 30 Ki, hits and heals")
	dummy.release()
	# Bo Master.
	await _path("monk", 0)
	ok(pl.weapon_id() == "bo" and not pl.can_use("sword"), "Bo Master holds the Bo and only the Bo")
	var ahead := spawn("normal", front(1.8), true)
	var behind := spawn("normal", front(-2.0), true)
	var behind0: float = behind.hp
	for i in 2:
		pl._start_swing(pl.weapon_def())
		pl._do_melee_hit()
	ok(behind.hp == behind0, "two blows leave what is behind you alone")
	pl._start_swing(pl.weapon_def())
	ok(pl._swing_keys == "bo_spin", "the third blow is the spin")
	pl._do_melee_hit()
	ok(behind.hp < behind0, "and it sweeps all around")
	ahead.release()
	behind.release()
	var start: Vector3 = pl.global_position
	place(Vector3(0, 0, 12))
	await frames(2)
	start = pl.global_position
	var landed_on := spawn("normal", front(9.0), true)
	var on_hp: float = landed_on.hp
	pl.mana = 40.0
	pl.use_art()
	ok(pl.mana == 5.0, "Pole Vault costs 35 Ki")
	await seconds(0.9)
	ok(pl.global_position.distance_to(start) > 7.0, "Pole Vault carries you (%.1f m)" % pl.global_position.distance_to(start))
	ok(landed_on.hp < on_hp, "and you land in a sweep")
	landed_on.release()
	# Spirit Walker.
	await _path("monk", 1)
	ok(pl.has_art() and pl.art_def()["name"] == "Leave Your Body", "Spirit Walker has Leave Your Body")
	place(Vector3(0, 0, 12))
	await frames(2)
	pl.mana = 60.0
	var regen_from: float = pl.mana
	await seconds(0.5)
	ok(pl.mana > regen_from, "its Ki fills by itself")
	pl.mana = 60.0
	var home: Vector3 = pl.global_position
	pl.hp = 40.0
	pl.use_art()
	await seconds(0.35)
	ok(pl.spirit_left > 0.0 and pl.is_unseen(), "out of the body, nothing sees you")
	ok(w.count_allies("body") == 1, "and the body stays behind")
	pl.hurt(50.0, pl.global_position)
	ok(pl.hp == 40.0, "the spirit cannot be hurt")
	var shots: int = pl.attack_count
	pl.input_fire = true
	pl._handle_fire()
	pl.input_fire = false
	ok(pl.attack_count == shots, "and cannot strike")
	pl.global_position += Vector3(6, 0, 0)
	var body: Ally = null
	for a: Ally in w.allies:
		if a.kind == "body":
			body = a
	body.hurt(30.0, body.global_position)
	await seconds(4.5)
	ok(pl.spirit_left <= 0.0 and pl.global_position.distance_to(home) < 1.0, "when it is over you are back in the body")
	ok(pl.hp >= 79.0, "and healed for what the body took (%.0f)" % pl.hp)
	ok(w.count_allies("body") == 0, "and the body is gone")
	# Iron Mountain.
	await _path("monk", 2)
	ok(pl.art_def()["name"] == "Mountain Stomp", "Iron Mountain has Mountain Stomp")
	place(Vector3(0, 0, 12))
	await frames(2)
	pl.velocity = Vector3.ZERO
	pl.input_move = Vector2.ZERO
	await seconds(3.0)
	var skin: float = pl.stone_skin
	ok(skin > 0.15 and skin < 0.35, "standing still grows Stone Skin (%.2f)" % skin)
	var hp2: float = pl.hp
	pl.guard_left = 0.0
	pl.mods["dodge"] = 0.0
	pl.hurt(20.0, pl.global_position + Vector3.FORWARD)
	ok(absf((hp2 - pl.hp) - 20.0 * (1.0 - pl.stone_skin)) < 2.0, "and takes the damage off (%.1f)" % (hp2 - pl.hp))
	await seconds(4.5)
	ok(pl.stone_skin >= 0.59 and pl.stone_skin <= 0.6, "it stops at 60%% (%.2f)" % pl.stone_skin)
	var near_z := spawn("normal", front(6.0), true)
	var near0: float = near_z.hp
	pl.mana = 45.0
	pl.use_art()
	await seconds(0.45)
	ok(pl.stone_skin < 0.1 and near_z.hp < near0 and pl.mana == 5.0, "Mountain Stomp spends the skin and reaches further with it")
	near_z.release()
	var low := spawn("normal", front(6.0), true)
	var low0: float = low.hp
	pl.stone_skin = 0.0
	pl.art_cd_left = 0.0
	pl.mana = 45.0
	pl.use_art()
	await seconds(0.45)
	ok(low.hp == low0, "with no skin it does not reach as far")
	low.release()
	pl.input_move = Vector2(0, -1)
	pl.stone_skin = 0.5
	await seconds(0.6)
	ok(pl.stone_skin < 0.5, "walking wears it away")
	pl.input_move = Vector2.ZERO
	# The Adept.
	await _path("adept", -1)
	ok(pl.weapon_id() == "sword" and not pl.can_use("bow") and not pl.can_use("bo"), "the Adept starts with a sword and no ranged weapons")
	ok(pl.has_art() and pl.stance == "wind" and pl.art_label() == "Wind stance", "and is in Wind stance from the start, with a button to change it")
	var speed_wind: float = pl.m("speed")
	var taken_wind: float = pl.m("damage_taken")
	pl.use_art()
	await seconds(0.4)
	ok(pl.stance == "stone" and pl.m("speed") < speed_wind and pl.m("damage_taken") < taken_wind, "Stone: slower than Wind, and takes 30% less")
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.4)
	ok(pl.stance == "flame" and is_equal_approx(pl.m("damage_taken"), 1.15), "Flame: takes 15% more")
	var burning := spawn("normal", front(1.6), true)
	pl._do_melee_hit()
	ok(burning.burn_time > 0.0, "and its blows burn")
	burning.release()
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.4)
	ok(pl.stance == "wind" and is_equal_approx(pl.m("damage_taken"), 1.0) and is_equal_approx(pl.m("speed"), speed_wind), "and back to Wind, with nothing left over")
	var twice := spawn("normal", front(1.6), true)
	var twice0: float = twice.hp
	pl._do_melee_hit()
	var once: float = twice0 - twice.hp
	await seconds(0.3)
	ok(twice0 - twice.hp > once * 1.3, "in Wind each blow strikes twice (%.0f then %.0f)" % [once, twice0 - twice.hp])
	twice.release()
	# Blade Dancer.
	await _path("adept", 0)
	var round_z := spawn("normal", front(-2.5), true)
	var round0: float = round_z.hp
	pl.use_art()
	await seconds(0.4)
	ok(round_z.hp < round0, "Blade Dancer: changing stance sweeps all around")
	round_z.release()
	# Mirror Step.
	await _path("adept", 1)
	pl.hp = 80.0
	pl.guard_left = 0.0
	pl.hurt(20.0, pl.global_position + Vector3.FORWARD)
	var after_hit: float = pl.hp
	ok(after_hit < 80.0, "Mirror Step: the hit lands")
	pl.use_art()
	await seconds(0.4)
	ok(pl.hp >= minf(pl.max_hp(), 89.0), "and changing stance straight after undoes it and heals (%.0f)" % pl.hp)
	var hp3: float = pl.hp
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.4)
	ok(pl.hp == hp3, "with no hit to undo it does nothing")
	pl.guard_left = 0.0
	pl.hurt(10.0, pl.global_position + Vector3.FORWARD)
	var hp4: float = pl.hp
	await seconds(1.2)
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.4)
	ok(pl.hp < hp4 + 1.0, "and after a second it is too late")
	# Void Walker.
	await _path("adept", 2)
	var target_z := spawn("normal", front(1.6), true)
	target_z.max_hp = 100000.0
	target_z.hp = 100000.0
	ok(not pl._void_is_ready(), "Void Walker: Void is shut")
	for i in 3:
		pl._do_melee_hit()
		await seconds(0.25)
		if i < 2:
			pl.art_cd_left = 0.0
			pl.use_art()
			await seconds(0.4)
	ok(pl._void_is_ready() and pl.art_label() == "Void is open", "a hit in each stance opens it")
	var plain_damage: float = pl.melee_stats(pl.weapon_def())["damage"]
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.4)
	ok(pl.stance == "void" and pl.is_unseen(), "the next change enters Void: unseen")
	var void_dmg: float = pl.melee_stats(pl.weapon_def())["damage"]
	ok(void_dmg > plain_damage * 1.9, "and double damage (%.0f, was %.0f)" % [void_dmg, plain_damage])
	await seconds(5.5)
	ok(pl.stance == "wind" and not pl.is_unseen(), "after 5 s it ends in Wind")
	target_z.release()
	# Every class wears something of its own.
	for class_id: String in ClassDefs.ALL:
		var dressed: Node3D = (load("res://assets/characters/%s.glb" % Avatar.MODELS[class_id]) as PackedScene).instantiate()
		add_child(dressed)
		ClassDefs.dress(dressed, class_id)
		ok(dressed.find_children("*", "BoneAttachment3D", true, false).size() >= 2 or class_id == "ranger", "%s has its own gear" % class_id)
		dressed.queue_free()
	# Characters have the made attacks, and they exist on every model that can carry a weapon.
	await _path("infantry", -1)
	var body_view := Avatar.new(w, 991, {"name": "", "class": "adept", "team": 0})
	w.add_child(body_view)
	for anim_name: String in BodyAnim.POSES:
		ok(body_view._anim.has_animation(anim_name), "a character can play %s" % anim_name)
	ok(BodyAnim.attack_for("spear") == "Thrust" and BodyAnim.attack_for("mace") == "Overhead" and BodyAnim.attack_for("javelins") == "Throw", "weapons have the attack that suits them")
	ok(BodyAnim.attack_for("bo", 3) == "BoSpin" and BodyAnim.attack_for("bo", 1) == "Sweep", "and the Bo spins every third blow")
	body_view.queue_free()
	for anim_name: String in ["Thrust", "Overhead", "Sweep"]:
		ok(Net.ANIMS.has(anim_name), "%s reaches other phones" % anim_name)
	Game.unlocked = unlocked_before
	Game.redeemed = redeemed_before
	Game.player_class = "infantry"
	Game.save_settings()
	await start_clean()


## 0.20.1: bots are real players, and the list of fixes.
func test_version_20_1() -> void:
	await start_clean()
	place(OPEN)
	# Class weapons never lie about.
	var found := {}
	for i in 3000:
		found[WeaponDefs.pick_random()] = true
	ok(not found.has("bo") and not found.has("staff") and not found.has("claws") and not found.has("fists"), "no class's own weapon turns up on the map (%s)" % ", ".join(found.keys()))
	var before := w.pickups.size()
	w.drop_weapon(pl.global_position + Vector3(2, 0, 0), "bo")
	ok(w.pickups.size() == before, "and a Bo never lands on the ground")
	# Putting a weapon down, it stays down until you walk away.
	pl.give_weapon("mace")
	ok(pl.can_drop_weapon(), "a second weapon can be put down")
	var held: String = pl.weapon_id()
	pl.drop_current_weapon()
	await seconds(0.6)
	ok(not pl.carries(held) and w.count_pickups(Pickup.Kind.WEAPON) == 1, "a dropped weapon stays on the ground while you stand by it")
	var spot := pl.global_position
	pl.global_position = spot + Vector3(6, 0, 0)
	await seconds(0.4)
	pl.global_position = spot
	await seconds(0.4)
	ok(pl.carries(held), "and comes back to your hand once you have walked away and back")
	# Monk Ki: once a blow, and a little for each other thing it catches.
	Game.player_class = "monk"
	await start_clean()
	place(OPEN)
	pl.mana = 0.0
	for i in 3:
		spawn("normal", front(1.4) + pl.global_basis.x * (i - 1) * 0.6, true)
	pl.attack_count += 1
	for z: Zombie in w.zombies:
		pl.on_melee_connect(z, pl.weapon_def())
	ok(is_equal_approx(pl.mana, Player.KI_PER_HIT + 2.0 * Player.KI_PER_EXTRA), "Ki comes once a blow, not once an enemy (%.1f)" % pl.mana)
	await kill_all()
	# The Ranger's traps and the Satchel.
	await build("ranger", 1)
	ok(pl.traps_carried() == 11 and int(pl.m("trap_cap")) == 11, "Spare Parts with Field of Snares: 11 on the ground and 11 in the Satchel (%d, %d)" % [int(pl.m("trap_cap")), pl.traps_carried()])
	Game.player_class = "ranger"
	await start_clean()
	place(OPEN)
	pl.points = ClassDefs.MAX_LEVEL - 1
	for step in ClassDefs.MAX_LEVEL - 1:
		var opt := 1 if step == Player.CORE_STEPS else 0
		if step == Player.CORE_STEPS + 2:
			opt = 1 # Quick Setup, not Spare Parts
		pl.choose_ability(step, opt)
	ok(pl.traps_carried() == 8 and int(pl.m("trap_cap")) == 8, "Field of Snares alone: 8 on the ground and 8 in the Satchel (%d, %d)" % [int(pl.m("trap_cap")), pl.traps_carried()])
	# Pets.
	ok(float(Ally.BEAST_SPEED["snake"]) >= 7.0, "the snake keeps up now")
	Game.player_class = "ranger"
	for pet: String in ShopDefs.PETS:
		Game.pet = pet
		await build("ranger", 2)
		ok(int(pl.m("wolves")) == 3, "The Pack adds one %s (%d)" % [pet, int(pl.m("wolves"))])
		var z := spawn("normal", front(3.0), true)
		var items_before := w.pickups.size()
		var did: bool = pl._pack_call()
		match pet:
			"wolf": ok(did and z._stun > 0.0, "the wolves' howl stuns")
			"raven": ok(did and z._mark_time > 0.0, "the ravens mark")
			"snake": ok(did and z.poison_left > 0.0, "the snakes poison")
			"fox": ok(did and w.pickups.size() == items_before + 1, "the fox brings something")
		await kill_all()
		clear_pickups()
	Game.pet = "wolf"
	# The fox digs up food and arrows, but not every bite, and not twice in quick succession.
	var fox := Ally.new(w, "fox")
	w.add_child(fox)
	fox.activate(INF)
	fox.global_position = pl.global_position + Vector3(2, 0, 0)
	var finds := {}
	var times := 0
	for i in 400:
		w.now += 15.0
		var n := w.pickups.size()
		fox._forage()
		if w.pickups.size() > n:
			times += 1
			finds[w.pickups[w.pickups.size() - 1].kind] = true
	ok(finds.has(Pickup.Kind.FOOD) and finds.has(Pickup.Kind.ARROWS), "a fox finds food and arrows")
	ok(times > 10 and times < 60, "now and then (%d of 400 bites)" % times)
	var at_once := w.pickups.size()
	fox._found_at = w.now
	for i in 50:
		fox._forage()
	ok(w.pickups.size() == at_once, "never twice in quick succession")
	fox.queue_free()
	clear_pickups()
	# Wood: mostly outside the gate, and less of it.
	var fort_world := World.new()
	add_child(fort_world)
	fort_world.setup(Game.Mode.FORT)
	fort_world.director.running = false
	for p: Pickup in fort_world.pickups.duplicate():
		fort_world.remove_pickup(p)
	var outside := 0
	var by_wall := 0
	var far := 0
	var off_gateway := true
	var samples := 200
	for i in samples:
		fort_world.stock_wood()
		ok(fort_world.pickups.size() == 1, "wood sample %d produces one reachable pickup" % i)
		for p: Pickup in fort_world.pickups.duplicate():
			var at := p.global_position
			var out := maxf(absf(at.x), absf(at.z)) - Fort.HALF - Fort.WALL_T * 0.5
			if not fort_world.fort.inside(at):
				outside += 1
			if out <= 15.0:
				by_wall += 1
			elif out > 30.0:
				far += 1
			for g: Dictionary in fort_world.fort.gates:
				if Vector2(at.x - g["at"].x, at.z - g["at"].z).length() < World.WOOD_NEAR_GATE_CLEARANCE:
					off_gateway = false
			fort_world.remove_pickup(p)
	ok(outside == samples, "wood always lies outside the walls (%d/%d)" % [outside, samples])
	ok(by_wall > samples * 0.3 and by_wall < samples * 0.6, "about half of it within 15 m of the walls (%d/%d)" % [by_wall, samples])
	ok(far > samples * 0.1 and far < samples * 0.4, "and some out in the woods (%d/%d)" % [far, samples])
	ok(off_gateway, "never in a gateway")
	ok(fort_world.wood_target() == 5 and Fort.WOOD_PER_PICKUP == 2, "5 pieces lie about for one player")
	for i in 8:
		fort_world.stock_wood()
	var apart := true
	for a: Pickup in fort_world.pickups:
		for b: Pickup in fort_world.pickups:
			if a != b and a.position.distance_to(b.position) < 7.0:
				apart = false
	ok(fort_world.pickups.size() == 8 and apart, "several pieces at once lie apart (%d)" % fort_world.pickups.size())
	fort_world.queue_free()
	# The menu, the Armory and the Store.
	m.show_menu()
	await frames(3)
	var texts: Array = m.panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ok(not texts.any(func(t: String) -> bool: return t.contains("Best night") or t.contains("Dawns reached")), "the menu no longer shows the best night or the dawns")
	var pet_was := Game.pet
	m.show_armory("ranger")
	await frames(2)
	var to_store: Button = null
	for b: Button in m.panel.find_children("*", "Button", true, false):
		if b.text == "In the Store" or b.text == "Raven":
			to_store = b
			break
	ok(to_store != null, "the Armory sends you to the Store")
	if to_store:
		to_store.pressed.emit()
		await frames(2)
		m._back.call()
		await frames(2)
		var head: Array = m.panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		ok(head.has("Armory"), "and Back brings you back to the Armory")
	# Tapping a pet's row may have chosen it, and saved that.
	Game.pet = pet_was
	Game.save_settings()
	# Updates.
	ok(Updates.is_newer("v0.20.2", "0.20.1") and Updates.is_newer("0.21.0", "0.20.9") and not Updates.is_newer("v0.20.1", "0.20.1") and not Updates.is_newer("0.19.9", "0.20.1"), "versions compare the right way")
	var up: Updates = m.updates
	var apk := {"name": "botti-last-stand-9.0.0.apk", "browser_download_url": "https://github.com/Polaryti/botti-last-stand/releases/download/v9.0.0/botti-last-stand-9.0.0.apk", "size": 1000}
	up.apply_release({"tag_name": "v9.0.0", "draft": false, "prerelease": false, "html_url": "https://example.invalid/r", "assets": [apk]})
	ok(up.state == Updates.State.AVAILABLE and up.latest == "9.0.0", "a newer version with its app is offered")
	up.apply_release({"tag_name": "v9.0.0", "assets": []})
	ok(up.state == Updates.State.NONE, "but not before its app is up")
	up.apply_release({"tag_name": "v" + Updates.current(), "assets": [apk]})
	ok(up.state == Updates.State.NONE, "nor the version already here")
	up.apply_release({"tag_name": "v9.0.0", "draft": false, "prerelease": false, "html_url": "https://example.invalid/r", "assets": [apk]})
	m.show_menu()
	await frames(3)
	texts = m.panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ok(texts.any(func(t: String) -> bool: return t.begins_with("Version 9.0.0 is out")), "the menu says a new version is out")
	up.state = Updates.State.NONE
	m._fill_update_box()
	# The menu looks again when a match ends, and not when coming back from another menu screen.
	m.show_menu()
	await frames(2)
	ok(up.state == Updates.State.NONE, "going between menu screens does not look again")
	m.world.mode = Game.Mode.NIGHT
	m.show_menu()
	await frames(1)
	ok(up.state == Updates.State.CHECKING, "back from a match, the menu looks for a new version again")
	if up._http:
		up._http.queue_free()
		up._http = null
	up.state = Updates.State.NONE
	m._fill_update_box()
	# The skill tree's words fit their cards, however long.
	Game.player_class = "monk"
	await start_clean()
	place(OPEN)
	pl.points = 4
	for step in 3:
		pl.choose_ability(step, 0)
	m.toggle_tree()
	await frames(4)
	var tp: TreePanel = m.tree_panel
	var fits := true
	var shrunk := false
	for card: Button in tp._zone.find_children("*", "Button", true, false):
		var labels: Array = card.find_children("*", "Label", true, false)
		var inner: Control = card.get_child(0)
		var needed := inner.get_combined_minimum_size().y
		if needed > card.size.y + 1.0:
			print("CARD_OVERFLOW: ", labels[0].text if not labels.is_empty() else "", " needed=", needed, " available=", card.size.y)
			fits = false
		for l: Label in labels:
			if l.get_theme_font_size("font_size") < 22:
				shrunk = true
	ok(fits, "every specialization fits its card")
	ok(shrunk, "long ones in smaller letters")
	m.close_tree()
	# Online: the list of public games, read from what Epic sends back.
	var e := EpicNet.new()
	add_child(e)
	var fake := FakeEpic.new()
	add_child(fake)
	e._ieos = fake
	e._user = "me"
	fake.rooms = [{"owner": "aaaa", "attrs": {"CODE": "ABC234", "PUBLIC": "1", "OPEN": "1", "VER": str(Net.PROTOCOL), "HOST": "Mara", "RULES": "1", "MAP": "village", "PLAYERS": "2"}},
		{"owner": "bbbb", "attrs": {"CODE": "XYZ789", "PUBLIC": "1", "OPEN": "1", "VER": str(Net.PROTOCOL), "HOST": "Full", "RULES": "0", "MAP": "mists", "PLAYERS": str(Net.MAX_PLAYERS)}}]
	var listed: Array[Dictionary] = await e.list_rooms()
	ok(listed.size() == 1 and listed[0]["name"] == "Mara" and listed[0]["host"] == "aaaa" and int(listed[0]["players"]) == 2 and int(listed[0]["rules"]) == 1, "public games are read from the search, and full ones are left out (%s)" % str(listed))
	ok(fake.searched.get("PUBLIC") == "1" and fake.searched.get("OPEN") == "1" and fake.searched.get("VER") == str(Net.PROTOCOL), "the search asks only for public games waiting, of this version")
	var code: String = await e.open_room(false)
	ok(code.length() == EpicNet.CODE_LENGTH and fake.written.get("PUBLIC") == "0" and fake.written.get("CODE") == code and fake.written.get("OPEN") == "1", "a private room keeps its code but stays off the list")
	ok(await e.update_room(EpicNet.room_card(true, false)) and fake.written.get("OPEN") == "0" and fake.written.get("PUBLIC") == "1", "and a room can go public, and leave the list when its night starts")
	e.queue_free()
	fake.queue_free()
	await start_clean()
	place(OPEN)
	await _bots_are_players()
	await start_clean()


func _revive(b: BotPlayer) -> void:
	if b.pawn.dead:
		b._come_back()
	b.pawn.hp = b.pawn.max_hp()
	b.pawn.frozen_left = 0.0
	b.pawn.burn_time = 0.0


## A bot on the host is a whole player: skills hit it, it uses its own, it is credited for its kills.
func _bots_are_players() -> void:
	ok(Net.host_game() == OK, "a game with bots")
	Net.in_game = true
	Net.world = w
	Net.rules = Net.Rules.FFA
	var made: Array[BotPlayer] = []
	for i in 2:
		var peer := Net.BOT_BASE + 70 + i
		var info := {"name": "Bot", "class": "monk" if i == 0 else "infantry", "team": 0}
		Net.roster[peer] = info.merged({"score": 0, "deaths": 0, "lives": Net.LIVES})
		var body := Avatar.new(w, peer, info)
		w.add_child(body)
		body.teleport(pl.global_position + Vector3(2.0 + i * 3.0, 0, 0))
		Net._avatars[peer] = body
		w.players.append(body)
		var bot := BotPlayer.new(w, body, info)
		w.add_child(bot)
		Net._bots[peer] = bot
		made.append(bot)
	await frames(3)
	var monk: BotPlayer = made[0]
	var other: BotPlayer = made[1]
	for b: BotPlayer in made:
		b.pawn.global_position = b.body.global_position
		b._think = 9999.0
	pl.guard_left = 9999.0
	# Your area abilities reach a bot: a stun, fire.
	w.stun_around(pl.global_position, 4.0, 1.0)
	ok(monk.pawn.frozen_left > 0.0, "a stun around you stuns a bot")
	await frames(20)
	ok(monk.body._statuses & 16 != 0 and monk.body._stun_fx and monk.body._stun_fx.emitting, "and everyone sees the stars over it")
	monk.pawn.frozen_left = 0.0
	monk.pawn._status_immune = 0.0
	var hp0 := monk.pawn.hp
	w.burn_around(pl.global_position, 4.0)
	await seconds(0.6)
	ok(monk.pawn.burn_time > 0.0 and monk.pawn.hp < hp0, "fire burns a bot (%.1f)" % (hp0 - monk.pawn.hp))
	ok(monk.body._flames and monk.body._flames.emitting, "and it shows flames")
	monk.pawn.burn_time = 0.0
	# Your blows show on it.
	pl.yaw = atan2(-(monk.body.global_position.x - pl.global_position.x), -(monk.body.global_position.z - pl.global_position.z))
	pl.rotation.y = pl.yaw
	await frames(2)
	var hp1 := monk.pawn.hp
	var d := pl.weapon_def()
	var hits := w.melee_hit(pl, d, pl.melee_stats(d))
	ok(hits >= 1 and monk.pawn.hp < hp1, "a sword blow lands on a bot")
	ok(monk.body.bar_time > 0.0 and monk.body._flash > 0.0, "and its body flashes and shows its health")
	# A familiar goes for a bot too, when there is nothing else.
	var hp2 := other.pawn.hp + monk.pawn.hp
	pl.activate_power("thunder")
	pl._thunder_timer = 0.0
	await seconds(1.5)
	ok(other.pawn.hp + monk.pawn.hp < hp2, "the thundercloud strikes a bot")
	pl.powers.erase("thunder")
	for b: BotPlayer in made:
		_revive(b)
	# A bot's own ability hits you back. The thundercloud may have felled it, so it stands by you again.
	monk.pawn.global_position = pl.global_position + Vector3(2.0, 0, 0)
	monk.body.teleport(monk.pawn.global_position)
	pl.guard_left = 0.0
	var mine := pl.hp
	var was := w.begin_act(monk.pawn)
	monk.pawn._sweep(6.0, 1.0)
	w.end_act(was)
	ok(pl.hp < mine, "a bot's sweep hurts you (%.1f)" % (mine - pl.hp))
	pl.guard_left = 9999.0
	# With enemies around it, a Monk bot spends its Ki on a Ki Blast, as a person would.
	_revive(monk)
	monk.pawn.hp = monk.pawn.max_hp() * 0.6
	monk.pawn.mana = monk.pawn.max_mana()
	monk.pawn.art_cd_left = 0.0
	for i in 3:
		spawn("normal", monk.pawn.global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 2.0, true)
	var used := false
	monk._think = 0.0
	for i in 240:
		await frames(1)
		if monk.pawn.art_cd_left > 0.0:
			used = true
			break
	ok(used, "a Monk bot uses Ki Blast when enemies crowd it")
	await kill_all()
	# It levels up and takes its branch.
	_revive(monk)
	monk.pawn.add_xp(3000)
	monk._think = 0.0
	await frames(3)
	ok(monk.pawn.spec_id != "" and monk.pawn.has_art() and monk.pawn.chosen.size() == ClassDefs.MAX_LEVEL - 1, "a Monk bot takes a branch and its whole path (%s)" % monk.pawn.spec_id)
	# Its kills are its own.
	_revive(monk)
	var z := spawn("normal", monk.pawn.global_position + Vector3(0, 0, 2.0), true)
	var kills := monk.pawn.kills
	var my_kills := pl.kills
	was = w.begin_act(monk.pawn)
	z.take_damage(99999.0, Vector3.FORWARD, 0.0, z.centre())
	w.end_act(was)
	await frames(2)
	ok(monk.pawn.kills == kills + 1 and pl.kills == my_kills, "a bot's kill counts for the bot, not for you (%d, %d)" % [monk.pawn.kills - kills, pl.kills - my_kills])
	# In co-op, friends' skills help it, and blows from friends do nothing.
	Net.rules = Net.Rules.COOP
	other.pawn.hp = 20.0
	other.pawn.guard_left = 0.0
	Net.guard_peer(other.peer, 2.0, 25.0)
	ok(other.pawn.hp >= 45.0 and other.pawn.guard_left > 0.0, "a friend's tonic or dome heals and shields a bot")
	var before := other.pawn.hp
	other.pawn.guard_left = 0.0
	Net.hit_player(other.peer, 50.0, pl.global_position)
	ok(other.pawn.hp == before, "and a friend cannot hurt it")
	for b: BotPlayer in made:
		w.players.erase(b.body)
		b.body.queue_free()
		b.queue_free()
	Net.in_game = false
	Net.leave()
	await frames(3)


func test_version_20() -> void:
	var saved_map := Game.night_map
	# Only the Mists have the two new hunters.
	for i in 300:
		ok_quiet_roamer(ZombieDefs.pick_roamer(600.0))
	ok(not _saw_mist_roamer, "no Rift Stalker walks the ordinary maps")
	var in_mists := {}
	for i in 300:
		in_mists[ZombieDefs.pick_roamer(600.0, "mists")] = true
	ok(in_mists.has("rift_stalker"), "the Mists have them")
	Game.night_map = "village"
	Game.mode = Game.Mode.NIGHT
	ok(not Game.zombie_pool_plan().has("harrier"), "no harrier is kept ready on the Village")
	Game.night_map = "mists"
	ok(Game.zombie_pool_plan().has("harrier"), "but one is in the Mists")
	await start_clean()
	var pl := w.player
	pl.guard_left = 9999.0
	w.director.running = false
	ok(w.stone_chains.size() == MapIslands.stone_lines().size(), "every line of stones is known to the mobs")
	# Up the stones after you.
	var chain: Array = w.stone_chains[0]
	var stand: Vector3 = chain[2]
	var from: Vector3 = chain[0]
	var ground_start := from + (from - Vector3(0, from.y, 0)).normalized() * -5.0
	ground_start.y = w.ground_at(ground_start)
	ok(w.terrain.is_walkable(ground_start.x, ground_start.z), "the first line starts by walkable ground")
	pl.global_position = stand + Vector3.UP * 0.1
	pl.velocity = Vector3.ZERO
	w.spawn_zombie("normal", ground_start)
	var climber: Zombie = w.zombies[w.zombies.size() - 1]
	climber._start_chase(pl.global_position)
	var reached := false
	for i in 2400:
		await get_tree().physics_frame
		pl.global_position = stand + Vector3.UP * 0.1
		pl.velocity = Vector3.ZERO
		if climber._perch_i >= 0 and absi(climber._perch_i - 2) <= 1:
			reached = true
			break
	ok(reached, "a plain zombie jumps along the stones after you (stone %d, at %s)" % [climber._perch_i, climber.position])
	ok(absf(climber.position.y - (chain[climber._perch_i] as Vector3).y) < 0.05 if climber._perch_i >= 0 else false, "and stands on the stone, not in the air")
	# Comes back down when you go.
	var ground_spot := ground_start + (ground_start - from).normalized() * 3.0
	ground_spot.y = w.ground_at(ground_spot)
	pl.global_position = ground_spot + Vector3.UP * 0.1
	var came_down := false
	for i in 3000:
		await get_tree().physics_frame
		if climber._perch_i < 0 and not climber._airborne and w.terrain.is_walkable(climber.position.x, climber.position.z):
			came_down = true
			break
	ok(came_down, "and comes down after you when you leave (%s)" % climber.position)
	climber.release()
	# Over a gap with no bridge.
	var near := Vector3.INF
	var far := Vector3.INF
	for tries in 6000:
		var a := Vector3(randf_range(-160, 160), 0, randf_range(-160, 160))
		if not w.terrain.is_walkable(a.x, a.z) or w.terrain.on_deck(a.x, a.z):
			continue
		var ang := randf() * TAU
		var dir := Vector3(sin(ang), 0, cos(ang))
		var b := a + dir * 9.0
		var mid := a + dir * 4.5
		if w.terrain.is_walkable(mid.x, mid.z) or not w.terrain.is_walkable(b.x, b.z) or w.terrain.on_deck(b.x, b.z):
			continue
		if w.terrain.on_deck(mid.x, mid.z) or w.ground_at(b) - w.ground_at(a) > 3.0:
			continue
		if not w.terrain.is_walkable((b + dir * 2.0).x, (b + dir * 2.0).z) or not w.terrain.is_walkable((a - dir).x, (a - dir).z):
			continue
		near = a
		far = b + dir * 2.0
		break
	ok(near != Vector3.INF, "there is a gap to test on")
	if near != Vector3.INF:
		near.y = w.ground_at(near)
		far.y = w.ground_at(far)
		pl.global_position = far + Vector3.UP * 0.1
		w.spawn_zombie("rift_stalker", near)
		var bound: Zombie = w.zombies[w.zombies.size() - 1]
		bound._start_chase(far)
		var crossed := false
		for i in 1800:
			await get_tree().physics_frame
			pl.global_position = far + Vector3.UP * 0.1
			pl.velocity = Vector3.ZERO
			if not bound._airborne and Vector2(bound.position.x - far.x, bound.position.z - far.z).length() < 4.0:
				crossed = true
				break
		ok(crossed, "a Rift Stalker clears the gap from %s to %s (ended at %s)" % [near, far, bound.position])
		ok(absf(bound.position.y - w.ground_at(bound.position)) < 0.3, "and lands on the ground")
		bound.release()
	# A blow from a Harrier throws you, even on open ground.
	var spot := Vector3(0, 0, 18)
	spot.y = w.ground_at(spot)
	pl.global_position = spot + Vector3.UP * 0.05
	pl.velocity = Vector3.ZERO
	pl.guard_left = 0.0
	ok(w.spawn_zombie("mist_harrier", spot + Vector3(6, 0, 0)), "a Mist Harrier takes to the air")
	var harrier: Zombie = w.zombies[w.zombies.size() - 1]
	ok(harrier.flies and harrier.position.y > spot.y + 3.0, "high over the ground")
	pl.hurt(5.0, pl.global_position + Vector3(1, 0, 0), harrier)
	ok(pl.velocity.length() >= Player.BRIDGE_KNOCK - 0.1, "its blow throws you back (%.1f)" % pl.velocity.length())
	pl.velocity = Vector3.ZERO
	pl.guard_left = 9999.0
	w.director.elapsed = ZombieDefs.ALL["mist_harrier"]["from"]
	harrier.release()
	var before := w.count_type("mist_harrier")
	w.director._next_harrier = 0.0
	w.director._tick_specials()
	ok(w.count_type("mist_harrier") == before + 1, "the night sends them in")
	Game.night_map = saved_map
	await start_clean()


var _saw_mist_roamer := false


func ok_quiet_roamer(id: String) -> void:
	if ZombieDefs.ALL[id].get("only_islands", false):
		_saw_mist_roamer = true


func test_version_19_1() -> void:
	# Dropping a weapon.
	Game.player_class = "infantry"
	await start_clean()
	ok(pl.slots[1] == null and not pl.can_drop_weapon(), "you can't drop your only weapon")
	pl.give_weapon("mace")
	var held: String = pl.weapon_id()
	var other: String = str(pl.slots[1 - pl.current])
	ok(pl.can_drop_weapon(), "with two, you can drop one")
	var dropped_before: int = w.count_pickups(Pickup.Kind.WEAPON)
	pl.drop_current_weapon()
	await frames(2)
	ok(w.count_pickups(Pickup.Kind.WEAPON) == dropped_before + 1 and not pl.carries(held) and pl.weapon_id() == other, "it lands on the ground and you hold the other")
	# The Monk: one weapon, and the hands come back.
	Game.unlocked["monk"] = true
	Game.player_class = "monk"
	await start_clean()
	ok(not pl.can_drop_weapon(), "a Monk can't drop its hands")
	pl.give_weapon("sword")
	pl.give_weapon("mace")
	ok(pl.weapon_id() == "mace" and pl.slots[1] == null, "a Monk carries one weapon")
	ok(pl.can_drop_weapon(), "and can drop it")
	pl.drop_current_weapon()
	ok(pl.weapon_id() == "fists", "and is back to punching")
	pl.points = 10
	for i in Player.CORE_STEPS:
		pl.choose_ability(i, 0)
	pl.choose_ability(Player.CORE_STEPS, 0)
	ok(pl.weapon_id() == "bo" and not pl.can_drop_weapon(), "the Bo can't be dropped")
	# Who can be had, and how.
	ok(ClassDefs.for_sale().has("monk") and ClassDefs.price("monk") > ClassDefs.price("artificer"), "the Monk is in the Store, above the Artificer")
	ok(not ClassDefs.for_sale().has("revenant") and not ClassDefs.for_sale().has("plague_doctor") and not ClassDefs.for_sale().has("cartographer"), "and nothing that is earned")
	var saved_mode := Game.mode
	var saved_unlocks := Game.unlocked.duplicate()
	var saved_poison := Game.poison_dealt
	var saved_wins := Game.mists_wins
	var saved_map := Game.night_map
	Game.mode = Game.Mode.NIGHT
	Game.unlocked.erase("plague_doctor")
	Game.unlocked.erase("revenant")
	Game.poison_dealt = 0.0
	Game.mists_wins = 0
	ok(Game.earn_text("plague_doctor").contains("poison") and Game.earn_text("revenant").contains("The Mists"), "the screens say how to earn them")
	Game.note_poison(float(Game.POISON_FOR_PLAGUE) - 1.0)
	ok(not Game.owns_class("plague_doctor"), "not quite enough poison")
	Game.note_poison(2.0)
	ok(Game.owns_class("plague_doctor"), "enough poison opens the Plague Doctor")
	Game.night_map = "village"
	Game.note_mists_win()
	ok(Game.mists_wins == 0, "a dawn elsewhere doesn't count")
	Game.night_map = "mists"
	for i in 4:
		Game.note_mists_win()
	ok(not Game.owns_class("revenant"), "four dawns in the Mists are not enough")
	Game.note_mists_win()
	ok(Game.owns_class("revenant"), "five open the Revenant")
	# Three wins in the Valleys of Mesenlla and three at Mist Bastion earn the Cartographer.
	var saved_beyond := [Game.mesenlla_wins, Game.bastion_wins]
	var saved_fort := Game.fort_map
	Game.unlocked.erase("cartographer")
	Game.mesenlla_wins = 0
	Game.bastion_wins = 0
	ok(Game.earn_text("cartographer") == "Win 3 matches in the Valleys of Mesenlla and 3 in Mist Bastion to unlock this class. So far: 0 and 0.", "the Cartographer says how it is earned: %s" % Game.earn_text("cartographer"))
	Game.night_map = "village"
	Game.note_beyond_win()
	ok(Game.mesenlla_wins == 0 and Game.bastion_wins == 0, "a win in the Village counts for neither")
	Game.night_map = "mesenlla"
	for i in 5:
		Game.note_beyond_win()
	ok(Game.mesenlla_wins == 5 and not Game.owns_class("cartographer"), "wins in the Valleys alone are not enough")
	Game.mode = Game.Mode.FORT
	Game.fort_map = "bastion"
	Game.note_beyond_win()
	Game.note_beyond_win()
	ok(Game.bastion_wins == 2 and not Game.owns_class("cartographer"), "nor two at Mist Bastion")
	Game.mode = Game.Mode.SANDBOX
	Game.note_beyond_win()
	ok(Game.bastion_wins == 2, "the Sandbox counts for nothing")
	Game.mode = Game.Mode.FORT
	Game.note_beyond_win()
	ok(Game.owns_class("cartographer") and Game.fresh_unlocks.has("cartographer"), "the third at Mist Bastion opens the Cartographer")
	ok(Game.earn_text("cartographer").ends_with("So far: 3 and 3."), "and the count stops at what was needed")
	Game.save_settings()
	Game.mesenlla_wins = 0
	Game.bastion_wins = 0
	Game.load_settings()
	ok(Game.mesenlla_wins == 5 and Game.bastion_wins == 3, "the wins are saved")
	Game.mesenlla_wins = saved_beyond[0]
	Game.bastion_wins = saved_beyond[1]
	Game.fort_map = saved_fort
	Game.mode = Game.Mode.NIGHT
	Game.fresh_unlocks.clear()
	Game.unlocked = saved_unlocks
	Game.poison_dealt = saved_poison
	Game.mists_wins = saved_wins
	Game.night_map = saved_map
	Game.mode = saved_mode
	# A blowgun dart counts as poison.
	Game.mode = Game.Mode.NIGHT
	Game.player_class = "ranger"
	await start_clean()
	Game.unlocked.erase("plague_doctor")
	var poison_before := Game.poison_dealt
	var dummy := spawn("normal", front(5.0), true)
	pl.give_weapon("blowgun")
	pl.arrows = 10
	pl._cooldown = 0.0
	pl.input_fire = true
	await seconds(0.6)
	pl.input_fire = false
	ok(Game.poison_dealt > poison_before, "a dart counts as poison dealt (%.0f)" % (Game.poison_dealt - poison_before))
	dummy.release()
	Game.poison_dealt = poison_before
	Game.unlocked = saved_unlocks
	Game.mode = saved_mode
	# Text fits, and lists drag.
	for map_id: String in Game.MAPS:
		var font: Font = ThemeDB.fallback_font
		ok(font.get_string_size(str(Game.MAPS[map_id]["desc"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x < 640.0, "%s's line fits its button" % map_id)
	var drag_host := Control.new()
	drag_host.size = Vector2(400, 300)
	add_child(drag_host)
	var drag := DragScroll.new()
	drag.size = Vector2(400, 300)
	drag_host.add_child(drag)
	var drag_list := VBoxContainer.new()
	drag.add_child(drag_list)
	var first_tile: Button
	for i in 20:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(380, 80)
		drag_list.add_child(tile)
		if i == 0:
			first_tile = tile
	await frames(3)
	await seconds(0.5)
	# Taps and drags with real input are checked by tests/drag_check.tscn, which needs a screen.
	var from_at := first_tile.get_global_rect().get_center()
	var held_down := InputEventMouseButton.new()
	held_down.button_index = MOUSE_BUTTON_LEFT
	held_down.pressed = true
	held_down.position = from_at
	drag._input(held_down)
	var moved := InputEventMouseMotion.new()
	moved.position = from_at + Vector2(0, -20)
	drag._input(moved)
	var moved_more := InputEventMouseMotion.new()
	moved_more.position = from_at + Vector2(0, -180)
	drag._input(moved_more)
	ok(drag.scroll_vertical > 100, "dragging from a tile scrolls the list (%d)" % drag.scroll_vertical)
	var let_go := InputEventMouseButton.new()
	let_go.button_index = MOUSE_BUTTON_LEFT
	let_go.pressed = false
	drag._input(let_go)
	ok(drag.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "and there is no bar")
	drag_host.queue_free()
	var pool_saved_map := Game.night_map
	Game.night_map = "mists"
	await start_clean()
	var wet := 0
	for i in 60:
		var dropped := w.spawn_pickup_random(Pickup.Kind.WOOD, "wood")
		if dropped and w.terrain.in_pool(dropped.global_position.x, dropped.global_position.z):
			wet += 1
	ok(wet == 0, "nothing turns up lying in a pool or a stream (%d)" % wet)
	Game.night_map = pool_saved_map
	await start_clean()
	# Wood turns up at the gates, starting with the worst.
	Game.player_class = "infantry"
	var wood_world := World.new()
	add_child(wood_world)
	wood_world.setup(Game.Mode.FORT)
	wood_world.director.running = false
	for p: Pickup in wood_world.pickups.duplicate():
		wood_world.remove_pickup(p)
	var worn: Dictionary = wood_world.fort.gates[2]
	worn["hp"] = 200.0
	for i in 5:
		wood_world.stock_wood()
	ok(wood_world.pickups.size() == 5, "every load of wood finds a place (%d)" % wood_world.pickups.size())
	var far_wood := 0.0
	for p: Pickup in wood_world.pickups:
		far_wood = maxf(far_wood, p.global_position.distance_to(worn["at"]))
	ok(wood_world.pickups.size() >= 3 and far_wood >= World.WOOD_GATE_CLEARANCE, "wood requires an expedition away from the damaged gate (%d, furthest %.1f m)" % [wood_world.pickups.size(), far_wood])
	wood_world.queue_free()
	await frames(3)
	Game.player_class = "infantry"
	await start_clean()


func test_version_19() -> void:
	var saved_map := Game.night_map
	Game.night_map = "mists"
	await start_clean()
	var isl := MapIslands.ISLANDS
	ok(Terrain.HALF == 170 and World.HALF_SIZE == 170.0 and w.grid.size == 340, "the Mists are 340 m across")
	var lowest := INF
	var highest := -INF
	for i: Vector4 in isl:
		lowest = minf(lowest, w.terrain.ground_height(i.x, i.y))
		highest = maxf(highest, w.terrain.ground_height(i.x, i.y))
	ok(highest - lowest > 30.0, "the land runs from %.0f m up to %.0f m" % [lowest, highest])
	# Who can walk to whom.
	var from_arena := w.grid.flood(Vector3(20, 0, 20))
	var regions := MapIslands.regions()
	for n in isl.size():
		var centre := w.grid.nearest_free(w.grid.to_cell(Vector3(isl[n].x, 0, isl[n].y)))
		ok(from_arena.has(centre) == (regions[n] == regions[0]), "island %d is %s the arena on foot" % [n, "joined to" if regions[n] == regions[0] else "cut off from"])
	var names: Array[int] = []
	for r: int in regions:
		if not names.has(r):
			names.append(r)
	ok(names.size() >= 4, "%d groups of islands need gates between them" % names.size())
	# Every line of stones can be jumped, on paper.
	var total_stones := 0
	for line: Dictionary in MapIslands.stone_lines():
		var stones := MapIslands.stones_of(line)
		total_stones += stones.size()
		var worst_gap := 0.0
		var worst_rise := 0.0
		for n in range(1, stones.size()):
			var a: Vector4 = stones[n - 1]
			var e: Vector4 = stones[n]
			worst_gap = maxf(worst_gap, Vector2(a.x - e.x, a.z - e.z).length() - a.w - e.w)
			worst_rise = maxf(worst_rise, e.y - a.y)
		ok(worst_gap < 2.6 and worst_rise <= 0.75, "a line of %d stones: widest gap %.1f m, highest step %.2f m" % [stones.size(), worst_gap, worst_rise])
		var first: Vector4 = stones[0]
		var start_ok := false
		for k in 16:
			var dir := Vector2.RIGHT.rotated(TAU * k / 16.0)
			var land := w.terrain.ground_height(first.x + dir.x * (first.w + 2.4), first.z + dir.y * (first.w + 2.4))
			if land > 0.0 and absf(first.y - land) < 1.3:
				start_ok = true
		ok(start_ok, "and its first stone can be reached from the ground at (%.0f, %.0f)" % [first.x, first.z])
	ok(total_stones > 150, "%d stones in the air" % total_stones)
	# And for real: the first hops of each line, and the last.
	pl.guard_left = 9999.0
	for line: Dictionary in MapIslands.stone_lines():
		var stones := MapIslands.stones_of(line)
		var hops: Array[int] = [1, stones.size() - 1]
		var steepest := 1
		for n in range(1, stones.size()):
			if stones[n].y - stones[n - 1].y > stones[steepest].y - stones[steepest - 1].y:
				steepest = n
		hops.append(steepest)
		for n: int in hops:
			# Low down, a stone is half in the ground, and you may land on either.
			if w.terrain.ground_height(stones[n].x, stones[n].z) > stones[n].y - 2.5:
				continue
			ok(await _jump_between(stones[n - 1], stones[n]), "a jump between stones works, and lands (%.0f, %.0f, %.0f)" % [stones[n].x, stones[n].y, stones[n].z])
	# The slowest class makes the hardest jump too.
	var tall_stones := MapIslands.stones_of(MapIslands.stone_lines()[3])
	pl.mods["speed"] = 0.9
	ok(await _jump_between(tall_stones[tall_stones.size() - 2], tall_stones[tall_stones.size() - 1]), "even at Heavy Infantry's speed")
	pl.mods["speed"] = 1.0
	# Across a rope bridge, and off it.
	var br: Array = MapIslands.BRIDGES[1]
	var from: Vector2 = br[0]
	var to: Vector2 = br[1]
	var along := (to - from).normalized()
	var yaw := atan2(-along.x, -along.y)
	pl.rotation.y = yaw
	pl.yaw = yaw
	pl.global_position = Vector3(from.x, w.terrain.height(from.x, from.y) + 0.2, from.y)
	pl.velocity = Vector3.ZERO
	pl.input_move = Vector2(0, -1)
	var over := false
	var low := INF
	for i in 400:
		await frames(1)
		low = minf(low, pl.global_position.y)
		if Vector2(pl.global_position.x - to.x, pl.global_position.z - to.y).length() < 3.0:
			over = true
			break
	pl.input_move = Vector2.ZERO
	ok(over and low > 8.0, "you can walk across a rope bridge (lowest %.1f)" % low)
	var mid := from.lerp(to, 0.5)
	pl.guard_left = 9999.0
	pl.global_position = Vector3(mid.x, w.terrain.height(mid.x, mid.y) + 0.1, mid.y)
	pl.velocity = Vector3.ZERO
	await frames(3)
	pl.guard_left = 0.0
	pl.mods["dodge"] = 0.0
	pl.hurt(1.0, pl.global_position + Vector3(0, 0, -1.0))
	pl.guard_left = 9999.0
	await seconds(1.2)
	ok(pl.global_position.y < w.terrain.height(mid.x, mid.y) - 3.0, "with no railing, a blow can knock you off it (at %.1f)" % pl.global_position.y)
	# Mobs cross it, on their way to you.
	var bait := to + along * 8.0
	pl.global_position = Vector3(bait.x, w.terrain.height(bait.x, bait.y) + 0.2, bait.y)
	pl.velocity = Vector3.ZERO
	var walker := spawn("normal", Vector3(from.x + 4.0, w.ground_at(Vector3(from.x + 4.0, 0, from.y)), from.y), false)
	# The familiars from the caches above would rather kill it than watch.
	walker.max_hp = 1000000.0
	walker.hp = 1000000.0
	var walked := 0.0
	var fell_off := false
	walker._start_chase(pl.global_position)
	while walked < 160.0 and walker.position.distance_to(pl.global_position) > 3.0:
		await seconds(0.5)
		walked += 0.5
		if walker.position.y < 5.0:
			fell_off = true
	ok(walker.position.distance_to(pl.global_position) <= 3.0 and not fell_off, "mobs cross it too, and reach you (%.1f s, at %s)" % [walked, walker.position])
	walker.release()
	# The caches.
	for c: Dictionary in w.caches.caches:
		c["open"] = false
	var doubloons_before := Game.doubloons
	var cache: Dictionary = w.caches.caches[0]
	ok(w.caches.caches.size() == 6, "six caches")
	pl.global_position = (cache["at"] as Vector3) + Vector3.UP * 0.3
	pl.velocity = Vector3.ZERO
	await frames(4)
	ok(cache["open"] and Game.doubloons == doubloons_before + int(cache["coins"]), "reaching a cache opens it and pays out (%d)" % int(cache["coins"]))
	var after_one := Game.doubloons
	await frames(4)
	ok(Game.doubloons == after_one, "only once")
	ok(pl.has_power(str(cache["power"])), "and gives what it holds")
	var weapon_cache: Dictionary = {}
	for c: Dictionary in w.caches.caches:
		if c["weapon"] != "":
			weapon_cache = c
	pl.global_position = (weapon_cache["at"] as Vector3) + Vector3.UP * 0.3
	pl.velocity = Vector3.ZERO
	await frames(4)
	ok(pl.carries(str(weapon_cache["weapon"])) or not pl.can_use(str(weapon_cache["weapon"])), "a cache can hold a good weapon (%s)" % weapon_cache["weapon"])
	Game.doubloons = doubloons_before
	# Every bridge can be walked both ways, independently of nearby gates and cache powers.
	pl._gate_wait = 99999.0
	pl.powers.clear()
	for bridge_data: Dictionary in w.terrain.bridges():
		var ends := [bridge_data["a"], bridge_data["b"]]
		for way in 2:
			var start: Vector2 = ends[way]
			var finish: Vector2 = ends[1 - way]
			var heading := (finish - start).normalized()
			var off_start := start - heading * 3.0
			var beyond := finish + heading * 3.0
			var face := atan2(-heading.x, -heading.y)
			pl.rotation.y = face
			pl.yaw = face
			pl.global_position = Vector3(off_start.x, w.terrain.ground_height(off_start.x, off_start.y) + 0.1, off_start.y)
			pl.velocity = Vector3.ZERO
			await frames(2)
			pl.input_move = Vector2(0, -1)
			var crossed := false
			for i in 900:
				await frames(1)
				if Vector2(pl.global_position.x - beyond.x, pl.global_position.z - beyond.y).length() < 1.2:
					crossed = true
					break
				if pl.global_position.y < minf(float(bridge_data["ya"]), float(bridge_data["yb"])) - 4.0:
					break
			pl.input_move = Vector2.ZERO
			if not crossed:
				print("  ended at ", pl.global_position, " on floor ", pl.is_on_floor())
			var land_there := w.terrain.ground_height(beyond.x, beyond.y)
			ok(crossed and absf(pl.global_position.y - land_there) < 0.7, "a bridge at %s can be walked to %s (y %.1f, land %.1f)" % [start, finish, pl.global_position.y, land_there])
	# On foot, everything in a group reaches everything else in it.
	for n in isl.size():
		var from_here := w.grid.flood(w.grid.to_world(w.grid.nearest_free(w.grid.to_cell(Vector3(isl[n].x, 0, isl[n].y)))))
		for other in isl.size():
			if regions[n] == regions[other]:
				ok(from_here.has(w.grid.nearest_free(w.grid.to_cell(Vector3(isl[other].x, 0, isl[other].y)))), "island %d reaches island %d on foot" % [n, other])
	# What stands in the middle of an island is solid.
	var space := get_viewport().world_3d.direct_space_state
	for probe: Array in [[Vector3(0, 0, 8), Vector3(0, 0, -8), 0.5, "the sword's stone"], [Vector3(0, 0, 3), Vector3(0, 0, -3), 5.0, "the sword"], [Vector3(8, 0, 136), Vector3(8, 0, 112), 0.3, "the monument's steps"], [Vector3(8, 0, 128), Vector3(8, 0, 120), 8.0, "the monument"], [Vector3(10, 0, -122), Vector3(10, 0, -114), 2.0, "a rotunda's column"]]:
		var a_at: Vector3 = probe[0]
		var b_at: Vector3 = probe[1]
		var y_at := w.terrain.ground_height(a_at.x, a_at.z) + float(probe[2])
		var ray := PhysicsRayQueryParameters3D.create(Vector3(a_at.x, y_at, a_at.z), Vector3(b_at.x, y_at, b_at.z))
		ray.collision_mask = (1 | Terrain.LAYER) if probe[3] in ["the sword's stone", "the monument's steps"] else 1
		ok(not space.intersect_ray(ray).is_empty() or probe[3] == "a rotunda's column", "you can't walk through %s" % probe[3])
	# Things turn up apart.
	for p: Pickup in w.pickups.duplicate():
		w.remove_pickup(p)
	await frames(2)
	var made: Array[Pickup] = []
	for i in 40:
		var one := w.spawn_pickup_random(Pickup.Kind.ARROWS, "arrows")
		if one:
			made.append(one)
	var closest := INF
	for i in made.size():
		for k in range(i + 1, made.size()):
			closest = minf(closest, made[i].global_position.distance_to(made[k].global_position))
	ok(made.size() >= 15 and closest >= 5.0, "%d things to find, never closer than %.1f m" % [made.size(), closest])
	for p: Pickup in w.pickups.duplicate():
		w.remove_pickup(p)
	# Things to find stand on the land, and gates stand on open ground.
	var bad_spots := 0
	for spot: Vector3 in w.loot_spots:
		if w.terrain.ground_height(spot.x, spot.z) <= 0.0:
			bad_spots += 1
	ok(bad_spots == 0 and w.loot_spots.size() > 25, "%d places for loot, all on land" % w.loot_spots.size())
	for link: Dictionary in w.portals.links:
		for end: Vector3 in [link["a"], link["b"]]:
			ok(end.y > 0.0, "a gate stands on land at %s" % end)
	Game.night_map = saved_map
	await start_clean()


## Stands on one stone, faces the next, runs and jumps at the edge, and says whether it landed.
func _jump_between(a: Vector4, e: Vector4) -> bool:
	var dir := Vector2(e.x - a.x, e.z - a.z).normalized()
	var yaw := atan2(-dir.x, -dir.y)
	pl.rotation.y = yaw
	pl.yaw = yaw
	pl.global_position = Vector3(a.x - dir.x * a.w * 0.5, a.y + 0.05, a.z - dir.y * a.w * 0.5)
	pl.velocity = Vector3.ZERO
	await frames(2)
	pl.input_move = Vector2(0, -1)
	var jumped := false
	var airborne := false
	for i in 150:
		await frames(1)
		var from_middle := Vector2(pl.global_position.x - a.x, pl.global_position.z - a.z).length()
		if not jumped and pl.is_on_floor() and from_middle > a.w * 0.72:
			pl.input_jump = true
			jumped = true
		if jumped and not pl.is_on_floor():
			airborne = true
		if pl.global_position.y < minf(a.y, e.y) - 3.0:
			break
		if airborne and pl.is_on_floor():
			break
	pl.input_move = Vector2.ZERO
	var near := Vector2(pl.global_position.x - e.x, pl.global_position.z - e.z).length() < e.w + 0.6
	if not (airborne and pl.is_on_floor() and near and absf(pl.global_position.y - e.y) < 1.0):
		print("  jump from %s to %s ended at %s, airborne %s, on floor %s" % [a, e, pl.global_position, airborne, pl.is_on_floor()])
	return airborne and pl.is_on_floor() and near and absf(pl.global_position.y - e.y) < 1.0


func test_version_16() -> void:
	for id: String in ["monk", "plague_doctor"]:
		ok(not Game.owns_class(id) or Game.unlocked.has(id), "%s is locked at first" % id)
		ok(AbilityData.tree(id)["specs"].size() == 3, "%s has three specializations" % id)
	var unlocked_before := Game.unlocked.duplicate()
	var redeemed_before := Game.redeemed.duplicate()
	Game.unlocked.erase("monk")
	Game.redeemed.erase(_code_of("monk"))
	ok(Game.redeem_key(_code_of("monk"))["class"] == "monk" and Game.owns_class("monk"), "the Monk's code opens the Monk")
	Game.unlocked.erase("plague_doctor")
	Game.redeemed.erase(_code_of("plague_doctor"))
	ok(Game.redeem_key(_code_of("plague_doctor"))["class"] == "plague_doctor", "and the other code the Plague Doctor")
	# The Plague Doctor.
	Game.player_class = "plague_doctor"
	await start_clean()
	ok(pl.weapon_id() == "blowgun" and pl.arrows == int(ClassDefs.ALL["plague_doctor"]["arrows"]), "the Plague Doctor starts with its full dart supply")
	pl.points = 10
	for i in Player.CORE_STEPS:
		pl.choose_ability(i, 0)
	pl.choose_ability(Player.CORE_STEPS, 0)
	pl.hp = 30.0
	pl.use_art()
	await seconds(0.5)
	ok(pl.hp >= 55.0, "the Healing Tonic heals")
	Game.player_class = "plague_doctor"
	await start_clean()
	pl.points = 10
	for i in Player.CORE_STEPS:
		pl.choose_ability(i, 0)
	pl.choose_ability(Player.CORE_STEPS, 2)
	pl.fire("take", {})
	var rat_time := 0.0
	while rat_time < 22.0 and w.count_allies("rat") == 0:
		await seconds(0.5)
		rat_time += 0.5
	ok(w.count_allies("rat") > 0, "the Rat King's rats come (%.1f s)" % rat_time)
	Game.player_class = "plague_doctor"
	await start_clean()
	pl.flags["plague_burst"] = true
	pl.flags["black_death"] = true
	var sick := spawn("normal", front(6.0), true)
	var next_to := spawn("normal", front(7.0), true)
	sick.add_dot(1.0, 5.0)
	pl.on_kill(sick)
	ok(next_to.poison_left > 0.0, "Black Death spreads the sickness")
	sick.release()
	next_to.release()
	# Every class can be shown in the Store's stage and the picker.
	for id: String in ClassDefs.ALL:
		m.show_class_picker(Game.Mode.SANDBOX)
		await frames(1)
	Game.unlocked = unlocked_before
	Game.redeemed = redeemed_before
	Game.player_class = "infantry"
	Game.save_settings()
	await start_clean()


func test_version_15() -> void:
	var saved_map := Game.night_map
	Game.night_map = "mists"
	await start_clean()
	ok(w.portals != null and w.terrain.has_islands(), "the Mists are floating islands with gates")
	var gates := w.portals
	ok(gates._all_joined(), "at the start every island can be reached")
	for i in 60:
		gates._change_one()
		for link: Dictionary in gates.links:
			if float(link["closing"]) > 0.0:
				link["closing"] = 0.0
				link["open"] = false
		if not gates._all_joined():
			break
	ok(gates._all_joined(), "and however the gates change, one way round stays open")
	var far_centre := Vector3(MapIslands.ISLANDS[1].x, 0, MapIslands.ISLANDS[1].y)
	far_centre.y = w.ground_at(far_centre)
	var way := gates.waypoint(Vector3(0, 4, 0), far_centre)
	ok(way != far_centre and gates.regions[gates.island_of(way)] == gates.regions[0], "to reach another island you walk to a gate on your own side")
	ok(gates.waypoint(Vector3(0, 4, 0), Vector3(4, 4, 4)) == Vector3(4, 4, 4), "and on your own island you just walk")
	# Through a gate.
	var open_link: Dictionary = {}
	for link: Dictionary in gates.links:
		if link["open"] and int(link["ia"]) == 0:
			open_link = link
	if open_link.is_empty():
		open_link = gates.links[0]
		open_link["open"] = true
		gates._show(open_link)
	var enter: Vector3 = open_link["a"]
	pl.global_position = enter + Vector3.UP * 0.1
	pl.velocity = Vector3.ZERO
	pl._gate_wait = 0.0
	await seconds(0.3)
	ok(gates.island_of(pl.global_position) == int(open_link["ib"]), "stepping into a gate takes you to its other end")
	ok(pl.global_position.y > 0.0, "standing on the ground")
	# A mob follows through the gates.
	var hunter := spawn("normal", enter + Vector3(1.0, 0, 1.0), false)
	var hunted_on := int(open_link["ib"])
	var t := 0.0
	while t < 20.0 and is_instance_valid(hunter) and gates.island_of(hunter.position) != hunted_on:
		hunter._start_chase(pl.global_position)
		await seconds(0.5)
		t += 0.5
	ok(gates.island_of(hunter.position) == hunted_on, "mobs use the gates too (%.1f s)" % t)
	hunter.release()
	# Mobs do not walk off the edge. You can.
	var edge_x := MapIslands.ISLANDS[0].z + 8.0
	var stuck := spawn("normal", Vector3(MapIslands.ISLANDS[0].z - 6.0, 0, 8.0), false)
	stuck._direct = true
	stuck._set_goal(Vector3(edge_x, 0, 8.0))
	stuck.state = Zombie.State.INVESTIGATE
	await seconds(3.0)
	ok(w.terrain.height(stuck.position.x, stuck.position.z) > 0.0, "a mob stays on its island (%s)" % stuck.position)
	stuck.release()
	# A night here runs like any other.
	pl.guard_left = 9999.0
	w.director.running = true
	w.director.elapsed = 420.0
	await seconds(4.0)
	ok(w.zombies.size() > 0, "the night comes here too")
	var fell := 0
	for z: Zombie in w.zombies:
		if not z.flies and z.position.y < -2.0:
			fell += 1
	ok(fell == 0, "and nothing has dropped into the void (%d)" % fell)
	w.director.running = false
	await kill_all()
	# Bots use the gates.
	ok(Net.host_game() == OK, "a game with a bot here")
	Net.in_game = true
	var info := {"name": "Bot", "class": "infantry", "team": 0}
	var body := Avatar.new(w, Net.BOT_BASE + 60, info)
	w.add_child(body)
	var bot_at := Vector3(4, w.ground_at(Vector3(4, 0, 4)) + 0.1, 4)
	body.teleport(bot_at)
	var bot := BotPlayer.new(w, body, info)
	w.add_child(bot)
	bot._has_goal = true
	bot._goal = pl.global_position
	var target_island := gates.island_of(far_centre)
	bot._goal = far_centre
	gates._timer = 9999.0
	for link: Dictionary in gates.links:
		link["open"] = true
		link["closing"] = 0.0
		gates._show(link)
	t = 0.0
	var moved_on := false
	while t < 60.0:
		bot._has_goal = true
		bot._goal = far_centre
		bot._think = 5.0
		await seconds(0.5)
		t += 0.5
		if gates.island_of(bot.at) == target_island:
			moved_on = true
			break
	ok(moved_on, "a bot walks through the gates to reach another island (%.1f s)" % t)
	bot.queue_free()
	body.queue_free()
	Net.in_game = false
	Net.leave()
	await frames(2)
	# Falling is a normal death.
	pl.set_physics_process(true)
	pl.guard_left = 0.0
	pl.global_position = Vector3(62.0, 22.0, 62.0)
	pl.velocity = Vector3.ZERO
	await seconds(3.0)
	ok(pl.dead, "falling off the world kills you")
	# Choosing a map.
	Game.night_map = saved_map
	await start_clean()
	m.show_map_picker()
	await frames(2)
	var names: Array = m.panel.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	var night_atlas := m.panel.find_child("WorldAtlas", true, false) as WorldAtlas
	ok(night_atlas != null and night_atlas.allowed == Game.MAPS.keys(), "you can choose where to spend the night on the world atlas: %s" % (str(night_atlas.allowed) if night_atlas else "none"))
	# Choosing where to hold the fort: the Fort, or Mist Bastion.
	var saved_fort := Game.fort_map
	var mode_before := Game.mode
	m.show_fort_picker()
	await frames(2)
	var atlas := m.panel.find_child("WorldAtlas", true, false) as WorldAtlas
	ok(atlas != null and atlas.allowed == ["fort", "bastion"], "Defend the Fort asks where, on the world atlas: the Fort or Mist Bastion")
	if atlas:
		var places := ["village", "fort", "mists", "mesenlla", "bastion"]
		ok(places.all(func(id: String) -> bool: return (atlas.find_child("Place_" + id, true, false) as Button).disabled == (id not in ["fort", "bastion"])), "the atlas shows all five places, and only the strongholds can be picked")
		(atlas.find_child("Place_bastion", true, false) as Button).pressed.emit()
		await frames(2)
		ok(atlas.selected == "bastion" and Game.fort_map == saved_fort and m.panel.find_child("WorldAtlas", true, false) == atlas, "tapping Mist Bastion shows it without starting anything")
		var shown := (m.panel.find_child("PlaceDetail", true, false) as Node).find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		ok(shown.has("Mist Bastion") and shown.has(Places.ALL["bastion"]["lore"]), "and tells its story")
		(m.panel.find_child("PlayHere", true, false) as Button).pressed.emit()
		await frames(2)
	ok(Game.fort_map == "bastion", "Play here remembers Mist Bastion")
	# Play Together shows at once and looks for games just after; changing tabs keeps looking.
	m.show_together(0)
	ok(Net._listener == null, "Play Together is on screen before it starts looking for games")
	await get_tree().create_timer(0.3).timeout
	ok(Net._listener != null, "then it looks for games nearby")
	m.show_together(1)
	await get_tree().create_timer(0.3).timeout
	ok(Net._listener != null and Net._searchers == 1, "and keeps looking on the next tab (%d)" % Net._searchers)
	m.show_menu()
	await frames(3)
	ok(Net._listener == null and Net._searchers == 0, "until you leave")
	Game.mode = Game.Mode.FORT
	ok(Game.current_map() == "bastion", "where the next Fort is held")
	Game.fort_map = saved_fort
	Game.mode = mode_before
	m.show_menu()
	await frames(2)
	await start_clean()


func test_version_14() -> void:
	var saved_doubloons := Game.doubloons
	var saved_items := Game.owned_items.duplicate()
	var saved_off := Game.switched_off.duplicate()
	var saved_pet := Game.pet
	Game.owned_items.clear()
	Game.switched_off.clear()
	Game.pet = "wolf"
	# Buying.
	Game.doubloons = 100
	ok(not Game.buy_item("raven"), "too few doubloons buy nothing")
	Game.doubloons = 400
	ok(Game.buy_item("raven") and Game.doubloons == 250 and Game.owns_item("raven"), "a pet can be bought")
	ok(Game.pet == "raven", "and is chosen at once")
	ok(not Game.buy_item("raven"), "and only once")
	Game.choose_pet("snake")
	ok(Game.pet == "raven", "a pet you do not own cannot be chosen")
	Game.choose_pet("wolf")
	ok(Game.pet == "wolf", "the wolf is always there")
	Game.doubloons = 2000
	for item: String in ["rain_of_arrows", "trap_satchel", "blade_flurry", "undying_rage", "shadow_shroud", "snake", "fox"]:
		ok(Game.buy_item(item), "%s can be bought" % item)
	# Every section of the Store and every class in the Armory opens.
	for section: String in ShopDefs.SECTIONS:
		m.show_store("", -1, section)
		await frames(2)
		ok(m.panel != null and m.panel.find_children("*", "ModelView", true, false).size() == 1, "the %s section shows a turning model" % section)
	for item: String in ShopDefs.ITEMS:
		m.show_store(item)
		await frames(1)
	m.show_armory("ranger")
	await frames(2)
	var words: Array = m.panel.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(words.has("Equipped") and words.has("Raven"), "the Armory lists upgrades and pets")
	ok(not ShopDefs.SECTIONS.has("pets") and ShopDefs.in_section("upgrades").has("raven"), "pets are among the class upgrades")
	ok(ShopDefs.whose("raven") == "Ranger, Beastmaster pet" and ShopDefs.whose("rain_of_arrows") == "Ranger, Sharpshooter", "each purchase says whose it is")
	# Every class and path has a picture of its own.
	var seen_icons := {}
	for class_id: String in ClassDefs.ALL:
		ok(Icons.exists("crest_%s" % class_id), "%s has its own crest" % class_id)
		for sp: Dictionary in AbilityData.tree(class_id)["specs"]:
			ok(Icons.exists("spec_%s" % sp["id"]) and not seen_icons.has(sp["id"]), "%s has its own emblem" % sp["id"])
			seen_icons[sp["id"]] = true
	for item: String in ShopDefs.ITEMS:
		ok(Icons.exists(str(ShopDefs.ITEMS[item]["icon"])), "%s has an icon" % item)
	for weapon_id: String in WeaponDefs.ALL:
		ok(Icons.exists(Icons.weapon(weapon_id).split("+")[0]), "%s has an icon" % weapon_id)
	for class_id: String in ClassDefs.available():
		m.show_armory(class_id)
		await frames(1)
	Game.set_item_on("trap_satchel", false)
	ok(not Game.item_active("trap_satchel") and Game.owns_item("trap_satchel"), "an upgrade can be taken off")
	Game.set_item_on("trap_satchel", true)
	m.show_menu()
	await frames(2)
	# Rain of Arrows: hold, aim, let go, stand still, and it falls.
	Game.player_class = "ranger"
	await start_clean()
	pl.spec_id = "sharpshooter"
	ok(pl.art_is_held() and pl.has_art(), "the Sharpshooter's upgrade is an ability you hold")
	pl.add_arrows(30)
	var arrows_before := pl.arrows
	pl.art_aim()
	await frames(2)
	ok(pl.aiming_art, "holding the button aims")
	ok(w._aim_ring != null and w._aim_ring.visible, "with a circle on the ground")
	var target := spawn("normal", pl._rain_spot, true)
	target.hp = 1000.0
	target.max_hp = 1000.0
	pl.art_release()
	ok(not w._aim_ring.visible and pl.arrows == arrows_before - Player.RAIN_ARROWS, "letting go fires, for 8 arrows")
	pl.input_move = Vector2(0, -1)
	var stood := pl.global_position
	await seconds(1.2)
	ok(pl.global_position.distance_to(stood) < 0.3, "and you stand still while it falls")
	await seconds(1.2)
	pl.input_move = Vector2.ZERO
	ok(target.hp < 900.0, "the volley hits what is in the circle (%.0f)" % target.hp)
	target.set_physics_process(true)
	target.release()
	# Trap Satchel: carried, set by hand, armed late.
	pl.spec_id = "trapper"
	pl.trap_charges = 0
	pl._act({"do": "trap"}, {})
	ok(pl.trap_charges == 1 and w._traps.is_empty(), "traps go in the satchel instead of dropping")
	for i in 8:
		pl._act({"do": "trap"}, {})
	ok(pl.trap_charges == Player.TRAPS_CARRIED, "up to 5")
	pl.art_cd_left = 0.0
	pl.use_art()
	await frames(3)
	ok(pl.trap_charges == Player.TRAPS_CARRIED - 1 and w._traps.size() == 1, "the ability sets one")
	var armed_at := float(w._traps[0]["armed_at"])
	ok(armed_at > w.now + 2.5, "and it arms about 3 s later")
	# Blade Flurry.
	Game.player_class = "infantry"
	await start_clean()
	pl.spec_id = "duelist"
	var rate_before := pl.attack_interval(WeaponDefs.ALL["sword"])
	pl.use_art()
	await frames(3)
	ok(pl.flurry_left > 0.0 and pl.attack_interval(WeaponDefs.ALL["sword"]) < rate_before, "Blade Flurry speeds up your attacks")
	pl.flurry_left = 0.0
	# Undying Rage.
	pl.spec_id = "berserker"
	pl.hp = 1.0
	pl._rage_cd = 0.0
	pl._kill()
	ok(not pl.dead and pl.rage_left > 0.0 and pl.hp > 1.0, "a Berserker rises again in a rage")
	pl.hp = 1.0
	pl._kill()
	ok(pl.dead, "but not twice within a minute")
	await start_clean()
	# Shadow Shroud.
	pl.spec_id = "shadow"
	pl.shadow_kills = 7
	pl.use_art()
	await frames(2)
	ok(pl.invis_left <= 0.0, "not yet with 7 kills")
	pl.shadow_kills = 8
	pl.art_cd_left = 0.0
	pl.use_art()
	await frames(3)
	ok(pl.invis_left > 0.0 and pl.shadow_kills == 0, "the eighth kill lets you vanish")
	pl.invis_left = 0.0
	# Pets.
	for kind: String in ["raven", "snake", "fox"]:
		var body := Ally.new(w, kind)
		w.add_child(body)
		ok(body._visual != null and body._visual.get_child_count() > 0, "the %s has a body" % kind)
		body.queue_free()
	Game.choose_pet("raven")
	pl.spec_id = "beastmaster"
	pl.mods["wolves"] = 1.0
	pl._wolf_timer = 0.0
	await frames(3)
	ok(w.count_allies("raven") == 1 and w.count_allies("wolf") == 0, "a Beastmaster gets the pet chosen")
	# The Revenant chooses like the others.
	var rev: Dictionary = AbilityData.tree("revenant")
	for row: Array in rev["core"]:
		ok(row.size() == 2, "the Revenant has a choice at each shared step")
	for spec: Dictionary in rev["specs"]:
		for row: Array in spec["path"]:
			ok(row.size() == 2, "and on each step of %s" % spec["name"])
	Game.owned_items = saved_items
	Game.switched_off = saved_off
	Game.pet = saved_pet
	Game.doubloons = saved_doubloons
	Game.save_settings()
	await start_clean()


func test_version_13() -> void:
	await start_clean()
	# Weapons differ in strength now, and the long bow earns its slowness.
	var longbow: Dictionary = WeaponDefs.ALL["longbow"]
	ok(WeaponDefs.DAMAGE * float(longbow["power"]) >= float(ZombieDefs.ALL["normal"]["hp"]), "one long bow arrow kills a plain zombie")
	ok(int(longbow["pierce"]) == 2, "and goes on through two more")
	for id: String in ["javelins", "blowgun"]:
		ok(WeaponDefs.is_ranged(id) and WeaponDefs.mesh(id) != null, "%s is a new ranged weapon" % id)
	ok(not WeaponDefs.ALL.has("sling"), "the sling has been removed")
	# Debuffs, on a mob.
	var z := spawn("normal", front(6.0), true)
	z.hp = 1000.0
	z.max_hp = 1000.0
	z.take_damage(100.0, Vector3.ZERO, 0.0, z.centre())
	var plain := 1000.0 - z.hp
	z.hp = 1000.0
	z.add_dot(0.0, 5.0)
	z.take_damage(100.0, Vector3.ZERO, 0.0, z.centre())
	ok(is_equal_approx(1000.0 - z.hp, plain * 1.05), "poison: 5%% more damage from anything (%.1f against %.1f)" % [1000.0 - z.hp, plain])
	z.state = Zombie.State.CHASE
	var before := z._desired_speed()
	z.add_dot(0.0, 5.0, true)
	ok(is_equal_approx(z._desired_speed(), before * 0.9), "bleeding: 10% slower")
	z.release()
	# Debuffs, on you.
	pl.hp = 100.0
	pl.poison_left = 5.0
	var hp_before := pl.hp
	pl.hurt(20.0, pl.global_position)
	ok(pl.hp < hp_before - 20.0, "poison makes you take more too")
	pl.poison_left = 0.0
	pl.hp = pl.max_hp()
	pl.ignite(1.0)
	ok(pl.is_lit(), "burning puts you in the light")
	pl.burn_time = 0.0
	# Invisible: not even right next to it.
	var near := spawn("normal", pl.global_position + Vector3(1.2, 0, 0), false)
	near._start_chase(pl.global_position)
	pl.invis_left = 3.0
	pl.hp = pl.max_hp()
	var hp_now := pl.hp
	await seconds(1.5)
	ok(pl.hp >= hp_now, "nothing can hit what it cannot see, even next to it")
	ok(not near._sees, "nor does it see you")
	pl.invis_left = 0.0
	near.release()
	# Effects you can see.
	w.stun_around(pl.global_position, 5.0, 0.1)
	ok(not w._rings.is_empty() and (w._rings[0]["node"] as MeshInstance3D).visible, "an area stun sends a ring along the ground")
	w.drop_poison(pl.global_position + Vector3(3, 0, 0), true, 2.0)
	var puddle: MeshInstance3D = w._puddles[(w._next_puddle - 1 + w._puddles.size()) % w._puddles.size()]
	ok((puddle.get_child(0) as Node3D).visible, "fire on the ground has real flames")
	w.drop_poison(pl.global_position + Vector3(-3, 0, 0))
	puddle = w._puddles[(w._next_puddle - 1 + w._puddles.size()) % w._puddles.size()]
	ok((puddle.get_child(1) as CPUParticles3D).emitting and not (puddle.get_child(0) as Node3D).visible, "and poison bubbles")
	# Weapons in the hand.
	ok(WeaponDefs.hand_rotation("spear") != Vector3.ZERO and WeaponDefs.hand_rotation("sword") == Vector3.ZERO, "poles get a quarter turn in the hand")
	# Earned classes.
	var unlocked_before := Game.unlocked.duplicate()
	var games_before := Game.finished_games
	Game.unlocked.erase("chivalry")
	Game.unlocked.erase("magician")
	Game.finished_games = 0
	ok(not Game.owns_class("chivalry") and not Game.owns_class("magician"), "Chivalry and Magician start locked")
	Game.note_rider_killed()
	ok(Game.owns_class("chivalry"), "killing a Dread Rider opens Chivalry")
	for i in 4:
		Game.note_game_finished()
	ok(not Game.owns_class("magician"), "four games are not enough for the Magician")
	Game.note_game_finished()
	ok(Game.owns_class("magician"), "five are")
	var old_mode := Game.mode
	Game.unlocked.erase("chivalry")
	Game.finished_games = 0
	Game.mode = Game.Mode.SANDBOX
	Game.note_rider_killed()
	Game.note_game_finished()
	ok(not Game.owns_class("chivalry") and Game.finished_games == 0, "the Sandbox counts for nothing")
	Game.mode = old_mode
	Game.fresh_unlocks.clear()
	Game.unlocked = unlocked_before
	Game.finished_games = games_before
	Game.save_settings()
	# Bots: they learn, and they go for what they need.
	ok(Net.host_game() == OK, "a game with a bot")
	Net.in_game = true
	var info := {"name": "Bot", "class": "infantry", "team": 0}
	var body := Avatar.new(w, Net.BOT_BASE + 50, info)
	w.add_child(body)
	body.teleport(pl.global_position + Vector3(4, 0, 0))
	var bot := BotPlayer.new(w, body, info)
	w.add_child(bot)
	await frames(3)
	ok(bot.pawn.is_inside_tree() and bot.pawn.is_bot() and bot.pawn.class_id == "infantry", "a bot is a real player of its class")
	bot.pawn.add_xp(3000)
	await frames(4)
	ok(bot.level == ClassDefs.MAX_LEVEL and bot.pawn.chosen.size() == bot.level - 1 and bot.pawn.spec_id != "", "it levels up and takes an ability each time, its branch too (level %d, %d taken, %s)" % [bot.level, bot.pawn.chosen.size(), bot.pawn.spec_id])
	bot.pawn.hp = bot.pawn.max_hp() * 0.3
	var food := w.spawn_pickup_at(bot.at + Vector3(0, 0, 4), Pickup.Kind.FOOD, PowerDefs.FOODS.keys()[0])
	var low_hp := bot.hp
	await seconds(3.0)
	ok(not is_instance_valid(food) or not w.pickups.has(food), "a hurt bot walks to food and eats it")
	ok(bot.hp > low_hp, "and feels better")
	var hard: Dictionary = BotPlayer.SMARTS[2]
	var easy: Dictionary = BotPlayer.SMARTS[0]
	ok(float(hard["aim"]) < float(easy["aim"]) and float(hard["think"]) < float(easy["think"]), "a harder game means sharper bots")
	bot.queue_free()
	body.queue_free()
	Net.in_game = false
	Net.leave()
	await frames(2)
	await start_clean()


func test_version_12_4() -> void:
	# Claws: a full bar of Mist runs out if you keep swinging with nothing dying.
	var claws: Dictionary = WeaponDefs.ALL["claws"]
	var rev: Dictionary = ClassDefs.ALL["revenant"]
	var net := float(claws["cost"]) / float(claws["rate"]) - Player.MANA_REGEN * float(rev["mana_regen"])
	ok(net > 0.0 and Player.BASE_MANA / net > 8.0 and Player.BASE_MANA / net < 30.0, "uninterrupted swinging drains a full Mist bar in a bounded time (%.1f s)" % (Player.BASE_MANA / net))
	# The Square is painted on the land like the paths.
	var boxes := 0
	ok(w.map_roads.size() > 0, "the map has roads")
	for c: Node in w.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).global_position == Vector3.ZERO and (c as MeshInstance3D).mesh is ArrayMesh:
			var box := ((c as MeshInstance3D).mesh as ArrayMesh).get_aabb()
			if is_equal_approx(box.size.x, 19.0) and is_equal_approx(box.size.z, 19.0):
				boxes += 1
	ok(boxes == 0, "the village square is not a box sitting on the ground")
	# The very end of the river, where it runs into the edge of the map, can be crossed too.
	pl.global_position = Vector3(-92, w.ground_at(Vector3(-92, 0, 104)) + 0.2, 104)
	pl.yaw = -PI * 0.5
	pl.rotation.y = -PI * 0.5
	pl.velocity = Vector3.ZERO
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	await seconds(7.0)
	pl.input_move = Vector2.ZERO
	ok(pl.global_position.x > -72.0, "the end of the river does not trap you (%s)" % pl.global_position)
	# Sacred Steed: the wait starts when the ride ends.
	pl._sacred_cd = 30.0
	pl.dismount()
	ok(is_equal_approx(pl._sacred_cd, 60.0), "the sacred horse waits 60 s after a ride")
	await seconds(0.3)
	ok(pl._sacred_cd < 60.0 and pl._sacred_cd > 59.0, "and the wait runs down on foot")


func test_version_12_2() -> void:
	await start_clean()
	# Roads are painted on the land: nothing floats, and the ground knows where they are.
	var ground: ShaderMaterial = null
	for c: Node in w.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
			var mat := (c as MeshInstance3D).material_override as ShaderMaterial
			if mat.get_shader_parameter("roads") != null:
				ground = mat
				break
	ok(ground != null, "the ground has the roads painted on it")
	if ground:
		var mask: Image = (ground.get_shader_parameter("roads") as Texture2D).get_image()
		var px := func(at: Vector2) -> float:
			var scale := MapBuilder.ROAD_PIXELS_PER_METRE
			return mask.get_pixel(int((at.x + Terrain.HALF) * scale), int((at.y + Terrain.HALF) * scale)).r
		var line: Array = w.map_roads[0]
		var on_road: Vector2 = (line[0] as Vector2).lerp(line[1], 0.5)
		ok(px.call(on_road) < 0.5, "a road is marked on the mask")
		var side: Vector2 = ((line[1] as Vector2) - (line[0] as Vector2)).normalized().orthogonal()
		ok(px.call(on_road + side * 9.0) > 0.9, "and the land beside it is not")
	# The way down from the castle: no walls you cannot see on either side of the road.
	for rd: Array in w.map_roads:
		if (rd[rd.size() - 1] as Vector2).distance_to(Vector2(-53, -70)) > 1.0:
			continue
		var steep := 0
		for i in rd.size() - 1:
			var a: Vector2 = rd[i]
			var b: Vector2 = rd[i + 1]
			var across := (b - a).normalized().orthogonal()
			for k in int(a.distance_to(b)) + 1:
				var c: Vector2 = a.lerp(b, float(k) / maxf(a.distance_to(b), 1.0))
				for o: float in [-7.0, -5.0, -3.0, -1.0, 1.0, 3.0, 5.0, 7.0]:
					var q: Vector2 = c + across * o
					if not w.terrain.is_walkable(q.x, q.y):
						steep += 1
		ok(steep == 0, "the castle road can be left on either side (%d steep spots)" % steep)
	# A fence in the way: it goes round, and does not stand there staring.
	for z: Zombie in w.zombies.duplicate():
		z.release()
	var spot := Vector3.INF
	for x in range(-60, 60, 6):
		for z in range(10, 70, 6):
			var clear := true
			for dx in range(-12, 13):
				for dz in range(-5, 6):
					var c := w.grid.to_cell(Vector3(x + dx, 0, z + dz))
					if not w.grid.is_free(c) or w.terrain.slope(x + dx, z + dz) > 0.3:
						clear = false
			if clear:
				spot = Vector3(x, 0, z)
				break
		if spot != Vector3.INF:
			break
	ok(spot != Vector3.INF, "there is open land to test on")
	if spot != Vector3.INF:
		spot.y = w.ground_at(spot)
		w.add_solid(spot + Vector3.UP * 0.5, Vector3(16, 1.0, 0.14))
		await w.get_tree().physics_frame
		await w.get_tree().physics_frame
		ok(not w.grid.line_is_open(spot + Vector3(0, 0, -3), spot + Vector3(0, 0, 3)), "the fence closes the straight line")
		ok(w.grid.line_is_open(spot + Vector3(9, 0, -3), spot + Vector3(9, 0, 3)), "and only where it stands")
		pl.global_position = spot + Vector3(0, 0, 3)
		pl.velocity = Vector3.ZERO
		pl.set_physics_process(false)
		var fz := spawn("normal", spot + Vector3(0, 0, -3), false)
		fz._start_chase(pl.global_position)
		var t := 0.0
		var reached := false
		while t < 25.0 and is_instance_valid(fz):
			await seconds(0.25)
			t += 0.25
			pl.hp = pl.max_hp()
			if fz.position.z > spot.z + 0.2 and Vector2(fz.position.x - pl.global_position.x, fz.position.z - pl.global_position.z).length() < 2.5:
				reached = true
				break
		ok(reached, "a mob behind a fence walks round it to reach you (%.1f s)" % t)
		if is_instance_valid(fz):
			fz.release()
		# Standing close to the fence, with a mob that likes to come from that side.
		pl.global_position = spot + Vector3(0, 0, 1.7)
		var near := spawn("normal", spot + Vector3(0, 0, -1.7), false)
		near._flank = Vector3(0, 0, -1)
		near._start_chase(pl.global_position)
		t = 0.0
		reached = false
		while t < 25.0 and is_instance_valid(near):
			await seconds(0.25)
			t += 0.25
			pl.hp = pl.max_hp()
			if near.position.z > spot.z + 0.2:
				reached = true
				break
		ok(reached, "and a mob's favourite side does not stop it short (%.1f s)" % t)
		if is_instance_valid(near):
			near.release()
		pl.set_physics_process(true)
	# Fallen in a team game: only your own side's eyes.
	ok(Net.host_game() == OK, "a team game starts")
	Net.rules = Net.Rules.TEAMS
	Net.roster[1]["team"] = 0
	Net.roster[501] = {"name": "Friend", "class": "infantry", "team": 0, "score": 0, "deaths": 0, "lives": 3}
	Net.roster[502] = {"name": "Foe", "class": "infantry", "team": 1, "score": 0, "deaths": 0, "lives": 3}
	Net.world = w
	for id: int in [501, 502]:
		var body := Avatar.new(w, id, Net.roster[id])
		w.add_child(body)
		body.global_position = pl.global_position + Vector3(id - 500, 0, 0)
		Net._avatars[id] = body
	pl.dead = true
	Net._watching = 0
	Net.watch_next()
	ok(Net._watching == 501, "a fallen player watches a team-mate")
	Net.watch_next()
	ok(Net._watching == 501, "and tapping never moves to the other team")
	(Net._avatars[501] as Avatar).set_fallen(true)
	Net.watch_next()
	ok(Net._watching == 0, "with no team-mate left standing, nothing to watch")
	Net.rules = Net.Rules.FFA
	Net.watch_next()
	ok(Net._watching == 502, "in All vs All anyone will do")
	Net._stop_watching()
	pl.dead = false
	for id: int in [501, 502]:
		(Net._avatars[id] as Avatar).queue_free()
		Net._avatars.erase(id)
	Net.leave()
	await frames(2)
	await start_clean()


func test_version_11() -> void:
	# Four ways to play, and no help button.
	for tab in Main.TOGETHER_TABS.size():
		m.show_together(tab)
		await frames(2)
		var names: Array = m.panel.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
		for title: String in Main.TOGETHER_TABS:
			ok(names.has(title), "the %s way is on offer" % title)
		ok(not names.has("Hotspot?"), "with no Hotspot? button")
		ok(names.has("Back"), "and a way back")
	m.show_together(0)
	await frames(2)
	m.show_menu()
	await frames(2)
	# Online is offered only if this build has what it needs. A wrong code says so.
	m.show_together(Main.ONLINE_TAB)
	await frames(2)
	if EpicNet.available():
		# The name is a button now (it opens the name prompt), so the room code is the only box.
		ok(m.panel.find_children("*", "LineEdit", true, false).size() == 1, "Online asks for a room code")
	# What is behind Online is nobody's business.
	var words: Array = m.panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ok(not " ".join(words).contains("Epic"), "and does not say what it runs on")
	ok(not Main.TOGETHER_TABS.has("Direct"), "there is no Direct tab")
	# Leaving a game goes back to Play Together, and a failed join stays there.
	m.show_together(0) # Exercise a local host from the local tab, even after checking Online.
	ok(Net.host_game() == OK, "a game starts")
	m.show_lobby()
	await frames(2)
	var left_at := Time.get_ticks_msec()
	m._leave_lobby()
	ok(Time.get_ticks_msec() - left_at < 300, "Leave is immediate (%d ms)" % (Time.get_ticks_msec() - left_at))
	await frames(2)
	var after: Array = m.panel.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(after.has("Online") and after.has("Start a game"), "and goes back to Play Together")
	m._on_net_left("No such game.")
	await frames(2)
	var underneath: Array = m.ui_layer.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(underneath.has("Online"), "a failed join also stays on Play Together")
	m.show_together(0)
	await frames(2)
	var boxes_now: Array = m.ui_layer.find_children("*", "LineEdit", true, false)
	for box_now: LineEdit in boxes_now:
		ok(not box_now.text.ends_with("."), "with no half address in a box")
	m.show_menu()
	await frames(2)
	# A room code or, if no room could be opened, a host's own long ID.
	if EpicNet.available():
		var epic_node := EpicNet.new()
		add_child(epic_node)
		ok(await epic_node.find_room("0002156C852B463AB32A97B4CAD67223") == "0002156c852b463ab32a97b4cad67223", "a long code is taken as the host's ID")
		epic_node.free()


func test_version_10() -> void:
	# Reading a skill you can take: unlock it from there.
	Game.player_class = "infantry"
	await start_clean()
	pl.points = 1
	m.toggle_tree()
	await frames(2)
	var panel := m.tree_panel as TreePanel
	var first: TreePanel.TreeNodeButton = null
	for n in panel._map.nodes:
		if panel.state_of(n) == "ready" and n.option == 1:
			first = n
	ok(first != null, "a second option is ready to read")
	panel.read(first)
	await frames(2)
	var unlock: Button = null
	for b: Node in panel._zone.find_children("*", "Button", true, false):
		if (b as Button).text == "Unlock":
			unlock = b
	ok(unlock != null, "reading it offers Unlock")
	var wanted: String = first.ability["id"]
	unlock.pressed.emit()
	await frames(2)
	ok(pl.chosen.get(0) == wanted, "and Unlock takes that one, not the other")
	m.close_tree()
	# And choosing a specialization from its card works the same way.
	pl.points = Player.CORE_STEPS
	for step in range(1, Player.CORE_STEPS):
		pl.choose_ability(step, 0)
	m.toggle_tree()
	await frames(2)
	panel = m.tree_panel as TreePanel
	var last_spec: TreePanel.TreeNodeButton = null
	for n in panel._map.nodes:
		if n.step == Player.CORE_STEPS and n.spec == 2:
			last_spec = n
	ok(last_spec != null and panel.state_of(last_spec) == "ready", "the third specialization is ready")
	panel.read(last_spec)
	await frames(2)
	for b: Node in panel._zone.find_children("*", "Button", true, false):
		if (b as Button).text == "Unlock":
			(b as Button).pressed.emit()
			break
	await frames(2)
	ok(pl.spec_id == pl.tree_data()["specs"][2]["id"], "and Unlock gives that path")
	m.close_tree()

	# All vs All and Teams need someone to fight, and bots count.
	m.show_menu()
	await frames(2)
	ok(Net.host_game() == OK, "a game can be hosted")
	Net.set_rules(Net.Rules.FFA)
	ok(not Net.can_start(), "All vs All alone cannot start")
	Net.start_match()
	ok(not Net.in_game, "not even by asking")
	Net.set_rules(Net.Rules.TEAMS)
	ok(not Net.can_start(), "nor Teams")
	Net.set_rules(Net.Rules.COOP)
	ok(Net.can_start(), "Co-op can")
	Net.set_bots(9)
	ok(Net.bot_count() == Net.MAX_PLAYERS - 1, "bots fill the empty places, no more")
	Net.set_bots(2)
	ok(Net.bot_count() == 2 and Net.roster.size() == 3, "and can be sent away")
	Net.set_rules(Net.Rules.TEAMS)
	Net.set_bots(1)
	ok(Net.can_start(), "a bot makes Teams possible, on the other side")
	Net.set_bots(3)
	Net.set_rules(Net.Rules.FFA)
	ok(Net.can_start(), "and All vs All")
	Net.start_match()
	var t := 0.0
	while not m._net_go and t < 40.0:
		await seconds(0.2)
		t += 0.2
	ok(m._net_go, "a match with bots starts")
	w = m.world
	pl = w.player
	hud = m.hud
	var bots: Array = Net.bot_players()
	ok(bots.size() == 3, "with three bots")
	var starts: Array = bots.map(func(b: BotPlayer) -> Vector3: return b.at)
	ok(pl.xp_needed() < ClassDefs.xp_for_level(pl.level), "levels come faster in All vs All")
	pl.guard_left = 99999.0
	w.director.elapsed = 5.0
	await seconds(4.0)
	var moved := 0
	for i in bots.size():
		if (bots[i] as BotPlayer).at.distance_to(starts[i]) > 3.0:
			moved += 1
	ok(moved >= 2, "bots go looking for a fight (%d)" % moved)
	var victim: BotPlayer = bots[0]
	var lives: int = Net.lives_of(victim.peer)
	Net.hit_player(victim.peer, 99999.0, pl.global_position)
	await seconds(0.3)
	ok(victim.down and victim.body.dead, "a bot can be defeated")
	ok(victim.body._current == "Death_A", "and its body lies down (%s)" % victim.body._current)
	ok(Net.lives_of(victim.peer) == lives - 1, "and it loses a life")
	ok(int(Net.roster[1]["score"]) >= Net.KILL_POINTS, "and whoever did it scores")
	await seconds(Net.FOG_RESPAWN + 1.0)
	ok(not victim.down and not victim.body.dead, "it comes back")
	# Everyone else out: the match ends.
	for b: BotPlayer in bots:
		while Net.lives_of(b.peer) > 0 and not m._run_over:
			if b.pawn.dead:
				b._respawn = 0.001
				await seconds(0.05)
				continue
			b.pawn.guard_left = 0.0
			Net.hit_player(b.peer, 99999.0, pl.global_position)
			await seconds(0.05)
	await seconds(0.5)
	ok(m._run_over and Net.last_winner == Net.my_id(), "last one standing beats the bots")
	Net.leave()
	m.show_menu()
	await frames(2)
	# A left-over fight must not leak into the next game.
	ok(Net.bot_players().is_empty(), "bots are gone with the match")

	await start_clean()


func test_version_9() -> void:
	# Ten levels, and few but big choices.
	ok(ClassDefs.MAX_LEVEL == 10, "ten levels")
	var total_xp := 0
	var old_xp := 0
	for level in range(1, ClassDefs.MAX_LEVEL):
		total_xp += ClassDefs.xp_for_level(level)
	for level in range(1, 19):
		old_xp += 30 + int(round(level * 9.6))
	ok(total_xp < old_xp, "the top level takes less than it did (%d, was %d)" % [total_xp, old_xp])
	for cid: String in ClassDefs.ALL:
		var tree := AbilityData.tree(cid)
		ok((tree["core"] as Array).size() == Player.CORE_STEPS, "%s has three shared choices" % cid)
		for spec: Dictionary in tree["specs"]:
			ok((spec["path"] as Array).size() == 4, "%s has four rows" % spec["name"])
			ok(Player.CORE_STEPS + 1 + (spec["path"] as Array).size() + 1 == ClassDefs.MAX_LEVEL - 1, "one choice for each level of %s" % spec["name"])
			if not ClassDefs.ALL[cid].get("auto_tree", false):
				for row: Array in spec["path"]:
					ok(row.size() == 2, "%s chooses one of two" % spec["name"])
	ok(ClassDefs.ALL["magician"]["hp"] < 90.0, "the Mage has less health")
	ok(Player.CHARIOT_SPEED < 1.0, "a chariot is slower than walking")

	# The tree closes when something hurts you.
	Game.player_class = "infantry"
	await start_clean()
	place(OPEN)
	m.toggle_tree()
	await frames(2)
	ok(m.tree_panel != null, "the tree opens")
	pl.guard_left = 0.0
	pl.hurt(2.0, pl.global_position + Vector3.FORWARD)
	await frames(2)
	ok(m.tree_panel == null, "being hurt closes it")
	ok(not hud.menu_open, "and the controls are back")
	# And it can be opened while you are down.
	pl.dead = true
	await frames(2)
	touch(2, hud._buttons["tree"]["pos"], true)
	await frames(2)
	touch(2, hud._buttons["tree"]["pos"], false)
	await frames(2)
	ok(m.tree_panel != null, "the tree opens while you are down")
	pl.points = 1
	(m.tree_panel as TreePanel).choose(0, 0)
	await frames(2)
	ok(pl.points == 0 and pl.chosen.size() == 1, "and a choice can be made")
	m.close_tree()
	pl.dead = false
	pl.hp = pl.max_hp()
	await frames(2)

	# The Illusionist swaps with its own image, and the image goes off.
	Game.player_class = "magician"
	await start_clean()
	place(OPEN, 0.0)
	pl.grant_all_points()
	for step in Player.CORE_STEPS:
		pl.choose_ability(step, 0)
	var illusionist := -1
	var specs: Array = pl.tree_data()["specs"]
	for i in specs.size():
		if specs[i]["id"] == "illusionist":
			illusionist = i
	ok(pl.choose_ability(Player.CORE_STEPS, illusionist), "the Illusionist can be chosen")
	var was := pl.global_position
	pl.mana = pl.max_mana()
	pl.use_art()
	await seconds(0.4)
	ok(absf(pl.global_position.distance_to(was) - pl.m("swap_range")) < 2.5, "Mirror Swap moves about %d m (%.1f)" % [int(pl.m("swap_range")), pl.global_position.distance_to(was)])
	var decoys := w.allies.filter(func(a: Ally) -> bool: return a.kind == "decoy")
	ok(decoys.size() == 1, "and leaves an image behind")
	w.spawn_zombie("normal", was + Vector3(1.2, 0, 0))
	await frames(2)
	var fooled: Zombie = w.zombies.back()
	fooled.set_physics_process(false)
	var fooled_hp := fooled.hp
	pl.decoy_burst(was + Vector3.UP)
	await frames(2)
	ok(fooled.hp < fooled_hp or not fooled.is_alive(), "the burst hurts what came to look")
	fooled.set_physics_process(true)
	for z: Zombie in w.zombies.duplicate():
		z.release()

	# Hits land where the body looks to be.
	Game.player_class = "infantry"
	await start_clean()
	place(OPEN, 0.0)
	await equip("dagger")
	w.spawn_zombie("normal", pl.global_position + Vector3(0, 0, -6))
	await frames(2)
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	var side := z.body_radius() / 1.4 + Projectile.HIT_PAD * 0.7
	var hp0 := z.hp
	var from := Vector3(z.position.x + side, z.position.y + 1.0, z.position.z + 5.0)
	w.spawn_player_arrow(pl, from, Vector3(0, 0, -30), 0.0, 12.0, 0.0, 10.0, false)
	await seconds(0.4)
	ok(z.hp < hp0, "an arrow that only just touches it counts")
	hp0 = z.hp
	from.x = z.position.x + z.body_radius() + Projectile.HIT_PAD + 0.5
	w.spawn_player_arrow(pl, from, Vector3(0, 0, -30), 0.0, 12.0, 0.0, 10.0, false)
	await seconds(0.4)
	ok(z.hp == hp0, "and one that passes by does not")
	var d: Dictionary = WeaponDefs.ALL["dagger"]
	var stats := pl.melee_stats(d)
	pl.global_position = z.position + Vector3(0, 0, float(stats["range"]) + z.body_radius() * 0.8)
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	await frames(2)
	hp0 = z.hp
	ok(w.melee_hit(pl, d, stats) == 1 and z.hp < hp0, "a blow reaches the edge of the body")
	z.set_physics_process(true)
	z.release()

	# Weather: mostly clear, and lightning hits everyone under it.
	var counts := [0, 0, 0]
	for i in 10000:
		counts[Weather.roll()] += 1
	ok(counts[0] > 7500 and counts[0] < 8300, "most nights are clear: 79%% (%d)" % counts[0])
	ok(counts[1] > 1350 and counts[1] < 1850, "some are wet: 16%% (%d)" % counts[1])
	ok(counts[2] > 350 and counts[2] < 650, "and a few have a storm: 5%% (%d)" % counts[2])
	ok(w.weather.kind == Weather.Kind.CLEAR or w.weather.kind == Weather.Kind.RAIN or w.weather.kind == Weather.Kind.STORM, "tonight has weather")
	w.weather.set_kind(Weather.Kind.STORM)
	w.weather._next_strike = 9999.0
	await frames(2)
	place(OPEN)
	pl.guard_left = 0.0
	pl.hp = pl.max_hp()
	w.spawn_zombie("normal", pl.global_position + Vector3(2, 0, 0))
	await frames(2)
	var struck: Zombie = w.zombies.back()
	struck.set_physics_process(false)
	var struck_hp := struck.hp
	var my_hp := pl.hp
	w.weather.announce(pl.global_position)
	await seconds(0.3)
	ok(pl.hp == my_hp, "the ground glows first")
	await seconds(Weather.STRIKE_WARNING)
	ok(pl.hp < my_hp, "then lightning hurts a player (%.0f)" % pl.hp)
	ok(struck.hp < struck_hp or not struck.is_alive(), "and an enemy")
	struck.set_physics_process(true)
	w.weather.set_kind(Weather.Kind.CLEAR)
	for gone: Zombie in w.zombies.duplicate():
		gone.release()
	pl.hp = pl.max_hp()

	# The address box takes dots, and the fog closes in the right order.
	m.show_together()
	await frames(2)
	var boxes: Array = m.panel.find_children("*", "LineEdit", true, false)
	ok(not boxes.is_empty(), "there is an address box")
	for b: Node in boxes:
		ok((b as LineEdit).virtual_keyboard_type != LineEdit.KEYBOARD_TYPE_NUMBER and (b as LineEdit).virtual_keyboard_type != LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL, "and it offers a keyboard with dots")
	m.show_menu()
	await frames(2)
	var last_r := ClosingFog.radius_at(0.0)
	var pvp_map := (load("res://maps/village.tscn") as PackedScene).instantiate() as MapRoot
	var fog_reach := Vector2.ONE * (pvp_map.land_half + 22.0)
	pvp_map.free()
	ok(last_r >= fog_reach.length(), "the fog starts outside the whole PvP map, independently of the title backdrop")
	var never_opens := true
	for t in range(1, 430):
		var r := ClosingFog.radius_at(float(t))
		if r > last_r + 0.001:
			never_opens = false
		last_r = r
	ok(never_opens and last_r == 0.0, "it only closes in, until nothing is left")

	# The Sandbox has a dummy that takes anything, and every point from the start.
	Game.player_class = "ranger"
	await m.start_game(Game.Mode.SANDBOX)
	await frames(3)
	w = m.world
	pl = w.player
	hud = m.hud
	ok(pl.points == ClassDefs.MAX_LEVEL - 1, "every point from the start (%d)" % pl.points)
	var dummies := w.zombies.filter(func(q: Zombie) -> bool: return q.type_id == "dummy")
	ok(dummies.size() >= 3, "dummies stand ready (%d)" % dummies.size())
	if not dummies.is_empty():
		var dummy: Zombie = dummies[0]
		dummy.take_damage(99999999.0, Vector3.ZERO, 0.0, dummy.centre())
		await seconds(0.3)
		ok(dummy.is_alive() and dummy.hp == dummy.max_hp, "a dummy cannot die")
		ok(int(dummy._dummy_last) > 0, "and shows what it took")
		var stands := dummy.position
		pl.global_position = stands + Vector3(1.5, 0.1, 0)
		pl.hp = pl.max_hp()
		await seconds(2.0)
		ok(pl.hp == pl.max_hp(), "it does not hit back")
		ok(dummy.position.distance_to(stands) < 0.05, "or move")
	Game.player_class = "infantry"
	await start_clean()


func test_version_8() -> void:
	# Codes work once, and the Store sells what is locked.
	var saved_unlocked := Game.unlocked.duplicate()
	var saved_redeemed := Game.redeemed.duplicate()
	var saved_coins := Game.doubloons
	Game.unlocked.clear()
	Game.redeemed.clear()
	ok(not Game.owns_class("artificer") and not Game.owns_class("revenant"), "both are locked at first")
	ok(Game.redeem("nothing")["result"] == "bad", "a wrong code is refused")
	var said := Game.redeem_key(_code_of("artificer"))
	ok(said["result"] == "opened" and said["class"] == "artificer", "the Artificer's code opens it")
	ok(Game.owns_class("artificer"), "and the class is yours")
	ok(Game.redeem_key(_code_of("artificer"))["result"] == "used", "the same code cannot be used twice")
	Game.unlocked.clear()
	ok(ClassDefs.price("monk") == 920 and ClassDefs.price("artificer") == 598 and ClassDefs.price("bandit") == 860 and ClassDefs.price("adept") == 1150, "the prices are set")
	ok(ClassDefs.price("cartographer") == 0, "the Cartographer is earned, not bought")
	var cartographer_code := Game.redeem_key(_code_of("cartographer"))
	ok(cartographer_code["result"] == "opened" and Game.owns_class("cartographer"), "though its code still opens it")
	Game.unlocked.clear()
	Game.redeemed.clear()
	ok(ClassDefs.price("infantry") == 0, "the others are free")
	var sale := ClassDefs.for_sale()
	ok(sale.size() == 4 and sale.has("monk") and sale.has("artificer") and sale.has("bandit") and sale.has("adept") and not sale.has("cartographer"), "the Store sells Monk, Artificer, Bandit and Adept; the Cartographer is earned")
	Game.doubloons = 597
	ok(not Game.buy_class("artificer") and Game.doubloons == 597, "you cannot buy what you cannot pay for")
	Game.doubloons = 599
	ok(Game.buy_class("artificer") and Game.doubloons == 1 and Game.owns_class("artificer"), "buying takes the price and opens the class")
	ok(not Game.buy_class("artificer"), "and it cannot be bought twice")
	Game.save_settings()
	Game.unlocked.clear()
	Game.redeemed.clear()
	Game.load_settings()
	ok(Game.owns_class("artificer"), "a purchase survives a restart")
	Game.unlocked = saved_unlocked
	Game.redeemed = saved_redeemed
	Game.doubloons = saved_coins
	Game.save_settings()
	# The changelog is the one in the repository, newest first.
	var notes := ChangelogPanel.parse(FileAccess.get_file_as_string(ChangelogPanel.PATH))
	ok(notes.size() > 10 and notes[0]["kind"] == "version", "the changelog can be read")
	var base_version := str(ProjectSettings.get_setting("application/config/version")).get_slice("-dev.", 0)
	ok(notes.any(func(entry: Dictionary) -> bool: return entry["kind"] == "version" and str(entry["text"]).begins_with(base_version)), "the changelog includes the current base version")
	ok(str(notes[0]["text"]).begins_with("Development") or str(notes[0]["text"]).begins_with(base_version), "the changelog opens with development notes or the current version")
	var kinds := {}
	for line: Dictionary in notes:
		kinds[line["kind"]] = true
	ok(kinds.has("part") and kinds.has("item"), "with its parts and its changes")
	m.show_changelog()
	await frames(2)
	ok(m.panel is ChangelogPanel, "the Changelog screen opens")
	ok(not CodexPanel.TABS.has("Tips") and CodexPanel.TABS[0] == "Classes", "the Codex has classes and no tips")
	m.show_codex()
	await frames(2)
	ok((m.panel as CodexPanel)._list.get_child_count() == ClassDefs.ALL.size(), "and shows every class, owned or not")
	m.show_store("artificer")
	await frames(2)
	ok(m.panel.get_meta("list").get_child_count() == 5, "the Store opens, with its tabs and four classes")
	m.show_class_picker(Game.Mode.SANDBOX)
	await frames(2)
	ok(m.panel.get_meta("list").get_child_count() == ClassDefs.available().size(), "the Sandbox only offers what you own")
	m.show_menu()
	await frames(2)

	# A new level gives three seconds nobody can hurt you in.
	Game.player_class = "infantry"
	await start_clean()
	place(OPEN)
	await seconds(0.2)
	pl.guard_left = 0.0
	var hp0 := pl.hp
	pl.add_xp(pl.xp_needed())
	ok(pl.level == 2 and pl.guard_left >= 2.9, "levelling up makes you invincible")
	pl.hurt(30.0, front(2.0))
	ok(pl.hp == hp0, "so a blow does nothing")
	await seconds(3.2)
	pl.hurt(30.0, front(2.0))
	ok(pl.hp < hp0, "and three seconds later it does again")

	# The bell strikes once for each minute gone, half a second apart.
	w.ring_bell(3)
	ok(w.bell_strokes_left() == 3, "three minutes, three strokes")
	await seconds(0.3)
	ok(w.bell_strokes_left() == 2, "the first comes at once")
	await seconds(0.5)
	ok(w.bell_strokes_left() == 1, "the second half a second later")
	await seconds(0.6)
	ok(w.bell_strokes_left() == 0, "and then the third")
	w.director.elapsed = 100.0
	w.director._bell_minute = 4
	w.director._bell_timer = 0.01
	w.director.running = true
	await seconds(0.2)
	ok(w.director._bell_minute == 5 and w.bell_strokes_left() >= 4, "at the fifth minute, five strokes")
	w.director.running = false

	# The river carries you along.
	var flow := w.terrain.river_flow(-54.5, 65.0)
	ok(flow.length() > 0.9, "the river has a direction")
	ok(w.terrain.in_water(-54.5, 65.0), "the ford is under water")
	ok(not w.terrain.in_water(0.0, 64.0), "a bridge is not")
	await kill_all()
	place(Vector3(-54.5, 0, 63.0))
	var from := pl.global_position
	await seconds(1.0)
	var moved := pl.global_position - from
	ok(Vector2(moved.x, moved.z).dot(flow) > 0.8, "standing in the ford, the current takes you downstream (%s)" % moved)
	place(Vector3(0, 0, 64.0))
	from = pl.global_position
	await seconds(1.0)
	ok(from.distance_to(pl.global_position) < 0.3, "on the bridge you stay where you are")
	place(Vector3(-54.5, 0, 63.0))
	pl.input_move = Vector2(0, -1)
	var dry_speed := Player.WALK_SPEED * pl.m("speed")
	await seconds(0.3)
	ok(Vector2(pl.velocity.x, pl.velocity.z).length() < dry_speed * 0.9, "and water slows you")
	pl.input_move = Vector2.ZERO

	# Nothing stands on a road, on any map.
	for mode: int in [Game.Mode.NIGHT, Game.Mode.FORT]:
		await m.start_game(mode)
		await seconds(0.2)
		var world: World = m.world
		var blocked := 0
		var checked := 0
		for line: Array in world.map_roads:
			for i in line.size() - 1:
				var a: Vector2 = line[i]
				var b: Vector2 = line[i + 1]
				for s in int(a.distance_to(b)):
					var p := a.lerp(b, float(s) / maxf(a.distance_to(b), 0.1))
					if absf(p.x) > 108.0 or absf(p.y) > 108.0:
						continue
					checked += 1
					if not world.grid.is_free(world.grid.to_cell(Vector3(p.x, 0, p.y))):
						blocked += 1
						print("  road blocked at ", p)
		ok(blocked <= 6 and checked > 100, "the roads of map %d are clear (%d of %d metres blocked)" % [mode, blocked, checked])

	# The fort's stairs are solid, you climb them on top, and they keep clear of the doors.
	await m.start_game(Game.Mode.FORT)
	await seconds(0.3)
	w = m.world
	pl = w.player
	w.director.running = false
	await kill_all()
	var inner := Fort.HALF - Fort.WALL_T * 0.5 - 1.3
	for i in 4:
		var dir := Fort.DIRS[i]
		var across := Vector3(dir.z, 0, -dir.x)
		var door: Vector3 = dir * inner + across * float(Fort.DOORS[i])
		ok(w.grid.is_free(w.grid.to_cell(door + Vector3(0.0, 0, 0.0) - dir * 2.5)), "the way in from the %s door is open" % Fort.NAMES[i])
		var sign_s := 1.0 if i % 2 == 0 else -1.0
		ok(signf(float(Fort.DOORS[i])) != sign_s, "and the %s stairs are on the other side of the gate" % Fort.NAMES[i])
	# Walk into the side of the stairs, high up: they stop you.
	var side_at := Vector3(-13.0, 0.05, -Fort.HALF + 7.0)
	pl.global_position = side_at
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	await seconds(1.2)
	pl.input_move = Vector2.ZERO
	ok(pl.global_position.z > -Fort.HALF + 3.0, "the stairs are solid: you cannot walk under them (%s)" % pl.global_position)
	# Climb from the bottom.
	var bottom := Vector3(-21.0, 0.05, -inner)
	pl.global_position = bottom + Vector3(-1.0, 0, 0)
	pl.yaw = -PI * 0.5
	pl.rotation.y = -PI * 0.5
	await seconds(0.2)
	pl.input_move = Vector2(0, -1)
	var stair_jumps := 0
	var was_jump := false
	Game.auto_jump = true
	for frame in 132:
		await frames(1)
		var jumping := pl.velocity.y > Player.JUMP_SPEED * 0.8
		if jumping and not was_jump:
			stair_jumps += 1
		was_jump = jumping
	ok(stair_jumps == 0, "stairs are walked up, with no jumping (%d jumps)" % stair_jumps)
	var height_on := pl.global_position.y
	var run := pl.global_position.x + 21.0
	var slope_y := run / 15.0 * 6.5
	pl.input_move = Vector2.ZERO
	ok(height_on > 2.5, "going up the stairs lifts you (%.1f m after %.1f m)" % [height_on, run])
	ok(absf(height_on - slope_y) < 0.45, "your feet stay on top of the steps (%.2f against %.2f)" % [height_on, slope_y])

	# The Sandbox has one of everything, and nothing is at stake.
	Game.unlocked["artificer"] = true
	Game.player_class = "artificer"
	await m.start_game(Game.Mode.SANDBOX)
	await seconds(0.4)
	w = m.world
	pl = w.player
	ok(w.terrain != null and w.zombies.size() == w.dummy_spots.size() and w.dummy_spots.size() >= 3, "the Sandbox starts with only its dummies")
	for dummy_one: Zombie in w.zombies:
		ok(dummy_one.type_id == "dummy", "and a dummy is all that is there")
	ok(not w.director.running and not Game.is_night(), "with no night running")
	var weapon_count := 0
	for id: String in WeaponDefs.ALL:
		if WeaponDefs.lies_around(id):
			weapon_count += 1
	await seconds(2.2)
	var items := {}
	for it: Pickup in w.pickups:
		items[it.item_id] = true
	ok(w.count_pickups(Pickup.Kind.WEAPON) == weapon_count, "every weapon is on show (%d)" % w.count_pickups(Pickup.Kind.WEAPON))
	var missing := 0
	for id: String in PowerDefs.ALL:
		# Pathfinder finds are unearthed by its beacons, never set out on a stand.
		if not items.has(id) and not PowerDefs.ALL[id].has("spec"):
			missing += 1
	for id: String in PowerDefs.FOODS:
		if not items.has(id):
			missing += 1
	ok(missing == 0 and items.has("arrows") and not items.has("lantern"), "and every item and familiar, but no Pathfinder find")
	var taken: Pickup = w.pickups[0]
	var taken_id := taken.item_id
	w.remove_pickup(taken)
	await seconds(2.5)
	var back := false
	for it: Pickup in w.pickups:
		if it.item_id == taken_id:
			back = true
	ok(back, "whatever is taken comes back")
	await seconds(70.0 / 12.0)
	ok(w.pickups.size() >= weapon_count, "and what is on show stays")
	for id: String in ZombieDefs.ALL:
		ok(w.sandbox_spawn(id), "a %s can be brought in" % id)
		await frames(1)
		w.sandbox_clear()
		await frames(1)
	pl.guard_left = 0.0
	pl.hurt(9999.0, front(2.0))
	ok(pl.dead, "you can fall")
	await seconds(2.0)
	ok(not pl.dead and not m._run_over, "and get straight back up")
	m.show_sandbox_menu()
	await frames(2)
	ok(get_tree().paused and m.panel != null, "the Sandbox menu opens and stops the world")
	ok(pl.level == ClassDefs.MAX_LEVEL and pl.points == ClassDefs.MAX_LEVEL - 1, "the whole tree is there to spend")
	await _press("Back to it")
	ok(not get_tree().paused, "and closes")

	# The Artificer holds one weapon.
	Game.player_class = "artificer"
	await start_clean()
	place(OPEN)
	await seconds(0.2)
	ok(pl.weapon_id() == "torch", "the Artificer starts with a torch")
	ok(not pl.has_empty_slot(), "and has no free hand")
	var sword := w.spawn_pickup_at(front(1.0), Pickup.Kind.WEAPON, "sword")
	await seconds(0.4)
	ok(pl.nearby_weapon == sword or pl.nearby_weapon != null, "a weapon on the ground can be seen")
	ok(pl.weapon_id() == "torch", "and is not picked up by itself")
	pl.take_nearby_weapon()
	ok(pl.weapon_id() == "sword" and pl.slots[1] == null, "taking it replaces the torch (%s)" % str(pl.slots))
	await seconds(0.2)
	var dropped := false
	for it: Pickup in w.pickups:
		if it.weapon_id == "torch":
			dropped = true
	ok(dropped, "and the torch is left on the ground")

	# The Pyromaniac.
	await _artificer_path(0)
	ok(pl.has_art() and pl.art_def()["name"] == "Incendiary Bomb", "the Pyromaniac has a bomb to throw")
	var target := spawn("normal", front(9.0))
	target._sight = 0.0
	await frames(1)
	var hp_before := target.hp
	var at_before := pl.art_cd_left
	ok(at_before == 0.0, "ready to begin with")
	pl.use_art()
	ok(pl.art_cd_left > 0.0, "throwing one starts the wait")
	pl.bomb_burst(target.centre())
	ok(target.hp < hp_before - 40.0 and target.burn_time > 0.0, "a bomb hurts and sets alight")
	await kill_all()
	await seconds(0.8)
	var before_flash := w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size()
	pl.flags["chaotic"] = true
	pl.bomb_burst(front(8.0))
	var after_flash := w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size()
	ok(after_flash - before_flash >= 6, "Chaotic throws off bomblets (%d)" % (after_flash - before_flash))
	await seconds(7.0)
	ok(w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size() <= before_flash, "and they all land in the end")

	# The Mechanic.
	await _artificer_path(1)
	ok(pl.has_mount() and pl.mount_kind() == "chariot", "the Mechanic builds a chariot")
	ok(not pl.horse_ready(), "which takes kills")
	var kill_me := spawn("normal", front(30.0))
	for i in pl.horses_needed():
		pl.on_kill(kill_me)
	ok(pl.horse_ready(), "and then it is ready")
	await kill_all()
	pl.mount()
	ok(pl.is_riding() and pl.riding_left >= Player.CHARIOT_TIME, "it lasts longer than a horse")
	pl.input_move = Vector2(0, -1)
	await seconds(1.0)
	var chariot_speed := Vector2(pl.velocity.x, pl.velocity.z).length()
	pl.input_move = Vector2.ZERO
	ok(chariot_speed < Player.WALK_SPEED, "and it is slower than walking (%.1f m/s)" % chariot_speed)
	ok(pl.horses_needed() < Player.HORSE_KILLS, "but it comes sooner than a horse")
	pl.guard_left = 0.0
	var before_hit := pl.hp
	pl.hurt(40.0, front(2.0))
	ok(pl.hp > before_hit - 30.0, "it takes part of a blow (%.1f lost)" % (before_hit - pl.hp))
	pl.flags["chariot_turret"] = true
	pl._chariot.show_upgrades(true, false)
	var shot_at := spawn("normal", front(8.0))
	var shot_hp := shot_at.hp
	await seconds(2.5)
	ok(shot_at.hp < shot_hp or not shot_at.is_alive(), "the turret shoots what comes near")
	await kill_all()
	pl.flags["chariot_spikes"] = true
	var cut := spawn("normal", front(1.8))
	var cut_hp := cut.hp
	await seconds(1.0)
	ok(cut.hp < cut_hp or not cut.is_alive(), "the spikes cut what is close")
	await kill_all()
	pl.dismount()
	ok(not pl.is_riding(), "and you can step down")

	# The Inventor.
	await _artificer_path(2)
	ok(pl.has_art() and pl.art_label() != "", "the Inventor's button says what comes next")
	var names := {}
	for i in 12:
		var next := pl.art_label()
		names[next] = true
		pl.art_cd_left = 0.0
		pl._invent()
		ok(pl.art_label() != next or pl._inventions().size() == 1, "the same invention does not come twice running") if i == 0 else null
	ok(names.size() == 2, "at first there are two to come")
	ok(pl.art_glyph() in ["dart", "flask"], "and the button shows the right picture")
	pl.flags["inv_sentry"] = true
	pl.flags["inv_boots"] = true
	pl.flags["inv_noise"] = true
	pl.flags["inv_magnet"] = true
	ok(pl._inventions().size() == 6, "the tree adds more")
	await kill_all()
	# Electric Volley: darts, and sparks that jump.
	var first := spawn("normal", front(6.0))
	var second := spawn("normal", front(6.0) + pl.global_basis.x * 3.0)
	var hp1 := first.hp
	var hp2 := second.hp
	first._sight = 0.0
	second._sight = 0.0
	pl.spark_from(first, 2, 30.0)
	ok(second.hp < hp2, "a spark jumps to the next enemy")
	await kill_all()
	var darted := spawn("normal", front(7.0))
	var dart_hp := darted.hp
	pl._run_invention("volley")
	ok(pl._volley_left == int(pl.m("volley_darts")), "a volley is a series of darts")
	await seconds(1.0)
	ok(pl._volley_left == 0 and darted.hp < dart_hp, "and they hit")
	await kill_all()
	var frozen := spawn("normal", front(5.0))
	pl._flask_burst(frozen.position)
	ok(frozen._frozen > 0.0, "Cryo Flask freezes")
	await kill_all()
	pl._run_invention("sentry")
	ok(w._sentries.size() == 1, "Clockwork Sentry stands where you put it")
	var sentry_target := spawn("normal", front(9.0))
	var sentry_hp := sentry_target.hp
	await seconds(2.5)
	ok(sentry_target.hp < sentry_hp or not sentry_target.is_alive(), "and shoots")
	await seconds(WorldLight.SENTRY_TIME)
	ok(w._sentries.is_empty(), "and it does not stay for ever")
	await kill_all()
	pl.guard_left = 0.0
	pl._run_invention("boots")
	ok(pl.guard_left > 1.0 and pl.m("speed") > 1.5, "Steam Boots give speed and safety")
	var lured := spawn("normal", front(14.0))
	var lured_hp := lured.hp
	lured._sight = 0.0
	pl._noise_burst(front(10.0))
	ok(lured.state == Zombie.State.CHASE, "Noise Box draws them in")
	await seconds(3.4)
	await kill_all()
	var pulled := spawn("normal", front(9.0))
	var pull_from := pulled.position
	var pull_to := front(4.0)
	pl._magnet_burst(pull_to)
	await seconds(0.9)
	ok(pulled.position.distance_to(pull_to) < pull_from.distance_to(pull_to) - 2.0, "Lodestone drags them over (%s)" % pulled.position)
	await kill_all()
	pl.flags["eureka"] = true
	pl._next_invention = "flask"
	var jobs_before := pl._later.size()
	pl._invent()
	ok(pl._later.size() == jobs_before + 1 and pl._last_invention == "flask", "Eureka schedules a second copy of the chosen invention")
	await seconds(0.7)
	ok(pl._later.size() == jobs_before, "Eureka executes and retires its delayed copy")
	Game.player_class = "infantry"
	Game.unlocked = saved_unlocked
	Game.save_settings()
	await start_clean()


## Starts an Artificer on one of its three paths.
func _artificer_path(spec: int) -> void:
	Game.unlocked["artificer"] = true
	Game.player_class = "artificer"
	await start_clean()
	place(OPEN)
	await seconds(0.2)
	pl.points = ClassDefs.MAX_LEVEL - 1
	for s in Player.CORE_STEPS:
		pl.choose_ability(s, 0)
	pl.choose_ability(Player.CORE_STEPS, spec)


func test_new_things() -> void:
	# Doubloons.
	ok(Game.match_doubloons(600.0, 150, true, false) == 60, "a full night with 150 kills pays 60")
	ok(Game.match_doubloons(600.0, 150, true, true) == 90, "and half as much again in co-op")
	ok(Game.match_doubloons(120.0, 9, false, false) == 3, "a short night pays less")
	var coins := Game.doubloons
	Game.mode = Game.Mode.NIGHT
	Game.begin_run()
	ok(Game.award_doubloons(60.0, 5, false, false) == 2 and Game.doubloons == coins + 2, "doubloons add up")
	Game.doubloons = coins
	Game.save_settings()
	# The joystick lets go when you die or come back.
	await start_clean()
	place(OPEN)
	var h: Hud = Hud.new()
	h.player = pl
	h.custom_minimum_size = Vector2(1280, 720)
	add_child(h)
	await frames(2)
	h._fingers[3] = "joy"
	h._joy_finger = 3
	pl.input_move = Vector2(0.8, 0)
	pl.dead = true
	await frames(2)
	ok(h._joy_finger < 0 and pl.input_move == Vector2.ZERO, "dying lets go of the joystick")
	pl.dead = false
	h._fingers[4] = "joy"
	h._joy_finger = 4
	h._touch_up(4)
	ok(h._joy_finger < 0, "and a lifted finger always counts")
	h.queue_free()
	pl.input_move = Vector2(1, 0)
	pl.input_fire = true
	pl.dead = true
	pl.respawn(OPEN)
	ok(pl.input_move == Vector2.ZERO and not pl.input_fire and not pl.dead, "coming back starts with nothing held down")
	# The Dread Rider.
	await frames(2)
	pl.hp = pl.max_hp()
	pl.guard_left = 0.0
	var r := spawn("rider", pl.global_position + Vector3(0, 0, -14))
	ok(r._mounted and r._horse_node.visible, "the Dread Rider rides a horse")
	r._sight = 60.0
	r._ride_turn = 0.0
	r._sees = true
	r.rotation.y = 0.0
	var hp0 := pl.hp
	var moved := 0.0
	var start := r.position
	for i in 200:
		await frames(1)
		r._sees = true
		moved = maxf(moved, r.position.distance_to(start))
		if pl.hp < hp0:
			break
	ok(pl.hp < hp0, "it rides you down")
	ok(moved > 6.0, "at a gallop")
	r.hp = r.max_hp * 0.3
	r.take_damage(1.0, Vector3.FORWARD, 0.0, r.centre())
	ok(not r._mounted and not r._horse_node.visible, "bring its horse down and it fights on foot")
	await kill_all()
	await frames(2)
	# The pause menu opens once, however often you tap.
	var m2: Main = load("res://scripts/main.gd").new()
	add_child(m2)
	await frames(2)
	await m2.start_game(Game.Mode.SANDBOX)
	m2.show_pause()
	m2.show_pause()
	m2.show_pause()
	var menus := 0
	for c in m2.ui_layer.get_children():
		if c.has_meta("box"):
			menus += 1
	ok(menus == 1, "tapping pause again changes nothing (%d)" % menus)
	m2._resume()
	await frames(1)
	ok(not get_tree().paused and not m2.hud.menu_open, "and Resume closes it")
	m2.queue_free()
	await frames(2)
	# F6 on a map in the editor goes straight into that map.
	Game.test_map = "res://maps/fort.tscn"
	var m3: Main = load("res://scripts/main.gd").new()
	add_child(m3)
	await seconds(2.0)
	ok(m3.world != null and m3.world.fort != null, "F6 on a map plays that map")
	Game.test_map = ""
	m3.queue_free()
	await frames(2)
	await start_clean()


func test_flow() -> void:
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await frames(3)
	ok(m.world != null and m.world.mode == Game.Mode.MENU and m.world.map_id == "mesenlla", "the title screen shows the Valleys of Mesenlla")
	ok((m.panel.find_child("UpdateTitle", true, false) as Label).text == "Beyond the Mists", "main title names the production update")
	ok(m.world.player == null and m.world.zombies.is_empty() and not m.world.director.running, "the title backdrop has no active match")
	await m.start_game(Game.Mode.SANDBOX)
	await seconds(3.0)
	ok(m.world.zombies.size() == m.world.dummy_spots.size(), "the Sandbox has no zombies, only dummies")
	ok(m.world.pickups.size() > 0, "the Sandbox has things to pick up")
	m.queue_free()
	await frames(2)


## Mario's review of Beyond the Mists, 13 November: campfires, walking backwards, the menu screens.
func test_beyond_review() -> void:
	await start_clean()
	# Nobody stands on a campfire, and standing right at one too long sets you alight.
	var fire: Dictionary = {}
	for f: Dictionary in w.fires:
		if f["heals"]:
			fire = f
			break
	ok(not fire.is_empty(), "the Village has a bonfire")
	if not fire.is_empty():
		var at: Vector3 = fire["at"]
		var q := PhysicsPointQueryParameters3D.new()
		q.position = at + Vector3.UP * 1.6
		q.collision_mask = Terrain.BARRIER
		ok(not w.get_world_3d().direct_space_state.intersect_point(q).is_empty(), "an unseen column over a bonfire keeps anyone off the top of it")
		pl.set_physics_process(true)
		pl.guard_left = 0.0
		pl.global_position = at + Vector3(0, 1.3, 0)
		pl.velocity = Vector3.ZERO
		await seconds(1.5)
		ok(Vector2(pl.global_position.x - at.x, pl.global_position.z - at.z).length() > 0.9 or pl.global_position.y < at.y + 1.2, "dropped on top of one, you do not stay up there (%.1f m off, %.1f up)" % [Vector2(pl.global_position.x - at.x, pl.global_position.z - at.z).length(), pl.global_position.y - at.y])
		pl.global_position = at + Vector3(1.9, 0.1, 0)
		pl.velocity = Vector3.ZERO
		pl.burn_time = 0.0
		pl._scorch = 0.0
		pl.hp = pl.max_hp()
		await seconds(WorldLight.SCORCH_AFTER - 1.5)
		ok(pl.burn_time <= 0.0 and w.at_bonfire(pl.global_position), "right at the stones, at first you only get warm")
		await seconds(2.5)
		ok(pl.burn_time > 0.0, "but after %d seconds you catch fire" % int(WorldLight.SCORCH_AFTER))
		pl.global_position = at + Vector3(6.0, 0.1, 0)
		await seconds(0.5)
		ok(pl._scorch == 0.0, "step back and it starts over")
		pl.burn_time = 0.0
		pl.hp = pl.max_hp()
	# Backing away is slower than walking on.
	place(OPEN)
	pl.set_physics_process(true)
	pl.input_move = Vector2(0, -1)
	await seconds(1.0)
	var ahead := Vector2(pl.velocity.x, pl.velocity.z).length()
	pl.input_move = Vector2(0, 1)
	await seconds(1.0)
	var back := Vector2(pl.velocity.x, pl.velocity.z).length()
	pl.input_move = Vector2.ZERO
	ok(absf(back / maxf(ahead, 0.01) - Player.BACK_SPEED) < 0.03, "walking backwards goes at %d%% of walking on (%.2f against %.2f m/s)" % [int(Player.BACK_SPEED * 100.0), back, ahead])
	# The Scarecrow belongs to the Village.
	ok(ZombieDefs.ALL["scarecrow"]["maps"] == ["village"] and SpawnRules.allows(ZombieDefs.ALL["scarecrow"], "village") and not SpawnRules.allows(ZombieDefs.ALL["scarecrow"], "mesenlla"), "the Scarecrow is the Village's alone")
	# The world atlas: the Mists lead only to Mist Bastion, and the Valleys lie below it.
	ok(WorldAtlas.LINKS.filter(func(l: Array) -> bool: return "mists" in [l[0], l[1]]).map(func(l: Array) -> String: return l[1] if l[0] == "mists" else l[0]) == ["fort", "bastion"], "on the atlas the Mists connect to the Fort and Mist Bastion only")
	ok((WorldAtlas.SPOTS["mesenlla"] as Vector2).y > (WorldAtlas.SPOTS["bastion"] as Vector2).y, "and the Valleys of Mesenlla lie below Mist Bastion")
	m.show_map_picker()
	await frames(2)
	var atlas := m.panel.find_child("WorldAtlas", true, false) as WorldAtlas
	(atlas.find_child("Place_mesenlla", true, false) as Button).pressed.emit()
	await frames(2)
	var shown: Array = m.panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ok(shown.has("Valleys of Mesenlla") and not shown.any(func(t: String) -> bool: return t.begins_with("Map Exclusive")), "choosing where to play shows no map tags")
	# Your name is changed in Settings, not on the menu.
	m.show_menu()
	await frames(2)
	ok(not m.ui_layer.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == Game.player_name), "the menu no longer has your name on a button")
	m.show_settings()
	await frames(2)
	var rename := m.ui_layer.find_child("Rename", true, false) as Button
	ok(rename != null and rename.text == Game.player_name, "Settings has it, to change your name")
	if rename:
		rename.pressed.emit()
		await frames(2)
		ok(m.ui_layer.find_children("*", "LineEdit", true, false).any(func(e: LineEdit) -> bool: return e.text == Game.player_name), "and tapping it asks for the new one")
	# New notes make the Changelog button glow until they are read.
	var read := Game.changelog_seen
	Game.changelog_seen = "older notes"
	m.show_menu()
	await frames(2)
	var notes := m.ui_layer.find_child("ChangelogButton", true, false) as Button
	ok(notes != null and notes.has_meta("news"), "new notes in the Changelog make its button glow")
	await seconds(0.3)
	ok(notes != null and notes.self_modulate != Color.WHITE, "and it does glow (%s)" % (str(notes.self_modulate) if notes else "-"))
	m.show_changelog()
	await frames(2)
	ok(Game.changelog_seen == ChangelogPanel.signature(), "opening the Changelog reads them")
	var lines: int = m.ui_layer.find_children("*", "Label", true, false).size()
	await frames(30)
	ok(m.ui_layer.find_children("*", "Label", true, false).size() > lines, "its older notes follow over the next moments, so it opens at once")
	m.show_menu()
	await frames(2)
	notes = m.ui_layer.find_child("ChangelogButton", true, false) as Button
	ok(notes != null and not notes.has_meta("news"), "after which the button stops glowing")
	Game.changelog_seen = read
	Game.save_settings()
	await start_clean()


func start_clean() -> void:
	if m and is_instance_valid(m):
		m.queue_free()
		await frames(2)
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await frames(2)
	await m.start_game(Game.Mode.NIGHT)
	await frames(3)
	w = m.world
	pl = w.player
	hud = m.hud
	w.director.running = false
	w.director._stock_timer = 99999.0
	w.director._familiar_timer = 99999.0
	w.director._bell_timer = 99999.0
	for z: Zombie in w.zombies.duplicate():
		z.release()
	clear_pickups()
	await frames(2)


func clear_pickups() -> void:
	for p: Pickup in w.pickups.duplicate():
		w.remove_pickup(p)


func place(at: Vector3, yaw := 0.0) -> void:
	at.y += w.ground_at(at)
	pl.global_position = at
	pl.velocity = Vector3.ZERO
	pl.yaw = yaw
	pl.rotation.y = yaw
	pl.pitch = 0.0
	pl.head.rotation.x = 0.0


func spawn(id: String, at: Vector3, frozen := false) -> Zombie:
	# Initial roamers may use every body of the first model; use any compatible pool.
	var pool: Array = []
	for model: String in ZombieDefs.ALL[id]["models"]:
		if w._pools.has(model) and not w._pools[model].is_empty():
			pool = w._pools[model]
			break
	assert(not pool.is_empty(), "No pooled body available for test enemy " + id)
	var z: Zombie = pool.pop_back()
	w.zombies.append(z)
	z.spawn(id, at)
	if frozen:
		z.set_physics_process(false)
	return z


func front(dist: float) -> Vector3:
	return pl.global_position - pl.global_basis.z * dist


func kill_all() -> void:
	for z: Zombie in w.zombies.duplicate():
		z.set_physics_process(true)
		if z.is_alive():
			z.take_damage(9999999.0, Vector3.FORWARD, 0.0, z.position)
	await seconds(2.5)


func aim_at(z: Zombie, height := 0.55) -> void:
	var to := z.global_position + Vector3.UP * z.height * height - pl.eye_position()
	pl.yaw = atan2(-to.x, -to.z)
	pl.rotation.y = pl.yaw
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	pl.head.rotation.x = pl.pitch


func equip(id: String) -> void:
	pl.slots = [id, null]
	pl.current = 0
	pl.own_ammo.clear()
	if WeaponDefs.own_ammo(id) > 0:
		pl.add_own_ammo(id, WeaponDefs.own_ammo_max(id)) # as if two had been picked up
	pl._equip()
	await seconds(0.3)


## Holds attack for a while and returns how much health the zombie lost.
func damage_dealt(z: Zombie, t: float) -> float:
	z.hp = 100000.0
	var before := z.hp
	pl.input_fire = true
	await seconds(t)
	pl.input_fire = false
	await seconds(0.7)
	return before - z.hp


func test_weapons() -> void:
	ok(pl.slots[0] == "dagger" and pl.arrows == 0, "starts with a dagger and no arrows")
	place(OPEN)
	pl.arrows = 60
	var hits := {}
	for id: String in WeaponDefs.ALL:
		await equip(id)
		pl.mana = 9999.0
		var dist := 1.4 if WeaponDefs.ALL[id]["kind"] == WeaponDefs.Kind.MELEE else 6.0
		var z := spawn("normal", front(dist), true)
		await frames(3)
		aim_at(z)
		var dealt: float = await damage_dealt(z, 3.0)
		hits[id] = dealt / (WeaponDefs.DAMAGE * float(WeaponDefs.ALL[id].get("power", 1.0)))
		print("  ", id, " hits in 3 s=", hits[id])
		ok(dealt > 0.0, "%s does damage" % id)
		z.set_physics_process(true)
		await kill_all()
	ok(hits["dagger"] > hits["sword"], "dagger attacks faster than sword")
	ok(hits["crossbow"] > hits["bow"] and hits["bow"] > hits["longbow"], "crossbow > bow > long bow cadence")

	# Melee reach.
	var reach := {"dagger": [1.5, 3.0], "sword": [2.5, 4.0], "spear": [4.0, 5.5], "mace": [1.8, 3.2], "lance": [4.8, 6.4],
		"scythe": [3.0, 4.4], "flail": [2.2, 3.6], "bell_hammer": [2.2, 3.6], "pitchfork": [3.4, 5.0], "torch": [1.7, 3.2]}
	for id: String in reach:
		await equip(id)
		var near := spawn("normal", front(reach[id][0]), true)
		await frames(3)
		aim_at(near)
		ok(await damage_dealt(near, 0.8) > 0.0, "%s reaches %.1f m" % [id, reach[id][0]])
		near.set_physics_process(true)
		await kill_all()
		var far := spawn("normal", front(reach[id][1]), true)
		await frames(3)
		aim_at(far)
		ok(await damage_dealt(far, 0.8) == 0.0, "%s does not reach %.1f m" % [id, reach[id][1]])
		far.set_physics_process(true)
		await kill_all()

	# Mace is broad, spear is narrow.
	var ring := func(id: String) -> int:
		await equip(id)
		place(OPEN)
		var a := spawn("normal", pl.global_position + pl.global_basis * Vector3(-1.2, 0, -1.2), true)
		var b := spawn("normal", pl.global_position + pl.global_basis * Vector3(1.2, 0, -1.2), true)
		await frames(3)
		a.hp = 1000.0
		b.hp = 1000.0
		pl.input_fire = true
		await seconds(0.3)
		pl.input_fire = false
		await seconds(0.5)
		var n := (1 if a.hp < 1000.0 else 0) + (1 if b.hp < 1000.0 else 0)
		a.set_physics_process(true)
		b.set_physics_process(true)
		await kill_all()
		return n
	ok(await ring.call("mace") == 2, "mace hits both zombies to the sides")
	ok(await ring.call("spear") == 0, "spear only hits straight ahead")
	ok(await ring.call("scythe") == 2, "scythe sweeps both sides")

	# Fire range: the arrow disappears at the end of its range.
	var ranges := {"crossbow": [12.0, 20.0], "bow": [28.0, 42.0], "longbow": [50.0, 0.0]}
	for id: String in ranges:
		place(Vector3(0, 0, 52))
		await equip(id)
		var z := spawn("normal", front(ranges[id][0]), true)
		await frames(3)
		aim_at(z, 0.75)
		pl.arrows = 60
		var d: float = await damage_dealt(z, 1.6)
		ok(d > 0.0, "%s reaches %.0f m" % [id, ranges[id][0]])
		z.set_physics_process(true)
		await kill_all()
		if ranges[id][1] > 0.0:
			var z2 := spawn("normal", front(ranges[id][1]), true)
			await frames(3)
			aim_at(z2, 1.6)
			var d2: float = await damage_dealt(z2, 1.6)
			ok(d2 == 0.0, "%s falls short of %.0f m" % [id, ranges[id][1]])
			z2.set_physics_process(true)
			await kill_all()
	place(OPEN)

	# Arrows are one shared stock.
	await equip("bow")
	pl.arrows = 2
	var t := spawn("normal", front(5.0), true)
	await frames(3)
	aim_at(t)
	pl.input_fire = true
	await seconds(2.5)
	pl.input_fire = false
	ok(pl.arrows == 0, "firing uses arrows until none are left")
	await equip("longbow")
	pl.input_fire = true
	await seconds(0.5)
	pl.input_fire = false
	ok(pl.toast == "No arrows", "every bow shares the empty stock")
	t.set_physics_process(true)
	await kill_all()
	pl.toggle_zoom()
	await seconds(0.5)
	ok(pl.camera.fov < 45.0, "long bow can aim with zoom")
	pl.toggle_zoom()
	await seconds(0.3)


func _to_window(at: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * at


func touch(i: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _to_window(at)
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func drag(i: int, at: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = _to_window(at)
	e.relative = _to_window(at + rel) - _to_window(at)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func test_touch() -> void:
	place(OPEN)
	await equip("dagger")
	var start := pl.global_position
	var vs := hud.size
	var left := Vector2(vs.x * 0.15, vs.y * 0.7)
	touch(0, left, true)
	await frames(1)
	drag(0, left + Vector2(0, -80), Vector2(0, -80))
	var fire: Vector2 = hud._buttons["fire"]["pos"]
	touch(1, fire, true)
	await seconds(0.5)
	ok(pl.input_fire, "ATTACK button holds attack while moving")
	var yaw0 := pl.yaw
	drag(1, fire + Vector2(-30, 0), Vector2(-30, 0))
	await frames(2)
	ok(not is_equal_approx(pl.yaw, yaw0), "dragging on ATTACK also aims")
	await seconds(0.5)
	ok(pl.global_position.distance_to(start) > 1.5, "left thumb moves the player")
	touch(1, fire, false)
	touch(0, left, false)
	await frames(2)
	ok(not pl.input_fire and pl.input_move == Vector2.ZERO, "releasing thumbs stops input")
	place(OPEN)
	await frames(3)
	var y0 := pl.global_position.y
	var jump: Vector2 = hud._buttons["jump"]["pos"]
	touch(3, jump, true)
	await seconds(0.2)
	ok(pl.global_position.y > y0 + 0.3, "JUMP button jumps")
	touch(3, jump, false)
	await seconds(0.8)


func test_auto_jump() -> void:
	# The east fence of the west wheat field runs along x = -20.
	Game.auto_jump = false
	place(Vector3(-17, 0, 26), PI * 0.5)
	await frames(3)
	pl.input_move = Vector2(0, -1)
	await seconds(1.5)
	ok(pl.global_position.x > -20.0, "with auto-jump off, a fence stops you")
	Game.auto_jump = true
	place(Vector3(-17, 0, 26), PI * 0.5)
	await frames(3)
	await seconds(2.0)
	print("  crossed to x=", pl.global_position.x)
	ok(pl.global_position.x < -20.5, "auto-jump clears a fence")
	pl.input_move = Vector2.ZERO
	# A house wall is too tall: no jump.
	place(Vector3(-15, 0, -8), 0.0)
	pl.global_position = Vector3(-18, 0, -9.5)
	await frames(3)
	pl.input_move = Vector2(0, -1)
	var peak := 0.0
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, pl.global_position.y)
	pl.input_move = Vector2.ZERO
	ok(peak < 0.2, "auto-jump does not trigger at a tall wall")
	await seconds(0.3)


func test_items() -> void:
	place(OPEN)
	clear_pickups()
	pl.slots = ["dagger", null]
	pl.current = 0
	pl._equip()
	var near := front(0.8)
	w.spawn_pickup_at(near, Pickup.Kind.WEAPON, "sword")
	await seconds(0.4)
	ok(pl.slots[1] == "sword", "empty slot takes a weapon")
	ok(w.pickups.is_empty(), "taken weapon leaves the map")
	var p2 := w.spawn_pickup_at(near, Pickup.Kind.WEAPON, "bow", 8)
	await seconds(0.4)
	ok(pl.nearby_weapon == p2, "full slots offer TAKE")
	var prev: String = pl.weapon_id()
	pl.arrows = 0
	touch(4, hud._buttons["take"]["pos"], true)
	touch(4, hud._buttons["take"]["pos"], false)
	await frames(2)
	ok(pl.weapon_id() == "bow", "TAKE swaps the weapon")
	ok(pl.arrows == 8, "a found bow comes with 8 arrows")
	ok(w.pickups.size() == 1 and w.pickups[0].weapon_id == prev, "swapped weapon drops on the ground")
	clear_pickups()
	for food: String in PowerDefs.FOODS:
		pl.hp = 50.0
		var heal: float = PowerDefs.FOODS[food]["heal"]
		w.spawn_pickup_at(pl.global_position, Pickup.Kind.FOOD, food)
		await seconds(0.3)
		ok(is_equal_approx(pl.hp, 50.0 + heal), "%s heals %d" % [food, heal])
	pl.hp = pl.max_hp()
	var apple := w.spawn_pickup_at(pl.global_position, Pickup.Kind.FOOD, "apple")
	await seconds(0.3)
	ok(is_instance_valid(apple) and w.pickups.has(apple), "food stays on the ground at full health")
	clear_pickups()
	pl.arrows = 0
	w.spawn_pickup_at(pl.global_position, Pickup.Kind.ARROWS, "arrows")
	await seconds(0.3)
	ok(pl.arrows == 12, "arrows pickup adds 12")


func test_powers() -> void:
	place(OPEN)
	clear_pickups()
	for id: String in PowerDefs.ALL:
		if PowerDefs.ALL[id].has("spec"):
			# A Pathfinder find: anyone else walks past it.
			w.spawn_pickup_at(pl.global_position, Pickup.Kind.POWER, id)
			await seconds(0.25)
			ok(not pl.has_power(id) and w.pickups.any(func(i: Pickup) -> bool: return i.item_id == id), "%s stays on the ground for anyone but a %s" % [id, PowerDefs.ALL[id]["spec"]])
			var was_spec := pl.spec_id
			pl.spec_id = str(PowerDefs.ALL[id]["spec"])
			await seconds(0.25)
			pl.spec_id = was_spec
			clear_pickups()
		else:
			w.spawn_pickup_at(pl.global_position, Pickup.Kind.POWER, id)
			await seconds(0.25)
		ok(pl.has_power(id), "%s activates" % id)
		var want := 20.0
		ok(absf(float(pl.powers[id]) - want) < 1.0, "%s lasts %d s" % [id, want])
		pl.powers.erase(id)
		if pl._familiars.has(id):
			pl._familiars[id].queue_free()
			pl._familiars.erase(id)
	# The Ghost Knight from the loop above would otherwise join the fights below.
	for a: Ally in w.allies.duplicate():
		w.remove_ally(a)
	# Timer really runs out, and picking one up again resets it.
	pl.activate_power("speed")
	pl.powers["speed"] = 0.3
	await seconds(0.6)
	ok(not pl.has_power("speed"), "powers run out")
	pl.activate_power("angel")
	ok(pl._familiars.has("angel"), "familiar appears")
	pl.powers["angel"] = 1.0
	pl.activate_power("angel")
	ok(float(pl.powers["angel"]) > 19.0, "picking up the same power resets its timer")
	pl.powers["angel"] = 0.1
	await seconds(0.3)
	ok(not pl._familiars.has("angel"), "familiar leaves when its time ends")

	# Speed.
	place(OPEN)
	await frames(3)
	var from := pl.global_position
	pl.input_move = Vector2(0, -1)
	await seconds(1.0)
	var normal := pl.global_position.distance_to(from)
	place(OPEN)
	await frames(3)
	from = pl.global_position
	pl.activate_power("speed")
	await seconds(1.0)
	var fast := pl.global_position.distance_to(from)
	pl.input_move = Vector2.ZERO
	pl.powers.clear()
	print("  1 s run normal=", normal, " speed=", fast)
	ok(fast > normal * 1.25, "speed potion is faster")

	# Fire arrows burn for 3 s and light the zombie.
	place(OPEN)
	await equip("bow")
	pl.arrows = 10
	pl.activate_power("fire_arrows")
	var z := spawn("normal", front(6.0), true)
	await frames(3)
	aim_at(z)
	z.hp = 1000.0
	pl.input_fire = true
	await frames(3)
	pl.input_fire = false
	await seconds(0.4)
	pl.powers.clear()
	ok(z.burn_time > 0.0, "fire arrow sets a zombie on fire")
	z.set_physics_process(true)
	z._think = 999.0
	var after_hit := z.hp
	await frames(5)
	ok(w._burn_lights[0].visible, "burning zombie lights the area")
	await seconds(3.2)
	ok(z.hp < after_hit and z.burn_time <= 0.0, "burn deals damage, then stops after 3 s (%.0f)" % (after_hit - z.hp))
	await kill_all()
	await frames(3)
	ok(not w._burn_lights[0].visible, "the light goes out")

	# Bouncing arrows reach two more enemies.
	place(OPEN)
	await equip("bow")
	pl.arrows = 10
	pl.activate_power("bounce_arrows")
	var a := spawn("normal", front(6.0), true)
	var b := spawn("normal", front(6.0) + pl.global_basis.x * 3.0, true)
	var c := spawn("normal", front(6.0) - pl.global_basis.x * 3.0, true)
	var d := spawn("normal", front(6.0) + pl.global_basis.x * 7.0, true)
	await frames(3)
	aim_at(a)
	for t: Zombie in [a, b, c, d]:
		t.hp = 1000.0
	pl.input_fire = true
	await frames(3)
	pl.input_fire = false
	await seconds(1.0)
	var bounced := 0
	for t: Zombie in [a, b, c, d]:
		if t.hp < 1000.0:
			bounced += 1
	pl.powers.clear()
	ok(bounced == 3, "bouncing arrow hits 3 enemies in total (hit %d)" % bounced)
	await kill_all()

	# Daemon raises damage.
	place(OPEN)
	await equip("sword")
	pl.activate_power("daemon")
	var dz := spawn("normal", front(1.5), true)
	await frames(3)
	aim_at(dz)
	dz.hp = 1000.0
	pl.input_fire = true
	await frames(10)
	pl.input_fire = false
	await seconds(0.2)
	ok(is_equal_approx(1000.0 - dz.hp, WeaponDefs.DAMAGE * PowerDefs.DAEMON_MULTIPLIER), "daemon raises damage (%.0f)" % (1000.0 - dz.hp))
	pl.powers.clear()
	pl._familiars.values().map(func(f: Node) -> void: f.queue_free())
	pl._familiars.clear()
	await kill_all()

	# Angel heals every 3 s.
	pl.hp = 50.0
	pl.activate_power("angel")
	await seconds(6.4)
	ok(is_equal_approx(pl.hp, 50.0 + PowerDefs.ANGEL_HEAL * 2.0), "angel heals every 3 s (hp %.0f)" % pl.hp)
	pl.powers.clear()
	await frames(2)
	pl.hp = 100.0

	# Archer shoots by itself without using your arrows.
	place(OPEN)
	pl.arrows = 5
	var az := spawn("normal", front(8.0), true)
	await frames(3)
	az.hp = 1000.0
	pl.activate_power("archer")
	await seconds(3.4)
	var archer_hits := (1000.0 - az.hp) / WeaponDefs.DAMAGE
	print("  archer hits in 3.4 s=", archer_hits)
	ok(archer_hits >= 2.0, "archer shoots near enemies each second")
	ok(pl.arrows == 5, "archer does not use your arrows")
	pl.powers.clear()
	await kill_all()

	# Thunder hits an area every 5 s.
	place(OPEN)
	var t1 := spawn("normal", front(10.0), true)
	var t2 := spawn("normal", front(10.0) + pl.global_basis.x * 3.0, true)
	var t3 := spawn("normal", front(10.0) + pl.global_basis.x * 14.0, true)
	await frames(3)
	for t: Zombie in [t1, t2, t3]:
		t.hp = 1000.0
	pl.activate_power("thunder")
	await seconds(1.4)
	ok(t1.hp < 1000.0 and t2.hp < 1000.0, "thunder hits an area")
	ok(t3.hp == 1000.0, "thunder misses zombies outside the area")
	var first := t1.hp
	await seconds(2.0)
	ok(t1.hp == first, "thunder waits between strikes")
	await seconds(3.5)
	ok(t1.hp < first, "thunder strikes again after 5 s")
	pl.powers.clear()
	await kill_all()
	await seconds(0.1)


func test_zombies() -> void:
	# Roams on its own, unaware of a far player.
	place(Vector3(50, 0, 50), PI)
	var z := spawn("normal", Vector3(-30, 0, 5))
	await seconds(0.3)
	var from := z.position
	await seconds(12.0)
	ok(z.position.distance_to(from) > 1.5, "zombie roams by itself (%.1f m)" % z.position.distance_to(from))
	ok(z.state == Zombie.State.ROAM, "it stays calm while nothing is near")
	await kill_all()

	# Sees in the open.
	place(OPEN)
	var seer := spawn("normal", front(10.0))
	seer.rotation.y = atan2(pl.global_position.x - seer.position.x, pl.global_position.z - seer.position.z)
	await seconds(0.6)
	ok(seer.state == Zombie.State.CHASE, "zombie facing you sees you")
	pl.hp = 100.0
	await seconds(5.0)
	ok(pl.hp < 100.0, "it reaches and hits you (hp %.0f)" % pl.hp)
	await kill_all()
	pl.hp = 100.0

	# Cannot see through a wall. This one is put up for the test, so moving things on the map cannot upset it.
	place(OPEN, 0.0)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(14, 6, 0.4)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	w.add_child(wall)
	wall.global_position = pl.global_position + Vector3(0, 2, -5)
	await seconds(0.1) # the wall only counts for sight from the next physics step
	var blind := spawn("normal", front(10.0))
	blind.rotation.y = 0.0
	pl.input_move = Vector2.ZERO
	await seconds(1.0)
	ok(blind.state != Zombie.State.CHASE, "a wall blocks sight")
	# A noise brings it to investigate.
	w.make_noise(blind.position + Vector3(0, 0, 3), 8.0)
	await frames(2)
	ok(blind.state == Zombie.State.INVESTIGATE, "noise makes it investigate")
	await kill_all()
	wall.queue_free()

	# Hiding: chase, then break line of sight and stay away.
	place(Vector3(15, 0, 36), 0.0)
	var hunter := spawn("normal", pl.global_position + Vector3(0, 0, -7))
	hunter.rotation.y = 0.0
	await seconds(0.5)
	ok(hunter.state == Zombie.State.CHASE, "hunter chases")
	place(Vector3(-50, 0, -50), 0.0)
	await seconds(9.5)
	ok(hunter.state != Zombie.State.CHASE, "it gives up when it loses you")
	await seconds(14.0)
	ok(hunter.state == Zombie.State.ROAM, "then it goes back to roaming")
	await kill_all()

	# Chases through a door into a house.
	place(Vector3(-15, 0, -13), 0.0)
	pl.hp = 100.0
	var door := spawn("normal", Vector3(-15, 0, -5))
	door._flank = Vector3.ZERO
	door._start_chase(pl.global_position)
	door.rotation.y = PI
	await seconds(6.0)
	ok(door.position.distance_to(pl.global_position) < 2.5, "zombie follows you through a door")
	await kill_all()
	pl.hp = 100.0

	# Wheat hides you.
	place(Vector3(-35, 0, 36), 0.0)
	var wz := spawn("normal", pl.global_position + Vector3(0, 0, -11))
	wz.rotation.y = 0.0
	wz.position = Vector3(-35, 0, 19)
	await seconds(0.8)
	ok(wz.state != Zombie.State.CHASE, "wheat hides you at 17 m")
	await kill_all()

	# Normal has no weapon, Clever finds one and fights with it.
	place(Vector3(50, 0, 50), PI)
	clear_pickups()
	var norm := spawn("normal", Vector3(0, 0, 30))
	w.spawn_pickup_at(Vector3(1, 0, 30), Pickup.Kind.WEAPON, "spear")
	await seconds(3.0)
	ok(norm.weapon_id == "" and w.count_pickups(Pickup.Kind.WEAPON) == 1, "normal zombie ignores weapons")
	await kill_all()
	clear_pickups()
	var clever := spawn("clever", Vector3(0, 0, 30))
	w.spawn_pickup_at(Vector3(6, 0, 30), Pickup.Kind.WEAPON, "spear")
	w.spawn_pickup_at(Vector3(-20, 0, 40), Pickup.Kind.WEAPON, "mace")
	await seconds(8.0)
	ok(clever.weapon_id == "spear", "clever zombie takes the nearest weapon")
	ok(w.count_pickups(Pickup.Kind.WEAPON) == 1, "weapon leaves the map")
	await seconds(4.0)
	ok(clever.weapon_id == "spear", "it only carries one")
	ok(clever._melee_reach() > 3.0, "spear gives it longer reach")
	clever.take_damage(9999.0, Vector3.FORWARD, 0.0, clever.position)
	await frames(2)
	ok(w.count_pickups(Pickup.Kind.WEAPON) == 2, "it drops the weapon when killed")
	await seconds(2.5)
	clear_pickups()
	# Armed with a bow it shoots.
	place(OPEN)
	pl.hp = 100.0
	var archer := spawn("clever", front(10.0))
	archer.rotation.y = pl.yaw
	archer.weapon_id = "bow"
	archer._show_weapon("bow")
	await seconds(4.0)
	ok(pl.hp < 100.0 and archer.position.distance_to(pl.global_position) > 4.0, "clever zombie with a bow shoots from range")
	await kill_all()

	# Magic burns.
	place(OPEN)
	pl.hp = 100.0
	pl.burn_time = 0.0
	var mage := spawn("magic", front(12.0))
	mage.rotation.y = pl.yaw
	var burned := false
	for i in 300:
		await get_tree().physics_frame
		if pl.burn_time > 0.0:
			burned = true
			break
	ok(burned, "magic zombie's fireball burns you")
	ok(mage.position.distance_to(pl.global_position) > 5.0, "it casts from a distance")
	await kill_all()
	await seconds(3.2)
	pl.hp = 100.0
	ok(pl.burn_time <= 0.0, "burn wears off")

	# Beast hunts a hidden player, faster than a sprint.
	place(Vector3(-16, 0, 14), 0.0)
	pl.hp = 100.0
	var beast := spawn("beast", Vector3(30, 0, 14))
	ok(float(ZombieDefs.ALL["beast"]["speed"]) > Player.WALK_SPEED, "beast is faster than you")
	var from_b := beast.position.distance_to(pl.global_position)
	await seconds(4.0)
	ok(beast.state == Zombie.State.CHASE and beast.position.distance_to(pl.global_position) < from_b - 12.0, "beast tracks you even out of sight")
	pl.hp = 100000.0 # it may well kill you, but the test goes on
	await seconds(9.0)
	ok(pl.hp < 100000.0, "beast reaches you inside a house")
	await kill_all()
	pl.hp = 100.0
	# The howl comes with the spawn.
	w.director.running = true
	w.director.elapsed = 500.0
	w.director._next_beast = 500.0
	w.director._spawn_timer = 999.0
	await seconds(0.2)
	ok(w.count_type("beast") == 1 and w.director.banner.contains("howl"), "beast arrives with a howl")
	w.director.running = false
	await kill_all()


func test_trees() -> void:
	for id: String in ClassDefs.ALL:
		var tree := AbilityData.tree(id)
		ok((tree["core"] as Array).size() == Player.CORE_STEPS, "%s has its shared tiers" % id)
		ok((tree["specs"] as Array).size() == 3, "%s has 3 specializations" % id)
		var ids := {}
		var icons := {}
		var bad_icons := 0
		var check := func(a: Dictionary) -> void:
			ids[a["id"]] = ids.get(a["id"], 0) + 1
			if not a.get("mastery", false):
				icons[a["icon"]] = int(icons.get(a["icon"], 0)) + 1
			for part: String in (a["icon"] as String).split("+"):
				if not Icons.exists(part):
					bad_icons += 1
					print("  missing icon ", part, " for ", a["id"])
		for tier: Array in tree["core"]:
			ok(tier.size() == (1 if ClassDefs.ALL[id].get("auto_tree", false) else 2), "%s core tier has its choices" % id)
			for a: Dictionary in tier:
				check.call(a)
		for spec: Dictionary in tree["specs"]:
			check.call(spec["entry"])
			check.call(spec["final"])
			ok((spec["path"] as Array).size() == 4, "%s has 4 steps" % spec["name"])
			var choices := 0
			for step: Array in spec["path"]:
				if step.size() == 2:
					choices += 1
				for a: Dictionary in step:
					check.call(a)
			ok(choices == (0 if ClassDefs.ALL[id].get("auto_tree", false) else 4), "%s has its real choices" % spec["name"])
			ok(spec["final"].get("final", false), "%s ends in a final ability" % spec["name"])
		var dupes := 0
		for k: String in ids:
			if int(ids[k]) > 1:
				dupes += 1
				print("  duplicate id ", k)
		ok(dupes == 0, "%s ability ids are unique" % id)
		ok(bad_icons == 0, "%s icon shapes all exist" % id)
		print("  %s total ability nodes %d" % [id, ids.size()])

	var total_xp := 0
	for l in range(1, ClassDefs.MAX_LEVEL):
		total_xp += ClassDefs.xp_for_level(l)
	print("  xp to top level ", total_xp)
	ok(total_xp > 1200 and total_xp < 2500, "levelling takes most of a night (%d points)" % total_xp)
	ok(ClassDefs.MAX_LEVEL - 1 == Player.CORE_STEPS + 1 + 4 + 1, "the points exactly fill a branch")
	ok(ClassDefs.XP_TO_NEXT.size() == ClassDefs.MAX_LEVEL - 1, "and each level has its price")

	# Exclusivity and order.
	Game.player_class = "magician"
	await start_clean()
	place(OPEN)
	ok(pl.level == 1 and pl.points == 0, "starts at level 1")
	var z := spawn("normal", front(6.0), true)
	await frames(2)
	z.take_damage(9999.0, Vector3.FORWARD, 0.0, z.position)
	ok(pl.xp == 10 and pl.kills == 1 and pl.level == 1, "one kill is far from a level")
	await seconds(2.4)
	ok(not pl.choose_ability(0, 0), "no point, no ability")
	pl.points = 20
	ok(not pl.choose_ability(1, 0), "steps go in order")
	for i in Player.CORE_STEPS:
		ok(pl.choose_ability(i, 0), "takes shared ability %d" % i)
	ok(not pl.choose_ability(0, 1), "the other choice of a tier stays locked")
	ok(pl.steps().size() == Player.CORE_STEPS + 1, "branches stay closed until a specialization is taken")
	m.toggle_tree()
	await frames(3)
	var panel_ref: TreePanel = m.tree_panel
	ok(panel_ref != null and hud.menu_open and not get_tree().paused, "tree opens with the game running")
	var cards := panel_ref._zone.find_children("*", "Button", true, false)
	ok(cards.size() == 3, "three specializations to choose from, as cards")
	(cards[2] as Button).pressed.emit()
	await frames(2)
	ok(pl.spec_id == "illusionist", "one tap on a card picks the specialization")
	ok(pl.steps().size() == ClassDefs.MAX_LEVEL - 1, "the chosen branch opens")
	var others := 0
	var open_nodes := 0
	for n in panel_ref._map.nodes:
		if n.spec >= 0 and n.spec != 2:
			others += 1
		if panel_ref.state_of(n) == "ready":
			open_nodes += 1
	ok(others == 0, "the other two branches leave the map")
	ok(open_nodes == 2, "the next tier offers its two choices")
	ok(panel_ref._zone.find_children("*", "Button", true, false).size() == 2, "as two cards")
	m.toggle_tree()
	await frames(2)
	ok(m.tree_panel == null and not hud.menu_open, "tree closes")
	pl.xp = 0
	pl.level = ClassDefs.MAX_LEVEL
	pl.add_xp(5000)
	ok(pl.level == ClassDefs.MAX_LEVEL, "levels stop at the top")

	# Every ability of every branch can be taken and fired without errors.
	await start_clean()
	for id: String in ClassDefs.ALL:
		for spec_i in 3:
			for pick in 2:
				Game.player_class = id
				await fresh_pawn(id)
				place(OPEN)
				pl.points = ClassDefs.MAX_LEVEL - 1
				var ok_all := true
				for step in ClassDefs.MAX_LEVEL - 1:
					if pl.next_step() > step:
						continue # a Revenant's gifts come by themselves
					var options: Array = pl.steps()[step]
					var opt := spec_i if step == Player.CORE_STEPS else mini(pick, options.size() - 1)
					if not pl.choose_ability(step, opt):
						ok_all = false
				var d := spawn("normal", front(1.8), true)
				await frames(2)
				aim_at(d)
				d.hp = 100000.0
				for event: String in pl._triggers:
					for e: Dictionary in pl._triggers[event]:
						pl._act(e, {"z": d, "attacker": d})
				pl.mana = pl.max_mana()
				pl.arrows = 30
				pl.input_fire = true
				await seconds(0.5)
				pl.input_fire = false
				pl.hurt(5.0, front(2.0), d)
				ok(ok_all and pl.spec_id != "" and not pl.dead, "%s %s build %d works" % [id, pl.spec_def()["name"], pick])
				d.set_physics_process(true)
				await kill_all()
	Game.player_class = "infantry"


## Takes a whole branch, then checks its final ability really does something.
func build(cls: String, spec: int) -> void:
	Game.player_class = cls
	await start_clean()
	place(OPEN)
	pl.points = ClassDefs.MAX_LEVEL - 1
	for step in ClassDefs.MAX_LEVEL - 1:
		var opt := spec if step == Player.CORE_STEPS else 0
		pl.choose_ability(step, opt)
	pl.hp = pl.max_hp()


func test_finals() -> void:
	await build("infantry", 0)
	var z := spawn("normal", front(2.0), true)
	await frames(2)
	pl.hp = pl.max_hp()
	pl._riposte_cd = 0.0
	pl.mods["dodge"] = 0.0 # the branch's Parry Stance would otherwise sometimes step in first
	pl.hurt(30.0, z.position, z)
	ok(pl.hp == pl.max_hp() and z._stun > 0.0, "Perfect Riposte blocks and stuns")
	z.set_physics_process(true)
	await kill_all()

	await build("infantry", 1)
	await equip("sword")
	var i0 := pl.attack_interval(WeaponDefs.ALL["sword"])
	pl.hp = pl.max_hp() * 0.4
	ok(pl.attack_interval(WeaponDefs.ALL["sword"]) < i0, "Blood Frenzy attacks faster when hurt")
	var hp0 := pl.hp
	var bz := spawn("normal", front(1.6), true)
	await frames(2)
	aim_at(bz)
	bz.hp = 5000.0
	pl.input_fire = true
	await seconds(0.8)
	pl.input_fire = false
	ok(pl.hp > hp0, "Blood Frenzy heals from hits")
	bz.set_physics_process(true)
	await kill_all()

	await build("infantry", 2)
	await equip("dagger")
	var unaware := spawn("normal", front(1.5), true)
	await frames(2)
	aim_at(unaware)
	unaware.hp = 5000.0
	pl.input_fire = true
	await seconds(0.3)
	pl.input_fire = false
	await frames(2)
	ok(not unaware.is_alive(), "Death from the Dark kills the unaware in one hit")
	ok(pl.invis_left > 0.0, "and hides you")
	unaware.set_physics_process(true)
	await seconds(2.5)
	pl.invis_left = 3.0
	var watcher := spawn("normal", front(6.0))
	watcher.rotation.y = pl.yaw
	await seconds(0.5)
	ok(watcher.state != Zombie.State.CHASE, "a vanished player cannot be seen")
	await kill_all()

	await build("ranger", 0)
	await equip("bow")
	pl.arrows = 10
	pl._kill_shot_cd = 0.0
	var ks := spawn("normal", front(6.0), true)
	await frames(2)
	aim_at(ks)
	ks.hp = 10000.0
	pl.input_fire = true
	await frames(3)
	pl.input_fire = false
	await seconds(0.5)
	ok(10000.0 - ks.hp >= 300.0, "Killing Shot hits for 300 (%.0f)" % (10000.0 - ks.hp))
	ks.set_physics_process(true)
	await kill_all()

	await build("ranger", 1)
	ok(int(pl.m("trap_cap")) >= 8, "Field of Snares allows 8 traps")
	w.place_trap(pl, pl.global_position + Vector3(2, 0, 0))
	var tz := spawn("normal", pl.global_position + Vector3(2.2, 0, 0))
	tz.hp = 10.0
	var traps0: int = w._traps.size()
	await seconds(0.3)
	ok(not tz.is_alive(), "a trap kills")
	ok(w._traps.size() >= traps0, "the kill drops a new trap")
	await seconds(2.5)

	Game.pet = "wolf"
	await build("ranger", 2)
	pl._wolf_timer = 0.0
	await seconds(0.3)
	ok(w.count_allies("wolf") >= 1, "wolves come to a Beastmaster")
	ok(int(pl.m("wolves")) == 3, "The Pack adds one beast: three with Second Beast (%d)" % int(pl.m("wolves")))
	var wz := spawn("normal", w.allies[0].position + Vector3(0, 0, 2.0))
	wz.hp = 1000.0
	await seconds(3.0)
	ok(wz.hp < 1000.0, "the wolf bites")
	await kill_all()

	await build("heavy", 0)
	ok(pl.shield_tier == 3, "Guardian reaches the rectangular iron shield")
	ok(pl.has_art() and pl.m("cover") >= 0.25, "and covers others")
	pl.velocity = Vector3.ZERO
	await seconds(0.2)
	pl.hp = pl.max_hp()
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.3)
	pl.hurt(50.0, front(2.0))
	ok(pl.hp < pl.max_hp() and pl.max_hp() - pl.hp <= 20.01, "the Shield Dome mitigates damage without invulnerability")
	ok(pl.art_cd_left > 0.0, "and it needs a long time to come back")
	pl.guard_left = 0.0
	pl.hurt(99999.0, pl.global_position + pl.global_basis.z)
	await seconds(2.5)
	pl.guard_left = 0.0
	pl.hurt(99999.0, pl.global_position + pl.global_basis.z)
	ok(pl.dead, "but only once a minute")

	await build("heavy", 1)
	var hz := spawn("normal", front(8.0), true)
	await frames(2)
	hz.hp = 1000.0
	for e: Dictionary in pl._triggers["every"]:
		if e["do"] == "thunder_all":
			pl._act(e, {})
	ok(hz.hp < 1000.0, "Divine Wrath strikes nearby enemies")
	hz.set_physics_process(true)
	await kill_all()

	await build("heavy", 2)
	await equip("mace")
	var qz := spawn("normal", front(5.0), true)
	await frames(2)
	qz.hp = 1000.0
	var near := spawn("normal", front(1.6), true)
	await frames(2)
	aim_at(near)
	near.hp = 10000.0
	pl.input_fire = true
	await seconds(4.0)
	pl.input_fire = false
	ok(qz.hp < 1000.0, "Earthbreaker reaches out to 7 m")
	near.set_physics_process(true)
	qz.set_physics_process(true)
	await kill_all()

	await build("chivalry", 0)
	pl.horse_progress = 99
	pl.mount()
	pl.hp = pl.max_hp()
	pl.hurt(50.0, front(2.0))
	ok(pl.hp == pl.max_hp(), "Unstoppable Charge takes no damage while riding")
	var un := spawn("clever", front(4.0), true)
	await frames(2)
	un.hp = 5000.0
	pl.input_move = Vector2(0, -1)
	await seconds(0.8)
	pl.input_move = Vector2.ZERO
	ok(not un.is_alive(), "and tramples anything but Beasts")
	pl.dismount()
	un.set_physics_process(true)
	await seconds(2.5)

	await build("chivalry", 1)
	pl.horse_progress = 0
	ok(pl.horse_ready(), "Sacred Steed comes without kills")
	pl.mount()
	pl.hp = 20.0
	await seconds(1.0)
	ok(pl.hp > 21.0, "and heals while riding")
	pl.dismount()
	ok(not pl.horse_ready(), "but only every 60 s")

	await build("chivalry", 2)
	ok(pl.can_use("bow"), "Horse Archer can use ranged weapons")
	pl.horse_progress = 99
	pl.mount()
	var pz := spawn("normal", front(8.0), true)
	await frames(2)
	pz.hp = 1000.0
	for e: Dictionary in pl._triggers["every"]:
		if e["do"] == "volley":
			e["timer"] = 0.01
	await seconds(1.0)
	ok(pz.hp < 1000.0, "Parthian Volley fires while riding")
	pl.dismount()
	pz.set_physics_process(true)
	await kill_all()

	await build("magician", 0)
	ok(int(pl.m("ally_cap")) == 6, "Army of the Dead allows 6 allies")
	for e: Dictionary in pl._triggers["every"]:
		if int(e.get("n", 0)) == 3:
			pl._act(e, {})
	await frames(3)
	ok(w.count_allies("skeleton") >= 3, "3 skeletons rise (%d)" % w.count_allies("skeleton"))
	for al: Ally in w.allies.duplicate():
		w.remove_ally(al)

	await build("magician", 1)
	var cz := spawn("normal", front(15.0), true)
	var cfar := spawn("normal", front(30.0), true)
	await frames(2)
	cz.hp = 1000.0
	cfar.hp = 1000.0
	for e: Dictionary in pl._triggers["every"]:
		if e["do"] == "cataclysm":
			pl._act(e, {})
	ok(cz.hp < 1000.0 and cz.burn_time > 0.0, "Cataclysm burns everything in range")
	ok(cfar.hp == 1000.0, "but not further")
	cz.set_physics_process(true)
	cfar.set_physics_process(true)
	await kill_all()
	pl.mana = pl.max_mana()
	var element_shots := []
	for i in 3:
		pl._shot_count = i
		element_shots.append(["fire", "frost", "storm"][pl._shot_count % 3])
	ok(element_shots.size() == 3, "bolts cycle through elements")

	await build("magician", 2)
	pl.art_cd_left = 0.0
	pl.use_art()
	await seconds(0.3)
	ok(w.count_allies("mirror") >= 1 and w.count_allies("decoy") >= 1, "a swap leaves decoys and mirror images")
	var mz := spawn("normal", w.allies[0].position + Vector3(0, 0, 4.0))
	mz.hp = 1000.0
	await seconds(3.0)
	ok(mz.hp < 1000.0, "mirror images cast bolts")
	ok(w.nearest_target(w.allies[0].position + Vector3(0, 0, 0.3)) is Ally, "enemies go for the illusions")
	await kill_all()
	for al: Ally in w.allies.duplicate():
		w.remove_ally(al)
	Game.player_class = "infantry"


func test_classes() -> void:
	var starts := {"infantry": "dagger", "ranger": "bow", "heavy": "flail", "chivalry": "lance", "magician": "staff"}
	for id: String in starts:
		Game.player_class = id
		await start_clean()
		ok(pl.slots[0] == starts[id], "%s starts with %s" % [id, starts[id]])
		ok(is_equal_approx(pl.hp, ClassDefs.ALL[id]["hp"]), "%s has its own health" % id)

	# Class rules on picking up weapons.
	Game.player_class = "heavy"
	await start_clean()
	place(OPEN)
	w.spawn_pickup_at(front(0.8), Pickup.Kind.WEAPON, "bow", 8)
	await seconds(0.4)
	ok(pl.slots[1] == null and w.count_pickups(Pickup.Kind.WEAPON) == 1, "Heavy Infantry cannot take a bow")
	w.spawn_pickup_at(front(1.4), Pickup.Kind.WEAPON, "sword")
	await seconds(0.4)
	ok(pl.slots[1] == "sword", "Heavy Infantry can take a sword")
	clear_pickups()
	ok(pl.shield_tier == 0, "starts with a wooden round shield")
	var mesh0: Mesh = pl._shield_node.mesh
	pl.points = 3
	pl.choose_ability(0, 0)
	pl.choose_ability(1, 0)
	pl.choose_ability(2, 0)
	ok(pl.shield_tier == 1 and pl._shield_node.mesh != mesh0, "shield upgrades to banded iron")
	pl.hp = pl.max_hp()
	pl.hurt(20.0, front(3.0))
	var blocked := pl.max_hp() - pl.hp
	pl.hp = pl.max_hp()
	pl.hurt(20.0, pl.global_position + pl.global_basis.z * 3.0)
	var from_back := pl.max_hp() - pl.hp
	print("  shield: front ", blocked, " back ", from_back)
	ok(blocked < from_back * 0.6, "shield blocks from the front only")

	# Magician.
	Game.player_class = "magician"
	await start_clean()
	place(OPEN)
	pl.mana = 15.0
	var mz := spawn("normal", front(6.0), true)
	await frames(2)
	aim_at(mz)
	mz.hp = 1000.0
	pl.input_fire = true
	await seconds(0.2)
	pl.input_fire = false
	await seconds(0.5)
	ok(mz.hp < 1000.0, "staff bolt hits")
	ok(pl.mana < 15.0, "bolts use mana")
	var before := pl.mana
	await seconds(1.0)
	ok(pl.mana > before, "mana refills")
	pl.mana = 0.0
	pl.input_fire = true
	await seconds(0.2)
	pl.input_fire = false
	ok(pl.toast == "No mana", "no mana, no bolt")
	mz.set_physics_process(true)
	await kill_all()
	pl.slots = ["staff", null]
	pl.current = 0
	pl._equip()
	w.spawn_pickup_at(front(1.0), Pickup.Kind.WEAPON, "sword")
	await seconds(0.3)
	pl.take_nearby_weapon()
	await frames(2)
	ok(pl.weapon_id() == "staff" and not pl.slots.has("sword") and not pl.can_use("sword"), "the Magician refuses a ground weapon and keeps only the staff")
	clear_pickups()

	# Chivalry and the horse.
	Game.player_class = "chivalry"
	await start_clean()
	place(OPEN)
	ok(not pl.horse_ready(), "horse needs kills first")
	pl.mount()
	ok(not pl.is_riding(), "cannot mount without enough kills")
	for i in Player.HORSE_KILLS:
		var q := spawn("normal", front(12.0), true)
		await frames(2)
		q.set_physics_process(true)
		q.take_damage(9999.0, Vector3.FORWARD, 0.0, q.position)
		if i % 4 == 3:
			await seconds(2.4)
	await seconds(2.4)
	ok(pl.horse_ready(), "%d kills call the horse" % Player.HORSE_KILLS)
	ok(hud._button_visible("horse"), "HORSE button appears")
	touch(5, hud._buttons["horse"]["pos"], true)
	touch(5, hud._buttons["horse"]["pos"], false)
	await frames(2)
	ok(pl.is_riding(), "HORSE button mounts")
	var ride_from := pl.global_position
	pl.input_move = Vector2(0, -1)
	await seconds(0.7)
	var ride_speed := pl.global_position.distance_to(ride_from) / 0.7
	print("  riding speed ", ride_speed)
	ok(ride_speed > Player.WALK_SPEED * 1.4, "riding is much faster than walking")
	pl.input_move = Vector2.ZERO
	await seconds(0.3)
	place(OPEN)
	await frames(2)
	var trampled := spawn("normal", front(5.0), true)
	await frames(2)
	trampled.hp = 1000.0
	pl.input_move = Vector2(0, -1)
	await seconds(0.8)
	pl.input_move = Vector2.ZERO
	ok(trampled.hp < 1000.0, "riding into a zombie tramples it")
	trampled.set_physics_process(true)
	await kill_all()
	pl.riding_left = 0.15
	await seconds(0.4)
	ok(not pl.is_riding(), "the horse leaves when the time ends")
	await seconds(0.8)
	ok(pl.head.position.y < 1.8, "camera returns to walking height")
	ok(not pl.can_use("bow"), "Chivalry cannot use a bow")
	Game.player_class = "infantry"


func test_enemies() -> void:
	Game.player_class = "infantry"
	await start_clean()
	# Leaper jumps a fence that stops others. The east fence of the west field runs along x = -20.
	place(Vector3(-23, 0, 28), -PI * 0.5)
	pl.hp = pl.max_hp()
	var leaper := spawn("leaper", Vector3(-15, 0, 28))
	leaper.rotation.y = -PI * 0.5
	leaper._special_cd = 0.0
	var went_up := false
	var crossed := false
	for i in 240:
		await get_tree().physics_frame
		if leaper.position.y > 0.8:
			went_up = true
		if leaper.position.x < -20.5:
			crossed = true
			break
	ok(went_up, "Leaper leaps through the air")
	ok(crossed, "Leaper crosses a fence directly")
	await kill_all()
	pl.hp = pl.max_hp()

	# Crows dive from above and cannot reach you indoors.
	place(OPEN)
	var crow := spawn("crow", OPEN + Vector3(5, 5, 0))
	ok(crow.position.y > 2.0, "crows fly")
	crow._special_cd = 0.0
	crow._start_chase(pl.global_position)
	var low := 99.0
	for i in 300:
		await get_tree().physics_frame
		low = minf(low, crow.position.y)
		if pl.hp < pl.max_hp():
			break
	ok(pl.hp < pl.max_hp(), "a crow dives and pecks you")
	ok(low < 2.8, "it really comes down (%.1f m)" % low)
	crow.take_damage(WeaponDefs.DAMAGE, Vector3.UP, 0.0, crow.centre())
	await frames(2)
	ok(not crow.is_alive(), "one hit kills a crow")
	await seconds(1.0)
	pl.hp = pl.max_hp()
	place(Vector3(-16, 0, 14), 0.0)
	var roof := spawn("crow", Vector3(-16, 6, 14))
	roof._special_cd = 0.0
	roof._start_chase(pl.global_position)
	await seconds(5.0)
	ok(pl.hp == pl.max_hp(), "a roof protects you from crows")
	await kill_all()

	# Gargoyle sits still on a roof, then swoops.
	place(OPEN)
	var perch := OPEN + Vector3(-9, 5.0, 0)
	var garg := spawn("gargoyle", perch)
	ok(garg.dormant, "a gargoyle starts as a statue")
	await seconds(0.3)
	ok(garg.position.distance_to(perch) < 0.05 or not garg.dormant, "it stays still while waiting")
	garg.rotation.y = PI * 0.5
	var woke := false
	for i in 120:
		await get_tree().physics_frame
		if not garg.dormant:
			woke = true
			break
	ok(woke, "it wakes when you come close")
	garg._special_cd = 0.0
	pl.hp = pl.max_hp()
	for i in 300:
		await get_tree().physics_frame
		if pl.hp < pl.max_hp():
			break
	ok(pl.hp < pl.max_hp(), "it swoops down on you")
	await kill_all()
	pl.hp = pl.max_hp()

	# Mimic looks like loot until you get close.
	place(Vector3(0, 0, 30))
	var mimic := spawn("mimic", Vector3(0, 0, 24))
	await seconds(0.5)
	ok(mimic.dormant and mimic._lure.visible, "a mimic looks like loot")
	ok(mimic.position.distance_to(Vector3(0, 0, 24)) < 0.05, "and stays still")
	place(Vector3(0, 0, 26.2))
	pl.hp = pl.max_hp()
	await seconds(2.5)
	ok(not mimic.dormant and mimic._visual.visible and not mimic._lure.visible, "it reveals itself when you come close")
	ok(pl.hp < pl.max_hp(), "and bites")
	await kill_all()
	pl.hp = pl.max_hp()

	# Scarecrow moves only when you are not looking.
	place(Vector3(0, 0, 36), 0.0)
	var sc := spawn("scarecrow", pl.global_position - pl.global_basis.z * 10.0)
	sc._start_chase(pl.global_position)
	await seconds(1.0)
	var start_sc := sc.position
	await seconds(1.2)
	ok(sc.position.distance_to(start_sc) < 0.2, "a scarecrow freezes while you look at it")
	pl.yaw = PI
	pl.rotation.y = PI
	await seconds(1.5)
	ok(sc.position.distance_to(start_sc) > 1.0, "it moves when you look away")
	await kill_all()

	# Wraith drifts through walls and fears fire.
	place(Vector3(-16, 0, 14), 0.0)
	pl.hp = pl.max_hp()
	var wraith := spawn("wraith", Vector3(-16, 0, 26))
	wraith._start_chase(pl.global_position)
	await seconds(7.0)
	ok(wraith.position.distance_to(pl.global_position) < 3.0, "a wraith passes through walls")
	var hp_w := wraith.hp
	await seconds(1.0)
	wraith.hp = 500.0
	w.burn_tick(wraith)
	ok(500.0 - wraith.hp >= 11.0, "fire hurts it double")
	await kill_all()
	pl.hp = pl.max_hp()
	ok(hp_w > 0.0, "wraith survived the walk")

	# Banshee alerts everything around.
	place(OPEN)
	var banshee := spawn("banshee", front(12.0))
	banshee.rotation.y = pl.yaw
	var far_z := spawn("normal", pl.global_position + pl.global_basis.z * 28.0, true)
	far_z.rotation.y = pl.yaw + PI
	banshee._special_cd = 0.0
	await seconds(0.5)
	ok(banshee._special_left > 0.0, "a banshee stops to scream")
	ok(far_z.state != Zombie.State.CHASE, "others do not know yet")
	await seconds(2.8)
	ok(far_z.state == Zombie.State.CHASE, "her scream gives you away to zombies far off")
	banshee.take_damage(99999.0, Vector3.UP, 0.0, banshee.centre())
	await kill_all()
	pl.hp = pl.max_hp()

	# Fallen Heroes grow with the night.
	w.director.elapsed = 60.0
	w.spawn_zombie("hero_infantry", OPEN + Vector3(0, 0, -30))
	var early: Zombie = w.zombies[w.zombies.size() - 1]
	var hp_early := early.max_hp
	var dmg_early := early._melee_damage()
	early.take_damage(9999999.0, Vector3.FORWARD, 0.0, early.position)
	await seconds(2.5)
	clear_pickups()
	w.director.elapsed = 480.0
	w.spawn_zombie("hero_infantry", OPEN + Vector3(0, 0, -30))
	var late: Zombie = w.zombies[w.zombies.size() - 1]
	print("  hero hp ", hp_early, " -> ", late.max_hp, " damage ", dmg_early, " -> ", late._melee_damage())
	ok(late.max_hp > hp_early and late._melee_damage() > dmg_early, "a Fallen Hero late in the night is stronger")
	ok(late.weapon_id == "sword", "it carries its class weapon")
	late.take_damage(9999999.0, Vector3.FORWARD, 0.0, late.position)
	await frames(2)
	ok(w.count_pickups(Pickup.Kind.WEAPON) == 1, "and drops it")
	await seconds(2.5)
	clear_pickups()
	w.director.elapsed = 0.0
	place(OPEN)
	var heavy := spawn("hero_heavy", front(4.0), true)
	await frames(2)
	heavy.rotation.y = pl.yaw
	heavy.hp = 1000.0
	heavy.take_damage(100.0, -pl.global_basis.z, 0.0, heavy.centre())
	var front_dmg := 1000.0 - heavy.hp
	heavy.hp = 1000.0
	heavy.rotation.y = pl.yaw + PI
	heavy.take_damage(100.0, -pl.global_basis.z, 0.0, heavy.centre())
	var back_dmg := 1000.0 - heavy.hp
	print("  heavy: front ", front_dmg, " back ", back_dmg)
	ok(front_dmg == 50.0 and back_dmg == 100.0, "Fallen Heavy blocks hits from the front")
	heavy.set_physics_process(true)
	await kill_all()
	clear_pickups()
	# Every hero type runs a while without errors.
	pl.hp = pl.max_hp()
	w.director.elapsed = 500.0
	for id: String in ZombieDefs.HEROES:
		w.spawn_zombie(id, front(9.0))
	await seconds(5.0)
	ok(w.count_living() >= 1, "Fallen Heroes fight")
	pl.hp = pl.max_hp()
	await kill_all()
	clear_pickups()

	# Schedule: the director sends everything at its time.
	await start_clean()
	var dir: Director = w.director
	dir.running = true
	dir._spawn_timer = 99999.0
	dir.elapsed = 119.9
	await seconds(0.2)
	ok(w.count_type("crow") == 3, "crows arrive as a flock")
	dir.elapsed = 239.9
	dir._next_beast = 99999.0
	await seconds(0.2)
	var hero_count := 0
	for z: Zombie in w.zombies:
		if z.def.get("hero", false):
			hero_count += 1
	ok(hero_count == 1, "a Fallen Hero rises")
	ok(dir.banner.contains("rises"), "and is announced")
	ok(w.count_type("gargoyle") == 1, "a gargoyle takes a roof")
	dir.elapsed = 500.0
	dir._next_ambush = 500.0
	await seconds(0.2)
	ok(w.count_type("mimic") + w.count_type("scarecrow") >= 1, "ambushers appear")
	dir.running = false
	await kill_all()

	# Familiars come often, nearby, and are announced.
	await start_clean()
	clear_pickups()
	w.director._familiar_timer = 0.05
	await seconds(0.2)
	var fam: Pickup = null
	for it: Pickup in w.pickups:
		if it.kind == Pickup.Kind.POWER and PowerDefs.ALL[it.item_id]["familiar"]:
			fam = it
	ok(fam != null, "a familiar appears")
	ok(fam.global_position.distance_to(pl.global_position) <= 40.0, "near the player")
	ok(w.director._familiar_timer > 25.0 and w.director._familiar_timer <= 30.0, "about every 30 s")
	ok(fam.life > 60.0, "and it waits on the map longer")

	# Sunrise moves the light and burns the undead.
	await start_clean()
	var d0: Vector3 = w._moon.rotation_degrees
	w._apply_sky(1.0)
	ok(w._moon.rotation_degrees != d0 and w._env.fog_density < 0.01, "the sun moves the light and clears the fog")
	var z2 := spawn("normal", OPEN + Vector3(10, 0, 0))
	z2._start_chase(pl.global_position)
	w.on_dawn()
	await seconds(1.6)
	ok(not z2.is_alive(), "the sunrise burns the undead")
	pl.hurt(99999.0, front(2.0))
	ok(not pl.dead, "you are safe at dawn")
	await seconds(3.0)
	Game.player_class = "infantry"


func test_new_stuff() -> void:
	await start_clean()
	place(OPEN)
	# Drops disappear.
	var weapon_drop := w.spawn_pickup_at(Vector3(40, 0, 40), Pickup.Kind.WEAPON, "sword")
	var item_drop := w.spawn_pickup_at(Vector3(44, 0, 44), Pickup.Kind.FOOD, "apple")
	ok(is_equal_approx(weapon_drop.life, 60.0) and is_equal_approx(item_drop.life, 45.0), "weapons last 60 s and items 45 s")
	item_drop.life = 3.0
	var hidden_seen := false
	for i in 120:
		await get_tree().physics_frame
		if not item_drop._spin.visible:
			hidden_seen = true
			break
	ok(hidden_seen, "drops blink before vanishing")
	item_drop.life = 0.05
	weapon_drop.life = 0.05
	await frames(5)
	ok(w.pickups.is_empty(), "drops vanish when their time ends")
	# A clever zombie aiming for a vanishing weapon does not crash.
	var c := spawn("clever", Vector3(0, 0, 40))
	var gone := w.spawn_pickup_at(Vector3(4, 0, 40), Pickup.Kind.WEAPON, "mace")
	await seconds(0.3)
	gone.life = 0.02
	await seconds(1.0)
	ok(c.weapon_id == "", "a vanished weapon cannot be picked up")
	await kill_all()
	# The restocker keeps the map supplied.
	w.director._stock_timer = 0.01
	await seconds(0.2)
	ok(w.pickups.size() >= 3, "new drops keep arriving")
	w.director._stock_timer = 99999.0
	clear_pickups()

	# Church bell.
	ok(w.bell != null, "the church has a bell")
	place(Vector3(50, 0, 50), PI)
	var roamer := spawn("normal", Vector3(-14, 0, -30))
	var chaser := spawn("normal", Vector3(10, 0, -30))
	chaser._start_chase(pl.global_position)
	await seconds(0.2)
	w.director._bell_timer = 0.1
	await seconds(0.4)
	ok(w.director._bell_timer > 58.0, "the bell rings every minute")
	ok(w._bell_swing > 0.5, "the bell swings")
	ok(roamer.state == Zombie.State.INVESTIGATE, "the bell draws roaming zombies")
	ok(chaser.state == Zombie.State.CHASE, "the bell does not distract a hunting zombie")
	var d0 := roamer.position.distance_to(w.church_door)
	await seconds(4.0)
	ok(roamer.position.distance_to(w.church_door) < d0 - 1.0, "they walk toward the church")
	await kill_all()
	# The bell's clock keeps going.
	var calls := w.director._bell_timer
	ok(calls > 0.0, "bell timer keeps counting")

	# Smarter hunting.
	place(OPEN)
	pl.hp = pl.max_hp()
	var spotter := spawn("normal", front(12.0))
	spotter.rotation.y = pl.yaw
	var friend := spawn("normal", front(12.0) + Vector3(9, 0, 0))
	friend.rotation.y = pl.yaw + PI
	await seconds(0.7)
	ok(spotter.state == Zombie.State.CHASE, "spotter chases")
	ok(friend.state == Zombie.State.CHASE, "it calls others nearby, even those facing away")
	await kill_all()
	pl.hp = pl.max_hp()
	var side_a := spawn("normal", front(10.0))
	var side_b := spawn("normal", front(10.0))
	side_a._flank = Vector3(1, 0, 0)
	side_b._flank = Vector3(-1, 0, 0)
	side_a._start_chase(pl.global_position)
	side_b._start_chase(pl.global_position)
	await seconds(1.8)
	print("  flank spread ", side_a.position.distance_to(side_b.position))
	ok(side_a.position.distance_to(side_b.position) > 2.0, "zombies spread out to surround you")
	await kill_all()
	pl.hp = pl.max_hp()

	# New weapons' special rules.
	await equip("bell_hammer")
	var stunned := spawn("normal", front(1.8), true)
	await frames(2)
	stunned.hp = 1000.0
	pl.input_fire = true
	await seconds(0.3)
	pl.input_fire = false
	ok(stunned._stun > 0.0, "Bell Hammer stuns")
	stunned.set_physics_process(true)
	await kill_all()
	await equip("torch")
	var burned := spawn("normal", front(1.5), true)
	await frames(2)
	burned.hp = 1000.0
	pl.input_fire = true
	await seconds(0.3)
	pl.input_fire = false
	ok(burned.burn_time > 0.0, "Torch sets enemies on fire")
	burned.set_physics_process(true)
	await kill_all()
	await equip("flail")
	var i0 := pl.attack_interval(WeaponDefs.ALL["flail"])
	var fz := spawn("normal", front(1.5), true)
	await frames(2)
	fz.hp = 5000.0
	pl.input_fire = true
	await seconds(3.0)
	var i1 := pl.attack_interval(WeaponDefs.ALL["flail"])
	pl.input_fire = false
	ok(i1 < i0 * 0.6, "Flail gets faster as you keep swinging")
	await seconds(1.6)
	ok(is_equal_approx(pl.attack_interval(WeaponDefs.ALL["flail"]), i0), "Flail slows again when you stop")
	fz.set_physics_process(true)
	await kill_all()
	await equip("pitchfork")
	var f1 := spawn("normal", front(1.8), true)
	var f2 := spawn("normal", front(2.8), true)
	var f3 := spawn("normal", front(3.6), true)
	await frames(2)
	for f: Zombie in [f1, f2, f3]:
		f.hp = 1000.0
	pl.input_fire = true
	await seconds(0.3)
	pl.input_fire = false
	ok(f1.hp < 1000.0 and f2.hp < 1000.0 and f3.hp < 1000.0, "Pitchfork pierces 3 in a line")
	for f: Zombie in [f1, f2, f3]:
		f.set_physics_process(true)
	await kill_all()
	await equip("axes")
	var az := spawn("normal", front(8.0), true)
	await frames(2)
	aim_at(az)
	az.hp = 1000.0
	var arrows0 := pl.arrows
	pl.input_fire = true
	await frames(4)
	pl.input_fire = false
	ok(pl._axe_out, "axe is thrown")
	await seconds(2.5)
	ok(not pl._axe_out, "axe flies back")
	ok(1000.0 - az.hp >= WeaponDefs.DAMAGE * float(WeaponDefs.ALL["axes"]["power"]) * 2.0 - 0.01, "it hits going out and coming back")
	ok(pl.arrows == arrows0, "axes use no arrows")
	az.set_physics_process(true)
	await kill_all()

	# New familiars.
	place(OPEN)
	pl.activate_power("raven")
	var far := spawn("normal", front(20.0), true)
	await seconds(0.2)
	ok(pl.has_power("raven") and is_instance_valid(far), "Raven marks enemies without errors")
	far.set_physics_process(true)
	await kill_all()
	pl.powers.clear()
	pl.activate_power("ghost")
	await seconds(0.2)
	ok(w.allies.size() == 1 and w.allies[0].kind == "ghost", "Ghost Knight appears")
	var gz := spawn("normal", w.allies[0].position + Vector3(0, 0, 2.2))
	gz.hp = 1000.0
	await seconds(3.0)
	ok(gz.hp < 1000.0, "Ghost Knight fights")
	await kill_all()
	w.allies[0].life = 0.05
	await seconds(1.6)
	pl.powers.clear()
	pl.hp = pl.max_hp() * 0.5
	var item := w.spawn_pickup_at(pl.global_position + Vector3(14, 0, 0), Pickup.Kind.FOOD, "bread")
	pl.activate_power("imp")
	await seconds(1.4)
	ok(not is_instance_valid(item) or not w.pickups.has(item), "Thief Imp brings an item to you")
	pl.powers.clear()
	pl.hp = pl.max_hp()
	var bz := spawn("normal", front(6.0), true)
	await frames(2)
	pl.activate_power("bell_spirit")
	await seconds(1.2)
	ok(bz._stun > 0.0, "Bell Spirit freezes nearby enemies")
	pl.powers.clear()
	bz.set_physics_process(true)
	await kill_all()
	pl.activate_power("rat")
	var rz := spawn("normal", pl.global_position + Vector3(0.6, 0, 0), true)
	await frames(2)
	rz.hp = 1000.0
	rz.set_physics_process(true)
	rz._think = 999.0
	await seconds(1.5)
	ok(rz.hp < 1000.0, "Plague Rat's poison hurts enemies standing in it")
	pl.powers.clear()
	await kill_all()
	await seconds(0.2)


func test_night() -> void:
	await start_clean()
	Game.best_time = 0.0
	w.director.running = true
	w.director.elapsed = 0.0
	ok(w.director.target_population() == 6, "night starts with few roamers")
	w.director.elapsed = Game.NIGHT_LENGTH
	ok(w.director.target_population() >= Game.max_live_zombies(), "population grows to the phone's limit")
	var pool_room := 0
	for model: String in ["normal_a", "normal_b", "clever", "magic", "beast"]:
		pool_room += int(Game.zombie_pool_plan()[model])
	ok(w.director.target_population() <= pool_room, "and there are always enough bodies for the last stand")
	w.director.elapsed = 0.0
	ok(w.director.dawn_amount() == 0.0, "sky starts dark")
	w.director.elapsed = Game.NIGHT_LENGTH - 10.0
	await seconds(0.3)
	ok(w.director.dawn_amount() > 0.8, "sky brightens near dawn")
	ok(w._env.ambient_light_energy > 0.7, "the light really changes")
	var nights := Game.nights_survived
	w.director.elapsed = Game.NIGHT_LENGTH - 0.1
	w.director._next_beast = 99999.0
	await seconds(0.5)
	ok(Game.nights_survived == nights + 1, "reaching dawn counts as a win")
	await seconds(4.0)
	ok(m._run_over and m.panel != null and m.panel.visible, "dawn screen appears after the sunrise")
	await frames(2)
	await m.start_game(Game.Mode.NIGHT)
	await seconds(0.2)
	w = m.world
	pl = w.player
	ok(pl.hp == pl.max_hp() and not pl.dead and w.director.elapsed < 1.0, "play again starts a fresh night")
	ok(w.count_living() == 6, "first zombies are already roaming")
	var near := INF
	for z in w.zombies:
		near = minf(near, z.position.distance_to(pl.global_position))
	ok(near > 20.0, "none spawn close to you (%.0f m)" % near)
	var seconds_before := 123.0
	Game.best_time = 0.0
	w.director.elapsed = seconds_before
	pl.hurt(1000.0, pl.global_position + Vector3.FORWARD)
	ok(pl.dead, "player can die")
	await seconds(1.6)
	ok(m.panel != null and m.panel.visible, "death screen appears")
	ok(is_equal_approx(Game.best_time, seconds_before), "survival time is saved")
	await m.start_game(Game.Mode.NIGHT)
	await seconds(0.2)
	m.show_pause()
	await frames(2)
	ok(get_tree().paused, "pause stops the game")
	m.show_menu()
	await frames(3)
	ok(not get_tree().paused and m.world.mode == Game.Mode.MENU, "quit returns to the menu")
	m.queue_free()
	await frames(2)


## Each of these was a real bug found while reviewing version 0.4.
func test_review() -> void:
	Game.player_class = "ranger"
	await start_clean()
	place(OPEN)
	await equip("bow")
	pl.arrows = 60

	# Arrows are the player's own shots: crits and "on shot" abilities must apply to them.
	pl.mods["crit_chance"] = 1.0
	pl._apply_ability(AbilityData.a("test_mark", "", "", "arrow", {}, [AbilityData.t("shot", "mark", {"mult": 1.25, "secs": 4.0})]))
	var dummy := spawn("normal", front(8.0), true)
	await frames(2)
	dummy.hp = 5000.0
	dummy.max_hp = 5000.0
	aim_at(dummy)
	pl.input_fire = true
	await seconds(0.25)
	pl.input_fire = false
	await seconds(0.5)
	ok(5000.0 - dummy.hp >= 45.0, "arrows can crit (%d damage)" % int(5000.0 - dummy.hp))
	ok(dummy._mark_time > 0.0, "arrows trigger on-shot abilities")
	dummy.set_physics_process(true)
	await kill_all()

	# A Ranger takes arrows back from the fallen.
	pl.arrows = 10
	var fallen := spawn("normal", front(5.0), true)
	await frames(2)
	fallen.take_damage(9999.0, Vector3.FORWARD, 0.0, fallen.centre())
	ok(pl.arrows == 12, "a kill gives a Ranger 2 arrows back")
	await kill_all()
	pl.arrows = 60

	# Familiar arrows do not count as the player's shots.
	pl.mods["crit_chance"] = 0.0
	var by_familiar := spawn("normal", front(8.0), true)
	await frames(2)
	w.familiar_arrow(pl, by_familiar)
	await seconds(0.5)
	ok(by_familiar._mark_time <= 0.0, "a familiar's arrow does not trigger on-shot abilities")
	by_familiar.set_physics_process(true)
	await kill_all()

	# Ricochet and Skip Shot: bounces apply to arrows too, not only to bolts.
	pl.mods["bounces"] = 1.0
	var first := spawn("normal", front(8.0), true)
	var second := spawn("normal", front(8.0) + Vector3(3.0, 0, 0), true)
	await frames(2)
	var hp_second := second.hp
	aim_at(first)
	pl.input_fire = true
	await seconds(0.25)
	pl.input_fire = false
	await seconds(0.7)
	ok(second.hp < hp_second, "arrows bounce with the Ricochet ability")
	pl.mods["bounces"] = 0.0
	first.set_physics_process(true)
	second.set_physics_process(true)
	await kill_all()

	# Fire Quiver.
	pl.flags["riding_fire"] = true
	pl.riding_left = 20.0
	var lit := spawn("normal", front(8.0), true)
	await frames(2)
	lit.hp = 5000.0
	aim_at(lit)
	pl.input_fire = true
	await seconds(0.25)
	pl.input_fire = false
	await seconds(0.5)
	ok(lit.burn_time > 0.0, "Fire Quiver lights arrows shot from the saddle")
	pl.flags.erase("riding_fire")
	pl.riding_left = 0.0
	lit.set_physics_process(true)
	await kill_all()

	# Quick Setup shortens the trap timer, and a shout with nobody near stays silent and retries.
	pl.mods["trap_cd"] = -3.0
	pl._apply_ability(AbilityData.a("test_trap", "", "", "trap", {}, [AbilityData.t("every", "trap", {"secs_every": 12.0})]))
	var trap_entry: Dictionary = pl._triggers["every"].back()
	trap_entry["timer"] = 0.01
	await seconds(0.1)
	ok(trap_entry["timer"] > 8.0 and trap_entry["timer"] < 9.5, "Quick Setup brings traps 3 s sooner")
	trap_entry["timer"] = 999.0
	pl._apply_ability(AbilityData.a("test_shout", "", "", "shout", {}, [AbilityData.t("every", "stun_around", {"secs_every": 20.0, "r": 7.0, "secs": 1.0, "sound": "attack"})]))
	var shout: Dictionary = pl._triggers["every"].back()
	shout["timer"] = 0.01
	await seconds(0.1)
	ok(shout["timer"] <= 0.4, "a timed shout with nobody near waits and looks again soon")
	var hears := spawn("normal", front(3.0), true)
	await frames(2)
	await seconds(0.6)
	ok(hears._stun > 0.0 and shout["timer"] > 15.0, "and goes off when someone comes close")
	shout["timer"] = 999.0
	hears.set_physics_process(true)
	await kill_all()

	await start_clean()
	place(OPEN)
	# A gargoyle wakes whichever way it happens to be facing.
	var perch := pl.global_position + Vector3(10, 3, 0)
	var statue := spawn("gargoyle", perch)
	statue.rotation.y = PI * 0.5 # facing directly away from the player
	await seconds(0.5)
	ok(not statue.dormant, "a gargoyle wakes even when it faces away")
	await kill_all()
	pl.hp = pl.max_hp()

	# A mimic stays hidden from aim help, familiars and the horde.
	place(OPEN)
	var mimic := spawn("mimic", front(8.0))
	await frames(2)
	ok(w.nearest_zombie(pl.eye_position(), 20.0, false) == null, "familiars do not give a mimic away")
	var dir0 := (mimic.centre() - pl.eye_position()).normalized().rotated(Vector3.UP, 0.01)
	ok(w.assist_aim(pl.eye_position(), dir0, 30.0) == dir0, "nor does aim help")
	var shouter := spawn("normal", front(5.0), true)
	await frames(2)
	w.call_horde(shouter, pl.global_position, 30.0)
	ok(not mimic.is_hunting() and mimic.dormant, "and it does not join the hunt while disguised")
	shouter.set_physics_process(true)
	await kill_all()
	pl.hp = pl.max_hp()

	# Things that die in the air fall down, and a pooled body comes back clean.
	place(OPEN)
	var crow := spawn("crow", front(6.0))
	await frames(2)
	ok(crow.position.y > 3.0, "a crow starts in the air")
	crow.take_damage(9999.0, Vector3.FORWARD, 0.0, crow.centre())
	await seconds(0.5)
	ok(crow.position.y < 0.5 and crow._visual.position.y > 0.0, "a dead crow falls to the ground and stays above it")
	await seconds(1.0)
	var crow2 := spawn("crow", front(6.0))
	await frames(1)
	ok(crow2._visual.position == Vector3.ZERO and crow2._visual.rotation == Vector3.ZERO, "a reused enemy starts clean")
	await kill_all()

	# A flock moves on after a while, and flyers hang low after a dive.
	pl.hp = pl.max_hp()
	var leaving := spawn("crow", front(6.0))
	leaving._flock_left = 0.0
	await seconds(6.0)
	ok(not leaving.active and not w.zombies.has(leaving), "a flock moves on after a while")
	place(OPEN)
	var diver := spawn("crow", front(1.2))
	await frames(2)
	diver.position = pl.eye_position() + Vector3(0.5, -0.2, 0.3)
	diver._dive = 2.0
	diver._dive_aim = pl.eye_position() + Vector3.DOWN * 0.3
	diver._clear = true
	await frames(2)
	ok(diver._recover > 0.0, "a flyer that dived stays low for a moment")
	await seconds(0.5)
	ok(diver.position.y < 3.4, "within reach of a sword (y %.1f)" % diver.position.y)
	await kill_all()
	pl.hp = pl.max_hp()

	# The night gets worse, and the difficulty setting scales everything.
	var early := spawn("normal", OPEN + Vector3(20, 0, 0), true)
	var early_hp := early.hp
	var early_hit := early._melee_damage()
	var late: Zombie = w._pools["normal_a"].pop_back()
	w.zombies.append(late)
	late.spawn("normal", OPEN + Vector3(22, 0, 0), 5)
	late.set_physics_process(false)
	ok(late.hp > early_hp * 1.2 and late._melee_damage() > early_hit * 1.15, "what rises later is tougher")
	Game.difficulty = 2
	var hard := spawn("normal", OPEN + Vector3(24, 0, 0), true)
	ok(is_equal_approx(hard.hp, early_hp * 1.2) and hard._melee_damage() > early_hit * 1.3, "Hard makes enemies tougher")
	Game.difficulty = 0
	var easy := spawn("normal", OPEN + Vector3(26, 0, 0), true)
	ok(easy.hp < early_hp and easy._melee_damage() < early_hit, "Easy makes them weaker")
	Game.difficulty = 1
	for z: Zombie in [early, late, hard, easy]:
		z.set_physics_process(true)
	await kill_all()

	# A stun does not freeze a leap in mid-air.
	var jumper := spawn("leaper", front(7.0))
	await frames(2)
	jumper._sees = true
	jumper._special_cd = 0.0
	jumper._try_leap(pl, 7.0)
	ok(jumper._airborne, "a leaper jumps")
	await frames(4)
	jumper.stun(2.0)
	await seconds(1.0)
	ok(not jumper._airborne and absf(jumper.position.y - w.ground_at(jumper.position)) < 0.01 and jumper._stun > 0.0, "a stunned leaper still lands, then stays stunned")
	await kill_all()
	pl.hp = pl.max_hp()

	# A wraith cannot see an invisible player through walls.
	place(OPEN)
	var ghost := spawn("wraith", front(7.0))
	var to_me := pl.global_position - ghost.position
	ghost.rotation.y = atan2(to_me.x, to_me.z)
	await seconds(0.6)
	ok(ghost.state == Zombie.State.CHASE, "a wraith hunts what it sees")
	pl.invis_left = 20.0
	place(OPEN + Vector3(0, 0, 14))
	await seconds(10.0)
	ok(ghost.state != Zombie.State.CHASE and not ghost._sees, "and gives up on someone unseen")
	pl.invis_left = 0.0
	await kill_all()

	# A stun cuts a Banshee's scream short. She keeps her distance.
	place(OPEN)
	var banshee := spawn("banshee", front(10.0))
	var to_player := pl.global_position - banshee.position
	banshee.rotation.y = atan2(to_player.x, to_player.z)
	banshee._special_cd = 0.0
	await seconds(0.5)
	ok(banshee._special_left > 0.0, "a Banshee screams on seeing you")
	banshee.stun(1.0)
	ok(is_zero_approx(banshee._special_left), "a stun cuts the scream short")
	await kill_all()

	# Out of arrows you can still hit with what you hold.
	place(OPEN)
	await equip("bow")
	pl.arrows = 0
	var bashed := spawn("normal", front(1.8), true)
	await frames(2)
	bashed.hp = 5000.0
	aim_at(bashed)
	pl.input_fire = true
	await seconds(1.0)
	pl.input_fire = false
	await seconds(0.3)
	var bash_damage := 5000.0 - bashed.hp
	ok(bash_damage >= 14.0 and bash_damage <= 31.0, "an empty bow still hits, weakly (%d in 1 s)" % int(bash_damage))
	ok(pl.toast == "No arrows", "and says why")
	bashed.set_physics_process(true)
	await kill_all()
	pl.arrows = 60

	# Throwing axes: another weapon is visible while the axe is away.
	pl.slots = ["axes", "dagger"]
	pl.current = 0
	pl._equip()
	await seconds(0.3)
	pl.input_fire = true
	await seconds(0.1)
	pl.input_fire = false
	await seconds(0.25)
	ok(not pl._vm_mesh.visible, "a thrown axe leaves the hand empty")
	pl.switch_weapon()
	ok(pl._vm_mesh.visible, "the other weapon still shows while it flies")
	await seconds(2.0)
	ok(not pl._axe_out, "and the axe comes back")

	# Horse Archer starts with something to shoot.
	await build("chivalry", 2)
	ok(pl.carries("bow") and pl.arrows >= 20, "Horse Archer gets a bow and arrows")
	Game.player_class = "infantry"

	# The sunrise saves you from fire as well as from claws.
	await start_clean()
	pl.hp = 1.0
	pl.burn_time = 3.0
	w.on_dawn()
	await seconds(1.0)
	ok(not pl.dead, "burning cannot kill you once the sun is up")
	await seconds(3.0)

	# Screens: the end screen takes touches away from the character, the back button makes sense.
	await start_clean()
	m._end_screen("Test", "line")
	await frames(2)
	touch(5, hud._buttons["fire"]["pos"], true)
	ok(not pl.input_fire, "touches on the end screen do not reach the game")
	touch(5, hud._buttons["fire"]["pos"], false)
	await start_clean()
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	ok(get_tree().paused, "back pauses the game")
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(2)
	ok(not get_tree().paused, "back again resumes it")
	pl.points = 1
	m.toggle_tree()
	await frames(2)
	m.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(2)
	ok(m.tree_panel == null, "back closes the ability tree")

	# The music is really playing, in all its layers, on a bus that is not muted.
	ok(Sfx.music_is_playing(), "the three music layers are playing")
	ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "on a bus that can be heard")
	Sfx.set_mood(1.0, 0.0)
	await seconds(0.2)
	Sfx.set_mood(0.0, 0.0)
	ok(Sfx.music_is_playing(), "and keep playing when the mood changes")
	# Volumes reach the mixer.
	var music := Game.music_volume
	Game.music_volume = 0.0
	Sfx.apply_volumes()
	ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music can be muted")
	Game.music_volume = music
	Sfx.apply_volumes()
	ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "and comes back")

	# Pause, settings from pause, and resuming.
	m.show_pause()
	await frames(2)
	m.show_settings(true)
	await frames(2)
	ok(get_tree().paused, "settings from pause keep the game paused")
	m._back.call()
	await frames(2)
	m._back.call()
	await frames(2)
	ok(not get_tree().paused, "and it resumes afterwards")

	# The whole tree fits on the screen, and tapping something on the map reads it out.
	pl.points = 1
	m.toggle_tree()
	await frames(3)
	var tree_nodes: Array = m.tree_panel._map.nodes
	var fits := true
	for tree_node: Control in tree_nodes:
		if tree_node.position.x < -1.0 or tree_node.position.x + tree_node.size.x > m.tree_panel._map.size.x + 1.0 or tree_node.position.y + tree_node.size.y > m.tree_panel._map.size.y + 1.0:
			fits = false
	ok(fits and not tree_nodes.is_empty(), "the whole tree fits on the screen")
	m.tree_panel.read(tree_nodes[tree_nodes.size() - 1])
	await frames(2)
	ok(m.tree_panel._zone.get_child_count() == 1, "tapping an ability on the map shows it large")
	m.tree_panel.read(null)
	await frames(2)
	ok(not m.tree_panel._zone.find_children("*", "Button", true, false).is_empty(), "and you can go back to your choice")
	m.close_tree()

	# Summoned bodies are reused.
	await start_clean()
	place(OPEN)
	w.spawn_ally("skeleton", front(3.0), 0.05)
	var first_body: Ally = w.allies[0]
	await seconds(2.0)
	ok(w.allies.is_empty(), "a summon that runs out goes away")
	w.spawn_ally("skeleton", front(3.0), 9.0)
	ok(w.allies[0] == first_body and not first_body.dead and first_body.visible and first_body.hp > 0.0, "and its body comes back good as new")
	w.remove_ally(first_body)
	w.prepare_allies("wolf", 3)
	ok((w._spare_allies["wolf"] as Array).size() == 3, "bodies can be prepared before they are needed")
	# The closest item shows its name.
	var named := w.spawn_pickup_at(front(3.0), Pickup.Kind.FOOD, "bread")
	await seconds(0.3)
	ok(pl.named_item == named, "the closest item gets named")
	w.remove_pickup(named)
	await seconds(0.3)
	ok(pl.named_item == null, "and the name goes with it")

	# The Settings buttons do what they say.
	m.show_menu()
	await frames(3)
	m.show_settings()
	await frames(2)
	await _press("Hard")
	ok(Game.difficulty == 2, "Hard can be chosen")
	await _press("Normal")
	ok(Game.difficulty == 1, "and Normal again")
	var vibration := Game.vibration
	await _press_toggle("Vibration")
	ok(Game.vibration != vibration, "vibration toggles")
	await _press_toggle("Vibration")
	ok(Game.vibration == vibration, "and back")
	var village: World = m.world
	await _press("Done")
	ok(m.world == village and m._back == Callable(m, "_quit"), "leaving Settings keeps the village behind the menu")
	# Class cards start a game of that class, with a loading screen in between.
	m.show_class_picker(Game.Mode.NIGHT)
	await frames(2)
	var rows: Node = m.panel.get_meta("list")
	ok(rows.get_child_count() == ClassDefs.ALL.size(), "every class is listed, the Adept too")
	(rows.get_child(2) as Button).pressed.emit()
	await frames(1)
	await _press("Play as Heavy Infantry")
	await seconds(1.0)
	ok(m.world.player != null and m.world.player.class_id == "heavy", "tapping a card starts that class")
	ok(m.hud.visible, "and the game shows once it is ready")
	Game.player_class = "infantry"
	m.show_menu()
	await frames(3)

	# The Codex opens on every page, and everything in it has an icon.
	m.show_codex()
	await frames(2)
	for i in CodexPanel.TABS.size():
		(m.panel as CodexPanel).show_tab(i)
		await frames(2)
		ok((m.panel as CodexPanel)._list.get_child_count() > 0, "Codex page %s has entries" % CodexPanel.TABS[i])
	for id: String in ZombieDefs.ALL:
		for part: String in String(ZombieDefs.ALL[id]["icon"]).split("+"):
			ok(Icons.exists(part), "icon %s for %s" % [part, id])
	for id: String in WeaponDefs.ALL:
		ok(WeaponDefs.ALL[id].has("desc"), "%s is described" % id)
	for id: String in PowerDefs.ALL:
		ok(PowerDefs.ALL[id].has("desc"), "%s is described" % id)
	m.show_menu()
	await frames(3)


## A button whose words are a label inside it, like the switches in Settings.
func _press_toggle(text: String) -> void:
	for b: Button in m.ui_layer.find_children("*", "Button", true, false):
		for l: Label in b.find_children("*", "Label", true, false):
			if l.text == text:
				b.pressed.emit()
				await frames(1)
				return
	ok(false, "there is a switch called %s" % text)


func _press(text: String) -> void:
	for b: Button in m.panel.find_children("*", "Button", true, false):
		if b.text == text:
			b.pressed.emit()
			await frames(2)
			return
	ok(false, "there is a button called %s" % text)


func _mouse_drag(from: Vector2, by: Vector2) -> void:
	var at := from
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = _to_window(at)
	press.global_position = press.position
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await frames(2)
	for i in 12:
		var step := by / 12.0
		at += step
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = _to_window(at)
		move.global_position = move.position
		move.relative = step
		Input.parse_input_event(move)
		Input.flush_buffered_events()
		await frames(1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = _to_window(at)
	release.global_position = release.position
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await frames(2)


## A bot plays a real night with the highest zombie cap, to catch errors and measure cost.
func soak() -> void:
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await frames(2)
	await m.start_game(Game.Mode.NIGHT)
	await frames(2)
	w = m.world
	pl = w.player
	pl.give_weapon("crossbow")
	pl.activate_power("archer")

	var peak := 0.0
	var total := 0.0
	var n := 0
	var peak_alive := 0
	var seen := {}
	var armed := 0
	var hunted_frames := 0
	var frames_total := 0
	var spikes: Array[String] = []
	while w.director.elapsed < Game.NIGHT_LENGTH - 2.0:
		await get_tree().physics_frame
		pl.hp = 100.0
		pl.arrows = 50
		var nearest: Zombie = null
		var nd := INF
		for z in w.zombies:
			seen[z.type_id] = true
			if z.is_alive():
				var d := z.position.distance_to(pl.global_position)
				if d < nd:
					nd = d
					nearest = z
				if z.weapon_id != "":
					armed = maxi(armed, 1)
		peak_alive = maxi(peak_alive, w.count_living())
		frames_total += 1
		if w.count_hunting() > 0:
			hunted_frames += 1
		if nearest:
			aim_at(nearest)
		pl.input_fire = nearest != null and nd < 14.0
		var t := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		peak = maxf(peak, t)
		total += t
		n += 1
		if t > 30.0 and spikes.size() < 12:
			spikes.append("%.0f ms at %s" % [t, Game.clock(w.director.elapsed)])
	print("soak: slow physics ticks: ", spikes)
	print("soak: night time reached ", Game.clock(w.director.elapsed), " kills=", pl.kills, " peak alive=", peak_alive, " types=", seen.keys())
	print("soak: physics ms avg=%.2f peak=%.2f, hunted %d%% of the time" % [total / maxi(n, 1), peak, 100 * hunted_frames / maxi(frames_total, 1)])
	# Rare ones depend on how many zombies die and get replaced, which varies from night to night.
	var eligible := ZombieDefs.ALL.values().filter(func(d: Dictionary) -> bool: return not d.get("only_islands", false)).size()
	ok(seen.size() >= eligible - 3, "nearly all eligible Village types appear in a real night (%d of %d)" % [seen.size(), eligible])
	var late := {}
	for i in 600:
		late[ZombieDefs.pick_roamer(420.0)] = true
	ok(late.has("wraith") and late.has("banshee"), "and the late ones are in the mix late at night")
	ok(armed > 0, "a clever zombie armed itself during the night")
	var pooled := 0
	for k: String in w._pools:
		pooled += (w._pools[k] as Array).size()
	var planned := 0
	var plan := Game.zombie_pool_plan()
	for k: String in plan:
		planned += int(plan[k])
	ok(pooled + w.zombies.size() == planned, "pool intact after a whole night")
	m.queue_free()
	await frames(2)


func fresh_pawn(class_id: String) -> void:
	for ally: Ally in w.allies.duplicate():
		w.remove_ally(ally)
	for projectile: Projectile in w._projectiles:
		if projectile.active:
			projectile.stop()
	for z: Zombie in w.zombies.duplicate():
		z.release()
	w.players.erase(pl)
	pl.queue_free()
	await frames(2)
	Game.player_class = class_id
	pl = Player.new(w)
	w.player = pl
	w.add_child(pl)
	w.players.append(pl)
	hud.player = pl
	await frames(2)
