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


# --- The drowned court (stage 3) ------------------------------------------------------------------

SOPRANO = ((800, 0.2, 1.0), (1150, 0.18, 0.6), (2900, 0.12, 0.35), (3900, 0.1, 0.15))


def sung(m, notes, vib=5.5, depth=0.012):
    """A wordless high voice through notes [(share of the sound, Hz)...], gliding between them, with
    vibrato, breath, and no roughness at all."""
    pitch = curve(m, *notes) * (1 + depth * np.sin(2 * np.pi * vib * t_(m)))
    return throat(m, pitch, SOPRANO, breath=0.18, rough=0.0, sub=0.0)


def siren_song():
    """A Siren's song (and her breath before it): a drawn breath through water, then a slow wordless
    melody, sweet and wrong, sung in two voices a sixth apart, with the sea under it. 4.3 s: the
    breath for the 0.8 s tell, and 3.5 s of song."""
    total = 4.3
    br = n(0.75)
    breath = band(noise(br), 600, 4000) * np.linspace(0.0, 1.0, br) ** 2 * 0.35
    x = at(breath, 0.0, total)
    m = n(3.5)
    melody = ((0, 587), (0.12, 587), (0.22, 698), (0.38, 659), (0.5, 659), (0.62, 523), (0.78, 554), (1.0, 440))
    voice = sung(m, melody) * env(m, 0.25, 1.0)
    voice *= np.minimum(1.0, (1 - t_(m) / 3.5) * 4.0)
    second = sung(m, [(p, f * 0.6) for p, f in melody], 5.0, 0.015) * env(m, 0.35, 1.0) * 0.45
    second *= np.minimum(1.0, (1 - t_(m) / 3.5) * 4.0)
    x += at(voice + second, 0.8, total)
    x += water(n(total), 200, 900, 20) * 0.08
    return reverb(x, 2.4, 0.5, 4500)


def siren_hum():
    """A Siren somewhere near: a few low hummed notes over the water."""
    m = n(2.0)
    v = sung(m, ((0, 392), (0.4, 440), (0.7, 349), (1, 330)), 4.5, 0.01) * env(m, 0.3, 1.2) * 0.6
    return reverb(lowp(v, 3000) + water(m, 200, 800, 10) * 0.1, 2.0, 0.5)


def siren_shriek():
    """A Siren's song broken off, or a Siren struck: a shriek that cracks and drops."""
    m = n(0.7)
    v = throat(m, curve(m, (0, 1100), (0.3, 1350), (1, 520)), SOPRANO, breath=0.5, rough=0.8, sub=0.1) * env(m, 0.01, 3)
    return reverb(v + highp(noise(m), 3000) * env(m, 0.01, 6) * 0.2, 0.9, 0.3)


def siren_death():
    """A Siren dying: a long falling wail that sinks into bubbles."""
    m = n(1.8)
    v = throat(m, curve(m, (0, 900), (0.3, 1000), (1, 260)), SOPRANO, breath=0.4, rough=0.3, sub=0.0) * env(m, 0.03, 1.4)
    return reverb(v + bubbles(m, 40, 250, 900, 0.07) * 0.5, 1.5, 0.4)


def press_shout():
    """A Press Gang man: a hoarse drowned bark, "haul!", through water in the throat."""
    m = n(0.7)
    v = throat(m, curve(m, (0, 150), (0.3, 175), (1, 120)), ((600, 0.3, 1.0), (1100, 0.25, 0.6), (2400, 0.2, 0.2)), breath=0.5, rough=0.9, sub=0.2) * env(m, 0.02, 2.5)
    return v + bubbles(m, 8, 300, 800, 0.05) * 0.3


def net_throw():
    """A weighted net flung: a broad whoosh of rope, and the weights clacking."""
    m = n(0.6)
    x = sweep_filter(noise(m), 500, 1600, 0.6) * bell_env(m, 1.6) * 0.8
    for i in range(6):
        x += at(band(noise(n(0.02)), 1500, 4000) * 0.3, 0.05 + i * 0.07, 0.6)
    return x


def net_land():
    """The net coming down: a soft slap of wet rope and lead weights thumping round you."""
    m = n(0.6)
    x = band(noise(m), 300, 1800) * env(m, 0.003, 7) * 0.8
    for i in range(8):
        x += at(thud(n(0.12), 0.0, 0.25, 160 + i * 9), rng.uniform(0.0, 0.08), 0.6)
    return x + water(m, 400, 2500, 10) * env(m, 0.01, 6) * 0.4


def witch_call():
    """A Tide Witch calling the sea: a crone's rising chant and the water answering with a swell."""
    m = n(1.4)
    v = throat(m, curve(m, (0, 220), (0.5, 330), (1, 260)), ((700, 0.3, 1.0), (1200, 0.25, 0.7), (2600, 0.2, 0.25)), breath=0.6, rough=0.5, sub=0.1) * env(m, 0.1, 1.5) * 0.7
    swell = band(noise(m), 150, 900) * np.sin(np.pi * t_(m) / 1.4) ** 2 * 0.6
    return reverb(v + swell, 1.4, 0.35)


