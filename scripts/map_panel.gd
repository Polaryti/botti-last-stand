class_name MapPanel
extends Control
## A moonlit map of the world, drawn once from the land itself. Only your own position and the
## other players' are shown on it, because what is out there is for you to find.

static var _images := {}
var _t := 0.0

signal selected(at: Vector3)
var targeting := false
var selected_spot := Vector3.ZERO
var target_radius := CommanderKit.BARRAGE_RADIUS

var world: World


func _ready() -> void:
	set_process(true)
	clip_contents = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## How each land is drawn: low and high ground, contour lines, water and roads. The lands beyond the
## Mists are drawn in their twilight.
const PALETTES := {
	"default": {"low": Color(0.11, 0.17, 0.17), "high": Color(0.22, 0.28, 0.26), "water": Color(0.2, 0.36, 0.5), "road": Color(0.6, 0.52, 0.38), "void": Color(0.06, 0.04, 0.12)},
	"twilight": {"low": Color(0.15, 0.13, 0.22), "high": Color(0.46, 0.36, 0.48), "water": Color(0.32, 0.42, 0.66), "road": Color(0.86, 0.62, 0.4), "void": Color(0.06, 0.04, 0.12)},
}
const SIDE := 240


static func _bake(w: World) -> ImageTexture:
	var key := "%s %d %s" % [w.map_id, w.mode, w.terrain.half_extent]
	if _images.has(key):
		return _images[key]
	var img := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	var t := w.terrain
	var half := float(t.half_extent)
	var twilight := w.map_id in SpawnRules.MESENLLA
	var pal: Dictionary = PALETTES["twilight" if twilight else "default"]
	# The Village and the Fort are low; the mountains beyond the Mists are drawn over their own range.
	var lowest := -1.0
	var span := 11.0 if not t.has_islands() else 48.0
	if twilight:
		lowest = INF
		var highest := -INF
		for y in range(0, SIDE, 4):
			for x in range(0, SIDE, 4):
				var hh := t.ground_height((x + 0.5) / SIDE * half * 2.0 - half, (y + 0.5) / SIDE * half * 2.0 - half)
				lowest = minf(lowest, hh)
				highest = maxf(highest, hh)
		span = maxf(1.0, highest - lowest)
	var contour := 4.0 if twilight else 2.0
	for y in SIDE:
		for x in SIDE:
			var wx := (x + 0.5) / SIDE * half * 2.0 - half
			var wz := (y + 0.5) / SIDE * half * 2.0 - half
			var h := t.ground_height(wx, wz)
			var col: Color = (pal["low"] as Color).lerp(pal["high"], clampf((h - lowest) / span, 0.0, 1.0))
			if fmod(h + 40.0, contour) < 0.14 * contour * 0.5:
				col = col.lightened(0.09)
			if t.has_islands() and h < 0.0:
				col = pal["void"]
			elif h < Terrain.WATER_Y and _by_river(t, wx, wz):
				col = pal["water"]
			elif t.slope(wx, wz) > Terrain.STEEP or not t.is_walkable(wx, wz):
				col = col.darkened(0.3)
			img.set_pixel(x, y, col)
	for road: Array in w.map_roads:
		for i in road.size() - 1:
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			var steps := int(a.distance_to(b))
			for s in steps + 1:
				var p := a.lerp(b, float(s) / maxf(steps, 1.0))
				var px := int((p.x + half) / (half * 2.0) * SIDE)
				var py := int((p.y + half) / (half * 2.0) * SIDE)
				if px >= 0 and py >= 0 and px < SIDE and py < SIDE:
					img.set_pixel(px, py, pal["road"])
	for r in w.indoors:
		var p0 := Vector2i(int((r.position.x + half) / (half * 2.0) * SIDE), int((r.position.y + half) / (half * 2.0) * SIDE))
		var size := Vector2i(maxi(2, int(r.size.x / (half * 2.0) * SIDE)), maxi(2, int(r.size.y / (half * 2.0) * SIDE)))
		img.fill_rect(Rect2i(p0, size), UiTheme.BONE.darkened(0.15))
	if w.fort and w.fort.region.is_empty():
		var wall := UiTheme.ASH
		var a := int((half - Fort.HALF) / (half * 2.0) * SIDE)
		var b := SIDE - a
		img.fill_rect(Rect2i(a, a, b - a, 3), wall)
		img.fill_rect(Rect2i(a, b - 3, b - a, 3), wall)
		img.fill_rect(Rect2i(a, a, 3, b - a), wall)
		img.fill_rect(Rect2i(b - 3, a, 3, b - a), wall)
	elif w.fort:
		# A stronghold of its own shape: its outline, drawn a pixel at a time along each wall.
		var outline := w.fort.region
		for i in outline.size():
			_line(img, half, outline[i], outline[(i + 1) % outline.size()], UiTheme.ASH, 1)
	for f: Dictionary in w.map_features:
		if f["kind"] == "spine":
			var along: Vector2 = f["dir"] * float(f["size"]) * 0.5
			_line(img, half, f["at"] - along, f["at"] + along, Color(0.09, 0.08, 0.12), 1)
	_images[key] = ImageTexture.create_from_image(img)
	return _images[key]


