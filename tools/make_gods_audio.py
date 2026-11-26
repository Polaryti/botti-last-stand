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


# --- The cult of Al'quimelea -----------------------------------------------------------------------

VOWEL_O = ((420, 0.35, 1.0), (800, 0.3, 0.55), (2500, 0.15, 0.12))
VOWEL_A = ((720, 0.3, 1.0), (1150, 0.25, 0.6), (2600, 0.15, 0.15))
VOWEL_U = ((320, 0.35, 1.0), (750, 0.3, 0.35), (2300, 0.15, 0.08))


def voice(m, f_curve, vowel, breath=0.15, rough=0.12):
    """A human voice, plainly sung or spoken."""
    return throat(m, f_curve, vowel, breath=breath, rough=rough, sub=0.05)


def cult_chant():
    """Worshippers chanting behind their wax masks: three voices on one slow line, muffled, a drone under."""
    m = n(2.4)
    tt = t_(m)
    line = curve(m, (0, 146), (0.3, 146), (0.35, 164), (0.6, 164), (0.65, 146), (1, 130))
    syll = 0.55 + 0.45 * np.abs(np.sin(np.pi * tt / 0.4))
    x = sum(voice(m, line * r, VOWEL_O if i != 1 else VOWEL_U) for i, r in enumerate((1.0, 1.004, 1.5)))
    drone = voice(m, np.full(m, 73.0), VOWEL_U) * 0.6
    return lowp((x * syll + drone) * env(m, 0.3, 0.9), 1800) * 0.5


def worshipper_hurt():
    m = n(0.4)
    return lowp(voice(m, curve(m, (0, 220), (1, 160)), VOWEL_A, breath=0.4, rough=0.5), 2000) * env(m, 0.01, 7)


def worshipper_death():
    m = n(1.1)
    return lowp(voice(m, curve(m, (0, 200), (1, 90)), VOWEL_O, breath=0.4, rough=0.4), 1800) * env(m, 0.02, 2.2) + thud(m, 0.75, 0.5, 120)


def priest_intone():
    """A priest's rite: a deep intoned line climbing, and a small bronze bell under it."""
    m = n(1.6)
    line = curve(m, (0, 98), (0.4, 110), (0.7, 131), (1, 123))
    sung = voice(m, line, VOWEL_A, breath=0.1) * env(m, 0.15, 1.2)
    ring = metal(1320, 3.0, 1.6) * bell_env(m, 1.5) * 0.12
    return reverb(sung + ring, 1.2, 0.35)


def priest_hurt():
    m = n(0.45)
    return voice(m, curve(m, (0, 180), (1, 120)), VOWEL_O, breath=0.4, rough=0.5) * env(m, 0.01, 6)


def priest_death():
    """A priest falling: a long sigh, and its vials breaking."""
    m = n(1.4)
    sigh = voice(m, curve(m, (0, 160), (1, 70)), VOWEL_O, breath=0.5, rough=0.3) * env(m, 0.02, 1.8)
    glass_ = sum(at(glass(r, 0.3, 14.0) * 0.12, 0.6 + k * 0.07, 1.4) for k, r in enumerate((2200, 2900, 3500)))
    return sigh + glass_ + thud(m, 0.6, 0.4, 130)


def elixir_throw():
    """A flask flung: a swish and liquid sloshing in glass."""
    m = n(0.5)
    swish = sweep_filter(noise(m), 500, 2500, 0.3) * env(m, 0.05, 6) * 0.4
    slosh = band(noise(m), 300, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t_(m))) * env(m, 0.02, 5) * 0.3
    return swish + slosh


def elixir_shatter():
    """The flask breaking: glass, a splash, and the elixir hissing."""
    m = n(1.0)
    shards = sum(at(glass(r, 0.25, 18.0) * 0.18, k * 0.02, 1.0) for k, r in enumerate((2400, 3100, 3900, 4700)))
    splash = band(noise(m), 600, 3000) * env(m, 0.003, 9) * 0.6
    hiss = band(noise(m), 3000, 8000) * np.exp(-t_(m) * 2.5) * 0.18
    return shards + splash + hiss


