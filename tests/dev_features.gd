extends Node
var checks := 0
var failures := 0
var w: World
var p: Player
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	seed(38142)
	Game.quality = 0
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "heavy"
	Game.night_map = "village"
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	p = w.player
	p.set_physics_process(false)
	p.position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.guard_left = 0
	await _ui_initialization()
	_codex_and_concealment()
	_prices()
	_store_upgrades()
	_heavy()
	await _snakes()
	await _wood_and_gates()
	await _traversal()
	_music_and_polish()
	await _after_0212()
	await _beyond_weapons()
	await _together_store_and_dawn()
	await _maps_weather_and_balance()
	await _requests_1116()
	await _feedback_and_numbers()
	await _wilds_of_mesenlla()
	_text_audit()
	Net.leave()
	w.queue_free()
	await frames(2)
	Sfx.stop_all()
	OS.delay_msec(120)
	await get_tree().create_timer(0.15).timeout
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
func _prices() -> void:
	check(ClassDefs.price("monk") == 920 and ClassDefs.price("artificer") == 598, "both original Store classes cost exactly 15% more")
	# Adept is back: sold again, offered to those who own it, and its code opens it.
	var had_adept := Game.unlocked.has("adept")
	var had_class := Game.player_class
	Game.unlocked.erase("adept")
	check(not ClassDefs.disabled("adept") and ClassDefs.for_sale().has("adept") and ClassDefs.price("adept") == 1150, "Adept is in the Store again, for 1,150")
	Game.doubloons = 5000
	check(Game.buy_class("adept") and Game.doubloons == 3850 and Game.owns_class("adept"), "and can be bought")
	check(CodexPanel.acquisition("adept") != "Not available at this time.", "the Codex no longer says it is unavailable")
	check(ClassDefs.available().has("adept"), "a phone that owns it can pick it")
	Game.player_class = "adept"
	Game.save_settings()
	Game.load_settings()
	check(Game.player_class == "adept", "a saved Adept choice stays Adept")
	check(Net.class_slot_available("adept", 1), "and it can be taken in a game together")
	Game.player_class = had_class
	if not had_adept:
		Game.unlocked.erase("adept")
	Game.save_settings()
	check(MistStorm.GAP <= 15.0 and MistStorm.TWO_FROM <= 360.0, "Mist Storms follow each other closely, and two can rage at once later in the night")
func _heavy() -> void:
	Game.owned_items["oathkeeper"] = true
	p.spec_id = "guardian"
	p.mods["dodge"] = 0.0
	p.hp = p.max_hp()
	for i in 9: p.hurt(1.0, p.position + Vector3.FORWARD * 3)
	check(p.oath_reserve == 20, "Oathkeeper caps its reserve even under repeated blocked attacks")
	p.hp = p.max_hp() - 50
	w.spawn_ally("ghost", p.position + Vector3.RIGHT * 2, 20)
	var ally: Ally = w.allies.back()
	ally.set_physics_process(false)
	ally.hp = 50
	p.raise_dome()
	check(p.oath_reserve == 0 and is_equal_approx(p.hp, p.max_hp() - 30), "Dome spends its healing reserve exactly once")
	check(ally.hp == 70 and ally.guarded > 0, "Oathkeeper mends and protects a nearby summon")
	var old := p.hp
	p.raise_dome()
	check(p.hp == old, "an empty reserve does not repeat its healing")
	p.flags.clear()
	p.guard_left = 0
	p.dome_left = 0
	p.hp = p.max_hp() - 30
	var at := p.position + Vector3.FORWARD * 3
	w.spawn_zombie("normal", at + Vector3.RIGHT)
	var enemy: Zombie = w.zombies.back()
	enemy.set_physics_process(false)
	enemy.hp = 1000
	HeavyArts.last_rites(p, at)
	check(p.hp == p.max_hp() - 20 and enemy.burn_time > 0, "Last Rites mends nearby allies and ignites nearby enemies")
	p.position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.rotation.y = 0
	p.head.rotation.x = 0
	enemy.position = p.position + Vector3.FORWARD * 8
	enemy.hp = 1000
	var before := enemy.hp
	HeavyArts.faultline(p)
	check(enemy.hp < before and enemy._slow > 0, "Faultline reaches and slows enemies beyond melee range")
	w.spawn_zombie("normal", p.position + Vector3(4, 0, -7))
	var side: Zombie = w.zombies.back()
	side.set_physics_process(false)
	side.hp = 1000
	HeavyArts.faultline(p)
	check(side.hp == 1000, "Faultline does not damage enemies beside its corridor")
	var tree: Dictionary = AbilityData.tree("heavy")
	var quake: Dictionary = tree["specs"][2]["final"]["on"][0]
	check(quake["when"] == "melee_swing", "Earthbreaker counts connecting swings rather than each victim")
	w.remove_ally(ally)
	for z: Zombie in w.zombies.duplicate(): z.release()
func _snakes() -> void:
	w.spawn_ally("snake", p.position + Vector3.RIGHT * 3, 20)
	var snake: Ally = w.allies.back()
	snake.set_physics_process(false)
	check(snake._snake != null and snake._legs.is_empty(), "a legless snake has its own body animator")
	snake._move_wolf(0.1, true)
	snake._snake._process(0.2)
	check(snake._snake.motion > 0 and snake._snake.look.get_shader_parameter("phase") > 0, "movement drives a travelling snake body wave")
	snake._attack_left = 0.25
	snake._move_wolf(0.1, false)
	snake._snake._process(0.1)
	check(snake._snake.bite > 0, "snake bites animate their head strike")
	w.remove_ally(snake)
	w.spawn_ally("snake", p.position, 20)
	snake = w.allies.back()
	snake.set_physics_process(false)
	check(not snake.net_biting and snake._snake.bite == 0, "a reused snake does not inherit an old attack pose")
	w.remove_ally(snake)
	var b := PackedByteArray()
	b.resize(10)
	b.encode_u8(0, 77)
	b.encode_u8(1, Ally.KINDS.find("snake") | 128)
	b.encode_s16(2, 300)
	b.encode_s16(4, 0)
	b.encode_s16(6, 3600)
	w.net_remote_allies(91, b)
	var remote: Ally = w._remote_allies["91:77"]
	remote.set_physics_process(false)
	remote._physics_process(0.016)
	check(remote.kind == "snake" and remote.net_biting and remote._snake.biting, "remote snake packets preserve both the species and bite animation")
	w.forget_peer_allies(91)
	await frames(2)
func _wood_and_gates() -> void:
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var fw := World.new()
	space.add_child(fw)
	fw.setup(Game.Mode.FORT)
	fw.director.running = false
	fw.player.set_physics_process(false)
	for z: Zombie in fw.zombies.duplicate(): z.release()
	for item: Pickup in fw.pickups.duplicate(): fw.remove_pickup(item)
	check(fw.forest_wood_spots.size() > 20, "Fort has many reachable woodland supply sites")
	var failures_before := failures
	for sample in 80:
		fw.stock_wood()
		check(fw.pickups.size() == 1, "one firewood bundle spawns per stock operation")
		for item: Pickup in fw.pickups.duplicate():
			for gate: Dictionary in fw.fort.gates:
				check(Vector2(item.position.x - gate["at"].x, item.position.z - gate["at"].z).length() >= World.WOOD_NEAR_GATE_CLEARANCE, "firewood stays out of every gateway")
			check(not fw.fort.inside(item.position) and fw.grid.is_free(fw.grid.to_cell(item.position)), "firewood stands on traversable ground outside the fort")
			fw.remove_pickup(item)
	check(failures == failures_before, "the wood policy holds across repeated replenishment")
	check(fw.near_wood_spots.size() > 40 and fw.field_wood_spots.size() > 40, "there is room for wood by the walls (%d) and out in the field (%d)" % [fw.near_wood_spots.size(), fw.field_wood_spots.size()])
	# The labels lie flat on the wall above each gateway, reading outwards and inwards.
	for g: Dictionary in fw.fort.gates:
		var outer: Label3D = g["requirement"]
		var inner: Label3D = g["inner_requirement"]
		var dir: Vector3 = g["dir"]
		check(outer.billboard == BaseMaterial3D.BILLBOARD_DISABLED and outer.global_basis.z.dot(dir) > 0.99 and inner.global_basis.z.dot(-dir) > 0.99, "gate %d's wood labels face out and in" % g["i"])
		var off: float = (outer.global_position - (g["at"] as Vector3)).dot(dir)
		check(off > Fort.WALL_T * 0.5 and off < Fort.WALL_T * 0.5 + 0.2 and outer.global_position.y > Fort.GATE_H and outer.global_position.y < Fort.WALL_H, "gate %d's label sits on the wall face above the gateway" % g["i"])
	# Zombies are sent evenly against the four gates, and rise on their gate's side.
	fw.director.running = false
	var per_gate := [0, 0, 0, 0]
	var on_side := 0
	var risen := 0
	for k in 40:
		if not fw.spawn_zombie("normal"):
			continue
		var z: Zombie = fw.zombies.back()
		risen += 1
		per_gate[z.fort_gate] += 1
		var d: Vector3 = Fort.DIRS[z.fort_gate]
		if Vector2(z.position.x, z.position.z).normalized().dot(Vector2(d.x, d.z)) > 0.6:
			on_side += 1
	check(risen >= 8 and per_gate.max() - per_gate.min() <= 1, "zombies are split evenly across the gates: %s" % str(per_gate))
	check(on_side >= risen - 1, "and rise on their own gate's side (%d of %d)" % [on_side, risen])
	# A breach at one gate draws only the zombies sent there, and about a quarter of the rest.
	var west: Dictionary = fw.fort.gates[3]
	west["hp"] = 0.0
	fw.fort._set_closed(west, false)
	var diverted := 0
	var others := 0
	for z: Zombie in fw.zombies:
		if z.fort_gate == 3:
			continue
		others += 1
		if fw.fort.gate_for(z)["i"] == 3:
			diverted += 1
	check(diverted <= others * 0.5, "an open gate does not pull the whole horde (%d of %d)" % [diverted, others])
	for z: Zombie in fw.zombies.duplicate(): z.release()
	west["hp"] = Fort.GATE_HP
	fw.fort._set_closed(west, true)
	var gate: Dictionary = fw.fort.gates[0]
	gate["hp"] = 770.0
	fw.fort._show_gate(gate)
	check((gate["requirement"] as Label3D).text == "3 WOOD\nto repair" and (gate["inner_requirement"] as Label3D).visible, "both gate faces show the correct repair cost")
	gate["hp"] = Fort.GATE_HP
	fw.fort._show_gate(gate)
	check(not (gate["requirement"] as Label3D).visible, "a fully repaired gate hides its requirement")
	gate["hp"] = Fort.GATE_HP * 0.5
	fw.fort._set_closed(gate, false)
	fw.player.position = gate["at"]
	fw.fort.repair(0, 100)
	check(not gate["closed"], "a repaired gate cannot close on a player in its doorway")
	fw.player.position = Vector3.ZERO
	fw.fort._process(0)
	check(gate["closed"], "the gate closes once its doorway is clear")
	# Bots use player-sized side doors even though the shared enemy grid blocks them.
	var info := {"name": "Woodrunner", "class": "infantry", "team": 0}
	var body := Avatar.new(fw, Net.BOT_BASE + 90, info)
	fw.add_child(body)
	var bot := BotPlayer.new(fw, body, info)
	fw.add_child(bot)
	await frames(3)
	bot.set_physics_process(false)
	bot.pawn.set_physics_process(false)
	bot.pawn.position = Vector3(15, 0.05, -20)
	for goal: Vector3 in [Vector3(15, 0, -52), Vector3(15, 0, -20)]:
		bot._goal = goal
		bot._has_goal = true
		bot._repath = 0.0
		bot._fort_cross = Vector3.INF
		for tick in 700:
			if Vector2(bot.pawn.position.x - goal.x, bot.pawn.position.z - goal.z).length() < 1.2: break
			var dir := bot._walk_dir(0.016)
			bot.pawn.velocity = dir * 8 + Vector3.DOWN * 3
			bot.pawn.move_and_slide()
			await frames(1)
		check(Vector2(bot.pawn.position.x - goal.x, bot.pawn.position.z - goal.z).length() < 1.5, "a wood-gathering bot traverses the side door to %s (ended %s)" % [goal, bot.pawn.position])
	space.queue_free()
	await frames(2)

func _walk_surface(pawn: Player, from: Vector3, toward: Vector3, label: String) -> void:
	pawn.position = from + Vector3.UP * 0.25
	var direction := Vector3(toward.x - from.x, 0, toward.z - from.z).normalized()
	for tick in 900:
		if Vector2(pawn.position.x - toward.x, pawn.position.z - toward.z).length() < 0.8: break
		pawn.velocity = direction * 6 + Vector3.DOWN * 4
		pawn.move_and_slide()
		await frames(1)
	check(Vector2(pawn.position.x - toward.x, pawn.position.z - toward.z).length() < 1.0 and pawn.position.y > toward.y - 1.0, label + " ended " + str(pawn.position))

func _traversal() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	add_child(viewport)
	Game.night_map = "mists"
	var mist := World.new()
	viewport.add_child(mist)
	mist.setup(Game.Mode.NIGHT)
	mist.director.running = false
	for z: Zombie in mist.zombies.duplicate(): z.release()
	var pawn := mist.player
	pawn.set_physics_process(false)
	await frames(3)
	for ramp: Array in MapIslands.RAMPS:
		await _walk_surface(pawn, ramp[0], ramp[1], "ascending shelf ramp")
		await _walk_surface(pawn, ramp[1], ramp[0], "descending shelf ramp")
	for shrine: Array in MapIslands.ROTUNDAS:
		var centre: Vector2 = shrine[0]
		for n in 4:
			var dir := Vector2(cos(n * PI / 2), sin(n * PI / 2))
			var at := centre + dir * (float(shrine[1]) + 4)
			var from := Vector3(at.x, mist.ground_at(Vector3(at.x, 0, at.y)), at.y)
			await _walk_surface(pawn, from, Vector3(centre.x, float(shrine[3]) + MapIslands.ROTUNDA_RISE, centre.y), "open shrine approach")
	for pair: Array in MapIslands.JOINED:
		var from: Vector4 = MapIslands.ISLANDS[pair[0]]
		var to: Vector4 = MapIslands.ISLANDS[pair[1]]
		var start := mist.grid.to_world(mist.grid.nearest_free(mist.grid.to_cell(Vector3(from.x, 0, from.y))))
		var end := mist.grid.nearest_free(mist.grid.to_cell(Vector3(to.x, 0, to.y)))
		check(mist.grid.flood(start).has(end), "bots and mobs can traverse joined islands %s" % str(pair))
	check(mist.map_marks.size() >= MapIslands.ISLANDS.size(), "every Mists zone has a map label")
	viewport.queue_free()
	await frames(2)

