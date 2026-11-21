@tool
class_name MapVael
extends MapPiece
## A landmark of Port Vael, the drowned harbour, drawn by code (scripts/map/vael_builder.gd): the
## harbour's walls and breakwaters, its lighthouse, the wrecks and rotten piers on the seabed that the
## Mist Tide covers and uncovers, a drowned bell tower, cranes, nets, lobster pots, boats, lamps,
## rocks, buoys and a great sunken anchor. Salvage marks a sea chest on a wreck (MistTide). Coast shapes
## the shore itself: the harbour wall's line is its z, the flats run size metres out to sea, and the
## bay is wide metres either side of the middle (Terrain.set_coast).
## The Lantern Road (Last Light) adds: sea (the whole map drowned flats at this height,
## Terrain.set_sea), a road lantern (unlit until the Lantern Barge passes), and a waystation (a stone
## landing beside the road where the barge stops and a boon is chosen).

const FLATS_TOP := 0.55 # the flats' height at the foot of the harbour wall
const FLATS_LOW := -0.85 # and where they meet the open sea
const MOLE_RUN := 11.0

@export_enum("coast", "paving", "quay_wall", "mole", "lighthouse", "wreck", "boat", "upturned_boat", "crane", "net_rack", "pots", "lamp_post", "pilings", "bell_tower", "sunk_anchor", "sea_rocks", "buoy", "sea_stairs", "salvage", "sea", "road_lantern", "waystation", "slipway", "spire", "statue", "fallen_statue", "statue_head", "arch", "broken_arch", "whale_bones", "mast", "kelp_bed", "tide_pool", "brazier", "shrine", "banner", "bunting", "cargo", "fish_rack", "ghost_lights", "drystone", "garden", "lantern_string", "laundry", "bench", "chimney", "sea_trail", "porch_lamp", "ship_frame", "fishing_cutter", "rope_bench", "sail_bench", "fish_bench", "supply_rack", "signal_beacon", "salt_grass", "pass_cairn") var kind := "wreck":
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
## Optional landing on the inner side of a breakwater, measured along its local Z.
@export var landing := INF:
	set(v):
		landing = v
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
		"mole":
			VaelBuilder.mole(b, size, wide, landing)
			if is_finite(landing):
				var mole_xf := b.xf
				b.xf = _landing_at(mole_xf)
				VaelBuilder.slipway(b, MOLE_RUN, VaelBuilder.MOLE_RAMP_WIDTH, false)
				b.xf = mole_xf
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
		"road_lantern": VaelBuilder.road_lantern(b)
		"waystation": VaelBuilder.waystation(b, size)
		"slipway": VaelBuilder.slipway(b, size, wide)
		"spire": VaelDressing.spire(b, size)
		"statue": VaelDressing.statue(b, size, false)
		"fallen_statue": VaelDressing.statue(b, size, true)
		"statue_head": VaelDressing.statue_head(b, size)
		"arch": VaelDressing.arch(b, size, false)
		"broken_arch": VaelDressing.arch(b, size, true)
		"whale_bones": VaelDressing.whale_bones(b, size)
		"mast": VaelDressing.mast(b, size)
		"kelp_bed": VaelDressing.kelp_bed(b, size)
		"tide_pool": VaelDressing.tide_pool(b, size)
		"brazier": VaelDressing.brazier(b)
		"shrine": VaelDressing.shrine(b)
		"banner": VaelDressing.banner(b, size)
		"bunting": VaelDressing.bunting(b, size, wide > 0.0)
		"cargo": VaelDressing.cargo(b)
		"fish_rack": VaelDressing.fish_rack(b, size)
		"ghost_lights": VaelDressing.ghost_lights(b, size)
		"drystone": VaelDressing.drystone(b, size)
		"garden": VaelDressing.garden(b, size, wide)
		"lantern_string": VaelDressing.lantern_string(b, size, wide > 0.0)
		"laundry": VaelDressing.laundry(b, size)
		"bench": VaelDressing.bench(b)
		"chimney": VaelDressing.chimney(b, size)
		"sea_trail": VaelDressing.sea_trail(b, size)
		"porch_lamp": VaelDressing.porch_lamp(b)
		"ship_frame": VaelDressing.ship_frame(b, size)
		"fishing_cutter": VaelDressing.ship_frame(b, size, true)
		"rope_bench", "sail_bench", "fish_bench": VaelDressing.trade_bench(b, kind)
		"supply_rack": VaelDressing.supply_rack(b)
		"signal_beacon": VaelDressing.signal_beacon(b, size)
		"salt_grass": VaelDressing.salt_grass(b, size)
		"pass_cairn": VaelDressing.pass_cairn(b, size)
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
		"sea":
			t.set_sea(at.origin.y)
		"waystation":
			# A round stone landing, its top just clear of the high tide.
			t.level(c, Vector2(size * 0.5, size * 0.5), yaw, at.origin.y, 1.6)
		"mole":
			# The causeway's top, its sides falling steeply to the seabed.
			t.level(c, Vector2(wide * 0.5, size * 0.5), yaw, at.origin.y, 1.2)
			if is_finite(landing):
				var top := _landing_at(at)
				var along := top.basis.z
				var shore_ratio := inverse_lerp(float(t.coast["z"]), float(t.coast["end"]), top.origin.z)
				var floor_y := lerpf(FLATS_TOP, FLATS_LOW, clampf(shore_ratio, 0.0, 1.0))
				var foot := top.origin + along * MOLE_RUN
				foot.y = floor_y
				var ramp: Array[Vector3] = [top.origin - along * 0.6, foot, foot + along]
				t.cut(ramp, VaelBuilder.MOLE_RAMP_WIDTH * 0.5 + 0.3, 1.0)
		"sea_stairs":
			# A ramp of steps from the top of the wall down to the seabed, along +Z.
			var down := at.basis.z.normalized()
			var top := at.origin
			var foot := at.origin + down * size + Vector3(0, -wide, 0)
			var pts: Array[Vector3] = [top - down * 0.5, foot + down * 0.8]
			t.cut(pts, 1.3, 0.4)
		"slipway":
			# A broad ramp from the top of the wall (at the piece) down to the seabed `size` along +Z.
			var down := at.basis.z.normalized()
			var foot_y := float(t.coast.get("top", 0.55)) if not t.coast.is_empty() else at.origin.y - 1.6
			var pts: Array[Vector3] = [at.origin - down * 1.0, Vector3(at.origin.x, foot_y, at.origin.z) + down * (size + 0.5)]
			t.cut(pts, wide * 0.5 + 0.4, 0.8)
		"lighthouse", "bell_tower":
			t.level_auto(c, Vector2(4.5, 4.5) if kind == "lighthouse" else Vector2(2.4, 2.4), yaw, 2.0)


func _landing_at(mole_xf: Transform3D) -> Transform3D:
	return mole_xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-wide * 0.5 + 1.4, 0, landing))


func shapes_land() -> bool:
	return kind in ["coast", "mole", "sea_stairs", "lighthouse", "bell_tower", "sea", "waystation", "slipway"]


func follows_land() -> bool:
	return kind in ["wreck", "pilings", "sea_rocks", "quay_wall", "mole", "fallen_statue", "statue_head", "arch", "broken_arch", "whale_bones", "mast", "kelp_bed", "tide_pool", "ghost_lights"]
