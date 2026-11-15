class_name RavenRig
extends Node3D
## The Beastmaster's crow. A body that can be posed: shoulders and elbows, so a wing folds on the
## upstroke and opens on the downstroke; a tail that fans and steers; a head that snaps round to look;
## a beak that opens to caw; and feet tucked in flight, dangling in a hover, thrown forward to strike.
##
## It has three ways of being, blended into each other so it never jumps from one to the next:
##   hovering   (idle)   it hangs in the air beating its wings, tail spread, looking about and cawing;
##   flying     (moving) it pitches forward and flies like a crow: a few strong beats, then a glide;
##   striking   (action) strike(): it folds its wings and drops on its prey, flares, throws its talons
##                       forward and pecks, then beats its way back up.

## Pose channels. A pose is one number per channel; the three ways of being are blended channel by channel.
enum {BODY_Y, PITCH, LIFT, SWEEP, ELBOW_LIFT, ELBOW_SWEEP, TAIL_X, TAIL_FAN, FEET, HEAD_X, JAW, COUNT}

const HOVER_BEATS := 3.4 # wingbeats a second hanging in the air
const FLIGHT_BEATS := 4.2 # and flying
const CLIMB_BEATS := 6.0 # climbing back after a strike
const FLIGHT_FLAPS := 3 # strong beats before each glide
const GLIDE_TIME := 0.55
const STRIKE_TIME := 0.62 # the whole drop, strike and climb back
const STRIKE_LOW := 0.36 # how far into it the talons reach the prey
const BLEND := 7.0 # how quickly it changes from one way of being to the next
const CAW_EVERY := Vector2(4.0, 7.5)
const CAW_TIME := 0.38
const INK := Color(0.075, 0.075, 0.1)
const SHEEN := Color(0.15, 0.16, 0.3) # the blue-violet gloss on a crow's back and wings
const BEAK := Color(0.2, 0.2, 0.23)
const EYE := Color(1.0, 0.72, 0.18)

static var _meshes := {}

var moving := false
var turn := 0.0 ## how fast it is turning (radians a second), so it banks into its turns
var dive := 1.3 ## how far it drops on its prey

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
var _weights := PackedFloat32Array([1.0, 0.0, 0.0]) # hovering, flying, striking
var _look := 0.0
var _head_y := 0.0
var _next_look := 0.8
var _next_caw := 3.0
var _caw := 0.0
var _roll := 0.0


func _init() -> void:
	name = "Raven"
	_build()
	_apply(_hover_pose())


## Drops on its prey. Starting another while it is still striking starts that one afresh.
func strike() -> void:
	_strike = STRIKE_TIME


func striking() -> bool:
	return _strike > 0.0


func _process(delta: float) -> void:
	advance(delta)


## Moves the crow on by this much time. Called every frame; tests call it directly.
func advance(delta: float) -> void:
	_clock += delta
	_strike = maxf(0.0, _strike - delta)
	var want := PackedFloat32Array([0.0, 0.0, 0.0])
	want[2 if _strike > 0.0 else 1 if moving else 0] = 1.0
	var k := 1.0 - exp(-BLEND * delta)
	for i in 3:
		_weights[i] = lerpf(_weights[i], want[i], k)
	var beats := lerpf(HOVER_BEATS, FLIGHT_BEATS, _weights[1])
	if _strike > 0.0 and _strike < STRIKE_TIME * (1.0 - STRIKE_LOW):
		beats = CLIMB_BEATS
	if moving and _strike <= 0.0:
		_flight = fmod(_flight + delta, FLIGHT_FLAPS / FLIGHT_BEATS + GLIDE_TIME)
	_beat = fmod(_beat + delta * beats, 1.0)
	_tick_head(delta)
	var pose := PackedFloat32Array()
	pose.resize(COUNT)
	var parts := [_hover_pose(), _flight_pose(), _strike_pose()]
	var total := _weights[0] + _weights[1] + _weights[2]
	for which in 3:
		var w := _weights[which] / maxf(total, 0.0001)
		if w < 0.0001:
			continue
		var p: PackedFloat32Array = parts[which]
		for c in COUNT:
			pose[c] += p[c] * w
	_roll = lerpf(_roll, clampf(-turn * 0.16, -0.55, 0.55) * (1.0 - _weights[2]), k)
	_apply(pose)


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
	_flap(p, _beat)
	p[PITCH] = -0.42 # hanging upright in the air
	p[TAIL_X] = -0.2
	p[TAIL_FAN] = 1.5
	p[FEET] = 0.2 + 0.08 * sin(_clock * 2.3)
	p[HEAD_X] = 0.32 + (-0.35 if _caw > 0.0 else 0.0) # holding its head level, or up to caw
	p[JAW] = 0.5 * sin(PI * clampf(_caw / CAW_TIME, 0.0, 1.0))
	return p


