"""Compone las pistas regionales y mezcla versos originales sintetizados con Piper."""
from array import array
from math import exp, floor, pi, sin, tanh
from pathlib import Path
from random import Random
from subprocess import run
from sys import argv, executable
from tempfile import TemporaryDirectory
from wave import open as wav

RATE = 24_000
TAU = 2 * pi
HERE = Path(__file__).resolve().parent
CITY = (
    ("santiago", 92, "es_MX-ald-medium", (38, 41, 36, 43),
     (0, 0.75, 1.5, 2.5, 3.25), (0, 3, 7, 10, 12), "quena",
     ("Bajo los Andes, rebota el balón.", "Cae la tarde, se enciende el tablón.",
      "La pobla en la reja, sonando el bombo.", "Santiago en la cancha, marcando el fondo.")),
    ("mexico", 96, "es_MX-claude-high", (43, 39, 46, 41),
     (0, 0.5, 1.75, 2.5, 3.5), (0, 7, 12, 15, 10), "fuelle",
     ("Desde la cuadra, el barrio prendido.", "Bota la bola, contesta el sonido.",
      "Cumbia en el muro, grafiti y calor.", "Ciudad de México, puro corazón.")),
    ("nueva_york", 88, "en_US-joe-medium", (41, 37, 44, 39),
     (0, 0.75, 2, 2.75, 3.5), (0, 10, 7, 3, 12), "keys",
     ("Concrete court, hear the train roll by.", "One on one underneath that skyline.",
      "Backboard ringing on the Lower East Side.", "Cage lights on, let the whole block ride.")),
)


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def tone(freq, t):
    return sin(TAU * freq * t)


def drum(kind, t, noise):
    if kind == "kick":
        return (sin(TAU * (49 * t + 1.8 * (1 - exp(-34 * t)))) * 0.81 + noise * 0.15 * exp(-240 * t)) * exp(-19 * t)
    if kind == "snare":
        return (0.61 * noise + 0.34 * tone(182, t) * exp(-38 * t)) * exp(-28 * t)
    if kind == "wood":
        return (0.67 * tone(655, t) + 0.32 * tone(948, t) + 0.28 * noise) * exp(-47 * t)
    return noise * (0.7 + 0.26 * tone(8175, t)) * exp(-(98 if kind == "hat" else 37) * t)


def lead(kind, f, t, noise):
    fundamental = tone(f, t)
    if kind == "quena":
        return (fundamental + 0.16 * tone(f * 2, t) + noise * 0.11) * (0.84 + tone(5.6, t) * 0.16) * min(1, t * 41) * exp(-5 * t)
    if kind == "fuelle":
        reed = sum(tone(f * harmonic, t) / harmonic for harmonic in (1, 2, 3, 4, 5))
        return (reed * 0.75 + 0.23 * tone(f * 1.006, t)) * min(1, t * 82) * exp(-6 * t)
    return (fundamental + 0.21 * tone(f * 2.005, t) + 0.11 * tone(f * 4.013, t) * exp(-14 * t)) * exp(-7 * t)


def beat_track(city, beat, roots, hits, melody, instrument):
    mix = [0.0] * round(32 * beat * RATE)
    rng = Random(5401 + city)

    def stamp(position, duration, level, voice):
        offset = round(position * beat * RATE)
        length = round(duration * RATE)
        for i in range(min(length, len(mix) - offset)):
            age = i / RATE
            edge = min(1, i / 30, (length - i) / 175)
            mix[offset + i] += voice(age, rng.uniform(-1, 1)) * level * edge

    def percussion(position, kind, level, duration):
        stamp(position, duration, level, lambda age, noise: drum(kind, age, noise))

    for bar in range(8):
        start = bar * 4
        root = roots[bar % len(roots)]
        for k in ((0, 1.75, 2.5) if city != 1 else (0, 1.5, 2, 3.5)):
            percussion(start + k, "kick", 0.44, 0.26)
        for k in (1, 3):
            percussion(start + k + (0.024 if city == 2 else 0), "snare", 0.34, 0.22)
        for k in range(8):
            swing = (0.075 if city in (0, 2) else 0.0) if k % 2 else 0.0
            percussion(start + k / 2 + swing, "shaker" if city == 1 else "hat", 0.095 if k % 2 else 0.060, 0.12)
        if city == 1:
            for k in (0.75, 1.25, 2.75, 3.25):
                percussion(start + k, "wood", 0.18, 0.12)
        for k, step in ((0, 0), (1.5 if city == 1 else 2, 7), (2.5 if city == 1 else 2.75, 0), (3.5, 12)):
            freq = hz(root + step)
            stamp(start + k, 0.68 * beat, 0.25, lambda t, _: (tone(freq, t) + 0.28 * tone(freq * 2, t)) * exp(-3.8 * t))
        for i, k in enumerate(hits):
            note = root + 24 + melody[(i + 2 * (bar % 2)) % len(melody)]
            freq = hz(note)
            volume = 0.052 if bar in (1, 2, 5, 6) else 0.11
            stamp(start + k, 0.70 * beat, volume, lambda t, n: lead(instrument, freq, t, n))
            if city != 1:
                stamp(start + k + 0.375, 0.49 * beat, volume * 0.24, lambda t, n: lead(instrument, freq, t, n))
        if city == 2:
            stamp(start + 0.25, 2 * beat, 0.042, lambda t, _: sum(tone(hz(root + k), t) for k in (12, 15, 22)) * exp(-5 * t))
    return mix


