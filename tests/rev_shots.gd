extends Node
## Pictures of the Revenant, fires, the map screen and the code box. Args: output folder.
var out := ""

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.unlocked = {"revenant": true}
	Game.player_class = "revenant"
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(0.6)
	m.show_settings()
	await wait(0.2)
	await snap("settings")
	m.show_class_picker(Game.Mode.NIGHT)
	await wait(0.2)
	await snap("classes")
	await m.start_game(Game.Mode.NIGHT)
	var w := m.world
	var pl := w.player
	w.director.running = false
	w.director._stock_timer = 9999.0
	w.director._familiar_timer = 9999.0
	for z: Zombie in w.zombies.duplicate():
		z.release()
	for it: Pickup in w.pickups.duplicate():
		w.remove_pickup(it)
	await wait(0.4)
	await snap("hud_start")
	pl.points = 5
	pl._auto_unlock()
	m.toggle_tree()
	await wait(0.3)
	await snap("tree")
	m.toggle_tree()
	pl.choose_ability(Player.CORE_STEPS, 0)
	pl.global_position = Vector3(0, 0, 18)
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	w.spawn_zombie("normal", Vector3(-2, 0, 13))
	w.spawn_zombie("clever", Vector3(2, 0, 13))
	for z: Zombie in w.zombies:
		z.set_physics_process(false)
	pl.mana = 100.0
	await wait(0.2)
	await snap("claws_rest")
	pl.input_fire = true
	await wait(0.17)
	pl.input_fire = false
	await snap("claws_swing")
	await wait(0.4)
	pl.use_burst()
	await wait(0.48)
	await snap("burst")
	await wait(0.4)
	await snap("frozen")
	# Fires.
	for z: Zombie in w.zombies.duplicate():
		z.release()
	pl.global_position = Vector3(4, w.ground_at(Vector3(4, 0, 0)), 2)
	pl.yaw = -0.9
	pl.rotation.y = -0.9
	await wait(0.4)
	await snap("bonfire_square")
	pl.global_position = Vector3(-4, 0.2, 46)
	pl.yaw = PI
	pl.rotation.y = PI
	await wait(0.4)
	await snap("bridge_torches")
	pl.global_position = Vector3(-40, w.ground_at(Vector3(-40, 0, -70)), -70)
	pl.yaw = 1.57
	pl.rotation.y = 1.57
	await wait(0.4)
	await snap("gate_torches")
	# A crow about to dive.
	pl.global_position = Vector3(0, 0.1, 30)
	pl.yaw = 0.0
	pl.rotation.y = 0.0
	w.spawn_zombie("crow", Vector3(6, 0, 34))
	var c: Zombie = w.zombies[-1]
	c.set_physics_process(false)
	c._windup = 0.5
	await wait(0.2)
	await snap("crow_warning")
	c.release()
	m.show_pause()
	await wait(0.2)
	await snap("pause")
	m.show_map()
	await wait(0.3)
	await snap("map")
	Game.unlocked = {}
	get_tree().quit()
