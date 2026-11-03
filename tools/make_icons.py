#!/usr/bin/env python3
"""Draws every icon shape used by the game: white shapes on transparency, tinted in game.
All original. Run from the project root."""
import math
from PIL import Image, ImageDraw

S = 8  # coordinates are 0-100, drawn at 800 px, saved at 128 px
G = {}

def glyph(f):
    G[f.__name__] = f
    return f

class P:
    def __init__(s, d, erase=False):
        s.d = d; s.c = 0 if erase else 255
    def poly(s, *pts):
        s.d.polygon([(x * S, y * S) for x, y in pts], fill=s.c)
    def circle(s, x, y, r):
        s.d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=s.c)
    def ell(s, x0, y0, x1, y1):
        s.d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=s.c)
    def line(s, w, *pts):
        p = [(x * S, y * S) for x, y in pts]
        s.d.line(p, fill=s.c, width=int(w * S), joint="curve")
        for x, y in pts:
            s.circle(x, y, w / 2)
    def rect(s, x0, y0, x1, y1):
        s.d.rectangle([x0 * S, y0 * S, x1 * S, y1 * S], fill=s.c)
    def arc(s, cx, cy, r, a0, a1, w):
        pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / 28)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / 28))) for i in range(29)]
        s.line(w, *pts)

def e(d):
    return P(d, True)

@glyph
def sword(p, x):
    p.poly((50, 6), (57, 18), (57, 66), (43, 66), (43, 18))
    x.rect(49, 18, 51, 62)
    p.rect(30, 66, 70, 73); p.rect(45, 73, 55, 88); p.circle(50, 91, 6)

@glyph
def dagger(p, x):
    p.poly((50, 12), (60, 40), (55, 62), (45, 62), (40, 40))
    p.rect(35, 62, 65, 68); p.rect(46, 68, 54, 84); p.circle(50, 87, 5)

@glyph
def axe(p, x):
    p.line(7, (58, 10), (40, 92))
    p.poly((54, 14), (84, 8), (92, 34), (76, 46), (49, 36))
    x.arc(100, 26, 16, 130, 230, 3)

@glyph
def mace(p, x):
    p.line(8, (32, 88), (58, 44))
    p.circle(66, 32, 19)
    for a in range(0, 360, 60):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.poly((66 + 30 * c, 32 + 30 * s_), (66 + 15 * c - 8 * s_, 32 + 15 * s_ + 8 * c), (66 + 15 * c + 8 * s_, 32 + 15 * s_ - 8 * c))

@glyph
def spear(p, x):
    p.line(6, (18, 88), (68, 32))
    p.poly((90, 8), (78, 42), (66, 34), (58, 22))

@glyph
def lance(p, x):
    p.poly((92, 8), (62, 44), (56, 38))
    p.poly((58, 36), (64, 42), (30, 68), (24, 62))
    p.poly((16, 56), (40, 80), (30, 90), (12, 84), (8, 66))

@glyph
def bow(p, x):
    p.arc(28, 50, 44, -62, 62, 7)
    p.line(2.5, (49, 11), (49, 89))
    p.line(4, (14, 50), (84, 50))
    p.poly((94, 50), (78, 42), (78, 58))

@glyph
def arrow(p, x):
    p.line(5, (18, 82), (76, 24))
    p.poly((90, 10), (66, 20), (80, 34))
    p.poly((24, 76), (8, 76), (14, 62), (26, 62))
    p.poly((24, 76), (24, 92), (38, 86), (38, 74))

@glyph
def arrows(p, x):
    for dx in (-22, 0, 22):
        p.line(4.5, (50 + dx, 86), (50 + dx, 24))
        p.poly((50 + dx, 8), (41 + dx, 28), (59 + dx, 28))
        p.poly((50 + dx, 72), (41 + dx, 92), (50 + dx, 84), (59 + dx, 92))

@glyph
def crossbow(p, x):
    p.arc(50, 58, 42, 200, 340, 7)
    p.line(2.5, (12, 44), (50, 66), (88, 44))
    p.rect(45, 20, 55, 92)
    p.poly((50, 6), (40, 24), (60, 24))

@glyph
def shield(p, x):
    p.poly((50, 8), (86, 18), (86, 50), (74, 74), (50, 94), (26, 74), (14, 50), (14, 18))
    x.rect(47, 16, 53, 84); x.rect(22, 42, 78, 48)

