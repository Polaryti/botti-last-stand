extends Node
## Same-Wi-Fi play. One phone is the host and runs the night: zombies, items, the clock.
## Everyone else plays their own character on their own phone, tells the host what it hit, and
## draws the zombies from the host's snapshots. Nothing here needs a server or the internet.

signal lobby_changed
signal rooms_changed
signal game_started
signal all_ready
signal left(reason: String)
signal game_over(title: String, line: String, reached_dawn: bool)
signal back_in_room
signal public_rooms_changed

enum Role { OFFLINE, HOST, CLIENT }
enum Rules { COOP, FFA, TEAMS, FORT }
enum Way { LOCAL, ONLINE } # how the phones reach each other

const PORT := 27415
const DISCOVERY_PORT := 27416
const ASK_PORT := 27417
const ASK_EVERY := 2.5
const MAX_PLAYERS := 4
const PROTOCOL := 42
const CONNECT_WAIT := 25.0 # how long a relay gets to bring two phones together
const BOT_BASE := 2147483000 # peer ids this high are never given to real phones in practice
const BOT_NAMES := ["Aldric", "Mara", "Osric", "Ysolde", "Bram", "Wynn"]
enum Fx { FIRE_PATCH, SPARK, SENTRY, POISON_PATCH }
enum Status { FREEZE, STUN, SLOW, BURN, POISON, BLEED }
const LIVES := 3 # All vs All: how many times you can fall
const FOG_RESPAWN := 6.0
const SNAPSHOT_EVERY := 0.08
const POSE_EVERY := 0.066
## Zombies per snapshot packet. 12 bytes each, so a packet stays under Epic's 1170-byte limit with room
## for the RPC's own header.
const SNAPSHOT_CHUNK := 80
const BEACON_EVERY := 1.0
const RESPAWN_TIME := 20.0
# A phone's Wi-Fi can go quiet for seconds at a time, so give it longer than ENet's usual 5 seconds.
const TIMEOUT_FACTOR := 64
const TIMEOUT_MIN := 12000
const TIMEOUT_MAX := 45000
const PVP_DAMAGE := 0.55 # players hit each other less hard than they hit the undead
const KILL_POINTS := 5
const RULE_NAMES := ["Co-op Night", "All vs All", "Teams", "Defend the Fort"]
const SOUNDS := ["groan", "attack", "zombie_hurt", "zombie_death", "block", "crow", "gargoyle", "leaper", "wraith", "banshee", "mimic", "creak",
	"blast", "gallop", "hammer", "fireball", "bow", "thunk", "howl", "rooster", "bell", "wolf", "chakram_hit", "cleave", "vanish", "steal", "nightfall", "dagger_fan"]
const ANIMS := ["", "Idle", "Walking_A", "Walking_C", "Running_A", "Hit_A", "1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A", "Spellcast_Shoot",
	"2H_Ranged_Shoot", "PickUp", "Death_A", "Death_B", "Thrust", "Overhead", "Sweep"]

var role: int = Role.OFFLINE
var way: int = Way.LOCAL
var night_map := "village" # which map a co-op night is played on: the host's choice
var online: EpicNet # stays once made, because its system can only start once
var room_code := ""
var room_problem := "" # why there is no short code
var room_listed := true # online: shown in the list of public games, or found only by its code
var public_rooms: Array[Dictionary] = [] # online games waiting for players, as last looked up
var looking_up := false
var lookup_problem := ""
var _room_dirty := false
var _room_wait := 0.0
var _connect_wait := 0.0
var rules: int = Rules.COOP
var difficulty := 1
var spectate_cam: Camera3D
var _watching := 0
var roster := {} # peer id -> {name, class, team, score, deaths}
var rooms := {} # address -> {name, players, rules, seen}
var forced_quality := -1
var weather := 0 # tonight's Weather.Kind, as the host rolled it
var fog_centre := Vector2.ZERO # where the fog closes in on, in All vs All
var last_winner := 0
var _started_with := 0
var in_game := false
var world: World
var started_loading := false

var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_timer := 0.0
var _answer: PacketPeerUDP
var _ask_timer := 0.0
var use_beacons := true # a test can switch these off to try the other way of finding a game
var _snap_timer := 0.0
var _pose_timer := 0.0
var _clock_timer := 0.0
var _respawn_left := -1.0
var _loaded := {}
var _avatars := {} # peer id -> Avatar
var _sound_ids := {}
var _anim_ids := {}
var _weapon_ids: Array = []
var _over := false
var _dawn_ending := false
var _ally_goodbyes := 0
var _ally_timer := 0.0
var _bots := {} # on the host: peer id -> BotPlayer
# Positions, poses and the clock go out unreliable and unordered: a late one is worth nothing, and
# Epic would turn "unreliable ordered" into reliable, queueing a slow phone further and further behind.
# Each stream carries a 16-bit count so a packet older than one already used is ignored.
var _out_seq := {} # stream -> last count sent
var _in_seq := {} # [stream, sender] -> newest count used


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SOUNDS.size():
		_sound_ids[SOUNDS[i]] = i
	for i in ANIMS.size():
		_anim_ids[ANIMS[i]] = i
	_weapon_ids = WeaponDefs.ALL.keys()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	set_physics_process(false)
	set_process(false)


func active() -> bool:
	return role != Role.OFFLINE


## Development APKs use their own compatibility namespace for LAN and online rooms.
func protocol_version() -> int:
	return PROTOCOL + (100000 if Game.is_dev_build() else 0)


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


func pvp() -> bool:
	return active() and (rules == Rules.FFA or rules == Rules.TEAMS)


## All vs All: three lives, and the fog.
func fog_rules() -> bool:
	return active() and rules == Rules.FFA


func lives_of(peer: int) -> int:
	return int(roster.get(peer, {}).get("lives", 0))


## This player has used up all their lives, and only watches now.
func is_out() -> bool:
	return fog_rules() and lives_of(my_id()) <= 0


func is_bot(peer: int) -> bool:
	return peer >= BOT_BASE


func humans() -> int:
	var n := 0
	for p: int in roster:
		if not is_bot(p):
			n += 1
	return n


func bot_count() -> int:
	return roster.size() - humans()


## All vs All and Teams need someone to fight. Bots count.
func can_start() -> bool:
	if rules == Rules.FFA:
		return roster.size() >= 2
	if rules == Rules.TEAMS:
		var teams := {}
		for p: int in roster:
			teams[int(roster[p]["team"])] = true
		return teams.size() >= 2
	return true


## Whether two players are on opposite sides, whoever's phone is asking.
func bots_foes(a: int, b: int) -> bool:
	if a == b or not pvp():
		return false
	if rules == Rules.TEAMS:
		return roster.has(a) and roster.has(b) and roster[a]["team"] != roster[b]["team"]
	return true


func set_bots(count: int) -> void:
	if not is_host():
		return
	count = clampi(count, 0, MAX_PLAYERS - humans())
	var mine: Array = roster.keys().filter(is_bot)
	mine.sort()
	while mine.size() > count:
		roster.erase(mine.pop_back())
	var i := 0
	while mine.size() < count:
		var id := BOT_BASE + i
		i += 1
		if roster.has(id):
			continue
		mine.append(id)
		var offered: Array = ClassDefs.ALL.keys().filter(func(c: String) -> bool: return not ClassDefs.ALL[c].get("no_bots", false) and not ClassDefs.disabled(c) and (not ClassDefs.ALL[c].get("hidden", false) or ClassDefs.ALL[c].has("earned")))
		# Each bot something different, as long as there are enough to go round.
		for other: int in mine:
			if roster.has(other):
				offered.erase(roster[other]["class"])
		var name_for_bot: String = BOT_NAMES[i % BOT_NAMES.size()]
		roster[id] = {"name": "%s (bot)" % name_for_bot, "class": offered[randi() % offered.size()], "team": 0, "score": 0, "deaths": 0, "lives": LIVES}
	_share_lobby()


## Bots take whichever side leaves the teams even. People choose for themselves.
func _balance_bots() -> void:
	var count := [0, 0]
	for p: int in roster:
		if not is_bot(p):
			count[int(roster[p]["team"])] += 1
	var mine: Array = roster.keys().filter(is_bot)
	mine.sort()
	for p: int in mine:
		var team := 0 if count[0] <= count[1] else 1
		roster[p]["team"] = team
		count[team] += 1


func _share_lobby() -> void:
	_room_dirty = true
	_balance_bots()
	_lobby.rpc(roster, rules, difficulty, night_map)
	lobby_changed.emit()


func game_mode() -> int:
	return Game.Mode.FORT if rules == Rules.FORT else Game.Mode.NIGHT


func avatar(peer: int) -> Avatar:
	return _avatars.get(peer)


func is_foe(peer: int) -> bool:
	if not pvp():
		return false
	if rules == Rules.TEAMS:
		# Someone who has just left can still have a message on its way.
		if not roster.has(peer) or not roster.has(my_id()):
			return false
		return roster[peer]["team"] != roster[my_id()]["team"]
	return peer != my_id()


# --- Connecting --------------------------------------------------------------

func host_game() -> Error:
	leave()
	way = Way.LOCAL
	PhoneNet.use_default()
	PhoneNet.hold_wifi()
	var e := ENetMultiplayerPeer.new()
	var err := e.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		# Right after moving from Wi-Fi to mobile data, the phone can still be tied to the old network.
		PhoneNet.use_active()
		e = ENetMultiplayerPeer.new()
		err = e.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		PhoneNet.use_default()
		return err
	multiplayer.multiplayer_peer = e
	role = Role.HOST
	rules = Rules.COOP
	difficulty = Game.difficulty
	_over = false
	roster = {1: _my_entry(0)}
	_start_beacon()
	set_process(true)
	lobby_changed.emit()
	return OK


