#!/usr/bin/env python3
"""Generates all game sounds from synthesis (music: make_music.py). Original and free to use.
Creatures use a voice model: a rough vocal-cord buzz shaped by mouth resonances.
Run from the project root."""
import os, subprocess, tempfile, wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 22050
rng = np.random.default_rng(23)
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

def buzz(m, f0, f1=None, jitter=0.02, rough=0.3, wobble=0.0, wob_rate=6.0):
    """Vocal cords: a pulse train with unsteady pitch, plus breath."""
    f1 = f0 if f1 is None else f1
    f = np.interp(np.linspace(0, 1, m), np.linspace(0, 1, len(np.atleast_1d(f0))), np.atleast_1d(f0)) if np.ndim(f0) else np.linspace(f0, f1, m)
    drift = np.interp(np.arange(m), np.arange(0, m + 500, 500), rng.normal(0, 1, len(np.arange(0, m + 500, 500))))
    f = f * (1 + jitter * drift + wobble * np.sin(2 * np.pi * wob_rate * t_(m)))
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1) - 1
    # Sharper pulses sound more throaty than a plain saw.
    pulse = np.sign(saw) * np.abs(saw) ** 2.2
    return pulse + rough * noise(m) * (0.6 + 0.4 * np.sin(2 * np.pi * ph))

VOWELS = {"a": [(800, 80), (1150, 90), (2900, 120)], "o": [(450, 70), (800, 80), (2830, 100)],
          "u": [(325, 60), (700, 70), (2530, 100)], "e": [(400, 70), (1700, 100), (2600, 120)],
          "aa": [(650, 90), (1080, 100), (2650, 130)], "i": [(290, 60), (2200, 110), (3000, 120)]}

def mouth(src, vowels, shift=1.0):
    """Shapes a buzz through vowels that blend in sequence."""
    m = len(src)
    if isinstance(vowels, str):
        vowels = [vowels]
    versions = []
    for v in vowels:
        y = np.zeros(m)
        for k, (f, b) in enumerate(VOWELS[v]):
            y += band(src, f * shift - b, f * shift + b) * (1.0, 0.75, 0.3)[k]
        versions.append(y)
    if len(versions) == 1:
        return versions[0]
    out = np.zeros(m)
    pos = np.linspace(0, len(versions) - 1, m)
    for i, y in enumerate(versions):
        out += y * np.clip(1 - np.abs(pos - i), 0, 1)
    return out

def reverb(x, secs=0.9, mix=0.25, damp=3000):
    m = n(secs)
    ir = noise(m) * np.exp(-np.linspace(0, 6, m))
    ir = lowp(ir, damp)
    wet = fftconvolve(x, ir)[:len(x) + m]
    dry = np.zeros(len(wet)); dry[:len(x)] = x
    wet = wet / (np.abs(wet).max() + 1e-6) * max(np.abs(x).max(), 1e-6)
    return dry * (1 - mix) + wet * mix

def write(path, x, gain=0.8, q=2, loop=False):
    x = np.asarray(x, float)
    x = x / (np.abs(x).max() + 1e-6) * gain
    # Short fades prevent clicks, except on loops, where they would make a dip at the seam.
    if not loop:
        f = min(60, len(x) // 4)
        x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        w = os.path.join(d, "a.wav")
        with wave.open(w, "wb") as fh:
            fh.setnchannels(1); fh.setsampwidth(2); fh.setframerate(SR); fh.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)

def save(name, x, gain=0.8):
    write(SND + name + ".ogg", x, gain)

# --- Creatures -------------------------------------------------------------

def moan(sec, f0, f1, vowels, shift=0.72, rough=0.45, wob=0.03):
    m = n(sec)
    v = mouth(buzz(m, f0, f1, 0.05, rough, wob, 5.0), vowels, shift)
    return reverb(v * bell_env(m, 0.7), 0.5, 0.18, 2200)

save("groan_a", moan(1.3, 92, 70, ["o", "u"]), 0.7)
save("groan_b", moan(1.0, 110, 78, ["aa", "o"], 0.7), 0.7)
save("groan_c", moan(1.6, 74, 96, ["u", "o", "u"], 0.68, 0.55), 0.7)
save("groan_d", moan(0.8, 130, 84, ["a", "u"], 0.75), 0.7)

