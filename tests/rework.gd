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
	await _bandit()
	print("REWORK upgrades")
	await _new_upgrades()
	await _path_upgrades()
	print("REWORK cartographer")
	await _cartographer()
	print("REWORK crown upgrades")
	await _crown_upgrades()
	await _trappers_guild()
	_class_codes()
	print("REWORK harpooner")
	await _harpooner()
	print("REWORK tidecaller")
	await _tidecaller()
	print("REWORK ascendant")
	await _ascendant()
	print("REWORK fontanova finds")
	await _fonta_finds()
	print("REWORK ferryman")
	check(ClassDefs.disabled("ferryman") and not ClassDefs.available().has("ferryman"), "Ferryman is disabled and absent from playable classes")
	print("REWORK walls")
	await _walls_protect()
	print("REWORK statuses")
	_statuses()
	_projectile_lifecycle()
	_remote_animation()
	_equipment()
	_ownership_and_poison()
	_foundations()
	_guardian_protection()
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
	check(not p.can_use("bow") and p.max_hp() >= float(ClassDefs.ALL["commander"]["hp"]), "Warlock has the Commander's full health and cannot replace its weapon")
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
	check(p.max_hp() == 100.0 and p.m("damage_taken") < 1.0, "Plague Doctor has improved baseline durability")


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
	var old_magician: Ally = w.allies.back()
	old_magician.life = 3.0
	p.flags["last_command"] = true
	p.level = 9
	CommanderKit.cast(p)
	var magicians := w.allies.filter(func(x: Ally) -> bool: return x.kind == "magician" and not x.dead and x.master == p)
	check(magicians.size() == 1 and is_equal_approx((magicians[0] as Ally).life, 16.0), "Warlock's Last Command also calls one fresh Magician for 16 s")
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
	var infantry_before := w.count_allies("infantry")
	CommanderKit.cast(p)
	check(p.hp == 80.0 and retainer.hp == 50.0, "Rally Recovery heals the Commander and its nearby living retinue")
	check(w.count_allies("infantry") == infantry_before + 1, "Vanguard's Command calls an Infantry")
	check(p.status_effects().any(func(e: Dictionary) -> bool: return e["icon"] == "boot+up" and float(e["left"]) > 5.0), "the rally's speed shows in the effects row")
	for x: Ally in w.allies.duplicate():
		if x.master == p: w.remove_ally(x)
	p.flags["last_command"] = true
	CommanderKit.cast(p)
	check(w.count_allies("infantry") == 2 and w.count_allies("ranger") == 1, "Vanguard's Last Command calls two Infantry and a Ranger")
	var effects := p.status_effects()
	check(effects.any(func(e: Dictionary) -> bool: return e["icon"] == "sword+up") and not effects.any(func(e: Dictionary) -> bool: return e["icon"] == "arrow+up"), "Last Command's damage shows once in the effects row")
	var ranger: Ally = w.allies.filter(func(x: Ally) -> bool: return x.kind == "ranger").back()
	var mark := target(ranger.global_position + Vector3.FORWARD * 8.0)
	ranger._foe = mark
	ranger._think = 1.0
	ranger._cooldown = 0.0
	ranger._tick_own(0.016)
	check(w._projectiles.any(func(q: Projectile) -> bool: return q.active and q.owner_player == p and q.kind == Projectile.Kind.ARROW), "the summoned Ranger shoots arrows")
	p.flags.erase("last_command")
	pawn("commander", 1)
	CommanderKit.cast(p)
	var artificer: Ally = w.allies.back()
	p.flags["last_command"] = true
	p.command_target_ready = true
	p.command_target = p.global_position + Vector3(0, 0, -20)
	var before_last := w.count_allies("artificer")
	CommanderKit.cast(p)
	check(w.count_allies("artificer") == maxi(1, before_last), "Gunner's Last Command also calls an Artificer")
	p.flags.erase("last_command")
	artificer = w.allies.filter(func(x: Ally) -> bool: return x.kind == "artificer" and not x.dead).back()
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
	var map_space := SubViewport.new()
	map_space.own_world_3d = true
	add_child(map_space)
	var mw := World.new()
	map_space.add_child(mw)
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
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 25.0, point + Vector3.UP * 8.0, Terrain.LAYER)
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
	# Use the real NPC mover and body, in an isolated physics world, in both directions.
	var approaches: Array[Array] = []
	for shrine: Array in MapIslands.ROTUNDAS:
		var centre: Vector2 = shrine[0]
		var radius := float(shrine[1])
		var angle := PI / (12.0 if radius > 9 else 10.0 if radius > 6 else 8.0)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var outside := Vector3(centre.x, 0, centre.y) + direction * (radius + 7.0)
		var inside := Vector3(centre.x, 0, centre.y) + direction * (radius - 2.0)
		approaches.append([outside, inside])
	approaches.append([Vector3(11, 0, 0), Vector3(3, 0, 0)])
	approaches.append([Vector3(19, 0, 124), Vector3(12, 0, 124)])
	# Each body a Zombie can rise in (the spawn picks one at random): every one of them must get through.
	var bodies: Array = ZombieDefs.ALL["normal"]["models"]
	for run in approaches.size() * bodies.size():
		var approach: Array = approaches[run / bodies.size()]
		var body: String = bodies[run % bodies.size()]
		var outside: Vector3 = approach[0]
		var inside: Vector3 = approach[1]
		outside.y = mw.ground_at(outside)
		var walker: Zombie = null
		for attempt in 24:
			mw.spawn_zombie("normal", outside)
			var risen: Zombie = mw.zombies.back()
			if risen.model_id == body:
				walker = risen
				break
			risen.release()
		if walker == null:
			check(false, "a Zombie rises as %s" % body)
			continue
		walker.set_physics_process(false)
		walker.state = Zombie.State.CHASE
		walker._sees = true
		walker._direct = true
		walker._flank = Vector3.ZERO
		walker._speed = 8.0
		await frames(2) # let the activated body enter the isolated physics space
		for goal: Vector3 in [inside, outside]:
			# Each leg starts a fresh pursuit; this fixture runs the mover without its AI thinker.
			walker._direct = true
			walker._blocked_timer = 0.0
			walker._blocked_from = walker.position
			mp.position = Vector3(goal.x, mw.ground_at(goal), goal.z)
			for tick in 480:
				var to := mp.position - walker.position
				to.y = 0.0
				if to.length() < 1.8: break
				walker._move(mp, to, to.length(), 0.016)
				await frames(1)
			var reached := Vector2(walker.position.x - goal.x, walker.position.z - goal.z).length() < 2.0
			var blocker := ""
			if not reached:
				# What stopped it, for whoever reads the failure.
				var ray := PhysicsRayQueryParameters3D.create(walker.centre(), Vector3(goal.x, walker.centre().y, goal.z))
				ray.exclude = [walker.get_rid()]
				var hit := mw.get_world_3d().direct_space_state.intersect_ray(ray)
				blocker = " blocked by %s at %s" % [str((hit["collider"] as Node).get_path()) if hit.has("collider") and hit["collider"] is Node else "nothing", str(hit.get("position", "-"))]
				# And what holds the walker itself: its own state, and every body it stands in.
				var touching := PhysicsShapeQueryParameters3D.new()
				var probe := SphereShape3D.new()
				probe.radius = walker.body_radius() + 0.3
				touching.shape = probe
				touching.transform = Transform3D(Basis(), walker.centre())
				touching.exclude = [walker.get_rid()]
				var near := mw.get_world_3d().direct_space_state.intersect_shape(touching, 8).map(func(h: Dictionary) -> String: return "%s(layer %d)" % [(h["collider"] as Node).name if h["collider"] is Node else "?", (h["collider"] as CollisionObject3D).collision_layer if h["collider"] is CollisionObject3D else -1])
				blocker += "; speed %.1f hop %s vel %s sep %s tick %d gate %.1f layer %d shape_off %s; touching %s" % [walker._desired_speed(), walker._hop_walk, walker.velocity, walker._separation, walker._tick_every, walker._gate_wait, walker.collision_layer, walker._shape.disabled, near]
			check(reached, "physical mob (%s) from %s reaches goal %s (ended %s, blocked %.1f s)%s" % [body, outside, goal, walker.position, walker._blocked_timer, blocker])
		walker.release()
	mp.position = Vector3(0, 10.06, 16)
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
	# The Fallen Revenant: a Revenant's own body and gear, its claws and its blow, and the Fallen's bar.
	check(MistModels.BORN.has("fallen_revenant") and not MistModels.KINDS.has("fallen_revenant") and Game.zombie_pool_plan().has("fallen_revenant") and Icons.exists("fallen_revenant"), "the Fallen Revenant is mist-born, with a pool and an icon, but not one of the mist's own models")
	check(mw.spawn_zombie("fallen_revenant", mp.position + Vector3(0, 0, -1.4)), "a Fallen Revenant can spawn")
	var fallen: Zombie = mw.zombies.back()
	fallen.set_physics_process(false)
	check(not fallen._custom and fallen._skeleton != null and fallen._anim != null and fallen.mist_mind != null, "it has a body with bones and animations, and still the mist's mind")
	var ghostly := fallen._visual.find_children("*", "MeshInstance3D", true, false).filter(func(mi: MeshInstance3D) -> bool: return mi.material_override == Ally._ghost())
	var revenant_gear := ClassGear._pieces("revenant").size()
	check(ghostly.size() >= revenant_gear and revenant_gear > 0, "it wears the Revenant's gear and its ghostly look (%d pieces)" % ghostly.size())
	check(fallen.weapon_id == "claws" and fallen._hand_mesh != null and float(fallen.def.get("weapon_drop", 1.0)) == 0.0, "it fights with Spectral Claws, and never drops them")
	check(fallen.named_bar() and not fallen.hero, "it has the Fallen's long bar and name, as the Fallen Heroes do")
	fallen._flash_on()
	fallen._restore_materials()
	check(fallen._parts.all(func(mi: MeshInstance3D) -> bool: return mi.material_override == mi.get_meta("own_material", null)), "after a hit's flash it is a Revenant again, not a zombie's skin")
	fallen._sees = true
	fallen._attack_cd = 0.0
	fallen.mist_mind.cooldown = 99.0
	var mp_was := mp.global_position
	mp.global_position = fallen.position + Vector3(0, 0, 1.2)
	var player_hp := mp.hp
	fallen.mist_mind.tick(fallen, mp, 0.016)
	check(fallen._current_anim == BodyAnim.mob_attack("claws") and Net.ANIMS.has(fallen._current_anim) and is_equal_approx(mp.hp, player_hp), "it swings its claws as a Revenant does, and every phone sees the swing (%s)" % fallen._current_anim)
	fallen.hp = fallen.max_hp - 20.0
	for i in 30:
		fallen.mist_mind.tick(fallen, mp, 0.016)
	check(mp.hp < player_hp and fallen.hp > fallen.max_hp - 20.0, "then the blow lands and drains life (%.0f taken)" % (player_hp - mp.hp))
	fallen.release()
	mp.hp = player_hp
	mp.global_position = mp_was
	var village_only := true
	for i in 400:
		village_only = village_only and not ZombieDefs.ALL[ZombieDefs.pick_roamer(550.0)].get("only_islands", false)
	check(village_only, "Village roster excludes mist-only enemies")
	var seen := {}
	for i in 400:
		seen[ZombieDefs.pick_roamer(550.0, "mists")] = true
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
	check(absf(raised.position.y - mw.ground_at(Vector3(2, 0, 0))) < 0.15, "seals on raised plinths warn on their visible standing surface")
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
	check(mw.director.boss_card == "veil_regent" and mw.director.boss_card_time > 0.0, "with its own entrance card, saying what it says as it comes")
	check(mw.director.banner.contains("return to the arena") and mw.director.banner_time > mw.director.boss_card_time, "and the warning to come back to the arena waits until the card has gone")
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
	check(mw.pickups.filter(func(it: Pickup) -> bool: return it.kind == Pickup.Kind.POWER and it.item_id == "angel").size() == angels, "defeating the Regent drops no Angel familiar")
	check(mw.director.banner.contains("Veil Regent") and mw.director.banner.contains("It closes behind every one of you"), "the Regent says its last words: %s" % mw.director.banner)

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
	var finale := MistStorm.create(mw, 0, true)
	finale.set_physics_process(false)
	var covered := true
	for island in range(1, MapIslands.ISLANDS.size()):
		var land := MapIslands.ISLANDS[island]
		covered = covered and finale.contains(Vector3(land.x, land.w, land.y))
	check(covered and not finale.contains(Vector3(16, 10, 0)), "finale storms cover every outer island and shelf while sparing the arena")
	mp.position = Vector3(0, 40.6, -122)
	mp.hp = mp.max_hp()
	mp.dome_left = 0.0
	var before_finale := mp.hp
	finale._physics_process(MistStorm.FINALE_WARNING)
	check(mp.hp == before_finale, "finale gives twenty seconds to evacuate")
	finale._physics_process(1.0)
	check(is_equal_approx(mp.hp, before_finale - MistStorm.DPS), "simultaneous outer storms apply damage once, without overlap stacking")
	finale._physics_process(30.0)
	check(is_instance_valid(finale) and not finale.is_queued_for_deletion(), "finale storms persist rather than expiring after twenty seconds")
	finale.free()
	# The night's storms: the next gathers soon after the last ends, and later two rage at once.
	var d := mw.director
	var was_elapsed := d.elapsed
	d._next_storm = MistStorm.FIRST
	d._storm_index = 0
	d._storms_last = 0
	d.elapsed = MistStorm.FIRST
	d._tick_storms()
	check(mw.mist_storms.size() == 1 and mw.mist_storms[0].island == 0, "the first storm gathers at %d s, over the arena" % int(MistStorm.FIRST))
	mw.mist_storms[0].end_now()
	d.elapsed += MistStorm.WARNING + MistStorm.DURATION
	d._tick_storms()
	check(mw.mist_storms.is_empty() and is_equal_approx(d._next_storm, d.elapsed + MistStorm.GAP), "when it ends, the next is due %d s later" % int(MistStorm.GAP))
	d.elapsed += MistStorm.GAP
	d._tick_storms()
	check(mw.mist_storms.size() == 1 and mw.mist_storms[0].island > 0, "and gathers then, over an outer island")
	d.elapsed += MistStorm.STAGGER + 1.0
	d._tick_storms()
	check(mw.mist_storms.size() == 1, "before %d s only one storm rages at a time" % int(MistStorm.TWO_FROM))
	d.elapsed = MistStorm.TWO_FROM + 1.0
	d._next_storm = 0.0
	d._tick_storms()
	check(mw.mist_storms.size() == 2 and mw.mist_storms[0].island != mw.mist_storms[1].island, "later, a second storm rages at the same time, over another island")
	mp.position = Vector3(MapIslands.ISLANDS[mw.mist_storms[1].island].x, 0, MapIslands.ISLANDS[mw.mist_storms[1].island].y)
	check(mw.storm_at(mp.position) == mw.mist_storms[1] and mw.storm_at(Vector3(16, 10, 0)) == null, "each storm covers only its own island")
	for raging: MistStorm in mw.mist_storms.duplicate():
		raging.free()
	check(mw.mist_storms.is_empty(), "storms leave the world's list as they go")
	d.elapsed = was_elapsed
	mp.position = Vector3(16, 10.06, 0)
	mp.hp = mp.max_hp()
	mp.dead = false
	mw.director.running = true
	mw.director.elapsed = 600.0
	mw.director._mist_boss_defeated = false
	mw.director._process(0.0)
	check(not mw._dawn_done and not mw.director._won, "ten minutes alone cannot win Mists while the boss survives")
	mw.director.elapsed = 599.0
	mw.director._mist_boss_defeated = true
	mw.director._process(0.0)
	check(not mw._dawn_done, "an early boss kill still requires ten minutes of survival")
	mw.director.elapsed = 600.0
	mw.director._process(0.0)
	check(mw._dawn_done and mw.director._won, "Mists victory requires both ten minutes and the boss kill")
	Game.night_map = old_map
	Game.player_class = old_class
	map_space.queue_free()
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


func _foundations() -> void:
	var map := (load("res://maps/village.tscn") as PackedScene).instantiate()
	_check_rooms(map, Transform3D.IDENTITY)
	map.free()

