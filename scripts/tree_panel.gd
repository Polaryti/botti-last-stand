class_name TreePanel
extends Control
## The class's ability tree, made to be used with enemies around. The top half is what you can do right
## now: big cards, one tap to take one. The bottom half is the map of your path: which step you are
## on, what is behind you, what is ahead, and whose branch is whose. Tap anything on the map to read it.
## The game keeps running behind it, and taking damage closes it.

signal closed

const LABELS_HIGH := 30.0
const ZONE_HIGH := 232.0 # the top half's usual height: cards and what you are reading
const ZONE_MOST := 0.62 # the most of the panel it may take when a text needs more room
const PANEL_PAD := 12.0
const CARD_PAD := 12.0

var player: Player
var _class_name: Label
var _level: Label
var _points: Label
var _xp: Control
var _zone: VBoxContainer
var _map: TreeMap
var _reading: TreeNodeButton
var _seen_points := -1
var _seen_step := -1
var _seen_level := -1
var _seen_xp := -1


func build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat(Color(UiTheme.NIGHT, 0.97), UiTheme.STEEL, 12, 12.0))
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_build_header())
	_zone = VBoxContainer.new()
	_zone.custom_minimum_size.y = ZONE_HIGH
	_zone.add_theme_constant_override("separation", 6)
	box.add_child(_zone)
	_map = TreeMap.new()
	_map.panel = self
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_map)
	refresh(true)


func _build_header() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var icon := IconView.new(ClassDefs.icon(player.class_id), ClassDefs.color(player.class_id), 46.0)
	top.add_child(icon)
	_class_name = Label.new()
	_class_name.add_theme_font_override("font", UiTheme.title_font())
	_class_name.add_theme_font_size_override("font_size", 28)
	top.add_child(_class_name)
	top.add_child(_spacer(12.0))
	_level = Label.new()
	_level.add_theme_font_override("font", UiTheme.bold_font())
	_level.add_theme_font_size_override("font_size", 24)
	_level.add_theme_color_override("font_color", UiTheme.BONE)
	top.add_child(_level)
	_xp = XpBar.new()
	(_xp as XpBar).player = player
	_xp.custom_minimum_size = Vector2(190, 12)
	_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_xp)
	_points = Label.new()
	_points.add_theme_font_override("font", UiTheme.bold_font())
	_points.add_theme_font_size_override("font_size", 24)
	_points.add_theme_color_override("font_color", UiTheme.EMBER)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_points)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(140, 50)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void:
		Sfx.play("ui_click", -4.0)
		closed.emit())
	top.add_child(close)
	return top