def anoint_chime():
    """A hurt creature anointed: a bright chime rising."""
    m = n(1.2)
    return reverb(sum(at(glass(f, 0.9, 4.0) * 0.25, k * 0.08, 1.2) for k, f in enumerate((880, 1109, 1319, 1760))), 1.0, 0.3)


def guardian_shout():
    """A Guardian's battle-cry, inside its helmet."""
    m = n(0.7)
    bark = voice(m, curve(m, (0, 150), (0.3, 190), (1, 140)), VOWEL_A, breath=0.3, rough=0.6) * env(m, 0.02, 3)
    return lowp(bark, 2500) + band(noise(m), 1500, 4000) * env(m, 0.005, 20) * 0.1


def guardian_hurt():
    m = n(0.4)
    return lowp(voice(m, curve(m, (0, 160), (1, 120)), VOWEL_A, breath=0.4, rough=0.6), 2200) * env(m, 0.01, 7) + band(noise(m), 2000, 6000) * env(m, 0.002, 30) * 0.2


def guardian_death():
    """A Guardian falling: a groan, and bronze crashing on stone."""
    m = n(1.5)
    groan = voice(m, curve(m, (0, 150), (1, 70)), VOWEL_O, breath=0.4, rough=0.5) * env(m, 0.02, 2.0)
    crash = sum(at(band(noise(n(0.2)), 1500, 6000) * env(n(0.2), 0.002, 14) * 0.4, 0.8 + k * 0.12, 1.5) for k in range(3))
    return groan + crash + thud(m, 0.8, 0.8, 110)


def shield_rush():
    """Running in behind the shield: heavy steps and bronze rattling."""
    m = n(0.9)
    steps = sum(at(lowp(noise(n(0.08)), 300) * env(n(0.08), 0.002, 30) * 0.8, k * 0.18, 0.9) for k in range(5))
    rattle = band(noise(m), 2500, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t_(m))) * env(m, 0.05, 2) * 0.15
    return steps + rattle


def shield_bash():
    """The shield striking: a bronze boom and a body thrown back."""
    m = n(0.8)
    clang = band(noise(n(0.05)), 800, 4000) * env(n(0.05), 0.001, 30) * 0.8
    return at(clang, 0.0, 0.8) + thud(m, 0.0, 1.0, 140) + glide(420, 300, m) * np.exp(-t_(m) * 7) * 0.25


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("cult_chant", 0.6), ("worshipper_hurt", 0.65), ("worshipper_death", 0.7), ("priest_intone", 0.7), ("priest_hurt", 0.65),
    ("priest_death", 0.7), ("elixir_throw", 0.6), ("elixir_shatter", 0.75), ("anoint_chime", 0.6), ("guardian_shout", 0.75),
    ("guardian_hurt", 0.7), ("guardian_death", 0.75), ("shield_rush", 0.7), ("shield_bash", 0.8))})


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("bee_buzz", 0.6), ("bee_sting", 0.75), ("wasp_buzz", 0.6), ("wasp_shot", 0.7), ("wasp_bite", 0.75),
    ("hive_hum", 0.5), ("hive_hurt", 0.7), ("hive_swarm", 0.7), ("hive_break", 0.8), ("nest_shudder", 0.65),
    ("snail_squelch", 0.6), ("snail_hurt", 0.7), ("snail_death", 0.75), ("spider_hiss", 0.65), ("spider_pounce", 0.75),
    ("spider_bite", 0.75), ("spider_hurt", 0.65), ("spider_death", 0.7), ("ostrich_screech", 0.75), ("ostrich_hiss", 0.65),
    ("ostrich_kick", 0.8), ("ostrich_hurt", 0.7), ("ostrich_death", 0.75), ("moth_flutter", 0.6), ("moth_dust", 0.75),
    ("insect_hurt", 0.65), ("insect_death", 0.65), ("thornback_grunt", 0.7), ("thornback_death", 0.8))})



