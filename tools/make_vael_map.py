#!/usr/bin/env python3
"""Writes maps/vael.tscn: Port Vael, the drowned harbour of "The Sunken Crown" (0.23).

    python3 tools/make_vael_map.py          (from the project root)

The map is laid out here in code, so it can be read and changed in one place, then opened and moved
about in the Godot editor like any other map. North is -Z.

  The upper town (z -95..-22, 5 m up): streets of slate-roofed houses, the market square with its
  well, the chapel, and the Harbourmaster's house.
  The quay (z -16..6, 2.2 m up): warehouses, cranes, lamps, nets, crates and barrels, and the harbour
  wall along z = 6, with stairs down at x = -30 and x = 30.
  The flats (z 6..80): the seabed the Mist Tide covers and uncovers (MistTide), sloping down from the
  wall to the open sea, with three wrecks, a drowned bell tower, the stumps of two piers, rocks,
  buoys and a sunken anchor. Each wreck keeps a sea chest (salvage).
  The moles: two stone breakwaters reaching out from the quay round the flats, the lighthouse at the
  end of the east one.
  The headlands (|x| > 82): high ground and pines either side of the bay.
"""
import math

OUT = "maps/vael.tscn"

SCRIPTS = [
    ("map_root", "root"), ("map_level", "level"), ("map_hill", "hill"), ("map_road", "road"),
    ("map_vael", "vael"), ("map_house", "house"), ("map_spot", "spot"), ("map_thing", "thing"),
    ("map_prop", "prop"), ("map_tree", "tree"),
]

SLATE = "Color(0.26, 0.29, 0.33, 1)"
SLATE_B = "Color(0.3, 0.27, 0.27, 1)"
WHITEWASH = "Color(0.66, 0.67, 0.64, 1)"
WHITEWASH_B = "Color(0.58, 0.6, 0.6, 1)"
STONE = "Color(0.47, 0.46, 0.44, 1)"
TIMBER = "Color(0.42, 0.3, 0.2, 1)"

nodes = []
curves = []
names = {}


def uniq(base):
    names[base] = names.get(base, 0) + 1
    return base if names[base] == 1 else "%s%d" % (base, names[base])


