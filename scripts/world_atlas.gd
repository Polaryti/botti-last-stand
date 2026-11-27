class_name WorldAtlas
extends Control
## The known world, drawn as a map to choose where to play: the Village in its lowland by the river,
## the road to the Fort, the Fort's portal to the Mists, the portal from the heart of the Mists to Mist
## Bastion on its peak in the twilight lands beyond, the road down from the Bastion to the Valleys
## of Mesenlla, the road from the Valleys of Mesenlla down to the coast of Port Vael, and the sea
## crossing from Port Vael to Fontanova, the first island of the archipelago.
## Two views: the Known World, and a sea chart of the Archipelago of the Forgotten Gods off Port Vael's
## coast (Port Vael in its corner, Fontanova the nearest island, the gods' other islands uncharted
## beyond). A sea road off the edge of each leads to the other.
## Each place is a medal you can tap. Places that cannot be played in the mode being chosen for are
## drawn dimmed and cannot be picked.

signal picked(id: String)
signal viewed(view: String)

## Where each place lies on the atlas, as a share of its width and height.
const SPOTS := {"village": Vector2(0.16, 0.7), "fort": Vector2(0.37, 0.82), "mists": Vector2(0.5, 0.42), "mesenlla": Vector2(0.85, 0.78), "bastion": Vector2(0.8, 0.36), "vael": Vector2(0.66, 0.81), "lantern_road": Vector2(0.51, 0.76)}
## And on the sea chart of the Archipelago: Port Vael on the coast in the north-west corner, Fontanova
## the first island out, its beach (where the crossing lands) on its south side.
const SEA_SPOTS := {"vael": Vector2(0.14, 0.2), "fontanova": Vector2(0.44, 0.56)}
const WORLD := "world"
const ARCHIPELAGO := "archipelago"
## The gods' other islands, not yet charted: where they lie, and how big.
const UNCHARTED := [Vector3(0.78, 0.3, 0.07), Vector3(0.9, 0.62, 0.055), Vector3(0.7, 0.84, 0.05), Vector3(0.62, 0.14, 0.035)]
## Roads walk; portals open. Each link is [from, to, through a portal].
const LINKS := [["village", "fort", false], ["fort", "mists", true], ["mists", "bastion", true], ["bastion", "mesenlla", false], ["mesenlla", "vael", false], ["vael", "fontanova", false]]
const MEDAL := 92.0

var allowed: Array = []
var selected := ""
var _t := 0.0
var _medals := {}
var view := WORLD


func _init(can_pick: Array, start := "") -> void:
	allowed = can_pick
	selected = start if start in can_pick else (can_pick[0] if not can_pick.is_empty() else "")
	view = view_of(selected)
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
		label.add_theme_font_size_override("font_size", UiTheme.FS_SMALL)
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
	# The sea road off the edge of each view, to the other.
	var road := Button.new()
	road.name = "SeaRoad"
	road.flat = true
	road.focus_mode = Control.FOCUS_ALL
	road.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	road.add_theme_font_override("font", UiTheme.bold_font())
	road.add_theme_font_size_override("font_size", UiTheme.FS_SMALL)
	road.add_theme_color_override("font_color", UiTheme.BONE)
	road.add_theme_color_override("font_hover_color", UiTheme.EMBER)
	road.add_theme_color_override("font_outline_color", Color(UiTheme.NIGHT, 0.9))
	road.add_theme_constant_override("outline_size", 6)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		road.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	road.pressed.connect(func() -> void:
		Sfx.play("ui_click", -3.0)
		show_view(ARCHIPELAGO if view == WORLD else WORLD))
	add_child(road)
	_road = road
	_place_medals()
	resized.connect(_place_medals)


var _road: Button


## Which view a place is drawn in: Fontanova only on the sea chart, the rest in the Known World.
static func view_of(id: String) -> String:
	return ARCHIPELAGO if id != "" and not SPOTS.has(id) and SEA_SPOTS.has(id) else WORLD


static func spots_of(which: String) -> Dictionary:
	return SEA_SPOTS if which == ARCHIPELAGO else SPOTS


func show_view(which: String) -> void:
	if which == view:
		return
	view = which
	_place_medals()
	viewed.emit(view)