func _check_rooms(node: Node, parent: Transform3D) -> void:
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var at := parent * (child as Node3D).transform
		if child is MapHouse and (child as MapHouse).on_ground:
			var house := child as MapHouse
			var base := w.terrain.height(at.origin.x, at.origin.z)
			var flat := true
			for x in 7:
				for z in 7:
					var point := at * Vector3((float(x) / 6.0 - 0.5) * (house.width - 0.3), 0, (float(z) / 6.0 - 0.5) * (house.depth - 0.3))
					flat = flat and absf(w.terrain.ground_height(point.x, point.z) - base) < 0.04
			check(flat, "flat interior terrain throughout %s" % child.name)
		_check_rooms(child, at)

func _guardian_protection() -> void:
	pawn("heavy", 0)
	p.hp = p.max_hp()
	p.guard_left = 0.0
	w.spawn_ally("ghost", p.position + Vector3.RIGHT * 2, 20.0)
	var ally: Ally = w.allies.back()
	p.raise_dome()
	var before := p.hp
	p.hurt(100.0, p.position + Vector3.BACK * 4)
	check(p.hp < before and is_equal_approx(before - p.hp, 100.0 * p.m("damage_taken") * 0.4), "Guardian dome reduces damage by sixty percent instead of granting invulnerability")
	var ally_before := ally.hp
	ally.hurt(100.0, p.position)
	check(ally.hp < ally_before and ally_before - ally.hp <= 40.01, "Guardian-protected summons take reduced damage rather than ignoring it")
	ally.guarded = 0.0
	Net.world = w
	Net._dome_fx(p.position + Vector3.UP * 0.5, 6.0, 3.0)
	check(ally.guarded == 3.0, "a remotely cast Guardian dome protects locally owned summons")
	w.remove_ally(ally)


## 0.22 step 2: the Bandit.
func _bandit() -> void:
	var d: Dictionary = ClassDefs.ALL["bandit"]
	check(d["weapon"] == "dagger" and ClassDefs.price("bandit") == 860 and ClassDefs.for_sale().has("bandit"), "the Bandit starts with a Dagger and is sold in the Store")
	check(ClassDefs.weapon_categories("bandit") == Array(["melee", "ranged"], TYPE_STRING, "", null), "Bandit wields Melee and Ranged weapons")
	check(Game.CODES.values().has("bandit"), "a Bandit code exists, kept only as a hash")
	var specs: Array = AbilityData.tree("bandit")["specs"].map(func(s: Dictionary) -> String: return s["id"])
	check(specs == ["thief", "mercenary", "highwayman"], "Thief, Mercenary and Highwayman")
	for id: String in ["crest_bandit", "spec_thief", "spec_mercenary", "spec_highwayman"]:
		check(ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s icon" % id)
	for s: String in ["vanish", "steal", "nightfall", "dagger_fan"]:
		check(Sfx.NAMES.has(s) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % s), "%s sound" % s)
	# Into the Shadows, before a profession.
	pawn("bandit")
	check(p.art_def()["name"] == "Into the Shadows", "the Bandit's own ability is Into the Shadows")
	p.use_art()
	check(p._cast_kind == "bandit", "it casts as the Bandit")
	await frames(10)
	check(p.invis_left > 3.0, "and turns the Bandit invisible (%.1f)" % p.invis_left)
	p.invis_left = 0.0
	p.art_cd_left = 0.0
	BanditKit.into_shadows(p)
	check(p.invis_left == 0.0, "but not again within 3 s of coming out")
	p.invis_lockout = 0.0
	# Steal: in front of the nearest foe, invisible, a blow, and the weapon on the ground.
	pawn("bandit", 0)
	check(p.art_def()["name"] == "Into the Shadows" and p.path_art_def()["name"] == "Steal", "a Thief keeps Into the Shadows and gets Steal on a second button")
	check(p.has_path_art() and not p.path_art_has_use(), "with nobody near, Steal has nothing to do")
	w.spawn_zombie("clever", p.global_position + Vector3(0, 0, -10))
	var victim: Zombie = w.zombies.back()
	victim.set_physics_process(false)
	victim.hp = 1000.0
	victim.max_hp = 1000.0
	victim.weapon_id = "sword"
	victim.rotation.y = 0.0
	check(p.path_art_has_use(), "with a foe in reach, Steal can be used")
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	BanditKit.cast_path(p)
	check(p.global_position.distance_to(victim.position) < 2.2, "the Thief appears beside its target (%.1f m)" % p.global_position.distance_to(victim.position))
	var look := -p.global_basis.z
	check(look.dot((victim.position - p.global_position).normalized()) > 0.8, "facing it")
	check(p.invis_left > 2.0 and victim.hp < 1000.0, "invisible, and the blow lands")
	check(victim._attack_cd >= BanditKit.STEAL_FLINCH - 0.01 and not victim._attack_hit_pending, "and the target, caught off guard, cannot strike back at once")
	p.mods["shadow_time"] = 0.0
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	victim.weapon_id = ""
	BanditKit.cast_path(p)
	var hidden_for := p.invis_left
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.mods["shadow_time"] = 2.0
	BanditKit.cast_path(p)
	check(is_equal_approx(p.invis_left, hidden_for + 2.0), "Long Shadows keeps a Thief hidden 2 s longer after a Steal (%.1f, was %.1f)" % [p.invis_left, hidden_for])
	p.mods["shadow_time"] = 0.0
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	check(victim.weapon_id == "" and w.pickups.any(func(i: Pickup) -> bool: return i.kind == Pickup.Kind.WEAPON and i.item_id == "sword"), "the stolen Sword lies on the ground")
	victim.weapon_id = "lance"
	BanditKit.cast_path(p)
	check(victim.weapon_id == "lance", "a class weapon cannot be stolen")
	victim.weapon_id = "spear"
	p.flags["steal_keep"] = true
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.slots = ["dagger", null]
	BanditKit.cast_path(p)
	check(p.slots.has("spear") and victim.weapon_id == "", "Fence puts the stolen weapon in the Thief's empty hand")
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	victim.weapon_id = "mace"
	p.slots = ["dagger", "spear"]
	p.current = 1
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	BanditKit.cast_path(p)
	check(p.weapon_id() == "mace" and p.slots.has("dagger") and not p.slots.has("spear"), "with both hands full, Fence swaps the stolen Mace for the Spear held")
	check(w.pickups.any(func(i: Pickup) -> bool: return i.kind == Pickup.Kind.WEAPON and i.item_id == "spear"), "and the Spear drops")
	# Grand Larceny: every armed foe round the target is struck and disarmed too.
	p.flags.erase("steal_keep")
	p.flags["steal_all"] = true
	victim.weapon_id = "sword"
	var crowd: Array[Zombie] = []
	for k in 3:
		w.spawn_zombie("clever", victim.position + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 2.5)
		var other: Zombie = w.zombies.back()
		other.set_physics_process(false)
		other.hp = 1000.0
		other.max_hp = 1000.0
		other.weapon_id = ["sword", "spear", "mace"][k]
		crowd.append(other)
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.path_art_cd_left = 0.0
	BanditKit.cast_path(p)
	check(victim.weapon_id == "", "Grand Larceny disarms the target")
	check(crowd.all(func(o: Zombie) -> bool: return o.weapon_id == "" and o.hp < 1000.0), "and strikes and disarms every armed foe within 4 m of it: %s" % str(crowd.map(func(o: Zombie) -> String: return "%s %.0f %.1f m" % [o.weapon_id, o.hp, o.position.distance_to(victim.position)])))
	for o in crowd: o.release()
	p.flags.erase("steal_all")
	victim.release()
	# Steal goes for nothing when nothing is near.
	p.path_art_cd_left = 0.0
	BanditKit.cast_path(p)
	check(p.path_art_cd_left <= 0.5, "nothing to steal from costs no cooldown")
	# A robbed player keeps a class weapon or a last weapon, and drops anything else.
	pawn("ranger")
	p.slots = ["bow", "sword"]
	p.current = 1
	p._equip()
	BanditKit.be_robbed(p, false)
	check(p.slots[1] == null and p.weapon_id() == "bow", "a robbed player drops the weapon in hand")
	BanditKit.be_robbed(p, false)
	check(p.weapon_id() == "bow", "but never the last one")
	# Nightfall: friends inside vanish and stay hidden a moment, creatures inside barely see.
	pawn("bandit", 1)
	check(p.art_def()["name"] == "Into the Shadows" and p.path_art_def()["name"] == "Nightfall", "a Mercenary keeps Into the Shadows and gets Nightfall")
	var near := target(p.global_position + Vector3(4, 0, 0))
	BanditKit.cast_path(p)
	var dome: NightfallDome = w.find_children("Nightfall", "NightfallDome", false, false).back() if not w.find_children("Nightfall", "NightfallDome", false, false).is_empty() else null
	check(dome != null and is_equal_approx(dome.radius, BanditKit.NIGHT_RADIUS), "a dome of night rises")
	await frames(4)
	check(p.invis_left > 1.0, "the Mercenary inside it is invisible")
	check(near.blind_left > 0.0 and not near._can_see(p, p.global_position - near.position, 4.0), "a creature inside it cannot see four metres")
	p.global_position += Vector3(BanditKit.NIGHT_RADIUS + 3.0, 0, 0)
	await frames(2)
	check(p.invis_left > 1.0, "and the darkness lingers just after leaving")
	dome.queue_free()
	near.release()
	# The Highwayman's Dagger Fan, and Plunder.
	pawn("bandit", 2)
	check(p.art_def()["name"] == "Into the Shadows" and p.path_art_def()["name"] == "Dagger Fan", "a Highwayman keeps Into the Shadows and gets Dagger Fan")
	var before := w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size()
	BanditKit.dagger_fan(p)
	var thrown := w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size() - before
	check(thrown == BanditKit.FAN_KNIVES, "five knives in a fan (%d)" % thrown)
	p.mods["shadow_time"] = 0.0
	p.invis_left = 0.0
	for q: Projectile in w._projectiles: q.stop()
	BanditKit.dagger_fan(p)
	check(p.invis_left <= 0.0, "without Long Shadows a Dagger Fan does not hide the Highwayman")
	p.mods["shadow_time"] = 2.0
	p.invis_lockout = 0.0
	for q: Projectile in w._projectiles: q.stop()
	BanditKit.dagger_fan(p)
	check(is_equal_approx(p.invis_left, 2.0), "with Long Shadows it hides the Highwayman for 2 s (%.1f)" % p.invis_left)
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.mods["shadow_time"] = 0.0
	p.mods["fan_knives"] = 2.0
	for q: Projectile in w._projectiles: q.stop()
	BanditKit.dagger_fan(p)
	check(w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size() == 7, "More Blades adds two")
	for q: Projectile in w._projectiles: q.stop()
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	p.mods["plunder"] = 1.0
	var mark := target(p.global_position + Vector3(0, 0, -3))
	p.on_kill(mark)
	check(not w.pickups.is_empty() and w.pickups.back().kind in [Pickup.Kind.FOOD, Pickup.Kind.ARROWS, Pickup.Kind.POWER], "Plunder leaves something behind")
	mark.release()


## The Class Upgrades of the Cavalry and the Magician, one for each path.
func _new_upgrades() -> void:
	var owned_before: Dictionary = Game.owned_items.duplicate()
	for id: String in ["lance_charge", "consecration", "wild_hunt", "grave_call", "frost_nova", "hall_of_mirrors"]:
		Game.owned_items[id] = true
		var d: Dictionary = ShopDefs.ITEMS[id]
		check(d["section"] == "upgrades" and d["class"] in ["chivalry", "magician"] and int(d["price"]) >= 240 and int(d["price"]) <= 320, "%s is a Class Upgrade at the usual price" % id)
		check(Icons.exists(str(d["icon"]).split("+")[0]) and (not d.has("art") or Icons.exists(str(d["art"]["icon"]))), "%s has its icons" % id)
	check(["lancer", "paladin", "horse_archer", "necromancer", "elementalist", "illusionist"].all(func(spec: String) -> bool:
		return ShopDefs.ITEMS.values().any(func(i: Dictionary) -> bool: return i.get("spec", "") == spec)), "every Cavalry and Magician path has an upgrade")
	# Lance Charge: ten metres on, and what is in the way is struck and thrown aside.
	pawn("chivalry", 0)
	check(p.art_def()["name"] == "Lance Charge", "a Lancer with the upgrade has Lance Charge")
	p.rotation.y = 0.0
	p.yaw = 0.0
	var start := p.global_position
	var in_way := target(start + Vector3(0, 0, -4))
	var aside := target(start + Vector3(6, 0, -4))
	p.use_art()
	await frames(150)
	var went := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	check(went > UpgradeKit.CHARGE_REACH * 0.6 and went < UpgradeKit.CHARGE_REACH + 1.5, "Lance Charge carries the Lancer about 10 m (%.1f)" % went)
	check(in_way.hp < in_way.max_hp - UpgradeKit.CHARGE_DAMAGE * 0.9, "it strikes what is in the way (%.0f)" % (in_way.max_hp - in_way.hp))
	check(is_equal_approx(aside.hp, aside.max_hp), "and nothing off to the side")
	check(p.art_cd_left > 10.0, "then rests (%.0f s)" % p.art_cd_left)
	in_way.release()
	aside.release()
	# Consecration: friends heal inside, enemies burn.
	pawn("chivalry", 1)
	check(p.art_def()["name"] == "Consecration", "a Paladin with the upgrade has Consecration")
	var burnt := target(p.global_position + Vector3(3, 0, 0))
	p.hp = p.max_hp() * 0.5
	UpgradeKit.consecrate(p)
	await frames(400)
	check(p.hp > p.max_hp() * 0.5 + 4.0 and p.status_effects().any(func(e: Dictionary) -> bool: return e["icon"] == "heart+hand"), "the Paladin heals inside it, and the status bar says a friend is mending (%.0f)" % p.hp)
	check(burnt.burn_time > 0.0, "an enemy inside burns")
	for c: Node in w.get_children():
		if c is Consecration:
			c.queue_free()
	burnt.release()
	# Wild Hunt: the horse at once, and the arrows loose themselves at the nearest enemy.
	check(not ShopDefs.ITEMS.has("whistle") and ShopDefs.ITEMS["wild_hunt"]["spec"] == "horse_archer", "Wild Hunt has taken Whistle's place")
	var bought := {"whistle": true}
	Game.migrate_items(bought)
	check(bought == {"wild_hunt": true}, "whoever bought Whistle has Wild Hunt")
	pawn("chivalry", 2)
	p.horse_progress = 0
	check(p.art_def()["name"] == "Wild Hunt" and not p.horse_ready(), "a Horse Archer with Wild Hunt, and no horse yet")
	p.rotation.y = 0.0
	p.yaw = 0.0
	var prey := target(p.global_position + Vector3(0, 0, -12))
	var quiver := p.arrows
	UpgradeKit.wild_hunt(p)
	check(p.is_riding() and p.hunt_left > 0.0, "Wild Hunt brings the horse at once")
	await frames(150)
	check(prey.hp < prey.max_hp, "its arrows find the nearest enemy (%.0f)" % (prey.max_hp - prey.hp))
	check(p.arrows == quiver, "without spending arrows")
	await frames(300)
	check(p.hunt_left <= 0.0, "and the hunt ends after 6 s")
	prey.release()
	p.dismount()
	# Grave Call: the fallen nearby rise.
	pawn("magician", 0)
	check(p.art_def()["name"] == "Grave Call", "a Necromancer with the upgrade has Grave Call")
	p.mana = p.max_mana()
	p.art_cd_left = 0.0
	UpgradeKit.grave_call(p)
	check(p.art_cd_left == 0.0, "with nobody fallen, Grave Call costs nothing")
	for k in 4:
		var fallen := target(p.global_position + Vector3(2 + k, 0, 2))
		fallen.take_damage(100000.0, Vector3.ZERO, 0.0, fallen.centre())
	await frames(4)
	var before := w.allies.size()
	UpgradeKit.grave_call(p)
	check(w.allies.size() - before == UpgradeKit.GRAVE_RAISED, "three of the four fallen rise as skeletons (%d)" % (w.allies.size() - before))
	check(UpgradeKit.graves(p).size() == 1, "and those graves are spent")
	# Frost Nova: everything near freezes.
	pawn("magician", 1)
	check(p.art_def()["name"] == "Frost Nova", "an Elementalist with the upgrade has Frost Nova")
	var cold := target(p.global_position + Vector3(4, 0, 0))
	var far := target(p.global_position + Vector3(12, 0, 0))
	UpgradeKit.frost_nova(p)
	check(cold._stun > 1.5 and cold.hp < cold.max_hp and is_equal_approx(far.hp, far.max_hp), "Frost Nova freezes and hurts what is within 6 m, and nothing further")
	cold.release()
	far.release()
	# Hall of Mirrors: a big hit swaps the Illusionist away, once every 30 s.
	pawn("magician", 2)
	check(p.art_def()["name"] == "Mirror Swap", "an Illusionist keeps Mirror Swap on the button")
	var hp := p.hp
	var was_at := p.global_position
	p.hurt(p.max_hp() * 0.5, p.global_position + Vector3(0, 0, -1))
	check(is_equal_approx(p.hp, hp) and p.mirror_hall_left > 25.0, "a hit of half its health misses: Hall of Mirrors")
	check(w.allies.any(func(a: Ally) -> bool: return a.kind == "decoy"), "and a decoy is left behind (moved %.1f m)" % p.global_position.distance_to(was_at))
	p.guard_left = 0.0
	p.hurt(p.max_hp() * 0.5, p.global_position + Vector3(0, 0, -1))
	check(p.hp < hp, "the next one within 30 s lands")
	p.hp = p.max_hp()
	p.guard_left = 0.0
	p.mirror_hall_left = 0.0
	p.hurt(p.max_hp() * 0.1, p.global_position + Vector3(0, 0, -1))
	check(p.mirror_hall_left == 0.0, "and a small hit is never swapped away")
	Game.owned_items = owned_before