func join_game(address: String) -> Error:
	leave()
	way = Way.LOCAL
	# A game nearby needs the Wi-Fi even if it has no internet.
	PhoneNet.use_wifi()
	PhoneNet.hold_wifi()
	var e := ENetMultiplayerPeer.new()
	var err := e.create_client(address, PORT)
	if err != OK:
		return err
	e.get_peer(1).set_timeout(TIMEOUT_FACTOR, TIMEOUT_MIN, TIMEOUT_MAX)
	multiplayer.multiplayer_peer = e
	role = Role.CLIENT
	_over = false
	set_process(true)
	return OK


## Online. These return why it failed, or "" if all is well. A listed game shows in everyone's list
## of public games; one that is not can only be joined with its code.
func host_online(listed := true) -> String:
	leave()
	var e := _online_node()
	if not await e.sign_in():
		return e.last_error
	room_listed = listed
	var code := await e.open_room(listed)
	if code == "":
		# Not fatal: the host's own ID works as a (long) code, because only the room lookup needs a room.
		room_problem = e.last_error
		code = e.own_id()
	var peer := e.make_peer()
	if peer == null:
		e.close_room()
		return e.last_error
	way = Way.ONLINE
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	rules = Rules.COOP
	difficulty = Game.difficulty
	_over = false
	roster = {1: _my_entry(0)}
	room_code = code
	_room_dirty = true
	set_process(true)
	lobby_changed.emit()
	return ""


## Public or private, from the room. The list hears about it a moment later.
func set_listed(listed: bool) -> void:
	if not is_host() or way != Way.ONLINE:
		return
	room_listed = listed
	_room_dirty = true
	lobby_changed.emit()


## Looks up the public games online. The list arrives through public_rooms_changed.
func look_for_rooms() -> void:
	if looking_up:
		return
	looking_up = true
	lookup_problem = ""
	var e := _online_node()
	if not await e.sign_in():
		lookup_problem = e.last_error
	else:
		public_rooms = await e.list_rooms()
		lookup_problem = e.last_error
	looking_up = false
	public_rooms_changed.emit()


## Tells the list what this room is like now, at most every couple of seconds.
func _tick_room(delta: float) -> void:
	_room_wait -= delta
	if not _room_dirty or _room_wait > 0.0 or online == null or not is_host() or way != Way.ONLINE:
		return
	_room_dirty = false
	_room_wait = 2.0
	if not await online.update_room(EpicNet.room_card(room_listed, not in_game)):
		_room_dirty = true


func join_online(code: String) -> String:
	leave()
	var e := _online_node()
	if not await e.sign_in():
		return e.last_error
	var host_user := await e.find_room(code)
	if host_user == "":
		return e.last_error
	var peer := e.make_peer(host_user)
	if peer == null:
		return e.last_error
	way = Way.ONLINE
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_over = false
	_connect_wait = CONNECT_WAIT
	set_process(true)
	return ""


func _online_node() -> EpicNet:
	if online == null:
		online = EpicNet.new()
		add_child(online)
	return online


func leave(reason := "") -> void:
	_out_seq.clear()
	_in_seq.clear()
	var was_active := active()
	if online:
		online.close_room()
	room_code = ""
	room_problem = ""
	_connect_wait = 0.0
	PhoneNet.use_default()
	PhoneNet.release_wifi()
	stop_search_keep_rooms()
	if _beacon:
		_beacon.close()
		_beacon = null
	if _answer:
		_answer.close()
		_answer = null
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.OFFLINE
	in_game = false
	world = null
	forced_quality = -1
	started_loading = false
	roster.clear()
	_loaded.clear()
	_avatars.clear()
	_bots.clear()
	_stop_watching()
	spectate_cam = null
	_respawn_left = -1.0
	_command_ready.clear()
	_over = false
	set_physics_process(false)
	set_process(_listener != null)
	if was_active and reason != "":
		left.emit(reason)


func _my_entry(team: int) -> Dictionary:
	return {"name": Game.player_name, "class": Game.player_class, "team": team, "score": 0, "deaths": 0, "lives": LIVES}


func _on_connected() -> void:
	_connect_wait = 0.0
	_hello.rpc_id(1, protocol_version(), Game.player_name, Game.player_class)


func _on_failed() -> void:
	if way == Way.LOCAL:
		leave("Could not reach that game. Are you both on the same Wi-Fi?\nIf this phone has mobile data on, try turning it off.")
	else:
		leave("Could not reach that game. Check that the host is still in the lobby, and try again.")


func _on_server_gone() -> void:
	if way == Way.LOCAL:
		leave("Lost touch with the host.\nThey may have left. If this keeps happening, turn off this phone's mobile data.")
	else:
		leave("Lost touch with the host. They may have left.")


func _on_peer_connected(id: int) -> void:
	if is_host() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id).set_timeout(TIMEOUT_FACTOR, TIMEOUT_MIN, TIMEOUT_MAX)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		_remove_peer(id)
		return
	roster.erase(id)
	_loaded.erase(id)
	_remove_peer(id)
	if in_game:
		_lobby.rpc(roster, rules, difficulty, night_map)
		lobby_changed.emit()
	else:
		_share_lobby()
	if in_game:
		_check_loaded()
		_check_everyone_down()
		_check_last_standing.call_deferred()


func _remove_peer(id: int) -> void:
	roster.erase(id)
	if _avatars.has(id):
		var a: Avatar = _avatars[id]
		_avatars.erase(id)
		if world:
			world.players.erase(a)
		a.queue_free()
	lobby_changed.emit()


@rpc("any_peer", "reliable")
func _hello(protocol: int, player_name: String, cls: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != protocol_version():
		_refused.rpc_id(id, "That phone has a different version of the game.")
		return
	if not ClassDefs.ALL.has(cls) or roster.has(id):
		return
	# A real person takes a bot's place.
	if not in_game and roster.size() >= MAX_PLAYERS and bot_count() > 0:
		set_bots(bot_count() - 1)
	if in_game or roster.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "That game has already started." if in_game else "That game is full.")
		return
	if not class_slot_available(cls, id):
		cls = "infantry"
	var team := _smaller_team()
	roster[id] = {"name": player_name.substr(0, 16), "class": cls, "team": team, "score": 0, "deaths": 0, "lives": LIVES}
	_share_lobby()


func _smaller_team() -> int:
	var count := [0, 0]
	for p: int in roster:
		if not is_bot(p):
			count[int(roster[p]["team"])] += 1
	return 0 if count[0] <= count[1] else 1


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave(reason)


@rpc("authority", "reliable")
func _lobby(new_roster: Dictionary, new_rules: int, new_difficulty: int, new_map: String) -> void:
	night_map = new_map
	roster = new_roster
	if roster.has(my_id()):
		Game.player_class = str(roster[my_id()]["class"])
	rules = new_rules
	difficulty = new_difficulty
	lobby_changed.emit()


## Lobby choices: anyone can change their own class and team, only the host the rules.
func set_my_class(cls: String) -> void:
	if in_game or not ClassDefs.ALL.has(cls) or not class_slot_available(cls, my_id()):
		return
	Game.player_class = cls
	if is_host():
		roster[1]["class"] = cls
		_share_lobby()
	elif active():
		_choice.rpc_id(1, cls, -1)


func switch_team() -> void:
	if in_game or not roster.has(my_id()):
		return
	var team := 1 - int(roster[my_id()]["team"])
	if is_host():
		roster[1]["team"] = team
		_share_lobby()
	elif active():
		_choice.rpc_id(1, "", team)


func set_difficulty(d: int) -> void:
	if is_host() and not in_game and d >= 0 and d <= 2:
		difficulty = d
		Game.difficulty = d
		_share_lobby()


func set_rules(r: int) -> void:
	if is_host() and not in_game and r >= Rules.COOP and r <= Rules.FORT:
		rules = r
		_share_lobby()


@rpc("any_peer", "reliable")
func _choice(cls: String, team: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or in_game or not roster.has(id):
		return
	if cls != "" and ClassDefs.ALL.has(cls) and class_slot_available(cls, id):
		roster[id]["class"] = cls
	if team == 0 or team == 1:
		roster[id]["team"] = team
	_share_lobby()


func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a: String in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.get_slice(".", 1).to_int() >= 16 and a.get_slice(".", 1).to_int() < 32):
			out.append(a)
	return out


# --- Finding games on the Wi-Fi ----------------------------------------------

func _start_beacon() -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_timer = 0.0
	# Hotspots and some routers drop broadcasts, so a joining phone can also ask around directly.
	_answer = PacketPeerUDP.new()
	var answer_error := _answer.bind(ASK_PORT)
	if answer_error != OK:
		push_warning("Could not bind LAN discovery responder: %s" % error_string(answer_error))
		_answer = null


func _beacon_text() -> PackedByteArray:
	return JSON.stringify({"g": "botti-last-stand", "v": protocol_version(), "n": Game.player_name, "p": roster.size(), "r": rules}).to_utf8_buffer()


func _answer_questions() -> void:
	while _answer and _answer.get_available_packet_count() > 0:
		var data := _answer.get_packet()
		if data.get_string_from_utf8() == "botti-last-stand?":
			_answer.set_dest_address(_answer.get_packet_ip(), DISCOVERY_PORT)
			_answer.put_packet(_beacon_text())


## Every address on this phone's own network gets one small question.
func _ask_around() -> void:
	var question := "botti-last-stand?".to_utf8_buffer()
	var targets := PackedStringArray(["127.0.0.1", "255.255.255.255"])
	for a in local_addresses():
		var base := "%s.%s.%s." % [a.get_slice(".", 0), a.get_slice(".", 1), a.get_slice(".", 2)]
		for i in range(1, 255):
			var other := base + str(i)
			if other != a:
				targets.append(other)
	for t in targets:
		_listener.set_dest_address(t, ASK_PORT)
		_listener.put_packet(question)


