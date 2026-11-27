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
	"feaeebd2dba326079890fb1cac967ee57f83292db887f82f4a1d8e54161dff7f": "cartographer",
	"8134ddbc51238f953f50369be83a1f67d15ff1a9bf15af44fc9da01b9b8f9c19": "harpooner",
	"b467740d07272196d7ca893ee099a0f27cf2b91ea0c6f5826b3cc12862cba55c": "tidecaller",
	"198dc481de37e02396478059dbf04e3edbb784f5b86f4e8cbc75989ae71b5c3f": "ferryman",
	"d9bca845c05c9fef2cc0fddcccfece5da2c8fe91b53ba194bc7675aac36886a9": "ascendant",
	"0737b22b9c93c1bbf0a043d938dfb28e119d6c542908f2003d191607b5f03275": "revenant",
	"7d81bbae5f2dc15cbe7ef6021dad08e08235c315458fde23654b3a3fc88e2031": "artificer",
	"851722ee3f2991091bcf1a11d634ff05ea3ea54ed49811ef83a8b7b4d2026312": "chivalry",
	"5bcc253292a148a30155854fa4b4e72aeeb81c3cacbc35fd77c0aeed845eb305": "magician"}
## Codes that pay Doubloons, every time they are entered (also kept only as hashes).
const DOUBLOON_CODES := {"56adbe46b05e15e74db8a9d637126086b142ac23ed9740786457771953e93791": 2000}

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
var lighthouses_lit := 0 # Last Light won: the Isle of Lamps' lighthouse burning again (counted only)
const VAEL_NIGHTS_FOR_FERRYMAN := 3
var vael_nights := 0 # nights survived to the dawn in Port Vael: three earn the Ferryman
var harbourmasters_beaten := 0 # Harbourmasters defeated in matches you played
var mesenlla_wins := 0 # matches won in the Valleys of Mesenlla, and in Mist Bastion: three of each earn the Cartographer
var bastion_wins := 0
var changelog_seen := "" # ChangelogPanel.signature() when the notes were last opened
var poison_dealt := 0.0
var killed_kinds := {} # every kind of enemy you have killed at least once: the Codex tells you about those
var owned_items := {} # things bought in the Store, other than classes
var switched_off := {} # bought, and turned off in the Armory
var pet := "wolf"
var night_map := "village"
var fort_map := "fort"
## A random place instead of a chosen one: rolled afresh each time a night or a siege begins.
var night_random := false
var fort_random := false
const MAPS := {"village": {"name": "The Village", "desc": "Houses, fields, a castle on a hill, and a river to cross."},
	"mists": {"name": "The Mists", "desc": "Rock islands high above the mist. Don't fall."},
	"mesenlla": {"name": "Valleys of Mesenlla", "desc": "Mountain slopes, rifts and islands in the twilight."},
	"vael": {"name": "Port Vael", "desc": "A drowned harbour. Survive fifteen minutes of Mist Tide."},
	"fontanova": {"name": "Fontanova", "desc": "An island of forgotten gods. Survive twelve minutes."}}
## The maps of the Archipelagos of the Forgotten Gods: playing on any of them earns the Ascendant.
const ARCHIPELAGO_MAPS := ["fontanova", "thalys"]
## Where to defend: the Fort round the portal to the Mists, or Mist Bastion beyond them.
const FORT_MAPS := {"fort": {"name": "The Fort", "desc": "Four gates round a keep, and the portal inside."},
	"bastion": {"name": "Mist Bastion", "desc": "A Great Portal on a mountaintop, and three lanes up."},
	"thalys": {"name": "Thalys", "desc": "Hold three harvest roads and defend the Golden Cornucopia from Pelagros."}}
## The maps All vs All and Teams can be played on: the Mists have no room to run.
const VERSUS_MAPS := ["village", "mesenlla", "vael", "fontanova"]


## Somewhere to play out of `choices`, at random, never `last` (the place just played) when there is
## anywhere else.
static func roll_map(choices: Array, last := "") -> String:
	var fresh := choices.filter(func(id: String) -> bool: return id != last)
	if fresh.is_empty():
		fresh = choices
	return str(fresh.pick_random()) if not fresh.is_empty() else last


## A night or a siege about to begin on a random place: where it is, this time.
func roll_random_map() -> void:
	if mode == Mode.FORT and fort_random:
		fort_map = roll_map(FORT_MAPS.keys(), fort_map)
	elif mode == Mode.NIGHT and night_random:
		night_map = roll_map(MAPS.keys(), night_map)
