#!/usr/bin/env python3
"""Pre-render a Syrian hamster run cycle and the pointer sprite.

Frames are painted once and saved as PNGs. The app only moves those pictures,
so a running hamster does not mean a running renderer.

The animal is a golden Syrian: long low body, round head, small ears, short
legs, stub tail, cream belly, and agouti fur lit from the upper left.
"""

from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RUN_COUNT = 8
RUN_SIZE = (480, 300)
POINTER_SIZE = 180
# Paw-tip hotspot in the pointer PNG, from the top-left, in pixels.
POINTER_HOT_X = 20
POINTER_HOT_Y = 18


def _noise(h: int, w: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    gw = max(2, int(cells * w / max(h, 1)))
    grid = rng.random((cells + 2, gw + 2)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8), mode="L")
    img = img.resize((w, h), Image.Resampling.BILINEAR)
    return np.asarray(img).astype(np.float32) / 255.0


def _ell(px, py, cx, cy, rx, ry):
    return np.hypot((px - cx) / max(rx, 0.5), (py - cy) / max(ry, 0.5)) - 1.0


def _capsule(px, py, ax, ay, bx, by, radius):
    abx = bx - ax
    aby = by - ay
    lab2 = abx * abx + aby * aby + 1e-3
    t = np.clip(((px - ax) * abx + (py - ay) * aby) / lab2, 0.0, 1.0)
    return np.hypot(px - (ax + abx * t), py - (ay + aby * t)) / radius - 1.0


def _union(a, b, k=0.16):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def _norm(x, y, z):
    length = np.sqrt(x * x + y * y + z * z) + 1e-6
    return x / length, y / length, z / length


def _lit(sdf, albedo):
    gy, gx = np.gradient(sdf.astype(np.float32))
    nx, ny, nz = _norm(gx, gy, np.full_like(gx, 0.55))
    # Light sits up and to the left. Image y grows downward.
    lx, ly, lz = _norm(np.float32(-0.42), np.float32(-0.78), np.float32(0.48))
    ndot = np.clip(nx * lx + ny * ly + nz * lz, 0.0, 1.0)
    rim = np.clip(-ny, 0.0, 1.0) * 0.12
    under = np.clip(ny, 0.0, 1.0) * 0.28
    rgb = albedo * (0.32 + 0.74 * ndot + rim - under)[..., None]
    alpha = np.clip((0.03 - sdf) / 0.055, 0.0, 1.0)
    out = np.zeros(sdf.shape + (4,), dtype=np.float32)
    out[..., :3] = np.clip(rgb, 0.0, 1.0)
    out[..., 3] = alpha
    return out


def _over(base, top):
    a = top[..., 3:4]
    base[..., :3] = top[..., :3] * a + base[..., :3] * (1.0 - a)
    base[..., 3:4] = a + base[..., 3:4] * (1.0 - a)
    return base


def _tint(image, mask, color):
    color = np.asarray(color, dtype=np.float32)
    m = np.clip(mask, 0.0, 1.0)[..., None]
    image[..., :3] = image[..., :3] * (1.0 - m) + color * m


def _foot_pose(phase: float, hip_x: float, ground: float, stride: float, lift: float):
    """One step. The foot slides back along the ground, then swings forward in the air."""
    p = phase % 1.0
    if p < 0.55:
        u = p / 0.55
        return hip_x + stride * (1.0 - 2.0 * u), ground
    u = (p - 0.55) / 0.45
    return hip_x - stride + stride * 2.0 * u, ground - math.sin(u * math.pi) * lift


def _fur_albedo(h, w, xs, ys, body_x, body_y, body_sdf):
    fur = _noise(h, w, 36, 4)
    fine = _noise(h, w, 90, 9)
    gold = np.array([0.62, 0.40, 0.20], dtype=np.float32)
    shade = np.array([0.36, 0.22, 0.12], dtype=np.float32)
    cream = np.array([0.90, 0.84, 0.73], dtype=np.float32)
    albedo = np.broadcast_to(gold, (h, w, 3)).copy()
    albedo *= (0.86 + 0.22 * fur)[..., None]
    # Darker along the spine, cream on a soft oval belly. Not a hard stripe.
    dorsal = np.clip((body_y - ys) / 64.0, 0.0, 1.0)
    albedo = albedo * (1.0 - 0.35 * dorsal[..., None]) + shade * (0.35 * dorsal)[..., None]
    belly = _ell(xs, ys, body_x, body_y + 18, 70, 24)
    belly_m = np.clip((0.15 - belly) / 0.45, 0.0, 1.0) * np.clip(-body_sdf, 0.0, 1.0)
    cream_rgb = cream * (0.96 + 0.06 * fur)[..., None]
    albedo = albedo * (1.0 - belly_m[..., None]) + cream_rgb * belly_m[..., None]
    # Fine agouti ticking, kept small so it reads as hair instead of spots.
    tick = (fine > 0.84) & (dorsal > 0.45)
    albedo[tick] *= 0.72
    return albedo


