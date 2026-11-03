@tool
class_name MapFord
extends MapPiece
## A shallow place where the river can be waded, with stones to mark it.

@export var size := Vector2(9, 22):
	set(v):
		size = v
		refresh()


func _init() -> void:
	on_ground = false


func land(t: Terrain, at: Transform3D) -> void:
	t.ford(Vector2(at.origin.x, at.origin.z), size * 0.5, at.basis.get_euler().y)


func build(b: MapBuilder) -> void:
	b.ford(size)


func shapes_land() -> bool:
	return true


func follows_land() -> bool:
	return true
