class_name UiTheme
## The iron and parchment look. Textures are nine-patches made by tools/make_ui.py.

const INK := Color(0.16, 0.09, 0.05)
const INK_SOFT := Color(0.33, 0.22, 0.13)
const GOLD := Color(1.0, 0.82, 0.42)
const PALE := Color(0.96, 0.9, 0.76)

static var _title: Font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/MedievalSharp.ttf")
	return _title


static func box(path: String, margin: float, content := 12.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/%s.png" % path)
	s.set_texture_margin_all(margin)
	s.set_content_margin_all(content)
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_stylebox("normal", "Button", box("btn_iron", 14, 14))
	t.set_stylebox("hover", "Button", box("btn_iron", 14, 14))
	t.set_stylebox("pressed", "Button", box("btn_gold", 14, 14))
	t.set_stylebox("disabled", "Button", box("btn_iron_off", 14, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.57, 0.5, 0.7))
	t.set_stylebox("panel", "PanelContainer", box("panel", 26, 26))
	t.set_stylebox("slider", "HSlider", box("btn_iron_off", 12, 6))
	return t


static func wax(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box("btn_wax", 14, 14))
	b.add_theme_stylebox_override("hover", box("btn_wax_hover", 14, 14))
	b.add_theme_stylebox_override("pressed", box("btn_wax_down", 14, 14))
	b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.78))
