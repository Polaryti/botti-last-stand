#!/usr/bin/env python3
"""Draws the launcher icon (plain, adaptive and themed), its Dev build variant, and the boot splash.
All original. Run from the project root.

The icon follows the game's latest expansion. Each expansion is a theme in THEMES (a backdrop and the
bell's metal and light); EDITION names the one in use. To brand a new expansion, add its theme and set
EDITION, then run this again: icon.png, assets/ui/icon_*.png and the Dev build's assets/ui/dev/icon_*.png
are all remade from it. The Dev build (tools/prepare_dev_build.py) uses the dev files: the same icon
with a DEV band across it, so it is never mistaken for the real game on a phone with both installed.

  valleys           0.1 to 0.21: the village bell before the moon, lit from below by a fire.
  beyond_the_mists  0.22: the bell before the Great Portal's violet ring, lit from below by the teal
                    light of the Mists, over the peaks beyond them and their low mist.
  sunken_crown      0.23: the bell in sea-green bronze wearing the Sunken Crown, under the aurora of
                    Vael, over the night sea and the drowned city's spires with their green windows.

The splash is the edition's backdrop, wide, under the wordmark and the update's name, so run
tools/make_ui.py first if that changed."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 4  # drawn large, then scaled down
TOP = np.array([0.043, 0.067, 0.122])
LOW = np.array([0.125, 0.180, 0.255])
MOON = np.array([0.945, 0.875, 0.70])
HALO = np.array([0.20, 0.19, 0.17])


def sky(w, h, moon, moon_r, trees=True, stars_seed=7):
    """Night blue running lighter towards the horizon, the moon, a few stars and two rows of firs.
    moon is given as a share of the picture's height from the top and of its width from the left."""
    rng = np.random.default_rng(stars_seed)
    yy, xx = np.mgrid[0:h, 0:w]
    v = (yy / h)[..., None]
    rgb = TOP * (1 - v ** 1.25) + LOW * v ** 1.25
    dist = np.hypot((xx / w - moon[0]) * w / h, yy / h - moon[1])
    rgb = rgb + np.exp(-(dist / (moon_r * 1.7)) ** 2)[..., None] * HALO
    disc = np.clip((moon_r - dist) * h / 2.2, 0, 1)[..., None]
    # The moon's face: broad, soft patches rather than cartoon craters.
    face = np.ones((h, w, 1))
    for a, r, size in ((0.5, 0.55, 0.42), (1.9, 0.72, 0.26), (3.6, 0.48, 0.2), (4.7, 0.78, 0.34), (5.8, 0.3, 0.16)):
        cx, cy = moon[0] + np.cos(a) * r * moon_r * h / w, moon[1] + np.sin(a) * r * moon_r
        face -= 0.05 * np.exp(-(np.hypot((xx / w - cx) * w / h, yy / h - cy) / (size * moon_r)) ** 2)[..., None]
    rgb = rgb * (1 - disc) + MOON * face * disc
    im = Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255 + 0.5))
    draw = ImageDraw.Draw(im)
    for _ in range(int(w * h / 5200)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * 0.62)
        if np.hypot((x / w - moon[0]) * w / h, y / h - moon[1]) < moon_r * 1.25:
            continue
        r = rng.uniform(0.35, 1.05) * h / 700
        c = int(rng.uniform(120, 225))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(c, c, min(255, c + 18)))
    if trees:
        for base, tone, scale in ((0.83, (12, 19, 31), 0.085), (0.91, (6, 10, 17), 0.12)):
            x = -0.05 * w
            pts = [(0, h)]
            while x < w * 1.05:
                th = rng.uniform(0.55, 1.0) * scale * h
                tw = th * 0.44
                y = base * h + rng.uniform(-0.008, 0.008) * h
                pts += [(x - tw * 0.5, y), (x, y - th), (x + tw * 0.5, y)]
                x += tw * rng.uniform(0.55, 0.95)
            pts.append((w, h))
            draw.polygon(pts, fill=tone)
    return im


def _profile(n=200):
    """Half the bell's width down its height, both as shares of its height. Smooth through hand-set points."""
    ys = np.array([0.0, 0.05, 0.13, 0.28, 0.46, 0.63, 0.76, 0.86, 0.94, 1.0])
    ws = np.array([0.135, 0.205, 0.245, 0.265, 0.285, 0.325, 0.385, 0.455, 0.525, 0.555])
    t = np.linspace(0, 1, n)
    w = np.interp(t, ys, ws)
    kernel = np.hanning(21)
    kernel /= kernel.sum()
    pad = np.concatenate([np.full(10, w[0]), w, np.full(10, w[-1])])
    return t, np.convolve(pad, kernel, mode="valid")


