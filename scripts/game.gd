extends Node
## Global settings and saved progress.

enum Mode { MENU, NIGHT, SANDBOX, FORT }

const MIST_HARRIERS := 3
const SAVE_PATH := "user://settings.cfg"
const NIGHT_LENGTH := 600.0
## Codes are kept as hashes, so they cannot simply be read out of the game files or the repository.
const CODES := {"c734137a1f7468ebdb5cf20deae67c89b15dc5de26ff06b497548a4a62a33706": "commander",
	"7d81dd39a273704c54618b070924a179bb3f9bd7b7b0854aead3dfaaa0f3f385": "monk",
	"87d952a34c98ffc8a98c3f809286c052d94848c42ee7c09828ffd205c468c90a": "plague_doctor",
	"7aec114a9acdb22075cdf4ae79d321a80f7a4b5ad4ff07187cdfc67a9bd71b36": "revenant",
	"28e314800565692691a7af4606286f26fc0f53b2201fe1fb4c8feaa018e3a6ad": "artificer",
	"d9bd0d6b1b8a6dc2c11e699df4d908344b17a609e2064940b19008fa3e1419be": "adept",
	"4a5310c45bc88862d35f592b3cb4f69b664f0b651a56b3503e99539386f7edb3": "bandit",
	"feaeebd2dba326079890fb1cac967ee57f83292db887f82f4a1d8e54161dff7f": "cartographer"}

var mode: int = Mode.MENU
var test_map := "" # a map scene to play instead of the usual one: see MapRoot
var force_weather := -1 # a test can ask for a certain weather
var player_class := "infantry"
var _run_awarded := false
var player_name := ""
var unlocked := {} # classes bought, or opened with a code
var redeemed := {} # the hashes of codes already used on this phone
var doubloons := 0
var board_prizes := {} # week -> doubloons, for leaderboard prizes already paid
var finished_games := 0
var mists_wins := 0
var mesenlla_wins := 0 # matches won in the Valleys of Mesenlla, and in Mist Bastion: three of each earn the Cartographer
var bastion_wins := 0
var changelog_seen := "" # ChangelogPanel.signature() when the notes were last opened
var poison_dealt := 0.0
var owned_items := {} # things bought in the Store, other than classes
var switched_off := {} # bought, and turned off in the Armory
var pet := "wolf"
var night_map := "village"
var fort_map := "fort"
const MAPS := {"village": {"name": "The Village", "desc": "Houses, fields, a castle on a hill, and a river to cross."},
	"mists": {"name": "The Mists", "desc": "Rock islands high above the mist. Don't fall."},
	"mesenlla": {"name": "Valleys of Mesenlla", "desc": "Mountain slopes, rifts and islands in the twilight."}}
## Where to defend: the Fort round the portal to the Mists, or Mist Bastion beyond them.
const FORT_MAPS := {"fort": {"name": "The Fort", "desc": "Four gates round a keep, and the portal inside."},
	"bastion": {"name": "Mist Bastion", "desc": "A Great Portal on a mountaintop, and three lanes up."}}
## The maps All vs All and Teams can be played on: the Mists have no room to run.
const VERSUS_MAPS := ["village", "mesenlla"]
var fresh_unlocks: Array[String] = [] # opened just now, for the end screen to announce
const GAMES_FOR_MAGICIAN := 5
const WINS_FOR_REVENANT := 5
const WINS_FOR_CARTOGRAPHER := 3 # in each of the Valleys of Mesenlla and Mist Bastion
const POISON_FOR_PLAGUE := 3000
var sensitivity := 1.0
var quality := 1 # 0 low, 1 medium, 2 high
var quality_auto := true # the game picks and lowers it by itself (AutoQuality)
var quality_measured := false # whether the first pick on the title screen has been made
var difficulty := 1 # 0 easy, 1 normal, 2 hard
var auto_jump := true
var vibration := true
var steady_brightness := true # hold the screen's brightness still while playing
var brightness := -1.0 # the level to hold, from 0 to 1. Below 0: whatever the phone was at when the game opened
var music_volume := 0.8
var sound_volume := 1.0
var best_time := 0.0
var best_kills := 0
var nights_survived := 0


