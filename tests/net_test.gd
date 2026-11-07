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
	Game.force_weather = Weather.Kind.CLEAR
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
	if rules == "mists":
		Net.set_night_map("mists")
		ok(true, "the host picks the Mists")
	Net.set_rules({"mists": Net.Rules.COOP, "coop": Net.Rules.COOP, "ride": Net.Rules.COOP, "chariot": Net.Rules.COOP, "bots": Net.Rules.COOP, "room": Net.Rules.COOP, "botsffa": Net.Rules.FFA, "ffa": Net.Rules.FFA, "teams": Net.Rules.TEAMS, "fort": Net.Rules.FORT}[rules])
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
	if rules == "bots" or rules == "botsffa":
		Net.set_bots(2)
	if rules == "room":
		Net.set_bots(1)
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
	var t := 0.0
	Net.start_search()
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
		if p != Net.my_id() and not Net.is_bot(p):
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
	elif rules == "mists":
		await _mists()
	elif rules == "coop":
		await _coop()
	elif rules == "bots" or rules == "botsffa":
		await _with_bots()
	elif rules == "room":
		await _room()
	else:
		await _fight()
	await wait(0.5)
	finish()


## Two phones and two bots: the bots are real to both.
## The islands on two phones: the same land, the same gates, and walking through them shows on the other.
func _mists() -> void:
	ok(w.portals != null, "both phones are on the islands")
	await sync(10)
	ok(w.terrain.has_islands(), "with no land between them")
	await sync(11)
	await wait(1.5)
	await sync(12)
	var link: Dictionary = w.portals.links[0]
	if not link["open"] and Net.is_host():
		link["open"] = true
		w.portals._show(link)
		w.portals._tell_others()
	await wait(0.5)
	await sync(13)
	ok(w.portals.links[0]["open"], "a gate opened on the host opens here too")
	pl.global_position = (link["a"] as Vector3) + Vector3.UP * 0.1 if Net.is_host() else pl.global_position
	await wait(1.0)
	await sync(14)
	if Net.is_host():
		ok(w.portals.island_of(pl.global_position) == int(link["ib"]), "the host stepped through")
	else:
		var other: Avatar = Net.avatar(1)
		ok(other and w.portals.island_of(other.global_position) == int(link["ib"]), "and the other phone sees it arrive")


func _with_bots() -> void:
	pl.guard_left = 99999.0
	var ids: Array = Net.roster.keys().filter(Net.is_bot)
	ok(ids.size() == 2, "two bots in the match")
	for b: int in ids:
		ok(Net._avatars.has(b) and w.players.has(Net._avatars[b]), "with bodies on this phone")
	var bot_id: int = ids[0]
	var body: Avatar = Net._avatars[bot_id]
	await sync(50)
	var was := body.global_position
	await wait(4.0)
	await sync(51)
	ok(body.global_position.distance_to(was) > 1.0 or rules == "bots", "the bots move on this phone")
	# A blow from the phone that does not run the bot. In co-op a friend's blow does nothing to it,
	# so there the night's own damage is sent instead, the way a zombie's would be.
	if not host:
		if rules == "botsffa":
			Net.hit_player(bot_id, 99999.0, pl.global_position)
		else:
			Net.hit_player(bot_id, 99999.0, pl.global_position)
			await wait(0.5)
			ok(not body.dead, "a friend's blow does not hurt a bot in co-op")
			Net.hurt_peer(bot_id, 99999.0, pl.global_position, null)
	await wait(0.8)
	await sync(52)
	ok(body.dead, "a defeated bot falls on this phone")
	ok(body._current == "Death_A", "and lies down")
	ok(Net.lives_of(bot_id) == (Net.LIVES - 1 if rules == "botsffa" else Net.LIVES), "lives are counted")
	if rules == "botsffa":
		var scorer := _human_other() if host else Net.my_id()
		ok(int(Net.roster[scorer]["score"]) >= Net.KILL_POINTS, "whoever did it scores")
	# The body also falls for people.
	if not host:
		pl.guard_left = 0.0
		pl.hurt(99999.0, pl.global_position + Vector3.FORWARD)
	await wait(0.8)
	await sync(53)
	if host:
		var them: Avatar = Net._avatars[_human_other()]
		ok(them.dead and them._current == "Death_A", "a fallen player lies down on the host")
	else:
		ok(pl.dead, "the player fell")
	await sync(54)
	if rules == "bots":
		# Bots fight the night, in co-op, and credit goes round.
		if host:
			var bot: BotPlayer = Net._bots[ids[1]]
			w.spawn_zombie("normal", bot.at + Vector3(1.0, 0, 0))
			var scored := int(Net.roster[ids[1]]["score"])
			var t := 0.0
			while int(Net.roster[ids[1]]["score"]) == scored and t < 12.0:
				await wait(0.2)
				t += 0.2
			ok(int(Net.roster[ids[1]]["score"]) > scored, "a bot kills zombies (%.1f s)" % t)
	await sync(55)
	await wait(0.3)
	await snap("bots")