func _spacer(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = px
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _process(_delta: float) -> void:
	if player == null:
		return
	if player.points != _seen_points or player.next_step() != _seen_step or player.level != _seen_level:
		refresh(true)
	elif player.xp != _seen_xp:
		refresh(false)


## Everything that depends on where the player is. With rebuild off, only the numbers.
func refresh(rebuild := false) -> void:
	_seen_points = player.points
	_seen_step = player.next_step()
	_seen_level = player.level
	_seen_xp = player.xp
	var text: String = player.class_def()["name"]
	if player.spec_id != "":
		text = "%s, %s" % [text, player.spec_def()["name"]]
	_class_name.text = text
	_level.text = "Level %d" % player.level
	_xp.queue_redraw()
	if player.points == 1:
		_points.text = "1 point to spend"
	elif player.points > 1:
		_points.text = "%d points to spend" % player.points
	else:
		_points.text = ""
	if rebuild:
		_map.rebuild()
		_fill_zone()


## How wide the top half is, from the screen, before anything is laid out.
func _zone_width() -> float:
	return get_viewport_rect().size.x - 36.0 - PANEL_PAD * 2.0


## How tall these words stand in a Label this wide, wrapped by word, with the gap between lines.
static func text_height(font: Font, text: String, width: float, size: int, spacing: int) -> float:
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
	var lines := maxi(1, roundi(h / maxf(font.get_height(size), 1.0)))
	return h + spacing * (lines - 1) + 2.0


## The largest of the sizes at which these words fit in a box this wide and this high. When even the
## smallest does not fit, the smallest, and the caller makes room.
static func fit_size(font: Font, text: String, width: float, height: float, sizes: Array, spacing := 3) -> int:
	for size: int in sizes:
		if text_height(font, text, width, size, spacing) <= height:
			return size
	return sizes[sizes.size() - 1]


## A name over its description, sized so that both fit the space they have. Long descriptions get
## smaller letters first, then the name. If nothing fits at the smallest, the top half grows instead,
## up to most of the panel, and the map below gives way.
func _fit_pair(name_label: Label, desc: Label, width: float, height: float, name_sizes: Array, desc_sizes: Array) -> void:
	var bold := UiTheme.bold_font()
	var plain := get_theme_default_font()
	var spacing := get_theme_constant("line_spacing", "Label")
	var name_size: int = name_sizes[0]
	var desc_size: int = desc_sizes[0]
	var need := 0.0
	for n: int in name_sizes:
		name_size = n
		var name_h := text_height(bold, name_label.text, width, n, spacing)
		desc_size = fit_size(plain, desc.text, width, height - name_h - 6.0, desc_sizes, spacing)
		need = name_h + 6.0 + text_height(plain, desc.text, width, desc_size, spacing)
		if need <= height:
			break
	name_label.add_theme_font_size_override("font_size", name_size)
	desc.add_theme_font_size_override("font_size", desc_size)
	if need > height:
		var most := get_viewport_rect().size.y * ZONE_MOST
		_zone.custom_minimum_size.y = minf(maxf(_zone.custom_minimum_size.y, ZONE_HIGH + need - height), most)


func _clear_zone() -> void:
	for c: Node in _zone.get_children():
		_zone.remove_child(c)
		c.queue_free()


func _fill_zone() -> void:
	_clear_zone()
	_zone.custom_minimum_size.y = ZONE_HIGH
	if _reading != null and is_instance_valid(_reading):
		_show_reading()
		return
	_reading = null
	var step := player.next_step()
	var all := player.steps()
	var can_pick := player.points > 0 and step < all.size()
	if can_pick:
		var options: Array = all[step]
		# A Revenant's gifts come by themselves, so only its path is ever on offer here.
		_show_cards(step, options)
		return
	_show_waiting(step, all.size())


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.title_font())
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", UiTheme.EMBER)
	return l


func _show_cards(step: int, options: Array) -> void:
	var picking_spec := step == Player.CORE_STEPS
	_zone.add_child(_title("Choose your specialization" if picking_spec else "Level %d: choose one" % (step + 2)))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	_zone.add_child(row)
	var specs: Array = player.tree_data()["specs"]
	var count := options.size()
	var card_w := (_zone_width() - 10.0 * (count - 1)) / count
	var text_w := card_w - CARD_PAD * 2.0 - (96.0 if count < 3 else 80.0) - 14.0
	var text_h := ZONE_HIGH - 42.0 - CARD_PAD * 2.0
	for i in count:
		var a: Dictionary = options[i]
		var col := ClassDefs.color(player.class_id)
		if picking_spec:
			col = specs[i]["color"]
		elif player.spec_id != "":
			col = player.spec_def()["color"]
		row.add_child(_card(step, i, a, col, count, text_w, text_h))


