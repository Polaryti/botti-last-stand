extends Node
## The Kraken of Vael as players will meet it at the end of Port Vael's night: rising in front of the
## quay, its crown of drowned towers and its eyes up close, its arms rearing over two players and
## whipping down on their rings, its sweep, its ink, its hook, its whirlpool, its fall; and a lone
## Kraken's Arm from the middle of the night, the same arm.
##     godot --path . res://tests/kraken_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D
var kraken: Zombie
var players: Array[Avatar] = []


func shot(label: String, from: Vector3, toward: Vector3, wait := 0.3) -> void:
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


## Holds it in a state for a while, as its phone would draw it.
func hold(z: Zombie, state: String, warn: bool, seconds: float) -> void:
	z._current_anim = state
	z.mesenlla_warning = warn
	var steps := int(seconds * 30.0)
	for i in steps:
		z._animate_custom(1.0 / 30.0, 0.0)


## A ring of its, frozen at a given moment of its tell.
func ring(z: Zombie, at: Vector3, reach: float, style: int, tell: float, gone: float, eye := 0.0) -> MistSeal:
	var seal := MistSeal.create(w, at, reach, eye, tell, 0.0, z.net_id, style)
	seal.elapsed = gone
	seal.set_physics_process(false)
	seal._material.set_shader_parameter("progress", minf(gone / tell, 1.0))
	return seal


func clear_rings() -> void:
	for s: MistSeal in w.mist_seals.duplicate():
		s.queue_free()
	await get_tree().process_frame


func person(id: int, cls: String, at: Vector3, face: Vector3) -> Avatar:
	var a := Avatar.new(w, id, {"name": "", "class": cls, "team": 0})
	w.add_child(a)
	a.apply_pose(at, atan2(face.x - at.x, face.z - at.z), 0.0, Vector3.ZERO, 1.0, 0, 0, "trident" if cls == "tidecaller" else "sword", 1.0)
	a.teleport(at)
	players.append(a)
	return a


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
	for z: Zombie in w.zombies.duplicate(): z.release()
	w.player.set_physics_process(false)
	w.player.set_process(false)
	w.player.position = ground(0, -30)
	cam = w.player.camera
	cam.cull_mask = 5
	cam.fov = 62.0
	w.director.elapsed = MistTide.TURN * 9.0 + MistTide.RISE + 6.0 # a high tide, near the end of the night
	w.tide.surge(900.0)
	w.tide.level = MistTide.level_at(w.director.elapsed)
	await get_tree().create_timer(0.3).timeout
	var at := ground(Director.KRAKEN_FROM.x, Director.KRAKEN_FROM.z)
	w.spawn_zombie(Director.KRAKEN, at)
	kraken = w.zombies.back()
	kraken.set_physics_process(false)
	kraken.position = at
	kraken.rotation.y = PI # facing the quay
	var quay := ground(0, 2.0, 1.7)
	# Rising out of the harbour.
	hold(kraken, "m_rise", false, 1.5)
	await shot("kraken_rising", quay + Vector3(7, 3, 0), at + Vector3(0, 3, 0), 0.4)
	hold(kraken, "", false, 3.0)
	await shot("kraken_risen", quay + Vector3(9, 4.5, -2), at + Vector3(0, 3.5, 0), 0.3)
	await shot("kraken_face", at + Vector3(4.0, 5.0, -11.0), at + Vector3(0, 4.0, 0), 0.2)
	await shot("kraken_crown", at + Vector3(-5.0, 12.0, -7.0), at + Vector3(0, 8.0, 1.0), 0.2)
	# Two players wading in; arms rear over each of them, then whip down.
	var a := person(901, "tidecaller", ground(-5, 14), at)
	var b := person(902, "infantry", ground(6, 13), at)
	var ra := ring(kraken, a.global_position, VaelMind.KRAKEN_SLAM_RADIUS, MistSeal.Style.SLAM, 1.4, 0.6)
	var rb := ring(kraken, b.global_position, VaelMind.KRAKEN_SLAM_RADIUS, MistSeal.Style.SLAM, 1.6, 0.6)
	hold(kraken, "m_slam", true, 1.2)
	await shot("kraken_slam_tell", ground(13, 6, 3.4), at + Vector3(-1, 3.5, -4), 0.3)
	ra.elapsed = 1.32
	rb.elapsed = 1.52
	hold(kraken, "m_slam", false, 0.35)
	await shot("kraken_slam_down", ground(13, 6, 3.4), at + Vector3(-1, 2.5, -5), 0.1)
	await clear_rings()
	# Too close: the sweep.
	a.teleport(ground(-2.5, 18))
	b.teleport(ground(3, 17.5))
	ring(kraken, at, VaelMind.KRAKEN_SWEEP_REACH, MistSeal.Style.WAVE, VaelMind.KRAKEN_SWEEP_TELL, 1.0, VaelMind.KRAKEN_BODY)
	hold(kraken, "m_sweep", true, 0.4)
	await shot("kraken_sweep", ground(9, 8, 5.0), at + Vector3(0, 1.5, -2), 0.25)
	await clear_rings()
	# Ink spat at one of them.
	a.teleport(ground(-6, 9))
	ring(kraken, a.global_position, VaelMind.KRAKEN_INK_RADIUS, MistSeal.Style.INK, VaelMind.KRAKEN_INK_TELL, 0.85)
	hold(kraken, "m_ink", true, 0.6)
	await shot("kraken_ink", ground(5, 4, 3.0), a.global_position + Vector3(0, 2.0, 5), 0.15)
	await clear_rings()
	# Its hook for whoever stands furthest off.
	b.teleport(ground(10, 4))
	ring(kraken, b.global_position, VaelMind.KRAKEN_GRASP_RADIUS, MistSeal.Style.HOOK, VaelMind.KRAKEN_GRASP_TELL, 0.9)
	hold(kraken, "m_grab", true, 0.8)
	await shot("kraken_grasp", ground(-8, 3, 4.0), at + Vector3(6, 1.5, -10), 0.2)
	await clear_rings()
	# The whirlpool, roaring.
	hold(kraken, "m_pull", false, 1.0)
	await shot("kraken_whirlpool", quay + Vector3(-8, 6, -3), at + Vector3(0, 3.5, 0), 0.3)
	for p: Avatar in players:
		p.queue_free()
	# Its fall.
	kraken.set_physics_process(true)
	kraken.take_damage(99999.0, Vector3.BACK, 0.0, kraken.centre())
	await get_tree().create_timer(1.4).timeout
	await shot("kraken_falling", quay + Vector3(9, 4.5, -2), at + Vector3(0, 2.5, 0), 0.05)
	# A lone arm from the middle of the night: the same arm.
	w.spawn_zombie("kraken_arm", ground(-10, 30))
	var lone: Zombie = w.zombies.back()
	lone.set_physics_process(false)
	lone.position = ground(-10, 30)
	lone.look_at(ground(-10, 20), Vector3.UP, true)
	hold(lone, "", false, 2.0)
	kraken.visible = false
	await shot("kraken_lone_arm", ground(-14, 19, 2.4), ground(-10, 30, 3.2), 0.3)
	await preload("res://tests/scene_cleanup.gd").finish(w)
