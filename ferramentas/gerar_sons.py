#!/usr/bin/env python3
"""Gera os efeitos sonoros e a música provisórios do ACERVO GUERRA CIVIL.

Tudo é sintetizado aqui mesmo com numpy (nenhuma amostra de terceiros), então
os .wav podem ficar no repositório sem problema de licença. Para trocar um som
por um de verdade, basta salvar outro .wav com o mesmo nome em audio/sfx/.

Uso:
    python3 ferramentas/gerar_sons.py              # gera todos
    python3 ferramentas/gerar_sons.py riff ko      # gera só esses
"""

import sys
import wave
import zlib
from pathlib import Path

import numpy as np

TAXA = 22050
PASTA = Path(__file__).resolve().parent.parent / "audio" / "sfx"


# ---------------------------------------------------------------- utilidades

def amostras(segundos):
    return int(round(TAXA * segundos))


def ruido(n, rng):
    return rng.uniform(-1.0, 1.0, n)


def decai(n, tau):
    """Decaimento exponencial com constante de tempo `tau` (segundos)."""
    return np.exp(-np.arange(n) / (TAXA * tau))


def ataque(n, segundos):
    env = np.ones(n)
    k = min(n, max(1, amostras(segundos)))
    env[:k] = np.linspace(0.0, 1.0, k)
    return env


def soltura(n, segundos):
    env = np.ones(n)
    k = min(n, max(1, amostras(segundos)))
    env[n - k:] = np.linspace(1.0, 0.0, k)
    return env


def varre(n, de, ate):
    """Glissando exponencial de `de` até `ate` (Hz)."""
    return de * (ate / de) ** (np.arange(n) / max(1, n - 1))


def _vetor(valor, n):
    return np.broadcast_to(np.asarray(valor, dtype=float), (n,)).tolist()


def passa_baixa(x, corte):
    """Filtro de um polo; `corte` pode variar no tempo."""
    n = len(x)
    coef = [float(np.exp(-2.0 * np.pi * c / TAXA)) for c in _vetor(corte, n)]
    entrada = x.tolist()
    saida = [0.0] * n
    s = 0.0
    for i in range(n):
        s = entrada[i] + coef[i] * (s - entrada[i])
        saida[i] = s
    return np.array(saida)


def passa_alta(x, corte):
    return x - passa_baixa(x, corte)


def filtro(x, corte, q=1.0, modo="banda"):
    """Filtro de estado variável (Chamberlin), ressonante."""
    n = len(x)
    f = [2.0 * np.sin(np.pi * min(c, TAXA / 6.0) / TAXA) for c in _vetor(corte, n)]
    amort = 1.0 / q
    entrada = x.tolist()
    saida = [0.0] * n
    baixo = banda = 0.0
    for i in range(n):
        baixo += f[i] * banda
        alto = entrada[i] - baixo - amort * banda
        banda += f[i] * alto
        saida[i] = banda if modo == "banda" else (baixo if modo == "baixa" else alto)
    return np.array(saida)


def fase(freq, n):
    return np.cumsum(np.broadcast_to(np.asarray(freq, dtype=float), (n,))) / TAXA


def seno(freq, n):
    return np.sin(2.0 * np.pi * fase(freq, n))


def serra(freq, n):
    p = fase(freq, n)
    return 2.0 * (p - np.floor(p + 0.5))


def quadrada(freq, n, largura=0.5):
    return np.where(fase(freq, n) % 1.0 < largura, 1.0, -1.0)


def satura(x, forca):
    return np.tanh(x * forca) / np.tanh(forca)


def misturar(n, *partes):
    """Soma sinais de tamanhos diferentes (cada parte: (sinal, posição em s))."""
    saida = np.zeros(n)
    for sinal, inicio in partes:
        i = amostras(inicio)
        if i >= n:
            continue
        k = min(len(sinal), n - i)
        saida[i:i + k] += sinal[:k]
    return saida


def eco(x, atraso, retorno, mistura):
    d = amostras(atraso)
    y = x.copy()
    for i in range(d, len(y)):
        y[i] += y[i - d] * retorno
    return x * (1.0 - mistura) + y * mistura


