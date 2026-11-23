#!/usr/bin/env python3
"""Build the running frames from Dionysius's drawing.

reference/walking-hamster-source.png is the body. The white paper and the
little motion marks come off. The four legs are removed and drawn again,
in his flat outlined style, for one walk cycle. The head and fur pixels
stay his.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "reference" / "walking-hamster-source.png"
FRAME_COUNT = 8

OUTLINE = (72, 64, 62, 255)
LEG = (186, 158, 136, 255)
PAW = (236, 190, 182, 255)
PAD = (214, 150, 146, 255)


def _foreground(rgb: np.ndarray) -> np.ndarray:
    """Paper becomes transparent. The cream belly is inside the outline, so it stays."""
    h, w, _ = rgb.shape
    paper = np.all(rgb >= 246, axis=2)
    seen = np.zeros((h, w), dtype=bool)
    stack = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
    seen[0, 0] = seen[0, w - 1] = seen[h - 1, 0] = seen[h - 1, w - 1] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ny, nx = y + dy, x + dx
            if ny < 0 or nx < 0 or ny >= h or nx >= w or seen[ny, nx]:
                continue
            if paper[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    alpha = np.where(seen, 0, 255).astype(np.uint8)
    # Soften the fringe of paper still clinging to the outline.
    fringe = (~seen) & np.all(rgb >= 238, axis=2)
    # Only the fringe that actually touches the paper.
    touch = np.zeros_like(seen)
    touch[1:] |= seen[:-1]
    touch[:-1] |= seen[1:]
    touch[:, 1:] |= seen[:, :-1]
    touch[:, :-1] |= seen[:, 1:]
    alpha[fringe & touch] = 0
    out = np.dstack([rgb, alpha])
    return out


def _drop_specks(image: np.ndarray) -> np.ndarray:
    """The motion dashes are tiny marks that are not connected to the hamster."""
    alpha = image[..., 3] > 0
    h, w = alpha.shape
    seen = np.zeros_like(alpha)
    keep = np.zeros_like(alpha)
    best = []
    for y in range(h):
        row = alpha[y]
        for x in range(w):
            if not row[x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            pts = []
            while stack:
                cy, cx = stack.pop()
                pts.append((cy, cx))
                for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(pts) > len(best):
                best = pts
    for y, x in best:
        keep[y, x] = True
    image = image.copy()
    image[~keep, 3] = 0
    return image


def _leg_mask(alpha: np.ndarray) -> np.ndarray:
    """The four legs and paws. The belly above them is not part of the mask."""
    fg = alpha > 0
    h, w = fg.shape
    mask = np.zeros_like(fg)
    for x in range(w):
        ys = np.where(fg[:, x])[0]
        if len(ys) == 0:
            continue
        splits = np.where(np.diff(ys) > 2)[0]
        start = 0
        segments = []
        for cut in list(splits) + [len(ys) - 1]:
            seg = ys[start:cut + 1]
            start = cut + 1
            if len(seg):
                segments.append(seg)
        for seg in segments:
            top, bot = int(seg[0]), int(seg[-1])
            # A separate lower piece is a paw or a motion speck.
            if top >= 243 and bot - top < 36:
                mask[top:bot + 1, x] = True
        # The rear leg is one piece with the rump on the far left.
        if x <= 112 and ys.min() >= 215:
            lower = ys[ys >= 220]
            if len(lower):
                mask[int(lower[0]):int(lower[-1]) + 1, x] = True
        # Pink hind foot that stays connected to the white belly.
        if 136 <= x <= 184:
            lower = ys[ys >= 250]
            if len(lower):
                mask[int(lower[0]):int(lower[-1]) + 1, x] = True
        # Front paw that stays connected under the chest.
        if 246 <= x <= 278:
            lower = ys[ys >= 244]
            if len(lower):
                mask[int(lower[0]):int(lower[-1]) + 1, x] = True
    # Include the dark outline pixel just outside the fur.
    grown = mask.copy()
    grown[1:] |= mask[:-1]
    grown[:-1] |= mask[1:]
    grown[:, 1:] |= mask[:, :-1]
    grown[:, :-1] |= mask[:, 1:]
    return grown & fg


def _fill_sockets(image: np.ndarray, body: np.ndarray, legs: np.ndarray) -> np.ndarray:
    """Close the belly where a leg used to meet it, using the fur just above the cut."""
    out = image.copy()
    out[legs, 3] = 0
    h, w = body.shape
    outline = np.array(OUTLINE[:3], dtype=np.uint8)
    for x in range(w):
        if not legs[:, x].any() or not body[:, x].any():
            continue
        bottom = int(np.where(body[:, x])[0].max())
        color = out[bottom, x, :3].copy()
        for step in range(1, 5):
            y = bottom + step
            if y >= h or body[y, x]:
                break
            if not legs[y, x] and step > 2:
                break
            out[y, x, :3] = color
            out[y, x, 3] = 255
        y = bottom + 5
        if y < h and legs[min(h - 1, bottom + 1), x]:
            out[y, x, :3] = outline
            out[y, x, 3] = 255
    return out


def prepare_body() -> tuple[Image.Image, dict]:
    rgb = np.asarray(Image.open(SOURCE).convert("RGB"))
    image = _drop_specks(_foreground(rgb))
    fg = image[..., 3] > 0
    legs = _leg_mask(image[..., 3])
    body = fg & ~legs
    filled = _fill_sockets(image, body, legs)
    kept = filled[..., 3] > 0
    ys, xs = np.where(kept)
    pad_bottom = 46
    pad = 8
    box = (
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(filled.shape[1], int(xs.max()) + pad + 1),
        min(filled.shape[0], int(ys.max()) + pad_bottom + 1),
    )
    crop = filled[box[1]:box[3], box[0]:box[2]]
    # Hips in the cropped picture. Measured from the original drawing.
    hips = {
        "rear": (100 - box[0], 230 - box[1]),
        "hind": (158 - box[0], 240 - box[1]),
        "front": (262 - box[0], 238 - box[1]),
        "fore": (292 - box[0], 230 - box[1]),
    }
    return Image.fromarray(crop, mode="RGBA"), hips


def _foot(phase: float, hip, stride: float, lift: float, ground: float):
    p = phase % 1.0
    hx, hy = hip
    if p < 0.55:
        u = p / 0.55
        return hx + stride * (1.0 - 2.0 * u), ground
    u = (p - 0.55) / 0.45
    return hx - stride + stride * 2.0 * u, ground - math.sin(u * math.pi) * lift


def _draw_leg(draw: ImageDraw.ImageDraw, hip, foot, far: bool):
    width = 7 if far else 9
    inner = 4 if far else 6
    color = (160, 136, 118, 255) if far else LEG
    draw.line([hip, foot], fill=OUTLINE, width=width + 4)
    draw.line([hip, foot], fill=color, width=inner + 3)
    x, y = foot
    rw, rh = (8, 5) if far else (11, 6)
    draw.ellipse([x - rw - 2, y - rh - 2, x + rw + 3, y + rh + 2], fill=OUTLINE)
    draw.ellipse([x - rw, y - rh, x + rw + 1, y + rh], fill=PAW)
    draw.ellipse([x - rw + 3, y - 1, x + rw - 2, y + rh - 1], fill=PAD)


def render_frames() -> list[Image.Image]:
    body, hips = prepare_body()
    w, h = body.size
    ground = max(hips["hind"][1], hips["front"][1]) + 22
    frames = []
    for index in range(FRAME_COUNT):
        t = index / FRAME_COUNT
        bob = int(round(math.sin(t * math.tau * 2.0) * 2.5))
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # Far legs sit behind the body.
        far = ImageDraw.Draw(canvas)
        moves = {
            "rear": _foot(t + 0.5, hips["rear"], 16, 9, ground),
            "fore": _foot(t, hips["fore"], 12, 7, ground - 2),
        }
        for name in ("rear", "fore"):
            hip = (hips[name][0], hips[name][1] + bob)
            foot = (moves[name][0], moves[name][1] + bob)
            _draw_leg(far, hip, foot, far=True)
        canvas.paste(body, (0, bob), body)
        near = ImageDraw.Draw(canvas)
        moves = {
            "hind": _foot(t, hips["hind"], 18, 10, ground),
            "front": _foot(t + 0.5, hips["front"], 14, 8, ground - 1),
        }
        for name in ("hind", "front"):
            hip = (hips[name][0], hips[name][1] + bob)
            foot = (moves[name][0], moves[name][1] + bob)
            _draw_leg(near, hip, foot, far=False)
        frames.append(canvas)
    return frames


def main():
    frames = render_frames()
    out = ROOT / "Sources" / "HamsterInfestation" / "Resources"
    out.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(out / f"ui-run-{index}.png")
    print(f"wrote {len(frames)} frames at {frames[0].size}")


if __name__ == "__main__":
    main()
