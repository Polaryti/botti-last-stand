class_name UiScreen
extends RefCounted
## The one way every menu screen is laid out. The world stays dimmed behind; along the top runs one
## bar: the way back on the left, the screen's name and a line about it, and on the right whatever the
## screen keeps there (Doubloons, a Refresh). Under it, a row of tabs when the screen has pages, and
## then the screen itself, filling the rest. Only small things (Pause, the end of a night, a name to
## type) open as a card over what is behind.


## Builds the frame inside `root` (which fills the screen) and returns its parts:
## "box" (everything under the bar, top to bottom), "top" (the bar), "right" (the right end of the
## bar), "back" (the way-back button), "head" (the title label).
static func frame(root: Control, title: String, on_back: Callable, line := "", back_text := "Back") -> Dictionary:
	var shade := TextureRect.new()
	shade.texture = load("res://assets/ui/vignette.png")
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	UiTheme.fit_safe_area(margin, UiTheme.EDGE_X, UiTheme.EDGE_Y)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.GAP)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var back := Button.new()
	back.name = "BackButton"
	back.text = back_text
	back.custom_minimum_size.x = maxf(116.0, UiTheme.bold_font().get_string_size(back_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_BTN).x + 48.0)
	UiTheme.size_button(back, UiTheme.BTN)
	back.pressed.connect(func() -> void: Sfx.play("ui_click", -3.0))
	back.pressed.connect(on_back)
	top.add_child(back)
	var head := Label.new()
	head.name = "ScreenTitle"
	head.text = title
	head.add_theme_font_override("font", UiTheme.title_font())
	head.add_theme_font_size_override("font_size", UiTheme.FS_TITLE)
	head.add_theme_color_override("font_color", UiTheme.BONE)
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	head.add_theme_constant_override("outline_size", 4)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(head)
	if line != "":
		var about := Label.new()
		about.name = "ScreenLine"
		about.text = line
		about.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
		about.add_theme_color_override("font_color", UiTheme.ASH)
		about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		about.clip_text = true
		about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(about)
	else:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(gap)
	var right := HBoxContainer.new()
	right.name = "TopRight"
	right.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(right)
	return {"box": box, "top": top, "right": right, "back": back, "head": head}


## A row of tabs under the bar: the chosen one marked, all the same height and size of words.
static func tabs(box: VBoxContainer, names: Array, on: int, picked: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("h_separation", UiTheme.GAP_SMALL)
	row.add_theme_constant_override("v_separation", UiTheme.GAP_SMALL)
	box.add_child(row)
	for i in names.size():
		var b := Button.new()
		b.text = str(names[i])
		UiTheme.size_button(b, UiTheme.BTN_SHORT)
		b.custom_minimum_size.x = maxf(120.0, UiTheme.bold_font().get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_BTN_SHORT).x + 40.0)
		if i == on:
			UiTheme.selected(b)
		var index := i
		b.pressed.connect(func() -> void: Sfx.play("ui_click", -5.0))
		b.pressed.connect(func() -> void: picked.call(index))
		row.add_child(b)
	return row


## Marks which tab of a row is chosen, for screens that change page without being built again.
static func mark_tab(row: Container, on: int) -> void:
	var i := 0
	for b: Button in row.get_children():
		UiTheme.plain(b)
		UiTheme.size_button(b, UiTheme.BTN_SHORT)
		if i == on:
			UiTheme.selected(b)
		i += 1


## The page itself: a card filling what is left of the screen.
static func page(box: VBoxContainer) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Page"
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(p)
	return p