# --- The cult's minibosses ------------------------------------------------------------------------

def hierophant_voice():
    """The Hierophant preaching: a deep voice, doubled an octave down as if two spoke, a bell behind."""
    m = n(2.0)
    line = curve(m, (0, 110), (0.25, 123), (0.5, 98), (0.8, 116), (1, 92))
    words = 0.5 + 0.5 * np.abs(np.sin(np.pi * t_(m) / 0.33))
    x = voice(m, line, VOWEL_A, breath=0.15, rough=0.2) + voice(m, line * 0.5, VOWEL_O, breath=0.1) * 0.7
    ring = metal(660, 3.0, 2.0) * bell_env(m, 1.6) * 0.08
    return reverb(lowp(x * words, 2400) * env(m, 0.1, 0.8) + ring, 1.4, 0.4)


def hierophant_hurt():
    m = n(0.6)
    return lowp(voice(m, curve(m, (0, 150), (1, 95)), VOWEL_A, breath=0.35, rough=0.5) + voice(m, curve(m, (0, 75), (1, 48)), VOWEL_O) * 0.6, 2000) * env(m, 0.01, 5)


def hierophant_death():
    """The Hierophant falling: both voices sinking apart, glass breaking, a bell going on alone."""
    m = n(2.6)
    a_ = voice(m, curve(m, (0, 120), (1, 55)), VOWEL_O, breath=0.4, rough=0.3) * env(m, 0.02, 1.2)
    b_ = voice(m, curve(m, (0, 60), (1, 40)), VOWEL_U, breath=0.2) * env(m, 0.02, 1.0) * 0.7
    glass_ = sum(at(glass(r, 0.4, 10.0) * 0.14, 0.9 + k * 0.06, 2.6) for k, r in enumerate((1900, 2600, 3300, 4100)))
    ring = at(metal(440, 2.6, 1.6) * bell_env(n(1.6), 1.2) * 0.12, 1.0, 2.6)
    return reverb(a_ + b_ + glass_ + ring + thud(m, 1.0, 0.9, 100), 1.6, 0.35)


def transmute_rite():
    """The elixir of change poured out: a seething boil, and a chord climbing out of it, not quite in tune."""
    m = n(2.4)
    tt = t_(m)
    boil = band(noise(m), 200, 1400) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * tt + np.sin(2 * np.pi * 1.3 * tt) * 3))) * env(m, 0.3, 1.0) * 0.4
    chord = sum(np.sin(2 * np.pi * np.cumsum(curve(m, (0, f), (1, f * 1.5))) / SR) * 0.08 for f in (130, 164, 196, 233))
    return reverb(boil + chord * env(m, 0.6, 1.2), 1.4, 0.35)


def polemarch_voice():
    """The Polemarch's war-cry, booming in its helmet."""
    m = n(1.0)
    bark = voice(m, curve(m, (0, 120), (0.3, 165), (1, 110)), VOWEL_A, breath=0.25, rough=0.7) * env(m, 0.02, 2.2)
    return reverb(lowp(bark, 2200) + band(noise(m), 1200, 3500) * env(m, 0.005, 12) * 0.12, 0.7, 0.3)


def polemarch_hurt():
    m = n(0.5)
    return lowp(voice(m, curve(m, (0, 130), (1, 95)), VOWEL_A, breath=0.4, rough=0.7), 2000) * env(m, 0.01, 6) + band(noise(m), 2000, 6000) * env(m, 0.002, 30) * 0.25


def polemarch_death():
    """The Polemarch falling: a roar breaking off, the great shield ringing down on the stones."""
    m = n(2.2)
    roar = voice(m, curve(m, (0, 140), (1, 60)), VOWEL_O, breath=0.4, rough=0.6) * env(m, 0.02, 1.6)
    ring = at(metal(310, 3.5, 1.4) * bell_env(n(1.4), 1.6) * 0.25, 0.9, 2.2)
    return roar + ring + thud(m, 0.9, 1.0, 90) + thud(m, 1.1, 0.6, 120)