def snarl(sec=0.45, f0=150, shift=0.85):
    m = n(sec)
    v = mouth(buzz(m, f0, f0 * 0.65, 0.09, 0.9, 0.08, 34.0), ["a", "aa"], shift)
    return v * env(m, 0.04, 1.3)

save("attack_a", snarl(), 0.75)
save("attack_b", snarl(0.38, 190, 0.95), 0.75)
save("zombie_hurt_a", (lambda m: mouth(buzz(m, 210, 120, 0.06, 0.6), "aa", 0.85) * env(m, 0.01, 1.6))(n(0.28)), 0.65)
save("zombie_hurt_b", (lambda m: mouth(buzz(m, 170, 105, 0.07, 0.7), "o", 0.8) * env(m, 0.01, 1.6))(n(0.32)), 0.65)
def death(f0):
    m = n(1.0)
    v = mouth(buzz(m, f0, f0 * 0.42, 0.08, 0.6, 0.05, 8.0), ["aa", "o", "u"], 0.74)
    k = n(0.14); thud = np.zeros(m)
    thud[-k - 1500:-1500] = np.sin(2 * np.pi * np.cumsum(np.linspace(90, 45, k)) / SR) * env(k, 0.002, 3) * 1.3
    return reverb(v * env(m, 0.015, 1.3) + thud, 0.4, 0.15)
save("zombie_death_a", death(160), 0.75)
save("zombie_death_b", death(125), 0.75)

m = n(3.0)
contour = np.interp(np.linspace(0, 1, m), [0, 0.1, 0.25, 0.72, 1], [240, 340, 560, 540, 250])
howl_src = np.sin(2 * np.pi * np.cumsum(contour * (1 + 0.012 * np.sin(2 * np.pi * 5 * t_(m)))) / SR)
howl = howl_src + 0.5 * np.sin(4 * np.pi * np.cumsum(contour) / SR) + 0.2 * np.sin(6 * np.pi * np.cumsum(contour) / SR)
save("howl", reverb(howl * bell_env(m, 0.6) + noise(m) * 0.05 * bell_env(m), 2.0, 0.5), 0.85)

# Banshee: a rising, wavering scream through an open vowel.
m = n(2.4)
contour = np.interp(np.linspace(0, 1, m), [0, 0.25, 0.8, 1], [500, 1150, 1350, 800])
ph = np.cumsum(contour * (1 + 0.03 * np.sin(2 * np.pi * 9 * t_(m)))) / SR
scr = 2 * (ph % 1) - 1
scr = band(scr, 700, 1500) + 0.7 * band(scr, 2300, 3400) + 0.2 * noise(m)
save("banshee", reverb(scr * bell_env(m, 0.45), 1.6, 0.45), 0.8)

def caw():
    m = n(0.26)
    v = mouth(buzz(m, 620, 430, 0.1, 1.1, 0.25, 48.0), "a", 1.5)
    return v * env(m, 0.03, 1.2)
c = np.zeros(n(0.72)); a = caw(); c[:len(a)] += a; c[n(0.36):n(0.36) + len(a)] += caw() * 0.8
save("crow", reverb(c, 0.5, 0.2), 0.6)

m = n(1.1)
scree = band(buzz(m, 340, 620, 0.08, 1.2, 0.15, 22.0), 500, 3000) + noise(m) * 0.2
stone = np.zeros(m); k = n(0.3); stone[:k] = band(noise(k), 120, 900) * env(k, 0.01, 2) * 1.4
save("gargoyle", reverb(scree * env(m, 0.1, 1.4) + stone, 0.8, 0.3), 0.75)

m = n(0.42)
save("leaper", band(noise(m), 1200, 5000) * env(m, 0.05, 1.3) * 1.6 + mouth(buzz(m, 260, 180, 0.1, 1.0), "e", 0.9) * env(m, 0.02, 2), 0.65)

m = n(1.9)
whisper = sweep_filter(noise(m), 1400, 650, 0.35) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t_(m))) * bell_env(m)
choir = sum(mouth(buzz(m, f, f * 0.96, 0.01, 0.05), "o", 1.0) for f in (196, 233, 294)) * bell_env(m, 1.2) * 0.35
save("wraith", reverb(whisper + choir, 2.0, 0.6), 0.6)

