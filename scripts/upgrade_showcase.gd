class_name UpgradeShowcase
extends Node3D
## A Class Upgrade, or a look, shown doing what it does on the Store's and the Armory's stage: the
## class's own body holding its own weapon, the same horse, stag, standard, skeletons and zombies a
## night has, on a loop of a few seconds. Nothing in it touches a game: no world, no timers, no sound.
##
## Everything is laid out facing -Z, as bodies face in a night; `view_turn` turns the whole of it to the
## side it is best seen from.

## Each scene and how long one round of it lasts.
const LOOP := {"lance_charge": 3.2, "consecration": 3.6, "whistle": 3.8, "grave_call": 3.8, "frost_nova": 3.4,
	"hall_of_mirrors": 3.4, "stag_steed": 4.0, "mount_horse": 4.0}
const RIDE_HEIGHT := 2.5 # a rider on a horse, from the hooves to the top of the head

const GOLD := Color(1.0, 0.82, 0.4)
const FROST := Color(0.62, 0.86, 1.0)
const GRAVE_MIST := Color(0.62, 0.4, 0.95)
const EARTH := Color(0.27, 0.2, 0.15)

var item := ""
var clock := 0.0
var _length := 3.0
var _person: Dictionary = {} # the class's body: "node", "anim", "hand", "holder"
var _steed: Node3D # a horse (MeshInstance3D) or the stag
var _parts := {} # each scene's own pieces, by name
var _played := {} # the last animation asked of each AnimationPlayer, so a loop is not restarted every frame


static func shows(id: String) -> bool:
	return LOOP.has(id)


## How tall the stage must be to hold the scene.
static func stage_height(id: String) -> float:
	match id:
		"lance_charge": return 3.1
		"whistle", "stag_steed", "mount_horse", "consecration": return 3.0
		"grave_call": return 3.4
		"frost_nova", "hall_of_mirrors": return 2.8
	return 2.4


## How far the camera looks down on it (radians): more where what happens is on the ground.
static func camera_tilt(id: String) -> float:
	match id:
		"grave_call", "consecration", "frost_nova", "hall_of_mirrors": return 0.24
		"lance_charge": return 0.08
	return 0.12


## Which way the scene is turned to the camera (radians about Y; 0 shows its back, PI its face).
static func view_turn(id: String) -> float:
	match id:
		"lance_charge": return PI * 0.5 + 0.38 # side on, riding to the left
		"whistle": return PI - 0.3
		"stag_steed", "mount_horse": return PI * 0.5 + 0.5
	return PI - 0.35


func configure(id: String) -> void:
	item = id
	_length = LOOP[id]
	rotation.y = view_turn(id)
	_ground_shadow(1.0 if id in ["stag_steed", "mount_horse", "lance_charge", "whistle"] else 0.6)
	match id:
		"lance_charge": _build_charge()
		"consecration": _build_consecration()
		"whistle": _build_whistle()
		"grave_call": _build_graves()
		"frost_nova": _build_nova()
		"hall_of_mirrors": _build_mirrors()
		"stag_steed": _build_mounted("chivalry", true)
		"mount_horse": _build_mounted("chivalry", false)


func _process(delta: float) -> void:
	clock += delta
	var t := fmod(clock, _length)
	match item:
		"lance_charge": _charge(t, delta)
		"consecration": _consecrate(t)
		"whistle": _whistle(t)
		"grave_call": _grave_call(t)
		"frost_nova": _nova(t)
		"hall_of_mirrors": _mirrors(t)
		"stag_steed", "mount_horse": _walk_mount()


# --- Pieces -------------------------------------------------------------------------------

## A spot on the ground given as the camera sees it: x to the right, y towards the camera (metres from
## the middle of the stage). The scenes that stand still are laid out this way.
func _at(screen: Vector2) -> Vector3:
	var a := rotation.y
	return Vector3(screen.x * cos(a) - screen.y * sin(a), 0, screen.x * sin(a) + screen.y * cos(a))


## Turned to face a point on the ground.
static func _facing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


## The class's body, 1.8 m tall and facing -Z, with its weapon in its right hand.
func _make_person(class_id: String, weapon: String, at := Vector3.ZERO) -> Dictionary:
	var holder := Node3D.new()
	holder.position = at
	add_child(holder)
	var model: String = Avatar.MODELS.get(class_id, "clever")
	var body: Node3D = (load("res://assets/characters/%s.glb" % model) as PackedScene).instantiate()
	body.rotation.y = PI
	holder.add_child(body)
	var top := 0.0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.extra_cull_margin = 1.0
		top = maxf(top, part.get_aabb().end.y)
	var fit := 1.8 / float(Zombie.BODY_TOP.get(model, maxf(top, 0.5)))
	body.scale = Vector3.ONE * fit
	ClassDefs.dress(body, class_id)
	var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	BodyAnim.install(anim, skeleton)
	for n: String in ["Idle", "Running_A", "Walking_A"]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var slot := BoneAttachment3D.new()
	slot.bone_name = "handslot.r"
	skeleton.add_child(slot)
	var hand := WeaponVisual.new()
	slot.add_child(hand)
	hand.arm(weapon, fit, holder)
	var person := {"node": body, "anim": anim, "hand": hand, "holder": holder}
	_play(anim, "Idle")
	return person


