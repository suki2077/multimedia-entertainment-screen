from pathlib import Path
import json,struct,sys
p=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(p/'tools'))
from prepare_titles import encode_pack
src=p/'sim/fixtures/shared'
lbas=[int(s,16) for s in (src/'lbas.hex').read_text().split()]
raw=bytes.fromhex((src/'data.hex').read_text());disk={lba:bytearray(raw[i*512:(i+1)*512]) for i,lba in enumerate(lbas)}
meta=json.loads((src/'meta.json').read_text());volume=meta['base'];b=disk[volume]
reserved=struct.unpack_from('<H',b,14)[0];fat_size=struct.unpack_from('<I',b,36)[0]
fat=volume+reserved;data=fat+b[16]*fat_size;assert b[13]==1
flags=struct.unpack_from('<H',b,40)[0];activefat=fat+((flags&15)*fat_size if flags&128 else 0)
c=struct.unpack_from('<I',b,44)[0]
while True:
 root=disk[data+c-2];free=next((i for i in range(16) if root[i*32] in (0,0xe5)),None)
 if free is not None:break
 c=struct.unpack_from('<I',disk[activefat+c//128],c%128*4)[0]&0xfffffff
 assert c<0xffffff8
assert free<15
pack,_=encode_pack([(0,'长标题音乐播放测试-Let Go.WAV',b'MUSIC   WAV')],Path('C:/Windows/Fonts/simhei.ttf'))
for i in range(9):
 c=30000+i*2;disk[data+c-2]=bytearray(pack[i*512:(i+1)*512])
 for copy in range(b[16]):
  sec=disk.setdefault(fat+copy*fat_size+c//128,bytearray(512))
  struct.pack_into('<I',sec,(c%128)*4,c+2 if i<8 else 0xfffffff)
entry=bytearray(32);entry[:11]=b'TITLES  BIN';struct.pack_into('<H',entry,26,30000);struct.pack_into('<I',entry,28,4608)
was_end=root[free*32]==0
root[free*32:(free+1)*32]=entry
if was_end:root[(free+1)*32:(free+2)*32]=bytes(32)
out=p/'sim/fixtures/title_music';out.mkdir(exist_ok=True)
(out/'lbas.hex').write_text(''.join(f'{n:08x}\n' for n in sorted(disk)))
(out/'data.hex').write_text(''.join(f'{v:02x}\n' for n in sorted(disk) for v in disk[n]))
(out/'meta.json').write_text(json.dumps(dict(count=len(disk)))+'\n')
s=(p/'sim/tb_album20_music.sv').read_text().replace('tb_album20_music','tb_title_music').replace('sim/fixtures/shared/','sim/fixtures/title_music/').replace('build/album20_music.txt','build/title_music.txt')
s=s.replace('fat32_media_stream #(.IO_TIMEOUT(1000000))','fat32_media_stream #(.IO_TIMEOUT(1000000),.SELECTABLE(1),.TITLES(1))')
s=s.replace('wire sample_valid,sample_ready,','wire title_commit;integer title_commits=0;\n wire sample_valid,sample_ready,')
s=s.replace('.sample_data(sample),.done(adone)',".selected_file(3'd0),.title_commit(title_commit),.sample_data(sample),.done(adone)")
s=s.replace('if(!rst)begin\n   if(ifail', 'if(!rst)begin\n   if(title_commit)title_commits<=title_commits+1;\n   if(ifail')
s=s.replace('if(loops<2)$fatal', 'if(title_commits<2)$fatal(1,"missing title reload loops");\n    if(loops<2)$fatal')
s=s.replace('PASS 20-capable catalog scan then SCALE+MUSIC:', 'PASS dynamic-title reloads with 20-capable catalog scan then SCALE+MUSIC:')
(p/'sim/tb_title_music.sv').write_text(s)
print('Prepared title+photo+music fixture',len(disk))