func _store_upgrades() -> void:
	for id: String in ["oathkeeper", "last_rites", "faultline"]:
		check(ShopDefs.for_class("heavy").has(id), "Heavy upgrade is listed in the Store: " + id)
		Game.owned_items.erase(id)
		var price := int(ShopDefs.ITEMS[id]["price"])
		Game.doubloons = price - 1
		check(not Game.buy_item(id), "purchase rejects insufficient funds: " + id)
		Game.doubloons = price
		check(Game.buy_item(id) and Game.doubloons == 0, "purchase charges the exact upgrade price: " + id)
		Game.set_item_on(id, false)
		check(not Game.item_active(id), "Armory can disable " + id)
		Game.set_item_on(id, true)
		check(Game.item_active(id), "Armory can equip " + id)


## Each place has its own music, the menu its own theme, and homes are dressed without changing the way through.
func _music_and_polish() -> void:
	for set_name: String in Sfx.MUSIC_SETS:
		for stem: String in Sfx.MUSIC_SETS[set_name]:
			check(stem == "" or ResourceLoader.exists("res://assets/music/%s.ogg" % stem), "the %s music has its %s stem" % [set_name, stem])
	var was := Sfx.music_set
	Sfx.ambient(true)
	Sfx.use_music("fort")
	check(Sfx.music_set == "fort" and Sfx.music_is_playing() and (Sfx._music[0].stream as AudioStreamOggVorbis).resource_path.ends_with("fort_night.ogg"), "the Fort plays its own three stems")
	check(Sfx._music.all(func(p: AudioStreamPlayer) -> bool: return p.stream and (p.stream as AudioStreamOggVorbis).loop), "and all of them loop")
	Sfx.use_music("menu")
	check(Sfx._music[0].stream != null and Sfx._music[1].stream == null and Sfx._music[2].stream == null and Sfx.music_is_playing(), "the menu has one theme of its own")
	Sfx.use_music("nowhere")
	check(Sfx.music_set == "menu", "an unknown place keeps what is playing")
	var lengths: Array = []
	for stem: String in ["mists_night", "mists_hunted", "mists_dawn"]:
		lengths.append(snappedf((load("res://assets/music/%s.ogg" % stem) as AudioStream).get_length(), 0.01))
	check(lengths[0] == lengths[1] and lengths[1] == lengths[2], "the Mists stems are the same length, so they stay in step: %s" % str(lengths))
	Sfx.use_music(was)
	# Shelves keep clear of doors and windows, and of the corners.
	var gap := MapBuilder._longest_gap(8.0, [{"at": -1.0, "width": 2.2}, {"at": 2.6, "width": 1.1}])
	check(is_equal_approx(gap.x, 0.45) and is_equal_approx(gap.y, 1.7), "the longest bare stretch of an 8 m wall with a door and a window: %s" % str(gap))
	check(MapBuilder._longest_gap(6.0, []).is_equal_approx(Vector2(-2.45, 2.45)), "a bare wall keeps 55 cm from each corner")
	# A level gained shows a ring and motes, and an ability its class's colour.
	var rings_before := w._rings.filter(func(r: Dictionary) -> bool: return float(r["left"]) > 0.0).size()
	p.add_xp(p.xp_needed())
	check(w._rise != null and w._rise.emitting and w._rings.filter(func(r: Dictionary) -> bool: return float(r["left"]) > 0.0).size() > rings_before, "a level gained sends a ring and rising motes")



func _after_0212() -> void:
	# Late packets are dropped, not queued: each stream counts, and only newer counts are used.
	Net.leave()
	check(Net.fresh(["pose", 7], 10) and not Net.fresh(["pose", 7], 9) and not Net.fresh(["pose", 7], 10), "an older or repeated pose is ignored")
	check(Net.fresh(["pose", 7], 11) and Net.fresh(["pose", 8], 0), "a newer one, or another sender's, is used")
	check(Net.fresh(["snapshot"], 65535) and Net.fresh(["snapshot"], 65535, true) and Net.fresh(["snapshot"], 2), "parts of one snapshot all count, and counts wrap past 65535")
	check(not Net.fresh(["snapshot"], 65000, true), "a snapshot from before the wrap is still old")
	check(Net.next_seq("clock") == 0 and Net.next_seq("clock") == 1, "each stream counts on its own")
	Net.leave()
	check(Net.next_seq("clock") == 0, "and starts again with a new game")
	check(Net.SNAPSHOT_CHUNK * 12 + 64 < 1170, "a snapshot part fits one Epic packet with room for its header")
	# The drop button: up top, away from the fighting thumb, and it needs a held press.
	var hud := Hud.new()
	add_child(hud)
	hud.player = p
	hud.size = Vector2(1280, 720)
	hud._layout()
	var drop: Vector2 = hud._buttons["drop"]["pos"]
	check(drop.y < 100.0 and drop.distance_to(hud._buttons["fire"]["pos"]) > 300.0 and drop.distance_to(hud._buttons["switch"]["pos"]) > 250.0, "the drop button sits in the top row, far from Attack and Switch")
	p.set_physics_process(false)
	p.slots = ["mace", "sword"]
	p.current = 1
	p._equip()
	var can_drop := p.can_drop_weapon()
	hud._touch_down(5, drop)
	hud._process(0.2)
	check(p.slots[1] == "sword", "a short press does not drop the weapon")
	hud._process(0.4)
	check(not can_drop or p.slots[1] == null, "holding it half a second does")
	hud._touch_up(5)
	hud.queue_free()
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	# Each player's health and countdown, for the list in a game together.
	var state := Net.player_state(Net.my_id())
	check(state.has("hp") and state.has("down") and state.has("back_in"), "the player list knows your health and state")
	var info := {"name": "Ally", "class": "ranger", "team": 0}
	var other := Avatar.new(w, 4242, info)
	w.add_child(other)
	Net._avatars[4242] = other
	other.hp_fraction = 0.4
	check(is_equal_approx(float(Net.player_state(4242)["hp"]), 0.4) and not Net.player_state(4242)["down"], "and another player's health")
	other.set_fallen(true)
	other.down_since = w.now - 5.0
	var back: float = Net.player_state(4242)["back_in"]
	check(Net.player_state(4242)["down"] and back > 14.0 and back <= 15.0, "and when they are down, how long until they are back (%.1f)" % back)
	Net._avatars.erase(4242)
	other.queue_free()
	await frames(1)

func _ui_initialization() -> void:
	for item: Pickup in w.pickups.duplicate():
		if item.kind == Pickup.Kind.WEAPON: w.remove_pickup(item)
	w.spawn_pickup_at(p.position + Vector3.RIGHT, Pickup.Kind.WEAPON, "sword")
	var loose_weapon: Pickup = w.pickups.back()
	check(w.nearest_weapon_pickup(p.position, 100.0) == loose_weapon, "Clever search finds a nearby reachable weapon on maps without portals")
	w.remove_pickup(loose_weapon)
	var insets := UiTheme.safe_insets(Vector2i(1920, 1080), Rect2i(160, 20, 1680, 1020), Vector2(1280, 720), 24, 16)
	check(insets[0] >= 127 and insets[1] >= 74 and insets[2] >= 30 and insets[3] >= 43, "safe-area conversion protects all four edges in viewport units")
	var flipped := UiTheme.safe_insets(Vector2i(1920, 1080), Rect2i(80, 20, 1680, 1020), Vector2(1280, 720), 24, 16)
	check(flipped[1] > flipped[0], "rotating the notch to the opposite side swaps the protected horizontal inset")
	var margin := MarginContainer.new()
	UiTheme.fit_safe_area(margin, 32, 18)
	add_child(margin)
	await frames(2)
	check(margin.get_theme_constant("margin_left") >= 32 and margin.get_theme_constant("margin_top") >= 18, "safe-area margins bind after entering the tree")
	margin.queue_free()
	var avatar := Avatar.new(w, 7654, {"class": "infantry", "name": "Test"})
	w.add_child(avatar)
	avatar.apply_pose(p.position, 0, 0, Vector3.ZERO, 1, 0, 17, "sword", 1)
	check(avatar._attack_left <= 0, "first pose seeds the attack counter without playing a phantom swing")
	avatar.apply_pose(p.position, 0, 0, Vector3.ZERO, 1, 0, 18, "sword", 1)
	check(avatar._attack_left > 0, "subsequent attack counter changes still animate")
	avatar._flash = 0.1
	avatar._set_flash(true)
	avatar._ice_left = 1.0
	avatar._show_ice(true)
	avatar._flash = 0.0
	avatar._set_flash(false)
	var ice_preserved := true
	for part: MeshInstance3D in avatar._visual.find_children("*", "MeshInstance3D", true, false):
		if part.material_override != Avatar._ice_look(): ice_preserved = false
	check(ice_preserved, "ending a hit flash preserves a still-active freeze visual")
	avatar.set_fallen(true)
	avatar.set_fallen(false)
	var restored := true
	for part: MeshInstance3D in avatar._visual.find_children("*", "MeshInstance3D", true, false):
		if part.has_meta("status_base") and part.material_override != part.get_meta("status_base"): restored = false
	check(restored, "death and respawn restore base materials after overlapping status visuals")
	avatar.queue_free()
	for entry: Dictionary in StatusCatalog.TIMED:
		for glyph: String in entry["icon"].split("+"): check(Icons.exists(glyph), "status glyph exists: " + glyph)
		p.set(entry["field"], 2.5)
		var found := false
		for effect: Dictionary in p.status_effects():
			# Being mended lasts as long as the mending, so it shows no count, only that it is happening.
			if is_equal_approx(float(effect["left"]), 2.5) or (entry["field"] == "friend_heal_left" and effect["icon"] == entry["icon"] and effect["left"] < 0.0): found = true
		check(found, "temporary status exposes a duration: " + entry["name"])
		p.set(entry["field"], 0.0)
	w._warmed_quality = -1
	await w.warm_up()
	var clear := true
	for puddle: MeshInstance3D in w._puddles:
		if puddle.visible: clear = false
	for gore: CPUParticles3D in w._gore:
		if gore.visible or gore.emitting: clear = false
	check(clear, "warm-up leaves no visible puddles or phantom blood")

func _codex_and_concealment() -> void:
	var was := p.class_id
	p.class_id = "magician"
	for id: String in WeaponDefs.ALL:
		var one_handed_melee: bool = WeaponDefs.ALL[id]["kind"] == WeaponDefs.Kind.MELEE and not WeaponDefs.is_two_handed(id) and id != "bo" and WeaponDefs.ALL[id].get("only", "") == "" and WeaponDefs.ALL[id].get("spec", "") == ""
		check(p.can_use(id) == (id == "staff" or one_handed_melee), "Magician accepts its Staff and one-handed melee weapons only: " + id)
	p.class_id = was
	p.invis_left = 4.0
	p.input_fire = false
	p._handle_fire()
	check(p.invis_left == 4.0, "not attacking preserves invisibility")
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	check(p.invis_left == 0.0, "an actual attack breaks invisibility")
	p.input_fire = false
	check(CodexPanel.enemy_group("normal") < CodexPanel.enemy_group("hero_infantry") and CodexPanel.enemy_group("hero_infantry") < CodexPanel.enemy_group("veil_regent"), "Codex separates common enemies, fallen heroes and bosses")
	check(not "doubloons" in CodexPanel.acquisition("monk"), "Codex acquisition omits store prices")
	var shot := Projectile.new(w)
	w.add_child(shot)
	shot.launch(Projectile.Kind.ARROW, w._arrow_mesh, Vector3(0, 5, 0), Vector3.FORWARD, 0, 20, 1, 0, true)
	check(not shot._flame.visible and shot._arrow_aura.visible, "fire arrows use a narrow 3D tip, never the fireball sprite")
	shot.launch(Projectile.Kind.FIREBALL, w._fireball_mesh, Vector3(0, 5, 0), Vector3.FORWARD, 0, 20, 1)
	check(shot._flame.visible and not shot._arrow_aura.visible, "pooled fireballs reset the arrow effect")
	shot.queue_free()


