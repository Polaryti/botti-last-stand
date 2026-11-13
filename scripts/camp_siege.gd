class_name CampSiege
extends RefCounted
## The shelling of the Valleys' camp. From STRIKES_FROM, bolts of storm and bursts of mist fall on the
## camp every so often; at WARN_AT everyone is told to get out; at BARRAGE_AT the sky opens over it
## for BARRAGE_TIME, the watchtowers come down, and a Mist Storm settles over the camp for the rest of
## the night. The host (or a phone on its own) decides when and where; every phone sees the circles
## and hurts its own players, as with any other circle of mist.

const STRIKES_FROM := 120.0
const STRIKE_EVERY := 16.0 # seconds between volleys, give or take a few
const VOLLEY := 3 # circles in a volley
const STRIKE_RADIUS := 3.2
const STRIKE_TELL := 1.8
const STRIKE_DAMAGE := 18.0
const WARN_AT := 300.0
const BARRAGE_AT := 315.0
const BARRAGE_TIME := 6.0
const BARRAGE_EVERY := 0.2 # a circle this often during the barrage
const BARRAGE_RADIUS := 4.2
const BARRAGE_TELL := 1.4
const BARRAGE_DAMAGE := 34.0
const RADIUS := 24.0 # how far the camp reaches from its middle
const CAMP_MARK := "Mesenlla Watch" # the map mark at the middle of the camp

var world: World
var centre := Vector3.INF
var _next_volley := STRIKES_FROM
var _barrage_next := BARRAGE_AT
var _told_strikes := false
var _warned := false
var done := false


func _init(w: World) -> void:
	world = w
	for mark: Dictionary in w.map_marks:
		if mark["name"] == CAMP_MARK:
			var at: Vector2 = mark["at"]
			centre = Vector3(at.x, w.ground_at(Vector3(at.x, 0, at.y)), at.y)


## Only in the Valleys of Mesenlla, in a night fought together against the Mists (not a fight between
## players, and not the Sandbox), and only where the map marks a camp.
static func wanted(w: World) -> bool:
	return w.map_id == "mesenlla" and Game.mode != Game.Mode.SANDBOX and Game.mode != Game.Mode.MENU and not Net.pvp()


func tick(elapsed: float) -> void:
	if done or centre == Vector3.INF:
		return
	if elapsed >= WARN_AT and not _warned:
		_warned = true
		world.director.show_banner("The mist gathers over the camp. Get out: the barrage falls in %d seconds!" % int(BARRAGE_AT - WARN_AT), 6.0)
		world.director._sound("storm_call", 2.0)
	if elapsed >= BARRAGE_AT:
		while _barrage_next <= elapsed and _barrage_next < BARRAGE_AT + BARRAGE_TIME:
			_strike(BARRAGE_RADIUS, BARRAGE_TELL, BARRAGE_DAMAGE)
			_barrage_next += BARRAGE_EVERY
		if elapsed >= BARRAGE_AT + BARRAGE_TIME:
			done = true
			if Net.active():
				Net.camp_falls(centre, RADIUS)
			else:
				world.fall_camp(centre, RADIUS)
			world.director.show_banner("The camp has fallen to the mist", 5.0)
		return
	if elapsed >= _next_volley:
		_next_volley = elapsed + STRIKE_EVERY + randf_range(-4.0, 4.0)
		if not _told_strikes:
			_told_strikes = true
			world.director.show_banner("Storm and mist are falling on the camp", 4.0)
		for i in VOLLEY:
			_strike(STRIKE_RADIUS, STRIKE_TELL + i * 0.35, STRIKE_DAMAGE)


## One circle somewhere in the camp, a bolt of storm or a burst of mist.
func _strike(reach: float, tell: float, amount: float) -> void:
	for attempt in 8:
		var a := randf() * TAU
		var d := sqrt(randf()) * (RADIUS - 2.0)
		var at := centre + Vector3(cos(a) * d, 0, sin(a) * d)
		if not world.terrain.is_walkable(at.x, at.z):
			continue
		at.y = world.ground_at(at)
		var style := MistSeal.Style.STORM if randf() < 0.5 else MistSeal.Style.MIST
		if Net.active():
			Net.mist_seal(at, reach, 0.0, tell, amount, -1, style)
		else:
			MistSeal.create(world, at, reach, 0.0, tell, amount, -1, style)
		return
