"""SKEAM 상점 그림: 게임 스크린샷 위에 제목을 얹는다.

사용: python tools/store_art.py <스크린샷 폴더>   (tools/shot.gd 로 찍은 PNG들)
결과: store/header.jpg(920x430), capsule.jpg(600x900), hero.jpg(1920x620), screenshots/1~5.jpg
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "store")
PIX = os.path.join(ROOT, "assets", "fonts", "Mulmaru.woff2")
BOLD = os.path.join(ROOT, "assets", "fonts", "Pretendard-SemiBold.woff2")
GOLD = (255, 219, 140)
CREAM = (255, 243, 220)
DARK = (28, 18, 10)
RED = (200, 40, 32)
TITLE = "민원실 3번 창구"


def cover(im, w, h, fy=0.5):
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = int((im.height - h) * fy)
    return im.crop((x, y, x + w, y + h))


def shade_left(im, strength=0.85, reach=0.62):
    """왼쪽을 어둡게 해서 글씨가 잘 보이게"""
    w, h = im.size
    g = Image.new("L", (w, 1))
    for x in range(w):
        t = max(0.0, 1.0 - x / (w * reach))
        g.putpixel((x, 0), int(255 * strength * t))
    mask = g.resize((w, h))
    dark = Image.new("RGB", im.size, (14, 10, 8))
    return Image.composite(dark, im, mask)


def text(d, xy, s, font, fill, outline=6, anchor="la"):
    d.text(xy, s, font=font, fill=fill, anchor=anchor, stroke_width=outline, stroke_fill=DARK)


def stamp(word, size, angle):
    """빨간 도장 자국"""
    f = ImageFont.truetype(PIX, size)
    bb = f.getbbox(word)
    pad = size // 4
    w, h = bb[2] - bb[0] + pad * 2, bb[3] - bb[1] + pad * 2
    im = Image.new("RGBA", (w + 8, h + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 4, w + 4, h + 4), radius=size // 5, outline=RED + (235,), width=max(4, size // 10))
    d.text((4 + pad - bb[0], 4 + pad - bb[1]), word, font=f, fill=RED + (235,))
    return im.rotate(angle, expand=True, resample=Image.BICUBIC)


def portrait(name, size):
    return Image.open(os.path.join(ROOT, "assets", "portraits", name + ".png")).convert("RGBA").resize((size, size), Image.NEAREST)


def main():
    shots = sys.argv[1]
    os.makedirs(os.path.join(OUT, "screenshots"), exist_ok=True)
    shot = lambda n: Image.open(os.path.join(shots, n + ".png")).convert("RGB")

    # header 920x430: 벽 앞의 화난 박달수 할아버지와 제목
    im = cover(Image.open(os.path.join(ROOT, "assets", "ui", "src", "wall.png")).convert("RGB"), 920, 430, 0.45)
    im = Image.blend(im, Image.new("RGB", im.size, (20, 16, 14)), 0.5)
    face = portrait("dalsu_angry", 430)
    im.paste(face, (500, 0), face)
    im = shade_left(im, 0.9, 0.6)
    d = ImageDraw.Draw(im)
    text(d, (44, 118), TITLE, ImageFont.truetype(PIX, 72), GOLD, 7)
    text(d, (50, 214), "진상은 먹금, 서류는 반려", ImageFont.truetype(PIX, 36), CREAM, 5)
    text(d, (52, 292), "주민센터 신규 주무관의 첫 2주", ImageFont.truetype(BOLD, 24), CREAM, 4)
    im.paste(s := stamp("반려", 58, 14), (720, 270), s)
    im.save(os.path.join(OUT, "header.jpg"), quality=92)

    # capsule 600x900: 화난 박달수 할아버지
    im = cover(Image.open(os.path.join(ROOT, "assets", "ui", "src", "wall.png")).convert("RGB"), 600, 900)
    im = Image.blend(im, Image.new("RGB", im.size, (20, 16, 14)), 0.55)
    face = Image.open(os.path.join(ROOT, "assets", "portraits", "dalsu_angry.png")).convert("RGBA").resize((560, 560), Image.NEAREST)
    im.paste(face, (20, 330), face)
    band = Image.new("RGBA", (600, 250), (14, 10, 8, 225))
    im.paste(band, (0, 0), band)
    d = ImageDraw.Draw(im)
    text(d, (300, 92), TITLE, ImageFont.truetype(PIX, 64), GOLD, 7, "mm")
    text(d, (300, 180), "진상은 먹금, 서류는 반려", ImageFont.truetype(PIX, 34), CREAM, 5, "mm")
    im.paste(s := stamp("반려", 70, -12), (330, 700), s)
    im.save(os.path.join(OUT, "capsule.jpg"), quality=92)

    # hero 1920x620: 책상 위에 줄 선 민원인들
    im = cover(Image.open(os.path.join(ROOT, "assets", "ui", "src", "wall.png")).convert("RGB"), 1920, 620, 0.5)
    im = Image.blend(im, Image.new("RGB", im.size, (20, 16, 14)), 0.45)
    counter = cover(Image.open(os.path.join(ROOT, "assets", "ui", "src", "desk.png")).convert("RGB"), 1920, 130)
    im.paste(counter, (0, 490))
    for k, (n, x) in enumerate([("soonja_sad", 880), ("jiwoo_happy", 1120), ("dalsu_angry", 1360), ("taemin_normal", 1620)]):
        f = portrait(n, 360 if n != "dalsu_angry" else 420)
        im.paste(f, (x - 30, 490 - f.height + 20), f)
    im = shade_left(im, 0.92, 0.5)
    d = ImageDraw.Draw(im)
    text(d, (110, 150), TITLE, ImageFont.truetype(PIX, 120), GOLD, 10)
    text(d, (118, 320), "진상은 먹금, 서류는 반려", ImageFont.truetype(PIX, 56), CREAM, 7)
    text(d, (122, 430), "서류를 대조하고, 도장을 쾅. 햇살동 주민센터 3번 창구의 2주", ImageFont.truetype(BOLD, 34), CREAM, 5)
    im.save(os.path.join(OUT, "hero.jpg"), quality=92)

    # 스크린샷
    for i, n in enumerate(["3b_stamped", "13_inspect_found", "4_office_hostile", "17_w2_lookup", "t2_compare"], 1):
        shot(n).save(os.path.join(OUT, "screenshots", f"{i}.jpg"), quality=92)
    print("ok")


if __name__ == "__main__":
    main()
