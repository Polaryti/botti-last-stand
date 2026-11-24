class_name WeaponDefs
## Each hit does DAMAGE times the weapon's power. Range, cadence, shape and a special rule set them apart.

enum Kind { MELEE, RANGED, SPELL }

const DAMAGE := 25.0
const ALIGNED_HELD := ["lance", "scythe", "flail", "bell_hammer", "bow", "longbow", "crossbow", "greatsword", "oar", "anchor"]
const HAND_TURN := PI * 0.5
const TORCH_FIRE := 0.575 # how high up a torch the fire starts

const ALL := {
	"dagger": {"power": 0.65, "name": "Dagger", "backstab": true, "desc": "Very fast, with short reach. Does double damage from behind.", "kind": Kind.MELEE, "rate": 0.26, "range": 1.9, "cone": 70.0, "max_hits": 1,
		"knock": 1.0, "swing": "stab", "weight": 1.2, "pos": Vector3(0.24, -0.26, -0.42), "scale": 0.3},
	"sword": {"name": "Sword", "desc": "A good all-round blade that cuts up to three at once.", "kind": Kind.MELEE, "rate": 0.55, "range": 2.8, "cone": 95.0, "max_hits": 3,
		"knock": 2.5, "swing": "slash", "weight": 1.6, "pos": Vector3(0.26, -0.3, -0.46), "scale": 0.3},
	"spear": {"power": 1.25, "name": "Spear", "desc": "Long reach in a narrow line, and hits hard.", "kind": Kind.MELEE, "rate": 0.6, "range": 4.4, "cone": 24.0, "max_hits": 1,
		"knock": 2.0, "swing": "thrust", "weight": 1.6, "pos": Vector3(0.22, -0.24, 0.05), "scale": 1.0},
	"mace": {"power": 1.05, "name": "Mace", "desc": "Short but very broad. Sends enemies flying.", "kind": Kind.MELEE, "rate": 0.6, "range": 2.2, "cone": 170.0, "max_hits": 6,
		"knock": 4.0, "swing": "smash", "weight": 1.6, "pos": Vector3(0.28, -0.3, -0.46), "scale": 0.72},
	"lance": {"only": "chivalry", "power": 1.5, "name": "Lance", "charge": true, "desc": "Chivalry only. Cannot be dropped or found as loot. The longest reach, through up to two enemies. Half as strong again while you run or ride.", "kind": Kind.MELEE, "rate": 0.75, "range": 5.2, "cone": 16.0, "max_hits": 2,
		"knock": 3.0, "swing": "thrust", "weight": 0.7, "pos": Vector3(0.24, -0.22, 0.35), "scale": 1.0},
	"scythe": {"maps": ["village", "fort"], "two_handed": true, "power": 0.8, "name": "Scythe", "bleed": true, "desc": "Slow, and sweeps a huge arc through a whole crowd. Leaves them bleeding.", "kind": Kind.MELEE, "rate": 0.95, "range": 3.3, "cone": 210.0, "max_hits": 8,
		"knock": 2.0, "swing": "reap", "arc": 1.2, "weight": 1.2, "pos": Vector3(0.4, -0.4, -0.65), "scale": 0.72},
	"flail": {"power": 0.95, "name": "Flail", "desc": "Gets faster the longer you keep swinging.", "kind": Kind.MELEE, "rate": 0.85, "range": 2.5, "cone": 100.0, "max_hits": 3,
		"knock": 2.0, "swing": "flail", "momentum": true, "weight": 1.2, "pos": Vector3(0.28, -0.1, -0.7), "scale": 0.72},
	"bell_hammer": {"maps": ["mists"], "two_handed": true, "power": 1.3, "name": "Bell Hammer", "desc": "Stuns all it hits, and everyone can hear it.", "kind": Kind.MELEE, "rate": 1.05, "range": 2.5, "cone": 130.0, "max_hits": 6,
		"knock": 4.0, "swing": "overhead", "stun": 1.3, "loud": 22.0, "weight": 1.0, "pos": Vector3(0.22, -0.4, -0.5), "scale": 0.5},
	"pitchfork": {"maps": ["village", "fort"], "two_handed": true, "power": 0.8, "name": "Pitchfork", "desc": "Stabs straight through up to three in a row.", "kind": Kind.MELEE, "rate": 0.65, "range": 3.8, "cone": 16.0, "max_hits": 3,
		"knock": 1.5, "swing": "thrust", "weight": 1.3, "pos": Vector3(0.22, -0.24, 0.0), "scale": 1.0},
	"torch": {"maps": ["village", "fort"], "power": 0.55, "name": "Torch", "desc": "Sets enemies on fire and lights your way.", "kind": Kind.MELEE, "rate": 0.5, "range": 2.0, "cone": 80.0, "max_hits": 2,
		"knock": 1.0, "swing": "slash", "burns": true, "weight": 1.2, "pos": Vector3(0.26, -0.3, -0.46), "scale": 0.72},
	"bow": {"nock": Vector3(-0.01, 0.0, -0.02), "name": "Short Bow", "desc": "Medium range and steady.", "kind": Kind.RANGED, "rate": 0.65, "range": 36.0, "speed": 38.0, "gravity": 3.5,
		"knock": 1.5, "weight": 1.6, "pos": Vector3(0.17, -0.1, -0.45), "scale": 0.5, "tilt": -0.42},
	"crossbow": {"power": 0.6, "nock": Vector3(0.0, 0.03, -0.16), "name": "Crossbow", "desc": "Short range and very fast, but each bolt is light.", "kind": Kind.RANGED, "rate": 0.3, "range": 16.0, "speed": 30.0, "gravity": 3.5,
		"knock": 1.0, "weight": 1.3, "pos": Vector3(0.17, -0.2, -0.3), "scale": 0.2},
	"longbow": {"power": 3.2, "nock": Vector3(-0.01, 0.0, -0.02), "name": "Long Bow", "pierce": 2, "desc": "Slow, but one arrow kills a zombie and goes on through two more. Reaches across the map. Zoom in to aim.", "kind": Kind.RANGED, "rate": 1.25, "range": 75.0, "speed": 64.0, "gravity": 1.5,
		"knock": 2.5, "zoom_fov": 38.0, "weight": 1.0, "pos": Vector3(0.17, -0.1, -0.5), "scale": 0.7, "tilt": -0.42},
	"axes": {"maps": ["village", "fort"], "power": 0.9, "name": "Throwing Axes", "desc": "They come back to you, cutting on the way out and back. No arrows needed.", "kind": Kind.RANGED, "rate": 0.5, "range": 15.0, "speed": 24.0, "gravity": 0.0,
		"knock": 2.0, "returning": true, "weight": 1.1, "pos": Vector3(0.24, -0.26, -0.46), "scale": 0.5},
	"javelins": {"power": 2.2, "pierce": 1, "shot": "javelin", "name": "Javelins", "desc": "Heavy, with a falling arc. Passes through the first enemy. Uses arrows.", "kind": Kind.RANGED, "rate": 1.0, "range": 30.0, "speed": 27.0, "gravity": 8.0,
		"knock": 3.5, "weight": 1.0, "pos": Vector3(0.22, -0.22, -0.1), "scale": 1.0},
	"blowgun": {"only": "plague_doctor", "power": 0.65, "silent": true, "poison": Vector2(12.0, 5.0), "name": "Blowgun", "desc": "Silent darts that poison what they hit: damage over time, and it takes 5% more from everything. Uses arrows.", "kind": Kind.RANGED, "rate": 0.65, "range": 22.0, "speed": 40.0, "gravity": 2.0,
		"knock": 0.0, "weight": 0.9, "pos": Vector3(0.14, -0.16, -0.25), "scale": 1.0},
	"fists": {"only": "monk", "power": 0.7, "name": "", "desc": "", "kind": Kind.MELEE, "rate": 0.34, "range": 2.4, "cone": 100.0, "max_hits": 2,
		"knock": 1.4, "swing": "punch", "hidden": true, "weight": 0.0, "pos": Vector3(0.34, -0.36, -0.68), "scale": 0.58},
	"bo": {"power": 0.95, "name": "Bo Staff", "desc": "A Monk's long staff, which sweeps wide and keeps them away.", "hidden": true, "kind": Kind.MELEE, "rate": 0.48, "range": 3.2, "cone": 130.0, "max_hits": 3,
		"knock": 2.8, "swing": "bo", "weight": 0.0, "only": "monk", "pos": Vector3(0.08, -0.3, -0.62), "scale": 0.8},
	"claws": {"only": "revenant", "name": "Spectral Claws", "desc": "A Revenant's own hands, shrouded in mist. Each blow uses a little Mist.", "kind": Kind.MELEE, "rate": 0.42, "range": 2.5, "cone": 100.0, "max_hits": 2,
		"knock": 1.2, "swing": "claw", "cost": 5.0, "hidden": true, "weight": 0.0, "pos": Vector3(0.27, -0.33, -0.5), "scale": 0.52},
	"staff": {"only": "magician", "name": "Staff", "desc": "Bolts of magic that use refilling mana.", "kind": Kind.SPELL, "rate": 0.45, "range": 30.0, "speed": 30.0, "gravity": 0.0, "cost": 10.0,
		"knock": 1.5, "weight": 0.0, "pos": Vector3(0.26, -0.38, -0.5), "scale": 0.6},
	# Two-Handed: only classes trained for them (ClassDefs "two_handed") can wield these.
	"greatsword": {"two_handed": true, "power": 1.45, "name": "Greatsword", "desc": "A long blade swung with both hands. Wide, heavy sweeps cut through up to five.", "kind": Kind.MELEE, "rate": 0.8, "range": 3.2, "cone": 150.0, "max_hits": 5,
		"knock": 2.5, "swing": "slash", "weight": 0.9, "pos": Vector3(0.3, -0.36, -0.55), "scale": 0.62},
	"battleaxe": {"maps": ["mesenlla", "bastion"], "two_handed": true, "power": 1.5, "name": "Battleaxe", "cleave": 3, "desc": "A bearded axe from the mountain outposts. Every third blow in a row is a cleaving chop: double damage, and it throws them back.", "kind": Kind.MELEE, "rate": 0.95, "range": 2.8, "cone": 120.0, "max_hits": 4,
		"knock": 2.5, "swing": "overhead", "weight": 1.0, "pos": Vector3(0.24, -0.4, -0.5), "scale": 0.55},
	"chakram": {"maps": ["mesenlla", "bastion"], "power": 1.0, "name": "Rift Chakram", "shot": "chakram", "bounces": 3, "own_ammo": 20, "own_ammo_max": 40, "desc": "A ring of mist-glass that the valley scouts throw. Ricochets on to three more enemies. Needs no arrows: each Rift Chakram picked up gives 20 throws, up to 40. When the last is thrown it is gone, and its slot is empty.", "kind": Kind.RANGED, "rate": 0.6, "range": 28.0, "speed": 30.0, "gravity": 0.0,
		"knock": 1.0, "weight": 0.9, "pos": Vector3(0.24, -0.26, -0.46), "scale": 0.5},
	# Pathfinder finds: unearthed by a Pathfinder's beacons, and only a Pathfinder can use them.
	"machete": {"only": "cartographer", "spec": "pathfinder", "power": 0.95, "name": "Pathfinder's Machete", "bleed": true, "desc": "Pathfinder only, unearthed by its beacons. Quick, wide chops that clear a path and leave enemies bleeding.", "kind": Kind.MELEE, "rate": 0.42, "range": 2.7, "cone": 115.0, "max_hits": 3,
		"knock": 1.8, "swing": "slash", "weight": 0.0, "pos": Vector3(0.26, -0.3, -0.46), "scale": 0.46},
	"bolas": {"only": "cartographer", "spec": "pathfinder", "power": 0.9, "name": "Pathfinder's Bolas", "shot": "bolas", "slows": 2.5, "free_ammo": true, "desc": "Pathfinder only, unearthed by its beacons. Weighted cords that tangle the legs: everything they hit is slowed for 2.5 s. No arrows needed.", "kind": Kind.RANGED, "rate": 0.7, "range": 24.0, "speed": 26.0, "gravity": 3.0,
		"knock": 1.2, "weight": 0.0, "pos": Vector3(0.24, -0.26, -0.46), "scale": 0.5},
	# The Sunken Crown: found on the coast of Vael (Port Vael and the Lantern Road).
	"cutlass": {"maps": ["vael", "lantern_road"], "swing_sound": "cutlass_swing", "power": 0.9, "name": "Cutlass", "fervour": 3, "fervour_rate": 0.15, "fervour_time": 3.0, "desc": "A sailor's curved blade, quick, cutting up to two. Each kill quickens your swings by 15%, up to 3 times; it fades 3 s after your last kill.", "lore": "Every deckhand of Vael carried one. The salt never quite came off the blades, and neither did the habit of fighting in a hurry.", "kind": Kind.MELEE, "rate": 0.5, "range": 2.6, "cone": 105.0, "max_hits": 2,
		"knock": 1.8, "swing": "slash", "weight": 1.2, "pos": Vector3(0.26, -0.3, -0.46), "scale": 0.5},
	"boarding_hook": {"maps": ["vael", "lantern_road"], "swing_sound": "hook_swing", "power": 0.8, "name": "Boarding Hook", "drags": 1.6, "drag_stagger": 0.4, "desc": "An iron hook on a short haft, for pulling ships together. Catches one enemy and drags it 1.6 m towards you, off balance for 0.4 s. Large lesser creatures are staggered. Bosses resist its control effects.", "lore": "Thrown over the rail of a rival ship, a hook like this ended most arguments on the Sound of Vael before a blade was drawn.", "kind": Kind.MELEE, "rate": 0.65, "range": 3.1, "cone": 40.0, "max_hits": 1,
		"knock": 0.0, "swing": "hook", "weight": 1.0, "pos": Vector3(0.24, -0.3, -0.46), "scale": 0.55},
	"harpoon": {"maps": ["vael", "lantern_road"], "power": 2.6, "name": "Whaler's Harpoon", "shot": "harpoon", "pins": 2.0, "tethered": 15.0, "desc": "A barbed whaling iron on a rope. Pins what it strikes to the spot for 2 s (half as long for bosses). There is only one: it lies where it lands until you walk over it, or comes back to your hand by itself after 15 s.", "lore": "The whalers of Vael hunted things under the mist long before the mist came ashore. Their irons were made to hold whatever they struck.", "kind": Kind.RANGED, "rate": 1.1, "range": 26.0, "speed": 30.0, "gravity": 5.0,
		"knock": 2.5, "weight": 0.9, "pos": Vector3(0.22, -0.22, -0.1), "scale": 1.0},
	"flare_pistol": {"maps": ["vael", "lantern_road"], "power": 0.8, "name": "Flare Pistol", "shot": "flare", "gun": true, "flare": true, "own_ammo": 6, "own_ammo_max": 12, "desc": "A brass signal pistol. Its flare sets alight what it hits and everything within 3 m of where it lands, then burns there for 8 s, showing every enemy within 7 m, hidden ones and invisible rivals too. Each Flare Pistol picked up gives 6 flares, up to 12; when the last is fired it is gone.", "lore": "Harbour pilots fired these to guide ships in through the fog. Fired into the mist now, they show what has come ashore.", "kind": Kind.RANGED, "rate": 1.2, "range": 34.0, "speed": 32.0, "gravity": 7.0,
		"knock": 1.0, "weight": 0.8, "pos": Vector3(0.15, -0.16, -0.27), "scale": 0.85},
	"anchor": {"maps": ["vael", "lantern_road"], "swing_sound": "anchor_heave", "two_handed": true, "power": 2.3, "name": "Ship's Anchor", "quake": 4.5, "quake_share": 0.5, "quake_stagger": 0.6, "burden": 0.9, "desc": "A ship's anchor on a short chain, swung with both hands. Very slow, but each slam shakes the ground: everything within 4.5 m takes half the blow and staggers for 0.6 s. You move at 90% speed while you carry it.", "lore": "Torn from a wreck in the harbour mud. Whoever first swung it at the Drowned found that they, too, remember what an anchor means.", "kind": Kind.MELEE, "rate": 1.5, "range": 2.7, "cone": 120.0, "max_hits": 6,
		"knock": 3.0, "swing": "slam", "weight": 0.8, "pos": Vector3(0.26, -0.44, -0.52), "scale": 0.5},
	"trident": {"only": "tidecaller", "power": 1.2, "name": "Tidecaller's Trident", "tide": 6.0, "desc": "Tidecaller only. Long thrusts that strike up to two in a line; each blow that lands draws 6 tide. The Tidecaller's tree makes it reach further, skewer and soak.",
		"lore": "Coral has grown over the haft where the sea held it. The tines still taste of salt.", "kind": Kind.MELEE, "rate": 0.55, "range": 3.9, "cone": 22.0, "max_hits": 2,
		"knock": 2.0, "swing": "thrust", "weight": 0.0, "pos": Vector3(0.22, -0.24, 0.05), "scale": 1.0},
	"oar": {"maps": ["vael", "lantern_road"], "swing_sound": "oar_sweep", "two_handed": true, "power": 1.05, "name": "Ferryman's Oar", "slows": 1.0, "desc": "A long black oar from the ferries of Vael. Wide sweeps through up to eight that shove everything hit far back and slow it for 1 s.", "lore": "The ferrymen rowed the dead across the Sound to the Isle of Lamps. Their oars were blessed to keep the drowned from climbing aboard.", "kind": Kind.MELEE, "rate": 0.85, "range": 3.5, "cone": 200.0, "max_hits": 8,
		"knock": 5.5, "swing": "row", "arc": 1.15, "weight": 1.0, "pos": Vector3(0.44, -0.5, -0.72), "scale": 0.6},
	"war_staff": {"only": "commander", "hidden": true, "name": "War Staff", "desc": "Melee staff; every fifth attack fires battle magic.", "kind": Kind.MELEE, "rate": 0.5, "range": 3.1, "cone": 100.0, "max_hits": 3, "power": 1.4, "knock": 2.5, "swing": "bo", "weight": 0.0, "pos": Vector3(0.26, -0.32, -0.5), "scale": 0.65},
	"musket": {"only": "commander", "hidden": true, "name": "Musket", "desc": "Fire shoots; Melee thrusts the bayonet. Powder replenishes while reloading.", "kind": Kind.RANGED, "rate": 1.25, "range": 55.0, "speed": 90.0, "gravity": 0.0, "power": 2.4, "free_ammo": true, "knock": 3.0, "weight": 0.0, "pos": Vector3(0.17, -0.22, -0.4), "scale": 0.8},

}

