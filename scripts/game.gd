extends Node
## Global settings and saved progress.

enum Mode { MENU, NIGHT, ROAM, FORT }

const SAVE_PATH := "user://settings.cfg"
const NIGHT_LENGTH := 600.0
## Codes are kept as hashes, so they cannot simply be read out of the game files.
const CODES := {"7aec114a9acdb22075cdf4ae79d321a80f7a4b5ad4ff07187cdfc67a9bd71b36": "revenant"}

var mode: int = Mode.MENU
var player_class := "infantry"
var player_name := ""
var unlocked := {} # classes opened with a code
var doubloons := 0
var sensitivity := 1.0
var quality := 1 # 0 low, 1 medium, 2 high
var difficulty := 1 # 0 easy, 1 normal, 2 hard
var auto_jump := true
var vibration := true
var music_volume := 0.8
var sound_volume := 1.0
var best_time := 0.0
var best_kills := 0
var nights_survived := 0


func _ready() -> void:
	load_settings()
	apply_quality()
	if player_name == "":
		player_name = ["Aldric", "Bertrand", "Cedric", "Edith", "Godfrey", "Isolde", "Matilda", "Roland", "Rowena", "Wilfred"][randi() % 10]


## Returns what the code opened, or "" if it is not a code.
func redeem(code: String) -> String:
	var opened: String = CODES.get(code.strip_edges().to_upper().sha256_text(), "")
	if opened != "":
		unlocked[opened] = true
		save_settings()
	return opened


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
	music_volume = c.get_value("audio", "music", 0.8)
	sound_volume = c.get_value("audio", "sound", 1.0)
	quality = clampi(c.get_value("video", "quality", 1), 0, 2)
	difficulty = clampi(c.get_value("progress", "difficulty", 1), 0, 2)
	player_name = str(c.get_value("progress", "player_name", ""))
	unlocked = c.get_value("progress", "unlocked", {})
	doubloons = c.get_value("progress", "doubloons", 0)
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
	c.set_value("audio", "music", music_volume)
	c.set_value("audio", "sound", sound_volume)
	c.set_value("video", "quality", quality)
	c.set_value("progress", "difficulty", difficulty)
	c.set_value("progress", "player_name", player_name)
	c.set_value("progress", "unlocked", unlocked)
	c.set_value("progress", "doubloons", doubloons)
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
