extends Node
## Pictures of the screens the other screenshot runs miss. Args: output folder.
var out := ""


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	Game.player_name = "Test Player"
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.player_class = "artificer"
	Game.unlocked["artificer"] = true
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(1.0)
	await snap("mists_title")
	m.show_together()
	await wait(0.2)
	await snap("together")
	m.show_together(1)
	await wait(0.2)
	await snap("hotspot")
	m.show_together(Main.ONLINE_TAB)
	await wait(0.2)
	await snap("online")
	m.show_together()
	await wait(0.1)
	Net.host_game()
	m.show_lobby()
	await wait(0.3)
	await snap("lobby")
	Net.set_rules(Net.Rules.FFA)
	await wait(0.2)
	await snap("lobby_alone")
	Net.set_bots(2)
	await wait(0.2)
	await snap("lobby_bots")
	Net.leave()
	await wait(0.2)
	Game.doubloons = 800
	m.show_store("revenant")
	await wait(0.2)
	await snap("store_can_buy")
	Game.doubloons = 900
	m.show_store("bandit")
	await wait(0.2)
	await snap("store_bandit")
	m.show_store("adept")
	await wait(0.2)
	await snap("store_adept")
	Game.unlocked["bandit"] = true
	m.show_class_picker(Game.Mode.SANDBOX)
	await wait(0.2)
	await snap("classes_sandbox")
	var loading := m._loading_screen()
	await wait(0.1)
	await snap("loading")
	loading.queue_free()
	# The world atlas, choosing where to spend the night and where to hold the fort.
	m.show_map_picker()
	await wait(0.4)
	await snap("atlas_night")
	m.show_fort_picker()
	await wait(0.2)
	(m.panel.find_child("Place_bastion", true, false) as Button).pressed.emit()
	await wait(0.4)
	await snap("atlas_fort")
	m.show_menu()
	await wait(0.2)
	# The loading screen of every place.
	var mode_before := Game.mode
	var night_before := Game.night_map
	var fort_before := Game.fort_map
	for where: Array in [[Game.Mode.NIGHT, "village"], [Game.Mode.FORT, "fort"], [Game.Mode.NIGHT, "mists"], [Game.Mode.NIGHT, "mesenlla"], [Game.Mode.FORT, "bastion"]]:
		Game.mode = where[0]
		if where[0] == Game.Mode.FORT:
			Game.fort_map = where[1]
		else:
			Game.night_map = where[1]
		var screen := m._loading_screen()
		await wait(0.3)
		await snap("loading_%s" % where[1])
		screen.queue_free()
	Game.mode = mode_before
	Game.night_map = night_before
	Game.fort_map = fort_before
	await m.start_game(Game.Mode.NIGHT)
	await wait(1.0)
	await snap("night")
	m.show_pause()
	await wait(0.2)
	await snap("pause")
	m.show_settings(true)
	await wait(0.2)
	await snap("settings_pause")
	m.show_pause()
	await wait(0.1)
	m.show_map()
	await wait(0.2)
	await snap("map")
	m._resume()
	await wait(0.2)
	m._end_screen("You fell", "You lasted 6:12 and took down 84. +23 doubloons.")
	await wait(0.2)
	await snap("end")
	await m.start_game(Game.Mode.SANDBOX)
	await wait(1.0)
	await snap("sandbox")
	m.show_sandbox_menu()
	await wait(0.2)
	await snap("sandbox_menu")
	await preload("res://tests/scene_cleanup.gd").finish(m)
