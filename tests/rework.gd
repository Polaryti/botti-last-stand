extends Node
## Targeted behavior checks for the combat rework and match rewards.

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
	Game.player_name = "Test Player"
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
	_projectile_lifecycle()
	_remote_animation()
	_equipment()
	_ownership_and_poison()
	await _mists()
	print("REWORK progress")
	_progress()
	Net.leave()
	w.queue_free()
	await frames(2)
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
	check(w.count_allies("artificer") == 1, "Gunner Command summons an Artificer")
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
	Game.mode = Game.Mode.NIGHT
	Game.begin_run()
	var before := Game.doubloons
	check(Game.award_doubloons(600, 150, true, false) == 60 and Game.doubloons == before + 60, "match rewards still grant currency")
	check(Game.award_doubloons(600, 150, true, false) == 0, "match rewards cannot be awarded twice")
	Game.mode = Game.Mode.SANDBOX
	Game.begin_run()
	check(Game.award_doubloons(600, 150, true, false) == 0, "Sandbox grants no currency")


func _projectile_lifecycle() -> void:
	var shot := Projectile.new(w)
	w.add_child(shot)
	shot.scale = Vector3.ONE * 3.0
	shot._spin = 8.0
	shot.launch(Projectile.Kind.ARROW, null, p.eye_position(), Vector3.FORWARD * 20, 0, 10, 5)
	check(shot.scale == Vector3.ONE and shot._spin == 0, "reused thrown shots cannot resize the next arrow or retain axe spin")
	var owner := Player.new(w)
	w.add_child(owner)
	shot.set_owner_player(owner)
	owner.free()
	check(shot._owner() == null, "a departed projectile owner never falls back to the host")
	shot._physics_process(0.016)
	check(not shot.active, "a shot retires before damage or callbacks after its owner leaves")
	shot.launch(Projectile.Kind.BOLT, null, p.eye_position(), Vector3.FORWARD, 0, 10, 0)
	check(shot._owner() == p, "a recycled shot clears its previous owner assignment")
	shot.stop()
	var axe_was_out := p._axe_out
	p._axe_out = true
	shot.launch(Projectile.Kind.AXE, null, p.eye_position(), Vector3.FORWARD, 0, 10, 0)
	shot.visual = true
	shot.stop()
	check(p._axe_out, "another player’s visual axe cannot return the local player’s weapon")
	p._axe_out = axe_was_out
	shot.queue_free()


func _remote_animation() -> void:
	var avatar := Avatar.new(w, 99, {"class": "infantry", "name": "Remote"})
	w.add_child(avatar)
	avatar.set_process(false)
	var clips := avatar._anim.get_animation_list()
	var clip: String = clips[0]
	avatar._play(clip, 1.4)
	avatar._anim.advance(0.1)
	var position_was := avatar._anim.current_animation_position
	avatar._play(clip, 0.6)
	check(is_equal_approx(avatar._anim.speed_scale, 0.6), "remote movement updates playback speed without changing animation")
	check(is_equal_approx(avatar._anim.current_animation_position, position_was), "speed changes preserve animation phase instead of restarting the clip")
	avatar.queue_free()


