class_name Main
extends Node
## Top-level flow: menu, game, pause, game over.

var world: World
var hud: Hud
var ui_layer: CanvasLayer
var panel: Control
var _theme: Theme
var tree_panel: TreePanel
var _run_over := false
var _back := Callable() # what the phone's back button does on the current screen
var _pause_root: Control
var _net_go := false

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
	"The bell rings every minute and draws zombies to the church.",
	"Beasts track by scent. Hiding only delays them.",
	"A chime means a familiar has appeared close by. Look for its light.",
	"In the last two minutes, everything comes for you. Save your strength.",
	"Out of arrows or mana? You can still hit with what you hold.",
	"The river can only be crossed on the bridges and at the ford.",
	"The castle has one road up, and several holes in its walls.",
	"Corn hides you better than anything. It also hides them.",
	"Firelight warms you, and everything out there can see you in it.",
	"A crow calls out before it dives. Step aside, then hit it while it hangs low.",
	"In the fort, carry wood close to a damaged gate and it mends as you stand there.",
	"Only you fit through the fort's small doors. Enemies have to break a gate.",
	"Drop off the fort's walls when you need to get out fast. It does not hurt.",
	"A Dread Rider is open to a blow while it turns.",
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
	# Coming back from another menu screen, the village behind it can simply stay.
	if rebuild or world == null or world.mode != Game.Mode.MENU:
		_new_world(Game.Mode.MENU)
	Sfx.ambient(true)
	Sfx.set_mood(0.0, 0.0)
	var root := Control.new()
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	root.add_child(_vignette())
	_fill(root.get_child(0))
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	root.add_child(margin)
	_fill(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := _label("UNDEAD DROP", 86, UiTheme.GOLD)
	title.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(title)
	box.add_child(_label("Grab what you find. Hide. Reach dawn.", 28, UiTheme.PALE))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	box.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var survive := _button("Survive the Night", func() -> void: show_class_picker(Game.Mode.NIGHT), Vector2(360, 80), true)
	row.add_child(survive)
	row.add_child(_button("Defend the Fort", func() -> void: show_class_picker(Game.Mode.FORT), Vector2(340, 80), true))
	row.add_child(_button("Play Together", show_together, Vector2(300, 80), true))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	box.add_child(row2)
	row2.add_child(_button("Roam", func() -> void: show_class_picker(Game.Mode.ROAM), Vector2(150, 68)))
	row2.add_child(_button("Codex", show_codex, Vector2(150, 68)))
	row2.add_child(_button("Settings", show_settings, Vector2(170, 68)))
	var store := _button("Store: coming soon", func() -> void: pass, Vector2(310, 68))
	store.disabled = true
	row2.add_child(store)
	row2.add_child(IconView.new("coin", UiTheme.GOLD, 56.0))
	row2.add_child(_label("%d Botti Doubloons" % Game.doubloons, 26, UiTheme.GOLD))
	var best := "No nights yet"
	if Game.best_time > 0.0:
		best = "Best: %s survived, %d kills. Nights survived: %d" % [Game.clock(Game.best_time), Game.best_kills, Game.nights_survived]
	box.add_child(_label(best, 24, UiTheme.PALE))
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer2)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var hint := _label("Left thumb moves: push it halfway to walk quietly. Right thumb aims.", 22, Color(UiTheme.PALE, 0.85))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	foot.add_child(_label("v%s" % ProjectSettings.get_setting("application/config/version"), 20, Color(UiTheme.PALE, 0.6)))
	panel = root


