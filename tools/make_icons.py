#!/usr/bin/env python3
"""Draws every icon in the game as a small painted picture, all original. Each picture is SVG, turned
into PNG by rsvg-convert. Coordinates are 0-100. Run from the project root:  python3 tools/make_icons.py
Plain names (sword, flame) sit on a dark disc in the game. crest_* are classes and spec_* are
specializations: they have their own outline, and no disc."""
import os, subprocess, sys, tempfile, math

OUT = "assets/icons"
INK = "#12141c"
_defs = {}

def grad(a, b):
    key = f"g{a[1:]}{b[1:]}"
    _defs[key] = f'<linearGradient id="{key}" x1="0.2" y1="0" x2="0.8" y2="1"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
    return f"url(#{key})"

STEEL = ("#f0f4fa", "#8c98af"); DSTEEL = ("#a4adc0", "#4d566b"); WOOD = ("#c08a52", "#6f4522"); GOLD = ("#ffe68a", "#c9831c")
FIRE = ("#ffb52e", "#e2301a"); HOT = ("#fff6b0", "#ffb52e"); RED = ("#ff7a6b", "#a61b1b"); GREEN = ("#a8ea72", "#2c8a3c")
TOX = ("#d4f75e", "#4b991d"); ICE = ("#dcf8ff", "#55aeea"); MIST = ("#dcfdf8", "#58c2bd"); VIO = ("#dca6ff", "#6a2fc2")
BONE = ("#fff8e4", "#c7b58b"); DARK = ("#59627a", "#232836"); ROCK = ("#b3a89b", "#5b5249"); BLUE = ("#8fc4ff", "#2a5fc2")
LEATHER = ("#a56b3a", "#55321a"); PINK = ("#ffc0c8", "#e0617a"); BRASS = ("#f2c96a", "#8f5f1e"); NIGHT = ("#3d3a63", "#15132b")

def f(c):
    return grad(*c) if isinstance(c, tuple) else c

def poly(c, *pts, w=3.2):
    return f'<polygon points="{" ".join(f"{x},{y}" for x, y in pts)}" fill="{f(c)}" stroke="{INK}" stroke-width="{w}" stroke-linejoin="round"/>'

def path(c, d, w=3.2):
    return f'<path d="{d}" fill="{f(c)}" stroke="{INK}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>'

def circ(c, x, y, r, w=3.2):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{f(c)}" stroke="{INK}" stroke-width="{w}"/>'

def ell(c, x, y, rx, ry, rot=0, w=3.2):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" transform="rotate({rot} {x} {y})" fill="{f(c)}" stroke="{INK}" stroke-width="{w}"/>'

def rect(c, x, y, w_, h, r=1.5, w=3.2):
    return f'<rect x="{x}" y="{y}" width="{w_}" height="{h}" rx="{r}" fill="{f(c)}" stroke="{INK}" stroke-width="{w}"/>'

def line(c, wid, *pts, ink=True):
    d = " ".join(f"{x},{y}" for x, y in pts)
    out = ""
    if ink:
        out = f'<polyline points="{d}" fill="none" stroke="{INK}" stroke-width="{wid + 5}" stroke-linecap="round" stroke-linejoin="round"/>'
    return out + f'<polyline points="{d}" fill="none" stroke="{c}" stroke-width="{wid}" stroke-linecap="round" stroke-linejoin="round"/>'

def curve(c, wid, d, ink=True):
    out = ""
    if ink:
        out = f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{wid + 5}" stroke-linecap="round"/>'
    return out + f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{wid}" stroke-linecap="round"/>'

def at(x, y, s, inner, rot=0):
    return f'<g transform="translate({x} {y}) rotate({rot}) scale({s}) translate(-50 -50)">{inner}</g>'

def turn(deg, inner):
    return f'<g transform="rotate({deg} 50 50)">{inner}</g>'

# Weapons and things held
def sword():
    return (poly(STEEL, (50, 5), (58, 18), (58, 64), (42, 64), (42, 18)) + line("#7a859c", 2, (50, 18), (50, 60), ink=False)
        + rect(GOLD, 28, 63, 44, 8) + rect(LEATHER, 44, 71, 12, 15) + circ(GOLD, 50, 90, 6))
def dagger():
    return poly(STEEL, (50, 8), (61, 38), (56, 60), (44, 60), (39, 38)) + rect(GOLD, 33, 59, 34, 7) + rect(LEATHER, 45, 66, 10, 17) + circ(GOLD, 50, 87, 5)
def axe():
    return line("#9a6a3a", 7, (63, 12), (38, 92)) + path(STEEL, "M50 12 C34 6 18 14 12 28 C10 40 16 50 30 56 L44 34 L60 24 Z")
def spear():
    return line("#a8743e", 6, (20, 86), (66, 34)) + poly(STEEL, (88, 11), (79, 36), (68, 37), (63, 26), (64, 20)) + line("#c9402e", 4, (62, 40), (54, 52), ink=False)
def lance():
    return poly(("#ff8a7a", "#a81d1d"), (92, 7), (40, 52), (50, 62)) + poly(STEEL, (46, 47), (56, 57), (34, 74), (26, 66)) + line("#a8743e", 7, (28, 72), (12, 88))
def mace():
    return line("#9a6a3a", 7, (22, 88), (58, 44)) + poly(STEEL, (72, 8), (76, 22), (92, 18), (84, 32), (94, 44), (78, 44), (72, 58), (64, 44), (48, 40), (60, 30), (56, 14), (66, 22))
def flail():
    return line("#9a6a3a", 7, (14, 90), (42, 56)) + line("#b9c2d2", 3, (42, 56), (52, 40), (62, 34)) + poly(DSTEEL, (72, 8), (76, 18), (90, 14), (86, 28), (96, 36), (84, 42), (84, 56), (72, 48), (60, 54), (60, 40), (50, 30), (64, 26))
def scythe():
    return line("#9a6a3a", 7, (66, 92), (54, 14)) + path(STEEL, "M54 12 C36 4 16 12 8 34 C22 22 38 22 56 28 Z")
def pitchfork():
    return line("#a8743e", 7, (50, 92), (50, 42)) + line("#d9dfeb", 6, (26, 10), (26, 34), (50, 42), (74, 34), (74, 10)) + line("#d9dfeb", 6, (50, 8), (50, 42))
def torch():
    return line("#9a6a3a", 8, (30, 90), (56, 46)) + rect(DARK, 50, 38, 16, 10, 2) + path(FIRE, "M58 4 C66 14 80 20 76 36 C72 46 52 46 48 36 C46 26 56 20 58 4Z") + path(HOT, "M60 20 C64 26 70 30 67 38 C63 42 56 42 54 37 C53 32 59 28 60 20Z", 0)
def bow():
    return curve("#a8743e", 7, "M36 6 C78 24 78 76 36 94") + line("#eef2f8", 2, (36, 6), (36, 94), ink=False) + line("#d9dfeb", 3.4, (12, 50), (84, 50)) + poly(STEEL, (96, 50), (80, 41), (80, 59))
def crossbow():
    return line("#7d5430", 8, (50, 94), (50, 22)) + curve("#b9c2d2", 7, "M12 44 C26 16 74 16 88 44") + line("#eef2f8", 2, (12, 44), (50, 56), (88, 44), ink=False) + poly(STEEL, (50, 4), (43, 20), (57, 20))
def staff():
    return line("#8a5f35", 7, (18, 92), (58, 40)) + curve("#9a6a3a", 6, "M58 40 C52 20 68 8 80 14 C92 22 84 40 72 36") + circ(ICE, 72, 26, 8)
def hammer():
    return line("#9a6a3a", 8, (18, 92), (56, 42)) + poly(DSTEEL, (50, 14), (88, 42), (68, 66), (30, 38))
def bell():
    return path(GOLD, "M50 8 C66 8 72 22 72 38 C72 54 78 62 88 72 L12 72 C22 62 28 54 28 38 C28 22 34 8 50 8Z") + circ(BRASS, 50, 84, 7) + rect(GOLD, 42, 4, 16, 8, 3)
def shield():
    return path(STEEL, "M50 6 L86 18 C88 54 76 78 50 94 C24 78 12 54 14 18Z") + rect(RED, 44, 22, 12, 54, 1, 0) + rect(RED, 28, 36, 44, 12, 1, 0)
def shield_rect():
    return rect(DSTEEL, 22, 6, 56, 88, 5) + rect(GOLD, 45, 14, 10, 72, 1, 0) + rect(GOLD, 30, 34, 40, 10, 1, 0) + "".join(circ("#dfe5ef", x, y, 3, 1.2) for x, y in [(30, 14), (70, 14), (30, 86), (70, 86)])
def shield_round():
    return circ(WOOD, 50, 50, 44) + circ("none", 50, 50, 33, 2) + circ(STEEL, 50, 50, 15) + "".join(circ("#dfe5ef", 50 + 38 * math.cos(a * .785), 50 + 38 * math.sin(a * .785), 2.4, 1) for a in range(8))
def helm():
    return path(STEEL, "M16 88 L16 42 C16 16 84 16 84 42 L84 88 L60 88 L60 56 L40 56 L40 88Z") + rect(INK, 22, 44, 56, 8, 1, 0) + rect(GOLD, 45, 14, 10, 30, 1, 0)
def arrow():
    return line("#a8743e", 5, (16, 84), (72, 28)) + poly(STEEL, (92, 8), (80, 40), (60, 20)) + poly(("#ff8a7a", "#a81d1d"), (6, 76), (24, 66), (34, 76), (24, 94), (20, 80))
def arrows():
    return "".join(line("#a8743e", 4, (x, 90), (x, 26)) + poly(STEEL, (x, 6), (x - 9, 28), (x + 9, 28)) for x in (22, 50, 78))
def dart():
    return line("#9fb06a", 4, (18, 82), (66, 34)) + poly(TOX, (86, 14), (64, 24), (76, 36)) + poly(RED, (10, 76), (26, 74), (26, 90))
def lock():
    return curve("#b9c2d2", 8, "M30 50 L30 30 C30 4 70 4 70 30 L70 50") + rect(GOLD, 18, 46, 64, 46, 6) + circ(INK, 50, 64, 7, 0) + rect(INK, 47, 66, 6, 14, 1, 0)
def turret():
    return line("#6d7790", 6, (50, 56), (22, 92)) + line("#6d7790", 6, (50, 56), (78, 92)) + rect(DSTEEL, 32, 32, 34, 26, 4) + line("#b9c2d2", 8, (62, 40), (94, 26)) + circ(RED, 42, 44, 4, 1.4)
def trap():
    upper = path(DSTEEL, "M6 50 C6 12 94 12 94 50 L82 50 C82 28 18 28 18 50Z") + "".join(poly(STEEL, (x - 6, y), (x, y + 18), (x + 6, y)) for x, y in [(30, 30), (50, 25), (70, 30)])
    lower = path(DSTEEL, "M6 50 C6 88 94 88 94 50 L82 50 C82 72 18 72 18 50Z") + "".join(poly(STEEL, (x - 6, y), (x, y - 18), (x + 6, y)) for x, y in [(30, 70), (50, 75), (70, 70)])
    return upper + lower + circ(RED, 50, 50, 7) + circ(STEEL, 10, 50, 7) + circ(STEEL, 90, 50, 7)
def net():
    out = ""
    for i in range(5):
        out += line("#e8dcc0", 2.6, (10 + 20 * i, 10), (10 + 20 * i, 90)) + line("#e8dcc0", 2.6, (10, 10 + 20 * i), (90, 10 + 20 * i))
    return out + "".join(circ(LEATHER, x, y, 4, 1.6) for x, y in [(10, 10), (90, 10), (10, 90), (90, 90)])
def spikes():
    return "".join(poly(STEEL, (x - 12, 88), (x, 16 + (0 if x == 50 else 16)), (x + 12, 88)) for x in (22, 50, 78)) + rect(DARK, 8, 84, 84, 8, 1)
def bomb():
    return circ(DARK, 44, 60, 32) + circ("#8c97ad", 32, 48, 6, 0) + line("#a8743e", 4, (62, 34), (76, 18)) + poly(HOT, (84, 4), (86, 13), (96, 12), (88, 19), (92, 28), (84, 22), (76, 28), (78, 18), (70, 12), (80, 12))
def flask():
    return path("#dfeaf5", "M40 6 L60 6 L60 34 L88 84 C90 92 84 94 80 94 L20 94 C14 94 10 92 12 84 L40 34Z") + path(TOX, "M28 60 L72 60 L84 86 C84 90 82 90 80 90 L20 90 C18 90 16 90 16 86Z", 0) + circ("#fff", 42, 76, 4, 0) + circ("#fff", 60, 70, 3, 0)
def potion():
    return rect(WOOD, 42, 4, 16, 12, 2) + path("#dfeaf5", "M42 16 L58 16 L58 32 C76 38 84 52 84 64 C84 82 68 94 50 94 C32 94 16 82 16 64 C16 52 24 38 42 32Z") + path(RED, "M20 62 C30 56 70 56 80 62 C80 80 66 90 50 90 C34 90 20 80 20 62Z", 0) + circ("#fff", 38, 72, 4, 0)
def poison():
    bottle = rect(LEATHER, 41, 2, 18, 12, 2) + path(("#3e4a33", "#171d14"), "M42 14 L58 14 L58 28 C76 36 86 50 86 66 C86 84 70 96 50 96 C30 96 14 84 14 66 C14 50 24 36 42 28Z")
    return bottle + at(50, 62, 0.5, skull()) + path(TOX, "M70 34 C74 42 82 48 80 58 C72 54 66 46 66 38Z", 0)
def orb():
    return circ(VIO, 50, 42, 32) + circ("#fff", 40, 30, 7, 0) + path(DARK, "M22 94 C24 76 34 72 50 72 C66 72 76 76 78 94Z")
def mirror():
    return ell(GOLD, 50, 38, 28, 34) + ell(ICE, 50, 38, 19, 25, 0, 1.5) + line("#fff", 3, (40, 26), (50, 18), ink=False) + rect(GOLD, 44, 70, 12, 24, 3)
def book():
    return path(("#c74a3e", "#6d1a1a"), "M8 20 C24 12 40 14 50 24 C60 14 76 12 92 20 L92 84 C76 76 60 78 50 88 C40 78 24 76 8 84Z") + path("#f6efdc", "M14 26 C26 20 40 22 47 30 L47 78 C40 70 26 70 14 74Z", 1.5) + path("#f6efdc", "M86 26 C74 20 60 22 53 30 L53 78 C60 70 74 70 86 74Z", 1.5)
def banner():
    return line("#a8743e", 6, (24, 94), (24, 6)) + path(RED, "M26 10 L88 10 L72 30 L88 52 L26 52Z") + poly(GOLD, (46, 20), (50, 30), (60, 31), (52, 37), (55, 46), (46, 41), (38, 46), (41, 37), (34, 31), (43, 30))
def chain():
    return "".join(ell(STEEL, x, y, 21, 13, 40) + ell("#232836", x, y, 11, 4, 40, 0) for x, y in [(24, 26), (50, 50), (76, 74)])
def log():
    return "".join(ell(WOOD, 50, y, 42, 10, -24) for y in (30, 52, 74))
def horseshoe():
    return path(STEEL, "M26 90 L14 90 C4 40 20 10 50 10 C80 10 96 40 86 90 L74 90 C82 50 70 28 50 28 C30 28 18 50 26 90Z") + "".join(circ(INK, x, y, 2.4, 0) for x, y in [(19, 70), (17, 50), (26, 30), (81, 70), (83, 50), (74, 30)])
def chariot():
    return path(("#c98a3e", "#6d4522"), "M14 28 L54 28 L60 62 L18 62Z") + line("#8a5f35", 6, (56, 52), (94, 36)) + circ(WOOD, 34, 70, 21) + circ(DARK, 34, 70, 6) + line("#3b2a18", 3, (34, 52), (34, 88), ink=False) + line("#3b2a18", 3, (16, 70), (52, 70), ink=False)
def war_chariot():
    # Side on: an iron car with a raised front, one big spoked wheel with a scythe at the hub, and the pole.
    spokes = "".join(line("#f2c96a", 3.4, (38 + 19 * math.cos(math.radians(d)), 66 + 19 * math.sin(math.radians(d))), (38 - 19 * math.cos(math.radians(d)), 66 - 19 * math.sin(math.radians(d)))) for d in (0, 45, 90, 135))
    return (line("#5a3a1e", 7, (66, 50), (97, 28))
        + path(DARK, "M8 28 L56 28 L64 14 L80 14 L74 58 L12 58Z")
        + path(STEEL, "M58 28 L64 14 L80 14 L74 58 L62 58Z")
        + line("#f2c96a", 3, (14, 36), (54, 36), ink=False)
        + poly(STEEL, (38, 62), (0, 52), (8, 72))
        + circ(DARK, 38, 66, 26) + circ(("#3a4150", "#1c2029"), 38, 66, 19) + spokes + circ(BRASS, 38, 66, 6.5))
def noisebox():
    return rect(WOOD, 16, 44, 40, 38, 3) + poly(STEEL, (52, 38), (84, 18), (84, 92), (52, 76)) + curve("#ffe68a", 4, "M62 8 C50 14 42 20 34 40", ink=False)
def magnet():
    return path(RED, "M16 14 L38 14 L38 54 C38 72 62 72 62 54 L62 14 L84 14 L84 56 C84 100 16 100 16 56Z") + rect(STEEL, 16, 12, 22, 14) + rect(STEEL, 62, 12, 22, 14)
def gear():
    return gearshape(50, 50, 40, 8, BRASS) + circ(NIGHT[1], 50, 50, 11)
def gearshape(cx, cy, r, teeth, col):
    pts = []
    for i in range(teeth * 4):
        a = i * math.pi * 2 / (teeth * 4) - math.pi / teeth / 2
        rr = r if i % 4 in (0, 1) else r * .75
        pts.append((round(cx + rr * math.cos(a), 1), round(cy + rr * math.sin(a), 1)))
    return poly(col, *pts)
