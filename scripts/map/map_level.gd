@tool
class_name MapLevel
extends MapPiece
## A level platform, at this piece's own height, blended into the land around it over blend metres.
## Buildings level the ground under themselves. This is for wider areas, like a village or a terrace.

@export var size := Vector2(30, 30):
	set(v):
		size = v
		refresh()
@export var blend := 5.0:
	set(v):
		blend = v
		refresh()


func _init() -> void:
	on_ground = false


func land(t: Terrain, at: Transform3D) -> void:
	t.level(Vector2(at.origin.x, at.origin.z), size * 0.5, at.basis.get_euler().y, at.origin.y, blend)


func shapes_land() -> bool:
	return true


func build(b: MapBuilder) -> void:
	if b.is_preview:
		b.w.show_area(size)
