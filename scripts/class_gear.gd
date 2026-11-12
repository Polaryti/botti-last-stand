class_name ClassGear
## What each class wears over its body, so that it can be told from the others at a glance and from
## any side. Each piece is low-poly and hangs from a bone, so it moves with the character.
## Coordinates are the bone's: +Y up, +Z the way the character faces, +X its left.

const STEEL := Color(0.72, 0.75, 0.8)
const DARK_STEEL := Color(0.3, 0.32, 0.38)
const GOLD := Color(0.95, 0.72, 0.22)
const BRASS := Color(0.8, 0.58, 0.24)
const COPPER := Color(0.72, 0.4, 0.22)
const LEATHER := Color(0.42, 0.26, 0.15)
const DARK_LEATHER := Color(0.2, 0.13, 0.09)
const WOOD := Color(0.5, 0.31, 0.15)
const WHITE := Color(0.95, 0.94, 0.9)
const BONE := Color(0.88, 0.82, 0.66)
const BLACK := Color(0.06, 0.06, 0.08)
const RED := Color(0.75, 0.13, 0.12)

## Robe colours for the bodies that can be recoloured: how green cloth turns to theirs.
const ROBES := {"commander": Vector3(0.52, 0.22, 0.72), "infantry": Vector3(1.05, 0.2, 0.16), "monk": Vector3(1.2, 0.62, 0.2), "adept": Vector3(0.3, 0.38, 0.95), "artificer": Vector3(0.68, 0.42, 0.22),
	"bandit": Vector3(0.36, 0.16, 0.28), "cartographer": Vector3(0.26, 0.56, 1.0)}
## How the bare steel of an armoured body is tinted.
const PLATES := {"heavy": Vector3(0.62, 0.68, 0.82), "chivalry": Vector3(1.25, 0.98, 0.5)}

static var _made := {}


## Dresses a body: new colours first, then what goes on top.
static func wear(body: Node3D, id: String) -> void:
	_tint(body, id)
	var skeleton: Skeleton3D = null
	var found := body.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		skeleton = found[0]
	if skeleton == null:
		return
	var pieces := _pieces(id)
	for bone: String in pieces:
		if skeleton.find_bone(bone) < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = bone
		skeleton.add_child(at)
		var part := MeshInstance3D.new()
		part.mesh = pieces[bone]
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.extra_cull_margin = 1.0
		at.add_child(part)
	if id == "revenant":
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = Ally._ghost()


static func _tint(body: Node3D, id: String) -> void:
	var robe: Variant = ROBES.get(id)
	var plate: Variant = PLATES.get(id)
	if robe == null and plate == null and id != "plague_doctor":
		return
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		if part.mesh == null or part.mesh.get_surface_count() == 0:
			continue
		var look: Material = part.mesh.surface_get_material(0)
		if not look is BaseMaterial3D:
			continue
		if id == "plague_doctor":
			var worn: BaseMaterial3D = look.duplicate()
			worn.albedo_color = Color(0.32, 0.32, 0.36)
			part.material_override = worn
			continue
		var cloth := ShaderMaterial.new()
		cloth.shader = load("res://assets/shaders/recolour.gdshader")
		cloth.set_shader_parameter("tex", (look as BaseMaterial3D).albedo_texture)
		if robe != null:
			cloth.set_shader_parameter("robe", robe)
		else:
			cloth.set_shader_parameter("robe", Vector3(0.0, 1.0, 0.0))
			cloth.set_shader_parameter("plate", plate)
		part.material_override = cloth


static func _pieces(id: String) -> Dictionary:
	if not _made.has(id):
		var built := {}
		match id:
			"commander": built = _commander()
			"infantry": built = _infantry()
			"ranger": built = _ranger()
			"heavy": built = _heavy()
			"chivalry": built = _chivalry()
			"magician": built = _magician()
			"revenant": built = _revenant()
			"monk": built = _monk()
			"adept": built = _adept()
			"plague_doctor": built = _plague_doctor()
			"artificer": built = _artificer()
			"bandit": built = _bandit()
			"cartographer": built = _cartographer()
		_made[id] = built
	return _made[id]


## A short, flat cylinder facing along the line from a to b.
static func _disc(l: LowPoly, centre: Vector3, normal: Vector3, r: float, thick: float, col: Color, sides := 10) -> void:
	var half := normal.normalized() * thick * 0.5
	l.prism(centre - half, centre + half, r, r, sides, col)


