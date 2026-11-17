#!/usr/bin/env python3
"""Sounds for "The Sunken Crown" (0.23): the coast of Vael. Made from synthesis like
tools/make_beyond_audio.py (whose helpers it uses) and original. Run from the project root:
    python3 tools/make_sunken_audio.py          (all of them)
    ONLY=flare_shot,anchor_slam python3 tools/make_sunken_audio.py
Each sound here is listed in Sfx.NAMES."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_beyond_audio import (SR, n, t_, env, bell_env, noise, band, lowp, highp, sweep_filter, glide, reverb,
                               metal, glass, save, thud, curve, throat, growl)

rng = np.random.default_rng(231)


def at(x, secs, total):
    """x placed `secs` into a silence `total` seconds long."""
    out = np.zeros(n(total))
    s = n(secs)
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]
    return out


def water(m, lo=300, hi=2600, bubbles=40):
    """Moving water: filtered noise with little bubble pops through it."""
    x = band(noise(m), lo, hi) * 0.6
    for _ in range(bubbles):
        f = rng.uniform(500, 1500)
        b = glide(f, f * 1.9, n(0.03)) * env(n(0.03), 0.002, 2.0) * rng.uniform(0.1, 0.35)
        s = rng.integers(0, max(1, m - len(b)))
        x[s:s + len(b)] += b
    return x


def chain(m, links=10, f=2400):
    """A chain running: quick little metal clinks."""
    x = np.zeros(m)
    for i in range(links):
        c = metal(f * rng.uniform(0.8, 1.3), 40, 0.08) * env(n(0.08), 0.001, 3.0) * rng.uniform(0.3, 0.7)
        s = int(i / links * (m - len(c)) + rng.uniform(-0.01, 0.01) * SR)
        s = int(np.clip(s, 0, m - len(c)))
        x[s:s + len(c)] += c
    return x


# --- Weapons ------------------------------------------------------------------

def cutlass_swing():
    """A curved blade whipped through the air: a bright, quick whistle with a thin ring of steel."""
    m = n(0.32)
    x = sweep_filter(noise(m), 900, 3800, 0.4) * bell_env(m, 1.6)
    x += metal(3100, 30, 0.32) * env(m, 0.04, 4.0) * 0.08
    return x


def hook_swing():
    """A boarding hook flung out: a short whoosh and its chain rattling after it."""
    m = n(0.42)
    x = sweep_filter(noise(m), 600, 1800, 0.5) * bell_env(m, 2.0) * 0.8
    x += chain(m, 6, 2600) * 0.35
    return x


def hook_catch():
    """The hook biting and hauling: a thick iron knock, a creak of the haft and a drag."""
    m = n(0.5)
    x = metal(520, 18, 0.5) * env(m, 0.001, 5.0) * 0.8
    x += band(noise(m), 120, 600) * env(m, 0.002, 6.0) * 0.6
    drag = band(noise(n(0.3)), 200, 900) * bell_env(n(0.3), 1.2) * 0.5
    x += at(drag, 0.12, 0.5)
    creak = np.sin(2 * np.pi * np.cumsum(curve(n(0.2), (0, 260), (1, 180))) / SR) * bell_env(n(0.2), 1.0) * 0.18
    x += at(creak, 0.08, 0.5)
    return x


def harpoon_throw():
    """A harpoon leaving the hand: a heavy whoosh and its rope paying out behind it."""
    m = n(0.6)
    x = sweep_filter(noise(m), 400, 1500, 0.5) * bell_env(m, 1.4)
    rope = band(noise(m), 1500, 4500) * np.linspace(0.6, 0.0, m) ** 1.5 * 0.35
    rope *= 1 + 0.5 * np.sin(2 * np.pi * 38 * t_(m))
    return x + rope


def harpoon_hit():
    """The iron going in: a deep thunk and the shaft shuddering."""
    m = n(0.55)
    x = thud(m, 0.0, 1.0, 120)
    shudder = np.sin(2 * np.pi * 95 * t_(m)) * np.exp(-t_(m) * 7) * (1 + 0.6 * np.sin(2 * np.pi * 22 * t_(m))) * 0.5
    return x + shudder + band(noise(m), 1200, 3500) * env(m, 0.001, 18.0) * 0.4


def harpoon_reel():
    """Taking the harpoon back: rope gathered hand over hand, and the iron knocking the shaft."""
    m = n(0.5)
    x = np.zeros(m)
    for i in range(4):
        pull = band(noise(n(0.09)), 900, 3000) * bell_env(n(0.09), 1.5) * 0.5
        x += at(pull, i * 0.09, 0.5)
    x += at(metal(880, 25, 0.2) * env(n(0.2), 0.001, 4.0) * 0.4, 0.34, 0.5)
    return x


def flare_shot():
    """A flare pistol: a hollow, wide-bored pop and the hiss of the flare catching as it flies."""
    m = n(0.9)
    pop = (lowp(noise(n(0.12)), 900) * env(n(0.12), 0.0005, 5.0) + glide(160, 70, n(0.12)) * env(n(0.12), 0.001, 4.0) * 0.6)
    x = at(pop, 0.0, 0.9)
    hiss = highp(noise(n(0.8)), 2500) * np.linspace(1.0, 0.0, n(0.8)) ** 0.8 * 0.35
    hiss *= 1 + 0.4 * np.sin(2 * np.pi * 14 * t_(n(0.8)))
    x += at(hiss, 0.05, 0.9)
    return reverb(x, 0.6, 0.18)


def flare_burst():
    """A flare striking and flaring up: a soft thump, then a roaring, sputtering burn."""
    m = n(1.6)
    x = at(thud(n(0.3), 0.0, 0.6, 140), 0.0, 1.6)
    burn = band(noise(m), 300, 4000) * (1 - np.exp(-t_(m) * 8)) * np.exp(-t_(m) * 1.4) * 0.6
    burn *= 1 + 0.5 * np.sin(2 * np.pi * 9 * t_(m)) * np.sin(2 * np.pi * 3.3 * t_(m))
    crackle = np.zeros(m)
    for _ in range(40):
        c = band(noise(n(0.012)), 2000, 7000) * rng.uniform(0.2, 0.6)
        s = rng.integers(n(0.05), m - n(0.02))
        crackle[s:s + len(c)] += c
    return x + burn + crackle * np.exp(-t_(m) * 1.2)


def anchor_heave():
    """An anchor hauled up for a blow: iron chain grinding taut and a deep, slow whoosh."""
    m = n(0.7)
    x = chain(m, 12, 1800) * np.linspace(0.3, 1.0, m) * 0.5
    x += sweep_filter(noise(m), 200, 700, 0.5) * bell_env(m, 1.2) * 0.9
    return x


def anchor_slam():
    """The anchor driven into the ground: a huge, low impact, stones shifting, and the chain settling."""
    m = n(1.4)
    x = thud(m, 0.0, 1.6, 55)
    x += glide(70, 28, m) * np.exp(-t_(m) * 3) * 0.8
    rubble = band(noise(m), 200, 1500) * np.exp(-t_(m) * 4) * 0.5
    x += rubble
    x += at(chain(n(0.4), 6, 2000) * 0.3, 0.25, 1.4)
    return reverb(x, 0.9, 0.2, 1800)


def oar_sweep():
    """A ferryman's oar swept wide: a broad, deep whoosh with a breath of spray in it."""
    m = n(0.6)
    x = sweep_filter(noise(m), 250, 1100, 0.6) * bell_env(m, 1.3)
    x += water(m, 1500, 5000, 12) * bell_env(m, 2.0) * 0.25
    return x


