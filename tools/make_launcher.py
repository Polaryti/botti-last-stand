#!/usr/bin/env python3
"""Draws the launcher icon (plain and adaptive) and the boot splash. All original.
Run from the project root."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

rng = np.random.default_rng(7)
SS = 4  # drawn large, then scaled down


def night_sky(w, h, moon=(0.68, 0.3), moon_r=0.2):
    """Deep blue gradient with stars, a moon behind thin cloud, and a black tree line."""
    yy, xx = np.mgrid[0:h, 0:w]
    u = xx / w
    v = yy / h
    top = np.array([0.03, 0.05, 0.11])
    low = np.array([0.13, 0.2, 0.3])
    rgb = top[None, None] * (1 - v[..., None] ** 1.3) + low[None, None] * v[..., None] ** 1.3
    aspect = w / h
    d = np.sqrt(((u - moon[0]) * aspect) ** 2 + (v - moon[1]) ** 2)
    glow = np.exp(-(d / (moon_r * 1.9)) ** 2)[..., None]
    rgb = rgb + glow * np.array([0.32, 0.28, 0.2])
    disc = np.clip((moon_r - d) * h / 3.0, 0, 1)[..., None]
    moon_col = np.array([0.98, 0.9, 0.68])
    shade = 1.0 - 0.14 * np.exp(-(((u - moon[0] + moon_r * 0.3) * aspect) ** 2 + (v - moon[1] + moon_r * 0.2) ** 2) / (moon_r * 0.45) ** 2)[..., None]
    rgb = rgb * (1 - disc) + moon_col * shade * disc
    im = Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255))
    d2 = ImageDraw.Draw(im)
    for _ in range(int(w * h / 6000)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * 0.6)
        if math.hypot((x / w - moon[0]) * aspect, y / h - moon[1]) < moon_r * 1.05:
            continue
        r = rng.uniform(0.4, 1.3) * h / 700
        c = int(rng.uniform(150, 255))
        d2.ellipse((x - r, y - r, x + r, y + r), fill=(c, c, min(255, c + 20)))
    # Tree line: rows of little firs getting darker towards the viewer.
    for row, (base, tone, scale) in enumerate(((0.8, (9, 15, 26), 0.09), (0.88, (5, 9, 16), 0.13))):
        x = -0.05 * w
        pts = [(0, h)]
        while x < w * 1.05:
            th = rng.uniform(0.6, 1.0) * scale * h
            tw = th * 0.42
            y = base * h + rng.uniform(-0.01, 0.01) * h
            pts += [(x - tw * 0.5, y), (x, y - th), (x + tw * 0.5, y)]
            x += tw * rng.uniform(0.55, 0.95)
        pts.append((w, h))
        d2.polygon(pts, fill=tone)
    return im


def skull(size):
    """A bone-coloured skull with burning eyes and a sword behind it. RGBA, transparent background."""
    n = size * SS
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    S = n / 100.0

    def poly(pts, col):
        d.polygon([(x * S, y * S) for x, y in pts], fill=col)

    def ell(x0, y0, x1, y1, col):
        d.ellipse((x0 * S, y0 * S, x1 * S, y1 * S), fill=col)

    def rrect(x0, y0, x1, y1, r, col):
        d.rounded_rectangle((x0 * S, y0 * S, x1 * S, y1 * S), radius=r * S, fill=col)

    # The sword lies diagonally behind the skull: a blade, a guard and a pommel.
    sword = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sword)
    steel = (178, 188, 204, 255)
    steel_dark = (118, 128, 146, 255)
    brass = (222, 174, 78, 255)
    edge = (20, 14, 12, 255)
    Y = lambda v: (12 + v * 0.8) * S
    sd.polygon([(50 * S, Y(104)), (41 * S, Y(88)), (41 * S, Y(14)), (59 * S, Y(14)), (59 * S, Y(88))], fill=edge)
    sd.polygon([(50 * S, Y(100)), (43.5 * S, Y(87)), (43.5 * S, Y(16)), (56.5 * S, Y(16)), (56.5 * S, Y(87))], fill=steel)
    sd.polygon([(50 * S, Y(100)), (50 * S, Y(16)), (56.5 * S, Y(16)), (56.5 * S, Y(87))], fill=steel_dark)
    sd.rectangle((44 * S, Y(-6), 56 * S, Y(8)), fill=edge)
    sd.rectangle((45.5 * S, Y(-6), 54.5 * S, Y(8)), fill=(112, 68, 38, 255))
    sd.rounded_rectangle((29 * S, Y(6), 71 * S, Y(16)), radius=3 * S, fill=edge)
    sd.rounded_rectangle((31 * S, Y(8), 69 * S, Y(14)), radius=2 * S, fill=brass)
    sd.ellipse((42 * S, Y(-13), 58 * S, Y(1)), fill=edge)
    sd.ellipse((44 * S, Y(-11), 56 * S, Y(-1)), fill=brass)
    sword = sword.rotate(-38, resample=Image.BICUBIC, center=(n / 2, n / 2))
    im.alpha_composite(sword)
    d = ImageDraw.Draw(im)
    # Bone, with an outline for small sizes.
    bone = (238, 228, 200, 255)
    bone_dark = (196, 182, 150, 255)
    line = (20, 14, 12, 255)
    ell(19, 16, 81, 72, line)
    rrect(31, 58, 69, 88, 7, line)
    ell(21.5, 18.5, 78.5, 69.5, bone)
    rrect(33.5, 60, 66.5, 85.5, 5, bone)
    # Shadow down the right side of the head, kept inside the bone, and under the cheekbones.
    shade_mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(shade_mask).ellipse((21.5 * S, 18.5 * S, 78.5 * S, 69.5 * S), fill=255)
    cut = Image.new("L", (n, n), 0)
    ImageDraw.Draw(cut).ellipse((62 * S, 26 * S, 90 * S, 76 * S), fill=120)
    shade_mask = Image.fromarray(np.minimum(np.asarray(shade_mask), np.asarray(cut)))
    im.paste(Image.new("RGBA", (n, n), bone_dark), (0, 0), shade_mask)
    d = ImageDraw.Draw(im)
    poly([(33.5, 66), (66.5, 66), (66.5, 70), (33.5, 70)], bone_dark)
    # Teeth.
    for x in (41, 50, 59):
        rrect(x - 0.9, 69, x + 0.9, 85, 0.5, (70, 56, 44, 255))
    # Nose.
    poly([(50, 53), (45, 63), (55, 63)], line)
    # Crack.
    d.line([(36 * S, 21 * S), (40 * S, 28 * S), (36 * S, 33 * S), (41 * S, 39 * S)], fill=(92, 76, 58, 255), width=int(1.2 * S))
    # Eye sockets.
    ell(26.5, 34, 45.5, 53, line)
    ell(54.5, 34, 73.5, 53, line)
    eyes = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    e = ImageDraw.Draw(eyes)
    for cx in (36, 64):
        e.ellipse(((cx - 7) * S, 37 * S, (cx + 7) * S, 51 * S), fill=(255, 54, 20, 255))
    glow = eyes.filter(ImageFilter.GaussianBlur(4 * S))
    im = Image.alpha_composite(im, glow)
    d = ImageDraw.Draw(im)
    for cx in (36, 64):
        d.ellipse(((cx - 5) * S, 39 * S, (cx + 5) * S, 49 * S), fill=(255, 92, 34, 255))
        d.ellipse(((cx - 2.2) * S, 41.8 * S, (cx + 2.2) * S, 46.2 * S), fill=(255, 226, 150, 255))
    return im.resize((size, size), Image.LANCZOS)


def rounded(im, radius):
    mask = Image.new("L", (im.width * SS, im.height * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, mask.width - 1, mask.height - 1), radius * SS, fill=255)
    mask = mask.resize(im.size, Image.LANCZOS)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def icons():
    bg = night_sky(432, 432, moon=(0.7, 0.26), moon_r=0.2)
    bg.save("assets/ui/icon_background.png")
    # Adaptive icons crop to the middle two thirds, so the skull stays inside that.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    s = skull(270)
    fg.alpha_composite(s, ((432 - 270) // 2, (432 - 270) // 2))
    fg.save("assets/ui/icon_foreground.png")
    # Themed icons on newer Android: one flat shape. Bone and steel stay, outlines and eyes become holes.
    a = np.asarray(fg, dtype=float) / 255.0
    lum = a[..., :3].mean(axis=2)
    red = a[..., 0] - a[..., 1]
    shape = a[..., 3] * (lum > 0.4) * (red < 0.3)
    mono = np.zeros(a.shape, dtype=np.uint8)
    mono[..., :3] = 255
    mono[..., 3] = np.uint8(np.clip(shape, 0, 1) * 255)
    Image.fromarray(mono, "RGBA").save("assets/ui/icon_monochrome.png")
    plain = night_sky(512, 512, moon=(0.72, 0.24), moon_r=0.19).convert("RGBA")
    plain.alpha_composite(skull(404), (54, 62))
    rounded(plain, 96).save("icon.png")


def splash():
    w, h = 1280, 720
    im = night_sky(w, h, moon=(0.76, 0.21), moon_r=0.15).convert("RGBA")
    font = ImageFont.truetype("assets/fonts/MedievalSharp.ttf", 132)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    text = "UNDEAD DROP"
    box = d.textbbox((0, 0), text, font=font)
    x = (w - (box[2] - box[0])) / 2 - box[0]
    y = h * 0.44
    d.text((x, y), text, font=font, fill=(0, 0, 0, 255), stroke_width=9, stroke_fill=(0, 0, 0, 255))
    layer = layer.filter(ImageFilter.GaussianBlur(5))
    d = ImageDraw.Draw(layer)
    d.text((x, y), text, font=font, fill=(255, 212, 118, 255), stroke_width=3, stroke_fill=(44, 24, 10, 255))
    im.alpha_composite(layer)
    im.convert("RGB").save("assets/ui/splash.png")


if __name__ == "__main__":
    icons()
    splash()
    print("launcher icons and splash done")