func is_dev_build() -> bool:
	return OS.has_feature("dev") or ProjectSettings.get_setting("botti/release_channel", "production") == "dev"


func _ready() -> void:
	load_settings()
	apply_quality()
	PhoneScreen.apply_orientation()
	PhoneScreen.apply_brightness()
	if player_name == "":
		player_name = ["Aldric", "Bertrand", "Cedric", "Edith", "Godfrey", "Isolde", "Matilda", "Roland", "Rowena", "Wilfred"][randi() % 10]



## Each code works once on a phone. Returns {"result": "opened", "class": id}, or "used", or "bad".
func redeem(code: String) -> Dictionary:
	return redeem_key(code_key(code))


## What a code is kept as: the same whatever its case, and with or without stray spaces.
static func code_key(code: String) -> String:
	return code.strip_edges().to_upper().sha256_text()


func redeem_key(key: String) -> Dictionary:
	if not CODES.has(key):
		return {"result": "bad"}
	if redeemed.has(key):
		return {"result": "used"}
	var opened: String = CODES[key]
	if ClassDefs.disabled(opened):
		return {"result": "disabled", "class": opened} # kept for when the class returns: not used up
	redeemed[key] = true
	unlocked[opened] = true
	save_settings()
	return {"result": "opened", "class": opened}


func owns_class(id: String) -> bool:
	return not ClassDefs.ALL[id].get("hidden", false) or unlocked.has(id)


## Which map a night is played on: the host decides in a game together.
func current_map() -> String:
	if Net.active():
		if Net.rules == Net.Rules.FORT:
			return Net.fort_map if FORT_MAPS.has(Net.fort_map) else "fort"
		if Net.pvp():
			return Net.night_map if Net.night_map in VERSUS_MAPS else "village"
		return Net.night_map
	if mode == Mode.FORT:
		return fort_map
	return night_map


func owns_item(id: String) -> bool:
	return owned_items.has(id)


## Bought, and not turned off in the Armory.
func item_active(id: String) -> bool:
	return owned_items.has(id) and not switched_off.has(id)


func buy_item(id: String) -> bool:
	var price := int(ShopDefs.ITEMS[id]["price"])
	if owned_items.has(id) or doubloons < price:
		return false
	doubloons -= price
	owned_items[id] = true
	if ShopDefs.ITEMS[id].get("pet", false):
		pet = id
	save_settings()
	return true


func set_item_on(id: String, on: bool) -> void:
	if on:
		switched_off.erase(id)
	else:
		switched_off[id] = true
	save_settings()


func choose_pet(id: String) -> void:
	if id == "wolf" or owned_items.has(id):
		pet = id
		save_settings()


## How to earn a class that cannot be bought.
func earn_text(id: String) -> String:
	match ClassDefs.ALL[id].get("earned", ""):
		"rider":
			return "Kill a Dread Rider to unlock this class."
		"games":
			return "Finish %d games to unlock this class, win or lose. So far: %d." % [GAMES_FOR_MAGICIAN, mini(finished_games, GAMES_FOR_MAGICIAN)]
		"mists":
			return "Survive until dawn %d times in The Mists to unlock this class. So far: %d." % [WINS_FOR_REVENANT, mini(mists_wins, WINS_FOR_REVENANT)]
		"poison":
			return "Deal %d poison damage to unlock this class. So far: %d." % [POISON_FOR_PLAGUE, mini(int(poison_dealt), POISON_FOR_PLAGUE)]
		"beyond":
			return "Win %d matches in the Valleys of Mesenlla and %d in Mist Bastion to unlock this class. So far: %d and %d." % [WINS_FOR_CARTOGRAPHER, WINS_FOR_CARTOGRAPHER, mini(mesenlla_wins, WINS_FOR_CARTOGRAPHER), mini(bastion_wins, WINS_FOR_CARTOGRAPHER)]
	return ""


## Poison you deal, counted over all your games. The Plague Doctor is earned with it.
func note_poison(amount: float) -> void:
	if mode == Mode.SANDBOX or unlocked.has("plague_doctor"):
		return
	poison_dealt += amount
	if poison_dealt >= POISON_FOR_PLAGUE:
		_earn("plague_doctor")


