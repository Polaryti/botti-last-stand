class_name Icons
## Draws medallion icons: a tinted disc, an iron ring, a white shape, and an optional corner badge.
## Icon strings look like "sword" or "sword+flame".

static var _tex := {}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


static func glyph(name: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % name)


static func exists(name: String) -> bool:
	return ResourceLoader.exists("res://assets/icons/%s.png" % name)


static func draw(c: CanvasItem, r: Rect2, icon: String, col: Color, dim := false, ring := true) -> void:
	var tint := col
	if dim:
		var v := col.get_luminance()
		tint = Color(v, v, v).lerp(Color(0.12, 0.12, 0.13), 0.65)
	c.draw_texture_rect(tex("res://assets/ui/medal.png"), r, false, tint)
	var parts := icon.split("+")
	var inset := r.size.x * 0.21
	var shape := Color(0.42, 0.42, 0.42) if dim else Color(1, 0.98, 0.9)
	var glyph_rect := r.grow(-inset)
	if parts.size() > 1:
		glyph_rect.position -= Vector2(r.size.x * 0.05, r.size.y * 0.05)
	c.draw_texture_rect(glyph(parts[0]), glyph_rect, false, Color(0, 0, 0, 0.45), false)
	c.draw_texture_rect(glyph(parts[0]), Rect2(glyph_rect.position - Vector2.ONE * 1.5, glyph_rect.size), false, shape)
	if ring:
		c.draw_texture_rect(tex("res://assets/ui/ring.png"), r, false, Color(0.55, 0.55, 0.55) if dim else Color.WHITE)
	if parts.size() > 1:
		var size := r.size.x * 0.42
		var badge := Rect2(r.end - Vector2.ONE * size * 0.98, Vector2.ONE * size)
		c.draw_circle(badge.get_center(), size * 0.5, Color(0.08, 0.06, 0.05, 0.98))
		c.draw_arc(badge.get_center(), size * 0.5, 0.0, TAU, 24, Color(0.72, 0.6, 0.3) if not dim else Color(0.36, 0.36, 0.36), maxf(1.0, r.size.x * 0.02))
		c.draw_texture_rect(glyph(parts[1]), badge.grow(-size * 0.2), false, Color(1, 0.84, 0.46) if not dim else Color(0.5, 0.5, 0.5))


static func weapon(id: String) -> String:
	return {"dagger": "dagger", "sword": "sword", "spear": "spear", "mace": "mace", "lance": "lance", "scythe": "scythe",
		"flail": "flail", "bell_hammer": "bell", "pitchfork": "pitchfork", "torch": "torch", "bow": "bow",
		"crossbow": "crossbow", "longbow": "bow+up", "axes": "axe", "staff": "staff", "claws": "claw"}.get(id, "sword")


static func power(id: String) -> String:
	return {"speed": "boot", "sensor": "eye", "fire_arrows": "flame+arrow", "bounce_arrows": "swap+arrow", "angel": "wings",
		"daemon": "tooth", "archer": "bow", "thunder": "bolt", "raven": "feather", "ghost": "ghost", "imp": "grab",
		"bell_spirit": "bell", "rat": "poison"}.get(id, "potion")
