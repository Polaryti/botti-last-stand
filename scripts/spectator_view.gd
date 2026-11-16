class_name SpectatorView
extends Control
## Spectator Mode: a live match watched like a broadcast. A director picks who to follow, going to
## where the fighting is (enemies close, health falling, a boss), and how: high above them, circling
## (AERIAL), over the whole fight (WIDE), close behind them (CHASE), or through their own eyes (EYES).
## The camera glides from one shot to the next; it only cuts going into or out of someone's eyes. Tap
## a player to keep the camera on them; Auto gives it back to the director.
## Over it: LIVE, the match and its clock, the night's banners and boss cards, and a card for each
## player (health, score or lives) along the bottom.

signal leave_requested

enum Shot { AERIAL, WIDE, CHASE, EYES }
const SHOT_NAMES := {Shot.AERIAL: "Aerial", Shot.WIDE: "Wide", Shot.CHASE: "Close", Shot.EYES: "Through their eyes"}
const SHOT_TIME := {Shot.AERIAL: Vector2(7.0, 9.0), Shot.WIDE: Vector2(5.5, 7.0), Shot.CHASE: Vector2(5.0, 7.0), Shot.EYES: Vector2(3.5, 5.0)}
const MIN_SHOT := 2.5 # the director does not leave a shot sooner, unless its player falls
const ACTION_REACH := 12.0 # enemies this close make a player worth watching
const BUSY := 4.0 # this much action, and the director goes in close
const GLIDE := 1.1 # seconds a change of shot takes, gliding
const CARD := Vector2(210, 74)
const LIVE_RED := Color(0.92, 0.24, 0.2)

var world: World
var cam: Camera3D
var lock := 0 # the player kept on screen; 0: the director chooses
var focus := 0 # the player the shot is about now
var shot: int = Shot.AERIAL
var shot_left := 0.0
var _shot_age := 0.0
var _orbit := 0.0
var _cam_at := Vector3.ZERO
var _look_at := Vector3.ZERO
var _hp_seen := {} # peer -> health fraction last seen, for hurt spikes
var _heat := {} # peer -> recent harm taken, fading
var _watched_peer := 0 # whose body is hidden while we look through their eyes
var _cards: HBoxContainer
var _auto: Button
var _font: Font
var _title: Font
var _started := false


func _init(owner_world: World) -> void:
	world = owner_world
	name = "SpectatorView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.bold_font()
	_title = UiTheme.title_font()
	cam = world.player.camera
	world.player.make_spectator()
	_orbit = randf() * TAU
	var leave := Button.new()
	leave.name = "LeaveSpectating"
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(150, UiTheme.BTN_SHORT)
	leave.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	leave.position = Vector2(-170, 20)
	leave.pressed.connect(func() -> void: leave_requested.emit())
	add_child(leave)
	var bottom := HBoxContainer.new()
	bottom.name = "PlayerCards"
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -CARD.y - 20.0
	bottom.offset_bottom = -20.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_auto = Button.new()
	_auto.name = "AutoCamera"
	_auto.text = "Auto"
	_auto.toggle_mode = true
	_auto.custom_minimum_size = Vector2(110, CARD.y)
	_auto.pressed.connect(func() -> void: set_lock(0))
	bottom.add_child(_auto)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_cards)
	_build_cards()
	Net.lobby_changed.connect(_build_cards)
	tree_exiting.connect(func() -> void:
		if Net.lobby_changed.is_connected(_build_cards):
			Net.lobby_changed.disconnect(_build_cards)
		_unwatch())


## One button for each player in the match: tapping it keeps the camera on them.
func _build_cards() -> void:
	if not is_instance_valid(_cards):
		return
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var ids: Array = Net.roster.keys()
	ids.sort()
	for peer: int in ids:
		var b := Button.new()
		b.name = "Card%d" % peer
		b.toggle_mode = true
		b.custom_minimum_size = CARD
		b.set_meta("peer", peer)
		var who := peer
		b.pressed.connect(func() -> void: set_lock(who if lock != who else 0))
		b.draw.connect(_draw_card.bind(b))
		_cards.add_child(b)
	_refresh_buttons()


func set_lock(peer: int) -> void:
	lock = peer
	if peer != 0 and peer != focus:
		_choose(peer, _next_shot(peer, true))
	_refresh_buttons()


func _refresh_buttons() -> void:
	_auto.button_pressed = lock == 0
	for b: Button in _cards.get_children():
		b.button_pressed = int(b.get_meta("peer")) == lock


# --- The director ----------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or cam == null:
		return
	_tick_action(delta)
	_shot_age += delta
	shot_left -= delta
	var target := _avatar(focus)
	var gone := target == null or target.dead
	if not _started:
		_started = true
		_choose(_best(), Shot.AERIAL, true)
	elif gone and lock == 0:
		_choose(_best(), Shot.AERIAL)
	elif shot_left <= 0.0:
		var next := lock if lock != 0 else _best()
		_choose(next, _next_shot(next, next != focus))
	elif lock == 0 and _shot_age >= MIN_SHOT:
		# Something bigger elsewhere: go there.
		var best := _best()
		if best != focus and _action(best) >= BUSY and _action(best) > _action(focus) * 1.5 + 1.0:
			_choose(best, _next_shot(best, true))
	_place_camera(delta)
	queue_redraw()
	for b: Button in _cards.get_children():
		b.queue_redraw()


