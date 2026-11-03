#!/usr/bin/env python3
"""Generates the three music stems. Original and free to use. Run from the project root.

Phone speakers play almost nothing below about 300 Hz, so everything that carries the music
sits between 300 Hz and 3 kHz, and the low end is only there for people wearing headphones."""
import os, subprocess, tempfile, wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve, lfilter

SR = 22050
rng = np.random.default_rng(41)
MUS = "assets/music/"


def n(s):
    return int(SR * s)


def t_(m):
    return np.arange(m) / SR


def midi(p):
    return 440.0 * 2 ** ((p - 69) / 12)


def band(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo / (SR / 2), min(hi, SR / 2 - 200) / (SR / 2)], btype="band", output="sos"), x)


def lowp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 - 200) / (SR / 2), output="sos"), x)


def highp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x)


def adsr(m, a=0.02, r=0.15):
    e = np.ones(m)
    na = max(1, min(n(a), m // 2)); nr = max(1, min(n(r), m // 2))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] = np.linspace(1, 0, nr)
    return e


def saw(f, m, vib=0.0, rate=5.2):
    phase_wob = 1 + vib * np.sin(2 * np.pi * rate * t_(m) + rng.random() * 6)
    return 2 * (np.cumsum(f * phase_wob) / SR % 1) - 1


def resonances(x, peaks):
    out = np.zeros(len(x))
    for f, w, g in peaks:
        out += band(x, f - w, f + w) * g
    return out


def viol(p, sec, vib=0.006):
    """A bowed string: the singing line. Its energy sits in the body resonances."""
    m = n(sec) + n(0.2)
    x = saw(midi(p), m, vib) + 0.4 * saw(midi(p) * 1.002, m, vib)
    x = resonances(x, [(520, 180, 1.0), (1150, 300, 0.9), (2300, 500, 0.45)])
    return x * adsr(m, 0.1, 0.22)


def spiccato(p, sec=0.16):
    m = n(sec)
    x = resonances(saw(midi(p), m) + saw(midi(p) * 1.003, m), [(600, 220, 1.0), (1500, 400, 0.7)])
    return x * np.exp(-np.linspace(0, 5, m)) * adsr(m, 0.004, 0.02)


def voice(p, sec, vowel=((650, 90, 1.0), (1080, 110, 0.55), (2650, 160, 0.2))):
    """Three singers on one note, far off."""
    m = n(sec)
    x = sum(saw(midi(p) * d, m, 0.004, 4.6) for d in (0.997, 1.0, 1.003))
    return resonances(x, vowel) * adsr(m, 0.9, 1.2)


def lute(p, sec=2.4, damp=0.996):
    """Karplus-Strong string, written as a filter so a whole piece takes moments to render."""
    m = n(sec)
    d = max(2, int(SR / midi(p)))
    seed = np.zeros(m)
    burst = lowp(rng.uniform(-1, 1, d * 2), 3800)[d:]
    seed[:len(burst)] = burst
    a = np.zeros(d + 2)
    a[0] = 1.0; a[d] = -damp * 0.5; a[d + 1] = -damp * 0.5
    x = lfilter([1.0], a, seed)
    return highp(x, 240) * adsr(m, 0.001, 0.2)


def flute(p, sec):
    m = n(sec)
    f = midi(p)
    wob = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t_(m))
    ph = np.cumsum(f * wob) / SR
    x = np.sin(2 * np.pi * ph) + 0.28 * np.sin(4 * np.pi * ph) + 0.1 * np.sin(6 * np.pi * ph)
    x += band(rng.normal(0, 0.3, m), f, min(f * 3, 8000)) * 0.45
    return x * adsr(m, 0.06, 0.16)


def horn(ps, sec):
    m = n(sec)
    x = sum(saw(midi(p), m, 0.002) for p in ps)
    return lowp(highp(x, 220), 1700) * adsr(m, 0.09, 0.3)


def frame_drum(strong=True):
    """The body has real partials above 300 Hz, so a phone speaker can still say 'drum'."""
    m = n(0.42 if strong else 0.2)
    t = t_(m)
    k = np.exp(-t * (13 if strong else 26))
    x = np.sin(2 * np.pi * (108 * t + 8 * (1 - np.exp(-t * 30)))) * (1.0 if strong else 0.4)
    for f, g in ((318, 0.8), (486, 0.55), (742, 0.38), (1130, 0.2)):
        x = x + np.sin(2 * np.pi * f * t) * g * np.exp(-t * 7 * f / 300)
    slap = band(rng.normal(0, 0.5, m), 900, 4200) * np.exp(-t * (70 if strong else 44))
    return x * k + slap * (0.75 if strong else 1.1)


def bird(m):
    f = rng.uniform(2300, 3800)
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * rng.uniform(0.82, 1.3), m)) / SR) * np.sin(np.linspace(0, np.pi, m))


