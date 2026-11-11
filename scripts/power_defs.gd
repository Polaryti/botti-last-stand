class_name PowerDefs
## Timed potions and familiars, plus food. Icons are built from simple shapes.

const POTION_TIME := 20.0
const FAMILIAR_TIME := 20.0
const SENSOR_RANGE := 20.0

const ALL := {
	"speed": {"name": "Speed", "desc": "You run 40% faster.", "time": POTION_TIME, "color": Color(1.0, 0.85, 0.25), "familiar": false, "weight": 3.0},
	"sensor": {"name": "Sensor", "desc": "Arrows point to enemies and weapons within 20 metres.", "time": POTION_TIME, "color": Color(0.35, 0.9, 1.0), "familiar": false, "weight": 3.0},
	"fire_arrows": {"name": "Fire Arrows", "desc": "Arrows set enemies on fire and light up the dark.", "time": POTION_TIME, "color": Color(1.0, 0.45, 0.12), "familiar": false, "weight": 2.5},
	"bounce_arrows": {"name": "Bouncing Arrows", "desc": "Each arrow jumps on to two more enemies.", "time": POTION_TIME, "color": Color(0.74, 0.45, 1.0), "familiar": false, "weight": 2.5},
	"angel": {"name": "Angel", "desc": "Heals you every 3 seconds.", "time": FAMILIAR_TIME, "color": Color(0.96, 0.94, 0.78), "familiar": true, "weight": 1.0},
	"daemon": {"name": "Daemon", "desc": "Everything you do hits 80% harder.", "time": FAMILIAR_TIME, "color": Color(0.95, 0.2, 0.16), "familiar": true, "weight": 1.0},
	"archer": {"name": "Archer", "desc": "Shoots an arrow at a nearby enemy every second.", "time": FAMILIAR_TIME, "color": Color(0.4, 0.82, 0.35), "familiar": true, "weight": 1.0},
	"thunder": {"name": "Thunder", "desc": "Calls lightning on nearby enemies every 5 seconds.", "time": FAMILIAR_TIME, "color": Color(0.5, 0.7, 1.0), "familiar": true, "weight": 1.0},
	"raven": {"name": "Raven", "desc": "Marks every enemy within 32 metres, even through walls.", "time": FAMILIAR_TIME, "color": Color(0.55, 0.45, 0.8), "familiar": true, "weight": 1.0},
	"ghost": {"name": "Ghost Knight", "desc": "A spirit fights at your side and draws attacks away from you.", "time": FAMILIAR_TIME, "color": Color(0.55, 0.9, 1.0), "familiar": true, "weight": 1.0},
	"imp": {"name": "Thief Imp", "desc": "Brings you the nearest item on the map, every 4 seconds.", "time": FAMILIAR_TIME, "color": Color(0.9, 0.65, 0.2), "familiar": true, "weight": 1.0},
	"bell_spirit": {"maps": ["village", "fort"], "name": "Bell Spirit", "desc": "Rings every 6 seconds, stunning all within 10 metres.", "time": FAMILIAR_TIME, "color": Color(1.0, 0.85, 0.45), "familiar": true, "weight": 1.0},
	"rat": {"maps": ["village", "fort"], "name": "Plague Rat", "desc": "Leaves a trail of poison behind you.", "time": FAMILIAR_TIME, "color": Color(0.5, 0.85, 0.3), "familiar": true, "weight": 1.0},
}

const FOODS := {
	"apple": {"name": "Apple", "heal": 12.0, "weight": 3.0},
	"bread": {"name": "Bread", "heal": 20.0, "weight": 3.0},
	"cheese": {"name": "Cheese", "heal": 25.0, "weight": 2.0},
	"meat": {"name": "Roast Meat", "heal": 40.0, "weight": 1.0},
}

const ARCHER_INTERVAL := 1.0
const ARCHER_RANGE := 22.0
const ANGEL_INTERVAL := 3.0
const ANGEL_HEAL := 6.0
const THUNDER_INTERVAL := 5.0
const THUNDER_RANGE := 26.0
const THUNDER_RADIUS := 5.0
const THUNDER_DAMAGE := 50.0
const DAEMON_MULTIPLIER := 1.8
const RAVEN_RANGE := 32.0
const IMP_INTERVAL := 4.0
const IMP_RANGE := 28.0
const BELL_INTERVAL := 6.0
const BELL_RADIUS := 10.0
const BELL_STUN := 1.5
const RAT_INTERVAL := 1.1
const POISON_TIME := 6.0
const POISON_DPS := 10.0
const BOUNCES := 2

