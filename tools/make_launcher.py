#!/usr/bin/env python3
"""Draws the launcher icon (plain, adaptive and themed) and the boot splash. All original.
The picture is the village bell in front of the moon, lit from below by a fire you cannot see.
The splash uses the wordmark, so run tools/make_ui.py first if that changed.
Run from the project root."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

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


def bell(size):
    """Dark metal, warmer towards the lip where the fire reaches it, with a thin line of moonlight."""
    mask, top, height = bell_mask(size)
    n = size * SS
    m = np.asarray(mask, dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n]
    v = np.clip((yy - top) / height, -0.3, 1.25)
    u = (xx - n / 2) / (height * 0.56)
    dark = np.array([0.070, 0.088, 0.125])
    warm = np.array([0.74, 0.40, 0.12])
    hot = np.array([0.98, 0.70, 0.30])
    heat = np.clip((v - 0.42) / 0.62, 0, 1) ** 1.6
    # The light comes from below and in front, so it fades towards the edges of the round metal.
    heat = heat * np.clip(1.08 - np.abs(u) ** 2.2 * 0.75, 0, 1)
    rgb = dark[None, None] * (1 - heat[..., None]) + warm[None, None] * heat[..., None]
    rgb = rgb + (hot - warm)[None, None] * (np.clip((v - 0.92) / 0.2, 0, 1) * np.clip(1.0 - np.abs(u) * 0.8, 0, 1))[..., None]
    # Moonlight just inside the outline, strongest on the upper part.
    blur = np.asarray(mask.filter(ImageFilter.GaussianBlur(height * 0.012)), dtype=float) / 255.0
    rim = np.clip((1.0 - blur) * m * 2.2, 0, 1) * np.clip(1.0 - v * 0.6, 0.25, 1)
    rgb = rgb * (1 - rim[..., None] * 0.75) + np.array([0.86, 0.80, 0.66])[None, None] * rim[..., None] * 0.75
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


def icons():
    # Adaptive icons crop to the middle two thirds, so the bell and the moon stay inside that.
    sky(432, 432, (0.5, 0.455), 0.235).save("assets/ui/icon_background.png")
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    b = bell(292)
    fg.alpha_composite(b, ((432 - 292) // 2, (432 - 292) // 2))
    fg.save("assets/ui/icon_foreground.png")
    # Themed icons on newer Android: one flat shape.
    mono = np.zeros((432, 432, 4), dtype=np.uint8)
    mono[..., :3] = 255
    mono[..., 3] = np.asarray(fg)[..., 3]
    Image.fromarray(mono, "RGBA").save("assets/ui/icon_monochrome.png")
    plain = sky(512, 512, (0.5, 0.44), 0.325).convert("RGBA")
    plain.alpha_composite(bell(480), (16, 2))
    rounded(plain, 96).save("icon.png")


def splash():
    w, h = 1280, 720
    im = sky(w, h, (0.76, 0.24), 0.15).convert("RGBA")
    mark = Image.open("assets/ui/wordmark.png").convert("RGBA")
    scale = 880.0 / mark.width
    mark = mark.resize((880, int(mark.height * scale)), Image.LANCZOS)
    im.alpha_composite(mark, ((w - mark.width) // 2, int(h * 0.5 - mark.height * 0.62)))
    im.convert("RGB").save("assets/ui/splash.png")


if __name__ == "__main__":
    icons()
    splash()
    print("launcher icons and splash done")