## Infantry: an iron kettle hat with a wide brim, and a round shield on the back.
static func _infantry() -> Dictionary:
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.74, 0), Vector3(0, 1.1, 0), 0.68, 0.34, 8, Color(0.40, 0.47, 0.55))
	head.prism(Vector3(0, 1.1, 0), Vector3(0, 1.22, 0), 0.34, 0.0, 8, DARK_STEEL)
	head.prism(Vector3(0, 0.7, 0), Vector3(0, 0.8, 0), 0.9, 0.72, 10, DARK_STEEL)
	var chest := LowPoly.new()
	_disc(chest, Vector3(0, 0.0, -0.46), Vector3.BACK, 0.6, 0.06, DARK_STEEL, 12)
	_disc(chest, Vector3(0, 0.0, -0.5), Vector3.BACK, 0.54, 0.06, WOOD, 12)
	_disc(chest, Vector3(0, 0.0, -0.56), Vector3.BACK, 0.17, 0.1, STEEL, 8)
	chest.box(Vector3(0, -0.02, 0.34), Vector3(0.14, 0.82, 0.04), LEATHER, Vector3(0, 0, 32))
	return {"head": head.commit(), "chest": chest.commit()}


## Ranger: a quiver standing over the shoulder and a long feather in the hood.
static func _ranger() -> Dictionary:
	var head := LowPoly.new()
	head.prism(Vector3(0.34, 0.74, -0.38), Vector3(0.82, 1.5, -0.72), 0.09, 0.0, 4, RED)
	head.prism(Vector3(0.42, 0.72, -0.4), Vector3(0.98, 1.3, -0.66), 0.07, 0.0, 4, WHITE)
	var chest := LowPoly.new()
	chest.prism(Vector3(-0.26, -0.36, -0.38), Vector3(0.24, 0.52, -0.46), 0.15, 0.18, 8, LEATHER)
	for i in 4:
		var off := Vector3(0.06 * i, 0.0, 0.03 * (i % 2))
		var top := Vector3(0.28, 1.06, -0.46) + off
		chest.prism(Vector3(0.2, 0.5, -0.46) + off, top, 0.018, 0.018, 4, Color(0.8, 0.68, 0.45))
		chest.box(top + Vector3(0.015, 0.04, 0), Vector3(0.11, 0.2, 0.02), WHITE)
	# A leaf-green mantle across the shoulders.
	chest.prism(Vector3(0, 0.34, -0.02), Vector3(0, -0.02, -0.12), 0.34, 0.6, 8, Color(0.08, 0.3, 0.17))
	return {"head": head.commit(), "chest": chest.commit()}


## Heavy Infantry: a closed great helm with a red plume, and huge shoulder plates.
static func _heavy() -> Dictionary:
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.02, 0), Vector3(0, 0.98, 0), 0.68, 0.7, 8, DARK_STEEL)
	head.prism(Vector3(0, 0.98, 0), Vector3(0, 1.14, 0), 0.7, 0.42, 8, Color(0.40, 0.47, 0.55))
	head.box(Vector3(0, 0.56, 0.66), Vector3(0.88, 0.1, 0.08), BLACK)
	head.box(Vector3(0, 0.42, 0.67), Vector3(0.14, 0.74, 0.07), GOLD)
	head.box(Vector3(0, 0.58, 0.68), Vector3(0.92, 0.04, 0.05), STEEL)
	head.prism(Vector3(0, 1.14, 0.06), Vector3(0, 1.72, -0.26), 0.2, 0.08, 6, RED)
	head.prism(Vector3(0, 1.72, -0.26), Vector3(0, 1.72, -0.86), 0.09, 0.0, 6, RED)
	var chest := LowPoly.new()
	for side: float in [-1.0, 1.0]:
		chest.prism(Vector3(side * 0.34, 0.14, 0), Vector3(side * 0.8, 0.14, 0), 0.24, 0.34, 8, Color(0.40, 0.47, 0.55))
		chest.prism(Vector3(side * 0.8, 0.14, 0), Vector3(side * 0.9, 0.14, 0), 0.34, 0.16, 8, DARK_STEEL)
		chest.prism(Vector3(side * 0.58, 0.44, 0), Vector3(side * 0.58, 0.76, 0), 0.08, 0.0, 5, DARK_STEEL)
	chest.box(Vector3(0, -0.26, 0.36), Vector3(0.6, 0.8, 0.04), Color(0.14, 0.17, 0.3))
	chest.box(Vector3(0, -0.2, 0.39), Vector3(0.12, 0.62, 0.03), WHITE)
	chest.box(Vector3(0, -0.04, 0.39), Vector3(0.42, 0.12, 0.03), WHITE)
	return {"head": head.commit(), "chest": chest.commit()}


