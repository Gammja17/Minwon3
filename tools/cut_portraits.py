"""VARCO에서 받은 2x2 표정 시트를 표정별 PNG로 자른다.

사용: python tools/cut_portraits.py <시트.png> <이름>
  시트 배치: 왼쪽 위 보통, 오른쪽 위 화남, 왼쪽 아래 슬픔, 오른쪽 아래 웃음
  결과: assets/portraits/<이름>_normal.png 등 (마젠타 배경은 투명, 256x256)
"""
import os
import sys

from PIL import Image

MOODS = ["normal", "angry", "sad", "happy"]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "portraits")
SIZE = 256


def key_magenta(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            # 마젠타(#FF00FF)와 그 주변 번진 색을 투명하게
            if r > 150 and b > 150 and g < 110 and abs(r - b) < 90:
                px[x, y] = (0, 0, 0, 0)
    return im


def main() -> None:
    sheet = Image.open(sys.argv[1]).convert("RGB")
    name = sys.argv[2]
    os.makedirs(OUT, exist_ok=True)
    w, h = sheet.size
    cw, ch = w // 2, h // 2
    for i, mood in enumerate(MOODS):
        cx, cy = (i % 2) * cw, (i // 2) * ch
        cell = sheet.crop((cx, cy, cx + cw, cy + ch))
        cell = key_magenta(cell).resize((SIZE, SIZE), Image.NEAREST)
        cell.save(os.path.join(OUT, f"{name}_{mood}.png"))
    print("ok", name)


if __name__ == "__main__":
    main()
