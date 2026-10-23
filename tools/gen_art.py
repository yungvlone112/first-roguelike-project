"""Генератор текстур комнаты в палитре персонажей (индиго/чёрный, багровый, кость, тёплое дерево)."""
import numpy as np, os, math
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")

# ---------- палитра (снята со спрайтов героя и врагов) ----------
INK = (11, 9, 13); N1 = (16, 14, 20); N2 = (24, 20, 26); N3 = (32, 26, 41)
PU1 = (48, 35, 63); PU2 = (65, 50, 86)
BR0 = (45, 26, 26); BR1 = (70, 48, 44); BR2 = (102, 76, 69); BR3 = (140, 104, 89)
SKN = (168, 140, 130); BONE = (210, 197, 194)
CR0 = (48, 6, 11); CR1 = (72, 13, 20); CR2 = (108, 10, 20); CR3 = (156, 24, 34)
S0 = (42, 34, 27); S1 = (60, 50, 38); S2 = (80, 66, 47); S3 = (102, 84, 59); S4 = (124, 104, 74)
P0 = (38, 27, 35); P1 = (52, 37, 47); P2 = (66, 47, 59); P3 = (82, 60, 72)
ST0 = (36, 30, 44); ST1 = (60, 52, 66); ST2 = (88, 80, 96); ST3 = (120, 112, 124)


