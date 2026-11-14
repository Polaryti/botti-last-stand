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
var _warmed := false # see _warm_up
var _warm_models: Array[Resource] = []
var _store_return := Callable() # where the Store's Back goes
var _start_listed := true # online: a new game is public unless you choose private
var updates: Updates
var _update_box: HBoxContainer
var _checked_updates := false
var _pause_root: Control
var _net_go := false

const ARMORY_TABS := ["Paths", "Appearance"]
var _armory_tab := 0
const TOGETHER_TABS := ["Same Wi-Fi", "Online"]
const ONLINE_TAB := 1
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
	"In The Village, the bell strikes once for each minute gone, and draws zombies to the church.",
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
	# Every button anywhere in the menus gives under the finger, whoever made it.
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			UiTheme.give(n as BaseButton))
	Net.game_started.connect(func() -> void: start_game(Net.game_mode()))
	Net.left.connect(_on_net_left)
	Net.game_over.connect(_on_net_over)
	Net.all_ready.connect(func() -> void: _net_go = true)
	Net.back_in_room.connect(_return_to_room)
	updates = Updates.new()
	add_child(updates)
	var auto := AutoQuality.new(self)
	auto.name = "AutoQuality"
	add_child(auto)
	auto.changed.connect(_on_auto_quality)
	if Game.test_map != "":
		# Someone pressed F6 on a map in the editor, so go straight to it.
		var map := Game.test_map
		start_game(Game.Mode.SANDBOX if map.contains("sandbox") else (Game.Mode.FORT if map.contains("fort") or map.contains("bastion") else Game.Mode.NIGHT))
		return
	show_menu()


## Auto graphics picked a level (on the title screen) or stepped down (in a match). The pick takes
## hold at once for sharpness and effects, and in full with the next world that is built.
func _on_auto_quality(quality: int, in_match: bool) -> void:
	if in_match:
		if world and is_instance_valid(world):
			world._grade()
			world.director.local_banner("Graphics lowered to %s to keep the game smooth" % ["Low", "Medium", "High"][quality], 4.0)


func _quit() -> void:
	get_tree().quit()


func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The first time a class is shown turning on its stand (the Store, choosing a class) its model has to
## be read and its look prepared for drawing, which made those screens hitch as they opened. The
## models are read in the background as the menu first appears and kept, and one is drawn once out of
## sight a moment later, while nothing else is happening.
func _warm_up() -> void:
	if _warmed:
		return
	_warmed = true
	var paths := PackedStringArray()
	for model: String in ["clever", "magic", "beast"]:
		var path := "res://assets/characters/%s.glb" % model
		paths.append(path)
		ResourceLoader.load_threaded_request(path)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		for path in paths:
			_warm_models.append(ResourceLoader.load_threaded_get(path))
		var view := ModelView.new(Vector2(96, 96))
		view.position = Vector2(-4000, -4000)
		add_child(view)
		view.show_class(Game.player_class if ClassDefs.ALL.has(Game.player_class) else "infantry")
		get_tree().create_timer(0.4).timeout.connect(view.queue_free))


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
	# Back from a match: worth looking again for a new version, which may have come out while playing.
	var from_match := world != null and world.mode != Game.Mode.MENU
	# Coming back from another menu screen, the Valleys behind it can simply stay.
	if rebuild or world == null or world.mode != Game.Mode.MENU:
		_new_world(Game.Mode.MENU)
	Sfx.ambient(true)
	Sfx.set_mood(0.0, 0.0)
	_warm_up()
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
	var update_title := _label("Beyond the Mists", UiTheme.FS_LEAD, UiTheme.TWILIGHT.lightened(0.25))
	update_title.name = "UpdateTitle"
	update_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(update_title)
	top.add_child(_expand())
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
	# (Once a new version has been found, the offer stands until it is taken.)
	if not _checked_updates or (from_match and updates.state != Updates.State.AVAILABLE):
		_checked_updates = true
		updates.check()
	foot.add_child(_button("Codex", show_codex, Vector2(132, UiTheme.BTN)))
	var notes := _button("Changelog", show_changelog, Vector2(168, UiTheme.BTN))
	notes.name = "ChangelogButton"
	foot.add_child(notes)
	if ChangelogPanel.has_news():
		# New notes since you last read them: the button glows on and off until you do.
		notes.set_meta("news", true)
		var glow := notes.create_tween().set_loops()
		glow.tween_property(notes, "self_modulate", Color(1.0, 0.62, 0.25), 0.55).set_trans(Tween.TRANS_SINE)
		glow.tween_property(notes, "self_modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)
	foot.add_child(_button("Settings", show_settings, Vector2(146, UiTheme.BTN)))
	var version := _soft("v%s" % ProjectSettings.get_setting("application/config/version"), UiTheme.FS_SMALL)
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
	var l := _body(line, UiTheme.FS_BODY)
	l.add_theme_color_override("font_color", UiTheme.EMBER)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_box.add_child(l)
	if action != "":
		_update_box.add_child(_button(action, press, Vector2(150, UiTheme.BTN), true))


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
	var head := _label(title, UiTheme.FS_TITLE, UiTheme.EMBER if first else UiTheme.BONE)
	head.add_theme_font_override("font", UiTheme.bold_font())
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(head)
	var sub := _soft(line, UiTheme.FS_BODY)
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
	var count := _label("%d" % Game.doubloons, UiTheme.FS_HEAD, UiTheme.BONE)
	count.add_theme_font_override("font", UiTheme.bold_font())
	row.add_child(count)
	var word := _soft("Store", UiTheme.FS_LEAD)
	word.add_theme_color_override("font_color", UiTheme.EMBER)
	row.add_child(word)
	b.custom_minimum_size.x = 64.0 + 44.0 + 30.0 + _text_width(str(Game.doubloons), UiTheme.FS_HEAD) + _text_width("Store", UiTheme.FS_LEAD)
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
	var root := _screen("Settings", func() -> void: _back.call(), "Kept on this phone." if not from_pause else ("The night goes on while you are here." if Net.active() else ""))
	_back = func() -> void:
		root.queue_free()
		_back = _resume if from_pause else _quit
	var page := UiScreen.page(root.get_meta("box"))
	var scroll := DragScroll.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.name = "SettingsRows"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(inner)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	inner.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for side: VBoxContainer in [left, right]:
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
		columns.add_child(side)
	if not from_pause:
		# Who you are to other players and on the leaderboard: first, as it is who you are.
		_section(left, "You", true)
		var name_row := HBoxContainer.new()
		name_row.name = "NameRow"
		name_row.add_theme_constant_override("separation", UiTheme.GAP)
		left.add_child(name_row)
		var name_title := _soft("Your name", UiTheme.FS_BODY)
		name_title.custom_minimum_size.x = 130
		name_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(name_title)
		var rename := _button(Game.player_name, func() -> void:
			root.queue_free()
			show_name_prompt(false, func() -> void: show_settings()), Vector2(0, UiTheme.BTN))
		rename.name = "Rename"
		rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename.tooltip_text = "Change your name"
		name_row.add_child(rename)
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
		left.add_child(code_row)
		var code := LineEdit.new()
		code.placeholder_text = "Redeem a code"
		code.custom_minimum_size = Vector2(0, UiTheme.BTN)
		code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_row.add_child(code)
		var answer := _soft("", UiTheme.FS_SMALL)
		code_row.add_child(_button("Redeem", func() -> void: _try_code(code, answer), Vector2(140, UiTheme.BTN)))
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(answer)
		# Both of these only apply to a new night, so they stay out of a running game.
		_section(left, "Game")
		left.add_child(_soft("Difficulty", UiTheme.FS_BODY))
		left.add_child(_choices(["Easy", "Normal", "Hard"], Game.difficulty, 380.0, func(i: int) -> void:
			Game.difficulty = i
			Game.save_settings()
			root.queue_free()
			show_settings()))
		left.add_child(_soft("Graphics" if not Game.quality_auto else "Graphics (Auto: %s now)" % ["Low", "Medium", "High"][Game.quality], UiTheme.FS_BODY))
		left.add_child(_choices(["Auto", "Low", "Medium", "High"], 0 if Game.quality_auto else Game.quality + 1, 380.0, func(i: int) -> void:
			Game.quality_auto = i == 0
			if i == 0:
				Game.quality_measured = false # look again
				Game.quality = 1
			else:
				Game.quality = i - 1
			Game.apply_quality()
			Game.save_settings()
			show_menu(true)))
	_section(left, "Sound", from_pause)
	_slider(left, "Music", 0.0, 1.0, Game.music_volume, func(v: float) -> void:
		Game.music_volume = v
		Sfx.apply_volumes())
	_slider(left, "Sounds", 0.0, 1.0, Game.sound_volume, func(v: float) -> void:
		Game.sound_volume = v
		Sfx.apply_volumes())
	_section(right, "Controls", true)
	_slider(right, "Look sensitivity", 0.4, 2.5, Game.sensitivity, func(v: float) -> void: Game.sensitivity = v)
	right.add_child(_toggle("Auto-jump", func() -> bool: return Game.auto_jump, func(on: bool) -> void: Game.auto_jump = on))
	right.add_child(_toggle("Vibration", func() -> bool: return Game.vibration, func(on: bool) -> void: Game.vibration = on))
	_section(right, "Screen")
	right.add_child(_toggle("Damage numbers", func() -> bool: return Game.damage_numbers, func(on: bool) -> void: Game.damage_numbers = on))
	right.add_child(_toggle("Steady brightness", func() -> bool: return Game.steady_brightness, func(on: bool) -> void:
		Game.steady_brightness = on
		PhoneScreen.apply_brightness()))
	_slider(right, "Screen brightness, when steady", 0.1, 1.0, Game.brightness if Game.brightness > 0.0 else PhoneScreen.current_level(), func(v: float) -> void:
		Game.brightness = v
		PhoneScreen.apply_brightness())


## The heading of a group of settings (or of any part of a page).
func _section(box: Control, title: String, first := false) -> void:
	if not first:
		var gap := Control.new()
		gap.custom_minimum_size.y = 10
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gap)
	var head := _label(title, UiTheme.FS_LEAD, UiTheme.EMBER)
	head.add_theme_font_override("font", UiTheme.bold_font())
	head.add_theme_constant_override("outline_size", 0)
	box.add_child(head)


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
		var b := _button(str(names[i]), func() -> void: picked.call(index), Vector2((width - 6.0 * (names.size() - 1)) / names.size(), UiTheme.BTN_SHORT))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == on:
			UiTheme.selected(b)
		row.add_child(b)
	return row


