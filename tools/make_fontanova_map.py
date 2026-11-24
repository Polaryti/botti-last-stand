#!/usr/bin/env python3
"""Writes maps/fontanova.tscn: Fontanova, the first island of the Archipelagos of the Forgotten Gods.

    python3 tools/make_fontanova_map.py          (from the project root)

The map is laid out here in code, so it can be read and changed in one place, then opened and moved
about in the Godot editor like any other map. North is -Z. The island is about 250 m across, ringed by
open sea that deepens to the horizon, with the other islands of the archipelago out on it.

  The Landing (south, z 95..125): the cove where your sailboat lies run up on the sand.
  The olive terraces (the middle): dry-stone terraces of olives and carobs, wildflower meadows, the
    ruined village of the god's worshippers and the Fallen Colossus.
  The West Ridge: limestone cliffs over the sea, split by the Ravine, crossed by two rope bridges.
  The Holm Wood (east): holm oaks and strawberry trees on the east hill, and the Oracle's Grotto
    running through it.
  The Acropolis (north): the Temple of Al'quimelea on its height, the shattered gods round it, and
    the alchemist god's cauldrons. Al'quimelea rises here.
"""
import math

OUT = "maps/fontanova.tscn"

SCRIPTS = [
    ("map_root", "root"), ("map_level", "level"), ("map_hill", "hill"), ("map_road", "road"),
    ("map_fonta", "fonta"), ("map_spot", "spot"),
]

ISLE_R = 128.0
ISLE_WOBBLE = 0.035
# The shore, every 15 degrees round from the east towards the south (+Z): the deep cove of the Landing
# in the south, a cape either side of it, the Ravine's little cove to the south-west, the long cliffs of
# the West Ridge, the Acropolis on its northern cliffs, a bay in the north-east, the east hill's shore.
SHORE = [124, 130, 142, 134, 122, 98, 78, 92, 128, 112, 124, 118, 130, 136, 128, 114,
         124, 136, 130, 120, 138, 116, 100, 112]
TEMPLE_Y = 19.0
RAVINE_Y = 2.6

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
        elif isinstance(v, str) and not v.startswith(("Color(", "Vector2(", "Vector3(", "PackedFloat32Array(")):
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


def fonta(name, parent, kind, at, **props):
    return node(name, parent, "fonta", at, kind=kind, **props)


# --- The land ------------------------------------------------------------------------------------
land = group("Land")
fonta("Isle", land, "isle", (0, 0, 0), size=ISLE_R, wide=ISLE_WOBBLE, shore="PackedFloat32Array(%s)" % ", ".join("%.1f" % r for r in SHORE), on_ground=False)
# The Acropolis: the height in the north, levelled on top for the temple and its court.
for (x, z, h, r) in [(0, -80, 21.0, 26.0), (-26, -92, 12.0, 16.0), (28, -94, 12.0, 16.0)]:
    node("Acropolis", land, "hill", (x, 0, z), height=h, radius=r)
node("TempleCourt", land, "level", (0, TEMPLE_Y, -84), size="Vector2(46, 34)", blend=7.0)
# The West Ridge, high over the sea, and the north-west cliffs.
for (x, z, h, r) in [(-94, -6, 17.0, 19.0), (-88, 34, 14.0, 17.0), (-96, -48, 18.0, 18.0), (-62, -96, 15.0, 18.0), (-78, 70, 9.0, 16.0)]:
    node("WestRidge", land, "hill", (x, 0, z), height=h, radius=r)
# The east hill and its woods, the Oracle's Grotto running through it, and the north-east height.
for (x, z, h, r) in [(84, -28, 15.0, 21.0), (96, 14, 12.0, 17.0), (58, -96, 13.0, 19.0)]:
    node("EastHill", land, "hill", (x, 0, z), height=h, radius=r)
