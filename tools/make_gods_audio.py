#!/usr/bin/env python3
"""Sounds for the Archipelagos of the Forgotten Gods: Fontanova, its mutants, its cult and its god.
Made from synthesis with the helpers of tools/make_beyond_audio.py and tools/make_sunken_audio.py,
and original. Run from the project root:
    python3 tools/make_gods_audio.py          (all of them)
    ONLY=dawn_fontanova python3 tools/make_gods_audio.py
Each sound here is listed in Sfx.NAMES."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_beyond_audio import (SR, n, t_, env, bell_env, noise, band, lowp, highp, sweep_filter, glide, reverb,
                               metal, glass, save, thud, curve, throat, growl)
from make_sunken_audio import at, water

rng = np.random.default_rng(271)
SOUNDS = {}


def reed(f, m, vibrato=5.0, depth=0.012):
    """A shepherd's pipe: a buzzy reed tone with a little breath and vibrato."""
    tt = t_(m)
    phase = 2 * np.pi * np.cumsum(f * (1 + depth * np.sin(2 * np.pi * vibrato * tt))) / SR
    tone = sum(np.sin(phase * h) * a for h, a in ((1, 1.0), (2, 0.55), (3, 0.42), (4, 0.2), (5, 0.12)))
    return lowp(tone, 3200) * 0.3 + band(noise(m), 1500, 4500) * 0.03


def pipe_phrase(notes, total):
    """A run of pipe notes, each (start, frequency, length), in a silence `total` seconds long."""
    x = np.zeros(n(total))
    for start, f, length in notes:
        k = n(length)
        x += at(reed(f, k) * env(k, 0.04, 1.8), start, total)
    return x


def cicadas(m, rise=1.0):
    """Cicadas in the olives: a dry high buzz pulsing in waves."""
    tt = t_(m)
    buzz = band(noise(m), 4200, 7600) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * tt) ** 2)
    swell = np.clip(tt / max(rise, 1e-3), 0, 1) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.45 * tt))
    return buzz * swell * 0.12


def goat_bells(total, count=6):
    """Small bells on a flock somewhere on the hillside: thin clanks, never in time."""
    x = np.zeros(n(total))
    for _ in range(count):
        f = rng.uniform(1300, 2100)
        clank = metal(f, 18, 0.25) * bell_env(n(0.25), 6.0) * rng.uniform(0.06, 0.14)
        x += at(clank, rng.uniform(0.2, total - 0.4), total)
    return x


def dawn_fontanova():
    """Morning over the island: the cicadas waking, a shepherd's pipe somewhere in the olives, goat bells
    far off, and the sea quiet on the beach."""
    total = 5.0
    m = n(total)
    x = cicadas(m, rise=2.0)
    # E, F, G#, A: the island's old mode, turning up into the light.
    x += pipe_phrase(((0.3, 659, 0.5), (0.85, 698, 0.35), (1.25, 831, 0.5), (1.8, 880, 1.4), (3.3, 988, 0.45), (3.8, 880, 1.0)), total)
    x += goat_bells(total)
    x += band(noise(m), 150, 700) * 0.06 * (1 + 0.6 * np.sin(2 * np.pi * 0.22 * t_(m)))
    return reverb(x, 1.6, 0.3)


SOUNDS.update({"dawn_fontanova": (dawn_fontanova, 0.7)})


if __name__ == "__main__":
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    for name, (make, gain) in SOUNDS.items():
        if only and name not in only:
            continue
        save(name, make(), gain)
        print("made", name)
