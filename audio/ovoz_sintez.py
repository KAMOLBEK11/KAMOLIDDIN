"""O'yin ovozlarini noldan (fizik modellar asosida) sintez qilish.
Har ovoz bir nechta variantda - o'yinda tasodifiy tanlanadi, takrorlanish sezilmaydi.
Chiqish: WAV (keyin OGG ga o'giriladi)."""
import os, sys
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ yordamchilar
def t_(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.standard_normal(int(d * SR))


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], 'band', output='sos')
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, min(f / (SR / 2), 0.99), 'low', output='sos')
    return signal.sosfilt(sos, x)


def hp(x, f, order=2):
    sos = signal.butter(order, f / (SR / 2), 'high', output='sos')
    return signal.sosfilt(sos, x)


def env_exp(d, tau, att=0.002):
    t = t_(d)
    e = np.exp(-t / tau)
    a = np.minimum(1, t / max(att, 1e-4))
    return e * a


def pad(x, d):
    n = int(d * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def place(buf, x, at):
    i = int(at * SR)
    if i < 0:
        x = x[-i:]
        i = 0
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i]


def reverb(x, size=0.6, wet=0.25, damp=3000):
    """ochiq maydon: qisqa, siyrak aks-sado (shovqinli eksponensial impuls)"""
    ir = noise(size) * np.exp(-t_(size) / (size / 5))
    ir = lp(ir, damp)
    ir[:int(0.012 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    w = signal.fftconvolve(x, ir)[:len(x) + int(size * SR)]
    return mix(x, w * wet)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.003, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def trim(x, db=-62):
    """oxiridagi jimlikni kesish"""
    thr = np.max(np.abs(x)) * 10 ** (db / 20)
    idx = np.nonzero(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    return x[:min(len(x), idx[-1] + int(0.02 * SR))]


def save(name, x, peak=0.9, verb=None):
    x = fade(x, 0.0005, 0.03)
    if verb:
        x = reverb(x, *verb)
    x = fade(trim(norm(x, peak)), 0.0005, 0.06)
    wavfile.write(os.path.join(OUT, name + '.wav'), SR, (x * 32767).astype(np.int16))


def loopify(x, xf=0.5):
    """uzluksiz takrorlanadigan halqa: oxiri boshiga yumshoq qo'shiladi"""
    n = int(xf * SR)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    y = x[n:-n].copy() if len(x) > 2 * n else x.copy()
    y = np.concatenate([tail * (1 - w) + head * w, x[n:-n]])
    return y


def save_loop(name, x, peak=0.7):
    x = loopify(norm(x, peak))
    wavfile.write(os.path.join(OUT, name + '.wav'), SR, (x * 32767).astype(np.int16))


def modal(freqs, decays, amps, d, detune=0.0):
    """rezonans modlar yig'indisi (metall, yog'och, tosh)"""
    t = t_(d)
    out = np.zeros_like(t)
    for f, tau, a in zip(freqs, decays, amps):
        ph = rng.uniform(0, 2 * np.pi)
        out += a * np.sin(2 * np.pi * f * t + ph) * np.exp(-t / tau)
        if detune:
            out += a * 0.5 * np.sin(2 * np.pi * f * (1 + detune) * t + ph) * np.exp(-t / tau)
    # oxirida yumshoq so'nish (keskin uzilish "chiq" ovozi bermasin)
    k = int(len(t) * 0.35)
    out[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return out


def ks(f0, d, damp=0.996, bright=0.5):
    """Karplus-Strong tor (kamon tori, arqon)"""
    n = int(SR / f0)
    buf = rng.uniform(-1, 1, n)
    buf = lp(buf, 2000 + 6000 * bright)
    out = np.zeros(int(d * SR))
    for i in range(len(out)):
        v = buf[i % n]
        out[i] = v
        buf[i % n] = damp * 0.5 * (v + buf[(i + 1) % n])
    return out


def thump(f0=80, d=0.25, tau=0.06, drop=0.5, click=0.3):
    """yerga tegish: pasayuvchi chastotali past to'lqin + kichik shitirlash"""
    t = t_(d)
    f = f0 * (1 + drop * np.exp(-t / 0.02))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t / tau)
    c = lp(noise(d), 2500) * np.exp(-t / 0.008) * click
    return x + c


def voice(f0, d, vowels, jitter=0.02, breath=0.15, vib=5.0, glide=0.0):
    """oddiy inson ovozi: glottal impulslar (arra) + formant filtrlar.
    vowels - [(vaqt_ulushi, (F1,F2,F3))] - unli tovushlar o'zgarishi"""
    t = t_(d)
    jit = 1 + jitter * lp(noise(d), 8) * 4
    ff = f0 * (1 + glide * t / d) * jit * (1 + 0.012 * np.sin(2 * np.pi * vib * t))
    ph = np.cumsum(ff) / SR
    saw = 2 * (ph % 1) - 1
    src = saw + breath * noise(d)
    out = np.zeros_like(t)
    # unli tovushlar - formantlar vaqt bo'yicha interpolyatsiya (bo'laklarda)
    seg = 0.04
    nseg = int(np.ceil(d / seg))
    fr = np.array([v[0] for v in vowels])
    fm = np.array([v[1] for v in vowels], dtype=float)
    for k in range(nseg):
        a, b = int(k * seg * SR), int(min(d, (k + 1) * seg + 0.02) * SR)
        u = min(1.0, k * seg / d)
        F = [np.interp(u, fr, fm[:, j]) for j in range(3)]
        chunk = src[a:b]
        y = np.zeros_like(chunk)
        for j, (Fj, g) in enumerate(zip(F, (1.0, 0.6, 0.3))):
            bw = 80 + 40 * j
            y += g * bp(chunk, max(50, Fj - bw), Fj + bw)
        w = np.hanning(len(y)) if len(y) > 4 else np.ones(len(y))
        out[a:b] += y * w
    return out


A = (800, 1200, 2500)
O = (500, 900, 2400)
U = (350, 700, 2300)
E = (550, 1800, 2500)
EH = (650, 1100, 2400)


# ================================================================== JANG

def sword_clash():
    for v in range(5):
        d = 1.1
        f0 = rng.uniform(1050, 1700)
        ratios = [1.0, 2.32, 2.76, 4.13, 5.4, 6.8, 8.93]
        x = modal([f0 * r * rng.uniform(0.98, 1.02) for r in ratios],
                  [rng.uniform(0.15, 0.5) / (1 + 0.25 * i) for i in range(7)],
                  [1.0, 0.7, 0.8, 0.5, 0.45, 0.3, 0.25], d, detune=0.004)
        tr = hp(noise(0.02), 2500) * env_exp(0.02, 0.003) * 2.5   # zarb lahzasi
        scrape = bp(noise(0.12), 3000, 9000) * env_exp(0.12, 0.04) * 0.5 * (v % 2)   # tig' sirpanishi
        save('qilich_%d' % v, mix(x * 0.5, tr, scrape), 0.85, (0.5, 0.18))


def blade_flesh():
    for v in range(4):
        d = 0.35
        x = thump(rng.uniform(70, 110), d, 0.05, 0.8, 0.6)
        sl = bp(noise(d), 800, 3500) * env_exp(d, 0.035) * 0.6
        save('zarba_%d' % v, mix(x, sl), 0.8, (0.3, 0.12))


def shield_block():
    for v in range(4):
        d = 0.5
        fr = [rng.uniform(170, 230), rng.uniform(380, 460), rng.uniform(700, 820), rng.uniform(1300, 1500)]
        x = modal(fr, [0.07, 0.05, 0.035, 0.02], [1, 0.6, 0.4, 0.25], d)
        knock = lp(noise(d), 4000) * env_exp(d, 0.006) * 1.2
        ring = modal([rng.uniform(2400, 3200)], [0.12], [0.15], d) * (v % 2)   # temir bo'rtma
        save('qalqon_%d' % v, mix(x, knock, ring), 0.85, (0.4, 0.15))


def whoosh(name, n, d=0.35, lo=400, hi=2500):
    for v in range(n):
        t = t_(d)
        x = noise(d)
        sweep = lo + (hi - lo) * np.sin(np.pi * t / d)
        y = np.zeros_like(x)
        seg = 256
        for i in range(0, len(x), seg):
            f = sweep[min(i, len(sweep) - 1)]
            y[i:i + seg] = bp(x[max(0, i - 512):i + seg], f * 0.7, f * 1.3)[-len(x[i:i + seg]):]
        y *= np.sin(np.pi * t / d) ** 2
        save('%s_%d' % (name, v), y, 0.6)


def bow_release():
    for v in range(4):
        d = 0.6
        s = ks(rng.uniform(95, 140), d, 0.993, 0.3) * env_exp(d, 0.12)
        th = thump(rng.uniform(140, 190), d, 0.03, 0.3, 0.8) * 0.9
        wh = bp(noise(d), 1200, 4000) * env_exp(d, 0.05, 0.01) * 0.25
        save('kamon_%d' % v, mix(s * 0.8, th, wh), 0.8, (0.3, 0.1))


def arrow_fly():
    for v in range(3):
        d = 0.9
        t = t_(d)
        f = 2200 * (1.25 - 0.5 * t / d)          # Doppler: yaqinlashib, uzoqlashadi
        x = noise(d)
        y = np.zeros_like(x)
        seg = 512
        for i in range(0, len(x), seg):
            fc = f[min(i, len(f) - 1)]
            y[i:i + seg] = bp(x[max(0, i - 1024):i + seg], fc * 0.85, fc * 1.15)[-len(x[i:i + seg]):]
        y *= np.exp(-((t - d * 0.45) / (d * 0.22)) ** 2)
        save('oq_uchish_%d' % v, y, 0.5)


def arrow_hit():
    for v in range(4):
        d = 0.35
        x = modal([rng.uniform(220, 300), rng.uniform(520, 700)], [0.04, 0.025], [1, 0.5], d)   # yog'och / yer
        cl = hp(noise(d), 1500) * env_exp(d, 0.004) * 1.5
        vib = np.sin(2 * np.pi * rng.uniform(18, 26) * t_(d)) * modal([rng.uniform(900, 1300)], [0.08], [0.3], d)   # o'q dumining titrashi
        save('oq_tegish_%d' % v, mix(x, cl, vib), 0.7, (0.25, 0.1))
    for v in range(3):   # toshga/devorga
        d = 0.25
        x = hp(noise(d), 2000) * env_exp(d, 0.012) + modal([rng.uniform(1800, 2600)], [0.03], [0.4], d)
        save('oq_tosh_%d' % v, x, 0.6, (0.3, 0.12))


def rifle():
    for v in range(4):
        d = 1.8
        crack = hp(noise(0.03), 1500) * env_exp(0.03, 0.004) * 3
        body = lp(noise(d), 900) * env_exp(d, 0.09, 0.001) * 2.2
        low = thump(rng.uniform(55, 75), d, 0.12, 1.5, 0.0) * 1.6
        tail = lp(noise(d), 500) * env_exp(d, 0.45, 0.05) * 0.35            # uzoq aks-sado
        save('miltiq_%d' % v, mix(crack, body, low, tail), 0.95, (1.4, 0.35, 1800))


def ramrod():
    for v in range(2):
        d = 1.6
        buf = np.zeros(int(d * SR))
        for k in range(3):
            at = 0.15 + k * 0.45
            place(buf, modal([rng.uniform(2800, 3400), rng.uniform(5200, 6000)], [0.05, 0.03], [0.4, 0.25], 0.2), at)
            place(buf, bp(noise(0.3), 2000, 7000) * np.hanning(int(0.3 * SR)) * 0.15, at - 0.25)   # tiqish shitirlashi
        save('shompol_%d' % v, buf, 0.5)


def cannon():
    for v in range(3):
        d = 4.0
        t = t_(d)
        f = 38 + 60 * np.exp(-t / 0.05)
        boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(d, 0.35, 0.003) * 1.6
        blast = lp(noise(d), 600) * env_exp(d, 0.25, 0.001) * 2.5
        crack = hp(noise(0.05), 1000) * env_exp(0.05, 0.008) * 2
        rumble = lp(noise(d), 160) * env_exp(d, 1.2, 0.08) * 1.4
        save('top_%d' % v, mix(boom, blast, crack, rumble), 0.97, (2.0, 0.45, 1200))


def impact_stone():
    for v in range(4):
        d = 2.0
        hit = thump(rng.uniform(45, 65), d, 0.18, 1.2, 1.5) * 1.5
        crash = bp(noise(d), 300, 5000) * env_exp(d, 0.09) * 1.2
        rub = np.zeros(int(d * SR))      # sochilgan tosh bo'laklari
        for k in range(rng.integers(25, 45)):
            at = 0.05 + rng.exponential(0.25)
            g = rng.uniform(0.1, 0.5) * np.exp(-at * 2)
            place(rub, modal([rng.uniform(900, 3500)], [rng.uniform(0.008, 0.02)], [g], 0.06), at)
        save('tosh_zarba_%d' % v, mix(hit, crash, rub), 0.95, (0.9, 0.3, 2500))


def ram():
    for v in range(3):
        d = 1.8
        boom = modal([rng.uniform(62, 78), rng.uniform(140, 170), rng.uniform(260, 300)], [0.35, 0.18, 0.08], [1, 0.5, 0.25], d)
        knock = lp(noise(d), 1500) * env_exp(d, 0.02) * 1.5
        creak = bp(noise(d), 300, 900) * env_exp(d, 0.3, 0.1) * 0.15 * (v % 2)
        save('taran_%d' % v, mix(boom * 1.4, knock, creak), 0.95, (1.0, 0.3, 1500))


def gate_break():
    d = 3.0
    buf = np.zeros(int(d * SR))
    place(buf, thump(50, 1.5, 0.3, 1.0, 2.0) * 1.5, 0)
    for k in range(60):   # yog'och sinishi, taxtalar tushishi
        at = rng.exponential(0.5)
        place(buf, modal([rng.uniform(150, 900)], [rng.uniform(0.03, 0.12)], [rng.uniform(0.2, 0.7) * np.exp(-at)], 0.4)
              + hp(noise(0.4), 1200) * env_exp(0.4, 0.01) * 0.3 * np.exp(-at), at)
    save('darvoza_sinish', buf, 0.95, (1.2, 0.3, 2000))


def trebuchet():
    d = 2.2
    buf = np.zeros(int(d * SR))
    t = t_(0.7)
    creak_f = 90 + 40 * np.sin(2 * np.pi * 1.3 * t)
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(creak_f) / SR)) * 0.3
    creak = bp(creak, 200, 2500) * np.hanning(len(t))
    place(buf, creak, 0.0)
    place(buf, bp(noise(0.6), 200, 1500) * np.hanning(int(0.6 * SR)) * 0.7, 0.45)   # yelka siltanishi
    place(buf, thump(60, 1.0, 0.15, 0.8, 1.2) * 1.3, 0.95)                            # yelka to'xtatgichga uriladi
    save('manjaniq', buf, 0.9, (0.8, 0.25))


def ladder():
    for v in range(2):
        d = 0.8
        x = modal([rng.uniform(200, 260), rng.uniform(480, 560), 900], [0.06, 0.04, 0.02], [1, 0.6, 0.3], d)
        x2 = np.zeros(int(d * SR))
        place(x2, x * 0.6, 0.09)
        save('narvon_%d' % v, mix(x, x2, lp(noise(d), 3000) * env_exp(d, 0.008)), 0.8, (0.4, 0.15))
    d = 1.5
    buf = np.zeros(int(d * SR))
    for k in range(8):
        at = 0.1 * k + rng.uniform(0, 0.05)
        place(buf, modal([rng.uniform(180, 600)], [0.05], [1 - k * 0.1], 0.3), at)
    place(buf, thump(70, 0.6, 0.12, 0.6, 1.0), 0.75)
    save('narvon_qulash', buf, 0.85, (0.6, 0.2))


def body_fall():
    for v in range(3):
        d = 0.6
        x = mix(thump(rng.uniform(55, 80), d, 0.07, 0.8, 0.8), np.zeros(1))
        jing = np.zeros(int(d * SR))
        for k in range(6):   # zirh/qurol jaranglashi
            place(jing, modal([rng.uniform(2500, 5000)], [0.02], [0.15], 0.08), rng.uniform(0.0, 0.15))
        save('yiqilish_%d' % v, mix(x, jing), 0.7, (0.3, 0.1))


# ================================================================== ODAMLAR

def shouts():
    # og'riq/zarb tovushlari: qisqa "uh", "a", "eh"
    for v in range(6):
        d = rng.uniform(0.3, 0.6)
        f0 = rng.uniform(95, 160)
        vw = [[(0, U), (1, A)], [(0, EH), (1, U)], [(0, A), (1, O)]][v % 3]
        x = voice(f0, d, vw, 0.03, 0.35, 6, -0.3) * np.sin(np.pi * t_(d) / d) ** 0.5
        save('ah_%d' % v, x, 0.55, (0.3, 0.12))
    # o'lim qichqirig'i (uzunroq, pasayuvchi)
    for v in range(3):
        d = 0.9
        f0 = rng.uniform(140, 200)
        x = voice(f0, d, [(0, A), (0.6, A), (1, U)], 0.04, 0.4, 7, -0.45) * env_exp(d, 0.45, 0.03)
        save('qichqiriq_%d' % v, x, 0.55, (0.5, 0.18))


def war_cry():
    """jang hayqirig'i (olomon): 'U-r-a-a-a' - 40 ovoz, har biri o'z balandligi va kechikishi bilan"""
    for v in range(2):
        d = 3.2
        buf = np.zeros(int(d * SR))
        for k in range(40):
            dd = rng.uniform(1.6, 2.6)
            f0 = rng.uniform(110, 210)
            x = voice(f0, dd, [(0, U), (0.15, U), (0.25, A), (1, A)], 0.04, 0.5, rng.uniform(4, 7), rng.uniform(-0.1, 0.15))
            x *= np.minimum(1, t_(dd) / 0.15) * np.minimum(1, (dd - t_(dd)) / 0.4)
            place(buf, x * rng.uniform(0.5, 1.0), rng.uniform(0, 0.5))
        save('urra_%d' % v, buf, 0.8, (1.2, 0.35, 2500))


def crowd_loop():
    """jang shovqini (fon): uzoqdan olomon g'uvillashi, qurollar jarangi, qichqiriqlar"""
    d = 12.0
    buf = lp(noise(d), 700) * 0.25 * (1 + 0.3 * np.sin(2 * np.pi * 0.17 * t_(d)))
    for k in range(70):
        at = rng.uniform(0, d - 1.2)
        f0 = rng.uniform(1100, 1700)
        place(buf, modal([f0, f0 * 2.76, f0 * 5.4], [0.2, 0.1, 0.06], [0.25, 0.15, 0.1], 0.7) * rng.uniform(0.3, 1), at)
    for k in range(14):
        at = rng.uniform(0, d - 1.2)
        dd = rng.uniform(0.3, 0.8)
        place(buf, voice(rng.uniform(110, 200), dd, [(0, A), (1, U)], 0.04, 0.4, 6, -0.3) * np.hanning(int(dd * SR))[:int(dd * SR)] * 0.4, at)
    buf = reverb(buf, 1.2, 0.4, 1500)[:int(d * SR)]
    save_loop('jang_fon', lp(buf, 5000), 0.6)


def horn():
    """karnay / jang burg'usi: uzun kuchli mis ovoz"""
    d = 2.8
    t = t_(d)
    f0 = 118 * (1 + 0.04 * np.minimum(1, t / 0.3)) * (1 + 0.004 * np.sin(2 * np.pi * 5 * t))
    ph = np.cumsum(f0) / SR
    x = np.zeros_like(t)
    for h in range(1, 16):
        x += np.sin(2 * np.pi * h * ph) / h ** 0.8
    x = bp(x, 120, 3500) + 0.6 * bp(x, 900, 1500)
    e = np.minimum(1, t / 0.25) * np.minimum(1, (d - t) / 0.5)
    save('karnay', x * e, 0.85, (1.5, 0.35))


def drum():
    for v in range(2):
        d = 1.4
        x = thump(rng.uniform(55, 70), d, 0.25, 0.6, 0.5) * 1.2 + lp(noise(d), 400) * env_exp(d, 0.08) * 0.6
        save('nogora_%d' % v, x, 0.9, (0.9, 0.3))


# ================================================================== OT, FIL, QADAM

def hoof_hit():
    d = 0.12
    return thump(rng.uniform(90, 130), d, 0.025, 0.6, 1.6) + hp(noise(d), 1500) * env_exp(d, 0.006) * 0.5


def hooves_loop(name, stride, pattern, n_horses, d=8.0):
    buf = np.zeros(int(d * SR))
    for h in range(n_horses):
        off = rng.uniform(0, stride)
        sp = stride * rng.uniform(0.95, 1.05)
        k = 0
        while True:
            base = off + k * sp
            if base > d:
                break
            for p in pattern:
                at = base + p * sp + rng.normal(0, 0.006)
                if 0 <= at < d:
                    place(buf, hoof_hit() * rng.uniform(0.5, 1.0) / np.sqrt(n_horses), at)
            k += 1
    buf = mix(buf, lp(noise(d), 300) * 0.04 * np.sqrt(n_horses))
    save_loop(name, reverb(buf, 0.5, 0.15)[:int(d * SR)], 0.6)


def steps_loop(name, rate, n, jingle=0.3, d=8.0):
    buf = np.zeros(int(d * SR))
    for s in range(n):
        off = rng.uniform(0, 1 / rate)
        k = 0
        while True:
            at = off + k / (rate * rng.uniform(0.97, 1.03)) + rng.normal(0, 0.01)
            if at > d:
                break
            st = thump(rng.uniform(70, 110), 0.15, 0.03, 0.4, 0.4) + bp(noise(0.15), 1500, 6000) * env_exp(0.15, 0.02) * 0.25  # tuproq/shag'al
            place(buf, st * rng.uniform(0.5, 1) / np.sqrt(n), at)
            if rng.random() < jingle:
                place(buf, modal([rng.uniform(3000, 6000)], [0.02], [0.12], 0.06) / np.sqrt(n), at + 0.02)
            k += 1
    save_loop(name, reverb(buf, 0.4, 0.12)[:int(d * SR)], 0.55)


def horse_snort():
    for v in range(3):
        d = 0.7
        t = t_(d)
        x = bp(noise(d), 300, 1800) * (np.abs(np.sin(2 * np.pi * rng.uniform(16, 24) * t)) ** 2)
        x *= np.sin(np.pi * t / d) ** 1.5
        save('ot_pishqirish_%d' % v, x, 0.5, (0.3, 0.1))


def neigh():
    d = 1.6
    t = t_(d)
    f0 = 520 + 380 * np.exp(-t / 0.25) - 180 * t / d
    f0 = f0 * (1 + 0.06 * np.sin(2 * np.pi * 11 * t) * np.minimum(1, t / 0.3))     # titroq kishnash
    x = voice(1.0, d, [(0, E), (0.3, A), (1, A)], 0.02, 0.6, 0.0, 0.0)
    ph = np.cumsum(f0) / SR
    saw = 2 * (ph % 1) - 1
    src = saw + 0.5 * noise(d)
    y = bp(src, 500, 1400) + 0.6 * bp(src, 1600, 2800) + 0.3 * bp(src, 3000, 4200)
    y *= np.minimum(1, t / 0.05) * np.exp(-t / 0.7)
    save('ot_kishnash', y, 0.55, (0.6, 0.2))


def elephant():
    for v in range(2):
        d = 1.8
        t = t_(d)
        f0 = (380 + 120 * v) * (1 + 0.35 * np.sin(np.pi * np.minimum(1, t / 0.9))) * (1 + 0.02 * np.sin(2 * np.pi * 7 * t))
        ph = np.cumsum(f0) / SR
        x = np.zeros_like(t)
        for h in range(1, 12):
            x += np.sin(2 * np.pi * h * ph) / h ** 0.7
        x += 0.5 * bp(noise(d), 600, 3000)           # xartumdan o'tgan havo
        x = bp(x, 300, 4000)
        x *= np.minimum(1, t / 0.08) * np.minimum(1, (d - t) / 0.4)
        save('fil_%d' % v, x, 0.8, (1.0, 0.3))
    d = 8.0
    buf = np.zeros(int(d * SR))
    for k in range(int(d / 0.75)):
        place(buf, thump(rng.uniform(35, 45), 0.5, 0.12, 0.5, 0.3) * rng.uniform(0.7, 1), k * 0.75 + rng.uniform(0, 0.05))
    save_loop('fil_qadam', buf, 0.6)


def wheels_loop():
    d = 8.0
    t = t_(d)
    x = lp(noise(d), 400) * 0.5 * (1 + 0.4 * np.sin(2 * np.pi * 3.1 * t))       # g'ildirak g'ildiragi
    for k in range(int(d * 6)):
        place(x, modal([rng.uniform(300, 700)], [0.03], [0.3], 0.1), rng.uniform(0, d - 0.1))  # tosh ustidan sakrash
    save_loop('arava_gildirak', x, 0.5)


# ================================================================== MUHIT

def crickets_loop():
    d = 12.0
    buf = lp(noise(d), 250) * 0.05                                    # kechki shamol
    for c in range(6):
        fc = rng.uniform(4200, 5200)
        rate = rng.uniform(1.2, 2.4)
        pan = rng.uniform(0.3, 1.0)
        k = 0
        while k / rate < d:
            at = k / rate + rng.uniform(0, 0.03)
            dd = 0.12
            tt = t_(dd)
            chirp = np.sin(2 * np.pi * fc * tt) * np.sin(np.pi * 30 * tt) ** 4 * np.sin(np.pi * tt / dd)
            place(buf, chirp * 0.12 * pan, at)
            k += 1
    for k in range(3):     # uzoqda boyqush
        at = rng.uniform(1, d - 2)
        dd = 0.5
        tt = t_(dd)
        owl = np.sin(2 * np.pi * (420 - 40 * tt / dd) * tt) * np.sin(np.pi * tt / dd) ** 2 * 0.1
        place(buf, owl, at)
        place(buf, owl * 0.8, at + 0.65)
    save_loop('tun', buf, 0.45)


def birds_loop():
    d = 12.0
    buf = lp(noise(d), 300) * 0.06 * (1 + 0.5 * np.sin(2 * np.pi * 0.1 * t_(d)))     # shamol
    for k in range(26):
        at = rng.uniform(0, d - 1)
        n = rng.integers(2, 6)
        f0 = rng.uniform(2500, 4500)
        for j in range(n):
            dd = rng.uniform(0.05, 0.12)
            tt = t_(dd)
            fm = f0 * (1 + rng.uniform(-0.3, 0.3) * tt / dd)
            ph = np.cumsum(fm) / SR
            place(buf, np.sin(2 * np.pi * ph) * np.sin(np.pi * tt / dd) * rng.uniform(0.05, 0.12), at + j * 0.13)
    save_loop('kunduz', buf, 0.45)


def wind_loop():
    d = 12.0
    t = t_(d)
    x = bp(noise(d), 150, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t) * np.sin(2 * np.pi * 0.19 * t + 1))
    save_loop('shamol', x, 0.45)