## A creature from the night: rotten skin, red eyes.
func _make_zombie(at: Vector3, model := "normal_a") -> Dictionary:
	var holder := Node3D.new()
	holder.position = at
	add_child(holder)
	var z := Zombie.show_body(model)
	holder.add_child(z["node"])
	z["holder"] = holder
	_play(z["anim"], "Walking_A")
	return z


## The horse the class rides, or the White Stag, sized as in a night and facing -Z.
func _make_steed(stag: bool) -> Node3D:
	var steed: Node3D
	if stag:
		steed = MesenllaModels.stag_steed(HorseModel.RIDDEN_SIZE)
	else:
		steed = HorseModel.make()
		steed.scale = Vector3.ONE * HorseModel.RIDDEN_SIZE
	add_child(steed)
	return steed


func _steed_gait(gait: float) -> void:
	if _steed is MeshInstance3D:
		HorseModel.set_gait(_steed as MeshInstance3D, gait)
	elif _steed:
		MesenllaModels.steed_gait(_steed, gait)


## Puts the person in the saddle of the steed, as a rider sits in a night.
func _seat(person: Dictionary, on: Node3D) -> void:
	var holder: Node3D = person["holder"]
	holder.get_parent().remove_child(holder)
	on.add_child(holder)
	# The horse is scaled down to its ridden size; the rider is not.
	holder.scale = Vector3.ONE / on.scale.x if on is MeshInstance3D else Vector3.ONE
	holder.position = Vector3(0, HorseModel.SADDLE / (on.scale.x if on is MeshInstance3D else 1.0), 0)


func _stand(person: Dictionary, at: Vector3) -> void:
	var holder: Node3D = person["holder"]
	if holder.get_parent() != self:
		holder.get_parent().remove_child(holder)
		add_child(holder)
	holder.scale = Vector3.ONE
	holder.rotation = Vector3.ZERO
	holder.position = at


