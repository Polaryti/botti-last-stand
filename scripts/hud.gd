class_name Hud
extends Control
## Touch HUD. It reads raw multi-touch itself, because normal UI buttons only follow
## one finger, and a shooter needs to move, aim and attack at the same time.

signal pause_requested
signal tree_requested
signal sandbox_requested
signal command_map_requested

const UNLINKED := Color(1.0, 0.5, 0.34) # the beacon button, when a beacon planted now would link to nothing
const JOY_R := 88.0
const KI_COLOUR := Color(1.0, 0.78, 0.28)
const COL_BG := Color(0.05, 0.05, 0.07, 0.72)
const COL_LINE := Color(1, 1, 1, 0.7)
const COL_FIRE := Color(0.62, 0.13, 0.09, 0.8)
const COL_ACCENT := Color(1.0, 0.78, 0.3)
# The HUD's own text scale: a few sizes, each for one kind of thing.
const HUD_CLOCK := 32 # the time left
const HUD_TEXT := 20 # names, chips, the weapon you hold
const HUD_SMALL := 17 # numbers on bars and icons, labels under buttons
const HUD_TOAST := 28 # a word for what just happened, in the middle
const CHIP_H := 30.0
const BACKING := Color(0.04, 0.05, 0.08, 0.55) # behind anything that sits on the world
## Dropping a weapon takes a held press, so a thumb passing over the button never throws one away.
const DROP_HOLD := 0.5

var player: Player
var director: Director
var font: Font
var title: Font
var _glass: Texture2D
var _ring: Texture2D
var menu_open := false

var _buttons := {}
var _fingers := {} # finger index -> role
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_finger := -1
var _pad := 24.0
var _crosshair: Texture2D
var _status_bottom := 110.0
var _centre_y := 64.0 # how far down the middle column (clock, chips, stance, Fort) has got this frame
var _backing := UiTheme.flat(BACKING, Color.TRANSPARENT, 12, 0.0)
var _track := UiTheme.flat(Color(UiTheme.NIGHT, 0.72), Color.TRANSPARENT, 5, 0.0)
var _fill := UiTheme.flat(Color.WHITE, Color.TRANSPARENT, 5, 0.0)
var _capsule := UiTheme.flat(Color(UiTheme.NIGHT, 0.6), Color.TRANSPARENT, 10, 0.0)
var _capsule_soft := UiTheme.flat(BACKING, Color.TRANSPARENT, 15, 0.0)
var _was_dead := false
var _drop_held := 0.0 # how long the drop button has been held, or -1 once it has dropped


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	font = UiTheme.bold_font()
	title = UiTheme.title_font()
	_crosshair = load("res://assets/sprites/crosshair.png")
	_glass = load("res://assets/ui/glass.png")
	_ring = load("res://assets/ui/ring.png")
	resized.connect(_layout)
	_layout()


func _safe_margin() -> float:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0:
		return 24.0
	var px := maxi(safe.position.x, win.x - safe.end.x)
	return clampf(float(px) * size.x / float(win.x), 0.0, 90.0) + 22.0


func _layout() -> void:
	var s := size
	_pad = _safe_margin()
	var right := s.x - _pad
	var bottom := s.y - 24.0
	_buttons = {
		"fire": {"pos": Vector2(right - 96, bottom - 118), "r": 96.0},
		"jump": {"pos": Vector2(right - 62, bottom - 276), "r": 52.0},
		"bayonet": {"pos": Vector2(right - 248, bottom - 92), "r": 52.0},
		"switch": {"pos": Vector2(right - 248, bottom - 92), "r": 52.0},
		"zoom": {"pos": Vector2(right - 208, bottom - 260), "r": 50.0},
		# Up with the menu buttons, away from the thumb's fighting buttons.
		"drop": {"pos": Vector2(right - (316 if Game.mode == Game.Mode.SANDBOX else 228), 46), "r": 38.0},
		"take": {"pos": Vector2(s.x * 0.5, s.y * 0.68), "r": 62.0},
		"pause": {"pos": Vector2(right - 28, 46), "r": 32.0},
		"tree": {"pos": Vector2(right - 124, 52), "r": 46.0},
		"sandbox": {"pos": Vector2(right - 228, 46), "r": 38.0},
		"horse": {"pos": Vector2(right - 372, bottom - 130), "r": 58.0},
		"burst": {"pos": Vector2(right - 372, bottom - 110), "r": 60.0},
		"art": {"pos": Vector2(right - 352, bottom - 260), "r": 56.0},
		# A path's own ability beside the class's (the Bandit's Steal, Nightfall or Dagger Fan).
		"path_art": {"pos": Vector2(right - 470, bottom - 190), "r": 52.0},
	}


func _button_visible(id: String) -> bool:
	if player == null:
		return false
	match id:
		"take":
			return player.nearby_weapon != null
		"zoom":
			return player.weapon_def().has("zoom_fov")
		"bayonet":
			return player.weapon_id() == "musket"
		"switch":
			return player.slots[0] != null and player.slots[1] != null
		"drop":
			return player.can_drop_weapon()
		"horse":
			return player.horse_ready() or player.is_riding() or player.ride_behind != 0 or player.can_board()
		"burst":
			return player.has_burst()
		"art":
			return player.has_art()
		"path_art":
			return player.has_path_art()
		"sandbox":
			return Game.mode == Game.Mode.SANDBOX
	return true


func _input(event: InputEvent) -> void:
	# A finger lifted always counts, whatever happened while it was down.
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_touch_up((event as InputEventScreenTouch).index)
		return
	if player == null or get_tree().paused or menu_open or not visible:
		return
	if player.dead:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			var at: Vector2 = (event as InputEventScreenTouch).position
			if at.distance_to(_buttons["pause"]["pos"]) < float(_buttons["pause"]["r"]) * 1.12:
				pause_requested.emit()
			elif at.distance_to(_buttons["tree"]["pos"]) < float(_buttons["tree"]["r"]) * 1.12:
				tree_requested.emit()
			elif Net.in_game:
				Net.watch_next()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		_touch_down(t.index, t.position)
	elif event is InputEventScreenDrag:
		_touch_drag(event as InputEventScreenDrag)


