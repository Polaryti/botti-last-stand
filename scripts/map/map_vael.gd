@tool
class_name MapVael
extends MapPiece
## A landmark of Port Vael, the drowned harbour, drawn by code (scripts/map/vael_builder.gd): the
## harbour's walls and breakwaters, its lighthouse, the wrecks and rotten piers on the seabed that the
## Mist Tide covers and uncovers, a drowned bell tower, cranes, nets, lobster pots, boats, lamps,
## rocks, buoys and a great sunken anchor. Salvage marks a sea chest on a wreck (MistTide). Coast shapes
## the shore itself: the harbour wall's line is its z, the flats run size metres out to sea, and the
## bay is wide metres either side of the middle (Terrain.set_coast).

const FLATS_TOP := 0.55 # the flats' height at the foot of the harbour wall
const FLATS_LOW := -0.85 # and where they meet the open sea

@export_enum("coast", "paving", "quay_wall", "mole", "lighthouse", "wreck", "boat", "upturned_boat", "crane", "net_rack", "pots", "lamp_post", "pilings", "bell_tower", "sunk_anchor", "sea_rocks", "buoy", "sea_stairs", "salvage") var kind := "wreck":
	set(v):
		kind = v
		refresh()
## How big it is: paving's length (along X) and wide its depth (along Z); a wall's, a mole's, a net rack's or a pier's length; a lighthouse's or a bell tower's
## or a crane's height; a wreck's or a boat's length; an anchor's size; how wide rocks spread; how far
## sea stairs run.
@export var size := 12.0:
	set(v):
		size = v
		refresh()
## A mole's width; how far sea stairs go down.
@export var wide := 6.0:
	set(v):
		wide = v
		refresh()
## A lighthouse burning (Last Light's goal, once relit).
@export var lit := false:
	set(v):
		lit = v
		refresh()


func build(b: MapBuilder) -> void:
	match kind:
		"paving": VaelBuilder.paving(b, size, wide)
		"quay_wall": VaelBuilder.quay_wall(b, size)
		"mole": VaelBuilder.mole(b, size, wide)
		"lighthouse": VaelBuilder.lighthouse(b, size, lit)
		"wreck": VaelBuilder.wreck(b, size)
		"boat": VaelBuilder.boat(b, size, false)
		"upturned_boat": VaelBuilder.boat(b, size, true)
		"crane": VaelBuilder.crane(b, size)
		"net_rack": VaelBuilder.net_rack(b, size)
		"pots": VaelBuilder.pots(b)
		"lamp_post": VaelBuilder.lamp_post(b)
		"pilings": VaelBuilder.pilings(b, size)
		"bell_tower": VaelBuilder.bell_tower(b, size)
		"sunk_anchor": VaelBuilder.sunk_anchor(b, size)
		"sea_rocks": VaelBuilder.sea_rocks(b, size)
		"buoy": VaelBuilder.buoy(b)
		"sea_stairs": VaelBuilder.sea_stairs(b, size, wide)
		"salvage":
			if not b.is_preview:
				b.w.salvage_spots.append(Transform3D(b.xf.basis, b.xf.origin))
			elif b.w.has_method("show_spot"):
				b.w.show_spot("cache", "", b.xf.origin)


func land(t: Terrain, at: Transform3D) -> void:
	var c := Vector2(at.origin.x, at.origin.z)
	var yaw := at.basis.get_euler().y
	match kind:
		"coast":
			t.set_coast(at.origin.z, at.origin.z + size, FLATS_TOP, FLATS_LOW, wide)
		"mole":
			# The causeway's top, its sides falling steeply to the seabed.
			t.level(c, Vector2(wide * 0.5, size * 0.5), yaw, at.origin.y, 1.2)
		"sea_stairs":
			# A ramp of steps from the top of the wall down to the seabed, along +Z.
			var down := at.basis.z.normalized()
			var top := at.origin
			var foot := at.origin + down * size + Vector3(0, -wide, 0)
			var pts: Array[Vector3] = [top - down * 0.5, foot + down * 0.8]
			t.cut(pts, 1.3, 0.4)
		"lighthouse", "bell_tower":
			t.level_auto(c, Vector2(4.5, 4.5) if kind == "lighthouse" else Vector2(2.4, 2.4), yaw, 2.0)


func shapes_land() -> bool:
	return kind in ["coast", "mole", "sea_stairs", "lighthouse", "bell_tower"]


func follows_land() -> bool:
	return kind in ["wreck", "pilings", "sea_rocks", "quay_wall", "mole"]
