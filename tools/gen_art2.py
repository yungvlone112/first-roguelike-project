"""Графика второй волны: темы этажей (храм, подвал, коридор), аномалии, существа, торговец, лунные лучи."""
import os, math, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_art import *   # палитра и помощники C, mix

# дополнительные цвета
VER0 = (74, 14, 18); VER1 = (122, 26, 28); VER2 = (168, 48, 40)          # киноварь (храм)
WH0 = (92, 84, 88); WH1 = (126, 116, 118); WH2 = (158, 148, 146)         # выцветшая побелка
GH0 = (96, 104, 140); GH1 = (150, 158, 192); GH2 = (206, 212, 232)       # призрачно-голубой
MS0 = (30, 42, 32); MS1 = (48, 64, 42); MS2 = (78, 96, 58)               # мох
CB0 = (26, 28, 38); CB1 = (40, 44, 58); CB2 = (62, 68, 84); CB3 = (92, 98, 116)   # сырой камень
T = f"{OUT}/tiles"; PR = f"{OUT}/props"


# ======================= ПОЛ =======================
def temple_atlas():
    """Каменные плиты 32x32 (2x2 тайла), два варианта; мох в швах."""
    a = C(32, 64)
    for v in range(2):
        rng = np.random.RandomState(40 + v)
        oy = v * 32
        base = [(54, 50, 64), (62, 58, 72)][v]
        for y in range(32):
            for x in range(32):
                n = rng.rand()
                col = base
                if n < 0.2: col = mix(base, INK, 0.25)
                elif n > 0.9: col = mix(base, ST2, 0.5)
                a.px(x, oy + y, col)
        for x in range(32):
            a.px(x, oy, (20, 17, 26)); a.px(x, oy + 1, (36, 31, 46))
        for y in range(32):
            a.px(0, oy + y, (20, 17, 26)); a.px(1, oy + y, (36, 31, 46))
        for x in range(32): a.px(x, oy + 31, mix(tuple(a.a[oy + 31, x, :3]), INK, 0.35))
        for y in range(32): a.px(31, oy + y, mix(tuple(a.a[oy + y, 31, :3]), INK, 0.35))
        for _ in range(3):   # мох в шве
            x0 = rng.randint(2, 28); y0 = rng.choice([0, 1])
            for k in range(rng.randint(3, 8)):
                a.px(x0 + k, oy + y0, MS1); a.px(x0 + k, oy + y0 + 1, MS0 if k % 2 else MS2)
        if v == 1:   # трещина
            p = [(6, 6), (9, 10), (8, 15), (12, 19), (14, 25)]
            for q, r in zip(p, p[1:]): a.line(q[0], oy + q[1], r[0], oy + r[1], (14, 11, 18))
    a.save(f"{T}/temple_atlas.png")


def cellar_atlas():
    """Булыжник/кирпич 32x16 (2x1 тайла), два варианта, сырой."""
    a = C(32, 32)
    for v in range(2):
        rng = np.random.RandomState(50 + v)
        oy = v * 16
        for y in range(16):
            for x in range(32):
                col = CB1 if rng.rand() > 0.15 else CB0
                if rng.rand() > 0.93: col = CB2
                a.px(x, oy + y, col)
        # кирпичи 16x8 в раскладку «в разбежку»
        for row in range(2):
            y0 = oy + row * 8
            for x in range(32): a.px(x, y0, (16, 17, 24))
            off = 0 if row == 0 else 8
            for bx in range(off, 32 + 16, 16):
                for y in range(y0, y0 + 8): a.px(bx % 32, y, (16, 17, 24))
            for x in range(32): a.px(x, y0 + 1, mix(tuple(a.a[y0 + 1, x, :3]), CB3, 0.25))
        for _ in range(5):   # мокрый блеск
            a.px(rng.randint(2, 30), oy + rng.randint(2, 14), CB3)
        if v == 1:
            for _ in range(6): a.px(rng.randint(0, 32), oy + rng.randint(0, 16), MS1)
    a.save(f"{T}/cellar_atlas.png")


def ov_moss():
    c = C(16, 16); rng = np.random.RandomState(61)
    for _ in range(3):
        cx, cy = rng.randint(3, 13), rng.randint(3, 13)
        for _ in range(16):
            c.px(cx + rng.randint(-3, 4), cy + rng.randint(-2, 3), [MS0, MS1, MS2][rng.randint(0, 3)], 215)
    c.save(f"{T}/floor_moss.png")


def ov_leaves():
    c = C(16, 16); rng = np.random.RandomState(62)
    for _ in range(5):
        x, y = rng.randint(1, 14), rng.randint(1, 14)
        col = [(98, 52, 34), (120, 70, 38), (74, 40, 30), (140, 92, 46)][rng.randint(0, 4)]
        c.px(x, y, col, 235); c.px(x + 1, y, col, 235); c.px(x, y + 1, mix(col, INK, 0.3), 235)
    c.save(f"{T}/floor_leaves.png")


def ov_wet():
    c = C(16, 16); rng = np.random.RandomState(63)
    for y in range(16):
        for x in range(16):
            d = math.hypot((x - 8) / 7.2, (y - 8) / 5.0) + (rng.rand() - 0.5) * 0.45
            if d < 0.7: c.px(x, y, (10, 12, 22), 170)
            elif d < 1.0: c.px(x, y, (16, 18, 30), 90)
    c.px(5, 7, CB3, 200); c.px(6, 7, CB2, 200); c.px(10, 9, CB3, 200)
    c.save(f"{T}/floor_wet.png")


def trail():
    c = C(8, 4)
    for (x, y, a) in [(0, 1, 150), (1, 1, 210), (2, 1, 230), (3, 2, 235), (4, 1, 235), (5, 1, 215), (6, 2, 170), (2, 2, 200), (4, 2, 190), (7, 1, 110)]:
        c.px(x, y, CR2, a)
    c.px(3, 1, CR3, 220)
    c.save(f"{OUT}/fx_trail.png")


