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

enum Role { OFFLINE, HOST, CLIENT }
enum Rules { COOP, FFA, TEAMS, FORT }

const PORT := 27415
const DISCOVERY_PORT := 27416
const ASK_PORT := 27417
const ASK_EVERY := 2.5
const MAX_PLAYERS := 4
const PROTOCOL := 7
const SNAPSHOT_EVERY := 0.08
const POSE_EVERY := 0.066
const BEACON_EVERY := 1.0
const RESPAWN_TIME := 20.0
const PVP_DAMAGE := 0.55 # players hit each other less hard than they hit the undead
const KILL_POINTS := 5
const RULE_NAMES := ["Co-op Night", "All vs All", "Teams", "Defend the Fort"]
const SOUNDS := ["groan", "attack", "zombie_hurt", "zombie_death", "block", "crow", "gargoyle", "leaper", "wraith", "banshee", "mimic", "creak",
	"blast", "gallop", "hammer", "fireball", "bow", "thunk", "howl", "rooster", "bell", "wolf"]
const ANIMS := ["", "Idle", "Walking_A", "Walking_C", "Running_A", "Hit_A", "1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A", "Spellcast_Shoot",
	"2H_Ranged_Shoot", "PickUp", "Death_A", "Death_B"]

var role: int = Role.OFFLINE
var rules: int = Rules.COOP
var difficulty := 1
var spectate_cam: Camera3D
var _watching := 0
var roster := {} # peer id -> {name, class, team, score, deaths}
var rooms := {} # address -> {name, players, rules, seen}
var forced_quality := -1
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


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


func pvp() -> bool:
	return active() and (rules == Rules.FFA or rules == Rules.TEAMS)


func game_mode() -> int:
	return Game.Mode.FORT if rules == Rules.FORT else Game.Mode.NIGHT


func avatar(peer: int) -> Avatar:
	return _avatars.get(peer)


func is_foe(peer: int) -> bool:
	if not pvp():
		return false
	if rules == Rules.TEAMS:
		return roster[peer]["team"] != roster[my_id()]["team"]
	return peer != my_id()


# --- Connecting --------------------------------------------------------------

func host_game() -> Error:
	leave()
	var e := ENetMultiplayerPeer.new()
	var err := e.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
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
	var e := ENetMultiplayerPeer.new()
	var err := e.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = e
	role = Role.CLIENT
	_over = false
	set_process(true)
	return OK


func leave(reason := "") -> void:
	var was_active := active()
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
	_stop_watching()
	spectate_cam = null
	_respawn_left = -1.0
	_over = false
	set_physics_process(false)
	set_process(_listener != null)
	if was_active and reason != "":
		left.emit(reason)


func _my_entry(team: int) -> Dictionary:
	return {"name": Game.player_name, "class": Game.player_class, "team": team, "score": 0, "deaths": 0}


func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, Game.player_name, Game.player_class)


func _on_failed() -> void:
	leave("Could not reach that game. Are you both on the same Wi-Fi?")


func _on_server_gone() -> void:
	leave("The host left the game.")


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		_remove_peer(id)
		return
	roster.erase(id)
	_loaded.erase(id)
	_remove_peer(id)
	_lobby.rpc(roster, rules, difficulty)
	lobby_changed.emit()
	if in_game:
		_check_loaded()
		_check_everyone_down()


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
	if protocol != PROTOCOL:
		_refused.rpc_id(id, "That phone has a different version of the game.")
		return
	if in_game or roster.size() >= MAX_PLAYERS:
		_refused.rpc_id(id, "That game has already started." if in_game else "That game is full.")
		return
	var team := _smaller_team()
	roster[id] = {"name": player_name.substr(0, 16), "class": cls, "team": team, "score": 0, "deaths": 0}
	_lobby.rpc(roster, rules, difficulty)
	lobby_changed.emit()


func _smaller_team() -> int:
	var count := [0, 0]
	for p: int in roster:
		count[int(roster[p]["team"])] += 1
	return 0 if count[0] <= count[1] else 1


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave(reason)


