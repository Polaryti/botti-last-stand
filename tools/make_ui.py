#!/usr/bin/env python3
"""Generates the iron and parchment UI textures. All original. Run from the project root."""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import gaussian_filter, zoom

rng = np.random.default_rng(11)
OUT = "assets/ui/"

def fractal(h, w, base=4, octaves=5):
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        g = rng.normal(0, 1, (base * 2 ** o + 2, base * 2 ** o + 2))
        z = zoom(g, (h / (g.shape[0] - 1), w / (g.shape[1] - 1)), order=3)[:h, :w]
        out += amp * z
        amp *= 0.55
    out -= out.min()
    return out / max(out.max(), 1e-6)

def save(name, arr):
    Image.fromarray(np.uint8(np.clip(arr, 0, 1) * 255)).save(OUT + name + ".png")

def parchment(h, w):
    n = fractal(h, w)
    fibre = gaussian_filter(rng.normal(0, 1, (h, w)), (0.6, 3.0))
    fibre /= np.abs(fibre).max()
    c0 = np.array([0.56, 0.42, 0.25]); c1 = np.array([0.88, 0.76, 0.54])
    t = np.clip(0.2 + 0.85 * n + 0.08 * fibre, 0, 1)[..., None]
    rgb = c0 * (1 - t) + c1 * t
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) / (min(h, w) * 0.22)
    rgb *= (0.62 + 0.38 * np.clip(edge, 0, 1))[..., None]
    return rgb

def iron(h, w):
    n = fractal(h, w, base=8, octaves=4)
    brushed = gaussian_filter(rng.normal(0, 1, (h, w)), (0.5, 6.0))
    brushed /= np.abs(brushed).max()
    v = 0.17 + 0.09 * n + 0.025 * brushed
    return np.stack([v * 1.02, v * 1.03, v * 1.1], -1)

def bevel(rgb, m, w=3, strength=0.5):
    """Lights the top-left and darkens the bottom-right inside the mask."""
    g = gaussian_filter(m.astype(float), w * 0.6)
    dy, dx = np.gradient(g)
    light = (dx + dy) * -1
    light = np.clip(light * w * 2.4, -1, 1)
    return rgb * (1 + strength * light[..., None])

def rivets(rgb, alpha, pts, r=5):
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w]
    for cx, cy in pts:
        d = np.hypot(xx - cx, yy - cy) / r
        m = d < 1
        v = 0.42 + 0.45 * np.clip(1 - np.hypot(xx - cx + r * 0.3, yy - cy + r * 0.3) / r, 0, 1)
        rgb[m] = np.stack([v, v, v * 1.05], -1)[m] * 0.9

def framed(name, h, w, b, fill):
    """A nine-patch: iron band of width b around fill, or transparent if fill is None."""
    rgb = iron(h, w)
    alpha = np.ones((h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    band = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) < b
    if fill is not None:
        rgb[~band] = fill[~band]
    else:
        alpha[~band] = 0.0
    rgb = bevel(rgb, band, 3, 0.55)
    # A dark line where the iron meets the middle.
    inner = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    line = (inner >= b) & (inner < b + 3)
    rgb[line] *= 0.45
    s = b // 2
    rivets(rgb, alpha, [(s, s), (w - 1 - s, s), (s, h - 1 - s), (w - 1 - s, h - 1 - s)], max(3, b // 3))
    # Rounded corners.
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        m = (np.abs(xx - cx) < 4) & (np.abs(yy - cy) < 4) & (np.hypot(xx - cx, yy - cy) > 3.5) & ((xx < 3) | (xx > w - 4)) & ((yy < 3) | (yy > h - 4))
        alpha[m] = 0
    Image.fromarray(np.uint8(np.dstack([np.clip(rgb, 0, 1), alpha]) * 255), "RGBA").save(OUT + name + ".png")

framed("panel", 192, 192, 18, parchment(192, 192))
framed("frame", 96, 96, 10, None)
save("parchment", parchment(256, 256))

def button(name, c0, c1, b=8):
    h, w = 96, 192
    n = fractal(h, w, base=6, octaves=4)[..., None]
    fill = np.array(c0) * (1 - n) + np.array(c1) * n
    yy = np.linspace(1.12, 0.78, h)[:, None, None]
    framed(name, h, w, b, fill * yy)

button("btn_wax", (0.33, 0.06, 0.05), (0.62, 0.13, 0.09))
button("btn_wax_hover", (0.45, 0.09, 0.06), (0.78, 0.2, 0.12))
button("btn_wax_down", (0.24, 0.04, 0.03), (0.42, 0.08, 0.06))
button("btn_iron", (0.13, 0.13, 0.15), (0.28, 0.28, 0.31))
button("btn_iron_off", (0.09, 0.09, 0.1), (0.15, 0.15, 0.16))
button("btn_gold", (0.48, 0.32, 0.08), (0.84, 0.62, 0.2))

# Round pieces: medallion base (tinted in game), and the iron ring over it.
S = 256
yy, xx = np.mgrid[0:S, 0:S]
d = np.hypot(xx - S / 2 + 0.5, yy - S / 2 + 0.5) / (S / 2)
shade = np.clip(1.1 - np.hypot(xx - S * 0.38, yy - S * 0.34) / (S * 0.82), 0.45, 1.0)
n = fractal(S, S, base=6, octaves=4)
v = np.clip(shade * (0.82 + 0.18 * n), 0, 1)
disc = np.dstack([v, v, v, (d < 0.86).astype(float)])
Image.fromarray(np.uint8(disc * 255), "RGBA").resize((128, 128), Image.LANCZOS).save(OUT + "medal.png")
ring_rgb = iron(S, S)
ring = (d < 0.98) & (d > 0.80)
ang = np.arctan2(yy - S / 2, xx - S / 2)
light = np.cos(ang + 2.4) * np.where(d > 0.89, 1, -1)
ring_rgb = ring_rgb * (1 + 0.65 * light[..., None]) + 0.06
rim = (np.abs(d - 0.89) < 0.008)
ring_rgb[rim] *= 0.5
alpha = ring.astype(float)
for i in range(8):
    a = i / 8 * 2 * np.pi + np.pi / 8
    rivets(ring_rgb, alpha, [(S / 2 + S * 0.445 * np.cos(a), S / 2 + S * 0.445 * np.sin(a))], 6)
Image.fromarray(np.uint8(np.dstack([np.clip(ring_rgb, 0, 1), alpha]) * 255), "RGBA").resize((128, 128), Image.LANCZOS).save(OUT + "ring.png")
# Glass-dark disc for the HUD buttons.
dark = np.dstack([np.full((S, S), 0.05), np.full((S, S), 0.05), np.full((S, S), 0.07), (d < 0.86) * 0.62])
Image.fromarray(np.uint8(dark * 255), "RGBA").resize((128, 128), Image.LANCZOS).save(OUT + "glass.png")

# Dark painted vignette for menus.
h, w = 360, 640
yy, xx = np.mgrid[0:h, 0:w]
dv = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
a = np.clip((dv - 0.45) / 0.9, 0, 1) ** 1.3
Image.fromarray(np.uint8(np.dstack([np.zeros((h, w)), np.zeros((h, w)), np.zeros((h, w)), a * 0.9]) * 255), "RGBA").save(OUT + "vignette.png")
