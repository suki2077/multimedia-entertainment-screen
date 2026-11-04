"""Rebuild the bounded player font ROM; generated HEX is included for normal builds."""
from pathlib import Path
import argparse,json
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent.parent
ap=argparse.ArgumentParser();ap.add_argument('--font',default='C:/Windows/Fonts/msyh.ttc');a=ap.parse_args()
chars=json.loads((p/'tools/player_zh_chars.json').read_text(encoding='utf8'))['characters']
assert len(chars)<=64
font=ImageFont.truetype(a.font,14);rows=[]
for c in chars.ljust(64):
 im=Image.new('1',(16,16));d=ImageDraw.Draw(im);box=d.textbbox((0,0),c,font=font)
 d.text(((16-box[2]+box[0])//2-box[0],(16-box[3]+box[1])//2-box[1]),c,font=font,fill=1)
 rows+=['%04x'%sum(im.getpixel((x,y))<<(15-x) for x in range(16)) for y in range(16)]
(p/'rtl/player_zh_font.hex').write_text('\n'.join(rows)+'\n')