func _play(anim: AnimationPlayer, anim_name: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if _played.get(anim, "") == anim_name and anim.is_playing():
		anim.speed_scale = speed
		return
	_played[anim] = anim_name
	anim.play(anim_name, 0.15)
	anim.speed_scale = speed


func _ground_shadow(size: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.28)
	var disc := CylinderMesh.new()
	disc.top_radius = size
	disc.bottom_radius = size
	disc.height = 0.01
	disc.radial_segments = 32
	var shadow := MeshInstance3D.new()
	shadow.mesh = disc
	shadow.material_override = mat
	shadow.position.y = 0.005
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	_parts["shadow"] = shadow


func _glow(col: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _mesh(build: Callable) -> ArrayMesh:
	var l := LowPoly.new()
	build.call(l)
	return l.commit()


func _piece(mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A ring lying on the ground, radius 1 (scaled to size).
func _ring(col: Color, alpha: float, width := 0.08) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const PARTS := 40
	for i in PARTS:
		var a := TAU * i / PARTS
		var b := TAU * (i + 1) / PARTS
		var ia := Vector3(cos(a), 0, sin(a)) * (1.0 - width)
		var oa := Vector3(cos(a), 0, sin(a)) * (1.0 + width)
		var ib := Vector3(cos(b), 0, sin(b)) * (1.0 - width)
		var ob := Vector3(cos(b), 0, sin(b)) * (1.0 + width)
		for v: Vector3 in [ia, oa, ib, oa, ob, ib]:
			st.add_vertex(v)
	var ring := _piece(st.commit(), _glow(col, alpha))
	ring.position.y = 0.03
	return ring


## A small puff of mist or dust: a few soft balls that swell and fade.
func _puff(col: Color, count: int) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = _glow(col, 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / count
		mi.set_meta("dir", Vector3(cos(a), 0.35 + 0.25 * (i % 2), sin(a)))
		root.add_child(mi)
	root.visible = false
	return root


## Plays a puff `age` seconds after it started; it lasts `life` seconds.
func _show_puff(puff: Node3D, age: float, life: float, size: float) -> void:
	puff.visible = age >= 0.0 and age < life
	if not puff.visible:
		return
	var k := age / life
	for mi: MeshInstance3D in puff.get_children():
		var dir: Vector3 = mi.get_meta("dir")
		mi.position = dir * size * (0.3 + k * 0.9)
		mi.scale = Vector3.ONE * size * (0.35 + k * 0.6)
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - k)


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


static func _window(t: float, from: float, to: float) -> float:
	return clampf((t - from) / (to - from), 0.0, 1.0)


# --- Lance Charge -------------------------------------------------------------------------
# The Lancer at the charge, lance couched; straw dummies come up the field and are thrown aside as the
# lance and the horse go through them. The field moves, not the rider, so the stage can stay close.

const CHARGE_SPEED := 7.0

func _build_charge() -> void:
	_steed = _make_steed(false)
	_steed.position.z = 0.7
	_person = _make_person("chivalry", "lance")
	_seat(_person, _steed)
	_play(_person["anim"], "RideCharge")
	var dummy_mesh := _mesh(func(l: LowPoly) -> void:
		l.box(Vector3(0, 0.55, 0), Vector3(0.07, 1.1, 0.07), Color(0.42, 0.3, 0.18))
		l.box(Vector3(0, 1.15, 0), Vector3(0.38, 0.52, 0.26), Color(0.82, 0.7, 0.42))
		l.box(Vector3(0, 1.1, 0), Vector3(0.8, 0.07, 0.07), Color(0.42, 0.3, 0.18))
		l.box(Vector3(0, 1.55, 0), Vector3(0.24, 0.26, 0.22), Color(0.86, 0.76, 0.5)))
	var dummies: Array[MeshInstance3D] = []
	for side: float in [0.15, -0.55]:
		var d := _piece(dummy_mesh)
		d.set_meta("side", side)
		dummies.append(d)
	_parts["dummies"] = dummies
	var tuft_mesh := _mesh(func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0.02, 0.16, 0), 0.05, 0.0, 3, Color(0.36, 0.44, 0.22))
		l.prism(Vector3(0.06, 0, 0.03), Vector3(0.08, 0.12, 0.02), 0.04, 0.0, 3, Color(0.42, 0.5, 0.26)))
	var tufts: Array[MeshInstance3D] = []
	for i in 14:
		var tuft := _piece(tuft_mesh)
		# Either side of the horse's path, never under its hooves.
		tuft.set_meta("x", (0.6 + fmod(i * 0.53, 1.0)) * (1.0 if i % 2 else -1.0))
		tuft.set_meta("z0", i * 0.55)
		tufts.append(tuft)
	_parts["tufts"] = tufts
	var dust: Array[Node3D] = []
	for i in 3:
		dust.append(_puff(Color(0.62, 0.52, 0.4), 5))
	_parts["dust"] = dust
	_parts["shadow"].scale = Vector3(0.75, 1, 1.5)
	_parts["shadow"].position.z = 0.7


func _charge(t: float, _delta: float) -> void:
	# Galloping hard all through; the dummies are met at 1.0 s and 1.25 s.
	_steed_gait(1.0)
	_steed.position.y = absf(sin(t * 14.0)) * 0.06
	for tuft: MeshInstance3D in _parts["tufts"]:
		var z := fmod(float(tuft.get_meta("z0")) + t * CHARGE_SPEED, 7.7) - 4.6
		tuft.position = Vector3(float(tuft.get_meta("x")), 0, z)
		tuft.visible = absf(z) < 3.2
	var dummies: Array = _parts["dummies"]
	for i in dummies.size():
		var d: MeshInstance3D = dummies[i]
		var side: float = d.get_meta("side")
		var meet := 1.0 + i * 0.25 # when the lance (or the horse's chest) reaches it
		var z := -1.1 - (meet - t) * CHARGE_SPEED
		if t < meet:
			d.position = Vector3(side, 0, z)
			d.rotation = Vector3.ZERO
			d.visible = z > -4.0
		else:
			# Struck: thrown up, aside and back down the field, turning over.
			var k := t - meet
			var away := signf(side + 0.2) if side != 0.0 else 1.0
			d.position = Vector3(side + away * k * 3.2, maxf(0.0, k * 4.5 - k * k * 9.0), -1.1 + k * (CHARGE_SPEED - 2.5))
			d.rotation = Vector3(-k * 5.0, 0, -away * k * 7.0)
			d.visible = k < 1.1
	var dust: Array = _parts["dust"]
	for i in dust.size():
		var age := fmod(t + i * 0.27, 0.8)
		(dust[i] as Node3D).position = Vector3(0.25 * (1 if i % 2 else -1), 0.1, 1.4 + age * CHARGE_SPEED * 0.4)
		_show_puff(dust[i], age, 0.8, 0.45)


# --- Consecration -------------------------------------------------------------------------
# The Paladin plants the standard; the ring of gold light opens round it; the Paladin mends inside it,
# and a zombie that walks in burns and slows.

const HOLY_RADIUS := 1.1
const HOLY_AT := Vector2(0.3, -0.3) # where the standard goes in; the ring is round it
const HOLY_FOE := Vector2(1.75, -1.3)
const PALADIN := Vector2(-0.4, 0.15)

func _build_consecration() -> void:
	_person = _make_person("chivalry", "lance", _at(PALADIN))
	(_person["holder"] as Node3D).rotation.y = _facing(_at(PALADIN), _at(Vector2(0.2, 2.5)))
	var standard := Consecration.standard()
	standard.scale = Vector3.ONE * 0.75
	add_child(standard)
	_parts["standard"] = standard
	var rim := MeshInstance3D.new()
	rim.mesh = Consecration.rim_mesh(1.0, func(_flat: Vector3) -> float: return -0.05)
	rim.material_override = Consecration.light_material()
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	_parts["rim"] = rim
	var wash := Consecration.wash(1.0)
	add_child(wash)
	_parts["wash"] = wash
	var mote := QuadMesh.new()
	mote.size = Vector2(0.07, 0.07)
	mote.material = Consecration.mote_material()
	var motes: Array[MeshInstance3D] = []
	for i in 16:
		var m := _piece(mote)
		m.set_meta("a", TAU * i / 16.0 + i * 0.7)
		m.set_meta("r", 0.35 + fmod(i * 0.37, 1.0) * 0.95)
		motes.append(m)
	_parts["motes"] = motes
	# Mending: small gold crosses rising off the Paladin.
	var cross := _mesh(func(l: LowPoly) -> void:
		l.box(Vector3.ZERO, Vector3(0.08, 0.26, 0.08), GOLD)
		l.box(Vector3.ZERO, Vector3(0.26, 0.08, 0.08), GOLD))
	var mends: Array[MeshInstance3D] = []
	for i in 3:
		mends.append(_piece(cross, _glow(Color(1.0, 0.9, 0.5))))
	_parts["mends"] = mends
	var z := _make_zombie(_at(HOLY_FOE))
	_parts["zombie"] = z
	var flame := _mesh(func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3.UP * 0.45, 0.13, 0.0, 5, Color(1, 0.42, 0.06))
		l.prism(Vector3.ZERO, Vector3.UP * 0.26, 0.08, 0.0, 5, Color(1, 0.85, 0.15)))
	var flames: Array[MeshInstance3D] = []
	for i in 4:
		var f := _piece(flame, null)
		flames.append(f)
	_parts["flames"] = flames


