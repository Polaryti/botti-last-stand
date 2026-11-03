class_name FortMap
extends RefCounted
## The map of Defend the Fort: a walled castle in the middle of a wood. Stairs lead up to the walls,
## four wooden gates face the four sides, and small doors in the walls let only players through.

const STONE := Color(0.43, 0.43, 0.45)
const STONE_DARK := Color(0.32, 0.32, 0.35)
const PLANK := Color(0.42, 0.28, 0.16)
const ROADS: Array = [[Vector2(0, -28), Vector2(0, -105)], [Vector2(28, 0), Vector2(105, 0)], [Vector2(0, 28), Vector2(0, 105)], [Vector2(-28, 0), Vector2(-105, 0)]]
const COPSES: Array[Vector3] = [Vector3(50, 0, 40), Vector3(-48, 0, 44), Vector3(46, 0, -50), Vector3(-52, 0, -42), Vector3(78, 0, 22), Vector3(-80, 0, 24), Vector3(24, 0, 78), Vector3(-24, 0, 80),
	Vector3(26, 0, -78), Vector3(-26, 0, -80), Vector3(84, 0, -28), Vector3(-84, 0, -30), Vector3(90, 0, 70), Vector3(-90, 0, 72), Vector3(88, 0, -78), Vector3(-92, 0, -76), Vector3(62, 0, 88), Vector3(-60, 0, -90)]

var v: Village
var w: World
var fort: Fort


static func plan_land(t: Terrain) -> void:
	t.use_river = false
	t.hill(70, 60, 6.0, 20)
	t.hill(-72, 66, 5.0, 18)
	t.hill(76, -64, 5.5, 20)
	t.hill(-70, -70, 6.5, 22)
	t.hill(0, -100, 4.0, 15)
	t.hill(104, 0, 4.0, 14)
	t.hill(0, 104, 4.0, 15)
	t.hill(-104, 0, 3.5, 15)
	t.pad(Rect2(-34, -34, 68, 68), 0.0, 10.0)
	t.bake()


func _init(village: Village) -> void:
	v = village
	w = village.w


func build() -> void:
	fort = Fort.new(w)
	w.fort = fort
	w.add_child(fort)
	w.church_door = Vector3(0, 0, 8)
	_walls()
	_stairs()
	_keep()
	_yard()
	_outside()
	for mark: Array in [["Keep", Vector2(0, 0)], ["North gate", Vector2(0, -32)], ["East gate", Vector2(40, 0)], ["South gate", Vector2(0, 32)], ["West gate", Vector2(-40, 0)]]:
		w.map_marks.append({"name": mark[0], "at": mark[1]})


func _no_fog() -> StandardMaterial3D:
	var clear := LowPoly.material().duplicate() as StandardMaterial3D
	clear.disable_fog = true
	return clear


func _walls() -> void:
	var h := Fort.HALF
	var l := LowPoly.new()
	# Each side: from a corner to the gate, over the gate, on to the other corner, with one small door.
	var doors := {0: 15.0, 1: 15.0, 2: -15.0, 3: -15.0}
	for side in 4:
		_wall_side(l, side, doors[side])
	for c: Vector2 in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		_tower(l, Vector3(c.x, 0, c.y))
	var walls := v._add(l)
	walls.material_override = _no_fog()
	for i in 4:
		_gate(i)


func _point(side: int, along: float, out: float) -> Vector3:
	var dir := Fort.DIRS[side]
	var across := Vector3(dir.z, 0, -dir.x)
	return dir * out + across * along


func _box_size(side: int, along: float, y: float, out: float) -> Vector3:
	return Vector3(along, y, out) if absf(Fort.DIRS[side].z) > 0.5 else Vector3(out, y, along)


