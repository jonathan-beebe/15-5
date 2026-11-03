#!/usr/bin/env python3
"""Generates FifteenFive/Resources/chime.wav: a two-note bell, 16-bit mono PCM."""
import math
import pathlib
import struct
import wave

RATE = 44100
NOTES = [(0.0, 880.0), (0.22, 1318.5)]  # (onset seconds, frequency Hz)
LENGTH = 1.4
PARTIALS = [(1.0, 1.0), (2.0, 0.35), (3.0, 0.12)]  # (frequency ratio, amplitude)


def sample(t):
    total = 0.0
    for onset, freq in NOTES:
        dt = t - onset
        if dt < 0:
            continue
        attack = min(dt / 0.004, 1.0)
        for ratio, amp in PARTIALS:
            total += attack * amp * math.exp(-3.2 * ratio * dt) * math.sin(2 * math.pi * freq * ratio * dt)
    return total * 0.45


out = pathlib.Path(__file__).parent.parent / "FifteenFive/Resources/chime.wav"
with wave.open(str(out), "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, sample(i / RATE))) * 32767))
        for i in range(int(LENGTH * RATE))
    ))
