extends Node
## Stage 6 of The Sunken Crown as players will see it: the Store's scenes for the nine Class Upgrades of
## the Adept, the Cartographer and the Bandit and for the Trappers' Guild, those upgrades at work in a
## night, and the Guild at Level 4 in the Valleys of Mesenlla (snare lines, the hunters on the towers,
## the fallback camp at the Ring of Stones, a creature caught).
##     godot --path . res://tests/crown_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D
var p: Player

const IDS := ["encore", "shattered_mirror", "event_horizon", "star_shower", "open_door", "trailblazer", "lucky_fingers", "contract", "toll_road", "trappers_guild"]


func snap(label: String, wait := 0.3) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func shot(label: String, from: Vector3, toward: Vector3, wait := 0.3) -> void:
	cam.global_position = from
	cam.look_at(toward)
	await snap(label, wait)


func ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	await _store()
	await _valleys()
	await _in_play()
	await _screens()
	await preload("res://tests/scene_cleanup.gd").finish(self)


## The Store's scenes, a still of each at four moments.
func _store() -> void:
	var board := Control.new()
	add_child(board)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.07)
	backdrop.size = Vector2(1280, 720)
	board.add_child(backdrop)
	var views: Array[ModelView] = []
	for i in IDS.size():
		var cell := Control.new()
		cell.position = Vector2(i % 4 * 320, i / 4 * 240)
		board.add_child(cell)
		var view := ModelView.new(Vector2(310, 210))
		cell.add_child(view)
		view.show_item(IDS[i])
		views.append(view)
		var label := Label.new()
		label.text = ShopDefs.ITEMS[IDS[i]]["name"]
		label.position = Vector2(10, 212)
		cell.add_child(label)
	await get_tree().process_frame
	for at: float in [0.7, 1.3, 2.0, 2.6, 3.1]:
		for view in views:
			for scene: Node in view.find_children("*", "UpgradeShowcase", true, false):
				(scene as UpgradeShowcase).clock = at
				(scene as UpgradeShowcase)._process(0.0)
				(scene as UpgradeShowcase).set_process(false)
		await snap("crown_store_%.1f" % at, 0.15)
	board.queue_free()
	await get_tree().process_frame


func _world(mode: int, map: String, cls: String) -> void:
	if w:
		w.queue_free()
		await get_tree().process_frame
	Game.night_map = map
	Game.player_class = cls
	Game.mode = mode
	w = World.new()
	add_child(w)
	w.setup(mode)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	p = w.player
	p.set_physics_process(false)
	p.set_process(false)
	p.camera.current = false
	cam = Camera3D.new()
	cam.fov = 62.0
	w.add_child(cam)
	cam.current = true


## The Valleys with the Guild at Level 4: what each level puts in the night.
func _valleys() -> void:
	await _world(Game.Mode.NIGHT, "mesenlla", "ranger")
	w._apply_sky(0.0)
	if w.guild:
		w.guild.queue_free()
	w.guild = TrappersGuild.new(w, 4)
	w.add_child(w.guild)
	w.prepare_allies("lodge_hunter", 4)
	await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout
	p.global_position = ground(0, 60)
	await shot("guild_south_snares", ground(-4, 4, 3.0), ground(2, -10, 0.2))
	await shot("guild_west_snares", ground(-31, -38, 2.6), ground(-27.5, -29, 0.2))
	await shot("guild_road_snares", ground(-38, -38, 3.0), ground(-45, -45, 0.3))
	# The hunters on the camp's towers.
	var hunters := w.allies.filter(func(a: Ally) -> bool: return a.kind == "lodge_hunter" and not a.dead)
	print("hunters: ", hunters.size(), " perched: ", hunters.filter(func(a: Ally) -> bool: return a.perch != Vector3.INF).size())
	await shot("guild_tower_hunter", ground(4, -8, 4.5), ground(8, -16, 6.5))
	if not hunters.is_empty():
		var h: Ally = hunters[0]
		await shot("guild_hunter_close", h.global_position + Vector3(2.2, 1.3, 2.6), h.global_position + Vector3.UP * 1.1)
	# A creature walks into a snare on the south side and is caught.
	var line := w.guild.snares.filter(func(s: Dictionary) -> bool: return not s["camp"] and float((s["at"] as Vector3).z) > -12.0)
	if not line.is_empty():
		var snare: Vector3 = line[2]["at"]
		var made := false
		for id: String in ZombieDefs.ALL.keys():
			if not made and not ZombieDefs.ALL[id].get("flies", false) and not ZombieDefs.ALL[id].get("boss", false):
				made = w.spawn_zombie(id, snare + Vector3(0, 0, 1.0))
		var z: Zombie = w.zombies.back()
		print("caught kind ", z.type_id)
		z.position = snare
		z.stun(30.0)
		for i in 20:
			await get_tree().physics_frame
		print("caught: ", z.root_left > 0.0, " hp ", z.hp)
		await shot("guild_snare_caught", snare + Vector3(2.4, 1.5, 3.0), snare + Vector3.UP * 0.6, 0.15)
	# The fallback camp at the Ring of Stones, its hunters and its ring of snares.
	var c := w.guild.camp_at
	await shot("guild_fallback_camp", c + Vector3(7, 4, 7), c + Vector3(-2, 0.5, -2), 0.5)
	await shot("guild_camp_close", c + Vector3(3.5, 1.8, 3.0), c + Vector3(0, 0.6, 0))
	await shot("guild_stones_overview", ground(-30, -40, 22.0), ground(-50, -60, 0.0))
	# Level 3: a cache by the fire.
	w.director.elapsed = TrappersGuild.CACHE_EVERY + 1.0
	await get_tree().create_timer(0.2).timeout
	var cache := w.guild.cache_spot()
	await shot("guild_cache", cache + Vector3(2.0, 1.4, 2.2), cache + Vector3.UP * 0.2)
	# The camp is lost: the towers' hunters come down and fall back to the Ring of Stones.
	w.fall_camp(Vector3(0, w.ground_at(Vector3(0, 0, -32)), -32), CampSiege.RADIUS)
	await get_tree().create_timer(0.3).timeout
	hunters = w.allies.filter(func(a: Ally) -> bool: return a.kind == "lodge_hunter" and not a.dead)
	print("after the fall, perched: ", hunters.filter(func(a: Ally) -> bool: return a.perch != Vector3.INF).size(), " cache spot ", w.guild.cache_spot())