## 0.22 step 1: Two-Handed weapons, the Greatsword, the Mesenlla weapons, tags and the 3 s reveal.
func _beyond_weapons() -> void:
	for id: String in ["bell_hammer", "pitchfork", "scythe", "greatsword", "battleaxe"]:
		check(WeaponDefs.category(id) == "two_handed", "%s is a Two-Handed weapon" % id)
	check(WeaponDefs.category("sword") == "melee" and WeaponDefs.category("chakram") == "ranged" and WeaponDefs.category("lance") == "exclusive" and WeaponDefs.category("bo") == "exclusive", "the other groups")
	var expect := {"infantry": ["melee", "two_handed", "ranged"], "ranger": ["melee", "ranged"], "heavy": ["melee"], "chivalry": ["melee", "two_handed", "exclusive"],
		"magician": ["melee", "exclusive"], "revenant": ["exclusive"], "monk": ["melee", "two_handed", "ranged", "exclusive"], "adept": ["melee", "two_handed"],
		"plague_doctor": ["melee", "ranged", "exclusive"], "artificer": ["melee", "two_handed", "ranged"], "commander": ["melee", "two_handed", "ranged", "exclusive"]}
	for id: String in expect:
		check(ClassDefs.weapon_categories(id) == Array(expect[id], TYPE_STRING, "", null), "%s wields %s (got %s)" % [id, str(expect[id]), str(ClassDefs.weapon_categories(id))])
	var cls := p.class_id
	for id: String in ["infantry", "chivalry", "monk", "adept", "artificer", "commander"]:
		p.setup_class(id)
		check(p.can_use("greatsword") and p.can_use("scythe"), "%s can wield Two-Handed weapons" % id)
	for id: String in ["ranger", "heavy", "plague_doctor"]:
		p.setup_class(id)
		check(not p.can_use("greatsword") and not p.can_use("bell_hammer") and p.can_use("sword"), "%s cannot, and keeps its one-handed melee" % id)
	p.setup_class("ranger")
	check(p.can_use("chakram") and p.can_use("bow"), "ranged rules are unchanged")
	p.setup_class("magician")
	check(not p.can_use("greatsword") and not p.can_use("bow") and p.can_use("staff") and p.can_use("sword"), "the Magician holds its Staff and one-handed melee weapons, nothing two-handed or ranged")
	# Where they are found.
	check(SpawnRules.allows(WeaponDefs.ALL["greatsword"], "village") and SpawnRules.allows(WeaponDefs.ALL["greatsword"], "mists") and SpawnRules.allows(WeaponDefs.ALL["greatsword"], "mesenlla"), "the Greatsword lies on every map")
	for id: String in ["battleaxe", "chakram"]:
		check(not SpawnRules.allows(WeaponDefs.ALL[id], "village") and SpawnRules.allows(WeaponDefs.ALL[id], "mesenlla") and SpawnRules.allows(WeaponDefs.ALL[id], "bastion"), "%s only beyond the Mists" % id)
		check(SpawnRules.names(WeaponDefs.ALL[id]) == "Mesenlla", "%s's badge says Mesenlla" % id)
	for id: String in ["greatsword", "battleaxe", "chakram"]:
		check(WeaponDefs.mesh(id) != null and ResourceLoader.exists("res://assets/icons/%s.png" % Icons.weapon(id)) and Icons.weapon(id) == id, "%s has its own model and icon" % id)
	for sound: String in ["heavy_swing", "cleave", "chakram_throw", "chakram_hit"]:
		check(ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound) and Sfx.NAMES.has(sound), "%s sound" % sound)
	# The Battleaxe: every third blow in a row cleaves for double.
	p.setup_class("infantry")
	p.slots = ["battleaxe", null]
	p.current = 0
	p._equip()
	p.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	w.spawn_zombie("normal", p.global_position + Vector3(0, 0, -1.6))
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	var losses: Array[float] = []
	for i in 3:
		z.hp = 5000.0
		z.max_hp = 5000.0
		z.position = p.global_position + Vector3(0, 0, -1.6)
		p._do_melee_hit()
		losses.append(5000.0 - z.hp)
	check(losses[0] > 0.0 and is_equal_approx(losses[0], losses[1]) and absf(losses[2] - losses[0] * 2.0) < 1.0, "blows 1 and 2 are equal, the third does double (%s)" % str(losses))
	z.release()
	# The Rift Chakram ricochets.
	p.slots = ["chakram", null]
	p._equip()
	var row: Array[Zombie] = []
	for i in 4:
		w.spawn_zombie("normal", p.global_position + Vector3(i * 3.0 * (1 if i % 2 else -1) * 0.5, 0, -9.0 - i * 2.0))
		var zz: Zombie = w.zombies.back()
		zz.set_physics_process(false)
		zz.hp = 500.0
		row.append(zz)
	p._fire_arrow(p.weapon_def())
	var shot: Projectile = w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.spins).back()
	check(shot != null and shot.bounces >= 3, "a thrown chakram carries three ricochets")
	for i in 120:
		await get_tree().physics_frame
	var struck := row.filter(func(zz: Zombie) -> bool: return zz.hp < 500.0).size()
	check(struck >= 3, "and strikes several enemies in turn (%d)" % struck)
	for zz in row: zz.release()
	# The Rift Chakram's own throws: 20 with each one picked up, up to 40, one spent with each throw.
	p.slots = ["sword", null]
	p.current = 0
	p.own_ammo.clear()
	p._equip()
	var arrows_before := p.arrows
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	var fresh := w.spawn_pickup_at(p.global_position + Vector3(0.6, 0, 0), Pickup.Kind.WEAPON, "chakram")
	check(fresh.throws() == 20, "a Rift Chakram found lying about brings 20 throws")
	w._scan_pickups_for(p)
	check(p.carries("chakram") and p.ammo_of("chakram") == 20 and p.arrows == arrows_before, "picked up, it gives 20 throws and no arrows")
	w.spawn_pickup_at(p.global_position + Vector3(0.6, 0, 0), Pickup.Kind.WEAPON, "chakram")
	w._scan_pickups_for(p)
	check(p.ammo_of("chakram") == 40, "a second one adds 20 more (%d)" % p.ammo_of("chakram"))
	var third := w.spawn_pickup_at(p.global_position + Vector3(0.6, 0, 0), Pickup.Kind.WEAPON, "chakram")
	w._scan_pickups_for(p)
	check(p.ammo_of("chakram") == 40 and is_instance_valid(third) and w.pickups.has(third), "40 is the most: a third one stays on the ground")
	w.remove_pickup(third)
	p.current = p.slots.find("chakram")
	p._equip()
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(p.ammo_of("chakram") == 39 and p.arrows == arrows_before, "a throw spends one throw and no arrows")
	# The last throw: the Rift Chakram is gone, its slot empty, the other weapon in hand.
	p.own_ammo["chakram"] = 1
	var held_with: Variant = p.slots[1 - p.current]
	var chakram_slot := p.current
	p._cooldown = 0.0
	var before_last := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.spins).size()
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.spins).size() == before_last + 1, "the last throw still flies")
	check(not p.carries("chakram") and p.slots[chakram_slot] == null and not p.own_ammo.has("chakram") and p.weapon_id() == str(held_with), "and then the Rift Chakram is gone: its slot is empty and the %s is in hand (%s)" % [str(held_with), str(p.slots)])
	check(p.has_empty_slot() and not w.pickups.any(func(q: Pickup) -> bool: return q.weapon_id == "chakram"), "nothing is left on the ground, and the empty slot takes the next weapon")
	# Held with none left (it should not happen), it still will not throw.
	p.slots[chakram_slot] = "chakram"
	p.current = chakram_slot
	p._equip()
	p.own_ammo["chakram"] = 0
	p._cooldown = 0.0
	var thrown := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.spins).size()
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.spins).size() == thrown and p.toast == "No throws left", "with none left it cannot be thrown")
	# Put down, it keeps what it had: picking it up again gives nothing new.
	p.own_ammo["chakram"] = 7
	p.slots = ["chakram", "sword"]
	p.current = 0
	p._equip()
	p.drop_current_weapon()
	check(not p.carries("chakram") and p.ammo_of("chakram") == 0, "dropped, its throws go with it")
	var put_down: Pickup = w.pickups.filter(func(q: Pickup) -> bool: return q.weapon_id == "chakram").back()
	check(put_down.throws() == 7, "the Rift Chakram on the ground keeps its 7 throws (%d)" % put_down.throws())
	p.shun_weapon = ""
	p.global_position = put_down.global_position
	w._scan_pickups_for(p)
	check(p.carries("chakram") and p.ammo_of("chakram") == 7, "taken back, it has the same 7 (%d)" % p.ammo_of("chakram"))
	p.slots = ["sword", null]
	p.current = 0
	p.own_ammo.clear()
	p._equip()
	# Invisibility, then three seconds before the next.
	p.invis_left = 2.0
	check(p.invis_left > 0.0 and p.can_vanish(), "invisible")
	p.invis_left = 4.0
	check(is_equal_approx(p.invis_left, 4.0), "a running invisibility can be lengthened")
	p.invis_left = 0.0
	check(is_equal_approx(p.invis_lockout, Player.INVIS_LOCKOUT) and not p.can_vanish(), "coming out of it starts the 3 s reveal")
	p._act({"do": "invis", "secs": 5.0}, {})
	check(p.invis_left == 0.0, "nothing hides you during it")
	check(p.status_effects().any(func(e: Dictionary) -> bool: return e["icon"] == "eye+clock"), "the reveal shows on the effects row")
	p._tick_ability_timers(1.6)
	p._tick_ability_timers(1.5)
	p._act({"do": "invis", "secs": 5.0}, {})
	check(p.invis_left > 4.0, "after 3 s it works again")
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.setup_class(cls)
	# Weapon groups read the same on the class screen, the Armory and the Codex.
	var m := Main.new()
	add_child(m)
	await frames(2)
	var had_magician := Game.unlocked.has("magician")
	Game.unlocked["magician"] = true # the Armory shows a class's details only once it is yours
	for id: String in ["infantry", "magician"]:
		var want := ClassDefs.weapon_categories(id).map(func(c: String) -> String: return WeaponDefs.CATEGORY_NAMES[c])
		m.show_class_picker(Game.Mode.NIGHT)
		m._fill_class_detail(m.panel.get_meta("detail"), id, Game.Mode.NIGHT)
		check(_tag_texts(m.panel) == want, "class screen tags for %s: %s" % [id, str(_tag_texts(m.panel))])
		check(m.panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == ClassPresentation.stats_line(id)), "class screen stat line for %s" % id)
		m.show_armory(id)
		m._fill_armory(m.panel.get_meta("detail"), id)
		check(_tag_texts(m.panel) == want, "Armory tags for %s" % id)
		check(m.panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.begins_with(ClassPresentation.stats_line(id))), "Armory stat line for %s" % id)
	if not had_magician:
		Game.unlocked.erase("magician")
	var codex := CodexPanel.new()
	add_child(codex)
	codex._list = VBoxContainer.new()
	codex.add_child(codex._list)
	codex._classes()
	var codex_tags := codex._list.find_children("WeaponTags", "HFlowContainer", true, false)
	check(codex_tags.size() == ClassDefs.ALL.size(), "every class in the Codex has weapon tags")
	codex._list.queue_free()
	codex._list = VBoxContainer.new()
	codex.add_child(codex._list)
	codex._weapons()
	var texts := codex._list.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(texts.has("Two-Handed") and texts.has("Map Exclusive · Mesenlla") and texts.has("Greatsword"), "the Codex weapons show their group and the Mesenlla badge")
	codex.queue_free()
	m.queue_free()
	await frames(2)


func _tag_texts(root: Node) -> Array:
	var rows := root.find_children("WeaponTags", "HFlowContainer", true, false)
	if rows.is_empty():
		return []
	return (rows[0] as Node).find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


