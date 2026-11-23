#!/usr/bin/env python3
"""An original front-facing hamster for the corner hole.

This is not based on a stock picture. It is a round orange cartoon with a
cream face, drawn here so the peek, the blink, and the nap all match.
"""

from __future__ import annotations

from PIL import Image, ImageDraw

OUTLINE = (74, 46, 30, 255)
ORANGE = (230, 146, 58, 255)
ORANGE_DEEP = (196, 112, 40, 255)
CREAM = (255, 246, 228, 255)
PINK = (244, 176, 188, 255)
PINK_DEEP = (226, 142, 160, 255)
EYE = (32, 20, 16, 255)
NOSE = (62, 38, 34, 255)


def _ellipse(draw, box, fill, outline_width):
    x0, y0, x1, y1 = box
    draw.ellipse(
        [x0 - outline_width, y0 - outline_width, x1 + outline_width, y1 + outline_width],
        fill=OUTLINE,
    )
    draw.ellipse(box, fill=fill)


def render_peek(mood: str = "open", size=(236, 220)) -> Image.Image:
    w, h = size
    scale = 3
    image = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def S(v):
        return v * scale

    thick = S(5)
    cx = S(w / 2)

    # Ears, then the round head, then the face, so the cheeks cover the ear bases.
    for side in (-1, 1):
        ear = [cx + side * S(48) - S(26), S(18), cx + side * S(48) + S(26), S(78)]
        _ellipse(draw, ear, ORANGE, thick)
        inner = [ear[0] + S(10), ear[1] + S(12), ear[2] - S(10), ear[3] - S(10)]
        draw.ellipse(inner, fill=PINK)

    head = [cx - S(78), S(48), cx + S(78), S(176)]
    _ellipse(draw, head, ORANGE, thick)
    # A slightly deeper orange cap so the cream face has a back to sit on.
    draw.ellipse([cx - S(78), S(48), cx + S(78), S(110)], fill=ORANGE_DEEP)
    draw.ellipse([cx - S(70), S(78), cx + S(70), S(168)], fill=CREAM)

    def eye(center_x, open_eye: bool):
        if mood == "sleep" or not open_eye:
            y = S(108)
            draw.arc(
                [center_x - S(16), y - S(10), center_x + S(16), y + S(12)],
                start=200,
                end=340,
                fill=OUTLINE,
                width=max(3, S(3)),
            )
            return
        if mood == "blink":
            draw.ellipse([center_x - S(15), S(104), center_x + S(15), S(114)], fill=EYE)
            return
        box = [center_x - S(16), S(92), center_x + S(16), S(124)]
        _ellipse(draw, box, EYE, max(2, S(2)))
        draw.ellipse([center_x - S(8), S(96), center_x - S(1), S(104)], fill=(255, 255, 255, 240))
        draw.ellipse([center_x + S(4), S(108), center_x + S(8), S(112)], fill=(255, 255, 255, 200))

    eye(cx - S(28), True)
    eye(cx + S(28), True)

    draw.ellipse([cx - S(7), S(122), cx + S(7), S(132)], fill=NOSE)
    # A tiny w smile.
    y = S(142)
    draw.line([(cx - S(14), y), (cx - S(6), y + S(6))], fill=OUTLINE, width=max(2, S(2)))
    draw.line([(cx - S(6), y + S(6)), (cx, y)], fill=OUTLINE, width=max(2, S(2)))
    draw.line([(cx, y), (cx + S(6), y + S(6))], fill=OUTLINE, width=max(2, S(2)))
    draw.line([(cx + S(6), y + S(6)), (cx + S(14), y)], fill=OUTLINE, width=max(2, S(2)))

    for side in (-1, 1):
        origin = (cx + side * S(36), S(128))
        for dy in (-8, 0, 8):
            draw.line(
                [origin, (origin[0] + side * S(34), origin[1] + S(dy))],
                fill=OUTLINE,
                width=max(2, S(1)),
            )

    for side in (-1, 1):
        paw = [cx + side * S(18) - S(20), S(162), cx + side * S(18) + S(16), S(196)]
        _ellipse(draw, paw, PINK, thick)
        draw.ellipse(
            [paw[0] + S(6), paw[1] + S(6), paw[2] - S(6), paw[3] - S(6)],
            fill=PINK_DEEP,
        )

    return image.resize(size, Image.Resampling.LANCZOS)


def render_peek_set():
    return {
        "open": render_peek("open"),
        "blink": render_peek("blink"),
        "sleep": render_peek("sleep"),
    }


if __name__ == "__main__":
    from pathlib import Path

    out = Path(__file__).resolve().parents[1] / "Sources" / "HamsterInfestation" / "Resources"
    images = render_peek_set()
    images["open"].save(out / "ui-peek.png")
    images["blink"].save(out / "ui-peek-blink.png")
    images["sleep"].save(out / "ui-peek-sleep.png")
    print("peek sprites written", images["open"].size)
