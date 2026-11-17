class_name MesenllaModels
extends RefCounted
## The creatures of the Valleys of Mesenlla and Mist Bastion: low-poly bodies built from code, and the
## light animation that moves them. All of them are parts on pivots; the bear a Child of the Woods
## rides is the one body that still walks in beast_gait.gdshader, like a horse. Each model is a root
## facing +Z; what the animation needs is kept as meta.
## The state a creature is in (rearing, charging, slamming...) is Zombie._current_anim, which is
## also what other phones are sent, so they show the same thing.

## Also the creatures of Port Vael (VaelModels.KINDS), built and moved through here on the same rigs.
const KINDS := ["bear", "mist_bear", "eagle", "mist_eagle", "shapeshifter", "earth_elemental", "mist_elemental",
	"storm_elemental", "wyvern", "great_revenant_elemental", "war_wyvern", "brine_hound", "lantern_jelly", "angler", "siren", "kraken_arm", "leviathan"]
const FLYERS := ["eagle", "mist_eagle", "wyvern", "war_wyvern"]
const BOSS_NAMES := {"great_revenant_elemental": "GREAT REVENANT ELEMENTAL", "war_wyvern": "WAR WYVERN"}

const FUR := Color(0.36, 0.24, 0.15)
const FUR_DARK := Color(0.22, 0.14, 0.09)
const MUZZLE := Color(0.55, 0.42, 0.3)
const CLAW := Color(0.86, 0.82, 0.7)
const BLACK := Color(0.05, 0.05, 0.06)
const MIST_FUR := Color(0.52, 0.6, 0.64)
const MIST_GLOW := Color(0.45, 0.95, 0.92)
const STONE := Color(0.46, 0.44, 0.41)
const STONE_DARK := Color(0.3, 0.29, 0.28)
const MOSS := Color(0.3, 0.46, 0.22)
const AMBER := Color(1.0, 0.66, 0.2)
const BONE := Color(0.9, 0.88, 0.8)
const SCALE_GREEN := Color(0.3, 0.38, 0.26)
const SCALE_BELLY := Color(0.62, 0.58, 0.42)
const WING := Color(0.36, 0.27, 0.22)
const STEEL := Color(0.58, 0.6, 0.66)
const BANNER_RED := Color(0.62, 0.12, 0.1)
const GOLD := Color(0.95, 0.72, 0.22)
const LEAF := Color(0.3, 0.5, 0.22)
const LEAF_DARK := Color(0.2, 0.34, 0.15)
const BARK := Color(0.4, 0.3, 0.2)

static var _meshes := {}
static var _glow: StandardMaterial3D
static var _ghost: StandardMaterial3D


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var l := LowPoly.new()
		build.call(l)
		_meshes[key] = l.commit()
	return _meshes[key]


static func _part(parent: Node3D, mesh: Mesh, at := Vector3.ZERO, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func _pivot(parent: Node3D, at: Vector3, name: String) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.name = name
	parent.add_child(n)
	return n


## Unshaded and coloured by the mesh: eyes, cores, lightning.
static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.vertex_color_use_as_albedo = true
		_glow.disable_fog = true
	return _glow


## Half there: mist creatures, coloured by the mesh and lit from inside.
static func ghost_material() -> StandardMaterial3D:
	if _ghost == null:
		_ghost = StandardMaterial3D.new()
		_ghost.vertex_color_use_as_albedo = true
		_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.albedo_color = Color(1, 1, 1, 0.78)
		_ghost.emission_enabled = true
		_ghost.emission = Color(0.18, 0.42, 0.46)
		_ghost.rim_enabled = true
		_ghost.rim = 0.8
	return _ghost


# --- Bodies ----------------------------------------------------------------------

## The Woodland Cavalry's bear: the bear of the valleys on its jointed legs, in the Children of the
## Woods' harness: a saddle of bark and moss on a woven blanket, a girth of braided vine, a breast band
## hung with leaves and a bridle of twisted root to the reins. "Saddle" on its back is where the rider
## sits, and moves with it. ride_bear() animates it.
const CAVALRY_SIZE := 1.25 # of a wild bear's size, beside the rider's own (small) scale: a big war bear
const RIDER_SEAT := Vector3(0, 0.72, 0.25) # the seat of the saddle, from the bear's hips
static func cavalry_bear() -> Node3D:
	var root := Node3D.new()
	root.name = "CavalryBear"
	_quadruped(root, "bear", _bear_look(FUR, FUR_DARK, MUZZLE, BLACK, false))
	var torso := root.get_node("Rig/Hind/Torso") as Node3D
	var hip: Vector3 = Vector3(0, 0.76, -0.55)
	_part(torso, _mesh("cavalry_harness", func(l: LowPoly) -> void:
		# The blanket, woven of rushes, draped over the back behind the hump.
		l.box(Vector3(0, 1.36, -0.32), Vector3(0.82, 0.05, 0.86), Color(0.42, 0.36, 0.22), Vector3(4, 0, 0))
		for i in 5:
			l.box(Vector3(0, 1.375, -0.66 + i * 0.17), Vector3(0.84, 0.02, 0.05), Color(0.3, 0.42, 0.2))
		for x: float in [-1.0, 1.0]:
			# Its sides hang over the flanks, edged with a fringe of rush ends.
			l.box(Vector3(x * 0.49, 1.22, -0.32), Vector3(0.04, 0.26, 0.78), Color(0.36, 0.3, 0.18), Vector3(0, 0, x * -14.0))
			for i in 7:
				var z := -0.66 + i * 0.113
				l.prism(Vector3(x * 0.52, 1.1, z), Vector3(x * 0.54, 1.0, z + 0.01), 0.018, 0.0, 3, Color(0.46, 0.4, 0.24))
		# The saddle: a seat of curved bark, a high cantle behind and a pommel of root before.
		l.box(Vector3(0, 1.44, -0.3), Vector3(0.46, 0.08, 0.5), BARK)
		l.box(Vector3(0, 1.52, -0.56), Vector3(0.44, 0.18, 0.07), BARK.darkened(0.15), Vector3(-12, 0, 0))
		l.prism(Vector3(0, 1.46, -0.04), Vector3(0, 1.66, 0.02), 0.07, 0.035, 6, BARK.darkened(0.25))
		l.box(Vector3(0, 1.49, -0.3), Vector3(0.38, 0.03, 0.4), Color(0.28, 0.42, 0.2)) # moss on the seat
		# The girth of braided vine round the barrel, and the breast band across the chest.
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.46, 1.3, -0.12), Vector3(x * 0.5, 0.62, -0.1), 0.025, 0.025, 5, LEAF_DARK.darkened(0.2))
			l.prism(Vector3(x * 0.44, 1.18, 0.05), Vector3(x * 0.3, 0.86, 0.7), 0.032, 0.032, 5, LEAF_DARK)
		l.prism(Vector3(-0.5, 0.62, -0.1), Vector3(0.5, 0.62, -0.1), 0.025, 0.025, 5, LEAF_DARK.darkened(0.2))
		l.prism(Vector3(-0.3, 0.86, 0.72), Vector3(0.3, 0.86, 0.72), 0.034, 0.034, 5, LEAF_DARK)
		# Leaves hung from the breast band, and a knot of feathers at the pommel.
		for i in 5:
			var x := -0.24 + i * 0.12
			l.prism(Vector3(x, 0.85, 0.74), Vector3(x * 1.1, 0.68, 0.78), 0.05, 0.0, 4, LEAF if i % 2 == 0 else LEAF_DARK)
		l.prism(Vector3(0.04, 1.62, 0.0), Vector3(0.16, 1.82, -0.08), 0.03, 0.0, 4, Color(0.75, 0.7, 0.6))
		l.prism(Vector3(-0.02, 1.62, 0.0), Vector3(-0.12, 1.84, -0.04), 0.03, 0.0, 4, Color(0.5, 0.36, 0.25))), -hip)
	var head := torso.get_node("Head") as Node3D
	_part(head, _mesh("cavalry_bridle", func(l: LowPoly) -> void:
		# A bridle of twisted root round the muzzle and behind the ears, and the reins back to the saddle.
		l.prism(Vector3(-0.17, 0.02, 0.3), Vector3(0.17, 0.02, 0.3), 0.025, 0.025, 5, BARK.darkened(0.2))
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.17, 0.02, 0.3), Vector3(x * 0.2, 0.2, 0.02), 0.022, 0.022, 5, BARK.darkened(0.2))
			l.prism(Vector3(x * 0.17, 0.02, 0.3), Vector3(x * 0.22, 0.18, -0.55), 0.016, 0.016, 4, LEAF_DARK)))
	_pivot(torso, RIDER_SEAT, "Saddle")
	root.scale = Vector3.ONE * CAVALRY_SIZE
	return root


## The Woodland Cavalry's bear under its rider, moving with what the rider is doing (its animation):
## galloping when the rider couches the spear for a charge, a paw raking as the spear goes home,
## half rearing with a roar as the rider brandishes the spear at the end of a pass, and otherwise
## ambling or standing by how fast it goes (pace, in metres a second).
static func ride_bear(z: Zombie, mount: Node3D, delta: float, pace: float, rider_anim: String) -> void:
	var state := ""
	match rider_anim:
		"RideCharge":
			state = "m_charge"
		"RideThrust":
			state = "m_swipe"
		"RideBrandish":
			state = "m_rear"
	if state != str(mount.get_meta("act_state", "")):
		mount.set_meta("from_state", mount.get_meta("act_state", ""))
		mount.set_meta("act_state", state)
		mount.set_meta("act_t", 0.0)
		if state == "m_swipe":
			mount.set_meta("swipes", int(mount.get_meta("swipes", 0)) + 1)
	else:
		mount.set_meta("act_t", float(mount.get_meta("act_t", 0.0)) + delta)
	_animate_bear(z, mount, delta, clampf(pace / 4.0, 0.0, 1.0), state, 0.45)


# --- Four legs on joints ------------------------------------------------------------

## A four-legged creature put together from parts on pivots, facing +Z, so it can walk, rear, maul,
## charge and fall over. The nodes:
##   Rig            the whole animal; it rolls over when it dies
##     Hind         at the hind hips: rearing tips everything above them up
##       Torso      the body, the neck and the head ("Head"), and the forelegs
##     LegBL, LegBR the hind legs, which stay on the ground when it rears
## Each leg is a pivot at the hip or shoulder with its "Knee" below, and for a bear its "Paw" below that,
## so the paw can flex as it lifts and plant flat as it lands. A bear's head has a "Jaw".
static func _quadruped(root: Node3D, key: String, look: Dictionary) -> void:
	var rig := _pivot(root, Vector3.ZERO, "Rig")
	var hip: Vector3 = look["hip"]
	var hind := _pivot(rig, hip, "Hind")
	var torso := _pivot(hind, Vector3.ZERO, "Torso")
	var body := _part(torso, _mesh(key + "_torso", look["torso"]), -hip)
	var head := _pivot(torso, Vector3(look["neck"]) - hip, "Head")
	var head_mesh := _part(head, _mesh(key + "_head", look["head"]))
	var material: Material = look.get("material", null)
	for part in [body, head_mesh]:
		part.material_override = material
	if look.has("jaw"):
		var jaw := _pivot(head, look["jaw_at"], "Jaw")
		_part(jaw, _mesh(key + "_jaw", look["jaw"])).material_override = material
	if look.has("eyes"):
		_part(head, _mesh(key + "_eyes", look["eyes"])).material_override = glow_material()
	if look.has("glow"):
		_part(torso, _mesh(key + "_glow", look["glow"]), -hip).material_override = glow_material()
	if look.has("tail"):
		var tail := _pivot(torso, Vector3(look["tail_at"]) - hip, "Tail")
		_part(tail, _mesh(key + "_tail", look["tail"])).material_override = material
	var shoulder: Vector3 = look["shoulder"]
	for side: float in [-1.0, 1.0]:
		var w: float = look["width"] * side
		for front: bool in [true, false]:
			var at := Vector3(w, shoulder.y, shoulder.z) if front else Vector3(w, hip.y, hip.z)
			var parent: Node3D = torso if front else rig
			var leg := _pivot(parent, at - hip if front else at, "Leg%s%s" % ["F" if front else "B", "L" if side < 0 else "R"])
			var upper := _part(leg, _mesh("%s_upper_%s" % [key, front], look["upper_front" if front else "upper_hind"]))
			var knee := _pivot(leg, Vector3(0, -float(look["upper_len"]), 0), "Knee")
			var lower := _part(knee, _mesh("%s_lower_%s" % [key, front], look["lower"]))
			upper.material_override = material
			lower.material_override = material
			if look.has("paw"):
				var paw := _pivot(knee, Vector3(0, -float(look["lower_len"]), 0.02), "Paw")
				_part(paw, _mesh(key + "_paw", look["paw"])).material_override = material
	root.set_meta("legs", ["LegFL", "LegFR", "LegBL", "LegBR"])


## A bear's parts, facing +Z, built to be looked at closely: a deep barrel of a body under a shaggy
## coat, the high hump of muscle over a grizzly's shoulders, a broad dished face with a short muzzle,
## a black nose and a jaw that opens, small round ears, heavy forearms feathered with long fur, and
## broad paws with long pale claws. The coat is tufts all over (a tuft's vertex alpha says how loose
## it is) and the fur shader (fur.gdshader) draws strands through every face.
const BEAR_TUFT := 0.55 # vertex alpha of a tuft: loose enough to stir


## Tufts of fur over part of a tube from a to b of this radius: count of them, spread around it
## between these angles (0 is straight up, PI straight down), each pointing out and along flow.
static func _shag(l: LowPoly, rng: RandomNumberGenerator, a: Vector3, b: Vector3, radius: float, count: int, around: Vector2, flow: Vector3, fur: Color, length := 0.16, thick := 0.05) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(axis).normalized()
	if up.y < 0.0:
		up = -up
	for i in count:
		var t := rng.randf()
		var angle := rng.randf_range(around.x, around.y) * (1.0 if rng.randf() < 0.5 else -1.0)
		var out := (up * cos(angle) + side * sin(angle)).normalized()
		var at := a.lerp(b, t) + out * radius * 0.9
		var reach := length * rng.randf_range(0.7, 1.25)
		var tip := at + (out * 0.32 + flow).normalized() * reach
		var shade := rng.randf_range(-0.12, 0.07)
		var col := (fur.lightened(shade) if shade > 0.0 else fur.darkened(-shade))
		col.a = BEAR_TUFT
		l.prism(at, tip, thick * rng.randf_range(0.9, 1.35), 0.0, 4, col)


