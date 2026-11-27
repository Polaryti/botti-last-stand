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
	await _fontanova()
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
	check(vs.size() > 10 and (str(vs[0]["number"]).begins_with("Development") or str(vs[0]["number"]) == current) and ChangelogPanel.count(vs[0]) > (0 if str(vs[0]["number"]).begins_with("Development") else 5), "the Changelog reads every version, newest first")
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
## Fontanova, the first island of the Archipelagos of the Forgotten Gods: listed everywhere a place is,
## an island ringed by sea that drowns you out of your depth, its rope bridges and its grotto, its
## flora moving in the wind, and the title screen it now is.
func _fontanova() -> void:
	check(Game.MAPS.has("fontanova") and "fontanova" in Game.VERSUS_MAPS and "fontanova" in Board.MAPS and "fontanova" in Game.ARCHIPELAGO_MAPS, "Fontanova can be chosen for the night and for versus, and has its boards")
	check(Places.ORDER.has("fontanova") and Places.ALL["fontanova"]["tips"].size() == 3 and str(Places.ALL["fontanova"]["lore"]).length() > 80, "it has its page, its lore and its tips")
	check(WorldAtlas.SEA_SPOTS.has("fontanova") and not WorldAtlas.SPOTS.has("fontanova") and WorldAtlas.view_of("fontanova") == WorldAtlas.ARCHIPELAGO and WorldAtlas.LINKS.has(["vael", "fontanova", false]), "on the Archipelago's chart, the crossing from Port Vael leads to it")
	check(PlaceVista.LOOKS.has("fontanova") and Icons.exists("map_fontanova"), "its loading view and its icon")
	check(Sfx.MUSIC_SETS.has("fontanova") and (Sfx.MUSIC_SETS["fontanova"] as Array).all(func(n: String) -> bool: return ResourceLoader.exists("res://assets/music/%s.ogg" % n)), "its own music, night, hunted and dawn")
	check(Director.DAWN_SOUNDS.get("fontanova", "") == "dawn_fontanova" and Sfx.NAMES.has("dawn_fontanova") and Net.SOUNDS.has("dawn_fontanova"), "and its own sound at dawn")
	check(Sfx.MUSIC_SETS["menu"][0] == "menu_fontanova" and ResourceLoader.exists("res://assets/music/menu_fontanova.ogg"), "the main menu has the Archipelagos' own theme")
	check(World.MENU_TOUR_FONTANOVA.size() >= 6 and World.MENU_TOUR_FONTANOVA.all(func(p: Array) -> bool: return absf(p[0].x) < 166.0 and absf(p[0].z) < 166.0), "and its camera tours Fontanova, inside the map")
	check("fontanova" in Weather.WINDY_MAPS, "the wind blows there some nights")
	var was_map := Game.night_map
	var was_mode := Game.mode
	Game.night_map = "fontanova"
	Game.mode = Game.Mode.NIGHT
	check(is_equal_approx(Game.night_length(), 720.0), "a night there lasts twelve minutes")
	# What the map holds.
	var scene: Node = (load("res://maps/fontanova.tscn") as PackedScene).instantiate()
	var pieces := scene.find_children("*", "Node3D", true, false).filter(func(p: Node) -> bool: return p is MapFonta)
	var kinds := {}
	var gods := {}
	for p: MapFonta in pieces:
		kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
		if p.kind in ["god_statue", "fallen_god", "god_head", "stele"]:
			gods[p.variant] = true
	check(kinds.get("sailboat", 0) == 1 and kinds.get("rope_bridge", 0) == 2 and kinds.get("grotto", 0) == 1 and kinds.get("temple", 0) == 1, "a beached sailboat, two rope bridges, a grotto and the god's temple")
	check(gods.size() == FontaBuilder.GODS.size() and kinds.get("horizon_isle", 0) >= 4, "every god of the archipelago is shown somewhere, and the other islands stand on the horizon")
	check(kinds.get("flora", 0) == 1 and kinds.get("mesa", 0) >= 8 and kinds.get("terraces", 0) == 2 and kinds.get("sacred_stair", 0) == 1 and kinds.get("god_altar", 0) == 4,
		"the island is planted from its land, has its crags and terraces, the Sacred Way's stair, and an altar for each god")
	scene.free()
	# The flora moves in the wind, harder on a windy night.
	check((FontaFlora.tree_mesh("olive") as ArrayMesh).surface_get_material(0) == FontaFlora.tree_material(), "its trees are drawn to sway")
	FontaFlora.set_wind(1.0, Vector3(0, 0, 1))
	check(is_equal_approx(float(FontaFlora.tree_material().get_shader_parameter("gust")), 1.0) and is_equal_approx(float(FontaFlora.herb_material().get_shader_parameter("gust")), 1.0), "the wind bends trees and flowers alike")
	FontaFlora.set_wind(0.0, Vector3(1, 0, 0.3))
	# The island itself.
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var isle := World.new()
	space.add_child(isle)
	isle.setup(Game.Mode.NIGHT)
	isle.director.set_process(false)
	for z: Zombie in isle.zombies.duplicate(): z.release()
	var you := isle.player
	you.set_physics_process(false)
	var t := isle.terrain
	check(isle.map_id == "fontanova" and isle.isle_sea != null and not t.isle.is_empty() and Ambience.wanted(isle), "Fontanova loads, an island in its sea, with its night air")
	check(t.isle_depth(0, 160) > Terrain.ISLE_DROWN and t.isle_depth(160, 0) > Terrain.ISLE_DROWN and t.isle_depth(-160, -100) > Terrain.ISLE_DROWN, "deep sea all round it")
	check(t.isle_depth(0, 0) == 0.0 and t.isle_depth(0, -84) == 0.0 and t.height(0, -84) > 15.0, "dry land in the middle, the Acropolis high in the north")
	check(t.deep_water(0, 160) and not t.deep_water(0, 0), "nothing walks into the deep")
	check(t.isle_depth(2, 64) == 0.0 and t.is_walkable(2, 64), "you land on the beach, by the sailboat")
	check(is_equal_approx(isle.isle_sea.slow_at(Vector3(0, t.ground_height(0, 0), 0)), 1.0) and isle.isle_sea.slow_at(Vector3(0, t.ground_height(0, 160), 160)) <= IsleSea.SLOW + 0.001, "wading slows you, to %d%% out of your depth" % int(IsleSea.SLOW * 100))
	# Out of your depth: a moment to turn back, then the sea drowns you.
	you.global_position = Vector3(0, t.ground_height(0, 160), 160)
	var hp0 := you.hp
	you._tick_sea(IsleSea.GRACE * 0.5)
	check(is_equal_approx(you.hp, hp0), "a few seconds' grace out of your depth")
	you._tick_sea(IsleSea.GRACE)
	check(you.hp < hp0, "then the sea drowns you (%.0f)" % (hp0 - you.hp))
	you.global_position = Vector3(2, t.height(2, 64), 64)
	you._tick_sea(0.1)
	check(you._under_sea == 0.0, "back where you can stand, the count starts again")
	you.hp = you.max_hp()
	# Its planting is kept: the next world on this land (the title screen after a match, the next night)
	# reuses the same meshes rather than working the island out again.
	var herbs := isle.find_children("*", "MeshInstance3D", false, false).map(func(n: Node) -> Mesh: return (n as MeshInstance3D).mesh)
	var kept := FontaFlora._memo.values().any(func(k: Dictionary) -> bool: return (k["herbs"] as Array).size() > 20 and (k["herbs"] as Array).all(func(m: Mesh) -> bool: return herbs.has(m)) and (k["cliffs"] as Array).size() > 5 and (k["carpet"] as Array).size() > 20)
	check(kept, "the island's herbs, cliff faces and grass are kept for the next world, and this one shows them")
	# The rope bridges over the Ravine: decks across it, high over its floor.
	check(t.bridges().size() == 2, "two rope bridges")
	for d: Dictionary in t.bridges():
		var mid := (Vector2(d["a"]) + Vector2(d["b"])) * 0.5
		check(t.deck_y(d, 0.5) > t.ground_height(mid.x, mid.y) + 3.0 and Vector2(d["a"]).distance_to(d["b"]) > 8.0, "a bridge spans the Ravine, high over its floor (%.1f m)" % (t.deck_y(d, 0.5) - t.ground_height(mid.x, mid.y)))
		check(t.on_deck(mid.x, mid.y), "and can be walked")
		var on_it := Vector3(mid.x, t.deck_y(d, 0.5), mid.y)
		check(isle.isle_sea.slow_at(on_it) == 1.0 and not isle.isle_sea.too_deep(on_it), "up on it you are not in the sea, however far below the water is (%.1f m of it under the deck)" % maxf(0.0, isle.isle_sea.level - t.ground_height(mid.x, mid.y)))
	# Walking: as quick across a bridge as on dry ground.
	var walk := func(at: Vector3, toward: Vector3) -> float:
		you.global_position = at + Vector3.UP * 0.05
		you.velocity = Vector3.ZERO
		you.look_at(Vector3(toward.x, you.global_position.y, toward.z), Vector3.UP)
		you.yaw = you.rotation.y
		you.input_move = Vector2(0, -1)
		you.set_physics_process(true)
		for i in 40:
			await get_tree().physics_frame
		var quick := Vector2(you.velocity.x, you.velocity.z).length()
		you.set_physics_process(false)
		you.input_move = Vector2.ZERO
		return quick
	var dry := Vector3(0, t.ground_height(0, 20), 20)
	var on_land: float = await walk.call(dry, dry + Vector3(0, 0, -10))
	for d: Dictionary in t.bridges():
		var a3 := Vector3(Vector2(d["a"]).x, 0, Vector2(d["a"]).y)
		var b3 := Vector3(Vector2(d["b"]).x, 0, Vector2(d["b"]).y)
		var start := a3.lerp(b3, 0.35)
		start.y = t.deck_y(d, 0.35)
		var across: float = await walk.call(start, b3)
		check(on_land > 1.0 and across > on_land * 0.95, "crossing a bridge you walk as quick as on the land (%.1f m/s against %.1f), not wading" % [across, on_land])
	# The temple's steps: walked straight up, at the front and at either side, onto its floor.
	var court := t.ground_height(10, -78)
	for line: Array in [[Vector3(10, 0, -78), Vector3(0, 0, -1)], [Vector3(-10, 0, -78), Vector3(0, 0, -1)], [Vector3(-22, 0, -94), Vector3(1, 0, 0)], [Vector3(22, 0, -94), Vector3(-1, 0, 0)]]:
		var from: Vector3 = line[0]
		from.y = t.ground_height(from.x, from.z) + 0.05
		var heading: Vector3 = line[1]
		you.global_position = from
		you.velocity = Vector3.ZERO
		you.look_at(from + heading, Vector3.UP)
		you.yaw = you.rotation.y
		you.input_move = Vector2(0, -1)
		you.set_physics_process(true)
		var highest := from.y
		for i in 900:
			await get_tree().physics_frame
			if Vector2(you.global_position.x, you.global_position.z).distance_to(Vector2(0, -94)) < 16.0: # on the temple's footprint
				highest = maxf(highest, you.global_position.y)
			if highest > court + 0.9:
				break
		you.set_physics_process(false)
		you.input_move = Vector2.ZERO
		check(highest > court + 0.9, "the temple's steps walk straight up from %s onto its floor (%.1f m up), no wall in the way" % [from, highest - court])
	await _fonta_land(isle)
	await _fonta_rites(isle)
	await _fonta_mutants(isle)
	await _fonta_cult(isle)
	await _fonta_god(isle)
	await _fonta_ascendant(isle)
	space.queue_free()
	Game.night_map = was_map
	Game.mode = was_mode