func _slider(box: VBoxContainer, title: String, low: float, high: float, value: float, changed: Callable) -> void:
	box.add_child(_soft(title, UiTheme.FS_BODY))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(360, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		changed.call(v)
		Game.save_settings())
	box.add_child(slider)


## A name on the left, and a switch at the right that says whether it is on. The whole row is the
## thing to tap.
func _toggle(title: String, read: Callable, write: Callable) -> Button:
	var b := _button("", func() -> void: pass, Vector2(380, UiTheme.BTN))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.GAP)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	var name_label := _body(title, UiTheme.FS_BODY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var knob := UiSwitch.new(read.call())
	knob.name = "Switch"
	row.add_child(knob)
	b.pressed.connect(func() -> void:
		write.call(not read.call())
		Game.save_settings()
		knob.on = read.call())
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
	ChangelogPanel.mark_read()
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
	UiTheme.size_button(b, min_size.y)
	if primary:
		UiTheme.primary(b)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -3.0))
	b.pressed.connect(action)
	return b


## One of a row of options, marked when it is the one chosen. (A choice is never drawn as the big
## thing to do on a screen: that is what a primary button is for.)
func _choice(text: String, action: Callable, min_size: Vector2, on: bool) -> Button:
	var b := _button(text, action, min_size)
	if on:
		UiTheme.selected(b)
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
	var root := _screen("Defend the Fort" if fort else "Survive the Night", func() -> void: _back.call(), "Where will you hold the line?" if fort else "Where will you spend the night?")
	root.name = "Atlas"
	var box: VBoxContainer = root.get_meta("box")
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
		var title := _label(place["name"], UiTheme.FS_HEAD, UiTheme.BONE)
		title.add_theme_font_override("font", UiTheme.title_font())
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		var lore := _label(place["lore"], UiTheme.FS_BODY, UiTheme.ASH)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size.x = 300
		detail.add_child(lore)
		var plays := _label("Played in %s." % place["plays"], UiTheme.FS_SMALL, UiTheme.BONE.darkened(0.15))
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
			show_class_picker(mode), Vector2(0, UiTheme.BTN_TALL), true)
		go.name = "PlayHere"
		detail.add_child(go)
	atlas.picked.connect(show_place)
	show_place.call(atlas.selected)
	panel = root


func show_class_picker(mode: int) -> void:
	_clear_ui()
	_back = show_map_picker if mode == Game.Mode.NIGHT else show_fort_picker if mode == Game.Mode.FORT else show_menu
	var root := _two_panes("Choose your class", true)
	var list: VBoxContainer = root.get_meta("list")
	var detail: VBoxContainer = root.get_meta("detail")
	var ids := ClassDefs.ALL.keys().filter(func(id: String) -> bool: return not ClassDefs.disabled(id))
	if mode == Game.Mode.SANDBOX:
		ids = ClassDefs.available()
	var rows := {}
	var pick := func(id: String) -> void:
		for other: String in rows:
			UiTheme.plain(rows[other])
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
func _two_panes(title: String, purse := false) -> Control:
	var root := _screen(title, func() -> void: _back.call())
	var box: VBoxContainer = root.get_meta("box")
	if purse:
		(root.get_meta("right") as Control).add_child(_purse())
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
	# The page scrolls when what it says is longer than the screen; when it is shorter, its last
	# button still sits at the bottom.
	var reading := DragScroll.new()
	reading.name = "DetailScroll"
	reading.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(reading)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	reading.add_child(detail)
	root.set_meta("panes", panes)
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
	var name_label := _body(c["name"], UiTheme.FS_LEAD)
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
	var title := _body(c["name"], UiTheme.FS_TITLE)
	title.add_theme_font_override("font", UiTheme.title_font())
	words.add_child(title)
	words.add_child(_soft(ClassPresentation.stats_line(id), UiTheme.FS_BODY))
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
	var desc := _body(ClassPresentation.description(id), UiTheme.FS_LEAD)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.add_child(desc)
	for spec: Dictionary in AbilityData.tree(id)["specs"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		prose.add_child(line)
		var emblem := IconView.new("spec_%s" % spec["id"], ClassDefs.color(id), 44.0)
		emblem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(emblem)
		var spec_name := _body(spec["name"], UiTheme.FS_BODY)
		spec_name.add_theme_font_override("font", UiTheme.bold_font())
		spec_name.custom_minimum_size.x = 190
		spec_name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(spec_name)
		var spec_desc := _soft(ClassPresentation.profession(spec), UiTheme.FS_BODY)
		spec_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spec_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(spec_desc)
	if id == "ranger" and not in_store and ShopDefs.PETS.any(func(p: String) -> bool: return Game.owns_item(p)):
		var pets := HBoxContainer.new()
		pets.add_theme_constant_override("separation", 6)
		prose.add_child(pets)
		pets.add_child(_body("Pet", UiTheme.FS_BODY))
		for pet: String in ShopDefs.PETS:
			if pet == "wolf" or Game.owns_item(pet):
				var chosen_pet := pet
				pets.add_child(_choice(pet.capitalize(), func() -> void:
					Game.choose_pet(chosen_pet)
					_fill_class_detail(detail, id, mode, in_store), Vector2(120, UiTheme.BTN_SHORT), Game.pet == pet))
	if not owned and c.get("unavailable", false):
		var how := _body(CodexPanel.acquisition(id), UiTheme.FS_LEAD)
		how.add_theme_color_override("font_color", UiTheme.ASH)
		detail.add_child(how)
	elif not owned and c.has("earned"):
		var how := _body(Game.earn_text(id), UiTheme.FS_LEAD)
		how.add_theme_color_override("font_color", UiTheme.EMBER)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(how)
	elif not owned:
		_buy_row(detail, id, mode, in_store)
	elif in_store:
		var have := _body("You own this class.", UiTheme.FS_LEAD)
		have.add_theme_color_override("font_color", UiTheme.MOSS)
		detail.add_child(have)
	else:
		var chosen := id
		var go := _button("Play as %s" % c["name"], func() -> void:
			Sfx.play("ui_choose", -3.0)
			Game.player_class = chosen
			Game.save_settings()
			start_game(mode), Vector2(0, UiTheme.BTN_TALL), true)
		detail.add_child(go)


## The price and the way to pay it. The first press asks, so a stray thumb cannot spend a week of nights.
func _buy_row(detail: VBoxContainer, id: String, mode: int, in_store: bool) -> void:
	var price := ClassDefs.price(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	detail.add_child(row)
	row.add_child(_coin(52.0))
	var cost := _body("%d" % price, UiTheme.FS_HEAD)
	cost.add_theme_font_override("font", UiTheme.bold_font())
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost)
	var left := Control.new()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	if not in_store:
		row.add_child(_button("Go to Store", func() -> void: show_store(id, mode), Vector2(220, UiTheme.BTN_TALL), true))
		return
	var buy := _button("Buy", func() -> void: pass, Vector2(260, UiTheme.BTN_TALL), true)
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
			show_store("", mode, "classes", Callable(), id))
	row.add_child(buy)