## One choice, large enough to read in a hurry. One tap takes it.
func _card(step: int, index: int, a: Dictionary, col: Color, count: int, text_w := 0.0, text_h := 0.0) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UiTheme.flat(UiTheme.DUSK, UiTheme.EMBER, 10, 0.0))
	b.add_theme_stylebox_override("hover", UiTheme.flat(UiTheme.DUSK, UiTheme.EMBER, 10, 0.0))
	b.add_theme_stylebox_override("pressed", UiTheme.flat(Color(UiTheme.EMBER, 0.28), UiTheme.EMBER, 10, 0.0))
	b.pressed.connect(func() -> void: choose(step, index))
	var inside := MarginContainer.new()
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		inside.add_theme_constant_override("margin_" + side, 12)
	b.add_child(inside)
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	inside.add_child(row)
	var icon := IconView.new(a["icon"], col, 96.0 if count < 3 else 80.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = a["name"]
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.add_theme_font_size_override("font_size", 30 if count < 3 else 27)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	var desc := Label.new()
	desc.text = a["desc"]
	desc.add_theme_font_size_override("font_size", 25 if count < 3 else 22)
	desc.add_theme_color_override("font_color", UiTheme.BONE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	if text_w > 0.0:
		var big := 30 if count < 3 else 27
		var small := 25 if count < 3 else 22
		_fit_pair(name_label, desc, text_w, text_h, [big, big - 3, big - 6, 20], range(small, 14, -1))
	return b


func _show_waiting(step: int, total: int) -> void:
	var line := "Tap anything on the map below to read it."
	if player.level >= ClassDefs.MAX_LEVEL and player.points == 0 and step >= total:
		_zone.add_child(_title("Every ability taken"))
	elif step < _map.total_steps():
		_zone.add_child(_title("Next choice at level %d" % (step + 2)))
	else:
		_zone.add_child(_title("Every ability taken"))
	var l := Label.new()
	l.text = line
	l.add_theme_font_size_override("font_size", 25)
	l.add_theme_color_override("font_color", UiTheme.ASH)
	_zone.add_child(l)


## The long version of one thing on the map.
func _show_reading() -> void:
	var a := _reading.ability
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	_zone.add_child(row)
	var icon := IconView.new(a["icon"], _reading.color, 120.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = a["name"]
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.add_theme_font_size_override("font_size", 34)
	text.add_child(name_label)
	var desc := Label.new()
	desc.text = a["desc"]
	desc.add_theme_font_size_override("font_size", 27)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	# Room for the words: the width left beside the picture and the buttons, and the height left
	# under the name, above the line that says where it stands.
	_fit_pair(name_label, desc, _zone_width() - 120.0 - 18.0 * 2.0 - 190.0, ZONE_HIGH - 34.0, [34, 30, 26], range(27, 15, -1))
	var state := Label.new()
	state.text = _state_words(_reading)
	state.add_theme_font_size_override("font_size", 23)
	state.add_theme_color_override("font_color", UiTheme.EMBER)
	text.add_child(state)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 10)
	row.add_child(buttons)
	if state_of(_reading) == "ready":
		var taking := _reading
		var unlock := Button.new()
		unlock.text = "Unlock"
		unlock.custom_minimum_size = Vector2(190, 72)
		UiTheme.primary(unlock)
		unlock.pressed.connect(func() -> void: choose(taking.step, taking.spec if taking.spec >= 0 and taking.step == Player.CORE_STEPS else taking.option))
		buttons.add_child(unlock)
	var back := Button.new()
	back.text = "Your choice" if player.points > 0 else "OK"
	back.custom_minimum_size = Vector2(190, 64)
	back.pressed.connect(func() -> void: read(null))
	buttons.add_child(back)


func _state_words(n: TreeNodeButton) -> String:
	match state_of(n):
		"taken": return "You have this."
		"ready": return "You can take this now."
		"locked": return "Not on your path this night."
	return "Comes at level %d." % (n.step + 2)


func read(n: TreeNodeButton) -> void:
	_reading = n
	Sfx.play("ui_click", -8.0)
	_map.queue_redraw()
	_fill_zone()


func choose(step: int, index: int) -> void:
	if player.choose_ability(step, index):
		_reading = null
		refresh(true)


func state_of(n: TreeNodeButton) -> String:
	var taken: Variant = player.chosen.get(n.step)
	if taken == n.ability["id"]:
		return "taken"
	if n.spec >= 0 and player.spec_id != "" and (player.tree_data()["specs"] as Array)[n.spec]["id"] != player.spec_id:
		return "locked"
	if taken != null:
		return "locked"
	if n.step == player.next_step() and player.points > 0 and (n.step <= Player.CORE_STEPS or player.spec_id != ""):
		return "ready"
	return "future"


class XpBar:
	extends Control
	var player: Player

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiTheme.flat(Color(UiTheme.STEEL, 0.8), Color.TRANSPARENT, 5, 0.0), r)
		var f := 1.0
		if player.level < ClassDefs.MAX_LEVEL:
			f = clampf(float(player.xp) / float(player.xp_needed()), 0.0, 1.0)
		if f > 0.0:
			draw_style_box(UiTheme.flat(UiTheme.EMBER, Color.TRANSPARENT, 5, 0.0), Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * f), r.size.y)))


