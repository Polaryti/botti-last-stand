@tool
class_name MapSetPiece
extends MapPiece
## A big landmark drawn by code, placed as one thing. Its look is in scripts/map/map_builder.gd.
## fort_walls and fort_keep hold the rules of the fort, so leave those two in the middle of their map.

@export_enum("church", "cowshed", "windmill", "mill_wheel", "fort_walls", "fort_keep") var kind := "church":
	set(v):
		kind = v
		refresh()


func build(b: MapBuilder) -> void:
	match kind:
		"church": b.church()
		"cowshed": b.cowshed()
		"windmill": b.windmill()
		"mill_wheel": b.mill_wheel()
		"fort_walls": b.fort_walls()
		"fort_keep": b.fort_keep()


func land(t: Terrain, at: Transform3D) -> void:
	if not on_ground:
		return
	match kind:
		"church":
			t.level_auto(Vector2(at.origin.x, at.origin.z) + _flat(at, Vector3(0, 0, -2.5)), Vector2(7.0, 13.0), at.basis.get_euler().y, 5.0)
		"cowshed":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(10.0, 6.0), at.basis.get_euler().y, 4.0)
		"windmill":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(7.0, 7.0), at.basis.get_euler().y, 6.0)


func _flat(at: Transform3D, local: Vector3) -> Vector2:
	var p := at.basis * local
	return Vector2(p.x, p.z)


func shapes_land() -> bool:
	return on_ground and kind in ["church", "cowshed", "windmill"]