func _wall_side(l: LowPoly, side: int, door_at: float) -> void:
	var h := Fort.HALF
	var t := Fort.WALL_T
	var top := Fort.WALL_H
	var gaps: Array[Vector2] = [Vector2(-Fort.GATE_W * 0.5, Fort.GATE_W * 0.5), Vector2(door_at - 0.95, door_at + 0.95)]
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := -h
	var spans: Array[Vector2] = []
	for g in gaps:
		spans.append(Vector2(cursor, g.x))
		cursor = g.y
	spans.append(Vector2(cursor, h))
	for s in spans:
		var size := _box_size(side, s.y - s.x, top, t)
		var at := _point(side, (s.x + s.y) * 0.5, h) + Vector3.UP * top * 0.5
		l.box(at, size, STONE)
		w.add_solid(at, size)
	# The walk stays whole over the openings.
	var over_gate := _box_size(side, Fort.GATE_W, top - Fort.GATE_H, t)
	var over_at := _point(side, 0.0, h) + Vector3.UP * (Fort.GATE_H + (top - Fort.GATE_H) * 0.5)
	l.box(over_at, over_gate, STONE_DARK)
	w.add_collider(over_at, over_gate)
	var over_door := _box_size(side, 1.9, top - 2.5, t)
	var door_point := _point(side, door_at, h)
	l.box(door_point + Vector3.UP * (2.5 + (top - 2.5) * 0.5), over_door, STONE_DARK)
	w.add_collider(door_point + Vector3.UP * (2.5 + (top - 2.5) * 0.5), over_door)
	# Only players fit through the small door.
	var plug := _box_size(side, 1.9, 2.5, t)
	w.add_enemy_block(door_point + Vector3.UP * 1.25, plug)
	var dark := Color(0.05, 0.04, 0.04)
	for f: float in [-1.0, 1.0]:
		l.box(_point(side, door_at + f * 1.02, h + t * 0.52) + Vector3.UP * 1.25, _box_size(side, 0.18, 2.5, 0.12), PLANK)
	l.box(_point(side, door_at, h + t * 0.52) + Vector3.UP * 2.56, _box_size(side, 2.2, 0.16, 0.12), PLANK)
	l.box(door_point + Vector3.DOWN * 0.04 + Vector3.UP * 0.02, _box_size(side, 1.9, 0.05, t), dark)
	# Battlements on the outer edge. You can step between them and drop.
	var a := -h + 3.0
	while a < h - 2.5:
		var p := _point(side, a, h + t * 0.5 - 0.2)
		l.box(p + Vector3.UP * (top + 0.42), _box_size(side, 1.1, 0.84, 0.4), STONE_DARK.lightened(0.06))
		w.add_collider(p + Vector3.UP * (top + 0.42), _box_size(side, 1.1, 0.84, 0.4))
		a += 2.3


func _tower(l: LowPoly, at: Vector3) -> void:
	var high := Fort.WALL_H + 3.2
	l.prism(at, at + Vector3.UP * high, 3.4, 3.1, 8, STONE.darkened(0.05))
	l.prism(at + Vector3.UP * high, at + Vector3.UP * (high + 0.5), 3.7, 3.7, 8, STONE_DARK)
	for i in 8:
		var a := TAU * i / 8.0
		l.box(at + Vector3(cos(a) * 3.3, high + 0.85, sin(a) * 3.3), Vector3(0.8, 0.7, 0.8), STONE_DARK.lightened(0.05))
	w.add_solid(at + Vector3.UP * high * 0.5, Vector3(5.6, high, 5.6))
	w.perches.append(at + Vector3.UP * (high + 0.6))


func _gate(i: int) -> void:
	var dir := Fort.DIRS[i]
	var node := Node3D.new()
	node.position = dir * Fort.HALF
	node.rotation.y = 0.0 if absf(dir.z) > 0.5 else PI * 0.5
	w.add_child(node)
	# Rows of planks, each its own mesh, so a damaged gate can lose them one by one.
	var rows: Array[Node3D] = []
	const ROWS := 5
	for r in ROWS:
		var row := LowPoly.new()
		var y := (r + 0.5) * Fort.GATE_H / ROWS
		var x := -Fort.GATE_W * 0.5 + 0.34
		var k := 0
		while x < Fort.GATE_W * 0.5:
			row.box(Vector3(x, y, 0), Vector3(0.62, Fort.GATE_H / ROWS + 0.02, 0.36), PLANK.lightened(0.04 * (k % 3)).darkened(0.03 * (r % 2)))
			x += 0.68
			k += 1
		if r % 2 == 0:
			row.box(Vector3(0, y, 0.2), Vector3(Fort.GATE_W, 0.18, 0.1), Color(0.14, 0.13, 0.14))
			row.box(Vector3(0, y, -0.2), Vector3(Fort.GATE_W, 0.18, 0.1), Color(0.14, 0.13, 0.14))
		var mi := MeshInstance3D.new()
		mi.mesh = row.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		rows.append(mi)
	fort.add_gate(i, node, rows)
	v.torch(dir * (Fort.HALF + 2.3) + Vector3(dir.z, 0, -dir.x) * 4.0)
	v.torch(dir * (Fort.HALF + 2.3) - Vector3(dir.z, 0, -dir.x) * 4.0)