class C:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.a = np.zeros((h, w, 4), np.uint8)

    def px(s, x, y, c, a=255):
        x, y = int(x), int(y)
        if 0 <= x < s.w and 0 <= y < s.h:
            s.a[y, x] = (c[0], c[1], c[2], a)

    def get(s, x, y):
        return tuple(s.a[y, x])

    def rect(s, x0, y0, x1, y1, c, a=255):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.px(x, y, c, a)

    def line(s, x0, y0, x1, y1, c, a=255):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            s.px(x0, y0, c, a)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy; x0 += sx
            if e2 <= dx:
                err += dx; y0 += sy

    def blob(s, cx, cy, rx, ry, pal, light=(-0.55, -0.8), outline=None, a=255):
        """Эллипс с тремя тонами (pal: тёмный, средний, светлый) и контуром."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
                d = nx * nx + ny * ny
                if d > 1.0:
                    continue
                l = -(nx * light[0] + ny * light[1])  # >0 — освещённая сторона
                t = 1 if l > 0.15 else (0 if l < -0.25 else 1)
                idx = 2 if l > 0.45 else (1 if l > -0.2 else 0)
                col = pal[idx]
                if outline and d > 0.72:
                    col = outline
                s.px(x, y, col, a)

    def paste(s, o, ox, oy):
        for y in range(o.h):
            for x in range(o.w):
                p = o.a[y, x]
                if p[3] > 0:
                    s.px(ox + x, oy + y, tuple(p[:3]), int(p[3]))

    def shadow(s, cx, cy, rx, ry, a=95):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if 0 <= x < s.w and 0 <= y < s.h and nx * nx + ny * ny <= 1 and s.a[y, x, 3] == 0:
                    s.px(x, y, (0, 0, 0), a)

    def save(s, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(s.a, "RGBA").save(path)


def mix(c1, c2, t):
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))


# ---------- ПОЛ: циновки татами ----------
def straw(c, x0, y0, x1, y1, rng, base=(S1, S2, S3), vary=0.0):
    """Плетёная солома: горизонтальные пряди разной длины."""
    for y in range(y0, y1 + 1):
        x = x0
        tone = rng.randint(0, 3)
        while x <= x1:
            run = rng.randint(3, 10)
            tone = int(np.clip(tone + rng.choice([-1, 0, 0, 1]), 0, 2))
            col = base[tone]
            if (y % 2) == 0:
                col = mix(col, S0, 0.25)
            for xx in range(x, min(x + run, x1 + 1)):
                c.px(xx, y, col)
            x += run
    # редкие тёмные крапины и светлые волокна
    for _ in range((x1 - x0 + 1) * (y1 - y0 + 1) // 28):
        c.px(rng.randint(x0, x1 + 1), rng.randint(y0, y1 + 1), S0)
    for _ in range((x1 - x0 + 1) * (y1 - y0 + 1) // 45):
        xx = rng.randint(x0, x1 - 2); yy = rng.randint(y0, y1 + 1)
        c.px(xx, yy, S4); c.px(xx + 1, yy, S3)


def mat(seed, tone_shift):
    """Одна циновка 64x32: край-кайма (хэри) по длинным сторонам, торцы соломы."""
    rng = np.random.RandomState(seed)
    c = C(64, 32)
    base = (mix(S1, S0, tone_shift), mix(S2, S1, tone_shift), mix(S3, S2, tone_shift))
    straw(c, 0, 0, 63, 31, rng, base)
    # старые пятна на соломе
    for _ in range(3):
        cx, cy = rng.randint(6, 58), rng.randint(6, 26)
        rx, ry = rng.randint(3, 7), rng.randint(2, 4)
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1 and rng.rand() < 0.55:
                    c.px(x, y, mix(tuple(c.a[y, x, :3]), S0, 0.55))
    # кайма: тёмная ткань с индиго-бликом сверху, снизу только тень соломы
    for x in range(64):
        c.px(x, 0, (14, 11, 18)); c.px(x, 1, (30, 24, 40))
        c.px(x, 2, mix(tuple(c.a[2, x, :3]), INK, 0.35))
        c.px(x, 31, mix(tuple(c.a[31, x, :3]), INK, 0.5))
        c.px(x, 30, mix(tuple(c.a[30, x, :3]), INK, 0.2))
    # торцы
    for y in range(2, 31):
        c.px(0, y, S0); c.px(63, y, S0)
        c.px(1, y, mix(tuple(c.a[y, 1, :3]), S0, 0.45))
        c.px(62, y, mix(tuple(c.a[y, 62, :3]), S0, 0.45))
    return c


def tatami_atlas():
    a = C(64, 64)
    a.paste(mat(11, 0.0), 0, 0)
    a.paste(mat(29, 0.28), 0, 32)
    a.save(f"{OUT}/tiles/tatami_atlas.png")
    # одиночная плитка-запасной вариант (floor.png)
    t = C(16, 16)
    straw(t, 0, 0, 15, 15, np.random.RandomState(5))
    t.save(f"{OUT}/floor.png")


def floor_boards():
    c = C(16, 16)
    rng = np.random.RandomState(7)
    for p in range(2):
        y0 = p * 8
        for y in range(y0, y0 + 8):
            for x in range(16):
                col = [BR0, BR1, BR1, BR2][min(3, max(0, int((y - y0) / 2.4)))] if False else BR1
                c.px(x, y, mix(BR1, BR0, 0.35 + 0.1 * rng.rand()))
        for x in range(16):
            c.px(x, y0, INK); c.px(x, y0 + 1, mix(BR2, BR1, 0.5))
            c.px(x, y0 + 7, N2)
        for _ in range(5):  # волокна
            xx = rng.randint(0, 12); yy = y0 + rng.randint(2, 7)
            for k in range(rng.randint(3, 6)):
                c.px(xx + k, yy, BR0)
        c.px(2 + p * 9, y0 + 4, INK); c.px(13 - p * 8, y0 + 3, INK)  # гвозди
    c.save(f"{OUT}/tiles/floor_boards.png")


# ---------- накладки на пол (прозрачные) ----------
def ov_scratch():
    c = C(16, 16)
    for k in range(3):
        o = k * 3
        c.line(2 + o, 1, 7 + o, 14, (14, 10, 10), 150)
        c.line(3 + o, 1, 8 + o, 14, (150, 134, 104), 140)
    c.save(f"{OUT}/tiles/floor_scratch.png")


def ov_crack():
    c = C(16, 16)
    pts = [(1, 0), (3, 3), (2, 6), (5, 8), (6, 11), (9, 12), (11, 15)]
    for a, b in zip(pts, pts[1:]):
        c.line(*a, *b, (10, 8, 9), 235)
    for a, b in zip(pts, pts[1:]):
        c.line(a[0] + 1, a[1], b[0] + 1, b[1], (120, 104, 74), 120)
    c.line(5, 8, 11, 7, (10, 8, 9), 220); c.line(11, 7, 14, 9, (10, 8, 9), 200)
    c.save(f"{OUT}/tiles/floor_crack.png")


def ov_stain():
    c = C(16, 16)
    rng = np.random.RandomState(3)
    cx, cy = 8, 8
    for y in range(16):
        for x in range(16):
            d = math.hypot((x - cx) / 6.0, (y - cy) / 4.5)
            d += (rng.rand() - 0.5) * 0.55
            if d < 0.55:
                c.px(x, y, (26, 17, 14), 175)
            elif d < 1.0:
                c.px(x, y, (34, 24, 18), 105)
    c.save(f"{OUT}/tiles/floor_stain.png")


def ov_mold():
    c = C(16, 16)
    rng = np.random.RandomState(9)
    for _ in range(4):
        cx, cy = rng.randint(2, 14), rng.randint(2, 14)
        for _ in range(11):
            x = cx + rng.randint(-2, 3); y = cy + rng.randint(-2, 3)
            c.px(x, y, [(30, 42, 32), (52, 66, 44), (80, 96, 62)][rng.randint(0, 3)], 205)
    c.save(f"{OUT}/tiles/floor_mold.png")


def ov_blood():
    c = C(16, 16)
    c.blob(7.5, 8, 4.2, 3.2, (CR1, CR2, CR3), a=235)
    for (x, y) in [(2, 4), (3, 12), (13, 3), (13, 12), (11, 14), (5, 1)]:
        c.px(x, y, CR2, 235)
    c.line(11, 9, 15, 13, CR1, 235)
    c.px(6, 7, (190, 50, 55)); c.px(7, 7, (190, 50, 55))
    c.save(f"{OUT}/tiles/floor_blood.png")


def ov_danger():
    c = C(16, 16)
    for y in range(16):
        for x in range(16):
            c.px(x, y, (90, 6, 16), 105)
    for k in range(16):  # руны-перекрестье
        c.px(k, k, CR0, 215); c.px(15 - k, k, CR0, 215)
    for (x, y) in [(7, 7), (8, 7), (7, 8), (8, 8)]:
        c.px(x, y, CR3, 230)
    for (x, y) in [(1, 7), (14, 8), (7, 1), (8, 14)]:
        c.px(x, y, (190, 50, 55), 220)
    c.save(f"{OUT}/tiles/floor_danger.png")


# ---------- СТЕНЫ ----------
def plaster(c, rng, y0=3, y1=12):
    for y in range(16):
        for x in range(16):
            r = rng.rand()
            col = P1
            if r < 0.20: col = P0
            elif r > 0.86: col = P2
            elif r > 0.975: col = P3
            if y >= 9: col = mix(col, INK, 0.12 * (y - 8) / 4)  # темнее к низу
            c.px(x, y, col)
    for _ in range(3):  # мазки штукатура
        yy = rng.randint(4, 11); xx = rng.randint(0, 10)
        for k in range(rng.randint(3, 6)):
            c.px(xx + k, yy, P2)
    # верхняя балка (нуки) и плинтус
    for x in range(16):
        c.px(x, 0, INK); c.px(x, 1, BR0); c.px(x, 2, mix(BR1, BR0, 0.4))
        c.px(x, 13, mix(BR1, BR0, 0.3)); c.px(x, 14, BR0); c.px(x, 15, INK)


def wall_face():
    c = C(16, 16); plaster(c, np.random.RandomState(21)); c.save(f"{OUT}/wall.png")
    return c


def wall_post():
    c = C(16, 16); plaster(c, np.random.RandomState(21))
    for y in range(16):
        for x in range(4, 12):
            col = BR0
            if x in (5, 6): col = BR1
            if x == 6 and y % 5 != 0: col = BR2
            if x in (4, 11): col = INK
            if x == 10: col = N2
            c.px(x, y, col)
    for y in (4, 9, 13):
        c.px(5, y, BR0); c.px(7, y + 1 if y < 14 else y, BR1)
    for x in range(3, 13):  # капитель
        c.px(x, 2, BR2 if x < 8 else BR1); c.px(x, 1, BR0)
    c.save(f"{OUT}/tiles/wall_post.png")


def wall_cap():
    c = C(16, 16)
    rng = np.random.RandomState(33)
    for y in range(16):
        for x in range(16):
            col = N2 if rng.rand() < 0.75 else N3
            if rng.rand() > 0.96: col = PU1
            c.px(x, y, col)
    for x in range(16):  # швы черепицы
        c.px(x, 7, N1); c.px(x, 15, N1)
    for y in range(0, 7):
        c.px(7 if y < 7 else 0, y, N1)
    for y in range(8, 15):
        c.px(0, y, N1); c.px(15, y, N1)
    for x in range(16):  # фаска сверху
        c.px(x, 0, PU1)
    c.px(3, 3, PU2); c.px(11, 11, PU2)
    c.save(f"{OUT}/tiles/wall_cap.png")


def deco_base():
    c = C(16, 16); plaster(c, np.random.RandomState(21)); return c


def wall_plaster_dec():
    c = deco_base()
    for y in range(4, 12):  # облупившаяся штукатурка, видна обрешётка
        for x in range(2, 9):
            edge = (x in (2, 8) or y in (4, 11)) and (x + y) % 2 == 0
            if edge: continue
            c.px(x, y, (22, 16, 20))
    for y in (5, 7, 9):
        for x in range(3, 8):
            c.px(x, y, BR1)
    c.line(9, 3, 11, 9, INK); c.line(11, 9, 13, 12, INK)
    c.save(f"{OUT}/tiles/wall_plaster.png")


def wall_mold_dec():
    c = deco_base()
    rng = np.random.RandomState(14)
    for y in range(4, 13):
        for x in range(16):
            p = (y - 3) / 10.0
            if rng.rand() < p * 0.7 and rng.rand() < 0.8 * (1.0 if 2 < x < 14 else 0.4):
                c.px(x, y, [(28, 38, 30), (46, 58, 40), (22, 28, 24)][rng.randint(0, 3)])
    for _ in range(6):
        c.px(rng.randint(2, 14), rng.randint(3, 9), (80, 96, 62))
    c.save(f"{OUT}/tiles/wall_mold.png")


def wall_ofuda_dec():
    c = deco_base()
    c.rect(5, 2, 10, 12, BONE)
    c.rect(5, 2, 5, 12, SKN); c.rect(5, 12, 10, 12, SKN)
    for y in range(3, 12, 3):  # красные знаки
        c.line(7, y, 8, y + 1, CR3); c.px(6, y + 1, CR3); c.px(9, y, CR3)
    c.line(8, 3, 8, 10, CR2)
    c.px(7, 5, CR3); c.px(9, 8, CR3)
    c.px(7, 1, INK); c.px(8, 1, BR1)   # гвоздь
    for (x, y) in [(6, 12), (8, 13), (9, 13)]:
        c.px(x, y, CR2)                 # подтёк
    c.save(f"{OUT}/tiles/wall_ofuda.png")


def shoji(torn):
    c = deco_base()
    c.rect(1, 3, 14, 12, BR1)
    for (x0, y0) in [(2, 4), (8, 4), (2, 8), (8, 8)]:
        for y in range(y0, y0 + 4):
            for x in range(x0, x0 + 6):
                c.px(x, y, (128, 114, 100) if (x + y) % 3 else (116, 102, 90))
    for x in range(1, 15): c.px(x, 3, BR0); c.px(x, 12, BR0)
    for y in range(3, 13): c.px(1, y, BR0); c.px(14, y, BR0); c.px(7, y, BR0)
    for x in range(2, 14): c.px(x, 7, BR0)
    if torn:
        for y in range(8, 12):
            for x in range(8, 14):
                c.px(x, y, (6, 4, 9))
        for (x, y) in [(8, 8), (9, 9), (13, 8), (12, 9), (13, 10)]:
            c.px(x, y, (128, 114, 100))
        c.line(10, 5, 11, 7, CR2); c.px(11, 7, CR3)
        c.line(3, 5, 4, 6, CR1)
    else:
        c.line(3, 5, 6, 6, (90, 78, 70)); c.px(10, 10, (90, 78, 70))
    c.save(f"{OUT}/tiles/wall_shoji{'_torn' if torn else ''}.png")


def skull(c, ox, oy, scale=1):
    for (x, y) in [(3, 0), (4, 0), (5, 0), (6, 0), (2, 1), (7, 1), (1, 2), (8, 2), (1, 3), (8, 3), (1, 4), (8, 4),
                   (2, 5), (7, 5), (3, 6), (4, 6), (5, 6), (6, 6)]:
        c.px(ox + x, oy + y, INK)
    for y in range(1, 6):
        for x in range(2, 8):
            c.px(ox + x, oy + y, BONE if (x + y) % 5 else SKN)
    for x in (3, 4, 6, 7):
        pass
    for (x, y) in [(3, 3), (4, 3), (6, 3), (7, 3), (3, 2), (6, 2)]:
        c.px(ox + x, oy + y, CR3 if (x, y) in [(3, 3), (6, 3)] else INK)
    c.px(ox + 5, oy + 4, INK)
    for x in (3, 4, 5, 6):
        c.px(ox + x, oy + 6, SKN if x % 2 else INK)


def wall_danger():
    c = C(16, 16)
    for y in range(16):
        for x in range(16):
            c.px(x, y, CR0 if (x + y) % 7 else (30, 6, 11))
    for k in range(16):
        c.px(k, k, CR2); c.px(15 - k, k, CR2)
    skull(c, 3, 4)
    for x in range(16): c.px(x, 0, INK); c.px(x, 15, INK)
    c.save(f"{OUT}/tiles/wall_danger.png")


def door_sealed():
    c = C(16, 16)
    for y in range(16):
        for x in range(16):
            col = BR0 if x % 4 else INK
            if x % 4 == 1: col = BR1
            c.px(x, y, col)
    for y in (2, 3, 12, 13):   # железные полосы
        for x in range(16):
            c.px(x, y, N1 if y in (2, 12) else N3)
    for x in (1, 5, 9, 13):
        c.px(x, 2, PU1); c.px(x, 12, PU1)
    c.rect(6, 4, 9, 11, BONE)
    c.line(7, 5, 8, 6, CR3); c.line(8, 7, 7, 8, CR3); c.px(7, 9, CR3); c.px(8, 10, CR3)
    c.rect(6, 4, 6, 11, SKN)
    c.save(f"{OUT}/tiles/door_sealed.png")


def door_boss():
    c = C(16, 16)
    for y in range(16):
        for x in range(16):
            col = (20, 4, 8) if x % 8 else INK
            c.px(x, y, col)
    for x in range(16):
        c.px(x, 0, CR1); c.px(x, 15, CR1)
        if x % 8 == 3: c.px(x, 7, CR0)
    skull(c, 3, 3)
    for (x, y) in [(1, 1), (14, 1), (1, 14), (14, 14)]:
        c.px(x, y, CR3)
    c.save(f"{OUT}/tiles/door_boss.png")


# ---------- ПРЕДМЕТЫ ----------
def sandals():
    c = C(16, 16)
    def sandal(ox, oy, tilt):
        for y in range(8):
            w = 3 if y in (0, 7) else 4
            for x in range(w):
                xx = ox + x + (tilt * y) // 4
                c.px(xx, oy + y, BR3 if (x + y) % 2 else BR2)
            c.px(ox + (tilt * y) // 4 - 1, oy + y, N2)
            c.px(ox + w + (tilt * y) // 4, oy + y, N2)
        c.px(ox + 1 + tilt // 4, oy + 2, CR3); c.px(ox + 2 + tilt // 4, oy + 2, CR3)
        c.px(ox + 1 + tilt // 2, oy + 3, CR2)
    c.shadow(8, 11, 6, 3, 70)
    sandal(3, 3, 1); sandal(9, 5, -1)
    c.save(f"{OUT}/props/sandals.png")


def plate():
    c = C(16, 16)
    c.shadow(8, 11, 7, 3, 70)
    c.blob(8, 8, 6, 3.6, (SKN, BONE, (232, 224, 222)), outline=BR1)
    c.blob(8, 8, 3.3, 1.8, ((150, 128, 120), (186, 172, 166), BONE))
    for (x, y) in [(7, 7), (8, 8), (9, 8), (10, 9)]:
        c.px(x, y, CR2)
    for (x, y) in [(12, 6), (13, 7), (2, 11), (3, 12)]:   # осколки
        c.px(x, y, BONE)
    c.px(13, 6, INK); c.px(10, 8, INK)
    c.save(f"{OUT}/props/plate.png")


def bones():
    c = C(16, 16)
    c.shadow(8, 11, 7, 3, 60)
    c.line(2, 10, 12, 5, BR2); c.line(2, 11, 12, 6, SKN)      # бедренная кость
    c.line(1, 9, 3, 10, BONE); c.line(1, 11, 3, 12, BONE); c.px(12, 4, BONE); c.px(13, 5, BONE); c.px(13, 6, BONE); c.px(12, 7, BONE)
    c.px(2, 11, BONE)
    # череп
    c.blob(6, 6, 3.6, 3.2, (SKN, BONE, (232, 224, 222)), outline=BR1)
    c.px(5, 5, INK); c.px(7, 5, INK); c.px(6, 7, INK); c.px(5, 5, CR2); c.px(7, 5, CR2)
    c.line(4, 9, 8, 9, SKN)
    # рёбра
    c.line(9, 10, 13, 9, BONE); c.line(9, 12, 14, 11, SKN); c.line(10, 13, 14, 13, BONE)
    c.save(f"{OUT}/props/bones.png")


def candle():
    c = C(16, 16)
    c.shadow(8, 13, 5, 2, 90)
    c.blob(8, 13, 4.5, 1.8, (BR0, BR1, BR2), outline=INK)
    for y in range(6, 13):
        c.px(7, y, BONE); c.px(8, y, (226, 214, 208)); c.px(9, y, SKN)
    c.px(7, 7, SKN); c.px(9, 9, BR3); c.px(9, 10, BR3)   # подтёки
    c.px(8, 5, N2)
    c.px(8, 4, (255, 236, 170)); c.px(8, 3, (250, 196, 96)); c.px(8, 2, (226, 128, 50))
    c.px(7, 4, (222, 130, 52)); c.px(9, 4, (222, 130, 52)); c.px(8, 1, (150, 64, 34))
    c.save(f"{OUT}/props/candle.png")


def charms():
    c = C(16, 16)
    def slip(ox, oy, w, h, col, glyph, skew):
        for y in range(h):
            for x in range(w):
                c.px(ox + x + (skew * y) // 5, oy + y, col)
        for y in range(1, h - 1, 3):
            c.px(ox + 1 + (skew * y) // 5, oy + y, glyph)
            c.px(ox + 2 + (skew * y) // 5, oy + y + 1, glyph)
        for y in range(h):
            c.px(ox + w + (skew * y) // 5, oy + y, (60, 46, 44), 160)
    c.shadow(8, 11, 7, 4, 40)
    slip(2, 4, 4, 8, BONE, CR3, 1)
    slip(9, 3, 4, 8, (170, 146, 134), CR2, -1)
    c.px(11, 10, CR2); c.px(4, 12, CR1)
    c.save(f"{OUT}/props/charms.png")


def kokeshi():
    c = C(16, 16)
    c.shadow(8, 14, 5, 2, 90)
    for y in range(8, 14):
        for x in range(5, 11):
            col = CR2
            if x <= 6: col = CR1
            if x >= 9: col = CR0
            c.px(x, y, col)
    for (x, y) in [(6, 9), (8, 10), (7, 12), (9, 12), (6, 11), (9, 9)]:
        c.px(x, y, BONE)
    for x in range(5, 11): c.px(x, 8, (30, 6, 11)); c.px(x, 14, N2)
    c.px(4, 13, N2)
    c.blob(8, 5, 3.6, 3.4, ((176, 158, 150), BONE, (232, 224, 222)), outline=N2)
    for x in range(5, 12): c.px(x, 2, INK)
    for (x, y) in [(5, 3), (11, 3), (5, 4), (11, 4)]: c.px(x, y, INK)
    c.px(6, 5, INK); c.px(9, 5, INK); c.px(6, 6, CR3); c.px(9, 6, CR3)   # глаза и щёки
    c.px(7, 7, CR2); c.px(8, 7, CR2)
    c.save(f"{OUT}/props/kokeshi.png")


def puddle():
    c = C(16, 16)
    pts = np.random.RandomState(5)
    for y in range(16):
        for x in range(16):
            d = math.hypot((x - 7.5) / 6.8, (y - 8) / 3.8) + (pts.rand() - 0.5) * 0.25
            if d < 0.78:
                c.px(x, y, (14, 12, 22), 240)
            elif d < 1.0:
                c.px(x, y, (30, 24, 38), 215)
    for (x, y) in [(4, 7), (5, 7), (10, 9), (11, 9)]:
        c.px(x, y, PU2, 230)
    c.px(6, 8, CR2, 230); c.px(7, 8, CR1, 230); c.px(12, 8, CR1, 200)
    c.px(8, 6, PU1, 230)
    c.save(f"{OUT}/props/puddle.png")


def cobweb():
    c = C(16, 16)
    W = (206, 196, 194)
    for (x1, y1) in [(15, 0), (13, 7), (9, 12), (4, 14), (0, 15)]:
        c.line(0, 0, x1, y1, W, 150)
    for r in (4, 8, 12):
        prev = None
        for a in np.linspace(0, math.pi / 2, 6):
            p = (int(r * math.cos(a)), int(r * math.sin(a)))
            if prev: c.line(*prev, *p, W, 110)
            prev = p
    c.px(9, 12, W, 200); c.px(13, 7, W, 200)
    c.save(f"{OUT}/props/cobweb.png")


def pillar():
    c = C(16, 32)
    c.shadow(8, 30, 8, 2, 100)
    # каменная база
    c.rect(2, 26, 13, 30, ST1)
    c.rect(2, 26, 13, 26, ST2); c.rect(2, 30, 13, 30, ST0)
    c.rect(1, 25, 14, 25, ST2); c.rect(2, 24, 13, 24, ST1)
    for x in (1, 14): c.rect(x, 25, x, 30, INK)
    c.rect(2, 31, 13, 31, INK)
    for (x, y) in [(5, 28), (10, 27), (8, 29)]: c.px(x, y, ST0)
    # лакированный столб
    for y in range(4, 24):
        for x in range(4, 12):
            col = {4: CR1, 5: CR2, 6: CR3, 7: CR2, 8: CR2, 9: CR1, 10: CR0, 11: INK}[x]
            if x == 6 and y % 7 == 3: col = CR2
            c.px(x, y, col)
    for (x, y) in [(5, 9), (6, 10), (9, 14), (5, 18), (7, 21), (10, 7)]:   # облупившийся лак
        c.px(x, y, BR1); c.px(x + 1, y, BR0)
    c.line(8, 12, 9, 17, CR0)
    # верхняя балка
    c.rect(1, 1, 14, 3, BR0); c.rect(1, 1, 14, 1, BR2); c.rect(0, 0, 15, 0, INK)
    c.rect(2, 4, 13, 4, N2); c.rect(3, 3, 12, 3, BR1)
    c.save(f"{OUT}/props/pillar.png")


def table():
    c = C(48, 32)
    c.shadow(24, 28, 22, 3, 85)
    # подушки
    for ox in (0, 40):
        c.blob(ox + 4, 18, 4.2, 5, (CR0, CR1, CR2), outline=INK)
        c.px(ox + 4, 18, CR3); c.px(ox + 3, 14, CR3)
    c.px(2, 21, BONE); c.px(3, 22, BONE)       # торчит вата
    # ножки
    for x in (8, 9, 38, 39):
        for y in range(23, 29):
            c.px(x, y, BR0 if x % 2 else INK)
    # столешница
    c.rect(6, 7, 41, 21, BR1)
    c.rect(6, 7, 41, 8, BR2)            # блик у дальнего края
    c.rect(6, 9, 41, 19, mix(BR1, BR0, 0.35))
    for x in range(7, 41, 3): c.px(x, 13, BR0); c.px(x + 1, 16, BR0)
    c.rect(6, 20, 41, 21, BR0)          # кромка
    c.rect(6, 22, 41, 23, N2)           # фартук
    c.rect(5, 7, 5, 23, INK); c.rect(42, 7, 42, 23, INK); c.rect(6, 6, 41, 6, INK); c.rect(6, 24, 41, 24, INK)
    # чайник, чашки, свиток
    c.blob(25, 13, 3.6, 2.8, (ST0, ST1, ST2), outline=INK)
    c.line(28, 12, 30, 10, ST1); c.px(21, 12, ST1); c.px(22, 11, ST1)
    c.rect(33, 11, 34, 12, BONE); c.rect(33, 11, 33, 12, SKN)
    c.rect(15, 12, 22, 13, BONE) if False else None
    c.rect(11, 14, 16, 15, SKN); c.rect(11, 14, 16, 14, BONE); c.px(16, 14, CR2); c.px(11, 15, CR2)
    c.px(33, 14, CR2); c.px(34, 15, CR1)
    c.save(f"{OUT}/props/table.png")


def screen():
    c = C(48, 32)
    c.shadow(24, 29, 22, 3, 85)
    for i in range(3):
        ox = i * 16
        top = 3 if i % 2 == 0 else 4
        bot = 27 if i % 2 == 0 else 28
        c.rect(ox, top, ox + 15, bot, BR0)
        for y in range(top + 1, bot):
            for x in range(ox + 2, ox + 14):
                c.px(x, y, (126, 112, 98) if (x + y) % 4 else (116, 102, 90))
        c.rect(ox + 1, top + 1, ox + 14, top + 1, BR1)
        c.rect(ox + 1, bot - 1, ox + 14, bot - 1, BR1)
        c.rect(ox, top, ox, bot, INK); c.rect(ox + 15, top, ox + 15, bot, INK)
        c.px(ox + 3, bot + 1, INK); c.px(ox + 12, bot + 1, INK)
    # роспись: горы, красное солнце, журавль
    for (x, y) in [(2, 22), (3, 20), (4, 18), (5, 17), (6, 18), (7, 20), (8, 21), (9, 22), (10, 20), (11, 19), (12, 21), (13, 23)]:
        for yy in range(y, 26): c.px(x, yy, (46, 36, 48))
    c.blob(24, 12, 4, 4, (CR1, CR2, CR3))
    for (x, y) in [(20, 22), (21, 21), (22, 20), (24, 21), (26, 22), (28, 21), (29, 22)]:
        for yy in range(y, 27): c.px(x, yy, (46, 36, 48))
    # журавль на третьей створке
    c.line(36, 14, 40, 11, INK); c.line(40, 11, 44, 13, INK); c.line(38, 13, 42, 15, INK)
    c.px(44, 12, INK); c.px(45, 12, CR2); c.line(36, 14, 33, 18, INK)
    # кровь и рваные края
    c.line(36, 7, 37, 11, CR2); c.line(37, 11, 37, 13, CR1); c.px(36, 15, CR2); c.px(41, 8, CR1); c.px(42, 9, CR1)
    for (x, y) in [(18, 4), (19, 5), (30, 28), (31, 27), (4, 5), (5, 6)]:
        c.px(x, y, (6, 4, 9))
    c.save(f"{OUT}/props/screen.png")


def lantern():
    c = C(16, 32)
    c.shadow(8, 30, 7, 2, 100)
    # основание
    c.rect(3, 27, 12, 30, ST1); c.rect(3, 27, 12, 27, ST2); c.rect(3, 30, 12, 30, ST0); c.rect(2, 28, 2, 30, INK); c.rect(13, 28, 13, 30, INK)
    c.rect(3, 31, 12, 31, INK)
    # стойка
    for y in range(17, 27):
        c.px(6, y, ST2); c.px(7, y, ST1); c.px(8, y, ST1); c.px(9, y, ST0); c.px(5, y, INK); c.px(10, y, INK)
    c.rect(4, 16, 11, 17, ST1); c.rect(4, 16, 11, 16, ST2)
    # огненная камера
    c.rect(3, 8, 12, 15, ST1); c.rect(2, 8, 2, 15, INK); c.rect(13, 8, 13, 15, INK)
    c.rect(3, 8, 12, 8, ST2); c.rect(3, 15, 12, 15, ST0)
    for y in range(10, 14):
        for x in range(5, 11):
            c.px(x, y, (240, 170, 80) if 6 <= x <= 9 and 11 <= y <= 12 else (190, 96, 42))
    c.px(7, 11, (255, 236, 170)); c.px(8, 11, (255, 236, 170)); c.px(7, 12, (255, 220, 140))
    c.rect(5, 10, 10, 10, (130, 60, 30)) if False else None
    # крыша
    for i, (x0, x1) in enumerate([(2, 13), (1, 14), (0, 15)]):
        y = 5 - i if False else (7 - i * 2 if False else 7 - i)
    c.rect(1, 6, 14, 7, ST1); c.rect(1, 6, 14, 6, ST2); c.rect(0, 7, 15, 7, ST0)
    c.rect(3, 4, 12, 5, ST1); c.rect(3, 4, 12, 4, ST2)
    c.rect(5, 2, 10, 3, ST1); c.rect(5, 2, 10, 2, ST2)
    c.rect(7, 0, 8, 1, ST2); c.px(7, 0, ST3)
    for (x, y) in [(0, 6), (15, 6)]: c.px(x, y, INK)
    c.save(f"{OUT}/props/lantern.png")


def rubble():
    c = C(32, 16)
    rng = np.random.RandomState(8)
    c.shadow(16, 12, 14, 3, 80)
    chunks = [(7, 9, 5, 3.6), (15, 8, 6, 4.2), (24, 10, 4.5, 3.2), (11, 5, 3.4, 2.6), (20, 5, 3.6, 2.8), (28, 12, 2.6, 2)]
    for i, (cx, cy, rx, ry) in enumerate(chunks):
        pal = [(ST0, ST1, ST2), (P0, P1, P2), (BR0, BR1, BR2)][i % 3]
        c.blob(cx, cy, rx, ry, pal, outline=INK)
    for _ in range(18):
        x, y = rng.randint(1, 31), rng.randint(9, 15)
        if c.a[y, x, 3] == 0: c.px(x, y, [P2, ST2, SKN][rng.randint(0, 3)])
    c.px(15, 7, CR2); c.px(16, 8, CR1)
    c.save(f"{OUT}/props/rubble.png")


def well():
    c = C(32, 32)
    c.shadow(16, 28, 14, 3, 90)
    # боковая стенка колодца
    for y in range(15, 27):
        for x in range(2, 30):
            nx = (x - 16) / 14.0
            if abs(nx) <= 1.0 and y <= 15 + 9 + 3.2 * math.sqrt(max(0, 1 - nx * nx)):
                col = ST1 if (x + (y // 4) * 3) % 8 else ST0
                if x < 8: col = ST2 if (x + (y // 4) * 3) % 8 else ST1
                if x > 22: col = ST0 if (x + (y // 4) * 3) % 8 else INK
                c.px(x, y, col)
    for y in (18, 22):
        for x in range(2, 30):
            if c.a[y, x, 3]: c.px(x, y, ST0)
    # верхнее кольцо
    c.blob(16, 14, 14, 8, (ST1, ST2, ST3), outline=INK)
    c.blob(16, 14, 10, 5.4, (INK, (10, 8, 18), (14, 12, 24)))
    c.blob(16, 15, 8, 3.8, ((8, 8, 16), (12, 10, 22), (22, 18, 36)))
    c.px(12, 14, PU2); c.px(13, 13, PU2); c.px(19, 16, PU1); c.px(17, 15, CR1)
    # мох и верёвка с ведром
    for (x, y) in [(4, 20), (5, 21), (24, 19), (25, 20), (6, 18)]:
        c.px(x, y, (40, 56, 36))
    c.line(24, 8, 23, 13, BR2); c.px(24, 8, BR1)
    c.rect(22, 11, 25, 13, BR1) if False else None
    c.rect(26, 7, 28, 8, BR0)
    c.save(f"{OUT}/props/well.png")


if __name__ == "__main__":
    tatami_atlas(); floor_boards()
    for f in (ov_scratch, ov_crack, ov_stain, ov_mold, ov_blood, ov_danger): f()
    wall_face(); wall_post(); wall_cap()
    wall_plaster_dec(); wall_mold_dec(); wall_ofuda_dec(); shoji(False); shoji(True)
    wall_danger(); door_sealed(); door_boss()
    for f in (sandals, plate, bones, candle, charms, kokeshi, puddle, cobweb,
              pillar, table, screen, lantern, rubble, well): f()
    print("ok")
