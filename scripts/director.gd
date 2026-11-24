class_name Director
extends Node
## Runs the night: roaming population, Beast howls, supplies, and dawn.

const BASTION_CROWD := 1.6 # how many more come up the lanes of Mist Bastion than roam other maps
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
const FIRST_HARRIER := 150.0
const HARRIER_EVERY := 60.0
const MAX_HARRIERS := 3
const FIRST_AMBUSH := 90.0
const AMBUSH_EVERY := 35.0
const DAWN_GLOW := 120.0 # seconds before dawn when the sky starts to change
## What each land sounds like when the dead sense the dawn. The Village and the Fort keep the wolf.
const DAWN_SOUNDS := {"mists": "dawn_mists", "mesenlla": "dawn_valleys", "bastion": "dawn_bastion", "vael": "dawn_vael", "fontanova": "dawn_fontanova"}
const LAST_STAND := 480.0 # the undead sense the dawn: more of them, and they all come for you
const LAST_STAND_CALL := 18.0
const FAR_AWAY := 92.0
const WOOD_EVERY := 4.0 # Defend the Fort: seconds between new pieces of wood, while short of World.wood_target()
const FIRST_RIDER := 300.0
const RIDER_EVERY := 75.0
const MAX_RIDERS := 2
## Beyond the Mists: eagles circle in from the peaks, wyverns come down late, and the Woodland
## Cavalry ride through the valley.
const FIRST_WYVERN := 300.0
const WYVERN_EVERY := 95.0
const MAX_WYVERNS := 1
# Port Vael (_tick_vael)
const HOUND_PACK_EVERY := 80.0
const MAX_HOUNDS := 6
const JELLIES_EVERY := 30.0 # while the tide is high
const JELLIES_AT_ONCE := 2
const MAX_JELLIES := 6
const MAX_ANGLERS := 3
# Port Vael, the drowned court (_tick_court): Sirens at the water's edge and Press Gangs through the
# night, and three who come once each, at their hour: the Harbourmaster up the quay stairs, the
# Kraken's four arms out of the flooded flats at the high tide after it, the Lighthouse Keeper down the
# East Mole. The Hollow Sovereign rises from the flats around 8:30 (_tick_mist_boss), and the night
# ends only when he falls (in Teams too, where his crown is a prize for either side). In All vs All
# there is no court: the Sunken Crown washes up at the Drowned Bell instead.
const SIREN_EVERY := 60.0
const MAX_SIRENS := 2
const PRESS_EVERY := 95.0
const MAX_PRESS := 6
const HARBOURMASTER_AT := 180.0
const KRAKEN_AT := 280.0 # the high tide after 4:30
const KEEPER_AT := 360.0
const QUAY_STAIRS := [Vector3(-30, 0, 10), Vector3(30, 0, 10)] # the foot of each, on the flats
const KEEPER_FROM := Vector3(84, 2.0, 62) # on the East Mole, under the lighthouse
const SOVEREIGN_FROM := Vector3(0, 0, 44) # the middle of the flats
# The end of it all: once the Hollow Sovereign and the Leviathan have both fallen, the harbour goes
# still, and after a little while the Kraken rises in front of the quay, under the Tide King's gaze.
# Dawn will not come until it sinks.
const KRAKEN := "kraken"
const KRAKEN_AFTER := 14.0 # seconds of stillness before it rises
const KRAKEN_FROM := Vector3(0, 0, 24)
const KRAKEN_HOLDS_TIDE := 900.0 # it holds the tide in while it lives
const CROWN_AT := 120.0 # All vs All: when the Sunken Crown washes up at the Drowned Bell
const CROWN_SPOT := Vector3(8, 0, 34)
const VAEL_BOSS := "hollow_sovereign"
const MESENLLA_BOSS := "great_revenant_elemental"
const BASTION_BOSS := "war_wyvern"

