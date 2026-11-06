extends Node3D
## The Mists from places a player can stand, and from above.
##     godot --path . res://tests/mists_shots.tscn -- OUT


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.force_weather = Weather.Kind.CLEAR
	Game.night_map = "mists"
	Game.mode = Game.Mode.NIGHT
	var t0 := Time.get_ticks_msec()
	var w := World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	print("BUILD ms ", Time.get_ticks_msec() - t0)
	w.director.running = false
	w.player.set_physics_process(false)
	w.player.set_process(false)
	var cam: Camera3D = w.player.camera
	cam.current = true
	cam.fov = 70.0
	var views := [
		["arena_floor", Vector3(0, 12, 26), Vector3(0, 16, 0)],
		["arena_rim", Vector3(-30, 21, 50), Vector3(0, 12, 0)],
		["rim_north", Vector3(0, 20.5, -56), Vector3(0, 44, -122)],
		["rope_west", Vector3(-54, 20, 4), Vector3(-124, 18, 8)],
		["stone_east", Vector3(56, 20, -2), Vector3(122, 30, -8)],
		["rotunda", Vector3(22, 42, -100), Vector3(0, 50, -122)],
		["forest", Vector3(-100, 16, 20), Vector3(-124, 20, 8)],
		["falls", Vector3(40, 44, -100), Vector3(96, 30, -118)],
		["battlements", Vector3(104, 28, 2), Vector3(128, 32, -24)],
		["stones", Vector3(-40, 20, -40), Vector3(-68, 24, -60)],
		["monument", Vector3(-6, 26, 100), Vector3(8, 30, 124)],
		["distance", Vector3(160, 60, 160), Vector3(0, 20, 0)],
		["pool", Vector3(82, 48.5, -112), Vector3(92, 46, -122)],
		["rope_end", Vector3(36, 42, -124), Vector3(56, 42, -118)],
		["stone_up", Vector3(60, 20, 1), Vector3(84, 27, -5)],
		["waterfall", Vector3(136, 56, -96), Vector3(96, 22, -124)],
		["cache", Vector3(-60, 24.5, -60), Vector3(-68, 24, -66)],
		["bridge_walk", Vector3(-60, 19.5, 4), Vector3(-90, 16, 6)],
		["on_stone", Vector3(-62, 22, -38), Vector3(-76, 23, -50)],
		["high_view", Vector3(0, 62, -118), Vector3(0, 20, 40)],
		["fog_off", Vector3(0, 300, 200), Vector3(0, 0, 0)],
	]
	for v: Array in views:
		w.player._vm_root.visible = false
		w._env.fog_enabled = v[0] != "fog_off"
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.FORWARD if v[0] == "top" else Vector3.UP)
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	get_tree().quit()
