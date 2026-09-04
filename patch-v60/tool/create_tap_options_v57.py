"""Create five original, single-shot UI tap previews for v57 selection."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 44_100
OUTPUT = Path(__file__).resolve().parents[3] / "outputs" / "tap-options-v57"


def envelope(t: float, duration: float, attack: float, decay: float) -> float:
    fade_in = min(1.0, t / attack)
    fade_out = min(1.0, max(0.0, (duration - t) / 0.012))
    return fade_in * math.exp(-t * decay) * fade_out


def save(name: str, samples: list[float]) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    peak = max(abs(value) for value in samples) or 1.0
    scale = 19_500 / peak
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(
            b"".join(struct.pack("<h", int(value * scale)) for value in samples)
        )


def soft_wood() -> list[float]:
    duration = 0.085
    rng = random.Random(57)
    result = []
    previous = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        warm_noise = 0.18 * (noise + previous) * math.exp(-t * 115)
        previous = noise
        tone = math.sin(2 * math.pi * 520 * t) + 0.32 * math.sin(
            2 * math.pi * 780 * t
        )
        result.append(envelope(t, duration, 0.0025, 48) * tone + warm_noise)
    return result


def bubble_pop() -> list[float]:
    duration = 0.095
    result = []
    phase = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        frequency = 620 + 760 * (t / duration) ** 1.35
        phase += 2 * math.pi * frequency / RATE
        result.append(envelope(t, duration, 0.003, 35) * math.sin(phase))
    return result


def crystal_tick() -> list[float]:
    duration = 0.12
    result = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        tone = math.sin(2 * math.pi * 1320 * t) + 0.24 * math.sin(
            2 * math.pi * 1980 * t
        )
        result.append(envelope(t, duration, 0.002, 30) * tone)
    return result


def rubber_touch() -> list[float]:
    duration = 0.105
    result = []
    phase = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        frequency = 760 - 330 * (t / duration)
        phase += 2 * math.pi * frequency / RATE
        tone = math.sin(phase) + 0.18 * math.sin(2 * phase)
        result.append(envelope(t, duration, 0.003, 38) * tone)
    return result


def gentle_digital() -> list[float]:
    duration = 0.13
    result = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        first = math.sin(2 * math.pi * 720 * t)
        second_t = max(0.0, t - 0.024)
        second = (
            0.38
            * math.sin(2 * math.pi * 900 * second_t)
            * math.exp(-second_t * 42)
            if t >= 0.024
            else 0.0
        )
        result.append(envelope(t, duration, 0.0025, 34) * first + second)
    return result


if __name__ == "__main__":
    choices = {
        "tap-1-soft-wood.wav": soft_wood(),
        "tap-2-bubble-pop.wav": bubble_pop(),
        "tap-3-crystal-tick.wav": crystal_tick(),
        "tap-4-rubber-touch.wav": rubber_touch(),
        "tap-5-gentle-digital.wav": gentle_digital(),
    }
    for filename, samples in choices.items():
        save(filename, samples)
    print(f"Created {len(choices)} tap previews in {OUTPUT}")