# Elements and marks
def flame():
    return path(FIRE, "M50 4 C56 22 82 34 82 62 C82 82 66 96 50 96 C34 96 18 82 18 62 C18 46 28 38 32 26 C38 32 40 38 42 40 C46 28 44 16 50 4Z") + path(HOT, "M52 44 C56 56 68 60 66 74 C64 86 56 90 50 90 C42 90 34 84 34 74 C34 62 48 58 52 44Z", 0)
def snow():
    return "".join(turn(a, line("#c9f2ff", 6, (50, 8), (50, 92)) + line("#c9f2ff", 4, (38, 18), (50, 30), (62, 18), ink=False)) for a in (0, 60, 120))
def bolt():
    return poly(("#fff8a0", "#f0a31c"), (62, 4), (20, 56), (46, 56), (34, 96), (82, 38), (54, 38))
def drop():
    return path(("#ff7a6b", "#9c1616"), "M50 6 C60 28 82 46 82 64 C82 82 68 94 50 94 C32 94 18 82 18 64 C18 46 40 28 50 6Z") + path("#ffd0c8", "M34 62 C34 72 40 78 46 80", 3)
def heart():
    return path(RED, "M50 92 C20 68 6 52 6 32 C6 16 18 8 30 8 C40 8 46 14 50 22 C54 14 60 8 70 8 C82 8 94 16 94 32 C94 52 80 68 50 92Z") + ell("#ffc0b8", 28, 28, 8, 5, -30, 0)
def skull():
    return path(BONE, "M50 6 C24 6 12 26 14 46 C15 58 22 64 28 68 L28 86 L72 86 L72 68 C78 64 85 58 86 46 C88 26 76 6 50 6Z") + circ(INK, 35, 48, 11, 0) + circ(INK, 65, 48, 11, 0) + poly(INK, (50, 58), (43, 72), (57, 72)) + "".join(rect(INK, x, 76, 3, 11, 0, 0) for x in (40, 49, 58))
def bones():
    def b(): return line("#fff4d8", 9, (20, 20), (80, 80)) + circ(BONE, 14, 22, 7, 2.4) + circ(BONE, 22, 14, 7, 2.4) + circ(BONE, 86, 78, 7, 2.4) + circ(BONE, 78, 86, 7, 2.4)
    return b() + turn(90, b())
def ghost():
    return path(MIST, "M50 6 C26 6 16 26 16 46 L16 92 L28 80 L39 92 L50 80 L61 92 L72 80 L84 92 L84 46 C84 26 74 6 50 6Z") + ell(INK, 37, 42, 7, 10, 0, 0) + ell(INK, 63, 42, 7, 10, 0, 0) + ell(INK, 50, 62, 6, 8, 0, 0)
def claw():
    return "".join(path(MIST, f"M{x} 6 C{x + 14} 34 {x + 14} 62 {x - 2} 94 C{x + 2} 62 {x - 6} 34 {x} 6Z") for x in (18, 42, 66))
def tooth():
    return path(BONE, "M16 10 C30 2 40 14 50 14 C60 14 70 2 84 10 C92 34 76 48 72 88 C66 96 60 76 50 66 C40 76 34 96 28 88 C24 48 8 34 16 10Z")
def wolf():
    return poly(("#b8bcc8", "#4f5362"), (14, 4), (32, 26), (68, 26), (86, 4), (90, 48), (66, 72), (50, 96), (34, 72), (10, 48)) + poly("#f4f1e8", (34, 56), (50, 94), (66, 56), (50, 64)) + poly(("#ffe68a", "#e6a11c"), (26, 40), (42, 44), (32, 50)) + poly(("#ffe68a", "#e6a11c"), (74, 40), (58, 44), (68, 50)) + circ(INK, 50, 84, 4, 0)
def raven():
    return path(NIGHT, "M6 44 C22 30 34 34 44 40 C50 22 66 12 78 20 L96 28 L80 32 C78 50 68 66 48 72 L34 92 L34 72 C22 70 12 58 6 44Z") + circ(("#ffe68a", "#e6a11c"), 72, 24, 3.4, 1.2) + curve("#7a78b0", 3, "M16 46 C26 50 34 52 44 50", ink=False)
def snake():
    return curve("#5da048", 13, "M20 92 C60 96 88 80 74 66 C62 54 24 66 22 46 C20 28 56 34 66 26") + path(GREEN, "M60 16 C74 8 92 14 92 26 C92 36 76 38 62 34 Z") + circ("#ffe14a", 78, 22, 3.6, 1.2) + line("#d9342b", 2.6, (92, 28), (98, 34), ink=False)
def fox():
    return poly(("#ffa24a", "#c4561a"), (10, 6), (32, 28), (68, 28), (90, 6), (88, 50), (50, 94), (12, 50)) + poly("#fbf3e4", (18, 50), (50, 92), (82, 50), (58, 58), (50, 70), (42, 58)) + circ(INK, 34, 42, 4.4, 0) + circ(INK, 66, 42, 4.4, 0) + circ(INK, 50, 90, 5, 0)
def rat():
    return path(("#a8a095", "#514a42"), "M8 66 C14 40 40 30 62 36 C72 32 86 42 94 58 C80 66 60 72 40 72 C26 72 14 70 8 66Z") + circ(PINK, 62, 32, 9) + circ(INK, 76, 46, 3.4, 0) + curve("#f0a0a8", 3.4, "M10 66 C2 76 8 90 26 86", ink=False)
def horse():
    return path(("#a56b3a", "#55321a"), "M26 94 C24 68 30 52 44 38 L30 44 L24 36 L40 14 L46 2 L54 12 C72 20 82 42 84 94Z") + path(DARK, "M46 4 C62 12 84 26 88 60 L78 70 C74 44 62 28 48 20Z", 2) + circ(INK, 38, 26, 3, 0)
def horn():
    return path(BONE, "M12 14 C10 46 30 76 64 80 L60 62 C40 58 26 40 28 16Z") + poly(GOLD, (60, 58), (92, 62), (92, 84), (66, 86))
def feather():
    return path(("#ffffff", "#9fb4cf"), "M84 8 C54 8 26 28 22 66 L16 88 L38 76 C70 74 88 44 84 8Z") + line("#59627a", 3, (16, 90), (66, 30), ink=False)
def wings():
    w = path(("#ffffff", "#b6c6dc"), "M50 46 C38 26 20 14 4 16 C4 30 8 36 14 42 C8 44 8 50 14 56 C24 62 38 62 50 58Z")
    return w + f'<g transform="translate(100 0) scale(-1 1)">{w}</g>'
def boot():
    return path(LEATHER, "M38 6 L68 6 L68 58 L92 76 L92 92 L24 92 L24 70 C30 58 36 44 38 6Z") + rect(GOLD, 36, 16, 34, 7, 1, 2)
def hand():
    return path(("#ffd8b0", "#c98a5a"), "M28 92 C20 76 14 62 16 50 C18 44 24 46 26 50 L26 22 C26 14 36 14 37 22 L37 14 C38 6 48 6 49 14 L50 22 C51 14 61 14 62 22 L62 30 C64 22 74 24 74 32 L74 62 C74 76 72 84 68 92Z")
def grab():
    return poly(STEEL, (50, 94), (16, 56), (34, 56), (34, 8), (66, 8), (66, 56), (84, 56))
def up():
    return poly(GREEN, (50, 6), (90, 52), (66, 52), (66, 94), (34, 94), (34, 52), (10, 52))
def plus():
    return poly(("#fff4c0", "#efb23c"), (38, 10), (62, 10), (62, 38), (90, 38), (90, 62), (62, 62), (62, 90), (38, 90), (38, 62), (10, 62), (10, 38), (38, 38))
def cross():
    return poly(("#fffbe9", "#d7c48e"), (40, 6), (60, 6), (60, 30), (86, 30), (86, 50), (60, 50), (60, 94), (40, 94), (40, 50), (14, 50), (14, 30), (40, 30))
def star():
    return poly(GOLD, (50, 6), (62, 36), (94, 38), (69, 58), (78, 90), (50, 72), (22, 90), (31, 58), (6, 38), (38, 36))
def crown():
    return poly(GOLD, (8, 26), (30, 50), (50, 14), (70, 50), (92, 26), (84, 84), (16, 84)) + rect(RED, 16, 66, 68, 7, 1, 0) + circ(RED, 8, 24, 5, 2) + circ(RED, 50, 12, 5, 2) + circ(RED, 92, 24, 5, 2)
def sun():
    return "".join(turn(a, poly(GOLD, (50, 4), (57, 22), (43, 22))) for a in range(0, 360, 45)) + circ(HOT, 50, 50, 25)
def moon():
    return path(("#fff7d6", "#b8bcd6"), "M62 6 C34 6 12 28 12 52 C12 78 34 94 58 94 C72 94 82 88 88 80 C60 86 40 70 40 46 C40 28 48 14 62 6Z")
def clock():
    return circ("#f6efdc", 50, 50, 42) + line("#2a2f3f", 6, (50, 26), (50, 52), (68, 62), ink=False) + "".join(circ("#59627a", 50 + 34 * math.cos(a * math.pi / 2), 50 + 34 * math.sin(a * math.pi / 2), 3, 0) for a in range(4))
def eye():
    return path("#f6f6f0", "M4 50 C24 16 76 16 96 50 C76 84 24 84 4 50Z") + circ(("#7fd0ff", "#1c64b8"), 50, 50, 19) + circ(INK, 50, 50, 8, 0) + circ("#fff", 44, 44, 4, 0)
def eye_closed():
    return curve("#dfe5ef", 7, "M6 42 C26 74 74 74 94 42") + "".join(line("#dfe5ef", 5, (x, y), (x2, y + 18)) for x, y, x2 in [(22, 62, 14), (40, 70, 36), (60, 70, 64), (78, 62, 86)])
def mask():
    return path(BONE, "M10 14 C36 22 64 22 90 14 C96 50 80 88 50 92 C20 88 4 50 10 14Z") + path(INK, "M22 36 C30 30 38 32 44 42 C36 48 26 46 22 36Z", 0) + path(INK, "M78 36 C70 30 62 32 56 42 C64 48 74 46 78 36Z", 0) + path(INK, "M30 62 C40 74 60 74 70 62 C60 66 40 66 30 62Z", 0)
def target():
    return circ("#f6f1e0", 50, 50, 44) + circ(RED, 50, 50, 31, 0) + circ("#f6f1e0", 50, 50, 19, 0) + circ(RED, 50, 50, 8, 0)
def spiral():
    return curve("#c9a6ff", 8, "M50 50 C56 42 66 50 60 60 C52 72 34 66 34 50 C34 28 62 22 76 38 C92 58 78 88 50 90 C24 90 8 70 12 46")
def burst():
    return poly(FIRE, *[(round(50 + (46 if i % 2 == 0 else 22) * math.cos(i * math.pi / 8), 1), round(50 + (46 if i % 2 == 0 else 22) * math.sin(i * math.pi / 8), 1)) for i in range(16)]) + circ(HOT, 50, 50, 13, 0)
def wind():
    return "".join(curve(c, 7, d) for c, d in [("#cfeff6", "M6 34 L58 34 C72 34 74 14 60 14 C52 14 50 22 54 26"), ("#a9dfe9", "M6 54 L78 54 C92 54 94 74 80 74 C72 74 70 66 74 62"), ("#cfeff6", "M16 74 L44 74 C54 74 56 88 46 90")])
def mist():
    return "".join(curve("#bff3ec", 8, f"M8 {y} C24 {y - 14} 36 {y + 14} 50 {y} C64 {y - 14} 76 {y + 14} 92 {y}") for y in (28, 52, 76))
def steam():
    return "".join(curve("#e3ecf2", 7, f"M{x} 92 C{x - 14} 74 {x + 14} 62 {x} 46 C{x - 14} 32 {x + 12} 22 {x} 8") for x in (26, 50, 74))
def quake():
    return poly(ROCK, (8, 92), (8, 54), (34, 40), (46, 62), (40, 92)) + poly(ROCK, (92, 92), (92, 50), (66, 38), (52, 62), (60, 92)) + "".join(line("#ffe68a", 5, a, b, ink=False) for a, b in [((50, 10), (50, 28)), ((28, 16), (34, 30)), ((72, 16), (66, 30))])
def rift():
    return path(VIO, "M56 4 C40 26 64 40 40 56 C30 66 50 74 42 96 C68 74 52 62 68 46 C78 34 56 26 56 4Z") + circ(ICE, 20, 30, 7) + circ(ICE, 82, 72, 7)
def blink():
    return "".join(line(c, 6, (x0, y), (x1, y), ink=False) for c, x0, x1, y in [("#9fe6ff", 6, 30, 30), ("#9fe6ff", 4, 36, 50), ("#9fe6ff", 6, 30, 70)]) + poly(ICE, (44, 12), (66, 12), (94, 50), (66, 88), (44, 88), (66, 50))
def jump():
    return curve("#ffe68a", 7, "M14 74 C24 22 68 22 80 56") + poly(GOLD, (90, 76), (66, 62), (88, 44)) + rect(ROCK, 6, 76, 88, 14, 2)
def leap():
    return curve("#bff3ec", 8, "M10 80 C14 22 68 14 80 46") + poly(MIST, (92, 68), (66, 54), (90, 34))
def swap():
    return curve("#bfe6ff", 7, "M14 44 C20 18 62 10 78 34") + poly(ICE, (90, 48), (64, 42), (86, 22)) + curve("#bfe6ff", 7, "M86 56 C80 82 38 90 22 66") + poly(ICE, (10, 52), (36, 58), (14, 78))
def shout():
    return poly(STEEL, (6, 38), (28, 38), (54, 16), (54, 84), (28, 62), (6, 62)) + "".join(curve("#ffe68a", 6, d) for d in ("M66 34 C74 44 74 56 66 66", "M78 20 C94 40 94 60 78 80"))
def pause():
    return rect("#f6f6f0", 22, 12, 20, 76, 4) + rect("#f6f6f0", 58, 12, 20, 76, 4)
def tree():
    # The button that opens the skill tree: three nodes under one.
    return line("#c9d2e2", 5, (50, 26), (24, 74)) + line("#c9d2e2", 5, (50, 26), (50, 74)) + line("#c9d2e2", 5, (50, 26), (76, 74)) + circ(GOLD, 50, 22, 13) + circ(GREEN, 22, 76, 12) + circ(RED, 50, 78, 12) + circ(BLUE, 78, 76, 12)

PLAIN = [sword, dagger, axe, spear, lance, mace, flail, scythe, pitchfork, torch, bow, crossbow, staff, hammer, bell, shield, shield_rect,
    shield_round, helm, arrow, arrows, dart, lock, turret, trap, net, spikes, bomb, flask, potion, poison, orb, mirror, book, banner, chain,
    log, horseshoe, chariot, noisebox, magnet, gear, flame, snow, bolt, drop, heart, skull, bones, ghost, claw, tooth, wolf, raven, snake, fox,
    rat, horse, horn, feather, wings, boot, hand, grab, up, plus, cross, star, crown, sun, moon, clock, eye, eye_closed, mask, target, spiral,
    burst, wind, mist, steam, quake, rift, blink, jump, leap, swap, shout, pause, tree]

# More symbols, made for what is new
def bo():
    return line("#a8743e", 8, (10, 90), (90, 10)) + "".join(line("#2a2f3f", 9, a, b, ink=False) for a, b in [((18, 82), (24, 76)), ((76, 24), (82, 18))])
def ki():
    return path(("#fff3b0", "#ff9e2e"), "M50 4 C70 22 86 40 80 64 C76 84 60 96 44 94 C24 92 12 76 16 58 C20 42 34 38 40 26 C44 34 46 40 50 42 C54 30 52 16 50 4Z") + curve("#7a3a0a", 5, "M50 76 C36 76 34 58 48 56 C58 56 58 66 52 66", ink=False)
def mountain():
    return poly(ROCK, (4, 90), (36, 28), (50, 50), (64, 18), (96, 90)) + poly("#f6f6f0", (64, 18), (54, 40), (62, 36), (68, 44), (74, 38)) + poly("#f6f6f0", (36, 28), (28, 44), (36, 42), (42, 48), (44, 42))
def wave():
    return path(ICE, "M6 74 C22 40 46 22 70 26 C86 30 92 44 84 56 C78 62 68 58 70 50 C60 50 54 66 60 80 L6 80Z")
def lotus():
    return "".join(turn(a, path(PINK, "M50 74 C34 56 38 28 50 10 C62 28 66 56 50 74Z")) for a in (-60, 60, -30, 30, 0)) + poly(GREEN, (10, 80), (50, 92), (90, 80), (50, 74))
def body_out():
    return path(DARK, "M30 94 L30 58 C30 46 38 42 44 40 C36 34 36 18 46 16 C58 14 60 34 52 40 C60 42 66 48 66 58 L66 94Z") + at(70, 28, 0.42, ghost())
def stalker():
    # A crouched shape in mid-bound over a gap.
    return path(("#7fe8dc", "#2d8f88"), "M8 66 C20 34 44 20 62 22 L72 10 L76 26 C86 30 92 38 92 44 L78 46 C70 52 60 54 52 54 L58 78 L44 72 L40 56 C30 60 20 66 8 66Z") + poly(ROCK, (2, 94), (2, 78), (30, 78), (22, 94)) + poly(ROCK, (98, 94), (98, 78), (68, 78), (76, 94))
def harrier():
    # A ray seen from above: broad wings and a whip of a tail.
    return path(("#e2fbf5", "#5fc2b8"), "M50 12 C58 24 66 30 96 34 C84 50 66 56 56 60 L52 92 L50 96 L48 92 L44 60 C34 56 16 50 4 34 C34 30 42 24 50 12Z") + ell("#ff6a3a", 42, 28, 4, 4, 0, 0) + ell("#ff6a3a", 58, 28, 4, 4, 0, 0)
for g in (bo, ki, mountain, wave, lotus, body_out, stalker, harrier):
    PLAIN.append(g)