## Everything for sale, by section. What you pick turns slowly beside its description.
## back_to: where Back goes, when the Store was opened from somewhere other than the menu or a class.
## Moving around inside the Store keeps it.
func show_store(focus := "", from_mode := -1, section := "", back_to := Callable(), just_bought := "") -> void:
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
	var root := _two_panes("Store", true)
	var list: VBoxContainer = root.get_meta("list")
	var detail: VBoxContainer = root.get_meta("detail")
	var keys: Array = ShopDefs.SECTIONS.keys()
	var tabs := UiScreen.tabs(root.get_meta("box"), keys.map(func(k: String) -> String: return ShopDefs.SECTIONS[k]), keys.find(section), func(i: int) -> void: show_store("", from_mode, keys[i], here))
	tabs.get_parent().move_child(tabs, 1)
	# What you own is not for sale any more: it leaves the list, and lives in the Armory.
	var ids: Array[String] = []
	ids.assign((ClassDefs.for_sale() if section == "classes" else ShopDefs.in_section(section)).filter(func(id: String) -> bool:
		return not (Game.owns_class(id) if section == "classes" else Game.owns_item(id))))
	if just_bought != "":
		var name_of: String = ClassDefs.ALL[just_bought]["name"] if ClassDefs.ALL.has(just_bought) else ShopDefs.ITEMS[just_bought]["name"]
		var bought := _body("Bought: %s. It is yours now, in the Armory." % name_of, UiTheme.FS_BODY)
		bought.name = "JustBought"
		bought.add_theme_color_override("font_color", UiTheme.MOSS)
		list.add_child(bought)
		bought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ids.is_empty():
		var none := _soft("You own everything here.", UiTheme.FS_BODY)
		none.name = "NothingLeft"
		list.add_child(none)
		# The other pane says where it all went, and takes you there.
		var gone := _body("Everything in %s is yours. Equip it, or take it off, in the Armory." % ShopDefs.SECTIONS.get(section, "Classes"), UiTheme.FS_LEAD)
		gone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(gone)
		var to_class := ""
		if ShopDefs.ITEMS.has(just_bought):
			to_class = str(ShopDefs.ITEMS[just_bought]["class"])
		elif ClassDefs.ALL.has(just_bought):
			to_class = just_bought
		var to_tab := 1 if section == "cosmetics" else 0
		var go := _button("Open the Armory", func() -> void: show_armory(to_class, to_tab), Vector2(280, UiTheme.BTN), true)
		go.name = "OpenArmory"
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		detail.add_child(go)
		panel = root
		return
	var rows := {}
	var pick := func(id: String) -> void:
		for other: String in rows:
			UiTheme.plain(rows[other])
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
	var name_label := _body(d["name"], UiTheme.FS_BODY)
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
	var whose := _soft(ShopDefs.whose(id), UiTheme.FS_TINY)
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
	var title := _body(d["name"], UiTheme.FS_HEAD)
	title.add_theme_font_override("font", UiTheme.title_font())
	words.add_child(title)
	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 10)
	owner_row.add_child(IconView.new(ClassDefs.icon(d["class"]), ClassDefs.color(d["class"]), 46.0))
	if d["spec"] != "":
		owner_row.add_child(IconView.new("spec_%s" % d["spec"], ClassDefs.color(d["class"]), 46.0))
	var owner_words := _soft(ShopDefs.whose(id), UiTheme.FS_BODY)
	owner_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owner_row.add_child(owner_words)
	words.add_child(owner_row)
	var desc := _body(d["desc"], UiTheme.FS_BODY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(desc)
	if Game.owns_item(id):
		var have := _body("You own this. Find it in the Armory.", UiTheme.FS_LEAD)
		have.add_theme_color_override("font_color", UiTheme.MOSS)
		detail.add_child(have)
		return
	var price := int(d["price"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	detail.add_child(row)
	row.add_child(_coin(52.0))
	var cost := _body("%d" % price, UiTheme.FS_HEAD)
	cost.add_theme_font_override("font", UiTheme.bold_font())
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost)
	var left := Control.new()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var buy := _button("Buy", func() -> void: pass, Vector2(260, UiTheme.BTN_TALL), true)
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
			show_store("", from_mode, str(ShopDefs.ITEMS[id]["section"]), _store_return, id))
	row.add_child(buy)


## What you own for each class, to switch on and off.
## `tab`: 0 the paths and their Class Upgrades, 1 the class's looks.
func show_armory(focus := "", tab := 0) -> void:
	_armory_tab = tab
	_clear_ui()
	_back = show_menu
	var root := _two_panes("Armory", true)
	var list: VBoxContainer = root.get_meta("list")
	var detail: VBoxContainer = root.get_meta("detail")
	var rows := {}
	var pick := func(id: String) -> void:
		for other: String in rows:
			UiTheme.plain(rows[other])
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
	# On the Appearance tab the stage below is the class's; up here, only its name and line.
	var looks_tab := _armory_tab == 1
	if not looks_tab:
		var view := ModelView.new(Vector2(170, 180))
		view.show_class(id)
		head.add_child(view)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 10)
	head.add_child(words)
	var title := _body(ClassDefs.ALL[id]["name"], UiTheme.FS_HEAD)
	title.add_theme_font_override("font", UiTheme.title_font())
	words.add_child(title)
	words.add_child(_body(ClassPresentation.COPY[id][0], UiTheme.FS_BODY))
	if looks_tab:
		_armory_tabs(detail, id)
		detail.add_child(_appearance(id))
		_wrap_labels(detail)
		return
	var d: Dictionary = ClassDefs.ALL[id]
	words.add_child(_soft("%s\nStarting weapon: %s · Starting arrows: %d" % [ClassPresentation.stats_line(id), WeaponDefs.ALL[d["weapon"]]["name"], int(d["arrows"])], UiTheme.FS_SMALL))
	words.add_child(ClassPresentation.weapon_tags(id))
	words.add_child(_body(ClassPresentation.COPY[id][1], UiTheme.FS_BODY))
	_armory_tabs(detail, id)
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
		content.add_child(_body(spec["name"], UiTheme.FS_HEAD))
		content.add_child(_body(ClassPresentation.profession(spec), UiTheme.FS_BODY))
		var upgrades := items.filter(func(item: String) -> bool: return ShopDefs.ITEMS[item]["spec"] == spec["id"])
		if not upgrades.is_empty():
			content.add_child(_armory_spec_row(id, spec["id"], upgrades))
		else:
			content.add_child(_soft("No Class Upgrades available for this profession.", UiTheme.FS_SMALL))
	_wrap_labels(detail)


