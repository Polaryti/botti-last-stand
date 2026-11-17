#!/usr/bin/env python3
"""The bosses of Beyond the Mists enter to the bells of its soundtrack: the same recorded tubular bells
the Mist Bastion's music tolls (tools/make_music.py `tubular`), with its bell tree and gong.

    python3 tools/make_boss_bells.py /path/to/VSCO-2-CE

Run from the project root. Writes assets/sounds/boss_bells_revenant.ogg (the Great Revenant
Elemental: a slow toll falling through E minor, the bell tree shivering after it) and
boss_bells_wyvern.ogg (the War Wyvern: the citadel's alarm, the bells climbing fast to the octave
over the gong). Both are in E minor, the key of the Bastion's bells. And boss_bells_regent.ogg (the Veil
Regent: slow down through D minor to a low D struck twice over the gong, the Mists' key), and
boss_bells_sovereign.ogg (the Hollow Sovereign: Port Vael's G minor, falling slowly from D5 to a low G
struck twice, as heavy and as slow as the tide; the gong under it like a wave breaking), and
boss_bells_leviathan.ogg (the Leviathan of the Mists: the Lantern Road's D minor, a low D struck three
times like the barge's hull knocking, then D5 and A4 crying out over two gongs).
    ONLY=sovereign python3 tools/make_boss_bells.py /path/to/VSCO-2-CE     (just that one)"""
import glob, os, sys
import numpy as np
from scipy.signal import resample_poly

sys.path.insert(0, os.path.dirname(__file__))
from make_music import read_wav, pitch  # noqa: E402
from make_beyond_audio import write, SR  # noqa: E402

SAMPLES = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("VSCO", "")
TUBULAR = {"C4": 60, "G4": 67, "C5": 72, "F5": 77}
SRC_SR = 44100


def _mono(path):
    x = read_wav(path)
    x = x.mean(axis=1) if x.ndim > 1 else x
    return resample_poly(x.astype(np.float64), SR, SRC_SR)


def tube(note, seconds=4.0):
    """A tubular bell on this note, bent from the nearest recorded one, as the soundtrack does."""
    midi = pitch(note)
    name = min(TUBULAR, key=lambda k: abs(TUBULAR[k] - midi))
    x = _mono(glob.glob(os.path.join(SAMPLES, "Percussion/TB_hit_%s_*.wav" % name))[0])
    ratio = 2.0 ** ((midi - TUBULAR[name]) / 12.0)
    pos = np.arange(int(min(len(x) / ratio - 2, SR * seconds))) * ratio
    i = pos.astype(np.int64)
    f = pos - i
    y = x[i] * (1.0 - f) + x[i + 1] * f
    tail = int(SR * 0.4)
    y[-tail:] *= np.linspace(1.0, 0.0, tail)
    return y / (np.abs(y).max() + 1e-6)


def one(path_glob):
    x = _mono(sorted(glob.glob(os.path.join(SAMPLES, path_glob)))[0])
    return x / (np.abs(x).max() + 1e-6)


def mix(length, parts):
    out = np.zeros(int(SR * length))
    for at, x, gain in parts:
        a = int(SR * at)
        b = min(len(out), a + len(x))
        out[a:b] += x[:b - a] * gain
    return out


def revenant():
    # The Ring of Stones wakes: E5, B4, G4 and down to E4, each heavier, the bell tree after the last.
    toll = [(0.0, "E5", 0.62), (0.55, "B4", 0.7), (1.1, "G4", 0.8), (1.75, "E4", 1.0)]
    parts = [(at, tube(note, 4.5), gain) for at, note, gain in toll]
    parts.append((1.78, one("Percussion/BellTree_Stroke2_*.wav"), 0.35))
    parts.append((1.75, one("Percussion/gongHit_mf.wav"), 0.32))
    return mix(5.2, parts)


def regent():
    # The Veil Regent wakes in the Mists: D5, A4, F4 slowly down, then a low D struck twice with the gong
    # under it and the bell tree drawn down after, the Mists' own minor, lower and slower than the others.
    toll = [(0.0, "D5", 0.55), (0.7, "A4", 0.65), (1.4, "F4", 0.75), (2.2, "D4", 1.0), (2.6, "D4", 0.7)]
    parts = [(at, tube(note, 5.0), gain) for at, note, gain in toll]
    parts.append((2.2, one("Percussion/gongHit_mf.wav"), 0.4))
    parts.append((2.62, one("Percussion/BellTree_Stroke3_*.wav"), 0.3))
    return mix(6.2, parts)


def wyvern():
    # The citadel's alarm: E4 G4 B4 struck quickly, the octave E5 twice, the gong under the last.
    toll = [(0.0, "E4", 0.75), (0.24, "G4", 0.78), (0.48, "B4", 0.82), (0.8, "E5", 1.0), (1.25, "E5", 0.9)]
    parts = [(at, tube(note, 3.8), gain) for at, note, gain in toll]
    parts.append((1.25, one("Percussion/gongHit_f.wav"), 0.45))
    parts.append((0.8, one("Percussion/BellTree_Stroke4_*.wav"), 0.25))
    return mix(4.8, parts)


def sovereign():
    # The Hollow Sovereign rises: D5, B-flat 4 and G4 tolled as slowly as the tide turns, then a low D and
    # a lower G under the gong, and the bell tree drawn down after like water running off him.
    toll = [(0.0, "D5", 0.55), (0.9, "A#4", 0.65), (1.8, "G4", 0.78), (2.25, "D4", 0.9), (2.7, "G3", 1.0)]
    parts = [(at, tube(note, 5.0), gain) for at, note, gain in toll]
    parts.append((2.7, one("Percussion/gongHit_f.wav"), 0.42))
    parts.append((2.75, one("Percussion/BellTree_Stroke3_*.wav"), 0.3))
    return mix(6.6, parts)


def leviathan():
    # The Leviathan surfaces off the Isle of Lamps: a low D knocked three times like something under the
    # hull, then the high D and A cry out over two gongs, the second louder, as it rears.
    toll = [(0.0, "D4", 0.7), (0.45, "D4", 0.78), (0.9, "D4", 0.86), (1.6, "D5", 0.9), (2.0, "A4", 1.0), (2.5, "D4", 1.0)]
    parts = [(at, tube(note, 5.0), gain) for at, note, gain in toll]
    parts.append((1.6, one("Percussion/gongHit_mf.wav"), 0.32))
    parts.append((2.5, one("Percussion/gongHit_f.wav"), 0.46))
    parts.append((2.55, one("Percussion/BellTree_Stroke3_*.wav"), 0.3))
    return mix(6.4, parts)


if __name__ == "__main__":
    if not SAMPLES or not glob.glob(os.path.join(SAMPLES, "Percussion/TB_hit_*.wav")):
        raise SystemExit("Give the VSCO-2 CE folder (the soundtrack's samples) as the first argument.")
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    for name, make in (("revenant", revenant), ("wyvern", wyvern), ("regent", regent), ("sovereign", sovereign), ("leviathan", leviathan)):
        if not only or name in only:
            write("assets/sounds/boss_bells_%s.ogg" % name, make(), 0.8, q=4)
    print("boss bells done")
