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


def road(name, parent, points, width, cut=False, draw=True):
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
node("Quayside", land, "level", (0, 2.2, -5), size="Vector2(176, 22)", blend=1.0)
node("HeadlandWest", land, "hill", (-104, 0, 34), height=11.0, radius=20.0)
node("HeadlandEast", land, "hill", (104, 0, 28), height=13.0, radius=20.0)
node("HillNorthWest", land, "hill", (-92, 0, -88), height=7.0, radius=22.0)
node("HillNorthEast", land, "hill", (90, 0, -92), height=8.0, radius=22.0)

# --- Roads ---------------------------------------------------------------------------------------
roads = group("Roads")
road("HarbourStreet", roads, [(0, 2.2, -10), (0, 3.4, -18), (0, 5.0, -27), (0, 5.0, -44)], 5.0, cut=True)
road("QuayStreet", roads, [(-80, 2.2, -4), (80, 2.2, -4)], 6.0)
road("MarketRow", roads, [(-86, 5.0, -52), (86, 5.0, -52)], 5.0)
road("ChapelLane", roads, [(-40, 5.0, -52), (-40, 5.0, -84)], 4.0)
road("HillLane", roads, [(40, 5.0, -52), (40, 5.0, -86)], 4.0)
road("WestSteps", roads, [(-60, 2.2, -12), (-60, 3.6, -19), (-60, 5.0, -27)], 3.4, cut=True)
road("EastSteps", roads, [(62, 2.2, -12), (62, 3.6, -19), (62, 5.0, -27)], 3.4, cut=True)

# --- The harbour ---------------------------------------------------------------------------------
harbour = group("Harbour")
# The harbour wall, in three lengths with stairs down between them.
node("WallWest", harbour, "vael", (-55.4, 2.2, 6), kind="quay_wall", size=47.2, on_ground=False)
node("WallMiddle", harbour, "vael", (0, 2.2, 6), kind="quay_wall", size=56.8, on_ground=False)
node("WallEast", harbour, "vael", (55.4, 2.2, 6), kind="quay_wall", size=47.2, on_ground=False)
for x in (-30.0, 30.0):
    node("SeaStairs", harbour, "vael", (x, 2.2, 6.2), kind="sea_stairs", size=6.0, wide=1.6, on_ground=False)
# The breakwaters and the lighthouse.
node("WestMole", harbour, "vael", (-84, 2.0, 40), kind="mole", size=68.0, wide=7.0, on_ground=False)
node("EastMole", harbour, "vael", (84, 2.0, 40), kind="mole", size=68.0, wide=7.0, on_ground=False)
node("Lighthouse", harbour, "vael", (84, 2.0, 70), kind="lighthouse", size=17.0, on_ground=False)
for z in (18, 34, 50):
    node("MoleLamp", harbour, "vael", (-81.5, 2.0, z), kind="lamp_post", on_ground=False)
    node("MoleLamp", harbour, "vael", (81.5, 2.0, z, 180), kind="lamp_post", on_ground=False)

# --- The quay ------------------------------------------------------------------------------------
quay = group("Quay")
node("QuayPaving", quay, "vael", (0, 2.2, -5), kind="paving", size=170.0, wide=21.6, on_ground=False)
for i, (x, w) in enumerate([(-50, 16.0), (-20, 14.0), (26, 16.0)]):
    house = node("Warehouse", quay, "house", (x, 2.2, -12), width=w, depth=8.0, height=4.4, ridge="x", roof_rise=2.4,
                 walls=STONE, roof=SLATE, beams=True, south="door:-3:3.2:3.6, window:3", north="window:-3, window:3", level_ground=False)
    spot(house, "loot", (-2.5, 0, 1.0), on_ground=False)
    node("Crate", house, "prop", (2.6, 0, -2.2), kind="crate_big", on_ground=False)
    node("Crate", house, "prop", (3.6, 0, -1.2, 30), kind="crate_small", on_ground=False)
    node("Barrel", house, "prop", (-5.0, 0, -2.4), kind="barrel", on_ground=False)
    node("Barrel", house, "prop", (-5.8, 0, -1.4), kind="barrel", on_ground=False)
    node("Sack", house, "prop", (0.5, 0, -2.6), kind="sack", on_ground=False)
for x in (-35.0, 12.0, 48.0):
    node("Crane", quay, "vael", (x, 2.2, 3.4), kind="crane", size=6.5, on_ground=False)
for x in range(-72, 80, 16):
    node("QuayLamp", quay, "vael", (x, 2.2, 4.2, 180), kind="lamp_post", on_ground=False)
node("Nets", quay, "vael", (60, 2.2, -10), kind="net_rack", size=10.0, on_ground=False)
node("Nets", quay, "vael", (-72, 2.2, -10), kind="net_rack", size=8.0, on_ground=False)
for (x, z) in [(-8, 1.0), (38, -1.0), (-62, 1.5), (68, 0.5)]:
    node("Pots", quay, "vael", (x, 2.2, z, x * 7 % 180), kind="pots", on_ground=False)
