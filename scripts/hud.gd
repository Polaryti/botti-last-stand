class_name Hud
extends Control
## Touch HUD. It reads raw multi-touch itself, because normal UI buttons only follow
## one finger, and a shooter needs to move, aim and attack at the same time.

signal pause_requested
signal tree_requested
signal sandbox_requested

const JOY_R := 88.0
const COL_BG := Color(0.05, 0.05, 0.07, 0.72)
const COL_LINE := Color(1, 1, 1, 0.7)
const COL_FIRE := Color(0.62, 0.13, 0.09, 0.8)
const COL_ACCENT := Color(1.0, 0.78, 0.3)

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
var _track := UiTheme.flat(Color(UiTheme.NIGHT, 0.72), Color.TRANSPARENT, 5, 0.0)
var _fill := UiTheme.flat(Color.WHITE, Color.TRANSPARENT, 5, 0.0)
var _capsule := UiTheme.flat(Color(UiTheme.NIGHT, 0.6), Color.TRANSPARENT, 10, 0.0)
var _was_dead := false


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
		"switch": {"pos": Vector2(right - 248, bottom - 92), "r": 52.0},
		"zoom": {"pos": Vector2(right - 208, bottom - 260), "r": 50.0},
		"take": {"pos": Vector2(s.x * 0.5, s.y * 0.68), "r": 62.0},
		"pause": {"pos": Vector2(right - 28, 46), "r": 32.0},
		"tree": {"pos": Vector2(right - 112, 46), "r": 38.0},
		"sandbox": {"pos": Vector2(right - 204, 46), "r": 38.0},
		"horse": {"pos": Vector2(right - 372, bottom - 130), "r": 58.0},
		"burst": {"pos": Vector2(right - 372, bottom - 110), "r": 60.0},
		"art": {"pos": Vector2(right - 352, bottom - 260), "r": 56.0},
	}


func _button_visible(id: String) -> bool:
	if player == null:
		return false
	match id:
		"take":
			return player.nearby_weapon != null
		"zoom":
			return player.weapon_def().has("zoom_fov")
		"switch":
			return player.slots[0] != null and player.slots[1] != null
		"horse":
			return player.horse_ready() or player.is_riding() or player.ride_behind != 0 or player.can_board()
		"burst":
			return player.has_burst()
		"art":
			return player.has_art()
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
		if event is InputEventScreenTouch:
			var at: Vector2 = (event as InputEventScreenTouch).position
			if at.distance_to(_buttons["pause"]["pos"]) < float(_buttons["pause"]["r"]) * 1.12:
				pause_requested.emit()
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
			"zoom": player.toggle_zoom()
			"take": player.take_nearby_weapon()
			"pause": pause_requested.emit()
			"tree": tree_requested.emit()
			"sandbox": sandbox_requested.emit()
			"burst": player.use_burst()
			"art": player.use_art()
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
		"look", "fire":
			# Aiming also works while a thumb holds ATTACK.
			player.apply_look(e.relative.x, e.relative.y)


func release_all() -> void:
	_fingers.clear()
	_joy_finger = -1
	if player:
		player.input_move = Vector2.ZERO
		player.input_fire = false


func _process(_delta: float) -> void:
	if player and player.dead != _was_dead:
		_was_dead = player.dead
		release_all()
	queue_redraw()


func _banner_text(t: String, centre: Vector2, a: float) -> void:
	var fs := 46
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
	_draw_status(s)
	if Net.in_game:
		_draw_together(s, centre)
	if player.world.fort:
		_draw_fort(s, centre)
	_draw_powers()
	_draw_weapon(s)
	_draw_controls()
	if player.toast_time > 0.0:
		_centered(player.toast, Vector2(centre.x, s.y * 0.38), 30, Color(UiTheme.BONE, minf(1.0, player.toast_time * 2.0)))
	if director and director.banner_time > 0.0:
		_banner_text(director.banner, Vector2(centre.x, s.y * 0.32), minf(1.0, director.banner_time))


func _bar(r: Rect2, f: float, col: Color) -> void:
	draw_style_box(_track, r)
	var part := clampf(f, 0.0, 1.0)
	if part > 0.0:
		_fill.bg_color = col
		draw_style_box(_fill, Rect2(r.position, Vector2(maxf(r.size.x * part, minf(r.size.y, r.size.x)), r.size.y)))


