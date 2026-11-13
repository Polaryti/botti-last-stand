class_name WorldAtlas
extends Control
## The known world, drawn as a map to choose where to play: the Village in its lowland by the river,
## the road to the Fort, the Fort's portal to the Mists, the portal from the heart of the Mists to Mist
## Bastion on its peak in the twilight lands beyond, and the road down from the Bastion to the Valleys
## of Mesenlla.
## Each place is a medal you can tap. Places that cannot be played in the mode being chosen for are
## drawn dimmed and cannot be picked.

signal picked(id: String)

## Where each place lies on the atlas, as a share of its width and height.
const SPOTS := {"village": Vector2(0.16, 0.7), "fort": Vector2(0.37, 0.82), "mists": Vector2(0.5, 0.42), "mesenlla": Vector2(0.84, 0.62), "bastion": Vector2(0.76, 0.24)}
## Roads walk; portals open. Each link is [from, to, through a portal].
const LINKS := [["village", "fort", false], ["fort", "mists", true], ["mists", "bastion", true], ["bastion", "mesenlla", false]]
const MEDAL := 92.0

var allowed: Array = []
var selected := ""
var _t := 0.0
var _medals := {}


func _init(can_pick: Array, start := "") -> void:
	allowed = can_pick
	selected = start if start in can_pick else (can_pick[0] if not can_pick.is_empty() else "")
	clip_contents = true


func _ready() -> void:
	for id: String in Places.ORDER:
		var place: Dictionary = Places.ALL[id]
		var b := Button.new()
		b.name = "Place_" + id
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(MEDAL + 70.0, MEDAL + 44.0)
		b.size = b.custom_minimum_size
		b.disabled = id not in allowed
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var clear := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, clear)
		add_child(b)
		var medal := IconView.new(place["icon"], (place["color"] as Color).darkened(0.55), MEDAL)
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.position = Vector2(35.0, 0.0)
		medal.modulate = Color(1, 1, 1, 1.0 if id in allowed else 0.45)
		b.add_child(medal)
		var label := Label.new()
		label.text = place["name"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UiTheme.bold_font())
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", UiTheme.BONE if id in allowed else UiTheme.ASH.darkened(0.25))
		label.add_theme_color_override("font_outline_color", Color(UiTheme.NIGHT, 0.9))
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(-20.0, MEDAL + 4.0)
		label.size = Vector2(MEDAL + 110.0, 30.0)
		b.add_child(label)
		var chosen := id
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click", -3.0)
			selected = chosen
			picked.emit(chosen))
		_medals[id] = b
	_place_medals()
	resized.connect(_place_medals)


func _place_medals() -> void:
	for id: String in _medals:
		var b: Button = _medals[id]
		b.position = spot(id) - Vector2(b.size.x * 0.5, MEDAL * 0.5)


func spot(id: String) -> Vector2:
	return (SPOTS[id] as Vector2) * size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	# The night over the known world; to the north-east, the twilight beyond the Mists.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.11))
	_glow(Vector2(w * 0.82, h * 0.36), h * 0.55, Color(0.96, 0.56, 0.34), 0.16)
	_glow(Vector2(w * 0.5, h * 0.42), h * 0.34, Color(0.42, 0.28, 0.8), 0.22)
	var r := RandomNumberGenerator.new()
	r.seed = 2022
	for i in 70:
		var at := Vector2(r.randf() * w, r.randf() * h)
		draw_circle(at, 1.0 + r.randf(), Color(1, 1, 1, 0.12 + 0.12 * sin(_t * 1.2 + i)))
	_lowland(w, h)
	_mists(w, h)
	_beyond(w, h)
	for link: Array in LINKS:
		_link(spot(link[0]), spot(link[1]), link[2])
	for id: String in Places.ORDER:
		var c := spot(id)
		if id == selected:
			var pulse := 0.6 + 0.4 * sin(_t * 3.0)
			draw_arc(c, MEDAL * 0.62, 0.0, TAU, 40, Color(UiTheme.EMBER, pulse), 4.0, true)
		elif id in allowed:
			draw_arc(c, MEDAL * 0.56, 0.0, TAU, 40, Color(UiTheme.BONE, 0.25), 2.0, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.STEEL, false, 2.0)


