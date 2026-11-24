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
LANE = 9.5 # how far east of the road (as you go) the barge's channel runs: clear of the causeway's foot
CHANNEL_Y = -1.0 # the channel's bed, dredged below the flats so the barge always has water under it
ROAD_BLEND = 2.5 # how far the causeway's sides run out to the flats (gentle enough to climb out of the water)
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
road("LanternRoad", roads, [(x, ROAD_Y, z) for (x, z) in line[::2]] + [(line[-1][0], ROAD_Y, line[-1][1])], 6.0, cut=True, blend=ROAD_BLEND)
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
# Dredged along the barge's course: open water from the Harbour Gate to the Isle, wherever the road
# bends, whatever islet stands near.
DOCK = (11.0, -116.5) # where the barge comes to rest: in the water off the Isle's landing


def clear_of_road(p):
    """A point of the channel well off the causeway (inside a bend, the offset can come back over it)."""
    return min(math.dist(p, q) for q in line) >= LANE - 0.8 and math.dist(p, (0, -136)) > 16.0


def toward_dock(points):
    """The channel's course up to where it turns in for the dock: nothing past it, nothing doubling back."""
    out = []
    for q in points:
        if math.dist(q, DOCK) < 10.0:
            break
        if clear_of_road(q):
            out.append(q)
    return out


chan = toward_dock([side(line, i, LANE) for i in range(0, len(line) - 1, 2)]) + [DOCK]
road("BargeChannel", roads, [(round(x, 2), CHANNEL_Y, round(z, 2)) for (x, z) in chan], 3.0, cut=True, draw=False, blend=1.5)
lane = group("BargeLane")
step = 6.0
d = 0.0
next_at = 0.0
k = 0
marks = []
for i in range(len(line)):
    if i > 0:
        d += math.dist(line[i - 1], line[i])
    if d >= next_at:
        next_at += step
        marks.append(side(line, i, LANE))
for q in toward_dock(marks):
    node("Barge", lane, "spot", (round(q[0], 2), 0, round(q[1], 2)), kind="barge", gate=k, on_ground=False)
    k += 1
node("Barge", lane, "spot", (DOCK[0], 0, DOCK[1]), kind="barge", gate=k, on_ground=False) # it ends off the Isle's landing

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
node("IslePier", isle, "vael", (-9, 0, -118, 200), kind="pilings", size=10.0)
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

# --- What makes it the road to the Isle -------------------------------------------------------------
dress = group("Dressing")


def heading(i):
    a = line[max(0, i - 1)]
    b = line[min(len(line) - 1, i + 1)]
    return b[0] - a[0], b[1] - a[1]


# Pilgrims' arches across the road, where the road passes under them.
for f in (0.1, 0.34, 0.58, 0.84):
    i = next(j for j in range(len(line)) if length_to(line, j) >= f * total)
    tx, tz = heading(i)
    yaw = math.degrees(math.atan2(tx, -tz))
    node("PilgrimArch", dress, "vael", (round(line[i][0], 2), ROAD_Y, round(line[i][1], 2), round(yaw, 1)), kind="arch", size=8.6, on_ground=False)
# Shrines of the Tide by the road, on its west side between the lanterns.
d = 0.0
next_at = 40.0
for i in range(1, len(line)):
    d += math.dist(line[i - 1], line[i])
    if d >= next_at and d < total - 20:
        next_at += 55.0
        x, z = side(line, i, -4.6)
        tx, tz = heading(i)
        yaw = math.degrees(math.atan2(tx, -tz)) + 90.0
        node("Shrine", dress, "vael", (round(x, 2), ROAD_Y, round(z, 2), round(yaw, 1)), kind="shrine", on_ground=False)
# The drowned: heads of statues out of the water, a fallen king on an islet, masts with corpse-lights.
for (x, z, sz) in [(-36, 30, 2.4), (44, -24, 2.0), (-80, -64, 2.8), (66, 92, 2.2), (-16, 118, 1.8)]:
    node("DrownedHead", dress, "vael", (x, 0, z), kind="statue_head", size=sz)
node("FallenKing", dress, "vael", (-30, 0, 48, 120), kind="fallen_statue", size=3.5)
node("WhaleBones", dress, "vael", (24, 0, -54, 30), kind="whale_bones", size=10.0)
node("SunkGate", dress, "vael", (-86, 0, 2, 60), kind="broken_arch", size=8.0)
node("SunkGate", dress, "vael", (84, 0, -40, -20), kind="arch", size=7.0)
for (x, z, h) in [(-20, 96, 8.0), (52, 12, 9.0), (-72, -22, 7.5), (34, -84, 9.5), (-44, -112, 8.0), (94, 40, 10.0)]:
    node("Mast", dress, "vael", (x, 0, z, x * 7 % 360), kind="mast", size=h)
for (x, z, r) in [(-44, 112, 4.0), (40, 92, 3.5), (-34, 44, 3.0), (28, 28, 3.5), (-24, -36, 4.0), (98, -12, 4.5), (-50, -82, 3.5)]:
    node("Kelp", dress, "vael", (x, 0, z), kind="kelp_bed", size=r)
for (x, z, sz) in [(-40, 80, 18.0), (30, 50, 16.0), (-50, -10, 18.0), (60, -70, 16.0), (-10, -90, 14.0), (0, 110, 14.0)]:
    node("GhostLights", dress, "vael", (x, 0, z), kind="ghost_lights", size=sz)
# Fires and banners at the Harbour Gate and on the Isle, and the Tide King watching the road's end.
for (x, y, z) in [(-12, 1.25, 135), (12, 1.25, 135), (-5, 2.0, -127), (5, 2.0, -127)]:
    node("Brazier", dress, "vael", (x, y, z), kind="brazier", on_ground=False)
for (x, y, z) in [(-6.5, 1.25, 141.5), (6.5, 1.25, 141.5), (-8, 2.0, -131), (8, 2.0, -131)]:
    node("Banner", dress, "vael", (x, y, z, 0), kind="banner", size=6.0, on_ground=False)
node("Bunting", dress, "vael", (0, 1.25, 143), kind="bunting", size=11.0, wide=0.0, on_ground=False)
node("TideKing", dress, "vael", (-7, 2.0, -126, 160), kind="statue", size=3.6, on_ground=False)
# The drowned city all round, far out at sea; the tallest behind the Isle.
for (x, z, h) in [(-150, -175, 70.0), (175, -120, 55.0), (190, 60, 48.0), (-190, 40, 62.0), (40, -215, 84.0), (-70, 205, 46.0), (120, 190, 52.0)]:
    node("Spire", dress, "vael", (x, -3.0, z, x * 3 % 360), kind="spire", size=h, on_ground=False)


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