var world: World
var running := false
var elapsed := 0.0
var banner := ""
var banner_time := 0.0
var _spawn_timer := 0.0
var _stock_timer := 0.0
var _wood_timer := 0.0
var _familiar_timer := FAMILIAR_EVERY
var _next_hero := FIRST_HERO
var _next_crows := FIRST_CROWS
var _next_gargoyle := FIRST_GARGOYLE
var _next_harrier := FIRST_HARRIER
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
var _next_storm := MistStorm.FIRST
var _storm_index := 0
var _storms_last := 0 # island storms raging at the last look, to notice when one ends
var camp: CampSiege # the shelling of the Valleys' camp, on that map
var _cache_due := {} # cache spot index -> when it may be filled again
var _cache_look := 0.0
var _mist_boss_at := 510.0
var _mist_boss_spawned := false
var _coastal_leviathan := false
var _kraken_at := -1.0
var _kraken_risen := false
var _kraken_fallen := false
var _mist_boss_defeated := false
var _next_wyvern := FIRST_WYVERN
var _next_siren := 150.0
var _next_press := 200.0
var _court_came := {} # which of the court has come tonight
var _crown_washed := false


func _init(owner_world: World) -> void:
	world = owner_world
	_mist_boss_at = randf_range(505.0, 515.0)


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
	for i in (10 if world.terrain.has_islands() else 6):
		stock(Pickup.Kind.WEAPON)
	for i in (9 if world.terrain.has_islands() else 4):
		stock(Pickup.Kind.FOOD)
	for i in (7 if world.terrain.has_islands() else 3):
		stock(Pickup.Kind.ARROWS)
	for i in (4 if world.terrain.has_islands() else 2):
		stock(Pickup.Kind.POWER)
	_spawn_familiar()
	if world.fort:
		for i in world.wood_target():
			world.stock_wood()
	if running:
		_spawn_timer = 0.0
		for i in target_population():
			_spawn_roamer()
		show_banner(opening_line(), 4.0)


## What the night asks of you, as it begins: to live until the dawn, or to keep something standing
## until then. Whatever else the night holds (a boss, a barrage) is not given away here.
func opening_line() -> String:
	var opening := "Survive until the dawn"
	if world.last_light:
		opening = "Walk with the Lantern Barge to the Isle of Lamps"
	elif world.map_id == "bastion":
		opening = "Defend the Great Portal until the dawn"
	elif world.fort:
		opening = "Defend the fort until the dawn"
	elif Net.fog_rules():
		opening = "Three lives. Last one standing"
	return opening


## Every boss enters with a card of its own instead of an ordinary banner: its name large in its
## colour, where it comes, what it says as it comes (its "first_words"), and the soundtrack's bells
## (tools/make_boss_bells.py). As it falls it says its "last_words". World.spawn_zombie shows the card
## for any boss, so a boss added later only needs its card here and its words in ZombieDefs.
const BOSS_CARDS := {
	"veil_regent": {"name": "Veil Regent", "line": "wakes on its throne in the Mists", "color": Color(0.78, 0.62, 1.0), "glow": Color(0.36, 0.16, 0.62), "bells": "boss_bells_regent", "strikes": [0.0, 0.7, 1.4, 2.2, 2.6]},
	MESENLLA_BOSS: {"name": "Great Revenant Elemental", "line": "rises at the Ring of Stones", "color": Color(0.45, 0.95, 0.88), "glow": Color(0.15, 0.55, 0.62), "bells": "boss_bells_revenant", "strikes": [0.0, 0.55, 1.1, 1.75]},
	BASTION_BOSS: {"name": "War Wyvern", "line": "comes for the Great Portal", "color": Color(1.0, 0.56, 0.2), "glow": Color(0.72, 0.12, 0.06), "bells": "boss_bells_wyvern", "strikes": [0.0, 0.24, 0.48, 0.8, 1.25]},
	LastLight.LEVIATHAN: {"name": "Leviathan of the Mists", "line": "the drowned harbour belongs to the deep", "color": Color(0.5, 0.95, 0.85), "glow": Color(0.05, 0.3, 0.35), "bells": "boss_bells_leviathan", "strikes": [0.0, 1.1, 2.2, 2.6, 3.0]},
	VAEL_BOSS: {"name": "Hollow Sovereign", "line": "rises from the drowned harbour", "color": Color(0.98, 0.8, 0.36), "glow": Color(0.1, 0.42, 0.4), "bells": "boss_bells_sovereign", "strikes": [0.0, 0.9, 1.8, 2.25, 2.7]},
	KRAKEN: {"name": "The Kraken", "line": "the last of Vael rises from the deep", "color": Color(0.45, 1.0, 0.8), "glow": Color(0.32, 0.06, 0.2), "bells": "boss_bells_kraken", "strikes": [0.0, 0.32, 1.2, 1.86, 2.3, 3.3]},
}
const BOSS_CARD_TIME := 7.0 # long enough to read what it says
var boss_card := "" # the boss whose card shows, while boss_card_time lasts
var boss_card_time := 0.0


