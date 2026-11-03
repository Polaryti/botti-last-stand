class_name Landmarks
extends RefCounted
## The places beyond the village: the castle on its hill, the graveyard, the farm, the mills,
## the hamlets and the lumber camp. Each is worth the walk, because each has loot.

const STONE := Color(0.43, 0.43, 0.45)
const STONE_DARK := Color(0.32, 0.32, 0.35)

var v: Village
var w: World


func _init(village: Village) -> void:
	v = village
	w = village.w


func build() -> void:
	_castle()
	_graveyard()
	_windmill()
	_water_mill()
	_farm()
	_orchard()
	_hamlets()
	_lumber_camp()
	_watchtower()
	_fires()
	_name_places()


## Fires along the way, at the places people would have gathered.
func _fires() -> void:
	for at: Vector3 in [Vector3(-60, 0, -40 + 18), Vector3(-5, 0, 28), Vector3(92, 0, 5), Vector3(4, 0, 83), Vector3(76, 0, -56),
			Vector3(-47, 0, 50), Vector3(-84, 0, 58), Vector3(-68, 0, 22), Vector3(84, 0, 42), Vector3(-30, 0, -28), Vector3(40, 0, -60)]:
		v.bonfire(at)
	var c := Terrain.CASTLE.get_center()
	v.bonfire(Vector3(c.x + 9, 0, c.y + 8))
	for at: Vector3 in [Vector3(-3.6, 0, 52), Vector3(3.6, 0, 52), Vector3(-3.6, 0, 76), Vector3(3.6, 0, 76), Vector3(60.5, 0, -3.6), Vector3(60.5, 0, 3.6), Vector3(84.5, 0, -3.6), Vector3(84.5, 0, 3.6),
			Vector3(-46, 0, -74.5), Vector3(-46, 0, -65.5), Vector3(-34, 0, -60), Vector3(-26, 0, -52), Vector3(-3.4, 0, -36), Vector3(3.4, 0, -36), Vector3(49, 0, -66), Vector3(40, 0, -66),
			Vector3(c.x - 2, 0, c.y + 6), Vector3(58, 0, -79), Vector3(21, 0, 72.5), Vector3(-3, 0, 96), Vector3(-53, 0, 76), Vector3(-53, 0, 53)]:
		v.torch(at)


func _name_places() -> void:
	var c := Terrain.CASTLE.get_center()
	for mark: Array in [["Castle", c], ["Village", Vector2(0, 0)], ["Church", Vector2(0, -48)], ["Graveyard", Vector2(49, -82)], ["Lumber camp", Vector2(80, -62)],
			["Hamlet", Vector2(-66, 0)], ["Orchard", Vector2(-90, 8)], ["Watch post", Vector2(-92, 60)], ["Hamlet", Vector2(93, 5)], ["Windmill", Vector2(94, 42)],
			["Mill", Vector2(28, 80)], ["Farm", Vector2(0, 92)], ["Ford", Vector2(-54, 64)]]:
		w.map_marks.append({"name": mark[0], "at": mark[1]})


func _no_fog() -> StandardMaterial3D:
	var clear := LowPoly.material().duplicate() as StandardMaterial3D
	clear.disable_fog = true
	return clear


# --- The castle --------------------------------------------------------------

