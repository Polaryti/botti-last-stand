class_name PlaceVista
extends Control
## A painted view of where a match is about to be played, for the loading screen: the place's sky,
## ridges fading into the distance, and what it is known for (the Village's church and lit windows,
## the Fort's walls, the Mists' islands over nothing, Mesenlla's twilight outpost, Mist Bastion's
## citadel and its turning Great Portal). Drawn from shapes, the same every time for the same place;
## mist drifts and portals glow while the world loads.

var place := "village"
var _t := 0.0
var _ridges: Array[PackedVector2Array] = []
var _stars := PackedVector2Array()
var _built_for := Vector2.ZERO

const LOOKS := {
	"village": {"top": Color(0.04, 0.06, 0.13), "low": Color(0.17, 0.2, 0.33), "far": Color(0.16, 0.19, 0.27), "near": Color(0.06, 0.09, 0.1), "glow": Color(0.95, 0.93, 0.8), "accent": Color(1.0, 0.72, 0.35)},
	"fort": {"top": Color(0.05, 0.05, 0.1), "low": Color(0.32, 0.18, 0.16), "far": Color(0.2, 0.16, 0.2), "near": Color(0.07, 0.07, 0.09), "glow": Color(1.0, 0.6, 0.3), "accent": Color(0.4, 0.9, 0.9)},
	"mists": {"top": Color(0.01, 0.02, 0.06), "low": Color(0.12, 0.08, 0.26), "far": Color(0.12, 0.12, 0.24), "near": Color(0.05, 0.05, 0.1), "glow": Color(0.66, 0.42, 1.0), "accent": Color(0.45, 0.95, 0.92)},
	"mesenlla": {"top": Color(0.11, 0.07, 0.22), "low": Color(0.96, 0.56, 0.34), "far": Color(0.33, 0.22, 0.37), "near": Color(0.12, 0.09, 0.17), "glow": Color(1.0, 0.75, 0.5), "accent": Color(0.45, 0.75, 1.0)},
	"bastion": {"top": Color(0.07, 0.07, 0.19), "low": Color(0.78, 0.52, 0.58), "far": Color(0.27, 0.24, 0.38), "near": Color(0.1, 0.1, 0.17), "glow": Color(0.9, 0.78, 0.86), "accent": Color(0.45, 0.95, 0.92)},
}


func _init(where := "village") -> void:
	place = where if LOOKS.has(where) else "village"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _look(key: String) -> Color:
	return LOOKS[place][key]