func _equipment() -> void:
	pawn("chivalry")
	p.slots[1] = "sword"
	check(not p.can_drop_weapon() and not WeaponDefs.lies_around("lance"), "Chivalry lance stays equipped and never enters the loot pool")
	var pickup_count := w.pickups.size()
	w.drop_weapon(p.global_position, "lance")
	check(w.pickups.size() == pickup_count, "Fallen Knights cannot drop exclusive lances")
	pawn("infantry")
	check(not p.can_use("lance"), "other classes cannot equip a lance")
	p.slots = ["sling", "dagger"]
	p.current = 0
	p._equip()
	check(p.weapon_id() == "dagger" and p.slots[0] == null, "obsolete inventory weapons are discarded safely")
	check(WeaponAnim.keys_for("reap", true) == WeaponAnim.keys_for("reap", false) and BodyAnim.attack_for("scythe", 1) == "Sweep", "scythe always reaps edge-first in both views")
	pawn("ranger")
	for id: String in ["bow", "longbow", "crossbow"]:
		p.slots = [id, null]
		p.current = 0
		p.arrows = 3
		p._equip()
		p._switch_anim = 0.0
		p._reload = 1.0
		p.pose_weapon(p.weapon_def(), 1.0)
		check(p._vm_arrow.visible, "%s starts nocked" % id)
		p._cooldown = 0.0
		p.input_fire = true
		p._handle_fire()
		p.input_fire = false
		p._animate_view(0.001)
		check(not p._vm_arrow.visible, "%s arrow leaves the hand immediately after firing" % id)
		p._cooldown = 0.0
		p._reload = 1.0
		p.pose_weapon(p.weapon_def(), 1.0)
		check(p._vm_arrow.visible, "%s is nocked again after reloading" % id)
		p.arrows = 0
		p.pose_weapon(p.weapon_def(), 1.0)
		check(not p._vm_arrow.visible, "%s does not show an arrow without ammunition" % id)
	var a := Avatar.new(w, 9993, {"class": "chivalry", "name": ""})
	w.add_child(a)
	a.apply_pose(p.global_position, 0.4, 0.0, Vector3.ZERO, 1.0, 0, 0, "lance", 1.0)
	a._process(0.016)
	a._hand._process(0.016)
	check((-a._hand.global_basis.z.normalized()).dot(-a.global_basis.z.normalized()) > 0.99, "remote lance points forward independently of the sword wrist")
	a.apply_pose(p.global_position, 0.4, 0.0, Vector3.ZERO, 1.0, 0, 1, "bow", 1.0)
	check(a._hand.arrow != null and not a._hand.arrow.visible, "remote arrows disappear on the replicated firing packet")
	a._hand._process(2.0)
	check(a._hand.arrow.visible, "remote arrow returns after reload")
	a.show_statuses(128)
	check(a._banner != null and a._banner.visible, "Vanguard banner is visible on remote players")
	a._hand.equip("flail")
	a._hand._process(1.0)
	var down := a._hand.chain.global_basis * Vector3.DOWN
	check(down.normalized().dot(Vector3.DOWN) > 0.99, "idle flail chain hangs toward gravity despite the hand rotation")
	a._hand.attack()
	a._hand._process(0.2)
	check((a._hand.chain.global_basis * Vector3.DOWN).normalized().dot(Vector3.DOWN) < 0.99, "flail chain moves through its attack arc")
	a._hand.equip("")
	check(a._hand.chain == null and a._hand.arrow == null, "unequip clears dynamic weapon parts")
	a.queue_free()
	pawn("commander", 0)
	p.flags["quick_command"] = true
	check(is_equal_approx(float(CommanderKit.art(p)["cd"]), 19.2), "Composure reduces Command cooldown before level ten")
	p.flags["last_command"] = true
	check(float(CommanderKit.art(p)["cd"]) == CommanderKit.LAST_CD, "Composure preserves Last Command cooldown")
	p.flags.erase("last_command")
	p.flags["war_echo"] = true
	p.flags["war_shatter"] = true
	p._war_attacks = 4
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	var bolts := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.owner_player == p)
	check(bolts.size() == 1 and bolts[0].damage >= 45.0 and bolts[0].pierce == 2 and bolts[0].sparks == 2 and bolts[0].stagger == 0.8, "Warlock fifth hit applies empowered damage, stagger, piercing and chaining talents")
	for q: Projectile in bolts:
		q.stop()
	w.spawn_bolt(p, p.eye_position(), Vector3.FORWARD * 30.0, 26.0, 1.0, 25.0, false)
	var summon_bolts := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.owner_player == p)
	check(summon_bolts.size() == 1 and summon_bolts[0].pierce == 0 and summon_bolts[0].sparks == 0 and summon_bolts[0].stagger == 0.0, "a Warlock's summoned Magician does not inherit fifth-hit bolt talents")
	w.spawn_ally("magician", p.position + Vector3.RIGHT, 16.0)
	p.flags["last_command"] = true
	p.level = 9
	CommanderKit.cast(p)
	check(w.count_allies("magician") == 0, "Last Command never falls back to the Warlock summon")
	check("poison damage" in CodexPanel.acquisition("plague_doctor") and not "Store" in CodexPanel.acquisition("plague_doctor"), "Codex explains the Plague Doctor poison unlock")
	check("VRAIN" in CodexPanel.acquisition("commander") and "code" in CodexPanel.acquisition("commander"), "Codex explains the tournament prize code")
	for id: String in PowerDefs.ALL:
		if PowerDefs.ALL[id]["familiar"]:
			check(PowerDefs.ALL[id]["time"] == 20.0, "%s familiar uses the twenty-second lifetime" % id)

	pawn("commander", 2)
	p.flags["rally_recovery"] = true
	p.hp = 60.0
	w.spawn_ally("infantry", p.global_position + Vector3.RIGHT, 20.0)
	var retainer: Ally = w.allies.back()
	retainer.hp = 30.0
	CommanderKit.cast(p)
	check(p.hp == 80.0 and retainer.hp == 50.0, "Rally Recovery heals the Commander and its nearby living retinue")
	pawn("commander", 1)
	CommanderKit.cast(p)
	var artificer: Ally = w.allies.back()
	check(artificer.kind == "artificer" and is_equal_approx(artificer.life, 16.0), "Gunner summons the Artificer kind for sixteen seconds")
	var victim := target(artificer.global_position + Vector3.FORWARD)
	artificer._foe = victim
	artificer._think = 1.0
	artificer._cooldown = 0.0
	artificer._tick_own(0.016)
	check(victim.hp < victim.max_hp and victim.burn_time > 0.0, "summoned Artificer attacks in melee and its torch ignites the target")


