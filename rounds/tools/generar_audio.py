"""Genera assets de audio placeholder (SFX y música) para Rounds.

No requiere dependencias externas: usa solo la librería estándar.
Los archivos resultantes son reemplazables por audio real más adelante.

Uso:
    python3 tools/generar_audio.py
"""

import math
import os
import random
import struct
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR_SFX = os.path.join(RAIZ, "audio", "sfx")
DIR_MUSICA = os.path.join(RAIZ, "audio", "music")

SFX_SR = 44100
MUS_SR = 22050


def osc(kind, phase):
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0.0 else -1.0
    if kind == "saw":
        x = (phase / (2.0 * math.pi)) % 1.0
        return 2.0 * x - 1.0
    if kind == "tri":
        x = (phase / (2.0 * math.pi)) % 1.0
        return 4.0 * abs(x - 0.5) - 1.0
    return 0.0


def adsr(n, sr, a=0.005, d=0.05, s=0.7, r=0.05):
    out = []
    for i in range(n):
        t = i / sr
        if t < a:
            e = t / a
        elif t < a + d:
            e = 1.0 - (1.0 - s) * ((t - a) / d)
        else:
            tr = t - a - d
            e = s * max(0.0, 1.0 - tr / r)
        out.append(e)
    return out


def tone(sr, dur, freq_fn, kind="sine", vol=0.5, env=(0.005, 0.05, 0.7, 0.05)):
    n = int(sr * dur)
    e = adsr(n, sr, *env)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        f = freq_fn(i / sr)
        phase += 2.0 * math.pi * f / sr
        out[i] = osc(kind, phase) * e[i] * vol
    return out


def sweep(f0, f1):
    return lambda t: f0 + (f1 - f0) * t


def noise(sr, dur, vol=0.4, env=(0.002, 0.03, 0.3, 0.05), seed=0):
    rng = random.Random(seed)
    n = int(sr * dur)
    e = adsr(n, sr, *env)
    return [rng.uniform(-1.0, 1.0) * e[i] * vol for i in range(n)]


def mezclar(*pistas):
    largo = max(len(p) for p in pistas)
    out = [0.0] * largo
    for p in pistas:
        for i, v in enumerate(p):
            out[i] += v
    return out


def normalizar(samples, pico=0.85):
    mx = max((abs(s) for s in samples), default=0.0)
    if mx <= 0.0:
        return samples
    k = pico / mx
    return [s * k for s in samples]


def fades(samples, sr, ms=4.0):
    n = int(sr * ms / 1000.0)
    n = min(n, len(samples) // 2)
    out = list(samples)
    for i in range(n):
        g = i / n
        out[i] *= g
        out[-1 - i] *= g
    return out


def silencio(sr, dur):
    return [0.0] * int(sr * dur)


def nota(sr, freq, dur, kind="sine", vol=0.5):
    return tone(sr, dur, lambda t: freq, kind=kind, vol=vol)


def escribir(path, samples, sr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        data = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            data += struct.pack("<h", v)
        w.writeframes(bytes(data))
    print("  %-34s %6.1f KB" % (os.path.relpath(path, RAIZ), len(data) / 1024.0))


def secuencia(sr, freqs, dur_nota, kind="sine", vol=0.5, hueco=0.0):
    out = []
    for f in freqs:
        out += nota(sr, f, dur_nota, kind=kind, vol=vol)
        if hueco > 0.0:
            out += silencio(sr, hueco)
    return out


def generar_sfx():
    print("SFX:")
    escribir(
        os.path.join(DIR_SFX, "disparo.wav"),
        normalizar(tone(SFX_SR, 0.09, sweep(900, 180), "square", 0.5)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "salto.wav"),
        normalizar(tone(SFX_SR, 0.14, sweep(280, 720), "sine", 0.5)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "golpe.wav"),
        normalizar(
            mezclar(
                noise(SFX_SR, 0.14, 0.6, env=(0.001, 0.02, 0.2, 0.08), seed=1),
                tone(SFX_SR, 0.14, sweep(220, 90), "sine", 0.5),
            )
        ),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "muerte.wav"),
        normalizar(tone(SFX_SR, 0.55, sweep(520, 70), "saw", 0.5, env=(0.005, 0.1, 0.6, 0.25))),
        SFX_SR,
    )

    def quack_freq(t):
        return 330.0 + 40.0 * math.sin(2.0 * math.pi * 28.0 * t)

    escribir(
        os.path.join(DIR_SFX, "cuac.wav"),
        normalizar(
            mezclar(
                tone(SFX_SR, 0.17, quack_freq, "square", 0.35, env=(0.005, 0.04, 0.6, 0.06)),
                noise(SFX_SR, 0.17, 0.15, env=(0.002, 0.03, 0.25, 0.06), seed=2),
            )
        ),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "ui_mover.wav"),
        normalizar(nota(SFX_SR, 600, 0.05, "square", 0.4)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "ui_confirmar.wav"),
        normalizar(secuencia(SFX_SR, [660, 990], 0.07, "square", 0.4)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "ui_click.wav"),
        normalizar(nota(SFX_SR, 1250, 0.035, "square", 0.35)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "ronda_inicio.wav"),
        normalizar(secuencia(SFX_SR, [440, 554, 659], 0.12, "square", 0.4, hueco=0.01)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "ronda_ganada.wav"),
        normalizar(secuencia(SFX_SR, [523, 659, 784, 1046], 0.12, "square", 0.4, hueco=0.01)),
        SFX_SR,
    )
    escribir(
        os.path.join(DIR_SFX, "mejora.wav"),
        normalizar(secuencia(SFX_SR, [880, 1174, 1568], 0.08, "square", 0.4, hueco=0.005)),
        SFX_SR,
    )


