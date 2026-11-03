extends Node
## Screenshots and quick checks of the Artificer's three paths and the Sandbox.
## Args after --: output folder.

var out := ""
var m: Main
var w: World
var pl: Player


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])


func _start(cls: String, mode: int) -> void:
	Game.player_class = cls
	Game.unlocked["artificer"] = true
	Game.unlocked["revenant"] = true
	await m.start_game(mode)
	await wait(0.3)
	w = m.world
	pl = w.player


func _take_path(spec: int) -> void:
	pl.points = ClassDefs.MAX_LEVEL - 1
	for s in Player.CORE_STEPS:
		pl.choose_ability(s, 0)
	pl.choose_ability(Player.CORE_STEPS, spec)


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(1.0)
	await _start("artificer", Game.Mode.SANDBOX)
	await snap("sandbox_start")
	pl.global_position = Vector3(-12, 0.05, -16)
	pl.yaw = 0.6
	pl.rotation.y = 0.6
	await wait(0.4)
	await snap("sandbox_weapons")
	pl.global_position = Vector3(-24, 0.05, -4)
	pl.yaw = PI * 0.5
	pl.rotation.y = PI * 0.5
	await wait(0.4)
	await snap("sandbox_items")
	m.show_sandbox_menu()
	await wait(0.2)
	await snap("sandbox_menu")
	m._resume()
	# The Pyromaniac.
	pl.global_position = Vector3(0, 0.05, 10)
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	_take_path(0)
	for id: String in ["normal", "normal", "clever"]:
		w.sandbox_spawn(id)
	await wait(0.2)
	pl.use_art()
	await wait(0.45)
	await snap("bomb_thrown")
	await wait(0.65)
	await snap("bomb_burst")
	await wait(0.3)
	await snap("bomb_fire")
	pl.flags["chaotic"] = true
	pl.art_cd_left = 0.0
	pl.use_art()
	await wait(1.25)
	await snap("chaotic")
	await wait(2.0)
	# The Mechanic.
	await _start("artificer", Game.Mode.SANDBOX)
	_take_path(1)
	pl.flags["chariot_turret"] = true
	pl.flags["chariot_spikes"] = true
	pl.horse_progress = pl.horses_needed()
	pl.mount()
	await wait(0.6)
	await snap("chariot_view")
	pl.pitch = -0.55
	pl.head.rotation.x = -0.55
	await wait(0.2)
	await snap("chariot_down")
	var model := ChariotModel.new()
	w.add_child(model)
	model.global_position = pl.global_position + Vector3(0, 0, -6)
	model.rotation.y = 2.4
	model.show_upgrades(true, true)
	pl.pitch = -0.2
	pl.head.rotation.x = -0.2
	await wait(0.2)
	await snap("chariot_model")
	# The Inventor.
	await _start("artificer", Game.Mode.SANDBOX)
	_take_path(2)
	pl.global_position = Vector3(0, 0.05, 10)
	await wait(0.3)
	await snap("inventor_button")
	for id: String in ["normal", "normal", "clever", "normal"]:
		w.sandbox_spawn(id)
	await wait(0.2)
	pl._next_invention = "volley"
	pl.use_art()
	await wait(0.6)
	await snap("volley")
	pl.art_cd_left = 0.0
	pl._run_invention("sentry")
	await wait(1.2)
	await snap("sentry")
	pl._run_invention("flask")
	await wait(1.0)
	await snap("flask")
	get_tree().quit()