@rpc("authority", "reliable")
func _lobby(new_roster: Dictionary, new_rules: int, new_difficulty: int) -> void:
	roster = new_roster
	rules = new_rules
	difficulty = new_difficulty
	lobby_changed.emit()


## Lobby choices: anyone can change their own class and team, only the host the rules.
func set_my_class(cls: String) -> void:
	Game.player_class = cls
	if is_host():
		roster[1]["class"] = cls
		_lobby.rpc(roster, rules, difficulty)
		lobby_changed.emit()
	elif active():
		_choice.rpc_id(1, cls, -1)


func switch_team() -> void:
	var team := 1 - int(roster[my_id()]["team"])
	if is_host():
		roster[1]["team"] = team
		_lobby.rpc(roster, rules, difficulty)
		lobby_changed.emit()
	elif active():
		_choice.rpc_id(1, "", team)


func set_difficulty(d: int) -> void:
	if is_host():
		difficulty = d
		Game.difficulty = d
		_lobby.rpc(roster, rules, difficulty)
		lobby_changed.emit()


func set_rules(r: int) -> void:
	if is_host():
		rules = r
		_lobby.rpc(roster, rules, difficulty)
		lobby_changed.emit()


@rpc("any_peer", "reliable")
func _choice(cls: String, team: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not roster.has(id):
		return
	if cls != "":
		roster[id]["class"] = cls
	if team >= 0:
		roster[id]["team"] = team
	_lobby.rpc(roster, rules, difficulty)
	lobby_changed.emit()


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
	if _answer.bind(ASK_PORT) != OK:
		_answer = null


func _beacon_text() -> PackedByteArray:
	return JSON.stringify({"g": "undead-drop", "v": PROTOCOL, "n": Game.player_name, "p": roster.size(), "r": rules}).to_utf8_buffer()


func _answer_questions() -> void:
	while _answer and _answer.get_available_packet_count() > 0:
		var data := _answer.get_packet()
		if data.get_string_from_utf8() == "undead-drop?":
			_answer.set_dest_address(_answer.get_packet_ip(), DISCOVERY_PORT)
			_answer.put_packet(_beacon_text())


## Every address on this phone's own network gets one small question.
func _ask_around() -> void:
	var question := "undead-drop?".to_utf8_buffer()
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
	_listener = PacketPeerUDP.new()
	_listener.set_broadcast_enabled(true) # on Android this also lets broadcasts in
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null
		return
	rooms.clear()
	_ask_timer = 0.0
	set_process(true)


func stop_search() -> void:
	stop_search_keep_rooms()
	rooms.clear()
	if not active():
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
		if not parsed is Dictionary or (parsed as Dictionary).get("g", "") != "undead-drop":
			continue
		var d: Dictionary = parsed
		if not rooms.has(from):
			changed = true
		rooms[from] = {"name": str(d.get("n", "?")), "players": int(d.get("p", 1)), "rules": int(d.get("r", 0)), "version_ok": int(d.get("v", 0)) == PROTOCOL, "seen": 0.0}
	for a: String in rooms.keys():
		rooms[a]["seen"] = float(rooms[a]["seen"]) + delta
		if float(rooms[a]["seen"]) > 4.0:
			rooms.erase(a)
			changed = true
	if changed:
		rooms_changed.emit()


func _process(delta: float) -> void:
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


# --- Starting a game ---------------------------------------------------------

func start_match() -> void:
	if not is_host():
		return
	multiplayer.multiplayer_peer.refuse_new_connections = true
	if _beacon:
		_beacon.close()
		_beacon = null
	if _answer:
		_answer.close()
		_answer = null
	_begin.rpc(rules, Game.quality, Game.difficulty, roster)
	_begin(rules, Game.quality, Game.difficulty, roster)


## Everyone uses the host's numbers of zombies, because each zombie has the same id on every phone.
@rpc("authority", "reliable")
func _begin(new_rules: int, quality: int, difficulty: int, new_roster: Dictionary) -> void:
	rules = new_rules
	roster = new_roster
	forced_quality = quality
	Game.difficulty = difficulty
	Game.player_class = str(roster[my_id()]["class"])
	in_game = true
	started_loading = true
	_loaded.clear()
	_over = false
	game_started.emit()


func attach(w: World) -> void:
	world = w
	for peer: int in roster:
		if peer != my_id():
			var a := Avatar.new(w, peer, roster[peer])
			w.add_child(a)
			a.global_position = w.player_start(int(peer))
			_avatars[peer] = a
			w.players.append(a)
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
		if not _loaded.has(p):
			return
	started_loading = false
	_go.rpc()
	_go()
	world.director.begin(true)


@rpc("authority", "reliable")
func _go() -> void:
	started_loading = false
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
			_clock.rpc(world.director.elapsed)
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
		b.encode_u8(at + 1, Ally.KINDS.find(a.kind))
		b.encode_s16(at + 2, int(a.position.x * 100.0))
		b.encode_s16(at + 4, int(a.position.y * 100.0))
		b.encode_s16(at + 6, int(a.position.z * 100.0))
		b.encode_u8(at + 8, int(wrapf(a.rotation.y, 0.0, TAU) / TAU * 255.0))
		at += 9
	_allies_pose.rpc(b)


@rpc("any_peer", "unreliable_ordered", "call_remote", 4)
func _allies_pose(b: PackedByteArray) -> void:
	if world and is_instance_valid(world):
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


func blast_fx(at: Vector3, radius: float, col: Color) -> void:
	_blast_fx.rpc(at, radius, col)


@rpc("any_peer", "unreliable", "call_remote")
func _blast_fx(at: Vector3, radius: float, col: Color) -> void:
	if world and is_instance_valid(world):
		world.fx_blast(at, radius, col)


func _send_pose() -> void:
	var p := world.player
	var b := PackedByteArray()
	b.resize(38)
	b.encode_float(0, p.global_position.x)
	b.encode_float(4, p.global_position.y)
	b.encode_float(8, p.global_position.z)
	b.encode_float(12, p.yaw)
	b.encode_float(16, p.pitch)
	b.encode_float(20, p.velocity.x)
	b.encode_float(24, p.velocity.z)
	b.encode_float(28, p.sight_factor())
	var flags := (1 if p.dead else 0) | (2 if p.is_unseen() else 0) | (4 if p.is_riding() else 0) | (8 if p.ride_behind != 0 else 0) \
		| (16 if p.has_flag("rescuer") else 0) | (32 if p.passenger != 0 else 0)
	b[32] = flags
	b[33] = p.attack_count & 255
	b[34] = _weapon_ids.find(p.weapon_id()) + 1
	b[35] = clampi(int(p.hp / maxf(p.max_hp(), 1.0) * 255.0), 0, 255)
	b[36] = clampi(int(p.m("cover") * 100.0), 0, 90)
	b[37] = clampi(int(p.m("cover_radius")), 0, 255)
	_pose.rpc(b)


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _pose(b: PackedByteArray) -> void:
	if b.size() < 38:
		return
	var a: Avatar = _avatars.get(multiplayer.get_remote_sender_id())
	if a == null:
		return
	var weapon: int = b[34]
	a.apply_pose(Vector3(b.decode_float(0), b.decode_float(4), b.decode_float(8)), b.decode_float(12), b.decode_float(16),
		Vector3(b.decode_float(20), 0, b.decode_float(24)), b.decode_float(28), b[32], b[33], _weapon_ids[weapon - 1] if weapon > 0 else "", b[35] / 255.0)
	a.cover_pct = b[36] / 100.0
	a.cover_radius = float(b[37])


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
		b.encode_u8(at + 10, int(_anim_ids.get(z._current_anim, 0)))
		b.encode_u8(at + 11, clampi(int(z.anim_speed() * 40.0), 0, 255))
		at += 12
	b.resize(at)
	if at > 0:
		_snapshot.rpc(b)


@rpc("authority", "unreliable_ordered", "call_remote", 2)
func _snapshot(b: PackedByteArray) -> void:
	if world == null or not is_instance_valid(world):
		return
	var at := 0
	while at + 12 <= b.size():
		var z: Zombie = world.zombie_by_id(b.decode_u8(at))
		if z and z.active:
			z.net_apply(Vector3(b.decode_s16(at + 1), b.decode_s16(at + 3), b.decode_s16(at + 5)) * 0.01,
				b.decode_u8(at + 7) / 255.0 * TAU, b.decode_u8(at + 8), b.decode_u8(at + 9) / 255.0,
				ANIMS[mini(b.decode_u8(at + 10), ANIMS.size() - 1)], b.decode_u8(at + 11) / 40.0)
		at += 12


@rpc("authority", "unreliable_ordered", "call_remote", 3)
func _clock(elapsed: float) -> void:
	if world and is_instance_valid(world):
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
		_score.rpc(killer, roster[killer]["score"], roster[killer]["deaths"])
	_credit(z, killer)


@rpc("authority", "reliable")
func _z_died(net_id: int, killer: int) -> void:
	if world == null or not is_instance_valid(world):
		return
	var z: Zombie = world.zombie_by_id(net_id)
	if z == null or not z.active:
		return
	z.net_die()
	_credit(z, killer)


## The killer gets the kill. In co-op the others learn something too.
func _credit(z: Zombie, killer: int) -> void:
	var p := world.player
	if p == null or p.dead:
		return
	if killer == my_id():
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
		Zombie.Effect.FORGET: z.forget()
		Zombie.Effect.FREEZE: z.freeze(a)


func noise(at: Vector3, radius: float) -> void:
	_noise.rpc_id(1, at, radius)


@rpc("any_peer", "unreliable")
func _noise(at: Vector3, radius: float) -> void:
	if is_host() and world and is_instance_valid(world):
		world.make_noise(at, radius)


# --- Hurting a player --------------------------------------------------------

func hurt_peer(peer: int, amount: float, from: Vector3, attacker: Zombie) -> void:
	_hurt.rpc_id(peer, amount, from, attacker.net_id if attacker else -1, 0)


## One player hitting another. The victim's own phone applies it, like any other damage.
func hit_player(peer: int, amount: float, from: Vector3) -> void:
	_hurt.rpc_id(peer, amount * PVP_DAMAGE, from, -1, my_id())


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


func ignite_peer(peer: int, seconds: float) -> void:
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


func familiar_near(peer: int) -> void:
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


@rpc("authority", "unreliable_ordered", "call_remote", 5)
func _fort_state(state: PackedByteArray) -> void:
	if world and is_instance_valid(world) and world.fort:
		world.fort.apply_state(state)


func repair_gate(i: int, amount: float) -> void:
	_repair.rpc_id(1, i, amount)


@rpc("any_peer", "reliable")
func _repair(i: int, amount: float) -> void:
	if is_host() and world and is_instance_valid(world) and world.fort:
		world.fort.repair(i, amount)


func bell() -> void:
	_bell.rpc()


@rpc("authority", "reliable")
func _bell() -> void:
	if world and is_instance_valid(world):
		world.ring_bell()


func dawn() -> void:
	_dawn.rpc()


@rpc("authority", "reliable")
func _dawn() -> void:
	if world and is_instance_valid(world):
		world.on_dawn()


# --- Falling, coming back, and the end of the game ---------------------------

func local_died(by_peer: int) -> void:
	if is_host():
		_note_death(1, by_peer)
	else:
		_died.rpc_id(1, by_peer)
	_respawn_left = RESPAWN_TIME
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
	if _avatars.has(peer):
		(_avatars[peer] as Avatar).dead = true
	_score.rpc(peer, roster[peer]["score"], roster[peer]["deaths"])
	if by_peer > 0 and roster.has(by_peer):
		roster[by_peer]["score"] = int(roster[by_peer]["score"]) + KILL_POINTS
		_score.rpc(by_peer, roster[by_peer]["score"], roster[by_peer]["deaths"])
		_note_pvp.rpc(by_peer, peer)
		_note_pvp(by_peer, peer)
	_check_everyone_down.call_deferred()


@rpc("authority", "reliable")
func _note_pvp(killer: int, victim: int) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	if killer == my_id():
		world.player.add_xp(30)
		world.player.say("You defeated %s" % roster[victim]["name"])
	elif victim != my_id():
		world.player.say("%s defeated %s" % [roster[killer]["name"], roster[victim]["name"]])


@rpc("authority", "reliable")
func _score(peer: int, score: int, deaths: int) -> void:
	if roster.has(peer):
		roster[peer]["score"] = score
		roster[peer]["deaths"] = deaths


## In co-op, the game ends when nobody is left standing.
func _check_everyone_down() -> void:
	if not is_host() or pvp() or world == null or _over:
		return
	for p in world.players:
		if not p.dead:
			return
	finish("The night took you all", "Nobody was left standing after %s." % Game.clock(world.director.elapsed))


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
		world.player.say("Back on your feet")


# --- Watching someone else while you wait -------------------------------------

func watch_next() -> void:
	if world == null or not is_instance_valid(world) or world.player == null or not world.player.dead:
		return
	var ids: Array = _avatars.keys()
	ids.sort()
	var alive: Array = ids.filter(func(p: int) -> bool: return not (_avatars[p] as Avatar).dead)
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
		spectate_cam.far = 100.0
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
	_share.rpc_id(peer, amount)


@rpc("any_peer", "reliable")
func _share(amount: float) -> void:
	if world and is_instance_valid(world) and world.player:
		world.player.take_shared(amount)


func guard_peer(peer: int, seconds: float, healing: float) -> void:
	_guard.rpc_id(peer, seconds, healing)


@rpc("any_peer", "reliable")
func _guard(seconds: float, healing: float) -> void:
	if world and is_instance_valid(world) and world.player and not world.player.dead:
		world.player.guard_left = maxf(world.player.guard_left, seconds)
		if healing > 0.0:
			world.player.heal(healing)


func dome(at: Vector3, radius: float, seconds: float) -> void:
	_dome_fx.rpc(at, radius, seconds)


@rpc("any_peer", "reliable", "call_remote")
func _dome_fx(at: Vector3, radius: float, seconds: float) -> void:
	if world and is_instance_valid(world):
		world.fx_dome(at, radius, seconds)


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
	if _avatars.has(peer):
		_ride_stop.rpc_id(peer)


@rpc("any_peer", "reliable")
func _ride_stop() -> void:
	if world and is_instance_valid(world) and world.player and world.player.passenger == multiplayer.get_remote_sender_id():
		world.player.passenger = 0


func drop_passenger(peer: int) -> void:
	if _avatars.has(peer):
		_ride_end.rpc_id(peer)


@rpc("any_peer", "reliable")
func _ride_end() -> void:
	if world and is_instance_valid(world) and world.player and world.player.ride_behind == multiplayer.get_remote_sender_id():
		world.player.ride_behind = 0


func respawn_seconds() -> float:
	return _respawn_left


## The results, as the host sees them.
func on_dawn_reached() -> void:
	if not is_host():
		return
	_dawn_ending = true
	match rules:
		Rules.COOP, Rules.FORT:
			finish("Dawn!", "You survived the night together.\n" + score_lines())
		Rules.FFA:
			var best := -1
			var name := ""
			for p: int in roster:
				if int(roster[p]["score"]) > best:
					best = roster[p]["score"]
					name = roster[p]["name"]
			finish("Dawn!", "%s wins with %d points.\n%s" % [name, best, score_lines()])
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