func _foe(at: Vector3, face: Vector3) -> Zombie:
	w.spawn_zombie("normal", at)
	var z: Zombie = w.zombies.back()
	z.position = at
	z.hp = 5000.0
	z.max_hp = 5000.0
	z.look_at(Vector3(face.x, at.y, face.z), Vector3.UP, true)
	z.stun(30.0)
	return z


func _as(cls: String, spec: int, at: Vector3) -> void:
	p.class_id = cls
	p.points = 9
	p.level = 5
	p.chosen.clear()
	p.flags.clear()
	p.mods = Player.BASE_MODS.duplicate()
	p.spec_id = ""
	for step in 4:
		p.choose_ability(step, spec if step == 3 else 0)
	p.global_position = at
	p.yaw = 0.0
	p.rotation.y = 0.0


## The upgrades at work, in the Sandbox.
func _in_play() -> void:
	await _world(Game.Mode.SANDBOX, "village", "adept")
	w._apply_sky(1.0)
	for id: String in IDS:
		Game.owned_items[id] = true
	var at := ground(-4, 12)
	# Event Horizon: the rift a Void Walker leaves, drawing three in.
	_as("adept", 2, at)
	for k in 3:
		_foe(at + Vector3(cos(k * 2.1) * 4.5, 0, sin(k * 2.1) * 4.5), at)
	p._left_void()
	for i in 50:
		await get_tree().physics_frame
	await shot("play_event_horizon", at + Vector3(6, 4.5, 7), at + Vector3.UP * 0.8, 0.1)
	for z: Zombie in w.zombies.duplicate(): z.release()
	await get_tree().create_timer(3.5).timeout
	# Shattered Mirror: the shards in flight.
	_as("adept", 1, at)
	for k in 3:
		_foe(at + Vector3(-5 + k * 5, 0, -7), at)
	p._last_hit = 10.0
	p._last_hit_left = 1.0
	p._undo_hit()
	for i in 4:
		await get_tree().physics_frame
	await shot("play_shattered_mirror", at + Vector3(3, 2.2, 3.5), at + Vector3(0, 1.0, -5), 0.0)
	for z: Zombie in w.zombies.duplicate(): z.release()
	# Contract: the seal over the toughest inside a Nightfall.
	_as("bandit", 1, at)
	var big := _foe(at + Vector3(2, 0, -3), at)
	big.max_hp = 9000.0
	_foe(at + Vector3(-2.5, 0, -2), at)
	BanditKit.nightfall(p)
	await get_tree().create_timer(0.5).timeout
	await shot("play_contract", at + Vector3(-4, 3.0, 6), big.position + Vector3.UP * 1.5)
	for z: Zombie in w.zombies.duplicate(): z.release()
	for n: Node in w.get_children():
		if n is NightfallDome:
			n.queue_free()
	# Trailblazer: the stakes along the way.
	_as("cartographer", 2, at)
	for k in 6:
		w.spawn_path_field(p.net_id(), "blaze", at + Vector3(k * 3.0, 0, -k * 1.2))
	await get_tree().create_timer(0.4).timeout
	await shot("play_trailblazer", at + Vector3(-3, 2.6, 5), at + Vector3(8, 0.3, -3))
	# Toll Road: the gold knives of the Toll in flight.
	_as("bandit", 2, at)
	p.camera.rotation = Vector3.ZERO
	_foe(at + Vector3(0, 0, -12), at)
	p.fans_thrown = 2
	BanditKit.dagger_fan(p)
	for i in 6:
		await get_tree().physics_frame
	await shot("play_toll_road", at + Vector3(2.5, 2.4, 2.5), at + Vector3(0, 1.2, -8), 0.0)


## The screens: the Store's page for an upgrade and for the Guild, the Armory's Map Upgrades with both
## owned, and the HUD's marks over the second button.
func _screens() -> void:
	if w:
		w.queue_free()
		w = null
		await get_tree().process_frame
	Game.player_name = "Mara"
	for c: String in ClassDefs.ALL:
		Game.unlocked[c] = true
	Game.doubloons = 5000
	for id: String in IDS:
		Game.owned_items.erase(id)
	var m := Main.new()
	add_child(m)
	await get_tree().create_timer(0.4).timeout
	m.show_store("event_horizon", -1, "upgrades")
	await snap("screen_store_upgrade", 0.6)
	m.show_store(TrappersGuild.ID, -1, "maps")
	await snap("screen_store_guild", 0.6)
	Game.owned_items["mist_reinforcements"] = true
	Game.owned_items[TrappersGuild.ID] = true
	m.show_armory("maps")
	await snap("screen_armory_maps", 0.5)
	Game.player_class = "bandit"
	Game.owned_items["toll_road"] = true
	await m.start_game(Game.Mode.NIGHT)
	m.world.director.running = false
	var pl := m.world.player
	pl.grant_all_points()
	for step in 4:
		pl.choose_ability(step, 2 if step == 3 else 0)
	pl.fans_thrown = 2
	await snap("screen_hud_toll", 0.5)
	await preload("res://tests/scene_cleanup.gd").finish(m)