def reverb(x, mistura=0.25, tamanho=1.0, cauda=0.0):
    """Reverb de Schroeder simples (4 pentes em paralelo e 2 passa-tudo)."""
    if cauda > 0.0:
        x = np.concatenate([x * soltura(len(x), 0.05), np.zeros(amostras(cauda))])
    n = len(x)
    entrada = x.tolist()
    soma = [0.0] * n
    for atraso, ganho in ((0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0437, 0.74)):
        d = amostras(atraso * tamanho)
        linha = [0.0] * n
        for i in range(n):
            v = entrada[i] + (linha[i - d] * ganho if i >= d else 0.0)
            linha[i] = v
            soma[i] += v
    for atraso, g in ((0.005, 0.7), (0.0017, 0.7)):
        d = amostras(atraso)
        saida = [0.0] * n
        for i in range(n):
            atrasado = soma[i - d] if i >= d else 0.0
            anterior = saida[i - d] if i >= d else 0.0
            saida[i] = -g * soma[i] + atrasado + g * anterior
        soma = saida
    molhado = passa_baixa(np.array(soma) * 0.25, 4500)
    return x * (1.0 - mistura) + molhado * mistura


def corda(freq, segundos, rng, abafada=False, brilho=0.5):
    """Corda dedilhada (Karplus-Strong)."""
    n = amostras(segundos)
    periodo = max(2, int(round(TAXA / freq - 0.5)))
    perda = 0.94 if abafada else 0.996
    buf = passa_baixa(ruido(periodo, rng), 2500 if abafada else 6000).tolist()
    saida = [0.0] * n
    for i in range(n):
        if i < periodo:
            saida[i] = buf[i]
        else:
            a = saida[i - periodo]
            b = saida[i - periodo - 1] if i > periodo else buf[-1]
            saida[i] = perda * ((1.0 - brilho) * a + brilho * b)
    return np.array(saida)


def baque(n, de, ate, tau, rng, brilho=900.0):
    corpo = seno(varre(n, de, ate), n) * decai(n, tau)
    textura = passa_baixa(ruido(n, rng), brilho) * decai(n, tau * 0.5)
    return corpo + textura * 0.6


def silencio_no_fim(x, segundos=0.01):
    return x * soltura(len(x), segundos)


# ---------------------------------------------------------------- efeitos

def vento_fraco(rng):
    n = amostras(0.15)
    u = (np.arange(n) / n) ** 0.6
    x = filtro(ruido(n, rng), varre(n, 700, 2600), q=1.3) * np.sin(np.pi * u) ** 1.5
    return x, 0.5


def vento_forte(rng):
    n = amostras(0.24)
    u = (np.arange(n) / n) ** 0.55
    env = np.sin(np.pi * u) ** 1.5
    alto = filtro(ruido(n, rng), varre(n, 450, 1900), q=1.6)
    grave = filtro(ruido(n, rng), varre(n, 220, 700), q=1.2)
    return (alto + grave * 0.7) * env, 0.62


def acerto_fraco(rng):
    n = amostras(0.16)
    corpo = seno(varre(n, 190, 70), n) * decai(n, 0.045)
    estalo = passa_baixa(ruido(n, rng), 3500) * decai(n, 0.012)
    clique = passa_alta(ruido(n, rng), 2500) * decai(n, 0.003)
    return satura(corpo * 0.9 + estalo * 0.7 + clique * 0.4, 2.0), 0.72


def acerto_forte(rng):
    n = amostras(0.34)
    corpo = seno(varre(n, 150, 42), n) * decai(n, 0.09)
    soco = passa_baixa(ruido(n, rng), varre(n, 4000, 300)) * decai(n, 0.03)
    estalo = passa_alta(ruido(n, rng), 3000) * decai(n, 0.006)
    return satura(corpo + soco * 0.8 + estalo * 0.5, 3.0), 0.92