func _consecrate(t: float) -> void:
	var anim: AnimationPlayer = _person["anim"]
	_play(anim, "Stomp" if t > 0.25 and t < 1.0 else "Idle")
	var standard: Node3D = _parts["standard"]
	var at := _at(HOLY_AT)
	var fall := _window(t, 0.35, 0.6)
	standard.position = at + Vector3.UP * 2.2 * (1.0 - fall * fall)
	standard.visible = t > 0.35 and t < 3.35
	var open := _ease_out(_window(t, 0.6, 1.0)) * (1.0 - _window(t, 3.1, 3.4))
	for n: String in ["rim", "wash"]:
		var piece: MeshInstance3D = _parts[n]
		piece.position = Vector3(at.x, piece.position.y, at.z)
		piece.scale = Vector3(HOLY_RADIUS * open, 1.0, HOLY_RADIUS * open)
		piece.visible = open > 0.01
	((_parts["wash"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.12 + 0.06 * sin(t * 5.0)
	for m: MeshInstance3D in _parts["motes"]:
		var a: float = m.get_meta("a")
		var rise := fmod(t * 0.55 + a, 1.0)
		m.position = at + Vector3(cos(a), 0, sin(a)) * float(m.get_meta("r")) * HOLY_RADIUS * 0.95 * open + Vector3.UP * (0.1 + rise * 1.3)
		m.visible = open > 0.3
	var mends: Array = _parts["mends"]
	var body_at: Vector3 = (_person["holder"] as Node3D).position
	for i in mends.size():
		var k := fmod(t * 0.9 + i / 3.0, 1.0)
		var m: MeshInstance3D = mends[i]
		m.position = body_at + _at(Vector2(-0.45 + 0.45 * i, 0.2)) + Vector3.UP * (0.9 + k * 1.3)
		m.scale = Vector3.ONE * (1.0 - k * 0.6)
		m.rotation.y = -rotation.y
		m.visible = open > 0.6 and t < 3.1
	# The zombie walks in at its own pace, then at half of it in the light, burning.
	var z: Dictionary = _parts["zombie"]
	var zh: Node3D = z["holder"]
	var start := _at(HOLY_FOE)
	var inside := 0.0
	var walk := t * 0.6
	if t > 1.4:
		walk = 1.4 * 0.6 + (t - 1.4) * 0.22
		inside = 1.0
	var dir := (at - start).normalized()
	zh.position = start + dir * minf(walk, 1.0)
	zh.rotation.y = atan2(-dir.x, -dir.z)
	(z["anim"] as AnimationPlayer).speed_scale = 0.45 if inside > 0.0 else 1.0
	zh.visible = t < 3.35
	var flames: Array = _parts["flames"]
	for i in flames.size():
		var f: MeshInstance3D = flames[i]
		f.visible = inside > 0.0 and zh.visible
		var flick := 0.8 + 0.3 * sin(t * 17.0 + i * 1.9)
		f.position = zh.position + Vector3(0.18 * cos(i * 1.6), 0.5 + i * 0.32, 0.18 * sin(i * 1.6))
		f.scale = Vector3(1.0, flick, 1.0)


# --- Whistle ------------------------------------------------------------------------------
# The Horse Archer whistles; the horse comes at a gallop from across the field, and the archer is up.

const ARCHER := Vector2(0.65, 0.1)

func _build_whistle() -> void:
	_person = _make_person("chivalry", "bow", _at(ARCHER))
	_steed = _make_steed(false)
	var note := _mesh(func(l: LowPoly) -> void:
		l.box(Vector3(0, 0, 0), Vector3(0.11, 0.08, 0.04), Color(1, 1, 1))
		l.box(Vector3(0.045, 0.13, 0), Vector3(0.025, 0.24, 0.025), Color(1, 1, 1))
		l.box(Vector3(0.09, 0.22, 0), Vector3(0.09, 0.03, 0.025), Color(1, 1, 1)))
	var notes: Array[MeshInstance3D] = []
	for i in 3:
		notes.append(_piece(note, _glow(Color(1.0, 0.95, 0.75))))
	_parts["notes"] = notes
	var dust: Array[Node3D] = []
	for i in 3:
		dust.append(_puff(Color(0.62, 0.52, 0.4), 5))
	_parts["dust"] = dust
	_parts["mount"] = _puff(Color(0.75, 0.68, 0.56), 7)


func _whistle(t: float) -> void:
	var anim: AnimationPlayer = _person["anim"]
	var mounted := t >= 2.25 and t < 3.6
	var notes: Array = _parts["notes"]
	for i in notes.size():
		var k := _window(t, 0.15 + i * 0.18, 1.0 + i * 0.18)
		var n: MeshInstance3D = notes[i]
		n.visible = k > 0.0 and k < 1.0
		n.position = _at(ARCHER) + _at(Vector2(0.15 + k * 0.6, -k * 0.2)) + Vector3.UP * (1.75 + k * 0.55 + sin(k * 9.0 + i) * 0.06)
		n.rotation.y = -rotation.y
		n.scale = Vector3.ONE * (0.8 + 0.4 * sin(k * PI))
	# The horse: from far off at a gallop, slowing to stand beside the archer.
	var from := _at(Vector2(-2.4, -2.6))
	var to := _at(Vector2(-0.3, -0.95))
	var k := _ease_out(_window(t, 0.5, 1.9))
	if not mounted:
		_steed.position = from.lerp(to, k)
		var heading := (to - from).normalized()
		# It comes up turning broadside, its head towards the archer.
		_steed.rotation.y = lerp_angle(atan2(-heading.x, -heading.z), _facing(Vector3.ZERO, _at(Vector2(-0.55, 1.0))), _window(t, 1.3, 2.0))
		_steed_gait(clampf((1.0 - k) * 1.6, 0.0, 1.0))
		_steed.position.y = absf(sin(t * 13.0)) * 0.05 * (1.0 - k)
		_steed.visible = t >= 0.5 and t < 3.6
		_stand(_person, _at(ARCHER))
		_play(anim, "Whistle" if t < 0.95 else "Idle")
		(_person["holder"] as Node3D).visible = t < 3.6
	else:
		if (_person["holder"] as Node3D).get_parent() != _steed:
			_seat(_person, _steed)
		_steed_gait(0.0)
		_play(anim, "Ride")
	var dust: Array = _parts["dust"]
	for i in dust.size():
		var age := fmod(t + i * 0.3, 0.9)
		(dust[i] as Node3D).position = _steed.position + Vector3(0, 0.1, 0) - (to - from).normalized() * (0.8 + age * 0.5)
		_show_puff(dust[i], age if t > 0.5 and t < 1.7 else -1.0, 0.9, 0.4)
	_show_puff(_parts["mount"], t - 2.2, 0.5, 0.45)
	(_parts["mount"] as Node3D).position = _steed.position + Vector3.UP * 0.8


# --- Grave Call -------------------------------------------------------------------------
# The Necromancer raises the staff over three fresh graves; violet wisps go down into them, and three
# skeletons climb out, stand a while, and fall back to dust.

const GRAVES := [Vector2(-0.15, 0.5), Vector2(-0.95, -0.05), Vector2(-1.55, -0.95)]
const NECROMANCER := Vector2(0.95, -0.35)
var _graves: Array[Vector3] = []
var _necromancer := Vector3.ZERO

func _build_graves() -> void:
	_necromancer = _at(NECROMANCER)
	for g: Vector2 in GRAVES:
		_graves.append(_at(g))
	_person = _make_person("magician", "staff", _necromancer)
	(_person["holder"] as Node3D).rotation.y = _facing(_necromancer, _graves[1])
	var mound := _mesh(func(l: LowPoly) -> void:
		l.box(Vector3(0, 0.05, 0), Vector3(0.55, 0.1, 0.85), EARTH)
		l.box(Vector3(0, 0.12, 0), Vector3(0.4, 0.08, 0.65), EARTH.lightened(0.08))
		l.box(Vector3(0, 0.32, -0.48), Vector3(0.36, 0.55, 0.1), Color(0.48, 0.48, 0.46))
		l.box(Vector3(0, 0.62, -0.48), Vector3(0.26, 0.1, 0.1), Color(0.48, 0.48, 0.46)))
	var skeletons: Array[Dictionary] = []
	var wisps: Array[MeshInstance3D] = []
	var rings: Array[MeshInstance3D] = []
	var clods: Array[MeshInstance3D] = []
	var clod := _mesh(func(l: LowPoly) -> void: l.box(Vector3.ZERO, Vector3(0.09, 0.07, 0.08), EARTH.lightened(0.1)))
	var orb := SphereMesh.new()
	orb.radius = 0.09
	orb.height = 0.18
	orb.radial_segments = 8
	orb.rings = 4
	for i in GRAVES.size():
		var g := _piece(mound)
		g.position = _graves[i]
		g.rotation.y = _facing(_graves[i], _necromancer) + PI
		var holder := Node3D.new()
		add_child(holder)
		var bones: Node3D = (load("res://assets/characters/skeleton.glb") as PackedScene).instantiate()
		bones.rotation.y = PI
		holder.add_child(bones)
		var top := 0.0
		for mi in bones.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			top = maxf(top, (mi as MeshInstance3D).get_aabb().end.y)
		bones.scale = Vector3.ONE * 1.8 / maxf(top, 0.5) # as tall as a raised skeleton in a night
		var anim: AnimationPlayer = bones.find_children("*", "AnimationPlayer", true, false)[0]
		if anim.has_animation("Idle"):
			anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		holder.position = _graves[i]
		holder.rotation.y = _facing(_graves[i], _necromancer)
		skeletons.append({"holder": holder, "anim": anim})
		wisps.append(_piece(orb, _glow(GRAVE_MIST)))
		var ring := _ring(GRAVE_MIST, 0.55)
		ring.position = _graves[i] + Vector3(0, 0.04, 0)
		rings.append(ring)
		for c in 5:
			var piece := _piece(clod)
			piece.set_meta("grave", i)
			piece.set_meta("dir", Vector3(cos(c * 1.3 + i), 1.0, sin(c * 1.3 + i)))
			clods.append(piece)
	_parts["skeletons"] = skeletons
	_parts["wisps"] = wisps
	_parts["rings"] = rings
	_parts["clods"] = clods


func _grave_call(t: float) -> void:
	_play(_person["anim"], "Raise" if t > 0.2 and t < 1.4 else "Idle")
	var staff_top: Vector3 = _necromancer + Vector3(0, 2.15, 0)
	var wisps: Array = _parts["wisps"]
	var rings: Array = _parts["rings"]
	var skeletons: Array = _parts["skeletons"]
	for i in GRAVES.size():
		var grave: Vector3 = _graves[i]
		var go := _window(t, 0.55 + i * 0.08, 0.95 + i * 0.08)
		var w: MeshInstance3D = wisps[i]
		w.visible = go > 0.0 and go < 1.0
		w.position = staff_top.lerp(grave, go) + Vector3.UP * sin(go * PI) * 0.6
		var rise := _ease_out(_window(t, 0.95 + i * 0.1, 1.55 + i * 0.1))
		var sink := _window(t, 3.0 + i * 0.06, 3.5 + i * 0.06)
		var s: Dictionary = skeletons[i]
		var holder: Node3D = s["holder"]
		var up := rise * (1.0 - sink)
		holder.visible = up > 0.02
		holder.scale = Vector3(1.0, maxf(up, 0.02), 1.0)
		holder.position = grave + Vector3(0, -0.15 * (1.0 - up), 0)
		holder.rotation.z = sin(t * 2.0 + i) * 0.04 * up
		_play(s["anim"], "Idle")
		var r: MeshInstance3D = rings[i]
		var glow := clampf(_window(t, 0.9, 1.1) * (1.0 - _window(t, 2.0, 2.6)) + _window(t, 2.95, 3.1) * (1.0 - _window(t, 3.4, 3.7)), 0.0, 1.0)
		r.visible = glow > 0.01
		r.scale = Vector3.ONE * (0.35 + 0.25 * glow)
		(r.material_override as StandardMaterial3D).albedo_color.a = 0.6 * glow
	for c: MeshInstance3D in _parts["clods"]:
		var i: int = c.get_meta("grave")
		var k := t - (0.95 + i * 0.1)
		c.visible = k > 0.0 and k < 0.55
		var dir: Vector3 = c.get_meta("dir")
		c.position = _graves[i] + Vector3(dir.x * k * 0.9, 0.15 + k * 2.4 - k * k * 6.0, dir.z * k * 0.9)
		c.rotation = Vector3(k * 9.0, k * 5.0, 0)


# --- Frost Nova ---------------------------------------------------------------------------
# Two zombies close in; the Elementalist strikes the ground; ice runs out all round, the zombies are
# struck and stand frozen, coloured as frozen creatures are in a night, until the ice lets go.

const NOVA_REACH := 1.2

func _build_nova() -> void:
	_person = _make_person("magician", "staff")
	var foes: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		foes.append(_make_zombie(_at(Vector2(side * 1.7, -1.4)), "normal_a" if side < 0 else "normal_b"))
	_parts["foes"] = foes
	var spike := _mesh(func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0, 0.55, 0), 0.09, 0.0, 4, Color(0.78, 0.93, 1.0)))
	var spikes: Array[MeshInstance3D] = []
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.75, 0.92, 1.0, 0.85)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.emission_enabled = true
	ice.emission = FROST
	ice.emission_energy_multiplier = 0.5
	ice.roughness = 0.15
	for i in 18:
		var s := _piece(spike, ice)
		s.set_meta("a", TAU * i / 18.0)
		spikes.append(s)
	_parts["spikes"] = spikes
	_parts["ring"] = _ring(FROST, 0.7, 0.12)
	var swirl: Array[MeshInstance3D] = []
	var flake := _mesh(func(l: LowPoly) -> void: l.box(Vector3.ZERO, Vector3(0.06, 0.06, 0.06), Color(0.9, 0.97, 1.0)))
	for i in 10:
		swirl.append(_piece(flake, _glow(Color(0.9, 0.97, 1.0))))
	_parts["swirl"] = swirl


