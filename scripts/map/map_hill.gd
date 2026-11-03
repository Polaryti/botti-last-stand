@tool
class_name MapHill
extends MapPiece
## A rise in the land. height is how tall at the top, radius how wide its slopes spread.

@export var height := 5.0:
	set(v):
		height = v
		refresh()
@export var radius := 20.0:
	set(v):
		radius = v
		refresh()


func land(t: Terrain, at: Transform3D) -> void:
	t.hill(at.origin.x, at.origin.z, height, radius)


func shapes_land() -> bool:
	return true


func build(b: MapBuilder) -> void:
	if b.is_preview:
		b.w.show_spot("hill", "", b.xf.origin)
