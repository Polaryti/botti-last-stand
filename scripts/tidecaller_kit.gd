class_name TidecallerKit
extends RefCounted
## The Tidecaller: one ability button, fed by tide (its mana) that its Trident draws with every blow
## and that rises a little by itself. Call the Tide sends a wave out; each path turns the call into its
## own: a Wavebreaker's Breaking Wave, a Deepsinger's Deep Song, a Fogbinder's Bind the Fog. The wave,
## the song and the fog themselves live in TideWave, DeepSong and FogBank.

# The class
const TRIDENT_TIDE := 5.0 # tide drawn by each Trident blow that lands
# Call the Tide
const WAVE_WIDTH := 3.0
const WAVE_RANGE := 14.0
const WAVE_DAMAGE := 30.0
const WAVE_KNOCK := 6.0
const WAVE_SLOW := 1.5
const TIDE_KILL := 8.0 # Tidal Pull: tide from each kill
const BRINE_SLOW := 1.0 # Brine: a Trident blow slows this long
# Wavebreaker
const BREAK_WIDE := 2.0
const BREAK_HARD := 0.5
const BREAKERS_STUN := 0.8
const SPRAY_HEAL := 12.0
const DROWNING := Vector2(6.0, 4.0) # damage a second, and seconds
const TSUNAMI_EVERY := 3
# Deepsinger
const SONG_TIME := 6.0
const SONG_REACH := 9.0
const SONG_HEAL := 4.0
const SONG_PULL := 2.0 # metres a second toward the singer
const SONG_MARK := 0.2
const LULLABY := 2.0
const CHORUS := 0.15
const SONG_DPS := 8.0
const REQUIEM := 60.0
# Fogbinder
const FOG_AHEAD := 9.0
const FOG_RADIUS := 4.5
const FOG_BLIND := 4.0
const FOG_SLOW := 2.0
const FOG_ROOT := 1.5
const FOG_MARK := 0.2
const FOG_HIDE := 3.0
const FOG_SPEED := 0.2
const FOG_SPEED_TIME := 4.0
const FIELD_TIME := 8.0

const ARTS := {
	"": {"name": "Call the Tide", "cost": 35.0, "cast": 0.3, "cd": 5.0, "icon": "wave", "anim": "Spellcast_Shoot"},
	"wavebreaker": {"name": "Breaking Wave", "cost": 35.0, "cast": 0.3, "cd": 5.0, "icon": "wave", "anim": "Spellcast_Shoot"},
	"deepsinger": {"name": "Deep Song", "cost": 40.0, "cast": 0.4, "cd": 14.0, "icon": "song", "anim": "Spellcast_Raise"},
	"fogbinder": {"name": "Bind the Fog", "cost": 35.0, "cast": 0.35, "cd": 10.0, "icon": "mist", "anim": "Spellcast_Shoot"},
}
const TIDE := Color(0.3, 0.86, 0.82)


static func art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, ARTS[""])


static func cast(p: Player) -> void:
	match p.spec_id:
		"deepsinger": deep_song(p)
		"fogbinder": bind_the_fog(p)
		_: call_the_tide(p)


