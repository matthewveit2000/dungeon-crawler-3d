"""Tileable procedural texture toolkit (NumPy only).

Every primitive here is *periodic* (wraps seamlessly at the image borders) so the
resulting PBR maps tile perfectly on modular 4 m dungeon pieces. All randomness is
seeded so the whole texture library regenerates bit-identically.

Conventions:
  * Images are float32 arrays in [0, 1], shape (H, W) or (H, W, C).
  * Coordinates u (x, columns) and v (y, rows) live in [0, 1).
  * Normal maps use the OpenGL convention (green = +Y), which both Godot and Blender expect.
"""

from __future__ import annotations

import numpy as np

F32 = np.float32


# ---------------------------------------------------------------------------
# Basic helpers
# ---------------------------------------------------------------------------

def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def grid(size: int) -> tuple[np.ndarray, np.ndarray]:
    """Return (u, v) coordinate grids in [0, 1)."""
    c = (np.arange(size, dtype=F32) + 0.5) / size
    v, u = np.meshgrid(c, c, indexing="ij")
    return u, v


def normalize(a: np.ndarray, lo: float = 0.0, hi: float = 1.0) -> np.ndarray:
    mn, mx = float(a.min()), float(a.max())
    if mx - mn < 1e-9:
        return np.full_like(a, (lo + hi) * 0.5, dtype=F32)
    return (lo + (a - mn) / (mx - mn) * (hi - lo)).astype(F32)


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0.0, 1.0)
    return (t * t * (3.0 - 2.0 * t)).astype(F32)


def lerp(a, b, t):
    return a + (b - a) * t


def hex_rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=F32)


def colorize(t: np.ndarray, stops: list[tuple[float, str]]) -> np.ndarray:
    """Map scalar field t in [0,1] through a colour ramp of (position, hex) stops."""
    pos = np.array([s[0] for s in stops], dtype=F32)
    cols = np.stack([hex_rgb(s[1]) for s in stops])
    out = np.empty(t.shape + (3,), dtype=F32)
    for c in range(3):
        out[..., c] = np.interp(t, pos, cols[:, c])
    return out


def blend(base: np.ndarray, top: np.ndarray, mask: np.ndarray) -> np.ndarray:
    m = mask[..., None] if base.ndim == 3 and mask.ndim == 2 else mask
    return (base * (1.0 - m) + top * m).astype(F32)


def overlay_tint(col: np.ndarray, amount: np.ndarray, strength: float = 0.25) -> np.ndarray:
    """Brighten/darken colour by a signed field centred on 0.5."""
    k = 1.0 + (amount - 0.5)[..., None] * 2.0 * strength
    return np.clip(col * k, 0.0, 1.0).astype(F32)


# ---------------------------------------------------------------------------
# Spectral (FFT) noise — perfectly periodic fractal noise
# ---------------------------------------------------------------------------

def _freq_grid(size: int, sx: float = 1.0, sy: float = 1.0) -> np.ndarray:
    fy = np.fft.fftfreq(size).astype(F32)[:, None] * size * sy
    fx = np.fft.fftfreq(size).astype(F32)[None, :] * size * sx
    return np.sqrt(fx * fx + fy * fy)


def fbm(size: int, seed: int, beta: float = 2.0, lo: float = 1.0, hi: float | None = None,
        sx: float = 1.0, sy: float = 1.0) -> np.ndarray:
    """Periodic fractal noise via spectral synthesis, normalised to [0, 1].

    beta: spectral slope (2 = natural fBm, higher = smoother, lower = rougher).
    lo/hi: band-limit in cycles per image.
    sx/sy: anisotropy (sx > sy stretches features along y, etc.).
    """
    r = rng(seed)
    white = r.standard_normal((size, size)).astype(F32)
    spec = np.fft.fft2(white)
    f = _freq_grid(size, sx, sy)
    f[0, 0] = 1.0
    amp = np.power(f, -beta * 0.5).astype(F32)
    amp[f < lo] = 0.0
    if hi is not None:
        # soft roll-off above hi instead of a hard brick-wall (avoids ringing)
        amp *= np.exp(-np.square(np.maximum(f - hi, 0.0) / (0.15 * hi + 1.0)))
    out = np.real(np.fft.ifft2(spec * amp)).astype(F32)
    return normalize(out)