for (x, z, k) in [(-44, 1.5, "barrel"), (-43, 2.6, "barrel"), (-41, 1.2, "crate_big"), (5, 1.6, "crate_long"), (6.5, -0.2, "crate_small"),
                  (18, 2.0, "barrel"), (33, 1.8, "sack"), (34, 0.9, "sack"), (52, 2.4, "crate_big"), (-14, -0.5, "wheelbarrow"),
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
    h = node("House", town, "house", (x, 5.0, z, (i * 37) % 7 - 3), width=float(w), depth=float(d), height=3.2, ridge="x", roof_rise=2.3,
             walls=walls, roof=roof, beams=i % 4 == 0, south="door:0, window:-2.5" if door == "s" else "window:-2, window:2",
             north="door:0, window:2.5" if door == "n" else "window:0", east="window:0", west="window:0")
    if i % 2 == 0:
        spot(h, "loot", (-1.5, 0, 0.5), on_ground=False)
        node("Table", h, "thing", (1.8, 0, -1.2), kind="table", on_ground=False)
    else:
        node("Bed", h, "thing", (-2.0, 0, -1.6), kind="bed", on_ground=False)
        node("Barrel", h, "prop", (2.6, 0, 1.6), kind="barrel", on_ground=False)
# The chapel: tall, with a bell in its gable; the Harbourmaster's house, big and stone.
chapel = node("Chapel", town, "house", (-40, 5.0, -76), width=10.0, depth=16.0, height=6.0, ridge="z", roof_rise=4.0,
              walls=STONE, roof=SLATE, beams=False, south="door:0:2.4:3.6", east="slit:-4, slit:0, slit:4", west="slit:-4, slit:0, slit:4", north="window:0")
spot(chapel, "loot", (0, 0, -5), on_ground=False)
spot(chapel, "loot", (2.5, 0, 3), on_ground=False)
hm = node("HarbourmastersHouse", town, "house", (40, 5.0, -76), width=13.0, depth=10.0, height=4.0, ridge="x", roof_rise=2.8,
          walls=STONE, roof=SLATE, beams=False, south="door:0:2.4:3.0, window:-4, window:4", north="window:-3, window:3", east="window:0", west="window:0")
spot(hm, "loot", (-3, 0, -2), on_ground=False)
spot(hm, "loot", (3.5, 0, 1.5), on_ground=False)
node("Table", hm, "thing", (0, 0, -1), kind="table", on_ground=False)
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
for (x, z, k, s) in [(-86, -44, "broad", 6.5), (86, -46, "dead", 6.0), (-4, -86, "broad", 7.0), (30, -40, "dead", 5.5), (-30, -40, "broad", 6.0)]:
    node("Tree", town, "tree", (x, 5.0, z), kind=k, size=s)
# Pines on the headlands and the hills behind the town.
nature = group("Nature")
for i in range(18):
    side = -1 if i % 2 == 0 else 1
    x = side * (90 + (i * 7) % 12)
    z = -40 + i * 7.5
    node("Pine", nature, "tree", (x, 0, z, i * 40), kind="fir", size=6.5 + (i % 3) * 0.8)
for i in range(10):
    node("Pine", nature, "tree", (-80 + i * 17, 0, -98 + (i % 3) * 2, i * 50), kind="fir", size=7.0 + (i % 2))

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
node("Boat", flats, "vael", (20, 0, 14, 40), kind="boat", size=4.2)
node("Boat", flats, "vael", (-56, 0, 12, -30), kind="upturned_boat", size=4.0)
for (x, z) in [(-40, 40), (-8, 58), (20, 38), (44, 70), (-30, 74), (0, 16), (-64, 28), (64, 34)]:
    spot(flats, "loot", (x, 0, z))
for (x, z) in [(-20, 30), (20, 50), (0, 66), (-50, 50), (50, 50)]:
    spot(flats, "poi", (x, 0, z))
for (x, z) in [(-40, -60), (40, -60), (0, -40), (-60, -20), (60, -20), (-70, -80), (70, -80)]:
    spot(town, "poi", (x, 5.0, z))

# --- Versus: where rivals begin ------------------------------------------------------------------
rivals = group("Rivals")
for (x, y, z) in [(-70, 5.0, -44), (70, 5.0, -44), (-60, 2.2, -2), (60, 2.2, -2), (0, 5.0, -80), (-84, 2.0, 30), (84, 2.0, 30), (0, 0, 40)]:
    spot(rivals, "rival", (x, y, z))

# --- Names on the map screen ---------------------------------------------------------------------
places = group("Places")
for (x, y, z, text) in [(0, 5.0, -52, "Market Square"), (-40, 5.0, -76, "Chapel"), (40, 5.0, -76, "Harbourmaster's House"),
                        (0, 2.2, -4, "The Quay"), (-84, 2.0, 40, "West Mole"), (84, 2.0, 46, "East Mole"), (84, 2.0, 70, "Lighthouse"),
                        (-22, 0, 46, "Wreck of the Grey Heron"), (8, 0, 30, "Drowned Bell"), (0, 0, 60, "The Flats")]:
    spot(places, "place", (x, y, z), text=text)


def write():
    out = ["[gd_scene load_steps=%d format=3]" % (len(SCRIPTS) + len(curves) + 1), ""]
    for path, sid in SCRIPTS:
        out.append('[ext_resource type="Script" path="res://scripts/map/%s.gd" id="%s"]' % (path, sid))
    out.append("")
    for c in curves:
        out.append(c)
        out.append("")
    out.append('[node name="PortVael" type="Node3D"]\nscript = ExtResource("root")\nplay_half = 100.0\nland_half = 110\nforest_wall = true\ngrass = 0.6\nroughness = 3.0\ncalm_radius = 60.0\nlook = "vael"')
    out.append("")
    for n in nodes:
        out.append(n)
        out.append("")
    with open(OUT, "w") as f:
        f.write("\n".join(out))
    print("wrote", OUT, len(nodes), "nodes")


if __name__ == "__main__":
    write()
