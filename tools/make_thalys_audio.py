#!/usr/bin/env python3
"""Synthesize Thalys's boss melody and monster cues. Requires ffmpeg."""
from math import exp, pi, sin
from pathlib import Path
from random import Random
import subprocess
import tempfile
import wave
from array import array

RATE = 32_000
ASSETS = Path(__file__).resolve().parents[1] / "assets" / "sounds"
SCORE = [
    (0.00, 52, 1.30, 0.53), (0.00, 64, 0.76, 0.50),
    (0.42, 65, 0.62, 0.40), (0.75, 71, 0.66, 0.44),
    (1.18, 67, 0.70, 0.48), (1.75, 76, 0.81, 0.57),
    (1.75, 47, 0.85, 0.45), (2.20, 74, 0.80, 0.46),
    (2.85, 65, 0.83, 0.48), (3.69, 64, 1.25, 0.54),
    (3.69, 52, 1.25, 0.51), (3.69, 71, 0.82, 0.27),
]

# Attack cues share no samples. The short transients are intentionally prominent on small speakers.
CUES = {
    "pipburst_tell": (0.81, [(0, 55, .16, .43), (.19, 62, .16, .38), (.36, 67, .23, .26)], .17, .28),
    "pipburst_pop": (.46, [(0, 37, .12, .54), (.035, 69, .07, .24), (.11, 77, .06, .16)], .51, .11),
    "pipburst_hurt": (.27, [(0, 49, .07, .33), (.04, 62, .08, .27)], .26, .08),
    "ovenback_tell": (1.03, [(0, 40, .33, .45), (.23, 47, .23, .37), (.53, 52, .17, .40)], .35, .41),
    "ovenback_crash": (.61, [(0, 40, .16, .67), (.04, 59, .13, .32), (.10, 42, .12, .20)], .54, .15),
    "ovenback_hurt": (.36, [(0, 37, .09, .47), (.06, 48, .10, .22)], .34, .12),
    "pepperwing_tell": (.83, [(0, 67, .19, .30), (.14, 69, .19, .33), (.38, 74, .17, .39)], .23, .25),
    "pepperwing_blast": (.56, [(0, 56, .12, .47), (.03, 71, .11, .29), (.09, 76, .19, .28)], .48, .12),
    "pepperwing_hurt": (.32, [(0, 76, .09, .33), (.04, 68, .08, .44)], .22, .11),
}


def render(name, duration, notes, noise, decay, melody=False):
    rng = Random(name)
    length = round(duration * RATE)
    out = [0.0] * length
    for start, key, sustain, amp in notes:
        offset = round(start * RATE)
        freq = 440 * 2 ** ((key - 69) / 12)
        for i in range(min(length - offset, round(4.7 * sustain * RATE))):
            t = i / RATE
            phase = freq * t * (1 + (0.02 * exp(-t * 8) if not melody else 0))
            env = min(1.0, t * 220) * exp(-t / sustain)
            tone = sin(2 * pi * phase) * .58
            tone += sin(2 * pi * 2.01 * phase) * .19 * exp(-t * 3.5)
            tone += sin(2 * pi * 3.07 * phase) * .14 * exp(-t * 6.2)
            tone += sin(2 * pi * 4.23 * phase) * .08 * exp(-t * 7.0)
            out[offset + i] += amp * env * tone
    dry = out.copy() if melody else None
    previous = 0.0
    gain = .92 / max(.7, max(abs(sample) for sample in out))
    for i in range(length):
        t = i / RATE
        previous = .72 * previous + rng.uniform(-.39, .39)
        out[i] += previous * noise * exp(-t / decay)
        if melody:
            for lag, echo in [(2336, .20), (4192, .12), (7904, .07)]:
                if i > lag:
                    out[i] += dry[i - lag] * echo
        out[i] *= gain * min(1.0, (duration - t) * 4.0)
    pcm = array("h", (round(32760 * min(.98, max(-.98, amp))) for amp in out))
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "cue.wav"
        with wave.open(str(wav), "wb") as stream:
            stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            stream.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-map_metadata", "-1",
                        "-c:a", "libvorbis", "-q:a", "4", str(ASSETS / (name + ".ogg"))], check=True)


if __name__ == "__main__":
    render("boss_bells_pelagros", 5.85, SCORE, .08, .22, melody=True)
    for cue, args in CUES.items():
        render(cue, *args)