@glyph
def shield_rect(p, x):
    p.rect(20, 8, 80, 92)
    x.rect(47, 14, 53, 86); x.rect(26, 32, 74, 38)
    x.rect(26, 14, 40, 26); x.rect(60, 14, 74, 26)

@glyph
def shield_round(p, x):
    p.circle(50, 50, 42)
    x.circle(50, 50, 30); p.circle(50, 50, 26); x.circle(50, 50, 9)

@glyph
def helm(p, x):
    p.poly((50, 8), (74, 18), (80, 44), (80, 88), (58, 88), (54, 62), (46, 62), (42, 88), (20, 88), (20, 44), (26, 18))
    x.rect(22, 42, 44, 50); x.rect(56, 42, 78, 50)

@glyph
def skull(p, x):
    p.ell(16, 6, 84, 70); p.rect(32, 60, 68, 90)
    x.circle(35, 44, 11); x.circle(65, 44, 11)
    x.poly((50, 54), (43, 68), (57, 68))
    for dx in (41, 50, 59):
        x.rect(dx - 1.5, 76, dx + 1.5, 92)

@glyph
def bones(p, x):
    for a, b in (((16, 16), (84, 84)), ((84, 16), (16, 84))):
        p.line(10, a, b)
        for q in (a, b):
            p.circle(q[0] + 6, q[1] - 6 * (1 if q[0] < 50 else -1) * (1 if q[1] < 50 else 1), 8)
            p.circle(q[0] - 6, q[1] + 6, 8)

@glyph
def heart(p, x):
    p.circle(32, 34, 23); p.circle(68, 34, 23)
    p.poly((11, 44), (89, 44), (50, 92))

@glyph
def drop(p, x):
    p.circle(50, 62, 30)
    p.poly((50, 6), (22, 52), (78, 52))

@glyph
def flame(p, x):
    p.poly((52, 4), (70, 26), (84, 52), (82, 74), (66, 94), (34, 94), (18, 76), (18, 52), (30, 58), (34, 36), (46, 34))
    x.poly((50, 48), (64, 70), (58, 90), (40, 90), (34, 72))

@glyph
def snow(p, x):
    for a in (0, 60, 120):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.line(7, (50 - 42 * c, 50 - 42 * s_), (50 + 42 * c, 50 + 42 * s_))
        for sign in (-1, 1):
            q = (50 + sign * 28 * c, 50 + sign * 28 * s_)
            for t in (35, -35):
                b = math.radians(a + (0 if sign > 0 else 180) + t)
                p.line(5, q, (q[0] + 14 * math.cos(b), q[1] + 14 * math.sin(b)))

@glyph
def bolt(p, x):
    p.poly((60, 4), (22, 54), (46, 54), (34, 96), (80, 38), (54, 38), (72, 4))

@glyph
def wind(p, x):
    p.arc(62, 30, 13, -200, 90, 7); p.line(7, (62, 43), (10, 43))
    p.arc(74, 60, 11, 270, 560, 7); p.line(7, (74, 49), (22, 57))
    p.arc(46, 76, 10, 90, -200, 7); p.line(7, (46, 66), (8, 66))

@glyph
def boot(p, x):
    p.poly((34, 8), (64, 8), (64, 54), (90, 70), (90, 90), (28, 90))
    x.rect(32, 20, 66, 25)
    p.rect(26, 92, 92, 95)

@glyph
def eye(p, x):
    p.poly((6, 50), (28, 28), (50, 22), (72, 28), (94, 50), (72, 72), (50, 78), (28, 72))
    x.circle(50, 50, 20); p.circle(50, 50, 13); x.circle(55, 45, 4)

@glyph
def eye_closed(p, x):
    p.arc(50, 18, 46, 30, 150, 8)
    for a in (55, 75, 90, 105, 125):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.line(5, (50 + 46 * c, 18 + 46 * s_), (50 + 62 * c, 18 + 62 * s_))

@glyph
def moon(p, x):
    p.circle(48, 50, 40); x.circle(66, 40, 34)

@glyph
def star(p, x):
    pts = []
    for i in range(10):
        r = 46 if i % 2 == 0 else 19
        a = math.radians(-90 + i * 36)
        pts.append((50 + r * math.cos(a), 52 + r * math.sin(a)))
    p.poly(*pts)

