extends Node
## The Ascendant as players will see it: dressed and holding its Ruin-Breaker Greataxe from the front, the
## side and behind, its HUD, Ascend crashing into a crowd, a Godslayer's Deicide breaking a Priest's flask
## in mid-throw, an Adorer drinking the Elixir of Change and the field of change opening, its Crucible
## Heart bursting, the profession choice with the Adorer still locked, and Fontanova's three weapons:
## the Censer Flail's release, the Resin Repeater and the Greataxe held.
##     godot --path . res://tests/ascendant_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D
var p: Player
var hud: Hud


func shot(label: String, from: Vector3, toward: Vector3, wait := 0.3) -> void:
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


func foe(at: Vector3, kind := "normal") -> Zombie:
	w.spawn_zombie(kind, at)
	var z: Zombie = w.zombies.back()
	z.position = at
	z.hp = 5000.0
	z.max_hp = 5000.0
	z.look_at(Vector3(p.global_position.x, at.y, p.global_position.z), Vector3.UP, true)
	z.set_physics_process(false)
	return z


func clear() -> void:
	for z: Zombie in w.zombies.duplicate(): z.release()
	for seal: MistSeal in w.mist_seals.duplicate(): seal.queue_free()
	await get_tree().process_frame


## The player as an Ascendant of the given profession (-1 for none), at `at`, facing -Z.
func ascendant(spec: int, final: bool, at: Vector3) -> void:
	p.setup_class("ascendant")
	p.points = 9
	p.level = 10 if final else 5
	p.chosen.clear()
	p.flags.clear()
	p.mods = Player.BASE_MODS.duplicate()
	p.spec_id = ""
	if spec >= 0:
		for step in (9 if final else 4):
			p.choose_ability(step, spec if step == 3 else 0)
	p.global_position = at
	p.yaw = 0.0
	p.rotation.y = 0.0
	p.pitch = 0.0
	p.camera.rotation = Vector3.ZERO
	p.art_cd_left = 0.0


func body(at: Vector3, yaw: float, weapon := "ruin_greataxe", id := 900) -> Avatar:
	var a := Avatar.new(w, id, {"name": "", "class": "ascendant", "team": 0})
	w.add_child(a)
	a.apply_pose(at, yaw, 0.0, Vector3.ZERO, 1.0, 0, 0, weapon, 1.0)
	a.teleport(at)
	return a


