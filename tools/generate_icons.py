#!/usr/bin/env python3
"""Generate Android launcher icons from the repository's root icon.png.

Outputs (in assets/generated/):
  icon_192.png     legacy / main launcher icon (192x192)
  icon_fg_432.png  adaptive icon foreground (432x432, content inside the safe zone)
  icon_bg_432.png  adaptive icon background (432x432, solid Calm Tactical dark)

If icon.png is missing, unreadable, not square or too small, the build FAILS with a
clear message. No substitute icon is ever generated.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "generated"
MIN_SIZE = 512
BG_COLOR = (21, 25, 30, 255)  # #15191E


class IconError(Exception):
    """Raised when icon.png cannot be used."""


def load_icon(root: Path = ROOT) -> Image.Image:
    """Load and validate root/icon.png. Returns an RGBA image."""
    path = root / "icon.png"
    if not path.is_file():
        raise IconError(
            "icon.png was not found in the repository root. "
            "Add a square PNG (at least 512x512, 1024x1024 recommended) named icon.png."
        )
    try:
        with Image.open(path) as probe:
            probe.verify()
        img = Image.open(path)
        img.load()
    except Exception as exc:  # noqa: BLE001 - any decoding problem means unusable
        raise IconError(f"icon.png is not a readable image: {exc}") from exc

    if img.format != "PNG":
        raise IconError(f"icon.png must be a PNG file (found {img.format}).")
    width, height = img.size
    if width != height:
        raise IconError(
            f"icon.png must be square (found {width}x{height}). "
            "Crop it to a square and try again."
        )
    if width < MIN_SIZE:
        raise IconError(
            f"icon.png is too small ({width}x{height}). Minimum is {MIN_SIZE}x{MIN_SIZE}; "
            "1024x1024 is recommended."
        )
    return img.convert("RGBA")


def has_transparency(img: Image.Image) -> bool:
    return img.getchannel("A").getextrema()[0] < 250


def circular_crop(img: Image.Image) -> Image.Image:
    """Return img with a smooth circular alpha mask (supersampled for clean edges)."""
    size = img.size[0]
    scale = 4
    mask = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * scale - 1, size * scale - 1), fill=255)
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    out = img.copy()
    out.putalpha(mask)
    return out


def build_foreground(img: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    if has_transparency(img):
        # Transparent artwork: use most of the visible area.
        content = img.resize((288, 288), Image.Resampling.LANCZOS)
        canvas.paste(content, (72, 72), content)
    else:
        # Opaque artwork: fit it inside the 66dp safe circle so no launcher mask clips it.
        content = circular_crop(img.resize((264, 264), Image.Resampling.LANCZOS))
        canvas.paste(content, (84, 84), content)
    return canvas


def main() -> int:
    try:
        icon = load_icon(ROOT)
    except IconError as exc:
        print(f"::error::{exc}")
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    icon.resize((192, 192), Image.Resampling.LANCZOS).save(OUT_DIR / "icon_192.png", optimize=True)
    build_foreground(icon).save(OUT_DIR / "icon_fg_432.png", optimize=True)
    Image.new("RGBA", (432, 432), BG_COLOR).save(OUT_DIR / "icon_bg_432.png", optimize=True)

    kind = "transparent" if has_transparency(icon) else "opaque"
    print(f"Icons generated from icon.png ({icon.size[0]}x{icon.size[1]}, {kind}) into {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())