func _port_vael() -> void:
	# Everywhere a place is listed, Port Vael is.
	check(Game.MAPS.has("vael") and "vael" in Game.VERSUS_MAPS and "vael" in Board.MAPS, "Port Vael can be chosen for the night and for versus, and has its boards")
	check(Places.ORDER.has("vael") and Places.ALL["vael"]["tips"].size() == 3 and str(Places.ALL["vael"]["lore"]).length() > 80, "it has its page, its lore and its tips")
	check(WorldAtlas.SPOTS.has("vael") and WorldAtlas.LINKS.has(["mesenlla", "vael", false]), "the atlas road from Mesenlla leads to Port Vael")
	check(PlaceVista.LOOKS.has("vael") and Icons.exists("map_vael"), "its loading view and its icon")
	check(Sfx.MUSIC_SETS.has("vael") and (Sfx.MUSIC_SETS["vael"] as Array).all(func(n: String) -> bool: return ResourceLoader.exists("res://assets/music/%s.ogg" % n)), "its own music, night, hunted and dawn")
	check(Director.DAWN_SOUNDS.get("vael", "") == "dawn_vael" and Sfx.NAMES.has("dawn_vael"), "and its own sound at dawn")
	# The Sunken Crown's own title tour is kept, and its menu theme stays in the game.
	check(ResourceLoader.exists("res://assets/music/menu_vael.ogg") and World.MENU_TOUR_VAEL.size() >= 6 and World.MENU_TOUR_VAEL.all(func(p: Array) -> bool: return absf(p[0].x) < 110.0 and absf(p[0].z) < 110.0), "The Sunken Crown's tour of Port Vael and its theme are kept")
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
		check(CodexPanel.enemy_group(id) == (8 if id == "hollow_sovereign" else 5), "%s in the Codex with the drowned of Vael%s" % [id, " (with the bosses)" if id == "hollow_sovereign" else ""])
		var voices: Array = [Zombie.MESENLLA_VOICES.get(id, ""), Zombie.MESENLLA_HURT.get(id, ""), Zombie.MESENLLA_DEATHS.get(id, "")]
		check(voices.all(func(v: String) -> bool: return v != "" and Sfx.NAMES.has(v) and Net.SOUNDS.has(v) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % v)), "%s has a voice, a hurt and a death of its own" % id)
	var wanders := func(id: String) -> bool: return ZombieDefs.roams(id, 999.0, "vael") and float(ZombieDefs.ALL[id]["weight"]) > 0.0
	check(wanders.call("tide_witch") and court.filter(func(id: String) -> bool: return id != "tide_witch").all(func(id: String) -> bool: return not wanders.call(id)), "Tide Witches roam; Sirens, the Press Gang and the court come when the night sends them")
	check(["harbourmaster", "lighthouse_keeper", "kraken_arm"].all(func(id: String) -> bool: return ZombieDefs.ALL[id].get("miniboss", false)) and ZombieDefs.ALL["hollow_sovereign"].get("vael_boss", false), "three of the court are minibosses, and the Hollow Sovereign the boss")
	check(Director.BOSS_CARDS.has("hollow_sovereign") and Sfx.NAMES.has("boss_bells_sovereign") and ResourceLoader.exists("res://assets/sounds/boss_bells_sovereign.ogg"), "he enters with his own card and bells")
	check(Net.ANIMS.size() <= 64 and ["m_sting", "m_song", "m_rise", "m_sink", "Throw", "WindUp", "Raise"].all(func(a: String) -> bool: return Net.ANIMS.has(a)), "every phone is sent what they are doing (%d states)" % Net.ANIMS.size())
	check(MistSeal.Style.NET == 7 and MistSeal.Style.CROWN == 13 and MistSeal.Style.INK == 17 and MistSeal.LOOKS.size() == MistSeal.Style.size(), "the new rings come after the old on the wire, each with its look")
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
	check(levi.get("vael_boss", false) and VaelMind.handles("leviathan") and Icons.exists("leviathan") and str(levi.get("lore", "")).length() > 60 and CodexPanel.enemy_group("leviathan") == 8, "the Leviathan of the Mists: a boss of Vael, with its own mind, icon, lore and place in the Codex")
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
	check(p.harpoon_out and p.arrows == arrows_before and p.slots[0] == null and p.weapon_id() == "sword", "thrown: its slot is left empty, you turn to your sword, and no arrows are spent")
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
	check(not p.harpoon_out and not w.harpoons.has(p.net_id()) and p.slots[0] == "harpoon" and p.weapon_id() == "sword", "walking over it takes it back into the slot it left")
	p.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	whale.release()
	p.current = 0
	p._equip()
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	for i in 90:
		await get_tree().physics_frame
	check(p.harpoon_out and w.harpoons.has(p.net_id()), "thrown at nothing, it lies on the ground")
	p._tick_harpoon(16.0)
	check(not p.harpoon_out and not w.harpoons.has(p.net_id()) and p.slots[0] == "harpoon" and p.weapon_id() == "sword", "and after 15 s it is back in its slot by itself")
	# Thrown with nothing else to hold, it comes back into your empty hands.
	p.slots[1] = null
	p.current = 0
	p._equip()
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	check(p.harpoon_out and p.current == 0 and p.slots == [null, null], "with no other weapon you are left empty-handed")
	p._tick_harpoon(16.0)
	check(p.weapon_id() == "harpoon", "and it comes back into your empty hands")
	for i in 30:
		await get_tree().physics_frame
	# Both hands full when it comes back: it drops at your feet instead of vanishing.
	p.slots[1] = "sword"
	p.current = 0
	p._equip()
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	p.input_fire = false
	for i in 90:
		await get_tree().physics_frame
	p.slots[0] = "mace"
	p.current = 0
	p._equip()
	var lying_round := w.pickups.size()
	p._tick_harpoon(16.0)
	var dropped := w.pickups.filter(func(q: Pickup) -> bool: return q.weapon_id == "harpoon" and q.global_position.distance_to(p.global_position) < 3.0)
	check(not p.harpoon_out and not p.slots.has("harpoon") and w.pickups.size() == lying_round + 1 and dropped.size() == 1, "with both hands full it lies at your feet")
	for item: Pickup in dropped: w.remove_pickup(item)
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


## The mutants of Fontanova: each one's tell, what lands and how to step out of it, what it leaves
## behind, and where the night puts them.
## Fontanova's land: high ground you can reach, a Ravine that kills, nothing floating, a full island.
func _fonta_land(isle: World) -> void:
	var t := isle.terrain
	check(t.height(0, -88) > 30.0 and t.height(-94, -8) > 18.0 and t.height(-104, -22) > 25.0 and t.height(84, -8) > 17.0,
		"real heights: the Acropolis (%.0f m), the West Ridge, Kerys' Watch and the Holm Wood's height" % t.height(0, -88))
	for trip: Array in [[Vector3(0, 0, 70), Vector3(0, 0, -84), "the temple, up the Sacred Way"], [Vector3(0, 0, 70), Vector3(-46, 0, -2), "the village on the Ravine's rim"],
			[Vector3(0, 0, 70), Vector3(-94, 0, 6), "the West Ridge, over a bridge"], [Vector3(0, 0, 70), Vector3(60, 0, -24), "the Oracle's Grotto"]]:
		var way := isle.grid.route(trip[0], trip[1])
		check(way.size() > 1 and Vector2(way[-1].x - trip[1].x, way[-1].z - trip[1].z).length() < 4.0, "a way on foot from the Landing to %s" % trip[2])
	# The Ravine: deep, and a fall into it is death.
	var floor_at := Vector3.INF
	for z in range(-40, 30, 2):
		for x in range(-80, -40, 2):
			if t.in_chasm(x, z) and t.height(x, z) < Terrain.CHASM_DEATH - 1.0:
				floor_at = Vector3(x, t.height(x, z), z)
				break
		if floor_at != Vector3.INF:
			break
	check(floor_at != Vector3.INF and floor_at.y < Terrain.CHASM_DEATH, "the Ravine's floor lies deep below the rims (%.1f m)" % floor_at.y)
	var you := isle.player
	you.hp = you.max_hp()
	you.global_position = floor_at
	you._tick_sea(0.1)
	check(you.dead or you.hp <= 0.0, "falling into the Ravine kills you")
	if you.dead:
		you.respawn(Vector3(2, t.height(2, 64), 64))
	you.guard_left = 0.0
	if isle.spawn_zombie("thornback", floor_at + Vector3(0, 0.5, 0)):
		var z: Zombie = isle.zombies.back()
		z.position = floor_at
		z._physics_process(0.05)
		check(not z.is_alive(), "and kills whatever is knocked into it")
	# Nothing in the air: every tree's root is on the ground, every prop on the lowest ground under it.
	var adrift := 0
	for at: Vector3 in isle.tree_spots:
		if absf(at.y - t.height(at.x, at.z)) > 0.06:
			adrift += 1
	check(isle.tree_spots.size() >= 250 and adrift == 0, "%d trees, every one rooted in the ground (%d adrift)" % [isle.tree_spots.size(), adrift])
	var column := MapFonta.new()
	column.kind = "column"
	column.size = 4.0
	var on_slope := Transform3D(Basis.IDENTITY, Vector3(0, 0, 40))
	var base := MapBuilder.settle_static(t, on_slope, column)
	var half := column.footprint()
	var under := INF
	for i: float in [-1.0, 1.0]:
		for j: float in [-1.0, 1.0]:
			under = minf(under, t.height(on_slope.origin.x + half.x * i, on_slope.origin.z + half.y * j))
	check(base <= under + 0.001, "a column on a slope is set down on its lowest corner, never left hanging")
	column.free()
	# The flora: a carpet of grass, flowers and shrubs, the cliffs dressed in strata.
	var tufts := 0
	var carpets := 0
	for n in isle.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (n as MultiMeshInstance3D).multimesh
		if (n as MultiMeshInstance3D).material_override == FontaFlora.grass_material():
			carpets += 1
			tufts += mm.instance_count
	check(carpets > 50 and tufts > 20000, "a carpet of grass over the island (%d tufts)" % tufts)
	check(FontaFlora.FIELD_ZONES.size() >= 9 and FontaFlora.NOMINAL.size() >= 10, "%d kinds of tree, planted by %d parts of the island" % [FontaFlora.NOMINAL.size(), FontaFlora.FIELD_ZONES.size()])
	FontaFlora.set_wind(1.0, Vector3(0, 0, 1))
	check(is_equal_approx(float(FontaFlora.grass_material().get_shader_parameter("gust")), 1.0), "the grass bends in the wind too")
	FontaFlora.set_wind(0.0, Vector3(1, 0, 0.3))


