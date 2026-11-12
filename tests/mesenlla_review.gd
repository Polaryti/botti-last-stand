extends Node
## The Valleys of Mesenlla from the places a player will look from, in its twilight.
##     godot --path . res://tests/mesenlla_review.tscn -- OUT
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


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.night_map = "mesenlla"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "cartographer"
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
	await shot("mesenlla_valley", ground(0, 84, 6.0), ground(0, -30, 6.0))
	await shot("mesenlla_outpost", ground(0, 14, 3.0), ground(0, -45, 3.0))
	await shot("mesenlla_portal", ground(0, -26, 1.7), ground(0, -45, 3.5))
	await shot("mesenlla_stones", ground(-40, -48, 3.0), ground(-54, -64, 2.0))
	await shot("mesenlla_rift", ground(-62, 18, 2.2), ground(-72, 8, 0.0))
	await shot("mesenlla_islands", ground(10, 40, 1.7), ground(-30, -10, 30.0))
	await shot("mesenlla_hamlet", ground(-14, 34, 2.2), ground(-36, 24, 1.5))
	await shot("mesenlla_crag", ground(30, -20, 4.0), ground(58, -44, 4.0))
	await shot("mesenlla_overview", Vector3(70, 60, 90), Vector3(-10, 0, -20))
	await preload("res://tests/scene_cleanup.gd").finish(w)
