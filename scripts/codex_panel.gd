class_name CodexPanel
extends Control
## The player's field notes: who you can be, what lives out there, and what can be found.

signal closed

const TABS := ["Classes", "Enemies", "Familiars", "Items", "Weapons"]

var _list: VBoxContainer
var _scroll: DragScroll
var _tabs: Array[Button] = []


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
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TABS[i]
		tab.toggle_mode = false
		tab.custom_minimum_size = Vector2(150, 52)
		tab.add_theme_font_size_override("font_size", 24)
		var index := i
		tab.pressed.connect(func() -> void:
			Sfx.play("ui_click", -5.0)
			show_tab(index))
		top.add_child(tab)
		_tabs.append(tab)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 52)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void:
		Sfx.play("ui_click", -4.0)
		closed.emit())
	top.add_child(close)
	_scroll = DragScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	show_tab(0)


func show_tab(index: int) -> void:
	for c in _list.get_children():
		c.queue_free()
	for i in _tabs.size():
		UiTheme.plain(_tabs[i])
		if i == index:
			UiTheme.selected(_tabs[i])
	_scroll.scroll_vertical = 0
	match index:
		0: _classes()
		1: _enemies()
		2: _familiars()
		3: _items()
		4: _weapons()


func _row(icon: String, color: Color, title: String, text: String, note := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_list.add_child(row)
	var medal := IconView.new(icon, color, 64.0)
	medal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(medal)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", UiTheme.title_font())
	head.add_theme_font_size_override("font_size", 27)
	head.add_theme_color_override("font_color", UiTheme.BONE)
	words.add_child(head)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", UiTheme.ASH)
	words.add_child(body)
	if note != "":
		var extra := Label.new()
		extra.text = note
		extra.add_theme_font_size_override("font_size", 20)
		extra.add_theme_color_override("font_color", UiTheme.EMBER)
		words.add_child(extra)


## Every class, whether or not it is yours yet, with its paths.
func _classes() -> void:
	for id: String in ClassDefs.ALL:
		var d: Dictionary = ClassDefs.ALL[id]
		var paths := PackedStringArray()
		for spec: Dictionary in AbilityData.tree(id)["specs"]:
			paths.append(spec["name"])
		var note := "Health %d, speed %d%%. Paths: %s." % [int(d["hp"]), int(round(float(d["speed"]) * 100.0)), ", ".join(paths)]
		if not Game.owns_class(id):
			note += " In the Store for %d doubloons." % ClassDefs.price(id)
		_row(ClassDefs.icon(id), ClassDefs.color(id), d["name"], d["desc"], note)


func _enemies() -> void:
	for id: String in ZombieDefs.ALL:
		var d: Dictionary = ZombieDefs.ALL[id]
		var note := "Health %d, %d XP" % [int(d["hp"]), int(d["xp"])]
		var from: float = d.get("from", -1.0)
		if from > 0.0:
			note += ". From minute %d" % ceili(from / 60.0)
		_row(d["icon"], d.get("tint", Color(0.34, 0.34, 0.38)).darkened(0.1), d["name"], d["desc"], note)


func _familiars() -> void:
	for id: String in PowerDefs.ALL:
		var d: Dictionary = PowerDefs.ALL[id]
		if d["familiar"]:
			_row(Icons.power(id), Color(d["color"]).darkened(0.35), d["name"], d["desc"], "%d seconds" % int(d["time"]))


func _items() -> void:
	for id: String in PowerDefs.ALL:
		var d: Dictionary = PowerDefs.ALL[id]
		if not d["familiar"]:
			_row(Icons.power(id), Color(d["color"]).darkened(0.35), "%s Potion" % d["name"], d["desc"], "%d seconds" % int(d["time"]))
	for id: String in PowerDefs.FOODS:
		var f: Dictionary = PowerDefs.FOODS[id]
		_row("drop+heart", Color(0.3, 0.5, 0.25), f["name"], "Heals %d health." % int(f["heal"]))
	_row("arrows", Color(0.5, 0.45, 0.35), "Arrows", "A bundle of 12, for bows and crossbows.")


func _weapons() -> void:
	for id: String in WeaponDefs.ALL:
		var d: Dictionary = WeaponDefs.ALL[id]
		if d.get("hidden", false):
			continue
		var note := ""
		match d["kind"]:
			WeaponDefs.Kind.MELEE:
				note = "Reach %.1f m, %.1f hits a second, up to %d enemies a swing" % [float(d["range"]), 1.0 / float(d["rate"]), int(d["max_hits"])]
			WeaponDefs.Kind.RANGED:
				note = "Range %d m, %.1f shots a second" % [int(d["range"]), 1.0 / float(d["rate"])]
			WeaponDefs.Kind.SPELL:
				note = "Range %d m, %d mana a bolt" % [int(d["range"]), int(d["cost"])]
		_row(Icons.weapon(id), Color(0.4, 0.34, 0.26), d["name"], d["desc"], note)