func _armory_tabs(detail: VBoxContainer, id: String) -> void:
	UiScreen.tabs(detail, ARMORY_TABS, _armory_tab, func(i: int) -> void:
		_armory_tab = i
		_fill_armory(detail, id))


func _wrap_labels(detail: Control) -> void:
	for label: Label in detail.find_children("*", "Label", true, false):
		if not label.get_parent().has_meta("tag"):
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## The Armory's Appearance tab: a stage showing a look, and beside it the class's looks (the one it
## starts with and those from the Store's Cosmetics), each on a small stage of its own. Tapping a look
## shows it on the big stage; a look you own is worn from here, one you do not is a tap from the Store.
func _appearance(class_id: String) -> Control:
	var section := VBoxContainer.new()
	section.name = "CosmeticsSection"
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	var skins: Array = ShopDefs.for_class(class_id).filter(func(item: String) -> bool: return ShopDefs.ITEMS[item]["section"] == "cosmetics")
	if skins.is_empty() or not ShopDefs.DEFAULT_LOOKS.has(class_id):
		var own := ModelView.new(Vector2(220, 240))
		own.show_class(class_id)
		section.add_child(own)
		section.add_child(_soft("Default appearance. No other looks for this class yet.", UiTheme.FS_BODY))
		return section
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(row)
	var stage := VBoxContainer.new()
	stage.add_theme_constant_override("separation", 4)
	row.add_child(stage)
	var view := ModelView.new(Vector2(280, 270))
	view.name = "LookStage"
	stage.add_child(view)
	var caption := _body("", UiTheme.FS_SMALL)
	caption.name = "StageCaption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(caption)
	var list := VBoxContainer.new()
	list.name = "Looks"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	row.add_child(list)
	list.add_child(_soft("Tap a look to see it on the stage.", UiTheme.FS_SMALL))
	var looks: Array[String] = [""]
	looks.append_array(skins)
	var cards: Array[PanelContainer] = []
	var show_look := func(look: String) -> void:
		for card in cards:
			card.add_theme_stylebox_override("panel", UiTheme.flat(UiTheme.DUSK, UiTheme.EMBER if card.get_meta("look") == look else UiTheme.STEEL, UiTheme.RADIUS_CARD, 10.0))
			(card.get_meta("update") as Callable).call()
		var d: Dictionary = ShopDefs.ITEMS[look] if look != "" else ShopDefs.DEFAULT_LOOKS[class_id]
		view.show_mount(look != "" and str(d.get("skin", "")) == "stag")
		caption.text = ("Wearing: %s" if _look_worn(class_id, look) else "Trying on: %s") % d["name"]
	for look: String in looks:
		var card := _look_card(class_id, look, show_look)
		cards.append(card)
		list.add_child(card)
	var worn := ""
	for look: String in looks:
		if _look_worn(class_id, look):
			worn = look
	show_look.call(worn)
	return section


## One look: its small stage, its name and state, and the button that wears it (or finds it in the Store).
func _look_card(class_id: String, look: String, show_look: Callable) -> PanelContainer:
	var d: Dictionary = ShopDefs.ITEMS[look] if look != "" else ShopDefs.DEFAULT_LOOKS[class_id]
	var card := PanelContainer.new()
	card.name = "Look_%s" % (look if look != "" else "default")
	card.set_meta("look", look)
	card.add_theme_stylebox_override("panel", UiTheme.flat(UiTheme.DUSK, UiTheme.STEEL, UiTheme.RADIUS_CARD, 10.0))
	# The whole card shows the look on the stage; its button wears or buys it.
	var tap := Button.new()
	tap.name = "TryOn"
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	card.add_child(tap)
	tap.pressed.connect(func() -> void:
		Sfx.play("ui_click", -5.0)
		show_look.call(look))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(line)
	var thumb := ModelView.new(Vector2(120, 100))
	thumb.show_mount(look != "" and str(d.get("skin", "")) == "stag")
	line.add_child(thumb)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(words)
	words.add_child(_body(str(d["name"]), UiTheme.FS_BODY))
	var state := _soft("", UiTheme.FS_SMALL)
	words.add_child(state)
	var owned := look == "" or Game.owns_item(look)
	var act := _button("", func() -> void: pass, Vector2(150, UiTheme.BTN_SHORT))
	act.name = "LookButton"
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(act)
	card.set_meta("update", func() -> void:
		var on := _look_worn(class_id, look)
		if not owned:
			state.text = "%d Doubloons" % int(d["price"])
			act.text = "In the Store"
			UiTheme.plain(act)
		else:
			state.text = "Worn" if on else "Yours"
			act.text = "Worn" if on else "Wear"
			if on: UiTheme.selected(act)
			else: UiTheme.plain(act)
		UiTheme.size_button(act, UiTheme.BTN_SHORT))
	act.pressed.connect(func() -> void:
		if not owned:
			show_store(look, -1, "", func() -> void: show_armory(class_id, 1))
			return
		# Wearing one look takes off the others of the same class.
		for other: String in ShopDefs.ITEMS:
			if ShopDefs.ITEMS[other]["section"] == "cosmetics" and ShopDefs.ITEMS[other]["class"] == class_id and Game.owns_item(other):
				Game.set_item_on(other, other == look)
		show_look.call(look))
	return card


## Whether this look ("" for the class's own) is the one worn.
static func _look_worn(class_id: String, look: String) -> bool:
	if look != "":
		return ShopDefs.skin_on(look)
	for other: String in ShopDefs.ITEMS:
		if ShopDefs.ITEMS[other]["section"] == "cosmetics" and ShopDefs.ITEMS[other]["class"] == class_id and ShopDefs.skin_on(other):
			return false
	return true


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
	column.add_child(_body("Class Upgrades", UiTheme.FS_BODY))
	if ShopDefs.ITEMS[items[0]].get("pet", false):
		column.add_child(_pet_row())
		return row
	for item: String in items:
		column.add_child(_item_switch(class_id, item))
	return row


