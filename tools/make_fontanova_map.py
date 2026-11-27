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
ACRO_Y = 34.0
TEMPLE_Y = ACRO_Y
RIM_Y = 19.0
RIDGE_Y = 21.0
WATCH_Y = 28.0
WOOD_Y = 20.0
GROTTO_Y = 11.6

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


def road(name, parent, points, width, cut=False, draw=True, blend=None, chasm=False):
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
    if chasm:
        lines.append("chasm = true")
    nodes.append("\n".join(lines))


def spot(parent, kind, at, text=None, on_ground=True):
    props = {"kind": kind}
    if text:
        props["text"] = text
    if not on_ground:
        props["on_ground"] = False
    node(kind.capitalize(), parent, "spot", at, **props)


def fonta(name, parent, kind, at, yaw_deg=None, **props):
    if yaw_deg is not None:
        at = (at[0], at[1], at[2], yaw_deg)
    return node(name, parent, "fonta", at, kind=kind, **props)


# --- The land ------------------------------------------------------------------------------------
# Heights (the sea is at -0.2): the Landing's beach 0-2; the olive terraces climbing from 3 to 14 in
# shelves; the Ravine rim and the village shelf at 18-19; the Holm Wood's height 20; the West Ridge 21,
# Kerys' Watch on it 28; the Acropolis 34, sheer all round but for the Sacred Way.
land = group("Land")
fonta("Isle", land, "isle", (0, 0, 0), size=ISLE_R, wide=ISLE_WOBBLE, shore="PackedFloat32Array(%s)" % ", ".join("%.1f" % r for r in SHORE), on_ground=False)
# The long rise from the cove to the foot of the Acropolis, and swells across it.
for (x, z, h, r) in [(0, -30, 10.0, 52.0), (-24, 10, 4.0, 26.0), (30, 8, 4.0, 24.0), (40, -40, 5.0, 20.0), (-30, -48, 5.0, 18.0)]:
    node("Rise", land, "hill", (x, 0, z), height=h, radius=r)
# The olive terraces: shelves 2.2 m apart from the cove up to the plateau.
fonta("OliveTerraces", land, "terraces", (0, 0, 30), size=52.0, wide=2.2, on_ground=False)
fonta("UpperTerraces", land, "terraces", (8, 0, -22), size=30.0, wide=2.2, on_ground=False)
# The Acropolis: a crag of limestone, its top levelled for the temple court.
fonta("Acropolis", land, "mesa", (0, ACRO_Y, -88), size=29.0, wide=6.0, on_ground=False)
node("TempleCourt", land, "level", (0, ACRO_Y, -86), size="Vector2(50, 38)", blend=4.0)
# The Ravine rim: the high shelf on the near side of the Ravine, the village below it.
fonta("RavineRim", land, "mesa", (-50, RIM_Y, -10), size=17.0, wide=5.0, stretch=2.1, on_ground=False, yaw_deg=90)
# The West Ridge over the sea, Kerys' Watch a crag on top of it.
fonta("WestRidge", land, "mesa", (-94, RIDGE_Y, -8), size=28.0, wide=4.0, stretch=2.5, on_ground=False, yaw_deg=90)
fonta("WestRidgeSouth", land, "mesa", (-92, RIDGE_Y - 3.0, 40), size=15.0, wide=4.0, stretch=1.4, on_ground=False, yaw_deg=70)
fonta("KerysWatch", land, "mesa", (-104, WATCH_Y, -22), size=9.0, wide=3.0, on_ground=False)
fonta("AcropolisWest", land, "mesa", (-22, ACRO_Y - 6.0, -96), size=14.0, wide=5.0, on_ground=False)
fonta("AcropolisEast", land, "mesa", (24, ACRO_Y - 4.0, -100), size=13.0, wide=5.0, on_ground=False)
# The Holm Wood's height in the east, the Oracle's Grotto cut into it.
fonta("HolmHeight", land, "mesa", (84, WOOD_Y, -22), size=21.0, wide=8.0, stretch=1.3, on_ground=False, yaw_deg=90)
# The northern crags either side of the Acropolis, and the headlands round the cove.
fonta("NorthEastCrag", land, "mesa", (60, 24.0, -98), size=15.0, wide=5.0, on_ground=False)
fonta("NorthWestCrag", land, "mesa", (-58, 22.0, -98), size=14.0, wide=5.0, on_ground=False)
fonta("EastHeadland", land, "mesa", (88, 15.0, 92), size=13.0, wide=4.0, on_ground=False)
fonta("WestHeadland", land, "mesa", (-62, 11.0, 96), size=11.0, wide=4.0, on_ground=False)
# The Ravine: a sheer cleft from the northern crags down to the sea at its cove, the sea far below in it.
road("Ravine", land, [(-60, -7.0, -90), (-62, -7.0, -56), (-65, -7.0, -24), (-66, -7.0, 10), (-70, -7.0, 40), (-82, -7.0, 68), (-96, -7.0, 84)],
     8.0, cut=True, draw=False, blend=1.0, chasm=True)

