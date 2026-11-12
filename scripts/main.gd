class_name Main
extends Node
## Top-level flow: menu, game, pause, game over.

var world: World
var hud: Hud
var ui_layer: CanvasLayer
var panel: Control
var _theme: Theme
var tree_panel: TreePanel
var _together_tab := 0
var _run_over := false
var _back := Callable() # what the phone's back button does on the current screen
var _store_return := Callable() # where the Store's Back goes
var _start_listed := true # online: a new game is public unless you choose private
var updates: Updates
var _update_box: HBoxContainer
var _checked_updates := false
var _pause_root: Control
var _net_go := false

const TOGETHER_TABS := ["Same Wi-Fi", "Hotspot", "Online"]
const ONLINE_TAB := 2
const TIPS := [
	"Push the stick halfway to walk quietly.",
	"Zombies see you much less in tall wheat.",
	"Roofs stop crows and gargoyles.",
	"Some weapons on the ground bite back.",
	"A scarecrow only walks while you look away.",
	"Stop a Banshee before she calls the horde.",
	"Fire hurts a Wraith twice as much.",
	"Fallen Heroes grow stronger every minute, and drop their weapon.",
	"The night does not wait: open the tree somewhere safe.",
	"The bell strikes once for each minute gone, and draws zombies to the church.",
	"Beasts track by scent. Hiding only delays them.",
	"A chime means a familiar has appeared close by. Look for its light.",
	"In the last two minutes, everything comes for you. Save your strength.",
	"Out of arrows or mana? You can still hit with what you hold.",
	"The river can only be crossed on the bridges and at the ford, and it pulls you downstream.",
	"The castle has one road up, and several holes in its walls.",
	"Corn hides you better than anything. It also hides them.",
	"Firelight warms you, and everything out there can see you in it.",
	"A crow calls out before it dives. Step aside, then hit it while it hangs low.",
	"In the fort, carry wood close to a damaged gate and it mends as you stand there.",
	"Only you fit through the fort's small doors. Enemies have to break a gate.",
	"Drop off the fort's walls when you need to get out fast. It does not hurt.",
	"A Dread Rider is open to a blow while it turns.",
	"In a storm, run from a glow on the ground. Lightning follows it.",
	"Lure them under the lightning: it hurts them far more than it hurts you.",
	"In All vs All the fog comes for everyone. Watch the map, and be inside before it closes.",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The Android back button should pause, not close the game mid-run.
	get_tree().quit_on_go_back = false
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_theme = UiTheme.make()
	Net.game_started.connect(func() -> void: start_game(Net.game_mode()))
	Net.left.connect(_on_net_left)
	Net.game_over.connect(_on_net_over)
	Net.all_ready.connect(func() -> void: _net_go = true)
	Net.back_in_room.connect(_return_to_room)
	Board.counted.connect(func(result: Dictionary) -> void:
		_counted = result
		_apply_board_note())
	updates = Updates.new()
	add_child(updates)
	if Game.test_map != "":
		# Someone pressed F6 on a map in the editor, so go straight to it.
		var map := Game.test_map
		start_game(Game.Mode.SANDBOX if map.contains("sandbox") else (Game.Mode.FORT if map.contains("fort") or map.contains("bastion") else Game.Mode.NIGHT))
		return
	show_menu()


func _quit() -> void:
	get_tree().quit()


func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_ui() -> void:
	for c in ui_layer.get_children():
		c.queue_free()
	panel = null
	hud = null
	tree_panel = null


func _clear_world() -> void:
	if world:
		world.queue_free()
		world = null


func _new_world(mode: int) -> void:
	_clear_world()
	world = World.new()
	add_child(world)
	world.setup(mode)


func show_menu(rebuild := false) -> void:
	get_tree().paused = false
	Net.leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_ui()
	Game.mode = Game.Mode.MENU
	_back = _quit
	# Coming back from another menu screen, the Valleys behind it can simply stay.
	if rebuild or world == null or world.mode != Game.Mode.MENU:
		_new_world(Game.Mode.MENU)
	Sfx.ambient(true)
	Sfx.set_mood(0.0, 0.0)
	var root := Control.new()
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var shade := TextureRect.new()
	shade.texture = load("res://assets/ui/menu_shade.png")
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	_fill(shade)
	var margin := _screen_margin(64, 26)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	margin.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/ui/wordmark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(590, 80)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(mark)
	var update_title := _label("Beyond the Mists", 27, UiTheme.EMBER)
	update_title.name = "UpdateTitle"
	update_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(update_title)
	top.add_child(_expand())
	top.add_child(_name_button())
	top.add_child(_purse_button())
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	box.add_child(gap)
	box.add_child(_menu_row("Survive the Night", "Ten minutes until dawn.", func() -> void: show_map_picker(), true))
	box.add_child(_menu_row("Defend the Fort", "Hold the gates. Protect the portal.", func() -> void: show_fort_picker()))
	box.add_child(_menu_row("Play Together", "Up to four phones, nearby or online.", show_together))
	box.add_child(_menu_row("Armory", "What you own for each class, and your pet.", func() -> void: show_armory()))
	box.add_child(_menu_row("Leaderboard", "The top players of all time, and of this week.", func() -> void: show_leaderboard()))
	box.add_child(_menu_row("Sandbox", "Try any weapon, item or class you own.", func() -> void: show_class_picker(Game.Mode.SANDBOX)))
	box.add_child(_expand(true))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	# Where a new version shows, when there is one.
	_update_box = HBoxContainer.new()
	_update_box.add_theme_constant_override("separation", 10)
	_update_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_update_box)
	if not updates.changed.is_connected(_fill_update_box):
		updates.changed.connect(_fill_update_box)
	_fill_update_box()
	if not _checked_updates:
		_checked_updates = true
		updates.check()
	foot.add_child(_button("Codex", show_codex, Vector2(132, 56)))
	foot.add_child(_button("Changelog", show_changelog, Vector2(168, 56)))
	foot.add_child(_button("Settings", show_settings, Vector2(146, 56)))
	var version := _soft("v%s" % ProjectSettings.get_setting("application/config/version"), 20)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(version)
	panel = root
	if Board.needs_name() and _asks_for_name():
		show_name_prompt(true)
	elif _asks_for_name():
		_collect_prizes()


## A new version on the game's page: on Android, one tap fetches it and Android asks to install it.
## On an iPhone, where the game cannot install itself, it says where to find it.
func _fill_update_box() -> void:
	if _update_box == null or not is_instance_valid(_update_box):
		return
	for c in _update_box.get_children():
		_update_box.remove_child(c)
		c.queue_free()
	var line := ""
	var action := ""
	var press := Callable()
	match updates.state:
		Updates.State.AVAILABLE:
			if Updates.can_install():
				line = "Version %s is out." % updates.latest
				action = "Update"
				press = updates.download
			else:
				line = "Version %s is out. Install it the way you installed this one." % updates.latest
				action = "See it"
				press = func() -> void: OS.shell_open(updates.page)
		Updates.State.DOWNLOADING:
			line = "Downloading version %s: %d%%" % [updates.latest, roundi(updates.progress() * 100.0)]
			get_tree().create_timer(0.3).timeout.connect(_fill_update_box)
		Updates.State.READY:
			line = "Version %s is ready." % updates.latest
			action = "Install"
			press = updates.install
		Updates.State.FAILED:
			line = updates.problem
			action = "Try again"
			press = updates.download
	if line == "":
		return
	var l := _body(line, 22)
	l.add_theme_color_override("font_color", UiTheme.EMBER)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_box.add_child(l)
	if action != "":
		_update_box.add_child(_button(action, press, Vector2(150, 56), true))


## A margin that also keeps clear of the camera cut-out, on whichever side it is.
func _screen_margin(side: int, top_bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	UiTheme.fit_safe_area(margin, side, top_bottom)
	_fill(margin)
	return margin


func _expand(tall := false) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tall:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## One way to play: a large name and what it means, with nothing around it until you touch it.
func _menu_row(title: String, line: String, action: Callable, first := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(680, 80)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var clear := UiTheme.flat(Color(0, 0, 0, 0), Color.TRANSPARENT, 8, 12.0)
	b.add_theme_stylebox_override("normal", clear)
	b.add_theme_stylebox_override("hover", clear)
	var held := UiTheme.flat(Color(UiTheme.EMBER, 0.2), Color.TRANSPARENT, 8, 12.0)
	b.add_theme_stylebox_override("pressed", held)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", -2)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(words)
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var head := _label(title, 38, UiTheme.EMBER if first else UiTheme.BONE)
	head.add_theme_font_override("font", UiTheme.bold_font())
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(head)
	var sub := _soft(line, 23)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(sub)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -3.0))
	b.pressed.connect(action)
	return b


## How many doubloons you have. It is also the way to the Store.
func _purse_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_child(_coin(44.0))
	var count := _label("%d" % Game.doubloons, 30, UiTheme.BONE)
	count.add_theme_font_override("font", UiTheme.bold_font())
	row.add_child(count)
	var word := _soft("Store", 26)
	word.add_theme_color_override("font_color", UiTheme.EMBER)
	row.add_child(word)
	b.custom_minimum_size.x = 64.0 + 44.0 + 30.0 + _text_width(str(Game.doubloons), 30) + _text_width("Store", 26)
	for c in row.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -3.0))
	b.pressed.connect(func() -> void: show_store())
	return b