static func _bear_look(fur: Color, dark: Color, muzzle: Color, eye: Color, misty: bool) -> Dictionary:
	var light := fur.lightened(0.12)
	var look := {
		"hip": Vector3(0, 0.76, -0.55), "shoulder": Vector3(0, 0.78, 0.48), "neck": Vector3(0, 0.98, 0.74), "width": 0.27, "upper_len": 0.36, "lower_len": 0.31,
		"jaw_at": Vector3(0, -0.1, 0.2),
		"torso": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1301
			l.prism(Vector3(0, 0.84, -0.98), Vector3(0, 0.88, -0.78), 0.26, 0.43, 10, fur.darkened(0.04)) # the rump
			l.prism(Vector3(0, 0.88, -0.78), Vector3(0, 0.93, 0.28), 0.43, 0.51, 10, fur) # the barrel
			l.prism(Vector3(0, 0.93, 0.28), Vector3(0, 0.9, 0.74), 0.51, 0.4, 10, fur.lightened(0.03)) # the chest
			l.prism(Vector3(0, 1.1, -0.05), Vector3(0, 1.2, 0.42), 0.3, 0.27, 8, fur.darkened(0.05)) # the hump
			l.prism(Vector3(0, 1.2, 0.42), Vector3(0, 1.06, 0.72), 0.27, 0.2, 8, fur.darkened(0.03))
			l.prism(Vector3(0, 0.97, -0.96), Vector3(0, 0.9, -1.1), 0.09, 0.03, 5, dark) # the stub of a tail
			# The coat: shaggy over the hump and the back, long and hanging under the belly, a ruff
			# round the neck, and the rump.
			_shag(l, rng, Vector3(0, 1.12, -0.05), Vector3(0, 1.2, 0.62), 0.29, 26, Vector2(0.0, 1.2), Vector3(0, 0.15, -0.8), light, 0.17, 0.06)
			_shag(l, rng, Vector3(0, 0.9, -0.8), Vector3(0, 0.93, 0.3), 0.48, 34, Vector2(0.3, 1.9), Vector3(0, -0.35, -0.7), fur, 0.16, 0.06)
			_shag(l, rng, Vector3(0, 0.84, -0.6), Vector3(0, 0.86, 0.55), 0.46, 22, Vector2(2.2, 2.75), Vector3(0, -1.0, -0.1), dark, 0.2, 0.05)
			_shag(l, rng, Vector3(0, 0.95, 0.55), Vector3(0, 0.96, 0.74), 0.42, 20, Vector2(0.4, 2.6), Vector3(0, -0.4, -0.5), light, 0.15, 0.055)
			_shag(l, rng, Vector3(0, 0.86, -1.0), Vector3(0, 0.88, -0.8), 0.36, 12, Vector2(0.2, 2.0), Vector3(0, -0.5, -0.6), fur, 0.13, 0.05),
		"head": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1302
			l.prism(Vector3(0, 0.0, -0.16), Vector3(0, 0.05, 0.16), 0.25, 0.25, 9, fur) # the skull
			l.prism(Vector3(0, 0.05, 0.16), Vector3(0, 0.02, 0.26), 0.25, 0.19, 9, fur.lightened(0.04))
			l.box(Vector3(0, 0.16, 0.17), Vector3(0.36, 0.07, 0.1), fur.darkened(0.08)) # the brow
			l.prism(Vector3(0, -0.02, 0.24), Vector3(0, -0.05, 0.5), 0.15, 0.1, 8, muzzle) # the muzzle
			l.prism(Vector3(0, 0.03, 0.24), Vector3(0, -0.01, 0.46), 0.1, 0.07, 6, muzzle.lightened(0.06)) # the bridge of the nose
			l.box(Vector3(0, -0.0, 0.52), Vector3(0.11, 0.07, 0.06), BLACK) # the nose
			l.box(Vector3(0, -0.06, 0.49), Vector3(0.03, 0.05, 0.03), BLACK)
			for x: float in [-1.0, 1.0]:
				l.box(Vector3(x * 0.035, 0.0, 0.552), Vector3(0.025, 0.025, 0.01), Color(0.12, 0.1, 0.1)) # nostrils
				l.prism(Vector3(x * 0.15, 0.2, 0.0), Vector3(x * 0.19, 0.3, -0.02), 0.075, 0.055, 7, fur.darkened(0.12)) # ears
				l.box(Vector3(x * 0.175, 0.26, 0.02), Vector3(0.06, 0.06, 0.02), dark.darkened(0.25))
			# Cheek ruffs, standing out round the face, and shaggy fur over the crown.
			_shag(l, rng, Vector3(0, -0.02, -0.12), Vector3(0, 0.0, 0.14), 0.24, 16, Vector2(0.9, 2.4), Vector3(0, -0.2, -0.6), light, 0.12, 0.05)
			_shag(l, rng, Vector3(0, 0.05, -0.15), Vector3(0, 0.08, 0.08), 0.22, 8, Vector2(0.0, 0.7), Vector3(0, 0.1, -0.9), fur, 0.11, 0.05),
		"jaw": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, -0.02), Vector3(0, -0.02, 0.27), 0.1, 0.07, 6, muzzle.darkened(0.1))
			l.box(Vector3(0, 0.035, 0.12), Vector3(0.12, 0.02, 0.24), Color(0.5, 0.18, 0.18)) # the mouth
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.045, 0.03, 0.22), Vector3(x * 0.045, 0.09, 0.23), 0.016, 0.0, 4, BONE), # the fangs
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-0.12, 0.12]:
				l.box(Vector3(x, 0.09, 0.285), Vector3(0.045, 0.04, 0.02), eye),
		"upper_front": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1303
			l.prism(Vector3(0, 0.14, -0.02), Vector3(0, -0.38, 0.02), 0.19, 0.14, 8, fur.darkened(0.06))
			_shag(l, rng, Vector3(0, 0.08, 0), Vector3(0, -0.34, 0.02), 0.16, 12, Vector2(1.6, 3.1), Vector3(0, -0.8, -0.4), fur, 0.15, 0.05),
		"upper_hind": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1304
			l.prism(Vector3(0, 0.16, -0.06), Vector3(0, -0.38, 0.04), 0.23, 0.14, 8, fur.darkened(0.04))
			_shag(l, rng, Vector3(0, 0.12, -0.04), Vector3(0, -0.3, 0.02), 0.2, 10, Vector2(1.2, 3.1), Vector3(0, -0.8, -0.3), fur, 0.14, 0.05),
		"lower": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1305
			l.prism(Vector3(0, 0.04, 0), Vector3(0, -0.31, 0.02), 0.14, 0.12, 8, dark)
			# Long fur feathering the backs of the legs.
			_shag(l, rng, Vector3(0, 0.0, 0), Vector3(0, -0.28, 0.02), 0.12, 9, Vector2(2.2, 3.1), Vector3(0, -0.9, -0.3), dark.lightened(0.08), 0.13, 0.045),
		"paw": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1306
			l.box(Vector3(0, -0.035, 0.05), Vector3(0.26, 0.1, 0.3), dark.darkened(0.12))
			l.box(Vector3(0, -0.084, 0.05), Vector3(0.22, 0.012, 0.24), Color(0.12, 0.1, 0.1)) # the pads
			_shag(l, rng, Vector3(0, -0.0, -0.05), Vector3(0, -0.01, 0.15), 0.12, 7, Vector2(0.4, 1.6), Vector3(0, -0.6, 0.4), dark.lightened(0.06), 0.08, 0.04)
			for c in 5:
				var x := -0.1 + c * 0.05
				l.prism(Vector3(x, -0.05, 0.19), Vector3(x * 1.1, -0.085, 0.31), 0.022, 0.0, 4, CLAW), # long, pale claws
	}
	if misty:
		look["glow"] = func(l: LowPoly) -> void:
			# Mist streaming off its back in pale stripes, and wisps along its spine.
			for i in 4:
				l.box(Vector3(0, 1.36 - i * 0.035, 0.45 - i * 0.3), Vector3(0.46 - i * 0.06, 0.04, 0.1), MIST_GLOW.darkened(0.25))
			for i in 6:
				var z := 0.55 - i * 0.26
				l.prism(Vector3(0, 1.32 - i * 0.04, z), Vector3(0, 1.5 - i * 0.03, z - 0.18), 0.035, 0.0, 4, MIST_GLOW.darkened(0.1))
	look["material"] = fur_material(misty)
	return look


## The bears' coat: one material for the bears of the valleys, one for the Mist Bear.
static var _fur := {}


static func fur_material(misty: bool) -> ShaderMaterial:
	if not _fur.has(misty):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/fur.gdshader")
		m.set_shader_parameter("glow", 1.0 if misty else 0.0)
		m.set_shader_parameter("glow_color", Color(MIST_GLOW.r, MIST_GLOW.g, MIST_GLOW.b))
		m.set_shader_parameter("density", 40.0 if misty else 44.0)
		m.set_shader_parameter("sheen", 0.25 if misty else 0.5)
		_fur[misty] = m
	return _fur[misty]


# --- The Shapeshifter's other shapes ----------------------------------------------------

const WOLF_FUR := Color(0.6, 0.66, 0.7)
const BOAR_HIDE := Color(0.24, 0.18, 0.14)
const OWL_FEATHER := Color(0.56, 0.48, 0.38)
const SHIFTER_EYES := Color(0.6, 1.0, 0.85) # the same pale green in every shape it takes


## The Mist Wolf: long-legged and lean, pale grey with mist in its coat, a deep chest and a long
## muzzle, tall ears, a ruff about its neck and a bushy tail that streams mist.
static func _wolf_look() -> Dictionary:
	var fur := WOLF_FUR
	var dark := fur.darkened(0.35)
	return {
		"hip": Vector3(0, 0.66, -0.48), "shoulder": Vector3(0, 0.7, 0.42), "neck": Vector3(0, 0.9, 0.64), "width": 0.16, "upper_len": 0.32, "lower_len": 0.28,
		"jaw_at": Vector3(0, -0.06, 0.14), "tail_at": Vector3(0, 0.78, -0.72),
		"torso": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2101
			l.prism(Vector3(0, 0.72, -0.72), Vector3(0, 0.74, 0.12), 0.19, 0.24, 9, fur) # loins to ribs
			l.prism(Vector3(0, 0.74, 0.12), Vector3(0, 0.78, 0.58), 0.27, 0.2, 9, fur.lightened(0.05)) # the deep chest
			l.prism(Vector3(0, 0.8, 0.5), Vector3(0, 0.92, 0.66), 0.2, 0.14, 8, fur) # the neck
			_shag(l, rng, Vector3(0, 0.8, 0.34), Vector3(0, 0.88, 0.66), 0.24, 22, Vector2(0.0, 2.6), Vector3(0, -0.3, -0.7), fur.lightened(0.12), 0.14, 0.05) # the ruff
			_shag(l, rng, Vector3(0, 0.74, -0.7), Vector3(0, 0.76, 0.3), 0.21, 18, Vector2(0.0, 1.6), Vector3(0, 0.0, -0.9), fur, 0.11, 0.04),
		"head": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2102
			l.prism(Vector3(0, 0.03, -0.1), Vector3(0, 0.04, 0.12), 0.13, 0.12, 8, fur)
			l.prism(Vector3(0, 0.0, 0.12), Vector3(0, -0.03, 0.4), 0.08, 0.045, 7, fur.lightened(0.1)) # the long muzzle
			l.box(Vector3(0, -0.01, 0.41), Vector3(0.06, 0.045, 0.04), BLACK)
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.07, 0.12, -0.02), Vector3(x * 0.1, 0.32, -0.06), 0.05, 0.0, 4, fur.darkened(0.1)) # tall ears
			_shag(l, rng, Vector3(0, 0.0, -0.08), Vector3(0, 0.02, 0.08), 0.13, 10, Vector2(1.0, 2.2), Vector3(0, -0.2, -0.7), fur.lightened(0.15), 0.09, 0.04),
		"jaw": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, -0.04), Vector3(0, -0.01, 0.24), 0.045, 0.025, 6, fur.darkened(0.1))
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.03, 0.02, 0.2), Vector3(x * 0.03, 0.06, 0.21), 0.01, 0.0, 3, BONE),
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-0.065, 0.065]:
				l.box(Vector3(x, 0.08, 0.13), Vector3(0.04, 0.025, 0.02), SHIFTER_EYES),
		"glow": func(l: LowPoly) -> void:
			# Mist rising off its back.
			for i in 5:
				var z := 0.45 - i * 0.26
				l.prism(Vector3(0, 0.96 - i * 0.02, z), Vector3(0, 1.1 - i * 0.02, z - 0.16), 0.03, 0.0, 4, MIST_GLOW.darkened(0.1)),
		"tail": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2103
			l.prism(Vector3.ZERO, Vector3(0, -0.24, -0.4), 0.08, 0.05, 6, fur)
			_shag(l, rng, Vector3(0, -0.04, -0.06), Vector3(0, -0.22, -0.38), 0.07, 14, Vector2(0.0, PI), Vector3(0, -0.4, -0.8), fur.lightened(0.15), 0.12, 0.045),
		"upper_front": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.08, 0), Vector3(0, -0.32, 0.02), 0.075, 0.05, 6, fur),
		"upper_hind": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.1, -0.04), Vector3(0, -0.32, 0.04), 0.11, 0.05, 6, fur),
		"lower": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.02, 0), Vector3(0, -0.28, -0.02), 0.045, 0.035, 6, dark.lightened(0.15)),
		"paw": func(l: LowPoly) -> void:
			l.box(Vector3(0, -0.025, 0.03), Vector3(0.09, 0.05, 0.13), dark)
			for c in 3:
				l.prism(Vector3(-0.03 + c * 0.03, -0.03, 0.09), Vector3(-0.03 + c * 0.03, -0.05, 0.13), 0.012, 0.0, 3, BONE),
		"material": fur_material(true),
	}


