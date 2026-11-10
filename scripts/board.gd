extends Node
## The public leaderboard: your display name, the points from your matches, and the boards.
##
## Each build is pointed at its own board when it is made (project setting botti/leaderboard_url):
## the dev app at the dev board, the production app at the production board. Every answer says
## which board it came from, and an answer from the other one is refused, so the two never mix.
##
## The phone never says how many points it has. It reports what happened in each match, and the
## board works the points out with the same rule as match_points() below. Matches played offline
## wait here, saved, until the board can be reached; each has its own id, so none counts twice.

signal changed
## A match reached the board: {"points", "board", "before": {"all", "week"}, "all", "week"}.
signal counted(result: Dictionary)
## A week's prize was added to your doubloons: {"week", "rank", "doubloons"}.
signal prize(reward: Dictionary)

const SAVE_PATH := "user://board.cfg"
const API := 1
const NAME_MIN := 3
const NAME_MAX := 16
const MAX_SECONDS := 3600
const DIFFICULTY := [0.75, 1.0, 1.25]
const MAX_PENDING := 300
const TIMEOUT := 12.0
const MAPS := ["village", "mists", "fort"]
## Every board, by what it counts. "all" holds every match.
const BOARDS := {"all": "All", "night": "Night", "mists": "Mists", "fort": "Fort", "coop": "Co-op", "versus": "Versus"}

enum NameState { NONE, CHOSEN, TAKEN }

var url := ""
var token := "" # this phone's secret: only its fingerprint is kept on the board
var registered := "" # the name the board knows us by, once it does
var name_state: int = NameState.NONE
var taken_name := "" # a name chosen offline that someone else had already, or the board refused
var taken_blocked := false # true when the board refused it as rude rather than taken
var pending: Array[Dictionary] = []
var syncing := false
var last_error := ""
var last_points := 0 # what the last match was worth, for the end screen
var standing := {} # {"all": {...}, "week": {...}} after the last sync, if any
var _cache := {} # period -> [time, result]


func _ready() -> void:
	url = str(ProjectSettings.get_setting("botti/leaderboard_url", "")).strip_edges().trim_suffix("/")
	_load()


## Which board this build belongs to.
func channel() -> String:
	return "dev" if Game.is_dev_build() else "production"


func configured() -> bool:
	return url.begins_with("https://") or url.begins_with("http://127.0.0.1")


# --- Rules shared with the board (server/leaderboard/src/index.js) -------------------------------

static func match_points(seconds: int, kills: int, won: bool, difficulty: int) -> int:
	var minutes := int(mini(seconds, MAX_SECONDS) / 60.0)
	var base := kills + 5 * minutes + (50 if won else 0)
	return roundi(base * float(DIFFICULTY[clampi(difficulty, 0, 2)]))


## The name as the board will keep it, or "" if it can't be a name.
static func clean_name(raw: String) -> String:
	var name_text := " ".join(raw.strip_edges().split(" ", false))
	var length := name_text.length()
	if length < NAME_MIN or length > NAME_MAX:
		return ""
	var any := false
	for ch: String in name_text:
		# Letters of every alphabet: the board has the final word on what counts as one.
		var letter := ch.to_lower() != ch.to_upper() or ch.unicode_at(0) >= 0xC0
		var digit := ch >= "0" and ch <= "9"
		if letter or digit:
			any = true
		elif not ch in [" ", "_", ".", "'", "-"]:
			return ""
	return name_text if any else ""


## Why a name can't be used, in words for the player, or "" if it can.
static func name_problem(raw: String) -> String:
	var name_text := " ".join(raw.strip_edges().split(" ", false))
	if name_text.length() < NAME_MIN:
		return "At least %d letters." % NAME_MIN
	if name_text.length() > NAME_MAX:
		return "At most %d letters." % NAME_MAX
	if clean_name(name_text) == "":
		return "Letters, numbers, spaces and _ . ' - only."
	return ""


# --- Your name -----------------------------------------------------------------------------------

## True until the player has picked a name, or when the one they picked offline was taken.
func needs_name() -> bool:
	return name_state != NameState.CHOSEN


