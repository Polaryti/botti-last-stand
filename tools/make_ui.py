#!/usr/bin/env python3
"""Draws the small images the interface uses: discs for icons, the slider knob, the shade behind the
menu, the Botti Doubloon and the wordmark. The rest of the look is flat colour, set in scripts/ui_theme.gd.
Run from the project root."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "assets/ui/"


def disc_alpha(size, radius, feather=1.2):
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.hypot(xx + 0.5 - size / 2, yy + 0.5 - size / 2)
    return np.clip((radius - d) / feather + 0.5, 0, 1), d


def save_rgba(name, rgb, a):
    arr = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    Image.fromarray(np.uint8(arr * 255 + 0.5), "RGBA").save(OUT + name + ".png")


def medal():
    """A plain disc for icons. White, so each class can tint it. A little lighter at the top."""
    n = 128
    a, _ = disc_alpha(n, 62.5)
    yy, _x = np.mgrid[0:n, 0:n]
    v = 1.0 - 0.28 * (yy / n)
    save_rgba("medal", np.dstack([v, v, v]), a)


def ring():
    """A hairline around each icon."""
    n = 128
    outer, _ = disc_alpha(n, 63.0)
    inner, _ = disc_alpha(n, 59.5)
    a = (outer - inner) * 0.85
    save_rgba("ring", np.ones((n, n, 3)) * np.array([0.94, 0.9, 0.82]), a)


def glass():
    """The disc under a touch control: dark and see-through, so the game shows behind it."""
    n = 128
    a, d = disc_alpha(n, 62.5)
    v = 0.3 + 0.12 * (1.0 - d / 64.0)
    save_rgba("glass", np.dstack([v, v, v]), a * 0.62)


def knob():
    n = 48
    a, _ = disc_alpha(n, 19.0)
    save_rgba("knob", np.ones((n, n, 3)) * np.array([0.937, 0.663, 0.247]), a)


def shades():
    # Keeps text readable over the moving village. Dark on the left, gone by two thirds of the way across.
    w, h = 512, 8
    xx = np.linspace(0, 1, w)[None, :].repeat(h, 0)
    a = np.clip(1.0 - xx / 0.72, 0, 1) ** 1.3 * 0.93
    save_rgba("menu_shade", np.ones((h, w, 3)) * np.array([0.05, 0.07, 0.11]), a)
    # Everything else: the edges of the screen fall away.
    w, h = 256, 144
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    a = np.clip((d - 0.35) / 1.0, 0, 1) ** 1.2 * 0.75 + 0.42
    save_rgba("vignette", np.ones((h, w, 3)) * np.array([0.04, 0.055, 0.09]), a)


def doubloon():
    """A hand-struck gold coin: a slightly uneven edge, a beaded border and a raised B."""
    n = 256 * 3
    c = n / 2
    yy, xx = np.mgrid[0:n, 0:n]
    dx, dy = xx + 0.5 - c, yy + 0.5 - c
    ang = np.arctan2(dy, dx)
    d = np.hypot(dx, dy) / (c * 0.96)
    # Struck by hand, so the outline is never quite round.
    edge = 1.0 + 0.012 * np.sin(ang * 3 + 0.6) + 0.008 * np.sin(ang * 7 + 2.0) + 0.004 * np.sin(ang * 13)
    r = d / edge
    alpha = np.clip((1.0 - r) * c * 0.96 / 2.0 + 0.5, 0, 1)
    # Height field: a raised rim, a sunk field, beads, and the letter.
    height = np.zeros((n, n))
    height += np.clip((r - 0.8) / 0.05, 0, 1) * 1.0
    height -= np.clip((r - 0.965) / 0.035, 0, 1) * 1.0
    beads = 36
    bead_ang = (ang / math.tau * beads) % 1.0 - 0.5
    bead_r = np.hypot(bead_ang * (math.tau * 0.71 / beads), r - 0.71)
    height += np.clip((0.021 - bead_r) / 0.012, 0, 1) * 0.55
    font = ImageFont.truetype("assets/fonts/Cinzel-Black.ttf", int(n * 0.5))
    letter = Image.new("L", (n, n), 0)
    ld = ImageDraw.Draw(letter)
    box = ld.textbbox((0, 0), "B", font=font)
    ld.text((c - (box[0] + box[2]) / 2, c - (box[1] + box[3]) / 2), "B", font=font, fill=255)
    letter = letter.filter(ImageFilter.GaussianBlur(n * 0.0035))
    height += np.asarray(letter, dtype=float) / 255.0 * 1.0
    height = np.asarray(Image.fromarray(np.uint8(np.clip(height + 0.2, 0, 2) * 120)).filter(ImageFilter.GaussianBlur(n * 0.0022)), dtype=float) / 120.0
    # Light from the upper left.
    gy, gx = np.gradient(height)
    relief = (-gx - gy) * n * 0.02
    base = np.array([0.93, 0.68, 0.2])
    shine = np.array([1.0, 0.92, 0.6])
    deep = np.array([0.52, 0.31, 0.08])
    sweep = np.clip(0.5 - (dx + dy) / (n * 1.1), 0, 1)[..., None]
    rgb = base * (0.78 + 0.34 * sweep)
    # A worn surface, so the gold does not look like plastic.
    rng = np.random.default_rng(11)
    wear = np.asarray(Image.fromarray(np.uint8(rng.uniform(0, 255, (n // 8, n // 8)))).resize((n, n), Image.BICUBIC), dtype=float)[..., None] / 255.0 - 0.5
    rgb = rgb * (1.0 + wear * 0.09)
    t = np.clip(relief, -1, 1)[..., None]
    rgb = np.where(t > 0, rgb + (shine - rgb) * t, rgb + (deep - rgb) * -t)
    # The dark line where the coin's rim meets the air.
    rgb = rgb * (1.0 - np.clip((r - 0.975) / 0.025, 0, 1)[..., None] * 0.45)
    img = Image.fromarray(np.uint8(np.dstack([np.clip(rgb, 0, 1), alpha]) * 255 + 0.5), "RGBA")
    img.resize((256, 256), Image.LANCZOS).save(OUT + "doubloon.png")


def wordmark(size=132):
    """The game's name, lit a little from below, as if by a fire nobody can see."""
    font = ImageFont.truetype("assets/fonts/Cinzel-Black.ttf", size * 3)
    text = "Botti's Last Stand"
    probe = ImageDraw.Draw(Image.new("L", (8, 8)))
    box = probe.textbbox((0, 0), text, font=font)
    pad = 60 * 3 // 3
    w, h = box[2] - box[0] + pad * 2, box[3] - box[1] + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - box[0], pad - box[1]), text, font=font, fill=255)
    m = np.asarray(mask, dtype=float) / 255.0
    v = np.linspace(0, 1, h)[:, None]
    top = np.array([0.965, 0.94, 0.88])
    low = np.array([0.98, 0.76, 0.42])
    rgb = top * (1 - np.clip((v - 0.35) / 0.4, 0, 1)[..., None]) + low * np.clip((v - 0.35) / 0.4, 0, 1)[..., None]
    rgb = np.broadcast_to(rgb, (h, w, 3))
    glow = np.asarray(mask.filter(ImageFilter.GaussianBlur(size * 0.28)), dtype=float) / 255.0
    shadow = np.asarray(mask.filter(ImageFilter.GaussianBlur(size * 0.07)), dtype=float) / 255.0
    # Over the night: first a soft dark edge, then a faint warm halo, then the letters.
    out_rgb = np.zeros((h, w, 3))
    out_a = np.zeros((h, w))
    out_rgb += np.array([0.95, 0.5, 0.14])
    out_a = glow * 0.4
    sa = shadow * 0.7
    out_rgb = (out_rgb * out_a[..., None] * (1 - sa[..., None]) + np.array([0.02, 0.03, 0.05]) * sa[..., None]) / np.maximum(out_a + sa - out_a * sa, 0.001)[..., None]
    out_a = out_a + sa - out_a * sa
    out_rgb = (out_rgb * out_a[..., None] * (1 - m[..., None]) + rgb * m[..., None]) / np.maximum(out_a + m - out_a * m, 0.001)[..., None]
    out_a = out_a + m - out_a * m
    img = Image.fromarray(np.uint8(np.dstack([np.clip(out_rgb, 0, 1), out_a]) * 255 + 0.5), "RGBA")
    img = img.resize((w // 3 * 1, h // 3 * 1), Image.LANCZOS)
    img.save(OUT + "wordmark.png")


if __name__ == "__main__":
    medal()
    ring()
    glass()
    knob()
    shades()
    doubloon()
    wordmark()
    print("interface images done")
