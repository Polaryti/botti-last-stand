class_name BastionBuilder
## Mist Bastion, drawn by code: the citadel on the summit with its three gates and posterns, the Great
## Portal it guards (a ring of runestones turning in the air above an anchor stone), jagged rock
## spines that keep the three lanes apart, the waystones the Mist Soldiers step out of, and the
## Bastion's dressing: mist braziers, rune hangings on its walls and the waymarks along its lanes.
## The citadel tells the Fort rules where its walls, gates, doors and portal are.
## Pieces are placed without a turn: the citadel's walls run along X and Z.

const SLATE := Color(0.33, 0.33, 0.4)
const SLATE_DARK := Color(0.2, 0.2, 0.27)
const SLATE_LIGHT := Color(0.44, 0.44, 0.52)
const IRONWOOD := Color(0.27, 0.2, 0.2)
const BAND := Color(0.16, 0.3, 0.33)
const SPINE := Color(0.3, 0.29, 0.34)
const SPINE_DARK := Color(0.19, 0.18, 0.23)
## Gates in the order the Fort numbers them: the lanes west, middle and east.
const GATES := ["west", "middle", "east"]
const POSTERN_W := 1.9
const POSTERN_H := 2.5
const SINK := 1.5 # walls go this far into the ground, so slopes never show a gap under them


## The citadel: walls round a rectangle width x depth, gates in the west, south and east walls,
## a postern in each of them, round towers on the corners and a glowing rune band along the top.
static func citadel(b: MapBuilder, width: float, depth: float, gate_z: float, postern_side: float, postern_south: float) -> void:
	b.w.start_fort()
	var hw := width * 0.5
	var hd := depth * 0.5
	var o := b.xf.origin
	var outline := PackedVector2Array([Vector2(o.x - hw, o.z - hd), Vector2(o.x + hw, o.z - hd), Vector2(o.x + hw, o.z + hd), Vector2(o.x - hw, o.z + hd)])
	b.w.fort.set_region(outline, o.y)
	var l := b.mesh()
	var runes := b.mesh()
	var gw := Fort.GATE_W
	# North: whole, with the mountain at its back. West and east: a gate and a postern. South: the
	# middle gate and a postern.
	_wall(b, l, runes, Vector2(-hw, -hd), Vector2(hw, -hd), [])
	_wall(b, l, runes, Vector2(-hw, -hd), Vector2(-hw, hd), [Vector3(gate_z - gw * 0.5, gate_z + gw * 0.5, Fort.GATE_H), Vector3(postern_side - POSTERN_W * 0.5, postern_side + POSTERN_W * 0.5, POSTERN_H)])
	_wall(b, l, runes, Vector2(hw, -hd), Vector2(hw, hd), [Vector3(gate_z - gw * 0.5, gate_z + gw * 0.5, Fort.GATE_H), Vector3(postern_side - POSTERN_W * 0.5, postern_side + POSTERN_W * 0.5, POSTERN_H)])
	_wall(b, l, runes, Vector2(-hw, hd), Vector2(hw, hd), [Vector3(-gw * 0.5, gw * 0.5, Fort.GATE_H), Vector3(postern_south - POSTERN_W * 0.5, postern_south + POSTERN_W * 0.5, POSTERN_H)])
	for c: Vector2 in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(-hw, hd), Vector2(hw, hd)]:
		_tower(b, l, runes, Vector3(c.x, 0, c.y))
	var walls := MeshInstance3D.new()
	walls.mesh = l.commit()
	walls.material_override = b.no_fog()
	b.w.add_child(walls)
	var glow := MeshInstance3D.new()
	glow.mesh = runes.commit()
	glow.material_override = MesenllaBuilder.glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(glow)
	# The gates, in lane order, and the small doors beside them.
	_gate(b, GATES[0], Vector3(-hw, 0, gate_z), Vector3.LEFT)
	_gate(b, GATES[1], Vector3(0, 0, hd), Vector3.BACK)
	_gate(b, GATES[2], Vector3(hw, 0, gate_z), Vector3.RIGHT)
	b.w.fort.add_door(b.xf * Vector3(-hw, 0, postern_side), Vector3.LEFT)
	b.w.fort.add_door(b.xf * Vector3(postern_south, 0, hd), Vector3.BACK)
	b.w.fort.add_door(b.xf * Vector3(hw, 0, postern_side), Vector3.RIGHT)


