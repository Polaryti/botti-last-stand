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


# --- Bandit -------------------------------------------------------------------

def vanish():
    """Into the Shadows: a breath drawn in, a soft falling hush and a muffled low swell."""
    m = n(0.8)
    breath = sweep_filter(noise(m), 2600, 500, 0.5) * env(m, 0.08, 1.6)
    hush = lowp(noise(m), 900) * bell_env(m, 1.0) * 0.6
    low = glide(220, 110, m) * env(m, 0.2, 1.4) * 0.35
    return reverb(breath + hush + low, 0.9, 0.35)


def steal():
    """A Thief's Steal: a quick blink of air, a snatch, and a little jingle of coins."""
    m = n(0.55)
    blink = sweep_filter(noise(m), 1200, 3800, 0.4) * env(m, 0.005, 6) * 0.9
    snatch = band(noise(m), 500, 2400) * np.exp(-t_(m) * 30) * 0.8
    coins = np.zeros(m)
    for start, f in ((0.12, 3100), (0.17, 3600), (0.23, 2900), (0.3, 4100)):
        k = n(0.2)
        p = n(start)
        q = min(k, m - p)
        coins[p:p + q] += metal(f, 30, 0.2)[:q] * 0.22
    return blink + snatch + coins


def nightfall():
    """Nightfall: a deep, falling swell like dusk arriving all at once, with a faint chime of stars."""
    m = n(1.6)
    swell = lowp(noise(m), 320, 3) * 3.0 * bell_env(m, 0.7)
    fall = glide(330, 98, m) * env(m, 0.3, 1.2) * 0.5 + glide(495, 147, m) * env(m, 0.3, 1.4) * 0.25
    stars = sum(glass(f, 1.6, 3.0) * a for f, a in ((2093, 0.06), (2637, 0.05), (3136, 0.04)))
    return reverb(swell + fall + stars, 1.4, 0.4)


def dagger_fan():
    """A Highwayman's Dagger Fan: several thin blades leaving the hand a hair apart."""
    m = n(0.5)
    out = np.zeros(m)
    for i in range(5):
        k = n(0.22)
        p = n(0.025 * i)
        out[p:p + k] += highp(sweep_filter(noise(k), 1600 + i * 180, 4200, 0.3), 1200) * bell_env(k, 2.0) * (0.9 - i * 0.08)
    return out


# --- Cartographer --------------------------------------------------------------

def beacon_plant():
    """A survey post driven into the ground: a wooden thunk, then a small two-note chime as its lamp lights."""
    m = n(0.9)
    thunk = lowp(noise(m), 260, 3) * env(m, 0.002, 14) * 2.0 + glide(160, 90, m) * env(m, 0.002, 10) * 0.8
    chime = np.zeros(m)
    for start, f in ((0.12, 1318.5), (0.24, 1975.5)):
        k = n(0.6)
        p = n(start)
        q = min(k, m - p)
        chime[p:p + q] += glass(f, 0.6, 5.0)[:q] * 0.32
    return reverb(thunk + chime, 0.8, 0.28)


def waygate():
    """Stepping through a Waygate: a rising rush of air folding into a soft, bright bloom."""
    m = n(0.9)
    rush = sweep_filter(noise(m), 300, 3200, 0.45) * bell_env(m, 1.1)
    bloom = (glide(392, 784, m) * 0.25 + glide(588, 1176, m) * 0.15) * env(m, 0.25, 1.6)
    return reverb(rush + bloom, 1.0, 0.35)


def starlight():
    """Starlight striking: a high, clear ping with a faint shimmer after it."""
    m = n(0.8)
    ping = glass(2637, 0.8, 7.0) * 0.6 + glass(3520, 0.8, 9.0) * 0.3
    shimmer = highp(noise(m), 5000) * env(m, 0.01, 6) * 0.12
    return reverb(ping + shimmer, 0.9, 0.35)


def falling_star():
    """A falling star: a descending whistle, a deep impact and a ring of glassy sparks."""
    m = n(1.6)
    whistle = np.zeros(m)
    k = n(0.55)
    whistle[:k] = glide(2400, 600, k) * np.linspace(0.2, 1.0, k) * 0.45
    hit = np.zeros(m)
    p = n(0.55)
    h = m - p
    hit[p:] = lowp(noise(h), 220, 3) * env(h, 0.002, 3.0) * 3.0 + band(noise(h), 400, 3000) * env(h, 0.001, 12) * 0.8
    sparks = np.zeros(m)
    for start, f in ((0.6, 2093), (0.66, 2794), (0.74, 3136)):
        q = n(start)
        sparks[q:] += glass(f, (m - q) / SR, 4.0)[:m - q] * 0.12
    return reverb(whistle + hit + sparks, 1.4, 0.35)


