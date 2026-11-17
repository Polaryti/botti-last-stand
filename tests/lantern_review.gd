extends Node
## Last Light on the Lantern Road, as a player sees it: the Lantern Barge setting out from the Harbour
## Gate, its light on the water, the road's lanterns lit behind it, a waystation with its boons, the
## tide drowning someone outside the light, and the Leviathan of the Mists off the Isle of Lamps.
##     godot --path . res://tests/lantern_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D
var hud: Hud
var ll: LastLight


func shot(label: String, from: Vector3, toward: Vector3, wait := 0.35) -> void:
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


## The barge somewhere along its course, set down there at once.
func barge_to(along: float) -> void:
	ll.progress = along
	ll._place(0.0)
	ll._light_lanterns()


## A spot beside the barge (to its left, as it faces), at its own height.
func beside(side: float, back := 0.0, up := 0.0) -> Vector3:
	var b := ll.barge.global_transform
	var at := b.origin + b.basis.x * side + b.basis.z * back
	return ground(at.x, at.z, up)


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.night_map = "lantern_road"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "infantry"
	Game.mode = Game.Mode.NIGHT
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	ll = w.last_light
	ll.set_physics_process(false)
	w.player.set_physics_process(false)
	w.player.set_process(false)
	cam = w.player.camera
	cam.cull_mask = 5
	# Setting out: the Harbour Gate behind, the barge at the quay, the road running into the fog.
	barge_to(0.0)
	w.player.global_position = beside(-5.0)
	await shot("lantern_setout", ll.barge_at() + Vector3(16, 8, 12), ll.barge_at() + Vector3(-3, 0, -6), 0.6)
	# The barge close up: the Great Lantern in its cage, the deck, the sweep.
	await shot("lantern_barge", beside(-6.5, -4.0, 2.4), ll.barge_at() + Vector3(0, 1.8, 0))
	# Under way: the lanterns it has passed lit behind it, a player walking beside it, the HUD.
	hud = Hud.new()
	hud.theme = UiTheme.make()
	hud.player = w.player
	hud.director = w.director
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.director.running = true
	barge_to(ll.way_at[0] * 0.8)
	w.player.global_position = beside(-5.0)
	ll.moving = true
	var ahead := ll.barge.global_transform.basis.z * -1.0
	await shot("lantern_underway", ll.barge_at() - ahead * 14.0 + Vector3(-6, 6, 0), ll.barge_at() + ahead * 6.0, 0.6)
	await shot("lantern_road_behind", ll.barge_at() + ahead * 6.0 + Vector3(-7, 4.5, 0), ll.barge_at() - ahead * 30.0, 0.4)
	# Outside the light: the tide drowning you.
	# Run on ahead up the road, past the edge of the light.
	var on := ll.path.sample_baked(ll.progress + LastLight.LIGHT_RADIUS + 8.0)
	var off := ll.barge.global_transform.basis.x * -5.4
	w.player.global_position = ground(on.x + off.x, on.z + off.z, 0.05)
	ll._out[w.player] = Boons.grace(w.player) + 1.0
	await shot("lantern_drowning", w.player.global_position - ahead * 4.0 + Vector3(0, 3.0, 0) - off * 0.4, ll.barge_at() + Vector3(0, 1.5, 0), 0.4)
	ll._out.clear()
	# A waystation: the brazier lit, the barge moored, three boons to choose from.
	barge_to(ll.way_at[0])
	ll.moving = false
	ll.docked = 0
	ll.ways_done = 1
	ll._docked_here(0)
	ll._offer()
	ll.offer = ["deep_lungs", "salt_ward", "ships_biscuit"] as Array[String] # the longest words, to see them fit
	var way: Transform3D = w.waystations[0]
	w.player.global_position = ground(way.origin.x, way.origin.z, 0.1)
	await shot("lantern_waystation", way.origin + Vector3(-9, 6, 9), (way.origin + ll.barge_at()) * 0.5, 0.8)
	ll.offer.clear()
	ll.docked = -1
	# The Isle of Lamps: the Leviathan risen in the sea off it, rearing to strike at you (the HUD
	# away, so its entrance card does not hide it).
	hud.visible = false
	barge_to(ll.length)
	ll.arrived = true
	w.player.global_position = beside(-5.0)
	var spot := ll.leviathan_spot(0)
	w.spawn_zombie("leviathan", spot)
	var beast: Zombie = w.zombies.back()
	beast.set_physics_process(false)
	beast.position = spot
	beast.look_at(Vector3(w.player.global_position.x, spot.y, w.player.global_position.z), Vector3.UP, true)
	beast.mesenlla_mind.phase = "pose"
	beast._current_anim = ""
	for i in 60:
		beast._animate_custom(1.0 / 30.0, 0.0)
	var toward := (spot - w.player.global_position).normalized()
	await shot("lantern_leviathan", spot - toward * 22.0 + Vector3(0, 5, 0) + toward.cross(Vector3.UP) * 6.0, spot + Vector3(0, 6, 0), 0.6)
	beast.mesenlla_warning = true
	beast._current_anim = "m_slam"
	for i in 30:
		beast._animate_custom(1.0 / 30.0, 0.0)
	MistSeal.create(w, w.player.global_position, VaelMind.BITE_RADIUS_L, 0.0, 2.0, 0.0, beast.net_id, MistSeal.Style.SLAM)
	await shot("lantern_leviathan_rear", w.player.global_position - toward * 5.0 + toward.cross(Vector3.UP) * 4.0 + Vector3(0, 2.5, 0), spot + Vector3(0, 6, 0), 0.5)
	# It falls, and the lighthouse burns.
	beast.release()
	ll._light_up()
	await shot("lantern_lighthouse_lit", w.lighthouse_top + Vector3(-28, -6, 34), w.lighthouse_top, 0.8)
	hud.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