## Fontanova's rites: the Oracle's braziers and sanctum, the waking altars, the rising sea, the blooms.
func _fonta_rites(isle: World) -> void:
	var rites := isle.fonta_rites
	check(rites != null and (isle.grotto_rites["braziers"] as Array).size() == 3 and isle.altar_spots.size() == 4, "the Oracle's Grotto has its three braziers, and each god an altar")
	var you := isle.player
	var gate := isle.grid.route(Vector3(60, 0, -24), (isle.grotto_rites["relic"] as Vector3))
	var shut := gate.size() < 2 or Vector2(gate[-1].x, gate[-1].z).distance_to(Vector2((isle.grotto_rites["relic"] as Vector3).x, (isle.grotto_rites["relic"] as Vector3).z)) > 3.0
	check(shut, "the sanctum is sealed at first")
	var pickups_before := isle.pickups.size()
	for i in 3:
		var at: Vector3 = (isle.grotto_rites["braziers"] as Array)[i]
		you.global_position = at + Vector3(0.5, 0, 0)
		rites._tick_braziers(FontaRites.BRAZIER_HOLD * 0.5)
		if i == 0:
			check(not rites.lit & 1, "a brazier takes a moment to light")
		rites._tick_braziers(FontaRites.BRAZIER_HOLD * 0.6)
	check(rites.lit == 7 and rites.door_open, "light all three braziers and the sanctum's door opens")
	var flames: Array = rites._braziers.map(func(b: Dictionary) -> MeshInstance3D: return b["fire"])
	check(flames.all(func(f: MeshInstance3D) -> bool: return f.visible and f.mesh == WorldLight.brazier_mesh() and (f.get_meta("halo") as Node3D).visible and (not f.has_meta("sparks") or (f.get_meta("sparks") as CPUParticles3D).emitting)),
		"each burns with living tongues of fire, a halo and sparks, as Port Vael's braziers do")
	var pickups_after := isle.pickups.size()
	check(pickups_after >= pickups_before + 2, "inside: a rare weapon and the Oracle's Eye")
	# The Oracle's Eye: harder blows, and the enemies near you shown.
	var dmg := you.damage_multiplier()
	you.activate_power(PowerDefs.EYE)
	check(is_equal_approx(you.damage_multiplier(), dmg * PowerDefs.EYE_DAMAGE), "the Oracle's Eye: blows %d%% harder" % int(round((PowerDefs.EYE_DAMAGE - 1.0) * 100.0)))
	check(PowerDefs.relic_banner(PowerDefs.EYE).contains("Oracle's Eye") and not PowerDefs.relic_banner(PowerDefs.EYE).contains("Crown") and you.skin_bits() & 2 == 0, "taken up, it says what it is and what it does, not the Sunken Crown's words")
	you._tick_powers(600.0)
	check(you.has_power(PowerDefs.EYE), "carried for as long as you stand")
	var eyes := func() -> int: return isle.pickups.filter(func(k: Pickup) -> bool: return is_instance_valid(k) and k.item_id == PowerDefs.EYE).size()
	var lying: int = eyes.call()
	var at_eye := you.global_position
	you._kill()
	check(not you.has_power(PowerDefs.EYE) and eyes.call() == lying, "fall, and it is lost for good: not on you, not on the ground")
	you.respawn(at_eye)
	check(not you.has_power(PowerDefs.EYE), "and it does not come back with you")
	you.guard_left = 0.0 # a fresh respawn's moment of safety, run out (physics is off here)
	# The altars wake one at a time.
	check(FontaRites.awake_at(FontaRites.ALTAR_FIRST - 1.0).x == 0 and int(FontaRites.awake_at(FontaRites.ALTAR_FIRST + 1.0).x) == FontaRites.ALTAR_ORDER[0], "the first altar wakes after %d s" % int(FontaRites.ALTAR_FIRST))
	check(FontaRites.awake_at(FontaRites.ALTAR_FIRST + FontaRites.ALTAR_AWAKE + 1.0).x == 0 and int(FontaRites.awake_at(FontaRites.ALTAR_FIRST + FontaRites.ALTAR_EVERY + 1.0).x) == FontaRites.ALTAR_ORDER[1], "sleeps after %d s, and the next wakes %d s after the first" % [int(FontaRites.ALTAR_AWAKE), int(FontaRites.ALTAR_EVERY)])
	isle.director.elapsed = FontaRites.ALTAR_FIRST + 1.0
	for z: Zombie in isle.zombies.duplicate(): z.release()
	rites._tick_altars(0.0)
	for z: Zombie in isle.zombies.duplicate(): z.release()
	var god := rites.altar_god
	var altar := rites._altar_at(god)
	check(god == FontaRites.ALTAR_ORDER[0] and altar != Vector3.INF, "%s's altar is awake" % FontaRites.GOD_NAMES.get(god, "?"))
	you.global_position = altar + Vector3(1, 0, 0)
	rites._tick_altars(FontaRites.ALTAR_HOLD * 0.5)
	check(rites.claims == 0, "it has to be held")
	rites._bless_claimed() # (every frame, as the altar burns, it notes whose it is)
	rites._tick_altars(FontaRites.ALTAR_HOLD * 0.6)
	rites._bless_claimed()
	check(rites.claims == 1 and you._buffs.has("god_ilyria_melee_damage"), "held for %d s, Ilyria blesses whoever stands there: blows %d%% harder" % [int(FontaRites.ALTAR_HOLD), int(Player.GOD_DAMAGE * 100.0)])
	check(isle.director.banner.contains("Ilyria's blessing is yours now") and isle.director.banner.contains(Player.god_gift(2)), "and says so at once, with what it gives and for how long")
	check(Player.god_gift(1).contains("%d at once" % int(Player.GOD_HEAL)) and Player.god_gift(1).contains("%d health a second" % int(Player.GOD_REGEN)) and Player.god_gift(3).contains("%d%% faster" % roundi(Player.GOD_SPEED * 100.0))
		and Player.god_gift(4).contains("%d%% harder shots" % roundi(Player.GOD_AIM * 100.0)) and [1, 2, 3, 4].all(func(g: int) -> bool: return Player.god_gift(g).contains("%d s" % int(Player.BLESSING_TIME["god_%d" % g]))), "each god's blessing in its own words, with its numbers")
	for key: String in you._buffs.keys():
		if key.begins_with("god_"):
			you._buffs.erase(key)
	# The sea rises, three times a night, and goes down again.
	check(FontaRites.tide_at(FontaRites.TIDES[0] - 1.0) == 0.0 and is_equal_approx(FontaRites.tide_at(FontaRites.TIDES[0] + FontaRites.TIDE_RAMP + 1.0), FontaRites.TIDE_RISE), "at %d s the sea rises %.1f m" % [int(FontaRites.TIDES[0]), FontaRites.TIDE_RISE])
	check(FontaRites.tide_at(FontaRites.TIDES[0] + FontaRites.TIDE_HIGH + FontaRites.TIDE_RAMP + 1.0) == 0.0 and FontaRites.TIDES.size() == 3, "and falls again after %d s, three times a night" % int(FontaRites.TIDE_HIGH))
	isle.director.elapsed = FontaRites.TIDES[0] + FontaRites.TIDE_RAMP + 1.0
	rites._tick_tide()
	var beach := Vector3(4, 0, 80)
	check(isle.isle_sea.slow_at(beach) < 1.0 or isle.terrain.height(beach.x, beach.z) < Terrain.ISLE_SEA_Y + FontaRites.TIDE_RISE, "the high sea covers the beach")
	# The blooms.
	check(FontaRites.bloom_at(FontaRites.BLOOM_FIRST - 1.0).x < 0 and FontaRites.bloom_at(FontaRites.BLOOM_FIRST + 1.0).z == 1 and FontaRites.bloom_at(FontaRites.BLOOM_FIRST + FontaRites.BLOOM_WARN + 1.0).z == 2,
		"violet buds break through after %d s, and open %d s later" % [int(FontaRites.BLOOM_FIRST), int(FontaRites.BLOOM_WARN)])
	isle.director.elapsed = FontaRites.BLOOM_FIRST + FontaRites.BLOOM_WARN + 1.0
	rites._tick_blooms(0.0)
	check(rites._bloom != null and rites._bloom_at != Vector3.INF and rites.in_bloom(rites._bloom_at), "they open at %s" % FontaRites.BLOOM_PLACES[FontaRites.bloom_at(isle.director.elapsed).y])
	you.hp = you.max_hp()
	you.global_position = rites._bloom_at
	rites._hurt_tick = 0.0
	rites._tick_blooms(0.6)
	check(you.hp < you.max_hp() and you.poison_left > 0.0, "standing in them poisons and hurts you")
	you.global_position = rites._bloom_at + Vector3(FontaRites.BLOOM_RADIUS + 2.0, 0, 0)
	check(not rites.in_bloom(you.global_position), "step out of the ring and you are clear")
	isle.director.elapsed = 0.0
	rites._tick_tide()
	rites._tick_blooms(0.0)
	you.hp = you.max_hp()
	you.poison_left = 0.0
	# Royal Jelly, from a broken hive.
	you.hp = 10.0
	you._rage_cd = 9.0
	you.royal_jelly()
	check(is_equal_approx(you.hp, you.max_hp()) and you._rage_cd == 0.0 and you._buffs.has("royal_jelly_melee_rate"), "Royal Jelly: full health, every ability ready, and %d%% quicker for %d s" % [int(PowerDefs.JELLY_RATE * 100.0), int(PowerDefs.JELLY_TIME)])
	you._buffs.erase("royal_jelly_melee_rate")
	you._buffs.erase("royal_jelly_spell_rate")