def spear_sweep():
    """A long spear swept low: a deep swish and the bronze head ringing at the end of it."""
    m = n(0.8)
    swish = sweep_filter(noise(m), 300, 1800, 0.35) * env(m, 0.08, 4) * 0.55
    return swish + at(metal(1250, 3.0, 0.6) * bell_env(n(0.6), 4) * 0.12, 0.35, 0.8)


def phalanx_call():
    """The Polemarch calls its Guardians: a bronze horn, two long falling notes, spears struck on shields."""
    m = n(2.2)
    horn = sum(at(lowp(sum(np.sin(2 * np.pi * np.cumsum(curve(n(0.9), (0, f), (1, f * 0.94))) / SR * h) * a for h, a in ((1, 1.0), (2, 0.5), (3, 0.3))), 1800) * env(n(0.9), 0.08, 1.6) * 0.3, s_, 2.2)
        for s_, f in ((0.0, 196), (0.9, 147)))
    clash = sum(at(band(noise(n(0.06)), 1500, 6000) * env(n(0.06), 0.001, 25) * 0.4, 1.6 + k * 0.14, 2.2) for k in range(3))
    return reverb(horn + clash, 1.2, 0.3)


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("hierophant_voice", 0.75), ("hierophant_hurt", 0.7), ("hierophant_death", 0.8), ("transmute_rite", 0.75),
    ("polemarch_voice", 0.8), ("polemarch_hurt", 0.7), ("polemarch_death", 0.8), ("spear_sweep", 0.7), ("phalanx_call", 0.75))})



# --- Al'quimelea --------------------------------------------------------------------------------------

def _choir(m, line, spread=(1.0, 1.26, 1.5, 0.5)):
    """Many voices on one line, each a little out of tune with the others: the god speaking."""
    return sum(voice(m, line * r * (1 + 0.006 * k), (VOWEL_O, VOWEL_A, VOWEL_U, VOWEL_O)[k % 4], breath=0.12) * (0.9 if r != 0.5 else 0.7)
        for k, r in enumerate(spread))


def alq_voice():
    """Al'quimelea speaking: a choir of voices on one falling line, glass ringing in it."""
    m = n(3.0)
    line = curve(m, (0, 98), (0.3, 104), (0.55, 92), (0.8, 87), (1, 82))
    words = 0.55 + 0.45 * np.abs(np.sin(np.pi * t_(m) / 0.45))
    ring = sum(at(glass(f, 1.6, 2.5) * 0.06, k * 0.4, 3.0) for k, f in enumerate((1318, 1397, 1661)))
    return reverb(lowp(_choir(m, line) * words, 2600) * env(m, 0.2, 0.7) + ring, 2.0, 0.45)


def alq_roar():
    """It tears itself open: every voice rising into a scream, a boiling under it."""
    m = n(2.4)
    line = curve(m, (0, 82), (0.5, 140), (1, 120))
    scream = _choir(m, line, (1.0, 1.06, 1.5, 2.0)) * env(m, 0.1, 1.2)
    boil = band(noise(m), 150, 900) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 7 * t_(m)))) * env(m, 0.2, 1.0) * 0.4
    return reverb(lowp(scream, 3000) * 0.8 + boil + thud(m, 0.0, 0.8, 70), 1.8, 0.4)


def alq_hurt():
    m = n(0.8)
    return reverb(lowp(_choir(m, curve(m, (0, 130), (1, 95))), 2400) * env(m, 0.01, 4.0) + glass(2200, 0.8, 12.0) * 0.08, 0.8, 0.3)


def alq_death():
    """Its end: the voices sinking and falling apart one by one, glass breaking, a long boil going quiet."""
    m = n(5.5)
    sink = sum(voice(m, curve(m, (0, f), (0.5 + k * 0.1, f * 0.7), (1, f * 0.4)), VOWEL_O, breath=0.3) * env(m, 0.05, 0.6 + k * 0.25) * 0.6 for k, f in enumerate((120, 150, 180, 98)))
    shards = sum(at(glass(r, 0.5, 8.0) * 0.12, 0.8 + k * 0.23, 5.5) for k, r in enumerate((1800, 2300, 2900, 3600, 4400, 5100)))
    boil = band(noise(m), 200, 1200) * np.exp(-t_(m) * 0.6) * 0.25
    return reverb(sink + shards + boil + thud(m, 2.6, 1.0, 60), 2.4, 0.4)