def bell_mask(size):
    """The bell's shape at this size, large: crown, shoulder, flared lip and clapper."""
    n = size * SS
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    t, w = _profile()
    top, height = 0.15 * n, 0.665 * n
    cx = n / 2
    pts = [(cx + a * height, top + b * height) for b, a in zip(t, w)]
    pts += [(cx - a * height, top + b * height) for b, a in zip(t[::-1], w[::-1])]
    d.polygon(pts, fill=255)
    # The round head on top of the shoulder.
    d.rounded_rectangle((cx - 0.10 * height, top - 0.075 * height, cx + 0.10 * height, top + 0.05 * height), 0.04 * height, fill=255)
    # The loop it hangs from.
    r_out, r_in = 0.105 * height, 0.058 * height
    cy = top - 0.115 * height
    d.ellipse((cx - r_out, cy - r_out, cx + r_out, cy + r_out), fill=255)
    d.ellipse((cx - r_in, cy - r_in, cx + r_in, cy + r_in), fill=0)
    # The clapper, under the lip with a small gap.
    r = 0.078 * height
    c_y = top + height + 0.075 * height
    d.ellipse((cx - r, c_y - r, cx + r, c_y + r), fill=255)
    # Two thin bands and the base of the lip, cut out.
    for b, thick in ((0.20, 0.012), (0.24, 0.006), (0.895, 0.012)):
        y = top + b * height
        half = np.interp(b, t, w) * height + 2
        d.rectangle((cx - half, y, cx + half, y + thick * height), fill=0)
    return mask, top, height


BELL_FIRE = {"dark": (0.070, 0.088, 0.125), "warm": (0.74, 0.40, 0.12), "hot": (0.98, 0.70, 0.30), "rim": (0.86, 0.80, 0.66)}


def bell(size, metal=BELL_FIRE):
    """Dark metal, lighter towards the lip where the light from below reaches it, with a thin rim of
    light from above. `metal` gives its colours: dark, warm (the light from below), hot, rim."""
    mask, top, height = bell_mask(size)
    n = size * SS
    m = np.asarray(mask, dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n]
    v = np.clip((yy - top) / height, -0.3, 1.25)
    u = (xx - n / 2) / (height * 0.56)
    dark = np.array(metal["dark"])
    warm = np.array(metal["warm"])
    hot = np.array(metal["hot"])
    heat = np.clip((v - 0.42) / 0.62, 0, 1) ** 1.6
    # The light comes from below and in front, so it fades towards the edges of the round metal.
    heat = heat * np.clip(1.08 - np.abs(u) ** 2.2 * 0.75, 0, 1)
    rgb = dark[None, None] * (1 - heat[..., None]) + warm[None, None] * heat[..., None]
    rgb = rgb + (hot - warm)[None, None] * (np.clip((v - 0.92) / 0.2, 0, 1) * np.clip(1.0 - np.abs(u) * 0.8, 0, 1))[..., None]
    # Moonlight just inside the outline, strongest on the upper part.
    blur = np.asarray(mask.filter(ImageFilter.GaussianBlur(height * 0.012)), dtype=float) / 255.0
    rim = np.clip((1.0 - blur) * m * 2.2, 0, 1) * np.clip(1.0 - v * 0.6, 0.25, 1)
    rgb = rgb * (1 - rim[..., None] * 0.75) + np.array(metal["rim"])[None, None] * rim[..., None] * 0.75
    arr = np.dstack([np.clip(rgb, 0, 1), m])
    im = Image.fromarray(np.uint8(arr * 255 + 0.5), "RGBA")
    return im.resize((size, size), Image.LANCZOS)


def rounded(im, radius):
    mask = Image.new("L", (im.width * SS, im.height * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, mask.width - 1, mask.height - 1), radius * SS, fill=255)
    mask = mask.resize(im.size, Image.LANCZOS)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def valleys_backdrop(w, h, adaptive):
    """The village night: the moon behind the bell, stars, two rows of firs."""
    if adaptive:
        return sky(w, h, (0.5, 0.455), 0.235)
    return sky(w, h, (0.5, 0.44), 0.325)