## Ridges and stars, made again only when the size changes.
func _plan() -> void:
	_built_for = size
	_ridges.clear()
	var r := RandomNumberGenerator.new()
	r.seed = hash(place)
	_stars = PackedVector2Array()
	for i in 90:
		_stars.append(Vector2(r.randf() * size.x, r.randf() * size.y * 0.55))
	var layers := 0 if place == "mists" else 3
	for k in layers:
		var line := PackedVector2Array()
		var base := size.y * (0.56 + 0.1 * k)
		var tall := size.y * (0.16 - 0.035 * k)
		var f1 := r.randf_range(1.2, 2.2)
		var f2 := r.randf_range(3.0, 5.5)
		var p1 := r.randf() * TAU
		var p2 := r.randf() * TAU
		for i in 97:
			var x := size.x * i / 96.0
			var u := x / size.x
			var h := sin(u * TAU * f1 * 0.5 + p1) * 0.6 + sin(u * TAU * f2 * 0.5 + p2) * 0.25 + r.randf_range(-0.04, 0.04)
			if place in ["mesenlla", "bastion"]:
				h = absf(h) * 1.4 - 0.2 # sharper peaks in the mountains
			line.append(Vector2(x, base - h * tall))
		line.append(Vector2(size.x, size.y))
		line.append(Vector2(0, size.y))
		_ridges.append(line)


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	if _built_for != size:
		_plan()
	var w := size.x
	var h := size.y
	# The sky, from high to the horizon.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.7), Vector2(0, h * 0.7)]),
		PackedColorArray([_look("top"), _look("top"), _look("low"), _look("low")]))
	var deep := _look("top") if place == "mists" else _look("low").lerp(_look("near"), 0.6)
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.7), Vector2(w, h * 0.7), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([_look("low"), _look("low"), deep, deep]))
	for i in _stars.size():
		var twinkle := 0.5 + 0.5 * sin(_t * 1.3 + i * 1.7)
		draw_circle(_stars[i], 1.2 + (i % 3) * 0.4, Color(1, 1, 1, (0.25 if place in ["mesenlla", "bastion"] else 0.5) * twinkle))
	match place:
		"village":
			_glow(Vector2(w * 0.78, h * 0.2), h * 0.16, _look("glow"), 0.35)
			draw_circle(Vector2(w * 0.78, h * 0.2), h * 0.045, _look("glow"))
			draw_circle(Vector2(w * 0.79, h * 0.19), h * 0.012, _look("glow").darkened(0.08))
		"fort":
			_glow(Vector2(w * 0.5, h * 0.62), h * 0.35, _look("glow"), 0.22)
		"mesenlla", "bastion":
			_glow(Vector2(w * 0.3, h * 0.66), h * 0.5, _look("glow"), 0.18)
	# Far ridges first, each one darker and nearer.
	for k in _ridges.size():
		var col := _look("far").lerp(_look("near"), float(k) / maxf(1.0, _ridges.size() - 1.0))
		draw_colored_polygon(_ridges[k], col)
		if k == 0:
			_haze(h * 0.58)
	match place:
		"village": _village(w, h)
		"fort": _fort(w, h)
		"mists": _mists(w, h)
		"mesenlla": _mesenlla(w, h)
		"bastion": _bastion(w, h)
	# Mist drifting across the bottom of the view.
	var mist := _look("accent") if place in ["mists", "mesenlla", "bastion"] else Color(0.7, 0.75, 0.85)
	for i in 6:
		var x := fmod(i * w / 5.0 + _t * (12.0 + i * 3.0), w * 1.3) - w * 0.15
		var y := h * (0.8 + 0.03 * sin(_t * 0.4 + i))
		_glow(Vector2(x, y), h * 0.16, mist, 0.12)


## A soft light: many faint discs, each smaller one adding a little, so no ring shows.
func _glow(at: Vector2, radius: float, col: Color, strength: float) -> void:
	const STEPS := 16
	for i in STEPS:
		var f := 1.0 - float(i) / STEPS
		draw_circle(at, radius * f, Color(col, strength / STEPS * 1.6))


## Haze lying along the far ridge, fading out above and below.
func _haze(y: float) -> void:
	var c := _look("low")
	var top := y - size.y * 0.06
	var bottom := y + size.y * 0.06
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, y), Vector2(0, y)]), PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, 0.14), Color(c, 0.14)]))
	draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, bottom), Vector2(0, bottom)]), PackedColorArray([Color(c, 0.14), Color(c, 0.14), Color(c, 0.0), Color(c, 0.0)]))


## The ground line of the nearest ridge at x.
func _ground(x: float) -> float:
	if _ridges.is_empty():
		return size.y
	var line := _ridges.back() as PackedVector2Array
	var i := clampi(int(x / size.x * 96.0), 0, 95)
	var a := line[i]
	var b := line[i + 1]
	return lerpf(a.y, b.y, clampf((x - a.x) / maxf(0.01, b.x - a.x), 0.0, 1.0))


func _village(w: float, h: float) -> void:
	var dark := _look("near").darkened(0.3)
	var windows := _look("accent")
	for i in 7:
		var x := w * (0.56 + i * 0.065)
		var g := _ground(x)
		var hw := h * (0.045 + 0.01 * (i % 3))
		var tall := h * 0.06
		draw_colored_polygon(PackedVector2Array([Vector2(x - hw, g + 4), Vector2(x - hw, g - tall), Vector2(x, g - tall - hw * 0.9), Vector2(x + hw, g - tall), Vector2(x + hw, g + 4)]), dark)
		var lit := 0.6 + 0.4 * sin(_t * 2.0 + i * 2.1)
		draw_rect(Rect2(x - hw * 0.35, g - tall * 0.7, hw * 0.3, tall * 0.35), Color(windows, lit))
	# The church, its spire and its bell.
	var cx := w * 0.5
	var cg := _ground(cx)
	draw_rect(Rect2(cx - h * 0.045, cg - h * 0.18, h * 0.09, h * 0.2), dark)
	draw_rect(Rect2(cx - h * 0.045, cg - h * 0.08, h * 0.2, h * 0.1), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - h * 0.055, cg - h * 0.18), Vector2(cx, cg - h * 0.34), Vector2(cx + h * 0.055, cg - h * 0.18)]), dark)
	draw_circle(Vector2(cx, cg - h * 0.13), h * 0.016, Color(windows, 0.8))