func _glow(at: Vector2, radius: float, col: Color, strength: float) -> void:
	const STEPS := 14
	for i in STEPS:
		draw_circle(at, radius * (1.0 - float(i) / STEPS), Color(col, strength / STEPS * 1.6))


## The Village's lowland: a rolling edge of land, a river winding through, fields and roofs.
func _lowland(w: float, h: float) -> void:
	var land := PackedVector2Array([Vector2(0, h)])
	for i in 13:
		var f := i / 12.0
		var x := lerpf(0.0, w * 0.5, f)
		var y := lerpf(h * 0.52, h * 0.96, f * f) + sin(f * 11.0) * h * 0.025
		land.append(Vector2(x, y))
	land.append(Vector2(w * 0.5, h))
	draw_colored_polygon(land, Color(0.12, 0.17, 0.15))
	var river := PackedVector2Array()
	for i in 21:
		var f := i / 20.0
		river.append(Vector2(lerpf(w * 0.02, w * 0.3, f), h * (0.56 + 0.44 * f) + sin(f * 9.0) * h * 0.03))
	draw_polyline(river, Color(0.24, 0.42, 0.58), 5.0, true)
	for i in 5:
		draw_rect(Rect2(Vector2(w * (0.12 + 0.025 * i), h * (0.6 + 0.02 * (i % 2))), Vector2(8, 7)), Color(0.85, 0.72, 0.45, 0.5))


## The Mists: islands floating over a soft dark void, round a bright heart.
func _mists(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.42)
	_glow(c, h * 0.26, Color(0.02, 0.01, 0.06), 1.4)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var p := c + Vector2(cos(a), sin(a) * 0.75) * h * 0.15 + Vector2(0, sin(_t * 0.8 + i) * 2.0)
		var s := h * (0.025 + 0.008 * (i % 3))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(s, 0), p + Vector2(0, s * 1.3)]), Color(0.2, 0.18, 0.3))
		draw_circle(p + Vector2(0, s * 1.3), 2.0, Color(0.45, 0.95, 0.92, 0.7))


## Beyond the Mists: a range of peaks under a twilight sky, snow on their tops, a valley among them.
func _beyond(w: float, h: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for layer in 2:
		var line := PackedVector2Array([Vector2(w * (0.58 + 0.04 * layer), h)])
		var tops: Array[Vector2] = []
		var x := w * (0.6 + 0.04 * layer)
		var k := 0
		while x < w * 1.02:
			# The range rises in foothills from the plain on its west side, rather than standing up like a wall.
			var base := h * (0.86 if k == 0 else 0.5 + 0.12 * layer + r.randf_range(-0.04, 0.04))
			line.append(Vector2(x, base))
			var high := h * (0.16 + 0.14 * layer + r.randf_range(0.0, 0.14))
			high = lerpf(h * 0.7, high, clampf(k / 2.0, 0.0, 1.0))
			var top := Vector2(x + w * r.randf_range(0.04, 0.06), high)
			k += 1
			line.append(top)
			tops.append(top)
			x = top.x + w * r.randf_range(0.03, 0.05)
		line.append(Vector2(w, h))
		draw_colored_polygon(line, Color(0.3, 0.21, 0.36) if layer == 0 else Color(0.19, 0.14, 0.25))
		for top in tops:
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(-w * 0.014, h * 0.05), top + Vector2(w * 0.002, h * 0.035), top + Vector2(w * 0.014, h * 0.05)]), Color(0.96, 0.78, 0.68, 0.5 - 0.15 * layer))


## A road (a dotted line) or a portal's path (a glowing, moving dash with a ring at each end).
func _link(a: Vector2, b: Vector2, portal: bool) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.01)
	var start := MEDAL * 0.6
	var end := length - MEDAL * 0.6
	if end <= start:
		return
	var step := 14.0 if portal else 10.0
	var offset := fmod(_t * 18.0, step) if portal else 0.0
	var d := start + offset
	while d < end:
		var p := a + dir * d
		var q := a + dir * minf(d + step * 0.5, end)
		draw_line(p, q, Color(0.66, 0.5, 1.0, 0.85) if portal else Color(0.85, 0.72, 0.45, 0.7), 3.0 if portal else 2.0, true)
		d += step
	if portal:
		for at: Vector2 in [a + dir * start, a + dir * end]:
			draw_arc(at, 6.0, 0.0, TAU, 16, Color(0.66, 0.5, 1.0), 2.0, true)
