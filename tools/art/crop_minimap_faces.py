"""Crops each character's face out of the boot screen key art (assets/ui/boot/boot_bg.webp)
for the minimap (assets/portraits/faces/<id>.png, 96 x 96 squares, shown in a circle).

usage: python tools/art/crop_minimap_faces.py
Needs Pillow. The boxes are (left, top, right, bottom) in the 941 x 1672 key art.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/ui/boot/boot_bg.webp"
OUT = ROOT / "assets/portraits/faces"
SIZE = 96
# each box is shrunk toward its centre: the face is only about 16 px wide on the minimap
TIGHTEN = 0.9

# the six kids in the key art, left to right
FACES: dict[str, tuple[int, int, int, int]] = {
    "junjun": (5, 765, 215, 975),
    "popoy": (165, 775, 365, 975),
    "ligaya": (285, 870, 485, 1070),
    "migo": (400, 805, 600, 1005),
    "toni": (560, 850, 770, 1060),
    "inday": (741, 800, 941, 1000),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    art = Image.open(SOURCE).convert("RGB")
    for name, box in FACES.items():
        left, top, right, bottom = box
        cx, cy, half = (left + right) / 2, (top + bottom) / 2, (right - left) / 2 * TIGHTEN
        face = art.crop((round(cx - half), round(cy - half), round(cx + half), round(cy + half))).resize((SIZE, SIZE), Image.LANCZOS)
        face.save(OUT / f"{name}.png", optimize=True)
        print("wrote", OUT / f"{name}.png")


if __name__ == "__main__":
    main()