## Chivalry: gilded, a horsehair crest over the helmet, and a long blue cape.
static func _chivalry() -> Dictionary:
	const BLUE := Color(0.1, 0.2, 0.62)
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.69, 0), Vector3(0, 1.22, 0), 0.82, 0.45, 8, GOLD)
	head.prism(Vector3(0, 0.56, 0), Vector3(0, 0.68, 0), 0.9, 0.86, 8, BRASS)
	head.box(Vector3(0, 0.46, 0.74), Vector3(0.1, 0.42, 0.05), BRASS)
	for i in 9:
		var a := lerpf(-0.45, 2.2, float(i) / 8.0)
		var at := Vector3(0, 0.62 + sin(a + 0.55) * 0.68, cos(a + 0.55) * 0.82)
		head.box(at, Vector3(0.1, 0.28, 0.14), Color(0.85, 0.12, 0.1) if i % 2 == 0 else WHITE, Vector3(rad_to_deg(0.55 + a) - 90.0, 0, 0))
	var chest := LowPoly.new()
	# The cape falls from the shoulders and widens down to the heels.
	chest.prism(Vector3(0, 0.34, -0.04), Vector3(0, 0.1, -0.1), 0.44, 0.66, 8, BLUE)
	chest.box(Vector3(0, -0.28, -0.42), Vector3(1.0, 0.9, 0.05), BLUE, Vector3(-8, 0, 0))
	chest.box(Vector3(0, -0.68, -0.5), Vector3(1.16, 0.36, 0.05), BLUE, Vector3(-14, 0, 0))
	chest.box(Vector3(0, -0.86, -0.55), Vector3(1.2, 0.06, 0.07), GOLD, Vector3(-14, 0, 0))
	# And a tabard in the same colours.
	chest.box(Vector3(0, -0.3, 0.36), Vector3(0.56, 0.86, 0.04), BLUE)
	chest.box(Vector3(0, -0.2, 0.39), Vector3(0.24, 0.34, 0.03), GOLD)
	return {"head": head.commit(), "chest": chest.commit()}


## Magician: a long white beard, stars on the hat, and a book on the belt.
static func _magician() -> Dictionary:
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.26, 0.42), Vector3(0, -0.62, 0.6), 0.36, 0.02, 7, WHITE)
	head.box(Vector3(-0.2, 0.3, 0.6), Vector3(0.34, 0.08, 0.12), WHITE, Vector3(0, 0, 18))
	head.box(Vector3(0.2, 0.3, 0.6), Vector3(0.34, 0.08, 0.12), WHITE, Vector3(0, 0, -18))
	for s: Array in [[Vector3(0.0, 1.32, 0.36), 0.14], [Vector3(0.3, 1.1, 0.42), 0.09], [Vector3(-0.28, 1.56, 0.1), 0.09]]:
		head.box(s[0], Vector3.ONE * float(s[1]) * Vector3(1.0, 1.0, 0.4), GOLD, Vector3(0, 0, 45))
		head.box(s[0], Vector3.ONE * float(s[1]) * Vector3(1.0, 1.0, 0.4), GOLD)
	var hips := LowPoly.new()
	hips.box(Vector3(0.42, 0.12, 0.2), Vector3(0.1, 0.44, 0.34), Color(0.6, 0.12, 0.14), Vector3(0, 0, -6))
	hips.box(Vector3(0.43, 0.12, 0.2), Vector3(0.12, 0.38, 0.28), WHITE, Vector3(0, 0, -6))
	var chest := LowPoly.new()
	chest.prism(Vector3(0, 0.32, 0), Vector3(0, 0.06, 0), 0.34, 0.6, 8, Color(0.2, 0.14, 0.42))
	_disc(chest, Vector3(0, -0.02, 0.44), Vector3.BACK, 0.13, 0.06, GOLD, 8)
	return {"head": head.commit(), "chest": chest.commit(), "hips": hips.commit()}