def alq_shatter():
    """Its halo breaks: many flasks at once, falling and smashing."""
    m = n(1.6)
    return sum(at(glass(r, 0.35, 14.0) * 0.12, k * 0.07, 1.6) for k, r in enumerate((1900, 2600, 3100, 3900, 4400, 5200, 2800, 3500))) + band(noise(m), 2000, 7000) * env(m, 0.01, 4) * 0.15


def alq_gather():
    """The crucible gathering its light: a rising hum and a hiss."""
    m = n(1.4)
    hum = sum(np.sin(2 * np.pi * np.cumsum(curve(m, (0, f), (1, f * 2.0))) / SR) * 0.1 for f in (110, 165))
    return (hum + band(noise(m), 3000, 8000) * 0.05) * env(m, 0.8, 0.4)


def alq_nova():
    """The nova: a white boom, a ring of light rolling out."""
    m = n(1.6)
    boom = thud(m, 0.0, 1.2, 55) + band(noise(m), 300, 4000) * env(m, 0.002, 4) * 0.6
    ring = glide(1400, 700, m) * np.exp(-t_(m) * 2.5) * 0.15
    return reverb(boom + ring, 1.4, 0.35)


def alq_change():
    """The ground changing under you: a crack, and a bright chord coming up out of it."""
    m = n(1.3)
    crack = band(noise(n(0.1)), 800, 5000) * env(n(0.1), 0.002, 20) * 0.6
    chord = sum(glass(f, 1.3, 3.5) * 0.08 for f in (659, 698, 831, 988))
    return at(crack, 0.0, 1.3) + chord + thud(m, 0.0, 0.5, 90)


def alq_shard():
    """A crystal shard driven into the ground."""
    m = n(0.6)
    return glass(2600, 0.6, 9.0) * 0.18 + glass(1950, 0.6, 9.0) * 0.12 + band(noise(m), 1500, 6000) * env(m, 0.002, 18) * 0.3


def alq_lance():
    """The lance cast: shards drawn together with a rising chime."""
    m = n(1.0)
    return sum(at(glass(f, 0.5, 6.0) * 0.1, k * 0.06, 1.0) for k, f in enumerate((880, 988, 1175, 1318, 1568, 1760, 2093)))


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("alq_voice", 0.8), ("alq_roar", 0.85), ("alq_hurt", 0.7), ("alq_death", 0.85), ("alq_shatter", 0.75), ("alq_gather", 0.7),
    ("alq_nova", 0.85), ("alq_change", 0.75), ("alq_shard", 0.7), ("alq_lance", 0.7))})



# --- Fontanova's weapons ----------------------------------------------------------------------

def censer_swing():
    """A censer swung on its chain: links chinking, the bronze bowl whooshing through the air, the embers
    breathing as it goes."""
    m = n(0.55)
    whoosh = sweep_filter(noise(m), 300, 1800, 0.35) * env(m, 0.08, 5) * 0.45
    chink = sum(at(metal(rng.uniform(2600, 3600), 30, 0.08) * bell_env(n(0.08), 30) * 0.08, k * 0.05, 0.55) for k in range(4))
    breath = band(noise(m), 800, 2400) * env(m, 0.1, 4) * 0.12
    return whoosh + chink + breath


def censer_ready():
    """The censer full: the resin catching, a low hum, and one small temple bell."""
    m = n(0.9)
    catch = band(noise(m), 1500, 5000) * env(m, 0.005, 9) * 0.2
    bell = metal(1320, 6, 0.9) * bell_env(m, 4.0) * 0.14
    hum = np.sin(2 * np.pi * 165 * t_(m)) * env(m, 0.1, 3) * 0.08
    return catch + bell + hum


