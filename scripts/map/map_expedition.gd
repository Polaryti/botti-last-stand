@tool
class_name MapExpedition
extends MapPiece
## Optional supply stop with two approaches, readable landmark and per-player rewards.
## Paths use world X/Z coordinates so their endpoints can connect existing roads exactly.

@export var title := "Supply camp":
	set(v):
		title = v
		refresh()
@export_enum("camp", "ruin") var style := "camp":
	set(v):
		style = v
		refresh()
@export var trail := PackedVector2Array():
	set(v):
		trail = v
		refresh()
@export var reward := "speed":
	set(v):
		reward = v
		refresh()
@export var timber := false:
	set(v):
		timber = v
		refresh()


func follows_land() -> bool:
	return true


func shapes_land() -> bool:
	return style == "camp"


func land(t: Terrain, at: Transform3D) -> void:
	if style == "camp":
		t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(5, 5), at.basis.get_euler().y, 4.0)


func build(b: MapBuilder) -> void:
	var origin := b.xf
	var l := b.cell()
	var stone := Color(0.43, 0.46, 0.45) if style == "ruin" else MapBuilder.BEAM
	# The shelter sits behind the cache; the front and both flanks stay open.
	for x: float in [-3.2, 3.2]:
		for z: float in [-3.5, 0.5]:
			var foot := origin.affine_inverse() * b.on_ground(Vector3(x, 0, z))
			l.prism(foot, foot + Vector3.UP * (3.4 if style == "ruin" else 2.8), 0.3 if style == "ruin" else 0.1, 0.23 if style == "ruin" else 0.08, 6, stone)
			b.solid(foot + Vector3.UP * 1.4, Vector3(0.5, 2.8, 0.5) if style == "ruin" else Vector3(0.18, 2.8, 0.18))
	if style == "camp":
		var cloth := Color(0.39, 0.27, 0.18)
		for side: float in [-1, 1]:
			var a := Vector3(side * 3.4, 2.8, -3.7)
			var c := Vector3(side * 3.4, 2.8, 0.7)
			var ridge_a := Vector3(0, 3.9, -3.7)
			var ridge_b := Vector3(0, 3.9, 0.7)
			l.gable(a, c, ridge_a, cloth)
			l.gable(c, ridge_b, ridge_a, cloth.lightened(0.07))
		l.box(Vector3(0, 3.75, -1.5), Vector3(0.12, 0.12, 4.7), MapBuilder.BEAM)
		for z: float in [-3.7, 0.7]:
			for side: float in [-1, 1]:
				l.prism(Vector3(side * 3.2, 2.75, z), Vector3(0, 3.75, z), 0.07, 0.07, 5, MapBuilder.BEAM)
		for x: float in [-3.2, 3.2]:
			l.box(Vector3(x, 2.75, -1.5), Vector3(0.12, 0.12, 4.4), MapBuilder.BEAM)
	else:
		# Broken arch and low rear wall: shelter silhouettes without trapping mobs or players.
		l.box(Vector3(0, 3.5, -3.5), Vector3(6.8, 0.45, 0.65), stone.lightened(0.12))
		for x: float in [-2.4, 2.4]:
			var foot := origin.affine_inverse() * b.on_ground(Vector3(x, 0, -3.5))
			l.box(foot + Vector3.UP * 0.55, Vector3(1.6, 1.1, 0.7), stone.darkened(0.12))
			b.solid(foot + Vector3.UP * 0.55, Vector3(1.6, 1.1, 0.7))
			l.box(foot + Vector3(0.15, 1.2, 0), Vector3(1.1, 0.25, 0.8), stone)
	# Supplies, a bench and a route marker create a legible abandoned stopping place.
	for row: Array in [[Vector3(-2.0, 0, -2.8), "props/barrel", Vector3(0.85, 0.9, 0.85)], [Vector3(2.0, 0, -2.6), "props/crate_A_big", Vector3(0.9, 0.85, 0.9)]]:
		var at := b.on_ground(row[0])
		b.stand_at(Transform3D(origin.basis, at))
		b.prop(row[1], 4.0, row[2])
	b.stand_at(origin)
	l = b.cell()
	var bench := origin.affine_inverse() * b.on_ground(Vector3(-2.3, 0, 2))
	l.box(bench + Vector3.UP * 0.65, Vector3(1.8, 0.18, 0.55), MapBuilder.PLANK)
	for x: float in [-0.6, 0.6]:
		l.box(bench + Vector3(x, 0.3, 0), Vector3(0.12, 0.6, 0.4), MapBuilder.BEAM)
	b.solid(bench + Vector3.UP * 0.35, Vector3(1.8, 0.7, 0.55))
	var flag := origin.affine_inverse() * b.on_ground(Vector3(3.8, 0, 2.5))
	l.prism(flag, flag + Vector3.UP * 4.5, 0.08, 0.05, 5, stone)
	l.box(flag + Vector3(-0.6, 3.8, 0), Vector3(1.3, 1.0, 0.04), Color(0.63, 0.32, 0.12) if style == "camp" else Color(0.19, 0.48, 0.46))
	b.stand_at(Transform3D(origin.basis, b.on_ground(Vector3(2.8, 0, 1.0))))
	b.lantern()
	b.stand_at(origin)
	if trail.size() > 1:
		var points: Array[Vector2] = []
		points.assign(trail)
		b.road(points, 2.8)
		b.w.map_roads.append(points)
		_trail_markers(b)
		b.stand_at(origin)
	if timber:
		b.stand_at(Transform3D(origin.basis, b.on_ground(Vector3(0, 0, -5.0))))
		b.log_pile()
		b.stand_at(origin)
	if b.is_preview:
		b.w.show_spot("loot", title, origin.origin)
		return
	var w: World = b.w
	w.map_marks.append({"name": title, "at": Vector2(origin.origin.x, origin.origin.z)})
	w.pois.append(origin.origin)
	if w.caches == null:
		w.caches = MistCaches.new(w)
		w.add_child(w.caches)
	w.caches.add(b.on_ground(Vector3(0, 0, -1)), 15, reward, "", title, 12.0, true)


func _trail_markers(b: MapBuilder) -> void:
	# Mark the outside of turns, leaving a full 2.8 m walking lane. Geometry is area-batched.
	for i in trail.size():
		var p := trail[i]
		var direction := (trail[mini(i + 1, trail.size() - 1)] - trail[maxi(0, i - 1)]).normalized()
		var side := direction.orthogonal() * 2.3
		var at := Vector3(p.x + side.x, 0, p.y + side.y)
		at.y = b.terrain.height(at.x, at.z)
		b.stand_at(Transform3D(Basis.IDENTITY, at))
		var l := b.cell()
		l.prism(Vector3.ZERO, Vector3.UP * 1.1, 0.12, 0.09, 5, MapBuilder.BEAM)
		l.box(Vector3(0, 0.9, 0), Vector3(0.8, 0.2, 0.09), Color(0.76, 0.61, 0.3))