## One straight wall from a to b (local, along X or along Z), with openings: Vector3(from, to, top)
## measured along the wall from the middle of a and b's own axis (z for a wall along Z, x along X).
static func _wall(b: MapBuilder, l: LowPoly, runes: LowPoly, a: Vector2, c: Vector2, openings: Array) -> void:
	var along_x := absf(a.y - c.y) < 0.01
	var t := Fort.WALL_T
	var top := Fort.WALL_H
	var lo := minf(a.x, c.x) if along_x else minf(a.y, c.y)
	var hi := maxf(a.x, c.x) if along_x else maxf(a.y, c.y)
	var line := a.y if along_x else a.x
	var out := signf(line) if absf(line) > 0.01 else 1.0 # which side is outside
	var gaps := openings.duplicate()
	gaps.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.x < q.x)
	var spans: Array[Vector2] = []
	var cursor := lo
	for g: Vector3 in gaps:
		spans.append(Vector2(cursor, g.x))
		cursor = g.y
	spans.append(Vector2(cursor, hi))
	for s in spans:
		if s.y - s.x < 0.05:
			continue
		var mid := (s.x + s.y) * 0.5
		var size := _sized(along_x, s.y - s.x, top + SINK, t)
		var centre := _on(along_x, mid, line, (top - SINK) * 0.5)
		l.box(centre, size, SLATE.lightened(0.03 * (int(mid) % 3)))
		b.w.add_solid(b.xf * centre, size)
		# A plinth of darker stone along the foot of the wall, outside.
		l.box(_on(along_x, mid, line + out * (t * 0.5 + 0.15), 0.35 - SINK * 0.5), _sized(along_x, s.y - s.x, 0.7 + SINK, 0.3), SLATE_DARK)
		# The rune band, on the outer face just under the walk.
		runes.box(_on(along_x, mid, line + out * (t * 0.5 + 0.02), top - 0.9), _sized(along_x, (s.y - s.x) - 0.6, 0.12, 0.03), MesenllaBuilder.RUNE)
	# The walk goes on over every opening.
	for g: Vector3 in gaps:
		var mid := (g.x + g.y) * 0.5
		var over := _sized(along_x, g.y - g.x, top - g.z, t)
		var at := _on(along_x, mid, line, g.z + (top - g.z) * 0.5)
		l.box(at, over, SLATE_DARK)
		b.w.add_collider(b.xf * at, over)
		if g.z < Fort.GATE_H - 0.01:
			# A postern: a narrow door only players fit through, with a dark lintel and posts.
			b.w.add_enemy_block(b.xf * _on(along_x, mid, line, g.z * 0.5), _sized(along_x, g.y - g.x, g.z, t))
			for f: float in [g.x - 0.1, g.y + 0.1]:
				l.box(_on(along_x, f, line + out * (t * 0.52), g.z * 0.5), _sized(along_x, 0.2, g.z, 0.14), IRONWOOD)
			l.box(_on(along_x, mid, line + out * (t * 0.52), g.z + 0.08), _sized(along_x, g.y - g.x + 0.4, 0.16, 0.14), IRONWOOD)
			l.box(_on(along_x, mid, line, -0.02), _sized(along_x, g.y - g.x, 0.05, t), Color(0.05, 0.05, 0.07))
		else:
			# A gateway: a stone arch-face with a keystone of mist-glass.
			l.box(_on(along_x, mid, line + out * (t * 0.5 + 0.1), g.z + 0.35), _sized(along_x, g.y - g.x + 1.2, 0.7, 0.2), SLATE_LIGHT)
			runes.box(_on(along_x, mid, line + out * (t * 0.5 + 0.22), g.z + 0.4), _sized(along_x, 0.5, 0.6, 0.05), MesenllaBuilder.MIST_GLOW)
	# Merlons along the outer edge, which you can step between.
	var m := lo + 2.6
	while m < hi - 2.4:
		var at := _on(along_x, m, line + out * (t * 0.5 - 0.2), top + 0.42)
		var size := _sized(along_x, 1.1, 0.84, 0.4)
		l.box(at, size, SLATE_DARK.lightened(0.08))
		b.w.add_collider(b.xf * at, size)
		m += 2.3


static func _on(along_x: bool, along: float, line: float, y: float) -> Vector3:
	return Vector3(along, y, line) if along_x else Vector3(line, y, along)


static func _sized(along_x: bool, length: float, h: float, thick: float) -> Vector3:
	return Vector3(length, h, thick) if along_x else Vector3(thick, h, length)


