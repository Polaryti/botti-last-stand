class_name Icons
## Draws icons: a tinted disc, a hairline ring, a pale shape, and an optional corner badge.
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
		tint = Color(v, v, v).lerp(UiTheme.DUSK, 0.72)
	c.draw_texture_rect(tex("res://assets/ui/medal.png"), r, false, tint)
	var parts := icon.split("+")
	var inset := r.size.x * 0.21
	var shape := Color(UiTheme.ASH, 0.6) if dim else UiTheme.BONE
	var glyph_rect := r.grow(-inset)
	if parts.size() > 1:
		glyph_rect.position -= Vector2(r.size.x * 0.05, r.size.y * 0.05)
	c.draw_texture_rect(glyph(parts[0]), glyph_rect, false, shape)
	if ring:
		c.draw_texture_rect(tex("res://assets/ui/ring.png"), r, false, Color(1, 1, 1, 0.3) if dim else Color(1, 1, 1, 0.75))
	if parts.size() > 1:
		var size := r.size.x * 0.42
		var badge := Rect2(r.end - Vector2.ONE * size * 0.98, Vector2.ONE * size)
		c.draw_circle(badge.get_center(), size * 0.5, UiTheme.NIGHT)
		c.draw_arc(badge.get_center(), size * 0.5, 0.0, TAU, 24, UiTheme.STEEL if dim else UiTheme.EMBER, maxf(1.0, r.size.x * 0.018), true)
		c.draw_texture_rect(glyph(parts[1]), badge.grow(-size * 0.2), false, UiTheme.ASH if dim else UiTheme.EMBER)


static func weapon(id: String) -> String:
	return {"dagger": "dagger", "sword": "sword", "spear": "spear", "mace": "mace", "lance": "lance", "scythe": "scythe",
		"flail": "flail", "bell_hammer": "bell", "pitchfork": "pitchfork", "torch": "torch", "bow": "bow",
		"crossbow": "crossbow", "longbow": "bow+up", "axes": "axe", "javelins": "spear", "fists": "claw", "bo": "staff", "sling": "target", "blowgun": "poison", "staff": "staff", "claws": "claw"}.get(id, "sword")


static func power(id: String) -> String:
	return {"speed": "boot", "sensor": "eye", "fire_arrows": "flame+arrow", "bounce_arrows": "swap+arrow", "angel": "wings",
		"daemon": "tooth", "archer": "bow", "thunder": "bolt", "raven": "feather", "ghost": "ghost", "imp": "grab",
		"bell_spirit": "bell", "rat": "poison"}.get(id, "potion")
