@tool
class_name MapMesenlla
extends MapPiece
## A landmark of the lands beyond the Mists, drawn by code (scripts/map/mesenlla_builder.gd):
## islands of rock floating in the twilight, rifts glowing in the ground, a Great Portal, rings of
## standing stones, Mesenlla banners, mist crystals, palisades of sharpened logs and watchtowers.
## A floating island is placed at its height above the ground with lift.

@export_enum("floating_island", "rift", "mist_gate", "standing_stones", "banner", "crystals", "palisade", "watchtower", "lodge_fire") var kind := "floating_island":
	set(v):
		kind = v
		refresh()
## How big it is: an island's width, a rift's length, a ring's radius, a palisade's length.
@export var size := 10.0:
	set(v):
		size = v
		refresh()
## Gaps in a palisade, as "start-end, start-end" in metres along it.
@export var openings := "":
	set(v):
		openings = v
		refresh()


func build(b: MapBuilder) -> void:
	match kind:
		"floating_island": MesenllaBuilder.floating_island(b, size)
		"rift": MesenllaBuilder.rift(b, size)
		"mist_gate": MesenllaBuilder.mist_gate(b, size)
		"standing_stones": MesenllaBuilder.standing_stones(b, size)
		"banner": MesenllaBuilder.banner(b, size)
		"crystals": MesenllaBuilder.crystals(b, size)
		"palisade": MesenllaBuilder.palisade(b, size, openings)
		"watchtower": MesenllaBuilder.watchtower(b, size)
		"lodge_fire": MesenllaBuilder.lodge_fire(b)


func land(t: Terrain, at: Transform3D) -> void:
	if not on_ground:
		return
	match kind:
		"mist_gate":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(size * 0.45 + 2.0, 4.0), at.basis.get_euler().y, 4.0)
		"standing_stones":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(size + 1.0, size + 1.0), at.basis.get_euler().y, 4.0)
		"watchtower":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(3.0, 3.0), at.basis.get_euler().y, 3.0)


func shapes_land() -> bool:
	return on_ground and kind in ["mist_gate", "standing_stones", "watchtower"]
