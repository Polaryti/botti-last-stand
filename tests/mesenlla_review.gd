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
	await shot("mesenlla_valley", ground(-8, 84, 6.0), ground(4, -30, 8.0))
	await shot("mesenlla_outpost", ground(-4, 4, 2.4), ground(0, -40, 3.0))
	await shot("mesenlla_hall", ground(-10, -26, 1.7), ground(0, -40, 2.5))
	await shot("mesenlla_falls", ground(14, -58, 2.0), ground(12, -80, 9.0))
	await shot("mesenlla_arch", ground(4, 42, 2.0), ground(20, 16, 6.0))
	await shot("mesenlla_stones", ground(-45, -54, 3.0), ground(-56, -66, 2.0))
	await shot("mesenlla_rift", ground(-64, 42, 2.2), ground(-72, 30, 3.5))
	await shot("mesenlla_forest", ground(-60, -10, 1.7), ground(-90, -40, 8.0))
	await shot("mesenlla_camp", ground(-14, 36, 2.2), ground(-36, 24, 1.5))
	await shot("mesenlla_crag", ground(22, -44, 3.0), ground(35, -51, 5.0))
	await shot("mesenlla_ruins", ground(28, 74, 2.4), ground(40, 84, 2.0))
	await shot("mesenlla_lodge", ground(-30, 80, 2.0), ground(-42, 90, 2.0))
	await shot("mesenlla_mine", ground(58, 82, 2.4), ground(75, 86, 3.0))
	await shot("mesenlla_spring", ground(0, 88, 1.8), ground(6, 96, 1.2))
	await shot("mesenlla_tent", ground(-17, -36, 1.7), ground(-14, -30, 1.0))
	await shot("mesenlla_overview", Vector3(70, 60, 90), Vector3(-10, 0, -20))
	await preload("res://tests/scene_cleanup.gd").finish(w)