func _touch_down(index: int, at: Vector2) -> void:
	var best := ""
	var best_d := INF
	for id: String in _buttons:
		if not _button_visible(id):
			continue
		var b: Dictionary = _buttons[id]
		var d := at.distance_to(b["pos"])
		if d < float(b["r"]) * 1.12 and d < best_d:
			best = id
			best_d = d
	if best != "":
		_fingers[index] = best
		match best:
			"fire": player.input_fire = true
			"jump": player.input_jump = true
			"switch": player.switch_weapon()
			"drop": _drop_held = 0.0
			"bayonet": player.use_bayonet()
			"zoom": player.toggle_zoom()
			"take": player.take_nearby_weapon()
			"pause": pause_requested.emit()
			"tree": tree_requested.emit()
			"sandbox": sandbox_requested.emit()
			"burst": player.use_burst()
			"path_art": player.use_path_art()
			"art":
				if player.art_is_held():
					player.art_aim()
				else:
					player.use_art()
			"horse":
				if player.ride_behind != 0:
					player.leave_horse()
				elif player.is_riding():
					player.dismount()
				elif player.horse_ready():
					player.mount()
				else:
					player.board()
		return
	if at.x < size.x * 0.42 and _joy_finger < 0:
		_joy_finger = index
		_joy_origin = at
		_joy_pos = at
		_fingers[index] = "joy"
		player.input_move = Vector2.ZERO
	else:
		_fingers[index] = "look"


func _touch_up(index: int) -> void:
	var role: String = _fingers.get(index, "")
	_fingers.erase(index)
	if role == "joy":
		_joy_finger = -1
		player.input_move = Vector2.ZERO
	elif role == "fire":
		player.input_fire = false
	elif role == "art":
		player.art_release()


func _touch_drag(e: InputEventScreenDrag) -> void:
	var role: String = _fingers.get(e.index, "")
	match role:
		"joy":
			var off := e.position - _joy_origin
			if off.length() > JOY_R:
				# The base follows the thumb, so running never hits an edge.
				_joy_origin = e.position - off.limit_length(JOY_R)
				off = e.position - _joy_origin
			_joy_pos = e.position
			player.input_move = (off / JOY_R).limit_length(1.0)
		"look", "fire", "art":
			# Aiming also works while a thumb holds ATTACK.
			player.apply_look(e.relative.x, e.relative.y)


func release_all() -> void:
	_fingers.clear()
	_joy_finger = -1
	if player:
		player.input_move = Vector2.ZERO
		player.input_fire = false


func _process(delta: float) -> void:
	if player and player.dead != _was_dead:
		_was_dead = player.dead
		release_all()
	if player and _fingers.values().has("drop") and _drop_held >= 0.0:
		_drop_held += delta
		if _drop_held >= DROP_HOLD:
			_drop_held = -1.0
			if player.can_drop_weapon():
				player.drop_current_weapon()
	queue_redraw()


func _banner_text(t: String, centre: Vector2, a: float) -> void:
	var fs := 46
	var full_width := title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if full_width > size.x - 100.0:
		fs = maxi(18, int(fs * (size.x - 100.0) / full_width))
	var w := title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := centre - Vector2(w * 0.5, -fs * 0.32)
	draw_string_outline(title, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 7, Color(0, 0, 0, 0.6 * a))
	draw_string(title, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiTheme.BONE, a))


func _text(t: String, at: Vector2, fs: int, col: Color) -> void:
	draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 4, Color(0, 0, 0, 0.55 * col.a))
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


func _centered(t: String, centre: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(t, centre - Vector2(w * 0.5, -fs * 0.34), fs, col)


func _draw() -> void:
	if player == null:
		return
	var s := size
	var centre := s * 0.5
	if player.fog_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.72, 0.95, 0.97, player.fog_flash * 0.42))
	if player.hurt_flash > 0.0:
		var burn := player.burn_time > 0.0
		var c := Color(0.95, 0.42, 0.05) if burn else Color(0.75, 0.05, 0.03)
		draw_rect(Rect2(Vector2.ZERO, s), Color(c, player.hurt_flash * 0.32))
	if player.heal_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.9, 0.4, player.heal_flash * 0.1))
	if player.level_flash > 0.0:
		_draw_level_flash(s)
	# Inside an enemy's Nightfall: the edges of sight close in.
	if player.night_blind_left > 0.0:
		var dark := Color(0.02, 0.01, 0.05, 0.62)
		draw_rect(Rect2(Vector2.ZERO, s), Color(dark, 0.35))
		var r := minf(s.x, s.y) * 0.32
		for i in 6:
			var band := r + i * minf(s.x, s.y) * 0.08
			draw_arc(centre, band + 60.0, 0.0, TAU, 64, Color(dark, 0.16 + i * 0.06), 120.0)
	var cross := 40.0
	draw_texture_rect(_crosshair, Rect2(centre - Vector2.ONE * cross * 0.5, Vector2.ONE * cross), false, Color(1, 1, 1, 0.85))
	if player.hit_marker > 0.0:
		var col := Color(1, 0.3, 0.2, player.hit_marker) if player.hit_head else Color(1, 1, 1, player.hit_marker)
		for pair: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(centre + pair * 10.0, centre + pair * 22.0, col, 3.0)
	if player.has_power("sensor"):
		_draw_sensor(centre)
	_draw_marks()
	_draw_item_name()
	_draw_enemy_bars()
	if player.hurt_dir_time > 0.0:
		_draw_hurt_direction(centre)
	_draw_dive_warning(centre)
	if player.is_unseen():
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.2, 0.12, 0.5, 0.16))
	_draw_status(s)
	_draw_chips(s)
	if player.class_id == "adept":
		_draw_stance(s)
	_draw_fog(s, centre)
	if player.frozen_left > 0.0:
		if player.is_iced:
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0.85, 1.0, 0.24))
		_centered("Frozen" if player.is_iced else "Stunned", Vector2(centre.x, s.y * 0.62), HUD_TOAST + 6, UiTheme.MIST)
	# Down the left side, each below the last, so nothing lands on anything else.
	var left_y := _status_bottom
	if Net.in_game:
		left_y = _draw_together(s, centre)
	if player.world.fort:
		_draw_fort(s, centre)
	_draw_powers(left_y)
	_draw_weapon(s)
	_draw_controls()
	if player.toast_time > 0.0:
		_centered(player.toast, Vector2(centre.x, s.y * 0.38), HUD_TOAST, Color(UiTheme.MOSS if "DODGE" in player.toast else (UiTheme.EMBER if "Backstab" in player.toast or "Riposte" in player.toast else UiTheme.BONE), minf(1.0, player.toast_time * 2.0)))
	if director and director.banner_time > 0.0:
		_banner_text(director.banner, Vector2(centre.x, maxf(s.y * 0.32, _centre_y + 40.0)), minf(1.0, director.banner_time))