func _nova(t: float) -> void:
	const BURST := 1.05
	_play(_person["anim"], "Stomp" if t > 0.75 and t < 1.6 else "Idle")
	var frozen := t >= BURST and t < 2.85
	var foes: Array = _parts["foes"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var holder: Node3D = z["holder"]
		var side := -1.0 if i == 0 else 1.0
		var start := _at(Vector2(side * 1.7, -1.4))
		var stop := _at(Vector2(side * 1.0, -0.2)) # walking in, to about a metre off
		var knocked := _ease_out(_window(t, BURST, BURST + 0.25)) * 0.12
		var dir := (stop - start).normalized()
		holder.position = start.lerp(stop, minf(t, BURST) / BURST - knocked)
		holder.rotation.y = atan2(-dir.x, -dir.z)
		holder.visible = t < 3.25
		var anim: AnimationPlayer = z["anim"]
		if frozen:
			anim.pause()
		else:
			_play(anim, "Walking_A")
		for part: MeshInstance3D in z["parts"]:
			part.set_meta("skin", part.get_meta("skin", part.material_override))
			part.material_override = Zombie.ice_material() if frozen else part.get_meta("skin")
	var grow := _ease_out(_window(t, BURST, BURST + 0.3))
	var fade := _window(t, 1.9, 2.5)
	for s: MeshInstance3D in _parts["spikes"]:
		var a: float = s.get_meta("a")
		var r := 0.25 + grow * (NOVA_REACH - 0.25) * (0.75 + 0.25 * sin(a * 3.0))
		s.position = Vector3(cos(a) * r, -0.05, sin(a) * r)
		s.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5) * -1.0
		s.scale = Vector3.ONE * grow * (1.0 - fade) * (0.8 + 0.4 * absf(sin(a * 5.0)))
		s.visible = grow > 0.0 and fade < 1.0
	var ring: MeshInstance3D = _parts["ring"]
	ring.visible = grow > 0.0 and fade < 1.0
	ring.scale = Vector3.ONE * (0.2 + grow * NOVA_REACH)
	(ring.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - fade)
	var swirl: Array = _parts["swirl"]
	for i in swirl.size():
		var f: MeshInstance3D = swirl[i]
		var k := _window(t, 0.3, BURST)
		var a := TAU * i / swirl.size() + t * 4.0
		var r := 1.1 * (1.0 - k)
		f.position = Vector3(cos(a) * r, 0.6 + 0.9 * k + 0.2 * sin(i), sin(a) * r)
		f.visible = t > 0.3 and t < BURST