## The cult of Al'quimelea: who they are, how they are dressed, what each of them does, the night's
## processions and riders.
func _fonta_cult(isle: World) -> void:
	var you := isle.player
	var at := Vector3(0, isle.ground_at(Vector3(0, 0, 30)), 30)
	var ready_you := func() -> void:
		you.position = at
		you.hp = you.max_hp()
		you.guard_left = 0.0
		you.poison_left = 0.0
		you.slowed_left = 0.0
		you.frozen_left = 0.0
		you.velocity = Vector3.ZERO
		you._status_immune = 0.0
	var drop_seals := func() -> void:
		for seal: MistSeal in isle.mist_seals.duplicate(): seal.queue_free()
	for z: Zombie in isle.zombies.duplicate(): z.release()
	drop_seals.call()
	await frames(1)
	# Some Worshippers carry a hunting bow, and put the sickle away for it; it shoots from afar.
	var archers := 0
	var sicklers := 0
	for i in 24:
		isle.spawn_zombie("cult_worshipper", at + Vector3(i % 6 * 2.0 - 5.0, 0, -12.0 - int(i / 6) * 2.0))
		var w: Zombie = isle.zombies.back()
		var sickle: MeshInstance3D = w._parts.filter(func(m: MeshInstance3D) -> bool: return m.has_meta("cult_held")).front()
		if w.weapon_id == "bow":
			archers += 1
			check(not sickle.visible and w._hand_mesh != null and w._attack_style() == "ranged" and w._ranged_reach() > 20.0, "a Worshipper with a bow holds it, not its sickle, and shoots from %.0f m" % w._ranged_reach())
			w.net_weapon("")
			check(sickle.visible, "told by the host it carries its sickle after all, it shows the sickle again")
		else:
			sicklers += 1
			check(w.weapon_id == "" and sickle.visible and w._attack_style() == "melee", "the rest come at you with the sickle")
		w.release()
	check(archers > 0 and sicklers > archers, "about one in four carries a bow (%d of 24)" % archers)
	await frames(1)
	# A staff or a spear is swung head first, never jabbed butt first with its head behind.
	for id: String in ["cult_priest", "cult_guardian", "hierophant", "polemarch"]:
		isle.spawn_zombie(id, at + Vector3(0, 0, -12))
		var c: Zombie = isle.zombies.back()
		c.set_physics_process(false)
		var held: MeshInstance3D = c._parts.filter(func(m: MeshInstance3D) -> bool: return m.get_parent() is BoneAttachment3D and (m.get_parent() as BoneAttachment3D).bone_name == "handslot.r").front()
		c._current_anim = ""
		c._play(c._blow_anim(), 1.0, 0.0)
		var ahead := -1.0
		for f: float in [0.3, 0.4, 0.5]:
			c._anim.seek(c._anim.current_animation_length * f, true)
			await frames(1)
			ahead = maxf(ahead, (c.global_transform.basis.inverse() * held.global_transform.basis.y.normalized()).z)
		check(c._blow_anim() != "Unarmed_Melee_Attack_Punch_A" and ahead > 0.4, "%s swings what it holds head first at you (%.1f ahead)" % [id, ahead])
		c.release()
	await frames(1)
	# Backing off from you with a wall behind it: it goes round, along the wall, and does not walk into
	# it; boxed in, it stands its ground.
	ready_you.call()
	var path_grid := isle.grid
	var by_wall := at + Vector3(0, 0, -6)
	isle.spawn_zombie("cult_priest", by_wall)
	var backer: Zombie = isle.zombies.back()
	backer.set_physics_process(false)
	backer.position = by_wall
	var shut: Array[Vector2i] = []
	var wall := func(cells: Array) -> void:
		for c: Vector2i in cells:
			if path_grid.is_free(c):
				path_grid.astar.set_point_solid(c, true)
				shut.append(c)
	var behind := path_grid.to_cell(by_wall + Vector3(0, 0, -1.2))
	var row: Array = []
	for dx in range(-12, 13): row.append(behind + Vector2i(dx, 0))
	wall.call(row)
	var backing := backer.mesenlla_mind as VaelMind
	var start := backer.position
	for i in 40:
		var to := you.global_position - backer.position
		backing._keep(backer, to, Vector2(to.x, to.z).length(), CultMind.PRIEST_RANGE, 1.0 / 30.0, you)
	var moved := Vector2(backer.position.x - start.x, backer.position.z - start.z)
	check(absf(moved.x) > 1.0 and path_grid.is_free(path_grid.to_cell(backer.position)), "a backer backing into a wall goes along it instead (%.1f m aside)" % moved.x)
	backer.position = by_wall
	var box: Array = []
	for dx in range(-12, 13):
		for dz in range(-12, 0): box.append(path_grid.to_cell(by_wall) + Vector2i(dx, dz))
		for dz in range(1, 13): box.append(path_grid.to_cell(by_wall) + Vector2i(dx, dz) if absi(dx) > 1 else path_grid.to_cell(by_wall) + Vector2i(12, 12))
	wall.call(box)
	for c: Vector2i in [path_grid.to_cell(by_wall) + Vector2i(-1, 0), path_grid.to_cell(by_wall) + Vector2i(1, 0)]: wall.call([c])
	start = backer.position
	for i in 20:
		var to := you.global_position - backer.position
		backing._keep(backer, to, Vector2(to.x, to.z).length(), CultMind.PRIEST_RANGE, 1.0 / 30.0, you)
	check(Vector2(backer.position.x - start.x, backer.position.z - start.z).length() < 0.2, "and cornered, it stands its ground")
	for c in shut: path_grid.astar.set_point_solid(c, false)
	backer.release()
	await frames(1)
	for id: String in CultMind.CULT:
		var d: Dictionary = ZombieDefs.ALL[id]
		check(d["maps"] == ["fontanova"] and CodexPanel.enemy_group(id) == 7 and Icons.exists(id) and str(d.get("lore", "")).length() > 60 and CultMind.handles(id), id + ": of Fontanova's cult, in the Codex with its icon, lore and mind")
		for table: Dictionary in [Zombie.MESENLLA_VOICES, Zombie.MESENLLA_HURT, Zombie.MESENLLA_DEATHS]:
			var sound: String = table.get(id, "")
			check(sound != "" and Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s has its own voice (%s)" % [id, sound])
		# Dressed piece by piece on the body's bones: robes and sleeves move with the limbs.
		ready_you.call()
		check(isle.spawn_zombie(id, at + Vector3(0, 0, -10)), id + " spawns")
		var z: Zombie = isle.zombies.back()
		var bones := {}
		for n in z._visual.find_children("*", "BoneAttachment3D", true, false):
			bones[(n as BoneAttachment3D).bone_name] = true
		var limbs := bones.keys().filter(func(b: String) -> bool: return b.begins_with("upper") or b.begins_with("lower"))
		check(bones.has("head") and bones.has("chest") and bones.has("hips") and limbs.size() >= 4, "%s wears its gear on its head, chest, hips and %d limbs" % [id, limbs.size()])
		z.release()
	# The worshippers: when one falls the others near it take up the cry.
	for i in 2:
		isle.spawn_zombie("cult_worshipper", at + Vector3(i * 2.0, 0, -12))
	var first: Zombie = isle.zombies[-2]
	var second: Zombie = isle.zombies[-1]
	first.take_damage(first.hp + 100.0, Vector3.ZERO, 0.0, first.centre())
	check(second.haste_left >= CultMind.FERVOUR_TIME - 0.01, "a Worshipper falls: those within %d m hurry on for %d s" % [int(CultMind.FERVOUR_REACH), int(CultMind.FERVOUR_TIME)])
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# The priest: a tell, a flask thrown where you will be, poison and a slow where it bursts.
	ready_you.call()
	isle.spawn_zombie("cult_priest", at + Vector3(0, 0, -12))
	var priest: Zombie = isle.zombies.back()
	priest.set_physics_process(false)
	priest._sees = true
	var mind := priest.mesenlla_mind as CultMind
	mind.cooldown = 0.0
	mind.cooldown_b = 99.0
	mind.tick(priest, you, Vector3.ZERO, 12.0, 0.01)
	check(mind.phase == "throw" and priest.is_warning() and isle.mist_seals.size() == 1 and isle.mist_seals[0].style == MistSeal.Style.ELIXIR, "a Priest draws back and throws a flask of elixir")
	var flask: MistSeal = isle.mist_seals[0]
	flask.set_physics_process(false)
	you.position = flask.position
	var hp := you.hp
	flask.strike()
	check(you.hp < hp and is_equal_approx(you.poison_left, CultMind.ELIXIR_POISON) and you.slowed_left >= CultMind.ELIXIR_SLOW - 0.01, "where it bursts: poisoned %d s and slowed %d s" % [int(CultMind.ELIXIR_POISON), int(CultMind.ELIXIR_SLOW)])
	drop_seals.call()
	# And it anoints the hurt: a third of their health back, and haste.
	mind.phase = ""
	priest._current_anim = ""
	isle.spawn_zombie("thornback", at + Vector3(3, 0, -12))
	var hurt: Zombie = isle.zombies.back()
	hurt.hp = hurt.max_hp * 0.3
	mind.cooldown_b = 0.0
	mind.cooldown = 99.0
	mind.tick(priest, you, Vector3.ZERO, 12.0, 0.01)
	check(mind.phase == "anoint" and priest.is_warning(), "a Priest raises its staff over a hurt creature")
	mind.tick(priest, you, Vector3.ZERO, 12.0, CultMind.ANOINT_TELL + 0.01)
	check(is_equal_approx(hurt.hp, hurt.max_hp * (0.3 + CultMind.ANOINT_HEAL)) and hurt.haste_left >= CultMind.ANOINT_HASTE - 0.01, "and anoints it: a third of its health back, and %d s of haste" % int(CultMind.ANOINT_HASTE))
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# The guardian: braces behind its shield, then rushes and bashes you down.
	ready_you.call()
	isle.spawn_zombie("cult_guardian", at + Vector3(0, 0, -6))
	var guard: Zombie = isle.zombies.back()
	guard.set_physics_process(false)
	guard._sees = true
	var gm := guard.mesenlla_mind as CultMind
	gm.cooldown = 0.0
	gm.tick(guard, you, Vector3.ZERO, 6.0, 0.01)
	check(gm.phase == "brace" and guard.is_warning(), "a Guardian braces behind its shield before it rushes")
	gm.tick(guard, you, Vector3.ZERO, 6.0, CultMind.RUSH_TELL + 0.01)
	for i in 60:
		if gm.phase != "rush" or isle.mist_seals.size() > 0:
			break
		gm.tick(guard, you, Vector3.ZERO, guard.position.distance_to(you.position), 1.0 / 30.0)
	check(isle.mist_seals.size() == 1 and isle.mist_seals[0].style == MistSeal.Style.BASH, "then rushes, and its shield meets you")
	if isle.mist_seals.size() == 1:
		hp = you.hp
		(isle.mist_seals[0] as MistSeal).strike()
		check(you.hp < hp and you.frozen_left >= CultMind.BASH_STUN - 0.01, "stunned %.1f s by the bash" % CultMind.BASH_STUN)
	drop_seals.call()
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# The Ostrich Guardian: on its bird until the bird is brought down, then on foot behind its shield.
	ready_you.call()
	isle.spawn_zombie("ostrich_rider", at + Vector3(0, 0, -14))
	var rider: Zombie = isle.zombies.back()
	rider.set_physics_process(false)
	check(rider._mounted and rider._horse_node != null and rider._horse_node.visible, "an Ostrich Guardian rides its war-bird")
	check(rider._horse_node.scale.x < rider._scale * 1.0 and rider._horse_node.scale.x > rider._scale * 0.9, "a bird of a rider's own size, not a giant")
	rider.take_damage(rider.max_hp * 0.65, Vector3.ZERO, 0.0, rider.centre())
	check(not rider._mounted and rider.is_alive(), "below 40%: the bird goes down, the Guardian fights on")
	var mount := rider._horse_node
	var t := 0.0
	var saw_down := false
	while rider._mount_fall > 0.0 and t < 5.0:
		rider._tick_mount_fall(1.0 / 30.0)
		t += 1.0 / 30.0
		saw_down = saw_down or mount.has_meta("did_thud")
	check(saw_down and absf(t - FontaModels.MOUNT_FALL_TIME) < 0.1 and not mount.visible, "the bird dies as a battle ostrich does, over %.1f s, and is gone" % FontaModels.MOUNT_FALL_TIME)
	check((mount.get_node("Rig") as Node3D).position.is_equal_approx(Vector3(0, 1.25, 0)) or not mount.has_meta("did_thud"), "and stands ready again for the next rider")
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# The cult's great ones.
	for id: String in CultMind.GREAT:
		var d: Dictionary = ZombieDefs.ALL[id]
		check(d.get("miniboss", false) and CodexPanel.enemy_group(id) == 7 and Icons.exists(id) and CultMind.handles(id) and str(d.get("first_words", "")) != "" and str(d.get("last_words", "")) != "", id + ": a miniboss of the cult, with its icon, words and mind")
		for table: Dictionary in [Zombie.MESENLLA_VOICES, Zombie.MESENLLA_HURT, Zombie.MESENLLA_DEATHS]:
			check(Sfx.NAMES.has(table.get(id, "")) and Net.SOUNDS.has(table.get(id, "")), "%s has its own voice (%s)" % [id, table.get(id, "")])
	ready_you.call()
	isle.spawn_zombie("hierophant", at + Vector3(0, 0, -11))
	var hiero: Zombie = isle.zombies.back()
	hiero.set_physics_process(false)
	hiero._sees = true
	var hm := hiero.mesenlla_mind as CultMind
	hm.cooldown = 0.0
	hm.cooldown_b = 99.0
	hm.tick(hiero, you, Vector3.ZERO, 11.0, 0.01)
	check(hm.phase == "fan" and hiero.is_warning() and isle.mist_seals.size() == 3 and isle.mist_seals.all(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.ELIXIR), "the Hierophant throws three flasks at once")
	var spread := (isle.mist_seals[0] as MistSeal).position.distance_to((isle.mist_seals[2] as MistSeal).position)
	check(absf(spread - CultMind.FAN_SPREAD * 2.0) < 0.6, "one where you are going and one %.1f m to either side" % CultMind.FAN_SPREAD)
	drop_seals.call()
	hm.phase = ""
	hiero._current_anim = ""
	hiero.mesenlla_warning = false
	# Below half health, the elixir of change.
	for i in 2:
		isle.spawn_zombie("cult_worshipper", hiero.position + Vector3(3.0 + i * 1.5, 0, 0))
	hiero.hp = hiero.max_hp * 0.4
	hm.cooldown_b = 0.0
	hm.cooldown = 99.0
	hm.tick(hiero, you, Vector3.ZERO, 11.0, 0.01)
	check(hm.phase == "rite" and hiero.is_warning(), "below half health it raises its staff to pour the elixir of change")
	hm.tick(hiero, you, Vector3.ZERO, 11.0, CultMind.RITE_TELL + 0.01)
	check(isle.count_type("cult_worshipper") == 0 and isle.count_type("battle_ostrich") + isle.count_type("thornback") == CultMind.RITE_COUNT, "and the Worshippers near it become mutants")
	hm.cooldown_b = 0.0
	hm.tick(hiero, you, Vector3.ZERO, 11.0, 0.01)
	hm.tick(hiero, you, Vector3.ZERO, 11.0, CultMind.RITE_TELL + 0.01)
	check(isle.count_type("cult_worshipper") == CultMind.RITE_COUNT, "with none near, it calls %d down to it" % CultMind.RITE_COUNT)
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# The Polemarch: behind its tower shield, a sweep close in, a charge further off, its Guardians called.
	ready_you.call()
	isle.spawn_zombie("polemarch", at + Vector3(0, 0, -3))
	var pole: Zombie = isle.zombies.back()
	pole.set_physics_process(false)
	pole._sees = true
	pole.rotation.y = 0.0 # facing +Z, toward you
	var full := pole.hp
	pole.take_damage(100.0, Vector3(0, 0, -1), 0.0, pole.centre())
	check(is_equal_approx(full - pole.hp, 100.0 * float(ZombieDefs.ALL["polemarch"]["shield_cut"])), "a blow from the front: only a quarter gets past the tower shield")
	full = pole.hp
	pole.take_damage(100.0, Vector3(0, 0, 1), 0.0, pole.centre())
	check(is_equal_approx(full - pole.hp, 100.0), "from behind, all of it")
	var pm := pole.mesenlla_mind as CultMind
	pm.cooldown = 99.0
	pm.cooldown_b = 0.0
	pm.tick(pole, you, Vector3.ZERO, 3.0, 0.01)
	check(pm.phase == "sweep" and pole.is_warning() and isle.mist_seals.size() == 1 and isle.mist_seals[0].style == MistSeal.Style.SWEEP, "close in, it draws back its spear to sweep")
	var sweep: MistSeal = isle.mist_seals[0]
	sweep.set_physics_process(false)
	you.position = sweep.position
	hp = you.hp
	sweep.strike()
	check(you.hp < hp and you.frozen_left >= CultMind.SPEAR_STUN - 0.01, "caught by the sweep: thrown back and stunned %d s" % int(CultMind.SPEAR_STUN))
	drop_seals.call()
	pm.phase = ""
	ready_you.call()
	pole.hp = pole.max_hp * 0.55
	pm.tick(pole, you, Vector3.ZERO, 3.0, 0.01)
	check(pm.phase == "call", "at %d%% it calls its Guardians" % int(CultMind.PHALANX[0] * 100.0))
	pm.tick(pole, you, Vector3.ZERO, 3.0, 1.3)
	check(isle.count_type("cult_guardian") == CultMind.PHALANX_COUNT, "and %d come to its sides" % CultMind.PHALANX_COUNT)
	for z: Zombie in isle.zombies.duplicate(): z.release()
	drop_seals.call()
	await frames(1)
	# Each comes once in the night, at its hour, at its place.
	isle.director._court_came.clear()
	isle.director.elapsed = Director.HIEROPHANT_AT + 0.1
	isle.director._next_procession = INF
	isle.director._next_ostrich_rider = INF
	isle.director._tick_cult()
	check(isle.count_type("hierophant") == 1, "at %d:%02d the Hierophant comes" % [int(Director.HIEROPHANT_AT) / 60, int(Director.HIEROPHANT_AT) % 60])
	isle.director.elapsed = Director.POLEMARCH_AT + 0.1
	isle.director._tick_cult()
	isle.director._tick_cult()
	check(isle.count_type("polemarch") == 1 and isle.count_type("hierophant") == 1, "at %d:%02d the Polemarch; each of them once" % [int(Director.POLEMARCH_AT) / 60, int(Director.POLEMARCH_AT) % 60])
	for z: Zombie in isle.zombies.duplicate(): z.release()
	isle.director._court_came.clear()
	# The Ravine's floor is shut to paths: nothing is led down into it.
	var floor_cell := Vector3.INF
	for zz in range(-40, 30, 2):
		if isle.terrain.in_chasm(-64, zz) and not isle.terrain.on_deck(-64, zz) and isle.terrain.ground_height(-64, zz) < Terrain.CHASM_DEATH:
			floor_cell = Vector3(-64, 0, zz)
			break
	check(floor_cell != Vector3.INF and isle.grid.astar.is_point_solid(isle.grid.to_cell(floor_cell)), "the Ravine's floor is shut to paths")
	# The night: processions from 2:00, riders from 7:00, out of sight of everyone.
	var director := isle.director
	you.position = at
	director.elapsed = Director.PROCESSION_FROM + 0.1
	director._next_procession = Director.PROCESSION_FROM
	director._next_ostrich_rider = INF
	director._tick_cult()
	check(isle.count_type("cult_worshipper") == int(ZombieDefs.ALL["cult_worshipper"]["pack"]), "from %d:%02d a procession of %d Worshippers comes" % [int(Director.PROCESSION_FROM) / 60, int(Director.PROCESSION_FROM) % 60, int(ZombieDefs.ALL["cult_worshipper"]["pack"])])
	var near := INF
	for z: Zombie in isle.zombies:
		near = minf(near, z.position.distance_to(you.position))
	check(near > Director.CULT_HIDDEN, "out of your sight (%.0f m away)" % near)
	director.elapsed = Director.RIDERS_FROM + 0.1
	director._next_ostrich_rider = Director.RIDERS_FROM
	director._next_procession = INF
	director._tick_cult()
	check(isle.count_type("ostrich_rider") == 1, "from %d:%02d Guardians ride out on their birds" % [int(Director.RIDERS_FROM) / 60, int(Director.RIDERS_FROM) % 60])
	for z: Zombie in isle.zombies.duplicate(): z.release()
	director.elapsed = 0.0
	director._next_procession = Director.PROCESSION_FROM
	director._next_ostrich_rider = Director.RIDERS_FROM
	ready_you.call()


## Al'quimelea, the end of Fontanova's night: it comes down from its temple at 11:00, keeps its distance
## floating over everything, tells each of its four arts before it lands, broods twice, and dawn waits for it.
func _fonta_god(isle: World) -> void:
	var you := isle.player
	var d := isle.director
	var at := Vector3(0, isle.ground_at(Vector3(0, 0, 30)), 30)
	var ready_you := func() -> void:
		you.position = at
		you.hp = you.max_hp()
		you.guard_left = 0.0
		you.poison_left = 0.0
		you.slowed_left = 0.0
		you.frozen_left = 0.0
		you.rooted_left = 0.0
		you.burn_time = 0.0
		you.velocity = Vector3.ZERO
		you._status_immune = 0.0
	var drop_seals := func() -> void:
		for seal: MistSeal in isle.mist_seals.duplicate(): seal.queue_free()
	for z: Zombie in isle.zombies.duplicate(): z.release()
	drop_seals.call()
	await frames(1)
	var id := Director.ALQUIMELEA
	var def: Dictionary = ZombieDefs.ALL[id]
	check(def.get("god_boss", false) and def["maps"] == ["fontanova"] and GodMind.handles(id) and Icons.exists(id) and Director.BOSS_CARDS.has(id)
		and Game.zombie_pool_plan().has(id) and str(def.get("lore", "")).length() > 80 and str(def.get("first_words", "")) != "" and str(def.get("last_words", "")) != "",
		"Al'quimelea is Fontanova's god, with its card, icon, lore, words and mind")
	for sound: String in ["alq_voice", "alq_roar", "alq_hurt", "alq_death", "alq_shatter", "alq_gather", "alq_nova", "alq_change", "alq_shard", "alq_lance", "boss_bells_alquimelea"]:
		check(Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s sound" % sound)
	# Dawn waits for it, and it comes at 11:00 from the temple's court.
	check(d.requires_regent(), "on Fontanova, dawn waits for the god")
	d._mist_boss_spawned = false
	d._mist_boss_defeated = false
	d.elapsed = Director.ALQ_AT - 1.0
	d._tick_mist_boss()
	check(isle.count_type(id) == 0, "not before %d:%02d" % [int(Director.ALQ_AT) / 60, int(Director.ALQ_AT) % 60])
	d.elapsed = Director.ALQ_AT + 0.1
	d._tick_mist_boss()
	d._tick_mist_boss()
	check(isle.count_type(id) == 1 and d._mist_boss_spawned, "at %d:%02d it comes down, once" % [int(Director.ALQ_AT) / 60, int(Director.ALQ_AT) % 60])
	var god: Zombie = isle.zombies.filter(func(z: Zombie) -> bool: return z.type_id == id).front()
	check(Vector2(god.position.x - Director.ALQ_FROM.x, god.position.z - Director.ALQ_FROM.z).length() < 6.0, "from the temple's court on the Acropolis")
	check(god.is_boss() and god._visual.get_node_or_null("Rig/Body/Crucible") != null and god._visual.get_node_or_null("Rig/Head/Halo") != null and god._visual.get_node_or_null("Pour") != null,
		"a boss with its crucible, its halo of flasks and the elixir it floats on")
	d.elapsed = d.match_length() + 5.0
	check(d.dawn_amount() < 0.5, "past the night's end, while it lives: no dawn")
	god.set_physics_process(false)
	god._sees = true
	var mind := god.mesenlla_mind as GodMind
	# It rises first; nothing lands while it does.
	ready_you.call()
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -14)), at.z - 14.0)
	mind.tick(god, you, Vector3.ZERO, 14.0, 0.01)
	check(mind.phase == "rise" and isle.mist_seals.is_empty(), "it rises before it does anything")
	mind.tick(god, you, Vector3.ZERO, 14.0, GodModels.RISE_TIME + 0.01)
	check(mind.phase == "", "and is ready after %.0f s" % GodModels.RISE_TIME)
	# It floats to keep its distance, over everything.
	god.position = Vector3(at.x, 0, at.z - 4.0)
	var was := Vector2(god.position.x - you.position.x, god.position.z - you.position.z).length()
	mind.cooldown = 99.0
	mind._cool_field = 99.0
	mind._cool_nova = 99.0
	mind._cool_lance = 99.0
	for i in 30:
		mind.tick(god, you, Vector3.ZERO, Vector2(god.position.x - you.position.x, god.position.z - you.position.z).length(), 0.1)
	var now := Vector2(god.position.x - you.position.x, god.position.z - you.position.z).length()
	check(now > was + 2.0, "too close, it floats back from you (%.1f m to %.1f m)" % [was, now])
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -13)), at.z - 13.0)
	# Elixir rain: several flasks round you.
	mind.cooldown = 0.0
	mind.tick(god, you, Vector3.ZERO, 13.0, 0.01)
	var rain := isle.mist_seals.filter(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.ELIXIR)
	check(mind.phase == "rain" and god.is_warning() and rain.size() == GodMind.RAIN_PER[0], "elixir rain: %d flasks fall round you, each told" % GodMind.RAIN_PER[0])
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	mind.cooldown = 99.0
	# Fields of change: poisoned and held fast.
	mind._cool_field = 0.0
	mind.tick(god, you, Vector3.ZERO, 13.0, 0.01)
	check(mind.phase == "field" and isle.mist_seals.size() == 1 and isle.mist_seals[0].style == MistSeal.Style.CHANGE, "a field of change opens under you")
	var field: MistSeal = isle.mist_seals[0]
	field.set_physics_process(false)
	you.position = field.position
	var hp := you.hp
	field.strike()
	check(you.hp < hp and you.poison_left >= GodMind.CHANGE_POISON - 0.01 and you.rooted_left >= GodMind.CHANGE_ROOT - 0.01, "caught in it: poisoned %.0f s and held fast %.1f s" % [GodMind.CHANGE_POISON, GodMind.CHANGE_ROOT])
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	mind._cool_field = 99.0
	# Crucible nova: close in, thrown back and set burning.
	ready_you.call()
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -5)), at.z - 5.0)
	mind._cool_nova = 0.0
	mind.tick(god, you, Vector3.ZERO, 5.0, 0.01)
	check(mind.phase == "nova" and isle.mist_seals.size() == 1 and isle.mist_seals[0].style == MistSeal.Style.NOVA and is_equal_approx(isle.mist_seals[0].radius, GodMind.NOVA_REACH), "within %.0f m, its crucible gathers light" % GodMind.NOVA_REACH)
	var nova: MistSeal = isle.mist_seals[0]
	nova.set_physics_process(false)
	hp = you.hp
	nova.strike()
	check(you.hp < hp and you.velocity.length() > 6.0 and you.burn_time > 0.0, "and the nova throws you back burning")
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	mind._cool_nova = 99.0
	# Crystal lance: a line of shards toward whoever stands furthest off.
	ready_you.call()
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -16)), at.z - 16.0)
	mind._cool_lance = 0.0
	mind.tick(god, you, Vector3.ZERO, 16.0, 0.01)
	var shards := isle.mist_seals.filter(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.SHARD)
	check(mind.phase == "lance" and shards.size() == GodMind.LANCE_SHARDS, "further off, a lance of %d shards strikes out toward you" % GodMind.LANCE_SHARDS)
	var toward := ((shards.back() as MistSeal).position - (shards.front() as MistSeal).position) * Vector3(1, 0, 1)
	check(toward.normalized().dot(Vector3(0, 0, 1)) > 0.95, "in a line, from it toward you")
	var shard: MistSeal = shards[2]
	shard.set_physics_process(false)
	you.position = shard.position
	shard.strike()
	check(you.slowed_left >= GodMind.SHARD_SLOW - 0.01, "a shard slows you %.1f s" % GodMind.SHARD_SLOW)
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	# Once it has changed, a fan of lances.
	god.hp = god.max_hp * (float(GodMind.STAGES[0]) - 0.01)
	mind._brooded = 1
	mind._cool_lance = 0.0
	mind.tick(god, you, Vector3.ZERO, 16.0, 0.01)
	shards = isle.mist_seals.filter(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.SHARD)
	check(mind.phase == "lance" and shards.size() == GodMind.LANCE_SHARDS * GodMind.LANCE_FAN, "once it has changed, %d lances at once (%d shards)" % [GodMind.LANCE_FAN, shards.size()])
	god.hp = god.max_hp
	mind._brooded = 0
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	mind._cool_lance = 99.0
	# It aims where you are going: a ring of change and the first flask land ahead of you.
	ready_you.call()
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -13)), at.z - 13.0)
	you.velocity = Vector3(5, 0, 0)
	mind._cool_field = 0.0
	mind.tick(god, you, Vector3.ZERO, 13.0, 0.01)
	var ring: Array = isle.mist_seals.filter(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.CHANGE)
	check(ring.size() == 1 and (ring[0] as MistSeal).position.x > you.position.x + 2.0, "its ring of change opens where you are heading (%.1f m ahead)" % ((ring[0] as MistSeal).position.x - you.position.x if ring.size() == 1 else 0.0))
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	mind._cool_field = 99.0
	mind.cooldown = 0.0
	mind.tick(god, you, Vector3.ZERO, 13.0, 0.01)
	var flasks: Array = isle.mist_seals.filter(func(m: MistSeal) -> bool: return m.style == MistSeal.Style.ELIXIR)
	var centre_x := 0.0
	for f: MistSeal in flasks: centre_x += f.position.x / flasks.size()
	check(flasks.size() == GodMind.RAIN_PER[0] and centre_x > you.position.x + 2.0, "and its flasks close round where you are going")
	you.velocity = Vector3.ZERO
	drop_seals.call()
	await frames(1)
	mind.phase = ""
	mind.cooldown = 99.0
	# Bots fight it: seen from far off, before the mutants round them, unless one is at their throat.
	var info := {"name": "Godslayer", "class": "ranger", "team": 0}
	var body := Avatar.new(isle, Net.BOT_BASE + 91, info)
	isle.add_child(body)
	var bot := BotPlayer.new(isle, body, info)
	isle.add_child(bot)
	await frames(3)
	bot.set_physics_process(false)
	bot.pawn.set_physics_process(false)
	bot.pawn.global_position = Vector3(at.x + 2.0, isle.ground_at(at + Vector3(2, 0, 16)) + 0.05, at.z + 16.0)
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -14)), at.z - 14.0)
	check(god.position.distance_to(bot.pawn.global_position) > BotPlayer.SEE_ZOMBIES, "(the god is %.0f m off, past where a bot sees the rest)" % god.position.distance_to(bot.pawn.global_position))
	isle.spawn_zombie("mutant_wasp", bot.pawn.global_position + Vector3(0, 0, -9))
	bot._decide()
	check(bot._target == god, "a bot fights the god, though it is far and a mutant is nearer")
	var throat: Zombie = isle.zombies.filter(func(z: Zombie) -> bool: return z.type_id == "mutant_wasp").front()
	throat.position = bot.pawn.global_position + Vector3(0, 0, -2.5)
	bot._decide()
	check(bot._target == throat, "but first whatever is at its throat")
	throat.release()
	bot.queue_free()
	await frames(2)
	# Below two thirds and one third: it broods, and grows quicker.
	ready_you.call()
	god.position = Vector3(at.x, isle.ground_at(at + Vector3(0, 0, -13)), at.z - 13.0)
	for stage in [1, 2]:
		god.hp = god.max_hp * (float(GodMind.STAGES[stage - 1]) - 0.01)
		var before := isle.zombies.size()
		mind.tick(god, you, Vector3.ZERO, 13.0, 0.01)
		check(mind.phase == "brood" and GodMind.stage_of(god) == stage, "below %d%% of its health it changes" % int(float(GodMind.STAGES[stage - 1]) * 100.0))
		mind.tick(god, you, Vector3.ZERO, 13.0, GodMind.BROOD_TIME + 0.01)
		check(isle.zombies.size() > before, "and mutants are born of it (%d)" % (isle.zombies.size() - before))
		mind.cooldown = 0.0
		mind.tick(god, you, Vector3.ZERO, 13.0, 0.01)
		check(is_equal_approx(mind.cooldown, GodMind.RAIN_EVERY * float(GodMind.QUICKER[stage])), "its arts come quicker (%.1f s)" % mind.cooldown)
		drop_seals.call()
		await frames(1)
		mind.phase = ""
		for z: Zombie in isle.zombies.duplicate():
			if z != god: z.release()
	# It falls: its long death, and then the dawn.
	check(is_equal_approx(MesenllaModels.death_time(id), GodModels.DEATH_TIME), "its death takes %.0f s" % GodModels.DEATH_TIME)
	d.boss_fallen(god)
	check(d._mist_boss_defeated and d.dawn_amount() >= 1.0, "when it falls, the dawn comes")
	for z: Zombie in isle.zombies.duplicate(): z.release()
	drop_seals.call()
	d.elapsed = 0.0
	d._mist_boss_spawned = false
	d._mist_boss_defeated = false
	ready_you.call()
	await frames(1)


