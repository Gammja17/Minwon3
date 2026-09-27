"""VARCO에서 받은 2x2 책상 소품 시트를 소품 네 장으로 자른다.

사용: python tools/cut_props.py <시트.png> <왼쪽위> <오른쪽위> <왼쪽아래> <오른쪽아래>
  이름이 _ 이면 그 칸은 건너뛴다.
결과: assets/ui/desk_<이름>.png (마젠타 배경은 투명, 긴 변 128px)
"""
import os
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
SIZE = 128


def key_magenta(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if r > 150 and b > 150 and g < 110 and abs(r - b) < 90:
                px[x, y] = (0, 0, 0, 0)
    return im


def main() -> None:
    sheet = Image.open(sys.argv[1]).convert("RGB")
    cw, ch = sheet.width // 2, sheet.height // 2
    for i, name in enumerate(sys.argv[2:6]):
        if name == "_":
            continue
        cx, cy = (i % 2) * cw, (i // 2) * ch
        cell = key_magenta(sheet.crop((cx, cy, cx + cw, cy + ch)))
        box = cell.getbbox()
        if box:
            cell = cell.crop(box)
        cell.thumbnail((SIZE, SIZE), Image.LANCZOS)
        cell.save(os.path.join(OUT, "desk_%s.png" % name))
        print("ok", name, cell.size)


if __name__ == "__main__":
    main()