## Water is only drawn where the river's water lies: low ground elsewhere is just a hollow.
static func _by_river(t: Terrain, x: float, z: float) -> bool:
	var at := Vector2(x, z)
	var reach := t.river_width + Terrain.BANK * 0.5
	for i in t.river.size() - 1:
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, t.river[i], t.river[i + 1])) <= reach:
			return true
	return false


## A line of square dots on the baked map, thick pixels to each side.
static func _line(img: Image, half: float, from: Vector2, to: Vector2, col: Color, thick: int) -> void:
	var steps := maxi(1, int(from.distance_to(to)))
	for k in steps + 1:
		var p := from.lerp(to, float(k) / steps)
		var px := int((p.x + half) / (half * 2.0) * SIDE)
		var py := int((p.y + half) / (half * 2.0) * SIDE)
		img.fill_rect(Rect2i(px - thick, py - thick, thick * 2 + 1, thick * 2 + 1).intersection(Rect2i(0, 0, SIDE, SIDE)), col)


func _to_map(x: float, z: float) -> Vector2:
	return Vector2((x + world.terrain.half_extent) / (world.terrain.half_extent * 2.0), (z + world.terrain.half_extent) / (world.terrain.half_extent * 2.0)) * size


func _draw() -> void:
	if world == null or not is_instance_valid(world):
		return
	draw_texture_rect(_bake(world), Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.STEEL, false, 2.0)
	if targeting:
		var point := _to_map(selected_spot.x, selected_spot.z)
		var radius := target_radius / (world.terrain.half_extent * 2.0) * size.x
		draw_circle(point, radius, Color(1.0, 0.5, 0.15, 0.2))
		draw_arc(point, radius, 0.0, TAU, 48, UiTheme.EMBER, 3.0, true)
	_draw_features()
	_draw_stronghold()
	var font := UiTheme.bold_font()
	for mark: Dictionary in world.map_marks:
		if mark["name"] == "boss":
			continue # where a boss rises is for the director to know, not the players
		var at: Vector2 = mark["at"]
		var p := _to_map(at.x, at.y)
		var text: String = mark["name"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var label_at := Vector2(clampf(p.x - w * 0.5, 4.0, maxf(4.0, size.x - w - 4.0)), clampf(p.y + float(mark.get("label_offset", 0.0)), 20.0, size.y - 4.0))
		draw_string_outline(font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 4, Color(UiTheme.NIGHT, 0.8))
		draw_string(font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, UiTheme.BONE)
	if world.mist_storm:
		var storm := world.mist_storm
		var affected: Array[int] = []
		if storm.finale:
			for index in range(1, MapIslands.ISLANDS.size()): affected.append(index)
		else: affected.append(storm.island)
		for index in affected:
			var land := MapIslands.ISLANDS[index]
			var centre := _to_map(land.x, land.y)
			var radius := land.z / (world.terrain.half_extent * 2.0) * size.x
			draw_circle(centre, radius, Color(0.65, 0.3, 0.9, 0.3))
			draw_arc(centre, radius, 0, TAU, 48, Color(0.85, 0.55, 1), 3)
			if not storm.finale:
				var text_width := font.get_string_size("MIST STORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				var label_at := Vector2(clampf(centre.x - text_width * 0.5, 4, maxf(4, size.x - text_width - 4)), clampf(centre.y + 24, 20, size.y - 4))
				draw_string(font, label_at, "MIST STORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.7, 1))
		if storm.finale:
			draw_string(font, Vector2(12, 24), "MIST STORMS: ALL OUTER ISLANDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.7, 1))
	if world.portals:
		for link: Dictionary in world.portals.links:
			if link["open"]:
				var pa := _to_map((link["a"] as Vector3).x, (link["a"] as Vector3).z)
				var pb := _to_map((link["b"] as Vector3).x, (link["b"] as Vector3).z)
				draw_line(pa, pb, Color(0.66, 0.42, 1.0, 0.35), 2.0)
				draw_circle(pa, 4.0, Color(0.66, 0.42, 1.0))
				draw_circle(pb, 4.0, Color(0.66, 0.42, 1.0))
	if world.fog:
		var c := _to_map(world.fog.centre.x, world.fog.centre.y)
		var r := world.fog.radius / (world.terrain.half_extent * 2.0) * size.x
		draw_arc(c, r, 0.0, TAU, 72, Color(UiTheme.MIST, 0.9), 3.0, true)
	for t in world.players:
		if t is Avatar and not t.dead and not Net.is_foe((t as Avatar).peer):
			var p := _to_map(t.global_position.x, t.global_position.z)
			draw_circle(p, 6.0, Net.team_colour((t as Avatar).team))
			draw_arc(p, 6.0, 0.0, TAU, 12, UiTheme.BONE, 1.5)
	var me := world.player
	if me:
		var p := _to_map(me.global_position.x, me.global_position.z)
		var d := Vector2(-sin(me.yaw), -cos(me.yaw))
		var side := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + d * 12.0, p - d * 6.0 + side * 7.0, p - d * 6.0 - side * 7.0]), UiTheme.EMBER)


## Landmarks beyond the land: islands hanging overhead (their shadow and a dashed edge), glowing
## rifts, rings of standing stones, portals and waystones.
func _draw_features() -> void:
	var scale := size.x / (world.terrain.half_extent * 2.0)
	var pulse := 0.75 + 0.25 * sin(_t * 2.2)
	for f: Dictionary in world.map_features:
		var at: Vector2 = f["at"]
		var p := _to_map(at.x, at.y)
		var s := float(f["size"]) * scale
		match f["kind"]:
			"island":
				draw_circle(p, s * 0.55, Color(0.05, 0.03, 0.1, 0.32))
				for i in 12:
					var a0 := TAU * i / 12.0 + _t * 0.08
					draw_arc(p, s * 0.55, a0, a0 + TAU / 24.0, 3, Color(0.75, 0.68, 0.9, 0.55), 1.5, true)
				draw_circle(p, 2.0, Color(0.45, 0.95, 0.92, pulse))
			"rift":
				var along: Vector2 = f["dir"] * s * 0.5
				draw_line(p - along, p + along, Color(0.62, 0.42, 1.0, 0.35), 6.0, true)
				draw_line(p - along, p + along, Color(0.82, 0.66, 1.0, pulse), 2.0, true)
			"stones":
				draw_arc(p, s, 0.0, TAU, 24, Color(0.55, 1.0, 0.92, 0.8), 2.0, true)
				for i in 8:
					var a := TAU * i / 8.0
					draw_circle(p + Vector2(cos(a), sin(a)) * s, 2.2, UiTheme.BONE)
			"portal", "great_portal":
				draw_circle(p, 7.0, Color(0.35, 0.65, 1.0, 0.25 * pulse))
				draw_arc(p, 5.0, 0.0, TAU, 20, Color(0.55, 0.85, 1.0), 2.5, true)
			"waystone":
				draw_circle(p, 3.0, Color(0.45, 0.95, 0.92, pulse))


## A stronghold's gates, coloured by how they stand (open gates in red), and its heart or portal.
func _draw_stronghold() -> void:
	var fort := world.fort
	if fort == null:
		return
	var font := UiTheme.bold_font()
	for g: Dictionary in fort.gates:
		var at: Vector3 = g["at"]
		var p := _to_map(at.x, at.z)
		var col := Color(0.72, 0.5, 0.26)
		if not g["closed"]:
			col = Color(1.0, 0.3, 0.22)
		elif float(g["hp"]) < Fort.GATE_HP:
			col = Color(0.95, 0.65, 0.25)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), UiTheme.NIGHT, false, 1.5)
		var out: Vector3 = g["dir"]
		var label_at := p + Vector2(out.x, out.z) * 14.0 + Vector2(-5, 6)
		draw_string_outline(font, label_at, str(g["short"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, 4, Color(UiTheme.NIGHT, 0.8))
		draw_string(font, label_at, str(g["short"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, col)
	var heart := _to_map(fort.heart_at.x, fort.heart_at.z)
	var share := clampf(fort.heart_hp / Fort.HEART_HP, 0.0, 1.0)
	draw_arc(heart, 9.0, -PI * 0.5, -PI * 0.5 + TAU * share, 32, Color(0.9, 0.3, 0.24) if share < 0.35 else UiTheme.MIST, 3.0, true)


func _gui_input(event: InputEvent) -> void:
	if not targeting:
		return
	var at := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		at = event.position
	else:
		return
	selected_spot = Vector3((at.x / size.x * 2.0 - 1.0) * world.terrain.half_extent, 0, (at.y / size.y * 2.0 - 1.0) * world.terrain.half_extent)
	selected_spot.y = world.ground_at(selected_spot)
	selected.emit(selected_spot)
	accept_event()
	queue_redraw()
