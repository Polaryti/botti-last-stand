extends Node
## The leaderboard from the game's side, against real local copies of both boards
## (tools/run_checks.py board starts them): url= is a board of this build's channel,
## other= a board of the other channel. Without them, only the offline checks run.

var checks := 0
var failures := 0
var url := ""
var other := ""


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("url="):
			url = arg.trim_prefix("url=")
		elif arg.begins_with("other="):
			other = arg.trim_prefix("other=")
	_shared_rules()
	_names()
	await _offline_first()
	if url != "":
		await _online()
		await _strict_channels()
		await _screens()
	else:
		print("No local boards given: online checks skipped.")
	Board.url = ""
	# Let freed scenes and sounds go before quitting, so nothing is reported as leaked.
	for i in 4:
		await get_tree().process_frame
	Sfx.stop_all()
	OS.delay_msec(120)
	await get_tree().create_timer(0.2).timeout
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## The board's rule and the game's rule are the same rule.
func _shared_rules() -> void:
	var rules: Dictionary = _json("res://server/leaderboard/test/rules.json")
	for e: Dictionary in rules["points"]:
		var got := Board.match_points(int(e["seconds"]), int(e["kills"]), e["outcome"] == "won", int(e["difficulty"]))
		check(got == int(e["points"]), "points for %s: %d, the board says %d" % [JSON.stringify(e), got, int(e["points"])])
	# Every class and profession the game has, the board accepts, and nothing else.
	var classes: Dictionary = _json("res://server/leaderboard/src/classes.json")
	var ours := {}
	for id: String in ClassDefs.ALL:
		var specs: Array = []
		for s: Dictionary in AbilityData.tree(id)["specs"]:
			specs.append(s["id"])
		ours[id] = specs
	check(JSON.stringify(ours, "", true) == JSON.stringify(classes, "", true), "server/leaderboard/src/classes.json lists exactly the game's classes and professions")
	check(Board.class_label("ranger", "trapper") == "Ranger · Trapper", "a class and profession read as one label (%s)" % Board.class_label("ranger", "trapper"))
	check(Board.class_label("monk", "") == "Monk", "a match before the profession shows the class alone")


func _names() -> void:
	check(Board.clean_name("  Sir   Botti ") == "Sir Botti", "spaces are tidied")
	check(Board.clean_name("ab") == "" and Board.name_problem("ab") != "", "a name needs three letters")
	check(Board.clean_name("x".repeat(17)) == "", "a name has at most sixteen")
	check(Board.clean_name("<b>bold</b>") == "" and Board.name_problem("<b>x</b>").contains("only"), "markup is not a name")
	check(Board.clean_name("Íñigo_2") == "Íñigo_2", "accents and numbers are fine")
	check(Board.clean_name("---") == "", "a name has at least one letter or number")


## No board reachable: the name is kept, the match waits, nothing is lost.
func _offline_first() -> void:
	Board.url = "http://127.0.0.1:9" # nothing listens there
	Board.token = ""
	Board.registered = ""
	Board.name_state = Board.NameState.NONE
	Board.pending.clear()
	check(Board.needs_name(), "a new player is asked for a name")
	check(await Board.choose_name("Offline Olaf") == "", "offline, the name is kept for now")
	check(not Board.needs_name() and Game.player_name == "Offline Olaf" and Board.registered == "", "it is the name in games, waiting to join the board")
	var points := Board.record_match(612.4, 120, true, "night", "village", "ranger", "trapper", 1)
	check(points == 120 + 50 + 50, "the end screen shows the board's points (%d)" % points)
	check(Board.pending.size() == 1, "the match waits")
	Board.sync()
	while Board.syncing:
		await get_tree().process_frame
	check(Board.pending.size() == 1, "and still waits after a failed try")
	# The queue survives the game closing.
	var saved := Board.pending.duplicate(true)
	Board.pending.clear()
	Board._load()
	check(Board.pending == saved and Board.name_state == Board.NameState.CHOSEN, "waiting matches and the name are saved")