## Revenant: no legs, only a torn shroud, and a crown of spikes of mist. All of it is pale and half there.
static func _revenant() -> Dictionary:
	var head := LowPoly.new()
	for i in 7:
		var a := TAU * i / 7.0
		var out := Vector3(sin(a), 0, cos(a))
		head.prism(out * 0.52 + Vector3.UP * 0.92, out * 0.82 + Vector3.UP * (1.44 + (0.26 if i % 2 == 0 else 0.0)), 0.1, 0.0, 4, WHITE)
	var hips := LowPoly.new()
	hips.prism(Vector3(0, 0.26, 0), Vector3(0, -0.2, 0), 0.5, 0.72, 8, WHITE)
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(sin(a), 0, cos(a))
		hips.prism(out * 0.56 + Vector3.UP * -0.14, out * 0.86 + Vector3.UP * (-0.42 if i % 2 == 0 else -0.3), 0.2, 0.0, 4, WHITE)
	var chest := LowPoly.new()
	chest.prism(Vector3(0, 0.34, -0.02), Vector3(0, -0.5, -0.16), 0.46, 0.68, 8, WHITE)
	return {"head": head.commit(), "hips": hips.commit(), "chest": chest.commit()}


## Monk: a wide straw hat, large prayer beads, and a sash across the robe.
static func _monk() -> Dictionary:
	const STRAW := Color(0.86, 0.71, 0.38)
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.72, 0), Vector3(0, 1.36, 0), 1.2, 0.04, 14, STRAW)
	head.prism(Vector3(0, 0.66, 0), Vector3(0, 0.72, 0), 1.16, 1.2, 14, Color(0.6, 0.46, 0.2))
	head.prism(Vector3(0, 1.0, 0), Vector3(0, 1.06, 0), 0.72, 0.62, 14, RED)
	var chest := LowPoly.new()
	const BEADS := 15
	for i in BEADS:
		var a := lerpf(-1.75, 1.75, float(i) / (BEADS - 1))
		var at := Vector3(sin(a) * 0.42, 0.3 - cos(a * 0.5) * 0.46, cos(a) * 0.38 + 0.02)
		var big := i == BEADS / 2
		chest.prism(at + Vector3.BACK * -0.06, at + Vector3.BACK * 0.06, 0.1 if big else 0.065, 0.1 if big else 0.065, 6, GOLD if big else Color(0.3, 0.14, 0.07))
	chest.box(Vector3(0, -0.04, 0.33), Vector3(0.2, 0.92, 0.04), Color(0.55, 0.1, 0.1), Vector3(0, 0, -38))
	return {"head": head.commit(), "chest": chest.commit()}


## Adept: a dark helmet with a golden crescent, wide shoulder plates, and a sword sheathed across the back.
static func _adept() -> Dictionary:
	const NAVY := Color(0.09, 0.11, 0.26)
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.66, 0), Vector3(0, 1.14, 0), 0.74, 0.34, 8, NAVY)
	head.prism(Vector3(0, 1.14, 0), Vector3(0, 1.24, 0), 0.2, 0.08, 6, GOLD)
	head.box(Vector3(0, 0.46, -0.66), Vector3(1.3, 0.42, 0.12), NAVY, Vector3(-28, 0, 0))
	for side: float in [-1.0, 1.0]:
		head.box(Vector3(side * 0.82, 0.62, 0.18), Vector3(0.1, 0.34, 0.5), GOLD, Vector3(0, side * 20.0, 0))
		# The crescent: three pieces rising from the brow, each further out.
		head.prism(Vector3(side * 0.05, 0.88, 0.72), Vector3(side * 0.42, 1.14, 0.74), 0.09, 0.07, 5, GOLD)
		head.prism(Vector3(side * 0.42, 1.14, 0.74), Vector3(side * 0.64, 1.56, 0.74), 0.07, 0.04, 5, GOLD)
		head.prism(Vector3(side * 0.64, 1.56, 0.74), Vector3(side * 0.56, 1.92, 0.74), 0.04, 0.0, 5, GOLD)
	var chest := LowPoly.new()
	for side: float in [-1.0, 1.0]:
		chest.box(Vector3(side * 0.74, 0.0, 0), Vector3(0.12, 0.66, 0.54), NAVY, Vector3(0, 0, side * 22.0))
		chest.box(Vector3(side * 0.62, 0.3, 0), Vector3(0.14, 0.05, 0.56), GOLD, Vector3(0, 0, side * 22.0))
	chest.prism(Vector3(-0.72, -0.44, -0.4), Vector3(0.72, 0.5, -0.44), 0.05, 0.05, 6, BLACK)
	chest.prism(Vector3(0.72, 0.5, -0.44), Vector3(0.98, 0.67, -0.45), 0.035, 0.035, 6, GOLD)
	var hips := LowPoly.new()
	for x: float in [-0.3, 0.0, 0.3]:
		hips.box(Vector3(x, -0.08, 0.38), Vector3(0.28, 0.42, 0.04), NAVY)
		hips.box(Vector3(x, -0.26, 0.4), Vector3(0.28, 0.05, 0.04), GOLD)
	return {"head": head.commit(), "chest": chest.commit(), "hips": hips.commit()}


