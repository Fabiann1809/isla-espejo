"""Synthesizes the sound effects no free pack had (bow, magic, boss warning...) as 16-bit mono WAV
files in assets/audio/sfx/. They are the team's own work, so they need no credit line.
    python tools/make_synth_sfx.py
Needs numpy. Every sound is a few lines of plain synthesis: tweak the numbers and run it again.
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n, attack, release_power=2.0):
    """Fast attack, then a curved fall to silence."""
    env = np.ones(n)
    a = max(int(RATE * attack), 1)
    env[:a] = np.linspace(0, 1, a)
    env[a:] = np.linspace(1, 0, n - a) ** release_power
    return env


def lowpass(signal, alpha):
    """One-pole low-pass filter (alpha 0..1, lower = darker)."""
    out = np.zeros_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha * (x - acc)
        out[i] = acc
    return out


def pluck(freq, seconds, damping=0.996):
    """Karplus-Strong plucked string: a burst of noise through a decaying delay line."""
    n = int(RATE * seconds)
    period = int(RATE / freq)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damping * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def sweep(f0, f1, seconds, wave_kind="sine"):
    tt = t(seconds)
    freq = np.geomspace(f0, f1, len(tt))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if wave_kind == "square":
        return np.sign(np.sin(phase))
    if wave_kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    return np.sin(phase)


def save(name, signal, gain=0.8):
    peak = np.max(np.abs(signal)) or 1.0
    data = np.int16(np.clip(signal / peak * gain, -1, 1) * 32767)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def bow_shot(variant):
    # A soft, short "fwip" of air with a faint thump of the string: no ringing twang, because the
    # player shoots constantly and a tonal sound gets tiring fast.
    seconds = 0.13
    raw = rng.uniform(-1, 1, int(RATE * seconds))
    # Band of noise: a bright low-pass minus a dark one keeps the airy middle only.
    air = lowpass(raw, 0.30 + variant * 0.04) - lowpass(raw, 0.04)
    air *= envelope(len(air), 0.012, 3.0)
    thump = np.sin(2 * np.pi * np.cumsum(np.geomspace(150, 90, int(RATE * 0.06))) / RATE)
    thump *= envelope(len(thump), 0.002, 2.5) * 0.35
    air[: len(thump)] += thump
    return air


def portal_open():
    # A rising shimmer: three detuned sweeps with a slow tremolo.
    tt = t(1.4)
    s = sum(sweep(220 * k, 880 * k, 1.4, "tri") for k in (1.0, 1.5, 2.01))
    tremolo = 0.7 + 0.3 * np.sin(2 * np.pi * 9 * tt)
    return s * tremolo * envelope(len(tt), 0.35, 1.5)


def fragment():
    # A bright arpeggio (C major, up two octaves) with a soft bell tail.
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    out = np.zeros(int(RATE * 1.3))
    for i, f in enumerate(notes):
        start = int(RATE * 0.09 * i)
        tone = np.sin(2 * np.pi * f * t(0.9)) + 0.3 * np.sin(2 * np.pi * f * 2 * t(0.9))
        tone *= envelope(len(tone), 0.005, 3)
        out[start:start + len(tone)] += tone[: len(out) - start]
    return out


def boss_warn():
    # A low rumble that swells: the ground getting ready to burst.
    tt = t(0.6)
    rumble = lowpass(rng.uniform(-1, 1, len(tt)), 0.03) * 3
    tone = sweep(55, 75, 0.6) * 0.5
    env = np.linspace(0, 1, len(tt)) ** 1.5
    env[-int(RATE * 0.08):] *= np.linspace(1, 0, int(RATE * 0.08))
    return (rumble + tone) * env


def player_death():
    # A falling, fading tone: Nico drops.
    s = sweep(440, 110, 0.9, "tri") + 0.4 * sweep(660, 140, 0.9)
    return s * envelope(int(RATE * 0.9), 0.01, 1.5)


def boss_defeated():
    # A slow low boom under a rising major chord.
    boom = lowpass(rng.uniform(-1, 1, int(RATE * 2.0)), 0.02) * 4 * envelope(int(RATE * 2.0), 0.005, 4)
    chord = sum(np.sin(2 * np.pi * f * t(2.0)) for f in (261.6, 329.6, 392.0, 523.3))
    chord *= np.minimum(t(2.0) / 0.5, 1) * envelope(int(RATE * 2.0), 0.001, 1.2)
    return boom + chord * 0.5


def enemy_alert():
    # A short two-note chirp when an enemy spots Nico.
    a = sweep(700, 900, 0.06, "square") * envelope(int(RATE * 0.06), 0.002, 1)
    b = sweep(900, 1200, 0.08, "square") * envelope(int(RATE * 0.08), 0.002, 2)
    return np.concatenate([a, np.zeros(int(RATE * 0.02)), b]) * 0.5


def shot_spit():
    # The plant spitting: a wet pop.
    tt = t(0.18)
    pop = sweep(500, 120, 0.18) * envelope(len(tt), 0.002, 3)
    noise = lowpass(rng.uniform(-1, 1, len(tt)), 0.4) * envelope(len(tt), 0.001, 6) * 0.5
    return pop + noise


def summon():
    # The forest spirit calls a sprout: a hollow wooden knock rising.
    s = sweep(160, 320, 0.35, "tri") * envelope(int(RATE * 0.35), 0.01, 2)
    return s + 0.5 * lowpass(rng.uniform(-1, 1, len(s)), 0.08) * envelope(len(s), 0.001, 5)


def thunder():
    # A crack, then a long low roll.
    n = int(RATE * 2.6)
    crack = rng.uniform(-1, 1, int(RATE * 0.12)) * envelope(int(RATE * 0.12), 0.001, 2)
    roll = lowpass(rng.uniform(-1, 1, n), 0.012) * 6
    roll *= np.minimum(t(2.6) / 0.15, 1) * np.linspace(1, 0, n) ** 1.6
    roll[: len(crack)] += crack
    return roll


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for v in range(3):
        save("shot_%d" % v, bow_shot(v), 0.45)
    save("portal_0", portal_open(), 0.6)
    save("fragment_0", fragment(), 0.7)
    save("boss_warn_0", boss_warn(), 0.7)
    save("player_death_0", player_death(), 0.7)
    save("boss_defeated_0", boss_defeated(), 0.8)
    save("alert_0", enemy_alert(), 0.35)
    save("spit_0", shot_spit(), 0.5)
    save("summon_0", summon(), 0.6)
    save("thunder_0", thunder(), 0.8)
    print("ok")
