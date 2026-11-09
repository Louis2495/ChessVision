#!/usr/bin/env python3
"""Original classical-style arpeggiated piano prelude; no third-party score or recording.
Optional regeneration requires NumPy; the finished WAV is bundled for Xcode.
"""
from pathlib import Path
import numpy as np
import wave
rate=22050; beat=.23
chords=[[48,60,64,67,72],[45,60,64,69,72],[50,62,65,69,74],[43,59,62,67,71],[48,60,64,67,72],[41,57,60,65,69],[43,55,59,62,67],[48,55,60,64,72]]
pattern=[0,1,2,3,4,2,3,4,0,1,2,3,4,2,3,4]
audio=np.zeros(int(rate*(beat*16*len(chords)*2+3)))
for repeat in range(2):
 for bar,chord in enumerate(chords):
  for step,index in enumerate(pattern):
   start=int(((repeat*len(chords)+bar)*16+step)*beat*rate)
   t=np.arange(int(rate*2.3))/rate; freq=440*2**((chord[index]-69)/12)
   tone=sum(np.sin(2*np.pi*freq*k*t)*np.exp(-t*(1.6+k*.3))/k**2 for k in range(1,5))
   tone*=np.minimum(1,t/.008)*.12; audio[start:start+len(tone)]+=tone
output=Path(__file__).resolve().parents[1]/'ChessVision/Resources/ClassicalPrelude.wav'
with wave.open(str(output),'wb') as file:
 file.setparams((1,2,rate,0,'NONE','not compressed'))
 file.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
print(output)