def witch_death():
    """A Tide Witch dying: a hissing curse, and the sea she called pouring off her."""
    m = n(1.4)
    v = throat(m, curve(m, (0, 300), (1, 120)), ((700, 0.3, 1.0), (1200, 0.25, 0.7)), breath=0.8, rough=0.7, sub=0.1) * env(m, 0.02, 2)
    return v + water(m, 300, 3000, 40) * env(m, 0.05, 2) * 0.6


def chain_rattle():
    """The Harbourmaster swinging his hook round: a chain running out and whirring."""
    m = n(0.6)
    x = chain(m, 12, 2200) * 0.8
    whirr = band(noise(m), 600, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t_(m))) * bell_env(m, 1.0) * 0.4
    return x + whirr


def hook_throw():
    """The hook flung on its chain: a heavy whoosh and the chain paying out fast behind it."""
    m = n(0.7)
    x = sweep_filter(noise(m), 400, 1500, 0.5) * bell_env(m, 2.0)
    return x + chain(m, 16, 2600) * np.linspace(1, 0.3, m) * 0.6


def harbour_bell_ring():
    """The Harbourmaster's handbell, rung hard: a bright clanging, over and over."""
    m = n(2.0)
    x = np.zeros(m)
    for i in range(6):
        x += at(metal(880 + (i % 2) * 40, 3.0, 0.5) * env(n(0.5), 0.001, 3.0) * 0.6, i * 0.28, 2.0)
    return reverb(x, 1.2, 0.3)


def harbour_growl():
    """The Harbourmaster: a deep, drowned old man's growl."""
    m = n(1.0)
    v = throat(m, curve(m, (0, 85), (0.5, 95), (1, 70)), ((450, 0.3, 1.0), (900, 0.25, 0.6), (2000, 0.2, 0.2)), breath=0.4, rough=1.0, sub=0.6) * env(m, 0.03, 2)
    return v + bubbles(m, 12, 200, 600, 0.06) * 0.3


def lamp_throw():
    """An oil lamp thrown: a whoosh, its flame fluttering, oil sloshing."""
    m = n(0.6)
    x = sweep_filter(noise(m), 700, 2200, 0.5) * bell_env(m, 1.8) * 0.6
    flutter = band(noise(m), 300, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t_(m))) * env(m, 0.05, 2) * 0.4
    return x + flutter


def lamp_smash():
    """An oil lamp bursting: glass breaking and the oil going up in a roar of flame."""
    m = n(1.2)
    x = np.zeros(m)
    for i in range(10):
        x += at(glass(rng.uniform(2500, 6000), 0.35, 12.0) * rng.uniform(0.2, 0.5), rng.uniform(0.0, 0.05), 1.2)
    roar = band(noise(m), 150, 1400) * env(m, 0.04, 2.2) * 0.9
    crackle = np.zeros(m)
    for _ in range(40):
        k = n(0.006)
        s = rng.integers(0, m - k)
        crackle[s:s + k] += highp(noise(k), 2500) * rng.uniform(0.2, 0.6)
    return x + roar + crackle * np.exp(-t_(m) * 1.5) * 0.6 + thud(m, 0.0, 0.4, 120)


def lamp_flare():
    """The great lamp lifted: a rising hum and roar of the flame as it is turned up and up."""
    m = n(1.3)
    t = t_(m)
    rise = (np.sin(2 * np.pi * np.cumsum(curve(m, (0, 110), (1, 330))) / SR) * 0.3 + band(noise(m), 300, 2500) * 0.6) * (t / 1.3) ** 2
    return reverb(rise, 1.0, 0.3)


def lamp_blaze():
    """The lamp blazing: a bright, hard flash of sound, like a sheet of fire going up."""
    m = n(1.0)
    x = band(noise(m), 800, 7000) * env(m, 0.002, 5) * 1.1 + glide(2400, 800, m) * np.exp(-t_(m) * 7) * 0.3
    return reverb(x + thud(m, 0.0, 0.6, 90), 1.2, 0.35)


def keeper_laugh():
    """The Mad Lighthouse Keeper: a cracked old man's cackle, too long, too loud."""
    m = n(1.8)
    x = np.zeros(m)
    for i in range(7):
        k = n(0.16)
        f = 260 + i * 12 + rng.uniform(-20, 20)
        h = throat(k, curve(k, (0, f * 1.2), (1, f)), ((700, 0.3, 1.0), (1300, 0.25, 0.7), (2700, 0.2, 0.3)), breath=0.7, rough=0.6, sub=0.0) * env(k, 0.01, 2.5)
        x += at(h, i * 0.2, 1.8)
    return reverb(x, 1.3, 0.35)