## A round corner tower with a crown of crystal points.
static func _tower(b: MapBuilder, l: LowPoly, runes: LowPoly, at: Vector3) -> void:
	var high := Fort.WALL_H + 3.6
	l.prism(at + Vector3.DOWN * SINK, at + Vector3.UP * high, 3.4, 3.0, 8, SLATE.darkened(0.05))
	l.prism(at + Vector3.UP * high, at + Vector3.UP * (high + 0.5), 3.6, 3.6, 8, SLATE_DARK)
	for i in 8:
		var a := TAU * i / 8.0
		l.box(at + Vector3(cos(a) * 3.2, high + 0.85, sin(a) * 3.2), Vector3(0.8, 0.7, 0.8), SLATE_DARK.lightened(0.06))
	runes.prism(at + Vector3.UP * (high - 1.2), at + Vector3.UP * (high - 1.05), 3.25, 3.25, 8, MesenllaBuilder.RUNE)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var foot := at + Vector3(cos(a) * 1.2, high + 0.5, sin(a) * 1.2)
		runes.prism(foot, foot + Vector3(cos(a) * 0.3, 1.4 + 0.3 * i, sin(a) * 0.3), 0.3, 0.0, 5, MesenllaBuilder.MIST_GLOW)
	b.w.add_solid(b.xf * (at + Vector3.UP * (high - SINK) * 0.5), Vector3(5.6, high + SINK, 5.6))
	b.w.perches.append(b.xf * (at + Vector3.UP * (high + 0.6)))
	b.w.add_glow(b.xf * (at + Vector3.UP * (high + 1.4)), MesenllaBuilder.MIST_GLOW, 3.0, 160.0)


## A gate of dark ironwood planks bound with mist-green iron, in rows that fall away from the top as
## it takes damage. at is the middle of the gateway on the ground (local), out the way to the lane.
static func _gate(b: MapBuilder, gate_name: String, at: Vector3, out: Vector3) -> void:
	var node := Node3D.new()
	node.position = b.xf * at
	node.rotation.y = 0.0 if absf(out.z) > 0.5 else PI * 0.5
	b.w.add_child(node)
	var rows: Array[Node3D] = []
	const ROWS := 5
	for r in ROWS:
		var row := LowPoly.new()
		var y := (r + 0.5) * Fort.GATE_H / ROWS
		var x := -Fort.GATE_W * 0.5 + 0.34
		var k := 0
		while x < Fort.GATE_W * 0.5:
			row.box(Vector3(x, y, 0), Vector3(0.62, Fort.GATE_H / ROWS + 0.02, 0.36), IRONWOOD.lightened(0.05 * (k % 3)).darkened(0.04 * (r % 2)))
			x += 0.68
			k += 1
		if r % 2 == 0:
			for side: float in [0.2, -0.2]:
				row.box(Vector3(0, y, side), Vector3(Fort.GATE_W, 0.18, 0.1), BAND)
			row.box(Vector3(0, y, 0.25), Vector3(0.5, 0.5, 0.06), BAND.lightened(0.2))
		var mi := MeshInstance3D.new()
		mi.mesh = row.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		rows.append(mi)
	b.w.fort.add_gate_at(gate_name, b.xf * at, out, node, rows)