def reverb(x, secs=1.4, mix=0.25, damp=3200):
    m = n(secs)
    ir = lowp(rng.normal(0, 0.33, m), damp) * np.exp(-np.linspace(0, 6, m))
    wet = fftconvolve(x, ir)
    dry = np.zeros(len(wet)); dry[:len(x)] = x
    wet = wet / (np.abs(wet).max() + 1e-6) * max(np.abs(x).max(), 1e-6)
    return dry * (1 - mix) + wet * mix


def at(buf, s, y, g=1.0):
    i = n(s)
    if i >= len(buf):
        return
    e = min(i + len(y), len(buf))
    buf[i:e] += y[:e - i] * g


def fold(x, length):
    """Folds what rings past the end back onto the start, so the loop has no seam."""
    out = x[:length].copy()
    tail = x[length:]
    out[:len(tail)] += tail[:length]
    return out


def level_out(x, strength=0.75):
    """A slow compressor. The quiet passages come up, or they vanish on a phone in a noisy room."""
    m = n(1.5)
    power = np.convolve(highp(x, 300) ** 2, np.ones(m) / m, mode="same")
    env = np.sqrt(power + 1e-7)
    gain = (np.median(env) / env) ** strength
    gain = np.convolve(np.clip(gain, 0.35, 5.0), np.ones(m) / m, mode="same")
    return x * gain


def write(path, x, target_db):
    """target_db is the loudness of the part a phone can actually play."""
    x = level_out(np.asarray(x, float))
    loud = np.sqrt(np.mean(highp(x, 350, 4) ** 2)) + 1e-9
    x = x * 10 ** (target_db / 20) / loud
    # Gentle saturation keeps the odd peak from clipping without lowering everything else.
    x = np.tanh(x * 1.05) / 1.05
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        w = os.path.join(d, "a.wav")
        with wave.open(w, "wb") as fh:
            fh.setnchannels(1); fh.setsampwidth(2); fh.setframerate(SR); fh.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-c:a", "libvorbis", "-q:a", "2", path], check=True)


# Notes as MIDI numbers: D5 is 74, A4 is 69, D4 is 62.
CHORDS = {"Dm": [50, 57, 62, 65, 69], "Gm": [55, 62, 67, 70, 74], "F": [53, 60, 65, 69, 72], "Am": [57, 64, 69, 72, 76],
          "Bb": [58, 62, 65, 70, 74], "C": [55, 60, 64, 67, 72], "D": [50, 57, 62, 66, 69], "G": [55, 62, 67, 71, 74],
          "A": [57, 64, 69, 73, 76], "Bm": [59, 62, 66, 71, 74]}


def night():
    """A slow, sad waltz in D minor: lute alone, then a viol, then a far choir."""
    beat = 60 / 63
    bar = beat * 3
    a_part = ["Dm", "Gm", "F", "Am", "Dm", "Bb", "F", "Dm"]
    b_part = ["F", "Bb", "C", "Am", "Bb", "F", "Gm", "Dm"]
    form = a_part + a_part + b_part + a_part
    length = n(bar * len(form))
    x = np.zeros(length + n(6))
    for i, name in enumerate(form):
        c = CHORDS[name]
        t = i * bar
        pattern = [(0, c[0] + 12), (1, c[2]), (1.5, c[3]), (2, c[4])] if i % 2 == 0 else [(0, c[0] + 12), (0.5, c[4]), (1, c[3]), (2, c[2])]
        for off, p in pattern:
            at(x, t + off * beat + rng.uniform(0, 0.012), lute(p, 2.2), 0.62 if off == 0 else 0.5)
    a_tune = [[(74, 1), (72, 1), (69, 1)], [(70, 1.5), (69, 0.5), (67, 1)], [(69, 1), (65, 1), (67, 1)], [(69, 3)],
              [(74, 1), (72, 1), (69, 1)], [(70, 1), (72, 1), (74, 1)], [(72, 1), (69, 1), (65, 1)], [(67, 1), (64, 1), (62, 1)]]
    b_tune = [[(77, 1.5), (76, 0.5), (74, 1)], [(74, 2), (70, 1)], [(72, 1), (76, 1), (72, 1)], [(69, 3)],
              [(70, 1), (72, 1), (74, 1)], [(72, 1), (70, 1), (69, 1)], [(67, 1), (69, 1), (65, 1)], [(62, 3)]]
    def line(bars, start_bar, instrument, shift=0, gain=1.0):
        for i, notes in enumerate(bars):
            t = (start_bar + i) * bar
            for p, b in notes:
                at(x, t, instrument(p + shift, b * beat), gain)
                t += b * beat
    line(a_tune, 8, viol, 0, 0.62)
    line(b_tune, 16, viol, 0, 0.72)
    line(a_tune, 24, lambda p, s: flute(p, s), 0, 0.42)
    for i, name in enumerate(form):
        c = CHORDS[name]
        for p in (c[2], c[3]):
            at(x, i * bar, voice(p, bar * 1.25), 0.2 if i >= 16 else 0.13)
    # A low drone for headphones.
    m = len(x)
    x += lowp(saw(midi(38), m) + saw(midi(45), m), 300) * 0.1
    return fold(reverb(x, 2.2, 0.32), length)