def keeper_hurt():
    """The Keeper struck, or falling: a shriek of outrage that breaks into a wheeze."""
    m = n(0.9)
    v = throat(m, curve(m, (0, 420), (0.3, 520), (1, 190)), ((700, 0.3, 1.0), (1300, 0.25, 0.7)), breath=0.7, rough=0.8, sub=0.0) * env(m, 0.01, 2.5)
    return v


def kraken_rise():
    """The Kraken's arm rising out of the sea: a great rush and pour of water, and a deep groan below."""
    m = n(1.8)
    t = t_(m)
    rush = band(noise(m), 120, 1800) * np.sin(np.pi * np.clip(t / 1.8, 0, 1)) ** 1.2 * 0.9
    pour = water(m, 300, 3500, 60) * np.clip(t / 0.6, 0, 1) * 0.6
    groan = throat(m, curve(m, (0, 45), (1, 38)), ((180, 0.4, 1.0), (420, 0.3, 0.5)), breath=0.3, rough=1.0, sub=0.8) * env(m, 0.3, 1.0) * 0.6
    return reverb(rush + pour + groan, 1.6, 0.35)


def kraken_slam():
    """An arm coming down: a heavy wet slap that throws water everywhere."""
    m = n(1.2)
    slap = band(noise(m), 200, 3000) * env(m, 0.002, 9) * 1.2
    return slap + thud(m, 0.0, 1.3, 55) + water(m, 300, 3500, 50) * env(m, 0.02, 2.5) * 0.7


def kraken_hurt():
    """An arm struck: a deep, bubbling bellow from under the water."""
    m = n(0.8)
    v = throat(m, curve(m, (0, 70), (1, 50)), ((200, 0.4, 1.0), (500, 0.3, 0.5)), breath=0.4, rough=1.0, sub=0.8) * env(m, 0.02, 2.5)
    return lowp(v, 1500) + bubbles(m, 20, 150, 500, 0.08) * 0.5


def kraken_death():
    """An arm dying: it thrashes, a long bellow sinks away, and the sea closes over it."""
    m = n(2.6)
    v = throat(m, curve(m, (0, 80), (1, 30)), ((200, 0.4, 1.0), (500, 0.3, 0.5)), breath=0.4, rough=1.0, sub=0.8) * env(m, 0.05, 1.2)
    return reverb(lowp(v, 1500) + water(m, 200, 2500, 60) * env(m, 0.4, 1.0) * 0.6 + thud(m, 0.4, 1.0, 50), 1.8, 0.35)


def wave_rise():
    """A wave being called up: water gathering and rising."""
    m = n(1.0)
    t = t_(m)
    return band(noise(m), 200, 1500) * (t / 1.0) ** 1.5 * 0.6 + water(m, 400, 2000, 10) * 0.2


def wave_crash():
    """A wave breaking over you: the crash, and the foam hissing out."""
    m = n(1.4)
    crash = band(noise(m), 150, 3000) * env(m, 0.01, 3.5) * 1.1
    hiss = highp(noise(m), 2500) * env(m, 0.05, 1.8) * 0.4
    return crash + hiss + thud(m, 0.0, 0.8, 80)


def crown_toll():
    """The Sunken Crown's judgement coming: one deep bell tolled under the water."""
    m = n(2.4)
    return reverb(lowp(harbour_bell(98, 2.4), 1500) + bubbles(m, 20, 150, 500, 0.08) * 0.3, 2.2, 0.5)


def crown_fall():
    """The judgement falling: a crash of water and a ringing of gold."""
    m = n(1.6)
    x = band(noise(m), 200, 3000) * env(m, 0.002, 5) + thud(m, 0.0, 1.2, 60)
    for f in (1318, 1568, 1976):
        x += metal(f, 3.0, 1.6) * env(m, 0.002, 2.5) * 0.15
    return reverb(x, 1.6, 0.35)


def crown_take():
    """The Sunken Crown taken up: a gold chime, low and wrong, and water running off it."""
    m = n(1.6)
    x = np.zeros(m)
    for i, f in enumerate((392, 466, 587, 698)):
        x += at(metal(f, 2.0, 1.2) * env(n(1.2), 0.002, 2.5) * 0.25, i * 0.12, 1.6)
    return reverb(x + water(m, 400, 3000, 20) * env(m, 0.05, 3) * 0.3, 1.8, 0.4)


SOVEREIGN = ((300, 0.35, 1.0), (750, 0.3, 0.55), (2200, 0.2, 0.15))


def sovereign_voice():
    """The Hollow Sovereign: a vast, hollow voice from inside an empty hood, a chord of drowned voices."""
    m = n(2.6)
    v = np.zeros(m)
    for k, f in enumerate((55, 82, 110)):
        v += throat(m, curve(m, (0, f), (0.6, f * 1.05), (1, f * 0.9)), SOVEREIGN, breath=0.5, rough=0.6, sub=0.4) * (0.6 if k else 1.0)
    v *= env(m, 0.3, 1.0)
    return reverb(lowp(v, 2400) + bubbles(m, 30, 150, 500, 0.08) * 0.3, 2.6, 0.55)