func _castle() -> void:
	var r := Terrain.CASTLE
	var c := r.get_center()
	var half := r.size.x * 0.5 - 2.0
	var x0 := c.x - half
	var x1 := c.x + half
	var z0 := c.y - half
	var z1 := c.y + half
	const H := 5.6
	v._y = Terrain.CASTLE_Y
	var l := LowPoly.new()
	var gate := {"at": 0.0, "width": 5.0, "sill": 0.0, "top": 4.1, "bare": true}
	var breach_s := {"at": 8.0, "width": 4.2, "sill": 0.0, "top": H, "bare": true}
	var breach_w := {"at": -9.0, "width": 3.6, "sill": 1.2, "top": H, "bare": true}
	var breach_n := {"at": 12.0, "width": 5.0, "sill": 2.2, "top": H, "bare": true}
	var slit := func(at: float) -> Dictionary: return {"at": at, "width": 0.5, "sill": 1.6, "top": 3.0, "bare": true}
	v._wall(l, Vector2(x0, z0), Vector2(x1, z0), H, [breach_n, slit.call(-10.0), slit.call(-2.0)], STONE, false)
	v._wall(l, Vector2(x0, z1), Vector2(x1, z1), H, [breach_s, slit.call(-12.0), slit.call(-4.0)], STONE, false)
	v._wall(l, Vector2(x0, z0), Vector2(x0, z1), H, [breach_w, slit.call(4.0), slit.call(12.0)], STONE, false)
	v._wall(l, Vector2(x1, z0), Vector2(x1, z1), H, [gate], STONE, false)
	_merlons(l, Vector2(x0, z0), Vector2(x1, z0), H, [breach_n])
	_merlons(l, Vector2(x0, z1), Vector2(x1, z1), H, [breach_s])
	_merlons(l, Vector2(x0, z0), Vector2(x0, z1), H, [breach_w])
	_merlons(l, Vector2(x1, z0), Vector2(x1, z1), H, [])
	# Fallen stones in the breaches. They hide nothing but they look the part.
	for at: Vector3 in [Vector3(c.x + 8, 0, z1 + 1.2), Vector3(c.x + 7, 0, z1 - 1.0), Vector3(x0 - 1.2, 0, c.y - 9), Vector3(x0 + 1.2, 0, c.y - 8), Vector3(c.x + 12, 0, z0 + 1.5)]:
		for i in 4:
			var s := v.rng.randf_range(0.4, 1.0)
			l.box(at + Vector3(v.rng.randf_range(-1.6, 1.6), s * 0.3, v.rng.randf_range(-1.6, 1.6)), Vector3(s, s * 0.7, s * 0.9), STONE_DARK.lightened(v.rng.randf() * 0.15), Vector3(0, v.rng.randf() * 90.0, v.rng.randf() * 18.0))
	# Gate towers and the portcullis, half raised.
	for dz: float in [-4.2, 4.2]:
		_round_tower(l, Vector3(x1, 0, c.y + dz), 2.0, H + 2.4)
	for i in 6:
		l.box(Vector3(x1, 3.6, c.y - 2.0 + i * 0.8), Vector3(0.1, 1.1, 0.1), Color(0.14, 0.14, 0.16))
	l.box(Vector3(x1, 3.1, c.y), Vector3(0.12, 0.1, 4.8), Color(0.14, 0.14, 0.16))
	var mesh := v._add(l)
	mesh.material_override = _no_fog()
	# Corner towers stand clear of the fog: you can find the castle from anywhere.
	var towers := LowPoly.new()
	for corner: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		_round_tower(towers, Vector3(corner.x, 0, corner.y), 3.2, H + 4.0)
		v.solid(Vector3(corner.x, (H + 4.0) * 0.5, corner.y), Vector3(5.2, H + 4.0, 5.2))
		w.perches.append(Vector3(corner.x, Terrain.CASTLE_Y + H + 4.6, corner.y))
	v._add(towers).material_override = _no_fog()
	for dz: float in [-4.2, 4.2]:
		v.solid(Vector3(x1, (H + 2.4) * 0.5, c.y + dz), Vector3(3.2, H + 2.4, 3.2))
	v._y = 0.0
	# The keep, with a roof to hide under.
	var keep_at := Vector3(c.x - 6, 0, c.y - 6)
	var keep_style := {"plaster": STONE.lightened(0.04), "roof": Color(0.22, 0.2, 0.24), "beams": false}
	v._house(keep_at, 16, 14, 6.5, "x", keep_style, {"e": [v.door(0, 3.0, 3.6)], "s": [{"at": -4.0, "width": 0.8, "sill": 2.2, "top": 4.4}, {"at": 4.0, "width": 0.8, "sill": 2.2, "top": 4.4}],
		"n": [{"at": 0.0, "width": 0.8, "sill": 2.2, "top": 4.4}], "w": [{"at": 2.0, "width": 2.2, "sill": 0.0, "top": 2.5}]})
	v._loot(keep_at + Vector3(-4, 0, -3))
	v._loot(keep_at + Vector3(3, 0, -4))
	v._loot(keep_at + Vector3(-5, 0, 4))
	v._table(keep_at + Vector3(-1, 0, 2))
	v._table(keep_at + Vector3(3, 0, 3))
	v._prop_at("props/weaponrack", keep_at + Vector3(6.4, 0, -5.4), 5.0, 0.0, Vector3(1.0, 1.2, 0.7))
	v._prop_at("props/barrel", keep_at + Vector3(-6.8, 0, 5.8), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	# The courtyard.
	v._loot(Vector3(c.x + 12, 0, c.y + 13))
	v._loot(Vector3(c.x - 14, 0, c.y + 14))
	v._loot(Vector3(c.x + 14, 0, c.y - 14))
	v._hay_bale(Vector3(c.x + 14, 0, c.y + 16), Vector3(2.0, 1.0, 1.4))
	v._hay_bale(Vector3(c.x + 16.2, 0, c.y + 16), Vector3(2.0, 1.0, 1.4))
	v._hay_bale(Vector3(c.x + 15, 1.0, c.y + 16), Vector3(2.0, 1.0, 1.4))
	v._prop_at("props/target", Vector3(c.x + 5, 0, c.y + 15), 5.0, 0.0, Vector3(1.2, 1.5, 0.5))
	v._prop_at("props/target", Vector3(c.x - 1, 0, c.y + 15), 5.0, 0.0, Vector3(1.2, 1.5, 0.5))
	v._prop_at("props/crate_A_big", Vector3(c.x + 16, 0, c.y - 16), 4.0, 0.3, Vector3(0.9, 0.85, 0.9))
	v._prop_at("props/crate_B_small", Vector3(c.x + 15, 0, c.y - 15), 4.0, 0.9, Vector3(0.6, 0.6, 0.6))
	v._lantern(Vector3(c.x + 18, 0, c.y - 5))
	v._lantern(Vector3(c.x + 18, 0, c.y + 5))
	w.pois.append(Vector3(c.x + 10, Terrain.CASTLE_Y, c.y + 6))
	w.pois.append(Vector3(c.x - 12, Terrain.CASTLE_Y, c.y + 10))


func _merlons(l: LowPoly, a: Vector2, b: Vector2, h: float, gaps: Array) -> void:
	var along_x := absf(a.x - b.x) > absf(a.y - b.y)
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	var s := -length * 0.5 + 1.0
	while s < length * 0.5:
		var clear := true
		for g: Dictionary in gaps:
			if absf(s - float(g["at"])) < float(g["width"]) * 0.5 + 0.5:
				clear = false
		if clear:
			var p := Vector3(mid.x + (s if along_x else 0.0), h + 0.34, mid.y + (0.0 if along_x else s))
			l.box(p, Vector3(1.0, 0.68, 0.42) if along_x else Vector3(0.42, 0.68, 1.0), STONE_DARK.lightened(0.05))
		s += 2.0


func _round_tower(l: LowPoly, at: Vector3, radius: float, h: float) -> void:
	l.prism(at, at + Vector3.UP * h, radius, radius * 0.92, 8, STONE.darkened(0.04))
	l.prism(at + Vector3.UP * h, at + Vector3.UP * (h + 0.5), radius * 1.14, radius * 1.14, 8, STONE_DARK)
	for i in 8:
		var a := TAU * i / 8.0
		l.box(at + Vector3(cos(a) * radius, h + 0.85, sin(a) * radius), Vector3(0.72, 0.7, 0.72), STONE_DARK.lightened(0.04))


# --- The graveyard -----------------------------------------------------------

func _graveyard() -> void:
	var r := Rect2(34, -94, 30, 26)
	v._y = w.terrain.height(r.get_center().x, r.get_center().y)
	var y := v._y
	var iron := LowPoly.new()
	v._fence(iron, Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), [])
	v._fence(iron, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), [Vector2(42, 47)])
	v._fence(iron, Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), [Vector2(-82, -78)])
	v._fence(iron, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), [])
	v._add(iron)
	var l := LowPoly.new()
	for row in 4:
		for col in 7:
			var x := r.position.x + 3.0 + col * 3.9 + v._land.randf_range(-0.3, 0.3)
			var z := r.position.y + 3.5 + row * 5.2 + v._land.randf_range(-0.3, 0.3)
			if x > 49.0 and z < -81.0 and x < 60.0:
				continue # the crypt stands here
			if v._land.randf() < 0.14:
				continue
			_grave(l, Vector3(x, 0, z), v._land.randf_range(-16.0, 16.0), v._land.randi_range(0, 2))
	v._add(l)
	v._y = 0.0
	var crypt_at := Vector3(55, 0, -86)
	v._house(crypt_at, 9, 10, 3.6, "z", {"plaster": STONE.darkened(0.08), "roof": STONE_DARK, "beams": false}, {"s": [v.door(0, 2.4, 2.8)]})
	v._loot(crypt_at + Vector3(0, 0, -3))
	v._loot(crypt_at + Vector3(-2.6, 0, 1))
	var inside := LowPoly.new()
	var f := w.terrain.height(crypt_at.x, crypt_at.z)
	for dx: float in [-2.8, 2.8]:
		inside.box(Vector3(crypt_at.x + dx, f + 0.45, crypt_at.z - 2.2), Vector3(1.3, 0.9, 2.4), STONE.lightened(0.08))
		w.add_solid(Vector3(crypt_at.x + dx, f + 0.45, crypt_at.z - 2.2), Vector3(1.3, 0.9, 2.4))
	v._add(inside)
	for at: Vector3 in [Vector3(38, 0, -72), Vector3(60, 0, -72), Vector3(38, 0, -90)]:
		_dead_tree(at)
	w.add_glow(Vector3(crypt_at.x, f + 3.2, crypt_at.z + 5.6), Color(0.45, 0.9, 0.55), 1.8)
	w.pois.append(Vector3(45, y, -74))
	v._loot(Vector3(40, 0, -74))