SOUNDS = {
    "cutlass_swing": (cutlass_swing, 0.55), "hook_swing": (hook_swing, 0.55), "hook_catch": (hook_catch, 0.75),
    "harpoon_throw": (harpoon_throw, 0.65), "harpoon_hit": (harpoon_hit, 0.8), "harpoon_reel": (harpoon_reel, 0.6),
    "flare_shot": (flare_shot, 0.75), "flare_burst": (flare_burst, 0.7),
    "anchor_heave": (anchor_heave, 0.6), "anchor_slam": (anchor_slam, 0.9), "oar_sweep": (oar_sweep, 0.6),
}


# --- Port Vael and the Mist Tide -----------------------------------------------------------------

def bubbles(m, count, lo=300, hi=1100, size=0.05):
    """Air coming up through water: rising little blips."""
    x = np.zeros(m)
    for _ in range(count):
        f = rng.uniform(lo, hi)
        k = n(size * rng.uniform(0.6, 1.4))
        b = glide(f, f * 2.2, k) * env(k, 0.003, 2.5) * rng.uniform(0.2, 0.6)
        s = rng.integers(0, max(1, m - k))
        x[s:s + k] += b
    return x


def harbour_bell(f, sec=3.0):
    """A big bronze bell heard across the water: a deep strike, its hum, and the ring dying away."""
    k = n(sec)
    strike = metal(f, 1.2, sec, ((1, 1), (2.0, 0.6), (2.4, 0.45), (3.0, 0.3), (4.2, 0.2), (0.5, 0.5)))
    return (strike * env(k, 0.002, 1.2) + band(noise(k), f * 2, f * 6) * np.exp(-t_(k) * 40) * 0.3)


