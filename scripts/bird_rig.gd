class_name BirdRig
extends Node3D
## Every bird in the game, as a body that can be posed: the Beastmaster's crow and the Raven familiar
## ("crow"), the Carrion Crows of the Village and the Fort ("carrion"), and the Eagles and Mist Eagles
## of the peaks ("eagle", "mist_eagle"). One rig, one way of flying; each kind its own build, colours,
## wingbeat and glide (KINDS).
##
## Its parts: shoulders and elbows, so a wing folds on the upstroke and opens on the downstroke; a tail
## that fans and steers; a head that snaps round to look; a beak that opens to call; and feet tucked in
## flight, dangling in a hover, thrown forward to strike.
##
## Its ways of being, blended into each other so it never jumps from one to the next:
##   hovering   it hangs in the air beating its wings, tail spread, looking about and calling now and
##              then; "screeching" (an enemy about to dive) it beats harder, head out, beak open;
##   flying     it pitches forward and flies: a few strong beats, then a glide (an eagle soars longer);
##              climbing, it beats hard and fast with its nose up;
##   striking   strike(): it folds its wings and drops on its prey, flares, throws its talons forward
##              and pecks, then beats its way back up (the pet, which stays at its height);
##   stooping   an enemy's dive: wings swept back and folded, body along the line of its fall; near
##              the ground its wings flare and its talons come forward, and as the dive ends it rakes.
## Enemies are moved by drive(z), from the creature's own flight (Zombie._fly) on the host and from
## the way it moves on other phones.

## Pose channels. A pose is one number per channel; the ways of being are blended channel by channel.
enum {BODY_Y, PITCH, LIFT, SWEEP, ELBOW_LIFT, ELBOW_SWEEP, TAIL_X, TAIL_FAN, FEET, HEAD_X, JAW, COUNT}
enum { HOVER, FLIGHT, STRIKE, STOOP }

const STRIKE_TIME := 0.62 # the whole drop, strike and climb back
const STRIKE_LOW := 0.36 # how far into it the talons reach the prey
const FLARE_TIME := 0.32 # the rake at the end of an enemy's dive
const BLEND := 7.0 # how quickly it changes from one way of being to the next
const CALL_TIME := 0.38
## Each kind: its size; its wings (length of the arm and hand, and their breadth); its beats a second
## hovering, flying and climbing; how many beats before a glide and how long it glides; its colours
## (feathers, gloss, head, tail, beak, eyes, feet); whether its eyes glow and whether it is of the mist;
## its beak (a crow's heavy bill or an eagle's hook); and how often it calls.
const KINDS := {
	"crow": {"size": 1.0, "wing": 1.0, "chord": 1.0, "hover": 3.4, "flight": 4.2, "climb": 6.0, "flaps": 3, "glide": 0.55,
		"ink": Color(0.075, 0.075, 0.1), "sheen": Color(0.15, 0.16, 0.3), "head": Color(0.085, 0.085, 0.11), "tail": Color(0.09, 0.09, 0.12),
		"beak": Color(0.2, 0.2, 0.23), "eye": Color(1.0, 0.72, 0.18), "feet": Color(0.16, 0.15, 0.15), "glow": false, "mist": false, "hook": false, "calls": Vector2(4.0, 7.5)},
	"carrion": {"size": 1.05, "wing": 1.05, "chord": 1.0, "hover": 3.6, "flight": 4.6, "climb": 6.4, "flaps": 3, "glide": 0.45,
		"ink": Color(0.08, 0.07, 0.1), "sheen": Color(0.2, 0.12, 0.2), "head": Color(0.1, 0.08, 0.1), "tail": Color(0.09, 0.08, 0.1),
		"beak": Color(0.5, 0.42, 0.22), "eye": Color(1.0, 0.18, 0.08), "feet": Color(0.2, 0.17, 0.14), "glow": true, "mist": false, "hook": false, "calls": Vector2(2.5, 5.0), "ragged": true},
	"eagle": {"size": 1.55, "wing": 1.25, "chord": 1.2, "hover": 2.6, "flight": 2.3, "climb": 3.6, "flaps": 2, "glide": 1.6,
		"ink": Color(0.33, 0.22, 0.13), "sheen": Color(0.46, 0.32, 0.17), "head": Color(0.94, 0.93, 0.88), "tail": Color(0.92, 0.91, 0.86),
		"beak": Color(1.0, 0.78, 0.2), "eye": Color(1.0, 0.85, 0.3), "feet": Color(1.0, 0.78, 0.2), "glow": false, "mist": false, "hook": true, "calls": Vector2(6.0, 11.0)},
	"mist_eagle": {"size": 1.55, "wing": 1.25, "chord": 1.2, "hover": 2.6, "flight": 2.3, "climb": 3.6, "flaps": 2, "glide": 1.6,
		"ink": Color(0.55, 0.82, 0.88), "sheen": Color(0.75, 0.95, 1.0), "head": Color(0.88, 0.98, 1.0), "tail": Color(0.8, 0.95, 1.0),
		"beak": Color(0.75, 0.95, 1.0), "eye": Color(0.45, 0.95, 1.0), "feet": Color(0.7, 0.9, 0.95), "glow": true, "mist": true, "hook": true, "calls": Vector2(6.0, 11.0)},
}