## Play Together, the multiplayer HUD, the Store's Cosmetics, the Bandit's second button and how a night
## opens and ends.
func _together_store_and_dawn() -> void:
	var m := Main.new()
	add_child(m)
	await frames(2)
	# The Store sells only what you do not own; what you buy is named once, then lives in the Armory.
	var saved_items := Game.owned_items.duplicate()
	var saved_off := Game.switched_off.duplicate()
	var saved_doubloons := Game.doubloons
	Game.owned_items.erase("stag_steed")
	check(ShopDefs.SECTIONS.has("cosmetics") and ShopDefs.in_section("cosmetics") == Array(["stag_steed"], TYPE_STRING, "", null), "the Store has a Cosmetics tab, with the White Stag in it")
	check(int(ShopDefs.ITEMS["stag_steed"]["price"]) == 400 and ShopDefs.whose("stag_steed") == "Chivalry, every path", "the White Stag costs 400 Doubloons and is for every Chivalry path")
	m.show_store("", -1, "cosmetics")
	await frames(2)
	var list: VBoxContainer = m.panel.get_meta("list")
	check(list.get_child_count() == 1 and m.panel.find_child("NothingLeft", true, false) == null, "with it unbought, the Cosmetics tab lists it")
	# A class you do not own: its Class Upgrades and cosmetics are shown, locked, and cannot be bought.
	var saved_unlocked := Game.unlocked.duplicate()
	Game.unlocked.erase("chivalry")
	Game.doubloons = 400
	check(Game.item_locked("stag_steed") and not Game.buy_item("stag_steed") and Game.doubloons == 400 and not Game.owns_item("stag_steed"), "without the Chivalry class, the White Stag cannot be bought")
	m.show_store("stag_steed", -1, "cosmetics")
	await frames(2)
	var locked_line := m.panel.find_child("ItemLocked", true, false) as Label
	check(locked_line != null and locked_line.text.contains("Chivalry") and locked_line.text.contains(Game.earn_text("chivalry")) and m.panel.find_child("SeeClass", true, false) == null, "the Store says so, and how the class is earned: %s" % (locked_line.text if locked_line else "nothing"))
	check(not (m.panel.find_children("*", "Button", true, false) as Array).any(func(b: Button) -> bool: return b.text == "Buy"), "and offers no Buy button")
	m.show_armory("chivalry")
	await frames(2)
	var armory_says := m.panel.find_child("UnlockRequirement", true, false) as Label
	check(armory_says != null and armory_says.text == Game.earn_text("chivalry") and m.panel.find_child("ToStore", true, false) == null, "the Armory, too, shows the class locked, and how it is earned")
	# A class that is bought: its locked Class Upgrades lead to it in the Store.
	var bought_class := ""
	for item: String in ShopDefs.ITEMS:
		var owner_class := str(ShopDefs.ITEMS[item]["class"])
		if owner_class != "" and ClassDefs.for_sale().has(owner_class) and ClassDefs.ALL[owner_class].get("hidden", false):
			bought_class = owner_class
			break
	var had_bought_class := Game.unlocked.has(bought_class)
	Game.unlocked.erase(bought_class)
	var its_item: String = ShopDefs.for_class(bought_class)[0]
	m.show_store(its_item, -1, str(ShopDefs.ITEMS[its_item]["section"]))
	await frames(2)
	var see_class := m.panel.find_child("SeeClass", true, false) as Button
	check(Game.item_locked(its_item) and see_class != null, "%s, locked, leads to the %s in the Store" % [its_item, bought_class])
	if see_class:
		see_class.pressed.emit()
		await frames(2)
		check(m.panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == ClassDefs.ALL[bought_class]["name"]), "which opens that class's page")
	m.show_armory(bought_class)
	await frames(2)
	var locked_page := m.panel.find_child("LockedClass", true, false)
	var requirement := m.panel.find_child("UnlockRequirement", true, false) as Label
	check(locked_page != null and requirement != null and requirement.text == m.armory_unlock_text(bought_class) and requirement.text.contains(str(ClassDefs.price(bought_class))), "in the Armory, a class you don't own is locked and says only how to unlock it: %s" % (requirement.text if requirement else "nothing"))
	check(m.panel.find_children("*", "ModelView", true, false).is_empty() and m.panel.find_child("CosmeticsSection", true, false) == null and not (m.panel.find_children("*", "Label", true, false) as Array).any(func(l: Label) -> bool: return l.text == ClassPresentation.COPY[bought_class][0]), "with nothing else of it shown: no model, description, paths or tabs")
	var to_store := m.panel.find_child("ToStore", true, false) as Button
	check(to_store != null, "and, sold in the Store, a button straight to it there")
	if to_store:
		to_store.pressed.emit()
		await frames(2)
		check(m.panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == ClassDefs.ALL[bought_class]["name"]) and (m.panel.find_children("*", "Button", true, false) as Array).any(func(b: Button) -> bool: return b.text == "Buy" or b.text.begins_with("Need ")), "which opens the class in the Store, to buy")
	var earned_class := ""
	for c: String in ClassDefs.ALL:
		if ClassDefs.ALL[c].has("earned") and not Game.owns_class(c):
			earned_class = c
			break
	if earned_class != "":
		m.show_armory(earned_class)
		await frames(2)
		var earned_req := m.panel.find_child("UnlockRequirement", true, false) as Label
		check(earned_req != null and earned_req.text == Game.earn_text(earned_class) and m.panel.find_child("ToStore", true, false) == null, "a class earned in play shows how to earn it, with no Store button (%s)" % earned_class)
	if had_bought_class:
		Game.unlocked[bought_class] = true
	Game.unlocked["chivalry"] = true
	check(not Game.item_locked("stag_steed") and not Game.item_locked("mist_reinforcements"), "with the class, it is for sale; a Map Upgrade belongs to no class")
	Game.doubloons = 399
	check(not Game.buy_item("stag_steed"), "399 Doubloons do not buy it")
	Game.doubloons = 400
	check(Game.buy_item("stag_steed") and Game.doubloons == 0, "400 do")
	m.show_store("", -1, "cosmetics", Callable(), "stag_steed")
	await frames(2)
	var bought := m.panel.find_child("JustBought", true, false) as Label
	check(bought != null and bought.text.contains("White Stag") and bought.text.contains("Armory"), "the Store says what was bought and where it went: %s" % (bought.text if bought else "nothing"))
	check(m.panel.find_child("NothingLeft", true, false) != null, "and, the tab now empty, that you own everything in it")
	check(m.panel.find_child("OpenArmory", true, false) != null, "with a way to the Armory")
	m.show_store("", -1, "cosmetics")
	await frames(2)
	check(m.panel.find_child("JustBought", true, false) == null, "the purchase line is shown once, not every time")
	for section: String in ShopDefs.SECTIONS:
		m.show_store("", -1, section)
		await frames(1)
		var names: Array = (m.panel.get_meta("list") as Node).find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		for id: String in ShopDefs.in_section(section):
			if Game.owns_item(id):
				check(not names.has(str(ShopDefs.ITEMS[id]["name"])), "an owned %s is not for sale in %s" % [id, section])
	m.show_armory("chivalry")
	await frames(2)
	check(m.panel.find_child("CosmeticsSection", true, false) == null, "the Armory opens on the paths")
	m.show_armory("chivalry", 1)
	await frames(2)
	var words: Array = m.panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(words.has("White Stag") and words.has("Brown Horse"), "its Appearance tab shows Chivalry's looks: the Brown Horse and the White Stag")
	var stage_scene := func() -> String:
		var shown: Array = (m.panel.find_child("LookStage", true, false) as Node).find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is UpgradeShowcase)
		return (shown.back() as UpgradeShowcase).item if not shown.is_empty() else ""
	var caption := m.panel.find_child("StageCaption", true, false) as Label
	check(caption.text == "Wearing: White Stag" and stage_scene.call() == "stag_steed", "its stage shows the look worn, the rider on the stag: %s" % caption.text)
	(m.panel.find_child("Look_default", true, false).find_child("LookButton", true, false) as Button).pressed.emit()
	await frames(2)
	check(not ShopDefs.skin_on("stag_steed") and caption.text == "Wearing: Brown Horse" and stage_scene.call() == "mount_horse", "wearing the Brown Horse takes the stag off and shows the horse")
	(m.panel.find_child("Look_stag_steed", true, false).find_child("TryOn", true, false) as Button).pressed.emit()
	await frames(2)
	check(not ShopDefs.skin_on("stag_steed") and caption.text == "Trying on: White Stag" and stage_scene.call() == "stag_steed", "tapping the stag tries it on without wearing it")
	var stag_button := m.panel.find_child("Look_stag_steed", true, false).find_child("LookButton", true, false) as Button
	check(stag_button.text == "Wear", "and its button offers to wear it")
	stag_button.pressed.emit()
	await frames(2)
	check(ShopDefs.skin_on("stag_steed") and caption.text == "Wearing: White Stag" and stag_button.text == "Worn", "which puts it on")
	# Worn, the stag is what you ride, on your phone and, by the pose, on everyone else's.
	check(ShopDefs.skin_on("stag_steed") and p.skin_bits() == 1, "the White Stag is worn")
	check(Net.POSE_BYTES == 41 and Net.pose_bytes(p)[40] == 1, "and sent in the pose")
	var a := Avatar.new(w, 901, {"name": "Rider", "class": "chivalry", "team": 0})
	w.add_child(a)
	a._riding = true
	a.set_skin(1)
	check(a._stag != null and a._stag.visible and (a._horse == null or not a._horse.visible), "another phone shows a rider on the stag, not the horse")
	a.set_skin(0)
	check(not a._stag.visible and a._horse != null and a._horse.visible, "and the horse when it is not worn")
	a.queue_free()
	Game.set_item_on("stag_steed", false)
	check(p.skin_bits() == 0, "taken off in the Armory, the horse is back")
	# The menu's look for games: Play Together glows for a game to join, red for a match to watch.
	m.show_menu()
	await frames(2)
	var together := m.panel.find_child("PlayTogether", true, false) as Button
	check(together != null and Net._listener != null, "the menu looks on the Wi-Fi for games each time it shows")
	var line_of := func() -> String: return (together.find_child("Line", true, false) as Label).text
	Net.rooms = {"10.0.0.7": {"name": "Ana", "players": 1, "rules": 0, "version_ok": true, "live": false, "watchable": false, "watchers": 0, "map": "village", "seen": 0.0}}
	Net.rooms_changed.emit()
	check(together.get_meta("open", false) and not together.get_meta("live", false) and together.has_meta("glow") and line_of.call() == "A game is open to join.", "a game open to join: it glows: '%s'" % line_of.call())
	Net.rooms["10.0.0.8"] = {"name": "Bo", "players": 2, "rules": 0, "version_ok": true, "live": true, "watchable": true, "watchers": 1, "map": "mists", "seen": 0.0}
	Net.rooms_changed.emit()
	check(together.get_meta("open", false) and together.get_meta("live", false) and line_of.call().contains("watch"), "and a match to watch as well: both glows, one after the other")
	Net.rooms.erase("10.0.0.7")
	Net.rooms_changed.emit()
	check(not together.get_meta("open", false) and together.get_meta("live", false) and line_of.call() == "A match is live: watch it.", "only a match to watch: the red glow")
	Net.rooms["10.0.0.8"]["version_ok"] = false
	Net.rooms_changed.emit()
	check(not together.get_meta("live", false) and not together.has_meta("glow"), "a game this version cannot reach does not count")
	Net.rooms.clear()
	m.show_together(0)
	await frames(2)
	Net.rooms = {"10.0.0.8": {"name": "Bo", "players": 2, "rules": 0, "version_ok": true, "live": true, "watchable": true, "watchers": 1, "map": "mists", "seen": 0.0}}
	Net.rooms_changed.emit()
	await frames(1)
	var watch_rows: Array = m.panel.find_children("WatchRow", "Button", true, false)
	check(watch_rows.size() == 1 and (watch_rows[0] as Button).text.contains("Watch Bo's match") and (watch_rows[0] as Button).text.contains("1 watching"), "Play Together lists the match under its own heading, to watch")
	Net.rooms.clear()
	# The Armory's Map Upgrades: every level written out, and a switch for each one you own.
	Game.owned_items["mist_reinforcements"] = true
	Game.switched_off.erase("mist_reinforcements")
	m.show_armory("maps")
	await frames(2)
	var knob := m.panel.find_child("MapSwitch_mist_reinforcements", true, false) as Button
	check(m.panel.find_child("MapUpgradesRow", true, false) != null and knob != null and (knob.find_child("Switch", true, false) as UiSwitch).on, "the Armory has a Map Upgrades section, with an On switch for Mist Reinforcements")
	var level_lines: Array = m.panel.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.begins_with("Level "))
	check(level_lines.size() == ShopDefs.MAP_LEVELS, "it lists all %d levels" % ShopDefs.MAP_LEVELS)
	knob.pressed.emit()
	check(not Game.item_active("mist_reinforcements") and Game.owns_item("mist_reinforcements") and not (knob.find_child("Switch", true, false) as UiSwitch).on and Game.map_upgrades_on().is_empty(), "switched Off there, it stays owned but you do not bring it")
	knob.pressed.emit()
	check(Game.item_active("mist_reinforcements"), "and On again")
	Game.owned_items.erase("mist_reinforcements")
	m.show_armory("maps")
	await frames(2)
	check(m.panel.find_child("MapSwitch_mist_reinforcements", true, false) == null and (m.panel.find_children("*", "Button", true, false) as Array).any(func(b: Button) -> bool: return b.text == "In the Store"), "not owned, it has no switch, only the way to the Store")
	# After buying, the Store's list stays where it was, on what came after the thing bought.
	for c: String in ClassDefs.ALL:
		Game.unlocked[c] = true
	Game.doubloons = 100000
	m.show_store("", -1, "upgrades")
	await frames(2)
	var store_list := (m.panel.get_meta("list") as Control).get_parent() as DragScroll
	store_list.scroll_to(600.0)
	await frames(1)
	var was_at := float(store_list.scroll_vertical)
	check(was_at > 300.0, "the Store's list scrolls (%.0f)" % was_at)
	var on_sale: Array = m.panel.get_meta("store_ids")
	var middle := on_sale.size() / 2
	var buying := str(on_sale[middle])
	check(Game.buy_item(buying), "buying %s" % buying)
	m.show_store("", -1, "upgrades", Callable(), buying)
	await frames(3)
	var after_list := (m.panel.get_meta("list") as Control).get_parent() as DragScroll
	check(absf(float(after_list.scroll_vertical) - was_at) < 2.0, "after buying, the list stays where it was (%.0f, was %.0f)" % [after_list.scroll_vertical, was_at])
	check((m.panel.find_children("*", "Label", true, false) as Array).any(func(l: Label) -> bool: return l.text == ShopDefs.ITEMS[str(on_sale[middle + 1])]["name"] and not after_list.is_ancestor_of(l)), "and the page beside it shows what came next (%s)" % ShopDefs.ITEMS[str(on_sale[middle + 1])]["name"])
	Game.owned_items = saved_items
	Game.switched_off = saved_off
	Game.doubloons = saved_doubloons
	Game.unlocked = saved_unlocked
	# Every Class Upgrade has its own demonstration on the Store's stage: the new six (and the stag) a
	# scene of their own, the others the older demonstrations.
	for id: String in ShopDefs.ITEMS:
		var view := ModelView.new(Vector2(250, 270))
		add_child(view)
		view.show_item(id)
		await frames(3)
		var scenes := view.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is UpgradeShowcase or n is UpgradePreview)
		check(scenes.size() == 1, "%s has a demonstration in the Store" % id)
		if UpgradeShowcase.shows(id):
			var scene := scenes[0] as UpgradeShowcase
			check(scene != null and scene.item == id, "%s plays its own scene" % id)
			for t: float in [0.5, 1.1, 1.6, 2.4, 3.3]:
				scene.clock = t
				scene._process(0.016)
			check(view.turning == (ShopDefs.ITEMS[id]["section"] == "cosmetics"), "%s is shown from its own side" % id if view.turning == false else "%s turns on the stage" % id)
		view.queue_free()
	await frames(1)
	# Play Together: Same Wi-Fi and Online, and no renaming there (Settings has that).
	check(Main.TOGETHER_TABS == ["Same Wi-Fi", "Online"], "Play Together offers Same Wi-Fi and Online only")
	m.show_together(0)
	await frames(2)
	check(m.panel.find_child("Rename", true, false) == null and m.panel.find_child("PlayingAs", true, false) != null, "and shows who you play as, without a way to change it there")
	m.queue_free()
	await frames(2)
	# The Bandit: tougher, Into the Shadows always, the path's ability on a button of its own.
	check(float(ClassDefs.ALL["bandit"]["hp"]) == 110.0, "the Bandit has 110 health")
	var cls := p.class_id
	var was_spec := p.spec_id
	var was_chosen = p.chosen.duplicate()
	var was_level := p.level
	p.spec_id = ""
	p.chosen.clear()
	p.level = 5
	p.setup_class("bandit")
	check(p.has_art() and str(p.art_def().get("name", "")) == "Into the Shadows" and not p.has_path_art(), "before a path, the Bandit has Into the Shadows alone")
	p.points = 10
	for step in Player.CORE_STEPS:
		p.choose_ability(step, 0)
	p.choose_ability(Player.CORE_STEPS, (AbilityData.tree("bandit")["specs"] as Array).map(func(d: Dictionary) -> String: return d["id"]).find("thief"))
	check(p.spec_id == "thief" and str(p.art_def().get("name", "")) == "Into the Shadows" and str(p.path_art_def().get("name", "")) == "Steal", "a Thief keeps Into the Shadows and has Steal beside it")
	var hud := Hud.new()
	add_child(hud)
	hud.player = p
	hud.size = Vector2(1280, 720)
	hud._layout()
	check(hud._button_visible("path_art") and hud._button_visible("art"), "both abilities have a button")
	var b1: Vector2 = hud._buttons["path_art"]["pos"]
	for other: String in hud._buttons:
		if other != "path_art":
			var o: Dictionary = hud._buttons[other]
			check(b1.distance_to(o["pos"]) >= float(hud._buttons["path_art"]["r"]) + float(o["r"]), "the second ability button does not cover %s" % other)
	for z: Zombie in w.zombies.duplicate(): z.release()
	check(not p.path_art_has_use(), "with no one in reach, Steal's button stays grey and says so")
	w.spawn_zombie("normal", p.global_position + Vector3(0, 0, -2.0))
	var target: Zombie = w.zombies.back()
	check(p.path_art_has_use(), "with someone in reach, it lights up")
	target.release()
	hud.queue_free()
	p.spec_id = was_spec
	p.chosen = was_chosen
	p.level = was_level
	p.setup_class(cls)
	# A friend's mending shows on your status row.
	p.hp = p.max_hp() * 0.5
	p.mended_by_friend(4.0)
	check(p.status_effects().any(func(e: Dictionary) -> bool: return e["icon"] == "heart+hand"), "a friend's mending shows as a status")
	p._tick_ability_timers(1.0)
	p.friend_heal_left = maxf(0.0, p.friend_heal_left - 1.0)
	check(not p.status_effects().any(func(e: Dictionary) -> bool: return e["icon"] == "heart+hand"), "and goes once the mending stops")
	# How a night opens, and how it says dawn is near.
	check(w.director.opening_line() == "Survive until the dawn", "the night opens with: Survive until the dawn")
	var was := w.map_id
	w.map_id = "bastion"
	check(w.director.opening_line() == "Defend the Great Portal until the dawn", "the Bastion's: Defend the Great Portal until the dawn")
	for map_id: String in ["mists", "mesenlla", "bastion"]:
		var sound: String = Director.DAWN_SOUNDS[map_id]
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s has its own sound for dawn coming: %s" % [map_id, sound])
	w.map_id = "mists"
	w.director._bell_timer = 0.0
	var minute := w.director._bell_minute
	w.director._process(0.1)
	check(w.director._bell_minute == minute, "no bell rings outside The Village")
	w.map_id = was
	# Weapons only one map has lie around a little more often.
	check(WeaponDefs.EXCLUSIVE_BOOST > 1.0 and is_equal_approx(WeaponDefs.spawn_weight("battleaxe"), float(WeaponDefs.ALL["battleaxe"]["weight"]) * WeaponDefs.EXCLUSIVE_BOOST) and is_equal_approx(WeaponDefs.spawn_weight("sword"), float(WeaponDefs.ALL["sword"]["weight"])), "a map's own weapons are weighted %.2f times" % WeaponDefs.EXCLUSIVE_BOOST)


