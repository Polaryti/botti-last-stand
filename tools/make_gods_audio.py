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


# --- The mutants ---------------------------------------------------------------------------------

def wings(m, f, depth=0.6, wobble=3.0):
    """An insect's wings: a buzz at the beat rate f, its pitch wavering, rough at the edges."""
    tt = t_(m)
    rate = f * (1 + 0.04 * np.sin(2 * np.pi * wobble * tt))
    ph = 2 * np.pi * np.cumsum(rate) / SR
    tone = np.sin(ph) + 0.5 * np.sin(ph * 2) + 0.3 * np.sin(ph * 3) + 0.15 * np.sign(np.sin(ph))
    return lowp(tone * (1 - depth + depth * (0.5 + 0.5 * np.sin(ph * 0.5))), 2400) * 0.3 + band(noise(m), 300, 1500) * 0.08


def bee_buzz():
    """A bee the size of a dog going past: a deep, swelling drone."""
    m = n(1.2)
    return wings(m, 150) * env(m, 0.15, 1.2) * (0.6 + 0.4 * np.sin(np.pi * t_(m) / 1.2))


def bee_sting():
    """The sting going in: a whip of wings and a wet stab."""
    m = n(0.45)
    stab = band(noise(m), 1200, 5000) * env(m, 0.002, 18) * 0.7
    return wings(m, 260) * env(m, 0.01, 6) * 0.6 + stab + thud(m, 0.02, 0.25, 220)


def wasp_buzz():
    """A wasp coming in: higher and harder than a bee, angry."""
    m = n(1.0)
    return wings(m, 230, 0.8, 6.0) * env(m, 0.08, 1.4)


def wasp_shot():
    """The stinger thrown: a snap of the abdomen and a thin whistle going away."""
    m = n(0.6)
    snap = band(noise(n(0.04)), 900, 4000) * env(n(0.04), 0.001, 30)
    whistle = np.sin(2 * np.pi * np.cumsum(curve(m, (0, 2600), (1, 1700))) / SR) * env(m, 0.01, 5) * 0.2
    return at(snap * 0.8, 0.0, 0.6) + whistle


def wasp_bite():
    """Shear jaws closing: two hard clicks."""
    m = n(0.3)
    x = np.zeros(m)
    for k in range(2):
        c = band(noise(n(0.02)), 1500, 6000) * env(n(0.02), 0.001, 40) * 0.8
        x += at(c, k * 0.07, 0.3)
    return x + thud(m, 0.07, 0.2, 260)


def hive_hum():
    """A hive alive: a low hum of many wings, never still."""
    m = n(2.0)
    x = sum(wings(m, f, 0.5, w) * 0.4 for f, w in ((120, 1.3), (137, 2.1), (155, 0.7)))
    return x * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t_(m)))


def hive_hurt():
    """The comb struck: a dull wax thud and the hum rising."""
    m = n(0.7)
    return thud(m, 0.0, 0.7, 140) + wings(m, 190, 0.6, 5.0) * env(m, 0.05, 2.5) * 0.7


def hive_swarm():
    """Bees pouring out of the hive: the hum swelling into a roar."""
    m = n(1.6)
    x = sum(wings(m, f, 0.5, 4.0) for f in (160, 190, 220, 250)) * 0.35
    return x * np.minimum(1, t_(m) / 0.4) * env(m, 0.01, 0.9)


def hive_break():
    """The hive broken: wax and wood cracking, honey falling, the bees' hum going to pieces."""
    m = n(1.8)
    crack = band(noise(m), 400, 3000) * env(m, 0.005, 4) * 0.6
    drip = sum(at(glide(700, 300, n(0.12)) * env(n(0.12), 0.005, 9) * 0.25, 0.3 + k * 0.25, 1.8) for k in range(5))
    return crack + thud(m, 0.05, 1.0, 120) + drip + wings(m, 170, 0.6, 7.0) * env(m, 0.01, 1.3) * 0.5