## Surviving until dawn in the Mists, alone or with friends. Five of them earn the Revenant.
func note_mists_win() -> void:
	if current_map() != "mists" or mode == Mode.SANDBOX:
		return
	mists_wins += 1
	if mists_wins >= WINS_FOR_REVENANT and not unlocked.has("revenant"):
		_earn("revenant")
	save_settings()


## A match won beyond the Mists: dawn reached in the Valleys of Mesenlla or at Mist Bastion, or a
## versus match won in the Valleys. Three wins in each earn the Cartographer.
func note_beyond_win() -> void:
	if mode == Mode.SANDBOX:
		return
	match current_map():
		"mesenlla":
			mesenlla_wins += 1
		"bastion":
			bastion_wins += 1
		_:
			return
	if mesenlla_wins >= WINS_FOR_CARTOGRAPHER and bastion_wins >= WINS_FOR_CARTOGRAPHER and not unlocked.has("cartographer"):
		_earn("cartographer")
	save_settings()


func note_rider_killed() -> void:
	if mode != Mode.SANDBOX and not unlocked.has("chivalry"):
		_earn("chivalry")


## A game played to its end, won or lost. Leaving early does not get here, and the Sandbox has no end.
func note_game_finished() -> void:
	if mode == Mode.SANDBOX:
		return
	finished_games += 1
	if finished_games >= GAMES_FOR_MAGICIAN and not unlocked.has("magician"):
		_earn("magician")
	save_settings()


func _earn(id: String) -> void:
	unlocked[id] = true
	fresh_unlocks.append(id)
	save_settings()


func buy_class(id: String) -> bool:
	var price := ClassDefs.price(id)
	if owns_class(id) or price <= 0 or doubloons < price or ClassDefs.disabled(id):
		return false
	doubloons -= price
	unlocked[id] = true
	save_settings()
	return true


func is_night() -> bool:
	return mode == Mode.NIGHT or mode == Mode.FORT


## Botti Doubloons for one match: 1 per minute, 1 per 5 kills, 20 for reaching dawn. Co-op pays 1.5 times.
func match_doubloons(seconds: float, kills: int, reached_dawn: bool, coop: bool) -> int:
	var base := int(seconds / 60.0) + kills / 5 + (20 if reached_dawn else 0)
	return ceili(base * 1.5) if coop else base


## A week's leaderboard prize, paid once: the weeks already paid are kept in the same save as the
## doubloons, so a prize can never be counted twice. Returns whether it was paid now.
func pay_board_prize(week: int, amount: int) -> bool:
	var key := str(week)
	if board_prizes.has(key) or amount <= 0:
		return false
	board_prizes[key] = amount
	doubloons += amount
	save_settings()
	return true


func award_doubloons(seconds: float, kills: int, reached_dawn: bool, coop: bool) -> int:
	if mode == Mode.SANDBOX or _run_awarded:
		return 0
	_run_awarded = true
	var earned := match_doubloons(seconds, kills, reached_dawn, coop)
	doubloons += earned
	save_settings()
	return earned


func enemy_health() -> float:
	return [0.85, 1.0, 1.2][difficulty]


func enemy_damage() -> float:
	return [0.7, 1.0, 1.35][difficulty]


func enemy_speed() -> float:
	return [0.95, 1.0, 1.08][difficulty]


## In a multiplayer game everyone uses the host's numbers of zombies.
func zombie_quality() -> int:
	return Net.forced_quality if Net.forced_quality >= 0 else quality


func max_live_zombies() -> int:
	return [10, 16, 24][zombie_quality()]


## How many of each model to keep ready. Together they match max_live_zombies().
## Beyond the Mists only its own creatures roam: the Children of the Woods and the beasts of the valleys.
const MESENLLA_POOLS := {"woods_child": 12, "bear": 3, "mist_bear": 2, "eagle": 6, "mist_eagle": 3, "shapeshifter": 2,
	"earth_elemental": 2, "mist_elemental": 2, "storm_elemental": 2, "wyvern": 2, "great_revenant_elemental": 1, "war_wyvern": 1}


