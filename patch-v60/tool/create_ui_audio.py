"""Original procedural UI sounds; no third-party recordings or licensing."""
from pathlib import Path
import math, random, struct, wave

root = Path(__file__).resolve().parents[1] / 'assets/audio'
rate = 44100
def save(name, samples):
    peak = max(abs(x) for x in samples) or 1
    with wave.open(str(root / name), 'wb') as out:
        out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        out.writeframes(b''.join(struct.pack('<h', int(x / peak * 24000)) for x in samples))

tap = []
for i in range(int(rate * .105)):
    t = i / rate
    envelope = min(1, t / .005) * math.exp(-t * 48)
    tap.append(envelope * (math.sin(2*math.pi*880*t) + .25*math.sin(2*math.pi*1320*t)))
save('ui_tap.wav', tap)

rng = random.Random(37)
applause = [0.] * int(rate * 2.7)
for person in range(9):
    for clap in range(8):
        start = int(rate * (.1 + clap * .25 + rng.uniform(0, .16)))
        level = rng.uniform(.3, .75)
        previous = 0
        for i in range(int(rate * .115)):
            t = i / rate
            noise = rng.uniform(-1, 1)
            burst = (noise - previous * .6) * math.exp(-t * 65) * level
            previous = noise
            if start + i < len(applause): applause[start+i] += burst
# Warm ascending celebration notes under the applause, no competing speech.
for onset, freq in [(.05, 523.25), (.22, 659.25), (.39, 783.99), (.57, 1046.5)]:
    for i in range(int(rate * .55)):
        t = i / rate
        at = int(onset * rate) + i
        applause[at] += .18 * min(1, t/.008) * math.exp(-t*7) * math.sin(2*math.pi*freq*t)
save('applause.wav', applause)
print('Created ui_tap.wav (105ms), applause.wav (2.7s).')