## The heart, the four gates, and how much wood you carry.
func _draw_fort(s: Vector2, centre: Vector2) -> void:
	var fort := player.world.fort
	var w := 260.0
	var top := 122.0
	_bar(Rect2(centre.x - w * 0.5, top, w, 12), fort.heart_hp / Fort.HEART_HP, Color(0.9, 0.3, 0.24))
	_centered("Heart", Vector2(centre.x - w * 0.5 - 36, top + 6), 18, UiTheme.BONE)
	var gate_w := (w - 18.0) / 4.0
	for i in fort.gates.size():
		var g: Dictionary = fort.gates[i]
		var r := Rect2(centre.x - w * 0.5 + i * (gate_w + 6.0), top + 20, gate_w, 9)
		_bar(r, float(g["hp"]) / Fort.GATE_HP, Color(0.72, 0.5, 0.26) if g["closed"] else Color(0.8, 0.2, 0.15))
		_centered(["N", "E", "S", "W"][i], r.get_center() + Vector2(0, 16), 15, UiTheme.BONE)
	if player.wood > 0:
		_text("Wood %d" % player.wood, Vector2(s.x * 0.33, s.y - 86.0), 22, Color(0.92, 0.72, 0.42))
	if fort.repairing >= 0:
		_centered("Mending the %s gate" % Fort.NAMES[fort.repairing], Vector2(centre.x, s.y * 0.62), 26, Color(0.92, 0.72, 0.42))


## Who else is out there. In a fight, the score. If you are down, how long until you are back.
func _draw_together(s: Vector2, centre: Vector2) -> void:
	var y := _status_bottom + 18.0
	var ids: Array = Net.roster.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.roster[a]["score"]) > int(Net.roster[b]["score"]))
	for peer: int in ids:
		var info: Dictionary = Net.roster[peer]
		var col := UiTheme.BONE
		if Net.rules == Net.Rules.TEAMS:
			col = Net.team_colour(int(info["team"]))
		var line := str(info["name"])
		if Net.rules != Net.Rules.COOP:
			line += "  %d" % int(info["score"])
		_text(line, Vector2(_pad, y), 19, Color(col, 1.0 if peer == Net.my_id() else 0.8))
		y += 22.0
	if player.dead:
		var wait := Net.respawn_seconds()
		if wait >= 0.0:
			_banner_text("Back in %d" % ceili(wait), Vector2(centre.x, s.y * 0.3), 1.0)
		var who := Net.watching_name()
		if who != "":
			_centered("Watching %s. Tap to change." % who, Vector2(centre.x, s.y * 0.88), 26, UiTheme.BONE)


func _draw_status(s: Vector2) -> void:
	var cls := player.class_id
	Icons.draw(self, Rect2(_pad, 14, 58, 58), ClassDefs.icon(cls), ClassDefs.color(cls))
	var x := _pad + 68.0
	var f := clampf(player.hp / player.max_hp(), 0.0, 1.0)
	var hp_col := UiTheme.MOSS.darkened(0.15) if f > 0.35 else UiTheme.BLOOD
	if player.burn_time > 0.0:
		hp_col = UiTheme.EMBER.darkened(0.1)
	_bar(Rect2(x, 16, 240, 22), f, hp_col)
	_text("%d" % ceil(player.hp), Vector2(x + 9, 34), 18, Color.WHITE)
	var xp_f := 1.0
	if player.level < ClassDefs.MAX_LEVEL:
		xp_f = float(player.xp) / float(player.xp_needed())
	_bar(Rect2(x, 42, 240, 7), xp_f, UiTheme.EMBER)
	var y := 66.0
	if player.class_def().get("mana", false):
		var mana_rect := Rect2(x, 53, 240, 16)
		_bar(mana_rect, player.mana / maxf(player.max_mana(), 1.0), UiTheme.MIST)
		_text("%d" % int(player.mana), Vector2(x + 9, 67), 14, Color.WHITE)
		y = 84.0
	y = maxf(y, 82.0)
	if Game.is_night() and director:
		_clock(s, Game.clock(director.night_left()))
		_text("%d kills" % player.kills, Vector2(_pad, y + 18), 21, UiTheme.BONE)
		y += 28.0
		var hunting := player.world.count_hunting()
		var label := "Hunted" if hunting > 0 else "Unseen"
		if player.invis_left > 0.0:
			label = "Vanished"
		var col := UiTheme.BLOOD.lightened(0.25) if hunting > 0 and player.invis_left <= 0.0 else UiTheme.MOSS
		_centered(label, Vector2(s.x * 0.5, 80), 20, col)
		if player.is_lit():
			_centered("In the light", Vector2(s.x * 0.5, 102), 18, UiTheme.EMBER)
	elif Game.mode == Game.Mode.SANDBOX:
		_clock(s, "Sandbox")
	if player.guard_left > 0.0 and player.guard_left < 100.0:
		_centered("Invincible %d" % ceili(player.guard_left), Vector2(s.x * 0.5, s.y * 0.2), 24, UiTheme.EMBER)
	if player.is_riding():
		_text("%s %d" % [player.mount_name(), ceil(player.riding_left)], Vector2(_pad, y + 18), 20, UiTheme.EMBER)
		y += 26.0
	elif player.has_mount():
		_text("%s %d/%d" % [player.mount_name(), player.horse_progress, player.horses_needed()], Vector2(_pad, y + 18), 20, UiTheme.EMBER if player.horse_ready() else UiTheme.BONE)
		y += 26.0
	_status_bottom = y + 16.0


