#!/usr/bin/env python3
"""Generates the original dark-fantasy UI art kit (9-slice frames, buttons, slots, bars, icons, crest).

All shapes are drawn at 4x and downsampled for crisp anti-aliasing. Output: game/assets/ui/*.png
Run: python3 art/pipeline/generate_ui.py
"""

from __future__ import annotations

import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import texgen as tg  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "game" / "assets" / "ui"
SS = 4  # supersampling

GOLD = (214, 178, 106)
GOLD_DIM = (120, 98, 60)
GOLD_BRIGHT = (246, 216, 146)
INK = (14, 12, 11)
INK2 = (26, 22, 19)
EDGE = (4, 3, 3)


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, name):
    w, h = img.size
    out = img.resize((w // SS, h // SS), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / f"{name}.png")
    print(f"[ui] {name}.png {out.size}")
    return out


def noise_fill(w, h, c_top, c_bot, alpha, seed=1, grain=0.06):
    """Vertical gradient with fine stone-like noise (RGBA image at SS scale)."""
    W, H = w * SS, h * SS
    n = tg.fbm(256, seed, 1.4, 6.0)
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), dtype=np.float32) / 255.0
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    top = np.array(c_top, np.float32)
    bot = np.array(c_bot, np.float32)
    col = top * (1 - t[..., None]) + bot * t[..., None]
    col = col * (1.0 + (n[..., None] - 0.5) * grain * 2)
    a = np.full((H, W, 1), alpha * 255.0, np.float32)
    return Image.fromarray(np.clip(np.concatenate([col, a], -1), 0, 255).astype(np.uint8), "RGBA")


def chamfer_poly(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def mask_poly(size, poly):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return m


def corner_ornament(d, cx, cy, sx, sy, s, col):
    """Small gilded flourish: diamond + two curls pointing along the edges."""
    r = 5 * s
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=col)
    w = max(1, int(1.6 * s))
    for k in (1, 2):
        rr = (5 + k * 4) * s
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], start=(0 if sx > 0 else 180) - 30, end=(0 if sx > 0 else 180) + 30, fill=col, width=w)
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], start=(90 if sy > 0 else 270) - 30, end=(90 if sy > 0 else 270) + 30, fill=col, width=w)
    d.line([(cx + sx * r * 1.6, cy), (cx + sx * r * 5.5, cy)], fill=col, width=w)
    d.line([(cx, cy + sy * r * 1.6), (cx, cy + sy * r * 5.5)], fill=col, width=w)


def panel_frame():
    w = h = 160
    img = noise_fill(w, h, (30, 26, 22), (12, 10, 10), 0.93, seed=3)
    m = mask_poly(img.size, chamfer_poly(0, 0, w * SS - 1, h * SS - 1, 10 * SS))
    img.putalpha(Image.fromarray(np.minimum(np.asarray(img.getchannel("A")), np.asarray(m))))
    d = ImageDraw.Draw(img)
    d.polygon(chamfer_poly(1 * SS, 1 * SS, w * SS - 1 * SS, h * SS - 1 * SS, 10 * SS), outline=EDGE + (255,), width=2 * SS)
    d.polygon(chamfer_poly(7 * SS, 7 * SS, w * SS - 7 * SS, h * SS - 7 * SS, 7 * SS), outline=GOLD + (235,), width=int(1.6 * SS))
    d.polygon(chamfer_poly(11 * SS, 11 * SS, w * SS - 11 * SS, h * SS - 11 * SS, 5 * SS), outline=GOLD_DIM + (170,), width=1 * SS)
    for (cx, cy, sx, sy) in ((18, 18, 1, 1), (w - 18, 18, -1, 1), (18, h - 18, 1, -1), (w - 18, h - 18, -1, -1)):
        corner_ornament(d, cx * SS, cy * SS, sx, sy, SS * 0.9, GOLD_BRIGHT + (255,))
    # soft inner top highlight
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).rectangle([14 * SS, 14 * SS, w * SS - 14 * SS, 15 * SS], fill=(255, 230, 180, 40))
    img = Image.alpha_composite(img, hl)
    finish(img, "panel_frame")