## Map Upgrades, the Doubloon code, the weather of each place, the Bandit's kit and the Commander.
func _maps_weather_and_balance() -> void:
	# The Store's Map Upgrades: Mist Reinforcements, for Mist Bastion.
	var d: Dictionary = ShopDefs.ITEMS["mist_reinforcements"]
	check(ShopDefs.SECTIONS.get("maps", "") == "Map Upgrades" and d["section"] == "maps" and int(d["price"]) == 2200 and d["map"] == "bastion", "the Store sells Mist Reinforcements under Map Upgrades, for 2,200")
	check(ShopDefs.whose("mist_reinforcements") == "Mist Bastion, for everyone in the match" and Icons.exists(str(d["icon"])) and UpgradeShowcase.shows("mist_reinforcements"), "it says where it works, and has its icon and its scene")
	var saved_items := Game.owned_items.duplicate()
	Game.owned_items.erase("mist_reinforcements")
	check(not ShopDefs.map_upgrade_on("mist_reinforcements") and Game.map_upgrades_on().is_empty(), "not bought, it is off")
	Game.owned_items["mist_reinforcements"] = true
	check(ShopDefs.map_upgrade_on("mist_reinforcements") and Game.map_upgrades_on() == Array(["mist_reinforcements"], TYPE_STRING, "", null), "bought, it is on for a night alone")
	check(ShopDefs.map_upgrade_level("mist_reinforcements") == 1, "alone, it is Level 1")
	Game.set_item_on("mist_reinforcements", false)
	check(ShopDefs.map_upgrade_level("mist_reinforcements") == 0 and Game.map_upgrades_on().is_empty(), "switched Off, you do not bring it")
	Game.set_item_on("mist_reinforcements", true)
	# In a match together: a level for each person (not a bot) who brings it, up to Level 4.
	var mr := ["mist_reinforcements"]
	check(ShopDefs.owners({1: {"maps": []}, 7: {"maps": mr}}, "mist_reinforcements") == 1, "in a match, one owner makes it Level 1")
	check(ShopDefs.owners({1: {"maps": mr}, 7: {"maps": mr}}, "mist_reinforcements") == 2, "two owners make it Level 2")
	check(ShopDefs.owners({1: {"maps": mr}, 7: {"maps": mr}, 8: {"maps": mr}, 9: {"maps": mr}, 10: {"maps": mr}}, "mist_reinforcements") == ShopDefs.MAP_LEVELS and ShopDefs.MAP_LEVELS == 4, "five make it no more than Level 4")
	check(ShopDefs.owners({1: {"maps": mr}, Net.BOT_BASE + 1: {"maps": mr}}, "mist_reinforcements") == 1, "a bot adds no level")
	check(not ShopDefs.anyone_has({1: {"maps": []}, 7: {}}, "mist_reinforcements"), "and with no owner it is off")
	var words_of := {2: "two", 3: "three"}
	check(str(d["desc"]).contains("%s Mist Rangers on each gate" % words_of[Garrison.GATE_ARCHERS]) and str(d["desc"]).contains("%s Mist Heavies" % words_of[Garrison.PORTAL_HEAVIES]) and (d["levels"] as Array).size() == ShopDefs.MAP_LEVELS, "its words count the Rangers and Heavies the game sends, level by level")
	# On Mist Bastion: a Mist Ranger on every gate, and every Mist Soldier 15% stronger.
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var was_fort_map := Game.fort_map
	var was_mode := Game.mode
	Game.mode = Game.Mode.FORT
	Game.fort_map = "bastion"
	var bw := World.new()
	space.add_child(bw)
	bw.setup(Game.Mode.FORT)
	bw.director.running = false
	check(bw.garrison != null and bw.garrison.reinforced and is_equal_approx(bw.garrison.power, Garrison.REINFORCED), "Mist Bastion knows it is reinforced (x%.2f)" % (bw.garrison.power if bw.garrison else 0.0))
	bw.garrison.tick(0.0)
	var perched := bw.allies.filter(func(a: Ally) -> bool: return a.perch != Vector3.INF and not a.dead)
	check(perched.size() == bw.fort.gates.size() and perched.all(func(a: Ally) -> bool: return a.kind == "mist_ranger"), "a Mist Ranger stands on each of the %d gates (%d)" % [bw.fort.gates.size(), perched.size()])
	var first: Ally = perched[0]
	check(first.global_position.y - bw.ground_at(first.global_position) > Fort.WALL_H - 1.5, "up on top of the gate (%.1f m)" % (first.global_position.y - bw.ground_at(first.global_position)))
	check(is_equal_approx(first.hp, float(Ally.HEALTH["mist_ranger"]) * Garrison.REINFORCED), "with 15% more health")
	first._physics_process(0.5)
	check(first.global_position.distance_to(first.perch) < 0.05, "and stays up there")
	# Its two bows: the Long Bow for what comes up the lane, the Crossbow for what is at the gate.
	var held := first._hand_mesh as WeaponVisual
	check(first.hand == "longbow" and held != null and held.weapon == "longbow" and is_equal_approx(held.body_size, WeaponDefs.held_size("longbow")), "it holds a Long Bow, at a player's size (%.2f)" % (held.body_size if held else 0.0))
	check(first.find_children("*", "MeshInstance3D", true, false).filter(func(mi: MeshInstance3D) -> bool: return mi.mesh == WeaponDefs.mesh("crossbow") or mi.mesh == WeaponDefs.mesh("bow")).is_empty(), "and nothing else: no second bow on it")
	var gate: Dictionary = bw.fort.gates[first.lane]
	var out: Vector3 = gate["dir"]
	for z: Zombie in bw.zombies.duplicate():
		z.release()
	var foot := (gate["at"] as Vector3) + out * 2.5
	check(bw.spawn_zombie("child_of_woods", Vector3(foot.x, 0, foot.z)), "a Child of the Woods comes to the gate")
	var breaker: Zombie = bw.zombies.back()
	breaker.set_physics_process(false)
	breaker.position = Vector3(foot.x, bw.ground_at(foot), foot.z)
	first._think = 0.0
	first._cooldown = 0.0
	var before := bw._projectiles.filter(func(pr: Projectile) -> bool: return pr.active and pr.garrison).size()
	first._tick_perch(0.016)
	var bolts := bw._projectiles.filter(func(pr: Projectile) -> bool: return pr.active and pr.garrison)
	check(first.hand == "crossbow" and held.weapon == "crossbow" and held.mesh == WeaponDefs.mesh("crossbow"), "what is at the foot of its gate gets the Crossbow, in place of the Long Bow (%s)" % first.hand)
	var crossbow_size := held.global_basis.get_scale().x
	check(absf(crossbow_size - WeaponDefs.held_size("crossbow")) < 0.05, "a Crossbow the size a player's is (%.2f, a player's %.2f)" % [crossbow_size, WeaponDefs.held_size("crossbow")])
	check(bolts.size() == before + 1 and is_equal_approx(first._cooldown, Ally.CROSSBOW_EVERY), "shot down at it, every %.2f s" % Ally.CROSSBOW_EVERY)
	var lean := first._lean_point()
	check(Vector2(lean.x - first.perch.x, lean.z - first.perch.z).dot(Vector2(out.x, out.z)) > 1.0, "leaning out over the parapet to do it")
	var outer := Vector2((gate["at"] as Vector3).x, (gate["at"] as Vector3).z).dot(Vector2(out.x, out.z)) + Fort.WALL_T * 0.5
	check(Vector2(lean.x, lean.z).dot(Vector2(out.x, out.z)) > outer and bw.has_line_of_sight(lean, breaker.centre()), "its bolts start past the wall's outer face, where no merlon is in the way")
	check(bw.fort.merlons.size() > 20 and bw.fort.merlons.all(func(m: Vector3) -> bool: return Vector2(m.x - first.perch.x, m.z - first.perch.z).length() > Fort.MERLON_W * 0.5 + 0.05 or absf(m.y - first.perch.y) > 1.5), "it stands in a gap between the merlons, not behind one")
	check(first._current == "CrossbowDown" and first._anim.has_animation("CrossbowDown"), "aiming down over the wall (%s)" % first._current)
	for i in 20:
		first._tick_perch(0.016)
	check(first._lean_to >= Ally.LEAN_MIN and first._lean_to <= Ally.LEAN_TILT and first._visual.rotation.x > 0.1, "bent out over the parapet as far as the shot needs (%.2f rad)" % first._visual.rotation.x)
	var hp0 := breaker.hp
	for i in 40:
		await frames(1)
	check(breaker.hp < hp0, "and the bolt strikes it (%.0f)" % (hp0 - breaker.hp))
	breaker.release()
	var lane_at := (gate["at"] as Vector3) + out * 28.0
	check(bw.spawn_zombie("child_of_woods", Vector3(lane_at.x, 0, lane_at.z)), "another comes up the lane")
	var walker_far: Zombie = bw.zombies.back()
	walker_far.set_physics_process(false)
	walker_far.position = Vector3(lane_at.x, bw.ground_at(lane_at), lane_at.z)
	first._think = 0.0
	first._cooldown = 0.0
	first._tick_perch(0.016)
	check(first._foe == walker_far and first.hand == "longbow" and is_equal_approx(first._cooldown, Ally.LONGBOW_EVERY), "what comes up the lane, %d m out, gets the Long Bow" % int(first.global_position.distance_to(walker_far.position)))
	for i in 30:
		first._tick_perch(0.016)
	check(is_zero_approx(first._visual.rotation.x) and is_zero_approx(first._visual.position.z), "standing up straight again to draw it")
	check(Ally.PERCH_REACH > Ally.GARRISON_SIGHT + 6.0, "which reaches further than its old bow (%d m)" % int(Ally.PERCH_REACH))
	walker_far.release()
	check(Ally.HANDS.size() <= 4 and Ally.KINDS.size() <= 32, "what it holds goes to the other phones with it")
	check(bw.garrison.on_lane(0) == 0, "the gate's Ranger is extra: the lane still musters its own guard")
	bw.garrison.tick(Garrison.FIRST)
	var walker: Ally = bw.allies.filter(func(a: Ally) -> bool: return a.perch == Vector3.INF and a.is_garrison()).back()
	check(is_equal_approx(walker.hp, float(Ally.HEALTH[walker.kind]) * Garrison.REINFORCED), "the Mist Soldiers that muster have 15% more health too")
	check(is_equal_approx(walker._garrison_power(), 1.15), "and deal 15% more")
	# Level by level, on fresh gates.
	var perched_at := func() -> Array:
		return bw.allies.filter(func(a: Ally) -> bool: return a.perch != Vector3.INF and not a.dead)
	var portal_guard := func() -> Array:
		return bw.allies.filter(func(a: Ally) -> bool: return a.kind == "mist_heavy" and a.lane < 0 and not a.dead)
	for level in [2, 3, 4]:
		for a: Ally in bw.allies.duplicate():
			if a.is_garrison():
				a.dead = true
		bw.garrison.set_level(level)
		bw.garrison._man_the_gates()
		var up: Array = perched_at.call()
		check(up.size() == bw.fort.gates.size() * Garrison.GATE_ARCHERS, "Level %d: two Mist Rangers on each gate (%d)" % [level, up.size()])
		var by_gate := {}
		for a: Ally in up:
			by_gate[a.lane] = by_gate.get(a.lane, []) + [a]
		var pair: Array = by_gate[0]
		check((pair[0] as Ally).perch.distance_to((pair[1] as Ally).perch) > 2.0 and absf((pair[0] as Ally).perch.y - (pair[1] as Ally).perch.y) < 0.01, "side by side along the wall (%.1f m apart)" % (pair[0] as Ally).perch.distance_to((pair[1] as Ally).perch))
		var kinds := up.map(func(a: Ally) -> String: return a.arrow_kind)
		if level >= 3:
			check(kinds.count("fire") == bw.fort.gates.size() and kinds.count("poison") == bw.fort.gates.size(), "Level %d: on each gate one shoots Fire Arrows, the other Poison Arrows" % level)
		else:
			check(kinds.all(func(k: String) -> bool: return k == ""), "Level 2: plain arrows")
		var guard: Array = portal_guard.call()
		if level >= 4:
			check(guard.size() == Garrison.PORTAL_HEAVIES and guard.all(func(a: Ally) -> bool: return a.fell_back and bw.fort.inside(a.global_position) and a.global_position.distance_to(bw.fort.heart_at) < Garrison.PORTAL_RING + 2.5), "Level 4: three Mist Heavies guard the Great Portal, in the courtyard")
		else:
			check(guard.is_empty(), "Level %d: no Mist Heavies at the portal yet" % level)
	# Level 3's arrows: one sets alight, the other poisons.
	bw.garrison_arrow(Vector3(0, 8, 0), Vector3(0, 8, 10), 10.0, "fire")
	bw.garrison_arrow(Vector3(0, 8, 0), Vector3(0, 8, 10), 10.0, "poison")
	var flying: Array = bw._projectiles.filter(func(pr: Projectile) -> bool: return pr.active and pr.garrison)
	check(flying.any(func(pr: Projectile) -> bool: return pr.fire) and flying.any(func(pr: Projectile) -> bool: return pr.poison == World.GARRISON_POISON), "a Fire Arrow burns and a Poison Arrow poisons")
	space.queue_free()
	Game.fort_map = was_fort_map
	Game.mode = was_mode
	Game.owned_items = saved_items
	await frames(2)
	# The Doubloon code: 2,000 every time, and the code itself is only a hash.
	check(Game.DOUBLOON_CODES.values() == [2000] and not Game.DOUBLOON_CODES.keys().any(func(k: String) -> bool: return k.length() != 64), "a code that pays 2,000 Doubloons, kept only as a hash")
	var key: String = Game.DOUBLOON_CODES.keys()[0]
	var purse := Game.doubloons
	check(Game.redeem_key(key)["result"] == "doubloons" and Game.doubloons == purse + 2000, "it pays 2,000")
	check(Game.redeem_key(key)["result"] == "doubloons" and Game.doubloons == purse + 4000, "and again, every time")
	Game.doubloons = purse
	# Weather: no rain or storm in The Mists; wind in the Valleys and on Mist Bastion, about one night in ten.
	var mists_wet := 0
	var village_windy := 0
	var valley_windy := 0
	for i in 2000:
		if Weather.roll("mists") in [Weather.Kind.RAIN, Weather.Kind.STORM]:
			mists_wet += 1
		if Weather.roll("village") == Weather.Kind.WINDY:
			village_windy += 1
		if Weather.roll("mesenlla") == Weather.Kind.WINDY:
			valley_windy += 1
	check(mists_wet == 0, "The Mists never have rain or storms")
	check(village_windy == 0, "the wind does not blow in The Village")
	check(valley_windy > 130 and valley_windy < 280, "and about one night in ten is windy in the Valleys (%d of 2000)" % valley_windy)
	check(Weather.allowed(Weather.Kind.STORM, "mists") == Weather.Kind.CLEAR and Weather.allowed(Weather.Kind.WINDY, "fort") == Weather.Kind.CLEAR and Weather.allowed(Weather.Kind.WINDY, "bastion") == Weather.Kind.WINDY, "a sent or forced weather a place cannot have is a clear night")
	var was_kind := w.weather.kind
	w.weather.set_kind(Weather.Kind.WINDY)
	check(not w.weather.is_wet() and w.weather._wind != null and w.weather._wind.visible and w.weather._wind.get_child_count() == 2, "a windy night has wind streaks and leaves, and is not wet")
	check(ResourceLoader.exists("res://assets/sounds/wind_breeze.ogg") and Sfx._wind != null and Sfx._wind_target > -30.0, "and the breeze is heard")
	w.weather._process(0.016)
	var cam := w._player_camera_position()
	check(Vector2(w.weather._wind.global_position.x - cam.x, w.weather._wind.global_position.z - cam.z).length() < 0.1, "the wind blows wherever you are")
	w.weather.set_kind(was_kind)
	check(Sfx._wind_target < -50.0, "and it stops with the wind")
	# The Bandit: Dagger, Long Bow and 20 arrows.
	var cls := p.class_id
	var was_slots := p.slots.duplicate()
	var was_arrows := p.arrows
	p.setup_class("bandit")
	check(p.slots == ["dagger", "longbow"] and p.arrows == 20, "the Bandit starts with a Dagger, a Long Bow and 20 arrows")
	p.setup_class(cls)
	p.slots = was_slots
	p.arrows = was_arrows
	p._equip()
	# The Commander: Last Command every 35 s, a battle cry of voices alone, the Gunner's barrage on the spot.
	check(CommanderKit.LAST_CD == 35.0 and float(CommanderKit.LAST_ART["cd"]) == 35.0, "Last Command is ready every 35 s")
	check(Sfx.NAMES.has("command") and ResourceLoader.exists("res://assets/sounds/command.ogg"), "Command's cry is the new battle cry, voices without bells")
	check(ClassDefs.ALL["commander"]["hp"] == 110.0 and not (AbilityData.tree("commander")["specs"][0]["entry"]["add"] as Dictionary).has("max_hp"), "the Warlock no longer gives up health")
	check(float(WeaponDefs.ALL["war_staff"]["power"]) > 1.1, "and its War Staff hits harder")
	check(CommanderKit.STORM_DPS > 0.0 and CommanderKit.STORM_STRIKE_EVERY < 1.0, "its storm hurts everything inside all the while, and strikes more often")
	var m := Main.new()
	add_child(m)
	await frames(2)
	m.world = w
	m.hud = Hud.new()
	m.add_child(m.hud)
	m.show_command_map()
	await frames(2)
	var call := m.find_child("CallBarrage", true, false) as Button
	check(call != null and not call.disabled, "the Gunner can call the barrage at once, on the circle round itself")
	m.world = null
	m.queue_free()
	await frames(2)


