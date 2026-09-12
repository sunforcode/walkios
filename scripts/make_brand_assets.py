#!/usr/bin/env python3
"""Generate Walk brand assets: App Icon (light/dark/tinted) and Launch Image.

Colors and geometry derive from the product design language:
- NightRidgeScene (PAGE-LOGIN): double mountain silhouettes + glowing mint route.
- Color+App.swift tokens: pageBase #040C08, pageMiddle #07130F, pageOuter #0D1F18,
  surfaceElevated #173126, interactionPrimary (mint) #8BD6AD, textSecondary #B8C2BD.

Outputs are written directly into Walk/Assets.xcassets.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Walk", "Assets.xcassets")

PAGE_BASE = (4, 12, 8)        # #040C08
PAGE_OUTER = (13, 31, 24)     # #0D1F18
SURFACE_ELEVATED = (23, 49, 38)  # #173126
SURFACE_PRIMARY = (16, 35, 27)   # #10231B
MINT = (139, 214, 173)        # #8BD6AD
TEXT_SECONDARY = (184, 194, 189)  # #B8C2BD
WHITE = (255, 255, 255)

# Grayscale mapping for the iOS 18 tinted icon slot.
TINT_BG_TOP = (26, 26, 26)
TINT_BG_BOTTOM = (0, 0, 0)
TINT_FAR = (95, 95, 95)
TINT_NEAR = (16, 16, 16)
TINT_ROUTE = (242, 242, 242)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient(size, top_right, bottom_left):
    """Diagonal gradient, dark at bottom-left, lighter at top-right."""
    small = 64
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = lerp(bottom_left, top_right, t)
    return img.resize(size, Image.BILINEAR)


def cubic(p0, c1, c2, p1, steps=120):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * c1[0] + 3 * mt * t**2 * c2[0] + t**3 * p1[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * c1[1] + 3 * mt * t**2 * c2[1] + t**3 * p1[1]
        pts.append((x, y))
    return pts


def draw_route(draw, start, mid, end, width, color):
    """S-curve route: start (bottom-left) -> mid -> end (top-right).

    Rendered by stamping overlapping discs along the path (smooth, no joint
    artifacts) plus explicit round caps.
    """
    seg1 = cubic(start, (start[0] + (mid[0] - start[0]) * 0.45, start[1] - 8),
                 (mid[0] - 90, mid[1] + 95), mid)
    seg2 = cubic(mid, (mid[0] + 92, mid[1] - 90),
                 (end[0] - (end[0] - mid[0]) * 0.25, end[1] + 110), end)
    pts = seg1 + seg2
    r = width / 2
    for x, y in pts:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)
    for p in (pts[0], pts[-1]):
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def make_icon(variant="light"):
    s = 1024
    img = Image.new("RGBA", (s, s))

    if variant == "light":
        base = diagonal_gradient((s, s), PAGE_OUTER, PAGE_BASE).convert("RGBA")
    elif variant == "dark":
        base = Image.new("RGBA", (s, s), PAGE_BASE + (255,))
    else:  # tinted (grayscale)
        base = diagonal_gradient((s, s), TINT_BG_TOP, TINT_BG_BOTTOM).convert("RGBA")
    img.alpha_composite(base)

    far_color = SURFACE_ELEVATED if variant != "tinted" else TINT_FAR
    near_color = PAGE_BASE if variant != "tinted" else TINT_NEAR
    route_color = MINT if variant != "tinted" else TINT_ROUTE

    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Far mountain range (muted elevated green, gentle twin ridges).
    d.polygon([(-40, 1024), (-40, 660), (200, 430), (450, 640),
               (700, 400), (1064, 610), (1064, 1024)],
              fill=far_color + (199,))
    # Near mountain range (near-black, pushes composition forward).
    d.polygon([(-40, 1024), (-40, 830), (260, 620), (560, 810),
               (820, 640), (1064, 760), (1064, 1024)],
              fill=near_color + (245,))
    img.alpha_composite(layer)

    # Route glow halo behind the end node only (restrained, per spec).
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([830 - 90, 270 - 90, 830 + 90, 270 + 90], fill=MINT + (80,))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    img.alpha_composite(glow)

    route = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rd = ImageDraw.Draw(route)
    draw_route(rd, (160, 880), (540, 660), (830, 270), 32, route_color + (255,))
    # Start node (solid) and end node (solid, on top of halo).
    rd.ellipse([160 - 30, 880 - 30, 160 + 30, 880 + 30], fill=route_color + (255,))
    rd.ellipse([830 - 30, 270 - 30, 830 + 30, 270 + 30], fill=route_color + (255,))
    img.alpha_composite(route)

    return img.convert("RGB")


def tracked_text(draw, pos, text, font, fill, tracking):
    x, y = pos
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking


def load_avenue(size, want_bold=True):
    path = "/System/Library/Fonts/Avenir Next.ttc"
    fallback = "/System/Library/Fonts/Helvetica.ttc"
    for p in (path, fallback):
        if not os.path.exists(p):
            continue
        for index in range(12):
            try:
                f = ImageFont.truetype(p, size, index=index)
                name = f.getname()[1]
                if want_bold and name in ("Bold", "Heavy", "Demi Bold"):
                    return f
                if not want_bold and name in ("Regular", "Roman", "Medium"):
                    return f
            except Exception:
                break
    return ImageFont.load_default()


def make_launch_image():
    w, h = 1290, 2796
    img = Image.new("RGB", (w, h), PAGE_BASE)

    # Brand line, top-left, inside safe area on all current devices.
    walk_font = load_avenue(72, want_bold=True)
    kicker_font = load_avenue(30, want_bold=False)
    d = ImageDraw.Draw(img)
    tracked_text(d, (96, 268), "Walk", walk_font, WHITE, 10)
    tracked_text(d, (99, 372), "ROUTE 01 · PERSONAL JOURNEY", kicker_font,
                 TEXT_SECONDARY, 6)

    # Bottom watermark: mountains + route at 25% opacity.
    wm = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wm)
    wd.polygon([(0, 2560), (0, 2320), (300, 2050), (620, 2280),
                (950, 2020), (1290, 2240), (1290, 2560)],
               fill=SURFACE_ELEVATED + (255,))
    wd.polygon([(0, 2560), (0, 2420), (380, 2200), (760, 2430),
                (1290, 2300), (1290, 2560)],
               fill=SURFACE_PRIMARY + (255,))
    draw_route(wd, (180, 2450), (640, 2320), (1080, 2120), 16, MINT + (255,))
    wd.ellipse([180 - 14, 2450 - 14, 180 + 14, 2450 + 14], fill=MINT + (255,))
    wd.ellipse([1080 - 14, 2120 - 14, 1080 + 14, 2120 + 14], fill=MINT + (255,))
    wm = wm.point(lambda v: v)  # keep alpha channel
    r, g, b, a = wm.split()
    a = a.point(lambda v: int(v * 0.25))
    wm = Image.merge("RGBA", (r, g, b, a))
    img = img.convert("RGBA")
    img.alpha_composite(wm)

    return img.convert("RGB")


def write_assets():
    iconset = os.path.join(ASSETS, "AppIcon.appiconset")
    launchset = os.path.join(ASSETS, "LaunchImage.imageset")
    colorset = os.path.join(ASSETS, "LaunchBackground.colorset")
    for p in (iconset, launchset, colorset):
        os.makedirs(p, exist_ok=True)

    make_icon("light").save(os.path.join(iconset, "AppIcon.png"))
    make_icon("dark").save(os.path.join(iconset, "AppIconDark.png"))
    make_icon("tinted").save(os.path.join(iconset, "AppIconTinted.png"))
    make_launch_image().save(os.path.join(launchset, "LaunchImage.png"))
    print("assets written to", ASSETS)


if __name__ == "__main__":
    write_assets()
