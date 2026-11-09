extends Node
## Pictures of rain and a lightning strike. Args: output folder.
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
	Game.player_class = "ranger"
	Game.force_weather = 1
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(0.5)
	await m.start_game(Game.Mode.NIGHT)
	await wait(0.8)
	var w: World = m.world
	var pl: Player = w.player
	w.director.running = false
	for z: Zombie in w.zombies.duplicate():
		z.release()
	pl.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 8)) + 0.05, 8)
	await wait(1.0)
	await snap("rain")
	pl.global_position = Vector3(-16, w.ground_at(Vector3(-16, 0, -13.5)) + 0.05, -13.5)
	await wait(1.0)
	await snap("rain_indoors")
	pl.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 8)) + 0.05, 8)
	w.weather.set_kind(Weather.Kind.STORM)
	w.weather._next_strike = 999.0
	w.weather._next_sheet = 999.0
	await wait(0.4)
	w.weather.announce(pl.global_position - pl.global_basis.z * 9.0)
	await wait(0.8)
	await snap("storm_warning")
	await wait(0.34)
	await snap("storm_strike")
	w.weather.set_kind(Weather.Kind.CLEAR)
	Game.force_weather = -1
	# The fog of All vs All: far off, close by, and from outside.
	w.fog = ClosingFog.new(w, Vector2.ZERO)
	w.add_child(w.fog)
	var at := Vector3(0, 0, 36)
	at.y = w.ground_at(at) + 0.05
	pl.global_position = at
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	pl.guard_left = 999.0
	# Looking north, the wall is behind the village. Looking south, it is close.
	w.director.elapsed = 170.0
	await wait(1.2)
	await snap("fog_far")
	pl.yaw = PI
	pl.rotation.y = PI
	await wait(0.3)
	await snap("fog_far_south")
	w.director.elapsed = 275.0
	await wait(1.2)
	await snap("fog_near")
	w.director.elapsed = 330.0
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	await wait(1.5)
	await snap("fog_outside")
	await preload("res://tests/scene_cleanup.gd").finish(m)