# ======================= СТЕНЫ (темы) =======================
def base_temple():
    c = C(16, 16); rng = np.random.RandomState(71)
    for y in range(16):
        for x in range(16):
            r = rng.rand(); col = WH0
            if r < 0.18: col = mix(WH0, INK, 0.3)
            elif r > 0.86: col = WH1
            elif r > 0.97: col = WH2
            if y >= 9: col = mix(col, INK, 0.12 * (y - 8) / 4)
            c.px(x, y, col)
    for x in range(16):   # красная балка сверху, тёмный плинтус
        c.px(x, 0, INK); c.px(x, 1, VER0); c.px(x, 2, VER1)
        c.px(x, 13, BR1); c.px(x, 14, BR0); c.px(x, 15, INK)
    for y in range(4, 12):   # потёки сырости
        if y % 3 == 0: c.px(3, y, mix(WH0, INK, 0.45)); c.px(11, y + 1 if y < 11 else y, mix(WH0, INK, 0.4))
    return c


def base_cellar():
    c = C(16, 16); rng = np.random.RandomState(72)
    for y in range(16):
        for x in range(16):
            col = CB1 if rng.rand() > 0.2 else CB0
            if rng.rand() > 0.92: col = CB2
            c.px(x, y, col)
    for row in range(2):   # блоки 16x8 в разбежку
        y0 = row * 8
        for x in range(16): c.px(x, y0, (14, 15, 22)); c.px(x, y0 + 1, mix(tuple(c.a[y0 + 1, x, :3]), CB3, 0.2))
        bx = 0 if row == 0 else 8
        for y in range(y0, y0 + 8): c.px(bx, y, (14, 15, 22)); c.px((bx + 8) % 16, y, (14, 15, 22))
    for x in range(16): c.px(x, 15, INK)
    return c


def wall_temple():
    base_temple().save(f"{T}/wall_temple.png")


def wall_temple_post():
    c = base_temple()
    for y in range(16):
        for x in range(4, 12):
            col = {4: VER0, 5: VER1, 6: VER2, 7: VER1, 8: VER1, 9: VER0, 10: VER0, 11: INK}[x]
            c.px(x, y, col)
    for (x, y) in [(5, 6), (9, 10), (6, 12)]: c.px(x, y, BR1)
    for x in range(3, 13): c.px(x, 1, BR0); c.px(x, 2, BR1)
    c.save(f"{T}/wall_temple_post.png")


def wall_cellar():
    base_cellar().save(f"{T}/wall_cellar.png")


def wall_cellar_post():
    c = base_cellar()
    for y in range(16):
        for x in range(4, 12):
            col = BR1 if x in (5, 6) else (BR0 if x < 10 else INK)
            if x == 4 or x == 11: col = INK
            c.px(x, y, col)
    for y in (3, 11):
        for x in range(4, 12): c.px(x, y, N1); c.px(x, y + 1, N3)
    c.save(f"{T}/wall_cellar_post.png")


def wall_cap_stone():
    c = C(16, 16); rng = np.random.RandomState(73)
    for y in range(16):
        for x in range(16):
            col = (22, 24, 34) if rng.rand() > 0.2 else (30, 33, 46)
            c.px(x, y, col)
    for x in range(16): c.px(x, 0, CB2); c.px(x, 7, (12, 13, 18)); c.px(x, 15, (12, 13, 18))
    for y in range(0, 7): c.px(7, y, (12, 13, 18))
    for y in range(8, 15): c.px(0, y, (12, 13, 18)); c.px(15, y, (12, 13, 18))
    c.save(f"{T}/wall_cap_stone.png")


# --- накладки в стиле темы: функция рисует поверх готовой основы ---
def deco(base_fn, kind, name):
    c = base_fn()
    rng = np.random.RandomState(sum(ord(ch) for ch in kind) % 1000)
    if kind == "ofuda":
        c.rect(5, 2, 10, 12, BONE); c.rect(5, 2, 5, 12, SKN); c.rect(5, 12, 10, 12, SKN)
        for y in range(3, 12, 3):
            c.line(7, y, 8, y + 1, CR3); c.px(6, y + 1, CR3); c.px(9, y, CR3)
        c.line(8, 3, 8, 10, CR2); c.px(7, 1, INK); c.px(8, 1, BR1)
        for (x, y) in [(6, 12), (8, 13), (9, 13)]: c.px(x, y, CR2)
    elif kind == "mold":
        for y in range(4, 13):
            for x in range(16):
                p = (y - 3) / 10.0
                if rng.rand() < p * 0.7 and rng.rand() < 0.8:
                    c.px(x, y, [MS0, MS1, (22, 28, 24)][rng.randint(0, 3)])
        for _ in range(5): c.px(rng.randint(2, 14), rng.randint(3, 9), MS2)
    elif kind == "crack":
        pts = [(8, 3), (7, 6), (9, 8), (7, 11), (8, 12)]
        for a, b in zip(pts, pts[1:]): c.line(*a, *b, INK)
        for a, b in zip(pts, pts[1:]): c.line(a[0] + 1, a[1], b[0] + 1, b[1], mix(tuple(c.a[a[1], a[0] + 1, :3]), INK, 0.0) if False else (90, 80, 84), 110)
        c.line(7, 6, 3, 8, INK); c.line(9, 8, 13, 7, INK)
    elif kind == "ema":   # деревянная табличка-эма на верёвочке
        c.rect(4, 4, 11, 11, BR2); c.rect(4, 4, 11, 4, BR3); c.rect(4, 11, 11, 11, BR0)
        c.rect(4, 4, 4, 11, BR1); c.rect(11, 4, 11, 11, BR0)
        c.line(8, 2, 8, 4, BR0); c.px(8, 2, INK)
        for (x, y) in [(6, 6), (7, 6), (6, 8), (9, 7), (8, 9), (9, 9)]: c.px(x, y, INK)
        c.px(9, 6, CR2); c.px(7, 9, CR2)
    elif kind == "shimenawa":   # священная верёвка со шиде
        for x in range(16):
            y = 4 + (1 if x % 4 in (1, 2) else 0)
            c.px(x, y, BR3 if x % 2 else BR2); c.px(x, y + 1, BR1)
        for x0 in (3, 10):
            for k in range(5):
                c.px(x0 + (k % 2), 7 + k, BONE); c.px(x0 + 1 + (k % 2), 7 + k, SKN)
    elif kind == "chains":
        for x0 in (4, 11):
            for y in range(0, 14, 3):
                c.rect(x0, y, x0 + 1, y + 2, (150, 150, 164)); c.px(x0, y + 1, INK); c.px(x0 + 1, y, ST3)
        c.rect(3, 12, 12, 13, (110, 112, 126)); c.rect(3, 13, 12, 13, (60, 62, 74))
    elif kind == "pipe":
        for y in range(5, 9):
            for x in range(16):
                c.px(x, y, [(70, 62, 60), (112, 96, 84), (150, 126, 100), (84, 72, 66)][y - 5])
        for x in (3, 12): c.rect(x, 4, x + 1, 9, (40, 36, 40))
        for (x, y) in [(8, 9), (8, 10), (8, 11)]: c.px(x, y, (24, 30, 46)); c.px(x, y + 1, (30, 40, 60))
    c.save(f"{T}/{name}.png")