const STEEL := Color(0.62, 0.66, 0.72)
const DARK := Color(0.17, 0.19, 0.23)
const WOOD := Color(0.42, 0.26, 0.14)
const LIGHT_WOOD := Color(0.6, 0.42, 0.24)
const BRASS := Color(0.78, 0.6, 0.24)

static var _meshes := {}
static var _shields := {}


## Can this be found lying about? Not the weapons that belong to one class: a Monk's Bo, the
## Revenant's claws, a Magician's staff, bare hands.
static func lies_around(id: String) -> bool:
	var d: Dictionary = ALL.get(id, {})
	return not d.is_empty() and not d.get("hidden", false) and not d.has("only") and float(d.get("weight", 0.0)) > 0.0


## How often a weapon turns up, against the others. A map's own weapons (those with "maps") turn up
## a little more often than their weight alone says, so each land's weapons are met on it.
const EXCLUSIVE_BOOST := 1.35
static func spawn_weight(id: String) -> float:
	var d: Dictionary = ALL[id]
	return float(d["weight"]) * (EXCLUSIVE_BOOST if d.has("maps") else 1.0)


static func pick_random(map_id := "") -> String:
	var total := 0.0
	for id: String in ALL:
		if lies_around(id) and SpawnRules.allows(ALL[id], map_id):
			total += spawn_weight(id)
	var r := randf() * total
	for id: String in ALL:
		if not lies_around(id) or not SpawnRules.allows(ALL[id], map_id):
			continue
		r -= spawn_weight(id)
		if r <= 0.0:
			return id
	return "sword"