## One item's name and what it does, with Equipped / Not equipped when you own it, or the way to the
## Store when you do not.
func _item_switch(class_id: String, item: String) -> Control:
	var d: Dictionary = ShopDefs.ITEMS[item]
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	column.add_child(line)
	var name_label := _soft(d["name"], UiTheme.FS_BODY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var description := _soft(d["desc"], UiTheme.FS_SMALL)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	if not Game.owns_item(item):
		line.add_child(_button("In the Store", func() -> void: show_store(item, -1, "", func() -> void: show_armory(class_id)), Vector2(190, UiTheme.BTN_SHORT)))
		return column
	var on := Game.item_active(item)
	var toggle := _choice("Equipped" if on else "Not equipped", func() -> void: pass, Vector2(190, UiTheme.BTN_SHORT), on)
	line.add_child(toggle)
	toggle.pressed.connect(func() -> void:
		Game.set_item_on(item, not Game.item_active(item))
		var active := Game.item_active(item)
		toggle.text = "Equipped" if active else "Not equipped"
		if active: UiTheme.selected(toggle)
		else: UiTheme.plain(toggle))
	return column


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
		var b := _choice(label, func() -> void:
			if not owned:
				show_store(chosen, -1, "", func() -> void: show_armory("ranger"))
				return
			Game.choose_pet(chosen)
			if panel:
				show_armory("ranger"), Vector2(0, UiTheme.BTN_SHORT), Game.pet == pet)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_rewards.clear()
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
	var caption := _label(mode_word, UiTheme.FS_LEAD, UiTheme.EMBER)
	caption.name = "Mode"
	box.add_child(caption)
	var title := _label(str(place.get("name", "Sandbox")), 64, UiTheme.BONE)
	title.name = "Place"
	title.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(title)
	var lore := _label(str(place.get("lore", "Try any weapon, item or class you own.")), UiTheme.FS_LEAD, UiTheme.ASH)
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
	words.add_child(_label(str(ClassDefs.ALL[Game.player_class]["name"]), UiTheme.FS_HEAD, UiTheme.BONE))
	var hints: Array = place.get("tips", []).duplicate()
	if where in ["village", "fort", ""]:
		hints.append_array(TIPS)
	var tip := _label(str(hints[randi() % hints.size()]), UiTheme.FS_BODY, UiTheme.ASH)
	tip.name = "Tip"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 760
	words.add_child(tip)
	row.add_child(_expand())
	var preparing := _label("Preparing the night" if Game.mode != Game.Mode.SANDBOX else "Preparing the yard", UiTheme.FS_BODY, UiTheme.BONE)
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
	var head := _body(title, UiTheme.FS_TITLE)
	head.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(head)
	root.set_meta("box", box)
	panel = root
	return root


## A menu screen in the one layout every screen shares (UiScreen): the way back at the top left, the
## name of the screen beside it. Its metas: box (everything under the bar), top, right, back.
func _screen(title: String, on_back: Callable, line := "", back_text := "Back") -> Control:
	var root := Control.new()
	root.theme = _theme
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(root)
	_fill(root)
	var parts := UiScreen.frame(root, title, on_back, line, back_text)
	for key: String in parts:
		root.set_meta(key, parts[key])
	# A screen covers whatever it was opened over (the title menu, the HUD and the Pause card) and
	# gives it back when it closes.
	var under: Array[Control] = []
	for c in ui_layer.get_children():
		if c != root and c is Control and (c as Control).visible:
			under.append(c)
			(c as Control).visible = false
	root.tree_exiting.connect(func() -> void:
		for c: Control in under:
			if is_instance_valid(c) and not c.is_queued_for_deletion():
				c.visible = true)
	panel = root
	return root


## How many Doubloons you have, for the right end of a screen's bar.
func _purse() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Purse"
	row.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	row.add_child(_coin(40.0))
	var count := _label("%d" % Game.doubloons, UiTheme.FS_HEAD, UiTheme.BONE)
	count.add_theme_font_override("font", UiTheme.bold_font())
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	return row


## A setting with its name in a column of its own, so a page of them lines up.
func _setting_row(box: Control, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	box.add_child(row)
	var name_label := _soft(title, UiTheme.FS_BODY)
	name_label.custom_minimum_size.x = 150
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	return row


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
	box.add_child(_button("Resume", _resume, Vector2(480, UiTheme.BTN_TALL), true))
	box.add_child(_button("Map", show_map, Vector2(480, UiTheme.BTN_TALL)))
	box.add_child(_button("Settings", func() -> void: show_settings(true), Vector2(480, UiTheme.BTN_TALL)))
	box.add_child(_button("Leave the game" if Net.active() else "Quit to menu", show_menu, Vector2(480, UiTheme.BTN_TALL)))


func show_map() -> void:
	var root := _screen("Map", func() -> void: _back.call(), str(Places.ALL.get(world.map_id, {}).get("name", "")))
	_back = func() -> void:
		root.queue_free()
		_back = _resume
	_square_map(root.get_meta("box")).world = world


## A map as big as the screen allows under its bar, and square.
func _square_map(box: VBoxContainer) -> MapPanel:
	var fit := AspectRatioContainer.new()
	fit.ratio = 1.0
	fit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(fit)
	var map := MapPanel.new()
	fit.add_child(map)
	return map


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
	Game.note_beyond_win()
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


## What the match earned is listed under the end screen's words, each with its picture: doubloons
## with a doubloon, a class unlocked with its emblem, and the leaderboard points. Returns "" so it
## can stand where the words of the end screen are put together.
func _earned_line(earned: int) -> String:
	if earned > 0:
		_rewards.append({"coin": true, "text": "+%d Botti Doubloons" % earned})
	Game.note_game_finished()
	for id: String in Game.fresh_unlocks:
		_rewards.append({"class": id, "text": "%s unlocked!" % ClassDefs.ALL[id]["name"]})
	Game.fresh_unlocks.clear()
	return ""


## The rows of what the match earned, under the end screen's words.
func _reward_rows(box: VBoxContainer) -> void:
	for i in _rewards.size():
		var reward: Dictionary = _rewards[i]
		var row := HBoxContainer.new()
		row.name = "Reward%d" % i
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		if reward.has("coin"):
			row.add_child(_coin(40.0))
		elif reward.has("class"):
			var id: String = reward["class"]
			var emblem := IconView.new(ClassDefs.icon(id), ClassDefs.color(id), 44.0)
			emblem.name = "ClassIcon"
			row.add_child(emblem)
		else:
			var star := IconView.new("star", UiTheme.STEEL, 40.0)
			star.name = "PointsIcon"
			row.add_child(star)
		var words := _body(reward["text"], UiTheme.FS_LEAD)
		words.add_theme_font_override("font", UiTheme.bold_font())
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
	_rewards.clear()


func _on_net_over(title: String, line: String, reached_dawn: bool) -> void:
	if _run_over or world == null:
		return
	_run_over = true
	var won := reached_dawn or Net.last_winner == Net.my_id()
	if reached_dawn:
		Game.note_mists_win()
	if won:
		Game.note_beyond_win()
	line += _earned_line(Game.award_doubloons(world.director.elapsed, world.player.kills, won, not Net.pvp() and Net.humans() > 1))
	line += _board_line(world.director.elapsed, world.player.kills, won)
	close_tree()
	if hud:
		hud.release_all()
		hud.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_back = show_menu
	_close_screens()
	var root := _modal(title)
	var box: VBoxContainer = root.get_meta("box")
	var l := _body(line, UiTheme.FS_LEAD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	_reward_rows(box)
	if Net.is_host():
		box.add_child(_button("Back to the room", Net.return_to_room, Vector2(480, UiTheme.BTN_TALL), true))
		box.add_child(_button("Menu", show_menu, Vector2(480, UiTheme.BTN_TALL)))
	else:
		var wait := _soft("Your host can take everyone back to the room for another night.", UiTheme.FS_BODY)
		wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(wait)
		box.add_child(_button("Menu", show_menu, Vector2(480, UiTheme.BTN_TALL), true))


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
	var l := _body(reason, UiTheme.FS_LEAD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(_button("OK", func() -> void: root.queue_free(), Vector2(480, UiTheme.BTN_TALL), true))


# --- Play together -----------------------------------------------------------

## What you can ask for in the Sandbox. The world waits while this is open.
func show_sandbox_menu() -> void:
	if world == null or Game.mode != Game.Mode.SANDBOX or (_pause_root and is_instance_valid(_pause_root)):
		return
	if hud:
		hud.release_all()
		hud.menu_open = true
	get_tree().paused = true
	var root := _screen("Sandbox", _resume, "The world waits while you are here.", "Back to it")
	_pause_root = root
	_back = _resume
	var page := UiScreen.page(root.get_meta("box"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	page.add_child(box)
	_section(box, "Bring in an enemy, a few steps in front of you", true)
	# Every enemy in the game no longer fits on one screen: the list scrolls, the rest stays put.
	var enemy_scroll := DragScroll.new()
	enemy_scroll.name = "SandboxEnemies"
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(enemy_scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UiTheme.GAP_SMALL)
	grid.add_theme_constant_override("v_separation", UiTheme.GAP_SMALL)
	enemy_scroll.add_child(grid)
	var enemies: Array = ["dummy"]
	enemies.append_array(ZombieDefs.ALL.keys())
	for id: String in enemies:
		var chosen := id
		var b := _button(str(ZombieDefs.def_of(id)["name"]), func() -> void:
			world.sandbox_spawn(chosen), Vector2(0, UiTheme.BTN_SHORT))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		grid.add_child(b)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 40)
	box.add_child(lower)
	var you := VBoxContainer.new()
	you.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	you.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	lower.add_child(you)
	_section(you, "You")
	var pl := world.player
	var safe := _toggle("Cannot be hurt", func() -> bool: return pl.guard_left > 100.0, func(on: bool) -> void: pl.guard_left = 9999.0 if on else 0.0)
	you.add_child(safe)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	you.add_child(row)
	for b: Button in [_button("New skill tree", func() -> void: start_game(Game.Mode.SANDBOX), Vector2(0, UiTheme.BTN)), _button("Clear enemies", func() -> void: world.sandbox_clear(), Vector2(0, UiTheme.BTN))]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var place := VBoxContainer.new()
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	lower.add_child(place)
	_section(place, "Weather")
	place.add_child(_choices(["Clear", "Rain", "Storm"], world.weather.kind, 380.0, func(i: int) -> void: world.weather.set_kind(i)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	place.add_child(foot)
	for b: Button in [_button("Change class", func() -> void: show_class_picker(Game.Mode.SANDBOX), Vector2(0, UiTheme.BTN)), _button("Quit to menu", show_menu, Vector2(0, UiTheme.BTN))]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(b)


## The four ways to play together, and what each one needs.
func show_together(tab := -1) -> void:
	if tab >= 0:
		_together_tab = clampi(tab, 0, TOGETHER_TABS.size() - 1)
	_clear_ui()
	_back = show_menu
	var root := _screen("Play Together", show_menu, "Up to four phones, nearby or online.")
	# Who you play as is shown, not changed, here: the name is changed in Settings.
	var right: HBoxContainer = root.get_meta("right")
	var playing := _soft("Playing as", UiTheme.FS_BODY)
	playing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(playing)
	var who := _label(Game.player_name, UiTheme.FS_LEAD, UiTheme.BONE)
	who.name = "PlayingAs"
	who.add_theme_font_override("font", UiTheme.bold_font())
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(who)
	UiScreen.tabs(root.get_meta("box"), TOGETHER_TABS, _together_tab, func(i: int) -> void: show_together(i))
	var page := UiScreen.page(root.get_meta("box"))
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(box)
	# What this way needs on the left; starting a game on the right, the same on every tab.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTheme.GAP)
	box.add_child(top)
	var about := _body(["Everyone on the same Wi-Fi network.", "Over the internet, from almost any network, mobile data included."][_together_tab], UiTheme.FS_LEAD)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(about)
	if _together_tab == ONLINE_TAB:
		if EpicNet.available():
			top.add_child(_button("Start a game", _start_online, Vector2(280, UiTheme.BTN_TALL), true))
	else:
		top.add_child(_button("Start a game", func() -> void:
			var problem := Net.host_game()
			if problem == OK:
				show_lobby()
			else:
				_on_net_left("Could not start a game here (%d)." % problem), Vector2(280, UiTheme.BTN_TALL), true))
	match _together_tab:
		0:
			_nearby_games(box, root)
		ONLINE_TAB:
			_online_tab(box)


func _nearby_games(box: VBoxContainer, root: Control) -> void:
	_section(box, "Games nearby")
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
			rooms.add_child(_body("Looking...", UiTheme.FS_BODY))
		for address: String in Net.rooms:
			var info: Dictionary = Net.rooms[address]
			rooms.add_child(_button("%s's game: %s, %d of %d players" % [info["name"], Net.RULE_NAMES[int(info["rules"])], info["players"], Net.MAX_PLAYERS], func() -> void: _join(address), Vector2(0, UiTheme.BTN)))
	Net.rooms_changed.connect(fill)
	# The screen shows at once; the search (which reaches into the phone's Wi-Fi settings and opens a
	# socket, and can take a moment) starts just after it is on screen.
	var searching := [false]
	root.tree_exiting.connect(func() -> void:
		Net.rooms_changed.disconnect(fill)
		if searching[0]:
			Net.stop_search())
	fill.call()
	# Held weakly: the screen may be gone (another tab) before the timer fires.
	var screen: WeakRef = weakref(root)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		var still := screen.get_ref() as Control
		if still and still.is_inside_tree() and not searching[0]:
			searching[0] = true
			Net.start_search())
	var manual := HBoxContainer.new()
	manual.add_theme_constant_override("separation", 10)
	box.add_child(manual)
	var by := _soft("Join by address", UiTheme.FS_BODY)
	by.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	manual.add_child(by)
	var address_edit := LineEdit.new()
	address_edit.placeholder_text = _example_address()
	address_edit.custom_minimum_size = Vector2(400, UiTheme.BTN)
	# Number keyboards on Android allow a single dot, and an address has three.
	address_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	manual.add_child(address_edit)
	manual.add_child(_button("Join", func() -> void:
		if address_edit.text.strip_edges() != "":
			_join(address_edit.text.strip_edges()), Vector2(140, UiTheme.BTN)))


func _online_tab(box: VBoxContainer) -> void:
	if not EpicNet.available():
		var missing := _body("This build has no online play.", UiTheme.FS_BODY)
		missing.add_theme_color_override("font_color", UiTheme.EMBER)
		box.add_child(missing)
		return
	# Whether the game you start shows in everyone's list, or is found only with its code.
	var kind := HBoxContainer.new()
	kind.add_theme_constant_override("separation", 8)
	box.add_child(kind)
	var new_game := _soft("New game", UiTheme.FS_BODY)
	new_game.custom_minimum_size.x = 150
	new_game.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.add_child(new_game)
	kind.add_child(_choice("Public", func() -> void:
		_start_listed = true
		show_together(ONLINE_TAB), Vector2(150, UiTheme.BTN_SHORT), _start_listed))
	kind.add_child(_choice("Private", func() -> void:
		_start_listed = false
		show_together(ONLINE_TAB), Vector2(150, UiTheme.BTN_SHORT), not _start_listed))
	var says := _soft("Anyone can find it in the list below, or join with its code." if _start_listed else "Only friends with its code can join.", UiTheme.FS_SMALL)
	says.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.add_child(says)
	var join := HBoxContainer.new()
	join.add_theme_constant_override("separation", 10)
	box.add_child(join)
	var code_title := _soft("Room code", UiTheme.FS_BODY)
	code_title.custom_minimum_size.x = 150
	code_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	join.add_child(code_title)
	var code_edit := LineEdit.new()
	code_edit.placeholder_text = "ABC234"
	code_edit.max_length = EpicNet.USER_ID_LENGTH
	code_edit.custom_minimum_size = Vector2(260, UiTheme.BTN)
	join.add_child(code_edit)
	join.add_child(_button("Join", func() -> void:
		if code_edit.text.strip_edges() != "":
			_join_online(code_edit.text), Vector2(140, UiTheme.BTN)))
	_public_games(box)


## Games other people started as public, waiting for players. Looked up again every few seconds.
func _public_games(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section(title, "Public games")
	head.add_child(title)
	head.add_child(_button("Refresh", func() -> void: Net.look_for_rooms(), Vector2(150, UiTheme.BTN_SHORT)))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", UiTheme.GAP_SMALL)
	box.add_child(rows)
	var fill := func() -> void:
		if not is_instance_valid(rows):
			return
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
		if Net.public_rooms.is_empty():
			var empty := "Looking..." if Net.looking_up else ("Could not look: %s" % Net.lookup_problem if Net.lookup_problem != "" else "No public games right now. Start one, or join a friend's with a code.")
			var l := _soft(empty, UiTheme.FS_BODY)
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
	var b := _button("%s's game: %s. %d of %d players" % [room["name"], what, int(room["players"]), Net.MAX_PLAYERS], func() -> void: _join_online(str(room["host"])), Vector2(0, UiTheme.BTN))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _online_wait() -> void:
	_clear_ui()
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 600
	box.add_child(_body("Connecting...", UiTheme.FS_HEAD))


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
	var root := _screen("Game room", _leave_lobby, "", "Leave")
	var box: VBoxContainer = root.get_meta("box")
	var page := UiScreen.page(box)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", UiTheme.GAP)
	page.add_child(inside)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inside.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	# Start and Leave stay in reach below the scrolling part, however long the room gets.
	var foot := HBoxContainer.new()
	foot.name = "LobbyFoot"
	foot.add_theme_constant_override("separation", UiTheme.GAP)
	inside.add_child(foot)
	body.set_meta("foot", foot)
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
	var foot: HBoxContainer = body.get_meta("foot")
	for holder: Node in [body, foot]:
		for c in holder.get_children():
			# This can run from inside one of these buttons' own press.
			holder.remove_child(c)
			c.queue_free()
	if Net.is_client() and not Net.roster.has(Net.my_id()):
		body.add_child(_body("Connecting...", UiTheme.FS_HEAD))
		return
	if Net.is_host():
		if Net.way == Net.Way.ONLINE:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			body.add_child(row)
			var shown := _body("Room code: %s" % Net.room_code, UiTheme.FS_HEAD if Net.room_problem == "" else UiTheme.FS_BODY)
			shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(shown)
			row.add_child(_button("Copy", func() -> void: DisplayServer.clipboard_set(Net.room_code), Vector2(120, UiTheme.BTN_SHORT)))
			row.add_child(_choice("Public", func() -> void: Net.set_listed(true), Vector2(130, UiTheme.BTN_SHORT), Net.room_listed))
			row.add_child(_choice("Private", func() -> void: Net.set_listed(false), Vector2(130, UiTheme.BTN_SHORT), not Net.room_listed))
			if Net.room_problem != "":
				var why := _soft("%s This longer code still works: copy it and send it to your friends." % Net.room_problem, UiTheme.FS_BODY)
				why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(why)
		else:
			var where := Net.local_addresses()
			body.add_child(_body("Your address, if someone needs it: %s" % (where[0] if not where.is_empty() else "no Wi-Fi?"), UiTheme.FS_BODY))
		# Each setting of the night on its own line, its name in a column, its choices beside it.
		var kinds := _setting_row(body, "Game")
		for r in Net.RULE_NAMES.size():
			var pick := r
			kinds.add_child(_choice(Net.RULE_NAMES[r], func() -> void: Net.set_rules(pick), Vector2(210, UiTheme.BTN_SHORT), Net.rules == r))
		var maps := _setting_row(body, "Place")
		if Net.rules == Net.Rules.FORT:
			for id: String in Game.FORT_MAPS:
				var chosen_fort := id
				maps.add_child(_choice(Game.FORT_MAPS[id]["name"], func() -> void: Net.set_fort_map(chosen_fort), Vector2(210, UiTheme.BTN_SHORT), Net.fort_map == id))
		else:
			for id: String in Game.MAPS:
				if Net.pvp() and id not in Game.VERSUS_MAPS:
					continue
				var chosen_map := id
				maps.add_child(_choice(Game.MAPS[id]["name"], func() -> void: Net.set_night_map(chosen_map), Vector2(210, UiTheme.BTN_SHORT), Net.night_map == id))
		var levels := _setting_row(body, "Difficulty")
		for d in 3:
			var level := d
			levels.add_child(_choice(["Easy", "Normal", "Hard"][d], func() -> void: Net.set_difficulty(level), Vector2(150, UiTheme.BTN_SHORT), Net.difficulty == d))
		var bots_row := _setting_row(body, "Bots")
		for n in Net.MAX_PLAYERS - Net.humans() + 1:
			var wanted := n
			bots_row.add_child(_choice(str(n), func() -> void: Net.set_bots(wanted), Vector2(72, UiTheme.BTN_SHORT), Net.bot_count() == n))
	else:
		body.add_child(_body("Game: %s, %s. The host starts when everyone is ready." % [Net.RULE_NAMES[Net.rules], ["Easy", "Normal", "Hard"][Net.difficulty]], UiTheme.FS_BODY))
	if Net.rules == Net.Rules.FFA:
		body.add_child(_soft("Three lives each, and a deadly fog closes in. The last one standing wins.", UiTheme.FS_BODY))
	if not Net.can_start():
		var need := "All vs All needs someone to fight." if Net.rules == Net.Rules.FFA else "Teams needs a player or bot on each side."
		if Net.is_host():
			need += " Wait for a friend or add a bot."
		var why := _soft(need, UiTheme.FS_BODY)
		why.add_theme_color_override("font_color", UiTheme.EMBER)
		body.add_child(why)
	# Who is in the room on the left, the class you play on the right.
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	body.add_child(split)
	var people := VBoxContainer.new()
	people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people.add_theme_constant_override("separation", 6)
	split.add_child(people)
	people.add_child(_soft("In the room", UiTheme.FS_BODY))
	var ids: Array = Net.roster.keys()
	ids.sort()
	for peer: int in ids:
		people.add_child(_lobby_person(peer))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	split.add_child(side)
	side.add_child(_soft("Your class", UiTheme.FS_BODY))
	var classes := GridContainer.new()
	classes.name = "LobbyClasses"
	classes.columns = 4
	classes.add_theme_constant_override("h_separation", 8)
	classes.add_theme_constant_override("v_separation", 8)
	side.add_child(classes)
	var mine := str(Net.roster[Net.my_id()]["class"])
	for id: String in ClassDefs.available():
		var pick := id
		classes.add_child(_class_tile(id, mine == id, Net.class_slot_available(id, Net.my_id()), func() -> void: Net.set_my_class(pick)))
	if Net.rules == Net.Rules.TEAMS:
		foot.add_child(_button("Change team", Net.switch_team, Vector2(240, UiTheme.BTN)))
	foot.add_child(_expand())
	if Net.is_host():
		var go := _button("Start the night", Net.start_match, Vector2(360, UiTheme.BTN_TALL), true)
		go.disabled = not Net.can_start()
		foot.add_child(go)


## One person in the room: the emblem of their class, their name, the class and, in Teams, their side.
func _lobby_person(peer: int) -> PanelContainer:
	var info: Dictionary = Net.roster[peer]
	var cls := str(info["class"])
	var card := PanelContainer.new()
	var me := peer == Net.my_id()
	card.add_theme_stylebox_override("panel", UiTheme.flat(Color(UiTheme.EMBER, 0.12) if me else Color(UiTheme.DUSK, 0.7), Color(UiTheme.EMBER, 0.55) if me else Color.TRANSPARENT, 8, 8.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(IconView.new(ClassDefs.icon(cls), ClassDefs.color(cls), 54.0))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var who := _body(str(info["name"]) + (" (you)" if me else ""), UiTheme.FS_LEAD)
	who.add_theme_font_override("font", UiTheme.bold_font())
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(who)
	var as_class := _soft(str(ClassDefs.ALL[cls]["name"]), UiTheme.FS_SMALL)
	as_class.add_theme_color_override("font_color", ClassDefs.color(cls).lightened(0.35))
	words.add_child(as_class)
	if Net.rules == Net.Rules.TEAMS:
		var team := _body("Team %s" % ("Gold" if int(info["team"]) == 0 else "Blue"), UiTheme.FS_BODY)
		team.add_theme_color_override("font_color", Net.team_colour(int(info["team"])))
		team.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(team)
	return card


## A class to pick in the room: its emblem over its name, lit when it is yours. A class that cannot be
## taken (a second Commander) is faded and says why.
func _class_tile(id: String, chosen: bool, can: bool, action: Callable) -> Button:
	var col := ClassDefs.color(id)
	var b := _button(String(ClassDefs.ALL[id]["name"]).get_slice(" ", 0), action, Vector2(128, 112))
	b.name = "Class_" + id
	b.add_theme_font_size_override("font_size", UiTheme.FS_SMALL)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# The name sits under the emblem: the top of the button is left for it.
	var look := {
		"normal": UiTheme.flat(Color(UiTheme.DUSK, 0.9), UiTheme.STEEL, 10, 8.0),
		"hover": UiTheme.flat(Color(UiTheme.DUSK.lightened(0.08), 0.95), col.lightened(0.2), 10, 8.0),
		"pressed": UiTheme.flat(Color(UiTheme.DUSK.darkened(0.2), 0.95), col, 10, 8.0),
		"disabled": UiTheme.flat(Color(UiTheme.DUSK, 0.45), Color.TRANSPARENT, 10, 8.0),
	}
	if chosen:
		for state: String in ["normal", "hover", "pressed"]:
			look[state] = UiTheme.flat(Color(UiTheme.EMBER, 0.22), UiTheme.EMBER, 10, 8.0, 3)
	for state: String in look:
		var box: StyleBoxFlat = look[state]
		box.content_margin_top = 70.0
		box.content_margin_bottom = 6.0
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", UiTheme.EMBER if chosen else UiTheme.BONE)
	b.add_theme_color_override("font_hover_color", UiTheme.EMBER if chosen else UiTheme.BONE)
	var emblem := IconView.new(ClassDefs.icon(id), col, 58.0)
	emblem.dim = not can
	emblem.position = Vector2(35, 9)
	b.add_child(emblem)
	b.disabled = not can
	b.tooltip_text = "Only one Commander per match" if not can else ""
	return b


func _character_name(pl: Player) -> String:
	if pl.spec_id != "":
		return String(pl.spec_def()["name"])
	return String(pl.class_def()["name"])


## Whatever was open over the night (the Map, Settings, the Pause card) goes when the night ends,
## so the end of it is never shown on top of a screen left open.
func _close_screens() -> void:
	for c in ui_layer.get_children():
		if c != hud and not c.is_queued_for_deletion():
			c.queue_free()
	_pause_root = null


func _end_screen(title: String, line: String) -> void:
	if hud:
		hud.menu_open = true # touches now belong to these buttons, not the character behind them
	_back = show_menu
	_close_screens()
	var root := _modal(title)
	var box: VBoxContainer = root.get_meta("box")
	var l := _body(line, UiTheme.FS_LEAD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	_reward_rows(box)
	box.add_child(_button("Play again", func() -> void: start_game(Game.mode), Vector2(480, UiTheme.BTN_TALL), true))
	box.add_child(_button("Change class", func() -> void: show_class_picker(Game.mode), Vector2(480, UiTheme.BTN_TALL)))
	box.add_child(_button("Menu", show_menu, Vector2(480, UiTheme.BTN_TALL)))


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
	var root := _screen("Artillery target", func() -> void: _back.call(), "Choose a circle: %d m radius. Impact in %d seconds; %d-second barrage, %d-second fires." % [int(CommanderKit.BARRAGE_RADIUS), int(CommanderKit.BARRAGE_DELAY), int(CommanderKit.BARRAGE_TIME), int(CommanderKit.FIRE_TIME)], "Cancel")
	var close := func() -> void:
		root.queue_free()
		if hud:
			hud.menu_open = false
		_back = show_pause
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var map := _square_map(root.get_meta("box"))
	map.targeting = true
	map.world = world
	map.selected_spot = world.player.global_position
	var confirm := _button("Call barrage", func() -> void:
		if world == null or world.player.dead:
			close.call()
			return
		world.player.command_target = map.selected_spot
		world.player.command_target_ready = true
		close.call()
		world.player.use_art(), Vector2(260, UiTheme.BTN), true)
	confirm.disabled = true
	map.selected.connect(func(_at: Vector3) -> void: confirm.disabled = false)
	(root.get_meta("right") as Control).add_child(confirm)
	_back = close


# --- Your name and the leaderboard -------------------------------------------

## The game itself asks for a name. Tests and capture scenes that host this menu ask for one only
## when they mean to.
func _asks_for_name() -> bool:
	var scene := get_tree().current_scene
	return scene == null or scene == self


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
	var about := _soft(line, UiTheme.FS_BODY)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	var edit := LineEdit.new()
	edit.text = Game.player_name if Board.name_state != Board.NameState.TAKEN else ""
	edit.placeholder_text = "3 to 16 letters"
	edit.max_length = Board.NAME_MAX
	edit.custom_minimum_size = Vector2(640, 64)
	edit.add_theme_font_size_override("font_size", UiTheme.FS_HEAD)
	edit.select_all_on_focus = true
	box.add_child(edit)
	var problem := _body("", UiTheme.FS_BODY)
	problem.add_theme_color_override("font_color", UiTheme.EMBER)
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(problem)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var save := _button("Save", func() -> void: pass, Vector2(0, UiTheme.BTN), true)
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
		row.add_child(_button("Cancel", close, Vector2(180, UiTheme.BTN)))
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
	var points := Board.record_match(seconds, kills, won, mode, map, world.player.class_id, world.player.spec_id, difficulty)
	_rewards.append({"points": true, "text": "+%d leaderboard points" % points})
	return ""


var _rewards: Array[Dictionary] = [] # what the match earned, for the end screen
var _prizes_checked := -1e9


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
		var l := _body("You finished %s in the week of %d %s. +%d doubloons." % [place, start["day"], ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][int(start["month"]) - 1], int(reward.get("doubloons", 0))], UiTheme.FS_LEAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		box.add_child(l)
	var close := func() -> void:
		root.queue_free()
		show_menu()
	box.add_child(_button("Close", close, Vector2(480, UiTheme.BTN_TALL), true))


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
	var root := _screen("Leaderboard", show_menu, "Points from every finished night, the best of each player.")
	var box: VBoxContainer = root.get_meta("box")
	var periods := [["all", "All time"], ["week", "This week"], ["mine", "Your matches"]]
	UiScreen.tabs(box, periods.map(func(t: Array) -> String: return t[1]), periods.map(func(t: Array) -> String: return t[0]).find(_board_period), func(i: int) -> void: show_leaderboard(periods[i][0]))
	# Which matches count: every one, or one kind. Chosen in the same way, a row below.
	if _board_period != "mine":
		var ids: Array = Board.BOARDS.keys()
		var kinds := UiScreen.tabs(box, ids.map(func(id: String) -> String: return Board.BOARDS[id]), ids.find(_board_kind), func(i: int) -> void: show_leaderboard("", ids[i]))
		kinds.name = "BoardKinds"
	var note := _soft("", UiTheme.FS_SMALL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var page := UiScreen.page(box)
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
	var mine := _body("", UiTheme.FS_BODY)
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inside.add_child(mine)
	(root.get_meta("right") as Control).add_child(_button("Refresh", func() -> void: _fill_leaderboard(list, note, mine, true), Vector2(150, UiTheme.BTN)))
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
		list.add_child(_soft("This version of the game has no leaderboard.", UiTheme.FS_BODY))
		return
	var asking := _soft("Asking the leaderboard…", UiTheme.FS_BODY)
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
			list.add_child(_soft("No matches yet. Finish a match outside the Sandbox and it shows here.", UiTheme.FS_BODY))
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
			list.add_child(_soft("No one has scored here yet%s. Finish a match to be the first." % (" this week" if period == "week" else ""), UiTheme.FS_BODY))
		for e: Dictionary in entries:
			var me_row := str(e.get("name", "")) == Game.player_name and Board.registered != ""
			var rank := int(e.get("rank", 0))
			var col: Color = [UiTheme.EMBER, Color(0.66, 0.76, 0.92), Color(0.8, 0.55, 0.35)][rank - 1] if rank >= 1 and rank <= 3 else UiTheme.BONE
			var row := _board_row(str(rank), str(e.get("name", "")), str(int(e.get("points", 0))), Board.class_label(str(e.get("class", "")), str(e.get("spec", ""))), col, false)
			_board_badge(row, str(e.get("class", "")), str(e.get("spec", "")))
			if me_row:
				var mark := UiTheme.flat(Color(UiTheme.EMBER, 0.18), Color(UiTheme.EMBER, 0.6), 6, 4.0)
				row.add_theme_stylebox_override("panel", mark)
			list.add_child(row)
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
	var l := _soft(why, UiTheme.FS_BODY)
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
	var size := UiTheme.FS_SMALL if header else UiTheme.FS_BODY
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


## The emblem of what a player plays most, in front of its name: the profession's when there is
## one, else the class's.
func _board_badge(row: PanelContainer, cls: String, spec: String) -> void:
	if not ClassDefs.ALL.has(cls):
		return
	var line: HBoxContainer = row.get_child(0)
	var icon := ClassDefs.icon(cls)
	if spec != "" and Icons.exists("spec_" + spec):
		icon = "spec_" + spec
	var badge := IconView.new(icon, ClassDefs.color(cls), 38.0)
	badge.name = "Played"
	line.add_child(badge)
	line.move_child(badge, line.get_child_count() - 2)


func _board_row(rank: String, who: String, points: String, played: String, col: Color, header: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.flat(Color(0, 0, 0, 0), Color.TRANSPARENT, 6, 4.0))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)
	var size := UiTheme.FS_SMALL if header else UiTheme.FS_LEAD
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