func _place_medals() -> void:
	var here := spots_of(view)
	for id: String in _medals:
		var b: Button = _medals[id]
		b.visible = here.has(id)
		if b.visible:
			b.position = spot(id) - Vector2(b.size.x * 0.5, MEDAL * 0.5)
	if _road:
		# In a corner nothing else is in: the Known World's south-east sea, the chart's north-west coast.
		_road.text = "To the Archipelago" if view == WORLD else "To the Known World"
		_road.size = _road.get_combined_minimum_size()
		_road.position = Vector2(size.x - _road.size.x - 6.0, size.y - _road.size.y - 2.0) if view == WORLD else Vector2(30.0, 4.0)


## Where the sea road's arrow points: at the side of its label.
func _road_tip() -> Vector2:
	if _road == null:
		return Vector2.ZERO
	var mid := _road.position.y + _road.size.y * 0.5
	return Vector2(_road.position.x - 6.0, mid) if view == WORLD else Vector2(_road.position.x - 4.0, mid)


func spot(id: String) -> Vector2:
	return (spots_of(view)[id] as Vector2) * size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	if view == ARCHIPELAGO:
		_archipelago(w, h)
	else:
		_known_world(w, h)
	var here := spots_of(view)
	for link: Array in LINKS:
		if here.has(link[0]) and here.has(link[1]):
			if view == ARCHIPELAGO:
				_crossing(spot(link[0]), spot(link[1]))
			else:
				_link(spot(link[0]), spot(link[1]), link[2])
	_sea_road(w, h)
	for id: String in Places.ORDER:
		if not here.has(id):
			continue
		var c := spot(id)
		if id == selected:
			var pulse := 0.6 + 0.4 * sin(_t * 3.0)
			draw_arc(c, MEDAL * 0.62, 0.0, TAU, 40, Color(UiTheme.EMBER, pulse), 4.0, true)
		elif id in allowed:
			draw_arc(c, MEDAL * 0.56, 0.0, TAU, 40, Color(UiTheme.BONE, 0.25), 2.0, true)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.STEEL, false, 2.0)


func _known_world(w: float, h: float) -> void:
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
	_coast(w, h)
	_mists(w, h)
	_beyond(w, h)


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


## The grey-green coast below the Valleys, with a lighthouse on the breakwater.
func _coast(w: float, h: float) -> void:
	var sea := PackedVector2Array([Vector2(w * 0.46, h), Vector2(w, h)])
	for i in 8:
		var f := i / 8.0
		sea.append(Vector2(lerpf(w, w * 0.46, f), lerpf(h * 0.67, h, f) + sin(f * 7.0) * h * 0.02))
	draw_colored_polygon(sea, Color(0.07, 0.16, 0.18))
	for i in 7:
		var y := h * (0.73 + i * 0.035)
		var x0 := w * (0.95 - i * 0.062)
		var x1 := w * 0.99
		if x1 <= x0:
			continue
		var pts := PackedVector2Array()
		for k in 13:
			var f := k / 12.0
			pts.append(Vector2(lerpf(x0, x1, f), y + sin(f * 12.0 + _t * 1.2 + i) * 2.0))
		draw_polyline(pts, Color(0.5, 0.84, 0.76, 0.18), 1.5, true)
	# The lighthouse on its mole.
	var at := Vector2(w * 0.74, h * 0.91)
	draw_line(at + Vector2(-w * 0.06, 0), at + Vector2(w * 0.02, 0), Color(0.42, 0.42, 0.4), 3.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(-3.5, -22), at + Vector2(3.5, -22), at + Vector2(5, 0)]), Color(0.78, 0.76, 0.7))
	draw_rect(Rect2(at + Vector2(-4, -14), Vector2(8, 3)), Color(0.66, 0.2, 0.16))
	draw_rect(Rect2(at + Vector2(-3, -27), Vector2(6, 5)), Color(0.2, 0.26, 0.28))


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


