extends Node
## Targeted behavior checks for the combat rework and persistent online score snapshots.

var checks := 0
var failures := 0
var w: World
var p: Player


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", description)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	seed(81731)
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	Game.confirm_name("Test Player")
	Game.quality = 0
	Game.force_weather = Weather.Kind.CLEAR
	Game.mode = Game.Mode.NIGHT
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate():
		z.release()
	p = w.player
	print("REWORK adept")
	await _adept()
	print("REWORK commander")
	await _commander()
	print("REWORK statuses")
	_statuses()
	print("REWORK progress")
	_progress()
	print("REWORK online")
	await _online()
	Net.leave()
	w.queue_free()
	await frames(2)
	await _exploration()
	Sfx.stop_all()
	OS.delay_msec(120) # allow the audio mixing thread to release stopped playback
	await get_tree().create_timer(0.1, true, false, true).timeout
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func pawn(cls: String, spec := -1, final := false) -> void:
	for ally: Ally in w.allies.duplicate():
		w.remove_ally(ally)
	for projectile: Projectile in w._projectiles:
		projectile.stop()
	for z: Zombie in w.zombies.duplicate():
		z.release()
	w.players.erase(p)
	p.free()
	Game.player_class = cls
	p = Player.new(w)
	w.player = p
	w.add_child(p)
	w.players.append(p)
	p.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 36)) + 0.05, 36)
	p.guard_left = 0.0
	if spec >= 0:
		p.points = 9
		p.level = 10 if final else 5
		for step in (9 if final else 4):
			check(p.choose_ability(step, spec if step == 3 else 0), "build %s step %d" % [cls, step])


func target(at: Vector3) -> Zombie:
	w.spawn_zombie("normal", at)
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	z.hp = 10000.0
	z.max_hp = 10000.0
	return z


func _adept() -> void:
	pawn("adept", 0)
	p.use_art()
	check(p.stance == "wind" and p._cast_kind == "stance", "stance change has a wind-up")
	await frames(22)
	check(p.stance == "stone", "stance changes after the wind-up")
	var cd := p.art_cd_left
	p.use_art()
	await frames(2)
	check(p.stance == "stone" and p.art_cd_left <= cd, "repeated input cannot skip a committed stance")
	check(cd > 5.0, "base commitment is six seconds")
	p.mods["art_cd"] = 0.01
	p.art_cd_left = 0.0
	p.use_art()
	check(p.art_cd_left >= 3.5, "cooldown reductions respect the commitment floor")
	await frames(22)
	var z := target(p.global_position + Vector3(0, 0, -1.5))
	for i in 3:
		p._do_melee_hit()
	check(p.stance_hits == 3 and p._stance_mastered, "three connected attacks build full transition rhythm and sustained damage")
	p.art_cd_left = 0.0
	p.use_art()
	await frames(22)
	check(p._transition_power == 1.6 and p.stance_hits == 0, "empowered transition consumes its rhythm")
	pawn("adept", 1)
	p.hp = 70.0
	p.hurt(20.0, p.global_position)
	p.use_art()
	await frames(22)
	check(p.hp >= 79.0 and p.mirror_guard_left > 0.0, "Mirror Step undoes a timed hit and opens a defensive window")
	var hp := p.hp
	p.hurt(20.0, p.global_position)
	check(hp - p.hp < 10.0, "Mirror protection reduces incoming damage")
	pawn("adept", 2, true)
	p._void_hits = {"wind": true, "stone": true, "flame": true}
	p.use_art()
	await frames(22)
	check(p.stance == "void" and p.void_left > 0.0, "Void opens after earning the stance sequence")
	z = target(p.global_position + Vector3(0, 0, -2))
	for i in 20:
		p.on_kill(z)
	check(p._void_extensions == 6 and p.void_left < 14.0, "Void kill extensions are bounded")