def sovereign_decree():
    """His decree: the voice raised in one great word, and the sea answering with a roar."""
    m = n(2.4)
    v = np.zeros(m)
    for f in (65, 98, 130):
        v += throat(m, curve(m, (0, f * 0.9), (0.2, f * 1.15), (1, f)), SOVEREIGN, breath=0.5, rough=0.7, sub=0.4)
    v *= env(m, 0.1, 1.2) * 0.7
    roar = band(noise(m), 120, 1600) * np.sin(np.pi * np.clip(t_(m) / 2.4, 0, 1)) * 0.8
    return reverb(v + roar, 2.4, 0.5)


def sovereign_hurt():
    """The Sovereign struck: a hollow grunt, as if from far down a well."""
    m = n(0.8)
    v = throat(m, curve(m, (0, 75), (1, 60)), SOVEREIGN, breath=0.4, rough=0.8, sub=0.5) * env(m, 0.01, 3)
    return reverb(lowp(v, 1800), 1.2, 0.45)


def sovereign_death():
    """The Sovereign falling: the voices inside the hood cry out and fall away to nothing, the robe
    collapses, and something golden rolls on the ground."""
    m = n(3.2)
    v = np.zeros(m)
    for f in (70, 104, 140, 210):
        v += throat(m, curve(m, (0, f), (1, f * 0.4)), SOVEREIGN, breath=0.6, rough=0.6, sub=0.3) * 0.5
    v *= env(m, 0.05, 1.0)
    roll = np.zeros(m)
    for i in range(6):
        roll += at(metal(1568 - i * 40, 3.0, 0.3) * env(n(0.3), 0.001, 4) * (0.3 - i * 0.04), 2.0 + i * 0.12, 3.2)
    return reverb(lowp(v, 2200) + roll + thud(m, 1.4, 0.8, 70), 2.4, 0.45)


SOUNDS.update({
    "siren_song": (siren_song, 0.75), "siren_hum": (siren_hum, 0.5), "siren_shriek": (siren_shriek, 0.75), "siren_death": (siren_death, 0.75),
    "press_shout": (press_shout, 0.7), "net_throw": (net_throw, 0.7), "net_land": (net_land, 0.75),
    "witch_call": (witch_call, 0.7), "witch_death": (witch_death, 0.75),
    "chain_rattle": (chain_rattle, 0.65), "hook_throw": (hook_throw, 0.75), "harbour_bell": (harbour_bell_ring, 0.7), "harbour_growl": (harbour_growl, 0.75),
    "lamp_throw": (lamp_throw, 0.65), "lamp_smash": (lamp_smash, 0.8), "lamp_flare": (lamp_flare, 0.7), "lamp_blaze": (lamp_blaze, 0.85),
    "keeper_laugh": (keeper_laugh, 0.75), "keeper_hurt": (keeper_hurt, 0.75),
    "kraken_rise": (kraken_rise, 0.85), "kraken_slam": (kraken_slam, 0.9), "kraken_hurt": (kraken_hurt, 0.8), "kraken_death": (kraken_death, 0.85),
    "wave_rise": (wave_rise, 0.6), "wave_crash": (wave_crash, 0.85),
    "crown_toll": (crown_toll, 0.8), "crown_fall": (crown_fall, 0.85), "crown_take": (crown_take, 0.75),
    "sovereign_voice": (sovereign_voice, 0.85), "sovereign_decree": (sovereign_decree, 0.9), "sovereign_hurt": (sovereign_hurt, 0.8), "sovereign_death": (sovereign_death, 0.9),
})


# --- Last Light ---------------------------------------------------------------------------------
LEVIATHAN = ((160, 0.45, 1.0), (380, 0.35, 0.6), (900, 0.25, 0.25))


def leviathan_rise():
    """The Leviathan surfacing: the sea heaving up and pouring off a vast body, and a groan under it all."""
    m = n(2.8)
    t = t_(m)
    heave = band(noise(m), 60, 900) * np.sin(np.pi * np.clip(t / 2.2, 0, 1)) ** 1.5 * 1.0
    pour = water(m, 250, 3200, 90) * np.clip((t - 0.6) / 0.8, 0, 1) * env(m, 0.8, 0.9) * 0.7
    groan = throat(m, curve(m, (0, 34), (0.5, 42), (1, 30)), LEVIATHAN, breath=0.3, rough=1.0, sub=1.0) * env(m, 0.5, 1.0) * 0.7
    return reverb(heave + pour + groan, 2.4, 0.45)