func boss_entrance(kind: String) -> void:
	show_boss_card(kind)
	if Net.is_host():
		Net.boss_entrance(kind)


## Shows the card and rings the bells on this phone (each phone rings its own: they carry no position).
func show_boss_card(kind: String) -> void:
	boss_card = kind
	boss_card_time = BOSS_CARD_TIME
	banner_time = 0.0
	Sfx.play(str(BOSS_CARDS[kind]["bells"]), 0.0, 1.0, 1.0)


func show_banner(text: String, seconds: float) -> void:
	banner = text
	# Over a boss's card it waits its turn, and then shows for as long as it would have.
	banner_time = seconds + boss_card_time
	if Net.is_host():
		Net.banner(text, seconds)


## The Mists' storms: one gathers a little after the last one ends, and from TWO_FROM on two can
## rage at once, on different islands, the second gathering a while after the first.
func _tick_storms() -> void:
	var raging := world.mist_storms.filter(func(storm: MistStorm) -> bool: return not storm.finale and storm.island >= 0)
	if raging.size() < _storms_last:
		_next_storm = maxf(_next_storm, elapsed + MistStorm.GAP)
	var room := (2 if elapsed >= MistStorm.TWO_FROM else 1) - raging.size()
	if room > 0 and elapsed >= _next_storm:
		var taken := raging.map(func(storm: MistStorm) -> int: return storm.island)
		var free: Array[int] = []
		for n in range(1, 9):
			if n not in taken:
				free.append(n)
		var island: int = 0 if _storm_index == 0 else free.pick_random()
		_storm_index += 1
		if Net.active(): Net.start_mist_storm(island)
		else: MistStorm.create(world, island)
		_next_storm = elapsed + MistStorm.STAGGER
	_storms_last = world.mist_storms.filter(func(storm: MistStorm) -> bool: return not storm.finale and storm.island >= 0).size()


## The ruins' caches: each holds one of the rarer weapons or a potion, and is filled again
## CACHE_REFILL seconds after what it held was taken. Not inside a Mist Storm.
const CACHE_REFILL := 100.0
func _tick_caches() -> void:
	if elapsed < _cache_look:
		return
	_cache_look = elapsed + 2.0
	for i in world.cache_spots.size():
		var at: Vector3 = world.cache_spots[i]
		var held := world.pickups.any(func(p: Pickup) -> bool: return is_instance_valid(p) and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < 2.0)
		if held:
			_cache_due[i] = elapsed + CACHE_REFILL
			continue
		if elapsed < float(_cache_due.get(i, 0.0)) or world.storm_at(at) != null:
			continue
		if world.vael_sites and not world.vael_sites.can_stock(at, false, VaelSites.CACHE_CLEARANCE, true):
			continue
		_cache_due[i] = elapsed + CACHE_REFILL
		if randf() < 0.65:
			var id := WeaponDefs.pick_rare(world.spawn_map())
			world.spawn_pickup_at(at, Pickup.Kind.WEAPON, id, 12 if WeaponDefs.is_ranged(id) else 0)
		else:
			world.spawn_pickup_at(at, Pickup.Kind.POWER, PowerDefs.pick_potion(world.spawn_map()))


## Words for this phone's player alone.
func local_banner(text: String, seconds: float) -> void:
	banner = text
	banner_time = seconds


## How long this match runs. In All vs All the clock counts down to the fog closing, not to dawn.
func match_length() -> float:
	return ClosingFog.TOTAL if Net.fog_rules() else Game.night_length()


func night_left() -> float:
	return maxf(0.0, match_length() - elapsed)


## 0 at night, 1 at dawn.
func dawn_amount() -> float:
	if not running or Net.fog_rules():
		return 0.0
	if world.last_light:
		# No clock on the Lantern Road: the sky pales a little as the Isle of Lamps comes near.
		return 1.0 if world.last_light.lit else clampf(world.last_light.progress / world.last_light.length, 0.0, 1.0) * 0.3
	var dawn := clampf(1.0 - night_left() / DAWN_GLOW, 0.0, 1.0)
	return minf(dawn, 0.45) if requires_regent() and not _mist_boss_defeated else dawn