func _fort(w: float, h: float) -> void:
	var dark := _look("near").darkened(0.35)
	var g := _ground(w * 0.5)
	var left := w * 0.32
	var right := w * 0.68
	var top := g - h * 0.12
	draw_rect(Rect2(left, top, right - left, h * 0.14), dark)
	var x := left
	while x < right:
		draw_rect(Rect2(x, top - h * 0.018, h * 0.02, h * 0.02), dark)
		x += h * 0.04
	for tx: float in [left, right]:
		draw_rect(Rect2(tx - h * 0.035, top - h * 0.06, h * 0.07, h * 0.2), dark)
	# The portal glowing over the walls from inside.
	var pulse := 0.7 + 0.3 * sin(_t * 2.0)
	_glow(Vector2(w * 0.5, top - h * 0.02), h * 0.08, _look("accent"), 0.5 * pulse)
	draw_arc(Vector2(w * 0.5, top - h * 0.02), h * 0.035, 0.0, TAU, 32, Color(_look("accent"), 0.9), 3.0, true)
	# Torches along the wall.
	for i in 5:
		var fx := lerpf(left + h * 0.05, right - h * 0.05, i / 4.0)
		draw_circle(Vector2(fx, top + h * 0.03), h * (0.006 + 0.002 * sin(_t * 9.0 + i)), _look("glow"))


func _island(at: Vector2, width: float, col: Color, glint: Color) -> void:
	var bob := sin(_t * 0.8 + at.x * 0.01) * width * 0.03
	var p := at + Vector2(0, bob)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-width * 0.5, 0), p + Vector2(width * 0.5, 0), p + Vector2(width * 0.2, width * 0.35), p + Vector2(0, width * 0.7), p + Vector2(-width * 0.25, width * 0.3)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-width * 0.5, 0), p + Vector2(-width * 0.3, -width * 0.06), p + Vector2(width * 0.35, -width * 0.05), p + Vector2(width * 0.5, 0)]), col.lightened(0.15))
	for k in 3:
		var tx := p.x - width * 0.25 + k * width * 0.22
		draw_colored_polygon(PackedVector2Array([Vector2(tx - width * 0.05, p.y - width * 0.04), Vector2(tx, p.y - width * 0.2), Vector2(tx + width * 0.05, p.y - width * 0.04)]), col.lightened(0.05))
	_glow(p + Vector2(0, width * 0.7), width * 0.18, glint, 0.6)


func _mists(w: float, h: float) -> void:
	var rock := Color(0.14, 0.13, 0.22)
	for spec: Vector3 in [Vector3(0.18, 0.5, 0.16), Vector3(0.5, 0.42, 0.24), Vector3(0.8, 0.55, 0.15), Vector3(0.36, 0.72, 0.1), Vector3(0.66, 0.74, 0.11)]:
		_island(Vector2(w * spec.x, h * spec.y), w * spec.z, rock, _look("accent"))
	# A portal on the middle island.
	var c := Vector2(w * 0.5, h * 0.42 - w * 0.06)
	draw_arc(c, w * 0.022, 0.0, TAU, 32, Color(_look("glow"), 0.6 + 0.4 * sin(_t * 2.0)), 3.0, true)