def leviathan_roar():
    """The Leviathan's roar: a huge, rough bellow that shakes the water, with a sea-wind hiss over it."""
    m = n(2.6)
    v = np.zeros(m)
    for f in (40, 61, 93):
        v += throat(m, curve(m, (0, f * 0.8), (0.25, f * 1.2), (1, f * 0.85)), LEVIATHAN, breath=0.5, rough=1.0, sub=0.9) * 0.6
    v *= env(m, 0.15, 1.1)
    hiss = band(noise(m), 1500, 6000) * env(m, 0.2, 1.5) * 0.25
    return reverb(lowp(v, 2600) + hiss, 2.6, 0.45)


def leviathan_bite():
    """The jaws coming down: a rush of air, a crunching snap of teeth as long as oars, and a wave thrown up."""
    m = n(1.5)
    rush = band(noise(m), 200, 1800) * curve(m, (0, 0.2), (0.25, 1.0), (0.3, 0.1), (1, 0.0)) * 0.7
    snap = band(noise(m), 600, 5000) * at(env(n(0.2), 0.001, 12), 0.38, 1.5) * 1.4
    crash = band(noise(m), 120, 2500) * at(env(n(1.1), 0.01, 3), 0.4, 1.5) * 0.9
    return rush + snap + crash + thud(m, 0.38, 1.4, 45)


def leviathan_hurt():
    """The Leviathan struck: a deep, angry bellow through the water."""
    m = n(1.1)
    v = throat(m, curve(m, (0, 60), (0.3, 72), (1, 44)), LEVIATHAN, breath=0.4, rough=1.0, sub=0.9) * env(m, 0.03, 2.2)
    return reverb(lowp(v, 1800) + bubbles(m, 25, 120, 450, 0.09) * 0.4, 1.4, 0.4)


def leviathan_death():
    """The Leviathan dying: a long falling cry, the great body crashing into the sea, and the water
    closing over it, settling, still."""
    m = n(4.6)
    v = np.zeros(m)
    for f in (56, 84, 126):
        v += throat(m, curve(m, (0, f * 1.1), (1, f * 0.35)), LEVIATHAN, breath=0.5, rough=0.9, sub=0.8) * 0.55
    v *= env(m, 0.1, 0.8) * curve(m, (0, 1), (0.6, 0.8), (1, 0))
    crash = band(noise(m), 80, 2500) * at(env(n(2.8), 0.01, 1.6), 1.8, 4.6) * 1.1
    settle = water(m, 200, 2400, 80) * curve(m, (0, 0), (0.45, 0), (0.6, 0.7), (1, 0)) * 0.5
    return reverb(lowp(v, 2200) + crash + settle + thud(m, 1.8, 1.5, 38), 2.8, 0.45)


def waystation():
    """Reaching a waystation: the barge bumping the jetty, a ship's bell rung twice, and a brazier catching."""
    m = n(2.4)
    bump = thud(m, 0.0, 0.7, 90) + band(noise(m), 200, 1200) * env(m, 0.005, 10) * 0.5
    bell = at(harbour_bell(523, 1.6), 0.35, 2.4) * 0.45 + at(harbour_bell(523, 1.6), 0.85, 2.4) * 0.4
    fire = band(noise(m), 300, 4000) * curve(m, (0, 0), (0.45, 0), (0.55, 0.5), (1, 0.15))
    for _ in range(30):
        c = band(noise(n(0.01)), 2000, 7000) * rng.uniform(0.1, 0.3)
        s = rng.integers(n(1.0), m - n(0.01))
        fire[s:s + len(c)] += c
    return reverb(bump + bell + fire * 0.5, 1.6, 0.35)


def lighthouse_lit():
    """The lighthouse lit: a roar of flame climbing the tower, the lens ringing, and bells across the sea."""
    m = n(4.0)
    t = t_(m)
    roar = band(noise(m), 150, 3500) * np.clip(t / 1.2, 0, 1) * env(m, 0.4, 0.8) * 0.8
    lens = np.zeros(m)
    for i, f in enumerate((587, 880, 1175, 1480)):
        lens += at(glass(f, 2.6) * 0.18, 0.9 + i * 0.18, 4.0)
    bells = sum(at(harbour_bell(f, 2.5), 1.4 + k * 0.5, 4.0) * 0.3 for k, f in enumerate((294, 370, 440)))
    return reverb(roar + lens + bells, 2.6, 0.45)


SOUNDS.update({
    "leviathan_rise": (leviathan_rise, 0.95), "leviathan_roar": (leviathan_roar, 0.95), "leviathan_bite": (leviathan_bite, 0.9),
    "leviathan_hurt": (leviathan_hurt, 0.8), "leviathan_death": (leviathan_death, 0.95),
    "waystation": (waystation, 0.75), "lighthouse_lit": (lighthouse_lit, 0.85),
})


# --- The classes of the coast: the Harpooner ----------------------------------------------------

