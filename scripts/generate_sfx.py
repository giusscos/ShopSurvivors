#!/usr/bin/env python3
"""Generate short retro SFX wavs for Shop Survivors."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "ShopSurvivors" / "Resources"
SAMPLE_RATE = 22050


def write_wav(name: str, samples: list[float], volume: float = 0.55) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    path = ROOT / f"{name}.wav"
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * volume))
            frames += struct.pack("<h", int(v * 32767))
        wf.writeframes(frames)
    print("wrote", path)


def silence(seconds: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * seconds)


def tone(freq: float, seconds: float, wave_fn=math.sin, decay: float = 0.0) -> list[float]:
    n = int(SAMPLE_RATE * seconds)
    out: list[float] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-decay * t) if decay > 0 else 1.0
        # Mild attack to avoid clicks
        attack = min(1.0, i / (SAMPLE_RATE * 0.008))
        out.append(wave_fn(2 * math.pi * freq * t) * env * attack)
    return out


def square(freq: float, seconds: float, decay: float = 0.0) -> list[float]:
    return tone(freq, seconds, wave_fn=lambda x: 1.0 if math.sin(x) >= 0 else -1.0, decay=decay)


def noise_burst(seconds: float, decay: float = 12.0) -> list[float]:
    n = int(SAMPLE_RATE * seconds)
    out: list[float] = []
    # Deterministic pseudo-noise
    state = 1
    for i in range(n):
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        raw = (state / 0x7FFFFFFF) * 2.0 - 1.0
        t = i / SAMPLE_RATE
        env = math.exp(-decay * t)
        out.append(raw * env)
    return out


def chirp(f0: float, f1: float, seconds: float, decay: float = 4.0) -> list[float]:
    n = int(SAMPLE_RATE * seconds)
    out: list[float] = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        frac = t / seconds if seconds > 0 else 0
        freq = f0 + (f1 - f0) * frac
        phase += 2 * math.pi * freq / SAMPLE_RATE
        env = math.exp(-decay * t)
        out.append(math.sin(phase) * env)
    return out


def mix(*parts: list[float]) -> list[float]:
    length = max((len(p) for p in parts), default=0)
    out = [0.0] * length
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def concat(*parts: list[float]) -> list[float]:
    out: list[float] = []
    for p in parts:
        out.extend(p)
    return out


def main() -> None:
    write_wav("sfx_hit", mix(square(420, 0.05, decay=18), noise_burst(0.04, decay=40)), volume=0.4)
    write_wav("sfx_defeat", concat(chirp(520, 180, 0.18, decay=6), square(140, 0.08, decay=20)), volume=0.5)
    write_wav("sfx_shove", mix(noise_burst(0.08, decay=22), square(90, 0.06, decay=25)), volume=0.45)
    write_wav("sfx_xp", concat(square(660, 0.05, decay=10), square(990, 0.08, decay=8)), volume=0.4)
    write_wav("sfx_coupon", chirp(280, 640, 0.16, decay=5), volume=0.45)
    write_wav("sfx_pitch", square(310, 0.07, decay=14), volume=0.35)
    write_wav(
        "sfx_levelup",
        concat(square(440, 0.07, decay=8), square(554, 0.07, decay=8), square(659, 0.12, decay=6)),
        volume=0.5,
    )
    write_wav(
        "sfx_win",
        concat(square(523, 0.1, decay=5), square(659, 0.1, decay=5), square(784, 0.18, decay=4)),
        volume=0.5,
    )
    write_wav("sfx_lose", concat(chirp(300, 90, 0.28, decay=3), square(70, 0.15, decay=8)), volume=0.5)
    write_wav("sfx_ui", square(700, 0.035, decay=30), volume=0.3)
    write_wav("sfx_door", concat(noise_burst(0.06, decay=18), square(180, 0.1, decay=10)), volume=0.45)

    # Distinct short "voice" blips per clerk type
    write_wav("sfx_clerk_pitcher", concat(square(380, 0.05, decay=12), square(460, 0.06, decay=10)), volume=0.4)
    write_wav("sfx_clerk_closer", concat(square(220, 0.08, decay=8), square(180, 0.1, decay=8)), volume=0.42)
    write_wav("sfx_clerk_sprinter", chirp(500, 900, 0.1, decay=8), volume=0.38)
    write_wav(
        "sfx_clerk_upseller",
        concat(square(340, 0.05, decay=10), square(420, 0.05, decay=10), square(500, 0.07, decay=8)),
        volume=0.4,
    )

    # Friendly shopping-chatter blip for the companion
    write_wav(
        "sfx_companion",
        concat(
            chirp(520, 780, 0.07, decay=10),
            square(660, 0.05, decay=14),
            square(880, 0.06, decay=12),
        ),
        volume=0.38,
    )


if __name__ == "__main__":
    main()
