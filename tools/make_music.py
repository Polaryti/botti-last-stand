#!/usr/bin/env python3
"""Composes and renders the three music stems: an orchestra playing from real recordings.

    git clone https://github.com/sgossner/VSCO-2-CE     (the samples: CC0, about 3 GB, not kept here)
    python3 tools/make_music.py path/to/VSCO-2-CE        (from the project root)

All three stems have the same tempo and length and stay in step, so the game can fade between them
at any moment. "night" is the main theme. "hunted" is the same harmony with drums and driving strings.
"dawn" turns the theme to the major for the last stretch of the night.

The tunes and the arrangement are original. Everything is written in plain note names below, so a
change to the music is a change to this file. Pitches are scientific: middle C is C4."""
import glob, os, re, subprocess, sys, tempfile, wave
import numpy as np
from scipy.fft import irfft, rfft
from scipy.ndimage import minimum_filter1d, uniform_filter1d
from scipy.signal import butter, sosfilt

SR = 44100
BPM = 80.0
BEAT = 60.0 / BPM
BARS = 32
LENGTH = int(round(BARS * 4 * BEAT * SR))
OUT = "assets/music/"
# How loud each stem ends up, as the average level in dB. The hunted stem is the loudest.
TARGET_RMS = {"night": -15.5, "hunted": -13.5, "dawn": -14.5}

NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
SAMPLES = ""


def pitch(name):
    m = re.fullmatch(r"([A-G][#b]?)(-?\d)", name)
    return 12 * (int(m.group(2)) + 1) + NAMES[m.group(1)]


def lowp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), output="sos"), x, axis=0)


def highp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x, axis=0)


