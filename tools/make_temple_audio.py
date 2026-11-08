"""Synthesizes the Templo del Eclipse audio with numpy only (fixed seeds, no samples, no downloads).

Writes the cues
assets/audio/sfx/<cue>_<n>.wav (44.1 kHz mono), plus the .import files (music loop = forward).
Run: python tools/make_temple_audio.py   (then godot --headless --path . --import and
godot --headless --path . --script res://tools/make_sound_data.gd)
"""
import os
import sys
import wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
MSR = 32000
TWO_PI = 2 * np.pi


def db(x):
    return 10 ** (x / 20.0)


def fft_filter(x, lo=None, hi=None, sr=SR, order=2):
    """Zero-phase band filter in the frequency domain (smooth rolloff)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    g = np.ones_like(f)
    if hi:
        g *= 1 / (1 + (f / hi) ** (2 * order))
    if lo:
        g *= 1 - 1 / (1 + (f / lo) ** (2 * order))
    return np.fft.irfft(spec * g, len(x))


def fade(x, fin=0.003, fout=0.02, sr=SR):
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def sine(freq, n, sr=SR, phase=0.0):
    """Sine of a constant frequency, or of a per-sample frequency array (phase is integrated)."""
    if np.ndim(freq):
        return np.sin(TWO_PI * np.cumsum(freq) / sr + phase)
    return np.sin(TWO_PI * freq * np.arange(n) / sr + phase)


def mix_at(buf, snd, start, wrap=False):
    n = len(snd)
    if wrap:
        idx = (np.arange(n) + start) % len(buf)
        np.add.at(buf, idx, snd)
    else:
        end = min(len(buf), start + n)
        if end > start:
            buf[start:end] += snd[: end - start]


def write_wav(path, data, sr, channels):
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def stats(x):
    return 20 * np.log10(np.max(np.abs(x)) + 1e-12), 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


# --- Music ----------------------------------------------------------------------------------------

BPM = 50
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LOOP_S = BARS * BAR  # 76.8 s


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def bell(freq, dur, rng):
    n = int(dur * MSR)
    t = np.arange(n) / MSR
    out = np.zeros(n)
    # Inharmonic partials of a cast bell.
    for ratio, amp, dec in [(1, 1, 1.0), (2.0, 0.6, 0.7), (2.4, 0.5, 0.55), (3.0, 0.35, 0.45),
                            (4.07, 0.3, 0.35), (5.43, 0.18, 0.25), (6.8, 0.1, 0.18)]:
        out += amp * np.sin(TWO_PI * freq * ratio * t + rng.uniform(0, TWO_PI)) * np.exp(-t / (dur * dec / 3.2))
    return out * np.minimum(1, t / 0.002)


def frame_drum(low, rng, vel=1.0, dur=0.9):
    n = int(dur * MSR)
    t = np.arange(n) / MSR
    freq = low * (1 + 1.2 * np.exp(-t / 0.03))
    body = np.sin(TWO_PI * np.cumsum(freq) / MSR) * np.exp(-t / 0.22)
    skin = fft_filter(rng.standard_normal(n), lo=300, hi=1800, sr=MSR) * np.exp(-t / 0.05) * 0.25
    return vel * (body + skin) * np.minimum(1, t / 0.002)


def flute(freq, dur, rng, vib=5.0):
    """Breathy modal flute: soft sine + 2nd/3rd harmonics, vibrato, breath noise."""
    n = int(dur * MSR)
    t = np.arange(n) / MSR
    vib_amt = 0.004 * np.minimum(1, t / 0.4) * np.sin(TWO_PI * vib * t)
    ph = TWO_PI * np.cumsum(freq * (1 + vib_amt)) / MSR
    tone = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    breath = fft_filter(rng.standard_normal(n), lo=1500, hi=5000, sr=MSR) * 0.12
    a = int(0.06 * MSR)
    r = int(min(0.5, dur * 0.5) * MSR)
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a) ** 1.5
    e[-r:] *= np.linspace(1, 0, r) ** 1.5
    return (tone + breath) * e


def make_music():
    rng = np.random.default_rng(1303)
    N = int(round(LOOP_S * MSR))
    t = np.arange(N) / MSR
    L = np.zeros(N)
    R = np.zeros(N)

    # Drone: D1/A1/D2 detuned saws, slowly breathing (whole LFO cycles per loop = seamless).
    def saw_stack(freq, voices=3):
        s = np.zeros(N)
        for k in range(voices):
            f = freq * (1 + 0.0015 * (k - 1))
            f = round(f * LOOP_S) / LOOP_S  # whole cycles per loop: no phase jump at the seam
            s += 2 * ((f * t + rng.uniform()) % 1.0) - 1
        return s / voices

    drone = saw_stack(midi(26)) * 0.9 + saw_stack(midi(33)) * 0.5 + saw_stack(midi(38)) * 0.25
    drone = fft_filter(drone, hi=260, sr=MSR, order=3)
    drone *= (0.75 + 0.25 * np.sin(TWO_PI * 4 * t / LOOP_S + 0.5)) * 1.4
    # Pad: D A F | D Bb G, swelling over each 4-bar block.
    pad = np.zeros(N)
    for blk in range(4):
        notes = [50, 57, 53] if blk % 2 == 0 else [50, 58, 55]
        n = int(4 * BAR * MSR)
        tt = np.arange(n) / MSR
        env = np.sin(np.pi * tt / (4 * BAR)) ** 2
        seg = np.zeros(n)
        for m in notes:
            for dt in (-0.0025, 0.0, 0.0025):
                f = midi(m) * (1 + dt)
                seg += np.sin(TWO_PI * f * tt + rng.uniform(0, 6)) + 0.4 * np.sin(TWO_PI * 2 * f * tt)
        mix_at(pad, seg * env * 0.05, int(blk * 4 * BAR * MSR), wrap=True)
    L += drone + pad
    R += drone + pad * 0.9

    # Frame drums: slow ritual pattern per bar (positions in beats).
    pat_a = [(0, 1.0), (2.5, 0.55), (3, 0.7)]
    pat_b = [(0, 1.0), (1.5, 0.45), (2, 0.8), (3.5, 0.5)]
    for bar in range(2, BARS):
        for beat, vel in (pat_a if bar % 4 != 3 else pat_b):
            s = int((bar * BAR + beat * BEAT) * MSR)
            d = frame_drum(rng.choice([62, 70]), rng, vel * rng.uniform(0.85, 1.0))
            pan = float(np.clip(0.5 + 0.1 * rng.standard_normal(), 0.2, 0.8))
            mix_at(L, d * 0.9 * (1 - pan), s, True)
            mix_at(R, d * 0.9 * pan, s, True)
    for bar in (0, 8):  # a deeper hit opens each 8 bars
        d = frame_drum(48, rng, 1.2, 1.4)
        mix_at(L, d, int(bar * BAR * MSR), True)
        mix_at(R, d, int(bar * BAR * MSR), True)

    # Temple bells on D, A and the Phrygian Eb; their tails wrap around the loop.
    for bar, beat, note in [(0, 0, 74), (3, 2, 81), (5, 0, 75), (7, 3, 69), (8, 0, 74), (10, 2, 77),
                            (12, 0, 81), (13, 2, 75), (15, 0, 69)]:
        b = bell(midi(note), 7.0, rng) * 0.16
        pan = rng.uniform(0.25, 0.75)
        s = int((bar * BAR + beat * BEAT) * MSR)
        mix_at(L, b * (1 - pan) * 1.4, s, True)
        mix_at(R, b * pan * 1.4, s, True)

    # Modal melody: D Phrygian, with the raised 7th (C#) in the final cadence (harmonic-minor colour).
    D4, Eb4, F4, G4, A4, Bb4, C5, Cs5, D5 = 62, 63, 65, 67, 69, 70, 72, 73, 74
    melody = [
        (4, 0, A4, 3), (4, 3, Bb4, 1), (5, 0, A4, 2), (5, 2, G4, 2), (6, 0, F4, 3), (6, 3, Eb4, 1),
        (7, 0, D4, 4),
        (8, 0, D5, 2), (8, 2, C5, 2), (9, 0, Bb4, 3), (9, 3, A4, 1), (10, 0, G4, 2), (10, 2, F4, 2),
        (11, 0, Eb4, 2), (11, 2, F4, 2),
        (12, 0, A4, 2), (12, 2, Bb4, 2), (13, 0, D5, 3), (13, 3, C5, 1), (14, 0, Bb4, 2),
        (14, 2, G4, 1), (14, 3, Eb4, 1), (15, 0, Cs5, 2), (15, 2, D5, 2),
    ]
    for bar, beat, note, beats in melody:
        s = int((bar * BAR + beat * BEAT) * MSR)
        f = flute(midi(note - 12), beats * BEAT * 1.05, rng) * 0.11
        mix_at(L, f * 0.9, s, True)
        mix_at(R, f * 1.1, s, True)

    # Crackle: sparse ember pops.
    crackle = np.zeros(N)
    for p in rng.integers(0, N, int(LOOP_S * 9)):
        ln = int(rng.uniform(0.001, 0.005) * MSR)
        pop = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4)) * rng.uniform(0.2, 1.0)
        mix_at(crackle, pop, int(p), True)
    crackle = fft_filter(crackle, lo=1200, hi=7000, sr=MSR)
    L += crackle * 0.035
    R += np.roll(crackle, 777) * 0.035

    # Reverb: circular convolution with a decaying noise tail (it wraps, so the loop stays seamless).
    def reverb(x, seed):
        r = np.random.default_rng(seed)
        n = int(2.8 * MSR)
        ir = r.standard_normal(n) * np.exp(-np.arange(n) / (0.7 * MSR))
        ir = fft_filter(ir, hi=3500, sr=MSR)
        ir[: int(0.02 * MSR)] *= np.linspace(0, 1, int(0.02 * MSR))
        ir /= np.sqrt(np.sum(ir ** 2))
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, len(x)), len(x))

    out = np.stack([L * 0.7 + reverb(L, 1) * 0.55, R * 0.7 + reverb(R, 2) * 0.55], axis=1)
    out = np.stack([fft_filter(out[:, 0], lo=28, sr=MSR), fft_filter(out[:, 1], lo=28, sr=MSR)], axis=1)
    # About -17 dBFS RMS, then a soft limiter so peaks stay under -1 dBFS.
    target = db(-17.0)
    out *= target / np.sqrt(np.mean(out ** 2))
    for _ in range(3):
        k = db(-1.5)
        if np.max(np.abs(out)) > k:
            out = np.tanh(out / k * 0.9) / np.tanh(0.9) * k
            out *= target / np.sqrt(np.mean(out ** 2))
    peak = np.max(np.abs(out))
    if peak > db(-1.2):
        out *= db(-1.2) / peak
    return out, N


# --- Sound effects (each takes a seeded rng and the variant number) -------------------------------

def noise(n, rng):
    return rng.standard_normal(n)


def fx_lava_bubble(rng, v):
    dur = 0.28 + 0.06 * v
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = [140, 190, 110][v] * (1 + 1.3 * (t / dur))  # a bubble rises in pitch as it swells
    s = sine(f, n) * np.sin(np.pi * np.minimum(1, t / dur * 1.1)) ** 0.7
    s += 0.3 * sine(f * 1.5, n) * np.exp(-t / 0.1)
    pop = fft_filter(noise(n, rng), lo=400, hi=2500) * np.exp(-np.abs(t - dur * 0.85) / 0.012) * 0.5
    return s * 0.7 + pop


def fx_lava_surge_warn(rng, v):
    dur = [1.8, 2.1, 1.6][v]
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = [38, 44, 34][v] * (1 + 0.15 * t / dur)
    s = sine(f, n) + 0.6 * sine(f * 2.01, n) + 0.3 * sine(f * 3.02, n)
    rumble = fft_filter(noise(n, rng), lo=20, hi=140, order=3) * 6
    trem = 0.7 + 0.3 * np.sin(TWO_PI * 9 * t)
    env = np.sin(np.pi * np.minimum(1, t / dur)) ** 0.8
    return (s * 0.5 + rumble) * trem * env


def fx_lava_surge_rise(rng, v):
    dur = [1.5, 1.7, 1.3][v]
    n = int(dur * SR)
    t = np.arange(n) / SR
    swell = (t / dur) ** 1.5
    roar = fft_filter(noise(n, rng), lo=60, hi=2400) * (0.3 + swell)
    low = sine([55, 48, 60][v] * (1 + 0.5 * swell), n) * 0.5
    gloop = fft_filter(noise(n, rng), lo=80, hi=300) * (0.5 + 0.5 * np.sin(TWO_PI * 13 * t))
    env = np.minimum(1, t / 0.15) * np.exp(-np.maximum(0, t - dur * 0.7) / 0.2)
    return (roar * 1.2 + low + gloop * 0.8) * env


def fx_lava_surge_recede(rng, v):
    dur = [1.5, 1.8, 1.3][v]
    n = int(dur * SR)
    t = np.arange(n) / SR
    hiss = fft_filter(noise(n, rng), lo=2500 - 300 * v, hi=9000)
    sweep = np.exp(-t / (dur * 0.45)) * np.minimum(1, t / 0.05)
    gurgle = fft_filter(noise(n, rng), lo=80, hi=350) * np.exp(-t / (dur * 0.4)) * 0.6
    return hiss * sweep * 1.2 + gurgle


def fx_geyser(rng, v):
    dur = [1.1, 1.3, 0.95][v]
    n = int(dur * SR)
    t = np.arange(n) / SR
    burst = fft_filter(noise(n, rng), lo=500, hi=7000 - 800 * v)
    env = np.minimum(1, t / 0.04) * np.exp(-t / (dur * 0.35))
    thump = sine(70 * np.exp(-t / 0.08) + 40, n) * np.exp(-t / 0.15)
    return burst * env * 1.1 + thump * 0.9


def fx_spikes(rng, v):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    snick = fft_filter(noise(n, rng), lo=2500, hi=10000) * np.exp(-t / 0.025)
    ring = (sine(2600 + 400 * v, n) + 0.5 * sine(3700 + 300 * v, n)) * np.exp(-t / 0.05) * 0.3
    thud = sine(130 * np.exp(-t / 0.03) + 70, n) * np.exp(-t / 0.05) * 0.6
    return snick * 0.9 + ring + thud


def fx_saw(rng, v):
    dur = [0.55, 0.65, 0.5][v]
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = [180, 210, 160][v] * (1 + 0.1 * np.sin(TWO_PI * 11 * t))
    buzz = fft_filter(2 * ((np.cumsum(f) / SR) % 1) - 1, lo=150, hi=3500)
    scrape = fft_filter(noise(n, rng), lo=1500, hi=8000) * (0.5 + 0.5 * np.sin(TWO_PI * 22 * t))
    env = np.minimum(1, t / 0.04) * np.minimum(1, (dur - t) / 0.1)
    return (buzz * 0.8 + scrape * 0.7) * env


def fx_rolling_rock(rng, v):
    dur = [1.0, 1.2, 0.85][v]
    n = int(dur * SR)
    t = np.arange(n) / SR
    rumble = fft_filter(noise(n, rng), lo=35, hi=380, order=3)
    bumps = 0.55 + 0.45 * np.abs(np.sin(np.pi * [7, 6, 8][v] * t + rng.uniform(0, 1)))
    grit = fft_filter(noise(n, rng), lo=800, hi=3000) * 0.25 * bumps
    env = np.minimum(1, t / 0.12) * np.minimum(1, (dur - t) / 0.2)
    return (rumble * 3 * bumps + grit) * env


def fx_shop_buy(rng, v):
    out = np.zeros(int(0.55 * SR))
    notes = [[(0.0, 1760), (0.07, 2349), (0.15, 2794)],
             [(0.0, 1568), (0.08, 2093), (0.16, 2637)],
             [(0.0, 1976), (0.06, 2637), (0.13, 3136), (0.2, 2637)]][v]
    for start, f in notes:
        m = int(0.35 * SR)
        tt = np.arange(m) / SR
        c = (np.sin(TWO_PI * f * tt) + 0.5 * np.sin(TWO_PI * f * 2.76 * tt)
             + 0.3 * np.sin(TWO_PI * f * 5.4 * tt)) * np.exp(-tt / 0.07)
        clink = fft_filter(noise(m, rng), lo=4000, hi=12000) * np.exp(-tt / 0.01) * 0.3
        mix_at(out, (c + clink) * 0.6, int(start * SR))
    return out


def fx_shop_denied(rng, v):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = [150, 175, 130][v]
    buzz = np.sign(sine(f, n)) * 0.5 + 0.5 * sine(f * 0.5, n)
    buzz = fft_filter(buzz, hi=1200) * np.minimum(1, np.abs(np.sin(np.pi * 8 * t)) * 4)
    env = np.minimum(1, t / 0.01) * np.exp(-t / 0.22)
    return (buzz + sine(f * 1.06, n) * 0.4) * env


def fx_crit_hit(rng, v):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    base = [1800, 2200, 2600][v]
    ring = (sine(base, n) + 0.6 * sine(base * 1.5, n) + 0.4 * sine(base * 2.76, n)) * np.exp(-t / 0.1)
    crack = fft_filter(noise(n, rng), lo=2000, hi=12000) * np.exp(-t / 0.018)
    punch = sine(220 * np.exp(-t / 0.02) + 90, n) * np.exp(-t / 0.05)
    sweep = sine(base * (0.6 + 2.5 * np.minimum(1, t / 0.06)), n) * np.exp(-t / 0.05) * 0.5
    return ring * 0.5 + crack * 0.9 + punch * 0.8 + sweep


def fx_merchant_greet(rng, v):
    out = np.zeros(int(0.9 * SR))
    for start, f in [[(0.0, 1319), (0.18, 1760)], [(0.0, 1175), (0.17, 1568)]][v]:
        m = int(0.7 * SR)
        tt = np.arange(m) / SR
        c = (np.sin(TWO_PI * f * tt) + 0.4 * np.sin(TWO_PI * f * 2.0 * tt)
             + 0.25 * np.sin(TWO_PI * f * 3.01 * tt)) * np.exp(-tt / 0.22)
        mix_at(out, c * 0.6, int(start * SR))
    return out


# cue -> (function, variants, target RMS dBFS)
SFX = {
    "lava_bubble": (fx_lava_bubble, 3, -18.0),
    "lava_surge_warn": (fx_lava_surge_warn, 3, -17.0),
    "lava_surge_rise": (fx_lava_surge_rise, 3, -17.0),
    "lava_surge_recede": (fx_lava_surge_recede, 3, -18.0),
    "geyser": (fx_geyser, 3, -17.0),
    "spikes": (fx_spikes, 3, -17.0),
    "saw": (fx_saw, 3, -17.0),
    "rolling_rock": (fx_rolling_rock, 3, -17.0),
    "shop_buy": (fx_shop_buy, 3, -18.0),
    "shop_denied": (fx_shop_denied, 3, -18.0),
    "crit_hit": (fx_crit_hit, 3, -16.0),
    "merchant_greet": (fx_merchant_greet, 2, -19.0),
}

IMPORT_TEXT = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="{source}"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={mode}
edit/loop_begin=0
edit/loop_end={end}
compress/mode=0
"""


