extends Node
## Small fixed pool of non-positional players. Distance is faked with volume,
## which is much cheaper on phones than many 3D audio sources.

const NAMES := ["bell", "blast", "block", "bow", "burn", "chime", "creak", "crossbow", "crow", "eat", "empty",
	"familiar", "fireball", "gallop", "gargoyle", "hammer", "howl", "banshee", "jump_a", "land", "leaper", "level",
	"mimic", "pickup", "potion", "rooster", "spell", "thunder", "thunder_far", "thunk", "trap", "ui_choose", "ui_click",
	"weapon_change", "wolf", "wraith"]
const VARIANTS := {"groan": ["groan_a", "groan_b", "groan_c", "groan_d"], "attack": ["attack_a", "attack_b"],
	"zombie_hurt": ["zombie_hurt_a", "zombie_hurt_b"], "zombie_death": ["zombie_death_a", "zombie_death_b"],
	"hurt": ["hurt_a", "hurt_b"], "swing": ["swing_a", "swing_b", "swing_c"], "hit": ["hit_a", "hit_b"],
	"clang": ["clang", "clang_b"], "step": ["step_a", "step_b", "step_c"]}
const POOL := 14
const MUSIC_BUS := "Music"
const SOUND_BUS := "Sounds"

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _ambient: AudioStreamPlayer
var _music: Array[AudioStreamPlayer] = []
var _targets := [-2.0, -60.0, -60.0] # calm, hunted, dawn
var _music_on := false
var _rain: AudioStreamPlayer
var _rain_target := -60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buses()
	for n: String in NAMES:
		_streams[n] = load("res://assets/sounds/%s.ogg" % n)
	for group: String in VARIANTS:
		for n: String in VARIANTS[group]:
			_streams[n] = load("res://assets/sounds/%s.ogg" % n)
	_music = [_stem("night"), _stem("hunted"), _stem("dawn")]
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = SOUND_BUS
		add_child(p)
		_players.append(p)
	var loop: AudioStreamOggVorbis = load("res://assets/sounds/night.ogg")
	loop.loop = true
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = loop
	_ambient.volume_db = -14.0
	_ambient.bus = SOUND_BUS
	add_child(_ambient)


## Separate volumes for music and sounds, and a limiter so a loud moment cannot clip the speaker.
func _build_buses() -> void:
	for bus: String in [MUSIC_BUS, SOUND_BUS]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)
	apply_volumes()


func apply_volumes() -> void:
	_set_bus(MUSIC_BUS, Game.music_volume)
	_set_bus(SOUND_BUS, Game.sound_volume)


func _set_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, linear <= 0.01)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.01)))


func _stem(stem: String) -> AudioStreamPlayer:
	var loop: AudioStreamOggVorbis = load("res://assets/music/%s.ogg" % stem)
	loop.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = loop
	p.volume_db = -60.0
	p.bus = MUSIC_BUS
	add_child(p)
	return p


func music_is_playing() -> bool:
	return _music_on and _music[0].playing and _music[1].playing and _music[2].playing


func ambient(on: bool) -> void:
	if on and not _ambient.playing:
		_ambient.play()
	elif not on:
		_ambient.stop()
	if on and not _music_on:
		_music_on = true
		for p in _music:
			p.play()


## A steady loop while it rains. The volume changes smoothly, so walking indoors sounds right.
func rain(on: bool, volume_db: float) -> void:
	if on and _rain == null:
		var loop: AudioStreamOggVorbis = load("res://assets/sounds/rain.ogg")
		loop.loop = true
		_rain = AudioStreamPlayer.new()
		_rain.stream = loop
		_rain.volume_db = -40.0
		_rain.bus = SOUND_BUS
		add_child(_rain)
	if _rain == null:
		return
	_rain_target = volume_db if on else -60.0
	if on and not _rain.playing:
		_rain.play()


## Hunted fades in the drums, dawn fades in the warm stem. The world calls this a few times a second.
func set_mood(hunted: float, dawn: float) -> void:
	var calm := 1.0 - dawn
	_targets[0] = linear_to_db(maxf(0.001, 0.82 * calm * (1.0 - hunted * 0.85)))
	_targets[1] = linear_to_db(maxf(0.001, 0.8 * hunted * calm))
	_targets[2] = linear_to_db(maxf(0.001, 0.82 * dawn))
	_ambient.volume_db = lerpf(-16.0, -30.0, dawn)


func _process(delta: float) -> void:
	for i in _music.size():
		_music[i].volume_db = move_toward(_music[i].volume_db, _targets[i], delta * 14.0)
	if _rain and _rain.playing:
		_rain.volume_db = move_toward(_rain.volume_db, _rain_target, delta * 24.0)
		if _rain.volume_db <= -59.0 and _rain_target <= -59.0:
			_rain.stop()


## min_gap keeps a horde from machine-gunning the same sample.
func play(sound: String, volume_db := 0.0, pitch := 1.0, min_gap := 0.03) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -10.0)) < min_gap:
		return
	_last[sound] = now
	var name := sound
	if VARIANTS.has(sound):
		var list: Array = VARIANTS[sound]
		name = list[randi() % list.size()]
	# Prefer a silent voice, so a long sound like the bell is not cut off by footsteps.
	var p := _players[_next]
	for i in POOL:
		var candidate := _players[(_next + i) % POOL]
		if not candidate.playing:
			p = candidate
			_next = (_next + i) % POOL
			break
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


func play_at(sound: String, pos: Vector3, listener: Vector3, volume_db := 0.0, min_gap := 0.08) -> void:
	var d := pos.distance_to(listener)
	if d > 38.0:
		return
	play(sound, volume_db - d * 0.55, 1.0, min_gap)