## Mist Bastion: more on foot to press the three gates, and the War Wyvern in place of the Revenant.
const BASTION_POOLS := {"woods_child": 26, "bear": 6, "mist_bear": 3, "eagle": 6, "mist_eagle": 3, "shapeshifter": 3,
	"earth_elemental": 4, "mist_elemental": 3, "storm_elemental": 3, "wyvern": 2, "war_wyvern": 1}


func zombie_pool_plan() -> Dictionary:
	if mode == Mode.FORT and current_map() == "bastion":
		return BASTION_POOLS.duplicate()
	if mode == Mode.NIGHT and current_map() in SpawnRules.MESENLLA:
		return MESENLLA_POOLS.duplicate()
	var plan := _zombie_pools()
	if mode == Mode.SANDBOX:
		plan["dummy"] = 6
		for model: String in MESENLLA_POOLS:
			plan[model] = mini(int(MESENLLA_POOLS[model]), 4)
	if mode == Mode.SANDBOX or (mode == Mode.NIGHT and current_map() == "mists"):
		plan["harrier"] = MIST_HARRIERS
		plan["lantern_wisp"] = 5 # three roamers and two reserved for the Regent
		plan["mist_weaver"] = 2
		plan["veil_regent"] = 1
		plan["fallen_revenant"] = 2
	return plan


func _zombie_pools() -> Dictionary:
	match zombie_quality():
		0: return {"normal_a": 5, "normal_b": 5, "clever": 3, "magic": 3, "beast": 3, "crow": 3, "gargoyle": 1, "mimic": 1, "scarecrow": 2}
		2: return {"normal_a": 9, "normal_b": 9, "clever": 6, "magic": 5, "beast": 4, "crow": 6, "gargoyle": 2, "mimic": 2, "scarecrow": 3}
	return {"normal_a": 7, "normal_b": 6, "clever": 4, "magic": 4, "beast": 3, "crow": 6, "gargoyle": 2, "mimic": 2, "scarecrow": 3}


func grass_count() -> int:
	return [120, 350, 700][quality]


func apply_quality() -> void:
	Engine.max_fps = 60
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.65, 0.85, 1.0][quality]


