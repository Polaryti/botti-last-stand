extends Node
## Two copies of the game talking over the network, each playing through the real code.
## Run one with: -- host coop, and another with: -- client coop. Rules: coop, ffa, teams.
## An optional third value is a folder for screenshots.

var checks := 0
var failures := 0
var host := false
var rules := "coop"
var m: Main
var w: World
var pl: Player
var shots := ""
var args_soak := false
var _their_count := -1
var _their_positions := PackedVector3Array()
var _step := -1


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("[%s] FAIL: %s" % ["host" if host else "client", what])
	else:
		print("[%s] ok: %s" % ["host" if host else "client", what])


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Both sides meet at each numbered step, so the test reads as one story.
@rpc("any_peer", "reliable", "call_remote")
func reached(n: int) -> void:
	_step = maxi(_step, n)


func sync(n: int) -> void:
	reached.rpc(n)
	var t := 0.0
	while _step < n and t < 40.0:
		await wait(0.05)
		t += 0.05
	if _step < n:
		ok(false, "the other side reached step %d" % n)
		finish()


func snap(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [shots, name, "host" if host else "client"])


func finish() -> void:
	print("[%s] RESULT: %d checks, %d failures" % ["host" if host else "client", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _ready() -> void:
	name = "NetTest"
	var args := OS.get_cmdline_user_args()
	host = args[0] == "host"
	rules = args[1] if args.size() > 1 else "coop"
	if rules == "soak":
		args_soak = true
		rules = "coop"
	shots = args[2] if args.size() > 2 else ""
	Game.quality = 1
	Game.player_name = "H" if host else "C"
	Game.difficulty = 1
	Game.player_class = "infantry"
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(0.3)
	if host:
		await _as_host()
	else:
		await _as_client()


func _as_host() -> void:
	m.show_together()
	await wait(0.2)
	ok(Net.host_game() == OK, "a game can be started")
	Net.use_beacons = rules != "teams" # in one of the runs, the asking has to find it alone
	m.show_lobby()
	var t := 0.0
	while Net.roster.size() < 2 and t < 20.0:
		await wait(0.1)
		t += 0.1
	ok(Net.roster.size() == 2, "the other phone joined")
	Net.set_rules({"coop": Net.Rules.COOP, "ride": Net.Rules.COOP, "chariot": Net.Rules.COOP, "ffa": Net.Rules.FFA, "teams": Net.Rules.TEAMS, "fort": Net.Rules.FORT}[rules])
	_press("Hard")
	await wait(0.1)
	ok(Net.difficulty == 2 and Game.difficulty == 2, "the host can pick the difficulty")
	_press("Normal")
	await wait(0.1)
	if rules == "ride":
		Game.player_class = "chivalry"
		Net.set_my_class("chivalry")
	if rules == "chariot":
		Game.player_class = "artificer"
		Net.set_my_class("artificer")
	if rules == "teams":
		# Put the two on opposite teams.
		Net.roster[1]["team"] = 0
		for p: int in Net.roster:
			if p != 1:
				Net.roster[p]["team"] = 1
	await wait(0.3)
	# The lobby buttons rebuild the lobby from inside their own press.
	_press("Ranger")
	await wait(0.2)
	ok(Game.player_class == "ranger" and Net.roster[1]["class"] == "ranger", "a class can be picked in the lobby")
	_press("Infantry")
	await wait(0.2)
	if rules == "ride":
		Net.set_my_class("chivalry")
	if rules == "chariot":
		Net.set_my_class("artificer")
	var chosen := Net.rules
	_press("Teams")
	await wait(0.1)
	ok(Net.rules == Net.Rules.TEAMS, "the host can pick the rules")
	_press("Change team")
	await wait(0.1)
	Net.set_rules(chosen)
	await wait(0.2)
	if rules == "teams":
		Net.roster[1]["team"] = 0
		for p: int in Net.roster:
			if p != 1:
				Net.roster[p]["team"] = 1
	if shots != "":
		await snap("lobby")
	await wait(1.2)
	Net.start_match()
	await _play()


func _as_client() -> void:
	# Finding the game: by its beacon, or by asking around when a hotspot drops broadcasts.
	Net.start_search()
	var t := 0.0
	while Net.rooms.is_empty() and t < 15.0:
		await wait(0.1)
		t += 0.1
	ok(not Net.rooms.is_empty(), "the game shows up in the list of games nearby")
	Net.stop_search()
	m.show_together()
	await wait(0.1)
	m._join("127.0.0.1")
	t = 0.0
	while not Net.roster.has(Net.my_id()) and t < 10.0:
		await wait(0.1)
		t += 0.1
	await wait(0.2)
	_press("Magician")
	await wait(0.4)
	ok(Game.player_class == "magician", "my class can be picked in the lobby")
	_press("Infantry")
	t = 0.0
	while not Net.in_game and t < 25.0:
		await wait(0.1)
		t += 0.1
	ok(Net.in_game, "the host's start reaches this phone")
	ok(Game.player_class == "infantry", "with the class I picked")
	await _play()


func _press(text: String) -> void:
	for b: Node in m.ui_layer.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			(b as Button).pressed.emit()
			return
	ok(false, "there is a button called %s" % text)


func _other() -> int:
	for p: int in Net.roster:
		if p != Net.my_id():
			return p
	return 0


func _avatar() -> Avatar:
	return Net._avatars.get(_other())


func _play() -> void:
	var t := 0.0
	while (not m.world or not m._net_go) and t < 40.0:
		await wait(0.1)
		t += 0.1
	ok(m._net_go, "everyone has loaded and the night begins")
	w = m.world
	pl = w.player
	await wait(0.6)
	await sync(1)
	ok(_avatar() != null and w.players.has(_avatar()), "the other player has a body here")
	ok(w.zombies.size() > 0, "zombies are out (%d)" % w.zombies.size())
	ok(w.pickups.size() > 3, "items are out (%d)" % w.pickups.size())
	ok(w.director.running, "the clock is running")
	await wait(0.8)
	ok(absf(w.director.elapsed - 1.5) < 1.5, "the clocks agree (%.1f)" % w.director.elapsed)
	if args_soak:
		await _soak()
	elif rules == "fort":
		await _fort()
	elif rules == "ride":
		await _ride()
	elif rules == "chariot":
		await _chariot()
	elif rules == "coop":
		await _coop()
	else:
		await _fight()
	await wait(0.5)
	finish()


## A real stretch of night, with both players wandering and swinging at whatever comes.
func _soak() -> void:
	pl.guard_left = 99999.0
	var end := Time.get_ticks_msec() + 60000
	var hits := 0
	while Time.get_ticks_msec() < end:
		var a := Time.get_ticks_msec() * 0.0004 + (0.0 if host else 2.0)
		pl.yaw = a
		pl.rotation.y = a
		pl.input_move = Vector2(0, -1)
		pl.input_fire = true
		pl.guard_left = 99999.0
		await wait(0.25)
		hits += 1
	pl.input_move = Vector2.ZERO
	pl.input_fire = false
	if host:
		w.director.running = false
	await wait(1.0)
	await sync(50)
	_report.rpc(w.count_living(), _living_positions())
	await wait(0.5)
	await sync(51)
	ok(pl.attack_count > 0, "the wandering player fought (%d kills)" % pl.kills)
	ok(absi(w.count_living() - _their_count) <= 1, "both phones agree how many zombies live (%d and %d)" % [w.count_living(), _their_count])
	var far := 0
	var mine := _living_positions()
	for p in mine:
		var best := INF
		for q in _their_positions:
			best = minf(best, p.distance_to(q))
		if best > 2.5:
			far += 1
	ok(far <= 1, "and where they are (%d out of place)" % far)
	ok(pl.level >= 1, "level %d, %d items here" % [pl.level, w.pickups.size()])
	ok(absi(w.pickups.size() - _their_items) <= 1, "both phones agree on the items (%d and %d)" % [w.pickups.size(), _their_items])


var _their_items := -1


func _living_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for z in w.zombies:
		if z.is_alive():
			out.append(z.position)
	return out


@rpc("any_peer", "reliable", "call_remote")
func _report(count: int, positions: PackedVector3Array) -> void:
	_their_count = count
	_their_positions = positions
	_items_report.rpc(w.pickups.size())


@rpc("any_peer", "reliable", "call_remote")
func _items_report(count: int) -> void:
	_their_items = count


func _fort() -> void:
	await _clear_zombies_on_host()
	await sync(2)
	ok(Game.mode == Game.Mode.FORT and w.fort != null, "both phones are in the fort")
	var f := w.fort
	var g: Dictionary = f.gates[1]
	if host:
		f.hit_gate(g, 99999.0, g["at"])
	await wait(0.6)
	await sync(3)
	ok(not g["closed"], "a gate falling reaches both phones")
	ok(f.any_open(), "and it is open on both")
	await snap("gate_down")
	# The client mends it with its own wood, and the host agrees.
	if not host:
		pl.wood = Fort.WOOD_MAX
		pl.global_position = (g["at"] as Vector3) + Vector3(-4, 0.1, 0)
	await wait(3.2)
	await sync(4)
	ok(float(g["hp"]) > 0.0, "wood from the other phone mends the gate (%.0f)" % float(g["hp"]))
	ok(g["closed"], "and it closes on both")
	if not host:
		ok(pl.wood < Fort.WOOD_MAX, "using up what I carried")
	if host:
		f.hit_heart(100.0)
	await wait(0.6)
	await sync(5)
	ok(f.heart_hp < Fort.HEART_HP, "the heart's health reaches both phones (%.0f)" % f.heart_hp)
	# The heart falls: the game ends for everyone, and it is not a win.
	if host:
		f.hit_heart(999999.0)
	await wait(0.8)
	await sync(6)
	ok(m._run_over, "when the heart falls it ends on this phone")
	await snap("fort_over")


func _ride() -> void:
	await _clear_zombies_on_host()
	await sync(2)
	# The host rides. The client climbs on.
	pl.global_position = Vector3(0, 0.05, 15) if host else Vector3(2, 0.05, 15)
	await wait(0.4)
	if host:
		pl.horse_progress = pl.horses_needed()
		pl.mount()
		ok(pl.is_riding(), "the knight mounts")
	await wait(0.5)
	await sync(3)
	if not host:
		ok(_avatar().is_mounted(), "I see the horse")
		ok(pl.can_board(), "and I can climb on behind")
		pl.board()
	await wait(0.5)
	await sync(4)
	if host:
		ok(pl.passenger != 0, "one passenger is on")
		pl.global_position = Vector3(0, 0.05, 25)
	else:
		ok(pl.ride_behind != 0, "I am riding")
		await snap("riding")
	await wait(0.8)
	await sync(5)
	if not host:
		ok(pl.global_position.distance_to(Vector3(0, 0, 25)) < 3.0, "the horse takes me along (%s)" % pl.global_position)
		var before := pl.global_position
		pl.input_move = Vector2(1, 0)
		await wait(0.3)
		pl.input_move = Vector2.ZERO
		ok(pl.global_position.distance_to(before) < 1.0, "and I do not steer")
	await wait(0.4)
	await sync(6)
	if host:
		pl.dismount()
	await wait(0.6)
	await sync(7)
	if not host:
		ok(pl.ride_behind == 0, "when the rider gets off so do I")
		ok(not pl.can_board(), "and there is nothing to climb on")
	else:
		ok(pl.passenger == 0, "and the seat is free")


## The Artificer on two phones: the chariot and its seat, what his devices leave behind, and the bell.
func _chariot() -> void:
	await _clear_zombies_on_host()
	await sync(2)
	pl.global_position = Vector3(0, 0.05, 15) if host else Vector3(2, 0.05, 15)
	await wait(0.4)
	if host:
		ok(pl.class_id == "artificer", "the host plays an Artificer")
		pl.points = 18
		for row in 4:
			pl.choose_ability(row, 0)
		pl.choose_ability(4, 1)
		pl.choose_ability(5, 0)
		ok(pl.spec_id == "mechanic" and pl.has_flag("chariot_turret"), "a Mechanic with a turret")
		pl.horse_progress = pl.horses_needed()
		pl.mount()
		ok(pl.is_riding() and pl.mount_kind() == "chariot", "he climbs into the chariot")
	await wait(0.6)
	await sync(3)
	if not host:
		ok(_avatar().is_mounted() and _avatar().in_chariot, "I see a chariot, not a horse")
		ok(_avatar()._has_turret, "with the turret on it")
		ok(pl.can_board(), "and I can climb on")
		pl.board()
	await wait(0.5)
	await sync(4)
	if host:
		ok(pl.passenger != 0, "one friend is on")
		pl.global_position = Vector3(0, 0.05, 25)
	else:
		ok(pl.ride_behind != 0, "I am riding in the chariot")
		await snap("chariot")
	await wait(0.8)
	await sync(5)
	if not host:
		ok(pl.global_position.distance_to(Vector3(0, 0, 25)) < 3.0, "the chariot takes me along (%s)" % pl.global_position)
	await sync(6)
	if host:
		pl.dismount()
	await wait(0.6)
	await sync(7)
	if not host:
		ok(pl.ride_behind == 0, "when he gets out so do I")
	else:
		ok(pl.passenger == 0, "and the seat is free")
	# A bomb on the host's phone leaves fire on the other's too.
	if host:
		pl.bomb_burst(Vector3(10, w.ground_at(Vector3(10, 0, 30)), 30))
	await wait(0.5)
	await sync(8)
	var burning := false
	for i in w._puddles.size():
		if w._puddle_life[i] > 0.0 and w._puddle_fire[i] and w._puddles[i].global_position.distance_to(Vector3(10, w.ground_at(Vector3(10, 0, 30)), 30)) < 1.0:
			burning = true
	ok(burning, "a bomb's fire shows on both phones")
	# The same goes for a sentry.
	if host:
		w.place_sentry(pl, Vector3(6, 0, 30), 5.0)
	await wait(0.5)
	await sync(9)
	ok(not w._sentries.is_empty(), "a sentry stands on both phones")
	# Minute 3: three strokes, half a second apart, on both phones.
	if host:
		w.ring_bell(3)
		Net.bell(3)
	await wait(0.2)
	ok(w.bell_strokes_left() == 2, "the first stroke rings straight away (%d left)" % w.bell_strokes_left())
	await wait(0.5)
	ok(w.bell_strokes_left() == 1, "the second after half a second (%d left)" % w.bell_strokes_left())
	await wait(0.5)
	ok(w.bell_strokes_left() == 0, "and the third after another (%d left)" % w.bell_strokes_left())
	await wait(0.2)
	await sync(10)


func _clear_zombies_on_host() -> void:
	if host:
		for z: Zombie in w.zombies.duplicate():
			z.release()
		w.director.running = false
		w.director._stock_timer = 999.0
		w.director._familiar_timer = 999.0
		w.director._bell_timer = 999.0
	await wait(0.4)


func _coop() -> void:
	await _clear_zombies_on_host()
	await sync(2)
	ok(w.zombies.is_empty(), "no zombies left for the next check")
	# The two stand apart, and their bodies move on each other's phones.
	pl.global_position = Vector3(-2.5, 0.05, 10) if host else Vector3(2.5, 0.05, 10)
	pl.velocity = Vector3.ZERO
	pl.yaw = -PI * 0.5 if host else PI * 0.5
	pl.rotation.y = pl.yaw
	await wait(0.6)
	await sync(3)
	var want := Vector3(2.5, 0, 10) if host else Vector3(-2.5, 0, 10)
	var a := _avatar()
	ok(a.global_position.distance_to(want) < 1.0, "the other player appears where they are (%s)" % a.global_position)
	await snap("together")
	# A zombie on the host appears on the client, and a client's hit counts.
	var id := -1
	if host:
		w.spawn_zombie("normal", Vector3(6, 0, 12))
		var z := w.zombies[-1]
		z.set_physics_process(false)
		id = z.net_id
	await wait(0.5)
	await sync(4)
	ok(w.zombies.size() == 1, "the zombie exists on both phones")
	var shared: Zombie = w.zombies[0]
	ok(shared.position.distance_to(Vector3(6, 0, 12)) < 1.5, "in the same place (%s)" % shared.position)
	if not host:
		ok(shared.puppet, "here it is only a puppet")
		var xp0 := pl.xp
		var hp0 := shared.hp
		w.damage_zombie(shared, 10.0, Vector3.FORWARD, 0.0, shared.centre(), false)
		await wait(0.3)
		ok(shared.is_alive() and shared.hp < hp0, "a small hit hurts it")
		w.damage_zombie(shared, 9999.0, Vector3.FORWARD, 0.0, shared.centre(), false)
		await wait(0.5)
		ok(not shared.is_alive(), "a big hit kills it, once the host agrees")
		ok(pl.kills == 1, "and the kill is mine")
		ok(pl.xp > xp0 or pl.level > 1, "and so is the experience")
	await sync(5)
	if host:
		ok(pl.kills == 0, "the host did not get that kill")
		ok(int(Net.roster[_other()]["score"]) == 1, "the host counted it for the other player")
		ok(pl.xp > 0, "but learned something from it, because this is co-op")
	await _clear_zombies_on_host()
	# A zombie on the host goes for the player it is closest to, and hurts them on their phone.
	await sync(6)
	pl.global_position = Vector3(-30, 0.05, 6) if host else Vector3(6, 0.05, 6)
	await wait(0.5)
	if host:
		w.spawn_zombie("normal", Vector3(6, 0, 8.5))
		w.zombies[-1].state = Zombie.State.CHASE
	var hp_before := pl.hp
	await wait(4.0)
	await sync(7)
	if not host:
		ok(pl.hp < hp_before, "the zombie hunted me down on this phone (%.0f to %.0f)" % [hp_before, pl.hp])
		ok(pl.hit_by != "", "and I know what hit me (%s)" % pl.hit_by)
	else:
		ok(absf(pl.hp - hp_before) < 0.01, "and left the host alone")
	await _clear_zombies_on_host()
	# Arrows from the host's enemies hurt whoever they reach, on that phone.
	await sync(8)
	if not host:
		pl.hp = pl.max_hp()
	if host:
		w.spawn_enemy_arrow(Vector3(6, 2, 20), _avatar().eye_position(), 12.0, 30.0, false, "A test")
	await wait(1.2)
	await sync(9)
	if not host:
		ok(pl.hp < pl.max_hp(), "an enemy arrow reached me")
	# Items: spawned on the host, seen and taken on the client, and gone everywhere.
	pl.hp = pl.max_hp() * 0.5
	var before := w.pickups.size()
	if host:
		for it: Pickup in w.pickups.duplicate():
			w.remove_pickup(it)
	await wait(0.4)
	await sync(10)
	for it: Pickup in w.pickups:
		print("  still here: ", it.display_name(), " id ", it.net_id, " at ", it.global_position)
	ok(w.pickups.is_empty(), "items removed on the host are gone here too")
	await wait(0.2)
	if host:
		w.spawn_pickup_at(Vector3(6, 0, 16), Pickup.Kind.FOOD, "bread")
	await wait(0.4)
	await sync(11)
	ok(w.pickups.size() == 1, "a new item shows up on both phones")
	await wait(0.3)
	if not host:
		pl.global_position = Vector3(6, 0.05, 16)
	await wait(1.5)
	await sync(12)
	if not host:
		ok(pl.hp > pl.max_hp() * 0.5, "standing on it, I ate it")
	for it: Pickup in w.pickups:
		print("  still here: ", it.display_name(), " id ", it.net_id, " at ", it.global_position)
	ok(w.pickups.is_empty(), "and it is gone from both")
	# Dropping a weapon goes through the host.
	if not host:
		w.drop_weapon(Vector3(6, 0, 12), "sword")
	await wait(0.5)
	await sync(13)
	for it: Pickup in w.pickups:
		print("  on the ground: ", it.display_name(), " id ", it.net_id, " at ", it.global_position)
	ok(w.pickups.size() == 1 and w.pickups[0].weapon_id == "sword", "a dropped weapon reaches both phones")
	# Effects a player puts on a zombie reach the host.
	if host:
		for it: Pickup in w.pickups.duplicate():
			w.remove_pickup(it)
		w.spawn_zombie("normal", Vector3(-6, 0, 30))
		w.zombies[-1].set_physics_process(false)
	await wait(0.4)
	await sync(14)
	if not host:
		w.zombies[0].stun(5.0)
		w.zombies[0].ignite(5.0)
		w.make_noise(w.zombies[0].position, 5.0)
	await wait(0.5)
	await sync(15)
	if host:
		ok(w.zombies[0]._stun > 0.0, "a stun from the other phone counts")
		ok(w.zombies[0].burn_time > 0.0, "so does setting it on fire")
		ok(w.zombies[0].state == Zombie.State.INVESTIGATE or w.zombies[0]._has_goal, "and so does noise")
	else:
		ok(w.zombies[0].burn_time > 0.0, "and I can see it burning")
	await _clear_zombies_on_host()
	# A summon is seen by the others, and enemies on the host can hurt it.
	await sync(40)
	if not host:
		w.prepare_allies("skeleton", 1)
		w.spawn_ally("skeleton", Vector3(12, 0, 24), 30.0)
	await wait(0.6)
	await sync(41)
	if host:
		var shown: Ally = null
		for al in w.allies:
			if al.remote_owner != 0:
				shown = al
		ok(shown != null, "the other player's summon appears here")
		if shown:
			ok(shown.global_position.distance_to(Vector3(12, 0, 24)) < 3.0, "where it stands")
			shown.hurt(5000.0, shown.global_position)
	await wait(0.6)
	await sync(42)
	if not host:
		var left := 0
		for al in w.allies:
			if not al.dead:
				left += 1
		ok(left == 0, "and a hit there reaches it on my phone")
	await wait(1.6)
	await sync(43)
	print("  step 43 fps=", Engine.get_frames_per_second())
	if host:
		var remote := 0
		for al in w.allies:
			if al.remote_owner != 0:
				remote += 1
		ok(remote == 0, "and when it falls it is gone from here too")
	# Falling: a 20 s wait, watching the other player.
	await sync(16)
	var body_at := pl.global_position
	if not host:
		pl.hurt(99999.0, pl.global_position + Vector3.FORWARD)
		ok(pl.dead, "I can fall")
	await wait(0.6)
	await sync(17)
	if host:
		ok(_avatar().dead, "the host sees me fallen")
		ok(not m._run_over, "and the night goes on for the one still standing")
		w.ring_bell(1)
		Net.bell(1)
	else:
		ok(Net.respawn_seconds() > 15.0, "I wait about 20 seconds (%.0f)" % Net.respawn_seconds())
		ok(Net.watching_name() == "H", "watching the other player")
		ok(get_viewport().get_camera_3d() == Net.spectate_cam, "through their eyes")
		ok(Net.spectate_cam.global_position.distance_to(_avatar().eye_position()) < 2.5, "from where they stand")
		await snap("watching")
	await wait(1.0)
	await sync(18)
	if not host:
		ok(pl.dead, "the bell does not bring anyone back")
		Net._respawn_left = 0.2
	await wait(1.0)
	await sync(44)
	if not host:
		ok(not pl.dead, "the wait ends and I am back")
		ok(get_viewport().get_camera_3d() == pl.camera, "with my own eyes")
		ok(pl.global_position.distance_to(_avatar().global_position) < 6.0, "next to my friend")
	else:
		ok(not _avatar().dead, "and the host sees that")
	await wait(0.4)
	# Everyone down ends the night for everyone.
	if host:
		print("  check at ", Time.get_ticks_msec(), " fps=", Engine.get_frames_per_second())
		ok(not _avatar().dead, "and the host sees that")
	await wait(0.4)
	pl.guard_left = 0.0
	pl.hurt(99999.0, pl.global_position + Vector3.FORWARD)
	await wait(1.5)
	await sync(19)
	ok(m._run_over, "when everyone has fallen, the game ends on this phone")
	await snap("over")


func _fight() -> void:
	await _clear_zombies_on_host()
	if host:
		for it: Pickup in w.pickups.duplicate():
			w.remove_pickup(it)
	await sync(2)
	ok(pl.global_position.distance_to(Vector3.ZERO) > 8.0, "the players start apart")
	# Melee between players, decided by the attacker, felt by the victim.
	pl.global_position = Vector3(-1.2, 0.05, 6) if host else Vector3(1.2, 0.05, 6)
	var face := -PI * 0.5 if host else PI * 0.5
	pl.yaw = face
	pl.rotation.y = face
	pl.hp = pl.max_hp()
	await wait(0.6)
	await sync(3)
	if not host:
		var d := WeaponDefs.ALL["sword"]
		var hits := w.melee_hit(pl, d, pl.melee_stats(d))
		ok(hits == 1, "my blow lands on the other player")
	await wait(0.5)
	await sync(4)
	if host:
		ok(pl.hp < pl.max_hp(), "the blow lands on this phone (%.0f)" % pl.hp)
		ok(pl.hit_by == "C", "and says who did it")
	var hp1 := pl.hp
	await wait(0.2)
	# An arrow between players.
	if not host:
		w.spawn_player_arrow(pl, pl.eye_position() + Vector3(-0.8, 0, 0), Vector3(-30, 0, 0), 0.0, 20.0, 1.0, 25.0)
	await wait(0.6)
	await sync(5)
	if host:
		ok(pl.hp < hp1, "an arrow from the other player hurts")
	# Defeat gives the points and brings the loser back.
	if not host:
		for i in 12:
			var d := WeaponDefs.ALL["sword"]
			w.melee_hit(pl, d, pl.melee_stats(d))
			await wait(0.1)
	await wait(0.6)
	await sync(6)
	if host:
		ok(pl.dead, "enough blows defeat a player")
		ok(not m._run_over, "without ending the game")
		ok(int(Net.roster[_other()]["score"]) >= Net.KILL_POINTS, "and the winner scores (%d)" % int(Net.roster[_other()]["score"]))
		ok(Net.respawn_seconds() > 0.0, "the loser is coming back")
	else:
		ok(pl.level > 1 or pl.xp > 0, "the winner learns from it")
	if host:
		ok(Net.respawn_seconds() > 15.0, "the wait is about 20 seconds")
		Net._respawn_left = 1.0
	await wait(1.8)
	await sync(7)
	if host:
		ok(not pl.dead and pl.hp > 0.0, "the loser comes back after a while")
		ok(pl.global_position.distance_to(_avatar().global_position) > 6.0, "somewhere else")
	# Dawn ends it with a winner.
	if host:
		w.director.running = true
		w.director.elapsed = Game.NIGHT_LENGTH - 0.5
	await wait(5.5)
	await sync(8)
	ok(m._run_over, "dawn ends the game on this phone")
	await snap("over")
