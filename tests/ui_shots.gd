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
	Game.confirm_name("Test Player")
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.player_class = "artificer"
	Game.unlocked["artificer"] = true
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(1.0)
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
	m.show_class_picker(Game.Mode.SANDBOX)
	await wait(0.2)
	await snap("classes_sandbox")
	var loading := m._loading_screen()
	await wait(0.1)
	await snap("loading")
	loading.queue_free()
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