def nest_shudder():
    """A paper nest shaking: dry rustling and an angry buzz inside."""
    m = n(1.0)
    rustle = band(noise(m), 1500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t_(m))) * env(m, 0.05, 2.0) * 0.35
    return rustle + wings(m, 240, 0.8, 8.0) * env(m, 0.2, 1.5) * 0.5


SNAIL_FORMANTS = ((300, 0.5, 1.0), (700, 0.4, 0.4))


def snail_squelch():
    """A great snail heaving itself along: wet slaps and suction."""
    m = n(1.2)
    x = np.zeros(m)
    for k in range(4):
        s = band(noise(n(0.15)), 200, 1200) * env(n(0.15), 0.02, 9) * 0.5
        x += at(s, k * 0.28, 1.2)
    return x + lowp(noise(m), 300) * 0.15 * env(m, 0.2, 1)


def snail_hurt():
    """A snail struck: a hollow knock on its shell and a wet hiss."""
    m = n(0.6)
    return thud(m, 0.0, 0.6, 180) + band(noise(m), 800, 3000) * env(m, 0.05, 6) * 0.35


def snail_death():
    """A snail giving up: its shell cracking, a long deflating hiss."""
    m = n(1.4)
    crack = band(noise(n(0.2)), 600, 4000) * env(n(0.2), 0.002, 15) * 0.6
    hiss = band(noise(m), 1500, 5000) * np.exp(-t_(m) * 2.0) * 0.3
    return at(crack, 0.0, 1.4) + hiss + thud(m, 0.1, 0.5, 120)


def spider_hiss():
    """A spider rearing: a dry rattling hiss."""
    m = n(0.8)
    return band(noise(m), 2500, 8000) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t_(m))) * env(m, 0.03, 3) * 0.6


def spider_pounce():
    """A spider dropping: a rush of air and many legs landing."""
    m = n(0.9)
    rush = sweep_filter(noise(m), 600, 3000, 0.2) * env(m, 0.02, 5) * 0.5
    taps = sum(at(band(noise(n(0.02)), 2000, 6000) * env(n(0.02), 0.001, 40) * 0.4, 0.55 + k * 0.03, 0.9) for k in range(6))
    return rush + taps + thud(m, 0.55, 0.4, 200)


def spider_bite():
    """Fangs going in, and the web snapping tight."""
    m = n(0.5)
    fang = band(noise(n(0.05)), 1000, 5000) * env(n(0.05), 0.001, 25) * 0.7
    web = np.sin(2 * np.pi * np.cumsum(curve(m, (0, 900), (0.3, 1400), (1, 1200))) / SR) * env(m, 0.01, 8) * 0.15
    return at(fang, 0.0, 0.5) + web


def spider_hurt():
    """A spider struck: a shrill chitter."""
    m = n(0.4)
    return band(noise(m), 3000, 9000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 45 * t_(m)))) * env(m, 0.005, 9) * 0.5


def spider_death():
    """A spider dying: legs scrabbling, then curling in."""
    m = n(1.2)
    scrabble = sum(at(band(noise(n(0.02)), 2000, 7000) * env(n(0.02), 0.001, 40) * 0.3, k * 0.06, 1.2) for k in range(12))
    return scrabble + band(noise(m), 2500, 6000) * np.exp(-t_(m) * 3) * 0.25


OSTRICH_FORMANTS = ((500, 0.3, 1.0), (1100, 0.3, 0.5), (2300, 0.2, 0.2))


def ostrich_screech():
    """A battle ostrich charging: a harsh, booming screech."""
    m = n(0.9)
    voice = throat(m, curve(m, (0, 260), (0.3, 420), (1, 300)), OSTRICH_FORMANTS, breath=0.5, rough=0.9, sub=0.4)
    return voice * env(m, 0.02, 2.0) + thud(m, 0.0, 0.4, 90)