def blur(img: np.ndarray, sigma_px: float) -> np.ndarray:
    """Periodic gaussian blur via FFT (works on 2D or 3D arrays)."""
    if sigma_px <= 0.0:
        return img
    size = img.shape[0]
    fy = np.fft.fftfreq(size).astype(F32)[:, None]
    fx = np.fft.fftfreq(img.shape[1]).astype(F32)[None, :]
    g = np.exp(-2.0 * (np.pi ** 2) * (sigma_px ** 2) * (fx * fx + fy * fy)).astype(F32)
    if img.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(img) * g)).astype(F32)
    out = np.empty_like(img)
    for c in range(img.shape[2]):
        out[..., c] = np.real(np.fft.ifft2(np.fft.fft2(img[..., c]) * g))
    return out.astype(F32)


def sample_wrap(img: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Bilinear periodic sampling of img at fractional coordinates (u, v in image units 0..1)."""
    h, w = img.shape[:2]
    x = (u % 1.0) * w - 0.5
    y = (v % 1.0) * h - 0.5
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0).astype(F32)
    fy = (y - y0).astype(F32)
    x0 %= w
    y0 %= h
    x1 = (x0 + 1) % w
    y1 = (y0 + 1) % h
    if img.ndim == 3:
        fx = fx[..., None]
        fy = fy[..., None]
    a = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    b = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    return (a * (1 - fy) + b * fy).astype(F32)


def warp(img: np.ndarray, seed: int, amount: float = 0.02, lo: float = 2.0, beta: float = 2.4) -> np.ndarray:
    """Domain-warp an image with periodic noise (amount in UV units)."""
    size = img.shape[0]
    u, v = grid(size)
    wx = (fbm(size, seed, beta, lo) - 0.5) * 2.0 * amount
    wy = (fbm(size, seed + 1, beta, lo) - 0.5) * 2.0 * amount
    return sample_wrap(img, u + wx, v + wy)


# ---------------------------------------------------------------------------
# Periodic Voronoi / Worley
# ---------------------------------------------------------------------------

def voronoi(size: int, seed: int, count: int, jitter_pts: np.ndarray | None = None,
            aspect: tuple[float, float] = (1.0, 1.0)):
    """Periodic Voronoi. Returns (F1, F2, cell_id) with distances in UV units.

    aspect scales the metric (e.g. (1, 2) makes cells twice as tall).
    """
    r = rng(seed)
    pts = jitter_pts if jitter_pts is not None else r.random((count, 2)).astype(F32)
    u, v = grid(size)
    f1 = np.full((size, size), 9.0, dtype=F32)
    f2 = np.full((size, size), 9.0, dtype=F32)
    cid = np.zeros((size, size), dtype=np.int32)
    ax, ay = aspect
    for i, (px, py) in enumerate(pts):
        dx = u - px
        dy = v - py
        dx -= np.round(dx)
        dy -= np.round(dy)
        d = np.sqrt((dx / ax) ** 2 + (dy / ay) ** 2)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, i, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid


def relaxed_points(seed: int, count: int, iterations: int = 2, size: int = 128) -> np.ndarray:
    """Lloyd-relaxed periodic point set for evenly sized, natural-looking cells."""
    r = rng(seed)
    pts = r.random((count, 2)).astype(F32)
    u, v = grid(size)
    for _ in range(iterations):
        _, _, cid = voronoi(size, seed, count, pts)
        new = pts.copy()
        for i in range(count):
            m = cid == i
            if not m.any():
                continue
            # circular mean for periodic centroid
            ang_u = u[m] * 2 * np.pi
            ang_v = v[m] * 2 * np.pi
            cu = (np.arctan2(np.sin(ang_u).mean(), np.cos(ang_u).mean()) / (2 * np.pi)) % 1.0
            cv = (np.arctan2(np.sin(ang_v).mean(), np.cos(ang_v).mean()) / (2 * np.pi)) % 1.0
            new[i] = (cu, cv)
        pts = new
    return pts


def cell_values(cid: np.ndarray, seed: int, n: int) -> np.ndarray:
    """Random per-cell scalar in [0,1] broadcast to the cell-id image."""
    vals = rng(seed).random(n).astype(F32)
    return vals[cid]


# ---------------------------------------------------------------------------
# Layout generators
# ---------------------------------------------------------------------------

def ashlar_layout(size: int, seed: int, rows: int = 5, min_w: float = 0.18, max_w: float = 0.42,
                  row_jitter: float = 0.35):
    """Irregular running-bond ashlar masonry.

    Returns dict with: edge (distance to stone edge in px-normalised UV), sid (stone id),
    lu/lv (local coords 0..1 inside stone), sw/sh (stone size in UV).
    """
    r = rng(seed)
    heights = r.uniform(1.0 - row_jitter, 1.0 + row_jitter, rows)
    heights = heights / heights.sum()
    row_edges = np.concatenate([[0.0], np.cumsum(heights)])
    u, v = grid(size)
    row = np.clip(np.searchsorted(row_edges, v, side="right") - 1, 0, rows - 1)
    edge = np.zeros((size, size), dtype=F32)
    sid = np.zeros((size, size), dtype=np.int32)
    lu = np.zeros((size, size), dtype=F32)
    lv = np.zeros((size, size), dtype=F32)
    sw_img = np.zeros((size, size), dtype=F32)
    sh_img = np.zeros((size, size), dtype=F32)
    next_id = 0
    for ri in range(rows):
        widths = []
        total = 0.0
        while total < 1.0:
            w = float(r.uniform(min_w, max_w))
            widths.append(w)
            total += w
        widths = np.array(widths) / total
        offs = float(r.random())
        col_edges = np.concatenate([[0.0], np.cumsum(widths)])
        m = row == ri
        vv = v[m]
        uu = (u[m] - offs) % 1.0
        ci = np.clip(np.searchsorted(col_edges, uu, side="right") - 1, 0, len(widths) - 1)
        x0 = col_edges[ci]
        x1 = col_edges[ci + 1]
        y0 = row_edges[ri]
        y1 = row_edges[ri + 1]
        dx = np.minimum(uu - x0, x1 - uu)
        dy = np.minimum(vv - y0, y1 - vv)
        edge[m] = np.minimum(dx, dy)
        sid[m] = next_id + ci
        lu[m] = (uu - x0) / (x1 - x0)
        lv[m] = (vv - y0) / (y1 - y0)
        sw_img[m] = x1 - x0
        sh_img[m] = y1 - y0
        next_id += len(widths)
    return {"edge": edge, "sid": sid, "lu": lu, "lv": lv, "sw": sw_img, "sh": sh_img, "count": next_id}


def plank_layout(size: int, seed: int, planks: int = 5, min_len: float = 0.35, max_len: float = 1.0):
    """Wood planks running along u. Returns plank id map, local coords, edge distances."""
    r = rng(seed)
    u, v = grid(size)
    pw = 1.0 / planks
    row = np.minimum((v / pw).astype(np.int32), planks - 1)
    edge_v = np.minimum(v - row * pw, (row + 1) * pw - v)
    pid = np.zeros((size, size), dtype=np.int32)
    edge_u = np.full((size, size), 1.0, dtype=F32)
    lu = np.zeros((size, size), dtype=F32)
    next_id = 0
    for ri in range(planks):
        lens = []
        total = 0.0
        while total < 1.0:
            l = float(r.uniform(min_len, max_len))
            lens.append(l)
            total += l
        lens = np.array(lens) / total
        offs = float(r.random())
        edges = np.concatenate([[0.0], np.cumsum(lens)])
        m = row == ri
        uu = (u[m] - offs) % 1.0
        ci = np.clip(np.searchsorted(edges, uu, side="right") - 1, 0, len(lens) - 1)
        x0 = edges[ci]
        x1 = edges[ci + 1]
        edge_u[m] = np.minimum(uu - x0, x1 - uu)
        lu[m] = (uu - x0) / (x1 - x0)
        pid[m] = next_id + ci
        next_id += len(lens)
    lv = ((v - row * pw) / pw).astype(F32)
    return {"pid": pid, "edge_u": edge_u, "edge_v": edge_v.astype(F32), "lu": lu, "lv": lv, "count": next_id}


# ---------------------------------------------------------------------------
# Derived maps
# ---------------------------------------------------------------------------

def height_to_normal(height: np.ndarray, strength: float) -> np.ndarray:
    """Periodic central-difference normal map (OpenGL / Y+). strength ~ height units per texel."""
    s = height.shape[0]
    k = strength * s / 1024.0
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * k * 64.0
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * k * 64.0
    # image rows grow downward; OpenGL normal maps want +Y pointing up the texture
    nx = -dx
    ny = dy
    nz = np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    return (n * 0.5 + 0.5).astype(F32)


def cavity_ao(height: np.ndarray, radius_px: float = 6.0, strength: float = 2.2) -> np.ndarray:
    """Cheap ambient-occlusion approximation: how far below its blurred neighbourhood a texel sits."""
    b1 = blur(height, radius_px)
    b2 = blur(height, radius_px * 3.0)
    occ = (b1 - height) * 0.6 + (b2 - height) * 0.4
    ao = 1.0 - np.clip(occ * strength, 0.0, 1.0)
    return np.clip(ao, 0.0, 1.0).astype(F32)


def curvature(height: np.ndarray, radius_px: float = 2.0) -> np.ndarray:
    """Positive on ridges/edges (useful for edge wear), negative in crevices."""
    return (height - blur(height, radius_px)).astype(F32)


def to_u8(img: np.ndarray) -> np.ndarray:
    return (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055).astype(F32)