## A find worth the trip (the caches in ruins): one of the rarer weapons that can lie about on this map.
const RARE_WEIGHT := 1.0 # weights this low or lower mark a weapon as rare
static func pick_rare(map_id := "") -> String:
	var rare: Array[String] = []
	for id: String in ALL:
		if lies_around(id) and SpawnRules.allows(ALL[id], map_id) and float(ALL[id]["weight"]) <= RARE_WEIGHT:
			rare.append(id)
	return rare.pick_random() if not rare.is_empty() else pick_random(map_id)


## How a weapon sits in a character's hand. Poles and bows are drawn along their length, so they need
## a quarter turn to point where the character is looking.
static func hand_rotation(id: String) -> Vector3:
	if id in ["spear", "pitchfork", "javelins", "blowgun", "bow", "longbow", "crossbow", "musket", "harpoon", "flare_pistol"]:
		return Vector3(HAND_TURN, 0.0, 0.0)
	return Vector3.ZERO


## Procedural models use metres; imported models retain their authored size.
static func held_size(id: String) -> float:
	match id:
		"lance": return 1.0
		"bow", "longbow": return 1.1
		"crossbow": return 0.5
	return float(ALL[id]["scale"]) * 1.6


static func is_two_handed(id: String) -> bool:
	return bool(ALL.get(id, {}).get("two_handed", false))


## The four groups the Codex, Armory and class screens talk about.
static func category(id: String) -> String:
	var d: Dictionary = ALL[id]
	if d.has("only") or d.get("hidden", false):
		return "exclusive"
	if d.get("two_handed", false):
		return "two_handed"
	return "ranged" if d["kind"] != Kind.MELEE else "melee"


const CATEGORY_NAMES := {"melee": "Melee", "two_handed": "Two-Handed", "ranged": "Ranged", "exclusive": "Exclusive Weapon"}


static func is_ranged(id: String) -> bool:
	return ALL[id]["kind"] == Kind.RANGED


static func uses_arrows(d: Dictionary) -> bool:
	return d["kind"] == Kind.RANGED and not d.get("returning", false) and not d.get("free_ammo", false) and not d.has("own_ammo") and not d.has("tethered")


## Throws that come with one weapon picked up, for a weapon with its own ammunition (the Rift
## Chakram), or 0 for any other.
static func own_ammo(id: String) -> int:
	return int(ALL.get(id, {}).get("own_ammo", 0))


static func own_ammo_max(id: String) -> int:
	return int(ALL.get(id, {}).get("own_ammo_max", 0))


static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var m: Mesh
	match id:
		"dagger": m = Models.merged("res://assets/weapons/dagger.gltf")
		"sword": m = Models.merged("res://assets/weapons/sword_1handed.gltf")
		"crossbow": m = _crossbow()
		"spear": m = _spear()
		"mace": m = _mace()
		"bow": m = _bow(0.45, 0.17)
		"longbow": m = _bow(0.72, 0.16)
		"lance": m = _lance()
		"scythe": m = _scythe()
		"flail": m = _flail()
		"bell_hammer": m = _bell_hammer()
		"pitchfork": m = _pitchfork()
		"torch": m = _torch()
		"axes": m = axe_mesh()
		"javelins": m = _javelins()
		"fists": m = _fists()
		"bo": m = _bo()
		"blowgun": m = _blowgun()
		"staff", "war_staff": m = _staff()
		"musket": m = _musket()
		"claws": m = _claws()
		"greatsword": m = _greatsword()
		"battleaxe": m = _battleaxe()
		"chakram": m = chakram_mesh()
		"machete": m = _machete()
		"bolas": m = bolas_mesh()
		"cutlass": m = _cutlass()
		"boarding_hook": m = _boarding_hook()
		"harpoon": m = harpoon_mesh()
		"flare_pistol": m = _flare_pistol()
		"anchor": m = _anchor()
		"oar": m = _oar()
		"trident": m = _trident()
	_meshes[id] = m
	return m


const SEA_IRON := Color(0.36, 0.38, 0.4) # iron long in salt water
const RUST := Color(0.52, 0.3, 0.18)
const TAR := Color(0.12, 0.1, 0.09) # tarred rope and black lacquer
const ROPE := Color(0.72, 0.62, 0.42)
const SILVER := Color(0.8, 0.82, 0.86)
const VAEL_BLUE := Color(0.16, 0.3, 0.42)


## A curved blade along a bend: a run of short plates, each turned a little more than the last.
static func _curved_blade(l: LowPoly, from: Vector3, length: float, width: float, thick: float, bend: float, plates: int, col: Color, taper := 0.55) -> Vector3:
	var at := from
	var dir := Vector3.UP
	var step := length / plates
	for i in plates:
		var k := float(i) / plates
		var w := width * lerpf(1.0, taper, k)
		var turn := bend * (k + 0.5 / plates)
		dir = Vector3(sin(turn), cos(turn), 0)
		var mid := at + dir * step * 0.5
		l.box(mid, Vector3(w, step * 1.08, thick), col.lightened(0.04 * (i % 2)), Vector3(0, 0, -rad_to_deg(turn)))
		at += dir * step
	return at