def pista_kick(sr, dur, bpm):
    beat = 60.0 / bpm
    n = int(sr * dur)
    out = [0.0] * n
    t = 0.0
    while t < dur - 1e-6:
        golpe = tone(sr, 0.12, sweep(120, 45), "sine", 0.9, env=(0.001, 0.02, 0.3, 0.08))
        ini = int(t * sr)
        for i, v in enumerate(golpe):
            if ini + i < n:
                out[ini + i] += v
        t += beat * 2.0
    return out


def pista_hat(sr, dur, bpm, seed=3):
    beat = 60.0 / bpm
    n = int(sr * dur)
    out = [0.0] * n
    t = beat * 0.5
    while t < dur - 1e-6:
        golpe = noise(sr, 0.04, 0.18, env=(0.001, 0.01, 0.1, 0.02), seed=seed + int(t * 100))
        ini = int(t * sr)
        for i, v in enumerate(golpe):
            if ini + i < n:
                out[ini + i] += v
        t += beat
    return out


def pista_bajo(sr, dur, bpm, raices):
    beat = 60.0 / bpm
    n = int(sr * dur)
    out = [0.0] * n
    negras = dur / beat
    for k in range(int(round(negras))):
        raiz = raices[(k // 4) % len(raices)]
        golpe = tone(sr, beat * 0.45, lambda t, f=raiz: f, "saw", 0.28, env=(0.005, 0.05, 0.5, 0.08))
        ini = int(k * beat * sr)
        for i, v in enumerate(golpe):
            if ini + i < n:
                out[ini + i] += v
    return out


def pista_arpegio(sr, dur, bpm, raices, escala, vol=0.22):
    beat = 60.0 / bpm
    n = int(sr * dur)
    out = [0.0] * n
    paso = beat * 0.5
    pasos = int(math.ceil(dur / paso))
    for k in range(pasos):
        raiz = raices[(k // 8) % len(raices)]
        grado = escala[k % len(escala)]
        freq = raiz * (2.0 ** (grado / 12.0))
        golpe = tone(sr, paso * 0.85, lambda t, f=freq: f, "square", vol, env=(0.004, 0.04, 0.4, 0.05))
        ini = int(k * paso * sr)
        for i, v in enumerate(golpe):
            if ini + i < n:
                out[ini + i] += v
    return out


def generar_musica():
    print("Música:")
    # Nivel: synthwave en La menor, 120 BPM, 8 s (4 compases).
    dur = 8.0
    bpm = 120.0
    raices = [110.0, 87.31, 130.81, 98.0]  # A2  F2  C3  G2
    escala = [0, 3, 7, 12, 7, 3, 10, 7]
    nivel = mezclar(
        pista_bajo(MUS_SR, dur, bpm, raices),
        pista_arpegio(MUS_SR, dur, bpm, raices, escala),
        pista_kick(MUS_SR, dur, bpm),
        pista_hat(MUS_SR, dur, bpm),
    )
    escribir(os.path.join(DIR_MUSICA, "nivel.wav"), normalizar(fades(nivel, MUS_SR), 0.7), MUS_SR)

    # Menú: ambiente lento, 90 BPM, 8 s.
    dur_m = 8.0
    bpm_m = 90.0
    raices_m = [110.0, 130.81, 98.0, 87.31]
    escala_m = [0, 7, 3, 12, 7, 3, 10, 7]
    menu = mezclar(
        pista_bajo(MUS_SR, dur_m, bpm_m, raices_m),
        pista_arpegio(MUS_SR, dur_m, bpm_m, raices_m, escala_m, vol=0.16),
    )
    escribir(os.path.join(DIR_MUSICA, "menu.wav"), normalizar(fades(menu, MUS_SR), 0.6), MUS_SR)


def main():
    print("Generando audio en res://audio ...")
    generar_sfx()
    generar_musica()
    print("Listo.")


if __name__ == "__main__":
    main()
