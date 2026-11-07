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
def sling():
    return curve("#b98a58", 5, "M18 8 C22 40 40 60 50 72") + curve("#b98a58", 5, "M82 8 C78 40 60 60 50 72") + ell(LEATHER, 50, 76, 20, 13) + circ(ROCK, 50, 70, 10)
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
for g in (let_go, longbow, bell_hammer, javelins, sling, blowgun, rain, satchel, flurry, rage, shroud):
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
CRESTS = [crest_infantry, crest_ranger, crest_heavy, crest_chivalry, crest_magician, crest_revenant, crest_artificer, crest_monk, crest_plague_doctor, crest_adept]

# Specializations: a lozenge in the class's colour, and what makes that path itself.
COL = {"infantry": ("#d9483a", "#7c1414"), "ranger": ("#5fb24d", "#1c5a2c"), "heavy": ("#9aa5ba", "#3f485c"), "chivalry": ("#f4c94e", "#a86a10"),
    "magician": ("#a86bff", "#3a1786"), "revenant": ("#3ec7c0", "#0e4d57"), "artificer": ("#d99a45", "#6d4315"), "monk": ("#ffb040", "#b25a10"),
    "plague_doctor": ("#6c7e54", "#1f2a1a"), "adept": ("#5f73d8", "#1b2368")}

def lozenge(cls, inner):
    return rect(COL[cls], 7, 7, 86, 86, 18, 4) + rect("none", 13, 13, 74, 74, 13, 1.6) + inner

def x2(g, s=0.72):
    return at(50, 50, s, turn(45, g()) + turn(-45, g()))

SPECS = {
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

main()
