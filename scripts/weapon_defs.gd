class_name WeaponDefs
## Each hit does DAMAGE times the weapon's power. Range, cadence, shape and a special rule set them apart.

enum Kind { MELEE, RANGED, SPELL }

const DAMAGE := 25.0
const ALIGNED_HELD := ["lance", "scythe", "flail", "bell_hammer", "bow", "longbow", "crossbow", "greatsword"]
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
	"chakram": {"maps": ["mesenlla", "bastion"], "power": 1.0, "name": "Rift Chakram", "shot": "chakram", "bounces": 3, "free_ammo": true, "desc": "A ring of mist-glass that the valley scouts throw. Ricochets on to three more enemies, and needs no arrows.", "kind": Kind.RANGED, "rate": 0.6, "range": 28.0, "speed": 30.0, "gravity": 0.0,
		"knock": 1.0, "weight": 0.9, "pos": Vector3(0.24, -0.26, -0.46), "scale": 0.5},
	# Pathfinder finds: unearthed by a Pathfinder's beacons, and only a Pathfinder can use them.
	"machete": {"only": "cartographer", "spec": "pathfinder", "power": 0.95, "name": "Pathfinder's Machete", "bleed": true, "desc": "Pathfinder only, unearthed by its beacons. Quick, wide chops that clear a path and leave enemies bleeding.", "kind": Kind.MELEE, "rate": 0.42, "range": 2.7, "cone": 115.0, "max_hits": 3,
		"knock": 1.8, "swing": "slash", "weight": 0.0, "pos": Vector3(0.26, -0.3, -0.46), "scale": 0.46},
	"bolas": {"only": "cartographer", "spec": "pathfinder", "power": 0.9, "name": "Pathfinder's Bolas", "shot": "bolas", "slows": 2.5, "free_ammo": true, "desc": "Pathfinder only, unearthed by its beacons. Weighted cords that tangle the legs: everything they hit is slowed for 2.5 s. No arrows needed.", "kind": Kind.RANGED, "rate": 0.7, "range": 24.0, "speed": 26.0, "gravity": 3.0,
		"knock": 1.2, "weight": 0.0, "pos": Vector3(0.24, -0.26, -0.46), "scale": 0.5},
	"war_staff": {"only": "commander", "hidden": true, "name": "War Staff", "desc": "Melee staff; every fifth attack fires battle magic.", "kind": Kind.MELEE, "rate": 0.5, "range": 3.1, "cone": 100.0, "max_hits": 3, "power": 1.1, "knock": 2.5, "swing": "bo", "weight": 0.0, "pos": Vector3(0.26, -0.32, -0.5), "scale": 0.65},
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


static func pick_random(map_id := "") -> String:
	var total := 0.0
	for id: String in ALL:
		if lies_around(id) and SpawnRules.allows(ALL[id], map_id):
			total += float(ALL[id]["weight"])
	var r := randf() * total
	for id: String in ALL:
		if not lies_around(id) or not SpawnRules.allows(ALL[id], map_id):
			continue
		r -= float(ALL[id]["weight"])
		if r <= 0.0:
			return id
	return "sword"


## How a weapon sits in a character's hand. Poles and bows are drawn along their length, so they need
## a quarter turn to point where the character is looking.
static func hand_rotation(id: String) -> Vector3:
	if id in ["spear", "pitchfork", "javelins", "blowgun", "bow", "longbow", "crossbow", "musket"]:
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
	return d["kind"] == Kind.RANGED and not d.get("returning", false) and not d.get("free_ammo", false)


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
	_meshes[id] = m
	return m


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
