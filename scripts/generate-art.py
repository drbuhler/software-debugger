#!/usr/bin/env python3
"""Draw the original art for Hamster Infestation.

The pictures inside the built app use bland filenames on purpose.
The project name stays Hamster Infestation; the installed app does not.
Nothing here is copied from another character or a film.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from render_lifelike import render_pointer
from render_peek_kawaii import render_peek_set
from render_walking_from_art import render_frames as render_reference_run

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Sources" / "HamsterInfestation" / "Resources"
ICON = ROOT / "packaging" / "AppIcon.iconset"
DOCS = ROOT / "docs"

# Warm hamster colors. The app icon deliberately does not use these.
FUR = (230, 158, 72, 255)
FUR_DEEP = (196, 122, 46, 255)
FUR_PALE = (244, 198, 130, 255)
BELLY = (255, 240, 220, 255)
EAR = (244, 176, 190, 255)
EAR_DEEP = (226, 142, 162, 255)
NOSE = (222, 108, 128, 255)
EYE = (54, 36, 30, 255)
CHEEK = (244, 164, 154, 150)
CLAW = (255, 236, 214, 255)
WOOD = (214, 176, 118, 255)
WOOD_DEEP = (168, 124, 74, 255)
HOLE = (58, 40, 34, 255)
DIRT = (168, 116, 70, 255)
DIRT_DEEP = (122, 80, 46, 255)
PELLET = (128, 82, 50, 255)
PELLET_BAND = (92, 58, 36, 255)
CURL = (240, 220, 180, 255)
CURL_DEEP = (214, 180, 130, 255)
TEAR = (126, 186, 220, 230)
INK = (62, 42, 32, 255)


def canvas(w: int, h: int, scale: int = 4):
    image = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), scale


def down(image: Image.Image, w: int, h: int) -> Image.Image:
    return image.resize((w, h), Image.Resampling.LANCZOS)


def ell(draw, box, fill, scale, outline=None, width=0):
    scaled = [v * scale for v in box]
    draw.ellipse(scaled, fill=fill, outline=outline, width=width * scale)


def poly(draw, points, fill, scale):
    draw.polygon([(x * scale, y * scale) for x, y in points], fill=fill)


def line(draw, a, b, fill, scale, width):
    draw.line(
        [(a[0] * scale, a[1] * scale), (b[0] * scale, b[1] * scale)],
        fill=fill,
        width=max(1, int(width * scale)),
    )


def arc(draw, box, start, end, fill, scale, width):
    scaled = [v * scale for v in box]
    draw.arc(scaled, start=start, end=end, fill=fill, width=max(1, int(width * scale)))


def eye(draw, cx, cy, scale, mood="open", size=7):
    if mood == "shut":
        arc(draw, [cx - size, cy - 2, cx + size, cy + 6], 200, 340, EYE, scale, 2.2)
        return
    if mood == "sad":
        ell(draw, [cx - size, cy - size * 0.7, cx + size, cy + size * 0.55], EYE, scale)
        # Heavy lid.
        ell(draw, [cx - size - 1, cy - size * 1.3, cx + size + 1, cy - 1], FUR, scale)
    elif mood == "blink":
        ell(draw, [cx - size, cy - 2.2, cx + size, cy + 2.2], EYE, scale)
    else:
        ell(draw, [cx - size, cy - size, cx + size, cy + size], EYE, scale)
        ell(draw, [cx - size * 0.15, cy - size * 0.55, cx + size * 0.35, cy - size * 0.05], (255, 255, 255, 230), scale)
    if mood == "sad":
        ell(draw, [cx - 1.5, cy + size * 0.2, cx + 2.2, cy + size * 0.85], (255, 255, 255, 220), scale)


def ear(draw, cx, cy, scale, droop=0):
    cy = cy + droop
    ell(draw, [cx - 16, cy - 20, cx + 16, cy + 18], FUR, scale)
    ell(draw, [cx - 9, cy - 10, cx + 9, cy + 10], EAR, scale)
    ell(draw, [cx - 5, cy - 4, cx + 4, cy + 6], EAR_DEEP, scale)


def front_head(draw, cx, cy, scale, mood="open", ears_droop=0, with_paws=False):
    ear(draw, cx - 28, cy - 34, scale, ears_droop)
    ear(draw, cx + 28, cy - 34, scale, ears_droop)
    ell(draw, [cx - 46, cy - 40, cx + 46, cy + 42], FUR_DEEP, scale)
    ell(draw, [cx - 42, cy - 44, cx + 42, cy + 36], FUR, scale)
    ell(draw, [cx - 24, cy - 4, cx + 24, cy + 32], BELLY, scale)
    ell(draw, [cx - 30, cy + 2, cx - 12, cy + 16], CHEEK, scale)
    ell(draw, [cx + 12, cy + 2, cx + 30, cy + 16], CHEEK, scale)
    eye(draw, cx - 16, cy - 6, scale, mood, 6.5)
    eye(draw, cx + 16, cy - 6, scale, mood, 6.5)
    ell(draw, [cx - 7, cy + 8, cx + 7, cy + 16], NOSE, scale)
    if mood == "sad":
        arc(draw, [cx - 10, cy + 16, cx + 10, cy + 28], 200, 340, INK, scale, 2)
        # One tear under the left eye.
        ell(draw, [cx - 22, cy + 4, cx - 16, cy + 14], TEAR, scale)
        ell(draw, [cx - 21, cy + 12, cx - 17, cy + 20], TEAR, scale)
    elif mood == "shut":
        arc(draw, [cx - 8, cy + 18, cx + 8, cy + 26], 20, 160, INK, scale, 2)
    else:
        arc(draw, [cx - 9, cy + 16, cx + 9, cy + 28], 20, 160, INK, scale, 2)
    # Whiskers.
    for side in (-1, 1):
        line(draw, (cx + side * 8, cy + 12), (cx + side * 40, cy + 6), INK, scale, 1.2)
        line(draw, (cx + side * 8, cy + 15), (cx + side * 42, cy + 16), INK, scale, 1.2)
        line(draw, (cx + side * 8, cy + 18), (cx + side * 38, cy + 26), INK, scale, 1.2)
    if with_paws:
        paw(draw, cx - 24, cy + 40, scale, 0)
        paw(draw, cx + 10, cy + 40, scale, 0)


def paw(draw, x, y, scale, angle_deg):
    # A small oval paw. angle is only used by the pointer, which draws its own arm.
    ell(draw, [x, y, x + 18, y + 12], FUR_PALE, scale)
    ell(draw, [x + 1, y + 1, x + 16, y + 9], FUR, scale)
    for i in range(3):
        ell(draw, [x + 2 + i * 5, y - 2, x + 6 + i * 5, y + 3], CLAW, scale)


def side_body(draw, cx, cy, scale, legs, mood="open", facing=1):
    """A chubby side-view hamster. facing=1 looks right."""

    def fx(x):
        return cx + facing * (x - cx)

    def box(x0, y0, x1, y1):
        a, b = fx(cx + x0), fx(cx + x1)
        return [min(a, b), cy + y0, max(a, b), cy + y1]

    # Tail nub, then body, then head so the head sits in front.
    ell(draw, box(-52, -6, -38, 8), FUR_DEEP, scale)
    ell(draw, box(-46, -28, 20, 30), FUR_DEEP, scale)
    ell(draw, box(-42, -32, 16, 24), FUR, scale)
    ell(draw, box(-28, -6, 8, 22), BELLY, scale)
    # Head.
    ell(draw, box(4, -40, 48, 16), FUR, scale)
    ell(draw, box(18, -36, 36, -4), FUR, scale)  # ear base
    ell(draw, box(20, -34, 34, -8), EAR, scale)
    ell(draw, box(10, -8, 28, 8), CHEEK, scale)
    eye(draw, fx(cx + 28), cy - 16, scale, mood, 4.5)
    ell(draw, box(36, -8, 48, 2), NOSE, scale)
    if mood == "shut":
        arc(draw, box(30, 0, 44, 10), 20, 160, INK, scale, 1.6)
    else:
        arc(draw, box(32, -2, 46, 8), 10, 150, INK, scale, 1.6)
    # Legs: each entry is (x, y) of a foot under the body.
    for lx, ly in legs:
        ell(draw, box(lx - 7, ly - 4, lx + 8, ly + 10), FUR_DEEP, scale)
        ell(draw, box(lx - 5, ly - 2, lx + 6, ly + 6), FUR, scale)
    # Little arm on the near side.
    ell(draw, box(6, 0, 22, 14), FUR_PALE, scale)


RUN_LEGS = [
    [(-30, 18), (-8, 22), (6, 16), (18, 22)],
    [(-32, 12), (-6, 24), (10, 8), (22, 18)],
    [(-34, 6), (-4, 12), (12, 2), (24, 8)],
    [(-30, 14), (-10, 8), (4, 20), (20, 10)],
    [(-28, 22), (-12, 16), (2, 22), (16, 14)],
    [(-30, 16), (-8, 10), (8, 18), (20, 22)],
]
RUN_BOB = [0, -4, -8, -3, 2, 0]


def render_runner(frame: int, w=180, h=120) -> Image.Image:
    image, draw, scale = canvas(w, h)
    bob = RUN_BOB[frame]
    side_body(draw, 86, 58 + bob, scale, RUN_LEGS[frame])
    return down(image, w, h)


def render_wave(frame: int, w=180, h=180) -> Image.Image:
    image, draw, scale = canvas(w, h)
    # Sitting body.
    ell(draw, [38, 78, 142, 162], FUR_DEEP, scale)
    ell(draw, [46, 70, 134, 150], FUR, scale)
    ell(draw, [62, 96, 118, 146], BELLY, scale)
    front_head(draw, 90, 78, scale, mood="open")
    # Waving paw. Four angles.
    angles = [-40, -70, -100, -70]
    ang = math.radians(angles[frame])
    shoulder = (118, 108)
    length = 36
    tip = (shoulder[0] + math.cos(ang) * length, shoulder[1] + math.sin(ang) * length)
    line(draw, shoulder, tip, FUR_DEEP, scale, 8)
    ell(draw, [tip[0] - 10, tip[1] - 8, tip[0] + 10, tip[1] + 8], FUR_PALE, scale)
    # Other paw stays down.
    paw(draw, 48, 132, scale, 0)
    return down(image, w, h)


def render_peek(mood: str, w=160, h=150) -> Image.Image:
    image, draw, scale = canvas(w, h)
    front_head(draw, 80, 78, scale, mood=mood, ears_droop=8 if mood == "sad" else 0, with_paws=True)
    return down(image, w, h)


def render_sad(w=220, h=220) -> Image.Image:
    image, draw, scale = canvas(w, h)
    ell(draw, [48, 118, 172, 208], FUR_DEEP, scale)
    ell(draw, [56, 108, 164, 196], FUR, scale)
    ell(draw, [78, 132, 142, 190], BELLY, scale)
    front_head(draw, 110, 104, scale, mood="sad", ears_droop=10, with_paws=False)
    paw(draw, 62, 168, scale, 0)
    paw(draw, 128, 168, scale, 0)
    return down(image, w, h)


def render_cursor(w=64, h=64) -> Image.Image:
    image, draw, scale = canvas(w, h, scale=8)
    # Body sits low and to the right. One paw reaches the top-left corner,
    # and that paw tip is the pointer hotspot.
    ell(draw, [22, 28, 58, 58], FUR_DEEP, scale)
    ell(draw, [24, 26, 56, 54], FUR, scale)
    ell(draw, [30, 34, 50, 52], BELLY, scale)
    # Head.
    ell(draw, [30, 16, 56, 42], FUR, scale)
    ell(draw, [36, 12, 50, 26], FUR, scale)
    ell(draw, [40, 14, 48, 22], EAR, scale)
    eye(draw, 46, 28, scale, "open", 3.2)
    ell(draw, [48, 30, 56, 36], NOSE, scale)
    # Pointing arm toward the upper left.
    line(draw, (30, 36), (10, 12), FUR_DEEP, scale, 5)
    ell(draw, [2, 2, 16, 16], FUR_PALE, scale)
    ell(draw, [3, 3, 9, 8], CLAW, scale)
    return down(image, w, h)


def render_hole(w=220, h=150) -> Image.Image:
    image, _, scale = canvas(w, h)
    wood = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(wood)
    cx, cy = w / 2, h / 2 + 4
    rx, ry = 78, 48
    # Chewed scallops around an oval.
    steps = 48
    for i in range(steps):
        theta = (i / steps) * math.tau
        wobble = 1 + 0.08 * math.sin(theta * 5) + 0.04 * math.sin(theta * 11)
        x = cx + math.cos(theta) * rx * wobble
        y = cy + math.sin(theta) * ry * wobble
        radius = 16 + 4 * math.sin(theta * 3)
        ell(draw, [x - radius, y - radius * 0.8, x + radius, y + radius * 0.8], WOOD if i % 2 == 0 else WOOD_DEEP, scale)
    # Inner lip.
    for i in range(steps):
        theta = (i / steps) * math.tau
        x = cx + math.cos(theta) * (rx - 14)
        y = cy + math.sin(theta) * (ry - 10)
        ell(draw, [x - 8, y - 6, x + 8, y + 6], WOOD_DEEP, scale)
    # Cut the middle out so the hamster can sit behind the ring.
    mask = Image.new("L", image.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse(
        [(cx - rx + 22) * scale, (cy - ry + 16) * scale, (cx + rx - 22) * scale, (cy + ry - 12) * scale],
        fill=255,
    )
    # The center stays empty. The app paints the dark interior, then the
    # hamster, then this ring, so the face sits inside the chewed hole.
    r, g, b, a = wood.split()
    inv = Image.eval(mask, lambda p: 255 - p)
    a = ImageChops.multiply(a, inv)
    wood = Image.merge("RGBA", (r, g, b, a))
    return down(wood, w, h)


def render_shaving(w=36, h=28) -> Image.Image:
    image, draw, scale = canvas(w, h, scale=8)
    # A wood curl, like a pencil shaving.
    cx, cy = w / 2, h / 2 + 2
    for t in range(18):
        ang = t / 18 * math.pi * 1.6 - 0.4
        rad = 3 + t * 0.55
        x = cx + math.cos(ang) * rad
        y = cy + math.sin(ang) * rad * 0.62
        color = CURL if t % 2 == 0 else CURL_DEEP
        ell(draw, [x - 3.2, y - 2.2, x + 3.2, y + 2.2], color, scale)
    return down(image, w, h)


def render_pellet(w=18, h=14) -> Image.Image:
    image, draw, scale = canvas(w, h, scale=8)
    ell(draw, [1, 1, w - 1, h - 1], PELLET, scale)
    ell(draw, [3, 2, w - 5, h - 6], PELLET_BAND, scale)
    ell(draw, [4, 3, 8, 6], (186, 140, 96, 255), scale)
    return down(image, w, h)


def render_burrow(w=150, h=90) -> Image.Image:
    image, draw, scale = canvas(w, h)
    ell(draw, [10, 28, 140, 84], DIRT_DEEP, scale)
    ell(draw, [18, 22, 132, 74], DIRT, scale)
    ell(draw, [48, 34, 104, 70], HOLE, scale)
    ell(draw, [56, 40, 96, 64], (36, 24, 20, 255), scale)
    # A couple of pebbles.
    ell(draw, [24, 48, 36, 58], WOOD_DEEP, scale)
    ell(draw, [112, 50, 126, 60], WOOD, scale)
    return down(image, w, h)


def render_icon(size: int) -> Image.Image:
    """A plain utility icon: slate tile, white magnifying glass. No hamster."""
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    margin = size * 0.08
    radius = size * 0.22
    # Vertical gradient by stacked rounded rects would be fuzzy. Paint a
    # gradient, then mask it to a rounded square.
    gradient = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gradient)
    top = (94, 122, 138, 255)
    bottom = (58, 78, 92, 255)
    for y in range(size):
        t = y / max(1, size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        gd.line([(0, y), (size, y)], fill=color)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([margin, margin, size - margin, size - margin], radius=radius, fill=255)
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile.paste(gradient, (0, 0), mask)
    image = tile
    draw = ImageDraw.Draw(image)
    # Lens.
    cx, cy = size * 0.43, size * 0.42
    r = size * 0.18
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 255), width=max(2, size // 16))
    # Handle.
    x0, y0 = cx + r * 0.7, cy + r * 0.7
    x1, y1 = cx + r * 1.85, cy + r * 1.85
    draw.line([(x0, y0), (x1, y1)], fill=(255, 255, 255, 255), width=max(2, size // 14))
    return image


def save_iconset():
    ICON.mkdir(parents=True, exist_ok=True)
    mapping = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in mapping.items():
        render_icon(size).save(ICON / name)


def sheet(frames, columns, cell):
    rows = math.ceil(len(frames) / columns)
    sheet_image = Image.new("RGBA", (cell[0] * columns, cell[1] * rows), (244, 236, 224, 255))
    for index, frame in enumerate(frames):
        x = (index % columns) * cell[0]
        y = (index // columns) * cell[1]
        fitted = frame.resize(cell, Image.Resampling.LANCZOS)
        sheet_image.paste(fitted, (x, y), fitted)
    return sheet_image


def preview(sprites: dict):
    w, h = 1280, 800
    image = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    draw = ImageDraw.Draw(image)
    for y in range(h):
        t = y / (h - 1)
        color = (
            int(150 + (232 - 150) * t),
            int(186 + (214 - 186) * t),
            int(206 + (188 - 206) * t),
            255,
        )
        draw.line([(0, y), (w, y)], fill=color)
    # Soft sun. Not a copy of anyone's wallpaper.
    draw.ellipse([860, 80, 1180, 400], fill=(255, 244, 220, 90))
    # A fake window, so the preview shows what floats above ordinary apps
    # and what stays down on the desktop.
    draw.rounded_rectangle([80, 160, 620, 520], radius=16, fill=(255, 252, 248, 235))
    draw.rectangle([80, 160, 620, 198], fill=(236, 232, 226, 255))
    draw.text((100, 170), "Notes", fill=(80, 70, 60, 255))
    # Desktop burrow, bottom left, under the window's layer in real use.
    burrow = sprites["burrow"].resize((180, 108), Image.Resampling.LANCZOS)
    image.paste(burrow, (90, 600), burrow)
    pellet = sprites["pellet"]
    image.paste(pellet, (250, 660), pellet)
    image.paste(pellet, (272, 674), pellet)
    image.paste(pellet, (236, 682), pellet)
    # Peeking hamster, top right, below where a menu bar would be.
    hole = sprites["hole"].resize((250, 170), Image.Resampling.LANCZOS)
    peek = sprites["peek"].resize((150, 140), Image.Resampling.LANCZOS)
    draw.ellipse([1072, 78, 1208, 158], fill=(58, 40, 34, 255))
    image.paste(peek, (1064, 58), peek)
    image.paste(hole, (1000, 36), hole)
    shaving = sprites["shaving"]
    for dx, dy in ((1016, 168), (1046, 178), (1078, 166), (1108, 182), (1140, 170)):
        image.paste(shaving, (dx, dy), shaving)
    # Runner crossing the fake window.
    runner = sprites["run3"].resize((200, 134), Image.Resampling.LANCZOS)
    image.paste(runner, (360, 300), runner)
    # Popup.
    draw.rounded_rectangle([700, 220, 1040, 420], radius=22, fill=(255, 246, 230, 245), outline=(120, 84, 48, 255), width=3)
    wave = sprites["wave1"].resize((160, 160), Image.Resampling.LANCZOS)
    image.paste(wave, (720, 250), wave)
    draw.text((900, 300), "I live here now.", fill=(90, 58, 36, 255))
    # Pointer.
    cursor = sprites["cursor"].resize((64, 64), Image.Resampling.LANCZOS)
    image.paste(cursor, (760, 480), cursor)
    # Menu bar last, so the hole clearly sits under it.
    draw.rectangle([0, 0, w, 28], fill=(40, 44, 48, 220))
    draw.text((16, 6), "Software Debugger", fill=(240, 240, 240, 255))
    return image


def main():
    RES.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)

    runners = render_reference_run()
    peeks = render_peek_set()
    waves = [render_wave(i) for i in range(4)]
    cursor_path = RES / "ui-cursor.png"
    cursor = Image.open(cursor_path).convert("RGBA") if cursor_path.exists() else render_pointer()
    sprites = {
        "cursor": cursor,
        "peek": peeks["open"],
        "peek_blink": peeks["blink"],
        "peek_sleep": peeks["sleep"],
        "sad": render_sad(),
        "hole": render_hole(),
        "shaving": render_shaving(),
        "pellet": render_pellet(),
        "burrow": render_burrow(),
    }
    # Bland names inside the app bundle. The comments here are the legend.
    legend = {
        "ui-peek.png": sprites["peek"],              # face in the chewed hole
        "ui-peek-blink.png": sprites["peek_blink"],
        "ui-peek-sleep.png": sprites["peek_sleep"],
        "ui-sad.png": sprites["sad"],                # farewell, still lets shutdown finish
        "ui-hole.png": sprites["hole"],
        "ui-shaving.png": sprites["shaving"],
        "ui-pellet.png": sprites["pellet"],
        "ui-burrow.png": sprites["burrow"],
    }
    for name, image in legend.items():
        image.save(RES / name)
    for index, frame in enumerate(runners):
        frame.save(RES / f"ui-run-{index}.png")
        sprites[f"run{index}"] = frame
    for index, frame in enumerate(waves):
        frame.save(RES / f"ui-wave-{index}.png")
        sprites[f"wave{index}"] = frame

    gif_frames = [frame.convert("RGBA") for frame in waves]
    gif_frames[0].save(
        RES / "ui-popup.gif",
        save_all=True,
        append_images=gif_frames[1:],
        duration=140,
        loop=0,
        disposal=2,
        optimize=False,
    )

    save_iconset()
    render_icon(256).save(DOCS / "preview-icon.png")
    preview(sprites).convert("RGB").save(DOCS / "preview-desktop.png", quality=92)
    cell_w, cell_h = runners[0].size
    sheet(runners, len(runners), (max(1, cell_w // 2), max(1, cell_h // 2))).save(DOCS / "preview-run.png")
    sheet([sprites["peek"], sprites["peek_blink"], sprites["peek_sleep"], sprites["sad"], sprites["cursor"]], 5, (160, 160)).save(DOCS / "preview-faces.png")
    print(f"Art written to {RES}")
    print(f"Icon set written to {ICON}")
    print(f"Previews written to {DOCS}")


if __name__ == "__main__":
    main()