def fire_loop():
    d = 8.0
    buf = lp(noise(d), 500) * 0.25
    for k in range(400):
        at = rng.uniform(0, d - 0.05)
        place(buf, hp(noise(0.02), 2000) * env_exp(0.02, 0.003) * rng.uniform(0.1, 0.6), at)
    save_loop('olov', buf, 0.5)


def rain_loop():
    d = 10.0
    buf = hp(lp(noise(d), 6000), 400) * 0.3
    for k in range(900):
        place(buf, hp(noise(0.01), 3000) * env_exp(0.01, 0.002) * rng.uniform(0.05, 0.3), rng.uniform(0, d - 0.02))
    save_loop('yomgir', buf, 0.45)


# ================================================================== QAL'A / INTERFEYS

def hammer():
    for v in range(3):
        d = 1.6
        buf = np.zeros(int(d * SR))
        for k in range(3):
            place(buf, mix(modal([rng.uniform(180, 240), rng.uniform(600, 800), rng.uniform(2000, 2600)], [0.06, 0.03, 0.02], [1, 0.4, 0.3], 0.3),
                           lp(noise(0.3), 3000) * env_exp(0.3, 0.006)), 0.05 + k * 0.42 + rng.uniform(0, 0.04))
        save('qurilish_%d' % v, buf, 0.75, (0.5, 0.15))