## The sea road off the edge, toward the other view: a dotted line out to sea and an arrow.
func _sea_road(w: float, h: float) -> void:
	var to := _road_tip()
	var from := spot("vael")
	var bend := Vector2(lerpf(from.x, to.x, 0.3), to.y) if view == WORLD else Vector2(to.x, lerpf(from.y, to.y, 0.5))
	var pts := PackedVector2Array()
	for i in 25:
		var f := i / 24.0
		pts.append(from.lerp(bend, f).lerp(bend.lerp(to, f), f))
	var gone := MEDAL * 0.62
	var dash := 0
	for i in pts.size() - 1:
		if pts[i].distance_to(from) < gone:
			continue
		dash += 1
		if dash % 2 == 0:
			draw_line(pts[i], pts[i + 1], Color(0.62, 0.86, 0.84, 0.75), 2.0, true)
	var dir := (pts[pts.size() - 1] - pts[pts.size() - 3]).normalized()
	var tip := to
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip + dir * 9.0, tip - dir * 6.0 + side * 7.0, tip - dir * 6.0 - side * 7.0]), Color(0.62, 0.86, 0.84, 0.9))


## The crossing on the sea chart: a ship's dotted course from the harbour, round to the island's beach.
func _crossing(a: Vector2, b: Vector2) -> void:
	var land := b + Vector2(0, MEDAL * 0.95) # the beach, on the island's south side
	var bend := Vector2(a.x + (land.x - a.x) * 0.2, land.y + MEDAL * 0.5)
	var pts := PackedVector2Array()
	for i in 41:
		var f := i / 40.0
		pts.append(a.lerp(bend, f).lerp(bend.lerp(land, f), f))
	var shift := fmod(_t * 0.6, 1.0)
	for i in pts.size() - 1:
		if pts[i].distance_to(a) < MEDAL * 0.62:
			continue
		if int(i + shift * 2.0) % 2 == 0:
			draw_line(pts[i], pts[i + 1], Color(0.85, 0.72, 0.45, 0.75), 2.0, true)
	# A sail on the way.
	var k := 0.55 + 0.03 * sin(_t * 0.7)
	var boat := a.lerp(bend, k).lerp(bend.lerp(land, k), k)
	draw_colored_polygon(PackedVector2Array([boat + Vector2(-9, 0), boat + Vector2(9, 0), boat + Vector2(6, 4), boat + Vector2(-6, 4)]), Color(0.36, 0.24, 0.16))
	draw_colored_polygon(PackedVector2Array([boat + Vector2(0, -1), boat + Vector2(0, -16), boat + Vector2(8, -2)]), Color(0.92, 0.86, 0.74))