## A sailor's cutlass: a brass basket that cups the hand, a tarred grip bound in brass wire and a broad
## curved blade with a fuller, clipped at the point.
static func _cutlass() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.24, 0), Vector3(0, -0.02, 0), 0.026, 0.03, 6, TAR)
	for i in 5:
		var y := -0.21 + i * 0.04
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.012, 0), 0.032, 0.032, 6, BRASS.darkened(0.2))
	l.box(Vector3(0, -0.27, 0), Vector3(0.06, 0.05, 0.06), BRASS)
	# The basket: a shell plate before the hand, a knuckle bow and two side bars.
	l.box(Vector3(0.0, -0.01, 0.0), Vector3(0.17, 0.03, 0.11), BRASS)
	l.box(Vector3(0.0, 0.0, 0.06), Vector3(0.15, 0.06, 0.012), BRASS.lightened(0.1))
	l.prism(Vector3(0.07, -0.01, 0.0), Vector3(0.08, -0.26, 0.0), 0.012, 0.012, 5, BRASS)
	for z: float in [-0.045, 0.045]:
		l.prism(Vector3(0.06, -0.01, z), Vector3(0.05, -0.17, z * 0.6), 0.009, 0.009, 4, BRASS.darkened(0.1))
	# The blade, curving back towards the spine, with a darker fuller and a clipped point.
	var steel := STEEL.lightened(0.04)
	var tip := _curved_blade(l, Vector3(0, 0.0, 0), 0.62, 0.085, 0.016, 0.38, 9, steel, 0.8)
	_curved_blade(l, Vector3(-0.012, 0.03, 0.009), 0.46, 0.012, 0.004, 0.36, 7, STEEL.darkened(0.3), 1.0)
	l.prism(tip, tip + Vector3(0.09, 0.06, 0), 0.03, 0.0, 4, steel.lightened(0.1))
	return l.commit()


## A boarding hook: an ash haft wound with tarred cord, an iron ferrule, a hooked iron head with a back
## spike, and a ring at its foot with a short chain.
static func _boarding_hook() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.36, 0), Vector3(0, 0.34, 0), 0.024, 0.022, 6, LIGHT_WOOD.darkened(0.08))
	for y: float in [-0.3, -0.24, -0.18, -0.12]:
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.03, 0), 0.028, 0.028, 6, TAR)
	l.prism(Vector3(0, 0.32, 0), Vector3(0, 0.42, 0), 0.03, 0.028, 6, SEA_IRON)
	# The hook: up out of the ferrule, over and down into a sharp barbed point.
	var iron := SEA_IRON.lightened(0.05)
	var at := Vector3(0, 0.42, 0)
	var turns := [0.0, 0.5, 1.1, 1.8, 2.5, 3.05]
	for i in turns.size():
		var a: float = turns[i]
		var next := at + Vector3(sin(a), cos(a), 0) * 0.07
		l.prism(at, next, 0.022 - i * 0.002, 0.02 - i * 0.002, 5, iron if i % 2 == 0 else RUST.lerp(iron, 0.6))
		at = next
	l.prism(at, at + Vector3(-0.02, -0.06, 0), 0.016, 0.0, 4, iron.lightened(0.2))
	l.prism(at + Vector3(0.0, -0.02, 0), at + Vector3(0.03, -0.01, 0), 0.01, 0.0, 3, iron.lightened(0.2))
	l.prism(Vector3(0, 0.44, 0), Vector3(-0.1, 0.52, 0), 0.016, 0.0, 4, iron)
	# A ring and three links of chain at the foot of the haft.
	l.prism(Vector3(0, -0.38, 0), Vector3(0, -0.4, 0), 0.03, 0.03, 8, SEA_IRON)
	for i in 3:
		l.box(Vector3(0.0, -0.44 - i * 0.04, 0.0), Vector3(0.025 if i % 2 == 0 else 0.008, 0.04, 0.008 if i % 2 == 0 else 0.025), SEA_IRON.darkened(0.15))
	return l.commit()


## A whaler's iron: an ash shaft, a barbed toggling head lashed on with tarred cord, and a coil of rope
## at its tail. Lies along -Z, in the hand and in flight.
static func harpoon_mesh() -> Mesh:
	if _meshes.has("_harpoon"):
		return _meshes["_harpoon"]
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, 0.62), Vector3(0, 0, -1.05), 0.026, 0.024, 6, LIGHT_WOOD.darkened(0.18))
	for z: float in [-0.95, -0.88, -0.81]:
		l.prism(Vector3(0, 0, z), Vector3(0, 0, z - 0.03), 0.024, 0.024, 6, TAR)
	l.prism(Vector3(0, 0, -1.05), Vector3(0, 0, -1.3), 0.014, 0.012, 5, SEA_IRON)
	l.prism(Vector3(0, 0, -1.3), Vector3(0, 0, -1.52), 0.045, 0.0, 4, STEEL)
	for side: float in [-1.0, 1.0]:
		l.prism(Vector3(side * 0.03, 0, -1.36), Vector3(side * 0.07, 0, -1.28), 0.012, 0.0, 3, STEEL.darkened(0.1))
		l.prism(Vector3(0, side * 0.025, -1.42), Vector3(0, side * 0.06, -1.35), 0.01, 0.0, 3, STEEL.darkened(0.1))
	# The line, coiled at the tail and tied off.
	for i in 3:
		l.prism(Vector3(0, 0, 0.42 + i * 0.05), Vector3(0, 0, 0.45 + i * 0.05), 0.05, 0.05, 8, ROPE.darkened(0.05 * i))
	l.prism(Vector3(0, 0, 0.58), Vector3(0.03, -0.08, 0.66), 0.01, 0.01, 4, ROPE)
	var m := l.commit()
	_meshes["_harpoon"] = m
	return m


## A harbour pilot's flare pistol: a wide brass barrel with a flared muzzle, a hammer and a curved
## walnut grip with a brass butt cap. Barrel along -Z.
static func _flare_pistol() -> Mesh:
	var l := LowPoly.new()
	var walnut := WOOD.darkened(0.12)
	l.prism(Vector3(0, 0.0, 0.02), Vector3(0, 0.0, -0.19), 0.036, 0.032, 8, BRASS)
	l.prism(Vector3(0, 0.0, -0.19), Vector3(0, 0.0, -0.24), 0.034, 0.042, 8, BRASS.lightened(0.1))
	l.prism(Vector3(0, 0.0, -0.236), Vector3(0, 0.0, -0.244), 0.03, 0.03, 8, TAR)
	l.prism(Vector3(0, 0, -0.03), Vector3(0, 0, -0.045), 0.04, 0.04, 8, BRASS.darkened(0.25))
	# A sight bead along the top of the barrel.
	l.box(Vector3(0, 0.038, -0.2), Vector3(0.008, 0.012, 0.02), SEA_IRON)
	l.box(Vector3(0, -0.03, 0.03), Vector3(0.05, 0.05, 0.1), BRASS.darkened(0.1))
	l.box(Vector3(0, 0.035, 0.07), Vector3(0.018, 0.05, 0.02), SEA_IRON, Vector3(-30, 0, 0))
	l.prism(Vector3(0, -0.03, 0.06), Vector3(0, -0.15, 0.12), 0.032, 0.036, 6, walnut)
	l.prism(Vector3(0, -0.15, 0.12), Vector3(0, -0.2, 0.15), 0.036, 0.04, 6, walnut.lightened(0.05))
	l.box(Vector3(0, -0.21, 0.155), Vector3(0.05, 0.02, 0.06), BRASS)
	l.prism(Vector3(0, -0.04, -0.01), Vector3(0, -0.09, 0.02), 0.008, 0.008, 4, BRASS)
	l.prism(Vector3(0, -0.09, 0.02), Vector3(0, -0.07, 0.07), 0.008, 0.008, 4, BRASS)
	l.box(Vector3(0, -0.02, 0.0), Vector3(0.01, 0.03, 0.01), SEA_IRON)
	# A red flare cartridge showing at the breech.
	l.prism(Vector3(0, 0.0, 0.03), Vector3(0, 0.0, 0.05), 0.028, 0.028, 8, Color(0.75, 0.16, 0.12))
	return l.commit()