func _online() -> void:
	Board.url = url
	Board._cache.clear()
	# The offline player joins the board on the next sync, and its match is sent once.
	Board.sync()
	while Board.syncing:
		await get_tree().process_frame
	check(Board.registered == "Offline Olaf", "joining the board with the name chosen offline (%s)" % Board.last_error)
	check(Board.pending.is_empty(), "the waiting match was sent")
	check(int(Board.standing.get("all", {}).get("points", 0)) == 220, "the board counted it once: %s" % str(Board.standing))
	# Someone else on another phone.
	var mine := Board.token
	Board.token = ""
	Board.registered = ""
	check(await Board.choose_name("offline olaf") == "Someone already has that name.", "names are unique, whatever their capitals")
	check(await Board.choose_name("Second Sam") == "" and Board.registered == "Second Sam", "another name is free")
	Board.record_match(300.0, 30, false, "coop", "mists", "monk", "", 2)
	Board.record_match(300.0, 30, false, "coop", "mists", "monk", "", 2)
	while Board.syncing or not Board.pending.is_empty():
		await get_tree().process_frame
		if not Board.syncing and not Board.pending.is_empty():
			Board.sync()
	var all := await Board.fetch("all", true)
	check(all["ok"], "the all-time board answers (%s)" % all.get("error", ""))
	var names: Array = all.get("entries", []).map(func(e: Dictionary) -> String: return e["name"])
	check(names.slice(0, 2) == ["Offline Olaf", "Second Sam"], "sorted by points: %s" % str(names))
	var sam: Dictionary = all["entries"][1]
	check(int(sam["points"]) == 2 * roundi((30 + 25) * 1.25) and sam["class"] == "monk" and sam["spec"] == "", "points and most played: %s" % str(sam))
	check(int(all["me"].get("rank", 0)) == 2 and all["me"].get("listed", false), "the board says where you are")
	var week := await Board.fetch("week", true)
	check(week["ok"] and week.get("entries", []).size() == 2 and int(week["week_end"]) > int(Time.get_unix_time_from_system()), "this week's board, and when it ends")
	# A player who was offline and lost their name to someone else chooses again.
	Board.token = ""
	Board.registered = ""
	Board.name_state = Board.NameState.CHOSEN
	Game.player_name = "Second Sam"
	Board.sync()
	while Board.syncing:
		await get_tree().process_frame
	check(Board.name_state == Board.NameState.TAKEN and Board.needs_name() and Board.taken_name == "Second Sam", "a name taken while offline asks for another")
	check(await Board.choose_name("Third Tia") == "" and Board.registered == "Third Tia" and not Board.needs_name(), "and the new one joins the board")
	# Renaming is checked too, and back to the first phone.
	check(await Board.choose_name("Offline Olaf") == "Someone already has that name.", "a rename can't take someone's name")
	Board.token = mine
	Board.registered = "Offline Olaf"
	check(await Board.choose_name("Olaf the Bold") == "" and Board.registered == "Olaf the Bold", "renaming keeps the same player")
	all = await Board.fetch("all", true)
	check(all["entries"][0]["name"] == "Olaf the Bold" and int(all["entries"][0]["points"]) == 220, "with the same points")


## A dev build never trusts the production board, nor the other way round.
func _strict_channels() -> void:
	if other == "":
		return
	Board.url = other
	Board._cache.clear()
	var answer := await Board.fetch("all", true)
	check(not answer["ok"] and answer["error"] == "wrong_board", "the other channel's board is refused")
	var before := Board.pending.size()
	Board.record_match(100.0, 5, false, "night", "village", "infantry", "", 1)
	Board.sync()
	while Board.syncing:
		await get_tree().process_frame
	check(Board.pending.size() == before + 1, "and no match is sent to it")
	Board.pending.clear()
	Board._save()
	Board.url = url


## The screens: the prompt, the board and the end-of-match line.
func _screens() -> void:
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await get_tree().create_timer(0.5).timeout
	var texts := func() -> Array:
		return m.ui_layer.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(texts.call().has("Olaf the Bold"), "the menu shows your name: %s" % str(texts.call()))
	check(m.ui_layer.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "Leaderboard"), "and the leaderboard")
	m.show_name_prompt(false)
	await get_tree().process_frame
	var edit: LineEdit = m.ui_layer.find_children("*", "LineEdit", true, false)[0]
	edit.text = "Third Tia"
	edit.text_submitted.emit(edit.text)
	await get_tree().create_timer(1.0).timeout
	var said: Array = m.ui_layer.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(said.has("Someone already has that name."), "the prompt says when a name is taken")
	m.show_leaderboard("all")
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		said = m.ui_layer.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		if said.has("Olaf the Bold"):
			break
	check(said.has("Olaf the Bold") and said.has("220") and said.has("Ranger · Trapper"), "the leaderboard lists players, points and most played: %s" % str(said))
	check(said.any(func(t: String) -> bool: return t.begins_with("You: #1 with 220 points")), "and where you are")
	m._clear_ui()
	m._clear_world()
	m.queue_free()
	await get_tree().process_frame
