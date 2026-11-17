#!/usr/bin/env python3
"""Writes maps/lantern_road.tscn: the Lantern Road, the map of Last Light ("The Sunken Crown", 0.23).

    python3 tools/make_lantern_map.py          (from the project root)

North is -Z. The whole map is drowned flats under the Mist Tide, which never goes out here
(MistTide.always_high). Across them runs the Lantern Road: an old stone causeway, its lanterns long
cold, from the Harbour Gate in the south (z 132) winding north for about 420 m to the Isle of Lamps
and its lighthouse (z -134). The Lantern Barge goes up a channel beside the road, a few metres to its
east as you go (the "barge" marks, in order), lighting the lanterns as it passes; three waystations
stand off the road's other side. Islets, ruined houses, wrecks, old piers, rocks and buoys stand in
the water either side.
"""
import math
import sys
sys.path.insert(0, "tools")
import make_vael_map as m

m.OUT = "maps/lantern_road.tscn"
m.nodes.clear()
m.curves.clear()
m.names.clear()
node, group, road, spot = m.node, m.group, m.road, m.spot

ROAD_Y = 1.15 # the causeway's top, a little above the high tide (0.85)
SEA_FLOOR = -0.55
LANE = 5.4 # how far east of the road (as you go) the barge's channel runs
ROUTE = [(0, 132), (0, 112), (-24, 92), (-58, 74), (-74, 44), (-60, 14), (-24, 0), (14, -6), (52, -20), (70, -50),
         (58, -82), (24, -98), (-4, -112), (0, -122)]


def catmull(points, step):
    """The route as a smooth curve, a point every `step` metres or so."""
    out = []
    pts = [points[0]] + points + [points[-1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        seg = math.dist(p1, p2)
        n = max(2, int(seg / step))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            z = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, z))
    out.append(points[-1])
    return out


def side(path, i, d):
    """The point `d` metres to the right of the path at point i (to the east, going north)."""
    a = path[max(0, i - 1)]
    b = path[min(len(path) - 1, i + 1)]
    tx, tz = b[0] - a[0], b[1] - a[1]
    l = math.hypot(tx, tz) or 1.0
    # Going north (-Z), right is +X: right = (-tz, tx) / l.
    return (path[i][0] - tz / l * d, path[i][1] + tx / l * d)


def length_to(path, i):
    return sum(math.dist(path[k], path[k + 1]) for k in range(i))


line = catmull(ROUTE, 4.0)
total = length_to(line, len(line) - 1)

# --- The land: the drowned flats, the islets, the Harbour Gate and the Isle of Lamps -------------
land = group("Land")
node("Sea", land, "vael", (0, SEA_FLOOR, 0), kind="sea", on_ground=False)
node("HarbourGateQuay", land, "level", (0, 1.25, 139), size="Vector2(40, 18)", blend=1.6)
node("IsleOfLamps", land, "hill", (0, 0, -136), height=3.4, radius=11.0)
node("LighthousePad", land, "level", (0, 2.0, -136), size="Vector2(22, 22)", blend=3.0)
islets = [(-40, 116, 2.2, 7), (38, 96, 2.6, 8), (-96, 70, 3.0, 10), (-30, 48, 2.0, 6), (-104, 10, 2.8, 9), (30, 30, 2.4, 8),
          (-20, -40, 2.6, 9), (96, -16, 3.2, 10), (24, -54, 2.0, 7), (100, -84, 2.8, 9), (-46, -86, 2.6, 8), (60, -122, 2.4, 8),
          (-60, -126, 2.2, 7), (-110, -50, 3.0, 10), (110, 60, 2.6, 9)]
for (x, z, h, r) in islets:
    node("Islet", land, "hill", (x, 0, z), height=h + 0.55, radius=float(r))