func _send_beacon() -> void:
	var text := _beacon_text()
	var targets := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for a in local_addresses():
		targets.append("%s.%s.%s.255" % [a.get_slice(".", 0), a.get_slice(".", 1), a.get_slice(".", 2)])
	for t in targets:
		_beacon.set_dest_address(t, DISCOVERY_PORT)
		_beacon.put_packet(text)


func start_search() -> void:
	if _listener:
		return
	PhoneNet.use_wifi()
	_listener = PacketPeerUDP.new()
	_listener.set_broadcast_enabled(true) # on Android this also lets broadcasts in
	var listen_error := _listener.bind(DISCOVERY_PORT)
	if listen_error != OK:
		push_warning("Could not bind LAN discovery listener: %s" % error_string(listen_error))
		_listener = null
		return
	rooms.clear()
	_ask_timer = 0.0
	set_process(true)


func stop_search() -> void:
	stop_search_keep_rooms()
	rooms.clear()
	if not active():
		PhoneNet.use_default()
		set_process(false)


func stop_search_keep_rooms() -> void:
	if _listener:
		_listener.close()
		_listener = null


func _read_beacons(delta: float) -> void:
	var changed := false
	while _listener and _listener.get_available_packet_count() > 0:
		var data := _listener.get_packet()
		var from := _listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
		if not parsed is Dictionary or (parsed as Dictionary).get("g", "") != "botti-last-stand":
			continue
		var d: Dictionary = parsed
		if not rooms.has(from):
			changed = true
		rooms[from] = {"name": str(d.get("n", "?")), "players": int(d.get("p", 1)), "rules": int(d.get("r", 0)), "version_ok": int(d.get("v", 0)) == protocol_version(), "seen": 0.0}
	for a: String in rooms.keys():
		rooms[a]["seen"] = float(rooms[a]["seen"]) + delta
		if float(rooms[a]["seen"]) > 4.0:
			rooms.erase(a)
			changed = true
	if changed:
		rooms_changed.emit()


func _process(delta: float) -> void:
	if _connect_wait > 0.0:
		_connect_wait -= delta
		if _connect_wait <= 0.0:
			_on_failed()
			return
	_read_beacons(delta)
	if _listener:
		_ask_timer -= delta
		if _ask_timer <= 0.0:
			_ask_timer = ASK_EVERY
			_ask_around()
	if is_host() and _beacon and not in_game:
		_answer_questions()
		_beacon_timer -= delta
		if _beacon_timer <= 0.0 and use_beacons:
			_beacon_timer = BEACON_EVERY
			_send_beacon()
	if in_game and world and is_instance_valid(world):
		_tick_respawn(delta)
	_tick_room(delta)


# --- Starting a game ---------------------------------------------------------

func start_match() -> void:
	if not is_host() or not can_start():
		return
	multiplayer.multiplayer_peer.refuse_new_connections = true
	if _beacon:
		_beacon.close()
		_beacon = null
	if _answer:
		_answer.close()
		_answer = null
	var tonight := Weather.roll()
	var fog_at := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	# Off the list of games waiting for players.
	_room_dirty = true
	for p: int in roster:
		roster[p]["lives"] = LIVES
	_begin.rpc(rules, Game.quality, Game.difficulty, roster, tonight, fog_at)
	_begin(rules, Game.quality, Game.difficulty, roster, tonight, fog_at)


## Everyone uses the host's numbers of zombies, because each zombie has the same id on every phone.
@rpc("authority", "reliable")
func _begin(new_rules: int, quality: int, difficulty: int, new_roster: Dictionary, tonight: int, fog_at: Vector2) -> void:
	rules = new_rules
	roster = new_roster
	if roster.has(my_id()):
		Game.player_class = str(roster[my_id()]["class"])
	weather = tonight
	fog_centre = fog_at
	last_winner = 0
	_started_with = roster.size()
	forced_quality = quality
	Game.difficulty = difficulty
	Game.player_class = str(roster[my_id()]["class"])
	in_game = true
	started_loading = true
	_loaded.clear()
	_over = false
	game_started.emit()


func attach(w: World) -> void:
	_command_ready.clear()
	world = w
	for peer: int in roster:
		if peer != my_id():
			var a := Avatar.new(w, peer, roster[peer])
			w.add_child(a)
			a.teleport(w.player_start(int(peer)))
			_avatars[peer] = a
			w.players.append(a)
			if is_host() and is_bot(peer):
				var bot := BotPlayer.new(w, a, roster[peer])
				w.add_child(bot)
				_bots[peer] = bot
	w.player.global_position = w.player_start(my_id())


## Called once the phone has built the map and loaded its shaders.
func report_loaded() -> void:
	if is_host():
		_loaded[1] = true
		_check_loaded()
	else:
		_peer_loaded.rpc_id(1)


@rpc("any_peer", "reliable")
func _peer_loaded() -> void:
	_loaded[multiplayer.get_remote_sender_id()] = true
	_check_loaded()


func _check_loaded() -> void:
	if not is_host() or not in_game or not started_loading:
		return
	for p: int in roster:
		if not _loaded.has(p) and not is_bot(p):
			return
	started_loading = false
	_go.rpc()
	_go()
	world.director.begin(true)


@rpc("authority", "reliable")
func _go() -> void:
	started_loading = false
	_in_seq.clear() # a new night: whatever was counted before belongs to the last one
	set_physics_process(true)
	all_ready.emit()


# --- Every tick --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	_pose_timer -= delta
	if _pose_timer <= 0.0:
		_pose_timer = POSE_EVERY
		_send_pose()
	_ally_timer -= delta
	if _ally_timer <= 0.0:
		_ally_timer = 0.12
		_send_allies()
	if is_host():
		_snap_timer -= delta
		if _snap_timer <= 0.0:
			_snap_timer = SNAPSHOT_EVERY
			_send_snapshot()
		_clock_timer -= delta
		if _clock_timer <= 0.0:
			_clock_timer = 1.0
			_clock.rpc(next_seq("clock"), world.director.elapsed)
			_check_everyone_down()


## Summons belong to the phone that called them. The others see them, and the host's enemies fight them.
func _send_allies() -> void:
	var mine: Array[Ally] = []
	for a in world.allies:
		if a.remote_owner == 0 and not a.dead:
			mine.append(a)
	# Packets can get lost, so the word that a summon is gone goes out more than once.
	if mine.is_empty():
		if _ally_goodbyes <= 0:
			return
		_ally_goodbyes -= 1
	else:
		_ally_goodbyes = 5
	var b := PackedByteArray()
	b.resize(mine.size() * 9 + 1)
	var at := 0
	for a in mine:
		b.encode_u8(at, a.net_index)
		b.encode_u8(at + 1, Ally.KINDS.find(a.kind) | (128 if a._attack_left > 0.0 else 0))
		b.encode_s16(at + 2, int(a.position.x * 100.0))
		b.encode_s16(at + 4, int(a.position.y * 100.0))
		b.encode_s16(at + 6, int(a.position.z * 100.0))
		b.encode_u8(at + 8, int(wrapf(a.rotation.y, 0.0, TAU) / TAU * 255.0))
		at += 9
	_allies_pose.rpc(next_seq("allies"), b)


@rpc("any_peer", "unreliable", "call_remote", 4)
func _allies_pose(seq: int, b: PackedByteArray) -> void:
	if world and is_instance_valid(world) and fresh(["allies", multiplayer.get_remote_sender_id()], seq):
		world.net_remote_allies(multiplayer.get_remote_sender_id(), b)


func ally_hurt(owner_peer: int, index: int, amount: float) -> void:
	_ally_hurt.rpc_id(owner_peer, index, amount)


@rpc("any_peer", "reliable")
func _ally_hurt(index: int, amount: float) -> void:
	if world and is_instance_valid(world):
		for a in world.allies:
			if a.remote_owner == 0 and a.net_index == index:
				a.hurt(amount, a.global_position)
				return


## Things other players should see, but that only one phone works out.
## Sparks are many and a lost one doesn't matter; a sentry or a burning patch is placed once and
## lasts, so those go reliably and every phone gets them.
func world_fx(kind: int, a: Vector3, b := Vector3.ZERO, by := 0) -> void:
	if kind == Fx.SPARK:
		_world_fx.rpc(kind, a, b, by if by != 0 else my_id())
	else:
		_world_fx_sure.rpc(kind, a, b, by if by != 0 else my_id())


@rpc("any_peer", "reliable", "call_remote")
func _world_fx_sure(kind: int, a: Vector3, b: Vector3, by: int) -> void:
	_world_fx(kind, a, b, by)


@rpc("any_peer", "unreliable", "call_remote")
func _world_fx(kind: int, a: Vector3, b: Vector3, by: int) -> void:
	if world == null or not is_instance_valid(world):
		return
	match kind:
		Fx.FIRE_PATCH: world.drop_poison(a, true, b.x, b.y, true, by)
		Fx.POISON_PATCH: world.drop_poison(a, false, b.x, b.y, true, by)
		Fx.SPARK: world.fx_spark(a, b)
		Fx.SENTRY: world.place_sentry(null, a, b.x)


func set_night_map(id: String) -> void:
	if is_host() and not in_game and Game.MAPS.has(id):
		night_map = id
		_share_lobby()


func send_portals(bits: PackedByteArray) -> void:
	_portals.rpc(bits)


@rpc("authority", "reliable", "call_remote")
func _portals(bits: PackedByteArray) -> void:
	if world and is_instance_valid(world) and world.portals:
		world.portals.apply_state(bits)


func ring_fx(at: Vector3, radius: float, col: Color) -> void:
	if active():
		_ring_fx.rpc(at, radius, col)


@rpc("any_peer", "unreliable", "call_remote")
func _ring_fx(at: Vector3, radius: float, col: Color) -> void:
	if world and is_instance_valid(world):
		world.show_ring(at, radius, col)


func cast_anim(anim_name := "") -> void:
	if active():
		_cast_anim.rpc(anim_name)