@glyph
def crown(p, x):
    p.poly((8, 30), (30, 52), (50, 18), (70, 52), (92, 30), (82, 80), (18, 80))
    for q in ((8, 26), (50, 14), (92, 26)):
        p.circle(q[0], q[1], 7)
    x.rect(24, 66, 76, 70)

@glyph
def claw(p, x):
    for dx in (20, 44, 68):
        p.poly((dx, 8), (dx + 20, 40), (dx + 16, 92), (dx + 2, 94), (dx + 8, 44))

@glyph
def wolf(p, x):
    p.poly((16, 6), (36, 30), (64, 30), (84, 6), (88, 48), (68, 72), (58, 94), (42, 94), (32, 72), (12, 48))
    x.poly((30, 48), (44, 52), (32, 58)); x.poly((70, 48), (56, 52), (68, 58))
    x.poly((44, 78), (56, 78), (50, 86))

@glyph
def horse(p, x):
    p.poly((30, 92), (34, 64), (28, 52), (42, 22), (40, 6), (52, 16), (62, 16), (86, 44), (84, 56), (72, 58), (62, 48), (60, 60), (72, 92))
    x.circle(60, 30, 4)

@glyph
def horseshoe(p, x):
    p.arc(50, 44, 30, 140, 400, 15)
    p.rect(16, 62, 30, 88); p.rect(70, 62, 84, 88)
    for q in ((27, 26), (73, 26), (50, 14)):
        x.circle(q[0], q[1], 3)

@glyph
def trap(p, x):
    p.arc(50, 58, 34, 180, 360, 7)
    p.rect(8, 58, 92, 68)
    for dx in range(20, 90, 15):
        p.poly((dx - 7, 58), (dx + 7, 58), (dx, 36))
    p.circle(50, 80, 9); p.line(5, (50, 68), (50, 80))

@glyph
def net(p, x):
    for k in range(4):
        y = 14 + k * 24
        p.line(4, (10, y), (90, y)); p.line(4, (10 + k * 26.6, 14), (10 + k * 26.6, 86))
    p.line(4, (10, 86), (90, 86))

@glyph
def poison(p, x):
    p.poly((36, 6), (64, 6), (60, 18), (60, 34), (84, 78), (78, 94), (22, 94), (16, 78), (40, 34), (40, 18))
    x.rect(28, 60, 72, 64)
    x.circle(44, 78, 5); x.circle(60, 74, 4)

@glyph
def cross(p, x):
    p.rect(40, 6, 60, 94); p.rect(16, 28, 84, 48)

@glyph
def hand(p, x):
    for i, dx in enumerate((24, 40, 56, 72)):
        p.rect(dx - 6, 18 + abs(i - 1.5) * 5, dx + 6, 60)
        p.circle(dx, 18 + abs(i - 1.5) * 5, 6)
    p.poly((18, 54), (78, 54), (76, 80), (60, 94), (34, 94), (20, 78))
    p.poly((18, 66), (4, 44), (10, 40), (26, 56))

@glyph
def book(p, x):
    p.poly((8, 18), (46, 26), (46, 90), (8, 80))
    p.poly((92, 18), (54, 26), (54, 90), (92, 80))
    for y in (38, 50, 62):
        x.line(3, (16, y - 4), (38, y + 2)); x.line(3, (62, y + 2), (84, y - 4))

@glyph
def staff(p, x):
    p.line(7, (26, 94), (60, 34))
    p.arc(68, 26, 18, 40, 330, 6)
    p.circle(68, 26, 9)

@glyph
def ghost(p, x):
    p.poly((16, 46), (84, 46), (84, 92), (70, 80), (58, 94), (46, 80), (32, 94), (16, 82))
    p.circle(50, 42, 34)
    x.circle(38, 40, 7); x.circle(62, 40, 7)
    x.ell(44, 54, 56, 68)

@glyph
def mask(p, x):
    p.poly((10, 16), (50, 26), (90, 16), (88, 56), (68, 84), (50, 92), (32, 84), (12, 56))
    x.poly((22, 40), (42, 44), (38, 54), (24, 52)); x.poly((78, 40), (58, 44), (62, 54), (76, 52))
    x.arc(50, 58, 12, 20, 160, 4)

