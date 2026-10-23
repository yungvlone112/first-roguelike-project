"""Синтез звуков: шаги (татами, доски, камень), шёпот, звуки существ. Формат как у остальных: 22050 Гц, моно, 16 бит."""
import numpy as np, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.RandomState(7)


def save(name, x, peak=0.8):
    x = np.asarray(x, np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def t_(sec): return np.arange(int(SR * sec)) / SR
def env_exp(n, k): return np.exp(-np.arange(n) / SR * k)


def bandpass(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    mask = np.exp(-0.5 * ((np.clip(f, lo, hi) - f) / (0.15 * (hi - lo) + 20)) ** 2)
    return np.fft.irfft(X * mask, len(x))


def lowpass(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / fc) ** 4), len(x))


def highpass(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * (1 - 1 / (1 + (f / fc) ** 4)), len(x))


def reverb(x, taps=((0.037, 0.35), (0.071, 0.25), (0.113, 0.18), (0.171, 0.1))):
    y = np.zeros(len(x) + int(SR * 0.3))
    y[:len(x)] += x
    for d, g in taps:
        k = int(SR * d); y[k:k + len(x)] += x * g
    return y


# ---------- шаги ----------
def step_tatami(seed):
    r = np.random.RandomState(seed)
    n = int(SR * 0.16); t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (70 + 15 * r.rand()) * t) * env_exp(n, 38)
    noise = lowpass(r.randn(n), 900) * env_exp(n, 45) * 0.8
    rustle = highpass(lowpass(r.randn(n), 3500), 1800) * env_exp(n, 70) * 0.25   # шорох соломы
    return thud * 0.9 + noise + rustle


def step_boards(seed):
    r = np.random.RandomState(seed)
    n = int(SR * 0.26); t = np.arange(n) / SR
    knock = (np.sin(2 * np.pi * 180 * t) + 0.6 * np.sin(2 * np.pi * 430 * t)) * env_exp(n, 30)
    tick = highpass(r.randn(n), 1200) * env_exp(n, 140) * 0.6
    creak_f = 310 + 90 * t / 0.26
    creak = np.sin(2 * np.pi * np.cumsum(creak_f) / SR) * env_exp(n, 14) * 0.10 * (r.rand() > 0.4)
    return knock * 0.8 + tick + creak


def step_stone(seed):
    r = np.random.RandomState(seed)
    n = int(SR * 0.12); t = np.arange(n) / SR
    tick = highpass(r.randn(n), 900) * env_exp(n, 90)
    ring = np.sin(2 * np.pi * (780 + 60 * r.rand()) * t) * env_exp(n, 48) * 0.35
    return reverb(tick + ring)


# ---------- шёпот ----------
def whisper(seed, dur, syll):
    r = np.random.RandomState(seed)
    n = int(SR * dur)
    base = r.randn(n)
    out = np.zeros(n)
    pos = 0.12
    for s in range(syll):
        ln = r.uniform(0.14, 0.34)
        a = int(pos * SR); b = min(n, a + int(ln * SR))
        if a >= n: break
        seg = base[a:b]
        f1 = r.uniform(500, 900); f2 = r.uniform(1400, 2200); f3 = r.uniform(2600, 3600)
        voc = bandpass(seg, f1 - 150, f1 + 150) * 1.0 + bandpass(seg, f2 - 300, f2 + 300) * 0.8 \
            + bandpass(seg, f3 - 500, f3 + 500) * 0.55
        w = np.hanning(len(seg)) ** 1.3
        out[a:b] += voc * w * r.uniform(0.7, 1.0)
        pos += ln + r.uniform(0.04, 0.16)
    out = reverb(out, ((0.05, 0.4), (0.11, 0.3), (0.19, 0.22), (0.29, 0.14)))
    return out


# ---------- существа ----------
def reveal():
    n = int(SR * 0.9); t = np.arange(n) / SR
    drone = np.sin(2 * np.pi * np.cumsum(70 - 35 * t / 0.9) / SR) * np.minimum(1, t * 12) * env_exp(n, 2.2)
    riser = highpass(rng.randn(n), 800) * (t / 0.9) ** 2 * env_exp(n, 4.0) * 0.5
    hi = (np.sin(2 * np.pi * 1760 * t) + np.sin(2 * np.pi * 1862 * t)) * env_exp(n, 9) * 0.35 * (t > 0.12)
    return drone * 0.9 + riser + hi


def creak():
    n = int(SR * 0.55); t = np.arange(n) / SR
    f = 140 - 40 * t / 0.55 + 6 * np.sin(2 * np.pi * 9 * t)
    saw = ((np.cumsum(f) / SR) % 1.0) * 2 - 1
    stick = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 26 * t))
    return lowpass(saw * stick, 1400) * np.minimum(1, t * 30) * env_exp(n, 3)


def scrape():
    n = int(SR * 0.5); t = np.arange(n) / SR
    x = bandpass(rng.randn(n), 900, 2600)
    am = 0.5 + 0.5 * np.sin(2 * np.pi * (22 - 8 * t / 0.5) * t)
    return x * am * np.minimum(1, t * 40) * env_exp(n, 2.5)


def snap():
    n = int(SR * 0.18); t = np.arange(n) / SR
    c1 = highpass(rng.randn(n), 700) * env_exp(n, 120)
    c2 = np.roll(highpass(rng.randn(n), 700) * env_exp(n, 120), int(SR * 0.045)) * 0.7
    tone = np.sin(2 * np.pi * 210 * t) * env_exp(n, 40) * 0.6
    return c1 + c2 + tone


def clack():
    n = int(SR * 0.09); t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 620 * t) * 0.6 + highpass(rng.randn(n), 1500) * 0.5) * env_exp(n, 90)


def bell():
    n = int(SR * 1.3); t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * t) * env_exp(n, d)
            for f, a, d in [(392, 1.0, 3.0), (784, 0.5, 4.5), (1180, 0.28, 6.0), (1568, 0.15, 8.0)])
    return x


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("step_tatami", np.concatenate([step_tatami(1), np.zeros(int(SR * 0.02))]), 0.7)
    save("step_boards", step_boards(2), 0.75)
    save("step_stone", step_stone(3), 0.7)
    save("whisper1", whisper(11, 1.9, 4), 0.55)
    save("whisper2", whisper(12, 2.4, 5), 0.55)
    save("whisper3", whisper(13, 1.5, 3), 0.55)
    save("reveal", reveal(), 0.85)
    save("creak", creak(), 0.7)
    save("scrape", scrape(), 0.7)
    save("snap", snap(), 0.8)
    save("clack", clack(), 0.7)
    save("bell", bell(), 0.6)
    print("audio ok")
