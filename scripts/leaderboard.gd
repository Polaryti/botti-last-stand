extends Node
## Lifetime totals use MAX snapshots, so retries after an offline session cannot duplicate points.
## Epic's device identity is the key. Display names are labels and may be duplicated.

const LIMIT := 50
const EOS_SUCCESS := 0
const MAX_AGGREGATION := 1 # EOS_LA_Max
const PAIRS: Array[String] = [
	"infantry|", "infantry|duelist", "infantry|shadow", "infantry|berserker",
	"ranger|", "ranger|sharpshooter", "ranger|trapper", "ranger|beastmaster",
	"heavy|", "heavy|guardian", "heavy|warpriest", "heavy|warlord",
	"chivalry|", "chivalry|lancer", "chivalry|paladin", "chivalry|horse_archer",
	"magician|", "magician|necromancer", "magician|elementalist", "magician|illusionist",
	"revenant|", "revenant|leaper", "revenant|rift", "revenant|summoner",
	"monk|", "monk|bo_master", "monk|spirit_walker", "monk|iron_mountain",
	"adept|", "adept|blade_dancer", "adept|mirror_step", "adept|void_walker",
	"plague_doctor|", "plague_doctor|apothecary", "plague_doctor|pestilence", "plague_doctor|rat_king",
	"artificer|", "artificer|pyromaniac", "artificer|mechanic", "artificer|inventor",
	"commander|", "commander|warlock", "commander|gunner", "commander|vanguard"]

var busy := false
var last_error := ""
var _request_id := 0
var cached: Array[Dictionary] = []
var _cache_time := -100000

class Options:
	extends RefCounted
	var client_data: Variant = null
	var local_user_id := ""
	var target_user_id := ""
	var leaderboard_id := ""
	var leaderboard_record_index := 0
	var user_id := ""
	var start_time := -1
	var end_time := -1
	var stats: Array = []
	var stat_names: Array = []
	var name := ""
	var stat_info: Array = []
	var user_ids: Array = []
	var stat_name := ""


func prefix() -> String:
	return "BLS_DEV_" if Game.is_dev_build() else "BLS_"


func pair_stat(pair: String) -> String:
	return prefix() + "PLAY_" + pair.replace("|", "_").to_upper()


func favourite(counts: Dictionary) -> String:
	var best := ""
	var count := 0
	# Stable order makes ties deterministic across phones and releases.
	for pair: String in PAIRS:
		var played := int(counts.get(pair, 0))
		if played > count:
			best = pair
			count = played
	return best


func pair_label(pair: String) -> String:
	if not PAIRS.has(pair):
		return "—"
	var parts := pair.split("|")
	var cls: String = ClassDefs.ALL[parts[0]]["name"]
	if parts[1] == "":
		return cls + " / Unspecialised"
	for spec: Dictionary in AbilityData.tree(parts[0])["specs"]:
		if spec["id"] == parts[1]:
			return cls + " / " + str(spec["name"])
	return cls


func _request(eos: Object, method: String, callback: String, options: Options) -> Dictionary:
	_request_id += 1
	options.client_data = _request_id
	var expected := _request_id
	var results: Array = []
	var receive := func(data: Dictionary) -> void:
		if data.get("client_data") == expected:
			results.append(data)
	eos.connect(callback, receive)
	eos.call(method, options)
	var deadline := Time.get_ticks_msec() + 30000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	eos.disconnect(callback, receive)
	return results[0] if not results.is_empty() else {"result_code": -1}