static var _meshes := {}

var kind := "crow"
var look: Dictionary
var moving := false
var screeching := false ## hovering about to dive: harder beats, head out, beak open
var climbing := false
var turn := 0.0 ## how fast it is turning (radians a second), so it banks into its turns
var dive := 1.3 ## how far it drops on its prey in a strike (the pet; an enemy's own flight is its dive)
var steep := 0.9 ## how steeply it is falling while it stoops (radians, nose down)
var low := 10.0 ## how high above the ground it is (metres): near it, a stooping bird flares and strikes

var body: Node3D
var head: Node3D
var jaw: Node3D
var tail: Node3D
var feet: Node3D
var shoulders: Array[Node3D] = [] # right, left
var elbows: Array[Node3D] = []

var _clock := 0.0
var _beat := 0.0 # wingbeat phase: 0 wings up, 0.5 wings down
var _flight := 0.0 # where it is in its beats-then-glide pattern, in seconds
var _strike := 0.0 # seconds left of a strike
var _stooping := false
var _flare := 0.0 # seconds left of the rake at the end of a dive
var _weights := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var _look := 0.0
var _head_y := 0.0
var _next_look := 0.8
var _next_call := 3.0
var _call := 0.0
var _roll := 0.0
var _last_pos := Vector3.INF
var _last_yaw := 0.0
var _vel := Vector3.ZERO


func _init(which := "crow") -> void:
	kind = which if KINDS.has(which) else "crow"
	look = KINDS[kind]
	name = "Raven" if kind == "crow" else "Bird"
	_next_call = randf_range(1.0, float(look["calls"].y))
	_build()
	_apply(_hover_pose())


## Drops on its prey. Starting another while it is still striking starts that one afresh.
func strike() -> void:
	_strike = STRIKE_TIME


func striking() -> bool:
	return _strike > 0.0


## An enemy diving (or not). When a dive ends, the bird rakes with its talons as it pulls up.
func stoop(on: bool) -> void:
	if _stooping and not on:
		_flare = FLARE_TIME
	_stooping = on


func _process(delta: float) -> void:
	advance(delta)


## Back to hovering, as it was made (a creature's body is used again).
func restart() -> void:
	_strike = 0.0
	_flare = 0.0
	_stooping = false
	screeching = false
	climbing = false
	moving = false
	_last_pos = Vector3.INF
	_vel = Vector3.ZERO
	_weights = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])


## Draws it on these render layers only (a familiar in the hands' view).
func set_layers(mask: int) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.layers = mask