def panel_soft():
    w = h = 96
    img = noise_fill(w, h, (24, 21, 18), (14, 12, 11), 0.86, seed=5, grain=0.04)
    m = mask_poly(img.size, chamfer_poly(0, 0, w * SS - 1, h * SS - 1, 6 * SS))
    img.putalpha(Image.fromarray(np.minimum(np.asarray(img.getchannel("A")), np.asarray(m))))
    d = ImageDraw.Draw(img)
    d.polygon(chamfer_poly(1 * SS, 1 * SS, w * SS - SS, h * SS - SS, 6 * SS), outline=GOLD_DIM + (200,), width=SS)
    finish(img, "panel_soft")


def card():
    w = h = 64
    img = noise_fill(w, h, (34, 29, 24), (20, 17, 15), 0.92, seed=7, grain=0.03)
    m = mask_poly(img.size, chamfer_poly(0, 0, w * SS - 1, h * SS - 1, 4 * SS))
    img.putalpha(Image.fromarray(np.minimum(np.asarray(img.getchannel("A")), np.asarray(m))))
    d = ImageDraw.Draw(img)
    d.polygon(chamfer_poly(1 * SS, 1 * SS, w * SS - SS, h * SS - SS, 4 * SS), outline=(70, 60, 46, 255), width=SS)
    d.line([(6 * SS, 2 * SS), (w * SS - 6 * SS, 2 * SS)], fill=(255, 235, 200, 30), width=SS)
    finish(img, "card")


def button(state):
    w, h = 96, 44
    cols = {
        "normal": ((44, 37, 30), (22, 19, 16), GOLD_DIM, 0),
        "hover": ((78, 60, 34), (36, 28, 18), GOLD_BRIGHT, 1),
        "pressed": ((20, 16, 12), (40, 31, 20), GOLD, 0),
        "disabled": ((30, 29, 28), (20, 20, 20), (70, 66, 60), 0),
    }[state]
    img = noise_fill(w, h, cols[0], cols[1], 0.96, seed=11, grain=0.05)
    poly = chamfer_poly(0, 0, w * SS - 1, h * SS - 1, 7 * SS)
    m = mask_poly(img.size, poly)
    img.putalpha(Image.fromarray(np.minimum(np.asarray(img.getchannel("A")), np.asarray(m))))
    d = ImageDraw.Draw(img)
    d.polygon(chamfer_poly(SS, SS, w * SS - SS, h * SS - SS, 7 * SS), outline=cols[2] + (255,), width=int(1.5 * SS))
    if state != "disabled":
        d.line([(10 * SS, 4 * SS), (w * SS - 10 * SS, 4 * SS)], fill=(255, 235, 190, 50 if state != "pressed" else 15), width=SS)
        # side diamonds
        for cx in (6 * SS, w * SS - 6 * SS):
            r = 2.6 * SS
            cy = h * SS / 2
            d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=cols[2] + (255,))
    if cols[3]:
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).polygon(chamfer_poly(3 * SS, 3 * SS, w * SS - 3 * SS, h * SS - 3 * SS, 6 * SS), outline=(255, 200, 110, 140), width=4 * SS)
        glow = glow.filter(ImageFilter.GaussianBlur(3 * SS))
        img = Image.alpha_composite(img, glow)
    finish(img, f"button_{state}")