func refresh(force := false) -> Array[Dictionary]:
	while busy:
		await get_tree().process_frame
	if not force and Time.get_ticks_msec() - _cache_time < 60000:
		return cached
	busy = true
	last_error = ""
	var epic := Net._online_node()
	if not await epic.sign_in():
		last_error = epic.last_error
		busy = false
		return cached
	var eos: Object = epic._ieos
	if not eos.has_method("stats_interface_ingest_stat") or not eos.has_method("leaderboards_interface_query_leaderboard_ranks"):
		last_error = "This build's online plugin does not support leaderboards."
		busy = false
		return cached
	var options := Options.new()
	options.local_user_id = epic.own_id()
	options.target_user_id = epic.own_id()
	# Read the server floor before preparing an outbox. The outbox survives a lost acknowledgement.
	options.stat_names = [prefix() + "POINTS"]
	for pair: String in PAIRS:
		options.stat_names.append(pair_stat(pair))
	var done := await _request(eos, "stats_interface_query_stats", "stats_interface_query_stats_callback", options)
	if int(done.get("result_code", -1)) != EOS_SUCCESS:
		return _failed("Could not read online progress", done)
	var read := Options.new()
	read.target_user_id = epic.own_id()
	read.name = prefix() + "POINTS"
	var value: Dictionary = eos.call("stats_interface_copy_stat_by_name", read)
	var remote_points := int(value.get("stat", {}).get("value", 0)) if int(value.get("result_code", -1)) == EOS_SUCCESS else 0
	var remote_plays := {}
	for pair: String in PAIRS:
		read.name = pair_stat(pair)
		value = eos.call("stats_interface_copy_stat_by_name", read)
		if int(value.get("result_code", -1)) == EOS_SUCCESS:
			remote_plays[pair] = int(value.get("stat", {}).get("value", 0))
	if Game.sync_snapshot.is_empty():
		Game.sync_snapshot = make_snapshot(remote_points, remote_plays)
		Game.save_settings() # before sending; retrying always sends this exact snapshot
	var snapshot := Game.sync_snapshot.duplicate(true)
	options.stats = [{"stat_name": prefix() + "POINTS", "ingest_amount": mini(int(snapshot["points"]), 2147483647)}]
	for pair: String in PAIRS:
		var count := int(snapshot["plays"].get(pair, 0))
		if count > 0:
			options.stats.append({"stat_name": pair_stat(pair), "ingest_amount": mini(count, 2147483647)})
	done = await _request(eos, "stats_interface_ingest_stat", "stats_interface_ingest_stat_callback", options)
	if int(done.get("result_code", -1)) != EOS_SUCCESS:
		return _failed("Could not sync online progress", done)
	acknowledge(snapshot)
	options.leaderboard_id = prefix() + "LIFETIME"
	done = await _request(eos, "leaderboards_interface_query_leaderboard_ranks", "leaderboards_interface_query_leaderboard_ranks_callback", options)
	if int(done.get("result_code", -1)) != EOS_SUCCESS:
		return _failed("Leaderboard unavailable", done)
	var rows: Array[Dictionary] = []
	var ids: Array = []
	var count := mini(LIMIT, int(eos.call("leaderboards_interface_get_leaderboard_record_count", options)))
	for i in count:
		options.leaderboard_record_index = i
		var copied: Dictionary = eos.call("leaderboards_interface_copy_leaderboard_record_by_index", options)
		if int(copied.get("result_code", -1)) != EOS_SUCCESS:
			continue
		var record: Dictionary = copied.get("record", {})
		var id := str(record.get("user_id", ""))
		if id == "":
			continue
		ids.append(id)
		var display := Game.clean_name(str(record.get("user_display_name", "")))
		rows.append({"id": id, "name": display if display != "" else "Unnamed player", "points": maxi(0, int(record.get("score", 0))), "favourite": ""})
	# One batched query per 10 stats; avoid a request for each individual player.
	var played_by_user := {}
	for id: String in ids:
		played_by_user[id] = {}
	if not ids.is_empty():
		options.user_ids = ids
		for start in range(0, PAIRS.size(), 10):
			options.stat_info = []
			for pair: String in PAIRS.slice(start, start + 10):
				options.stat_info.append({"stat_name": pair_stat(pair), "aggregation": MAX_AGGREGATION})
			done = await _request(eos, "leaderboards_interface_query_leaderboard_user_scores", "leaderboards_interface_query_leaderboard_user_scores_callback", options)
			if int(done.get("result_code", -1)) != EOS_SUCCESS:
				return _failed("Could not load favourite professions", done)
			for pair: String in PAIRS.slice(start, start + 10):
				options.stat_name = pair_stat(pair)
				for id: String in ids:
					options.user_id = id
					var copied: Dictionary = eos.call("leaderboards_interface_copy_leaderboard_user_score_by_user_id", options)
					if int(copied.get("result_code", -1)) == EOS_SUCCESS:
						played_by_user[id][pair] = int(copied.get("user_score", {}).get("score", 0))
	for row: Dictionary in rows:
		row["favourite"] = favourite(played_by_user[row["id"]])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["points"]) > int(b["points"]) if a["points"] != b["points"] else str(a["id"]) < str(b["id"]))
	cached = rows
	_cache_time = Time.get_ticks_msec()
	busy = false
	return cached


func _failed(message: String, data: Dictionary) -> Array[Dictionary]:
	last_error = "%s (%d). Check your connection or try again later." % [message, int(data.get("result_code", -1))]
	busy = false
	return cached


func make_snapshot(remote_points: int, remote_plays: Dictionary) -> Dictionary:
	var plays := {}
	for pair: String in PAIRS:
		var pending := int(Game.pending_plays.get(pair, 0))
		plays[pair] = maxi(int(remote_plays.get(pair, 0)), int(Game.class_plays.get(pair, 0)) - pending) + pending
	return {"points": maxi(remote_points, Game.total_points - Game.pending_points) + Game.pending_points,
		"plays": plays, "covered_points": Game.pending_points, "covered_plays": Game.pending_plays.duplicate()}


func acknowledge(snapshot: Dictionary) -> void:
	Game.pending_points = maxi(0, Game.pending_points - int(snapshot["covered_points"]))
	Game.total_points = maxi(Game.total_points, int(snapshot["points"]) + Game.pending_points)
	for pair: String in PAIRS:
		Game.pending_plays[pair] = maxi(0, int(Game.pending_plays.get(pair, 0)) - int(snapshot["covered_plays"].get(pair, 0)))
		Game.class_plays[pair] = maxi(int(Game.class_plays.get(pair, 0)), int(snapshot["plays"].get(pair, 0)) + int(Game.pending_plays[pair]))
	Game.sync_snapshot.clear()
	Game.save_settings()