def ostrich_hiss():
    """An ostrich warning: a deep boom and a hiss."""
    m = n(1.0)
    boom = np.sin(2 * np.pi * np.cumsum(curve(m, (0, 80), (1, 60))) / SR) * env(m, 0.05, 3) * 0.5
    return boom + band(noise(m), 1500, 5000) * env(m, 0.1, 3) * 0.3


def ostrich_kick():
    """A kick landing: a heavy thud and bronze rattling on its harness."""
    m = n(0.5)
    return thud(m, 0.0, 1.0, 120) + band(noise(m), 600, 2500) * env(m, 0.002, 14) * 0.4


def ostrich_hurt():
    """An ostrich struck: a short, harsh honk."""
    m = n(0.4)
    return throat(m, curve(m, (0, 380), (1, 300)), OSTRICH_FORMANTS, breath=0.4, rough=0.8, sub=0.2) * env(m, 0.01, 6)


def ostrich_death():
    """An ostrich going down: a long falling cry and the harness crashing."""
    m = n(1.4)
    cry = throat(m, curve(m, (0, 400), (1, 160)), OSTRICH_FORMANTS, breath=0.5, rough=0.8, sub=0.3) * env(m, 0.02, 1.6)
    return cry + thud(m, 0.6, 0.9, 100)


def moth_flutter():
    """A great moth's wings: slow, soft beats, like cloth shaken."""
    m = n(1.0)
    tt = t_(m)
    beats = np.maximum(0, np.sin(2 * np.pi * 6 * tt)) ** 3
    return lowp(noise(m), 800) * beats * 0.6 * env(m, 0.05, 1.5)


def moth_dust():
    """The dust thrown: a soft clap and a crackling cloud catching fire."""
    m = n(1.2)
    clap = lowp(noise(n(0.06)), 1200) * env(n(0.06), 0.002, 25) * 0.8
    crackle = sum(at(band(noise(n(0.015)), 2000, 7000) * env(n(0.015), 0.001, 50) * rng.uniform(0.1, 0.35), rng.uniform(0.1, 1.0), 1.2) for k in range(30))
    whoosh = band(noise(m), 300, 2000) * env(m, 0.05, 3) * 0.3
    return at(clap, 0.0, 1.2) + crackle + whoosh


def insect_hurt():
    """An insect struck: a crack of shell and a stutter of its wings."""
    m = n(0.4)
    crack = band(noise(n(0.03)), 1500, 6000) * env(n(0.03), 0.001, 30) * 0.6
    return at(crack, 0.0, 0.4) + wings(m, 300, 0.9, 12.0) * env(m, 0.01, 8) * 0.5


def insect_death():
    """An insect falling: its wings sputtering out, and the body hitting the ground."""
    m = n(1.0)
    tt = t_(m)
    rate = curve(m, (0, 260), (1, 60))
    ph = 2 * np.pi * np.cumsum(rate) / SR
    sputter = np.sin(ph) * (np.sin(2 * np.pi * 11 * tt) > 0) * np.exp(-tt * 2.5) * 0.4
    return lowp(sputter, 2000) + thud(m, 0.7, 0.35, 220)


def thornback_grunt():
    """A great tortoise: a slow, creaking grunt from inside its shell."""
    m = n(1.0)
    return throat(m, curve(m, (0, 70), (1, 55)), SNAIL_FORMANTS, breath=0.3, rough=0.9, sub=0.6) * env(m, 0.1, 2.0)


def thornback_death():
    """A great tortoise dying: a long groan, and its shell settling with a crack of stone."""
    m = n(1.8)
    groan = throat(m, curve(m, (0, 75), (1, 40)), SNAIL_FORMANTS, breath=0.3, rough=0.9, sub=0.6) * env(m, 0.1, 1.2)
    return groan + thud(m, 1.0, 1.0, 80) + at(band(noise(n(0.1)), 800, 4000) * env(n(0.1), 0.002, 20) * 0.4, 1.0, 1.8)


# --- Fontanova's rites -----------------------------------------------------------------------------