## A ramp up to the walk on each side of the yard, with steps drawn on it.
func _stairs() -> void:
	var inner := Fort.HALF - Fort.WALL_T * 0.5 - 1.3
	for side in 4:
		var dir := Fort.DIRS[side]
		var across := Vector3(dir.z, 0, -dir.x)
		var sign_s := 1.0 if side % 2 == 0 else -1.0
		var from := dir * inner + across * sign_s * 21.0
		var to := dir * inner + across * sign_s * 6.0
		_ramp(from, to + Vector3.UP * Fort.WALL_H, 2.6)


func _ramp(from: Vector3, to: Vector3, width: float) -> void:
	var run := to - from
	var flat := Vector3(run.x, 0, run.z)
	var length := run.length()
	var along := flat.normalized()
	var basis_z := run.normalized()
	var basis_x := Vector3.UP.cross(along).normalized()
	var basis_y := basis_z.cross(basis_x).normalized()
	var body_box := Vector3(width, 0.3, length)
	var centre := (from + to) * 0.5 - basis_y * 0.15
	w.add_rotated_collider(Transform3D(Basis(basis_x, basis_y, basis_z), centre), body_box)
	var size := Vector3(absf(along.z) * width + absf(along.x) * flat.length(), 2.5, absf(along.x) * width + absf(along.z) * flat.length())
	w.grid.block_box((from + to) * 0.5, size)
	var l := LowPoly.new()
	var steps := int(run.y / 0.42)
	for i in steps:
		var f := (float(i) + 0.5) / steps
		var p := from + run * f
		var tall := p.y + 0.21
		var side := Vector3(absf(along.z) * width + absf(along.x) * flat.length() / steps, tall, absf(along.x) * width + absf(along.z) * flat.length() / steps)
		l.box(Vector3(p.x, tall * 0.5, p.z), side, STONE.lightened(0.05 * (i % 2)))
	v._add(l)


## The keep, and in it the heart that has to last until morning.
func _keep() -> void:
	var stone := {"plaster": STONE.lightened(0.04), "roof": Color(0.22, 0.2, 0.24), "beams": false}
	var c := v._house(Vector3.ZERO, 15, 15, 5.0, "x", stone, {"n": [v.door(0, 3.0, 3.4)], "e": [v.door(0, 3.0, 3.4)], "s": [v.door(0, 3.0, 3.4)], "w": [v.door(0, 3.0, 3.4)]})
	var at := v.on_ground(Vector3(0, 0, 0))
	var l := LowPoly.new()
	l.prism(at, at + Vector3.UP * 0.5, 1.3, 1.1, 8, STONE_DARK)
	l.prism(at + Vector3.UP * 0.5, at + Vector3.UP * 0.9, 0.7, 0.45, 8, STONE)
	v._add(l)
	w.add_solid(at + Vector3.UP * 0.5, Vector3(2.2, 1.0, 2.2))
	var heart := LowPoly.new()
	heart.prism(Vector3(0, -0.5, 0), Vector3(0, 0, 0), 0.08, 0.45, 8, Color(1.0, 0.36, 0.28))
	heart.prism(Vector3(0, 0, 0), Vector3(0, 0.5, 0), 0.45, 0.08, 8, Color(1.0, 0.52, 0.36))
	var mi := MeshInstance3D.new()
	mi.mesh = heart.commit()
	var m := LowPoly.material().duplicate() as StandardMaterial3D
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	mi.material_override = m
	mi.position = at + Vector3.UP * 1.6
	w.add_child(mi)
	w.add_spinner(mi, Vector3.UP, 0.8)
	w.add_glow(at + Vector3.UP * 1.6, Color(1.0, 0.36, 0.26), 4.0)
	if Game.quality > 0:
		var light := OmniLight3D.new()
		light.position = at + Vector3.UP * 2.2
		light.light_color = Color(1.0, 0.42, 0.3)
		light.light_energy = 2.2
		light.omni_range = 9.0
		w.add_child(light)
		w.add_lantern_light(light)
	fort.set_heart(at, mi)
	v._loot(c + Vector3(-5, 0, -5))
	v._loot(c + Vector3(5, 0, 5))