## The flare in flight: a red paper cartridge with a burning white-gold head.
static func flare_mesh() -> Mesh:
	if _meshes.has("_flare"):
		return _meshes["_flare"]
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, 0.06), Vector3(0, 0, -0.04), 0.022, 0.022, 8, Color(0.75, 0.16, 0.12))
	l.prism(Vector3(0, 0, -0.04), Vector3(0, 0, -0.08), 0.03, 0.01, 8, Color(1.0, 0.92, 0.6))
	var m := l.commit()
	_meshes["_flare"] = m
	return m


## A ship's anchor swung by its shank: the ring and a few links of chain at the hand end with a
## wooden stock across it, a long iron shank, and at the far end the crown with two curved arms
## ending in broad flukes. Weed and rust from years in the harbour mud.
static func _anchor() -> Mesh:
	var l := LowPoly.new()
	var iron := SEA_IRON.darkened(0.08)
	# Ring and chain wound round the grip.
	l.prism(Vector3(0, -0.5, -0.05), Vector3(0, -0.5, 0.05), 0.07, 0.07, 10, iron)
	l.prism(Vector3(0, -0.5, -0.03), Vector3(0, -0.5, 0.03), 0.045, 0.045, 10, TAR)
	for i in 6:
		var y := -0.38 + i * 0.05
		l.box(Vector3(0, y, 0), Vector3(0.07 if i % 2 == 0 else 0.03, 0.05, 0.03 if i % 2 == 0 else 0.07), iron.lightened(0.05), Vector3(0, 30.0 * i, 0))
	# The stock: a wooden bar through the shank, bound with iron bands.
	l.box(Vector3(0, -0.06, 0), Vector3(0.05, 0.06, 0.62), LIGHT_WOOD.darkened(0.25))
	for z: float in [-0.27, 0.27]:
		l.box(Vector3(0, -0.06, z), Vector3(0.06, 0.07, 0.03), iron)
	# The shank.
	l.prism(Vector3(0, -0.02, 0), Vector3(0, 0.82, 0), 0.04, 0.05, 6, iron)
	l.box(Vector3(0, 0.3, 0.04), Vector3(0.06, 0.1, 0.02), Color(0.22, 0.34, 0.2)) # a trail of weed
	l.box(Vector3(0.02, 0.55, -0.04), Vector3(0.04, 0.14, 0.02), RUST)
	# The crown and two arms curving back down, each ending in a fluke with a sharp bill.
	l.prism(Vector3(0, 0.82, 0), Vector3(0, 0.9, 0), 0.07, 0.06, 6, iron.lightened(0.05))
	for side: float in [-1.0, 1.0]:
		# Out sideways from the crown, then curving back towards the hand.
		var at := Vector3(0, 0.88, 0)
		for i in 5:
			var a := side * (1.45 + i * 0.3)
			var next := at + Vector3(sin(a), cos(a), 0) * 0.1
			l.prism(at, next, 0.042 - i * 0.004, 0.04 - i * 0.004, 6, iron if i % 2 == 0 else iron.lightened(0.06))
			at = next
		# The fluke: a broad spade-shaped palm, its bill pointing back up the shank.
		l.box(at + Vector3(side * -0.015, 0.06, 0), Vector3(0.04, 0.16, 0.15), iron.lightened(0.12), Vector3(0, 0, side * -25.0))
		l.prism(at + Vector3(side * -0.03, 0.12, 0), at + Vector3(side * -0.07, 0.22, 0), 0.03, 0.0, 4, STEEL.darkened(0.2))
	return l.commit()


## A ferryman's oar: a black-lacquered loom with a silver-capped handle, a broad blade edged in
## silver with the lamp of Vael painted on it and coins nailed along its spine.
## The Tidecaller's Trident: a sea-worn haft crusted with coral and barnacles, a bronze collar with a
## shell on it, and three barbed tines, the middle one longer. Points along -Z, like the Spear.
static func _trident() -> Mesh:
	var l := LowPoly.new()
	var haft := Color(0.36, 0.3, 0.24)
	var bronze := Color(0.62, 0.5, 0.26)
	var verdigris := Color(0.36, 0.62, 0.52)
	var coral := Color(0.92, 0.46, 0.4)
	l.prism(Vector3(0, 0, 0.5), Vector3(0, 0, -1.2), 0.02, 0.018, 6, haft)
	l.prism(Vector3(0, 0, 0.5), Vector3(0, 0, 0.56), 0.026, 0.02, 6, bronze)
	# Coral and barnacles, grown over where the sea held it.
	for k in 6:
		var z := -0.2 - k * 0.12
		var a := k * 2.1
		l.prism(Vector3(cos(a) * 0.018, sin(a) * 0.018, z), Vector3(cos(a) * 0.05, sin(a) * 0.05, z - 0.05), 0.012, 0.004, 4, coral if k % 2 == 0 else Color(0.86, 0.84, 0.76))
	# The collar, and a scallop shell on it.
	l.prism(Vector3(0, 0, -1.2), Vector3(0, 0, -1.3), 0.035, 0.04, 8, bronze)
	l.box(Vector3(0, 0.03, -1.25), Vector3(0.06, 0.012, 0.05), Color(0.95, 0.88, 0.78), Vector3(0, 0, 0))
	l.box(Vector3(0, 0, -1.32), Vector3(0.24, 0.03, 0.035), verdigris)
	# The tines: the middle one longer, each with a barb.
	for x: float in [-0.11, 0.0, 0.11]:
		var tip := -1.72 if x == 0.0 else -1.62
		l.prism(Vector3(x, 0, -1.32), Vector3(x, 0, tip + 0.1), 0.014, 0.012, 5, verdigris.lightened(0.15))
		l.prism(Vector3(x, 0, tip + 0.1), Vector3(x, 0, tip), 0.022, 0.0, 4, Color(0.78, 0.84, 0.8))
		l.prism(Vector3(x, 0, tip + 0.1), Vector3(x + (0.035 if x >= 0.0 else -0.035), 0, tip + 0.18), 0.008, 0.0, 3, verdigris.lightened(0.25))
	return l.commit()


static func _oar() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.7, 0), Vector3(0, -0.56, 0), 0.028, 0.03, 6, SILVER.darkened(0.2))
	l.prism(Vector3(0, -0.56, 0), Vector3(0, 0.62, 0), 0.03, 0.026, 6, TAR)
	for y: float in [-0.48, -0.1, 0.3]:
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.03, 0), 0.034, 0.034, 6, SILVER.darkened(0.3))
	# The blade widens from the throat to a rounded tip.
	var widths := [0.06, 0.12, 0.16, 0.17, 0.17, 0.16, 0.12]
	for i in widths.size():
		var y := 0.66 + i * 0.1
		l.box(Vector3(0, y, 0), Vector3(widths[i], 0.105, 0.02), TAR.lightened(0.06 * (i % 2)))
		if i > 0:
			for side: float in [-1.0, 1.0]:
				l.box(Vector3(side * float(widths[i]) * 0.5, y, 0), Vector3(0.012, 0.105, 0.024), SILVER.darkened(0.15))
	l.prism(Vector3(0, 1.36, 0), Vector3(0, 1.42, 0), 0.06, 0.0, 6, SILVER.darkened(0.15))
	# The lamp of Vael on both faces: a pale flame over a little bowl.
	for face: float in [-1.0, 1.0]:
		l.box(Vector3(0, 0.98, face * 0.012), Vector3(0.05, 0.03, 0.004), Color(0.85, 0.72, 0.4))
		l.prism(Vector3(0, 1.0, face * 0.012), Vector3(0, 1.1, face * 0.012), 0.025, 0.0, 4, Color(0.95, 0.88, 0.6))
	# Obols nailed along the spine of the blade.
	for i in 4:
		l.prism(Vector3(0, 0.74 + i * 0.12, 0.012), Vector3(0, 0.74 + i * 0.12, 0.018), 0.018, 0.018, 8, SILVER)
	return l.commit()


