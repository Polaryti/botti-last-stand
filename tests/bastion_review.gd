extends Node
## Mist Bastion from the places a player will look from: the citadel and its Great Portal, each gate,
## the three lanes and the valley the enemies come up from.
##     godot --path . res://tests/bastion_review.tscn -- OUT
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
	Game.fort_map = "bastion"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "heavy"
	Game.mode = Game.Mode.FORT
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.FORT)
	w.director.running = false
	for mob: Zombie in w.zombies.duplicate(): mob.release()
	w.player.set_physics_process(false)
	w.player.set_process(false)
	cam = w.player.camera
	cam.cull_mask = 5
	await shot("bastion_portal", ground(0, -56, 1.7), ground(0, -72, 5.0))
	await shot("bastion_yard", ground(14, -50, 2.4), ground(-14, -74, 2.0))
	await shot("bastion_walls", ground(0, -36, 2.0), ground(0, -50, 4.0))
	await shot("bastion_middle_gate", ground(-2, -58, 1.7), ground(0, -44, 1.5))
	await shot("bastion_post_camp", ground(-46, -26, 2.2), ground(-58, -34, 1.5))
	await shot("bastion_outer_wall", ground(-62, 40, 2.0), ground(-76, 30, 3.0))
	await shot("bastion_west_gate", ground(-38, -54, 2.0), ground(-26, -62, 3.0))
	await shot("bastion_middle_lane", ground(0, 30, 2.0), ground(0, -40, 10.0))
	await shot("bastion_from_wall", Vector3(-10, 24.2, -45.8), Vector3(-6, 8, 20))
	await shot("bastion_west_lane", ground(-46, 40, 2.0), ground(-48, -40, 8.0))
	await shot("bastion_spine", ground(-12, 8, 2.0), ground(-30, 8, 3.0))
	await shot("bastion_overview", Vector3(80, 70, 70), Vector3(0, 0, -30))
	# The garrison, side by side in the yard, looking at the camera.
	var at := ground(0, -61, 0.0)
	for i in Garrison.ORDER.size():
		var a := w.spawn_garrison(Garrison.ORDER[i], 1, at + Vector3(-2.2 + i * 2.2, 0, 0), Vector3.INF)
		a.global_position = at + Vector3(-2.2 + i * 2.2, 0, 0)
		a.rotation.y = 0.0
		a.set_physics_process(false)
	await shot("bastion_garrison", at + Vector3(0, 1.5, 5.5), at + Vector3(0, 1.0, 0))
	await preload("res://tests/scene_cleanup.gd").finish(w)