var fresh_unlocks: Array[String] = [] # opened just now, for the end screen to announce
var earned_specs := {} # professions that have to be earned (AbilityData._spec), once they are
var fresh_specs: Array[String] = [] # earned just now, for the end screen to announce
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
var damage_numbers := true # the numbers that rise from what you hit
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
	if DOUBLOON_CODES.has(key):
		var paid := int(DOUBLOON_CODES[key])
		doubloons += paid
		save_settings()
		return {"result": "doubloons", "amount": paid}
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


## Store items that were replaced: whoever had the old one has the new one. Whistle was the Horse
## Archer's upgrade until Wild Hunt took its place.
static func migrate_items(kept: Dictionary) -> void:
	if kept.has("whistle"):
		kept.erase("whistle")
		kept["wild_hunt"] = true


## The Map Upgrades this phone brings to a match: bought, and not switched off.
func map_upgrades_on() -> Array[String]:
	var out: Array[String] = []
	for id: String in ShopDefs.in_section("maps"):
		if item_active(id):
			out.append(id)
	return out


func owns_class(id: String) -> bool:
	return not ClassDefs.ALL[id].get("hidden", false) or unlocked.has(id)


## Which map a night is played on: the host decides in a game together.
func night_length() -> float:
	match current_map():
		"vael": return 900.0
		"fontanova": return 720.0
		"thalys": return 600.0
	return NIGHT_LENGTH


func current_map() -> String:
	if Net.active():
		if Net.rules == Net.Rules.FORT:
			return Net.fort_map if FORT_MAPS.has(Net.fort_map) else "fort"
		if Net.pvp():
			return Net.night_map if Net.night_map in VERSUS_MAPS else "village"
		return "vael" if Net.night_map == "lantern_road" else Net.night_map
	if mode == Mode.FORT:
		return fort_map
	return "vael" if night_map == "lantern_road" else night_map


func owns_item(id: String) -> bool:
	return owned_items.has(id)


## Bought, and not turned off in the Armory.
func item_active(id: String) -> bool:
	return owned_items.has(id) and not switched_off.has(id)


## A Class Upgrade or cosmetic of a class you do not own cannot be bought yet: own the class first.
func item_locked(id: String) -> bool:
	var whose_class := str(ShopDefs.ITEMS[id].get("class", ""))
	return whose_class != "" and not owns_class(whose_class)


func buy_item(id: String) -> bool:
	var price := int(ShopDefs.ITEMS[id]["price"])
	if owned_items.has(id) or doubloons < price or item_locked(id):
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
		"vael_nights":
			return "Survive %d nights in Port Vael (reach the dawn there, alone or with friends) to unlock this class. So far: %d." % [VAEL_NIGHTS_FOR_FERRYMAN, mini(vael_nights, VAEL_NIGHTS_FOR_FERRYMAN)]
		"vael_win":
			return "Win a match in Port Vael to unlock this class: reach the dawn there, alone or with friends, or win a versus match there."
		"harbourmaster":
			return "Defeat the Harbourmaster of Port Vael to unlock this class: be in the match when he falls."
		"archipelago":
			return "Play a match on Fontanova to its end to unlock this class, win or lose."
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


## The Harbourmaster fell in a match this phone's player was in (alone or with friends, whoever struck
## the last blow).
func note_harbourmaster() -> void:
	if mode == Mode.SANDBOX:
		return
	harbourmasters_beaten += 1
	if not ClassDefs.disabled("harpooner") and not unlocked.has("harpooner"):
		_earn("harpooner")
	save_settings()


## Last Light won: the Lantern Barge brought to the Isle of Lamps and the lighthouse lit again.
## Dawn reached in Port Vael. Three nights earn the Ferryman.
func note_vael_night() -> void:
	if mode == Mode.SANDBOX:
		return
	vael_nights += 1
	if vael_nights >= VAEL_NIGHTS_FOR_FERRYMAN and not unlocked.has("ferryman"):
		_earn("ferryman")
	save_settings()


## Last Light won (the Lantern Road is retired; the count is kept).
func note_last_light() -> void:
	if mode == Mode.SANDBOX:
		return
	lighthouses_lit += 1
	save_settings()