func _grave(l: LowPoly, at: Vector3, tilt: float, kind: int) -> void:
	var col := Color(0.47, 0.47, 0.48).lightened(v._land.randf() * 0.1)
	match kind:
		0:
			l.box(at + Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.16), col, Vector3(tilt * 0.6, 0, tilt * 0.25))
			l.box(at + Vector3(0, 1.0, 0), Vector3(0.5, 0.14, 0.14), col)
		1:
			l.box(at + Vector3(0, 0.65, 0), Vector3(0.15, 1.3, 0.15), col, Vector3(tilt * 0.5, 0, tilt))
			l.box(at + Vector3(0, 0.95, 0), Vector3(0.72, 0.15, 0.15), col, Vector3(tilt * 0.5, 0, tilt))
		2:
			l.box(at + Vector3(0, 0.42, 0), Vector3(0.9, 0.85, 0.2), col.darkened(0.1), Vector3(tilt, 0, 0))
	l.box(at + Vector3(0, 0.08, 1.15), Vector3(0.95, 0.16, 1.9), Color(0.2, 0.15, 0.1))
	v.solid(at + Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.3))


func _dead_tree(at: Vector3) -> void:
	at = v.on_ground(at)
	var l := LowPoly.new()
	var bark := Color(0.14, 0.12, 0.11)
	l.prism(at, at + Vector3(0.2, 3.0, 0.1), 0.26, 0.1, 5, bark)
	for b: Array in [[Vector3(0.2, 2.0, 0.1), Vector3(1.4, 3.2, 0.3)], [Vector3(0.2, 2.5, 0.1), Vector3(-0.9, 3.7, -0.5)], [Vector3(0.2, 3.0, 0.1), Vector3(0.7, 4.3, 0.8)], [Vector3(0.1, 1.6, 0.0), Vector3(-1.1, 2.2, 0.8)]]:
		l.prism(at + (b[0] as Vector3), at + (b[1] as Vector3), 0.08, 0.02, 4, bark)
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	w.add_child(mi)
	w.add_solid(at + Vector3.UP, Vector3(0.6, 2.0, 0.6))