def hunted():
    """Fast and tight: frame drums, a nervous string figure, and horns that keep getting closer."""
    beat = 60 / 118
    bars = 16
    length = n(beat * 4 * bars)
    x = np.zeros(length + n(3))
    figure = [62, 62, 63, 62, 65, 62, 63, 60]
    high = [74, 74, 75, 74, 77, 74, 75, 72]
    strong = [0.0, 1.5, 2.0]
    weak = [0.75, 2.75, 3.25, 3.5]
    for b in range(bars):
        t0 = b * 4 * beat
        for s in strong:
            at(x, t0 + s * beat, frame_drum(True), 0.95 if s == 0.0 else 0.75)
        for s in weak:
            at(x, t0 + s * beat, frame_drum(False), 0.5)
        notes = figure if b < 8 or b % 2 == 0 else [p + 5 for p in figure]
        for i, p in enumerate(notes):
            at(x, t0 + i * 0.5 * beat, spiccato(p + 12 if b >= 4 else p, 0.2), 0.5)
        if b >= 8:
            for i, p in enumerate(high):
                at(x, t0 + (i + 0.5) * 0.5 * beat, spiccato(p, 0.14), 0.32)
    for b, ps in ((3, [62, 69]), (7, [63, 70]), (11, [62, 69]), (13, [65, 72]), (15, [63, 70])):
        at(x, b * 4 * beat, horn(ps, 3.6 * beat), 0.42)
    cry = [(9, 74, 2), (9.5, 75, 2), (10, 77, 3), (11, 75, 2), (11.5, 74, 2), (13, 77, 2), (13.5, 79, 2), (14, 77, 2), (14.5, 75, 2), (15, 74, 4)]
    for b, p, dur in cry:
        at(x, b * 4 * beat, viol(p, dur * beat, 0.009), 0.6)
    x += lowp(saw(midi(38), len(x)), 240) * 0.12
    return fold(reverb(x, 0.8, 0.14), length)


def dawn():
    """The night is over: D major, an open lute and a flute, with birds."""
    beat = 60 / 76
    bar = beat * 4
    form = ["D", "G", "D", "A", "Bm", "G", "A", "D"] * 2
    length = n(bar * len(form))
    x = np.zeros(length + n(5))
    for i, name in enumerate(form):
        c = CHORDS[name]
        for j in range(8):
            p = [c[0] + 12, c[2], c[3], c[4], c[3], c[2], c[3], c[4]][j]
            at(x, i * bar + j * 0.5 * beat, lute(p, 2.0), 0.55)
        for p in (c[2], c[3], c[4]):
            at(x, i * bar, voice(p, bar * 1.2, ((560, 100, 1.0), (980, 120, 0.5), (2500, 160, 0.16))), 0.14)
    tune = [(74, 2), (76, 1), (78, 1), (79, 2), (78, 2), (78, 2), (76, 1), (74, 1), (76, 4),
            (78, 2), (79, 1), (81, 1), (83, 2), (81, 2), (79, 2), (78, 1), (76, 1), (74, 4)]
    t = bar * 8
    for p, b in tune:
        at(x, t, flute(p, b * beat), 0.42)
        t += b * beat
    for i in range(30):
        at(x, rng.uniform(1.0, length / SR - 1.0), bird(n(rng.uniform(0.06, 0.16))), 0.06)
    return fold(reverb(x, 1.9, 0.3), length)


os.makedirs(MUS, exist_ok=True)
write(MUS + "night.ogg", night(), -15.0)
write(MUS + "hunted.ogg", hunted(), -12.5)
write(MUS + "dawn.ogg", dawn(), -14.0)