def haul_throw():
    """Haul: a weighted hook whirled once and flung, its line hissing out after it."""
    m = n(0.55)
    whirl = sweep_filter(noise(m), 500, 2200, 0.45) * bell_env(m, 1.8) * 0.7
    whirl *= 1 + 0.6 * np.sin(2 * np.pi * 9 * t_(m))
    line = band(noise(m), 2000, 5200) * np.clip(t_(m) / 0.55, 0, 1) * np.linspace(1.0, 0.2, m) * 0.3
    return whirl + line + chain(m, 4, 2400) * 0.2


def blood_water():
    """Blood in the Water: a great heartbeat, a wash of surf, and a growl rising behind it."""
    m = n(1.4)
    x = thud(m, 0.0, 1.0, 55) * 0.9 + thud(m, 0.32, 0.8, 50) * 0.7
    surf = band(noise(m), 200, 2400) * np.sin(np.pi * np.clip(t_(m) / 1.4, 0, 1)) ** 1.4 * 0.45
    growl = throat(m, curve(m, (0, 80), (1, 120)), ((300, 0.4, 1.0), (800, 0.3, 0.5)), breath=0.5, rough=1.0, sub=0.4) * env(m, 0.3, 1.8) * 0.3
    return reverb(x + surf + growl, 1.0, 0.3)


def rig_line():
    """Rig a Line: a stake knocked in, rope paid out and hauled taut with a twang."""
    m = n(0.9)
    knock = thud(m, 0.0, 0.8, 140) + band(noise(m), 300, 1500) * env(m, 0.002, 14) * 0.5
    pay = at(band(noise(n(0.35)), 1500, 4500) * bell_env(n(0.35), 1.2) * 0.35, 0.12, 0.9)
    tt = t_(n(0.4))
    twang = np.sin(2 * np.pi * 180 * tt + 3 * np.sin(2 * np.pi * 6 * tt)) * np.exp(-tt * 8) * 0.35
    return knock + pay + at(twang, 0.5, 0.9)


def line_trip():
    """Something caught by the ankles on a line: the rope snapping taut and a body going down."""
    m = n(0.6)
    tt = t_(m)
    twang = np.sin(2 * np.pi * 150 * tt) * np.exp(-tt * 12) * 0.4
    fall = thud(m, 0.12, 0.9, 70) + band(noise(m), 150, 900) * at(env(n(0.3), 0.005, 8), 0.12, 0.6) * 0.5
    return twang + fall


def great_harpoon():
    """The Great Harpoon thrown: a grunt of effort, a heavy iron hurled, and a long line roaring out."""
    m = n(1.0)
    heave = band(noise(m), 120, 700) * env(m, 0.02, 7) * 0.6
    whoosh = sweep_filter(noise(m), 250, 1300, 0.6) * bell_env(m, 1.2)
    line = band(noise(m), 1800, 5000) * np.clip((t_(m) - 0.1) / 0.3, 0, 1) * np.linspace(1.0, 0.0, m) ** 1.2 * 0.4
    line *= 1 + 0.5 * np.sin(2 * np.pi * 30 * t_(m))
    return heave + whoosh + line


SOUNDS.update({
    "haul_throw": (haul_throw, 0.7), "blood_water": (blood_water, 0.8), "rig_line": (rig_line, 0.7),
    "line_trip": (line_trip, 0.7), "great_harpoon": (great_harpoon, 0.85),
})


# --- The Tidecaller ------------------------------------------------------------------------------

def call_tide():
    """Call the Tide: a breath drawn in, then the sea answering: a wave gathering and rolling away."""
    m = n(1.5)
    tt = t_(m)
    draw = band(noise(m), 600, 3000) * np.clip(tt / 0.3, 0, 1) * np.clip((0.4 - tt) / 0.1, 0, 1) * 0.3
    roll = band(noise(m), 120, 1800) * np.clip((tt - 0.25) / 0.3, 0, 1) * np.exp(-np.clip(tt - 0.6, 0, 9) * 2.4) * 0.9
    hiss = band(noise(m), 2500, 7000) * np.clip((tt - 0.35) / 0.2, 0, 1) * np.exp(-np.clip(tt - 0.5, 0, 9) * 3) * 0.3
    return reverb(draw + roll + hiss + thud(m, 0.3, 0.6, 60), 1.0, 0.3)


def tsunami():
    """A Tsunami: the same call, but the whole sea stands up and comes down like a cliff falling."""
    m = n(2.6)
    tt = t_(m)
    swell = band(noise(m), 60, 1200) * np.clip(tt / 0.8, 0, 1) ** 1.5 * np.exp(-np.clip(tt - 1.0, 0, 9) * 1.6)
    crash = band(noise(m), 150, 5000) * at(env(n(1.6), 0.01, 2.2), 0.9, 2.6) * 0.9
    return reverb(swell + crash + thud(m, 0.9, 1.4, 42), 2.0, 0.4)