## An enemy bird, moved by its creature: on the host its flight says when it hangs before a dive, dives
## and climbs away (Zombie._windup, _dive, _recover); on another phone that is read from its warning
## and from how it moves.
func drive(z: Zombie, delta: float) -> void:
	set_process(false)
	if delta <= 0.0:
		return
	var here := z.global_position
	if _last_pos != Vector3.INF:
		_vel = _vel.lerp((here - _last_pos) / delta, minf(1.0, delta * 8.0))
		turn = lerpf(turn, wrapf(z.rotation.y - _last_yaw, -PI, PI) / delta, minf(1.0, delta * 5.0))
	_last_pos = here
	_last_yaw = z.rotation.y
	var warning := z.is_warning()
	var diving := (z._dive > 0.0) if not z.puppet else (warning and _vel.y < -2.0)
	stoop(diving)
	screeching = warning and not diving
	climbing = (z._recover > 0.0) if not z.puppet else (not warning and _vel.y > 1.2)
	moving = _vel.length() > 0.6 or climbing
	steep = clampf(atan2(-_vel.y, Vector2(_vel.x, _vel.z).length() + 0.01), 0.25, 1.3)
	low = here.y - z.world.ground_at(here)
	advance(delta)


## Moves the bird on by this much time. Called every frame; tests call it directly.
func advance(delta: float) -> void:
	_clock += delta
	_strike = maxf(0.0, _strike - delta)
	_flare = maxf(0.0, _flare - delta)
	var want := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	if _strike > 0.0:
		want[STRIKE] = 1.0
	elif _stooping or _flare > 0.0:
		want[STOOP] = 1.0
	elif moving:
		want[FLIGHT] = 1.0
	else:
		want[HOVER] = 1.0
	var k := 1.0 - exp(-BLEND * (2.0 if _stooping or _flare > 0.0 else 1.0) * delta)
	for i in 4:
		_weights[i] = lerpf(_weights[i], want[i], k)
	var beats := lerpf(float(look["hover"]), float(look["flight"]), _weights[FLIGHT])
	if screeching:
		beats = float(look["hover"]) * 1.45
	if climbing or (_strike > 0.0 and _strike < STRIKE_TIME * (1.0 - STRIKE_LOW)):
		beats = float(look["climb"])
	if moving and _strike <= 0.0 and not climbing:
		_flight = fmod(_flight + delta, _beating() + float(look["glide"]))
	_beat = fmod(_beat + delta * beats, 1.0)
	_tick_head(delta)
	var pose := PackedFloat32Array()
	pose.resize(COUNT)
	var parts := [_hover_pose(), _flight_pose(), _strike_pose(), _stoop_pose()]
	var total := _weights[0] + _weights[1] + _weights[2] + _weights[3]
	for which in 4:
		var w := _weights[which] / maxf(total, 0.0001)
		if w < 0.0001:
			continue
		var p: PackedFloat32Array = parts[which]
		for c in COUNT:
			pose[c] += p[c] * w
	_roll = lerpf(_roll, clampf(-turn * 0.16, -0.6, 0.6) * (1.0 - _weights[STRIKE] - _weights[STOOP] * 0.7), k)
	_apply(pose)


func _beating() -> float:
	return float(look["flaps"]) / float(look["flight"])


## The wings through one beat. Down from high over its back to low under its belly with the wing open;
## back up with the wing folded at the elbow, the hand trailing, so it does not push itself down again.
## The body rises a little on each downstroke.
func _flap(p: PackedFloat32Array, beat: float, size := 1.0) -> void:
	var fold := maxf(0.0, -sin(TAU * beat))
	p[LIFT] = 0.2 + 0.78 * size * cos(TAU * beat)
	p[SWEEP] = 0.05 + 0.22 * fold
	p[ELBOW_LIFT] = -0.42 * fold
	p[ELBOW_SWEEP] = 0.1 + 0.8 * fold
	p[BODY_Y] = 0.035 * size * sin(TAU * beat)


func _hover_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(COUNT)
	_flap(p, _beat, 1.1 if screeching else 1.0)
	p[PITCH] = -0.42 if not screeching else -0.6 # hanging upright in the air; rearing back to dive
	p[TAIL_X] = -0.2
	p[TAIL_FAN] = 1.5 if not screeching else 1.75
	p[FEET] = (0.2 + 0.08 * sin(_clock * 2.3)) if not screeching else 0.9
	# Holding its head level, or up to call; screeching, thrust out at its prey with the beak wide.
	p[HEAD_X] = 0.75 if screeching else 0.32 + (-0.35 if _call > 0.0 else 0.0)
	p[JAW] = (0.55 + 0.1 * sin(_clock * 30.0)) if screeching else 0.5 * sin(PI * clampf(_call / CALL_TIME, 0.0, 1.0))
	return p