## The night starts calm and fills up to the phone's zombie limit.
func target_population() -> int:
	var cap := Game.max_live_zombies()
	var mists := world.terrain.has_islands() and not Net.fog_rules()
	if mists: cap += 4
	var bastion := world.map_id == "bastion"
	if bastion:
		# Three lanes to fill: Mist Bastion is fought against far bigger numbers.
		cap = int(round(cap * BASTION_CROWD))
	var start := mini(12 if mists or bastion else 6, cap)
	# A slow start while the player finds a weapon, then the crowd builds.
	var t := pow(clampf(elapsed / (match_length() * 0.75), 0.0, 1.0), 1.3)
	var crowd := lerpf(start, cap, t) * (1.0 + 0.35 * (world.players.size() - 1))
	if elapsed >= match_length() - 120.0:
		crowd *= 1.3
	if Net.fog_rules():
		crowd *= 0.6 # enough to keep you busy, but the others are the danger here
	return int(round(crowd))


func stock(kind: int) -> void:
	match kind:
		Pickup.Kind.WEAPON: world.spawn_pickup_random(kind, WeaponDefs.pick_random(world.spawn_map()))
		Pickup.Kind.FOOD: world.spawn_pickup_random(kind, PowerDefs.pick_weighted(PowerDefs.FOODS))
		Pickup.Kind.ARROWS: world.spawn_pickup_random(kind, "arrows")
		Pickup.Kind.POWER: world.spawn_pickup_random(kind, PowerDefs.pick_potion(world.spawn_map()))


func _process(delta: float) -> void:
	banner_time = maxf(0.0, banner_time - delta)
	boss_card_time = maxf(0.0, boss_card_time - delta)
	if sandbox:
		world.tick_stands(delta)
		return
	if _follows_host:
		if running:
			elapsed += delta
		return
	if _waiting or _won or _everyone_down():
		return
	# The church bell tolls the minutes, and there is a church only in The Village.
	_bell_timer -= delta
	if _bell_timer <= 0.0 and world.map_id == "village":
		_bell_timer = 60.0
		_bell_minute += 1
		world.ring_bell(_bell_minute)
		if Net.is_host():
			Net.bell(_bell_minute)
	_stock_timer -= delta
	if _stock_timer <= 0.0:
		_stock_timer = 6.0 if world.terrain.has_islands() else 8.0
		_restock()
	_wood_timer -= delta
	if _wood_timer <= 0.0:
		_wood_timer = WOOD_EVERY
		if world.fort and world.count_pickups(Pickup.Kind.WOOD) < world.wood_target():
			world.stock_wood()
	_familiar_timer -= delta
	if _familiar_timer <= 0.0:
		_familiar_timer = FAMILIAR_EVERY
		_spawn_familiar()
	if not running:
		return
	elapsed += delta
	if world.terrain.has_islands() and not Net.fog_rules() and not _mist_boss_spawned:
		_tick_storms()
	if not _follows_host and not sandbox and not world.cache_spots.is_empty():
		_tick_caches()
	if not _follows_host and not sandbox:
		if camp == null and CampSiege.wanted(world):
			camp = CampSiege.new(world)
		if camp:
			camp.tick(elapsed)
	_tick_specials()
	_tick_last_stand(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.25 if _last_stand else 2.5
		var living := world.count_living()
		if living < target_population():
			_spawn_roamer()
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
	var dawned := world.last_light.lit if world.last_light else elapsed >= match_length() and not Net.fog_rules() and (not requires_regent() or (_mist_boss_defeated and (world.map_id != "vael" or _kraken_fallen)))
	if dawned:
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
	if world.terrain.has_islands(): return # Keep the island garrisons rather than recycling them around the centre.
	for z: Zombie in world.zombies.duplicate():
		if not z.is_alive() or z.flies or z.dormant or z.hero or z.is_boss() or z.is_hunting():
			continue
		var near := INF
		for p in world.players:
			near = minf(near, z.position.distance_to(p.global_position))
		if near > FAR_AWAY:
			z.release()


## A familiar always appears within reach. The sound says one is out there; finding it is up to you.
func _spawn_familiar() -> void:
	var who: Target = world.players[randi() % world.players.size()] if not world.players.is_empty() else null
	var p := world.spawn_pickup_near_player(Pickup.Kind.POWER, PowerDefs.pick_familiar(world.spawn_map()), 10.0, 26.0, who)
	if p and who:
		if who is Avatar:
			Net.familiar_near((who as Avatar).peer)
		else:
			Sfx.play("familiar", -4.0)


## The last two minutes: the sky starts to change, and everything still standing wants you dead.
func _tick_last_stand(delta: float) -> void:
	if Net.fog_rules() or world.last_light:
		return # (no dawn to sense on the Lantern Road, only the lighthouse)
	if not _last_stand:
		if elapsed >= match_length() - 120.0:
			_last_stand = true
			_call_timer = 2.0
			show_banner("They sense the dawn...", 4.0)
			_sound(DAWN_SOUNDS.get(world.map_id, "howl"), -1.0, 0.8 if not DAWN_SOUNDS.has(world.map_id) else 1.0)
		return
	_call_timer -= delta
	if _call_timer <= 0.0 and world.player:
		_call_timer = LAST_STAND_CALL
		world.call_all_to_players()


func minute() -> int:
	return int(elapsed / 60.0)


func _pick_roamer() -> String:
	var kind := ZombieDefs.pick_roamer(elapsed, world.spawn_map())
	# Coastal flyers share three ranged slots, leaving room for the drowned on phones.
	if kind in VaelSkyMind.KINDS:
		var flyers := 0
		for id: String in VaelSkyMind.KINDS: flyers += world.count_type(id)
		if flyers >= 3: return "drowned_sailor"
	# Leave two pooled bodies available for the Regent's second phase.
	return "rift_stalker" if kind == "lantern_wisp" and world.count_type(kind) >= 3 else kind


func _tick_mist_boss() -> void:
	if not _follows_host and not sandbox and world.map_id in SpawnRules.MESENLLA and not Net.fog_rules() and not _mist_boss_spawned and elapsed >= _mist_boss_at:
		_raise_mesenlla_boss()
		return
	if not _follows_host and not sandbox and world.map_id == "vael" and not Net.fog_rules() and not _mist_boss_spawned and elapsed >= _mist_boss_at:
		_raise_sovereign()
		return
	if not _follows_host and not sandbox and world.terrain.has_islands() and not Net.fog_rules() and not _mist_boss_spawned and elapsed >= _mist_boss_at:
		var throne := world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(Vector3.ZERO)))
		throne.y = world.ground_at(throne)
		if world.spawn_zombie("veil_regent", throne):
			_mist_boss_spawned = true
			CommandField.visual_impact(world, throne, 12.0, true)
			if Net.is_host(): Net.command_impact_visual(throne, 12.0, true)
			if Net.active(): Net.start_mist_storm(-1)
			else: MistStorm.create(world, 0, true)
			_sound("mist_regent", 0.0)