def anvil():
    d = 1.2
    x = modal([1180, 2650, 3900, 5600], [0.4, 0.25, 0.15, 0.1], [1, 0.6, 0.4, 0.2], d) + hp(noise(d), 2000) * env_exp(d, 0.004)
    save('sandon', x, 0.7, (0.5, 0.15))


def coin():
    d = 0.6
    buf = np.zeros(int(d * SR))
    for k, f in enumerate((2400, 3150, 2800)):
        place(buf, modal([f, f * 2.4], [0.12, 0.06], [0.5, 0.2], 0.4), k * 0.07)
    save('tanga', buf, 0.55)


def click():
    d = 0.06
    x = modal([1800, 3600], [0.008, 0.004], [1, 0.4], d) + hp(noise(d), 3000) * env_exp(d, 0.002) * 0.5
    save('tugma', x, 0.4)
    d = 0.25
    x = bp(noise(d), 600, 3000) * np.sin(np.pi * t_(d) / d) ** 2
    save('varaq', x, 0.35)     # panel ochilishi (qog'oz/mato shitirlashi)


def bell():
    d = 3.0
    x = modal([220, 440 * 1.19, 660 * 1.02, 880 * 1.33, 1320], [1.2, 0.9, 0.6, 0.4, 0.25], [1, 0.5, 0.4, 0.3, 0.2], d, 0.002)
    save('qongiroq', x, 0.6, (1.0, 0.2))


if __name__ == '__main__':
    for fn in [sword_clash, blade_flesh, shield_block, bow_release, arrow_fly, arrow_hit, rifle, ramrod, cannon, impact_stone, ram,
               gate_break, trebuchet, ladder, body_fall, shouts, war_cry, crowd_loop, horn, drum, horse_snort, neigh, elephant,
               wheels_loop, crickets_loop, birds_loop, wind_loop, fire_loop, rain_loop, hammer, anvil, coin, click, bell]:
        fn()
        print('ok', fn.__name__, flush=True)
    whoosh('silkish', 3, 0.3, 500, 2600)
    hooves_loop('ot_yurish', 0.9, [0.0, 0.25, 0.5, 0.75], 6)
    hooves_loop('ot_chopish', 0.42, [0.0, 0.1, 0.22], 8)
    steps_loop('qadam', 1.8, 24, 0.35)
    steps_loop('yugurish', 2.8, 24, 0.5)
    print('DONE')