# Purchases and weapons with a picture of their own
def longbow():
    return curve("#7d5430", 7, "M42 2 C68 26 68 74 42 98") + line("#eef2f8", 2, (42, 2), (42, 98), ink=False) + line("#d9dfeb", 3.4, (8, 50), (88, 50)) + poly(STEEL, (98, 50), (84, 42), (84, 58)) + poly(RED, (8, 50), (2, 42), (16, 46))
def bell_hammer():
    return line("#9a6a3a", 7, (20, 92), (54, 46)) + at(66, 32, 0.56, turn(40, bell()))
def javelins():
    return "".join(line("#a8743e", 4, (x0, 92), (x1, 28)) + poly(STEEL, (x1 + (x1 - x0) * .3, 8), (x1 - 7, 28), (x1 + 7, 28)) for x0, x1 in [(26, 34), (50, 50), (74, 66)])
def blowgun():
    return line("#7f8c3f", 8, (6, 86), (82, 18)) + "".join(line("#2a2f3f", 9, a, b, ink=False) for a, b in [((24, 70), (29, 65)), ((58, 40), (63, 35))]) + poly(TOX, (98, 4), (84, 12), (90, 20))
def rain():
    arrow_down = lambda x, y: line("#a8743e", 3.4, (x, y), (x, y + 22)) + poly(STEEL, (x, y + 36), (x - 7, y + 20), (x + 7, y + 20))
    return ell(RED, 50, 82, 44, 13) + ell("#f6f1e0", 50, 82, 28, 7, 0, 0) + arrow_down(22, 28) + arrow_down(50, 8) + arrow_down(78, 26) + arrow_down(36, 44) + arrow_down(64, 42)
def satchel():
    return path(LEATHER, "M14 40 C14 34 18 32 24 32 L76 32 C82 32 86 34 86 40 L86 88 C86 92 82 94 78 94 L22 94 C18 94 14 92 14 88Z") + curve("#7a4d26", 6, "M32 32 C32 8 68 8 68 32") + path(("#c08a52", "#7a4d26"), "M12 34 L88 34 L88 54 C70 66 30 66 12 54Z") + rect(GOLD, 44, 52, 12, 14, 2) + at(50, 80, 0.3, trap())
def flurry():
    return at(58, 50, 0.84, turn(30, sword())) + "".join(line("#9fd8ff", 5, a, b, ink=False) for a, b in [((4, 30), (28, 30)), ((2, 50), (24, 50)), ((6, 70), (26, 70))])
def rage():
    return at(50, 40, 0.92, flame()) + at(50, 60, 0.6, skull())
def shroud():
    return path(("#4c4a78", "#14132a"), "M50 4 C20 4 12 34 12 60 C12 78 8 88 4 96 L96 96 C92 88 88 78 88 60 C88 34 80 4 50 4Z") + path(INK, "M28 62 C28 34 72 34 72 62 C72 76 60 84 50 84 C40 84 28 76 28 62Z", 0) + ell("#ffe68a", 40, 60, 5, 3, 12, 0) + ell("#ffe68a", 60, 60, 5, 3, -12, 0)
def let_go():
    return at(38, 40, 0.62, turn(30, sword())) + poly(RED, (66, 88), (46, 62), (58, 62), (58, 40), (74, 40), (74, 62), (86, 62)) + rect(ROCK, 8, 88, 84, 8, 2)
for g in (let_go, longbow, bell_hammer, javelins, blowgun, rain, satchel, flurry, rage, shroud):
    PLAIN.append(g)

# Class crests: every class has its own outline, colour and picture.
def crest_infantry():
    return path(("#d9483a", "#7c1414"), "M50 3 L92 15 C95 56 80 82 50 97 C20 82 5 56 8 15Z", 4) + path("none", "M50 11 L84 21 C86 54 74 74 50 88 C26 74 14 54 16 21Z", 0) + at(50, 50, 0.72, sword())
def crest_ranger():
    return path(("#5fb24d", "#1c5a2c"), "M50 2 C80 18 94 44 86 66 C78 86 62 94 50 98 C38 94 22 86 14 66 C6 44 20 18 50 2Z", 4) + at(50, 50, 0.72, bow())
def crest_heavy():
    return rect(("#9aa5ba", "#3f485c"), 12, 3, 76, 94, 7, 4) + rect("none", 19, 10, 62, 80, 3, 2) + at(50, 50, 0.72, helm()) + "".join(circ("#e3e8f2", x, y, 3.2, 1.2) for x, y in [(19, 11), (81, 11), (19, 89), (81, 89)])
def crest_chivalry():
    return path(("#f4c94e", "#a86a10"), "M6 4 L94 4 L94 96 L50 74 L6 96Z", 4) + at(50, 40, 0.68, horse())
def crest_magician():
    return poly(("#a86bff", "#3a1786"), (50, 2), (92, 26), (92, 74), (50, 98), (8, 74), (8, 26)) + at(38, 54, 0.6, moon()) + at(64, 36, 0.42, star()) + at(66, 66, 0.22, star())
def crest_revenant():
    return path(("#3ec7c0", "#0e4d57"), "M50 3 C22 3 8 24 8 48 L8 98 L22 84 L36 98 L50 84 L64 98 L78 84 L92 98 L92 48 C92 24 78 3 50 3Z", 4) + at(50, 44, 0.62, skull())
def crest_artificer():
    return gearshape(50, 50, 49, 10, ("#d99a45", "#6d4315")) + circ(("#3a2a18", "#1b120a"), 50, 50, 30, 3) + at(50, 50, 0.56, turn(40, hammer()) + turn(-40, hammer()))
def crest_monk():
    return circ(("#ffb040", "#b25a10"), 50, 50, 47, 4) + circ(("#fff4d4", "#f4d18e"), 50, 50, 35, 3) + at(50, 52, 0.62, ki())
def crest_plague_doctor():
    return (poly(("#6c7e54", "#1f2a1a"), (28, 3), (72, 3), (97, 28), (97, 72), (72, 97), (28, 97), (3, 72), (3, 28))
        + path(("#3a3f4c", "#14161f"), "M14 90 C14 48 20 14 46 12 C70 10 78 26 78 40 L60 86Z")
        + path(BONE, "M28 34 C34 24 52 22 62 30 C70 42 84 58 92 80 C74 72 62 66 52 64 C40 66 30 60 28 50Z")
        + circ(("#ff8a7a", "#a61b1b"), 42, 40, 8) + circ("#ffd0c8", 40, 37, 2, 0) + rect(DARK, 24, 34, 8, 4, 1, 1.5))
def crest_adept():
    t = '<path d="M50 3 L95 80 Q97 94 84 96 L16 96 Q3 94 5 80Z" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % (grad("#5d6680", "#1e2230"), INK)
    return t + at(50, 36, 0.3, wind()) + at(31, 72, 0.3, mountain()) + at(69, 72, 0.3, flame())
def crest_commander():
    return lozenge("commander", at(50, 55, 0.68, banner()) + at(50, 23, 0.35, crown()))

def crest_bandit():
    # A plum hood-shaped shield with a masked eye-slit and a dagger point-down through it.
    return (path(("#a8577f", "#3d1430"), "M50 2 C74 10 92 28 92 52 C92 76 72 92 50 98 C28 92 8 76 8 52 C8 28 26 10 50 2Z", 4)
        + path(("#2a1020", "#0c0509"), "M18 44 C30 34 70 34 82 44 L78 56 C64 50 36 50 22 56Z", 2)
        + ell("#f2e2ff", 36, 48, 6, 3, 0, 0) + ell("#f2e2ff", 64, 48, 6, 3, 0, 0)
        + at(50, 62, 0.5, turn(180, dagger())))
CRESTS = [crest_bandit, crest_commander, crest_infantry, crest_ranger, crest_heavy, crest_chivalry, crest_magician, crest_revenant, crest_artificer, crest_monk, crest_plague_doctor, crest_adept]

# Beyond the Mists: two-handed and Mesenlla weapons
def greatsword():
    # Longer and broader than the Sword: a wide blade with a fuller, a straight bar guard and a two-hand grip.
    return (poly(STEEL, (50, 0), (61, 10), (61, 54), (39, 54), (39, 10)) + line("#7a859c", 3, (50, 10), (50, 50), ink=False)
        + rect(DSTEEL, 18, 53, 64, 7) + rect(LEATHER, 45, 60, 10, 28) + line("#2a2f3f", 2, (45, 70), (55, 70), ink=False) + line("#2a2f3f", 2, (45, 78), (55, 78), ink=False) + circ(BRASS, 50, 93, 6))
def battleaxe():
    return (line("#c08a52", 7, (64, 96), (40, 6)) + "".join(line("#a22a20", 8, a, b, ink=False) for a, b in [((60, 84), (62, 78)), ((44, 24), (45, 20))])
        + path(STEEL, "M44 16 C30 8 12 14 8 30 C6 44 14 58 28 66 C24 54 26 44 34 38 L48 34 Z") + poly(DSTEEL, (48, 20), (64, 12), (52, 30)))
def chakram():
    teeth = "".join(turn(a, poly(MIST, (50, 2), (56, 14), (44, 14))) for a in (0, 90, 180, 270))
    return teeth + circ(MIST, 50, 50, 38) + circ("#12141c", 50, 50, 22, 0) + circ("none", 50, 50, 22, 3) + line("#7a4d26", 7, (32, 50), (68, 50)) + circ("#40f0e2", 50, 50, 6, 1.5)
for g in (greatsword, battleaxe, chakram):
    PLAIN.append(g)

# Beyond the Mists: the Cartographer and the Pathfinder's finds
AZURE = ("#9fd6ff", "#2a6fb8")
def beacon():
    # A survey post: a pole with a crossbar and a pennant, and a lit lamp on top.
    return (line("#c08a52", 7, (50, 94), (50, 28)) + line("#c08a52", 5, (34, 50), (66, 50))
        + path(("#ffe08a", "#e0a020"), "M52 30 L84 38 L52 46Z", 2.4) + circ(AZURE, 50, 20, 13) + circ("#ffffff", 46, 16, 4, 0) + rect(ROCK, 30, 88, 40, 8, 2))
def link():
    # Two posts and the line of light between them.
    return (line("#9fd6ff", 5, (22, 40), (78, 40), ink=False) + line("#ffffff", 2, (22, 40), (78, 40), ink=False)
        + line("#c08a52", 6, (22, 90), (22, 40)) + line("#c08a52", 6, (78, 90), (78, 40)) + circ(AZURE, 22, 34, 9) + circ(AZURE, 78, 34, 9))
def waygate():
    # A stone arch with a swirl of another world inside it.
    return (path(ROCK, "M14 94 L14 44 C14 14 86 14 86 44 L86 94 L70 94 L70 46 C70 30 30 30 30 46 L30 94Z")
        + path(("#e2f4ff", "#3d7fd0"), "M30 94 L30 46 C30 30 70 30 70 46 L70 94Z", 2) + curve("#ffffff", 4, "M50 82 C40 80 38 64 50 62 C60 62 60 72 52 72", ink=False))
def machete():
    # A broad, slightly hooked chopping blade with a wrapped grip.
    return (path(STEEL, "M30 70 L74 8 C88 10 92 22 84 34 L44 80Z") + line("#7a859c", 2.4, (42, 66), (78, 20), ink=False)
        + rect(DSTEEL, 26, 66, 22, 7, 2) + line("#5a3a1e", 9, (32, 74), (14, 94)) + "".join(line("#c08a52", 2.4, (a, b), (a + 6, b + 4), ink=False) for a, b in ((16, 86), (22, 80))))
def bolas():
    # Three weighted cords, tied in the middle.
    return ("".join(curve("#d8c9a6", 4, "M50 50 " + d) for d in ("C40 30 30 24 20 18", "C64 36 74 26 84 20", "C50 66 52 78 52 88"))
        + circ(ROCK, 20, 18, 11) + circ(ROCK, 84, 20, 11) + circ(ROCK, 52, 86, 11) + circ(LEATHER, 50, 50, 7))
def lantern():
    # A brass lantern with a warm light inside.
    return (curve("#8f5f1e", 5, "M38 22 C38 6 62 6 62 22") + rect(BRASS, 32, 20, 36, 8, 2) + rect(("#fff6c0", "#ffb52e"), 34, 28, 32, 46, 3)
        + line("#8f5f1e", 3, (50, 28), (50, 74), ink=False) + rect(BRASS, 28, 74, 44, 10, 2) + circ(HOT, 50, 50, 8, 0))
def compass():
    return circ(BRASS, 50, 50, 44) + circ("#f6efdc", 50, 50, 34, 2) + poly(RED, (50, 18), (58, 50), (42, 50)) + poly("#59627a", (50, 82), (58, 50), (42, 50)) + circ(BRASS, 50, 50, 5, 1.5)
# The Sunken Crown: the weapons of Vael
SEA_IRON = ("#b9c2c8", "#4a545c"); TARRED = ("#4a3c34", "#15110f"); SILVER = ("#ffffff", "#9aa3ae")
def cutlass():
    # A broad curved blade under a brass basket guard.
    return (path(STEEL, "M40 64 C46 40 58 18 80 6 C76 26 66 48 52 70 Z") + curve("#7a859c", 2.4, "M46 60 C52 42 62 26 74 14", ink=False)
        + path(BRASS, "M28 62 C34 52 56 56 60 68 C52 76 36 76 28 62 Z") + curve("#c9831c", 4, "M30 66 C26 76 30 90 40 92")
        + line("#3a2c22", 9, (44, 70), (36, 88)) + "".join(line("#ffe68a", 2.2, (a, b), (a + 7, b + 3), ink=False) for a, b in ((37, 76), (35, 82))) + circ(BRASS, 34, 92, 5))
def boarding_hook():
    # A hooked iron head on a short haft, and a few links of chain at its foot.
    return (line("#c08a52", 7, (34, 94), (52, 34)) + "".join(line("#2a2420", 8, a, b, ink=False) for a, b in (((36, 88), (38, 82)), ((40, 76), (42, 70))))
        + curve("#b9c2c8", 8, "M52 36 C50 14 70 4 82 14 C90 22 86 36 76 38") + poly(SEA_IRON, (70, 34), (80, 44), (82, 32))
        + circ("none", 30, 98, 4, 3) + circ("none", 24, 94, 4, 3))
def harpoon():
    # A whaling iron: a barbed head, a lashed shaft and a coil of rope at its tail.
    return (line("#c08a52", 6, (20, 86), (70, 30)) + poly(STEEL, (70, 30), (94, 6), (76, 38)) + poly(DSTEEL, (74, 26), (68, 18), (80, 22))
        + poly(DSTEEL, (78, 36), (86, 42), (82, 30)) + "".join(line("#2a2420", 6, a, b, ink=False) for a, b in (((62, 38), (66, 34)), ((58, 42), (62, 38))))
        + circ(("#e8d6a8", "#9c7f4a"), 20, 86, 11) + circ("none", 20, 86, 6, 2.4))
def flare_pistol():
    # A brass signal pistol, its wide muzzle spitting a red flare.
    return (rect(BRASS, 20, 34, 50, 18, 4) + path(BRASS, "M14 30 L22 30 L22 56 L14 56 Z") + path(("#a46a3a", "#4a2c16"), "M60 46 C66 60 72 74 70 88 L54 90 C54 74 52 62 48 50 Z")
        + curve("#c9831c", 3.4, "M48 54 C44 64 52 70 58 64") + circ(("#ffffff", "#ff5a3a"), 10, 22, 10) + circ(("#ffe6a0", "#ff8a2a"), 10, 22, 5, 0)
        + line("#ffb52e", 3, (4, 12), (0, 6), ink=False) + line("#ffb52e", 3, (20, 12), (24, 4), ink=False))
def anchor():
    # A ship's anchor: ring, stock, shank, and the crown with its two curved arms and flukes.
    return (circ("none", 50, 12, 8, 6) + circ("none", 50, 12, 8, 3) + rect(("#c08a52", "#6f4522"), 26, 22, 48, 9, 2)
        + line("#b9c2c8", 9, (50, 18), (50, 84)) + curve("#b9c2c8", 9, "M16 60 C18 82 34 90 50 88 C66 90 82 82 84 60")
        + poly(SEA_IRON, (8, 66), (16, 50), (24, 66)) + poly(SEA_IRON, (76, 66), (84, 50), (92, 66)))
def oar():
    # A long black oar with a broad blade edged in silver and the lamp of Vael painted on it.
    return (line("#3a302a", 7, (16, 94), (54, 46)) + rect(SILVER, 10, 88, 12, 10, 3)
        + path(TARRED, "M54 46 C58 30 72 8 86 6 C96 10 94 28 82 42 C74 52 62 56 54 46 Z") + curve("#e8eef6", 3, "M58 44 C64 30 74 14 86 10", ink=False)
        + path(("#fff2b0", "#e0a020"), "M72 30 C68 24 72 18 76 14 C78 20 80 26 76 30 Z", 1.6) + rect(("#e0b050", "#8f5f1e"), 68, 30, 12, 4, 1.4))
for g in (beacon, link, waygate, machete, bolas, lantern, compass):
    PLAIN.append(g)
for g in (cutlass, boarding_hook, harpoon, flare_pistol, anchor, oar):
    PLAIN.append(g)

def crest_cartographer():
    # An azure map sheet, folded in three, with a route to a star.
    return (poly(("#5aa6e8", "#163f78"), (6, 14), (36, 4), (64, 14), (94, 4), (94, 86), (64, 96), (36, 86), (6, 96))
        + line("#0f2f58", 2, (36, 4), (36, 86), ink=False) + line("#0f2f58", 2, (64, 14), (64, 96), ink=False)
        + curve("#fff1c8", 4, "M18 80 C30 60 44 74 52 56 C58 42 66 44 72 32", ink=False)
        + at(76, 26, 0.3, star()) + at(18, 80, 0.16, circ(RED, 50, 50, 40)))
CRESTS.append(crest_cartographer)

