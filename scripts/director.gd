class_name Director
extends Node
## Runs the night: roaming population, Beast howls, supplies, and dawn.

const FIRST_BEAST := 170.0
const BEAST_EVERY := 85.0
const MAX_BEASTS := 2
const LAST_STAND_BEASTS := 3
const LAST_STAND_BEAST_EVERY := 45.0
const LAST_STAND_HERO_EVERY := 45.0
const FAMILIAR_EVERY := 30.0
const FIRST_HERO := 210.0
const HERO_EVERY := 70.0
const FIRST_CROWS := 120.0
const CROWS_EVERY := 55.0
const FIRST_GARGOYLE := 240.0
const GARGOYLE_EVERY := 70.0
const FIRST_AMBUSH := 90.0
const AMBUSH_EVERY := 35.0
const DAWN_GLOW := 120.0 # seconds before dawn when the sky starts to change
const LAST_STAND := 480.0 # the undead sense the dawn: more of them, and they all come for you
const LAST_STAND_CALL := 18.0
const FAR_AWAY := 92.0
const WOOD_ON_MAP := 7
const FIRST_RIDER := 300.0
const RIDER_EVERY := 75.0
const MAX_RIDERS := 2

var world: World
var running := false
var elapsed := 0.0
var banner := ""
var banner_time := 0.0
var _spawn_timer := 0.0
var _stock_timer := 0.0
var _familiar_timer := FAMILIAR_EVERY
var _next_hero := FIRST_HERO
var _next_crows := FIRST_CROWS
var _next_gargoyle := FIRST_GARGOYLE
var _next_ambush := FIRST_AMBUSH
var _hero_index := 0
var _next_beast := FIRST_BEAST
var _won := false
var _waiting := false # a multiplayer game has not started yet
var _follows_host := false
var _bell_timer := 60.0
var _bell_minute := 0
var sandbox := false
var _last_stand := false
var _call_timer := 0.0
var _far_timer := 4.0
var _next_rider := FIRST_RIDER


func _init(owner_world: World) -> void:
	world = owner_world


## In a multiplayer game this waits for all phones to load. A joined phone only keeps the clock.
func join_game(follow: bool) -> void:
	_follows_host = follow
	_waiting = not follow
	running = follow


## No night and no zombies unless you ask for them: only rows of things to try.
func begin_sandbox() -> void:
	_waiting = false
	running = false
	sandbox = true
	world.set_up_stands()
	for at: Vector3 in world.dummy_spots:
		world.spawn_zombie("dummy", at)


func begin(with_zombies: bool) -> void:
	_waiting = false
	running = with_zombies
	for i in 6:
		stock(Pickup.Kind.WEAPON)
	for i in 4:
		stock(Pickup.Kind.FOOD)
	for i in 3:
		stock(Pickup.Kind.ARROWS)
	for i in 2:
		stock(Pickup.Kind.POWER)
	_spawn_familiar()
	if world.fort:
		for i in WOOD_ON_MAP:
			world.stock_wood()
	if running:
		_spawn_timer = 0.0
		for i in target_population():
			world.spawn_zombie(ZombieDefs.pick_roamer(elapsed))
		var opening := "Survive until dawn"
		if world.fort:
			opening = "Hold the fort until dawn"
		elif Net.fog_rules():
			opening = "Three lives. Last one standing"
		show_banner(opening, 4.0)


func show_banner(text: String, seconds: float) -> void:
	banner = text
	banner_time = seconds
	if Net.is_host():
		Net.banner(text, seconds)


## How long this match runs. In All vs All the clock counts down to the fog closing, not to dawn.
func match_length() -> float:
	return ClosingFog.TOTAL if Net.fog_rules() else Game.NIGHT_LENGTH


func night_left() -> float:
	return maxf(0.0, match_length() - elapsed)


## 0 at night, 1 at dawn.
func dawn_amount() -> float:
	if not running or Net.fog_rules():
		return 0.0
	return clampf(1.0 - night_left() / DAWN_GLOW, 0.0, 1.0)


## The night starts calm and fills up to the phone's zombie limit.
func target_population() -> int:
	var cap := Game.max_live_zombies()
	var start := mini(6, cap)
	# A slow start while the player finds a weapon, then the crowd builds.
	var t := pow(clampf(elapsed / (Game.NIGHT_LENGTH * 0.75), 0.0, 1.0), 1.3)
	var crowd := lerpf(start, cap, t) * (1.0 + 0.35 * (world.players.size() - 1))
	if elapsed >= LAST_STAND:
		crowd *= 1.3
	if Net.fog_rules():
		crowd *= 0.6 # enough to keep you busy, but the others are the danger here
	return int(round(crowd))


func stock(kind: int) -> void:
	match kind:
		Pickup.Kind.WEAPON: world.spawn_pickup_random(kind, WeaponDefs.pick_random())
		Pickup.Kind.FOOD: world.spawn_pickup_random(kind, PowerDefs.pick_weighted(PowerDefs.FOODS))
		Pickup.Kind.ARROWS: world.spawn_pickup_random(kind, "arrows")
		Pickup.Kind.POWER: world.spawn_pickup_random(kind, PowerDefs.pick_potion())