func _flight_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(COUNT)
	var beating := FLIGHT_FLAPS / FLIGHT_BEATS
	# A few beats, then it holds its wings out and glides; the beats ease into the glide and out of it.
	var glide := smoothstep(beating - 0.12, beating + 0.06, _flight) * (1.0 - smoothstep(beating + GLIDE_TIME - 0.1, beating + GLIDE_TIME, _flight))
	_flap(p, _beat)
	var still := PackedFloat32Array([0.0, 0.0, 0.14, 0.12, 0.04, 0.06])
	for c in [BODY_Y, PITCH, LIFT, SWEEP, ELBOW_LIFT, ELBOW_SWEEP]:
		if c != PITCH:
			p[c] = lerpf(p[c], still[c], glide)
	p[PITCH] = 0.16 - 0.08 * glide
	p[TAIL_X] = 0.06
	p[TAIL_FAN] = 1.0 + 0.25 * glide
	p[FEET] = 1.35
	p[HEAD_X] = -0.12
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
		p[PITCH] = lerpf(0.95, -0.7, smoothstep(0.0, 0.5, f))
		p[LIFT] = lerpf(0.4, 1.05, smoothstep(0.0, 0.4, f))
		p[SWEEP] = lerpf(0.95, -0.3, smoothstep(0.0, 0.4, f))
		p[ELBOW_SWEEP] = lerpf(1.25, -0.1, smoothstep(0.0, 0.4, f))
		p[TAIL_X] = -0.45
		p[TAIL_FAN] = 1.7
		p[FEET] = -1.1
		p[HEAD_X] = 0.75 * sin(PI * f) # the peck
		p[JAW] = 0.45 * sin(PI * f)
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


## Crows look about in quick turns of the head, not slow sweeps, and caw now and then while they hover.
func _tick_head(delta: float) -> void:
	_next_look -= delta
	if _next_look <= 0.0:
		_next_look = randf_range(0.5, 1.4)
		_look = randf_range(-0.75, 0.75) * (0.3 if moving else 1.0)
	_head_y = lerpf(_head_y, _look, 1.0 - exp(-16.0 * delta))
	_caw = maxf(0.0, _caw - delta)
	_next_caw -= delta
	if _next_caw <= 0.0:
		_next_caw = randf_range(CAW_EVERY.x, CAW_EVERY.y)
		if not moving and _strike <= 0.0:
			_caw = CAW_TIME


func _apply(p: PackedFloat32Array) -> void:
	body.position.y = p[BODY_Y]
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


