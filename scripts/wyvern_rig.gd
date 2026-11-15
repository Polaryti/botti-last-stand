class_name WyvernRig
extends Node3D
## A wyvern, or the War Wyvern, as a body that can be posed (MesenllaModels builds it; Zombie moves it).
## Facing +Z. Its nodes:
##   Body             the whole animal, at its size (the War Wyvern is bigger), pitching and rolling
##     Neck > Head > Jaw   the neck bends, the head looks, the jaw opens to roar and breathe
##     Tail > Tail2 > Tail3   a tail in three joints that waves
##     LegL, LegR      hind legs: tucked in flight, dangling in a hover, thrown forward to strike
##     WingL, WingR    shoulders, each with its "Elbow": the inner wing on the shoulder, the hand and its
##                     fingers on the elbow, so a wing can fold, beat, glide and sweep back for a dive
##     Seat0, Seat1    (the War Wyvern) where its two riders sit, in the saddle on its back
## Each wyvern is one of three kinds, Fire, Ice or Storm (set_element): its hide, its wings, the spines
## and crystals along its back and tail, the glow in its eyes and throat, the breath it breathes and
## what drifts off it as it flies are its element's.
##
## drive() is given what the creature is doing and moves it: cruising on slow beats with glides between
## them, banking into turns; hanging in the air beating hard, rearing and roaring (before it dives); the
## dive itself, wings swept back and folded, head stretched down the line of its fall, talons thrown at the
## end; climbing away on strong beats; and its breath: drawing back with its throat glowing, then the head
## thrown forward with the jaw wide and its element pouring from it.

const ELEMENTS := ["fire", "ice", "storm"]
const NAMES := {"fire": "Fire", "ice": "Ice", "storm": "Storm"}
const BREATH_INHALE := 0.85 # seconds of drawing breath before it pours out (MesenllaMind.BREATH_TELL is 1.2)
const SEATS := [Vector3(0, 0.18, 0.34), Vector3(0, 0.18, -0.06)] # the War Wyvern's riders' feet, astride its saddle, in its body's space

## Hide, darker hide, belly, wing membrane, horn and claw, the glow of its eyes and throat, the glow of its
## spines (or crystals, or sparks), and what its breath and aura look like.
const LOOKS := {
	"fire": {"hide": Color(0.46, 0.12, 0.07), "dark": Color(0.24, 0.06, 0.05), "belly": Color(0.86, 0.56, 0.24), "membrane": Color(0.64, 0.22, 0.08),
		"horn": Color(0.2, 0.15, 0.13), "eye": Color(1.0, 0.78, 0.22), "glow": Color(1.0, 0.48, 0.1),
		"breath": [Color(1.0, 0.9, 0.45), Color(1.0, 0.45, 0.08), Color(0.55, 0.08, 0.02, 0.7), Color(0.12, 0.08, 0.08, 0.0)]},
	"ice": {"hide": Color(0.6, 0.74, 0.86), "dark": Color(0.36, 0.48, 0.62), "belly": Color(0.9, 0.95, 0.99), "membrane": Color(0.56, 0.78, 0.94),
		"horn": Color(0.86, 0.92, 0.98), "eye": Color(0.55, 0.96, 1.0), "glow": Color(0.62, 0.94, 1.0),
		"breath": [Color(1.0, 1.0, 1.0), Color(0.72, 0.94, 1.0), Color(0.45, 0.75, 1.0, 0.6), Color(0.85, 0.95, 1.0, 0.0)]},
	"storm": {"hide": Color(0.2, 0.22, 0.34), "dark": Color(0.11, 0.12, 0.2), "belly": Color(0.5, 0.53, 0.64), "membrane": Color(0.24, 0.27, 0.46),
		"horn": Color(0.55, 0.56, 0.62), "eye": Color(0.92, 0.96, 1.0), "glow": Color(0.8, 0.9, 1.0),
		"breath": [Color(1.0, 1.0, 0.85), Color(0.75, 0.88, 1.0), Color(0.45, 0.55, 1.0, 0.7), Color(0.3, 0.3, 0.6, 0.0)]},
}
const STEEL := Color(0.52, 0.54, 0.6)
const STEEL_DARK := Color(0.3, 0.31, 0.36)
const GOLD := Color(0.95, 0.72, 0.22)
const BANNER_RED := Color(0.62, 0.12, 0.1)
const LEATHER := Color(0.36, 0.22, 0.13)
const BONE := Color(0.9, 0.88, 0.8)

static var _meshes := {}

var armoured := false
var element := "fire"
var body: Node3D
var neck: Node3D
var head: Node3D
var jaw: Node3D
var tails: Array[Node3D] = []
var legs: Array[Node3D] = [] # left, right
var shoulders: Array[Node3D] = [] # left, right
var elbows: Array[Node3D] = []
var breath: CPUParticles3D
var aura: CPUParticles3D
var _parts := {} # name: the MeshInstance3D whose mesh changes with the element
var _beat := 0.0
var _cruise := 0.0 # where it is in its beats-then-glide pattern
var _env := {} # the slow parts of the pose, eased from frame to frame
var _last_pos := Vector3.INF
var _last_yaw := 0.0
var _vel := Vector3.ZERO
var _turn := 0.0
var _sparks := 0.0


