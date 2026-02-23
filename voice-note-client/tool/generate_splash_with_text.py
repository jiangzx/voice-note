#!/usr/bin/env python3
"""Generate assets/splash/logo.png with mark + tagline. Run from voice-note-client: python3 tool/generate_splash_with_text.py. Needs: pip install -r tool/requirements.txt."""

import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Need Pillow: pip install -r tool/requirements.txt", file=sys.stderr)
    sys.exit(1)

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO_PATH = os.path.join(BASE, "assets", "splash", "logo.png")
TAGLINE = "AI 懂你说的，记账更轻松"
W, H = 864, 1024
# 文案置于 logo 下方白区，居中；logo 占 0~864，白区 864~1024
LOGO_H = 864
FONT_SIZE = 48
TEXT_COLOR = (29, 33, 41)   # #1D2129 主文案，对比度更高
FONT_COLOR_SUBTLE = (78, 89, 105)  # #4E5969 备用

def main():
    os.chdir(BASE)
    if not os.path.isdir("assets/splash"):
        print("Run from voice-note-client directory.", file=sys.stderr)
        sys.exit(1)

    # Load existing logo (864x864 with mark only) or create white 864x864
    if os.path.isfile(LOGO_PATH):
        logo = Image.open(LOGO_PATH).convert("RGB")
        if logo.size != (864, 864):
            logo = logo.resize((864, 864), Image.Resampling.LANCZOS)
    else:
        logo = Image.new("RGB", (864, 864), (255, 255, 255))

    out = Image.new("RGB", (W, H), (255, 255, 255))
    out.paste(logo, (0, 0))

    draw = ImageDraw.Draw(out)
    # 优先使用稍粗字体，企业级观感；TTC 需传 index（0=Regular, 1=Medium 等，视系统而定）
    font_paths = [
        ("/System/Library/Fonts/PingFang.ttc", 0),
        ("/System/Library/Fonts/Supplemental/PingFang.ttc", 0),
        ("/System/Library/Fonts/Supplemental/Songti.ttc", 0),
        ("/Library/Fonts/Arial Unicode.ttf", 0),
    ]
    font = None
    for path, index in font_paths:
        if os.path.isfile(path):
            try:
                font = ImageFont.truetype(path, FONT_SIZE, index=index)
                break
            except Exception:
                try:
                    font = ImageFont.truetype(path, FONT_SIZE)
                    break
                except Exception:
                    continue
    if font is None:
        font = ImageFont.load_default()

    # 文案水平居中；垂直置于 logo 下方白区居中（864~1024）
    bbox = draw.textbbox((0, 0), TAGLINE, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    band_height = H - LOGO_H
    text_y = LOGO_H + (band_height - th) // 2
    x = (W - tw) // 2
    draw.text((x, text_y), TAGLINE, fill=TEXT_COLOR, font=font)

    out.save(LOGO_PATH, "PNG")
    print(f"Wrote {LOGO_PATH} ({W}x{H})")

if __name__ == "__main__":
    main()