def tide_bell():
    """The harbour bells warning that the tide is turning: two slow tolls from far off, over the water."""
    m = n(5.0)
    x = at(harbour_bell(196, 3.5), 0.0, 5.0) + at(harbour_bell(147, 3.2), 1.6, 5.0) * 0.8
    x = lowp(x, 2800)
    x += water(m, 200, 1200, 30) * 0.12
    return reverb(x, 2.0, 0.45, 2200)


def tide_in():
    """The Mist Tide coming in: a long low surge of water swelling over the flats, a foghorn far out."""
    m = n(4.5)
    t = t_(m)
    surge = band(noise(m), 120, 900) * (np.sin(np.pi * np.clip(t / 4.5, 0, 1)) ** 1.5)
    surge *= 1 + 0.4 * np.sin(2 * np.pi * 0.7 * t)
    foam = highp(noise(m), 2500) * (np.sin(np.pi * np.clip(t / 4.5, 0, 1)) ** 3) * 0.35
    horn_k = n(3.2)
    horn = (glide(73, 70, horn_k) + 0.6 * glide(146, 140, horn_k) + 0.3 * glide(219, 210, horn_k)) * bell_env(horn_k, 1.2) * 0.5
    x = surge + foam + at(lowp(horn, 600), 0.6, 4.5)
    return reverb(x, 1.5, 0.35, 2000)


def tide_out():
    """The tide going out: water draining and sucking at the mud, trickles, and gulls over the flats."""
    m = n(4.0)
    t = t_(m)
    drain = band(noise(m), 200, 1400) * np.exp(-t * 0.5) * 0.7
    drain *= 1 + 0.5 * np.sin(2 * np.pi * 1.3 * t)
    trickle = bubbles(m, 50, 500, 1600, 0.04) * 0.7
    x = drain + trickle
    for k in range(3):
        g = n(0.45)
        gull = glide(1700, 1250, g) * bell_env(g, 1.3) * 0.25 + glide(3400, 2500, g) * bell_env(g, 1.3) * 0.08
        x += at(gull, 1.2 + k * 0.7, 4.0)
    return reverb(x, 1.2, 0.3)


def salvage():
    """A sea chest forced open: a wet creak of the lid, coins sliding, and water running out of it."""
    m = n(1.4)
    k = n(0.5)
    creak = np.sin(2 * np.pi * np.cumsum(curve(k, (0, 180), (0.5, 260), (1, 150))) / SR) * bell_env(k, 1.0) * 0.4
    creak *= 1 + 0.6 * np.sin(2 * np.pi * 37 * t_(k))
    x = at(band(creak, 150, 1800), 0.0, 1.4)
    for i in range(10):
        c = glass(rng.uniform(3200, 5200), 0.25, 18.0) * rng.uniform(0.15, 0.35)
        x += at(c, 0.45 + i * 0.04 + rng.uniform(0, 0.03), 1.4)
    x += at(water(n(0.8), 400, 2400, 25) * np.linspace(1, 0, n(0.8)) * 0.5, 0.5, 1.4)
    return x


def dawn_vael():
    """Morning over the harbour: the bells ringing out, gulls, and the sea quiet on the flats."""
    m = n(5.0)
    x = np.zeros(m)
    for i, f in enumerate((262, 330, 392, 523)):
        x += at(harbour_bell(f, 3.0) * 0.5, i * 0.45, 5.0)
    for k in range(4):
        g = n(0.5)
        gull = glide(1800, 1300, g) * bell_env(g, 1.2) * 0.2
        x += at(gull, 1.5 + k * 0.6 + rng.uniform(0, 0.2), 5.0)
    x += band(noise(m), 200, 900) * 0.08 * (1 + 0.5 * np.sin(2 * np.pi * 0.3 * t_(m)))
    return reverb(x, 1.8, 0.35)


DROWNED_FORMANTS = ((420, 0.4, 1.0), (900, 0.3, 0.55), (2100, 0.25, 0.2))


