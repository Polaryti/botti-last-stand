@tool
class_name MapBridge
extends MapPiece
## A bridge along the piece's Z axis, centred over the water. The land at each end decides its height.

@export var length := 22.0:
	set(v):
		length = v
		refresh()
@export var hump := 1.0:
	set(v):
		hump = v
		refresh()
@export var stone_built := true:
	set(v):
		stone_built = v
		refresh()


func _init() -> void:
	on_ground = false


func land(t: Terrain, at: Transform3D) -> void:
	var a := at * Vector3(0, 0, -length * 0.5)
	var e := at * Vector3(0, 0, length * 0.5)
	t.bridge(Vector2(a.x, a.z), Vector2(e.x, e.z), hump)


func build(b: MapBuilder) -> void:
	b.bridge(length, stone_built)


func shapes_land() -> bool:
	return true


func follows_land() -> bool:
	return true