## The Ascendant against Fontanova's own: it strikes the divine and the changed harder, its Deicide breaks
## a miniboss's attack, and the Ruin-Breaker goes through a Guardian's shield and into stone.
func _fonta_ascendant(isle: World) -> void:
	var you := isle.player
	var at := Vector3(0, isle.ground_at(Vector3(0, 0, 30)), 30)
	var was_class := you.class_id
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	var place := func(kind: String, ahead: float, side := 0.0) -> Zombie:
		var spot := at + Vector3(side, 0, -ahead)
		spot.y = isle.ground_at(spot)
		if not isle.spawn_zombie(kind, spot):
			return null
		var z: Zombie = isle.zombies.back()
		z.position = spot
		z.set_physics_process(false)
		z.hp = 10000.0
		z.max_hp = 10000.0
		return z
	you.setup_class("ascendant")
	you.chosen.clear()
	you.flags.clear()
	you.mods = Player.BASE_MODS.duplicate()
	you.spec_id = ""
	you.position = at
	you.rotation = Vector3.ZERO
	you.yaw = 0.0
	you.pitch = 0.0
	you.camera.rotation = Vector3.ZERO
	var snail: Zombie = place.call("mutant_snail", 3.0)
	var pole: Zombie = place.call("polemarch", 3.0, 3.0)
	var worshipper: Zombie = place.call("cult_worshipper", 3.0, -3.0)
	check(snail != null and pole != null and worshipper != null, "a mutant, a miniboss and a Worshipper to try it on")
	if snail == null or pole == null or worshipper == null:
		return
	check(is_equal_approx(AscendantKit.damage_scale(you, snail), 1.0 + AscendantKit.BANE) and is_equal_approx(AscendantKit.damage_scale(you, pole), 1.0 + AscendantKit.BANE)
		and is_equal_approx(AscendantKit.damage_scale(you, worshipper), 1.0), "the Ascendant strikes mutants and minibosses %d%% harder, and a mere Worshipper no harder" % roundi(AscendantKit.BANE * 100.0))
	you.flags["unbowed"] = true
	check(is_equal_approx(AscendantKit.hurt_scale(you), 1.0 - AscendantKit.UNBOWED), "Unbowed: with a miniboss near, less harm")
	you.flags.erase("unbowed")
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# A Godslayer's Deicide on the Hierophant as it readies its flasks: the attack is broken.
	you.points = 4
	for step in Player.CORE_STEPS:
		you.choose_ability(step, 0)
	you.choose_ability(Player.CORE_STEPS, 0)
	check(you.spec_id == "godslayer", "a Godslayer")
	var hiero: Zombie = place.call("hierophant", 7.0)
	hiero._sees = true
	var hm := hiero.mesenlla_mind as CultMind
	hm.cooldown = 0.0
	hm.cooldown_b = 99.0
	hm.tick(hiero, you, Vector3.ZERO, 7.0, 0.01)
	await frames(1)
	var own := func() -> int: return isle.mist_seals.filter(func(m: MistSeal) -> bool: return m.source_id == hiero.net_id and not m.struck).size()
	check(hiero.is_warning() and own.call() == 3, "the Hierophant readies three flasks")
	var h0 := hiero.hp
	AscendantKit.deicide(you)
	check(you.deicide_on == hiero, "Deicide leaps on it")
	you.set_physics_process(true)
	for i in 120:
		if you._leap_t < 0.0:
			break
		await get_tree().physics_frame
	you.set_physics_process(false)
	await frames(1)
	check(hiero.hp < h0 and not hiero.is_warning() and hm.phase == "" and own.call() == 0, "and breaks its attack, though stuns do not touch it: its rings fade without landing")
	for seal: MistSeal in isle.mist_seals.duplicate(): seal.queue_free()
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	# The Ruin-Breaker Greataxe: through a Guardian's shield, and into stone.
	you.setup_class("infantry")
	you.position = at
	you.rotation = Vector3.ZERO
	you.yaw = 0.0
	you.camera.rotation = Vector3.ZERO
	var guard: Zombie = place.call("cult_guardian", 2.0)
	guard.look_at(Vector3(you.position.x, guard.position.y, you.position.z), Vector3.UP, true)
	var sword: Dictionary = WeaponDefs.ALL["sword"]
	var axe: Dictionary = WeaponDefs.ALL["ruin_greataxe"]
	var g0 := guard.hp
	isle.melee_hit(you, sword, you.melee_stats(sword))
	var by_sword := g0 - guard.hp
	g0 = guard.hp
	isle.melee_hit(you, axe, you.melee_stats(axe))
	var by_axe := g0 - guard.hp
	var plain := float(you.melee_stats(axe)["damage"]) / float(you.melee_stats(sword)["damage"])
	check(by_sword > 0.0 and absf(by_axe / by_sword - plain / float(ZombieDefs.ALL["cult_guardian"].get("shield_cut", 0.5))) < 0.05, "a sword glances off a Guardian's shield; the Greataxe goes through it")
	guard.release()
	await frames(1)
	var stony: Zombie = place.call("cult_worshipper", 2.0)
	stony.def = stony.def.duplicate()
	stony.def["stone"] = true # this one only: what counts is that it is stone
	var s0 := stony.hp
	isle.melee_hit(you, axe, you.melee_stats(axe))
	check(absf((s0 - stony.hp) - float(you.melee_stats(axe)["damage"]) * float(axe["breaker"])) < 1.0, "it strikes stone things %d%% harder" % roundi((float(axe["breaker"]) - 1.0) * 100.0))
	check(["earth_elemental", "great_revenant_elemental", "gargoyle"].all(func(k: String) -> bool: return ZombieDefs.ALL[k].get("stone", false)), "the elementals of stone and the gargoyles are stone")
	stony.release()
	# The Resin Repeater against a mutant bee.
	var bee: Zombie = place.call("mutant_bee", 6.0)
	check(bee != null and bee.flies, "a mutant bee flies, and the Repeater's bolts are made for it")
	for z: Zombie in isle.zombies.duplicate(): z.release()
	await frames(1)
	you.setup_class(was_class)
	you.position = at


