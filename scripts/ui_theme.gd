class_name UiTheme
## The look of the game: moonlit slate panels, bone-coloured text, and one warm accent, the colour
## of firelight. Everything is flat colour, so it stays sharp on any screen.

const NIGHT := Color("121824") # panels
const DUSK := Color("1c2433") # things that sit on a panel
const STEEL := Color("39455a") # lines
const BONE := Color("efe8d8") # text
const ASH := Color("a9b0bd") # quieter text
const EMBER := Color("efa93f") # what matters most on a screen
const COAL := Color("1b1408") # text on ember
const BLOOD := Color("c8432f") # danger
const MIST := Color("6fb6d6") # mana and mist
const MOSS := Color("7fc08a") # safe

static var _title: Font
static var _bold: Font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/Cinzel-Bold.ttf")
	return _title


static func bold_font() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/FiraSans-Bold.ttf")
	return _bold


static func flat(bg: Color, border := Color.TRANSPARENT, radius := 8, pad := 14.0, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing_size = 0.8
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/FiraSans-Medium.ttf")
	t.default_font_size = 26
	t.set_font("font", "Button", bold_font())
	t.set_stylebox("normal", "Button", flat(Color(DUSK, 0.94), STEEL))
	t.set_stylebox("hover", "Button", flat(Color(DUSK, 0.94), STEEL))
	t.set_stylebox("pressed", "Button", flat(Color(EMBER, 0.24), EMBER))
	t.set_stylebox("disabled", "Button", flat(Color(DUSK, 0.5), Color(STEEL, 0.5)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", BONE)
	t.set_color("font_hover_color", "Button", BONE)
	t.set_color("font_pressed_color", "Button", BONE)
	t.set_color("font_focus_color", "Button", BONE)
	t.set_color("font_hover_pressed_color", "Button", BONE)
	t.set_color("font_disabled_color", "Button", Color(ASH, 0.55))
	t.set_color("font_color", "Label", BONE)
	var panel := flat(Color(NIGHT, 0.96), STEEL, 12, 26.0)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 24
	t.set_stylebox("panel", "PanelContainer", panel)
	# A slider is a line and a knob. The whole height of the control still takes a thumb.
	var track := flat(STEEL, Color.TRANSPARENT, 4, 0.0)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	t.set_stylebox("slider", "HSlider", track)
	var filled := flat(EMBER, Color.TRANSPARENT, 4, 0.0)
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob: Texture2D = load("res://assets/ui/knob.png")
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	t.set_stylebox("normal", "LineEdit", flat(DUSK, STEEL))
	t.set_stylebox("focus", "LineEdit", flat(DUSK, EMBER))
	t.set_stylebox("read_only", "LineEdit", flat(DUSK, STEEL))
	t.set_color("font_color", "LineEdit", BONE)
	t.set_color("font_placeholder_color", "LineEdit", Color(ASH, 0.8))
	t.set_color("caret_color", "LineEdit", EMBER)
	# Scrolling is done with a finger, so the bar only has to say where you are.
	for bar: String in ["VScrollBar", "HScrollBar"]:
		var grab := flat(Color(ASH, 0.45), Color.TRANSPARENT, 4, 3.0)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab)
		t.set_stylebox("grabber_pressed", bar, grab)
		t.set_stylebox("scroll", bar, flat(Color(0, 0, 0, 0), Color.TRANSPARENT, 4, 3.0))
		t.set_stylebox("scroll_focus", bar, flat(Color(0, 0, 0, 0), Color.TRANSPARENT, 4, 3.0))
	return t


## The one thing on a screen you are most likely to want.
static func primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", flat(EMBER, Color.TRANSPARENT))
	b.add_theme_stylebox_override("hover", flat(EMBER, Color.TRANSPARENT))
	b.add_theme_stylebox_override("pressed", flat(EMBER.darkened(0.2), Color.TRANSPARENT))
	b.add_theme_stylebox_override("disabled", flat(Color(EMBER, 0.3), Color.TRANSPARENT))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, COAL)
	b.add_theme_color_override("font_disabled_color", Color(BONE, 0.8))


## An option that is on, in a row of options.
static func selected(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, flat(Color(EMBER, 0.22), EMBER))


## Back to how the theme draws it.
static func plain(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.remove_theme_stylebox_override(state)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.remove_theme_color_override(state)
