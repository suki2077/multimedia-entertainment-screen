from pathlib import Path
import struct,sys
p=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(p/'tools'))
from prepare_titles import encode_pack
def put(b,o,f,*v):struct.pack_into('<'+f,b,o,*v)
def entry(name,c,size):
 b=bytearray(32);b[:11]=name;put(b,26,'H',c);put(b,28,'I',size);return b
disk={};b=bytearray(512);put(b,11,'H',512);b[13]=4;put(b,14,'H',32);b[16]=1;put(b,32,'I',300000);put(b,36,'I',600);put(b,44,'I',2);put(b,510,'H',0xaa55);disk[0]=b
fat=bytearray(4096);put(fat,8,'I',0xfffffff)
root=bytearray(512);root[:32]=entry(b'VIDEO   SAV',100,134144);root[32:64]=entry(b'TITLES  BIN',500,4608);disk[632]=root
head=bytearray(512);head[:8]=b'SUKIPL01';put(head,8,'6H',480,270,15,5,1,0);put(head,20,'I',133632);put(head,24,'I',24000);put(head,28,'HHI',1600,16,133632)
video=head+b''.join(struct.pack('<I',0x56780000+i) for i in range(33408))
chain=[100+i*2 for i in range(66)]
for j,c in enumerate(chain):
 put(fat,c*4,'I',chain[j+1] if j<65 else 0xfffffff)
 for sec in range(4):
  part=video[(j*4+sec)*512:(j*4+sec+1)*512]
  if part:disk[632+(c-2)*4+sec]=part
pack,_=encode_pack([(1,'我的视频-LetGo.SAV',b'VIDEO   SAV')],Path('C:/Windows/Fonts/simhei.ttf'))
for j,c in enumerate([500,702,504]):
 put(fat,c*4,'I',[702,504,0xfffffff][j])
 for sec in range(4):
  part=pack[(j*4+sec)*512:(j*4+sec+1)*512]
  if part:disk[632+(c-2)*4+sec]=part
for i in range(8):disk[32+i]=fat[i*512:(i+1)*512]
out=p/'sim/fixtures/title_prefetch';out.mkdir(exist_ok=True)
(out/'info.hex').write_text(f'{len(disk):08x}\n')
(out/'lbas.hex').write_text(''.join(f'{n:08x}\n' for n in disk))
(out/'data.hex').write_text(''.join(f'{v:02x}\n' for data in disk.values() for v in data))
expected=bytearray(4096);expected[:2048]=pack[512:2560];expected[2048]=pack[2561];expected[2049:2112]=pack[2564:2627]
(out/'expected.hex').write_text(''.join(f'{v:02x}\n' for v in expected))
s=(p/'sim/tb_dynamic_title_reader.sv').read_text().replace('tb_dynamic_title_reader','tb_title_prefetch')
s=s.replace('lbas[0:63]','lbas[0:511]').replace('disk[0:32767]','disk[0:262143]')
s=s.replace('writes!=2560','writes!=2112').replace("32'h12340000+selected*256+samples","32'h56780000+samples").replace('samples==4','samples==33408').replace('count!=8','count!=1')
s=s.replace("if(!seen[k] || !seen[2048+k/4])", "if(!seen[k] || !seen[2048+k/32])")
s=s.replace('string folder,path;', 'string folder,path;integer prefetch_cycles=0;')
s=s.replace('if(tb)begins=', 'if(d.prefetch_busy)prefetch_cycles=prefetch_cycles+1;\n  if(tb)begins=')
s=s.replace('$display("PASS dynamic title reader', 'if(prefetch_cycles==0)$fatal(1,"no prefetch bank overwrite tested");\n    $display("PASS 33408 video words with reused metadata scratch / video prefetch bank; dynamic title reader')
s=s.replace('path=$sformatf("sim/fixtures/dynamic_titles/expected%0d.hex",kind);', 'path="sim/fixtures/title_prefetch/expected.hex";')
(p/'sim/tb_title_prefetch.sv').write_text(s)
print('Prepared 33408-word video title/preload/prefetch fixture,',len(disk),'sectors')