func _bar(r: Rect2, f: float, col: Color) -> void:
	draw_style_box(_track, r)
	var part := clampf(f, 0.0, 1.0)
	if part > 0.0:
		_fill.bg_color = col
		draw_style_box(_fill, Rect2(r.position, Vector2(maxf(r.size.x * part, minf(r.size.y, r.size.x)), r.size.y)))


## The portal, the gates and the wood you carry, on a small panel under the clock, with the dial that
## says which way each gate lies beside them.
func _draw_fort(s: Vector2, centre: Vector2) -> void:
	var fort := player.world.fort
	const BAR_W := 170.0
	const DIAL := 34.0 # the dial's radius, ring included
	const FS := HUD_SMALL - 2
	var w := 10.0 + BAR_W + 12.0 + DIAL * 2.0 + 8.0
	var h := 78.0
	var top := _centre_y + 4.0
	var x0 := centre.x - w * 0.5
	draw_style_box(_backing, Rect2(x0, top, w, h))
	var x := x0 + 10.0
	var heart := fort.heart_hp / Fort.HEART_HP
	_text("Portal", Vector2(x, top + 17), FS, UiTheme.BONE)
	var pct := "%d%%" % ceili(heart * 100.0)
	_text(pct, Vector2(x + BAR_W - font.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x, top + 17), FS, UiTheme.BONE if heart > 0.35 else UiTheme.BLOOD.lightened(0.3))
	_bar(Rect2(x, top + 22, BAR_W, 8), heart, Color(0.9, 0.3, 0.24))
	var gate_count := maxi(1, fort.gates.size())
	var gate_w := (BAR_W - 5.0 * (gate_count - 1)) / gate_count
	for i in fort.gates.size():
		var g: Dictionary = fort.gates[i]
		var r := Rect2(x + i * (gate_w + 5.0), top + 36, gate_w, 6)
		_bar(r, float(g["hp"]) / Fort.GATE_HP, Color(0.72, 0.5, 0.26) if g["closed"] else Color(0.8, 0.2, 0.15))
		_centered(str(g["short"]), r.get_center() + Vector2(0, 13), FS, UiTheme.BONE if g["closed"] else UiTheme.BLOOD.lightened(0.3))
	const WOOD_COL := Color(0.92, 0.72, 0.42)
	draw_texture_rect(Icons.glyph("log"), Rect2(x, top + 58, 15, 15), false, WOOD_COL)
	_text("Wood %d of %d" % [player.wood, Fort.WOOD_MAX], Vector2(x + 20, top + 71), FS, WOOD_COL)
	_draw_gate_compass(fort, Vector2(x0 + w - 8.0 - DIAL, top + h * 0.5), DIAL - 10.0)
	_centre_y = top + h


## Which way each gate lies from where you stand. The top of the dial is the way you are looking.
func _draw_gate_compass(fort: Fort, at: Vector2, radius := 34.0) -> void:
	draw_circle(at, radius + 10.0, Color(0.05, 0.06, 0.09, 0.62))
	draw_arc(at, radius + 10.0, 0.0, TAU, 32, Color(0.92, 0.72, 0.42, 0.7), 2.0, true)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(-4, 4), at + Vector2(4, 4)]), UiTheme.BONE)
	for g: Dictionary in fort.gates:
		var to: Vector3 = (g["at"] as Vector3) - player.global_position
		var local := Vector3(to.x, 0.0, to.z).rotated(Vector3.UP, -player.rotation.y)
		var dir := Vector2(local.x, local.z).normalized()
		var col := UiTheme.BONE
		if not g["closed"]:
			col = Color(1.0, 0.3, 0.22)
		elif fort.wood_needed(g) > 0:
			col = Color(0.95, 0.65, 0.25)
		_centered(str(g["short"]), at + dir * radius, HUD_SMALL, col)


## All vs All: what the fog is doing, and the way back if you are out in it.
func _draw_fog(s: Vector2, centre: Vector2) -> void:
	var fog := player.world.fog
	if fog == null:
		return
	if player.dead or fog.contains(player.global_position):
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.45, 0.62, 0.56, 0.22))
	_banner_text("Get out of the fog!", Vector2(centre.x, s.y * 0.24), 1.0)
	_sensor_arrow(centre, (Vector3(fog.centre.x, 0.0, fog.centre.y) - player.global_position).normalized() * 5.0, UiTheme.MOSS)