static func _flat_ahead(p: Player) -> Vector3:
	var ahead := -p.global_basis.z
	return Vector3(ahead.x, 0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.1 else Vector3.FORWARD


# --- Call the Tide, Breaking Wave --------------------------------------------------

static func wave_bits(p: Player, tsunami: bool) -> int:
	var bits := 0
	for flag: String in ["riptide", "breakers", "spray", "drowning"]:
		if p.has_flag(flag):
			bits |= 1 << TideWave.FLAGS.find(flag)
	if tsunami:
		bits |= 1 << TideWave.FLAGS.find("tsunami")
	return bits


static func call_the_tide(p: Player) -> void:
	var breaker := p.spec_id == "wavebreaker"
	var wide := WAVE_WIDTH + (BREAK_WIDE if breaker else 0.0)
	var hard := 1.0 + (BREAK_HARD if breaker else 0.0) + p.m("wave_damage")
	var tsunami := false
	if p.has_flag("tsunami"):
		p.waves_called += 1
		tsunami = p.waves_called % TSUNAMI_EVERY == 0
	if tsunami:
		wide *= 2.0
		hard *= 2.0
	var length := WAVE_RANGE + p.m("wave_range")
	var start := p.global_position + _flat_ahead(p) * 0.8
	start.y = p.world.ground_at(start)
	var dmg := WAVE_DAMAGE * hard * p.damage_multiplier() * p.m("spell_damage")
	var bits := wave_bits(p, tsunami)
	p.world.tide_wave(p.net_id(), start, _flat_ahead(p), wide, length, dmg, bits)
	if Net.active():
		Net.tide_wave(p.net_id(), start, _flat_ahead(p), wide, length, bits)
	p.world.sfx_at("tsunami" if tsunami else "call_tide", start, -1.0)
	if tsunami:
		p.say("Tsunami!")
	p.shake(0.25 if tsunami else 0.1)


# --- Deep Song -------------------------------------------------------------------

static func song_bits(p: Player) -> int:
	var bits := 0
	for i in DeepSong.FLAGS.size():
		if p.has_flag(DeepSong.FLAGS[i]):
			bits |= 1 << i
	return bits


static func deep_song(p: Player) -> void:
	var reach := SONG_REACH + p.m("song_reach")
	var secs := SONG_TIME + p.m("song_time")
	var heal := SONG_HEAL + p.m("song_heal")
	var bits := song_bits(p)
	p.world.deep_song(p.net_id(), reach, secs, heal, bits)
	if Net.active():
		Net.deep_song(p.net_id(), reach, secs, heal, bits)
	p.world.sfx_at("deep_song", p.global_position, -1.0)


# --- Bind the Fog ----------------------------------------------------------------

static func fog_bits(p: Player) -> int:
	var bits := 0
	for i in FogBank.FLAGS.size():
		if p.has_flag(FogBank.FLAGS[i]):
			bits |= 1 << i
	return bits


## Where the fog is bound: what you look at if it is in reach, otherwise as far ahead as that.
static func fog_point(p: Player) -> Vector3:
	var eye := p.eye_position()
	var look := -p.camera.global_basis.z if p.camera else -p.global_basis.z
	# Walk the line of sight out until it meets the ground; looking up or level, go the full reach.
	var reach := FOG_AHEAD + p.m("fog_reach")
	var d := 1.0
	while d <= reach:
		var at := eye + look * d
		if at.y <= p.world.ground_at(at) + 0.2:
			reach = d
			break
		d += 0.5
	var spot := p.leap_landing(p.global_position, _flat_ahead(p), maxf(2.0, Vector2(look.x, look.z).length() * reach))
	spot.y = p.world.ground_at(spot)
	return spot


static func bind_the_fog(p: Player) -> void:
	var at := fog_point(p)
	var radius := FOG_RADIUS + p.m("fog_radius")
	var blind := FOG_BLIND + p.m("fog_time")
	var bits := fog_bits(p)
	p.world.fog_bank(p.net_id(), at, radius, blind, bits)
	if Net.active():
		Net.fog_bank(p.net_id(), at, radius, blind, bits)
	p.world.sfx_at("bind_fog", at, -1.0)
	if p.has_flag("fog_hide"):
		p._act({"do": "invis", "secs": FOG_HIDE}, {})
	if p.has_flag("fog_speed"):
		p._act({"do": "buff", "key": "fog_walker", "stat": "speed", "val": FOG_SPEED, "secs": FOG_SPEED_TIME}, {})


# --- The Trident and kills -----------------------------------------------------------

## A Trident blow that lands draws tide (and with Brine, slows).
static func on_trident_hit(p: Player, z: Zombie) -> void:
	p.mana = minf(p.max_mana(), p.mana + TRIDENT_TIDE)
	if p.has_flag("brine") and z != null:
		z.slow(BRINE_SLOW)


static func on_kill(p: Player) -> void:
	if p.has_flag("tidal_pull"):
		p.mana = minf(p.max_mana(), p.mana + TIDE_KILL)