def censer_release():
    """The release: a heavy whoosh all the way round, bronze ringing, and the smoke bursting out with a
    roar of embers."""
    m = n(1.3)
    whoosh = sweep_filter(noise(m), 200, 2600, 0.5) * env(m, 0.12, 2.6) * 0.6
    ring = metal(740, 5, 1.3) * bell_env(m, 3.0) * 0.18 + metal(1110, 6, 1.3) * bell_env(m, 3.5) * 0.1
    roar = band(noise(m), 400, 3000) * np.exp(-((t_(m) - 0.3) ** 2) / 0.08) * 0.35
    return reverb(whoosh + ring + roar + thud(m, 0.25, 0.5, 100), 0.8, 0.2)


def repeater_shot():
    """The Resin Repeater: a tight crack of the prod, the lever clacking the next bolt down."""
    m = n(0.4)
    snap = band(noise(n(0.03)), 1200, 6000) * env(n(0.03), 0.001, 60) * 0.8
    thrum = glide(240, 160, m) * np.exp(-t_(m) * 22) * 0.35
    clack = band(noise(n(0.03)), 2000, 7000) * env(n(0.03), 0.001, 50) * 0.35
    return at(snap, 0.0, 0.4) + thrum + at(clack, 0.16, 0.4) + at(clack * 0.7, 0.21, 0.4)


def greataxe_swing():
    """The Ruin-Breaker's chop: a long heavy whoosh, deep, the haft creaking."""
    m = n(0.7)
    whoosh = sweep_filter(noise(m), 160, 1300, 0.5) * env(m, 0.15, 4) * 0.7
    creak = band(noise(m), 300, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t_(m))) * env(m, 0.05, 6) * 0.12
    return whoosh + creak


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("censer_swing", 0.6), ("censer_ready", 0.6), ("censer_release", 0.85), ("repeater_shot", 0.7), ("greataxe_swing", 0.75))})


# --- The Ascendant ----------------------------------------------------------------------------

def ascend_leap():
    """Rising: a rush of air upward and a breath of choir."""
    m = n(0.7)
    rush = sweep_filter(noise(m), 300, 3200, 0.45) * env(m, 0.05, 3) * 0.5
    choir = _choir(m, curve(m, (0, 330), (1, 440)), spread=(1.0, 1.5, 2.0)) * env(m, 0.15, 3) * 0.25
    return rush + choir


def ascend_crash():
    """Coming down: a stone-breaking crash, dust, and a ringing chord."""
    m = n(1.4)
    crash = thud(m, 0.0, 1.4, 70) + band(noise(m), 200, 3000) * env(m, 0.002, 6) * 0.7
    grit = band(noise(m), 2500, 7000) * env(m, 0.02, 4) * 0.15
    chord = sum(glass(f, 1.4, 3.0) * 0.05 for f in (440, 554, 659))
    return reverb(crash + grit + chord, 1.0, 0.25)


def deicide_strike():
    """Deicide: the axe coming down out of the leap, a heavy bite, and a choir cut off."""
    m = n(1.5)
    bite = thud(m, 0.0, 1.5, 60) + at(band(noise(n(0.08)), 600, 5000) * env(n(0.08), 0.001, 25) * 0.9, 0.0, 1.5)
    choir = _choir(m, curve(m, (0, 392), (0.2, 392), (1, 196)), spread=(1.0, 1.26, 1.5, 0.5)) * np.exp(-t_(m) * 6) * 0.35
    return reverb(bite + choir, 1.2, 0.3)


def rite_break():
    """An attack broken: a holy chord shattering like glass and falling away."""
    m = n(1.3)
    chord = sum(glass(f, 1.3, 2.0) * 0.07 for f in (523, 659, 784, 1047))
    shatter = sum(at(glass(r, 0.3, 14.0) * 0.14, 0.05 + k * 0.025, 1.3) for k, r in enumerate((2200, 2900, 3700, 4600, 5400)))
    fall = glide(900, 220, m) * np.exp(-t_(m) * 3) * 0.12
    return reverb(chord * np.exp(-t_(m) * 8) + shatter + fall, 1.0, 0.3)