## The Great Portal: an anchor stone on a round dais, and above it a ring of runestones turning slowly
## in the air round a swirl of mist; four obelisks stand round it and a pillar of mist rises from it.
## This is what the enemies come for: when the Fort's heart falls, the ring goes dark and falls still.
static func great_portal(b: MapBuilder, radius: float) -> void:
	MesenllaBuilder._feature(b, "great_portal", radius)
	if b.w.fort == null:
		b.w.start_fort()
	var l := b.mesh()
	l.prism(Vector3(0, -0.4, 0), Vector3(0, 0.12, 0), radius + 2.6, radius + 2.4, 16, SLATE_DARK)
	l.prism(Vector3(0, 0.12, 0), Vector3(0, 0.24, 0), radius + 1.6, radius + 1.5, 16, SLATE)
	# The anchor stone the ring is bound to.
	l.prism(Vector3(0, 0.24, 0), Vector3(0, 1.1, 0), 1.0, 0.8, 6, SLATE_DARK)
	l.prism(Vector3(0, 1.1, 0), Vector3(0, 1.5, 0), 0.8, 0.0, 6, SLATE_LIGHT)
	b.solid(Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 1.8))
	var marks := b.mesh()
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var foot := Vector3(cos(a), 0, sin(a)) * (radius + 1.9)
		l.prism(foot, foot + Vector3.UP * 4.2, 0.55, 0.35, 4, SLATE)
		l.prism(foot + Vector3.UP * 4.2, foot + Vector3.UP * 4.9, 0.35, 0.0, 4, SLATE_DARK)
		b.solid(foot + Vector3.UP * 2.1, Vector3(0.9, 4.2, 0.9))
		marks.prism(foot + Vector3.UP * 4.9, foot + Vector3.UP * 5.5, 0.18, 0.0, 4, MesenllaBuilder.MIST_GLOW)
		for k in 3:
			marks.box(foot + Vector3(cos(a) * 0.42, 1.2 + k * 0.9, sin(a) * 0.42), Vector3(0.22, 0.08, 0.22), MesenllaBuilder.RUNE)
	# Rune lines across the dais, from the anchor stone to the obelisks.
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var d := Vector3(cos(a), 0, sin(a))
		marks.box(d * (radius + 0.4) * 0.5 + Vector3.UP * 0.25, Vector3(0.12, 0.03, radius + 0.4), MesenllaBuilder.RUNE, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	b.add(l)
	MesenllaBuilder._shine(b, marks)
	# The ring, its own node so that it can turn, and go when the portal is lost.
	var centre_y := radius + 1.2
	var ring := LowPoly.new()
	var stones := LowPoly.new()
	const PARTS := 18
	for i in PARTS:
		var a0 := TAU * i / PARTS
		var a1 := TAU * (i + 0.82) / PARTS
		var p0 := Vector3(cos(a0), sin(a0), 0) * radius
		var p1 := Vector3(cos(a1), sin(a1), 0) * radius
		ring.prism(p0, p1, 0.55, 0.55, 5, SLATE if i % 2 else SLATE_LIGHT)
		var mid := (p0 + p1) * 0.5
		stones.box(mid + Vector3(0, 0, 0.5), Vector3(0.22, 0.22, 0.04), MesenllaBuilder.RUNE)
		stones.box(mid + Vector3(0, 0, -0.5), Vector3(0.22, 0.22, 0.04), MesenllaBuilder.RUNE)
	var holder := Node3D.new()
	holder.name = "GreatPortal"
	holder.transform = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, centre_y, 0))
	b.w.add_child(holder)
	var spinning := Node3D.new()
	holder.add_child(spinning)
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring.commit()
	spinning.add_child(ring_mesh)
	var rune_mesh := MeshInstance3D.new()
	rune_mesh.mesh = stones.commit()
	rune_mesh.material_override = MesenllaBuilder.glow_material()
	rune_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spinning.add_child(rune_mesh)
	b.w.add_spinner(spinning, Vector3.BACK, 0.12)
	if not b.is_preview:
		var swirl := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(radius * 2.0 - 0.6, radius * 2.0 - 0.6)
		swirl.mesh = q
		swirl.material_override = MesenllaBuilder._portal_material()
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(swirl)
	b.w.add_glow(b.xf * Vector3(0, centre_y, 0.6), Color(0.35, 0.75, 1.0), radius * 2.6, 260.0)
	MesenllaBuilder._light(b, Vector3(0, centre_y, 2.0), Color(0.45, 0.8, 1.0), 3.0, radius * 3.0)
	MesenllaBuilder._mist(b, Vector3(0, centre_y + 4.0, 0), Vector3(1.2, 4.0, 1.2), MesenllaBuilder.MIST_GLOW, 14, 1.6)
	b.w.fort.set_heart(b.xf.origin, holder)