## The Tusked Boar: low and heavy, black-brown, a crest of bristles down its back, a long snout with a
## pale disc of a nose and two great curved tusks, small ears, short legs on hooves.
static func _boar_look() -> Dictionary:
	var hide := BOAR_HIDE
	var dark := hide.darkened(0.3)
	return {
		"hip": Vector3(0, 0.56, -0.42), "shoulder": Vector3(0, 0.6, 0.36), "neck": Vector3(0, 0.72, 0.6), "width": 0.2, "upper_len": 0.26, "lower_len": 0.22,
		"jaw_at": Vector3(0, -0.1, 0.1), "tail_at": Vector3(0, 0.72, -0.72),
		"torso": func(l: LowPoly) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 2201
			l.prism(Vector3(0, 0.66, -0.72), Vector3(0, 0.7, 0.1), 0.26, 0.33, 9, hide) # rump to ribs
			l.prism(Vector3(0, 0.7, 0.1), Vector3(0, 0.74, 0.6), 0.36, 0.3, 9, hide.lightened(0.04)) # the great shoulders
			l.box(Vector3(0, 0.44, -0.05), Vector3(0.4, 0.14, 0.8), dark)
			# The crest of bristles, standing up from its neck down its spine.
			_shag(l, rng, Vector3(0, 0.98, 0.55), Vector3(0, 0.92, -0.5), 0.06, 30, Vector2(0.0, 0.35), Vector3(0, 0.6, -0.35), dark.lightened(0.12), 0.17, 0.045)
			_shag(l, rng, Vector3(0, 0.68, -0.6), Vector3(0, 0.72, 0.5), 0.32, 26, Vector2(0.5, 2.0), Vector3(0, -0.4, -0.6), hide, 0.1, 0.045),
		"head": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, -0.12), Vector3(0, -0.04, 0.18), 0.22, 0.16, 8, hide) # the wedge of its head
			l.prism(Vector3(0, -0.04, 0.18), Vector3(0, -0.08, 0.46), 0.14, 0.09, 8, hide.lightened(0.05)) # the snout
			l.prism(Vector3(0, -0.08, 0.46), Vector3(0, -0.08, 0.5), 0.1, 0.1, 8, Color(0.62, 0.48, 0.46)) # the disc of its nose
			for x: float in [-1.0, 1.0]:
				l.box(Vector3(x * 0.035, -0.07, 0.505), Vector3(0.025, 0.035, 0.01), Color(0.2, 0.12, 0.12))
				l.prism(Vector3(x * 0.12, 0.14, -0.04), Vector3(x * 0.18, 0.24, -0.1), 0.05, 0.0, 4, dark) # small ears
				# The tusks: out of its lower lip, out and up and back.
				l.prism(Vector3(x * 0.09, -0.1, 0.36), Vector3(x * 0.17, -0.02, 0.38), 0.03, 0.026, 5, BONE)
				l.prism(Vector3(x * 0.17, -0.02, 0.38), Vector3(x * 0.19, 0.12, 0.28), 0.026, 0.0, 5, BONE.darkened(0.06)),
		"jaw": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, -0.02), Vector3(0, -0.02, 0.3), 0.08, 0.06, 6, hide.darkened(0.1)),
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-0.13, 0.13]:
				l.box(Vector3(x, 0.07, 0.14), Vector3(0.03, 0.03, 0.03), SHIFTER_EYES),
		"tail": func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.28, -0.08), 0.025, 0.015, 4, dark)
			l.prism(Vector3(0, -0.26, -0.08), Vector3(0, -0.36, -0.1), 0.04, 0.0, 4, dark.lightened(0.1)),
		"upper_front": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.1, 0), Vector3(0, -0.26, 0.02), 0.11, 0.07, 6, hide),
		"upper_hind": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.12, -0.04), Vector3(0, -0.26, 0.04), 0.14, 0.07, 6, hide),
		"lower": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.02, 0), Vector3(0, -0.22, 0.0), 0.06, 0.045, 6, dark),
		"paw": func(l: LowPoly) -> void:
			for x: float in [-0.025, 0.025]:
				l.box(Vector3(x, -0.035, 0.03), Vector3(0.04, 0.07, 0.08), Color(0.12, 0.1, 0.09)), # cloven hooves
		"material": fur_material(false),
	}


## The Great Owl: a tawny spirit-owl as big as a man, a pale face with great glowing eyes and tufted
## ears, wings that span half again its height, a fanned tail and long talons. Facing +Z. Nodes:
##   Owl > Body (pitches and bobs) > Head, WingL and WingR (shoulders, each with its "Tip"), Tail, Talons
static func _owl_parts(holder: Node3D) -> void:
	var body := _pivot(holder, Vector3(0, 1.0, 0), "Body")
	var feather := OWL_FEATHER
	var pale := Color(0.86, 0.82, 0.72)
	_part(body, _mesh("owl_body", func(l: LowPoly) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2301
		l.prism(Vector3(0, -0.42, -0.04), Vector3(0, 0.0, 0.0), 0.2, 0.32, 9, feather.darkened(0.08))
		l.prism(Vector3(0, 0.0, 0.0), Vector3(0, 0.3, 0.02), 0.32, 0.26, 9, feather)
		l.prism(Vector3(0, -0.3, 0.12), Vector3(0, 0.2, 0.2), 0.16, 0.18, 7, pale.darkened(0.1)) # the speckled breast
		for i in 14:
			l.box(Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.28, 0.18), 0.33), Vector3(0.04, 0.025, 0.02), feather.darkened(0.3))
		_shag(l, rng, Vector3(0, -0.4, 0), Vector3(0, 0.25, 0), 0.28, 26, Vector2(0.0, PI), Vector3(0, -1.0, -0.2), feather.lightened(0.05), 0.1, 0.05)))
	var head := _pivot(body, Vector3(0, 0.36, 0.04), "Head")
	_part(head, _mesh("owl_head", func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.06, -0.02), Vector3(0, 0.24, 0.0), 0.24, 0.2, 9, feather)
		l.prism(Vector3(0, 0.08, 0.12), Vector3(0, 0.08, 0.2), 0.2, 0.17, 10, pale) # the face
		l.prism(Vector3(0, 0.06, 0.2), Vector3(0, -0.02, 0.28), 0.035, 0.0, 4, Color(0.3, 0.26, 0.2)) # the hooked beak
		for x: float in [-1.0, 1.0]:
			l.prism(Vector3(x * 0.12, 0.2, 0.02), Vector3(x * 0.2, 0.42, -0.04), 0.05, 0.0, 4, feather.darkened(0.2)) # ear tufts
			l.prism(Vector3(x * 0.075, 0.1, 0.205), Vector3(x * 0.075, 0.1, 0.21), 0.075, 0.075, 8, Color(0.22, 0.18, 0.14))))
	_part(head, _mesh("owl_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.075, 0.075]:
			l.prism(Vector3(x, 0.1, 0.21), Vector3(x, 0.1, 0.225), 0.05, 0.05, 8, SHIFTER_EYES))).material_override = glow_material()
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(body, Vector3(side * 0.26, 0.18, 0.0), "WingL" if side < 0 else "WingR")
		_part(wing, _mesh("owl_wing_%s" % side, func(l: LowPoly) -> void:
			l.box(Vector3(side * 0.32, 0.0, -0.06), Vector3(0.66, 0.05, 0.4), feather)
			for i in 6:
				l.box(Vector3(side * (0.06 + i * 0.11), -0.02, -0.32), Vector3(0.1, 0.02, 0.22), feather.darkened(0.08 * (i % 2)))
			l.box(Vector3(side * 0.3, 0.03, 0.05), Vector3(0.56, 0.02, 0.14), pale.darkened(0.25))))
		var tip := _pivot(wing, Vector3(side * 0.64, 0, 0), "Tip")
		_part(tip, _mesh("owl_tip_%s" % side, func(l: LowPoly) -> void:
			l.box(Vector3(side * 0.24, 0.0, -0.1), Vector3(0.5, 0.04, 0.32), feather.darkened(0.05))
			for i in 5:
				var a := 0.15 + i * 0.16
				var dir := Vector3(side * cos(a), 0, -sin(a))
				l.turned_box(Vector3(side * 0.42, -0.01, -0.12) + dir * 0.22, Vector3(0.46, 0.015, 0.07), feather.darkened(0.12 * (i % 2)), Basis(Vector3.UP, -side * a))))
	var tail := _pivot(body, Vector3(0, -0.38, -0.12), "Tail")
	_part(tail, _mesh("owl_tail", func(l: LowPoly) -> void:
		for i in 5:
			var a := (i - 2) * 0.22
			l.turned_box(Vector3(sin(a) * 0.14, -0.02, -0.18), Vector3(0.1, 0.02, 0.36), feather.darkened(0.06 * (i % 2)), Basis(Vector3.UP, a))))
	var talons := _pivot(body, Vector3(0, -0.4, 0.06), "Talons")
	_part(talons, _mesh("owl_talons", func(l: LowPoly) -> void:
		for x: float in [-0.09, 0.09]:
			l.prism(Vector3(x, 0, 0), Vector3(x, -0.24, 0.02), 0.05, 0.035, 5, pale.darkened(0.15)) # feathered legs
			for k in 3:
				var a := (k - 1) * 0.5
				l.prism(Vector3(x, -0.24, 0.02), Vector3(x + sin(a) * 0.1, -0.28, 0.02 + cos(a) * 0.12), 0.018, 0.0, 4, Color(0.15, 0.13, 0.12))))


## The Shapeshifter's first shape: a stag of pure white on long legs, with a crown of antlers.
static func _stag_look() -> Dictionary:
	var white := Color(0.9, 0.9, 0.86)
	var shade := Color(0.74, 0.74, 0.72)
	var hoof := Color(0.25, 0.22, 0.2)
	return {
		"hip": Vector3(0, 1.0, -0.5), "shoulder": Vector3(0, 1.0, 0.45), "neck": Vector3(0, 1.55, 0.78), "width": 0.16, "upper_len": 0.46,
		"torso": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 1.06, -0.66), Vector3(0, 1.1, 0.58), 0.25, 0.28, 7, white)
			l.prism(Vector3(0, 1.12, 0.5), Vector3(0, 1.55, 0.78), 0.17, 0.12, 6, white)
			l.box(Vector3(0, 0.92, 0.0), Vector3(0.3, 0.12, 0.9), shade)
			l.prism(Vector3(0, 1.2, -0.66), Vector3(0, 1.05, -0.82), 0.08, 0.02, 5, white),
		"head": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.04, -0.1), Vector3(0, 0.0, 0.2), 0.13, 0.11, 7, white)
			l.prism(Vector3(0, 0.0, 0.2), Vector3(0, -0.06, 0.42), 0.1, 0.06, 6, shade)
			l.box(Vector3(0, -0.04, 0.43), Vector3(0.06, 0.05, 0.03), BLACK)
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.1, 0.12, -0.04), Vector3(x * 0.26, 0.2, -0.1), 0.05, 0.02, 4, shade)
				l.prism(Vector3(x * 0.07, 0.14, 0.0), Vector3(x * 0.25, 0.58, -0.1), 0.03, 0.022, 4, BONE)
				l.prism(Vector3(x * 0.25, 0.58, -0.1), Vector3(x * 0.38, 0.92, -0.28), 0.022, 0.0, 4, BONE)
				l.prism(Vector3(x * 0.17, 0.38, -0.05), Vector3(x * 0.38, 0.48, 0.16), 0.018, 0.0, 4, BONE)
				l.prism(Vector3(x * 0.25, 0.58, -0.1), Vector3(x * 0.46, 0.72, 0.08), 0.018, 0.0, 4, BONE)
				l.prism(Vector3(x * 0.31, 0.75, -0.18), Vector3(x * 0.5, 0.86, -0.06), 0.015, 0.0, 4, BONE),
		"eyes": func(l: LowPoly) -> void:
			for x: float in [-0.1, 0.1]:
				l.box(Vector3(x, 0.08, 0.14), Vector3(0.04, 0.04, 0.03), Color(0.5, 0.9, 1.0)),
		"upper_front": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.08, 0), Vector3(0, -0.48, 0.02), 0.08, 0.05, 6, white),
		"upper_hind": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.1, -0.06), Vector3(0, -0.48, -0.02), 0.12, 0.05, 6, white),
		"lower": func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.0, 0), Vector3(0, -0.46, 0.0), 0.045, 0.035, 5, white)
			l.box(Vector3(0, -0.5, 0.02), Vector3(0.08, 0.08, 0.1), hoof),
	}


