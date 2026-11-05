extends Node
## Global settings and saved progress.

enum Mode { MENU, NIGHT, SANDBOX, FORT }

const SAVE_PATH := "user://settings.cfg"
const NIGHT_LENGTH := 600.0
## Codes are kept as hashes, so they cannot simply be read out of the game files or the repository.
const CODES := {"7d81dd39a273704c54618b070924a179bb3f9bd7b7b0854aead3dfaaa0f3f385": "monk",
	"87d952a34c98ffc8a98c3f809286c052d94848c42ee7c09828ffd205c468c90a": "plague_doctor",
	"7aec114a9acdb22075cdf4ae79d321a80f7a4b5ad4ff07187cdfc67a9bd71b36": "revenant",
	"28e314800565692691a7af4606286f26fc0f53b2201fe1fb4c8feaa018e3a6ad": "artificer",
	"d9bd0d6b1b8a6dc2c11e699df4d908344b17a609e2064940b19008fa3e1419be": "adept"}

var mode: int = Mode.MENU
var test_map := "" # a map scene to play instead of the usual one: see MapRoot
var force_weather := -1 # a test can ask for a certain weather
var player_class := "infantry"
var player_name := ""
var unlocked := {} # classes bought, or opened with a code
var redeemed := {} # the hashes of codes already used on this phone
var doubloons := 0
var finished_games := 0
var owned_items := {} # things bought in the Store, other than classes
var switched_off := {} # bought, and turned off in the Armory
var pet := "wolf"
var night_map := "village"
const MAPS := {"village": {"name": "The Village", "desc": "Houses, fields, a castle on a hill, and a river to cross."},
	"mists": {"name": "The Mists", "desc": "Floating islands, joined by gates that open and close. Mind the edge: falling is death."}}
var fresh_unlocks: Array[String] = [] # opened just now, for the end screen to announce
const GAMES_FOR_MAGICIAN := 5
var sensitivity := 1.0
var quality := 1 # 0 low, 1 medium, 2 high
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
	redeemed[key] = true
	unlocked[opened] = true
	save_settings()
	return {"result": "opened", "class": opened}


func owns_class(id: String) -> bool:
	return not ClassDefs.ALL[id].get("hidden", false) or unlocked.has(id)


## Which map a night is played on: the host decides in a game together.
func current_map() -> String:
	if Net.active():
		return "village" if Net.pvp() else Net.night_map
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
	return ""


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
	if owns_class(id) or price <= 0 or doubloons < price:
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


func award_doubloons(seconds: float, kills: int, reached_dawn: bool, coop: bool) -> int:
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
func zombie_pool_plan() -> Dictionary:
	var plan := _zombie_pools()
	if mode == Mode.SANDBOX:
		plan["dummy"] = 6
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


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	sensitivity = c.get_value("input", "sensitivity", 1.0)
	player_class = c.get_value("progress", "player_class", "infantry")
	if not ClassDefs.ALL.has(player_class):
		player_class = "infantry"
	auto_jump = c.get_value("input", "auto_jump", true)
	vibration = c.get_value("input", "vibration", true)
	steady_brightness = c.get_value("video", "steady_brightness", true)
	brightness = c.get_value("video", "brightness", -1.0)
	music_volume = c.get_value("audio", "music", 0.8)
	sound_volume = c.get_value("audio", "sound", 1.0)
	quality = clampi(c.get_value("video", "quality", 1), 0, 2)
	difficulty = clampi(c.get_value("progress", "difficulty", 1), 0, 2)
	player_name = str(c.get_value("progress", "player_name", ""))
	unlocked = c.get_value("progress", "unlocked", {})
	redeemed = c.get_value("progress", "redeemed", {})
	doubloons = c.get_value("progress", "doubloons", 0)
	finished_games = c.get_value("progress", "finished_games", 0)
	owned_items = c.get_value("progress", "owned_items", {})
	switched_off = c.get_value("progress", "switched_off", {})
	pet = c.get_value("progress", "pet", "wolf")
	night_map = c.get_value("progress", "night_map", "village")
	if not MAPS.has(night_map):
		night_map = "village"
	if not ShopDefs.PETS.has(pet) or (pet != "wolf" and not owned_items.has(pet)):
		pet = "wolf"
	if ClassDefs.ALL.get(player_class, {}).get("hidden", false) and not unlocked.has(player_class):
		player_class = "infantry"
	best_time = c.get_value("progress", "best_time", 0.0)
	best_kills = c.get_value("progress", "best_kills", 0)
	nights_survived = c.get_value("progress", "nights_survived", 0)


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
	c.set_value("progress", "difficulty", difficulty)
	c.set_value("progress", "player_name", player_name)
	c.set_value("progress", "unlocked", unlocked)
	c.set_value("progress", "redeemed", redeemed)
	c.set_value("progress", "doubloons", doubloons)
	c.set_value("progress", "finished_games", finished_games)
	c.set_value("progress", "owned_items", owned_items)
	c.set_value("progress", "switched_off", switched_off)
	c.set_value("progress", "pet", pet)
	c.set_value("progress", "night_map", night_map)
	c.set_value("progress", "best_time", best_time)
	c.set_value("progress", "best_kills", best_kills)
	c.set_value("progress", "nights_survived", nights_survived)
	c.save(SAVE_PATH)


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