def unearth():
    """A Pathfinder's find: two scrapes of earth and a bright, rising sparkle."""
    m = n(1.0)
    dig = np.zeros(m)
    for start in (0.0, 0.18):
        k = n(0.16)
        p = n(start)
        dig[p:p + k] += band(noise(k), 600, 3000) * env(k, 0.01, 3) * 0.8
    sparkle = np.zeros(m)
    for i, f in enumerate((1568, 1976, 2349, 3136)):
        p = n(0.36 + i * 0.07)
        sparkle[p:] += glass(f, (m - p) / SR, 6.0)[:m - p] * 0.18
    return reverb(dig + sparkle, 0.9, 0.3)


def bolas_throw():
    """Bolas leaving the hand: cords whirling, a low wobbling hum."""
    m = n(0.55)
    t = t_(m)
    whirl = sweep_filter(noise(m), 500, 1400, 0.4) * (0.55 + 0.45 * np.sin(2 * np.pi * 14 * t)) * bell_env(m, 1.2)
    hum = np.sin(2 * np.pi * 110 * t + 3 * np.sin(2 * np.pi * 14 * t)) * env(m, 0.05, 2) * 0.2
    return whirl + hum


def bolas_wrap():
    """Bolas catching legs: a whip of cord, two stones knocking together."""
    m = n(0.45)
    whip = highp(sweep_filter(noise(m), 3000, 1200, 0.4), 800) * env(m, 0.002, 8) * 0.8
    knock = np.zeros(m)
    for start, f in ((0.06, 900), (0.12, 760)):
        k = n(0.12)
        p = n(start)
        knock[p:p + k] += (band(noise(k), f * 0.7, f * 1.6) * 0.8 + np.sin(2 * np.pi * f * t_(k)) * 0.3) * env(k, 0.001, 14)
    return whip + knock


# --- Creatures of Mesenlla -------------------------------------------------------------

def growl(m, f0, f1, rough=0.6):
    """A throat: a low saw-like voice gliding f0 to f1, roughened by fast flutter and noise."""
    t = t_(m)
    f = np.linspace(f0, f1, m) * (1 + 0.04 * np.sin(2 * np.pi * 23 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    voice = sum(np.sin(ph * k) / k for k in range(1, 9))
    buzz = band(noise(m), 150, 900) * rough
    return lowp(voice * (1 + 0.5 * np.sin(2 * np.pi * 31 * t)) + buzz, 1400)


def bear_roar():
    """A mountain bear: a deep, rising-then-falling roar with a rumble under it."""
    m = n(1.4)
    roar = growl(m, 90, 70, 0.8) * bell_env(m, 0.8)
    rumble = lowp(noise(m), 120, 3) * 2.0 * env(m, 0.1, 1.5)
    return reverb(roar + rumble, 0.9, 0.25)


def bear_maul():
    """Two paws coming down: a heavy whoosh into a thud and a short snarl."""
    m = n(0.7)
    whoosh = sweep_filter(noise(m), 900, 250, 0.6) * env(m, 0.08, 4) * 0.8
    thud = lowp(noise(m), 160, 3) * 2.4 * np.exp(-t_(m) * 14)
    snarl = growl(m, 140, 110, 1.0) * env(m, 0.02, 3) * 0.5
    return thud + whoosh + snarl


def eagle_cry():
    """A high, falling scream with a rasp in it."""
    m = n(0.9)
    t = t_(m)
    f = 2400 * np.exp(-t * 0.9) + 600 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 2)
    cry = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    rasp = band(noise(m), 2000, 5000) * 0.3
    return reverb((cry + rasp) * env(m, 0.03, 2.2), 0.8, 0.3)


def shapeshift():
    """A body changing shape: a stretched, wavering groan folding into a snap and a puff of mist."""
    m = n(1.2)
    t = t_(m)
    groan = growl(m, 70, 160, 0.5) * bell_env(m, 1.2) * (0.7 + 0.3 * np.sin(2 * np.pi * 5 * t))
    snap = np.zeros(m)
    p = n(0.85)
    snap[p:] = band(noise(m - p), 800, 4000) * np.exp(-t_(m - p) * 40)
    breath = sweep_filter(noise(m), 3000, 600, 0.5) * bell_env(m, 2) * 0.4
    return reverb(groan + snap + breath, 0.9, 0.3)


def quake_warning():
    """The ground about to give: a rising sub rumble and grinding stone."""
    m = n(1.0)
    rumble = lowp(noise(m), 90, 3) * 3.0 * np.linspace(0.3, 1.0, m) * env(m, 0.3, 0.4)
    grind = band(noise(m), 300, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * t_(m))) * 0.35 * np.linspace(0.2, 1.0, m)
    return rumble + grind