## Standing up: the Shapeshifter's hulking second shape, half bear and half something older.
static func _were_parts(root: Node3D) -> void:
	var beast := _pivot(root, Vector3.ZERO, "Beast")
	var fur := Color(0.28, 0.2, 0.16)
	_part(beast, _mesh("were_torso", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.95, 0), Vector3(0, 1.85, 0.05), 0.42, 0.55, 7, fur)
		l.box(Vector3(0, 1.75, 0.12), Vector3(0.95, 0.45, 0.6), fur.lightened(0.05))
		l.box(Vector3(0, 1.35, 0.32), Vector3(0.5, 0.5, 0.12), MUZZLE.darkened(0.2))))
	var head := _pivot(beast, Vector3(0, 2.05, 0.22), "Head")
	_part(head, _mesh("were_head", func(l: LowPoly) -> void:
		l.box(Vector3(0, 0.1, 0.05), Vector3(0.5, 0.42, 0.5), fur)
		l.box(Vector3(0, 0.0, 0.38), Vector3(0.28, 0.22, 0.3), MUZZLE)
		l.box(Vector3(0, 0.06, 0.54), Vector3(0.1, 0.08, 0.04), BLACK)
		for x: float in [-1.0, 1.0]:
			l.box(Vector3(x * 0.2, 0.36, -0.02), Vector3(0.12, 0.12, 0.08), fur.darkened(0.2))
			l.prism(Vector3(x * 0.15, 0.3, -0.05), Vector3(x * 0.45, 0.75, -0.2), 0.03, 0.015, 4, BONE)
			l.prism(Vector3(x * 0.33, 0.55, -0.12), Vector3(x * 0.55, 0.62, 0.1), 0.015, 0.0, 4, BONE)))
	_part(head, _mesh("were_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.12, 0.12]:
			l.box(Vector3(x, 0.17, 0.31), Vector3(0.08, 0.04, 0.02), Color(0.6, 1.0, 0.85)))).material_override = glow_material()
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(beast, Vector3(side * 0.6, 1.8, 0.1), "ArmL" if side < 0 else "ArmR")
		_part(arm, _mesh("were_arm", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.7, 0.05), 0.17, 0.14, 6, fur)
			l.prism(Vector3(0, -0.7, 0.05), Vector3(0, -1.15, 0.2), 0.14, 0.12, 6, fur.darkened(0.1))
			for c in 3:
				l.prism(Vector3(-0.08 + c * 0.08, -1.18, 0.24), Vector3(-0.1 + c * 0.1, -1.42, 0.4), 0.03, 0.0, 4, CLAW)))
		var leg := _pivot(beast, Vector3(side * 0.26, 1.0, 0), "LegL" if side < 0 else "LegR")
		_part(leg, _mesh("were_leg", func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO, Vector3(0, -0.55, -0.08), 0.17, 0.14, 6, fur)
			l.prism(Vector3(0, -0.55, -0.08), Vector3(0, -0.95, 0.04), 0.13, 0.1, 6, fur.darkened(0.12))
			l.box(Vector3(0, -0.97, 0.12), Vector3(0.22, 0.08, 0.3), FUR_DARK)))


static func _earth_parts(root: Node3D, big: bool) -> void:
	var s := 2.0 if big else 1.0
	var body := _pivot(root, Vector3.ZERO, "Body")
	_part(body, _mesh("earth_torso", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.95, 0), Vector3(0, 1.75, 0.05), 0.5, 0.62, 6, STONE)
		l.box(Vector3(0.1, 1.85, 0.05), Vector3(1.05, 0.5, 0.75), STONE.lightened(0.06), Vector3(0, 12, 6))
		l.box(Vector3(-0.3, 1.25, 0.32), Vector3(0.4, 0.36, 0.2), STONE_DARK, Vector3(10, 20, 0))
		l.box(Vector3(0.25, 2.08, 0.1), Vector3(0.6, 0.12, 0.5), MOSS)
		l.box(Vector3(-0.35, 1.55, -0.3), Vector3(0.4, 0.22, 0.2), MOSS)
		for x: float in [-0.25, 0.25]:
			l.prism(Vector3(x, 0.95, 0), Vector3(x * 1.1, 0.05, 0.05), 0.24, 0.3, 5, STONE_DARK)), Vector3.ZERO).scale = Vector3.ONE * s
	var core := _part(body, _mesh("earth_core", func(l: LowPoly) -> void:
		l.prism(Vector3(0, 1.3, 0.36), Vector3(0, 1.62, 0.38), 0.14, 0.08, 5, AMBER)
		l.box(Vector3(0, 2.32, 0.34), Vector3(0.36, 0.06, 0.04), AMBER)), Vector3.ZERO, "Core")
	core.material_override = glow_material()
	core.scale = Vector3.ONE * s
	_part(body, _mesh("earth_head", func(l: LowPoly) -> void:
		l.box(Vector3(0, 2.32, 0.08), Vector3(0.62, 0.48, 0.55), STONE, Vector3(0, 8, 0))
		l.box(Vector3(0, 2.6, 0.0), Vector3(0.5, 0.12, 0.4), MOSS)), Vector3.ZERO).scale = Vector3.ONE * s
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(body, Vector3(side * 0.82, 1.95, 0.05) * s, "ArmL" if side < 0 else "ArmR")
		var part := _part(arm, _mesh("earth_arm", func(l: LowPoly) -> void:
			l.box(Vector3(0, -0.25, 0), Vector3(0.42, 0.42, 0.42), STONE, Vector3(10, 30, 5))
			l.box(Vector3(0, -0.75, 0.05), Vector3(0.38, 0.4, 0.38), STONE_DARK, Vector3(-8, 12, 0))
			l.box(Vector3(0, -1.25, 0.1), Vector3(0.55, 0.5, 0.55), STONE, Vector3(5, 40, 10))
			l.box(Vector3(0.05, -1.0, 0.25), Vector3(0.2, 0.14, 0.1), MOSS)))
		part.scale = Vector3.ONE * s


static func _ring(l: LowPoly, radius: float, y: float, thick: float, col: Color, segments := 20) -> void:
	for i in segments:
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		l.prism(Vector3(cos(a) * radius, y, sin(a) * radius), Vector3(cos(b) * radius, y, sin(b) * radius), thick, thick, 4, col)


## A wyvern's body (WyvernRig), kept as "rig"; its shoulders are its "wing_l" and "wing_r" for the fall.
static func _wyvern_parts(root: Node3D, armoured: bool) -> void:
	var rig := WyvernRig.new(armoured)
	root.add_child(rig)
	root.set_meta("rig", rig)
	root.set_meta("wing_l", rig.shoulders[0])
	root.set_meta("wing_r", rig.shoulders[1])


## When each of the War Wyvern's riders (wyvern_rider) looses its arrow, in seconds into the world's
## shared clock: the second half a draw after the first, so they shoot in turn.
static func rider_cycle(i: int, now: float) -> float:
	return fmod(now + i * BodyAnim.RIDE_SHOT * 0.5, BodyAnim.RIDE_SHOT)


## The Eagle and the Mist Eagle are birds of the shared rig (BirdRig "eagle", "mist_eagle").
static func _eagle_parts(root: Node3D, misty: bool) -> void:
	EnemyModels._bird(root, "mist_eagle" if misty else "eagle")


## The Shapeshifter's white stag as a Cavalry rider's steed (the White Stag cosmetic): facing -Z like
## the horse, sized so its back is where the horse's saddle is. scale_to: the horse's own size.
static func stag_steed(scale_to := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "StagSteed"
	var holder := _pivot(root, Vector3.ZERO, "Stag")
	_quadruped(holder, "stag", _stag_look())
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * 1.12 * scale_to
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("legs", ["LegFL", "LegFR", "LegBL", "LegBR"].map(func(n: String) -> Node3D: return root.find_child(n, true, false) as Node3D))
	return root


## The stag steed's legs swinging, faster and wider the faster it goes (gait 0..1).
static func steed_gait(root: Node3D, gait: float) -> void:
	var t := Time.get_ticks_msec() * 0.016
	var legs: Array = root.get_meta("legs", [])
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(t + (0.0 if i % 3 == 0 else PI)) * 0.7 * clampf(gait, 0.05, 1.0)


## Returns the model. Named nodes and meta are what animate() moves.
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"bear":
			_quadruped(root, "bear", _bear_look(FUR, FUR_DARK, MUZZLE, BLACK, false))
		"mist_bear":
			_quadruped(root, "mist_bear", _bear_look(MIST_FUR, MIST_FUR.darkened(0.3), MIST_FUR.lightened(0.2), MIST_GLOW, true))
		"eagle", "mist_eagle":
			_eagle_parts(root, id == "mist_eagle")
		"shapeshifter":
			var stag_holder := _pivot(root, Vector3.ZERO, "Stag")
			_quadruped(stag_holder, "stag", _stag_look())
			_were_parts(root)
			(root.get_node("Beast") as Node3D).visible = false
			var wolf := _pivot(root, Vector3.ZERO, "Wolf")
			_quadruped(wolf, "mist_wolf", _wolf_look())
			wolf.scale = Vector3.ONE * 1.25 # a wolf bigger than any wolf
			var owl := _pivot(root, Vector3.ZERO, "Owl")
			_owl_parts(owl)
			owl.scale = Vector3.ONE * 1.3
			var boar := _pivot(root, Vector3.ZERO, "Boar")
			_quadruped(boar, "boar", _boar_look())
			boar.scale = Vector3.ONE * 1.3
			for form: Node3D in [wolf, owl, boar]:
				form.visible = false
		"earth_elemental":
			_earth_parts(root, false)
		"great_revenant_elemental":
			_earth_parts(root, true)
			# Mist binds the boulders: pale bands around it, and loose stones that orbit once it is angry.
			var bands := _part(root, _mesh("revenant_bands", func(l: LowPoly) -> void:
				_ring(l, 1.3, 2.4, 0.05, MIST_GLOW)
				_ring(l, 1.15, 3.3, 0.05, MIST_GLOW)
				_ring(l, 0.8, 1.6, 0.04, MIST_GLOW)), Vector3.ZERO, "Bands")
			bands.material_override = glow_material()
			var orbit := _pivot(root, Vector3(0, 3.0, 0), "Orbit")
			for i in 5:
				var a := TAU * i / 5.0
				_part(orbit, _mesh("orbit_stone", func(l: LowPoly) -> void:
					l.box(Vector3.ZERO, Vector3(0.5, 0.42, 0.46), STONE, Vector3(20, 35, 10))
					l.box(Vector3(0, 0.22, 0), Vector3(0.3, 0.06, 0.3), MOSS)), Vector3(cos(a) * 2.2, sin(a * 2.0) * 0.4, sin(a) * 2.2))
			orbit.visible = false
			_label(root, 5.6)
		"mist_elemental":
			var core := _part(root, _mesh("mist_core", func(l: LowPoly) -> void:
				for i in 5:
					var a := TAU * i / 5.0
					l.prism(Vector3(0, 1.4, 0), Vector3(cos(a) * 0.32, 1.4 + sin(a * 3.0) * 0.3, sin(a) * 0.32), 0.09, 0.0, 4, BONE)
				l.prism(Vector3(0, 1.1, 0), Vector3(0, 1.75, 0), 0.0, 0.16, 5, BONE)
				l.prism(Vector3(0, 1.75, 0), Vector3(0, 2.05, 0), 0.16, 0.0, 5, Color(0.6, 1.0, 0.95))), Vector3.ZERO, "Core")
			core.material_override = glow_material()
			var swirl := _pivot(root, Vector3.ZERO, "Swirl")
			var shell := _part(swirl, _mesh("mist_shell", func(l: LowPoly) -> void:
				l.prism(Vector3(0, 0.25, 0), Vector3(0, 1.2, 0), 0.04, 0.55, 7, Color(0.55, 0.78, 0.82))
				l.prism(Vector3(0, 1.2, 0), Vector3(0, 2.1, 0), 0.55, 0.3, 7, Color(0.6, 0.85, 0.88))
				l.prism(Vector3(0, 2.1, 0), Vector3(0, 2.35, 0), 0.3, 0.0, 7, Color(0.7, 0.9, 0.92))))
			shell.material_override = ghost_material()
			var ribbons := _part(swirl, _mesh("mist_ribbons", func(l: LowPoly) -> void:
				for i in 3:
					var y := 0.8 + i * 0.5
					for seg in 14:
						var a := TAU * seg / 14.0 + i
						var b := TAU * (seg + 1) / 14.0 + i
						if seg % 4 == 3:
							continue
						var r := 0.7 + i * 0.05
						l.prism(Vector3(cos(a) * r, y + sin(a * 2.0) * 0.12, sin(a) * r), Vector3(cos(b) * r, y + sin(b * 2.0) * 0.12, sin(b) * r), 0.035, 0.035, 4, MIST_GLOW)), Vector3.ZERO, "Ribbons")
			ribbons.material_override = glow_material()
		"storm_elemental":
			var cloud := _pivot(root, Vector3.ZERO, "Cloud")
			_part(cloud, _mesh("storm_cloud", func(l: LowPoly) -> void:
				var grey := Color(0.32, 0.34, 0.4)
				l.prism(Vector3(0, 1.75, 0), Vector3(0, 2.3, 0), 0.6, 0.45, 7, grey)
				l.prism(Vector3(0.45, 1.85, 0.1), Vector3(0.45, 2.25, 0.1), 0.4, 0.3, 6, grey.lightened(0.08))
				l.prism(Vector3(-0.42, 1.8, -0.1), Vector3(-0.42, 2.2, -0.1), 0.42, 0.28, 6, grey.darkened(0.1))
				l.prism(Vector3(0.05, 2.25, -0.3), Vector3(0.05, 2.55, -0.3), 0.34, 0.18, 6, grey.lightened(0.15))
				l.prism(Vector3(0, 1.4, 0), Vector3(0, 1.75, 0), 0.2, 0.6, 7, grey.darkened(0.25))))
			var eyes := _part(cloud, _mesh("storm_eyes", func(l: LowPoly) -> void:
				for x: float in [-0.18, 0.18]:
					l.box(Vector3(x, 2.0, 0.56), Vector3(0.12, 0.05, 0.04), Color(0.85, 0.95, 1.0))), Vector3.ZERO)
			eyes.material_override = glow_material()
			var bolts := _part(cloud, _mesh("storm_bolts", func(l: LowPoly) -> void:
				var white := Color(0.9, 0.95, 1.0)
				for i in 3:
					var a := TAU * i / 3.0 + 0.4
					var pts := [Vector3(cos(a) * 0.4, 1.5, sin(a) * 0.4), Vector3(cos(a) * 0.55, 1.15, sin(a) * 0.5), Vector3(cos(a) * 0.4, 0.85, sin(a) * 0.62), Vector3(cos(a) * 0.62, 0.5, sin(a) * 0.55)]
					for p in 3:
						l.prism(pts[p], pts[p + 1], 0.03, 0.03, 4, white)), Vector3.ZERO, "Bolts")
			bolts.material_override = glow_material()
			var stones := _pivot(root, Vector3(0, 0.75, 0), "Stones")
			for i in 5:
				var a := TAU * i / 5.0
				_part(stones, _mesh("storm_stone", func(l: LowPoly) -> void:
					l.box(Vector3.ZERO, Vector3(0.26, 0.22, 0.24), STONE_DARK, Vector3(15, 25, 0))
					l.box(Vector3(0, 0.12, 0), Vector3(0.12, 0.04, 0.12), Color(0.6, 0.8, 1.0))), Vector3(cos(a) * 0.85, 0, sin(a) * 0.85))
		"wyvern":
			_wyvern_parts(root, false)
		"war_wyvern":
			_wyvern_parts(root, true)
			_label(root, 4.4)
		"brine_hound":
			_quadruped(root, "brine_hound", VaelModels.hound_look())
		"lantern_jelly":
			VaelModels.jelly_parts(root)
		"angler":
			VaelModels.angler_parts(root)
		"siren":
			VaelModels.siren_parts(root)
		"kraken_arm":
			VaelModels.kraken_parts(root)
		"leviathan":
			VaelModels.leviathan_parts(root)
	return root


static func _label(root: Node3D, high: float) -> void:
	var label := Label3D.new()
	label.name = "BossHealth"
	label.position.y = high
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.82, 0.5)
	label.outline_size = 8
	root.add_child(label)