def mists_backdrop(w, h, adaptive, seed=22):
    """Beyond the Mists: a violet dusk, the Great Portal's ring turning behind the bell (violet, its
    heart going teal), the peaks beyond the Mists below, the low mist over them and its teal lights."""
    rng = np.random.default_rng(seed)
    cy = 0.455 if adaptive else 0.44
    radius = 0.235 if adaptive else 0.33
    yy, xx = np.mgrid[0:h, 0:w]
    v = (yy / h)[..., None]
    rgb = np.array([0.055, 0.035, 0.13]) * (1 - v ** 1.2) + np.array([0.24, 0.13, 0.33]) * v ** 1.2
    dx, dy = xx / w - 0.5, yy / h - cy
    dist = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    rr = dist / radius
    # Its glow on the dusk around it.
    rgb = rgb + np.exp(-((rr - 1.0) / 0.55) ** 2)[..., None] * np.array([0.22, 0.12, 0.36]) * 0.8
    # Inside: arms of light turning in, violet at the rim, teal at the heart.
    swirl = 0.5 + 0.5 * np.sin(ang * 3.0 + np.log(np.maximum(rr, 0.02)) * 5.5)
    inside = np.clip(1.0 - rr, 0, 1)
    heart = np.array([0.30, 0.85, 0.85]) * (1 - rr[..., None]) ** 2 + np.array([0.42, 0.25, 0.70]) * (1 - (1 - rr[..., None]) ** 2)
    body = np.array([0.10, 0.06, 0.22]) + heart * (0.35 + 0.9 * swirl[..., None] ** 1.5)
    mix = np.clip((1.0 - rr) * 6.0, 0, 1)[..., None] * (rr < 1.0)[..., None]
    rgb = rgb * (1 - mix) + body * mix
    # The ring itself: bright violet edged in white-teal.
    ring = np.exp(-((rr - 1.0) / 0.045) ** 2)[..., None]
    rgb = rgb * (1 - ring * 0.85) + np.array([0.78, 0.66, 1.0]) * ring
    rgb = rgb + np.exp(-((rr - 0.94) / 0.02) ** 2)[..., None] * np.array([0.35, 0.8, 0.8]) * 0.45
    im = Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255 + 0.5)).convert("RGBA")
    draw = ImageDraw.Draw(im)
    for _ in range(int(w * h / 3800)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * 0.55)
        if np.hypot(x / w - 0.5, y / h - cy) < radius * 1.15:
            continue
        r = rng.uniform(0.35, 1.0) * h / 700
        a = int(rng.uniform(90, 210))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(235, 225, 255, a))
    # The peaks beyond the Mists, and mist lying over them.
    for k, (base, tall, tone) in enumerate(((0.8, 0.12, (52, 34, 74)), (0.9, 0.1, (24, 15, 38)))):
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(_ridge(w, h, rng, base, tall), fill=tone + (255,))
        im.alpha_composite(layer)
        mist = np.exp(-((yy / h - (base + 0.02)) / 0.035) ** 2) * (0.42 - 0.12 * k)
        haze = np.zeros((h, w, 4), dtype=np.uint8)
        haze[..., :3] = (200, 175, 235)
        haze[..., 3] = np.uint8(np.clip(mist, 0, 1) * 255)
        im.alpha_composite(Image.fromarray(haze, "RGBA"))
    # Teal lights drifting in the mist.
    lights = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lights)
    for _ in range(9):
        x, y = rng.uniform(0.06, 0.94) * w, rng.uniform(0.66, 0.9) * h
        r = rng.uniform(0.006, 0.013) * h
        ld.ellipse((x - r, y - r, x + r, y + r), fill=(120, 245, 235, 230))
    im.alpha_composite(lights.filter(ImageFilter.GaussianBlur(h * 0.006)))
    im.alpha_composite(lights)
    return im


def _spire(draw, x, base, height, width, tone, lit, rng, scale):
    """A drowned tower: a body, a needle roof, a little turret beside it, a few windows still lit."""
    draw.rectangle((x - width / 2, base - height * 0.62, x + width / 2, base), fill=tone)
    draw.polygon([(x - width * 0.62, base - height * 0.6), (x, base - height), (x + width * 0.62, base - height * 0.6)], fill=tone)
    side = rng.choice([-1, 1])
    tx = x + side * width * 0.78
    draw.rectangle((tx - width * 0.24, base - height * 0.38, tx + width * 0.24, base), fill=tone)
    draw.polygon([(tx - width * 0.32, base - height * 0.37), (tx, base - height * 0.55), (tx + width * 0.32, base - height * 0.37)], fill=tone)
    windows = []
    for _ in range(int(rng.integers(2, 5))):
        wy = base - height * rng.uniform(0.12, 0.55)
        wx = x + rng.uniform(-0.22, 0.22) * width
        windows.append((wx - 0.7 * scale, wy - 1.8 * scale, wx + 0.7 * scale, wy + 1.8 * scale))
    for box in windows:
        lit.rectangle(box, fill=(120, 255, 205, 255))


