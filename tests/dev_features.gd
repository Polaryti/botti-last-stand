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
	await _vael_weapons()
	await _port_vael()
	await _drowned_court()
	await _coastal_campaign()
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
	var listed := ClassDefs.ALL.keys().filter(func(id: String) -> bool: return not ClassDefs.disabled(id))
	check(codex_tags.size() == listed.size(), "every enabled class in the Codex has weapon tags")
	check(not codex._list.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "Harpooner"), "the disabled Harpooner is absent from the Codex")
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
	check(level_lines.size() == ShopDefs.MAP_LEVELS * ShopDefs.in_section("maps").size(), "it lists all %d levels of each Map Upgrade (%d lines)" % [ShopDefs.MAP_LEVELS, level_lines.size()])
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
	# A world of its own, so nothing of the title screen's map behind it gets in the way.
	var space := SubViewport.new()
	space.own_world_3d = true
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
	# Both flyers leave their spawn when there is no player in their sight.
	for kind: String in ["eagle", "mist_eagle"]:
		var launch := bw.fort.heart_at + Vector3(0, 8, -55)
		if not bw.spawn_zombie(kind, launch):
			check(false, "%s spawns outside Mist Bastion" % kind)
			continue
		var bird: Zombie = bw.zombies.back()
		bird._sees = false
		bird._clear = false
		var before := Vector2(bird.position.x - bw.fort.heart_at.x, bird.position.z - bw.fort.heart_at.z).length()
		for i in 120:
			bird._fly(pl, Vector3.ZERO, before, 1.0 / 60.0)
		var after := Vector2(bird.position.x - bw.fort.heart_at.x, bird.position.z - bw.fort.heart_at.z).length()
		check(before - after > 8.0, "%s approaches Mist Bastion while it has no target in sight" % kind)
		bird.release()
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



## The Sunken Crown: the six weapons of the coast of Vael.
## The Sunken Crown, stage 2: Port Vael, its Mist Tide, its salvage and its creatures.
func _port_vael() -> void:
	# Everywhere a place is listed, Port Vael is.
	check(Game.MAPS.has("vael") and "vael" in Game.VERSUS_MAPS and "vael" in Board.MAPS, "Port Vael can be chosen for the night and for versus, and has its boards")
	check(Places.ORDER.has("vael") and Places.ALL["vael"]["tips"].size() == 3 and str(Places.ALL["vael"]["lore"]).length() > 80, "it has its page, its lore and its tips")
	check(WorldAtlas.SPOTS.has("vael") and WorldAtlas.LINKS.has(["mesenlla", "vael", false]), "the atlas road from Mesenlla leads to Port Vael")
	check(PlaceVista.LOOKS.has("vael") and Icons.exists("map_vael"), "its loading view and its icon")
	check(Sfx.MUSIC_SETS.has("vael") and (Sfx.MUSIC_SETS["vael"] as Array).all(func(n: String) -> bool: return ResourceLoader.exists("res://assets/music/%s.ogg" % n)), "its own music, night, hunted and dawn")
	check(Director.DAWN_SOUNDS.get("vael", "") == "dawn_vael" and Sfx.NAMES.has("dawn_vael"), "and its own sound at dawn")
	# The Sunken Crown's title screen: Port Vael under its aurora, and a theme of its own.
	check(Sfx.MUSIC_SETS["menu"][0] == "menu_vael" and ResourceLoader.exists("res://assets/music/menu_vael.ogg"), "the main menu has The Sunken Crown's own theme")
	check(World.MENU_TOUR_VAEL.size() >= 6 and World.MENU_TOUR_VAEL.all(func(p: Array) -> bool: return absf(p[0].x) < 110.0 and absf(p[0].z) < 110.0), "and its camera tours Port Vael, inside the map")
	# The tide's clock.
	check(is_equal_approx(MistTide.level_at(0.0), MistTide.LOW_Y) and not MistTide.is_high_at(10.0), "the night begins at low tide")
	check(MistTide.is_high_at(MistTide.TURN + 1.0) and is_equal_approx(MistTide.level_at(MistTide.TURN + MistTide.RISE), MistTide.HIGH_Y), "after %d s it comes in, taking %d s" % [int(MistTide.TURN), int(MistTide.RISE)])
	check(MistTide.level_at(MistTide.TURN + MistTide.RISE * 0.5) > MistTide.LOW_Y and MistTide.level_at(MistTide.TURN + MistTide.RISE * 0.5) < MistTide.HIGH_Y, "rising in between")
	check(not MistTide.is_high_at(MistTide.TURN * 2.0 + 1.0) and is_equal_approx(MistTide.turns_in(10.0), MistTide.TURN - 10.0), "and turns again every %d s" % int(MistTide.TURN))
	check(MistTide.ebb(0.0) == 0 and MistTide.ebb(MistTide.TURN * 2.0 + 1.0) == 1 and MistTide.ebb(MistTide.TURN * 4.0 + 1.0) == 2, "each low tide counted")
	# The map itself.
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var was_map := Game.night_map
	var was_mode := Game.mode
	Game.night_map = "vael"
	Game.mode = Game.Mode.NIGHT
	var vael := World.new()
	space.add_child(vael)
	vael.setup(Game.Mode.NIGHT)
	vael.director.set_process(false)
	for z: Zombie in vael.zombies.duplicate(): z.release()
	var you := vael.player
	you.set_physics_process(false)
	check(vael.map_id == "vael" and vael.tide != null, "Port Vael loads, with its tide")
	var t := vael.terrain
	await get_tree().physics_frame
	var lighthouse_hit := vael.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(84, 2.7, 63), Vector3(84, 2.7, 70), 1))
	check(not lighthouse_hit.is_empty() and (lighthouse_hit["position"] as Vector3).z < 67.0, "the lighthouse plinth stops characters on approach")
	var road_end := Vector3(13, 0, -84)
	var road_route := vael.grid.route(Vector3(0, 0, -53), road_end)
	check(road_route.size() > 1 and Vector2(road_route[-1].x - road_end.x, road_route[-1].z - road_end.z).length() < 2.5, "the market is linked to the lower end of Valley Road")
	await _vael_pass(vael)
	check(t.height(40, -18) > 2.4 and t.height(40, -22) > 3.7, "the town terraces grade up from the Quay without a moat")
	check(absf(t.height(0, -5) - 2.2) < 0.15 and t.height(0, -55) > 4.5, "the quay and the town above it")
	check(t.height(0, 40) < MistTide.HIGH_Y - 0.3 and t.height(0, 40) > MistTide.LOW_Y + 0.2, "the flats between low and high water")
	check(t.deep_water(0, 104) and not t.is_walkable(0, 104) and t.is_walkable(0, 40), "the open sea beyond them is no place to walk")
	# Out of the tide flats the Drowned climb by the stairs and slipways, never up the face of the
	# quay or the moles, which the path grid shuts wherever the ground rises too steeply.
	var face := 0
	var shut := 0
	for x in range(-78, 79):
		if [-55, -30, -12, 12, 30, 55].any(func(w: int) -> bool: return absi(x - w) <= 4):
			continue
		face += 1
		if vael.grid.astar.is_point_solid(vael.grid.to_cell(Vector3(x, 0, 7.0))):
			shut += 1
	check(vael.grid.fine_only and vael.grid.closed_steep > 0 and shut == face, "the face of the quay is shut to paths all along, but for its stairs and slipways (%d of %d m; %d steep cells)" % [shut, face, vael.grid.closed_steep])
	for trip: Array in [[Vector3(0, 0, 40), Vector3(0, 0, -6), "the quay"], [Vector3(-30, 0, 60), Vector3(0, 0, -55), "the market square"],
			[Vector3(60, 0, 40), Vector3(84, 0, 45), "the east mole"], [Vector3(-60, 0, 40), Vector3(-84, 0, 45), "the west mole"]]:
		var from: Vector3 = trip[0]
		var to: Vector3 = trip[1]
		var way := vael.grid.route(from, to)
		var steepest := 0.0
		for i in range(1, way.size()):
			var rise := absf(t.height(way[i].x, way[i].z) - t.height(way[i - 1].x, way[i - 1].z))
			steepest = maxf(steepest, rise / maxf(0.5, Vector2(way[i].x - way[i - 1].x, way[i].z - way[i - 1].z).length()))
		var reaches := way.size() > 1 and Vector2(way[-1].x - to.x, way[-1].z - to.z).length() < 2.5
		check(reaches and steepest < 0.95, "from the flats a path climbs to %s, by stairs or a slipway (%d points, steepest %.2f)" % [trip[2], way.size(), steepest])
	check(t.height(-84, 40) > MistTide.HIGH_Y + 0.8 and t.height(84, 40) > MistTide.HIGH_Y + 0.8, "the breakwaters stand out of the highest tide")
	await _vael_districts(vael)
	check(vael.tide.salvage().size() >= 4, "every wreck keeps a sea chest (%d)" % vael.tide.salvage().size())
	var flats := Vector3(0, t.height(0, 40), 40)
	# Low tide: dry flats, chests to open.
	vael.director.elapsed = 20.0
	vael.tide.level = MistTide.level_at(20.0)
	check(is_equal_approx(vael.tide.slow_at(flats), 1.0) and vael.tide.blind_for(flats) == 0.0, "at low tide the flats are dry")
	var chest: Dictionary = vael.tide.salvage()[0]
	var coins := Game.doubloons
	you.global_position = chest["at"]
	vael.tide._tick_salvage(20.0)
	check(Game.doubloons > coins and int(chest["taken"]) == MistTide.ebb(20.0), "you open a sea chest by walking up to it")
	coins = Game.doubloons
	vael.tide._tick_salvage(21.0)
	check(Game.doubloons == coins and not vael.tide.salvage_open(chest), "once each low tide")
	# High tide: wading, sea-mist, the Drowned quicker.
	var high_at := MistTide.TURN + MistTide.RISE + 2.0
	vael.director.elapsed = high_at
	vael.tide.level = MistTide.level_at(high_at)
	var deep := Vector3(0, t.height(0, 70), 70)
	check(vael.tide.slow_at(flats) < 1.0 and is_equal_approx(vael.tide.slow_at(deep), MistTide.SLOW) == (vael.tide.depth_at(deep) >= MistTide.SLOW_DEPTH), "at high tide wading slows you, to %d%% at its deepest" % roundi(MistTide.SLOW * 100.0))
	check(vael.tide.blind_for(deep) > 0.0 and vael.tide.blind_for(deep) <= 0.5 and vael.tide.blind_for(Vector3(0, 2.2, -5)) == 0.0, "and the sea-mist half blinds you in it, not on the quay")
	check(vael.tide.fog_scale() > 1.5, "and the fog over the harbour thickens")
	check(not vael.tide.salvage_open(chest) or (chest["at"] as Vector3).y > vael.tide.level, "a chest under the water can't be opened")
	check(vael.tide.status()["text"] == "High tide" and float(vael.tide.status()["turns_in"]) > 0.0, "the HUD shows the tide and when it turns")
	# The creatures.
	var ids := ["drowned_sailor", "barnacle_brute", "brine_hound", "lantern_jelly", "angler"]
	for id: String in ids:
		var d: Dictionary = ZombieDefs.ALL[id]
		check(SpawnRules.is_vael(d) and CodexPanel.enemy_group(id) == 5 and str(d.get("lore", "")).length() > 60 and Icons.exists(str(d["icon"])), "%s: of Vael, in the Codex with its lore and icon" % id)
		check(ZombieDefs.roams(id, 999.0, "vael") and not ZombieDefs.roams(id, 999.0, "village") and not ZombieDefs.roams(id, 999.0, "mesenlla"), "%s keeps to the coast" % id)
	check(not ZombieDefs.roams("normal", 999.0, "vael") and not ZombieDefs.roams("child_of_woods", 999.0, "vael"), "and nothing else walks in Port Vael")
	var at := Vector3(0, t.height(0, 20), 20)
	check(vael.spawn_zombie("drowned_sailor", at), "a Drowned Sailor comes up")
	var sailor: Zombie = vael.zombies.back()
	check(sailor.weapon_id in ["cutlass", "boarding_hook", "dagger"], "with a cutlass, a hook or a knife")
	sailor.state = Zombie.State.CHASE
	var quick := sailor._desired_speed()
	vael.director.elapsed = 20.0
	vael.tide.level = MistTide.LOW_Y
	check(is_equal_approx(quick / sailor._desired_speed(), MistTide.QUICKEN), "a quarter quicker while the tide is high")
	sailor.release()
	check(vael.spawn_zombie("barnacle_brute", at), "a Barnacle Brute")
	var brute: Zombie = vael.zombies.back()
	brute.rotation.y = 0.0
	var hp := brute.hp
	brute.take_damage(40.0, Vector3(0, 0, -1), 0.0, brute.centre())
	var front := hp - brute.hp
	hp = brute.hp
	brute.take_damage(40.0, Vector3(0, 0, 1), 0.0, brute.centre())
	check(is_equal_approx(front, 20.0) and is_equal_approx(hp - brute.hp, 40.0), "its crust takes half a blow from in front (%.0f), none from behind (%.0f)" % [front, hp - brute.hp])
	brute.release()
	check(vael.spawn_zombie("brine_hound", at), "a Brine Hound")
	var hound: Zombie = vael.zombies.back()
	check(hound._custom and hound._visual.has_node("Rig") and hound.mesenlla_mind != null and int(ZombieDefs.ALL["brine_hound"]["pack"]) == 3, "on its own body, hunting in packs")
	hound.release()
	check(vael.spawn_zombie("angler", at), "an Angler")
	var angler: Zombie = vael.zombies.back()
	check(angler.dormant and (angler._visual.get_node("Body") as Node3D).position.y < 0.0 and angler._visual.get_meta("buried", false), "lying buried, its lure out of the sand")
	angler._wake()
	check(not angler.dormant, "it bursts out when you come close")
	angler.release()
	check(vael.spawn_zombie("lantern_jelly", at), "a Lantern Jelly")
	var jelly: Zombie = vael.zombies.back()
	check(jelly._visual.has_node("Float/Bell/Lantern") and jelly._visual.has_node("Float/Bell/Threads/Thread0/Joint/Joint"), "a bell with its lantern and its threads")
	check(is_equal_approx(float(ZombieDefs.ALL["lantern_jelly"]["sting_stun"]), MistSeal.STING_STUN), "its sting stuns for as long as the Codex says")
	you.global_position = jelly.position + Vector3(1.0, 0, 0)
	you.frozen_left = 0.0
	you._status_immune = 0.0
	var life := you.hp
	var seal := MistSeal.create(vael, Vector3(jelly.position.x, t.height(jelly.position.x, jelly.position.z), jelly.position.z), float(ZombieDefs.ALL["lantern_jelly"]["sting_reach"]), 0.0, 0.05, 10.0, jelly.net_id, MistSeal.Style.STING)
	seal.strike()
	check(you.hp < life and is_equal_approx(you.frozen_left, MistSeal.STING_STUN) and not you.is_iced, "stung: hurt and stunned")
	seal.queue_free()
	jelly.release()
	you.frozen_left = 0.0
	# What the night brings: hounds in a pack, jellies on the high tide, Anglers buried on the shore.
	for z: Zombie in vael.zombies.duplicate(): z.release()
	you.global_position = Vector3(0, t.height(0, 30), 30)
	var d := vael.director
	d.elapsed = 400.0 # the tide is low at 400 s
	vael.tide.level = MistTide.level_at(400.0)
	d._next_rider = 0.0
	d._next_wyvern = 0.0
	d._next_ambush = 0.0
	d._tick_vael()
	check(vael.count_type("brine_hound") == int(ZombieDefs.ALL["brine_hound"]["pack"]), "Brine Hounds come up in a pack of %d" % vael.count_type("brine_hound"))
	check(vael.count_type("lantern_jelly") == 0, "no Lantern Jellies at low tide")
	var buried := vael.zombies.filter(func(z: Zombie) -> bool: return z.type_id == "angler")
	check(buried.size() == 1 and buried[0].dormant and t.height(buried[0].position.x, buried[0].position.z) < MistTide.HIGH_Y + 0.4, "an Angler lies buried on the shore")
	d.elapsed = MistTide.TURN * 5.0 + MistTide.RISE + 1.0 # high
	vael.tide.level = MistTide.HIGH_Y
	d._next_wyvern = 0.0
	d._tick_vael()
	var jellies := vael.zombies.filter(func(z: Zombie) -> bool: return z.type_id == "lantern_jelly")
	check(jellies.size() == Director.JELLIES_AT_ONCE and jellies.all(func(z: Zombie) -> bool: return vael.tide.flooded(z.position)), "the high tide brings Lantern Jellies in over the water")
	for z: Zombie in vael.zombies.duplicate(): z.release()
	await _vael_sky(vael)
	await _coastal_repairs(vael)
	await _kraken_finale(vael)
	space.queue_free()
	Game.night_map = was_map
	Game.mode = was_mode
	await get_tree().process_frame