## After a night, the host takes everyone back to the room, and a second night starts from there.
func _room() -> void:
	pl.guard_left = 99999.0
	await sync(80)
	if host:
		Net.roster[Net.my_id()]["score"] = 5
		Net.finish("Test over", "The test ended the night.")
	var t := 0.0
	while not m._run_over and t < 10.0:
		await wait(0.1)
		t += 0.1
	ok(m._run_over, "the night ends on this phone")
	var names: Array = m.ui_layer.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	if host:
		ok(names.has("Back to the room"), "the host can take everyone back to the room")
	else:
		ok(not names.has("Back to the room") and names.has("Menu"), "the others wait for the host, or leave")
	await sync(81)
	var first_world := m.world
	if host:
		_press("Back to the room")
	t = 0.0
	while (Net.in_game or m.world == first_world or m.panel == null) and t < 10.0:
		await wait(0.1)
		t += 0.1
	await wait(0.4)
	ok(not Net.in_game and Net.active(), "back in the room, still together")
	ok(m.world != null and m.world.mode == Game.Mode.MENU and not is_instance_valid(first_world), "the night is cleared away")
	var labels: Array = m.ui_layer.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(labels.has("Infantry") and labels.has("Ranger"), "the room shows again, with the classes to pick")
	ok(Net.roster.size() == 3 and _human_other() != 0 and Net.roster.keys().filter(Net.is_bot).size() == 1, "the other phone and the bot are still in the room (%d)" % Net.roster.size())
	ok(Net.roster.values().all(func(r: Dictionary) -> bool: return int(r["score"]) == 0 and int(r["lives"]) == Net.LIVES), "scores start again from nothing")
	if host:
		ok(not multiplayer.multiplayer_peer.refuse_new_connections, "the room takes new players again")
		if shots != "":
			await snap("room_again")
	await sync(82)
	if host:
		_press("Start the night")
	t = 0.0
	while (not Net.in_game or m.world == null or m.world.mode == Game.Mode.MENU or not m._net_go) and t < 40.0:
		await wait(0.1)
		t += 0.1
	ok(Net.in_game and m._net_go, "a second night starts on this phone")
	w = m.world
	pl = w.player
	pl.guard_left = 99999.0
	await wait(0.6)
	await sync(83)
	ok(_avatar() != null and w.players.has(_avatar()), "the other player has a body again")
	var bot_id: int = Net.roster.keys().filter(Net.is_bot)[0]
	ok(Net._avatars.has(bot_id) and w.players.has(Net._avatars[bot_id]), "and so has the bot")
	var bot_body: Avatar = Net._avatars.get(bot_id)
	var was := bot_body.global_position if bot_body else Vector3.ZERO
	await wait(4.0)
	await sync(84)
	ok(bot_body != null and bot_body.global_position.distance_to(was) > 1.0, "the bot plays the second night too")
	ok(w.director.running and w.director.elapsed > 2.0, "the clock runs (%.1f)" % w.director.elapsed)
	await sync(85)