func _vignette() -> TextureRect:
	var v := TextureRect.new()
	v.texture = load("res://assets/ui/vignette.png")
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func show_settings(from_pause := false) -> void:
	var root := _modal("Settings")
	var box: VBoxContainer = root.get_meta("box")
	var close := func() -> void:
		root.queue_free()
		_back = _resume if from_pause else _quit
	_back = close
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 360
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_slider(left, "Look sensitivity", 0.4, 2.5, Game.sensitivity, func(v: float) -> void: Game.sensitivity = v)
	_slider(left, "Music", 0.0, 1.0, Game.music_volume, func(v: float) -> void:
		Game.music_volume = v
		Sfx.apply_volumes())
	_slider(left, "Sounds", 0.0, 1.0, Game.sound_volume, func(v: float) -> void:
		Game.sound_volume = v
		Sfx.apply_volumes())
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 360
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(_toggle("Auto-jump", func() -> bool: return Game.auto_jump, func(on: bool) -> void: Game.auto_jump = on))
	right.add_child(_toggle("Vibration", func() -> bool: return Game.vibration, func(on: bool) -> void: Game.vibration = on))
	if not from_pause:
		# Both of these only apply to a new night, so they stay out of a running game.
		right.add_child(_ink("Difficulty", 24))
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 8)
		right.add_child(levels)
		var level_names := ["Easy", "Normal", "Hard"]
		for i in 3:
			var d := i
			levels.add_child(_button(level_names[i], func() -> void:
				Game.difficulty = d
				Game.save_settings()
				root.queue_free()
				show_settings(), Vector2(114, 56), Game.difficulty == i))
		right.add_child(_ink("Graphics", 24))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		right.add_child(row)
		var names := ["Low", "Medium", "High"]
		for i in 3:
			var q := i
			row.add_child(_button(names[i], func() -> void:
				Game.quality = q
				Game.apply_quality()
				Game.save_settings()
				show_menu(true), Vector2(114, 56), Game.quality == i))
	if not from_pause:
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", 8)
		box.add_child(code_row)
		var code := LineEdit.new()
		code.placeholder_text = "Redeem a code"
		code.custom_minimum_size = Vector2(380, 56)
		code.add_theme_font_size_override("font_size", 24)
		code_row.add_child(code)
		var answer := _ink("", 22)
		answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		code_row.add_child(_button("Redeem", func() -> void:
			var opened := Game.redeem(code.text)
			if opened != "":
				answer.text = "%s unlocked!" % ClassDefs.ALL[opened]["name"]
				code.text = ""
				Sfx.play("level", -3.0)
			elif code.text.strip_edges() != "":
				answer.text = "That code does not work.", Vector2(150, 56)))
		code_row.add_child(answer)
	box.add_child(_button("Back", close, Vector2(750, 64)))


func _slider(box: VBoxContainer, title: String, low: float, high: float, value: float, changed: Callable) -> void:
	box.add_child(_ink(title, 24))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(340, 46)
	slider.value_changed.connect(func(v: float) -> void:
		changed.call(v)
		Game.save_settings())
	box.add_child(slider)


func _toggle(title: String, read: Callable, write: Callable) -> Button:
	var b := _button("", func() -> void: pass, Vector2(360, 62))
	var show := func() -> void: b.text = "%s: %s" % [title, "On" if read.call() else "Off"]
	show.call()
	b.pressed.connect(func() -> void:
		write.call(not read.call())
		Game.save_settings()
		show.call())
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


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	return l


## Dark ink text for parchment.
func _ink(text: String, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", UiTheme.INK)
	return l


func _button(text: String, action: Callable, min_size: Vector2, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 28)
	if primary:
		UiTheme.wax(b)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -3.0))
	b.pressed.connect(action)
	return b


func show_class_picker(mode: int) -> void:
	_clear_ui()
	_back = show_menu
	var root := Control.new()
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var shade := _vignette()
	root.add_child(shade)
	_fill(shade)
	var margin := MarginContainer.new()
	root.add_child(margin)
	_fill(margin)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var head := _label("Choose your class", 46, UiTheme.GOLD)
	head.add_theme_font_override("font", UiTheme.title_font())
	box.add_child(head)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for id: String in ClassDefs.available():
		row.add_child(_class_card(id, mode))
	var back := _button("Back", show_menu, Vector2(220, 54))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(back)
	panel = root


func _class_card(id: String, mode: int) -> Button:
	var c: Dictionary = ClassDefs.ALL[id]
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 100.0
	for state in ["normal", "hover", "pressed"]:
		card.add_theme_stylebox_override(state, UiTheme.box("panel", 26, 14))
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	var medal := IconView.new(ClassDefs.icon(id), ClassDefs.color(id), 86.0)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(medal)
	var name_label := _ink(c["name"], 25)
	name_label.add_theme_font_override("font", UiTheme.title_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)
	var desc := _ink(c["desc"], 21)
	desc.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc)
	var stats := _ink("Health %d, speed %d%%" % [int(c["hp"]), int(round(float(c["speed"]) * 100.0))], 20)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(stats)
	var specs := PackedStringArray()
	for spec: Dictionary in AbilityData.tree(id)["specs"]:
		specs.append(spec["name"])
	var path_label := _ink(", ".join(specs), 19)
	path_label.add_theme_color_override("font_color", Color(0.46, 0.16, 0.08))
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(path_label)
	var chosen_id := id
	card.pressed.connect(func() -> void:
		Sfx.play("ui_choose", -3.0)
		Game.player_class = chosen_id
		Game.save_settings()
		start_game(mode))
	return card


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


func close_tree() -> void:
	if tree_panel:
		tree_panel.queue_free()
		tree_panel = null
	if hud:
		hud.menu_open = false
		_back = show_pause