## A valid ConfigFile can still contain values of the wrong type. Reject those before assigning
## typed properties; non-finite numbers must not reach rendering, audio or progress calculations.
static func _saved(config: ConfigFile, section: String, key: String, fallback: Variant) -> Variant:
	var value: Variant = config.get_value(section, key, fallback)
	if typeof(fallback) == TYPE_FLOAT and (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
		return float(value) if is_finite(float(value)) else fallback
	return value if typeof(value) == typeof(fallback) else fallback


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	sensitivity = clampf(_saved(c, "input", "sensitivity", 1.0), 0.4, 2.5)
	player_class = _saved(c, "progress", "player_class", "infantry")
	if not ClassDefs.ALL.has(player_class):
		player_class = "infantry"
	auto_jump = _saved(c, "input", "auto_jump", true)
	vibration = _saved(c, "input", "vibration", true)
	steady_brightness = _saved(c, "video", "steady_brightness", true)
	brightness = clampf(_saved(c, "video", "brightness", -1.0), -1.0, 1.0)
	music_volume = clampf(_saved(c, "audio", "music", 0.8), 0.0, 1.0)
	sound_volume = clampf(_saved(c, "audio", "sound", 1.0), 0.0, 1.0)
	# Someone who chose their graphics before Auto existed keeps their choice.
	quality_auto = bool(_saved(c, "video", "auto", not c.has_section_key("video", "quality")))
	quality_measured = bool(_saved(c, "video", "measured", false))
	quality = clampi(_saved(c, "video", "quality", 1), 0, 2)
	difficulty = clampi(_saved(c, "progress", "difficulty", 1), 0, 2)
	player_name = str(_saved(c, "progress", "player_name", ""))
	unlocked = _saved(c, "progress", "unlocked", {})
	redeemed = _saved(c, "progress", "redeemed", {})
	doubloons = maxi(0, _saved(c, "progress", "doubloons", 0))
	board_prizes = _saved(c, "progress", "board_prizes", {})
	finished_games = maxi(0, _saved(c, "progress", "finished_games", 0))
	mists_wins = maxi(0, _saved(c, "progress", "mists_wins", 0))
	mesenlla_wins = maxi(0, _saved(c, "progress", "mesenlla_wins", 0))
	bastion_wins = maxi(0, _saved(c, "progress", "bastion_wins", 0))
	changelog_seen = str(_saved(c, "progress", "changelog_seen", ""))
	poison_dealt = maxf(0.0, _saved(c, "progress", "poison_dealt", 0.0))
	owned_items = _saved(c, "progress", "owned_items", {})
	switched_off = _saved(c, "progress", "switched_off", {})
	pet = _saved(c, "progress", "pet", "wolf")
	night_map = _saved(c, "progress", "night_map", "village")
	if not MAPS.has(night_map):
		night_map = "village"
	fort_map = _saved(c, "progress", "fort_map", "fort")
	if not FORT_MAPS.has(fort_map):
		fort_map = "fort"
	if not ShopDefs.PETS.has(pet) or (pet != "wolf" and not owned_items.has(pet)):
		pet = "wolf"
	if ClassDefs.ALL.get(player_class, {}).get("hidden", false) and not unlocked.has(player_class) or ClassDefs.disabled(player_class):
		player_class = "infantry"
	best_time = maxf(0.0, _saved(c, "progress", "best_time", 0.0))
	best_kills = maxi(0, _saved(c, "progress", "best_kills", 0))
	nights_survived = maxi(0, _saved(c, "progress", "nights_survived", 0))


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("input", "sensitivity", sensitivity)
	c.set_value("progress", "player_class", player_class)
	c.set_value("input", "auto_jump", auto_jump)
	c.set_value("input", "vibration", vibration)
	c.set_value("video", "steady_brightness", steady_brightness)
	c.set_value("video", "brightness", brightness)
	c.set_value("audio", "music", music_volume)
	c.set_value("audio", "sound", sound_volume)
	c.set_value("video", "quality", quality)
	c.set_value("video", "auto", quality_auto)
	c.set_value("video", "measured", quality_measured)
	c.set_value("progress", "difficulty", difficulty)
	c.set_value("progress", "player_name", player_name)
	c.set_value("progress", "unlocked", unlocked)
	c.set_value("progress", "redeemed", redeemed)
	c.set_value("progress", "doubloons", doubloons)
	c.set_value("progress", "board_prizes", board_prizes)
	c.set_value("progress", "finished_games", finished_games)
	c.set_value("progress", "mists_wins", mists_wins)
	c.set_value("progress", "mesenlla_wins", mesenlla_wins)
	c.set_value("progress", "bastion_wins", bastion_wins)
	c.set_value("progress", "changelog_seen", changelog_seen)
	c.set_value("progress", "poison_dealt", poison_dealt)
	c.set_value("progress", "owned_items", owned_items)
	c.set_value("progress", "switched_off", switched_off)
	c.set_value("progress", "pet", pet)
	c.set_value("progress", "night_map", night_map)
	c.set_value("progress", "fort_map", fort_map)
	c.set_value("progress", "best_time", best_time)
	c.set_value("progress", "best_kills", best_kills)
	c.set_value("progress", "nights_survived", nights_survived)
	# Replace only after the complete file is written, so a failed write keeps the previous save.
	var temporary := SAVE_PATH + ".tmp"
	var error := c.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, SAVE_PATH)
	if error != OK:
		push_error("Could not save settings: %s" % error_string(error))


func record_run(seconds: float, kills: int, won: bool) -> bool:
	var is_best := seconds > best_time or (is_equal_approx(seconds, best_time) and kills > best_kills)
	if is_best:
		best_time = seconds
		best_kills = kills
	if won:
		nights_survived += 1
	save_settings()
	return is_best


static func clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%02d:%02d" % [s / 60, s % 60]


func begin_run() -> void:
	_run_awarded = false