func _mesenlla(w: float, h: float) -> void:
	var rock := _look("far").darkened(0.25)
	_island(Vector2(w * 0.68, h * 0.2), w * 0.11, rock, _look("accent"))
	_island(Vector2(w * 0.88, h * 0.32), w * 0.07, rock, _look("accent"))
	_island(Vector2(w * 0.46, h * 0.12), w * 0.05, rock, _look("accent"))
	# The outpost on its shoulder: a palisade, two watchtowers, lit lodges, and the Great Portal.
	var dark := _look("near").darkened(0.35)
	var cx := w * 0.7
	var g := _ground(cx)
	var left := cx - w * 0.1
	var right := cx + w * 0.1
	var x := left
	while x < right:
		draw_colored_polygon(PackedVector2Array([Vector2(x, g + 4), Vector2(x, g - h * 0.035), Vector2(x + w * 0.004, g - h * 0.045), Vector2(x + w * 0.008, g - h * 0.035), Vector2(x + w * 0.008, g + 4)]), dark)
		x += w * 0.009
	for tx: float in [left + w * 0.01, right - w * 0.01]:
		draw_rect(Rect2(tx - w * 0.008, g - h * 0.1, w * 0.016, h * 0.1), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - w * 0.013, g - h * 0.1), Vector2(tx, g - h * 0.13), Vector2(tx + w * 0.013, g - h * 0.1)]), dark)
		draw_circle(Vector2(tx, g - h * 0.085), h * 0.005, Color(_look("glow"), 0.9))
	var pulse := 0.75 + 0.25 * sin(_t * 1.8)
	_glow(Vector2(cx, g - h * 0.07), h * 0.07, _look("accent"), 0.5 * pulse)
	draw_rect(Rect2(cx - w * 0.018, g - h * 0.1, w * 0.006, h * 0.1), dark)
	draw_rect(Rect2(cx + w * 0.012, g - h * 0.1, w * 0.006, h * 0.1), dark)
	draw_rect(Rect2(cx - w * 0.02, g - h * 0.108, w * 0.04, h * 0.01), dark)
	draw_rect(Rect2(cx - w * 0.012, g - h * 0.097, w * 0.024, h * 0.095), Color(_look("accent"), 0.55 * pulse))


func _bastion(w: float, h: float) -> void:
	var rock := _look("far").darkened(0.25)
	_island(Vector2(w * 0.2, h * 0.2), w * 0.08, rock, _look("accent"))
	_island(Vector2(w * 0.86, h * 0.26), w * 0.1, rock, _look("accent"))
	# The peak, and the citadel on it.
	var dark := _look("near").darkened(0.2)
	var px := w * 0.6
	var peak := h * 0.36
	draw_colored_polygon(PackedVector2Array([Vector2(px - w * 0.3, h), Vector2(px - w * 0.08, peak + h * 0.06), Vector2(px + w * 0.08, peak + h * 0.06), Vector2(px + w * 0.3, h)]), dark)
	# Three lanes climbing to it.
	var lane := Color(_look("glow"), 0.22)
	for k: float in [-1.0, 0.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			var y := lerpf(h, peak + h * 0.07, f)
			var x := px + k * lerpf(w * 0.22, w * 0.05, f) + sin(f * 9.0 + k) * w * 0.012 * (1.0 - f)
			pts.append(Vector2(x, y))
		draw_polyline(pts, lane, 3.0, true)
	var walls := _look("near").darkened(0.45)
	var top := peak + h * 0.02
	draw_rect(Rect2(px - w * 0.07, top, w * 0.14, h * 0.05), walls)
	for tx: float in [px - w * 0.07, px + w * 0.07]:
		draw_rect(Rect2(tx - w * 0.009, top - h * 0.03, w * 0.018, h * 0.08), walls)
		draw_line(Vector2(tx - w * 0.009, top - h * 0.018), Vector2(tx + w * 0.009, top - h * 0.018), Color(_look("accent"), 0.9), 2.0)
	draw_line(Vector2(px - w * 0.07, top + h * 0.012), Vector2(px + w * 0.07, top + h * 0.012), Color(_look("accent"), 0.7), 2.0)
	# The Great Portal: a ring turning above the walls.
	var c := Vector2(px, top - h * 0.05)
	var r := h * 0.045
	var pulse := 0.75 + 0.25 * sin(_t * 1.6)
	_glow(c, r * 2.2, _look("accent"), 0.5 * pulse)
	draw_circle(c, r * 0.85, Color(0.35, 0.7, 1.0, 0.55 * pulse))
	for i in 12:
		var a := _t * 0.4 + TAU * i / 12.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r, r * 0.16, walls.lightened(0.25))
		draw_circle(c + Vector2(cos(a), sin(a)) * r, r * 0.05, _look("accent"))
	# A pillar of mist rising from it.
	draw_rect(Rect2(c.x - r * 0.15, 0, r * 0.3, c.y - r), Color(_look("accent"), 0.06 + 0.03 * pulse))
