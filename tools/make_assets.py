#!/usr/bin/env python3
"""Generates the ground tile. Everything else has its own tool: make_audio.py for sounds and
music, make_icons.py, make_ui.py and make_launcher.py for art.
Everything made here is original and free to use. Run from the project root."""
import numpy as np
from PIL import Image

rng = np.random.default_rng(7)


def ground_tile():
    s = 128
    base = np.zeros((s, s))
    for f, a in ((4, .5), (8, .3), (16, .2)):
        g = rng.normal(0, 1, (f, f))
        # Wrapped resize keeps the tile seamless.
        wrap = Image.fromarray(np.uint8(np.pad((g - g.min()) / (g.max() - g.min()) * 255, 1, mode="wrap")))
        up = wrap.resize((s + 2 * s // f, s + 2 * s // f), Image.BICUBIC)
        base += a * (np.asarray(up, float)[s // f:s // f + s, s // f:s // f + s] / 255)
    v = 0.84 + 0.16 * (base - base.min()) / (base.max() - base.min())
    Image.fromarray(np.uint8(np.stack([v] * 3, -1) * 255)).save("assets/sprites/ground_tile.png")


def glow():
    """A soft white disc. Tinted by whatever uses it, so glows add light instead of black."""
    s = 128
    y, x = np.mgrid[0:s, 0:s]
    r = np.sqrt((x - s / 2 + 0.5) ** 2 + (y - s / 2 + 0.5) ** 2) / (s / 2)
    im = np.zeros((s, s, 4), np.uint8)
    im[..., :3] = 255
    im[..., 3] = (np.clip(1 - r, 0, 1) ** 1.6 * 255).astype(np.uint8)
    Image.fromarray(im).save("assets/sprites/glow.png")


if __name__ == "__main__":
    ground_tile()
    glow()