# --- Movement ----------------------------------------------------------------------

## Called every frame with the creature's state (Zombie._current_anim) and how fast it moves.
static func animate(z: Zombie, root: Node3D, delta: float, moving: float) -> void:
	var t := z.world.now + float(z.net_id) * 0.37
	var state := z._current_anim
	# How long it has been in this state, for moves that play out over time (a maul, a slash).
	if state != str(root.get_meta("act_state", "")):
		root.set_meta("from_state", root.get_meta("act_state", ""))
		root.set_meta("act_state", state)
		root.set_meta("act_t", 0.0)
		if state == "m_swipe":
			root.set_meta("swipes", int(root.get_meta("swipes", 0)) + 1)
	else:
		root.set_meta("act_t", float(root.get_meta("act_t", 0.0)) + delta)
	var speed := clampf(moving / maxf(z._speed, 0.1), 0.0, 1.0) if moving > 0.0 else 0.0
	match z.model_id:
		"bear", "mist_bear":
			_animate_bear(z, root, delta, speed, state)
		"wyvern", "war_wyvern":
			var rig := root.get_meta("rig") as WyvernRig
			var was := rig._beat
			rig.drive(z, delta)
			# A wyvern's wings are heard on each downstroke, on this phone only.
			if z.world.player and was > rig._beat and float(rig._env.get("amp", 0.0)) > 0.3:
				Sfx.play_at("wing_flap", z.position, z.world.player.global_position, -9.0 if z.model_id == "war_wyvern" else -13.0)
		"eagle", "mist_eagle":
			(root.get_meta("bird") as BirdRig).drive(z, delta)
		"shapeshifter":
			_animate_shifter(z, root, delta, speed, state, t)
		"earth_elemental", "great_revenant_elemental":
			var body := root.get_node("Body") as Node3D
			body.position.y = sin(t * 1.5) * 0.04
			var arm_l := body.get_node("ArmL") as Node3D
			var arm_r := body.get_node("ArmR") as Node3D
			var lift := 0.0
			if state == "m_slam":
				lift = -2.6 if z.is_warning() else 0.4
			elif state == "m_throw":
				lift = -2.2
			var swing := sin(t * 4.0) * 0.35 * speed
			arm_l.rotation.x = lerpf(arm_l.rotation.x, lift + swing, minf(1.0, delta * 8.0))
			arm_r.rotation.x = lerpf(arm_r.rotation.x, lift - swing if state != "m_throw" else 0.2, minf(1.0, delta * 8.0))
			body.rotation.z = sin(t * 2.0) * 0.04 * speed
			var orbit := root.get_node_or_null("Orbit") as Node3D
			if orbit:
				orbit.visible = state in ["m_beast", "m_throw", "m_slam"] and z.hp < z.max_hp * 0.5
				orbit.rotation.y = t * 0.9
			_boss_label(z, root)
		"mist_elemental":
			root.position.y = 0.25 + sin(t * 2.2) * 0.12
			(root.get_node("Swirl") as Node3D).rotation.y = t * 1.6
			(root.get_node("Swirl/Ribbons") as Node3D).rotation.y = -t * 2.4
			var fade := 0.2 if state == "m_blink" else 1.0
			root.scale = root.scale.lerp(Vector3.ONE * fade, minf(1.0, delta * 10.0))
		"storm_elemental":
			root.position.y = 0.2 + sin(t * 1.8) * 0.1
			(root.get_node("Stones") as Node3D).rotation.y = t * (2.5 if state == "m_cast" else 0.9)
			var bolts := root.get_node("Cloud/Bolts") as Node3D
			bolts.visible = state == "m_cast" or fmod(t * 3.7, 1.0) > 0.82
			bolts.rotation.y = floor(t * 9.0) * 1.3
			(root.get_node("Cloud") as Node3D).position.y = 0.3 if state == "m_cast" else 0.0
		"brine_hound":
			# A Brine Hound moves as the Mist Wolf does: the same lope, crouch and lunge.
			_animate_wolf(z, root, delta, speed, "m_bite" if state == "m_swipe" else state, float(root.get_meta("act_t", 0.0)))
		"lantern_jelly":
			VaelModels.animate_jelly(z, root, delta, speed, state, t, float(root.get_meta("act_t", 0.0)))
		"angler":
			VaelModels.animate_angler(z, root, delta, speed, state, t, float(root.get_meta("act_t", 0.0)))
		"siren":
			VaelModels.animate_siren(z, root, delta, speed, state, t, float(root.get_meta("act_t", 0.0)))
		"kraken_arm":
			VaelModels.animate_kraken(z, root, delta, state, t, float(root.get_meta("act_t", 0.0)))
		"leviathan":
			VaelModels.animate_leviathan(z, root, delta, state, t, float(root.get_meta("act_t", 0.0)))
	if z.model_id == "war_wyvern":
		_boss_label(z, root)


## A bear, moving like one. It walks in a rolling amble, the legs on each side one after the other,
## the weight swaying from side to side over the hump, the big head carried low and swinging; each
## paw comes up with its sole turned back and goes down flat. Standing, it breathes, shifts its weight
## and lifts its nose to the wind. It charges in a bounding gallop, the back bunching and stretching.
## Its tells: up on its hind legs to roar with its forepaws spread (before the maul), or head down,
## raking the ground with a forepaw and snorting (the Mist Bear, before it charges). The maul brings
## both paws crashing down as it lunges and bites; an ordinary blow is one paw hooked round, left
## and right in turn.
static func _animate_bear(z: Zombie, root: Node3D, delta: float, speed: float, state: String, rear_k := 1.0) -> void:
	var rig := root.get_node("Rig") as Node3D
	var hind := rig.get_node("Hind") as Node3D
	var torso := hind.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var jaw := head.get_node("Jaw") as Node3D
	var now := z.world.now + float(z.net_id) * 0.37
	var act := float(root.get_meta("act_t", 0.0))
	var charging := state == "m_charge"
	var gait := 1.0 if charging else speed
	var strides := 2.3 if charging else lerpf(0.75, 1.45, gait) # strides a second
	var phase := float(root.get_meta("phase", randf())) + delta * strides * (1.0 if charging or gait > 0.02 else 0.0)
	phase = fmod(phase, 1.0)
	root.set_meta("phase", phase)
	var cycle := TAU * phase
	# What every part should be doing now; then each eases towards it.
	var rear := 0.0 # the hind pivot: below 0 up on its hind legs, above 0 the front down
	var lunge := 0.0
	var lift := 0.0
	var roll := 0.0
	var yaw := 0.0
	var head_pitch := 0.0
	var head_yaw := 0.0
	var head_roll := 0.0
	var mouth := 0.0
	var ease := 10.0
	var legs := {}
	for leg_name: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		legs[leg_name] = Vector4.ZERO # swing, spread, knee, paw
	match state:
		"m_rear":
			# Up on its hind legs, forepaws spread and raking the air, roaring with its head shaking.
			var up := smoothstep(0.0, 0.35, act)
			rear = -1.12 * up
			head_pitch = -0.25 * up
			mouth = 0.7 * smoothstep(0.15, 0.3, act)
			head_roll = sin(now * 17.0) * 0.1 * smoothstep(0.2, 0.35, act)
			ease = 9.0
			for leg_name: String in legs:
				if leg_name.begins_with("LegF"):
					var left := leg_name == "LegFL"
					var rake := sin(now * 6.0 + (0.0 if left else 1.9))
					legs[leg_name] = Vector4(-0.95 + rake * 0.3, (-0.5 if left else 0.5) * up, 0.75 + rake * 0.2, 0.6)
				else:
					legs[leg_name] = Vector4(-0.2 * up, 0.0, 0.3 * up, -0.2 * up)
		"m_paw":
			# Head down, rump up, raking the ground with its right forepaw, snorting mist.
			rear = 0.13
			head_pitch = 0.42
			head_yaw = sin(now * 3.1) * 0.12
			mouth = 0.12 + 0.1 * sin(now * 12.0)
			roll = sin(now * 5.0) * 0.05
			var u := fmod(now * 1.7, 1.0)
			var rake := Vector4.ZERO
			if u < 0.35:
				var s := u / 0.35 # forward and up
				rake = Vector4(lerpf(0.45, -0.7, s), 0.06, sin(PI * s) * 1.1, sin(PI * s) * 0.8)
			else:
				var s := (u - 0.35) / 0.65 # dragged back over the ground
				rake = Vector4(lerpf(-0.7, 0.45, s), 0.06, 0.05, -0.15)
			legs["LegFR"] = rake
			legs["LegFL"] = Vector4(-0.12, -0.05, 0.1, 0.0)
			legs["LegBL"] = Vector4(0.1, -0.04, 0.0, 0.0)
			legs["LegBR"] = Vector4(0.1, 0.04, 0.0, 0.0)
			ease = 18.0
		"m_swipe":
			if str(root.get_meta("from_state", "")) == "m_rear":
				# The maul: still higher for a moment, then down on both forepaws as it lunges and bites.
				if act < 0.08:
					rear = -1.25
					head_pitch = -0.3
					mouth = 0.7
					for leg_name: String in ["LegFL", "LegFR"]:
						legs[leg_name] = Vector4(-1.6, -0.3 if leg_name == "LegFL" else 0.3, 1.0, 0.7)
				else:
					var down := smoothstep(0.08, 0.2, act)
					var back := smoothstep(0.24, 0.4, act)
					rear = lerpf(-1.25, 0.2, down) * (1.0 - back)
					lunge = 0.3 * down * (1.0 - back)
					head_pitch = lerpf(-0.3, 0.38, down) * (1.0 - back)
					mouth = 0.7 * (1.0 - smoothstep(0.16, 0.24, act))
					for leg_name: String in ["LegFL", "LegFR"]:
						legs[leg_name] = Vector4(lerpf(-1.6, -0.55, down) * (1.0 - back), (-0.3 if leg_name == "LegFL" else 0.3) * (1.0 - down), lerpf(1.0, 0.0, down), 0.0)
					for leg_name: String in ["LegBL", "LegBR"]:
						legs[leg_name] = Vector4(0.25 * down * (1.0 - back), 0.0, 0.2 * down * (1.0 - back), 0.0)
				ease = 26.0
			else:
				# One paw hooked round from the outside in, the body turning behind it; left, then right.
				var side := 1.0 if int(root.get_meta("swipes", 0)) % 2 == 0 else -1.0
				var paw := "LegFR" if side > 0.0 else "LegFL"
				var wind := smoothstep(0.0, 0.1, act) * (1.0 - smoothstep(0.1, 0.22, act))
				var hit := smoothstep(0.1, 0.22, act) * (1.0 - smoothstep(0.3, 0.5, act))
				rear = -0.25 * wind
				roll = side * (-0.12 * wind + 0.1 * hit)
				yaw = side * (0.12 * wind - 0.22 * hit)
				head_yaw = side * (-0.2 * hit)
				head_pitch = 0.2 * hit
				mouth = 0.5 * hit
				legs[paw] = Vector4(-1.3 * wind - 0.7 * hit, side * (0.55 * wind - 0.35 * hit), 0.9 * wind + 0.1 * hit, 0.5 * wind)
				ease = 24.0
		_:
			if charging:
				# A bounding gallop: forepaws together, then hind paws, the back bunching and stretching.
				rear = sin(cycle) * 0.1
				lift = maxf(0.0, sin(cycle + 0.6)) * 0.1
				head_pitch = 0.3 - sin(cycle) * 0.08
				mouth = 0.3
				var offsets := {"LegFL": 0.0, "LegFR": 0.1, "LegBL": 0.5, "LegBR": 0.6}
				for leg_name: String in offsets:
					legs[leg_name] = _bear_step(phase + float(offsets[leg_name]), 0.75, 0.4, leg_name.begins_with("LegF"))
				ease = 22.0
			elif gait > 0.02:
				# The amble: hind and fore on one side, then the other; rolling over the hump.
				var offsets := {"LegBL": 0.0, "LegFL": 0.25, "LegBR": 0.5, "LegFR": 0.75}
				for leg_name: String in offsets:
					legs[leg_name] = _bear_step(phase + float(offsets[leg_name]), lerpf(0.25, 0.55, gait), 0.62, leg_name.begins_with("LegF")) * Vector4(1, 1, minf(1.0, gait * 2.5), minf(1.0, gait * 2.5))
				roll = sin(cycle) * 0.07 * gait
				yaw = sin(cycle) * 0.05 * gait
				lift = -absf(sin(cycle)) * 0.035 * gait
				head_pitch = 0.14 * gait + sin(cycle * 2.0) * 0.05 * gait
				head_yaw = sin(cycle + 0.8) * 0.16 * gait
				ease = 16.0
			else:
				# Standing: breathing, its weight shifting, now and then its nose up to the wind.
				var sniffing := fmod(now, 6.5) < 1.4
				head_pitch = (-0.28 + sin(now * 15.0) * 0.035) if sniffing else 0.05 + sin(now * 0.6) * 0.04
				head_yaw = sin(now * 0.45) * 0.3
				mouth = 0.05 if sniffing else 0.0
				roll = sin(now * 0.5) * 0.025
				ease = 5.0
	if rear < 0.0:
		rear *= rear_k # with someone on its back, it rears only part of the way
	# Breathing, always: deeper after it has charged or roared.
	torso.scale = Vector3.ONE * (1.0 + sin(now * 2.2) * 0.012 * (1.0 - gait))
	var k := minf(1.0, delta * ease)
	hind.rotation.x = lerpf(hind.rotation.x, rear, k)
	rig.position.y = lerpf(rig.position.y, lift, k)
	rig.position.z = lerpf(rig.position.z, lunge, k)
	torso.rotation.z = lerpf(torso.rotation.z, roll, k)
	rig.rotation.y = lerpf(rig.rotation.y, yaw, k)
	head.rotation.x = lerpf(head.rotation.x, head_pitch, k)
	head.rotation.y = lerpf(head.rotation.y, head_yaw, minf(1.0, delta * ease * 0.6))
	head.rotation.z = lerpf(head.rotation.z, head_roll, k)
	jaw.rotation.x = lerpf(jaw.rotation.x, mouth, minf(1.0, delta * 20.0))
	for leg_name: String in legs:
		var front := leg_name.begins_with("LegF")
		var leg := (torso if front else rig).get_node(leg_name) as Node3D
		var knee := leg.get_node("Knee") as Node3D
		var paw := knee.get_node("Paw") as Node3D
		var want: Vector4 = legs[leg_name]
		leg.rotation.x = lerpf(leg.rotation.x, want.x, k)
		leg.rotation.z = lerpf(leg.rotation.z, want.y, k)
		knee.rotation.x = lerpf(knee.rotation.x, want.z, k)
		paw.rotation.x = lerpf(paw.rotation.x, want.w, k)


