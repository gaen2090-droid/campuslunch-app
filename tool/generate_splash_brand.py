#!/usr/bin/env python3
"""스플래시 이미지 생성 — iOS/Android/Flutter 공통.

  python3 tool/generate_splash_brand.py

산출물:
  assets/images/splash_brand.png      — 아이콘+문구 (투명 배경)
  assets/images/splash_screen_full.png — 테마 배경 포함 풀스크린
  ios/.../LaunchImage*.png            — 네이티브 런치 (풀스크린)
  android/.../splash_screen_full.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICON_SRC = ROOT / "assets/icon/app_icon_source.png"
FONT_TITLE = ROOT / "assets/fonts/Pretendard-Black.otf"
FONT_TAG = ROOT / "assets/fonts/Pretendard-Medium.otf"
OUT_BRAND = ROOT / "assets/images/splash_brand.png"
OUT_FULL = ROOT / "assets/images/splash_screen_full.png"
IOS_SET = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
ANDROID_DRAWABLE = ROOT / "android/app/src/main/res/drawable-nodpi"

# Flutter splash_screen.dart 레이아웃 (1x pt)
ICON_PT = 72
GAP_TITLE_PT = 20
GAP_TAG_PT = 8
TITLE_PT = 30
TAG_PT = 14
PAD_BOTTOM_PT = 12
PAD_TOP_PT = 4
TITLE = "캠퍼스런치"
TAGLINE = "지금 어디가 여유로울까?"
TITLE_COLOR = (0x5E, 0x8C, 0x4A, 0xFF)
TAG_COLOR = (0x9C, 0xA3, 0xAF, 0xFF)
ICON_RADIUS_PT = 22

# 풀스크린 (iPhone 14 논리 해상도)
SCREEN_W_PT = 393
SCREEN_H_PT = 852
BRAND_OFFSET_Y_PT = -28


def _round_icon(icon: Image.Image, radius: int) -> Image.Image:
    icon = icon.convert("RGBA")
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, icon.width, icon.height), radius=radius, fill=255
    )
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out


def _text_block(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    y: int,
    canvas_w: int,
    color: tuple[int, int, int, int],
) -> int:
    """텍스트를 그리고 다음 y 반환. bbox 오프셋 보정으로 잘림 방지."""
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (canvas_w - tw) // 2 - bbox[0]
    draw.text((x, y - bbox[1]), text, font=font, fill=color)
    return y + th


def render_brand(scale: int) -> Image.Image:
    icon_px = ICON_PT * scale
    gap1 = GAP_TITLE_PT * scale
    gap2 = GAP_TAG_PT * scale
    title_px = TITLE_PT * scale
    tag_px = TAG_PT * scale
    pad_b = PAD_BOTTOM_PT * scale
    pad_t = PAD_TOP_PT * scale
    radius = ICON_RADIUS_PT * scale

    icon = _round_icon(
        Image.open(ICON_SRC).resize((icon_px, icon_px), Image.Resampling.LANCZOS),
        radius,
    )
    title_font = ImageFont.truetype(str(FONT_TITLE), title_px)
    tag_font = ImageFont.truetype(str(FONT_TAG), tag_px)

    probe = Image.new("RGBA", (1, 1))
    draw_probe = ImageDraw.Draw(probe)
    tb = draw_probe.textbbox((0, 0), TITLE, font=title_font)
    gb = draw_probe.textbbox((0, 0), TAGLINE, font=tag_font)
    title_w = tb[2] - tb[0]
    tag_w = gb[2] - gb[0]

    width = max(icon_px, title_w, tag_w) + 8 * scale
    content_h = icon_px + gap1 + (tb[3] - tb[1]) + gap2 + (gb[3] - gb[1])
    height = pad_t + content_h + pad_b
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    y = pad_t
    icon_x = (width - icon_px) // 2
    canvas.paste(icon, (icon_x, y), icon)
    y += icon_px + gap1
    y = _text_block(draw, TITLE, title_font, y, width, TITLE_COLOR)
    y += gap2
    _text_block(draw, TAGLINE, tag_font, y, width, TAG_COLOR)
    return canvas


def render_full_screen(scale: int) -> Image.Image:
    w = SCREEN_W_PT * scale
    h = SCREEN_H_PT * scale
    canvas = Image.new("RGB", (w, h), (255, 255, 255))

    brand = render_brand(scale)
    bx = (w - brand.width) // 2
    by = (h - brand.height) // 2 + BRAND_OFFSET_Y_PT * scale
    canvas.paste(brand, (bx, by), brand)
    return canvas


def main() -> None:
    for p in (ICON_SRC, FONT_TITLE, FONT_TAG):
        if not p.exists():
            raise SystemExit(f"Missing: {p}")

    brand = render_brand(scale=1)
    OUT_BRAND.parent.mkdir(parents=True, exist_ok=True)
    brand.save(OUT_BRAND)
    print(f"Wrote {OUT_BRAND} ({brand.size[0]}x{brand.size[1]})")

    full = render_full_screen(scale=1)
    full.save(OUT_FULL)
    print(f"Wrote {OUT_FULL} ({full.size[0]}x{full.size[1]})")

    IOS_SET.mkdir(parents=True, exist_ok=True)
    for name, scale in [
        ("LaunchImage.png", 1),
        ("LaunchImage@2x.png", 2),
        ("LaunchImage@3x.png", 3),
    ]:
        img = render_full_screen(scale=scale)
        path = IOS_SET / name
        img.save(path)
        print(f"Wrote {path} ({img.size[0]}x{img.size[1]})")

    ANDROID_DRAWABLE.mkdir(parents=True, exist_ok=True)
    android_path = ANDROID_DRAWABLE / "splash_screen_full.png"
    render_full_screen(scale=3).save(android_path)
    print(f"Wrote {android_path}")


if __name__ == "__main__":
    main()
