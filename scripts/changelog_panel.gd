class_name ChangelogPanel
extends Control
## The game notes: what changed in each version, newest first. Read from CHANGELOG.md, so the game
## and the repository always say the same thing.
##
## Laid out to be scanned rather than read through: the versions down the left, one to a row, with
## a dot for each kind of change in it; the chosen version on the right, its name and date, a count
## of its changes by kind, and a card for each part of it. Each card is marked with the icon and the
## colour of what it is about (CATEGORIES): new content, classes and weapons, enemies and bosses, maps,
## the Store, playing together, the look of the game, fixes. A change's lead words (**bold** in the
## file) stand out from the rest of it.

signal closed

const PATH := "res://CHANGELOG.md"
const RAIL_WIDTH := 330.0
const PER_FRAME := 18 # changes built each frame once the first cards are up
const FIRST_BUILT := 28 # changes built at once, when a version opens
## What a part of a version is about, from words in its heading: [words, name, icon, colour]. The first
## that matches wins, so the more particular come first.
const CATEGORIES := [
	[["fix", "bug", "steadier", "fairer", "smoother", "review"], "Fixes", "gear", Color("7fc08a")],
	[["spectator", "together", "online", "multiplayer", "versus", "lobby", "watch"], "Playing together", "link", Color("6fb6d6")],
	[["store", "armory", "shop", "doubloon", "prize", "leaderboard", "redeem"], "Store", "crown", Color("e8c25a")],
	[["boss", "enem", "creature", "wild", "beast", "wyvern", "bear", "words"], "Enemies", "skull", Color("d8604a")],
	[["class", "upgrade", "path", "weapon", "beastmaster", "abilit", "familiar", "item", "found"], "Classes and items", "up", Color("efa93f")],
	[["map", "valley", "bastion", "mists", "village", "fort", "world", "mesenlla", "vael", "harbour", "tide", "lantern", "fontanova", "island", "archipelago"], "Maps", "compass", Color("a880ff")],
	[["screen", "menu", "icon", "look", "graphic", "performance", "sound", "music", "number", "seeing", "hud", "changelog", "setting", "control"], "Look and feel", "eye", Color("8fb0e6")],
]
const OTHER := ["", "Changes", "plus", Color("a9b0bd")]
static var _notes: Array[Dictionary] = []
var _versions: Array[Dictionary] = []
var _rail: VBoxContainer
var _body: VBoxContainer
var _scroll: DragScroll
var _chosen := -1
var _queue: Array = [] # [card, entry] still to build for the chosen version


func build() -> void:
	var parts := UiScreen.frame(self, "Changelog", func() -> void: closed.emit(), "What changed in each version, newest first.")
	var page := UiScreen.page(parts["box"])
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", UiTheme.GAP)
	page.add_child(panes)
	var rail_scroll := DragScroll.new()
	rail_scroll.name = "Versions"
	rail_scroll.custom_minimum_size.x = RAIL_WIDTH
	rail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_child(rail_scroll)
	_rail = VBoxContainer.new()
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	rail_scroll.add_child(_rail)
	_scroll = DragScroll.new()
	_scroll.name = "Notes"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UiTheme.GAP)
	_scroll.add_child(_body)
	_versions = versions(notes())
	for i in _versions.size():
		_rail.add_child(_version_button(i))
	if not _versions.is_empty():
		show_version(0)


## What the notes say now, in short: when it differs from what was last read, there is something new.
static func signature() -> String:
	return FileAccess.get_file_as_string(PATH).md5_text()


## Whether the notes have changed since they were last opened. A phone that has never finished a game
## is new to all of it, so nothing is flagged as new there; it simply takes note of the notes as they are.
static func has_news() -> bool:
	if Game.changelog_seen == "":
		if Game.finished_games == 0:
			mark_read()
			return false
		return true
	return Game.changelog_seen != signature()


static func mark_read() -> void:
	Game.changelog_seen = signature()
	Game.save_settings()


## The notes, read once.
static func notes() -> Array[Dictionary]:
	if _notes.is_empty():
		_notes = parse(FileAccess.get_file_as_string(PATH))
	return _notes