## A match won beyond the Mists: dawn reached in the Valleys of Mesenlla, at Mist Bastion or in Port
## Vael, or a versus match won there. Three wins in each of the first two earn the Cartographer; the
## first win in Port Vael earns the Tidecaller.
func note_beyond_win() -> void:
	if mode == Mode.SANDBOX:
		return
	match current_map():
		"vael":
			if not unlocked.has("tidecaller"):
				_earn("tidecaller")
			return
		"fontanova":
			if player_class == "ascendant" and not earned_specs.has("adorer"):
				earn_spec("adorer")
			return
		"mesenlla":
			mesenlla_wins += 1
		"bastion":
			bastion_wins += 1
		_:
			return
	if mesenlla_wins >= WINS_FOR_CARTOGRAPHER and bastion_wins >= WINS_FOR_CARTOGRAPHER and not unlocked.has("cartographer"):
		_earn("cartographer")
	save_settings()


## Your first kill of a kind of enemy opens its Codex entry. Kills in the Sandbox don't count.
func note_killed(kind: String) -> void:
	if mode == Mode.SANDBOX or kind == "" or killed_kinds.has(kind):
		return
	killed_kinds[kind] = true
	save_settings()


func has_killed(kind: String) -> bool:
	return killed_kinds.has(kind)


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
	if current_map() in ARCHIPELAGO_MAPS and not unlocked.has("ascendant"):
		# Any match played to its end on an island of the Archipelagos, won or lost.
		_earn("ascendant")
	save_settings()


## A profession that has to be earned: can this phone take it?
func owns_spec(spec: Dictionary) -> bool:
	return not spec.has("earned") or earned_specs.has(spec["earned"])


func earn_spec(id: String) -> void:
	if earned_specs.has(id):
		return
	earned_specs[id] = true
	fresh_specs.append(id)
	save_settings()


## How to earn a profession that cannot be taken yet.
static func spec_earn_text(spec: Dictionary) -> String:
	match str(spec.get("earned", "")):
		"adorer_pelagros":
			return "Defeat Pelagros in Defend the Fort on Thalys."
		"adorer":
			return "Win a match on Fontanova as the Ascendant to unlock this profession."
	return ""


func _earn(id: String) -> void:
	if ClassDefs.disabled(id): return
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


## Port Vael: the drowned and what the Mist Tide brings in, and the drowned court: two gangs of the
## Press Gang and one more at the Harbourmaster's bell; a Kraken's four arms; and one of each of the rest.
const VAEL_POOLS := {"drowned": 18, "barnacle_brute": 3, "brine_hound": 6, "lantern_jelly": 6, "angler": 3,
	"wreck_gull": 3, "storm_ray": 2, "bell_wraith": 2, "siren": 2, "press_gang": 9, "tide_witch": 2, "harbourmaster": 1, "lighthouse_keeper": 1, "kraken_arm": 4, "hollow_sovereign": 1, "leviathan": 1, "kraken": 1}


## Fontanova: the mutants of the island, its hives and its ambushers.
const FONTA_POOLS := {"mutant_bee": 14, "beehive": 6, "mutant_wasp": 9, "mutant_snail": 4, "wasp_hive_snail": 2, "mutant_spider": 4,
	"battle_ostrich": 4, "ember_moth": 3, "thornback": 3, "cult_worshipper": 9, "cult_priest": 3, "cult_guardian": 5, "hierophant": 1, "polemarch": 1, "alquimelea": 1} # (Ostrich Guardians ride on Guardians' bodies)


## Mist Bastion: more on foot to press the three gates, and the War Wyvern in place of the Revenant.
const BASTION_POOLS := {"woods_child": 26, "bear": 6, "mist_bear": 3, "eagle": 6, "mist_eagle": 3, "shapeshifter": 3,
	"earth_elemental": 4, "mist_elemental": 3, "storm_elemental": 3, "wyvern": 2, "war_wyvern": 1}


const THALYS_POOLS := {"cult_worshipper": 17, "cult_guardian": 10, "cult_priest": 5, "battle_ostrich": 5,
	"mutant_snail": 6, "thornback": 5, "ember_moth": 4,
	"polemarch": 1, "pelagros": 1}