## One leg through one stride, at this point (0..1) of it: on the ground for `stance` of the stride,
## sweeping back from in front of the hip to behind it; then up, knee folding and paw turning its sole
## back, and forward again to plant flat. reach: how far forward and back it swings (radians).
static func _bear_step(at: float, reach: float, stance: float, front: bool) -> Vector4:
	var u := fmod(at, 1.0)
	if u < stance:
		return Vector4(lerpf(-reach, reach, u / stance), 0.0, 0.0, 0.0)
	var s := (u - stance) / (1.0 - stance)
	var up := sin(PI * s)
	return Vector4(lerpf(reach, -reach, smoothstep(0.0, 1.0, s)), 0.0, up * (1.15 if front else 0.75), up * 0.9)


# --- The Shapeshifter in each of its shapes ----------------------------------------------------

const SHIFTER_FORMS := ["Stag", "Beast", "Wolf", "Owl", "Boar"]
const SHIFTER_SIZES := {"Stag": 1.0, "Beast": 1.0, "Wolf": 1.25, "Owl": 1.3, "Boar": 1.3}
## Which shape each state shows. A change of shape ("m_shift") shows the last one, shrinking into mist.
const SHIFTER_STATES := {"m_stag": "Stag", "": "Stag", "m_beast": "Beast", "m_swipe": "Beast", "m_wolf": "Wolf", "m_bite": "Wolf",
	"m_lunge": "Wolf", "m_howl": "Wolf", "m_owl": "Owl", "m_dive": "Owl", "m_boar": "Boar", "m_gore": "Boar", "m_paw": "Boar", "m_charge": "Boar"}
const SHIFT_GROW := 0.35 # seconds a new shape takes to come out of the mist


static func _animate_shifter(z: Zombie, root: Node3D, delta: float, speed: float, state: String, t: float) -> void:
	var act := float(root.get_meta("act_t", 0.0))
	var form := str(root.get_meta("form", "Stag"))
	var size_k := 1.0
	if state == "m_shift":
		# The old shape shrinks and shudders into the mist.
		size_k = maxf(0.25, 1.0 - act * 1.1) * (1.0 + sin(act * 40.0) * 0.05)
	else:
		var now_form: String = SHIFTER_STATES.get(state, form)
		if now_form != form:
			form = now_form
			root.set_meta("form", form)
			root.set_meta("grown", 0.0)
		var grown := minf(1.0, float(root.get_meta("grown", 1.0)) + delta / SHIFT_GROW)
		root.set_meta("grown", grown)
		size_k = lerpf(0.4, 1.0, smoothstep(0.0, 1.0, grown))
	for f: String in SHIFTER_FORMS:
		var holder := root.get_node(f) as Node3D
		holder.visible = f == form
		if f == form:
			holder.scale = Vector3.ONE * float(SHIFTER_SIZES[f]) * size_k
	var holder := root.get_node(form) as Node3D
	match form:
		"Stag": _animate_quadruped(z, holder, delta, speed, state, true)
		"Beast": _walk_upright(holder, t, speed, state == "m_swipe", act, delta)
		"Wolf": _animate_wolf(z, holder, delta, speed, state, act)
		"Boar": _animate_boar(z, holder, delta, speed, state, act)
		"Owl": _animate_owl(z, holder, delta, state, act)


## The parts of a four-legged shape, as a dictionary, so a pose can be eased onto them.
static func _four(holder: Node3D) -> Dictionary:
	var rig := holder.get_node("Rig") as Node3D
	var hind := rig.get_node("Hind") as Node3D
	var torso := hind.get_node("Torso") as Node3D
	return {"rig": rig, "hind": hind, "torso": torso, "head": torso.get_node("Head"), "jaw": torso.get_node("Head/Jaw"), "tail": torso.get_node_or_null("Tail")}


## Eases a four-legged shape towards a pose: rear (hind pivot), lift and lunge (the whole body),
## the head's pitch and turn, the jaw, the tail's lift and swing, and each leg's swing, spread, knee
## and paw (as from _bear_step).
static func _ease_four(parts: Dictionary, pose: Dictionary, legs: Dictionary, k: float) -> void:
	var rig := parts["rig"] as Node3D
	(parts["hind"] as Node3D).rotation.x = lerpf((parts["hind"] as Node3D).rotation.x, float(pose.get("rear", 0.0)), k)
	rig.position.y = lerpf(rig.position.y, float(pose.get("lift", 0.0)), k)
	rig.position.z = lerpf(rig.position.z, float(pose.get("lunge", 0.0)), k)
	rig.rotation.x = lerpf(rig.rotation.x, float(pose.get("pitch", 0.0)), k)
	var head := parts["head"] as Node3D
	head.rotation.x = lerpf(head.rotation.x, float(pose.get("head", 0.0)), k)
	head.rotation.y = lerpf(head.rotation.y, float(pose.get("look", 0.0)), k)
	var jaw := parts["jaw"] as Node3D
	jaw.rotation.x = lerpf(jaw.rotation.x, float(pose.get("jaw", 0.0)), minf(1.0, k * 1.6))
	var tail := parts["tail"] as Node3D
	if tail:
		tail.rotation.x = lerpf(tail.rotation.x, float(pose.get("tail_up", 0.0)), k)
		tail.rotation.y = float(pose.get("wag", 0.0))
	var torso := parts["torso"] as Node3D
	for leg_name: String in legs:
		var front := leg_name.begins_with("LegF")
		var leg := (torso if front else rig).get_node(leg_name) as Node3D
		var knee := leg.get_node("Knee") as Node3D
		var paw := knee.get_node_or_null("Paw") as Node3D
		var want: Vector4 = legs[leg_name]
		leg.rotation.x = lerpf(leg.rotation.x, want.x, k)
		leg.rotation.z = lerpf(leg.rotation.z, want.y, k)
		knee.rotation.x = lerpf(knee.rotation.x, want.z, k)
		if paw:
			paw.rotation.x = lerpf(paw.rotation.x, want.w, k)


## The legs at this point of a stride: trotting (diagonal pairs) or galloping (fore together, hind
## together).
static func _stride(phase: float, reach: float, gallop: bool) -> Dictionary:
	var offsets := {"LegFL": 0.0, "LegFR": 0.1, "LegBL": 0.5, "LegBR": 0.6} if gallop else {"LegFL": 0.0, "LegBR": 0.0, "LegFR": 0.5, "LegBL": 0.5}
	var legs := {}
	for leg_name: String in offsets:
		legs[leg_name] = _bear_step(phase + float(offsets[leg_name]), reach, 0.42 if gallop else 0.55, leg_name.begins_with("LegF"))
	return legs


static func _advance_phase(root: Node3D, delta: float, strides: float) -> float:
	var phase := fmod(float(root.get_meta("phase", randf())) + delta * strides, 1.0)
	root.set_meta("phase", phase)
	return phase


## The Mist Wolf: a long, easy trot that becomes a flat-out gallop, its tail streaming; it crouches
## low before it lunges, then flies at you stretched out, forelegs reaching; it sits back on its
## haunches to howl with its head thrown up; a bite is the head snapping forward.
static func _animate_wolf(z: Zombie, holder: Node3D, delta: float, speed: float, state: String, act: float) -> void:
	var parts := _four(holder)
	var now := z.world.now + float(z.net_id) * 0.37
	var gallop := speed > 0.6
	var phase := _advance_phase(holder, delta, lerpf(1.2, 2.4, speed) if speed > 0.02 else 0.0)
	var pose := {"head": 0.05 + sin(now * 0.8) * 0.05, "look": sin(now * 0.5) * 0.3 * (1.0 - speed), "tail_up": 0.15, "wag": sin(now * 6.0) * 0.25}
	var legs := {}
	for leg_name: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		legs[leg_name] = Vector4.ZERO
	var k := minf(1.0, delta * 12.0)
	match state:
		"m_lunge":
			if z.is_warning():
				# Crouched low, haunches gathered, head level and fixed on you.
				pose = {"lift": -0.16, "rear": 0.08, "head": -0.05, "tail_up": -0.3, "jaw": 0.15}
				legs = {"LegFL": Vector4(-0.3, 0, 0.9, 0.3), "LegFR": Vector4(-0.3, 0, 0.9, 0.3), "LegBL": Vector4(-0.5, 0, 0.9, 0.0), "LegBR": Vector4(-0.5, 0, 0.9, 0.0)}
			else:
				# In the air, stretched out, jaws open.
				pose = {"lift": 0.28, "pitch": -0.1, "head": 0.1, "jaw": 0.55, "tail_up": 0.35}
				legs = {"LegFL": Vector4(-1.1, 0, 0.1, -0.3), "LegFR": Vector4(-1.0, 0, 0.1, -0.3), "LegBL": Vector4(0.9, 0, 0.2, 0.3), "LegBR": Vector4(0.95, 0, 0.2, 0.3)}
			k = minf(1.0, delta * 20.0)
		"m_howl":
			# Sat back on its haunches, head up, howling.
			var up := smoothstep(0.0, 0.3, act)
			# (Its forelegs stay straight down under its raised chest; its haunches sink to the ground.)
			pose = {"rear": -0.42 * up, "lift": -0.3 * up, "head": -0.8 * up, "jaw": 0.55 * up + sin(now * 9.0) * 0.06, "tail_up": -0.4, "look": 0.0}
			legs = {"LegFL": Vector4(0.42 * up, 0, 0.0, 0.0), "LegFR": Vector4(0.42 * up, 0, 0.0, 0.0), "LegBL": Vector4(-1.0 * up, 0, 1.6 * up, -0.5 * up), "LegBR": Vector4(-1.0 * up, 0, 1.6 * up, -0.5 * up)}
		"m_bite":
			var snap := sin(clampf(act / 0.3, 0.0, 1.0) * PI)
			pose = {"head": 0.3 * snap, "lunge": 0.25 * snap, "jaw": 0.6 * (1.0 - smoothstep(0.1, 0.2, act)), "tail_up": 0.3, "wag": 0.0}
			legs = _stride(0.25, 0.3, false)
		_:
			if speed > 0.02:
				legs = _stride(phase, lerpf(0.35, 0.8, speed), gallop)
				pose["lift"] = -absf(sin(TAU * phase)) * 0.04 * speed
				pose["head"] = 0.18 * speed
				pose["tail_up"] = 0.3 + 0.2 * speed
				pose["wag"] = sin(TAU * phase) * 0.15
				pose["pitch"] = sin(TAU * phase) * 0.06 * float(gallop)
				k = minf(1.0, delta * 16.0)
	_ease_four(parts, pose, legs, k)


## The Tusked Boar: a quick, stiff-legged trot, its head low; it rakes the ground with a forehoof and
## snorts before it charges, then charges flat out with its head down; its blow is a toss of the tusks.
static func _animate_boar(z: Zombie, holder: Node3D, delta: float, speed: float, state: String, act: float) -> void:
	var parts := _four(holder)
	var now := z.world.now + float(z.net_id) * 0.37
	var charging := state == "m_charge"
	var go := 1.0 if charging else speed
	var phase := _advance_phase(holder, delta, (2.8 if charging else lerpf(1.6, 2.6, speed)) if go > 0.02 else 0.0)
	var pose := {"head": 0.12 + sin(now * 1.3) * 0.04, "look": sin(now * 0.7) * 0.25 * (1.0 - speed), "wag": sin(now * 9.0) * 0.4}
	var legs := {}
	for leg_name: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		legs[leg_name] = Vector4.ZERO
	var k := minf(1.0, delta * 14.0)
	match state:
		"m_paw":
			pose = {"rear": 0.1, "head": 0.4, "look": sin(now * 3.0) * 0.12, "jaw": 0.1 + 0.1 * sin(now * 14.0), "wag": sin(now * 14.0) * 0.5}
			var u := fmod(now * 1.9, 1.0)
			var rake := Vector4(lerpf(0.4, -0.6, u / 0.35), 0.0, sin(PI * u / 0.35) * 1.0, 0.0) if u < 0.35 else Vector4(lerpf(-0.6, 0.4, (u - 0.35) / 0.65), 0.0, 0.05, 0.0)
			legs["LegFR"] = rake
			k = minf(1.0, delta * 18.0)
		"m_gore":
			# The toss: head down, then up and round with the tusks.
			var toss := smoothstep(0.05, 0.2, act) * (1.0 - smoothstep(0.3, 0.5, act))
			pose = {"head": lerpf(0.45, -0.6, toss), "look": 0.35 * toss, "lunge": 0.2 * toss, "jaw": 0.3 * toss, "rear": -0.12 * toss}
			k = minf(1.0, delta * 22.0)
		_:
			if go > 0.02:
				legs = _stride(phase, lerpf(0.3, 0.75, go), charging)
				pose["lift"] = -absf(sin(TAU * phase)) * 0.05 * go
				pose["head"] = 0.42 if charging else 0.2
				pose["pitch"] = sin(TAU * phase) * 0.07 * float(charging)
				pose["wag"] = 0.0 if charging else pose["wag"]
				k = minf(1.0, delta * 18.0)
	_ease_four(parts, pose, legs, k)