def piper(model, phrase, scratch, speed):
    run([executable, "-m", "piper", "-m", str(model), "-f", str(scratch),
         "--length-scale", str(speed), "--sentence-silence", "0"], input=phrase, text=True, check=True)
    with wav(str(scratch), "rb") as voice:
        source_rate = voice.getframerate()
        values = array("h", voice.readframes(voice.getnframes()))
    first = next(i for i, sample in enumerate(values) if abs(sample) > 420)
    last = len(values) - next(i for i, sample in enumerate(reversed(values)) if abs(sample) > 420)
    return values[max(0, first - source_rate // 50): last + source_rate // 25], source_rate


def dub(mix, offset, length, values, source_rate, level, echo=0.16):
    increment = max(source_rate / RATE, (len(values) - 1) / length)
    count = floor((len(values) - 1) / increment)
    low = smooth = 0.0
    delay = round(echo * RATE)
    for i in range(count):
        sample = i * increment
        index = int(sample)
        value = (values[index] + (sample - index) * (values[index + 1] - values[index])) / 32768
        low += 0.026 * (value - low)
        smooth += 0.64 * (value - low - smooth)
        voiced = tanh(smooth * 1.85) * level * min(1, i / 150, (count - i) / 500)
        if offset + i < len(mix):
            mix[offset + i] += voiced
        if offset + i + delay < len(mix):
            mix[offset + i + delay] += voiced * 0.20


def write(name, samples):
    scale = 1 / max(1.0, max(map(abs, samples)) * 1.38)
    frames = array("h", (round(32000 * tanh(value * scale)) for value in samples))
    with wav(str(HERE / name), "wb") as track:
        track.setparams((1, 2, RATE, len(frames), "NONE", "not compressed"))
        track.writeframes(frames.tobytes())


def crowd(models, scratch):
    length = 1.65
    mix = [0.0] * round(length * RATE)
    for name, phrase, starter, level, stretch in [
        ("es_MX-ald-medium", "¡Vamos!", 0.06, 0.20, 0.87),
        ("es_MX-claude-high", "¡Oh!", 0.00, 0.24, 1.16),
        ("en_US-joe-medium", "Woo!", 0.14, 0.19, 0.93),
    ]:
        v, rate = piper(models / (name + ".onnx"), phrase, scratch, stretch)
        for delta in (0, 0.14):
            dub(mix, round((starter + delta) * RATE), round(1.15 * RATE), v, rate, level * (1 if delta == 0 else 0.38), 0.07)
    rng = Random(2905)
    for _ in range(31):
        at = round(rng.uniform(0, 1.46) * RATE)
        decay = rng.uniform(91, 174)
        weight = rng.uniform(0.055, 0.18) * (1 - at / len(mix))
        for i in range(min(1100, len(mix) - at)):
            t = i / RATE
            mix[at + i] += (rng.uniform(-1, 1) + 0.28 * tone(207, t)) * exp(-t * decay) * weight
    write("tribuna.wav", mix)


if __name__ == "__main__":
    models = Path(argv[1])
    with TemporaryDirectory(prefix="asfalto-voz-") as work:
        scratch = Path(work) / "verse.wav"
        for city, (name, bpm, model, roots, hits, melody, lead_kind, lyrics) in enumerate(CITY):
            beat = 60 / bpm
            mix = beat_track(city, beat, roots, hits, melody, lead_kind)
            for bar, phrase in zip((1, 2, 5, 6), lyrics):
                take, rate = piper(models / (model + ".onnx"), phrase, scratch, 0.89)
                dub(mix, round((bar * 4 + 0.09) * beat * RATE), round(3.8 * beat * RATE), take, rate, 0.51)
            write("rap_" + name + ".wav", mix)
        crowd(models, scratch)