func _process(delta: float) -> void:
	banner_time = maxf(0.0, banner_time - delta)
	if sandbox:
		world.tick_stands(delta)
		return
	if _follows_host:
		if running:
			elapsed += delta
		return
	if _waiting or _won or _everyone_down():
		return
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		_bell_timer = 60.0
		_bell_minute += 1
		world.ring_bell(_bell_minute)
		if Net.is_host():
			Net.bell(_bell_minute)
	_stock_timer -= delta
	if _stock_timer <= 0.0:
		_stock_timer = 8.0
		_restock()
		if world.fort and world.count_pickups(Pickup.Kind.WOOD) < WOOD_ON_MAP:
			world.stock_wood()
	_familiar_timer -= delta
	if _familiar_timer <= 0.0:
		_familiar_timer = FAMILIAR_EVERY
		_spawn_familiar()
	if not running:
		return
	elapsed += delta
	_tick_specials()
	_tick_last_stand(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.25 if _last_stand else 2.5
		var living := world.count_living()
		if living < target_population():
			world.spawn_zombie(ZombieDefs.pick_roamer(elapsed))
	if elapsed >= _next_beast:
		_next_beast = elapsed + (LAST_STAND_BEAST_EVERY if _last_stand else BEAST_EVERY)
		if world.count_type("beast") < (LAST_STAND_BEASTS if _last_stand else MAX_BEASTS) and world.spawn_zombie("beast"):
			_sound("howl", 0.0)
			show_banner("A howl in the dark...", 3.0)
	_far_timer -= delta
	if _far_timer <= 0.0:
		_far_timer = 4.0
		if world.fort == null:
			_clear_far_zombies()
	if elapsed >= Game.NIGHT_LENGTH and not Net.fog_rules():
		_won = true
		_sound("rooster", 0.0)
		if Net.is_host():
			Net.dawn()
		world.on_dawn()


func _everyone_down() -> bool:
	for p in world.players:
		if not p.dead:
			return false
	return not world.players.is_empty()


func _sound(sound: String, volume: float, pitch := 1.0) -> void:
	Sfx.play(sound, volume, pitch, 1.0)
	if Net.is_host():
		Net.sound_all(sound, volume, pitch)


## The map is big, and a zombie that wandered off into the distance is a zombie nobody will meet.
## It comes back around where the players are instead.
func _clear_far_zombies() -> void:
	for z: Zombie in world.zombies.duplicate():
		if not z.is_alive() or z.flies or z.dormant or z.hero or z.is_hunting():
			continue
		var near := INF
		for p in world.players:
			near = minf(near, z.position.distance_to(p.global_position))
		if near > FAR_AWAY:
			z.release()


## A familiar always appears within reach. The sound says one is out there; finding it is up to you.
func _spawn_familiar() -> void:
	var who: Target = world.players[randi() % world.players.size()] if not world.players.is_empty() else null
	var p := world.spawn_pickup_near_player(Pickup.Kind.POWER, PowerDefs.pick_familiar(), 10.0, 26.0, who)
	if p and who:
		if who is Avatar:
			Net.familiar_near((who as Avatar).peer)
		else:
			Sfx.play("familiar", -4.0)


## The last two minutes: the sky starts to change, and everything still standing wants you dead.
func _tick_last_stand(delta: float) -> void:
	if Net.fog_rules():
		return
	if not _last_stand:
		if elapsed >= LAST_STAND:
			_last_stand = true
			_call_timer = 2.0
			show_banner("They sense the dawn...", 4.0)
			_sound("howl", -1.0, 0.8)
		return
	_call_timer -= delta
	if _call_timer <= 0.0 and world.player:
		_call_timer = LAST_STAND_CALL
		world.call_all_to_players()


func minute() -> int:
	return int(elapsed / 60.0)


func _tick_specials() -> void:
	if elapsed >= _next_rider:
		_next_rider = elapsed + RIDER_EVERY
		if world.count_type("rider") < MAX_RIDERS + (1 if _last_stand else 0) and world.spawn_zombie("rider"):
			_sound("gallop", 2.0)
			show_banner("Hooves in the dark...", 3.0)
	if elapsed >= _next_crows:
		_next_crows = elapsed + CROWS_EVERY
		for i in 3:
			world.spawn_zombie("crow")
		world.sfx_at("crow", world.player.global_position + Vector3(20, 0, 0), -4.0)
	if elapsed >= _next_gargoyle:
		_next_gargoyle = elapsed + GARGOYLE_EVERY
		world.spawn_gargoyle()
	if elapsed >= _next_ambush:
		_next_ambush = elapsed + AMBUSH_EVERY
		if world.fort:
			pass
		elif randf() < 0.5:
			world.spawn_mimic()
		else:
			world.spawn_scarecrow()
	if elapsed >= _next_hero:
		_next_hero = elapsed + (LAST_STAND_HERO_EVERY if _last_stand else HERO_EVERY)
		# If every body of this hero's kind is out there already, the next hero takes its turn.
		for i in ZombieDefs.HEROES.size():
			var id: String = ZombieDefs.HEROES[_hero_index % ZombieDefs.HEROES.size()]
			_hero_index += 1
			if world.spawn_zombie(id):
				show_banner("%s rises" % ZombieDefs.ALL[id]["name"], 3.0)
				_sound("wraith", -4.0, 0.8)
				break


func _restock() -> void:
	if world.count_pickups(Pickup.Kind.WEAPON) < 7:
		stock(Pickup.Kind.WEAPON)
	if world.count_pickups(Pickup.Kind.FOOD) < 6:
		stock(Pickup.Kind.FOOD)
	if world.count_pickups(Pickup.Kind.ARROWS) < 4:
		stock(Pickup.Kind.ARROWS)
	var potions := 0
	for p in world.pickups:
		if p.kind == Pickup.Kind.POWER and not PowerDefs.ALL[p.item_id]["familiar"]:
			potions += 1
	if potions < 3:
		stock(Pickup.Kind.POWER)