## A jagged spine of rock along the piece's X axis, as tall as a house, that nothing walks over: it
## keeps the lanes apart. Slabs lean this way and that, cracked through with mist-glass.
static func rock_spine(b: MapBuilder, length: float) -> void:
	MesenllaBuilder._feature(b, "spine", length)
	var r := b.seeded()
	var l := LowPoly.new()
	var glints := LowPoly.new()
	var x := -length * 0.5
	while x < length * 0.5:
		var step := r.randf_range(2.2, 3.0)
		var tall := r.randf_range(4.5, 8.0)
		var thick := r.randf_range(2.4, 3.6)
		var foot := b.on_ground(Vector3(x + step * 0.5, 0, r.randf_range(-0.4, 0.4)))
		var lean := Vector3(r.randf_range(-6, 6), r.randf_range(-12, 12), r.randf_range(-8, 8))
		var centre := foot + Vector3.UP * (tall * 0.5 - 1.0)
		l.box(centre, Vector3(step + 0.6, tall + 2.0, thick) if _along_world_x(b) else Vector3(thick, tall + 2.0, step + 0.6), SPINE if r.randf() < 0.6 else SPINE_DARK, lean)
		l.prism(centre + Vector3.UP * (tall * 0.5), centre + Vector3.UP * (tall * 0.5 + r.randf_range(0.8, 2.0)) + Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.5, 0.5)), thick * 0.45, 0.0, 4, SPINE_DARK)
		if r.randf() < 0.35:
			var crack := centre + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(-1.0, 1.5), 0)
			glints.box(crack, Vector3(0.18, r.randf_range(1.0, 2.4), thick + 0.06) if _along_world_x(b) else Vector3(thick + 0.06, r.randf_range(1.0, 2.4), 0.18), MesenllaBuilder.MIST_GLOW, Vector3(0, 0, r.randf_range(-20, 20)))
		b.w.add_solid(centre, Vector3(step + 0.4, tall + 2.0, thick) if _along_world_x(b) else Vector3(thick, tall + 2.0, step + 0.4))
		x += step
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	b.w.add_child(mi)
	var glow := MeshInstance3D.new()
	glow.mesh = glints.commit()
	glow.material_override = MesenllaBuilder.glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(glow)


## Whether the piece runs along the world's X axis (no turn, or half a turn) rather than along Z.
static func _along_world_x(b: MapBuilder) -> bool:
	return absf(b.xf.basis.x.x) > 0.7


## A waystone where Mist Soldiers step out of the mist: a tall stone with a ring of light round its
## top, and mist pooling at its foot.
static func waystone(b: MapBuilder) -> void:
	MesenllaBuilder._feature(b, "waystone", 1.0)
	var l := b.mesh()
	l.prism(Vector3(0, -0.3, 0), Vector3(0, 0.3, 0), 1.3, 1.1, 6, SLATE_DARK)
	l.prism(Vector3(0, 0.3, 0), Vector3(0, 3.6, 0), 0.55, 0.38, 4, SLATE)
	l.prism(Vector3(0, 3.6, 0), Vector3(0, 4.2, 0), 0.38, 0.0, 4, SLATE_LIGHT)
	b.add(l)
	b.solid(Vector3(0, 1.8, 0), Vector3(0.9, 3.6, 0.9))
	var g := b.mesh()
	for k in 4:
		g.box(Vector3(0, 0.9 + k * 0.7, 0.42), Vector3(0.2, 0.08, 0.03), MesenllaBuilder.RUNE)
	g.prism(Vector3(0, 3.0, 0), Vector3(0, 3.1, 0), 0.75, 0.75, 10, MesenllaBuilder.MIST_GLOW)
	MesenllaBuilder._shine(b, g)
	b.w.add_glow(b.xf * Vector3(0, 3.0, 0), MesenllaBuilder.MIST_GLOW, 3.2, 150.0)
	MesenllaBuilder._mist(b, Vector3(0, 0.4, 0), Vector3(1.6, 0.3, 1.6), MesenllaBuilder.MIST_GLOW, 6, 0.15)


## A brazier of mist fire on a stone foot: a slate bowl on a short column, cold blue flame in it.
static func brazier(b: MapBuilder) -> void:
	var l := b.cell()
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.25, 0), 0.7, 0.6, 6, SLATE_DARK)
	l.prism(Vector3(0, 0.25, 0), Vector3(0, 1.1, 0), 0.26, 0.22, 6, SLATE)
	l.prism(Vector3(0, 1.1, 0), Vector3(0, 1.45, 0), 0.32, 0.72, 8, SLATE_LIGHT)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		l.prism(Vector3(cos(a) * 0.62, 1.35, sin(a) * 0.62), Vector3(cos(a) * 0.7, 1.62, sin(a) * 0.7), 0.06, 0.0, 4, BAND)
	b.solid(Vector3(0, 0.7, 0), Vector3(0.9, 1.4, 0.9))
	var flame := b.mesh()
	flame.prism(Vector3(0, 1.4, 0), Vector3(0, 1.48, 0), 0.6, 0.6, 8, MesenllaBuilder.MIST_GLOW.darkened(0.2))
	for k in 5:
		var a := TAU * k / 5.0
		var at := Vector3(cos(a) * 0.28, 1.45, sin(a) * 0.28)
		flame.prism(at, at + Vector3(0, 0.45 + 0.2 * (k % 2), 0), 0.16, 0.0, 4, MesenllaBuilder.MIST_GLOW)
	flame.prism(Vector3(0, 1.45, 0), Vector3(0, 2.2, 0), 0.24, 0.0, 5, MesenllaBuilder.RUNE.lightened(0.3))
	MesenllaBuilder._shine(b, flame)
	b.w.add_glow(b.xf * Vector3(0, 1.8, 0), MesenllaBuilder.MIST_GLOW, 3.0, 150.0)
	MesenllaBuilder._light(b, Vector3(0, 2.2, 0), MesenllaBuilder.MIST_GLOW, 1.1, 7.0)
	MesenllaBuilder._mist(b, Vector3(0, 1.9, 0), Vector3(0.3, 0.2, 0.3), MesenllaBuilder.MIST_GLOW, 5, 0.5)