@glyph
def mirror(p, x):
    p.ell(24, 6, 76, 70); x.ell(32, 14, 68, 62)
    p.line(4, (42, 22), (54, 40)); p.line(4, (42, 36), (50, 48))
    p.rect(44, 68, 56, 94)

@glyph
def bell(p, x):
    p.circle(50, 12, 7)
    p.poly((36, 18), (64, 18), (72, 44), (84, 74), (16, 74), (28, 44))
    p.rect(10, 74, 90, 82); p.circle(50, 90, 8)

@glyph
def horn(p, x):
    p.arc(62, 30, 40, 70, 200, 14)
    p.poly((22, 28), (6, 8), (34, 14))
    p.poly((76, 66), (94, 74), (66, 92))

@glyph
def banner(p, x):
    p.rect(14, 4, 21, 96)
    p.poly((21, 10), (88, 10), (72, 30), (88, 50), (21, 50))

@glyph
def hammer(p, x):
    p.line(8, (24, 90), (62, 36))
    p.poly((36, 28), (66, 6), (92, 40), (62, 62))

@glyph
def quake(p, x):
    p.poly((6, 58), (34, 44), (44, 58), (66, 40), (94, 58), (94, 92), (66, 92), (58, 72), (44, 92), (6, 92))
    p.line(5, (50, 10), (50, 30)); p.line(5, (26, 18), (34, 34)); p.line(5, (74, 18), (66, 34))

@glyph
def tooth(p, x):
    p.poly((20, 10), (40, 18), (60, 18), (80, 10), (84, 40), (72, 92), (58, 66), (42, 66), (28, 92), (16, 40))

@glyph
def feather(p, x):
    p.poly((84, 8), (60, 12), (32, 36), (24, 66), (40, 70), (68, 54), (88, 28))
    x.line(3.5, (78, 16), (24, 72))
    p.line(4, (26, 70), (12, 92))

@glyph
def clock(p, x):
    p.circle(50, 50, 42); x.circle(50, 50, 33)
    p.line(6, (50, 50), (50, 26)); p.line(6, (50, 50), (68, 58))

@glyph
def potion(p, x):
    p.rect(40, 6, 60, 30); p.circle(50, 62, 32)
    x.circle(40, 54, 6)

@glyph
def orb(p, x):
    p.circle(50, 44, 34); x.circle(40, 34, 8)
    p.poly((24, 76), (76, 76), (84, 94), (16, 94))

@glyph
def sun(p, x):
    p.circle(50, 50, 22)
    for a in range(0, 360, 45):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.line(7, (50 + 32 * c, 50 + 32 * s_), (50 + 45 * c, 50 + 45 * s_))

@glyph
def shout(p, x):
    p.poly((6, 38), (26, 38), (50, 16), (50, 84), (26, 62), (6, 62))
    p.arc(50, 50, 18, -50, 50, 6); p.arc(50, 50, 32, -50, 50, 6); p.arc(50, 50, 46, -40, 40, 6)

@glyph
def chain(p, x):
    for q in ((26, 26), (50, 50), (74, 74)):
        p.ell(q[0] - 19, q[1] - 13, q[0] + 19, q[1] + 13)
        x.ell(q[0] - 11, q[1] - 6, q[0] + 11, q[1] + 6)

@glyph
def target(p, x):
    p.circle(50, 50, 44); x.circle(50, 50, 33); p.circle(50, 50, 23); x.circle(50, 50, 13); p.circle(50, 50, 6)

@glyph
def spiral(p, x):
    pts = []
    for i in range(90):
        t = i / 89
        a = t * 3.1 * 2 * math.pi
        r = 4 + t * 40
        pts.append((50 + r * math.cos(a), 50 + r * math.sin(a)))
    p.line(7, *pts)

@glyph
def wings(p, x):
    for sign in (-1, 1):
        p.poly((50, 62), (50 + sign * 14, 34), (50 + sign * 44, 18), (50 + sign * 46, 34), (50 + sign * 38, 42), (50 + sign * 40, 52), (50 + sign * 28, 58), (50 + sign * 28, 68))
    p.circle(50, 58, 7)

@glyph
def up(p, x):
    p.poly((50, 8), (90, 54), (66, 54), (66, 92), (34, 92), (34, 54), (10, 54))

@glyph
def plus(p, x):
    p.rect(38, 10, 62, 90); p.rect(10, 38, 90, 62)