## A long two-hand blade: leather grip for both hands, a broad crossguard and a fullered blade.
static func _greatsword() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.42, 0), Vector3(0, -0.06, 0), 0.026, 0.026, 6, WOOD.darkened(0.35))
	for y: float in [-0.36, -0.25, -0.14]:
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.03, 0), 0.031, 0.031, 6, BRASS.darkened(0.3))
	l.box(Vector3(0, -0.46, 0), Vector3(0.06, 0.06, 0.06), BRASS)
	l.box(Vector3(0, -0.04, 0), Vector3(0.36, 0.05, 0.06), DARK)
	l.box(Vector3(-0.19, -0.02, 0), Vector3(0.05, 0.08, 0.07), BRASS)
	l.box(Vector3(0.19, -0.02, 0), Vector3(0.05, 0.08, 0.07), BRASS)
	l.box(Vector3(0, 0.62, 0), Vector3(0.11, 1.24, 0.022), STEEL)
	l.box(Vector3(0, 0.55, 0.012), Vector3(0.025, 1.0, 0.004), STEEL.darkened(0.25))
	l.prism(Vector3(0, 1.24, 0), Vector3(0, 1.4, 0), 0.06, 0.0, 4, STEEL.lightened(0.1))
	return l.commit()


## A bearded mountain axe: long ash haft, a crescent head with a hooked beard and a back spike.
static func _battleaxe() -> Mesh:
	# The head lies along Z so it shows its broad face in the hand, like the Bell Hammer's.
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.75, 0), Vector3(0, 0.66, 0), 0.03, 0.026, 6, LIGHT_WOOD.darkened(0.1))
	for y: float in [-0.65, -0.5, 0.42]:
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.06, 0), 0.036, 0.036, 6, Color(0.55, 0.12, 0.1))
	var head := STEEL.darkened(0.05)
	l.box(Vector3(0, 0.55, 0.12), Vector3(0.04, 0.18, 0.2), head)
	l.box(Vector3(0, 0.52, 0.27), Vector3(0.03, 0.42, 0.12), head.lightened(0.12))
	l.prism(Vector3(0, 0.32, 0.3), Vector3(0, 0.22, 0.2), 0.03, 0.0, 4, head)
	l.prism(Vector3(0, 0.55, -0.03), Vector3(0, 0.58, -0.22), 0.04, 0.0, 4, head)
	l.box(Vector3(0, 0.55, 0), Vector3(0.07, 0.2, 0.07), DARK)
	return l.commit()


## A Pathfinder's chopping blade: wrapped grip, a short guard and a broad blade that widens to a hooked tip.
static func _machete() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.3, 0), Vector3(0, -0.02, 0), 0.024, 0.028, 6, WOOD.darkened(0.3))
	for y: float in [-0.26, -0.17, -0.08]:
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.025, 0), 0.031, 0.031, 6, LIGHT_WOOD)
	l.box(Vector3(0, -0.01, 0), Vector3(0.12, 0.035, 0.05), DARK)
	var blade := STEEL.darkened(0.08)
	l.box(Vector3(0.0, 0.2, 0), Vector3(0.07, 0.4, 0.016), blade)
	l.box(Vector3(0.012, 0.48, 0), Vector3(0.1, 0.18, 0.016), blade.lightened(0.08))
	l.prism(Vector3(0.03, 0.57, 0), Vector3(-0.03, 0.66, 0), 0.05, 0.0, 4, blade.lightened(0.15))
	l.box(Vector3(-0.03, 0.3, 0.01), Vector3(0.012, 0.5, 0.004), DARK)
	return l.commit()


## Three stones on cords, knotted together: the Pathfinder's Bolas, in the hand and in flight.
static func bolas_mesh() -> Mesh:
	if _meshes.has("_bolas"):
		return _meshes["_bolas"]
	var l := LowPoly.new()
	var cord := Color(0.82, 0.74, 0.55)
	var stone := Color(0.5, 0.47, 0.42)
	l.box(Vector3.ZERO, Vector3(0.06, 0.06, 0.06), Color(0.42, 0.26, 0.14))
	for i in 3:
		var a := TAU * i / 3.0
		var tip := Vector3(cos(a), 0, sin(a)) * 0.24
		l.prism(Vector3.ZERO, tip, 0.008, 0.008, 4, cord)
		l.prism(tip - Vector3.UP * 0.05, tip + Vector3.UP * 0.05, 0.05, 0.05, 6, stone if i else stone.lightened(0.12))
	var m := l.commit()
	_meshes["_bolas"] = m
	return m


## A flat ring of pale mist-glass with a cyan core, three notches and a leather grip across it.
static func chakram_mesh() -> Mesh:
	if _meshes.has("_chakram"):
		return _meshes["_chakram"]
	var l := LowPoly.new()
	var glass := Color(0.66, 0.9, 0.95)
	var core := Color(0.25, 0.95, 0.9)
	var n := 12
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0)) * 0.2
		var p1 := Vector3(cos(a1), 0, sin(a1)) * 0.2
		l.box((p0 + p1) * 0.5, Vector3(p0.distance_to(p1) + 0.01, 0.025, 0.06), glass if i % 4 else core, Vector3(0, -rad_to_deg((a0 + a1) * 0.5) + 90.0, 0))
		if i % 4 == 0:
			l.prism(p0 * 1.05, p0 * 1.45, 0.03, 0.0, 4, glass.lightened(0.2))
	l.box(Vector3.ZERO, Vector3(0.34, 0.03, 0.035), Color(0.36, 0.22, 0.12))
	var m := l.commit()
	_meshes["_chakram"] = m
	return m


## Pale and half there: a wrist of mist and three long talons.
static func _claws() -> Mesh:
	var l := LowPoly.new()
	var pale := Color(0.72, 0.95, 0.96)
	var dim := Color(0.34, 0.62, 0.68)
	l.prism(Vector3(0, -0.75, 0.06), Vector3(0, -0.12, 0), 0.05, 0.12, 6, dim)
	l.prism(Vector3(0, -0.12, 0), Vector3(0, 0.08, 0), 0.13, 0.12, 6, dim.lightened(0.15))
	for i in 3:
		var x := -0.1 + i * 0.1
		l.prism(Vector3(x, 0.06, -0.02), Vector3(x * 1.3, 0.3, -0.05), 0.04, 0.024, 4, pale)
		l.prism(Vector3(x * 1.3, 0.3, -0.05), Vector3(x * 1.5, 0.58, -0.14), 0.024, 0.0, 4, Color(0.92, 1.0, 1.0))
	var m := l.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.82)
	mat.disable_fog = true
	m.surface_set_material(0, mat)
	return m


static func _spear() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, 0.5), Vector3(0, 0, -1.6), 0.018, 0.018, 5, WOOD)
	l.box(Vector3(0, 0, -1.6), Vector3(0.05, 0.05, 0.06), DARK)
	l.prism(Vector3(0, 0, -1.62), Vector3(0, 0, -1.95), 0.05, 0.0, 4, STEEL)
	return l.commit()


static func _fists() -> Mesh:
	const SKIN := Color(0.82, 0.62, 0.46)
	const WRAP := Color(0.9, 0.86, 0.76)
	var l := LowPoly.new()
	# A closed fist: knuckles, thumb, and a forearm bound in cloth.
	l.box(Vector3(0, 0.08, 0), Vector3(0.24, 0.22, 0.24), SKIN)
	for x: float in [-0.08, 0.0, 0.08]:
		l.box(Vector3(x, 0.2, 0.03), Vector3(0.07, 0.05, 0.16), SKIN.lightened(0.12))
	l.box(Vector3(-0.15, 0.08, 0.04), Vector3(0.07, 0.16, 0.1), SKIN.darkened(0.08))
	l.box(Vector3(0, -0.1, 0), Vector3(0.2, 0.16, 0.2), WRAP)
	l.prism(Vector3(0, -0.14, 0), Vector3(0, -0.7, 0), 0.09, 0.11, 6, SKIN)
	return l.commit()


static func _bo() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -1.0, 0), Vector3(0, 1.0, 0), 0.028, 0.028, 6, LIGHT_WOOD.darkened(0.15))
	l.box(Vector3(0, 0.82, 0), Vector3(0.07, 0.1, 0.07), DARK)
	l.box(Vector3(0, -0.82, 0), Vector3(0.07, 0.1, 0.07), DARK)
	return l.commit()


static func _javelins() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, 0.45), Vector3(0, 0, -0.75), 0.016, 0.016, 5, LIGHT_WOOD)
	l.prism(Vector3(0, 0, -0.75), Vector3(0, 0, -1.0), 0.04, 0.0, 4, STEEL)
	l.box(Vector3(0, 0, 0.05), Vector3(0.035, 0.035, 0.12), DARK)
	return l.commit()