def crown_backdrop(w, h, adaptive, seed=23):
    """The Sunken Crown: the night over Vael. A green aurora hangs in folds across the sky and lights
    the sea under it; the drowned city's spires stand out of the water on the horizon, windows still lit."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    sea_y = 0.70 if adaptive else 0.72
    rgb = np.array([0.012, 0.025, 0.06])[None, None] * (1 - v[..., None] ** 1.3) + np.array([0.03, 0.12, 0.15])[None, None] * v[..., None] ** 1.3
    # The aurora: curtains that fold along the sky, brightest at their lower hem, fading upward.
    hem = 0.36 + 0.07 * np.sin(u * 7.0 + 0.6) + 0.03 * np.sin(u * 17.0 + 1.3)
    above = hem - v
    folds = 0.55 + 0.45 * np.sin(u * 38.0 + np.sin(u * 9.0) * 2.4) ** 2
    veil = np.where(above > 0, np.exp(-above / 0.17), np.exp(-(above / 0.025) ** 2)) * folds
    veil *= 0.55 + 0.45 * np.sin(u * 3.2 + 0.4) ** 2
    rgb = rgb + veil[..., None] * np.array([0.16, 0.62, 0.42]) * 0.9
    rgb = rgb + (np.clip(veil - 0.65, 0, 1) ** 2)[..., None] * np.array([0.5, 1.0, 0.8]) * 0.8
    # A violet fringe high up, as auroras have.
    rgb = rgb + (np.exp(-((v - (hem - 0.22)) / 0.06) ** 2) * folds * 0.25)[..., None] * np.array([0.35, 0.18, 0.5])
    # The green glow on the horizon, where the drowned city lies.
    rgb = rgb + np.exp(-((v - sea_y) / 0.07) ** 2)[..., None] * np.array([0.05, 0.28, 0.22])
    # The sea: dark, with the aurora's light lying on it in long broken streaks.
    sea = v > sea_y
    depth = np.clip((v - sea_y) / (1 - sea_y), 0, 1)
    water = np.array([0.02, 0.08, 0.10])[None, None] * (1 - depth[..., None]) + np.array([0.01, 0.04, 0.06])[None, None] * depth[..., None]
    # The horizon's glow lies on the water just under it.
    water = water + np.exp(-((v - sea_y) / 0.035) ** 2)[..., None] * np.array([0.04, 0.2, 0.16])
    rgb = np.where(sea[..., None], water, rgb)
    im = Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255 + 0.5)).convert("RGBA")
    draw = ImageDraw.Draw(im)
    for _ in range(int(w * h / 3400)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * sea_y * 0.75)
        r = rng.uniform(0.3, 0.95) * h / 700
        a = int(rng.uniform(70, 200))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(225, 245, 240, a))
    # The drowned city on the horizon: tall spires on both sides, low ones in the middle behind the bell.
    city = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    lit = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd, ld = ImageDraw.Draw(city), ImageDraw.Draw(lit)
    base = sea_y * h + 1
    scale = h / 432
    for x, tall in ((0.05, 0.27), (0.13, 0.19), (0.21, 0.31), (0.30, 0.12), (0.40, 0.08), (0.60, 0.09), (0.70, 0.14),
            (0.79, 0.33), (0.87, 0.2), (0.96, 0.25)):
        _spire(cd, x * w, base, tall * h * (0.8 if adaptive else 1.0), 0.028 * w, (6, 22, 26, 255), ld, rng, scale)
    im.alpha_composite(city)
    im.alpha_composite(lit.filter(ImageFilter.GaussianBlur(3 * scale)))
    im.alpha_composite(lit)
    # Their reflections, broken by the swell.
    refl = city.transpose(Image.FLIP_TOP_BOTTOM)
    shift = int(h - 2 * base)
    mirror_im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mirror_im.alpha_composite(refl, (0, -shift) if shift < 0 else (0, 0), (0, shift) if shift > 0 else (0, 0))
    arr = np.asarray(mirror_im).copy()
    arr[..., 3] = (arr[..., 3] * np.clip(0.55 - (v - sea_y) * 2.2, 0, 1) * (v > sea_y)).astype(np.uint8)
    im.alpha_composite(Image.fromarray(arr, "RGBA").filter(ImageFilter.GaussianBlur(1.5 * scale)))
    # The aurora's light on the swell: short broken dashes, longer and brighter near, where the sky
    # above that part of the sea is brightest.
    column = veil[: int(h * 0.5)].mean(axis=0)
    column = column / max(column.max(), 1e-6)
    dashes = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dashes)
    for _ in range(int(w * h / 2600)):
        depth_share = rng.uniform(0, 1) ** 1.6
        y = (sea_y + 0.012 + depth_share * (0.98 - sea_y)) * h
        x = rng.uniform(0, w)
        bright = column[min(w - 1, int(x))] * (0.35 + 0.65 * depth_share)
        if rng.uniform() > 0.25 + bright:
            continue
        half = (0.004 + depth_share * 0.022) * w * rng.uniform(0.3, 1.0)
        thick = max(1.0, (0.5 + depth_share * 1.4) * h / 432)
        a = int(np.clip(30 + 120 * bright, 0, 170))
        dd.line((x - half, y, x + half, y), fill=(110, 235, 190, a), width=int(round(thick)))
    im.alpha_composite(dashes.filter(ImageFilter.GaussianBlur(0.6 * h / 432)))
    # Corpse-lights drifting low over the water.
    lights = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(lights)
    for _ in range(7):
        x, y = rng.uniform(0.05, 0.95) * w, rng.uniform(sea_y + 0.04, 0.95) * h
        r = rng.uniform(0.005, 0.011) * h
        gd.ellipse((x - r, y - r, x + r, y + r), fill=(110, 255, 200, 220))
    im.alpha_composite(lights.filter(ImageFilter.GaussianBlur(h * 0.008)))
    im.alpha_composite(lights)
    return im


CROWN_GOLD = {"dark": (0.30, 0.22, 0.09), "mid": (0.74, 0.58, 0.28), "light": (0.98, 0.88, 0.58)}


def crown(size, tilt=-9.0):
    """The Sunken Crown: a band of sea-dulled gold, five points of two heights each tipped with a pearl,
    a green stone in the front, a little crust of verdigris. Drawn on its own, to sit on the bell's head."""
    n = size * SS
    shape = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(shape)
    left, right = 0.08 * n, 0.92 * n
    band_top, band_low = 0.56 * n, 0.80 * n
    pts = [(left, band_low), (left, band_top)]
    peaks = [(0.08, 0.27), (0.29, 0.38), (0.5, 0.16), (0.71, 0.38), (0.92, 0.27)]
    for i, (px, py) in enumerate(peaks):
        x = left + (right - left) * (px - 0.08) / 0.84
        pts.append((x, py * n + 0.06 * n))
        if i < len(peaks) - 1:
            nx = left + (right - left) * (peaks[i + 1][0] - 0.08) / 0.84
            pts.append(((x + nx) / 2, band_top + 0.02 * n))
    pts += [(right, band_top), (right, band_low)]
    d.polygon(pts, fill=255)
    pearls = []
    for px, py in peaks:
        x = left + (right - left) * (px - 0.08) / 0.84
        r = 0.055 * n if py < 0.2 else 0.045 * n
        d.ellipse((x - r, py * n + 0.06 * n - r * 1.6, x + r, py * n + 0.06 * n + r * 0.4), fill=255)
        pearls.append((x, py * n + 0.06 * n - r * 0.6, r))
    m = np.asarray(shape, dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n]
    g = CROWN_GOLD
    # Lit from below by the sea's glow and from above-left by the aurora: a soft vertical ramp.
    t = np.clip((yy / n - 0.2) / 0.62, 0, 1)
    shade = np.clip(0.25 + 0.75 * np.sin(np.clip((xx / n - 0.05) / 0.9, 0, 1) * np.pi) ** 0.6, 0, 1)
    rgb = (np.array(g["light"]) * (1 - t[..., None]) + np.array(g["mid"]) * t[..., None]) * shade[..., None] + np.array(g["dark"]) * (1 - shade[..., None])
    band = (yy > band_top) & (yy < band_low)
    edge = (np.abs(yy - band_top) < 0.018 * n) | (np.abs(yy - band_low) < 0.02 * n)
    rgb = np.where((band & edge)[..., None], rgb * 0.62, rgb)
    # Verdigris where the sea has had it longest: low on the band, in patches.
    crust = np.clip(np.sin(xx / n * 31.0) * np.sin(yy / n * 23.0 + 1.0) * 1.4 - 0.5, 0, 1) * np.clip((yy / n - 0.6) * 4.0, 0, 1)
    rgb = rgb * (1 - crust[..., None] * 0.7) + np.array([0.24, 0.62, 0.52]) * crust[..., None] * 0.7
    out = Image.fromarray(np.uint8(np.dstack([np.clip(rgb, 0, 1), m]) * 255 + 0.5), "RGBA")
    od = ImageDraw.Draw(out)
    for x, y, r in pearls:
        od.ellipse((x - r * 0.8, y - r * 0.8, x + r * 0.8, y + r * 0.8), fill=(222, 240, 232, 255))
        od.ellipse((x - r * 0.45, y - r * 0.55, x - r * 0.05, y - r * 0.15), fill=(255, 255, 255, 255))
    gx, gy, gr = n * 0.5, (band_top + band_low) / 2, 0.075 * n
    od.ellipse((gx - gr * 1.25, gy - gr * 1.25, gx + gr * 1.25, gy + gr * 1.25), fill=(86, 62, 22, 255))
    od.ellipse((gx - gr, gy - gr, gx + gr, gy + gr), fill=(60, 230, 170, 255))
    od.ellipse((gx - gr * 0.5, gy - gr * 0.6, gx - gr * 0.05, gy - gr * 0.15), fill=(200, 255, 235, 255))
    for k in (-1, 1):
        sx = n * 0.5 + k * 0.26 * n
        od.ellipse((sx - gr * 0.55, gy - gr * 0.55, sx + gr * 0.55, gy + gr * 0.55), fill=(150, 40, 60, 255))
    out = out.rotate(tilt, resample=Image.BICUBIC, center=(n / 2, n * 0.6))
    return out.resize((size, size), Image.LANCZOS)


