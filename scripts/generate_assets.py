#!/usr/bin/env python3
"""Generate pixel-art sprites for Shop Survivors into Assets.xcassets."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "ShopSurvivors" / "Assets.xcassets"
SCALE = 8
SPRITE = 16


def imageset_dir(name: str) -> Path:
    d = ROOT / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_contents(name: str, filename: str):
    d = imageset_dir(name)
    (d / "Contents.json").write_text(
        """{
  "images" : [
    {
      "filename" : "%s",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
        % filename
    )


def save(name: str, img: Image.Image, upscale: int = SCALE):
    out = img.resize((img.width * upscale, img.height * upscale), Image.NEAREST)
    filename = f"{name}.png"
    path = imageset_dir(name) / filename
    out.save(path)
    write_contents(name, filename)
    print("wrote", path)


def blank(w=SPRITE, h=SPRITE):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(draw, x, y, color, w=1, h=1):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def draw_chibi(img, body, shirt, hair, accent, pants=(40, 40, 50, 255), frame="idle"):
    """frame: idle | walk1 | walk2 — leg offsets for walk cycle."""
    d = ImageDraw.Draw(img)
    px(d, 4, 14, (0, 0, 0, 60), 8, 2)

    if frame == "walk1":
        left, right = (4, 12, 2, 3), (10, 11, 2, 4)
    elif frame == "walk2":
        left, right = (10, 12, 2, 3), (4, 11, 2, 4)
    else:
        left, right = (5, 12, 2, 3), (9, 12, 2, 3)

    px(d, *left[:2], pants, left[2], left[3])
    px(d, *right[:2], pants, right[2], right[3])

    body_y = 7 if frame == "idle" else 6
    px(d, 5, body_y, shirt, 6, 5)
    px(d, 5, body_y - 5, body, 6, 5)
    px(d, 5, body_y - 6, hair, 6, 2)
    px(d, 4, body_y - 5, hair, 1, 3)
    px(d, 11, body_y - 5, hair, 1, 3)
    px(d, 6, body_y - 3, (20, 20, 25, 255), 1, 1)
    px(d, 9, body_y - 3, (20, 20, 25, 255), 1, 1)
    px(d, 10, body_y + 1, accent, 2, 2)
    return img


def save_character(base_name, body, shirt, hair, accent, pants, bag=False):
    for frame in ("idle", "walk1", "walk2"):
        img = blank()
        draw_chibi(img, body, shirt, hair, accent, pants, frame)
        if bag:
            d = ImageDraw.Draw(img)
            px(d, 12, 9, (255, 200, 60, 255), 3, 4)
            px(d, 13, 8, (180, 120, 40, 255), 1, 1)
        name = base_name if frame == "idle" else f"{base_name}_{frame}"
        # Also keep base name as idle alias
        if frame == "idle":
            save(base_name, img)
        save(f"{base_name}_{frame}", img)


def make_player():
    save_character(
        "player",
        body=(255, 214, 170, 255),
        shirt=(32, 180, 190, 255),
        hair=(40, 90, 120, 255),
        accent=(255, 140, 60, 255),
        pants=(30, 50, 70, 255),
    )


def make_companion():
    save_character(
        "companion",
        body=(255, 214, 170, 255),
        shirt=(255, 120, 90, 255),
        hair=(120, 60, 40, 255),
        accent=(255, 220, 80, 255),
        pants=(90, 50, 70, 255),
        bag=True,
    )


def make_clerk(name, shirt, hair, badge):
    save_character(
        name,
        body=(255, 214, 170, 255),
        shirt=shirt,
        hair=hair,
        accent=badge,
        pants=(50, 50, 60, 255),
    )
    # clipboard on idle only already in base; add to all frames
    for frame in ("idle", "walk1", "walk2"):
        key = name if frame == "idle" else f"{name}_{frame}"
        # re-open and add clipboard
        path = imageset_dir(key if frame != "idle" else name) / f"{name if frame == 'idle' else key}.png"
        # Simpler: stamp clipboard onto already-saved small images by regenerating
    for frame in ("idle", "walk1", "walk2"):
        img = blank()
        draw_chibi(img, (255, 214, 170, 255), shirt, hair, badge, (50, 50, 60, 255), frame)
        d = ImageDraw.Draw(img)
        px(d, 1, 8, (240, 240, 245, 255), 3, 4)
        px(d, 2, 9, (80, 160, 220, 255), 1, 1)
        if frame == "idle":
            save(name, img)
        save(f"{name}_{frame}", img)


def make_coupon():
    img = blank(20, 16)
    d = ImageDraw.Draw(img)
    px(d, 1, 2, (255, 230, 120, 255), 18, 12)
    px(d, 1, 2, (220, 160, 40, 255), 18, 1)
    px(d, 1, 13, (220, 160, 40, 255), 18, 1)
    for x in range(1, 19, 2):
        px(d, x, 1, (255, 230, 120, 255), 1, 1)
        px(d, x, 14, (255, 230, 120, 255), 1, 1)
    # LURE text bars
    px(d, 4, 5, (200, 80, 40, 255), 12, 2)
    px(d, 5, 8, (200, 80, 40, 255), 10, 1)
    px(d, 6, 10, (200, 80, 40, 255), 8, 1)
    save("coupon", img)


def make_xp():
    img = blank(16, 16)
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 13, 13], fill=(40, 200, 210, 255), outline=(20, 120, 140, 255))
    px(d, 5, 5, (220, 255, 255, 255), 2, 2)
    # XP mark
    px(d, 5, 8, (10, 40, 50, 255), 2, 4)
    px(d, 9, 8, (10, 40, 50, 255), 2, 4)
    px(d, 6, 9, (10, 40, 50, 255), 4, 1)
    save("xp_orb", img)