## The Archipelago of the Forgotten Gods, charted at night: the open sea, Port Vael's coast in its
## corner, Fontanova out on the water, and the other gods' islands, uncharted, on the horizon.
func _archipelago(w: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.1, 0.13))
	_glow(Vector2(w * 0.85, h * 0.4), h * 0.7, Color(0.5, 0.36, 0.7), 0.12) # the gods' twilight to the east
	_glow(Vector2(w * 0.44, h * 0.56), h * 0.32, Color(0.95, 0.75, 0.42), 0.08)
	# The swell.
	for row in 14:
		var y := h * (0.06 + row * 0.07)
		var pts := PackedVector2Array()
		for k in 25:
			var f := k / 24.0
			pts.append(Vector2(w * f, y + sin(f * 14.0 + _t * 0.9 + row * 1.7) * 2.5))
		draw_polyline(pts, Color(0.5, 0.8, 0.82, 0.07), 1.5, true)
	# Port Vael's coast, in the north-west corner, its lighthouse on the mole.
	var coast := PackedVector2Array([Vector2(0, 0), Vector2(w * 0.34, 0)])
	for i in 9:
		var f := i / 8.0
		coast.append(Vector2(lerpf(w * 0.34, 0.0, f), h * (0.04 + 0.34 * f * f) + sin(f * 9.0) * h * 0.02 + h * 0.05 * sin(f * PI)))
	draw_colored_polygon(coast, Color(0.17, 0.22, 0.2))
	draw_polyline(coast.slice(1), Color(0.6, 0.8, 0.72, 0.3), 2.0, true)
	var light := Vector2(w * 0.25, h * 0.2)
	draw_line(light + Vector2(-w * 0.05, 0), light + Vector2(w * 0.01, 0), Color(0.42, 0.42, 0.4), 3.0)
	draw_colored_polygon(PackedVector2Array([light + Vector2(-4, 0), light + Vector2(-3, -18), light + Vector2(3, -18), light + Vector2(4, 0)]), Color(0.78, 0.76, 0.7))
	_glow(light + Vector2(0, -20), 18.0, Color(1.0, 0.85, 0.5), 0.5 + 0.2 * sin(_t * 2.0))
	# Fontanova: its terraced shore, the Acropolis to the north with the temple on it, a beach to the
	# south where the crossing lands.
	var c := spot("fontanova")
	var r := MEDAL * 1.05
	var isle := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var wob := 1.0 + 0.12 * sin(a * 3.0 + 1.0) + 0.07 * sin(a * 7.0)
		isle.append(c + Vector2(cos(a) * r * 1.35, sin(a) * r * 0.95) * wob)
	draw_colored_polygon(isle, Color(0.82, 0.74, 0.55)) # sand at the waterline
	var inner := PackedVector2Array()
	for p in isle:
		inner.append(c + (p - c) * 0.9)
	draw_colored_polygon(inner, Color(0.3, 0.38, 0.24))
	draw_polyline(isle + PackedVector2Array([isle[0]]), Color(0.7, 0.9, 0.86, 0.35), 2.0, true)
	var crag := c + Vector2(r * 0.1, -r * 0.62)
	draw_colored_polygon(PackedVector2Array([crag + Vector2(-r * 0.42, r * 0.12), crag + Vector2(-r * 0.28, -r * 0.14), crag + Vector2(r * 0.3, -r * 0.16), crag + Vector2(r * 0.44, r * 0.12)]), Color(0.42, 0.38, 0.33))
	var top := crag + Vector2(0, -r * 0.15)
	draw_rect(Rect2(top + Vector2(-13, -3), Vector2(26, 3)), Color(0.9, 0.86, 0.76))
	for k in 5:
		draw_rect(Rect2(top + Vector2(-11 + k * 5, -13), Vector2(2, 10)), Color(0.9, 0.86, 0.76))
	draw_colored_polygon(PackedVector2Array([top + Vector2(-14, -13), top + Vector2(0, -20), top + Vector2(14, -13)]), Color(0.9, 0.86, 0.76))
	_glow(top + Vector2(0, -9), 16.0, Color(0.7, 0.45, 1.0), 0.35 + 0.15 * sin(_t * 1.6))
	# The gods' other islands, uncharted: dark shapes in the mist, each with a faint light on it.
	for u: Vector3 in UNCHARTED:
		var at := Vector2(u.x * w, u.y * h)
		var ur := u.z * w
		var shape := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			shape.append(at + Vector2(cos(a) * ur * 1.3, sin(a) * ur * 0.7) * (1.0 + 0.15 * sin(a * 4.0 + u.x * 9.0)))
		draw_colored_polygon(shape, Color(0.13, 0.15, 0.17))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-ur * 0.5, 0), at + Vector2(-ur * 0.1, -ur * 0.7), at + Vector2(ur * 0.4, -ur * 0.2), at + Vector2(ur * 0.6, 0)]), Color(0.17, 0.18, 0.22))
		_glow(at + Vector2(0, -ur * 0.5), ur * 0.6, Color(0.7, 0.5, 1.0), 0.18 + 0.1 * sin(_t * 1.1 + u.y * 7.0))
		var font := UiTheme.bold_font()
		var words := font.get_string_size("Uncharted", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_SMALL - 4)
		draw_string(font, at + Vector2(-words.x * 0.5, ur * 0.75 + 16.0), "Uncharted", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_SMALL - 4, Color(UiTheme.ASH, 0.6))
	# A mist bank on the horizon, where the chart runs out.
	for i in 10:
		var f := i / 10.0
		draw_rect(Rect2(Vector2(w * (0.9 + f * 0.1), 0), Vector2(w * 0.011, h)), Color(0.55, 0.5, 0.7, 0.025 * (i + 1)))
	# North, for the chart.
	var rose := Vector2(w * 0.08, h * 0.88)
	draw_colored_polygon(PackedVector2Array([rose + Vector2(0, -18), rose + Vector2(5, 0), rose + Vector2(0, 18), rose + Vector2(-5, 0)]), Color(UiTheme.BONE, 0.5))
	draw_colored_polygon(PackedVector2Array([rose + Vector2(0, -18), rose + Vector2(5, 0), rose + Vector2(-5, 0)]), Color(UiTheme.EMBER, 0.8))
	draw_string(UiTheme.bold_font(), rose + Vector2(-6, -22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_SMALL - 4, Color(UiTheme.BONE, 0.7))