func _commander() -> void:
	Net.roster = {1: {"class": "commander"}, 2: {"class": "infantry"}}
	check(Net.class_slot_available("commander", 1), "Commander keeps its own reservation")
	check(not Net.class_slot_available("commander", 2), "second Commander reservation is rejected")
	check(not Net.class_slot_available("commander", Net.BOT_BASE), "bots can never reserve Commander")
	Net.roster.erase(1)
	check(Net.class_slot_available("commander", 2), "disconnect releases Commander reservation")
	Net.roster.clear()
	for weapon: String in ["war_staff", "musket"]:
		check(not WeaponDefs.lies_around(weapon), "%s cannot be map loot" % weapon)
		var before := w.pickups.size()
		w.drop_weapon(p.global_position, weapon)
		check(w.pickups.size() == before, "%s cannot be dropped" % weapon)
	pawn("infantry")
	check(not p.can_use("war_staff") and not p.can_use("musket") and not p.can_use("staff"), "exclusive weapons reject another class")
	pawn("commander", 0)
	check(p.weapon_id() == "war_staff" and p.slots[1] == null and not p.can_drop_weapon(), "Warlock has one permanent War Staff")
	check(not p.can_use("bow") and p.max_hp() < 110.0, "Warlock is fragile and cannot replace its weapon")
	for i in 5:
		p._cooldown = 0.0
		p.input_fire = true
		p._handle_fire()
		p._melee_pending = -1.0
		check(w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size() == (1 if i == 4 else 0), "War Staff attack %d has correct melee/magic cadence" % (i + 1))
	p.input_fire = false
	p.use_art()
	await frames(32)
	check(w.count_allies("magician") == 1, "Warlock Command summons a temporary Magician")
	pawn("commander", 1)
	check(p.weapon_id() == "musket" and not p.can_use("sword"), "Gunner has one permanent Musket")
	await frames(15)
	p.use_bayonet()
	check(p._bayonet_pending and p._cooldown > 0.0, "Musket can thrust with its bayonet")
	p.use_art()
	await frames(32)
	check(w.count_allies("gunner") == 1, "Gunner Command summons a torch-bearing Gunner")
	pawn("commander", 2)
	check(p._banner != null and p.max_hp() >= 140.0, "Vanguard has a banner and defensive health")
	p.use_art()
	await frames(32)
	check(p.m("speed") >= 1.25 and p._buffs.has("command_speed"), "Vanguard Command grants a timed speed buff")
	pawn("commander", 2, true)
	p.hp = 20.0
	p.use_art()
	await frames(32)
	check(w.count_allies("infantry") == 2 and p.hp > 50.0 and p.m("melee_damage") > 1.3, "Vanguard Last Command heals, buffs and calls two Infantry")
	pawn("commander", 1, true)
	p.use_art()
	check(p.art_cd_left == 0.0 and p._cast_kind == "", "opening target selection spends no cooldown")
	p.command_target = p.global_position + Vector3(0, 0, -8)
	p.command_target_ready = true
	p.use_art()
	await frames(32)
	var fields := w.get_children().filter(func(n: Node) -> bool: return n is CommandField)
	check(fields.size() == 1 and w.director.banner == "The Commander has called in an artillery barrage", "barrage starts with the global warning")
	var barrage: CommandField = fields[0]
	var z := target(barrage.global_position)
	var hp := z.hp
	barrage.set_physics_process(false)
	barrage.elapsed = 0.0
	barrage._physics_process(CommanderKit.BARRAGE_DELAY - 0.01)
	check(z.hp == hp, "artillery cannot damage before the four-second warning")
	for i in 20:
		barrage._physics_process(0.25)
	check(z.hp < hp, "artillery rains during its five-second window")
	barrage._physics_process(0.25)
	check(not barrage.is_queued_for_deletion() and barrage._fires.size() == 20, "twenty shells leave fire after the five-second barrage")
	var fire_at: Vector3 = barrage._fires[-1]["at"]
	z.global_position = fire_at
	p.global_position = fire_at
	p.hp = 50.0
	var before_fire := z.hp
	barrage._fires.append(barrage._fires[-1].duplicate())
	barrage._fire_tick = 0.0
	barrage._tick_fire(0.5, true)
	check(is_equal_approx(before_fire - z.hp, CommanderKit.FIRE_DPS * 0.5), "overlapping fire applies one damage tick and credits the Commander")
	check(p.hp == 50.0, "artillery fire leaves its allied Commander unharmed")
	before_fire = z.hp
	barrage._fire_tick = 0.0
	barrage._tick_fire(0.5, false)
	check(z.hp == before_fire, "client visual fire cannot apply damage")
	barrage._physics_process(CommanderKit.FIRE_TIME)
	check(barrage.is_queued_for_deletion(), "field is cleaned after the final eight-second fire")
	await frames(2)
	pawn("commander", 0, true)
	p.use_art()
	await frames(32)
	fields = w.get_children().filter(func(n: Node) -> bool: return n is CommandField)
	check(fields.size() == 1, "Warlock Last Command creates a storm")
	var storm: CommandField = fields[0]
	z = target(p.global_position + Vector3(2, 0, 0))
	hp = z.hp
	storm._strike = 0.0
	storm._pulse = 0.0
	storm._physics_process(0.51)
	check(z.hp < hp and z._slow > 0.0, "storm slows enemies and calls damaging lightning")
	var player_hp := p.hp
	storm._impact(p.global_position, 5.0, 35.0)
	check(p.hp == player_hp, "Commander storm cannot hurt its caster")
	p.dead = true
	storm._physics_process(0.1)
	check(storm.is_queued_for_deletion(), "storm ends when the Warlock dies")
	await frames(2)