## Valley Road's rockfall, the border mesh and the shared obstacle traversal.
func _vael_pass(vael: World) -> void:
	var terrain := vael.terrain
	var arch := Vector3(10.5, 0, -92)
	var face := vael.ground_at(arch) + 1.0
	var space := vael.get_world_3d().direct_space_state
	var a := Vector3(arch.x, face, -90)
	var b := Vector3(arch.x, face, -95)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
	check(not hit.is_empty() and (hit["position"] as Vector3).z > -91.8, "the outer boulders are solid at their visible front face")
	check(not vael.vael_sites.accessible(Vector3(13, 0, -98.5)) and terrain.slope(13, -98.5) > Terrain.STEEP, "the slope behind the rockfall is too steep for paths")
	check(terrain.coast_scenery_height(38, -119) > 42.0, "the Mesenlla skyline rises steeply beyond the playable coast")
	var edge := float(terrain.half_extent)
	var north: PackedVector3Array = terrain.skirt_mesh(0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var seam_samples := 0
	var seam_clear := true
	for v: Vector3 in north:
		if v.z == -edge:
			seam_samples += 1
			seam_clear = seam_clear and is_equal_approx(v.y, terrain.ground_height(v.x, v.z))
	check(seam_samples >= terrain.vertices_per_side and seam_clear, "northern scenery meets the playable terrain at the exact seam")
	var you := vael.player
	var original := you.global_position
	var facing := you.rotation
	you.global_position = Vector3(arch.x, vael.ground_at(a) + 0.08, -89.6)
	you.rotation.y = 0.0
	you.velocity = Vector3.ZERO
	you.input_move = Vector2(0, -1)
	you.set_physics_process(true)
	for i in 110:
		if you.is_on_floor():
			you.input_jump = true
		await get_tree().physics_frame
	check(you.global_position.z > -92.0, "a player running and jumping stops at the rockfall")
	you.set_physics_process(false)
	you.input_move = Vector2.ZERO
	you.input_jump = false
	you.velocity = Vector3.ZERO
	# The low cargo on the quay is part of the map. The lane around the cargo stays open.
	var floor_y := vael.ground_at(Vector3(5, 0, 3.7))
	you.global_position = Vector3(5, floor_y, -2.5)
	var started := vael.spawn_zombie("drowned_sailor", Vector3(3.93, floor_y, 2.69))
	check(started, "a Drowned Sailor can start on the quayside of the cargo")
	if started:
		var sailor: Zombie = vael.zombies.back()
		sailor.rotation.y = PI
		sailor._flank = Vector3.ZERO
		sailor._start_chase(you.global_position)
		sailor._sees = true
		sailor._think = 999.0
		sailor._hop_cd = 0.0
		var vaulted := false
		for i in 150:
			await get_tree().physics_frame
			vaulted = vaulted or (sailor._airborne and sailor.global_position.y > floor_y + 0.65)
			if vaulted and not sailor._airborne and sailor.global_position.z < 1.0:
				break
		check(vaulted and sailor.global_position.z < 1.0, "a Drowned Sailor vaults the quay's cargo and lands across it")
		sailor.release()
	var old_auto_jump := Game.auto_jump
	you.global_position = Vector3(5, floor_y + 0.10, 5.7)
	you.rotation.y = 0.0
	you.velocity = Vector3.ZERO
	Game.auto_jump = true
	you.input_move = Vector2(0, -1)
	you.set_physics_process(true)
	var airborne := false
	for i in 99:
		await get_tree().physics_frame
		airborne = airborne or you.global_position.y > floor_y + 0.65
		if airborne and you.is_on_floor() and you.global_position.z < 0.0:
			break
	check(airborne and you.global_position.z < 0.0 and you.is_on_floor(), "player auto-jump carries the player over the quay's cargo")
	you.set_physics_process(false)
	you.input_move = Vector2.ZERO
	you.velocity = Vector3.ZERO
	you.rotation = facing
	you.global_position = original
	Game.auto_jump = old_auto_jump


## The Port Vael districts, supply racks, and routes through the quay and its buildings.
func _vael_districts(vael: World) -> void:
	var sites := vael.vael_sites
	var spawn_failures := 0
	var you := vael.player
	var start := you.global_position
	for z: float in [-8.0, -50.0, -86.0, 30.0]:
		var at := Vector3(0, 0, z)
		at.y = vael.ground_at(at)
		you.global_position = at
		for i in 8:
			var found := sites.enemy_site()
			if found == Vector3.INF or not sites.accessible(found) or found.distance_to(you.global_position) < 16.0:
				spawn_failures += 1
	check(spawn_failures == 0, "enemy spawns find connected, unoccupied approaches from the coast, market and back lanes")
	check(vael.vael_approaches.size() >= 30 and vael.vael_approaches.all(sites.accessible), "all marked enemy approaches are walkable and connected")
	check(vael.loot_spots.size() >= 60 and vael.loot_spots.all(sites.accessible), "all marked supplies can be reached, including those inside buildings")
	var highest_floor := -INF
	for x in range(-56, -40):
		for z in range(-16, -8):
			highest_floor = maxf(highest_floor, vael.terrain.height(x + 0.5, z + 0.5))
	check(highest_floor <= 2.25, "the west steps stay clear of the Ropewalk floor")
	var roads := [
		[Vector3(-74, 0, -4), Vector3(-89, 0, -52), "Gullwatch"],
		[Vector3(-89, 0, -52), Vector3(-78, 0, -52), "Gullwatch's road to Market Row"],
		[Vector3(80, 0, -4), Vector3(87, 0, -54), "East Headland"],
		[Vector3(86, 0, -48), Vector3(77.5, 0, -83.9), "Pilgrims' Garden"],
		[Vector3(77.5, 0, -83.9), Vector3(49, 0, -71), "the garden's return route to town"],
	]
	for road: Array in roads:
		var route := vael.grid.astar.get_id_path(vael.grid.to_cell(road[0]), vael.grid.to_cell(road[1]))
		check(route.size() >= 2, "a connected route for players and mobs to %s" % road[2])
	# Check physics as well as the grid, since a route can still hit a model or turn too sharply.
	you.global_position = Vector3(0, 5, -49)
	for trip: Array in [
			[Vector3(-12, 0, 17), Vector3(-12, 0, 2), "the western slipway"],
			[Vector3(12, 0, 17), Vector3(12, 0, 2), "the eastern slipway"],
			[Vector3(-70, 0, 34), Vector3(-84, 0, 34), "the West Mole landing"],
			[Vector3(70, 0, 34), Vector3(84, 0, 34), "the East Mole landing"],
			[Vector3(-51.5, 0, -6), Vector3(-39, 0, -12), "both Ropewalk doors"],
			[Vector3(40, 0, -69), Vector3(40, 0, -82), "the Harbourmaster's House"],
		]:
		var at: Vector3 = trip[0]
		at.y = vael.ground_at(at)
		if not vael.spawn_zombie("drowned_sailor", at):
			check(false, "spawn a Drowned Sailor for %s" % trip[2])
			continue
		var sailor: Zombie = vael.zombies.back()
		sailor._think = 999.0
		sailor.state = Zombie.State.INVESTIGATE
		sailor._set_goal(trip[1])
		for i in 570:
			await get_tree().physics_frame
			if sailor._arrived():
				break
		check(sailor._arrived(), "a Drowned Sailor walks through %s" % trip[2])
		sailor.release()
	you.global_position = start
	check(vael.cache_spots.all(func(at: Vector3) -> bool: return not sites.can_stock(at + Vector3(0.4, 0, 0), false)), "ordinary loot stays out of the supply racks")
	var old_pickups := vael.pickups.duplicate()
	vael.director._tick_caches()
	var caches := vael.pickups.filter(func(item: Pickup) -> bool: return sites.holds_supplies(item.global_position))
	check(caches.size() == 4 and caches.all(func(item: Pickup) -> bool: return is_inf(item.life)), "exploration keeps a reward waiting at each of the four supply racks")
	for item: Pickup in caches:
		if not old_pickups.has(item):
			vael.remove_pickup(item)
	vael.director._cache_due.clear()
	vael.director._cache_look = 0.0


## Stage 3 of The Sunken Crown: the drowned court of Port Vael, the Hollow Sovereign and his crown.
func _drowned_court() -> void:
	var court := ["siren", "press_gang", "tide_witch", "harbourmaster", "lighthouse_keeper", "kraken_arm", "hollow_sovereign"]
	for id: String in court:
		var d: Dictionary = ZombieDefs.ALL[id]
		check(SpawnRules.is_vael(d) and VaelMind.handles(id) and str(d.get("lore", "")).length() > 60 and Icons.exists(str(d["icon"]).get_slice("+", 0)), "%s: of Vael, with its own mind, lore and icon" % id)
		check(CodexPanel.enemy_group(id) == (6 if id == "hollow_sovereign" else 5), "%s in the Codex with the drowned of Vael%s" % [id, " (with the bosses)" if id == "hollow_sovereign" else ""])
		var voices: Array = [Zombie.MESENLLA_VOICES.get(id, ""), Zombie.MESENLLA_HURT.get(id, ""), Zombie.MESENLLA_DEATHS.get(id, "")]
		check(voices.all(func(v: String) -> bool: return v != "" and Sfx.NAMES.has(v) and Net.SOUNDS.has(v) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % v)), "%s has a voice, a hurt and a death of its own" % id)
	var wanders := func(id: String) -> bool: return ZombieDefs.roams(id, 999.0, "vael") and float(ZombieDefs.ALL[id]["weight"]) > 0.0
	check(wanders.call("tide_witch") and court.filter(func(id: String) -> bool: return id != "tide_witch").all(func(id: String) -> bool: return not wanders.call(id)), "Tide Witches roam; Sirens, the Press Gang and the court come when the night sends them")
	check(["harbourmaster", "lighthouse_keeper", "kraken_arm"].all(func(id: String) -> bool: return ZombieDefs.ALL[id].get("miniboss", false)) and ZombieDefs.ALL["hollow_sovereign"].get("vael_boss", false), "three of the court are minibosses, and the Hollow Sovereign the boss")
	check(Director.BOSS_CARDS.has("hollow_sovereign") and Sfx.NAMES.has("boss_bells_sovereign") and ResourceLoader.exists("res://assets/sounds/boss_bells_sovereign.ogg"), "he enters with his own card and bells")
	check(Net.ANIMS.size() <= 64 and ["m_sting", "m_song", "m_rise", "m_sink", "Throw", "WindUp", "Raise"].all(func(a: String) -> bool: return Net.ANIMS.has(a)), "every phone is sent what they are doing (%d states)" % Net.ANIMS.size())
	check(MistSeal.Style.NET == 7 and MistSeal.Style.CROWN == 13 and MistSeal.Style.INK == 17 and MistSeal.LOOKS.size() == 18, "the new rings come after the old on the wire")
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var was_map := Game.night_map
	var was_mode := Game.mode
	Game.night_map = "vael"
	Game.mode = Game.Mode.NIGHT
	var vael := World.new()
	space.add_child(vael)
	vael.setup(Game.Mode.NIGHT)
	vael.director.running = false
	for z: Zombie in vael.zombies.duplicate(): z.release()
	var you := vael.player
	you.set_physics_process(false)
	var t := vael.terrain
	var dt := 1.0 / 60.0
	var ready_you := func() -> void:
		you.frozen_left = 0.0
		you._status_immune = 0.0
		you.rooted_left = 0.0
		you.slowed_left = 0.0
		you.burn_time = 0.0
		you._drag_left = 0.0
		you._lure_left = 0.0
		you.velocity = Vector3.ZERO
		you.hp = you.max_hp()
		you.guard_left = 0.0
	var ground := func(x: float, z: float) -> Vector3: return Vector3(x, t.height(x, z), z)
	var strike := func(at: Vector3, reach: float, kind: int, source: Zombie, amount := 10.0) -> void:
		var seal := MistSeal.create(vael, at, reach, 0.0, 0.05, amount, source.net_id if source else -1, kind)
		seal.strike()
		seal.queue_free()
	vael.director.elapsed = 20.0
	vael.tide.level = MistTide.level_at(20.0)
	# The Siren: her song draws you in, a fifth of her health struck off breaks it.
	var siren_at: Vector3 = ground.call(0.0, 30.0)
	check(vael.spawn_zombie("siren", siren_at), "a Siren")
	var siren: Zombie = vael.zombies.back()
	check(siren._custom and siren._visual.has_node("Body/Torso/Head/Hair") and siren._visual.has_node("Tail0/Tail1/Tail2") and siren._visual.has_node("Song"), "on her own body: a woman's above, an eel's tail below, her song's rings")
	ready_you.call()
	you.global_position = ground.call(0.0, 30.0 + 10.0)
	siren.mesenlla_mind.phase = "song"
	siren.mesenlla_mind.left = VaelMind.SONG_TIME
	siren._current_anim = "m_song"
	siren.mesenlla_warning = false
	VaelMind.sing(vael)
	check(you.is_lured(), "while she sings, she draws you in from %d m" % int(you.global_position.distance_to(siren.position)))
	var was := you.global_position.distance_to(siren.position)
	for i in 30:
		VaelMind.sing(vael)
		you._physics_step(dt)
	check(was - you.global_position.distance_to(siren.position) > VaelMind.SONG_PULL * 0.3, "toward her, standing still (%.2f m in half a second)" % (was - you.global_position.distance_to(siren.position)))
	you.global_position = ground.call(0.0, 30.0 + VaelMind.SONG_REACH + 3.0)
	you._lure_left = 0.0
	VaelMind.sing(vael)
	check(not you.is_lured(), "but not from beyond %d m" % int(VaelMind.SONG_REACH))
	siren.mesenlla_mind._song_from = siren.hp
	siren.take_damage(siren.max_hp * VaelMind.SONG_BREAK + 1.0, Vector3(0, 0, -1), 0.0, siren.centre())
	siren.mesenlla_mind.tick(siren, you, you.global_position - siren.position, 10.0, dt)
	check(siren.mesenlla_mind.phase == "" and siren._current_anim != "m_song", "a fifth of her health struck off breaks her song")
	siren.mesenlla_mind.phase = "song"
	siren._current_anim = "m_song"
	siren.stun(1.0)
	check(siren.mesenlla_mind.phase == "", "and so does a stun")
	siren.release()
	# The Press Gang's net holds you where you stand.
	check(vael.spawn_zombie("press_gang", ground.call(4.0, 20.0)), "a Press Gang man")
	var press: Zombie = vael.zombies.back()
	check(press.weapon_id == "boarding_hook" and press._parts.size() >= 5, "dressed for the work, a boarding hook in hand")
	ready_you.call()
	you.global_position = ground.call(0.0, 20.0)
	strike.call(you.global_position, VaelMind.NET_RADIUS, MistSeal.Style.NET, press)
	check(is_equal_approx(you.rooted_left, VaelMind.NET_HOLD), "caught in his net, you cannot move for %.1f s" % VaelMind.NET_HOLD)
	var stood := you.global_position
	press.set_physics_process(false)
	you.input_move = Vector2(0, -1)
	you.set_physics_process(true)
	await frames(20)
	you.set_physics_process(false)
	you.input_move = Vector2.ZERO
	check(Vector2(you.global_position.x - stood.x, you.global_position.z - stood.z).length() < 0.05, "however you try to walk")
	press.release()
	# The Tide Witch: a line of waves, and the drowned out of the high tide.
	check(vael.spawn_zombie("tide_witch", ground.call(0.0, 12.0)), "a Tide Witch")
	var witch: Zombie = vael.zombies.back()
	ready_you.call()
	you.global_position = ground.call(0.0, 26.0)
	var seals := vael.mist_seals.size()
	(witch.mesenlla_mind as VaelMind)._undertow(witch, you, VaelMind.WAVES, VaelMind.WAVE_RADIUS, VaelMind.WAVE_POWER)
	check(vael.mist_seals.size() - seals == VaelMind.WAVES, "%d waves roll at you in a line" % (vael.mist_seals.size() - seals))
	for seal: MistSeal in vael.mist_seals.duplicate(): seal.queue_free()
	strike.call(you.global_position, VaelMind.WAVE_RADIUS, MistSeal.Style.WAVE, witch)
	check(you.velocity.z > VaelMind.WAVE_KNOCK * 0.8 and is_equal_approx(you.slowed_left, VaelMind.WAVE_SLOW), "a wave throws you back, away from her, and slows you for %d s" % int(VaelMind.WAVE_SLOW))
	vael.director.elapsed = MistTide.TURN + MistTide.RISE + 2.0
	vael.tide.level = MistTide.HIGH_Y
	var sailors := vael.count_type("drowned_sailor")
	you.global_position = ground.call(0.0, 50.0)
	(witch.mesenlla_mind as VaelMind)._raise_drowned(witch, you)
	check(vael.count_type("drowned_sailor") - sailors == VaelMind.RAISE_COUNT, "at high tide she raises %d Drowned Sailors out of the water" % (vael.count_type("drowned_sailor") - sailors))
	for z: Zombie in vael.zombies.duplicate(): z.release()
	vael.director.elapsed = 20.0
	vael.tide.level = MistTide.level_at(20.0)
	# The Harbourmaster's hook drags you to him; at half health his bell brings a Press Gang.
	check(vael.spawn_zombie("harbourmaster", ground.call(0.0, 12.0)), "the Harbourmaster")
	var harbour: Zombie = vael.zombies.back()
	check(harbour.named_bar() and harbour.is_miniboss() and not harbour.draggable() and is_equal_approx(harbour.max_hp, 700.0 * Game.enemy_health()), "a named foe, too big to drag, %d health" % int(harbour.max_hp))
	ready_you.call()
	you.global_position = ground.call(0.0, 26.0)
	strike.call(you.global_position, VaelMind.HOOK_RADIUS, MistSeal.Style.HOOK, harbour)
	check(you.is_dragged() and is_equal_approx(you.frozen_left, VaelMind.HOOK_STUN), "his hook catches you")
	harbour.set_physics_process(false)
	you.set_physics_process(true)
	await frames(90)
	you.set_physics_process(false)
	var hauled := Vector2(you.global_position.x - harbour.position.x, you.global_position.z - harbour.position.z).length()
	check(hauled < VaelMind.HOOK_STOP + 0.8 and not you.is_dragged(), "and hauls you to his feet (%.1f m off)" % hauled)
	harbour.set_physics_process(true)
	harbour.hp = harbour.max_hp * 0.45
	var gangs := vael.count_type("press_gang")
	for i in 80:
		harbour.mesenlla_mind.tick(harbour, you, you.global_position - harbour.position, 6.0, 1.0 / 30.0)
	check(vael.count_type("press_gang") - gangs == VaelMind.BELL_GANG, "below half health he rings his bell and a Press Gang answers (%d)" % (vael.count_type("press_gang") - gangs))
	for z: Zombie in vael.zombies.duplicate(): z.release()
	# The Lighthouse Keeper: oil lamps that set you alight; his great lamp dazzles whoever looks at it.
	check(vael.spawn_zombie("lighthouse_keeper", ground.call(0.0, 12.0)), "the Mad Lighthouse Keeper")
	var keeper: Zombie = vael.zombies.back()
	check(keeper._court_light != null, "his great lamp lit on his back")
	ready_you.call()
	you.global_position = ground.call(0.0, 20.0)
	strike.call(you.global_position, VaelMind.LAMP_RADIUS, MistSeal.Style.LAMP, keeper)
	check(you.burn_time > 0.0, "his lamps set you alight")
	ready_you.call()
	you.global_position = ground.call(0.0, 18.0)
	you.rotation.y = 0.0 # looking toward -Z: at him
	you.camera.rotation = Vector3.ZERO
	strike.call(keeper.position, VaelMind.FLASH_REACH, MistSeal.Style.FLASH, keeper, 0.0)
	check(is_equal_approx(you.frozen_left, VaelMind.FLASH_STUN), "looking at him as the lamp blazes, you are dazzled for %.1f s" % VaelMind.FLASH_STUN)
	ready_you.call()
	you.rotation.y = PI # back turned
	strike.call(keeper.position, VaelMind.FLASH_REACH, MistSeal.Style.FLASH, keeper, 0.0)
	check(you.frozen_left == 0.0 and you.hp == you.max_hp(), "with your back to it, nothing")
	you.rotation.y = 0.0
	keeper.release()
	# The Kraken's arms: up out of the flooded flats at high tide, back under when it goes out.
	vael.director.elapsed = MistTide.TURN * 3.0 + MistTide.RISE + 2.0
	vael.tide.level = MistTide.HIGH_Y
	you.global_position = ground.call(-10.0, 40.0)
	var arms := vael.raise_kraken()
	check(arms >= 3 and vael.zombies.filter(func(z: Zombie) -> bool: return z.type_id == "kraken_arm").all(func(z: Zombie) -> bool: return vael.tide.flooded(z.position)), "the Kraken's arms rise out of the flooded flats round you (%d)" % arms)
	var arm: Zombie = vael.zombies.back()
	check(arm._visual.has_node("Arm/Seg0/Seg1/Seg2") and arm.named_bar(), "each a great arm of twelve joints, named")
	var was_at := arm.position
	arm.take_damage(30.0, Vector3(1, 0, 0), 8.0, arm.centre())
	for i in 10:
		arm._physics_process(dt)
	check(arm.position.distance_to(was_at) < 0.05, "rooted in the sea floor: no blow moves it")
	ready_you.call()
	strike.call(you.global_position, VaelMind.KRAKEN_RADIUS, MistSeal.Style.SLAM, arm)
	check(is_equal_approx(you.frozen_left, VaelMind.KRAKEN_STUN), "its slam stuns")
	vael.director.elapsed = MistTide.TURN * 4.0 + MistTide.RISE + 2.0 # the tide is out
	vael.tide.level = MistTide.LOW_Y
	arm.mesenlla_mind.phase = ""
	for i in int((VaelMind.SINK_TIME + 0.5) * 30.0):
		if arm.active:
			arm.mesenlla_mind.tick(arm, you, you.global_position - arm.position, 8.0, 1.0 / 30.0)
	check(not arm.active, "when the tide goes out, it sinks back into the sea")
	for z: Zombie in vael.zombies.duplicate(): z.release()
	# The Hollow Sovereign: his decrees call the tide in and raise his court; the crown falls with him.
	check(vael.director.requires_regent(), "the night at Port Vael ends only when he falls")
	vael.director.elapsed = 40.0 # low tide
	vael.tide.level = MistTide.level_at(40.0)
	check(vael.spawn_zombie("hollow_sovereign", ground.call(0.0, 44.0)), "the Hollow Sovereign rises")
	var king: Zombie = vael.zombies.back()
	check(king.is_boss() and king.named_bar() and king._parts.size() >= 6, "the boss, in his robes and his crown")
	ready_you.call()
	you.global_position = ground.call(0.0, 30.0)
	sailors = vael.count_type("drowned_sailor")
	king.hp = king.max_hp * 0.6
	for i in 50:
		king.mesenlla_mind.tick(king, you, you.global_position - king.position, 14.0, 1.0 / 30.0)
	check(vael.tide.surging() and vael.tide.high() and vael.count_type("drowned_sailor") - sailors == VaelMind.COURT, "at his decree the tide comes in out of its turn, and %d of his court rise" % (vael.count_type("drowned_sailor") - sailors))
	check(is_equal_approx(vael.tide.surge_until - vael.tide.surge_from, VaelMind.SURGE) and vael.tide.level_now(vael.director.elapsed + MistTide.RISE) > MistTide.HIGH_Y - 0.05, "for %d s" % int(VaelMind.SURGE))
	king.hp = king.max_hp * 0.45
	king._sees = true
	(king.mesenlla_mind as VaelMind)._cooldown_c = 0.0
	king.mesenlla_mind.phase = ""
	king.mesenlla_mind.tick(king, you, you.global_position - king.position, 14.0, 1.0 / 30.0)
	check(vael.mist_seals.any(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.CROWN), "below half health, the crown's judgement")
	ready_you.call()
	strike.call(you.global_position, VaelMind.JUDGEMENT_RADIUS, MistSeal.Style.CROWN, king)
	check(is_equal_approx(you.frozen_left, VaelMind.JUDGEMENT_STUN), "which stuns where it falls")
	var crowns := func() -> int: return vael.pickups.filter(func(p: Pickup) -> bool: return p.item_id == PowerDefs.CROWN).size()
	king.take_damage(king.hp + 1.0, Vector3(0, 0, 1), 0.0, king.centre())
	check(crowns.call() == 1 and vael.director._mist_boss_defeated, "he falls, and the Sunken Crown with him")
	# The crown: worn until you fall.
	ready_you.call()
	var mult := you.damage_multiplier()
	you.activate_power(PowerDefs.CROWN)
	check(is_equal_approx(you.damage_multiplier() / mult, PowerDefs.CROWN_DAMAGE) and you.skin_bits() & 2 != 0, "wearing it you hit a quarter harder, and everyone sees it on you")
	you.hp = 50.0
	you._tick_powers(1.0)
	check(is_equal_approx(you.hp, 50.0 + PowerDefs.CROWN_REGEN), "and heal %d a second" % int(PowerDefs.CROWN_REGEN))
	you._tick_powers(600.0)
	check(you.has_power(PowerDefs.CROWN), "for as long as you stand")
	for p: Pickup in vael.pickups.duplicate(): vael.remove_pickup(p)
	you._kill()
	check(not you.has_power(PowerDefs.CROWN) and crowns.call() == 1, "fall, and it falls where you do")
	you.respawn(ground.call(0.0, 0.0))
	var picked := {}
	for i in 400:
		picked[PowerDefs.pick_potion("vael")] = true
	check(not picked.has(PowerDefs.CROWN), "it is never found lying about as a potion")
	# The night sends the court at its hours.
	for z: Zombie in vael.zombies.duplicate(): z.release()
	you.global_position = ground.call(-10.0, 30.0)
	var d := vael.director
	d.elapsed = Director.HARBOURMASTER_AT + 1.0
	vael.tide.level = MistTide.level_at(d.elapsed)
	d._tick_court()
	check(vael.count_type("harbourmaster") == 1, "around %d:00 the Harbourmaster climbs the quay stairs" % int(Director.HARBOURMASTER_AT / 60.0))
	d._tick_court()
	check(vael.count_type("harbourmaster") == 1, "once")
	d.elapsed = Director.KRAKEN_AT
	vael.tide.level = MistTide.HIGH_Y
	var clear_rings := 0
	for i in 16:
		var sites := vael.vael_sites.kraken_sites(World.KRAKEN_RING, VaelMind.ARMS)
		if sites.size() == VaelMind.ARMS and sites.all(vael.tide.flooded):
			clear_rings += 1
	check(clear_rings == 16, "the Kraken finds a whole flooded ring beside the pier and wrecks")
	d._tick_court()
	check(vael.count_type("kraken_arm") >= 3, "at the high tide after 4:30, the Kraken")
	d.elapsed = Director.KEEPER_AT + 1.0
	d._tick_court()
	check(vael.count_type("lighthouse_keeper") == 1 and vael.zombies.any(func(z: Zombie) -> bool: return z.type_id == "lighthouse_keeper" and z.position.x > 70.0), "and around %d:00 the Lighthouse Keeper, down the East Mole" % int(Director.KEEPER_AT / 60.0))
	for z: Zombie in vael.zombies.duplicate(): z.release()
	d._next_siren = 0.0
	d._next_press = 0.0
	d.elapsed = 400.0
	vael.tide.level = MistTide.level_at(400.0)
	d._tick_court()
	check(vael.count_type("siren") == 1 and vael.count_type("press_gang") == int(ZombieDefs.ALL["press_gang"]["pack"]), "Sirens come to the water's edge, and the Press Gang in threes")
	space.queue_free()
	Game.night_map = was_map
	Game.mode = was_mode
	await get_tree().process_frame