static func _blowgun() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, 0.2), Vector3(0, 0, -0.62), 0.016, 0.012, 6, Color(0.46, 0.5, 0.26))
	l.box(Vector3(0, 0, -0.2), Vector3(0.028, 0.028, 0.03), DARK)
	l.box(Vector3(0, 0, 0.12), Vector3(0.028, 0.028, 0.03), DARK)
	return l.commit()


static func _lance() -> Mesh:
	var l := LowPoly.new()
	var red := Color(0.62, 0.14, 0.12)
	l.prism(Vector3(0, 0, 0.45), Vector3(0, 0, -0.1), 0.028, 0.034, 6, DARK)
	l.prism(Vector3(0, 0, -0.1), Vector3(0, 0, -0.32), 0.1, 0.03, 8, red)
	l.prism(Vector3(0, 0, -0.32), Vector3(0, 0, -2.3), 0.032, 0.012, 6, Color(0.82, 0.78, 0.68))
	l.prism(Vector3(0, 0, -2.3), Vector3(0, 0, -2.6), 0.022, 0.0, 5, STEEL)
	return l.commit()


static func _mace() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.46, 0), 0.022, 0.022, 6, WOOD)
	l.box(Vector3(0, -0.16, 0), Vector3(0.055, 0.14, 0.055), DARK)
	l.prism(Vector3(0, 0.42, 0), Vector3(0, 0.7, 0), 0.075, 0.075, 6, DARK)
	for a: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, 0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, -0.7)]:
		var y := 0.56 if absf(a.x) == 1.0 or absf(a.z) == 1.0 else 0.48
		l.prism(Vector3(0, y, 0) + a * 0.06, Vector3(0, y, 0) + a * 0.14, 0.035, 0.0, 4, STEEL)
	l.prism(Vector3(0, 0.7, 0), Vector3(0, 0.8, 0), 0.05, 0.0, 4, STEEL)
	return l.commit()


static func _scythe() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.35, 0), Vector3(0.05, 0.95, 0), 0.02, 0.017, 5, WOOD)
	l.box(Vector3(0.02, -0.02, 0), Vector3(0.14, 0.03, 0.03), DARK)
	var prev := Vector3(0.05, 0.93, 0)
	for i in range(1, 7):
		var t := float(i) / 6.0
		var p := Vector3(0.05 - t * 0.72, 0.93 + sin(t * 1.7) * 0.17 - t * t * 0.17, 0)
		l.box((prev + p) * 0.5, Vector3(prev.distance_to(p) + 0.02, 0.07 * (1.1 - t * 0.8), 0.012), STEEL, Vector3(0, 0, rad_to_deg(atan2(p.y - prev.y, p.x - prev.x))))
		prev = p
	return l.commit()


static func _flail() -> Mesh:
	return LowPoly.new() \
		.prism(Vector3(0, -0.2, 0), Vector3(0, 0.34, 0), 0.028, 0.024, 6, WOOD) \
		.box(Vector3(0, 0.34, 0), Vector3(0.07, 0.07, 0.07), DARK) \
		.box(Vector3(0, -0.1, 0), Vector3(0.065, 0.22, 0.065), DARK).commit()


static func flail_chain() -> Mesh:
	if _meshes.has("chain"):
		return _meshes["chain"]
	var l := LowPoly.new()
	for i in 8:
		var y := -0.035 - i * 0.055
		# Alternating open links, rather than a rigid rod.
		for offset: float in [-0.018, 0.018]:
			var centre := Vector3(offset, y, 0) if i % 2 == 0 else Vector3(0, y, offset)
			l.box(centre, Vector3(0.009, 0.055, 0.009), STEEL)
		for offset: float in [-0.026, 0.026]:
			l.box(Vector3(0, y + offset, 0), Vector3(0.04, 0.009, 0.009) if i % 2 == 0 else Vector3(0.009, 0.009, 0.04), DARK)
	var c := Vector3(0, -0.55, 0)
	l.prism(c - Vector3.UP * 0.1, c + Vector3.UP * 0.1, 0.12, 0.12, 8, DARK)
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		l.prism(c + d * 0.08, c + d * 0.23, 0.045, 0.0, 4, STEEL)
	_meshes["chain"] = l.commit()
	return _meshes["chain"]


## Armoured war hammer with a solid striking face and rear pick.
static func _bell_hammer() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.5, 0), Vector3(0, 0.85, 0), 0.035, 0.03, 8, WOOD)
	for y: float in [-0.35, -0.12, 0.6]:
		l.prism(Vector3(0, y, 0), Vector3(0, y + 0.13, 0), 0.043, 0.043, 8, DARK)
	l.box(Vector3(0, 0.8, 0), Vector3(0.3, 0.32, 0.22), DARK)
	# Solid striking face. The old bell, mouth and clapper are gone.
	l.box(Vector3(0, 0.8, 0.3), Vector3(0.38, 0.34, 0.1), STEEL)
	l.prism(Vector3(0, 0.8, -0.1), Vector3(0, 0.85, -0.45), 0.09, 0.0, 4, STEEL)
	for x: float in [-0.17, 0.17]:
		l.box(Vector3(x, 0.8, 0.12), Vector3(0.04, 0.34, 0.22), DARK)
	l.box(Vector3(0, 1.0, 0.08), Vector3(0.38, 0.05, 0.3), STEEL)
	return l.commit()


static func _pitchfork() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, 0.5), Vector3(0, 0, -1.25), 0.018, 0.016, 5, LIGHT_WOOD)
	l.box(Vector3(0, 0, -1.28), Vector3(0.3, 0.03, 0.04), DARK)
	for x: float in [-0.14, 0.0, 0.14]:
		l.prism(Vector3(x, 0, -1.28), Vector3(x, 0, -1.68), 0.012, 0.0, 4, STEEL)
	return l.commit()


static func _torch() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.44, 0), 0.022, 0.03, 6, WOOD)
	# Rags bound round the head, charred where they burn.
	l.prism(Vector3(0, 0.42, 0), Vector3(0, 0.5, 0), 0.034, 0.058, 7, Color(0.36, 0.28, 0.18))
	l.prism(Vector3(0, 0.5, 0), Vector3(0, TORCH_FIRE, 0), 0.058, 0.05, 7, Color(0.1, 0.08, 0.07))
	# Fire: several tongues, so it cannot be taken for a spear point. White is how the shader tells it apart.
	var fire := Color.WHITE
	l.prism(Vector3(0, TORCH_FIRE, 0), Vector3(0.01, 0.84, 0.0), 0.05, 0.0, 6, fire)
	l.prism(Vector3(0.03, TORCH_FIRE, 0.016), Vector3(0.08, 0.74, 0.03), 0.032, 0.0, 5, fire)
	l.prism(Vector3(-0.03, TORCH_FIRE, 0.012), Vector3(-0.075, 0.71, 0.026), 0.032, 0.0, 5, fire)
	l.prism(Vector3(0.0, TORCH_FIRE, -0.028), Vector3(-0.02, 0.77, -0.07), 0.03, 0.0, 5, fire)
	l.prism(Vector3(0.012, TORCH_FIRE, 0.03), Vector3(0.02, 0.68, 0.075), 0.026, 0.0, 5, fire)
	var mesh := l.commit()
	mesh.surface_set_material(0, _torch_material())
	return mesh