func _yard() -> void:
	var a := {"plaster": Village.PLASTER, "roof": Village.THATCH}
	var b := {"plaster": Village.PLANK.lightened(0.15), "roof": Village.SHINGLE, "beams": false}
	var h1 := v._house(Vector3(-14, 0, -14), 7, 6, 2.8, "x", a, {"s": [v.door(0)], "e": [v.window(0)]})
	v._bed(h1 + Vector3(-2, 0, -1.6))
	v._loot(h1 + Vector3(2, 0, -1.2))
	var h2 := v._house(Vector3(14, 0, 14), 7, 6, 2.8, "x", b, {"n": [v.door(0)], "w": [v.window(0)]})
	v._table(h2 + Vector3(-1.4, 0, 1.3))
	v._loot(h2 + Vector3(2, 0, 1.2))
	for at: Vector3 in [Vector3(14, 0, -14), Vector3(-15, 0, 14)]:
		v.bonfire(at)
		v._loot(at + Vector3(0, 0, 3.0))
	v._hay_bale(Vector3(18, 0, -9), Vector3(2.0, 1.0, 1.4))
	v._hay_bale(Vector3(-19, 0, 9), Vector3(2.0, 1.0, 1.4))
	v._prop_at("props/barrel", Vector3(11, 0, 19), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	v._prop_at("props/crate_A_big", Vector3(-11, 0, -19), 4.0, 0.3, Vector3(0.9, 0.85, 0.9))
	v._prop_at("props/weaponrack", Vector3(8, 0, -19), 5.0, 0.0, Vector3(1.0, 1.2, 0.7))
	v._prop_at("props/target", Vector3(-8, 0, 19), 5.0, 0.0, Vector3(1.2, 1.5, 0.5))
	for at: Vector3 in [Vector3(9, 0, 9), Vector3(-9, 0, -9), Vector3(-9, 0, 9), Vector3(9, 0, -9)]:
		v.torch(at)
	w.pois.append(Vector3(10, 0, 0))
	w.pois.append(Vector3(-10, 0, 0))
	w.pois.append(Vector3(0, 0, 12))
	w.pois.append(Vector3(0, 0, -12))


## Out in the wood: fallen trees and old camps, and the wood that keeps the gates standing.
func _outside() -> void:
	var a := {"plaster": Village.PLANK.lightened(0.1), "roof": Village.SHINGLE, "beams": false}
	for at: Vector3 in [Vector3(58, 0, 12), Vector3(-60, 0, -14), Vector3(14, 0, 62), Vector3(-12, 0, -60)]:
		var hut := v._house(at, 6, 6, 2.6, "x", a, {"s": [v.door(0, 2.0, 2.3)], "n": [v.window(0)]})
		v._loot(hut + Vector3(1.4, 0, -1.2))
		w.pois.append(at + Vector3(0, 0, 6))
		v.bonfire(at + Vector3(5, 0, 5))
	var logs := LowPoly.new()
	for i in 12:
		var a2 := TAU * i / 12.0 + 0.3
		var r := 46.0 + (i % 3) * 14.0
		var at := v.on_ground(Vector3(cos(a2) * r, 0, sin(a2) * r))
		logs.prism(at + Vector3(-1.6, 0.25, 0), at + Vector3(1.6, 0.25, 0.4), 0.24, 0.22, 6, Color(0.32, 0.22, 0.14))
		w.wood_spots.append(at + Vector3(0, 0, 1.4))
	v._add(logs)
	# A little wood is kept in the yard, for when going out is out of the question.
	w.yard_wood_spots.append(Vector3(19, 0, 6))
	w.yard_wood_spots.append(Vector3(-19, 0, -6))
	w.map_roads = ROADS
