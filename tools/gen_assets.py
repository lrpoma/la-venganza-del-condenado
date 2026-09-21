#!/usr/bin/env python3
"""Genera el pixel art y el audio del juego (sin dependencias externas).

Uso:  python3 tools/gen_assets.py
Salida: assets/sprites/*.png, assets/audio/*.ogg
Los sprites se dibujan a baja resolución y se amplían x3 (SCALE) para el look pixel art.
Para reemplazar cualquier asset por arte propio basta con sobrescribir el archivo
(mismo nombre y mismo número de frames horizontales).
"""
import math
import os
import random
import struct
import subprocess
import wave
import zlib

random.seed(11)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
SPR = os.path.join(ROOT, "sprites")
AUD = os.path.join(ROOT, "audio")
os.makedirs(SPR, exist_ok=True)
os.makedirs(AUD, exist_ok=True)
SCALE = 3


def H(hexstr, a=255):
    hexstr = hexstr.lstrip("#")
    return (int(hexstr[0:2], 16), int(hexstr[2:4], 16), int(hexstr[4:6], 16), a)


OUTLINE = H("#07080f")


class Img:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.p = [[None] * w for _ in range(h)]

    def px(s, x, y, c):
        if 0 <= x < s.w and 0 <= y < s.h:
            s.p[y][x] = c

    def rect(s, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                s.px(i, j, c)

    def ell(s, cx, cy, rx, ry, c):
        for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((i + .5 - cx) / rx) ** 2 + ((j + .5 - cy) / ry) ** 2 <= 1:
                    s.px(i, j, c)

    def line(s, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for k in range(n + 1):
            s.px(round(x0 + (x1 - x0) * k / n), round(y0 + (y1 - y0) * k / n), c)

    def outline(s, c=OUTLINE):
        o = [row[:] for row in s.p]
        for y in range(s.h):
            for x in range(s.w):
                if s.p[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < s.w and 0 <= ny < s.h and s.p[ny][nx] is not None:
                            o[y][x] = c
                            break
        s.p = o
        return s

    def scaled(s, n=SCALE):
        o = Img(s.w * n, s.h * n)
        for y in range(s.h):
            for x in range(s.w):
                c = s.p[y][x]
                if c:
                    o.rect(x * n, y * n, n, n, c)
        return o

    def save(s, name):
        raw = b""
        for row in s.p:
            raw += b"\x00" + b"".join(bytes(c) if c else b"\x00\x00\x00\x00" for c in row)

        def chunk(t, d):
            c = struct.pack(">I", len(d)) + t + d
            return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
        data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", s.w, s.h, 8, 6, 0, 0, 0))
        data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
        with open(os.path.join(SPR, name + ".png"), "wb") as f:
            f.write(data)


def sheet(frames):
    out = Img(sum(f.w for f in frames), frames[0].h)
    x = 0
    for f in frames:
        for j in range(f.h):
            for i in range(f.w):
                out.p[j][x + i] = f.p[j][i]
        x += f.w
    return out


def emit(name, frames):
    """Guarda un spritesheet horizontal ya ampliado."""
    sheet([f.outline().scaled() for f in frames]).save(name)


# --------------------------------------------------------------------------- personajes
def human(frame, skin, skin_d, cloth, cloth_d, eye, hat=None, hat2=None, knife=False, ragged=True):
    i = Img(16, 24)
    b = frame
    # piernas
    la, lb = (6, 5) if frame == 0 else (5, 6)
    i.rect(5, 17 + b, 2, 6 - b, cloth_d)
    i.rect(9, 17 + b, 2, 5 + b, cloth_d)
    i.rect(5, 22, 3, 2, skin_d) if frame == 0 else i.rect(9, 22, 3, 2, skin_d)
    # torso
    i.rect(4, 9 + b, 8, 8, cloth)
    if ragged:
        for x in range(4, 12, 2):
            i.rect(x, 17 + b, 1, 2, cloth)
        i.px(6, 11 + b, cloth_d)
        i.px(9, 13 + b, cloth_d)
    i.rect(4, 15 + b, 8, 1, cloth_d)
    # brazos
    i.rect(2, 10 + b, 2, 7, skin)
    i.rect(12, 10 + b, 2, 7, skin)
    # cabeza
    i.ell(8, 5 + b, 3.6, 4, skin)
    i.rect(5, 7 + b, 6, 1, skin_d)
    i.px(6, 5 + b, eye)
    i.px(9, 5 + b, eye)
    i.px(8, 8 + b, OUTLINE)
    if hat:
        i.rect(4, 1 + b, 8, 3, hat)
        i.rect(3, 3 + b, 10, 1, hat2 or hat)
    if knife:
        i.rect(13, 14 + b, 1, 2, skin)
        i.line(14, 10 + b, 14, 14 + b, H("#c8d2dc"))
    return i


def dog(frame, fur, fur_d, eye, collar=None):
    i = Img(24, 16)
    b = 1 if frame else 0
    i.ell(11, 8, 7.5, 4, fur)
    i.rect(6, 9, 10, 2, fur_d)
    i.ell(19, 6 + b, 3.5, 3, fur)
    i.rect(20, 6 + b, 4, 3, fur)
    i.px(23, 6 + b, OUTLINE)
    i.rect(17, 2 + b, 2, 3, fur_d)
    i.rect(20, 3 + b, 1, 2, fur_d)
    i.px(20, 5 + b, eye)
    i.px(19, 5 + b, eye)
    i.px(22, 8 + b, H("#eeeeee"))
    if collar:
        i.rect(16, 7, 1, 3, collar)
    # cola
    i.line(4, 6, 2, 3 + b, fur)
    # patas
    if frame == 0:
        i.rect(15, 11, 2, 4, fur)
        i.rect(12, 11, 2, 3, fur_d)
        i.rect(6, 11, 2, 3, fur_d)
        i.rect(3, 11, 2, 4, fur)
    else:
        i.rect(16, 11, 2, 3, fur)
        i.rect(12, 11, 2, 4, fur_d)
        i.rect(6, 11, 2, 4, fur_d)
        i.rect(4, 11, 2, 3, fur)
    return i


def whirl(frame):
    i = Img(16, 24)
    cols = [H("#e8f4ff", 230), H("#8fd0ff", 220), H("#4a86d8", 210)]
    for y in range(24):
        t = 1 - y / 23
        w = int(2 + t * 12)
        cx = 8 + round(2 * math.sin(y * 0.55 + frame * 1.6) * (0.4 + t))
        x0 = cx - w // 2
        c = cols[(y // 2 + frame) % 3]
        i.rect(x0, y, w, 1, c)
        i.px(x0, y, cols[2])
        i.px(x0 + w - 1, y, cols[2])
    for k in range(6):
        i.px(random.randint(0, 15), random.randint(2, 20), H("#cfe8ff", 200))
    i.rect(6, 7, 1, 2, H("#ffb02e"))
    i.rect(9, 7, 1, 2, H("#ffb02e"))
    return i


def yatiri(frame):
    i = Img(16, 26)
    b = frame
    glow = H("#7fe8ff", 90)
    i.ell(8, 14 + b, 8, 10, glow)
    robe, robe_d = H("#5f7ca8"), H("#3b527a")
    for y in range(11, 22):
        w = 6 + (y - 11)
        i.rect(8 - w // 2, y + b, w, 1, robe if y % 3 else robe_d)
    for k, y in enumerate(range(22, 26)):
        i.rect(3 + k * 2 + (k + frame) % 2, y - 1 + b, 2, 1, H("#9fc8f0", 160 - k * 30))
    i.ell(8, 8 + b, 3.4, 3.8, H("#c9d4dc"))
    i.rect(5, 10 + b, 6, 4, H("#f0f4f8"))  # barba
    i.rect(6, 14 + b, 4, 1, H("#f0f4f8"))
    i.px(6, 8 + b, H("#7fe8ff"))
    i.px(9, 8 + b, H("#7fe8ff"))
    # chullo (gorro con orejeras)
    i.rect(4, 3 + b, 8, 3, H("#a8402e"))
    i.rect(5, 2 + b, 6, 1, H("#e0a030"))
    i.rect(4, 6 + b, 1, 4, H("#a8402e"))
    i.rect(11, 6 + b, 1, 4, H("#a8402e"))
    i.px(4, 10 + b, H("#e0a030"))
    i.px(11, 10 + b, H("#e0a030"))
    i.px(8, 1 + b, H("#e0a030"))
    return i


def boss(frame):
    i = Img(20, 28)
    b = frame
    skin, skin_d = H("#b98055"), H("#8a5a3a")
    pon, pon_d = H("#1c1c26"), H("#0e0e15")
    i.rect(6, 21 + b, 3, 6 - b, pon_d)
    i.rect(11, 21 + b, 3, 5 + b, pon_d)
    for y in range(11, 23):
        w = 10 + (y - 11) // 2
        i.rect(10 - w // 2, y + b, w, 1, pon if y % 4 else H("#7a2418"))
    i.rect(6, 15 + b, 8, 1, H("#e08a1e"))
    i.rect(3, 12 + b, 2, 8, skin)
    i.rect(15, 12 + b, 2, 8, skin)
    i.ell(10, 7 + b, 4, 4.5, skin)
    i.rect(6, 9 + b, 8, 3, H("#2a2020"))   # barba
    i.px(8, 7 + b, H("#ff3030"))
    i.px(12, 7 + b, H("#ff3030"))
    # sombrero
    i.rect(5, 2 + b, 10, 3, H("#231a17"))
    i.rect(3, 4 + b, 14, 1, H("#231a17"))
    i.rect(5, 4 + b, 10, 1, H("#e08a1e"))
    # incensario
    i.line(2, 19 + b, 2, 23 + b, H("#888888"))
    i.ell(2, 24 + b, 2.2, 2.2, H("#ff8a1a"))
    i.px(2, 24 + b, H("#ffe070"))
    i.px(2, 21 + b, H("#c0c0c0", 180))
    return i


def altar():
    i = Img(24, 20)
    st, st_d = H("#6d7385"), H("#464b5c")
    i.rect(2, 12, 20, 8, st)
    i.rect(2, 17, 20, 3, st_d)
    i.rect(5, 6, 14, 6, st)
    i.rect(5, 10, 14, 2, st_d)
    for x in (8, 15):
        i.rect(x, 2, 2, 4, H("#f0ead8"))
        i.px(x, 1, H("#ffd060"))
        i.px(x + 1, 0, H("#ff8a1a"))
    i.rect(10, 5, 4, 1, H("#3fa055"))
    i.px(11, 4, H("#5ec070"))
    return i


def pickup(kind):
    if kind == "bone":
        i = Img(12, 8)
        w = H("#f1ecd8")
        i.rect(2, 3, 8, 2, w)
        i.rect(0, 2, 2, 2, w)
        i.rect(0, 4, 2, 2, w)
        i.rect(10, 2, 2, 2, w)
        i.rect(10, 4, 2, 2, w)
        i.rect(3, 4, 6, 1, H("#c9c2a8"))
        return i
    if kind == "coca":
        i = Img(10, 10)
        for k in range(5):
            i.ell(2 + k * 1.5, 5 + (k % 2) * 1.5, 1.6, 3.2, H("#3fa055") if k % 2 else H("#5ec070"))
        i.rect(2, 8, 6, 1, H("#a8402e"))
        return i
    if kind == "amulet":
        i = Img(12, 12)
        i.ell(6, 6, 5, 5, H("#e0a030"))
        i.ell(6, 6, 3.4, 3.4, H("#2ec4c4"))
        i.px(5, 5, H("#c8ffff"))
        i.px(6, 1, H("#e0a030"))
        return i
    i = Img(14, 10)
    for cx, cy, r in ((4, 6, 3.4), (9, 6, 3.6), (7, 3, 3)):
        i.ell(cx, cy, r, r * .85, H("#f4c430"))
    i.px(3, 5, H("#fff6b0"))
    i.px(8, 5, H("#fff6b0"))
    i.px(6, 2, H("#fff6b0"))
    return i


def smoke():
    i = Img(12, 12)
    i.ell(6, 6, 5.5, 5.5, H("#80708a", 200))
    i.ell(6, 6, 3.5, 3.5, H("#e06a1a", 230))
    i.ell(5, 5, 1.6, 1.6, H("#ffd060", 255))
    return i


def knife():
    i = Img(14, 5)
    i.rect(0, 2, 4, 1, H("#5a3a22"))
    i.rect(4, 1, 8, 3, H("#c8d2dc"))
    i.px(12, 2, H("#c8d2dc"))
    i.px(13, 2, H("#ffffff"))
    i.rect(4, 1, 8, 1, H("#eef4fa"))
    return i


def orb():
    i = Img(12, 12)
    i.ell(6, 6, 5.5, 5.5, H("#7fe8ff", 120))
    i.ell(6, 6, 3, 3, H("#e8ffff", 230))
    return i


# --------------------------------------------------------------------------- tiles / fondos
def noise_tile(base, spots, n=40, seed=1):
    r = random.Random(seed)
    i = Img(16, 16)
    i.rect(0, 0, 16, 16, base)
    for _ in range(n):
        i.px(r.randint(0, 15), r.randint(0, 15), r.choice(spots))
    return i


def top_tile(top, top_l, base, spots, seed):
    i = noise_tile(base, spots, 26, seed)
    r = random.Random(seed + 5)
    i.rect(0, 0, 16, 4, top)
    for x in range(16):
        h = r.choice((4, 4, 5, 5, 6))
        for y in range(4, h):
            i.px(x, y, top)
        if r.random() < .5:
            i.px(x, 0, top_l)
    return i


def tile_out(name, i):
    i.scaled().save(name)


def salt_tile():
    r = random.Random(3)
    i = Img(16, 16)
    i.rect(0, 0, 16, 16, H("#c9b95a"))
    for _ in range(38):
        i.px(r.randint(0, 15), r.randint(0, 15), r.choice((H("#fff6c0"), H("#f0e290"), H("#ffffff"), H("#ffd24a"))))
    for x in range(0, 16, 3):
        i.px(x + r.randint(0, 1), 0, H("#ffffff"))
    return i


def incense_tile():
    r = random.Random(9)
    i = Img(16, 16)
    i.rect(0, 0, 16, 16, H("#5a2412"))
    for _ in range(34):
        i.px(r.randint(0, 15), r.randint(0, 15), r.choice((H("#ff8a1a"), H("#ffb040"), H("#c24a14"), H("#7a7080"))))
    for x in range(0, 16, 4):
        i.px(x, 0, H("#ffe070"))
    return i


def ridge(w, h, base, amps, color, seed, extra=None):
    r = random.Random(seed)
    phases = [r.random() * 6.28 for _ in amps]
    i = Img(w, h)
    for x in range(w):
        y = base
        for (k, a), ph in zip(amps, phases):
            y += a * math.sin(2 * math.pi * k * x / w + ph)
        y = int(y)
        for j in range(max(y, 0), h):
            i.px(x, j, color)
    if extra:
        extra(i, r)
    return i


def village(i, r):
    """Casas oscuras con ventanas encendidas sobre la cresta cercana."""
    for cx in range(20, i.w - 20, 45):
        if r.random() < .75:
            gy = None
            for y in range(i.h):
                if i.p[y][cx]:
                    gy = y
                    break
            if gy is None:
                continue
            w, hh = r.randint(12, 18), r.randint(9, 13)
            c = H("#070b16")
            i.rect(cx, gy - hh, w, hh, c)
            for k in range(3):
                i.rect(cx + k * w // 3 - 1 + 1, gy - hh - 2 + k, w // 3 + 1, 1, c)
            if r.random() < .8:
                i.rect(cx + 3, gy - hh + 3, 2, 3, H("#f4b030"))


def stars():
    r = random.Random(4)
    i = Img(432, 240)
    for _ in range(90):
        c = r.choice((H("#ffffff", 230), H("#b0c8ff", 200), H("#7f9ad8", 170)))
        i.px(r.randint(0, 431), r.randint(0, 200), c)
    return i


def moon():
    i = Img(24, 24)
    i.ell(12, 12, 10, 10, H("#e8eefc"))
    for cx, cy, rr in ((8, 9, 2.2), (15, 14, 2.8), (13, 6, 1.5)):
        i.ell(cx, cy, rr, rr, H("#c2cde6"))
    i.ell(12, 12, 12, 12, H("#a8c0f0", 40))
    return i


def prop_house():
    i = Img(36, 26)
    wall, roof = H("#2a2b3e"), H("#1a1b2a")
    i.rect(2, 8, 32, 18, wall)
    for k in range(6):
        i.rect(k, 2 + k, 36 - 2 * k, 1, roof)
    i.rect(0, 8, 36, 1, roof)
    i.rect(6, 12, 5, 5, H("#f4b030"))
    i.rect(8, 12, 1, 5, H("#a86a10"))
    i.rect(22, 14, 7, 12, H("#171826"))
    return i


def prop_tree():
    i = Img(18, 28)
    i.rect(8, 16, 3, 12, H("#3a2a22"))
    for y in range(2, 18):
        w = 3 + (y - 2) // 2
        i.rect(9 - w // 2, y, w, 1, H("#1f3b34") if y % 3 else H("#2a4f44"))
    return i


def prop_rock():
    i = Img(18, 10)
    i.ell(9, 6, 8, 4.2, H("#4a5068"))
    i.ell(7, 5, 4, 2, H("#5c637c"))
    return i


def prop_cross():
    i = Img(10, 20)
    i.rect(4, 0, 2, 20, H("#5a4636"))
    i.rect(0, 4, 10, 2, H("#5a4636"))
    return i


def prop_pillar():
    i = Img(10, 40)
    i.rect(0, 0, 10, 40, H("#3a2f3f"))
    i.rect(0, 0, 10, 3, H("#5a4a55"))
    i.rect(0, 37, 10, 3, H("#5a4a55"))
    for y in range(6, 36, 6):
        i.rect(2, y, 1, 3, H("#2a2130"))
    return i


def gen_sprites():
    # jugador
    skin, skin_d = H("#8fa3ad"), H("#5f7480")
    cloth, cloth_d = H("#3b3f5c"), H("#232640")
    eye = H("#ffb02e")
    emit("player_human", [human(f, skin, skin_d, cloth, cloth_d, eye) for f in (0, 1)])
    emit("player_dog", [dog(f, H("#22222e"), H("#141420"), H("#ff7a1a")) for f in (0, 1)])
    emit("player_whirlwind", [whirl(f) for f in (0, 1)])
    # enemigos
    emit("enemy_dog", [dog(f, H("#6b5a48"), H("#463a2e"), H("#ff2a2a"), H("#a8402e")) for f in (0, 1)])
    emit("friend1", [human(f, H("#c48a5a"), H("#96643c"), H("#8a3b2a"), H("#5a2418"), H("#1a1a1a"),
                           H("#2a2320"), H("#e08a1e"), knife=True, ragged=False) for f in (0, 1)])
    emit("friend2", [human(f, H("#b87a4c"), H("#8a5634"), H("#2f6a4a"), H("#1e4630"), H("#1a1a1a"),
                           H("#5a4030"), H("#c0a040"), knife=True, ragged=False) for f in (0, 1)])
    emit("boss", [boss(f) for f in (0, 1)])
    emit("yatiri", [yatiri(f) for f in (0, 1)])
    emit("altar", [altar()])
    for k in ("bone", "coca", "amulet", "gold"):
        emit("item_" + k, [pickup(k)])
    emit("incense_smoke", [smoke()])
    emit("knife", [knife()])
    emit("spirit_orb", [orb()])

    # tiles (16x16 -> 48x48)
    dirt = [H("#3a3850"), H("#1f1e2c"), H("#4a4864")]
    tile_out("tile_dirt_top", top_tile(H("#22423f"), H("#3b6a5e"), H("#2b2a3c"), dirt, 1))
    tile_out("tile_dirt_fill", noise_tile(H("#2b2a3c"), dirt, 34, 2))
    rock = [H("#50566e"), H("#2c3044"), H("#616884")]
    tile_out("tile_rock_top", top_tile(H("#6a7290"), H("#8a93b4"), H("#3d4256"), rock, 3))
    tile_out("tile_rock_fill", noise_tile(H("#3d4256"), rock, 34, 4))
    wood = [H("#6a4632"), H("#301c12"), H("#7a5440")]
    tile_out("tile_wood_top", top_tile(H("#7a5440"), H("#a07458"), H("#4a2f22"), wood, 5))
    tile_out("tile_wood_fill", noise_tile(H("#4a2f22"), wood, 30, 6))
    wall = [H("#5a4658"), H("#382a38"), H("#6a5468")]
    tile_out("tile_wall", noise_tile(H("#453545"), wall, 30, 7))
    tile_out("tile_salt", salt_tile())
    tile_out("tile_incense", incense_tile())

    # fondos (ya x3)
    W = 432
    far = ridge(W, 130, 55, [(2, 22), (5, 9), (11, 3)], H("#1a2a4c"), 1)
    mid = ridge(W, 110, 40, [(3, 14), (7, 6), (13, 3)], H("#101d38"), 2)
    near = ridge(W, 80, 30, [(4, 8), (9, 4), (17, 2)], H("#0a1226"), 3, village)
    far.scaled().save("bg_mountains_far")
    mid.scaled().save("bg_mountains_mid")
    near.scaled().save("bg_hills_near")
    stars().scaled().save("bg_stars")
    moon().scaled().save("bg_moon")

    for n, f in (("prop_house", prop_house), ("prop_tree", prop_tree), ("prop_rock", prop_rock),
                 ("prop_cross", prop_cross), ("prop_pillar", prop_pillar)):
        emit(n, [f()])

    # icono de titulo: fantasma del condenado grande
    title = Img(64, 64)
    title.ell(32, 32, 30, 30, H("#e8eefc", 30))
    title.save("title_glow")


# --------------------------------------------------------------------------- audio
SR = 22050


def save_audio(name, samples, ogg=True, gain=0.9):
    peak = max(1e-9, max(abs(s) for s in samples))
    pcm = b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * gain)) * 32767)) for s in samples)
    wav_path = os.path.join(AUD, name + ".wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    if ogg:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3",
                        os.path.join(AUD, name + ".ogg")], check=True)
        os.remove(wav_path)


def noise(n, rnd):
    return [rnd.uniform(-1, 1) for _ in range(n)]


def lowpass(x, a):
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def bandpass(x, lo, hi):
    lp = lowpass(x, hi)
    l2 = lowpass(x, lo)
    return [a - b for a, b in zip(lp, l2)]


def env(n, a, d):
    return [min(1, i / max(1, a * SR)) * math.exp(-i / SR / d) for i in range(n)]


def tone(n, f0, f1=None, wave_="sin", vib=0):
    f1 = f0 if f1 is None else f1
    ph, out = 0.0, []
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t + (vib * math.sin(2 * math.pi * 5.5 * i / SR) if vib else 0)
        ph += 2 * math.pi * f / SR
        s = math.sin(ph)
        if wave_ == "sq":
            s = 1.0 if s > 0 else -1.0
        elif wave_ == "saw":
            s = (ph / math.pi) % 2 - 1
        out.append(s)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, k):
    return [x * k for x in a]


def reverb(x, delays=((0.21, .45), (0.34, .38), (0.53, .3)), tail=0.0):
    n = len(x)
    out = x[:] + [0.0] * int(tail * SR)
    for d, g in delays:
        k = int(d * SR)
        for i in range(k, len(out)):
            out[i] += out[i - k] * g * 0.6
    return out


def gen_sfx():
    r = random.Random(5)
    n = int(.4 * SR)
    growl = mul(mix(tone(n, 260, 110, "saw"), scale(tone(n, 130, 70, "sq"), .4), scale(lowpass(noise(n, r), .3), .5)),
                env(n, .01, .16))
    save_audio("sfx_bark", reverb(growl, tail=.3))

    n = int(.18 * SR)
    save_audio("sfx_bite", mul(mix(bandpass(noise(n, r), .05, .5), scale(tone(n, 320, 90, "sq"), .5)), env(n, .002, .05)))

    n = int(1.2 * SR)
    w = bandpass(noise(n, r), .02, .22)
    lfo = [0.65 + 0.35 * math.sin(2 * math.pi * i / n * 2) for i in range(n)]
    save_audio("sfx_wind", mul(w, lfo))

    n = int(.55 * SR)
    hiss = [v * (1.6 if r.random() < .02 else 1) for v in noise(n, r)]
    save_audio("sfx_sizzle", mul(bandpass(hiss, .3, .95), env(n, .005, .22)))

    n = int(.28 * SR)
    save_audio("sfx_hurt", mul(mix(tone(n, 180, 60, "sq"), scale(lowpass(noise(n, r), .25), .8)), env(n, .002, .09)))

    n = int(.5 * SR)
    save_audio("sfx_pickup", mul(mix(tone(n, 660), tone(n, 990), scale(tone(n, 1320), .5)), env(n, .002, .18)))

    n = int(.07 * SR)
    save_audio("sfx_click", mul(mix(lowpass(noise(n, r), .5), scale(tone(n, 220, 120), 1)), env(n, .001, .015)))

    n = int(.05 * SR)
    save_audio("sfx_blip", mul(tone(n, 520, 480, "sq"), env(n, .001, .02)), gain=.4)

    n = int(.5 * SR)
    sweep = mix(tone(n, 200, 900), scale(bandpass(noise(n, r), .05, .4), .8))
    save_audio("sfx_transform", mul(sweep, [math.sin(math.pi * i / n) for i in range(n)]))

    n = int(1.3 * SR)
    save_audio("sfx_death", reverb(mul(mix(tone(n, 300, 40), scale(lowpass(noise(n, r), .1), .5)), env(n, .01, .5)), tail=.4))

    n = int(.6 * SR)
    save_audio("sfx_shield", mul(mix(tone(n, 220), tone(n, 330), tone(n, 440, None, "sin", 6)), env(n, .05, .3)))

    n = int(.5 * SR)
    save_audio("sfx_incense", mul(bandpass(noise(n, r), .03, .3), [math.sin(math.pi * i / n) for i in range(n)]))

    n = int(.3 * SR)
    save_audio("sfx_deflect", mul(mix(tone(n, 1500, 900), tone(n, 2100, 1300)), env(n, .001, .05)), gain=.6)

    n = int(.4 * SR)
    save_audio("sfx_dialog_open", mul(mix(tone(n, 440), tone(n, 660)), env(n, .05, .2)), gain=.6)


PENTA = [293.66, 349.23, 392.0, 440.0, 523.25, 587.33]  # re menor pentatonica (quena)


def music(seconds, tense, seed):
    r = random.Random(seed)
    n = int(seconds * SR)
    out = [0.0] * n
    # bordon
    for f, g in ((73.4, .5), (110.0, .3), (146.8, .1)):
        lfo_p = r.random() * 6
        for i in range(n):
            out[i] += g * math.sin(2 * math.pi * f * i / SR + 0.6 * math.sin(2 * math.pi * 0.11 * i / SR + lfo_p))
    # viento
    wind = lowpass(noise(n, r), .03)
    for i in range(n):
        out[i] += wind[i] * (2.2 + math.sin(2 * math.pi * i / n * 3))
    # melodia de quena
    t = 1.0
    last = 2
    while t < seconds - 3:
        dur = r.choice((1.2, 1.6, 2.4, 3.0)) * (0.7 if tense else 1.0)
        step = r.choice((-2, -1, -1, 1, 1, 2))
        last = max(0, min(len(PENTA) - 1, last + step))
        f = PENTA[last] * (1.0595 if tense and r.random() < .3 else 1.0)
        m = int(dur * SR)
        s0 = int(t * SR)
        ph = 0.0
        for i in range(m):
            if s0 + i >= n:
                break
            vib = 4 * math.sin(2 * math.pi * 5.2 * i / SR) * min(1, i / (0.5 * SR))
            ph += 2 * math.pi * (f + vib) / SR
            a = min(1, i / (0.15 * SR)) * max(0, 1 - i / m) ** 0.7
            breath = r.uniform(-1, 1) * 0.06
            out[s0 + i] += (math.sin(ph) + 0.25 * math.sin(2 * ph) + breath) * a * 0.55
        t += dur + r.choice((0.2, 0.8, 1.4))
    if tense:
        beat = 0.75
        k = 0.0
        while k < seconds - 1:
            s0 = int(k * SR)
            for i in range(int(.35 * SR)):
                if s0 + i < n:
                    out[s0 + i] += 1.6 * math.sin(2 * math.pi * (58 - 25 * i / (.35 * SR)) * i / SR) * math.exp(-i / SR / .1)
            k += beat
    out = reverb(out)[:n]
    fade = int(.05 * SR)
    for i in range(fade):
        out[i] *= i / fade
        out[n - 1 - i] *= i / fade
    return out


def gen_music():
    save_audio("music_ambient", music(34, False, 21), gain=.8)
    save_audio("music_tense", music(30, True, 22), gain=.8)
    n = int(6 * SR)
    mel = [0.0] * n
    for k, fi in enumerate((0, 2, 3, 4, 5, 3, 4)):
        s0 = int(k * .7 * SR)
        m = int(1.6 * SR)
        for i in range(m):
            if s0 + i < n:
                mel[s0 + i] += math.sin(2 * math.pi * PENTA[fi] * i / SR) * math.exp(-i / SR / .9) * min(1, i / (.1 * SR))
    save_audio("music_victory", reverb(mel, tail=1.0), gain=.8)


if __name__ == "__main__":
    gen_sprites()
    gen_sfx()
    gen_music()
    print("assets generados en", os.path.abspath(ROOT))