## What every class, path, ability and Class Upgrade says, against what the game does (tests/text_audit.gd).
## Special attacks shown before they happen; damage over time and healing as numbers.
func _feedback_and_numbers() -> void:
	var cls := p.class_id
	var saved_items := Game.owned_items.duplicate()
	var saved_off := Game.switched_off.duplicate()
	var entry_of := func(key: String) -> Dictionary:
		for r: Dictionary in p.readiness():
			if r["key"] == key:
				return r
		return {}
	# The Great Keg: counted over the ability button, glowing when the keg is next, a keg in the air.
	p.setup_class("artificer")
	p.spec_id = "pyromaniac"
	Game.owned_items["great_keg"] = true
	Game.switched_off.erase("great_keg")
	p.bombs_thrown = 0
	var keg: Dictionary = entry_of.call("great_keg")
	check(not keg.is_empty() and keg["button"] == "art" and keg["need"] == PathUpgrades.GREAT_KEG_EVERY and keg["have"] == 0 and not keg["primed"], "the Great Keg counts its throws over the ability button")
	p.bombs_thrown = PathUpgrades.GREAT_KEG_EVERY - 1
	keg = entry_of.call("great_keg")
	check(keg["primed"] and keg["have"] == PathUpgrades.GREAT_KEG_EVERY - 1, "and is shown primed before the throw that is the keg")
	p.toast = ""
	p._throw_bombs()
	var kegs := w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.mesh == w._shot_mesh("keg"))
	check(kegs.size() == 1 and p.toast == "", "the keg flies as a keg, with no word after it (toast '%s')" % p.toast)
	check(not (entry_of.call("great_keg") as Dictionary)["primed"], "and the count starts again")
	# Grapeshot: counted under the crosshair, and the musket glows while it is loaded.
	p.setup_class("commander")
	p.spec_id = "gunner"
	Game.owned_items["grapeshot"] = true
	Game.switched_off.erase("grapeshot")
	p.slots = ["musket", null]
	p.current = 0
	p._equip()
	p.musket_shots = PathUpgrades.GRAPESHOT_EVERY - 1
	p._primed_wait = 0.0
	p._tick_primed_glow(0.016)
	check((entry_of.call("grapeshot") as Dictionary).get("primed", false) and p.weapon_glows() and p._vm_mesh.material_overlay != null, "loaded Grapeshot: its mark glows, and so does the musket")
	p.musket_shots = 0
	p._primed_wait = 0.0
	p._tick_primed_glow(0.016)
	check(not p.weapon_glows() and p._vm_mesh.material_overlay == null, "and the glow goes once it has gone off")
	# Killing Shot: armed, then resting.
	p.setup_class("ranger")
	p.slots = ["bow", null]
	p.current = 0
	p._equip()
	p.flags["killing_shot"] = true
	p._kill_shot_cd = 0.0
	check((entry_of.call("killing_shot") as Dictionary).get("primed", false), "Killing Shot shows armed before the shot")
	p._kill_shot_cd = 3.0
	check(not (entry_of.call("killing_shot") as Dictionary).get("primed", true), "and not while it rests")
	# A passive counted on hits (Cleaver): its own name and icon, from the skill tree.
	p.setup_class("infantry")
	p.slots = ["sword", null]
	p.current = 0
	p._equip()
	var cleaver := Player._find_ability(AbilityData.tree("infantry"), "cleaver")
	p._apply_ability(cleaver)
	var counted: Dictionary = entry_of.call("nth_cleaver")
	check(not counted.is_empty() and counted["name"] == cleaver["name"] and counted["icon"] == cleaver["icon"] and counted["need"] == 4, "Cleaver counts its hits under the crosshair: %s" % str(counted))
	for i in 3:
		p.fire("hit", {})
	check((entry_of.call("nth_cleaver") as Dictionary)["primed"], "and is primed for the fourth")
	for key: String in ["grapeshot", "great_keg", "killing_shot"]:
		var look: Dictionary = {"grapeshot": {"icon": ShopDefs.ITEMS["grapeshot"]["icon"]}, "great_keg": {"icon": ShopDefs.ITEMS["great_keg"]["icon"]}, "killing_shot": {"icon": "arrow+crown"}}[key]
		for glyph: String in str(look["icon"]).split("+"):
			check(Icons.exists(glyph), "%s's sign exists: %s" % [key, glyph])
	# Damage over time: numbers in its colour, for the one who put it on.
	w.spawn_zombie("normal", p.global_position + Vector3(0, 0, -4))
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	z.max_hp = 5000.0
	z.hp = 5000.0
	z.last_hitter = 0
	var numbers := w.damage_numbers
	var shown := func(color: Color) -> bool:
		return numbers._labels.any(func(l: Label3D) -> bool: return l.visible and l.modulate.is_equal_approx(color))
	z.add_dot(20.0, 2.0)
	for i in 30:
		z._tick_dot(0.016)
	check(shown.call(DamageNumbers.DOT_COLORS["poison"]), "poison ticks float up in green")
	z.add_dot(20.0, 2.0, true)
	z.poison_left = 0.0
	for i in 30:
		z._tick_dot(0.016)
	check(shown.call(DamageNumbers.DOT_COLORS["bleed"]), "bleeding in red")
	z.ignite(2.0)
	w.burn_tick(z)
	check(shown.call(DamageNumbers.DOT_COLORS["fire"]), "fire in orange")
	z.release()
	# Healing: green numbers over a summon you mend.
	p.setup_class("commander")
	w.spawn_ally("infantry", p.global_position + Vector3(2, 0, 0), 30.0)
	var friend: Ally = w.allies.back()
	friend.hp = 10.0
	HeavyArts.mend_summons(w, p.net_id(), friend.global_position, 3.0, 25.0)
	check(numbers._labels.any(func(l: Label3D) -> bool: return l.visible and l.text == "+25" and l.modulate.is_equal_approx(DamageNumbers.HEAL_COLOR)), "mending a summon shows +25 in green")
	# Mending from a friend's field is counted for that friend.
	p.hp = p.max_hp() - 30.0
	p.mended_by_friend(12.0, 77)
	check(is_equal_approx(float(p._mended_by.get(77, 0.0)), 12.0), "a friend's field's mending is told to that friend")
	p.mended_by_friend(50.0, 77)
	check(is_equal_approx(float(p._mended_by.get(77, 0.0)), 30.0), "only what it really healed")
	p._mended_by.clear()
	Game.owned_items = saved_items
	Game.switched_off = saved_off
	p.setup_class(cls)
	await frames(1)