# --- Roads and paths -----------------------------------------------------------------------------
roads = group("Roads")
road("LandingPath", roads, [(4, 1.2, 92), (6, 2.6, 78), (2, 4.4, 62), (0, 6.6, 44)], 3.6)
road("OliveWay", roads, [(0, 6.6, 44), (-4, 9.0, 20), (0, 11.4, -6), (2, 12.0, -30), (0, 11.5, -40)], 3.6)
# The Sacred Way: the only way up the Acropolis, a processional stair carved straight up its south
# face, a landing halfway (FontaBuilder.sacred_stair draws the steps).
road("SacredWay", roads, [(0, 11.5, -40), (0, 22.0, -55), (0, 23.0, -59), (0, ACRO_Y, -74)], 6.0, cut=True, blend=1.0, draw=False)
# Up onto the Ravine rim from the village, and up onto the Holm Wood's height.
road("RimPath", roads, [(-20, 8.8, 20), (-28, 12.0, 14), (-34, 16.0, 8), (-40, RIM_Y, 2)], 3.4, cut=True, blend=2.5)
road("WatchPath", roads, [(-86, RIDGE_Y, 2), (-96, WATCH_Y - 0.5, -14)], 3.0, cut=True, blend=2.0)
road("WoodPath", roads, [(0, 11.4, -6), (30, 12.0, -8), (48, 14.0, -6), (60, 17.0, -4), (70, WOOD_Y, -2)], 3.2, cut=True, blend=2.5)
road("CoveShore", roads, [(-34, 1.1, 94), (4, 1.2, 92), (40, 1.2, 94)], 3.0)


# --- The Landing ---------------------------------------------------------------------------------
landing = group("Landing")
fonta("Sailboat", landing, "sailboat", (14, 0, 86, 172), size=26.0)
fonta("ShoreCrates", landing, "shore_crates", (0, 0, 68, 20))
fonta("ShoreCrates", landing, "shore_crates", (-12, 0, 70, -35))
fonta("Amphorae", landing, "amphorae", (26, 0, 70))
for (x, z) in [(-2, 70), (6, 68), (-8, 72), (10, 72)]:
    spot(landing, "start", (x, 0, z))
for (x, z, s) in [(118, 104, 16.0), (128, 88, 12.0), (-112, 102, 14.0), (-124, 84, 10.0), (60, -128, 13.0), (-40, -132, 11.0), (132, -40, 12.0)]:
    fonta("SeaStack", landing, "sea_stack", (x, 0, z, x * 7 % 360), size=s, on_ground=False)
for (x, z, s) in [(64, 92, 4.0), (78, 80, 5.0), (-48, 92, 3.5), (-58, 82, 4.5), (40, 96, 2.5), (-24, 100, 3.0)]:
    fonta("Limestone", landing, "limestone", (x, 0, z, x * 13 % 360), size=s)