# Beyond the Mists: the creatures of Mesenlla
def bear():
    # A bear's head from the front: round ears, a pale muzzle and a dark nose.
    fur = ("#a5743f", "#4e3018")
    return (circ(fur, 24, 24, 13) + circ(fur, 76, 24, 13) + circ("#5a3a20", 24, 24, 6, 0) + circ("#5a3a20", 76, 24, 6, 0)
        + path(fur, "M14 52 C14 26 86 26 86 52 C86 78 70 92 50 92 C30 92 14 78 14 52Z")
        + ell(("#e2c49a", "#a07850"), 50, 68, 18, 14) + ell(INK, 50, 60, 7, 5, 0, 0) + circ(INK, 36, 46, 4, 0) + circ(INK, 64, 46, 4, 0))
def eagle():
    # Wings spread wide, white head, hooked yellow beak.
    brown = ("#8a5a30", "#3e2410")
    return (path(brown, "M50 46 C36 30 16 24 2 30 C10 38 14 44 22 46 C14 50 14 54 22 58 C32 60 44 58 50 56Z")
        + f'<g transform="translate(100 0) scale(-1 1)">{path(brown, "M50 46 C36 30 16 24 2 30 C10 38 14 44 22 46 C14 50 14 54 22 58 C32 60 44 58 50 56Z")}</g>'
        + path(brown, "M40 50 L60 50 L64 80 L50 90 L36 80Z") + circ(("#ffffff", "#c8ccd6"), 50, 38, 11) + poly(GOLD, (50, 40), (60, 46), (52, 52)) + circ(INK, 46, 35, 2, 0))
def antlers():
    # A stag's crown of antlers over a pale head.
    branch = lambda s: line("#efe6cf", 5, (50, 52), (50 + s * 22, 26), (50 + s * 30, 6)) + line("#efe6cf", 4, (50 + s * 22, 26), (50 + s * 40, 22)) + line("#efe6cf", 4, (50 + s * 14, 38), (50 + s * 30, 40))
    return branch(-1) + branch(1) + path(("#f4f2ea", "#b8b4a6"), "M38 50 C38 44 62 44 62 50 L58 84 C56 92 44 92 42 84Z") + circ("#5fd4ff", 44, 58, 3, 0) + circ("#5fd4ff", 56, 58, 3, 0)
def sprout():
    # A small hooded figure of leaves: two leaves and green eyes in a bark face.
    return (path(("#7cc456", "#2f6a1e"), "M50 6 C80 14 90 40 84 70 L16 70 C10 40 20 14 50 6Z")
        + path(("#a07850", "#5a3a20"), "M30 40 C30 30 70 30 70 40 L68 66 C60 74 40 74 32 66Z") + ell("#c8ff8a", 41, 50, 5, 3, 0, 0) + ell("#c8ff8a", 59, 50, 5, 3, 0, 0)
        + path(("#5aa83a", "#2f6a1e"), "M18 72 C24 92 44 96 50 92 C40 86 30 80 18 72Z") + path(("#5aa83a", "#2f6a1e"), "M82 72 C76 92 56 96 50 92 C60 86 70 80 82 72Z"))
def boulder():
    # Stones held together by a band of pale mist, with an amber eye.
    return (poly(ROCK, (14, 70), (20, 34), (46, 18), (74, 24), (90, 50), (82, 82), (50, 92), (24, 88)) + poly(("#8c8379", "#4a433d"), (46, 18), (60, 40), (90, 50), (74, 24))
        + path(("#7cc456", "#2f6a1e"), "M30 30 C40 22 52 22 58 28 C48 30 38 32 30 30Z", 2) + curve("#bff3ec", 5, "M10 58 C34 70 66 70 92 56", ink=False) + ell(("#ffe08a", "#e07a10"), 46, 52, 8, 5))
def storm():
    # A thundercloud with a bolt beneath it.
    return (path(("#9aa3b8", "#454c62"), "M18 54 C6 54 6 34 20 32 C22 16 44 10 54 22 C62 12 82 16 82 32 C96 32 96 54 82 54Z")
        + poly(("#ffffff", "#bfe0ff"), (52, 50), (36, 76), (50, 76), (40, 96), (66, 66), (52, 66), (62, 50)))
def wyvern():
    # A wyvern in flight from below: bat wings, a long neck and a barbed tail.
    green = ("#7ea46a", "#33482a")
    wing = "M50 44 C40 22 18 12 2 18 C6 30 12 34 8 46 C18 44 22 50 20 58 C32 52 40 54 50 56Z"
    return (path(("#6f5446", "#3a2a22"), wing) + f'<g transform="translate(100 0) scale(-1 1)">{path(("#6f5446", "#3a2a22"), wing)}</g>'
        + path(green, "M44 40 C44 26 56 26 56 40 L56 70 C56 76 44 76 44 70Z") + path(green, "M46 30 C46 18 54 18 54 30 L54 34 L46 34Z") + poly(green, (44, 14), (56, 14), (50, 4))
        + curve("#33482a", 5, "M50 74 C52 84 46 90 50 96", ink=False) + poly(BONE, (50, 98), (44, 90), (56, 90)) + circ("#ffb52e", 47, 12, 2, 0) + circ("#ffb52e", 53, 12, 2, 0))
def _ruff(cx, cy, rx, ry, spikes, deep, col):
    # A shaggy outline: points alternating out and in around an ellipse.
    pts = []
    for i in range(spikes * 2):
        a = math.pi * 2 * i / (spikes * 2) - math.pi / 2
        k = 1.0 if i % 2 == 0 else deep
        pts.append((round(cx + math.cos(a) * rx * k, 1), round(cy + math.sin(a) * ry * k, 1)))
    return poly(col, *pts)
def _bear_head(fur, ruff, muzzle, eyes, mouth="#5a1414", glow=None):
    # A bear's head from the front, snarling: a shaggy ruff, small round ears, a heavy brow, an open
    # mouth with fangs.
    out = circ(fur, 22, 22, 11) + circ(fur, 78, 22, 11) + circ(ruff[1], 22, 22, 5, 0) + circ(ruff[1], 78, 22, 5, 0)
    out += _ruff(50, 55, 44, 40, 13, 0.86, ruff)
    out += path(fur, "M20 50 C20 24 80 24 80 50 C80 74 66 88 50 88 C34 88 20 74 20 50Z")
    out += path(muzzle, "M34 66 C34 54 66 54 66 66 C66 80 58 88 50 88 C42 88 34 80 34 66Z")
    out += path(mouth, "M38 72 C42 84 58 84 62 72 C56 76 44 76 38 72Z", 2.4)
    out += poly("#fffbe8", (41, 73), (44, 81), (46.5, 74.5), w=1.6) + poly("#fffbe8", (53.5, 74.5), (56, 81), (59, 73), w=1.6)
    out += ell(INK, 50, 62, 7, 5, 0, 0)
    out += line(ruff[1], 3.2, (30, 40), (44, 46), ink=False) + line(ruff[1], 3.2, (70, 40), (56, 46), ink=False)
    if glow:
        out += circ(glow, 38, 49, 7, 0).replace("/>", ' opacity="0.45"/>') + circ(glow, 62, 49, 7, 0).replace("/>", ' opacity="0.45"/>')
    out += ell(eyes, 38, 49, 4.2, 3.2, 12, 1.6) + ell(eyes, 62, 49, 4.2, 3.2, -12, 1.6)
    return out
def bear():
    # A brown bear's head, snarling, in a shaggy ruff of fur.
    return _bear_head(("#a5743f", "#4e3018"), ("#7a5028", "#3a2410"), ("#d8b88c", "#9a7248"), ("#ffcf5a", "#d98a14"))
def mist_bear():
    # The Mist Bear: the same snarl in pale spectral fur, eyes burning cyan, mist curling below it.
    head = _bear_head(("#d4fbf6", "#4fa8a4"), ("#a8ece6", "#2c6e6c"), ("#f2fffd", "#9ed8d2"), ("#ffffff", "#5ff0ff"), "#1f4a50", "#9ff8ff")
    wisps = curve("#e6fffc", 5, "M4 90 C20 80 32 96 48 90 C64 84 76 98 96 88", ink=False) + curve("#bff3ec", 3.5, "M10 98 C26 92 40 100 56 96", ink=False)
    return head + wisps
def mist_eagle():
    # A Mist Eagle's head in profile: a hooked beak, a burning eye, its feathers trailing into mist.
    ghost = ("#e8fffc", "#55b8b3")
    return (path(ghost, "M30 30 C40 12 70 8 84 22 C94 32 96 50 88 60 C94 68 96 78 90 90 C80 84 72 82 62 86 C60 76 54 70 46 68 C36 66 30 58 30 48Z")
        + curve("#9fdcd6", 3, "M58 30 C70 34 78 44 80 56", ink=False) + curve("#9fdcd6", 3, "M52 46 C62 50 70 60 72 72", ink=False)
        + path(GOLD, "M32 32 C18 30 6 40 4 56 C10 50 16 48 22 50 C20 56 22 60 28 62 C30 52 34 46 40 44Z")
        + path(("#fff2a8", "#e0b030"), "M30 32 C34 30 40 32 42 36 C38 36 34 36 30 36Z", 2)
        + circ("#9ff8ff", 48, 38, 9, 0).replace("/>", ' opacity="0.45"/>') + circ(("#ffffff", "#5ff0ff"), 48, 38, 5.5, 2) + circ(INK, 49, 38, 2.2, 0)
        + line("#2c6e6c", 3, (38, 30), (58, 32), ink=False)
        + curve("#e6fffc", 5, "M62 92 C72 86 80 96 92 90", ink=False) + curve("#bff3ec", 3.5, "M70 99 C78 95 86 100 96 96", ink=False))
def mist_elemental():
    # A column of swirling mist round a glowing core, with two pale eyes in its hood.
    body = path(("#d8fffb", "#3a9e9a"), "M50 6 C70 8 82 26 78 44 C90 54 88 72 74 80 C70 90 58 96 50 96 C42 96 30 90 26 80 C12 72 10 54 22 44 C18 26 30 8 50 6Z")
    swirl = curve("#ffffff", 4, "M28 74 C20 56 40 42 56 50 C70 58 60 78 46 72", ink=False) + curve("#bff7f2", 3, "M70 30 C78 40 76 52 68 58", ink=False) + curve("#bff7f2", 3, "M24 34 C30 26 38 22 46 22", ink=False)
    core = circ("#ffffff", 50, 62, 15, 0).replace("/>", ' opacity="0.35"/>') + circ(("#ffffff", "#5fe3da"), 50, 62, 9, 2.4)
    eyes = (ell("#1f4a50", 40, 32, 7, 4.5, 14, 0) + ell("#1f4a50", 60, 32, 7, 4.5, -14, 0)
        + ell(("#ffffff", "#9ff8ff"), 40.5, 32, 4, 2.2, 14, 0) + ell(("#ffffff", "#9ff8ff"), 59.5, 32, 4, 2.2, -14, 0))
    return body + swirl + core + eyes
def storm_elemental():
    # A thunderhead with burning eyes, a body that is one bolt of lightning, and crackling arms.
    cloud = path(("#8c95ac", "#353b50"), "M14 50 C2 48 4 28 18 28 C18 12 40 6 50 18 C60 6 82 12 82 28 C96 28 98 48 86 50 C80 56 20 56 14 50Z")
    eyes = ell(("#ffffff", "#bfe0ff"), 38, 36, 6, 3, 12, 1.6) + ell(("#ffffff", "#bfe0ff"), 62, 36, 6, 3, -12, 1.6)
    body = poly(("#ffffff", "#7fc0ff"), (42, 52), (60, 52), (52, 68), (64, 68), (38, 98), (46, 74), (34, 74))
    arms = line("#cfe8ff", 3.2, (16, 52), (8, 64), (16, 66), (6, 82)) + line("#cfe8ff", 3.2, (84, 52), (92, 64), (84, 66), (94, 82))
    return arms + cloud + body + eyes
def woodland_cavalry():
    # A Child of the Woods riding a bear into battle, its spear couched across the bear's head.
    spear_shaft = line("#c08a52", 4, (8, 74), (84, 12))
    tip = poly(STEEL, (84, 12), (97, 2), (90, 18), w=2.4)
    rider = at(46, 24, 0.48, sprout())
    beast = at(50, 64, 0.74, _bear_head(("#a5743f", "#4e3018"), ("#7a5028", "#3a2410"), ("#d8b88c", "#9a7248"), ("#ffcf5a", "#d98a14")))
    return beast + rider + spear_shaft + tip
def daemon():
    # A horned daemon's head on bat wings, eyes burning and fangs bared.
    wing = "M40 46 C28 30 12 26 2 32 C8 40 10 46 8 54 C16 52 22 56 24 62 C30 56 36 54 42 56Z"
    red = ("#ff6a4a", "#8c1010")
    return (path(("#5a1a1a", "#250808"), wing) + f'<g transform="translate(100 0) scale(-1 1)">{path(("#5a1a1a", "#250808"), wing)}</g>'
        + path(BONE, "M30 32 C18 24 14 12 18 2 C24 12 32 16 40 22Z") + path(BONE, "M70 32 C82 24 86 12 82 2 C76 12 68 16 60 22Z")
        + path(red, "M26 42 C26 18 74 18 74 42 L72 64 C68 82 58 92 50 92 C42 92 32 82 28 64Z")
        + line("#4a0808", 3.4, (32, 42), (46, 48), ink=False) + line("#4a0808", 3.4, (68, 42), (54, 48), ink=False)
        + circ("#ffe066", 39, 52, 7, 0).replace("/>", ' opacity="0.4"/>') + circ("#ffe066", 61, 52, 7, 0).replace("/>", ' opacity="0.4"/>')
        + ell(("#fff6b0", "#ffb52e"), 39, 52, 5, 2.8, 15, 1.6) + ell(("#fff6b0", "#ffb52e"), 61, 52, 5, 2.8, -15, 1.6)
        + path("#3a0606", "M34 70 C42 80 58 80 66 70 C58 74 42 74 34 70Z", 2.2)
        + poly("#fffbe8", (38, 71), (41, 79), (43, 72.5), w=1.4) + poly("#fffbe8", (57, 72.5), (59, 79), (62, 71), w=1.4))
def invisible():
    # Someone who is there and isn't: a dashed outline of a figure, faintly filled, with glints of light.
    dash = 'stroke-dasharray="7 5"'
    fig = ('<g fill="#dcfdf8" fill-opacity="0.18">'
        + f'<circle cx="50" cy="28" r="13" stroke="{INK}" stroke-width="8" {dash}/>'
        + f'<path d="M24 94 C24 60 34 46 50 46 C66 46 76 60 76 94Z" stroke="{INK}" stroke-width="8" stroke-linejoin="round" {dash}/>'
        + f'<circle cx="50" cy="28" r="13" stroke="#dcfdf8" stroke-width="4" {dash}/>'
        + f'<path d="M24 94 C24 60 34 46 50 46 C66 46 76 60 76 94Z" stroke="#dcfdf8" stroke-width="4" stroke-linejoin="round" {dash}/></g>')
    return fig + at(82, 18, 0.3, star()) + at(16, 54, 0.22, star()) + at(86, 70, 0.16, star())
for g in (bear, mist_bear, eagle, mist_eagle, antlers, sprout, boulder, storm, wyvern, mist_elemental, storm_elemental, woodland_cavalry, daemon, invisible):
    PLAIN.append(g)

# Beyond the Mists: Mist Bastion's garrison
GLASS = ("#d8fffb", "#3fc4bc")
MSTEEL = ("#c9d8de", "#5a6c76")
def mist_infantry():
    # A rounded sallet with a glowing eye-slit and a crest of three mist-glass fins, over a kite shield.
    return (path(("#2f7f86", "#123a40"), "M24 54 L76 54 L72 80 L50 96 L28 80Z")
        + circ("none", 50, 72, 10, 3).replace('stroke="#12141c"', 'stroke="#bff7f2"')
        + poly(GLASS, (40, 22), (46, 4), (50, 22)) + poly(GLASS, (48, 20), (56, 2), (58, 22)) + poly(GLASS, (56, 22), (66, 8), (64, 26))
        + path(MSTEEL, "M22 52 C20 22 80 22 78 52 C82 56 84 62 76 62 L24 62 C16 62 18 56 22 52Z")
        + rect(INK, 30, 42, 40, 8, 2, 0) + rect(GLASS, 33, 44, 34, 4, 1, 0))
def mist_ranger():
    # A deep teal hood with a circlet of mist-glass, and a bow drawn across it.
    return (path(("#2b6b78", "#0f3038"), "M50 6 C80 10 92 44 86 90 L14 90 C8 44 20 10 50 6Z")
        + ell(INK, 50, 58, 22, 24, 0, 0) + ell(("#bff7f2", "#3fc4bc"), 41, 56, 4, 3, 0, 0) + ell(("#bff7f2", "#3fc4bc"), 59, 56, 4, 3, 0, 0)
        + curve("#bff7f2", 5, "M24 40 C40 30 60 30 76 40", ink=False) + poly(GLASS, (46, 34), (50, 24), (54, 34))
        + curve("#c08a52", 5, "M88 10 C64 34 64 66 88 92", ink=False) + line("#e9eef5", 1.6, (88, 10), (88, 92), ink=False))
def mist_heavy():
    # A closed great helm with a lit visor, crowned by two curved horns of mist-glass.
    return (path(GLASS, "M30 30 C20 22 16 10 22 2 C26 12 32 18 40 22Z") + path(GLASS, "M70 30 C80 22 84 10 78 2 C74 12 68 18 60 22Z")
        + path(MSTEEL, "M24 32 C24 16 76 16 76 32 L78 86 C70 94 30 94 22 86Z")
        + rect(INK, 26, 46, 48, 9, 2, 0) + rect(GLASS, 30, 48.5, 40, 4, 1, 0) + rect(MSTEEL, 46, 56, 8, 26, 1, 2))
# The Sunken Crown: the drowned of Port Vael and what the tide brings
SEA_SKIN = ("#5f8a90", "#1c3238"); KELP = ("#7aa84a", "#2a4a18"); BARN = ("#f2ead6", "#9c927c"); JELLY = ("#e6f6ff", "#7ab4d8")
def _barnacles(pts, r=4):
    return "".join(circ(BARN, x, y, r, 1.8) + circ("#5a554c", x, y, r * 0.4, 0) for x, y in pts)