## Who else is out there, in a panel under your own: each player's name and level, their health and,
## when they are down, how long until they are back. In a fight, the score. If you are down, your own
## countdown in the middle.
func _draw_together(s: Vector2, centre: Vector2) -> float:
	var ids: Array = Net.roster.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.roster[a]["score"]) > int(Net.roster[b]["score"]))
	const BAR_W := 150.0
	const W := 300.0
	# A score beside each name where players fight each other; side by side (a night together, the
	# Fort) nobody's kills are counted out loud.
	var versus := Net.pvp()
	# You are the panel above, so the list is only the others.
	var shown := ids.filter(func(peer: int) -> bool: return peer != Net.my_id())
	var top := _status_bottom + 6.0
	var y := top + 26.0
	if not shown.is_empty():
		var height := 12.0
		for peer: int in shown:
			height += 44.0
		draw_style_box(_backing, Rect2(_pad - 10.0, top, W, height))
	for peer: int in shown:
		var info: Dictionary = Net.roster[peer]
		var col := UiTheme.BONE
		if Net.rules == Net.Rules.TEAMS:
			col = Net.team_colour(int(info["team"]))
		var state := Net.player_state(peer)
		var out: bool = state["out"]
		var down: bool = state["down"]
		var faded := 0.45 if out or down else 1.0
		var line := str(info["name"])
		_text(line, Vector2(_pad, y), HUD_TEXT, Color(col, faded))
		var x := _pad + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_TEXT).x + 8.0
		var lv := "Lv %d" % int(state["level"])
		_text(lv, Vector2(x, y), HUD_SMALL, Color(UiTheme.EMBER, faded))
		x += font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_SMALL).x + 10.0
		if versus:
			var score := "%d" % int(info["score"])
			# The score at the right edge of the panel, where scores line up under each other.
			_text(score, Vector2(_pad - 10.0 + W - 14.0 - font.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_TEXT).x, y), HUD_TEXT, Color(col, faded))
		if Net.fog_rules():
			for i in Net.lives_of(peer):
				draw_texture_rect(Icons.glyph("heart"), Rect2(x + i * 19.0, y - 15.0, 17.0, 17.0), false, UiTheme.BLOOD.lightened(0.2))
		y += 6.0
		var bar := Rect2(_pad, y, BAR_W, 8)
		if out:
			_bar(bar, 0.0, UiTheme.ASH)
			_text("Out", Vector2(_pad + BAR_W + 8, y + 9), HUD_SMALL, UiTheme.ASH)
		elif down:
			_bar(bar, 0.0, UiTheme.ASH)
			var back: float = state["back_in"]
			_text("Back in %d s" % ceili(back) if back >= 0.0 else "Down", Vector2(_pad + BAR_W + 8, y + 9), HUD_SMALL, UiTheme.BLOOD.lightened(0.3))
		else:
			var f: float = state["hp"]
			_bar(bar, f, UiTheme.MOSS.darkened(0.15) if f > 0.35 else UiTheme.BLOOD)
		y += 38.0
	if player.dead:
		var wait := Net.respawn_seconds()
		if Net.is_out():
			_banner_text("You are out", Vector2(centre.x, s.y * 0.3), 1.0)
		elif wait >= 0.0:
			_banner_text("Back in %d" % ceili(wait), Vector2(centre.x, s.y * 0.3), 1.0)
		var who := Net.watching_name()
		if who != "":
			_chip("Watching %s. Tap to change." % who, "eye", UiTheme.BONE, Vector2(centre.x, s.y * 0.88), true)
	return (y - 26.0 + 14.0) if not shown.is_empty() else top


## You, top left, on one panel: the crest of your class, your health with its number, how far to the
## next level, and mana or Ki when your class has them. Under it, small chips: kills, and your mount.
func _draw_status(s: Vector2) -> void:
	var cls := player.class_id
	const BAR_W := 230.0
	var has_mana: bool = player.class_def().get("mana", false)
	var card := Rect2(_pad - 10.0, 8.0, 10.0 + 54.0 + 10.0 + BAR_W + 12.0, 80.0 if has_mana else 64.0)
	draw_style_box(_backing, card)
	Icons.draw(self, Rect2(_pad, 14, 52, 52), ClassDefs.icon(cls), ClassDefs.color(cls))
	var x := _pad + 64.0
	var f := clampf(player.hp / player.max_hp(), 0.0, 1.0)
	var hp_col := UiTheme.MOSS.darkened(0.15) if f > 0.35 else UiTheme.BLOOD
	if player.burn_time > 0.0:
		hp_col = UiTheme.EMBER.darkened(0.1)
	_bar(Rect2(x, 16, BAR_W, 22), f, hp_col)
	_text("%d" % ceil(player.hp), Vector2(x + 9, 34), HUD_SMALL, Color.WHITE)
	var xp_f := 1.0
	if player.level < ClassDefs.MAX_LEVEL:
		xp_f = float(player.xp) / float(player.xp_needed())
	_bar(Rect2(x, 43, BAR_W, 7), xp_f, UiTheme.EMBER)
	if has_mana:
		_bar(Rect2(x, 56, BAR_W, 16), player.mana / maxf(player.max_mana(), 1.0), KI_COLOUR if player.class_def().get("ki", false) else UiTheme.MIST)
		_text("%d" % int(player.mana), Vector2(x + 9, 70), HUD_SMALL - 2, Color.WHITE)
	var y := card.end.y + 6.0
	var cx := _pad - 10.0
	if Game.is_night() and director:
		_clock(s, Game.clock(director.night_left()))
		cx += _chip("%d kills" % player.kills, "skull", UiTheme.BONE, Vector2(cx, y)) + 6.0
	elif Game.mode == Game.Mode.SANDBOX:
		_clock(s, "Sandbox")
	if player.is_riding():
		_chip("%s %d" % [player.mount_name(), ceil(player.riding_left)], "horse", UiTheme.EMBER, Vector2(cx, y))
	elif player.has_mount():
		_chip("%s %d/%d" % [player.mount_name(), player.horse_progress, player.horses_needed()], "horse", UiTheme.EMBER if player.horse_ready() else UiTheme.BONE, Vector2(cx, y))
	_status_bottom = y + CHIP_H