func _text_width(text: String, fs: int) -> float:
	return UiTheme.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _coin(px: float) -> TextureRect:
	var c := TextureRect.new()
	c.texture = load("res://assets/ui/doubloon.png")
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.custom_minimum_size = Vector2.ONE * px
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _vignette() -> TextureRect:
	var v := TextureRect.new()
	v.texture = load("res://assets/ui/vignette.png")
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func show_settings(from_pause := false) -> void:
	var root := _modal("Settings")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 800
	var close := func() -> void:
		root.queue_free()
		_back = _resume if from_pause else _quit
	_back = close
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	_slider(left, "Look sensitivity", 0.4, 2.5, Game.sensitivity, func(v: float) -> void: Game.sensitivity = v)
	_slider(left, "Music", 0.0, 1.0, Game.music_volume, func(v: float) -> void:
		Game.music_volume = v
		Sfx.apply_volumes())
	_slider(left, "Sounds", 0.0, 1.0, Game.sound_volume, func(v: float) -> void:
		Game.sound_volume = v
		Sfx.apply_volumes())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	right.add_child(_toggle("Auto-jump", func() -> bool: return Game.auto_jump, func(on: bool) -> void: Game.auto_jump = on))
	right.add_child(_toggle("Vibration", func() -> bool: return Game.vibration, func(on: bool) -> void: Game.vibration = on))
	right.add_child(_toggle("Steady brightness", func() -> bool: return Game.steady_brightness, func(on: bool) -> void:
		Game.steady_brightness = on
		PhoneScreen.apply_brightness()))
	_slider(left, "Screen brightness, when steady", 0.1, 1.0, Game.brightness if Game.brightness > 0.0 else PhoneScreen.current_level(), func(v: float) -> void:
		Game.brightness = v
		PhoneScreen.apply_brightness())
	if not from_pause:
		# Both of these only apply to a new night, so they stay out of a running game.
		left.add_child(_soft("Difficulty", 23))
		left.add_child(_choices(["Easy", "Normal", "Hard"], Game.difficulty, 380.0, func(i: int) -> void:
			Game.difficulty = i
			Game.save_settings()
			root.queue_free()
			show_settings()))
		right.add_child(_soft("Graphics", 23))
		right.add_child(_choices(["Low", "Medium", "High"], Game.quality, 380.0, func(i: int) -> void:
			Game.quality = i
			Game.apply_quality()
			Game.save_settings()
			show_menu(true)))
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", 8)
		box.add_child(code_row)
		var code := LineEdit.new()
		code.placeholder_text = "Redeem a code"
		code.custom_minimum_size = Vector2(290, 58)
		code.add_theme_font_size_override("font_size", 24)
		code_row.add_child(code)
		var answer := _soft("", 22)
		code_row.add_child(_button("Redeem", func() -> void: _try_code(code, answer), Vector2(140, 58)))
		answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		code_row.add_child(answer)
	box.add_child(_button("Done", close, Vector2(800, 60), true))


func _try_code(code: LineEdit, answer: Label) -> void:
	if code.text.strip_edges() == "":
		return
	var said := Game.redeem(code.text)
	match str(said["result"]):
		"opened":
			answer.text = "%s unlocked." % ClassDefs.ALL[said["class"]]["name"]
			answer.add_theme_color_override("font_color", UiTheme.MOSS)
			code.text = ""
			Sfx.play("level", -3.0)
		"disabled":
			answer.text = "%s is not available at this time. Keep the code for later." % ClassDefs.ALL[said["class"]]["name"]
			answer.add_theme_color_override("font_color", UiTheme.ASH)
		"used":
			answer.text = "This code has already been redeemed."
			answer.add_theme_color_override("font_color", UiTheme.ASH)
		_:
			answer.text = "That code does not work. Check the spelling."
			answer.add_theme_color_override("font_color", UiTheme.BLOOD.lightened(0.25))


## A row of options, one of them on.
func _choices(names: Array, on: int, width: float, picked: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i in names.size():
		var index := i
		var b := _button(str(names[i]), func() -> void: picked.call(index), Vector2((width - 6.0 * (names.size() - 1)) / names.size(), 54))
		b.add_theme_font_size_override("font_size", 24)
		if i == on:
			UiTheme.selected(b)
		row.add_child(b)
	return row


func _slider(box: VBoxContainer, title: String, low: float, high: float, value: float, changed: Callable) -> void:
	box.add_child(_soft(title, 23))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(360, 44)
	slider.value_changed.connect(func(v: float) -> void:
		changed.call(v)
		Game.save_settings())
	box.add_child(slider)


## A name on the left, and whether it is on at the right.
func _toggle(title: String, read: Callable, write: Callable) -> Button:
	var b := _button("", func() -> void: pass, Vector2(380, 58))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	var name_label := _body(title, 24)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var state := _body("", 24)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.add_theme_font_override("font", UiTheme.bold_font())
	row.add_child(state)
	var show_state := func() -> void:
		var on: bool = read.call()
		state.text = "On" if on else "Off"
		state.add_theme_color_override("font_color", UiTheme.EMBER if on else UiTheme.ASH)
	show_state.call()
	b.pressed.connect(func() -> void:
		write.call(not read.call())
		Game.save_settings()
		show_state.call())
	return b


func show_codex() -> void:
	_clear_ui()
	var c := CodexPanel.new()
	c.theme = _theme
	ui_layer.add_child(c)
	_fill(c)
	c.build()
	c.closed.connect(show_menu)
	_back = show_menu
	panel = c


## What changed in each version, read from CHANGELOG.md so the game and the repository always agree.
func show_changelog() -> void:
	_clear_ui()
	var c := ChangelogPanel.new()
	c.theme = _theme
	ui_layer.add_child(c)
	_fill(c)
	c.build()
	c.closed.connect(show_menu)
	_back = show_menu
	panel = c


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Plain text, for a panel.
func _body(text: String, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", UiTheme.BONE)
	return l


## Quieter text.
func _soft(text: String, fs: int) -> Label:
	var l := _body(text, fs)
	l.add_theme_color_override("font_color", UiTheme.ASH)
	return l


func _button(text: String, action: Callable, min_size: Vector2, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 26)
	if primary:
		UiTheme.primary(b)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -3.0))
	b.pressed.connect(action)
	return b


# --- Choosing a class, and the Store ------------------------------------------

## The list of classes on the left, what the chosen one is on the right.
## Where to spend the night.
func show_map_picker() -> void:
	_show_atlas(Game.Mode.NIGHT)


## Which stronghold to hold.
func show_fort_picker() -> void:
	_show_atlas(Game.Mode.FORT)


## Where to play, chosen on the world atlas: the places this mode can be played in are lit, the rest
## dimmed. Tapping a place shows what it is; Play here goes on to choosing a class.
func _show_atlas(mode: int) -> void:
	_clear_ui()
	_back = show_menu
	var fort := mode == Game.Mode.FORT
	var root := Control.new()
	root.name = "Atlas"
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var shade := _vignette()
	root.add_child(shade)
	_fill(shade)
	var margin := _screen_margin(44, 18)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	top.add_child(_button("Back", func() -> void: _back.call(), Vector2(116, 56)))
	var head := _label("Defend the Fort" if fort else "Survive the Night", 40, UiTheme.BONE)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(head)
	var ask := _label("Where will you hold the line?" if fort else "Where will you spend the night?", 24, UiTheme.ASH)
	ask.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ask)
	var panes := HBoxContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_theme_constant_override("separation", 16)
	box.add_child(panes)
	var allowed: Array = (Game.FORT_MAPS if fort else Game.MAPS).keys()
	var atlas := WorldAtlas.new(allowed, Game.fort_map if fort else Game.night_map)
	atlas.name = "WorldAtlas"
	atlas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atlas.size_flags_stretch_ratio = 1.9
	panes.add_child(atlas)
	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panes.add_child(page)
	var detail := VBoxContainer.new()
	detail.name = "PlaceDetail"
	detail.add_theme_constant_override("separation", 10)
	page.add_child(detail)
	var show_place := func(id: String) -> void:
		for c in detail.get_children():
			detail.remove_child(c) # at once, so the new page's names (PlayHere) are never taken
			c.queue_free()
		var place: Dictionary = Places.ALL[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		detail.add_child(row)
		row.add_child(IconView.new(place["icon"], (place["color"] as Color).darkened(0.55), 64.0))
		var title := _label(place["name"], 34, UiTheme.BONE)
		title.add_theme_font_override("font", UiTheme.title_font())
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		if id in SpawnRules.MESENLLA:
			var tag := ClassPresentation.map_tag({"maps": [id]})
			tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			detail.add_child(tag)
		var lore := _label(place["lore"], 23, UiTheme.ASH)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size.x = 300
		detail.add_child(lore)
		var plays := _label("Played in %s." % place["plays"], 20, UiTheme.BONE.darkened(0.15))
		plays.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plays.custom_minimum_size.x = 300
		detail.add_child(plays)
		detail.add_child(_expand(true))
		var chosen := id
		var go := _button("Play here", func() -> void:
			if fort:
				Game.fort_map = chosen
			else:
				Game.night_map = chosen
			Game.save_settings()
			show_class_picker(mode), Vector2(0, 64), true)
		go.name = "PlayHere"
		detail.add_child(go)
	atlas.picked.connect(show_place)
	show_place.call(atlas.selected)
	panel = root


func show_class_picker(mode: int) -> void:
	_clear_ui()
	_back = show_map_picker if mode == Game.Mode.NIGHT else show_fort_picker if mode == Game.Mode.FORT else show_menu
	var root := _two_panes("Choose your class")
	var list: VBoxContainer = root.get_meta("list")
	var detail: VBoxContainer = root.get_meta("detail")
	var ids := ClassDefs.ALL.keys().filter(func(id: String) -> bool: return not ClassDefs.disabled(id))
	if mode == Game.Mode.SANDBOX:
		ids = ClassDefs.available()
	var rows := {}
	var pick := func(id: String) -> void:
		for other: String in rows:
			(rows[other] as Button).remove_theme_stylebox_override("normal")
			(rows[other] as Button).remove_theme_stylebox_override("hover")
		UiTheme.selected(rows[id])
		_fill_class_detail(detail, id, mode)
	for id: String in ids:
		var row := _class_row(id)
		rows[id] = row
		var chosen := id
		row.pressed.connect(func() -> void:
			Sfx.play("ui_click", -5.0)
			pick.call(chosen))
		list.add_child(row)
	pick.call(Game.player_class if rows.has(Game.player_class) else "infantry")
	panel = root


## Header, a list down the left and a page on the right. Used by the classes and the Store.
func _two_panes(title: String) -> Control:
	var root := Control.new()
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var shade := _vignette()
	root.add_child(shade)
	_fill(shade)
	var margin := _screen_margin(44, 18)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	var back := _button("Back", func() -> void: _back.call(), Vector2(116, 56))
	top.add_child(back)
	var head := _label(title, 40, UiTheme.BONE)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	root.set_meta("top", top)
	var panes := HBoxContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_theme_constant_override("separation", 16)
	box.add_child(panes)
	var scroll := DragScroll.new()
	scroll.custom_minimum_size.x = 340
	panes.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panes.add_child(page)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	page.add_child(detail)
	root.set_meta("list", list)
	root.set_meta("detail", detail)
	return root


func _class_row(id: String) -> Button:
	var c: Dictionary = ClassDefs.ALL[id]
	var owned := Game.owns_class(id)
	var row := Button.new()
	row.custom_minimum_size = Vector2(320, 72)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 12)
	row.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var medal := IconView.new(ClassDefs.icon(id), ClassDefs.color(id), 54.0)
	medal.dim = not owned
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(medal)
	var name_label := _body(c["name"], 25)
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not owned:
		name_label.add_theme_color_override("font_color", UiTheme.ASH)
	inner.add_child(name_label)
	if not owned:
		var lock := TextureRect.new()
		lock.texture = Icons.glyph("lock")
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.custom_minimum_size = Vector2(30, 30)
		lock.modulate = UiTheme.ASH
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(lock)
	return row