def slot():
    w = h = 80
    img = noise_fill(w, h, (12, 11, 10), (22, 19, 16), 0.9, seed=13, grain=0.04)
    m = mask_poly(img.size, chamfer_poly(0, 0, w * SS - 1, h * SS - 1, 6 * SS))
    img.putalpha(Image.fromarray(np.minimum(np.asarray(img.getchannel("A")), np.asarray(m))))
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon(chamfer_poly(2 * SS, 2 * SS, w * SS - 2 * SS, h * SS - 2 * SS, 6 * SS), outline=(0, 0, 0, 200), width=8 * SS)
    sh = sh.filter(ImageFilter.GaussianBlur(4 * SS))
    img = Image.alpha_composite(img, sh)
    finish(img, "slot_bg")
    b = canvas(w, h)
    ImageDraw.Draw(b).polygon(chamfer_poly(SS, SS, w * SS - SS, h * SS - SS, 6 * SS), outline=(255, 255, 255, 255), width=2 * SS)
    gl = Image.new("RGBA", b.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).polygon(chamfer_poly(4 * SS, 4 * SS, w * SS - 4 * SS, h * SS - 4 * SS, 5 * SS), outline=(255, 255, 255, 90), width=5 * SS)
    gl = gl.filter(ImageFilter.GaussianBlur(4 * SS))
    finish(Image.alpha_composite(gl, b), "slot_border")


def bars():
    w, h = 200, 22
    poly = chamfer_poly(SS, SS, w * SS - SS, h * SS - SS, 8 * SS)
    # Trough (drawn under the fill) and frame (drawn over it) are separate so the fill stays bright
    b = canvas(w, h)
    ImageDraw.Draw(b).polygon(poly, fill=(6, 5, 5, 205))
    finish(b, "bar_back")
    f = canvas(w, h)
    d = ImageDraw.Draw(f)
    d.polygon(poly, outline=GOLD_DIM + (255,), width=int(1.4 * SS))
    for cx in (3 * SS, w * SS - 3 * SS):
        r = 4 * SS
        cy = h * SS / 2
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=GOLD + (255,))
    finish(f, "bar_frame")
    # grayscale fill with top sheen (tinted per vital in Godot)
    fw, fh = 64, 14
    arr = np.zeros((fh * SS, fw * SS, 4), np.float32)
    t = np.linspace(0, 1, fh * SS)[:, None]
    shade = 0.62 + 0.38 * (1 - t) ** 1.5
    sheen = np.exp(-((t - 0.22) ** 2) / 0.006) * 0.35
    v = np.clip(shade + sheen, 0, 1)
    arr[..., 0] = v * 255
    arr[..., 1] = v * 255
    arr[..., 2] = v * 255
    arr[..., 3] = 255
    img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    m = mask_poly(img.size, chamfer_poly(0, 0, fw * SS - 1, fh * SS - 1, 5 * SS))
    img.putalpha(m)
    finish(img, "bar_fill")


def divider():
    w, h = 512, 24
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cy = h * SS // 2
    for x in range(0, w * SS, SS):
        a = 1.0 - abs(x / (w * SS) - 0.5) * 2
        a = max(0.0, a) ** 0.7
        d.line([(x, cy), (x + SS, cy)], fill=GOLD + (int(230 * a),), width=int(1.4 * SS))
    cx = w * SS // 2
    r = 7 * SS
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=GOLD_BRIGHT + (255,))
    r2 = 3 * SS
    d.polygon([(cx, cy - r2), (cx + r2, cy), (cx, cy + r2), (cx - r2, cy)], fill=INK + (255,))
    for sx in (-1, 1):
        x = cx + sx * 16 * SS
        d.polygon([(x, cy - 3 * SS), (x + 3 * SS, cy), (x, cy + 3 * SS), (x - 3 * SS, cy)], fill=GOLD + (255,))
    finish(img, "divider")


