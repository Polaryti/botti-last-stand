extends Node
var w: World
var camera: Camera3D
var out: String
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.night_map = "vael"
	Game.mode = Game.Mode.NIGHT
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	w.player.set_physics_process(false)
	w.player.camera.current = false
	camera = Camera3D.new()
	w.add_child(camera)
	camera.current = true
	w._apply_sky(0.0)
	for id: String in ["hollow_sovereign", "kraken_arm", "leviathan", "brine_hound", "angler", "siren"]:
		var at := Vector3(0, w.ground_at(Vector3(0,0,40)), 40)
		w.spawn_zombie(id, at)
		var z: Zombie = w.zombies.back()
		var group: Array[Zombie] = [z]
		if id == "kraken_arm":
			for offset: Vector3 in [Vector3(-6,0,0),Vector3(0,0,-6),Vector3(6,0,0)]:
				w.spawn_zombie(id, at+offset)
				var arm: Zombie = w.zombies.back()
				arm.set_physics_process(false)
				arm._current_anim = ""
				group.append(arm)
		z.set_physics_process(false)
		z.position = at + Vector3(0,0,6) if id == "kraken_arm" else at
		z.rotation.y = 0
		var tall := 6.0 if id == "leviathan" else 6.0 if id == "kraken_arm" else 3.0 if id == "hollow_sovereign" else 1.0
		camera.position = at + Vector3(-tall*1.8, tall*1.2, tall*3.5)
		camera.look_at(at+Vector3.UP*tall)
		w.player.position = at+Vector3(-6,0,14)
		z._current_anim = ""
		if id == "angler": z._visual.set_meta("buried", false)
		for i in 30:
			for actor in group: actor._animate_custom(1.0/60,2)
		await snap(id+"_coastal_idle")
		z.mesenlla_warning = true
		z._current_anim = "Raise" if id == "hollow_sovereign" else "m_slam" if id in ["kraken_arm","leviathan"] else "m_song" if id == "siren" else "m_bite"
		for i in 40: z._animate_custom(1.0/60, 0)
		await snap(id+"_coastal_tell")
		z.mesenlla_warning = false
		for i in 8:
			z._animate_custom(1.0/60,0)
			await get_tree().physics_frame
		await snap(id+"_coastal_strike")
		for actor in group: actor.release()
	var chest_at := Vector3(10,w.ground_at(Vector3(10,0,40)),40)
	w.tide.add_salvage(chest_at,0)
	var chest: Dictionary = w.tide.salvage().back()
	camera.position = chest_at+Vector3(2,1.8,3)
	camera.look_at(chest_at+Vector3.UP*0.4)
	await snap("salvage_closed")
	w.tide._open(chest,w.player,MistTide.ebb(w.tide.elapsed()))
	await get_tree().create_timer(0.7).timeout
	await snap("salvage_open")
	await preload("res://tests/scene_cleanup.gd").finish(w)
func snap(label: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