def earth_slam():
    """A fist of stone on the ground: a huge low thump, a crack and gravel falling."""
    m = n(1.3)
    thump = lowp(noise(m), 110, 3) * 3.5 * np.exp(-t_(m) * 5) + glide(70, 35, m) * env(m, 0.002, 3) * 0.9
    crack = band(noise(m), 1200, 6000) * np.exp(-t_(m) * 30) * 0.8
    gravel = np.zeros(m)
    for i in range(30):
        p = n(0.1 + rng.random() * 0.9)
        k = n(0.03)
        q = min(k, m - p)
        gravel[p:p + q] += band(noise(k), 1500, 5000)[:q] * env(k, 0.001, 6)[:q] * rng.random() * 0.4
    return reverb(thump + crack + gravel, 1.0, 0.25)


def mist_blink():
    """Mist folding away and opening somewhere else: a reversed swell into a soft, hollow pop."""
    m = n(0.7)
    swell = sweep_filter(noise(m), 400, 2600, 0.5) * np.linspace(0, 1, m) ** 2
    pop = np.zeros(m)
    p = n(0.5)
    pop[p:] = glide(500, 200, m - p) * env(m - p, 0.002, 6) * 0.6
    return reverb(swell * 0.7 + pop, 0.9, 0.4)


def storm_call():
    """A storm gathering: crackle and a rising electric whine."""
    m = n(1.1)
    t = t_(m)
    whine = (np.sin(2 * np.pi * np.cumsum(np.linspace(300, 1400, m)) / SR) * 0.25 + np.sign(np.sin(2 * np.pi * 50 * t)) * 0.05) * np.linspace(0.2, 1.0, m)
    crackle = np.zeros(m)
    for i in range(40):
        p = n(rng.random() * 1.05)
        k = n(0.008)
        q = min(k, m - p)
        crackle[p:p + q] += highp(noise(k), 3000)[:q] * rng.random()
    return reverb(whine + crackle * 0.6, 0.6, 0.25)


def fire_warning():
    """Breath drawn in through a furnace: a rising roar of air with embers ticking."""
    m = n(1.0)
    roar = sweep_filter(noise(m), 300, 1800, 0.6) * np.linspace(0.2, 1.0, m) * env(m, 0.3, 0.3)
    return roar


def fire_breath():
    """Fire coming down: a wide roar of flame and crackling."""
    m = n(1.3)
    roar = band(noise(m), 200, 2500) * env(m, 0.02, 1.4) * 1.2 + lowp(noise(m), 200, 2) * env(m, 0.02, 2) * 1.5
    crackle = np.zeros(m)
    for i in range(50):
        p = n(rng.random() * 1.2)
        k = n(0.01)
        q = min(k, m - p)
        crackle[p:p + q] += band(noise(k), 2000, 7000)[:q] * rng.random() * 0.8
    return roar + crackle


def wyvern_roar():
    """A wyvern: a long, screeching roar, harsher and higher than a bear's."""
    m = n(1.5)
    roar = growl(m, 220, 160, 1.2) * bell_env(m, 0.7)
    screech = band(noise(m), 1800, 4200) * bell_env(m, 1.5) * 0.4
    return reverb(roar + screech, 1.0, 0.3)


def boulder_throw():
    """A boulder heaved into the air: a grunt of stone and a heavy, tumbling whoosh."""
    m = n(1.0)
    heave = lowp(noise(m), 200, 3) * 2.0 * np.exp(-t_(m) * 8)
    whoosh = sweep_filter(noise(m), 600, 200, 0.6) * bell_env(m, 1.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t_(m)))
    return heave + whoosh


def boulder_impact():
    """A boulder landing: a deep crash and shattered stone."""
    m = n(1.2)
    crash = lowp(noise(m), 140, 3) * 3.5 * np.exp(-t_(m) * 4.5)
    shatter = band(noise(m), 800, 5000) * np.exp(-t_(m) * 12) * 1.0
    return reverb(crash + shatter, 1.0, 0.25)


def revenant_roar():
    """The Great Revenant Elemental: a huge grinding bellow with mist howling through stone."""
    m = n(2.2)
    t = t_(m)
    bellow = growl(m, 55, 42, 1.0) * bell_env(m, 0.6) * 1.2
    howl = (np.sin(2 * np.pi * np.cumsum(np.linspace(220, 330, m)) / SR) * 0.25 + np.sin(2 * np.pi * np.cumsum(np.linspace(330, 495, m)) / SR) * 0.15) * bell_env(m, 1.0)
    grind = band(noise(m), 200, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)) * 0.4 * bell_env(m, 1.0)
    return reverb(bellow + howl + grind, 1.6, 0.4)


