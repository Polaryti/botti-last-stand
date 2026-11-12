#!/usr/bin/env python3
"""Draws the launcher icon (plain, adaptive and themed) and the boot splash. All original.
The picture is the village bell in front of the moon, lit from below by a fire you cannot see.
The splash is the twilight of the lands beyond the Mists under the wordmark, so run tools/make_ui.py
first if that changed.
Run from the project root."""
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


def splash():
    w, h = 1280, 720
    im = twilight(w, h)
    mark = Image.open("assets/ui/wordmark.png").convert("RGBA")
    scale = 860.0 / mark.width
    mark = mark.resize((860, int(mark.height * scale)), Image.LANCZOS)
    top = int(h * 0.36 - mark.height * 0.62)
    im.alpha_composite(mark, ((w - mark.width) // 2, top))
    # The update's name under it, in the violet of the lands beyond the Mists.
    font = ImageFont.truetype("assets/fonts/Cinzel-Bold.ttf", 46)
    text = "Beyond the Mists"
    box = ImageDraw.Draw(im).textbbox((0, 0), text, font=font)
    at = ((w - (box[2] - box[0])) // 2 - box[0], top + mark.height - 6)
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shade).text(at, text, font=font, fill=(18, 10, 34, 210))
    im.alpha_composite(shade.filter(ImageFilter.GaussianBlur(5)))
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).text(at, text, font=font, fill=VIOLET + (150,))
    im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(9)))
    ImageDraw.Draw(im).text(at, text, font=font, fill=(214, 198, 255))
    im.convert("RGB").save("assets/ui/splash.png")


if __name__ == "__main__":
    icons()
    splash()
    print("launcher icons and splash done")