func _statuses() -> void:
	pawn("plague_doctor", 1)
	var z := target(p.global_position + Vector3(2, 0, 0))
	z.add_dot(18.0, 5.0)
	z.add_dot(12.0, 5.0)
	check(z._poison_dps == 18.0, "weaker dart poison cannot overwrite Virulence")
	z.add_dot(8.0, 3.0, true)
	check(z._poison_dps == 18.0 and z._bleed_dps == 8.0, "bleeding and poison use independent channels")
	var hp := z.hp
	z._tick_dot(5.0)
	check(is_equal_approx(hp - z.hp, (18.0 * 5.0 + 8.0 * 3.0) * 1.05), "damage integrates exactly over both status lifetimes")
	hp = z.hp
	z._tick_dot(1.0)
	check(z.hp == hp, "expired statuses deal no extra tick")
	check(p.max_hp() >= 105.0 and p.m("damage_taken") < 1.0, "Plague Doctor has improved baseline durability")


func _progress() -> void:
	check(not Game.valid_sync_snapshot({"points": "broken"}), "malformed pending score snapshots are rejected")
	for cls: String in ClassDefs.ALL:
		check(Scores.PAIRS.has(cls + "|"), "leaderboard tracks unspecialised " + cls)
		for spec: Dictionary in AbilityData.tree(cls)["specs"]:
			check(Scores.PAIRS.has(cls + "|" + str(spec["id"])), "leaderboard tracks " + str(spec["id"]))
	Game.name_schema = 0
	Game.player_name = "Old generated name"
	check(Game.needs_name(), "existing installations get a one-time name prompt")
	check(not Game.confirm_name(" \n\t"), "blank names cannot bypass the prompt")
	check(Game.confirm_name("  Mara  ") and not Game.needs_name(), "confirming a valid name completes migration")
	check(Game.confirm_name("Mara"), "duplicate display names are allowed")
	check(Game.clean_name("A\nB\tC") == "ABC", "network names strip control characters")
	Game.mode = Game.Mode.NIGHT
	Game.begin_run()
	var before := Game.total_points
	Game.run_profession = "pestilence"
	check(Game.award_doubloons(600, 150, true, false) == 60 and Game.total_points == before + 60, "lifetime points use the match reward formula")
	check(Game.award_doubloons(600, 150, true, false) == 0 and Game.total_points == before + 60, "duplicate match-end callbacks cannot duplicate points")
	Game.mode = Game.Mode.SANDBOX
	Game.begin_run()
	check(Game.award_doubloons(600, 150, true, false) == 0, "Sandbox awards no points")
	check(Scores.favourite({"plague_doctor|pestilence": 3, "infantry|duelist": 1}) == "plague_doctor|pestilence", "favourite uses the most-played class-profession pair")
	Game.total_points = 5
	Game.pending_points = 5
	Game.class_plays = {"infantry|duelist": 1}
	Game.pending_plays = Game.class_plays.duplicate()
	var snapshot := Scores.make_snapshot(100, {"infantry|duelist": 4})
	check(snapshot["points"] == 105 and snapshot["plays"]["infantry|duelist"] == 5, "offline progress merges with an existing online identity")
	Game.total_points += 2
	Game.pending_points += 2
	Scores.acknowledge(snapshot)
	check(Game.total_points == 107 and Game.pending_points == 2, "sync acknowledgement preserves progress earned during the request")
	Game.save_settings()
	Game.total_points = 0
	Game.load_settings()
	check(Game.total_points == 107 and Game.pending_points == 2 and not Game.needs_name(), "points, pending progress and name migration survive restart")


func _online() -> void:
	# Full API contract checks live in FakeLeaderboard; no live account or network is needed in CI.
	var fake := FakeLeaderboard.new()
	add_child(fake)
	var epic := Net._online_node()
	epic._ieos = fake
	epic._user = "self"
	epic._display_name = Game.player_name
	Scores._cache_time = -100000
	fake.ingest_result = 3
	await Scores.refresh(true)
	check(not Game.sync_snapshot.is_empty() and Scores.last_error != "", "failed ingest retains its durable score snapshot")
	var pending_snapshot := Game.sync_snapshot.duplicate(true)
	fake.ingest_result = 0
	var rows := await Scores.refresh(true)
	check(fake.attempts.size() == 2 and fake.attempts[0] == fake.attempts[1], "lost or failed ingest retries the same MAX snapshot")
	check(Game.sync_snapshot.is_empty() and Game.total_points == pending_snapshot["points"], "acknowledged retry cannot add the same points twice")
	check(Scores.last_error == "" and rows.size() == 2, "Epic stats and ranks API contract completes")
	check(rows[0]["points"] > rows[1]["points"], "leaderboard sorts by descending total points")
	check(rows[0]["name"] == rows[1]["name"], "equal display names remain separate identities")
	check(rows[0]["favourite"] == "plague_doctor|pestilence", "batched Epic stats resolve favourite profession")
	check(fake.ingested.has(Scores.prefix() + "POINTS"), "score submission uses the selected release channel")
	epic._ieos = null
	epic._user = ""
	fake.queue_free()