## The Beastmaster's crow and pets, the Mesenlla beasts and bosses, the Wyverns, the Shapeshifter's
## forms and the Mesenlla familiar and items.
func _wilds_of_mesenlla() -> void:
	# Choosing a pet in the Armory changes it where it is: the page does not jump back to the top.
	var saved_items := Game.owned_items.duplicate()
	var saved_pet := Game.pet
	for pet: String in ShopDefs.PETS:
		Game.owned_items[pet] = true
	Game.choose_pet("wolf")
	var m := Main.new()
	add_child(m)
	await frames(2)
	m.show_armory("ranger")
	await frames(3)
	var choices := m.panel.find_children("Pet_raven", "Button", true, false)
	check(choices.size() == 1, "the Armory shows the Beastmaster's pets to choose from")
	var up: Node = choices[0]
	while up and not (up is ScrollContainer):
		up = up.get_parent()
	var scroll := up as ScrollContainer
	var content := scroll.get_child(0) as Control
	var stage: Node = m.panel.find_children("PetStage", "", true, false)[0]
	content.custom_minimum_size.y = scroll.size.y + 1200.0 # this square test window shows the whole page; a phone does not
	await frames(2)
	(scroll as DragScroll).scroll_to(240.0)
	await frames(1)
	var at := scroll.scroll_vertical
	(choices[0] as Button).pressed.emit()
	await frames(2)
	check(Game.pet == "raven", "pressing the Raven chooses it")
	check(is_instance_valid(stage) and is_instance_valid(content) and scroll.get_child(0) == content, "and the Armory is not built again")
	check(scroll.scroll_vertical == at and at > 0, "so it stays where it was scrolled to (%d, was %d)" % [scroll.scroll_vertical, at])
	check(stage.find_children("Raven", "Node3D", true, false).size() == 1, "and the stage shows the crow")
	m.queue_free()
	Game.owned_items = saved_items
	Game.choose_pet(saved_pet)
	await frames(2)
	# The crow moves: wings beat as it hovers, it flies in beats and glides, and it drops on what it strikes.
	var crow := BirdRig.new("crow")
	add_child(crow)
	crow.set_process(false)
	var lifts: Array[float] = []
	var folds: Array[float] = []
	for i in 60:
		crow.advance(1.0 / 60.0)
		lifts.append(crow.shoulders[0].rotation.z)
		folds.append(crow.elbows[0].rotation.y)
	check(lifts.max() - lifts.min() > 1.0, "hovering, its wings beat (%.2f rad)" % (lifts.max() - lifts.min()))
	check(folds.max() > 0.5, "and fold at the elbow on the way up")
	check(is_equal_approx(crow.shoulders[1].rotation.z, -crow.shoulders[0].rotation.z), "both wings together")
	check(crow.body.rotation.x < -0.2 and crow.feet.rotation.x < 0.6, "it hangs upright with its feet down")
	crow.moving = true
	for i in 120: crow.advance(1.0 / 60.0)
	check(crow.body.rotation.x > 0.0 and crow.feet.rotation.x > 1.2, "flying, it leans forward and tucks its feet")
	var still := 0
	var beat := 0
	for i in 150:
		crow.advance(1.0 / 60.0)
		if absf(crow.shoulders[0].rotation.z - 0.14) < 0.05: still += 1
		else: beat += 1
	check(still > 15 and beat > 40, "it beats its wings and glides between beats (%d glide frames, %d beating)" % [still, beat])
	crow.moving = false
	crow.strike()
	var lowest := 0.0
	var talons := 9.0
	var peck := 0.0
	for i in int(BirdRig.STRIKE_TIME * 60.0) + 30:
		crow.advance(1.0 / 60.0)
		lowest = minf(lowest, crow.body.position.y)
		talons = minf(talons, crow.feet.rotation.x)
		peck = maxf(peck, crow.head.rotation.x)
	check(lowest < -crow.dive * 0.9, "striking, it drops on its prey (%.2f m)" % lowest)
	check(talons < -0.8 and peck > 0.6, "throws its talons forward and pecks")
	check(not crow.striking() and crow.body.position.y > -0.2, "and climbs back to where it was")
	crow.queue_free()
	# Every bird is of the same rig: the Carrion Crow, the Eagle and the Mist Eagle, and the Raven familiar.
	for kind: String in ["carrion", "eagle", "mist_eagle"]:
		var made: Node3D = EnemyModels.build("crow") if kind == "carrion" else MesenllaModels.build(kind)
		var bird := made.get_meta("bird") as BirdRig
		check(bird != null and bird.kind == kind and made.get_meta("wing_l") == bird.shoulders[1], "the %s is a posed bird" % kind)
		made.free()
	var eagle := BirdRig.new("eagle")
	add_child(eagle)
	eagle.set_process(false)
	check(eagle.scale.x > 1.4 and BirdRig.KINDS["eagle"]["flight"] < BirdRig.KINDS["crow"]["flight"], "an eagle is bigger, with slower beats than a crow's")
	eagle.moving = true
	var soared := 0
	for i in 240:
		eagle.advance(1.0 / 60.0)
		if absf(eagle.shoulders[0].rotation.z - 0.14) < 0.05: soared += 1
	check(soared > 60, "and soars longer between them (%d of 240 frames)" % soared)
	# A dive: swept back and folded, then near the ground the talons forward, and a rake as it pulls up.
	eagle.stoop(true)
	eagle.steep = 1.0
	eagle.low = 12.0
	for i in 30: eagle.advance(1.0 / 60.0)
	check(eagle.shoulders[0].rotation.y > 0.8 and eagle.elbows[0].rotation.y > 1.0 and eagle.body.rotation.x > 0.7, "diving, it sweeps its wings back and folds them, head down the line of its fall")
	eagle.low = 0.8
	for i in 20: eagle.advance(1.0 / 60.0)
	check(eagle.feet.rotation.x < -0.5, "near the ground its talons come forward")
	eagle.stoop(false)
	eagle.advance(1.0 / 60.0)
	check(eagle._flare > 0.0 and eagle.feet.rotation.x < 0.0, "and it rakes as it pulls up")
	eagle.restart()
	eagle.screeching = true
	for i in 30: eagle.advance(1.0 / 60.0)
	check(eagle.jaw.rotation.x > 0.3 and eagle.head.rotation.x > 0.5, "before a dive it hangs screeching, head out at its prey")
	eagle.queue_free()
	p.activate_power("raven")
	var familiar := p._familiars["raven"] as Node3D
	var mini: BirdRig = familiar.get_child(0) as BirdRig
	check(mini != null and mini.find_children("*", "MeshInstance3D", true, false).all(func(mi: MeshInstance3D) -> bool: return mi.layers == 2), "the Raven familiar is a little bird in view of your hands")
	var span := AABB()
	var first_part := true
	for mi: MeshInstance3D in mini.find_children("*", "MeshInstance3D", true, false):
		var part := familiar.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		span = part if first_part else span.merge(part)
		first_part = false
	var daemon_width := PowerDefs.mesh("daemon").get_aabb().size.x * 0.22
	check(span.size.x < daemon_width * 1.4 and span.size.x > daemon_width * 0.6, "no bigger than the other familiars beside it (%.2f m across, the Daemon %.2f m)" % [span.size.x, daemon_width])
	var flap := mini.shoulders[0].rotation.z
	await frames(10)
	check(not is_equal_approx(flap, mini.shoulders[0].rotation.z), "beating its wings")
	p.powers["raven"] = 0.0
	p._tick_powers(0.016)
	# In the game: the Beastmaster's raven strikes when it bites.
	w.spawn_ally("raven", p.global_position + Vector3(3, 0, 0), 20.0)
	var raven: Ally = w.allies.back()
	check(raven._raven != null and raven._raven.is_inside_tree(), "the Beastmaster's raven is the crow")
	raven._attack_left = 0.25
	raven._move_wolf(0.016, false)
	check(raven._raven.striking(), "and it dives on what it bites")
	w.remove_ally(raven)
	await _mesenlla_finds()
	await _changelog_and_atlas()


## The Changelog in cards by kind, and where the places beyond the Mists sit on the map.
func _changelog_and_atlas() -> void:
	var vs := ChangelogPanel.versions(ChangelogPanel.notes())
	var current := str(ProjectSettings.get_setting("application/config/version")).get_slice("-dev.", 0)
	check(vs.size() > 10 and (str(vs[0]["number"]).begins_with("Development") or str(vs[0]["number"]) == current) and ChangelogPanel.count(vs[0]) > 5, "the Changelog reads every version, newest first")
	var released: Dictionary = vs.filter(func(v: Dictionary) -> bool: return str(v["number"]) == "0.21.4")[0]
	check(released["name"] == "A Portal Worth Defending" and released["date"] == "11 November 2026", "with each version's name and date")
	check(ChangelogPanel.category("Fixes")[1] == "Fixes" and ChangelogPanel.category("The wilds of Mesenlla")[1] == "Enemies" and ChangelogPanel.category("Spectator Mode")[1] == "Playing together", "each part is marked by what it is about")
	for c: Array in ChangelogPanel.CATEGORIES + [ChangelogPanel.OTHER]:
		check(Icons.exists(c[2]), "%s has its icon" % c[1])
	var long := "**Lead words.** " + "A first sentence that runs on for a while. ".repeat(6)
	check(ChangelogPanel.brief(long).length() < long.length() and ChangelogPanel.brief(long).begins_with("**Lead words.**"), "a long change shows its gist first")
	check(ChangelogPanel.bbcode("**Bold** and [square]") == "[b][color=#ffffff]Bold[/color][/b] and [lb]square]", "bold stands out; brackets stay as written")
	check(ChangelogPanel.bbcode("*Once upon a time.* **Then** this") == "[i]Once upon a time.[/i] [b][color=#ffffff]Then[/color][/b] this", "italics too")
	var told := ChangelogPanel.versions(ChangelogPanel.parse("## 1.0.0 — Told (1 January 2027)\n\n*A story.* What came.\n\n### Fixes\n- One.\n"))
	check((told[0]["intro"] as Array) == ["*A story.* What came."] and (told[0]["parts"] as Array).size() == 1 and told[0]["parts"][0]["title"] == "Fixes", "words before a version's first part are its intro, not a card of their own")
	var m := Main.new()
	add_child(m)
	await frames(2)
	m.show_changelog()
	await frames(3)
	var page := m.panel as ChangelogPanel
	var cards := func() -> int: return page._body.get_children().filter(func(n: Node) -> bool: return n.has_meta("list")).size()
	check(page._rail.get_child_count() == vs.size() and cards.call() == (vs[0]["parts"] as Array).size(), "the screen lists the versions and shows the newest in cards (%d)" % cards.call())
	var intros := page._body.find_children("Intro", "RichTextLabel", true, false)
	check(intros.size() == (vs[0]["intro"] as Array).size() and (intros.is_empty() or (intros[0] as RichTextLabel).get_parsed_text().length() > 40), "with its intro over its cards")
	page.show_version(1)
	await frames(2)
	check(cards.call() == (vs[1]["parts"] as Array).size(), "and another version when it is chosen (%d)" % cards.call())
	m.queue_free()
	await frames(1)
	var bastion: Vector2 = WorldAtlas.SPOTS["bastion"]
	var valleys: Vector2 = WorldAtlas.SPOTS["mesenlla"]
	check(bastion.x >= 0.79 and bastion.y >= 0.34, "Mist Bastion sits down among the peaks, not on top of them")
	check(valleys.y >= 0.75 and valleys.y - bastion.y > 0.35, "and the Valleys of Mesenlla further down the map")


## The Stone Sprite, the Mistberry Draught and the Antler Charm: found only beyond the Mists.
func _mesenlla_finds() -> void:
	for id: String in ["stone_sprite", "mistberry_draught", "antler_charm"]:
		var d: Dictionary = PowerDefs.ALL[id]
		check(d["maps"] == SpawnRules.MESENLLA and is_equal_approx(float(d["time"]), 20.0), "%s is found only in Mesenlla, for 20 seconds" % id)
		var badge := ClassPresentation.map_tag(d)
		check((badge.get_child(0) as Label).text == "Map Exclusive · Mesenlla", "%s is tagged Map Exclusive · Mesenlla" % id)
		badge.free()
		for glyph: String in Icons.power(id).split("+"):
			check(Icons.exists(glyph), "%s's sign exists: %s" % [id, glyph])
	check(PowerDefs.title("mistberry_draught") == "Mistberry Draught" and PowerDefs.title("speed") == "Speed Potion", "the Draught and the Charm keep their own names")
	var village := {}
	var valleys := {}
	for i in 400:
		village[PowerDefs.pick_potion("village")] = true
		valleys[PowerDefs.pick_potion("mesenlla")] = true
		village[PowerDefs.pick_familiar("village")] = true
		valleys[PowerDefs.pick_familiar("bastion")] = true
	check(not village.has("stone_sprite") and not village.has("mistberry_draught") and not village.has("antler_charm"), "none of them turns up in the Village")
	check(valleys.has("stone_sprite") and valleys.has("mistberry_draught") and valleys.has("antler_charm"), "all of them turn up beyond the Mists")
	check(str(PowerDefs.ALL["stone_sprite"]["desc"]).contains("Every %d seconds" % int(PowerDefs.STONE_INTERVAL)), "the Stone Sprite says how often its ward rises")
	check(str(PowerDefs.ALL["mistberry_draught"]["desc"]).contains("%d health a second" % int(PowerDefs.MISTBERRY_HEAL)), "the Draught says how fast it mends")
	check(str(PowerDefs.ALL["antler_charm"]["desc"]).contains("%s seconds" % str(PowerDefs.ANTLER_ROOT)) and str(PowerDefs.ALL["antler_charm"]["desc"]).contains("for %d seconds after" % int(PowerDefs.ANTLER_AGAIN)), "the Charm says how long the vines hold")
	# The Stone Sprite: its ward takes the next blow and throws back whoever struck.
	p.setup_class("heavy")
	p.hp = p.max_hp()
	p.guard_left = 0.0
	p.activate_power("stone_sprite")
	check(p.stone_ward and p._ward_stones.visible, "the Stone Sprite raises a ward of stones about you")
	w.spawn_zombie("normal", p.global_position + Vector3(0, 0, -1.5))
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	var hp0 := p.hp
	p.hurt(30.0, z.position, z)
	check(p.hp == hp0 and not p.stone_ward, "it takes the blow")
	check(z._stun > 0.0 and z._knock.length() > 1.0, "and throws back whoever struck")
	p.hurt(10.0, z.position, z)
	check(p.hp < hp0, "the next blow lands")
	p._tick_powers(PowerDefs.STONE_INTERVAL + 0.1)
	check(p.stone_ward, "until the ward rises again, %d seconds later" % int(PowerDefs.STONE_INTERVAL))
	check(p.readiness().any(func(r: Dictionary) -> bool: return r["key"] == "stone_ward" and r["primed"]), "and you can see that it is up")
	p.powers["stone_sprite"] = 0.0
	p._tick_powers(0.016)
	# The Mistberry Draught: mist where you walk; in it you are hidden and you mend.
	p.hp = p.max_hp() - 40.0
	p.activate_power("mistberry_draught")
	p._tick_powers(0.016)
	check(p.in_mist and p.is_unseen(), "the Draught leaves mist where you stand, and hides you in it")
	var mending := p.hp
	for i in 30:
		p._tick_powers(1.0 / 30.0)
	check(p.hp > mending + PowerDefs.MISTBERRY_HEAL * 0.8, "and mends you (%.1f a second)" % (p.hp - mending))
	check(w._mist_patches.any(func(m: CPUParticles3D) -> bool: return m.emitting), "the mist can be seen")
	var away := p.global_position
	p.powers.erase("mistberry_draught")
	p.global_position = away + Vector3(20, 0, 0)
	p._tick_powers(0.016)
	check(not p.in_mist and not p.is_unseen(), "out of it, you are seen again")
	p.global_position = away
	p._mistberry.clear()
	p._tick_powers(0.016)
	# The Antler Charm: your blows root what they hit.
	z.root_left = 0.0
	z._stun = 0.0
	z._root_again = -100.0
	p.activate_power("antler_charm")
	p.on_melee_connect(z, WeaponDefs.ALL["sword"])
	check(z.root_left > 0.0 and z._vines and z._vines.visible, "the Antler Charm's vines hold what you hit")
	z.state = Zombie.State.CHASE
	check(z._desired_speed() == 0.0, "it cannot move")
	z.root_left = 0.0
	p.on_melee_connect(z, WeaponDefs.ALL["sword"])
	check(z.root_left == 0.0, "nor be caught again straight away")
	z._root_again = w.now - 0.1
	p.on_shot_connect(z)
	check(z.root_left > 0.0, "arrows catch it too, once its %d seconds are up" % int(PowerDefs.ANTLER_AGAIN))
	p.powers.erase("antler_charm")
	z.release()
	p.setup_class("heavy")