## "## 0.8.0 — Name (3 November 2026)" starts a version, "### New" a part of it, "- " one change
## ("  - " one under the change before it), and any other line is said about the part it is in.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("## "):
			out.append({"kind": "version", "text": line.substr(3)})
		elif line.begins_with("### "):
			out.append({"kind": "part", "text": line.substr(4)})
		elif line.begins_with("- "):
			out.append({"kind": "item", "text": line.substr(2), "sub": raw.begins_with(" ") or raw.begins_with("\t")})
		elif line != "" and not line.begins_with("#") and not out.is_empty():
			out.append({"kind": "text", "text": line})
	return out


## The notes as versions: {number, name, date, intro, parts: [{title, category, entries}]}. Lines of
## text before a version's first part are its intro, shown above its cards rather than in one.
static func versions(entries: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		match e["kind"]:
			"version":
				out.append(_version_head(str(e["text"])))
			"part":
				if not out.is_empty():
					(out.back()["parts"] as Array).append({"title": e["text"], "category": category(str(e["text"])), "entries": []})
			_:
				if out.is_empty():
					continue
				var parts: Array = out.back()["parts"]
				if parts.is_empty() and e["kind"] == "text":
					(out.back()["intro"] as Array).append(str(e["text"]))
					continue
				if parts.is_empty():
					parts.append({"title": "Changes", "category": OTHER, "entries": []})
				(parts.back()["entries"] as Array).append(e)
	return out


## "0.21.4 — A Portal Worth Defending (11 November 2026)" → its number, its name and its date.
static func _version_head(text: String) -> Dictionary:
	var number := text
	var name := ""
	var date := ""
	var dash := text.find(" — ")
	if dash >= 0:
		number = text.substr(0, dash)
		name = text.substr(dash + 3)
	var open := (name if dash >= 0 else number).rfind(" (")
	if open >= 0 and text.ends_with(")"):
		if dash >= 0:
			date = name.substr(open + 2, name.length() - open - 3)
			name = name.substr(0, open)
		else:
			date = number.substr(open + 2, number.length() - open - 3)
			number = number.substr(0, open)
	return {"number": number, "name": name, "date": date, "intro": [], "parts": []}


## What a part is about, from its heading (CATEGORIES).
static func category(title: String) -> Array:
	var t := title.to_lower()
	for c: Array in CATEGORIES:
		for word: String in c[0]:
			if t.contains(word):
				return c
	return OTHER


## How many changes a version has.
static func count(v: Dictionary) -> int:
	var n := 0
	for part: Dictionary in v["parts"]:
		n += (part["entries"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "item").size()
	return n


func _version_button(i: int) -> Button:
	var v := _versions[i]
	var b := Button.new()
	b.name = "Version_%d" % i
	b.custom_minimum_size = Vector2(RAIL_WIDTH - 12.0, 84.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16.0
	box.offset_right = -12.0
	box.offset_top = 8.0
	b.add_child(box)
	var developing := str(v["number"]).begins_with("Development") or str(v["number"]).begins_with("Previous")
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.add_child(_text("In development" if developing else str(v["number"]), UiTheme.FS_BODY, UiTheme.TWILIGHT if developing else UiTheme.BONE, UiTheme.bold_font()))
	# A dot for each kind of change it has, in that kind's colour.
	var kinds := {}
	for part: Dictionary in v["parts"]:
		kinds[part["category"][1]] = part["category"][3]
	var dots := HBoxContainer.new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.add_theme_constant_override("separation", 3)
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.alignment = BoxContainer.ALIGNMENT_END
	for col: Color in kinds.values():
		var dot := ColorRect.new()
		dot.color = col
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	head.add_child(dots)
	var sub := str(v["name"]) if str(v["name"]) != "" else str(v["date"])
	if developing:
		sub = sub.trim_prefix("Beyond the Mists, ")
		sub = sub.left(1).to_upper() + sub.substr(1)
	var line := _text(sub, UiTheme.FS_SMALL, UiTheme.ASH)
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(line)
	var index := i
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click", -5.0)
		show_version(index))
	return b


## The chosen version on the right: its head, a count of its changes by kind, and a card for each part.
func show_version(i: int) -> void:
	_chosen = i
	for k in _rail.get_child_count():
		var b := _rail.get_child(k) as Button
		if k == i:
			UiTheme.selected(b)
		else:
			UiTheme.plain(b)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_queue.clear()
	var v := _versions[i]
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	_body.add_child(head)
	var developing := str(v["number"]).begins_with("Development") or str(v["number"]).begins_with("Previous")
	var title := str(v["name"]) if str(v["name"]) != "" else str(v["number"])
	head.add_child(_text(title, UiTheme.FS_HEAD, UiTheme.BONE, UiTheme.title_font(), true))
	var meta := "In development, not yet released" if developing else ("Version %s" % v["number"] + (", %s" % v["date"] if str(v["date"]) != "" else ""))
	head.add_child(_text(meta, UiTheme.FS_SMALL, UiTheme.TWILIGHT if developing else UiTheme.ASH))
	for line: String in v["intro"]:
		var intro := _rich(line, UiTheme.BONE)
		intro.name = "Intro"
		head.add_child(intro)
	# The count by kind: a chip for each.
	var tally := {}
	for part: Dictionary in v["parts"]:
		var c: Array = part["category"]
		if not tally.has(c[1]):
			tally[c[1]] = [c, 0]
		tally[c[1]][1] += (part["entries"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "item").size()
	var chips := HFlowContainer.new()
	chips.name = "Tally"
	chips.add_theme_constant_override("h_separation", UiTheme.GAP_SMALL)
	chips.add_theme_constant_override("v_separation", UiTheme.GAP_SMALL)
	_body.add_child(chips)
	for key: String in tally:
		var c: Array = tally[key][0]
		chips.add_child(_chip(c, int(tally[key][1])))
	for part: Dictionary in v["parts"]:
		var card := _card(part)
		_body.add_child(card)
		for e: Dictionary in part["entries"]:
			_queue.append([card.get_meta("list"), e, part["category"][3]])
	# The first changes at once, the rest a few at a time while the top is being read.
	_build_queued(FIRST_BUILT)
	_scroll.scroll_to(0.0)


func _process(_delta: float) -> void:
	if not _queue.is_empty():
		_build_queued(PER_FRAME)


func _build_queued(n: int) -> void:
	for k in mini(n, _queue.size()):
		var q: Array = _queue.pop_front()
		if is_instance_valid(q[0]):
			_entry(q[0], q[1], q[2])


func _chip(c: Array, n: int) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiTheme.flat(Color(c[3], 0.14), Color(c[3], 0.55), UiTheme.RADIUS, 6.0, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var icon := IconView.new(c[2], Color(c[3]).darkened(0.55), 30.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(_text("%s  %d" % [c[1], n], UiTheme.FS_SMALL, UiTheme.BONE, UiTheme.bold_font()))
	return chip


## A part of a version: a bar in its colour down its left edge, its icon and heading, and its changes.
func _card(part: Dictionary) -> PanelContainer:
	var c: Array = part["category"]
	var col: Color = c[3]
	var card := PanelContainer.new()
	card.name = "Card"
	var style := UiTheme.flat(Color(UiTheme.DUSK, 0.92), col, UiTheme.RADIUS_CARD, 16.0, 0)
	style.border_width_left = 6
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var icon := IconView.new(c[2], col.darkened(0.55), 46.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	words.add_child(_text(str(part["title"]), UiTheme.FS_LEAD, UiTheme.BONE, UiTheme.bold_font(), true))
	var n := (part["entries"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "item").size()
	if str(part["title"]) != c[1]:
		words.add_child(_text("%s · %d %s" % [c[1], n, "change" if n == 1 else "changes"], UiTheme.FS_TINY, col.lightened(0.15)))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	card.set_meta("list", list)
	return card


func _entry(list: VBoxContainer, e: Dictionary, col: Color) -> void:
	var sub := bool(e.get("sub", false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	list.add_child(row)
	if e["kind"] == "text":
		row.add_child(_rich(str(e["text"]), UiTheme.ASH))
		return
	if sub:
		var indent := Control.new()
		indent.custom_minimum_size.x = 26.0
		row.add_child(indent)
	var mark := ColorRect.new()
	mark.color = col if not sub else Color(col, 0.55)
	mark.custom_minimum_size = Vector2(8, 8) if not sub else Vector2(6, 6)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", 12)
	holder.add_child(mark)
	row.add_child(holder)
	var full := str(e["text"])
	var short := brief(full)
	var words := _rich(short, UiTheme.BONE if not sub else UiTheme.BONE.darkened(0.08))
	if short == full:
		row.add_child(words)
		return
	# A long change shows its gist; "More" opens the rest of it.
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	stack.add_child(words)
	var more := Button.new()
	more.name = "More"
	more.text = "More"
	more.flat = true
	more.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	more.add_theme_font_size_override("font_size", UiTheme.FS_SMALL)
	more.add_theme_color_override("font_color", col.lightened(0.2))
	more.add_theme_color_override("font_hover_color", col.lightened(0.4))
	more.add_theme_color_override("font_pressed_color", col)
	more.custom_minimum_size.y = 36.0
	more.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	more.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	more.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	stack.add_child(more)
	more.pressed.connect(func() -> void:
		Sfx.play("ui_click", -6.0)
		var opening := more.text == "More"
		words.text = bbcode(full if opening else short)
		more.text = "Less" if opening else "More")


## A change, with its **lead words** in bold.
func _rich(text: String, col: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_theme_font_size_override("normal_font_size", UiTheme.FS_BODY)
	r.add_theme_font_size_override("bold_font_size", UiTheme.FS_BODY)
	r.add_theme_font_override("bold_font", UiTheme.bold_font())
	r.add_theme_font_override("italics_font", _italics())
	r.add_theme_font_size_override("italics_font_size", UiTheme.FS_BODY)
	r.add_theme_color_override("default_color", col)
	r.text = bbcode(text)
	return r


## The gist of a change: its **lead words** and the sentence after them, or its first sentence, when
## the whole of it is long. Short changes are shown whole.
const BRIEF := 170


static func brief(text: String) -> String:
	if text.length() <= BRIEF:
		return text
	var from := 0
	if text.begins_with("**"):
		from = text.find("**", 2) + 2
	# The first full stop or semicolon after the lead words.
	var stop := -1
	for mark: String in [". ", "; "]:
		var at := text.find(mark, maxi(from + 1, 30))
		if at >= 0 and (stop < 0 or at < stop):
			stop = at
	var gist := text.substr(0, stop + 1).trim_suffix(";") + ("…" if stop >= 0 and text[stop] == ";" else "") if stop >= 0 else text
	if (gist.length() > BRIEF + 120 or stop < 0) and from > 2:
		gist = text.substr(0, from) # just its lead words
	return gist if gist.length() < text.length() - 20 else text


## Markdown's **bold** and *italics* as BBCode, with any square brackets in the words kept as they are.
static func bbcode(text: String) -> String:
	var safe := text.replace("[", "[lb]")
	var out := ""
	var bold := false
	var italic := false
	var parts := safe.split("**")
	for i in parts.size():
		if i > 0:
			out += "[/color][/b]" if bold else "[b][color=#ffffff]"
			bold = not bold
		var bits := parts[i].split("*")
		for k in bits.size():
			if k > 0:
				out += "[/i]" if italic else "[i]"
				italic = not italic
			out += bits[k]
	if italic:
		out += "[/i]"
	if bold:
		out += "[/color][/b]"
	return out


static var _slanted: FontVariation

## The body font slanted, for *italics*.
static func _italics() -> Font:
	if _slanted == null:
		_slanted = FontVariation.new()
		_slanted.base_font = load("res://assets/fonts/FiraSans-Medium.ttf")
		_slanted.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)
	return _slanted


func _text(t: String, fs: int, col: Color, font: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
