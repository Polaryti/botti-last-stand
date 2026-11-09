class_name MapPanel
extends Control
## A moonlit map of the world, drawn once from the land itself. Only your own position and the
## other players' are shown on it, because what is out there is for you to find.

static var _images := {}

signal selected(at: Vector3)
var targeting := false
var selected_spot := Vector3.ZERO
var target_radius := CommanderKit.BARRAGE_RADIUS

var world: World


func _ready() -> void:
	set_process(true)
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


static func _bake(w: World) -> ImageTexture:
	var key := "%d %s" % [w.mode, w.terrain.half_extent]
	if _images.has(key):
		return _images[key]
	const SIDE := 240
	var img := Image.create(SIDE, SIDE, false, Image.FORMAT_RGB8)
	var t := w.terrain
	var half := float(t.half_extent)
	for y in SIDE:
		for x in SIDE:
			var wx := (x + 0.5) / SIDE * half * 2.0 - half
			var wz := (y + 0.5) / SIDE * half * 2.0 - half
			var h := t.ground_height(wx, wz)
			var col := Color(0.11, 0.17, 0.17).lerp(Color(0.22, 0.28, 0.26), clampf((h + 1.0) / (11.0 if not t.has_islands() else 48.0), 0.0, 1.0))
			if fmod(h + 40.0, 2.0) < 0.14:
				col = col.lightened(0.09)
			if t.has_islands() and h < 0.0:
				col = Color(0.06, 0.04, 0.12)
			elif h < Terrain.WATER_Y:
				col = Color(0.2, 0.36, 0.5)
			elif t.slope(wx, wz) > Terrain.STEEP:
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
					img.set_pixel(px, py, Color(0.6, 0.52, 0.38))
	for r in w.indoors:
		var p0 := Vector2i(int((r.position.x + half) / (half * 2.0) * SIDE), int((r.position.y + half) / (half * 2.0) * SIDE))
		var size := Vector2i(maxi(2, int(r.size.x / (half * 2.0) * SIDE)), maxi(2, int(r.size.y / (half * 2.0) * SIDE)))
		img.fill_rect(Rect2i(p0, size), UiTheme.BONE.darkened(0.15))
	if w.fort:
		var wall := UiTheme.ASH
		var a := int((half - Fort.HALF) / (half * 2.0) * SIDE)
		var b := SIDE - a
		img.fill_rect(Rect2i(a, a, b - a, 3), wall)
		img.fill_rect(Rect2i(a, b - 3, b - a, 3), wall)
		img.fill_rect(Rect2i(a, a, 3, b - a), wall)
		img.fill_rect(Rect2i(b - 3, a, 3, b - a), wall)
	_images[key] = ImageTexture.create_from_image(img)
	return _images[key]


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
	var font := UiTheme.bold_font()
	for mark: Dictionary in world.map_marks:
		var at: Vector2 = mark["at"]
		var p := _to_map(at.x, at.y)
		var text: String = mark["name"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var label_at := Vector2(clampf(p.x - w * 0.5, 4.0, maxf(4.0, size.x - w - 4.0)), clampf(p.y, 20.0, size.y - 4.0))
		draw_string_outline(font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 4, Color(UiTheme.NIGHT, 0.8))
		draw_string(font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, UiTheme.BONE)
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