# --- Mills -------------------------------------------------------------------

## The windmill turns on its hill, and it stands clear of the fog as a landmark.
func _windmill() -> void:
	var at := Vector3(94, 0, 42)
	v._y = w.terrain.height(at.x, at.z)
	var l := LowPoly.new()
	l.prism(at, at + Vector3.UP * 8.5, 3.5, 2.2, 10, Color(0.56, 0.52, 0.44))
	l.prism(at + Vector3.UP * 8.5, at + Vector3.UP * 10.8, 2.5, 0.2, 10, Color(0.26, 0.2, 0.17))
	l.box(at + Vector3(0, 1.2, 3.4), Vector3(1.4, 2.4, 0.3), Color(0.2, 0.13, 0.08))
	l.box(at + Vector3(0, 4.5, 2.95), Vector3(0.7, 1.0, 0.2), Color(1.0, 0.76, 0.34))
	v._add(l).material_override = _no_fog()
	v.solid(at + Vector3.UP * 4.0, Vector3(5.6, 8.0, 5.6))
	var sails := LowPoly.new()
	sails.prism(Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), 0.2, 0.2, 6, Color(0.2, 0.14, 0.1))
	for i in 4:
		var turn := Basis(Vector3.BACK, TAU * i / 4.0)
		sails.box(turn * Vector3(0, 3.1, 0.3), Vector3(0.16, 6.2, 0.1), Color(0.3, 0.21, 0.13), Vector3(0, 0, -rad_to_deg(TAU * i / 4.0)))
		sails.box(turn * Vector3(0.48, 3.6, 0.3), Vector3(0.8, 4.8, 0.04), Color(0.72, 0.68, 0.58), Vector3(0, 0, -rad_to_deg(TAU * i / 4.0)))
	var node := MeshInstance3D.new()
	node.mesh = sails.commit()
	node.material_override = _no_fog()
	node.position = at + Vector3(0, v._y + 8.0, 3.2)
	w.add_child(node)
	w.add_spinner(node, Vector3.BACK, 0.55)
	v._y = 0.0
	v._hay_bale(at + Vector3(4.8, 0, 2.5), Vector3(2.0, 1.0, 1.4))
	v._prop_at("props/sack", at + Vector3(2.2, 0, 4.4), 5.0, 0.4, Vector3.ZERO)
	v._prop_at("props/sack", at + Vector3(3.0, 0, 4.1), 5.0, 1.4, Vector3.ZERO)
	v._loot(at + Vector3(-4.6, 0, 3.0))
	w.pois.append(at + Vector3(0, v._y, 6))