## The Great Revenant Elemental rises from the Ring of Stones, the boulders of the meadow drawing together.
## Over Mist Bastion the War Wyvern comes up from the valley instead, for the Great Portal.
func _raise_mesenlla_boss() -> void:
	var at := Vector3.ZERO
	for mark: Dictionary in world.map_marks:
		if mark["name"] == "boss":
			at = Vector3(mark["at"].x, 0, mark["at"].y)
	var spot := world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(at)))
	spot.y = world.ground_at(spot)
	if world.map_id == "bastion":
		if world.spawn_zombie(BASTION_BOSS, spot):
			_mist_boss_spawned = true
			_sound("wyvern_roar", 4.0)
		return
	if world.spawn_zombie(MESENLLA_BOSS, spot):
		_mist_boss_spawned = true
		CommandField.visual_impact(world, spot, 10.0, true)
		if Net.is_host(): Net.command_impact_visual(spot, 10.0, true)
		_sound("revenant_roar", 2.0)


## The Hollow Sovereign rises out of the middle of the flats, the tide pouring off him.
func _raise_sovereign() -> void:
	var spot := world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(SOVEREIGN_FROM)))
	spot.y = world.ground_at(spot)
	if world.spawn_zombie(VAEL_BOSS, spot):
		_mist_boss_spawned = true
		world.fx_water(spot, 3.0, Color(0.72, 0.9, 0.92), true)
		CommandField.visual_impact(world, spot, 10.0, true)
		if Net.is_host(): Net.command_impact_visual(spot, 10.0, true)
		_sound("sovereign_voice", 4.0)


## A boss has fallen: the Veil Regent, the Great Revenant Elemental, the War Wyvern or the Hollow
## Sovereign. Dawn can come now.
func boss_fallen(_z: Zombie) -> void:
	if _z.type_id == KRAKEN:
		_kraken_fallen = true
		show_banner("The Kraken sinks. The deep is still, and Vael is free.", 6.0)
	elif _z.type_id != "leviathan":
		_mist_boss_defeated = true