def band(x, lo, hi, order=1):
    return sosfilt(butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band", output="sos"), x, axis=0)


def read_wav(path):
    from scipy.io import wavfile
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        sr, x = wavfile.read(path)
    if x.dtype == np.int16:
        x = x / 32768.0
    elif x.dtype == np.int32:
        x = x / 2147483648.0
    elif x.dtype == np.uint8:
        x = (x.astype(np.float32) - 128.0) / 128.0
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    assert sr == SR, path
    x = x[:, :2].astype(np.float32)
    # Recordings start with a little silence, and every note should start when it is told to.
    loud = np.abs(x).max(axis=1)
    above = np.nonzero(loud > loud.max() * 0.03)[0]
    start = max(0, int(above[0]) - 100) if len(above) else 0
    return x[start:]


class Instrument:
    """All the recordings of one instrument playing one way. Every recording is levelled the same,
    so how loud a note is depends on what the score says, and the layer it picks changes its tone."""

    def __init__(self, folder, level, pan, send, lead=0.03, release=0.35, short=False, scientific=False, keep=7.5):
        self.folder, self.level, self.pan, self.send = folder, level, pan, send
        self.lead, self.release, self.short, self.scientific, self.keep = lead, release, short, scientific, keep
        self.notes = None
        self.cache = {}

    def _scan(self):
        self.notes = {}
        files = glob.glob(os.path.join(SAMPLES, self.folder, "*.wav"))
        assert files, "no samples in " + self.folder
        for f in files:
            name = os.path.basename(f)
            m = re.search(r"_([A-G]#?)(\d)_", name)
            if not m:
                continue
            # The library calls middle C "C3", apart from the harp.
            midi = 12 * (int(m.group(2)) + (1 if self.scientific else 2)) + NAMES[m.group(1)]
            v = re.search(r"_v(\d)", name)
            d = re.search(r"_(p|mp|mf|f)\.wav", name)
            layer = int(v.group(1)) if v else {"p": 1, "mp": 1, "mf": 2, "f": 3}.get(d.group(1) if d else "mf", 2)
            self.notes.setdefault(layer, []).append((midi, f))
        self.layers = sorted(self.notes)

    def recording(self, path):
        if path not in self.cache:
            x = read_wav(path)
            if self.short:
                x = x / max(1e-5, np.abs(x).max()) * 0.5
            else:
                body = x[int(0.3 * SR):int(2.3 * SR)]
                if len(body) < SR // 2:
                    body = x
                x = x / max(1e-5, np.sqrt((body ** 2).mean())) * 0.12
                x = x[:int(self.keep * SR)]
            self.cache[path] = x.astype(np.float32)
        return self.cache[path]

    def pick(self, midi, vel, rng):
        if self.notes is None:
            self._scan()
        wanted = self.layers[min(int(vel * len(self.layers)), len(self.layers) - 1)]
        # The nearest pitch in the wanted layer, unless another layer has one much closer.
        best = None
        for layer in self.layers:
            for m, f in self.notes[layer]:
                cost = abs(m - midi) * 2.0 + abs(self.layers.index(layer) - self.layers.index(wanted)) * 3.0 + rng.random() * 0.4
                if best is None or cost < best[0]:
                    best = (cost, m, f)
        return best[1], best[2]


def harp_row():
    return Instrument("Strings/Harp", 0.62, -0.42, 0.34, lead=0.0, release=0.6, short=True, scientific=True, keep=6.0)


class Score:
    """One stem being written: notes go on a stave per instrument, and everything is mixed at the end."""

    def __init__(self, name, seed):
        self.name = name
        self.rng = np.random.default_rng(seed)
        self.buses = {}
        self.dynamics = [(1, 1.0), (33, 1.0)]

    def level(self, bar):
        ps = self.dynamics
        return float(np.interp(bar, [p[0] for p in ps], [p[1] for p in ps]))

    def _bus(self, inst):
        key = inst.folder
        if key not in self.buses:
            self.buses[key] = (np.zeros((LENGTH, 2), dtype=np.float32), inst)
        return self.buses[key][0]

    def _add(self, inst, sound, at_seconds):
        bus = self._bus(inst)
        start = int(at_seconds * SR) % LENGTH
        n = len(sound)
        first = min(n, LENGTH - start)
        bus[start:start + first] += sound[:first]
        if n > first:  # past the end of the loop: comes in again at its start
            bus[:n - first] += sound[first:]

    def note(self, inst, midi, beat, beats, vel, end=None, legato=False, detune=0.0, delay=0.0, dyn=True):
        """vel and end run from 0 to 1. end makes the note swell or fade while it sounds."""
        bar = beat // 4 + 1
        rng = self.rng
        v = float(np.clip(vel * (self.level(bar) if dyn else 1.0) * (1.0 + rng.normal(0.0, 0.03)), 0.02, 1.0))
        source, path = inst.pick(midi, v, rng)
        x = inst.recording(path)
        ratio = 2.0 ** ((midi - source + detune / 100.0) / 12.0)
        skip = int(0.07 * SR) if legato and not inst.short else 0
        body = int((beats * BEAT + inst.lead) * SR)
        tail = int(inst.release * SR)
        frames = body + tail
        if inst.short:
            frames = int(min(len(x) / ratio, frames))
        pos = skip + np.arange(frames) * ratio
        pos = pos[pos < len(x) - 1]
        if len(pos) < 64:
            return
        i = pos.astype(np.int32)
        f = (pos - i).astype(np.float32)[:, None]
        y = x[i] * (1.0 - f) + x[i + 1] * f
        n = len(y)
        env = np.ones(n, dtype=np.float32)
        fade = min(n // 2, int((0.09 if legato else 0.004) * SR))
        env[:fade] = np.linspace(0.0, 1.0, fade)
        if n > body:
            env[body:] = np.cos(np.linspace(0.0, np.pi / 2, n - body)) ** 2
        else:
            last = min(n // 2, int(0.05 * SR))
            env[-last:] *= np.linspace(1.0, 0.0, last)
        if end is not None:
            e = float(np.clip(end * (self.level(bar) if dyn else 1.0), 0.02, 1.0))
            env[:min(n, body)] *= np.linspace(1.0, (e / v) ** 1.35, min(n, body), dtype=np.float32)
        y = y * env[:, None] * inst.level * v ** 1.35
        humanize = rng.normal(0.0, 0.006)
        self._add(inst, y, beat * BEAT - inst.lead + humanize + delay)

    def section(self, inst, midi, beat, beats, vel, end=None, legato=False, players=2):
        """Several desks of an instrument: the same note, very slightly out of step with itself."""
        for k in range(players):
            spread = (k - (players - 1) / 2.0)
            self.note(inst, midi, beat, beats, vel * (0.85 if players > 1 else 1.0), end, legato, detune=spread * 7.0 + self.rng.normal(0, 1.5), delay=abs(spread) * 0.012)

    def play_line(self, inst, text, bar, shift=0, vel=0.7, players=1, swell=True):
        """Plays a line written as "D4:2 A4:1.5 | F4:2", with | between bars and r for a rest. Long notes
        swell a little in the middle of the phrase, as a player's breath would."""
        for midi, beat, beats in parse_line(text, bar, shift):
            end = vel * 1.1 if swell and beats >= 2.0 else None
            self.section(inst, midi, beat, beats * 1.03, vel, end=end, legato=True, players=players)


def parse_line(text, bar, shift=0):
    out = []
    for offset, chunk in enumerate(text.split("|")):
        beat = (bar + offset - 1) * 4.0
        for tok in chunk.split():
            name, length = tok.split(":")
            if name != "r":
                out.append((pitch(name) + shift, beat, float(length)))
            beat += float(length)
    return out


# --- Chords -------------------------------------------------------------------------------------

CHORDS = {"Dm": (2, 5, 9), "Bb": (10, 2, 5), "F": (5, 9, 0), "C": (0, 4, 7), "Gm": (7, 10, 2), "A": (9, 1, 4), "Asus": (9, 2, 4), "Am": (9, 0, 4)}

NIGHT_CHORDS = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A",
    "Bb", "F", "C", "Dm", "Bb", "F", "Gm", "A",
    "Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A",
    "Bb", "F", "C", "Dm", "Gm", "Bb", "Asus", "A"]

DAWN_CHORDS = ["F", "Bb", "F", "C", "Dm", "Bb", "C", "C",
    "Bb", "F", "C", "Dm", "Bb", "F", "C", "F",
    "F", "Bb", "F", "C", "Dm", "Bb", "C", "C",
    "Bb", "F", "Gm", "C", "Bb", "F", "C", "C"]

# The main theme, and its answer. Both written for the middle of the orchestra.
THEME_A = "D4:2 A4:1.5 G4:.5 | F4:2 D4:1 F4:1 | C5:2 A4:1.5 Bb4:.5 | G4:3 E4:1 | D4:2 A4:1.5 Bb4:.5 | D5:2 C5:1 Bb4:1 | A4:1.5 Bb4:.5 G4:2 | A4:4"
THEME_B = "F5:3 D5:1 | C5:2 A4:1 C5:1 | E5:3 C5:1 | D5:2 A4:2 | F5:3 G5:1 | A5:2 G5:1 F5:1 | G5:2 F5:1 D5:1 | E5:2 C#5:1 E5:1"
THEME_B_SHORT = "F5:3 D5:1 | C5:2 A4:1 C5:1 | E5:3 C5:1 | D5:2 A4:2"
CLOSING = "D5:2 Bb4:2 | D5:1 C5:1 Bb4:1 A4:1 | A4:4"
# The same tunes in the light of morning.
DAWN_A = "F4:2 C5:1.5 Bb4:.5 | Bb4:2 F4:1 Bb4:1 | C5:2 A4:1.5 Bb4:.5 | G4:3 E4:1 | D4:2 A4:1.5 Bb4:.5 | D5:2 C5:1 Bb4:1 | C5:1.5 D5:.5 E5:2 | C5:4"
DAWN_B = "F5:3 D5:1 | C5:2 A4:1 C5:1 | E5:3 C5:1 | D5:2 A4:2 | F5:3 G5:1 | A5:2 G5:1 F5:1 | G5:2 E5:1 G5:1 | F5:4"
DAWN_C = "D5:2 F5:2 | A5:3 G5:1 | Bb5:2 G5:1 Bb5:1 | C6:3 G5:1 | D6:2 Bb5:1 F5:1 | A5:2 C6:2 | G5:2 A5:1 Bb5:1 | C6:4"


def tones(chord, lo, hi):
    pcs = CHORDS[chord]
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def root_in(chord, lo):
    r = CHORDS[chord][0]
    return lo + (r - lo) % 12


def pad_voices(chords, count, lo, hi, start=None):
    """Chord tones for each bar, each voice moving as little as it can, and never all on the same note."""
    prev = start if start else tones(chords[0], lo, hi)[:count]
    rows = []
    for ch in chords:
        pool = tones(ch, lo, hi)
        row = []
        used = set()
        for p in prev:
            for c in sorted(pool, key=lambda m: abs(m - p)):
                if c % 12 not in used or len(used) >= len(CHORDS[ch]):
                    row.append(c)
                    used.add(c % 12)
                    break
        rows.append(sorted(row))
        prev = row
    return rows


def play_pad(score, inst, chords, first_bar, count, lo, hi, vel, players=1, end=None, start=None):
    """Sustained chords. A voice that stays on the same note keeps it instead of bowing again."""
    rows = pad_voices(chords, count, lo, hi, start)
    for v in range(count):
        i = 0
        while i < len(rows):
            m = rows[i][v]
            j = i + 1
            while j < len(rows) and rows[j][v] == m and j - i < 2:
                j += 1
            score.section(inst, m, (first_bar + i - 1) * 4.0, (j - i) * 4.0 + 0.1, vel, end=end, legato=i > 0, players=players)
            i = j


def harmony_below(line_text, bar, chords_of, shift=0):
    """A second voice under a tune, always on a tone of the bar's chord."""
    out = []
    held = None
    for midi, beat, beats in parse_line(line_text, bar, shift):
        chord = chords_of[int(beat // 4)]
        if beats >= 1.0 or held is None:
            under = [m for m in tones(chord, midi - 9, midi - 3)]
            if under:
                held = min(under, key=lambda m: abs(m - (held if held else midi - 4)))
        out.append((held, beat, beats))
    return out


def harp_bar(score, inst, chord, bar, vel, up_only=False):
    """Up and down the chord in eighth notes."""
    r = root_in(chord, 50)
    pcs = CHORDS[chord]
    third = (pcs[1] - pcs[0]) % 12
    fifth = (pcs[2] - pcs[0]) % 12
    shape = [r, r + fifth, r + 12, r + 12 + third, r + 12 + fifth, r + 12 + third, r + 12, r + fifth]
    if up_only:
        shape = [r, r + fifth, r + 12, r + 12 + third, r + 12 + fifth, r + 24, r + 24 + third, r + 24 + fifth]
    for i, m in enumerate(shape):
        score.note(inst, m, (bar - 1) * 4.0 + i * 0.5, 3.0, vel * (1.0 if i % 4 == 0 else 0.8))


def harp_run(score, inst, beat, beats, low, high, vel, notes=(0, 2, 4, 5, 7, 9, 10)):
    """A sweep up the strings, the way a harp announces something."""
    scale = [m for m in range(low, high + 1) if m % 12 in notes]
    for i, m in enumerate(scale):
        score.note(inst, m, beat + beats * i / len(scale), 2.0, vel * (0.55 + 0.45 * i / len(scale)), dyn=False)


# --- Choir --------------------------------------------------------------------------------------
# The library has no voices, so these are made: a few detuned voices through the resonances of "ah".

def choir_voice(midi, seconds, rng):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    f = 440.0 * 2.0 ** ((midi - 69) / 12.0)
    mix = np.zeros((n, 2))
    for k in range(6):
        cents = rng.normal(0.0, 7.0)
        wob = 1.0 + 0.0035 * np.sin(2 * np.pi * rng.uniform(4.3, 5.4) * t + rng.uniform(0, 6)) + 0.002 * np.sin(2 * np.pi * rng.uniform(0.3, 0.8) * t + rng.uniform(0, 6))
        phase = np.cumsum(f * 2.0 ** (cents / 1200.0) * wob) / SR + rng.random()
        saw = 2.0 * (phase % 1.0) - 1.0
        side = (k / 5.0 - 0.5) * 1.3
        mix[:, 0] += saw * (1.0 - max(0.0, side))
        mix[:, 1] += saw * (1.0 + min(0.0, side))
    mix += rng.normal(0.0, 0.05, mix.shape)
    out = band(mix, 480, 800, 1) * 1.0 + band(mix, 950, 1300, 1) * 0.55 + band(mix, 2300, 3000, 1) * 0.28
    out = lowp(out, 3800)
    return (out / max(1e-6, np.sqrt((out ** 2).mean())) * 0.12).astype(np.float32)


class Choir(Instrument):
    def __init__(self):
        super().__init__("(voices)", 0.34, 0.0, 0.7, lead=0.2, release=1.0)


def sing(score, choir, midi, beat, beats, vel, end=None):
    bar = beat // 4 + 1
    rng = score.rng
    v = vel * score.level(bar)
    seconds = beats * BEAT + choir.release + choir.lead
    y = choir_voice(midi, seconds, rng)
    n = len(y)
    env = np.ones(n, dtype=np.float32)
    rise = min(n // 2, int(0.7 * SR))
    env[:rise] = np.sin(np.linspace(0.0, np.pi / 2, rise)) ** 2
    fall = min(n // 2, int(choir.release * SR))
    env[-fall:] = np.cos(np.linspace(0.0, np.pi / 2, fall)) ** 2
    if end is not None:
        env *= np.linspace(1.0, end / max(vel, 0.01), n, dtype=np.float32)
    score._add(choir, y * env[:, None] * choir.level * v, beat * BEAT - choir.lead)


def choir_chords(score, choir, chords, first_bar, vel, lo=60, hi=76, count=4):
    rows = pad_voices(chords, count, lo, hi)
    for i, row in enumerate(rows):
        for m in row:
            sing(score, choir, m, (first_bar + i - 1) * 4.0, 4.1, vel)


# --- Drums --------------------------------------------------------------------------------------

class Drums:
    """Single hits, kept apart from the pitched instruments because each kind is chosen by name."""
    # The note each of the five kettledrums sounds, measured from the recordings.
    TIMPANI = {1: 41.4, 2: 46.8, 3: 49.5, 4: 52.4, 5: 54.6}

    def __init__(self):
        self.timp_bus = Instrument("Percussion/Timpani", 1.0, 0.1, 0.3, lead=0.0)
        self.big_bus = Instrument("Percussion/BDrum", 1.0, 0.0, 0.34, lead=0.0)
        self.metal_bus = Instrument("Percussion/Cymbals", 1.0, 0.18, 0.42, lead=0.0)
        self.timp_notes = None
        self.cache = {}

    def _read(self, path):
        if path not in self.cache:
            self.cache[path] = read_wav(path)
        return self.cache[path]

    def _timp_scan(self):
        self.timp_notes = []
        for f in sorted(glob.glob(os.path.join(SAMPLES, "Percussion/Timpani/*Hit*.wav"))):
            drum = int(re.search(r"Timpani(\d)_", f).group(1))
            v = int(re.search(r"_v(\d)", f).group(1))
            self.timp_notes.append((self.TIMPANI[drum], v, f))

    def timp(self, score, midi, beat, vel, gain=1.0):
        """A timpani hit on this note."""
        if self.timp_notes is None:
            self._timp_scan()
        v = float(np.clip(vel * score.level(beat // 4 + 1), 0.05, 1.0))
        wanted = 1 + int(v * 3.99)
        cands = sorted(self.timp_notes, key=lambda c: abs(c[0] - midi) + abs(c[1] - wanted) * 1.5 + score.rng.random())
        source, _, path = cands[0]
        x = self._read(path)
        ratio = 2.0 ** ((midi - source) / 12.0)
        pos = np.arange(int(min(len(x) / ratio - 2, SR * 3.0))) * ratio
        i = pos.astype(np.int32)
        f = (pos - i).astype(np.float32)[:, None]
        y = x[i] * (1.0 - f) + x[i + 1] * f
        y = y / max(1e-5, np.abs(y).max()) * 0.9 * v ** 1.2 * gain
        # Phones play no low notes at all: a little of the attack's weight is moved up to where they can.
        y = y + np.tanh(y * 5.0) * 0.1 * v
        score._add(self.timp_bus, y.astype(np.float32), beat * BEAT + score.rng.normal(0, 0.004))

    def roll(self, score, midi, beat, beats, v0, v1):
        """A roll that grows into the next downbeat."""
        drum = min(self.TIMPANI, key=lambda k: abs(self.TIMPANI[k] - midi))
        files = sorted(glob.glob(os.path.join(SAMPLES, "Percussion/Timpani/Rolls/Timpani%d_Roll_*.wav" % drum)))
        x = self._read(files[-1])
        ratio = 2.0 ** ((midi - self.TIMPANI[drum]) / 12.0)
        n = int(beats * BEAT * SR)
        pos = (int(0.2 * SR) + np.arange(n) * ratio) % (len(x) * 0.8 - 2.0)
        i = pos.astype(np.int32)
        f = (pos - i).astype(np.float32)[:, None]
        y = x[i] * (1.0 - f) + x[i + 1] * f
        y = y / max(1e-5, np.sqrt((y ** 2).mean())) * 0.1
        level = score.level(beat // 4 + 1)
        y = y * np.linspace(v0 * level, v1 * level, n, dtype=np.float32)[:, None] ** 1.4
        y[-200:] *= np.linspace(1.0, 0.0, 200, dtype=np.float32)[:, None]
        score._add(self.timp_bus, y.astype(np.float32), beat * BEAT)

    def boom(self, score, beat, vel):
        """The big drum."""
        v = float(np.clip(vel * score.level(beat // 4 + 1), 0.05, 1.0))
        layer = 1 + int(v * 6.99)
        files = sorted(glob.glob(os.path.join(SAMPLES, "Percussion/BDrumNewhit_v%d_*.wav" % layer)))
        x = self._read(files[score.rng.integers(0, len(files))])
        y = x[:int(SR * 2.5)]
        y = y / max(1e-5, np.abs(y).max()) * 0.95 * v ** 1.1
        y = y + np.tanh(y * 6.0) * 0.12 * v
        score._add(self.big_bus, y.astype(np.float32), beat * BEAT + score.rng.normal(0, 0.003))

    def crash(self, score, beat, vel):
        names = ["pp", "mp", "mf", "ff"]
        v = float(np.clip(vel * score.level(beat // 4 + 1), 0.05, 1.0))
        kind = names[min(3, int(v * 4))]
        files = sorted(glob.glob(os.path.join(SAMPLES, "Percussion/cymbal-crash1_%s_*.wav" % kind)))
        x = self._read(files[score.rng.integers(0, len(files))])[:int(SR * 5.0)]
        y = x / max(1e-5, np.abs(x).max()) * 0.5 * v
        score._add(self.metal_bus, y.astype(np.float32), beat * BEAT)

    def swell(self, score, into_beat, vel, size="Median"):
        """A suspended cymbal growing until a downbeat."""
        files = sorted(glob.glob(os.path.join(SAMPLES, "Percussion/susCymb1-cresc-%s_*.wav" % size)))
        x = self._read(files[0])
        loud = np.abs(x).max(axis=1)
        peak = int(np.argmax(lowp(loud, 20.0)))
        y = x / max(1e-5, np.abs(x).max()) * 0.42 * vel * score.level(into_beat // 4 + 1)
        y = y[:peak + int(SR * 2.5)]
        score._add(self.metal_bus, y.astype(np.float32), into_beat * BEAT - peak / SR)

    def gong(self, score, beat, vel):
        names = ["p", "mf", "f", "fff"]
        v = float(np.clip(vel, 0.05, 1.0))
        files = glob.glob(os.path.join(SAMPLES, "Percussion/gongHit_%s.wav" % names[min(3, int(v * 4))]))
        x = self._read(files[0])[:int(SR * 6.0)]
        score._add(self.metal_bus, (x / max(1e-5, np.abs(x).max()) * 0.5 * v).astype(np.float32), beat * BEAT)


# --- The orchestra ------------------------------------------------------------------------------

class Orchestra:
    def __init__(self):
        S, B, W = "Strings/", "Brass/", "Woodwinds/"
        self.violins = Instrument(S + "Violin Section/susVib", 1.0, -0.38, 0.34, lead=0.05, release=0.45)
        self.violas = Instrument(S + "Viola Section/susvib", 0.72, 0.12, 0.32, lead=0.05, release=0.45)
        self.cellos = Instrument(S + "Cello Section/susvib", 0.85, 0.34, 0.3, lead=0.05, release=0.45)
        self.basses = Instrument(S + "Solo Contrabass/SusVib", 0.8, 0.46, 0.26, lead=0.06, release=0.5)
        self.horns = Instrument(B + "F Horn/sus", 1.15, -0.2, 0.46, lead=0.03, release=0.4)
        self.trombones = Instrument(B + "Tenor Trombone/sus", 0.75, 0.28, 0.42, lead=0.03, release=0.4)
        self.trumpets = Instrument(B + "Trumpet/sus", 0.8, 0.14, 0.42, lead=0.02, release=0.35)
        self.flute = Instrument(W + "Flute/susvib", 1.0, -0.14, 0.5, lead=0.04, release=0.5)
        self.harp = harp_row()
        self.vln_short = Instrument(S + "Violin Section/Spic", 0.95, -0.38, 0.26, lead=0.0, release=0.2, short=True)
        self.vla_short = Instrument(S + "Viola Section/spic", 1.15, 0.12, 0.24, lead=0.0, release=0.2, short=True)
        self.cel_short = Instrument(S + "Cello Section/spic", 1.25, 0.34, 0.22, lead=0.0, release=0.2, short=True)
        self.bas_short = Instrument(S + "Solo Contrabass/Spic", 1.0, 0.46, 0.2, lead=0.0, release=0.2, short=True)
        self.hrn_short = Instrument(B + "F Horn/stac", 0.75, -0.2, 0.42, lead=0.0, release=0.25, short=True)
        self.tbn_short = Instrument(B + "Tenor Trombone/stac", 0.7, 0.28, 0.4, lead=0.0, release=0.25, short=True)
        self.tpt_short = Instrument(B + "Trumpet/stac", 0.78, 0.14, 0.4, lead=0.0, release=0.25, short=True)
        self.choir = Choir()
        self.drums = Drums()


def low_strings(s, o, chords, first_bar, vel, basses=True):
    """Cellos and basses on the root of each chord."""
    for i, ch in enumerate(chords):
        b = (first_bar + i - 1) * 4.0
        s.section(o.cellos, root_in(ch, 45), b, 4.1, vel, legato=i > 0, players=2)
        if basses:
            s.note(o.basses, root_in(ch, 33), b, 4.1, vel, legato=i > 0)


ACCENTS = (0, 3, 6, 8, 11, 14)  # the 3 + 3 + 2 that makes it drive


def drive_strings(s, o, chords, first_bar, vel, violins=False):
    """Sixteenth notes that never stop, leaning on the 3 + 3 + 2."""
    for i, ch in enumerate(chords):
        bar = first_bar + i
        r = root_in(ch, 50)
        pcs = CHORDS[ch]
        third = (pcs[1] - pcs[0]) % 12
        fifth = (pcs[2] - pcs[0]) % 12
        shape = [r, r, r + 12, r, r, r + 12, r + fifth, r, r, r, r + 12, r, r, r + 12 + third, r + fifth, r + 12]
        for k, m in enumerate(shape):
            beat = (bar - 1) * 4.0 + k * 0.25
            accent = k in ACCENTS
            s.note(o.vla_short, m, beat, 0.3, vel * (1.0 if accent else 0.55))
            if violins:
                s.note(o.vln_short, m + 12, beat, 0.3, vel * (0.95 if accent else 0.5))
        for k in ACCENTS:
            beat = (bar - 1) * 4.0 + k * 0.25
            s.note(o.cel_short, root_in(ch, 38), beat, 0.4, vel * (1.0 if k in (0, 8) else 0.72))
            s.note(o.bas_short, root_in(ch, 33), beat, 0.4, vel * (1.0 if k in (0, 8) else 0.72))


def pulse_low(s, o, chords, first_bar, vel):
    """A lighter pulse under the quiet parts: long, short, short."""
    for i, ch in enumerate(chords):
        bar = first_bar + i
        for beat_in_bar, a in ((0.0, 1.0), (1.5, 0.7), (2.0, 0.75), (3.5, 0.65)):
            s.note(o.cel_short, root_in(ch, 38), (bar - 1) * 4.0 + beat_in_bar, 0.6, vel * a)
            s.note(o.bas_short, root_in(ch, 33), (bar - 1) * 4.0 + beat_in_bar, 0.6, vel * a)


def drum_bar(s, d, ch, bar, vel, timp_note=None):
    beat = (bar - 1) * 4.0
    t = timp_note if timp_note else root_in(ch, 38)
    s_boom = {0: 1.0, 6: 0.72, 8: 0.92, 14: 0.7}
    for k, a in s_boom.items():
        d.boom(s, beat + k * 0.25, vel * a)
    for k, a in {0: 0.9, 3: 0.55, 6: 0.65, 11: 0.6, 12: 0.7, 15: 0.5}.items():
        d.timp(s, t, beat + k * 0.25, vel * a)


def drum_fill(s, d, ch, bar, vel):
    """The last beats of a phrase rush into the next."""
    beat = (bar - 1) * 4.0
    t = root_in(ch, 38)
    for k in range(8, 16):
        d.timp(s, t + (0 if k < 12 else 7 if t + 7 <= 53 else -5), beat + k * 0.25, vel * (0.4 + 0.6 * (k - 8) / 7.0))
    d.swell(s, beat + 4.0, 0.9, "Short")


def brass_stabs(s, o, ch, bar, vel):
    """Da-da-DAAH on the chord."""
    beat = (bar - 1) * 4.0
    rows = [(o.hrn_short, tones(ch, 57, 70)[:3]), (o.tbn_short, [root_in(ch, 41), root_in(ch, 41) + 7]), (o.tpt_short, tones(ch, 62, 74)[:2])]
    for inst, notes in rows:
        for m in notes:
            for k, a in ((0, 1.0), (3, 0.8), (6, 0.95), (14, 0.75)):
                s.note(inst, m, beat + k * 0.25, 0.4, vel * a)


# --- The three stems ----------------------------------------------------------------------------

OVER_A = (1, 2, 4, 5, 7, 9, 10)  # a sweep over the chord of A has C sharp in it


def compose_night(o):
    s = Score("night", 11)
    d = o.drums
    # It breathes: quiet and wide at first, the whole orchestra in the third part, then back.
    s.dynamics = [(1, 0.5), (8, 0.56), (9, 0.6), (16, 0.72), (17, 0.92), (24, 0.96), (25, 0.8), (29, 0.62), (32, 0.5), (33, 0.5)]
    ch = NIGHT_CHORDS
    low_strings(s, o, ch, 1, 0.62)
    play_pad(s, o.violas, ch, 1, 2, 57, 69, 0.46)
    for i, c in enumerate(ch):
        harp_bar(s, o.harp, c, i + 1, 0.8 if i < 16 else 0.78)
    # I. A horn alone, far off.
    s.play_line(o.horns, THEME_A, 1, vel=0.8, players=1)
    s.play_line(o.flute, "r:2 G5:.5 A5:.5 G5:1", 4, vel=0.74, swell=False)
    s.play_line(o.flute, "r:1 A5:.5 G5:.5 E5:1 E5:1", 8, vel=0.74, swell=False)
    d.roll(s, 38, 28.0, 4.0, 0.25, 0.55)
    # II. The violins answer, and the voices come in behind.
    s.play_line(o.violins, THEME_B, 9, vel=0.62, players=2)
    play_pad(s, o.horns, ch[8:16], 9, 2, 53, 65, 0.42)
    choir_chords(s, o.choir, ch[8:16], 9, 0.5)
    pulse_low(s, o, ch[12:16], 13, 0.6)
    d.roll(s, root_in("A", 33) + 12, 60.0, 4.0, 0.3, 0.95)
    d.swell(s, 64.0, 0.75, "Median")
    harp_run(s, o.harp, 62.0, 2.0, 57, 88, 0.6, OVER_A)
    # III. Everything: the theme high in the violins, with the horns under it.
    s.play_line(o.violins, THEME_A, 17, shift=12, vel=1.0, players=3)
    s.play_line(o.violas, THEME_A, 17, vel=0.8, players=2)
    s.play_line(o.horns, THEME_A, 17, vel=0.66, players=3)
    for m, b, l in harmony_below(THEME_A, 17, [None] * 16 + ch[16:24]):
        s.note(o.horns, m, b, l * 1.03, 0.54, legato=True)
    play_pad(s, o.trombones, ch[16:24], 17, 2, 46, 58, 0.66)
    choir_chords(s, o.choir, ch[16:24], 17, 0.95)
    pulse_low(s, o, ch[16:24], 17, 0.86)
    d.crash(s, 64.0, 0.55)
    for bar in range(17, 25):
        d.timp(s, root_in(ch[bar - 1], 38), (bar - 1) * 4.0, 0.72)
        d.boom(s, (bar - 1) * 4.0, 0.62)
        d.timp(s, root_in(ch[bar - 1], 38), (bar - 1) * 4.0 + 3.5, 0.42)
    d.swell(s, 80.0, 0.55, "Short")
    harp_run(s, o.harp, 78.0, 2.0, 57, 88, 0.55, OVER_A)
    d.crash(s, 80.0, 0.32)
    # IV. A trumpet takes the answer, and it all falls back to where it started.
    s.play_line(o.trumpets, THEME_B_SHORT, 25, shift=-12, vel=0.6, players=1)
    s.play_line(o.violins, THEME_B_SHORT, 25, vel=0.6, players=2)
    play_pad(s, o.horns, ch[24:28], 25, 2, 53, 65, 0.5)
    choir_chords(s, o.choir, ch[24:30], 25, 0.45)
    s.play_line(o.horns, CLOSING, 29, shift=-12, vel=0.62, players=1)
    s.play_line(o.flute, "A5:1 F5:1 D5:1 A4:1 | Bb5:1 F5:1 D5:1 Bb4:1", 29, vel=0.66, swell=False)
    d.roll(s, 33 + 12, 124.0, 8.0, 0.3, 0.12)
    return s


def compose_hunted(o):
    s = Score("hunted", 22)
    d = o.drums
    s.dynamics = [(1, 0.82), (8, 0.86), (9, 0.86), (16, 0.92), (17, 1.0), (24, 1.0), (25, 0.9), (32, 0.96), (33, 0.82)]
    ch = NIGHT_CHORDS
    drive_strings(s, o, ch[:8], 1, 0.8)
    drive_strings(s, o, ch[8:], 9, 0.85, violins=True)
    for i, c in enumerate(ch):
        drum_bar(s, d, c, i + 1, 0.9)
    for bar in (8, 16, 24, 32):
        drum_fill(s, d, ch[bar - 1], bar, 0.85)
    for bar in (9, 17, 25, 33):
        d.crash(s, (bar - 1) * 4.0, 0.72)
    d.gong(s, 64.0, 0.55)
    # The theme, low and hard in the brass.
    s.play_line(o.horns, THEME_A, 1, vel=0.78, players=3)
    s.play_line(o.trombones, THEME_A, 1, shift=-12, vel=0.86, players=2)
    # The answer, higher, with trumpets.
    s.play_line(o.trumpets, THEME_B, 9, shift=-12, vel=0.94, players=2)
    s.play_line(o.horns, THEME_B, 9, shift=-12, vel=0.68, players=3)
    s.play_line(o.violins, THEME_B, 9, vel=0.9, players=2)
    play_pad(s, o.trombones, ch[8:16], 9, 2, 46, 58, 0.72)
    choir_chords(s, o.choir, ch[8:16], 9, 0.6)
    # Everything on the theme.
    s.play_line(o.violins, THEME_A, 17, shift=12, vel=1.0, players=3)
    s.play_line(o.trumpets, THEME_A, 17, vel=0.92, players=2)
    s.play_line(o.horns, THEME_A, 17, vel=0.76, players=3)
    s.play_line(o.trombones, THEME_A, 17, shift=-12, vel=0.9, players=2)
    choir_chords(s, o.choir, ch[16:24], 17, 0.95)
    # Hammering on the chords, climbing back to the top.
    for i in range(24, 32):
        brass_stabs(s, o, ch[i], i + 1, 0.9)
    s.play_line(o.violins, THEME_B_SHORT, 25, vel=0.9, players=3)
    s.play_line(o.violins, CLOSING, 29, vel=0.86, players=3)
    s.play_line(o.horns, CLOSING, 29, shift=-12, vel=0.9, players=3)
    choir_chords(s, o.choir, ch[24:32], 25, 0.7)
    return s


def compose_dawn(o):
    s = Score("dawn", 33)
    d = o.drums
    s.dynamics = [(1, 0.9), (16, 0.95), (17, 0.7), (24, 0.8), (25, 1.0), (33, 0.9)]
    ch = DAWN_CHORDS
    low_strings(s, o, ch, 1, 0.8)
    play_pad(s, o.violas, ch, 1, 3, 57, 72, 0.68, players=2)
    for i, c in enumerate(ch):
        harp_bar(s, o.harp, c, i + 1, 0.75, up_only=i % 2 == 1)
    for bar in (1, 5, 9, 13, 25, 29):
        harp_run(s, o.harp, (bar - 1) * 4.0 - 2.0, 2.0, 57, 88, 0.62)
    choir_chords(s, o.choir, ch[:16], 1, 0.82, lo=62, hi=79)
    # The theme in the major, with the trumpets on top.
    s.play_line(o.trumpets, DAWN_A, 1, vel=0.92, players=2)
    s.play_line(o.horns, DAWN_A, 1, vel=0.7, players=2)
    s.play_line(o.violins, DAWN_A, 1, shift=12, vel=0.92, players=3)
    for m, b, l in harmony_below(DAWN_A, 1, ch):
        s.note(o.horns, m, b, l * 1.03, 0.56, legato=True)
    play_pad(s, o.trombones, ch[:16], 1, 2, 46, 58, 0.62)
    s.play_line(o.trumpets, DAWN_B, 9, shift=-12, vel=0.92, players=2)
    s.play_line(o.horns, DAWN_B, 9, shift=-12, vel=0.7, players=2)
    s.play_line(o.violins, DAWN_B, 9, vel=0.94, players=3)
    for bar in (1, 9, 25):
        d.crash(s, (bar - 1) * 4.0, 0.62)
        d.gong(s, (bar - 1) * 4.0, 0.45)
    for bar in list(range(1, 17)) + list(range(25, 33)):
        c = ch[bar - 1]
        d.timp(s, root_in(c, 38), (bar - 1) * 4.0, 0.72)
        d.boom(s, (bar - 1) * 4.0, 0.55)
        d.timp(s, root_in(c, 38), (bar - 1) * 4.0 + 2.0, 0.46)
        d.timp(s, root_in(c, 38), (bar - 1) * 4.0 + 3.5, 0.4)
    # Morning: the flute and the violins, and room to breathe.
    s.play_line(o.flute, DAWN_A, 17, shift=12, vel=0.62, swell=True)
    s.play_line(o.horns, DAWN_A, 17, shift=-12, vel=0.54, players=1)
    play_pad(s, o.violins, ch[16:24], 17, 3, 69, 84, 0.42)
    choir_chords(s, o.choir, ch[16:24], 17, 0.42, lo=62, hi=79)
    pulse_low(s, o, ch[20:24], 21, 0.5)
    d.roll(s, 36 + 12, 92.0, 4.0, 0.3, 0.92)
    d.swell(s, 96.0, 0.7, "Median")
    # And the last climb, everything at the top of its voice.
    s.play_line(o.violins, DAWN_C, 25, vel=0.95, players=3)
    s.play_line(o.trumpets, DAWN_C, 25, shift=-12, vel=0.92, players=2)
    s.play_line(o.horns, DAWN_C, 25, shift=-24, vel=0.74, players=2)
    play_pad(s, o.trombones, ch[24:32], 25, 2, 46, 58, 0.72)
    choir_chords(s, o.choir, ch[24:32], 25, 0.92, lo=62, hi=79)
    pulse_low(s, o, ch[24:32], 25, 0.74)
    return s


# --- Mixing -------------------------------------------------------------------------------------

def hall(seconds=2.9, seed=5):
    """The room everything is played in: a big stone hall, bright for a moment, then dark."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    channels = []
    for side in range(2):
        noise = rng.normal(0.0, 1.0, n)
        low = lowp(noise, 450, 2) * np.exp(-t / 0.72)
        mid = band(noise, 450, 2400, 1) * np.exp(-t / 0.56)
        top = highp(noise, 2400, 2) * np.exp(-t / 0.24) * 0.5
        ir = low * 1.1 + mid + top
        ir *= np.minimum(1.0, t / 0.03)
        for k in range(14):
            at = int(rng.uniform(0.018, 0.11) * SR)
            ir[at] += rng.choice([-1.0, 1.0]) * rng.uniform(1.0, 3.5) * np.exp(-at / SR / 0.1)
        channels.append(ir)
    ir = np.stack(channels, axis=1)
    return ir / np.sqrt((ir ** 2).sum(axis=0).mean())


def mix(score):
    dry = np.zeros((LENGTH, 2), dtype=np.float64)
    send = np.zeros((LENGTH, 2), dtype=np.float64)
    report = []
    for folder, (bus, inst) in score.buses.items():
        x = bus.astype(np.float64)
        x = highp(x, 34.0, 2)
        left = min(1.0, 1.0 - inst.pan)
        right = min(1.0, 1.0 + inst.pan)
        x[:, 0] *= left
        x[:, 1] *= right
        dry += x * (1.0 - inst.send * 0.35)
        send += x * inst.send
        parts = np.array_split(x, 4)
        report.append((folder, [float(np.sqrt((p ** 2).mean())) for p in parts]))
    # The hall takes no deep bass, or everything turns to mud.
    send = highp(send, 110.0, 2)
    ir = hall()
    wet = np.zeros_like(send)
    for c in range(2):
        pad = np.zeros(LENGTH)
        m = min(LENGTH, len(ir))
        pad[:m] = ir[:m, c]
        # Circular, so the end of the loop rings on into its start.
        wet[:, c] = irfft(rfft(send[:, c], workers=2) * rfft(pad, workers=2), n=LENGTH, workers=2)
    out = dry + wet * 0.85
    # A touch of warmth from the instruments' middle, where a phone's speaker can play them.
    out = out + band(out, 500, 2600, 1) * 0.28
    return out, report


def limit(x, ceiling=0.93):
    """Keeps the loudest moments under the ceiling without changing anything else. Runs around the loop."""
    loud = np.abs(x).max(axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(loud, 1e-6))
    # Hold each reduction a little, then let go slowly. Run twice so it works across the join.
    window = int(0.005 * SR)
    hold = minimum_filter1d(need, window * 2 + 1, mode="wrap")
    gain = uniform_filter1d(hold, window * 2 + 1, mode="wrap")
    gain = np.minimum(gain, hold)
    return x * gain[:, None]


def even_out(x, amount=0.5):
    """Lifts the quiet parts and lowers the loud ones, part of the way. An orchestra's full range would
    be lost under the game's sounds and a phone's small speaker."""
    power = (x ** 2).mean(axis=1)
    local = np.sqrt(uniform_filter1d(power, int(3.0 * SR), mode="wrap"))
    gain = (np.sqrt(power.mean()) / np.maximum(local, 1e-6)) ** amount
    return x * uniform_filter1d(gain, int(1.5 * SR), mode="wrap")[:, None]


def finish(score):
    x, report = mix(score)
    x = even_out(x)
    # Not too wide: on a phone both speakers are a hand's width apart.
    middle = x.mean(axis=1, keepdims=True)
    x = middle + (x - middle) * 0.7
    rms = float(np.sqrt((x ** 2).mean()))
    x = x * 10.0 ** (TARGET_RMS[score.name] / 20.0) / max(rms, 1e-9)
    print(score.name, "peak before limiting: %.2f, moments over the ceiling: %.2f%%" % (np.abs(x).max(), 100.0 * float((np.abs(x).max(axis=1) > 0.93).mean())))
    # The peaks are shaved, then the whole is set again, so the stem reaches its level.
    for _ in range(3):
        x = limit(x)
        rms = float(np.sqrt((x ** 2).mean()))
        x = x * 10.0 ** (TARGET_RMS[score.name] / 20.0) / max(rms, 1e-9)
    x = limit(x, 0.97)
    return x, report


def write(name, x):
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, name + ".wav")
        with wave.open(path, "wb") as f:
            f.setnchannels(2)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "2.6", "-map_metadata", "-1", OUT + name + ".ogg"], check=True)


COMPOSERS = {"night": compose_night, "hunted": compose_hunted, "dawn": compose_dawn}


def main():
    global SAMPLES
    if len(sys.argv) < 2:
        print(__doc__)
        return
    SAMPLES = sys.argv[1]
    wanted = sys.argv[2:] or list(COMPOSERS)
    orchestra = Orchestra()
    for name in wanted:
        score = COMPOSERS[name](orchestra)
        x, report = finish(score)
        write(name, x)
        print(name, "peak %.2f, rms %.1f dB" % (np.abs(x).max(), 20.0 * np.log10(np.sqrt((x ** 2).mean()))))
        # How loud each instrument is in each of the four parts, before the stem is levelled.
        for folder, levels in sorted(report, key=lambda r: -max(r[1])):
            print("   %-32s" % folder, " ".join("%6.1f" % (20.0 * np.log10(max(v, 1e-6))) for v in levels))


if __name__ == "__main__":
    main()
