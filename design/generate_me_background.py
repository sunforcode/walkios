"""程序化绘制「我的」页背景图（1206x2622 @3x）。

底色渐变严格取自 WalkDesignSystem token：
  pageOuter  #0D1F18 (13,31,24)
  pageMiddle #07130F (7,19,15)
  pageBase   #050B08 (5,11,8)
装饰层：顶部嵌套等高线族（随高度淡出）+ 底部山脊剪影，均为低对比。
"""
from PIL import Image, ImageDraw
import math

W, H = 1206, 2622

PAGE_OUTER = (13, 31, 24)   # #0d1f18
PAGE_MIDDLE = (7, 19, 15)   # #07130f
PAGE_BASE = (4, 12, 8)      # #040c08


def base_color(y: float) -> tuple[int, int, int]:
    t = y / H
    if t < 0.46:
        k = t / 0.46
        return tuple(round(a + (b - a) * k) for a, b in zip(PAGE_OUTER, PAGE_MIDDLE))
    k = (t - 0.46) / 0.54
    return tuple(round(a + (b - a) * k) for a, b in zip(PAGE_MIDDLE, PAGE_BASE))


img = Image.new("RGB", (W, H))
px = img.load()
for y in range(H):
    c = base_color(y)
    for x in range(W):
        px[x, y] = c


def contour_wave(x: float) -> float:
    """整族等高线共享的同一条地形波形（保证嵌套平行、不交叉）。"""
    return (
        math.sin(x * 0.0016 + 0.7) * 210
        + math.sin(x * 0.0041 + 2.9) * 70
        + math.sin(x * 0.0093 + 5.2) * 18
    )


# 顶部等高线族：同一波形、逐层向下发散（山脊等高线的嵌套感）
CONTOUR_END = H * 0.32
LINE_COLOR = (56, 99, 78)
LINES = 30
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
for i in range(LINES):
    t = i / (LINES - 1)
    y_base = H * 0.015 + t * (CONTOUR_END - H * 0.015)
    # 越往下层，波形放大 → 线间距先密后疏，接近真实山体等高线
    amp = 0.35 + t * 1.25
    alpha = round(30 * (1 - t) ** 1.2 + 6)
    points = []
    for x in range(-20, W + 21, 10):
        y = y_base + contour_wave(x) * amp * (y_base / CONTOUR_END + 0.25)
        points.append((x, y))
    od.line(points, fill=LINE_COLOR + (alpha,), width=3, joint="curve")

img = Image.alpha_composite(img.convert("RGBA"), overlay)


def ridge(y_at_center: float, amp: float, seed: float) -> list[tuple[float, float]]:
    pts = []
    for x in range(-10, W + 11, 8):
        y = (
            y_at_center
            + math.sin(x * 0.0021 + seed) * amp
            + math.sin(x * 0.0057 + seed * 2.1) * amp * 0.35
        )
        pts.append((x, y))
    return pts


ridge_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(ridge_layer)
rd.polygon(ridge(H * 0.93, 48, 1.3) + [(W + 20, H + 20), (-20, H + 20)], fill=(17, 36, 28, 255))
rd.polygon(ridge(H * 0.966, 34, 4.1) + [(W + 20, H + 20), (-20, H + 20)], fill=(11, 24, 19, 255))
img = Image.alpha_composite(img, ridge_layer)

img.convert("RGB").save("/Users/sunyongji/Develop/walk/walkios/design/me-page-background.png", "PNG")
print("done")