## Recent harm on each player, from their health falling: it fades over a few seconds.
func _tick_action(delta: float) -> void:
	for peer: int in Net.roster:
		var a := _avatar(peer)
		if a == null:
			continue
		var seen := float(_hp_seen.get(peer, a.hp_fraction))
		if a.hp_fraction < seen - 0.005:
			_heat[peer] = float(_heat.get(peer, 0.0)) + (seen - a.hp_fraction) * 20.0
		_hp_seen[peer] = a.hp_fraction
		_heat[peer] = maxf(0.0, float(_heat.get(peer, 0.0)) - delta * 1.5)


## How much is happening around a player: enemies close (bosses and the Fallen count more), and
## harm they have just taken.
func _action(peer: int) -> float:
	var a := _avatar(peer)
	if a == null or a.dead:
		return -1.0
	var score := float(_heat.get(peer, 0.0))
	for z: Zombie in world.zombies_near(a.global_position, ACTION_REACH, 24):
		if not z.is_alive():
			continue
		var close := 1.0 - z.position.distance_to(a.global_position) / ACTION_REACH
		score += (6.0 if z.is_boss() else 3.0 if z.named_bar() else 1.0) * (0.4 + close)
	return score


## Who the director would follow: the busiest player still up.
func _best() -> int:
	var best := 0
	var best_score := -1.0
	var ids: Array = Net.roster.keys()
	ids.sort()
	for peer: int in ids:
		var score := _action(peer)
		if score > best_score:
			best_score = score
			best = peer
	return best


## The next kind of shot for this player: close when it is busy, high and wide when it is calm, never
## the same twice running, and only a short look through their eyes.
func _next_shot(peer: int, new_focus: bool) -> int:
	var busy := _action(peer) >= BUSY
	var options: Array[int] = []
	options.assign([Shot.CHASE, Shot.EYES, Shot.AERIAL] if busy else [Shot.AERIAL, Shot.WIDE, Shot.CHASE])
	if new_focus and not busy:
		return Shot.AERIAL
	options.erase(shot)
	return options[randi() % options.size()]


func _choose(peer: int, kind: int, cut := false) -> void:
	focus = peer
	shot = kind
	var span: Vector2 = SHOT_TIME[kind]
	shot_left = randf_range(span.x, span.y)
	_shot_age = 0.0
	_unwatch()
	if kind == Shot.EYES:
		var a := _avatar(peer)
		if a:
			a.set_watched(true)
			_watched_peer = peer
	if cut:
		var goal := _goal(0.0)
		_cam_at = goal[0]
		_look_at = goal[1]


func _unwatch() -> void:
	var a := _avatar(_watched_peer)
	if a:
		a.set_watched(false)
	_watched_peer = 0


func _avatar(peer: int) -> Avatar:
	return Net.avatar(peer) if peer != 0 else null


## Where the camera wants to be for the current shot, and what it looks at: [position, look target].
func _goal(delta: float) -> Array:
	var a := _avatar(focus)
	var centre: Vector3 = a.global_position if a else _fallback_centre()
	match shot:
		Shot.AERIAL:
			_orbit += delta * 0.14
			var at := centre + Vector3(sin(_orbit), 0.0, cos(_orbit)) * 14.0 + Vector3.UP * 11.0
			return [_above_ground(at, 4.0), centre + Vector3.UP * 1.0]
		Shot.WIDE:
			var mid := centre
			var n := 1.0
			for z: Zombie in world.zombies_near(centre, ACTION_REACH, 16):
				if z.is_alive():
					mid += z.position
					n += 1.0
			mid /= n
			_orbit += delta * 0.05
			var at := mid + Vector3(sin(_orbit + 1.2), 0.0, cos(_orbit + 1.2)) * 20.0 + Vector3.UP * 16.0
			return [_above_ground(at, 6.0), mid + Vector3.UP * 0.5]
		Shot.CHASE:
			if a == null:
				return [_cam_at, _look_at]
			var view := a.view_transform()
			var forward := -view.basis.z
			forward.y = 0.0
			forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
			var right := forward.cross(Vector3.UP)
			var head := centre + Vector3.UP * 1.6
			var at := centre - forward * 4.2 + Vector3.UP * 2.3 + right * 0.9
			if not world.has_line_of_sight(head, at):
				at = centre - forward * 2.0 + Vector3.UP * 2.6 # tucked in closer when a wall is behind
			return [_above_ground(at, 1.2), centre + forward * 6.0 + Vector3.UP * 1.2]
		Shot.EYES:
			if a == null:
				return [_cam_at, _look_at]
			var eyes := a.view_transform()
			return [eyes.origin, eyes.origin - eyes.basis.z * 10.0]
	return [_cam_at, _look_at]