func _last_light() -> void:
	# The map, and how it is known.
	check(Game.MAPS.has("lantern_road") and Places.ALL.has("lantern_road") and Places.ORDER.has("lantern_road") and WorldAtlas.SPOTS.has("lantern_road") and Icons.exists("map_lantern_road"), "the Lantern Road is a map of its own, in the Places, on the atlas, with its icon")
	check(ResourceLoader.exists("res://maps/lantern_road.tscn") and Sfx.MUSIC_SETS.has("lantern") and (Sfx.MUSIC_SETS["lantern"] as Array).all(func(m: String) -> bool: return ResourceLoader.exists("res://assets/music/%s.ogg" % m)), "with its own music")
	var levi: Dictionary = ZombieDefs.ALL["leviathan"]
	check(levi.get("vael_boss", false) and VaelMind.handles("leviathan") and Icons.exists("leviathan") and str(levi.get("lore", "")).length() > 60 and CodexPanel.enemy_group("leviathan") == 6, "the Leviathan of the Mists: a boss of Vael, with its own mind, icon, lore and place in the Codex")
	var voices: Array = [Zombie.MESENLLA_VOICES.get("leviathan", ""), Zombie.MESENLLA_HURT.get("leviathan", ""), Zombie.MESENLLA_DEATHS.get("leviathan", ""), "leviathan_bite", "leviathan_rise", "waystation", "lighthouse_lit", "boss_bells_leviathan"]
	check(voices.all(func(v: String) -> bool: return v != "" and Sfx.NAMES.has(v) and Net.SOUNDS.has(v) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % v)), "it and the road have sounds of their own")
	check(Director.BOSS_CARDS.has("leviathan"), "it enters with its own card")
	check(Boons.ALL.size() >= Boons.OFFERED * 2 and Boons.ALL.values().all(func(b: Dictionary) -> bool: return Icons.exists(str(b["icon"]).get_slice("+", 0)) and str(b["desc"]).length() > 10), "the waystations' boons, each with an icon and words")
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var was_map := Game.night_map
	var was_mode := Game.mode
	Game.night_map = "lantern_road"
	Game.mode = Game.Mode.NIGHT
	var road := World.new()
	space.add_child(road)
	road.setup(Game.Mode.NIGHT)
	road.director.running = false
	for z: Zombie in road.zombies.duplicate(): z.release()
	var ll := road.last_light
	check(ll != null and ll.length > 300.0, "Last Light: the barge's course runs %d m" % int(ll.length if ll else 0.0))
	if ll == null:
		space.queue_free()
		Game.night_map = was_map
		Game.mode = was_mode
		return
	ll.set_physics_process(false)
	# The barge floats: every metre of its course, under it, beside it and just ahead of it, is under
	# the Lantern Road's sea, which never goes out, and none of it crosses the road.
	var dry := 0
	var worst := -9.0
	var d := 0.0
	while d < ll.length:
		var at := ll.path.sample_baked(d)
		var ahead := ll.path.sample_baked(minf(ll.length, d + 1.0))
		var dir := Vector3(ahead.x - at.x, 0, ahead.z - at.z).normalized()
		if dir == Vector3.ZERO:
			dir = Vector3.FORWARD
		var side := dir.cross(Vector3.UP)
		for off: Vector3 in [Vector3.ZERO, side * 2.1, -side * 2.1, dir * 4.0 + side * 2.1, dir * 4.0 - side * 2.1]:
			var g := road.terrain.height(at.x + off.x, at.z + off.z)
			worst = maxf(worst, g)
			if g > MistTide.HIGH_Y - 0.3:
				dry += 1
		d += 1.0
	check(road.tide.always_high and dry == 0, "the barge's whole course is water, never land (highest ground under it %.2f m, the sea %.2f m)" % [worst, MistTide.HIGH_Y])
	check(ll.way_at.size() == 3 and road.road_lanterns.size() >= 20 and road.lighthouse_top != Vector3.INF, "three waystations, %d road lanterns, and the lighthouse at the end" % road.road_lanterns.size())
	check(road.tide.level >= MistTide.HIGH_Y - 0.01, "the tide is in, and stays in")
	var you := road.player
	you.set_physics_process(false)
	var dt := 1.0 / 30.0
	var step := func(seconds: float) -> void:
		for i in int(seconds / dt):
			ll._physics_process(dt)
	var start := ll.barge_at()
	check(road.terrain.is_walkable(start.x + 5.4, start.z) or road.terrain.is_walkable(start.x - 5.4, start.z) or road.terrain.is_walkable(start.x, start.z), "the barge sets out beside the quay")
	# Walk with it, and it goes; leave it, and it stops.
	you.global_position = start + Vector3(-5.0, 0.6, 0)
	step.call(2.0)
	check(ll.moving and ll.progress > LastLight.BARGE_SPEED * 1.5, "with you beside it, the barge goes on (%.1f m in 2 s)" % ll.progress)
	you.global_position = ll.barge_at() + Vector3(-30.0, 0.6, 0)
	var was := ll.progress
	step.call(1.0)
	check(not ll.moving and is_equal_approx(ll.progress, was), "with nobody near it, it stops")
	# Out of its light, the tide drowns you after a few seconds' grace.
	you.global_position = ll.barge_at() + Vector3(-5.0, 0.6, 0)
	ll._out.clear()
	you.global_position = ll.barge_at() + Vector3(-30.0, 0.6, 0)
	you.hp = you.max_hp()
	step.call(LastLight.OUT_GRACE - 0.5)
	check(is_equal_approx(you.hp, you.max_hp()), "%d s out of the light before the tide takes you" % int(LastLight.OUT_GRACE))
	step.call(1.5)
	var lost := you.max_hp() - you.hp
	check(lost > LastLight.DROWN * 0.5 and lost < LastLight.DROWN * 1.6, "then %d health a second (%.1f lost)" % [int(LastLight.DROWN), lost])
	you.global_position = ll.barge_at() + Vector3(-5.0, 0.6, 0)
	you.hp = you.max_hp()
	step.call(1.0)
	check(is_equal_approx(you.hp, you.max_hp()) and ll.out_for(you) == 0.0, "back in the light, you are safe")
	# Something of the sea in the barge holds it.
	road.spawn_zombie("drowned_sailor", ll.barge_at() + Vector3(0, 0.5, 0))
	var sailor: Zombie = road.zombies.back()
	sailor.set_physics_process(false)
	sailor.position = ll.barge_at() + Vector3(0, 0.5, 0)
	was = ll.progress
	step.call(1.0)
	check(ll.held and not ll.moving and is_equal_approx(ll.progress, was), "a Drowned Sailor aboard holds the barge where it is")
	sailor.release()
	step.call(0.5)
	check(ll.moving, "throw it off, and it goes on")
	# The lanterns it passes light up.
	ll.progress = 40.0
	ll._place(0.0)
	you.global_position = ll.barge_at() + Vector3(-5.0, 0.6, 0)
	step.call(0.5)
	check(ll.lanterns_lit() >= 1, "it lights the road's lanterns as it passes (%d)" % ll.lanterns_lit())
	# The first waystation: healed, three boons, and the barge waits.
	ll.progress = ll.way_at[0] - 0.5
	ll._place(0.0)
	you.global_position = ll.barge_at() + Vector3(-5.0, 0.6, 0)
	you.hp = you.max_hp() * 0.3
	step.call(0.6)
	check(ll.docked == 0 and not ll.moving, "at a waystation the barge stops")
	check(you.hp >= you.max_hp() * (0.3 + LastLight.WAY_HEAL) - 1.0, "everyone there is healed %d%% of their health" % int(LastLight.WAY_HEAL * 100.0))
	check(ll.offer.size() == Boons.OFFERED and ll.offer == Boons.offer_for(you, 0), "and offered %d boons" % Boons.OFFERED)
	ll.choose("salt_ward") if ll.offer.has("salt_ward") else ll.choose(ll.offer[0])
	var took := you.boons[0] if not you.boons.is_empty() else ""
	check(took != "" and ll.offer.is_empty() and not Boons.offer_for(you, 1).has(took), "one is chosen (%s), and never offered again" % took)
	Boons.grant(you, "salt_ward")
	Boons.grant(you, "lamplighter")
	check(is_equal_approx(float(you.mods["damage_taken"]), 0.8) and is_equal_approx(float(you.mods["melee_damage"]), 1.2), "Salt Ward takes a fifth off every blow; Lamplighter's Fury adds a fifth to yours")
	step.call(0.2)
	check(ll.docked == -1 and road.count_type(LastLight.WAY_FOES[0][0]) == int(LastLight.WAY_FOES[0][1]), "once all have chosen it leaves, and a Press Gang waits on the road ahead")
	for z: Zombie in road.zombies.duplicate(): z.release()
	# Deep Lungs and the Lantern Bearer.
	Boons.grant(you, "deep_lungs")
	Boons.grant(you, "lantern_bearer")
	check(Boons.grace(you) == Boons.DEEP_GRACE and Boons.drown_share(you) == Boons.DEEP_SHARE and Boons.light_bonus(you) == Boons.BEARER_REACH, "Deep Lungs: %d s of grace and half the drowning; the Lantern Bearer: the light %d m further" % [int(Boons.DEEP_GRACE), int(Boons.BEARER_REACH)])
	you.global_position = ll.barge_at() + Vector3(-(LastLight.LIGHT_RADIUS + 2.0), 0.6, 0)
	you.hp = you.max_hp()
	step.call(1.0)
	check(ll.out_for(you) == 0.0, "so %d m from the barge is still in its light for them" % int(LastLight.LIGHT_RADIUS + 2.0))
	# The Isle of Lamps: the Leviathan rises.
	ll.progress = ll.length - 0.3
	ll.ways_done = ll.way_at.size()
	ll._place(0.0)
	you.global_position = ll.barge_at() + Vector3(-5.0, 0.6, 0)
	step.call(0.5)
	check(ll.arrived and road.count_type("leviathan") == 1, "at the Isle of Lamps the Leviathan rises from the sea")
	var beast: Zombie = road.zombies.filter(func(z: Zombie) -> bool: return z.type_id == "leviathan").front()
	check(beast._custom and beast._visual.has_node("Body/Neck0") and beast.is_boss(), "a sea-serpent's neck of its own, and a boss")
	check(road.director.dawn_amount() < 0.5, "and it is still night")
	# It douses the barge's light.
	var mind: VaelMind = beast.mesenlla_mind
	mind.phase = ""
	mind._cooldown_d = 99.0
	mind._cooldown_e = 0.0
	mind._leviathan(beast, you, 0.01)
	check(ll.dim_left > 0.0 and is_equal_approx(ll.light_radius(), LastLight.DIM_RADIUS), "it spits the sea over the barge: the light shrinks to %d m for %d s" % [int(LastLight.DIM_RADIUS), int(LastLight.DIM_TIME)])
	# It sinks, and rises somewhere else with Drowned Sailors.
	var first := beast.position
	mind.phase = "sink"
	mind.left = 0.0
	mind._leviathan(beast, you, 0.01)
	check(beast.position.distance_to(first) > 3.0 and road.count_type("drowned_sailor") >= 1, "it dives and comes up elsewhere round the isle, with Drowned Sailors")
	# It falls, and the lighthouse burns: the dawn.
	road.director._mist_boss_defeated = true
	step.call(0.2)
	road.director.running = true
	var dawn := road.director.dawn_amount()
	road.director.running = false
	check(ll.lit and dawn >= 1.0, "when it falls, the lighthouse burns again, and that is the dawn")
	var counted := Game.lighthouses_lit
	Game.note_last_light()
	check(Game.lighthouses_lit == counted + 1, "and it is counted (%d)" % Game.lighthouses_lit)
	Game.lighthouses_lit = counted
	space.queue_free()
	Game.night_map = was_map
	Game.mode = was_mode
	await get_tree().process_frame