## Plague Doctor: a bone beak with red glass eyes, a black shoulder cape, a coat to the ground, and a smoking censer.
static func _plague_doctor() -> Dictionary:
	var head := LowPoly.new()
	head.box(Vector3(0, 0.26, 0.5), Vector3(0.88, 0.62, 0.34), BONE)
	head.prism(Vector3(0, 0.22, 0.62), Vector3(0, 0.02, 1.08), 0.3, 0.18, 6, BONE)
	head.prism(Vector3(0, 0.02, 1.08), Vector3(0, -0.24, 1.6), 0.18, 0.02, 6, BONE)
	for side: float in [-1.0, 1.0]:
		_disc(head, Vector3(side * 0.24, 0.38, 0.68), Vector3.BACK, 0.17, 0.05, BRASS, 8)
		_disc(head, Vector3(side * 0.24, 0.38, 0.71), Vector3.BACK, 0.12, 0.04, Color(0.9, 0.08, 0.06), 8)
	var chest := LowPoly.new()
	chest.prism(Vector3(0, 0.3, 0), Vector3(0, -0.28, -0.02), 0.32, 0.72, 8, BLACK)
	var hips := LowPoly.new()
	hips.prism(Vector3(0, 0.26, 0), Vector3(0, -0.36, -0.03), 0.5, 0.66, 8, Color(0.1, 0.1, 0.12))
	hips.prism(Vector3(0.46, 0.14, 0.2), Vector3(0.46, -0.18, 0.2), 0.04, 0.12, 6, BRASS)
	hips.prism(Vector3(0.46, -0.18, 0.2), Vector3(0.46, -0.28, 0.2), 0.12, 0.06, 6, Color(0.5, 0.95, 0.25))
	return {"head": head.commit(), "chest": chest.commit(), "hips": hips.commit()}


## Bandit: a deep plum hood with a black cloth mask over the nose, a short ragged cape, a belt of
## knives across the chest and a coin purse at the hip.
static func _bandit() -> Dictionary:
	const PLUM := Color(0.3, 0.12, 0.22)
	const DEEP := Color(0.17, 0.07, 0.13)
	var head := LowPoly.new()
	# The hood: round over the crown and falling to a point behind; its front edge frames the face.
	head.prism(Vector3(0, 0.34, -0.08), Vector3(0, 1.02, -0.16), 0.7, 0.46, 8, PLUM)
	head.prism(Vector3(0, 1.02, -0.16), Vector3(0, 1.0, -0.62), 0.4, 0.04, 6, PLUM)
	head.box(Vector3(0, 0.86, 0.46), Vector3(0.86, 0.16, 0.12), DEEP, Vector3(12, 0, 0))
	# Black cloth over the nose and mouth, knotted behind; the eyes stay clear.
	head.box(Vector3(0, 0.1, 0.6), Vector3(0.9, 0.2, 0.12), BLACK)
	head.prism(Vector3(0, 0.02, 0.64), Vector3(0, -0.2, 0.7), 0.24, 0.04, 5, BLACK)
	var chest := LowPoly.new()
	chest.prism(Vector3(0, 0.36, -0.04), Vector3(0, -0.06, -0.12), 0.4, 0.62, 8, DEEP)
	# A short cape to the small of the back, torn into points at the hem.
	chest.box(Vector3(0, -0.2, -0.36), Vector3(0.92, 0.66, 0.05), PLUM, Vector3(-4, 0, 0))
	for i in 4:
		var x := -0.33 + i * 0.22
		chest.prism(Vector3(x, -0.5, -0.38), Vector3(x + 0.02, -0.72, -0.4), 0.1, 0.0, 4, PLUM)
	chest.box(Vector3(0, -0.02, 0.36), Vector3(0.14, 0.92, 0.04), DARK_LEATHER, Vector3(0, 0, -34))
	for i in 3:
		var along := Vector3(-0.15 + i * 0.15, 0.22 - i * 0.22, 0.4)
		chest.prism(along, along + Vector3(0.04, 0.2, 0.0), 0.025, 0.0, 4, STEEL)
		chest.box(along - Vector3(0.0, 0.05, 0.0), Vector3(0.05, 0.08, 0.04), BLACK)
	var hips := LowPoly.new()
	hips.prism(Vector3(-0.44, 0.16, 0.2), Vector3(-0.44, -0.16, 0.2), 0.08, 0.15, 7, LEATHER)
	hips.prism(Vector3(-0.44, 0.16, 0.2), Vector3(-0.44, 0.22, 0.2), 0.06, 0.03, 7, GOLD)
	hips.box(Vector3(0.46, 0.0, 0.14), Vector3(0.05, 0.36, 0.08), DARK_LEATHER)
	return {"head": head.commit(), "chest": chest.commit(), "hips": hips.commit()}