func zombie_pool_plan() -> Dictionary:
	if mode == Mode.FORT and current_map() == "thalys":
		return THALYS_POOLS.duplicate()
	if mode == Mode.FORT and current_map() == "bastion":
		return BASTION_POOLS.duplicate()
	if mode == Mode.NIGHT and current_map() in SpawnRules.MESENLLA:
		return MESENLLA_POOLS.duplicate()
	if mode == Mode.NIGHT and current_map() == "lantern_road":
		# Last Light: no Hollow Sovereign, no Kraken; the Leviathan at the end, and Drowned climbing aboard.
		var road := VAEL_POOLS.duplicate()
		for flyer: String in VaelSkyMind.KINDS:
			road.erase(flyer)
		road.erase("hollow_sovereign")
		road.erase("kraken_arm")
		road.erase("kraken")
		road["drowned"] = 22
		road["leviathan"] = 1
		return road
	if mode == Mode.NIGHT and current_map() in SpawnRules.VAEL:
		return VAEL_POOLS.duplicate()
	if mode == Mode.NIGHT and current_map() in SpawnRules.ARCHIPELAGO:
		return FONTA_POOLS.duplicate()
	var plan := _zombie_pools()
	if mode == Mode.SANDBOX:
		plan["dummy"] = 6
		for model: String in MESENLLA_POOLS:
			plan[model] = mini(int(MESENLLA_POOLS[model]), 4)
		for model: String in VAEL_POOLS:
			plan[model] = mini(int(VAEL_POOLS[model]), 4)
		for model: String in FONTA_POOLS:
			plan[model] = mini(int(FONTA_POOLS[model]), 4)
		plan["leviathan"] = 1
		plan["pelagros"] = 1
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
	damage_numbers = _saved(c, "display", "damage_numbers", true)
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
	earned_specs = _saved(c, "progress", "earned_specs", {})
	redeemed = _saved(c, "progress", "redeemed", {})
	doubloons = maxi(0, _saved(c, "progress", "doubloons", 0))
	board_prizes = _saved(c, "progress", "board_prizes", {})
	finished_games = maxi(0, _saved(c, "progress", "finished_games", 0))
	mists_wins = maxi(0, _saved(c, "progress", "mists_wins", 0))
	lighthouses_lit = maxi(0, _saved(c, "progress", "lighthouses_lit", 0))
	harbourmasters_beaten = maxi(0, _saved(c, "progress", "harbourmasters_beaten", 0))
	vael_nights = maxi(0, _saved(c, "progress", "vael_nights", 0))
	if vael_nights > 0 and not unlocked.has("tidecaller") and not ClassDefs.disabled("tidecaller"):
		# Already won in Port Vael before one win was enough: the Tidecaller is theirs.
		unlocked["tidecaller"] = true
		fresh_unlocks.append("tidecaller")
	mesenlla_wins = maxi(0, _saved(c, "progress", "mesenlla_wins", 0))
	bastion_wins = maxi(0, _saved(c, "progress", "bastion_wins", 0))
	changelog_seen = str(_saved(c, "progress", "changelog_seen", ""))
	poison_dealt = maxf(0.0, _saved(c, "progress", "poison_dealt", 0.0))
	killed_kinds = _saved(c, "progress", "killed_kinds", {})
	owned_items = _saved(c, "progress", "owned_items", {})
	switched_off = _saved(c, "progress", "switched_off", {})
	migrate_items(owned_items)
	migrate_items(switched_off)
	pet = _saved(c, "progress", "pet", "wolf")
	night_map = _saved(c, "progress", "night_map", "village")
	if night_map == "lantern_road": night_map = "vael"
	if not MAPS.has(night_map):
		night_map = "village"
	fort_map = _saved(c, "progress", "fort_map", "fort")
	if not FORT_MAPS.has(fort_map):
		fort_map = "fort"
	night_random = bool(_saved(c, "progress", "night_random", false))
	fort_random = bool(_saved(c, "progress", "fort_random", false))
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
	c.set_value("display", "damage_numbers", damage_numbers)
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
	c.set_value("progress", "earned_specs", earned_specs)
	c.set_value("progress", "redeemed", redeemed)
	c.set_value("progress", "doubloons", doubloons)
	c.set_value("progress", "board_prizes", board_prizes)
	c.set_value("progress", "finished_games", finished_games)
	c.set_value("progress", "mists_wins", mists_wins)
	c.set_value("progress", "lighthouses_lit", lighthouses_lit)
	c.set_value("progress", "harbourmasters_beaten", harbourmasters_beaten)
	c.set_value("progress", "vael_nights", vael_nights)
	c.set_value("progress", "mesenlla_wins", mesenlla_wins)
	c.set_value("progress", "bastion_wins", bastion_wins)
	c.set_value("progress", "changelog_seen", changelog_seen)
	c.set_value("progress", "poison_dealt", poison_dealt)
	c.set_value("progress", "killed_kinds", killed_kinds)
	c.set_value("progress", "owned_items", owned_items)
	c.set_value("progress", "switched_off", switched_off)
	c.set_value("progress", "pet", pet)
	c.set_value("progress", "night_map", night_map)
	c.set_value("progress", "fort_map", fort_map)
	c.set_value("progress", "night_random", night_random)
	c.set_value("progress", "fort_random", fort_random)
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
