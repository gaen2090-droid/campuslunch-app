#!/usr/bin/env python3
"""Play 스토어 '앱 소개용 그래픽 이미지'(feature graphic) 생성.

규격: 1024 x 500 PNG (Play Console 고정 크기)
구성: 좌측 절반 앱 로고 / 우측 절반 온보딩 1페이지 문구
      (문구는 usage_guide_screen.dart 1페이지와 동일, '중앙대' -> '대학교')

실행: python3 tool/generate_play_feature_graphic.py
출력: docs/play_store/feature_graphic_1024x500.png
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "assets/icon/app_icon_source.png"
FONTS = ROOT / "assets/fonts"
OUT = ROOT / "docs/play_store/feature_graphic_1024x500.png"

W, H = 1024, 500

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GRAY = (107, 114, 128)
LINE = (229, 231, 235)

TITLE = ["실시간 혼잡도를", "한눈에 확인해요"]
SUBTITLE = ["대학교 주변 매장의 혼잡도를 확인하고", "지금 바로 입장 가능한 곳을 찾아보세요"]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def draw_lines(draw, lines, x, y, fnt, fill, line_height):
    for line in lines:
        draw.text((x, y), line, font=fnt, fill=fill)
        y += line_height
    return y


def main() -> None:
    canvas = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(canvas)

    # ── 좌측: 로고 ──
    # 알파 채널이 있으므로 흰 배경에 합성한 뒤 리사이즈한다.
    logo_size = 300
    logo = Image.open(ICON).convert("RGBA")
    flat = Image.new("RGBA", logo.size, WHITE + (255,))
    flat.alpha_composite(logo)
    logo = flat.convert("RGB").resize((logo_size, logo_size), Image.LANCZOS)
    canvas.paste(logo, ((W // 2 - logo_size) // 2, (H - logo_size) // 2))

    # ── 가운데 구분선 ──
    draw.line([(W // 2, 90), (W // 2, H - 90)], fill=LINE, width=2)

    # ── 우측: 문구 ──
    title_font = font("Pretendard-ExtraBold.otf", 46)
    sub_font = font("Pretendard-Medium.otf", 22)

    title_lh, sub_lh = 62, 34
    block_h = len(TITLE) * title_lh + 18 + len(SUBTITLE) * sub_lh
    x = W // 2 + 56
    y = (H - block_h) // 2

    y = draw_lines(draw, TITLE, x, y, title_font, BLACK, title_lh)
    draw_lines(draw, SUBTITLE, x, y + 18, sub_font, GRAY, sub_lh)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, "PNG", optimize=True)
    print(f"생성 완료: {OUT} ({canvas.width}x{canvas.height})")


if __name__ == "__main__":
    main()