## Cartographer: a broad traveller's hat with an azure band and a brass compass at the front, a
## map case slung across the back, a compass on the chest strap, and a spyglass at the hip.
static func _cartographer() -> Dictionary:
	const AZURE := Color(0.2, 0.46, 0.78)
	const FELT := Color(0.33, 0.25, 0.18)
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.7, 0.02), Vector3(0, 0.8, 0.02), 0.84, 0.8, 12, FELT)
	head.prism(Vector3(0, 0.8, 0.0), Vector3(0, 1.14, -0.02), 0.56, 0.48, 10, FELT.lightened(0.06))
	head.prism(Vector3(0, 0.8, 0.0), Vector3(0, 0.92, 0.0), 0.575, 0.565, 10, AZURE)
	_disc(head, Vector3(0, 0.88, 0.57), Vector3.BACK, 0.11, 0.05, BRASS, 8)
	head.box(Vector3(0, 0.88, 0.6), Vector3(0.025, 0.12, 0.02), RED)
	var chest := LowPoly.new()
	# The map case, corner to corner across the back, capped in leather.
	chest.prism(Vector3(-0.42, -0.42, -0.5), Vector3(0.38, 0.62, -0.52), 0.16, 0.16, 8, AZURE.darkened(0.2))
	chest.prism(Vector3(-0.48, -0.5, -0.5), Vector3(-0.42, -0.42, -0.5), 0.18, 0.18, 8, LEATHER)
	chest.prism(Vector3(0.38, 0.62, -0.52), Vector3(0.44, 0.7, -0.52), 0.18, 0.18, 8, LEATHER)
	chest.prism(Vector3(0.44, 0.7, -0.52), Vector3(0.5, 0.78, -0.52), 0.1, 0.1, 6, Color(0.92, 0.86, 0.68))
	# The strap that holds it, and a brass compass hung on it.
	chest.box(Vector3(0, -0.02, 0.36), Vector3(0.12, 0.94, 0.04), DARK_LEATHER, Vector3(0, 0, 32))
	_disc(chest, Vector3(-0.08, 0.1, 0.42), Vector3.BACK, 0.13, 0.05, BRASS, 10)
	_disc(chest, Vector3(-0.08, 0.1, 0.45), Vector3.BACK, 0.09, 0.02, WHITE, 10)
	chest.box(Vector3(-0.08, 0.13, 0.465), Vector3(0.02, 0.08, 0.01), RED)
	var hips := LowPoly.new()
	hips.prism(Vector3(0.46, 0.2, 0.1), Vector3(0.46, -0.3, 0.16), 0.06, 0.05, 8, BRASS)
	hips.prism(Vector3(0.46, -0.3, 0.16), Vector3(0.46, -0.36, 0.17), 0.065, 0.065, 8, DARK_STEEL)
	hips.box(Vector3(-0.44, 0.06, 0.12), Vector3(0.14, 0.3, 0.26), LEATHER)
	hips.box(Vector3(-0.44, 0.2, 0.12), Vector3(0.16, 0.06, 0.28), DARK_LEATHER)
	return {"head": head.commit(), "chest": chest.commit(), "hips": hips.commit()}