# --- The olive terraces --------------------------------------------------------------------------
groves = group("Groves")
colossus = group("FallenColossus")
fonta("ColossusHead", colossus, "god_head", (24, 0, 10, 205), size=5.0, variant=1)
fonta("ColossusHand", colossus, "god_hand", (33, 0, 2, 60), size=5.5)
fonta("ColossusBody", colossus, "fallen_god", (30, 0, 18, 120), size=9.0, variant=1)
for (x, z) in [(17, 2), (31, 26)]:
    fonta("BrokenColumn", colossus, "broken_column", (x, 0, z, x * 9 % 360), size=6.0)
fonta("WaysideStele", groves, "stele", (-6, 0, 30, 160), size=2.2, variant=2)
fonta("WaysideAltar", groves, "altar", (8, 0, -14, 200))

# --- The Ravine rim and the Worshippers' Village ---------------------------------------------------
village = group("WorshippersVillage")
for (x, z, yaw, length, high) in [(-52, -10, 0, 8.0, 2.6), (-52, -2, 0, 8.0, 1.8), (-56, -6, 90, 8.0, 2.2), (-48, -6, 90, 8.0, 1.2),
                                  (-40, 6, 0, 7.0, 2.4), (-40, 12, 0, 7.0, 1.6), (-43.5, 9, 90, 6.0, 2.0), (-48, 14, 0, 6.0, 1.4),
                                  (-38, -16, 90, 7.0, 2.2), (-34, -20, 0, 6.0, 1.5)]:
    fonta("RuinWall", village, "ruin_wall", (x, 0, z, yaw), size=length, wide=high)
fonta("ShrineAltar", village, "altar", (-42, 0, -4, 180))
fonta("Stele", village, "stele", (-39, 0, -6, 200), size=2.4, variant=0)
for (x, z) in [(-54, 4), (-44, 0), (-36, 10)]:
    fonta("Amphorae", village, "amphorae", (x, 0, z))
fonta("Cauldron", village, "cauldron", (-46, 0, -12), size=1.3)
ridge = group("WestRidge")
fonta("RavineBridgeNorth", ridge, "rope_bridge", (-64, 0, -28, 90), size=20.0, on_ground=False)
fonta("RavineBridgeSouth", ridge, "rope_bridge", (-66, 0, 8, 90), size=20.0, on_ground=False)
fonta("Kerys", ridge, "god_statue", (-104, 0, -22, 70), size=6.0, variant=4)
fonta("Orvane", ridge, "fallen_god", (-94, 0, 34, 110), size=6.0, variant=3)
for (x, z, s) in [(-108, -40, 5.0), (-100, 18, 4.0), (-86, -54, 5.5), (-110, 44, 4.5), (-82, 20, 3.0)]:
    fonta("Limestone", ridge, "limestone", (x, 0, z, x * 17 % 360), size=s)

# --- The Holm Wood and the Oracle's Grotto -------------------------------------------------------
wood = group("HolmWood")
fonta("OraclesGrotto", wood, "grotto", (72, GROTTO_Y, -24, -90), size=26.0, wide=5.0, on_ground=False)
fonta("Ilyria", wood, "god_statue", (58, 0, 22, 220), size=6.0, variant=2)
for (x, z, s) in [(96, 40, 4.0), (108, -16, 5.0), (90, -62, 4.5), (60, -40, 3.5)]:
    fonta("Limestone", wood, "limestone", (x, 0, z, x * 3 % 360), size=s)

# --- The Acropolis: the Temple of Al'quimelea ----------------------------------------------------
acro = group("Acropolis")
fonta("TempleOfAlquimelea", acro, "temple", (0, TEMPLE_Y, -94, 0), size=26.0, wide=18.0, on_ground=False)
fonta("Alquimelea", acro, "god_statue", (0, TEMPLE_Y, -80, 0), size=9.0, variant=0, on_ground=False)
for (x, z, yaw, v) in [(-18, -80, 130, 1), (19, -82, 230, 2), (-17, -100, 60, 3), (18, -101, 300, 4)]:
    fonta("FallenGod", acro, "fallen_god", (x, TEMPLE_Y, z, yaw), size=6.0, variant=v, on_ground=False)
fonta("GodHead", acro, "god_head", (-12, TEMPLE_Y, -74, 160), size=3.2, variant=0, on_ground=False)
for (x, z) in [(12, -75), (-21, -90), (21, -92)]:
    fonta("Cauldron", acro, "cauldron", (x, TEMPLE_Y, z), size=1.6, on_ground=False)
