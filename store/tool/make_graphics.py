"""Google Play graphics for Crown & Blade.

Writes into store/graphics/:
  icon-512.png               512 x 512 Play icon (full square; Play rounds it)
  feature-graphic-en.png     1024 x 500 feature graphic, English
  feature-graphic-am.png     1024 x 500 feature graphic, Amharic

The icon redraws the Android launcher icon (android/app/src/main/res/
mipmap-*/ic_launcher.png: white scissors with a green pivot on the charcoal
hero gradient) as vector shapes, because the largest launcher PNG is only
192 px. Colours come from lib/core/theme/app_theme.dart.

The feature graphics put the first phone screenshot (store/screenshots/
01_customer_home.png, from test/store_screenshots_test.dart) in a phone frame
when it exists.

Fonts: Inter from build/store_cache/fonts (store/tool/fetch_screenshot_assets.sh)
or Segoe UI, and Noto Sans Ethiopic (or Nyala / Ebrima) for Amharic.

  python store/tool/make_graphics.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "store", "graphics")

# AppTheme
CHARCOAL = (0x2B, 0x2B, 0x2E)
CHARCOAL_DEEP = (0x11, 0x11, 0x13)
GREEN = (0x22, 0xB1, 0x4C)
WHITE = (255, 255, 255)
MUTED = (0xB4, 0xB4, 0xB8)

SS = 4  # supersampling


def font(candidates, size):
    for c in candidates:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


WIN_FONTS = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")
CACHE_FONTS = os.path.join(ROOT, "build", "store_cache", "fonts")
LATIN_BOLD = [os.path.join(CACHE_FONTS, "Inter-800.ttf"), os.path.join(CACHE_FONTS, "Inter-700.ttf"),
              os.path.join(WIN_FONTS, "segoeuib.ttf"), "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
LATIN_MEDIUM = [os.path.join(CACHE_FONTS, "Inter-500.ttf"), os.path.join(CACHE_FONTS, "Inter-400.ttf"),
                os.path.join(WIN_FONTS, "segoeui.ttf"), "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
LATIN_SEMI = [os.path.join(CACHE_FONTS, "Inter-600.ttf"), os.path.join(CACHE_FONTS, "Inter-700.ttf"),
              os.path.join(WIN_FONTS, "seguisb.ttf"), os.path.join(WIN_FONTS, "segoeuib.ttf")]
ETHIOPIC_BOLD = [os.path.join(WIN_FONTS, "NotoSansEthiopic-Bold.ttf"), os.path.join(WIN_FONTS, "ebrimabd.ttf"),
                 os.path.join(WIN_FONTS, "nyala.ttf")]
ETHIOPIC_MEDIUM = [os.path.join(WIN_FONTS, "NotoSansEthiopic-Medium.ttf"),
                   os.path.join(WIN_FONTS, "NotoSansEthiopic-Regular.ttf"), os.path.join(WIN_FONTS, "ebrima.ttf")]


def gradient(w, h, a=CHARCOAL, b=CHARCOAL_DEEP):
    """Top-left -> bottom-right linear gradient (AppTheme.heroGradient)."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img


def scissors(draw, cx, cy, s):
    """The launcher icon's scissors, drawn in a 192-unit box scaled by s,
    centred on (cx, cy) (the pivot)."""
    stroke = 9.5 * s
    ring_r = 15.75 * s
    rings = [(-33, -30), (-33, 29)]
    ends = [(50, -38), (50, 38)]

    def p(x, y):
        return cx + x * s, cy + y * s

    def dot(x, y, r, fill):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def line(a, b):
        draw.line([a, b], fill=WHITE, width=round(stroke))
        dot(*a, stroke / 2, WHITE)
        dot(*b, stroke / 2, WHITE)

    # Each blade runs from its tip through the pivot into the opposite ring.
    for (ex, ey), (rx, ry) in zip(ends, reversed(rings)):
        # Walk from the pivot away from the tip until the ring's centre line.
        dx, dy = -ex, -ey
        n = math.hypot(dx, dy)
        dx, dy = dx / n, dy / n
        t = 0.0
        while math.hypot(dx * t - rx, dy * t - ry) > 15.75 and t < 80:
            t += 0.25
        line(p(ex, ey), p(dx * t, dy * t))
    for rx, ry in rings:
        x, y = p(rx, ry)
        draw.ellipse([x - ring_r - stroke / 2, y - ring_r - stroke / 2, x + ring_r + stroke / 2, y + ring_r + stroke / 2],
                     outline=WHITE, width=round(stroke))
    x, y = p(0, 0)
    dot(x, y, 5.5 * s, GREEN)