## What only happens beyond the Mists.
func _tick_mesenlla() -> void:
	if elapsed >= _next_crows:
		_next_crows = elapsed + CROWS_EVERY
		# A pair of eagles, and a Mist Eagle with them once the night is old.
		for i in 2:
			world.spawn_zombie("eagle")
		if elapsed >= ZombieDefs.ALL["mist_eagle"]["from"]:
			world.spawn_zombie("mist_eagle")
		world.sfx_at("eagle_cry", world.player.global_position + Vector3(18, 6, 0), -2.0)
	if elapsed >= _next_rider and elapsed >= ZombieDefs.ALL["woodland_cavalry"]["from"]:
		_next_rider = elapsed + RIDER_EVERY
		if world.count_type("woodland_cavalry") < MAX_RIDERS + (1 if _last_stand else 0) and world.spawn_zombie("woodland_cavalry"):
			_sound("bear_roar", 0.0)
			show_banner("Riders of the woods...", 3.0)
	if elapsed >= _next_wyvern:
		_next_wyvern = elapsed + WYVERN_EVERY
		if world.count_type("wyvern") < MAX_WYVERNS + (1 if _last_stand else 0) and world.spawn_zombie("wyvern"):
			_sound("wyvern_roar", 2.0)
			show_banner("A wyvern over the valley!", 3.0)


## Port Vael: Brine Hounds come up out of the sea in packs; the high tide carries Lantern Jellies in
## over the flats; and Anglers lie buried on the shore with their lures showing.
## Fontanova: its hives grow at the start of the night, and from SPIDERS_FROM its spiders wait in the
## trees, a new one every SPIDER_EVERY seconds while fewer than MAX_SPIDERS are about.
const SPIDERS_FROM := 200.0
const SPIDER_EVERY := 50.0
const MAX_SPIDERS := 3
var _hives_grown := false
var _next_spider := SPIDERS_FROM
func _tick_fontanova() -> void:
	if _follows_host:
		return
	if not _hives_grown:
		_hives_grown = true
		world.grow_hives()
	if elapsed >= _next_spider:
		_next_spider = elapsed + SPIDER_EVERY
		if world.count_type("mutant_spider") < MAX_SPIDERS:
			world.spawn_spider()


func _tick_vael() -> void:
	if elapsed >= _next_rider and elapsed >= ZombieDefs.ALL["brine_hound"]["from"]:
		_next_rider = elapsed + HOUND_PACK_EVERY
		if world.count_type("brine_hound") <= MAX_HOUNDS - int(ZombieDefs.ALL["brine_hound"]["pack"]):
			var pack := int(ZombieDefs.ALL["brine_hound"]["pack"])
			var came := world.vael_sites.spawn_pack("brine_hound", pack, VaelSites.Shore.WATERLINE) if world.vael_sites else _lantern_pack("brine_hound", pack, 26.0, 40.0)
			if came > 0:
				_sound("hound_snarl", 0.0)
				show_banner("Hounds out of the sea...", 3.0)
	if elapsed >= _next_wyvern and world.tide and world.tide.high() and elapsed >= ZombieDefs.ALL["lantern_jelly"]["from"]:
		_next_wyvern = elapsed + JELLIES_EVERY
		for i in JELLIES_AT_ONCE:
			if world.count_type("lantern_jelly") >= MAX_JELLIES:
				break
			world.spawn_on_tide("lantern_jelly")
	if elapsed >= _next_ambush and elapsed >= ZombieDefs.ALL["angler"]["from"]:
		_next_ambush = elapsed + AMBUSH_EVERY
		if world.count_type("angler") < MAX_ANGLERS:
			world.spawn_angler()
	_tick_court()
	if world.map_id == "vael" and not Net.fog_rules() and elapsed >= 690.0 and not _coastal_leviathan:
		var at := world.vael_sites.enemy_site(20.0, 65.0, VaelSites.Shore.WATERLINE)
		if at == Vector3.INF: at = world.vael_sites.enemy_site(15.0, 190.0, VaelSites.Shore.WATERLINE)
		if at != Vector3.INF and world.spawn_zombie("leviathan", at):
			_coastal_leviathan = true
			show_banner("The Leviathan rises from the drowned harbour", 5.0)
	_tick_kraken()