for (x, z) in [(-8, -76), (8, -76)]:
    fonta("Altar", acro, "altar", (x, TEMPLE_Y, z, 0), on_ground=False)
fonta("SacredStair", acro, "sacred_stair", (0, 0, -40, 0), size=34.0, wide=6.0, on_ground=False)
# The Sacred Way's columns, two by two up the stair, some fallen.
for k, z in enumerate([-44, -50, -61, -67]):
    for side in (-1, 1):
        broken = (k + (side > 0)) % 3 == 1
        fonta("SacredColumn", acro, "broken_column" if broken else "column", (side * 4.6, 0, z), size=6.5)
for (x, z) in [(-6, -74), (6, -74)]:
    fonta("Cypress", acro, "cypress", (x, TEMPLE_Y, z), size=11.0, on_ground=False)
for (x, z) in [(-8, -40), (8, -40)]:
    fonta("Stele", acro, "stele", (x, 0, z, 180), size=2.2, variant=0)

# --- The lesser gods' altars: one wakes now and then in the night (FontaRites) ----------------------
altars = group("GodAltars")
fonta("Thaleon", altars, "god_statue", (-34, 0, 78, 200), size=6.0, variant=1)
fonta("ThaleonAltar", altars, "god_altar", (-30, 0, 72, 200), variant=1)
fonta("IlyriaAltar", altars, "god_altar", (54, 0, 17, 220), variant=2)
fonta("OrvaneAltar", altars, "god_altar", (-89, 0, 29, 110), variant=3)
fonta("KerysAltar", altars, "god_altar", (-99, 0, -17, 70), variant=4)

# --- The archipelago, far out at sea -------------------------------------------------------------
far = group("Archipelago")
for (x, z, s) in [(-232, -70, 70.0), (205, -150, 80.0), (150, 205, 55.0), (-190, 175, 50.0), (30, -240, 90.0)]:
    fonta("HorizonIsle", far, "horizon_isle", (x, 0, z, x % 360), size=s, on_ground=False)

# --- The hives: where the night's beehives grow ----------------------------------------------------
hives = group("Hives")
for (x, z) in [(-14, 44), (22, 52), (-46, -26), (40, -28), (60, 2), (-24, -40)]:
    spot(hives, "hive", (x, 0, z))

# --- Versus: where rivals begin ------------------------------------------------------------------
rivals = group("Rivals")
for (x, z) in [(0, 70), (-24, 30), (30, 30), (-46, -6), (60, -10), (0, -30), (-96, 0), (84, -24)]:
    spot(rivals, "rival", (x, 0, z))

# --- Supplies ------------------------------------------------------------------------------------
loot = group("Loot")
for (x, z) in [(-46, 2), (-40, 10), (8, 80), (26, 6), (-66, -36), (-66, 14), (0, -84), (14, -90), (-14, -90), (60, 18), (-100, -10), (96, 6), (-104, -22)]:
    spot(loot, "loot", (x, 0, z))
for (x, z) in [(0, 0), (-50, 40), (50, -40), (-40, -40), (40, 50)]:
    spot(loot, "poi", (x, 0, z))

# --- Names on the map screen ---------------------------------------------------------------------
places = group("Places")
for (x, z, text) in [(10, 84, "The Landing"), (-46, -2, "Worshippers' Village"), (26, 10, "Fallen Colossus"), (0, 30, "Olive Terraces"),
                     (-66, -10, "The Ravine"), (-104, -22, "Kerys' Watch"), (60, -24, "Oracle's Grotto"), (88, -10, "Holm Wood"),
                     (58, 22, "Ilyria's Grove"), (0, -92, "Temple of Al'quimelea"), (0, -56, "Sacred Way")]:
    spot(places, "place", (x, 0, z), text=text)

# --- Everything that grows: planted last, round all of the above ---------------------------------
fonta("Flora", ".", "flora", (0, 0, 0), size=140.0, on_ground=False)


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