def deep_song():
    """Deep Song: a wordless chord of low voices under the water, swelling and slowly beating."""
    m = n(3.0)
    tt = t_(m)
    v = np.zeros(m)
    for f, w in ((110, 1.0), (165, 0.7), (220, 0.5), (277, 0.35)):
        vib = 1 + 0.006 * np.sin(2 * np.pi * 4.6 * tt + f)
        v += (np.sin(2 * np.pi * f * tt * vib) + 0.3 * np.sin(4 * np.pi * f * tt * vib)) * w
    v *= np.sin(np.pi * np.clip(tt / 3.0, 0, 1)) ** 0.8 * 0.18
    return reverb(lowp(v, 1800) + bubbles(m, 30, 160, 520, 0.05) * 0.3, 2.2, 0.5)


def bind_fog():
    """Bind the Fog: a cold breath, and fog rolling in thick with a low moan inside it."""
    m = n(1.8)
    tt = t_(m)
    breath = band(noise(m), 400, 2600) * np.sin(np.pi * np.clip(tt / 1.8, 0, 1)) ** 1.2 * 0.6
    moan = np.sin(2 * np.pi * curve(m, (0, 140), (1, 110)).cumsum() / SR) * np.sin(np.pi * np.clip(tt / 1.8, 0, 1)) * 0.12
    return reverb(breath + moan, 1.8, 0.5)


SOUNDS.update({
    "call_tide": (call_tide, 0.8), "tsunami": (tsunami, 0.9), "deep_song": (deep_song, 0.7), "bind_fog": (bind_fog, 0.7),
})


# --- The Ferryman ---------------------------------------------------------------------------------

def crossing():
    """Crossing: one long pull of an oar through still water, the skiff hissing over it, a lantern's creak."""
    m = n(1.0)
    tt = t_(m)
    pull = band(noise(m), 200, 1400) * np.sin(np.pi * np.clip(tt / 0.6, 0, 1)) ** 1.5 * 0.7
    glide = band(noise(m), 1800, 5200) * np.sin(np.pi * np.clip(tt / 1.0, 0, 1)) * 0.25
    creak = np.sin(2 * np.pi * curve(m, (0, 420), (0.5, 380), (1, 400)).cumsum() / SR) * at(env(n(0.25), 0.02, 9), 0.55, 1.0) * 0.12
    return reverb(pull + glide + creak + bubbles(m, 12, 300, 900, 0.05) * 0.4, 1.4, 0.4)


def toll_bell():
    """Demand the Toll: a single cracked iron bell, struck once, long and low."""
    return reverb(harbour_bell(196, 3.0) * 0.8, 2.4, 0.45)


def obol():
    """An obol paid: a small silver coin dropped and ringing on stone."""
    m = n(0.7)
    v = np.zeros(m)
    for k, (dt, g) in enumerate(((0.0, 1.0), (0.09, 0.6), (0.15, 0.4), (0.19, 0.25))):
        v += at(glass(2400 + k * 70, 0.4) * g * 0.25, dt, 0.7)
    return v


def souls_go():
    """Guide the Souls: a breath of many whispering voices rising and rushing away."""
    m = n(1.4)
    tt = t_(m)
    v = np.zeros(m)
    for f in (420, 530, 660, 790):
        v += np.sin(2 * np.pi * curve(m, (0, f), (1, f * 1.6)).cumsum() / SR) * 0.05
    whoosh = sweep_filter(noise(m), 600, 3400, 0.6) * bell_env(m, 1.2) * 0.6
    return reverb((v + whoosh) * np.sin(np.pi * np.clip(tt / 1.4, 0, 1)), 1.8, 0.45)


SOUNDS.update({"crossing": (crossing, 0.8), "toll_bell": (toll_bell, 0.8), "obol": (obol, 0.6), "souls_go": (souls_go, 0.75)})


# --- Stage 6: Class Upgrades of the Adept, the Cartographer and the Bandit; the Trappers' Guild -----

def mirror_shatter():
    """Shattered Mirror: a pane of glass bursting, bright shards ringing as they fly."""
    m = n(0.9)
    crack = highp(noise(m), 2500) * env(m, 0.001, 18.0) * 0.7
    v = np.zeros(m)
    for k in range(9):
        f = rng.uniform(2600, 5200)
        v += at(glass(f, 0.5, 7.0) * rng.uniform(0.08, 0.2), rng.uniform(0.0, 0.25), 0.9)
    return reverb(crack + v, 1.0, 0.3)


def encore():
    """Encore: the blade ringing out wide, with a low swell under it as everything is thrown down."""
    m = n(0.9)
    tt = t_(m)
    whoosh = sweep_filter(noise(m), 400, 3000, 0.35) * bell_env(m, 1.4) * 0.6
    ring = metal(1650, 9, 0.9) * env(m, 0.05, 3.5) * 0.12
    swell = np.sin(2 * np.pi * curve(m, (0, 90), (1, 60)).cumsum() / SR) * np.sin(np.pi * np.clip(tt / 0.9, 0, 1)) * 0.25
    return reverb(whoosh + ring + swell, 1.2, 0.35)


