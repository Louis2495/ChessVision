#!/usr/bin/env python3
"""Original three-minute piano miniature in four contrasting sections.
No third-party composition or recording. Regeneration requires NumPy.
"""
from pathlib import Path
import numpy as np
import wave
rate = 22050
rng = np.random.default_rng(1987)
# Four phrases: C major, A minor, F major, then a varied return and cadence.
harmonies = [
 [[48,55,60,64], [47,55,59,62], [45,52,57,60], [43,55,59,62], [41,53,57,60], [50,57,62,65], [43,55,59,62], [48,55,60,64]],
 [[45,52,57,60], [52,59,64,68], [45,57,60,64], [43,55,58,62], [41,53,57,60], [50,57,62,65], [40,52,56,59], [45,52,57,60]],
 [[41,53,57,60], [48,55,60,64], [50,57,62,65], [46,53,58,62], [43,55,59,62], [48,55,60,64], [43,55,59,65], [48,55,60,64]],
]
melodies = [[76,79,77,74], [74,71,72,76], [72,76,79,76], [74,77,76,71], [69,72,77,76], [74,77,81,77], [79,77,74,71], [76,74,72,72]]
bar_lengths = [4 * (0.72 + 0.04*np.sin(i*0.43)) for i in range(64)]
starts = np.concatenate(([0], np.cumsum(bar_lengths)))
audio = np.zeros(int((starts[-1]+5)*rate), dtype=np.float64)
def note(midi, start, length, velocity):
    size = int((length+1.8)*rate)
    t = np.arange(size)/rate
    freq = 440 * 2**((midi-69)/12)
    tone = np.zeros(size)
    for k in range(1,7):
        # Slight string detuning and faster-decaying upper partials soften the timbre.
        phase = 2*np.pi*freq*k*t
        tone += (np.sin(phase)+0.25*np.sin(phase*1.0009))/(k**2.1) * np.exp(-t*(1.35+0.33*k))
    envelope = np.minimum(1,t/0.006) * np.exp(-np.maximum(0,t-length)*2.5)
    first = max(0, int(start*rate)); end = min(len(audio), first+size)
    audio[first:end] += tone[:end-first] * envelope[:end-first] * velocity
for bar in range(64):
    section, phrase = bar//16, bar%8
    chord = harmonies[[0,1,2,0][section]][phrase]
    beat = bar_lengths[bar]/4
    start = starts[bar]
    dynamic = 0.07 + 0.025*np.sin(np.pi*(bar%16)/16)
    note(chord[0], start, beat*2.2, dynamic*0.85)
    # Accompaniment changes between broken chords, waltz-like figures and sustained voicings.
    pattern = [1,2,3,2,1,3] if section in (0,3) else [1,3,2] if section == 1 else [1,2,3]
    for n, index in enumerate(pattern):
        when = start + (n+1)*beat*(3.2/len(pattern))
        note(chord[index], when, beat*(0.65 if section != 2 else 1.3), dynamic*0.56)
    melody = list(melodies[phrase])
    if section == 1: melody = [x-3 for x in melody]
    if section == 2: melody = [chord[1]+12, chord[2]+12, chord[3]+12, chord[2]+12]
    if bar%16 >= 8: melody = melody[1:]+melody[:1]
    if section == 3 and phrase in (2,4,6): melody = list(reversed(melody))
    for n, pitch in enumerate(melody):
        note(pitch, start+n*beat+rng.uniform(0,0.018), beat*(1.25 if n==3 else 0.85), dynamic*(1.0+0.10*np.sin(n+bar)))
# Quiet, resolved final chord and a natural tail before the loop returns.
for pitch in [48,55,60,64,72]: note(pitch, starts[-1], 3.5, 0.045)
for seconds, level in [(0.09,0.10),(0.21,0.065),(0.37,0.035)]:
    offset = int(seconds*rate); audio[offset:] += audio[:-offset].copy()*level
peak = max(1, np.max(np.abs(audio))/0.85)
audio /= peak
fade = int(rate*0.1); audio[:fade] *= np.linspace(0,1,fade)
tail = int(rate*1.5); audio[-tail:] *= np.linspace(1,0,tail)
output = Path(__file__).resolve().parents[1]/'NovaChess/Resources/ClassicalPrelude.wav'
with wave.open(str(output),'wb') as file:
    file.setparams((1,2,rate,0,'NONE','not compressed'))
    file.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
print(f'{output.name}: {len(audio)/rate:.1f} seconds')