def vignette():
    s = 512
    yy, xx = np.mgrid[0:s, 0:s] / (s - 1)
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 2
    a = np.clip((r - 0.55) / 0.6, 0, 1) ** 1.6
    arr = np.zeros((s, s, 4), np.uint8)
    arr[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(OUT / "vignette.png")
    print("[ui] vignette.png")


def keycap():
    w = h = 48
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([SS, 2 * SS, w * SS - SS, h * SS - SS], radius=8 * SS, fill=(30, 26, 22, 245), outline=GOLD_DIM + (255,), width=int(1.5 * SS))
    d.rounded_rectangle([4 * SS, 4 * SS, w * SS - 4 * SS, h * SS - 7 * SS], radius=6 * SS, fill=(58, 49, 39, 255), outline=(110, 92, 62, 255), width=SS)
    d.line([(8 * SS, 6 * SS), (w * SS - 8 * SS, 6 * SS)], fill=(255, 235, 200, 50), width=SS)
    finish(img, "keycap")


def compass_bg():
    w, h = 640, 44
    arr = np.zeros((h * SS, w * SS, 4), np.float32)
    x = np.linspace(0, 1, w * SS)[None, :]
    fade = np.clip(1 - np.abs(x - 0.5) * 2, 0, 1) ** 0.5
    arr[..., 0] = 14
    arr[..., 1] = 12
    arr[..., 2] = 11
    arr[..., 3] = 200 * fade
    img = Image.fromarray(arr.astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    for yline in (2 * SS, h * SS - 3 * SS):
        for xx in range(0, w * SS, SS):
            a = max(0.0, 1 - abs(xx / (w * SS) - 0.5) * 2) ** 0.6
            d.line([(xx, yline), (xx + SS, yline)], fill=GOLD + (int(220 * a),), width=int(1.2 * SS))
    finish(img, "compass_bg")


def icon(name, draw_fn, size=64):
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    draw_fn(d, size * SS)
    # dark outline for legibility
    a = np.asarray(img.getchannel("A"))
    outline = Image.fromarray(a).filter(ImageFilter.MaxFilter(1 + 2 * (2 * SS // 2)))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    base.putalpha(outline.point(lambda v: int(v * 0.85)))
    out = Image.alpha_composite(base, img)
    finish(out, f"icon_{name}")


def _skull(d, S):
    c = S / 2
    d.ellipse([c - S * 0.3, S * 0.14, c + S * 0.3, S * 0.66], fill="white")
    d.rectangle([c - S * 0.17, S * 0.55, c + S * 0.17, S * 0.82], fill="white")
    for sx in (-1, 1):
        d.ellipse([c + sx * S * 0.13 - S * 0.08, S * 0.38, c + sx * S * 0.13 + S * 0.08, S * 0.54], fill=(0, 0, 0, 0))
    d.polygon([(c, S * 0.56), (c - S * 0.04, S * 0.64), (c + S * 0.04, S * 0.64)], fill=(0, 0, 0, 0))
    for i in range(-2, 3):
        d.line([(c + i * S * 0.06, S * 0.7), (c + i * S * 0.06, S * 0.82)], fill=(0, 0, 0, 0), width=int(S * 0.025))


def _shield(d, S):
    c = S / 2
    d.polygon([(c, S * 0.1), (S * 0.84, S * 0.22), (S * 0.8, S * 0.52), (c, S * 0.9), (S * 0.2, S * 0.52), (S * 0.16, S * 0.22)], fill="white")
    d.line([(c, S * 0.2), (c, S * 0.78)], fill=(0, 0, 0, 0), width=int(S * 0.06))
    d.line([(S * 0.28, S * 0.42), (S * 0.72, S * 0.42)], fill=(0, 0, 0, 0), width=int(S * 0.06))


def _chest(d, S):
    d.rounded_rectangle([S * 0.14, S * 0.42, S * 0.86, S * 0.84], radius=int(S * 0.04), fill="white")
    d.pieslice([S * 0.14, S * 0.18, S * 0.86, S * 0.66], 180, 360, fill="white")
    d.line([(S * 0.14, S * 0.44), (S * 0.86, S * 0.44)], fill=(0, 0, 0, 0), width=int(S * 0.04))
    d.rectangle([S * 0.44, S * 0.38, S * 0.56, S * 0.56], fill=(0, 0, 0, 0))


def _stairs(d, S):
    for i in range(4):
        y = S * (0.2 + i * 0.16)
        d.rectangle([S * (0.14 + i * 0.18), y, S * 0.86, y + S * 0.12], fill="white")


def _door(d, S):
    d.rectangle([S * 0.22, S * 0.36, S * 0.78, S * 0.88], fill="white")
    d.pieslice([S * 0.22, S * 0.1, S * 0.78, S * 0.62], 180, 360, fill="white")
    d.rectangle([S * 0.36, S * 0.42, S * 0.64, S * 0.88], fill=(0, 0, 0, 0))
    d.pieslice([S * 0.36, S * 0.26, S * 0.64, S * 0.56], 180, 360, fill=(0, 0, 0, 0))


def _diamond(d, S):
    c = S / 2
    d.polygon([(c, S * 0.1), (S * 0.9, c), (c, S * 0.9), (S * 0.1, c)], fill="white")
    d.polygon([(c, S * 0.3), (S * 0.7, c), (c, S * 0.7), (S * 0.3, c)], fill=(0, 0, 0, 0))


def _player_arrow(d, S):
    c = S / 2
    d.polygon([(c, S * 0.08), (S * 0.82, S * 0.9), (c, S * 0.7), (S * 0.18, S * 0.9)], fill="white")


def _coin(d, S):
    d.ellipse([S * 0.12, S * 0.12, S * 0.88, S * 0.88], fill="white")
    d.ellipse([S * 0.24, S * 0.24, S * 0.76, S * 0.76], outline=(0, 0, 0, 0), width=int(S * 0.05))
    c = S / 2
    d.polygon([(c, S * 0.34), (S * 0.64, c), (c, S * 0.66), (S * 0.36, c)], fill=(0, 0, 0, 0))


def _flame(d, S):
    c = S / 2
    d.polygon([(c, S * 0.06), (S * 0.72, S * 0.4), (S * 0.8, S * 0.66), (c, S * 0.94), (S * 0.2, S * 0.66), (S * 0.3, S * 0.42), (S * 0.42, S * 0.5)], fill="white")


def _heart(d, S):
    d.ellipse([S * 0.1, S * 0.16, S * 0.53, S * 0.58], fill="white")
    d.ellipse([S * 0.47, S * 0.16, S * 0.9, S * 0.58], fill="white")
    d.polygon([(S * 0.12, S * 0.45), (S * 0.88, S * 0.45), (S * 0.5, S * 0.9)], fill="white")


def _bolt(d, S):
    d.polygon([(S * 0.56, S * 0.06), (S * 0.22, S * 0.56), (S * 0.46, S * 0.56), (S * 0.38, S * 0.94), (S * 0.78, S * 0.4), (S * 0.52, S * 0.4)], fill="white")


def _sword(d, S):
    d.polygon([(S * 0.5, S * 0.04), (S * 0.57, S * 0.14), (S * 0.57, S * 0.64), (S * 0.43, S * 0.64), (S * 0.43, S * 0.14)], fill="white")
    d.rectangle([S * 0.26, S * 0.64, S * 0.74, S * 0.7], fill="white")
    d.rectangle([S * 0.46, S * 0.7, S * 0.54, S * 0.88], fill="white")
    d.ellipse([S * 0.43, S * 0.86, S * 0.57, S * 0.98], fill="white")


def _gear(d, S):
    c = S / 2
    for i in range(8):
        a = i / 8 * math.tau
        d.polygon([(c + math.cos(a - 0.2) * S * 0.3, c + math.sin(a - 0.2) * S * 0.3), (c + math.cos(a - 0.12) * S * 0.44, c + math.sin(a - 0.12) * S * 0.44),
                   (c + math.cos(a + 0.12) * S * 0.44, c + math.sin(a + 0.12) * S * 0.44), (c + math.cos(a + 0.2) * S * 0.3, c + math.sin(a + 0.2) * S * 0.3)], fill="white")
    d.ellipse([c - S * 0.32, c - S * 0.32, c + S * 0.32, c + S * 0.32], fill="white")
    d.ellipse([c - S * 0.13, c - S * 0.13, c + S * 0.13, c + S * 0.13], fill=(0, 0, 0, 0))


def crest():
    S = 512
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    k = SS
    c = S * k / 2
    # outer ring
    d.ellipse([c - 230 * k, c - 230 * k, c + 230 * k, c + 230 * k], outline=(255, 255, 255, 255), width=10 * k)
    d.ellipse([c - 208 * k, c - 208 * k, c + 208 * k, c + 208 * k], outline=(255, 255, 255, 200), width=3 * k)
    for i in range(24):
        a = i / 24 * math.tau
        r0, r1 = 214 * k, 226 * k
        d.line([(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * r1, c + math.sin(a) * r1)], fill=(255, 255, 255, 255), width=3 * k)
    # crossed axes
    for sgn in (-1, 1):
        d.line([(c - sgn * 150 * k, c + 160 * k), (c + sgn * 120 * k, c - 120 * k)], fill=(255, 255, 255, 255), width=16 * k)
        hx, hy = c + sgn * 112 * k, c - 112 * k
        d.pieslice([hx - 70 * k, hy - 70 * k, hx + 70 * k, hy + 70 * k], start=(205 if sgn > 0 else -25), end=(335 if sgn > 0 else 105), fill=(255, 255, 255, 255))
    # skull
    R = 88 * k
    d.ellipse([c - R, c - R - 10 * k, c + R, c + R * 0.85], fill=(255, 255, 255, 255))
    d.rectangle([c - R * 0.6, c + R * 0.4, c + R * 0.6, c + R * 1.15], fill=(255, 255, 255, 255))
    for sx in (-1, 1):
        d.ellipse([c + sx * R * 0.42 - R * 0.26, c - R * 0.05, c + sx * R * 0.42 + R * 0.26, c + R * 0.42], fill=(0, 0, 0, 0))
    d.polygon([(c, c + R * 0.45), (c - R * 0.14, c + R * 0.72), (c + R * 0.14, c + R * 0.72)], fill=(0, 0, 0, 0))
    for i in range(-2, 3):
        d.line([(c + i * R * 0.22, c + R * 0.85), (c + i * R * 0.22, c + R * 1.15)], fill=(0, 0, 0, 0), width=6 * k)
    # crown
    pts = [(c - R, c - R * 0.55)]
    for i in range(5):
        x0 = c - R + i * (2 * R) / 5
        pts += [(x0 + R / 5, c - R * 1.45), (x0 + 2 * R / 5, c - R * 0.85)]
    pts += [(c + R, c - R * 0.55)]
    d.polygon(pts, fill=(255, 255, 255, 255))
    # gold gradient fill
    a = np.asarray(img.getchannel("A")).astype(np.float32) / 255.0
    H = a.shape[0]
    t = np.linspace(0, 1, H)[:, None]
    r = 255 * (0.98 - 0.25 * t)
    g = 255 * (0.84 - 0.32 * t)
    b = 255 * (0.52 - 0.3 * t)
    rgb = np.stack([np.broadcast_to(r, a.shape), np.broadcast_to(g, a.shape), np.broadcast_to(b, a.shape)], -1)
    out = np.concatenate([rgb, (a * 255)[..., None]], -1).astype(np.uint8)
    gold = Image.fromarray(out, "RGBA")
    sh = Image.new("RGBA", gold.size, (0, 0, 0, 0))
    sh.putalpha(Image.fromarray((a * 200).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * k)))
    finish(Image.alpha_composite(sh, gold), "crest")


def cursor():
    s = 32
    img = canvas(s, s)
    d = ImageDraw.Draw(img)
    k = SS
    pts = [(2 * k, 2 * k), (2 * k, 24 * k), (8 * k, 18 * k), (12 * k, 28 * k), (16 * k, 26 * k), (12 * k, 16 * k), (20 * k, 16 * k)]
    d.polygon(pts, fill=(10, 8, 6, 255))
    inner = [(4 * k, 6 * k), (4 * k, 20 * k), (8.5 * k, 15.5 * k), (12.5 * k, 25 * k), (13.5 * k, 24.5 * k), (9.5 * k, 14.5 * k), (16 * k, 14.5 * k)]
    d.polygon(inner, fill=GOLD_BRIGHT + (255,))
    finish(img, "cursor")


def check_icons():
    for name, checked in (("check_off", False), ("check_on", True)):
        s = 28
        img = canvas(s, s)
        d = ImageDraw.Draw(img)
        k = SS
        d.polygon(chamfer_poly(2 * k, 2 * k, s * k - 2 * k, s * k - 2 * k, 4 * k), fill=(12, 10, 9, 230), outline=GOLD_DIM + (255,), width=int(1.5 * k))
        if checked:
            d.polygon(chamfer_poly(7 * k, 7 * k, s * k - 7 * k, s * k - 7 * k, 3 * k), fill=GOLD_BRIGHT + (255,))
        finish(img, name)


def slider_parts():
    s = 28
    img = canvas(s, s)
    d = ImageDraw.Draw(img)
    k = SS
    c = s * k / 2
    d.polygon([(c, 2 * k), (s * k - 2 * k, c), (c, s * k - 2 * k), (2 * k, c)], fill=GOLD_BRIGHT + (255,), outline=EDGE + (255,))
    d.polygon([(c, 8 * k), (s * k - 8 * k, c), (c, s * k - 8 * k), (8 * k, c)], fill=(90, 70, 40, 255))
    finish(img, "slider_grabber")


def map_paper(size=1024, seed=77):
    """Clean aged vellum for the dungeon map: fibres, foxing stains, a faint survey grid and darkened edges
    (no handwriting rows, unlike the quest-board parchment material)."""
    base = tg.fbm(size, seed, 2.0, 2.0)
    fib = tg.fbm(size, seed + 1, 0.6, 160.0)
    stains = tg.smoothstep(0.58, 0.86, tg.fbm(size, seed + 2, 2.4, 3.0))
    fox = tg.smoothstep(0.78, 0.9, tg.fbm(size, seed + 3, 1.2, 14.0))
    alb = tg.colorize(tg.normalize(0.72 * base + 0.28 * fib), [(0.0, "#8f7752"), (0.5, "#bba478"), (1.0, "#d8c69c")])
    alb = tg.blend(alb, alb * np.array([0.74, 0.6, 0.42], np.float32), stains * 0.55)
    alb = tg.blend(alb, alb * np.array([0.62, 0.46, 0.3], np.float32), fox * 0.5)
    u, v = tg.grid(size)
    cells = 16
    gx = np.abs(((u * cells) % 1.0) - 0.5)
    gy = np.abs(((v * cells) % 1.0) - 0.5)
    gridline = np.maximum(tg.smoothstep(0.47, 0.5, gx), tg.smoothstep(0.47, 0.5, gy))
    alb = tg.blend(alb, alb * np.array([0.8, 0.72, 0.6], np.float32), gridline * 0.22)
    rgb = (np.clip(alb, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(OUT / "map_paper.webp", quality=90, method=6)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    map_paper()
    panel_frame()
    panel_soft()
    card()
    for st in ("normal", "hover", "pressed", "disabled"):
        button(st)
    slot()
    bars()
    divider()
    vignette()
    keycap()
    compass_bg()
    for nm, fn in (("skull", _skull), ("shield", _shield), ("chest", _chest), ("stairs", _stairs), ("door", _door),
                   ("diamond", _diamond), ("player", _player_arrow), ("coin", _coin), ("flame", _flame), ("heart", _heart),
                   ("bolt", _bolt), ("sword", _sword), ("gear", _gear)):
        icon(nm, fn)
    crest()
    cursor()
    check_icons()
    slider_parts()


if __name__ == "__main__":
    main()