def drowned_sailor():
    # A drowned sailor's head: a knitted cap gone green, weed hanging from it, sea-green eyes, a bubble rising.
    return (path(SEA_SKIN, "M24 46 C24 24 76 24 76 46 L74 70 C70 86 60 94 50 94 C40 94 30 86 26 70Z")
        + path(("#3a5a78", "#162a3c"), "M20 46 C18 22 32 8 50 8 C68 8 82 22 80 46 C70 40 30 40 20 46Z")
        + rect(("#4a6a8a", "#1e3448"), 18, 40, 64, 9, 3) + circ(("#c8443a", "#6a1a14"), 50, 8, 6)
        + curve("#5a8a3a", 4, "M24 48 C20 60 26 70 20 84", ink=False) + curve("#3e6a26", 3.5, "M78 48 C82 58 76 66 82 78", ink=False)
        + ell("#0e2228", 39, 60, 7, 4.5, 8, 0) + ell("#0e2228", 61, 60, 7, 4.5, -8, 0)
        + ell(("#e8fff6", "#5ff0c8"), 39, 60, 4, 2.4, 8, 0) + ell(("#e8fff6", "#5ff0c8"), 61, 60, 4, 2.4, -8, 0)
        + path("#0e2228", "M40 78 C46 82 54 82 60 78 C56 84 44 84 40 78Z", 2) + _barnacles([(70, 74), (75, 66)], 3.5)
        + circ("none", 88, 26, 5, 2.4) + circ("none", 92, 12, 3, 2))
def barnacle_brute():
    # A hulking shoulder and head crusted in barnacle shell, chain over it, eyes deep in the crust.
    return (path(("#8c8679", "#3a3630"), "M6 92 C6 56 20 34 50 30 C80 34 94 56 94 92Z")
        + path(SEA_SKIN, "M32 52 C32 30 68 30 68 52 L66 70 C62 82 38 82 34 70Z")
        + path(("#b0a892", "#5a554c"), "M28 44 C28 18 72 18 72 44 C62 36 38 36 28 44Z")
        + _barnacles([(18, 70), (28, 60), (14, 82), (82, 70), (74, 60), (86, 84), (40, 26), (54, 22), (64, 30)], 4.5)
        + line("#c8cdd2", 5, (10, 58), (30, 76), (52, 86), (74, 84), (92, 70))
        + ell(("#e8fff6", "#5ff0c8"), 42, 56, 4, 2.4, 10, 1.4) + ell(("#e8fff6", "#5ff0c8"), 58, 56, 4, 2.4, -10, 1.4)
        + path(("#e08070", "#8a2a20"), "M58 18 L66 2 L70 20Z", 2) + path(("#e08070", "#8a2a20"), "M44 16 L40 4 L50 14Z", 2))
def brine_hound():
    # A finned, eel-skinned hound's head in profile: a wide mouth of needles, a glowing eye, gill slits.
    return (path(SEA_SKIN, "M10 56 C12 36 34 26 56 28 C74 30 90 38 94 50 C88 54 80 54 72 56 C62 58 60 66 54 74 C44 80 26 80 16 72Z")
        + path(("#4a8a88", "#1a3a3a"), "M30 30 L36 6 L46 28 L54 8 L62 28 L74 14 L76 32Z", 2.4)
        + path("#3a0e10", "M94 50 C86 60 72 62 58 60 C70 66 84 66 92 58Z", 2) + "".join(poly(BONE, (x, 55), (x + 2.6, 62), (x + 5, 55), w=1.2) for x in (64, 70, 76, 82))
        + "".join(poly(BONE, (x, 63), (x + 2.4, 57), (x + 4.8, 63), w=1.2) for x in (67, 73, 79))
        + "".join(line("#0e2228", 2.6, (x, 48), (x - 4, 64), ink=False) for x in (30, 36, 42))
        + circ("#5ff0c8", 66, 40, 8, 0).replace("/>", ' opacity="0.4"/>') + circ(("#e8fff6", "#5ff0c8"), 66, 40, 5, 1.6) + circ(INK, 67, 40, 2, 0)
        + _barnacles([(22, 66), (28, 72)], 3.2))
def lantern_jelly():
    # A jelly's pale bell with a lantern burning inside it, and stinging threads trailing below.
    threads = "".join(curve(c, 3, d, ink=False) for c, d in (("#bfe6ff", "M24 56 C20 70 30 80 24 96"), ("#e6c6f2", "M38 58 C36 72 44 82 40 98"),
        ("#bfe6ff", "M62 58 C64 72 56 82 60 98"), ("#e6c6f2", "M76 56 C80 70 70 80 76 96"), ("#9ff8e0", "M50 60 C48 74 54 86 50 98")))
    bell = path(JELLY, "M12 56 C10 26 30 8 50 8 C70 8 90 26 88 56 C80 52 74 60 66 56 C60 60 54 56 50 60 C46 56 40 60 34 56 C26 60 20 52 12 56Z")
    lamp = (rect(("#5a4a3a", "#2a2018"), 40, 22, 20, 4, 1.4, 2) + rect(("#fff6b0", "#ffb52e"), 42, 26, 16, 18, 2, 2)
        + line("#2a2018", 2, (50, 26), (50, 44), ink=False) + rect(("#5a4a3a", "#2a2018"), 40, 44, 20, 4, 1.4, 2))
    glow = circ("#ffd070", 50, 35, 20, 0).replace("/>", ' opacity="0.35"/>')
    return threads + bell + glow + lamp
def angler():
    # A great-jawed angler with a glowing lure on a stalk over its head.
    return (curve("#2a3a40", 4, "M54 30 C56 14 70 6 82 10", ink=True)
        + circ("#ffe08a", 84, 16, 12, 0).replace("/>", ' opacity="0.4"/>') + circ(("#fffbe0", "#ffc040"), 84, 16, 7, 2)
        + path(SEA_SKIN, "M8 64 C8 40 26 26 52 28 C76 30 92 44 92 60 C80 62 60 64 40 62 C30 62 18 64 8 64Z")
        + path(("#8a9a90", "#3a4a44"), "M6 64 C20 70 50 72 94 62 C92 80 76 94 50 94 C26 94 8 82 6 64Z")
        + path("#3a0e10", "M14 64 C30 72 66 72 90 62 C82 68 60 76 40 74 C28 72 20 70 14 64Z", 2)
        + "".join(poly(BONE, (x, 64), (x + 3, 76), (x + 6, 65), w=1.2) for x in (20, 32, 46, 60, 74))
        + "".join(poly(BONE, (x, 72), (x + 3, 60), (x + 6, 71), w=1.2) for x in (26, 40, 54, 68))
        + circ(("#e8fff6", "#5ff0c8"), 30, 42, 3.4, 1.4) + circ(("#e8fff6", "#5ff0c8"), 46, 38, 3.4, 1.4) + _barnacles([(66, 36), (74, 42)], 3.2))
def tide():
    # The Mist Tide: a rolling wave with mist over it.
    return (path(("#7fd6c2", "#1e5a5a"), "M4 70 C14 40 40 30 58 40 C70 46 70 62 58 62 C50 62 50 52 56 50 C40 44 24 58 20 78 L4 78Z")
        + path(("#4aa8a0", "#163c40"), "M4 78 C24 70 40 86 60 78 C76 72 86 80 96 76 L96 96 L4 96Z")
        + curve("#dcfdf8", 4, "M22 22 C34 16 46 26 58 20 C68 15 78 22 90 18", ink=False) + curve("#bff3ec", 3, "M30 32 C40 28 52 34 64 30", ink=False))
for g in (drowned_sailor, barnacle_brute, brine_hound, lantern_jelly, angler, tide):
    PLAIN.append(g)

# The drowned court (stage 3)
PALE = ("#c8dcd8", "#5a7a78"); GOLDD = ("#e8c060", "#7a5418"); NAVY = ("#3a4c74", "#141c30"); OIL = ("#f2cc40", "#8a6410")
ROYAL = ("#6a3a7a", "#2a1032"); KRAK = ("#9a3c54", "#3a1020"); SUCK = ("#f2c8bc", "#a07068")
def _song(x, y):
    return "".join(curve("#bff7ec", 3, f"M{x - r} {y - r * 0.6} C{x - r * 0.3} {y - r} {x + r * 0.3} {y - r} {x + r} {y - r * 0.6}", ink=False) for r in (10, 16))
def siren():
    # A Siren singing: a thin pale face thrown back, mouth open, hair of kelp, rings of song rising.
    return (curve("#5a8a3a", 5, "M30 30 C18 50 26 70 16 94", ink=False) + curve("#3e6a26", 5, "M70 30 C82 50 74 70 84 94", ink=False)
        + path(PALE, "M32 40 C32 18 68 18 68 40 L66 64 C62 80 56 88 50 88 C44 88 38 80 34 64Z")
        + path(("#4a7a3a", "#1e3a14"), "M28 42 C26 16 40 8 50 8 C62 8 74 16 72 42 C64 30 36 30 28 42Z")
        + ell("#0e2228", 41, 50, 6, 3.6, 8, 0) + ell("#0e2228", 59, 50, 6, 3.6, -8, 0)
        + ell(("#e8fff6", "#5ff0c8"), 41, 50, 3.2, 2, 8, 0) + ell(("#e8fff6", "#5ff0c8"), 59, 50, 3.2, 2, -8, 0)
        + ell("#2a0a10", 50, 72, 5, 7, 0, 2) + _song(50, 10))
def press_gang():
    # A press-gang man: a tarred round hat, a drowned face, and a weighted net slung over a shoulder.
    return (path(("#a08458", "#4a3a20"), "M58 60 C80 56 94 70 92 92 L56 92Z") + "".join(circ(("#c49058", "#5a3a18"), x, y, 4, 1.6) for x, y in ((62, 64), (74, 62), (86, 70), (90, 84)))
        + line("#6a5434", 1.6, (60, 66), (90, 90)) + line("#6a5434", 1.6, (72, 62), (70, 92)) + line("#6a5434", 1.6, (84, 66), (58, 88))
        + path(SEA_SKIN, "M22 44 C22 24 62 24 62 44 L60 66 C56 80 50 86 42 86 C34 86 28 80 24 66Z")
        + path(("#2a2622", "#0a0806"), "M8 40 L76 40 L74 46 L10 46Z", 2.4) + path(("#3a3430", "#100c0a"), "M20 40 C20 18 64 18 64 40Z")
        + rect(("#8a2a20", "#3a0e08"), 20, 33, 44, 5, 1, 1.6)
        + ell(("#e8fff6", "#5ff0c8"), 34, 56, 3.4, 2.2, 8, 1.2) + ell(("#e8fff6", "#5ff0c8"), 50, 56, 3.4, 2.2, -8, 1.2)
        + path("#0e2228", "M34 72 C40 76 46 76 52 72", 2.6))
def tide_witch():
    # A Tide Witch: a crown of shells over kelp hair, a hooded drowned face, and her glowing float.
    return (path(("#3a5a2a", "#162a10"), "M18 92 C14 50 24 20 46 18 C68 20 78 50 74 92Z")
        + path(PALE, "M32 48 C32 32 60 32 60 48 L58 66 C54 78 38 78 34 66Z")
        + "".join(poly(("#f2e6d4", "#8a7a64"), (x - 5, 22), (x, 6 + abs(x - 46) * 0.3), (x + 5, 22), w=1.6) for x in (30, 46, 62))
        + ell(("#e8fff6", "#5ff0c8"), 40, 54, 3, 2, 0, 1.2) + ell(("#e8fff6", "#5ff0c8"), 52, 54, 3, 2, 0, 1.2)
        + line("#a8987a", 5, (86, 94), (80, 34)) + circ("#5ff0c8", 80, 24, 14, 0).replace("/>", ' opacity="0.35"/>') + circ(("#d8fff4", "#3ac4a4"), 80, 24, 8, 2))
def harbourmaster():
    # The Harbourmaster: a peaked cap with an anchor badge over grey whiskers, a hook on a chain.
    return (path(SEA_SKIN, "M26 46 C26 26 70 26 70 46 L68 68 C64 82 56 88 48 88 C40 88 32 82 28 68Z")
        + path(NAVY, "M22 42 C20 18 76 18 74 42Z") + path(("#1a1a1a", "#000"), "M18 42 L78 42 L70 50 L26 50Z", 2)
        + rect(GOLDD, 22, 36, 52, 5, 1, 1.4) + line("#e8c060", 3, (48, 22), (48, 34)) + line("#e8c060", 3, (43, 28), (53, 28))
        + path(("#d8dcd8", "#6a6e6a"), "M26 58 C24 74 32 84 38 84 L36 66Z", 1.8) + path(("#d8dcd8", "#6a6e6a"), "M70 58 C72 74 64 84 58 84 L60 66Z", 1.8)
        + ell(("#e8fff6", "#5ff0c8"), 40, 56, 3.4, 2.2, 8, 1.2) + ell(("#e8fff6", "#5ff0c8"), 56, 56, 3.4, 2.2, -8, 1.2)
        + line("#8a8e94", 3, (86, 4), (86, 14), (84, 22), (86, 30), (86, 58))
        + curve(("#c8ccd2"), 6, "M86 58 C86 78 70 80 68 66", ink=True) + poly(("#e8ecf0", "#6a6e74"), (66, 70), (68, 60), (72, 68), w=1.4))
def lighthouse_keeper():
    # The Mad Lighthouse Keeper: a yellow sou'wester, a wild white beard, lit spectacles, and his lamp held up.
    return (circ("#ffe08a", 80, 20, 18, 0).replace("/>", ' opacity="0.35"/>') + rect(GOLDD, 72, 8, 16, 4, 1, 1.4) + rect(("#fff6c0", "#ffc040"), 73, 12, 14, 16, 2, 1.6) + rect(GOLDD, 72, 28, 16, 4, 1, 1.4)
        + path(PALE, "M26 46 C26 28 66 28 66 46 L64 62 C60 72 32 72 28 62Z")
        + path(OIL, "M10 48 C14 24 28 14 46 14 C64 14 76 26 80 46 C70 40 22 40 10 48Z")
        + path(("#f4f4ee", "#9a9a94"), "M28 60 C26 84 38 96 46 96 C54 96 66 84 64 60 C58 68 34 68 28 60Z", 2)
        + circ(("#fff6c0", "#ffc040"), 37, 52, 6, 2) + circ(("#fff6c0", "#ffc040"), 55, 52, 6, 2) + line("#7a5418", 2, (43, 52), (49, 52)))
def kraken_arm():
    # A kraken's arm curling up out of the waves, suckers along its inner side.
    return (path(KRAK, "M30 96 C26 70 30 46 46 30 C58 18 76 16 84 26 C90 34 84 44 76 40 C70 36 74 30 68 30 C58 32 50 46 48 62 C46 76 50 88 54 96Z")
        + "".join(circ(SUCK, x, y, r, 1.4) for x, y, r in ((50, 86, 4), (49, 74, 3.8), (50, 62, 3.5), (54, 50, 3.2), (60, 40, 2.8), (68, 34, 2.4)))
        + path(("#7fd6c2", "#1e5a5a"), "M4 88 C18 80 30 92 46 86 C62 80 76 92 96 84 L96 98 L4 98Z")
        + curve("#dcfdf8", 3.4, "M8 84 C18 78 28 86 38 82", ink=False) + curve("#dcfdf8", 3.4, "M60 82 C70 78 80 86 92 80", ink=False))
def kraken():
    # The Kraken of Vael: its mantle reared out of the sea, the broken gold towers of drowned Vael grown
    # into its head with their windows lit, two great gold eyes barred with black, and arms curling up
    # out of the waves either side.
    arm_l = path(KRAK, "M2 94 C-2 70 6 46 20 40 C30 36 34 46 28 52 C24 56 18 52 20 46 C12 54 10 74 14 94Z")
    arm_r = path(KRAK, "M98 94 C102 70 94 46 80 40 C70 36 66 46 72 52 C76 56 82 52 80 46 C88 54 90 74 86 94Z")
    crown = "".join(poly(("#f0d27a", "#7a5a18"), (x - 5, 40), (x - 1, 40 - h), (x + 1, 40 - h), (x + 5, 40))
                    + rect(("#bfffe8", "#3ae0b0"), x - 1.6, 36 - h * 0.45, 3.2, 4, 0.5, 0) for x, h in ((32, 12), (41, 20), (50, 28), (59, 20), (68, 12)))
    return (arm_l + arm_r
        + path(KRAK, "M18 96 C14 72 20 48 34 40 C44 34 56 34 66 40 C80 48 86 72 82 96Z")
        + crown + rect(("#f0d27a", "#7a5a18"), 26, 38, 48, 6, 2, 1.6)
        + "".join(circ(SUCK, x, y, r, 1.2) for x, y, r in ((30, 84, 3), (70, 84, 3), (26, 72, 2.4), (74, 72, 2.4), (8, 62, 2.2), (92, 62, 2.2)))
        + ell(("#ffe07a", "#c87a10"), 36, 60, 8.5, 7.5, 0, 1.6) + ell(("#ffe07a", "#c87a10"), 64, 60, 8.5, 7.5, 0, 1.6)
        + rect("#14060a", 28.5, 58.6, 15, 2.8, 1, 0) + rect("#14060a", 56.5, 58.6, 15, 2.8, 1, 0)
        + path(("#2a1418", "#0a0204"), "M44 74 L56 74 L50 84Z", 1.4)
        + path(("#7fd6c2", "#1e5a5a"), "M2 88 C18 80 30 92 46 86 C62 80 76 92 98 84 L98 98 L2 98Z")
        + curve("#dcfdf8", 3.4, "M8 84 C18 78 28 86 38 82", ink=False) + curve("#dcfdf8", 3.4, "M60 82 C70 78 80 86 92 80", ink=False))