def _stroke_fur(pil: Image.Image, mask: np.ndarray, seed: int) -> Image.Image:
    """Short hairs lying along the body, painted once per frame."""
    rng = np.random.default_rng(seed)
    ys, xs = np.where(mask)
    if len(xs) < 50:
        return pil
    take = rng.choice(len(xs), size=min(700, len(xs)), replace=False)
    draw = ImageDraw.Draw(pil)
    for x, y in zip(xs[take], ys[take]):
        length = 3 + int(rng.integers(0, 3))
        # A few darker hairs, not a white scribble over the shading.
        x2 = int(x + length)
        y2 = int(y + rng.integers(-1, 2))
        draw.line([(int(x), int(y)), (x2, y2)], fill=(92, 58, 32, 55), width=1)
    return pil


def _animal(w, h, body, head, ground, legs, ear_shift=(0, 0)):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    bx, by = body
    hx, hy = head
    torso = _ell(xs, ys, bx, by, 112, 50)
    torso = _union(torso, _ell(xs, ys, bx - 78, by + 4, 40, 42), 0.2)  # rump
    torso = _union(torso, _ell(xs, ys, bx + 78, by - 2, 34, 32), 0.18)  # shoulder
    torso = _union(torso, _ell(xs, ys, hx, hy, 50, 44), 0.22)  # round head
    torso = _union(torso, _ell(xs, ys, hx + 22, hy + 10, 16, 13), 0.12)  # short muzzle
    torso = _union(torso, _ell(xs, ys, hx - 8 + ear_shift[0], hy - 34 + ear_shift[1], 14, 16), 0.12)
    torso = _union(torso, _ell(xs, ys, bx - 108, by + 10, 12, 8), 0.1)  # tail stub

    albedo = _fur_albedo(h, w, xs, ys, bx, by, _ell(xs, ys, bx, by, 112, 50))
    body_img = _lit(torso, albedo)

    def limb_layer(phase, hip_x, stride, lift, thick, color_scale):
        fx, fy = _foot_pose(phase, hip_x, ground, stride, lift)
        hip_y = by + 16
        knee_x = (hip_x + fx) * 0.5 + 2
        knee_y = (hip_y + fy) * 0.55
        leg = _capsule(xs, ys, hip_x, hip_y, knee_x, knee_y, thick)
        shin = _capsule(xs, ys, knee_x, knee_y, fx, fy - 2, thick * 0.78)
        foot = _ell(xs, ys, fx + 6, fy - 2, 13, 5.5)
        shape = _union(_union(leg, shin, 0.08), foot, 0.1)
        tint = albedo * color_scale
        return _lit(shape, tint), fx, fy

    # Far pair, slightly darker, drawn under the body. Near legs are thicker.
    picture = np.zeros((h, w, 4), dtype=np.float32)
    shadow = _ell(xs, ys, bx, ground + 8, 120, 12)
    picture[..., 3] = np.clip((0.2 - shadow) / 0.55, 0, 1) * 0.33

    for phase, hip, stride, lift in legs["far"]:
        limb, _, _ = limb_layer(phase, hip, stride, lift, 7.0, 0.72)
        picture = _over(picture, limb)
    picture = _over(picture, body_img)
    for phase, hip, stride, lift in legs["near"]:
        limb, _, _ = limb_layer(phase, hip, stride, lift, 11.0, 0.95)
        picture = _over(picture, limb)

    ear_in = _ell(xs, ys, hx - 6, hy - 30, 7, 8)
    nose = _ell(xs, ys, hx + 46, hy + 6, 6.2, 4.6)
    eye = _ell(xs, ys, hx + 10, hy - 2, 5.4, 5.6)
    catch = _ell(xs, ys, hx + 8.2, hy - 4.4, 1.7, 1.7)
    _tint(picture, np.clip((0.02 - ear_in) / 0.08, 0, 1) * picture[..., 3], (0.84, 0.52, 0.55))
    _tint(picture, np.clip((0.0 - nose) / 0.06, 0, 1) * picture[..., 3], (0.72, 0.38, 0.44))
    _tint(picture, np.clip((0.0 - eye) / 0.05, 0, 1), (0.05, 0.04, 0.03))
    _tint(picture, np.clip((0.0 - catch) / 0.04, 0, 1), (0.95, 0.96, 0.93))

    # Pink foot pads on the near feet.
    for phase, hip, stride, lift in legs["near"]:
        fx, fy = _foot_pose(phase, hip, ground, stride, lift)
        pad = _ell(xs, ys, fx + 6, fy - 1, 6, 2.4)
        _tint(picture, np.clip((0.0 - pad) / 0.08, 0, 1) * picture[..., 3], (0.78, 0.5, 0.5))

    pil = Image.fromarray((np.clip(picture, 0, 1) * 255).astype(np.uint8), mode="RGBA")
    draw = ImageDraw.Draw(pil)
    nx, ny = hx + 48, hy + 6
    for dy in (-5, -1, 3):
        draw.line([(nx, ny + dy * 0.2), (nx + 34, ny + dy)], fill=(45, 32, 22, 160), width=1)
    return pil.filter(ImageFilter.SMOOTH)