## The end of Port Vael's night: the Kraken, once both its royals have fallen.
func _tick_kraken() -> void:
	if world.map_id != "vael" or Net.fog_rules() or _follows_host or _kraken_risen:
		return
	if _kraken_at < 0.0:
		if _mist_boss_defeated and _coastal_leviathan and world.count_type("leviathan") == 0:
			_kraken_at = elapsed + KRAKEN_AFTER
			show_banner("The harbour goes still. Something vast is moving under it...", 5.0)
			_sound("kraken_whirlpool", 2.0)
		return
	if elapsed >= _kraken_at:
		_raise_kraken()


func _raise_kraken() -> void:
	var spot := world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(KRAKEN_FROM)))
	spot.y = world.ground_at(spot)
	if not world.spawn_zombie(KRAKEN, spot):
		_kraken_at = elapsed + 2.0 # nowhere to rise just now: a moment later
		return
	_kraken_risen = true
	if world.tide:
		world.tide.surge(KRAKEN_HOLDS_TIDE)
	world.fx_water(spot + Vector3.UP, 8.0, Color(0.72, 0.9, 0.92), true)
	world.fx_ring(spot, 14.0, Color(0.55, 0.95, 0.9))



## The drowned court of Port Vael (see SIREN_EVERY and what follows it).
func _tick_court() -> void:
	if elapsed >= _next_siren and elapsed >= ZombieDefs.ALL["siren"]["from"]:
		_next_siren = elapsed + SIREN_EVERY
		if world.count_type("siren") < MAX_SIRENS and world.spawn_siren():
			_sound("siren_hum", 0.0)
	if elapsed >= _next_press and elapsed >= ZombieDefs.ALL["press_gang"]["from"]:
		_next_press = elapsed + PRESS_EVERY
		var gang := int(ZombieDefs.ALL["press_gang"]["pack"])
		if world.count_type("press_gang") <= MAX_PRESS - gang:
			var came := world.vael_sites.spawn_pack("press_gang", gang, VaelSites.Shore.DRY) if world.vael_sites else _lantern_pack("press_gang", gang, 24.0, 38.0)
			if came > 0:
				_sound("press_shout", 2.0)
				show_banner("A Press Gang is looking for hands...", 3.0)
	if world.map_id != "vael":
		return # on the Lantern Road the court waits at the waystations instead (LastLight)
	if Net.fog_rules():
		# All vs All: no court, but the Sunken Crown washes up for whoever can take it and keep it.
		if not _crown_washed and elapsed >= CROWN_AT and world.map_id == "vael":
			_crown_washed = true
			world.spawn_pickup_at(CROWN_SPOT, Pickup.Kind.POWER, PowerDefs.CROWN)
			world.fx_water(CROWN_SPOT, 2.0, Color(0.95, 0.82, 0.4), true)
			show_banner("The Sunken Crown has washed up at the Drowned Bell", 4.0)
			_sound("crown_toll", 4.0)
		return
	if not _court_came.has("harbourmaster") and elapsed >= HARBOURMASTER_AT:
		var stairs: Vector3 = QUAY_STAIRS[0] if world.random_player_position().x < 0.0 else QUAY_STAIRS[1]
		if _summon("harbourmaster", stairs, "harbour_bell"):
			show_banner("The Harbourmaster climbs the quay stairs: \u201c%s\u201d" % ZombieDefs.ALL["harbourmaster"]["first_words"], 4.5)
	if not _court_came.has("kraken_arm") and elapsed >= KRAKEN_AT and world.tide and world.tide.high() and world.tide.level > MistTide.HIGH_Y - 0.3:
		_court_came["kraken_arm"] = true
		if world.raise_kraken() > 0:
			show_banner("The Kraken wakes. Its arms close around the harbour.", 4.0)
	if not _court_came.has("lighthouse_keeper") and elapsed >= KEEPER_AT:
		if _summon("lighthouse_keeper", KEEPER_FROM, "keeper_laugh"):
			show_banner("The Mad Lighthouse Keeper comes down the East Mole: \u201c%s\u201d" % ZombieDefs.ALL["lighthouse_keeper"]["first_words"], 4.5)


## The Lantern Road shares these encounters. Check each pack member in its own cell there as well.
func _lantern_pack(id: String, count: int, near: float, far: float) -> int:
	var at := world.spawn_point_near(world.random_player_position(), near, far)
	if at == Vector3.INF:
		return 0
	var came := 1 if world.spawn_zombie(id, at) else 0
	for i in count - 1:
		var next := world.spawn_point_near(at, 1.6, 3.0)
		if next != Vector3.INF and world.spawn_zombie(id, next):
			came += 1
	return came


