from pathlib import Path
p=Path(__file__).resolve().parent.parent;w,h=321,243
dw,dh=max(1,w*480//h),480;px,py=(640-dw)//2,(480-dh)//2
seen=set();count=0
def col(x,y):return (((x*17+y*3)^((x//7)*51))&255,((y*19+x*5)^((y//9)*31))&255,(x*11+y*13)&255)
def ref(x,y):
 y=479-y-(480-dh-py);x-=px
 if x<0 or x>=dw or y<0 or y>=dh:return 0
 xc=x*(w-1)*4096//(dw-1);yc=y*(h-1)*4096//(dh-1);x0,y0=xc>>12,yc>>12;fx,fy=(xc>>4)&255,(yc>>4)&255
 a,b,c,d=col(x0,y0),col(min(w-1,x0+1),y0),col(x0,min(h-1,y0+1)),col(min(w-1,x0+1),min(h-1,y0+1))
 rgb=[]
 for i in range(3):
  ab=(a[i]*256+(b[i]-a[i])*fx+128)>>8;cd=(c[i]*256+(d[i]-c[i])*fx+128)>>8
  rgb.append((ab*256+(cd-ab)*fy+128)>>8)
 return (rgb[0]<<16)|(rgb[1]<<8)|rgb[2]
for line in (p/'build/scale_music.txt').read_text().splitlines():
 a,d=line.split();addr,data=int(a,16),int(d,16)
 assert addr%4==0 and addr not in seen;seen.add(addr)
 for i in range(4):
  at=addr+i;x,y=at%640,at//640;actual=(data>>(i*32))&0xffffff
  assert actual==ref(x,y),(x,y,hex(actual),hex(ref(x,y)))
  count+=1
assert count>=80000
msg=f'PASS {count} concurrent scaled pixels match independent bilinear reference exactly\n'
(p/'verification/scale_pixel_reference.log').write_text(msg);print(msg)