# The olive slopes rising gently from the Landing to the Acropolis, and the headlands either side of
# the cove.
for (x, z, h, r) in [(0, -8, 6.5, 40.0), (-34, -36, 8.0, 22.0), (32, -46, 7.0, 22.0), (30, 30, 3.5, 22.0), (-30, 34, 3.0, 20.0),
                     (44, -6, 6.0, 14.0), (-52, -26, 7.0, 13.0), (56, 46, 5.0, 14.0), (-46, 60, 4.0, 12.0), (12, -36, 3.0, 12.0)]:
    node("OliveSlopes", land, "hill", (x, 0, z), height=h, radius=r)
for (x, z, h, r) in [(86, 96, 13.0, 14.0), (-58, 98, 9.0, 13.0)]:
    node("Headland", land, "hill", (x, 0, z), height=h, radius=r)
# The Ravine: a cleft through the West Ridge, its floor a dry torrent bed running down to the sea.
road("Ravine", land, [(-58, 8.0, -78), (-63, RAVINE_Y + 1.5, -50), (-66, RAVINE_Y, -18), (-68, RAVINE_Y, 14),
                      (-74, RAVINE_Y - 0.8, 44), (-88, 0.0, 74)], 7.0, cut=True, draw=False, blend=2.2)

# --- Roads and paths -----------------------------------------------------------------------------
roads = group("Roads")
road("LandingPath", roads, [(4, 1.2, 90), (6, 2.0, 78), (2, 3.4, 64), (0, 5.0, 40)], 3.6)
road("OliveWay", roads, [(0, 5.0, 40), (-4, 6.2, 16), (0, 6.6, -8), (4, 8.0, -34), (0, 11.0, -52)], 3.6)
# The Sacred Way climbs the Acropolis in two turns.
road("SacredWay", roads, [(0, 11.0, -52), (-12, 14.0, -58), (-6, 17.0, -64), (0, TEMPLE_Y, -68)], 4.0, cut=True, blend=3.0)
road("RidgePath", roads, [(-4, 6.2, 16), (-28, 6.5, 8), (-50, 8.5, -2)], 3.0)
road("WoodPath", roads, [(0, 6.6, -8), (30, 7.0, -12), (56, 7.0, -18), (70, 5.5, -40)], 3.0)
road("CoveShore", roads, [(-34, 1.1, 92), (4, 1.2, 90), (40, 1.2, 92)], 3.0)


# --- The Landing ---------------------------------------------------------------------------------
landing = group("Landing")
fonta("Sailboat", landing, "sailboat", (16, 0, 82, 160), size=17.0)
fonta("ShoreCrates", landing, "shore_crates", (2, 0, 70, 20))
fonta("ShoreCrates", landing, "shore_crates", (-9, 0, 72, -35))
fonta("Amphorae", landing, "amphorae", (24, 0, 68))
for (x, z) in [(-2, 64), (6, 62), (-8, 66), (10, 66)]:
    spot(landing, "start", (x, 0, z))
for (x, z, s) in [(118, 104, 16.0), (128, 88, 12.0), (-104, 98, 14.0), (-118, 84, 10.0), (60, -128, 13.0), (-40, -132, 11.0)]:
    fonta("SeaStack", landing, "sea_stack", (x, 0, z, x * 7 % 360), size=s, on_ground=False)
for (x, z, s) in [(64, 92, 4.0), (78, 80, 5.0), (-48, 92, 3.5), (-60, 84, 4.5), (40, 88, 2.5)]:
    fonta("Limestone", landing, "limestone", (x, 0, z, x * 13 % 360), size=s)
for (x, z) in [(36, 70), (-30, 74), (56, 66)]:
    fonta("Maquis", landing, "maquis", (x, 0, z), size=9.0)

# --- The olive terraces and the worshippers' village ---------------------------------------------
groves = group("Groves")
for z in (54, 36, 18, -2, -22):
    for (x0, x1) in [(-44, -6), (6, 44)]:
        fonta("TerraceWall", groves, "terrace_wall", ((x0 + x1) * 0.5, 0, z, 0), size=float(x1 - x0), wide=1.0)