def write_import(path, source, mode, end):
    """Godot adds uid/path/dest_files on the next --import and keeps them on later runs of this tool."""
    lines = IMPORT_TEXT.format(source=source, mode=mode, end=end).splitlines()
    if os.path.exists(path):
        keep = {}
        for l in open(path, encoding="utf-8").read().splitlines():
            for key in ("uid=", "path=", "dest_files="):
                if l.startswith(key):
                    keep[key] = l
        out = []
        for l in lines:
            out.append(l)
            if l.startswith("type=") and "uid=" in keep:
                out.append(keep["uid="])
                if "path=" in keep:
                    out.append(keep["path="])
            if l.startswith("source_file=") and "dest_files=" in keep:
                out.append(keep["dest_files="])
        lines = out
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def seed_of(cue, v):
    return sum(ord(c) * (i + 3) for i, c in enumerate(cue)) * 31 + v * 7919


def main():
    os.makedirs(MUSIC_DIR, exist_ok=True)
    os.makedirs(SFX_DIR, exist_ok=True)
    # The temple plays "Ancient Temple" (Alexandr Zhelanov, CC-BY 4.0, see CREDITS.md) as temple.ogg; this
    # synthesized loop is only written on request, as a stand-in, outside the game's music folder.
    if "--music" in sys.argv:
        music, n = make_music()
        out = os.path.join(ROOT, "tmp_preview", "temple_synth.wav")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        write_wav(out, music, MSR, 2)
        peak, rms = stats(music)
        print(f"{out}: {n} samples @ {MSR} Hz = {n / MSR:.2f} s, peak {peak:.1f} dBFS, rms {rms:.1f} dBFS")
    for cue, (fn, variants, rms_target) in SFX.items():
        for v in range(variants):
            x = fade(fn(np.random.default_rng(seed_of(cue, v)), v), 0.002, 0.03)
            x *= db(rms_target) / np.sqrt(np.mean(x ** 2))
            if np.max(np.abs(x)) > db(-2.0):
                x *= db(-2.0) / np.max(np.abs(x))
            x = fade(x, 0.002, 0.03)
            name = f"{cue}_{v}.wav"
            write_wav(os.path.join(SFX_DIR, name), x, SR, 1)
            write_import(os.path.join(SFX_DIR, name + ".import"), "res://assets/audio/sfx/" + name, 0, -1)
            p, r = stats(x)
            print(f"sfx/{name}: {len(x) / SR:.2f} s, peak {p:.1f}, rms {r:.1f}")


if __name__ == "__main__":
    main()