def stone_grind():
    """Stone shifting against stone: a low, uneven grinding."""
    m = n(1.0)
    t = t_(m)
    grind = band(noise(m), 120, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t + np.sin(2 * np.pi * 2 * t))) * bell_env(m, 1.0)
    return grind * 1.5


def woods_chatter():
    """A Child of the Woods: quick, wooden clicks and a little whistled call, like birdsong played on twigs."""
    m = n(0.8)
    clicks = np.zeros(m)
    for i in range(7):
        p = n(0.05 + i * 0.06 + rng.random() * 0.02)
        k = n(0.02)
        clicks[p:p + k] += band(noise(k), 1500, 3500) * env(k, 0.001, 8) * 0.8
    whistle = np.zeros(m)
    p = n(0.45)
    k = m - p
    f = 1800 + 500 * np.sin(np.linspace(0, 3 * np.pi, k))
    whistle[p:] = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(k, 0.05, 1.5) * 0.35
    return reverb(clicks + whistle, 0.6, 0.25)


def mist_muster():
    """A Mist Soldier steps out of a waystone: mist rushing in, a rising chord of glassy chimes and a
    short call on a far-off horn."""
    m = n(1.6)
    t = t_(m)
    rush = sweep_filter(noise(m), 300, 2400, 0.6) * bell_env(m, 0.8) * 0.9
    chimes = np.zeros(m)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        p = n(0.08 + i * 0.09)
        k = m - p
        tt = t_(k)
        chimes[p:] += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2.76 * tt)) * np.exp(-tt * 3.0) * 0.22
    horn = np.zeros(m)
    p = n(0.55)
    k = n(0.8)
    tt = t_(k)
    f = 196.0 * (1 + 0.012 * np.sin(2 * np.pi * 5 * tt))
    tone = sum(np.sin(2 * np.pi * np.cumsum(f * h) / SR) / h ** 1.3 for h in range(1, 7))
    horn[p:p + k] = lowp(tone, 1400) * env(k, 0.08, 1.2) * 0.3
    return reverb(rush + chimes + horn, 1.4, 0.4)


def portal_wound():
    """The Great Portal struck: a deep crack through stone, and the ring answering with a low,
    unsteady hum that falls away."""
    m = n(1.5)
    t = t_(m)
    crack = band(noise(m), 300, 3000) * np.exp(-t * 20) * 1.4 + lowp(noise(m), 120, 3) * np.exp(-t * 6) * 2.0
    hum = (np.sin(2 * np.pi * np.cumsum(np.linspace(110, 92, m)) / SR) + 0.6 * np.sin(2 * np.pi * np.cumsum(np.linspace(116.5, 97, m)) / SR)) * bell_env(m, 0.7) * np.exp(-t * 1.5) * 0.45
    return reverb(crack + hum, 1.3, 0.35)


if __name__ == "__main__":
    os.makedirs(SND, exist_ok=True)
    save("heavy_swing", heavy_swing(), 0.6)
    save("cleave", cleave(), 0.85)
    save("chakram_throw", chakram_throw(), 0.55)
    save("chakram_hit", chakram_hit(), 0.55)
    save("vanish", vanish(), 0.6)
    save("steal", steal(), 0.65)
    save("nightfall", nightfall(), 0.75)
    save("dagger_fan", dagger_fan(), 0.6)
    save("beacon_plant", beacon_plant(), 0.6)
    save("waygate", waygate(), 0.6)
    save("starlight", starlight(), 0.5)
    save("falling_star", falling_star(), 0.8)
    save("unearth", unearth(), 0.6)
    save("bolas_throw", bolas_throw(), 0.55)
    save("bolas_wrap", bolas_wrap(), 0.6)
    for name, gain in (("bear_roar", 0.75), ("bear_maul", 0.75), ("eagle_cry", 0.55), ("shapeshift", 0.65), ("quake_warning", 0.6),
                       ("earth_slam", 0.85), ("mist_blink", 0.55), ("storm_call", 0.55), ("fire_warning", 0.55), ("fire_breath", 0.7),
                       ("wyvern_roar", 0.75), ("boulder_throw", 0.65), ("boulder_impact", 0.85), ("revenant_roar", 0.85),
                       ("stone_grind", 0.5), ("woods_chatter", 0.5), ("mist_muster", 0.6), ("portal_wound", 0.75)):
        save(name, globals()[name](), gain)
    print("Beyond the Mists sounds written to", SND)
