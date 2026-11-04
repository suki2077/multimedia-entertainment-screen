from pathlib import Path
import subprocess,os
p=Path(__file__).resolve().parent.parent;env=os.environ.copy();env['PATH']='D:/FPGA/rtl_sim_tools/bin;'+env['PATH'];env['TMP']=env['TEMP']='D:/FPGA/tf_console_hdmi/build'
base='D:/FPGA/rtl_sim_tools/bin/';exe=p/'build/fit_final.vvp'
subprocess.run([base+'iverilog.exe','-g2012','-s','tb_fit','-o',str(exe),*[str(p/'rtl'/f'{m}.v') for m in ['bmp_fit_scaler','scale_divider','scale_lerp','album_line_buffer']],str(p/'sim/tb_fit.sv')],env=env,check=True)
def col(x,y):return (((x*17+y*3)^((x//7)*51))&255,((y*19+x*5)^((y//9)*31))&255,(x*11+y*13)&255)
def ref(x,y):
 y=(y-py) if top else (479-y-(480-dh-py));x-=px
 if x<0 or x>=dw or y<0 or y>=dh:return 0
 xc=x*(w-1)*4096//(dw-1) if dw>1 else (w-1)*2048;yc=y*(h-1)*4096//(dh-1) if dh>1 else (h-1)*2048;x0,y0=xc>>12,yc>>12;fx,fy=(xc>>4)&255,(yc>>4)&255
 a,b,c,d=col(x0,y0),col(min(w-1,x0+1),y0),col(x0,min(h-1,y0+1)),col(min(w-1,x0+1),min(h-1,y0+1))
 rgb=[]
 for i in range(3):
  ab=(a[i]*256+(b[i]-a[i])*fx+128)>>8;cd=(c[i]*256+(d[i]-c[i])*fx+128)>>8
  rgb.append((ab*256+(cd-ab)*fy+128)>>8)
 return (rgb[0]<<16)|(rgb[1]<<8)|rgb[2]

logs=[]
for i,(w,h,top) in enumerate([(17,13,1),(321,243,0),(1,1,1),(1,4096,0),(4096,1,1),(1280,720,0),(4096,7,1)]):
 dw,dh=(640,max(1,h*640//w)) if w*3>=h*4 else (max(1,w*480//h),480)
 px,py=(640-dw)//2,(480-dh)//2;out=p/'build'/f'fit_final_{i}.txt'
 r=subprocess.run([base+'vvp.exe',str(exe),f'+W={w}',f'+H={h}',f'+TOP={top}',f'+OUT=build/{out.name}'],cwd=p,env=env,capture_output=True,text=True)
 assert r.returncode==0 and 'PASS' in r.stdout,r.stdout+r.stderr
 seen=set()
 for line in out.read_text().splitlines():
  a,d=line.split();addr,data=int(a,16),int(d,16)
  assert addr%4==0 and addr not in seen;seen.add(addr)
  for n in range(4):
   at=addr+n;x,y=at%640,at//640;actual=(data>>(n*32))&0xffffffff
   assert actual==ref(x,y),(w,h,x,y,hex(actual),hex(ref(x,y)))
 assert len(seen)==76800
 msg=f'PASS {w}x{h} top={top}: all 307200 pixels match independent bilinear reference';logs.append(msg);print(msg,flush=True)
(p/'verification/scaler_hit_reference.log').write_text('\n'.join(logs)+'\n')
