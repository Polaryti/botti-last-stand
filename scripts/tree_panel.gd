class_name TreePanel
extends Control
## The class's ability tree, as a real tree: a shared start that splits into three branches
## ending in final abilities. Drag sideways to scroll, tap a node to read and choose it.
## The game keeps running behind it, so open it somewhere safe.

signal closed

const NODE := 62.0
const COL := 88.0
const ROW := [78.0, 232.0, 386.0]

var player: Player
var _scroll: ScrollContainer
var _content: TreeCanvas
var _header: Label
var _detail_icon: IconView
var _detail_name: Label
var _detail_desc: Label
var _choose: Button
var _nodes: Array[TreeNodeButton] = []
var _selected: TreeNodeButton


func build() -> void:
	var shade := TextureRect.new()
	shade.texture = load("res://assets/ui/vignette.png")
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_header = Label.new()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_font_override("font", UiTheme.title_font())
	_header.add_theme_font_size_override("font_size", 28)
	_header.add_theme_color_override("font_color", UiTheme.INK)
	top.add_child(_header)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(130, 44)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func() -> void:
		Sfx.play("ui_click", -4.0)
		closed.emit())
	top.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_content = TreeCanvas.new()
	_content.panel = self
	# Drags have to reach the scroll container, on bare parchment as well as on a medallion.
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	_build_nodes()
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 12)
	box.add_child(detail)
	_detail_icon = IconView.new("tree", Color(0.4, 0.3, 0.2), 66.0)
	detail.add_child(_detail_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	detail.add_child(text)
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 24)
	_detail_name.add_theme_color_override("font_color", UiTheme.INK)
	text.add_child(_detail_name)
	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 20)
	_detail_desc.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	text.add_child(_detail_desc)
	_choose = Button.new()
	_choose.text = "Choose"
	_choose.custom_minimum_size = Vector2(170, 62)
	_choose.add_theme_font_size_override("font_size", 26)
	UiTheme.wax(_choose)
	_choose.pressed.connect(choose_selected)
	detail.add_child(_choose)
	refresh()
	_select_next()
	_scroll_to_next.call_deferred()


func _add_node(step: int, option: int, spec: int, a: Dictionary, at: Vector2, col: Color, px := NODE) -> void:
	var n := TreeNodeButton.new()
	n.panel = self
	n.step = step
	n.option = option
	n.spec = spec
	n.ability = a
	n.color = col
	n.custom_minimum_size = Vector2.ONE * px
	n.size = Vector2.ONE * px
	n.position = at - Vector2.ONE * px * 0.5
	_content.add_child(n)
	_nodes.append(n)


func _build_nodes() -> void:
	var t := player.tree_data()
	var base := ClassDefs.color(player.class_id)
	var core: Array = t["core"]
	var mid: float = ROW[1]
	for s in core.size():
		var options: Array = core[s]
		for i in options.size():
			_add_node(s, i, -1, options[i], Vector2(50 + s * COL, mid + (i * 2 - 1) * 42.0), base)
	var specs: Array = t["specs"]
	var entry_step := core.size()
	var entry_x := 50 + entry_step * COL + 14.0
	for si in specs.size():
		var spec: Dictionary = specs[si]
		var y: float = ROW[si]
		var col: Color = spec["color"]
		_add_node(entry_step, si, si, spec["entry"], Vector2(entry_x, y), col, 74.0)
		var x := entry_x + COL + 6.0
		var path: Array = spec["path"]
		for p in path.size():
			var options: Array = path[p]
			var step := entry_step + 1 + p
			if options.size() == 1:
				_add_node(step, 0, si, options[0], Vector2(x, y), col, 46.0)
				x += COL * 0.72
			else:
				for i in options.size():
					_add_node(step, i, si, options[i], Vector2(x, y + (i * 2 - 1) * 34.0), col, 58.0)
				x += COL * 0.85
		_add_node(entry_step + 1 + path.size(), 0, si, spec["final"], Vector2(x + 14.0, y), col, 82.0)
		_content.custom_minimum_size = Vector2(maxf(_content.custom_minimum_size.x, x + 80.0), 462.0)


