extends Node
var out := ""
var w: World
var camera: Camera3D
func snap(name: String, from: Vector3, toward: Vector3) -> void:
	w.player.position = from - Vector3.UP * 1.58
	camera.global_position = from
	camera.look_at(toward)
	await get_tree().create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
func setup(mode: int) -> void:
	w = World.new()
	add_child(w)
	w.setup(mode)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	w.player.set_physics_process(false)
	w.player.set_process(false)
	w.player._vm_root.visible = false
	camera = w.player.camera
	camera.cull_mask = 5
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.player_class = "heavy"
	Game.night_map = "village"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	setup(Game.Mode.NIGHT)
	var at := Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	var snake := SnakeBody.new()
	w.add_child(snake)
	snake.position = at
	await snap("snake_idle", at + Vector3(1, 0.7, 1.5), at + Vector3(0, 0.1, -0.5))
	snake.moving = true
	await get_tree().create_timer(0.5).timeout
	await snap("snake_slither", at + Vector3(1, 0.7, 1.5), at + Vector3(0, 0.1, -0.5))
	snake.biting = true
	await snap("snake_bite", at + Vector3(1, 0.7, 1.5), at + Vector3(0, 0.1, -0.5))
	snake.queue_free()
	HeavyWave.spawn_visual(w, 0, at, Vector3.FORWARD, 6)
	w.fx_dome(at + Vector3.UP * 0.5, 6, 3)
	await snap("guardian_oath", at + Vector3(9, 6, 9), at + Vector3.UP)
	await get_tree().create_timer(3).timeout
	HeavyWave.spawn_visual(w, 2, at, Vector3.FORWARD, 12)
	await snap("warlord_faultline", at + Vector3(7, 5, 2), at + Vector3.FORWARD * 5)
	HeavyWave.spawn_visual(w, 1, at, Vector3.FORWARD, 4)
	w.spawn_zombie("normal", at + Vector3.LEFT * 2)
	var enemy: Zombie = w.zombies.back()
	enemy.set_physics_process(false)
	enemy.ignite(4)
	await snap("warpriest_rites", at + Vector3(7, 4, 6), at + Vector3.UP)
	var ground := w.ground_at(Vector3(-68, 0, 24))
	await snap("village_fences", Vector3(-65, ground + 2.5, 20), Vector3(-72, ground + 0.5, 27))
	var rock := Vector3(-40.302, 0, -50.775)
	rock.y = w.ground_at(rock)
	await snap("grounded_rocks", rock + Vector3(4, 2, 4), rock + Vector3.UP * 0.4)
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	setup(Game.Mode.FORT)
	var gate: Dictionary = w.fort.gates[0]
	gate["hp"] = 770
	w.fort._show_gate(gate)
	var hud := Hud.new()
	hud.theme = UiTheme.make()
	hud.player = w.player
	hud.director = w.director
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await snap("gate_cost_outside", Vector3(0, 1.65, -36), Vector3(0.7, 1.8, -26))
	await snap("gate_cost_inside", Vector3(0, 1.65, -16), Vector3(0.7, 1.8, -26))
	# From the side, where a label that turned to face the camera used to sink into the wall.
	await snap("gate_cost_angle", Vector3(11, 1.65, -33), Vector3(0, 4.5, -27.2))
	# A game together: the list of players with health, one of them down, the effects row with a
	# Commander's rally, and the drop button up top.
	var p := w.player
	p.slots = ["mace", "sword"]
	p._equip()
	p._act({"do": "buff", "key": "command_speed", "stat": "speed", "val": 0.25, "secs": 8.0}, {})
	p._act({"do": "buff", "key": "command_melee", "stat": "melee_damage", "val": 0.2, "secs": 8.0}, {})
	Net.roster = {1: {"name": "Mario", "class": "heavy", "team": 0, "score": 0, "deaths": 0, "lives": 3},
		2: {"name": "Lucia", "class": "ranger", "team": 0, "score": 0, "deaths": 0, "lives": 3},
		3: {"name": "Pepe", "class": "monk", "team": 0, "score": 0, "deaths": 1, "lives": 3}}
	var friends: Array[Avatar] = []
	for peer: int in [2, 3]:
		var a := Avatar.new(w, peer, Net.roster[peer])
		w.add_child(a)
		a.position = Vector3(peer * 2.0, 0, -12)
		Net._avatars[peer] = a
		friends.append(a)
	friends[0].hp_fraction = 0.55
	friends[1].set_fallen(true)
	friends[1].down_since = w.now - 6.0
	Net.in_game = true
	await snap("together_hud", Vector3(0, 1.65, -14), Vector3(0, 1.6, -26))
	Net.in_game = false
	for a in friends:
		Net._avatars.erase(a.peer)
		a.queue_free()
	Net.roster = {}
	hud.visible = false
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	w.stock_wood()
	var wood: Pickup = w.pickups.back()
	await snap("forest_firewood", wood.position + Vector3(5, 3, 5), wood.position + Vector3.UP * 0.4)
	# A Mercenary's Nightfall from outside, and from inside an enemy's.
	var spot := Vector3(0, w.ground_at(Vector3(0, 0, 60)), 60)
	w.spawn_nightfall(99, spot, 6.0, 30.0, 1.5, 0)
	await get_tree().create_timer(0.4).timeout
	await snap("nightfall_outside", spot + Vector3(9, 2.4, 9), spot + Vector3.UP * 1.5)
	hud.visible = true
	w.player.night_blind_left = 5.0
	await snap("nightfall_blind", spot + Vector3(0, 1.65, 2), spot + Vector3(0, 1.4, -8))
	w.player.night_blind_left = 0.0
	hud.visible = false
	# A Cartographer's linked beacons, a Star Reader's constellation and a Worlds Traveler's Waygates.
	var base := {"kind": "", "max": 3, "link": 24.0, "radius": 4.0, "heal": 2.0, "mark": 10.0, "bonus": 0.2, "power": 15.0, "gate_speed": 0.3, "gate_rest": 3.0, "gate_heal": 0.0, "bits": 0}
	var field := Vector3(0, 0, 96)
	for offset: Vector3 in [Vector3(-7, 0, 0), Vector3(7, 0, 0), Vector3(0, 0, -11)]:
		w.plant_beacon(201, field + offset, base, 0.0)
	await get_tree().create_timer(0.3).timeout
	var field_y := w.ground_at(field)
	await snap("survey_beacons", field + Vector3(0, field_y + 7.0, 14), field + Vector3(0, field_y + 0.5, -4))
	var stars := base.duplicate()
	stars["kind"] = "stars"
	var sky := Vector3(-40, 0, 96)
	for offset: Vector3 in [Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(0, 0, -13)]:
		w.plant_beacon(202, sky + offset, stars, 0.0)
	await get_tree().create_timer(0.3).timeout
	await snap("survey_constellation", sky + Vector3(0, w.ground_at(sky) + 8.0, 13), sky + Vector3(0, w.ground_at(sky) + 0.5, -5))
	var gates := base.duplicate()
	gates["kind"] = "gates"
	var road := Vector3(40, 0, 96)
	w.plant_beacon(203, road, gates, 0.0)
	w.plant_beacon(203, road + Vector3(10, 0, -8), gates, 0.6)
	await get_tree().create_timer(0.3).timeout
	await snap("survey_waygates", road + Vector3(-2, w.ground_at(road) + 2.4, 7), road + Vector3(3, w.ground_at(road) + 1.2, -4))
	# The rings that warn of what the creatures of Mesenlla are about to bring down: mist, quake, storm, fire, boulder.
	var rings := Vector3(0, 0, 74)
	for i in 5:
		var ring_at := rings + Vector3(-12 + i * 6, 0, 0)
		ring_at.y = w.ground_at(ring_at)
		var seal := MistSeal.create(w, ring_at, 2.4, 0.0, 30.0, 0.0, -1, i)
		seal.elapsed = 12.0
	await get_tree().create_timer(0.3).timeout
	await snap("mesenlla_rings", rings + Vector3(0, w.ground_at(rings) + 9.0, 11), rings + Vector3(0, w.ground_at(rings), -1))
	canvas.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
