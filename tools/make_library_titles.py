"""Generate two bounded Chinese display titles, without a general Unicode font."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

p = Path(__file__).resolve().parent.parent
config = p / "tools/library_titles.json"
titles = json.loads(config.read_text(encoding="utf8"))["titles"] if config.exists() else ["唯一 邓紫棋", "再见 邓紫棋"]
assert len(titles) == 2, "This bounded ROM supports exactly two preset labels"
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 15)
words = []
preview = Image.new("RGB", (512, 128), "#142337")
for n, title in enumerate(titles):
    im = Image.new("L", (128, 16))
    draw = ImageDraw.Draw(im)
    box = draw.textbbox((0, 0), title, font=font)
    assert box[2] - box[0] <= 128, "Title exceeds the 128-pixel label area"
    draw.text((0, (16 - box[3] + box[1]) // 2 - box[1]), title, font=font, fill=255)
    for x in range(128):
        words.append(sum(min(3, (im.getpixel((x, y)) + 42) // 85) << (30 - 2*y) for y in range(16)))
    colored = Image.new("RGB", im.size, "#eaf1f7")
    preview.paste(colored.resize((384, 48)), (24, 8+n*64), im.resize((384, 48)))
(p / "rtl/library_titles.hex").write_text("".join(f"{part:04x}\n" for w in words for part in (w >> 16, w & 65535)), encoding="ascii")
(p / "preview/library_titles_font.png").parent.mkdir(exist_ok=True)
preview.save(p / "preview/library_titles_font.png")
(p / "tools/library_titles.json").write_text(json.dumps({"titles": titles, "scheme": "512x16 ROM; two 128x16, 2-bit coverage strips; 8192 bits total"}, ensure_ascii=False, indent=2)+"\n", encoding="utf8")