## A water mill on the far bank, with its wheel in the river.
func _water_mill() -> void:
	var at := Vector3(28, 0, 80.5)
	var m := v._house(at, 12, 9, 3.4, "x", {"plaster": Village.PLASTER_B, "roof": Village.SHINGLE}, {"s": [v.door(-2)], "w": [v.window(0)], "e": [v.door(0)], "n": [v.window(-3), v.window(3)]})
	v._table(m + Vector3(3, 0, 2))
	v._loot(m + Vector3(-3.5, 0, -2))
	v._loot(m + Vector3(3.5, 0, -2.5))
	v._prop_at("props/sack", m + Vector3(-1, 0, 2.5), 5.0, 0.4, Vector3.ZERO)
	v._prop_at("props/barrel", m + Vector3(4.8, 0, 3.2), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	var y := w.terrain.height(at.x, at.z)
	var frame := LowPoly.new()
	# The race that carries water down to the wheel.
	for x: float in [at.x - 1.6, at.x + 1.6]:
		frame.box(Vector3(x, y - 0.6, 73.6), Vector3(0.3, 4.4, 0.3), Village.BEAM)
	frame.box(Vector3(at.x, y + 1.5, 73.6), Vector3(3.8, 0.24, 0.3), Village.BEAM)
	frame.box(Vector3(at.x, y + 1.5, 74.8), Vector3(0.3, 0.24, 2.6), Village.BEAM)
	var solid_frame := MeshInstance3D.new()
	solid_frame.mesh = frame.commit()
	w.add_child(solid_frame)
	var wheel := LowPoly.new()
	for i in 10:
		var a := TAU * i / 10.0
		var q := Vector3(0, cos(a) * 2.4, sin(a) * 2.4)
		wheel.box(q, Vector3(1.1, 0.14, 0.72), Village.PLANK.lightened(0.1), Vector3(rad_to_deg(a), 0, 0))
		wheel.box(q * 0.5, Vector3(0.14, 2.4, 0.14), Village.BEAM, Vector3(rad_to_deg(a), 0, 0))
	wheel.prism(Vector3(-0.8, 0, 0), Vector3(0.8, 0, 0), 0.2, 0.2, 6, Village.BEAM)
	var node := MeshInstance3D.new()
	node.mesh = wheel.commit()
	node.position = Vector3(at.x, y - 0.6, 72.6)
	w.add_child(node)
	w.add_spinner(node, Vector3.RIGHT, 0.7)
	w.pois.append(at + Vector3(0, y, 7))


# --- The farm and the orchard ------------------------------------------------

func _farm() -> void:
	var house := v._house(Vector3(-13, 0, 86), 10, 8, 3.0, "x", {"plaster": Village.PLASTER, "roof": Village.THATCH}, {"e": [v.door(0)], "n": [v.door(0)], "s": [v.window(-2), v.window(2)], "w": [v.window(0)]})
	v._table(house + Vector3(-2.5, 0, 1.8))
	v._bed(house + Vector3(3.2, 0, -2.0))
	v._loot(house + Vector3(-3.2, 0, -2.0))
	var barn := v._house(Vector3(14, 0, 95), 16, 10, 4.4, "x", {"plaster": Village.PLANK, "roof": Village.SHINGLE}, {"n": [v.door(0, 4.0, 3.5)], "s": [v.door(3, 2.2, 2.6)], "w": [v.window(0)], "e": [v.window(0)]})
	for at: Vector3 in [Vector3(-6, 0, -3), Vector3(-6, 0, -0.8), Vector3(6, 0, 3), Vector3(6, 0, 0.8)]:
		v._hay_bale(barn + at, Vector3(2.0, 1.0, 1.4))
	v._hay_bale(barn + Vector3(-6, 1.0, -2), Vector3(2.0, 1.0, 1.4))
	v._loot(barn + Vector3(0, 0, 1))
	v._loot(barn + Vector3(-3, 0, -3))
	# A well, a cart, and sheaves in the yard.
	var l := LowPoly.new()
	var well := v.on_ground(Vector3(0, 0, 90))
	l.prism(well, well + Vector3.UP * 0.9, 0.9, 0.9, 8, Landmarks.STONE)
	l.prism(well + Vector3.UP * 0.9, well + Vector3.UP * 0.95, 0.62, 0.62, 8, Color(0.04, 0.06, 0.09))
	w.add_solid(well + Vector3.UP * 0.5, Vector3(1.8, 1.0, 1.8))
	_cart(l, v.on_ground(Vector3(-6, 0, 96)))
	w.add_solid(v.on_ground(Vector3(-6, 0, 96)) + Vector3.UP * 0.6, Vector3(1.7, 1.2, 3.1))
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	w.add_child(mi)
	v.field(Rect2(-50, 79, 26, 21), "corn", {"e": [Vector2(86, 92)], "n": [Vector2(-44, -38)]})
	v.field(Rect2(-16, 97, 16, 8), "garden", {"n": [Vector2(-10, -6)]})
	v.field(Rect2(30, 92, 22, 12), "wheat", {"w": [Vector2(96, 100)], "n": [Vector2(38, 44)]})
	v._scarecrow(Vector3(-37, 0, 90))
	v._scarecrow(Vector3(42, 0, 98))
	v._hay_bale(Vector3(-20, 0, 92), Vector3(2.0, 1.0, 1.4))
	w.pois.append(Vector3(-2, 1, 88))
	v._loot(Vector3(4, 0, 90))


func _cart(l: LowPoly, at: Vector3) -> void:
	var wood := Color(0.42, 0.28, 0.16)
	l.box(at + Vector3(0, 0.85, 0), Vector3(1.5, 0.12, 2.8), wood)
	for dx: float in [-0.72, 0.72]:
		l.box(at + Vector3(dx, 1.12, 0), Vector3(0.08, 0.5, 2.8), wood.darkened(0.1))
		l.prism(at + Vector3(dx * 1.1, 0.5, 0.8), at + Vector3(dx * 1.22, 0.5, 0.8), 0.5, 0.5, 8, Village.BEAM)
		l.prism(at + Vector3(dx * 1.1, 0.5, -0.8), at + Vector3(dx * 1.22, 0.5, -0.8), 0.5, 0.5, 8, Village.BEAM)
	l.box(at + Vector3(0, 1.1, 0.2), Vector3(1.2, 0.5, 1.6), Village.HAY)


## Rows of apple trees on a terrace, with vines on the slope below.
func _orchard() -> void:
	var r := Rect2(-104, -5, 28, 26)
	var trees: Array[Transform3D] = []
	var tints := PackedColorArray()
	var fallen := LowPoly.new()
	var x := r.position.x + 2.5
	while x < r.end.x - 1.0:
		var z := r.position.y + 2.5
		while z < r.end.y - 1.0:
			var at := v.on_ground(Vector3(x + v._land.randf_range(-0.4, 0.4), 0, z + v._land.randf_range(-0.4, 0.4)))
			var s := v._land.randf_range(0.9, 1.2)
			trees.append(Transform3D(Basis(Vector3.UP, v._land.randf() * TAU).scaled(Vector3(s, s, s)), at))
			tints.append(Color(v._land.randf_range(0.9, 1.08), v._land.randf_range(0.9, 1.08), v._land.randf_range(0.9, 1.0)))
			w.add_solid(at + Vector3.UP, Vector3(0.5, 2.0, 0.5))
			for i in 3:
				var a := v._land.randf() * TAU
				var p := at + Vector3(cos(a) * v._land.randf_range(0.5, 1.6), 0.06, sin(a) * v._land.randf_range(0.5, 1.6))
				fallen.box(p, Vector3.ONE * 0.11, Color(0.72, 0.14, 0.1))
			z += 5.0
		x += 5.0
	var node := Crops.plant(Crops.apple_tree(), trees, tints, true)
	node.visibility_range_end = 90.0
	w.add_child(node)
	var apples := MeshInstance3D.new()
	apples.mesh = fallen.commit()
	apples.visibility_range_end = 40.0
	apples.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(apples)
	v._loot(Vector3(r.get_center().x + 2.5, 0, r.get_center().y + 2.5))
	v._loot(Vector3(r.position.x + 5, 0, r.position.y + 15))
	v._prop_at("props/crate_long_A", Vector3(r.end.x + 2, 0, r.position.y + 12), 3.6, 0.5, Vector3(1.5, 0.6, 1.5))
	v._prop_at("props/barrel", Vector3(r.end.x + 3.5, 0, r.position.y + 10), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	w.pois.append(Vector3(r.get_center().x, 3.4, r.get_center().y))
	# Vines in rows on the terrace's near side.
	var vines: Array[Transform3D] = []
	var vine_tints := PackedColorArray()
	var vx := -70.0
	while vx < -60.0:
		var vz := 24.0
		while vz < 40.0:
			var at := v.on_ground(Vector3(vx, 0, vz))
			vines.append(Transform3D(Basis.IDENTITY, at))
			vine_tints.append(Color(1, 1, 1) * v._land.randf_range(0.85, 1.1))
			vz += 2.0
		vx += 2.6
	var vine_node := Crops.plant(Crops.vine(), vines, vine_tints, true)
	vine_node.visibility_range_end = 60.0
	w.add_child(vine_node)


# --- Hamlets and the rest ----------------------------------------------------

func _hamlets() -> void:
	var a := {"plaster": Village.PLASTER, "roof": Village.THATCH}
	var b := {"plaster": Village.PLASTER_B, "roof": Village.SHINGLE}
	var h1 := v._house(Vector3(-64.5, 0, -14), 9, 8, 3.0, "x", a, {"s": [v.door(1)], "e": [v.window(0)], "w": [v.window(0)]})
	v._table(h1 + Vector3(-2, 0, -2))
	v._loot(h1 + Vector3(3, 0, -2))
	var h2 := v._house(Vector3(-66.5, 0, 14), 9, 8, 3.0, "x", b, {"n": [v.door(0)], "s": [v.window(0)], "e": [v.window(1)]})
	v._bed(h2 + Vector3(3, 0, 1.5))
	v._loot(h2 + Vector3(-3, 0, 1.5))
	var h3 := v._house(Vector3(88.5, 0, -3.5), 10, 8, 3.0, "x", b, {"s": [v.door(-2)], "n": [v.window(0)], "w": [v.door(0)]})
	v._table(h3 + Vector3(2.5, 0, -2))
	v._loot(h3 + Vector3(-3, 0, -2))
	var h4 := v._house(Vector3(98.5, 0, 14.5), 9, 8, 3.0, "z", a, {"n": [v.door(0)], "w": [v.window(0)], "e": [v.window(0)]})
	v._bed(h4 + Vector3(-2.5, 0, 2))
	v._loot(h4 + Vector3(2.5, 0, 2))
	w.pois.append(Vector3(-62, 1, 0))
	w.pois.append(Vector3(90, 1, 4))
	v._lantern(Vector3(-60, 0, -3.5))
	v._lantern(Vector3(86, 0, 3))


func _lumber_camp() -> void:
	var at := Vector3(80, 0, -63)
	var cabin := v._house(at + Vector3(5, 0, -2), 7, 6, 2.7, "x", {"plaster": Village.PLANK.lightened(0.15), "roof": Village.SHINGLE, "beams": false}, {"w": [v.door(0, 2.0, 2.3)]})
	v._loot(cabin + Vector3(1.8, 0, 1))
	var l := LowPoly.new()
	for pile: Vector3 in [Vector3(-4, 0, 2), Vector3(-3.5, 0, -3)]:
		var base := v.on_ground(at + pile)
		for row in 3:
			for i in 3 - row:
				var off := Vector3(0, 0.27 + row * 0.46, (i - (2 - row) * 0.5) * 0.52)
				l.prism(base + off + Vector3(-1.9, 0, 0), base + off + Vector3(1.9, 0, 0), 0.25, 0.25, 6, Color(0.36, 0.25, 0.15).lightened(0.05 * i))
		w.add_solid(base + Vector3.UP * 0.7, Vector3(3.8, 1.4, 1.6))
	for stump: Vector3 in [Vector3(0, 0, 4), Vector3(2, 0, 5), Vector3(-1, 0, 6), Vector3(3, 0, 3)]:
		var base := v.on_ground(at + stump)
		l.prism(base, base + Vector3.UP * 0.55, 0.42, 0.36, 7, Color(0.3, 0.21, 0.13))
		l.prism(base + Vector3.UP * 0.55, base + Vector3.UP * 0.58, 0.36, 0.36, 7, Color(0.58, 0.44, 0.27))
		w.add_solid(base + Vector3.UP * 0.3, Vector3(0.7, 0.6, 0.7))
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	w.add_child(mi)
	v._loot(at + Vector3(0, 0, 1))
	w.pois.append(at)


## An old watch post on the western hill.
func _watchtower() -> void:
	var at := Vector3(-92.5, 0, 60.5)
	var t := v._house(at, 7, 7, 6.5, "x", {"plaster": STONE.darkened(0.04), "roof": Color(0.2, 0.18, 0.2), "beams": false}, {"e": [v.door(0, 2.0, 2.5)], "s": [{"at": 0.0, "width": 0.7, "sill": 3.0, "top": 4.4}], "n": [{"at": 0.0, "width": 0.7, "sill": 3.0, "top": 4.4}]})
	v._loot(t + Vector3(-1.8, 0, 1.8))
	v._loot(t + Vector3(-1.8, 0, -1.8))
	w.pois.append(at + Vector3(6, 5, 0))