def hollow_sovereign():
    # The Hollow Sovereign: a deep royal hood with nothing inside it but two points of gold light.
    return (path(ROYAL, "M10 96 C8 56 22 18 50 16 C78 18 92 56 90 96Z")
        + path(("#ece8dc", "#8a867a"), "M12 90 C26 82 74 82 88 90 L90 98 L10 98Z", 2) + "".join(rect("#1a1a1a", x, 90, 3, 4, 0.5, 0) for x in (22, 36, 50, 64, 78))
        + path("#050508", "M30 74 C26 50 34 34 50 32 C66 34 74 50 70 74 C62 80 38 80 30 74Z", 2.4)
        + circ("#ffd070", 42, 54, 7, 0).replace("/>", ' opacity="0.35"/>') + circ("#ffd070", 58, 54, 7, 0).replace("/>", ' opacity="0.35"/>')
        + circ(("#fff6c0", "#ffc040"), 42, 54, 2.8, 0) + circ(("#fff6c0", "#ffc040"), 58, 54, 2.8, 0))
def sunken_crown():
    # The Sunken Crown: gold gone dull, pearl-tipped points, coral grown through it, a green stone.
    return (path(GOLDD, "M14 78 L12 34 L28 54 L36 22 L50 50 L64 22 L72 54 L88 34 L86 78Z")
        + rect(GOLDD, 12, 72, 76, 14, 2, 3) + rect(("#7ac8a8", "#2a5a48"), 14, 76, 72, 5, 1, 0)
        + "".join(circ(("#fbf6ec", "#a09888"), x, y, 4.2, 1.6) for x, y in ((12, 32), (36, 20), (64, 20), (88, 32)))
        + ell(("#7ff0b0", "#1a8a50"), 50, 66, 6, 7, 0, 2)
        + path(("#f08a78", "#8a2a20"), "M80 74 L86 52 L88 62 L94 50 L90 70Z", 1.6) + _barnacles([(22, 80), (30, 82)], 3))
for g in (siren, press_gang, tide_witch, harbourmaster, lighthouse_keeper, kraken_arm, kraken, hollow_sovereign, sunken_crown):
    PLAIN.append(g)

# The Harpooner (stage 5)
HEMP = ("#e8d6a8", "#9c7f4a")
def rope():
    # A coil of hemp line, three turns flat on the ground, its end trailing off to the side.
    return (ell(HEMP, 46, 58, 40, 30) + ell("none", 46, 58, 30, 22, 0, 3) + ell("none", 46, 58, 19, 13, 0, 3) + ell(("#4a3a20", "#2a2010"), 46, 58, 10, 6, 0, 2)
        + curve("#e8d6a8", 9, "M82 50 C92 40 92 22 78 16 C66 10 58 18 62 26") + curve("#9c7f4a", 3, "M84 46 C90 38 88 24 78 20", ink=False))
def crest_harpooner():
    # A navy shield shaped like a whale's tail fluke, a harpoon crossing it and a coil of line below.
    return (path(("#3f74a8", "#102640"), "M50 98 C46 82 44 70 40 62 C26 58 8 50 3 24 C18 28 32 22 42 8 C46 22 48 30 50 36 C52 30 54 22 58 8 C68 22 82 28 97 24 C92 50 74 58 60 62 C56 70 54 82 50 98Z", 4)
        + at(50, 50, 0.84, turn(-4, harpoon())))
for g in (rope,):
    PLAIN.append(g)
CRESTS.append(crest_harpooner)

# The Ferryman (stage 5)
def coin():
    # An obol: a worn silver coin stamped with the lamp of Vael.
    return (circ(("#e8eef6", "#7a8494"), 50, 50, 40, 4) + circ("none", 50, 50, 31, 3)
        + path(("#fff2b0", "#c08a1e"), "M50 26 C42 38 42 48 50 54 C58 48 58 38 50 26Z", 2) + rect(("#e0b050", "#8f5f1e"), 38, 56, 24, 8, 2)
        + "".join(circ(("#c8d0dc", "#7a8494"), 50 + 35 * c, 50 + 35 * s, 2.4, 0) for c, s in ((1, 0), (-1, 0), (0, 1), (0, -1))))
def skiff():
    # A pale ghostly skiff with a lantern on a pole at its stern, mist curling under it.
    return (path(("#d6f2ea", "#5a8a84"), "M2 40 C14 52 30 58 50 58 C70 58 86 52 98 40 C92 64 74 76 50 76 C26 76 8 64 2 40Z", 3) + curve("#5a8a84", 3, "M8 48 C26 58 74 58 92 48", ink=False)
        + line("#4a6a66", 4, (78, 54), (78, 14)) + line("#4a6a66", 3, (78, 16), (66, 16)) + rect(("#fff8c0", "#d0a030"), 60, 18, 12, 14, 3)
        + curve("#e8f6f4", 5, "M8 88 C22 80 34 94 50 86 C64 80 78 94 92 86", ink=False))
def soul():
    # A wisp: a pale flame-shaped soul with a trailing tail and two dark eyes.
    return (path(("#e8fff8", "#5ac8b0"), "M50 8 C66 26 78 44 72 62 C68 78 56 86 46 84 C30 82 22 66 30 50 C34 40 24 34 20 26 C34 30 42 22 50 8Z", 3)
        + ell(("#1a3a36", "#1a3a36"), 44, 58, 4, 6, 0, 1) + ell(("#1a3a36", "#1a3a36"), 58, 58, 4, 6, 0, 1))
def crest_ferryman():
    # A bone-white lozenge with the ferry's lantern over a coin and the oars crossed behind.
    return (path(("#e6dfc6", "#5a5240"), "M50 4 L94 50 L50 96 L6 50Z", 4) + at(50, 50, 0.62, turn(45, oar())) + at(50, 50, 0.62, turn(-45, oar()))
        + at(50, 40, 0.42, lantern()) + at(50, 70, 0.3, coin()))
for g in (coin, skiff, soul):
    PLAIN.append(g)
CRESTS.append(crest_ferryman)

# The Tidecaller (stage 5)
def song():
    # Two notes of the drowned's song rising out of a curl of water.
    return (path(ICE, "M6 86 C20 70 36 66 50 74 C62 80 76 80 94 68 L94 94 L6 94Z")
        + circ(("#9ff5e2", "#2a8a7a"), 30, 58, 10) + rect(("#9ff5e2", "#2a8a7a"), 37, 18, 6, 42, 2)
        + circ(("#9ff5e2", "#2a8a7a"), 66, 46, 10) + rect(("#9ff5e2", "#2a8a7a"), 73, 8, 6, 40, 2)
        + path(("#9ff5e2", "#2a8a7a"), "M40 18 L79 8 L79 18 L40 28Z", 2))
def trident_upright():
    # Upright: a coral-crusted haft, a bronze collar, and three barbed tines, the middle one longer.
    green = ("#8fe0c0", "#24584a")
    return (line("#6a5640", 7, (50, 98), (50, 44)) + "".join(circ(("#f07a6a", "#8a3028"), 50 + dx, y, 3.6, 1.4) for dx, y in ((-3, 86), (3, 76), (-3, 66)))
        + rect(("#d0aa52", "#6a4c1c"), 30, 38, 40, 9, 3)
        + line(green[0], 6, (34, 40), (34, 14)) + line(green[0], 6, (66, 40), (66, 14)) + line(green[0], 6, (50, 40), (50, 8))
        + poly(green, (28, 16), (34, 2), (40, 16)) + poly(green, (60, 16), (66, 2), (72, 16)) + poly(green, (44, 10), (50, -4), (56, 10)))
def trident():
    return at(50, 50, 0.92, turn(35, trident_upright()))
def crest_tidecaller():
    # A sea-green round shield with a wave curling over it and three tines rising from the crest.
    return (circ(("#36c6b8", "#0d4a46"), 50, 52, 44, 4) + at(50, 44, 0.62, trident_upright()) + at(50, 70, 0.6, wave()))
def shell():
    # Tide Shell: a dome of seawater over the ground, a curl of light running round it and drops
    # flying off its top.
    return (path(("#a8f4ea", "#1f7f78"), "M10 86 C10 44 28 18 50 18 C72 18 90 44 90 86Z", 3.6)
        + path(("#e6fffb", "#5fd8cc"), "M22 74 C24 50 36 34 52 30 C40 40 34 56 34 76Z", 0)
        + curve("#ffffff", 3.4, "M24 62 C40 48 62 46 78 58", ink=False)
        + line("#4ac0b2", 5, (4, 88), (96, 88))
        + circ(("#e6fffb", "#5fd8cc"), 30, 12, 4.4, 1.6) + circ(("#e6fffb", "#5fd8cc"), 70, 10, 3.6, 1.6) + circ(("#e6fffb", "#5fd8cc"), 50, 6, 3, 1.4))
def serpent():
    # A sea serpent's neck rearing out of a swirl of water: green scale, a finned crest that glows,
    # jaws open, a pale eye.
    scale_ = ("#3aa890", "#0e3a36"); fin_ = ("#8ff5d8", "#1c8f7a")
    return (path(scale_, "M30 92 C26 70 30 50 44 38 C52 30 54 22 52 14 L74 10 C86 12 92 22 88 32 L70 38 C60 44 52 58 50 72 C49 82 50 88 52 92Z")
        + path(("#d4ead0", "#6a8a66"), "M38 90 C36 74 40 58 50 48 L54 52 C48 62 46 76 46 90Z", 1.6)
        + path(fin_, "M46 40 L36 30 L48 34 L44 22 L54 28 L54 16 L60 24Z", 1.6)
        + path(("#2a0a10", "#0a0204"), "M70 38 L92 44 L86 32Z", 1.6)
        + ell(("#f0ffe0", "#8ff5d8"), 70, 22, 4, 2.4, -20, 1.4)
        + path(("#7fd6c2", "#1e5a5a"), "M6 90 C18 82 30 94 46 88 C62 82 76 94 94 86 L94 98 L6 98Z")
        + curve("#dcfdf8", 3, "M14 86 C24 80 34 88 42 84", ink=False))
for g in (song, trident, shell, serpent):
    PLAIN.append(g)
CRESTS.append(crest_tidecaller)

# Last Light (stage 4)
LEVI = ("#3a6a78", "#0e2630"); LEVI_BELLY = ("#b8d8c8", "#4a6a60")
def leviathan():
    # The Leviathan of the Mists: a great sea-serpent's neck rearing out of the waves, a finned crest,
    # jaws open over rows of teeth, and two cold green eyes.
    return (path(LEVI, "M20 96 C18 72 26 52 40 40 C48 32 52 24 50 16 L74 10 C86 14 92 24 88 34 L70 40 C58 46 50 58 46 72 C44 82 46 90 48 96Z")
        + path(LEVI_BELLY, "M30 94 C30 74 36 58 46 48 L52 52 C44 62 40 76 40 94Z", 1.6)
        + path(("#5aa0a8", "#163a44"), "M50 16 L44 4 L56 12 L58 2 L64 10 L70 0 L74 10Z", 1.6)
        + path(("#2a0a10", "#0a0204"), "M70 40 L94 46 L88 34Z", 1.6)
        + "".join(poly(("#f4f0e4", "#8a8474"), (x, 38 + (x - 70) * 0.25), (x + 2, 44 + (x - 70) * 0.25), (x + 4, 39 + (x - 70) * 0.25), w=1) for x in (72, 78, 84))
        + ell(("#e8fff6", "#5ff0c8"), 70, 24, 4.4, 2.6, -20, 1.4)
        + path(("#7fd6c2", "#1e5a5a"), "M4 88 C18 80 30 92 46 86 C62 80 76 92 96 84 L96 98 L4 98Z")
        + curve("#dcfdf8", 3.4, "M8 84 C18 78 28 86 38 82", ink=False) + curve("#dcfdf8", 3.4, "M60 82 C70 78 80 86 92 80", ink=False))
PLAIN.append(leviathan)
def leviathan_head():
    # Just the serpent's head and neck rising from a wave, for the Leviathan Hunter's emblem.
    return (path(LEVI, "M24 96 C22 70 30 50 46 40 C54 34 58 26 56 18 L80 12 C92 16 96 28 90 38 L72 44 C62 50 54 62 50 76 C48 86 50 92 52 96Z")
        + path(("#5aa0a8", "#163a44"), "M56 18 L50 6 L62 14 L66 4 L72 12Z", 1.6)
        + ell(("#e8fff6", "#5ff0c8"), 76, 26, 4.4, 2.6, -20, 1.4)
        + path(("#7fd6c2", "#1e5a5a"), "M4 88 C18 80 30 92 46 86 C62 80 76 92 96 84 L96 98 L4 98Z"))

for g in (mist_infantry, mist_ranger, mist_heavy):
    PLAIN.append(g)

def lodge_hunter():
    # A hunter of the Lodge in the Valleys: a moss-green hood trimmed with fur, a hunting horn on a
    # strap across the chest, and a bow drawn up behind.
    return (curve("#c08a52", 5, "M86 8 C62 32 62 66 86 92", ink=False) + line("#e9eef5", 1.6, (86, 8), (86, 92), ink=False)
        + path(("#5d7a3a", "#243a17"), "M50 6 C80 10 92 44 86 90 L14 90 C8 44 20 10 50 6Z")
        + path(("#d8c4a0", "#7a6040"), "M18 40 C30 26 70 26 82 40 C76 36 70 38 64 34 C58 38 52 32 46 36 C40 32 34 38 28 34 C24 38 20 38 18 40Z", 1.6)
        + ell(INK, 50, 60, 21, 23, 0, 0) + ell(("#fff1c8", "#d9a441"), 42, 58, 3.6, 2.6, 0, 0) + ell(("#fff1c8", "#d9a441"), 58, 58, 3.6, 2.6, 0, 0)
        + curve("#6b4426", 4, "M16 76 C36 92 64 92 84 74", ink=False)
        + path(("#f2e6c8", "#9a7a4a"), "M26 84 C40 84 54 78 62 66 L72 74 C62 88 44 92 26 88Z", 1.6)
        + ell(("#fff4d8", "#b08850"), 67, 70, 6.5, 4, -50, 1.6) + ell(INK, 67, 70, 3.2, 1.8, -50, 0)
        + line("#c9a24a", 2.6, (40, 82), (42, 89), ink=False) + line("#c9a24a", 2.6, (52, 77), (56, 84), ink=False))
PLAIN.append(lodge_hunter)

# --- The creatures of Fontanova ------------------------------------------------------------------
AMBER = ("#ffd65a", "#c97a12"); CHITIN = ("#3a3030", "#120c0c"); WINGS = "#e8f6ff"; WASP_RED = ("#ff6a48", "#9a1810")
GOD_GLOW = ("#fff2c0", "#ffae2e"); SHELL = ("#d8b48a", "#7a4e2a"); LIME = ("#efe4cc", "#9a8a6a")

def _wing(x, y, rx, ry, rot):
    return ell(WINGS, x, y, rx, ry, rot, 2).replace("/>", ' fill-opacity="0.7"/>')

def mutant_bee():
    # A great bee in a dive: amber and black bands, blurred wings, its stinger curled forward.
    return (_wing(36, 30, 20, 10, -30) + _wing(62, 28, 18, 9, 30)
        + path(AMBER, "M30 50 C30 36 46 32 58 38 C74 44 84 58 80 72 C76 84 60 84 48 76 C38 68 30 60 30 50Z")
        + "".join(curve(CHITIN[1], 6, d, ink=False) for d in ("M50 38 C44 50 46 66 54 76", "M64 44 C58 56 60 70 68 80"))
        + poly(CHITIN, (74, 78), (88, 94), (78, 80), w=2)
        + circ(CHITIN, 26, 46, 12) + ell(("#ffb060", "#a03a10"), 21, 44, 4.6, 6, 20, 1.4)
        + line(CHITIN[1], 2.4, (22, 36), (14, 22), ink=False) + line(CHITIN[1], 2.4, (28, 35), (26, 18), ink=False))
PLAIN.append(mutant_bee)

def beehive():
    # A great comb over an olive stump: hexagon cells, a few aglow with the god's light, honey running.
    def hexa(x, y, r, c):
        return poly(c, *[(x + r * math.cos(math.radians(60 * k + 30)), y + r * math.sin(math.radians(60 * k + 30))) for k in range(6)], w=1.6)
    cells = ""
    for row in range(5):
        for col in range(4 + (row % 2 == 0)):
            x = 22 + col * 13 + (0 if row % 2 == 0 else 6.5)
            y = 22 + row * 11
            lit = (row, col) in ((1, 1), (2, 3), (3, 0), (0, 2))
            cells += hexa(x, y, 6.6, GOD_GLOW if lit else AMBER)
    return (path(WOOD, "M30 90 C34 80 36 74 34 66 L66 66 C64 74 66 80 72 90Z")
        + path(("#e0a43a", "#7a4a12"), "M14 46 C10 20 30 8 50 8 C70 8 90 20 86 46 C84 64 70 74 50 74 C30 74 16 64 14 46Z")
        + f'<clipPath id="comb"><path d="M14 46 C10 20 30 8 50 8 C70 8 90 20 86 46 C84 64 70 74 50 74 C30 74 16 64 14 46Z"/></clipPath>'
        + f'<g clip-path="url(#comb)">{cells}</g>'
        + path(("#ffd040", "#d08010"), "M60 70 C62 78 58 84 62 92 C64 96 68 94 66 88 C64 82 66 76 64 70Z", 1.4)
        + at(84, 82, 0.2, mutant_bee()) + at(16, 84, 0.16, mutant_bee()))
PLAIN.append(beehive)

def mutant_wasp():
    # A red-and-black wasp side on, its abdomen arched under to shoot, the stinger flying ahead.
    return (_wing(48, 26, 20, 8, -15) + _wing(60, 30, 16, 7, 10)
        + path(WASP_RED, "M52 44 C64 44 74 52 76 62 C78 74 70 84 60 86 C54 80 54 70 58 62 C56 54 52 50 52 44Z")
        + "".join(curve(CHITIN[1], 4.4, d, ink=False) for d in ("M70 52 C64 58 62 66 64 74", "M76 64 C70 70 66 76 66 84"))
        + ell(CHITIN, 42, 46, 12, 8, 0) + circ(WASP_RED, 22, 44, 10)
        + ell("#1a0a0a", 18, 41, 3.8, 5, 20, 0) + path(CHITIN, "M12 50 L4 56 L14 54Z", 1.4)
        + line(CHITIN[1], 2.4, (36, 52), (30, 66), ink=False) + line(CHITIN[1], 2.4, (44, 54), (42, 70), ink=False)
        + poly(BONE, (60, 88), (30, 94), (56, 82), w=1.6) + line("#ffffff", 1.4, (28, 94), (16, 96), ink=False))