func _fonta_mutants(isle: World) -> void:
	var you := isle.player
	var at := Vector3(0, isle.ground_at(Vector3(0, 0, 30)), 30)
	var ready_you := func() -> void:
		you.position = at
		you.hp = you.max_hp()
		you.guard_left = 0.0
		you.poison_left = 0.0
		you.rooted_left = 0.0
		you.burn_time = 0.0
		you.night_blind_left = 0.0
		you.velocity = Vector3.ZERO
		you._status_immune = 0.0
	var drop_seals := func() -> void:
		for seal: MistSeal in isle.mist_seals.duplicate(): seal.queue_free()
	var honey := func() -> Array:
		return isle.pickups.filter(func(p: Pickup) -> bool: return p.item_id == "honey")
	for z: Zombie in isle.zombies.duplicate(): z.release()
	drop_seals.call()
	await frames(1)
	# Who they are.
	for id: String in FontaModels.KINDS:
		var d: Dictionary = ZombieDefs.ALL[id]
		check(d["maps"] == ["fontanova"] and SpawnRules.is_archipelago(d) and CodexPanel.enemy_group(id) == 6 and Icons.exists(id) and str(d.get("lore", "")).length() > 60, id + ": of Fontanova, in the Codex with its icon and lore")
		check(not ZombieDefs.roams(id, 600, "vael") and not ZombieDefs.roams(id, 600, "village") and not ZombieDefs.roams(id, 600, "mists"), id + " lives only on Fontanova")
		var model := MesenllaModels.build(id)
		check(MesenllaModels.KINDS.has(id) and model.has_node("Rig") and FontaMind.handles(id), id + " has its own model and mind")
		model.free()
		for table: Dictionary in [Zombie.MESENLLA_VOICES, Zombie.MESENLLA_HURT, Zombie.MESENLLA_DEATHS]:
			var sound: String = table.get(id, "")
			check(sound != "" and Sfx.NAMES.has(sound) and Net.SOUNDS.has(sound) and ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound), "%s has its own voice (%s)" % [id, sound])
	check(CodexPanel.enemy_group("kraken") == 8 and CodexPanel.enemy_group("cult_priest") == 7, "the cult has its own place in the Codex, and the bosses still come last")
	for i in 300:
		var pick := ZombieDefs.pick_roamer(900.0, "fontanova")
		if pick in ["beehive", "mutant_spider", "ostrich_rider"] or not (FontaModels.KINDS.has(pick) or CultMind.CULT.has(pick)):
			check(false, "hives, spiders and riders come only where the night puts them, never as roamers (%s)" % pick)
			break
	check(MistSeal.Style.INK == 17 and MistSeal.Style.DUST == 22 and Net.ANIMS.size() <= 63, "their strikes append wire styles and reuse animation slots")
	# Mutant Bee: a tell, a dive at where you stood, a poisoned sting; a step aside is enough.
	ready_you.call()
	check(isle.spawn_zombie("mutant_bee", at + Vector3(0, 0, -8)), "a Mutant Bee spawns")
	var bee: Zombie = isle.zombies.back()
	bee.set_physics_process(false)
	bee._sees = true
	var mind := bee.mesenlla_mind as FontaMind
	check(bee.flies and mind != null, "it flies, with its own mind")
	mind.cooldown = 0.0
	mind.tick(bee, you, Vector3.ZERO, 8.0, 0.01)
	check(mind.phase == "tell" and bee.is_warning() and bee._current_anim == "m_cast" and isle.mist_seals.is_empty(), "it curls its stinger forward before it dives, and nothing lands yet")
	var aim := mind.aim
	mind.tick(bee, you, Vector3.ZERO, 8.0, FontaMind.BEE_TELL + 0.01)
	check(mind.phase == "dive" and bee._current_anim == "m_dive", "then it dives")
	for i in 120:
		if mind.phase != "dive":
			break
		mind.tick(bee, you, Vector3.ZERO, 8.0, 1.0 / 30.0)
	check(mind.phase == "recover" and isle.mist_seals.size() == 1, "and stings where you stood")
	var sting: MistSeal = isle.mist_seals[0]
	sting.set_physics_process(false)
	you.position = aim + Vector3(4, 0, 0)
	var hp := you.hp
	sting.strike()
	check(you.hp == hp and you.poison_left <= 0.0, "a step aside and it misses")
	you.position = aim
	sting.strike()
	check(you.hp < hp and is_equal_approx(you.poison_left, FontaMind.STING_POISON), "where it lands it stings, and poisons you for %d s" % int(FontaMind.STING_POISON))
	drop_seals.call()
	await frames(1)
	bee.stun(0.5)
	check(mind.phase == "" and not bee.is_warning(), "a stun breaks off its attack")
	bee.release()
	# Honey: half the bees leave some.
	seed(11)
	var before := (honey.call() as Array).size()
	for i in 40:
		mind.on_death(bee)
	var dropped := (honey.call() as Array).size() - before
	check(dropped > 10 and dropped < 30, "about half the bees leave Honey (%d of 40)" % dropped)
	for p: Pickup in honey.call(): isle.remove_pickup(p)
	# Beehive: it grows where the map says, sends bees out when struck, spills Honey when broken.
	check(isle.hive_spots.size() == 6, "the map has six places where hives grow")
	var living := isle.count_living()
	check(isle.spawn_zombie("beehive", at + Vector3(8, 0, -8)), "a Beehive grows")
	var hive: Zombie = isle.zombies.back()
	hive.set_physics_process(false)
	check(isle.count_living() == living, "a hive is part of the island, not one of the night's hunters")
	var bees := isle.count_type("mutant_bee")
	hive.take_damage(10.0, Vector3.FORWARD, 0.0, hive.centre())
	check(isle.count_type("mutant_bee") == bees + FontaMind.HIVE_RELEASE, "struck, it sends out %d bees" % FontaMind.HIVE_RELEASE)
	hive.take_damage(10.0, Vector3.FORWARD, 0.0, hive.centre())
	check(isle.count_type("mutant_bee") == bees + FontaMind.HIVE_RELEASE, "not again at once")
	var hive_mind := hive.mesenlla_mind as FontaMind
	for i in 6:
		hive_mind._released = 0.0
		hive_mind.on_hurt(hive)
	var from_hive := isle.zombies.filter(func(z: Zombie) -> bool: return z.is_alive() and int(z.get_meta("from", -1)) == hive.net_id).size()
	check(from_hive == FontaMind.HIVE_BEES, "never more than %d of its bees at once" % FontaMind.HIVE_BEES)
	hive_mind.on_death(hive)
	check((honey.call() as Array).size() == FontaMind.HIVE_HONEY, "broken, it spills %d Honey" % FontaMind.HIVE_HONEY)
	for p: Pickup in honey.call(): isle.remove_pickup(p)
	for z: Zombie in isle.zombies.duplicate(): z.release()
	# Honey: worth eating unhurt, for its speed, but not twice over.
	ready_you.call()
	you._buffs.erase("honey")
	var pot := isle.spawn_pickup_at(you.position, Pickup.Kind.FOOD, "honey")
	isle._scan_pickups_for(you)
	check(not isle.pickups.has(pot) and you._buffs.has("honey") and is_equal_approx(float(you._buffs["honey"]["val"]), PowerDefs.HONEY_SPEED) and is_equal_approx(float(you._buffs["honey"]["left"]), PowerDefs.HONEY_HASTE), "Honey quickens you even unhurt")
	you._buffs["honey"]["left"] = 1.0
	var pot2 := isle.spawn_pickup_at(you.position, Pickup.Kind.FOOD, "honey")
	isle._scan_pickups_for(you)
	check(not isle.pickups.has(pot2) and is_equal_approx(float(you._buffs["honey"]["left"]), PowerDefs.HONEY_HASTE), "a second pot, unhurt and still quick: you take it, and the speed starts over")
	you.hp = you.max_hp() - 40.0
	var pot3 := isle.spawn_pickup_at(you.position, Pickup.Kind.FOOD, "honey")
	isle._scan_pickups_for(you)
	check(not isle.pickups.has(pot3) and is_equal_approx(you.hp, you.max_hp() - 40.0 + float(PowerDefs.FOODS["honey"]["heal"])), "hurt, you eat it for its healing")
	# Something freed out from under the list of pickups does not stop you taking what is there.
	var gone := isle.spawn_pickup_at(you.position + Vector3(30, 0, 0), Pickup.Kind.FOOD, "apple")
	gone.free()
	you.hp = you.max_hp() - 40.0
	var pot4 := isle.spawn_pickup_at(you.position, Pickup.Kind.FOOD, "honey")
	isle._scan_pickups_for(you)
	check(not isle.pickups.has(pot4) and isle.pickups.all(func(k: Variant) -> bool: return is_instance_valid(k)), "a freed pickup in the list is let go of, and Honey is still taken")
	you.hp = you.max_hp()
	you._buffs.erase("honey")
	check(PowerDefs.FOODS["honey"]["weight"] == 0.0 and PowerDefs.mesh("honey") != null, "Honey is never found lying about, only dropped, and has its own pot")
	# Mutant Wasp: the stinger from afar, which poisons; close in, a dive to bite.
	ready_you.call()
	check(isle.spawn_zombie("mutant_wasp", at + Vector3(0, 0, -10)), "a Mutant Wasp spawns")
	var wasp: Zombie = isle.zombies.back()
	wasp.set_physics_process(false)
	wasp._sees = true
	mind = wasp.mesenlla_mind as FontaMind
	mind.cooldown = 0.0
	mind.tick(wasp, you, Vector3.ZERO, 10.0, 0.01)
	check(mind.phase == "tell" and wasp.is_warning(), "at range it arches its abdomen under itself first")
	mind.tick(wasp, you, Vector3.ZERO, 10.0, FontaMind.WASP_TELL + 0.01)
	var stingers := isle._projectiles.filter(func(p: Projectile) -> bool: return p.active and p.source == "mutant_wasp")
	check(stingers.size() == 1 and wasp._current_anim == "m_throw", "then shoots its stinger")
	if stingers.size() == 1:
		var stinger: Projectile = stingers[0]
		ready_you.call()
		await get_tree().physics_frame
		for i in 60:
			if not stinger.active:
				break
			stinger._fly(1.0 / 30.0)
		check(you.hp < you.max_hp() and is_equal_approx(you.poison_left, FontaMind.WASP_POISON), "which poisons you for %d s" % int(FontaMind.WASP_POISON))
	for p: Projectile in isle._projectiles:
		if p.active: p.stop()
	mind.phase = ""
	mind.cooldown = 0.0
	mind.tick(wasp, you, Vector3.ZERO, 2.0, 0.01)
	mind.tick(wasp, you, Vector3.ZERO, 2.0, FontaMind.WASP_TELL + 0.01)
	check(mind.phase == "dive", "close in, it dives to bite")
	wasp.release()
	# Wasp-Hive Snail: its nest shudders, then a wasp crawls out; no more than three of its own.
	check(isle.spawn_zombie("wasp_hive_snail", at + Vector3(0, 0, -12)), "a Wasp-Hive Snail spawns")
	var nest: Zombie = isle.zombies.back()
	nest.set_physics_process(false)
	nest._sees = true
	mind = nest.mesenlla_mind as FontaMind
	for i in 5:
		mind.cooldown = 0.0
		mind.tick(nest, you, Vector3.ZERO, 12.0, 0.01)
		check(i > 0 or (mind.phase == "tell" and nest.is_warning()), "its nest shudders first")
		mind.tick(nest, you, Vector3.ZERO, 12.0, FontaMind.NEST_TELL + 0.01)
	var wasps := isle.zombies.filter(func(z: Zombie) -> bool: return z.is_alive() and int(z.get_meta("from", -1)) == nest.net_id).size()
	check(wasps == FontaMind.NEST_WASPS, "then wasps crawl out of it, %d of its own at most" % FontaMind.NEST_WASPS)
	for z: Zombie in isle.zombies.duplicate(): z.release()
	# Mutant Snail: a trail behind it, poison or fire, that lasts.
	ready_you.call()
	check(isle.spawn_zombie("mutant_snail", at + Vector3(0, 0, -6)), "a Mutant Snail spawns")
	var snail: Zombie = isle.zombies.back()
	snail.set_physics_process(false)
	var trails := FontaTrails.of(isle)
	for step in 6:
		snail.position = at + Vector3(0, 0, -6 + step * 1.4)
		trails.track(snail)
	var laid := trails._life.filter(func(life: float) -> bool: return life > 0.0).size()
	check(laid >= 4, "a snail leaves a trail as it crawls (%d)" % laid)
	you.position = at + Vector3(0, 0, -2)
	trails._check = 0.0
	trails._process(0.01)
	var poisoned := FontaMind.trail_of(snail) == "poison"
	check(you.poison_left > 0.0 if poisoned else you.burn_time > 0.0, "stepping in it %s" % ("poisons you" if poisoned else "sets you alight"))
	trails._process(FontaTrails.TRAIL_LIFE)
	check(trails._life.all(func(life: float) -> bool: return life <= 0.0), "and it is gone after %d s" % int(FontaTrails.TRAIL_LIFE))
	snail.release()
	# Mutant Spider: perched head down on a trunk, on the bark, until you come near; its web roots and poisons.
	ready_you.call()
	check(isle.spider_trunks.size() >= 10, "the island's trees have trunks to cling to (%d)" % isle.spider_trunks.size())
	var trunk: Dictionary = isle.spider_trunks[0]
	var tree: Vector3 = trunk["at"]
	you.position = tree + Vector3(25, 0, 0)
	you.position.y = isle.ground_at(you.position)
	var spider: Zombie = null
	var placed := false
	for i in 30:
		if isle.spawn_spider():
			placed = true
			break
	check(placed, "a spider takes to a tree a way off from you")
	spider = isle.zombies.back()
	spider.set_physics_process(false)
	mind = spider.mesenlla_mind as FontaMind
	var home: Dictionary = {}
	for p: Dictionary in isle.spider_trunks:
		if home.is_empty() or Vector2((p["at"] as Vector3).x - spider.position.x, (p["at"] as Vector3).z - spider.position.z).length() < Vector2((home["at"] as Vector3).x - spider.position.x, (home["at"] as Vector3).z - spider.position.z).length():
			home = p
	var off := Vector2((home["at"] as Vector3).x - spider.position.x, (home["at"] as Vector3).z - spider.position.z).length()
	var up := spider.position.y + FontaMind.SPIDER_RIG - isle.ground_at(home["at"])
	check(mind.perched and is_equal_approx(off, float(home["girth"]) + FontaMind.CLING), "it clings on the bark of its trunk, not inside it (%.2f m out)" % off)
	check(up >= FontaMind.PERCH_LOW - 0.01 and up <= FontaMind.PERCH_HIGH + 0.01 and up <= maxf(float(home["high"]), FontaMind.PERCH_LOW) + 0.01, "below the leaves (%.1f m up)" % up)
	spider._sees = true
	mind.tick(spider, you, Vector3.ZERO, 30.0, 0.1)
	check(mind.perched and spider._current_anim == "m_sink" and mind.phase == "", "far off, it waits head down")
	# On the side it faces, out from its trunk.
	you.position = spider.position + Vector3(sin(spider.rotation.y), 0, cos(spider.rotation.y)) * 6.0
	you.position.y = isle.ground_at(you.position)
	mind.tick(spider, you, Vector3.ZERO, 6.0, 0.1)
	check(mind.phase == "pounce" and isle.mist_seals.size() == 1, "come near and it drops on you, its landing marked")
	var web: MistSeal = isle.mist_seals[0]
	web.set_physics_process(false)
	for i in 40:
		mind.tick(spider, you, Vector3.ZERO, 3.0, 1.0 / 30.0)
	check(not mind.perched and mind.phase == "" and absf(spider.position.y - isle.ground_at(spider.position)) < 0.3, "and lands on the ground")
	you.position = web.position
	web.strike()
	check(you.rooted_left >= FontaMind.WEB_ROOT - 0.01 and you.poison_left >= FontaMind.WEB_POISON - 0.01, "its web holds you and poisons you")
	drop_seals.call()
	await frames(1)
	spider.release()
	isle.spawn_spider()
	spider = isle.zombies.back()
	spider.set_physics_process(false)
	spider.stun(0.5)
	check(not (spider.mesenlla_mind as FontaMind).perched, "a stun knocks a spider off its tree")
	spider.release()
	# Battle Ostrich: paws the ground, charges, and kicks away whoever it reaches.
	ready_you.call()
	check(isle.spawn_zombie("battle_ostrich", at + Vector3(0, 0, -12)), "a Battle Ostrich spawns")
	var ostrich: Zombie = isle.zombies.back()
	ostrich.set_physics_process(false)
	ostrich._sees = true
	mind = ostrich.mesenlla_mind as FontaMind
	mind.cooldown = 0.0
	mind.tick(ostrich, you, Vector3.ZERO, 12.0, 0.01)
	check(mind.phase == "tell" and ostrich.is_warning(), "it paws the ground before it charges")
	mind.tick(ostrich, you, Vector3.ZERO, 12.0, FontaMind.CHARGE_TELL_OSTRICH + 0.01)
	check(mind.phase == "charge" and ostrich._current_anim == "m_charge", "then charges")
	for i in 90:
		if mind.phase != "charge":
			break
		mind.tick(ostrich, you, Vector3.ZERO, ostrich.position.distance_to(you.position), 1.0 / 30.0)
	check(isle.mist_seals.size() == 1, "and kicks you when it reaches you")
	var kick: MistSeal = isle.mist_seals[0]
	kick.set_physics_process(false)
	hp = you.hp
	kick.strike()
	check(you.hp < hp and Vector2(you.velocity.x, you.velocity.z).length() > 5.0, "the kick throws you away")
	drop_seals.call()
	await frames(1)
	ostrich.release()
	# Ember Moth: wings spread a second, then the burning dust dazzles and sets alight.
	ready_you.call()
	check(isle.spawn_zombie("ember_moth", at + Vector3(0, 0, -10)), "an Ember Moth spawns")
	var moth: Zombie = isle.zombies.back()
	moth.set_physics_process(false)
	moth._sees = true
	mind = moth.mesenlla_mind as FontaMind
	mind.cooldown = 0.0
	mind.tick(moth, you, Vector3.ZERO, 10.0, 0.01)
	check(mind.phase == "tell" and moth.is_warning() and isle.mist_seals.is_empty(), "it spreads its wings, eye-spots blazing")
	mind.tick(moth, you, Vector3.ZERO, 10.0, FontaMind.MOTH_TELL * 0.5)
	check(isle.mist_seals.is_empty(), "and holds them")
	mind.tick(moth, you, Vector3.ZERO, 10.0, FontaMind.MOTH_TELL * 0.5 + 0.01)
	check(isle.mist_seals.size() == 1 and moth._current_anim == "m_throw", "then claps them")
	var dust: MistSeal = isle.mist_seals[0]
	dust.set_physics_process(false)
	you.position = dust.position
	dust.strike()
	check(you.night_blind_left >= FontaMind.DUST_BLIND - 0.01 and you.burn_time >= FontaMind.DUST_BURN - 0.01, "the dust dazzles you and sets you alight")
	drop_seals.call()
	await frames(1)
	moth.release()
	# Thornback: blows from the front glance off its shell.
	check(isle.spawn_zombie("thornback", at + Vector3(0, 0, -6)), "a Thornback spawns")
	var tortoise: Zombie = isle.zombies.back()
	tortoise.set_physics_process(false)
	tortoise.rotation.y = 0.0
	var full := tortoise.hp
	tortoise.take_damage(40.0, Vector3(0, 0, -1), 0.0, tortoise.centre())
	var front := full - tortoise.hp
	tortoise.hp = full
	tortoise.take_damage(40.0, Vector3(0, 0, 1), 0.0, tortoise.centre())
	var back := full - tortoise.hp
	check(front > 0.0 and is_equal_approx(front * 2.0, back), "struck from the front it takes half (%.0f of %.0f)" % [front, back])
	tortoise.release()
	# The night: hives grow at its start, spiders take to the trees from 3:20.
	for z: Zombie in isle.zombies.duplicate(): z.release()
	ready_you.call()
	isle.director.elapsed = 10.0
	isle.director._tick_fontanova()
	check(isle.count_type("beehive") == isle.hive_spots.size(), "the hives grow where the map says, at the start of the night")
	isle.director._tick_fontanova()
	check(isle.count_type("beehive") == isle.hive_spots.size(), "once a night")
	check(isle.count_type("mutant_spider") == 0, "no spiders yet")
	isle.director.elapsed = Director.SPIDERS_FROM + 1.0
	you.position = tree + Vector3(25, 0, 0)
	you.position.y = isle.ground_at(you.position)
	for i in 10:
		isle.director._next_spider = 0.0
		isle.director._tick_fontanova()
	check(isle.count_type("mutant_spider") == Director.MAX_SPIDERS, "from %d:%02d spiders wait in the trees, %d at most" % [int(Director.SPIDERS_FROM) / 60, int(Director.SPIDERS_FROM) % 60, Director.MAX_SPIDERS])
	for z: Zombie in isle.zombies.duplicate(): z.release()
	ready_you.call()
	# How each of them dies: in stages, the body moving through them, the god's glow going out, and
	# whole again when the same creature comes back.
	for id: String in FontaModels.KINDS:
		var spot := at + Vector3(0, 2.2 if id in FontaModels.FLYERS else 0.0, -8)
		if not isle.spawn_zombie(id, spot):
			check(false, id + " spawns to be killed")
			continue
		var z: Zombie = isle.zombies.back()
		z.position = spot
		var rig := z._visual.get_node("Rig") as Node3D
		var pose_of := func() -> Array:
			var out: Array = [z._visual.transform]
			for n in z._visual.find_children("*", "Node3D", true, false):
				out.append((n as Node3D).transform)
			return out
		var rest: Array = pose_of.call()
		z.take_damage(z.hp + 1000.0, Vector3.ZERO, 0.0, z.centre())
		var poses: Array[Array] = []
		var t := 0.0
		while z.active and t < 4.0:
			z._physics_process(1.0 / 30.0)
			t += 1.0 / 30.0
			if absf(fmod(t, 0.5)) < 1.0 / 30.0:
				poses.append(pose_of.call())
		var same := func(a: Array, b: Array) -> bool:
			for i in a.size():
				if not (a[i] as Transform3D).is_equal_approx(b[i]):
					return false
			return true
		var moved := poses.filter(func(p: Array) -> bool: return not same.call(p, rest)).size()
		var distinct := 0
		for i in range(1, poses.size()):
			if not same.call(poses[i], poses[i - 1]):
				distinct += 1
		check(t >= FontaModels.death_time(id) - 0.1 and moved >= 3 and distinct >= 2, "%s dies in stages over %.1f s (%d poses)" % [id, FontaModels.death_time(id), distinct + 1])
		var beat := "splash" if id in ["mutant_bee", "mutant_wasp"] else "dust" if id == "ember_moth" else "slump" if id == "mutant_spider" else "spill" if id in FontaModels.SNAILS else "crack" if id == "beehive" else "thud"
		check(not z.active and z._visual.has_meta("did_" + beat), "%s: the moment it hits the ground is marked (%s), and the body is gone after" % [id, beat])
		isle.spawn_zombie(id, spot)
		var again: Zombie = isle.zombies.back()
		if again == z:
			check(same.call(pose_of.call(), rest) and not z._visual.has_meta("landed_at") and z._visual.find_children("*", "MeshInstance3D", true, false).all(func(m: Node) -> bool: return (m as MeshInstance3D).visible), "%s comes back whole" % id)
		for other: Zombie in isle.zombies.duplicate(): other.release()
	# The wasp's stinger is its own, not an arrow.
	isle.spawn_enemy_arrow(at + Vector3(0, 2, 0), at + Vector3(0, 2, 10), 5.0, 30.0, false, "mutant_wasp")
	var shot: Projectile = null
	for n in isle.find_children("*", "Projectile", true, false):
		if (n as Projectile).active and (n as Projectile).source == "mutant_wasp":
			shot = n
	check(shot != null and shot.mesh != World._arrow_mesh and shot.spins and shot.poison_trail, "a Mutant Wasp's stinger flies as a stinger, corkscrewing and venomous, not as an arrow")
	if shot:
		shot.stop()


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
