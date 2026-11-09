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
	_streams["command"] = _command_cry()
	for kind in ["warning", "burst", "regent"]:
		_streams["mist_" + kind] = _mist_sound(kind)
	for sound in ["warning", "fall", "impact"]:
		_streams["artillery_" + sound] = _artillery_sound(sound)
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


## Stop playback before teardown, so audio-thread playback objects can release their streams.
func stop_all() -> void:
	_music_on = false
	_rain_target = -60.0
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()


func _exit_tree() -> void:
	stop_all()


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


## A short voiced rally, generated once at startup; no extra audio file or streaming cost.
func _command_cry() -> AudioStreamWAV:
	var data := PackedByteArray()
	const RATE := 16000
	data.resize(RATE * 2)
	for i in RATE:
		var t := float(i) / RATE
		var envelope := minf(t * 18.0, 1.0) * pow(1.0 - t, 1.5)
		var phase := TAU * (130.0 * t - 12.0 * t * t)
		var voice := (sin(phase) + 0.45 * sin(phase * 2.0) + 0.25 * sin(phase * 3.0)) * envelope * 0.35
		data.encode_s16(i * 2, int(voice * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


func _artillery_sound(kind: String) -> AudioStreamWAV:
	const RATE := 16000
	var duration := 1.8 if kind == "impact" else (1.1 if kind == "warning" else 0.35)
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 641
	var rumble := 0.0
	for i in count:
		var t := float(i) / RATE
		var x := t / duration
		var value := 0.0
		if kind == "impact":
			rumble = lerpf(rumble, rng.randf_range(-1, 1), 0.18)
			value = (rumble * 1.8 + sin(TAU * (70.0 * t - 12.0 * t * t)) * 0.4) * exp(-t * 3.0) * minf(t * 250, 1.0)
		elif kind == "fall":
			value = sin(TAU * (1500.0 * t - 1000.0 * t * t)) * sin(PI * x) * 0.22
		else:
			value = (sin(TAU * 195 * t) + 0.3 * sin(TAU * 390 * t)) * sin(PI * x) * (0.35 + 0.15 * sin(TAU * 5 * t))
		data.encode_s16(i * 2, int(clampf(value, -0.95, 0.95) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## Original mist cues: a rising glass note, a hollow impact and the Regent's low chord.
func _mist_sound(kind: String) -> AudioStreamWAV:
	const RATE := 16000
	var duration := 1.8 if kind == "regent" else 1.2 if kind == "warning" else 0.65
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8931
	var air := 0.0
	for i in count:
		var t := float(i) / RATE
		var x := t / duration
		var envelope := sin(PI * x) * minf(t * 25.0, 1.0)
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.06)
		var phase := TAU * (420.0 * t + 90.0 * t * t)
		var tone := sin(phase) * 0.2 + sin(phase * 1.502) * 0.11
		if kind == "burst":
			tone = sin(TAU * (115.0 * t - 55.0 * t * t)) * 0.34 + air * 0.55
		elif kind == "regent":
			tone = sin(TAU * 73.4 * t) * 0.22 + sin(TAU * 110.0 * t) * 0.15 + sin(TAU * 155.6 * t) * 0.12 + air * 0.1
		data.encode_s16(i * 2, int(clampf(tone * envelope, -0.8, 0.8) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