func _flight_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(COUNT)
	var beating := _beating()
	var glide_time := float(look["glide"])
	# A few beats, then it holds its wings out and glides; the beats ease into the glide and out of it.
	var glide := 0.0 if climbing else smoothstep(beating - 0.12, beating + 0.06, _flight) * (1.0 - smoothstep(beating + glide_time - 0.1, beating + glide_time, _flight))
	_flap(p, _beat, 1.15 if climbing else 1.0)
	var still := PackedFloat32Array([0.0, 0.0, 0.14, 0.12, 0.04, 0.06])
	for c in [BODY_Y, LIFT, SWEEP, ELBOW_LIFT, ELBOW_SWEEP]:
		p[c] = lerpf(p[c], still[c], glide)
	p[PITCH] = -0.35 if climbing else 0.16 - 0.08 * glide
	p[TAIL_X] = -0.15 if climbing else 0.06
	p[TAIL_FAN] = 1.0 + 0.25 * glide + (0.3 if climbing else 0.0)
	p[FEET] = 1.35
	p[HEAD_X] = 0.2 if climbing else -0.12
	return p


## Wings folded back, it drops head first; at the bottom it flares, wings up and forward, and throws
## its talons at its prey, pecking; then it beats hard to climb back to where it was.
func _strike_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(COUNT)
	var s := 1.0 - _strike / STRIKE_TIME # 0 → 1 through the strike
	if s < STRIKE_LOW:
		var d := smoothstep(0.0, STRIKE_LOW, s)
		p[BODY_Y] = -dive * d * d
		p[PITCH] = 0.95 * smoothstep(0.0, 0.4, s / STRIKE_LOW)
		p[LIFT] = 0.4
		p[SWEEP] = 0.95
		p[ELBOW_LIFT] = -0.2
		p[ELBOW_SWEEP] = 1.25
		p[TAIL_X] = 0.25
		p[TAIL_FAN] = 0.8
		p[FEET] = 1.35 - 1.6 * smoothstep(0.6, 1.0, s / STRIKE_LOW)
		p[HEAD_X] = 0.2
	elif s < STRIKE_LOW + 0.16:
		var f := (s - STRIKE_LOW) / 0.16 # the flare and the blow
		p[BODY_Y] = -dive
		_rake(p, f)
	else:
		var c := smoothstep(STRIKE_LOW + 0.16, 1.0, s)
		_flap(p, _beat, 1.15)
		p[BODY_Y] += -dive * (1.0 - c)
		p[PITCH] = lerpf(-0.7, -0.3, c)
		p[TAIL_X] = -0.25
		p[TAIL_FAN] = 1.4
		p[FEET] = lerpf(-0.6, 0.6, c)
		p[HEAD_X] = 0.2
	return p


## The blow itself, f from 0 to 1: wings thrown up and forward to brake, tail spread and down, talons
## forward, a peck.
func _rake(p: PackedFloat32Array, f: float) -> void:
	p[PITCH] = lerpf(0.95, -0.7, smoothstep(0.0, 0.5, f))
	p[LIFT] = lerpf(0.4, 1.05, smoothstep(0.0, 0.4, f))
	p[SWEEP] = lerpf(0.95, -0.3, smoothstep(0.0, 0.4, f))
	p[ELBOW_SWEEP] = lerpf(1.25, -0.1, smoothstep(0.0, 0.4, f))
	p[TAIL_X] = -0.45
	p[TAIL_FAN] = 1.7
	p[FEET] = -1.1
	p[HEAD_X] = 0.75 * sin(PI * f)
	p[JAW] = 0.45 * sin(PI * f)


