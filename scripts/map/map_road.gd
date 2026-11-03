@tool
class_name MapRoad
extends Path3D
## A road. Drag its points in the editor. With cut on, the land is also shaped to it at each point's
## own height, which is how a road climbs a hill. With draw off it only shapes the land.

@export var width := 4.0:
	set(v):
		width = v
		_refresh()
@export var draw := true:
	set(v):
		draw = v
		_refresh()
@export var cut := false:
	set(v):
		cut = v
		_refresh()
@export var cut_blend := 3.5:
	set(v):
		cut_blend = v
		_refresh()


func points(at: Transform3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if curve:
		for i in curve.point_count:
			out.append(at * curve.get_point_position(i))
	return out


func land(t: Terrain, at: Transform3D) -> void:
	if cut:
		t.cut(points(at), width * 0.5 + 0.6, cut_blend)


func build(b: MapBuilder) -> void:
	if not draw:
		return
	var flat: Array[Vector2] = []
	for p: Vector3 in points(b.xf):
		flat.append(Vector2(p.x, p.z))
	if flat.size() >= 2:
		b.road(flat, width)
		b.w.map_roads.append(flat)


func shapes_land() -> bool:
	return cut


func follows_land() -> bool:
	return true


func _refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var root := MapRoot.of(self)
		if root:
			root.piece_changed(self)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		if not curve_changed.is_connected(_refresh):
			curve_changed.connect(_refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_inside_tree():
		_refresh()