func _mists() -> void:
	var old_map := Game.night_map
	var old_class := Game.player_class
	w.process_mode = Node.PROCESS_MODE_DISABLED
	Game.night_map = "mists"
	Game.player_class = "infantry"
	var mw := World.new()
	add_child(mw)
	mw.setup(Game.Mode.NIGHT)
	mw.director.running = false
	for z: Zombie in mw.zombies.duplicate():
		z.release()
	var mp := mw.player
	mp.set_physics_process(false)
	mp.guard_left = 0.0
	mp.position = Vector3(0, mw.ground_at(Vector3(0, 0, 16)), 16)
	await frames(2)
	var treads_match := true
	for step in 13:
		var radius := 30.0 + (step + 0.5) * 24.0 / 13.0
		var point := Vector3(radius * 0.7, 0, radius * sqrt(0.51))
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 25.0, point + Vector3.UP * 8.0, 1)
		var hit := mw.get_world_3d().direct_space_state.intersect_ray(query)
		treads_match = treads_match and not hit.is_empty() and absf((hit["position"] as Vector3).y - mw.ground_at(point)) < 0.03
	check(treads_match, "all thirteen arena bands have continuous ramp collision at the visible surface")
	var cache_top: Vector3 = mw.stone_chains[0].back()
	var underside_query := PhysicsRayQueryParameters3D.create(cache_top - Vector3.UP * 6.0, cache_top + Vector3.UP, Terrain.LAYER)
	var underside := mw.get_world_3d().direct_space_state.intersect_ray(underside_query)
	check(not underside.is_empty() and (underside["position"] as Vector3).y < cache_top.y - 1.0, "floating stone undersides have collision rather than a thin top-only disc")
	var clear_landings := true
	var connected_landings := true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	for link: Dictionary in mw.portals.links:
		for side: String in ["a", "b"]:
			var at: Vector3 = link[side]
			var island := int(link["ia" if side == "a" else "ib"])
			var land := MapIslands.ISLANDS[island]
			var anchor := mw.grid.nearest_free(mw.grid.to_cell(Vector3(land.x, land.w, land.y + 8)))
			clear_landings = clear_landings and mw.grid.is_free(mw.grid.to_cell(at)) and absf(at.y - mw.ground_at(at)) < 0.2
			connected_landings = connected_landings and not mw.grid.astar.get_id_path(mw.grid.to_cell(at), anchor).is_empty()
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.95)
			query.collision_mask = 1 | Terrain.LAYER
			clear_landings = clear_landings and mw.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
	check(clear_landings, "all twenty portal landings have space for a capsule above the ground")
	check(connected_landings, "every portal has a walkable route into its island")
	var gate: Dictionary = mw.portals.links[0]
	gate["open"] = true
	var expected_exit := mw.portals._beyond(gate["b"], int(gate["ib"]))
	mp.position = gate["a"]
	mp.level_flash = 0.0
	mp._gate_wait = 0.0
	var old_level := mp.level
	mp._tick_islands(0.016)
	check(mp.level_flash == 0.0 and mp.level == old_level and mp.position.distance_to(expected_exit) < 0.01, "portal transit has its own effect without a level-up announcement")
	mp.position = Vector3(28, 10.16, 0)
	for direction: float in [1.0, -1.0]:
		for tick in 480:
			mp.velocity = Vector3(direction * 8.0, -3.0, 0)
			mp.move_and_slide()
			await frames(1)
			if (direction > 0 and mp.position.x > 55.0) or (direction < 0 and mp.position.x < 29.0): break
		check(mp.position.x > 54.0 if direction > 0 else mp.position.x < 30.0, "player walks %s the arena slope without jumping" % ("up" if direction > 0 else "down"))
	mp.position = Vector3(0, 10.06, 16)
	var shrines := mw.find_child("IslandSupplyShrines", false, false)
	check(shrines != null and shrines.get_meta("islands").size() >= 6, "outer islands have several unobstructed supply shrines")
	check(mw.director.target_population() >= 12, "Mists starts with enough enemies to populate the islands")

	for shrine: Array in MapIslands.ROTUNDAS:
		var centre: Vector2 = shrine[0]
		var radius := float(shrine[1])
		# Halfway between columns is the intended doorway, rather than through a pillar.
		var angle := PI / (12.0 if radius > 9 else 10.0 if radius > 6 else 8.0)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var outside := Vector3(centre.x, 0, centre.y) + direction * (radius + 7.0)
		var inside := Vector3(centre.x, 0, centre.y) + direction * (radius - 2.0)
		check(mw.grid.line_is_open(outside, inside), "shrine entry remains open between its columns")
	check(mw.night_bg.get_luminance() < 0.06 and mw.night_moon <= 0.35 and mw.night_sky_shows, "Mists uses a moonlit night palette with stars")
	check(mw.find_children("MistBridgeInlays*", "MeshInstance3D", false, false).size() == MapIslands.BRIDGES.size(), "every existing bridge has deck-following night inlays")
	for kind: String in MistModels.KINDS:
		check(Icons.exists(kind) and Game.zombie_pool_plan().has(kind), "%s has its own icon and pooled model in the Mists" % kind)
		check(mw.spawn_zombie(kind, Vector3(8, 10, 8)), "%s can spawn" % kind)
		var enemy: Zombie = mw.zombies.back()
		enemy.set_physics_process(false)
		check(enemy.mist_mind != null and enemy._custom and enemy._parts.size() > 0, "%s uses its original model and mist AI" % kind)
		enemy._animate_custom(0.1, 0.0)
		await frames(2)
		var eye := enemy._visual.to_global(Vector3(0, 1.35 if kind == "lantern_wisp" else 1.78, 0.3 if kind == "lantern_wisp" else 0.2))
		var ray := PhysicsRayQueryParameters3D.create(eye + Vector3.BACK * 5.0, eye, Zombie.LAYER)
		var hit := mw.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider") == enemy, "%s visible face is inside its hittable collider" % kind)
		enemy.release()
	var village_only := true
	for i in 400:
		village_only = village_only and not ZombieDefs.ALL[ZombieDefs.pick_roamer(550.0)].get("only_islands", false)
	check(village_only, "Village roster excludes mist-only enemies")
	var seen := {}
	for i in 400:
		seen[ZombieDefs.pick_roamer(550.0, true)] = true
	check(seen.has("lantern_wisp") and seen.has("mist_weaver") and not seen.has("veil_regent"), "Mists roaming waves include both spirits and exclude the scheduled boss")
	mw.spawn_zombie("lantern_wisp", mp.position + Vector3.RIGHT * 12)
	var spirit: Zombie = mw.zombies.back()
	spirit.set_physics_process(false)
	spirit._sees = false
	spirit._has_goal = false
	spirit.mist_mind.cooldown = 0.0
	var before := mw.mist_seals.size()
	spirit.mist_mind.tick(spirit, mp, 0.016)
	check(mw.mist_seals.size() == before and spirit.velocity == Vector3.ZERO, "unaware spirits do not track or cast at unseen players")
	spirit._sees = true
	spirit.mist_mind.tick(spirit, mp, 0.016)
	check(mw.mist_seals.size() == before + 1, "a spirit that sees its target casts a warning")
	for seal: MistSeal in mw.mist_seals.duplicate():
		seal.free()
	MistSeal.cast(spirit, mp.position + Vector3.UP * 6.0, 3.0, 1.5, 10.0)
	var grounded: MistSeal = mw.mist_seals.back()
	check(absf(grounded.position.y - mp.position.y) < 0.2 and grounded.contains(mp.position), "a seal aimed at a high jump warns on the ground below")
	check(not grounded.contains(mp.position + Vector3.UP * 6.0), "a sufficiently high airborne player stays clear of a ground seal")
	grounded.free()
	MistSeal.cast(spirit, Vector3(2.0, 12.72, 0), 3.0, 1.5, 10.0)
	var raised: MistSeal = mw.mist_seals.back()
	check(absf(raised.position.y - 12.7) < 0.1, "seals on raised plinths warn on their visible standing surface")
	raised.free()
	for i in MistSeal.LIMIT:
		MistSeal.create(mw, mp.position, 3.0, 0.0, 1.5, 0.0, -1)
	MistSeal.cast(spirit, mp.position, 3.0, 1.5, 10.0)
	check(mw.mist_seals.size() == MistSeal.LIMIT, "active mist effects respect their fixed mobile budget")
	for seal: MistSeal in mw.mist_seals.duplicate():
		seal.free()
	spirit.release()
	var at := mp.position
	mp.hp = 100.0
	var seal := MistSeal.create(mw, at, 3.0, 0.0, 1.5, 10.0, -1)
	seal._physics_process(1.0)
	check(mp.hp == 100.0, "mist seal does not damage during its warning")
	seal._physics_process(0.5)
	check(mp.hp == 90.0 and mp.slowed_left > 0.0, "mist seal lands once and slows a player caught inside")
	seal._physics_process(0.1)
	check(mp.hp == 90.0, "mist seal cannot damage repeatedly after detonation")
	seal.free()
	var crown := MistSeal.create(mw, at, 9.0, 3.0, 1.8, 20.0, -1)
	check(not crown.contains(at) and crown.contains(at + Vector3.RIGHT * 5.0), "Regent crown has a genuinely safe centre and dangerous annulus")
	check(not crown.contains(at + Vector3.RIGHT * 10.0) and not crown.contains(at + Vector3(5, 10, 0)), "seal cannot hit outside its radius or on a different height")
	crown.strike()
	check(mp.hp == 90.0, "standing in the safe eye avoids the crown attack")
	crown.free()
	mw.director._mist_boss_spawned = false
	check(mw.director._mist_boss_at >= 505.0 and mw.director._mist_boss_at <= 515.0, "boss scheduling is around 8:30")
	mw.director.elapsed = mw.director._mist_boss_at - 0.01
	mw.director._tick_mist_boss()
	check(mw.count_type("veil_regent") == 0, "Regent does not arrive early")
	mw.director.elapsed += 0.02
	mw.director._tick_mist_boss()
	mw.director._tick_mist_boss()
	check(mw.count_type("veil_regent") == 1, "Regent arrives exactly once at its scheduled time")
	var boss: Zombie = mw.zombies.back()
	boss.set_physics_process(false)
	boss.freeze(10.0)
	check(boss._stun <= 0.6 and boss._frozen <= 0.6, "Regent resists long disables without an incorrect lingering ice effect")
	boss._stun = 0.0
	boss._show_frozen(0.0)
	for i in 3:
		mw.spawn_zombie("lantern_wisp", Vector3(8 + i * 2, 10, 16))
	var reserves_kept := true
	for i in 100:
		reserves_kept = reserves_kept and mw.director._pick_roamer() != "lantern_wisp"
	check(reserves_kept, "roaming waves reserve two wisp bodies for the boss encounter")
	boss.hp = boss.max_hp * 0.49
	boss.mist_mind.tick(boss, mp, 0.016)
	check(boss.mist_mind.enraged and mw.count_type("lantern_wisp") == 5, "Regent enters its second phase and calls two wisps")
	boss.mist_mind.tick(boss, mp, 0.016)
	check(mw.count_type("lantern_wisp") == 5, "second-phase reinforcement happens only once")
	var angels := mw.pickups.filter(func(it: Pickup) -> bool: return it.kind == Pickup.Kind.POWER and it.item_id == "angel").size()
	boss._die()
	check(mw.pickups.filter(func(it: Pickup) -> bool: return it.kind == Pickup.Kind.POWER and it.item_id == "angel").size() == angels + 1, "defeating the Regent drops an Angel familiar")

	mp.position = Vector3(0, 10.1, 16)
	mp.hp = mp.max_hp()
	mp.guard_left = 0.0
	var storm := MistStorm.create(mw, 0)
	storm.set_physics_process(false)
	var hp_before := mp.hp
	storm._physics_process(MistStorm.WARNING)
	check(mp.hp == hp_before, "Mist Storm provides a damage-free evacuation warning")
	storm._physics_process(1.0)
	check(is_equal_approx(mp.hp, hp_before - MistStorm.DPS), "Mist Storm integrates its configured damage per second")
	mp.position = Vector3(0, 40, -122)
	var safe_hp := mp.hp
	storm._physics_process(1.0)
	check(mp.hp == safe_hp, "another island is safe from the active storm")
	check(storm.escape(Vector3(0, 10, 16)) != Vector3.INF, "storm island has an evacuation gate")
	storm.free()
	Game.night_map = old_map
	Game.player_class = old_class
	mw.queue_free()
	await frames(2)
	w.process_mode = Node.PROCESS_MODE_INHERIT


func _ownership_and_poison() -> void:
	pawn("infantry")
	var bot := Player.new(w, Net.BOT_BASE)
	w.add_child(bot)
	w.players.append(bot)
	bot.position = p.position + Vector3.RIGHT * 12.0
	bot.activate_power("ghost")
	var ghost: Ally = w.allies.back()
	check(ghost.master == bot and ghost.global_position.distance_to(bot.position) < 5.0, "bot Ghost Knight familiar belongs to and appears near the collecting bot")
	w.remove_ally(ghost)
	w.players.erase(bot)
	bot.free()
	var victim := target(p.position + Vector3.FORWARD * 8.0)
	victim.add_dot(10.0, 3.0)
	victim._hurt_stun = 0.0
	victim._tick_dot(0.25)
	check(victim._hurt_stun == 0.0, "poison ticks never cause hit flinches or micro-stuns")
	victim.release()
	pawn("plague_doctor")
	p.slots[1] = "sword"
	check(not p.can_drop_weapon() and not WeaponDefs.lies_around("blowgun"), "Plague Doctor's blowgun is exclusive, undroppable and absent from loot")
