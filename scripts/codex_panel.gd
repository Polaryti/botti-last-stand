class_name CodexPanel
extends Control
## The player's field notes: who you can be, what lives out there, and what can be found.

signal closed

const TABS := ["Classes", "Weapons", "Items", "Familiars", "Enemies", "Status Effects", "Maps"]

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
	UiTheme.fit_safe_area(margin, 40, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TABS[i]
		tab.toggle_mode = false
		tab.custom_minimum_size = Vector2(110, 52)
		tab.add_theme_font_size_override("font_size", 20)
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
	close.add_theme_font_size_override("font_size", 20)
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
	_scroll.scroll_to(0)
	match index:
		0: _classes()
		1: _weapons()
		2: _items()
		3: _familiars()
		4: _enemies()
		5: _statuses()
		6: _maps()


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
		var note := "%s. Paths: %s." % [ClassPresentation.stats_line(id), ", ".join(paths)]
		if not Game.owns_class(id):
			note += " " + acquisition(id)
		_row(ClassDefs.icon(id), ClassDefs.color(id), d["name"], ClassPresentation.description(id), note)
		_list.get_child(-1).get_child(1).add_child(ClassPresentation.weapon_tags(id))


## Families are kept together; alphabetical order is only used within a family.
static func enemy_group(id: String) -> int:
	var d: Dictionary = ZombieDefs.ALL[id]
	if d.get("mist_boss", false) or d.get("mesenlla_boss", false): return 5
	if SpawnRules.is_mesenlla(d): return 4
	if d.get("maps", []).has("mists"): return 3
	if d.get("hero", false) or d.get("rider", false): return 2
	if id in ["normal", "clever", "magic", "beast", "leaper"]: return 0
	return 1

func _enemies() -> void:
	var order: Array = ZombieDefs.ALL.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		var ga := enemy_group(a)
		var gb := enemy_group(b)
		if ga != gb: return ga < gb
		if ga == 0: return ["normal", "clever", "leaper", "magic", "beast"].find(a) < ["normal", "clever", "leaper", "magic", "beast"].find(b)
		return str(ZombieDefs.ALL[a]["name"]).naturalnocasecmp_to(str(ZombieDefs.ALL[b]["name"])) < 0)
	var previous := -1
	for id: String in order:
		var group := enemy_group(id)
		if group != previous:
			_section(["The undead", "Hunters and horrors", "Fallen heroes", "Creatures of The Mists", "Creatures of Mesenlla", "Bosses"][group])
			previous = group
		var d: Dictionary = ZombieDefs.ALL[id]
		var locations := PackedStringArray()
		for map_id: String in d.get("maps", []): locations.append({"mists": "The Mists", "village": "The Village", "fort": "The Fort", "mesenlla": "Valleys of Mesenlla", "bastion": "Mist Bastion"}.get(map_id, map_id.capitalize()))
		var note := "Health %d, %d XP" % [int(d["hp"]), int(d["xp"])]
		var from: float = d.get("from", -1.0)
		if d.get("mist_boss", false) or d.get("mesenlla_boss", false):
			note += ". Boss encounter"
		elif from > 0.0:
			note += ". Appears from %d:%02d" % [int(from) / 60, int(from) % 60]
		_row(d["icon"], d.get("tint", Color(0.34, 0.34, 0.38)).darkened(0.1), d["name"], d["desc"], note)
		_map_badge(d, d.get("maps", []).has("village"))

func _map_badge(data: Dictionary, _green := true) -> void:
	if not data.has("maps"): return
	_list.get_child(-1).get_child(1).add_child(ClassPresentation.map_tag(data))

func _section(title: String) -> void:
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", UiTheme.EMBER)
	_list.add_child(label)


func _familiars() -> void:
	for id: String in PowerDefs.ALL:
		var d: Dictionary = PowerDefs.ALL[id]
		if d["familiar"]:
			_row(Icons.power(id), Color(d["color"]).darkened(0.35), d["name"], d["desc"], "Base duration: %d seconds" % int(d["time"]))
			_map_badge(d)


func _items() -> void:
	for id: String in PowerDefs.ALL:
		var d: Dictionary = PowerDefs.ALL[id]
		if not d["familiar"]:
			_row(Icons.power(id), Color(d["color"]).darkened(0.35), d["name"] if d.has("spec") else "%s Potion" % d["name"], d["desc"], "Base duration: %d seconds" % int(d["time"]))


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
		var tags := HFlowContainer.new()
		tags.add_theme_constant_override("h_separation", 8)
		var cat := WeaponDefs.category(id)
		tags.add_child(ClassPresentation.tag(WeaponDefs.CATEGORY_NAMES[cat], cat))
		if d.has("maps"):
			tags.add_child(ClassPresentation.map_tag(d))
		_list.get_child(-1).get_child(1).add_child(tags)


static func acquisition(id: String) -> String:
	if ClassDefs.disabled(id):
		return "Not available at this time."
	var earned := Game.earn_text(id)
	if earned != "":
		return earned
	if ClassDefs.price(id) > 0:
		return "Available in the Store."
	if id == "commander":
		return "First prize in VRAIN tournaments. Redeem the prize code to unlock."
	if ClassDefs.ALL[id].get("unavailable", false):
		return "Unlocked by redeeming a class code."
	return "Available from the start."

## General conditions only. Profession skills remain in their class trees.
func _statuses() -> void:
	for entry: Dictionary in StatusCatalog.TIMED:
		if entry["field"] not in ["burn_time", "bleed_left", "poison_left", "slowed_left", "invis_left", "invis_lockout", "night_blind_left", "guard_left"]: continue
		_row(entry["icon"], UiTheme.BLOOD if entry["field"] in ["burn_time", "bleed_left", "poison_left", "night_blind_left"] else UiTheme.MIST, entry["name"], entry["desc"])
	_row("status_frozen", UiTheme.MIST, "Frozen", "Ice prevents movement until its timer ends. You can still look around.")
	_row("status_stunned", UiTheme.EMBER, "Stunned", "An impact briefly interrupts movement until its timer ends.")

func _maps() -> void:
	_row("map_village", UiTheme.BONE, "The Village", "The first village to be overrun and razed by the zombie hordes.")
	_row("map_fort", UiTheme.BONE, "The Fort", "The last bastion protecting the portal to The Mists.")
	_row("map_mists", UiTheme.MIST, "The Mists", "The heart of mysterious worlds lying beyond our own.")
	_row("map_mesenlla", Color(0.91, 0.63, 0.3), "Valleys of Mesenlla", "Fleeing a collapsed world and having conquered the heart of the Mists, new paths open to distant lands through its portals. The first leads to a mountain outpost under an endless twilight. Survive the night there, alone, together or against each other.")
	_map_badge({"maps": ["mesenlla"]})