def make_pricetag():
    img = blank(14, 14)
    d = ImageDraw.Draw(img)
    px(d, 2, 4, (255, 220, 80, 255), 10, 7)
    px(d, 2, 4, (200, 140, 30, 255), 10, 1)
    # $
    px(d, 6, 6, (180, 60, 40, 255), 2, 4)
    px(d, 5, 7, (180, 60, 40, 255), 4, 1)
    px(d, 5, 9, (180, 60, 40, 255), 4, 1)
    px(d, 10, 3, (255, 220, 80, 255), 2, 2)
    save("proj_pricetag", img)


def make_receipt():
    img = blank(16, 12)
    d = ImageDraw.Draw(img)
    px(d, 1, 1, (245, 245, 240, 255), 14, 10)
    px(d, 3, 3, (40, 180, 120, 255), 4, 1)
    for y in (5, 7, 9):
        px(d, 3, y, (160, 160, 150, 255), 10, 1)
    save("proj_receipt", img)


def make_laser():
    img = blank(24, 8)
    d = ImageDraw.Draw(img)
    px(d, 0, 3, (40, 220, 120, 255), 24, 2)
    px(d, 0, 2, (180, 255, 200, 255), 24, 1)
    px(d, 0, 5, (20, 140, 80, 255), 24, 1)
    save("proj_laser", img)


def make_bag():
    img = blank(14, 14)
    d = ImageDraw.Draw(img)
    px(d, 3, 5, (255, 140, 50, 255), 8, 7)
    px(d, 4, 3, (200, 100, 40, 255), 1, 3)
    px(d, 9, 3, (200, 100, 40, 255), 1, 3)
    px(d, 4, 3, (200, 100, 40, 255), 6, 1)
    px(d, 5, 7, (255, 200, 120, 255), 4, 2)
    save("proj_bag", img)


def make_floor():
    img = blank(32, 32)
    d = ImageDraw.Draw(img)
    for y in range(0, 32, 8):
        for x in range(0, 32, 8):
            c = (55, 70, 85, 255) if ((x // 8) + (y // 8)) % 2 == 0 else (45, 58, 72, 255)
            px(d, x, y, c, 8, 8)
    for i in range(0, 33, 8):
        px(d, 0, i, (35, 45, 55, 255), 32, 1)
        px(d, i, 0, (35, 45, 55, 255), 1, 32)
    save("floor_tile", img, upscale=4)


def make_shelf():
    img = blank(24, 16)
    d = ImageDraw.Draw(img)
    px(d, 1, 2, (90, 70, 50, 255), 22, 12)
    px(d, 2, 3, (120, 95, 70, 255), 20, 2)
    px(d, 2, 7, (120, 95, 70, 255), 20, 2)
    px(d, 2, 11, (120, 95, 70, 255), 20, 2)
    colors = [(40, 180, 200), (255, 120, 80), (80, 200, 100), (255, 210, 70)]
    for i, c in enumerate(colors):
        px(d, 3 + i * 5, 4, (*c, 255), 3, 2)
        px(d, 3 + i * 5, 8, (*c, 255), 3, 2)
    save("prop_shelf", img)


def make_title_splash():
    # Keep existing AI splash if present; only regenerate if missing
    existing = imageset_dir("title_splash") / "title_splash.png"
    if existing.exists() and existing.stat().st_size > 50_000:
        print("keep existing title_splash")
        return
    img = blank(64, 48)
    d = ImageDraw.Draw(img)
    px(d, 0, 36, (40, 55, 70, 255), 64, 12)
    px(d, 18, 20, (32, 180, 190, 255), 8, 10)
    px(d, 32, 22, (255, 120, 90, 255), 8, 10)
    save("title_splash", img, upscale=6)


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    make_player()
    make_companion()
    make_clerk("clerk_pitcher", (70, 110, 180, 255), (50, 50, 60, 255), (255, 200, 60, 255))
    make_clerk("clerk_closer", (120, 50, 70, 255), (30, 30, 40, 255), (255, 80, 80, 255))
    make_clerk("clerk_sprinter", (40, 140, 100, 255), (90, 60, 30, 255), (80, 255, 180, 255))
    make_clerk("clerk_upseller", (160, 100, 40, 255), (40, 40, 50, 255), (255, 160, 40, 255))
    make_coupon()
    make_xp()
    make_pricetag()
    make_receipt()
    make_laser()
    make_bag()
    make_floor()
    make_shelf()
    make_title_splash()
    print("Done.")


if __name__ == "__main__":
    main()