def rift_open():
    """Event Horizon: a deep tearing hum as the rift opens and starts to draw everything in."""
    m = n(1.6)
    tt = t_(m)
    hum = sum(np.sin(2 * np.pi * curve(m, (0, f), (1, f * 0.8)).cumsum() / SR) * a for f, a in ((55, 0.35), (82, 0.2), (110, 0.1)))
    tear = sweep_filter(noise(m), 3000, 300, 0.7) * env(m, 0.01, 2.2) * 0.5
    suck = sweep_filter(noise(m), 200, 1600, 0.5) * np.clip(tt / 1.6, 0, 1) * 0.25
    return reverb((hum * np.sin(np.pi * np.clip(tt / 1.6, 0, 1)) + tear + suck), 1.8, 0.45)


def rift_collapse():
    """The horizon falls in on itself: a sharp inward rush, then a heavy, muffled boom."""
    m = n(1.2)
    rush = sweep_filter(noise(m), 4000, 200, 0.2) * at(env(n(0.25), 0.2, 1.0), 0.0, 1.2) * 0.6
    boom = thud(m, 0.22, 1.2, 70)
    return reverb(rush + boom, 1.5, 0.4)


def coin_flip():
    """Lucky Fingers: a coin thumbed into the air, spinning, and caught."""
    m = n(0.6)
    flick = at(metal(3600, 60, 0.05) * 0.4, 0.0, 0.6)
    spin = np.zeros(m)
    for k in range(7):
        spin += at(glass(2900 + k * 25, 0.12, 9.0) * 0.08 * (1 - k / 8), 0.04 + k * 0.045, 0.6)
    catch = at(band(noise(n(0.04)), 800, 3000) * env(n(0.04), 0.001, 30.0) * 0.5, 0.42, 0.6)
    return flick + spin + catch


def contract_seal():
    """Contract: a seal pressed into warm wax and a purse of coin shaken once, low and certain."""
    m = n(1.0)
    press = thud(m, 0.02, 0.6, 140) * 0.8
    v = np.zeros(m)
    for k in range(6):
        v += at(metal(rng.uniform(2400, 3400), 50, 0.12) * 0.07, 0.18 + k * 0.035 + rng.uniform(0, 0.015), 1.0)
    low = np.sin(2 * np.pi * 98 * t_(m)) * env(m, 0.02, 3.0) * 0.12
    return reverb(press + v + low, 1.2, 0.35)


def snare_snap():
    """A trapper's snare sprung: a sapling whipping up and the noose snapping tight."""
    m = n(0.5)
    whip = sweep_filter(noise(m), 500, 2600, 0.12) * env(m, 0.005, 9.0) * 0.6
    snap = at(band(noise(n(0.03)), 1200, 5000) * env(n(0.03), 0.001, 40.0), 0.08, 0.5)
    creak = np.sin(2 * np.pi * curve(m, (0, 300), (1, 240)).cumsum() / SR) * at(env(n(0.2), 0.02, 10), 0.1, 0.5) * 0.1
    return whip + snap + creak


def trapper_horn():
    """The Trappers' Guild arrives: a hunting horn of the Valleys, two long notes from the woods."""
    m = n(2.4)
    v = np.zeros(m)
    for start, f, d in ((0.0, 196, 0.9), (1.0, 262, 1.3)):
        k = n(d)
        tt = t_(k)
        note = sum(np.sin(2 * np.pi * f * h * tt) * a for h, a in ((1, 1), (2, 0.5), (3, 0.3), (4, 0.15)))
        note *= np.minimum(1, tt / 0.12) * np.exp(-np.maximum(0, tt - d * 0.6) * 4)
        v += at(lowp(note, 1800) * 0.25, start, 2.4)
    return reverb(v, 2.2, 0.5)


def cache_drop():
    """A hunters' cache set down: a pack thumped onto the ground, its straps and tins settling."""
    m = n(0.6)
    return thud(m, 0.02, 0.9, 120) + at(metal(1800, 45, 0.15) * 0.06, 0.08, 0.6) + at(band(noise(n(0.15)), 600, 2400) * env(n(0.15), 0.01, 12) * 0.2, 0.05, 0.6)


SOUNDS.update({"mirror_shatter": (mirror_shatter, 0.75), "encore": (encore, 0.75), "rift_open": (rift_open, 0.75), "rift_collapse": (rift_collapse, 0.8),
               "coin_flip": (coin_flip, 0.6), "contract_seal": (contract_seal, 0.7), "snare_snap": (snare_snap, 0.75), "trapper_horn": (trapper_horn, 0.7),
               "cache_drop": (cache_drop, 0.7)})


if __name__ == "__main__":
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    for name, (make, gain) in SOUNDS.items():
        if only and name not in only:
            continue
        save(name, make(), gain)
        print("made", name)
