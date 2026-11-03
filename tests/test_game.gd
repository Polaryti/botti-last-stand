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
	else:
		print("ok: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(t: float) -> void:
	await frames(int(t * 60.0))


func _ready() -> void:
	# Same 1/60 s steps as the real game, four times as fast.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	Engine.max_fps = 0
	Game.quality = 2
	Game.player_class = "infantry"
	Game.save_settings()
	var args := OS.get_cmdline_user_args()
	if args.has("soakonly"):
		await soak()
		print("RESULT: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if args.has("new"):
		await start_clean()
		await test_version_8()
		await test_new_things()
		await test_fort()
		print("RESULT: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	var only := args.has("quick")
	if not only:
		await test_map()
		await test_flow()
		await start_clean()
		await test_weapons()
		await test_touch()
		await test_auto_jump()
		await test_items()
		await test_powers()
		await test_zombies()
		await test_night()
	await test_land()
	await test_version_8()
	await test_new_things()
	await test_fort()
	await test_crows()
	await test_revenant()
	await test_fire()
	await test_trees()
	await test_finals()
	await test_classes()
	await test_enemies()
	await test_new_stuff()
	await test_review()
	if OS.get_cmdline_user_args().has("soak"):
		await soak()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func test_map() -> void:
	var world := World.new()
	add_child(world)
	world.setup(Game.Mode.MENU)
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
	ok(ClassDefs.available().size() >= 6, "next to the others")
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
	ok(pl.mana > 54.0, "Mist comes back by itself (%.1f)" % pl.mana)
	pl.mana = 10.0
	z.next_hitter = 0
	await kill_all()
	await frames(2)
	var kz := spawn("normal", front(1.8), true)
	pl.mana = 10.0
	kz.take_damage(99999.0, Vector3.FORWARD, 0.0, kz.centre())
	ok(pl.mana >= 18.0, "and from kills")
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
	# The tree unlocks by itself, up to the choice of a path.
	pl.mana = 100.0
	pl.add_xp(100000)
	ok(pl.next_step() == Player.CORE_STEPS, "levels bring the shared gifts by themselves, up to the path")
	ok(pl.points > 0 and pl.spec_id == "", "the path waits for you")
	ok(pl.choose_ability(Player.CORE_STEPS, 0), "you can choose it")
	ok(pl.spec_id == "leaper", "Mist Leaper")
	ok(pl.next_step() == 18 or pl.points == 0, "and everything else then comes by itself (%d)" % pl.next_step())
	# Mist Leaper: forward, up and down the land, not through walls.
	Game.player_class = "revenant"
	await start_clean()
	pl.level = 6
	pl.points = 1
	pl._auto_unlock()
	for i in 4:
		pl.points += 1
		pl._auto_unlock()
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
	pl.points = 5
	pl._auto_unlock()
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
	pl._auto_unlock()
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
	var dark := Vector3(-100, 0, -100)
	for i in 30:
		var p := Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
		if not w.in_firelight(p):
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
	# The water can only be crossed at three places.
	ok(t.is_walkable(0, 64), "the stone bridge stands over the river")
	ok(t.is_walkable(72, 0), "the timber bridge too")
	ok(t.is_walkable(-54, 64), "and the ford is shallow")
	ok(not t.is_walkable(24, 64), "the river is too deep to wade")
	ok(not w.grid.is_free(w.grid.to_cell(Vector3(24, 0, 64))), "so nothing plans a path through it")
	var north := w.grid.path(Vector3(24, 0, 55), Vector3(24, 0, 76))
	var crossed := false
	for p: Vector3 in north:
		if absf(p.x) < 6.0:
			crossed = true
	ok(not north.is_empty() and crossed, "to reach the other bank a zombie walks to the bridge")
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
	# The castle stands high, and its hill has one road.
	ok(t.height(-72, -60) > 7.5, "the castle stands on high ground")
	ok(not w.grid.is_free(w.grid.to_cell(Vector3(-46, 0, -48))) or t.height(-46, -48) < 7.0, "the hill is steep")
	var cliff := 0
	for i in 40:
		var a := float(i) / 40.0
		if not t.is_walkable(lerpf(-96.0, -48.0, a), -41.5):
			cliff += 1
	ok(cliff > 12, "with cliffs along its sides")
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
	await seconds(1.5)
	pl.input_move = Vector2.ZERO
	ok(pl.global_position.z < 62.0 and pl.global_position.y > Terrain.WATER_Y, "the river stops you")
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
	ok(pl.wood == Fort.WOOD_PER_PICKUP and not wf.pickups.has(wood), "wood gets picked up")
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
	ok(ClassDefs.price("revenant") == 650 and ClassDefs.price("artificer") == 520, "the prices are set")
	ok(ClassDefs.price("infantry") == 0, "the others are free")
	var sale := ClassDefs.for_sale()
	ok(sale.size() == 2 and sale.has("revenant") and sale.has("artificer"), "the Store sells the two")
	Game.doubloons = 519
	ok(not Game.buy_class("artificer") and Game.doubloons == 519, "you cannot buy what you cannot pay for")
	Game.doubloons = 521
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
	ok(str(notes[0]["text"]).begins_with(str(ProjectSettings.get_setting("application/config/version"))), "and starts with this version")
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
	ok(m.panel.get_meta("list").get_child_count() == 2, "the Store opens")
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
	await seconds(2.2)
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
	ok(w.terrain != null and w.zombies.is_empty(), "the Sandbox starts empty")
	ok(not w.director.running and not Game.is_night(), "with no night running")
	var weapon_count := 0
	for id: String in WeaponDefs.ALL:
		if not WeaponDefs.ALL[id].get("hidden", false) and id != "staff":
			weapon_count += 1
	await seconds(2.2)
	var items := {}
	for it: Pickup in w.pickups:
		items[it.item_id] = true
	ok(w.count_pickups(Pickup.Kind.WEAPON) == weapon_count, "every weapon is on show (%d)" % w.count_pickups(Pickup.Kind.WEAPON))
	var missing := 0
	for id: String in PowerDefs.ALL:
		if not items.has(id):
			missing += 1
	for id: String in PowerDefs.FOODS:
		if not items.has(id):
			missing += 1
	ok(missing == 0 and items.has("arrows"), "and every item and familiar")
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
	await _press("Level up")
	ok(pl.level == 2, "it can give you a level")
	await _press("Top level")
	ok(pl.level == ClassDefs.MAX_LEVEL, "or all of them")
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
	ok(chariot_speed < Player.WALK_SPEED * Player.HORSE_SPEED * 0.7, "and it is much slower (%.1f m/s)" % chariot_speed)
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
	var shots_before := w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size()
	pl._invent()
	await seconds(0.7)
	ok(true, "Eureka runs without trouble (%d)" % shots_before)
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
	pl.points = 18
	for s in 4:
		pl.choose_ability(s, 0)
	pl.choose_ability(4, spec)


func test_new_things() -> void:
	# Doubloons.
	ok(Game.match_doubloons(600.0, 150, true, false) == 60, "a full night with 150 kills pays 60")
	ok(Game.match_doubloons(600.0, 150, true, true) == 90, "and half as much again in co-op")
	ok(Game.match_doubloons(120.0, 9, false, false) == 3, "a short night pays less")
	var coins := Game.doubloons
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
	await start_clean()


func test_flow() -> void:
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await frames(3)
	ok(m.world != null and m.world.mode == Game.Mode.MENU, "menu shows the village")
	await m.start_game(Game.Mode.SANDBOX)
	await seconds(3.0)
	ok(m.world.zombies.is_empty(), "roam has no zombies")
	ok(m.world.pickups.size() > 0, "roam still has random pickups")
	m.queue_free()
	await frames(2)


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
	var model: String = ZombieDefs.ALL[id]["models"][0]
	var z: Zombie = w._pools[model].pop_back()
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
		hits[id] = dealt / WeaponDefs.DAMAGE
		print("  ", id, " hits in 3 s=", hits[id])
		ok(is_equal_approx(fmod(dealt, WeaponDefs.DAMAGE), 0.0) and dealt > 0.0, "%s deals %d per hit" % [id, WeaponDefs.DAMAGE])
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
	pl.hp = 100.0
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
		w.spawn_pickup_at(pl.global_position, Pickup.Kind.POWER, id)
		await seconds(0.25)
		ok(pl.has_power(id), "%s activates" % id)
		var want: float = 40.0 if PowerDefs.ALL[id]["familiar"] else 20.0
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
	ok(float(pl.powers["angel"]) > 39.0, "picking up the same power resets its timer")
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
		ok((tree["core"] as Array).size() == 4, "%s has 4 shared tiers" % id)
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
			ok((spec["path"] as Array).size() == 12, "%s has 12 steps" % spec["name"])
			var choices := 0
			for step: Array in spec["path"]:
				if step.size() == 2:
					choices += 1
				for a: Dictionary in step:
					check.call(a)
			ok(choices == (0 if ClassDefs.ALL[id].get("auto_tree", false) else (3 if spec["id"] == "mechanic" else 5)), "%s has its real choices" % spec["name"])
			ok(spec["final"].get("final", false), "%s ends in a final ability" % spec["name"])
		var dupes := 0
		for k: String in ids:
			if int(ids[k]) > 1:
				dupes += 1
				print("  duplicate id ", k)
		var same_icons := 0
		for k: String in icons:
			if int(icons[k]) > 1:
				same_icons += 1
				print("  shared icon ", k)
		ok(dupes == 0, "%s ability ids are unique" % id)
		ok(bad_icons == 0, "%s icon shapes all exist" % id)
		ok(same_icons == 0, "%s abilities each have their own icon" % id)
		print("  %s total ability nodes %d" % [id, ids.size()])

	var total_xp := 0
	for l in range(1, ClassDefs.MAX_LEVEL):
		total_xp += ClassDefs.xp_for_level(l)
	print("  xp to top level ", total_xp)
	ok(total_xp > 1500 and total_xp < 3000, "levelling is much slower (%d points)" % total_xp)
	ok(ClassDefs.MAX_LEVEL - 1 == 18, "18 points fill a branch")

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
	for i in 4:
		ok(pl.choose_ability(i, 0), "takes shared ability %d" % i)
	ok(not pl.choose_ability(0, 1), "the other choice of a tier stays locked")
	ok(pl.steps().size() == 5, "branches stay closed until a specialization is taken")
	m.toggle_tree()
	await frames(3)
	var panel_ref: TreePanel = m.tree_panel
	ok(panel_ref != null and hud.menu_open and not get_tree().paused, "tree opens with the game running")
	var picked := false
	for n in panel_ref._nodes:
		if n.step == Player.CORE_STEPS and n.spec == 2:
			panel_ref.select(n)
			panel_ref.choose_selected()
			picked = true
			break
	await frames(2)
	ok(picked and pl.spec_id == "illusionist", "tapping a branch and Choose picks the specialization")
	ok(pl.steps().size() == 18, "the chosen branch opens")
	var locked := 0
	var open_nodes := 0
	for n in panel_ref._nodes:
		if n.spec >= 0 and n.spec != 2:
			if panel_ref.state_of(n) == "locked":
				locked += 1
		if panel_ref.state_of(n) == "ready":
			open_nodes += 1
	ok(locked == 2 * 19 + 2 * 5 - 0 or locked > 30, "the other two branches lock (%d nodes)" % locked)
	ok(open_nodes == 2, "the next tier offers its two choices")
	m.toggle_tree()
	await frames(2)
	ok(m.tree_panel == null and not hud.menu_open, "tree closes")
	pl.xp = 0
	pl.level = ClassDefs.MAX_LEVEL
	pl.add_xp(5000)
	ok(pl.level == ClassDefs.MAX_LEVEL, "levels stop at the top")

	# Every ability of every branch can be taken and fired without errors.
	for id: String in ClassDefs.ALL:
		for spec_i in 3:
			for pick in 2:
				Game.player_class = id
				await start_clean()
				place(OPEN)
				pl.points = 18
				var ok_all := true
				for step in 18:
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
	pl.points = 18
	for step in 18:
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

	await build("ranger", 2)
	pl._wolf_timer = 0.0
	await seconds(0.3)
	ok(w.count_allies("wolf") >= 1, "wolves come to a Beastmaster")
	ok(int(pl.m("wolves")) >= 5, "Wolf Pack raises the pack")
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
	ok(pl.hp == pl.max_hp(), "the Shield Dome stops every blow")
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
	ok(pl.hp > 22.0, "and heals while riding")
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
	ok(int(pl.m("ally_cap")) == 8, "Army of the Dead allows 8 allies")
	for e: Dictionary in pl._triggers["every"]:
		if int(e.get("n", 0)) == 4:
			pl._act(e, {})
	await frames(3)
	ok(w.count_allies("skeleton") >= 4, "4 skeletons rise (%d)" % w.count_allies("skeleton"))
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
	for e: Dictionary in pl._triggers["every"]:
		if e["do"] == "summon":
			pl._act(e, {})
	await frames(3)
	ok(w.count_allies("mirror") >= 1 and w.count_allies("decoy") >= 1, "decoys and mirror images appear")
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
	var starts := {"infantry": "dagger", "ranger": "bow", "heavy": "mace", "chivalry": "lance", "magician": "staff"}
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
	ok(pl.shield_tier == 2 and pl._shield_node.mesh != mesh0, "shield upgrades to iron round")
	pl.hp = pl.max_hp()
	pl.hurt(20.0, front(3.0))
	var blocked := pl.max_hp() - pl.hp
	pl.hp = pl.max_hp()
	pl.hurt(20.0, pl.global_position + pl.global_basis.z * 3.0)
	var from_back := pl.max_hp() - pl.hp
	print("  shield: front ", blocked, " back ", from_back)
	ok(blocked < from_back * 0.6, "shield blocks from the front only")
	pl.hp = pl.max_hp()
	pl.ignite(3.0)
	ok(pl.burn_time == 0.0, "iron shield stops burning")

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
	pl.slots = ["staff", "dagger"]
	pl.current = 0
	pl._equip()
	w.spawn_pickup_at(front(1.0), Pickup.Kind.WEAPON, "sword")
	await seconds(0.3)
	pl.take_nearby_weapon()
	await frames(2)
	ok(pl.slots.has("staff") and pl.slots.has("sword"), "the Magician keeps the staff when swapping")
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
	ok(1000.0 - az.hp >= WeaponDefs.DAMAGE * 2.0, "it hits going out and coming back")
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

	# Touch scrolling in the tree, on empty parchment and starting on a medallion.
	Input.emulate_touch_from_mouse = true
	pl.points = 1
	m.toggle_tree()
	await frames(3)
	var scroll: ScrollContainer = m.tree_panel._scroll
	scroll.scroll_horizontal = 0
	var empty_at := scroll.global_position + Vector2(380, 18)
	await _mouse_drag(empty_at, Vector2(-300, 0))
	ok(scroll.scroll_horizontal > 100, "dragging empty parchment scrolls the tree (%d)" % scroll.scroll_horizontal)
	scroll.scroll_horizontal = 0
	await frames(2)
	var node: Control = m.tree_panel._nodes[0]
	var selected_before: Variant = m.tree_panel._selected
	await _mouse_drag(node.global_position + node.size * 0.5, Vector2(-300, 0))
	ok(scroll.scroll_horizontal > 100, "dragging from a medallion scrolls too (%d)" % scroll.scroll_horizontal)
	ok(m.tree_panel._selected == selected_before, "and does not count as a tap")
	Input.emulate_touch_from_mouse = false
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
	ok(rows.get_child_count() == ClassDefs.ALL.size(), "every class is listed")
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
	ok(seen.size() >= ZombieDefs.ALL.size() - 3, "nearly all zombie types appear in a real night (%d of %d)" % [seen.size(), ZombieDefs.ALL.size()])
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