## The whole path, left to right, one column for each level. Before a specialization is chosen it shows
## all three branches. After that only yours, so its icons can be large.
class TreeMap:
	extends Control
	var panel: TreePanel
	var nodes: Array[TreeNodeButton] = []
	var _branches: Array[Dictionary] = []
	var _laid_for := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(_layout)

	func total_steps() -> int:
		var t := panel.player.tree_data()
		var spec: Dictionary = t["specs"][0]
		return (t["core"] as Array).size() + 1 + (spec["path"] as Array).size() + 1

	func _column(step: int) -> float:
		return size.x * (step + 0.5) / float(total_steps())

	func rebuild() -> void:
		for n in nodes:
			remove_child(n)
			n.queue_free()
		nodes.clear()
		_branches.clear()
		var player := panel.player
		var t := player.tree_data()
		var core: Array = t["core"]
		for s in core.size():
			var options: Array = core[s]
			for i in options.size():
				_add(s, i, -1, options[i], ClassDefs.color(player.class_id))
		var specs: Array = t["specs"]
		for si in specs.size():
			var spec: Dictionary = specs[si]
			if player.spec_id != "" and spec["id"] != player.spec_id:
				continue
			_branches.append({"index": si, "name": spec["name"], "color": spec["color"]})
			var step := core.size()
			_add(step, si, si, spec["entry"], spec["color"])
			var path: Array = spec["path"]
			for p in path.size():
				var options: Array = path[p]
				for i in options.size():
					_add(step + 1 + p, i, si, options[i], spec["color"])
			_add(step + 1 + path.size(), 0, si, spec["final"], spec["color"])
		_layout()
		queue_redraw()

	func _add(step: int, option: int, spec: int, a: Dictionary, col: Color) -> void:
		var n := TreeNodeButton.new()
		n.panel = panel
		n.step = step
		n.option = option
		n.spec = spec
		n.ability = a
		n.color = col
		add_child(n)
		nodes.append(n)

	## Where the lane of a branch runs.
	func _lane(index: int) -> Rect2:
		var top := LABELS_HIGH
		var high := (size.y - top) / maxf(1.0, float(_branches.size()))
		return Rect2(_column(Player.CORE_STEPS) - size.x * 0.5 / float(total_steps()) + 2.0, top + index * high + 2.0, 1e6, high - 4.0)

	func _layout() -> void:
		if panel == null or nodes.is_empty() or size.y <= 0.0:
			return
		_laid_for = size
		var one := _branches.size() == 1
		var usable := size.y - LABELS_HIGH
		var lane_high := usable / maxf(1.0, float(_branches.size()))
		var column := size.x / float(total_steps())
		var wide := minf(column - 8.0, 96.0 if one else 68.0)
		var big := minf(column - 6.0, 112.0 if one else 78.0)
		var small := minf(minf(column - 8.0, 92.0 if one else 56.0), lane_high * 0.5 - 2.0 + 8.0)
		var core_px := minf(column - 8.0, 84.0)
		var mid := LABELS_HIGH + usable * 0.5
		for n in nodes:
			var px := wide
			var y := mid
			if n.step < Player.CORE_STEPS:
				px = core_px
				y = mid + (n.option * 2 - 1) * minf(usable * 0.25, 58.0)
			else:
				var lane := _lane(_lane_of(n.spec))
				var centre := lane.get_center().y
				var is_entry := n.step == Player.CORE_STEPS
				var is_final := bool(n.ability.get("final", false))
				if is_final:
					px = big
					y = centre
				elif is_entry:
					px = wide
					y = centre + 8.0
				else:
					px = small
					var options := 2.0 if not n.ability.is_empty() else 1.0
					y = centre + 8.0 + (n.option * 2 - 1) * minf(lane_high * 0.25, px * 0.56 + 2.0) * (1.0 if options > 1.0 else 0.0)
					if _single_option(n):
						y = centre + 8.0
			n.size = Vector2.ONE * px
			n.custom_minimum_size = n.size
			n.position = Vector2(_column(n.step), y) - n.size * 0.5
		queue_redraw()

	func _single_option(n: TreeNodeButton) -> bool:
		for other in nodes:
			if other != n and other.step == n.step and other.spec == n.spec:
				return false
		return true

	func _lane_of(spec: int) -> int:
		for i in _branches.size():
			if int(_branches[i]["index"]) == spec:
				return i
		return 0

	func _draw() -> void:
		var player := panel.player
		var now := player.next_step()
		var column := size.x / float(total_steps())
		var font := UiTheme.bold_font()
		# The lanes, each with its specialization's name on it.
		for i in _branches.size():
			var b: Dictionary = _branches[i]
			var lane := _lane(i)
			lane.size.x = size.x - lane.position.x
			draw_style_box(UiTheme.flat(Color(b["color"], 0.16), Color(b["color"], 0.4), 8, 0.0, 1), lane)
			var col: Color = (b["color"] as Color).lightened(0.45)
			draw_string(font, lane.position + Vector2(10, 24), str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23, col)
		# A column for each level, and a marker on the one you are at.
		if now < total_steps():
			var x := _column(now) - column * 0.5
			var ready := player.points > 0
			draw_style_box(UiTheme.flat(Color(UiTheme.EMBER, 0.2 if ready else 0.08), Color(UiTheme.EMBER, 0.75 if ready else 0.3), 8, 0.0, 2), Rect2(x + 1.0, 0.0, column - 2.0, size.y))
		for s in total_steps():
			var text := "Lv %d" % (s + 2)
			var cx := _column(s)
			var is_now := s == now
			var col := UiTheme.EMBER if is_now else (UiTheme.BONE if s < now else UiTheme.ASH)
			if is_now:
				text = "You are here"
			var fs := 19 if is_now else 21
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(cx - w * 0.5, 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
		# The roads between the abilities: bright for the way you took.
		var by_step := {}
		for n in nodes:
			var key := "%d:%d" % [n.step, n.spec if n.step > Player.CORE_STEPS else -1]
			if not by_step.has(key):
				by_step[key] = []
			by_step[key].append(n)
		for n in nodes:
			for p: TreeNodeButton in _previous(n, by_step):
				var both := panel.state_of(n) == "taken" and panel.state_of(p) == "taken"
				var dark := panel.state_of(n) == "locked" or panel.state_of(p) == "locked"
				var col := UiTheme.EMBER if both else Color(UiTheme.STEEL, 0.4 if dark else 0.95)
				draw_line(p.position + p.size * 0.5, n.position + n.size * 0.5, col, 5.0 if both else 2.0, true)

	func _previous(n: TreeNodeButton, by_step: Dictionary) -> Array:
		if n.step == 0:
			return []
		if n.step <= Player.CORE_STEPS:
			return by_step.get("%d:-1" % (n.step - 1), [])
		if n.step == Player.CORE_STEPS + 1:
			var out: Array = []
			for e: TreeNodeButton in by_step.get("%d:-1" % Player.CORE_STEPS, []):
				if e.spec == n.spec:
					out.append(e)
			return out
		return by_step.get("%d:%d" % [n.step - 1, n.spec], [])


class TreeNodeButton:
	extends BaseButton
	var panel: TreePanel
	var step := 0
	var option := 0
	var spec := -1
	var ability: Dictionary
	var color := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		panel.read(self)

	func _process(_delta: float) -> void:
		if panel.state_of(self) == "ready":
			queue_redraw()

	func _draw() -> void:
		var st := panel.state_of(self)
		var r := Rect2(Vector2.ZERO, size)
		if st == "ready":
			var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.006) * 0.5
			draw_circle(size * 0.5, size.x * 0.58, Color(UiTheme.EMBER, 0.25 + pulse * 0.5))
		if st == "taken":
			draw_circle(size * 0.5, size.x * 0.56, UiTheme.EMBER)
		if panel._reading == self:
			draw_arc(size * 0.5, size.x * 0.6, 0.0, TAU, 32, UiTheme.BONE, 3.0, true)
		Icons.draw(self, r, ability["icon"], color.darkened(0.25) if st == "future" else color, st == "locked")
		if ability.get("final", false) and st != "locked":
			draw_arc(size * 0.5, size.x * 0.54, 0.0, TAU, 32, UiTheme.EMBER, 3.0, true)
