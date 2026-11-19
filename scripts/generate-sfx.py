#!/usr/bin/env python3
"""Generates 100% original, open-source procedural WAV sound effects & dungeon ambience
using only the Python standard library (zero external dependencies, deterministic seeds).
"""

import math
import pathlib
import random
import struct
import wave

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
AUDIO_DIR = REPO_ROOT / "game" / "assets" / "audio"
SAMPLE_RATE = 22050


def write_wav(name: str, samples: list[float]) -> None:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    path = AUDIO_DIR / f"{name}.wav"
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            frames.extend(struct.pack("<h", int(clamped * 32767)))
        wf.writeframes(bytes(frames))


def synth_sword_swing() -> list[float]:
    rng = random.Random(101)
    n = int(SAMPLE_RATE * 0.22)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / n)) ** 1.4
        noise = rng.uniform(-1.0, 1.0)
        alpha = 0.08 + 0.25 * (1.0 - i / n)
        lp = lp + alpha * (noise - lp)
        tone = 0.25 * math.sin(2 * math.pi * (420 - 240 * (i / n)) * t)
        out.append((lp * 0.85 + tone) * env * 0.7)
    return out


def synth_sword_hit() -> list[float]:
    rng = random.Random(102)
    n = int(SAMPLE_RATE * 0.18)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 24.0)
        clang = math.sin(2 * math.pi * 680 * t) * 0.45 + math.sin(2 * math.pi * 1120 * t) * 0.25
        thud = math.sin(2 * math.pi * (140 - 70 * (i / n)) * t) * 0.65
        noise = rng.uniform(-0.35, 0.35) * math.exp(-t * 45.0)
        out.append((clang + thud + noise) * env * 0.75)
    return out


def synth_shield_block() -> list[float]:
    n = int(SAMPLE_RATE * 0.24)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 16.0)
        ring = (
            0.5 * math.sin(2 * math.pi * 520 * t)
            + 0.35 * math.sin(2 * math.pi * 830 * t)
            + 0.25 * math.sin(2 * math.pi * 1390 * t)
        )
        out.append(ring * env * 0.7)
    return out


def synth_bow_release() -> list[float]:
    n = int(SAMPLE_RATE * 0.2)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 20.0)
        twang = math.sin(2 * math.pi * (260 + 180 * math.exp(-t * 22.0)) * t)
        out.append(twang * env * 0.65)
    return out


def synth_spell_fire() -> list[float]:
    rng = random.Random(105)
    n = int(SAMPLE_RATE * 0.32)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * min(1.0, i / (n * 0.25))) if i < n * 0.25 else math.exp(-(t - 0.08) * 10.0)
        lp = lp + 0.14 * (rng.uniform(-1.0, 1.0) - lp)
        whoosh = math.sin(2 * math.pi * (320 - 160 * (i / n)) * t) * 0.4
        out.append((lp * 0.9 + whoosh) * env * 0.7)
    return out


def synth_spell_heal() -> list[float]:
    n = int(SAMPLE_RATE * 0.45)
    out = []
    freqs = [523.25, 659.25, 783.99, 1046.5]
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / n)) ** 0.7
        val = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        shimmer = 0.7 + 0.3 * math.sin(2 * math.pi * 9.0 * t)
        out.append(val * env * shimmer * 0.55)
    return out


def synth_chest_open() -> list[float]:
    n = int(SAMPLE_RATE * 0.3)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 11.0)
        creak = math.sin(2 * math.pi * (190 + 90 * (i / n)) * t) * 0.5
        latch = math.sin(2 * math.pi * 920 * t) * math.exp(-t * 45.0) * 0.5
        out.append((creak + latch) * env * 0.65)
    return out


def synth_door_seal() -> list[float]:
    rng = random.Random(108)
    n = int(SAMPLE_RATE * 0.55)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 5.0)
        lp = lp + 0.05 * (rng.uniform(-1.0, 1.0) - lp)
        rumble = math.sin(2 * math.pi * (75 - 25 * (i / n)) * t) * 0.7
        out.append((rumble + lp * 0.8) * env * 0.8)
    return out


def synth_level_up() -> list[float]:
    n = int(SAMPLE_RATE * 0.65)
    notes = [(0.0, 440.0), (0.14, 554.37), (0.28, 659.25), (0.42, 880.0)]
    out = [0.0] * n
    for start, freq in notes:
        s_idx = int(start * SAMPLE_RATE)
        dur = int(0.24 * SAMPLE_RATE)
        for j in range(dur):
            if s_idx + j >= n:
                break
            t = j / SAMPLE_RATE
            env = math.exp(-t * 7.5)
            out[s_idx + j] += (0.55 * math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)) * env * 0.5
    return out


def synth_ai_chime() -> list[float]:
    n = int(SAMPLE_RATE * 0.28)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 880.0 if t < 0.11 else 1318.5
        env = math.exp(-((t if t < 0.11 else t - 0.11)) * 18.0)
        out.append(math.sin(2 * math.pi * freq * t) * env * 0.45)
    return out


def synth_collapse_rumble() -> list[float]:
    rng = random.Random(111)
    n = int(SAMPLE_RATE * 0.9)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / n)) ** 0.8
        lp = lp + 0.04 * (rng.uniform(-1.0, 1.0) - lp)
        sub = math.sin(2 * math.pi * (55 - 20 * (i / n)) * t) * 0.65
        out.append((sub + lp * 1.1) * env * 0.75)
    return out


def synth_dungeon_ambience() -> list[float]:
    rng = random.Random(112)
    n = int(SAMPLE_RATE * 4.0)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Smooth seamless loop envelope via periodic harmonics
        base = (
            0.35 * math.sin(2 * math.pi * 48.0 * t)
            + 0.2 * math.sin(2 * math.pi * 72.0 * t + 0.8)
            + 0.12 * math.sin(2 * math.pi * 96.0 * t)
        )
        lp = lp + 0.015 * (rng.uniform(-1.0, 1.0) - lp)
        mod = 0.75 + 0.25 * math.sin(2 * math.pi * 0.25 * t)
        out.append((base + lp * 0.6) * mod * 0.35)
    return out


def main() -> None:
    clips = {
        "sword_swing": synth_sword_swing(),
        "sword_hit": synth_sword_hit(),
        "shield_block": synth_shield_block(),
        "bow_release": synth_bow_release(),
        "spell_fire": synth_spell_fire(),
        "spell_heal": synth_spell_heal(),
        "chest_open": synth_chest_open(),
        "door_seal": synth_door_seal(),
        "level_up": synth_level_up(),
        "ai_chime": synth_ai_chime(),
        "collapse_rumble": synth_collapse_rumble(),
        "dungeon_ambience": synth_dungeon_ambience(),
    }
    for name, data in clips.items():
        write_wav(name, data)
    print(f"[generate-sfx] Generated {len(clips)} open-source procedural WAV clips in {AUDIO_DIR}")


if __name__ == "__main__":
    main()