## The Class Upgrades of the Revenant, the Monk, the Plague Doctor, the Artificer and the Commander.
func _path_upgrades() -> void:
	var owned_before: Dictionary = Game.owned_items.duplicate()
	var ids := ["mist_wake", "torn_rifts", "soul_link", "dragon_spin", "fighting_body", "avalanche", "healing_mist", "plague_censer", "rat_tide",
		"great_keg", "field_turret", "tesla_coil", "arcane_surge", "grapeshot", "shield_wall"]
	for id: String in ids:
		Game.owned_items[id] = true
		var d: Dictionary = ShopDefs.ITEMS[id]
		check(d["section"] == "upgrades" and int(d["price"]) >= 260 and int(d["price"]) <= 320, "%s is a Class Upgrade at the usual price (%d)" % [id, int(d["price"])])
		check(Icons.exists(str(d["icon"]).split("+")[0]) and (str(d["icon"]).split("+").size() < 2 or Icons.exists(str(d["icon"]).split("+")[1])) and (not d.has("art") or Icons.exists(str(d["art"]["icon"]))), "%s has its icons" % id)
		check(UpgradeShowcase.shows(id), "%s has a scene of its own in the Store" % id)
	for cls: String in ["revenant", "monk", "plague_doctor", "artificer", "commander"]:
		for spec: Dictionary in AbilityData.tree(cls)["specs"]:
			check(ShopDefs.ITEMS.values().filter(func(i: Dictionary) -> bool: return i.get("spec", "") == spec["id"]).size() == 1, "%s's %s path has one Class Upgrade" % [cls, spec["id"]])
	var names: Array = ids.map(func(id: String) -> String: return ShopDefs.ITEMS[id]["name"])
	var clashes: Array[String] = []
	for cls: String in ClassDefs.ALL:
		for spec: Dictionary in AbilityData.tree(cls).get("specs", []):
			for row: Array in spec["path"]:
				for ab: Dictionary in row:
					if names.has(ab["name"]):
						clashes.append("%s (%s)" % [ab["name"], cls])
	check(clashes.is_empty(), "no new upgrade shares its name with an ability: %s" % ", ".join(clashes))
	# Mist Wake: a pool where the Mist Leaper lands.
	pawn("revenant", 0)
	var waded := target(p.global_position + Vector3(1, 0, 0))
	PathUpgrades.mist_wake(p)
	await frames(70)
	check(waded.hp < waded.max_hp and waded._slow > 0.0, "Mist Wake slows and hurts what stands in it (%.0f)" % (waded.max_hp - waded.hp))
	waded.release()
	_clear_fields()
	# Torn Rifts: every enemy the jump went through bursts afterwards.
	pawn("revenant", 1)
	var first := target(p.global_position + Vector3(0, 0, -5))
	var second := target(p.global_position + Vector3(6, 0, -5))
	p.mana = p.max_mana()
	p.use_art()
	await frames(120)
	var plain := p.m("rift_damage")
	check(first.max_hp - first.hp > plain + PathUpgrades.TORN_RIFT_DAMAGE * 0.9 and second.max_hp - second.hp > plain + PathUpgrades.TORN_RIFT_DAMAGE * 0.9, "both hopped enemies took the hop and the tear (%.0f, %.0f)" % [first.max_hp - first.hp, second.max_hp - second.hp])
	first.release()
	second.release()
	# Soul Link: a quarter of the hit to the Revenant, and strength back when one is struck down.
	pawn("revenant", 2)
	p._summon_revenants()
	var called: Ally = w.allies.filter(func(a: Ally) -> bool: return a.kind == "revenant" and not a.dead).back()
	var ally_hp := called.hp
	var hp := p.hp
	p.hurt(40.0, p.global_position + Vector3(0, 0, -1))
	check(is_equal_approx(hp - p.hp, 40.0 * p.m("damage_taken") * (1.0 - PathUpgrades.SOUL_LINK_SHARE)) and called.hp < ally_hp, "Soul Link: the Revenant takes a quarter of the hit (%.1f to you, %.1f to it)" % [hp - p.hp, ally_hp - called.hp])
	hp = p.hp
	called.hurt(10000.0, called.global_position)
	check(is_equal_approx(p.hp, minf(p.max_hp(), hp + PathUpgrades.SOUL_LINK_HEAL)), "and its fall heals 20")
	# Dragon Spin: three blows round the Bo Master after the vault.
	pawn("monk", 0)
	var spun := target(p.global_position + Vector3(2, 0, 0))
	PathUpgrades.dragon_spin(p)
	await frames(110)
	check(p.spin_hits == PathUpgrades.DRAGON_SPIN_HITS and spun.max_hp - spun.hp >= PathUpgrades.DRAGON_SPIN_DAMAGE * 3 * 0.9, "Dragon Spin strikes three times (%.0f)" % (spun.max_hp - spun.hp))
	spun.release()
	# Fighting Body: the body left behind strikes and holds.
	pawn("monk", 1)
	var close := target(p.global_position + Vector3(1.5, 0, 0))
	p._leave_body()
	await frames(80)
	check(close.max_hp - close.hp >= PathUpgrades.FIGHTING_BODY_DAMAGE * 0.9, "the body strikes what is close (%.0f)" % (close.max_hp - close.hp))
	var body: Ally = w.allies.filter(func(a: Ally) -> bool: return a.kind == "body" and not a.dead).back()
	var body_hp := body.hp
	body.hurt(100.0, body.global_position)
	check(is_equal_approx(body_hp - body.hp, 100.0 * (1.0 - PathUpgrades.FIGHTING_BODY_GUARD)), "and takes 30%% less (%.0f of 100)" % (body_hp - body.hp))
	p._come_back()
	close.release()
	# Avalanche: a second ring, twice as far, a moment later.
	pawn("monk", 2)
	p.stone_skin = Player.SKIN_MAX
	var distant := target(p.global_position + Vector3(12, 0, 0))
	p._mountain_stomp()
	check(is_equal_approx(distant.hp, distant.max_hp), "the stomp itself does not reach 12 m")
	await frames(60)
	check(distant.hp < distant.max_hp and distant._stun > 1.0, "the Avalanche does, and stuns")
	distant.release()
	# Healing Mist: friends mend and are cured inside it.
	pawn("plague_doctor", 0)
	p.hp = p.max_hp() * 0.5
	p.poison_left = 4.0
	p.burn_time = 3.0
	PathUpgrades.healing_mist(p)
	await frames(70)
	check(p.hp > p.max_hp() * 0.5 + PathUpgrades.HEALING_MIST_HEAL * 0.7 and p.poison_left == 0.0 and p.burn_time == 0.0, "Healing Mist mends and cures (%.0f)" % p.hp)
	_clear_fields()
	# Plague Censer: the cloud follows, and sickens what is in it.
	pawn("plague_doctor", 1)
	check(p.art_def()["name"] == "Plague Censer", "a Pestilence with the upgrade has the Plague Censer")
	var sick := target(p.global_position + Vector3(3, 0, 0))
	p.use_art()
	await frames(60)
	check(sick.poison_left > 0.0 and sick._slow > 0.0, "what is within 5 m is poisoned and slowed")
	var cloud: PathField = w.get_children().filter(func(n: Node) -> bool: return n is PathField and n.kind == "censer").back()
	p.global_position += Vector3(4, 0, 0)
	await frames(20)
	check(cloud.position.distance_to(p.global_position) < 0.5, "and the cloud goes where the Plague Doctor goes")
	sick.release()
	_clear_fields()
	# Rat Tide: everything in the line is bowled over, nothing beside it.
	pawn("plague_doctor", 2)
	check(p.art_def()["name"] == "Rat Tide", "a Rat King with the upgrade has the Rat Tide")
	p.rotation.y = 0.0
	p.yaw = 0.0
	var bowled := target(p.global_position + Vector3(0, 0, -6))
	var beside := target(p.global_position + Vector3(5, 0, -6))
	PathUpgrades.rat_tide(p)
	check(bowled.hp < bowled.max_hp and bowled._stun > 0.0 and is_equal_approx(beside.hp, beside.max_hp), "the tide strikes what is ahead, and not what is beside it")
	check(PathUpgrades.RAT_TIDE_DAMAGE == 30.0 and bowled.poison_left >= PathUpgrades.RAT_TIDE_POISON.y - 0.01 and beside.poison_left <= 0.0, "Rat Tide hits for 30 and poisons what it bites (%.1f s)" % bowled.poison_left)
	check(w.get_children().any(func(n: Node) -> bool: return n is RatTide), "and the rats are seen running")
	bowled.release()
	beside.release()
	# Great Keg: every fourth bomb.
	pawn("artificer", 0)
	var kegs := 0
	for k in 8:
		if PathUpgrades.next_is_keg(p):
			kegs += 1
	check(kegs == 2, "every fourth bomb is a Great Keg")
	var outside := target(p.global_position + Vector3(p.m("bomb_radius") * 1.6, 0, 0))
	p.bomb_burst(p.global_position + Vector3.UP * 0.5, PathUpgrades.GREAT_KEG_POWER)
	check(outside.hp < outside.max_hp, "and a keg reaches twice as far")
	outside.release()
	# Field Turret: a sentry, from the ability button.
	pawn("artificer", 1)
	check(p.art_def()["name"] == "Field Turret", "a Mechanic with the upgrade has the Field Turret")
	var sentries: int = w._sentries.size()
	PathUpgrades.field_turret(p)
	check(w._sentries.size() == sentries + 1 and is_equal_approx(float(w._sentries.back()["left"]), PathUpgrades.FIELD_TURRET_TIME), "it sets down a sentry for 20 s")
	# Tesla Coil: the first invention, and it strikes the four nearest.
	pawn("artificer", 2)
	check(p._next_invention == "tesla" and p._inventions().has("tesla"), "the Inventor's first invention is the Tesla Coil")
	var shocked: Array[Zombie] = []
	for k in 5:
		shocked.append(target(p.global_position + Vector3(2 + k, 0, 2)))
	PathUpgrades.tesla_coil(p)
	await frames(40)
	var struck := shocked.filter(func(z: Zombie) -> bool: return z.hp < z.max_hp).size()
	check(struck == PathUpgrades.TESLA_TARGETS, "the coil strikes the 4 nearest of 5 (%d)" % struck)
	for z in shocked:
		z.release()
	_clear_fields()
	# The Commander's three.
	pawn("commander", 0)
	check(PathUpgrades.bolt_every(p) == PathUpgrades.ARCANE_SURGE_EVERY, "Arcane Surge: a bolt every third attack")
	pawn("commander", 1)
	var shots: Array[bool] = []
	var loaded: Array[int] = []
	p.toast = ""
	p.grapeshot_flash = 0.0
	for k in 4:
		loaded.append(PathUpgrades.grapeshot_in(p))
		shots.append(PathUpgrades.grapeshot(p, p.eye_position(), -p.global_basis.z, WeaponDefs.ALL["musket"]))
	check(shots == Array([false, false, false, true], TYPE_BOOL, "", null), "Grapeshot: every fourth musket shot")
	check(loaded == Array([3, 2, 1, 0], TYPE_INT, "", null), "the HUD's marks count down to it: %s" % str(loaded))
	check(p.toast == "" and p.grapeshot_flash == 1.0, "it goes off with no word on the screen, only the burst round the crosshair (toast '%s')" % p.toast)
	var pellets := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.mesh == w._shot_mesh("pellet"))
	check(pellets.size() == PathUpgrades.GRAPESHOT_PELLETS, "its pellets fly as glowing iron, not as musket balls (%d)" % pellets.size())
	pawn("commander", 2)
	CommanderKit.cast(p)
	check(is_equal_approx(p.ward_hp, PathUpgrades.SHIELD_WALL_AMOUNT) and p.status_effects().any(func(e: Dictionary) -> bool: return str(e["icon"]).begins_with("shield_round")), "Command raises a Shield Wall, and the status bar shows it")
	hp = p.hp
	p.hurt(30.0 / p.m("damage_taken"), p.global_position + Vector3(0, 0, -1))
	check(is_equal_approx(p.hp, hp), "it stops a hit")
	p.hurt(30.0 / p.m("damage_taken"), p.global_position + Vector3(0, 0, -1))
	check(is_equal_approx(hp - p.hp, 20.0), "until its 40 are spent (%.1f got through)" % (hp - p.hp))
	Game.owned_items = owned_before


func _clear_fields() -> void:
	for n: Node in w.get_children():
		if n is PathField or n is RatTide:
			n.queue_free()


