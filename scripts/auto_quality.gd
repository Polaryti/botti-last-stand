class_name AutoQuality
extends Node
## Keeps the game smooth on whatever phone it is on. With Graphics on Auto, the first time the game
## runs it watches the title screen for a few seconds and picks Low, Medium or High from how fast
## the phone draws it; and during a match, if the phone stays well short of smooth, it steps the
## graphics down a level and says so. It never steps up mid-match, so it cannot flicker between two.

const SETTLE := 2.5 # seconds ignored after a screen appears, while things load
const SAMPLE := 3.0 # seconds measured on the title screen
const HIGH_FROM := 55.0 # frames a second at Medium on the title screen to earn High
const LOW_BELOW := 36.0 # and below this, Low
const WINDOW := 5.0 # seconds in each look during a match
const TOO_SLOW := 38.0 # a window averaging below this is slow
const STRIKES := 2 # this many slow windows in a row step the graphics down

signal changed(quality: int, in_match: bool)

## Tests set this to try it off a phone; otherwise it only ever acts on one.
static var force := false
var main: Node
var _t := 0.0
var _frames := 0
var _slow := 0
var _was_playing := false


func _init(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS


static func enabled() -> bool:
	return Game.quality_auto and (force or OS.has_feature("mobile"))


func _process(_delta: float) -> void:
	if not enabled():
		return
	var playing: bool = main.world != null and is_instance_valid(main.world) and Game.mode != Game.Mode.MENU
	if playing != _was_playing or get_tree().paused:
		_was_playing = playing
		_restart()
		return
	# Real time, whatever the game's own clock is doing.
	_t += _delta / maxf(0.01, Engine.time_scale)
	if _t < SETTLE:
		return
	_frames += 1
	if not playing:
		if not Game.quality_measured and _t >= SETTLE + SAMPLE:
			take(_frames / (_t - SETTLE), false)
		return
	if _t >= SETTLE + WINDOW:
		take(_frames / (_t - SETTLE), true)


## Acts on a measured rate of frames a second.
func take(fps: float, in_match: bool) -> void:
	_t = SETTLE
	_frames = 0
	if not in_match:
		Game.quality_measured = true
		var pick := 2 if fps >= HIGH_FROM else (0 if fps < LOW_BELOW else 1)
		if Game.quality != 1:
			pick = Game.quality # only a phone still on the Medium it started with is judged
		var was := Game.quality
		Game.quality = pick
		Game.apply_quality()
		Game.save_settings()
		if pick != was:
			changed.emit(pick, false)
		return
	_slow = _slow + 1 if fps < TOO_SLOW else 0
	if _slow >= STRIKES and Game.quality > 0:
		_slow = 0
		Game.quality -= 1
		Game.apply_quality()
		Game.save_settings()
		changed.emit(Game.quality, true)


func _restart() -> void:
	_t = 0.0
	_frames = 0
	_slow = 0
