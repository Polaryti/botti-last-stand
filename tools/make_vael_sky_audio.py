#!/usr/bin/env python3
"""Deterministic voices for the coastal flyers; NumPy/SciPy synthesis, Ogg via ffmpeg.
Only writes these fifteen clips. No source samples or external asset downloads required.
"""
from pathlib import Path
import subprocess
import tempfile
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io.wavfile import write
RATE = 24000
OUT = Path(__file__).resolve().parents[1] / 'assets/sounds'

def render(name, seconds, voice, seed):
    rng = np.random.default_rng(seed)
    t = np.arange(int(seconds * RATE)) / RATE
    x = voice(t, rng)
    x = np.tanh(x * 0.85)
    fade = np.minimum(t / 0.018, 1) * np.minimum((seconds - t) / 0.09, 1)
    x *= fade
    x *= 0.79 / max(0.01, np.max(np.abs(x)))
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / 'clip.wav'
        write(src, RATE, (x * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(src), '-c:a', 'libvorbis', '-q:a', '4', str(OUT / (name + '.ogg'))], check=True)

def noise(t, rng, low=300, high=4000):
    return sosfilt(butter(2, [low, high], btype='bandpass', fs=RATE, output='sos'), rng.normal(size=t.size))

def gull(t, rng, rate=1):
    # Rough, two-part seabird cry, with a throaty downward bend.
    f = 680 + 400 * np.exp(-t * 6) + 90 * np.sin(t * 37)
    phase = np.cumsum(f) * (2 * np.pi / RATE)
    return (np.sin(phase) + 0.3 * np.sin(phase * 2.01) + noise(t, rng) * 0.6) * np.exp(-t * rate) * (0.35 + 0.65 * np.sin(t * 10) ** 2)

def ray(t, rng, rate=2):
    # Low submarine resonance under rising electrical arcing.
    phase = 2 * np.pi * (95 * t + 100 * t * t)
    return (np.sin(phase) * 0.7 + np.sin(phase * 1.51) * 0.3 + noise(t, rng, 1100, 7000) * (0.15 + t * 0.7) * np.sin(t * 87) ** 8) * np.exp(-t * rate)

def bell(t, rng, fall=2):
    # Inharmonic bronze partials; the ghostly breath is quieter than the bell.
    return sum(np.sin(2*np.pi*f*t) * np.exp(-t*(fall+i*0.28)) / (1+i*0.6) for i,f in enumerate([196, 311, 419, 562, 839, 1117])) + noise(t,rng,200,2500)*np.exp(-t*3)*0.12

if __name__ == '__main__':
    for i, (id, voice) in enumerate([('wreck_gull',gull),('storm_ray',ray),('bell_wraith',bell)]):
        render(id+'_call', 1.4 if i==2 else 1.15, voice, 940+i)
        render(id+'_release', .55, lambda t,r,v=voice: v(t,r)*np.exp(-t*5)+noise(t,r)*np.exp(-t*12)*.6, 950+i)
        render(id+'_hurt', .38, lambda t,r,v=voice: v(t,r)*np.exp(-t*7), 960+i)
        render(id+'_death', 1.5, lambda t,r,v=voice: v(t,r)*np.exp(-t*2.2), 970+i)
    render('salt_splash', .65, lambda t,r: noise(t,r,300,6000)*np.exp(-t*9)+np.sin(2*np.pi*(240*t-100*t*t))*np.exp(-t*12)*.35, 980)
    render('brine_crack', .8, lambda t,r: noise(t,r,90,7500)*np.exp(-t*14)+np.sin(t*2*np.pi*62)*np.exp(-t*5)*.5, 981)
    render('knell_strike', 1.8, bell, 982)
    print('15 coastal flyer clips written')