def elixir_drink():
    """The Elixir of Change drunk: a gulp, bubbling, and a bright chord swelling up."""
    m = n(1.4)
    gulp = sum(at(lowp(noise(n(0.09)), 500) * env(n(0.09), 0.01, 18) * 0.5, k * 0.16, 1.4) for k in range(3))
    bubbles = sum(at(glide(rng.uniform(500, 900), rng.uniform(900, 1500), n(0.06)) * env(n(0.06), 0.005, 30) * 0.08, rng.uniform(0.3, 1.0), 1.4) for _ in range(10))
    swell = sum(glass(f, 1.4, 1.5) * 0.06 for f in (587, 740, 880)) * np.clip(t_(m) / 0.9, 0, 1)
    return gulp + bubbles + swell


def change_end():
    """The change ebbing away: a falling sigh of chord."""
    m = n(0.9)
    return reverb(sum(glide(f, f * 0.75, m) * 0.05 for f in (587, 740, 880)) * env(m, 0.03, 3), 0.8, 0.3)


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("ascend_leap", 0.7), ("ascend_crash", 0.85), ("deicide_strike", 0.9), ("rite_break", 0.8), ("elixir_drink", 0.7), ("change_end", 0.6))})


# --- The Honeycomb and the Mysterious Flask -----------------------------------------------------

def honeycomb_hum():
    """The Honeycomb's bees going out to sting: a swelling buzz of many small wings."""
    m = n(0.9)
    tt = t_(m)
    buzz = sum(np.sin(2 * np.pi * np.cumsum(np.full(m, f) * (1 + 0.02 * np.sin(2 * np.pi * rng.uniform(5, 9) * tt))) / SR) for f in (220, 233, 247, 262))
    buzz = band(np.sign(buzz) * np.abs(buzz) ** 0.6, 200, 3000) * env(m, 0.15, 3) * 0.25
    return buzz


def honey_forage():
    """Honey brought back: a sticky plop and a small bright chime."""
    m = n(0.8)
    plop = glide(500, 180, n(0.12)) * env(n(0.12), 0.003, 20) * 0.5
    return at(plop, 0.0, 0.8) + glass(1760, 0.8, 5.0) * 0.12 + glass(2217, 0.8, 6.0) * 0.06


def flask_drink():
    """The Mysterious Flask: a cork drawn, a swallow, and something unexpected fizzing up."""
    m = n(1.1)
    cork = band(noise(n(0.04)), 800, 4000) * env(n(0.04), 0.001, 40) * 0.6 + glide(900, 600, n(0.04)) * 0.2
    gulp = sum(at(lowp(noise(n(0.08)), 450) * env(n(0.08), 0.01, 18) * 0.45, 0.25 + k * 0.15, 1.1) for k in range(2))
    fizz = band(noise(m), 4000, 9000) * np.clip((t_(m) - 0.55) / 0.2, 0, 1) * np.exp(-np.clip(t_(m) - 0.75, 0, None) * 4) * 0.15
    return at(cork, 0.0, 1.1) + gulp + fizz


def flask_sour():
    """The flask was bad: a sour gurgle and a cough."""
    m = n(0.9)
    gurgle = band(noise(m), 200, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t_(m))) * env(m, 0.05, 4) * 0.4
    cough = voice(n(0.25), curve(n(0.25), (0, 220), (1, 160)), VOWEL_A, breath=0.8, rough=0.5) * env(n(0.25), 0.005, 12)
    return gurgle + at(cough, 0.5, 0.9) * 0.6


SOUNDS.update({n_: (globals()[n_], g) for n_, g in (
    ("honeycomb_hum", 0.55), ("honey_forage", 0.65), ("flask_drink", 0.7), ("flask_sour", 0.7))})

if __name__ == "__main__":
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    for name, (make, gain) in SOUNDS.items():
        if only and name not in only:
            continue
        save(name, make(), gain)
        print("made", name)