func state_of(n: TreeNodeButton) -> String:
	var taken: Variant = player.chosen.get(n.step)
	if taken == n.ability["id"]:
		return "taken"
	if n.spec >= 0 and player.spec_id != "" and (player.tree_data()["specs"] as Array)[n.spec]["id"] != player.spec_id:
		return "locked"
	if taken != null:
		return "locked"
	if n.step == player.next_step() and player.points > 0 and _branch_open(n):
		return "ready"
	return "future"


func _branch_open(n: TreeNodeButton) -> bool:
	return n.step <= Player.CORE_STEPS or player.spec_id != ""


func select(n: TreeNodeButton) -> void:
	_selected = n
	Sfx.play("ui_click", -8.0)
	refresh()


func choose_selected() -> void:
	if _selected == null or state_of(_selected) != "ready":
		return
	if player.choose_ability(_selected.step, _selected.option):
		refresh()
		_select_next()
		_scroll_to_next.call_deferred()


func _select_next() -> void:
	for n in _nodes:
		if state_of(n) == "ready":
			_selected = n
			refresh()
			return


func _scroll_to_next() -> void:
	var target := -1.0
	for n in _nodes:
		if n.step == player.next_step() and state_of(n) != "locked":
			target = n.position.x
			break
	if target >= 0.0:
		_scroll.scroll_horizontal = int(maxf(0.0, target - 300.0))


func refresh() -> void:
	var name_text: String = player.class_def()["name"]
	if player.spec_id != "":
		name_text = "%s, %s" % [name_text, player.spec_def()["name"]]
	if player.level >= ClassDefs.MAX_LEVEL:
		_header.text = "%s. Level %d. Points: %d" % [name_text, player.level, player.points]
	else:
		_header.text = "%s. Level %d (%d/%d). Points: %d" % [name_text, player.level, player.xp, player.xp_needed(), player.points]
	if _selected:
		var a := _selected.ability
		_detail_icon.icon = a["icon"]
		_detail_icon.color = _selected.color
		_detail_icon.queue_redraw()
		_detail_name.text = a["name"]
		_detail_desc.text = a["desc"]
		var st := state_of(_selected)
		_choose.disabled = st != "ready"
		_choose.text = {"taken": "Taken", "locked": "Locked", "ready": "Choose"}.get(st, "Later")
	else:
		_detail_name.text = ""
		_detail_desc.text = "Tap a medallion to read it."
		_choose.disabled = true
	for n in _nodes:
		n.queue_redraw()
	_content.queue_redraw()


class TreeCanvas:
	extends Control
	var panel: TreePanel

	func _draw() -> void:
		var by_step := {}
		for n: TreeNodeButton in panel._nodes:
			var key := "%d:%d" % [n.step, n.spec if n.step > Player.CORE_STEPS else -1]
			if not by_step.has(key):
				by_step[key] = []
			by_step[key].append(n)
		for n: TreeNodeButton in panel._nodes:
			var prev := _previous(n, by_step)
			for p: TreeNodeButton in prev:
				var both := panel.state_of(n) == "taken" and panel.state_of(p) == "taken"
				var col := Color(0.62, 0.42, 0.08) if both else Color(0.3, 0.22, 0.15, 0.42)
				draw_line(p.position + p.size * 0.5, n.position + n.size * 0.5, col, 4.0 if both else 2.0, true)

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
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE

	func _pressed() -> void:
		panel.select(self)

	func _process(_delta: float) -> void:
		if panel.state_of(self) == "ready":
			queue_redraw()

	func _draw() -> void:
		var st := panel.state_of(self)
		var r := Rect2(Vector2.ZERO, size)
		if st == "ready":
			var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.006) * 0.5
			draw_circle(size * 0.5, size.x * 0.56, Color(1.0, 0.78, 0.2, 0.25 + pulse * 0.5))
		if st == "taken":
			draw_circle(size * 0.5, size.x * 0.56, Color(0.85, 0.6, 0.12, 0.85))
		if panel._selected == self:
			draw_arc(size * 0.5, size.x * 0.58, 0.0, TAU, 32, UiTheme.INK, 3.0)
		Icons.draw(self, r, ability["icon"], color.darkened(0.3) if st == "future" else color, st == "locked")
		if ability.get("final", false) and st != "locked":
			draw_arc(size * 0.5, size.x * 0.52, 0.0, TAU, 32, UiTheme.GOLD, 3.0)
