#!/usr/bin/env python3
"""Cut out Dionysius's painted hamsters and build the peek and the walk.

The corner picture is on white paper. The walker has a fake checkerboard
baked into the RGB file. Both are separated by a flood fill from the edges,
stopped by the dark outline, so the cream belly is not keyed out.

The walk reuses the painted legs, swung around the hips. The stored frames
face right. The app already mirrors them for the other direction.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "reference"
RES = ROOT / "Sources" / "HamsterInfestation" / "Resources"
FRAMES = 8


def _neighbors(y, x, h, w):
    if y > 0:
        yield y - 1, x
    if y + 1 < h:
        yield y + 1, x
    if x > 0:
        yield y, x - 1
    if x + 1 < w:
        yield y, x + 1


def flood_background(rgb: np.ndarray, is_background) -> np.ndarray:
    """Return an alpha mask: 0 on paper reached from the edges, 255 elsewhere."""
    h, w, _ = rgb.shape
    paper = np.zeros((h, w), dtype=bool)
    stack = []
    for x in range(w):
        stack.append((0, x))
        stack.append((h - 1, x))
    for y in range(h):
        stack.append((y, 0))
        stack.append((y, w - 1))
    seen = np.zeros((h, w), dtype=bool)
    while stack:
        y, x = stack.pop()
        if seen[y, x]:
            continue
        seen[y, x] = True
        if not is_background(rgb[y, x]):
            continue
        paper[y, x] = True
        stack.extend(_neighbors(y, x, h, w))
    alpha = np.where(paper, 0, 255).astype(np.uint8)
    # Soften only the fringe that touches the paper, so whiskers stay solid.
    touch = np.zeros_like(paper)
    touch[1:] |= paper[:-1]
    touch[:-1] |= paper[1:]
    touch[:, 1:] |= paper[:, :-1]
    touch[:, :-1] |= paper[:, 1:]
    fringe = (~paper) & touch
    ys, xs = np.where(fringe)
    for y, x in zip(ys, xs):
        pix = rgb[y, x].astype(np.int16)
        # How much white/gray is mixed into this edge pixel.
        sat = int(pix.max() - pix.min())
        if sat > 40:
            continue
        darkness = 255 - int(pix.min())
        alpha[y, x] = np.uint8(np.clip(darkness * 3, 0, 255))
    return alpha


def is_white_paper(pixel) -> bool:
    # Pure paper and the pale halo. Cream fur fails this because one channel is lower.
    return int(pixel.min()) >= 248 and int(pixel.max() - pixel.min()) <= 10


def is_checker(pixel) -> bool:
    # Use a wider integer type. uint8 subtraction wraps and would look saturated.
    sample = pixel.astype(np.int16)
    sat = int(sample.max() - sample.min())
    if sat > 18:
        return False
    lum = int(sample.mean())
    if lum >= 246:
        return True
    # The two checker grays, and the blends between them.
    # Ink and whiskers are darker than this, so the flood stops on the outline.
    if 96 <= lum <= 214:
        return True
    return False


def cutout(path: Path, paper) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB"))
    alpha = flood_background(rgb, paper)
    image = np.dstack([rgb, alpha])
    kept = alpha > 20
    ys, xs = np.where(kept)
    pad = 8
    box = (
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(rgb.shape[1], int(xs.max()) + pad + 1),
        min(rgb.shape[0], int(ys.max()) + pad + 1),
    )
    return Image.fromarray(image[box[1]:box[3], box[0]:box[2]], mode="RGBA")


def _eye_box(image: Image.Image):
    a = np.asarray(image)
    rgb = a[..., :3]
    alpha = a[..., 3] > 40
    dark = alpha & (rgb.mean(2) < 45)
    # Knock out the thin outline so the eye blob remains.
    core = dark.copy()
    for _ in range(3):
        nxt = core.copy()
        nxt[1:] &= core[:-1]
        nxt[:-1] &= core[1:]
        nxt[:, 1:] &= core[:, :-1]
        nxt[:, :-1] &= core[:, 1:]
        core = nxt
    h, w = core.shape
    seen = np.zeros_like(core)
    best = None
    for y in range(h):
        for x in range(w):
            if not core[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            pts = []
            while stack:
                cy, cx = stack.pop()
                pts.append((cx, cy))
                for ny, nx in _neighbors(cy, cx, h, w):
                    if core[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if best is None or len(pts) > len(best):
                best = pts
    arr = np.array(best)
    return int(arr[:, 0].min()), int(arr[:, 1].min()), int(arr[:, 0].max()), int(arr[:, 1].max())


def _paint_closed_eye(image: Image.Image, box, nap: bool) -> Image.Image:
    out = image.copy()
    draw = ImageDraw.Draw(out)
    x0, y0, x1, y1 = box
    # Cover the open eye with the gold fur just above it.
    sample = np.asarray(image)
    fur = sample[max(0, y0 - 18):y0, x0:x1, :3]
    fur = fur[fur.mean(2) > 80]
    if len(fur) == 0:
        color = (232, 176, 96, 255)
    else:
        mean = fur.mean(0).astype(int)
        color = (int(mean[0]), int(mean[1]), int(mean[2]), 255)
    pad = 4
    draw.ellipse([x0 - pad, y0 - pad, x1 + pad, y1 + pad], fill=color)
    # A lid in the same dark ink as the drawing.
    mid_y = (y0 + y1) // 2 + 2
    draw.arc([x0 - 2, mid_y - 10, x1 + 2, mid_y + 14], start=200, end=340, fill=(40, 28, 22, 255), width=4)
    if nap:
        zx = max(6, x0 - 6)
        zy = max(6, y0 - 28)
        ink = (48, 34, 28, 255)
        draw.line([(zx, zy), (zx + 22, zy)], fill=ink, width=4)
        draw.line([(zx + 22, zy), (zx + 2, zy + 16)], fill=ink, width=4)
        draw.line([(zx + 2, zy + 16), (zx + 24, zy + 16)], fill=ink, width=4)
    return out


def save_scaled(image: Image.Image, stem: str):
    """Write a 1x file and a 2x file. 1x is half the painted pixels."""
    twox = image
    onex = image.resize((max(1, image.width // 2), max(1, image.height // 2)), Image.Resampling.LANCZOS)
    onex.save(RES / f"{stem}.png")
    twox.save(RES / f"{stem}@2x.png")


def make_peek():
    cut = cutout(REF / "corner-hamster-white-bg.png", is_white_paper)
    # Head and chest are on the left. The rump stays behind the hole.
    w, h = cut.size
    crop = cut.crop((0, 0, int(w * 0.62), h))
    # Trim again.
    alpha = np.asarray(crop)[..., 3]
    ys, xs = np.where(alpha > 20)
    crop = crop.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    # A display size that fits the hole without squashing him. 2x pixels.
    point_w, point_h = 168, int(round(168 * crop.height / crop.width))
    sharp = crop.resize((point_w * 2, point_h * 2), Image.Resampling.LANCZOS)
    eye = _eye_box(sharp)
    save_scaled(sharp, "ui-peek")
    save_scaled(_paint_closed_eye(sharp, eye, nap=False), "ui-peek-blink")
    save_scaled(_paint_closed_eye(sharp, eye, nap=True), "ui-peek-sleep")
    return point_w, point_h


def _components(mask: np.ndarray, min_size: int):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    found = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            pts = []
            while stack:
                cy, cx = stack.pop()
                pts.append((cx, cy))
                for ny, nx in _neighbors(cy, cx, h, w):
                    if mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(pts) >= min_size:
                found.append(pts)
    return found


def _leg_sprite(image: np.ndarray, pts):
    arr = np.array(pts)
    x0, y0, x1, y1 = arr[:, 0].min(), arr[:, 1].min(), arr[:, 0].max(), arr[:, 1].max()
    pad = 2
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(image.shape[1] - 1, x1 + pad)
    y1 = min(image.shape[0] - 1, y1 + pad)
    chip = image[y0:y1 + 1, x0:x1 + 1].copy()
    keep = np.zeros(chip.shape[:2], dtype=bool)
    for x, y in pts:
        keep[y - y0, x - x0] = True
    # Include the outline pixel around the fur.
    grown = keep.copy()
    grown[1:] |= keep[:-1]
    grown[:-1] |= keep[1:]
    grown[:, 1:] |= keep[:, :-1]
    grown[:, :-1] |= keep[:, 1:]
    chip[~grown, 3] = 0
    # Hip is the top of the leg.
    top = arr[arr[:, 1] == arr[:, 1].min()]
    hip = (int(top[:, 0].mean()) - x0, int(arr[:, 1].min()) - y0)
    return Image.fromarray(chip, mode="RGBA"), hip, (x0, y0)


def _spin_about(sprite: Image.Image, hip, angle: float):
    """Rotate a leg around its hip. The hip stays at the center of the result."""
    pad = int(math.hypot(sprite.width, sprite.height)) + 8
    big = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    cx, cy = pad, pad
    big.paste(sprite, (cx - hip[0], cy - hip[1]), sprite)
    spun = big.rotate(angle, resample=Image.Resampling.BICUBIC, center=(cx, cy))
    return spun, cx, cy


def _paste_clipped(base: Image.Image, sprite: Image.Image, x: int, y: int):
    if x >= base.width or y >= base.height or x + sprite.width <= 0 or y + sprite.height <= 0:
        return
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    sx1 = min(sprite.width, base.width - x)
    sy1 = min(sprite.height, base.height - y)
    piece = sprite.crop((sx0, sy0, sx1, sy1))
    base.alpha_composite(piece, (dx0, dy0))


def make_walk():
    cut = cutout(REF / "walker-hamster-source.png", is_checker)
    arr = np.asarray(cut)
    alpha = arr[..., 3] > 30
    h, w = alpha.shape
    # Pixels well below the belly, plus the raised front paw.
    low = np.zeros_like(alpha)
    low[600:] = alpha[600:]
    low[540:630, 400:520] |= alpha[540:630, 400:520]
    parts = _components(low, 40)
    # Drop specks. Keep the four biggest hanging pieces.
    parts.sort(key=len, reverse=True)
    parts = parts[:4]
    legs = []
    leg_mask = np.zeros_like(alpha)
    for pts in parts:
        sprite, hip, origin = _leg_sprite(arr, pts)
        legs.append((sprite, hip, origin, pts))
        for x, y in pts:
            leg_mask[y, x] = True
    # Body with the legs lifted out, sockets closed using the pixel just above.
    body = arr.copy()
    body[leg_mask, 3] = 0
    for x in range(w):
        if not leg_mask[:, x].any():
            continue
        above = np.where((~leg_mask[:, x]) & (body[:, x, 3] > 30))[0]
        if len(above) == 0:
            continue
        y_src = int(above.max())
        color = body[y_src, x].copy()
        for y in range(y_src + 1, min(h, y_src + 10)):
            if leg_mask[y, x]:
                body[y, x] = color
                body[y, x, 3] = 255
    body_img = Image.fromarray(body, mode="RGBA")
    # Mirror so the stored frames face right. The app flips them to walk left.
    body_img = body_img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    legs = [
        (
            sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
            (sprite.width - 1 - hip[0], hip[1]),
            (w - (origin[0] + sprite.width), origin[1]),
        )
        for sprite, hip, origin, _pts in legs
    ]
    frames = []
    margin = 80
    for index in range(FRAMES):
        # Half a step in, so the passing pose is not drawn twice.
        t = (index + 0.5) / FRAMES
        bob = int(round(math.sin(t * math.tau * 2.0) * 4))
        canvas = Image.new("RGBA", (w + margin * 2, h + 16 + margin * 2), (0, 0, 0, 0))
        canvas.paste(body_img, (margin, margin + 8 + bob), body_img)
        for n, (sprite, hip, origin) in enumerate(legs):
            # Alternate front and back. Each leg has its own phase.
            phase = t + (0.0 if n % 2 == 0 else 0.5)
            angle = math.sin(phase * math.tau) * 28
            spun, cx, cy = _spin_about(sprite, hip, angle)
            # Keep the hip on the body, tucked in so the cut does not show.
            attach_x = margin + origin[0] + hip[0]
            attach_y = margin + origin[1] + hip[1] + 8 + bob - 12
            _paste_clipped(canvas, spun, int(attach_x - cx), int(attach_y - cy))
        frames.append(canvas)
    # Trim every frame to the same box so the body does not jump sideways.
    union = np.zeros((frames[0].height, frames[0].width), dtype=bool)
    for frame in frames:
        union |= np.asarray(frame)[..., 3] > 20
    ys, xs = np.where(union)
    box = (int(xs.min()) - 4, int(ys.min()) - 4, int(xs.max()) + 5, int(ys.max()) + 5)
    box = (
        max(0, box[0]),
        max(0, box[1]),
        min(frames[0].width, box[2]),
        min(frames[0].height, box[3]),
    )
    trimmed = [frame.crop(box) for frame in frames]
    # About the same on-screen width as before, with the painting's proportions.
    point_w = 240
    point_h = max(1, int(round(point_w * trimmed[0].height / trimmed[0].width)))
    out = []
    for frame in trimmed:
        out.append(frame.resize((point_w * 2, point_h * 2), Image.Resampling.LANCZOS))
    for index, frame in enumerate(out):
        frame.save(RES / f"ui-run-{index}.png")
    return point_w, point_h, out


def main():
    RES.mkdir(parents=True, exist_ok=True)
    peek = make_peek()
    walk = make_walk()
    print("peek point size", peek)
    print("walk point size", walk[0], walk[1], "frames", len(walk[2]))


if __name__ == "__main__":
    main()
