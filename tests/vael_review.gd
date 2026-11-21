extends Node
## Port Vael from the places a player will look from, at night, at low tide and at high tide.
##     godot --path . res://tests/vael_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D


func shot(label: String, from: Vector3, toward: Vector3) -> void:
	w.player.position = from - Vector3.UP * 1.6
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func ground(x: float, z: float, up: float) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


## Sets the night's clock to a point in the tide's turning and lets the water settle there.
func tide_at(elapsed: float) -> void:
	w.director.elapsed = elapsed
	w.tide.level = MistTide.level_at(elapsed)
	await get_tree().create_timer(0.2).timeout


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.night_map = "vael"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "infantry"
	Game.mode = Game.Mode.NIGHT
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for mob: Zombie in w.zombies.duplicate(): mob.release()
	w.player.set_physics_process(false)
	w.player.set_process(false)
	cam = w.player.camera
	cam.cull_mask = 5
	await tide_at(20.0) # low tide
	await shot("vael_quay", ground(-6, -6, 2.0), ground(6, 30, 0.0))
	await shot("vael_flats_low", ground(0, 4.5, 3.0), ground(-10, 50, 0.0))
	await shot("vael_wreck_low", ground(-12, 36, 1.7), ground(-22, 46, 1.0))
	await shot("vael_bell_tower", ground(16, 20, 1.7), ground(8, 30, 5.0))
	await shot("vael_lighthouse", ground(84, 40, 1.7), ground(84, 70, 12.0))
	await shot("vael_mole", ground(-84, 12, 1.7), ground(-84, 70, 1.0))
	await shot("vael_town", ground(0, -30, 1.7), ground(0, -60, 3.0))
	await shot("vael_harbour_terraces", ground(10, -7.0, 3.2), ground(0, -25, 1.4))
	await shot("vael_valley_road", ground(14, -87, 2.0), ground(10, -108, 3.4))
	await shot("vael_aurora", ground(71, -19, 3.5), ground(43, 72, 30.0))
	await shot("vael_boatyard", ground(-80, -4, 2.7), ground(-74, -10, 1.5))
	await shot("vael_fishmarket", ground(43, -2, 2.0), ground(53, -8, 1.5))
	await shot("vael_ropewalk", ground(-51.5, -6.0, 1.7), ground(-50.3, -13, 0.9))
	await shot("vael_gullwatch", ground(-88, -47, 2.1), ground(-94, -56, 2.0))
	await shot("vael_east_landing", ground(70, 34, 1.8), ground(84, 34, 1.2))
	await shot("vael_pilgrims_garden", ground(80, -76, 2.5), ground(75, -85, 1.3))
	await shot("vael_square", ground(-8, -46, 1.7), ground(10, -56, 2.0))
	await shot("vael_chapel", ground(-30, -60, 1.7), ground(-40, -76, 4.0))
	await tide_at(MistTide.TURN + MistTide.RISE + 5.0) # high tide
	await shot("vael_flats_high", ground(0, 4.5, 3.0), ground(-10, 50, 0.0))
	await shot("vael_wreck_high", ground(-30, 8, 4.0), ground(-22, 46, 0.0))
	await shot("vael_overview_high", Vector3(-60, 55, 90), Vector3(0, 0, -10))
	await tide_at(20.0)
	await shot("vael_overview_low", Vector3(-60, 55, 90), Vector3(0, 0, -10))
	await preload("res://tests/scene_cleanup.gd").finish(w)
