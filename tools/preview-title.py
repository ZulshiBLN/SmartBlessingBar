"""Finishing touches for the store screenshots in .previews/ (ruleset plan
2026-10-24-store-screenshots; the same tool as SimpleConjureBar's). Runs on the PC with Python 3
and Pillow; never shipped.

    python tools/preview-title.py fit   <in> <out> [x y w h]
    python tools/preview-title.py blur  <in> <out> x y w h [x y w h ...]
    python tools/preview-title.py title <in> <out> "<title>"

fit    crops to the box, or to the centred 16:9 area, and scales to exactly 1280x720
blur   pixelates each box in 12 px blocks - names that must not show
title  lays a dark band across the top, 76 px, with a gold rule under it, and centres the
       title in Cinzel Bold, 40 px, gold, outlined and shadowed. It refuses an input that is
       not 1280x720 and a title wider than 1200 px.

Output is JPEG, quality 90. The font is tools/fonts/Cinzel[wght].ttf (SIL Open Font License,
tools/fonts/OFL.txt).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1280, 720
BAND = 76                                  # px covered by the band, the rule below it
BAND_TOP, BAND_BOTTOM = 0.72, 0.45         # band opacity, top to bottom
RULE = (196, 128, 20)                      # #C48014
GOLD = [(255, 246, 190), (255, 209, 0), (196, 128, 20)]  # #FFF6BE, #FFD100, #C48014
OUTLINE = (58, 34, 8)                      # dark brown
FONT_SIZE, MAX_TITLE = 40, 1200
BLOCK = 12
FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts", "Cinzel[wght].ttf")


def fail(message):
    print("preview-title: " + message, file=sys.stderr)
    sys.exit(1)


def save(image, path):
    image.convert("RGB").save(path, "JPEG", quality=90)


def numbers(values, count_of):
    try:
        out = [int(v) for v in values]
    except ValueError:
        fail("box values must be whole numbers: " + " ".join(values))
    if len(out) == 0 or len(out) % count_of:
        fail("a box is four numbers: x y w h")
    return out


def fit(src, dst, box):
    image = Image.open(src)
    if box:
        x, y, w, h = numbers(box, 4)[:4]
        image = image.crop((x, y, x + w, y + h))
    else:
        w, h = image.size
        if w * 9 > h * 16:            # wider than 16:9: cut the sides
            cw = h * 16 // 9
            image = image.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
        else:                         # taller: cut top and bottom
            ch = w * 9 // 16
            image = image.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
    save(image.resize((WIDTH, HEIGHT), Image.LANCZOS), dst)


def blur(src, dst, values):
    image = Image.open(src).convert("RGB")
    v = numbers(values, 4)
    for i in range(0, len(v), 4):
        x, y, w, h = v[i:i + 4]
        part = image.crop((x, y, x + w, y + h))
        small = part.resize((max(1, w // BLOCK), max(1, h // BLOCK)), Image.BILINEAR)
        image.paste(small.resize((w, h), Image.NEAREST), (x, y))
    save(image, dst)


def gradient(width, height):
    """The gold, top to bottom through the three stops"""
    strip = Image.new("RGB", (1, height))
    for y in range(height):
        t = y / max(1, height - 1) * (len(GOLD) - 1)
        i = min(int(t), len(GOLD) - 2)
        f = t - i
        a, b = GOLD[i], GOLD[i + 1]
        strip.putpixel((0, y), tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    return strip.resize((width, height))


def title(src, dst, text):
    image = Image.open(src).convert("RGBA")
    if image.size != (WIDTH, HEIGHT):
        fail("the input is %dx%d, not %dx%d - run fit first" % (image.size + (WIDTH, HEIGHT)))
    font = ImageFont.truetype(FONT, FONT_SIZE)
    font.set_variation_by_name("Bold")
    left, top, right, bottom = font.getbbox(text)
    width, height = right - left, bottom - top
    if width > MAX_TITLE:
        fail("the title is %d px wide, at most %d fit" % (width, MAX_TITLE))

    # the band, fading from BAND_TOP to BAND_BOTTOM, and the gold rule under it
    band = Image.new("RGBA", (WIDTH, BAND))
    for y in range(BAND):
        alpha = BAND_TOP + (BAND_BOTTOM - BAND_TOP) * y / (BAND - 1)
        ImageDraw.Draw(band).line([(0, y), (WIDTH, y)], fill=(0, 0, 0, round(alpha * 255)))
    image.alpha_composite(band)
    ImageDraw.Draw(image).line([(0, BAND), (WIDTH, BAND)], fill=RULE + (255,), width=2)

    x = (WIDTH - width) // 2 - left
    y = (BAND - height) // 2 - top
    # a soft shadow, the outline, then the letters filled with the gold gradient
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + 2, y + 3), text, font=font, fill=(0, 0, 0, 200))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(3)))
    ImageDraw.Draw(image).text((x, y), text, font=font, fill=OUTLINE + (255,),
                               stroke_width=2, stroke_fill=OUTLINE + (255,))
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
    gold = Image.new("RGBA", image.size, (0, 0, 0, 0))
    gold.paste(gradient(width, height), (x + left, y + top))
    image.paste(gold, (0, 0), mask)
    save(image, dst)


def main(args):
    if len(args) < 3:
        fail(__doc__.split("\n\n")[1])
    command, src, dst, rest = args[0], args[1], args[2], args[3:]
    if not os.path.isfile(src):
        fail("no such file: " + src)
    if command == "fit":
        fit(src, dst, rest)
    elif command == "blur":
        blur(src, dst, rest)
    elif command == "title":
        if len(rest) != 1:
            fail('title takes one argument, the title in quotes')
        title(src, dst, rest[0])
    else:
        fail("unknown command: " + command)


if __name__ == "__main__":
    main(sys.argv[1:])
