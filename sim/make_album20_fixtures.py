"""Sparse FAT32 images for header enumeration and initial pixel selection.
Only the first 16 sectors of each 640x480 BMP are materialized; these fixtures
test directory/header selection and first output groups, not complete files.
"""
from pathlib import Path
import struct
p=Path(__file__).resolve().parent/'fixtures/album20'
def put(b,o,fmt,*v):struct.pack_into('<'+fmt,b,o,*v)
def ent(name,cluster,size,attr=32):
 b=bytearray(32);b[:11]=name;put(b,11,'B',attr);put(b,26,'H',cluster&65535);put(b,20,'H',cluster>>16);put(b,28,'I',size);return b
for count in [0,1,4,20,21]:
 disk={};boot=bytearray(512);put(boot,11,'H',512);boot[13]=1;put(boot,14,'H',32);boot[16]=1;put(boot,32,'I',70000);put(boot,36,'I',600);put(boot,44,'I',2);put(boot,510,'H',0xaa55);disk[0]=boot
 fat=bytearray(4096)
 for c in range(2,6):put(fat,c*4,'I',c+1 if c<5 else 0xfffffff)
 root=bytearray(b'\xe5'+bytes(31))*64;pos=30
 root[pos*32:(pos+1)*32]=ent(b'FOLDER  BMP',22,100,16);pos+=1
 root[pos*32:(pos+1)*32]=ent(b'LONG    BMP',22,100,15);pos+=1
 for n in range(count+1):
  # One invalid BMP header precedes the real photos and must be skipped.
  cluster=64+n*32;size=54+640*480*3
  name=(f'BADHDR00' if n==0 else f'PIC{n-1:05d}').encode()+b'BMP'
  root[pos*32:(pos+1)*32]=ent(name,cluster,size);pos+=1
  color=0x210040+(n-1)*0x030101 if n else 0
  bgr=bytes([color&255,(color>>8)&255,(color>>16)&255])
  blob=bytearray((bgr*3000)[:8192]);blob[:54]=bytes(54)
  blob[:2]=b'BM' if n else b'NO';put(blob,2,'I',size);put(blob,10,'IIiiHHI',54,40,640,-480,1,24,0)
  for j in range(54,8192):blob[j]=bgr[(j-54)%3]
  for j in range(16):
   disk[632+cluster+j-2]=blob[j*512:(j+1)*512]
   put(fat,(cluster+j)*4,'I',cluster+j+1 if j<15 else 0xfffffff)
 root[pos*32:(pos+1)*32]=bytes(32)
 for j in range(4):disk[632+j]=root[j*512:(j+1)*512]
 for j in range(8):disk[32+j]=fat[j*512:(j+1)*512]
 out=p/str(count);out.mkdir(parents=True,exist_ok=True)
 (out/'info.hex').write_text(f'{len(disk):08x}\n{min(count,20):08x}\n')
 (out/'lbas.hex').write_text(''.join(f'{v:08x}\n' for v in disk))
 (out/'data.hex').write_text(''.join(f'{v:02x}\n' for b in disk.values() for v in b))