m = n(0.34); bite = np.zeros(m)
for s in (0, n(0.12)):
    k = n(0.08); bite[s:s + k] += (band(noise(k), 300, 2400) + np.sin(2 * np.pi * 170 * t_(k))) * env(k, 0.001, 4)
save("mimic", bite + mouth(buzz(m, 120, 90, 0.08, 0.8), "aa", 0.8) * env(m, 0.08, 1.4) * 0.6, 0.8)

m = n(0.5)
save("creak", band(buzz(m, 42, 78, 0.2, 0.2), 300, 2600) * bell_env(m, 0.8), 0.45)

# Wolf ally.
m = n(0.26)
save("wolf", mouth(buzz(m, 320, 190, 0.08, 0.9), "aa", 1.2) * env(m, 0.01, 1.7), 0.6)

# Player.
save("hurt_a", (lambda m: mouth(buzz(m, 165, 115, 0.03, 0.3), ["aa", "u"], 1.0) * env(m, 0.01, 1.5))(n(0.3)), 0.65)
save("hurt_b", (lambda m: mouth(buzz(m, 195, 130, 0.03, 0.35), ["a", "o"], 1.0) * env(m, 0.01, 1.5))(n(0.26)), 0.65)

# --- Weapons and impacts ---------------------------------------------------

def whoosh(sec, f0, f1, gain=1.0):
    m = n(sec)
    return sweep_filter(noise(m), f0, f1, 0.55) * bell_env(m, 1.5) * gain

save("swing_a", whoosh(0.24, 500, 1700), 0.6)
save("swing_b", whoosh(0.3, 380, 1300), 0.6)
save("swing_c", whoosh(0.2, 800, 2400), 0.55)

def flesh():
    m = n(0.18)
    return (np.sin(2 * np.pi * np.cumsum(np.linspace(170, 60, m)) / SR) * 1.1 + band(noise(m), 300, 1800) * 0.9) * env(m, 0.001, 4)
save("hit_a", flesh(), 0.8)
hb = flesh(); hb[:n(0.09)] += band(noise(n(0.09)), 1500, 5000) * env(n(0.09), 0.001, 4) * 0.5
save("hit_b", hb, 0.8)

def metal(f, d, sec):
    t = np.arange(n(sec)) / SR
    return sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d * r ** 0.5) for r, a in ((1, 1), (1.47, 0.7), (2.09, 0.55), (2.76, 0.4), (3.76, 0.3)))
m = n(0.32)
save("clang", metal(1650, 14, 0.32) + band(noise(m), 2000, 7000) * env(m, 0.001, 8) * 0.8, 0.55)
save("clang_b", metal(1250, 16, 0.32) + band(noise(m), 1500, 6000) * env(m, 0.001, 8) * 0.8, 0.55)
save("block", metal(620, 22, 0.25) + (lambda k: np.sin(2 * np.pi * 130 * t_(k)) * env(k, 0.001, 5))(n(0.25)), 0.7)
save("hammer", reverb(metal(415, 3.5, 0.9) + (lambda k: band(noise(k), 200, 3000) * env(k, 0.001, 12))(n(0.9)), 1.0, 0.25), 0.8)

m = n(0.34)
tw = np.exp(-t_(m) * 13) * np.sin(2 * np.pi * np.cumsum(np.linspace(300, 150, m)) / SR)
save("bow", tw + highp(whoosh(0.34, 1500, 3200), 900) * 0.45, 0.65)
k = n(0.16); clack = band(noise(k), 900, 5000) * env(k, 0.001, 8)
save("crossbow", np.concatenate([clack * 1.3, whoosh(0.14, 1800, 3000) * 0.5]), 0.65)
m = n(0.13)
save("thunk", np.sin(2 * np.pi * np.cumsum(np.linspace(240, 90, m)) / SR) * env(m, 0.001, 4) + band(noise(m), 600, 2600) * env(m, 0.001, 8) * 0.8, 0.7)
m = n(0.2)
save("trap", (metal(980, 28, 0.2) + band(noise(m), 700, 5000) * env(m, 0.001, 9)), 0.75)

