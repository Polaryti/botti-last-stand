#!/usr/bin/env python3
"""Sounds for "Beyond the Mists" (0.22), made from synthesis like tools/make_audio.py and original.
Kept apart from make_audio.py so these can be remade alone. Run from the project root:
    python3 tools/make_beyond_audio.py
Each sound here is listed in Sfx.NAMES."""
import os, subprocess, tempfile, wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 22050
rng = np.random.default_rng(122)
SND = "assets/sounds/"


def n(s):
    return int(SR * s)


def t_(m):
    return np.arange(m) / SR


def env(m, a=0.005, p=3.0):
    t = np.linspace(0, 1, m)
    return np.minimum(1, t / max(a, 1e-4)) * (1 - t) ** p


def bell_env(m, p=1.0):
    return np.sin(np.linspace(0, np.pi, m)) ** p


def noise(m):
    return rng.normal(0, 0.33, m)


def band(x, lo, hi, order=2):
    return sosfilt(butter(order, [max(lo, 20) / (SR / 2), min(hi, SR / 2 - 200) / (SR / 2)], btype="band", output="sos"), x)


def lowp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 - 200) / (SR / 2), output="sos"), x)


def highp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x)


def sweep_filter(x, f0, f1, width=0.5, steps=24):
    """Band-pass whose centre glides, by crossfading short filtered blocks."""
    m = len(x); out = np.zeros(m)
    hop = m // steps; win = np.hanning(hop * 2)
    for i in range(steps):
        fc = f0 * (f1 / f0) ** (i / max(steps - 1, 1))
        s = max(0, i * hop - hop // 2); e = min(m, s + hop * 2)
        y = band(x[s:e], fc * (1 - width), fc * (1 + width))
        out[s:e] += y * win[:e - s]
    return out


def glide(f0, f1, m):
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f1, m)) / SR)


def reverb(x, secs=0.9, mix=0.25, damp=3000):
    m = n(secs)
    ir = noise(m) * np.exp(-np.linspace(0, 6, m))
    ir = lowp(ir, damp)
    wet = fftconvolve(x, ir)[:len(x) + m]
    dry = np.zeros(len(wet)); dry[:len(x)] = x
    wet = wet / (np.abs(wet).max() + 1e-6) * max(np.abs(x).max(), 1e-6)
    return dry * (1 - mix) + wet * mix


def metal(f, d, sec, ratios=((1, 1), (1.47, 0.7), (2.09, 0.55), (2.76, 0.4), (3.76, 0.3))):
    t = t_(n(sec))
    return sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d * r ** 0.5) for r, a in ratios)


def glass(f, sec, decay=5.0):
    """A struck glass ring: inharmonic partials that beat slowly against each other."""
    t = t_(n(sec))
    return sum(a * np.sin(2 * np.pi * f * r * t + p) * np.exp(-t * decay * r ** 0.4) for r, a, p in ((1, 1, 0), (1.004, 0.6, 1.1), (2.32, 0.45, 0.4), (4.25, 0.25, 2.0), (6.8, 0.12, 0.7)))


def write(path, x, gain=0.8, q=2, loop=False):
    x = np.asarray(x, float)
    x = x / (np.abs(x).max() + 1e-6) * gain
    if not loop:
        f = min(60, len(x) // 4)
        x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        w = os.path.join(d, "a.wav")
        with wave.open(w, "wb") as fh:
            fh.setnchannels(1); fh.setsampwidth(2); fh.setframerate(SR); fh.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-c:a", "libvorbis", "-q:a", str(q), "-map_metadata", "-1", path], check=True)


def save(name, x, gain=0.8):
    write(SND + name + ".ogg", x, gain)


# --- Weapons ------------------------------------------------------------------

def heavy_swing():
    """A long blade through the air: a slow, deep whoosh with a thin steel edge on top."""
    m = n(0.42)
    air = sweep_filter(noise(m), 260, 900, 0.6) * bell_env(m, 1.3)
    edge = highp(sweep_filter(noise(m), 2400, 4200, 0.25), 1800) * bell_env(m, 3.0) * 0.35
    return air + edge


def cleave():
    """The Battleaxe's third blow: a thick chop, a crunch, and the ground answering."""
    m = n(0.7)
    chop = glide(140, 46, m) * env(m, 0.002, 2.4) * 1.3
    crunch = band(noise(m), 300, 2600) * env(m, 0.001, 9) * 1.2
    ring = metal(520, 9, 0.7) * 0.18
    thud = lowp(noise(m), 180, 3) * env(m, 0.004, 2.0) * 2.2
    return reverb(chop + crunch + ring + thud, 0.8, 0.22)


def chakram_throw():
    """A ring of mist-glass leaving the hand: a whirring, rising spin."""
    m = n(0.5)
    t = t_(m)
    whirr = sweep_filter(noise(m), 700, 2600, 0.35) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t)) * bell_env(m, 1.2)
    sing = glide(1180, 1560, m) * env(m, 0.04, 1.6) * 0.22
    return whirr + sing


def chakram_hit():
    """The ring striking and ricocheting: a bright glass chime over a short knock."""
    m = n(0.6)
    knock = band(noise(m), 500, 3200) * env(m, 0.001, 10)
    return reverb(glass(1720, 0.6, 6.0) * 0.55 + knock, 0.5, 0.3)


if __name__ == "__main__":
    os.makedirs(SND, exist_ok=True)
    save("heavy_swing", heavy_swing(), 0.6)
    save("cleave", cleave(), 0.85)
    save("chakram_throw", chakram_throw(), 0.55)
    save("chakram_hit", chakram_hit(), 0.55)
    print("Beyond the Mists sounds written to", SND)
