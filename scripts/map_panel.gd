class_name MapPanel
extends Control
## A parchment map of the world, drawn once from the land itself. Only your own position and the
## other players' are shown on it, because what is out there is for you to find.

static var _images := {}

var world: World


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


static func _bake(w: World) -> ImageTexture:
	if _images.has(w.mode):
		return _images[w.mode]
	const SIDE := 240
	var img := Image.create(SIDE, SIDE, false, Image.FORMAT_RGB8)
	var t := w.terrain
	var half := float(Terrain.HALF)
	for y in SIDE:
		for x in SIDE:
			var wx := (x + 0.5) / SIDE * half * 2.0 - half
			var wz := (y + 0.5) / SIDE * half * 2.0 - half
			var h := t.ground_height(wx, wz)
			var col := Color(0.78, 0.68, 0.48).lerp(Color(0.58, 0.46, 0.3), clampf((h + 1.0) / 11.0, 0.0, 1.0))
			if fmod(h + 40.0, 2.0) < 0.14:
				col = col.darkened(0.14)
			if h < Terrain.WATER_Y:
				col = Color(0.34, 0.46, 0.52)
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
					img.set_pixel(px, py, Color(0.42, 0.3, 0.18))
	for r in w.indoors:
		var p0 := Vector2i(int((r.position.x + half) / (half * 2.0) * SIDE), int((r.position.y + half) / (half * 2.0) * SIDE))
		var size := Vector2i(maxi(2, int(r.size.x / (half * 2.0) * SIDE)), maxi(2, int(r.size.y / (half * 2.0) * SIDE)))
		img.fill_rect(Rect2i(p0, size), Color(0.24, 0.17, 0.12))
	if w.fort:
		var wall := Color(0.3, 0.27, 0.27)
		var a := int((float(Terrain.HALF) - Fort.HALF) / (float(Terrain.HALF) * 2.0) * SIDE)
		var b := SIDE - a
		img.fill_rect(Rect2i(a, a, b - a, 3), wall)
		img.fill_rect(Rect2i(a, b - 3, b - a, 3), wall)
		img.fill_rect(Rect2i(a, a, 3, b - a), wall)
		img.fill_rect(Rect2i(b - 3, a, 3, b - a), wall)
	_images[w.mode] = ImageTexture.create_from_image(img)
	return _images[w.mode]


func _to_map(x: float, z: float) -> Vector2:
	return Vector2((x + Terrain.HALF) / (Terrain.HALF * 2.0), (z + Terrain.HALF) / (Terrain.HALF * 2.0)) * size


func _draw() -> void:
	if world == null or not is_instance_valid(world):
		return
	draw_texture_rect(_bake(world), Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.INK, false, 3.0)
	var font := UiTheme.title_font()
	for mark: Dictionary in world.map_marks:
		var at: Vector2 = mark["at"]
		var p := _to_map(at.x, at.y)
		var text: String = mark["name"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, UiTheme.INK)
	for t in world.players:
		if t is Avatar and not t.dead:
			var p := _to_map(t.global_position.x, t.global_position.z)
			draw_circle(p, 6.0, Net.team_colour((t as Avatar).team))
			draw_arc(p, 6.0, 0.0, TAU, 12, UiTheme.INK, 1.5)
	var me := world.player
	if me:
		var p := _to_map(me.global_position.x, me.global_position.z)
		var d := Vector2(-sin(me.yaw), -cos(me.yaw))
		var side := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + d * 11.0, p - d * 6.0 + side * 6.5, p - d * 6.0 - side * 6.5]), Color(0.72, 0.13, 0.09))
