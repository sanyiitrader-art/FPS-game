#!/usr/bin/env python3
"""Generate small placeholder images so the game always has something to show.

Real artwork goes in assets/ui/ (for example assets/ui/map_urban.png); the game prefers
real files and only falls back to these generated placeholders.

Outputs (in assets/generated/):
  map_urban_placeholder.png, map_industrial_placeholder.png   960x540 map previews
  avatar_placeholder.png                                      256x256 portrait silhouette
  weapon_placeholder.png                                      512x256 weapon silhouette
  bomb_grenade_placeholder.png, bomb_sticky_placeholder.png   128x128 bomb icons
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "generated"

BG_MAIN = (21, 25, 30)
BG_SECOND = (32, 40, 48)
PANEL = (41, 52, 61)
ACCENT = (98, 182, 165)
ACCENT_2 = (120, 157, 187)
TEXT = (229, 233, 236)
TEXT_2 = (154, 166, 174)
BORDER = (55, 67, 76)

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "DejaVuSans-Bold.ttf",
    "arial.ttf",
]


def get_font(size: int) -> ImageFont.ImageFont:
    for candidate in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def draw_centered(draw: ImageDraw.ImageDraw, center, text, font, fill) -> None:
    box = draw.textbbox((0, 0), text, font=font)
    width, height = box[2] - box[0], box[3] - box[1]
    draw.text((center[0] - width / 2 - box[0], center[1] - height / 2 - box[1]), text, font=font, fill=fill)


def gradient(size, top, bottom) -> Image.Image:
    img = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(img)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size[0], y)], fill=color)
    return img


def map_preview(name: str, accent, seed: int) -> Image.Image:
    size = (960, 540)
    img = gradient(size, BG_SECOND, BG_MAIN)
    draw = ImageDraw.Draw(img)
    for x in range(0, size[0], 48):
        draw.line([(x, 0), (x, size[1])], fill=BORDER, width=1)
    for y in range(0, size[1], 48):
        draw.line([(0, y), (size[0], y)], fill=BORDER, width=1)
    rng = random.Random(seed)
    for _ in range(16):
        w = rng.randrange(2, 6) * 48
        h = rng.randrange(2, 5) * 48
        x = rng.randrange(0, (size[0] - w) // 48) * 48
        y = rng.randrange(0, (size[1] - h) // 48) * 48
        draw.rectangle((x + 4, y + 4, x + w - 4, y + h - 4), fill=PANEL, outline=BORDER, width=2)
    draw.rectangle((0, 190, size[0], 350), fill=(21, 25, 30))
    draw_centered(draw, (size[0] / 2, 245), name, get_font(76), accent)
    draw_centered(draw, (size[0] / 2, 315), "PREVIEW PLACEHOLDER", get_font(26), TEXT_2)
    return img


def avatar() -> Image.Image:
    img = Image.new("RGB", (256, 256), PANEL)
    draw = ImageDraw.Draw(img)
    draw.ellipse((88, 46, 168, 126), fill=ACCENT_2)
    draw.ellipse((40, 140, 216, 330), fill=ACCENT_2)
    draw.rectangle((0, 0, 255, 255), outline=BORDER, width=4)
    return img


def weapon() -> Image.Image:
    img = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((70, 100, 400, 140), fill=TEXT)            # body
    draw.rectangle((400, 112, 480, 128), fill=TEXT)           # barrel
    draw.polygon([(150, 140), (200, 140), (190, 215), (140, 215)], fill=TEXT_2)  # magazine
    draw.polygon([(70, 100), (20, 130), (20, 160), (90, 140)], fill=TEXT_2)      # stock
    draw.polygon([(300, 140), (340, 140), (330, 190), (300, 190)], fill=TEXT_2)  # grip
    return img


def grenade() -> Image.Image:
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse((28, 36, 100, 112), fill=TEXT_2, outline=TEXT, width=4)
    draw.rectangle((54, 18, 74, 40), fill=TEXT)
    draw.arc((60, 6, 104, 40), 200, 340, fill=TEXT, width=4)
    return img


def sticky() -> Image.Image:
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((24, 40, 104, 96), radius=10, fill=TEXT_2, outline=TEXT, width=4)
    draw.ellipse((54, 58, 74, 78), fill=(190, 110, 100))
    draw.line([(64, 40), (64, 20)], fill=TEXT, width=4)
    return img


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "map_urban_placeholder.png": map_preview("URBAN", ACCENT, 11),
        "map_industrial_placeholder.png": map_preview("INDUSTRIAL", ACCENT_2, 23),
        "avatar_placeholder.png": avatar(),
        "weapon_placeholder.png": weapon(),
        "bomb_grenade_placeholder.png": grenade(),
        "bomb_sticky_placeholder.png": sticky(),
    }
    for name, image in outputs.items():
        image.save(OUT_DIR / name, optimize=True)
    print(f"Generated {len(outputs)} placeholder images in {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())