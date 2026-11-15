#!/usr/bin/env python3
"""The bosses of Beyond the Mists enter to the bells of its soundtrack: the same recorded tubular bells
the Mist Bastion's music tolls (tools/make_music.py `tubular`), with its bell tree and gong.

    python3 tools/make_boss_bells.py /path/to/VSCO-2-CE

Run from the project root. Writes assets/sounds/boss_bells_revenant.ogg (the Great Revenant
Elemental: a slow toll falling through E minor, the bell tree shivering after it) and
boss_bells_wyvern.ogg (the War Wyvern: the citadel's alarm, the bells climbing fast to the octave
over the gong). Both are in E minor, the key of the Bastion's bells."""
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


def wyvern():
    # The citadel's alarm: E4 G4 B4 struck quickly, the octave E5 twice, the gong under the last.
    toll = [(0.0, "E4", 0.75), (0.24, "G4", 0.78), (0.48, "B4", 0.82), (0.8, "E5", 1.0), (1.25, "E5", 0.9)]
    parts = [(at, tube(note, 3.8), gain) for at, note, gain in toll]
    parts.append((1.25, one("Percussion/gongHit_f.wav"), 0.45))
    parts.append((0.8, one("Percussion/BellTree_Stroke4_*.wav"), 0.25))
    return mix(4.8, parts)


if __name__ == "__main__":
    if not SAMPLES or not glob.glob(os.path.join(SAMPLES, "Percussion/TB_hit_*.wav")):
        raise SystemExit("Give the VSCO-2 CE folder (the soundtrack's samples) as the first argument.")
    write("assets/sounds/boss_bells_revenant.ogg", revenant(), 0.8, q=4)
    write("assets/sounds/boss_bells_wyvern.ogg", wyvern(), 0.8, q=4)
    print("boss bells done")
