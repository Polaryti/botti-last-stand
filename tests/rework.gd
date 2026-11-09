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
