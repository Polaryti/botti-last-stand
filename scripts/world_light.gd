class_name WorldLight
## Numbers and shapes for firelight, and for the Revenant's arts. Everything that is a plain constant
## about these lives here, so both can be tuned from one place.

const SEEN_IN_LIGHT := 1.5 # zombies see you this much further when you stand in firelight
const BONFIRE_REACH := 6.5
const TORCH_REACH := 3.5
const LANTERN_REACH := 4.0
const WARMTH := 1.5 # health per second, close to a bonfire

const BURST_FREEZE := 2.0
const LEAP_CLIMB := 4.0 # as high above where you stand as a leap can land
const RIFT_REACH := 16.0
const ARTS := {
	"leaper": {"name": "Mist Leap", "cost": 18.0, "cast": 0.12, "cd": 2.5, "icon": "leap"},
	"rift": {"name": "Rift Jump", "cost": 30.0, "cast": 0.3, "cd": 6.0, "icon": "rift"},
	"summoner": {"name": "Call Revenant", "cost": 50.0, "cast": 0.7, "cd": 18.0, "icon": "ghost"},
	"guardian": {"name": "Shield Dome", "cost": 0.0, "cast": 0.15, "cd": 24.0, "icon": "shield_rect"},
}

static var _flame: Mesh


## Three leaning tongues of fire. The flicker happens in the shader, so it costs almost nothing.
static func flame_mesh() -> Mesh:
	if _flame:
		return _flame
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Array in [[Vector3.ZERO, 0.52, 1.75, Color(1.0, 0.42, 0.08), Color(1.0, 0.72, 0.18)],
			[Vector3(0.28, 0, 0.12), 0.34, 1.1, Color(1.0, 0.36, 0.06), Color(1.0, 0.66, 0.15)],
			[Vector3(-0.24, 0, -0.16), 0.36, 1.25, Color(1.0, 0.38, 0.06), Color(1.0, 0.68, 0.15)],
			[Vector3(0.0, 0, 0.0), 0.28, 1.0, Color(1.0, 0.82, 0.3), Color(1.0, 0.96, 0.62)]]:
		var at: Vector3 = t[0]
		var r: float = t[1]
		var h: float = t[2]
		for i in 5:
			var a0 := TAU * i / 5.0
			var a1 := TAU * (i + 1) / 5.0
			st.set_color(t[3])
			st.add_vertex(at + Vector3(cos(a0) * r, 0, sin(a0) * r))
			st.set_color(t[3])
			st.add_vertex(at + Vector3(cos(a1) * r, 0, sin(a1) * r))
			st.set_color(t[4])
			st.add_vertex(at + Vector3.UP * h)
	_flame = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/flame.gdshader")
	_flame.surface_set_material(0, m)
	return _flame