olives = 0
for zi, z in enumerate(range(48, -34, -9)):
    for xi, x in enumerate(range(-42, 46, 8)):
        if abs(x) < 7:
            continue # the path
        if -40 < x < -18 and 8 < z < 34:
            continue # the village
        if 14 < x < 36 and -4 < z < 22:
            continue # the colossus' meadow
        jx = ((xi * 37 + zi * 11) % 7) - 3
        jz = ((xi * 13 + zi * 29) % 5) - 2
        kind = "carob" if (xi + zi * 3) % 11 == 0 else "olive"
        size = 6.5 if kind == "carob" else 4.0 + ((xi * 7 + zi) % 5) * 0.35
        fonta("Olive" if kind == "olive" else "Carob", groves, kind, (x + jx, 0, z + jz), size=size)
        olives += 1
for (x, z, s) in [(-12, 60, 14.0), (14, 62, 12.0), (24, 44, 10.0), (-26, 46, 12.0), (30, 4, 16.0), (-6, 22, 9.0), (10, -14, 10.0),
                  (-20, -28, 12.0), (36, -30, 10.0), (-48, 54, 14.0), (52, 40, 13.0), (-54, -10, 9.0)]:
    fonta("Wildflowers", groves, "wildflowers", (x, 0, z), size=s)
village = group("WorshippersVillage")
for (x, z, yaw, length, high) in [(-36, 14, 0, 8.0, 2.6), (-36, 22, 0, 8.0, 1.8), (-40, 18, 90, 8.0, 2.2), (-32, 18, 90, 8.0, 1.2),
                                  (-24, 26, 0, 7.0, 2.4), (-24, 32, 0, 7.0, 1.6), (-27.5, 29, 90, 6.0, 2.0),
                                  (-34, 32, 0, 6.0, 1.4)]:
    fonta("RuinWall", village, "ruin_wall", (x, 0, z, yaw), size=length, wide=high)
fonta("ShrineAltar", village, "altar", (-22, 0, 16, 180))
fonta("Stele", village, "stele", (-19, 0, 14, 200), size=2.4, variant=0)
for (x, z) in [(-38, 26), (-28, 12), (-20, 30)]:
    fonta("Amphorae", village, "amphorae", (x, 0, z))
fonta("Cauldron", village, "cauldron", (-30, 0, 20), size=1.3)
colossus = group("FallenColossus")
fonta("ColossusHead", colossus, "god_head", (24, 0, 10, 205), size=5.0, variant=1)
fonta("ColossusHand", colossus, "god_hand", (32, 0, 2, 60), size=5.5)
for (x, z) in [(18, 2), (30, 16)]:
    fonta("BrokenColumn", colossus, "broken_column", (x, 0, z, x * 9 % 360), size=6.0)

# --- The West Ridge and the Ravine ---------------------------------------------------------------
ridge = group("WestRidge")
fonta("RavineBridgeNorth", ridge, "rope_bridge", (-65, 0, -28, 90), size=18.0, on_ground=False)
fonta("RavineBridgeSouth", ridge, "rope_bridge", (-67.5, 0, 8, 90), size=18.0, on_ground=False)
fonta("Kerys", ridge, "god_statue", (-96, 0, -14, 70), size=6.0, variant=4)
fonta("Orvane", ridge, "fallen_god", (-90, 0, 34, 110), size=6.0, variant=3)
for (x, z, s) in [(-104, -30, 5.0), (-100, 16, 4.0), (-86, -54, 5.5), (-108, 46, 4.5), (-58, -84, 5.0), (-80, -74, 4.0), (-76, -40, 3.5), (-80, 20, 3.0)]:
    fonta("Limestone", ridge, "limestone", (x, 0, z, x * 17 % 360), size=s)