@glyph
def jump(p, x):
    p.arc(50, 74, 38, 180, 360, 8)
    p.poly((96, 76), (72, 66), (92, 52))
    p.rect(4, 86, 96, 92)

@glyph
def swap(p, x):
    p.arc(50, 50, 32, 200, 340, 8); p.poly((92, 50), (70, 36), (68, 58))
    p.arc(50, 50, 32, 20, 160, 8); p.poly((8, 50), (30, 64), (32, 42))

@glyph
def pause(p, x):
    p.rect(24, 16, 42, 84); p.rect(58, 16, 76, 84)

@glyph
def grab(p, x):
    p.poly((50, 92), (18, 52), (38, 52), (38, 10), (62, 10), (62, 52), (82, 52))

@glyph
def tree(p, x):
    p.circle(50, 20, 13); p.circle(22, 74, 13); p.circle(78, 74, 13); p.circle(50, 74, 13)
    p.line(6, (50, 20), (22, 74)); p.line(6, (50, 20), (78, 74)); p.line(6, (50, 20), (50, 74))

@glyph
def scythe(p, x):
    p.line(7, (34, 94), (62, 12))
    p.poly((60, 14), (24, 8), (6, 30), (28, 22), (56, 28))

@glyph
def pitchfork(p, x):
    p.line(7, (50, 94), (50, 40))
    p.arc(50, 22, 24, 0, 180, 7)
    for dx in (26, 50, 74):
        p.poly((dx - 5, 26), (dx + 5, 26), (dx, 4))

@glyph
def flail(p, x):
    p.line(8, (18, 92), (40, 54))
    p.line(4, (40, 54), (52, 42), (62, 34))
    p.circle(72, 26, 16)
    for a in range(0, 360, 72):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.poly((72 + 26 * c, 26 + 26 * s_), (72 + 13 * c - 6 * s_, 26 + 13 * s_ + 6 * c), (72 + 13 * c + 6 * s_, 26 + 13 * s_ - 6 * c))

@glyph
def torch(p, x):
    p.line(9, (32, 92), (54, 46))
    p.poly((62, 6), (76, 28), (70, 50), (46, 44), (42, 26), (54, 24))

@glyph
def blink(p, x):
    p.poly((68, 12), (82, 50), (68, 88), (42, 88), (56, 50), (42, 12))
    for k, y in enumerate((30, 50, 70)):
        p.line(5, (8 + k * 3, y), (32, y))

@glyph
def mist(p, x):
    for y, a, b in ((24, 18, 74), (44, 28, 88), (64, 12, 68), (84, 30, 80)):
        p.line(8, (a, y), (a + (b - a) * 0.3, y - 6), (a + (b - a) * 0.65, y + 4), (b, y - 2))

@glyph
def burst(p, x):
    p.circle(50, 50, 13)
    for a in range(0, 360, 45):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.line(6, (50 + 22 * c, 50 + 22 * s_), (50 + 44 * c, 50 + 44 * s_))

@glyph
def leap(p, x):
    p.arc(50, 74, 38, 180, 320, 8)
    p.poly((86, 42), (92, 74), (64, 58))
    p.line(7, (6, 90), (34, 90))

@glyph
def rift(p, x):
    p.poly((58, 4), (66, 40), (46, 52), (58, 96), (34, 56), (52, 44))
    p.circle(18, 30, 8)
    p.circle(82, 70, 8)

@glyph
def coin(p, x):
    p.circle(50, 50, 40)
    x.circle(50, 50, 30)
    p.circle(50, 50, 25)
    x.rect(44, 28, 56, 72)
    x.rect(30, 44, 70, 56)

@glyph
def log(p, x):
    p.line(16, (14, 72), (86, 44))
    p.line(16, (14, 42), (70, 20))
    x.circle(80, 46, 4)
    p.line(14, (26, 88), (82, 66))

W = 800

def render(name):
    im = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(im)
    G[name](P(d), e(d))
    im = im.resize((128, 128), Image.LANCZOS)
    rgba = Image.merge("RGBA", (Image.new("L", im.size, 255),) * 3 + (im,))
    rgba.save(f"assets/icons/{name}.png")
    return rgba

if __name__ == "__main__":
    for n in G:
        render(n)
    print(len(G), "icons")