func _text_audit() -> void:
	var problems: Array[String] = (load("res://tests/text_audit.gd").new() as RefCounted).run()
	for problem in problems:
		check(false, problem)
	check(problems.is_empty(), "every number on a class, path, ability and Class Upgrade is the game's own (%d wrong)" % problems.size())



## Mario's list of 16 November: the Armory's locked classes, keeping places in Settings, the Codex and
## the Sandbox, icons, the Raven familiar's size, freezing, the Woodland Cavalry, Mist Bastion's
## soldiers, archers, battlements and hollows, and what Children of the Woods carry.
func _requests_1116() -> void:
	var m: Main = Main.new()
	add_child(m)
	await frames(2)
	# Settings: a new difficulty, or a new graphics level, leaves the page where it was.
	var saved_difficulty := Game.difficulty
	var saved_quality := Game.quality
	var saved_auto := Game.quality_auto
	m.show_menu()
	await frames(2)
	# A window short enough for the Settings page to scroll.
	var window_was := get_window().size
	get_window().size = Vector2i(1152, 380)
	m.show_settings()
	await frames(3)
	var settings := m.ui_layer.find_children("SettingsScroll", "DragScroll", true, false).back() as DragScroll
	settings.scroll_to(160.0)
	await frames(1)
	var settings_at := float(settings.scroll_vertical)
	check(settings_at > 40.0, "Settings scrolls (%.0f)" % settings_at)
	var pressed := func(text: String) -> void:
		for b: Button in m.ui_layer.find_children("*", "Button", true, false):
			if b.text == text and b.is_visible_in_tree() and not b.is_queued_for_deletion():
				b.pressed.emit()
				return
	pressed.call("Hard" if Game.difficulty != 2 else "Easy")
	await frames(4)
	var again := m.ui_layer.find_children("SettingsScroll", "DragScroll", true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	check(again.size() == 1 and absf(float((again[0] as DragScroll).scroll_vertical) - settings_at) < 2.0, "a new difficulty keeps Settings where it was (%.0f)" % (float((again[0] as DragScroll).scroll_vertical) if again.size() == 1 else -1.0))
	var world_before := m.world
	pressed.call("Low" if Game.quality != 0 or Game.quality_auto else "Medium")
	await frames(4)
	again = m.ui_layer.find_children("SettingsScroll", "DragScroll", true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	check(again.size() == 1 and absf(float((again[0] as DragScroll).scroll_vertical) - settings_at) < 2.0, "a new graphics level keeps you in Settings, where you were, not back at the main menu")
	check(m.world != world_before and m.world.mode == Game.Mode.MENU, "with the scene behind it built again at that level")
	get_window().size = window_was
	Game.difficulty = saved_difficulty
	Game.quality = saved_quality
	Game.quality_auto = saved_auto
	Game.apply_quality()
	# The Codex and the Sandbox: no War Wyvern Rider of its own; the Fallen Revenant with the Fallen
	# heroes; an enemy's description hidden until you have killed one.
	check(CodexPanel.enemy_group("fallen_revenant") == CodexPanel.enemy_group("hero_infantry"), "the Fallen Revenant is one of the Fallen heroes")
	var saved_kills := Game.killed_kinds.duplicate()
	Game.killed_kinds = {"bear": true}
	var codex := CodexPanel.new()
	add_child(codex)
	codex._list = VBoxContainer.new()
	codex.add_child(codex._list)
	codex._enemies()
	var codex_texts: Array = codex._list.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(not codex_texts.has(ZombieDefs.ALL["wyvern_rider"]["name"]), "the Codex has no War Wyvern Rider of its own")
	check(codex_texts.has(ZombieDefs.ALL["bear"]["desc"]) and not codex_texts.has(ZombieDefs.ALL["mist_bear"]["desc"]) and codex_texts.has(CodexPanel.HIDDEN_ENEMY), "it tells you about the enemies you have killed, and not yet the others")
	codex.queue_free()
	var saved_mode := Game.mode
	Game.mode = Game.Mode.SANDBOX
	Game.note_killed("mist_bear")
	check(not Game.has_killed("mist_bear"), "a kill in the Sandbox doesn't count")
	Game.mode = Game.Mode.NIGHT
	Game.note_killed("mist_bear")
	check(Game.has_killed("mist_bear"), "a kill in a match does")
	Game.mode = saved_mode
	Game.killed_kinds = saved_kills
	# Icons: the new ones exist and differ from what they replaced.
	for pair: Array in [["mist_bear", "mist_bear"], ["mist_eagle", "mist_eagle"], ["mist_elemental", "mist_elemental"], ["storm_elemental", "storm_elemental"], ["woodland_cavalry", "woodland_cavalry"]]:
		check(ZombieDefs.ALL[pair[0]]["icon"] == pair[1] and Icons.glyph(pair[1]) != null, "%s has its own icon" % pair[0])
	check(str(ZombieDefs.ALL["veil_regent"]["icon"]).ends_with("+crown") and ["great_revenant_elemental", "war_wyvern"].all(func(b: String) -> bool: return str(ZombieDefs.ALL[b]["icon"]).ends_with("+crown")), "the Veil Regent wears a crown like the other bosses")
	check(Icons.power("daemon") == "daemon" and Icons.power("daemon") != ZombieDefs.ALL["mimic"]["icon"], "the Daemon has an icon of its own")
	var invisible_icon := ""
	for entry: Dictionary in StatusCatalog.TIMED:
		if entry["field"] == "invis_left":
			invisible_icon = entry["icon"]
	check(invisible_icon == "invisible" and BanditKit.ARTS[""]["icon"] == "invisible", "Invisible has its own icon, apart from Unseen's closed eye")
	# Children of the Woods: mostly blades and flails; spears, bows and crossbows now and then.
	var def: Dictionary = ZombieDefs.ALL["child_of_woods"]
	var far := 0
	for i in 4000:
		var picked: String = def["weapons"][Zombie.pick_weighted(def["weapon_odds"])]
		if WeaponDefs.is_ranged(picked) or picked == "spear":
			far += 1
	check(absf(far / 4000.0 - 3.0 / 11.0) < 0.03, "about 27%% of them carry a spear or something to shoot (%.1f%%)" % (far / 40.0))
	# Mist Bastion: soldiers fall back through a broken gate from anywhere before it; battlements are
	# walls to auto-jump; the dry hollows have no unseen walls.
	var saved_map := Game.fort_map
	Game.fort_map = "bastion"
	Game.mode = Game.Mode.FORT
	var space := Node3D.new()
	add_child(space)
	var bw := World.new()
	space.add_child(bw)
	bw.setup(Game.Mode.FORT)
	bw.director.running = false
	for z: Zombie in bw.zombies.duplicate(): z.release()
	var east: Dictionary = bw.fort.gates[2]
	var out: Vector3 = east["dir"]
	var heavy := bw.spawn_garrison("mist_heavy", 2, bw.garrison.mark(2, "post"), bw.garrison.mark(2, "post"))
	bw.fort.hit_gate(east, 99999.0, east["at"])
	# Where one stood still for good: 1.5 m from the gate's mouth, a metre off its middle.
	heavy.global_position = (east["at"] as Vector3) + out * 5.1 + out.cross(Vector3.UP) * 1.05
	heavy.global_position.y = bw.ground_at(heavy.global_position)
	await frames(240)
	check(bw.fort.inside(heavy.global_position) and heavy.fell_back, "a Mist Soldier before a fallen gate goes in to the portal, from anywhere (%s)" % heavy.global_position)
	var merlon: Vector3 = bw.fort.merlons[bw.fort.merlons.size() / 2]
	# Stand on the wall walk just inside a merlon, facing it.
	var pl := bw.player
	pl.set_physics_process(false)
	var walk_out := Vector3.ZERO
	for g: Dictionary in bw.fort.gates:
		var d: Vector3 = g["dir"]
		var rel := merlon - (g["at"] as Vector3)
		if absf(rel.dot(d)) < Fort.WALL_T:
			walk_out = d
	if walk_out == Vector3.ZERO:
		walk_out = (Vector3(merlon.x, 0, merlon.z) - Vector3(bw.fort.heart_at.x, 0, bw.fort.heart_at.z)).normalized()
	pl.global_position = merlon - walk_out * 0.9 + Vector3.UP * 0.05
	await frames(2)
	check(not pl._should_auto_jump(walk_out), "walking up to a battlement, auto-jump leaves it alone")
	for spot: Vector2 in [Vector2(-28.4, 57.9), Vector2(-59.6, 92.3)]:
		var q := PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 4.0
		q.shape = ball
		q.collision_mask = Terrain.BARRIER
		q.transform = Transform3D(Basis(), Vector3(spot.x, bw.ground_at(Vector3(spot.x, 0, spot.y)) + 1.0, spot.y))
		check(bw.get_world_3d().direct_space_state.intersect_shape(q, 4).is_empty() and bw.terrain.is_walkable(spot.x, spot.y), "no unseen wall in the dry hollow at %s" % spot)
	# Freezing a Child of the Woods turns all of it to ice, its leaves and bark too; thawed, all comes back.
	var at := bw.fort.heart_at + Vector3(0, 0, 8)
	bw.spawn_zombie("child_of_woods", at)
	var child := _nearest_zombie(at, bw)
	check(child != null and child.type_id == "child_of_woods", "a Child of the Woods to freeze")
	if child:
		var worn := child._parts.filter(func(mi: MeshInstance3D) -> bool: return mi.has_meta("own_material"))
		check(worn.size() >= 3, "its leaves, bark and eyes are of its body (%d parts)" % worn.size())
		child.freeze(1.0)
		check(child._parts.all(func(mi: MeshInstance3D) -> bool: return mi.material_override == Zombie.ice_material()), "frozen, every part of it is ice")
		child._show_frozen(0.0)
		check(worn.all(func(mi: MeshInstance3D) -> bool: return mi.material_override == mi.get_meta("own_material")), "and thawed, its own look comes back")
		child.release()
	# The Woodland Cavalry: a jointed bear in harness under a rider who sits in its saddle.
	bw.spawn_zombie("woodland_cavalry", at)
	var cav := _nearest_zombie(at, bw)
	check(cav != null and cav.type_id == "woodland_cavalry" and cav._mounted, "a Woodland Cavalry rides out")
	if cav:
		cav.set_physics_process(false)
		var bear := cav._horse_node
		check(bear != null and not (bear is MeshInstance3D) and bear.get_node_or_null("Rig/Hind/Torso/Saddle") != null and bear.get_node_or_null("Rig/Hind/Torso/Head/Jaw") != null, "on a bear of jointed legs, head and jaw, with a saddle")
		check(["Ride", "RideCharge", "RideThrust", "RideBrandish"].all(func(n: String) -> bool: return Net.ANIMS.has(n) and cav._anim.has_animation(n)), "the rider's riding moves, on every phone")
		var leg := bear.get_node("Rig/Hind/Torso/LegFL") as Node3D
		cav._current_anim = ""
		cav._play("RideCharge", 1.0, 0.0)
		var swings: Array[float] = []
		for i in 30:
			cav._tick_mount(1.0 / 30.0, 7.0)
			swings.append(leg.rotation.x)
		check(swings.max() - swings.min() > 0.4, "the spear couched, the bear gallops (%.2f rad of stride)" % (swings.max() - swings.min()))
		var seat := (bear.get_node("Rig/Hind/Torso/Saddle") as Node3D).global_position
		var hips := cav._visual.global_position + cav._visual.global_basis.y.normalized() * cav._rider_hip() * cav._visual.scale.y
		check(hips.distance_to(seat) < 0.1, "with the rider in the saddle (%.2f m off)" % hips.distance_to(seat))
		cav._current_anim = ""
		cav._play("RideBrandish", 1.0, 0.0)
		for i in 30:
			cav._tick_mount(1.0 / 30.0, 2.0)
		var hind := bear.get_node("Rig/Hind") as Node3D
		check(hind.rotation.x < -0.25 and hind.rotation.x > -0.7, "wheeling round, the spear brandished, the bear half rears (%.2f rad)" % hind.rotation.x)
		check(cav._visual.global_position.y > seat.y - 0.3, "and its rider goes up with it")
		cav._current_anim = ""
		cav._play("RideThrust", 1.0, 0.0)
		cav._tick_mount(1.0 / 30.0, 7.0)
		check(str(bear.get_meta("act_state", "")) == "m_swipe", "the spear driven home, the bear rakes with a paw")
		cav.freeze(1.0)
		check(bear.find_children("*", "MeshInstance3D", true, false).all(func(mi: MeshInstance3D) -> bool: return mi.material_override == Zombie.ice_material()), "frozen, the bear is ice too")
		cav._show_frozen(0.0)
		cav.hp = cav.max_hp * 0.3
		cav._check_dismount()
		check(not cav._mounted and bear.visible and bear.top_level and cav._mount_fall > 0.0, "brought down, the bear falls where it is and its rider fights on foot")
		for i in 70:
			cav._tick_mount_fall(1.0 / 30.0)
		check(not bear.visible and not bear.top_level, "then it is gone")
		cav.release()
	space.queue_free()
	Game.fort_map = saved_map
	Game.mode = Game.Mode.NIGHT
	m.queue_free()


func _nearest_zombie(at: Vector3, in_world: World) -> Zombie:
	var best: Zombie = null
	for z: Zombie in in_world.zombies:
		if z.active and (best == null or z.position.distance_to(at) < best.position.distance_to(at)):
			best = z
	return best
