class_name ChangelogPanel
extends Control
## The game notes: what changed in each version, newest first. Read from CHANGELOG.md, so the game
## and the repository always say the same thing.

signal closed

const PATH := "res://CHANGELOG.md"


func build() -> void:
	var shade := TextureRect.new()
	shade.texture = load("res://assets/ui/vignette.png")
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	UiTheme.fit_safe_area(margin, 56, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := PanelContainer.new()
	margin.add_child(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	page.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var head := Label.new()
	head.text = "Changelog"
	head.add_theme_font_override("font", UiTheme.title_font())
	head.add_theme_font_size_override("font_size", 38)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(130, 54)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void:
		Sfx.play("ui_click", -4.0)
		closed.emit())
	top.add_child(close)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for entry: Dictionary in parse(FileAccess.get_file_as_string(PATH)):
		_add_line(list, entry)


## "## 0.8.0 (3 November 2026)" starts a version, "### New" a part of it, and "- " one change.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("## "):
			out.append({"kind": "version", "text": line.substr(3)})
		elif line.begins_with("### "):
			out.append({"kind": "part", "text": line.substr(4)})
		elif line.begins_with("- "):
			out.append({"kind": "item", "text": line.substr(2)})
	return out


func _add_line(list: VBoxContainer, entry: Dictionary) -> void:
	var l := Label.new()
	l.text = entry["text"]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match entry["kind"]:
		"version":
			var gap := Control.new()
			gap.custom_minimum_size.y = 12
			list.add_child(gap)
			l.add_theme_font_override("font", UiTheme.title_font())
			l.add_theme_font_size_override("font_size", 30)
			list.add_child(l)
		"part":
			l.add_theme_font_override("font", UiTheme.bold_font())
			l.add_theme_font_size_override("font_size", 23)
			l.add_theme_color_override("font_color", UiTheme.EMBER)
			list.add_child(l)
		_:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list.add_child(row)
			var dot := Label.new()
			dot.text = "•"
			dot.add_theme_font_size_override("font_size", 22)
			dot.add_theme_color_override("font_color", UiTheme.ASH)
			dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(dot)
			l.add_theme_font_size_override("font_size", 23)
			row.add_child(l)
