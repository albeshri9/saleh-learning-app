"""Original gentle tap: no harsh high harmonics, 8ms attack, clean fade."""
import math
import struct
import wave
from pathlib import Path

rate = 44100
duration = .085
samples = []
for i in range(round(rate * duration)):
    t = i / rate
    attack = min(1, t / .008)
    tail = (1 - t / duration) ** 2
    phase = 2 * math.pi * (470 * t - 650 * t * t)
    value = .19 * attack * tail * (math.sin(phase) + .12 * math.sin(phase * 2))
    samples.append(round(value * 32767))
path = Path(__file__).resolve().parents[1] / 'assets/audio/ui_tap_soft_v41.wav'
with wave.open(str(path), 'wb') as out:
    out.setparams((1, 2, rate, len(samples), 'NONE', 'not compressed'))
    out.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print(path)