## The Great Owl: slow, deep, silent beats and long glides; before it strikes it hangs in the air on
## wide, fast wings, head thrust forward, screeching; it falls on you with its wings swept back and its
## talons thrown forward at the last.
static func _animate_owl(z: Zombie, holder: Node3D, delta: float, state: String, act: float) -> void:
	var body := holder.get_node("Body") as Node3D
	var head := body.get_node("Head") as Node3D
	var talons := body.get_node("Talons") as Node3D
	var tail := body.get_node("Tail") as Node3D
	var now := z.world.now + float(z.net_id) * 0.37
	var hanging := state == "m_owl" and z.is_warning()
	var diving := state == "m_dive"
	var rate := 3.4 if hanging else 1.5
	var beat := fmod(float(holder.get_meta("beat", 0.0)) + delta * rate, 1.0)
	holder.set_meta("beat", beat)
	var glide := 0.0 if hanging or diving else smoothstep(0.55, 0.75, fmod(now * 0.25, 1.0)) * (1.0 - smoothstep(0.9, 1.0, fmod(now * 0.25, 1.0)))
	var amp := (1.0 if hanging else 0.75) * (1.0 - glide)
	var cyc := TAU * beat
	var lift := 0.15 + amp * 0.8 * cos(cyc)
	var fold := maxf(0.0, -sin(cyc)) * amp * 0.8
	var sweep := 0.0
	var pitch := 0.1
	var claws := 0.9
	var head_x := -0.1
	if hanging:
		pitch = -0.55
		head_x = 0.5 + sin(now * 20.0) * 0.05
		claws = 0.2
	elif diving:
		# Wings swept back; at the end of the fall, the talons forward and the wings thrown open.
		var strike := smoothstep(0.35, 0.6, act)
		lift = lerpf(0.5, 1.0, strike)
		fold = lerpf(1.1, 0.0, strike)
		sweep = lerpf(1.0, -0.2, strike)
		pitch = lerpf(0.9, -0.6, strike)
		claws = lerpf(1.2, -1.2, strike)
		head_x = lerpf(-0.5, 0.2, strike)
	var k := minf(1.0, delta * 10.0)
	for side: float in [-1.0, 1.0]:
		var wing := body.get_node("WingL" if side < 0 else "WingR") as Node3D
		wing.rotation = Vector3(0.0, side * sweep, side * lift)
		(wing.get_node("Tip") as Node3D).rotation = Vector3(0.0, side * fold, -side * fold * 0.5)
	body.rotation.x = lerpf(body.rotation.x, pitch, k)
	body.position.y = 1.0 + 0.06 * amp * sin(cyc)
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
	# An owl's head turns further than any other bird's, and snaps round to look.
	head.rotation.y = lerpf(head.rotation.y, 0.0 if hanging or diving else sin(floor(now * 0.7) * 2.3) * 1.2, minf(1.0, delta * 9.0))
	talons.rotation.x = lerpf(talons.rotation.x, claws, k)
	tail.rotation.x = lerpf(tail.rotation.x, -0.3 if hanging else 0.1, k)
	tail.scale.x = 1.4 if hanging or glide > 0.5 else 1.0


## The owl struck down: it tumbles, and lies with one wing spread.
static func _fall_owl(holder: Node3D, k: float, side: float) -> void:
	var body := holder.get_node("Body") as Node3D
	var over := smoothstep(0.0, 0.6, k)
	body.rotation.z = side * 1.4 * over
	body.position.y = lerpf(1.0, 0.35, over)
	var near := body.get_node("WingL" if side > 0 else "WingR") as Node3D
	var far := body.get_node("WingR" if side > 0 else "WingL") as Node3D
	near.rotation.z = lerpf(near.rotation.z, 0.0, over)
	far.rotation.z = lerpf(far.rotation.z, side * -0.2, over)


## Walking, trotting or galloping on four legs, rearing up, mauling and charging. Each leg swings
## from the hip and folds at the knee while it comes forward, so the paws lift off the ground.
static func _animate_quadruped(z: Zombie, root: Node3D, delta: float, speed: float, state: String, light: bool) -> void:
	var rig := root.get_node("Rig") as Node3D
	var hind := rig.get_node("Hind") as Node3D
	var torso := hind.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var k := minf(1.0, delta * 10.0)
	var charging := state == "m_charge"
	var gait := 1.0 if charging else speed
	# The legs' clock runs faster the faster it goes, and keeps its place between frames.
	var pace := lerpf(5.5, 9.0, gait) if not light else lerpf(6.5, 10.5, gait)
	var phase := float(root.get_meta("phase", randf() * TAU)) + delta * pace * (0.25 + gait)
	root.set_meta("phase", fmod(phase, TAU * 8.0))
	var amp := lerpf(0.0, 0.55, gait) if not charging else 0.8
	var offsets := {"LegFL": 0.0, "LegBR": PI * 0.5 if not charging else PI, "LegFR": PI if not charging else 0.25, "LegBL": PI * 1.5 if not charging else PI + 0.25}
	var rear := 0.0
	var head_pitch := sin(phase * 2.0) * 0.06 * gait
	var bob := absf(sin(phase)) * 0.05 * gait
	if state == "m_rear":
		rear = -0.95
		head_pitch = -0.45
		bob = 0.0
	elif state == "m_swipe":
		# The maul: forepaws flung up, then brought down hard with the head lunging after them.
		var act := float(root.get_meta("act_t", 0.0))
		rear = -0.4 if act < 0.12 else 0.16
		head_pitch = -0.2 if act < 0.12 else 0.4
		bob = 0.0
	elif charging:
		head_pitch = 0.22
	else:
		# Breathing while it stands.
		torso.scale = Vector3.ONE * (1.0 + sin(z.world.now * 2.2 + float(z.net_id)) * 0.012 * (1.0 - gait))
	hind.rotation.x = lerpf(hind.rotation.x, rear, minf(1.0, delta * (16.0 if state == "m_swipe" else 7.0)))
	# Lower at the ends of each stride, when the legs reach out furthest.
	rig.position.y = lerpf(rig.position.y, -bob if state != "m_rear" else 0.0, k)
	rig.rotation.x = lerpf(rig.rotation.x, sin(phase * 2.0) * 0.05 if charging else 0.0, k)
	head.rotation.x = lerpf(head.rotation.x, head_pitch, k)
	head.rotation.y = lerpf(head.rotation.y, sin(z.world.now * 0.7 + float(z.net_id)) * 0.25 * (1.0 - gait), minf(1.0, delta * 3.0))
	for leg_name: String in offsets:
		var leg := (torso if leg_name.begins_with("LegF") else rig).get_node(leg_name) as Node3D
		var knee := leg.get_node("Knee") as Node3D
		var front := leg_name.begins_with("LegF")
		var swing := 0.0
		var fold := 0.0
		if state == "m_rear" and front:
			# Up on its hind legs, the forepaws claw at the air.
			swing = -0.7 + sin(z.world.now * 9.0 + (0.0 if leg_name == "LegFL" else 1.6)) * 0.35
			fold = 0.9
		elif state == "m_swipe" and front:
			var act := float(root.get_meta("act_t", 0.0))
			swing = -1.35 if act < 0.12 else -0.35 + (0.12 if leg_name == "LegFL" else -0.05)
			fold = 1.0 if act < 0.12 else 0.0
		else:
			var a: float = phase + float(offsets[leg_name])
			swing = -sin(a) * amp
			# Folded while the leg comes forward, straight while it carries the weight.
			fold = maxf(0.0, cos(a)) * amp * (1.5 if front else 1.1)
			if not front:
				fold *= 0.8
		leg.rotation.x = lerpf(leg.rotation.x, swing, minf(1.0, delta * 18.0))
		knee.rotation.x = lerpf(knee.rotation.x, fold, minf(1.0, delta * 18.0))


## The beast on two legs: a heavy stride with the arms swinging, and a slash that winds up over the
## shoulder, twists through the body and rakes down and across.
static func _walk_upright(beast: Node3D, t: float, speed: float, swiping: bool, act: float, delta: float) -> void:
	var step := sin(t * 7.0) * 0.6 * speed
	var leg_l := beast.get_node("LegL") as Node3D
	var leg_r := beast.get_node("LegR") as Node3D
	var arm_l := beast.get_node("ArmL") as Node3D
	var arm_r := beast.get_node("ArmR") as Node3D
	var head := beast.get_node("Head") as Node3D
	var k := minf(1.0, delta * 20.0)
	var target := {"arm_l": Vector3(-step * 0.6 - 0.2, 0, 0.15), "arm_r": Vector3(step * 0.6 - 0.2, 0, -0.15), "lean": 0.12 * speed, "twist": 0.0, "head": 0.0}
	if swiping:
		if act < 0.16:
			# Wind up: the right arm high and back, the body turning away.
			target = {"arm_l": Vector3(-0.9, 0, 0.4), "arm_r": Vector3(-2.7, 0, -0.5), "lean": -0.15, "twist": -0.45, "head": -0.2}
		elif act < 0.34:
			# The rake: down and across, the body coming round behind it.
			target = {"arm_l": Vector3(-0.4, 0, 0.3), "arm_r": Vector3(0.35, 0, 0.6), "lean": 0.35, "twist": 0.4, "head": 0.25}
		else:
			target = {"arm_l": Vector3(-0.5, 0, 0.25), "arm_r": Vector3(0.1, 0, 0.3), "lean": 0.25, "twist": 0.2, "head": 0.15}
		step = 0.0
	leg_l.rotation.x = lerpf(leg_l.rotation.x, step if not swiping else 0.35, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -step if not swiping else -0.3, k)
	var al: Vector3 = target["arm_l"]
	var ar: Vector3 = target["arm_r"]
	arm_l.rotation = arm_l.rotation.lerp(al, k)
	arm_r.rotation = arm_r.rotation.lerp(ar, k)
	beast.rotation.x = lerpf(beast.rotation.x, float(target["lean"]), k)
	beast.rotation.y = lerpf(beast.rotation.y, float(target["twist"]), k)
	head.rotation.x = lerpf(head.rotation.x, float(target["head"]), k)
	# A heavy body bobs with each step.
	beast.position.y = -absf(sin(t * 7.0)) * 0.06 * speed


# --- Falling ----------------------------------------------------------------------------

## Every pivot and part where the body was built, so a body that fell can stand up again when the
## same creature is used again.
static func remember_pose(root: Node3D) -> void:
	root.set_meta("rest", root.transform)
	for n in root.find_children("*", "Node3D", true, false):
		(n as Node3D).set_meta("rest", (n as Node3D).transform)


static func reset_pose(root: Node3D) -> void:
	root.transform = root.get_meta("rest", root.transform)
	for n in root.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		if node.has_meta("rest"):
			node.transform = node.get_meta("rest")
		node.remove_meta("fall")
		if node is MeshInstance3D or node is Label3D:
			node.visible = true
	root.remove_meta("side")
	# The Shapeshifter stands as a stag again, the Revenant's stones are still.
	var beast := root.get_node_or_null("Beast") as Node3D
	if beast:
		beast.visible = false
		for form: String in ["Wolf", "Owl", "Boar"]:
			(root.get_node(form) as Node3D).visible = false
		root.set_meta("form", "Stag")
		root.remove_meta("dies_as")
	var orbit := root.get_node_or_null("Orbit") as Node3D
	if orbit:
		orbit.visible = false
	if root.has_meta("rig"):
		(root.get_meta("rig") as WyvernRig).restart()
	if root.has_meta("bird"):
		(root.get_meta("bird") as BirdRig).restart()


## How long each kind takes to die before the body is gone.
static func death_time(id: String) -> float:
	match id:
		"great_revenant_elemental", "war_wyvern":
			return 3.2
		"mist_elemental", "storm_elemental":
			return 1.8
		"kraken_arm":
			return 2.8
		"leviathan":
			return 4.2
	return 2.6


## The moment it dies: which way it falls, and the boss's name taken down.
static func begin_death(z: Zombie, root: Node3D) -> void:
	root.set_meta("side", -1.0 if randf() < 0.5 else 1.0)
	if root.has_meta("rig"):
		(root.get_meta("rig") as WyvernRig).stop()
	var label := root.get_node_or_null("BossHealth") as Label3D
	if label:
		label.visible = false
	var as_beast := false
	var beast := root.get_node_or_null("Beast") as Node3D
	if beast and beast.visible:
		as_beast = true
	root.set_meta("as_beast", as_beast)
	if z.model_id == "shapeshifter":
		# It dies in the shape it is in.
		var shown := str(root.get_meta("form", "Stag"))
		for form: String in SHIFTER_FORMS:
			var holder := root.get_node(form) as Node3D
			holder.visible = form == shown
			holder.scale = Vector3.ONE * float(SHIFTER_SIZES[form])
		root.set_meta("dies_as", shown)
	# Pieces that come apart: their own way out and their own spin.
	var loose: Array[Node3D] = []
	match z.model_id:
		"earth_elemental", "great_revenant_elemental":
			var body := root.get_node("Body") as Node3D
			for n in body.get_children():
				loose.append(n as Node3D)
			var orbit := root.get_node_or_null("Orbit") as Node3D
			if orbit:
				for n in orbit.get_children():
					loose.append(n as Node3D)
		"storm_elemental":
			for n in root.get_node("Stones").get_children():
				loose.append(n as Node3D)
	var size := 2.0 if z.model_id == "great_revenant_elemental" else 1.0
	for piece in loose:
		var out := Vector3(piece.position.x, 0.0, piece.position.z)
		out = out.normalized() if out.length() > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		piece.set_meta("fall", {"v": out * randf_range(0.6, 1.6) * size + Vector3.UP * randf_range(0.5, 1.8) * size,
			"spin": Vector3(randf_range(-4, 4), randf_range(-3, 3), randf_range(-4, 4)), "rest": false, "delay": randf_range(0.0, 0.35)})