## Long hangings of slate-blue cloth against a wall, the piece's front facing out from it (+Z), each
## with the Bastion's rune worked on it in glowing thread, and a mist brazier's glow between them.
static func rune_banners(b: MapBuilder, width: float) -> void:
	var l := b.cell()
	var g := b.mesh()
	var count := maxi(2, int(width / 3.6))
	for k in count:
		var x := (float(k) + 0.5) / count * width - width * 0.5
		l.box(Vector3(x, 4.1, 0.05), Vector3(1.3, 0.1, 0.1), IRONWOOD)
		l.box(Vector3(x, 2.6, 0.07), Vector3(1.0, 3.0, 0.03), BAND.darkened(0.15))
		l.box(Vector3(x, 2.6, 0.08), Vector3(0.84, 2.8, 0.02), Color(0.2, 0.22, 0.36))
		# The swallow-tailed foot of the cloth.
		for side: float in [-1.0, 1.0]:
			l._tri(Vector3(x + side * 0.5, 1.1, 0.07), Vector3(x, 1.1, 0.07), Vector3(x + side * 0.3, 0.6, 0.07), Vector3(x, 1.0, -1), BAND.darkened(0.15))
		# The rune: a ring cut by a stroke, as on the Great Portal's stones.
		g.prism(Vector3(x, 2.9, 0.09), Vector3(x, 2.9, 0.1), 0.3, 0.3, 10, MesenllaBuilder.RUNE)
		g.prism(Vector3(x, 2.9, 0.1), Vector3(x, 2.9, 0.11), 0.22, 0.22, 10, Color(0.2, 0.22, 0.36))
		g.box(Vector3(x, 2.6, 0.12), Vector3(0.06, 0.9, 0.01), MesenllaBuilder.RUNE)
		g.box(Vector3(x, 1.6, 0.1), Vector3(0.6, 0.05, 0.01), MesenllaBuilder.RUNE.darkened(0.2))
	MesenllaBuilder._shine(b, g)


## A waymark beside a lane: a leaning slab with a glowing rune on its face, its foot in moss.
static func lane_stone(b: MapBuilder, tall: float) -> void:
	var r := b.seeded()
	var l := b.cell()
	var lean := Vector3(r.randf_range(-0.12, 0.12), 1.0, r.randf_range(-0.12, 0.12)).normalized()
	l.prism(Vector3(0, -0.4, 0), lean * tall, 0.42, 0.3, 4, SPINE if r.randf() < 0.5 else SLATE)
	l.prism(lean * tall, lean * (tall + 0.35), 0.3, 0.0, 4, SPINE_DARK)
	l.prism(Vector3(0, -0.05, 0), Vector3(0, 0.12, 0), 0.75, 0.6, 7, MesenllaBuilder.MOSS)
	b.solid(Vector3(0, tall * 0.5, 0), Vector3(0.6, tall, 0.6))
	var g := b.mesh()
	var face := lean * (tall * 0.62) + Vector3(0, 0, 0.3)
	g.box(face, Vector3(0.08, 0.5, 0.02), MesenllaBuilder.RUNE)
	g.box(face + Vector3(0, 0.12, 0), Vector3(0.3, 0.06, 0.02), MesenllaBuilder.RUNE)
	MesenllaBuilder._shine(b, g)


## An unseen wall along the piece's X axis: the edge of the land you can walk, beyond the outer spines.
## It stops everyone, and nothing paths through it.
static func bound(b: MapBuilder, length: float) -> void:
	b.w.add_barrier_xf(b.xf.translated_local(Vector3(0, 20.0, 0)), Vector3(length, 120.0, 2.0))