## What a class is. With mode set, the button at the bottom starts a game; in the Store it buys.
func _fill_class_detail(detail: VBoxContainer, id: String, mode: int, in_store := false) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var c: Dictionary = ClassDefs.ALL[id]
	var owned := Game.owns_class(id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	detail.add_child(head)
	if in_store:
		var view := ModelView.new(Vector2(170, 210))
		view.show_class(id)
		head.add_child(view)
	else:
		head.add_child(IconView.new(ClassDefs.icon(id), ClassDefs.color(id), 92.0))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	head.add_child(words)
	var title := _body(c["name"], 38)
	title.add_theme_font_override("font", UiTheme.title_font())
	words.add_child(title)
	words.add_child(_soft(ClassPresentation.stats_line(id), 24))
	words.add_child(ClassPresentation.weapon_tags(id))
	# The preview and action stay visible; prose can grow without stretching the screen.
	var scroll := DragScroll.new()
	scroll.name = "ClassDescriptionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(scroll)
	var prose := VBoxContainer.new()
	prose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prose.add_theme_constant_override("separation", 12)
	scroll.add_child(prose)
	var desc := _body(ClassPresentation.description(id), 25)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.add_child(desc)
	for spec: Dictionary in AbilityData.tree(id)["specs"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		prose.add_child(line)
		var emblem := IconView.new("spec_%s" % spec["id"], ClassDefs.color(id), 44.0)
		emblem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(emblem)
		var spec_name := _body(spec["name"], 23)
		spec_name.add_theme_font_override("font", UiTheme.bold_font())
		spec_name.custom_minimum_size.x = 190
		spec_name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(spec_name)
		var spec_desc := _soft(ClassPresentation.profession(spec), 23)
		spec_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spec_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(spec_desc)
	if id == "ranger" and not in_store and ShopDefs.PETS.any(func(p: String) -> bool: return Game.owns_item(p)):
		var pets := HBoxContainer.new()
		pets.add_theme_constant_override("separation", 6)
		prose.add_child(pets)
		pets.add_child(_body("Pet", 23))
		for pet: String in ShopDefs.PETS:
			if pet == "wolf" or Game.owns_item(pet):
				var chosen_pet := pet
				pets.add_child(_button(pet.capitalize(), func() -> void:
					Game.choose_pet(chosen_pet)
					_fill_class_detail(detail, id, mode, in_store), Vector2(120, 48), Game.pet == pet))
	if not owned and c.get("unavailable", false):
		var how := _body(CodexPanel.acquisition(id), 26)
		how.add_theme_color_override("font_color", UiTheme.ASH)
		detail.add_child(how)
	elif not owned and c.has("earned"):
		var how := _body(Game.earn_text(id), 26)
		how.add_theme_color_override("font_color", UiTheme.EMBER)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(how)
	elif not owned:
		_buy_row(detail, id, mode, in_store)
	elif in_store:
		var have := _body("You own this class.", 26)
		have.add_theme_color_override("font_color", UiTheme.MOSS)
		detail.add_child(have)
	else:
		var chosen := id
		var go := _button("Play as %s" % c["name"], func() -> void:
			Sfx.play("ui_choose", -3.0)
			Game.player_class = chosen
			Game.save_settings()
			start_game(mode), Vector2(0, 72), true)
		go.add_theme_font_size_override("font_size", 30)
		detail.add_child(go)


## The price and the way to pay it. The first press asks, so a stray thumb cannot spend a week of nights.
func _buy_row(detail: VBoxContainer, id: String, mode: int, in_store: bool) -> void:
	var price := ClassDefs.price(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	detail.add_child(row)
	row.add_child(_coin(52.0))
	var cost := _body("%d" % price, 34)
	cost.add_theme_font_override("font", UiTheme.bold_font())
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost)
	var left := Control.new()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	if not in_store:
		row.add_child(_button("Go to Store", func() -> void: show_store(id, mode), Vector2(220, 68), true))
		return
	var buy := _button("Buy", func() -> void: pass, Vector2(260, 68), true)
	buy.disabled = Game.doubloons < price
	if buy.disabled:
		buy.text = "Need %d more" % (price - Game.doubloons)
	var asked := [false]
	buy.pressed.connect(func() -> void:
		if not asked[0]:
			asked[0] = true
			buy.text = "Tap again to buy"
			return
		if Game.buy_class(id):
			Sfx.play("level", -3.0)
			show_store(id, mode))
	row.add_child(buy)


## Everything for sale, by section. What you pick turns slowly beside its description.
## back_to: where Back goes, when the Store was opened from somewhere other than the menu or a class.
## Moving around inside the Store keeps it.
func show_store(focus := "", from_mode := -1, section := "", back_to := Callable()) -> void:
	_clear_ui()
	if back_to.is_valid():
		_store_return = back_to
	elif from_mode >= 0:
		_store_return = func() -> void: show_class_picker(from_mode)
	else:
		_store_return = show_menu
	_back = _store_return
	var here := _store_return
	if section == "":
		section = "classes"
		if ShopDefs.ITEMS.has(focus):
			section = str(ShopDefs.ITEMS[focus]["section"])
	var root := _two_panes("Store")
	var top: HBoxContainer = root.get_meta("top")
	top.add_child(_coin(44.0))
	var purse := _label("%d" % Game.doubloons, 32, UiTheme.BONE)
	purse.add_theme_font_override("font", UiTheme.bold_font())
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(purse)
	var list: VBoxContainer = root.get_meta("list")
	var detail: VBoxContainer = root.get_meta("detail")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	list.add_child(tabs)
	for key: String in ShopDefs.SECTIONS:
		var chosen_section := key
		var tab := _button(ShopDefs.SECTIONS[key], func() -> void: show_store("", from_mode, chosen_section, here), Vector2(0, 52), key == section)
		tab.add_theme_font_size_override("font_size", 19)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
	var ids: Array[String] = ClassDefs.for_sale() if section == "classes" else ShopDefs.in_section(section)
	var rows := {}
	var pick := func(id: String) -> void:
		for other: String in rows:
			(rows[other] as Button).remove_theme_stylebox_override("normal")
			(rows[other] as Button).remove_theme_stylebox_override("hover")
		UiTheme.selected(rows[id])
		if section == "classes":
			_fill_class_detail(detail, id, from_mode, true)
		else:
			_fill_item_detail(detail, id, from_mode)
	for id: String in ids:
		var row := _class_row(id) if section == "classes" else _item_row(id)
		rows[id] = row
		var chosen := id
		row.pressed.connect(func() -> void:
			Sfx.play("ui_click", -5.0)
			pick.call(chosen))
		list.add_child(row)
	pick.call(focus if rows.has(focus) else ids[0])
	panel = root


func _item_row(id: String) -> Button:
	var d: Dictionary = ShopDefs.ITEMS[id]
	var owned := Game.owns_item(id)
	var row := Button.new()
	row.custom_minimum_size = Vector2(320, 80)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 12)
	row.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var medal := IconView.new(str(d["icon"]), ClassDefs.color(str(d["class"])), 54.0)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(medal)
	var name_label := _body(d["name"], 24)
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not owned:
		name_label.add_theme_color_override("font_color", UiTheme.ASH)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(name_label)
	var whose := _soft(ShopDefs.whose(id), 18)
	whose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(whose)
	inner.add_child(words)
	return row


func _fill_item_detail(detail: VBoxContainer, id: String, from_mode: int) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var d: Dictionary = ShopDefs.ITEMS[id]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.size_flags_vertical = Control.SIZE_FILL
	detail.add_child(head)
	var view := ModelView.new(Vector2(250, 270))
	view.show_item(id)
	head.add_child(view)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 8)
	head.add_child(words)
	var title := _body(d["name"], 36)
	title.add_theme_font_override("font", UiTheme.title_font())
	words.add_child(title)
	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 10)
	owner_row.add_child(IconView.new(ClassDefs.icon(d["class"]), ClassDefs.color(d["class"]), 46.0))
	owner_row.add_child(IconView.new("spec_%s" % d["spec"], ClassDefs.color(d["class"]), 46.0))
	var owner_words := _soft(ShopDefs.whose(id), 23)
	owner_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owner_row.add_child(owner_words)
	words.add_child(owner_row)
	var desc := _body(d["desc"], 24)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(desc)
	if Game.owns_item(id):
		var have := _body("You own this. Find it in the Armory.", 26)
		have.add_theme_color_override("font_color", UiTheme.MOSS)
		detail.add_child(have)
		return
	var price := int(d["price"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	detail.add_child(row)
	row.add_child(_coin(52.0))
	var cost := _body("%d" % price, 34)
	cost.add_theme_font_override("font", UiTheme.bold_font())
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost)
	var left := Control.new()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var buy := _button("Buy", func() -> void: pass, Vector2(260, 68), true)
	buy.disabled = Game.doubloons < price
	if buy.disabled:
		buy.text = "Need %d more" % (price - Game.doubloons)
	var asked := [false]
	buy.pressed.connect(func() -> void:
		if not asked[0]:
			asked[0] = true
			buy.text = "Tap again to buy"
			return
		if Game.buy_item(id):
			Sfx.play("level", -3.0)
			show_store(id, from_mode, "", _store_return))
	row.add_child(buy)


## What you own for each class, to switch on and off.
func show_armory(focus := "") -> void:
	_clear_ui()
	_back = show_menu
	var root := _two_panes("Armory")
	var list: VBoxContainer = root.get_meta("list")
	var detail: VBoxContainer = root.get_meta("detail")
	var rows := {}
	var pick := func(id: String) -> void:
		for other: String in rows:
			(rows[other] as Button).remove_theme_stylebox_override("normal")
			(rows[other] as Button).remove_theme_stylebox_override("hover")
		UiTheme.selected(rows[id])
		_fill_armory(detail, id)
	var classes: Array = ClassDefs.ALL.keys().filter(func(key: String) -> bool: return not ClassDefs.disabled(key))
	for id: String in classes:
		var row := _class_row(id)
		rows[id] = row
		var chosen := id
		row.pressed.connect(func() -> void:
			Sfx.play("ui_click", -5.0)
			pick.call(chosen))
		list.add_child(row)
	pick.call(focus if rows.has(focus) else classes[0])
	panel = root


func _fill_armory(detail: VBoxContainer, id: String) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.size_flags_vertical = Control.SIZE_FILL
	detail.add_child(head)
	var view := ModelView.new(Vector2(170, 180))
	view.show_class(id)
	head.add_child(view)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 10)
	head.add_child(words)
	var title := _body(ClassDefs.ALL[id]["name"], 36)
	title.add_theme_font_override("font", UiTheme.title_font())
	words.add_child(title)
	words.add_child(_body(ClassPresentation.COPY[id][0], 23))
	var d: Dictionary = ClassDefs.ALL[id]
	words.add_child(_soft("%s\nStarting weapon: %s · Starting arrows: %d" % [ClassPresentation.stats_line(id), WeaponDefs.ALL[d["weapon"]]["name"], int(d["arrows"])], 21))
	words.add_child(ClassPresentation.weapon_tags(id))
	words.add_child(_body(ClassPresentation.COPY[id][1], 22))
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	var tree := AbilityData.tree(id)
	var items := ShopDefs.for_class(id)
	for spec: Dictionary in tree["specs"]:
		content.add_child(_body(spec["name"], 29))
		content.add_child(_body(ClassPresentation.profession(spec), 22))
		var upgrades := items.filter(func(item: String) -> bool: return ShopDefs.ITEMS[item]["spec"] == spec["id"])
		if not upgrades.is_empty():
			content.add_child(_armory_spec_row(id, spec["id"], upgrades))
		else:
			content.add_child(_soft("No Class Upgrades available for this profession.", 20))
	var cosmetics := VBoxContainer.new()
	cosmetics.name = "CosmeticsSection"
	content.add_child(cosmetics)
	cosmetics.add_child(_body("Appearance", 25))
	cosmetics.add_child(_soft("Default appearance. No additional skins available yet.", 21))
	for label: Label in detail.find_children("*", "Label", true, false):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## One specialization: its emblem and name, and what you have for it.