def _faiscas(n, rng, de=250.0, ate=900.0, troca=0.012):
    passo = amostras(troca)
    freqs = np.repeat(rng.uniform(de, ate, n // passo + 1), passo)[:n]
    zumbido = quadrada(freqs, n) * 0.6 + ruido(n, rng) * 0.4
    return filtro(zumbido, 1800, q=0.9)


def acerto_especial(rng):
    n = amostras(0.55)
    corpo = seno(varre(n, 160, 38), n) * decai(n, 0.14)
    soco = passa_baixa(ruido(n, rng), varre(n, 5000, 250)) * decai(n, 0.045)
    estalo = passa_alta(ruido(n, rng), 3000) * decai(n, 0.007)
    zap = _faiscas(n, rng) * decai(n, 0.09)
    x = satura(corpo * 1.1 + soco * 0.8 + estalo * 0.5 + zap * 0.45, 2.6)
    return reverb(x, 0.22, 0.8), 0.95


def bloqueio(rng):
    n = amostras(0.15)
    tom = seno(520.0, n) * decai(n, 0.025) + seno(1310.0, n) * decai(n, 0.014) * 0.5
    chiado = filtro(ruido(n, rng), 2200, q=3.0) * decai(n, 0.02)
    grave = seno(varre(n, 160, 90), n) * decai(n, 0.03)
    return satura(tom * 0.6 + chiado * 0.9 + grave * 0.5, 1.5), 0.7


def pulo(rng):
    n = amostras(0.12)
    env = ataque(n, 0.02) * decai(n, 0.04)
    return filtro(ruido(n, rng), varre(n, 500, 1800), q=1.0) * env, 0.38


def aterrissar(rng):
    n = amostras(0.12)
    return baque(n, 110, 55, 0.03, rng), 0.5


def queda(rng):
    n = amostras(0.5)
    chacoalho = filtro(ruido(n, rng), 650, q=1.5) * decai(n, 0.09)
    x = misturar(n, (baque(n, 95, 38, 0.08, rng, 1200), 0.0), (baque(n, 80, 40, 0.05, rng) * 0.6, 0.075),
                 (chacoalho * 0.5, 0.02))
    return satura(x, 2.0), 0.85


def ko(rng):
    n = amostras(1.4)
    boom = seno(varre(n, 110, 28), n) * decai(n, 0.4)
    soco = passa_baixa(ruido(n, rng), varre(n, 5000, 200)) * decai(n, 0.08)
    estalo = passa_alta(ruido(n, rng), 2500) * decai(n, 0.01)
    x = satura(boom * 1.2 + soco + estalo * 0.6, 2.5)
    x = reverb(x, 0.35, 1.4, cauda=0.4)
    # zumbido no ouvido depois da pancada
    m = len(x)
    x += seno(1150.0, m) * ataque(m, 0.08) * decai(m, 0.5) * 0.06
    return silencio_no_fim(x, 0.2), 1.0


def _acorde_distorcido(freqs, segundos, rng, abafada):
    n = amostras(segundos)
    x = misturar(n, *[(corda(f, segundos, rng, abafada, 0.45), k * 0.006) for k, f in enumerate(freqs)])
    x = satura(x * 1.4, 7.0)
    x = passa_baixa(passa_baixa(x, 2600), 4200)
    x = passa_alta(x, 90)
    if abafada:
        x = passa_baixa(x, 1100) * decai(n, 0.07)
    return x * soltura(n, 0.03)


def riff(rng):
    """Power chords em Mi menor: dois abafados e um aberto, bem distorcido."""
    mi = [82.41, 123.47, 164.81]
    sol = [98.0, 146.83, 196.0]
    n = amostras(0.78)
    x = misturar(n,
                 (_acorde_distorcido(mi, 0.11, rng, True), 0.0),
                 (_acorde_distorcido(mi, 0.11, rng, True), 0.115),
                 (_acorde_distorcido(sol, 0.55, rng, False), 0.23))
    return silencio_no_fim(x, 0.06), 0.9


def energizar(rng):
    n = amostras(0.7)
    f = varre(n, 70, 300)
    zumbido = serra(f, n) * (0.65 + 0.35 * seno(18.0, n))
    zumbido = passa_baixa(zumbido, varre(n, 400, 3500))
    estalos = np.zeros(n)
    for _ in range(26):
        i = int(n * rng.random() ** 0.7)
        k = min(n - i, amostras(0.008))
        estalos[i:i + k] += passa_alta(ruido(k, rng), 2000) * decai(k, 0.002) * rng.uniform(0.3, 1.0)
    x = (zumbido * 0.8 + estalos * 0.7) * ataque(n, 0.06) * soltura(n, 0.14)
    return satura(x, 1.8), 0.7


def guitarra_gira(rng):
    n = amostras(0.28)
    giro = filtro(ruido(n, rng), 1100, q=2.0) * (0.5 + 0.5 * seno(14.0, n))
    zumbido = seno(varre(n, 300, 340), n) * 0.1
    return (giro + zumbido) * np.sin(np.pi * np.arange(n) / n), 0.5


def choque(rng):
    n = amostras(0.3)
    x = _faiscas(n, rng, 180, 1100, 0.007)
    x = passa_alta(x, 300)
    piscar = 0.6 + 0.4 * (np.repeat(rng.random(n // 60 + 1), 60)[:n] > 0.3)
    return satura(x * decai(n, 0.1) * piscar * 1.6, 2.0), 0.7


def berimbau(rng):
    """Corda de aço com a cabaça abrindo e fechando (o "uau") e o caxixi."""
    n = amostras(0.9)
    arame = corda(116.0, 0.9, rng, brilho=0.25)
    cabaca = filtro(arame, 750 + 380 * np.sin(2.0 * np.pi * 4.5 * np.arange(n) / TAXA - 1.2), q=2.5)
    x = arame * 0.45 + cabaca * 0.9
    caxixi = passa_alta(ruido(n, rng), 5000)
    x += misturar(n, (caxixi * decai(n, 0.03) * 0.5, 0.0), (caxixi * decai(n, 0.025) * 0.3, 0.17))
    return silencio_no_fim(x * soltura(n, 0.25), 0.05), 0.8


def pegadas(rng):
    """Passos abafados com um brilho mágico (as pegadas ao contrário do Curupira)."""
    n = amostras(0.34)
    folhas = filtro(ruido(n, rng), 3000, q=0.8)
    x = misturar(n, (baque(n, 120, 60, 0.025, rng, 1200), 0.0), (baque(n, 110, 55, 0.025, rng, 1200) * 0.8, 0.13),
                 (folhas * decai(n, 0.02) * 0.4, 0.0), (folhas * decai(n, 0.02) * 0.3, 0.13))
    brilho = (seno(1760.0, n) + seno(2637.0, n) * 0.7) * ataque(n, 0.02) * decai(n, 0.09) * 0.12
    return x + brilho, 0.55


def agarrar(rng):
    n = amostras(0.22)
    tremido = passa_baixa(np.abs(ruido(n, rng)), 60) * 3.0
    pano = filtro(ruido(n, rng), 1300, q=0.8) * tremido * decai(n, 0.06)
    return satura(pano + baque(n, 130, 60, 0.04, rng) * 0.8, 1.5), 0.75


def round_(rng):
    """Gongo grave com pancada: abre cada round."""
    n = amostras(1.5)
    t = np.arange(n) / TAXA
    gongo = np.zeros(n)
    for f, amp, tau in ((96, 1.0, 0.9), (151, 0.6, 0.7), (212, 0.5, 0.6), (287, 0.35, 0.5), (406, 0.25, 0.4),
                        (557, 0.15, 0.3)):
        gongo += amp * seno(f * (1.0 + 0.002 * np.sin(2.0 * np.pi * 3.0 * t)), n) * decai(n, tau)
    boom = seno(varre(n, 90, 35), n) * decai(n, 0.3)
    x = satura(gongo * 0.5 + boom, 1.5) * ataque(n, 0.004)
    return silencio_no_fim(reverb(x, 0.3, 1.2), 0.2), 0.9


def lutem(rng):
    n = amostras(1.1)
    acorde = np.zeros(n)
    for f in (110.0, 164.81, 220.0, 261.63, 329.63):
        for desafino in (-0.004, 0.0, 0.004):
            acorde += serra(f * (1.0 + desafino), n)
    acorde = passa_baixa(acorde / 15.0, varre(n, 5000, 600)) * ataque(n, 0.005) * decai(n, 0.35)
    prato = passa_alta(ruido(n, rng), 5000) * decai(n, 0.5) * 0.35
    boom = seno(varre(n, 100, 40), n) * decai(n, 0.25)
    x = satura(acorde * 2.0 + prato + boom, 1.8)
    return silencio_no_fim(reverb(x, 0.3), 0.15), 0.9


def tique(rng):
    n = amostras(0.05)
    x = seno(1900.0, n) * decai(n, 0.008) + seno(3100.0, n) * decai(n, 0.004) * 0.5
    x += passa_alta(ruido(n, rng), 4000) * decai(n, 0.001) * 0.4
    return x, 0.6


def menu_mover(rng):
    n = amostras(0.06)
    return passa_baixa(quadrada(740.0, n) * decai(n, 0.015), 4000), 0.45


def menu_ok(rng):
    n = amostras(0.26)
    a = passa_baixa(quadrada(660.0, n) * decai(n, 0.02), 4000)
    b = passa_baixa(quadrada(990.0, n) * decai(n, 0.05), 4500)
    return eco(misturar(n, (a, 0.0), (b, 0.06)), 0.07, 0.3, 0.4), 0.5


def chuva(rng):
    """Chuva constante em loop (6 s, o fim emenda no começo)."""
    duracao, extra = 6.0, 0.6
    n = amostras(duracao + extra)
    chiado = passa_baixa(passa_alta(ruido(n, rng), 400), 6000) * 0.5
    grave = passa_baixa(ruido(n, rng), 250) * 0.9
    gotas = np.zeros(n)
    k = amostras(0.03)
    for _ in range(1400):
        i = rng.integers(0, n - k)
        f = rng.uniform(1400, 4800)
        gotas[i:i + k] += seno(f, k) * decai(k, rng.uniform(0.002, 0.006)) * rng.uniform(0.05, 0.4)
    x = chiado + grave + gotas
    return _emendar(x, amostras(extra)), 0.55


def _emendar(x, f):
    """Faz o fim do som emendar no começo (para tocar em loop sem estalo)."""
    total = len(x) - f
    saida = x[:total].copy()
    u = np.linspace(0.0, 1.0, f)
    saida[:f] = x[:f] * np.sin(0.5 * np.pi * u) + x[total:] * np.cos(0.5 * np.pi * u)
    return saida


# ---------------------------------------------------------------- música

def musica(rng):
    """Synthwave escuro com batida de funk carioca (130 BPM, 8 compassos em loop)."""
    bpm = 130.0
    passo = 60.0 / bpm / 4.0
    compassos = 8
    total = amostras(passo * 16 * compassos)
    n = total + amostras(2.5)

    def instrumento(segundos):
        return amostras(segundos)

    # bateria
    nb = instrumento(0.5)
    bumbo = seno(varre(nb, 165, 42), nb) * decai(nb, 0.22) + passa_alta(ruido(nb, rng), 3000) * decai(nb, 0.002) * 0.3
    bumbo = satura(bumbo, 2.2) * soltura(nb, 0.12)
    nc = instrumento(0.3)
    palma = np.zeros(nc)
    for k in range(3):
        rajada = filtro(ruido(nc, rng), 1200, q=0.8)
        palma += misturar(nc, (rajada * decai(nc, 0.006 if k < 2 else 0.06), k * 0.009))
    palma = palma + seno(varre(nc, 210, 170), nc) * decai(nc, 0.04) * 0.5
    nh = instrumento(0.06)
    chimbal = passa_alta(ruido(nh, rng), 7000) * decai(nh, 0.012)
    nt = instrumento(0.1)
    tamborim = seno(varre(nt, 950, 620), nt) * decai(nt, 0.02) + passa_alta(ruido(nt, rng), 3000) * decai(nt, 0.008) * 0.6

    bumbos = [0, 3, 6, 8, 11, 14]
    palmas = [4, 12]
    tamborins = [2, 7, 10, 15]

    progressao = [  # (baixo, notas do pad) — Lá menor, Fá, Ré menor, Mi
        (110.0, [220.0, 261.63, 329.63]),
        (87.31, [174.61, 220.0, 261.63]),
        (73.42, [146.83, 174.61, 220.0]),
        (82.41, [164.81, 207.65, 246.94]),
    ]

    bateria = np.zeros(n)
    baixo = np.zeros(n)
    arpejo = np.zeros(n)
    pad = np.zeros(n)
    abaixa = np.ones(n)  # "sidechain": o pad abaixa a cada bumbo

    na = instrumento(0.3)
    nbx = instrumento(passo * 2.2)
    for c in range(compassos):
        raiz, notas = progressao[(c // 2) % 4]
        inicio_compasso = c * 16 * passo
        for s in range(16):
            t = inicio_compasso + s * passo
            i = amostras(t)
            if s in bumbos:
                bateria[i:i + nb] += bumbo[:n - i] * 0.95
                k = min(n - i, amostras(0.25))
                abaixa[i:i + k] *= 1.0 - 0.55 * decai(k, 0.08)
                # baixo acompanhando o bumbo
                corpo = serra(raiz, nbx) * 0.7 + seno(raiz / 2.0, nbx) * 0.55
                corpo = passa_baixa(corpo, varre(nbx, 1400, 180)) * decai(nbx, 0.12) * soltura(nbx, 0.02)
                baixo[i:i + nbx] += corpo[:n - i]
            if s in palmas:
                bateria[i:i + nc] += palma[:n - i] * 0.5
            if s in tamborins:
                bateria[i:i + nt] += tamborim[:n - i] * 0.16
            if s % 2 == 0:
                bateria[i:i + nh] += chimbal[:n - i] * (0.12 if s % 4 == 2 else 0.07)
            # arpejo neon na segunda metade
            if c >= 4:
                nota = notas[s % 3] * (2.0 if s % 6 < 3 else 4.0)
                som = passa_baixa(quadrada(nota, na, 0.3) * decai(na, 0.06), 3000)
                arpejo[i:i + na] += som[:n - i] * 0.07
        # pad do acorde (2 compassos por acorde, com crossfade)
        if c % 2 == 0:
            dur = 32 * passo + 0.8
            m = instrumento(dur)
            som = np.zeros(m)
            for f in notas:
                for desafino in (-0.0045, 0.0, 0.0045):
                    som += serra(f * (1.0 + desafino), m)
            lfo = 900 + 300 * np.sin(2.0 * np.pi * 0.25 * np.arange(m) / TAXA)
            som = passa_baixa(passa_baixa(som / 9.0, lfo), 1800) * ataque(m, 0.35) * soltura(m, 0.8)
            i = amostras(inicio_compasso)
            pad[i:i + m] += som[:n - i]

    arpejo = eco(arpejo, passo * 3, 0.35, 0.45)
    mix = bateria * 0.9 + baixo * 0.55 + (pad * 0.6 + arpejo * 1.3) * abaixa
    # emenda o loop: o que passou do fim volta para o começo
    sobra = mix[total:]
    mix = mix[:total].copy()
    mix[:len(sobra)] += sobra
    return satura(mix, 1.1), 0.8


# ---------------------------------------------------------------- saída

SONS = {
    "vento_fraco": vento_fraco, "vento_forte": vento_forte, "acerto_fraco": acerto_fraco,
    "acerto_forte": acerto_forte, "acerto_especial": acerto_especial, "bloqueio": bloqueio, "pulo": pulo,
    "aterrissar": aterrissar, "queda": queda, "ko": ko, "riff": riff, "energizar": energizar,
    "guitarra_gira": guitarra_gira, "choque": choque, "berimbau": berimbau, "pegadas": pegadas,
    "agarrar": agarrar, "round": round_, "lutem": lutem, "tique": tique, "menu_mover": menu_mover,
    "menu_ok": menu_ok, "chuva": chuva, "musica": musica,
}


LOOPS = ("chuva", "musica")


def salvar(nome, sinal, pico):
    sinal = np.nan_to_num(sinal)
    if nome not in LOOPS:
        # tira o nível DC e evita estalo no começo e no fim
        sinal = passa_alta(sinal, 25)
        sinal = sinal * ataque(len(sinal), 0.0006) * soltura(len(sinal), 0.008)
    maior = float(np.max(np.abs(sinal))) or 1.0
    dados = np.clip(sinal / maior * pico, -1.0, 1.0)
    pcm = (dados * 32767).astype("<i2")
    caminho = PASTA / f"{nome}.wav"
    with wave.open(str(caminho), "wb") as arq:
        arq.setnchannels(1)
        arq.setsampwidth(2)
        arq.setframerate(TAXA)
        arq.writeframes(pcm.tobytes())
    return caminho, len(pcm) / TAXA


def main(nomes):
    PASTA.mkdir(parents=True, exist_ok=True)
    for nome in nomes or SONS:
        if nome not in SONS:
            sys.exit(f"som desconhecido: {nome}")
        rng = np.random.default_rng(zlib.crc32(nome.encode()))
        sinal, pico = SONS[nome](rng)
        caminho, segundos = salvar(nome, sinal, pico)
        print(f"{caminho.name:22s} {segundos:5.2f} s")


if __name__ == "__main__":
    main(sys.argv[1:])
