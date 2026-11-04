from pathlib import Path
import sys,struct
P=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(P/'tools'))
from prepare_titles import encode_pack
def put(b,o,f,*v):struct.pack_into('<'+f,b,o,*v)
def entry(name,cluster,size):
 b=bytearray(32);b[:11]=name;put(b,20,'H',cluster>>16);put(b,26,'H',cluster&65535);put(b,28,'I',size);return b
items=[]
for kind,ext in [(0,b'WAV'),(1,b'SAV')]:
 for n in range(8):
  title=('我的视频'+str(n)+'.SAV') if kind else ('测试音乐'+str(n)+'.WAV')
  if not kind and n<2:title=['唯一 邓紫棋.wav','再见 邓紫棋.wav'][n]
  if kind and n==0:title='都2024年了，还有人在听这首《Let Go》吗？.SAV'
  items.append((kind,title,('VIDEO' if kind else 'SONG0').encode()+f'{n:03d}'.encode()+ext))
# Deliberately reverse record order: hardware must join by short-name identity.
pack,report=encode_pack(list(reversed(items)),Path('C:/Windows/Fonts/simhei.ttf'))
base=P/'sim/fixtures/dynamic_titles';base.mkdir(parents=True,exist_ok=True)
for variant in ['good','badmagic','badcode','badfat','absent','badsize']:
 disk={};boot=bytearray(512);put(boot,11,'H',512);boot[13]=1;put(boot,14,'H',32);boot[16]=1;put(boot,32,'I',70000);put(boot,36,'I',600);put(boot,44,'I',2);put(boot,510,'H',0xaa55);disk[0]=boot
 fat=bytearray(4096)
 for a,b in [(2,4),(4,6),(6,0xfffffff)]:put(fat,a*4,'I',b)
 root=bytearray(b'\xe5'+bytes(31))*48
 for j,(kind,name,identity) in enumerate(items):
  n=j%8;cluster=100+j*4;size=134144 if kind else 60
  root[(15+j)*32:(16+j)*32]=entry(identity,cluster,size)
  head=bytearray(512);payload=b''.join(struct.pack('<I',0x12340000+n*256+k) for k in range(4))
  if kind:
   head[:8]=b'SUKIPL01';put(head,8,'6H',480,270,15,5,1,0);put(head,20,'I',133632);put(head,24,'I',24000);put(head,28,'HHI',1600,16,133632)
   put(fat,cluster*4,'I',400+j);put(fat,(400+j)*4,'I',0xfffffff)
   disk[632+400+j-2]=bytearray(payload+bytes(496))
  else:
   head[:4]=b'RIFF';put(head,4,'I',52);head[8:16]=b'WAVEfmt ';put(head,16,'IHHIIHH',16,1,2,48000,192000,4,16);head[36:40]=b'data';put(head,40,'I',16);head[44:60]=payload;put(fat,cluster*4,'I',0xfffffff)
  disk[632+cluster-2]=head
 blob=bytearray(pack)
 if variant=='badmagic':blob[0]=0
 if variant=='badcode':blob[512+2048+4]=192 # first record is active video slot7
 chain=[500,702,504,706,508,710,512,714,516]
 for i,c in enumerate(chain):
  put(fat,c*4,'I',chain[i+1] if i<8 else 0xfffffff)
  disk[632+c-2]=blob[i*512:(i+1)*512]
 if variant=='badfat':put(fat,chain[0]*4,'I',chain[0])
 if variant!='absent':root[40*32:41*32]=entry(b'TITLES  BIN',chain[0],4607 if variant=='badsize' else 4608)
 root[41*32:42*32]=bytes(32)
 for i,c in enumerate([2,4,6]):disk[632+c-2]=root[i*512:(i+1)*512]
 for i in range(8):disk[32+i]=fat[i*512:(i+1)*512]
 out=base/variant;out.mkdir(exist_ok=True)
 (out/'info.hex').write_text(f'{len(disk):08x}\n')
 (out/'lbas.hex').write_text(''.join(f'{a:08x}\n' for a in disk))
 (out/'data.hex').write_text(''.join(f'{b:02x}\n' for data in disk.values() for b in data))
for kind in [0,1]:
 expected=bytearray(4096);expected[:2048]=pack[512:2560]
 for i,(k,name,identity) in enumerate(items):
  if k!=kind:continue
  record=list(reversed(items)).index((k,name,identity));raw=pack[2560+record*128:2560+(record+1)*128]
  expected[2048+(i%8)*64]=raw[1];expected[2049+(i%8)*64:2112+(i%8)*64]=raw[4:67]
 (base/f'expected{kind}.hex').write_text(''.join(f'{v:02x}\n' for v in expected))
print('Dynamic title fixtures: 16 media, title file beyond 8-entry limit, reordered records, fragmented9-sector metadata and malformed fallbacks.')