## An enemy's dive: swept back and folded, falling down its own line; near the ground, the rake.
func _stoop_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(COUNT)
	if _flare > 0.0:
		_rake(p, 1.0 - _flare / FLARE_TIME * 0.6)
		return p
	var near := smoothstep(3.0 * float(look["size"]), 1.0, low)
	p[PITCH] = lerpf(steep, 0.6, near)
	p[LIFT] = lerpf(0.35, 0.6, near)
	p[SWEEP] = lerpf(1.05, 0.5, near)
	p[ELBOW_LIFT] = -0.2
	p[ELBOW_SWEEP] = lerpf(1.3, 0.6, near)
	p[TAIL_X] = 0.25
	p[TAIL_FAN] = lerpf(0.7, 1.3, near)
	p[FEET] = lerpf(1.35, -0.9, near)
	p[HEAD_X] = lerpf(-0.35, 0.3, near) # head stretched out along the fall, then down at its prey
	p[JAW] = 0.5 * near
	# The wind shakes its folded wings.
	p[LIFT] += sin(_clock * 37.0) * 0.04
	return p


## Birds look about in quick turns of the head, not slow sweeps, and call now and then while they hover.
func _tick_head(delta: float) -> void:
	_next_look -= delta
	if _next_look <= 0.0:
		_next_look = randf_range(0.5, 1.4)
		_look = randf_range(-0.75, 0.75) * (0.3 if moving else 1.0)
	_head_y = lerpf(_head_y, 0.0 if _stooping or screeching else _look, 1.0 - exp(-16.0 * delta))
	_call = maxf(0.0, _call - delta)
	_next_call -= delta
	if _next_call <= 0.0:
		_next_call = randf_range(float(look["calls"].x), float(look["calls"].y))
		if not moving and _strike <= 0.0 and not _stooping:
			_call = CALL_TIME


func _apply(p: PackedFloat32Array) -> void:
	body.position.y = p[BODY_Y] * float(look["size"])
	body.rotation = Vector3(p[PITCH], 0.0, _roll)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		shoulders[i].rotation = Vector3(0.0, side * p[SWEEP], side * p[LIFT])
		elbows[i].rotation = Vector3(0.0, side * p[ELBOW_SWEEP], side * p[ELBOW_LIFT])
	tail.rotation.x = p[TAIL_X]
	tail.scale.x = p[TAIL_FAN]
	feet.rotation.x = p[FEET]
	head.rotation = Vector3(p[HEAD_X], _head_y, 0.0)
	jaw.rotation.x = p[JAW]