func _clock(s: Vector2, t: String) -> void:
	var fs := 32
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_style_box(_capsule, Rect2(s.x * 0.5 - w * 0.5 - 18, 12, w + 36, 48))
	draw_string(font, Vector2(s.x * 0.5 - w * 0.5, 47), t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, UiTheme.BONE)


func _draw_powers() -> void:
	var y := _status_bottom
	var x := _pad
	for id: String in player.powers:
		var d: Dictionary = PowerDefs.ALL[id]
		var left: float = player.powers[id]
		Icons.draw(self, Rect2(x, y, 46, 46), Icons.power(id), d["color"])
		var fs := 18
		var t := "%d" % ceil(left)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(t, Vector2(x + 23 - w * 0.5, y + 60), fs, UiTheme.BONE)
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
	_centered(text, at, 22, col)


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
			_centered(z.display_name(), at + Vector2(0, -16.0), 20, Color(1.0, 0.84, 0.95))


## Red diamonds on enemies marked through walls: by a Raven, a scent or a hunter's eye.
func _draw_marks() -> void:
	var cam := player.camera
	var here := player.global_position
	var raven := player.has_power("raven")
	var scent := player.has_flag("scent")
	if not raven and not scent:
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
		var seen: bool = (raven and d2 < PowerDefs.RAVEN_RANGE * PowerDefs.RAVEN_RANGE) or (scent and d2 < 225.0) or z.reveal_left > 0.0
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


func _draw_weapon(s: Vector2) -> void:
	var d := player.weapon_def()
	if d.is_empty():
		return
	var y := s.y - 26.0
	var x := s.x * 0.33
	_text(str(d["name"]), Vector2(x, y - 30), 24, UiTheme.BONE)
	if d["kind"] == WeaponDefs.Kind.SPELL:
		_text("%d mana" % int(player.mana), Vector2(x, y), 22, UiTheme.MIST)
	elif player.has_burst():
		_text("%d mist" % int(player.mana), Vector2(x, y), 22, UiTheme.MIST)
	elif WeaponDefs.uses_arrows(d):
		_text("%d arrows" % player.arrows, Vector2(x, y), 22, UiTheme.BONE if player.arrows > 0 else UiTheme.BLOOD.lightened(0.25))
	elif player.arrows > 0:
		_text("%d arrows" % player.arrows, Vector2(x, y), 18, Color(UiTheme.BONE, 0.65))


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
	for id: String in _buttons:
		if not _button_visible(id) or (player.dead and id != "pause"):
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
			"art":
				tint = UiTheme.MIST if player.art_cd_left <= 0.0 and player.mana >= player.art_cost() else Color(0.6, 0.6, 0.6)
			"zoom":
				if player.zoomed:
					tint = UiTheme.EMBER
			"tree":
				if player.points > 0:
					tint = Color(UiTheme.EMBER, 0.65 + sin(Time.get_ticks_msec() * 0.006) * 0.35)
		if held:
			rect = rect.grow(-3.0)
		draw_texture_rect(_glass, rect, false, tint)
		var glyph := _button_glyph(id)
		var inset := r * 0.42
		draw_texture_rect(Icons.glyph(glyph), rect.grow(-inset), false, Color(UiTheme.BONE, 0.95))
		draw_texture_rect(_ring, rect, false, Color(1, 1, 1, 0.6) if not held else UiTheme.EMBER)
		if id == "take" and player.nearby_weapon:
			_centered(player.nearby_weapon.display_name(), pos + Vector2(0, -r - 18), 26, UiTheme.BONE)
		if id == "art" and player.art_label() != "":
			_centered(player.art_label(), pos + Vector2(0, -r - 14), 18, UiTheme.BONE)
		if id == "burst" or id == "art":
			var left: float = player.burst_cd_left if id == "burst" else player.art_cd_left
			var total: float = player.m("burst_cd") if id == "burst" else maxf(float(player.art_def().get("cd", 1.0)) * player.m("art_cd"), 0.1)
			if left > 0.0:
				draw_arc(pos, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(left / total, 0.0, 1.0), 28, Color(0, 0, 0, 0.7), 9.0)
				_centered("%d" % ceili(left), pos, 26, Color.WHITE)
			var cost: float = player.burst_cost() if id == "burst" else player.art_cost()
			if cost > 0.0:
				_centered("%d" % int(cost), pos + Vector2(0, r + 12), 18, UiTheme.MIST)
		if id == "tree":
			_centered("%d" % player.level, pos + Vector2(0, r + 14), 20, UiTheme.EMBER if player.points > 0 else UiTheme.BONE)


func _button_glyph(id: String) -> String:
	match id:
		"fire":
			return Icons.weapon(player.weapon_id()).split("+")[0]
		"jump": return "jump"
		"switch": return "swap"
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
	return "plus"