def crowned_bell(size, metal):
    """The bell with the Sunken Crown set at a tilt on its head, and the sea's light glowing round it.
    The bell is drawn a little smaller and low in the square, so the crown has room above it."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bs = int(size * 0.82)
    b = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b.alpha_composite(bell(bs, metal), ((size - bs) // 2, size - bs))
    # A soft green halo round the bell, so it stands out of the night.
    alpha = np.asarray(b)[..., 3].astype(float)
    glow = np.zeros((size, size, 4), dtype=np.uint8)
    glow[..., :3] = (70, 220, 170)
    glow[..., 3] = np.uint8(np.clip(alpha * 0.55, 0, 255))
    im.alpha_composite(Image.fromarray(glow, "RGBA").filter(ImageFilter.GaussianBlur(size * 0.03)))
    im.alpha_composite(b)
    top, height = size - bs + 0.15 * bs, 0.665 * bs
    cw = int(height * 0.62)
    im.alpha_composite(crown(cw), (int(size / 2 - cw * 0.5 + height * 0.02), int(top - height * 0.2 - cw * 0.5)))
    return im


THEMES = {
    "valleys": {"backdrop": valleys_backdrop, "metal": BELL_FIRE},
    "beyond_the_mists": {"backdrop": mists_backdrop,
        "metal": {"dark": (0.065, 0.055, 0.12), "warm": (0.22, 0.62, 0.68), "hot": (0.62, 0.98, 0.94), "rim": (0.80, 0.70, 1.0)}},
    "sunken_crown": {"backdrop": crown_backdrop, "crowned": True, "title": "The Sunken Crown", "title_ink": (150, 240, 205),
        "metal": {"dark": (0.07, 0.15, 0.15), "warm": (0.20, 0.58, 0.48), "hot": (0.62, 1.0, 0.84), "rim": (0.74, 0.96, 0.88)}},
}
EDITION = "beyond_the_mists"

DEV_BAND = (242, 168, 58)    # amber: the Dev build's band
DEV_INK = (30, 18, 10)


def dev_band(im, centre_y, width_share, height_share, mono=False):
    """A band across the picture with DEV on it, tilted a little, inside the part every launcher shows.
    `mono`: for the themed icon, which is one flat shape: a white band with the letters cut through
    the whole icon."""
    w, h = im.size
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    letters = Image.new("L", big.size, 0)
    d = ImageDraw.Draw(big)
    bw, bh = w * SS * width_share, h * SS * height_share
    cx, cy = w * SS / 2, h * SS * centre_y
    d.rounded_rectangle((cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2), bh * 0.22,
        fill=(255, 255, 255, 255) if mono else DEV_BAND + (255,), outline=None if mono else (20, 12, 8, 255), width=int(bh * 0.06))
    font = ImageFont.truetype("assets/fonts/FiraSans-Bold.ttf", int(bh * 0.74))
    box = d.textbbox((0, 0), "DEV", font=font)
    at = (cx - (box[2] - box[0]) / 2 - box[0], cy - (box[3] - box[1]) / 2 - box[1])
    if mono:
        ImageDraw.Draw(letters).text(at, "DEV", font=font, fill=255)
    else:
        d.text(at, "DEV", font=font, fill=DEV_INK + (255,))
    big = big.rotate(-8, resample=Image.BICUBIC, center=(cx, cy))
    out = im.copy()
    out.alpha_composite(big.resize((w, h), Image.LANCZOS))
    if mono:
        cut = np.asarray(letters.rotate(-8, resample=Image.BICUBIC, center=(cx, cy)).resize((w, h), Image.LANCZOS)).astype(np.int32)
        arr = np.asarray(out).copy()
        arr[..., 3] = np.clip(arr[..., 3].astype(np.int32) - cut, 0, 255).astype(np.uint8)
        out = Image.fromarray(arr, "RGBA")
    return out


def icons(edition=EDITION):
    theme = THEMES[edition]
    os.makedirs("assets/ui/dev", exist_ok=True)
    # Adaptive icons crop to the middle two thirds, so the bell and the ring stay inside that.
    background = theme["backdrop"](432, 432, True)
    background.convert("RGB").save("assets/ui/icon_background.png")
    background.convert("RGB").save("assets/ui/dev/icon_background.png")
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    if theme.get("crowned"):
        # The crown stands above the bell's head, so the pair is drawn a little smaller and lower to
        # stay inside the middle the launchers show.
        fg.alpha_composite(crowned_bell(300, theme["metal"]), ((432 - 300) // 2, (432 - 300) // 2 + 4))
    else:
        fg.alpha_composite(bell(292, theme["metal"]), ((432 - 292) // 2, (432 - 292) // 2))
    fg.save("assets/ui/icon_foreground.png")
    dev_band(fg, 0.7, 0.5, 0.12).save("assets/ui/dev/icon_foreground.png")
    # Themed icons on newer Android: one flat shape.
    mono = np.zeros((432, 432, 4), dtype=np.uint8)
    mono[..., :3] = 255
    mono[..., 3] = np.asarray(fg)[..., 3]
    mono_im = Image.fromarray(mono, "RGBA")
    mono_im.save("assets/ui/icon_monochrome.png")
    dev_band(mono_im, 0.7, 0.5, 0.12, mono=True).save("assets/ui/dev/icon_monochrome.png")
    plain = theme["backdrop"](512, 512, False).convert("RGBA")
    if theme.get("crowned"):
        plain.alpha_composite(crowned_bell(500, theme["metal"]), (6, 4))
    else:
        plain.alpha_composite(bell(480, theme["metal"]), (16, 2))
    rounded(plain, 96).save("icon.png")
    rounded(dev_band(plain, 0.74, 0.62, 0.15), 96).save("assets/ui/dev/icon.png")


# The splash belongs to Beyond the Mists: twilight over the mountains past the Mists, not the village night.
DUSK_TOP = np.array([0.075, 0.05, 0.165])
DUSK_MID = np.array([0.34, 0.2, 0.46])
DUSK_LOW = np.array([0.96, 0.58, 0.38])
VIOLET = (168, 128, 255)


def _ridge(w, h, rng, base, tall, sharp=True):
    """One mountain line across the picture, as polygon points closed along the bottom."""
    f1, f2 = rng.uniform(1.1, 2.0), rng.uniform(3.2, 5.6)
    p1, p2 = rng.uniform(0, 6.3), rng.uniform(0, 6.3)
    pts = []
    for i in range(241):
        u = i / 240.0
        v = np.sin(u * np.pi * f1 + p1) * 0.6 + np.sin(u * np.pi * f2 + p2) * 0.28 + rng.uniform(-0.03, 0.03)
        if sharp:
            v = abs(v) * 1.4 - 0.2
        pts.append((u * w, (base - v * tall) * h))
    return pts + [(w, h), (0, h)]


def twilight(w, h, seed=11):
    """The endless twilight of the lands beyond the Mists: violet above, peach on the horizon, three
    ranges of peaks fading into it, rock shards floating with a glint of mist light, and a low mist."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    v = (yy / h)[..., None]
    up = np.clip(v / 0.4, 0, 1)
    down = np.clip((v - 0.4) / 0.22, 0, 1)
    rgb = DUSK_TOP * (1 - up) + DUSK_MID * up
    rgb = rgb * (1 - down) + DUSK_LOW * down
    # Where the sun has gone down: a warm glow low on the right.
    sun = np.exp(-((xx / w - 0.72) * w / h / 0.42) ** 2 - ((yy / h - 0.62) / 0.2) ** 2)[..., None]
    rgb = rgb + sun * np.array([0.22, 0.12, 0.04])
    im = Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255 + 0.5)).convert("RGBA")
    draw = ImageDraw.Draw(im)
    for _ in range(int(w * h / 4200)):
        x, y = rng.uniform(0, w), rng.uniform(0, h * 0.42)
        r = rng.uniform(0.35, 1.0) * h / 700
        a = int(rng.uniform(90, 220) * (1 - y / (h * 0.45)))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(235, 225, 255, a))
    # Floating shards of rock, high and far, each with a cyan glint underneath.
    shards = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shards)
    for cx, cy, s in ((0.13, 0.2, 0.05), (0.31, 0.11, 0.028), (0.87, 0.14, 0.04), (0.66, 0.08, 0.022), (0.95, 0.33, 0.026)):
        x, y, r = cx * w, cy * h, s * h
        top = [(x - r * 1.2, y), (x - r * 0.5, y - r * 0.35), (x + r * 0.6, y - r * 0.3), (x + r * 1.25, y + r * 0.05)]
        tip = (x + r * 0.1, y + r * 1.9)
        sd.polygon(top + [tip], fill=(52, 38, 76, 255))
        sd.polygon([(x - r * 1.2, y), (x - r * 0.5, y - r * 0.35), (x + r * 0.6, y - r * 0.3), (x + r * 1.25, y + r * 0.05), (x + r * 0.1, y + r * 0.35)], fill=(92, 72, 118, 255))
        sd.ellipse((tip[0] - r * 0.22, tip[1] - r * 0.22, tip[0] + r * 0.22, tip[1] + r * 0.22), fill=(120, 245, 235, 255))
    lights = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for cx, cy, s in ((0.13, 0.2, 0.05), (0.31, 0.11, 0.028), (0.87, 0.14, 0.04), (0.66, 0.08, 0.022), (0.95, 0.33, 0.026)):
        x, y, r = cx * w, (cy + s * 1.9) * h, s * h * 0.9
        ImageDraw.Draw(lights).ellipse((x + s * h * 0.1 - r, y - r, x + s * h * 0.1 + r, y + r), fill=(110, 240, 230, 120))
    im.alpha_composite(lights.filter(ImageFilter.GaussianBlur(h * 0.02)))
    im.alpha_composite(shards)
    # Three ranges, the far one pale with the horizon's light on its snow.
    for k, (base, tall, tone) in enumerate(((0.6, 0.2, (122, 82, 128)), (0.7, 0.16, (70, 48, 92)), (0.8, 0.12, (38, 27, 56)))):
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(_ridge(w, h, rng, base, tall), fill=tone + (255,))
        if k == 0:
            # Snow on the far peaks: the ridge shifted down a little, cut out of a pale copy.
            snow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            ImageDraw.Draw(snow).polygon(_ridge(w, h, np.random.default_rng(seed + 100), base - 0.035, tall * 0.9), fill=(246, 214, 206, 150))
            mask = np.minimum(np.asarray(layer)[..., 3], 255 - np.asarray(snow.filter(ImageFilter.GaussianBlur(2)))[..., 3])
            cap = np.asarray(layer).copy()
            cap[..., :3] = (236, 196, 196)
            cap[..., 3] = (mask * (np.clip(1.0 - (yy / h - (base - tall * 1.1)) / (tall * 0.6), 0, 1))).astype(np.uint8) // 2
            im.alpha_composite(layer)
            im.alpha_composite(Image.fromarray(cap, "RGBA"))
        else:
            im.alpha_composite(layer)
        # Mist lying in each valley.
        mist = np.exp(-((yy / h - (base + 0.03)) / 0.03) ** 2) * (0.35 - 0.08 * k)
        haze = np.zeros((h, w, 4), dtype=np.uint8)
        haze[..., :3] = (205, 170, 230)
        haze[..., 3] = np.uint8(np.clip(mist, 0, 1) * 255)
        im.alpha_composite(Image.fromarray(haze, "RGBA"))
    # Tall firs close by, darkest of all, a little taller towards the edges.
    near = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    nd = ImageDraw.Draw(near)
    for base, tone, scale in ((0.86, (26, 18, 40), 0.15), (0.94, (13, 9, 22), 0.2)):
        x = -0.05 * w
        pts = [(0, h)]
        while x < w * 1.05:
            edge = 0.55 + 0.9 * abs(x / w - 0.5)
            th = rng.uniform(0.55, 1.0) * scale * h * edge
            tw = th * 0.36
            y = base * h + rng.uniform(-0.006, 0.006) * h
            pts += [(x - tw * 0.5, y), (x - tw * 0.18, y - th * 0.45), (x - tw * 0.28, y - th * 0.45), (x, y - th), (x + tw * 0.28, y - th * 0.45), (x + tw * 0.18, y - th * 0.45), (x + tw * 0.5, y)]
            x += tw * rng.uniform(0.6, 1.0)
        pts.append((w, h))
        nd.polygon(pts, fill=tone + (255,))
    im.alpha_composite(near)
    return im


