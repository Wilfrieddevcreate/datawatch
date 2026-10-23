"""Icônes monogrammes pour les captures de la vidéo de présentation.

Les vraies icônes viennent du téléphone ; pour la vidéo, on évite les logos
des marques et on garde des monogrammes sobres, comme dans la maquette.

    python3 tool/promo/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tool" / "promo" / "assets" / "icons"
FONT = ROOT / "assets" / "fonts" / "BricolageGrotesque.ttf"

ICONS = {
    "com.zhiliaoapp.musically": ("Tk", "#E4E8FF", "#2B3FB0"),
    "com.google.android.youtube": ("Yt", "#FFE6D9", "#9A3412"),
    "com.whatsapp": ("Wa", "#E4F5C8", "#3F5A0B"),
    "com.facebook.katana": ("Fb", "#E1ECFF", "#1E40AF"),
    "com.android.chrome": ("Ch", "#FFF1C2", "#7A4D00"),
    "com.instagram.android": ("Ig", "#FCE4F1", "#9D174D"),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    size = 256
    for pkg, (text, bg, fg) in ICONS.items():
        img = Image.new("RGBA", (size, size), bg)
        font = ImageFont.truetype(str(FONT), 112)
        font.set_variation_by_axes([48, 700, 100])
        draw = ImageDraw.Draw(img)
        box = draw.textbbox((0, 0), text, font=font)
        w, h = box[2] - box[0], box[3] - box[1]
        draw.text(((size - w) / 2 - box[0], (size - h) / 2 - box[1]), text, font=font, fill=fg)
        img.save(OUT / f"{pkg}.png")
    print(f"{len(ICONS)} icônes dans {OUT}")


if __name__ == "__main__":
    main()