for (x, z, s) in [(-84, -20, 10.0), (-92, 4, 9.0), (-78, 48, 12.0), (-96, -40, 8.0), (-70, -66, 10.0), (-54, 70, 9.0)]:
    fonta("Maquis", ridge, "maquis", (x, 0, z), size=s)
for (x, z) in [(-54, -30), (-56, -24), (-56, 6), (-56, 12), (-77, -32), (-79, 4), (-48, -2), (-44, 2)]:
    fonta("Cypress", ridge, "cypress", (x, 0, z), size=10.0 + (x * z) % 3)

# --- The Holm Wood and the Oracle's Grotto -------------------------------------------------------
wood = group("HolmWood")
fonta("OraclesGrotto", wood, "grotto", (82, 5.5, -29, 0), size=30.0, wide=5.0, on_ground=False)
fonta("OracleAltar", wood, "altar", (79.2, 5.5, -29, 90), on_ground=False)
fonta("OracleStele", wood, "stele", (79.0, 5.5, -26.5, 90), size=2.0, variant=1, on_ground=False)
fonta("Ilyria", wood, "god_statue", (58, 0, 22, 220), size=6.0, variant=2)
trees = 0
for k in range(48):
    a = k * 2.399
    r = 6 + (k * 53 % 37)
    x = 80 + math.cos(a) * r * 0.9
    z = -18 + math.sin(a) * r * 1.2
    if abs(x - 82) < 6 and -50 < z < -8:
        continue # the grotto's line
    kind = "madrono" if k % 4 == 1 else "holm_oak"
    fonta("HolmOak" if kind == "holm_oak" else "Madrono", wood, kind, (round(x, 1), 0, round(z, 1)), size=7.0 + (k % 3) * 0.8 if kind == "holm_oak" else 5.0)
    trees += 1
for (x, z, s) in [(64, -6, 10.0), (100, -2, 9.0), (70, -56, 11.0), (104, -44, 8.0), (52, 6, 9.0)]:
    fonta("Maquis", wood, "maquis", (x, 0, z), size=s)
for (x, z, s) in [(96, 40, 4.0), (108, -16, 5.0), (90, -62, 4.5)]:
    fonta("Limestone", wood, "limestone", (x, 0, z, x * 3 % 360), size=s)

# --- The Acropolis: the Temple of Al'quimelea ----------------------------------------------------
acro = group("Acropolis")
fonta("TempleOfAlquimelea", acro, "temple", (0, TEMPLE_Y, -90, 0), size=26.0, wide=18.0, on_ground=False)
fonta("Alquimelea", acro, "god_statue", (0, TEMPLE_Y, -75, 0), size=9.0, variant=0, on_ground=False)
for (x, z, yaw, v) in [(-18, -78, 130, 1), (19, -80, 230, 2), (-17, -98, 60, 3), (18, -99, 300, 4)]:
    fonta("FallenGod", acro, "fallen_god", (x, TEMPLE_Y, z, yaw), size=6.0, variant=v, on_ground=False)
fonta("GodHead", acro, "god_head", (-12, TEMPLE_Y, -70, 160), size=3.2, variant=0, on_ground=False)
for (x, z) in [(12, -71), (-21, -88), (21, -90)]:
    fonta("Cauldron", acro, "cauldron", (x, TEMPLE_Y, z), size=1.6, on_ground=False)
for (x, z) in [(-8, -69), (8, -69)]:
    fonta("Altar", acro, "altar", (x, TEMPLE_Y, z, 0), on_ground=False)
# The Sacred Way's columns, two by two up the hill.
for (x, z, broken) in [(-4, -52, False), (4, -52, True), (-15, -57, False), (-9, -61, True), (-3, -63, False), (5, -64, True)]:
    fonta("SacredColumn", acro, "broken_column" if broken else "column", (x, 0, z), size=6.5)