## Chooses or changes the display name. Asks the board first when it can, so names stay unique.
## Returns "" when done, or what went wrong in words for the player.
func choose_name(raw: String) -> String:
	var wanted := clean_name(raw)
	if wanted == "":
		return name_problem(raw)
	if configured():
		var answer: Dictionary
		if registered == "":
			answer = await _call(HTTPClient.METHOD_POST, "/v1/players", {"name": wanted, "token": _token()}, false)
		else:
			answer = await _call(HTTPClient.METHOD_PUT, "/v1/players/me", {"name": wanted}, true)
		match int(answer["code"]):
			200, 201:
				wanted = str(answer["data"].get("name", wanted))
				registered = wanted
			409:
				return "Someone already has that name."
			400:
				if answer["data"].get("error", "") == "name_blocked":
					return "That name isn't allowed. Choose another."
				return name_problem(raw) if name_problem(raw) != "" else "That name can't be used."
			429:
				return "You changed your name a moment ago. Try again in a few minutes."
			401:
				# The board doesn't know this phone any more: join it again under this name.
				registered = ""
				token = ""
				return await choose_name(raw)
			_:
				# No connection: keep the name here, and ask the board when it can be reached.
				if registered != "" and registered.to_lower() != wanted.to_lower():
					return "The leaderboard can't be reached, so your name can't be changed right now."
	Game.player_name = wanted
	Game.save_settings()
	name_state = NameState.CHOSEN
	taken_name = ""
	taken_blocked = false
	_save()
	changed.emit()
	if configured() and registered != "":
		sync()
	return ""


# --- Matches -------------------------------------------------------------------------------------

## A finished match, outside the Sandbox. Returns its points, and sends it when it can.
func record_match(seconds: float, kills: int, won: bool, mode: String, map: String, cls: String, spec: String, difficulty: int) -> int:
	var whole := clampi(roundi(seconds), 1, MAX_SECONDS)
	var entry := {
		"match_id": _hex(16), "seconds": whole, "kills": maxi(0, kills), "outcome": "won" if won else "lost",
		"difficulty": clampi(difficulty, 0, 2), "mode": mode, "map": map if map in MAPS else "village",
		"class": cls, "spec": spec, "version": str(ProjectSettings.get_setting("application/config/version")).substr(0, 40),
	}
	last_points = match_points(whole, entry["kills"], won, entry["difficulty"])
	pending.append(entry)
	while pending.size() > MAX_PENDING:
		pending.pop_front()
	_save()
	sync()
	return last_points


## Sends what is waiting. Safe to call at any time: it does nothing while a sync is running.
func sync() -> void:
	if syncing or not configured():
		return
	syncing = true
	last_error = ""
	if registered == "" and name_state == NameState.CHOSEN:
		await _join()
	var rejoined := false
	while registered != "" and not pending.is_empty():
		var entry: Dictionary = pending[0]
		var answer := await _call(HTTPClient.METHOD_POST, "/v1/matches", entry, true)
		var code := int(answer["code"])
		if code == 200:
			pending.pop_front()
			for period: String in ["all", "week"]:
				if answer["data"].has(period):
					standing[period] = answer["data"][period]
			_cache.clear()
			_save()
			if not answer["data"].get("duplicate", false):
				counted.emit(answer["data"])
		elif code == 400:
			# The board will never take this one, so it can't wait here for ever.
			push_warning("Leaderboard refused a match: %s" % answer["data"].get("error", ""))
			pending.pop_front()
			_save()
		elif code == 401 and not rejoined:
			# The board doesn't know this phone (it was reset): join again, once.
			rejoined = true
			registered = ""
			await _join()
		else:
			# Offline, or too many matches too quickly: try again later.
			last_error = str(answer["data"].get("error", "offline"))
			break
	syncing = false
	changed.emit()


## Joins the board under the name chosen offline.
func _join() -> void:
	var answer := await _call(HTTPClient.METHOD_POST, "/v1/players", {"name": Game.player_name, "token": _token()}, false)
	match int(answer["code"]):
		200, 201:
			registered = str(answer["data"].get("name", Game.player_name))
			if registered != Game.player_name:
				# The board already knew this phone under another name.
				Game.player_name = registered
				Game.save_settings()
			_save()
		409, 400:
			# Someone else took the name while we were offline, or the board won't have it: the
			# player picks another.
			taken_name = Game.player_name
			taken_blocked = answer["data"].get("error", "") == "name_blocked"
			name_state = NameState.TAKEN
			_save()
			changed.emit()


# --- The boards ----------------------------------------------------------------------------------

## The top players: period "all" or "week", on one of BOARDS.
## Returns {"ok", "entries", "me", "week_end", "prizes", "error"}.
func fetch(period: String, fresh := false, board := "all") -> Dictionary:
	if not configured():
		return {"ok": false, "error": "not_configured"}
	var key := period + "/" + board
	var cached: Array = _cache.get(key, [])
	if not fresh and not cached.is_empty() and Time.get_ticks_msec() - int(cached[0]) < 30000:
		return cached[1]
	if not pending.is_empty() or (registered == "" and name_state == NameState.CHOSEN):
		await sync()
	var answer := await _call(HTTPClient.METHOD_GET, "/v1/board?period=%s&board=%s" % [period, board], null, registered != "")
	var code := int(answer["code"])
	if code != 200:
		return {"ok": false, "error": str(answer["data"].get("error", "offline"))}
	var data: Dictionary = answer["data"]
	var result := {"ok": true, "entries": data.get("entries", []), "me": data.get("me", {}), "week_end": int(data.get("week_end", 0)), "prizes": data.get("prizes", [])}
	_cache[key] = [Time.get_ticks_msec(), result]
	return result


