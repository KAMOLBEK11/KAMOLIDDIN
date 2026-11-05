"""Foydalanuvchi yuborgan ovozlarni o'yin formatiga keltirish: kesish, jimlikni olib tashlash, balandlikni tenglash, halqa qilish."""
import numpy as np, os, subprocess
from scipy.io import wavfile
from scipy import signal
SR = 44100
OUT = 'out'
os.makedirs(OUT, exist_ok=True)

def rd(k):
    sr, x = wavfile.read('w/%s.wav' % k)
    return x.astype(np.float32) / 32768

def cut(x, a=None, b=None):
    return x[int((a or 0) * SR): (int(b * SR) if b else None)]

def hpf(x, f=35):
    sos = signal.butter(2, f / (SR / 2), 'high', output='sos')
    return signal.sosfilt(sos, x)

def trim(x, db=-45, keep=0.005):
    e = np.abs(x)
    thr = e.max() * 10 ** (db / 20)
    idx = np.nonzero(e > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(keep * SR)); b = min(len(x), idx[-1] + int(0.05 * SR))
    return x[a:b]

def fade(x, fi=0.003, fo=0.05):
    x = x.copy(); a, b = int(fi * SR), min(int(fo * SR), len(x) // 3)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b) ** 2
    return x

def peak(x, p=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * p

def rmsn(x, db=-20, pmax=0.95):
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x * (10 ** (db / 20) / r)
    m = np.max(np.abs(y))
    if m > pmax:   # yumshoq cheklash (keskin cho'qqilar kesilmasin)
        y = np.tanh(y / pmax * 1.2) * pmax / np.tanh(1.2) if m > pmax * 1.5 else y / m * pmax
    return y

def loop(x, xf=1.0):
    n = int(xf * SR)
    w = np.linspace(0, 1, n)
    return np.concatenate([x[-n:] * np.sqrt(1 - w) + x[:n] * np.sqrt(w), x[n:-n]])

def tempo(x, f):
    import tempfile
    wavfile.write('/tmp/claude-0/t_in.wav', SR, (x * 32767).astype(np.int16))
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', '/tmp/claude-0/t_in.wav', '-af', 'atempo=%f' % f, '/tmp/claude-0/t_out.wav'], check=True)
    return rd2('/tmp/claude-0/t_out.wav')

def rd2(p):
    sr, x = wavfile.read(p)
    return x.astype(np.float32) / 32768

made = []
def save(name, x):
    p = os.path.join(OUT, name + '.wav')
    wavfile.write(p, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    made.append((name, len(x) / SR))

def shot(name, k, a=None, b=None, p=0.9, db=-45):
    save(name, fade(peak(trim(hpf(cut(rd(k), a, b)), db), p)))

def amb(name, k, a=None, b=None, db=-20, xf=1.5, hp=40):
    save(name, loop(rmsn(hpf(cut(rd(k), a, b), hp), db), xf))

# ---------------- qurollar
for i, k in enumerate(['41', '52', '63', '42', '60', '72']):
    shot('qilich_%d' % i, k, p=0.85)
for i, (a, b) in enumerate([(0.0, 0.55), (0.55, 1.12), (1.12, 2.3)]):
    shot('qilich_%d' % (6 + i), '70', a, b, p=0.8)
shot('qalqon_0', '58', p=0.8); shot('qalqon_1', '59', p=0.8)
shot('qilich_sugurish_0', '61', p=0.7); shot('qilich_sugurish_1', '62', p=0.7); shot('qilich_sugurish_2', '18', p=0.7)
shot('qilich_tushish', '57', p=0.6)
shot('kamon_0', '43', p=0.75)
shot('kamon_tortish', '47', p=0.6, db=-40)
shot('oq_uchish_0', '48', p=0.6)
shot('oq_tegish_0', '44', p=0.7)
shot('oq_odam_0', '45', p=0.7)
shot('oq_yomgiri', '46', 0.85, 4.7, p=0.8)
shot('miltiq_0', '50', p=0.95, db=-55)
shot('miltiq_tegish_0', '51', p=0.7); shot('miltiq_tegish_1', '54', p=0.7)
shot('miltiq_kurok', '53', p=0.5)
shot('top_0', '55', p=0.97, db=-55); shot('top_1', '56', p=0.95, db=-55); shot('top_2', '71', p=0.95, db=-55)
shot('top_3', '77', 12.25, 16.6, p=0.9, db=-60)
shot('tosh_zarba_0', '64', p=0.9); shot('tosh_zarba_1', '66', p=0.9); shot('tosh_zarba_2', '69', p=0.9)
shot('darvoza_sinish', '68', p=0.95)
# ---------------- odamlar
for i, (a, b) in enumerate([(0.5, 2.2), (2.2, 4.2), (5.5, 7.0)]):
    shot('urra_%d' % i, '25', a, b, p=0.85)
shot('urra_3', '17', p=0.8)
shot('qomondon', '30', p=0.85)
shot('galaba', '13', p=0.85)
shot('maglubiyat', '29', p=0.8)
shot('ah_0', '21', p=0.7); shot('ah_1', '24', p=0.7); shot('ah_2', '26', 0.7, 1.7, p=0.7)
for i, k in enumerate(['28', '31', '32', '34', '36', '37', '38']):
    shot('qichqiriq_%d' % i, k, p=0.75)
shot('yiqilish_qichqiriq', '33', p=0.8)
# ---------------- hayvonlar
shot('ot_kishnash_0', '03', p=0.75); shot('ot_kishnash_1', '04', p=0.75); shot('ot_kishnash_2', '08', p=0.75)
shot('ot_pishqirish_0', '05', p=0.7)
shot('fil_0', '01', p=0.85); shot('fil_1', '10', p=0.85)
# ---------------- halqalar (fon)
amb('ot_chopish_0', '02', db=-20, xf=0.4); amb('ot_chopish_1', '06', 0, 30, db=-19, xf=1.0, hp=60); amb('ot_chopish_2', '07', db=-19, xf=0.5)
amb('ot_yurish', '12', 0.2, 6.3, db=-22, xf=0.6)
x = hpf(rd('14'))
amb('qadam', '14', 0.1, 8.6, db=-18, xf=0.6)
save('yugurish', loop(rmsn(tempo(cut(x, 0.1, 8.6), 1.45), -18), 0.4))
amb('zirh', '67', db=-28, xf=0.5)
amb('nogora_loop_0', '79', db=-17, xf=0.08); amb('nogora_loop_1', '89', db=-17, xf=0.3)
amb('nogora_afrika', '78', db=-17, xf=0.1)
amb('tun', '76', 5, 50, db=-27, xf=2.0)
amb('kunduz', '86', 20, 80, db=-27, xf=2.0)
amb('shamol_0', '87', 0, 32, db=-24, xf=2.0); amb('shamol_1', '82', 0, 15.5, db=-24, xf=2.0)
amb('yomgir', '75', 2, 50, db=-22, xf=2.0)
amb('olov', '84', 10, 50, db=-22, xf=1.0)
amb('daryo_0', '80', 5, 45, db=-24, xf=2.0); amb('daryo_1', '81', 5, 45, db=-24, xf=2.0)
amb('bozor', '16', db=-22, xf=1.5)
amb('masjid', '73', db=-30, xf=1.5)
shot('karnay', '83', p=0.85)
shot('qongiroq', '15', p=0.7, db=-55)
for n, d in made:
    print('%-22s %5.1fs' % (n, d))
print(len(made))