def drowned_moan():
    """A Drowned Sailor: a long moan through water in the lungs, bubbling."""
    m = n(1.5)
    voice = throat(m, curve(m, (0, 110), (0.4, 135), (1, 92)), DROWNED_FORMANTS, breath=0.4, rough=0.7, sub=0.3) * env(m, 0.2, 1.4)
    voice *= 1 + 0.35 * np.sin(2 * np.pi * 9 * t_(m))
    return lowp(voice, 2200) + bubbles(m, 25, 200, 700, 0.06) * 0.5


def drowned_hurt():
    """A Drowned Sailor struck: a choked grunt and a gout of water."""
    m = n(0.5)
    voice = throat(m, curve(m, (0, 160), (1, 105)), DROWNED_FORMANTS, breath=0.5, rough=0.9, sub=0.2) * env(m, 0.01, 4)
    return voice + water(m, 300, 2000, 8) * env(m, 0.01, 5) * 0.6


def drowned_death():
    """A Drowned Sailor falling: a long gurgling sigh and the splash of it going down."""
    m = n(1.4)
    voice = throat(m, curve(m, (0, 120), (1, 60)), DROWNED_FORMANTS, breath=0.6, rough=0.8, sub=0.4) * env(m, 0.05, 2)
    splash = at(water(n(0.7), 300, 3000, 30) * env(n(0.7), 0.005, 3) * 0.9, 0.6, 1.4)
    return voice + bubbles(m, 40, 200, 900, 0.07) * 0.5 + splash


def brute_hurt():
    """A Barnacle Brute struck: shell cracking, and a deep, wet grunt."""
    m = n(0.6)
    crack = band(noise(m), 1500, 6000) * np.exp(-t_(m) * 30) * 0.8
    for i in range(4):
        crack += at(band(noise(n(0.03)), 2000, 7000) * 0.4, 0.02 + i * 0.03, 0.6)
    voice = throat(m, curve(m, (0, 80), (1, 62)), DROWNED_FORMANTS, breath=0.3, rough=1.0, sub=0.6) * env(m, 0.02, 3) * 0.8
    return crack + voice


def brute_death():
    """A Barnacle Brute going down: its shell splitting, a groan, and the heavy fall."""
    m = n(1.8)
    voice = throat(m, curve(m, (0, 75), (1, 40)), DROWNED_FORMANTS, breath=0.4, rough=1.0, sub=0.7) * env(m, 0.05, 1.5)
    crack = np.zeros(m)
    for i in range(12):
        crack += at(band(noise(n(0.04)), 1800, 6500) * rng.uniform(0.3, 0.6), rng.uniform(0.0, 0.6), 1.8)
    return voice + crack + thud(m, 1.0, 1.6, 70)


def hound_snarl():
    """A Brine Hound: a wet, rattling snarl, and a hiss through the gills."""
    m = n(1.0)
    x = growl(m, 160, 120, 1.2) * env(m, 0.05, 1.5)
    x *= 1 + 0.6 * np.sin(2 * np.pi * 14 * t_(m))
    gills = band(noise(m), 2500, 6000) * bell_env(m, 1.5) * 0.3
    return x + gills + bubbles(m, 12, 400, 1000, 0.04) * 0.3


def hound_bite():
    """A Brine Hound's jaws: a snap of needle teeth and a wet tear."""
    m = n(0.45)
    snap = band(noise(m), 1500, 5000) * np.exp(-t_(m) * 45) * 1.2
    tear = band(noise(m), 400, 2000) * env(m, 0.03, 6) * 0.5
    return snap + tear + growl(m, 190, 140, 1.0) * env(m, 0.01, 6) * 0.4


def hound_death():
    """A Brine Hound dying: a high whine that drowns in a gurgle."""
    m = n(1.1)
    whine = throat(m, curve(m, (0, 600), (0.4, 520), (1, 220)), ((1200, 0.3, 1.0), (2600, 0.25, 0.5)), breath=0.4, rough=0.5, sub=0.1) * env(m, 0.02, 2)
    return whine * 0.7 + bubbles(m, 30, 250, 900, 0.06) * 0.6


def jelly_sting():
    """A Lantern Jelly stinging: a crackle of electricity through wet threads, and a hum rising."""
    m = n(0.9)
    t = t_(m)
    crackle = np.zeros(m)
    for _ in range(60):
        k = n(rng.uniform(0.002, 0.01))
        s = rng.integers(0, m - k)
        crackle[s:s + k] += highp(noise(k), 3000) * rng.uniform(0.3, 1.0)
    crackle *= np.exp(-t * 2.5)
    hum = (np.sin(2 * np.pi * 120 * t) + 0.5 * np.sin(2 * np.pi * 240 * t)) * bell_env(m, 1.5) * 0.3
    zap = glide(2400, 300, m) * np.exp(-t * 9) * 0.4
    return crackle + hum + zap