func _vael_weapons() -> void:
	var ids := ["cutlass", "boarding_hook", "harpoon", "flare_pistol", "anchor", "oar"]
	# The Sandbox lays out every weapon, potion and familiar: all of them inside the play area, now
	# that there are more weapons than fit in one row (they ran out past the edge of the yard).
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var was_mode := Game.mode
	Game.mode = Game.Mode.SANDBOX
	var yard := World.new()
	space.add_child(yard)
	yard.setup(Game.Mode.SANDBOX)
	yard.player.set_physics_process(false)
	var laid: Array[Dictionary] = yard._stand_items
	var weapons_laid := laid.filter(func(s: Dictionary) -> bool: return s["kind"] == Pickup.Kind.WEAPON).map(func(s: Dictionary) -> String: return s["id"])
	check(WeaponDefs.ALL.keys().filter(func(id: String) -> bool: return WeaponDefs.lies_around(id)).all(func(id: String) -> bool: return weapons_laid.has(id)), "the Sandbox lays out every weapon, the coast's too")
	check(laid.all(func(s: Dictionary) -> bool: return yard._inside_play(s["at"], 2.0)), "every one of them inside the yard (%d things)" % laid.size())
	var apart := true
	for i in laid.size():
		for j in range(i + 1, laid.size()):
			if (laid[i]["at"] as Vector3).distance_to(laid[j]["at"]) < 2.0:
				apart = false
	check(apart, "and none on top of another")
	space.queue_free()
	Game.mode = was_mode
	await get_tree().process_frame
	for id: String in ids:
		var d: Dictionary = WeaponDefs.ALL[id]
		check(WeaponDefs.lies_around(id) and SpawnRules.allows(d, "vael") and SpawnRules.allows(d, "lantern_road") and not SpawnRules.allows(d, "village") and SpawnRules.names(d) == "Vael", "%s lies about only on the coast of Vael" % id)
		check(WeaponDefs.mesh(id) != null and Icons.weapon(id) == id and ResourceLoader.exists("res://assets/icons/%s.png" % id), "%s has its own model and icon" % id)
		check(str(d.get("lore", "")).length() > 40 and not RegEx.create_from_string("\\d").search(str(d["lore"])), "%s has a story of its own, with no numbers in it" % id)
	check(WeaponDefs.category("anchor") == "two_handed" and WeaponDefs.category("oar") == "two_handed" and WeaponDefs.category("cutlass") == "melee" and WeaponDefs.category("boarding_hook") == "melee" and WeaponDefs.category("harpoon") == "ranged" and WeaponDefs.category("flare_pistol") == "ranged", "two melee, two ranged, two two-handed")
	for sound: String in ["cutlass_swing", "hook_swing", "hook_catch", "harpoon_throw", "harpoon_hit", "harpoon_reel", "flare_shot", "flare_burst", "anchor_heave", "anchor_slam", "oar_sweep"]:
		check(ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound) and Sfx.NAMES.has(sound), "%s sound" % sound)
	for key: String in ["slam", "hook", "row"]:
		check(WeaponAnim.KEYS.has(key + "_a") and WeaponAnim.REST_DIRS.has(key), "a first-person %s" % key)
	check(BodyAnim.attack_for("anchor") == "Overhead" and BodyAnim.attack_for("boarding_hook") == "Thrust" and BodyAnim.attack_for("flare_pistol") == "Spellcast_Shoot" and BodyAnim.attack_for("harpoon") == "Throw", "and their moves as others see them")
	var codex := CodexPanel.new()
	add_child(codex)
	codex._list = VBoxContainer.new()
	codex.add_child(codex._list)
	codex._weapons()
	var texts: Array = codex._list.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(ids.all(func(id: String) -> bool: return texts.has(WeaponDefs.ALL[id]["desc"] + "\n" + WeaponDefs.ALL[id]["lore"])), "the Codex tells what each does and where it comes from")
	codex.queue_free()
	p.setup_class("infantry")
	p.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	var at_front := func(dist: float, kind := "normal") -> Zombie:
		w.spawn_zombie(kind, p.global_position + Vector3(0, 0, -dist))
		var zz: Zombie = w.zombies.back()
		zz.set_physics_process(false)
		zz.position = p.global_position + Vector3(0, 0, -dist)
		zz.hp = 5000.0
		zz.max_hp = 5000.0
		return zz
	# Cutlass: each kill quickens the swings, up to three times, fading 3 s after the last.
	p.slots = ["cutlass", null]
	p.current = 0
	p._equip()
	var cut: Dictionary = WeaponDefs.ALL["cutlass"]
	var base := p.attack_interval(cut)
	for i in 4:
		p._on_kill(at_front.call(30.0 + i))
	check(p._fervour == 3 and is_equal_approx(p.attack_interval(cut), base / (1.0 + 3 * 0.15)), "four kills with a Cutlass: three times quicker by 15%% (%.3f s a swing, from %.3f)" % [p.attack_interval(cut), base])
	check(p.readiness().any(func(r: Dictionary) -> bool: return r["key"] == "fervour" and r["have"] == 3), "the HUD shows it")
	for i in 200:
		p._process(1.0 / 60.0)
	check(p._fervour == 0 and is_equal_approx(p.attack_interval(cut), base), "and it fades a few seconds after the last kill")
	for zz: Zombie in w.zombies.duplicate(): zz.release()
	# Boarding Hook: drags one in about 1.6 m, staggered; a boss is only staggered.
	p.slots = ["boarding_hook", null]
	p._equip()
	var hooked: Zombie = at_front.call(2.8)
	p._do_melee_hit()
	check(hooked._stun > 0.2, "hooked, it is off balance")
	# Knock fades at 8 a second, so a knock of K carries a body about K / 8 metres.
	var pull := hooked._knock
	check(pull.z > 0.0 and absf(pull.length() / 8.0 - 1.6) < 0.05, "and dragged towards you, about 1.6 m (%.2f m)" % (pull.length() / 8.0))
	hooked.set_physics_process(true)
	var was := hooked.position.distance_to(p.global_position)
	for i in 20:
		await get_tree().physics_frame
	check(was - hooked.position.distance_to(p.global_position) > 0.8, "and it really comes")
	hooked.release()
	var big: Zombie = at_front.call(2.8)
	big.def = big.def.duplicate()
	big.def["mesenlla_boss"] = true # the village keeps no boss bodies: this one stands in for one
	p._do_melee_hit()
	check(not big.draggable() and big._knock.length() < 0.01 and big._stun == 0.0, "bosses resist the hook without stagger")
	big.release()
	# Whaler's Harpoon: pins what it strikes, lies where it lands, comes back when you walk over it.
	p.slots = ["harpoon", "sword"]
	p.current = 0
	p.own_ammo.clear()
	p._equip()
	var whale: Zombie = at_front.call(10.0)
	var arrows_before := p.arrows
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(p.harpoon_out and p.arrows == arrows_before and not p._vm_mesh.visible, "thrown: it is out of your hand, and spent no arrows")
	for i in 60:
		await get_tree().physics_frame
	check(whale.root_left > 1.5 and whale.hp < 5000.0, "it struck and pinned what it hit (%.1f s)" % whale.root_left)
	var lying: Node3D = w.harpoons.get(p.net_id(), null)
	check(lying != null and lying.global_position.distance_to(whale.position) < 2.0, "and lies by it")
	p._cooldown = 0.0
	var flying := w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size()
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(w._projectiles.filter(func(q: Projectile) -> bool: return q.active).size() == flying, "with it out, there is nothing to throw")
	p.global_position = lying.global_position + Vector3(0.5, 0, 0)
	p._tick_harpoon(0.02)
	check(not p.harpoon_out and not w.harpoons.has(p.net_id()) and p._vm_mesh.visible, "walking over it takes it back")
	p.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	whale.release()
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	for i in 90:
		await get_tree().physics_frame
	check(p.harpoon_out and w.harpoons.has(p.net_id()), "thrown at nothing, it lies on the ground")
	p._tick_harpoon(16.0)
	check(not p.harpoon_out and not w.harpoons.has(p.net_id()), "and after 15 s it is back in your hand by itself")
	# Flare Pistol: 6 flares a pistol; a flare burns all within 3 m and shows all within 7 m for 8 s.
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	p.slots = ["sword", null]
	p._equip()
	var gun := w.spawn_pickup_at(p.global_position + Vector3(0.6, 0, 0), Pickup.Kind.WEAPON, "flare_pistol")
	check(gun.throws() == 6, "a Flare Pistol found lying about brings 6 flares")
	w._scan_pickups_for(p)
	check(p.carries("flare_pistol") and p.ammo_of("flare_pistol") == 6, "picked up, 6 flares")
	p.current = p.slots.find("flare_pistol")
	p._equip()
	var near: Zombie = at_front.call(12.0)
	var side: Zombie = at_front.call(12.0)
	side.position += Vector3(2.0, 0, 0)
	var far_one: Zombie = at_front.call(12.0)
	far_one.position += Vector3(5.5, 0, 0)
	p.camera.rotation.x = -0.12
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(p.ammo_of("flare_pistol") == 5, "a shot spends one flare")
	var flares := []
	for i in 90:
		await get_tree().physics_frame
		flares = w.find_children("Flare", "Flare", false, false)
		if not flares.is_empty():
			break
	check(flares.size() == 1, "the flare lands and burns")
	if flares.size() == 1:
		var f: Flare = flares[0]
		var burning := [near, side].filter(func(zz: Zombie) -> bool: return zz.burn_time > 0.0 and zz.position.distance_to(f.global_position) <= Flare.BURN_RADIUS + 0.8)
		check(not burning.is_empty(), "setting alight what is close by")
		for i in 40:
			await get_tree().process_frame
		check(far_one.position.distance_to(f.global_position) < Flare.REVEAL_RADIUS and far_one.revealed_left > 0.0, "and showing what stands in its light")
		f.queue_free()
	# Test a direct body hit separately from the ballistic shot that checks burning and reveal.
	var lodged_shot := w.spawn_player_arrow(p, near.centre() + Vector3.BACK, Vector3.FORWARD * 24.0, 0.0, 12.0, 0.0, 1.0)
	lodged_shot._hit_zombie(near, near.centre())
	var lodged := w.get_children().back() as Flare
	check(lodged != null and lodged._target == near, "a direct flare hit lodges in the enemy")
	if lodged:
		var hit_at := lodged.global_position
		near.position.x += 1.0
		lodged._process(0.01)
		check(is_equal_approx(lodged.global_position.x, hit_at.x + 1.0), "a lodged flare follows its living target")
		near.take_damage(10000.0, Vector3.ZERO, 0.0, near.centre())
		lodged._process(0.01)
		check(lodged._target == null and absf(lodged.global_position.y - w.ground_at(lodged.global_position)) < 0.15, "a lodged flare drops to the ground when its target dies")
		lodged.queue_free()
	for zz: Zombie in [near, side, far_one]: zz.release()
	p.own_ammo["flare_pistol"] = 1
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(not p.carries("flare_pistol"), "the last flare fired, the pistol is gone")
	# Ship's Anchor: the slam shakes everything within 4.5 m, and you walk slower carrying it.
	p.slots = ["anchor", null]
	p.current = 0
	p._equip()
	check(p.can_use("anchor"), "an Infantry can wield it")
	var front: Zombie = at_front.call(1.8)
	var behind: Zombie = at_front.call(-3.0)
	p._do_melee_hit()
	check(front.hp < 5000.0, "the anchor's blow lands")
	check(behind.hp < 5000.0 and behind._stun > 0.3 and 5000.0 - behind.hp < (5000.0 - front.hp) * 0.75, "and the ground shakes behind you too: a share of the blow, staggered")
	for zz: Zombie in [front, behind]: zz.release()
	var slow_speed: float = p.weapon_def().get("burden", 1.0)
	check(is_equal_approx(slow_speed, 0.9), "carrying it, 90% speed")
	# Ferryman's Oar: wide, shoves far and slows.
	p.slots = ["oar", null]
	p._equip()
	var rowed: Zombie = at_front.call(2.2)
	p._do_melee_hit()
	check(rowed._slow > 0.5, "struck by the oar, it is slowed")
	rowed.release()
	p.setup_class("infantry")
	p.slots = ["sword", null]
	p._equip()