## A small rounded label sitting on the world: an icon and a few words. Drawn from its left edge (or
## its middle, if centred); returns how wide it was.
func _chip(t: String, icon: String, col: Color, at: Vector2, centred := false) -> float:
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_TEXT - 2).x
	var w := 10.0 + (22.0 if icon != "" else 0.0) + tw + 12.0
	var x := at.x - w * 0.5 if centred else at.x
	var r := Rect2(x, at.y, w, CHIP_H)
	draw_style_box(_capsule_soft, r)
	var tx := x + 10.0
	if icon != "":
		draw_texture_rect(Icons.glyph(icon), Rect2(tx, at.y + 5.0, 20.0, 20.0), false, col)
		tx += 26.0
	_text(t, Vector2(tx, at.y + 21.0), HUD_TEXT - 2, col)
	return w


## Under the clock, in one row: whether anything is hunting you, whether you stand in the light, what
## your way of fighting is doing, and the Mist Storm you are in. Each with its own icon.
func _draw_chips(s: Vector2) -> void:
	var chips: Array[Array] = [] # [words, icon, colour]
	if Game.is_night() and director:
		var hunting := player.world.count_hunting()
		if player.invis_left > 0.0:
			chips.append(["Invisible", "eye_closed", UiTheme.MIST])
		elif hunting > 0:
			chips.append(["Hunted", "eye", UiTheme.BLOOD.lightened(0.3)])
		else:
			chips.append(["Unseen", "eye_closed", UiTheme.MOSS])
		if player.is_lit():
			chips.append(["In the light", "sun", UiTheme.EMBER])
	if player.spirit_left > 0.0:
		chips.append(["Your spirit walks: %d s" % ceili(player.spirit_left), "ghost", Color(0.7, 0.95, 1.0)])
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.5, 0.9, 1.0, 0.12))
	elif player.void_left > 0.0:
		chips.append(["Void stance: %d s" % ceili(player.void_left), "moon", Player.STANCE_COLOURS["void"].lightened(0.3)])
	elif player.stone_skin > 0.0:
		chips.append(["Stone Skin %d%%" % roundi(player.stone_skin * 100.0), "mountain", Player.STANCE_COLOURS["stone"]])
	var fog := player.world.fog
	if fog != null:
		chips.append(["The fog is closing" if ClosingFog.is_closing(director.elapsed if director else 0.0) else "The fog holds", "mist", UiTheme.MIST])
	for storm: MistStorm in player.world.mist_storms:
		if is_instance_valid(storm) and storm.hud_line != "":
			chips.append([storm.hud_line, "storm", Color(0.85, 0.7, 1.0)])
	_centre_y = 64.0
	if chips.is_empty():
		return
	var widths: Array[float] = []
	var total := 0.0
	for c: Array in chips:
		var w := 10.0 + 22.0 + font.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_TEXT - 2).x + 12.0
		widths.append(w)
		total += w + 6.0
	var x := s.x * 0.5 - (total - 6.0) * 0.5
	for i in chips.size():
		_chip(chips[i][0], chips[i][1], chips[i][2], Vector2(x, 68.0))
		x += widths[i] + 6.0
	_centre_y = 68.0 + CHIP_H


func _clock(s: Vector2, t: String) -> void:
	var fs := HUD_CLOCK
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_style_box(_backing, Rect2(s.x * 0.5 - w * 0.5 - 18, 12, w + 36, 48))
	draw_string(font, Vector2(s.x * 0.5 - w * 0.5, 47), t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, UiTheme.BONE)


func _draw_powers(top: float) -> void:
	var y := top
	var x := _pad
	for id: String in player.powers:
		var d: Dictionary = PowerDefs.ALL[id]
		var left: float = player.powers[id]
		Icons.draw(self, Rect2(x, y, 46, 46), Icons.power(id), d["color"])
		var fs := HUD_SMALL
		var t := "%d" % ceil(left)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(t, Vector2(x + 23 - w * 0.5, y + 60), fs, UiTheme.BONE)
		x += 52.0
		if x > _pad + 260.0:
			x = _pad
			y += 66.0
	# Buffs, from your own skills or from another player, in the same row.
	for e: Dictionary in player.status_effects():
		Icons.draw(self, Rect2(x, y, 46, 46), e["icon"], e["color"])
		var left: float = e["left"]
		if left >= 0.0:
			var t := "%d" % ceil(left)
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_SMALL).x
			_text(t, Vector2(x + 23 - w * 0.5, y + 60), HUD_SMALL, UiTheme.BONE)
		if int(e["stacks"]) > 1:
			_text("x%d" % int(e["stacks"]), Vector2(x + 30, y + 14), HUD_SMALL - 2, UiTheme.EMBER)
		x += 52.0
		if x > _pad + 260.0:
			x = _pad
			y += 66.0


## Arrows around the crosshair: red for enemies, gold for weapons, both within 20 m.
func _draw_sensor(centre: Vector2) -> void:
	var here := player.global_position
	var r2 := PowerDefs.SENSOR_RANGE * PowerDefs.SENSOR_RANGE
	for z in player.world.zombies:
		if z.is_alive() and z.position.distance_squared_to(here) < r2:
			_sensor_arrow(centre, z.position - here, Color(1, 0.25, 0.2))
	for p in player.world.pickups:
		if p.kind == Pickup.Kind.WEAPON and p.global_position.distance_squared_to(here) < r2:
			_sensor_arrow(centre, p.global_position - here, COL_ACCENT)


## A yellow arc points at any flyer coming down on you, even from behind.
func _draw_dive_warning(centre: Vector2) -> void:
	for z: Zombie in player.world.zombies:
		if not z.flies or not z.is_warning():
			continue
		var to := z.position - player.global_position
		if to.length_squared() > 625.0:
			continue
		var local := player.global_basis.inverse() * Vector3(to.x, 0, to.z)
		if local.length_squared() < 0.04:
			continue
		var a := atan2(local.x, -local.z) - PI * 0.5
		var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.02) * 0.35
		draw_arc(centre, 128.0, a - 0.2, a + 0.2, 10, Color(1.0, 0.8, 0.2, pulse), 7.0)