## The handle is lit like anything else. The fire above it glows, and flickers by itself.
static func _torch_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
varying float fire;
varying float rise;
void vertex() {
	fire = step(0.99, COLOR.b);
	rise = max(VERTEX.y - %.3f, 0.0);
	float t = TIME * 10.0 + MODEL_MATRIX[3].x * 3.0;
	VERTEX.x += sin(t + VERTEX.y * 26.0 + VERTEX.z * 40.0) * rise * 0.2;
	VERTEX.z += cos(t * 1.27 + VERTEX.y * 21.0 + VERTEX.x * 40.0) * rise * 0.16;
	VERTEX.y += (sin(t * 1.73 + VERTEX.x * 50.0) * 0.5 + 0.2) * rise * 0.2;
}
void fragment() {
	float up = clamp(rise / 0.26, 0.0, 1.0);
	vec3 flame = mix(vec3(1.0, 0.82, 0.34), vec3(1.0, 0.36, 0.05), smoothstep(0.1, 0.8, up));
	ALBEDO = COLOR.rgb * (1.0 - fire);
	EMISSION = flame * fire * 1.05;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
""" % TORCH_FIRE
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func axe_mesh() -> Mesh:
	if _meshes.has("_axe"):
		return _meshes["_axe"]
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.3, 0), 0.018, 0.018, 5, WOOD)
	l.box(Vector3(0.08, 0.24, 0), Vector3(0.16, 0.12, 0.016), STEEL)
	l.box(Vector3(0.17, 0.24, 0), Vector3(0.05, 0.24, 0.014), STEEL.lightened(0.15))
	var m := l.commit()
	_meshes["_axe"] = m
	return m


static func _staff() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.4, 0), Vector3(0, 0.7, 0), 0.02, 0.016, 6, WOOD.darkened(0.2))
	l.prism(Vector3(0, 0.66, 0), Vector3(-0.06, 0.8, 0), 0.016, 0.012, 5, WOOD)
	l.prism(Vector3(0, 0.66, 0), Vector3(0.06, 0.8, 0), 0.016, 0.012, 5, WOOD)
	l.prism(Vector3(0, 0.74, 0), Vector3(0, 0.86, 0), 0.06, 0.055, 7, Color(0.5, 0.75, 1.0))
	l.prism(Vector3(0, 0.86, 0), Vector3(0, 0.92, 0), 0.055, 0.0, 7, Color(0.75, 0.9, 1.0))
	return l.commit()


## tier 0 wood round, 1 banded, 2 iron round, 3 rectangular iron.
static func shield_mesh(tier: int) -> Mesh:
	if _shields.has(tier):
		return _shields[tier]
	var l := LowPoly.new()
	var iron := Color(0.5, 0.53, 0.58)
	if tier >= 3:
		l.box(Vector3.ZERO, Vector3(0.62, 0.92, 0.05), iron)
		l.box(Vector3(0, 0, -0.03), Vector3(0.5, 0.8, 0.02), iron.darkened(0.25))
		l.box(Vector3(0, 0, -0.045), Vector3(0.09, 0.8, 0.02), Color(0.62, 0.14, 0.12))
		l.box(Vector3(0, 0.12, -0.045), Vector3(0.5, 0.09, 0.02), Color(0.62, 0.14, 0.12))
	else:
		var face := WOOD.lightened(0.15) if tier < 2 else iron.darkened(0.2)
		var rim := WOOD.darkened(0.25) if tier == 0 else iron
		l.prism(Vector3(0, 0, 0.02), Vector3(0, 0, -0.02), 0.36, 0.36, 12, rim)
		l.prism(Vector3(0, 0, -0.02), Vector3(0, 0, -0.035), 0.32, 0.32, 12, face)
		l.prism(Vector3(0, 0, -0.035), Vector3(0, 0, -0.08), 0.08, 0.05, 8, iron if tier > 0 else DARK)
		if tier >= 1:
			l.box(Vector3(0, 0, -0.04), Vector3(0.62, 0.05, 0.015), iron)
			l.box(Vector3(0, 0, -0.04), Vector3(0.05, 0.62, 0.015), iron)
	# The side you actually see in first person: planks and arm straps.
	var back := WOOD.darkened(0.15)
	var strap := Color(0.2, 0.13, 0.09)
	if tier >= 3:
		l.box(Vector3(0, 0, 0.03), Vector3(0.58, 0.88, 0.02), back)
		for x: float in [-0.19, 0.0, 0.19]:
			l.box(Vector3(x, 0, 0.042), Vector3(0.015, 0.88, 0.008), strap)
		for y: float in [-0.34, 0.34]:
			l.box(Vector3(0, y, 0.05), Vector3(0.64, 0.05, 0.02), iron.darkened(0.3))
		l.box(Vector3(0, 0.12, 0.06), Vector3(0.36, 0.06, 0.03), strap)
		l.box(Vector3(0, -0.14, 0.06), Vector3(0.36, 0.06, 0.03), strap)
	else:
		l.prism(Vector3(0, 0, 0.02), Vector3(0, 0, 0.035), 0.33, 0.33, 12, back)
		for x: float in [-0.17, -0.06, 0.06, 0.17]:
			var half := sqrt(0.32 * 0.32 - x * x)
			l.box(Vector3(x, 0, 0.038), Vector3(0.012, half * 2.0, 0.006), strap)
		l.box(Vector3(0, 0.09, 0.05), Vector3(0.34, 0.05, 0.025), strap)
		l.box(Vector3(0, -0.09, 0.05), Vector3(0.34, 0.05, 0.025), strap)
	var m := l.commit()
	_shields[tier] = m
	return m


static func _bow(half: float, depth: float) -> Mesh:
	var l := LowPoly.new()
	var prev := Vector3.ZERO
	for i in range(0, 9):
		var t := float(i) / 8.0 * 2.0 - 1.0
		var p := Vector3(0, t * half, -depth * (1.0 - t * t))
		if i > 0:
			l.prism(prev, p, 0.016, 0.016, 5, LIGHT_WOOD if half > 0.6 else WOOD)
		prev = p
	l.box(Vector3(0, 0, -depth), Vector3(0.035, 0.11, 0.04), DARK)
	var string_col := Color(0.9, 0.9, 0.85)
	l.prism(Vector3(0, half, 0), Vector3(0, 0, 0.1), 0.004, 0.004, 3, string_col)
	l.prism(Vector3(0, -half, 0), Vector3(0, 0, 0.1), 0.004, 0.004, 3, string_col)
	return l.commit()


static func _musket() -> Mesh:
	var l := LowPoly.new()
	l.box(Vector3(0, 0, 0.2), Vector3(0.11, 0.16, 0.7), WOOD)
	l.prism(Vector3(0, 0.07, -0.05), Vector3(0, 0.07, -1.15), 0.045, 0.045, 6, DARK)
	for z: float in [-0.2, -0.8]:
		l.box(Vector3(0, 0.04, z), Vector3(0.13, 0.14, 0.06), BRASS)
	l.prism(Vector3(0.07, 0.07, -0.95), Vector3(0.07, 0.07, -1.55), 0.035, 0.0, 4, STEEL)
	return l.commit()


## Folded, double-sided cloth with a split hem and raised heraldry.
static func banner_mesh() -> Mesh:
	if _meshes.has("banner"):
		return _meshes["banner"]
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.5, 0), Vector3(0, 1.5, 0), 0.028, 0.025, 6, WOOD)
	l.prism(Vector3(0, 1.5, 0), Vector3(0, 1.75, 0), 0.075, 0.0, 4, BRASS)
	l.prism(Vector3(-0.04, 1.43, 0), Vector3(0.78, 1.43, 0), 0.018, 0.018, 6, BRASS)
	_meshes["banner"] = l.commit()
	var fabric := SurfaceTool.new()
	fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 8:
		for y in 4:
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)]:
				var uv := Vector2((x + corner.x) / 8.0, (y + corner.y) / 4.0)
				var drop := 0.6 + 0.06 * absf(uv.x * 2.0 - 1.0)
				fabric.set_normal(Vector3.FORWARD)
				fabric.set_uv(uv)
				fabric.add_vertex(Vector3(0.045 + uv.x * 0.62, 1.4 - uv.y * drop, sin(uv.x * TAU * 1.3) * 0.035 * uv.y))
	var mesh := _meshes["banner"] as ArrayMesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fabric.commit_to_arrays())
	var cloth := ShaderMaterial.new()
	cloth.shader = preload("res://assets/shaders/banner.gdshader")
	mesh.surface_set_material(1, cloth)
	return mesh



static func _crossbow() -> Mesh:
	# Stock points down -Z, like the projectile. Ammunition is a separate animated mesh.
	var l := LowPoly.new()
	l.box(Vector3(0, 0, 0), Vector3(0.2, 0.24, 2.0), WOOD)
	l.box(Vector3(0, 0.14, -0.1), Vector3(0.09, 0.04, 1.6), DARK)
	l.box(Vector3(0, -0.23, 0.35), Vector3(0.14, 0.4, 0.25), DARK)
	for side: float in [-1.0, 1.0]:
		l.prism(Vector3(0, 0, -0.7), Vector3(side * 0.9, 0, -0.4), 0.07, 0.04, 6, STEEL)
		l.prism(Vector3(side * 0.9, 0, -0.4), Vector3(0, 0.12, 0.5), 0.012, 0.012, 3, LIGHT_WOOD)
	return l.commit()