## Beacons straight in front of the Cartographer, at the given offsets, each faced north.
## The Class Upgrades of the Adept, the Cartographer and the Bandit (CrownUpgrades).
func _crown_upgrades() -> void:
	var owned_before: Dictionary = Game.owned_items.duplicate()
	var ids := ["encore", "shattered_mirror", "event_horizon", "star_shower", "open_door", "trailblazer", "lucky_fingers", "contract", "toll_road"]
	for id: String in ids:
		Game.owned_items[id] = true
		var d: Dictionary = ShopDefs.ITEMS[id]
		check(d["section"] == "upgrades" and int(d["price"]) >= 260 and int(d["price"]) <= 320, "%s is a Class Upgrade at the usual price (%d)" % [id, int(d["price"])])
		check(Icons.exists(str(d["icon"]).split("+")[0]) and Icons.exists(str(d["icon"]).split("+")[1]), "%s has its icons" % id)
		check(UpgradeShowcase.shows(id), "%s has a scene of its own in the Store" % id)
	for cls: String in ["adept", "cartographer", "bandit"]:
		for spec: Dictionary in AbilityData.tree(cls)["specs"]:
			check(ShopDefs.ITEMS.values().filter(func(i: Dictionary) -> bool: return i.get("spec", "") == spec["id"]).size() == 1, "%s's %s path has one Class Upgrade" % [cls, spec["id"]])
	var names: Array = ids.map(func(id: String) -> String: return ShopDefs.ITEMS[id]["name"])
	var clashes: Array[String] = []
	for cls: String in ClassDefs.ALL:
		for spec: Dictionary in AbilityData.tree(cls).get("specs", []):
			for row: Array in spec["path"]:
				for ab: Dictionary in row:
					if names.has(ab["name"]):
						clashes.append("%s (%s)" % [ab["name"], cls])
			if names.has(spec["final"]["name"]):
				clashes.append("%s (%s)" % [spec["final"]["name"], cls])
	check(clashes.is_empty(), "no upgrade shares its name with a talent: %s" % ", ".join(clashes))
	for sound: String in ["mirror_shatter", "encore", "rift_open", "rift_collapse", "coin_flip", "contract_seal"]:
		check(Sfx.NAMES.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	# Encore: every third change of stance, a wider, harder sweep that knocks everything down.
	pawn("adept", 0)
	var out_of_reach := target(p.global_position + Vector3(p.sweep_reach() + 1.2, 0, 0))
	var have: Array[int] = []
	for k in 3:
		have.append(CrownUpgrades.encore_have(p))
		var before := out_of_reach.hp
		p._change_stance()
		if k < 2:
			check(is_equal_approx(out_of_reach.hp, before), "change %d: the sweep does not reach %.1f m" % [k + 1, p.sweep_reach() + 1.2])
	check(have == Array([0, 1, 2], TYPE_INT, "", null) and p.readiness().any(func(e: Dictionary) -> bool: return e["key"] == "encore" and e["button"] == "art"), "the marks over the ability button count to it: %s" % str(have))
	check(out_of_reach.hp < out_of_reach.max_hp and out_of_reach._stun >= CrownUpgrades.ENCORE_DOWN - 0.05, "the third is the Encore: it reaches 2 m further and knocks down (%.0f, %.1f s)" % [out_of_reach.max_hp - out_of_reach.hp, out_of_reach._stun])
	out_of_reach.release()
	# Shattered Mirror: an undone hit sends shards at the nearest, and they bleed.
	pawn("adept", 1)
	var near_a := target(p.global_position + Vector3(3, 0, -2))
	var near_b := target(p.global_position + Vector3(-4, 0, -4))
	var too_far := target(p.global_position + Vector3(0, 0, CrownUpgrades.SHARD_REACH + 4.0))
	p._last_hit = 10.0
	p._last_hit_left = 1.0
	p._undo_hit()
	check(w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.mesh == w._shot_mesh("shard")).size() == CrownUpgrades.SHARDS, "the mirror breaks into 6 shards")
	await frames(40)
	var cut := (near_a.max_hp - near_a.hp) + (near_b.max_hp - near_b.hp)
	check(cut >= CrownUpgrades.SHARD_DAMAGE * CrownUpgrades.SHARDS * 0.9 and near_a.bleed_left > 0.0 and near_b.bleed_left > 0.0, "they strike the two nearest, 25 each, and leave them bleeding (%.0f)" % cut)
	check(is_equal_approx(too_far.hp, too_far.max_hp), "and nothing beyond 10 m")
	for z: Zombie in [near_a, near_b, too_far]:
		z.release()
	# Event Horizon: leaving Void stance opens a rift that pulls, bites and then collapses.
	pawn("adept", 2)
	var drawn := foe("normal", 5.0)
	drawn.stun(30.0)
	var start_gap := Vector2(drawn.position.x - p.global_position.x, drawn.position.z - p.global_position.z).length()
	var hp0 := drawn.hp
	p._left_void()
	var rift: PathField = w.get_children().filter(func(n: Node) -> bool: return n is PathField and n.kind == "horizon").back()
	check(rift != null, "leaving Void stance tears a rift open where the Adept stood")
	await frames(90)
	var gap := Vector2(drawn.position.x - rift.position.x, drawn.position.z - rift.position.z).length()
	check(gap < start_gap - 1.0 and drawn.hp < hp0, "it draws in what is within 7 m and hurts it (%.1f m from %.1f, %.0f)" % [gap, start_gap, hp0 - drawn.hp])
	var mid := drawn.hp
	await until_gone(PathField)
	check(mid - drawn.hp >= CrownUpgrades.HORIZON_COLLAPSE * 0.9, "and falls in on itself for 60 (%.0f)" % (mid - drawn.hp))
	drawn.release()
	# Star Shower: a stone that closes a constellation brings five stars down across it.
	pawn("cartographer", 0)
	var under := target(p.global_position + Vector3(0, 0, CartographerKit.PLANT_AHEAD - 6.0))
	var survey := plant_at([Vector3(-8, 0, 0), Vector3(8, 0, 0)])
	await frames(30)
	check(is_equal_approx(under.hp, under.max_hp), "two stones bring nothing down")
	plant_at([Vector3(0, 0, -14)])
	check(survey.triangles().size() == 1 and survey.in_constellation(under.position), "the third closes the constellation over it")
	await frames(150)
	check(under.max_hp - under.hp >= CrownUpgrades.SHOWER_DAMAGE, "the first star falls on it, the toughest inside (%.0f)" % (under.max_hp - under.hp))
	check(survey._shower_n == -1, "and all five have fallen")
	under.release()
	survey.queue_free()
	w.surveys.erase(p.net_id())
	await frames(1)
	# Open Door: a hit that would leave you low is never taken; you are at the farthest gate instead.
	pawn("cartographer", 1)
	survey = plant_at([Vector3(0, 0, 0), Vector3(24, 0, 0)])
	var home := p.global_position
	check(CrownUpgrades.door_ready(p) and p.readiness().any(func(e: Dictionary) -> bool: return e["key"] == "open_door" and e["primed"]), "with a gate far off, the door is ready, and the HUD says so")
	var full := p.hp
	p.hurt(p.max_hp() * 0.85 / p.m("damage_taken"), p.global_position + Vector3(0, 0, -1))
	var far_gate: Vector3 = survey.beacons[1]["at"]
	check(is_equal_approx(p.hp, minf(p.max_hp(), full + CrownUpgrades.DOOR_HEAL)) and Vector2(p.global_position.x - far_gate.x, p.global_position.z - far_gate.z).length() < 2.5, "the hit is never taken: the Traveler steps out of the far gate (%.1f m from it, %.0f health)" % [Vector2(p.global_position.x - far_gate.x, p.global_position.z - far_gate.z).length(), p.hp])
	check(p.guard_left > 0.0 and is_equal_approx(p.open_door_cd, CrownUpgrades.DOOR_REST), "untouchable for a moment, and not again for 60 s")
	p.guard_left = 0.0
	full = p.hp
	p.hurt(p.max_hp() * 0.85 / p.m("damage_taken"), p.global_position + Vector3(0, 0, -1))
	check(p.hp < full, "the next one lands")
	p.hp = p.max_hp()
	p.global_position = home
	survey.queue_free()
	w.surveys.erase(p.net_id())
	await frames(1)
	# Trailblazer: marks every 3 m while on the move, that speed friends and slow enemies.
	pawn("cartographer", 2)
	await frames(3)
	var from := p.global_position
	for k in 14:
		p.global_position = from + Vector3(0, 0, -0.8 * k)
		p.global_position.y = w.ground_at(p.global_position) + 0.02
		await frames(3)
	var marks := w.get_children().filter(func(n: Node) -> bool: return n is PathField and n.kind == "blaze")
	check(marks.size() >= 3, "a mark every 3 m along the way (%d over 10 m)" % marks.size())
	var first_mark: PathField = marks[0]
	var slowed := target(first_mark.position)
	p.global_position = first_mark.position + Vector3.UP * 0.05
	await frames(20)
	check(p._buffs.has("trailblazer") and slowed._slow > 0.0, "on the trail a friend runs faster, and an enemy is slowed")
	slowed.release()
	_clear_fields()
	# Lucky Fingers: every Steal picks a pocket, and every fourth is ready again at once.
	pawn("bandit", 0)
	w.spawn_zombie("clever", p.global_position + Vector3(0, 0, -8))
	var mark: Zombie = w.zombies.back()
	mark.set_physics_process(false)
	mark.hp = 5000.0
	mark.max_hp = 5000.0
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	var ready_after: Array[bool] = []
	for k in 4:
		p.path_art_cd_left = 5.0
		mark.weapon_id = ""
		BanditKit.cast_path(p)
		ready_after.append(p.path_art_cd_left <= 0.0)
	check(w.pickups.size() >= 4, "each Steal leaves food, arrows or a potion (%d)" % w.pickups.size())
	check(ready_after == Array([false, false, false, true], TYPE_BOOL, "", null), "and the fourth is lucky: ready again at once %s" % str(ready_after))
	mark.release()
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	# Contract: Nightfall names the toughest inside, it takes more, and its death pays.
	pawn("bandit", 1)
	var tough := target(p.global_position + Vector3(2, 0, -2))
	tough.max_hp = 600.0
	tough.hp = 600.0
	var small := target(p.global_position + Vector3(-2, 0, -1))
	small.max_hp = 75.0
	small.hp = 75.0
	BanditKit.nightfall(p)
	check(p.contract_on == tough and tough.get_node_or_null("ContractSeal") != null and small.get_node_or_null("ContractSeal") == null, "the Contract goes on the toughest, and its seal shows over it")
	var was_hp := tough.hp
	tough.take_damage(20.0, Vector3.ZERO, 0.0, tough.centre())
	check(is_equal_approx(was_hp - tough.hp, 20.0 * CrownUpgrades.CONTRACT_MARK), "it takes 50%% more (%.0f of 20)" % (was_hp - tough.hp))
	p.hp = 40.0
	p.path_art_cd_left = 20.0
	tough.next_hitter = -1
	tough.take_damage(10000.0, Vector3.ZERO, 0.0, tough.centre())
	await frames(2)
	check(is_equal_approx(p.hp, 40.0 + CrownUpgrades.CONTRACT_HEAL) and p.path_art_cd_left <= 20.0 - CrownUpgrades.CONTRACT_REFUND + 0.1, "its death heals 25 and brings Nightfall 8 s sooner (%.0f, %.1f s)" % [p.hp, p.path_art_cd_left])
	small.release()
	_clear_fields()
	for n: Node in w.get_children():
		if n is NightfallDome:
			n.queue_free()
	# Toll Road: every third fan pins, and what dies pinned always pays.
	pawn("bandit", 2)
	_face_ahead()
	var tolled := target(p.global_position + Vector3(0, 0, -6))
	var counted: Array[int] = []
	for k in 3:
		counted.append(CrownUpgrades.toll_have(p))
		BanditKit.dagger_fan(p)
	check(counted == Array([0, 1, 2], TYPE_INT, "", null) and p.readiness().any(func(e: Dictionary) -> bool: return e["key"] == "toll_road" and e["button"] == "path_art"), "marks over the second button count the fans: %s" % str(counted))
	var gold := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.toll)
	check(gold.size() == BanditKit.FAN_KNIVES + int(p.m("fan_knives")) and p.toll_fan, "the third fan is the Toll: its knives gleam gold (%d)" % gold.size())
	await frames(30)
	check(tolled.root_left > 0.0 and tolled.tolled(), "and pin what they strike")
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	p.mods["plunder"] = 0.0
	tolled.next_hitter = -1
	p.on_kill(tolled)
	check(w.pickups.size() == 1, "a creature killed while pinned always leaves plunder")
	tolled.release()
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	Game.owned_items = owned_before


