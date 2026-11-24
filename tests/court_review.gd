extends Node
## The drowned court of Port Vael, posed on the harbour as a player meets them: each with its tell and
## its ring on the ground (VaelMind, MistSeal), the Kraken's arms at high tide and the Hollow Sovereign.
##     godot --path . res://tests/court_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D


func shot(label: String, from: Vector3, toward: Vector3, wait := 0.35) -> void:
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


## One of the court, standing still in a pose: its own state for those built of parts, an animation
## for those on a body.
func pose(id: String, at: Vector3, face: Vector3, state: String, warn: bool) -> Zombie:
	w.spawn_zombie(id, at)
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	z.position = at
	z.look_at(Vector3(face.x, at.y, face.z), Vector3.UP, true)
	if z.mesenlla_mind:
		z.mesenlla_mind.phase = "pose"
	z.mesenlla_warning = warn
	if z._custom:
		z._current_anim = state
		for i in 50:
			z._animate_custom(1.0 / 30.0, 0.0)
	elif state != "":
		z._play(state, 1.0, 0.0)
	return z


func seal(z: Zombie, at: Vector3, reach: float, style: int, delay := 1.4) -> void:
	MistSeal.create(w, at, reach, 0.0, delay, 0.0, z.net_id, style)


func clear() -> void:
	for z: Zombie in w.zombies.duplicate(): z.release()
	for s: MistSeal in w.mist_seals.duplicate(): s.queue_free()
	await get_tree().process_frame


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
	await clear()
	w.player.set_physics_process(false)
	w.player.set_process(false)
	w.player.position = ground(0, -20)
	cam = w.player.camera
	cam.cull_mask = 5
	await tide_at(20.0) # low tide
	# A Siren singing on the flats, her rings swelling.
	var siren := await_pose("siren", ground(-4, 30), ground(0, 22), "m_song", false)
	await shot("court_siren_song", ground(1.5, 24.5, 1.4), siren.position + Vector3(0, 1.1, 0))
	await clear()
	# A Press Gang, one winding up, his net in the air over you.
	var press := await_pose("press_gang", ground(3, 30), ground(0, 22), "WindUp", true)
	await_pose("press_gang", ground(-1, 31.5), ground(0, 22), "", false)
	await_pose("press_gang", ground(6, 32), ground(0, 22), "", false)
	seal(press, ground(0.5, 24.5), VaelMind.NET_RADIUS, MistSeal.Style.NET, 0.9)
	await shot("court_press_gang", ground(-1.5, 19.5, 1.6), ground(2, 28, 0.6), 0.62)
	await clear()
	# A Tide Witch sending her line of waves.
	var witch := await_pose("tide_witch", ground(-2, 34), ground(0, 22), "Spellcast_Shoot", true)
	for i in VaelMind.WAVES:
		seal(witch, ground(-1.5 + i * 0.4, 31 - (i + 1) * 3.6), VaelMind.WAVE_RADIUS, MistSeal.Style.WAVE, 1.0 + i * 0.25)
	await shot("court_tide_witch", ground(4, 19, 2.2), ground(-1, 29, 0.6))
	await clear()
	# The Harbourmaster on the quay stairs, his hook on its chain flying at you.
	var hm := await_pose("harbourmaster", ground(30, 12), ground(26, 24), "Throw", false)
	seal(hm, ground(26.5, 22.5), VaelMind.HOOK_RADIUS, MistSeal.Style.HOOK, 0.9)
	await shot("court_harbourmaster", ground(22, 27, 2.0), ground(29, 13, 1.6), 0.55)
	await clear()
	# The Mad Lighthouse Keeper on the East Mole, lifting his great lamp; an oil lamp on its way.
	var keeper := await_pose("lighthouse_keeper", ground(84, 56), ground(84, 44), "Raise", true)
	seal(keeper, keeper.position, VaelMind.FLASH_REACH, MistSeal.Style.FLASH, 3.0)
	await shot("court_keeper", ground(81, 46, 1.8), keeper.position + Vector3(0, 1.6, 0), 0.8)
	await clear()
	# The Kraken's arms risen out of the flooded flats round you, one rearing, one slamming down.
	await tide_at(MistTide.TURN * 3.0 + MistTide.RISE + 6.0)
	var centre := ground(-6, 44)
	var states := ["", "m_slam", "", "m_slam"]
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var arm := await_pose("kraken_arm", centre + Vector3(cos(a), 0, sin(a)) * World.KRAKEN_RING, centre, states[i], i == 1)
		if i == 1:
			seal(arm, centre + Vector3(cos(a), 0, sin(a)) * 2.0, VaelMind.KRAKEN_RADIUS, MistSeal.Style.SLAM, 3.0)
	await shot("court_kraken", ground(-6, 33, 3.2), ground(-6, 46, 2.5))
	await clear()
	# The Hollow Sovereign risen on the flats, at his decree; the crown's judgement waiting on you.
	var king := await_pose("hollow_sovereign", ground(0, 46), ground(0, 34), "Raise", true)
	seal(king, ground(1, 37.5), VaelMind.JUDGEMENT_RADIUS, MistSeal.Style.CROWN, 3.0)
	await shot("court_sovereign", ground(3.5, 33, 2.2), king.position + Vector3(0, 3.2, 0), 0.7)
	await shot("court_sovereign_near", ground(-2.5, 40.5, 3.2), king.position + Vector3(0, 3.6, 0), 0.3)
	await clear()
	await tide_at(20.0)
	# The Sunken Crown where he fell, and a player wearing it (as everyone else sees them).
	w.spawn_pickup_at(ground(0, 30), Pickup.Kind.POWER, PowerDefs.CROWN)
	await shot("court_crown", ground(1.2, 28.2, 1.0), ground(0, 30, 0.4))
	await preload("res://tests/scene_cleanup.gd").finish(w)


func await_pose(id: String, at: Vector3, face: Vector3, state: String, warn: bool) -> Zombie:
	return pose(id, at, face, state, warn)