@rpc("any_peer", "unreliable", "call_remote")
func _cast_anim(anim_name: String) -> void:
	var a: Avatar = _avatars.get(multiplayer.get_remote_sender_id())
	if a and (anim_name == "" or BodyAnim.POSES.has(anim_name)):
		a.play_cast(anim_name)


func blast_fx(at: Vector3, radius: float, col: Color) -> void:
	_blast_fx.rpc(at, radius, col)


@rpc("any_peer", "unreliable", "call_remote")
func _blast_fx(at: Vector3, radius: float, col: Color) -> void:
	if world and is_instance_valid(world):
		world.fx_blast(at, radius, col)


func _send_pose() -> void:
	_pose.rpc(next_seq("pose"), pose_bytes(world.player))


@rpc("any_peer", "unreliable", "call_remote", 1)
func _pose(seq: int, b: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not fresh(["pose", sender], seq):
		return
	var a: Avatar = _avatars.get(sender)
	if a:
		_apply_pose(a, b)


## The next count for one of this phone's streams.
func next_seq(stream: Variant) -> int:
	var n := (int(_out_seq.get(stream, -1)) + 1) & 0xFFFF
	_out_seq[stream] = n
	return n


## True when a packet is newer than the last one used from the same stream (or, with same_ok, part
## of that same one), and remembers it. Counts wrap at 65536.
func fresh(key: Array, seq: int, same_ok := false) -> bool:
	var last: int = _in_seq.get(key, -1)
	if last >= 0:
		var ahead := (seq - last) & 0xFFFF
		if ahead == 0:
			return same_ok
		if ahead >= 0x8000:
			return false
	_in_seq[key] = seq & 0xFFFF
	return true


## What every zombie looks like right now: 12 bytes each. Losing a packet does not matter.
func _send_snapshot() -> void:
	var live := world.zombies
	if live.is_empty():
		return
	var b := PackedByteArray()
	b.resize(live.size() * 12)
	var at := 0
	for z in live:
		if z.net_id < 0 or z._dying > 0.0:
			continue
		b.encode_u8(at, z.net_id)
		b.encode_s16(at + 1, clampi(int(z.position.x * 100.0), -32000, 32000))
		b.encode_s16(at + 3, clampi(int(z.position.y * 100.0), -32000, 32000))
		b.encode_s16(at + 5, clampi(int(z.position.z * 100.0), -32000, 32000))
		b.encode_u8(at + 7, int(wrapf(z.rotation.y, 0.0, TAU) / TAU * 255.0))
		var flags: int = z.state | (4 if z.dormant else 0) | (8 if z.burn_time > 0.0 else 0) | (16 if z._stun > 0.0 else 0) \
			| (32 if z._frozen > 0.0 else 0) | (64 if z.is_warning() else 0) | (128 if z._mounted else 0)
		b.encode_u8(at + 8, flags)
		b.encode_u8(at + 9, clampi(int(z.hp / maxf(z.max_hp, 1.0) * 255.0), 0, 255))
		b.encode_u8(at + 10, int(_anim_ids.get(z._current_anim, 0)) | (64 if z.poison_left > 0.0 else 0) | (128 if z.bleed_left > 0.0 else 0))
		b.encode_u8(at + 11, clampi(int(z.anim_speed() * 40.0), 0, 255))
		at += 12
	b.resize(at)
	if at == 0:
		return
	# A night with many zombies would not fit one packet: send it in parts that share one count.
	var seq := next_seq("snapshot")
	var step := SNAPSHOT_CHUNK * 12
	for from in range(0, at, step):
		_snapshot.rpc(seq, b.slice(from, mini(from + step, at)))


@rpc("authority", "unreliable", "call_remote", 2)
func _snapshot(seq: int, b: PackedByteArray) -> void:
	if world == null or not is_instance_valid(world):
		return
	if not fresh(["snapshot"], seq, true):
		return
	var at := 0
	while at + 12 <= b.size():
		var z: Zombie = world.zombie_by_id(b.decode_u8(at))
		if z and z.active:
			var anim_byte := b.decode_u8(at + 10)
			z.net_apply(Vector3(b.decode_s16(at + 1), b.decode_s16(at + 3), b.decode_s16(at + 5)) * 0.01,
				b.decode_u8(at + 7) / 255.0 * TAU, b.decode_u8(at + 8), b.decode_u8(at + 9) / 255.0,
				ANIMS[mini(anim_byte & 63, ANIMS.size() - 1)], b.decode_u8(at + 11) / 40.0)
			if anim_byte & 192 != z.shown_debuffs:
				z.shown_debuffs = anim_byte & 192
				z.show_debuffs(anim_byte & 64 != 0, anim_byte & 128 != 0)
		at += 12


@rpc("authority", "unreliable", "call_remote", 3)
func _clock(seq: int, elapsed: float) -> void:
	if world and is_instance_valid(world) and fresh(["clock"], seq):
		world.director.elapsed = elapsed


# --- Zombies: host to everyone ----------------------------------------------

func zombie_spawned(z: Zombie, id: String, at: Vector3, minute: int) -> void:
	_z_spawn.rpc(z.net_id, id, at, minute)


@rpc("authority", "reliable")
func _z_spawn(net_id: int, id: String, at: Vector3, minute: int) -> void:
	if world and is_instance_valid(world):
		world.net_spawn_zombie(net_id, id, at, minute)


func zombie_died(z: Zombie, killer: int) -> void:
	_z_died.rpc(z.net_id, killer)
	if killer > 0 and roster.has(killer):
		roster[killer]["score"] = int(roster[killer]["score"]) + 1
		_score.rpc(killer, roster[killer]["score"], roster[killer]["deaths"], lives_of(killer))
	_credit(z, killer)


@rpc("authority", "reliable")
func _z_died(net_id: int, killer: int) -> void:
	if world == null or not is_instance_valid(world):
		return
	var z: Zombie = world.zombie_by_id(net_id)
	if z == null or not z.active:
		return
	if z.def.get("mist_boss", false): world.director._mist_boss_defeated = true
	z.net_die()
	_credit(z, killer)


## The killer gets the kill. In co-op the others learn something too.
func _credit(z: Zombie, killer: int) -> void:
	if killer < 0: return
	for p: Player in world.local_players():
		if p.dead:
			continue
		if killer == p.net_id():
			p.on_kill(z)
		elif not pvp():
			p.add_xp(int(ceil(z.xp_value * 0.5)))


func zombie_gone(z: Zombie) -> void:
	_z_gone.rpc(z.net_id)


@rpc("authority", "reliable")
func _z_gone(net_id: int) -> void:
	if world and is_instance_valid(world):
		var z: Zombie = world.zombie_by_id(net_id)
		if z and z.active:
			z.release()


func zombie_weapon(z: Zombie) -> void:
	_z_weapon.rpc(z.net_id, z.weapon_id)


@rpc("authority", "reliable")
func _z_weapon(net_id: int, weapon: String) -> void:
	if world and is_instance_valid(world):
		var z: Zombie = world.zombie_by_id(net_id)
		if z and z.active:
			z.net_weapon(weapon)


func zombie_woke(z: Zombie) -> void:
	_z_woke.rpc(z.net_id)


@rpc("authority", "reliable")
func _z_woke(net_id: int) -> void:
	if world and is_instance_valid(world):
		var z: Zombie = world.zombie_by_id(net_id)
		if z and z.active:
			z.net_wake()


# --- Zombies: everyone to host ----------------------------------------------

func hit_zombie(z: Zombie, amount: float, dir: Vector3, knock: float, at: Vector3) -> void:
	_z_hit.rpc_id(1, z.net_id, amount, dir, knock, at)


@rpc("any_peer", "reliable")
func _z_hit(net_id: int, amount: float, dir: Vector3, knock: float, at: Vector3) -> void:
	if not is_host() or world == null:
		return
	var z: Zombie = world.zombie_by_id(net_id)
	if z and z.is_alive():
		z.next_hitter = multiplayer.get_remote_sender_id()
		z.take_damage(amount, dir, knock, at)


func effect_zombie(z: Zombie, what: int, a := 0.0, b := 0.0) -> void:
	_z_effect.rpc_id(1, z.net_id, what, a, b)


@rpc("any_peer", "reliable")
func _z_effect(net_id: int, what: int, a: float, b: float) -> void:
	if not is_host() or world == null:
		return
	var z: Zombie = world.zombie_by_id(net_id)
	if z == null or not z.is_alive():
		return
	z.last_hitter = multiplayer.get_remote_sender_id()
	match what:
		Zombie.Effect.STUN: z.stun(a)
		Zombie.Effect.SLOW: z.slow(a)
		Zombie.Effect.IGNITE: z.ignite(a)
		Zombie.Effect.MARK: z.mark(a, b)
		Zombie.Effect.DOT: z.add_dot(a, b)
		Zombie.Effect.BLEED: z.add_dot(a, b, true)
		Zombie.Effect.FORGET: z.forget()
		Zombie.Effect.FREEZE: z.freeze(a)
		Zombie.Effect.TAUNT: z.taunted_by(Vector3(a, 0.0, b))
		Zombie.Effect.PULL: z.pull_to(Vector3(a, 0.0, b))


func noise(at: Vector3, radius: float) -> void:
	_noise.rpc_id(1, at, radius)


@rpc("any_peer", "unreliable")
func _noise(at: Vector3, radius: float) -> void:
	if is_host() and world and is_instance_valid(world):
		world.make_noise(at, radius)


# --- Hurting a player --------------------------------------------------------

func hurt_peer(peer: int, amount: float, from: Vector3, attacker: Zombie) -> void:
	var zombie_id := attacker.net_id if attacker else -1
	if is_bot(peer):
		_hurt_bot(peer, amount, from, zombie_id, 0)
		return
	_hurt.rpc_id(peer, amount, from, zombie_id, 0)


## One player hitting another. The victim's own phone applies it, like any other damage. by is
## whoever struck: this phone's player, or one of the host's bots.
func hit_player(peer: int, amount: float, from: Vector3, by := 0) -> void:
	if by == 0:
		by = my_id()
	amount *= PVP_DAMAGE
	if is_bot(peer):
		_hurt_bot(peer, amount, from, -1, by)
	elif peer == my_id():
		_hurt(amount, from, -1, by)
	else:
		_hurt.rpc_id(peer, amount, from, -1, by)


# --- Bots: they live on the host, and the other phones only see their bodies ---

func _hurt_bot(peer: int, amount: float, from: Vector3, zombie_id: int, by_peer: int) -> void:
	if is_host():
		if _bots.has(peer):
			(_bots[peer] as BotPlayer).hurt_by(amount, from, zombie_id, by_peer)
	else:
		_bot_hurt.rpc_id(1, peer, amount, from, zombie_id, by_peer)


@rpc("any_peer", "reliable")
func _bot_hurt(peer: int, amount: float, from: Vector3, zombie_id: int, by_peer: int) -> void:
	_hurt_bot(peer, amount, from, zombie_id, by_peer)


func note_bot_fell(peer: int, by_peer: int) -> void:
	_note_death(peer, by_peer)


## What every phone needs to draw a player: where they are, how they look, what they hold and
## what is happening to them. The same for a person's phone and for a bot on the host.
func pose_bytes(p: Player) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(39)
	b.encode_float(0, p.global_position.x)
	b.encode_float(4, p.global_position.y)
	b.encode_float(8, p.global_position.z)
	b.encode_float(12, p.yaw)
	b.encode_float(16, p.pitch)
	b.encode_float(20, p.velocity.x)
	b.encode_float(24, p.velocity.z)
	b.encode_float(28, p.sight_factor())
	var flags := (1 if p.dead else 0) | (2 if p.is_unseen() else 0) | (4 if p.is_riding() else 0) | (8 if p.ride_behind != 0 else 0) \
		| (16 if p.has_flag("rescuer") else 0) | (32 if p.passenger != 0 else 0) \
		| (64 if p.is_riding() and p.mount_kind() == "chariot" else 0) | (128 if p.has_turret() else 0)
	b[32] = flags
	b[33] = p.attack_count & 255
	b[34] = _weapon_ids.find(p.weapon_id()) + 1
	b[35] = clampi(int(p.hp / maxf(p.max_hp(), 1.0) * 255.0), 0, 255)
	b[36] = clampi(int(p.m("cover") * 100.0), 0, 90)
	b[37] = clampi(int(p.m("cover_radius")), 0, 255)
	b[38] = p.status_bits()
	return b


func _apply_pose(a: Avatar, b: PackedByteArray) -> void:
	if not valid_pose(b):
		return
	var weapon: int = b[34]
	a.apply_pose(Vector3(b.decode_float(0), b.decode_float(4), b.decode_float(8)), b.decode_float(12), b.decode_float(16),
		Vector3(b.decode_float(20), 0, b.decode_float(24)), b.decode_float(28), b[32], b[33], _weapon_ids[weapon - 1] if weapon > 0 else "", b[35] / 255.0)
	a.cover_pct = b[36] / 100.0
	a.cover_radius = float(b[37])
	a.show_statuses(b[38])


## Validate before touching an avatar: truncated packets, unknown weapon indices and NaN/Inf
## transforms must never reach physics or the renderer. The wire format remains unchanged.
func valid_pose(b: PackedByteArray) -> bool:
	if b.size() != 39 or b[34] > _weapon_ids.size():
		return false
	for offset in range(0, 32, 4):
		if not is_finite(b.decode_float(offset)):
			return false
	return true


func bot_pose(bot: BotPlayer) -> void:
	var b := pose_bytes(bot.pawn)
	_apply_pose(bot.body, b)
	_bot_pose.rpc(next_seq(["bot", bot.peer]), bot.peer, b)


@rpc("authority", "unreliable", "call_remote", 1)
func _bot_pose(seq: int, peer: int, b: PackedByteArray) -> void:
	if not fresh(["bot", peer], seq):
		return
	var a: Avatar = _avatars.get(peer)
	if a:
		_apply_pose(a, b)


## A bot raising its hand for an ability, on the host and on every other phone.
func bot_cast(peer: int, anim_name := "") -> void:
	var a: Avatar = _avatars.get(peer)
	if a:
		a.play_cast(anim_name)
	_bot_cast.rpc(peer, anim_name)


@rpc("authority", "unreliable", "call_remote")
func _bot_cast(peer: int, anim_name: String) -> void:
	var a: Avatar = _avatars.get(peer)
	if a and (anim_name == "" or BodyAnim.POSES.has(anim_name)):
		a.play_cast(anim_name)


func bot_players() -> Array:
	return _bots.values()


## The host's bots as players, for effects that look after everyone on this phone.
func bot_pawns() -> Array[Player]:
	var out: Array[Player] = []
	for bot: BotPlayer in _bots.values():
		if bot.pawn and is_instance_valid(bot.pawn):
			out.append(bot.pawn)
	return out


## A Thief's Steal: the robbed player or bot lets go of the weapon in hand, on whichever phone it lives.
## A Thief (by: a person, or one of the host's bots) knocks the weapon out of someone's hand.
func disarm(peer: int, by: int, stun := false) -> void:
	_disarm.rpc(peer, by, stun)
	_disarm(peer, by, stun)


@rpc("any_peer", "reliable", "call_remote")
func _disarm(peer: int, by: int, stun: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	# A phone speaks for its own person; only the host speaks for its bots.
	if sender != 0 and sender != by and not (sender == 1 and is_bot(by)):
		return
	if world == null or not is_instance_valid(world) or world.player == null or not bots_foes(by, peer):
		return
	if peer == my_id():
		BanditKit.be_robbed(world.player, stun)
	elif is_host() and _bots.has(peer) and (_bots[peer] as BotPlayer).pawn:
		BanditKit.be_robbed((_bots[peer] as BotPlayer).pawn, stun)


## A Mercenary's Nightfall, so every phone can look after its own people inside it.
func nightfall(owner_peer: int, at: Vector3, radius: float, seconds: float, linger: float, bits: int) -> void:
	_nightfall.rpc(owner_peer, at, radius, seconds, linger, bits)


@rpc("any_peer", "reliable", "call_remote")
func _nightfall(owner_peer: int, at: Vector3, radius: float, seconds: float, linger: float, bits: int) -> void:
	if world and is_instance_valid(world):
		world.spawn_nightfall(owner_peer, at, radius, seconds, linger, bits)


## The host's player or one of its bots, by peer id. Null for anyone on another phone.
func local_player(peer: int) -> Player:
	if world == null or not is_instance_valid(world):
		return null
	if peer == my_id() or not active():
		return world.player
	for bot: BotPlayer in world.bots:
		if bot.peer == peer:
			return bot.pawn
	return null


@rpc("any_peer", "reliable")
func _hurt(amount: float, from: Vector3, zombie_id: int, by_peer: int) -> void:
	if world == null or not is_instance_valid(world) or world.player == null or _over:
		return
	var p := world.player
	if by_peer > 0:
		if not is_foe(by_peer):
			return
		p.last_foe = by_peer
		p.hit_by = str(roster.get(by_peer, {}).get("name", "another player"))
	else:
		p.last_foe = 0
	var z: Zombie = world.zombie_by_id(zombie_id) if zombie_id >= 0 else null
	p.hurt(amount, from, z)


## Frozen, stunned, slowed or set alight by another player. Everyone hears, so they can all see it.
func status_peer(peer: int, kind: int, seconds: float, by := 0) -> void:
	if by == 0:
		by = my_id()
	_status.rpc(peer, kind, seconds, by)
	_status(peer, kind, seconds, by)


@rpc("any_peer", "reliable", "call_remote")
func _status(peer: int, kind: int, seconds: float, by: int) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	if not bots_foes(by, peer):
		return
	if peer == my_id():
		world.player.apply_status(kind, seconds)
	elif _avatars.has(peer):
		(_avatars[peer] as Avatar).show_status(kind, seconds)
		if is_host() and _bots.has(peer):
			(_bots[peer] as BotPlayer).apply_status(kind, seconds)


func ignite_peer(peer: int, seconds: float) -> void:
	if is_bot(peer):
		if _bots.has(peer):
			(_bots[peer] as BotPlayer).ignite(seconds)
		return
	_ignite.rpc_id(peer, seconds)


@rpc("any_peer", "reliable")
func _ignite(seconds: float) -> void:
	if world and is_instance_valid(world) and world.player:
		world.player.ignite(seconds)


# --- Items -------------------------------------------------------------------

func pickup_spawned(p: Pickup, at: Vector3) -> void:
	_item_spawn.rpc(p.net_id, p.kind, p.item_id, p.bonus_arrows, at)


@rpc("authority", "reliable")
func _item_spawn(net_id: int, kind: int, item: String, bonus: int, at: Vector3) -> void:
	if world and is_instance_valid(world):
		world.net_spawn_pickup(net_id, kind, item, bonus, at)


func pickup_gone(net_id: int) -> void:
	_item_gone.rpc(net_id)


@rpc("any_peer", "reliable", "call_remote")
func _item_gone(net_id: int) -> void:
	if world and is_instance_valid(world):
		world.net_remove_pickup(net_id)


func request_drop(at: Vector3, kind: int, item: String, bonus: int) -> void:
	_item_drop.rpc_id(1, at, kind, item, bonus)


@rpc("any_peer", "reliable")
func _item_drop(at: Vector3, kind: int, item: String, bonus: int) -> void:
	if is_host() and world and is_instance_valid(world):
		world.spawn_pickup_at(at, kind, item, bonus)


## A familiar turned up near this person. A bot has no ears; it finds familiars by looking.
func familiar_near(peer: int) -> void:
	if is_bot(peer) or not multiplayer.get_peers().has(peer):
		return
	_chime.rpc_id(peer)


@rpc("authority", "reliable")
func _chime() -> void:
	Sfx.play("familiar", -4.0)


# --- Shots and shared effects ------------------------------------------------

func shot(mesh: int, at: Vector3, vel: Vector3, grav: float, reach: float, fire: bool, col: Color) -> void:
	_shot.rpc(mesh, at, vel, grav, reach, fire, col)


@rpc("any_peer", "unreliable", "call_remote")
func _shot(mesh: int, at: Vector3, vel: Vector3, grav: float, reach: float, fire: bool, col: Color) -> void:
	if world and is_instance_valid(world):
		world.net_visual_shot(mesh, at, vel, grav, reach, fire, col)


func enemy_shot(fireball: bool, at: Vector3, target: Vector3, damage: float, reach: float, burning: bool, source: String) -> void:
	_enemy_shot.rpc(fireball, at, target, damage, reach, burning, source)


@rpc("authority", "reliable")
func _enemy_shot(fireball: bool, at: Vector3, target: Vector3, damage: float, reach: float, burning: bool, source: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	if fireball:
		world.spawn_fireball(at, target, damage, source)
	else:
		world.spawn_enemy_arrow(at, target, damage, reach, burning, source)


func sound_at(sound: String, at: Vector3, volume: float) -> void:
	var id: int = _sound_ids.get(sound, -1)
	if id >= 0:
		_sound.rpc(id, at, volume)


@rpc("authority", "unreliable")
func _sound(id: int, at: Vector3, volume: float) -> void:
	if world and is_instance_valid(world) and world.player:
		Sfx.play_at(SOUNDS[id], at, world.player.global_position, volume)


func sound_all(sound: String, volume: float, pitch := 1.0) -> void:
	_sound_all.rpc(sound, volume, pitch)


@rpc("authority", "reliable")
func _sound_all(sound: String, volume: float, pitch: float) -> void:
	Sfx.play(sound, volume, pitch, 0.1)


func gore(at: Vector3, col: Color) -> void:
	_gore.rpc(at, col)


@rpc("any_peer", "unreliable", "call_remote")
func _gore(at: Vector3, col: Color) -> void:
	if world and is_instance_valid(world):
		world.fx_gore(at, col)


func banner(text: String, seconds: float) -> void:
	_banner.rpc(text, seconds)


@rpc("authority", "reliable")
func _banner(text: String, seconds: float) -> void:
	if world and is_instance_valid(world):
		world.director.show_banner(text, seconds)


func send_fort(state: PackedByteArray) -> void:
	_fort_state.rpc(state)


@rpc("authority", "reliable", "call_remote", 5)
func _fort_state(state: PackedByteArray) -> void:
	if world and is_instance_valid(world) and world.fort:
		world.fort.apply_state(state)


func repair_gate(i: int, amount: float) -> void:
	_repair.rpc_id(1, i, amount)


@rpc("any_peer", "reliable")
func _repair(i: int, amount: float) -> void:
	if is_host() and world and is_instance_valid(world) and world.fort:
		world.fort.repair(i, amount)


func bell(minutes: int) -> void:
	_bell.rpc(minutes)


@rpc("authority", "reliable")
func _bell(minutes: int) -> void:
	if world and is_instance_valid(world):
		world.ring_bell(minutes)


func lightning(at: Vector3) -> void:
	_lightning.rpc(at)


@rpc("authority", "reliable")
func _lightning(at: Vector3) -> void:
	if world and is_instance_valid(world) and world.weather:
		world.weather.announce(at)


func dawn() -> void:
	_dawn.rpc()


@rpc("authority", "reliable")
func _dawn() -> void:
	if world and is_instance_valid(world):
		world.on_dawn()


# --- Falling, coming back, and the end of the game ---------------------------

func local_died(by_peer: int) -> void:
	var last_life := fog_rules() and lives_of(my_id()) <= 1
	if is_host():
		_note_death(1, by_peer)
	else:
		_died.rpc_id(1, by_peer)
	if last_life:
		_respawn_left = -1.0
		world.player.say("You are out")
	else:
		_respawn_left = FOG_RESPAWN if fog_rules() else RESPAWN_TIME
		world.player.say("You fell")
	_watching = 0
	watch_next()


@rpc("any_peer", "reliable")
func _died(by_peer: int) -> void:
	if is_host():
		_note_death(multiplayer.get_remote_sender_id(), by_peer)


func _note_death(peer: int, by_peer: int) -> void:
	if not roster.has(peer):
		return
	roster[peer]["deaths"] = int(roster[peer]["deaths"]) + 1
	if fog_rules():
		roster[peer]["lives"] = maxi(0, lives_of(peer) - 1)
		if lives_of(peer) == 0 and world:
			world.director.show_banner("%s is out" % roster[peer]["name"], 3.0)
	if _avatars.has(peer):
		(_avatars[peer] as Avatar).set_fallen(true)
	_score.rpc(peer, roster[peer]["score"], roster[peer]["deaths"], lives_of(peer))
	if by_peer > 0 and roster.has(by_peer):
		roster[by_peer]["score"] = int(roster[by_peer]["score"]) + KILL_POINTS
		_score.rpc(by_peer, roster[by_peer]["score"], roster[by_peer]["deaths"], lives_of(by_peer))
		_note_pvp.rpc(by_peer, peer)
		_note_pvp(by_peer, peer)
	_check_everyone_down.call_deferred()
	_check_last_standing.call_deferred()


@rpc("authority", "reliable")
func _note_pvp(killer: int, victim: int) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	if is_host() and _bots.has(killer) and (_bots[killer] as BotPlayer).pawn:
		var pawn: Player = (_bots[killer] as BotPlayer).pawn
		pawn.add_xp(80 if fog_rules() else 50)
		pawn.heal(25.0)
	if killer == my_id():
		world.player.add_xp(80 if fog_rules() else 50)
		world.player.heal(25.0)
		world.player.say("You defeated %s" % roster[victim]["name"])
	elif victim != my_id():
		world.player.say("%s defeated %s" % [roster[killer]["name"], roster[victim]["name"]])


@rpc("authority", "reliable")
func _score(peer: int, score: int, deaths: int, lives: int) -> void:
	if roster.has(peer):
		roster[peer]["score"] = score
		roster[peer]["deaths"] = deaths
		roster[peer]["lives"] = lives


## In co-op, the game ends when nobody is left standing.
func _check_everyone_down() -> void:
	if not is_host() or pvp() or world == null or _over:
		return
	for p in world.players:
		if not p.dead:
			return
	finish("The night took you all", "Nobody was left standing after %s." % Game.clock(world.director.elapsed))


## All vs All ends the moment only one player has a life left.
func _check_last_standing() -> void:
	if not is_host() or not fog_rules() or not in_game or _over:
		return
	var alive: Array = roster.keys().filter(func(p: int) -> bool: return lives_of(p) > 0)
	# Alone from the start, the fog decides. If the others have left, whoever is still here has won.
	# With every person out, nobody needs to sit and watch bots finish it off.
	var people_left := alive.any(func(p: int) -> bool: return not is_bot(p))
	if (alive.size() > 1 and people_left) or (alive.size() == 1 and _started_with < 2):
		return
	var winner: int = _best_score(alive if not alive.is_empty() else roster.keys())
	last_winner = winner
	_winner.rpc(winner)
	finish("Last one standing", "%s wins.\n%s" % [roster[winner]["name"], score_lines()])


func _best_score(among: Array) -> int:
	var best := -1
	var who := 1
	for p: int in among:
		if int(roster[p]["score"]) > best:
			best = int(roster[p]["score"])
			who = p
	return who


@rpc("authority", "reliable")
func _winner(peer: int) -> void:
	last_winner = peer


func _tick_respawn(delta: float) -> void:
	_tick_watching(delta)
	if _respawn_left < 0.0:
		return
	# A Guardian with the Rescuer gift nearby gets you up twice as fast.
	var speed := 1.0
	for peer: int in _avatars:
		var a: Avatar = _avatars[peer]
		if a.rescues and not a.dead and not is_foe(peer) and a.global_position.distance_to(world.player.global_position) < 12.0:
			speed = 2.0
	_respawn_left -= delta * speed
	if _respawn_left <= 0.0 and world.player:
		_respawn_left = -1.0
		_stop_watching()
		world.player.respawn(world.far_from_rivals() if pvp() else world.near_friend())
		var lives := lives_of(my_id())
		world.player.say(("Your last life!" if lives == 1 else "Back on your feet. %d lives left" % lives) if fog_rules() else "Back on your feet")


# --- Watching someone else while you wait -------------------------------------

func watch_next() -> void:
	if world == null or not is_instance_valid(world) or world.player == null or not world.player.dead:
		return
	var ids: Array = _avatars.keys()
	ids.sort()
	# On a team you only see through your own side's eyes: no scouting the enemy from the grave.
	var alive: Array = ids.filter(func(p: int) -> bool:
		return not (_avatars[p] as Avatar).dead and not (rules == Rules.TEAMS and is_foe(p)))
	if alive.is_empty():
		_stop_watching()
		return
	var next: int = alive[(alive.find(_watching) + 1) % alive.size()]
	_set_watching(next)


func _set_watching(peer: int) -> void:
	if _avatars.has(_watching):
		(_avatars[_watching] as Avatar).set_watched(false)
	_watching = peer
	if spectate_cam == null or not is_instance_valid(spectate_cam):
		spectate_cam = Camera3D.new()
		spectate_cam.fov = Player.BASE_FOV
		spectate_cam.near = 0.06
		spectate_cam.far = 460.0 if world.terrain.has_islands() else 100.0
		spectate_cam.set_cull_mask_value(2, false)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.8, 0.55)
		glow.light_energy = 0.9
		glow.omni_range = 11.0
		spectate_cam.add_child(glow)
		world.add_child(spectate_cam)
	(_avatars[peer] as Avatar).set_watched(true)
	spectate_cam.current = true


func _stop_watching() -> void:
	if _avatars.has(_watching):
		(_avatars[_watching] as Avatar).set_watched(false)
	_watching = 0
	if spectate_cam and is_instance_valid(spectate_cam):
		spectate_cam.current = false
	if world and is_instance_valid(world) and world.player:
		world.player.camera.current = true


func _tick_watching(_delta: float) -> void:
	if world.player == null or not world.player.dead:
		return
	var a: Avatar = _avatars.get(_watching)
	if a == null or a.dead:
		watch_next()
		a = _avatars.get(_watching)
		if a == null:
			return
	spectate_cam.global_transform = a.view_transform()


func watching_name() -> String:
	if _avatars.has(_watching):
		return (_avatars[_watching] as Avatar).display
	return ""


# --- Guardians and passengers -------------------------------------------------

func share_hit(peer: int, amount: float) -> void:
	if is_bot(peer):
		if is_host():
			var pawn := local_player(peer)
			if pawn:
				pawn.take_shared(amount)
		else:
			_bot_share.rpc_id(1, peer, amount)
		return
	_share.rpc_id(peer, amount)


@rpc("any_peer", "reliable")
func _bot_share(peer: int, amount: float) -> void:
	share_hit(peer, amount)


@rpc("any_peer", "reliable")
func _share(amount: float) -> void:
	if world and is_instance_valid(world) and world.player:
		world.player.take_shared(amount)


## A friend's Apothecary: a moment nobody can hurt you, and some health back.
func guard_peer(peer: int, seconds: float, healing: float) -> void:
	if is_bot(peer):
		if is_host():
			_guard_player(local_player(peer), seconds, healing)
		else:
			_bot_guard.rpc_id(1, peer, seconds, healing)
		return
	if peer == my_id():
		_guard_player(world.player, seconds, healing)
		return
	_guard.rpc_id(peer, seconds, healing)


@rpc("any_peer", "reliable")
func _bot_guard(peer: int, seconds: float, healing: float) -> void:
	guard_peer(peer, seconds, healing)


@rpc("any_peer", "reliable")
func _guard(seconds: float, healing: float) -> void:
	if world and is_instance_valid(world):
		_guard_player(world.player, seconds, healing)


func _guard_player(p: Player, seconds: float, healing: float) -> void:
	if p == null or p.dead:
		return
	p.guard_left = maxf(p.guard_left, seconds)
	if healing > 0.0:
		p.heal(healing)


func dome(at: Vector3, radius: float, seconds: float) -> void:
	_dome_fx.rpc(at, radius, seconds)


@rpc("any_peer", "reliable", "call_remote")
func _dome_fx(at: Vector3, radius: float, seconds: float) -> void:
	if world and is_instance_valid(world):
		world.fx_dome(at, radius, seconds)
		for ally: Ally in world.allies:
			if ally.remote_owner == 0 and not ally.dead and ally.global_position.distance_to(at - Vector3.UP * 0.5) <= radius:
				ally.guarded = maxf(ally.guarded, clampf(seconds, 0.0, 6.0))


func mist(at: Vector3, size: float) -> void:
	_mist_fx.rpc(at, size)


@rpc("any_peer", "unreliable", "call_remote")
func _mist_fx(at: Vector3, size: float) -> void:
	if world and is_instance_valid(world):
		world.fx_mist(at, size)


## A friend's horse close enough to climb on, with the seat behind them free.
func nearby_horse(at: Vector3) -> int:
	for peer: int in _avatars:
		var a: Avatar = _avatars[peer]
		if a.is_mounted() and not a.has_passenger and not is_foe(peer) and at.distance_to(a.global_position) < 3.5:
			return peer
	return 0


func ask_to_ride(peer: int) -> void:
	if is_bot(peer):
		if is_host(): _accept_bot_ride(my_id(), peer)
		else: _bot_ride_ask.rpc_id(1, peer)
	else:
		_ride_ask.rpc_id(peer)


@rpc("any_peer", "reliable")
func _ride_ask() -> void:
	var who := multiplayer.get_remote_sender_id()
	var p := world.player if world and is_instance_valid(world) else null
	var yes := p != null and p.is_riding() and p.passenger == 0
	if yes:
		p.passenger = who
		p.say("%s climbs on behind you" % roster.get(who, {}).get("name", "A friend"))
	_ride_answer.rpc_id(who, yes)


@rpc("any_peer", "reliable")
func _ride_answer(yes: bool) -> void:
	if yes and world and is_instance_valid(world) and world.player:
		world.player.ride_behind = multiplayer.get_remote_sender_id()
		world.player.say("Riding behind %s" % roster.get(world.player.ride_behind, {}).get("name", "a friend"))


func stop_riding(peer: int) -> void:
	if is_bot(peer):
		if is_host(): _clear_bot_seat(my_id(), peer)
		else: _bot_ride_stop.rpc_id(1, peer)
		return
	if _avatars.has(peer):
		_ride_stop.rpc_id(peer)


@rpc("any_peer", "reliable")
func _ride_stop() -> void:
	if world and is_instance_valid(world) and world.player and world.player.passenger == multiplayer.get_remote_sender_id():
		world.player.passenger = 0


func drop_passenger(peer: int) -> void:
	if peer == my_id() and world and world.player:
		world.player.ride_behind = 0
		return
	if _avatars.has(peer):
		_ride_end.rpc_id(peer)


@rpc("any_peer", "reliable")
func _ride_end() -> void:
	if world and is_instance_valid(world) and world.player and (world.player.ride_behind == multiplayer.get_remote_sender_id() or (multiplayer.get_remote_sender_id() == 1 and is_bot(world.player.ride_behind))):
		world.player.ride_behind = 0


## After a match, the host takes everyone still here back to the room, ready for another night.
func return_to_room() -> void:
	if not is_host():
		return
	_back_to_room.rpc()
	_back_to_room()


@rpc("authority", "reliable")
func _back_to_room() -> void:
	in_game = false
	started_loading = false
	_over = false
	_dawn_ending = false
	last_winner = 0
	world = null
	_loaded.clear()
	_avatars.clear()
	_bots.clear()
	_stop_watching()
	spectate_cam = null
	_respawn_left = -1.0
	set_physics_process(false)
	for p: int in roster:
		roster[p]["score"] = 0
		roster[p]["deaths"] = 0
		roster[p]["lives"] = LIVES
	if is_host():
		multiplayer.multiplayer_peer.refuse_new_connections = false
		if way == Way.LOCAL:
			_start_beacon()
		_share_lobby()
	back_in_room.emit()


func respawn_seconds() -> float:
	return _respawn_left


## For the list of players: how one of them is doing. {hp (0..1), down, out, back_in (seconds,
## or -1 when unknown)}. Another phone's countdown is worked out from when its player fell here.
func player_state(peer: int) -> Dictionary:
	var out := fog_rules() and lives_of(peer) <= 0
	if peer == my_id():
		var me := world.player if world else null
		if me == null:
			return {"hp": 1.0, "down": false, "out": out, "back_in": -1.0}
		return {"hp": clampf(me.hp / me.max_hp(), 0.0, 1.0), "down": me.dead, "out": out, "back_in": _respawn_left}
	var a: Avatar = _avatars.get(peer)
	if a == null:
		return {"hp": 1.0, "down": false, "out": out, "back_in": -1.0}
	var back := -1.0
	if a.dead and not out and a.world:
		back = maxf(0.0, (FOG_RESPAWN if fog_rules() else RESPAWN_TIME) - (a.world.now - a.down_since))
	return {"hp": a.hp_fraction, "down": a.dead, "out": out, "back_in": back}


## The results, as the host sees them.
func on_dawn_reached() -> void:
	if not is_host():
		return
	_dawn_ending = true
	match rules:
		Rules.COOP, Rules.FORT:
			finish("Dawn!", "You survived the night together.\n" + score_lines())
		Rules.TEAMS:
			var totals := [0, 0]
			for p: int in roster:
				totals[int(roster[p]["team"])] += int(roster[p]["score"])
			var winner := "It is a draw"
			if totals[0] != totals[1]:
				winner = "Team %s wins" % ("Gold" if totals[0] > totals[1] else "Blue")
			finish("Dawn!", "%s, %d to %d.\n%s" % [winner, totals[0], totals[1], score_lines()])


func finish(title: String, line: String) -> void:
	if _over:
		return
	_over = true
	_finish.rpc(title, line, _dawn_ending)
	game_over.emit(title, line, _dawn_ending)


@rpc("authority", "reliable")
func _finish(title: String, line: String, reached_dawn: bool) -> void:
	_over = true
	_dawn_ending = reached_dawn
	game_over.emit(title, line, _dawn_ending)


func score_lines() -> String:
	var rows: Array = roster.keys()
	rows.sort_custom(func(a: int, b: int) -> bool: return int(roster[a]["score"]) > int(roster[b]["score"]))
	var out := PackedStringArray()
	for p: int in rows:
		out.append("%s: %d points, fell %d times" % [roster[p]["name"], roster[p]["score"], roster[p]["deaths"]])
	return "\n".join(out)


func team_colour(team: int) -> Color:
	return Color(0.95, 0.72, 0.2) if team == 0 else Color(0.35, 0.6, 1.0)


## The host serializes reservations, including simultaneous join/choice requests.
func class_slot_available(cls: String, peer: int) -> bool:
	if not ClassDefs.ALL.has(cls) or ClassDefs.disabled(cls):
		return false
	if is_bot(peer) and ClassDefs.ALL[cls].get("no_bots", false):
		return false
	if ClassDefs.ALL[cls].get("unique", false):
		for other: int in roster:
			if other != peer and roster[other]["class"] == cls:
				return false
	return true


var _command_ready := {} # host-only cooldowns, in this world's clock


func _commander_source(peer: int) -> Target:
	if not world or not is_instance_valid(world) or not roster.has(peer) or roster[peer]["class"] != "commander" or is_bot(peer):
		return null
	for target: Target in world.players:
		if world.peer_of(target) == peer and not target.dead:
			return target
	return null


func command_field(kind: String, at: Vector3, local_world: World = null) -> void:
	if not active():
		if local_world:
			var field := CommandField.new()
			local_world.add_child(field)
			field.setup(local_world, 1, kind, at)
			if kind == "gunner":
				local_world.director.show_banner("The Commander has called in an artillery barrage", 5.0)
	elif is_host():
		_accept_command_field(my_id(), kind, at)
	else:
		_request_command_field.rpc_id(1, kind, at)


@rpc("any_peer", "reliable")
func _request_command_field(kind: String, at: Vector3) -> void:
	if is_host():
		_accept_command_field(multiplayer.get_remote_sender_id(), kind, at)


func _accept_command_field(peer: int, kind: String, at: Vector3) -> void:
	var source := _commander_source(peer)
	if source == null or not kind in ["warlock", "gunner"] or not at.is_finite():
		return
	if absf(at.x) > world.half_size or absf(at.z) > world.half_size or world.now < float(_command_ready.get(peer, -1.0)):
		return
	_command_ready[peer] = world.now + CommanderKit.LAST_CD
	if kind == "warlock":
		at = source.global_position
	else:
		at.y = world.ground_at(at)
	_spawn_command_field.rpc(peer, kind, at)


@rpc("authority", "call_local", "reliable")
func _spawn_command_field(peer: int, kind: String, at: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	var field := CommandField.new()
	world.add_child(field)
	field.setup(world, peer, kind, at)
	if kind == "gunner":
		world.director.show_banner("The Commander has called in an artillery barrage", 5.0)


func command_rally(peer: int, radius: float, last: bool, local_world: World = null) -> void:
	if not active():
		if local_world:
			_apply_rally_player(local_world.player, last)
			local_world.fx_ring(local_world.player.global_position, radius, ClassDefs.color("commander"))
	elif is_host():
		_accept_rally(peer, radius, last)
	else:
		_request_rally.rpc_id(1, radius, last)


@rpc("any_peer", "reliable")
func _request_rally(radius: float, last: bool) -> void:
	if is_host():
		_accept_rally(multiplayer.get_remote_sender_id(), radius, last)


func _accept_rally(peer: int, radius: float, last: bool) -> void:
	var source := _commander_source(peer)
	if source == null or not is_finite(radius) or world.now < float(_command_ready.get(peer, -1.0)):
		return
	radius = clampf(radius, 0.0, 16.0)
	# Remote talent selections are local to their player; enforce the shortest legal trained cooldown.
	_command_ready[peer] = world.now + (CommanderKit.LAST_CD if last else CommanderKit.TRAINED_COMMAND_CD)
	world.fx_ring(source.global_position, radius, ClassDefs.color("commander"))
	blast_fx(source.global_position, radius, Color(0.85, 0.65, 0.25, 0.25))
	for target: Target in world.players:
		var other := world.peer_of(target)
		if other <= 0 or bots_foes(peer, other) or target.global_position.distance_to(source.global_position) > radius:
			continue
		if target is Player:
			_apply_rally_player(target, last)
		else:
			_receive_rally.rpc_id(other, last)


@rpc("authority", "reliable")
func _receive_rally(last: bool) -> void:
	if world and is_instance_valid(world):
		_apply_rally_player(world.player, last)


func _apply_rally_player(p: Player, last: bool) -> void:
	if p == null:
		return
	if last and p.dead:
		if fog_rules() and lives_of(p.net_id()) <= 0:
			return
		p.respawn(p.global_position)
		if p == world.player:
			_respawn_left = -1.0
			_stop_watching()
	if p.dead:
		return
	var duration := 8.0 if last else 6.0
	p._act({"do": "buff", "key": "command_speed", "stat": "speed", "val": 0.25, "secs": duration}, {})
	if last:
		p.heal(35.0)
		p.guard_left = maxf(p.guard_left, 2.0)
		p._act({"do": "buff", "key": "command_melee", "stat": "melee_damage", "val": 0.2, "secs": duration}, {})
		p._act({"do": "buff", "key": "command_ranged", "stat": "ranged_damage", "val": 0.2, "secs": duration}, {})
		p._act({"do": "buff", "key": "command_spell", "stat": "spell_damage", "val": 0.2, "secs": duration}, {})
	p.say("Last Command!" if last else "Forward!")


func command_impact_visual(at: Vector3, radius: float, storm: bool) -> void:
	if is_host():
		_command_impact_visual.rpc(at, radius, storm)


@rpc("authority", "call_remote", "reliable")
func _command_impact_visual(at: Vector3, radius: float, storm: bool) -> void:
	if world and is_instance_valid(world):
		CommandField.visual_impact(world, at, radius, storm)


## The authority starts each warning; every phone applies the eventual hit to its own player only.
func mist_seal(at: Vector3, radius: float, eye: float, delay: float, damage: float, source: int) -> void:
	if is_host():
		_spawn_mist_seal.rpc(at, radius, eye, delay, damage, source)


@rpc("authority", "call_local", "reliable")
func _spawn_mist_seal(at: Vector3, radius: float, eye: float, delay: float, damage: float, source: int) -> void:
	if world and is_instance_valid(world):
		MistSeal.create(world, at, radius, eye, delay, damage, source)


@rpc("any_peer", "reliable")
func _bot_ride_ask(carrier: int) -> void:
	if is_host(): _accept_bot_ride(multiplayer.get_remote_sender_id(), carrier)

func _accept_bot_ride(who: int, carrier: int) -> void:
	var bot := local_player(carrier)
	var rider: Target = world.player if who == my_id() else avatar(who)
	var yes := bot != null and rider != null and not rider.dead and bot.is_riding() and bot.passenger == 0 and not bots_foes(who, carrier) and rider.global_position.distance_to(bot.global_position) < 3.5
	if yes: bot.passenger = who
	if who == my_id(): _bot_ride_answer(yes, carrier)
	else: _bot_ride_answer.rpc_id(who, yes, carrier)

@rpc("authority", "reliable")
func _bot_ride_answer(yes: bool, carrier: int) -> void:
	if yes and world and world.player: world.player.ride_behind = carrier

@rpc("any_peer", "reliable")
func _bot_ride_stop(carrier: int) -> void:
	if is_host(): _clear_bot_seat(multiplayer.get_remote_sender_id(), carrier)

func _clear_bot_seat(who: int, carrier: int) -> void:
	var bot := local_player(carrier)
	if bot and bot.passenger == who: bot.passenger = 0

func start_mist_storm(island: int) -> void:
	if is_host(): _mist_storm_start.rpc(island)

@rpc("authority", "call_local", "reliable")
func _mist_storm_start(island: int) -> void:
	if world and is_instance_valid(world) and island >= -1 and island < 9:
		MistStorm.create(world, maxi(0, island), island == -1)


var _last_command_voice := -10.0

func command_voice(peer: int) -> void:
	if not active(): return
	if is_host(): _relay_command_voice(peer)
	else: _ask_command_voice.rpc_id(1)

@rpc("any_peer", "reliable")
func _ask_command_voice() -> void:
	if is_host(): _relay_command_voice(multiplayer.get_remote_sender_id())

func _relay_command_voice(peer: int) -> void:
	var source := _commander_source(peer)
	var now := Time.get_ticks_msec() / 1000.0
	if source == null or now - _last_command_voice < 2.0: return
	_last_command_voice = now
	_command_voice.rpc(peer, source.global_position)

@rpc("authority", "call_remote", "reliable")
func _command_voice(peer: int, at: Vector3) -> void:
	if peer != my_id() and world and world.player:
		Sfx.play_at("command", at, world.player.global_position, -1.0, 0.1)


func protect_peer(peer: int, seconds: float, healing: float) -> void:
	if peer == my_id() or (is_host() and is_bot(peer)):
		_protect_player(local_player(peer), seconds, healing)
	elif is_bot(peer): _bot_protect.rpc_id(1, peer, seconds, healing)
	else: _protect.rpc_id(peer, seconds, healing)

@rpc("any_peer", "reliable")
func _bot_protect(peer: int, seconds: float, healing: float) -> void:
	if is_host() and is_bot(peer): _protect_player(local_player(peer), seconds, healing)

@rpc("any_peer", "reliable")
func _protect(seconds: float, healing: float) -> void:
	if world and is_instance_valid(world): _protect_player(world.player, seconds, healing)

func _protect_player(p: Player, seconds: float, healing: float) -> void:
	if p == null or p.dead: return
	p.dome_left = maxf(p.dome_left, clampf(seconds, 0, 6))
	if healing > 0: p.heal(minf(healing, 30))


func heavy_visual(kind: int, at: Vector3, direction: Vector3, radius: float) -> void:
	_heavy_visual.rpc(kind, at, direction, radius)

@rpc("any_peer", "unreliable", "call_remote")
func _heavy_visual(kind: int, at: Vector3, direction: Vector3, radius: float) -> void:
	if world and is_instance_valid(world) and kind >= 0 and kind <= 2 and at.is_finite() and direction.is_finite() and is_finite(radius):
		HeavyWave.spawn_visual(world, kind, at, direction, clampf(radius, 0.1, 12.0))

func heavy_mend(at: Vector3, radius: float, healing: float, owner: int) -> void:
	_heavy_mend.rpc(at, radius, healing, owner)

@rpc("any_peer", "reliable", "call_remote")
func _heavy_mend(at: Vector3, radius: float, healing: float, owner: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if owner != sender and not (sender == 1 and is_bot(owner)): return
	if world and is_instance_valid(world) and at.is_finite() and is_finite(radius) and is_finite(healing):
		HeavyArts.mend_summons(world, owner, at, clampf(radius, 0.0, 10.0), clampf(healing, 0.0, 50.0))