## The Trappers' Guild, with the Valleys' marks laid out on the test ground: its snares, its hunters,
## its caches and its fallback camp, by level.
func _trappers_guild() -> void:
	var d: Dictionary = ShopDefs.ITEMS[TrappersGuild.ID]
	check(d["section"] == "maps" and d["map"] == "mesenlla" and (d["levels"] as Array).size() == ShopDefs.MAP_LEVELS and Icons.exists(str(d["icon"])) and UpgradeShowcase.shows(TrappersGuild.ID), "the Trappers' Guild is a Map Upgrade of the Valleys, with four levels, its icon and its scene")
	check(Ally.KINDS.find("lodge_hunter") == Ally.KINDS.find("mist_heavy") + 1 and Ally.GARRISON.has("lodge_hunter"), "the Lodge hunter is a new kind after the Mist Bastion's garrison, and keeps watch like it")
	for sound: String in ["snare_snap", "trapper_horn", "cache_drop"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound, heard on every phone" % sound)
	var tscn := FileAccess.get_file_as_string("res://maps/mesenlla.tscn")
	for kind: String in ["snare", "hunter", "trap_cache", "guild_camp"]:
		check(tscn.contains('kind = "%s"' % kind), "the Valleys mark where the Guild's %s goes" % kind)
	pawn("ranger")
	await frames(3)
	var home := p.global_position
	var marks_before := w.guild_marks.duplicate()
	w.guild_marks.assign([
		{"kind": "snare", "gate": 3, "at": home + Vector3(0, 0, -10), "yaw": 0.0},
		{"kind": "hunter", "gate": 2, "at": home + Vector3(-6, 0, 4), "yaw": 0.0},
		{"kind": "hunter", "gate": 4, "at": home + Vector3(8, 0, 4), "yaw": 0.0},
		{"kind": "hunter", "gate": 4, "at": home + Vector3(10, 0, 6), "yaw": 0.0},
		{"kind": "trap_cache", "gate": 0, "at": home + Vector3(3, 0, 3), "yaw": 0.0},
		{"kind": "trap_cache", "gate": 1, "at": home + Vector3(-3, 0, 3), "yaw": 0.0},
		{"kind": "guild_camp", "gate": 0, "at": home + Vector3(12, 0, 0), "yaw": 0.0}])
	# Level 1: snares only.
	var guild := TrappersGuild.new(w, 1)
	w.add_child(guild)
	w.guild = guild
	check(guild.snares.size() == 3 and guild.camp_at == Vector3.INF, "Level 1 lays its line of 3 snares, and no camp")
	var line_gap: float = (guild.snares[0]["at"] as Vector3).distance_to(guild.snares[1]["at"])
	check(absf(line_gap - TrappersGuild.SNARE_GAP * 1.0) < 0.3, "2 m apart along the line (%.1f)" % line_gap)
	var walker := foe("normal", 10.0, 0.0, 200.0)
	walker.position = guild.snares[1]["at"]
	await frames(4)
	check(walker.root_left > 0.0 and is_equal_approx(walker.hp, 200.0 - TrappersGuild.SNARE_DAMAGE), "a creature that steps in a snare is held and cut for 15 (%.0f)" % walker.hp)
	check(float(guild.snares[1]["armed_at"]) > w.now + TrappersGuild.SNARE_REARM - 0.5 and (guild.snares[1]["node"] as MeshInstance3D).mesh == TrappersGuild.snare_mesh(true), "the snare shows sprung, and is set again in 12 s")
	walker.root_left = 0.0
	walker.position = guild.snares[1]["at"] + Vector3(0.1, 0, 0)
	var held_hp := walker.hp
	await frames(4)
	check(is_equal_approx(walker.hp, held_hp), "a sprung snare catches nothing until it is set again")
	walker.release()
	check(w.allies.filter(func(a: Ally) -> bool: return a.kind == "lodge_hunter" and not a.dead).is_empty(), "no hunters at Level 1")
	guild.queue_free()
	await frames(1)
	# Level 4: hunters at their posts (no towers on this ground), caches, and the camp's fire and snares.
	w.prepare_allies("lodge_hunter", 4)
	guild = TrappersGuild.new(w, 4)
	w.add_child(guild)
	w.guild = guild
	await frames(3)
	check(guild.camp_at != Vector3.INF and guild.snares.size() == 3 + TrappersGuild.CAMP_SNARES, "Level 4 makes the fallback camp, ringed with 6 snares")
	var hunters := w.allies.filter(func(a: Ally) -> bool: return a.kind == "lodge_hunter" and not a.dead)
	check(hunters.size() == 2 and hunters.all(func(a: Ally) -> bool: return a.is_garrison() and a.perch == Vector3.INF), "its two hunters stand guard by the camp (%d)" % hunters.size())
	var prey := foe("normal", 0.0, 0.0, 5000.0)
	prey.position = home + Vector3(4, 0, 1)
	prey.position.y = w.ground_at(prey.position)
	prey.stun(30.0)
	await frames(200)
	check(prey.hp < 5000.0, "the hunters shoot what comes near (%.0f)" % (5000.0 - prey.hp))
	prey.release()
	p.global_position = guild.camp_at + Vector3(1.5, 0.05, 0)
	p.hp = p.max_hp() * 0.5
	var low := p.hp
	await frames(60)
	check(p.hp > low + TrappersGuild.FIRE_HEAL * 0.6, "a friend by the camp fire mends 3 a second (%.1f)" % (p.hp - low))
	p.global_position = home
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	w.director.elapsed = TrappersGuild.CACHE_EVERY + 0.5
	await frames(2)
	var first_cache := w.pickups.filter(func(i: Pickup) -> bool: return i.global_position.distance_to(guild.cache_spot()) < 1.0)
	check(first_cache.size() == 1 and (first_cache[0] as Pickup).kind == Pickup.Kind.FOOD, "after 60 s a cache by the fire: food first")
	w.director.elapsed = TrappersGuild.CACHE_EVERY * 2.0 + 1.0
	await frames(2)
	check(w.pickups.size() == 1, "and none on top of it while it is still lying there")
	w.remove_pickup(first_cache[0])
	w.director.elapsed = TrappersGuild.CACHE_EVERY * 3.0 + 1.5
	await frames(2)
	check(w.pickups.size() == 1 and w.pickups[0].kind == Pickup.Kind.ARROWS, "once taken, the next: arrows")
	# A hunter struck down is replaced from the Lodge after a while.
	var fallen: Ally = hunters[0]
	fallen.hurt(10000.0, fallen.global_position)
	await frames(2)
	var spot: Dictionary = guild.hunters.filter(func(h: Dictionary) -> bool: return h["ally"] == fallen)[0]
	check(float(spot["back_at"]) > w.now, "a hunter struck down is missed")
	spot["back_at"] = w.now - 0.1
	await frames(2)
	check(spot["ally"] != fallen and (spot["ally"] as Ally).kind == "lodge_hunter" and not (spot["ally"] as Ally).dead, "and another comes from the Lodge in its place")
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	w.director.elapsed = 0.0
	guild.queue_free()
	w.guild = null
	for ally: Ally in w.allies.duplicate():
		w.remove_ally(ally)
	w.guild_marks.assign(marks_before)
	await frames(1)


func plant_at(spots: Array) -> SurveyNet:
	var start := p.global_position
	for spot: Vector3 in spots:
		p.global_position = Vector3(start.x + spot.x, w.ground_at(start + spot) + 0.05, start.z + spot.z + CartographerKit.PLANT_AHEAD)
		p.yaw = 0.0
		p.rotation.y = 0.0
		CartographerKit.cast(p)
	p.global_position = start
	return w.surveys.get(p.net_id())


func _cartographer() -> void:
	var d: Dictionary = ClassDefs.ALL["cartographer"]
	check(d["weapon"] == "spear" and ClassDefs.price("cartographer") == 0 and not ClassDefs.for_sale().has("cartographer") and d.get("earned", "") == "beyond", "the Cartographer starts with a Spear and is earned beyond the Mists, not bought")
	check(ClassDefs.weapon_categories("cartographer") == Array(["melee", "ranged", "exclusive"], TYPE_STRING, "", null), "Cartographer wields Melee and Ranged weapons, and the Pathfinder's own")
	check(Game.CODES.values().has("cartographer"), "a Cartographer code exists, kept only as a hash")
	var specs: Array = AbilityData.tree("cartographer")["specs"].map(func(x: Dictionary) -> String: return x["id"])
	check(specs == ["star_reader", "worlds_traveler", "pathfinder"], "Star Reader, Worlds Traveler and Pathfinder")
	for id: String in ["crest_cartographer", "spec_star_reader", "spec_worlds_traveler", "spec_pathfinder", "beacon", "link", "waygate", "machete", "bolas", "lantern", "compass"]:
		check(ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s icon" % id)
	for sound: String in ["beacon_plant", "waygate", "starlight", "falling_star", "unearth", "bolas_throw", "bolas_wrap"]:
		check(Sfx.NAMES.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	# Linked beacons: speed near one, mending on a line, marks near one, and only three at a time.
	pawn("cartographer")
	check(p.art_def()["name"] == "Plant Beacon", "the Cartographer's ability is Plant Beacon")
	p.use_art()
	check(p._cast_kind == "cartographer", "it casts as the Cartographer")
	await frames(90)
	var survey: SurveyNet = w.surveys.get(p.net_id())
	check(survey != null and survey.beacons.size() == 1, "a beacon stands in front of the Cartographer")
	survey.queue_free()
	w.surveys.erase(p.net_id())
	await frames(1)
	survey = plant_at([Vector3(0, 0, 0), Vector3(12, 0, 0), Vector3(6, 0, -10)])
	check(survey.beacons.size() == 3 and survey.links().size() == 3, "three beacons, all linked")
	var a: Vector3 = survey.beacons[0]["at"]
	var b: Vector3 = survey.beacons[1]["at"]
	p.global_position = Vector3(a.x + 1.0, w.ground_at(a) + 0.05, a.z + 1.0)
	await frames(4)
	check(p._buffs.has("beacon_speed"), "near a beacon a friend runs faster")
	var mid := (a + b) * 0.5
	p.global_position = Vector3(mid.x, w.ground_at(mid) + 0.05, mid.z)
	p.hp = 50.0
	await frames(60)
	check(p.hp > 50.0, "on the line between two beacons a friend mends (%.1f)" % p.hp)
	var watched := target(a + Vector3(3, 0, 3))
	await frames(80)
	check(watched.reveal_left > 0.0, "an enemy near a beacon is marked")
	watched.release()
	plant_at([Vector3(30, 0, 30)])
	check(survey.beacons.size() == 3 and survey.beacons[0]["at"] == b, "a fourth beacon pulls up the oldest")
	survey.queue_free()
	w.surveys.erase(p.net_id())
	# Star Reader: a constellation strengthens friends inside and strikes creatures with starlight.
	pawn("cartographer", 0)
	check(p.art_def()["name"] == "Set a Star Stone", "Star Reader sets Star Stones")
	survey = plant_at([Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(0, 0, -14)])
	check(survey.kind() == "stars" and survey.triangles().size() == 1, "three linked stones hold a constellation")
	var inside: Vector3 = (Vector3(survey.beacons[0]["at"]) + survey.beacons[1]["at"] + survey.beacons[2]["at"]) / 3.0
	check(survey.in_constellation(inside) and not survey.in_constellation(inside + Vector3(0, 0, 30)), "and it covers the space between them")
	p.global_position = Vector3(inside.x, w.ground_at(inside) + 0.05, inside.z)
	var under := target(inside + Vector3(1.5, 0, 0))
	await frames(4)
	check(p._buffs.has("stars_melee_damage") and is_equal_approx(p.m("melee_damage"), 1.0 + CartographerKit.STAR_BONUS), "friends inside deal 20% more damage")
	var hp0 := under.hp
	await frames(int(SurveyNet.STAR_EVERY * 240) + 30)
	check(under.hp < hp0, "starlight strikes creatures inside (%.0f)" % (hp0 - under.hp))
	under.release()
	survey.queue_free()
	w.surveys.erase(p.net_id())
	# Worlds Traveler: step into one gate and out of the next.
	pawn("cartographer", 1)
	check(p.art_def()["name"] == "Raise a Waygate", "Worlds Traveler raises Waygates")
	survey = plant_at([Vector3(0, 0, 0), Vector3(16, 0, 0)])
	var gate_a: Vector3 = survey.beacons[0]["at"]
	var gate_b: Vector3 = survey.beacons[1]["at"]
	p.gate_rest_left = 0.0
	p.global_position = Vector3(gate_a.x, w.ground_at(gate_a) + 0.05, gate_a.z)
	await frames(3)
	check(SurveyNet._flat(p.global_position, gate_b) < 2.5, "stepping into a Waygate comes out of the next (%.1f m)" % SurveyNet._flat(p.global_position, gate_b))
	check(p._buffs.has("gate_speed") and p.gate_rest_left > 2.0, "with a burst of speed, and a rest before the next passage")
	var rested := p.global_position
	p.global_position = Vector3(gate_b.x, w.ground_at(gate_b) + 0.05, gate_b.z)
	await frames(3)
	check(SurveyNet._flat(p.global_position, gate_b) < 0.5, "not again until the rest is over")
	# Learning Veiled Passage and Rift Road works on the gates already standing.
	check(not survey.has("gate_hide") and not survey.has("rift_road"), "these gates were raised before Veiled Passage and Rift Road")
	p.flags["gate_hide"] = true
	p.flags["rift_road"] = true
	CartographerKit.retune(p)
	check(survey.has("gate_hide") and survey.has("rift_road") and survey.beacons.size() == 2, "learning them reaches the gates already raised")
	p.gate_rest_left = 0.0
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.global_position = Vector3(gate_a.x, w.ground_at(gate_a) + 0.05, gate_a.z)
	await frames(3)
	check(SurveyNet._flat(p.global_position, gate_b) < 2.5 and p.invis_left > 1.5, "Veiled Passage hides you coming out of an old gate (%.1f s)" % p.invis_left)
	p.global_position = gate_b + Vector3(30, 0, 0)
	var walker := target(gate_a + Vector3(0.6, 0, 0))
	await frames(3)
	check(SurveyNet._flat(walker.position, gate_b) < 2.5 and walker._stun > 0.0, "and Rift Road throws a creature walking into it out of the far gate, stunned")
	walker.release()
	survey.queue_free()
	w.surveys.erase(p.net_id())
	# Pathfinder: new ground unearths finds only a Pathfinder can use.
	pawn("cartographer", 2)
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	survey = plant_at([Vector3(0, 0, 0)])
	var finds := w.pickups.filter(func(i: Pickup) -> bool: return i.item_id in CartographerKit.FINDS)
	check(finds.size() == 1 and p.find_rest_left > 25.0, "a Pathfinder's beacon unearths a find, then rests")
	plant_at([Vector3(20, 0, 0)])
	check(w.pickups.filter(func(i: Pickup) -> bool: return i.item_id in CartographerKit.FINDS).size() == 1, "not again before the rest is over")
	check(p.can_use("machete") and p.can_use("bolas"), "the Pathfinder can wield the Machete and the Bolas")
	pawn("cartographer", 0)
	check(not p.can_use("machete") and not p.can_use("bolas"), "another Cartographer cannot")
	pawn("infantry")
	check(not p.can_use("machete"), "nor any other class")
	check(not WeaponDefs.lies_around("machete") and not WeaponDefs.lies_around("bolas") and not PowerDefs.pick_potion() == "lantern", "finds are never ordinary loot")
	check(WeaponDefs.category("machete") == "exclusive" and WeaponDefs.category("bolas") == "exclusive", "the Codex calls them Exclusive Weapons")
	pawn("cartographer", 2)
	var pace := p.m("speed")
	p.activate_power("lantern")
	check(p.has_power("lantern") and (p._light == null or p._light.omni_range > 17.0), "the Wayfinder's Lantern lights the way")
	check(is_equal_approx(CartographerKit.LANTERN_SPEED, 1.15) and is_equal_approx(p.m("speed"), pace), "and quickens the step through movement, not a skill bonus")
	for left: SurveyNet in w.surveys.values():
		if is_instance_valid(left):
			left.queue_free()
	w.surveys.clear()

## A creature of the kind asked for, `ahead` metres in front of the player, standing still.
func foe(kind: String, ahead: float, side := 0.0, hp := 10000.0) -> Zombie:
	var at := p.global_position + Vector3(side, 0, -ahead)
	at.y = w.ground_at(at)
	w.spawn_zombie(kind, at)
	var z: Zombie = w.zombies.back()
	z.position = at
	z.hp = hp
	z.max_hp = hp
	return z


## Frames go by until nothing of this kind is left in the world (a wave rolled out, a soul landed):
## frames come faster or slower with the machine, the game's own clock does not.
func until_gone(kind: Variant) -> void:
	for i in 600:
		if not w.get_children().any(func(n: Node) -> bool: return is_instance_of(n, kind)):
			break
		await frames(1)
	await frames(2)


func _face_ahead() -> void:
	p.yaw = 0.0
	p.rotation.y = 0.0
	p.pitch = 0.0
	if p.camera:
		p.camera.rotation = Vector3.ZERO


func _class_codes() -> void:
	# Every class that is not free from the start can be opened with a code (the codes themselves are
	# kept out of the repository: only their hashes are in the game).
	var coded := Game.CODES.values()
	for id: String in ClassDefs.ALL:
		var d: Dictionary = ClassDefs.ALL[id]
		if d.get("hidden", false) and not ClassDefs.disabled(id):
			check(coded.has(id), "%s can be opened with a code" % d["name"])


## Lets a leap run its course, frame by frame, as it would in play.
func _leap_through() -> void:
	for i in 120:
		if p._leap_t < 0.0:
			return
		await get_tree().physics_frame


func _ascendant() -> void:
	var d: Dictionary = ClassDefs.ALL["ascendant"]
	check(d["weapon"] == "ruin_greataxe" and d.get("earned", "") == "archipelago" and not ClassDefs.for_sale().has("ascendant") and ClassDefs.available().has("ascendant") == Game.owns_class("ascendant"), "the Ascendant starts with the Ruin-Breaker Greataxe and is earned in the Archipelagos")
	check(ClassDefs.weapon_categories("ascendant") == Array(["melee", "two_handed", "ranged"], TYPE_STRING, "", null), "it wields Melee, Two-Handed and Ranged weapons")
	var specs: Array = AbilityData.tree("ascendant")["specs"]
	check(specs.map(func(x: Dictionary) -> String: return x["id"]) == ["godslayer", "adorer", "adorer_pelagros"], "the Ascendant has the Godslayer and both god professions")
	check(not specs[0].has("earned") and specs[1].get("earned", "") == "adorer" and specs[2].get("earned", "") == "adorer_pelagros", "the Godslayer is open and the two god professions must be earned")
	for id: String in ["crest_ascendant", "spec_godslayer", "spec_adorer", "spec_adorer_pelagros", "ascend", "deicide", "elixir", "rite_break", "ruin_greataxe"]:
		check(Icons.exists(id), "%s icon" % id)
	for sound: String in ["ascend_leap", "ascend_crash", "deicide_strike", "rite_break", "elixir_drink", "change_end"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	check(ClassGear._pieces("ascendant").has("hips:glow") and Avatar.MODELS.has("ascendant") and ClassPresentation.COPY.has("ascendant"), "dressed, seen by others, and described")
	# Earned by playing a match on Fontanova to its end, won or lost; the Adorer by winning there as one.
	var had: Dictionary = Game.unlocked.duplicate()
	var had_specs: Dictionary = Game.earned_specs.duplicate()
	var was_mode := Game.mode
	var was_map := Game.night_map
	var was_class := Game.player_class
	var games := Game.finished_games
	Game.unlocked.erase("ascendant")
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "vael"
	Game.note_game_finished()
	check(not Game.owns_class("ascendant") and Game.earn_text("ascendant").contains("Fontanova"), "a match elsewhere does not earn it, and it says to play on Fontanova")
	Game.night_map = "fontanova"
	Game.note_game_finished()
	check(Game.owns_class("ascendant") and Game.fresh_unlocks.has("ascendant"), "a match on Fontanova, played to its end, earns the Ascendant")
	Game.fresh_unlocks.erase("ascendant")
	Game.earned_specs.erase("adorer")
	Game.player_class = "infantry"
	Game.note_beyond_win()
	check(not Game.earned_specs.has("adorer"), "a win on Fontanova as another class does not earn the Adorer")
	Game.player_class = "ascendant"
	Game.night_map = "vael"
	Game.note_beyond_win()
	check(not Game.earned_specs.has("adorer"), "nor a win elsewhere as the Ascendant")
	Game.night_map = "fontanova"
	Game.note_beyond_win()
	check(Game.earned_specs.has("adorer") and Game.fresh_specs.has("adorer") and Game.owns_spec(specs[1]), "a win on Fontanova as the Ascendant earns the Adorer of Al'quimelea")
	Game.fresh_specs.clear()
	Game.earned_specs.erase("adorer")
	Game.mode = Game.Mode.SANDBOX
	Game.note_beyond_win()
	check(not Game.earned_specs.has("adorer"), "but not in the Sandbox")
	Game.unlocked = had
	Game.mode = was_mode
	Game.night_map = was_map
	Game.player_class = was_class
	Game.finished_games = games
	# Not yet earned, the Adorer cannot be taken; its card says how to earn it. Earned, it can. A bot never takes it.
	Game.earned_specs.erase("adorer")
	pawn("ascendant")
	p.points = 4
	for step in Player.CORE_STEPS:
		p.choose_ability(step, 0)
	check(not p.spec_open(specs[1]) and not p.choose_ability(Player.CORE_STEPS, 1) and p.spec_id == "", "the Adorer, not yet earned, cannot be taken")
	check(Game.spec_earn_text(specs[1]).contains("Fontanova") and Game.spec_earn_text(specs[1]).contains("Ascendant"), "and it says how to earn it")
	var panel := TreePanel.new()
	panel.theme = UiTheme.make()
	panel.player = p
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.build()
	await frames(1)
	var locked := panel.find_children("LockedCard", "Button", true, false)
	check(locked.size() == 1 and (locked[0] as Button).disabled and (locked[0] as Button).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == Game.spec_earn_text(specs[1])), "the profession card is locked, and says how to earn it")
	# Tapped on the map, the locked profession reads in full, its words inside the panel.
	var entry_node: Variant = null
	for n: Node in panel.find_children("*", "", true, false):
		if n.get("ability") is Dictionary and str(n.get("ability").get("id", "")) == "adorer_entry":
			entry_node = n
	panel.read(entry_node)
	await frames(2)
	var words := panel._zone.find_children("*", "Label", true, false)
	var how := words.filter(func(l: Label) -> bool: return l.text == Game.spec_earn_text(specs[1]))
	var inside := words.all(func(l: Label) -> bool: return l.get_global_rect().end.x <= panel.get_global_rect().end.x + 1.0)
	check(how.size() == 1 and (how[0] as Label).autowrap_mode != TextServer.AUTOWRAP_OFF and inside, "read on the map, the locked profession says how to earn it, and every line stays inside the panel")
	panel.queue_free()
	Game.earned_specs["adorer"] = true
	check(p.spec_open(specs[1]) and p.choose_ability(Player.CORE_STEPS, 1) and p.spec_id == "adorer", "earned, it can be taken")
	p.bot_peer = 77
	check(not p.spec_open(specs[1]) and p.spec_open(specs[0]), "a bot never takes a profession that has to be earned")
	p.bot_peer = 0
	# Ascend: up, and down on everything near where it lands.
	pawn("ascendant")
	_face_ahead()
	check(p.weapon_id() == "ruin_greataxe" and p.art_def()["name"] == "Ascend", "it holds the Greataxe and has Ascend")
	var near_a := foe("normal", AscendantKit.ASCEND_REACH - 1.0, -0.6)
	var near_b := foe("normal", AscendantKit.ASCEND_REACH - 1.0, 0.6)
	var far := foe("normal", 2.0, 9.0)
	for z: Zombie in [near_a, near_b, far]:
		z.set_physics_process(false) # they stand where they are put, so what is measured is the leap
	var a0 := near_a.hp
	var f0 := far.hp
	var from := p.global_position
	AscendantKit.ascend(p)
	check(p._leap_t >= 0.0 and p.ascending == "ascend", "Ascend leaps")
	await _leap_through()
	var landed := p.global_position
	var gap := Vector2(near_a.position.x - landed.x, near_a.position.z - landed.z).length()
	check(p.ascending == "" and near_a.hp < a0 and near_b._stun > 0.0 and is_equal_approx(far.hp, f0),
		"and comes down on what is near where it lands, stunning it, and nothing further (leapt %.1f m; %.1f m from the nearest; it took %.0f)" % [Vector2(landed.x - from.x, landed.z - from.z).length(), gap, a0 - near_a.hp])
	check(is_equal_approx(AscendantKit.damage_scale(p, near_a), 1.0), "a lesser enemy takes no more than anyone's blow (the divine are tried on Fontanova: dev_features)")
	# Godslayer: Deicide ends what is low, and breaks what is being readied, even a miniboss's.
	pawn("ascendant", 0, true)
	_face_ahead()
	check(p.art_def()["name"] == "Deicide", "a Godslayer's Ascend is Deicide")
	var low := foe("normal", 6.0, 0.0, 1000.0)
	low.hp = 200.0
	AscendantKit.deicide(p)
	check(p.deicide_on == low, "it leaps on the enemy it faces")
	await _leap_through()
	check(not low.is_alive(), "and ends it, below %d%% health" % roundi(AscendantKit.execute_below(p) * 100.0))
	# Adorer: the Elixir of Change.
	pawn("ascendant", 1, true)
	_face_ahead()
	check(p.art_def()["name"] == "Elixir of Change", "an Adorer's Ascend is the Elixir of Change")
	var in_field := foe("normal", 2.0)
	var outside := foe("normal", 9.0)
	for z: Zombie in [in_field, outside]:
		z.set_physics_process(false) # where they are put: one in the field, one well out of it
	var speed := p.m("speed")
	AscendantKit.drink(p)
	check(is_equal_approx(p.changed_left, AscendantKit.changed_time(p)) and is_equal_approx(p.m("speed"), speed + AscendantKit.CHANGED_SPEED), "it drinks and is Changed, quicker")
	await get_tree().create_timer(AscendantKit.FIELD_TELL + 0.15).timeout
	check(in_field.poison_left > 0.0 and in_field.root_left > 0.0 and outside.poison_left <= 0.0, "the field of change poisons and holds what is still in it")
	var struck := foe("normal", 1.5, 2.0)
	p.on_melee_connect(struck, WeaponDefs.ALL["ruin_greataxe"])
	check(struck.poison_left > 0.0, "Changed, its blows poison")
	check(is_equal_approx(AscendantKit.hurt_scale(p), 1.0 - AscendantKit.THICK_HIDE) or not p.has_flag("thick_hide"), "Thick Hide: less harm while Changed")
	var ring := foe("normal", 2.5, 2.5)
	var r0 := ring.hp
	p.flags["crucible"] = true
	p.changed_left = 0.01
	AscendantKit.tick(p, 0.02)
	check(p.changed_left == 0.0 and not p._buffs.has("changed") and ring.hp < r0 and ring.burn_time > 0.0, "the change ends, and its Crucible Heart bursts out")
	Game.earned_specs = had_specs
	pawn("infantry")


## Fontanova's three weapons, the Honeycomb familiar and the Mysterious Flask.
func _fonta_finds() -> void:
	for id: String in ["censer_flail", "resin_repeater", "ruin_greataxe"]:
		var wd: Dictionary = WeaponDefs.ALL[id]
		check(WeaponDefs.lies_around(id) and SpawnRules.allows(wd, "fontanova") and not SpawnRules.allows(wd, "village") and WeaponDefs.mesh(id) != null and Icons.weapon(id) == id and ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s lies about only on Fontanova, with its own model and icon" % id)
		check(str(wd.get("lore", "")).length() > 40 and not RegEx.create_from_string("\\d").search(str(wd["lore"])), "%s has a story of its own, with no numbers in it" % id)
	check(WeaponDefs.category("censer_flail") == "melee" and WeaponDefs.category("resin_repeater") == "ranged" and WeaponDefs.category("ruin_greataxe") == "two_handed", "one melee, one ranged, one two-handed")
	for sound: String in ["censer_swing", "censer_ready", "censer_release", "repeater_shot", "greataxe_swing", "honeycomb_hum", "honey_forage", "flask_drink", "flask_sour"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	# The Censer Flail: packed by each blow that lands, then a release all round.
	pawn("infantry")
	_face_ahead()
	p.slots = ["censer_flail", null]
	p.current = 0
	p._equip()
	var cd: Dictionary = WeaponDefs.ALL["censer_flail"]
	var front := foe("normal", 1.6)
	front.stun(60.0)
	for i in int(cd["censer"]):
		p._do_melee_hit()
	check(p.censer == int(cd["censer"]), "%d blows that land fill the censer" % int(cd["censer"]))
	var behind := foe("normal", -2.4)
	behind.stun(60.0)
	var b0 := behind.hp
	p._do_melee_hit()
	check(p.censer == 0 and behind.hp < b0 and behind.poison_left > 0.0, "the next swing is its release: it strikes all round, behind too, and its smoke poisons")
	# The Resin Repeater: harder into what flies.
	pawn("infantry")
	_face_ahead()
	var bee := foe("normal", 6.0)
	bee.flies = true # what counts is that it flies (Fontanova's bees are tried there)
	var walker := foe("normal", 6.0, 3.0)
	bee.set_physics_process(false)
	walker.set_physics_process(false)
	p.slots = ["resin_repeater", null]
	p._equip()
	var shot := w.spawn_player_arrow(p, p.eye_position(), Vector3(0, 0, -50), 0.6, 34.0, 1.0, 20.0)
	var e0 := bee.hp
	shot._hit_zombie(bee, bee.centre())
	var into_bee := e0 - bee.hp
	shot = w.spawn_player_arrow(p, p.eye_position(), Vector3(0, 0, -50), 0.6, 34.0, 1.0, 20.0)
	e0 = walker.hp
	shot._hit_zombie(walker, walker.centre())
	var into_walker := e0 - walker.hp
	check(into_walker > 0.0 and absf(into_bee / into_walker - float(WeaponDefs.ALL["resin_repeater"]["flyers"])) < 0.05, "its bolts strike what flies %d%% harder" % roundi((float(WeaponDefs.ALL["resin_repeater"]["flyers"]) - 1.0) * 100.0))
	shot.stop()
	# The Honeycomb: its bees sting what you last struck, and it forages Honey.
	pawn("infantry")
	_face_ahead()
	var comb: Dictionary = PowerDefs.ALL["honeycomb"]
	check(comb["familiar"] and comb["maps"] == ["fontanova"] and Icons.power("honeycomb") == "honeycomb" and ResourceLoader.exists("res://assets/icons/honeycomb.png") and PowerDefs.mesh("honeycomb") != null, "the Honeycomb is Fontanova's familiar, with its own model and icon")
	var near_one := foe("normal", 3.0)
	var struck_one := foe("normal", 7.0, 2.0)
	p.activate_power("honeycomb")
	p.on_melee_connect(struck_one, WeaponDefs.ALL["sword"])
	var n0 := near_one.hp
	var s1 := struck_one.hp
	p._tick_honeycomb(1.0)
	check(near_one.hp == n0 and struck_one.hp < s1 and struck_one.poison_left > 0.0, "its bees sting the last enemy you struck, not the nearest, and poison it")
	struck_one.release()
	await frames(1)
	n0 = near_one.hp
	p._tick_honeycomb(PowerDefs.COMB_INTERVAL)
	check(near_one.hp < n0, "with that one gone, the nearest")
	var honey := w.pickups.filter(func(k: Pickup) -> bool: return k.item_id == "honey").size()
	p._tick_honeycomb(PowerDefs.COMB_FORAGE)
	check(w.pickups.filter(func(k: Pickup) -> bool: return k.item_id == "honey").size() == honey + 1, "and every %d s it brings a Honey" % int(PowerDefs.COMB_FORAGE))
	# The Mysterious Flask: one gift at a time, or now and then poison.
	var gifts := 0
	var poisoned := 0
	for i in 400:
		p.poison_left = 0.0
		p.guard_left = 0.0
		p._buffs.clear()
		p.activate_power("mystery_flask")
		var held := p._buffs.keys().filter(func(k: String) -> bool: return k.begins_with("flask_"))
		if p.poison_left > 0.0:
			poisoned += 1
			if poisoned == 1:
				check(held.is_empty() and not p.has_power("mystery_flask"), "a turned flask gives nothing else")
		elif not held.is_empty():
			gifts += 1
	check(poisoned > 0 and gifts > 0 and gifts + poisoned == 400 and absf(float(poisoned) / 400.0 - PowerDefs.FLASK_BAD) < 0.06, "the flask gives one of its gifts, and one in %d is turned (%d of 400)" % [roundi(1.0 / PowerDefs.FLASK_BAD), poisoned])
	p._buffs.clear()
	p.take_flask_gift(PowerDefs.FLASK_GIFTS[1], 10.0)
	p.take_flask_gift(PowerDefs.FLASK_GIFTS[0], 10.0)
	check(p._buffs.has("flask_speed") and not p._buffs.has("flask_melee_damage"), "a new flask's gift takes the place of the last")
	p._buffs.clear()
	p.poison_left = 0.0
	pawn("infantry")


func _harpooner() -> void:
	var d: Dictionary = ClassDefs.ALL["harpooner"]
	check(d["weapon"] == "harpoon" and d["second"] == "boarding_hook" and ClassDefs.price("harpooner") == 0 and not ClassDefs.for_sale().has("harpooner") and d.get("earned", "") == "harbourmaster", "the Harpooner starts with a Whaler's Harpoon and a Boarding Hook, and is earned against the Harbourmaster")
	check(ClassDefs.weapon_categories("harpooner") == Array(["melee", "two_handed", "ranged"], TYPE_STRING, "", null), "Harpooner wields Melee, Two-Handed and Ranged weapons")
	var specs: Array = AbilityData.tree("harpooner")["specs"].map(func(x: Dictionary) -> String: return x["id"])
	check(specs == ["reaver", "rigger", "leviathan_hunter"], "Reaver, Rigger and Leviathan Hunter")
	for id: String in ["crest_harpooner", "spec_reaver", "spec_rigger", "spec_leviathan_hunter", "rope", "chain", "drop", "harpoon"]:
		check(ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s icon" % id)
	for sound: String in ["haul_throw", "blood_water", "rig_line", "line_trip", "great_harpoon", "hook_catch"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	check(ClassGear._pieces("harpooner").size() == 3 and Avatar.MODELS.has("harpooner") and ClassPresentation.COPY.has("harpooner"), "dressed, seen by others, and described")
	# The kit remains covered while the class is disabled in the player roster.
	var had: Dictionary = Game.unlocked.duplicate()
	var beaten := Game.harbourmasters_beaten
	Game.unlocked.erase("harpooner")
	check(d.get("disabled", false) and not Game.owns_class("harpooner"), "the Harpooner is disabled")
	# (This map has no Harbourmaster of its own: a stand-in falls as one, the way every phone hears of it.)
	var hm := target(p.global_position + Vector3(0, 0, -20))
	hm.type_id = "harbourmaster"
	w.note_defeated(hm)
	hm.type_id = "normal"
	hm.release()
	check(not Game.owns_class("harpooner") and Game.harbourmasters_beaten == beaten + 1, "the Harbourmaster kill is counted without unlocking the Harpooner")
	Game.unlocked = had
	Game.harbourmasters_beaten = beaten
	Game.fresh_unlocks.erase("harpooner")
	# The class: Haul on the button, and its harpoon comes back by itself quickly.
	pawn("harpooner")
	_face_ahead()
	await frames(3)
	_face_ahead()
	check(p.weapon_id() == "harpoon" and p.slots.has("boarding_hook"), "it holds its Harpoon, the Hook at its side")
	check(p.art_def()["name"] == "Haul" and not p.has_path_art(), "its ability is Haul, and no second button yet")
	check(is_equal_approx(HarpoonerKit.harpoon_return(p, 15.0), HarpoonerKit.RETURN), "a Harpooner's harpoon comes back by itself after %d s" % int(HarpoonerKit.RETURN))
	HarpoonerKit.haul(p)
	check(p.art_cd_left <= 0.5, "with nothing in reach, Haul does nothing and comes straight back")
	var caught := foe("normal", 12.0)
	var hp0 := caught.hp
	check(HarpoonerKit.haul_target(p) == caught, "something in front, in reach: Haul finds it")
	var behind := foe("normal", -6.0)
	check(HarpoonerKit.haul_target(p) == caught, "and not what is behind")
	behind.release()
	HarpoonerKit.haul(p)
	check(w.get_children().any(func(n: Node) -> bool: return n is HaulRope), "the rope flies from the Harpooner's hand")
	await frames(60)
	var gap := Vector2(caught.position.x - p.global_position.x, caught.position.z - p.global_position.z).length()
	check(gap < 3.2 and caught.hp < hp0 and caught._stun > 0.0, "Haul drags it in on the rope, strikes and stuns it (%.1f m away now)" % gap)
	caught.release()
	# Too big to move: the rope hauls the Harpooner to it.
	_face_ahead()
	var big := foe("normal", 14.0)
	big._scale = 1.6 # too big to drag, like a Brute or anything a boss
	big.set_physics_process(false)
	var from := p.global_position
	HarpoonerKit.haul(p)
	await frames(90)
	var to_big := Vector2(big.position.x - p.global_position.x, big.position.z - p.global_position.z).length()
	check(p.global_position.distance_to(from) > 8.0 and to_big < HarpoonerKit.HAUL_STOP + big.body_radius() + 1.0, "something too big to move pulls the Harpooner to it instead (%.1f m from it)" % to_big)
	big._scale = 1.0
	big.release()
	# Reaver: Blood in the Water.
	pawn("harpooner", 0)
	_face_ahead()
	await frames(3)
	_face_ahead()
	check(p.path_art_def()["name"] == "Blood in the Water", "a Reaver keeps Haul and gets Blood in the Water on a second button")
	HarpoonerKit.cast_path(p)
	check(HarpoonerKit.in_blood(p) and is_equal_approx(p.m("speed"), 1.0 + HarpoonerKit.BLOOD_SPEED), "in Blood in the Water the Reaver moves 15% faster")
	p.hp = 50.0
	HarpoonerKit.on_blow(p)
	check(is_equal_approx(p.hp, 50.0 + HarpoonerKit.BLOOD_HEAL), "and every blow that lands heals 3")
	var mark := foe("normal", 10.0)
	HarpoonerKit.haul(p)
	check(is_equal_approx(mark._mark_mult, HarpoonerKit.HAUL_MARK), "what a Reaver hauls takes 30% more damage")
	mark.release()
	# Red Tide, No Quarter: with the whole tree, a kill in Blood in the Water hauls the next one in.
	pawn("harpooner", 0, true)
	_face_ahead()
	await frames(3)
	_face_ahead()
	check(p.has_flag("red_tide") and p.has_flag("haul_refund"), "a Reaver's tree reaches Red Tide")
	HarpoonerKit.cast_path(p)
	var victim := foe("normal", 2.0, 0.0, 30.0)
	var next := foe("normal", 10.0, 3.0)
	var next_was := next.position.distance_to(p.global_position)
	p.hauled[victim.get_instance_id()] = w.now + 4.0
	p.art_cd_left = 6.0
	victim.next_hitter = -1 # nobody is credited: the kill is handed to the player below
	victim.take_damage(500.0, Vector3.ZERO, 0.0, victim.centre())
	p.on_kill(victim)
	await frames(60)
	check(next.position.distance_to(p.global_position) < next_was - 4.0, "Red Tide: the kill hauls the nearest enemy in (%.1f m, was %.1f)" % [next.position.distance_to(p.global_position), next_was])
	check(p.art_cd_left <= 2.0 + 0.01, "No Quarter: killing what it hauled takes 4 s off Haul (%.1f)" % p.art_cd_left)
	next.release()
	# Grapple Slam: hauled to something big, the Harpooner lands in a slam.
	p.flags["haul_slam"] = true
	_face_ahead()
	var anchor := foe("normal", 13.0)
	anchor._scale = 1.6
	anchor.set_physics_process(false)
	var bystander := foe("normal", 12.0, 1.5)
	bystander.set_physics_process(false)
	var by0 := bystander.hp
	HarpoonerKit.haul(p)
	await frames(100)
	check(bystander.hp < by0 - 1.0, "Grapple Slam strikes what stands round where it lands (%.0f)" % (by0 - bystander.hp))
	anchor._scale = 1.0
	anchor.release()
	bystander.release()
	# Rigger: Rig a Line.
	pawn("harpooner", 1)
	_face_ahead()
	await frames(3)
	_face_ahead()
	check(p.path_art_def()["name"] == "Rig a Line", "a Rigger gets Rig a Line")
	HarpoonerKit.cast_path(p)
	var mine := w.rig_lines.filter(func(l: RigLine) -> bool: return is_instance_valid(l) and l.owner_peer == p.net_id())
	check(mine.size() == 1 and (mine[0] as RigLine).length() > 10.0, "a line staked from the Rigger's feet ahead (%.1f m)" % ((mine[0] as RigLine).length() if not mine.is_empty() else 0.0))
	if mine.is_empty():
		return
	var line: RigLine = mine[0]
	var mid := (line.a + line.b) * 0.5
	var tripper := foe("normal", 0.0)
	tripper.position = Vector3(mid.x, w.ground_at(mid), mid.z)
	tripper.set_physics_process(false)
	await frames(20)
	check(tripper._stun > 0.0 and tripper._slow > 0.0, "an enemy on the line trips: stunned and slowed")
	tripper.release()
	p.path_art_cd_left = 0.0
	p.global_position += Vector3(4, 0, 0)
	HarpoonerKit.cast_path(p)
	p.global_position += Vector3(4, 0, 0)
	HarpoonerKit.cast_path(p)
	mine = w.rig_lines.filter(func(l: RigLine) -> bool: return is_instance_valid(l) and not l.is_queued_for_deletion() and l.owner_peer == p.net_id())
	check(mine.size() == HarpoonerKit.RIG_LINES, "only %d lines at a time: the oldest comes up" % HarpoonerKit.RIG_LINES)
	for l: RigLine in w.rig_lines.duplicate(): w.remove_rig_line(l)
	pawn("harpooner", 1, true)
	_face_ahead()
	await frames(3)
	_face_ahead()
	check(p.has_flag("cats_cradle") and p.has_flag("line_barbs") and int(p.m("line_time")) == 6, "a Rigger's tree: Tarred Rope, Barbed Line and Cat's Cradle")
	HarpoonerKit.cast_path(p)
	p.global_position += Vector3(6, 0, 0)
	HarpoonerKit.cast_path(p)
	var ties := w.rig_lines.filter(func(l: RigLine) -> bool: return is_instance_valid(l) and l.cradle)
	check(ties.size() == 1, "Cat's Cradle ties the new line to the far end of the other")
	var cut := foe("normal", 0.0)
	var own: RigLine = w.rig_lines.filter(func(l: RigLine) -> bool: return is_instance_valid(l) and not l.cradle).front()
	var on := (own.a + own.b) * 0.5
	cut.position = Vector3(on.x, w.ground_at(on), on.z)
	cut.set_physics_process(false)
	var cut0 := cut.hp
	await frames(20)
	check(cut.hp <= cut0 - HarpoonerKit.BARB_DAMAGE + 0.01 and cut.bleed_left > 0.0, "Barbed Line: what trips is cut and bleeds (%.0f)" % (cut0 - cut.hp))
	check(own.left > HarpoonerKit.RIG_TIME, "Tarred Rope: lines stand longer")
	cut.release()
	for l: RigLine in w.rig_lines.duplicate(): w.remove_rig_line(l)
	await frames(2)
	# Leviathan Hunter: Great Harpoon through a line of them, pinned and marked.
	pawn("harpooner", 2)
	_face_ahead()
	await frames(3)
	_face_ahead()
	check(p.path_art_def()["name"] == "Great Harpoon", "a Leviathan Hunter gets Great Harpoon")
	var first := foe("normal", 8.0)
	var second := foe("normal", 14.0)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var f0 := first.hp
	var s0 := second.hp
	HarpoonerKit.cast_path(p)
	await frames(80)
	check(first.hp < f0 and second.hp < s0, "the Great Harpoon flies through both (%.0f, %.0f)" % [f0 - first.hp, s0 - second.hp])
	check(is_equal_approx(first._mark_mult, HarpoonerKit.MARK) and first._mark_time > 0.0 and first.root_left > 0.0, "and pins and marks what it strikes: 20% more damage from everyone")
	first.release()
	second.release()
	p.flags["big_game"] = true
	p.flags["bane"] = true
	var boss := foe("normal", 10.0)
	boss.def = boss.def.duplicate()
	boss.def["miniboss"] = true # as the Harbourmaster or the Lighthouse Keeper are
	boss.set_physics_process(false)
	HarpoonerKit.mark(p, boss)
	check(is_equal_approx(boss._mark_mult, HarpoonerKit.BANE), "Leviathan's Bane: a marked miniboss takes 40% more")
	check(is_equal_approx(p.modify_damage(boss, 100.0), 100.0 * (1.0 + HarpoonerKit.BIG_GAME)), "Whale Oil: the Hunter strikes bosses and minibosses 30% harder")
	boss.release()
	p.flags["flensing"] = true
	var prey := foe("normal", 6.0, 0.0, 20.0)
	HarpoonerKit.mark(p, prey)
	p.hp = 40.0
	prey.next_hitter = -1 # nobody is credited: the kill is handed to the player below
	prey.take_damage(500.0, Vector3.ZERO, 0.0, prey.centre())
	p.on_kill(prey)
	check(is_equal_approx(p.hp, 40.0 + HarpoonerKit.FLENSE_HEAL), "Flensing: killing what you marked heals 10")


func _tidecaller() -> void:
	var d: Dictionary = ClassDefs.ALL["tidecaller"]
	check(d["weapon"] == "trident" and d.get("mana", false) and d.get("earned", "") == "vael_win" and not ClassDefs.for_sale().has("tidecaller"), "the Tidecaller starts with its Trident, spends tide, and is earned in Port Vael")
	check(WeaponDefs.ALL["trident"].get("only", "") == "tidecaller" and WeaponDefs.mesh("trident") != null, "the Trident is the Tidecaller's alone")
	var specs: Array = AbilityData.tree("tidecaller")["specs"].map(func(x: Dictionary) -> String: return x["id"])
	check(specs == ["tidewarden", "stormcaller", "deepcaller"], "Tidewarden, Stormcaller and Deepcaller")
	for id: String in ["crest_tidecaller", "spec_tidewarden", "spec_stormcaller", "spec_deepcaller", "shell", "serpent", "trident", "wave", "bolt", "storm", "rain"]:
		check(ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s icon" % id)
	for sound: String in ["call_tide", "tide_shell", "shell_hit", "shell_burst", "stormspear", "chain_lightning", "maelstrom", "serpent_rise", "serpent_bite"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	check(ClassGear._pieces("tidecaller").has("chest:glow") and Avatar.MODELS.has("tidecaller") and ClassPresentation.COPY.has("tidecaller"), "dressed, seen by others, and described")
	# Earned by winning one match in Port Vael (dawn there, or a versus match won there).
	var had: Dictionary = Game.unlocked.duplicate()
	var was_mode := Game.mode
	var was_map := Game.night_map
	Game.unlocked.erase("tidecaller")
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "mesenlla"
	var wins := Game.mesenlla_wins
	Game.note_beyond_win()
	Game.mesenlla_wins = wins
	check(not Game.owns_class("tidecaller") and Game.earn_text("tidecaller").contains("Port Vael"), "a win elsewhere does not earn it, and it says to win in Port Vael")
	Game.night_map = "lantern_road"
	Game.note_last_light()
	Game.lighthouses_lit -= 1
	check(not Game.owns_class("tidecaller"), "nor does a lighthouse lit")
	Game.night_map = "vael"
	Game.note_beyond_win()
	check(Game.owns_class("tidecaller") and Game.fresh_unlocks.has("tidecaller"), "one win in Port Vael earns the Tidecaller")
	Game.unlocked.erase("tidecaller")
	Game.mode = Game.Mode.SANDBOX
	Game.note_beyond_win()
	check(not Game.owns_class("tidecaller"), "but not in the Sandbox")
	Game.unlocked = had
	Game.mode = was_mode
	Game.night_map = was_map
	Game.fresh_unlocks.erase("tidecaller")
	# The class: tide from the Trident, and Call the Tide.
	pawn("tidecaller")
	await frames(3)
	_face_ahead()
	check(p.weapon_id() == "trident" and p.max_mana() > 0.0 and p.art_def()["name"] == "Call the Tide", "it holds its Trident, has tide, and Call the Tide")
	p.mana = 0.0
	var poked := foe("normal", 2.0)
	p.on_melee_connect(poked, WeaponDefs.ALL["trident"])
	check(is_equal_approx(p.mana, TidecallerKit.TRIDENT_TIDE), "a Trident blow that lands draws %d tide" % int(TidecallerKit.TRIDENT_TIDE))
	poked.release()
	var hit := foe("normal", 6.0)
	var aside := foe("normal", 6.0, 6.0)
	var h0 := hit.hp
	var a0 := aside.hp
	var hit_was := hit.position
	hit.stun(30.0) # so only the wave moves it
	TidecallerKit.call_the_tide(p)
	# How far along the wave's way it was thrown, at the furthest: frames come at the machine's pace.
	# The throw is the push the wave gives it (a rock behind it in the test world can stop it short),
	# or the ground it covered, whichever shows more.
	var thrown := 0.0
	for i in 600:
		thrown = maxf(thrown, maxf(hit_was.z - hit.position.z, -hit._knock.z))
		if not w.get_children().any(func(n: Node) -> bool: return n is TideWave):
			break
		await frames(1)
	for i in 10:
		thrown = maxf(thrown, maxf(hit_was.z - hit.position.z, -hit._knock.z))
		await frames(1)
	check(hit.hp < h0 and hit._slow > 0.0, "the wave strikes what is in its way and slows it (%.0f)" % (h0 - hit.hp))
	check(thrown > 0.5, "and throws it back along the wave's way (%.1f m)" % thrown)
	check(is_equal_approx(aside.hp, a0), "but not what stands off to the side")
	hit.release()
	aside.release()
	# The core of the tree is the Trident: Long Haft, Skewer, Brine.
	pawn("tidecaller", 0)
	await frames(3)
	_face_ahead()
	var trident: Dictionary = WeaponDefs.ALL["trident"]
	var reach: Dictionary = p.melee_stats(trident)
	check(p.has_flag("skewer") and p.has_flag("brine") and is_equal_approx(float(reach["range"]), float(trident["range"]) + TidecallerKit.LONG_HAFT_REACH)
		and int(reach["hits"]) == int(trident["max_hits"]) + TidecallerKit.LONG_HAFT_HITS, "Long Haft: the Trident reaches %d m further and strikes %d more" % [int(TidecallerKit.LONG_HAFT_REACH), TidecallerKit.LONG_HAFT_HITS])
	var pricked := foe("normal", 3.0)
	var scales: Array[float] = []
	for i in TidecallerKit.SKEWER_EVERY:
		scales.append(TidecallerKit.trident_scale(p, pricked))
		p.mana = 0.0
		p.on_melee_connect(pricked, trident)
		await w.get_tree().physics_frame
	check(is_equal_approx(scales[0], 1.0) and is_equal_approx(scales[TidecallerKit.SKEWER_EVERY - 1], TidecallerKit.SKEWER_MULT * (1.0 + TidecallerKit.BRINE_HARD)),
		"Skewer: every third thrust strikes twice as hard (and Brine on what the first two slowed): %s" % str(scales))
	check(pricked.root_left > 0.0 and absf(p.mana - TidecallerKit.TRIDENT_TIDE - TidecallerKit.SKEWER_TIDE) < 0.5, "and holds what it strikes, drawing %d more tide (held %.1f s, %.0f tide)" % [int(TidecallerKit.SKEWER_TIDE), pricked.root_left, p.mana])
	check(pricked._slow > 0.0, "Brine: Trident blows slow what they strike")
	pricked.release()
	# Tidewarden: Tide Shell takes the blows, Trident blows fill it, it bursts; Unbroken Sea.
	pawn("tidecaller", 0, true)
	await frames(3)
	_face_ahead()
	check(p.art_def()["name"] == "Tide Shell" and p.m("shell_hp") > 0.0 and p.has_flag("steady_footing") and p.has_flag("breakwater") and p.has_flag("unbroken_sea"), "a Tidewarden's tree: Tide Shell, up to Unbroken Sea")
	var biter := foe("normal", 1.5)
	var near := foe("normal", 2.5, 1.0)
	TidecallerKit.raise_shell(p)
	var full := TidecallerKit.SHELL_BASE + TidecallerKit.SHELL_SHARE * p.max_hp() + TidecallerKit.SHELL_THICK
	check(is_equal_approx(p.shell_hp, full) and p.shell_left > 0.0, "the shell holds %d (Thick Shell included)" % int(full))
	await frames(2)
	check(p.get_children().any(func(n: Node) -> bool: return n is TideShell), "and shows round the Tidewarden")
	var hp0 := p.hp
	p.hurt(30.0, biter.position, biter)
	check(is_equal_approx(p.hp, hp0) and is_equal_approx(p.shell_hp, full - 30.0), "a blow is taken by the shell, not by you")
	p.on_melee_connect(biter, trident)
	check(is_equal_approx(p.shell_hp, full - 30.0 + TidecallerKit.SHELL_REFILL), "a Trident blow fills it by %d" % int(TidecallerKit.SHELL_REFILL))
	p.stun_by_creature(2.0)
	p.root_by_creature(2.0)
	check(p.frozen_left <= 0.0 and p.rooted_left <= 0.0, "Steady Footing: while it holds, nothing stuns or holds you")
	var n0 := near.hp
	p.hurt(full + 50.0, biter.position, biter)
	check(p.shell_left <= 0.0 and near.hp < n0 and near._stun > 0.0, "a blow too heavy breaks it: it bursts, striking and (Breakwater) stunning what stands round (%.0f)" % (n0 - near.hp))
	check(p.hp < hp0, "and the rest of the blow gets through")
	p.hp = 10.0
	p.hurt(500.0, biter.position, biter)
	check(not p.dead and p.guard_left > 0.0 and p.shell_left > 0.0 and p.hp > 10.0, "Unbroken Sea: a fatal blow passes through water, and the shell rises again")
	p.hp = 5.0
	p.guard_left = 0.0
	p.shell_left = 0.0
	p.shell_hp = 0.0
	p.hurt(500.0, biter.position, biter)
	check(p.dead or p.hp <= 0.0, "but only once a minute")
	biter.release()
	near.release()
	# Stormcaller: Trident blows soak; Stormspear leaps between the soaked; Squall Step; Maelstrom.
	pawn("tidecaller", 1, true)
	await frames(3)
	_face_ahead()
	check(p.art_def()["name"] == "Stormspear" and p.has_flag("charged_tines") and p.m("chains") > 0.0 and p.has_flag("squall_step") and p.has_flag("maelstrom"), "a Stormcaller's tree: Stormspear, up to Maelstrom")
	var first := foe("normal", 9.0)
	var wet: Array[Zombie] = [foe("normal", 12.0, 2.0), foe("normal", 15.0, -1.0), foe("normal", 17.5, 2.5)]
	var dry := foe("normal", 11.0, -4.0)
	for z: Zombie in wet:
		p.on_melee_connect(z, trident)
	check(wet.all(func(z: Zombie) -> bool: return z.soaked_left > 0.0) and dry.soaked_left <= 0.0, "Trident blows soak what they strike")
	# Both in the same thrust: what tells them apart is the soaking (and Brine, since the soaked one was struck).
	var ratio := TidecallerKit.trident_scale(p, wet[0]) / TidecallerKit.trident_scale(p, dry)
	check(is_equal_approx(ratio, (1.0 + TidecallerKit.CHARGED_TINES) * (1.0 + TidecallerKit.BRINE_HARD)), "Charged Tines: soaked enemies take Trident blows %d%% harder (x%.2f)" % [int(TidecallerKit.CHARGED_TINES * 100.0), ratio])
	var was_at := p.global_position
	var hps := wet.map(func(z: Zombie) -> float: return z.hp)
	var f0 := first.hp
	var d0 := dry.hp
	TidecallerKit.stormspear(p)
	check(first.hp < f0 - TidecallerKit.SPEAR_DAMAGE * 0.5, "Stormspear strikes the first enemy in its way (%.0f)" % (f0 - first.hp))
	var leapt := 0
	for i in wet.size():
		if wet[i].hp < float(hps[i]):
			leapt += 1
	check(leapt == wet.size() and wet.all(func(z: Zombie) -> bool: return z.soaked_left <= 0.0 and z._stun > 0.0), "its lightning leaps from soaked enemy to soaked enemy, jolting each (%d of %d)" % [leapt, wet.size()])
	check(is_equal_approx(dry.hp, d0), "but not to one that is dry")
	check(w.get_children().any(func(n: Node) -> bool: return n is StormArc), "and every leap shows")
	await frames(20)
	check(Vector2(p.global_position.x - was_at.x, p.global_position.z - was_at.z).length() > TidecallerKit.SQUALL_STEP * 0.5, "Squall Step carries the Stormcaller back on the wind (%.1f m)" % Vector2(p.global_position.x - was_at.x, p.global_position.z - was_at.z).length())
	for z: Zombie in wet + [first, dry]:
		z.release()
	for i in TidecallerKit.MAELSTROM_EVERY - 1:
		TidecallerKit.stormspear(p)
	check(w.get_children().any(func(n: Node) -> bool: return n is Maelstrom), "every third Stormspear leaves a Maelstrom")
	var under := foe("normal", 0.0)
	var storm: Maelstrom = w.get_children().filter(func(n: Node) -> bool: return n is Maelstrom).back()
	under.position = storm.global_position + Vector3(1.0, 0, 0)
	var u0 := under.hp
	for i in 90:
		if under.hp < u0:
			break
		await frames(1)
	check(under.hp < u0 and under.soaked_left > 0.0, "its bolts fall on what is under it, and soak it")
	under.release()
	# Deepcaller: Call of the Deep raises a serpent that draws enemies and bites; Bond of Salt; Shed Skin.
	pawn("tidecaller", 2, true)
	await frames(3)
	_face_ahead()
	check(p.art_def()["name"] == "Call of the Deep" and p.has_flag("thick_scales") and p.has_flag("pack_hunter") and p.has_flag("coil") and p.m("art_cost") < 1.0 and p.has_flag("leviathans_child"), "a Deepcaller's tree: Call of the Deep, up to Leviathan's Child")
	var prey := foe("normal", 6.0)
	TidecallerKit.call_of_the_deep(p)
	var serpent := TidecallerKit.serpent_of(p)
	check(serpent != null and serpent.kind == "sea_serpent" and is_equal_approx(serpent.hp, TidecallerKit.SERPENT_HP * (1.0 + TidecallerKit.THICK_SCALES + TidecallerKit.CHILD_HP)), "a sea serpent rises, with Thick Scales and Leviathan's Child health")
	check(serpent != null and is_equal_approx(serpent.grown, TidecallerKit.CHILD_SIZE), "grown by Leviathan's Child")
	check(w.nearest_target(prey.position) == serpent or prey.position.distance_to(serpent.global_position) < prey.position.distance_to(p.global_position) + 4.0, "and draws the enemies near it")
	var p0 := prey.hp
	p.on_melee_connect(prey, trident)
	check(prey.hp < p0 and p.trident_prey == prey, "Leviathan's Child: it lashes what the Trident strikes (%.0f)" % (p0 - prey.hp))
	var bitten := prey.hp
	for i in 120:
		if prey.hp < bitten:
			break
		await frames(1)
	check(prey.hp < bitten and prey.root_left > 0.0, "it goes for the Trident's prey and bites it, Coil holding it (%.0f)" % (bitten - prey.hp))
	TidecallerKit.call_of_the_deep(p)
	check(TidecallerKit.serpent_of(p) == serpent and w.allies.filter(func(a: Ally) -> bool: return a.kind == "sea_serpent" and not a.dead).size() == 1, "called again, the same serpent rises anew: never two")
	prey.release()
	serpent.hurt(9999.0, serpent.global_position)
	check(serpent.dead, "it can be struck down")
	for i in 400:
		if not w.allies.has(serpent):
			break
		await frames(1)
	check(TidecallerKit.serpent_of(p) == null and not w.allies.has(serpent), "and sinks back into the deep")
	for n: Node in w.get_children():
		if n is TideWave or n is StormArc or n is Maelstrom:
			n.queue_free()


func _ferryman() -> void:
	var d: Dictionary = ClassDefs.ALL["ferryman"]
	check(d["weapon"] == "oar" and d.get("earned", "") == "vael_nights" and not ClassDefs.for_sale().has("ferryman"), "the Ferryman starts with the Ferryman's Oar, and is earned in Port Vael")
	var specs: Array = AbilityData.tree("ferryman")["specs"].map(func(x: Dictionary) -> String: return x["id"])
	check(specs == ["tollkeeper", "boatman", "psychopomp"], "Tollkeeper, Boatman and Psychopomp")
	for id: String in ["crest_ferryman", "spec_tollkeeper", "spec_boatman", "spec_psychopomp", "coin", "skiff", "soul", "oar", "bell", "lantern"]:
		check(ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s icon" % id)
	for sound: String in ["crossing", "toll_bell", "obol", "souls_go"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	check(ClassGear._pieces("ferryman").has("chest:glow") and Avatar.MODELS.has("ferryman") and ClassPresentation.COPY.has("ferryman"), "dressed, seen by others, and described")
	# Earned by the third night survived in Port Vael.
	var had: Dictionary = Game.unlocked.duplicate()
	var nights := Game.vael_nights
	var was_mode := Game.mode
	Game.unlocked.erase("ferryman")
	Game.mode = Game.Mode.NIGHT
	Game.vael_nights = Game.VAEL_NIGHTS_FOR_FERRYMAN - 2
	Game.note_vael_night()
	check(not Game.owns_class("ferryman") and Game.earn_text("ferryman").contains("So far: %d" % (Game.VAEL_NIGHTS_FOR_FERRYMAN - 1)), "two nights are not enough, and it says how many so far")
	Game.note_vael_night()
	check(Game.owns_class("ferryman"), "the third earns the Ferryman")
	Game.unlocked = had
	Game.vael_nights = nights
	Game.mode = was_mode
	Game.fresh_unlocks.erase("ferryman")
	# Crossing: the skiff carries the Ferryman ahead, through what is in the way.
	pawn("ferryman")
	await frames(3)
	_face_ahead()
	check(p.weapon_id() == "oar" and p.art_def()["name"] == "Crossing", "it holds its Oar, and Crossing")
	var in_way := foe("normal", 4.5)
	in_way.stun(30.0)
	var w0 := in_way.hp
	var from := p.global_position
	FerrymanKit.cross(p)
	check(p.is_crossing() and w.get_children().any(func(n: Node) -> bool: return n is FerrySkiff), "the skiff sets off, and shows")
	await frames(40)
	var went := Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()
	check(not p.is_crossing() and went > FerrymanKit.CROSS_REACH - 1.5, "it carries the Ferryman %.1f m ahead" % went)
	check(in_way.hp < w0 and in_way._slow > 0.0, "what it passes is struck and slowed (%.0f)" % (w0 - in_way.hp))
	in_way.release()
	# Tollkeeper: debts, obols, Debt Collector.
	pawn("ferryman", 0, true)
	await frames(3)
	_face_ahead()
	check(p.art_def()["name"] == "Demand the Toll" and p.has_flag("debt_collector"), "a Tollkeeper demands the toll, up to Debt Collector")
	var debtor := foe("normal", 4.0, 0.0, 30.0)
	var spared := foe("normal", -4.0, 0.0, 30.0)
	FerrymanKit.demand_the_toll(p)
	check(FerrymanKit.in_debt(p, debtor) and is_equal_approx(debtor._mark_mult, FerrymanKit.DEBT), "those in front fall in debt, taking 25% more damage")
	check(FerrymanKit.in_debt(p, spared), "with All Must Pay, those behind too")
	p.hp = 40.0
	debtor.next_hitter = -1
	debtor.take_damage(500.0, Vector3.ZERO, 0.0, debtor.centre())
	p.on_kill(debtor)
	check(p.obols == 1 and is_equal_approx(p.hp, 40.0 + FerrymanKit.OBOL_HEAL + p.m("obol_heal")), "a debtor's death pays an obol and heals")
	check(is_equal_approx(FerrymanKit.blow_scale(p), 1.0 + FerrymanKit.OBOL_DAMAGE), "each obol makes the Tollkeeper's blows 5% harder")
	spared.release()
	var low := foe("normal", 3.0, 0.0, 100.0)
	FerrymanKit.demand_the_toll(p)
	low.hp = 15.0
	p.on_melee_connect(low, WeaponDefs.ALL["oar"])
	check(not low.is_alive(), "Debt Collector: a blow ends a debtor below 20% health")
	p._kill()
	check(p.obols == 0, "and the obols are lost when the Tollkeeper falls")
	# Boatman: Black Water behind the skiff, and the Last Ferry.
	pawn("ferryman", 1, true)
	await frames(3)
	_face_ahead()
	check(p.has_flag("carry") and p.has_flag("wake") and p.has_flag("last_ferry"), "a Boatman's tree: carry, Black Water, The Last Ferry")
	var knocked := foe("normal", 4.5)
	FerrymanKit.cross(p)
	await frames(40)
	check(knocked._stun > 0.0, "the Boatman's skiff knocks down what it passes")
	check(w.get_children().any(func(n: Node) -> bool: return n is BlackWater), "and leaves black water behind")
	check(p.art_cd_left <= 0.0 and p.second_trip_left > 0.0, "The Last Ferry: a second trip, at once")
	knocked.release()
	# Psychopomp: souls of the dead near it; Guide the Souls; Gate of the Dead.
	pawn("ferryman", 2, true)
	await frames(3)
	_face_ahead()
	check(p.art_def()["name"] == "Guide the Souls" and not FerrymanKit.has_use(p), "a Psychopomp guides souls, and has none yet")
	for i in 3:
		var dead := foe("normal", 3.0, float(i), 10.0)
		dead.take_damage(500.0, Vector3.ZERO, 0.0, dead.centre())
	await frames(2)
	check(p.souls >= 3 and p._soul_ring != null and p._soul_ring.count == p.souls, "the souls of the dead nearby circle it (%d)" % p.souls)
	var target_foe := foe("normal", 6.0)
	var t0 := target_foe.hp
	FerrymanKit.guide_the_souls(p)
	check(p.souls == 0, "Guide the Souls sends them all")
	await until_gone(SoulBolt)
	check(target_foe.hp < t0 - FerrymanKit.SOUL_DAMAGE, "they strike the enemy near (%.0f)" % (t0 - target_foe.hp))
	target_foe.release()
	p.set_souls(FerrymanKit.GATE_SOULS)
	p.hp = 5.0
	p._on_fatal()
	check(not p.dead and p.hp >= p.max_hp() * 0.5 - 0.1 and p.souls == 0, "Gate of the Dead: falling with 6 souls, it comes back at half health")
	p.hp = 5.0
	p.set_souls(FerrymanKit.GATE_SOULS)
	p._on_fatal()
	check(p.dead, "but only once a minute")
	for n: Node in w.get_children():
		if n is BlackWater or n is FerrySkiff or n is SoulBolt:
			n.queue_free()



## A wall between a shot and a body protects the body: an arrow flying along a wall does not graze a
## creature on its far side, and a thrown axe coming back through a wall strikes nothing behind it.
func _walls_protect() -> void:
	pawn("ranger")
	var base := Vector3(30, 0, -30)
	base.y = w.ground_at(base)
	# A wall 6 m long running along Z, 0.3 m thick, 3 m tall.
	w.add_solid(base + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 6.0))
	await frames(2)
	var behind := target(base + Vector3(0.55, 0, 0))
	var hp0 := behind.hp
	# An arrow flying along the near face of the wall, 0.3 m from it.
	p.global_position = base + Vector3(-0.45, 0, 6.0)
	w.spawn_player_arrow(p, base + Vector3(-0.45, 1.0, 3.5), Vector3(0, 0, -40), 0.0, 20.0, 1.0, 30.0)
	await frames(20)
	check(is_equal_approx(behind.hp, hp0), "an arrow along a wall does not hit a creature behind it (%.0f)" % (hp0 - behind.hp))
	# Without the wall the same shot grazes it.
	var open := target(base + Vector3(-0.45 + 0.55, 0, -12.0))
	var open_hp := open.hp
	w.spawn_player_arrow(p, base + Vector3(-0.45, 1.0, -8.5), Vector3(0, 0, -40), 0.0, 20.0, 1.0, 30.0)
	await frames(20)
	check(open.hp < open_hp, "while in the open the same shot grazes it (%.0f)" % (open_hp - open.hp))
	open.release()
	# A thrown axe coming back through the wall.
	hp0 = behind.hp
	p.global_position = base + Vector3(-4.0, 0, 0)
	w.spawn_axe(p, base + Vector3(-3.5, 1.4, 0.0), Vector3(-30, 0, 0), 8.0, 1.0, 30.0)
	await frames(10)
	p.global_position = base + Vector3(4.0, 0, 0)
	await frames(40)
	check(is_equal_approx(behind.hp, hp0), "an axe flying back through a wall does not strike what is behind it (%.0f)" % (hp0 - behind.hp))
	behind.release()
	# A window: seen and shot through, but no blade reaches through it and nobody jumps at it.
	var panes := w._windows.get_children()
	check(not panes.is_empty(), "the houses' windows are filled in (%d)" % panes.size())
	if panes.is_empty():
		return
	var pane := panes[0] as CollisionShape3D
	var size := (pane.shape as BoxShape3D).size
	var normal := pane.transform.basis * (Vector3.RIGHT if size.x < size.z else Vector3.BACK)
	normal = Vector3(normal.x, 0, normal.z).normalized()
	var sill := pane.transform.origin
	var near := sill + normal * 1.0
	near.y = w.ground_at(near)
	var far := sill - normal * 1.1
	far.y = w.ground_at(far)
	pawn("infantry")
	p.global_position = near
	var look := far - near
	p.yaw = atan2(-look.x, -look.z)
	p.rotation.y = p.yaw
	p.pitch = -0.15
	p.head.rotation.x = p.pitch
	var outside := target(far)
	await frames(2)
	check(w.has_line_of_sight(p.eye_position(), outside.centre()), "a creature outside a window can be seen")
	var sword := WeaponDefs.ALL["sword"]
	var landed := w.melee_hit(p, sword, p.melee_stats(sword))
	check(landed == 0, "but a sword swung through the window does not reach it")
	check(not p._should_auto_jump(look.normalized()), "and walking up to a window never jumps at it")
	outside.release()