def splash(edition=EDITION):
    w, h = 1280, 720
    theme = THEMES[edition]
    im = theme["backdrop"](w, h, False).convert("RGBA") if "title" in theme else twilight(w, h)
    mark = Image.open("assets/ui/wordmark.png").convert("RGBA")
    scale = 860.0 / mark.width
    mark = mark.resize((860, int(mark.height * scale)), Image.LANCZOS)
    top = int(h * 0.36 - mark.height * 0.62)
    im.alpha_composite(mark, ((w - mark.width) // 2, top))
    # The update's name under it, in the violet of the lands beyond the Mists.
    font = ImageFont.truetype("assets/fonts/Cinzel-Bold.ttf", 46)
    text = theme.get("title", "Beyond the Mists")
    ink = theme.get("title_ink", (214, 198, 255))
    glow = tuple(int(c * 0.75) for c in ink) if "title" in theme else VIOLET
    box = ImageDraw.Draw(im).textbbox((0, 0), text, font=font)
    at = ((w - (box[2] - box[0])) // 2 - box[0], top + mark.height - 6)
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shade).text(at, text, font=font, fill=(18, 10, 34, 210))
    im.alpha_composite(shade.filter(ImageFilter.GaussianBlur(5)))
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).text(at, text, font=font, fill=glow + (150,))
    im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(9)))
    ImageDraw.Draw(im).text(at, text, font=font, fill=ink)
    im.convert("RGB").save("assets/ui/splash.png")


if __name__ == "__main__":
    icons(sys.argv[1] if len(sys.argv) > 1 else EDITION)
    splash(sys.argv[1] if len(sys.argv) > 1 else EDITION)
    print("launcher icons and splash done")
