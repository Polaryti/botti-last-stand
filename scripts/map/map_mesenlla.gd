@tool
class_name MapMesenlla
extends MapPiece
## A landmark of the lands beyond the Mists, drawn by code (scripts/map/mesenlla_builder.gd):
## islands of rock floating in the twilight, rifts torn open above the ground, a Great Portal, rings of
## standing stones, mist crystals, palisades of sharpened logs and watchtowers, waterfalls, arches of
## mossy rock, the tents, bunting and wall hangings of a makeshift outpost, the forest floor, and in
## the south the ruins of an old hall, the mouth of an old mine and the shrines of the valley folk.
## A floating island is placed at its height above the ground with lift.

@export_enum("floating_island", "rift", "mist_gate", "standing_stones", "crystals", "palisade", "watchtower", "lodge_fire", "waterfall", "arch", "tent", "bunting", "wall_banners", "undergrowth", "shrine", "ruins", "mine") var kind := "floating_island":
	set(v):
		kind = v
		refresh()
## How big it is: an island's width, a rift's length, a ring's radius, a palisade's length, a
## waterfall's drop, an arch's span, a tent's width, a string of bunting's length, the width of a wall
## hung with banners, the radius of a patch of undergrowth, the radius of a ring of ruins, the width
## of a mine's mouth.
@export var size := 10.0:
	set(v):
		size = v
		refresh()
## A waterfall's width.
@export var wide := 4.0:
	set(v):
		wide = v
		refresh()
## What a shrine gives: the stag's swiftness, the bear's strength, or the spring's healing.
@export_enum("stag", "bear", "spring") var blessing := "stag":
	set(v):
		blessing = v
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
		"crystals": MesenllaBuilder.crystals(b, size)
		"palisade": MesenllaBuilder.palisade(b, size, openings)
		"watchtower": MesenllaBuilder.watchtower(b, size)
		"lodge_fire": MesenllaBuilder.lodge_fire(b)
		"waterfall": MesenllaBuilder.waterfall(b, size, wide)
		"arch": MesenllaBuilder.arch(b, size)
		"tent": MesenllaBuilder.tent(b, size)
		"bunting": MesenllaBuilder.bunting(b, size)
		"wall_banners": MesenllaBuilder.wall_banners(b, size)
		"undergrowth": MesenllaBuilder.undergrowth(b, size)
		"shrine": MesenllaBuilder.shrine(b, blessing)
		"ruins": MesenllaBuilder.ruins(b, size)
		"mine": MesenllaBuilder.mine(b, size)


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
		"tent":
			t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(size + 1.0, size * 1.2 + 1.0), at.basis.get_euler().y, 2.0)


func shapes_land() -> bool:
	return on_ground and kind in ["mist_gate", "standing_stones", "watchtower", "tent"]