## Coastal flyers exercise real wind-ups, dodges, interruption, damage and pool reuse.
func _vael_sky(vael: World) -> void:
	for seal: MistSeal in vael.mist_seals.duplicate(): seal.queue_free()
	await frames(1)
	var you := vael.player
	var saved := you.position
	var at := Vector3(0, vael.ground_at(Vector3(0, 0, 40)), 40)
	you.position = at
	you.guard_left = 0.0
	for id: String in VaelSkyMind.KINDS:
		check(ZombieDefs.roams(id, 600, "vael") and not ZombieDefs.roams(id, 600, "lantern_road") and not ZombieDefs.roams(id, 600, "village"), id + " stays in Port Vael")
		check(not ZombieDefs.roams(id, 10, "vael") and Icons.exists(id) and CodexPanel.enemy_group(id) == 5, id + " has a timed arrival, icon and Codex entry")
		for suffix: String in ["call", "release", "hurt", "death"]:
			check(Sfx.NAMES.has(id + "_" + suffix) and Net.SOUNDS.has(id + "_" + suffix), id + " has its own " + suffix)
		check(vael.spawn_zombie(id, at + Vector3(0, 0, -10)), id + " spawns from its pool")
		var z: Zombie = vael.zombies.back()
		z.set_physics_process(false)
		z._sees = true
		var mind := z.mesenlla_mind as VaelSkyMind
		check(z.flies and mind != null and z.position.y > vael.ground_at(z.position) + 2, id + " flies with its own mind")
		mind.cooldown = 0
		mind.tick(z, you, Vector3.ZERO, 10, 0)
		check(mind.phase == "tell" and z.is_warning() and vael.mist_seals.is_empty(), id + " warns before releasing damage")
		z._animate_custom(0.1, 1)
		# Stun before release prevents any attack.
		z.stun(0.6)
		check(mind.phase == "" and not z.is_warning() and vael.mist_seals.is_empty(), id + " stun interrupts wind-up")
		z._stun = 0
		z._sees = true
		mind.cooldown = 0
		mind.tick(z, you, Vector3.ZERO, 10, 0)
		mind.tick(z, you, Vector3.ZERO, 10, float(VaelSkyMind.TELLS[id]) + 0.01)
		check(mind.phase == "recover" and not z.is_warning() and not vael.mist_seals.is_empty(), id + " releases and enters recovery")
		var shots := vael.mist_seals.duplicate()
		check(shots.size() == (3 if id == "storm_ray" else 1), id + " has the right attack pattern")
		var seal: MistSeal = shots[0]
		seal.set_physics_process(false)
		var hit_at := seal.position + (Vector3.RIGHT * 2.7 if id == "bell_wraith" else Vector3.ZERO)
		you.position = hit_at + Vector3.RIGHT * 10
		you.hp = you.max_hp()
		var hp_before := you.hp
		seal.strike()
		check(you.hp == hp_before, id + " can be dodged")
		you.position = seal.position if id == "bell_wraith" else hit_at
		if id == "bell_wraith":
			seal.strike()
			check(you.hp == hp_before and not seal.contains(you.position), "the knell has a safe centre")
		you.position = hit_at
		you._status_immune = 0
		you.frozen_left = 0
		you.guard_left = 0
		seal.strike()
		check(you.hp < hp_before, id + " hurts inside the marked area")
		for s: MistSeal in shots: s.queue_free()
		await frames(1)
		# Joined phones display the same pose and tell from snapshot state.
		z.puppet = true
		z.net_apply(z.position, 0, 64, 1.0, "m_cast", 1.0)
		z._animate_custom(0.1, 1)
		check(z.is_warning() and z._current_anim == "m_cast", id + " receives its ranged pose on a joined phone")
		z.puppet = false
		# Low recovery reaches a hittable height; steering stays in the playable bounds.
		you.position = at
		mind.phase = "recover"
		mind.left = VaelSkyMind.RECOVERY
		for i in 108: mind.tick(z, you, Vector3.ZERO, 10, 1.0 / 60)
		check(z.position.y < at.y + 2.5 and absf(z.position.x) < vael.half_size, id + " recovers low inside map bounds")
		z.release()
		check(vael.spawn_zombie(id, at + Vector3(0, 0, -10)), id + " reuses its pooled body")
		z = vael.zombies.back()
		check(z._current_anim == "" and not z.is_warning() and (z.mesenlla_mind as VaelSkyMind).phase == "", id + " clears its attack when reused")
		z.set_physics_process(false)
		z._die()
		z._physics_process(0.1)
		z.release()
	check(MistSeal.Style.SALT == 14 and MistSeal.Style.KNELL == 16 and Net.ANIMS.size() <= 64, "coastal impacts append wire styles and reuse animation slots")
	# With all three ranged slots occupied, the director keeps spawning ground enemies.
	for id: String in VaelSkyMind.KINDS: vael.spawn_zombie(id, at + Vector3(0, 0, -15))
	vael.director.elapsed = 600
	for i in 50: check(vael.director._pick_roamer() not in VaelSkyMind.KINDS, "the ranged population is capped at three")
	for z: Zombie in vael.zombies.duplicate(): z.release()
	you.position = at
	vael.director.elapsed = 690.0
	vael.director._tick_vael()
	check(vael.count_type("leviathan") == 1, "the former road boss rises in the harbour at 11:30")
	vael.director._tick_vael()
	check(vael.count_type("leviathan") == 1, "the coastal Leviathan is summoned once")
	for z: Zombie in vael.zombies.duplicate(): z.release()
	you.position = saved