## A red arc around the crosshair shows where the last hit came from.
func _draw_hurt_direction(centre: Vector2) -> void:
	var to := player.hurt_from - player.global_position
	var local := player.global_basis.inverse() * Vector3(to.x, 0, to.z)
	if local.length_squared() < 0.04:
		return
	var a := atan2(local.x, -local.z) - PI * 0.5
	var fade := clampf(player.hurt_dir_time, 0.0, 1.0)
	draw_arc(centre, 150.0, a - 0.42, a + 0.42, 18, Color(1.0, 0.16, 0.08, 0.28 * fade), 26.0)
	draw_arc(centre, 150.0, a - 0.3, a + 0.3, 14, Color(1.0, 0.24, 0.12, 0.8 * fade), 8.0)


func _draw_level_flash(s: Vector2) -> void:
	var a := player.level_flash
	draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.75, 0.25, a * 0.1))
	var fs := 54
	var t := "Level %d" % player.level
	var w := title.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(s.x * 0.5 - w * 0.5, 186.0 + (1.0 - a) * -14.0)
	var col := Color(UiTheme.EMBER, minf(1.0, a * 1.8))
	draw_string_outline(title, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 7, Color(0, 0, 0, 0.6 * col.a))
	draw_string(title, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


## The name of the closest item, so you know what a glow is before walking over to it.
func _draw_item_name() -> void:
	var p := player.named_item
	if p == null or not is_instance_valid(p):
		return
	var cam := player.camera
	var above := p.global_position + Vector3.UP * 1.5
	if cam.is_position_behind(above):
		return
	var at := cam.unproject_position(above) * size / Vector2(get_viewport().get_visible_rect().size)
	var text := p.display_name()
	var col := UiTheme.BONE
	if p.kind == Pickup.Kind.WEAPON and not player.can_use(p.weapon_id):
		text += " (not for your class)"
		col = Color(0.75, 0.72, 0.68, 0.8)
	_centered(text, at, HUD_TEXT, col)


## A small health bar over anything just hit, and over a Fallen Hero that is hunting you.
func _draw_enemy_bars() -> void:
	var cam := player.camera
	var scale := size / Vector2(get_viewport().get_visible_rect().size)
	for z: Zombie in player.world.zombies:
		if not z.is_alive() or (z.bar_time <= 0.0 and not (z.hero and z.is_hunting())):
			continue
		var top: Vector3 = z.position + Vector3.UP * (z.height + 0.3)
		if cam.is_position_behind(top) or top.distance_squared_to(cam.global_position) > 1600.0:
			continue
		var at := cam.unproject_position(top) * scale
		var w := 112.0 if z.hero else 62.0
		var r := Rect2(at - Vector2(w * 0.5, 4.0), Vector2(w, 8.0))
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(z.hp / z.max_hp, 0.0, 1.0), r.size.y)), Color(0.72, 0.13, 0.1) if not z.hero else Color(0.72, 0.28, 0.72))
		if z.hero:
			_centered(z.display_name(), at + Vector2(0, -16.0), HUD_TEXT, Color(1.0, 0.84, 0.95))
	# Other players and bots: their health for a moment after a hit, red for foes and green for friends.
	for t: Target in player.world.players:
		if not is_instance_valid(t) or not t is Avatar:
			continue
		var a := t as Avatar
		if a.dead or a.bar_time <= 0.0 or a.is_unseen():
			continue
		var top: Vector3 = a.global_position + Vector3.UP * 2.35
		if cam.is_position_behind(top) or top.distance_squared_to(cam.global_position) > 2500.0:
			continue
		var at := cam.unproject_position(top) * scale
		var r := Rect2(at - Vector2(36.0, 4.0), Vector2(72.0, 8.0))
		var fade := minf(1.0, a.bar_time * 2.0)
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.7 * fade))
		var col := Color(0.8, 0.16, 0.12) if Net.is_foe(a.peer) else Color(0.32, 0.78, 0.36)
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(a.hp_fraction, 0.0, 1.0), r.size.y)), Color(col, fade))


## Red diamonds on enemies marked through walls: by a Raven, a scent or a hunter's eye.
func _draw_marks() -> void:
	var cam := player.camera
	var here := player.global_position
	var raven := player.has_power("raven")
	var lantern := player.has_power("lantern")
	var scent := player.has_flag("scent")
	if not raven and not scent and not lantern:
		var any := false
		for z in player.world.zombies:
			if z.reveal_left > 0.0:
				any = true
				break
		if not any:
			return
	for z in player.world.zombies:
		if not z.is_alive():
			continue
		var d2: float = z.position.distance_squared_to(here)
		var seen: bool = (raven and d2 < PowerDefs.RAVEN_RANGE * PowerDefs.RAVEN_RANGE) or (lantern and d2 < PowerDefs.LANTERN_RANGE * PowerDefs.LANTERN_RANGE) or (scent and d2 < AbilityNumbers.SCENT_REACH * AbilityNumbers.SCENT_REACH) or z.reveal_left > 0.0
		if not seen:
			continue
		var top: Vector3 = z.position + Vector3.UP * (z.height + 0.35)
		if cam.is_position_behind(top):
			continue
		var at := cam.unproject_position(top) * size / Vector2(get_viewport().get_visible_rect().size)
		var r := 8.0
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), Color(1, 0.25, 0.2, 0.9))