func _human_other() -> int:
	for p: int in Net.roster:
		if p != Net.my_id() and not Net.is_bot(p):
			return p
	return 0


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
		pl.points = ClassDefs.MAX_LEVEL - 1
		for row in Player.CORE_STEPS:
			pl.choose_ability(row, 0)
		pl.choose_ability(Player.CORE_STEPS, 1)
		pl.choose_ability(Player.CORE_STEPS + 1, 0)
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


## Abilities reach other players in a fight, and rivals' names stay hidden.
func _rival_effects() -> void:
	await _clear_zombies_on_host()
	ok(not _avatar()._label.visible, "no name over a rival's head")
	pl.guard_left = 0.0
	pl.hp = pl.max_hp()
	pl.global_position = Vector3(-1.2, 0.05, 6) if host else Vector3(1.2, 0.05, 6)
	await wait(0.6)
	await sync(30)
	if not host:
		ok(w.stun_around(pl.global_position, 5.0, 3.0) >= 1, "a stun counts the other player")
	await wait(0.4)
	await sync(31)
	if host:
		ok(pl.frozen_left > 0.0 and not pl.is_iced, "a stun from another player stops this one")
		var at := pl.global_position
		pl.input_move = Vector2(0, 1)
		await wait(0.5)
		ok(pl.global_position.distance_to(at) < 0.2, "and they cannot walk away")
		pl.input_move = Vector2.ZERO
	pl.frozen_left = 0.0
	await sync(32)
	# The Revenant's Burst: damage and a freeze, seen on every phone.
	if not host:
		Net.status_peer(_other(), Net.Status.FREEZE, 3.0)
		await wait(0.1)
		ok(_avatar()._ice_left > 0.0, "the frozen player looks frozen to me")
	await wait(0.4)
	await sync(33)
	if host:
		ok(pl.frozen_left > 0.0 and pl.is_iced, "a freeze from another player")
		ok(pl.frozen_left <= 3.0 * Player.PVP_STATUS, "though shorter than on the undead")
		pl.frozen_left = 0.0
		pl.guard_left = 5.0
	await wait(0.2)
	await sync(34)
	if not host:
		Net.status_peer(_other(), Net.Status.STUN, 3.0)
	await wait(0.4)
	await sync(35)
	var hp_now := pl.hp
	if host:
		ok(pl.frozen_left <= 0.0, "a moment of invincibility shrugs it off")
		pl.guard_left = 0.0
	await sync(36)
	if not host:
		w.blast(pl.global_position, 5.0, 30.0)
	await wait(0.5)
	await sync(37)
	if host:
		ok(pl.hp < hp_now, "a blast from another player hurts (%.0f)" % pl.hp)
	# A trap catches another player too.
	if not host:
		w.place_trap(pl, _avatar().global_position)
	await wait(0.6)
	await sync(38)
	if host:
		ok(pl.frozen_left > 0.0, "a trap from another player catches this one")
		pl.frozen_left = 0.0
	await sync(39)