# --- The Lantern Road ----------------------------------------------------------------------------
roads = group("Roads")
road("LanternRoad", roads, [(x, ROAD_Y, z) for (x, z) in line[::2]] + [(line[-1][0], ROAD_Y, line[-1][1])], 6.0, cut=True)
road("IsleStair", roads, [(0, ROAD_Y, -122), (0, 1.6, -126), (0, 2.0, -129)], 5.0, cut=True)
lights = group("RoadLanterns")
d = 0.0
next_at = 8.0
for i in range(1, len(line)):
    d += math.dist(line[i - 1], line[i])
    if d >= next_at and d < total - 6:
        next_at += 15.0
        x, z = side(line, i, -3.5)
        tx, tz = line[i][0] - line[i - 1][0], line[i][1] - line[i - 1][1]
        yaw = math.degrees(math.atan2(-tz, tx)) + 90.0 # the lantern's arm (+X) out over the road
        node("RoadLantern", lights, "vael", (x, ROAD_Y, z, yaw), kind="road_lantern", on_ground=False)

# --- The barge's channel -------------------------------------------------------------------------
lane = group("BargeLane")
step = 6.0
d = 0.0
next_at = 0.0
k = 0
for i in range(len(line)):
    if i > 0:
        d += math.dist(line[i - 1], line[i])
    if d >= next_at or i == len(line) - 1:
        next_at += step
        x, z = side(line, i, LANE) if i < len(line) - 1 else (line[i][0] + LANE * 0.4, line[i][1] - 2.0)
        node("Barge", lane, "spot", (round(x, 2), 0, round(z, 2)), kind="barge", gate=k, on_ground=False)
        k += 1

# --- Waystations, off the road's west side -------------------------------------------------------
ways = group("Waystations")
WAY_NAMES = ["Saint Ennor's Landing", "The Drowned Inn", "The Last Waystation"]
for n, f in enumerate((0.26, 0.52, 0.78)):
    i = next(j for j in range(len(line)) if length_to(line, j) >= f * total)
    x, z = side(line, i, -10.0)
    a = line[max(0, i - 1)]
    b = line[min(len(line) - 1, i + 1)]
    yaw = math.degrees(math.atan2(b[0] - a[0], b[1] - a[1])) # its steps (-Z) away from the road
    node("Waystation", ways, "vael", (round(x, 2), ROAD_Y + 0.05, round(z, 2), yaw + 90.0), kind="waystation", size=10.0, on_ground=False)
    spot(ways, "place", (x, ROAD_Y, z), text=WAY_NAMES[n])
    spot(ways, "loot", (x + 2.0, ROAD_Y, z + 2.0))
    # A short spur of causeway from the road to it.
    road("Spur", roads, [(line[i][0], ROAD_Y, line[i][1]), (x, ROAD_Y, z)], 4.0, cut=True)

# --- The Harbour Gate ----------------------------------------------------------------------------
gate = group("HarbourGate")
node("GateQuay", gate, "vael", (0, 1.25, 139), kind="paving", size=38.0, wide=16.0, on_ground=False)
for x in (-9.0, 9.0):
    node("GateTower", gate, "house", (x, 1.25, 145), width=6.0, depth=6.0, height=6.5, ridge="x", roof_rise=2.0,
         walls=m.STONE, roof=m.SLATE, beams=False, north="slit:0", south="door:0:2.0:2.8", east="slit:0", west="slit:0", level_ground=False)
for x in (-17.0, 17.0):
    node("GateLamp", gate, "vael", (x, 1.25, 133), kind="lamp_post", on_ground=False)
for (x, z, k2) in [(-14, 141, "barrel"), (-13, 142.4, "crate_big"), (13, 141, "sack"), (15, 140, "barrel"), (6, 143, "crate_small")]:
    node("GateProp", gate, "prop", (x, 1.25, z, x * 13 % 360), kind=k2, on_ground=False)
for (x, z) in [(0, 136), (-4, 137), (4, 137), (-8, 138), (8, 138)]:
    spot(gate, "start", (x, 1.25, z))
spot(gate, "place", (0, 1.25, 139), text="The Harbour Gate")

# --- The Isle of Lamps ---------------------------------------------------------------------------
isle = group("IsleOfLamps")
node("Lighthouse", isle, "vael", (0, 2.0, -138), kind="lighthouse", size=19.0, on_ground=False)
node("IsleRocks", isle, "vael", (-9, 0, -142, 40), kind="sea_rocks", size=4.0)
node("IsleRocks", isle, "vael", (10, 0, -132, 200), kind="sea_rocks", size=3.5)
node("IslePier", isle, "vael", (8, 0, -118, 160), kind="pilings", size=10.0)
spot(isle, "place", (0, 2.0, -136), text="Isle of Lamps")
for (x, z) in [(-6, -130), (6, -131)]:
    spot(isle, "loot", (x, 2.0, z))