## Artificer: a leather cap with brass goggles, and a boiler on the back with a chimney and a gear.
static func _artificer() -> Dictionary:
	var head := LowPoly.new()
	head.prism(Vector3(0, 0.66, 0), Vector3(0, 1.08, 0), 0.72, 0.42, 8, DARK_LEATHER)
	head.box(Vector3(0, 0.82, 0.58), Vector3(1.16, 0.1, 0.14), LEATHER)
	for side: float in [-1.0, 1.0]:
		_disc(head, Vector3(side * 0.26, 0.84, 0.64), Vector3.BACK, 0.22, 0.12, BRASS, 8)
		_disc(head, Vector3(side * 0.26, 0.84, 0.7), Vector3.BACK, 0.16, 0.04, Color(0.5, 0.85, 1.0), 8)
	var chest := LowPoly.new()
	chest.prism(Vector3(0, -0.46, -0.62), Vector3(0, 0.54, -0.62), 0.42, 0.42, 10, COPPER)
	chest.prism(Vector3(0, 0.54, -0.62), Vector3(0, 0.66, -0.62), 0.42, 0.26, 10, BRASS)
	chest.prism(Vector3(0, -0.56, -0.62), Vector3(0, -0.46, -0.62), 0.26, 0.42, 10, BRASS)
	chest.prism(Vector3(-0.2, 0.6, -0.68), Vector3(-0.2, 1.42, -0.72), 0.09, 0.1, 6, DARK_STEEL)
	chest.prism(Vector3(-0.2, 1.42, -0.72), Vector3(-0.2, 1.54, -0.72), 0.1, 0.18, 6, BLACK)
	_disc(chest, Vector3(0.5, 0.1, -0.62), Vector3.RIGHT, 0.26, 0.06, GOLD, 8)
	for i in 8:
		var a := TAU * i / 8.0
		chest.box(Vector3(0.5, 0.1 + sin(a) * 0.3, -0.62 + cos(a) * 0.3), Vector3(0.06, 0.1, 0.1), GOLD, Vector3(rad_to_deg(a), 0, 0))
	_disc(chest, Vector3(0.53, 0.1, -0.62), Vector3.RIGHT, 0.08, 0.04, BLACK, 6)
	chest.box(Vector3(-0.25, 0.0, 0.34), Vector3(0.1, 0.84, 0.04), LEATHER, Vector3(0, 0, 8))
	chest.box(Vector3(0.25, 0.0, 0.34), Vector3(0.1, 0.84, 0.04), LEATHER, Vector3(0, 0, -8))
	var hips := LowPoly.new()
	hips.box(Vector3(-0.44, 0.12, 0.18), Vector3(0.14, 0.26, 0.22), DARK_LEATHER)
	hips.box(Vector3(0.46, 0.04, 0.12), Vector3(0.05, 0.44, 0.07), STEEL)
	hips.box(Vector3(0.46, -0.2, 0.12), Vector3(0.1, 0.1, 0.13), STEEL)
	return {"head": head.commit(), "chest": chest.commit(), "hips": hips.commit()}


static func _commander() -> Dictionary:
	var helm := LowPoly.new()
	# Enclosed officer's sallet with a swept crest and split cheek guards.
	helm.prism(Vector3(0, 0.64, 0), Vector3(0, 1.16, 0.06), 0.63, 0.43, 8, Color(0.40, 0.47, 0.55))
	helm.box(Vector3(0, 0.80, -0.57), Vector3(0.85, 0.07, 0.08), Color(0.06, 0.07, 0.10))
	for side: float in [-1.0, 1.0]:
		helm.box(Vector3(side * 0.43, 0.52, -0.32), Vector3(0.16, 0.38, 0.32), Color(0.40, 0.47, 0.55))
	helm.prism(Vector3(0, 1.06, -0.3), Vector3(0, 1.40, 0.48), 0.12, 0.035, 4, Color(0.46, 0.16, 0.58))
	helm.box(Vector3(0, 0.68, -0.62), Vector3(0.08, 0.23, 0.06), GOLD)
	var chest := LowPoly.new()
	chest.box(Vector3(0, -0.3, -0.38), Vector3(1.1, 1.1, 0.06), Color(0.38, 0.12, 0.55))
	for side: float in [-1.0, 1.0]:
		chest.box(Vector3(side * 0.55, 0.18, 0), Vector3(0.36, 0.2, 0.5), GOLD)
	_disc(chest, Vector3(0, 0.16, 0.38), Vector3.BACK, 0.12, 0.05, GOLD, 6)
	return {"head": helm.commit(), "chest": chest.commit()}
