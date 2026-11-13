#!/usr/bin/env python3
"""Render lesser-known classical piano pieces from pinned, redistributable scores.
Requires NumPy, mido and LilyPond 2.24.x (with convert-ly alongside it).
Use --lilypond /path/to/lilypond when it is not on PATH. No modern recording or soundfont.
The rendered soundtrack is CC BY-SA 4.0; see Vendor/ClassicalMusic/README.md.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, tempfile, wave
import mido
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SCORES = ROOT / 'Vendor/ClassicalMusic'
p = argparse.ArgumentParser()
p.add_argument('--lilypond', default=shutil.which('lilypond'))
a = p.parse_args()
if not a.lilypond:
    p.error('Install LilyPond or pass --lilypond /path/to/lilypond')
lilypond = Path(a.lilypond).resolve()
convert = lilypond.with_name('convert-ly')
manifest = json.loads((SCORES / 'PROVENANCE.json').read_text())
rate = 22050
rng = np.random.default_rng(1874)
events = []
start = 1.5
with tempfile.TemporaryDirectory(prefix='novachess-scores-') as temporary:
    directory = Path(temporary)
    for piece in manifest['pieces']:
        source = SCORES / piece['file']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == piece['sha256'], source
        # Convert only a temporary copy; preserve the exact credited upstream edition.
        working = directory / piece['file']
        working.write_bytes(source.read_bytes())
        subprocess.run([str(convert), '-e', str(working)], check=True, capture_output=True)
        text = working.read_text()
        # Unfold written repeats for the performance, with no changes to notes or voices.
        text = text.replace('\\score {', '\\score { \\unfoldRepeats', 1)
        if '\\unfoldRepeats' not in text:
            import re
            text = re.sub(r'\\score\s*\{', lambda m: m[0] + ' \\unfoldRepeats ', text, count=1)
        working.write_text(text)
        stem = directory / working.stem
        result = subprocess.run([str(lilypond), '-dno-print-pages', '-o', str(stem), str(working)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        midi = mido.MidiFile(stem.with_suffix('.midi'))
        elapsed = 0.0
        active = {}
        tempo = mido.bpm2tempo(piece['quarter_bpm'])
        for message in mido.merge_tracks(midi.tracks):
            elapsed += mido.tick2second(message.time, midi.ticks_per_beat, tempo)
            if message.type not in ('note_on', 'note_off'):
                continue
            key = (message.channel, message.note)
            if message.type == 'note_on' and message.velocity:
                active.setdefault(key, []).append((elapsed, message.velocity))
            elif active.get(key):
                onset, velocity = active[key].pop(0)
                duration = max(.06, elapsed - onset)
                # Quiet dynamics, tiny timing variance, lower accompaniment kept restrained.
                volume = .036 * (.45 + .55 * velocity / 127) * (0.76 if message.note < 60 else 1)
                events.append((message.note, start + onset, duration, volume))
        print(f"{piece['composer']} · {piece['title']}: {elapsed:.1f} seconds")
        start += elapsed + 4

audio = np.zeros(int((start + 2) * rate), dtype=np.float64)
for pitch, onset, duration, volume in events:
    onset += rng.uniform(0, .009)
    size = int((duration + 1.7) * rate)
    times = np.arange(size) / rate
    frequency = 440 * 2 ** ((pitch - 69) / 12)
    tone = np.zeros(size)
    for harmonic, amplitude in enumerate([1, .29, .10, .035, .012], 1):
        phase = 2 * np.pi * frequency * harmonic * (1 + .000015 * harmonic ** 2) * times
        tone += amplitude * (np.sin(phase) + .12 * np.sin(phase * 1.0005)) * np.exp(-times * (.65 + harmonic * .25))
    envelope = np.minimum(1, times / .012) * np.exp(-np.maximum(0, times - duration) * 3)
    first = int(onset * rate)
    end = min(len(audio), first + size)
    audio[first:end] += tone[:end-first] * envelope[:end-first] * volume
for delay, level in [(.11, .09), (.23, .05), (.41, .025)]:
    offset = int(delay * rate)
    audio[offset:] += audio[:-offset].copy() * level
audio *= min(1, .65 / max(.0001, np.max(np.abs(audio))))
fade = int(rate * 1.5)
audio[-fade:] *= np.linspace(1, 0, fade)
output = ROOT / 'NovaChess/Resources/ClassicalPrelude.wav'
with wave.open(str(output), 'wb') as file:
    file.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    file.writeframes((np.clip(audio, -1, 1) * 32767).astype('<i2').tobytes())
print(f'New quiet-piano collection: {len(audio)/rate:.1f} seconds, {len(events)} notes')