PLAIN.append(mutant_wasp)

def _snail_body(x0=8, x1=92):
    return path(("#a09078", "#4a3e30"), f"M{x0} 84 C{x0} 72 20 66 34 68 L80 70 C88 72 {x1} 78 {x1} 86 L{x0} 88Z")

def mutant_snail():
    # A boar-sized snail: its spiral shell split by seams that glow green on one side and ember on the other.
    return (_snail_body()
        + path(SHELL, "M28 72 C18 50 30 20 56 18 C80 18 90 40 84 58 C78 74 58 80 44 74 C36 72 30 74 28 72Z")
        + curve("#7a4e2a", 2.4, "M44 74 C32 68 32 52 42 46 C52 40 62 48 58 56", ink=False)
        + curve("#9cf06a", 3.2, "M40 70 C30 56 36 34 56 30 C74 28 82 46 76 58", ink=False)
        + curve("#ff9a3a", 3.2, "M48 62 C42 54 46 42 56 42 C64 42 68 50 64 56", ink=False)
        + line("#a09078", 5, (16, 72), (8, 54)) + line("#a09078", 5, (20, 72), (18, 52))
        + circ("#1a1410", 8, 52, 3, 0) + circ("#1a1410", 18, 50, 3, 0)
        + path(("#b8f07a", "#3a8a20"), "M60 94 C70 90 84 92 96 90 L96 98 L58 98Z", 1.2).replace("/>", ' opacity="0.8"/>'))
PLAIN.append(mutant_snail)

def wasp_hive_snail():
    # A snail carrying a paper wasps' nest for its shell, a wasp crawling out of the hole.
    layers = "".join(curve("#8a7a64", 2, f"M{30 + k} {34 + k * 9} C46 {28 + k * 9} 66 {28 + k * 9} {80 - k} {36 + k * 9}", ink=False) for k in range(4))
    return (_snail_body()
        + path(("#e6dcc8", "#8a7a5e"), "M26 72 C20 48 34 14 56 14 C78 14 88 42 82 64 C78 74 64 78 50 76 C38 76 30 76 26 72Z")
        + layers + ell("#1a1208", 58, 56, 8, 6, 0, 2)
        + at(66, 46, 0.3, mutant_wasp())
        + line("#a09078", 5, (16, 72), (8, 54)) + line("#a09078", 5, (20, 72), (18, 52))
        + circ("#1a1410", 8, 52, 3, 0) + circ("#1a1410", 18, 50, 3, 0))
PLAIN.append(wasp_hive_snail)

def mutant_spider():
    # A long-legged spider head down on a trunk, legs splayed round it, eyes aglow, a thread above.
    legs = ""
    for k, (dx, dy, ex, ey) in enumerate(((-14, -6, -42, -30), (-16, 0, -44, -4), (-15, 6, -42, 22), (-12, 10, -34, 42))):
        for sgn in (-1, 1):
            kx, ky = 50 + sgn * (-dx + 10), 50 + dy - 14
            legs += line(CHITIN[1], 3.6, (50 + sgn * -dx * 0.4, 50 + dy * 0.6), (kx, ky), (50 + sgn * -ex, 50 + ey))
    return (rect(WOOD, 40, -2, 20, 104, 4, 2.4).replace("/>", ' opacity="0.9"/>')
        + line("#e9eef5", 1.4, (50, 0), (50, 26), ink=False)
        + legs
        + ell(("#5a4a3a", "#1a1410"), 50, 40, 12, 15, 0) + "".join(curve("#c9a040", 2, f"M{44 + k * 4} 30 L{44 + k * 4} 50", ink=False) for k in range(4))
        + circ(("#5a4a3a", "#1a1410"), 50, 62, 9)
        + "".join(circ("#ffcf4a", x, y, 1.8, 0) for x, y in ((46, 64), (54, 64), (48, 68), (52, 68)))
        + poly(BONE, (45, 70), (47, 76), (49, 70), w=1) + poly(BONE, (51, 70), (53, 76), (55, 70), w=1))
PLAIN.append(mutant_spider)

def battle_ostrich():
    # An ostrich's head and long neck in a bronze war-harness: a crested headpiece, beak open, eye wild.
    return (path(("#4a3a30", "#1a120c"), "M18 98 C20 80 30 70 40 62 C48 56 50 44 46 32 L56 30 C62 46 58 62 48 74 C40 84 36 92 36 98Z")
        + path(("#e6d0b0", "#8a6a4a"), "M46 34 C42 20 52 10 64 12 C74 14 78 24 74 32 C68 36 56 38 46 34Z")
        + path(BRASS, "M44 30 C46 20 54 14 64 14 L70 24 C62 22 52 26 48 34Z", 2)
        + path(("#ff6a48", "#9a1810"), "M56 14 C54 4 62 0 70 6 C64 6 62 10 62 14Z", 1.6)
        + path(("#e8c070", "#8a5a20"), "M72 22 L96 28 L74 32Z", 2) + line(INK, 1.4, (74, 27), (92, 28), ink=False)
        + circ("#fff4d0", 64, 22, 4, 1.4) + circ("#a01010", 65, 22, 1.8, 0)
        + path(BRASS, "M36 66 C44 60 52 60 58 66 L54 74 C48 70 42 70 38 74Z", 2)
        + "".join(circ(BRASS, x, y, 2.2, 1.2) for x, y in ((40, 70), (48, 67), (55, 70))))
PLAIN.append(battle_ostrich)

def ember_moth():
    # A great moth with its wings spread, eye-spots blazing, dust burning off its wingtips.
    spot = lambda x, y: circ(("#ffe08a", "#e2301a"), x, y, 7, 1.6) + circ("#1a0a08", x, y, 3, 0)
    return (path(("#a0784a", "#4a2e1a"), "M50 46 C36 20 14 12 6 22 C2 40 18 54 46 54Z")
        + path(("#a0784a", "#4a2e1a"), "M50 46 C64 20 86 12 94 22 C98 40 82 54 54 54Z")
        + path(("#8a5a3a", "#3a2010"), "M48 54 C30 56 16 70 22 84 C32 86 44 74 50 60Z")
        + path(("#8a5a3a", "#3a2010"), "M52 54 C70 56 84 70 78 84 C68 86 56 74 50 60Z")
        + spot(26, 34) + spot(74, 34)
        + ell(("#d8b48a", "#6a4a2a"), 50, 52, 5, 18, 0)
        + curve("#d8b48a", 2, "M48 36 C44 26 38 22 34 22", ink=False) + curve("#d8b48a", 2, "M52 36 C56 26 62 22 66 22", ink=False)
        + "".join(circ("#ffb52e", x, y, r, 0).replace("/>", ' opacity="0.8"/>') for x, y, r in ((8, 12, 2.4), (14, 6, 1.6), (92, 12, 2.4), (86, 6, 1.6), (4, 30, 1.6), (96, 30, 1.6))))
PLAIN.append(ember_moth)

def thornback():
    # A cart-sized tortoise, its shell grown into limestone thorns, its old head low and forward.
    thorns = "".join(poly(LIME, (x - 6, y + 4), (x + tx, y - 18), (x + 6, y + 4), w=2) for x, y, tx in ((24, 54, -6), (36, 42, -3), (50, 38, 0), (64, 42, 3), (76, 54, 6)))
    return (path(("#8a7a60", "#3a3020"), "M16 74 L12 90 L26 90 L28 76Z") + path(("#8a7a60", "#3a3020"), "M62 76 L64 90 L78 90 L74 74Z")
        + path(("#8a7a60", "#3a3020"), "M74 68 C80 56 94 54 98 64 C100 74 92 80 82 78Z")
        + circ("#fff1c8", 90, 64, 2.6, 1.2) + circ(INK, 90.6, 64, 1.2, 0)
        + path(("#c8b898", "#6a5a40"), "M8 76 C8 52 28 40 50 40 C72 40 88 54 86 76Z")
        + "".join(curve("#6a5a40", 2.2, d, ink=False) for d in ("M24 76 L32 56 L50 50 L68 56 L74 76", "M32 56 L16 64", "M68 56 L82 64", "M50 50 L50 76"))
        + thorns
        + line("#5a4a30", 4, (8, 77), (86, 77)))
PLAIN.append(thornback)

# The cult of Al'quimelea: heads, each told by what it wears.
LINEN_C = ("#efe6d2", "#9c8f74"); WAX_C = ("#f6d77a", "#b9862a"); VIOLET_C = ("#a26bd8", "#3e1a6a"); BRONZE_C = ("#f0b45a", "#7a4818")

def _violet_eyes(y, xs=(38, 62), w_=12):
    return "".join(rect("#e8c8ff", x - w_ / 2, y - 1.6, w_, 3.2, 1.2, 0) for x in xs)

def cult_worshipper():
    # A linen hood over a wax mask pressed with honeycomb, its slit eyes lit violet, a violet stole.
    cells = "".join(poly(("#e8c060", "#a87a20"), *[(x + 4.2 * math.cos(a * math.pi / 3), y + 4.2 * math.sin(a * math.pi / 3)) for a in range(6)], w=1)
        for x, y in ((40, 40), (50, 36), (60, 40), (45, 62), (55, 62)))
    return (path(LINEN_C, "M14 96 C14 70 22 58 30 54 L70 54 C78 58 86 70 86 96Z")
        + rect(VIOLET_C, 34, 60, 9, 38, 2, 2) + rect(VIOLET_C, 57, 60, 9, 38, 2, 2)
        + path(LINEN_C, "M18 62 C10 30 30 4 54 6 C70 8 76 2 84 0 C80 12 86 22 84 40 C82 54 78 62 72 66 L28 66Z")
        + ell(WAX_C, 50, 46, 20, 22, 0, 2.4) + cells
        + rect(BRONZE_C, 30, 30, 40, 4, 1.5, 1.6)
        + _violet_eyes(48) + poly(WAX_C, (44, 66), (50, 76), (56, 66), w=1.6))
PLAIN.append(cult_worshipper)

def cult_priest():
    # A hood woven like a bee-skep, a violet veil in strips, one violet eye at the brow; a green vial.
    rings = "".join(path(("#e8c068", "#8a6020"), f"M{50 - r} {y} C{50 - r} {y - 8} {50 + r} {y - 8} {50 + r} {y} L{50 + r - 2} {y + 9} C{50 + r - 2} {y + 2} {50 - r + 2} {y + 2} {50 - r + 2} {y + 9}Z", 1.6)
        for r, y in ((34, 64), (32, 54), (29, 44), (25, 34), (19, 24), (12, 15)))
    veil = "".join(rect(VIOLET_C, 30 + k * 7, 50, 6, 22 + (k % 2) * 5, 1, 1.2) for k in range(6))
    return (path(VIOLET_C, "M12 98 C14 80 24 72 36 70 L64 70 C76 72 86 80 88 98Z")
        + rings + veil + rect(BRONZE_C, 28, 48, 44, 4, 1, 1.4)
        + circ(BRONZE_C, 50, 38, 7, 1.6) + circ(("#f0d8ff", "#9a4af0"), 50, 38, 4.4, 0)
        + rect(("#d8ffb0", "#3c9a2a"), 74, 74, 9, 16, 3, 1.8) + rect(LEATHER, 75, 70, 7, 5, 1, 1.2))
PLAIN.append(cult_priest)

def cult_guardian():
    # A closed bronze helmet, a ridge of black plumes, violet eyes in the T of its face.
    plumes = "".join(poly(("#3a3440", "#0e0c12"), (x - 4, 26), (x + 2, 2 + abs(x - 50) * 0.15), (x + 4, 26), w=1.4) for x in range(28, 76, 6))
    return (plumes + rect(BRONZE_C, 26, 24, 48, 6, 2, 1.6)
        + path(BRONZE_C, "M20 58 C18 30 32 24 50 24 C68 24 82 30 80 58 L78 90 L60 92 L56 66 L44 66 L40 92 L22 90Z")
        + path(("#1a1418", "#000000"), "M30 46 L70 46 L70 52 L54 52 L54 72 L46 72 L46 52 L30 52Z", 1)
        + _violet_eyes(49, (38, 62), 11)
        + curve("#7a4818", 2.2, "M24 40 C40 34 60 34 76 40", ink=False)
        + poly(VIOLET_C, (50, 30), (55, 33), (55, 38), (50, 41), (45, 38), (45, 33), w=1.4))
PLAIN.append(cult_guardian)

def ostrich_rider():
    # The Guardian's helmet behind the war-bird's head, the bird's neck reaching forward.
    return (at(36, 50, 0.72, cult_guardian()) + at(66, 54, 0.7, battle_ostrich()))
PLAIN.append(ostrich_rider)

GOLD_C = ("#ffe08a", "#a8721c"); CRIMSON_C = ("#e0503c", "#6a1010")

def hierophant():
    # The Hierophant: a tall crowned skep-mitre, a golden mask with a third eye lit at its brow.
    rings = "".join(path(("#e8c068", "#8a6020"), f"M{50 - r} {y} C{50 - r} {y - 7} {50 + r} {y - 7} {50 + r} {y} L{50 + r - 2} {y + 8} C{50 + r - 2} {y + 2} {50 - r + 2} {y + 2} {50 - r + 2} {y + 8}Z", 1.4)
        for r, y in ((30, 56), (28, 47), (25, 38), (22, 29), (18, 21), (13, 13)))
    crown = "".join(poly(GOLD_C, (50 + dx - 4, 60), (50 + dx, 50 - (6 if dx == 0 else 0)), (50 + dx + 4, 60), w=1.2) for dx in (-24, -16, -8, 0, 8, 16, 24))
    return (path(VIOLET_C, "M10 98 C12 80 22 72 34 70 L66 70 C78 72 88 80 90 98Z") + path(GOLD_C, "M24 98 L30 76 L70 76 L76 98Z", 1.4)
        + rings + poly(GOLD_C, (46, 8), (50, 0), (54, 8), w=1.2) + crown
        + ell(GOLD_C, 50, 72, 19, 20, 0, 2.4)
        + _violet_eyes(72, (42, 58), 9) + circ(("#f0d8ff", "#9a4af0"), 50, 63, 3.6, 1.2)
        + rect(GOLD_C, 46, 74, 8, 10, 2, 1.2))
PLAIN.append(hierophant)

def polemarch():
    # The Polemarch: a closed gilded helmet, its crimson crest set crosswise, over the top of a tower shield.
    crest = "".join(poly(CRIMSON_C, (x - 4, 28), (x + (x - 50) * 0.18, 4 + abs(x - 50) * 0.3), (x + 4, 28), w=1.3) for x in range(14, 90, 6))
    return (rect(CRIMSON_C, 8, 66, 84, 34, 6, 2.4) + rect(GOLD_C, 8, 66, 84, 6, 2, 1.6)
        + crest + rect(GOLD_C, 12, 24, 76, 7, 2, 1.6)
        + path(BRONZE_C, "M20 60 C18 32 32 26 50 26 C68 26 82 32 80 60 L78 84 L60 86 L56 64 L44 64 L40 86 L22 84Z")
        + path(("#1a1418", "#000000"), "M30 44 L70 44 L70 50 L54 50 L54 68 L46 68 L46 50 L30 50Z", 1)
        + _violet_eyes(47, (38, 62), 11) + rect(GOLD_C, 47, 28, 6, 18, 1.5, 1.2)
        + poly(GOLD_C, (50, 82), (58, 87), (58, 95), (50, 100), (42, 95), (42, 87), w=1.4))
PLAIN.append(polemarch)

def alquimelea():
    # Al'quimelea: its long golden mask, cracked, three eyes lit violet, a crown of rays behind it, and
    # the crucible glowing green under its chin.
    rays = "".join(poly(GOLD_C if k % 2 == 0 else ("#c08030", "#5a3a10"), (50 + 30 * math.sin(a - 0.08), 52 - 30 * math.cos(a - 0.08)), (50 + 48 * math.sin(a), 52 - 48 * math.cos(a)), (50 + 30 * math.sin(a + 0.08), 52 - 30 * math.cos(a + 0.08)), w=1.2)
        for k, a in enumerate([-1.4 + i * (2.8 / 10) for i in range(11)]))
    return (rays + ell(("#3a1e48", "#120818"), 50, 52, 28, 34, 0, 2)
        + ell(GOLD_C, 50, 50, 21, 30, 0, 2.4)
        + curve("#1a0a1a", 1.6, "M52 22 L49 32 L53 40 L48 52 L51 60", ink=False)
        + _violet_eyes(48, (41, 59), 9) + circ(("#f0d8ff", "#9a4af0"), 50, 36, 3.6, 1.2)
        + rect(GOLD_C, 46, 52, 8, 12, 2, 1.2)
        + circ(("#d8ffb0", "#2c9a2a"), 50, 88, 9, 2) + curve("#a8721c", 2.4, "M39 88 A11 11 0 1 0 61 88 A11 11 0 1 0 39 88", ink=False))
PLAIN.append(alquimelea)

# Fontanova's weapons
BRONZE_W = ("#f0b870", "#7a4a1c"); RESIN_W = ("#ffe08a", "#e07a10"); OLIVE_W = ("#d0a46a", "#6a4422"); MARBLE_W = ("#ffffff", "#c8c2b4")

