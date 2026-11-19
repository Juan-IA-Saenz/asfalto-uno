"""Regenera la música original sin bibliotecas externas."""
from array import array
from math import exp, pi, sin, tanh
from pathlib import Path
from random import Random
from wave import open as wave_open

RATE = 24_000
BEAT = 0.5
TAU = 2 * pi
HERE = Path(__file__).resolve().parent


def tone(hz, t):
    return sin(TAU * hz * t)


def midi(key):
    return 440 * 2 ** ((key - 69) / 12)


def write(name, seconds, synthesize):
    rng = Random(7441)
    frames = array("h")
    for i in range(round(seconds * RATE)):
        value = synthesize(i / RATE, rng.uniform(-1, 1))
        frames.append(round(32_000 * tanh(value)))
    with wave_open(str(HERE / name), "wb") as track:
        track.setparams((1, 2, RATE, len(frames), "NONE", "not compressed"))
        track.writeframes(frames.tobytes())


def tension(t, noise):
    pulse = int(t / BEAT)
    elapsed = t % BEAT
    unit = (t / BEAT) % 1
    fast = (t % (BEAT / 4))
    bar = pulse // 4
    root = [38, 38, 34, 41, 38, 38, 34, 36][bar]
    pattern = [0, 0, 12, 7, 0, 3, 12, 7]
    key = pattern[pulse % len(pattern)]
    low = midi(root)
    rim = (0.21 * tone(52, elapsed) + 0.32 * tone(68, elapsed) + noise * 0.08) * exp(-elapsed * 22)
    if pulse % 4 == 1 or pulse % 4 == 3:
        rim = (noise * 0.19 + tone(178, elapsed) * 0.10) * exp(-elapsed * 31)
    hat = noise * 0.071 * exp(-fast * (71 if unit < 0.5 else 121))
    bass = (tone(low, elapsed) * 0.27 + tone(low * 2, elapsed) * 0.093) * exp(-elapsed * 4.8)
    tick = (tone(midi(root + key + 24), elapsed) * 0.076 + tone(midi(root + key + 36), elapsed) * 0.036) * exp(-elapsed * 12)
    pad = (tone(midi(root + 19), t) * 0.052 + tone(midi(root + 27), t) * 0.048)
    pad *= 0.61 + tone(0.5, t) * 0.23
    edge = min(1, t * 70, (16 - t) * 70)
    return (hat + bass + rim + pad + tick) * min(1, elapsed * 170) * edge


def award(t, noise):
    result = 0.0
    for offset, key, level in [(0.0, 50, 0.4), (0.20, 57, 0.32), (0.36, 62, 0.28), (0.56, 66, 0.25), (0.64, 69, 0.23), (0.73, 74, 0.28)]:
        age = t - offset
        if age < 0:
            continue
        hz = midi(key)
        attack = min(1, age * 34)
        result += (0.65 * tone(hz, age) + 0.23 * tone(hz * 2, age) + 0.12 * tone(hz * 3, age)) * attack * exp(-age * 1.95) * level
    return (result + noise * 0.072 * exp(-t * 2.6)) * min(1, t * 45, (3.4 - t) * 6)


if __name__ == "__main__":
    write("tension.wav", 16, tension)
    write("premiacion.wav", 3.4, award)
