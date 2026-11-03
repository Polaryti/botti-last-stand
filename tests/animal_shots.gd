extends Node
## Pictures of the animals and the Dread Rider, to check sizes and movement. Args: output folder.
var out := ""
var m: Main
var cam: Camera3D


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.player_class = "ranger"
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(0.5)
	await m.start_game(Game.Mode.SANDBOX)
	await wait(0.6)
	var w: World = m.world
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 100.0
	w.add_child(cam)
	m.hud.visible = false
	w.player.global_position = Vector3(0, 0.05, 28)
	# In a row: a zombie, a Beast, a Dread Rider, a Fallen Knight and a dummy.
	var line := [["normal", -8.0], ["beast", -5.0], ["rider", -0.5], ["hero_chivalry", 4.0]]
	for e: Array in line:
		w.spawn_zombie(e[0], Vector3(e[1], 0, 16))
	for z: Zombie in w.zombies:
		if z.type_id != "dummy":
			z.set_physics_process(false)
			z.rotation.y = PI * 0.5
			z.set_process(true)
	w.spawn_ally("wolf", Vector3(8, 0, 16), 100.0)
	await wait(0.2)
	await wait(0.4)
	look(Vector3(0, 2.2, 28), Vector3(0, 1.4, 16))
	await snap("row")
	look(Vector3(-0.5, 1.8, 22), Vector3(-0.5, 1.4, 16))
	await snap("rider_side")
	get_tree().quit()