## Each frame of a death, k seconds after it began.
static func animate_death(z: Zombie, root: Node3D, k: float, delta: float) -> void:
	var side := float(root.get_meta("side", 1.0))
	var total := death_time(z.model_id)
	# The last moments: the body sinks into the ground and is gone.
	var sink := clampf((k - (total - 0.7)) / 0.7, 0.0, 1.0)
	match z.model_id:
		"bear", "mist_bear":
			_fall_quadruped(root, k, side, 0.5)
			root.position.y = -sink * 1.0
		"brine_hound":
			_fall_quadruped(root, k, side, 0.24)
			root.position.y = -sink * 0.8
		"lantern_jelly":
			VaelModels.fall_jelly(root, k, delta)
		"angler":
			VaelModels.fall_angler(root, k, side)
			root.position.y = -sink * 1.0
		"siren":
			VaelModels.fall_siren(root, k, side)
			root.position.y = -sink * 0.8
		"kraken_arm":
			VaelModels.fall_kraken(root, k, side)
		"leviathan":
			VaelModels.fall_leviathan(root, k, side)
		"shapeshifter":
			match str(root.get_meta("dies_as", "Stag")):
				"Beast": _fall_upright(root.get_node("Beast") as Node3D, k, side)
				"Owl": _fall_owl(root.get_node("Owl") as Node3D, k, side)
				"Wolf": _fall_quadruped(root.get_node("Wolf") as Node3D, k, side, 0.22)
				"Boar": _fall_quadruped(root.get_node("Boar") as Node3D, k, side, 0.3)
				_: _fall_quadruped(root.get_node("Stag") as Node3D, k, side, 0.32)
			root.position.y = -sink * 1.2
		"eagle", "mist_eagle", "wyvern", "war_wyvern", "crow":
			_fall_flyer(z, root, k, delta, side)
			root.position.y -= sink * delta * 1.6
		"earth_elemental", "great_revenant_elemental":
			_crumble(z, root, k, delta)
			var bands := root.get_node_or_null("Bands") as Node3D
			if bands:
				bands.scale = Vector3.ONE * maxf(0.01, 1.0 - k * 1.2)
				bands.rotation.y += delta * 3.0
			root.position.y = -sink * 0.8
		"mist_elemental":
			# Spun apart: the swirl whirls faster and wider, rises and thins to nothing.
			var swirl := root.get_node("Swirl") as Node3D
			swirl.rotation.y += delta * (3.0 + k * 14.0)
			swirl.scale = Vector3.ONE * (1.0 + k * 0.9)
			(root.get_node("Swirl/Ribbons") as Node3D).rotation.y -= delta * 8.0
			(root.get_node("Core") as Node3D).scale = Vector3.ONE * maxf(0.01, 1.0 - k * 1.4)
			root.position.y += delta * 0.9
			root.scale = Vector3.ONE * maxf(0.01, 1.0 - clampf((k - 0.5) / 1.2, 0.0, 1.0))
		"storm_elemental":
			# It bursts: the cloud swells and tears, lightning flickers, the stones fall.
			var cloud := root.get_node("Cloud") as Node3D
			var swell := 1.0 + minf(k, 0.35) * 1.6
			cloud.scale = Vector3.ONE * swell * maxf(0.01, 1.0 - clampf((k - 0.5) / 1.0, 0.0, 1.0))
			cloud.rotation.y += delta * 5.0
			var bolts := cloud.get_node("Bolts") as Node3D
			bolts.visible = k < 1.1 and fmod(k * 13.0, 1.0) > 0.4
			bolts.rotation.y = floor(k * 17.0) * 1.7
			for stone in root.get_node("Stones").get_children():
				_tumble(z, stone as Node3D, k, delta, 0.13)


## Four legs give way: a stagger, then over onto its side, legs stiff, and still.
static func _fall_quadruped(holder: Node3D, k: float, side: float, girth: float) -> void:
	var rig := holder.get_node("Rig") as Node3D
	var hind := rig.get_node("Hind") as Node3D
	var torso := hind.get_node("Torso") as Node3D
	var head := torso.get_node("Head") as Node3D
	var over := smoothstep(0.18, 0.75, k)
	# A last lurch up on the forelegs before it goes over.
	hind.rotation.x = -0.25 * sin(clampf(k / 0.4, 0.0, 1.0) * PI) * (1.0 - over)
	rig.rotation.z = side * 1.45 * over + side * 0.1 * sin(clampf((k - 0.75) / 0.3, 0.0, 1.0) * PI)
	rig.position.y = girth * over
	head.rotation.x = lerpf(0.0, 0.35, over)
	head.rotation.z = -side * 0.4 * over
	var jaw := head.get_node_or_null("Jaw") as Node3D
	if jaw:
		# A last roar as it staggers, and then the jaw hangs slack.
		jaw.rotation.x = 0.55 * sin(clampf(k / 0.5, 0.0, 1.0) * PI) + 0.18 * over
	var twitch := sin(k * 22.0) * 0.12 * clampf((k - 0.8) / 0.2, 0.0, 1.0) * clampf((1.5 - k) / 0.4, 0.0, 1.0)
	for leg_name: String in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		var front := leg_name.begins_with("LegF")
		var leg := (torso if front else rig).get_node(leg_name) as Node3D
		var knee := leg.get_node("Knee") as Node3D
		leg.rotation.x = lerpf(leg.rotation.x, (-0.45 if front else 0.4) + twitch, minf(1.0, over * 0.3 + 0.05))
		knee.rotation.x = lerpf(knee.rotation.x, 0.15, minf(1.0, over * 0.3 + 0.05))


## Standing up when it dies: the knees go, it falls back and lies with its arms flung out.
static func _fall_upright(body: Node3D, k: float, side: float) -> void:
	var over := smoothstep(0.1, 0.8, k)
	body.rotation.x = -1.5 * over
	body.rotation.z = side * 0.25 * over
	body.position.y = 0.25 * over
	for leg_name: String in ["LegL", "LegR"]:
		(body.get_node(leg_name) as Node3D).rotation.x = lerpf(0.0, 0.9, smoothstep(0.0, 0.35, k)) * (1.0 - over * 0.6)
	(body.get_node("ArmL") as Node3D).rotation.z = -1.2 * over
	(body.get_node("ArmR") as Node3D).rotation.z = 1.2 * over
	(body.get_node("Head") as Node3D).rotation.x = -0.4 * over


## A flyer shot down: wings flail and the body tips nose-first as it drops; on the ground it rolls
## onto its side with a wing crumpled under it.
static func _fall_flyer(z: Zombie, root: Node3D, k: float, delta: float, side: float) -> void:
	var landed := z.position.y - z.world.ground_at(z.position) < 0.05
	if not landed:
		root.set_meta("landed_at", -1.0)
	elif float(root.get_meta("landed_at", -1.0)) < 0.0:
		root.set_meta("landed_at", k)
	var since := k - float(root.get_meta("landed_at", -1.0)) if landed else 0.0
	var flail := sin(k * 15.0) * 1.0 * maxf(0.0, 1.0 - k * 0.6) if not landed else 0.0
	var wing_l := root.get_meta("wing_l") as Node3D
	var wing_r := root.get_meta("wing_r") as Node3D
	var body := root.get_node_or_null("Body") as Node3D
	if root.has_meta("rig"):
		body = (root.get_meta("rig") as WyvernRig).body
	elif root.has_meta("bird"):
		body = (root.get_meta("bird") as BirdRig).body
	var big := z.model_id.ends_with("wyvern")
	if not landed:
		wing_l.rotation.z = flail
		wing_r.rotation.z = -flail
		if body:
			body.rotation.x = lerpf(body.rotation.x, 0.8, minf(1.0, delta * 3.0))
			(body.get_node("Tail") as Node3D).rotation.y = sin(k * 9.0) * 0.6
		else:
			root.rotation.z += delta * 9.0 * side
	else:
		var lie := smoothstep(0.0, 0.45, since)
		# Down: the body comes level, rolls over, and the wings lie flat, one of them folded.
		root.rotation.z = lerpf(root.rotation.z if body == null else 0.0, side * (1.2 if body else 1.5), lie)
		if body:
			body.rotation.x = lerpf(0.8, 0.0, lie)
			root.position.y = lerpf(0.0, (0.08 * (root.get_meta("bird") as BirdRig).scale.y) if root.has_meta("bird") else 0.35 * body.scale.y, lie)
		wing_l.rotation.z = lerpf(wing_l.rotation.z, 0.2 if side > 0 else -1.3, lie)
		wing_r.rotation.z = lerpf(wing_r.rotation.z, 1.3 if side > 0 else -0.2, lie)
		if big and since < delta * 1.5:
			z.world.fx_gore(z.position + Vector3.UP * 0.2, Color(0.45, 0.4, 0.34))


## Stone coming apart: the arms and the body break into their pieces, which fall and roll away while
## the glowing core goes out.
static func _crumble(z: Zombie, root: Node3D, k: float, delta: float) -> void:
	var body := root.get_node("Body") as Node3D
	var core := body.get_node_or_null("Core") as Node3D
	if k < 0.3:
		# A shudder first.
		body.position.x = sin(k * 70.0) * 0.05
		body.rotation.x = k * 0.5
		return
	for piece in body.get_children():
		_tumble(z, piece as Node3D, k - 0.3, delta, 0.25 if z.model_id == "earth_elemental" else 0.5)
	if core:
		core.scale = Vector3.ONE * maxf(0.01, 1.0 - (k - 0.3) * 1.5) * (1.0 + sin(k * 40.0) * 0.15) * (2.0 if z.model_id == "great_revenant_elemental" else 1.0)
	var orbit := root.get_node_or_null("Orbit") as Node3D
	if orbit and orbit.visible:
		for stone in orbit.get_children():
			_tumble(z, stone as Node3D, k, delta, 0.2)


## One loose piece: thrown out, falling, spinning, and coming to rest on the ground.
static func _tumble(z: Zombie, piece: Node3D, k: float, delta: float, rest_height: float) -> void:
	var fall: Variant = piece.get_meta("fall", null)
	if fall == null or k < float(fall["delay"]) or bool(fall["rest"]):
		return
	var v: Vector3 = fall["v"]
	piece.global_position += v * delta
	v.y -= 9.8 * delta
	var spin: Vector3 = fall["spin"]
	piece.rotation += spin * delta
	var ground := z.world.ground_at(piece.global_position) + rest_height
	if piece.global_position.y <= ground and v.y < 0.0:
		piece.global_position.y = ground
		if absf(v.y) > 2.0:
			v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
			spin *= 0.5
		else:
			fall["rest"] = true
	fall["v"] = v
	fall["spin"] = spin


static func _boss_label(z: Zombie, root: Node3D) -> void:
	var label := root.get_node_or_null("BossHealth") as Label3D
	if label == null:
		return
	var fraction := z.hp / maxf(z.max_hp, 1.0)
	label.text = "%s • %d%%" % [BOSS_NAMES.get(z.model_id, ""), ceili(fraction * 100.0)]
	label.modulate = Color(1.0, 0.45, 0.3) if fraction <= 0.5 else Color(1.0, 0.82, 0.5)


# --- Children of the Woods --------------------------------------------------------------

## What a Child of the Woods wears over a small body: a hood of leaves with twig antlers, a bark mask
## with green eyes, and a mantle of leaves. Keys are bone names.
static func child_gear() -> Dictionary:
	return {
		"head": _mesh("child_head", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.45, -0.05), Vector3(0, 1.05, -0.12), 0.68, 0.36, 8, LEAF)
			l.prism(Vector3(0, 1.05, -0.12), Vector3(0, 1.1, -0.5), 0.3, 0.04, 6, LEAF_DARK)
			for i in 6:
				var a := TAU * i / 6.0
				l.leaf(Vector3(cos(a) * 0.62, 0.7, sin(a) * 0.62 - 0.05), Vector3(cos(a) * 0.82, 0.48, sin(a) * 0.82 - 0.05), Vector3(cos(a + 0.4) * 0.66, 0.5, sin(a + 0.4) * 0.66), LEAF_DARK)
			l.box(Vector3(0, 0.42, 0.56), Vector3(0.82, 0.48, 0.1), BARK)
			l.box(Vector3(0, 0.2, 0.6), Vector3(0.3, 0.12, 0.06), BARK.darkened(0.2))
			for x: float in [-1.0, 1.0]:
				l.prism(Vector3(x * 0.2, 1.0, -0.05), Vector3(x * 0.45, 1.45, -0.15), 0.035, 0.02, 4, BARK)
				l.prism(Vector3(x * 0.38, 1.3, -0.12), Vector3(x * 0.6, 1.4, 0.02), 0.02, 0.0, 4, BARK)
				l.prism(Vector3(x * 0.3, 1.2, -0.1), Vector3(x * 0.3, 1.52, -0.2), 0.018, 0.0, 4, BARK)),
		"chest": _mesh("child_chest", func(l: LowPoly) -> void:
			l.prism(Vector3(0, 0.4, 0), Vector3(0, -0.1, 0), 0.45, 0.66, 8, LEAF_DARK)
			for i in 8:
				var a := TAU * i / 8.0
				l.leaf(Vector3(cos(a) * 0.58, -0.05, sin(a) * 0.58), Vector3(cos(a) * 0.7, -0.4, sin(a) * 0.7), Vector3(cos(a + 0.35) * 0.6, -0.3, sin(a + 0.35) * 0.6), LEAF)),
	}


static func child_eyes() -> Mesh:
	return _mesh("child_eyes", func(l: LowPoly) -> void:
		for x: float in [-0.17, 0.17]:
			l.box(Vector3(x, 0.47, 0.62), Vector3(0.11, 0.06, 0.03), Color(0.62, 1.0, 0.45)))