# --- The drowned flats either side ---------------------------------------------------------------
flats = group("Flats")
for (at, length) in [((-36, 0, 70, 30), 18.0), ((44, 0, 4, -50), 15.0), ((-50, 0, -60, 100), 14.0), ((40, 0, -110, 20), 12.0)]:
    node("Wreck", flats, "vael", at, kind="wreck", size=length)
for (x, z, s) in [(20, 120, 4.0), (-70, 100, 4.5), (-90, 30, 3.5), (8, 24, 3.0), (80, 8, 4.0), (40, -36, 3.5), (88, -60, 4.0),
                  (-20, -70, 3.5), (-80, -100, 4.0), (30, -130, 3.0), (-30, 130, 3.5)]:
    node("SeaRocks", flats, "vael", (x, 0, z, x * 11 % 360), kind="sea_rocks", size=s)
for (x, z) in [(14, 104), (-46, 86), (-82, 54), (-48, 22), (30, -8), (80, -36), (48, -94), (-20, -108)]:
    node("Buoy", flats, "vael", (x, 0, z, x * 23 % 360), kind="buoy")
for (x, z, length, yaw) in [(-14, 74, 20.0, 30), (60, 50, 16.0, -20), (-90, -20, 18.0, 70), (70, -110, 14.0, 10)]:
    node("OldPier", flats, "vael", (x, 0, z, yaw), kind="pilings", size=length)
node("Boat", flats, "vael", (-28, 0, 104, 40), kind="boat", size=4.2)
node("Boat", flats, "vael", (66, 0, -64, -30), kind="upturned_boat", size=4.0)
# Drowned cottages on the islets, and dead trees.
for (x, z, yaw) in [(-96, 70, 20), (30, 30, -15), (96, -16, 40), (-110, -50, 10), (-46, -86, -30)]:
    node("DrownedCottage", flats, "house", (x, 2.8, z, yaw), width=7.0, depth=6.0, height=2.8, ridge="x", roof_rise=2.0,
         walls=m.WHITEWASH_B, roof=m.SLATE_B, beams=True, south="door:0, window:2", north="window:0", level_ground=True)
for (x, z) in [(-40, 116), (38, 96), (-30, 48), (-104, 10), (-20, -40), (24, -54), (100, -84), (60, -122), (-60, -126), (110, 60)]:
    node("DeadTree", flats, "tree", (x + 1.5, 0, z - 1.0, x * 7 % 360), kind="dead", size=5.0 + (abs(x) % 3))
for (x, z) in [(-40, 114), (36, 98), (-96, 72), (-30, 50), (30, 32), (96, -14), (-20, -38), (100, -82), (-46, -84), (60, -120)]:
    spot(flats, "loot", (x, 0, z))
for (x, z) in [(-30, 100), (-70, 60), (-40, 10), (30, -14), (64, -60), (30, -100), (-60, 40), (40, 60)]:
    spot(flats, "poi", (x, 0, z))
spot(flats, "place", (-74, ROAD_Y, 44), text="The Lantern Road")


def write():
    out = ["[gd_scene load_steps=%d format=3]" % (len(m.SCRIPTS) + len(m.curves) + 1), ""]
    for path, sid in m.SCRIPTS:
        out.append('[ext_resource type="Script" path="res://scripts/map/%s.gd" id="%s"]' % (path, sid))
    out.append("")
    for c in m.curves:
        out.append(c)
        out.append("")
    out.append('[node name="LanternRoad" type="Node3D"]\nscript = ExtResource("root")\nplay_half = 152.0\nland_half = 165\nforest_wall = false\ngrass = 0.0\nroughness = 0.0\ncalm_radius = 0.0\nlook = "lantern_road"')
    out.append("")
    for n in m.nodes:
        out.append(n)
        out.append("")
    with open(m.OUT, "w") as f:
        f.write("\n".join(out))
    print("wrote", m.OUT, len(m.nodes), "nodes; the road", round(total), "m")


if __name__ == "__main__":
    write()
