"""VARCO에서 받은 2x2 도전 과제 아이콘 시트를 아이콘 네 장으로 자른다.

사용: python tools/cut_icons.py <시트.png> <왼쪽위 id> <오른쪽위 id> <왼쪽아래 id> <오른쪽아래 id>
결과: store/achievements/<id>.png (128x128, 마젠타 배경은 투명)
"""
import os
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "store", "achievements")
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
    ids = sys.argv[2:6]
    os.makedirs(OUT, exist_ok=True)
    cw, ch = sheet.width // 2, sheet.height // 2
    for i, name in enumerate(ids):
        cx, cy = (i % 2) * cw, (i // 2) * ch
        cell = key_magenta(sheet.crop((cx, cy, cx + cw, cy + ch)))
        box = cell.getbbox()
        if box:
            cell = cell.crop(box)
        side = max(cell.size)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
        sq.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
        print("ok", name)


if __name__ == "__main__":
    main()