def censer_flail():
    # A turned haft, its chain, and the pierced bronze censer swinging out, embers glowing through it.
    links = "".join(ell("none", 46 + i * 5, 34 + i * 6, 3.2, 2.2, 40, 2.6) for i in range(4))
    holes = "".join(circ(RESIN_W, x, y, 3.2, 1) for x, y in ((60, 72), (70, 70), (80, 72), (66, 62), (76, 62)))
    return (line("#a87a48", 7, (12, 94), (40, 30)) + "".join(line("#5a2c6a", 7, a, b, ink=False) for a, b in (((18, 80), (20, 76)), ((24, 66), (26, 62))))
        + circ(BRONZE_W, 42, 26, 6, 2.4) + links
        + path(BRONZE_W, "M52 60 C52 52 88 52 88 60 C90 76 82 88 70 88 C58 88 50 76 52 60Z") + holes
        + path(BRONZE_W, "M54 58 C56 44 84 44 86 58Z", 2.4) + poly(GOLD, (66, 44), (70, 34), (74, 44), w=2)
        + curve("#e0d8c8", 3, "M72 32 C66 24 76 18 70 10", ink=False) + curve("#e0d8c8", 2.4, "M60 46 C56 38 64 34 60 26", ink=False))
def resin_repeater():
    # A crossbow seen from above at a slant: its olive stock, the tall box of bolts on it, a horn prod.
    return (path(("#f0e4c8", "#9c8a62"), "M10 40 C26 30 40 28 50 32 C60 28 74 30 90 40 L86 46 C74 38 62 38 50 40 C38 38 26 38 14 46Z")
        + line("#fff4d8", 1.6, (12, 44), (50, 72), (88, 44), ink=False)
        + path(OLIVE_W, "M44 34 L56 34 L60 96 L40 96Z") + rect(BRONZE_W, 38, 46, 24, 28, 3) + "".join(line("#7a4a1c", 2, (38, y), (62, y), ink=False) for y in (54, 62))
        + "".join(poly(RESIN_W, (x - 3, 46), (x, 38), (x + 3, 46), w=1.4) for x in (44, 50, 56))
        + rect(RESIN_W, 46, 26, 8, 8, 2, 2))
def ruin_greataxe():
    # A long dark haft, a double crescent head with white edges, and a spike on top.
    return (line("#6a4226", 7, (50, 98), (50, 22)) + "".join(line("#f0b870", 8, a, b, ink=False) for a, b in (((50, 86), (50, 82)), ((50, 50), (50, 46))))
        + path(DSTEEL, "M46 22 C30 18 16 12 8 4 C2 20 2 42 8 56 C18 46 32 42 46 40Z") + path(DSTEEL, "M54 22 C70 18 84 12 92 4 C98 20 98 42 92 56 C82 46 68 42 54 40Z")
        + curve("#ffffff", 3.4, "M8 6 C3 20 3 42 8 54", ink=False) + curve("#ffffff", 3.4, "M92 6 C97 20 97 42 92 54", ink=False)
        + rect(DARK, 44, 18, 12, 26, 2) + poly(STEEL, (46, 18), (50, 2), (54, 18)) + rect(GOLD, 47, 26, 6, 8, 1, 1.4))
for g in (censer_flail, resin_repeater, ruin_greataxe):
    PLAIN.append(g)

# The Ascendant
ICHOR_C = ("#e4e88a", "#5a6012"); CHANGE_C = ("#d8ffb0", "#2c9a2a"); HALO_C = ("#fff6c8", "#d8a83a")

def ascend():
    # Ascend: a figure's rise drawn as a golden chevron climbing out of cracked ground, with light above.
    return (path(ROCK, "M4 92 L34 80 L42 88 L58 78 L66 86 L96 92 L96 98 L4 98Z", 2.4)
        + curve("#2a2418", 2, "M42 88 L46 94 M58 78 L56 70", ink=False)
        + poly(HALO_C, (50, 8), (82, 44), (64, 44), (64, 72), (36, 72), (36, 44), (18, 44))
        + line("#ffffff", 2.4, (50, 16), (70, 38), ink=False)
        + "".join(line("#fff6c8", 3, (x, 74), (x, 82), ink=False) for x in (40, 50, 60)))
def deicide():
    # Deicide: an axe coming down on a cracked halo.
    return (circ("none", 50, 66, 26, 7) + circ("none", 50, 66, 26, 4).replace('stroke="#12141c"', 'stroke="#ffe08a"')
        + curve("#12141c", 4, "M44 38 L52 52 L46 62 L56 74 L50 92", ink=False)
        + at(56, 40, 0.74, turn(-30, ruin_greataxe())))
def elixir():
    # The Elixir of Change: a round flask of green elixir with a gold stopper, violet light swirling in it.
    return (path(CHANGE_C, "M38 30 L62 30 L62 42 C80 48 88 62 86 74 C84 90 70 96 50 96 C30 96 16 90 14 74 C12 62 20 48 38 42Z")
        + curve("#c07af0", 3.4, "M26 74 C34 62 48 66 52 74 C56 82 68 82 74 70", ink=False)
        + circ("#ffffff", 34, 60, 4, 0) + rect(GOLD, 34, 18, 32, 14, 3) + poly(GOLD, (42, 18), (50, 6), (58, 18), w=2.4)
        + "".join(circ(("#f0ffe0", "#7ad060"), x, y, r, 1.4) for x, y, r in ((70, 22, 4), (78, 10, 3), (24, 16, 3))))
def rite_break():
    # A broken attack: a ring of holy light split by a crack, its pieces falling away.
    return (path(HALO_C, "M50 10 A40 40 0 0 1 88 40 L76 44 A28 28 0 0 0 50 22Z") + path(HALO_C, "M90 52 A40 40 0 0 1 50 90 L50 78 A28 28 0 0 0 78 56Z")
        + path(HALO_C, "M44 90 A40 40 0 0 1 10 50 L22 50 A28 28 0 0 0 44 78Z") + path(HALO_C, "M10 42 A40 40 0 0 1 40 11 L42 23 A28 28 0 0 0 22 42Z")
        + curve("#12141c", 4, "M50 30 L44 44 L56 54 L48 70", ink=False) + poly(VIO, (60, 30), (66, 22), (70, 32), w=1.6) + poly(VIO, (30, 66), (24, 76), (36, 74), w=1.6))
def honeycomb():
    # A piece of wild comb: golden hexagons, some capped, honey dripping, and two bees about it.
    cells = "".join(poly(("#ffd870", "#c07a10") if (i % 3) else ("#ffeaa0", "#d08a20"), *[(x + 13 * math.cos(math.pi / 6 + k * math.pi / 3), y + 13 * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)], w=2.4)
        for i, (x, y) in enumerate(((50, 48), (28, 36), (72, 36), (28, 60), (72, 60), (50, 24), (50, 72))))
    def bee(x, y, r):
        return at(x, y, 0.3, turn(r, ell(("#ffe070", "#c08010"), 50, 50, 24, 16) + line("#12141c", 6, (44, 36), (44, 64), ink=False) + line("#12141c", 6, (58, 38), (58, 62), ink=False)
            + ell(("#ffffff", "#bcd8f0"), 46, 26, 12, 8, -20, 2) + ell(("#ffffff", "#bcd8f0"), 60, 26, 12, 8, 20, 2)))
    return (cells + path(("#ffd040", "#e08a10"), "M44 82 C44 90 48 96 50 96 C52 96 56 90 56 82Z", 2.4) + bee(82, 16, 20) + bee(16, 84, -30))
def mystery_flask():
    # A pear-shaped flask, violet below and green above, a gold-wired cork and a red wax seal on a cord.
    return (path(("#a070ff", "#4a1ca0"), "M40 30 L60 30 L60 40 C80 48 86 64 82 78 C78 92 66 96 50 96 C34 96 22 92 18 78 C14 64 20 48 40 40Z")
        + path(("#a8f0a0", "#2c9a2a"), "M40 40 C28 46 20 56 20 64 L80 64 C80 56 72 46 60 40Z", 2)
        + circ("#ffffff", 32, 74, 4, 0) + rect(("#c08a52", "#6f4522"), 40, 18, 20, 14, 3) + line("#ffe08a", 2.4, (38, 22), (62, 22), ink=False)
        + curve("#5a3a20", 2.4, "M60 34 C72 40 78 50 78 56", ink=False) + circ(("#ff8080", "#a01020"), 80, 60, 7, 2) + curve("#ffffff", 3, "M46 6 C42 12 54 12 50 16", ink=False))
for g in (honeycomb, mystery_flask):
    PLAIN.append(g)

def crest_ascendant():
    # An olive-gold shield cut like a temple's pediment, a broken halo over it and the greataxe upright.
    return (path(ICHOR_C, "M50 4 L96 30 L90 78 L50 98 L10 78 L4 30Z", 4)
        + curve("#fff0b0", 6, "M26 50 A25 25 0 0 1 56 20") + curve("#fff0b0", 6, "M66 24 A25 25 0 0 1 72 60")
        + at(50, 58, 0.72, ruin_greataxe()))
for g in (ascend, deicide, elixir, rite_break):
    PLAIN.append(g)
CRESTS.append(crest_ascendant)

# Specializations: a lozenge in the class's colour, and what makes that path itself.
COL = {"commander": ("#e4bf61", "#69441d"), "infantry": ("#d9483a", "#7c1414"), "ranger": ("#5fb24d", "#1c5a2c"), "heavy": ("#9aa5ba", "#3f485c"), "chivalry": ("#f4c94e", "#a86a10"),
    "magician": ("#a86bff", "#3a1786"), "revenant": ("#3ec7c0", "#0e4d57"), "artificer": ("#d99a45", "#6d4315"), "monk": ("#ffb040", "#b25a10"),
    "plague_doctor": ("#6c7e54", "#1f2a1a"), "adept": ("#5f73d8", "#1b2368"), "bandit": ("#a8577f", "#3d1430"), "cartographer": ("#5aa6e8", "#163f78"),
    "harpooner": ("#3f74a8", "#102640"), "tidecaller": ("#36c6b8", "#0d4a46"), "ferryman": ("#c8bf9e", "#3a3428"),
    "ascendant": ("#c8cc5a", "#3e4410")}

def lozenge(cls, inner):
    return rect(COL[cls], 7, 7, 86, 86, 18, 4) + rect("none", 13, 13, 74, 74, 13, 1.6) + inner

def x2(g, s=0.72):
    return at(50, 50, s, turn(45, g()) + turn(-45, g()))

SPECS = {
    "warlock": ("commander", lambda: at(50, 50, 0.7, staff()) + at(72, 24, 0.28, bolt())),
    "gunner": ("commander", lambda: at(50, 50, 0.72, crossbow())),
    "vanguard": ("commander", lambda: at(50, 50, 0.76, banner())),
    "duelist": ("infantry", lambda: x2(sword)),
    "berserker": ("infantry", lambda: at(42, 50, 0.72, axe()) + at(76, 28, 0.3, drop()) + at(78, 64, 0.22, drop())),
    "shadow": ("infantry", lambda: at(50, 44, 0.62, moon()) + at(56, 58, 0.62, turn(25, dagger()))),
    "sharpshooter": ("ranger", lambda: at(50, 50, 0.72, target()) + at(62, 38, 0.56, arrow())),
    "trapper": ("ranger", lambda: at(50, 50, 0.82, trap())),
    "beastmaster": ("ranger", lambda: at(50, 50, 0.76, wolf())),
    "guardian": ("heavy", lambda: path(ICE, "M10 72 C14 28 86 28 90 72Z") + at(50, 58, 0.5, shield())),
    "warpriest": ("heavy", lambda: at(50, 50, 0.66, sun()) + at(50, 50, 0.6, cross())),
    "warlord": ("heavy", lambda: at(50, 50, 0.78, banner())),
    "lancer": ("chivalry", lambda: at(50, 50, 0.82, lance())),
    "paladin": ("chivalry", lambda: at(50, 50, 0.72, shield_round()) + at(50, 50, 0.5, cross())),
    "horse_archer": ("chivalry", lambda: at(50, 56, 0.62, horseshoe()) + at(50, 40, 0.56, bow())),
    "necromancer": ("magician", lambda: at(50, 36, 0.48, skull()) + at(50, 70, 0.52, hand())),
    "elementalist": ("magician", lambda: at(50, 30, 0.38, flame()) + at(30, 66, 0.38, snow()) + at(70, 66, 0.38, bolt())),
    "illusionist": ("magician", lambda: at(36, 50, 0.6, mask()) + at(66, 50, 0.6, mask().replace(BONE[0], "#d4c8ff"))),
    "leaper": ("revenant", lambda: at(50, 50, 0.78, leap())),
    "rift": ("revenant", lambda: at(50, 50, 0.8, rift())),
    "summoner": ("revenant", lambda: at(30, 40, 0.42, ghost()) + at(70, 40, 0.42, ghost()) + at(50, 62, 0.5, ghost())),
    "pyromaniac": ("artificer", lambda: at(46, 56, 0.66, bomb()) + at(66, 34, 0.38, flame())),
    "mechanic": ("artificer", lambda: at(50, 52, 0.86, war_chariot())),
    "inventor": ("artificer", lambda: at(42, 54, 0.66, flask()) + at(70, 32, 0.42, gear())),
    "apothecary": ("plague_doctor", lambda: at(50, 50, 0.72, potion()) + at(68, 66, 0.3, cross())),
    "pestilence": ("plague_doctor", lambda: at(50, 44, 0.62, skull()) + at(26, 76, 0.2, circ(TOX, 50, 50, 40)) + at(50, 82, 0.26, circ(TOX, 50, 50, 40)) + at(74, 74, 0.2, circ(TOX, 50, 50, 40))),
    "rat_king": ("plague_doctor", lambda: at(50, 60, 0.74, rat()) + at(58, 22, 0.34, crown())),
    "bo_master": ("monk", lambda: x2(bo, 0.56)),
    "spirit_walker": ("monk", lambda: at(50, 50, 0.84, body_out())),
    "iron_mountain": ("monk", lambda: at(50, 50, 0.84, mountain())),
    "blade_dancer": ("adept", lambda: at(50, 50, 0.72, spiral()) + at(50, 50, 0.6, turn(35, sword()))),
    "mirror_step": ("adept", lambda: at(32, 50, 0.46, boot()) + at(68, 50, 0.46, f'<g transform="translate(100 0) scale(-1 1)">{boot()}</g>') + at(50, 22, 0.28, swap())),
    "thief": ("bandit", lambda: at(44, 58, 0.66, hand()) + at(68, 30, 0.42, circ(GOLD, 50, 50, 34) + circ("none", 50, 50, 22, 2)) + at(30, 26, 0.3, dagger())),
    "mercenary": ("bandit", lambda: path(NIGHT, "M10 76 C14 30 86 30 90 76Z") + at(50, 50, 0.38, moon()) + at(30, 40, 0.14, star()) + at(70, 36, 0.12, star())),
    "highwayman": ("bandit", lambda: "".join(at(50 + dx, 56, 0.5, turn(a, dagger())) for dx, a in ((-20, -36), (-10, -18), (0, 0), (10, 18), (20, 36)))),
    "star_reader": ("cartographer", lambda: line("#cfe8ff", 4, (24, 68), (50, 28), (78, 60), (24, 68))
        + at(24, 68, 0.26, star()) + at(50, 28, 0.3, star()) + at(78, 60, 0.26, star())),
    "worlds_traveler": ("cartographer", lambda: at(50, 52, 0.78, waygate()) + at(76, 24, 0.24, star())),
    "pathfinder": ("cartographer", lambda: at(36, 58, 0.62, turn(-20, machete())) + at(68, 40, 0.5, compass())),
    "tollkeeper": ("ferryman", lambda: at(40, 56, 0.6, coin()) + at(64, 40, 0.5, coin()) + at(60, 70, 0.4, coin())),
    "boatman": ("ferryman", lambda: at(50, 54, 0.9, skiff())),
    "psychopomp": ("ferryman", lambda: at(50, 52, 0.66, soul()) + at(24, 30, 0.3, soul()) + at(78, 32, 0.3, soul())),
    "tidewarden": ("tidecaller", lambda: at(50, 54, 0.86, shell()) + at(50, 52, 0.5, trident_upright())),
    "stormcaller": ("tidecaller", lambda: at(46, 54, 0.8, trident()) + at(72, 30, 0.42, bolt()) + at(26, 30, 0.26, bolt())),
    "deepcaller": ("tidecaller", lambda: at(50, 52, 0.9, serpent())),
    "reaver": ("harpooner", lambda: at(46, 54, 0.66, turn(-20, cutlass())) + at(74, 30, 0.34, drop()) + at(26, 30, 0.22, drop())),
    "rigger": ("harpooner", lambda: line("#e8d6a8", 5, (14, 70), (86, 38)) + rect(WOOD, 10, 62, 8, 30, 2) + rect(WOOD, 82, 30, 8, 30, 2) + at(50, 70, 0.4, rope())),
    "leviathan_hunter": ("harpooner", lambda: at(42, 60, 0.7, leviathan_head()) + at(60, 42, 0.72, turn(-10, harpoon()))),
    "godslayer": ("ascendant", lambda: at(50, 54, 0.62, alquimelea()) + curve("#12141c", 5, "M40 20 L54 44 L44 60 L58 84", ink=False) + at(62, 46, 0.62, turn(-25, ruin_greataxe()))),
    "adorer": ("ascendant", lambda: at(50, 40, 0.56, alquimelea()) + at(50, 70, 0.5, elixir())),
    "void_walker": ("adept", lambda: circ(NIGHT, 50, 50, 28) + at(50, 50, 0.7, eye_closed()) + at(74, 26, 0.22, star())),
}

def render(name, body, out, px):
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2 104 104" width="%d" height="%d"><defs>%s</defs>%s</svg>' % (px, px, "".join(_defs.values()), body)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as t:
        t.write(svg)
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", os.path.join(out, name + ".png"), t.name], check=True)
    os.unlink(t.name)

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else OUT
    os.makedirs(out, exist_ok=True)
    made = []
    for g in PLAIN:
        _defs.clear(); render(g.__name__, g(), out, 160); made.append(g.__name__)
    for g in CRESTS:
        _defs.clear(); render(g.__name__, g(), out, 200); made.append(g.__name__)
    for name, (cls, g) in SPECS.items():
        _defs.clear(); render("spec_" + name, lozenge(cls, g()), out, 200); made.append("spec_" + name)
    print(len(made), "icons")

if __name__ == "__main__":
    main()