def hall_fusuma():
    """Две половинки фусума 16x16: вместе — створка 32x16 с росписью и ручкой. Повторяются по всей стене."""
    for side in range(2):
        c = C(16, 16); rng = np.random.RandomState(81)
        for y in range(16):
            for x in range(16):
                paper = (132 + rng.randint(-5, 5), 118 + rng.randint(-5, 5), 100 + rng.randint(-5, 5))
                c.px(x, y, paper)
        # рама
        for x in range(16): c.px(x, 0, INK); c.px(x, 1, BR0); c.px(x, 14, BR0); c.px(x, 15, INK)
        edge = 0 if side == 0 else 15
        for y in range(16): c.px(edge, y, INK); c.px(edge + (1 if side == 0 else -1), y, BR1)
        # роспись: тёмные бамбуковые стебли и красное пятно
        for sx in ([3, 9] if side == 0 else [4, 11]):
            for y in range(3, 14):
                c.px(sx, y, (46, 56, 48))
                if y % 4 == 0: c.px(sx - 1, y, (46, 56, 48)); c.px(sx + 1, y, (46, 56, 48))
            c.line(sx, 6, sx + 3, 4, (46, 56, 48)); c.line(sx, 9, sx - 3, 7, (46, 56, 48))
        if side == 1:
            c.rect(1, 7, 2, 10, BR0)             # ручка-вырез у шва
            c.px(1, 7, BR2)
        else:
            c.rect(13, 7, 14, 10, BR0); c.px(13, 7, BR2)
        c.save(f"{T}/wall_fusuma_{'ab'[side]}.png")


def wall_lamp():
    c = C(16, 16); base = np.random.RandomState(81)
    for y in range(16):
        for x in range(16):
            c.px(x, y, (132 + base.randint(-5, 5), 118 + base.randint(-5, 5), 100 + base.randint(-5, 5)))
    for x in range(16): c.px(x, 0, INK); c.px(x, 1, BR0); c.px(x, 14, BR0); c.px(x, 15, INK)
    # бумажный фонарь-андон
    c.rect(5, 3, 10, 12, BR1); c.rect(5, 3, 5, 12, INK); c.rect(10, 3, 10, 12, INK); c.rect(5, 3, 10, 3, INK); c.rect(5, 12, 10, 12, INK)
    for y in range(4, 12):
        for x in range(6, 10):
            c.px(x, y, (250, 200, 110) if 6 <= y <= 9 and x in (7, 8) else (214, 140, 60))
    c.px(7, 6, (255, 238, 180)); c.px(8, 6, (255, 238, 180))
    c.save(f"{T}/wall_lamp.png")


def wall_door_tiny():
    c = C(16, 16)
    base = deco_base()
    c.paste(base, 0, 0)
    c.rect(5, 3, 10, 14, INK); c.rect(6, 4, 9, 14, BR1)
    for y in range(4, 14):
        c.px(6, y, BR2); c.px(9, y, BR0)
    c.line(6, 8, 9, 8, BR0); c.px(8, 9, (190, 160, 60))
    c.rect(6, 14, 9, 14, CR2)   # красный свет из-под двери
    c.px(5, 15, CR1); c.px(10, 15, CR1)
    c.save(f"{T}/wall_door_tiny.png")


def wall_handprints():
    c = deco_base()
    rng = np.random.RandomState(91)
    for (x0, y0) in [(2, 3), (8, 5), (4, 9), (10, 10)]:
        c.rect(x0, y0 + 2, x0 + 3, y0 + 4, CR2)
        for k in range(4): c.px(x0 + k, y0 + 1 - (k % 2), CR2)
        c.px(x0 + 4, y0 + 3, CR2); c.px(x0 + 1, y0 + 5, CR1); c.px(x0 + 2, y0 + 6, CR1); c.px(x0 + 2, y0 + 7, CR0)
    c.save(f"{T}/wall_handprints.png")