func _armory_spec_row(class_id: String, spec: String, items: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var emblem := IconView.new("spec_%s" % spec, ClassDefs.color(class_id), 58.0)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(emblem)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	column.add_child(_body("Class Upgrades", 23))
	if ShopDefs.ITEMS[items[0]].get("pet", false):
		column.add_child(_pet_row())
		return row
	for item: String in items:
		var d: Dictionary = ShopDefs.ITEMS[item]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		column.add_child(line)
		var description := _soft(d["desc"], 21)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(description)
		var name_label := _soft(d["name"], 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		if not Game.owns_item(item):
			line.add_child(_button("In the Store", func() -> void: show_store(item, -1, "", func() -> void: show_armory(class_id)), Vector2(190, 50)))
			continue
		var on := Game.item_active(item)
		var toggle := _button("Equipped" if on else "Not equipped", func() -> void: pass, Vector2(190, 50), on)
		line.add_child(toggle)
		toggle.pressed.connect(func() -> void:
			Game.set_item_on(item, not Game.item_active(item))
			var active := Game.item_active(item)
			toggle.text = "Equipped" if active else "Not equipped"
			if active: UiTheme.selected(toggle)
			else: UiTheme.plain(toggle))
	return row


static func _spec_name(class_id: String, spec: String) -> String:
	for s: Dictionary in AbilityData.tree(class_id)["specs"]:
		if s["id"] == spec:
			return s["name"]
	return spec


## The Beastmaster's companion. Whichever is chosen shows on the stage.
func _pet_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for pet: String in ShopDefs.PETS:
		var owned := pet == "wolf" or Game.owns_item(pet)
		var chosen := pet
		var label: String = pet.capitalize()
		var b := _button(label, func() -> void:
			if not owned:
				show_store(chosen, -1, "", func() -> void: show_armory("ranger"))
				return
			Game.choose_pet(chosen)
			if panel:
				show_armory("ranger"), Vector2(0, 52), Game.pet == pet)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		if not owned:
			b.modulate = Color(1, 1, 1, 0.55)
		row.add_child(b)
	var shown := ModelView.new(Vector2(200, 130))
	shown.show_pet(Game.pet)
	box.add_child(shown)
	return box


func toggle_tree() -> void:
	if tree_panel:
		close_tree()
		return
	if hud == null or world == null or world.player == null:
		return
	hud.release_all()
	hud.menu_open = true
	_back = close_tree
	tree_panel = TreePanel.new()
	tree_panel.theme = _theme
	tree_panel.player = world.player
	ui_layer.add_child(tree_panel)
	_fill(tree_panel)
	tree_panel.build()
	tree_panel.closed.connect(close_tree)
	world.player.damaged.connect(_hurt_with_tree_open)


## Something got to you while you were reading: back to the fight.
func _hurt_with_tree_open(_amount: float, _source: String) -> void:
	close_tree()


func close_tree() -> void:
	if tree_panel:
		if world and is_instance_valid(world) and world.player and world.player.damaged.is_connected(_hurt_with_tree_open):
			world.player.damaged.disconnect(_hurt_with_tree_open)
		tree_panel.queue_free()
		tree_panel = null
	if hud:
		hud.menu_open = false
		_back = show_pause


func start_game(mode: int) -> void:
	Game.begin_run()
	Game.mode = mode
	get_tree().paused = false
	_run_over = false
	_clear_ui()
	_back = Callable()
	# The slow part runs in one go, so the loading screen must be drawn before it starts.
	var loading := _loading_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	_net_go = false
	_new_world(mode)
	var current := world
	world.player_died.connect(_on_player_died)
	world.dawn_reached.connect(_on_dawn)
	world.fort_lost.connect(_on_fort_lost)
	hud = Hud.new()
	hud.theme = _theme
	hud.player = world.player
	world.player.command_target_requested.connect(show_command_map)
	hud.director = world.director
	hud.visible = false
	ui_layer.add_child(hud)
	_fill(hud)
	hud.pause_requested.connect(show_pause)
	hud.tree_requested.connect(toggle_tree)
	hud.sandbox_requested.connect(show_sandbox_menu)
	# Nothing moves until the shaders are ready and the screen is showing the game.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await world.warm_up()
	if world != current or not is_instance_valid(world):
		return
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	if Net.active():
		# Nobody starts until every phone has finished loading.
		Net.report_loaded()
		while not _net_go and world == current and Net.active():
			await get_tree().process_frame
		if world != current or not Net.active():
			return
	loading.queue_free()
	hud.visible = true
	_back = show_pause
	if mode == Game.Mode.SANDBOX:
		world.player.grant_all_points()
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Where the match is about to be played, painted across the screen, with its name, its lore, how it
## is played and a hint for it, and the class you are bringing. Shown while the world is built.
func _loading_screen() -> Control:
	var where := Places.of_match(Game.mode)
	var place: Dictionary = Places.ALL.get(where, {})
	var root := Control.new()
	root.name = "Loading"
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var vista := PlaceVista.new(where if where != "" else "village")
	vista.name = "Vista"
	root.add_child(vista)
	_fill(vista)
	# A darker band at the bottom, so the words read over any sky.
	var shade := TextureRect.new()
	shade.texture = load("res://assets/ui/menu_shade.png")
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.flip_h = true
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.modulate = Color(1, 1, 1, 0.85)
	root.add_child(shade)
	_fill(shade)
	var margin := _screen_margin(64, 40)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var mode_word := "Sandbox"
	if Net.active():
		mode_word = Net.RULE_NAMES[Net.rules]
	elif Game.mode == Game.Mode.NIGHT:
		mode_word = "Survive the Night"
	elif Game.mode == Game.Mode.FORT:
		mode_word = "Defend the Fort"
	var caption := _label(mode_word, 26, UiTheme.EMBER)
	caption.name = "Mode"
	box.add_child(caption)
	var title := _label(str(place.get("name", "Sandbox")), 64, UiTheme.BONE)
	title.name = "Place"
	title.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(title)
	var lore := _label(str(place.get("lore", "Try any weapon, item or class you own.")), 25, UiTheme.ASH)
	lore.name = "Lore"
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size.x = 820
	lore.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(lore)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	box.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var medal := IconView.new(ClassDefs.icon(Game.player_class), ClassDefs.color(Game.player_class), 72.0)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	words.add_child(_label(str(ClassDefs.ALL[Game.player_class]["name"]), 30, UiTheme.BONE))
	var hints: Array = place.get("tips", []).duplicate()
	if where in ["village", "fort", ""]:
		hints.append_array(TIPS)
	var tip := _label(str(hints[randi() % hints.size()]), 24, UiTheme.ASH)
	tip.name = "Tip"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 760
	words.add_child(tip)
	row.add_child(_expand())
	var preparing := _label("Preparing the night" if Game.mode != Game.Mode.SANDBOX else "Preparing the yard", 24, UiTheme.BONE)
	preparing.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(preparing)
	return root


func _modal(title: String) -> Control:
	var root := Control.new()
	root.theme = _theme
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(root)
	_fill(root)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.07, 0.6)
	root.add_child(shade)
	_fill(shade)
	var center := CenterContainer.new()
	root.add_child(center)
	_fill(center)
	var card := PanelContainer.new()
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size.x = 480
	card.add_child(box)
	var head := _body(title, 40)
	head.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(head)
	root.set_meta("box", box)
	panel = root
	return root


func show_pause() -> void:
	# Tapping pause again changes nothing.
	if _pause_root and is_instance_valid(_pause_root):
		return
	close_tree()
	if hud:
		hud.release_all()
		hud.menu_open = true
	# The others keep playing, so a shared night cannot stop for one player.
	get_tree().paused = not Net.active()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := _modal("The night goes on" if Net.active() else "Paused")
	_pause_root = root
	_back = _resume
	var box: VBoxContainer = root.get_meta("box")
	box.add_child(_button("Resume", _resume, Vector2(480, 72), true))
	box.add_child(_button("Map", show_map, Vector2(480, 72)))
	box.add_child(_button("Settings", func() -> void: show_settings(true), Vector2(480, 72)))
	box.add_child(_button("Leave the game" if Net.active() else "Quit to menu", show_menu, Vector2(480, 72)))


func show_map() -> void:
	var root := _modal("Map")
	var box: VBoxContainer = root.get_meta("box")
	var map := MapPanel.new()
	map.world = world
	map.custom_minimum_size = Vector2(470, 470)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(map)
	var close := func() -> void:
		root.queue_free()
		_back = _resume
	var back := _button("Back", close, Vector2(180, 70))
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(back)
	_back = close


func _resume() -> void:
	if _pause_root and is_instance_valid(_pause_root):
		_pause_root.queue_free()
	_pause_root = null
	get_tree().paused = false
	if hud:
		hud.menu_open = false
	_back = show_pause
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_player_died() -> void:
	if Game.mode == Game.Mode.SANDBOX:
		# Nothing is at stake here: back on your feet in a moment.
		var here := world
		await get_tree().create_timer(1.5).timeout
		if world == here and is_instance_valid(world) and world.player.dead:
			world.player.respawn(world.player_start(0))
		return
	if _run_over:
		return
	_run_over = true
	close_tree()
	if hud:
		hud.release_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var seconds := world.director.elapsed
	var kills := world.player.kills
	var is_best := Game.mode == Game.Mode.NIGHT and Game.record_run(seconds, kills, false)
	var earned := Game.award_doubloons(seconds, kills, false, false) if Game.is_night() else 0
	var points_line := _board_line(seconds, kills, false) if Game.is_night() else ""
	var current := world
	await get_tree().create_timer(1.2).timeout
	if world != current or not is_inside_tree():
		return
	var pl := world.player
	var cause := "Slain by %s." % pl.hit_by if pl.hit_by != "" else "You fell."
	if pl.hit_by == "flames":
		cause = "Burned alive."
	elif pl.hit_by == "lightning":
		cause = "Struck by lightning."
	_end_screen("You fell", "%s\nSurvived %s as %s: %d kills, level %d.%s" % [cause, Game.clock(seconds), _character_name(pl), kills, pl.level, (" New best!" if is_best else "") + _earned_line(earned) + points_line])


func _on_dawn() -> void:
	if Net.active():
		if Net.is_host():
			var night := world
			# Let the sunrise and the burning zombies play first.
			await get_tree().create_timer(3.5).timeout
			if world == night and Net.is_host():
				Net.on_dawn_reached()
		return
	if _run_over:
		return
	_run_over = true
	Game.note_mists_win()
	close_tree()
	if hud:
		hud.release_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var kills := world.player.kills
	Game.record_run(Game.NIGHT_LENGTH, kills, true)
	var earned := Game.award_doubloons(Game.NIGHT_LENGTH, kills, true, false)
	var current := world
	var line := "%s survived the night: %d kills, level %d.%s" % [_character_name(world.player), kills, world.player.level, _earned_line(earned)]
	# The Mists can run past ten minutes, until the Regent falls.
	line += _board_line(maxf(Game.NIGHT_LENGTH, world.director.elapsed), kills, true)
	# Let the sunrise and the burning zombies play first.
	await get_tree().create_timer(3.5).timeout
	if world != current or not is_inside_tree():
		return
	_end_screen("Dawn!", line)


func _on_fort_lost() -> void:
	if _run_over:
		return
	_run_over = true
	close_tree()
	if hud:
		hud.release_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var seconds := world.director.elapsed
	var kills := world.player.kills
	var earned := Game.award_doubloons(seconds, kills, false, false)
	_end_screen("The portal has fallen", "The fort held for %s, and you took %d with you.%s" % [Game.clock(seconds), kills, _earned_line(earned) + _board_line(seconds, kills, false)])


func _earned_line(earned: int) -> String:
	var line := "\n+%d Botti Doubloons" % earned if earned > 0 else ""
	Game.note_game_finished()
	for id: String in Game.fresh_unlocks:
		line += "\n%s unlocked!" % ClassDefs.ALL[id]["name"]
	Game.fresh_unlocks.clear()
	return line


func _on_net_over(title: String, line: String, reached_dawn: bool) -> void:
	if _run_over or world == null:
		return
	_run_over = true
	var won := reached_dawn or Net.last_winner == Net.my_id()
	if reached_dawn:
		Game.note_mists_win()
	line += _earned_line(Game.award_doubloons(world.director.elapsed, world.player.kills, won, not Net.pvp() and Net.humans() > 1))
	line += _board_line(world.director.elapsed, world.player.kills, won)
	close_tree()
	if hud:
		hud.release_all()
		hud.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_back = show_menu
	var root := _modal(title)
	var box: VBoxContainer = root.get_meta("box")
	var l := _body(line, 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	if Net.is_host():
		box.add_child(_button("Back to the room", Net.return_to_room, Vector2(480, 72), true))
		box.add_child(_button("Menu", show_menu, Vector2(480, 64)))
	else:
		var wait := _soft("Your host can take everyone back to the room for another night.", 22)
		wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(wait)
		box.add_child(_button("Menu", show_menu, Vector2(480, 72), true))


## Everyone still here, back in the room the night began from.
func _return_to_room() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run_over = false
	_clear_world()
	_clear_ui()
	_new_world(Game.Mode.MENU)
	Game.mode = Game.Mode.MENU
	Sfx.set_mood(0.0, 0.0)
	show_lobby()


func _on_net_left(reason: String) -> void:
	# Whoever is already reading the results can finish reading them.
	if _run_over and hud:
		return
	# From a game, back to the menu. From the Play Together screens, back to where this began.
	if hud:
		show_menu()
	elif panel:
		show_together()
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	var l := _body(reason, 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(_button("OK", func() -> void: root.queue_free(), Vector2(480, 72), true))


# --- Play together -----------------------------------------------------------

## What you can ask for in the Sandbox. The world waits while this is open.
func show_sandbox_menu() -> void:
	if world == null or Game.mode != Game.Mode.SANDBOX or (_pause_root and is_instance_valid(_pause_root)):
		return
	if hud:
		hud.release_all()
		hud.menu_open = true
	get_tree().paused = true
	var root := _modal("Sandbox")
	_pause_root = root
	_back = _resume
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 1000
	box.add_child(_soft("Bring in an enemy, a few steps in front of you", 23))
	# Every enemy in the game no longer fits on one screen: the list scrolls, the rest stays put.
	var enemy_scroll := DragScroll.new()
	enemy_scroll.name = "SandboxEnemies"
	enemy_scroll.custom_minimum_size = Vector2(1000, 250)
	box.add_child(enemy_scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	enemy_scroll.add_child(grid)
	var enemies: Array = ["dummy"]
	enemies.append_array(ZombieDefs.ALL.keys())
	for id: String in enemies:
		var chosen := id
		var b := _button(str(ZombieDefs.def_of(id)["name"]), func() -> void:
			world.sandbox_spawn(chosen), Vector2(194, 54))
		b.add_theme_font_size_override("font_size", 22)
		grid.add_child(b)
	box.add_child(_soft("You", 23))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var pl := world.player
	row.add_child(_button("New skill tree", func() -> void: start_game(Game.Mode.SANDBOX), Vector2(220, 60)))
	var safe := _toggle("Cannot be hurt", func() -> bool: return pl.guard_left > 100.0, func(on: bool) -> void: pl.guard_left = 9999.0 if on else 0.0)
	safe.custom_minimum_size.x = 300
	row.add_child(safe)
	row.add_child(_button("Clear enemies", func() -> void: world.sandbox_clear(), Vector2(210, 60)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	box.add_child(foot)
	var weather_row := HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 8)
	box.add_child(weather_row)
	weather_row.add_child(_soft("Weather", 23))
	weather_row.add_child(_choices(["Clear", "Rain", "Storm"], world.weather.kind, 150.0, func(i: int) -> void: world.weather.set_kind(i)))
	foot.add_child(_button("Change class", func() -> void: show_class_picker(Game.Mode.SANDBOX), Vector2(240, 66)))
	foot.add_child(_button("Quit to menu", show_menu, Vector2(240, 66)))
	foot.add_child(_expand())
	foot.add_child(_button("Back to it", _resume, Vector2(260, 66), true))


## The four ways to play together, and what each one needs.
func show_together(tab := -1) -> void:
	if tab >= 0:
		_together_tab = tab
	_clear_ui()
	_back = show_menu
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 900
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	for t in TOGETHER_TABS.size():
		var pick := t
		tabs.add_child(_button(TOGETHER_TABS[t], func() -> void: show_together(pick), Vector2(216, 60), _together_tab == t))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(_soft("Playing as", 24))
	var who := _button(Game.player_name, func() -> void: show_name_prompt(false, func() -> void: show_together()), Vector2(250, 58))
	who.tooltip_text = "Change your name"
	top.add_child(who)
	if _together_tab == ONLINE_TAB:
		if EpicNet.available():
			top.add_child(_button("Start a game", _start_online, Vector2(300, 66), true))
	else:
		top.add_child(_button("Start a game", func() -> void:
			var problem := Net.host_game()
			if problem == OK:
				show_lobby()
			else:
				_on_net_left("Could not start a game here (%d)." % problem), Vector2(300, 66), true))
	top.add_child(_button("Back", show_menu, Vector2(130, 66)))
	match _together_tab:
		0:
			box.add_child(_soft("Everyone on the same Wi-Fi network.", 24))
			_nearby_games(box, root)
		1:
			var steps := _soft("1. On one phone, turn on the hotspot in its settings.\n2. Connect the others to that hotspot's Wi-Fi. If a phone warns there is no internet, stay connected.\n3. Start a game on the hotspot phone, and it appears on the others.\nIf a phone keeps getting dropped, turn off its mobile data.", 23)
			steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(steps)
			_nearby_games(box, root)
		2:
			_online_tab(box)


func _nearby_games(box: VBoxContainer, root: Control) -> void:
	box.add_child(_body("Games nearby", 26))
	var rooms := VBoxContainer.new()
	rooms.custom_minimum_size.y = 80
	rooms.add_theme_constant_override("separation", 6)
	box.add_child(rooms)
	var fill := func() -> void:
		if not is_instance_valid(rooms):
			return
		for c in rooms.get_children():
			c.queue_free()
		if Net.rooms.is_empty():
			rooms.add_child(_body("Looking...", 24))
		for address: String in Net.rooms:
			var info: Dictionary = Net.rooms[address]
			rooms.add_child(_button("%s's game: %s, %d of %d players" % [info["name"], Net.RULE_NAMES[int(info["rules"])], info["players"], Net.MAX_PLAYERS], func() -> void: _join(address), Vector2(860, 60)))
	Net.rooms_changed.connect(fill)
	root.tree_exiting.connect(func() -> void:
		Net.rooms_changed.disconnect(fill)
		Net.stop_search())
	Net.start_search()
	fill.call()
	var manual := HBoxContainer.new()
	manual.add_theme_constant_override("separation", 10)
	box.add_child(manual)
	manual.add_child(_body("Join by address", 24))
	var address_edit := LineEdit.new()
	address_edit.placeholder_text = _example_address()
	address_edit.custom_minimum_size = Vector2(400, 58)
	address_edit.add_theme_font_size_override("font_size", 26)
	# Number keyboards on Android allow a single dot, and an address has three.
	address_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	manual.add_child(address_edit)
	manual.add_child(_button("Join", func() -> void:
		if address_edit.text.strip_edges() != "":
			_join(address_edit.text.strip_edges()), Vector2(160, 60)))


func _online_tab(box: VBoxContainer) -> void:
	var how := _soft("Over the internet, from almost any network, mobile data included.", 24)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	if not EpicNet.available():
		var missing := _body("This build has no online play.", 24)
		missing.add_theme_color_override("font_color", UiTheme.EMBER)
		box.add_child(missing)
		return
	# Whether the game you start shows in everyone's list, or is found only with its code.
	var kind := HBoxContainer.new()
	kind.add_theme_constant_override("separation", 8)
	box.add_child(kind)
	kind.add_child(_body("New game", 24))
	kind.add_child(_button("Public", func() -> void:
		_start_listed = true
		show_together(ONLINE_TAB), Vector2(150, 54), _start_listed))
	kind.add_child(_button("Private", func() -> void:
		_start_listed = false
		show_together(ONLINE_TAB), Vector2(150, 54), not _start_listed))
	var says := _soft("Anyone can find it in the list below, or join with its code." if _start_listed else "Only friends with its code can join.", 21)
	says.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.add_child(says)
	var join := HBoxContainer.new()
	join.add_theme_constant_override("separation", 10)
	box.add_child(join)
	join.add_child(_body("Room code", 24))
	var code_edit := LineEdit.new()
	code_edit.placeholder_text = "ABC234"
	code_edit.max_length = EpicNet.USER_ID_LENGTH
	code_edit.custom_minimum_size = Vector2(260, 58)
	code_edit.add_theme_font_size_override("font_size", 26)
	join.add_child(code_edit)
	join.add_child(_button("Join", func() -> void:
		if code_edit.text.strip_edges() != "":
			_join_online(code_edit.text), Vector2(160, 60)))
	_public_games(box)


## Games other people started as public, waiting for players. Looked up again every few seconds.
func _public_games(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := _body("Public games", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Refresh", func() -> void: Net.look_for_rooms(), Vector2(150, 50)))
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(860, 150)
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	var fill := func() -> void:
		if not is_instance_valid(rows):
			return
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
		if Net.public_rooms.is_empty():
			var empty := "Looking..." if Net.looking_up else ("Could not look: %s" % Net.lookup_problem if Net.lookup_problem != "" else "No public games right now. Start one, or join a friend's with a code.")
			var l := _soft(empty, 22)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rows.add_child(l)
		for room: Dictionary in Net.public_rooms:
			rows.add_child(_public_room_row(room))
	Net.public_rooms_changed.connect(fill)
	var timer := Timer.new()
	timer.wait_time = 6.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: Net.look_for_rooms())
	box.add_child(timer)
	box.tree_exiting.connect(func() -> void:
		if Net.public_rooms_changed.is_connected(fill):
			Net.public_rooms_changed.disconnect(fill))
	fill.call()
	Net.look_for_rooms()


func _public_room_row(room: Dictionary) -> Button:
	var map_name: String = Game.MAPS.get(str(room["map"]), {}).get("name", "")
	var rules: String = Net.RULE_NAMES[clampi(int(room["rules"]), 0, Net.RULE_NAMES.size() - 1)]
	var what := rules if int(room["rules"]) != Net.Rules.COOP or map_name == "" else "%s, %s" % [rules, map_name]
	var b := _button("%s's game: %s. %d of %d players" % [room["name"], what, int(room["players"]), Net.MAX_PLAYERS], func() -> void: _join_online(str(room["host"])), Vector2(840, 58))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _online_wait() -> void:
	_clear_ui()
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 600
	box.add_child(_body("Connecting...", 28))


func _start_online() -> void:
	_online_wait()
	var problem := await Net.host_online(_start_listed)
	if problem != "":
		_on_online_failed(problem)
	else:
		show_lobby()


func _join_online(code: String) -> void:
	_online_wait()
	var problem := await Net.join_online(code)
	if problem != "":
		_on_online_failed(problem)
	else:
		show_lobby()


func _on_online_failed(problem: String) -> void:
	show_together(ONLINE_TAB)
	_on_net_left(problem)


## An example from this phone's own network, since a game on the same Wi-Fi will share the start of it.
func _example_address() -> String:
	var mine := Net.local_addresses()
	if mine.is_empty():
		return "192.168.1.20"
	return mine[0].substr(0, mine[0].rfind(".") + 1) + "20"


func _join(address: String) -> void:
	if Net.join_game(address) == OK:
		show_lobby()
	else:
		_on_net_left("That address does not look right.")


## Who is here, and what the game will be.
func show_lobby() -> void:
	_clear_ui()
	_back = _leave_lobby
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 900
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(900, 520)
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	var refresh := func() -> void: _fill_lobby(body)
	Net.lobby_changed.connect(refresh)
	root.tree_exiting.connect(func() -> void: Net.lobby_changed.disconnect(refresh))
	refresh.call()


func _leave_lobby() -> void:
	Net.leave()
	show_together()


func _fill_lobby(body: VBoxContainer) -> void:
	if not is_instance_valid(body):
		return
	for c in body.get_children():
		# This can run from inside one of these buttons' own press.
		body.remove_child(c)
		c.queue_free()
	if Net.is_client() and not Net.roster.has(Net.my_id()):
		body.add_child(_body("Connecting...", 28))
		body.add_child(_button("Back", _leave_lobby, Vector2(240, 60)))
		return
	if Net.is_host():
		if Net.way == Net.Way.ONLINE:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			body.add_child(row)
			var shown := _body("Room code: %s" % Net.room_code, 30 if Net.room_problem == "" else 22)
			shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(shown)
			row.add_child(_button("Copy", func() -> void: DisplayServer.clipboard_set(Net.room_code), Vector2(120, 48)))
			row.add_child(_button("Public", func() -> void: Net.set_listed(true), Vector2(130, 48), Net.room_listed))
			row.add_child(_button("Private", func() -> void: Net.set_listed(false), Vector2(130, 48), not Net.room_listed))
			if Net.room_problem != "":
				var why := _soft("%s This longer code still works: copy it and send it to your friends." % Net.room_problem, 22)
				why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(why)
		else:
			var where := Net.local_addresses()
			body.add_child(_body("Your address, if someone needs it: %s" % (where[0] if not where.is_empty() else "no Wi-Fi?"), 24))
		var kinds := HBoxContainer.new()
		kinds.add_theme_constant_override("separation", 8)
		body.add_child(kinds)
		for r in Net.RULE_NAMES.size():
			var pick := r
			kinds.add_child(_button(Net.RULE_NAMES[r], func() -> void: Net.set_rules(pick), Vector2(215, 58), Net.rules == r))
		var maps := HBoxContainer.new()
		maps.add_theme_constant_override("separation", 8)
		body.add_child(maps)
		if Net.rules == Net.Rules.FORT:
			for id: String in Game.FORT_MAPS:
				var chosen_fort := id
				maps.add_child(_button(Game.FORT_MAPS[id]["name"], func() -> void: Net.set_fort_map(chosen_fort), Vector2(215, 52), Net.fort_map == id))
		else:
			for id: String in Game.MAPS:
				if Net.pvp() and id not in Game.VERSUS_MAPS:
					continue
				var chosen_map := id
				maps.add_child(_button(Game.MAPS[id]["name"], func() -> void: Net.set_night_map(chosen_map), Vector2(215, 52), Net.night_map == id))
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 8)
		body.add_child(levels)
		var bots_row := levels
		levels.add_child(_body("Difficulty", 24))
		for d in 3:
			var level := d
			levels.add_child(_button(["Easy", "Normal", "Hard"][d], func() -> void: Net.set_difficulty(level), Vector2(125, 52), Net.difficulty == d))
		bots_row.add_child(_body("  Bots", 24))
		for n in Net.MAX_PLAYERS - Net.humans() + 1:
			var wanted := n
			bots_row.add_child(_button(str(n), func() -> void: Net.set_bots(wanted), Vector2(62, 52), Net.bot_count() == n))
	else:
		body.add_child(_body("Game: %s, %s. The host starts when everyone is ready." % [Net.RULE_NAMES[Net.rules], ["Easy", "Normal", "Hard"][Net.difficulty]], 24))
	if Net.rules == Net.Rules.FFA:
		body.add_child(_soft("Three lives each, and a deadly fog closes in. The last one standing wins.", 23))
	if not Net.can_start():
		var need := "All vs All needs someone to fight." if Net.rules == Net.Rules.FFA else "Teams needs a player or bot on each side."
		if Net.is_host():
			need += " Wait for a friend or add a bot."
		var why := _soft(need, 23)
		why.add_theme_color_override("font_color", UiTheme.EMBER)
		body.add_child(why)
	var ids: Array = Net.roster.keys()
	ids.sort()
	for peer: int in ids:
		var info: Dictionary = Net.roster[peer]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		body.add_child(row)
		var medal := IconView.new(ClassDefs.icon(str(info["class"])), ClassDefs.color(str(info["class"])), 44.0)
		row.add_child(medal)
		var who := "%s: %s" % [info["name"], ClassDefs.ALL[str(info["class"])]["name"]]
		if peer == Net.my_id():
			who += " (you)"
		var l := _body(who, 26)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if Net.rules == Net.Rules.TEAMS:
			var team := _body("Team %s" % ("Gold" if int(info["team"]) == 0 else "Blue"), 26)
			team.add_theme_color_override("font_color", Net.team_colour(int(info["team"])))
			row.add_child(team)
	var classes := GridContainer.new()
	classes.columns = 6
	classes.add_theme_constant_override("h_separation", 6)
	classes.add_theme_constant_override("v_separation", 6)
	body.add_child(classes)
	var offered := ClassDefs.available()
	for id: String in offered:
		var pick := id
		var mine := str(Net.roster[Net.my_id()]["class"]) == id
		var b := _button(String(ClassDefs.ALL[id]["name"]).get_slice(" ", 0), func() -> void: Net.set_my_class(pick), Vector2(136, 56), mine)
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = not Net.class_slot_available(id, Net.my_id())
		b.tooltip_text = "Only one Commander per match" if b.disabled else ""
		classes.add_child(b)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	body.add_child(foot)
	if Net.rules == Net.Rules.TEAMS:
		foot.add_child(_button("Change team", Net.switch_team, Vector2(240, 66)))
	if Net.is_host():
		var go := _button("Start the night", Net.start_match, Vector2(360, 66), true)
		go.disabled = not Net.can_start()
		foot.add_child(go)
	foot.add_child(_button("Leave", _leave_lobby, Vector2(180, 66)))


func _character_name(pl: Player) -> String:
	if pl.spec_id != "":
		return String(pl.spec_def()["name"])
	return String(pl.class_def()["name"])


func _end_screen(title: String, line: String) -> void:
	if hud:
		hud.menu_open = true # touches now belong to these buttons, not the character behind them
	_back = show_menu
	var root := _modal(title)
	var box: VBoxContainer = root.get_meta("box")
	var l := _body(line, 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	_end_label = l
	_apply_board_note()
	box.add_child(_button("Play again", func() -> void: start_game(Game.mode), Vector2(480, 72), true))
	box.add_child(_button("Change class", func() -> void: show_class_picker(Game.mode), Vector2(480, 72)))
	box.add_child(_button("Menu", show_menu, Vector2(480, 72)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if hud and hud.visible and not get_tree().paused and not _run_over:
			show_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _back.is_valid():
		_back.call()


func show_command_map() -> void:
	if world == null or world.player.dead or hud.menu_open:
		return
	hud.release_all()
	hud.menu_open = true
	world.player.input_fire = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := _modal("Artillery target")
	var box: VBoxContainer = root.get_meta("box")
	box.add_child(_soft("Choose a circle: %d m radius. Impact in %d seconds; %d-second barrage, %d-second fires." % [int(CommanderKit.BARRAGE_RADIUS), int(CommanderKit.BARRAGE_DELAY), int(CommanderKit.BARRAGE_TIME), int(CommanderKit.FIRE_TIME)], 22))
	var map := MapPanel.new()
	map.world = world
	map.targeting = true
	map.selected_spot = world.player.global_position
	map.custom_minimum_size = Vector2(440, 440)
	map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(map)
	var row := HBoxContainer.new()
	box.add_child(row)
	var close := func() -> void:
		root.queue_free()
		if hud:
			hud.menu_open = false
		_back = show_pause
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	row.add_child(_button("Cancel", close, Vector2(210, 60)))
	var confirm := _button("Call barrage", func() -> void:
		if world == null or world.player.dead:
			close.call()
			return
		world.player.command_target = map.selected_spot
		world.player.command_target_ready = true
		close.call()
		world.player.use_art(), Vector2(230, 60), true)
	confirm.disabled = true
	map.selected.connect(func(_at: Vector3) -> void: confirm.disabled = false)
	row.add_child(confirm)
	_back = close


# --- Your name and the leaderboard -------------------------------------------

## The game itself asks for a name. Tests and capture scenes that host this menu ask for one only
## when they mean to.
func _asks_for_name() -> bool:
	var scene := get_tree().current_scene
	return scene == null or scene == self


## Who you are, at the top of the menu. Tapping it changes your name.
func _name_button() -> Button:
	var b := _button(Game.player_name, func() -> void: show_name_prompt(false), Vector2(0, 64))
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size.x = maxf(150.0, _text_width(Game.player_name, 26) + 48.0)
	b.tooltip_text = "Change your name"
	return b


## Your display name: shown to others in games together and on the leaderboard. Names are unique.
## When `required`, there is no way out but choosing one.
func show_name_prompt(required: bool, after := Callable()) -> void:
	var root := _modal("Choose your name" if required else "Your name")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 640
	var was_back := _back
	var close := func() -> void:
		root.queue_free()
		_back = was_back
		if after.is_valid():
			after.call()
		elif Game.mode == Game.Mode.MENU:
			show_menu()
	if not required:
		_back = close
	var line := "Other players see this name in games together and on the leaderboard. Each name belongs to one player."
	if Board.name_state == Board.NameState.TAKEN:
		line = ("\"%s\" isn't allowed on the leaderboard. Choose another name." if Board.taken_blocked else "Someone else took \"%s\" while you were offline. Choose another name.") % Board.taken_name
	var about := _soft(line, 23)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	var edit := LineEdit.new()
	edit.text = Game.player_name if Board.name_state != Board.NameState.TAKEN else ""
	edit.placeholder_text = "3 to 16 letters"
	edit.max_length = Board.NAME_MAX
	edit.custom_minimum_size = Vector2(640, 64)
	edit.add_theme_font_size_override("font_size", 30)
	edit.select_all_on_focus = true
	box.add_child(edit)
	var problem := _body("", 22)
	problem.add_theme_color_override("font_color", UiTheme.EMBER)
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(problem)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var save := _button("Save", func() -> void: pass, Vector2(0, 66), true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var choose := func() -> void:
		if save.disabled:
			return
		save.disabled = true
		save.text = "Checking…"
		problem.text = ""
		var answer: String = await Board.choose_name(edit.text)
		if not is_instance_valid(root):
			return
		save.disabled = false
		save.text = "Save"
		if answer == "":
			close.call()
		else:
			problem.text = answer
			edit.grab_focus()
	save.pressed.connect(choose)
	edit.text_submitted.connect(func(_t: String) -> void: choose.call())
	edit.text_changed.connect(func(t: String) -> void: problem.text = Board.name_problem(t) if t.strip_edges() != "" else "")
	if not required:
		row.add_child(_button("Cancel", close, Vector2(180, 66)))
	row.add_child(save)
	edit.grab_focus.call_deferred()


## This match's points for the leaderboard, as a line for the end screen.
func _board_line(seconds: float, kills: int, won: bool) -> String:
	if Game.mode == Game.Mode.SANDBOX or world == null or world.player == null:
		return ""
	var mode := "fort" if Game.mode == Game.Mode.FORT else "night"
	if Net.active():
		mode = {Net.Rules.COOP: "coop", Net.Rules.FFA: "ffa", Net.Rules.TEAMS: "teams", Net.Rules.FORT: "fort"}.get(Net.rules, "coop")
	var map := Game.current_map()
	var difficulty: int = Net.difficulty if Net.active() else Game.difficulty
	_counted = {}
	var points := Board.record_match(seconds, kills, won, mode, map, world.player.class_id, world.player.spec_id, difficulty)
	_board_note = "+%d leaderboard points" % points
	return "\n" + _board_note


var _board_note := "" # "+250 leaderboard points" on the current end screen
var _end_label: Label
var _counted := {} # what the board said about the last match
var _prizes_checked := -1e9


## Once the board has counted the match, the end screen also says where it moved you.
func _apply_board_note() -> void:
	if _counted.is_empty() or _board_note == "" or not is_instance_valid(_end_label) or not _end_label.text.contains(_board_note):
		return
	var moves: Array = []
	for period: String in ["week", "all"]:
		var now: Dictionary = _counted.get(period, {})
		var was: Dictionary = (_counted.get("before", {}) as Dictionary).get(period, {})
		if now.get("rank") == null:
			continue
		var where := "this week" if period == "week" else "of all time"
		var rank := int(now["rank"])
		if was.get("rank") == null:
			moves.append("#%d %s" % [rank, where])
		elif int(was["rank"]) > rank:
			moves.append("#%d %s (up %d)" % [rank, where, int(was["rank"]) - rank])
		else:
			moves.append("#%d %s" % [rank, where])
	if moves.is_empty():
		return
	var line := _board_note + ": " + " and ".join(moves)
	_end_label.text = _end_label.text.replace(_board_note, line)
	_board_note = line


## Weekly prizes: collected quietly when the menu opens, and announced when there is one.
func _collect_prizes() -> void:
	if not Board.configured() or Board.registered == "" or Time.get_ticks_msec() - _prizes_checked < 5 * 60 * 1000.0:
		return
	_prizes_checked = Time.get_ticks_msec()
	var won: Array = await Board.collect_prizes()
	if won.is_empty() or not is_instance_valid(panel) or Game.mode != Game.Mode.MENU:
		return
	var root := _modal("A leaderboard prize")
	var box: VBoxContainer = root.get_meta("box")
	for reward: Dictionary in won:
		var place: String = ["first", "second", "third"][clampi(int(reward.get("rank", 1)) - 1, 0, 2)]
		var start := Time.get_datetime_dict_from_unix_time(int(reward.get("week", 0)) * 7 * 86400 + 4 * 86400)
		var l := _body("You finished %s in the week of %d %s. +%d doubloons." % [place, start["day"], ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][int(start["month"]) - 1], int(reward.get("doubloons", 0))], 26)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		box.add_child(l)
	var close := func() -> void:
		root.queue_free()
		show_menu()
	box.add_child(_button("Close", close, Vector2(480, 72), true))


var _board_period := "all" # "all", "week" or "mine"
var _board_kind := "all"


## The leaderboard: the top 50 of all time or of this week, on every match or one kind of match,
## and your own last matches.
func show_leaderboard(period := "", kind := "") -> void:
	if period != "":
		_board_period = period
	if kind != "":
		_board_kind = kind
	_clear_ui()
	_back = show_menu
	var root := Control.new()
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var shade := _vignette()
	root.add_child(shade)
	_fill(shade)
	var margin := _screen_margin(44, 18)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(_button("Back", show_menu, Vector2(116, 56)))
	var head := _label("Leaderboard", 40, UiTheme.BONE)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(head)
	top.add_child(_expand())
	for tab: Array in [["all", "All time"], ["week", "This week"], ["mine", "Your matches"]]:
		var which: String = tab[0]
		top.add_child(_button(tab[1], func() -> void: show_leaderboard(which), Vector2(168, 56), _board_period == which))
	# Which matches count: every one, or one kind.
	if _board_period != "mine":
		var kinds := HBoxContainer.new()
		kinds.add_theme_constant_override("separation", 8)
		box.add_child(kinds)
		for id: String in Board.BOARDS:
			var b := _button(Board.BOARDS[id], func() -> void: show_leaderboard("", id), Vector2(0, 46), _board_kind == id)
			b.add_theme_font_size_override("font_size", 21)
			b.custom_minimum_size.x = maxf(96.0, _text_width(Board.BOARDS[id], 21) + 36.0)
			kinds.add_child(b)
	var note := _soft("", 21)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(page)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 4)
	page.add_child(inside)
	if _board_period == "mine":
		inside.add_child(_history_row("When", "Match", "Played as", "Kills", "Result", "Points", true))
	else:
		inside.add_child(_board_row("#", "Player", "Points", "Most played", UiTheme.ASH, true))
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inside.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	var mine := _body("", 23)
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(mine)
	foot.add_child(_button("Refresh", func() -> void: _fill_leaderboard(list, note, mine, true), Vector2(150, 56)))
	panel = root
	_fill_leaderboard(list, note, mine, false)


func _fill_leaderboard(list: VBoxContainer, note: Label, mine: Label, fresh: bool) -> void:
	for c in list.get_children():
		c.queue_free()
	var period := _board_period
	var kind := _board_kind
	mine.text = ""
	note.text = ""
	if not Board.configured():
		list.add_child(_soft("This version of the game has no leaderboard.", 24))
		return
	var asking := _soft("Asking the leaderboard…", 24)
	list.add_child(asking)
	if period == "mine":
		note.text = "Your last 30 matches on the leaderboard, newest first."
		var got: Dictionary = await Board.history()
		if not is_instance_valid(list) or _board_period != period:
			return
		asking.queue_free()
		if not got["ok"]:
			list.add_child(_board_problem(got["error"]))
		elif got["matches"].is_empty():
			list.add_child(_soft("No matches yet. Finish a match outside the Sandbox and it shows here.", 24))
		for m: Dictionary in got.get("matches", []):
			var played := _match_word(str(m.get("mode", "")), str(m.get("map", "")))
			var as_class := Board.class_label(str(m.get("class", "")), str(m.get("spec", "")))
			var result := ("Won" if m.get("outcome", "") == "won" else "Lost") + ", " + Game.clock(float(m.get("seconds", 0)))
			list.add_child(_history_row(_ago(int(m.get("at", 0))), played, as_class, str(int(m.get("kills", 0))), result, str(int(m.get("points", 0))), false))
		_note_pending(mine)
		return
	var result: Dictionary = await Board.fetch(period, fresh, kind)
	if not is_instance_valid(list) or _board_period != period or _board_kind != kind:
		return
	asking.queue_free()
	var what: String = "every match" if kind == "all" else {"night": "Survive the Night in the Village and the Valleys of Mesenlla", "mists": "nights in the Mists, alone or together", "fort": "Defend the Fort and Mist Bastion", "coop": "Co-op nights in the Village and the Valleys of Mesenlla", "versus": "All vs All and Teams"}[kind]
	note.text = ("Points from %s, since the leaderboard began." if period == "all" else "Points from %s since Monday 00:00 UTC.") % what
	if not result["ok"]:
		list.add_child(_board_problem(result["error"]))
	else:
		var entries: Array = result["entries"]
		if entries.is_empty():
			list.add_child(_soft("No one has scored here yet%s. Finish a match to be the first." % (" this week" if period == "week" else ""), 24))
		for e: Dictionary in entries:
			var me_row := str(e.get("name", "")) == Game.player_name and Board.registered != ""
			var rank := int(e.get("rank", 0))
			var col: Color = [UiTheme.EMBER, Color(0.66, 0.76, 0.92), Color(0.8, 0.55, 0.35)][rank - 1] if rank >= 1 and rank <= 3 else UiTheme.BONE
			var row := _board_row(str(rank), str(e.get("name", "")), str(int(e.get("points", 0))), Board.class_label(str(e.get("class", "")), str(e.get("spec", ""))), col, false)
			if me_row:
				var mark := UiTheme.flat(Color(UiTheme.EMBER, 0.18), Color(UiTheme.EMBER, 0.6), 6, 4.0)
				row.add_theme_stylebox_override("panel", mark)
			list.add_child(row)
		var me: Dictionary = result.get("me", {})
		if not me.is_empty():
			if me.get("rank") == null:
				mine.text = "You (%s) haven't scored here yet%s." % [Game.player_name, " this week" if period == "week" else ""]
			else:
				mine.text = "You: #%d with %d points." % [int(me["rank"]), int(me["points"])]
		if period == "week" and int(result.get("week_end", 0)) > 0:
			var left := int(result["week_end"]) - int(Time.get_unix_time_from_system())
			note.text += " A new week starts in %s." % _span(left)
			var prizes: Array = result.get("prizes", [])
			if prizes.size() == 3 and kind == "all":
				note.text += " The top three of the week win %d, %d and %d doubloons." % [int(prizes[0]), int(prizes[1]), int(prizes[2])]
	_note_pending(mine)


func _board_problem(error: String) -> Label:
	var why := "Can't reach the leaderboard. Check your connection and try again."
	if error == "wrong_board":
		why = "The leaderboard answered for another version of the game, so it was ignored."
	var l := _soft(why, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _note_pending(mine: Label) -> void:
	if not Board.pending.is_empty():
		mine.text += ("  " if mine.text != "" else "") + ("%d of your matches haven't been sent yet." % Board.pending.size() if Board.pending.size() > 1 else "One of your matches hasn't been sent yet.")


static func _map_word(map: String) -> String:
	return {"village": "Village", "mists": "Mists", "fort": "Fort", "mesenlla": "Mesenlla", "bastion": "Mist Bastion"}.get(map, map.capitalize())


## "Night · Mists", "Co-op · Village", "All vs All · Village"; the Fort is its own map, so just "Fort",
## and Mist Bastion "Fort · Mist Bastion".
static func _match_word(mode: String, map: String) -> String:
	var word: String = {"night": "Night", "coop": "Co-op", "fort": "Fort", "ffa": "All vs All", "teams": "Teams"}.get(mode, mode.capitalize())
	return word if map == "fort" or map == "" else word + " · " + _map_word(map)


## "Just now", "12 min ago", "3 h ago", "2 days ago", then the date.
static func _ago(unix: int) -> String:
	var s := int(Time.get_unix_time_from_system()) - unix
	if s < 90:
		return "Just now"
	if s < 3600:
		return "%d min ago" % (s / 60)
	if s < 86400:
		return "%d h ago" % (s / 3600)
	if s < 7 * 86400:
		return "%d day%s ago" % [s / 86400, "" if s / 86400 == 1 else "s"]
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%d %s" % [d["day"], ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][int(d["month"]) - 1]]


func _history_row(when: String, played: String, as_class: String, kills: String, result: String, points: String, header: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.flat(Color(0, 0, 0, 0), Color.TRANSPARENT, 6, 4.0))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)
	var size := 21 if header else 23
	var cells: Array = [[when, 150.0, HORIZONTAL_ALIGNMENT_LEFT], [played, 200.0, HORIZONTAL_ALIGNMENT_LEFT], [as_class, 0.0, HORIZONTAL_ALIGNMENT_LEFT],
		[kills, 80.0, HORIZONTAL_ALIGNMENT_RIGHT], [result, 170.0, HORIZONTAL_ALIGNMENT_LEFT], [points, 90.0, HORIZONTAL_ALIGNMENT_RIGHT]]
	for i in cells.size():
		var cell: Array = cells[i]
		var l := _body(str(cell[0]), size)
		l.horizontal_alignment = cell[2]
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.add_theme_color_override("font_color", UiTheme.ASH if header or i == 0 else UiTheme.BONE)
		if i == 2:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = cell[1]
		if not header and i == 5:
			l.add_theme_font_override("font", UiTheme.bold_font())
			l.add_theme_color_override("font_color", UiTheme.EMBER)
		line.add_child(l)
	return row


## "2 days 5 hours", "3 hours 10 minutes", "12 minutes".
static func _span(seconds: int) -> String:
	seconds = maxi(seconds, 60)
	var days := seconds / 86400
	var hours := (seconds % 86400) / 3600
	var minutes := (seconds % 3600) / 60
	var plural := func(n: int, word: String) -> String: return "%d %s%s" % [n, word, "" if n == 1 else "s"]
	if days > 0:
		return "%s %s" % [plural.call(days, "day"), plural.call(hours, "hour")]
	if hours > 0:
		return "%s %s" % [plural.call(hours, "hour"), plural.call(minutes, "minute")]
	return plural.call(minutes, "minute")


func _board_row(rank: String, who: String, points: String, played: String, col: Color, header: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.flat(Color(0, 0, 0, 0), Color.TRANSPARENT, 6, 4.0))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)
	var size := 21 if header else 25
	var cells: Array = [[rank, 64.0, HORIZONTAL_ALIGNMENT_RIGHT], [who, 300.0, HORIZONTAL_ALIGNMENT_LEFT], [points, 140.0, HORIZONTAL_ALIGNMENT_RIGHT], [played, 0.0, HORIZONTAL_ALIGNMENT_LEFT]]
	for i in cells.size():
		var cell: Array = cells[i]
		var l := _body(str(cell[0]), size)
		l.horizontal_alignment = cell[2]
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.add_theme_color_override("font_color", UiTheme.ASH if header else (col if i < 2 else UiTheme.BONE))
		if i == 3:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if not header:
				l.add_theme_color_override("font_color", UiTheme.ASH)
		else:
			l.custom_minimum_size.x = cell[1]
		if not header and i == 1:
			l.add_theme_font_override("font", UiTheme.bold_font())
		line.add_child(l)
	return row