# --- Hall of Mirrors ------------------------------------------------------------------------
# A zombie swings at the Illusionist; mist bursts where the Illusionist stood, the Illusionist is
# already two strides away, and the blow falls on a mirror image left behind, which shatters.

func _build_mirrors() -> void:
	_person = _make_person("magician", "staff", _at(MIRROR_FROM))
	var image := _make_person("magician", "staff", _at(MIRROR_FROM))
	for part: MeshInstance3D in (image["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		part.material_override = Ally._ghost()
	_parts["image"] = image
	_parts["zombie"] = _make_zombie(_at(MIRROR_FOE), "normal_b")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.9, 1.0, 0.8)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 1.0
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = Color(0.7, 0.75, 1.0)
	glass.emission_energy_multiplier = 0.6
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shard := _mesh(func(l: LowPoly) -> void:
		l.gable(Vector3(-0.08, 0, 0), Vector3(0.08, 0, 0), Vector3(0, 0.2, 0), Color(1, 1, 1)))
	var shards: Array[MeshInstance3D] = []
	for i in 14:
		var s := _piece(shard, glass)
		s.set_meta("dir", Vector3(cos(i * 2.39), 0.2 + fmod(i * 0.37, 1.0) * 0.9, sin(i * 2.39)))
		shards.append(s)
	_parts["shards"] = shards
	_parts["mist_from"] = _puff(Color(0.78, 0.72, 0.95), 7)
	_parts["mist_to"] = _puff(Color(0.78, 0.72, 0.95), 6)


const MIRROR_FROM := Vector2(-0.25, 0.2)
const MIRROR_TO := Vector2(-1.35, -1.4)
const MIRROR_FOE := Vector2(1.8, -0.3)
const MIRROR_BLOW := Vector2(0.55, 0.1) # where the zombie stands to strike

func _mirrors(t: float) -> void:
	const SWAP := 1.0
	var from := _at(MIRROR_FROM)
	var to := _at(MIRROR_TO)
	var holder: Node3D = _person["holder"]
	holder.position = from if t < SWAP else to
	var foe_at := _at(MIRROR_BLOW)
	var look := foe_at - holder.position
	holder.rotation.y = atan2(-look.x, -look.z)
	holder.visible = t < 3.25
	_play(_person["anim"], "Idle")
	# The image is left where the Illusionist stood, takes the blow, and breaks.
	var image: Dictionary = _parts["image"]
	var ih: Node3D = image["holder"]
	ih.visible = t >= SWAP and t < 1.32
	ih.position = from
	ih.rotation.y = atan2(-(foe_at - from).x, -(foe_at - from).z)
	# The zombie: up to the Illusionist, the blow, then a look round at where they went.
	var z: Dictionary = _parts["zombie"]
	var zh: Node3D = z["holder"]
	var walk := minf(t, 0.75) / 0.75
	zh.position = _at(MIRROR_FOE).lerp(foe_at, walk)
	var at_them := from - foe_at
	# After the blow it turns, looking for where the Illusionist went.
	zh.rotation.y = atan2(-at_them.x, -at_them.z) - (sin(_window(t, 1.6, 2.7) * PI) * 0.9 if t > 1.6 else 0.0)
	zh.visible = t < 3.25
	if t < 0.75:
		_play(z["anim"], "Walking_A")
	elif t < 1.45:
		_play(z["anim"], "1H_Melee_Attack_Chop")
	else:
		_play(z["anim"], "Idle")
	var break_at := 1.3
	for s: MeshInstance3D in _parts["shards"]:
		var k := t - break_at
		s.visible = k >= 0.0 and k < 0.7
		var dir: Vector3 = s.get_meta("dir")
		s.position = from + Vector3(0, 1.0, 0) + Vector3(dir.x * k * 1.8, dir.y * k * 2.0 - k * k * 3.0, dir.z * k * 1.8)
		s.rotation = Vector3(k * 8.0, k * 6.0 + dir.x, 0)
	(_parts["mist_from"] as Node3D).position = from + Vector3.UP * 0.9
	(_parts["mist_to"] as Node3D).position = to + Vector3.UP * 0.9
	_show_puff(_parts["mist_from"], t - SWAP, 0.8, 0.75)
	_show_puff(_parts["mist_to"], t - SWAP - 0.05, 0.6, 0.6)


# --- Mounts ---------------------------------------------------------------------------------
# The class in the saddle of a horse or of the White Stag, walking on the spot.

func _build_mounted(class_id: String, stag: bool) -> void:
	_steed = _make_steed(stag)
	_person = _make_person(class_id, ClassDefs.ALL[class_id]["weapon"])
	_seat(_person, _steed)
	_play(_person["anim"], "Ride")
	_parts["shadow"].scale = Vector3(0.7, 1, 1.4)


func _walk_mount() -> void:
	_steed_gait(0.32)
	_steed.position.y = absf(sin(clock * 5.5)) * 0.025
