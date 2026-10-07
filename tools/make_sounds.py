#!/usr/bin/env python3
"""Synthesise every sound in the game into art/sounds/*.wav.

Nothing is recorded or downloaded: each sound is built from noise, sine waves and filters,
the way the art is built from code. Run it again after changing a recipe:

    python3 tools/make_sounds.py

Needs numpy only. Loops are filtered in the frequency domain, which wraps round the ends, so
they repeat without a seam. Output is 22,050 Hz mono 16-bit, with a fixed seed so the files
only change when a recipe does.
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "art" / "sounds"
rng = np.random.default_rng(7)


# --- building blocks ---------------------------------------------------------------------

def seconds(n: float) -> int:
    return int(round(n * SR))


def times(length: int) -> np.ndarray:
    return np.arange(length) / SR


def noise(length: int) -> np.ndarray:
    return rng.standard_normal(length)


def shape(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 4) -> np.ndarray:
    """Band-limit `x` with smooth high-pass (lo) and low-pass (hi) edges, circularly."""
    spectrum = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    gain = np.ones_like(f)
    if hi is not None:
        gain /= 1.0 + (f / hi) ** order
    if lo is not None:
        ratio = (f / lo) ** order
        gain *= ratio / (1.0 + ratio)
    return np.fft.irfft(spectrum * gain, len(x))


def one_shot(x: np.ndarray, lo: float | None = None, hi: float | None = None) -> np.ndarray:
    """Filter a one-shot without its tail wrapping round to the start."""
    pad = np.concatenate([x, np.zeros(seconds(0.5))])
    return shape(pad, lo, hi)[: len(x)]


def decay(length: int, attack: float, fall: float) -> np.ndarray:
    """Linear attack then exponential fall (time constant `fall` seconds)."""
    t = times(length)
    env = np.exp(-np.maximum(t - attack, 0.0) / fall)
    if attack > 0:
        env *= np.clip(t / attack, 0.0, 1.0)
    return env


def tone(freqs: list[float], length: int, falls: list[float], amps: list[float] | None = None) -> np.ndarray:
    t = times(length)
    out = np.zeros(length)
    amps = amps or [1.0] * len(freqs)
    for f, fall, a in zip(freqs, falls, amps):
        out += a * np.sin(2 * np.pi * f * t) * np.exp(-t / fall)
    return out


def glide(start: float, end: float, length: int, curve: float = 1.0) -> np.ndarray:
    """A sine sweeping from `start` to `end` Hz (phase integrated, so no clicks)."""
    k = np.linspace(0.0, 1.0, length) ** curve
    freq = start + (end - start) * k
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def at(length: int, clip: np.ndarray, start: float) -> np.ndarray:
    """`clip` placed `start` seconds into silence of `length` samples."""
    out = np.zeros(length)
    i = seconds(start)
    j = min(length, i + len(clip))
    if i < length:
        out[i:j] += clip[: j - i]
    return out


def swell(length: int, cycles: list[tuple[int, float]]) -> np.ndarray:
    """Slow amplitude movement that loops exactly: (whole cycles per loop, depth) pairs."""
    t = np.arange(length) / length
    env = np.ones(length)
    for count, depth in cycles:
        env *= 1.0 - depth * 0.5 * (1.0 + np.sin(2 * np.pi * count * t + rng.uniform(0, 6.28)))
    return env


def normalise(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    top = np.max(np.abs(x))
    return x * (peak / top) if top > 0 else x


def punch(x: np.ndarray, drive: float = 2.5) -> np.ndarray:
    """Soft-limit so the body of a loud sound is not dwarfed by its first crack."""
    x = normalise(x, 1.0)
    return np.tanh(drive * x) / np.tanh(drive)


def fade_edges(x: np.ndarray, ms: float = 4.0) -> np.ndarray:
    n = min(len(x) // 2, seconds(ms / 1000.0))
    ramp = np.linspace(0.0, 1.0, n)
    x = x.copy()
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def save(name: str, x: np.ndarray, peak: float = 0.9, loop: bool = False) -> None:
    x = normalise(x, peak)
    if not loop:
        x = fade_edges(x)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


# --- loops -------------------------------------------------------------------------------

def sea() -> np.ndarray:
    n = seconds(8)
    body = shape(noise(n), hi=420) * swell(n, [(1, 0.5), (3, 0.35)])
    wash = shape(noise(n), lo=700, hi=2600) * swell(n, [(2, 0.8), (5, 0.6)]) * 0.35
    return body + wash


def wind() -> np.ndarray:
    n = seconds(8)
    air = shape(noise(n), lo=250, hi=1400) * swell(n, [(1, 0.6), (3, 0.4)])
    howl = np.zeros(n)
    for centre, count in [(520, 2), (760, 3), (980, 5)]:
        howl += shape(noise(n), lo=centre * 0.94, hi=centre * 1.06, order=8) * swell(n, [(count, 0.9)])
    return air + 1.8 * howl


def rain() -> np.ndarray:
    n = seconds(6)
    hiss = shape(noise(n), lo=1800, hi=7000) * 0.5
    drops = np.zeros(n)
    blip = one_shot(noise(seconds(0.012)), lo=2500, hi=6000) * decay(seconds(0.012), 0.0, 0.003)
    for _ in range(1400):
        i = rng.integers(0, n - len(blip))
        drops[i : i + len(blip)] += blip * rng.uniform(0.3, 1.0)
    return hiss + drops


def bow_wash() -> np.ndarray:
    n = seconds(4)
    return shape(noise(n), lo=250, hi=2200) * swell(n, [(4, 0.7), (6, 0.4)])


def fire() -> np.ndarray:
    n = seconds(5)
    roar = shape(noise(n), hi=280) * 0.6
    crackle = np.zeros(n)
    pop = one_shot(noise(seconds(0.02)), lo=900, hi=5000) * decay(seconds(0.02), 0.0, 0.004)
    for _ in range(90):
        i = rng.integers(0, n - len(pop))
        crackle[i : i + len(pop)] += pop * rng.uniform(0.4, 1.4)
    return roar + crackle


def winch() -> np.ndarray:
    n = seconds(1.2)
    click = one_shot(noise(seconds(0.03)), lo=1200, hi=5000) * decay(seconds(0.03), 0.0, 0.006)
    clank = tone([380, 910], seconds(0.08), [0.02, 0.012])
    out = np.zeros(n)
    for k in range(6):
        out += at(n, click + at(len(click), clank, 0.0) * 0.6, k * 0.2)
    return out


# --- one-shots ---------------------------------------------------------------------------

def cannon() -> np.ndarray:
    n = seconds(2.6)
    boom = glide(95, 32, n, 0.4) * decay(n, 0.004, 0.45)
    blast = one_shot(noise(n), hi=700) * decay(n, 0.002, 0.7)
    crack = at(n, one_shot(noise(seconds(0.05)), lo=900, hi=5000) * decay(seconds(0.05), 0.0, 0.012), 0.0)
    return punch(1.2 * boom + 0.9 * blast + 0.5 * crack)


def splash() -> np.ndarray:
    n = seconds(1.3)
    hit = one_shot(noise(n), lo=350, hi=3800) * decay(n, 0.006, 0.18)
    tail = one_shot(noise(n), lo=200, hi=1500) * decay(n, 0.05, 0.45) * swell(n, [(9, 0.6)])
    return punch(hit + 0.5 * tail, 2.0)


def hull_hit() -> np.ndarray:
    n = seconds(0.9)
    crack = at(n, one_shot(noise(seconds(0.06)), lo=900, hi=5500) * decay(seconds(0.06), 0.0, 0.015), 0.0)
    wood = tone([170, 290, 470, 690], n, [0.12, 0.08, 0.05, 0.03], [1.0, 0.7, 0.5, 0.3])
    rattle = np.zeros(n)
    for _ in range(7):
        bit = one_shot(noise(seconds(0.015)), lo=1500, hi=5000) * decay(seconds(0.015), 0.0, 0.004)
        rattle += at(n, bit, rng.uniform(0.05, 0.4)) * rng.uniform(0.3, 0.8)
    return punch(0.8 * crack + wood + 0.5 * rattle, 2.0)


def thunder(close: bool) -> np.ndarray:
    n = seconds(5.5)
    rumble = one_shot(noise(n), hi=130 if close else 100) * decay(n, 0.15 if close else 0.6, 1.6)
    rolls = shape(noise(n), hi=3)
    rumble *= 0.5 + 0.5 * np.abs(rolls) / np.max(np.abs(rolls))
    if not close:
        return rumble
    crack = one_shot(noise(n), lo=600, hi=6000) * decay(n, 0.0, 0.09)
    rumble = normalise(rumble, 1.0)
    crack = normalise(crack, 1.0)
    return punch(rumble + 0.45 * crack, 3.0)


def swing() -> np.ndarray:
    n = seconds(0.34)
    t = np.linspace(0.0, 1.0, n)
    return one_shot(noise(n), lo=500, hi=2800) * np.sin(np.pi * t) ** 3


def clang() -> np.ndarray:
    n = seconds(0.7)
    ring = tone([620, 1430, 2350, 3310], n, [0.25, 0.15, 0.1, 0.06], [1.0, 0.6, 0.4, 0.25])
    tick = one_shot(noise(n), lo=2000, hi=7000) * decay(n, 0.0, 0.01)
    return ring + 0.6 * tick


def pistol() -> np.ndarray:
    n = seconds(1.0)
    crack = one_shot(noise(n), lo=400, hi=7000) * decay(n, 0.0, 0.02)
    body = one_shot(noise(n), hi=700) * decay(n, 0.002, 0.12)
    shot = normalise(crack, 1.0) * 0.6 + normalise(body, 1.0)
    return punch(shot + 0.3 * at(n, shot, 0.24), 3.0)


def step_wood() -> np.ndarray:
    n = seconds(0.16)
    return tone([115, 230], n, [0.04, 0.025]) + 0.3 * one_shot(noise(n), hi=900) * decay(n, 0.0, 0.02)


def step_sand() -> np.ndarray:
    n = seconds(0.2)
    return one_shot(noise(n), lo=900, hi=6000) * decay(n, 0.01, 0.04)


def dig() -> np.ndarray:
    n = seconds(0.55)
    crunch = one_shot(noise(n), lo=400, hi=4000) * decay(n, 0.01, 0.08)
    scrape = one_shot(noise(n), lo=1500, hi=5000) * decay(n, 0.12, 0.12) * 0.4
    return crunch + scrape


def hammer() -> np.ndarray:
    n = seconds(0.3)
    knock = tone([380, 870, 1500], n, [0.05, 0.03, 0.015], [1.0, 0.6, 0.3])
    tick = one_shot(noise(n), lo=1500, hi=6000) * decay(n, 0.0, 0.006)
    return knock + 0.7 * tick


def coins() -> np.ndarray:
    n = seconds(1.0)
    out = np.zeros(n)
    for k in range(7):
        base = rng.uniform(2400, 3600)
        ting = tone([base, base * 1.48, base * 2.1], seconds(0.3), [0.08, 0.05, 0.03], [1.0, 0.5, 0.3])
        out += at(n, ting, 0.03 + k * rng.uniform(0.05, 0.11)) * rng.uniform(0.4, 1.0)
    return out


def bell() -> np.ndarray:
    n = seconds(2.8)
    base = 440.0
    ratios = [0.5, 1.0, 1.19, 1.5, 2.0, 2.74]
    return tone([base * r for r in ratios], n, [1.4, 1.1, 0.8, 0.6, 0.5, 0.3], [0.5, 1.0, 0.5, 0.4, 0.35, 0.2])


def gull() -> np.ndarray:
    n = seconds(1.1)
    out = np.zeros(n)
    for start in (0.0, 0.42):
        m = seconds(0.32)
        t = times(m)
        freq = 1700 - 900 * (t / t[-1]) ** 0.7 + 60 * np.sin(2 * np.pi * 28 * t)
        call = np.sin(2 * np.pi * np.cumsum(freq) / SR)
        call += 0.4 * np.sin(2 * np.pi * np.cumsum(freq * 2) / SR)
        call *= np.sin(np.pi * t / t[-1]) ** 0.8
        out += at(n, call, start)
    return out


def rattle() -> np.ndarray:
    n = seconds(0.45)
    out = np.zeros(n)
    for _ in range(8):
        tock = tone([rng.uniform(900, 1600)], seconds(0.04), [0.008])
        out += at(n, tock, rng.uniform(0.0, 0.35)) * rng.uniform(0.4, 1.0)
    return out


def thud() -> np.ndarray:
    n = seconds(0.32)
    return tone([85, 160], n, [0.07, 0.04]) + 0.4 * one_shot(noise(n), hi=500) * decay(n, 0.0, 0.03)


def chomp() -> np.ndarray:
    n = seconds(0.3)
    bite = one_shot(noise(seconds(0.07)), lo=500, hi=3200) * decay(seconds(0.07), 0.005, 0.02)
    return at(n, bite, 0.0) + 0.8 * at(n, bite, 0.14)


def sail_flap() -> np.ndarray:
    n = seconds(0.7)
    t = times(n)
    beats = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 11 * t))
    return one_shot(noise(n), lo=120, hi=1300) * decay(n, 0.02, 0.18) * (0.4 + 0.6 * beats)


def spout() -> np.ndarray:
    n = seconds(1.6)
    t = np.linspace(0.0, 1.0, n)
    return one_shot(noise(n), lo=300, hi=3000) * np.sin(np.pi * t) ** 1.5


def creak() -> np.ndarray:
    n = seconds(1.1)
    t = times(n)
    jitter = shape(noise(n), hi=15)
    freq = 95 + 45 * np.sin(2 * np.pi * 0.6 * t) + 8 * jitter / np.max(np.abs(jitter))
    phase = np.cumsum(freq) / SR
    saw = 2.0 * (phase % 1.0) - 1.0
    return one_shot(saw, lo=300, hi=1800) * np.sin(np.pi * t / t[-1]) ** 2


def click() -> np.ndarray:
    n = seconds(0.06)
    return tone([1800], n, [0.01])


# --- music -------------------------------------------------------------------------------

# "What Shall We Do with a Drunken Sailor" (traditional, public domain), in D dorian.
NOTE = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def freq(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave - 4)) / 12)


TUNE = [
    # What shall we do with a drun-ken sai-lor (x3), ear-ly in the mor-ning
    ("A4", 1), ("A4", .5), ("A4", .5), ("A4", 1), ("A4", .5), ("A4", .5), ("A4", 1), ("D4", 1), ("F4", 1), ("A4", 1),
    ("G4", 1), ("G4", .5), ("G4", .5), ("G4", 1), ("G4", .5), ("G4", .5), ("G4", 1), ("C4", 1), ("E4", 1), ("G4", 1),
    ("A4", 1), ("A4", .5), ("A4", .5), ("A4", 1), ("A4", .5), ("A4", .5), ("A4", 1), ("B4", 1), ("C5", 1), ("D5", 1),
    ("C5", 1), ("A4", 1), ("G4", 1), ("E4", 1), ("D4", 2), ("D4", 2),
]
CHORDS = ["D", "D", "C", "C", "D", "D", "C", "D"]  # one per bar of four beats
BEAT = 0.36


def accordion(f: float, length: int) -> np.ndarray:
    t = times(length)
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
    reed = np.zeros(length)
    for detune in (0.997, 1.0, 1.004):
        phase = np.cumsum(np.full(length, f * detune) * vib) / SR
        reed += 2.0 * (phase % 1.0) - 1.0
    env = np.minimum(1.0, t / 0.03) * np.minimum(1.0, (t[-1] - t) / 0.05 + 0.01)
    return reed * env


def shanty() -> np.ndarray:
    beats = sum(b for _, b in TUNE)
    n = seconds(beats * BEAT)
    melody = np.zeros(n)
    t0 = 0.0
    for note, b in TUNE:
        clip = accordion(freq(note), seconds(b * BEAT * 0.92))
        melody += at(n, clip, t0)
        t0 += b * BEAT
    melody = one_shot(melody, lo=180, hi=2600)
    bass = np.zeros(n)
    chord_tones = {"D": ("D3", "A3"), "C": ("C3", "G3")}
    for bar, chord in enumerate(CHORDS):
        root, fifth = chord_tones[chord]
        for beat in range(4):
            start = (bar * 4 + beat) * BEAT
            pitch = freq(root if beat % 2 == 0 else fifth) / 2
            pluck = tone([pitch, pitch * 2], seconds(BEAT * 0.9), [0.18, 0.08], [1.0, 0.4])
            bass += at(n, pluck, start)
    drum = np.zeros(n)
    for beat in range(int(beats)):
        hit = thud() if beat % 2 == 0 else 0.5 * step_sand()
        drum += at(n, hit, beat * BEAT)
    return 0.5 * melody + 0.6 * bass + 0.35 * drum


# -----------------------------------------------------------------------------------------

LOOPS = {"sea": sea, "wind": wind, "rain": rain, "bow_wash": bow_wash, "fire": fire, "winch": winch}
SHOTS = {
    "cannon": cannon, "splash": splash, "hull_hit": hull_hit,
    "thunder": lambda: thunder(True), "thunder_far": lambda: thunder(False),
    "swing": swing, "clang": clang, "pistol": pistol, "step_wood": step_wood, "step_sand": step_sand,
    "dig": dig, "hammer": hammer, "coins": coins, "bell": bell, "gull": gull, "rattle": rattle,
    "thud": thud, "chomp": chomp, "sail_flap": sail_flap, "spout": spout, "creak": creak,
    "click": click,
}


def main() -> None:
    for name, make in LOOPS.items():
        save(name, make(), peak=0.8, loop=True)
    for name, make in SHOTS.items():
        save(name, make())
    save("shanty", shanty(), peak=0.8, loop=True)
    sizes = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"wrote {len(LOOPS) + len(SHOTS) + 1} sounds to {OUT} ({sizes / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