## All vs All: the fog, the lives and the last one standing.
func _fog_match() -> void:
	ok(w.fog != null, "the fog is out there")
	ok(w.fog.centre == Net.fog_centre, "closing on the spot the host chose (%s)" % str(w.fog.centre))
	print("FOGCENTRE %s" % str(w.fog.centre))
	ok(w.director.dawn_amount() == 0.0, "no dawn is coming")
	ok(Net.lives_of(Net.my_id()) == (2 if host else 3), "lives count down (%d)" % Net.lives_of(Net.my_id()))
	if host:
		w.director.running = true
		w.director.elapsed = 180.0
	await wait(1.6)
	await sync(40)
	ok(absf(w.fog.radius - ClosingFog.radius_at(w.director.elapsed)) < 4.0 and w.fog.radius < 100.0, "the fog has closed in on this phone (%.0f)" % w.fog.radius)
	ok(not w.fog.contains(w.fog.centre3() + Vector3(120, 0, 0)), "far away is outside it")
	# Out there it hurts, and enemies do not stay.
	var inside := w.fog.centre3() + Vector3(1.5 if host else -1.5, 0.05, 0)
	var out := w.fog.centre3() + Vector3(0, 0.05, 92.0)
	out.y = w.ground_at(out) + 0.05
	pl.guard_left = 0.0
	pl.hp = pl.max_hp()
	pl.global_position = out
	await wait(1.2)
	ok(pl.hp < pl.max_hp() - 4.0 and pl.hit_by == "the fog", "the fog hurts outside (%.0f)" % pl.hp)
	await snap("fog_outside")
	pl.hp = pl.max_hp()
	inside.y = w.ground_at(inside) + 0.05
	pl.global_position = inside
	await wait(0.5)
	var hp2 := pl.hp
	await wait(0.8)
	ok(pl.hp >= hp2, "and not inside it")
	# Active effects go under the names, not on them.
	pl.activate_power("speed", 20.0)
	pl.activate_power("fire_arrows", 20.0)
	await snap("fog_inside")
	# The wall from just inside it, and from far inside.
	var edge := w.fog.centre3() + Vector3(0, 0, w.fog.radius - 6.0)
	edge.y = w.ground_at(edge) + 0.05
	pl.global_position = edge
	pl.yaw = PI
	pl.rotation.y = PI
	await wait(0.3)
	await snap("fog_edge")
	pl.global_position = inside
	pl.yaw = PI
	pl.rotation.y = PI
	await wait(0.3)
	await snap("fog_far")
	if host:
		for i in 6:
			var spot := w._pick_spawn_point()
			ok(w.fog.contains(spot), "enemies only appear inside it")
		w.spawn_zombie("normal", out)
		await wait(1.6)
		var left_out := w.zombies.filter(func(z: Zombie) -> bool: return z.is_alive() and not w.fog.contains(z.position, 4.0))
		ok(left_out.is_empty(), "an enemy left outside goes (%d)" % left_out.size())
	await sync(41)
	# Host falls twice more, and is out: the other phone wins.
	if host:
		pl.guard_left = 0.0
		pl.hurt(99999.0, pl.global_position + Vector3.FORWARD)
		await wait(0.4)
		ok(pl.dead and Net.respawn_seconds() > 0.0, "second life gone, back soon")
		ok(Net.lives_of(Net.my_id()) == 1, "one life left")
		Net._respawn_left = 0.2
		await wait(0.6)
		ok(not pl.dead, "back for the last life")
		ok(not m._run_over, "the match goes on")
		pl.guard_left = 0.0
		pl.hurt(99999.0, pl.global_position + Vector3.FORWARD)
	await wait(1.2)
	await sync(42)
	if host:
		ok(Net.is_out(), "out of lives")
		ok(Net.respawn_seconds() < 0.0, "and not coming back")
		ok(Net.last_winner == _other(), "the other player wins")
	else:
		ok(Net.last_winner == Net.my_id(), "this player wins")
	ok(m._run_over, "last one standing ends the match on this phone")
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
		if Net.fog_rules():
			ok(Net.respawn_seconds() > 3.0 and Net.respawn_seconds() <= Net.FOG_RESPAWN, "in All vs All you are back in a few seconds")
		else:
			ok(Net.respawn_seconds() > 15.0, "the wait is about 20 seconds")
		Net._respawn_left = 1.0
	await wait(1.8)
	await sync(7)
	if host:
		ok(not pl.dead and pl.hp > 0.0, "the loser comes back after a while")
		ok(pl.global_position.distance_to(_avatar().global_position) > 6.0, "somewhere else")
	await _rival_effects()
	if Net.fog_rules():
		await _fog_match()
		return
	# Dawn ends it with a winner.
	if host:
		w.director.running = true
		w.director.elapsed = Game.NIGHT_LENGTH - 0.5
	await wait(5.5)
	await sync(8)
	ok(m._run_over, "dawn ends the game on this phone")
	await snap("over")