## The Kraken, the end of Port Vael's night: it rises only once the Hollow Sovereign and the Leviathan
## have both fallen, holds the tide in, can be struck by blade, arrow and Trident, uses each of its
## arts in its own third of its health, and dawn waits for it.
func _kraken_finale(coast: World) -> void:
	var d := coast.director
	var you := coast.player
	var saved := you.position
	for z: Zombie in coast.zombies.duplicate(): z.release()
	var def: Dictionary = ZombieDefs.ALL[Director.KRAKEN]
	check(def.get("vael_boss", false) and def.get("rooted", false) and VaelMind.handles(Director.KRAKEN) and Icons.exists("kraken") and Director.BOSS_CARDS.has(Director.KRAKEN)
		and Game.zombie_pool_plan().has(Director.KRAKEN) and str(def.get("lore", "")).length() > 80, "the Kraken is the coast's last boss, with its card, its icon and its lore")
	for sound: String in ["kraken_emerge", "kraken_roar", "kraken_ink", "kraken_whirlpool", "kraken_end", "boss_bells_kraken"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	# It waits for both royals.
	d._kraken_at = -1.0
	d._kraken_risen = false
	d._kraken_fallen = false
	d._mist_boss_defeated = false
	d._coastal_leviathan = true
	d.elapsed = 800.0
	d._tick_kraken()
	check(d._kraken_at < 0.0 and coast.count_type(Director.KRAKEN) == 0, "not while the Hollow Sovereign stands")
	d._mist_boss_defeated = true
	coast.spawn_zombie("leviathan", coast.vael_sites.enemy_site(15.0, 190.0, VaelSites.Shore.WATERLINE))
	d._tick_kraken()
	check(d._kraken_at < 0.0, "nor while the Leviathan does")
	for z: Zombie in coast.zombies.duplicate(): z.release()
	d._tick_kraken()
	check(d._kraken_at >= d.elapsed + Director.KRAKEN_AFTER - 0.01 and coast.count_type(Director.KRAKEN) == 0, "once both have fallen, the harbour goes still for %d s" % int(Director.KRAKEN_AFTER))
	d.elapsed = d._kraken_at + 0.1
	d._tick_kraken()
	check(coast.count_type(Director.KRAKEN) == 1 and d._kraken_risen and coast.tide.surging(), "then the Kraken rises, and holds the tide in")
	var beast: Zombie = coast.zombies.filter(func(z: Zombie) -> bool: return z.type_id == Director.KRAKEN).front()
	check(Vector2(beast.position.x - Director.KRAKEN_FROM.x, beast.position.z - Director.KRAKEN_FROM.z).length() < 4.0, "in front of the quay")
	check(beast._visual.find_children("Arm*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.name.begins_with("Arm") and n.name.length() == 4).size() == KrakenModels.ARMS
		and beast._visual.get_node_or_null("Body/Crown") != null and beast._visual.get_node_or_null("Body/Eyes") != null, "eight arms, its crown of drowned towers, its eyes")
	# It can be struck: by a blade from the water's edge, by an arrow, by the Trident.
	beast.set_physics_process(false)
	var mind := beast.mesenlla_mind as VaelMind
	mind.phase = ""
	beast.hp = beast.max_hp
	var edge := beast.position + Vector3(0, 0, -(VaelMind.KRAKEN_BODY + 2.0))
	you.position = Vector3(edge.x, coast.ground_at(edge), edge.z)
	you.look_at(Vector3(beast.position.x, you.position.y, beast.position.z), Vector3.UP)
	you.yaw = you.rotation.y
	var h0 := beast.hp
	you.pitch = 0.0
	you.camera.rotation = Vector3.ZERO
	var sword: Dictionary = WeaponDefs.ALL["sword"]
	var hit := coast.melee_hit(you, sword, you.melee_stats(sword))
	check(hit > 0 and beast.hp < h0, "a blade from the water's edge reaches it (%.0f)" % (h0 - beast.hp))
	# Struck, it flashes, but its whirlpool keeps its own shader: animating it must still find it.
	var whirl := beast._visual.get_node("Whirl") as MeshInstance3D
	check(beast._flash > 0.0 and whirl.material_override is ShaderMaterial and not beast._parts.has(whirl), "a blow flashes the Kraken but not its whirlpool")
	var foams := beast._visual.find_children("*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool: return m.has_meta("no_flash"))
	check(foams.size() >= 2 and foams.all(func(m: Node) -> bool: return not beast._parts.has(m)), "nor the foam and water round it (%d)" % foams.size())
	beast._current_anim = "m_pull"
	MesenllaModels.animate(beast, beast._visual, 0.05, 0.0)
	check((whirl.material_override as ShaderMaterial).get_shader_parameter("strength") > 0.0, "the whirlpool still turns while it flashes")
	await get_tree().physics_frame # the physics world catches up with where everything stands
	var space := coast.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(you.eye_position(), beast.centre(), Zombie.LAYER)
	var found := space.intersect_ray(ray)
	check(not found.is_empty() and found["collider"] == beast, "an arrow or a bolt finds its body (layer %d, %s)" % [beast.collision_layer, str(found.get("collider", null))])
	# Its arts, each in its own third.
	check(VaelMind.kraken_stage(beast) == 0, "whole, it is in its first third")
	beast.hp = beast.max_hp * 0.6
	check(VaelMind.kraken_stage(beast) == 1, "below two thirds, its second")
	beast.hp = beast.max_hp * 0.3
	check(VaelMind.kraken_stage(beast) == 2, "below one third, its last")
	beast.hp = beast.max_hp
	you.position = Vector3(edge.x, coast.ground_at(edge), edge.z) + Vector3(0, 0, -8)
	you.guard_left = 0.0
	mind._decreed = 0
	mind.cooldown = 0.0
	mind._cooldown_d = 99.0
	mind._cooldown_e = 99.0
	mind.cooldown_b = 99.0
	mind._cooldown_c = 99.0
	beast._sees = true
	var seals_before := coast.mist_seals.size()
	mind._kraken(beast, you, 0.016)
	check(mind.phase == "slam" and beast.is_warning() and coast.mist_seals.size() > seals_before, "its arms rear over you and a ring shows where they will come down (%s, %d)" % [mind.phase, coast.mist_seals.size() - seals_before])
	await get_tree().physics_frame
	for s: MistSeal in coast.mist_seals.duplicate(): s.queue_free()
	mind.phase = ""
	beast.hp = beast.max_hp * 0.6
	mind._kraken(beast, you, 0.016)
	check(mind.phase == "pull" and beast._current_anim == "m_pull" and coast.zombies.filter(func(z: Zombie) -> bool: return z.type_id == "drowned_sailor").size() > 0, "at two thirds it roars, turns the sea round itself and raises the drowned")
	var was := you.position
	you.global_position = beast.position + Vector3(0, 0, -(VaelMind.KRAKEN_BODY + 8.0))
	you.global_position.y = coast.ground_at(you.global_position)
	VaelMind.whirl(coast)
	check(you.is_lured(), "its whirlpool draws you toward it")
	you.position = was
	mind.phase = ""
	mind.cooldown_b = 0.0
	mind.cooldown = 99.0
	mind._kraken(beast, you, 0.016)
	check(mind.phase == "ink" and coast.mist_seals.any(func(s: MistSeal) -> bool: return s.style == MistSeal.Style.INK), "in its second third it spits ink (%s, %d rings)" % [mind.phase, coast.mist_seals.size()])
	if not coast.mist_seals.any(func(s: MistSeal) -> bool: return s.style == MistSeal.Style.INK):
		return
	var ink: MistSeal = coast.mist_seals.filter(func(s: MistSeal) -> bool: return s.style == MistSeal.Style.INK).front()
	you.global_position = ink.global_position
	ink.elapsed = ink.warning
	ink.strike()
	check(you.night_blind_left > 0.0, "ink in your eyes: the dark closes in")
	for s: MistSeal in coast.mist_seals.duplicate(): s.queue_free()
	for z: Zombie in coast.zombies.duplicate():
		if z != beast: z.release()
	# Its fall: dawn can come, the tide is let go, and its hoard washes up.
	var loot := coast.pickups.size()
	beast.set_physics_process(true)
	beast.take_damage(99999.0, Vector3.BACK, 0.0, beast.centre())
	await get_tree().physics_frame
	check(d._kraken_fallen and not coast.tide.surging() and coast.pickups.size() >= loot + VaelMind.KRAKEN_HOARD, "its fall: dawn can come, the tide goes free, and its hoard washes up")
	for i in 400:
		if coast.count_type(Director.KRAKEN) == 0:
			break
		await get_tree().physics_frame
	for z: Zombie in coast.zombies.duplicate(): z.release()
	for p: Pickup in coast.pickups.duplicate(): coast.remove_pickup(p)
	d._kraken_fallen = false
	d._kraken_risen = false
	d._kraken_at = -1.0
	you.position = saved


func _coastal_campaign() -> void:
	check(not Game.MAPS.has("lantern_road") and not Places.ORDER.has("lantern_road"), "Lantern Road is retired from selection and atlas")
	var saved := Game.night_map
	Game.night_map = "lantern_road"
	check(Game.current_map() == "vael" and Game.night_length() == 900.0, "retired map migrates to the fifteen-minute coast")
	Game.night_map = "vael"
	check(Game.zombie_pool_plan().has("leviathan"), "the coast reserves the former road boss")
	check(ZombieDefs.ALL["barnacle_brute"]["hp"] == 290.0 and ZombieDefs.ALL["harbourmaster"]["hp"] == 700.0, "coastal heavies have lower health")
	check(VaelVault.RISE >= 1.8 and KrakenModels.SEGMENTS >= 20, "stone-wall vault and continuous tentacle joints")
	Game.night_map = saved


func _coastal_repairs(coast: World) -> void:
	var you := coast.player
	var at := Vector3(0,coast.ground_at(Vector3(0,0,40)),40)
	for id: String in ["harbourmaster","hollow_sovereign","kraken_arm","leviathan","kraken"]:
		check(coast.spawn_zombie(id,at), id+" immunity fixture spawns")
		var boss: Zombie = coast.zombies.back()
		boss.set_physics_process(false)
		var from := boss.position
		boss.stun(5)
		boss.freeze(5)
		boss.slow(5)
		boss.root(5,true)
		boss.pull_to(from+Vector3.RIGHT*10)
		boss.haul_to(from+Vector3.RIGHT*10)
		boss.drift_to(from+Vector3.RIGHT*10,10)
		boss.blind_for(5)
		boss.flinch(5)
		var hp_before := boss.hp
		boss.take_damage(1,Vector3.RIGHT,100,boss.centre())
		check(boss._stun == 0 and boss._frozen == 0 and boss._slow == 0 and boss.root_left == 0 and boss._pull_left == 0 and boss._drift_left == 0 and boss._knock.is_zero_approx(), id+" cannot be controlled or displaced")
		check(boss.hp < hp_before, id+" still takes damage")
		boss.release()
	for id: String in ["angler", "siren", "kraken_arm"]:
		coast.spawn_zombie(id,at)
		var actor: Zombie = coast.zombies.back()
		actor.set_physics_process(false)
		actor._current_anim = "m_bite" if id == "angler" else "m_song" if id == "siren" else "m_slam"
		actor.mesenlla_warning = true
		actor._animate_custom(0.01,0)
		actor._animate_custom(0.8,0)
		actor.mesenlla_warning = false
		actor._animate_custom(1.0/60,0)
		check(float(actor._visual.get_meta("act_t",9)) < 0.02,id+" restarts its strike timer after the tell")
		actor.release()
	var chest: Dictionary = coast.tide.salvage()[0]
	var saved_mode := Game.mode
	var taken: int = chest["taken"]
	var slots := you.slots.duplicate()
	var seen := false
	Game.mode = Game.Mode.SANDBOX
	for i in 20:
		var before := coast.pickups.size()
		seed(7080+i)
		coast.tide._open(chest,you,0)
		if coast.pickups.size() > before:
			seen = true
			break
	check(seen and you.slots == slots,"salvage weapon appears on the ground without replacing any carried weapon")
	check(not coast.tide.salvage_open(chest),"opened chest cannot be reopened in the same ebb")
	chest["taken"] = taken
	Game.mode = saved_mode
	check(ClassDefs.disabled("ferryman") and not ClassDefs.available().has("ferryman"),"Ferryman stays out of selection even when owned")