m = n(0.6)
save("fireball", sweep_filter(noise(m), 300, 900, 0.7) * bell_env(m, 0.8) + np.sin(2 * np.pi * np.cumsum(np.linspace(140, 70, m)) / SR) * env(m, 0.05, 1.5) * 0.6, 0.7)
m = n(0.42)
save("burn", lowp(noise(m), 2200) * (0.6 + 0.4 * (rng.random(m) > 0.992).astype(float) * 2) * bell_env(m, 0.7), 0.4)
m = n(0.38)
save("spell", reverb(np.sin(2 * np.pi * np.cumsum(np.linspace(1250, 420, m)) / SR) * env(m, 0.004, 2.6) + np.sin(2 * np.pi * np.cumsum(np.linspace(1880, 630, m)) / SR) * env(m, 0.004, 3.2) * 0.5 + sweep_filter(noise(m), 2600, 800, 0.5) * env(m, 0.01, 2) * 0.8, 0.6, 0.35), 0.55)
m = n(2.0)
crack = np.zeros(m); k = n(0.09); crack[:k] = noise(k) * 3
rumble = lowp(noise(m), 240, 3) * 4 * env(m, 0.02, 1.7)
save("thunder", reverb(crack + rumble, 1.5, 0.3), 0.75) # a sharp crack overshoots once compressed
m = n(1.1)
save("blast", reverb(lowp(noise(m), 500, 3) * 5 * env(m, 0.002, 2.2) + np.sin(2 * np.pi * np.cumsum(np.linspace(110, 34, m)) / SR) * env(m, 0.002, 2) * 1.2, 0.9, 0.2), 0.95)

# --- Items, UI and world ---------------------------------------------------

m = n(0.34); eat = np.zeros(m)
for s in (0, n(0.16)):
    k = n(0.1); eat[s:s + k] += band(noise(k), 900, 4000) * env(k, 0.002, 3)
save("eat", eat, 0.55)
m = n(0.5)
gl = sum(np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.8, m)) / SR) * env(m, 0.01, 2.4) * a for f, a in ((520, 1), (780, 0.5)))
save("potion", reverb(gl, 0.5, 0.3), 0.5)
def pluck(f, sec, damp=0.996, bright=0.5):
    m = n(sec); p = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, p)
    buf = lowp(np.concatenate([buf, buf]), SR * bright * 0.2)[p:]
    out = np.zeros(m); b = buf.copy(); i = 0
    for j in range(m):
        out[j] = b[i]
        nxt = (i + 1) % p
        b[i] = damp * 0.5 * (b[i] + b[nxt])
        i = nxt
    return out
m = n(0.9)
def chord(notes, sec, gap=0.07):
    out = np.zeros(n(sec))
    for i, f in enumerate(notes):
        y = pluck(f, sec - gap * i, 0.997)
        out[n(gap * i):n(gap * i) + len(y)] += y
    return out
save("chime", reverb(sum(np.sin(2 * np.pi * f * t_(m)) * np.exp(-t_(m) * 4.5) * a for f, a in ((880, 1), (1320, 0.6), (1760, 0.3))), 0.8, 0.35), 0.45)
save("level", reverb(chord([294, 370, 440, 587, 740], 1.5), 1.0, 0.3), 0.6)
save("familiar", reverb(sum(np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * 1.5, n(1.2))) / SR) * bell_env(n(1.2), 1.4) * a for f, a in ((660, 1), (990, 0.5), (1320, 0.3))), 1.5, 0.5), 0.5)
save("pickup", reverb(chord([587, 880], 0.4, 0.05), 0.3, 0.2), 0.55)
save("weapon_change", (metal(2100, 30, 0.18) * 0.7 + whoosh(0.18, 900, 2400)), 0.5)
save("empty", (lambda k: band(noise(k), 1500, 6000) * env(k, 0.001, 9))(n(0.09)), 0.45)
k = n(0.1); save("ui_click", band(noise(k), 300, 2200) * env(k, 0.001, 6) + np.sin(2 * np.pi * 180 * t_(k)) * env(k, 0.001, 8), 0.5)
save("ui_choose", reverb(chord([440, 659], 0.7, 0.06), 0.5, 0.3), 0.55)

m = n(0.34); hoof = np.zeros(m)
for s in (0, n(0.09), n(0.2)):
    k = n(0.07); hoof[s:s + k] += (np.sin(2 * np.pi * np.cumsum(np.linspace(170, 70, k)) / SR) + band(noise(k), 400, 2500) * 0.6) * env(k, 0.001, 5)