## Lets the leap run its course, frame by frame, as it would in play.
func leap_through() -> void:
	p.set_physics_process(true)
	for i in 40:
		await get_tree().physics_frame
		if p._leap_t < 0.0:
			break
	p.set_physics_process(false)


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "ascendant"
	Game.mode = Game.Mode.SANDBOX
	Game.earned_specs.erase("adorer")
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.SANDBOX)
	w.director.running = false
	w._apply_sky(1.0)
	await clear()
	p = w.player
	p.set_physics_process(false)
	p.set_process(false)
	p.camera.current = false
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 50.0
	# Dressed, the greataxe in hand: from the front, the side and behind.
	var origin := ground(-4, 12)
	var bodies: Array[Avatar] = []
	for i in 4:
		var at := origin + Vector3((i - 1.5) * 1.5, 0, 0)
		at.y = w.ground_at(at)
		bodies.append(body(at, [PI, PI, PI * 0.5, 0.0][i], "ruin_greataxe", 900 + i))
	await shot("ascendant_models", origin + Vector3(0, 1.4, 5.2), origin + Vector3(0, 1.0, 0), 0.8)
	await shot("ascendant_model_close", bodies[0].global_position + Vector3(0.3, 1.6, 1.6), bodies[0].global_position + Vector3(0, 1.35, 0), 0.3)
	await shot("ascendant_model_back", bodies[3].global_position + Vector3(-0.4, 1.8, 1.8), bodies[3].global_position + Vector3(0, 1.35, 0), 0.3)
	for a: Avatar in bodies:
		a.queue_free()
	# Fontanova's weapons, held.
	var held: Array[Avatar] = []
	var weapons := ["censer_flail", "resin_repeater", "ruin_greataxe"]
	for i in 3:
		var at := origin + Vector3((i - 1) * 1.6, 0, 0)
		at.y = w.ground_at(at)
		held.append(body(at, PI, weapons[i], 920 + i))
	await shot("fonta_weapons_held", origin + Vector3(0, 1.3, 4.4), origin + Vector3(0, 0.9, 0), 0.8)
	for a: Avatar in held:
		a.queue_free()
	hud = Hud.new()
	hud.theme = UiTheme.make()
	hud.player = p
	hud.director = w.director
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var here := ground(0, 20)
	# The HUD, and Ascend crashing into a crowd.
	ascendant(-1, false, here)
	for i in 5:
		foe(ground(-2.0 + i, 13 - (i % 2) * 1.2))
	cam.current = false
	p.camera.current = true
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ascendant_hud.png"))
	p.camera.current = false
	cam.current = true
	AscendantKit.ascend(p)
	await leap_through()
	await shot("ascendant_ascend", here + Vector3(6, 2.8, -4), here + Vector3(0, 0.6, -8), 0.12)
	# A Godslayer's Deicide on a Priest of Change caught in mid-throw: its flask's ring breaks.
	await clear()
	ascendant(0, true, here)
	var priest := foe(ground(0, 13), "cult_priest")
	priest.set_physics_process(true)
	priest._sees = true
	var mind := priest.mesenlla_mind as CultMind
	mind.cooldown = 0.0
	mind.tick(priest, p, Vector3.ZERO, 7.0, 0.01)
	priest.set_physics_process(false)
	await shot("godslayer_rite", here + Vector3(5, 2.6, -2), here + Vector3(0, 0.8, -6), 0.4)
	AscendantKit.deicide(p)
	await leap_through()
	await shot("godslayer_deicide", here + Vector3(5, 2.6, -2), here + Vector3(0, 0.8, -6), 0.1)
	# An Adorer drinking the Elixir of Change, its field opening on a crowd.
	await clear()
	Game.earned_specs["adorer"] = true
	ascendant(1, true, here)
	for i in 6:
		var a := TAU * i / 6.0
		foe(here + Vector3(cos(a) * 2.6, 0, sin(a) * 2.6))
	var adorer := body(here, PI, "ruin_greataxe", 960)
	AscendantKit.drink(p)
	await shot("adorer_field_told", here + Vector3(4.5, 3.4, 5.0), here + Vector3(0, 0.6, 0), 0.3)
	await shot("adorer_field_opens", here + Vector3(4.5, 3.4, 5.0), here + Vector3(0, 0.6, 0), 0.6)
	p.changed_left = 0.01
	AscendantKit.tick(p, 0.02)
	await shot("adorer_crucible", here + Vector3(5.5, 3.8, 6.0), here + Vector3(0, 0.8, 0), 0.12)
	adorer.queue_free()
	# The Censer Flail's release.
	await clear()
	for i in 6:
		var a := TAU * i / 6.0
		foe(here + Vector3(cos(a) * 2.4, 0, sin(a) * 2.4))
	var swinger := body(here, PI, "censer_flail", 961)
	w.censer_fx(here, float(WeaponDefs.ALL["censer_flail"]["censer_reach"]))
	await shot("censer_release", here + Vector3(4.5, 3.0, 5.0), here + Vector3(0, 0.7, 0), 0.35)
	swinger.queue_free()
	await clear()
	# The profession choice: the Adorer still to be earned.
	Game.earned_specs.erase("adorer")
	ascendant(-1, false, here)
	p.points = 4
	for step in 3:
		p.choose_ability(step, 0)
	var tree := TreePanel.new()
	tree.theme = UiTheme.make()
	tree.player = p
	canvas.add_child(tree)
	tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.build()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ascendant_professions.png"))
	tree.queue_free()
	hud.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