def icon(size):
    big = size * SS
    img = gradient(big // 4, big // 4).resize((big, big), Image.BILINEAR)
    d = ImageDraw.Draw(img)
    scissors(d, big / 2, big / 2, big / 192)
    return img.resize((size, size), Image.LANCZOS)


def rounded_mask(w, h, r):
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], r * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def phone(screenshot_path, width):
    """A dark phone frame around the screenshot (or None)."""
    if not os.path.exists(screenshot_path):
        return None
    shot = Image.open(screenshot_path).convert("RGB")
    sw = width - 2 * round(width * 0.035)
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    bez = (width - sw) // 2
    h = sh + 2 * bez
    frame = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    body = Image.new("RGBA", (width, h), (0x05, 0x05, 0x06, 255))
    frame.paste(body, (0, 0), rounded_mask(width, h, round(width * 0.12)))
    frame.paste(shot, (bez, bez), rounded_mask(sw, sh, round(width * 0.09)))
    return frame


def feature_graphic(lang):
    w, h = 1024, 500
    img = gradient(w // 4, h // 4).resize((w, h), Image.BILINEAR).convert("RGBA")

    # Soft green glow behind the phone.
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([640, 40, 1040, 440], fill=GREEN + (70,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(90)))

    # Phone with the customer home screenshot, cut off by the bottom edge.
    ph = phone(os.path.join(ROOT, "store", "screenshots", "01_customer_home.png"), 300)
    if ph is not None:
        shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([700, 70, 1000, 600], 36, fill=(0, 0, 0, 150))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(24)))
        img.alpha_composite(ph, (690, 52))

    d = ImageDraw.Draw(img)
    # Icon tile.
    tile = icon(112)
    ring = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle([62, 62, 177, 177], 28, fill=(255, 255, 255, 38))
    img = Image.alpha_composite(img, ring)
    d = ImageDraw.Draw(img)
    img.paste(tile, (64, 64), rounded_mask(112, 112, 26))

    title = font(LATIN_BOLD, 64)
    d.text((64, 206), "Crown & Blade", font=title, fill=WHITE)
    if lang == "am":
        tag = font(ETHIOPIC_BOLD, 34)
        sub = font(ETHIOPIC_MEDIUM, 24)
        d.text((64, 292), "በአዲስ አበባ ፀጉር አስተካካይ ይያዙ", font=tag, fill=WHITE)
        d.text((64, 344), "ፀጉር ቤት፣ ፀጉር አስተካካይና ነፃ ሰዓት በሰከንዶች።", font=sub, fill=MUTED)
        pill_text, pill_font = "ቦሌ · ካዛንቺስ · ፒያሳ · ሳርቤት", font(ETHIOPIC_MEDIUM, 22)
    else:
        tag = font(LATIN_SEMI, 34)
        sub = font(LATIN_MEDIUM, 24)
        d.text((64, 292), "Book your barber in Addis Ababa", font=tag, fill=WHITE)
        d.text((64, 344), "Pick a shop, a barber and a free time in seconds.", font=sub, fill=MUTED)
        pill_text, pill_font = "Bole · Kazanchis · Piassa · Sarbet", font(LATIN_MEDIUM, 21)

    # Green pill.
    tw = d.textlength(pill_text, font=pill_font)
    x0, y0 = 64, 404
    d.rounded_rectangle([x0, y0, x0 + tw + 56, y0 + 44], 22, fill=GREEN)
    d.ellipse([x0 + 18, y0 + 17, x0 + 28, y0 + 27], fill=WHITE)
    d.text((x0 + 38, y0 + 22), pill_text, font=pill_font, fill=WHITE, anchor="lm")
    return img.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    icon(512).save(os.path.join(OUT, "icon-512.png"))
    for lang in ("en", "am"):
        feature_graphic(lang).save(os.path.join(OUT, f"feature-graphic-{lang}.png"))
    for f in sorted(os.listdir(OUT)):
        im = Image.open(os.path.join(OUT, f))
        print(f, im.size, im.mode)


if __name__ == "__main__":
    main()
