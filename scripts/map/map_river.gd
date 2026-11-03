@tool
class_name MapRiver
extends Path3D
## The river, from where it comes in to where it leaves. It flows from the first point to the last,
## and carries anyone in it along. Only the shallows can be walked, so it divides the map.

@export var width := 4.2:
	set(v):
		width = v
		_refresh()


func land(t: Terrain, at: Transform3D) -> void:
	var line: Array[Vector2] = []
	if curve:
		for i in curve.point_count:
			var p := at * curve.get_point_position(i)
			line.append(Vector2(p.x, p.z))
	t.set_river(line, width)


func build(b: MapBuilder) -> void:
	if not b.terrain.river.is_empty():
		b.river()


func shapes_land() -> bool:
	return true


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