static var _meshes := {}
static var _moving := {}


static func pick_weighted(table: Dictionary) -> String:
	var total := 0.0
	for id: String in table:
		total += float(table[id]["weight"])
	var r := randf() * total
	for id: String in table:
		r -= float(table[id]["weight"])
		if r <= 0.0:
			return id
	return table.keys()[0]


static func pick_potion() -> String:
	var t := {}
	for id: String in ALL:
		if not ALL[id]["familiar"]:
			t[id] = ALL[id]
	return pick_weighted(t)


static func pick_familiar(map_id := "") -> String:
	var t := {}
	for id: String in ALL:
		if ALL[id]["familiar"] and SpawnRules.allows(ALL[id], map_id):
			t[id] = ALL[id]
	return pick_weighted(t)


## How a familiar moves at your shoulder: wings beat, and a rat scurries.
static func familiar_material(id: String) -> ShaderMaterial:
	if not _moving.has(id):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/familiar.gdshader")
		m.set_shader_parameter("flap", {"angel": 0.6, "daemon": 0.8, "raven": 1.0, "imp": 0.5}.get(id, 0.0))
		m.set_shader_parameter("scurry", 1.0 if id == "rat" else 0.0)
		_moving[id] = m
	return _moving[id]


static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var l := LowPoly.new()
	match id:
		"apple":
			l.prism(Vector3(0, -0.14, 0), Vector3(0, 0.14, 0), 0.17, 0.15, 7, Color(0.8, 0.13, 0.12))
			l.prism(Vector3(0, 0.14, 0), Vector3(0, 0.26, 0), 0.015, 0.015, 4, Color(0.3, 0.2, 0.1))
			l.box(Vector3(0.05, 0.22, 0), Vector3(0.1, 0.02, 0.06), Color(0.3, 0.6, 0.2))
		"bread":
			l.box(Vector3.ZERO, Vector3(0.5, 0.2, 0.26), Color(0.76, 0.5, 0.24))
			l.box(Vector3(0, 0.11, 0), Vector3(0.42, 0.08, 0.2), Color(0.6, 0.36, 0.16))
		"cheese":
			l.prism(Vector3(0, -0.12, 0), Vector3(0, 0.12, 0), 0.24, 0.24, 3, Color(0.95, 0.78, 0.25))
		"meat":
			l.prism(Vector3(-0.3, 0, 0), Vector3(0.1, 0, 0), 0.05, 0.05, 5, Color(0.9, 0.88, 0.78))
			l.prism(Vector3(-0.08, 0, 0), Vector3(0.28, 0, 0), 0.13, 0.2, 7, Color(0.5, 0.22, 0.12))
		"arrows":
			for i in 5:
				var x := -0.1 + i * 0.05
				l.prism(Vector3(x, -0.3, 0), Vector3(x, 0.26, 0), 0.012, 0.012, 4, WeaponDefs.LIGHT_WOOD)
				l.prism(Vector3(x, 0.26, 0), Vector3(x, 0.36, 0), 0.026, 0.0, 4, WeaponDefs.STEEL)
				l.box(Vector3(x, -0.3, 0), Vector3(0.012, 0.12, 0.05), Color(0.9, 0.9, 0.85))
			l.box(Vector3(0, -0.02, 0), Vector3(0.3, 0.05, 0.1), WeaponDefs.WOOD)
		"angel":
			var white := Color(0.97, 0.95, 0.88)
			l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.1, 0), 0.12, 0.06, 6, white)
			l.prism(Vector3(0, 0.1, 0), Vector3(0, 0.22, 0), 0.07, 0.07, 6, Color(1, 0.86, 0.7))
			l.box(Vector3(-0.16, 0.03, -0.03), Vector3(0.22, 0.14, 0.02), white, Vector3(0, 0, 20))
			l.box(Vector3(0.16, 0.03, -0.03), Vector3(0.22, 0.14, 0.02), white, Vector3(0, 0, -20))
			l.prism(Vector3(0, 0.29, 0), Vector3(0, 0.31, 0), 0.09, 0.09, 8, Color(1, 0.85, 0.25))
		"daemon":
			var red := Color(0.72, 0.1, 0.08)
			l.prism(Vector3(0, -0.18, 0), Vector3(0, 0.12, 0), 0.08, 0.12, 6, red)
			l.prism(Vector3(0, 0.12, 0), Vector3(0, 0.24, 0), 0.09, 0.08, 6, red)
			l.prism(Vector3(-0.05, 0.22, 0), Vector3(-0.1, 0.36, 0), 0.025, 0.0, 4, Color(0.1, 0.08, 0.08))
			l.prism(Vector3(0.05, 0.22, 0), Vector3(0.1, 0.36, 0), 0.025, 0.0, 4, Color(0.1, 0.08, 0.08))
			l.box(Vector3(-0.17, 0.05, -0.02), Vector3(0.22, 0.12, 0.02), Color(0.25, 0.05, 0.05), Vector3(0, 0, -25))
			l.box(Vector3(0.17, 0.05, -0.02), Vector3(0.22, 0.12, 0.02), Color(0.25, 0.05, 0.05), Vector3(0, 0, 25))
			l.box(Vector3(-0.035, 0.19, 0.08), Vector3(0.03, 0.03, 0.02), Color(1, 0.9, 0.2))
			l.box(Vector3(0.035, 0.19, 0.08), Vector3(0.03, 0.03, 0.02), Color(1, 0.9, 0.2))
		"archer":
			var green := Color(0.22, 0.45, 0.2)
			l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.14, 0), 0.13, 0.05, 6, green)
			l.prism(Vector3(0, 0.12, 0), Vector3(0, 0.3, 0), 0.08, 0.0, 6, green)
			l.prism(Vector3(0, 0.08, 0.02), Vector3(0, 0.17, 0.02), 0.05, 0.05, 6, Color(0.95, 0.78, 0.62))
			l.prism(Vector3(0.15, -0.15, 0), Vector3(0.21, 0.02, 0), 0.01, 0.01, 4, WeaponDefs.WOOD)
			l.prism(Vector3(0.21, 0.02, 0), Vector3(0.15, 0.19, 0), 0.01, 0.01, 4, WeaponDefs.WOOD)
		"thunder":
			var cloud := Color(0.38, 0.45, 0.6)
			l.box(Vector3(0, 0.1, 0), Vector3(0.36, 0.14, 0.2), cloud)
			l.box(Vector3(-0.09, 0.2, 0), Vector3(0.16, 0.12, 0.14), cloud.lightened(0.2))
			l.box(Vector3(0.09, 0.18, 0), Vector3(0.16, 0.1, 0.14), cloud.lightened(0.1))
			var y := Color(1.0, 0.92, 0.3)
			l.box(Vector3(0.02, -0.03, 0), Vector3(0.05, 0.14, 0.04), y, Vector3(0, 0, 25))
			l.box(Vector3(-0.01, -0.15, 0), Vector3(0.05, 0.14, 0.04), y, Vector3(0, 0, -25))
		"raven":
			var black := Color(0.09, 0.08, 0.13)
			l.prism(Vector3(0, -0.02, -0.12), Vector3(0, 0.02, 0.15), 0.06, 0.09, 6, black)
			l.prism(Vector3(0, 0.05, 0.14), Vector3(0, 0.08, 0.26), 0.07, 0.06, 6, black)
			l.prism(Vector3(0, 0.07, 0.26), Vector3(0, 0.05, 0.38), 0.03, 0.0, 4, Color(0.7, 0.6, 0.2))
			l.box(Vector3(-0.2, 0.05, 0.03), Vector3(0.34, 0.015, 0.16), black.lightened(0.1), Vector3(0, 0, 22))
			l.box(Vector3(0.2, 0.05, 0.03), Vector3(0.34, 0.015, 0.16), black.lightened(0.1), Vector3(0, 0, -22))
			l.box(Vector3(0.035, 0.1, 0.27), Vector3(0.02, 0.02, 0.01), Color(1, 0.9, 0.3))
			l.box(Vector3(-0.035, 0.1, 0.27), Vector3(0.02, 0.02, 0.01), Color(1, 0.9, 0.3))
		"ghost":
			var g := Color(0.55, 0.9, 1.0)
			l.prism(Vector3(0, -0.26, 0), Vector3(0, 0.1, 0), 0.05, 0.14, 7, g.darkened(0.2))
			l.box(Vector3(0, 0.2, 0), Vector3(0.15, 0.17, 0.15), g)
			l.box(Vector3(0, 0.2, 0.078), Vector3(0.11, 0.025, 0.01), Color(0.03, 0.08, 0.14))
			l.box(Vector3(0.18, 0.1, 0.04), Vector3(0.03, 0.42, 0.02), WeaponDefs.STEEL)
			l.box(Vector3(0.18, 0.0, 0.04), Vector3(0.12, 0.03, 0.03), WeaponDefs.BRASS)
		"imp":
			var o := Color(0.72, 0.42, 0.14)
			l.prism(Vector3(0, -0.16, 0), Vector3(0, 0.07, 0), 0.09, 0.08, 6, o)
			l.prism(Vector3(0, 0.07, 0), Vector3(0, 0.22, 0), 0.1, 0.08, 6, o)
			l.prism(Vector3(-0.09, 0.16, 0), Vector3(-0.22, 0.24, 0), 0.04, 0.0, 4, o.darkened(0.2))
			l.prism(Vector3(0.09, 0.16, 0), Vector3(0.22, 0.24, 0), 0.04, 0.0, 4, o.darkened(0.2))
			l.prism(Vector3(0.16, -0.14, -0.04), Vector3(0.16, 0.03, -0.04), 0.09, 0.05, 6, Color(0.62, 0.5, 0.3))
			l.box(Vector3(0.035, 0.16, 0.085), Vector3(0.025, 0.02, 0.01), Color(1, 0.95, 0.3))
			l.box(Vector3(-0.035, 0.16, 0.085), Vector3(0.025, 0.02, 0.01), Color(1, 0.95, 0.3))
		"bell_spirit":
			var b := WeaponDefs.BRASS.lightened(0.15)
			l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.05, 0), 0.2, 0.1, 9, b)
			l.prism(Vector3(0, 0.05, 0), Vector3(0, 0.19, 0), 0.1, 0.03, 9, b)
			l.prism(Vector3(0, 0.19, 0), Vector3(0, 0.25, 0), 0.03, 0.03, 5, b.darkened(0.3))
			l.prism(Vector3(0, -0.26, 0), Vector3(0, -0.2, 0), 0.03, 0.04, 5, Color(0.25, 0.2, 0.15))
			l.box(Vector3(0.05, -0.02, 0.15), Vector3(0.025, 0.04, 0.01), Color(0.1, 0.05, 0.03))
			l.box(Vector3(-0.05, -0.02, 0.15), Vector3(0.025, 0.04, 0.01), Color(0.1, 0.05, 0.03))
		"rat":
			var r := Color(0.33, 0.36, 0.28)
			l.prism(Vector3(0, -0.05, -0.2), Vector3(0, 0.0, 0.1), 0.06, 0.12, 7, r)
			l.prism(Vector3(0, 0.0, 0.1), Vector3(0, -0.02, 0.3), 0.09, 0.0, 6, r.lightened(0.1))
			l.prism(Vector3(0, -0.05, -0.2), Vector3(0, -0.08, -0.5), 0.016, 0.004, 4, Color(0.6, 0.45, 0.45))
			l.box(Vector3(0.06, 0.09, 0.1), Vector3(0.07, 0.09, 0.012), Color(0.6, 0.45, 0.45))
			l.box(Vector3(-0.06, 0.09, 0.1), Vector3(0.07, 0.09, 0.012), Color(0.6, 0.45, 0.45))
			l.box(Vector3(0.04, 0.03, 0.2), Vector3(0.02, 0.02, 0.01), Color(0.6, 1.0, 0.25))
			l.box(Vector3(-0.04, 0.03, 0.2), Vector3(0.02, 0.02, 0.01), Color(0.6, 1.0, 0.25))
		_:
			# A potion bottle, tinted per potion.
			var col: Color = ALL[id]["color"]
			l.prism(Vector3(0, -0.22, 0), Vector3(0, 0.06, 0), 0.15, 0.15, 7, col)
			l.prism(Vector3(0, 0.06, 0), Vector3(0, 0.16, 0), 0.15, 0.05, 7, col.lightened(0.15))
			l.prism(Vector3(0, 0.16, 0), Vector3(0, 0.24, 0), 0.05, 0.05, 6, Color(0.85, 0.9, 0.95))
			l.prism(Vector3(0, 0.24, 0), Vector3(0, 0.3, 0), 0.055, 0.055, 6, Color(0.5, 0.33, 0.18))
	var m := l.commit()
	_meshes[id] = m
	return m
