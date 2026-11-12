@tool
class_name MapBastion
extends MapPiece
## A part of Mist Bastion, drawn by code (scripts/map/bastion_builder.gd): the citadel and its gates,
## the Great Portal, a rock spine between two lanes, or a waystone for the Mist Soldiers.
## Place the citadel before the Great Portal, and without a turn: the Fort rules read its walls.

@export_enum("citadel", "great_portal", "rock_spine", "waystone") var kind := "citadel":
	set(v):
		kind = v
		refresh()
## citadel: its width (X) and depth (Z). great_portal: x is the ring's radius. rock_spine: x is its length.
@export var size := Vector2(52, 36):
	set(v):
		size = v
		refresh()
## citadel: where the west and east gates are along their walls, from the middle (+ is south).
@export var gate_at := 2.0:
	set(v):
		gate_at = v
		refresh()
## citadel: where the posterns are: along the west and east walls (x), and along the south wall (y).
@export var posterns := Vector2(-10, 14):
	set(v):
		posterns = v
		refresh()


func build(b: MapBuilder) -> void:
	match kind:
		"citadel": BastionBuilder.citadel(b, size.x, size.y, gate_at, posterns.x, posterns.y)
		"great_portal": BastionBuilder.great_portal(b, size.x)
		"rock_spine": BastionBuilder.rock_spine(b, size.x)
		"waystone": BastionBuilder.waystone(b)


func land(t: Terrain, at: Transform3D) -> void:
	if not on_ground:
		return
	match kind:
		"great_portal":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(size.x + 3.0, size.x + 3.0), at.basis.get_euler().y, 4.0)
		"waystone":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(1.6, 1.6), at.basis.get_euler().y, 2.0)


func shapes_land() -> bool:
	return on_ground and kind in ["great_portal", "waystone"]