func _sensor_arrow(centre: Vector2, to: Vector3, col: Color) -> void:
	var dist := Vector2(to.x, to.z).length()
	var local := player.global_basis.inverse() * Vector3(to.x, 0, to.z)
	var ang := atan2(local.x, -local.z)
	var dir := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-dir.y, dir.x)
	var radius := 120.0 + dist * 4.0
	var tip := centre + dir * (radius + 20.0)
	var base := centre + dir * radius
	var pts := PackedVector2Array([tip, base + side * 11.0, base - side * 11.0])
	draw_colored_polygon(pts, Color(col, clampf(1.3 - dist / PowerDefs.SENSOR_RANGE, 0.35, 1.0)))


## What you hold, and what it has left to throw or cast, on a chip at the bottom just left of the
## fighting buttons, under the swap button: where the thumb that uses it already is.
func _draw_weapon(s: Vector2) -> void:
	var d := player.weapon_def()
	if d.is_empty():
		return
	var name_text := str(d["name"])
	var extra := ""
	var extra_col := UiTheme.BONE
	if d["kind"] == WeaponDefs.Kind.SPELL:
		extra = "%d mana" % int(player.mana)
		extra_col = UiTheme.MIST
	elif player.has_burst():
		extra = "%d mist" % int(player.mana)
		extra_col = UiTheme.MIST
	elif player.class_def().get("ki", false):
		extra = "%d Ki" % int(player.mana)
		extra_col = KI_COLOUR
	elif WeaponDefs.own_ammo(player.weapon_id()) > 0:
		var throws := player.ammo_of(player.weapon_id())
		extra = "%d throws" % throws
		extra_col = UiTheme.BONE if throws > 0 else UiTheme.BLOOD.lightened(0.25)
	elif WeaponDefs.uses_arrows(d):
		extra = "%d arrows" % player.arrows
		extra_col = UiTheme.BONE if player.arrows > 0 else UiTheme.BLOOD.lightened(0.25)
	elif player.arrows > 0:
		extra = "%d arrows" % player.arrows
		extra_col = Color(UiTheme.BONE, 0.65)
	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_TEXT).x
	var extra_w := font.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_SMALL).x if extra != "" else 0.0
	var w := 14.0 + name_w + (10.0 + extra_w if extra != "" else 0.0) + 14.0
	var fire: Dictionary = _buttons["fire"]
	var right := (fire["pos"] as Vector2).x - float(fire["r"]) - 14.0
	var r := Rect2(right - w, s.y - 20.0 - CHIP_H, w, CHIP_H)
	draw_style_box(_capsule_soft, r)
	_text(name_text, Vector2(r.position.x + 14.0, r.position.y + 21.0), HUD_TEXT, UiTheme.BONE)
	if extra != "":
		_text(extra, Vector2(r.position.x + 14.0 + name_w + 10.0, r.position.y + 21.0), HUD_SMALL, extra_col)


var _path_art_useful := true


func _draw_controls() -> void:
	if player.dead:
		pass
	elif _joy_finger >= 0:
		draw_circle(_joy_origin, JOY_R, Color(1, 1, 1, 0.1))
		draw_arc(_joy_origin, JOY_R, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
		draw_circle(_joy_origin + (_joy_pos - _joy_origin).limit_length(JOY_R), 38.0, Color(1, 1, 1, 0.45))
	else:
		var hint := Vector2(_pad + JOY_R + 22, size.y - JOY_R - 48)
		draw_arc(hint, JOY_R, 0.0, TAU, 40, Color(1, 1, 1, 0.2), 3.0)
		draw_circle(hint, 36.0, Color(1, 1, 1, 0.12))
	_path_art_useful = player.has_path_art() and player.path_art_has_use()
	for id: String in _buttons:
		if not _button_visible(id) or (player.dead and id != "pause" and id != "tree"):
			continue
		var b: Dictionary = _buttons[id]
		var pos: Vector2 = b["pos"]
		var r: float = b["r"]
		var held := _fingers.values().has(id)
		var rect := Rect2(pos - Vector2.ONE * r, Vector2.ONE * r * 2.0)
		var tint := Color(1, 1, 1, 1)
		match id:
			"fire": tint = Color(1.0, 0.72, 0.62)
			"take": tint = UiTheme.EMBER
			"horse": tint = UiTheme.EMBER
			"burst":
				tint = UiTheme.MIST if player.burst_cd_left <= 0.0 and player.mana >= player.burst_cost() else Color(0.6, 0.6, 0.6)
			"path_art":
				# Lit only when it would do something now: a Steal with nobody in reach stays grey.
				tint = UiTheme.MIST if player.path_art_cd_left <= 0.0 and _path_art_useful else Color(0.6, 0.6, 0.6)
			"art":
				tint = UiTheme.MIST if player.art_cd_left <= 0.0 and player.mana >= player.art_cost() else Color(0.6, 0.6, 0.6)
				if player.class_id == "cartographer" and CartographerKit.would_stand_alone(player):
					# Planted here, the beacon would link to none of the others.
					tint = UNLINKED if player.art_cd_left <= 0.0 else UNLINKED.darkened(0.35)
			"zoom":
				if player.zoomed:
					tint = UiTheme.EMBER
			"tree":
				tint = Color(1.0, 0.82, 0.45)
				if player.points > 0:
					tint = Color(1.0, 0.62 + sin(Time.get_ticks_msec() * 0.008) * 0.2, 0.25)
		if held:
			rect = rect.grow(-3.0)
		if id == "tree" and player.points > 0:
			_draw_points_call(pos, r)
		draw_texture_rect(_glass, rect, false, tint)
		var glyph := _button_glyph(id)
		var inset := r * 0.42
		draw_texture_rect(Icons.glyph(glyph), rect.grow(-inset), false, Color.WHITE)
		draw_texture_rect(_ring, rect, false, Color(1, 1, 1, 0.6) if not held else UiTheme.EMBER)
		if id == "drop" and held and _drop_held >= 0.0:
			draw_arc(pos, r - 4.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_drop_held / DROP_HOLD, 0.0, 1.0), 32, UiTheme.EMBER, 7.0)
		if id == "drop":
			_centered("Hold to drop", pos + Vector2(0, r + 14), HUD_SMALL, UiTheme.BONE)
		if id == "take" and player.nearby_weapon:
			_chip(player.nearby_weapon.display_name(), "grab", UiTheme.BONE, pos + Vector2(0, -r - 18 - CHIP_H), true)
		if id == "art" and player.class_id == "cartographer" and CartographerKit.would_stand_alone(player):
			_centered("Too far to link", pos + Vector2(0, -r - 14), HUD_SMALL, UNLINKED.lightened(0.3))
		elif id == "art" and player.art_label() != "":
			_centered(player.art_label(), pos + Vector2(0, -r - 14), HUD_SMALL, UiTheme.BONE)
		if id == "path_art":
			var ready := player.path_art_cd_left <= 0.0
			if ready and _path_art_useful and player.spec_id == "thief":
				# Someone is in reach: a ring of the class's colour says Steal will find them.
				var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.009) * 0.35
				draw_arc(pos, r + 5.0, 0.0, TAU, 40, Color(UiTheme.EMBER, pulse), 4.0)
			var word := str(player.path_art_def().get("name", ""))
			if ready and not _path_art_useful:
				word = "No one in reach"
			_centered(word, pos + Vector2(0, -r - 14), HUD_SMALL, UiTheme.BONE if _path_art_useful or not ready else UiTheme.ASH)
			if not ready:
				var total := maxf(float(player.path_art_def().get("cd", 1.0)) * player.m("art_cd"), 0.1)
				draw_arc(pos, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(player.path_art_cd_left / total, 0.0, 1.0), 28, Color(0, 0, 0, 0.7), 9.0)
				_centered("%d" % ceili(player.path_art_cd_left), pos, HUD_TOAST - 2, Color.WHITE)
		if id == "burst" or id == "art":
			var left: float = player.burst_cd_left if id == "burst" else player.art_cd_left
			if id == "art" and player.spirit_left > 0.0:
				left = 0.0
			var total: float = player.m("burst_cd") if id == "burst" else maxf(float(player.art_def().get("cd", 1.0)) * player.m("art_cd"), 0.1)
			if left > 0.0:
				draw_arc(pos, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(left / total, 0.0, 1.0), 28, Color(0, 0, 0, 0.7), 9.0)
				_centered("%d" % ceili(left), pos, HUD_TOAST - 2, Color.WHITE)
			var cost: float = player.burst_cost() if id == "burst" else player.art_cost()
			if cost > 0.0:
				_centered("%d" % int(cost), pos + Vector2(0, r + 12), HUD_SMALL, UiTheme.MIST)
		if id == "tree":
			# Always marked out from the other buttons, with the level under it.
			draw_arc(pos, r + 2.0, 0.0, TAU, 40, Color(UiTheme.EMBER, 0.9), 3.0)
			_centered("Skills  Lv %d" % player.level, pos + Vector2(0, r + 16), HUD_SMALL, UiTheme.EMBER if player.points > 0 else UiTheme.BONE)
			if player.points > 0:
				_draw_points_badge(pos + Vector2(r * 0.74, -r * 0.62), player.points)


