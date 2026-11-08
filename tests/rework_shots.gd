extends Node
## Render the name migration, Commander equipment, Adept phase card and artillery selection.
var out := ""
var m: Main

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	seed(771)
	Game.player_name = ""
	Game.name_schema = 0
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.unlocked["commander"] = true
	Game.unlocked["adept"] = true
	m = Main.new()
	add_child(m)
	await wait(0.4)
	await snap("choose_name")
	Game.confirm_name("Mara")
	m.show_menu()
	await snap("menu_leaderboard")
	Scores.cached = [{"id": "fixture-a", "name": "Mara", "points": 625, "favourite": "commander|vanguard"}, {"id": "fixture-b", "name": "Mara", "points": 320, "favourite": "plague_doctor|pestilence"}]
	Scores._cache_time = Time.get_ticks_msec()
	m.show_leaderboard()
	await snap("leaderboard")
	m.show_class_picker(Game.Mode.NIGHT)
	m._fill_class_detail(m.panel.get_meta("detail"), "commander", Game.Mode.NIGHT)
	# Use the normal picker buttons so the stage remains inside its viewport.
	for button: Node in m.ui_layer.find_children("*", "Button", true, false):
		if button.tooltip_text == "Commander":
			button.pressed.emit()
	await snap("commander_picker")
	Game.player_class = "adept"
	await m.start_game(Game.Mode.NIGHT)
	m.world.director.running = false
	await wait(0.3)
	await snap("adept_wind")
	m.world.player.use_art()
	await wait(0.4)
	await snap("adept_stone")
	m.world.player.art_cd_left = 0.0
	m.world.player.use_art()
	await wait(0.4)
	await snap("adept_flame")
	for spec in 3:
		Game.player_class = "commander"
		await m.start_game(Game.Mode.NIGHT)
		m.world.director.running = false
		m.world.player.grant_all_points()
		for step in 9:
			m.world.player.choose_ability(step, spec if step == 3 else 0)
		await wait(0.3)
		await snap(["commander_warlock", "commander_gunner", "commander_vanguard"][spec])
		if spec == 1:
			m.world.player.use_art()
			await snap("artillery_map")
	await preload("res://tests/scene_cleanup.gd").finish(m)