for (x, z) in [(-5, -67), (5, -67)]:
    fonta("Cypress", acro, "cypress", (x, TEMPLE_Y, z), size=11.0, on_ground=False)
for (x, z) in [(-14, -64), (14, -66)]:
    fonta("Stele", acro, "stele", (x, 0, z, 180), size=2.2, variant=0)
for (x, z, s) in [(-40, -100, 5.0), (40, -104, 5.0), (-30, -110, 4.0), (26, -112, 4.5), (52, -110, 6.0), (-64, -108, 4.0)]:
    fonta("Limestone", acro, "limestone", (x, 0, z, x * 11 % 360), size=s)
for (x, z, s) in [(-34, -66, 9.0), (34, -70, 10.0), (46, -90, 8.0), (-46, -88, 9.0)]:
    fonta("Maquis", acro, "maquis", (x, 0, z), size=s)
for (x, z, s) in [(-22, -50, 12.0), (24, -54, 11.0)]:
    fonta("Wildflowers", acro, "wildflowers", (x, 0, z), size=s)
for (x, z) in [(-28, -60), (30, -62), (46, -76), (-44, -74)]:
    fonta("Olive", acro, "olive", (x, 0, z), size=4.4)

# --- The archipelago, far out at sea -------------------------------------------------------------
far = group("Archipelago")
for (x, z, s) in [(-232, -70, 70.0), (205, -150, 80.0), (150, 205, 55.0), (-190, 175, 50.0), (30, -240, 90.0)]:
    fonta("HorizonIsle", far, "horizon_isle", (x, 0, z, x % 360), size=s, on_ground=False)

# --- Versus: where rivals begin ------------------------------------------------------------------
rivals = group("Rivals")
for (x, z) in [(0, 70), (-30, 30), (30, 30), (-60, -10), (60, -10), (0, -40), (-40, -60), (40, -60)]:
    spot(rivals, "rival", (x, 0, z))

# --- Supplies ------------------------------------------------------------------------------------
loot = group("Loot")
for (x, z) in [(-28, 20), (-22, 28), (8, 76), (26, 6), (82, -30), (-66, -32), (-66, 12), (0, -76), (14, -86), (-14, -86), (60, 18), (-92, -10), (100, 6)]:
    spot(loot, "loot", (x, 0, z))
for (x, z) in [(0, 0), (-50, 40), (50, -40), (-40, -40), (40, 50)]:
    spot(loot, "poi", (x, 0, z))

# --- Names on the map screen ---------------------------------------------------------------------
places = group("Places")
for (x, z, text) in [(10, 80, "The Landing"), (-30, 20, "Worshippers' Village"), (26, 8, "Fallen Colossus"), (0, 30, "Olive Terraces"),
                     (-66, -10, "The Ravine"), (-96, -14, "Kerys' Watch"), (82, -30, "Oracle's Grotto"), (78, -10, "Holm Wood"),
                     (58, 22, "Ilyria's Grove"), (0, -88, "Temple of Al'quimelea"), (0, -58, "Sacred Way")]:
    spot(places, "place", (x, 0, z), text=text)


def write():
    out = ["[gd_scene load_steps=%d format=3]" % (len(SCRIPTS) + len(curves) + 1), ""]
    for path, sid in SCRIPTS:
        out.append('[ext_resource type="Script" path="res://scripts/map/%s.gd" id="%s"]' % (path, sid))
    out.append("")
    for c in curves:
        out.append(c)
        out.append("")
    out.append('[node name="Fontanova" type="Node3D"]\nscript = ExtResource("root")\nplay_half = 166.0\nland_half = 170\nforest_wall = false\ngrass = 0.8\nroughness = 3.6\ncalm_radius = 30.0\nlook = "fontanova"')
    out.append("")
    for n in nodes:
        out.append(n)
        out.append("")
    with open(OUT, "w") as f:
        f.write("\n".join(out))
    print("wrote", OUT, len(nodes), "nodes")


if __name__ == "__main__":
    write()