func _init(is_war := false) -> void:
	name = "Wyvern"
	armoured = is_war
	_build()
	set_element("fire")


## The size of its body: the War Wyvern is twice a wyvern's.
func size() -> float:
	return 2.0 if armoured else 1.0


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var l := LowPoly.new()
		build.call(l)
		_meshes[key] = l.commit()
	return _meshes[key]


func _pivot(parent: Node3D, called: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = called
	n.position = at
	parent.add_child(n)
	return n


func _part(parent: Node3D, called: String, glows := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = called
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glows:
		mi.material_override = MesenllaModels.glow_material()
	parent.add_child(mi)
	_parts[called] = mi
	return mi


func _build() -> void:
	body = _pivot(self, "Body", Vector3.ZERO)
	body.scale = Vector3.ONE * size()
	_part(body, "Torso")
	_part(body, "TorsoGlow", true)
	if armoured:
		_part(body, "Barding")
		_part(body, "BardingGold")
		for i in SEATS.size():
			_pivot(body, "Seat%d" % i, SEATS[i])
	neck = _pivot(body, "Neck", Vector3(0, 0.12, 0.5))
	_part(neck, "NeckMesh")
	_part(neck, "NeckGlow", true)
	head = _pivot(neck, "Head", Vector3(0, 0.26, 0.4))
	_part(head, "HeadMesh")
	_part(head, "Eyes", true)
	jaw = _pivot(head, "Jaw", Vector3(0, -0.07, 0.06))
	_part(jaw, "JawMesh")
	_part(jaw, "Maw", true)
	var at := Vector3(0, 0.0, -0.62)
	var parent := body
	for i in 3:
		var t := _pivot(parent, "Tail" if i == 0 else "Tail%d" % (i + 1), at)
		_part(t, "TailMesh%d" % i)
		_part(t, "TailGlow%d" % i, true)
		tails.append(t)
		parent = t
		at = Vector3(0, -0.03, -[0.7, 0.62, 0.5][i])
	for side: float in [-1.0, 1.0]:
		var leg := _pivot(body, "LegL" if side < 0 else "LegR", Vector3(side * 0.19, -0.12, -0.22))
		_part(leg, "LegMesh" + ("L" if side < 0 else "R"))
		legs.append(leg)
		var shoulder := _pivot(body, "WingL" if side < 0 else "WingR", Vector3(side * 0.24, 0.17, 0.26))
		_part(shoulder, "Arm" + ("L" if side < 0 else "R"))
		var elbow := _pivot(shoulder, "Elbow", Vector3(side * 0.72, 0.08, 0.04))
		_part(elbow, "Hand" + ("L" if side < 0 else "R"))
		_part(elbow, "HandGlow" + ("L" if side < 0 else "R"), true)
		shoulders.append(shoulder)
		elbows.append(elbow)
	breath = _particles(head, Vector3(0, -0.06, 0.52), 96)
	breath.name = "Breath"
	aura = _particles(body, Vector3.ZERO, 14)
	aura.name = "Aura"


func _ready() -> void:
	aura.emitting = true # (only once it is in the world: an emitter needs to know where it is)


func _particles(parent: Node3D, at: Vector3, count: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.local_coords = false
	p.emitting = false
	p.position = at
	p.mesh = puff_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


## A soft round puff that always faces the camera, coloured by the particle: breath and drifting motes.
static var _puff: QuadMesh


static func puff_mesh() -> QuadMesh:
	if _puff == null:
		var soft := GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(0.5, 0.0)
		soft.width = 64
		soft.height = 64
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		soft.gradient = g
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = soft
		m.disable_fog = true
		m.no_depth_test = false
		_puff = QuadMesh.new()
		_puff.size = Vector2(0.7, 0.7)
		_puff.material = m
	return _puff


## Fire, Ice or Storm: its looks, its breath and its aura.
func set_element(e: String) -> void:
	element = e if LOOKS.has(e) else "fire"
	var key := "%s_%s" % ["war" if armoured else "wyvern", element]
	var look: Dictionary = LOOKS[element]
	var war := armoured
	var el := element
	(_parts["Torso"] as MeshInstance3D).mesh = _mesh(key + "_torso", func(l: LowPoly) -> void: _torso(l, look, war))
	(_parts["TorsoGlow"] as MeshInstance3D).mesh = _mesh(key + "_torso_glow", func(l: LowPoly) -> void: _spines(l, look, el, Vector3(0, 0.3, -0.55), Vector3(0, 0.36, 0.45), 6, 0.2, war))
	if armoured:
		(_parts["Barding"] as MeshInstance3D).mesh = _mesh("war_barding", func(l: LowPoly) -> void: _barding(l))
		(_parts["BardingGold"] as MeshInstance3D).mesh = _mesh("war_barding_gold", func(l: LowPoly) -> void: _barding_gold(l))
	(_parts["NeckMesh"] as MeshInstance3D).mesh = _mesh(key + "_neck", func(l: LowPoly) -> void: _neck(l, look, war))
	(_parts["NeckGlow"] as MeshInstance3D).mesh = _mesh(key + "_neck_glow", func(l: LowPoly) -> void: _spines(l, look, el, Vector3(0, 0.15, 0.0), Vector3(0, 0.33, 0.3), 3, 0.15, war))
	(_parts["HeadMesh"] as MeshInstance3D).mesh = _mesh(key + "_head", func(l: LowPoly) -> void: _head(l, look, el, war))
	(_parts["Eyes"] as MeshInstance3D).mesh = _mesh(key + "_eyes", func(l: LowPoly) -> void:
		for x: float in [-1.0, 1.0]:
			l.box(Vector3(x * 0.1, 0.1, 0.17), Vector3(0.035, 0.04, 0.07), look["eye"]))
	(_parts["JawMesh"] as MeshInstance3D).mesh = _mesh(key + "_jaw", func(l: LowPoly) -> void: _jaw(l, look))
	(_parts["Maw"] as MeshInstance3D).mesh = _mesh(key + "_maw", func(l: LowPoly) -> void:
		l.box(Vector3(0, 0.035, 0.2), Vector3(0.09, 0.02, 0.3), look["glow"]))
	for i in 3:
		var seg := i
		(_parts["TailMesh%d" % i] as MeshInstance3D).mesh = _mesh(key + "_tail%d" % i, func(l: LowPoly) -> void: _tail(l, look, el, seg, war))
		(_parts["TailGlow%d" % i] as MeshInstance3D).mesh = _mesh(key + "_tail_glow%d" % i, func(l: LowPoly) -> void:
			var length: float = [0.7, 0.62, 0.5][seg]
			_spines(l, look, el, Vector3(0, 0.1 - seg * 0.03, -0.08), Vector3(0, 0.08 - seg * 0.03, -length + 0.1), 3 - (1 if seg == 2 else 0), 0.12 - seg * 0.025, false)
			if seg == 2:
				_tail_tip(l, look, el, length))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var suffix := "L" if i == 0 else "R"
		(_parts["LegMesh" + suffix] as MeshInstance3D).mesh = _mesh(key + "_leg" + suffix, func(l: LowPoly) -> void: _leg(l, look, side))
		(_parts["Arm" + suffix] as MeshInstance3D).mesh = _mesh(key + "_arm" + suffix, func(l: LowPoly) -> void: _arm(l, look, side, war))
		(_parts["Hand" + suffix] as MeshInstance3D).mesh = _mesh(key + "_hand" + suffix, func(l: LowPoly) -> void: _hand(l, look, side, war))
		(_parts["HandGlow" + suffix] as MeshInstance3D).mesh = _mesh(key + "_hand_glow" + suffix, func(l: LowPoly) -> void: _hand_glow(l, look, el, side))
	_style_particles()
	for mi: MeshInstance3D in _parts.values():
		# Its own look comes back after a hit's flash (Zombie._restore_materials).
		mi.set_meta("own_material", mi.material_override)


func _style_particles() -> void:
	var look: Dictionary = LOOKS[element]
	var ramp := Gradient.new()
	var cols: Array = look["breath"]
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	ramp.colors = PackedColorArray(cols)
	breath.color_ramp = ramp
	breath.lifetime = 0.75
	breath.direction = Vector3(0, 0, 1)
	breath.spread = 17.0 if element != "storm" else 10.0
	breath.initial_velocity_min = 10.0 * size()
	breath.initial_velocity_max = 14.0 * size()
	breath.gravity = Vector3(0, 2.5, 0) if element == "fire" else Vector3(0, -6.0, 0) if element == "ice" else Vector3.ZERO
	breath.damping_min = 6.0 * size()
	breath.damping_max = 9.0 * size()
	var grow := Curve.new()
	grow.max_value = 4.0
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 3.2 if element == "fire" else 2.2))
	breath.scale_amount_curve = grow
	breath.scale_amount_min = 1.1 * size()
	breath.scale_amount_max = 1.7 * size()
	breath.angular_velocity_min = -180.0
	breath.angular_velocity_max = 180.0
	var aura_ramp := Gradient.new()
	aura_ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var glow: Color = look["glow"]
	aura_ramp.colors = PackedColorArray([Color(glow, 0.0), Color(glow, 0.85), Color(glow, 0.0)])
	aura.color_ramp = aura_ramp
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	aura.emission_box_extents = Vector3(1.6, 0.3, 0.8) # (in the body's space, which is already its size)
	aura.lifetime = 1.4
	# Embers rise off a Fire wyvern, snow falls from an Ice one, sparks jump round a Storm one.
	aura.gravity = Vector3(0, 1.8, 0) if element == "fire" else Vector3(0, -2.2, 0) if element == "ice" else Vector3.ZERO
	aura.initial_velocity_min = 0.2 if element != "storm" else 2.5
	aura.initial_velocity_max = 0.6 if element != "storm" else 4.0
	aura.spread = 180.0
	aura.scale_amount_min = 0.2 * size()
	aura.scale_amount_max = 0.38 * size()


# --- Bodies ----------------------------------------------------------------------------

static func _torso(l: LowPoly, look: Dictionary, war: bool) -> void:
	var hide: Color = look["hide"]
	var dark: Color = look["dark"]
	var belly: Color = look["belly"]
	l.prism(Vector3(0, 0.0, -0.68), Vector3(0, 0.05, 0.1), 0.2, 0.33, 9, hide) # haunch to ribs
	l.prism(Vector3(0, 0.05, 0.1), Vector3(0, 0.12, 0.56), 0.33, 0.24, 9, hide.lightened(0.04)) # the deep chest
	l.prism(Vector3(0, 0.2, -0.3), Vector3(0, 0.26, 0.4), 0.16, 0.18, 7, dark) # the ridge of its back
	for side: float in [-1.0, 1.0]:
		l.prism(Vector3(side * 0.2, 0.14, 0.3), Vector3(side * 0.3, 0.2, 0.24), 0.14, 0.1, 6, hide) # where the wings join
		l.prism(Vector3(side * 0.15, -0.08, -0.25), Vector3(side * 0.19, -0.12, -0.22), 0.16, 0.13, 6, dark) # haunches
	# Belly plates, overlapping like a snake's.
	for i in 8:
		var z := -0.55 + i * 0.14
		l.box(Vector3(0, -0.24 - 0.02 * sin(i * 0.4), z), Vector3(0.36 - absf(i - 4.0) * 0.03, 0.06, 0.13), belly.darkened(0.05 * (i % 2)))
	# Scales: rows of small plates down each flank.
	for side: float in [-1.0, 1.0]:
		for i in 6:
			l.box(Vector3(side * 0.28, 0.02 + (i % 2) * 0.08, -0.4 + i * 0.15), Vector3(0.04, 0.08, 0.12), dark.lightened(0.04 * (i % 2)), Vector3(0, 0, side * 20.0))
	if war:
		# Old wounds: pale scars across its flank.
		for k in 3:
			l.box(Vector3(0.31, 0.06 + k * 0.05, -0.1 + k * 0.08), Vector3(0.012, 0.025, 0.26), BONE.darkened(0.25), Vector3(30, 0, 0))


## Spines along the back from a to b, or crystals of ice, or blades crackling with lightning.
static func _spines(l: LowPoly, look: Dictionary, element: String, a: Vector3, b: Vector3, count: int, tall: float, war: bool) -> void:
	var glow: Color = look["glow"]
	for i in count:
		var t := (i + 0.5) / count
		var at := a.lerp(b, t)
		var h := tall * (1.0 - absf(t - 0.55) * 0.6) * (1.25 if war else 1.0)
		match element:
			"ice":
				l.prism(at, at + Vector3(0, h * 1.2, -h * 0.35), 0.05, 0.0, 4, glow)
				l.prism(at + Vector3(0.03, 0, 0.02), at + Vector3(0.09, h * 0.7, -h * 0.1), 0.03, 0.0, 4, glow.lightened(0.2))
			"storm":
				l.prism(at, at + Vector3(0, h, -h * 0.5), 0.045, 0.0, 4, look["horn"].lerp(glow, 0.5))
				l.box(at + Vector3(0, h * 0.75, -h * 0.38), Vector3(0.02, 0.05, 0.05), glow) # the spark at its tip
			_:
				l.prism(at, at + Vector3(0, h, -h * 0.6), 0.055, 0.0, 4, glow.darkened(0.15)) # glowing like embers


static func _neck(l: LowPoly, look: Dictionary, war: bool) -> void:
	var hide: Color = look["hide"]
	l.prism(Vector3(0, 0.0, -0.05), Vector3(0, 0.14, 0.22), 0.2, 0.15, 8, hide)
	l.prism(Vector3(0, 0.14, 0.22), Vector3(0, 0.26, 0.42), 0.15, 0.12, 8, hide.lightened(0.03))
	for i in 4:
		var t := i / 3.0
		l.box(Vector3(0, -0.12 + t * 0.24, 0.02 + t * 0.36), Vector3(0.2 - t * 0.06, 0.05, 0.1), look["belly"], Vector3(-35, 0, 0))
	if war:
		# Plates of barding down the neck, one over the next.
		for i in 3:
			var t := i / 2.0
			l.box(Vector3(0, 0.15 + t * 0.12, 0.02 + t * 0.3), Vector3(0.32 - t * 0.06, 0.06, 0.18), STEEL.darkened(0.08 * (i % 2)), Vector3(-25, 0, 0))
			l.box(Vector3(0, 0.19 + t * 0.12, 0.02 + t * 0.3), Vector3(0.04, 0.05, 0.14), GOLD, Vector3(-25, 0, 0))


static func _head(l: LowPoly, look: Dictionary, element: String, war: bool) -> void:
	var hide: Color = look["hide"]
	var horn: Color = look["horn"]
	l.prism(Vector3(0, 0.04, -0.08), Vector3(0, 0.05, 0.22), 0.14, 0.12, 8, hide) # the skull
	l.prism(Vector3(0, 0.02, 0.22), Vector3(0, -0.01, 0.48), 0.1, 0.055, 7, hide.lightened(0.05)) # the snout
	l.box(Vector3(0, 0.13, 0.12), Vector3(0.22, 0.04, 0.16), look["dark"]) # the brow
	for x: float in [-1.0, 1.0]:
		l.box(Vector3(x * 0.03, 0.04, 0.47), Vector3(0.02, 0.02, 0.02), Color(0.05, 0.03, 0.03)) # nostrils
		# Swept-back horns, two to a side, and a frill along the jaw.
		l.prism(Vector3(x * 0.08, 0.14, 0.02), Vector3(x * 0.14, 0.28, -0.22), 0.04, 0.025, 5, horn)
		l.prism(Vector3(x * 0.14, 0.28, -0.22), Vector3(x * 0.15, 0.3, -0.42), 0.025, 0.0, 4, horn.lightened(0.1))
		l.prism(Vector3(x * 0.11, 0.08, -0.04), Vector3(x * 0.22, 0.12, -0.24), 0.025, 0.0, 4, horn)
		for k in 3:
			l.prism(Vector3(x * 0.12, -0.04, 0.12 - k * 0.09), Vector3(x * 0.2, -0.06, 0.06 - k * 0.11), 0.02, 0.0, 3, look["dark"])
		# The upper teeth.
		for k in 4:
			l.prism(Vector3(x * 0.05, -0.04, 0.24 + k * 0.06), Vector3(x * 0.05, -0.09, 0.25 + k * 0.06), 0.012, 0.0, 3, BONE)
	match element:
		"ice":
			l.prism(Vector3(0, 0.14, 0.2), Vector3(0, 0.26, 0.05), 0.03, 0.0, 4, look["glow"]) # a crystal on its brow
		"storm":
			l.prism(Vector3(0, 0.14, 0.14), Vector3(0, 0.2, -0.12), 0.025, 0.0, 4, horn)
	if war:
		# A steel chamfron with a spike, riveted in gold.
		l.box(Vector3(0, 0.12, 0.25), Vector3(0.18, 0.05, 0.3), STEEL)
		l.prism(Vector3(0, 0.15, 0.3), Vector3(0, 0.3, 0.42), 0.035, 0.0, 4, STEEL.lightened(0.15))
		for x: float in [-1.0, 1.0]:
			l.box(Vector3(x * 0.09, 0.12, 0.25), Vector3(0.02, 0.06, 0.3), GOLD)


static func _jaw(l: LowPoly, look: Dictionary) -> void:
	l.prism(Vector3(0, 0.0, -0.02), Vector3(0, -0.02, 0.42), 0.07, 0.035, 6, look["hide"].darkened(0.08))
	l.box(Vector3(0, -0.05, 0.18), Vector3(0.1, 0.03, 0.3), look["belly"].darkened(0.1))
	for x: float in [-1.0, 1.0]:
		for k in 3:
			l.prism(Vector3(x * 0.04, 0.02, 0.24 + k * 0.06), Vector3(x * 0.04, 0.07, 0.25 + k * 0.06), 0.011, 0.0, 3, BONE)


static func _tail(l: LowPoly, look: Dictionary, element: String, seg: int, war: bool) -> void:
	var length: float = [0.7, 0.62, 0.5][seg]
	var r: Array = [[0.2, 0.13], [0.13, 0.08], [0.08, 0.035]][seg]
	l.prism(Vector3.ZERO, Vector3(0, -0.03, -length), r[0], r[1], 7, look["hide"].darkened(0.04 * seg))
	l.box(Vector3(0, -r[0] * 0.75, -length * 0.5), Vector3(r[0] * 1.1, 0.04, length * 0.9), look["belly"].darkened(0.08))
	if war and seg == 0:
		for k in 2:
			l.prism(Vector3(0, -0.01, -0.2 - k * 0.3), Vector3(0, -0.02, -0.28 - k * 0.3), float(r[0]) * 1.08, float(r[0]) * 1.0, 8, STEEL_DARK)


## The end of the tail: a barbed blade, a shard of ice, or a fork that crackles.
static func _tail_tip(l: LowPoly, look: Dictionary, element: String, length: float) -> void:
	var end := Vector3(0, -0.03, -length)
	match element:
		"ice":
			l.prism(end, end + Vector3(0, 0.0, -0.32), 0.07, 0.0, 4, look["glow"])
			for x: float in [-1.0, 1.0]:
				l.prism(end, end + Vector3(x * 0.12, 0.04, -0.18), 0.035, 0.0, 4, look["glow"].lightened(0.2))
		"storm":
			for x: float in [-1.0, 1.0]:
				l.prism(end, end + Vector3(x * 0.1, 0.0, -0.18), 0.03, 0.02, 4, look["horn"])
				l.prism(end + Vector3(x * 0.1, 0.0, -0.18), end + Vector3(x * 0.03, 0.0, -0.32), 0.02, 0.0, 4, look["glow"])
		_:
			l.prism(end, end + Vector3(0, 0.05, -0.3), 0.09, 0.0, 4, look["glow"].darkened(0.2))
			for x: float in [-1.0, 1.0]:
				l.prism(end + Vector3(0, 0, -0.08), end + Vector3(x * 0.14, 0.06, -0.12), 0.04, 0.0, 4, look["glow"].darkened(0.3))


static func _leg(l: LowPoly, look: Dictionary, side: float) -> void:
	var hide: Color = look["hide"]
	l.prism(Vector3.ZERO, Vector3(side * 0.02, -0.24, 0.08), 0.1, 0.07, 6, hide.darkened(0.06)) # thigh
	l.prism(Vector3(side * 0.02, -0.24, 0.08), Vector3(side * 0.02, -0.4, -0.04), 0.06, 0.045, 6, look["dark"]) # shin
	for k in 3:
		var a := (k - 1) * 0.35
		var toe := Vector3(side * 0.02 + sin(a) * 0.1, -0.44, -0.04 + cos(a) * 0.12)
		l.prism(Vector3(side * 0.02, -0.41, -0.04), toe, 0.03, 0.02, 4, look["dark"])
		l.prism(toe, toe + Vector3(sin(a) * 0.03, -0.04, cos(a) * 0.06), 0.02, 0.0, 4, BONE) # talons
	l.prism(Vector3(side * 0.02, -0.41, -0.04), Vector3(side * 0.02, -0.45, -0.16), 0.025, 0.0, 4, BONE)


## The inner wing: the arm from shoulder to elbow, and the stretch of skin from it to the flank.
static func _arm(l: LowPoly, look: Dictionary, side: float, war: bool) -> void:
	l.base = Transform3D(Basis.from_scale(Vector3(side, 1, 1)), Vector3.ZERO)
	var membrane: Color = look["membrane"]
	l.prism(Vector3.ZERO, Vector3(0.72, 0.08, 0.04), 0.075, 0.055, 6, look["hide"]) # the arm
	l.gable(Vector3(0.0, 0.0, 0.0), Vector3(0.72, 0.08, 0.04), Vector3(0.66, 0.0, -0.62), membrane)
	l.gable(Vector3(0.0, 0.0, 0.0), Vector3(0.66, 0.0, -0.62), Vector3(0.02, -0.04, -0.62), membrane.darkened(0.08))
	l.gable(Vector3(0.02, -0.04, -0.62), Vector3(0.66, 0.0, -0.62), Vector3(0.34, -0.03, -0.74), membrane.darkened(0.14)) # the scalloped edge
	if war:
		l.box(Vector3(0.22, 0.07, 0.03), Vector3(0.3, 0.05, 0.12), STEEL)
		l.prism(Vector3(0.1, 0.09, 0.03), Vector3(0.12, 0.2, 0.0), 0.03, 0.0, 4, STEEL.lightened(0.1))


## The hand: the forearm to the wrist with its hooked thumb, three long fingers, and the skin between
## them, to a scalloped edge.
static func _hand(l: LowPoly, look: Dictionary, side: float, war: bool) -> void:
	l.base = Transform3D(Basis.from_scale(Vector3(side, 1, 1)), Vector3.ZERO)
	var bone: Color = look["hide"].darkened(0.1)
	var membrane: Color = look["membrane"]
	var wrist := Vector3(0.62, -0.03, -0.08)
	var tips := [Vector3(1.55, -0.04, -0.3), Vector3(1.32, -0.05, -0.78), Vector3(0.86, -0.05, -0.98)]
	l.prism(Vector3.ZERO, wrist, 0.055, 0.045, 6, look["hide"])
	l.prism(wrist, wrist + Vector3(0.06, 0.12, 0.1), 0.035, 0.0, 4, BONE if not war else STEEL.lightened(0.1)) # the thumb claw
	for tip: Vector3 in tips:
		l.prism(wrist, tip, 0.032, 0.012, 4, bone)
	var trailing := Vector3(-0.06, -0.03, -0.62) # where the inner wing's edge meets this one
	l.gable(Vector3.ZERO, wrist, trailing, membrane.darkened(0.05))
	l.gable(wrist, tips[2], trailing, membrane.darkened(0.12))
	l.gable(wrist, tips[0], tips[1], membrane)
	l.gable(wrist, tips[1], tips[2], membrane.darkened(0.06))
	# Scallops between the fingers.
	l.gable(tips[0], tips[1], (tips[0] + tips[1]) * 0.5 + Vector3(-0.1, 0, -0.08), membrane.darkened(0.15))
	l.gable(tips[1], tips[2], (tips[1] + tips[2]) * 0.5 + Vector3(-0.06, 0, -0.1), membrane.darkened(0.15))


## Its element in the skin of its wings: veins of ice, of lightning, or of embers.
static func _hand_glow(l: LowPoly, look: Dictionary, element: String, side: float) -> void:
	l.base = Transform3D(Basis.from_scale(Vector3(side, 1, 1)), Vector3.ZERO)
	var glow: Color = look["glow"]
	var wrist := Vector3(0.62, -0.02, -0.08)
	var pts: Array
	match element:
		"storm":
			pts = [wrist, Vector3(0.85, -0.02, -0.3), Vector3(0.78, -0.02, -0.42), Vector3(1.05, -0.02, -0.6), Vector3(0.98, -0.02, -0.7)]
		"ice":
			pts = [wrist, Vector3(0.9, -0.02, -0.42), Vector3(1.05, -0.02, -0.66)]
		_:
			pts = [wrist + Vector3(0.1, 0, -0.05), Vector3(1.1, -0.02, -0.5), Vector3(1.15, -0.02, -0.62)]
	for i in pts.size() - 1:
		l.prism(pts[i], pts[i + 1], 0.012, 0.012, 3, glow)


static func _barding(l: LowPoly) -> void:
	# A war saddle for two, on a caparison of the War's red, and a breastplate.
	l.box(Vector3(0, 0.33, 0.14), Vector3(0.5, 0.06, 0.72), LEATHER)
	for z: float in [0.34, -0.06]:
		l.box(Vector3(0, 0.38, z - 0.1), Vector3(0.32, 0.12, 0.06), LEATHER.darkened(0.2)) # the cantle behind each seat
		l.box(Vector3(0, 0.37, z + 0.12), Vector3(0.2, 0.08, 0.05), LEATHER.darkened(0.1)) # the pommel
	for side: float in [-1.0, 1.0]:
		l.box(Vector3(side * 0.31, 0.06, 0.12), Vector3(0.025, 0.46, 0.8), BANNER_RED)
		l.box(Vector3(side * 0.32, -0.16, 0.12), Vector3(0.025, 0.04, 0.8), GOLD.darkened(0.1))
		l.box(Vector3(side * 0.32, 0.12, 0.12), Vector3(0.03, 0.1, 0.14), GOLD) # the War's sign
	l.box(Vector3(0, 0.06, 0.6), Vector3(0.44, 0.3, 0.08), STEEL, Vector3(-20, 0, 0)) # breastplate
	l.prism(Vector3(0, 0.08, 0.64), Vector3(0, 0.08, 0.82), 0.05, 0.0, 4, STEEL.lightened(0.15))
	# The banner pole behind the saddle and the War's banner on it.
	l.prism(Vector3(0, 0.34, -0.22), Vector3(0, 1.5, -0.3), 0.022, 0.022, 4, Color(0.35, 0.24, 0.14))
	l.box(Vector3(0, 1.25, -0.56), Vector3(0.02, 0.5, 0.52), BANNER_RED)
	l.prism(Vector3(0, 1.52, -0.3), Vector3(0, 1.6, -0.3), 0.04, 0.0, 4, GOLD)
	# Chains from the saddle to the collar.
	for side: float in [-1.0, 1.0]:
		for k in 4:
			l.box(Vector3(side * 0.24, 0.3 - k * 0.02, 0.44 + k * 0.07), Vector3(0.025, 0.025, 0.05), STEEL_DARK, Vector3(0, 0, 45 * (k % 2)))


static func _barding_gold(l: LowPoly) -> void:
	l.box(Vector3(0, 1.25, -0.56), Vector3(0.03, 0.15, 0.2), GOLD) # the device on the banner
	l.box(Vector3(0, 0.22, 0.6), Vector3(0.3, 0.04, 0.09), GOLD, Vector3(-20, 0, 0))


# --- Movement -----------------------------------------------------------------------------

## What it is doing, from what the creature shows (Zombie._current_anim and its warning) and how it is
## moving; on the host the dive and the climb after it are known, on other phones they are read from
## the way it moves.
func drive(z: Zombie, delta: float) -> void:
	if delta <= 0.0:
		return
	var here := z.global_position
	if _last_pos != Vector3.INF:
		_vel = _vel.lerp((here - _last_pos) / delta, minf(1.0, delta * 8.0))
		_turn = lerpf(_turn, wrapf(z.rotation.y - _last_yaw, -PI, PI) / delta, minf(1.0, delta * 5.0))
	_last_pos = here
	_last_yaw = z.rotation.y
	var state := z._current_anim
	var act := float(z._visual.get_meta("act_t", 0.0))
	var warning := z.is_warning()
	var above := here.y - z.world.ground_at(here)
	var breathing := state == "m_breath"
	var diving := (z._dive > 0.0) if not z.puppet else (warning and not breathing and _vel.y < -2.5)
	var hanging := warning and not breathing and not diving
	var climbing := (z._recover > 0.0) if not z.puppet else (not warning and _vel.y > 1.2)
	var mode := "breath" if breathing else "dive" if diving else "hang" if hanging else "climb" if climbing else "cruise"
	pose(mode, delta, act, above, z.world.now + float(z.net_id) * 0.41)


## Moves it on by delta in this way of being: "cruise", "hang", "dive", "climb" or "breath". act: how long
## it has been breathing; above: how high it is over the ground. Tests and the Codex call this directly.
func pose(mode: String, delta: float, act := 0.0, above := 10.0, now := 0.0) -> void:
	var war := armoured
	var flap_rate := 0.95 if war else 1.25 # beats a second, cruising
	var want := {"amp": 0.75, "lift": 0.12, "sweep": 0.1, "fold": 0.0, "pitch": clampf(-_vel.y * 0.05, -0.3, 0.3), "neck": 0.0, "head": 0.0,
		"jaw": 0.0, "legs": 1.15, "tail": 0.05, "chest": 1.0, "rate": flap_rate, "shake": 0.0}
	var breathing := false
	match mode:
		"cruise":
			# Some beats, then a glide on still wings; the beats ease into it and out of it.
			var beats := 3.0 / flap_rate
			var glide := 1.6 if not war else 2.2
			_cruise = fmod(_cruise + delta, beats + glide)
			var still := smoothstep(beats - 0.3, beats + 0.1, _cruise) * (1.0 - smoothstep(beats + glide - 0.4, beats + glide, _cruise))
			want["amp"] = lerpf(0.72, 0.06, still)
			want["lift"] = lerpf(0.12, 0.18, still)
			want["neck"] = sin(now * 0.8) * 0.08
		"hang":
			# Hanging in the air before the dive: rearing, beating hard and fast, roaring with its head up.
			want = {"amp": 1.0, "lift": 0.25, "sweep": -0.1, "fold": 0.0, "pitch": -0.55, "neck": -0.45, "head": -0.2,
				"jaw": 0.75, "legs": 0.3, "tail": -0.3, "chest": 1.03, "rate": flap_rate * 1.7, "shake": 1.0}
		"dive":
			# Wings swept back and folded close, the body down the line of its fall, the head stretched
			# out ahead, shrieking; near the ground the talons come forward.
			var steep := clampf(atan2(-_vel.y, Vector2(_vel.x, _vel.z).length() + 0.01), 0.2, 1.25)
			var strike := smoothstep(3.0, 1.2, above)
			want = {"amp": 0.06, "lift": lerpf(0.35, 0.9, strike), "sweep": lerpf(1.05, -0.2, strike), "fold": lerpf(1.25, 0.1, strike),
				"pitch": lerpf(steep, -0.5, strike), "neck": lerpf(0.3, -0.2, strike), "head": 0.15, "jaw": 0.6, "legs": lerpf(1.35, -1.0, strike),
				"tail": 0.15, "chest": 1.0, "rate": 3.0, "shake": 0.0}
		"climb":
			# Away and up on strong, deep beats.
			want["amp"] = 1.0
			want["rate"] = flap_rate * 1.45
			want["pitch"] = -0.3
			want["legs"] = 0.6
			want["tail"] = -0.15
		"breath":
			var inhale := act < BREATH_INHALE
			if inhale:
				# Drawing back, chest swelling, the light growing in its throat.
				var k := act / BREATH_INHALE
				want = {"amp": 0.8, "lift": 0.2, "sweep": 0.0, "fold": 0.0, "pitch": -0.35, "neck": -0.55 * k, "head": -0.25 * k,
					"jaw": 0.15, "legs": 0.5, "tail": -0.2, "chest": 1.0 + 0.09 * k, "rate": flap_rate * 1.3, "shake": 0.0}
			else:
				# The head thrown forward and down, the jaw wide, its element pouring out.
				want = {"amp": 0.55, "lift": 0.2, "sweep": -0.05, "fold": 0.0, "pitch": 0.28, "neck": 0.55, "head": 0.35,
					"jaw": 0.85, "legs": 0.6, "tail": 0.2, "chest": 1.0, "rate": flap_rate * 1.2, "shake": 0.35}
				breathing = true
	var k := minf(1.0, delta * (9.0 if mode == "dive" else 5.0))
	for key: String in want:
		_env[key] = lerpf(float(_env.get(key, want[key])), float(want[key]), k)
	_beat = fmod(_beat + delta * float(_env["rate"]), 1.0)
	var amp := float(_env["amp"])
	var cyc := TAU * _beat
	# Down from high over its back with the wing open; up with it folded at the elbow, the hand trailing.
	var lift := float(_env["lift"]) + amp * 0.85 * cos(cyc)
	var up_fold := maxf(0.0, -sin(cyc)) * amp
	var sweep := float(_env["sweep"]) + 0.15 * up_fold
	var fold := float(_env["fold"]) + 0.7 * up_fold
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		shoulders[i].rotation = Vector3(0.0, side * sweep, side * lift)
		elbows[i].rotation = Vector3(0.0, side * fold, -side * 0.45 * up_fold)
	body.position.y = 0.09 * size() * amp * sin(cyc)
	var roll := clampf(-_turn * 0.25, -0.6, 0.6) * (0.3 if mode == "dive" else 1.0)
	body.rotation = Vector3(float(_env["pitch"]), 0.0, lerpf(body.rotation.z, roll, minf(1.0, delta * 3.0)))
	var shake := float(_env["shake"]) * sin(now * 31.0) * 0.07
	neck.rotation = Vector3(float(_env["neck"]) + sin(cyc + 1.2) * 0.06 * amp, sin(now * 0.6) * 0.15 * (1.0 - float(_env["shake"])), shake)
	head.rotation = Vector3(float(_env["head"]) - float(_env["neck"]) * 0.35, 0.0, shake * 0.5)
	jaw.rotation.x = float(_env["jaw"]) * (0.85 + 0.15 * sin(now * 23.0) if float(_env["jaw"]) > 0.3 else 1.0)
	body.scale = Vector3(float(_env["chest"]), float(_env["chest"]), 1.0) * size()
	for i in tails.size():
		tails[i].rotation = Vector3(float(_env["tail"]) * (0.6 if i > 0 else 1.0) - float(_env["pitch"]) * 0.25,
			sin(now * 1.4 - i * 0.8) * (0.22 + 0.06 * i) - roll * 0.3, 0.0)
	for leg in legs:
		leg.rotation.x = float(_env["legs"])
	# Its throat glows as it draws breath, and pours its element out as it breathes.
	var maw := _parts["Maw"] as MeshInstance3D
	maw.scale = Vector3.ONE * (1.0 + (2.2 * act / BREATH_INHALE if mode == "breath" and act < BREATH_INHALE else 1.4 if breathing else 0.0))
	if breath.emitting != breathing:
		breath.emitting = breathing
	if element == "storm":
		# A storm wyvern's sparks flicker on and off.
		_sparks -= delta
		if _sparks <= 0.0:
			_sparks = randf_range(0.05, 0.25)
			for key: String in ["TorsoGlow", "NeckGlow", "HandGlowL", "HandGlowR", "TailGlow2"]:
				(_parts[key] as MeshInstance3D).visible = randf() < 0.75


## Down and still: no more breath, and nothing drifting off it.
func stop() -> void:
	breath.emitting = false
	aura.emitting = false


func restart() -> void:
	_last_pos = Vector3.INF
	_env.clear()
	breath.emitting = false
	aura.emitting = true
	for mi: MeshInstance3D in _parts.values():
		mi.visible = true