static func _part(parent: Node3D, mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = material
	mi.set_meta("own_material", material)
	parent.add_child(mi)
	return mi


static func _pivot(parent: Node3D, called: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = called
	n.position = at
	parent.add_child(n)
	return n


func _build() -> void:
	if not _meshes.has(kind):
		_meshes[kind] = _make_meshes(look)
	var m: Dictionary = _meshes[kind]
	var skin: Material = MesenllaModels.ghost_material() if look["mist"] else null
	var eyes: Material = MesenllaModels.glow_material() if look["glow"] else skin
	scale = Vector3.ONE * float(look["size"])
	body = _pivot(self, "Body", Vector3.ZERO)
	_part(body, m["body"], skin)
	head = _pivot(body, "Head", Vector3(0, 0.06, 0.19))
	_part(head, m["head"], skin)
	_part(head, m["eyes"], eyes)
	jaw = _pivot(head, "Jaw", Vector3(0, 0.012, 0.12))
	_part(jaw, m["jaw"], skin)
	tail = _pivot(body, "Tail", Vector3(0, 0.02, -0.17))
	_part(tail, m["tail"], skin)
	feet = _pivot(body, "Feet", Vector3(0, -0.07, 0.03))
	_part(feet, m["feet"], skin)
	var reach := 0.27 * float(look["wing"])
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := _pivot(body, "Shoulder" + ("R" if i == 0 else "L"), Vector3(0.065 * side, 0.045, 0.06))
		_part(shoulder, m["arm_r" if i == 0 else "arm_l"], skin)
		var elbow := _pivot(shoulder, "Elbow", Vector3(reach * side, 0, 0))
		_part(elbow, m["hand_r" if i == 0 else "hand_l"], skin)
		shoulders.append(shoulder)
		elbows.append(elbow)


static func _make_meshes(look: Dictionary) -> Dictionary:
	var ink: Color = look["ink"]
	var sheen: Color = look["sheen"]
	var head_col: Color = look["head"]
	var beak: Color = look["beak"]
	var hook: bool = look["hook"]
	var out := {}
	var b := LowPoly.new()
	b.prism(Vector3(0, 0.0, -0.18), Vector3(0, 0.02, 0.14), 0.07, 0.095, 6, ink) # back and belly
	b.prism(Vector3(0, 0.02, 0.1), Vector3(0, 0.05, 0.22), 0.095, 0.068, 6, ink if not hook else head_col) # chest into the neck
	b.box(Vector3(0, 0.083, -0.02), Vector3(0.11, 0.018, 0.26), sheen) # the gloss (or the paler mantle) along its back
	for x: float in [-0.03, 0.0, 0.03]: # hackles at the throat
		b.prism(Vector3(x, 0.0, 0.2), Vector3(x * 1.4, -0.075, 0.17), 0.022, 0.0, 4, (ink if not hook else head_col).lightened(0.06))
	if hook:
		# An eagle's feathered legs: trousers of feathers down to the feet.
		for x: float in [-0.04, 0.04]:
			b.prism(Vector3(x, -0.05, 0.03), Vector3(x, -0.1, 0.04), 0.03, 0.022, 5, ink.lightened(0.08))
	out["body"] = b.commit()
	var h := LowPoly.new()
	h.box(Vector3(0, 0.035, 0.05), Vector3(0.125, 0.115, 0.15), head_col if hook else head_col.lightened(0.04)) # skull
	if hook:
		h.box(Vector3(0, 0.075, 0.1), Vector3(0.13, 0.03, 0.06), head_col.darkened(0.12)) # the brow over its eyes
		h.prism(Vector3(0, 0.045, 0.11), Vector3(0, 0.03, 0.22), 0.045, 0.02, 4, beak) # the hooked bill
		h.prism(Vector3(0, 0.03, 0.22), Vector3(0, -0.02, 0.25), 0.02, 0.0, 4, beak.darkened(0.15))
		h.box(Vector3(0, 0.05, 0.125), Vector3(0.06, 0.025, 0.03), beak.lightened(0.15)) # the cere
	else:
		h.box(Vector3(0, 0.088, 0.035), Vector3(0.1, 0.02, 0.11), sheen) # crown
		h.prism(Vector3(0, 0.045, 0.11), Vector3(0, 0.025, 0.27), 0.04, 0.0, 4, beak) # a crow's heavy bill
		h.box(Vector3(0, 0.06, 0.13), Vector3(0.05, 0.022, 0.04), ink) # the bristles over its nostrils
	out["head"] = h.commit()
	var e := LowPoly.new()
	for side: float in [-1.0, 1.0]:
		e.box(Vector3(0.063 * side, 0.055, 0.085), Vector3(0.014, 0.03, 0.03), look["eye"])
		if not look["glow"]:
			e.box(Vector3(0.068 * side, 0.058, 0.09), Vector3(0.008, 0.012, 0.012), Color(0.05, 0.04, 0.03)) # the pupil
			e.box(Vector3(0.069 * side, 0.064, 0.094), Vector3(0.006, 0.006, 0.006), Color(1, 1, 0.9)) # the glint
	out["eyes"] = e.commit()
	var j := LowPoly.new()
	if hook:
		j.prism(Vector3(0, -0.012, -0.005), Vector3(0, -0.012, 0.1), 0.025, 0.0, 4, beak.darkened(0.1))
	else:
		j.prism(Vector3(0, -0.012, -0.005), Vector3(0, -0.012, 0.13), 0.025, 0.0, 4, beak.darkened(0.2))
	out["jaw"] = j.commit()
	var t := LowPoly.new() # the tail: seven feathers side by side, the middle ones longest
	var tail_col: Color = look["tail"]
	var tail_len := 0.27 * (1.1 if hook else 1.0)
	for i in 7:
		var x := (i - 3) * 0.022 * (1.25 if hook else 1.0)
		var length := tail_len - absf(i - 3) * (0.008 if hook else 0.018)
		if look.get("ragged", false) and i % 3 == 1:
			length *= 0.78 # a torn feather
		t.turned_box(Vector3(x * 1.2, 0.0, -length * 0.5), Vector3(0.034 * (1.2 if hook else 1.0), 0.012, length), tail_col.darkened(0.04 * (i % 2)), Basis(Vector3.UP, -x * 2.4))
	t.box(Vector3(0, 0.012, -0.05), Vector3(0.1, 0.014, 0.1), ink.lightened(0.05)) # coverts over the root of the tail
	out["tail"] = t.commit()
	var f := LowPoly.new() # legs and feet, hanging down from the pivot under its belly
	var foot: Color = look["feet"]
	var claw := Color(0.12, 0.11, 0.1) if hook else foot
	var grip := 1.5 if hook else 1.0
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(0.035 * side, 0, 0)
		var ankle := Vector3(0.04 * side, -0.1, 0.01)
		f.prism(hip, ankle, 0.014 * grip, 0.01 * grip, 4, foot)
		for toe: Vector3 in [Vector3(0, 0, 0.055), Vector3(0.022 * side, 0, 0.045), Vector3(-0.018 * side, 0, 0.045), Vector3(0, 0, -0.04)]:
			var tip := ankle + toe * grip + Vector3(0, -0.012, 0)
			f.prism(ankle, tip, 0.008 * grip, 0.006 * grip, 3, foot)
			f.prism(tip, tip + toe.normalized() * 0.025 * grip + Vector3(0, -0.02, 0), 0.006 * grip, 0.0, 3, claw) # the talon
	out["feet"] = f.commit()
	for side: float in [1.0, -1.0]:
		var suffix := "_r" if side > 0.0 else "_l"
		out["arm" + suffix] = _arm(side, look)
		out["hand" + suffix] = _hand(side, look)
	return out


## The inner wing, from the shoulder to the elbow: coverts on top, the secondaries trailing behind.
## The left one is the right one in a mirror.
static func _arm(side: float, look: Dictionary) -> ArrayMesh:
	var w := float(look["wing"])
	var c := float(look["chord"])
	var ink: Color = look["ink"]
	var a := LowPoly.new()
	a.base = Transform3D(Basis.from_scale(Vector3(side * w, 1, c)), Vector3.ZERO)
	a.box(Vector3(0.135, 0.0, -0.01), Vector3(0.27, 0.032, 0.13), ink) # the leading edge and coverts
	a.box(Vector3(0.12, 0.018, 0.0), Vector3(0.22, 0.01, 0.09), look["sheen"]) # their gloss
	for i in 5: # secondaries
		var x := 0.03 + i * 0.058
		var length := 0.17 * (0.8 if look.get("ragged", false) and i % 2 == 1 else 1.0)
		a.turned_box(Vector3(x, -0.006, -0.055 - length * 0.5), Vector3(0.062, 0.012, length), ink.lightened(0.03 * (i % 2)), Basis(Vector3.UP, 0.06 * (i - 2)))
	return a.commit()


## The outer wing, from the elbow: the hand coverts and five long primaries spread like fingers.
static func _hand(side: float, look: Dictionary) -> ArrayMesh:
	var w := float(look["wing"])
	var c := float(look["chord"])
	var ink: Color = look["ink"]
	var a := LowPoly.new()
	a.base = Transform3D(Basis.from_scale(Vector3(side * w, 1, c)), Vector3.ZERO)
	a.box(Vector3(0.07, 0.0, -0.02), Vector3(0.15, 0.026, 0.12), ink)
	a.box(Vector3(0.05, 0.015, -0.0), Vector3(0.1, 0.01, 0.07), Color(look["sheen"]).darkened(0.15))
	var lengths := [0.31, 0.34, 0.33, 0.29, 0.24]
	for i in 5:
		var root := Vector3(0.12 - i * 0.025, -0.004, -0.02 - i * 0.03)
		var angle := 0.04 + i * 0.2 # sweeping further back, feather by feather
		var dir := Vector3(cos(angle), 0, -sin(angle))
		var length: float = lengths[i] * (0.8 if look.get("ragged", false) and i == 2 else 1.0)
		# An eagle's primaries are darker at the tips.
		var col := ink.lightened(0.02 * (i % 2)) if not look["hook"] else ink.darkened(0.25 + 0.05 * (i % 2))
		a.turned_box(root + dir * length * 0.5, Vector3(length, 0.011, 0.05 - i * 0.003), col, Basis(Vector3.UP, angle))
	return a.commit()