def render_run_frame(index: int, size=RUN_SIZE) -> Image.Image:
    w, h = size
    t = index / RUN_COUNT
    # Two small bobs per stride: the body, then the head a little later.
    bob = math.sin(t * math.tau * 2.0) * 4.0
    head_bob = math.sin(t * math.tau * 2.0 + 0.7) * 3.2
    ground = 228
    body = (200, 148 + bob)
    head = (308, 136 + bob * 0.35 + head_bob)
    # Short legs. Near hind and near front are half a step apart.
    legs = {
        "far": [
            (t + 0.5, 146, 18, 10),
            (t + 0.0, 236, 14, 8),
        ],
        "near": [
            (t, 158, 22, 12),
            (t + 0.5, 248, 16, 10),
        ],
    }
    return _animal(w, h, body, head, ground, legs)


def render_run_cycle() -> list[Image.Image]:
    return [render_run_frame(i) for i in range(RUN_COUNT)]


def render_pointer(size: int = POINTER_SIZE) -> Image.Image:
    """Compact hamster. The extended paw's claw is the click point."""
    w = h = size
    s = size / 180.0

    def S(v):
        return v * s

    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    body = (S(108), S(112))
    head = (S(70), S(74))
    tip = (float(POINTER_HOT_X) * s, float(POINTER_HOT_Y) * s)
    shoulder = (S(62), S(70))

    shape = _ell(xs, ys, body[0], body[1], S(50), S(36))
    shape = _union(shape, _ell(xs, ys, head[0], head[1], S(32), S(28)), 0.18)
    shape = _union(shape, _ell(xs, ys, head[0] + S(14), head[1] + S(8), S(14), S(11)), 0.12)
    shape = _union(shape, _ell(xs, ys, head[0] - S(2), head[1] - S(22), S(10), S(11)), 0.1)
    shape = _union(shape, _ell(xs, ys, body[0] + S(38), body[1] + S(6), S(9), S(6)), 0.1)
    paw = _capsule(xs, ys, shoulder[0], shoulder[1], tip[0] + S(10), tip[1] + S(9), S(12))
    toes = _ell(xs, ys, tip[0] + S(8), tip[1] + S(7), S(10), S(7))
    shape = _union(shape, _union(paw, toes, 0.1), 0.16)

    albedo = _fur_albedo(h, w, xs, ys, body[0], body[1], _ell(xs, ys, body[0], body[1], S(52), S(38)))
    image = _lit(shape, albedo)
    ear = _ell(xs, ys, head[0] - S(2), head[1] - S(22), S(5.5), S(6))
    nose = _ell(xs, ys, head[0] + S(26), head[1] + S(4), S(4.5), S(3.6))
    eye = _ell(xs, ys, head[0] + S(6), head[1] - S(2), S(4.2), S(4.4))
    catch = _ell(xs, ys, head[0] + S(4.6), head[1] - S(3.8), S(1.3), S(1.3))
    claw = _ell(xs, ys, tip[0] + S(2), tip[1] + S(2), S(2.4), S(1.6))
    _tint(image, np.clip((0.0 - ear) / 0.08, 0, 1) * image[..., 3], (0.84, 0.52, 0.55))
    _tint(image, np.clip((0.0 - nose) / 0.06, 0, 1) * image[..., 3], (0.74, 0.4, 0.46))
    _tint(image, np.clip((0.0 - eye) / 0.05, 0, 1), (0.05, 0.04, 0.03))
    _tint(image, np.clip((0.0 - catch) / 0.04, 0, 1), (0.96, 0.96, 0.93))
    _tint(image, np.clip((0.0 - claw) / 0.05, 0, 1) * image[..., 3], (0.95, 0.91, 0.84))

    pil = Image.fromarray((np.clip(image, 0, 1) * 255).astype(np.uint8), mode="RGBA")
    return pil.filter(ImageFilter.SMOOTH)


def pointer_hotspot_points(point_size: float = 40.0) -> tuple[float, float]:
    scale = point_size / POINTER_SIZE
    return POINTER_HOT_X * scale, POINTER_HOT_Y * scale