def jelly_hum():
    """A Lantern Jelly drifting near: a soft electric hum and the slosh of its bell."""
    m = n(1.6)
    t = t_(m)
    hum = (np.sin(2 * np.pi * 110 * t) + 0.4 * np.sin(2 * np.pi * 330 * t + 0.4)) * bell_env(m, 1.0) * 0.3
    hum *= 1 + 0.3 * np.sin(2 * np.pi * 3 * t)
    slosh = water(m, 300, 1200, 6) * bell_env(m, 1.0) * 0.3
    return hum + slosh


def jelly_burst():
    """A Lantern Jelly bursting: a wet pop, a last snap of its sting, and its lantern's glass breaking."""
    m = n(1.2)
    pop = lowp(noise(n(0.15)), 900) * env(n(0.15), 0.001, 6) * 1.2
    x = at(pop, 0.0, 1.2)
    x += at(jelly_sting()[:n(0.5)] * 0.7, 0.02, 1.2)
    for i in range(8):
        x += at(glass(rng.uniform(2800, 6000), 0.4, 14.0) * rng.uniform(0.2, 0.5), 0.05 + i * 0.02, 1.2)
    x += water(m, 400, 3000, 20) * env(m, 0.01, 3) * 0.5
    return x


def angler_rise():
    """An Angler bursting out of the sand: a spray of wet sand and a gaping, gurgling hiss."""
    m = n(1.0)
    spray = band(noise(m), 600, 5000) * env(m, 0.005, 3) * 0.9
    hiss = throat(m, curve(m, (0, 220), (1, 140)), ((700, 0.4, 1.0), (1800, 0.3, 0.6)), breath=0.9, rough=0.6, sub=0.2) * env(m, 0.08, 2) * 0.6
    return spray + hiss + thud(m, 0.0, 0.7, 120) + bubbles(m, 20, 300, 900, 0.05) * 0.4


def angler_bite():
    """An Angler's jaws closing: a great wet crunch of fangs."""
    m = n(0.6)
    crunch = band(noise(m), 800, 4500) * np.exp(-t_(m) * 18) * 1.1
    for i in range(5):
        crunch += at(band(noise(n(0.02)), 2000, 6000) * 0.5, 0.01 + i * 0.025, 0.6)
    return crunch + thud(m, 0.0, 0.9, 140) + growl(m, 110, 80, 1.2) * env(m, 0.01, 5) * 0.4


def angler_death():
    """An Angler dying: its lure going out with a fizz, and a long croaking gurgle."""
    m = n(1.5)
    croak = throat(m, curve(m, (0, 140), (1, 55)), ((500, 0.4, 1.0), (1200, 0.3, 0.6)), breath=0.5, rough=1.0, sub=0.5) * env(m, 0.05, 1.8)
    fizz = highp(noise(m), 3500) * np.exp(-t_(m) * 3) * 0.25
    return croak + fizz + bubbles(m, 35, 200, 800, 0.07) * 0.5


SOUNDS.update({
    "tide_bell": (tide_bell, 0.7), "tide_in": (tide_in, 0.75), "tide_out": (tide_out, 0.7), "salvage": (salvage, 0.7),
    "dawn_vael": (dawn_vael, 0.7),
    "drowned_moan": (drowned_moan, 0.6), "drowned_hurt": (drowned_hurt, 0.7), "drowned_death": (drowned_death, 0.7),
    "brute_hurt": (brute_hurt, 0.75), "brute_death": (brute_death, 0.85),
    "hound_snarl": (hound_snarl, 0.7), "hound_bite": (hound_bite, 0.75), "hound_death": (hound_death, 0.7),
    "jelly_sting": (jelly_sting, 0.75), "jelly_hum": (jelly_hum, 0.55), "jelly_burst": (jelly_burst, 0.8),
    "angler_rise": (angler_rise, 0.8), "angler_bite": (angler_bite, 0.85), "angler_death": (angler_death, 0.75),
})


if __name__ == "__main__":
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    for name, (make, gain) in SOUNDS.items():
        if only and name not in only:
            continue
        save(name, make(), gain)
        print("made", name)