## Rings that keep spreading out from the tree while there is a point to spend.
func _draw_points_call(pos: Vector2, r: float) -> void:
	var t := fmod(Time.get_ticks_msec() * 0.001, 1.4) / 1.4
	for k in 2:
		var f := fmod(t + k * 0.5, 1.0)
		draw_arc(pos, r + 4.0 + f * 26.0, 0.0, TAU, 48, Color(1.0, 0.7, 0.2, (1.0 - f) * 0.75), 4.0 - f * 2.5)


## How many points are waiting, on a red badge at the corner of the button.
func _draw_points_badge(at: Vector2, points: int) -> void:
	draw_circle(at, 17.0, Color(0.05, 0.04, 0.05, 0.9))
	draw_circle(at, 15.0, UiTheme.BLOOD.lightened(0.15))
	_centered("%d" % points, at + Vector2(0, 1), HUD_TEXT, Color.WHITE)


func _button_glyph(id: String) -> String:
	match id:
		"fire":
			return Icons.weapon(player.weapon_id()).split("+")[0]
		"jump": return "jump"
		"bayonet": return "spear"
		"switch": return "swap"
		"drop": return "let_go"
		"zoom": return "eye"
		"take": return "grab"
		"pause": return "pause"
		"tree": return "tree"
		"sandbox": return "gear"
		"horse":
			if player.is_riding() or player.ride_behind != 0:
				return "horseshoe"
			return "chariot" if player.mount_kind() == "chariot" else "horse"
		"burst": return "burst"
		"art": return player.art_glyph()
		"path_art": return str(player.path_art_def().get("icon", "mist"))
	return "plus"


func _draw_stance(s: Vector2) -> void:
	var at := Vector2(s.x * 0.5, _centre_y + 32.0)
	var tint: Color = Player.STANCE_COLOURS[player.stance]
	draw_style_box(_backing, Rect2(at - Vector2(158, 26), Vector2(316, 74)))
	Icons.draw(self, Rect2(at - Vector2(146, 19), Vector2(38, 38)), str(Player.STANCE_ICONS[player.stance]), tint)
	_centered("%s stance" % str(Player.STANCE_NAMES[player.stance]), at + Vector2(14, 0), HUD_TEXT + 2, tint)
	var detail: String = {"wind": "Speed / echo strikes", "stone": "Protection / knockback", "flame": "Burning strikes / exposed", "void": "Invisible / double damage"}[player.stance]
	if player.stance_hits >= 3:
		detail = "+15% damage / transition ready"
	_centered(detail, at + Vector2(0, 27), HUD_SMALL, UiTheme.BONE)
	for i in 3:
		draw_circle(at + Vector2(130 + i * 9, -17), 3.0, tint if player.stance_hits > i else UiTheme.ASH.darkened(0.5))
	_centre_y = at.y + 52.0
