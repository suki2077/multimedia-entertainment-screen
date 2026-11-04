"""Regenerate both shared game ROMs; no external font dependency."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parent.parent/'rtl'
s=(root/'arcade_renderer.v').read_text()
chars={int(c):bits for c,bits in re.findall(r"8'd(\d+):glyph=35'b([01]+)",s)}
font=[0]*4096
for c,bits in chars.items():
 for row in range(7):
  for col in range(1,6):font[((c&63)<<6)|(row<<3)|col]=int(bits[row*5+col-1])
(root/'arcade_pixel_font.hex').write_text(''.join(f'{x:x}\n' for x in font))
texts=json.loads((root/'arcade_texts.json').read_text());rom=[]
for k,v in texts.items():
 expected=f"6'd{k}:text_span={{10'd{len(rom)},6'd{len(v)}}};"
 assert expected in s, 'Update text_span offsets/lengths when changing text'
 rom.extend(v)
assert len(rom)<=1024
(root/'arcade_text_rom.hex').write_text(''.join(f'{ord(c):02x}\n' for c in rom)+'20\n'*(1024-len(rom)))
print(f'{len(chars)} glyphs, {len(rom)} text bytes; two shared BRAM9K blocks')
