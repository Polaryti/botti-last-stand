class_name Icons
## Draws icons: a tinted disc, a hairline ring, a pale shape, and an optional corner badge.
## Icon strings look like "sword" or "sword+flame".

static var _tex := {}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


static func glyph(name: String) -> Texture2D:
	var vector := "res://assets/icons/%s.svg" % name
	return tex(vector if ResourceLoader.exists(vector) else "res://assets/icons/%s.png" % name)


static func exists(name: String) -> bool:
	return ResourceLoader.exists("res://assets/icons/%s.png" % name) or ResourceLoader.exists("res://assets/icons/%s.svg" % name)


## Crests and specialization emblems have their own outline. Everything else sits on a dark disc,
## ringed in the colour of its class.
static func draw(c: CanvasItem, r: Rect2, icon: String, col: Color, dim := false, ring := true) -> void:
	var parts := icon.split("+")
	var own_outline := parts[0].begins_with("crest_") or parts[0].begins_with("spec_")
	var shade := Color(0.56, 0.56, 0.6, 0.92) if dim else Color.WHITE
	if own_outline:
		c.draw_texture_rect(glyph(parts[0]), r, false, shade)
	else:
		var disc := Color(0.1, 0.11, 0.16).lerp(col, 0.22)
		c.draw_circle(r.get_center(), r.size.x * 0.49, disc.darkened(0.25) if dim else disc)
		var inset := r.size.x * 0.14
		var glyph_rect := r.grow(-inset)
		if parts.size() > 1:
			glyph_rect.position -= Vector2(r.size.x * 0.06, r.size.y * 0.06)
		c.draw_texture_rect(glyph(parts[0]), glyph_rect, false, shade)
		if ring:
			c.draw_arc(r.get_center(), r.size.x * 0.48, 0.0, TAU, 40, col.darkened(0.45) if dim else col.lightened(0.15), maxf(1.5, r.size.x * 0.035), true)
	if parts.size() > 1:
		var size := r.size.x * 0.46
		var badge := Rect2(r.end - Vector2.ONE * size * 0.98, Vector2.ONE * size)
		c.draw_circle(badge.get_center(), size * 0.5, UiTheme.NIGHT)
		c.draw_arc(badge.get_center(), size * 0.5, 0.0, TAU, 24, UiTheme.STEEL if dim else UiTheme.EMBER, maxf(1.0, r.size.x * 0.02), true)
		c.draw_texture_rect(glyph(parts[1]), badge.grow(-size * 0.12), false, shade)


static func weapon(id: String) -> String:
	return {"dagger": "dagger", "sword": "sword", "spear": "spear", "mace": "mace", "lance": "lance", "scythe": "scythe",
		"flail": "flail", "bell_hammer": "bell_hammer", "pitchfork": "pitchfork", "torch": "torch", "bow": "bow",
		"crossbow": "crossbow", "longbow": "longbow", "axes": "axe", "javelins": "javelins", "fists": "hand", "bo": "bo",
		"blowgun": "blowgun", "war_staff": "staff", "musket": "crossbow", "staff": "staff", "claws": "claw"}.get(id, "sword")


static func power(id: String) -> String:
	return {"speed": "boot", "sensor": "eye", "fire_arrows": "flame+arrow", "bounce_arrows": "swap+arrow", "angel": "wings",
		"daemon": "tooth", "archer": "bow", "thunder": "bolt", "raven": "raven", "ghost": "ghost", "imp": "grab",
		"bell_spirit": "bell", "rat": "rat"}.get(id, "potion")
