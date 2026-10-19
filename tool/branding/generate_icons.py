"""Génère les icônes PNG de DataWatch à partir de la même géométrie que
android/app/src/main/res/drawable/ic_launcher_foreground.xml.

    python3 tool/branding/generate_icons.py

Écrit les mipmaps Android (secours pour les lanceurs sans icône adaptative)
et l'icône 512 px de la fiche Play Store dans branding/.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android" / "app" / "src" / "main" / "res"

INK_TOP = (34, 40, 55, 255)  # #222837
INK_BOTTOM = (12, 15, 20, 255)  # #0C0F14
TANK = (42, 48, 60, 255)  # #2A303C
LIME = (198, 241, 53, 255)  # #C6F135
SHINE = (255, 255, 255, 140)

# Zone visible de la grille 108 des icônes adaptatives : 18 → 90.
GRID_ORIGIN = 18
GRID_SIZE = 72
SUPERSAMPLE = 4


def render(size: int, rounded: bool) -> Image.Image:
    big = size * SUPERSAMPLE
    scale = big / GRID_SIZE

    def box(x0, y0, x1, y1):
        return [(x0 - GRID_ORIGIN) * scale, (y0 - GRID_ORIGIN) * scale,
                (x1 - GRID_ORIGIN) * scale, (y1 - GRID_ORIGIN) * scale]

    # Fond encre en dégradé vertical (même rendu que ic_launcher_background.xml).
    gradient = Image.new("RGBA", (1, big))
    for y in range(big):
        t = y / (big - 1)
        gradient.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(INK_TOP, INK_BOTTOM)))
    background = gradient.resize((big, big))
    mask = Image.new("L", (big, big), 0)
    if rounded:
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=16 * scale, fill=255)
    else:
        mask.paste(255, [0, 0, big, big])
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    image.paste(background, (0, 0), mask)
    draw = ImageDraw.Draw(image)

    # Cuve, puis niveau restant (coins bas plus ronds que les coins hauts).
    draw.rounded_rectangle(box(39, 28, 69, 80), radius=10 * scale, fill=TANK)
    draw.rounded_rectangle(box(43, 52, 65, 76), radius=6 * scale, fill=LIME)
    draw.rounded_rectangle(box(43, 52, 65, 64), radius=2.5 * scale, fill=LIME)

    shine = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(shine).rectangle(box(45, 52, 63, 53.4), fill=SHINE)
    image = Image.alpha_composite(image, shine)

    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in densities.items():
        render(size, rounded=True).save(RES / f"mipmap-{density}" / "ic_launcher.png")

    branding = ROOT / "branding"
    branding.mkdir(exist_ok=True)
    # Le Play Store applique lui-même le masque arrondi : carré plein.
    render(512, rounded=False).save(branding / "play_store_icon_512.png")
    render(1024, rounded=True).save(branding / "icon_preview_1024.png")
    print("Icônes générées.")


if __name__ == "__main__":
    main()