def xf(x, y, z, yaw_deg=0.0):
    a = math.radians(yaw_deg)
    c, s = math.cos(a), math.sin(a)
    r = lambda v: ("%.5f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"
    return "Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)" % (r(c), r(-s), r(s), r(c), r(x), r(y), r(z))


def node(name, parent, script, at=None, **props):
    name = uniq(name)
    lines = ['[node name="%s" type="Node3D" parent="%s"]' % (name, parent)]
    if at is not None:
        lines.append("transform = " + xf(*at))
    lines.append('script = ExtResource("%s")' % script)
    for k, v in props.items():
        if isinstance(v, bool):
            v = "true" if v else "false"
        elif isinstance(v, str) and not v.startswith(("Color(", "Vector2(", "Vector3(")):
            v = '"%s"' % v
        lines.append("%s = %s" % (k, v))
    nodes.append("\n".join(lines))
    return name if parent == "." else parent + "/" + name


def group(name, parent="."):
    name = uniq(name)
    nodes.append('[node name="%s" type="Node3D" parent="%s"]' % (name, parent))
    return name if parent == "." else parent + "/" + name


def road(name, parent, points, width, cut=False, draw=True, blend=None):
    cid = "Curve_%d" % (len(curves) + 1)
    flat = ", ".join("0, 0, 0, 0, 0, 0, %s, %s, %s" % (p[0], p[1], p[2]) for p in points)
    curves.append('[sub_resource type="Curve3D" id="%s"]\n_data = {\n"points": PackedVector3Array(%s),\n"tilts": PackedFloat32Array(%s)\n}\npoint_count = %d'
                  % (cid, flat, ", ".join("0" for _ in points), len(points)))
    lines = ['[node name="%s" type="Path3D" parent="%s"]' % (uniq(name), parent), 'script = ExtResource("road")', 'curve = SubResource("%s")' % cid]
    lines.append("width = %s" % width)
    if cut:
        lines.append("cut = true")
    if not draw:
        lines.append("draw = false")
    if blend is not None:
        lines.append("cut_blend = %s" % blend)
    nodes.append("\n".join(lines))


def spot(parent, kind, at, text=None, on_ground=True):
    props = {"kind": kind}
    if text:
        props["text"] = text
    if not on_ground:
        props["on_ground"] = False
    node(kind.capitalize(), parent, "spot", at, **props)


# --- The land ------------------------------------------------------------------------------------
land = group("Land")
# The shore: the land falls to the seabed south of the harbour wall (z = 6) and to the open sea
# beyond z = 82; either side of the bay the headlands stand (see MapVael "coast").
node("Coast", land, "vael", (0, 0, 6), kind="coast", size=76.0, wide=96.0, on_ground=False)
node("UpperTown", land, "level", (0, 5.0, -58), size="Vector2(196, 72)", blend=6.0)
# Two graded terraces fill the hollow between the waterfront and the upper town.
node("LowerTerrace", land, "level", (0, 2.9, -17.9), size="Vector2(174, 4)", blend=2.0)
node("UpperTerrace", land, "level", (0, 4.1, -21.7), size="Vector2(174, 4)", blend=2.0)
node("Quayside", land, "level", (0, 2.2, -5), size="Vector2(176, 22)", blend=2.0)
node("HeadlandWest", land, "hill", (-104, 0, 34), height=11.0, radius=20.0)
node("HeadlandEast", land, "hill", (104, 0, 28), height=13.0, radius=20.0)
node("HillNorthWest", land, "hill", (-92, 0, -88), height=7.0, radius=22.0)
node("HillNorthEast", land, "hill", (90, 0, -92), height=8.0, radius=22.0)
node("WestCliff", land, "hill", (-108, 0, -44), height=12.0, radius=16.0)
node("EastCliff", land, "hill", (109, 0, -28), height=10.0, radius=15.0)
node("GullwatchTerrace", land, "level", (-91, 7.1, -57), size="Vector2(14, 15)", blend=4.0)
node("PilgrimTerrace", land, "level", (77, 5.0, -82), size="Vector2(17, 14)", blend=3.0)
node("SaltHouseGround", land, "level", (74, 2.2, -11), size="Vector2(19, 11)", blend=1.8)
# The cut between these two spurs is the last turn of the mountain road into Vael.
for x, z, height, radius in [(-28, -113, 18.0, 15.0), (31, -119, 22.0, 18.0),
                            (-51, -129, 13.0, 20.0), (54, -134, 19.0, 22.0),
                            (-16, -101, 5.5, 9.0), (18, -107, 6.8, 11.0)]:
    node("MountainSpur", land, "hill", (x, 0, z), height=height, radius=radius)

# --- Roads ---------------------------------------------------------------------------------------
roads = group("Roads")
road("HarbourStreet", roads, [(0, 2.2, -10), (0, 3.4, -18), (0, 5.0, -27), (0, 5.0, -44)], 5.0, cut=True)
road("QuayStreet", roads, [(-80, 2.2, -4), (80, 2.2, -4)], 6.0)
road("MarketRow", roads, [(-86, 5.0, -52), (86, 5.0, -52)], 5.0)
valley_road = [(8, 5.0, -54), (7, 5.0, -68), (12, 5.0, -78), (13, 5.15, -86),
               (10, 6.6, -91), (4, 8.9, -95), (-2, 11.7, -100), (-6, 14.6, -108),
               (2, 18.4, -120), (15, 21.8, -134)]
road("ValleyRoad", roads, valley_road, 6.0, cut=True, blend=3.6)
# The arch opening runs along the road, and its foot is sampled from the road itself.
gate_downhill, gate_uphill = valley_road[4:6]
# Widen the cut only at the gate, leaving both stone feet on a proper shoulder.
road("GateShoulders", roads, [gate_downhill, gate_uphill], 8.6, cut=True, draw=False, blend=3.1)
gate_x = (gate_downhill[0] + gate_uphill[0]) * 0.5
gate_z = (gate_downhill[2] + gate_uphill[2]) * 0.5
gate_yaw = math.degrees(math.atan2(gate_downhill[0] - gate_uphill[0], gate_downhill[2] - gate_uphill[2]))
road("ChapelLane", roads, [(-40, 5.0, -52), (-40, 5.0, -84)], 4.0)
road("HillLane", roads, [(40, 5.0, -52), (40, 5.0, -86)], 4.0)
road("WestSteps", roads, [(-62, 2.2, -12), (-62, 3.6, -19), (-62, 5.0, -27)], 4.6, cut=True, blend=2.0)
road("EastSteps", roads, [(62, 2.2, -12), (62, 3.6, -19), (62, 5.0, -27)], 4.6, cut=True)
# Two long ways around town. The shoulder roads meet its streets instead of ending in the woods.
road("WestCliffPath", roads, [(-70, 2.2, -3), (-85, 2.5, -7), (-91, 4.2, -21),
                            (-89, 5.4, -39), (-89, 7.1, -53), (-85, 6.0, -70),
                            (-73, 5.2, -87), (-68, 5.0, -91), (-40, 5.0, -91)], 4.8, cut=True, blend=3.0)
road("NorthLane", roads, [(-40, 5.0, -91), (-24, 5.0, -89), (-14, 5.0, -89), (0, 5.0, -86), (12.4, 5.35, -87)], 4.2, cut=True)
road("EastHeadlandPath", roads, [(79, 2.2, -3), (88, 2.35, -9), (91, 3.5, -21), (90, 4.6, -36),
                                (88, 5.0, -51), (89, 5.0, -67), (85, 5.0, -78),
                                (77, 5.0, -81), (66, 5.0, -76), (49, 5.0, -71)], 4.8, cut=True, blend=3.0)
road("WatchCrossing", roads, [(-90, 7.1, -53), (-78, 5.0, -52)], 4.2, cut=True, blend=2.8)

# --- The harbour ---------------------------------------------------------------------------------
harbour = group("Harbour")
# The harbour wall, in lengths with ways down between them: stairs at x = -55, -30, 30 and 55, and
# two broad slipways either side of the middle, so whatever the tide brings in can always get up.
WALL_ENDS = (-79.0, 79.0)
WAYS = [(-55.0, "stairs"), (-30.0, "stairs"), (-12.0, "slip"), (12.0, "slip"), (30.0, "stairs"), (55.0, "stairs")]
GAP = {"stairs": 1.7, "slip": 3.6}
edges = [WALL_ENDS[0]]
for (x, k) in WAYS:
    edges += [x - GAP[k], x + GAP[k]]
edges.append(WALL_ENDS[1])
for i in range(0, len(edges), 2):
    a, b = edges[i], edges[i + 1]
    node("Wall", harbour, "vael", ((a + b) * 0.5, 2.2, 6), kind="quay_wall", size=round(b - a, 2), on_ground=False)
for (x, k) in WAYS:
    if k == "stairs":
        node("SeaStairs", harbour, "vael", (x, 2.2, 6.2), kind="sea_stairs", size=6.0, wide=1.6, on_ground=False)
    else:
        node("Slipway", harbour, "vael", (x, 2.2, 6.0), kind="slipway", size=10.0, wide=6.0, on_ground=False)
# The breakwaters and the lighthouse.
node("WestMole", harbour, "vael", (-84, 2.0, 40, 180), kind="mole", size=68.0, wide=7.0, landing=6.0, on_ground=False) # its parapet to the sea
node("EastMole", harbour, "vael", (84, 2.0, 40), kind="mole", size=68.0, wide=7.0, landing=-6.0, on_ground=False)
node("Lighthouse", harbour, "vael", (84, 2.0, 70), kind="lighthouse", size=17.0, on_ground=False)
for z in (18, 27, 50):
    node("MoleLamp", harbour, "vael", (-81.5, 2.0, z), kind="lamp_post", on_ground=False)
    node("MoleLamp", harbour, "vael", (81.5, 2.0, z, 180), kind="lamp_post", on_ground=False)

# --- The quay ------------------------------------------------------------------------------------
quay = group("Quay")
node("QuayPaving", quay, "vael", (0, 2.2, -1), kind="paving", size=170.0, wide=14.0, on_ground=False)
for i, (x, w) in enumerate([(-48.5, 16.0), (-20, 14.0), (26, 16.0)]):
    node("WarehouseFloor", land, "level", (x, 2.2, -12), size=f"Vector2({w + 1.2}, 9.6)", blend=1.6)
    house = node(("Ropewalk", "SailLoft", "BondedStore")[i], quay, "house", (x, 2.2, -12), width=w, depth=8.0, height=4.4, ridge="x", roof_rise=2.4,
                 walls=STONE, roof=SLATE, beams=True, south="door:-3:3.6:3.6, window:3", north="window:-3, window:3",
                 east="door:0:3.4:3.2", level_ground=False)
    spot(house, "loot", (-2.5, 0, 1.0), on_ground=False)
    node("Crate", house, "prop", (2.6, 0, -2.2), kind="crate_big", on_ground=False)
    node("Crate", house, "prop", (3.6, 0, -1.2, 30), kind="crate_small", on_ground=False)
    node("Barrel", house, "prop", (-5.0, 0, -2.4), kind="barrel", on_ground=False)
    node("Barrel", house, "prop", (-5.8, 0, -1.4), kind="barrel", on_ground=False)
    node("Sack", house, "prop", (0.5, 0, -2.6), kind="sack", on_ground=False)
    node("TradeStation", house, "vael", (-2.5, 0, -2.85), kind=("rope_bench", "sail_bench", "rope_bench")[i], on_ground=False)
    node("WorkLamp", house, "vael", (-5.4, 0, 3.0), kind="porch_lamp", on_ground=False)
for x in (-35.0, 21.0, 48.0):
    node("Crane", quay, "vael", (x, 2.2, 3.4), kind="crane", size=6.5, on_ground=False)
for x in range(-72, 80, 16):
    node("QuayLamp", quay, "vael", (x, 2.2, 4.2, 180), kind="lamp_post", on_ground=False)
node("Nets", quay, "vael", (60, 2.2, -10), kind="net_rack", size=10.0, on_ground=False)
node("Nets", quay, "vael", (-66, 2.2, -11, 90), kind="net_rack", size=5.5, on_ground=False)
node("ShipOnStocks", quay, "vael", (-77, 2.2, -10.5, -8), kind="ship_frame", size=10.0, on_ground=False)
node("ShipyardTimber", quay, "prop", (-74, 2.2, -5.2, 15), kind="lumber_small", on_ground=False)
node("ShipyardTools", quay, "vael", (-80, 2.2, -6.4, 90), kind="rope_bench", on_ground=False)
node("FishStall", quay, "thing", (54, 2.2, -6.5, -90), kind="stall_blue", on_ground=False)
node("FishStall", quay, "thing", (49, 2.2, -9.5, -90), kind="stall_red", on_ground=False)
node("FishSortingTable", quay, "vael", (54, 2.2, -10.6), kind="fish_bench", on_ground=False)
node("FishSortingTable", quay, "vael", (48, 2.2, -4.8, 90), kind="fish_bench", on_ground=False)
salt = node("SaltHouse", quay, "house", (74, 2.2, -10.5), width=9.0, depth=8.0, height=3.6, ridge="z", roof_rise=2.3,
            walls=STONE, roof=SLATE_B, south="door:0:3.2:3.3", east="door:0:3.2:3.0",
            north="slit:-2.2, slit:2.2", west="slit:0", level_ground=False)
node("SaltRacks", salt, "vael", (0, 0, -2.6), kind="fish_bench", on_ground=False)
node("SaltSacks", salt, "prop", (-2.5, 0, -1.6), kind="sack", on_ground=False)
node("SaltBarrel", salt, "prop", (-3, 0, 2.0), kind="barrel", on_ground=False)
spot(salt, "loot", (-1.7, 0, 0.6), on_ground=False)
spot(quay, "loot", (53, 2.2, -3))
spot(quay, "loot", (-72, 2.2, -6.5))
spot(quay, "loot", (80, 2.2, -7))
for (x, z) in [(-8, 1.0), (38, -1.0), (-62, 1.5), (68, 0.5)]:
    node("Pots", quay, "vael", (x, 2.2, z, x * 7 % 180), kind="pots", on_ground=False)
for (x, z, k) in [(-44, 1.5, "barrel"), (-43, 2.6, "barrel"), (-41, 1.2, "crate_big"), (5, 1.6, "crate_long"), (6.5, -0.2, "crate_small"),
                  (16, 0.5, "barrel"), (33, 1.8, "sack"), (34, 0.9, "sack"), (52, 2.4, "crate_big"), (-14, -0.5, "wheelbarrow"),
                  (-25, 2.4, "lumber"), (22, -8.5, "barrel"), (-4, -8.0, "crate_small")]:
    node("QuayProp", quay, "prop", (x, 2.2, z, x * 13 % 360), kind=k, on_ground=False)
node("Boat", quay, "vael", (-76, 2.2, 0, 80), kind="upturned_boat", size=4.6, on_ground=False)
node("Cart", quay, "thing", (-10, 2.2, -8, 75), kind="cart", on_ground=False)
for x in (-60, -30, 0, 30, 60):
    spot(quay, "loot", (x + 4, 2.2, -1))
for i, (x, z) in enumerate([(0, -2), (-8, -1), (8, -1), (-4, 1), (4, 1)]):
    spot(quay, "start", (x, 2.2, z))

# --- The upper town ------------------------------------------------------------------------------
town = group("Town")
houses = [
    (-74, -36, 9, 7, "s"), (-60, -36, 8, 7, "s"), (-24, -36, 9, 8, "s"), (-12, -37, 7, 7, "s"), (14, -36, 8, 7, "s"),
    (52, -36, 10, 7, "s"), (70, -36, 8, 7, "s"),
    (-74, -66, 9, 7, "n"), (-58, -66, 8, 8, "n"), (-22, -66, 8, 7, "n"), (-10, -67, 7, 7, "n"), (18, -66, 9, 7, "n"),
    (54, -66, 8, 7, "n"), (70, -67, 9, 8, "n"),
    (-56, -84, 10, 7, "s"), (20, -84, 8, 7, "s"), (58, -84, 9, 7, "s"),
]
for i, (x, z, w, d, door) in enumerate(houses):
    walls = WHITEWASH if i % 3 else WHITEWASH_B
    roof = SLATE if i % 2 else SLATE_B
    rear = "door:0:2.8:2.7, window:2.5" if i in (0, 2, 5, 7, 11, 14) else "window:0"
    h = node("House", town, "house", (x, 5.0, z, (i * 37) % 7 - 3), width=float(w), depth=float(d), height=3.2, ridge="x", roof_rise=2.3,
             walls=walls, roof=roof, beams=i % 4 == 0, south="door:0:2.8:2.7, window:-2.5" if door == "s" else rear,
             north="door:0:2.8:2.7, window:2.5" if door == "n" else rear, east="window:0", west="window:0")
    if i % 3 != 1:
        spot(h, "loot", (-1.35, 0, 0.45), on_ground=False)
    if i in (0, 4, 7, 11):
        node("TradeStation", h, "vael", (2.0, 0, -1.55), kind=("rope_bench" if i < 7 else "sail_bench"), on_ground=False)
        node("Reel", h, "prop", (2.5, 0, 1.3), kind="bucket", on_ground=False)
    elif i % 2 == 0:
        node("Table", h, "thing", (1.8, 0, -1.2), kind="table", on_ground=False)
    else:
        node("Bed", h, "thing", (-2.0, 0, -1.6), kind="bed", on_ground=False)
        node("Barrel", h, "prop", (min(w * 0.5 - 1.1, 2.6), 0, 1.6), kind="barrel", on_ground=False)
    if i in (0, 2, 5, 7, 11, 14):
        side = -1.0 if door == "s" else 1.0
        node("BackDoorLamp", h, "vael", (1.9, 0, side * d * 0.5, 180.0 if side < 0 else 0.0),
             kind="porch_lamp", on_ground=False)
# The chapel: tall, with a bell in its gable; the Harbourmaster's house, big and stone.
chapel = node("Chapel", town, "house", (-40, 5.0, -76), width=10.0, depth=16.0, height=6.0, ridge="z", roof_rise=4.0,
              walls=STONE, roof=SLATE, beams=False, south="door:0:3.2:3.6", east="slit:-4, door:1:3.0:3.4, slit:5", west="slit:-4, slit:0, slit:4", north="window:0")
spot(chapel, "loot", (0, 0, -5), on_ground=False)
spot(chapel, "loot", (1.36, 0, 3), on_ground=False)
for x in (-3.0, 3.0):
    for z in (-4.0, -1.6, 3.1):
        node("ChapelPew", chapel, "vael", (x, 0, z, 180), kind="bench", on_ground=False)
node("ChapelAltar", chapel, "thing", (0, 0, -6.3), kind="table", on_ground=False)
node("ChapelCandle", chapel, "vael", (0, 0, -7.6, 180), kind="porch_lamp", on_ground=False)
hm = node("HarbourmastersHouse", town, "house", (40, 5.0, -76), width=13.0, depth=10.0, height=4.0, ridge="x", roof_rise=2.8,
          walls=STONE, roof=SLATE, beams=False, south="door:0:3.2:3.0, window:-4, window:4", north="window:-3, door:0:3.0:3.0, window:3", east="window:0", west="window:0")
spot(hm, "loot", (-2.1, 0, 1.1), on_ground=False)
spot(hm, "loot", (3.2, 0, 1.5), on_ground=False)
node("LedgerTable", hm, "vael", (3.6, 0, -2.8, 180), kind="sail_bench", on_ground=False)
node("LockedCrates", hm, "prop", (-4.2, 0, -2.7), kind="crate_long", on_ground=False)
node("HouseBench", hm, "vael", (4.4, 0, 3.0, 180), kind="bench", on_ground=False)
# The market square.
node("SquarePaving", town, "vael", (0, 5.0, -52), kind="paving", size=34.0, wide=20.0, on_ground=False)
node("Well", town, "thing", (0, 5.0, -52), kind="well", on_ground=False)
node("Stall", town, "thing", (-10, 5.0, -47, 10), kind="stall_blue", on_ground=False)
node("Stall", town, "thing", (10, 5.0, -47, -10), kind="stall_red", on_ground=False)
node("Stall", town, "thing", (-9, 5.0, -58, 170), kind="stall_red", on_ground=False)
for (x, z) in [(-30, -46), (30, -46), (-30, -58), (30, -58), (-66, -52), (66, -52), (0, -30)]:
    node("TownLamp", town, "vael", (x, 5.0, z), kind="lamp_post", on_ground=False)
for (x, z, k) in [(-6, -45, "barrel"), (7, -44, "crate_small"), (12, -58, "sack"), (-14, -55, "crate_big")]:
    node("MarketProp", town, "prop", (x, 5.0, z, x * 17 % 360), kind=k, on_ground=False)
for (x, z) in [(-80, -50), (-48, -54), (-20, -50), (20, -54), (48, -50), (80, -54), (-30, -88), (36, -92), (0, -70), (-66, -78), (66, -78)]:
    spot(town, "loot", (x, 5.0, z))
for (x, z, k, s) in [(-86, -44, "mossy_oak", 6.5), (86, -46, "tall_pine", 6.0), (-4, -86, "mossy_oak", 7.0), (30, -40, "tall_pine", 5.5), (-30, -40, "mossy_oak", 6.0)]:
    node("Tree", town, "tree", (x, 5.0, z), kind=k, size=s)
# Cliffs, woodland walks and hand-placed banks of salt grass outside the streets.
nature = group("Nature")
for x, z, r in [(-49, -107, 23), (44, -110, 26), (-105, -68, 16), (105, -58, 18)]:
    node("CoastalRidge", land, "hill", (x, 0, z), height=7.0, radius=float(r))
for cx, cz in [(-95, -8), (-98, -25), (-98, -42), (-98, -70), (-73, -96), (-52, -98), (-30, -98),
               (30, -96), (53, -97), (77, -96), (97, -72), (97, -48), (97, -31), (97, -12), (-96, 13), (96, 15)]:
    for i, (dx, dz, height) in enumerate([(-2.5, -3, 8.4), (0.7, 2, 9.8), (3.5, -1, 7.3)]):
        node("Windbreak", nature, "tree", (cx + dx, 0, cz + dz, cx * 13 + i * 39),
             kind="giant_fir" if i == 1 else "tall_pine", size=height, tall=1.07)
for x, z in [(-95, -54), (-92, -59), (71, -81), (81, -79), (-94, -41), (-93, -66), (-90, 2), (-92, 21), (93, -37), (95, -59), (96, -13),
             (-57, -93), (-24, -92), (27, -90), (60, -92), (83, -87), (81, -75),
             (-59, -29), (-41, -30), (-20, -27), (21, -28), (47, -30), (68, -26)]:
    node("CoastalGrasses", nature, "vael", (x, 0, z), kind="salt_grass", size=3.6)
for x, z, size in [(-96, -31, 1.45), (-97, -49, 2.1), (-95, -77, 1.4), (-57, -95, 1.35),
                   (95, -54, 1.9), (96, -38, 1.3), (96, 4, 1.7), (65, -94, 1.6), (94, 28, 1.75), (-96, 32, 1.4)]:
    node("StormBoulder", nature, "prop", (x, 0, z), kind="rock", grow=size)
# Old retaining walls follow the outside of the turns, clear of both traffic and gardens.
for x, z, yaw, length in [(17.6, -89, 82, 5.0), (5.7, -88.9, 137, 4.7)]:
    node("RoadWall", nature, "vael", (x, 0, z, yaw), kind="drystone", size=length)
node("OldValleyGate", nature, "vael", (gate_x, 0, gate_z, gate_yaw), kind="arch", size=8.4)
for x, z, grow in [(-12.3, -98, 1.8), (-9, -101, 2.4), (13.7, -97.5, 1.7), (18, -95, 1.45)]:
    node("PassOutcrop", nature, "prop", (x, 0, z), kind="rock", grow=grow, lift=-0.35)
for x, z, size in [(-11, -96, 2.2), (-6.8, -92.4, 2.1), (11, -97, 2.7), (20, -96, 2.4)]:
    node("PassGrass", nature, "vael", (x, 0, z), kind="salt_grass", size=size)
for x, z in [(8, -76), (-0.8, -94.6), (18.5, -90), (-96, -54), (-84, -55), (-91, -34), (87, -49), (85, -73)]:
    node("RoadLamp", nature, "vael", (x, 0, z), kind="lamp_post")

# Gullwatch was the fleet's signal post. Pilgrims' Garden kept a sheltered stop on the coast road.
landmarks = group("Districts")
node("SignalBeacon", landmarks, "vael", (-94, 0, -55, 90), kind="signal_beacon", size=6.0)
for x, z, yaw, length in [(-96, -59, 90, 8.0), (-94, -62, 0, 5.0),
                          (75, -87, 0, 9.0), (70, -84, 90, 6.0), (81, -86, 90, 3.0)]:
    node("ShelterWall", landmarks, "vael", (x, 0, z, yaw), kind="drystone", size=length)
node("LookoutBench", landmarks, "vael", (-92.5, 0, -61, 180), kind="bench")
node("Shrine", landmarks, "vael", (74, 0, -85, 0), kind="shrine")
node("CoastalGarden", landmarks, "vael", (78.5, 0, -83.2), kind="garden", size=5.2, wide=3.2)
node("PilgrimBench", landmarks, "vael", (72, 0, -83, -90), kind="bench")
node("MileAnchor", landmarks, "vael", (92, 0, -42, -30), kind="sunk_anchor", size=2.7)
node("Memorial", landmarks, "thing", (-27, 0, -92.5), kind="grave_stone")
node("ValleyStones", landmarks, "vael", (-15, 0, -94.5), kind="drystone", size=6.5)
node("ValleyBench", landmarks, "vael", (-18, 0, -92.4), kind="bench")
node("Cairn", landmarks, "vael", (5.8, 0, -99.0, 40), kind="pass_cairn", size=1.75)
node("Cairn", landmarks, "vael", (17.1, 0, -92.2, -30), kind="pass_cairn", size=1.2)
node("PassCart", landmarks, "thing", (-9.2, 0, -93.1, 14), kind="cart")
node("CartCargo", landmarks, "prop", (-8.6, 0, -89.9, 20), kind="sack")
node("CartCargo", landmarks, "prop", (-11.8, 0, -90.8, -28), kind="lumber_small")
# Open supply racks mark rare finds. The pickups have dedicated clear cells in front of the racks.
for x, z, yaw, dx, dz in [(-94, -58, 90, 2, 0), (77.5, -86, 0, 0, 2.1),
                           (-17, -91.8, 0, 0, 2.1), (37.1, -78.0, 0, 0, 2.1)]:
    node("SupplyRack", landmarks, "vael", (x, 0, z, yaw), kind="supply_rack")
    spot(landmarks, "cache", (x + dx, 0, z + dz))

# Three circuits for the creatures: the sea approaches, the town back streets and the headland lanes.
entries = group("EnemyApproaches")
for x, z in [
    (-73, 17), (-64, 31), (-55, 46), (-27, 31), (-16, 21), (3, 44), (7, 69),
    (24, 34), (44, 28), (57, 59), (69, 38), (72, 16), (-39, 74), (33, 74),
    (-86, -10), (-87, -29), (-84, -58), (-79, -78), (-50, -90), (-32, -88), (-6, -87), (8.6, -92),
    (30, -87), (63, -89), (82, -79), (87, -65), (88, -47), (84, -27), (82, -9),
    (-75, -43), (-39, -46), (-29, -58), (16, -57), (38, -47), (71, -49),
]:
    spot(entries, "vael_spawn", (x, 0, z))
for x, z in [(-91, -46), (-82, -57), (-51.5, -89.2), (-17, -86), (27, -85), (74, -77), (88, -61),
             (88, -28), (-83, -19), (80, -17), (-83.5, 42), (81, 45)]:
    spot(landmarks, "loot", (x, 0, z))
for x, z in [(-91, -53), (-81, -74), (-28, -89), (80, -79), (88, -48), (-74, -6), (54, -3)]:
    spot(landmarks, "poi", (x, 0, z))

# --- The flats -----------------------------------------------------------------------------------
flats = group("Flats")
wrecks = [((-22, 0, 46, 20), 20.0), ((30, 0, 58, -35), 16.0), ((-48, 0, 68, 70), 12.0)]
for (at, length) in wrecks:
    w = node("Wreck", flats, "vael", at, kind="wreck", size=length)
    # The sea chest, in her hold, under her broken deck: in through the hole in her side.
    node("Salvage", w, "vael", (0.0, 0.0, 0.0), kind="salvage")
node("DrownedBell", flats, "vael", (8, 0, 30), kind="bell_tower", size=11.0)
node("Salvage", flats, "vael", (8, 0, 25.5, 180), kind="salvage")
node("OldPierWest", flats, "vael", (-10, 0, 9), kind="pilings", size=30.0)
node("OldPierEast", flats, "vael", (46, 0, 9), kind="pilings", size=22.0)
node("SunkAnchor", flats, "vael", (36, 0, 32, 30), kind="sunk_anchor", size=3.2)
for (x, z, s) in [(-50, 30, 4.0), (54, 22, 3.5), (-6, 70, 5.0), (16, 46, 3.0), (-36, 18, 3.0), (60, 64, 4.0), (-68, 52, 3.5)]:
    node("SeaRocks", flats, "vael", (x, 0, z, x * 11 % 360), kind="sea_rocks", size=s)
for (x, z) in [(-30, 28), (18, 74), (48, 44), (-60, 74)]:
    node("Buoy", flats, "vael", (x, 0, z, x * 23 % 360), kind="buoy")
node("StrandedCutter", flats, "vael", (66, 0, 14, 25), kind="fishing_cutter", size=7.5)
node("Boat", flats, "vael", (20, 0, 14, 40), kind="boat", size=4.2)
node("Boat", flats, "vael", (-56, 0, 12, -30), kind="upturned_boat", size=4.0)
for (x, z) in [(-40, 40), (-8, 58), (20, 38), (44, 70), (-30, 74), (0, 16), (-64, 28), (64, 34)]:
    spot(flats, "loot", (x, 0, z))
for (x, z) in [(-20, 30), (20, 50), (0, 66), (-50, 50), (50, 50)]:
    spot(flats, "poi", (x, 0, z))
for (x, z) in [(-40, -60), (40, -60), (0, -40), (-60, -20), (60, -20), (-70, -80), (70, -80)]:
    spot(town, "poi", (x, 5.0, z))

# --- What makes it Vael ----------------------------------------------------------------------------
dress = group("Dressing")
# The Tide King at the head of Harbour Street, looking out to sea, braziers either side.
node("TideKing", dress, "vael", (0, 5.0, -39), kind="statue", size=4.5, on_ground=False)
for x in (-3.4, 3.4):
    node("Brazier", dress, "vael", (x, 5.0, -36.5), kind="brazier", on_ground=False)
# Fires along the quay and in the square.
for (x, y, z) in [(-24, 2.2, 3.0), (36, 2.2, 3.0), (-66, 2.2, 2.4), (66, 2.2, 2.4), (-13, 5.0, -63), (13, 5.0, -63), (-83, 2.0, 71), (81, 2.0, 66)]:
    node("Brazier", dress, "vael", (x, y, z), kind="brazier", on_ground=False)
# Banners of Vael.
for (x, y, z, yaw) in [(-40, 2.2, 4.6, 0), (40, 2.2, 4.6, 0), (0, 2.2, 4.4, 0), (-16, 5.0, -44, 0), (16, 5.0, -44, 0), (-16, 5.0, -60, 180), (16, 5.0, -60, 180),
                       (-44, 5.0, -66.5, 0), (-36, 5.0, -66.5, 0), (-84, 2.0, 8, 0), (84, 2.0, 8, 0)]:
    node("Banner", dress, "vael", (x, y, z, yaw), kind="banner", size=5.5, on_ground=False)
# Bunting over the streets and the quay.
for (x, y, z, yaw, length) in [(-20, 5.0, -52, 90, 8.0), (20, 5.0, -52, 90, 8.0), (0, 5.0, -31, 0, 7.0), (-50, 2.2, -2, 0, 10.0), (50, 2.2, -2, 0, 10.0)]:
    node("Bunting", dress, "vael", (x, y, z, yaw), kind="bunting", size=length, wide=1.0, on_ground=False)
# Cargo, and fish drying.
for (x, z, yaw) in [(-9, -13.5, 0), (10, -13.5, 180), (-59, -9, 90), (68, -13, -90), (-23, -3.6, 10)]:
    node("Cargo", dress, "vael", (x, 2.2, z, yaw), kind="cargo", on_ground=False)
for (x, z, yaw) in [(-60, 2.2, 0), (44, -14.0, 0), (-82, -4.5, 90)]:
    node("FishRack", dress, "vael", (x, 2.2, z, yaw), kind="fish_rack", size=4.0, on_ground=False)
# Shrines of the Tide.
for (x, y, z, yaw) in [(-40, 5.0, -60, 90), (40, 5.0, -60, -90), (-79, 2.0, 10, 90), (79, 2.0, 10, -90), (-62, 5.0, -29, 0), (64, 5.0, -29, 0)]:
    node("Shrine", dress, "vael", (x, y, z, yaw), kind="shrine", on_ground=False)
# On the seabed: a fallen king, the gates of old Vael, a whale, masts of ships, kelp and pools.
node("FallenKing", dress, "vael", (-38, 0, 56, 30), kind="fallen_statue", size=5.0)
node("SeaGate", dress, "vael", (-62, 0, 40, -30), kind="arch", size=7.0)
node("BrokenGate", dress, "vael", (14, 0, 64, 20), kind="broken_arch", size=8.0)
node("WhaleBones", dress, "vael", (52, 0, 48, 70), kind="whale_bones", size=12.0)
for (x, z, h) in [(-8, 78, 8.0), (64, 78, 10.0), (-68, 26, 7.0)]:
    node("Mast", dress, "vael", (x, 0, z, x * 7 % 360), kind="mast", size=h)
for (x, z, r) in [(-14, 36, 4.0), (24, 24, 3.5), (-52, 58, 4.0), (40, 70, 4.0), (2, 50, 3.0), (70, 40, 3.0)]:
    node("Kelp", dress, "vael", (x, 0, z), kind="kelp_bed", size=r)
for (x, z, r) in [(-62, 16, 2.2), (-26, 22, 2.0), (58, 30, 2.4), (32, 16, 1.8)]:
    node("TidePool", dress, "vael", (x, 0, z), kind="tide_pool", size=r)
node("DrownedHead", dress, "vael", (-72, 0, 80), kind="statue_head", size=2.2)
# Slabs mark the drowned road from the eastern slipway toward the bell. Keep crossings open.
for x, z, yaw in [(17, 19, -14), (16, 22, -13), (14, 25, -27), (13, 28, -24), (12, 31, -19),
                  (13, 35, 18), (15, 38, 23), (16, 41, 12)]:
    node("DrownedRoad", dress, "vael", (x, 0, z, yaw + 90), kind="paving", size=2.0, wide=2.7)
for x, z, yaw in [(-70, 21, 62), (65, 56, -24), (-15, 59, 40)]:
    node("BrokenSeaWall", dress, "vael", (x, 0, z, yaw), kind="drystone", size=5.0)
# The town lived in: every house with its chimney smoking and a lamp by the door, a bench, and behind
# it a garden, a washing line or a boat laid up for mending; paved streets; a drystone wall along the
# brow above the quay and paper lanterns strung over Market Row.
for i, (x, z, w, d, door) in enumerate(houses):
    yaw = (i * 37) % 7 - 3
    a = math.radians(yaw)
    def at(lx, lz, ly=5.0, turn=0.0):
        return (x + lx * math.cos(a) + lz * math.sin(a), ly, z - lx * math.sin(a) + lz * math.cos(a), yaw + turn)
    front = 1.0 if door == "s" else -1.0
    turn = 0.0 if door == "s" else 180.0
    node("Chimney", dress, "vael", at(w * 0.3 * (1 if i % 2 else -1), 0), kind="chimney", size=6.4, on_ground=False)
    node("PorchLamp", dress, "vael", at(1.25, front * d * 0.5, turn=turn), kind="porch_lamp", on_ground=False)
    node("Bench", dress, "vael", at(-2.6 if door == "s" else 2.6, front * (d * 0.5 + 0.35), turn=turn), kind="bench", on_ground=False)
    back = at(0, -front * (d * 0.5 + 4.0), turn=turn)
    if i % 3 == 0:
        # The market-side cottage has a shallower garden to leave the stall approaches open.
        garden_at = at(0, -front * (d * 0.5 + 1.75), turn=turn) if i == 3 else back
        node("Garden", dress, "vael", garden_at, kind="garden",
             size=4.4 if i == 3 else float(min(w, 9)), wide=3.0 if i == 3 else 6.0, on_ground=False)
    elif i % 3 == 1:
        node("Laundry", dress, "vael", at(0, -front * (d * 0.5 + 2.5), turn=turn), kind="laundry", size=float(w - 1), on_ground=False)
    else:
        node("LaidUpBoat", dress, "vael", back, kind="upturned_boat", size=4.6, on_ground=False)
        node("Pots", dress, "vael", at(2.8, -front * (d * 0.5 + 2.0), turn=turn), kind="pots", on_ground=False)
for (cx, z, length, yaw) in [(-74.5, -52, 23.0, 0), (-51.5, -52, 23.0, 0), (-28.5, -52, 23.0, 0), (28.5, -52, 23.0, 0), (51.5, -52, 23.0, 0),
                             (74.5, -52, 23.0, 0), (-40, -69, 30.0, 90), (40, -69, 30.0, 90), (0, -36, 16.0, 90)]:
    node("StreetPaving", dress, "vael", (cx, 5.0, z, yaw), kind="paving", size=length, wide=4.0 if yaw else 5.0, on_ground=False)
for (a, b) in [(-86, -66), (-56, -6), (6, 58), (66, 86)]:
    node("BrowWall", dress, "vael", ((a + b) * 0.5, 5.0, -23.5), kind="drystone", size=float(b - a))
for x in (-64, -36, 24, 50, 78):
    node("Lanterns", dress, "vael", (x, 5.0, -52, 90), kind="lantern_string", size=12.0, wide=1.0, on_ground=False)
for (x, z, k, sz) in [(-48, -42, "mossy_oak", 6.0), (62, -44, "mossy_oak", 5.5), (-48, -74, "tall_pine", 5.5), (4, -80, "mossy_oak", 6.5), (25, -71, "mossy_oak", 6.0), (-82, -74, "tall_pine", 5.0)]:
    node("Tree", dress, "tree", (x, 5.0, z), kind=k, size=sz)
# The drowned city, far out at sea.
for (x, z, h) in [(-40, 150, 46.0), (30, 172, 62.0), (92, 142, 38.0), (-112, 166, 52.0), (-4, 205, 74.0)]:
    node("Spire", dress, "vael", (x, -3.6, z, x * 3 % 360), kind="spire", size=h, on_ground=False)

# --- Versus: where rivals begin ------------------------------------------------------------------
rivals = group("Rivals")
for (x, y, z) in [(-70, 5.0, -44), (70, 5.0, -44), (-60, 2.2, -2), (60, 2.2, -2), (0, 5.0, -80), (-84, 2.0, 30), (84, 2.0, 30), (0, 0, 40)]:
    spot(rivals, "rival", (x, y, z))

# --- Names on the map screen ---------------------------------------------------------------------
places = group("Places")
for (x, y, z, text) in [(0, 5.0, -52, "Market Square"), (-40, 5.0, -76, "Chapel"), (40, 5.0, -76, "Harbourmaster's House"),
                        (0, 2.2, -4, "The Quay"), (-84, 2.0, 40, "West Mole"), (84, 2.0, 46, "East Mole"), (84, 2.0, 70, "Lighthouse"),
                        (-22, 0, 46, "Wreck of the Grey Heron"), (8, 0, 30, "Drowned Bell"), (0, 0, 60, "Tide Zone"), (7, 7.8, -93, "Valley Road"),
                        (-76, 2.2, -8, "Boatwright's Yard"), (54, 2.2, -7, "Fishmarket"), (74, 2.2, -21, "Salt House"),
                        (-93, 7.1, -56, "Gullwatch"), (76, 5.0, -87, "Pilgrims' Garden")]:
    spot(places, "place", (x, y, z), text=text)


def write():
    out = ["[gd_scene load_steps=%d format=3]" % (len(SCRIPTS) + len(curves) + 1), ""]
    for path, sid in SCRIPTS:
        out.append('[ext_resource type="Script" path="res://scripts/map/%s.gd" id="%s"]' % (path, sid))
    out.append("")
    for c in curves:
        out.append(c)
        out.append("")
    out.append('[node name="PortVael" type="Node3D"]\nscript = ExtResource("root")\nplay_half = 105.0\nland_half = 110\nforest_wall = true\ngrass = 0.6\nroughness = 3.0\ncalm_radius = 60.0\nlook = "vael"')
    out.append("")
    for n in nodes:
        out.append(n)
        out.append("")
    with open(OUT, "w") as f:
        f.write("\n".join(out))
    print("wrote", OUT, len(nodes), "nodes")


if __name__ == "__main__":
    write()
