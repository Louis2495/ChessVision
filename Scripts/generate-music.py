#!/usr/bin/env python3
"""Gentle new piano arrangements of public-domain Bach, Beethoven and Satie themes.
No modern recording, soundfont, engraving or MIDI performance is used.
Requires NumPy only. The generated recording is bundled for offline playback.
"""
from pathlib import Path
import numpy as np
import wave
rate = 22050
rng = np.random.default_rng(1827)
events = []
def note(pitch, start, beats, volume):
    events.append((pitch, start, beats, volume))
# Bach: Prelude in C major, BWV 846. A slower, softly pedaled opening section.
chords = [[60,64,67,72,76],[60,62,69,74,77],[59,62,67,74,77],[60,64,67,72,76],
          [60,64,69,76,81],[60,62,66,69,74],[59,62,67,74,79],[59,60,64,67,72],
          [57,60,64,67,72],[50,57,62,66,72],[55,59,62,67,71],[55,58,64,67,73],
          [53,57,62,65,69],[53,56,62,65,71],[52,55,60,64,67],[48,55,60,64,72]]
pattern = [0,1,2,3,4,2,3,4] * 2
for bar, chord in enumerate(chords):
    for i, index in enumerate(pattern):
        note(chord[index], bar*4+i*0.25, 1.1, 0.052*(0.92+0.08*np.sin(i)))
    if bar%2==0: note(chord[0]-12, bar*4, 3.5, 0.035)
start = 68.0
# Beethoven: Fur Elise, WoO 59. Original theme, relaxed timing and quiet accompaniment.
elise = [(76,.5),(75,.5),(76,.5),(75,.5),(76,.5),(71,.5),(74,.5),(72,.5),(69,1.5),
         (60,.5),(64,.5),(69,.5),(71,1.5),(64,.5),(68,.5),(71,.5),(72,1.5),
         (64,.5),(76,.5),(75,.5),(76,.5),(75,.5),(76,.5),(71,.5),(74,.5),(72,.5),(69,1.5),
         (60,.5),(64,.5),(69,.5),(71,1.5),(64,.5),(72,.5),(71,.5),(69,2),
         (71,.5),(72,.5),(74,.5),(76,1.5),(67,.5),(77,.5),(76,.5),(74,1.5),
         (65,.5),(76,.5),(74,.5),(72,1.5),(64,.5),(74,.5),(72,.5),(71,2)]
t = start; beat = .82
for repeat in range(2):
    begin=t
    for i,(pitch,length) in enumerate(elise):
        note(pitch,t,length*beat+0.12,0.067*(0.9+0.1*np.sin(i*.4)))
        t += length*beat
    for bar in range(int((t-begin)/(3*beat))+1):
        chord = [45,52,57] if bar%4 in (0,3) else [40,52,56] if bar%4==1 else [48,55,60]
        for j,pitch in enumerate(chord): note(pitch,begin+(3*bar+j)*beat,beat*1.8,0.026)
start = t+4
# Satie: Gymnopedie No. 1. Sustained melody and the characteristic gentle 3/4 pulse.
satie = [(78,1),(81,1),(79,1),(78,2),(73,1),(71,2),(73,1),(74,3),(69,3),(66,3),
         (64,1),(66,1),(67,1),(66,2),(64,1),(62,2),(64,1),(66,3),(61,3),(62,3)]
t = start; beat = 1.0
for repeat in range(2):
    begin=t
    for i,(pitch,length) in enumerate(satie):
        note(pitch,t,length*beat+0.4,0.055*(0.94+0.06*np.cos(i)))
        t += length*beat
    for bar in range(int((t-begin)/3)):
        root, upper = (43,[55,59,62,66]) if bar%2==0 else (50,[54,57,61,66])
        note(root,begin+bar*3,2.8,0.025)
        for pitch in upper: note(pitch,begin+bar*3+1,1.9,0.015)
for pitch in [38,50,54,57,62]: note(pitch,t,4,0.025)
audio = np.zeros(int((t+6)*rate),dtype=np.float64)
for pitch,start,duration,volume in events:
    start += rng.uniform(0,.012)
    size = int((duration+2)*rate); times = np.arange(size)/rate
    freq = 440*2**((pitch-69)/12)
    tone = np.zeros(size)
    for k,amp in enumerate([1,.34,.12,.045,.018],1):
        phase=2*np.pi*freq*k*(1+0.000015*k*k)*times
        tone += amp*(np.sin(phase)+.15*np.sin(phase*1.0005))*np.exp(-times*(.85+k*.3))
    envelope = np.minimum(1,times/.009)*np.exp(-np.maximum(0,times-duration)*2)
    first=int(start*rate); end=min(len(audio),first+size)
    audio[first:end] += tone[:end-first]*envelope[:end-first]*volume
for delay,level in [(.11,.10),(.23,.065),(.41,.03)]:
    offset=int(delay*rate); audio[offset:]+=audio[:-offset].copy()*level
audio *= min(1,.8/max(.0001,np.max(np.abs(audio))))
fade=int(rate*1.5);audio[-fade:]*=np.linspace(1,0,fade)
output=Path(__file__).resolve().parents[1]/'NovaChess/Resources/ClassicalPrelude.wav'
with wave.open(str(output),'wb') as file:
    file.setparams((1,2,rate,0,'NONE','not compressed'))
    file.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
print(f'Bach / Beethoven / Satie piano medley: {len(audio)/rate:.1f} seconds')