func _place_camera(delta: float) -> void:
	var goal := _goal(delta)
	# Into and out of someone's eyes it settles fast; between the others it glides.
	var settling := _shot_age < GLIDE
	var rate := 14.0 if shot == Shot.EYES and _shot_age > 0.35 else (3.2 if settling else 6.0)
	var k := 1.0 - exp(-rate * delta)
	_cam_at = _cam_at.lerp(goal[0], k)
	_look_at = _look_at.lerp(goal[1], minf(1.0, k * 1.4))
	var t := Transform3D(Basis.IDENTITY, _cam_at)
	if _cam_at.distance_to(_look_at) > 0.05 and absf((_look_at - _cam_at).normalized().dot(Vector3.UP)) < 0.995:
		t = t.looking_at(_look_at, Vector3.UP)
	cam.global_transform = t
	cam.fov = lerpf(cam.fov, 70.0 if shot == Shot.EYES else 62.0, k)
	# Sound and detail follow the view.
	world.player.global_position = _cam_at


func _above_ground(at: Vector3, clearance: float) -> Vector3:
	var ground := world.ground_at(at)
	if is_finite(ground) and ground > World.FALL_DEATH:
		at.y = maxf(at.y, ground + clearance)
	return at


## Nobody to follow: the middle of things (the fort's portal, or the map's centre).
func _fallback_centre() -> Vector3:
	if world.fort:
		return world.fort.heart_at
	var c := Vector3.ZERO
	c.y = world.ground_at(c)
	return c


# --- What is shown over it -------------------------------------------------

func _draw() -> void:
	var s := size
	var director := world.director
	# LIVE, the match, and its clock.
	var pill := Rect2(Vector2(24, 22), Vector2(78, 34))
	draw_rect(pill, LIVE_RED)
	var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.006) * 0.45
	draw_circle(pill.position + Vector2(16, 17), 6.0, Color(1, 1, 1, pulse))
	draw_string(_font, pill.position + Vector2(28, 25), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	var map_id := Net.fort_map if Net.rules == Net.Rules.FORT else Net.night_map
	var place: String = Places.ALL.get(map_id, {}).get("name", "")
	var what: String = Net.RULE_NAMES[Net.rules] + ("" if place == "" else " on %s" % place)
	_shadowed(what, Vector2(116, 47), 24, UiTheme.BONE)
	_shadowed(Game.clock(director.night_left()), Vector2(26, 92), 30, Color.WHITE)
	# What the camera is doing.
	var a := _avatar(focus)
	if a:
		var line := "%s: %s" % [SHOT_NAMES[shot], a.display] if shot != Shot.EYES else "Through %s's eyes" % a.display
		if lock != 0:
			line += " (kept on)"
		var w := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_shadowed(line, Vector2(s.x * 0.5 - w * 0.5, s.y - CARD.y - 34.0), 22, UiTheme.BONE)
	if director.boss_card_time > 0.0 and Director.BOSS_CARDS.has(director.boss_card):
		Hud.draw_boss_card(self, _title, s, director.boss_card, Director.BOSS_CARD_TIME - director.boss_card_time, director.boss_card_time)
	elif director.banner_time > 0.0:
		Hud.draw_banner(self, _title, director.banner, Vector2(s.x * 0.5, s.y * 0.3), minf(1.0, director.banner_time), s.x)


func _shadowed(text: String, at: Vector2, fs: int, col: Color) -> void:
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.6))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## A player's card: their class colour down the side, name, health, and their score (or lives).
func _draw_card(b: Button) -> void:
	var peer := int(b.get_meta("peer"))
	if not Net.roster.has(peer):
		return
	var info: Dictionary = Net.roster[peer]
	var cls := str(info.get("class", "infantry"))
	var col := ClassDefs.color(cls)
	var r := Rect2(Vector2.ZERO, b.size)
	b.draw_rect(Rect2(r.position, Vector2(8, r.size.y)), col)
	var state := Net.player_state(peer)
	var name_col := UiTheme.ASH if state["down"] else UiTheme.BONE
	b.draw_texture_rect(Icons.glyph(ClassDefs.icon(cls).split("+")[0]), Rect2(Vector2(16, 10), Vector2(28, 28)), false, Color(col, 0.95))
	b.draw_string(_font, Vector2(52, 31), str(info.get("name", "?")).substr(0, 12), HORIZONTAL_ALIGNMENT_LEFT, 150, 22, name_col)
	var bar := Rect2(Vector2(16, 48), Vector2(r.size.x - 32, 10))
	b.draw_rect(bar, Color(0, 0, 0, 0.6))
	b.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(state["hp"]), 0.0, 1.0), bar.size.y)), Color(0.32, 0.78, 0.36) if not state["down"] else UiTheme.ASH)
	var tally := "%d lives" % Net.lives_of(peer) if Net.fog_rules() else "%d" % int(info.get("score", 0))
	if state["down"]:
		tally = "Out" if state["out"] else "Down"
	var tw := _font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	b.draw_string(_font, Vector2(r.size.x - 14 - tw, 31), tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.EMBER if not state["down"] else UiTheme.ASH)
	if peer == focus:
		b.draw_rect(r.grow(-2.0), Color(LIVE_RED, 0.9), false, 3.0)