## One of the court, come at its hour where it comes from; once, whether or not it could.
func _summon(id: String, near: Vector3, sound: String) -> bool:
	_court_came[id] = true
	var spot := world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(near)))
	spot.y = world.ground_at(spot)
	if not world.spawn_zombie(id, spot):
		return false
	_sound(sound, 4.0)
	return true


func _tick_specials() -> void:
	_tick_mist_boss()
	if world.garrison:
		world.garrison.tick(elapsed)
	if world.map_id in SpawnRules.MESENLLA:
		_tick_mesenlla()
		return
	if world.map_id in SpawnRules.VAEL:
		_tick_vael()
		return
	if world.map_id in SpawnRules.ARCHIPELAGO:
		_tick_fontanova()
		return
	if elapsed >= _next_rider and SpawnRules.allows(ZombieDefs.ALL["rider"], world.spawn_map()):
		_next_rider = elapsed + RIDER_EVERY
		if world.count_type("rider") < MAX_RIDERS + (1 if _last_stand else 0) and world.spawn_zombie("rider"):
			_sound("gallop", 2.0)
			show_banner("Hooves in the dark...", 3.0)
	if elapsed >= _next_crows and SpawnRules.allows(ZombieDefs.ALL["crow"], world.spawn_map()):
		_next_crows = elapsed + CROWS_EVERY
		for i in 3:
			world.spawn_zombie("crow")
		world.sfx_at("crow", world.player.global_position + Vector3(20, 0, 0), -4.0)
	if elapsed >= _next_gargoyle:
		_next_gargoyle = elapsed + GARGOYLE_EVERY
		world.spawn_gargoyle()
	if elapsed >= _next_harrier:
		_next_harrier = elapsed + HARRIER_EVERY
		if world.terrain.has_islands() and world.count_type("mist_harrier") < MAX_HARRIERS:
			world.spawn_zombie("mist_harrier")
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
	if world.count_pickups(Pickup.Kind.WEAPON) < (10 if world.terrain.has_islands() else 7):
		stock(Pickup.Kind.WEAPON)
	if world.count_pickups(Pickup.Kind.FOOD) < (10 if world.terrain.has_islands() else 6):
		stock(Pickup.Kind.FOOD)
	if world.count_pickups(Pickup.Kind.ARROWS) < (8 if world.terrain.has_islands() else 4):
		stock(Pickup.Kind.ARROWS)
	var potions := 0
	for p in world.pickups:
		if p.kind == Pickup.Kind.POWER and not PowerDefs.ALL[p.item_id]["familiar"]:
			potions += 1
	if potions < (5 if world.terrain.has_islands() else 3):
		stock(Pickup.Kind.POWER)


func _spawn_roamer() -> void:
	if not world.terrain.has_islands():
		world.spawn_zombie(_pick_roamer())
		return
	# Keep pressure near explorers and replenish the least populated outer island.
	if world.storm_finale() or (world.count_living() >= 8 and randf() < 0.5):
		world.spawn_zombie(_pick_roamer())
		return
	var counts := PackedInt32Array()
	counts.resize(9)
	for mob: Zombie in world.zombies:
		if mob.is_alive():
			var index := world.portals.island_of(mob.position)
			if index >= 0 and index < 9: counts[index] += 1
	var chosen := randi_range(1, 8)
	for index in range(1, 9):
		if counts[index] < counts[chosen]: chosen = index
	var land := MapIslands.ISLANDS[chosen]
	for attempt in 16:
		var angle := randf() * TAU
		var radius := randf_range(0.25, 0.7) * land.z
		var at := Vector3(land.x + cos(angle) * radius, land.w, land.y + sin(angle) * radius)
		if world.grid.is_free(world.grid.to_cell(at)) and world.terrain.is_walkable(at.x, at.z) and not world.terrain.in_pool(at.x, at.z):
			world.spawn_zombie(_pick_roamer(), at)
			return


## The Mists end only when the Veil Regent falls, and Mesenlla only when the Great Revenant Elemental does.
func requires_regent() -> bool:
	return (world.terrain.has_islands() or world.map_id in SpawnRules.MESENLLA or world.map_id == "vael") and not sandbox and not Net.fog_rules()