## Your own last matches, newest first. Returns {"ok", "matches", "error"}.
func history() -> Dictionary:
	if not configured():
		return {"ok": false, "error": "not_configured"}
	if not pending.is_empty() or (registered == "" and name_state == NameState.CHOSEN):
		await sync()
	if registered == "":
		return {"ok": true, "matches": []}
	var answer := await _call(HTTPClient.METHOD_GET, "/v1/players/me/matches", null, true)
	if int(answer["code"]) != 200:
		return {"ok": false, "error": str(answer["data"].get("error", "offline"))}
	return {"ok": true, "matches": answer["data"].get("matches", [])}


## Collects the doubloons of any week you finished in the top three. Each prize is added once:
## the save remembers which weeks were paid, and the board is told afterwards. Returns the prizes
## newly added, for the menu to announce.
func collect_prizes() -> Array:
	var won: Array = []
	if not configured() or registered == "":
		return won
	var answer := await _call(HTTPClient.METHOD_GET, "/v1/players/me", null, true)
	if int(answer["code"]) != 200:
		return won
	_adopt_name(str(answer["data"].get("name", "")))
	for reward: Variant in answer["data"].get("rewards", []):
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		var week := int(reward.get("week", -1))
		if week < 0:
			continue
		if Game.pay_board_prize(week, int(reward.get("doubloons", 0))):
			won.append(reward)
			prize.emit(reward)
		# Paid here, now or before: the board can stop offering it.
		await _call(HTTPClient.METHOD_POST, "/v1/rewards/claim", {"week": week}, true)
	return won


## The board renamed this player (from its admin page): the phone uses that name from now on.
func _adopt_name(on_board: String) -> void:
	if on_board == "" or on_board == registered or name_state != NameState.CHOSEN:
		return
	registered = on_board
	Game.player_name = on_board
	Game.save_settings()
	_save()
	changed.emit()


## "Ranger · Trapper", or just the class when no profession was reached.
static func class_label(cls: String, spec: String) -> String:
	if not ClassDefs.ALL.has(cls):
		return "—"
	var text := str(ClassDefs.ALL[cls]["name"])
	if spec != "":
		for s: Dictionary in AbilityData.tree(cls)["specs"]:
			if s["id"] == spec:
				return text + " · " + str(s["name"])
	return text


# --- Talking to the board ------------------------------------------------------------------------

## {"code": HTTP status, or 0 with no answer, "data": Dictionary}.
func _call(method: int, path: String, body: Variant, signed: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "User-Agent: BottisLastStand/%s" % ProjectSettings.get_setting("application/config/version")])
	if signed:
		headers.append("Authorization: Bearer " + _token())
	var sent := http.request(url + path, headers, method, "" if body == null else JSON.stringify(body))
	if sent != OK:
		http.queue_free()
		return {"code": 0, "data": {"error": "offline"}}
	var got: Array = await http.request_completed
	http.queue_free()
	var text := (got[3] as PackedByteArray).get_string_from_utf8()
	if int(got[0]) != HTTPRequest.RESULT_SUCCESS or not text.begins_with("{"):
		return {"code": 0, "data": {"error": "offline"}}
	var json := JSON.new()
	var data: Dictionary = json.data if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY else {}
	# Strict separation: an answer from the other channel's board counts as no answer at all.
	if data.get("env", "") != channel():
		return {"code": 0, "data": {"error": "wrong_board"}}
	return {"code": int(got[1]), "data": data}


func _token() -> String:
	if token == "":
		token = _hex(32)
		_save()
	return token


static func _hex(bytes: int) -> String:
	return Crypto.new().generate_random_bytes(bytes).hex_encode()


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	token = str(c.get_value("board", "token", ""))
	registered = str(c.get_value("board", "registered", ""))
	name_state = int(c.get_value("board", "name_state", NameState.NONE))
	taken_name = str(c.get_value("board", "taken_name", ""))
	taken_blocked = bool(c.get_value("board", "taken_blocked", false))
	var saved: Variant = c.get_value("board", "pending", [])
	pending.clear()
	if typeof(saved) == TYPE_ARRAY:
		for entry: Variant in saved:
			if typeof(entry) == TYPE_DICTIONARY:
				pending.append(entry)


func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("board", "token", token)
	c.set_value("board", "registered", registered)
	c.set_value("board", "name_state", name_state)
	c.set_value("board", "taken_name", taken_name)
	c.set_value("board", "taken_blocked", taken_blocked)
	c.set_value("board", "pending", pending)
	# Written beside the old file, then swapped in, so a crash can't lose the queue.
	var tmp := SAVE_PATH + ".tmp"
	if c.save(tmp) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