# ======================= ПРЕДМЕТЫ =======================
def jizo():
    c = C(16, 32)
    c.shadow(8, 30, 7, 2, 100)
    c.rect(3, 27, 12, 30, ST1); c.rect(3, 27, 12, 27, ST2); c.rect(3, 30, 12, 30, ST0); c.rect(2, 28, 2, 30, INK); c.rect(13, 28, 13, 30, INK)
    for y in range(14, 27):   # тело в одеянии
        w = 3 + (y - 14) // 5
        for x in range(8 - w, 8 + w):
            c.px(x, y, ST2 if x < 8 - w // 3 else (ST1 if x < 8 + w // 2 else ST0))
        c.px(8 - w - 1, y, INK); c.px(8 + w, y, INK)
    c.rect(5, 15, 10, 17, CR2); c.rect(5, 15, 10, 15, CR3); c.rect(6, 18, 9, 19, CR1)   # красный нагрудник
    c.blob(8, 9, 4, 4.4, (ST1, ST2, ST3), outline=INK)
    c.rect(5, 4, 10, 5, ST1); c.rect(6, 3, 9, 3, ST2); c.rect(4, 5, 11, 5, ST0)   # шапочка
    c.px(7, 9, INK); c.px(9, 9, INK); c.px(8, 11, CR1)
    c.px(8, 7, ST3)
    for (x, y) in [(4, 22), (11, 24), (6, 26)]: c.px(x, y, MS1)
    c.save(f"{PR}/jizo.png")


def offering_box():
    c = C(32, 32)
    c.shadow(16, 29, 14, 2, 90)
    c.rect(3, 12, 28, 26, BR1); c.rect(3, 12, 28, 13, BR2); c.rect(3, 26, 28, 27, N2)
    c.rect(2, 12, 2, 27, INK); c.rect(29, 12, 29, 27, INK); c.rect(3, 11, 28, 11, INK)
    for x in range(5, 28, 3): c.rect(x, 14, x, 17, BR0)         # решётка-прорезь
    c.rect(4, 14, 27, 14, INK); c.rect(4, 18, 27, 18, INK)
    for y in range(20, 26):
        for x in range(4, 28): c.px(x, y, BR1 if (x + y) % 5 else BR0)
    c.rect(13, 21, 18, 24, (150, 112, 60)); c.rect(13, 21, 18, 21, (196, 152, 80))   # монетка-табличка
    c.px(15, 22, INK); c.px(16, 23, INK)
    c.line(3, 11, 16, 6, BR2); c.line(28, 11, 16, 6, BR1)             # скат крыши
    c.rect(8, 8, 23, 10, BR0)
    for x in range(8, 24): c.px(x, 8, BR1)
    c.rect(14, 5, 17, 7, VER1); c.px(15, 5, VER2)
    c.save(f"{PR}/offering_box.png")


def barrel():
    c = C(16, 32)
    c.shadow(8, 30, 7, 2, 100)
    for y in range(12, 29):
        t = (y - 12) / 16.0
        w = 6.0 + 1.6 * math.sin(t * math.pi)
        for x in range(int(8 - w), int(8 + w) + 1):
            k = (x - (8 - w)) / (2 * w)
            col = BR2 if k < 0.3 else (BR1 if k < 0.65 else BR0)
            if x == int(8 - w) or x == int(8 + w): col = INK
            c.px(x, y, col)
    for y in (14, 20, 26):
        for x in range(2, 14):
            if c.a[y, x, 3]: c.px(x, y, (90, 92, 108) if x < 7 else (50, 52, 64)); c.px(x, y + 1, (36, 38, 48))
    for y in range(13, 28, 2): c.px(6, y, BR0); c.px(10, y + 1 if y < 27 else y, BR0)
    c.blob(8, 12, 6.2, 2.6, (BR0, BR1, BR2), outline=INK)
    c.blob(8, 12, 4.6, 1.8, ((20, 14, 14), (30, 22, 22), (44, 32, 30)))
    c.px(6, 21, MS1); c.px(10, 23, MS1)
    c.save(f"{PR}/barrel.png")


def crate():
    c = C(32, 16)
    c.shadow(16, 14, 14, 2, 90)
    for ox in (0, 16):
        c.rect(ox + 1, 2, ox + 14, 14, BR1); c.rect(ox, 2, ox, 14, INK); c.rect(ox + 15, 2, ox + 15, 14, INK)
        c.rect(ox + 1, 1, ox + 14, 1, INK); c.rect(ox + 1, 2, ox + 14, 3, BR2)
        c.rect(ox + 1, 14, ox + 14, 14, N2)
        for k in range(1, 14): c.px(ox + k, 2 + k // 1 if k < 11 else 13, BR0) if k % 3 == 0 else None
        c.line(ox + 1, 4, ox + 14, 13, BR0); c.line(ox + 14, 4, ox + 1, 13, BR0)
        c.px(ox + 7, 8, N3)
    c.rect(2, 6, 4, 8, SKN) if False else None
    c.rect(18, 5, 20, 5, CR2)    # красная метка
    c.save(f"{PR}/crate.png")


def candle_blue():
    c = C(16, 16)
    c.shadow(8, 13, 5, 2, 90)
    c.blob(8, 13, 4.5, 1.8, (BR0, BR1, BR2), outline=INK)
    for y in range(6, 13):
        c.px(7, y, (190, 200, 224)); c.px(8, y, (222, 228, 244)); c.px(9, y, (150, 160, 190))
    c.px(8, 5, N2)
    c.px(8, 4, (230, 244, 255)); c.px(8, 3, (130, 190, 255)); c.px(8, 2, (70, 120, 230))
    c.px(7, 4, (80, 140, 240)); c.px(9, 4, (80, 140, 240)); c.px(8, 1, (40, 70, 170))
    c.save(f"{PR}/candle_blue.png")


def kokeshi_variants():
    # вид сзади: только чёрные волосы и красная спина
    c = C(16, 16)
    c.shadow(8, 14, 5, 2, 90)
    for y in range(8, 14):
        for x in range(5, 11):
            c.px(x, y, CR1 if x <= 6 else (CR2 if x < 9 else CR0))
    for x in range(5, 11): c.px(x, 8, (30, 6, 11)); c.px(x, 14, N2)
    c.px(8, 10, BONE); c.px(8, 12, BONE)
    c.blob(8, 5, 3.6, 3.4, (INK, N1, N3), outline=N2)
    c.px(6, 4, N3); c.px(7, 3, PU1)
    c.save(f"{PR}/kokeshi_back.png")
    # лицом: широко открытые чёрные глаза и узкая улыбка
    c = C(16, 16)
    c.shadow(8, 14, 5, 2, 90)
    for y in range(8, 14):
        for x in range(5, 11):
            c.px(x, y, CR2 if x <= 6 else (CR1 if x < 9 else CR0))
    for (x, y) in [(6, 9), (8, 10), (7, 12), (9, 12), (6, 11), (9, 9)]: c.px(x, y, BONE)
    for x in range(5, 11): c.px(x, 8, (30, 6, 11)); c.px(x, 14, N2)
    c.blob(8, 5, 3.6, 3.4, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    for x in range(5, 12): c.px(x, 2, INK)
    for (x, y) in [(5, 3), (11, 3), (5, 4), (11, 4)]: c.px(x, y, INK)
    c.rect(6, 4, 7, 6, INK); c.rect(9, 4, 10, 6, INK); c.px(6, 5, CR3); c.px(10, 5, CR3)
    c.line(6, 8, 10, 8, CR2) if False else None
    c.px(6, 7, CR2); c.px(7, 7, INK); c.px(8, 7, INK); c.px(9, 7, INK); c.px(10, 7, CR2)
    c.save(f"{PR}/kokeshi_turn.png")
    # ожила: рот открыт, глаза горят
    c = C(16, 16)
    c.shadow(8, 14, 5, 2, 90)
    for y in range(8, 14):
        for x in range(5, 11):
            c.px(x, y, CR2 if x <= 6 else (CR1 if x < 9 else CR0))
    for x in range(5, 11): c.px(x, 8, (30, 6, 11)); c.px(x, 14, N2)
    c.blob(8, 5, 3.8, 3.6, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    for x in range(4, 13): c.px(x, 2, INK)
    c.rect(5, 3, 7, 6, INK); c.rect(9, 3, 11, 6, INK); c.px(6, 4, CR3); c.px(10, 4, CR3)
    c.rect(6, 7, 10, 9, INK); c.px(7, 8, BONE); c.px(9, 8, BONE); c.px(8, 9, CR2)
    c.save(f"{PR}/kokeshi_awake.png")


# ---------- сундук, пьедестал, алтарь ----------
def chest(opened, mimic=None):
    c = C(32, 26)
    c.shadow(16, 23, 14, 3, 100)
    # корпус
    c.rect(2, 12, 29, 22, BR1); c.rect(2, 12, 29, 13, BR2)
    for x in range(3, 29, 4): c.rect(x, 14, x, 21, BR0)
    c.rect(2, 21, 29, 22, N2)
    c.rect(1, 12, 1, 22, INK); c.rect(30, 12, 30, 22, INK); c.rect(2, 23, 29, 23, INK)
    for x in (6, 24): c.rect(x, 12, x + 1, 22, N3); c.rect(x, 12, x, 22, (96, 98, 112))
    if not opened and mimic is None:
        c.rect(2, 5, 29, 12, BR1); c.rect(2, 5, 29, 6, BR2)
        for x in range(3, 29, 4): c.rect(x, 7, x, 11, BR0)
        c.rect(1, 5, 1, 12, INK); c.rect(30, 5, 30, 12, INK); c.rect(2, 4, 29, 4, INK)
        for x in (6, 24): c.rect(x, 5, x + 1, 12, N3); c.rect(x, 5, x, 12, (96, 98, 112))
        c.rect(14, 10, 17, 14, (170, 140, 60)); c.rect(14, 10, 17, 10, (214, 184, 90)); c.px(15, 12, INK); c.px(16, 12, INK)
    elif opened:
        # откинутая крышка (задняя стенка) и свет изнутри
        c.rect(3, 3, 28, 9, BR0); c.rect(3, 3, 28, 4, BR1); c.rect(2, 2, 29, 2, INK)
        c.rect(3, 10, 28, 12, (40, 12, 16))
        for x in range(4, 28):
            c.px(x, 11, (150, 40, 40) if x % 3 else (210, 120, 70))
        c.px(10, 10, (240, 220, 140)); c.px(20, 10, (240, 220, 140)); c.px(15, 9, (255, 240, 180))
        c.rect(14, 14, 17, 16, (170, 140, 60)) if False else None
    else:
        # мимик: пасть с зубами
        c.rect(2, 2, 29, 9, BR0); c.rect(2, 2, 29, 3, BR1); c.rect(2, 1, 29, 1, INK)
        c.rect(3, 9, 28, 13, (40, 8, 12))
        c.rect(5, 12, 26, 13, CR1)
        for x in range(4, 28, 3):
            c.px(x, 10, BONE); c.px(x + 1, 10, BONE); c.px(x, 11, SKN) if mimic == "open" else None
            c.px(x, 14, BONE); c.px(x + 1, 14, SKN); c.px(x, 15, BONE) if x % 2 else None
        for x in range(12, 22):   # язык
            c.px(x, 13, CR3); c.px(x, 14, CR2)
        c.rect(13, 15, 20, 16, CR3); c.rect(14, 17, 19, 18, CR2); c.px(16, 17, CR1)
        c.rect(7, 4, 9, 6, (24, 4, 8)); c.rect(22, 4, 24, 6, (24, 4, 8)); c.px(8, 5, CR3); c.px(23, 5, CR3)   # глаза в крышке
        if mimic == "snap":
            c.rect(3, 9, 28, 12, BR1); c.rect(3, 9, 28, 9, BR2)
            for x in range(4, 28, 3): c.px(x, 12, BONE); c.px(x + 1, 12, BONE); c.px(x, 13, SKN)
    name = "chest_open" if opened else ("mimic_" + mimic if mimic else "chest")
    c.save(f"{PR}/{name}.png")


def pedestal():
    c = C(24, 26)
    c.shadow(12, 23, 10, 2, 100)
    c.rect(3, 19, 20, 23, ST1); c.rect(3, 19, 20, 19, ST2); c.rect(3, 23, 20, 23, ST0)
    c.rect(2, 20, 2, 23, INK); c.rect(21, 20, 21, 23, INK); c.rect(3, 24, 20, 24, INK)
    c.rect(7, 10, 16, 19, ST1); c.rect(7, 10, 8, 19, ST2); c.rect(15, 10, 16, 19, ST0); c.rect(6, 10, 6, 19, INK); c.rect(17, 10, 17, 19, INK)
    c.rect(4, 7, 19, 10, ST2); c.rect(4, 7, 19, 7, ST3); c.rect(4, 10, 19, 10, ST0); c.rect(3, 8, 3, 10, INK); c.rect(20, 8, 20, 10, INK); c.rect(4, 6, 19, 6, INK)
    c.blob(12, 7, 6, 1.8, (BR0, BR1, BR2), outline=INK)    # блюдо для подношений
    for (x, y) in [(5, 15), (14, 13), (10, 17)]: c.px(x, y, MS1)
    c.save(f"{PR}/pedestal.png")


def altar():
    c = C(32, 32)
    c.shadow(16, 29, 14, 3, 100)
    c.rect(2, 24, 29, 29, ST1); c.rect(2, 24, 29, 24, ST2); c.rect(2, 29, 29, 29, ST0); c.rect(1, 25, 1, 29, INK); c.rect(30, 25, 30, 29, INK); c.rect(2, 30, 29, 30, INK)
    c.rect(5, 16, 26, 24, ST1); c.rect(5, 16, 26, 17, ST2); c.rect(4, 17, 4, 24, INK); c.rect(27, 17, 27, 24, INK)
    c.rect(6, 18, 25, 22, CR1); c.rect(6, 18, 25, 18, CR2)       # алтарное полотно
    for x in range(8, 24, 3): c.px(x, 20, BONE)
    c.rect(3, 13, 28, 16, ST2); c.rect(3, 13, 28, 13, ST3); c.rect(3, 16, 28, 16, ST0); c.rect(2, 14, 2, 16, INK); c.rect(29, 14, 29, 16, INK); c.rect(3, 12, 28, 12, INK)
    for cx in (7, 24):    # свечи
        for y in range(7, 12): c.px(cx, y, BONE); c.px(cx + 1, y, SKN)
        c.px(cx, 6, (255, 236, 170)); c.px(cx, 5, (250, 196, 96)); c.px(cx, 4, (226, 128, 50)); c.px(cx + 1, 6, (222, 130, 52))
    c.blob(16, 10, 4, 2, (BR0, BR1, BR2), outline=INK)                # чаша
    c.rect(14, 4, 17, 9, BONE); c.rect(14, 4, 14, 9, SKN)               # оберег
    c.line(15, 5, 16, 6, CR3); c.line(16, 7, 15, 8, CR3)
    c.save(f"{PR}/altar.png")


# ======================= ЛУННЫЕ ЛУЧИ (текстуры для света) =======================
def moon_beam(torn):
    S = 64
    a = np.zeros((S, S), float)
    rng = np.random.RandomState(5)
    for y in range(S):
        t = y / (S - 1)
        half = (9 + 18 * t) if not torn else (7 + 13 * t)
        fall = (1 - t) ** (1.3 if not torn else 1.0)
        for x in range(S):
            dx = abs(x - S / 2 + 0.5)
            soft = 1.0 if dx < half - 4 else max(0.0, (half - dx) / 4.0)
            v = soft * fall
            # решётка сёдзи: вертикальная и горизонтальная рейки дают тень
            if not torn:
                if abs(x - S / 2) < 1.2 + 0.6 * t: v *= 0.55
                if abs(y - (14 + 22 * 0.0)) < 1.6 or abs(y - 30) < 1.8: v *= 0.6
            else:
                # одна створка порвана: правый верхний сектор светит ярче, остальное темнее
                sector = (x > S / 2 and y < 34)
                v *= 1.0 if sector else 0.55
                if abs(x - S / 2) < 1.2: v *= 0.6
                v *= 1.0 + 0.15 * math.sin(x * 0.9 + y * 0.4)
            a[y, x] = max(0.0, min(1.0, v))
    img = np.zeros((S, S, 4), np.uint8)
    g = (a * 255).astype(np.uint8)
    img[..., 0] = g; img[..., 1] = g; img[..., 2] = g; img[..., 3] = g
    Image.fromarray(img, "RGBA").save(f"{T}/moon_beam{'_torn' if torn else ''}.png")


# ======================= СУЩЕСТВА (30x56) =======================
def robe(c, pal, obi, sleeves=True, hem=52, wide=1.0, skirt=True):
    """Фигура в кимоно: плечи y 24, пояс y 33..35, подол до hem."""
    dark, mid, light = pal
    for y in range(24, hem):
        t = (y - 24) / (hem - 24)
        half = 7.5 + 4.5 * t * wide
        for x in range(int(15 - half), int(15 + half) + 1):
            k = (x - (15 - half)) / (2 * half)
            col = light if k < 0.28 else (mid if k < 0.62 else dark)
            if x == int(15 - half) or x == int(15 + half): col = INK
            c.px(x, y, col)
        if y > 36 and y % 3 == 0 and skirt:   # складки хакама
            for x in range(int(15 - half) + 2, int(15 + half) - 1, 3):
                c.px(x, y, mix(mid, INK, 0.35))
    # воротник
    for i in range(8):
        c.px(15 - 1 - i // 2, 24 + i, BONE); c.px(15 + 1 + i // 2, 24 + i, SKN)
    c.px(15, 31, SKN)
    # оби
    for y in range(33, 36):
        for x in range(8, 23):
            c.px(x, y, obi[(0 if x < 12 else (1 if x < 19 else 2))])
    if sleeves:
        for side in (-1, 1):
            x0 = 15 + side * 10
            for y in range(25, 43):
                w = 3 if y < 40 else 3 - (y - 39)
                for x in range(min(x0 - w * (1 if side < 0 else 0), x0 + w), max(x0 - w, x0 + w) + 1):
                    c.px(x, y, mid if (x - x0) * side < 1 else dark)
                c.px(x0 - 3 if side < 0 else x0 + 3, y, INK)
    # ноги/сандалии
    for fx in (11, 19):
        c.rect(fx - 2, hem, fx + 2, hem + 2, BR1); c.rect(fx - 2, hem, fx + 2, hem, BR2); c.rect(fx - 2, hem + 3, fx + 2, hem + 3, INK)


def nopperabo(face):
    c = C(30, 56)
    c.shadow(15, 55, 11, 2, 90)
    robe(c, (N2, N3, PU1), (CR1, CR2, CR0))
    # шея, голова
    c.rect(13, 20, 17, 24, (150, 128, 120))
    c.blob(15, 14, 6.4, 7.8, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    # причёска: тугой пучок
    for x in range(9, 22):
        for y in range(5, 9):
            if (x - 15) ** 2 / 36.0 + (y - 11) ** 2 / 36.0 < 1.0: c.px(x, y, INK if y < 8 else N1)
    c.rect(14, 3, 16, 5, INK); c.px(15, 3, N3)
    for y in range(8, 13): c.px(9, y, INK); c.px(21, y, INK); c.px(10, y, N1); c.px(20, y, N1)
    if not face:
        c.px(12, 13, (186, 170, 162)); c.px(18, 13, (186, 170, 162))   # едва заметные впадины
    else:
        # лицо проступает: огромные глаза и растянутый рот
        for (ex, ey) in [(12, 12), (18, 12)]:
            c.blob(ex, ey, 2.6, 3.4, (INK, INK, N1))
            c.px(ex, ey + 1, CR3); c.px(ex + (1 if ex < 15 else -1), ey, CR2)
        for x in range(9, 22):
            yy = 17 + int(2.2 * math.sin((x - 9) / 12.0 * math.pi))
            c.px(x, yy, INK); c.px(x, yy + 1, INK)
            if x % 2 == 0: c.px(x, yy + 1, BONE)
        for x in range(10, 21, 2): c.px(x, 19, CR1)
        for (x, y) in [(9, 10), (8, 12), (22, 10), (21, 15), (10, 8)]: c.px(x, y, (120, 100, 104))   # трещины лица
    c.save(f"{OUT}/nopperabo{'_face' if face else ''}.png")


def tekeke(frame):
    c = C(32, 24)
    c.shadow(15, 21, 14, 2, 90)
    # кровавый след под телом
    for x in range(1, 12): c.px(x, 19 + (x % 2), CR2 if x % 3 else CR1)
    bob = frame
    # волосы (сзади и по спине)
    c.blob(12, 11 + bob, 11, 6, (INK, N1, N3), outline=None)
    # торс в светлом кимоно
    c.blob(14, 12 + bob, 8.5, 4.3, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    for (x, y) in [(10, 11), (13, 13), (16, 11), (18, 13)]:
        c.px(x, y + bob, CR2); c.px(x + 1, y + bob, CR1)
    # разорванный край сзади (талия)
    for y in range(8 + bob, 16 + bob):
        c.px(6, y, CR1); c.px(5, y, CR0) if y % 2 else None; c.px(7, y, CR2)
    c.px(5, 12 + bob, BONE); c.px(4, 13 + bob, CR2)
    # голова
    c.blob(24, 9 + bob, 4.3, 4.3, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    for x in range(20, 29): c.px(x, 5 + bob, INK)
    for y in range(6 + bob, 11 + bob): c.px(20, y, INK); c.px(19, y, N1)
    c.px(25, 9 + bob, INK); c.px(26, 9 + bob, CR3); c.px(24, 9 + bob, INK)
    c.px(26, 12 + bob, CR2); c.px(27, 12 + bob, INK)
    # руки: одна тянется вперёд, вторая упирается
    if frame == 0:
        c.line(21, 14, 27, 18, BONE); c.line(21, 15, 27, 19, SKN)
        for k in range(3): c.px(28 + (k > 0), 18 + k, BONE)
        c.line(17, 15, 20, 19, mix(BONE, INK, 0.4))
    else:
        c.line(21, 14, 25, 16, BONE); c.line(21, 15, 25, 17, SKN)
        c.line(17, 15, 24, 19, SKN); c.line(18, 15, 25, 20, BONE)
        for k in range(3): c.px(26 + (k > 0), 19 + k, BONE)
    c.save(f"{OUT}/tekeke_{'ab'[frame]}.png")


def rokurokubi(mode):
    """mode: full / nohead"""
    c = C(30, 56)
    c.shadow(15, 55, 11, 2, 90)
    robe(c, (N3, PU1, PU2), (CR1, CR3, CR1), wide=0.9)
    # узор на подоле
    for (x, y) in [(10, 43), (15, 46), (20, 42), (12, 49), (18, 49)]:
        c.px(x, y, CR2); c.px(x + 1, y, CR1)
    if mode == "full":
        c.rect(14, 20, 16, 24, (178, 158, 150))
        face_head(c, 15, 13)
    else:
        c.rect(14, 16, 16, 24, (178, 158, 150)); c.rect(13, 15, 17, 15, CR2); c.px(15, 14, CR3)   # шея кверху и срез
        c.px(14, 18, (130, 110, 104)); c.px(16, 21, (130, 110, 104))
    c.save(f"{OUT}/rokurokubi{'' if mode == 'full' else '_nohead'}.png")


def face_head(c, cx, cy):
    c.blob(cx, cy, 5.8, 6.8, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    for x in range(cx - 7, cx + 8):          # причёска нихонгами
        for y in range(cy - 9, cy - 3):
            if ((x - cx) / 7.0) ** 2 + ((y - cy + 3) / 6.0) ** 2 < 1.0: c.px(x, y, INK if y < cy - 5 else N1)
    for y in range(cy - 4, cy + 1): c.px(cx - 7, y, INK); c.px(cx + 7, y, INK); c.px(cx - 6, y, N1); c.px(cx + 6, y, N1)
    c.rect(cx - 3, cy - 10, cx + 3, cy - 9, INK)
    c.px(cx - 4, cy - 9, CR3); c.px(cx - 5, cy - 8, CR3); c.px(cx + 4, cy - 9, BONE); c.px(cx + 5, cy - 8, SKN)   # заколки
    c.px(cx - 3, cy, INK); c.px(cx - 2, cy, INK); c.px(cx + 2, cy, INK); c.px(cx + 3, cy, INK)
    c.px(cx - 3, cy + 1, CR3); c.px(cx + 3, cy + 1, CR3)
    c.px(cx, cy + 4, CR2); c.px(cx - 1, cy + 4, CR2); c.px(cx + 1, cy + 4, CR2)


def rokuro_head():
    c = C(16, 18)
    face_head(c, 8, 10)
    c.px(8, 17, (130, 110, 104)); c.px(7, 17, CR2); c.px(9, 17, CR2)
    c.save(f"{OUT}/rokurokubi_head.png")


def merchant():
    c = C(30, 56)
    # призрачное тело: чем ниже, тем прозрачнее
    for y in range(18, 56):
        t = (y - 18) / 37.0
        half = 5.5 + 9.0 * t
        sway = 1.2 * math.sin(y * 0.55)
        alpha = int(255 * (1.0 if t < 0.55 else max(0.0, 1.0 - (t - 0.55) / 0.45)))
        for x in range(int(15 - half + sway), int(15 + half + sway) + 1):
            k = (x - (15 - half + sway)) / (2 * half)
            col = GH2 if k < 0.25 else (GH1 if k < 0.62 else GH0)
            if x == int(15 - half + sway) or x == int(15 + half + sway): col = (60, 66, 96)
            c.px(x, y, col, alpha)
        if y % 5 == 0:
            for x in range(int(15 - half + sway) + 2, int(15 + half + sway) - 1, 4): c.px(x, y, mix(GH0, INK, 0.4), alpha)
    # узел с поклажей за спиной
    c.blob(7, 24, 6, 5.5, (BR0, BR1, BR2), outline=INK)
    c.rect(4, 21, 10, 21, PU1); c.px(6, 19, INK); c.px(8, 19, INK); c.line(6, 20, 9, 22, PU2)
    # капюшон
    c.blob(15, 13, 7.2, 8.2, (GH0, GH1, GH2), outline=(52, 56, 84))
    c.blob(15, 14, 4.6, 5.4, (INK, N1, N2))
    c.px(13, 13, CR3); c.px(17, 13, CR3); c.px(13, 14, CR2); c.px(17, 14, CR2)
    c.px(14, 17, (60, 12, 18)); c.px(15, 17, (60, 12, 18)); c.px(16, 17, (60, 12, 18))
    # рука с фонарём
    c.line(20, 27, 24, 30, GH1); c.line(20, 28, 24, 31, GH0)
    c.line(25, 28, 25, 32, BR1)
    c.rect(23, 32, 27, 38, BR1); c.rect(23, 32, 27, 32, INK); c.rect(23, 38, 27, 38, INK)
    for y in range(33, 38):
        for x in range(24, 27):
            c.px(x, y, (255, 226, 150) if y in (34, 35) and x == 25 else (232, 150, 70))
    c.save(f"{OUT}/merchant.png")


if __name__ == "__main__":
    temple_atlas(); cellar_atlas(); ov_moss(); ov_leaves(); ov_wet(); trail()
    wall_temple(); wall_temple_post(); wall_cellar(); wall_cellar_post(); wall_cap_stone()
    # накладки: татами-основа уже есть (wall_ofuda и др.), здесь — храм и подвал
    deco(base_temple, "ofuda", "wall_temple_ofuda"); deco(base_temple, "mold", "wall_temple_mold")
    deco(base_temple, "crack", "wall_temple_crack"); deco(base_temple, "ema", "wall_ema")
    deco(base_temple, "shimenawa", "wall_shimenawa")
    deco(base_cellar, "ofuda", "wall_cellar_ofuda"); deco(base_cellar, "mold", "wall_cellar_mold")
    deco(base_cellar, "crack", "wall_cellar_crack"); deco(base_cellar, "chains", "wall_chains")
    deco(base_cellar, "pipe", "wall_pipe")
    hall_fusuma(); wall_lamp(); wall_door_tiny(); wall_handprints()
    for f in (jizo, offering_box, barrel, crate, candle_blue, kokeshi_variants, pedestal, altar): f()
    chest(False); chest(True); chest(False, "open"); chest(False, "snap")
    moon_beam(False); moon_beam(True)
    nopperabo(False); nopperabo(True); tekeke(0); tekeke(1)
    rokurokubi("full"); rokurokubi("nohead"); rokuro_head(); merchant()
    print("art2 ok")