func _exploration() -> void:
	var map_was := Game.night_map
	var coins_were := Game.doubloons
	for map_id: String in ["village", "mists", "fort"]:
		Game.night_map = map_id
		var area := World.new()
		add_child(area)
		area.setup(Game.Mode.FORT if map_id == "fort" else Game.Mode.NIGHT)
		area.director.running = false
		area.player.set_physics_process(false)
		var sites := area.caches.caches.filter(func(c: Dictionary) -> bool: return c["title"] != "Mist cache")
		check(sites.size() == (4 if map_id == "fort" else 3), "%s has independent expedition stops" % map_id)
		for c: Dictionary in sites:
			var at: Vector3 = c["at"]
			check(not area.terrain.in_water(at.x, at.z), "%s is on dry land" % c["title"])
			check(area.grid.is_free(area.grid.to_cell(at)), "%s cache is on a walkable cell" % c["title"])
			check(absf(at.y - area.ground_at(at)) < 0.1, "%s chest rests on the ground" % c["title"])
			for side: float in [-1, 1]:
				var from := at + Vector3(side * 5, 0, 3)
				var route: Array[Vector2i] = area.grid.astar.get_id_path(area.grid.to_cell(from), area.grid.to_cell(at)) if area.grid.is_free(area.grid.to_cell(from)) else ([] as Array[Vector2i])
				check(not route.is_empty(), "%s has a clear %s approach" % [c["title"], side])
			area.player.hp = 40.0
			var before := Game.doubloons
			area.caches.open_cache(c, area.player)
			area.caches.open_cache(c, area.player)
			check(Game.doubloons == before + 15 and area.player.hp > 40, "%s rewards and heals exactly once" % c["title"])
		var source: MapRoot = (load("res://maps/%s.tscn" % map_id) as PackedScene).instantiate()
		for piece: Node in source.find_children("*", "Node3D", true, false):
			if not piece is MapExpedition:
				continue
			var trail: PackedVector2Array = piece.trail
			for segment in trail.size() - 1:
				var steps := ceili(trail[segment].distance_to(trail[segment + 1]))
				var blocked := Vector2.INF
				for step in steps + 1:
					var spot := trail[segment].lerp(trail[segment + 1], float(step) / steps)
					if not area.grid.is_free(area.grid.to_cell(Vector3(spot.x, 0, spot.y))):
						blocked = spot
						for body: Node3D in [area._body, area._barriers, area._enemy_blocks]:
							for collider: CollisionShape3D in body.get_children():
								if collider.shape is BoxShape3D:
									var local := collider.global_transform.affine_inverse() * Vector3(spot.x, collider.global_position.y, spot.y)
									var size := (collider.shape as BoxShape3D).size * 0.5 + Vector3.ONE * 0.4
									if absf(local.x) <= size.x and absf(local.z) <= size.z:
										print("TRAIL_OBSTACLE ", piece.title, " ", collider.global_position, " size=", (collider.shape as BoxShape3D).size)
						break
				check(blocked == Vector2.INF, "%s trail segment %d is clear (blocked at %s)" % [piece.title, segment, blocked])
		source.free()
		if map_id != "fort":
			var field := CommandField.new()
			area.add_child(field)
			field.set_physics_process(false)
			field.world = area
			var wet := Vector3(20, 0, 64) if map_id == "village" else Vector3(60, -100, 100)
			wet.y = area.terrain.height(wet.x, wet.z)
			field._add_fire(wet, 0.0)
			check(field._fires.is_empty(), "%s artillery leaves no floating fire in water or void" % map_id)
			field.queue_free()
		var friend := Avatar.new(area, 42, {"name": "Companion", "class": "infantry"})
		area.add_child(friend)
		friend.set_process(false)
		friend.set_physics_process(false)
		area.players.append(friend)
		var cache: Dictionary = sites[0]
		area.player.global_position = cache["at"]
		friend.global_position = area.player.global_position + Vector3.RIGHT * 3
		check(area.caches.nearby_friend(area.player), "%s recognises a nearby travelling companion" % map_id)
		friend.dead = true
		check(not area.caches.nearby_friend(area.player), "fallen allies cannot trigger expedition bonuses")
		friend.dead = false
		cache["open"] = false
		area.player.hp = 30.0
		area.caches.open_cache(cache, area.player)
		check(area.player.hp == 70.0, "%s group exploration grants ten extra healing" % map_id)
		area.queue_free()
		await frames(2)
	Game.night_map = map_was
	Game.doubloons = coins_were
	Game.save_settings()