func start_game(mode: int) -> void:
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
	hud.director = world.director
	hud.visible = false
	ui_layer.add_child(hud)
	_fill(hud)
	hud.pause_requested.connect(show_pause)
	hud.tree_requested.connect(toggle_tree)
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
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _loading_screen() -> Control:
	var root := Control.new()
	root.theme = _theme
	ui_layer.add_child(root)
	_fill(root)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.04, 0.06)
	root.add_child(bg)
	_fill(bg)
	var center := CenterContainer.new()
	root.add_child(center)
	_fill(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var medal := IconView.new(ClassDefs.icon(Game.player_class), ClassDefs.color(Game.player_class), 110.0)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(medal)
	var title := _label("Preparing the night...", 52, UiTheme.GOLD)
	title.add_theme_font_override("font", UiTheme.title_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tip := _label(TIPS[randi() % TIPS.size()], 26, UiTheme.PALE)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	return root


func _modal(title: String) -> Control:
	var root := Control.new()
	root.theme = _theme
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(root)
	_fill(root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.55)
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
	var head := _ink(title, 52)
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
	var current := world
	await get_tree().create_timer(1.2).timeout
	if world != current or not is_inside_tree():
		return
	var pl := world.player
	var cause := "Slain by %s." % pl.hit_by if pl.hit_by != "" else "You fell."
	if pl.hit_by == "flames":
		cause = "Burned alive."
	_end_screen("You fell", "%s\nSurvived %s as %s: %d kills, level %d.%s" % [cause, Game.clock(seconds), _character_name(pl), kills, pl.level, (" New best!" if is_best else "") + _earned_line(earned)])


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
	close_tree()
	if hud:
		hud.release_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var kills := world.player.kills
	Game.record_run(Game.NIGHT_LENGTH, kills, true)
	var earned := Game.award_doubloons(Game.NIGHT_LENGTH, kills, true, false)
	var current := world
	var line := "%s survived the night: %d kills, level %d.%s" % [_character_name(world.player), kills, world.player.level, _earned_line(earned)]
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
	_end_screen("The heart has fallen", "The fort held for %s, and you took %d with you.%s" % [Game.clock(seconds), kills, _earned_line(earned)])


func _earned_line(earned: int) -> String:
	return "\n+%d Botti Doubloons" % earned if earned > 0 else ""


func _on_net_over(title: String, line: String, reached_dawn: bool) -> void:
	if _run_over or world == null:
		return
	_run_over = true
	line += _earned_line(Game.award_doubloons(world.director.elapsed, world.player.kills, reached_dawn, not Net.pvp()))
	close_tree()
	if hud:
		hud.release_all()
		hud.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_back = show_menu
	var root := _modal(title)
	var box: VBoxContainer = root.get_meta("box")
	var l := _ink(line, 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(_button("Menu", show_menu, Vector2(480, 72), true))


func _on_net_left(reason: String) -> void:
	# Whoever is already reading the results can finish reading them.
	if _run_over and hud:
		return
	if hud or panel:
		show_menu()
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	var l := _ink(reason, 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(_button("OK", func() -> void: root.queue_free(), Vector2(480, 72), true))


# --- Play together -----------------------------------------------------------

## Finding a game on the same Wi-Fi, or starting one.
func show_together() -> void:
	_clear_ui()
	_back = show_menu
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 860
	box.add_child(_ink("On the same Wi-Fi, or with no Wi-Fi at all through one phone's hotspot.", 24))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(_ink("Your name", 26))
	var name_edit := LineEdit.new()
	name_edit.text = Game.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(290, 58)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.text_changed.connect(func(t: String) -> void:
		Game.player_name = t.strip_edges() if t.strip_edges() != "" else Game.player_name
		Game.save_settings())
	top.add_child(name_edit)
	top.add_child(_button("Start a game", func() -> void:
		if Net.host_game() == OK:
			show_lobby()
		else:
			_on_net_left("Could not start a game here."), Vector2(300, 66), true))
	box.add_child(_ink("Games nearby", 26))
	var rooms := VBoxContainer.new()
	rooms.custom_minimum_size.y = 150
	rooms.add_theme_constant_override("separation", 6)
	box.add_child(rooms)
	var fill := func() -> void:
		if not is_instance_valid(rooms):
			return
		for c in rooms.get_children():
			c.queue_free()
		if Net.rooms.is_empty():
			rooms.add_child(_ink("Looking...", 24))
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
	manual.add_child(_ink("Or its address", 24))
	var address_edit := LineEdit.new()
	address_edit.placeholder_text = "192.168.1.20"
	address_edit.custom_minimum_size = Vector2(290, 58)
	address_edit.add_theme_font_size_override("font_size", 26)
	address_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	manual.add_child(address_edit)
	manual.add_child(_button("Join", func() -> void:
		if address_edit.text.strip_edges() != "":
			_join(address_edit.text.strip_edges()), Vector2(160, 60)))
	manual.add_child(_button("Hotspot?", show_hotspot_help, Vector2(170, 60)))
	manual.add_child(_button("Back", show_menu, Vector2(130, 60)))


func show_hotspot_help() -> void:
	var root := _modal("No Wi-Fi? Use a hotspot")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 860
	var close := func() -> void:
		root.queue_free()
		_back = show_menu
	_back = close
	for line: String in ["1. On one phone, turn on the Wi-Fi hotspot in its settings.",
			"2. On the other phones, connect to that hotspot's Wi-Fi. If a phone warns there is no internet, choose to stay connected.",
			"3. On the hotspot phone, press Start a game. The others will find it in the list.",
			"The game itself uses no mobile data, but other apps on the phones might, so you can turn data off."]:
		var l := _ink(line, 25)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	box.add_child(_button("Got it", close, Vector2(860, 64), true))


func _join(address: String) -> void:
	if Net.join_game(address) == OK:
		show_lobby()
	else:
		_on_net_left("That address does not look right.")


## Who is here, and what the game will be.
func show_lobby() -> void:
	_clear_ui()
	_back = show_menu
	var root := _modal("Play Together")
	var box: VBoxContainer = root.get_meta("box")
	box.custom_minimum_size.x = 900
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	var refresh := func() -> void: _fill_lobby(body)
	Net.lobby_changed.connect(refresh)
	root.tree_exiting.connect(func() -> void: Net.lobby_changed.disconnect(refresh))
	refresh.call()


func _fill_lobby(body: VBoxContainer) -> void:
	if not is_instance_valid(body):
		return
	for c in body.get_children():
		# This can run from inside one of these buttons' own press.
		body.remove_child(c)
		c.queue_free()
	if Net.is_client() and not Net.roster.has(Net.my_id()):
		body.add_child(_ink("Connecting...", 28))
		body.add_child(_button("Back", show_menu, Vector2(240, 60)))
		return
	if Net.is_host():
		var where := Net.local_addresses()
		body.add_child(_ink("Your address, if someone needs it: %s" % (where[0] if not where.is_empty() else "no Wi-Fi?"), 24))
		var kinds := HBoxContainer.new()
		kinds.add_theme_constant_override("separation", 8)
		body.add_child(kinds)
		for r in Net.RULE_NAMES.size():
			var pick := r
			kinds.add_child(_button(Net.RULE_NAMES[r], func() -> void: Net.set_rules(pick), Vector2(215, 58), Net.rules == r))
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 8)
		body.add_child(levels)
		levels.add_child(_ink("Difficulty", 24))
		for d in 3:
			var level := d
			levels.add_child(_button(["Easy", "Normal", "Hard"][d], func() -> void: Net.set_difficulty(level), Vector2(150, 52), Net.difficulty == d))
	else:
		body.add_child(_ink("Game: %s, %s. The host starts when everyone is ready." % [Net.RULE_NAMES[Net.rules], ["Easy", "Normal", "Hard"][Net.difficulty]], 24))
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
		var l := _ink(who, 26)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if Net.rules == Net.Rules.TEAMS:
			var team := _ink("Team %s" % ("Gold" if int(info["team"]) == 0 else "Blue"), 26)
			team.add_theme_color_override("font_color", Net.team_colour(int(info["team"])).darkened(0.35))
			row.add_child(team)
	var classes := HBoxContainer.new()
	classes.add_theme_constant_override("separation", 6)
	body.add_child(classes)
	var offered := ClassDefs.available()
	for id: String in offered:
		var pick := id
		var mine := str(Net.roster[Net.my_id()]["class"]) == id
		var b := _button(String(ClassDefs.ALL[id]["name"]).get_slice(" ", 0), func() -> void: Net.set_my_class(pick), Vector2(850.0 / offered.size(), 56), mine)
		b.add_theme_font_size_override("font_size", 22)
		classes.add_child(b)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	body.add_child(foot)
	if Net.rules == Net.Rules.TEAMS:
		foot.add_child(_button("Change team", Net.switch_team, Vector2(240, 66)))
	if Net.is_host():
		foot.add_child(_button("Start the night", Net.start_match, Vector2(360, 66), true))
	foot.add_child(_button("Leave", show_menu, Vector2(180, 66)))


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
	var l := _ink(line, 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	box.add_child(_button("Play again", func() -> void: start_game(Game.mode), Vector2(480, 72), true))
	box.add_child(_button("Change class", func() -> void: show_class_picker(Game.mode), Vector2(480, 72)))
	box.add_child(_button("Menu", show_menu, Vector2(480, 72)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if hud and hud.visible and not get_tree().paused and not _run_over:
			show_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _back.is_valid():
		_back.call()