def brazier_lit():
    """A brazier catching: a whoomph of flame, and the fire crackling up."""
    m = n(1.6)
    whoomph = lowp(noise(m), 600) * env(m, 0.03, 4) * 0.8
    crackle = sum(at(band(noise(n(0.015)), 2000, 7000) * env(n(0.015), 0.001, 50) * rng.uniform(0.1, 0.35), rng.uniform(0.15, 1.5), 1.6) for k in range(26))
    roar = band(noise(m), 200, 900) * np.minimum(1, t_(m) / 0.3) * env(m, 0.2, 1.2) * 0.3
    return whoomph + crackle + roar


def sanctum_open():
    """The sanctum's door sinking: stone grinding on stone, a deep boom, a breath of air from inside."""
    m = n(3.2)
    grind = band(noise(m), 80, 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t_(m))) * env(m, 0.3, 0.7) * 0.7
    boom = thud(m, 2.6, 1.2, 60)
    breath = band(noise(m), 300, 1500) * env(m, 1.5, 1.0) * 0.2
    chime = at(glass(660, 2.0, 2.0) * 0.25 + glass(990, 2.0, 2.5) * 0.15, 2.7, 3.2)
    return grind + boom + breath + chime


def altar_wake():
    """A god's altar waking: a low swell, a bell, a choir-like chord rising."""
    m = n(3.0)
    chord = sum(np.sin(2 * np.pi * f * t_(m)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * t_(m) + f)) for f in (110, 165, 220, 277)) * 0.12
    bell = metal(440, 4.0, 3.0) * bell_env(m, 2.5) * 0.25
    return reverb(chord * np.minimum(1, t_(m) / 1.2) * env(m, 0.5, 0.6) + bell, 1.6, 0.4)


def altar_bless():
    """A blessing given: a bright shimmer falling."""
    m = n(2.0)
    return reverb(sum(at(glass(f, 1.2, 3.0) * 0.22, k * 0.07, 2.0) for k, f in enumerate((1760, 1480, 1319, 1109, 880))), 1.2, 0.35)


def tide_rising():
    """The sea rising: a long roar of surf swelling, and a deep conch."""
    m = n(3.5)
    surf = band(noise(m), 150, 1200) * np.minimum(1, t_(m) / 1.5) * env(m, 0.5, 0.6) * 0.5
    conch = throat(m, curve(m, (0, 98), (0.5, 110), (1, 98)), ((420, 0.3, 1.0), (900, 0.3, 0.4)), breath=0.3, rough=0.1, sub=0.3) * env(m, 0.4, 1.2) * 0.6
    return surf + conch


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("brazier_lit", 0.75), ("sanctum_open", 0.8), ("altar_wake", 0.7), ("altar_bless", 0.6), ("tide_rising", 0.75))})


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("bee_buzz", 0.6), ("bee_sting", 0.75), ("wasp_buzz", 0.6), ("wasp_shot", 0.7), ("wasp_bite", 0.75),
    ("hive_hum", 0.5), ("hive_hurt", 0.7), ("hive_swarm", 0.7), ("hive_break", 0.8), ("nest_shudder", 0.65),
    ("snail_squelch", 0.6), ("snail_hurt", 0.7), ("snail_death", 0.75), ("spider_hiss", 0.65), ("spider_pounce", 0.75),
    ("spider_bite", 0.75), ("spider_hurt", 0.65), ("spider_death", 0.7), ("ostrich_screech", 0.75), ("ostrich_hiss", 0.65),
    ("ostrich_kick", 0.8), ("ostrich_hurt", 0.7), ("ostrich_death", 0.75), ("moth_flutter", 0.6), ("moth_dust", 0.75),
    ("insect_hurt", 0.65), ("insect_death", 0.65), ("thornback_grunt", 0.7), ("thornback_death", 0.8))})


if __name__ == "__main__":
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    for name, (make, gain) in SOUNDS.items():
        if only and name not in only:
            continue
        save(name, make(), gain)
        print("made", name)