static func _part(parent: Node3D, mesh: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _pivot(parent: Node3D, called: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = called
	n.position = at
	parent.add_child(n)
	return n


func _build() -> void:
	if _meshes.is_empty():
		_make_meshes()
	body = _pivot(self, "Body", Vector3.ZERO)
	_part(body, _meshes["body"])
	head = _pivot(body, "Head", Vector3(0, 0.06, 0.19))
	_part(head, _meshes["head"])
	jaw = _pivot(head, "Jaw", Vector3(0, 0.012, 0.12))
	_part(jaw, _meshes["jaw"])
	tail = _pivot(body, "Tail", Vector3(0, 0.02, -0.17))
	_part(tail, _meshes["tail"])
	feet = _pivot(body, "Feet", Vector3(0, -0.07, 0.03))
	_part(feet, _meshes["feet"])
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := _pivot(body, "Shoulder" + ("R" if i == 0 else "L"), Vector3(0.065 * side, 0.045, 0.06))
		_part(shoulder, _meshes["arm_r" if i == 0 else "arm_l"])
		var elbow := _pivot(shoulder, "Elbow", Vector3(0.27 * side, 0, 0))
		_part(elbow, _meshes["hand_r" if i == 0 else "hand_l"])
		shoulders.append(shoulder)
		elbows.append(elbow)


static func _make_meshes() -> void:
	var feather := INK.lightened(0.04)
	var b := LowPoly.new()
	b.prism(Vector3(0, 0.0, -0.18), Vector3(0, 0.02, 0.14), 0.07, 0.095, 6, INK) # back and belly
	b.prism(Vector3(0, 0.02, 0.1), Vector3(0, 0.05, 0.22), 0.095, 0.068, 6, INK) # chest into the neck
	b.box(Vector3(0, 0.083, -0.02), Vector3(0.11, 0.018, 0.26), SHEEN) # the gloss along its back
	for x: float in [-0.03, 0.0, 0.03]: # the shaggy hackles at its throat
		b.prism(Vector3(x, 0.0, 0.2), Vector3(x * 1.4, -0.075, 0.17), 0.022, 0.0, 4, INK.lightened(0.06))
	var h := LowPoly.new()
	h.box(Vector3(0, 0.035, 0.05), Vector3(0.125, 0.115, 0.15), INK.lightened(0.05)) # skull
	h.box(Vector3(0, 0.088, 0.035), Vector3(0.1, 0.02, 0.11), SHEEN) # crown
	h.prism(Vector3(0, 0.045, 0.11), Vector3(0, 0.025, 0.27), 0.04, 0.0, 4, BEAK) # upper beak: a crow's heavy bill
	h.box(Vector3(0, 0.06, 0.13), Vector3(0.05, 0.022, 0.04), INK) # the bristles over its nostrils
	for side: float in [-1.0, 1.0]:
		h.box(Vector3(0.063 * side, 0.055, 0.085), Vector3(0.012, 0.028, 0.028), EYE)
		h.box(Vector3(0.066 * side, 0.06, 0.09), Vector3(0.008, 0.009, 0.009), Color(1, 1, 0.9)) # the glint
	var j := LowPoly.new().prism(Vector3(0, -0.012, -0.005), Vector3(0, -0.012, 0.13), 0.025, 0.0, 4, BEAK.darkened(0.2))
	var t := LowPoly.new() # the tail: seven feathers side by side, the middle ones longest
	for i in 7:
		var x := (i - 3) * 0.022
		var length := 0.27 - absf(i - 3) * 0.018
		t.turned_box(Vector3(x * 1.2, 0.0, -length * 0.5), Vector3(0.034, 0.012, length), feather.darkened(0.04 * (i % 2)), Basis(Vector3.UP, -x * 2.4))
	t.box(Vector3(0, 0.012, -0.05), Vector3(0.1, 0.014, 0.1), SHEEN.darkened(0.25)) # coverts over the root of the tail
	var f := LowPoly.new() # legs and feet, hanging down from the pivot under its belly
	var claw := Color(0.16, 0.15, 0.15)
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(0.035 * side, 0, 0)
		var ankle := Vector3(0.04 * side, -0.1, 0.01)
		f.prism(hip, ankle, 0.014, 0.01, 4, claw)
		for toe: Vector3 in [Vector3(0, 0, 0.055), Vector3(0.022 * side, 0, 0.045), Vector3(-0.018 * side, 0, 0.045), Vector3(0, 0, -0.04)]:
			f.prism(ankle, ankle + toe + Vector3(0, -0.012, 0), 0.008, 0.0, 3, claw)
	_meshes["body"] = b.commit()
	_meshes["head"] = h.commit()
	_meshes["jaw"] = j.commit()
	_meshes["tail"] = t.commit()
	_meshes["feet"] = f.commit()
	for side: float in [1.0, -1.0]:
		var suffix := "_r" if side > 0.0 else "_l"
		_meshes["arm" + suffix] = _arm(side)
		_meshes["hand" + suffix] = _hand(side)


## The inner wing, from the shoulder to the elbow: coverts on top, the secondaries trailing behind.
## The left one is the right one in a mirror.
static func _arm(side: float) -> ArrayMesh:
	var a := LowPoly.new()
	a.base = Transform3D(Basis.from_scale(Vector3(side, 1, 1)), Vector3.ZERO)
	a.box(Vector3(0.135, 0.0, -0.01), Vector3(0.27, 0.032, 0.13), INK) # the leading edge and coverts
	a.box(Vector3(0.12, 0.018, 0.0), Vector3(0.22, 0.01, 0.09), SHEEN) # their gloss
	for i in 5: # secondaries
		var x := 0.03 + i * 0.058
		a.turned_box(Vector3(x, -0.006, -0.14), Vector3(0.062, 0.012, 0.17), INK.lightened(0.03 * (i % 2)), Basis(Vector3.UP, 0.06 * (i - 2)))
	return a.commit()


## The outer wing, from the elbow: the hand coverts and five long primaries spread like fingers,
## the crow's mark against the sky.
static func _hand(side: float) -> ArrayMesh:
	var a := LowPoly.new()
	a.base = Transform3D(Basis.from_scale(Vector3(side, 1, 1)), Vector3.ZERO)
	a.box(Vector3(0.07, 0.0, -0.02), Vector3(0.15, 0.026, 0.12), INK)
	a.box(Vector3(0.05, 0.015, -0.0), Vector3(0.1, 0.01, 0.07), SHEEN.darkened(0.15))
	var lengths := [0.31, 0.34, 0.33, 0.29, 0.24]
	for i in 5:
		var root := Vector3(0.12 - i * 0.025, -0.004, -0.02 - i * 0.03)
		var angle := 0.04 + i * 0.2 # sweeping further back, feather by feather
		var dir := Vector3(cos(angle), 0, -sin(angle))
		var length: float = lengths[i]
		a.turned_box(root + dir * length * 0.5, Vector3(length, 0.011, 0.05 - i * 0.003), INK.lightened(0.02 * (i % 2)), Basis(Vector3.UP, angle))
	return a.commit()