save("gallop", hoof, 0.6)
for name, lo, hi in (("step_a", 200, 1200), ("step_b", 260, 1500), ("step_c", 170, 1000)):
    k = n(0.13); save(name, band(noise(k), lo, hi) * env(k, 0.003, 4) + np.sin(2 * np.pi * 85 * t_(k)) * env(k, 0.002, 7) * 0.8, 0.6)
k = n(0.2); save("jump_a", band(noise(k), 300, 1800) * env(k, 0.01, 3), 0.45)
k = n(0.22); save("land", np.sin(2 * np.pi * np.cumsum(np.linspace(120, 55, k)) / SR) * env(k, 0.002, 4) + band(noise(k), 200, 1300) * env(k, 0.002, 5), 0.6)

t = np.arange(n(5.5)) / SR
strike = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, a, d in ((147, 0.8, 0.45), (294, 1.0, 0.6), (352, 0.65, 0.8), (441, 0.45, 1.1), (588, 0.4, 1.4), (784, 0.25, 2.0), (1045, 0.2, 2.8), (1480, 0.1, 4.0)))
strike[:n(0.02)] += noise(n(0.02)) * 1.5
save("bell", reverb(strike, 2.5, 0.35, 2500), 0.9)

# Rooster, using the same voice model.
parts = []
for dur, a, b in ((0.16, 500, 760), (0.2, 780, 880), (0.5, 900, 1050), (0.42, 1000, 640)):
    m = n(dur); parts.append(mouth(buzz(m, a, b, 0.02, 0.4, 0.05, 30.0), "a", 1.5) * bell_env(m, 0.3))
save("rooster", reverb(np.concatenate(parts), 1.5, 0.35), 0.6)

# --- Night air: wind and crickets, seamless --------------------------------

def looped(x, tail):
    """Folds a tail back onto the start, so the file loops with no gap."""
    out = x[:-tail].copy()
    out[:tail] += x[-tail:]
    return out

m = n(22); wind = lowp(noise(m + n(2)), 520, 2); wind *= 0.55 + 0.45 * np.interp(np.arange(m + n(2)), np.arange(0, m + n(2) + 8000, 8000), rng.random(len(np.arange(0, m + n(2) + 8000, 8000))))
crick = np.zeros(m + n(2))
for s in range(0, m, n(1.25)):
    for j in range(5):
        q = n(0.03); p = s + j * n(0.055)
        crick[p:p + q] += np.sin(2 * np.pi * 4300 * t_(q)) * bell_env(q)
write(SND + "night.ogg", looped(wind * 2.2 + crick * 0.13, n(2)), 0.5, loop=True)

# --- Rain and far-off thunder ------------------------------------------------

def crossfaded(x, tail):
    """Blends the end into the start with equal power, so a noisy loop has no bump at the seam."""
    a = np.sin(np.linspace(0, np.pi / 2, tail))
    out = x[:-tail].copy()
    out[:tail] = out[:tail] * a + x[-tail:] * a[::-1]
    return out

m = n(10.5)
hiss = highp(noise(m), 2200, 2) * 0.9 + band(noise(m), 500, 2200) * 0.75 + lowp(noise(m), 320, 2) * 0.35
swell = 0.86 + 0.14 * np.interp(np.arange(m), np.arange(0, m + 12000, 12000), rng.random(len(np.arange(0, m + 12000, 12000))))
drops = np.zeros(m)
for i in range(420):
    q = n(rng.uniform(0.004, 0.014))
    p = rng.integers(0, m - q)
    drops[p:p + q] += band(noise(q), rng.uniform(900, 2400), rng.uniform(3000, 7000)) * env(q, 0.05, 2) * rng.uniform(0.3, 1.5)
write(SND + "rain.ogg", crossfaded(hiss * swell + drops * 0.7, n(1.5)), 0.6, loop=True)

m = n(4.2)
roll = lowp(noise(m), 150, 3) * 5
for start, size in ((0.0, 1.0), (0.9, 0.7), (1.7, 0.85), (2.8, 0.5)):
    k = n(1.6)
    p = n(start)
    q = min(k, m - p)
    roll[p:p + q] += lowp(noise(q), 90, 3) * 9 * size * env(q, 0.12, 1.5)[:q]
save("thunder_far", reverb(roll * env(m, 0.04, 1.1), 1.2, 0.2), 0.7)
